"""Resolve references on the server; never accept a client-supplied quotation."""

from fastapi import HTTPException


def add_reply_column(connection, table):
    if table not in {"messages", "friend_chat_messages"}:
        raise ValueError("Unknown conversation")
    if "reply_to" not in {r["name"] for r in connection.execute(f"PRAGMA table_info({table})")}:
        connection.execute(f"ALTER TABLE {table} ADD COLUMN reply_to INTEGER")


def require_reply(connection, reply_to, pair=None):
    if reply_to is None:
        return
    if pair is None:
        found = connection.execute("SELECT id FROM messages WHERE id=? AND hidden=0", (reply_to,)).fetchone()
    else:
        found = connection.execute(
            "SELECT id FROM friend_chat_messages WHERE id=? AND low_id=? AND high_id=?", (reply_to, *pair)
        ).fetchone()
    if found is None:
        raise HTTPException(422, "Le message cité n’est plus disponible dans cette discussion. Annule la réponse ou choisis un autre message.")


def with_replies(connection, rows, pair=None):
    messages = [dict(row) for row in rows]
    ids = {m["reply_to"] for m in messages if m.get("reply_to") is not None}
    originals = {}
    if ids:
        marks = ",".join("?" for _ in ids)
        if pair is None:
            query = f"SELECT m.id,m.text,u.nickname AS sender FROM messages m JOIN users u ON u.id=m.user_id WHERE m.hidden=0 AND m.id IN ({marks})"
            params = tuple(ids)
        else:
            query = f"SELECT m.id,m.text,u.nickname AS sender FROM friend_chat_messages m JOIN users u ON u.id=m.sender_id WHERE m.id IN ({marks}) AND m.low_id=? AND m.high_id=?"
            params = (*ids, *pair)
        originals = {r["id"]: dict(r) for r in connection.execute(query, params)}
    for m in messages:
        ref = m.get("reply_to")
        m["reply"] = originals.get(ref, {"id": ref, "unavailable": True}) if ref is not None else None
    return messages
