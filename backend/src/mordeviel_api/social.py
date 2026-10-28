"""Account-bound social graph, private profiles and authoritative match results."""

import hashlib
import secrets
import time
from typing import Annotated, Literal

from fastapi import APIRouter, Depends, HTTPException, Request
from pydantic import BaseModel, Field

from .community import Store, authenticated, store

router = APIRouter(prefix="/social", tags=["social"])
User = Annotated[dict, Depends(authenticated)]
Database = Annotated[Store, Depends(store)]


def initialize(db):
    with db.db() as c:
        c.executescript("""
        CREATE TABLE IF NOT EXISTS social_preferences (
            user_id INTEGER PRIMARY KEY, stats_visibility TEXT NOT NULL DEFAULT 'public',
            invite_emails INTEGER NOT NULL DEFAULT 1, phone_notifications INTEGER NOT NULL DEFAULT 0,
            auto_invite INTEGER NOT NULL DEFAULT 1, last_seen REAL NOT NULL DEFAULT 0,
            optout TEXT NOT NULL UNIQUE);
        CREATE TABLE IF NOT EXISTS social_friends (
            low_id INTEGER NOT NULL, high_id INTEGER NOT NULL, sender_id INTEGER NOT NULL,
            status TEXT NOT NULL, created REAL NOT NULL, updated REAL NOT NULL,
            PRIMARY KEY(low_id,high_id));
        CREATE TABLE IF NOT EXISTS social_blocks (
            user_id INTEGER NOT NULL, target_id INTEGER NOT NULL, created REAL NOT NULL,
            PRIMARY KEY(user_id,target_id));
        CREATE TABLE IF NOT EXISTS social_recent (
            user_id INTEGER NOT NULL, target_id INTEGER NOT NULL, played_at REAL NOT NULL,
            games INTEGER NOT NULL DEFAULT 1, PRIMARY KEY(user_id,target_id));
        CREATE TABLE IF NOT EXISTS social_matches (
            match_id TEXT PRIMARY KEY, finished REAL NOT NULL);
        CREATE TABLE IF NOT EXISTS social_match_stats (
            match_id TEXT NOT NULL, user_id INTEGER NOT NULL, wins INTEGER NOT NULL,
            wolf_victims INTEGER NOT NULL, devoured INTEGER NOT NULL, executed INTEGER NOT NULL,
            PRIMARY KEY(match_id,user_id));
        CREATE TABLE IF NOT EXISTS social_invitations (
            id INTEGER PRIMARY KEY AUTOINCREMENT, room_id TEXT NOT NULL, code TEXT NOT NULL,
            sender_id INTEGER NOT NULL, target_id INTEGER NOT NULL, status TEXT NOT NULL DEFAULT 'active',
            seen INTEGER NOT NULL DEFAULT 0, created REAL NOT NULL, expires REAL NOT NULL,
            UNIQUE(room_id,sender_id,target_id));
        CREATE TABLE IF NOT EXISTS social_notifications (
            id INTEGER PRIMARY KEY AUTOINCREMENT, user_id INTEGER NOT NULL, kind TEXT NOT NULL,
            source_id INTEGER NOT NULL, actor_id INTEGER NOT NULL, created REAL NOT NULL,
            seen INTEGER NOT NULL DEFAULT 0, mail_state TEXT NOT NULL DEFAULT 'none',
            UNIQUE(user_id,kind,source_id,created));
        CREATE TABLE IF NOT EXISTS social_receipts (
            notification_id INTEGER NOT NULL, device_id TEXT NOT NULL,
            PRIMARY KEY(notification_id,device_id));
        CREATE TABLE IF NOT EXISTS social_devices (
            digest TEXT PRIMARY KEY,user_id INTEGER NOT NULL,device_id TEXT NOT NULL,
            expires REAL NOT NULL,UNIQUE(user_id,device_id));
        CREATE INDEX IF NOT EXISTS social_invite_target ON social_invitations(target_id,status);
        CREATE INDEX IF NOT EXISTS social_notification_target ON social_notifications(user_id,seen);
        """)
        # Game engines live only in this process. Old invitations cannot survive restart.
        c.execute("UPDATE social_invitations SET status='closed' WHERE status='active'")
        c.execute(
            "UPDATE social_notifications SET mail_state='cancelled' WHERE mail_state='pending'"
        )


