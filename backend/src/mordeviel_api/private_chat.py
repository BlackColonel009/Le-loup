"""Friend-only conversations erased as a whole 24 hours after their first message."""
import time

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field

from .chat_replies import add_reply_column, require_reply, with_replies
from .social import Database, User, friends, require_target
from .stickers import require_sticker_access, validate_sticker

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
        CREATE INDEX IF NOT EXISTS friend_chat_recipient_high ON friend_chat_messages(high_id,id);
        CREATE TABLE IF NOT EXISTS friend_chat_reads (
            user_id INTEGER NOT NULL, friend_id INTEGER NOT NULL, last_id INTEGER NOT NULL DEFAULT 0,
            PRIMARY KEY(user_id,friend_id));
        """)
        add_reply_column(c, "friend_chat_messages")
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


@router.get('/inbox')
def inbox(*, user: User, db: Database):
    from .avatars import avatar_in
    purge(db)
    with db.db() as c:
        rows = c.execute('''SELECT m.sender_id,MAX(m.id) AS last_id,COUNT(*) AS unread_count
            FROM friend_chat_messages m
            LEFT JOIN friend_chat_reads r ON r.user_id=? AND r.friend_id=m.sender_id
            WHERE (m.low_id=? OR m.high_id=?) AND m.sender_id!=? AND m.id>COALESCE(r.last_id,0)
            GROUP BY m.sender_id ORDER BY last_id DESC LIMIT 100''', (user['id'],)*4).fetchall()
        conversations = []
        for row in rows:
            if not friends(c, user['id'], row['sender_id']):
                continue
            person = c.execute('SELECT nickname,banned,email_verified FROM users WHERE id=?', (row['sender_id'],)).fetchone()
            if not person or person['banned'] or not person['email_verified']:
                continue
            message = c.execute('SELECT text,created FROM friend_chat_messages WHERE id=?', (row['last_id'],)).fetchone()
            conversations.append({'friend_id': row['sender_id'], 'nickname': person['nickname'],
                'avatar': avatar_in(c, row['sender_id']), 'last_id': row['last_id'],
                'text': message['text'], 'created': message['created'], 'unread_count': row['unread_count']})
        return {'viewer_id': user['id'], 'conversations': conversations}


class ReadMessages(BaseModel):
    through_id: int = Field(ge=0)


@router.post('/{target}/read')
def read_messages(target: int, data: ReadMessages, *, user: User, db: Database):
    notifications = []
    with db.db() as c:
        _, pair = access(c, user['id'], target)
        cutoff = c.execute('SELECT MAX(id) FROM friend_chat_messages WHERE low_id=? AND high_id=? AND id<=?', (*pair, data.through_id)).fetchone()[0]
        if cutoff is not None:
            notifications = [r[0] for r in c.execute("SELECT id FROM social_notifications WHERE user_id=? AND actor_id=? AND kind='message' AND source_id<=? AND seen=0 LIMIT 500", (user['id'], target, cutoff))]
            c.execute('INSERT INTO friend_chat_reads VALUES(?,?,?) ON CONFLICT(user_id,friend_id) DO UPDATE SET last_id=MAX(last_id,excluded.last_id)', (user['id'], target, cutoff))
            c.execute("UPDATE social_notifications SET seen=1 WHERE user_id=? AND actor_id=? AND kind='message' AND source_id<=?", (user['id'], target, cutoff))
    return {'ok': True, 'through_id': cutoff or 0, 'notification_ids': notifications}


@router.get("/{target}")
def history(target: int, *, user: User, db: Database):
    purge(db)
    with db.db() as c:
        person, pair = access(c, user["id"], target)
        window = c.execute("SELECT expires FROM friend_chat_windows WHERE low_id=? AND high_id=?", pair).fetchone()
        rows = c.execute("SELECT id,sender_id,text,created,reply_to FROM friend_chat_messages WHERE low_id=? AND high_id=? ORDER BY id DESC LIMIT 100", pair).fetchall()
        messages = with_replies(c, reversed(rows), pair)
    return {"friend": {"id": target, "nickname": person["nickname"]}, "viewer_id": user["id"],
            "reset_at": window["expires"] if window else None, "messages": messages}


class Message(BaseModel):
    text: str = Field(min_length=1, max_length=300)
    reply_to: int | None = Field(default=None, gt=0)


@router.post("/{target}", status_code=201)
def send(target: int, data: Message, *, user: User, db: Database):
    text = data.text.strip()
    if not text:
        raise HTTPException(422, "Écris un message avant de l’envoyer.")
    try:
        sticker = validate_sticker(text)
    except ValueError as error:
        raise HTTPException(422, str(error)) from None
    db.limit(("friend-chat", user["id"]), 30, 60)
    purge(db)
    with db.db() as c:
        c.execute("BEGIN IMMEDIATE")
        _, pair = access(c, user["id"], target)
        require_sticker_access(c, user['id'], sticker)
        now = time.time()
        window = c.execute("SELECT expires FROM friend_chat_windows WHERE low_id=? AND high_id=?", pair).fetchone()
        if window and window['expires'] <= now:
            c.execute("DELETE FROM friend_chat_messages WHERE low_id=? AND high_id=?", pair)
            c.execute("DELETE FROM friend_chat_windows WHERE low_id=? AND high_id=?", pair)
        c.execute("INSERT OR IGNORE INTO friend_chat_windows VALUES(?,?,?)", (*pair, now + 86400))
        require_reply(c, data.reply_to, pair)
        inserted = c.execute("INSERT INTO friend_chat_messages(low_id,high_id,sender_id,text,created,reply_to) VALUES(?,?,?,?,?,?)", (*pair, user["id"], text, now, data.reply_to))
        c.execute("INSERT INTO social_notifications(user_id,kind,source_id,actor_id,created) VALUES(?,'message',?,?,?)", (target, inserted.lastrowid, user['id'], now))
        # Keep storage bounded, even in a busy 24-hour conversation.
        c.execute("DELETE FROM friend_chat_messages WHERE low_id=? AND high_id=? AND id NOT IN (SELECT id FROM friend_chat_messages WHERE low_id=? AND high_id=? ORDER BY id DESC LIMIT 500)", (*pair, *pair))
    return {"ok": True}
