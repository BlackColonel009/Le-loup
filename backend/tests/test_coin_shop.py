from concurrent.futures import ThreadPoolExecutor
from datetime import date, timedelta

import pytest

from mordeviel_api import collection, shop
from mordeviel_api.avatar_styles import BORDERS, allowed
from mordeviel_api.stickers import STICKERS, require_sticker_access

from .test_collection import collection_api as collection_api  # noqa: PLC0414
from .test_social import account


def fund(api, user_id, amount):
    with api.app.state.community.db() as c:
        c.execute('INSERT OR REPLACE INTO coin_wallets VALUES(?,?)', (user_id, amount))


def payload(catalog, p, **extra):
    return {'product_id': p['id'], 'day': catalog['day'], 'expected_price': p['coin_price'], **extra}


def test_daily_shop_is_shared_changes_daily_and_never_sells_creator(collection_api, monkeypatch):
    api, headers, _ = collection_api
    first = api.get('/shop/me', headers=headers).json()
    public = api.get('/shop/catalog').json()
    assert first['purchases_enabled'] and not first['payments_enabled']
    assert first['balance'] == 0 and public['balance'] is None
    assert [p['id'] for p in first['products']] == [p['id'] for p in public['products']]
    assert all(not p['purchasable'] for p in public['products'])
    for kind, minimum in [('sticker',200), ('card',900), ('border',500)]:
        offers = [p for p in first['products'] if p['kind'] == kind]
        assert len(offers) == 3 and all(p['coin_price'] >= minimum for p in offers)
        if kind == 'card':
            assert all(p['theme'] == 'intense' for p in offers)
    assert api.get('/shop/me', headers=headers).json() == first
    tomorrow = str(date.fromisoformat(first['day']) + timedelta(days=1))
    monkeypatch.setattr(shop, 'today', lambda: tomorrow)
    second = api.get('/shop/me', headers=headers).json()
    assert second['day'] == tomorrow and second['next_rotation'].endswith('T00:00:00Z')
    for kind in ['sticker','card','border']:
        assert {p['id'] for p in first['products'] if p['kind']==kind} != {
            p['id'] for p in second['products'] if p['kind']==kind}
    all_products = api.get('/community/admin/collection', headers=collection_api[2]).json()['products']
    assert not any(p['id'] == 'border-creator-gold' for p in all_products)


@pytest.mark.parametrize('kind', ['sticker','card','border'])
def test_purchase_debits_once_and_grants_usable_permanent_entitlement(collection_api, kind):
    api, headers, admin = collection_api
    catalog = api.get('/shop/me', headers=headers).json()
    uid = catalog['user_id']
    p = next(p for p in catalog['products'] if p['kind'] == kind)
    fund(api, uid, 3000)
    body = payload(catalog,p)
    response = api.post('/shop/purchase', headers=headers, json=body)
    assert response.status_code == 200, response.text
    result = response.json()
    assert result['amount_charged'] == p['coin_price'] and result['balance'] == 3000-p['coin_price']
    assert p['id'] in result['granted']
    again = api.post('/shop/purchase', headers=headers, json=body).json()
    assert again['already_owned'] and again['amount_charged'] == 0 and again['balance'] == result['balance']
    api.put('/community/admin/collection/settings', headers=admin, json={'free_access':False})
    item = next(i for i in api.get('/collection/me', headers=headers).json()['products'] if i['id']==p['id'])
    assert item['owned'] and item['accessible']
    with api.app.state.community.db() as c:
        if kind == 'sticker':
            require_sticker_access(c, uid, STICKERS[p['role_id']])
        elif kind == 'border':
            assert allowed(c, uid, next(b for b in BORDERS if b['id']==p['role_id']))
    history = api.get('/community/purchases', headers=headers).json()['purchases']
    assert len(history)==1 and history[0]['currency']=='gold_moons' and history[0]['amount_minor']==p['coin_price']
    wallet = api.get('/coins/me', headers=headers).json()
    assert wallet['purchases'][0]['product_id']==p['id'] and wallet['balance']==result['balance']


def test_insufficient_balance_expired_offer_changed_price_and_no_free_bypass(collection_api):
    api, headers, admin = collection_api
    catalog = api.get('/shop/me', headers=headers).json()
    p = catalog['products'][0]
    body = payload(catalog,p)
    assert api.post('/shop/purchase', headers=headers, json=body).status_code == 409
    assert api.get('/coins/me', headers=headers).json()['balance'] == 0
    fund(api,catalog['user_id'],1000)
    old = str(date.fromisoformat(catalog['day'])-timedelta(days=1))
    assert api.post('/shop/purchase', headers=headers, json={**body,'day':old}).status_code == 409
    assert api.post('/shop/purchase', headers=headers, json={**body,'expected_price':1}).status_code == 409
    assert api.put('/community/admin/collection/products/'+p['id'], headers=admin,
                   json={'coin_price':p['coin_price']+20,'price_minor':0}).status_code == 200
    assert api.post('/shop/purchase', headers=headers, json=body).status_code == 409
    assert api.post('/collection/claim', headers=headers, json={'product_id':p['id']}).status_code == 409
    assert api.get('/coins/me', headers=headers).json()['balance'] == 1000
    assert api.get('/community/purchases', headers=headers).json()['purchases'] == []


