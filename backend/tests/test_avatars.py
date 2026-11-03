import base64
import io

import pytest
from fastapi.testclient import TestClient
from PIL import Image

from mordeviel_api import social_scheduler
from mordeviel_api.avatars import STARTERS
from mordeviel_api.main import app

from .helpers import OUTBOX, post_verified


@pytest.fixture
def api(tmp_path, monkeypatch):
    monkeypatch.setenv('MORDEVIEL_COMMUNITY_DB', str(tmp_path / 'avatars.sqlite3'))
    monkeypatch.setattr(social_scheduler, 'send_message', lambda message: None)
    with TestClient(app) as client:
        yield client


def account(api, nickname):
    response = post_verified(api, '/community/register', json={'nickname': nickname, 'password': 'password-test-123'})
    assert response.status_code == 201, response.text
    data = response.json()
    return data['user']['id'], {'Authorization': 'Bearer ' + data['token']}, data


def photo():
    output = io.BytesIO()
    Image.new('RGB', (60, 90), '#876543').save(output, 'PNG')
    return {'image_base64': base64.b64encode(output.getvalue()).decode()}


def test_starter_is_random_assigned_once_and_shared_by_profiles(api):
    uid, headers, registered = account(api, 'Alice')
    first = api.get('/community/avatars', headers=headers).json()
    assert len(first['avatars']) == 35
    assert sum(not a['locked'] for a in first['avatars']) == 4
    assert first['avatar']['id'] in STARTERS
    assert registered['user']['avatar'] == first['avatar']
    assert api.get('/community/profile', headers=headers).json()['avatar'] == first['avatar']
    assert api.get(f'/social/profiles/{uid}', headers=headers).json()['avatar'] == first['avatar']
    summary = api.get('/social/summary', headers=headers).json()
    assert summary['nickname'] == 'Alice'
    assert summary['avatar'] == first['avatar']
    again = api.post('/community/login', json={'nickname': 'Alice', 'password': 'password-test-123'}).json()
    assert again['user']['avatar'] == first['avatar']


def test_only_starters_or_real_unlocks_can_be_selected(api):
    uid, headers, _ = account(api, 'Alice')
    _, other, _ = account(api, 'Bob')
    before = api.get('/community/profile', headers=other).json()['avatar']
    for avatar_id in STARTERS:
        response = api.put('/community/avatar', headers=headers, json={'avatar_id': avatar_id})
        assert response.status_code == 200
        assert response.json()['avatar']['id'] == avatar_id
    for forbidden in ['classic-hunter', 'intense-villager', '../../etc/passwd']:
        assert api.put('/community/avatar', headers=headers, json={'avatar_id': forbidden}).status_code == 403
    with api.app.state.community.db() as c:
        c.execute('INSERT INTO avatar_unlocks VALUES(?,?,?)', (uid, 'classic-hunter', 'test-only'))
    assert api.put('/community/avatar', headers=headers, json={'avatar_id': 'classic-hunter'}).status_code == 200
    assert api.get('/community/profile', headers=other).json()['avatar'] == before
    assert api.put('/community/avatar', json={'avatar_id': STARTERS[0]}).status_code == 401


def test_personal_photo_is_private_normalized_and_deleted_on_replacement(api, tmp_path):
    _, headers, _ = account(api, 'Alice')
    response = api.put('/community/avatar/photo', headers=headers, json=photo())
    assert response.status_code == 200, response.text
    url = response.json()['avatar']['photo_url']
    assert api.get('/social/summary', headers=headers).json()['avatar'] == response.json()['avatar']
    assert api.get(url).status_code == 401
    image = api.get(url, headers=headers)
    assert image.status_code == 200 and image.headers['content-type'] == 'image/webp'
    with Image.open(io.BytesIO(image.content)) as decoded:
        assert decoded.size == (384, 384)
        assert not decoded.getexif()
    assert len(list((tmp_path / 'player-photos').glob('*'))) == 1
    assert api.put('/community/avatar', headers=headers, json={'avatar_id': STARTERS[0]}).status_code == 200
    assert api.get(url, headers=headers).status_code == 404
    assert not list((tmp_path / 'player-photos').glob('*'))
    assert api.put('/community/avatar/photo', headers=headers, json={'image_base64': 'A' * 30}).status_code == 422


def test_premium_borders_and_creator_cannot_be_claimed_by_players(api):
    uid, headers, _ = account(api, 'Alice')
    data = api.get('/community/avatars', headers=headers).json()
    assert sum(b['locked'] for b in data['borders']) == 34
    assert not any(b['id'] == 'creator-gold' for b in data['borders'])
    for border in ['ruby', 'rainbow', 'creator-gold', 'unknown']:
        assert api.put('/community/avatar/border', headers=headers, json={'border_id': border, 'locked': False}).status_code == 403
    with api.app.state.community.db() as c:
        c.execute('INSERT INTO avatar_unlocks VALUES(?,?,?)', (uid, 'creator-wolf', 'forged-ownership'))
        c.execute('INSERT INTO border_unlocks VALUES(?,?,?)', (uid, 'creator-gold', 'forged-ownership'))
    assert api.put('/community/avatar', headers=headers, json={'avatar_id': 'creator-wolf'}).status_code == 403
    assert api.put('/community/avatar/border', headers=headers, json={'border_id': 'creator-gold'}).status_code == 403
    assert api.put('/community/avatar/border', headers=headers, json={'border_id': 'none'}).status_code == 200
    assert api.put('/community/avatar/border', json={'border_id': 'none'}).status_code == 401