def preference(c, uid):
    c.execute(
        "INSERT OR IGNORE INTO social_preferences(user_id,optout) VALUES(?,?)",
        (uid, secrets.token_urlsafe(32)),
    )
    return dict(
        c.execute("SELECT * FROM social_preferences WHERE user_id=?", (uid,)).fetchone()
    )


def blocked(c, a, b):
    return bool(
        c.execute(
            "SELECT 1 FROM social_blocks WHERE (user_id=? AND target_id=?) OR (user_id=? AND target_id=?)",
            (a, b, b, a),
        ).fetchone()
    )


def friends(c, a, b):
    return bool(
        c.execute(
            "SELECT 1 FROM social_friends WHERE low_id=? AND high_id=? AND status='accepted'",
            (min(a, b), max(a, b)),
        ).fetchone()
    ) and not blocked(c, a, b)


def require_target(c, uid):
    if not 0 < uid < 2**63:
        raise HTTPException(404, "Joueur introuvable.")
    row = c.execute(
        "SELECT id,nickname,role,email_verified,banned FROM users WHERE id=?", (uid,)
    ).fetchone()
    if not row or row["banned"] or not row["email_verified"]:
        raise HTTPException(404, "Joueur introuvable.")
    return row


def profile_data(c, viewer, target):
    person = require_target(c, target)
    pref = preference(c, target)
    is_friend = friends(c, viewer, target)
    mine = viewer == target
    visible = (
        mine
        or not blocked(c, viewer, target)
        and (pref["stats_visibility"] == "public" or is_friend)
    )
    relationship = c.execute(
        "SELECT * FROM social_friends WHERE low_id=? AND high_id=?",
        (min(viewer, target), max(viewer, target)),
    ).fetchone()
    result = {
        "id": target,
        "nickname": person["nickname"],
        "verified": person["role"] == "admin",
        "is_self": mine,
        "is_friend": is_friend,
        "stats_visible": visible,
        "blocked_by_me": bool(
            c.execute(
                "SELECT 1 FROM social_blocks WHERE user_id=? AND target_id=?",
                (viewer, target),
            ).fetchone()
        ),
        "relationship": relationship["status"] if relationship else "none",
        "request_incoming": bool(
            relationship
            and relationship["status"] == "pending"
            and relationship["sender_id"] != viewer
        ),
    }
    if visible:
        result["stats"] = dict(
            c.execute(
                """SELECT COUNT(*) AS games,COALESCE(SUM(wins),0) AS wins,
            COALESCE(SUM(wolf_victims),0) AS wolf_victims,COALESCE(SUM(devoured),0) AS devoured,
            COALESCE(SUM(executed),0) AS executed FROM social_match_stats WHERE user_id=?""",
                (target,),
            ).fetchone()
        )
    if mine:
        result["preferences"] = {
            k: pref[k]
            for k in [
                "stats_visibility",
                "invite_emails",
                "phone_notifications",
                "auto_invite",
            ]
        }
    return result


@router.get("/profiles/{target}")
def profile(target: int, *, user: User, db: Database):
    with db.db() as c:
        return profile_data(c, user["id"], target)


@router.get("/me")
def my_profile(*, user: User, db: Database):
    with db.db() as c:
        return profile_data(c, user["id"], user["id"])


class Preferences(BaseModel):
    stats_visibility: Literal["public", "friends"] = "public"
    invite_emails: bool = True
    phone_notifications: bool = False
    auto_invite: bool = True


