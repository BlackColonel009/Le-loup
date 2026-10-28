import hashlib
import json

from fastapi.testclient import TestClient
from mordeviel_api.main import app


def test_immutable_content_range_and_unknown_path(tmp_path, monkeypatch):
    monkeypatch.setenv('MORDEVIEL_COMMUNITY_DB', str(tmp_path / 'community.db'))
    root = tmp_path / 'packs'
    monkeypatch.setenv('MORDEVIEL_CONTENT_ROOT', str(root))
    data = b'pack-payload-for-resumable-download'
    digest = hashlib.sha256(data).hexdigest()
    directory = root / 'sample' / '1234567890abcdef'
    directory.mkdir(parents=True)
    (directory / digest).write_bytes(data)
    (root / 'catalog.json').write_text(json.dumps({'packs':[{'id':'sample','version':'1234567890abcdef','files':[{'asset':'assets/test.png','sha256':digest,'size':len(data),'url':f'/content/packs/sample/1234567890abcdef/{digest}'}]}]}))
    with TestClient(app) as api:
        catalog = api.get('/content/packs').json()
        url = catalog['packs'][0]['files'][0]['url']
        response = api.get(url)
        assert response.content == data
        assert 'immutable' in response.headers['cache-control']
        response = api.get(url, headers={'Range':'bytes=5-'})
        assert response.status_code == 206
        assert response.content == data[5:]
        assert api.get('/content/packs/sample/1234567890abcdef/not-a-file').status_code == 404
