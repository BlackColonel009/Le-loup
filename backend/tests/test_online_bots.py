import os
import time
from contextlib import ExitStack

import pytest
from fastapi.testclient import TestClient

from mordeviel_api.main import app

from .helpers import post_verified
from .test_online import receive


def wait_for(predicate):
    deadline = time.monotonic() + 10
    while not predicate():
        assert time.monotonic() < deadline, "Les bots n’ont pas effectué l’action attendue."
        time.sleep(0.025)


def command(socket, action, *, error=False, **values):
    request_id = time.monotonic_ns()
    socket.send_json({"action": action, "request_id": request_id, **values})
    for _ in range(400):
        event = socket.receive_json()
        if event.get("request_id") == request_id:
            assert event["type"] == ("error" if error else "command.ok"), event
            return event
    raise AssertionError("Commande MDJ non confirmée.")


@pytest.mark.skipif(not os.getenv("MORDEVIEL_DART"), reason="Real Dart runtime required")
def test_regular_host_adds_server_bots_and_wolves_speak_in_turn_without_leaks(tmp_path, monkeypatch):
    monkeypatch.setenv("MORDEVIEL_COMMUNITY_DB", str(tmp_path / "bots.sqlite3"))
    with TestClient(app) as api, ExitStack() as stack:
        account = post_verified(api, "/community/register", json={
            "nickname": "Maitre", "password": "test-password-123",
        }).json()
        assert account["user"]["role"] != "admin"
        response = api.post("/rooms", headers={"Authorization": "Bearer " + account["token"]},
                            json={"nickname": "Maitre", "public": True})
        assert response.status_code == 201, response.text
        room = response.json()
        engine = api.app.state.rooms.get(room["code"])
        mdj = stack.enter_context(api.websocket_connect(room["host_path"]))
        mdj.send_json({"token": room["host_token"]})
        snapshot = receive(mdj, "host.snapshot")["room"]
        player = stack.enter_context(api.websocket_connect(room["player_path"]))
        player.send_json({"version": 1, "type": "room.join", "code": room["code"], "nickname": "Humain"})
        human_id = receive(player, "room.joined")["id"]
        deck = {key: 0 for key in snapshot["deck"]}
        deck.update(villager=3, werewolf=3, seer=1, witch=1)
        command(mdj, "configure", deck=deck, camp_only=False)
        player.send_json({"version": 1, "type": "player.ready", "ready": True})
        command(mdj, "bots.configure", paused=False, delay_ms=250)
        command(mdj, "bots.add", count=7)
        wait_for(lambda: len(engine.snapshot["players"]) == 8 and all(p["ready"] for p in engine.snapshot["players"]))
        assert engine.snapshot["has_bots"] and not engine.snapshot["test_mode"]
        assert engine.snapshot["bot_count"] == 7
        command(mdj, "bots.add", error=True, count=21)
        # The player transport cannot execute host commands.
        player.send_json({"version": 1, "type": "host.command", "action": "bots.add", "count": 1})
        for _ in range(200):
            rejected = player.receive_json()
            if rejected.get("type") == "error":
                assert rejected["message"] == "Action non autorisée."
                break
        else:
            raise AssertionError("Un joueur ne doit pas pouvoir ajouter des bots.")
        command(mdj, "start")
        command(mdj, "bots.add", error=True, count=1)
        assert len(engine.snapshot["players"]) == 8
        command(mdj, "night.start", seconds=120)
        command(mdj, "night.call", call="wolves")
        assignments = engine.snapshot["assignments"]
        wolves = sorted(p["id"] for p in engine.snapshot["players"]
                        if p.get("is_bot") and assignments[p["id"]] == "werewolf")
        assert len(wolves) >= 2
        wait_for(lambda: len(engine.snapshot.get("game_host", {}).get("wolf_messages", [])) == len(wolves))
        messages = engine.snapshot["game_host"]["wolf_messages"]
        assert [m["author"] for m in messages] == wolves
        targets = {p["nickname"] for p in engine.snapshot["players"] if assignments[p["id"]] != "werewolf"}
        assert all(any(m["text"] == f"Je propose de dévorer {name}." for name in targets) for m in messages)
        assert set(engine.snapshot["game_host"]["wolf_choices"]) == set(wolves)
        revision = engine.snapshot["game"]["phase_revision"]
        for _ in range(200):
            private = receive(player, "game.private")
            if private["phase_revision"] == revision:
                break
        else:
            raise AssertionError("État privé introuvable")
        if assignments[human_id] != "werewolf":
            assert "messages" not in private and "choices" not in private
        command(mdj, "night.advance")
        assert engine.snapshot["game_host"]["wolf_messages"] == []
        assert api.delete(f"/rooms/{room['code']}",
                          headers={"Authorization": "Bearer " + room["host_token"]}).status_code == 204