@router.put("/preferences")
def preferences(data: Preferences, *, user: User, db: Database):
    with db.db() as c:
        preference(c, user["id"])
        c.execute(
            "UPDATE social_preferences SET stats_visibility=?,invite_emails=?,phone_notifications=?,auto_invite=? WHERE user_id=?",
            (
                data.stats_visibility,
                int(data.invite_emails),
                int(data.phone_notifications),
                int(data.auto_invite),
                user["id"],
            ),
        )
    return {"ok": True}


@router.get("/summary")
def summary(request: Request, *, user: User, db: Database):
    expire_invitations(db, request.app.state.rooms)
    with db.db() as c:
        preference(c, user["id"])
        c.execute(
            "UPDATE social_preferences SET last_seen=? WHERE user_id=?",
            (time.time(), user["id"]),
        )
        pending = sum(
            1
            for r in c.execute(
                "SELECT f.sender_id FROM social_friends f JOIN users u ON u.id=f.sender_id WHERE f.status='pending' AND f.sender_id!=? AND (f.low_id=? OR f.high_id=?) AND u.banned=0 AND u.email_verified=1",
                (user["id"], user["id"], user["id"]),
            ).fetchall()
            if not blocked(c, user["id"], r["sender_id"])
        )
        invitations = c.execute(
            "SELECT COUNT(*) FROM social_invitations WHERE target_id=? AND status='active'",
            (user["id"],),
        ).fetchone()[0]
        return {
            "user_id": user["id"],
            "nickname": user["nickname"],
            "friend_requests": pending,
            "invitations": invitations,
            "phone_notifications": bool(
                preference(c, user["id"])["phone_notifications"]
            ),
        }


@router.get("/friends")
def friend_list(*, user: User, db: Database):
    with db.db() as c:
        rows = c.execute(
            """SELECT f.*,u.id,u.nickname,u.role,p.last_seen FROM social_friends f
            JOIN users u ON u.id=CASE WHEN f.low_id=? THEN f.high_id ELSE f.low_id END
            LEFT JOIN social_preferences p ON p.user_id=u.id
            WHERE (f.low_id=? OR f.high_id=?) AND f.status IN ('accepted','pending') AND u.banned=0 ORDER BY f.updated DESC LIMIT 200""",
            (user["id"], user["id"], user["id"]),
        ).fetchall()
        return {
            "friends": [
                {
                    "id": r["id"],
                    "nickname": r["nickname"],
                    "verified": r["role"] == "admin",
                    "status": r["status"],
                    "incoming": r["sender_id"] != user["id"],
                    "online": r["status"] == "accepted"
                    and (r["last_seen"] or 0) > time.time() - 90,
                }
                for r in rows
                if not blocked(c, user["id"], r["id"])
            ]
        }


@router.get("/recent")
def recent(*, user: User, db: Database):
    with db.db() as c:
        rows = c.execute(
            "SELECT r.*,u.nickname FROM social_recent r JOIN users u ON u.id=r.target_id WHERE r.user_id=? AND u.banned=0 ORDER BY r.played_at DESC LIMIT 100",
            (user["id"],),
        ).fetchall()
        return {
            "players": [
                {
                    "id": r["target_id"],
                    "nickname": r["nickname"],
                    "played_at": r["played_at"],
                    "games": r["games"],
                    "is_friend": friends(c, user["id"], r["target_id"]),
                }
                for r in rows
                if not blocked(c, user["id"], r["target_id"])
            ]
        }


class FriendAction(BaseModel):
    action: Literal["request", "accept", "decline", "cancel", "remove"]


