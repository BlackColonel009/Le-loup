import pytest

from mordeviel_api import coins, social

from .test_challenges import api as api  # noqa: PLC0414 -- shared pytest fixture
from .test_challenges import finished
from .test_social import account, room


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
    assert api.get('/coins/me',headers=host[1]).json()['balance'] == 73
    host_reward = api.get(endpoint,headers=host[1]).json()
    assert host_reward['participant_role'] == 'mdj' and host_reward['nights'] == 3
    assert host_reward['won'] is False and host_reward['eligible'] is True
    assert api.post(endpoint+'/claim',headers=host[1]).json()['balance'] == 73
    assert api.post(endpoint+'/claim',headers=host[1]).json()['balance'] == 73
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
    host_reward = api.get('/coins/matches/'+engine.social_id,headers=host[1]).json()
    assert host_reward['amount'] == 60 and host_reward['participant_role'] == 'mdj'


@pytest.mark.parametrize('winner', ['village', 'wolves', 'draw', 'white_wolf', 'angel'])
def test_mdj_payment_does_not_depend_on_winner(api, winner):
    host, player = account(api, 'Maitre'), account(api, 'Humain')
    engine = finished(api, host, [player], winner=winner, winners=[], theme='classic')
    result = api.get('/coins/matches/'+engine.social_id, headers=host[1]).json()
    assert result['amount'] == 28 and result['participant_role'] == 'mdj'


def test_mdj_progressive_payment_and_zero_nights():
    for theme in coins.RANGES:
        values = [coins.mdj_amount_for(theme, n) for n in range(9)]
        assert values[0] == 0 and values == sorted(values)
        assert values[1] == coins.RANGES[theme][0]
        assert values[6] == values[8] == coins.RANGES[theme][1]


def test_bot_only_room_pays_verified_host(api):
    host = account(api, 'MaitreBots')
    engine = finished(api, host, [], roles={'bot1':'werewolf','bot2':'villager'},
                      bots=True, winner='wolves', winners=['bot1'], theme='classic')
    reward = api.get('/coins/matches/'+engine.social_id, headers=host[1]).json()
    assert reward['amount'] == 28 and reward['participant_role'] == 'mdj'
    social.sync_match(api.app.state.community, engine)
    assert api.get('/coins/me', headers=host[1]).json()['balance'] == 28


def test_stale_owner_association_cannot_receive_host_reward(api):
    host = account(api, 'AncienMaitre')
    engine = room(api, host[0], code='STALE1')
    engine.owner_stamp = 'association-obsolete'
    engine.snapshot.update(phase='ended', has_bots=True, game={
        'phase':'ended', 'night':3, 'winner':'wolves', 'winner_ids':['bot'],
        'revealed_roles':{'bot':'werewolf'},
        'history':[{'kind':'deal','roles':{'bot':'werewolf'}}],
    })
    social.sync_match(api.app.state.community, engine)
    assert api.get('/coins/matches/'+engine.social_id, headers=host[1]).status_code == 404
    assert api.get('/coins/me', headers=host[1]).json()['balance'] == 0


def test_old_receipts_migrate_without_changing_balances(tmp_path):
    import sqlite3
    connection = sqlite3.connect(tmp_path / 'legacy-coins.sqlite3')
    connection.row_factory = sqlite3.Row
    class LegacyStore:
        def db(self):
            return connection
    try:
        connection.executescript('''CREATE TABLE users(id INTEGER PRIMARY KEY);
            CREATE TABLE coin_wallets(user_id INTEGER PRIMARY KEY,balance INTEGER NOT NULL);
            INSERT INTO coin_wallets VALUES(1,28);
            CREATE TABLE coin_match_rewards(match_id TEXT,user_id INTEGER,amount INTEGER,
                won INTEGER,theme TEXT,nights INTEGER,eligible INTEGER,reason TEXT,
                created REAL,claimed_at REAL,PRIMARY KEY(match_id,user_id));
            INSERT INTO coin_match_rewards VALUES('old',1,28,1,'classic',3,1,'',0,NULL);''')
        for _ in range(2):
            coins.initialize(LegacyStore())
        row = connection.execute('SELECT * FROM coin_match_rewards').fetchone()
        assert row['participant_role'] == 'player' and row['amount'] == 28
        assert coins.balance_in(connection, 1) == 28
    finally:
        connection.close()


def test_chest_classification_is_consistent_with_challenge_difficulty(api):
    from mordeviel_api.challenges import CATALOG
    pairs = {'easy':'classic','medium':'epic','hard':'premium'}
    assert len(CATALOG)==42
    assert {c['difficulty'] for c in CATALOG} == set(pairs)
    assert all(c['chest_tier']==pairs[c['difficulty']] for c in CATALOG)
    assert next(c for c in CATALOG if c['id']=='first-win')['chest_tier']=='classic'
    assert next(c for c in CATALOG if c['id']=='veteran')['chest_tier']=='premium'
