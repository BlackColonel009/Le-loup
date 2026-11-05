"""Explicit, persistent email campaigns for visible community announcements."""

import hashlib
import io
import json
import logging
import os
import re
import secrets
import time
from email.message import EmailMessage
from pathlib import Path
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException

from .community import Store, administrator, store
from .email_security import normalize_email, require_mailer, send_message
from .mail_template import reminder_html

router = APIRouter()
log = logging.getLogger(__name__)


def revision(title, body, images=()):
    text = title + '\0' + body
    if images:
        text += '\0' + json.dumps(list(images), ensure_ascii=False)
    return hashlib.sha256(text.encode()).hexdigest()


def inline_cards(db, images):
    """Read trusted local artwork, never fetch arbitrary network URLs."""
    from PIL import Image

    from .gallery import upload_directory
    result = []
    for index, url in enumerate(images):
        if re.fullmatch(r'/site-assets/[a-zA-Z0-9_.-]+', url):
            path = Path(__file__).parent / 'web/assets' / url.rsplit('/', 1)[1]
        elif re.fullmatch(r'/(?:gallery/images|community/content-images)/[a-f0-9]{32}\.(?:png|jpg|webp)', url):
            path = upload_directory(db) / url.rsplit('/', 1)[1]
        else:
            raise ValueError('Invalid announcement artwork')
        if path.stat().st_size > 8 * 1024 * 1024:
            raise ValueError('Announcement artwork too large')
        with Image.open(path) as original:
            original.thumbnail((800, 1200))
            pixels = original.convert('RGBA')
            background = Image.new('RGB', pixels.size, '#152232')
            background.paste(pixels, mask=pixels.getchannel('A'))
            output = io.BytesIO()
            background.save(output, format='JPEG', quality=85, optimize=True)
        data = output.getvalue()
        cid = f'card-{index}-{hashlib.sha256(data).hexdigest()[:16]}@mordeviel'
        result.append((cid, data))
    return result


def initialize(db):
    with db.db() as c:
        c.executescript("""
            CREATE TABLE IF NOT EXISTS announcement_campaigns (
                id INTEGER PRIMARY KEY, content_id INTEGER NOT NULL,
                revision TEXT NOT NULL, title TEXT NOT NULL, body TEXT NOT NULL,
                actor INTEGER NOT NULL, created REAL NOT NULL,
                UNIQUE(content_id,revision));
            CREATE TABLE IF NOT EXISTS announcement_deliveries (
                id INTEGER PRIMARY KEY, campaign_id INTEGER NOT NULL,
                user_id INTEGER NOT NULL, address TEXT NOT NULL,
                status TEXT NOT NULL DEFAULT 'pending',
                UNIQUE(campaign_id,user_id));
        """)
        if 'images' not in {r[1] for r in c.execute('PRAGMA table_info(announcement_campaigns)')}:
            c.execute("ALTER TABLE announcement_campaigns ADD COLUMN images TEXT NOT NULL DEFAULT '[]'")


def summary(c, content_id):
    rows = c.execute(
        """SELECT d.status, COUNT(*) AS n FROM announcement_deliveries d
        JOIN announcement_campaigns a ON a.id=d.campaign_id
        WHERE a.content_id=? GROUP BY d.status""",
        (content_id,),
    ).fetchall()
    return {r["status"]: r["n"] for r in rows}


@router.get("/community/admin/content/{content_id}/email")
def status(
    content_id: int,
    *,
    admin: Annotated[dict, Depends(administrator)],
    db: Annotated[Store, Depends(store)],
):
    with db.db() as c:
        return {"deliveries": summary(c, content_id)}