@router.post("/friends/{target}")
def friend_action(target: int, data: FriendAction, *, user: User, db: Database):
    uid = user["id"]
    if uid == target:
        raise HTTPException(422, "Tu ne peux pas t’ajouter toi-même.")
    now = time.time()
    with db.db() as c:
        c.execute("BEGIN IMMEDIATE")
        require_target(c, target)
        if blocked(c, uid, target):
            raise HTTPException(403, "Cette relation est indisponible.")
        low, high = min(uid, target), max(uid, target)
        row = c.execute(
            "SELECT * FROM social_friends WHERE low_id=? AND high_id=?", (low, high)
        ).fetchone()
        if data.action == "request":
            db.limit(("friend-request", uid), 20, 86400)
            if row and row["status"] in ["pending", "accepted"]:
                raise HTTPException(409, "Une demande ou une amitié existe déjà.")
            if row and now - row["updated"] < 86400:
                raise HTTPException(429, "Attends avant de renouveler cette demande.")
            c.execute(
                "INSERT OR REPLACE INTO social_friends VALUES(?,?,?,'pending',?,?)",
                (low, high, uid, now, now),
            )
            c.execute(
                "INSERT INTO social_notifications(user_id,kind,source_id,actor_id,created) VALUES(?,'friend',?,?,?)",
                (target, uid, uid, now),
            )
        elif data.action == "accept":
            if not row or row["status"] != "pending" or row["sender_id"] == uid:
                raise HTTPException(409, "Aucune demande reçue à accepter.")
            c.execute(
                "UPDATE social_friends SET status='accepted',updated=? WHERE low_id=? AND high_id=?",
                (now, low, high),
            )
        elif data.action in ["decline", "cancel"]:
            if (
                not row
                or row["status"] != "pending"
                or (data.action == "cancel") != (row["sender_id"] == uid)
            ):
                raise HTTPException(409, "Demande indisponible.")
            c.execute(
                "UPDATE social_friends SET status='declined',updated=? WHERE low_id=? AND high_id=?",
                (now, low, high),
            )
        else:
            c.execute(
                "UPDATE social_friends SET status='removed',updated=? WHERE low_id=? AND high_id=?",
                (now, low, high),
            )
        if data.action != "request":
            c.execute(
                "UPDATE social_notifications SET seen=1 WHERE kind='friend' AND ((user_id=? AND actor_id=?) OR (user_id=? AND actor_id=?))",
                (uid, target, target, uid),
            )
    return {"ok": True}


class BlockAction(BaseModel):
    blocked: bool


@router.put("/blocks/{target}")
def block(target: int, data: BlockAction, *, user: User, db: Database):
    if target == user["id"]:
        raise HTTPException(422, "Action impossible sur ton compte.")
    with db.db() as c:
        require_target(c, target)
        if data.blocked:
            c.execute(
                "INSERT OR IGNORE INTO social_blocks VALUES(?,?,?)",
                (user["id"], target, time.time()),
            )
            c.execute(
                "UPDATE social_friends SET status='removed',updated=? WHERE low_id=? AND high_id=?",
                (time.time(), min(target, user["id"]), max(target, user["id"])),
            )
            c.execute(
                "UPDATE social_invitations SET status='cancelled' WHERE status='active' AND ((sender_id=? AND target_id=?) OR (sender_id=? AND target_id=?))",
                (user["id"], target, target, user["id"]),
            )
        else:
            c.execute(
                "DELETE FROM social_blocks WHERE user_id=? AND target_id=?",
                (user["id"], target),
            )
    return {"ok": True}


def room_summary(engine):
    snapshot = engine.snapshot
    phase = snapshot.get("phase", "lobby")
    count = len(snapshot.get("players", []))
    return {
        "code": snapshot["code"],
        "room_id": engine.social_id,
        "title": engine.title,
        "host": snapshot.get("host", "MDJ"),
        "owner_id": engine.owner_id,
        "theme": snapshot.get("pack_label", snapshot.get("visual_pack", "classic")),
        "environment": snapshot.get("visual_pack", "classic"),
        "players": count,
        "capacity": 20,
        "phase": phase,
        "joinable": phase == "lobby"
        and not snapshot.get("locked", False)
        and count < 20,
        "public": engine.public_room,
    }


@router.get("/rooms")
def public_rooms(request: Request, *, user: User, db: Database):
    result = []
    with db.db() as c:
        for code in list(request.app.state.rooms.engines):
            engine = request.app.state.rooms.get(code)
            if (
                engine
                and engine.public_room
                and (not engine.owner_id or not blocked(c, user["id"], engine.owner_id))
            ):
                result.append(room_summary(engine))
    return {"rooms": result[:100]}


