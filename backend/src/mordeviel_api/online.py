"""FastAPI gateway; the existing Dart engine remains authoritative."""

import asyncio
import contextlib
import hashlib
import hmac
import json
import logging
import os
import secrets
import shutil
import time
from collections import deque
from pathlib import Path
from typing import Literal

from fastapi import APIRouter, HTTPException, Request, WebSocket, WebSocketDisconnect
from pydantic import BaseModel, Field
from websockets.asyncio.client import connect
from websockets.exceptions import ConnectionClosed

router = APIRouter()
WORKER = (
    Path(__file__).resolve().parents[3] / "packages/local_host/bin/online_worker.dart"
)
MAX_ROOMS = int(os.getenv("MORDEVIEL_MAX_ROOMS", "16"))
ROOM_LIFETIME = int(os.getenv("MORDEVIEL_ROOM_LIFETIME", "21600"))
MAX_MESSAGE = 16384
HOST_ACTIONS = {
    "configure",
    "narration.configure",
    "lock",
    "kick",
    "start",
    "night.start",
    "night.call",
    "night.advance",
    "night.finish",
    "pause",
    "resume",
    "vote.start",
    "day.chat",
    "sentence.spin",
    "sentence.continue",
    "snapshot",
}


class CreateRoom(BaseModel):
    nickname: str = Field(min_length=1, max_length=24)
    title: str = Field(default='Le village de la nuit', min_length=1, max_length=60)
    public: bool = False
    theme: Literal['classic','intense','horror','mixed'] = 'classic'


class Engine:
    def __init__(self, process):
        self.social_id = secrets.token_hex(16)
        self.owner_id = None
        self.public_room = False
        self.title = 'Le village de la nuit'
        self.accounts = {}
        self.account_stamps = {}
        self.owner_stamp = None
        self.player_tokens = {}
        self.recent_saved = False
        self.db = None
        self.process = process
        self.pending = {}
        self.hosts = set()
        self.snapshot = {}
        self.sequence = 0
        self.port = None
        self.expiry = time.monotonic() + ROOM_LIFETIME
        self.connections = 0
        self.lock = asyncio.Lock()
        self.closed = False
        self.close_task = None
        self.reader = asyncio.create_task(self._read())
        self.token_hash = b""

    @classmethod
    async def create(cls, nickname):
        dart = os.getenv("MORDEVIEL_DART") or shutil.which("dart")
        if not dart:
            raise RuntimeError("Dart runtime unavailable")
        process = await asyncio.create_subprocess_exec(
            dart,
            str(WORKER),
            stdin=asyncio.subprocess.PIPE,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.DEVNULL,
            limit=1024 * 1024,
        )
        engine = cls(process)
        try:
            await engine.command({"action": "create", "nickname": nickname})
        except BaseException:
            await engine.close()
            raise
        return engine

    async def _read(self):
        try:
            while line := await self.process.stdout.readline():
                event = json.loads(line)
                if "room" in event:
                    self.snapshot = event["room"]
                    if self.snapshot.get('phase')=='lobby':
                        active={p['id'] for p in self.snapshot.get('players',[])}
                        self.accounts={p:uid for p,uid in self.accounts.items() if p in active}
                    if self.db:
                        from .social import sync_match
                        try:
                            sync_match(self.db,self)
                        except Exception:
                            logging.getLogger(__name__).exception('Social match synchronization failed')
                    for queue in tuple(self.hosts):
                        if queue.full():
                            queue.get_nowait()
                        queue.put_nowait(self.snapshot)
                if "port" in event:
                    self.port = event["port"]
                future = self.pending.pop(event.get("id"), None)
                if future and not future.done():
                    if event["type"] == "command.error":
                        future.set_exception(ValueError(event["message"]))
                    else:
                        future.set_result(event)
        finally:
            if self.db:
                from .social import close_room
                close_room(self.db,self)
            for future in self.pending.values():
                if not future.done():
                    future.set_exception(RuntimeError("Game engine stopped"))
            self.pending.clear()
            for queue in tuple(self.hosts):
                if queue.full():
                    queue.get_nowait()
                queue.put_nowait(None)

    async def command(self, data):
        if self.closed:
            raise RuntimeError("Room closed")
        async with self.lock:
            self.sequence += 1
            identifier = self.sequence
            future = asyncio.get_running_loop().create_future()
            self.pending[identifier] = future
            try:
                self.process.stdin.write(
                    (json.dumps({**data, "id": identifier}) + "\n").encode()
                )
                await self.process.stdin.drain()
                return await asyncio.wait_for(future, 12)
            finally:
                self.pending.pop(identifier, None)

    async def close(self):
        if self.close_task is None:
            self.close_task = asyncio.create_task(self._shutdown())
        await asyncio.shield(self.close_task)

    async def _shutdown(self):
        self.closed = True
        self.process.stdin.close()
        with contextlib.suppress(BrokenPipeError, ConnectionResetError):
            await self.process.stdin.wait_closed()
        try:
            await asyncio.wait_for(self.process.wait(), 3)
        except TimeoutError:
            self.process.kill()
            await self.process.wait()
        await self.reader
        await asyncio.sleep(0)


