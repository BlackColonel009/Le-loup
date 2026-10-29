import hashlib
import os
import secrets
from contextlib import ExitStack
from types import SimpleNamespace

import pytest
from fastapi.testclient import TestClient

from mordeviel_api import social, social_scheduler
from mordeviel_api.main import app

from .helpers import post_verified
from .test_online import receive


@pytest.fixture
def api(tmp_path, monkeypatch):
    monkeypatch.setenv("MORDEVIEL_COMMUNITY_DB", str(tmp_path / "social.sqlite3"))
    # No real SMTP calls, including the scheduler started by the lifespan.
    monkeypatch.setattr(social_scheduler, "send_message", lambda message: None)
    with TestClient(app) as client:
        yield client


def account(api, name):
    response = post_verified(
        api,
        "/community/register",
        json={"nickname": name, "password": "test-password-123"},
    )
    assert response.status_code == 201, response.text
    body = response.json()
    return (
        body["user"]["id"],
        {"Authorization": "Bearer " + body["token"]},
        body["token"],
    )


def befriend(api, a, b):
    assert (
        api.post(
            f"/social/friends/{b[0]}", headers=a[1], json={"action": "request"}
        ).status_code
        == 200
    )
    assert (
        api.post(
            f"/social/friends/{a[0]}", headers=b[1], json={"action": "accept"}
        ).status_code
        == 200
    )


class Room:
    def __init__(self, db, owner, code="606060", public=True):
        self.db = db
        self.owner_id = owner
        self.social_id = secrets.token_hex(16)
        self.public_room = public
        self.closed = False
        self.title = "Le village test"
        self.accounts = {}
        self.account_stamps = {}
        self.recent_saved = False
        self.process = SimpleNamespace(returncode=None)
        self.snapshot = {
            "code": code,
            "host": "Le MDJ",
            "phase": "lobby",
            "visual_pack": "classic",
            "pack_label": "mixed",
            "locked": False,
            "players": [],
        }
        with db.db() as c:
            self.owner_stamp = social.preference(c, owner)["optout"]

    async def close(self):
        self.closed = True
        social.close_room(self.db, self)


def room(api, owner, **kwargs):
    value = Room(api.app.state.community, owner, **kwargs)
    api.app.state.rooms.engines[value.snapshot["code"]] = value
    return value


def prefs(api, user, **changes):
    data = {
        "stats_visibility": "public",
        "invite_emails": True,
        "phone_notifications": False,
        "auto_invite": True,
        **changes,
    }
    response = api.put("/social/preferences", headers=user[1], json=data)
    assert response.status_code == 200, response.text


def test_friend_requests_badges_acceptance_privacy_and_removal(api):
    a, b, c = account(api, "Alice"), account(api, "Bob"), account(api, "Chloe")
    assert api.get(f"/social/profiles/{a[0]}").status_code == 401
    assert (
        api.post(
            f"/social/friends/{a[0]}", headers=a[1], json={"action": "request"}
        ).status_code
        == 422
    )
    assert (
        api.post(
            f"/social/friends/{b[0]}", headers=a[1], json={"action": "request"}
        ).status_code
        == 200
    )
    assert api.get("/social/summary", headers=b[1]).json()["friend_requests"] == 1
    assert (
        api.post(
            f"/social/friends/{b[0]}", headers=a[1], json={"action": "accept"}
        ).status_code
        == 409
    )
    assert (
        api.post(
            f"/social/friends/{a[0]}", headers=b[1], json={"action": "accept"}
        ).status_code
        == 200
    )
    assert api.get("/social/summary", headers=b[1]).json()["friend_requests"] == 0
    prefs(api, a, stats_visibility="friends")
    own = api.get("/social/me", headers=a[1]).json()
    assert "stats" in own and "preferences" in own
    assert "stats" in api.get(f"/social/profiles/{a[0]}", headers=b[1]).json()
    hidden = api.get(f"/social/profiles/{a[0]}", headers=c[1]).json()
    assert (
        hidden["stats_visible"] is False
        and "stats" not in hidden
        and "preferences" not in hidden
    )
    assert (
        api.post(
            f"/social/friends/{a[0]}", headers=b[1], json={"action": "remove"}
        ).status_code
        == 200
    )
    assert "stats" not in api.get(f"/social/profiles/{a[0]}", headers=b[1]).json()