def invite(db, engine, sender, target):
    now = time.time()
    if engine.closed or engine.snapshot.get("phase") != "lobby":
        raise HTTPException(409, "Le salon ne reçoit plus d’invitations.")
    with db.db() as c:
        c.execute("BEGIN IMMEDIATE")
        require_target(c, target)
        if not friends(c, sender, target):
            raise HTTPException(403, "Invitations réservées aux amis.")
        if c.execute(
            "SELECT 1 FROM social_invitations WHERE room_id=? AND sender_id=? AND target_id=?",
            (engine.social_id, sender, target),
        ).fetchone():
            return
        # One invitation per pair per half-hour, including newly recreated rooms.
        if c.execute(
            "SELECT 1 FROM social_invitations WHERE sender_id=? AND target_id=? AND created>?",
            (sender, target, now - 1800),
        ).fetchone():
            raise HTTPException(429, "Cet ami a déjà été invité récemment.")
        row = c.execute(
            "INSERT INTO social_invitations(room_id,code,sender_id,target_id,created,expires) VALUES(?,?,?,?,?,?)",
            (
                engine.social_id,
                engine.snapshot["code"],
                sender,
                target,
                now,
                now + 7200,
            ),
        )
        preference(c, target)
        c.execute(
            "INSERT INTO social_notifications(user_id,kind,source_id,actor_id,created,mail_state) VALUES(?,'invitation',?,?,?,'pending')",
            (target, row.lastrowid, sender, now),
        )


def invite_friends(db, engine):
    if not engine.owner_id:
        return
    with db.db() as c:
        pref = preference(c, engine.owner_id)
        targets = [
            r[0]
            for r in c.execute(
                "SELECT CASE WHEN low_id=? THEN high_id ELSE low_id END FROM social_friends WHERE status='accepted' AND (low_id=? OR high_id=?) LIMIT 200",
                (engine.owner_id, engine.owner_id, engine.owner_id),
            )
        ]
    if pref["auto_invite"]:
        for target in targets:
            try:
                invite(db, engine, engine.owner_id, target)
            except HTTPException:
                pass


class InviteAction(BaseModel):
    target_id: int = Field(gt=0)


@router.post("/rooms/{code}/invitations")
def send_invite(
    code: str, data: InviteAction, request: Request, *, user: User, db: Database
):
    engine = request.app.state.rooms.get(code)
    if not engine or engine.owner_id != user["id"]:
        raise HTTPException(403, "Seul le MDJ peut inviter dans ce salon.")
    with db.db() as c:
        if preference(c, user["id"])["optout"] != engine.owner_stamp:
            raise HTTPException(403, "Ce salon appartient à un ancien compte.")
    db.limit(("invite", user["id"]), 200, 3600)
    invite(db, engine, user["id"], data.target_id)
    return {"ok": True}


def expire_invitations(db, rooms):
    with db.db() as c:
        c.execute(
            "UPDATE social_invitations SET status='cancelled' WHERE status='active' AND sender_id IN (SELECT id FROM users WHERE banned=1)"
        )
        for row in c.execute(
            "SELECT DISTINCT room_id,code FROM social_invitations WHERE status='active'"
        ).fetchall():
            engine = rooms.get(row["code"])
            status = (
                "closed"
                if not engine or engine.social_id != row["room_id"]
                else "started"
                if engine.snapshot.get("phase") != "lobby"
                else None
            )
            if status:
                c.execute(
                    "UPDATE social_invitations SET status=? WHERE room_id=? AND status='active'",
                    (status, row["room_id"]),
                )
        c.execute(
            "UPDATE social_invitations SET status='expired' WHERE status='active' AND expires<?",
            (time.time(),),
        )


