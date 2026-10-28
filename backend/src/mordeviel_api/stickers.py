"""Closed catalogue shared with the authoritative Dart engine and Flutter."""
import json
import re
from pathlib import Path

CATALOG = json.loads((Path(__file__).resolve().parents[3] / 'shared/stickers/classic.json').read_text(encoding='utf-8'))
STICKERS = {item['id']: item for item in CATALOG}
TOKEN = re.compile(r'\[\[sticker:([a-z0-9_]+)\]\]')


def validate_sticker(text: str):
    match = TOKEN.fullmatch(text.strip())
    if text.strip().startswith('[[sticker:') and (not match or match[1] not in STICKERS):
        raise ValueError('Sticker inconnu ou indisponible.')
    return STICKERS[match[1]] if match and match[1] in STICKERS else None
