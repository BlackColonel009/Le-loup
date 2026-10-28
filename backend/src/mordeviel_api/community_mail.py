"""Persistent community reminder schedule, driven by the API lifespan."""
import asyncio
import json
import logging
import os
import secrets
import time
from email.message import EmailMessage
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException
from fastapi.responses import HTMLResponse
from pydantic import BaseModel, Field

from .community import Store, administrator, store
from .email_security import normalize_email, require_mailer, send_message

router = APIRouter()
log = logging.getLogger(__name__)
PHRASES = [
    "La communauté du Loup vous attend… N’oubliez pas : les loups rôdent !",
    "La nuit approche et le village compte sur vous. Qui oserez-vous croire ce soir ?",
    "Une lumière brille encore au conseil du village. Venez retrouver la communauté !",
    "Sous la pleine lune, les secrets se réveillent. Préparez vos alliances et rejoignez-nous !",
    "Un hurlement au loin… Vos amis vous attendent pour une nouvelle soirée de mystère.",
    "Villageois ou prédateur, votre prochaine histoire commence avec la communauté du Loup.",
    "Le conseil se rassemble. Vos intuitions feront-elles la différence cette fois ?",
    "Les portes du village sont ouvertes. Entrez… mais gardez un œil sur vos voisins !",
    "Un nouveau débat, de nouveaux soupçons, de nouveaux souvenirs à partager. Le village vous attend !",
    "Les loups n’ont pas dit leur dernier mot. Réunissez vos amis et faites vivre la légende !",
]


class MailSettings(BaseModel):
    enabled: bool = True
    interval_days: int = Field(default=7, ge=1, le=90)
    subject: str = Field(default="Le village vous attend · Mordeviel", min_length=1, max_length=150, pattern=r"^[^\r\n]+$")
    phrases: list[str] = Field(default=PHRASES, min_length=1, max_length=30)


def initialize(db):
    with db.db() as connection:
        connection.executescript("""
            CREATE TABLE IF NOT EXISTS community_mail_schedule (
                id INTEGER PRIMARY KEY CHECK(id=1), config TEXT NOT NULL,
                next_due REAL NOT NULL, rotation INTEGER NOT NULL DEFAULT 0);
            CREATE TABLE IF NOT EXISTS community_mail_preferences (
                user_id INTEGER PRIMARY KEY, token TEXT NOT NULL UNIQUE,
                subscribed INTEGER NOT NULL DEFAULT 1);
            CREATE TABLE IF NOT EXISTS community_mail_deliveries (
                id INTEGER PRIMARY KEY, user_id INTEGER NOT NULL,
                address TEXT NOT NULL, body TEXT NOT NULL, subject TEXT NOT NULL,
                status TEXT NOT NULL DEFAULT 'pending', created REAL NOT NULL);
        """)
        connection.execute(
            "INSERT OR IGNORE INTO community_mail_schedule(id,config,next_due) VALUES(1,?,?)",
            (MailSettings().model_dump_json(), time.time() + 7 * 86400),
        )


def settings(db):
    with db.db() as connection:
        row = connection.execute("SELECT * FROM community_mail_schedule WHERE id=1").fetchone()
        counts = {r['status']: r['n'] for r in connection.execute(
            "SELECT status,COUNT(*) AS n FROM community_mail_deliveries GROUP BY status")}
    return {**json.loads(row['config']), "next_due": row['next_due'], "deliveries": counts}


@router.get('/community/admin/mail-schedule')
def read_settings(*, admin: Annotated[dict, Depends(administrator)], db: Annotated[Store, Depends(store)]):
    return settings(db)


@router.put('/community/admin/mail-schedule')
def update_settings(*, data: MailSettings, admin: Annotated[dict, Depends(administrator)], db: Annotated[Store, Depends(store)]):
    phrases = [p.strip() for p in data.phrases]
    if any(not p or len(p) > 2000 for p in phrases) or not data.subject.strip():
        raise HTTPException(422, 'Chaque phrase doit contenir entre 1 et 2000 caractères.')
    data = data.model_copy(update={'phrases': phrases, 'subject': data.subject.strip()})
    with db.db() as connection:
        connection.execute('BEGIN IMMEDIATE')
        row = connection.execute('SELECT * FROM community_mail_schedule WHERE id=1').fetchone()
        old = json.loads(row['config'])
        due = row['next_due']
        if data.interval_days != old['interval_days'] or data.enabled and not old['enabled']:
            due = time.time() + data.interval_days * 86400
        connection.execute('UPDATE community_mail_schedule SET config=?,next_due=? WHERE id=1', (data.model_dump_json(), due))
        if not data.enabled:
            connection.execute("UPDATE community_mail_deliveries SET status='cancelled' WHERE status='pending'")
        from .administration import audit
        audit(connection, admin, 'community_mail_schedule', data.model_dump_json())
    return settings(db)


