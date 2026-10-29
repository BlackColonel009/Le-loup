"""Foreground leases and friend connection alerts; background polling is not presence."""

import hashlib
import time
from typing import Literal

from fastapi import APIRouter, HTTPException, Request
from pydantic import BaseModel, Field

from .social import Database, User, blocked, friends, preference

router = APIRouter(prefix="/social", tags=["social"])
ONLINE_LEASE = 90
AWAY_LEASE = 300
ALERT_LIFETIME = 3600


def initialize(db):
    with db.db() as c:
        c.executescript("""
        CREATE TABLE IF NOT EXISTS social_presence (
            user_id INTEGER NOT NULL, device_id TEXT NOT NULL, session_digest TEXT NOT NULL,
            state TEXT NOT NULL, heartbeat REAL NOT NULL, changed REAL NOT NULL,
            PRIMARY KEY(user_id,device_id));
        CREATE TABLE IF NOT EXISTS social_inapp_receipts (
            notification_id INTEGER NOT NULL, device_id TEXT NOT NULL,
            PRIMARY KEY(notification_id,device_id));
        CREATE INDEX IF NOT EXISTS social_presence_actor
            ON social_notifications(actor_id,kind,created);
        """)


def status(c, uid, now=None):
    now = time.time() if now is None else now
    rows = c.execute("SELECT * FROM social_presence WHERE user_id=?", (uid,)).fetchall()
    online = any(
        r["state"] == "online" and r["heartbeat"] > now - ONLINE_LEASE for r in rows
    )
    away = any(r["state"] == "away" and r["heartbeat"] > now - AWAY_LEASE for r in rows)
    disconnected = max(
        (
            r["changed"]
            if r["state"] == "offline"
            else r["heartbeat"]
            + (ONLINE_LEASE if r["state"] == "online" else AWAY_LEASE)
            for r in rows
        ),
        default=None,
    )
    return {
        "presence": "online" if online else "away" if away else "offline",
        "online": online,
        "disconnected_at": disconnected if not online and not away else None,
    }


def connection_alerts(c, actor, now):
    rows = c.execute(
        """SELECT u.id FROM social_friends f JOIN users u
        ON u.id=CASE WHEN f.low_id=? THEN f.high_id ELSE f.low_id END
        WHERE (f.low_id=? OR f.high_id=?) AND f.status='accepted'
        AND u.banned=0 AND u.email_verified=1 LIMIT 200""",
        (actor, actor, actor),
    ).fetchall()
    for row in rows:
        target = row["id"]
        if blocked(c, actor, target):
            continue
        # Repeated foreground changes, reconnects and multiple devices must not spam friends.
        if c.execute(
            "SELECT 1 FROM social_notifications WHERE user_id=? AND actor_id=? AND kind='presence' AND created>?",
            (target, actor, now - 900),
        ).fetchone():
            continue
        c.execute(
            "INSERT INTO social_notifications(user_id,kind,source_id,actor_id,created) VALUES(?,'presence',?,?,?)",
            (target, actor, actor, now),
        )


class Heartbeat(BaseModel):
    device_id: str = Field(pattern=r"^[a-f0-9]{32}$")
    state: Literal["online", "away", "offline"] = "online"


@router.post("/presence")
def heartbeat(data: Heartbeat, request: Request, *, user: User, db: Database):
    uid, now = user["id"], time.time()
    db.limit(("presence", uid), 120, 60)
    with db.db() as c:
        c.execute("BEGIN IMMEDIATE")
        previous = status(c, uid, now)["presence"]
        existing = c.execute(
            "SELECT 1 FROM social_presence WHERE user_id=? AND device_id=?",
            (uid, data.device_id),
        ).fetchone()
        if not existing:
            # Retain a bounded number of devices while preserving the latest disconnect time.
            c.execute(
                """DELETE FROM social_presence WHERE user_id=? AND device_id NOT IN
                (SELECT device_id FROM social_presence WHERE user_id=? ORDER BY heartbeat DESC LIMIT 9)""",
                (uid, uid),
            )
        digest = hashlib.sha256(
            request.headers.get("authorization", "")[7:].encode()
        ).hexdigest()
        c.execute(
            """INSERT INTO social_presence VALUES(?,?,?,?,?,?)
            ON CONFLICT(user_id,device_id) DO UPDATE SET
            changed=CASE WHEN state=excluded.state THEN changed ELSE excluded.changed END,
            state=excluded.state,heartbeat=excluded.heartbeat,session_digest=excluded.session_digest""",
            (uid, data.device_id, digest, data.state, now, now),
        )
        if data.state == "online":
            preference(c, uid)
            c.execute(
                "UPDATE social_preferences SET last_seen=? WHERE user_id=?", (now, uid)
            )
            if previous == "offline":
                connection_alerts(c, uid, now)
        return {"ok": True, **status(c, uid, now)}


def alert_active(c, n):
    return n["created"] > time.time() - ALERT_LIFETIME and friends(
        c, n["user_id"], n["actor_id"]
    )


@router.get("/presence/alerts")
def alerts(device_id: str, *, user: User, db: Database):
    if len(device_id) != 32 or any(ch not in "0123456789abcdef" for ch in device_id):
        raise HTTPException(422, "Appareil invalide.")
    with db.db() as c:
        rows = c.execute(
            """SELECT n.*,u.nickname FROM social_notifications n
            JOIN users u ON u.id=n.actor_id
            WHERE n.user_id=? AND n.kind='presence' AND n.created>?
            AND u.banned=0 AND u.email_verified=1
            AND NOT EXISTS(SELECT 1 FROM social_inapp_receipts r
                WHERE r.notification_id=n.id AND r.device_id=?)
            ORDER BY n.id DESC LIMIT 20""",
            (user["id"], time.time() - ALERT_LIFETIME, device_id),
        ).fetchall()
        return {
            "alerts": [
                {"id": n["id"], "nickname": n["nickname"], "created": n["created"]}
                for n in reversed(rows)
                if alert_active(c, n)
            ]
        }


@router.post("/presence/alerts/{notification_id}/delivered")
def delivered(notification_id: int, data: Heartbeat, *, user: User, db: Database):
    with db.db() as c:
        if c.execute(
            "SELECT 1 FROM social_notifications WHERE id=? AND user_id=? AND kind='presence'",
            (notification_id, user["id"]),
        ).fetchone():
            c.execute(
                "INSERT OR IGNORE INTO social_inapp_receipts VALUES(?,?)",
                (notification_id, data.device_id),
            )
    return {"ok": True}
