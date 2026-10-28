"""Single-use email challenges. Codes are never returned by the API or logged."""

import hashlib
import hmac
import os
import re
import secrets
import smtplib
import ssl
import time
from email.message import EmailMessage

from fastapi import HTTPException


def normalize_email(value):
    value = value.strip().casefold()
    if len(value) > 254 or not re.fullmatch(
        r"[^\s<>@,;\r\n]+@[a-z0-9](?:[a-z0-9.-]*[a-z0-9])?\.[a-z]{2,63}", value
    ):
        raise HTTPException(422, "Adresse email invalide.")
    return value


def require_mailer():
    if os.getenv("SMTP_USE_TLS", "true").strip().lower() not in {
        "true",
        "1",
        "yes",
        "on",
    }:
        raise HTTPException(
            503, "La configuration SMTP doit activer TLS pour envoyer les emails."
        )
    if not os.getenv("LE_LOUP_SMTP_HOST") or not os.getenv("LE_LOUP_SMTP_FROM"):
        raise HTTPException(
            503,
            "La vérification par email est momentanément indisponible. Réessaie plus tard.",
        )


def send_code(address, code, purpose):
    require_mailer()
    message = EmailMessage()
    message["From"] = normalize_email(os.environ["LE_LOUP_SMTP_FROM"])
    message["To"] = address
    message["Subject"] = "Legende of Wolf · Vérification de sécurité"
    label = {
        "verify": "vérifier ton adresse email",
        "reset": "changer ton mot de passe",
        "delete": "supprimer définitivement ton compte et ses données",
    }[purpose]
    message.set_content(
        f"Bonjour,\n\nPour {label}, saisis ce code sur le site ou dans l’application Legende of Wolf :\n\n{code}\n\nCe code expire dans 10 minutes et ne peut servir qu’une fois.\nSi tu n’as rien demandé, ignore ce message.\nNe partage jamais ce code.\n\nLegende of Wolf · by Logan R.D"
    )
    send_message(message)


def send_message(message):
    """Shared TLS transport for security and community emails."""
    require_mailer()
    host = os.environ["LE_LOUP_SMTP_HOST"]
    port = int(os.getenv("LE_LOUP_SMTP_PORT", "587"))
    context = ssl.create_default_context()
    try:
        smtp = (
            smtplib.SMTP_SSL(host, port, timeout=10, context=context)
            if port == 465
            else smtplib.SMTP(host, port, timeout=10)
        )
        with smtp:
            if port != 465:
                smtp.starttls(context=context)
            if os.getenv("LE_LOUP_SMTP_USERNAME"):
                smtp.login(
                    os.environ["LE_LOUP_SMTP_USERNAME"],
                    os.environ["LE_LOUP_SMTP_PASSWORD"],
                )
            smtp.send_message(message)
    except (OSError, smtplib.SMTPException, KeyError):
        raise HTTPException(
            503, "Envoi email impossible. Réessaie plus tard."
        ) from None


def issue(db, user_id, address, purpose):
    require_mailer()
    challenge = secrets.token_urlsafe(24)
    code = f"{secrets.randbelow(1000000):06d}"
    digest = hashlib.sha256(f"{challenge}:{code}".encode()).hexdigest()
    with db.db() as connection:
        connection.execute(
            "DELETE FROM email_challenges WHERE expires<?", (time.time() - 86400,)
        )
        if user_id is not None:
            connection.execute(
                "UPDATE email_challenges SET used=1 WHERE user_id=? AND purpose=?",
                (user_id, purpose),
            )
        connection.execute(
            "INSERT INTO email_challenges VALUES(?,?,?,?,?,?,0,0)",
            (challenge, user_id, address, purpose, digest, time.time() + 600),
        )
    if address and user_id is not None:
        try:
            send_code(address, code, purpose)
        except HTTPException:
            with db.db() as connection:
                connection.execute(
                    "UPDATE email_challenges SET used=1 WHERE id=?", (challenge,)
                )
            raise
    return challenge


def check(connection, challenge, code, purpose, user_id=None):
    row = connection.execute(
        "SELECT * FROM email_challenges WHERE id=?", (challenge,)
    ).fetchone()
    candidate = hashlib.sha256(f"{challenge}:{code}".encode()).hexdigest()
    valid = row is not None and hmac.compare_digest(candidate, row["digest"])
    if (
        row is None
        or row["used"]
        or row["expires"] <= time.time()
        or row["attempts"] >= 5
        or row["purpose"] != purpose
        or user_id is not None
        and row["user_id"] != user_id
    ):
        return None, "Code invalide ou expiré. Demande un nouveau code."
    if not valid or row["user_id"] is None:
        connection.execute(
            "UPDATE email_challenges SET attempts=attempts+1 WHERE id=?", (challenge,)
        )
        return None, "Code incorrect. Vérifie le code reçu par email."
    return row, None
