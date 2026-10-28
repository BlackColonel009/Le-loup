"""Account settings; password changes require the current password, never just a nickname."""

import hashlib
import secrets
import sqlite3
import time
from typing import Annotated

from fastapi import APIRouter, Depends, Header, HTTPException, Request
from pydantic import BaseModel, Field

from . import email_security
from .community import Store, authenticated, identity, store

router = APIRouter(prefix="/community", tags=["profile"])


@router.get("/profile")
def profile(
    *,
    user: Annotated[dict, Depends(authenticated)],
    db: Annotated[Store, Depends(store)],
):
    restricted = user["muted_until"] > time.time()
    return {
        "id": user["id"],
        "nickname": user["nickname"],
        "role": user["role"],
        "verified": user["role"] == "admin",
        "email": user["email"],
        "email_verified": bool(user["email_verified"]),
        "account_state": "chat_restricted" if restricted else "active",
        "uses_password": True,
        "warning_streak": user["strikes"],
        "restriction_ends_at": user["muted_until"] if restricted else None,
    }


class PasswordChange(BaseModel):
    current_password: str = Field(min_length=8, max_length=128)
    new_password: str = Field(min_length=8, max_length=128)
    confirm_password: str = Field(min_length=8, max_length=128)


@router.post("/password")
def change_password(
    *,
    data: PasswordChange,
    authorization: str = Header(default=""),
    user: Annotated[dict, Depends(authenticated)],
    db: Annotated[Store, Depends(store)],
):
    raise HTTPException(
        409,
        "La vérification par email est obligatoire. Demande un code de changement de mot de passe.",
    )


class VerifyRequest(BaseModel):
    email: str = Field(min_length=3, max_length=254)


class Code(BaseModel):
    challenge_id: str = Field(min_length=20, max_length=80)
    code: str = Field(pattern=r"^\d{6}$")


@router.post("/email/request")
def request_verification(
    *,
    data: VerifyRequest,
    user: Annotated[dict, Depends(identity)],
    db: Annotated[Store, Depends(store)],
):
    db.limit(("verify", user["id"]), 3, 300)
    if user["email_verified"]:
        raise HTTPException(409, "Cette adresse email est déjà vérifiée.")
    email = email_security.normalize_email(data.email)
    with db.db() as connection:
        exists = connection.execute(
            "SELECT id FROM users WHERE email=? AND id<>?", (email, user["id"])
        ).fetchone()
    if exists:
        raise HTTPException(409, "Cette adresse email est déjà associée à un compte.")
    return {
        "challenge_id": email_security.issue(db, user["id"], email, "verify"),
        "message": "Code de vérification envoyé par email.",
    }


@router.post("/email/verify")
def verify_email(
    *,
    data: Code,
    user: Annotated[dict, Depends(identity)],
    db: Annotated[Store, Depends(store)],
):
    db.limit(("verify_attempt", user["id"]), 20, 300)
    try:
        with db.db() as connection:
            connection.execute("BEGIN IMMEDIATE")
            row, error = email_security.check(
                connection, data.challenge_id, data.code, "verify", user["id"]
            )
            if not error:
                connection.execute(
                    "UPDATE users SET email=?,email_verified=1 WHERE id=?",
                    (row["email"], user["id"]),
                )
                connection.execute(
                    "UPDATE email_challenges SET used=1 WHERE user_id=?",
                    (user['id'],),
                )
    except sqlite3.IntegrityError:
        raise HTTPException(409, "Cette adresse email est déjà utilisée.") from None
    if error:
        raise HTTPException(400, error)
    return {"ok": True, "message": "Adresse email vérifiée."}


class ResetRequest(BaseModel):
    identifier: str = Field(min_length=2, max_length=254)


@router.post("/password/request", status_code=202)
def request_reset(
    *, data: ResetRequest, request: Request, db: Annotated[Store, Depends(store)]
):
    email_security.require_mailer()
    db.limit(("reset_ip", request.client.host), 10, 300)
    value = data.identifier.strip().casefold()
    db.limit(("reset_identifier", value), 3, 300)
    with db.db() as connection:
        user = connection.execute(
            "SELECT id,email,banned FROM users WHERE name_key=? OR email=?",
            (value, value),
        ).fetchone()
    eligible = user is not None and user["email"] and not user["banned"]
    challenge = email_security.issue(
        db,
        user["id"] if eligible else None,
        user["email"] if eligible else None,
        "reset",
    )
    return {
        "challenge_id": challenge,
        "message": "Si ce compte possède une adresse email, un code de vérification vient de lui être envoyé.",
    }


class ResetPassword(Code):
    new_password: str = Field(min_length=8, max_length=128)
    confirm_password: str = Field(min_length=8, max_length=128)


@router.post("/password/confirm")
def confirm_reset(
    *, data: ResetPassword, request: Request, db: Annotated[Store, Depends(store)]
):
    db.limit(("reset_attempt", request.client.host), 30, 300)
    if data.new_password != data.confirm_password:
        raise HTTPException(422, "Les nouveaux mots de passe ne correspondent pas.")
    with db.db() as connection:
        connection.execute("BEGIN IMMEDIATE")
        row, error = email_security.check(
            connection, data.challenge_id, data.code, "reset"
        )
        if not error:
            user = connection.execute(
                "SELECT banned,email FROM users WHERE id=?", (row["user_id"],)
            ).fetchone()
            if user is None or user["banned"] or user['email']!=row['email']:
                error = "Modification impossible pour ce compte."
            else:
                salt = secrets.token_hex(16)
                password = hashlib.scrypt(
                    data.new_password.encode(),
                    salt=bytes.fromhex(salt),
                    n=16384,
                    r=8,
                    p=1,
                ).hex()
                connection.execute(
                    "UPDATE users SET salt=?,password=?,email_verified=1 WHERE id=?",
                    (salt, password, row["user_id"]),
                )
                connection.execute(
                    "DELETE FROM sessions WHERE user_id=?", (row["user_id"],)
                )
                connection.execute('DELETE FROM social_devices WHERE user_id=?',(row['user_id'],))
                connection.execute(
                    "UPDATE email_challenges SET used=1 WHERE user_id=?",
                    (row["user_id"],),
                )
    if error:
        raise HTTPException(400, error)
    return {
        "ok": True,
        "message": "Mot de passe modifié. Reconnecte-toi avec ton nouveau mot de passe.",
    }


@router.get("/purchases")
def purchases(
    *,
    user: Annotated[dict, Depends(authenticated)],
    db: Annotated[Store, Depends(store)],
):
    with db.db() as connection:
        rows = connection.execute(
            """SELECT id,product_id,title,amount_minor,currency,status,purchased_at
            FROM purchase_history WHERE user_id=? ORDER BY purchased_at DESC,id DESC LIMIT 100""",
            (user["id"],),
        ).fetchall()
    return {"purchases": [dict(row) for row in rows], "purchases_enabled": False}
