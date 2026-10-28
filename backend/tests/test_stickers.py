from fastapi.testclient import TestClient

from mordeviel_api.main import app
from mordeviel_api.stickers import STICKERS

from .helpers import post_verified


def test_sticker_community_roundtrip_and_unknown_rejection(tmp_path, monkeypatch):
    monkeypatch.setenv("MORDEVIEL_COMMUNITY_DB", str(tmp_path / "stickers.sqlite3"))
    with TestClient(app) as api:
        sender = post_verified(
            api,
            "/community/register",
            json={"nickname": "StickerFan", "password": "password-for-test"},
        ).json()
        viewer = post_verified(
            api,
            "/community/register",
            json={"nickname": "StickerViewer", "password": "password-for-test"},
        ).json()
        auth = {"Authorization": "Bearer " + sender["token"]}
        token = "[[sticker:" + next(iter(STICKERS)) + "]]"
        assert len(STICKERS) == 17
        assert (
            api.post(
                "/community/messages", headers=auth, json={"text": token}
            ).status_code
            == 201
        )
        received = api.get(
            "/community/messages",
            headers={"Authorization": "Bearer " + viewer["token"]},
        ).json()["messages"]
        assert received[-1]["text"] == token
        assert (
            api.post(
                "/community/messages",
                headers=auth,
                json={"text": "[[sticker:missing_sticker]]"},
            ).status_code
            == 422
        )
