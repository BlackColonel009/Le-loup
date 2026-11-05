import base64
import io
import json
from email import policy
from email.parser import BytesParser

import pytest
from fastapi.testclient import TestClient
from PIL import Image

from mordeviel_api import announcement_mail
from mordeviel_api.main import app

from .helpers import post_verified


def account(api, name):
    response = post_verified(
        api,
        "/community/register",
        json={"nickname": name, "password": "test-password-123"},
    )
    assert response.status_code == 201, response.text
    data = response.json()
    return data["user"]["id"], {"Authorization": "Bearer " + data["token"]}


@pytest.fixture
def setup(tmp_path, monkeypatch):
    monkeypatch.setenv(
        "MORDEVIEL_COMMUNITY_DB", str(tmp_path / "announcements.sqlite3")
    )
    monkeypatch.setenv("MORDEVIEL_SMTP_FROM", "village@example.test")
    monkeypatch.setattr(announcement_mail, "require_mailer", lambda: None)
    outbox = []
    monkeypatch.setattr(announcement_mail, "send_message", outbox.append)
    with TestClient(app) as api:
        admin_id, admin = account(api, "Admin")
        with api.app.state.community.db() as c:
            c.execute("UPDATE users SET role='admin' WHERE id=?", (admin_id,))
        yield api, admin, outbox


def publish(api, admin, **values):
    response = api.post(
        "/community/admin/content",
        headers=admin,
        json={
            "kind": "announcement",
            "title": "Nouvelle soirée",
            "body": "Le village vous attend.",
            **values,
        },
    )
    assert response.status_code == 201
    return response.json()["id"]


def test_publication_is_not_an_email_and_explicit_queue_is_idempotent(setup):
    api, admin, outbox = setup
    _, player = account(api, "Alice")
    content = publish(
        api,
        admin,
        title="<Nouvelle>\nsoirée",
        body="Une annonce <script>danger</script>\nSuite",
    )
    endpoint = f"/community/admin/content/{content}/email"
    assert not outbox
    assert api.post(endpoint).status_code == 403
    assert api.post(endpoint, headers=player).status_code == 403
    assert api.get(endpoint, headers=player).status_code == 403
    queued = api.post(endpoint, headers=admin)
    assert queued.status_code == 200
    assert queued.json()["queued"] == 2
    assert api.post(endpoint, headers=admin).json()["already_queued"] is True
    # A worker restart preserves both the queue and its duplicate protection.
    announcement_mail.initialize(api.app.state.community)
    announcement_mail.tick(api.app.state.community)
    announcement_mail.tick(api.app.state.community)
    assert len(outbox) == 2
    email = outbox[0]
    assert "\n" not in str(email["Subject"])
    html = email.get_body(preferencelist=("html",)).get_content()
    assert "&lt;Nouvelle&gt;" in html and "&lt;script&gt;" in html
    assert "<script>" not in html
    assert "LEGENDARY" in html and "logo.png" in html and "#0b111a" in html
    assert "Annonces" in html
    assert '/#annonces' in html
    assert api.get(endpoint, headers=admin).json()["deliveries"] == {"sent": 2}


def test_invisible_faq_and_changed_announcements_are_never_sent(setup):
    api, admin, outbox = setup
    faq = publish(api, admin, kind="faq")
    assert (
        api.post(f"/community/admin/content/{faq}/email", headers=admin).status_code
        == 409
    )
    hidden = publish(api, admin)
    api.delete(f"/community/admin/content/{hidden}", headers=admin)
    assert (
        api.post(f"/community/admin/content/{hidden}/email", headers=admin).status_code
        == 409
    )
    content = publish(api, admin)
    endpoint = f"/community/admin/content/{content}/email"
    api.post(endpoint, headers=admin)
    api.put(
        f"/community/admin/content/{content}",
        headers=admin,
        json={
            "kind": "announcement",
            "title": "Version corrigée",
            "body": "Nouveau texte",
        },
    )
    announcement_mail.tick(api.app.state.community)
    assert not outbox
    assert api.get(endpoint, headers=admin).json()["deliveries"] == {"cancelled": 1}
    assert api.post(endpoint, headers=admin).json()["queued"] == 1
    announcement_mail.tick(api.app.state.community)
    assert len(outbox) == 1 and "Version corrigée" in str(outbox[0]["Subject"])
    pending = publish(api, admin)
    api.post(f"/community/admin/content/{pending}/email", headers=admin)
    api.delete(f"/community/admin/content/{pending}", headers=admin)
    announcement_mail.tick(api.app.state.community)
    assert len(outbox) == 1