@router.get("/invitations")
def invitations(request: Request, *, user: User, db: Database):
    expire_invitations(db, request.app.state.rooms)
    with db.db() as c:
        rows = c.execute(
            "SELECT i.*,u.nickname FROM social_invitations i JOIN users u ON u.id=i.sender_id WHERE target_id=? ORDER BY created DESC LIMIT 100",
            (user["id"],),
        ).fetchall()
        result = []
        for r in rows:
            engine = request.app.state.rooms.get(r["code"])
            entry = {
                k: r[k]
                for k in ["id", "nickname", "status", "seen", "created", "expires"]
            }
            if r["status"] == "active" and engine and engine.social_id == r["room_id"]:
                entry["room"] = room_summary(engine)
            result.append(entry)
    return {"invitations": result}


@router.post("/invitations/{invite_id}/seen")
def invitation_seen(invite_id: int, *, user: User, db: Database):
    with db.db() as c:
        c.execute(
            "UPDATE social_invitations SET seen=1 WHERE id=? AND target_id=?",
            (invite_id, user["id"]),
        )
        c.execute(
            "UPDATE social_notifications SET seen=1 WHERE user_id=? AND kind='invitation' AND source_id=?",
            (user["id"], invite_id),
        )
    return {"ok": True}


@router.post("/invitations/{invite_id}/decline")
def decline_invitation(invite_id: int, *, user: User, db: Database):
    with db.db() as c:
        c.execute(
            "UPDATE social_invitations SET status='declined',seen=1 WHERE id=? AND target_id=? AND status='active'",
            (invite_id, user["id"]),
        )
        c.execute(
            "UPDATE social_notifications SET seen=1 WHERE user_id=? AND kind='invitation' AND source_id=?",
            (user["id"], invite_id),
        )
    return {"ok": True}


def notification_active(c, n):
    actor = c.execute(
        "SELECT banned,email_verified FROM users WHERE id=?", (n["actor_id"],)
    ).fetchone()
    if not actor or actor["banned"] or not actor["email_verified"]:
        return False
    if n["seen"] or blocked(c, n["user_id"], n["actor_id"]):
        return False
    if n["kind"] == "invitation":
        return bool(
            c.execute(
                "SELECT 1 FROM social_invitations WHERE id=? AND target_id=? AND status='active' AND expires>?",
                (n["source_id"], n["user_id"], time.time()),
            ).fetchone()
        )
    return bool(
        c.execute(
            "SELECT 1 FROM social_friends WHERE low_id=? AND high_id=? AND status='pending' AND sender_id=?",
            (
                min(n["user_id"], n["actor_id"]),
                max(n["user_id"], n["actor_id"]),
                n["actor_id"],
            ),
        ).fetchone()
    )


@router.get("/notifications/pending")
def notifications(request: Request, device_id: str, *, user: User, db: Database):
    if len(device_id) != 32 or any(ch not in "0123456789abcdef" for ch in device_id):
        raise HTTPException(422, "Appareil invalide.")
    expire_invitations(db, request.app.state.rooms)
    with db.db() as c:
        pref = preference(c, user["id"])
        rows = c.execute(
            "SELECT n.*,u.nickname FROM social_notifications n JOIN users u ON u.id=n.actor_id WHERE n.user_id=? ORDER BY n.id DESC LIMIT 200",
            (user["id"],),
        ).fetchall()
        pending = []
        cancelled = []
        for n in rows:
            if not notification_active(c, n):
                cancelled.append(n["id"])
                continue
            if (
                pref["phone_notifications"]
                and not c.execute(
                    "SELECT 1 FROM social_receipts WHERE notification_id=? AND device_id=?",
                    (n["id"], device_id),
                ).fetchone()
            ):
                pending.append(
                    {
                        "id": n["id"],
                        "kind": n["kind"],
                        "title": "Le village vous attend"
                        if n["kind"] == "invitation"
                        else "Une nouvelle amitié ?",
                        "body": f"{n['nickname']} vous invite à jouer."
                        if n["kind"] == "invitation"
                        else f"{n['nickname']} souhaite devenir votre ami.",
                    }
                )
        return {
            "notifications": pending[:30],
            "cancelled_ids": cancelled,
            "enabled": bool(pref["phone_notifications"]),
        }


