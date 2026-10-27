import os
from contextlib import ExitStack

import pytest
from fastapi.testclient import TestClient
from starlette.websockets import WebSocketDisconnect

from le_loup_api.main import app

from .helpers import post_verified


def receive(socket, kind):
    for _ in range(100):
        event = socket.receive_json()
        assert event.get("type") != "error", event
        if event.get("type") == kind:
            return event
    raise AssertionError(f"Missing {kind}")


@pytest.mark.skipif(
    not os.getenv("LE_LOUP_DART"), reason="Set LE_LOUP_DART for real engine integration"
)
def test_real_online_game_private_roles_host_permissions_and_reconnect():
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
            }
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
            assert "assignments" not in snapshot and "game_host" not in snapshot
            assert snapshot["players"][-1]["appearance"] == "female"
            player.send_json({"version": 1, "type": "player.ready", "ready": True})
            receive(player, "room.snapshot")
            players.append(player)
        mdj.send_json({"action": "start"})
        receive(mdj, "command.ok")
        for player in players:
            role = receive(player, "game.private")
            assert role["role"] in {"villager", "werewolf"}
        mdj.send_json({"action": "night.start", "seconds": 120})
        receive(mdj, "command.ok")
        mdj.send_json({"action": "night.call", "call": "wolves"})
        receive(mdj, "command.ok")
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
        mdj.send_json({"action": "room.close"})


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