def test_preferences_and_eligibility_are_checked_at_queue_and_delivery(setup):
    api, admin, outbox = setup
    banned, _ = account(api, "Banned")
    unverified, _ = account(api, "Unverified")
    unsub, _ = account(api, "Unsubscribed")
    changed, _ = account(api, "ChangedAddress")
    later, _ = account(api, "LaterUnsubscribed")
    db = api.app.state.community
    with db.db() as c:
        c.execute("UPDATE users SET banned=1 WHERE id=?", (banned,))
        c.execute("UPDATE users SET email_verified=0 WHERE id=?", (unverified,))
        c.execute(
            "INSERT INTO community_mail_preferences VALUES(?, 'unsubscribed-token', 0)",
            (unsub,),
        )
        config = json.loads(
            c.execute(
                "SELECT config FROM community_mail_schedule WHERE id=1"
            ).fetchone()[0]
        )
        config["enabled"] = False
        c.execute("UPDATE community_mail_schedule SET config=?", (json.dumps(config),))
    content = publish(api, admin)
    assert (
        api.post(f"/community/admin/content/{content}/email", headers=admin).json()[
            "queued"
        ]
        == 3
    )
    with db.db() as c:
        c.execute("UPDATE users SET email='other@example.test' WHERE id=?", (changed,))
        token = c.execute(
            "SELECT token FROM community_mail_preferences WHERE user_id=?", (later,)
        ).fetchone()[0]
    assert api.post(f"/community/mail/unsubscribe/{token}").status_code == 200
    announcement_mail.tick(db)
    assert (
        len(outbox) == 1
    )  # Admin only; weekly scheduling being disabled is independent.
    counts = api.get(f"/community/admin/content/{content}/email", headers=admin).json()[
        "deliveries"
    ]
    assert counts == {"cancelled": 2, "sent": 1}


def test_failed_or_uncertain_sends_are_not_retried(setup, monkeypatch):
    api, admin, outbox = setup
    content = publish(api, admin)
    endpoint = f"/community/admin/content/{content}/email"
    api.post(endpoint, headers=admin)

    def fail(message):
        outbox.append(message)
        raise OSError("SMTP interrupted")

    monkeypatch.setattr(announcement_mail, "send_message", fail)
    announcement_mail.tick(api.app.state.community)
    announcement_mail.tick(api.app.state.community)
    api.post(endpoint, headers=admin)
    announcement_mail.tick(api.app.state.community)
    assert len(outbox) == 1
    assert api.get(endpoint, headers=admin).json()["deliveries"] == {"failed": 1}


def test_images_are_embedded_in_email_and_image_update_is_a_new_revision(setup):
    api, admin, outbox = setup
    content = publish(api, admin)
    endpoint = f'/community/admin/content/{content}/email'
    api.post(endpoint, headers=admin)
    announcement_mail.tick(api.app.state.community)
    assert len(outbox) == 1
    images = []
    for color in ['gold', 'darkred']:
        output = io.BytesIO()
        Image.new('RGBA', (80,120), color).save(output, format='PNG')
        response = api.post('/community/admin/content-images', headers=admin,
            json={'image_base64':base64.b64encode(output.getvalue()).decode()})
        assert response.status_code == 200
        images.append(response.json()['url'])
    api.put(f'/community/admin/content/{content}', headers=admin, json={
        'kind':'announcement','title':'Nouvelle soirée','body':'Le village vous attend.','images':images})
    assert api.post(endpoint, headers=admin).json()['already_queued'] is False
    assert api.post(endpoint, headers=admin).json()['already_queued'] is True
    announcement_mail.tick(api.app.state.community)
    assert len(outbox) == 2
    # Verify the serialized MIME message, as received by a mail client.
    message = BytesParser(policy=policy.default).parsebytes(outbox[-1].as_bytes())
    html = message.get_body(preferencelist=('html',)).get_content()
    cards = [part for part in message.walk() if part.get_content_type() == 'image/jpeg']
    assert len(cards) == 2
    for card in cards:
        cid = str(card['Content-ID']).strip('<>')
        assert f'cid:{cid}' in html
        assert card.get_content_disposition() == 'inline'
        with Image.open(io.BytesIO(card.get_payload(decode=True))) as image:
            assert image.format == 'JPEG' and image.size == (80,120)
    assert 'Le village vous attend.' in html and 'LEGENDARY' in html


def test_changed_images_cancel_the_old_pending_email(setup):
    api, admin, outbox = setup
    content = publish(api, admin, images=['/site-assets/seer.jpg'])
    endpoint = f'/community/admin/content/{content}/email'
    api.post(endpoint, headers=admin)
    api.put(f'/community/admin/content/{content}', headers=admin, json={
        'kind':'announcement','title':'Nouvelle soirée','body':'Le village vous attend.',
        'images':['/site-assets/witch.jpg']})
    announcement_mail.tick(api.app.state.community)
    assert not outbox
    assert api.get(endpoint, headers=admin).json()['deliveries'] == {'cancelled':1}
