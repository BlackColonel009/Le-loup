"""Closed catalogue shared with the authoritative Dart engine and Flutter."""
import json
import re
from pathlib import Path

CATALOG = json.loads((Path(__file__).resolve().parents[3] / 'shared/stickers/classic.json').read_text(encoding='utf-8'))
CATALOG += json.loads((Path(__file__).resolve().parents[3] / 'shared/stickers/rewards.json').read_text(encoding='utf-8'))
STICKERS = {item['id']: item for item in CATALOG}
TOKEN = re.compile(r'\[\[sticker:([a-z0-9_]+)\]\]')


def validate_sticker(text: str):
    match = TOKEN.fullmatch(text.strip())
    if text.strip().startswith('[[sticker:') and (not match or match[1] not in STICKERS):
        raise ValueError('Sticker inconnu ou indisponible.')
    return STICKERS[match[1]] if match and match[1] in STICKERS else None


def require_sticker_access(connection, user_id, sticker):
    if sticker is None or sticker.get('pack') != 'rewards':
        return
    from datetime import UTC, datetime

    from fastapi import HTTPException

    from .collection import trial_ids
    pid = f"sticker-{sticker['id']}"
    owned = connection.execute('SELECT 1 FROM collection_owned WHERE user_id=? AND product_id=?', (user_id, pid)).fetchone() if user_id else None
    if not owned and pid not in trial_ids(connection, datetime.now(UTC).date().isoformat()):
        raise HTTPException(403, 'Ce sticker est verrouillé. Débloque-le par un défi ou ajoute-le à ta collection depuis la boutique ou le Collectionneur.')
