import os
from contextlib import ExitStack

import pytest
from fastapi.testclient import TestClient

from mordeviel_api.main import app
from mordeviel_api.voice import VoiceHub

from .helpers import post_verified
from .test_online import receive
from .test_voice import token_payload


@pytest.mark.skipif(not os.getenv('MORDEVIEL_DART'), reason='Requires actual Dart game engine')
def test_voice_permissions_follow_real_engine_and_private_sessions(tmp_path, monkeypatch):
    monkeypatch.setenv('MORDEVIEL_COMMUNITY_DB', str(tmp_path / 'voice.sqlite3'))
    monkeypatch.setenv('MORDEVIEL_VOICE_URL', 'wss://voice.example.test')
    monkeypatch.setenv('LIVEKIT_API_KEY', 'fixture-key')
    monkeypatch.setenv('LIVEKIT_API_SECRET', 's' * 48)
    calls = []

    async def rpc(self, method, data):
        calls.append((method, data))
        return {}
    monkeypatch.setattr(VoiceHub, 'rpc', rpc)
    with TestClient(app) as api, ExitStack() as stack:
        created = post_verified(api, '/rooms', json={'nickname': 'MDJ'}).json()
        code = created['code']
        host = stack.enter_context(api.websocket_connect(created['host_path']))
        host.send_json({'token': created['host_token']})
        receive(host, 'host.snapshot')

        def command(action, **fields):
            host.send_json({'action': action, **fields})
            receive(host, 'command.ok')

        command('narration.configure', profile='classic_male', automatic=False)
        command('voice.configure', enabled=True, open=True, muted=[])
        players = {}
        for i in range(4):
            peer = stack.enter_context(api.websocket_connect(created['player_path']))
            peer.send_json({'type': 'room.join', 'version': 1, 'code': code, 'nickname': f'Joueur {i}'})
            joined = receive(peer, 'room.joined')
            players[joined['id']] = (peer, joined['token'])
            snapshot = receive(peer, 'room.snapshot')
            assert 'voice_access' not in snapshot and 'voice_muted' not in snapshot
            peer.send_json({'version': 1, 'type': 'player.ready', 'ready': True})
            receive(peer, 'room.snapshot')
        command('start')
        command('night.start')
        command('night.call', call='wolves')
        engine = api.app.state.rooms.get(code)
        wolf = next(pid for pid, role in engine.snapshot['assignments'].items() if role == 'werewolf')
        villager = next(pid for pid in players if pid != wolf)
        endpoint = f'/rooms/{code}/voice/access'
        assert api.post(endpoint).status_code == 401
        assert api.post(endpoint, headers={'Authorization': 'Bearer ' + code}).status_code == 403
        wolf_grant = api.post(endpoint, headers={'Authorization': 'Bearer ' + players[wolf][1]}).json()
        assert wolf_grant['channel'] == 'wolves' and wolf_grant['publish']
        village_grant = api.post(endpoint, headers={'Authorization': 'Bearer ' + players[villager][1]}).json()
        assert village_grant['channel'] is None and 'token' not in village_grant
        host_grant = api.post(endpoint, headers={'Authorization': 'Bearer ' + created['host_token']}).json()
        assert token_payload(host_grant['token'])['video']['room'] == token_payload(wolf_grant['token'])['video']['room']
        command('voice.configure', enabled=True, open=True, muted=[wolf])
        muted = api.post(endpoint, headers={'Authorization': 'Bearer ' + players[wolf][1]}).json()
        assert muted['publish'] is False and muted['epoch'] != wolf_grant['epoch']
        assert any(method == 'DeleteRoom' for method, _ in calls)
        # A participant cannot forge host commands through their game socket.
        peer = players[villager][0]
        peer.send_json({'version': 1, 'type': 'game.action', 'action': 'voice.configure',
                        'phase_revision': engine.snapshot['game']['phase_revision'], 'enabled': True})
        error = receive_error(peer)
        assert error['type'] == 'error'


def receive_error(peer):
    for _ in range(100):
        event = peer.receive_json()
        if event['type'] == 'error':
            return event
    raise AssertionError('Expected denied game action')
