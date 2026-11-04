"""Account-bound virtual coins awarded once from authoritative game results."""
import time
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException

from .community import Store, authenticated, store

router = APIRouter(prefix='/coins', tags=['coins'])
DB = Annotated[Store, Depends(store)]
User = Annotated[dict, Depends(authenticated)]
CURRENCY = {'id': 'gold_moons', 'name': 'Lunes d’or'}
RANGES = {'classic': (20, 40), 'intense': (50, 75), 'horror': (55, 100)}


def initialize(db):
    with db.db() as c:
        c.executescript('''
        CREATE TABLE IF NOT EXISTS coin_wallets (
            user_id INTEGER PRIMARY KEY, balance INTEGER NOT NULL DEFAULT 0 CHECK(balance>=0));
        CREATE TABLE IF NOT EXISTS coin_match_rewards (
            match_id TEXT NOT NULL, user_id INTEGER NOT NULL, amount INTEGER NOT NULL,
            won INTEGER NOT NULL, theme TEXT NOT NULL, nights INTEGER NOT NULL,
            eligible INTEGER NOT NULL, reason TEXT NOT NULL, created REAL NOT NULL, claimed_at REAL,
            PRIMARY KEY(match_id,user_id));
        CREATE INDEX IF NOT EXISTS coin_reward_user ON coin_match_rewards(user_id,created);
        CREATE TABLE IF NOT EXISTS coin_purchases (
            user_id INTEGER NOT NULL, product_id TEXT NOT NULL, amount INTEGER NOT NULL,
            day TEXT NOT NULL, created REAL NOT NULL, PRIMARY KEY(user_id,product_id));
        CREATE TABLE IF NOT EXISTS coin_gifts (
            user_id INTEGER NOT NULL, gift_id TEXT NOT NULL, amount INTEGER NOT NULL,
            created REAL NOT NULL, PRIMARY KEY(user_id,gift_id));
        ''')


def balance_in(c, uid):
    row = c.execute('SELECT balance FROM coin_wallets WHERE user_id=?', (uid,)).fetchone()
    return row['balance'] if row else 0


def amount_for(theme, nights, won):
    nights = max(0, int(nights))
    if not won:
        return min(5, max(1, nights))
    low, high = RANGES.get(theme, RANGES['classic'])
    return low + (high - low) * min(5, max(0, nights - 1)) // 5


def record_match(c, engine, accounts, practice):
    game = engine.snapshot.get('game') or {}
    if game.get('phase') != 'ended' or not game.get('history'):
        return
    theme = engine.snapshot.get('visual_pack', 'classic')
    if theme not in RANGES:
        theme = 'classic'
    nights = max(0, int(game.get('night', 0)))
    winners = set(game.get('winner_ids', []))
    roles = game.get('revealed_roles') or game.get('dealt_roles') or {}
    for player, uid in accounts.items():
        if not c.execute('SELECT 1 FROM users WHERE id=? AND email_verified=1 AND banned=0', (uid,)).fetchone():
            continue
        eligible = player in roles
        reason = 'Résultat de partie indisponible pour ce joueur.' if not eligible else ''
        won = player in winners
        amount = amount_for(theme, nights, won) if eligible else 0
        created = c.execute('''INSERT OR IGNORE INTO coin_match_rewards
            (match_id,user_id,amount,won,theme,nights,eligible,reason,created)
            VALUES(?,?,?,?,?,?,?,?,?)''',
            (engine.social_id, uid, amount, int(won), theme, nights, int(eligible), reason, time.time())).rowcount
        if created and amount:
            c.execute('''INSERT INTO coin_wallets VALUES(?,?)
                ON CONFLICT(user_id) DO UPDATE SET balance=balance+excluded.balance''', (uid, amount))


def receipt(c, row):
    return {**dict(row), 'won': bool(row['won']), 'eligible': bool(row['eligible']),
            'balance': balance_in(c, row['user_id']), 'currency': CURRENCY}


@router.get('/me')
def wallet(*, user: User, db: DB):
    with db.db() as c:
        rows = c.execute('SELECT * FROM coin_match_rewards WHERE user_id=? AND amount>0 ORDER BY created DESC LIMIT 50', (user['id'],)).fetchall()
        return {'user_id': user['id'], 'balance': balance_in(c, user['id']), 'currency': CURRENCY,
                'rewards': [receipt(c, row) for row in rows],
                'gifts': [dict(r) for r in c.execute('SELECT * FROM coin_gifts WHERE user_id=? ORDER BY created DESC', (user['id'],))],
                'creator_gift': creator_gift(c, user['id']),
                'purchases': [dict(r) for r in c.execute('SELECT cp.*,p.title FROM coin_purchases cp JOIN collection_products p ON p.id=cp.product_id WHERE cp.user_id=? ORDER BY cp.created DESC LIMIT 50', (user['id'],))]}


def creator_gift(c, uid):
    row = c.execute("SELECT * FROM coin_gifts WHERE user_id=? AND gift_id='creator-0.3.5'", (uid,)).fetchone()
    return {'id': 'creator-0.3.5', 'version': '0.3.5', 'amount': 100,
            'title': 'Un cadeau du Créateur',
            'message': 'Merci de faire vivre Mordeviel ! Pour la mise à jour 0.3.5, le Créateur t’offre 100 Lunes d’or. — Logan R.D',
            'claimed': row is not None, 'user_id': uid, 'balance': balance_in(c, uid)}


@router.get('/gifts/0.3.5')
def gift_status(*, user: User, db: DB):
    with db.db() as c:
        return creator_gift(c, user['id'])


@router.post('/gifts/0.3.5/claim')
def claim_creator_gift(*, user: User, db: DB):
    with db.db() as c:
        c.execute('BEGIN IMMEDIATE')
        inserted = c.execute("INSERT OR IGNORE INTO coin_gifts VALUES(?,'creator-0.3.5',100,?)", (user['id'], time.time())).rowcount
        if inserted:
            c.execute('INSERT INTO coin_wallets VALUES(?,100) ON CONFLICT(user_id) DO UPDATE SET balance=balance+100', (user['id'],))
        return {**creator_gift(c, user['id']), 'amount_credited': 100 if inserted else 0}


@router.get('/matches/{match_id}')
def match_reward(match_id: str, *, user: User, db: DB):
    with db.db() as c:
        row = c.execute('SELECT * FROM coin_match_rewards WHERE match_id=? AND user_id=?', (match_id, user['id'])).fetchone()
        if not row:
            raise HTTPException(404, 'Le coffre de cette partie n’est pas encore disponible.')
        return receipt(c, row)


@router.post('/matches/{match_id}/claim')
def claim_reward(match_id: str, *, user: User, db: DB):
    # Coins are already credited atomically when the match ends. Opening or
    # skipping the video only acknowledges its presentation, never adds money.
    with db.db() as c:
        c.execute('BEGIN IMMEDIATE')
        row = c.execute('SELECT * FROM coin_match_rewards WHERE match_id=? AND user_id=?', (match_id, user['id'])).fetchone()
        if not row:
            raise HTTPException(404, 'Ce coffre est introuvable pour ton compte.')
        if not row['eligible']:
            raise HTTPException(409, row['reason'])
        c.execute('UPDATE coin_match_rewards SET claimed_at=COALESCE(claimed_at,?) WHERE match_id=? AND user_id=?', (time.time(), match_id, user['id']))
        return receipt(c, c.execute('SELECT * FROM coin_match_rewards WHERE match_id=? AND user_id=?', (match_id, user['id'])).fetchone())
