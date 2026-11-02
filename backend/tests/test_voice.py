import asyncio
import base64
import hashlib
import hmac
import importlib.util
import json
from pathlib import Path
from types import SimpleNamespace

import pytest
from fastapi import HTTPException

from mordeviel_api.voice import VoiceHub, session_identity


class Engine:
    def __init__(self):
        self.closed = False
        self.token_hash = hashlib.sha256(b'host-session').digest()
        self.player_tokens = {hashlib.sha256(b'player-session').hexdigest(): 'p1'}
        self.snapshot = {
            'players': [{'id': 'p1', 'connected': True}],
            'automatic_narration': False,
            'game': {'phase_revision': 1},
            'voice_access': {'host': {'channel': 'village', 'publish': True},
                             'p1': {'channel': 'village', 'publish': True}},
        }


def token_payload(token):
    segment = token.split('.')[1]
    return json.loads(base64.urlsafe_b64decode(segment + '=' * (-len(segment) % 4)))


@pytest.fixture
def hub(monkeypatch):
    monkeypatch.setenv('MORDEVIEL_VOICE_URL', 'wss://voice.example.test')
    monkeypatch.setenv('LIVEKIT_API_KEY', 'test-key')
    monkeypatch.setenv('LIVEKIT_API_SECRET', 's' * 48)
    return VoiceHub()


def test_private_session_is_required_and_bots_cannot_join():
    engine = Engine()
    assert session_identity(engine, 'Bearer host-session') == 'host'
    assert session_identity(engine, 'Bearer player-session') == 'p1'
    for credential in ['', 'Bearer 123456', 'Bearer username', 'Basic player-session']:
        with pytest.raises(HTTPException):
            session_identity(engine, credential)
    engine.snapshot['players'][0]['is_bot'] = True
    with pytest.raises(HTTPException):
        session_identity(engine, 'Bearer player-session')


def test_audio_only_grants_and_revocation_rotate_channels(hub):
    calls = []

    async def rpc(method, data):
        calls.append((method, data))
        return {}

    hub.rpc = rpc
    engine = Engine()

    async def scenario():
        first = await hub.grant(engine, 'p1')
        payload = token_payload(first['token'])
        grants = payload['video']
        assert grants['canPublishSources'] == ['microphone']
        assert grants['canPublishData'] is False
        assert not grants.get('roomCreate') and not grants.get('roomAdmin')
        assert payload['exp'] - payload['iat'] == 60
        message, signature = first['token'].rsplit('.', 1)
        expected = base64.urlsafe_b64encode(hmac.new(hub.secret.encode(), message.encode(), hashlib.sha256).digest()).decode().rstrip('=')
        assert hmac.compare_digest(signature, expected)
        assert 'p1' not in grants['room'] and '123456' not in grants['room']
        engine.snapshot['voice_access']['p1']['publish'] = False
        second = await hub.grant(engine, 'p1')
        assert second['epoch'] != first['epoch']
        assert token_payload(second['token'])['video']['canPublish'] is False
        assert calls[1][0] == 'DeleteRoom'
        assert calls[1][1]['room'] == grants['room']
        assert calls[2][0] == 'CreateRoom'
        engine.snapshot['voice_access']['p1'] = {'channel': None, 'publish': False}
        denied = await hub.grant(engine, 'p1')
        assert denied['channel'] is None and 'token' not in denied

    asyncio.run(scenario())


def test_phase_race_never_returns_an_old_channel_token(hub):
    engine = Engine()

    async def rpc(method, data):
        if method == 'CreateRoom':
            engine.snapshot['voice_access']['p1'] = {'channel': None, 'publish': False}
            hub.state_changed(engine)
        return {}

    hub.rpc = rpc
    with pytest.raises(HTTPException) as failure:
        asyncio.run(hub.grant(engine, 'p1'))
    assert failure.value.status_code == 409
    assert hub.states[engine].retired


def test_media_control_failure_fails_before_issuing_access(hub):
    async def failed(method, data):
        raise OSError('unreachable')
    hub.rpc = failed
    with pytest.raises(OSError):
        asyncio.run(hub.grant(Engine(), 'p1'))


def test_narration_temporarily_removes_publish_permission(hub, monkeypatch):
    from mordeviel_api import voice
    clock = [100.0]
    monkeypatch.setattr(voice.time, 'monotonic', lambda: clock[0])
    monkeypatch.setattr(voice, 'narration_duration', lambda profile, cue: 2.0)
    engine = Engine()
    engine.snapshot['automatic_narration'] = True
    engine.snapshot['game']['narration_events'] = [{'revision': 1, 'cue': 'mdj_wolves.wav'}]

    async def rpc(method, data):
        return {}
    hub.rpc = rpc

    async def scenario():
        first = await hub.grant(engine, 'p1')
        assert first['publish'] is False and first['blocked_ms'] == 2000
        clock[0] += 3
        next_grant = await hub.grant(engine, 'p1')
        assert next_grant['publish'] is True
        assert next_grant['epoch'] != first['epoch']
    asyncio.run(scenario())


def test_prepare_preserves_existing_env_and_keys(tmp_path, monkeypatch):
    spec = importlib.util.spec_from_file_location('prepare_voice', Path(__file__).resolve().parents[2] / 'tools/deploy/prepare_voice.py')
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    mode_changes = []
    monkeypatch.setattr(module, 'os', SimpleNamespace(
        name='posix', chmod=lambda path, mode: mode_changes.append((path, mode))))
    env = tmp_path / '.env'
    original = 'SMTP_USE_TLS=true\nMORDEVIEL_SMTP_PASSWORD=private-fixture\n'
    env.write_text(original)
    config = module.prepare(tmp_path)
    first = env.read_text()
    assert first.startswith(original)
    assert 'auto_create: false' in config.read_text()
    module.prepare(tmp_path)
    assert env.read_text() == first
    assert all(path != env for path, _ in mode_changes)
    assert (config, 0o600) in mode_changes
    assert config.parent == tmp_path / 'data/livekit'


def test_prepare_makes_new_env_private(tmp_path, monkeypatch):
    spec = importlib.util.spec_from_file_location('prepare_voice', Path(__file__).resolve().parents[2] / 'tools/deploy/prepare_voice.py')
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    mode_changes = []
    monkeypatch.setattr(module, 'os', SimpleNamespace(
        name='posix', chmod=lambda path, mode: mode_changes.append((path, mode))))
    module.prepare(tmp_path)
    assert (tmp_path / '.env', 0o600) in mode_changes
