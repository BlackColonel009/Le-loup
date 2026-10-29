import os
import time
from contextlib import ExitStack

import pytest
from fastapi.testclient import TestClient
from starlette.websockets import WebSocketDisconnect

from mordeviel_api.main import app

from .helpers import post_verified


def receive(socket, kind):
    for _ in range(100):
        event = socket.receive_json()
        assert event.get("type") != "error", event
        if event.get("type") == kind:
            return event
    raise AssertionError(f"Missing {kind}")


@pytest.mark.skipif(
    not os.getenv("MORDEVIEL_DART"),
    reason="Set MORDEVIEL_DART for real engine integration",
)
@pytest.mark.parametrize("close_via_http", [False, True])
def test_real_online_game_private_roles_host_permissions_and_reconnect(close_via_http, tmp_path, monkeypatch):
    monkeypatch.setenv("MORDEVIEL_COMMUNITY_DB", str(tmp_path / "online.sqlite3"))
    with TestClient(app) as api, ExitStack() as stack:
        response = post_verified(api, "/rooms", json={"nickname": "Logan"})
        assert response.status_code == 201, response.text
        room = response.json()
        code = room["code"]
        assert len(code) == 6
        with api.websocket_connect(room["host_path"]) as intruder:
            intruder.send_json({"token": "wrong"})
            with pytest.raises(WebSocketDisconnect):
                intruder.receive_json()
        mdj = stack.enter_context(api.websocket_connect(room["host_path"]))
        mdj.send_json({"token": room["host_token"]})
        assert receive(mdj, "host.snapshot")["room"]["phase"] == "lobby"
        mdj.send_json(
            {
                "action": "configure",
                "deck": {
                    "villager": 3,
                    "werewolf": 1,
                    "seer": 0,
                    "witch": 0,
                    "hunter": 0,
                },
                "camp_only": False,
                "pack": "intense",
                "card_styles": {
                    "werewolf#0": "horror",
                    "villager#0": "classic",
                    "villager#1": "intense",
                    "villager#2": "horror",
                },
            }
        )
        receive(mdj, "command.ok")
        mdj.send_json(
            {"action": "narration.configure", "profile": "duke", "automatic": True}
        )
        receive(mdj, "command.ok")
        players = []
        tokens = []
        for index in range(4):
            player = stack.enter_context(api.websocket_connect(room["player_path"]))
            player.send_json(
                {
                    "version": 1,
                    "type": "room.join",
                    "code": code,
                    "nickname": f"Player {index}",
                    "appearance": "female",
                }
            )
            joined = receive(player, "room.joined")
            tokens.append(joined["token"])
            snapshot = receive(player, "room.snapshot")
            assert snapshot["visual_pack"] == "intense"
            assert snapshot["narration_profile"] == "duke"
            assert snapshot["automatic_narration"] is True
            assert "assignments" not in snapshot and "game_host" not in snapshot
            assert snapshot["players"][-1]["appearance"] == "female"
            player.send_json({"version": 1, "type": "player.ready", "ready": True})
            receive(player, "room.snapshot")
            players.append(player)
        mdj.send_json({"action": "start"})
        receive(mdj, "command.ok")
        dealt = []
        for player in players:
            role = receive(player, "game.private")
            assert role["role"] in {"villager", "werewolf"}
            dealt.append((role["role"], role["edition"]))
        assert sorted(edition for role, edition in dealt if role == "villager") == [
            "classic",
            "horror",
            "intense",
        ]
        assert [edition for role, edition in dealt if role == "werewolf"] == ["horror"]
        if close_via_http:
            before = time.monotonic()
            mdj.send_json({"action": "phase.schedule", "target": "night", "seconds": 120})
            receive(mdj, "command.ok")
            transition = receive(players[0], "room.snapshot")
            while not transition.get("transition"):
                transition = receive(players[0], "room.snapshot")
            assert transition["phase"] == "role_reveal"
            assert 0 < transition["transition"]["remaining_ms"] <= 5000
            while receive(mdj, "host.snapshot")["room"]["phase"] != "sleep":
                pass
            assert time.monotonic() - before >= 4.5
        else:
            mdj.send_json({"action": "night.start", "seconds": 120})
            receive(mdj, "command.ok")
        mdj.send_json({"action": "night.call", "call": "wolves"})
        receive(mdj, "command.ok")
        mdj.send_json(
            {"action": "narration.configure", "profile": "duke", "automatic": False}
        )
        receive(mdj, "command.ok")
        for player in players:
            for _ in range(100):
                event = receive(player, "room.snapshot")
                if event.get("automatic_narration") is False:
                    assert event["narration_profile"] == "duke"
                    break
            else:
                raise AssertionError("Shared narration mode was not received")
        wolf = players[
            next(i for i, (role, _) in enumerate(dealt) if role == "werewolf")
        ]
        revision = event["game"]["phase_revision"]
        wolf.send_json(
            {
                "version": 1,
                "type": "game.action",
                "action": "wolves.veil",
                "phase_revision": revision,
                "targets": [],
            }
        )
        for _ in range(100):
            private = receive(wolf, "game.private")
            if private.get("veil_requested"):
                break
        else:
            raise AssertionError(
                "Horror wolf ability was not accepted over the remote gateway"
            )
        # Host commands sent through the player channel never grant MDJ access.
        players[0].send_json({"type": "host.command", "action": "night.finish"})
        # A disconnected player can reclaim only their own private session.
        players[0].close()
        resumed = stack.enter_context(api.websocket_connect(room["player_path"]))
        resumed.send_json(
            {"version": 1, "type": "room.resume", "code": code, "token": tokens[0]}
        )
        receive(resumed, "room.joined")
        assert receive(resumed, "game.private")["role"] in {"villager", "werewolf"}
        if close_via_http:
            response = api.delete(
                f"/rooms/{code}",
                headers={"Authorization": "Bearer " + room["host_token"]},
            )
            assert response.status_code == 204, response.text
            assert api.app.state.rooms.get(code) is None
        else:
            mdj.send_json({"action": "room.close"})
        # Wait for the server shutdown handshake before cancelling TestClient tasks.
        for player in [*players[1:], resumed]:
            with pytest.raises(WebSocketDisconnect):
                for _ in range(100):
                    player.receive_json()


def test_room_validation_and_unknown_rooms():
    with TestClient(app) as api:
        assert post_verified(api, "/rooms", json={"nickname": " "}).status_code == 422
        assert (
            post_verified(api, "/rooms", json={"nickname": "x" * 25}).status_code == 422
        )
        with (
            pytest.raises(WebSocketDisconnect),
            api.websocket_connect("/rooms/000000/ws"),
        ):
            pass
