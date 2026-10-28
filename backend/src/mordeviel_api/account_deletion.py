"""Email-confirmed account deletion, usable without an app session."""

from typing import Annotated, Literal

from fastapi import APIRouter, Depends, HTTPException, Request
from pydantic import BaseModel, Field

from . import email_security
from .community import Store, store
from .profile import Code

router = APIRouter(prefix="/community/account-deletion", tags=["profile"])


class DeletionRequest(BaseModel):
    email: str = Field(min_length=3, max_length=254)


class DeletionConfirmation(Code):
    confirm: Literal[True]


@router.post("/request", status_code=202)
def request_deletion(
    *, data: DeletionRequest, request: Request, db: Annotated[Store, Depends(store)]
):
    email_security.require_mailer()
    email = email_security.normalize_email(data.email)
    db.limit(("delete_ip", request.client.host), 10, 300)
    db.limit(("delete_email", email), 3, 300)
    with db.db() as connection:
        user = connection.execute(
            "SELECT id,email FROM users WHERE email=?", (email,)
        ).fetchone()
    challenge = email_security.issue(
        db, user["id"] if user else None, user["email"] if user else None, "delete"
    )
    return {
        "challenge_id": challenge,
        "message": "Si un compte correspond à cette adresse, un code de suppression vient de lui être envoyé. Il expire dans 10 minutes.",
    }


@router.post("/confirm")
def confirm_deletion(
    *,
    data: DeletionConfirmation,
    request: Request,
    db: Annotated[Store, Depends(store)],
):
    db.limit(("delete_attempt", request.client.host), 30, 300)
    with db.db() as connection:
        connection.execute("BEGIN IMMEDIATE")
        row, error = email_security.check(
            connection, data.challenge_id, data.code, "delete"
        )
        if not error:
            user_id = row["user_id"]
            user = connection.execute(
                "SELECT email FROM users WHERE id=?", (user_id,)
            ).fetchone()
            if user is None or user["email"] != row["email"]:
                error = "Code invalide ou expiré. Demande un nouveau code."
            else:
                connection.execute(
                    "DELETE FROM reports WHERE user_id=? OR message_id IN (SELECT id FROM messages WHERE user_id=?)",
                    (user_id, user_id),
                )
                connection.execute(
                    "DELETE FROM replies WHERE ticket_id IN (SELECT id FROM tickets WHERE user_id=?)",
                    (user_id,),
                )
                for table in (
                    "tickets",
                    "messages",
                    "sessions",
                    "purchase_history",
                    "email_challenges",
                    "community_mail_preferences",
                    "community_mail_deliveries",
                ):
                    connection.execute(
                        f"DELETE FROM {table} WHERE user_id=?", (user_id,)
                    )
                connection.execute(
                    "DELETE FROM admin_audit WHERE actor=? OR (action IN ('ban','unban','unmute') AND target=?)",
                    (user_id, str(user_id)),
                )
                connection.execute('DELETE FROM social_receipts WHERE notification_id IN (SELECT id FROM social_notifications WHERE user_id=? OR actor_id=?)',(user_id,user_id))
                for table, column in [('social_preferences','user_id'),('social_devices','user_id'),('social_match_stats','user_id'),('social_notifications','user_id')]:
                    connection.execute(f'DELETE FROM {table} WHERE {column}=?',(user_id,))
                connection.execute('DELETE FROM social_notifications WHERE actor_id=?',(user_id,))
                for table, first, second in [('social_friends','low_id','high_id'),('social_blocks','user_id','target_id'),('social_recent','user_id','target_id'),('social_invitations','sender_id','target_id')]:
                    connection.execute(f'DELETE FROM {table} WHERE {first}=? OR {second}=?',(user_id,user_id))
                connection.execute('DELETE FROM collection_owned WHERE user_id=?', (user_id,))
                connection.execute('DELETE FROM collection_visits WHERE user_id=?', (user_id,))
                connection.execute("DELETE FROM users WHERE id=?", (user_id,))
    # Keep failed-attempt counters committed even when returning an error.
    if error:
        raise HTTPException(400, error)
    return {
        "ok": True,
        "message": "Ton compte et ses données associées ont été supprimés de la base active. Tes sessions sont fermées.",
    }
