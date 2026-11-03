"""Authoritative awards, replay safety, private receipts and role outcomes."""
import secrets
import time

import pytest
from fastapi.testclient import TestClient

from mordeviel_api import challenges, social
from mordeviel_api.main import app

from .test_social import account, befriend, room


@pytest.fixture
def api(tmp_path, monkeypatch):
    monkeypatch.setenv('MORDEVIEL_COMMUNITY_DB', str(tmp_path / 'challenges.sqlite3'))
    with TestClient(app) as client:
        yield client


def finished(api, owner, participants, *, history=None, roles=None, winner='village', winners=None, bots=False, theme='classic'):
    engine = room(api, owner[0], code=secrets.token_hex(3))
    for i, user in enumerate(participants):
        social.claim_player(api.app.state.community, engine, f'p{i}', user[0])
    roles = roles or {f'p{i}': 'villager' for i in range(len(participants))}
    engine.snapshot.update(phase='ended', has_bots=bots, visual_pack=theme, game={
        'phase': 'ended', 'night': 3, 'winner': winner,
        'winner_ids': winners if winners is not None else list(roles),
        'alive_ids': list(roles), 'dealt_roles': roles, 'revealed_roles': roles,
        'history': history or [{'kind': 'deal', 'roles': roles}],
    })
    social.sync_match(api.app.state.community, engine)
    return engine


def entries(api, user):
    response = api.get('/challenges/me', headers=user[1])
    assert response.status_code == 200, response.text
    return {c['id']: c for c in response.json()['challenges']}


def test_welcome_is_permanent_and_does_not_equip_or_replace_starters(api):
    user = account(api, 'Bienvenue')
    before = api.get('/community/avatars', headers=user[1]).json()['avatar']
    data = entries(api, user)
    assert len(data) == 42 and data['welcome']['progress'] == 1
    assert len(data['welcome']['rewards']) == 3
    after = api.get('/community/avatars', headers=user[1]).json()
    assert after['avatar'] == before
    assert next(a for a in after['avatars'] if a['id'] == 'classic-sisters')['locked'] is False
    assert next(b for b in after['borders'] if b['id'] == 'welcome')['locked'] is False
    for _ in range(2):
        entries(api, user)
    with api.app.state.community.db() as c:
        assert c.execute('SELECT COUNT(*) FROM collection_owned WHERE user_id=?', (user[0],)).fetchone()[0] == 1


def test_end_records_every_player_including_dead_once_and_receipts_are_private(api):
    host, a, b = [account(api, name) for name in ['Hote', 'Alice', 'Bob']]
    engine = finished(api, host, [a, b], history=[{'kind': 'death', 'target': 'p0', 'cause': 'night', 'night': 1}], winners=['p0', 'p1'])
    social.sync_match(api.app.state.community, engine)
    for user in [a, b]:
        data = entries(api, user)
        assert data['first-night']['progress'] == data['first-win']['progress'] == 1
        assert data['regular']['progress'] == 1
        result = api.get('/challenges/matches/'+engine.social_id, headers=user[1]).json()
        assert result['eligible'] and any(c['id'] == 'first-win' and c['newly_completed'] for c in result['changes'])
    assert api.get('/challenges/matches/'+engine.social_id, headers=host[1]).status_code == 404
    assert entries(api, host)['regular']['progress'] == 0
    assert api.post('/challenges/progress', headers=a[1], json={'wins': 99}).status_code in {404, 405}


def test_practice_does_not_advance_rewarded_challenges(api):
    host, user = account(api, 'Hote'), account(api, 'Testeur')
    engine = finished(api, host, [user], bots=True)
    data = entries(api, user)
    assert data['regular']['progress'] == data['first-win']['progress'] == 0
    response = api.get('/challenges/matches/'+engine.social_id, headers=user[1]).json()
    assert response['eligible'] is False and response['changes'] == []
    assert 'entraînement' in response['reason']