class Receipt(BaseModel):
    device_id: str = Field(pattern=r"^[a-f0-9]{32}$")


@router.post("/devices")
def register_device(data: Receipt, *, user: User, db: Database):
    db.limit(("social-device", user["id"]), 30, 3600)
    token = secrets.token_urlsafe(32)
    with db.db() as c:
        c.execute("DELETE FROM social_devices WHERE expires<?", (time.time(),))
        count = c.execute(
            "SELECT COUNT(*) FROM social_devices WHERE user_id=?", (user["id"],)
        ).fetchone()[0]
        existing = c.execute(
            "SELECT 1 FROM social_devices WHERE user_id=? AND device_id=?",
            (user["id"], data.device_id),
        ).fetchone()
        if count >= 10 and not existing:
            raise HTTPException(429, "Trop d’appareils associés.")
        c.execute(
            "DELETE FROM social_devices WHERE user_id=? AND device_id=?",
            (user["id"], data.device_id),
        )
        c.execute(
            "INSERT INTO social_devices VALUES(?,?,?,?)",
            (
                hashlib.sha256(token.encode()).hexdigest(),
                user["id"],
                data.device_id,
                time.time() + 30 * 86400,
            ),
        )
    return {
        "background_token": token,
        "expires_at": time.time() + 30 * 86400,
        "user_id": user["id"],
    }


def device_identity(request: Request, db):
    token = request.headers.get("authorization", "").removeprefix("Bearer ")
    with db.db() as c:
        device = c.execute(
            "SELECT d.*,u.banned,u.email_verified FROM social_devices d JOIN users u ON u.id=d.user_id WHERE digest=? AND expires>?",
            (hashlib.sha256(token.encode()).hexdigest(), time.time()),
        ).fetchone()
    if not device or device["banned"] or not device["email_verified"]:
        raise HTTPException(401, "Appareil déconnecté.")
    return device


@router.get("/device/notifications")
def device_notifications(request: Request, *, db: Database):
    device = device_identity(request, db)
    return notifications(
        request, device["device_id"], user={"id": device["user_id"]}, db=db
    )


@router.delete("/device")
def revoke_background_device(request: Request, *, db: Database):
    device = device_identity(request, db)
    with db.db() as c:
        c.execute("DELETE FROM social_devices WHERE digest=?", (device["digest"],))
    return {"ok": True}


@router.post("/device/notifications/{notification_id}/delivered")
def device_delivered(notification_id: int, request: Request, *, db: Database):
    device = device_identity(request, db)
    return notification_delivered(
        notification_id,
        Receipt(device_id=device["device_id"]),
        user={"id": device["user_id"]},
        db=db,
    )


@router.delete("/devices/{device_id}")
def revoke_device(device_id: str, *, user: User, db: Database):
    with db.db() as c:
        c.execute(
            "DELETE FROM social_devices WHERE user_id=? AND device_id=?",
            (user["id"], device_id),
        )
    return {"ok": True}


@router.post("/notifications/{notification_id}/delivered")
def notification_delivered(
    notification_id: int, data: Receipt, *, user: User, db: Database
):
    with db.db() as c:
        if c.execute(
            "SELECT 1 FROM social_notifications WHERE id=? AND user_id=?",
            (notification_id, user["id"]),
        ).fetchone():
            c.execute(
                "INSERT OR IGNORE INTO social_receipts VALUES(?,?)",
                (notification_id, data.device_id),
            )
    return {"ok": True}


def claim_player(db, engine, player_id, user_id):
    existing = engine.accounts.get(player_id)
    if existing is not None and existing != user_id:
        raise ValueError("Reconnecte-toi avec le compte associé à cette place.")
    if user_id is not None:
        with db.db() as c:
            stamp = preference(c, user_id)["optout"]
        if (
            player_id in engine.account_stamps
            and engine.account_stamps[player_id] != stamp
        ):
            raise ValueError("Compte associé indisponible.")
        if user_id in engine.accounts.values() and existing != user_id:
            raise ValueError("Ce compte occupe déjà une place dans ce salon.")
        if engine.owner_id == user_id:
            raise ValueError("Le MDJ ne peut pas occuper une place de joueur.")
        engine.accounts[player_id] = user_id
        engine.account_stamps[player_id] = stamp
        with db.db() as c:
            c.execute(
                "UPDATE social_invitations SET status='accepted',seen=1 WHERE room_id=? AND target_id=? AND status='active'",
                (engine.social_id, user_id),
            )


