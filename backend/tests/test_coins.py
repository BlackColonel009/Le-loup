import pytest

from mordeviel_api import coins, social

from .test_challenges import api as api  # noqa: PLC0414 -- shared pytest fixture
from .test_challenges import finished
from .test_social import account


@pytest.mark.parametrize('theme,low,high', [('classic',20,40),('intense',50,75),('horror',55,100)])
def test_progressive_winner_ranges_are_bounded(theme, low, high):
    values = [coins.amount_for(theme, n, True) for n in range(12)]
    assert values[0] == values[1] == low
    assert values[6] == values[-1] == high
    assert values == sorted(values)
    assert all(low <= value <= high for value in values)


def test_defeats_are_one_to_five_coins():
    assert [coins.amount_for('horror',n,False) for n in range(8)] == [1,1,2,3,4,5,5,5]


def test_match_awards_once_and_opening_or_skipping_never_credits_twice(api):
    host, winner, loser = [account(api,name) for name in ['Maitre','Alice','Bob']]
    engine = finished(api,host,[winner,loser],winners=['p0'],theme='horror',
        history=[{'kind':'death','target':'p0','cause':'night','night':1}])
    social.sync_match(api.app.state.community,engine)
    endpoint = '/coins/matches/'+engine.social_id
    reward = api.get(endpoint,headers=winner[1]).json()
    assert reward['amount'] == 73 and reward['won'] and reward['eligible']
    assert reward['currency']['name'] == 'Lunes d’or'
    assert reward['claimed_at'] is None
    assert api.get('/coins/me',headers=winner[1]).json()['balance'] == 73
    assert api.get(endpoint,headers=loser[1]).json()['amount'] == 3
    assert api.get('/coins/me',headers=host[1]).json()['balance'] == 0
    assert api.get(endpoint,headers=host[1]).status_code == 404
    assert api.get('/coins/me').status_code == 401
    assert api.post(endpoint+'/claim').status_code == 401
    first = api.post(endpoint+'/claim',headers=winner[1],json={'amount':999999}).json()
    second = api.post(endpoint+'/claim',headers=winner[1]).json()
    assert first['claimed_at'] == second['claimed_at'] and second['balance'] == 73
    assert api.get('/social/summary',headers=winner[1]).json()['coin_balance'] == 73


def test_online_bot_matches_award_accounts_without_unlocking_human_challenges(api):
    host, player = account(api,'Maitre'),account(api,'Humain')
    engine = finished(api,host,[player],roles={'p0':'werewolf','bot':'villager'},
        winners=['p0'],winner='wolves',bots=True,theme='intense')
    reward = api.get('/coins/matches/'+engine.social_id,headers=player[1]).json()
    assert reward['amount'] == 60 and reward['eligible']
    assert api.get('/coins/me',headers=player[1]).json()['balance'] == 60
    items = api.get('/challenges/me',headers=player[1]).json()['challenges']
    assert next(c for c in items if c['id']=='first-win')['progress'] == 0


def test_chest_classification_is_consistent_with_challenge_difficulty(api):
    from mordeviel_api.challenges import CATALOG
    pairs = {'easy':'classic','medium':'epic','hard':'premium'}
    assert len(CATALOG)==42
    assert {c['difficulty'] for c in CATALOG} == set(pairs)
    assert all(c['chest_tier']==pairs[c['difficulty']] for c in CATALOG)
    assert next(c for c in CATALOG if c['id']=='first-win')['chest_tier']=='classic'
    assert next(c for c in CATALOG if c['id']=='veteran')['chest_tier']=='premium'