def test_partial_progress_different_matches_days_themes_and_choice(api):
    host, user = account(api, 'Maitre'), account(api, 'Joueuse')
    for i in range(10):
        finished(api, host, [user], theme=['classic', 'intense', 'horror'][i % 3])
    data = entries(api, user)
    assert data['regular']['completed_at'] and data['universes']['progress'] == 3
    assert data['rendezvous']['progress'] == 1  # UTC day, not the number of games.
    choice = data['regular']['rewards'][0]['ids']
    denied = api.post('/challenges/choices/regular', headers=host[1], json={'avatar_id': choice[0]})
    assert denied.status_code == 403
    assert api.post('/challenges/choices/regular', headers=user[1], json={'avatar_id': choice[0]}).status_code == 200
    assert api.post('/challenges/choices/regular', headers=user[1], json={'avatar_id': choice[0]}).status_code == 200
    assert api.post('/challenges/choices/regular', headers=user[1], json={'avatar_id': choice[1]}).status_code == 409
    assert api.put('/community/avatar', headers=user[1], json={'avatar_id': choice[0]}).status_code == 200


def test_actual_pack_kills_not_saved_proposals_and_nights_best():
    history = []
    for night in range(1, 4):
        history.extend([
            {'kind': 'action', 'actor': 'w', 'action': 'wolves.choose', 'target': f'v{night}', 'night': night},
            {'kind': 'death', 'target': f'v{night}', 'cause': 'night', 'night': night, 'pack_ids': ['w'], 'camp': 'village'},
        ])
    history.append({'kind': 'action', 'actor': 'w', 'action': 'wolves.choose', 'target': 'saved', 'night': 4})
    game = {'dealt_roles': {'w': 'werewolf'}, 'history': history}
    f = challenges.match_facts(game)['w']
    assert f['wolf_victims'] == 3 and f['devouring_games'] == 1 and f['hunt_nights_best'] == 3


def test_two_successful_hunts_have_partial_then_complete_receipts_and_unlock_the_sticker(api):
    host, user = account(api, 'HoteLoup'), account(api, 'LeLoup')
    receipts = []
    for _ in range(2):
        engine = finished(api, host, [user], roles={'p0': 'werewolf', 'victim': 'villager'}, history=[
            {'kind': 'death', 'target': 'victim', 'cause': 'night', 'pack_ids': ['p0'], 'night': 1},
        ], winner='wolves', winners=['p0'])
        response = api.get('/challenges/matches/'+engine.social_id, headers=user[1]).json()
        receipts.append(next(ch for ch in response['changes'] if ch['id'] == 'first-fangs'))
    assert (receipts[0]['before'], receipts[0]['progress'], receipts[0]['newly_completed']) == (0, 1, False)
    assert (receipts[1]['before'], receipts[1]['progress'], receipts[1]['newly_completed']) == (1, 2, True)
    assert api.post('/community/messages', headers=user[1], json={'text': '[[sticker:rewards_wolf_bite]]'}).status_code == 201


