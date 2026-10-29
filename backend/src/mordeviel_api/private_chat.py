"""Friend-only conversations erased as a whole 24 hours after their first message."""
import time

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field

from .social import Database, User, friends, require_target
from .stickers import validate_sticker

router = APIRouter(prefix="/social/chats", tags=["private-chat"])


def initialize(db):
    with db.db() as c:
        c.executescript("""
        CREATE TABLE IF NOT EXISTS friend_chat_windows (
            low_id INTEGER NOT NULL, high_id INTEGER NOT NULL, expires REAL NOT NULL,
            PRIMARY KEY(low_id,high_id));
        CREATE TABLE IF NOT EXISTS friend_chat_messages (
            id INTEGER PRIMARY KEY AUTOINCREMENT, low_id INTEGER NOT NULL,
            high_id INTEGER NOT NULL, sender_id INTEGER NOT NULL,
            text TEXT NOT NULL, created REAL NOT NULL);
        CREATE INDEX IF NOT EXISTS friend_chat_pair ON friend_chat_messages(low_id,high_id,id);
        """)
    purge(db)


def purge(db):
    with db.db() as c:
        c.execute("DELETE FROM friend_chat_messages WHERE EXISTS (SELECT 1 FROM friend_chat_windows w WHERE w.low_id=friend_chat_messages.low_id AND w.high_id=friend_chat_messages.high_id AND w.expires<=?)", (time.time(),))
        c.execute("DELETE FROM friend_chat_windows WHERE expires<=?", (time.time(),))


def access(c, viewer, target):
    person = require_target(c, target)
    if viewer == target or not friends(c, viewer, target):
        raise HTTPException(403, "Cette discussion est réservée à deux amis. Vérifie que votre amitié est toujours active et qu’aucun blocage n’est appliqué.")
    return person, (min(viewer, target), max(viewer, target))


@router.get("/{target}")
def history(target: int, *, user: User, db: Database):
    purge(db)
    with db.db() as c:
        person, pair = access(c, user["id"], target)
        window = c.execute("SELECT expires FROM friend_chat_windows WHERE low_id=? AND high_id=?", pair).fetchone()
        rows = c.execute("SELECT id,sender_id,text,created FROM friend_chat_messages WHERE low_id=? AND high_id=? ORDER BY id DESC LIMIT 100", pair).fetchall()
    return {"friend": {"id": target, "nickname": person["nickname"]}, "viewer_id": user["id"],
            "reset_at": window["expires"] if window else None, "messages": [dict(r) for r in reversed(rows)]}


class Message(BaseModel):
    text: str = Field(min_length=1, max_length=300)


@router.post("/{target}", status_code=201)
def send(target: int, data: Message, *, user: User, db: Database):
    text = data.text.strip()
    if not text:
        raise HTTPException(422, "Écris un message avant de l’envoyer.")
    try:
        validate_sticker(text)
    except ValueError as error:
        raise HTTPException(422, str(error)) from None
    db.limit(("friend-chat", user["id"]), 30, 60)
    purge(db)
    with db.db() as c:
        c.execute("BEGIN IMMEDIATE")
        _, pair = access(c, user["id"], target)
        now = time.time()
        window = c.execute("SELECT expires FROM friend_chat_windows WHERE low_id=? AND high_id=?", pair).fetchone()
        if window and window['expires'] <= now:
            c.execute("DELETE FROM friend_chat_messages WHERE low_id=? AND high_id=?", pair)
            c.execute("DELETE FROM friend_chat_windows WHERE low_id=? AND high_id=?", pair)
        c.execute("INSERT OR IGNORE INTO friend_chat_windows VALUES(?,?,?)", (*pair, now + 86400))
        c.execute("INSERT INTO friend_chat_messages(low_id,high_id,sender_id,text,created) VALUES(?,?,?,?,?)", (*pair, user["id"], text, now))
        # Keep storage bounded, even in a busy 24-hour conversation.
        c.execute("DELETE FROM friend_chat_messages WHERE low_id=? AND high_id=? AND id NOT IN (SELECT id FROM friend_chat_messages WHERE low_id=? AND high_id=? ORDER BY id DESC LIMIT 500)", (*pair, *pair))
    return {"ok": True}
