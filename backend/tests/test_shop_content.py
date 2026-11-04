from fastapi.testclient import TestClient

from mordeviel_api.main import app

from .helpers import post_verified


def test_official_content_and_public_coin_shop(tmp_path, monkeypatch):
    monkeypatch.setenv("MORDEVIEL_COMMUNITY_DB", str(tmp_path / "content.sqlite3"))
    monkeypatch.setenv("MORDEVIEL_SUPPORT_TOKEN", "admin-test-content")
    with TestClient(app) as api:
        info = api.get("/community/info").json()
        assert len(info["faq"]) >= 4 and info["announcements"]
        item = {
            "kind": "announcement",
            "title": "Nouvelle annonce",
            "body": "Les tests continuent.",
        }
        assert (
            post_verified(api, "/community/admin/content", json=item).status_code == 403
        )
        admin = {"Authorization": "Bearer admin-test-content"}
        identifier = post_verified(
            api, "/community/admin/content", headers=admin, json=item
        ).json()["id"]
        assert (
            api.get("/community/info").json()["announcements"][0]["title"]
            == "Nouvelle annonce"
        )
        assert (
            api.put(
                f"/community/admin/content/{identifier}",
                headers=admin,
                json={**item, "title": "Annonce corrigée"},
            ).status_code
            == 200
        )
        assert (
            api.delete(
                f"/community/admin/content/{identifier}", headers=admin
            ).status_code
            == 200
        )
        assert all(
            row["id"] != identifier
            for row in api.get("/community/info").json()["announcements"]
        )
        catalog = api.get("/shop/catalog").json()
        assert catalog["purchases_enabled"] is True
        assert catalog["payments_enabled"] is False
        assert len(catalog["products"]) == 9
        for product in catalog["products"]:
            assert product["purchasable"] is False
        assert api.post('/shop/purchase', json={
            'product_id': catalog['products'][0]['id'], 'day': catalog['day'],
            'expected_price': catalog['products'][0]['coin_price'],
        }).status_code == 401
