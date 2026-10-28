import sqlite3

from fastapi.testclient import TestClient

from mordeviel_api.main import app

from .helpers import post_verified


def test_community_accounts_chat_and_private_support(tmp_path, monkeypatch):
    path = tmp_path / "community.sqlite3"
    monkeypatch.setenv("MORDEVIEL_COMMUNITY_DB", str(path))
    monkeypatch.setenv("MORDEVIEL_SUPPORT_TOKEN", "test-only-support-secret")
    with TestClient(app) as api:
        assert api.get("/community/messages").status_code == 401
        first = post_verified(
            api,
            "/community/register",
            json={"nickname": "Alice", "password": "test-password-123"},
        )
        assert first.status_code == 201
        token = first.json()["token"]
        alice = {"Authorization": "Bearer " + token}
        assert (
            post_verified(
                api,
                "/community/register",
                json={"nickname": "alice", "password": "test-password-123"},
            ).status_code
            == 409
        )
        bob_data = post_verified(
            api,
            "/community/register",
            json={"nickname": "Bob", "password": "different-password"},
        ).json()
        bob = {"Authorization": "Bearer " + bob_data["token"]}
        assert (
            post_verified(
                api,
                "/community/login",
                json={"nickname": "ALICE", "password": "wrong-password"},
            ).status_code
            == 401
        )
        assert (
            post_verified(
                api,
                "/community/login",
                json={"nickname": "ALICE", "password": "test-password-123"},
            ).status_code
            == 200
        )
        message = post_verified(
            api,
            "/community/messages",
            headers=alice,
            json={"text": "Bonjour le village !"},
        )
        assert message.status_code == 201
        assert (
            api.get("/community/messages", headers=bob).json()["messages"][0][
                "nickname"
            ]
            == "Alice"
        )
        assert (
            post_verified(
                api, "/community/messages", headers=alice, json={"text": "spam"}
            ).status_code
            == 429
        )
        ticket = post_verified(
            api,
            "/community/tickets",
            headers=alice,
            json={"subject": "Problème audio", "text": "Ma musique ne démarre pas."},
        )
        assert ticket.status_code == 201
        identifier = ticket.json()["id"]
        assert ticket.json()["response_target_hours"] == 48
        assert api.get("/community/tickets", headers=bob).json()["tickets"] == []
        assert (
            api.get(f"/community/tickets/{identifier}", headers=bob).status_code == 404
        )
        assert (
            post_verified(
                api,
                f"/community/tickets/{identifier}/reply",
                headers=bob,
                json={"text": "Intrusion"},
            ).status_code
            == 404
        )
        assert api.get("/community/admin/tickets", headers=alice).status_code == 403
        admin = {"Authorization": "Bearer test-only-support-secret"}
        assert (
            api.get("/community/admin/tickets", headers=admin).json()["tickets"][0][
                "subject"
            ]
            == "Problème audio"
        )
        assert (
            post_verified(
                api,
                f"/community/admin/tickets/{identifier}/reply",
                headers=admin,
                json={"text": "Nous vérifions ton problème."},
            ).status_code
            == 200
        )
        replies = api.get(f"/community/tickets/{identifier}", headers=alice).json()
        assert replies["status"] == "answered"
        assert replies["messages"][-1]["author"] == "support"
        assert (
            post_verified(
                api, f"/community/messages/{message.json()['id']}/report", headers=bob
            ).status_code
            == 200
        )
        assert (
            api.get("/community/admin/reports", headers=admin).json()["reports"][0][
                "reports"
            ]
            == 1
        )
        assert (
            api.delete(
                f"/community/admin/messages/{message.json()['id']}", headers=admin
            ).status_code
            == 200
        )
        assert api.get("/community/messages", headers=alice).json()["messages"] == []
        assert post_verified(api, "/community/logout", headers=alice).status_code == 200
        assert api.get("/community/messages", headers=alice).status_code == 401
    with sqlite3.connect(path) as db:
        password = db.execute(
            "SELECT password FROM users WHERE nickname=?", ("Alice",)
        ).fetchone()[0]
        assert password != "test-password-123"
        assert db.execute("SELECT count(*) FROM tickets").fetchone()[0] == 1
    with TestClient(app) as api:
        session = post_verified(
            api,
            "/community/login",
            json={"nickname": "Alice", "password": "test-password-123"},
        ).json()
        assert (
            len(
                api.get(
                    "/community/tickets",
                    headers={"Authorization": "Bearer " + session["token"]},
                ).json()["tickets"]
            )
            == 1
        )