def sync_match(db, engine):
    game = engine.snapshot.get("game") or {}
    if engine.snapshot.get("phase") == "lobby":
        return
    with db.db() as c:
        valid_accounts = {}
        for player, uid in engine.accounts.items():
            current = c.execute(
                "SELECT optout FROM social_preferences WHERE user_id=?", (uid,)
            ).fetchone()
            if current and current["optout"] == engine.account_stamps.get(player):
                valid_accounts[player] = uid
        participants = set(valid_accounts.values())
        owner = (
            c.execute(
                "SELECT optout FROM social_preferences WHERE user_id=?",
                (engine.owner_id,),
            ).fetchone()
            if engine.owner_id
            else None
        )
        if owner and owner["optout"] == engine.owner_stamp:
            participants.add(engine.owner_id)
        if not engine.recent_saved:
            for uid in participants:
                for other in participants - {uid}:
                    c.execute(
                        "INSERT INTO social_recent VALUES(?,?,?,1) ON CONFLICT(user_id,target_id) DO UPDATE SET played_at=excluded.played_at,games=games+1",
                        (uid, other, time.time()),
                    )
            engine.recent_saved = True
        if game.get("phase") != "ended" or not game.get("history"):
            return
        c.execute("BEGIN IMMEDIATE" if not c.in_transaction else "SELECT 1")
        if c.execute(
            "SELECT 1 FROM social_matches WHERE match_id=?", (engine.social_id,)
        ).fetchone():
            return
        c.execute(
            "INSERT INTO social_matches VALUES(?,?)", (engine.social_id, time.time())
        )
        history = game["history"]
        winners = set(game.get("winner_ids", []))
        wolf_roles = {"werewolf", "alpha_wolf", "white_wolf", "wolf_father"}
        for player, uid in valid_accounts.items():
            if not c.execute("SELECT 1 FROM users WHERE id=?", (uid,)).fetchone():
                continue
            deaths = [
                e
                for e in history
                if e.get("kind") == "death" and e.get("target") == player
            ]
            kills = set()
            for death in (
                e
                for e in history
                if e.get("kind") == "death"
                and e.get("source_cause", e.get("cause")) in ["night", "white_wolf"]
            ):
                actions = [
                    e
                    for e in history
                    if e.get("kind") == "action"
                    and e.get("actor") == player
                    and e.get("night") == death.get("night")
                    and e.get("action")
                    in ["wolves.choose", "alpha.choose", "white_wolf.choose"]
                    and (e.get("camp") == "wolves" or e.get("role") in wolf_roles)
                ]
                last = {}
                for action in actions:
                    last[action["action"]] = action
                if any(
                    death.get("redirected_from", death["target"]) == a.get("target")
                    or death.get("redirected_from", death["target"])
                    in a.get("targets", [])
                    for a in last.values()
                ):
                    kills.add((death.get("night"), death["target"]))
            c.execute(
                "INSERT INTO social_match_stats VALUES(?,?,?,?,?,?)",
                (
                    engine.social_id,
                    uid,
                    int(player in winners),
                    len(kills),
                    int(
                        any(
                            e.get("source_cause", e.get("cause"))
                            in ["night", "white_wolf"]
                            for e in deaths
                        )
                    ),
                    int(any(e.get("cause") == "vote" for e in deaths)),
                ),
            )


def close_room(db, engine):
    with db.db() as c:
        c.execute(
            "UPDATE social_invitations SET status='closed' WHERE room_id=? AND status='active'",
            (engine.social_id,),
        )
