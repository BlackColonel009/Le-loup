import base64
import io
import sqlite3
import time

from fastapi.testclient import TestClient
from PIL import Image

from mordeviel_api.main import app

from .helpers import OUTBOX, post_verified


def register(api, name="Alice"):
    result = post_verified(
        api,
        "/community/register",
        json={
            "nickname": name,
            "password": "private-password-123",
        },
    )
    assert result.status_code == 201
    return {"Authorization": "Bearer " + result.json()["token"]}


def test_website_and_gallery_public_access(tmp_path, monkeypatch):
    monkeypatch.setenv("MORDEVIEL_COMMUNITY_DB", str(tmp_path / "website.sqlite3"))
    monkeypatch.setenv("MORDEVIEL_PUBLIC_SUPPORT_EMAIL", "contact@example.test")
    with TestClient(app) as api:
        for path in (
            "/",
            "/confidentialite",
            "/suppression-compte",
            "/support",
            "/administration",
        ):
            response = api.get(path)
            assert response.status_code == 200
            assert "Mordeviel" in response.text
            assert (
                "frame-ancestors 'none'" in response.headers["content-security-policy"]
            )
        assert api.get("/site-assets/site.css").status_code == 200
        assert api.get("/site-assets/screen-village.png").status_code == 200
        assert api.get("/health").json()["status"] == "ok"
        assert api.get("/site-config").json() == {
            "support_email": "contact@example.test",
            "download_url": "",
            "download_version": "",
        }
        cards = api.get("/gallery/cards").json()["cards"]
        assert len(cards) == 9
        horror = [card for card in cards if card['edition'] == 'horror']
        assert len(horror) == 3
        for card in horror:
            response = api.get(card['image_url'])
            assert response.status_code == 200
            assert response.headers['content-type'] == 'image/png'
        assert api.get("/community/admin/site/cards").status_code == 403


def test_horror_gallery_upgrades_existing_database_once(tmp_path, monkeypatch):
    path = tmp_path / 'existing-gallery.sqlite3'
    monkeypatch.setenv('MORDEVIEL_COMMUNITY_DB', str(path))
    with TestClient(app):
        pass
    with sqlite3.connect(path) as connection:
        connection.execute("DELETE FROM site_cards WHERE edition='horror'")
        connection.execute("DELETE FROM settings WHERE key='site_horror_gallery_seeded'")
        connection.execute("UPDATE site_cards SET title='Carte personnalisée',published=0 WHERE edition='classic'")
    with TestClient(app) as api:
        cards = api.get('/gallery/cards').json()['cards']
        assert len([card for card in cards if card['edition'] == 'horror']) == 3
        assert not any(card['edition'] == 'classic' for card in cards)
    with sqlite3.connect(path) as connection:
        connection.execute("UPDATE site_cards SET published=0 WHERE edition='horror'")
    with TestClient(app) as api:
        assert not any(card['edition'] == 'horror' for card in api.get('/gallery/cards').json()['cards'])
    with sqlite3.connect(path) as connection:
        assert connection.execute("SELECT COUNT(*) FROM site_cards WHERE edition='horror'").fetchone()[0] == 3
        assert connection.execute("SELECT COUNT(*) FROM site_cards WHERE title='Carte personnalisée' AND published=0").fetchone()[0] == 3


