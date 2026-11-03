from fastapi.testclient import TestClient

from mordeviel_api.main import app

from .test_avatars import account


def test_new_cosmetics_stay_locked_until_a_real_account_unlock(tmp_path, monkeypatch):
    monkeypatch.setenv('MORDEVIEL_COMMUNITY_DB', str(tmp_path / 'rewards.sqlite3'))
    with TestClient(app) as api:
        uid, auth, _ = account(api, 'Alice')
        _, other, _ = account(api, 'Bob')
        data = api.get('/community/avatars', headers=auth).json()
        portraits = [a for a in data['avatars'] if a['pack_id'] == 'avatars-rewards']
        borders = [b for b in data['borders'] if b.get('pack_id') == 'borders-rewards']
        assert len(portraits) == 15 and all(a['locked'] for a in portraits)
        assert len(borders) == 25 and all(b['locked'] for b in borders)
        assert sum(not a['locked'] for a in data['avatars']) == 4
        avatar_id, border_id = portraits[0]['id'], borders[0]['id']
        assert api.put('/community/avatar', headers=auth, json={'avatar_id': avatar_id, 'locked': False}).status_code == 403
        assert api.put('/community/avatar/border', headers=auth, json={'border_id': border_id, 'locked': False}).status_code == 403
        with api.app.state.community.db() as db:
            db.execute('INSERT INTO avatar_unlocks VALUES(?,?,?)', (uid, avatar_id, 'challenge:test'))
            db.execute('INSERT INTO border_unlocks VALUES(?,?,?)', (uid, border_id, 'challenge:test'))
        chosen = api.put('/community/avatar', headers=auth, json={'avatar_id': avatar_id})
        assert chosen.status_code == 200 and chosen.json()['avatar']['pack_id'] == 'avatars-rewards'
        framed = api.put('/community/avatar/border', headers=auth, json={'border_id': border_id})
        assert framed.status_code == 200 and framed.json()['avatar']['border_id'] == border_id
        assert api.get('/social/summary', headers=auth).json()['avatar'] == framed.json()['avatar']
        # Granting a challenge to one account does not unlock anyone else's copy.
        assert api.put('/community/avatar', headers=other, json={'avatar_id': avatar_id}).status_code == 403
        assert api.put('/community/avatar/border', headers=other, json={'border_id': border_id}).status_code == 403
        for item in borders:
            x, y, w, h = item['opening']
            assert 0 < x < 1 and 0 < y < 1 and w > .1 and h > .1
            assert x+w <= 1 and y+h <= 1