@router.post("/community/admin/content/{content_id}/email")
def queue(
    content_id: int,
    *,
    admin: Annotated[dict, Depends(administrator)],
    db: Annotated[Store, Depends(store)],
):
    with db.db() as c:
        c.execute("BEGIN IMMEDIATE")
        content = c.execute(
            "SELECT * FROM official_content WHERE id=?", (content_id,)
        ).fetchone()
        if not content or not content["visible"] or content["kind"] != "announcement":
            raise HTTPException(
                409, "Seule une annonce publiée et visible peut être envoyée par email."
            )
        images = json.loads(content['images'])
        digest = revision(content["title"], content["body"], images)
        previous = c.execute(
            "SELECT id FROM announcement_campaigns WHERE content_id=? AND revision=?",
            (content_id, digest),
        ).fetchone()
        if previous:
            return {"already_queued": True, "deliveries": summary(c, content_id)}
        require_mailer()
        campaign = c.execute(
            """INSERT INTO announcement_campaigns
            (content_id,revision,title,body,actor,created,images) VALUES(?,?,?,?,?,?,?)""",
            (
                content_id,
                digest,
                content["title"],
                content["body"],
                admin["id"],
                time.time(),
                json.dumps(images),
            ),
        ).lastrowid
        count = 0
        for user in c.execute(
            "SELECT id,email FROM users WHERE email_verified=1 AND banned=0 AND email IS NOT NULL"
        ).fetchall():
            c.execute(
                "INSERT OR IGNORE INTO community_mail_preferences(user_id,token) VALUES(?,?)",
                (user["id"], secrets.token_urlsafe(32)),
            )
            subscribed = c.execute(
                "SELECT subscribed FROM community_mail_preferences WHERE user_id=?",
                (user["id"],),
            ).fetchone()[0]
            if subscribed and user["email"]:
                c.execute(
                    "INSERT INTO announcement_deliveries(campaign_id,user_id,address) VALUES(?,?,?)",
                    (campaign, user["id"], user["email"]),
                )
                count += 1
        from .administration import audit

        audit(c, admin, "announcement_email", f"{content_id}:{campaign}:{count}")
        return {
            "already_queued": False,
            "queued": count,
            "deliveries": summary(c, content_id),
        }


def tick(db):
    # Claim before SMTP. An uncertain send is never retried automatically.
    for _ in range(100):
        with db.db() as c:
            c.execute("BEGIN IMMEDIATE")
            delivery = c.execute("""SELECT d.*, a.content_id,a.revision,a.title,a.body,a.images
                FROM announcement_deliveries d JOIN announcement_campaigns a ON a.id=d.campaign_id
                WHERE d.status='pending' ORDER BY d.id LIMIT 1""").fetchone()
            if delivery is None:
                return
            user = c.execute(
                "SELECT email,email_verified,banned FROM users WHERE id=?",
                (delivery["user_id"],),
            ).fetchone()
            pref = c.execute(
                "SELECT * FROM community_mail_preferences WHERE user_id=?",
                (delivery["user_id"],),
            ).fetchone()
            content = c.execute(
                "SELECT * FROM official_content WHERE id=?", (delivery["content_id"],)
            ).fetchone()
            valid = (
                user
                and user["email_verified"]
                and not user["banned"]
                and user["email"] == delivery["address"]
                and pref
                and pref["subscribed"]
                and content
                and content["visible"]
                and content["kind"] == "announcement"
                and revision(content["title"], content["body"], json.loads(content['images'])) == delivery["revision"]
            )
            if valid:
                require_mailer()
            c.execute(
                "UPDATE announcement_deliveries SET status=? WHERE id=?",
                ("sending" if valid else "cancelled", delivery["id"]),
            )
        if not valid:
            continue
        try:
            base = os.getenv(
                "MORDEVIEL_PUBLIC_URL", "https://mordeviel.newtechnologiestg.com"
            ).rstrip("/")
            unsubscribe = f"{base}/community/mail/unsubscribe/{pref['token']}"
            message = EmailMessage()
            message["From"] = normalize_email(os.environ["MORDEVIEL_SMTP_FROM"])
            message["To"] = normalize_email(delivery["address"])
            message["Subject"] = "Mordeviel · " + " ".join(delivery["title"].split())
            message["List-Unsubscribe"] = f"<{unsubscribe}>"
            cards = inline_cards(db, json.loads(delivery['images']))
            message.set_content(
                f"{delivery['title']}\n\n{delivery['body']}\n\nAnnonce publiée dans la communauté Mordeviel et sur la vitrine.\n{base}/#annonces\n\nNe plus recevoir les emails de la communauté : {unsubscribe}\n\nby Logan R.D"
            )
            message.add_alternative(
                reminder_html(
                    delivery["body"],
                    base,
                    unsubscribe,
                    announcement_title=delivery["title"],
                    announcement_images=[{'src': 'cid:' + cid, 'alt': f'Carte {index + 1} · ' + delivery['title']} for index, (cid, _) in enumerate(cards)],
                ),
                subtype="html",
            )
            html = message.get_payload()[-1]
            for index, (cid, data) in enumerate(cards):
                html.add_related(data, maintype='image', subtype='jpeg', cid=f'<{cid}>', disposition='inline', filename=f'carte-{index + 1}.jpg')
            send_message(message)
            outcome = "sent"
        except Exception:  # noqa: BLE001 -- worker boundary; never expose SMTP secrets in logs.
            log.warning("Announcement email failed; see delivery counters.")
            outcome = "failed"
        with db.db() as c:
            c.execute(
                "UPDATE announcement_deliveries SET status=? WHERE id=?",
                (outcome, delivery["id"]),
            )
