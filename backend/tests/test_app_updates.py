import hashlib

from fastapi.testclient import TestClient

from mordeviel_api.main import app


def test_release_is_public_and_tracks_version_and_full_link(tmp_path, monkeypatch):
    monkeypatch.setenv('MORDEVIEL_COMMUNITY_DB', str(tmp_path/'updates.sqlite3'))
    monkeypatch.setenv('MORDEVIEL_SUPPORT_TOKEN', 'updates-admin')
    auth = {'Authorization': 'Bearer updates-admin'}
    url = 'https://mega.nz/file/public-apk#key'
    data = {'download_enabled': True, 'download_version':'0.2.0+2', 'download_url':url}
    with TestClient(app) as api:
        assert api.get('/app-update').json()['enabled'] is False
        endpoint = '/community/admin/site/download'
        assert api.put(endpoint, headers=auth, json=data).status_code == 200
        response = api.get('/app-update')
        release = response.json()
        assert response.headers['cache-control'] == 'no-store'
        assert release['platform'] == 'android' and release['required'] is True
        assert release['download_url'] == url and release['version'] == '0.2.0+2'
        assert release['release_id'] == hashlib.sha256(f'0.2.0+2\n{url}'.encode()).hexdigest()
        changed = {**data, 'download_url':url+'2'}
        assert api.put(endpoint, headers=auth, json=changed).status_code == 200
        assert api.get('/app-update').json()['release_id'] != release['release_id']
        for version in ['', 'version prochaine', '0.2', '0.2.0-beta']:
            assert api.put(endpoint, headers=auth, json={**data,'download_version':version}).status_code == 422
        assert api.put(endpoint, headers=auth, json={**data,'download_enabled':False}).status_code == 200
        assert api.get('/app-update').json()['enabled'] is False