def test_role_facts_effective_saves_final_ballots_and_actual_infection():
    roles = {'s': 'seer', 'g': 'guardian', 'witch': 'witch', 'h': 'hunter', 'f': 'wolf_father', 'w': 'werewolf', 'v': 'villager', 'a': 'elder'}
    history = [
        {'kind': 'action', 'action': 'seer.inspect', 'actor': 's', 'night': 1, 'vision': {'kind': 'role', 'value': 'werewolf'}},
        {'kind': 'effect', 'effect': 'protected', 'actor': 'g', 'target': 'v', 'night': 1},
        {'kind': 'effect', 'effect': 'saved', 'actor': 'witch', 'target': 'v', 'effective': True, 'night': 2},
        {'kind': 'effect', 'effect': 'saved', 'actor': 'witch', 'target': 'h', 'effective': False, 'night': 3},
        {'kind': 'action', 'action': 'hunter.shoot', 'actor': 'h', 'target': 'w', 'night': 3},
        {'kind': 'death', 'cause': 'hunter', 'target': 'w', 'camp': 'wolves', 'night': 3},
        {'kind': 'effect', 'effect': 'infection_pending', 'actor': 'f', 'target': 'v', 'night': 2},
        {'kind': 'effect', 'effect': 'infection', 'actor': 'f', 'target': 'v', 'night': 3},
        {'kind': 'effect', 'effect': 'elder_resists', 'target': 'a', 'night': 1},
        {'kind': 'vote_result', 'ballots': {'s': 'f', 'h': 'v'}, 'night': 3},
        {'kind': 'death', 'cause': 'vote', 'target': 'f', 'camp': 'wolves', 'night': 3},
    ]
    facts = challenges.match_facts({'dealt_roles': roles, 'history': history, 'winner': 'wolves', 'winner_ids': ['f', 'v']})
    assert facts['s']['seer_games'] == facts['s']['verdict_games'] == 1
    assert facts['g']['guardian_games'] == 1 and facts['g']['guards'] == {'v'}
    assert facts['witch']['witch_games'] == 1
    assert facts['h']['hunter_wolf'] == 1
    assert facts['f']['infections'] == facts['f']['infection_win'] == 1
    assert facts['a']['elder_resists'] == 1
    assert 'verdict_games' not in facts['h']


def test_blocked_attack_does_not_count_when_same_target_dies_and_infection_pending_is_not_success():
    facts = challenges.match_facts({'dealt_roles': {'g': 'guardian', 'f': 'wolf_father', 'v': 'villager'}, 'history': [
        {'kind': 'effect', 'effect': 'protected', 'actor': 'g', 'target': 'v', 'night': 1},
        {'kind': 'death', 'cause': 'poison', 'target': 'v', 'night': 1},
        {'kind': 'effect', 'effect': 'infection_pending', 'actor': 'f', 'target': 'v', 'night': 1},
    ]})
    assert not facts['g'].get('guardian_games') and facts['f']['infections'] == 0


def test_hunter_also_recognizes_the_white_wolf_as_a_member_of_the_pack():
    facts = challenges.match_facts({'dealt_roles': {'h': 'hunter', 'w': 'white_wolf'}, 'history': [
        {'kind': 'action', 'action': 'hunter.shoot', 'actor': 'h', 'target': 'w', 'night': 1},
        {'kind': 'death', 'cause': 'hunter', 'target': 'w', 'camp': 'white_wolf', 'night': 1},
    ]})
    assert facts['h']['hunter_wolf'] == 1


def test_event_admin_authorization_and_distinct_event_and_friend_achievement(api, monkeypatch):
    host, player, *others = [account(api, n) for n in ['AdminHote', 'Participant', 'AmiA', 'AmiB', 'AmiC']]
    for other in others:
        befriend(api, player, other)
    event = {'title': 'La veillée', 'starts': time.time()-20, 'ends': time.time()+500, 'enabled': True}
    assert api.put('/challenges/admin/events/veillee', headers=player[1], json=event).status_code == 403
    monkeypatch.setenv('MORDEVIEL_SUPPORT_TOKEN', 'challenge-test-admin')
    admin = {'Authorization': 'Bearer challenge-test-admin'}
    assert api.put('/challenges/admin/events/veillee', headers=admin, json=event).status_code == 200
    for _ in range(2):
        finished(api, host, [player, *others])
    data = entries(api, player)
    assert data['friends']['completed_at'] and data['festival']['completed_at']
    assert data['seasons']['progress'] == 1
    assert api.get('/challenges/admin/events', headers=player[1]).status_code == 403


def test_catalog_rewards_refer_only_to_real_assets_and_never_creator():
    assert len({ch['id'] for ch in challenges.CATALOG}) == 42
    for ch in challenges.CATALOG:
        for reward in ch['rewards']:
            assert 'creator' not in str(reward)
            assert challenges.reward_data(reward)['title']
