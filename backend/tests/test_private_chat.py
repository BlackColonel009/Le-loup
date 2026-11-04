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


def test_inbox_groups_friends_and_read_receipt_keeps_later_messages(api):
    a, b, c = account(api, 'Alice'), account(api, 'Bob'), account(api, 'Charlie')
    befriend(api, a, b)
    befriend(api, c, b)
    for text in ['Bonjour', 'Tu joues ?']:
        assert api.post(f'/social/chats/{b[0]}', headers=a[1], json={'text': text}).status_code == 201
    api.post(f'/social/chats/{b[0]}', headers=c[1], json={'text': 'Une autre discussion'})
    data = api.get('/social/chats/inbox', headers=b[1]).json()
    assert data['viewer_id'] == b[0] and len(data['conversations']) == 2
    alice = next(m for m in data['conversations'] if m['friend_id'] == a[0])
    assert alice['unread_count'] == 2 and alice['text'] == 'Tu joues ?' and alice['avatar']['id']
    api.post(f'/social/chats/{b[0]}', headers=a[1], json={'text': 'Nouveau pendant la lecture'})
    read = api.post(f'/social/chats/{a[0]}/read', headers=b[1], json={'through_id': alice['last_id']})
    assert read.status_code == 200 and len(read.json()['notification_ids']) == 2
    remaining = api.get('/social/chats/inbox', headers=b[1]).json()['conversations']
    assert len(remaining) == 2
    assert next(m for m in remaining if m['friend_id'] == a[0])['unread_count'] == 1
    assert api.get('/social/chats/inbox', headers=a[1]).json()['conversations'] == []


def test_message_phone_notification_routes_to_friend_and_cancels_when_read(api):
    a, b = account(api, 'Alice'), account(api, 'Bob')
    befriend(api, a, b)
    assert api.put('/social/preferences', headers=b[1], json={'phone_notifications': True}).status_code == 200
    api.post(f'/social/chats/{b[0]}', headers=a[1], json={'text': 'Salut au village'})
    headers = {'Authorization': 'Bearer ' + api.post('/social/devices', headers=b[1], json={'device_id': 'e'*32}).json()['background_token']}
    pending = api.get('/social/device/notifications', headers=headers).json()
    message = next(n for n in pending['notifications'] if n['kind'] == 'message')
    assert message['payload'] == f'chat:{a[0]}' and message['body'] == 'Salut au village'
    assert api.get('/social/chats/inbox', headers=headers).status_code == 401
    assert api.post(f"/social/device/notifications/{message['id']}/delivered", headers=headers).status_code == 200
    assert not any(n['kind'] == 'message' for n in api.get('/social/device/notifications', headers=headers).json()['notifications'])
    # Delivery is distinct from actually reading the conversation.
    entry = api.get('/social/chats/inbox', headers=b[1]).json()['conversations'][0]
    assert entry['unread_count'] == 1
    api.post(f'/social/chats/{a[0]}/read', headers=b[1], json={'through_id': entry['last_id']})
    assert message['id'] in api.get('/social/device/notifications', headers=headers).json()['cancelled_ids']


def test_block_and_24_hour_expiry_remove_message_alerts(api, monkeypatch):
    a, b = account(api, 'Alice'), account(api, 'Bob')
    befriend(api, a, b)
    api.post(f'/social/chats/{b[0]}', headers=a[1], json={'text': 'Éphémère'})
    assert api.get('/social/chats/inbox', headers=b[1]).json()['conversations']
    api.put(f'/social/blocks/{a[0]}', headers=b[1], json={'blocked': True})
    assert api.get('/social/chats/inbox', headers=b[1]).json()['conversations'] == []
    api.put(f'/social/blocks/{a[0]}', headers=b[1], json={'blocked': False})
    now = private_chat.time.time()
    monkeypatch.setattr(private_chat.time, 'time', lambda: now + 86401)
    assert api.get('/social/chats/inbox', headers=b[1]).json()['conversations'] == []