def test_public_rooms_hide_private_rooms_and_secrets(api):
    a, b = account(api, "Alice"), account(api, "Bob")
    public = room(api, a[0])
    private = room(api, a[0], code="707070", public=False)
    public.snapshot["assignments"] = {"secret": "werewolf"}
    public.snapshot["game_host"] = {"wolf_choices": {"secret": "victim"}}
    result = api.get("/social/rooms", headers=b[1]).json()["rooms"]
    assert (
        len(result) == 1
        and result[0]["code"] == "606060"
        and result[0]["theme"] == "mixed"
    )
    assert "assignments" not in str(result) and "wolf_choices" not in str(result)
    assert private.snapshot["code"] not in str(result)
    api.put(f"/social/blocks/{a[0]}", headers=b[1], json={"blocked": True})
    assert api.get("/social/rooms", headers=b[1]).json()["rooms"] == []


def test_invitations_close_history_and_are_not_duplicated(api):
    a, b = account(api, "Alice"), account(api, "Bob")
    befriend(api, a, b)
    r = room(api, a[0])
    social.invite_friends(api.app.state.community, r)
    social.invite_friends(api.app.state.community, r)
    invitations = api.get("/social/invitations", headers=b[1]).json()["invitations"]
    assert len(invitations) == 1 and invitations[0]["status"] == "active"
    assert api.get("/social/summary", headers=b[1]).json()["invitations"] == 1
    assert (
        api.post(
            f"/social/invitations/{invitations[0]['id']}/seen", headers=b[1]
        ).status_code
        == 200
    )
    assert api.get("/social/summary", headers=b[1]).json()["invitations"] == 1
    r.closed = True
    social.close_room(api.app.state.community, r)
    assert api.get("/social/summary", headers=b[1]).json()["invitations"] == 0
    history = api.get("/social/invitations", headers=b[1]).json()["invitations"]
    assert (
        len(history) == 1
        and history[0]["status"] == "closed"
        and "room" not in history[0]
    )


def test_only_host_can_close_room_over_http_and_discovery_and_invites_disappear(api):
    a, b = account(api, "Alice"), account(api, "Bob")
    befriend(api, a, b)
    r = room(api, a[0])
    token = secrets.token_urlsafe(32)
    r.token_hash = hashlib.sha256(token.encode()).digest()
    social.invite_friends(api.app.state.community, r)
    assert len(api.get("/social/rooms", headers=b[1]).json()["rooms"]) == 1
    # Neither a guest, another account, nor even the owner's community token
    # substitutes for the private credential issued to this room's MDJ.
    assert api.delete("/rooms/606060").status_code == 401
    assert api.delete("/rooms/606060", headers=b[1]).status_code == 403
    assert api.delete("/rooms/606060", headers=a[1]).status_code == 403
    assert api.app.state.rooms.get("606060") is r
    headers = {"Authorization": "Bearer " + token}
    assert api.delete("/rooms/606060", headers=headers).status_code == 204
    assert r.closed
    assert "606060" not in api.app.state.rooms.engines
    assert api.get("/social/rooms", headers=b[1]).json()["rooms"] == []
    assert api.get("/social/summary", headers=b[1]).json()["invitations"] == 0
    history = api.get("/social/invitations", headers=b[1]).json()["invitations"]
    assert len(history) == 1 and history[0]["status"] == "closed"
    assert api.delete("/rooms/606060", headers=headers).status_code == 404


def test_block_prevents_requests_and_invitations_both_directions(api):
    a, b = account(api, "Alice"), account(api, "Bob")
    befriend(api, a, b)
    r = room(api, a[0])
    social.invite_friends(api.app.state.community, r)
    assert (
        api.put(
            f"/social/blocks/{a[0]}", headers=b[1], json={"blocked": True}
        ).status_code
        == 200
    )
    assert api.get("/social/summary", headers=b[1]).json()["invitations"] == 0
    assert (
        api.post(
            f"/social/friends/{b[0]}", headers=a[1], json={"action": "request"}
        ).status_code
        == 403
    )
    assert (
        api.post(
            "/social/rooms/606060/invitations", headers=a[1], json={"target_id": b[0]}
        ).status_code
        == 403
    )
    assert api.get("/social/friends", headers=a[1]).json()["friends"] == []


def test_stats_are_authoritative_idempotent_and_recent_includes_mdj(api):
    a, b, host = account(api, "Alice"), account(api, "Bob"), account(api, "Maitre")
    r = room(api, host[0])
    db = api.app.state.community
    social.claim_player(db, r, "wolf", a[0])
    social.claim_player(db, r, "victim", b[0])
    r.snapshot.update(
        {
            "phase": "ended",
            "game": {
                "phase": "ended",
                "winner_ids": ["victim"],
                "history": [
                    {
                        "kind": "action",
                        "actor": "wolf",
                        "action": "wolves.choose",
                        "target": "victim",
                        "role": "werewolf",
                        "camp": "wolves",
                        "night": 1,
                    },
                    {"kind": "death", "target": "victim", "cause": "night", "night": 1},
                    {"kind": "death", "target": "wolf", "cause": "vote", "night": 1},
                ],
            },
        }
    )
    social.sync_match(db, r)
    social.sync_match(db, r)
    a_stats = api.get("/social/me", headers=a[1]).json()["stats"]
    b_stats = api.get("/social/me", headers=b[1]).json()["stats"]
    assert a_stats == {
        "games": 1,
        "wins": 0,
        "wolf_victims": 1,
        "devoured": 0,
        "executed": 1,
    }
    assert b_stats == {
        "games": 1,
        "wins": 1,
        "wolf_victims": 0,
        "devoured": 1,
        "executed": 0,
    }
    assert len(api.get("/social/recent", headers=host[1]).json()["players"]) == 2
    assert (
        api.post("/social/stats", headers=a[1], json={"wins": 999}).status_code == 404
    )


