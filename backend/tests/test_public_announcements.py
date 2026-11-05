from fastapi.testclient import TestClient

from mordeviel_api.main import app

from .helpers import post_verified


def test_announcement_image_upload_visibility_and_final_profiles(tmp_path, monkeypatch):
    import base64
    import io
    from PIL import Image
    from types import SimpleNamespace
    from mordeviel_api.online import final_player_profiles
    monkeypatch.setenv('MORDEVIEL_COMMUNITY_DB', str(tmp_path / 'images.sqlite3'))
    with TestClient(app) as api:
        user = post_verified(api, '/community/register', json={'nickname':'ImageAdmin','password':'test-password-123'}).json()
        headers = {'Authorization':'Bearer ' + user['token']}
        with api.app.state.community.db() as c:
            c.execute("UPDATE users SET role='admin' WHERE id=?", (user['user']['id'],))
        output = io.BytesIO()
        Image.new('RGB', (20,30), 'gold').save(output, format='PNG')
        payload = {'image_base64':base64.b64encode(output.getvalue()).decode()}
        assert api.post('/community/admin/content-images',json=payload).status_code == 403
        uploaded = api.post('/community/admin/content-images',headers=headers,json=payload)
        assert uploaded.status_code == 200
        url = uploaded.json()['url']
        assert api.get(url).status_code == 404
        published = api.post('/community/admin/content',headers=headers,json={'kind':'announcement','title':'Sulfuron','body':'Une nouvelle carte','images':[url]})
        assert published.status_code == 201
        assert api.get(url).headers['content-type'] == 'image/webp'
        assert api.get('/community/info').json()['announcements'][0]['images'] == [url]
        api.delete('/community/admin/content/'+str(published.json()['id']),headers=headers)
        assert api.get(url).status_code == 404
        engine = SimpleNamespace(db=api.app.state.community, accounts={'p':user['user']['id']})
        snapshot = {'players':[{'id':'p','nickname':'Le Fourbe'}], 'game':{'phase':'day'}}
        final_player_profiles(engine,snapshot)
        assert 'final_players' not in snapshot['game']
        snapshot['game']['phase']='ended'
        final_player_profiles(engine,snapshot)
        final = snapshot['game']['final_players'][0]
        assert final['account_nickname']=='ImageAdmin' and final['nickname']=='Le Fourbe'
        assert final['avatar']['id']


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
            "images": ["/site-assets/seer.jpg", "/site-assets/witch.jpg"],
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
        assert announcements[0]['images'] == publication['images']
        assert api.post('/community/admin/content',headers=headers,json={**publication,'images':['https://evil.example/card.svg']}).status_code == 422
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
