"""Audio-only LiveKit access derived exclusively from authoritative Dart state."""
import asyncio
import base64
import hashlib
import hmac
import json
import os
import secrets
import time
import urllib.error
import urllib.parse
import urllib.request
import wave
from functools import lru_cache
from pathlib import Path

from fastapi import APIRouter, HTTPException, Request, Response

router = APIRouter()


def _b64(data):
    return base64.urlsafe_b64encode(data).decode().rstrip('=')


def signed_token(key, secret, grants, identity='control', ttl=60):
    now = int(time.time())
    payload = {'iss': key, 'sub': identity, 'iat': now, 'nbf': now - 5,
               'exp': now + ttl, 'video': grants}
    head = _b64(b'{"alg":"HS256","typ":"JWT"}')
    body = _b64(json.dumps(payload, separators=(',', ':')).encode())
    message = f'{head}.{body}'
    signature = hmac.new(secret.encode(), message.encode(), hashlib.sha256).digest()
    return f'{message}.{_b64(signature)}'


@lru_cache(maxsize=512)
def narration_duration(profile, cue):
    # These are validated engine values. Restrict paths again at the boundary.
    if not all(isinstance(v, str) and v.replace('_', '').replace('.', '').isalnum()
               and '/' not in v and '\\' not in v and '..' not in v for v in [profile, cue]):
        return 7.0
    path = Path(__file__).resolve().parents[3] / 'apps/mordeviel/assets/audio/classic/neural' / profile / cue
    try:
        with wave.open(str(path)) as audio:
            return min(30.0, audio.getnframes() / audio.getframerate() + .4)
    except (OSError, wave.Error, ZeroDivisionError):
        return 7.0


class VoiceState:
    def __init__(self):
        self.fingerprint = None
        self.epoch = ''
        self.access = {}
        self.rooms = set()
        self.created = {}
        self.retired = set()
        self.lock = asyncio.Lock()
        self.cue = None
        self.blocked_until = 0.0

    def update(self, engine):
        snapshot = engine.snapshot if not engine.closed else {}
        game = snapshot.get('game', {})
        events = game.get('narration_events', [])
        latest = events[-1] if events else None
        cue = (game.get('night'), latest.get('revision'), latest.get('cue')) if latest else None
        if cue != self.cue:
            self.cue = cue
            self.blocked_until = (time.monotonic() + narration_duration(
                snapshot.get('narration_profile', 'classic_male'), latest['cue'])
                if latest and snapshot.get('automatic_narration', True) else 0.0)
        if not snapshot.get('automatic_narration', True):
            self.blocked_until = 0.0
        blocked = time.monotonic() < self.blocked_until
        access = {identity: {**rights, 'publish': bool(rights.get('publish') and not blocked)}
                  for identity, rights in snapshot.get('voice_access', {}).items()
                  if rights.get('channel') in {'village', 'wolves', 'narrator'}}
        fingerprint = json.dumps([game.get('phase_revision'), access], sort_keys=True)
        if fingerprint != self.fingerprint:
            self.retired.update(self.rooms)
            self.rooms.clear()
            self.epoch = secrets.token_hex(16)
            self.access = access
            self.fingerprint = fingerprint