class Rooms:
    def __init__(self):
        self.db = None
        self.engines = {}
        self.lock = asyncio.Lock()

    def get(self, code):
        engine = self.engines.get(code)
        if not engine or engine.closed or engine.process.returncode is not None:
            return None
        return engine

    async def reap(self):
        while True:
            await asyncio.sleep(30)
            async with self.lock:
                for code, engine in list(self.engines.items()):
                    if (
                        engine.expiry <= time.monotonic()
                        or engine.process.returncode is not None
                    ):
                        self.engines.pop(code)
                        await engine.close()

    async def close(self):
        for engine in list(self.engines.values()):
            await engine.close()
        self.engines.clear()


def manager(websocket):
    return websocket.app.state.rooms


@router.post("/rooms", status_code=201)
async def create_room(data: CreateRoom, request: Request):
    from .administration import status

    maintenance = status(request.app.state.community)
    if not maintenance["online_enabled"]:
        raise HTTPException(503, maintenance["message"])
    rooms = request.app.state.rooms
    account = None
    authorization = request.headers.get('authorization','')
    if authorization:
        from .community import authenticated
        account = authenticated(authorization=authorization,db=request.app.state.community)
        request.app.state.community.limit(('create-social-room',account['id']),5,300)
    if data.public and account is None:
        raise HTTPException(401,'Connecte-toi à la communauté pour publier un salon.')
    if not data.nickname.strip():
        raise HTTPException(422, "Pseudo requis.")
    from .collection import require_room_access
    require_room_access(request.app.state.community, account['id'] if account else None,
                        'classic' if data.theme == 'mixed' else data.theme,
                        {'villager': 'intense', 'werewolf': 'horror'} if data.theme == 'mixed' else {},
                        {'villager': 1, 'werewolf': 1, 'seer': 1, 'witch': 1, 'hunter': 1})
    async with rooms.lock:
        if len(rooms.engines) >= MAX_ROOMS:
            raise HTTPException(503, "Tous les salons sont occupés.")
        try:
            # A six-digit code is chosen by the engine; never reuse a live code.
            for _ in range(5):
                engine = await Engine.create(account['nickname'] if account else data.nickname.strip())
                code = engine.snapshot["code"]
                if code not in rooms.engines:
                    break
                await engine.close()
            else:
                raise RuntimeError("Code allocation failed")
        except (RuntimeError, OSError, TimeoutError):
            raise HTTPException(503, "Le moteur de jeu est indisponible.") from None
        token = secrets.token_urlsafe(32)
        engine.token_hash = hashlib.sha256(token.encode()).digest()
        engine.owner_id = account['id'] if account else None
        if account:
            from .social import preference
            with request.app.state.community.db() as connection:
                engine.owner_stamp=preference(connection,account['id'])['optout']
        engine.public_room = data.public
        engine.title = data.title.strip() or 'Le village de la nuit'
        engine.db = request.app.state.community
        rooms.engines[code] = engine
        await engine.command({'action':'configure','deck':engine.snapshot['deck'],'camp_only':engine.snapshot.get('seer_camp_only',False),
                              'pack':'classic' if data.theme=='mixed' else data.theme,
                              'card_styles':{'villager':'intense','werewolf':'horror'} if data.theme=='mixed' else {}})
        from .social import invite_friends
        invite_friends(request.app.state.community,engine)
    return {
        "code": code,
        "host_token": token,
        "protocol": 1,
        "player_path": f"/rooms/{code}/ws",
        "host_path": f"/rooms/{code}/host",
    }


