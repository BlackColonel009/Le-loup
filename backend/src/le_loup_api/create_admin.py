"""Run on the server terminal: python -m le_loup_api.create_admin."""

import argparse
import getpass
import hashlib
import hmac
import os
import secrets
from pathlib import Path

from .community import Store
from .email_security import normalize_email


def main():
    parser = argparse.ArgumentParser(
        description="Créer le compte administrateur certifié sur ce serveur."
    )
    parser.add_argument("--nickname", default="Logan R.D")
    parser.add_argument(
        "--email",
        required=True,
        help="Adresse privée de récupération et de vérification.",
    )
    args = parser.parse_args()
    name = args.nickname.strip()
    email = normalize_email(args.email)
    if not 2 <= len(name) <= 24:
        raise SystemExit("Le pseudo doit contenir 2 à 24 caractères.")
    password = getpass.getpass("Mot de passe privé (8 caractères minimum) : ")
    if (
        len(password) < 8
        or len(password) > 128
        or password != getpass.getpass("Confirmer le mot de passe : ")
    ):
        raise SystemExit("Mot de passe trop court ou confirmation différente.")
    db = Store(
        os.getenv(
            "LE_LOUP_COMMUNITY_DB",
            str(Path(__file__).resolve().parents[2] / "data/community.sqlite3"),
        )
    )
    with db.db() as connection:
        user = connection.execute(
            "SELECT * FROM users WHERE name_key=?", (name.casefold(),)
        ).fetchone()
        if user:
            derived = hashlib.scrypt(
                password.encode(), salt=bytes.fromhex(user["salt"]), n=16384, r=8, p=1
            ).hex()
            if not hmac.compare_digest(derived, user["password"]):
                raise SystemExit(
                    "Ce compte existe : saisir son mot de passe actuel pour le promouvoir."
                )
            connection.execute(
                "UPDATE users SET role='admin',banned=0,email=?,email_verified=CASE WHEN email=? THEN email_verified ELSE 0 END WHERE id=?",
                (email, email, user["id"]),
            )
        else:
            salt = secrets.token_hex(16)
            derived = hashlib.scrypt(
                password.encode(), salt=bytes.fromhex(salt), n=16384, r=8, p=1
            ).hex()
            connection.execute(
                "INSERT INTO users(nickname,name_key,salt,password,role,email) VALUES(?,?,?,?,'admin',?)",
                (name, name.casefold(), salt, derived, email),
            )
    print(
        f"Compte administrateur certifié prêt : {name}. Connectez-vous dans Communauté pour ouvrir le dashboard."
    )


if __name__ == "__main__":
    main()
