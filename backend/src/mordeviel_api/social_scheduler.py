"""Backend-owned invitation email scheduler. Phone delivery is client polling."""

import asyncio
import logging
import os
import time
from email.message import EmailMessage
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException
from fastapi.responses import HTMLResponse

from .community import Store, store
from .email_security import normalize_email, send_message
from .mail_template import reminder_html
from .social import expire_invitations, notification_active, preference

router = APIRouter()
log = logging.getLogger(__name__)


def tick(db, rooms):
    from .private_chat import purge
    purge(db)
    expire_invitations(db, rooms)
    now = time.time()
    with db.db() as c:
        rows = c.execute(
            "SELECT id FROM social_notifications WHERE mail_state='pending' AND created<? ORDER BY id LIMIT 50",
            (now - 30,),
        ).fetchall()
    for row in rows:
        with db.db() as c:
            c.execute("BEGIN IMMEDIATE")
            n = c.execute(
                "SELECT * FROM social_notifications WHERE id=?", (row["id"],)
            ).fetchone()
            if n["mail_state"] != "pending":
                continue
            target = c.execute(
                "SELECT email,email_verified,banned FROM users WHERE id=?",
                (n["user_id"],),
            ).fetchone()
            sender = c.execute(
                "SELECT nickname FROM users WHERE id=?", (n["actor_id"],)
            ).fetchone()
            pref = preference(c, n["user_id"])
            recent = c.execute(
                "SELECT COUNT(*) FROM social_notifications WHERE user_id=? AND mail_state='sent' AND created>?",
                (n["user_id"], now - 86400),
            ).fetchone()[0]
            pair = c.execute(
                "SELECT 1 FROM social_notifications WHERE user_id=? AND actor_id=? AND mail_state='sent' AND created>?",
                (n["user_id"], n["actor_id"], now - 21600),
            ).fetchone()
            allowed = (
                target
                and sender
                and target["email_verified"]
                and not target["banned"]
                and target["email"]
                and pref["invite_emails"]
                and pref["last_seen"] < now - 90
                and notification_active(c, n)
                and recent < 6
                and not pair
            )
            c.execute(
                "UPDATE social_notifications SET mail_state=? WHERE id=?",
                ("sending" if allowed else "skipped", n["id"]),
            )
        if not allowed:
            continue
        try:
            base = os.getenv(
                "MORDEVIEL_PUBLIC_URL", "https://mordeviel.newtechnologiestg.com"
            ).rstrip("/")
            optout = f"{base}/social/email/unsubscribe/{pref['optout']}"
            text = f"{sender['nickname']} vient d’ouvrir un salon et vous invite à rejoindre le village.\nOuvrez l’application puis vos Invitations pour retrouver les détails et rejoindre la partie tant que le salon est disponible.\nLes loups rôdent… votre place vous attend !"
            message = EmailMessage()
            message["From"] = normalize_email(os.environ["MORDEVIEL_SMTP_FROM"])
            message["To"] = normalize_email(target["email"])
            message["Subject"] = "Une invitation au village · Mordeviel"
            message["List-Unsubscribe"] = f"<{optout}>"
            message.set_content(
                f"{text}\n\n{base}\n\nDésactiver ces emails : {optout}\n\nby Logan R.D"
            )
            message.add_alternative(reminder_html(text, base, optout), subtype="html")
            send_message(message)
            outcome = "sent"
        except Exception:
            outcome = "failed"
            log.exception("Invitation email could not be delivered.")
        with db.db() as c:
            c.execute(
                "UPDATE social_notifications SET mail_state=? WHERE id=?",
                (outcome, n["id"]),
            )
    with db.db() as c:
        old = now - 90 * 86400
        c.execute(
            "DELETE FROM social_receipts WHERE notification_id IN (SELECT id FROM social_notifications WHERE created<?)",
            (old,),
        )
        c.execute("DELETE FROM social_notifications WHERE created<?", (old,))
        c.execute("DELETE FROM social_inapp_receipts WHERE notification_id NOT IN (SELECT id FROM social_notifications)")
        c.execute(
            "DELETE FROM social_invitations WHERE created<? AND status!='active'",
            (old,),
        )


async def run(db, rooms):
    while True:
        try:
            await asyncio.to_thread(tick, db, rooms)
        except Exception:
            log.exception("Invitation scheduler will retry on the next cycle.")
        await asyncio.sleep(30)


@router.get("/social/email/unsubscribe/{token}", response_class=HTMLResponse)
def unsubscribe_page(token: str, db: Annotated[Store, Depends(store)]):
    with db.db() as c:
        if not c.execute(
            "SELECT 1 FROM social_preferences WHERE optout=?", (token,)
        ).fetchone():
            raise HTTPException(404, "Lien introuvable.")
    return '<!doctype html><html lang="fr"><meta charset="utf-8"><meta name="viewport" content="width=device-width"><title>Invitations du village</title><h1>Mordeviel</h1><p>Désactiver les emails d’invitation des amis ?</p><form method="post"><button>Ne plus recevoir ces emails</button></form></html>'


@router.post("/social/email/unsubscribe/{token}", response_class=HTMLResponse)
def unsubscribe(token: str, db: Annotated[Store, Depends(store)]):
    with db.db() as c:
        if not c.execute(
            "UPDATE social_preferences SET invite_emails=0 WHERE optout=?", (token,)
        ).rowcount:
            raise HTTPException(404, "Lien introuvable.")
    return '<!doctype html><html lang="fr"><meta charset="utf-8"><title>Désinscription</title><h1>Emails d’invitation désactivés.</h1><p>Vos amis et votre compte restent disponibles.</p></html>'