def test_admin_minimums_and_disabled_offers_survive_reinitialization(collection_api):
    api, headers, admin = collection_api
    catalog = api.get('/shop/me', headers=headers).json()
    for p in [next(p for p in catalog['products'] if p['kind']==k) for k in ['card','sticker','border']]:
        path = '/community/admin/collection/products/'+p['id']
        assert api.put(path,headers=headers,json={'coin_price':p['coin_price']}).status_code == 403
        assert api.put(path,headers=admin,json={'coin_price':p['coin_minimum']-1}).status_code == 422
    p = catalog['products'][0]
    fund(api,catalog['user_id'],1000)
    assert api.put('/community/admin/collection/products/'+p['id'],headers=admin,json={'coin_price':None}).status_code == 200
    collection.initialize(api.app.state.community)
    assert p['id'] not in {p['id'] for p in api.get('/shop/me',headers=headers).json()['products']}
    assert api.post('/shop/purchase',headers=headers,json=payload(catalog,p)).status_code == 409
    assert api.get('/coins/me',headers=headers).json()['balance'] == 1000


def test_concurrent_purchases_cannot_overdraw_or_duplicate(collection_api):
    api, headers, _ = collection_api
    catalog = api.get('/shop/me',headers=headers).json()
    p,q = [p for p in catalog['products'] if p['kind']=='sticker'][:2]
    uid = catalog['user_id']
    fund(api,uid,300)
    with ThreadPoolExecutor(max_workers=2) as pool:
        results = list(pool.map(lambda p: api.post('/shop/purchase',headers=headers,json=payload(catalog,p)),[p,q]))
    assert sorted(r.status_code for r in results)==[200,409]
    assert api.get('/coins/me',headers=headers).json()['balance']==100
    bought = next(r.json()['granted'][0] for r in results if r.status_code==200)
    item = next(p for p in catalog['products'] if p['id']==bought)
    with ThreadPoolExecutor(max_workers=3) as pool:
        retries = list(pool.map(lambda _: api.post('/shop/purchase',headers=headers,json=payload(catalog,item)), range(3)))
    assert all(r.json()['already_owned'] for r in retries)
    assert api.get('/coins/me',headers=headers).json()['balance']==100


def test_collector_coin_purchase_includes_admin_bonus(collection_api):
    api, headers, admin = collection_api
    state = api.get('/collection/me',headers=headers).json()
    pid = 'card-intense-seer'
    selected = [pid]+['card-horror-'+r for r in ['witch','werewolf','hunter','elder']]
    assert api.put('/community/admin/collection/daily',headers=admin,json={'day':state['day'],'products':selected}).status_code == 200
    assert api.put('/community/admin/collection/products/'+pid,headers=admin,json={'coin_price':950,'bonus':['card-horror-witch']}).status_code == 200
    state = api.get('/collection/me',headers=headers).json()
    p = next(p for p in state['products'] if p['id']==pid)
    assert p['coin_purchasable'] and p['coin_price']==950
    uid = api.get('/shop/me',headers=headers).json()['user_id']
    fund(api,uid,1000)
    result = api.post('/shop/purchase',headers=headers,json=payload(state,p,source='collector')).json()
    assert result['balance']==50 and set(result['granted'])=={pid,'card-horror-witch'}


def test_creator_gift_is_exactly_100_once_per_account_even_concurrently(collection_api):
    api, headers, _ = collection_api
    endpoint = '/coins/gifts/0.3.5'
    assert api.get(endpoint).status_code==401
    assert api.post(endpoint+'/claim').status_code==401
    assert not api.get(endpoint,headers=headers).json()['claimed']
    with ThreadPoolExecutor(max_workers=3) as pool:
        receipts = list(pool.map(lambda _: api.post(endpoint+'/claim',headers=headers,json={'amount':999999}).json(),range(3)))
    assert sum(r['amount_credited'] for r in receipts)==100
    assert api.get('/coins/me',headers=headers).json()['balance']==100
    assert api.get(endpoint,headers=headers).json()['claimed']
    assert api.post(endpoint+'/claim',headers=headers).json()['amount_credited']==0
    other = account(api,'SecondCompte')[1]
    assert api.post(endpoint+'/claim',headers=other).json()['balance']==100


def test_personal_profiles_show_authoritative_balance_without_exposing_it_to_visitors(collection_api):
    api, auth, _ = collection_api
    uid = api.get('/shop/me', headers=auth).json()['user_id']
    fund(api, uid, 2345)
    assert api.get('/community/profile', headers=auth).json()['coin_balance'] == 2345
    assert api.get('/community/profile', headers=auth).json()['bronze_balance'] == 0
    assert api.get('/coins/me', headers=auth).json()['bronze_balance'] == 0
    assert api.get('/social/me', headers=auth).json()['coin_balance'] == 2345
    assert api.get('/social/me', headers=auth).json()['bronze_balance'] == 0
    assert api.get(f'/social/profiles/{uid}', headers=auth).json()['coin_balance'] == 2345
    other = account(api, 'Visiteur')[1]
    assert 'coin_balance' not in api.get(f'/social/profiles/{uid}', headers=other).json()
    assert 'bronze_balance' not in api.get(f'/social/profiles/{uid}', headers=other).json()
    assert api.get('/coins/me', headers=other).json()['bronze_balance'] == 0
