from datetime import UTC, datetime, timedelta

import pytest
from fastapi.testclient import TestClient

from mordeviel_api import collection
from mordeviel_api.main import app

from .helpers import post_verified


@pytest.fixture
def collection_api(tmp_path, monkeypatch):
    monkeypatch.setenv("MORDEVIEL_COMMUNITY_DB", str(tmp_path / "collection.sqlite3"))
    monkeypatch.setenv("MORDEVIEL_SUPPORT_TOKEN", "collection-admin-test")
    with TestClient(app) as api:
        body = post_verified(
            api,
            "/community/register",
            json={"nickname": "CollectorFan", "password": "password-for-tests"},
        ).json()
        yield (
            api,
            {"Authorization": "Bearer " + body["token"]},
            {"Authorization": "Bearer collection-admin-test"},
        )


def product(state, pid):
    return next(p for p in state["products"] if p["id"] == pid)


def test_collection_default_classics_free_preview_and_price_gate(collection_api):
    api, user, admin = collection_api
    state = api.get("/collection/me", headers=user).json()
    assert len(state["products"]) == 70
    assert len([p for p in state["products"] if p["owned"]]) == 20
    assert all(p["accessible"] for p in state["products"])
    assert not any(p["claimable"] for p in state["products"])
    assert (
        api.post(
            "/collection/claim", headers=user, json={"product_id": "card-horror-seer"}
        ).status_code
        == 409
    )
    assert api.get("/collection/me").status_code == 401
    assert (
        api.put(
            "/community/admin/collection/settings",
            headers=user,
            json={"free_access": False},
        ).status_code
        == 403
    )
    assert (
        api.put(
            "/community/admin/collection/settings",
            headers=admin,
            json={"free_access": False},
        ).status_code
        == 200
    )
    locked = api.get("/collection/me", headers=user).json()["products"]
    assert all(p["locked"] == (p["theme"] != "classic") for p in locked)
    assert (
        api.put(
            "/community/admin/collection/products/card-classic-seer",
            headers=admin,
            json={"price_minor": 10},
        ).status_code
        == 409
    )
    assert (
        api.put(
            "/community/admin/collection/settings",
            headers=admin,
            json={"free_access": True},
        ).status_code
        == 200
    )
    assert all(
        p["accessible"]
        for p in api.get("/collection/me", headers=user).json()["products"]
    )


def test_free_claim_bonus_persists_once_and_paid_claim_never_charges(collection_api):
    api, user, admin = collection_api
    pid = "card-intense-seer"
    edit = {"price_minor": 250, "currency": "XOF", "bonus": ["card-horror-witch"]}
    assert (
        api.put(
            "/community/admin/collection/products/" + pid, headers=admin, json=edit
        ).status_code
        == 200
    )
    result = api.post(
        "/collection/claim", headers=user, json={"product_id": pid}
    ).json()
    assert result["amount_charged"] == 0 and len(result["granted"]) == 2
    assert api.post("/collection/claim", headers=user, json={"product_id": pid}).json()[
        "already_owned"
    ]
    api.put(
        "/community/admin/collection/settings",
        headers=admin,
        json={"free_access": False},
    )
    state = api.get("/collection/me", headers=user).json()
    assert (
        product(state, pid)["owned"]
        and product(state, "card-horror-witch")["accessible"]
    )
    assert product(state, "card-horror-witch")["owned"]
    other = "card-intense-hunter"
    api.put(
        "/community/admin/collection/products/" + other,
        headers=admin,
        json={"price_minor": 100},
    )
    assert (
        api.post(
            "/collection/claim", headers=user, json={"product_id": other}
        ).status_code
        == 409
    )
    rows = api.get("/community/purchases", headers=user).json()["purchases"]
    assert (
        len(rows) == 1 and rows[0]["amount_minor"] == 0 and rows[0]["status"] == "free"
    )


