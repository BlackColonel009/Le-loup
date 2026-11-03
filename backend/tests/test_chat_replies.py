import pytest
from fastapi.testclient import TestClient

from mordeviel_api.main import app

from .test_social import account, befriend


@pytest.fixture
def api(tmp_path, monkeypatch):
    monkeypatch.setenv('MORDEVIEL_COMMUNITY_DB', str(tmp_path / 'replies.sqlite3'))
    monkeypatch.setenv('MORDEVIEL_SUPPORT_TOKEN', 'reply-admin')
    with TestClient(app) as client:
        yield client


def test_community_quote_is_resolved_and_disappears_when_original_is_moderated(api):
    a, b = account(api, 'Alice'), account(api, 'Bob')
    original = api.post('/community/messages', headers=a[1], json={'text': 'Bonjour le village'}).json()['id']
    reply = api.post('/community/messages', headers=b[1], json={'text': 'Bonjour !', 'reply_to': original,
        'reply': {'sender': 'Faux auteur', 'text': 'Contenu inventé'}})
    assert reply.status_code == 201
    messages = api.get('/community/messages', headers=a[1]).json()['messages']
    assert messages[-1]['reply'] == {'id': original, 'sender': 'Alice', 'text': 'Bonjour le village'}
    admin = {'Authorization': 'Bearer reply-admin'}
    assert api.delete(f'/community/admin/messages/{original}', headers=admin).status_code == 200
    messages = api.get('/community/messages', headers=b[1]).json()['messages']
    assert messages[-1]['reply'] == {'id': original, 'unavailable': True}
    assert api.post('/community/messages', headers=b[1], json={'text': 'Encore', 'reply_to': original}).status_code == 422


def test_private_quote_is_scoped_and_erased_with_conversation(api):
    a, b, c = account(api, 'Alice'), account(api, 'Bob'), account(api, 'Celia')
    befriend(api, a, b)
    befriend(api, a, c)
    assert api.post(f'/social/chats/{b[0]}', headers=a[1], json={'text': '[[sticker:classic_villager_joy]]'}).status_code == 201
    first = api.get(f'/social/chats/{a[0]}', headers=b[1]).json()['messages'][0]
    assert api.post(f'/social/chats/{a[0]}', headers=b[1], json={'text': 'Bien reçu', 'reply_to': first['id']}).status_code == 201
    received = api.get(f'/social/chats/{b[0]}', headers=a[1]).json()['messages'][-1]
    assert received['reply']['text'] == first['text']
    assert received['reply']['sender'] == 'Alice'
    assert api.post(f'/social/chats/{c[0]}', headers=a[1], json={'text': 'Espionnage', 'reply_to': first['id']}).status_code == 422
    with api.app.state.community.db() as db:
        db.execute('UPDATE friend_chat_windows SET expires=0')
    assert api.get(f'/social/chats/{b[0]}', headers=a[1]).json()['messages'] == []
    assert api.post(f'/social/chats/{b[0]}', headers=a[1], json={'text': 'Trop tard', 'reply_to': first['id']}).status_code == 422


def test_reward_stickers_remain_locked_despite_free_preview_then_can_be_acquired(api):
    a, b = account(api, 'Alice'), account(api, 'Bob')
    befriend(api, a, b)
    pid = 'sticker-rewards_witch_rescue'
    token = '[[sticker:rewards_witch_rescue]]'
    item = next(p for p in api.get('/collection/me', headers=a[1]).json()['products'] if p['id'] == pid)
    assert item['locked'] and not item['owned'] and item['price_minor'] is None
    assert api.post('/community/messages', headers=a[1], json={'text': token}).status_code == 403
    assert api.post(f'/social/chats/{b[0]}', headers=a[1], json={'text': token}).status_code == 403
    assert api.post('/collection/claim', headers=a[1], json={'product_id': pid}).status_code == 409
    assert api.put('/community/admin/collection/products/'+pid,
        headers={'Authorization': 'Bearer reply-admin'},
        json={'price_minor': 0, 'currency': 'XOF', 'visible': True, 'shop': True, 'collector': True, 'bonus': []}).status_code == 200
    assert api.post('/collection/claim', headers=a[1], json={'product_id': pid}).status_code == 200
    assert api.post(f'/social/chats/{b[0]}', headers=a[1], json={'text': token}).status_code == 201
    assert api.post('/community/messages', headers=a[1], json={'text': token}).status_code == 201
    # Bob can see the sticker without receiving Alice's acquisition.
    assert api.get(f'/social/chats/{a[0]}', headers=b[1]).json()['messages'][-1]['text'] == token
    assert api.post(f'/social/chats/{a[0]}', headers=b[1], json={'text': token}).status_code == 403