async def incoming(socket):
    text = await asyncio.wait_for(socket.receive_text(), 60)
    if len(text.encode()) > MAX_MESSAGE:
        raise ValueError("Message trop long.")
    value = json.loads(text)
    if not isinstance(value, dict):
        raise TypeError("Message JSON attendu.")
    return value


def allowed_origin(socket):
    origin = socket.headers.get("origin")
    allowed = os.getenv("MORDEVIEL_ALLOWED_ORIGINS", "").split(",")
    return origin is None or origin in allowed


@router.websocket("/rooms/{code}/ws")
async def player_socket(socket: WebSocket, code: str):
    from .administration import status

    maintenance = status(socket.app.state.community)
    if not maintenance["online_enabled"]:
        await socket.accept()
        await socket.send_json({"type": "error", "message": maintenance["message"]})
        await socket.close(code=1013)
        return
    engine = manager(socket).get(code)
    if not engine or not allowed_origin(socket) or engine.connections >= 24:
        await socket.close(code=1008)
        return
    engine.connections += 1
    await socket.accept()
    try:
        async with connect(
            f"ws://127.0.0.1:{engine.port}/ws", max_size=1024 * 1024
        ) as upstream:
            account_id = None
            authenticated_join = False

            async def from_player():
                nonlocal account_id, authenticated_join
                timestamps = deque()
                while True:
                    # Idle players remain connected; only the initial join is timed out.
                    text = await socket.receive_text()
                    now = time.monotonic()
                    while timestamps and now - timestamps[0] > 1:
                        timestamps.popleft()
                    timestamps.append(now)
                    if len(timestamps) > 40 or len(text.encode()) > MAX_MESSAGE:
                        raise ValueError("Trop de messages.")
                    event = json.loads(text)
                    if not isinstance(event, dict):
                        raise TypeError("Message JSON attendu.")
                    if event.get('type') in {'room.join','room.resume'}:
                        raw_token=event.pop('account_token',None)
                        account=None
                        if raw_token:
                            from .community import authenticated
                            try: account=authenticated(authorization='Bearer '+str(raw_token),db=socket.app.state.community)
                            except HTTPException as error: raise ValueError(error.detail) from error
                        account_id=account['id'] if account else None
                        if event.get('type')=='room.resume':
                            resume_id=engine.player_tokens.get(hashlib.sha256(str(event.get('token','')).encode()).hexdigest())
                            if resume_id in engine.accounts and engine.accounts[resume_id]!=account_id:
                                raise ValueError('Reconnecte-toi avec le compte associé à cette place.')
                        elif account_id is not None and (account_id in engine.accounts.values() or account_id==engine.owner_id):
                            raise ValueError('Ce compte est déjà présent dans le salon.')
                        if account_id is not None and engine.owner_id:
                            from .social import blocked
                            with socket.app.state.community.db() as connection:
                                if blocked(connection,account_id,engine.owner_id): raise ValueError('Ce salon est indisponible pour ce compte.')
                        if account and event.get('type')=='room.join': event['nickname']=account['nickname']
                        authenticated_join=True
                    if (
                        event.get("type") in {"room.join", "room.resume"}
                        and event.get("code") != code
                    ):
                        raise ValueError("Code de salon incorrect.")
                    await upstream.send(json.dumps(event))

            async def to_player():
                async for text in upstream:
                    event=json.loads(text)
                    if event.get('type')=='room.joined' and authenticated_join:
                        from .social import claim_player
                        claim_player(socket.app.state.community,engine,event['id'],account_id)
                        if event.get('token'):
                            engine.player_tokens[hashlib.sha256(event['token'].encode()).hexdigest()]=event['id']
                    await socket.send_text(text)
                await socket.close(code=1001)

            tasks = [
                asyncio.create_task(from_player()),
                asyncio.create_task(to_player()),
            ]
            try:
                done, _ = await asyncio.wait(tasks, return_when=asyncio.FIRST_COMPLETED)
                for task in done:
                    task.result()
            finally:
                for task in tasks:
                    task.cancel()
                await asyncio.gather(*tasks, return_exceptions=True)
    except (WebSocketDisconnect, ConnectionClosed, ValueError, TypeError, OSError):
        with contextlib.suppress(RuntimeError, WebSocketDisconnect):
            await socket.close(code=1008)
    finally:
        engine.connections -= 1


