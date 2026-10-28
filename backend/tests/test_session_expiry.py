import sqlite3
import time

from fastapi.testclient import TestClient

from mordeviel_api.main import app

from .helpers import post_verified


def test_player_session_lasts_14_days_without_sliding_refresh(tmp_path, monkeypatch):
    path = tmp_path / "session.sqlite3"
    monkeypatch.setenv("MORDEVIEL_COMMUNITY_DB", str(path))
    with TestClient(app) as api:
        before = time.time()
        response = post_verified(
            api,
            "/community/register",
            json={
                "nickname": "Alice",
                "password": "private-password-123",
            },
        ).json()
        deadline = response["expires_at"]
        assert before + 14 * 86400 <= deadline <= time.time() + 14 * 86400
        headers = {"Authorization": "Bearer " + response["token"]}
        assert api.get("/community/me", headers=headers).status_code == 200
        with sqlite3.connect(path) as connection:
            assert (
                connection.execute("SELECT expires FROM sessions").fetchone()[0]
                == deadline
            )
            connection.execute("UPDATE sessions SET expires=?", (time.time() - 1,))
        assert api.get("/community/me", headers=headers).status_code == 401


def test_admin_session_lasts_24_hours_and_promotion_revokes_player_session(
    tmp_path, monkeypatch
):
    import sys

    from mordeviel_api import create_admin

    path = tmp_path / "admin-session.sqlite3"
    monkeypatch.setenv("MORDEVIEL_COMMUNITY_DB", str(path))
    with TestClient(app) as api:
        player = post_verified(
            api,
            "/community/register",
            json={"nickname": "Alice", "password": "private-password-123"},
        ).json()
        player_headers = {"Authorization": "Bearer " + player["token"]}
        monkeypatch.setattr(
            sys,
            "argv",
            ["create_admin", "--nickname", "Alice", "--email", "alice@example.test"],
        )
        monkeypatch.setattr(
            create_admin.getpass, "getpass", lambda _: "private-password-123"
        )
        create_admin.main()
        assert api.get("/community/me", headers=player_headers).status_code == 401
        before = time.time()
        admin = post_verified(
            api,
            "/community/login",
            json={"nickname": "Alice", "password": "private-password-123"},
        ).json()
        assert admin["user"]["role"] == "admin"
        assert before + 86400 <= admin["expires_at"] <= time.time() + 86400
        headers = {"Authorization": "Bearer " + admin["token"]}
        assert api.get("/community/admin/dashboard", headers=headers).status_code == 200
        with sqlite3.connect(path) as c:
            assert (
                c.execute("SELECT expires FROM sessions").fetchone()[0]
                == admin["expires_at"]
            )
            c.execute("UPDATE sessions SET expires=?", (time.time() - 1,))
        assert api.get("/community/admin/dashboard", headers=headers).status_code == 403