class VoiceHub:
    def __init__(self):
        self.url = os.getenv('MORDEVIEL_VOICE_URL', '').rstrip('/')
        self.api_url = os.getenv('MORDEVIEL_VOICE_API_URL', 'http://127.0.0.1:7880').rstrip('/')
        self.key = os.getenv('LIVEKIT_API_KEY', '')
        self.secret = os.getenv('LIVEKIT_API_SECRET', '')
        self.states = {}

    @property
    def configured(self):
        url = urllib.parse.urlparse(self.url)
        return bool(self.key and len(self.secret) >= 32 and url.hostname and
                    (url.scheme == 'wss' or url.scheme == 'ws' and url.hostname in {'localhost', '127.0.0.1'}))

    def state_changed(self, engine):
        state = self.states.setdefault(engine, VoiceState())
        state.update(engine)

    async def rpc(self, method, data):
        def send():
            request = urllib.request.Request(
                f'{self.api_url}/twirp/livekit.RoomService/{method}',
                data=json.dumps(data).encode(),
                headers={'Content-Type': 'application/json', 'Authorization': 'Bearer ' +
                         signed_token(self.key, self.secret, {'roomCreate': True})}, method='POST')
            try:
                with urllib.request.urlopen(request, timeout=4) as response:
                    return json.load(response)
            except urllib.error.HTTPError as error:
                if method == 'DeleteRoom' and error.code == 404:
                    return {}
                raise
        return await asyncio.to_thread(send)

    async def _retire(self, state):
        for room in tuple(state.retired):
            await self.rpc('DeleteRoom', {'room': room})
            state.retired.discard(room)
            state.created.pop(room, None)

    async def grant(self, engine, identity):
        self.state_changed(engine)
        state = self.states[engine]
        async with state.lock:
            # Withdraw the previous channel before admitting anyone to the new one.
            # Tokens never carry roomCreate; LiveKit auto_create MUST be disabled.
            await self._retire(state)
            state.update(engine)
            if state.retired:
                raise HTTPException(409, 'La phase a changé. Le vocal se reconnecte.')
            rights = state.access.get(identity, {})
            channel = rights.get('channel')
            if not channel:
                return {'channel': None, 'publish': False, 'message': 'Le vocal est fermé pour cette phase.'}
            room = f'mw-{state.epoch}-{channel}'
            current = state.epoch
            if room not in state.rooms or time.monotonic() - state.created.get(room, 0) > 8:
                await self.rpc('CreateRoom', {'name': room, 'empty_timeout': 60,
                                             'departure_timeout': 10, 'max_participants': 21})
                # A phase can advance during the media server round-trip.
                state.update(engine)
                if state.epoch != current:
                    state.retired.add(room)
                    raise HTTPException(409, 'La phase a changé. Le vocal se reconnecte.')
                state.rooms.add(room)
                state.created[room] = time.monotonic()
            grants = {'room': room, 'roomJoin': True, 'canSubscribe': True,
                      'canPublish': rights['publish'], 'canPublishData': False,
                      'canPublishSources': ['microphone'], 'canUpdateOwnMetadata': False}
            return {'url': self.url, 'token': signed_token(self.key, self.secret, grants, identity),
                    'channel': channel, 'epoch': state.epoch, 'publish': rights['publish'],
                    'blocked_ms': max(0, int((state.blocked_until - time.monotonic()) * 1000))}

    async def run(self, rooms):
        while True:
            await asyncio.sleep(.5)
            active = {e for e in rooms.engines.values() if not e.closed and e.process.returncode is None}
            for engine, state in tuple(self.states.items()):
                state.update(engine)
                if engine not in active or engine.closed:
                    state.retired.update(state.rooms)
                    state.rooms.clear()
                try:
                    if self.configured:
                        async with state.lock:
                            await self._retire(state)
                    if engine not in active and not state.retired:
                        self.states.pop(engine, None)
                except (OSError, ValueError):
                    # Retry withdrawal. Access requests also fail closed on this error.
                    pass

    async def close(self):
        if not self.configured:
            return
        for state in self.states.values():
            state.retired.update(state.rooms)
            try:
                async with state.lock:
                    await self._retire(state)
            except (OSError, ValueError):
                pass


def session_identity(engine, authorization):
    scheme, _, token = authorization.partition(' ')
    if scheme.lower() != 'bearer' or not token or len(token) > 512:
        raise HTTPException(401, 'Rejoins le salon avant d’activer le vocal.')
    digest = hashlib.sha256(token.encode()).digest()
    if hmac.compare_digest(digest, engine.token_hash):
        return 'host'
    identity = engine.player_tokens.get(digest.hex())
    player = next((p for p in engine.snapshot.get('players', []) if p['id'] == identity), None)
    if not player or not player.get('connected') or player.get('is_bot'):
        raise HTTPException(403, 'Cette session ne peut pas utiliser le vocal du salon.')
    return identity


@router.post('/rooms/{code}/voice/access')
async def voice_access(code: str, request: Request, response: Response):
    response.headers['Cache-Control'] = 'no-store'
    rooms = request.app.state.rooms
    engine = rooms.get(code)
    if engine is None:
        raise HTTPException(404, 'Ce salon est fermé.')
    identity = session_identity(engine, request.headers.get('authorization', ''))
    request.app.state.community.limit(('voice-access', engine.social_id, identity), 60, 60)
    hub = request.app.state.voice
    if not hub.configured:
        raise HTTPException(503, 'Le vocal n’est pas encore disponible. Le chat écrit reste accessible.')
    try:
        return await hub.grant(engine, identity)
    except (OSError, ValueError):
        raise HTTPException(503, 'Le vocal est momentanément indisponible. Tu peux continuer la partie par écrit.') from None
