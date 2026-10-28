"""Public, immutable downloadable content. No uploads or client-supplied paths."""
import json
import os
import re
from pathlib import Path

from fastapi import APIRouter, HTTPException
from fastapi.responses import FileResponse

router = APIRouter(prefix='/content', tags=['content'])


def root():
    return Path(os.getenv('MORDEVIEL_CONTENT_ROOT', str(Path(__file__).resolve().parents[2] / 'content/packs')))


def catalog():
    path = root() / 'catalog.json'
    return json.loads(path.read_text(encoding='utf-8')) if path.is_file() else {'packs': []}


@router.get('/packs')
def packs():
    return catalog()


@router.get('/packs/{pack_id}/{version}/{file_id}')
def content_file(pack_id: str, version: str, file_id: str):
    if not re.fullmatch(r'[a-z0-9-]{1,60}', pack_id) or not re.fullmatch(r'[a-f0-9]{16}', version) or not re.fullmatch(r'[a-f0-9]{64}', file_id):
        raise HTTPException(404, 'Contenu introuvable.')
    pack = next((p for p in catalog()['packs'] if p['id'] == pack_id and p['version'] == version), None)
    if pack is None:
        previous = root() / pack_id / version / 'manifest.json'
        if previous.is_file():
            pack = json.loads(previous.read_text(encoding='utf-8'))
    entry = next((f for f in pack['files'] if f['sha256'] == file_id), None) if pack else None
    if entry is None:
        raise HTTPException(404, 'Contenu introuvable.')
    path = root() / pack_id / version / file_id
    if not path.is_file():
        raise HTTPException(404, 'Contenu non publié.')
    return FileResponse(path, media_type='application/octet-stream', headers={
        'Cache-Control': 'public,max-age=31536000,immutable', 'ETag': f'"{file_id}"',
    })


def initialize():
    if os.getenv('MORDEVIEL_CONTENT_ROOT') or (root() / 'catalog.json').is_file():
        return
    script = Path(__file__).resolve().parents[3] / 'tools/content/build_packs.py'
    if script.is_file():
        import runpy
        runpy.run_path(str(script), run_name='__main__')
