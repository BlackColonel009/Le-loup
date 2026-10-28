import time

from fastapi.testclient import TestClient

from mordeviel_api import community_mail
from mordeviel_api.main import app

from .helpers import post_verified


def test_reminders_schedule_rotation_optout_admin_and_failure(tmp_path, monkeypatch):
    monkeypatch.setenv("MORDEVIEL_COMMUNITY_DB", str(tmp_path / "reminders.sqlite3"))
    monkeypatch.setenv("MORDEVIEL_SUPPORT_TOKEN", "test-admin-reminders")
    monkeypatch.setenv("MORDEVIEL_SMTP_FROM", "village@example.test")
    monkeypatch.setattr(community_mail, "require_mailer", lambda: None)
    outbox = []
    monkeypatch.setattr(community_mail, "send_message", outbox.append)
    with TestClient(app) as api:
        users = []
        for name in ["Present", "Desinscrit", "Banni", "Nonverifie"]:
            user = post_verified(
                api,
                "/community/register",
                json={"nickname": name, "password": "test-password-123"},
            ).json()
            users.append(
                (user["user"]["id"], {"Authorization": "Bearer " + user["token"]})
            )
        db = api.app.state.community
        admin = {"Authorization": "Bearer test-admin-reminders"}
        config = api.get("/community/admin/mail-schedule", headers=admin).json()
        assert config["interval_days"] == 7 and len(config["phrases"]) >= 5
        assert (
            api.get("/community/admin/mail-schedule", headers=users[0][1]).status_code
            == 403
        )
        config = {
            "enabled": True,
            "interval_days": 3,
            "subject": "Le village revient",
            "phrases": ["Premier appel du village.", "Les loups reviennent."],
        }
        assert (
            api.put(
                "/community/admin/mail-schedule", headers=admin, json=config
            ).status_code
            == 200
        )
        with db.db() as c:
            c.execute(
                "INSERT INTO community_mail_preferences VALUES(?, 'unsub-test-token', 0)",
                (users[1][0],),
            )
            c.execute("UPDATE users SET banned=1 WHERE id=?", (users[2][0],))
            c.execute("UPDATE users SET email_verified=0 WHERE id=?", (users[3][0],))
            c.execute("UPDATE community_mail_schedule SET next_due=0")
        before = time.time()
        community_mail.tick(db)
        community_mail.tick(db)
        assert len(outbox) == 1
        message = outbox[0]
        assert (
            "Premier appel du village."
            in message.get_body(preferencelist=("plain",)).get_content()
        )
        assert (
            "<html" in message.get_body(preferencelist=("html",)).get_content().lower()
        )
        assert "by Logan" in message.get_body(preferencelist=("html",)).get_content()
        schedule = api.get("/community/admin/mail-schedule", headers=admin).json()
        assert before + 3 * 86400 <= schedule["next_due"] <= time.time() + 3 * 86400
        assert schedule["deliveries"]["sent"] == 1
        # The next period rotates its phrase, with no backlog or duplicate sends.
        with db.db() as c:
            c.execute("UPDATE community_mail_schedule SET next_due=0")
        community_mail.tick(db)
        assert (
            len(outbox) == 2
            and "Les loups reviennent."
            in outbox[-1].get_body(preferencelist=("plain",)).get_content()
        )
        link = str(message["List-Unsubscribe"])[1:-1]
        path = link[link.index("/community/") :]
        assert api.post(path).status_code == 200
        with db.db() as c:
            c.execute("UPDATE community_mail_schedule SET next_due=0")
        community_mail.tick(db)
        assert len(outbox) == 2
        # Re-enable this test recipient, then verify a delivery error is recorded once.
        with db.db() as c:
            c.execute(
                "UPDATE community_mail_preferences SET subscribed=1 WHERE user_id=?",
                (users[0][0],),
            )
            c.execute("UPDATE community_mail_schedule SET next_due=0")

        def failed_send(message):
            raise OSError("Simulated SMTP outage")

        monkeypatch.setattr(community_mail, "send_message", failed_send)
        community_mail.tick(db)
        community_mail.tick(db)
        assert (
            api.get("/community/admin/mail-schedule", headers=admin).json()[
                "deliveries"
            ]["failed"]
            == 1
        )
        assert (
            api.put(
                "/community/admin/mail-schedule",
                headers=admin,
                json={**config, "enabled": False},
            ).status_code
            == 200
        )
        with db.db() as c:
            c.execute("UPDATE community_mail_schedule SET next_due=0")
        community_mail.tick(db)
        assert (
            api.get("/community/admin/mail-schedule", headers=admin).json()[
                "deliveries"
            ]["failed"]
            == 1
        )