@router.websocket("/rooms/{code}/host")
async def host_socket(socket: WebSocket, code: str):
    rooms = manager(socket)
    engine = rooms.get(code)
    if not engine or not allowed_origin(socket):
        await socket.close(code=1008)
        return
    await socket.accept()
    queue = asyncio.Queue(maxsize=2)
    sender = None
    try:
        auth = await asyncio.wait_for(incoming(socket), 8)
        token = auth.get("token")
        if not isinstance(token, str) or not hmac.compare_digest(
            hashlib.sha256(token.encode()).digest(), engine.token_hash
        ):
            await socket.close(code=1008)
            return
        if engine.hosts:
            await socket.close(code=1008, reason="Le MDJ est déjà connecté.")
            return
        engine.hosts.add(queue)
        queue.put_nowait(engine.snapshot)

        async def send_updates():
            while True:
                snapshot = await queue.get()
                if snapshot is None:
                    await socket.close(code=1001)
                    return
                await socket.send_json({"type": "host.snapshot", "room": snapshot})

        sender = asyncio.create_task(send_updates())
        while True:
            # No inactivity expiry for the authenticated MDJ during debates.
            command = await socket.receive_json()
            if not isinstance(command, dict) or len(json.dumps(command)) > MAX_MESSAGE:
                raise ValueError("Commande invalide.")
            action = command.get("action")
            if action == "room.close":
                await engine.close()
                rooms.engines.pop(code, None)
                return
            if action not in HOST_ACTIONS:
                await socket.send_json(
                    {"type": "error", "message": "Commande MDJ inconnue."}
                )
                continue
            try:
                if action in {'configure', 'narration.configure', 'start'}:
                    from .collection import require_room_access
                    require_room_access(socket.app.state.community, engine.owner_id,
                        command.get('pack', engine.snapshot.get('visual_pack', 'classic')),
                        command.get('card_styles', engine.snapshot.get('card_styles', {})),
                        command.get('deck', engine.snapshot.get('deck', {})),
                        command.get('profile', engine.snapshot.get('narration_profile')))
                result = await engine.command(command)
                await socket.send_json(
                    {
                        "type": "command.ok",
                        "request_id": command.get("request_id"),
                        "id": result["id"],
                    }
                )
            except (ValueError, HTTPException) as error:
                await socket.send_json(
                    {
                        "type": "error",
                        "message": error.detail if isinstance(error, HTTPException) else str(error),
                        "request_id": command.get("request_id"),
                    }
                )
    except (WebSocketDisconnect, ValueError, TypeError, RuntimeError, TimeoutError):
        with contextlib.suppress(RuntimeError, WebSocketDisconnect):
            await socket.close(code=1008)
    finally:
        engine.hosts.discard(queue)
        if sender:
            sender.cancel()
            await asyncio.gather(sender, return_exceptions=True)