def test_matches_with_bots_keep_recents_but_never_award_public_stats(api):
    a, b, host = account(api, "Alice"), account(api, "Bob"), account(api, "Maitre")
    r = room(api, host[0])
    db = api.app.state.community
    social.claim_player(db, r, "one", a[0])
    social.claim_player(db, r, "two", b[0])
    r.snapshot.update({"phase":"ended", "has_bots":True, "game":{
        "phase":"ended", "winner_ids":["one"], "history":[
            {"kind":"death", "target":"bot", "cause":"night", "night":1}
        ]}})
    social.sync_match(db, r)
    assert api.get("/social/me", headers=a[1]).json()["stats"]["games"] == 0
    assert api.get("/social/me", headers=a[1]).json()["practice_stats"]["games"] == 1
    assert api.get("/social/me", headers=a[1]).json()["practice_stats"]["wins"] == 1
    assert 'practice_stats' not in api.get(f'/social/profiles/{a[0]}', headers=b[1]).json()
    assert len(api.get("/social/recent", headers=host[1]).json()["players"]) == 2


def test_device_credential_is_scoped_and_survives_main_session_expiry(api):
    a, b = account(api, "Alice"), account(api, "Bob")
    prefs(api, b, phone_notifications=True)
    api.post(f"/social/friends/{b[0]}", headers=a[1], json={"action": "request"})
    data = api.post(
        "/social/devices", headers=b[1], json={"device_id": "a" * 32}
    ).json()
    credential = {"Authorization": "Bearer " + data["background_token"]}
    assert api.get("/social/me", headers=credential).status_code == 401
    with api.app.state.community.db() as c:
        c.execute("UPDATE sessions SET expires=0 WHERE user_id=?", (b[0],))
    messages = api.get("/social/device/notifications", headers=credential).json()[
        "notifications"
    ]
    assert len(messages) == 1 and messages[0]["kind"] == "friend"
    assert (
        api.post(
            f"/social/device/notifications/{messages[0]['id']}/delivered",
            headers=credential,
        ).status_code
        == 200
    )
    assert (
        api.get("/social/device/notifications", headers=credential).json()[
            "notifications"
        ]
        == []
    )
    assert api.delete("/social/device", headers=credential).status_code == 200
    assert (
        api.get("/social/device/notifications", headers=credential).status_code == 401
    )


def test_offline_email_is_sent_once_respects_preferences_and_unsubscribe(
    api, monkeypatch
):
    a, b = account(api, "Alice"), account(api, "Bob")
    befriend(api, a, b)
    r = room(api, a[0])
    db = api.app.state.community
    social.invite_friends(db, r)
    outbox = []
    monkeypatch.setattr(social_scheduler, "send_message", lambda m: outbox.append(m))
    monkeypatch.setenv("MORDEVIEL_SMTP_FROM", "village@example.test")
    with db.db() as c:
        c.execute("UPDATE social_notifications SET created=created-60")
    social_scheduler.tick(db, api.app.state.rooms)
    social_scheduler.tick(db, api.app.state.rooms)
    assert len(outbox) == 1 and outbox[0].is_multipart()
    link = str(outbox[0]["List-Unsubscribe"])[1:-1]
    path = link[link.index("/social/") :]
    assert api.get(path).status_code == 200
    assert api.post(path).status_code == 200
    assert (
        api.get("/social/me", headers=b[1]).json()["preferences"]["invite_emails"] == 0
    )
    with db.db() as c:
        c.execute("UPDATE social_notifications SET mail_state='pending'")
    social_scheduler.tick(db, api.app.state.rooms)
    assert len(outbox) == 1


def test_join_accepts_invitation_and_decline_clears_badge(api):
    a, b, c = account(api, "Alice"), account(api, "Bob"), account(api, "Chloe")
    befriend(api, a, b)
    befriend(api, a, c)
    r = room(api, a[0])
    db = api.app.state.community
    social.invite_friends(db, r)
    social.claim_player(db, r, "player-b", b[0])
    assert api.get("/social/summary", headers=b[1]).json()["invitations"] == 0
    invite = api.get("/social/invitations", headers=c[1]).json()["invitations"][0]
    assert (
        api.post(
            f"/social/invitations/{invite['id']}/decline", headers=c[1]
        ).status_code
        == 200
    )
    assert api.get("/social/summary", headers=c[1]).json()["invitations"] == 0


