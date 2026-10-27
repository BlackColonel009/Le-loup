import sqlite3
import sys
import time

from fastapi.testclient import TestClient

from le_loup_api import create_admin
from le_loup_api.main import app
from le_loup_api.moderation import discouraged

from .helpers import post_verified


def test_admin_permissions_moderation_offers_maintenance(tmp_path, monkeypatch):
    path = tmp_path / "admin.sqlite3"
    monkeypatch.setenv("LE_LOUP_COMMUNITY_DB", str(path))
    monkeypatch.delenv("LE_LOUP_SUPPORT_TOKEN", raising=False)
    monkeypatch.setattr(
        sys,
        "argv",
        ["create_admin", "--nickname", "Logan R.D", "--email", "logan@example.test"],
    )
    monkeypatch.setattr(
        create_admin.getpass, "getpass", lambda _: "private-test-password"
    )
    create_admin.main()
    with TestClient(app) as api:
        admin_data = post_verified(
            api,
            "/community/login",
            json={"nickname": "Logan R.D", "password": "private-test-password"},
        ).json()
        assert admin_data["user"]["role"] == "admin" and admin_data["user"]["verified"]
        admin = {"Authorization": "Bearer " + admin_data["token"]}
        user_data = post_verified(
            api,
            "/community/register",
            json={
                "nickname": "Alice",
                "password": "player-test-password",
                "role": "admin",
            },
        ).json()
        user = {"Authorization": "Bearer " + user_data["token"]}
        user_id = user_data["user"]["id"]
        assert user_data["user"]["role"] == "player"
        assert api.get("/community/admin/dashboard", headers=user).status_code == 403
        assert api.get("/community/admin/dashboard", headers=admin).status_code == 200
        for word, status in [("sale con", 422), ("connard", 422), ("sexe", 423)]:
            result = post_verified(
                api, "/community/messages", headers=user, json={"text": word}
            )
            assert result.status_code == status, result.text
        assert (
            api.get("/community/me", headers=user).json()["user"]["muted_until"]
            > time.time() + 10700
        )
        assert (
            post_verified(
                api, "/community/messages", headers=user, json={"text": "Bonjour"}
            ).status_code
            == 423
        )
        assert api.get("/community/messages", headers=user).json()["messages"] == []
        assert (
            post_verified(
                api,
                "/community/tickets",
                headers=user,
                json={"subject": "Restriction", "text": "Je conteste la restriction."},
            ).status_code
            == 201
        )
        assert (
            post_verified(
                api,
                f"/community/admin/users/{user_id}",
                headers=admin,
                json={"action": "unmute"},
            ).status_code
            == 200
        )
        assert (
            post_verified(
                api, "/community/messages", headers=user, json={"text": "con"}
            ).status_code
            == 422
        )
        assert (
            post_verified(
                api,
                "/community/messages",
                headers=user,
                json={"text": "Bonjour le village"},
            ).status_code
            == 201
        )
        again = post_verified(
            api, "/community/messages", headers=user, json={"text": "merde"}
        )
        assert "1/3" in again.json()["detail"]
        assert (
            post_verified(
                api,
                f"/community/admin/users/{user_id}",
                headers=admin,
                json={"action": "ban"},
            ).status_code
            == 200
        )
        assert api.get("/community/messages", headers=user).status_code == 403
        assert (
            post_verified(
                api,
                "/community/login",
                json={"nickname": "Alice", "password": "player-test-password"},
            ).status_code
            == 403
        )
        assert (
            post_verified(
                api,
                f"/community/admin/users/{user_id}",
                headers=admin,
                json={"action": "unban"},
            ).status_code
            == 200
        )
        offer = {
            "id": "intense",
            "title": "Intense Premium",
            "category": "Thèmes complets",
            "description": "Pack doré",
            "price_minor": 499,
            "currency": "EUR",
            "visible": True,
            "on_sale": True,
        }
        assert (
            api.put(
                "/community/admin/offers/intense", headers=user, json=offer
            ).status_code
            == 403
        )
        assert (
            api.put(
                "/community/admin/offers/intense", headers=admin, json=offer
            ).status_code
            == 200
        )
        product = next(
            p
            for p in api.get("/shop/catalog").json()["products"]
            if p["id"] == "intense"
        )
        assert product["price_minor"] == 499 and not product["purchasable"]
        assert (
            post_verified(
                api, "/shop/purchase", json={"product_id": "intense"}
            ).status_code
            == 409
        )
        maintenance = {
            "local_enabled": False,
            "online_enabled": False,
            "message": "On est en petite maintenance, s’il vous plaît.",
        }
        assert (
            api.put(
                "/community/admin/maintenance", headers=user, json=maintenance
            ).status_code
            == 403
        )
        assert (
            api.put(
                "/community/admin/maintenance", headers=admin, json=maintenance
            ).status_code
            == 200
        )
        assert api.get("/status").json()["local_enabled"] is False
        assert (
            post_verified(api, "/rooms", json={"nickname": "Test"}).status_code == 503
        )
        maintenance["local_enabled"] = True
        maintenance["online_enabled"] = True
        assert (
            api.put(
                "/community/admin/maintenance", headers=admin, json=maintenance
            ).status_code
            == 200
        )
    with sqlite3.connect(path) as db:
        assert db.execute("SELECT count(*) FROM admin_audit").fetchone()[0] >= 6


def test_filter_boundaries_and_obfuscation():
    assert discouraged("CONNARD")
    assert discouraged("c.o.n.n.a.r.d")
    assert discouraged("p0rn0")
    assert not discouraged("Nous pouvons discuter du concours et de la connexion.")
