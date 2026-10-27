import sqlite3
import time

from fastapi.testclient import TestClient

from le_loup_api.main import app

from .helpers import post_verified


def test_session_lasts_24_hours_without_sliding_refresh(tmp_path, monkeypatch):
    path = tmp_path / "session.sqlite3"
    monkeypatch.setenv("LE_LOUP_COMMUNITY_DB", str(path))
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
        assert before + 86400 <= deadline <= time.time() + 86400
        headers = {"Authorization": "Bearer " + response["token"]}
        assert api.get("/community/me", headers=headers).status_code == 200
        with sqlite3.connect(path) as connection:
            assert (
                connection.execute("SELECT expires FROM sessions").fetchone()[0]
                == deadline
            )
            connection.execute("UPDATE sessions SET expires=?", (time.time() - 1,))
        assert api.get("/community/me", headers=headers).status_code == 401
