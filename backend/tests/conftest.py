import pytest

from mordeviel_api import email_security

from .helpers import OUTBOX


@pytest.fixture(autouse=True)
def fake_email(monkeypatch):
    OUTBOX.clear()
    monkeypatch.setattr(email_security, "require_mailer", lambda: None)
    monkeypatch.setattr(
        email_security,
        "send_code",
        lambda email, code, purpose: OUTBOX.append(
            {"email": email, "code": code, "purpose": purpose}
        ),
    )
