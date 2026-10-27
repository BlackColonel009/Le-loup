"""Private SMTP diagnostic. --send-test sends exactly one message to the configured mailbox."""

import argparse
import os
import smtplib
import ssl
from email.message import EmailMessage
from pathlib import Path

from dotenv import load_dotenv
from fastapi import HTTPException


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--send-test", action="store_true")
    args = parser.parse_args()
    load_dotenv(Path(__file__).resolve().parents[1] / "backend/.env", override=False)
    from le_loup_api.email_security import normalize_email, require_mailer

    stage = "configuration"
    accepted = False
    smtp = None
    try:
        require_mailer()
        address = normalize_email(os.environ["LE_LOUP_SMTP_FROM"])
        recipient = os.getenv("LE_LOUP_SMTP_USERNAME", "")
        try:
            recipient = normalize_email(recipient)
        except HTTPException:
            recipient = address
        host = os.environ["LE_LOUP_SMTP_HOST"]
        port = int(os.getenv("LE_LOUP_SMTP_PORT", "587"))
        context = ssl.create_default_context()
        stage = "connexion TLS"
        smtp = (
            smtplib.SMTP_SSL(host, port, timeout=15, context=context)
            if port == 465
            else smtplib.SMTP(host, port, timeout=15)
        )
        if port != 465:
            smtp.starttls(context=context)
        print("Connexion SMTP chiffrée et certificat : OK")
        stage = "authentification"
        smtp.login(
            os.environ["LE_LOUP_SMTP_USERNAME"], os.environ["LE_LOUP_SMTP_PASSWORD"]
        )
        print("Authentification SMTP : OK")
        if args.send_test:
            message = EmailMessage()
            message["From"] = address
            message["To"] = recipient
            message["Subject"] = "Legende of Wolf · Test SMTP"
            message.set_content(
                "Bonjour,\n\nCet unique message confirme le test de la configuration SMTP de Legende of Wolf.\nIl ne contient aucun code de récupération ni mot de passe.\n\nby Logan R.D"
            )
            stage = "envoi du message de test"
            refused = smtp.send_message(message)
            if refused:
                print(
                    "Le serveur a refusé le destinataire. Aucun second envoi effectué."
                )
                return 1
            accepted = True
            print("Un unique email de test accepté par le serveur SMTP : OK")
        return 0
    except (OSError, smtplib.SMTPException, HTTPException, KeyError, ValueError) as error:
        code = getattr(error, "smtp_code", None)
        print(
            f"Échec : {stage} ({type(error).__name__}"
            + (f", code {code}" if code else "")
            + ")."
        )
        if accepted:
            print(
                "Le message avait déjà été accepté ; ne pas relancer automatiquement."
            )
        return 1
    finally:
        if smtp:
            try:
                smtp.quit()
            except (OSError, smtplib.SMTPException):
                smtp.close()


if __name__ == "__main__":
    raise SystemExit(main())
