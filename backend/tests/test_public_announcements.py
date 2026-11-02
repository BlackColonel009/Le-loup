from fastapi.testclient import TestClient

from mordeviel_api.main import app

from .helpers import post_verified


def test_vitrine_reads_same_visible_announcements_as_game(tmp_path, monkeypatch):
    monkeypatch.setenv("MORDEVIEL_COMMUNITY_DB", str(tmp_path / "public-news.sqlite3"))
    with TestClient(app) as api:
        registered = post_verified(
            api,
            "/community/register",
            json={"nickname": "NewsAdmin", "password": "test-password-123"},
        ).json()
        headers = {"Authorization": "Bearer " + registered["token"]}
        with api.app.state.community.db() as connection:
            connection.execute(
                "UPDATE users SET role='admin' WHERE id=?", (registered["user"]["id"],)
            )
        publication = {
            "kind": "announcement",
            "title": "Soirée du village",
            "body": "Rendez-vous samedi.\nVenez avec vos amis !",
        }
        created = api.post(
            "/community/admin/content", headers=headers, json=publication
        )
        assert created.status_code == 201
        content_id = created.json()["id"]
        api.post(
            "/community/admin/content",
            headers=headers,
            json={
                **publication,
                "kind": "faq",
                "title": "FAQ privée aux listes de FAQ",
            },
        )
        public = api.get("/community/info")  # No account needed on the website.
        assert public.headers["cache-control"] == "no-store"
        announcements = public.json()["announcements"]
        assert announcements[0]["id"] == content_id
        assert announcements[0]["body"] == publication["body"]
        assert all(item["kind"] == "announcement" for item in announcements)
        home = api.get("/")
        assert 'id="annonces"' in home.text and 'id="announcements-list"' in home.text
        api.put(
            f"/community/admin/content/{content_id}",
            headers=headers,
            json={**publication, "body": "Horaire corrigé."},
        )
        assert (
            api.get("/community/info").json()["announcements"][0]["body"]
            == "Horaire corrigé."
        )
        api.delete(f"/community/admin/content/{content_id}", headers=headers)
        assert all(
            item["id"] != content_id
            for item in api.get("/community/info").json()["announcements"]
        )
