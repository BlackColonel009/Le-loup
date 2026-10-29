import pytest
from fastapi.testclient import TestClient

from mordeviel_api import private_chat
from mordeviel_api.main import app

from .test_social import account, befriend


@pytest.fixture
def api(tmp_path, monkeypatch):
    monkeypatch.setenv('MORDEVIEL_COMMUNITY_DB', str(tmp_path / 'chat.sqlite3'))
    with TestClient(app) as client:
        yield client


def test_private_messages_require_friendship_and_both_sides_see_authenticated_author(api):
    a, b, other = account(api, 'Alice'), account(api, 'Bob'), account(api, 'Charlie')
    assert api.get(f'/social/chats/{b[0]}', headers=a[1]).status_code == 403
    befriend(api, a, b)
    sent = api.post(f'/social/chats/{b[0]}', headers=a[1], json={'text':'Salut Bob', 'sender_id':other[0]})
    assert sent.status_code == 201
    history = api.get(f'/social/chats/{a[0]}', headers=b[1]).json()
    assert history['messages'][0]['sender_id'] == a[0]
    assert history['messages'][0]['text'] == 'Salut Bob'
    assert api.get(f'/social/chats/{b[0]}', headers=other[1]).status_code == 403
    assert api.put(f'/social/blocks/{b[0]}', headers=a[1], json={'blocked':True}).status_code == 200
    assert api.get(f'/social/chats/{a[0]}', headers=b[1]).status_code == 403


def test_conversation_is_physically_erased_after_24_hours_and_next_message_starts_new_window(api, monkeypatch):
    a, b = account(api, 'Alice'), account(api, 'Bob')
    befriend(api, a, b)
    now = private_chat.time.time()
    assert api.post(f'/social/chats/{b[0]}', headers=a[1], json={'text':'Éphémère'}).status_code == 201
    initial = api.get(f'/social/chats/{a[0]}', headers=b[1]).json()
    assert 86390 < initial['reset_at'] - now < 86410
    monkeypatch.setattr(private_chat.time, 'time', lambda: now + 86402)
    expired = api.get(f'/social/chats/{b[0]}', headers=a[1]).json()
    assert expired['messages'] == [] and expired['reset_at'] is None
    with api.app.state.community.db() as c:
        assert c.execute('SELECT COUNT(*) FROM friend_chat_messages').fetchone()[0] == 0
    assert api.post(f'/social/chats/{a[0]}', headers=b[1], json={'text':'Nouvelle journée'}).status_code == 201
    new = api.get(f'/social/chats/{b[0]}', headers=a[1]).json()
    assert len(new['messages']) == 1 and new['reset_at'] > initial['reset_at']


def test_private_chat_accepts_shared_stickers_and_rejects_unknown_ones(api):
    a, b = account(api, 'Alice'), account(api, 'Bob')
    befriend(api, a, b)
    token = '[[sticker:classic_villager_joy]]'
    assert api.post(f'/social/chats/{b[0]}', headers=a[1], json={'text':token}).status_code == 201
    history = api.get(f'/social/chats/{a[0]}', headers=b[1]).json()
    assert history['messages'][0]['text'] == token
    assert api.post(f'/social/chats/{b[0]}', headers=a[1], json={'text':'[[sticker:not-a-sticker]]'}).status_code == 422