def test_trials_temporary_all_or_selection_and_room_access(collection_api):
    api, user, admin = collection_api
    today = datetime.now(UTC).date()
    api.put(
        "/community/admin/collection/settings",
        headers=admin,
        json={"free_access": False},
    )
    trial = {
        "title": "Essai Voyante",
        "starts": str(today),
        "ends": str(today),
        "products": ["card-horror-seer"],
    }
    assert (
        api.post(
            "/community/admin/collection/trials", headers=admin, json=trial
        ).status_code
        == 200
    )
    state = api.get("/collection/me", headers=user).json()
    assert product(state, "card-horror-seer")["access_reason"] == "trial"
    assert not product(state, "card-horror-seer")["owned"]
    assert product(state, "card-horror-witch")["locked"]
    with pytest.raises(Exception) as error:
        collection.require_room_access(
            api.app.state.community, None, "horror", deck={"seer": 1}
        )
    assert error.value.status_code == 403
    # All products trial includes environment and voices, without acquiring anything.
    assert (
        api.post(
            "/community/admin/collection/trials",
            headers=admin,
            json={**trial, "title": "Tout découvrir", "products": []},
        ).status_code
        == 200
    )
    collection.require_room_access(
        api.app.state.community, None, "horror", deck={"seer": 1}, voice="ghost"
    )
    assert all(
        p["accessible"]
        for p in api.get("/collection/me", headers=user).json()["products"]
    )
    trials = api.get("/community/admin/collection", headers=admin).json()["trials"]
    for entry in trials:
        api.delete(
            "/community/admin/collection/trials/" + str(entry["id"]), headers=admin
        )
    assert product(api.get("/collection/me", headers=user).json(), "card-horror-seer")[
        "locked"
    ]
    yesterday = str(today - timedelta(days=1))
    api.post(
        "/community/admin/collection/trials",
        headers=admin,
        json={**trial, "starts": yesterday, "ends": yesterday},
    )
    assert product(api.get("/collection/me", headers=user).json(), "card-horror-seer")[
        "locked"
    ]


def test_collector_five_cards_stable_manual_selection_and_claim_source(collection_api):
    api, user, admin = collection_api
    first = api.get("/collection/catalog").json()
    second = api.get("/collection/me", headers=user).json()
    assert first["daily_ids"] == second["daily_ids"]
    cards = [pid for pid in first["daily_ids"] if pid.startswith("card-")]
    assert len(cards) == 5 and len(cards) == len(set(cards))
    wanted = [
        "card-horror-" + r for r in ["seer", "witch", "werewolf", "hunter", "elder"]
    ]
    assert (
        api.put(
            "/community/admin/collection/daily",
            headers=admin,
            json={"day": first["day"], "products": wanted},
        ).status_code
        == 200
    )
    assert api.get("/collection/catalog").json()["daily_ids"] == wanted
    assert (
        api.put(
            "/community/admin/collection/daily",
            headers=admin,
            json={"day": first["day"], "products": wanted[:-1] + [wanted[0]]},
        ).status_code
        == 422
    )
    for pid in ["card-horror-seer", "card-intense-seer"]:
        api.put(
            "/community/admin/collection/products/" + pid,
            headers=admin,
            json={"price_minor": 0},
        )
    assert (
        api.post(
            "/collection/claim",
            headers=user,
            json={"product_id": "card-horror-seer", "source": "collector"},
        ).status_code
        == 200
    )
    assert (
        api.post(
            "/collection/claim",
            headers=user,
            json={"product_id": "card-intense-seer", "source": "collector"},
        ).status_code
        == 409
    )
    # Hidden or removed listings cannot be claimed through a stale client.
    api.put(
        "/community/admin/collection/products/card-horror-witch",
        headers=admin,
        json={"price_minor": 0, "visible": False},
    )
    assert (
        api.post(
            "/collection/claim",
            headers=user,
            json={"product_id": "card-horror-witch", "source": "collector"},
        ).status_code
        == 404
    )


def test_free_duration_and_days_display_expiration(collection_api):
    api, user, admin = collection_api
    assert (
        api.put(
            "/community/admin/collection/settings",
            headers=admin,
            json={"free_access": True, "free_days": 12},
        ).status_code
        == 200
    )
    state = api.get("/collection/me", headers=user).json()
    assert state["free_days_remaining"] == 12
    assert product(state, "card-intense-seer")["free_days_remaining"] == 12
    assert product(state, "card-classic-seer")["free_days_remaining"] is None
    with api.app.state.community.db() as c:
        c.execute(
            "UPDATE settings SET value='2020-01-01' WHERE key='collection_free_until'"
        )
    state = api.get("/collection/me", headers=user).json()
    assert state["free_access"] is False and state["free_days_remaining"] == 0
    assert product(state, "card-intense-seer")["locked"]
    # Re-enable an expired preview: use the configured duration, never a permanent grant.
    api.put(
        "/community/admin/collection/settings",
        headers=admin,
        json={"free_access": True},
    )
    assert api.get("/collection/me", headers=user).json()["free_days_remaining"] == 12


def test_collector_welcome_only_once_each_day(collection_api):
    api, user, _ = collection_api
    assert api.post("/collection/collector/visit", headers=user).json()["show"] is True
    assert api.post("/collection/collector/visit", headers=user).json()["show"] is False
    with api.app.state.community.db() as c:
        c.execute("UPDATE collection_visits SET day='2020-01-01'")
    assert api.post("/collection/collector/visit", headers=user).json()["show"] is True
    assert api.post("/collection/collector/visit").status_code == 401
