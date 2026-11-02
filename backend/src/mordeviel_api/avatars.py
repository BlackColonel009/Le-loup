"""Account portraits: four starters, server-enforced unlocks, optional own photo."""
import base64
import binascii
import io
import json
import re
import secrets
from pathlib import Path
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException
from fastapi.responses import FileResponse
from PIL import Image, ImageOps, UnidentifiedImageError
from pydantic import BaseModel, Field

from . import avatar_styles
from .community import Store, authenticated, store

router = APIRouter(prefix='/community', tags=['avatars'])
DB = Annotated[Store, Depends(store)]
User = Annotated[dict, Depends(authenticated)]
CATALOG = json.loads((Path(__file__).resolve().parents[3] / 'shared/avatars/catalog.json').read_text(encoding='utf-8'))['avatars']
STARTERS = tuple(a['id'] for a in CATALOG if a['starter'])


def avatar_in(c, uid):
    row = c.execute('SELECT * FROM player_avatars WHERE user_id=?', (uid,)).fetchone()
    if row is None:
        c.execute('INSERT OR IGNORE INTO player_avatars(user_id,avatar_id) VALUES(?,?)', (uid, secrets.choice(STARTERS)))
        row = c.execute('SELECT * FROM player_avatars WHERE user_id=?', (uid,)).fetchone()
    style = avatar_styles.style_in(c, uid)
    row = c.execute('SELECT * FROM player_avatars WHERE user_id=?', (uid,)).fetchone()
    avatar_id = row['avatar_id']
    if avatar_id == 'creator-wolf' and not style['is_creator']:
        avatar_id = STARTERS[0]
    return {'id': avatar_id, 'kind': 'photo' if row['photo'] else 'game', **style,
            'pack_id': 'avatars-classic',
            'photo_url': f"/community/avatars/photo/{uid}/{row['photo']}" if row['photo'] else None}


def directory(db):
    return Path(db.path).parent / 'player-photos'


@router.get('/avatars')
def catalogue(*, user: User, db: DB):
    with db.db() as c:
        unlocked = {r['avatar_id'] for r in c.execute('SELECT avatar_id FROM avatar_unlocks WHERE user_id=?', (user['id'],))}
        creator = avatar_styles.is_creator(c, user['id'])
        return {'avatar': avatar_in(c, user['id']), 'avatars': [
            {k: v for k, v in a.items() if k not in {'source', 'source_root'}} | {
                'locked': not (creator if a.get('creator_only') else a['starter'] or a['id'] in unlocked),
                'unlock': 'creator' if a.get('creator_only') else 'starter' if a['starter'] else 'challenge',
            } for a in CATALOG if not a.get('creator_only') or creator],
            'borders': avatar_styles.catalogue_in(c, user['id'])}


class Choice(BaseModel):
    avatar_id: str = Field(min_length=3, max_length=80)


@router.put('/avatar')
def choose(*, data: Choice, user: User, db: DB):
    db.limit(('avatar', user['id']), 60, 300)
    entry = next((a for a in CATALOG if a['id'] == data.avatar_id), None)
    with db.db() as c:
        unlocked = c.execute('SELECT 1 FROM avatar_unlocks WHERE user_id=? AND avatar_id=?', (user['id'], data.avatar_id)).fetchone()
        eligible = (avatar_styles.is_creator(c, user['id']) if entry and entry.get('creator_only')
                    else entry is not None and (entry['starter'] or unlocked))
        if not eligible:
            raise HTTPException(403, 'Cet avatar est verrouillé. Les défis permettant de le débloquer seront annoncés prochainement.')
        avatar_in(c, user['id'])
        old = c.execute('SELECT photo FROM player_avatars WHERE user_id=?', (user['id'],)).fetchone()['photo']
        c.execute('UPDATE player_avatars SET avatar_id=?,photo=NULL WHERE user_id=?', (data.avatar_id, user['id']))
        result = avatar_in(c, user['id'])
    if old:
        (directory(db) / old).unlink(missing_ok=True)
    return {'avatar': result}


class BorderChoice(BaseModel):
    border_id: str = Field(min_length=3, max_length=60)


@router.put('/avatar/border')
def choose_border(*, data: BorderChoice, user: User, db: DB):
    db.limit(('avatar_border', user['id']), 60, 300)
    entry = next((b for b in avatar_styles.BORDERS if b['id'] == data.border_id), None)
    with db.db() as c:
        if not avatar_styles.allowed(c, user['id'], entry):
            raise HTTPException(403, 'Bordure prémium verrouillée. Défis ou achat à venir.')
        avatar_in(c, user['id'])
        c.execute('UPDATE player_avatar_styles SET border_id=? WHERE user_id=?', (data.border_id, user['id']))
        return {'avatar': avatar_in(c, user['id'])}


class Photo(BaseModel):
    image_base64: str = Field(min_length=16, max_length=800_000)


@router.put('/avatar/photo')
def upload_photo(*, data: Photo, user: User, db: DB):
    db.limit(('avatar_photo', user['id']), 10, 3600)
    try:
        raw = base64.b64decode(data.image_base64, validate=True)
        if len(raw) > 600_000:
            raise ValueError
        with Image.open(io.BytesIO(raw)) as original:
            if original.format not in {'PNG', 'JPEG', 'WEBP'} or max(original.size) > 4096 or original.width * original.height > 16_000_000:
                raise ValueError
            original.load()
            image = ImageOps.fit(ImageOps.exif_transpose(original).convert('RGB'), (384, 384))
            output = io.BytesIO()
            image.save(output, 'WEBP', quality=85)
    except (ValueError, binascii.Error, OSError, UnidentifiedImageError, Image.DecompressionBombError):
        raise HTTPException(422, 'Photo PNG, JPEG ou WebP requise. Réduis sa taille puis réessaie.') from None
    folder = directory(db)
    folder.mkdir(parents=True, exist_ok=True)
    filename = secrets.token_hex(16) + '.webp'
    (folder / filename).write_bytes(output.getvalue())
    try:
        with db.db() as c:
            avatar_in(c, user['id'])
            old = c.execute('SELECT photo FROM player_avatars WHERE user_id=?', (user['id'],)).fetchone()['photo']
            c.execute('UPDATE player_avatars SET photo=? WHERE user_id=?', (filename, user['id']))
            result = avatar_in(c, user['id'])
    except Exception:
        (folder / filename).unlink(missing_ok=True)
        raise
    if old:
        (folder / old).unlink(missing_ok=True)
    return {'avatar': result}


@router.get('/avatars/photo/{target}/{filename}')
def photo(target: int, filename: str, *, user: User, db: DB):
    if not re.fullmatch(r'[a-f0-9]{32}\.webp', filename):
        raise HTTPException(404, 'Portrait indisponible.')
    with db.db() as c:
        row = c.execute('SELECT p.photo FROM player_avatars p JOIN users u ON u.id=p.user_id WHERE p.user_id=? AND u.banned=0 AND u.email_verified=1', (target,)).fetchone()
        blocked = c.execute('SELECT 1 FROM social_blocks WHERE (user_id=? AND target_id=?) OR (user_id=? AND target_id=?)', (user['id'], target, target, user['id'])).fetchone()
    path = directory(db) / filename
    if not row or row['photo'] != filename or blocked or not path.is_file():
        raise HTTPException(404, 'Portrait indisponible.')
    return FileResponse(path, media_type='image/webp', headers={'Cache-Control': 'private,max-age=3600', 'X-Content-Type-Options': 'nosniff'})