def test_admin_download_link_permissions_validation_and_persistence(
    tmp_path, monkeypatch
):
    path = tmp_path / "downloads.sqlite3"
    monkeypatch.setenv("MORDEVIEL_COMMUNITY_DB", str(path))
    url = "https://mega.nz/file/test-apk#cle-de-dechiffrement"
    body = {"download_url": url, "download_enabled": True, "download_version": "0.1.0"}
    endpoint = "/community/admin/site/download"
    with TestClient(app) as api:
        assert api.get(endpoint).status_code == 403
        assert api.put(endpoint, json=body).status_code == 403
        auth = register(api)
        assert api.put(endpoint, json=body, headers=auth).status_code == 403
        with sqlite3.connect(path) as connection:
            connection.execute("UPDATE users SET role='admin'")
        for bad in (
            "javascript:alert(1)",
            "http://mega.nz/file/test#key",
            "https://user:pwd@mega.nz/file/test",
            "https://mega.nz/file/hello\nworld",
            "https://mega.nz:bad/file/test",
        ):
            assert (
                api.put(
                    endpoint, json={**body, "download_url": bad}, headers=auth
                ).status_code
                == 422
            )
        assert (
            api.put(
                endpoint, json={**body, "download_url": ""}, headers=auth
            ).status_code
            == 422
        )
        assert api.put(endpoint, json=body, headers=auth).status_code == 200
        assert api.get(endpoint, headers=auth).json() == body
        public = api.get("/site-config").json()
        assert public["download_url"] == url
        assert public["download_version"] == "0.1.0"
    with TestClient(app) as api:
        assert api.get("/site-config").json()["download_url"] == url
        assert (
            api.put(
                endpoint, json={**body, "download_enabled": False}, headers=auth
            ).status_code
            == 200
        )
        assert api.get("/site-config").json()["download_url"] == ""
        assert api.get(endpoint, headers=auth).json()["download_url"] == url


def test_deletion_removes_only_owner_data_and_revokes_sessions(tmp_path, monkeypatch):
    path = tmp_path / "delete.sqlite3"
    monkeypatch.setenv("MORDEVIEL_COMMUNITY_DB", str(path))
    with TestClient(app) as api:
        alice = register(api)
        bob = register(api, "Bob")
        api.post(
            "/community/messages", headers=alice, json={"text": "Bonjour le village"}
        )
        api.post("/community/messages", headers=bob, json={"text": "Bonsoir les amis"})
        api.post(
            "/community/tickets",
            headers=alice,
            json={"subject": "Aide", "text": "Question privée"},
        )
        challenge = api.post(
            "/community/account-deletion/request", json={"email": "alice@example.test"}
        )
        assert challenge.status_code == 202
        assert OUTBOX[-1]["purpose"] == "delete"
        body = {
            "challenge_id": challenge.json()["challenge_id"],
            "code": OUTBOX[-1]["code"],
            "confirm": True,
        }
        assert (
            api.post(
                "/community/account-deletion/confirm", json={**body, "confirm": False}
            ).status_code
            == 422
        )
        assert api.get("/community/profile", headers=alice).status_code == 200
        assert (
            api.post("/community/account-deletion/confirm", json=body).status_code
            == 200
        )
        assert (
            api.post("/community/account-deletion/confirm", json=body).status_code
            == 400
        )
        assert api.get("/community/profile", headers=alice).status_code == 401
        assert api.get("/community/profile", headers=bob).status_code == 200
        with sqlite3.connect(path) as connection:
            assert connection.execute("SELECT nickname FROM users").fetchall() == [
                ("Bob",)
            ]
            assert connection.execute("SELECT text FROM messages").fetchall() == [
                ("Bonsoir les amis",)
            ]
            assert connection.execute("SELECT COUNT(*) FROM tickets").fetchone()[0] == 0
            assert connection.execute("SELECT COUNT(*) FROM replies").fetchone()[0] == 0