@pytest.mark.skipif(
    not os.getenv("MORDEVIEL_DART"), reason="Real Dart runtime required"
)
def test_real_social_room_identity_mixed_cards_and_invitations(api):
    owner = account(api, "HostSocial")
    player = account(api, "PlayerSocial")
    friend = account(api, "FriendSocial")
    befriend(api, owner, player)
    befriend(api, owner, friend)
    response = api.post(
        "/rooms",
        headers=owner[1],
        json={
            "nickname": "Forged host",
            "title": "Le village mixte",
            "public": True,
            "theme": "mixed",
        },
    )
    assert response.status_code == 201, response.text
    room_data = response.json()
    rooms = api.get("/social/rooms", headers=player[1]).json()["rooms"]
    listing = next(r for r in rooms if r["code"] == room_data["code"])
    assert listing["theme"] == "mixed"
    assert listing["host"] == "HostSocial"
    assert "assignments" not in listing and "host_token" not in listing
    assert api.get("/social/summary", headers=player[1]).json()["invitations"] == 1
    with ExitStack() as stack:
        mdj = stack.enter_context(api.websocket_connect(room_data["host_path"]))
        mdj.send_json({"token": room_data["host_token"]})
        receive(mdj, "host.snapshot")
        socket = stack.enter_context(api.websocket_connect(room_data["player_path"]))
        socket.send_json(
            {
                "version": 1,
                "type": "room.join",
                "code": room_data["code"],
                "nickname": "Forged player",
                "account_token": player[2],
            }
        )
        joined = receive(socket, "room.joined")
        snapshot = receive(socket, "room.snapshot")
        assert snapshot["pack_label"] == "mixed"
        assert snapshot["players"][0]["nickname"] == "PlayerSocial"
        assert "assignments" not in snapshot and "account_token" not in str(snapshot)
        assert api.get("/social/summary", headers=player[1]).json()["invitations"] == 0
        engine = api.app.state.rooms.engines[room_data["code"]]
        assert engine.accounts[joined["id"]] == player[0]
        # Another account cannot steal this authenticated player's resume token.
        from starlette.websockets import WebSocketDisconnect

        with api.websocket_connect(room_data["player_path"]) as intruder:
            intruder.send_json(
                {
                    "version": 1,
                    "type": "room.resume",
                    "code": room_data["code"],
                    "token": joined["token"],
                    "account_token": friend[2],
                }
            )
            with pytest.raises(WebSocketDisconnect):
                for _ in range(10):
                    intruder.receive_json()
        socket.send_json({"version": 1, "type": "player.ready", "ready": True})
        for _ in range(20):
            current = receive(socket, "room.snapshot")
            if current["players"][0]["ready"]:
                break
        else:
            raise AssertionError("The legitimate player's connection was lost")
        mdj.send_json({"action": "room.close"})
        with pytest.raises(WebSocketDisconnect):
            for _ in range(30):
                socket.receive_json()
    invite = api.get("/social/invitations", headers=friend[1]).json()["invitations"][0]
    assert invite["status"] == "closed" and invite.get("room") is None


@pytest.mark.parametrize("source_cause", ["night", "poison"])
def test_sacrifice_statistics_follow_the_actual_source(api, source_cause):
    wolf, guard, host = (
        account(api, "LoupTest"),
        account(api, "GardienTest"),
        account(api, "MaitreTest"),
    )
    r = room(api, host[0])
    db = api.app.state.community
    social.claim_player(db, r, "wolf", wolf[0])
    social.claim_player(db, r, "guard", guard[0])
    r.snapshot.update(
        {
            "phase": "ended",
            "game": {
                "phase": "ended",
                "winner_ids": [],
                "history": [
                    {
                        "kind": "action",
                        "actor": "wolf",
                        "role": "werewolf",
                        "camp": "wolves",
                        "action": "wolves.choose",
                        "target": "rescued",
                        "night": 1,
                    },
                    {
                        "kind": "death",
                        "target": "guard",
                        "cause": "sacrifice",
                        "source_cause": source_cause,
                        "redirected_from": "rescued",
                        "night": 1,
                    },
                ],
            },
        }
    )
    social.sync_match(db, r)
    social.sync_match(db, r)
    assert api.get("/social/me", headers=wolf[1]).json()["stats"][
        "wolf_victims"
    ] == int(source_cause == "night")
    assert api.get("/social/me", headers=guard[1]).json()["stats"]["devoured"] == int(
        source_cause == "night"
    )