def tick(db):
    """Claim before SMTP: never automatically resend an uncertain delivery."""
    with db.db() as connection:
        connection.execute('BEGIN IMMEDIATE')
        row = connection.execute('SELECT * FROM community_mail_schedule WHERE id=1').fetchone()
        config = json.loads(row['config'])
        if not config['enabled']:
            return
        now = time.time()
        connection.execute('DELETE FROM community_mail_deliveries WHERE created<?', (now - 30 * 86400,))
        if row['next_due'] > now and not connection.execute("SELECT 1 FROM community_mail_deliveries WHERE status='pending' LIMIT 1").fetchone():
            return
        require_mailer()
        if row['next_due'] <= now:
            phrase = config['phrases'][row['rotation'] % len(config['phrases'])]
            # Skip missed weeks instead of sending a backlog after downtime.
            connection.execute('UPDATE community_mail_schedule SET next_due=?,rotation=rotation+1 WHERE id=1', (now + config['interval_days'] * 86400,))
            connection.execute("UPDATE community_mail_deliveries SET status='expired' WHERE status='pending'")
            for user in connection.execute('SELECT id,email FROM users WHERE email_verified=1 AND banned=0 AND email IS NOT NULL').fetchall():
                connection.execute('INSERT OR IGNORE INTO community_mail_preferences(user_id,token) VALUES(?,?)', (user['id'], secrets.token_urlsafe(32)))
                pref = connection.execute('SELECT * FROM community_mail_preferences WHERE user_id=?', (user['id'],)).fetchone()
                if pref['subscribed']:
                    connection.execute('INSERT INTO community_mail_deliveries(user_id,address,body,subject,created) VALUES(?,?,?,?,?)', (user['id'], user['email'], phrase, config['subject'], now))
    for _ in range(100):
        with db.db() as connection:
            connection.execute('BEGIN IMMEDIATE')
            current = json.loads(connection.execute('SELECT config FROM community_mail_schedule WHERE id=1').fetchone()[0])
            if not current['enabled']:
                return
            delivery = connection.execute("SELECT * FROM community_mail_deliveries WHERE status='pending' ORDER BY id LIMIT 1").fetchone()
            if delivery is None:
                return
            user = connection.execute('SELECT email,email_verified,banned FROM users WHERE id=?', (delivery['user_id'],)).fetchone()
            pref = connection.execute('SELECT * FROM community_mail_preferences WHERE user_id=?', (delivery['user_id'],)).fetchone()
            valid = user and user['email_verified'] and not user['banned'] and user['email'] == delivery['address'] and pref and pref['subscribed']
            connection.execute('UPDATE community_mail_deliveries SET status=? WHERE id=?', ('sending' if valid else 'cancelled', delivery['id']))
        if not valid:
            continue
        try:
            base = os.getenv('MORDEVIEL_PUBLIC_URL', 'https://mordeviel.newtechnologiestg.com').rstrip('/')
            unsubscribe = f"{base}/community/mail/unsubscribe/{pref['token']}"
            message = EmailMessage()
            message['From'] = normalize_email(os.environ['MORDEVIEL_SMTP_FROM'])
            message['To'] = normalize_email(delivery['address'])
            message['Subject'] = delivery['subject']
            message['List-Unsubscribe'] = f'<{unsubscribe}>'
            message.set_content(f"Bonjour,\n\n{delivery['body']}\n\nRetrouvez le jeu et la communauté : {base}\n\nMordeviel · by Logan R.D\n\nNe plus recevoir ces rappels : {unsubscribe}")
            from .mail_template import reminder_html
            message.add_alternative(reminder_html(delivery['body'], base, unsubscribe), subtype='html')
            send_message(message)
            outcome = 'sent'
        except Exception:
            # Never log addresses, credentials, unsubscribe tokens or message bodies.
            log.warning('Community reminder delivery failed; see dashboard counters.')
            outcome = 'failed'
        with db.db() as connection:
            connection.execute('UPDATE community_mail_deliveries SET status=? WHERE id=?', (outcome, delivery['id']))


async def run(db):
    while True:
        try:
            await asyncio.to_thread(tick, db)
        except Exception:
            log.warning('Community mail scheduler unavailable; retrying in 60 seconds.')
        await asyncio.sleep(60)


@router.get('/community/mail/unsubscribe/{token}', response_class=HTMLResponse)
def unsubscribe_page(token: str, db: Annotated[Store, Depends(store)]):
    with db.db() as connection:
        if not connection.execute('SELECT 1 FROM community_mail_preferences WHERE token=?', (token,)).fetchone():
            raise HTTPException(404, 'Lien introuvable.')
    return '<!doctype html><html lang="fr"><meta charset="utf-8"><meta name="viewport" content="width=device-width"><title>Rappels du village</title><body><h1>Mordeviel</h1><p>Ne plus recevoir les rappels de la communauté ?</p><form method="post"><button>Me désinscrire des rappels</button></form></body></html>'


@router.post('/community/mail/unsubscribe/{token}', response_class=HTMLResponse)
def unsubscribe(token: str, db: Annotated[Store, Depends(store)]):
    with db.db() as connection:
        result = connection.execute('UPDATE community_mail_preferences SET subscribed=0 WHERE token=?', (token,))
        if not result.rowcount:
            raise HTTPException(404, 'Lien introuvable.')
    return '<!doctype html><html lang="fr"><meta charset="utf-8"><title>Désinscription</title><h1>Vous ne recevrez plus les rappels de la communauté.</h1><p>Votre compte reste actif.</p></html>'
