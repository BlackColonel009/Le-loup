import sqlite3
import time

from fastapi.testclient import TestClient

from le_loup_api.main import app

from .helpers import OUTBOX


def test_email_required_reset_single_use_and_private_history(tmp_path, monkeypatch):
    path = tmp_path / "email.sqlite3"
    monkeypatch.setenv("LE_LOUP_COMMUNITY_DB", str(path))
    with TestClient(app) as api:
        assert (
            api.post(
                "/community/register",
                json={"nickname": "Alice", "password": "original-password"},
            ).status_code
            == 422
        )
        data = api.post(
            "/community/register",
            json={
                "nickname": "Alice",
                "password": "original-password",
                "email": "alice@example.test",
            },
        ).json()
        token = {"Authorization": "Bearer " + data["token"]}
        assert data["verification_required"]
        assert "code" not in data
        assert api.get("/community/messages", headers=token).status_code == 403
        assert (
            api.post(
                "/community/email/verify",
                headers=token,
                json={"challenge_id": data["challenge_id"], "code": OUTBOX[-1]["code"]},
            ).status_code
            == 200
        )
        assert api.get("/community/profile", headers=token).json()["email_verified"]
        assert api.get("/community/purchases", headers=token).json()["purchases"] == []
        assert (
            api.post(
                "/community/password",
                headers=token,
                json={
                    "current_password": "original-password",
                    "new_password": "unverified-password",
                    "confirm_password": "unverified-password",
                },
            ).status_code
            == 409
        )
        reset = api.post(
            "/community/password/request", json={"identifier": "Alice"}
        ).json()
        code = OUTBOX[-1]["code"]
        body = {
            "challenge_id": reset["challenge_id"],
            "code": "xxxxxx",
            "new_password": "new-private-password",
            "confirm_password": "new-private-password",
        }
        assert api.post("/community/password/confirm", json=body).status_code == 422
        body["code"] = code
        assert api.post("/community/password/confirm", json=body).status_code == 200
        assert api.get("/community/profile", headers=token).status_code == 401
        assert api.post("/community/password/confirm", json=body).status_code == 400
        assert (
            api.post(
                "/community/login",
                json={"nickname": "Alice", "password": "original-password"},
            ).status_code
            == 401
        )
        assert (
            api.post(
                "/community/login",
                json={"nickname": "Alice", "password": "new-private-password"},
            ).status_code
            == 200
        )
        unknown = api.post(
            "/community/password/request", json={"identifier": "unknown@example.test"}
        )
        assert unknown.status_code == 202
        assert unknown.json()["message"] == reset["message"]


def test_codes_expire_and_five_failures_lock_challenge(tmp_path, monkeypatch):
    path = tmp_path / "attempts.sqlite3"
    monkeypatch.setenv("LE_LOUP_COMMUNITY_DB", str(path))
    with TestClient(app) as api:
        registered = api.post(
            "/community/register",
            json={
                "nickname": "Bob",
                "password": "original-password",
                "email": "bob@example.test",
            },
        ).json()
        token = {"Authorization": "Bearer " + registered["token"]}
        original = OUTBOX[-1]["code"]
        wrong = "000000" if original != "000000" else "000001"
        body = {"challenge_id": registered["challenge_id"], "code": wrong}
        for _ in range(5):
            assert (
                api.post(
                    "/community/email/verify", headers=token, json=body
                ).status_code
                == 400
            )
        body["code"] = original
        assert (
            api.post("/community/email/verify", headers=token, json=body).status_code
            == 400
        )
        new = api.post(
            "/community/email/request",
            headers=token,
            json={"email": "bob@example.test"},
        ).json()
        with sqlite3.connect(path) as db:
            db.execute(
                "UPDATE email_challenges SET expires=? WHERE id=?",
                (time.time() - 1, new["challenge_id"]),
            )
        assert (
            api.post(
                "/community/email/verify",
                headers=token,
                json={"challenge_id": new["challenge_id"], "code": OUTBOX[-1]["code"]},
            ).status_code
            == 400
        )