def test_creator_is_unique_survives_alias_and_preserves_selected_style(api):
    uid, owner, _ = account(api, 'Logan')
    with api.app.state.community.db() as c:
        c.execute("UPDATE users SET role='admin' WHERE id=?", (uid,))
    profile = api.get('/community/profile', headers=owner).json()
    assert profile['avatar']['is_creator'] is True
    assert profile['avatar']['id'] == 'creator-wolf'
    assert profile['avatar']['border_id'] == 'creator-gold'
    other_id, other, _ = account(api, 'Moderator')
    with api.app.state.community.db() as c:
        c.execute("UPDATE users SET role='admin' WHERE id=?", (other_id,))
        c.execute("UPDATE users SET nickname='NouvelAlias' WHERE id=?", (uid,))
    assert api.get('/community/profile', headers=other).json()['avatar']['is_creator'] is False
    assert api.put('/community/avatar/border', headers=other, json={'border_id': 'creator-gold'}).status_code == 403
    assert api.put('/community/avatar', headers=owner, json={'avatar_id': 'classic-seer'}).status_code == 200
    assert api.put('/community/avatar/border', headers=owner, json={'border_id': 'none'}).status_code == 200
    after = api.get('/community/profile', headers=owner).json()['avatar']
    assert after['is_creator'] and after['id'] == 'classic-seer' and after['border_id'] == 'none'
    assert api.put('/community/avatar', headers=owner, json={'avatar_id': 'creator-wolf'}).status_code == 200


def test_real_border_unlock_is_shared_on_profiles_and_messages(api):
    uid, owner, _ = account(api, 'Alice')
    _, visitor, _ = account(api, 'Bob')
    with api.app.state.community.db() as c:
        c.execute('INSERT INTO border_unlocks VALUES(?,?,?)', (uid, 'rainbow', 'test-challenge'))
    assert api.put('/community/avatar/border', headers=owner, json={'border_id': 'rainbow'}).status_code == 200
    assert api.post('/community/messages', headers=owner, json={'text': 'Bonjour'}).status_code == 201
    assert api.get(f'/social/profiles/{uid}', headers=visitor).json()['avatar']['border_id'] == 'rainbow'
    assert api.get('/community/messages', headers=visitor).json()['messages'][0]['avatar']['border_id'] == 'rainbow'
    data = api.get('/community/avatars', headers=owner).json()
    assert next(b for b in data['borders'] if b['id'] == 'rainbow')['locked'] is False
    assert api.get('/community/profile', headers=visitor).json()['avatar']['border_id'] == 'none'


def test_creator_artwork_is_a_published_download_not_an_app_asset(api):
    import hashlib
    catalog = api.get('/content/packs').json()['packs']
    pack = next(p for p in catalog if p['id'] == 'avatars-classic')
    entry = next(f for f in pack['files'] if f['asset'].endswith('/creator-wolf.jpg'))
    response = api.get(entry['url'])
    assert response.status_code == 200
    assert hashlib.sha256(response.content).hexdigest() == entry['sha256']


def test_blocked_profiles_do_not_expose_the_photo(api):
    uid, owner, _ = account(api, 'Alice')
    other_id, other, _ = account(api, 'Bob')
    url = api.put('/community/avatar/photo', headers=owner, json=photo()).json()['avatar']['photo_url']
    assert api.get(url, headers=other).status_code == 200
    assert api.put(f'/social/blocks/{other_id}', headers=owner, json={'blocked': True}).status_code == 200
    assert api.get(url, headers=other).status_code == 404
    assert api.get(f'/social/profiles/{uid}', headers=other).json()['avatar'] is None


def test_account_deletion_removes_portrait_and_ownership(api, tmp_path):
    uid, headers, _ = account(api, 'Alice')
    api.put('/community/avatar/photo', headers=headers, json=photo())
    request = api.post('/community/account-deletion/request', json={'email': 'alice@example.test'})
    assert request.status_code == 202, request.text
    challenge = request.json()['challenge_id']
    confirmed = api.post('/community/account-deletion/confirm', json={'challenge_id': challenge, 'code': OUTBOX[-1]['code'], 'confirm': True})
    assert confirmed.status_code == 200, confirmed.text
    with api.app.state.community.db() as c:
        assert c.execute('SELECT * FROM player_avatars WHERE user_id=?', (uid,)).fetchone() is None
        assert c.execute('SELECT * FROM player_avatar_styles WHERE user_id=?', (uid,)).fetchone() is None
        assert c.execute('SELECT * FROM border_unlocks WHERE user_id=?', (uid,)).fetchone() is None
    assert not list((tmp_path / 'player-photos').glob('*'))


def test_community_messages_include_the_updated_account_portrait(api):
    _, alice, _ = account(api, 'Alice')
    _, bob, _ = account(api, 'Bob')
    assert api.post('/community/messages', headers=alice, json={'text': 'Bonjour le village'}).status_code == 201
    api.put('/community/avatar', headers=alice, json={'avatar_id': 'classic-seer'})
    message = api.get('/community/messages', headers=bob).json()['messages'][0]
    assert message['avatar']['id'] == 'classic-seer'
    assert 'email' not in message
