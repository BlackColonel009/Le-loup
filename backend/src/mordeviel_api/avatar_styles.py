"""Server-owned creator identity and future earned/purchased avatar frames."""
import json
from pathlib import Path

BORDERS = json.loads((Path(__file__).resolve().parents[3] / 'shared/avatars/borders.json').read_text(encoding='utf-8'))['borders']
CREATOR_KEY = 'avatar_creator_user_id'


def initialize(c):
    c.executescript('''
        CREATE TABLE IF NOT EXISTS player_avatar_styles (
            user_id INTEGER PRIMARY KEY, border_id TEXT NOT NULL DEFAULT 'none',
            creator_initialized INTEGER NOT NULL DEFAULT 0);
        CREATE TABLE IF NOT EXISTS border_unlocks (
            user_id INTEGER NOT NULL,border_id TEXT NOT NULL,source TEXT NOT NULL,
            PRIMARY KEY(user_id,border_id));
    ''')


def is_creator(c, uid):
    owner = c.execute('SELECT value FROM settings WHERE key=?', (CREATOR_KEY,)).fetchone()
    if owner is None:
        # The sole existing administrator is the original owner. Persist the ID
        # once; creating more administrators never confers the creator style.
        admins = c.execute("SELECT id FROM users WHERE role='admin' ORDER BY id LIMIT 2").fetchall()
        if len(admins) == 1:
            c.execute('INSERT OR IGNORE INTO settings(key,value) VALUES(?,?)', (CREATOR_KEY, str(admins[0]['id'])))
            owner = c.execute('SELECT value FROM settings WHERE key=?', (CREATOR_KEY,)).fetchone()
    if owner is None or owner['value'] != str(uid):
        return False
    return c.execute("SELECT 1 FROM users WHERE id=? AND role='admin' AND banned=0", (uid,)).fetchone() is not None


def allowed(c, uid, entry, *, creator=None):
    if entry is None:
        return False
    if entry.get('creator_only'):
        return is_creator(c, uid) if creator is None else creator
    return bool(entry.get('free') or c.execute(
        'SELECT 1 FROM border_unlocks WHERE user_id=? AND border_id=?', (uid, entry['id'])
    ).fetchone())


def style_in(c, uid):
    creator = is_creator(c, uid)
    c.execute('INSERT OR IGNORE INTO player_avatar_styles(user_id) VALUES(?)', (uid,))
    row = c.execute('SELECT * FROM player_avatar_styles WHERE user_id=?', (uid,)).fetchone()
    if creator and not row['creator_initialized']:
        c.execute("UPDATE player_avatar_styles SET border_id='creator-gold',creator_initialized=1 WHERE user_id=?", (uid,))
        c.execute("UPDATE player_avatars SET avatar_id='creator-wolf' WHERE user_id=? AND photo IS NULL", (uid,))
        row = c.execute('SELECT * FROM player_avatar_styles WHERE user_id=?', (uid,)).fetchone()
    entry = next((b for b in BORDERS if b['id'] == row['border_id']), None)
    border = row['border_id'] if allowed(c, uid, entry, creator=creator) else 'none'
    return {'is_creator': creator, 'border_id': border}


def catalogue_in(c, uid):
    creator = is_creator(c, uid)
    return [dict(b, locked=not allowed(c, uid, b, creator=creator),
                 unlock='creator' if b.get('creator_only') else 'free' if b.get('free') else 'challenge_or_purchase')
            for b in BORDERS if not b.get('creator_only') or creator]
