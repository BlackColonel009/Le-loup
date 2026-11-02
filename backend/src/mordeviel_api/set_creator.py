"""Bind the unique creator style to an existing administrator, from the server."""
import argparse
import os
import time
from pathlib import Path

from dotenv import load_dotenv

from .avatar_styles import CREATOR_KEY
from .community import Store


def main():
    parser = argparse.ArgumentParser(description='Attribuer le profil Créateur unique, sans changer de mot de passe.')
    parser.add_argument('--nickname', required=True)
    args = parser.parse_args()
    load_dotenv(Path(__file__).resolve().parents[2] / '.env', override=False)
    db = Store(os.getenv('MORDEVIEL_COMMUNITY_DB', str(Path(__file__).resolve().parents[2] / 'data/community.sqlite3')))
    with db.db() as c:
        user = c.execute("SELECT id,nickname FROM users WHERE name_key=? AND role='admin' AND banned=0", (args.nickname.strip().casefold(),)).fetchone()
        if user is None:
            parser.error('Ce pseudo ne correspond pas à un administrateur actif.')
        c.execute('INSERT INTO settings(key,value) VALUES(?,?) ON CONFLICT(key) DO UPDATE SET value=excluded.value', (CREATOR_KEY, str(user['id'])))
        c.execute('INSERT INTO admin_audit(actor,action,target,created) VALUES(?,?,?,?)', (user['id'], 'creator_style', str(user['id']), time.time()))
    print(f"Profil Créateur attribué à {user['nickname']}. Actualise le profil dans l’application.")


if __name__ == '__main__':
    main()