def test_deletion_expiry_attempt_limit_purpose_and_banned_account(
    tmp_path, monkeypatch
):
    path = tmp_path / "safety.sqlite3"
    monkeypatch.setenv("MORDEVIEL_COMMUNITY_DB", str(path))
    with TestClient(app) as api:
        register(api)
        reset = api.post(
            "/community/password/request", json={"identifier": "Alice"}
        ).json()
        assert (
            api.post(
                "/community/account-deletion/confirm",
                json={
                    "challenge_id": reset["challenge_id"],
                    "code": OUTBOX[-1]["code"],
                    "confirm": True,
                },
            ).status_code
            == 400
        )
        missing = api.post(
            "/community/account-deletion/request",
            json={"email": "missing@example.test"},
        )
        challenge = api.post(
            "/community/account-deletion/request", json={"email": "alice@example.test"}
        )
        assert missing.status_code == challenge.status_code == 202
        assert missing.json()["message"] == challenge.json()["message"]
        body = {
            "challenge_id": challenge.json()["challenge_id"],
            "code": OUTBOX[-1]["code"],
            "confirm": True,
        }
        wrong = "000000" if body["code"] != "000000" else "111111"
        for _ in range(5):
            assert (
                api.post(
                    "/community/account-deletion/confirm", json={**body, "code": wrong}
                ).status_code
                == 400
            )
        assert (
            api.post("/community/account-deletion/confirm", json=body).status_code
            == 400
        )
        challenge = api.post(
            "/community/account-deletion/request", json={"email": "alice@example.test"}
        ).json()
        body = {
            "challenge_id": challenge["challenge_id"],
            "code": OUTBOX[-1]["code"],
            "confirm": True,
        }
        with sqlite3.connect(path) as connection:
            connection.execute(
                "UPDATE email_challenges SET expires=? WHERE id=?",
                (time.time() - 1, body["challenge_id"]),
            )
        assert (
            api.post("/community/account-deletion/confirm", json=body).status_code
            == 400
        )
        with sqlite3.connect(path) as connection:
            connection.execute("UPDATE users SET banned=1")
            connection.execute(
                "UPDATE email_challenges SET expires=? WHERE id=?",
                (time.time() + 100, body["challenge_id"]),
            )
        assert (
            api.post("/community/account-deletion/confirm", json=body).status_code
            == 200
        )


def test_gallery_admin_upload_edit_hide_delete_and_reject_invalid_images(
    tmp_path, monkeypatch
):
    path = tmp_path / "gallery.sqlite3"
    monkeypatch.setenv("MORDEVIEL_COMMUNITY_DB", str(path))
    with TestClient(app) as api:
        auth = register(api)
        assert api.get("/community/admin/site/cards", headers=auth).status_code == 403
        with sqlite3.connect(path) as connection:
            connection.execute("UPDATE users SET role='admin'")
        output = io.BytesIO()
        Image.new("RGB", (24, 36), "gold").save(output, "PNG")
        body = {
            "title": "Le Gardien",
            "role_name": "Gardien",
            "edition": "horror",
            "description": "Une protection nocturne.",
            "published": True,
            "image_base64": base64.b64encode(output.getvalue()).decode(),
        }
        assert api.post("/community/admin/site/cards", json=body).status_code == 403
        bad = {
            **body,
            "image_base64": base64.b64encode(b'<svg onload="evil()"></svg>').decode(),
        }
        assert (
            api.post("/community/admin/site/cards", headers=auth, json=bad).status_code
            == 422
        )
        created = api.post("/community/admin/site/cards", headers=auth, json=body)
        assert created.status_code == 201
        card_id = created.json()["id"]
        cards = api.get("/gallery/cards").json()["cards"]
        card = next(c for c in cards if c["id"] == card_id)
        assert api.get(card["image_url"]).headers["content-type"] == "image/webp"
        edit = {
            **body,
            "image_base64": None,
            "published": False,
            "title": "Le Salvateur",
        }
        assert (
            api.put(
                "/community/admin/site/cards/" + card_id, headers=auth, json=edit
            ).status_code
            == 200
        )
        assert all(
            c["id"] != card_id for c in api.get("/gallery/cards").json()["cards"]
        )
        assert api.get(card["image_url"]).status_code == 404
        assert len(list((tmp_path / "site-uploads").iterdir())) == 1
        assert (
            api.delete(
                "/community/admin/site/cards/" + card_id, headers=auth
            ).status_code
            == 200
        )
        assert list((tmp_path / "site-uploads").iterdir()) == []
