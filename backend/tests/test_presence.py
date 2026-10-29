from types import SimpleNamespace

import pytest
from fastapi.testclient import TestClient

from mordeviel_api import presence, social_scheduler
from mordeviel_api.main import app

from .test_social import account, befriend, prefs

DEVICE = "a" * 32


@pytest.fixture
def api(tmp_path, monkeypatch):
    monkeypatch.setenv("MORDEVIEL_COMMUNITY_DB", str(tmp_path / "presence.sqlite3"))
    monkeypatch.setattr(social_scheduler, "send_message", lambda message: None)
    with TestClient(app) as client:
        yield client


def pulse(api, who, state="online", device=DEVICE):
    response = api.post(
        "/social/presence", headers=who[1], json={"device_id": device, "state": state}
    )
    assert response.status_code == 200, response.text
    return response.json()


def friend(api, viewer):
    return api.get("/social/friends", headers=viewer[1]).json()["friends"][0]


def alerts(api, viewer):
    return api.get(
        f"/social/presence/alerts?device_id={DEVICE}", headers=viewer[1]
    ).json()["alerts"]


@pytest.fixture
def clock(monkeypatch):
    value = [presence.time.time()]
    monkeypatch.setattr(presence, "time", SimpleNamespace(time=lambda: value[0]))
    return value


def test_friend_presence_lifecycle_expiry_and_multiple_devices(api, clock):
    a, b, stranger = account(api, "Alice"), account(api, "Bob"), account(api, "Chloe")
    befriend(api, a, b)
    assert friend(api, b)["presence"] == "offline"
    assert pulse(api, a)["presence"] == "online"
    assert friend(api, b)["presence"] == "online"
    assert (
        "presence"
        not in api.get(f"/social/profiles/{a[0]}", headers=stranger[1]).json()
    )
    assert pulse(api, a, "away")["presence"] == "away"
    assert friend(api, b)["presence"] == "away"
    pulse(api, a, device="b" * 32)
    assert friend(api, b)["presence"] == "online"
    pulse(api, a, "offline", device="b" * 32)
    assert friend(api, b)["presence"] == "away"
    clock[0] += 301
    result = friend(api, b)
    assert result["presence"] == "offline"
    assert result["disconnected_at"] == pytest.approx(clock[0] - 1)
    pulse(api, a)
    clock[0] += 91
    result = friend(api, b)
    assert result["presence"] == "offline"
    assert result["disconnected_at"] == pytest.approx(clock[0] - 1)


def test_connection_alerts_friends_only_deduplicated_independent_phone_receipt(
    api, clock
):
    a, b, stranger = account(api, "Alice"), account(api, "Bob"), account(api, "Chloe")
    befriend(api, a, b)
    pulse(api, a)
    notices = alerts(api, b)
    assert len(notices) == 1 and notices[0]["nickname"] == "Alice"
    assert alerts(api, stranger) == []
    prefs(api, b, phone_notifications=True)
    phone = api.get(
        f"/social/notifications/pending?device_id={DEVICE}", headers=b[1]
    ).json()["notifications"]
    assert len(phone) == 1 and phone[0]["kind"] == "presence"
    assert "s’est connecté" in phone[0]["body"]
    api.post(
        f"/social/presence/alerts/{notices[0]['id']}/delivered",
        headers=b[1],
        json={"device_id": DEVICE},
    )
    assert alerts(api, b) == []
    assert api.get(
        f"/social/notifications/pending?device_id={DEVICE}", headers=b[1]
    ).json()["notifications"]
    for state in ["online", "away", "online", "offline", "online"]:
        pulse(api, a, state)
    assert alerts(api, b) == []
    # A new connection after the anti-spam interval produces one new alert.
    pulse(api, a, "offline")
    clock[0] += 901
    pulse(api, a)
    assert len(alerts(api, b)) == 1
    api.put(f"/social/blocks/{a[0]}", headers=b[1], json={"blocked": True})
    assert alerts(api, b) == []
    assert (
        api.get(
            f"/social/notifications/pending?device_id={DEVICE}", headers=b[1]
        ).json()["notifications"]
        == []
    )


def test_background_notification_poll_is_not_a_foreground_heartbeat_and_logout_is_immediate(
    api,
):
    a, b = account(api, "Alice"), account(api, "Bob")
    befriend(api, a, b)
    prefs(api, a, phone_notifications=True)
    registration = api.post(
        "/social/devices", headers=a[1], json={"device_id": DEVICE}
    ).json()
    background = {"Authorization": "Bearer " + registration["background_token"]}
    assert (
        api.get("/social/device/notifications", headers=background).status_code == 200
    )
    assert friend(api, b)["presence"] == "offline"
    assert (
        api.post(
            "/social/presence", headers=background, json={"device_id": DEVICE}
        ).status_code
        == 401
    )
    pulse(api, a)
    assert api.post("/community/logout", headers=a[1]).status_code == 200
    assert friend(api, b)["presence"] == "offline"
    assert (
        api.get("/social/presence/alerts?device_id=bad", headers=b[1]).status_code
        == 422
    )


def test_alerts_expire_and_are_not_visible_to_another_account(api, clock):
    a, b = account(api, "Alice"), account(api, "Bob")
    befriend(api, a, b)
    pulse(api, a)
    alert = alerts(api, b)[0]
    api.post(
        f"/social/presence/alerts/{alert['id']}/delivered",
        headers=a[1],
        json={"device_id": DEVICE},
    )
    assert alerts(api, b)
    clock[0] += 3601
    assert alerts(api, b) == []
