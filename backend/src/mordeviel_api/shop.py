"""Daily offers purchased atomically with earned Lunes d’or."""

import time
from datetime import UTC, date, datetime, timedelta
from typing import Annotated, Literal

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field

from . import collection
from .avatar_styles import BORDERS
from .coin_shop import daily_ids, grant, minimum_price, owned_ids
from .coins import CURRENCY, balance_in
from .community import Store, authenticated, store

router = APIRouter(prefix="/shop", tags=["shop"])
PRODUCTS = [
    {
        "id": "intense",
        "category": "Thèmes complets",
        "title": "Intense Premium",
        "description": "Village enneigé, cartes dorées, maisons, roue et animations du pack.",
    },
    {
        "id": "horror",
        "category": "Thèmes complets",
        "title": "Horreur",
        "description": "Une ambiance sombre et des habillages terrifiants. Collection en préparation.",
    },
    {
        "id": "cards",
        "category": "Apparences de cartes",
        "title": "Collections de cartes",
        "description": "Illustrations, bordures et variantes de pouvoirs détaillées dans le Codex.",
    },
    {
        "id": "voices",
        "category": "Voix OFF",
        "title": "Narrateurs et narratrices",
        "description": "Choisis les voix et les interprétations pour accompagner tes parties.",
    },
    {
        "id": "animations",
        "category": "Animations",
        "title": "Effets et cérémonies",
        "description": "Découvre des effets de protection et des cérémonies de sentence.",
    },
    {
        "id": "ghosts",
        "category": "Cosmétiques personnels",
        "title": "Fantômes et ornements",
        "description": "Personnalise ton fantôme et tes ornements visuels.",
    },
]


Database = Annotated[Store, Depends(store)]
User = Annotated[dict, Depends(authenticated)]


def today():
    return datetime.now(UTC).date().isoformat()


def catalog_in(c, uid=None):
    day = today()
    products = collection.products(c)
    selection = daily_ids(products, day)
    owned = owned_ids(c, uid)
    balance = balance_in(c, uid) if uid is not None else None
    offers = []
    for pid in selection:
        p = next(p for p in products if p['id'] == pid)
        border = next((b for b in BORDERS if b['id'] == p['role_id']), None) if p['kind'] == 'border' else None
        offers.append({**p, 'owned': pid in owned,
            'coin_minimum': minimum_price(p), 'border': border,
            'purchasable': bool(uid and pid not in owned),
            'affordable': balance is not None and balance >= p['coin_price'],
            'purchase_label': 'Dans ta collection' if pid in owned else 'Acheter en Lunes d’or'})
    return {'purchases_enabled': True, 'payments_enabled': False, 'currency': CURRENCY,
        'user_id': uid, 'balance': balance, 'day': day, 'rotation_timezone': 'UTC',
        'next_rotation': f"{(date.fromisoformat(day)+timedelta(days=1)).isoformat()}T00:00:00Z",
        'notice': 'Les trouvailles changent chaque jour. Les achats restent dans ta collection.',
        'products': offers}


@router.get('/catalog')
def catalog(*, db: Database):
    with db.db() as c:
        return catalog_in(c)


@router.get('/me')
def mine(*, user: User, db: Database):
    with db.db() as c:
        return catalog_in(c, user['id'])


class Purchase(BaseModel):
    product_id: str = Field(min_length=1, max_length=80)
    day: date
    expected_price: int = Field(ge=0, le=100000000)
    source: Literal['shop', 'collector'] = 'shop'


@router.post('/purchase')
def purchase(data: Purchase, *, user: User, db: Database):
    with db.db() as c:
        c.execute('BEGIN IMMEDIATE')
        uid = user['id']
        p = next((p for p in collection.products(c) if p['id'] == data.product_id), None)
        if p is None or minimum_price(p) is None:
            raise HTTPException(404, 'Cet article n’est pas proposé en Lunes d’or.')
        if p['id'] in owned_ids(c, uid):
            return {'ok': True, 'already_owned': True, 'amount_charged': 0,
                    'balance': balance_in(c, uid), 'user_id': uid, 'granted': []}
        day = today()
        offers = daily_ids(collection.products(c), day) if data.source == 'shop' else collection.day_offers(c, day)
        if str(data.day) != day or p['id'] not in offers:
            raise HTTPException(409, 'Les offres ont changé. Actualise la boutique pour découvrir les trouvailles du jour.')
        price = p['coin_price']
        if not p['visible'] or not p[data.source] or price is None:
            raise HTTPException(409, 'Cette offre n’est plus disponible. Actualise la boutique.')
        if price < minimum_price(p) or price != data.expected_price:
            raise HTTPException(409, 'Le prix a changé. Actualise la boutique avant de confirmer cet achat.')
        c.execute('INSERT OR IGNORE INTO coin_wallets VALUES(?,0)', (uid,))
        debited = c.execute('UPDATE coin_wallets SET balance=balance-? WHERE user_id=? AND balance>=?',
                            (price, uid, price)).rowcount
        if not debited:
            raise HTTPException(409, f"Lunes d’or insuffisantes : il te manque {price-balance_in(c, uid)} lunes. Joue des parties pour en gagner !")
        granted = grant(c, uid, [p['id'], *p['bonus']], 'gold_moons')
        c.execute('INSERT INTO coin_purchases VALUES(?,?,?,?,?)', (uid, p['id'], price, day, time.time()))
        c.execute('''INSERT INTO purchase_history(user_id,product_id,title,amount_minor,currency,status,purchased_at,receipt_reference)
            VALUES(?,?,?,?,?,?,?,?)''', (uid,p['id'],p['title'],price,'gold_moons','paid',time.time(),f"gold_moons:{uid}:{p['id']}"))
        return {'ok': True, 'already_owned': False, 'amount_charged': price,
                'balance': balance_in(c, uid), 'user_id': uid, 'granted': granted}
