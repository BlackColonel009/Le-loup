"""Private, permanent achievements computed from authoritative completed games."""

import json
import re
import secrets
import time
from datetime import UTC, datetime
from pathlib import Path
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field, model_validator

from .community import Store, administrator, authenticated, store
from .coins import balance_in

router = APIRouter(prefix='/challenges', tags=['challenges'])
DB = Annotated[Store, Depends(store)]
User = Annotated[dict, Depends(authenticated)]
Admin = Annotated[dict, Depends(administrator)]
CATALOG = json.loads((Path(__file__).resolve().parents[3] / 'shared/challenges/catalog.json').read_text(encoding='utf-8'))['challenges']
WOLVES = {'werewolf', 'alpha_wolf', 'white_wolf', 'wolf_father'}


def initialize(db):
    with db.db() as c:
        c.executescript('''
        CREATE TABLE IF NOT EXISTS challenge_users(user_id INTEGER PRIMARY KEY);
        CREATE TABLE IF NOT EXISTS challenge_metrics(user_id INTEGER NOT NULL,metric TEXT NOT NULL,value INTEGER NOT NULL,PRIMARY KEY(user_id,metric));
        CREATE TABLE IF NOT EXISTS challenge_distinct(user_id INTEGER NOT NULL,metric TEXT NOT NULL,value TEXT NOT NULL,PRIMARY KEY(user_id,metric,value));
        CREATE TABLE IF NOT EXISTS challenge_progress(user_id INTEGER NOT NULL,challenge_id TEXT NOT NULL,value INTEGER NOT NULL,completed REAL,choice TEXT,PRIMARY KEY(user_id,challenge_id));
        CREATE TABLE IF NOT EXISTS challenge_matches(match_id TEXT NOT NULL,user_id INTEGER NOT NULL,room_code TEXT NOT NULL,finished REAL NOT NULL,eligible INTEGER NOT NULL,reason TEXT NOT NULL,changes TEXT NOT NULL,PRIMARY KEY(match_id,user_id));
        CREATE TABLE IF NOT EXISTS challenge_events(id TEXT PRIMARY KEY,title TEXT NOT NULL,starts REAL NOT NULL,ends REAL NOT NULL,enabled INTEGER NOT NULL DEFAULT 1);
        CREATE TABLE IF NOT EXISTS challenge_room_events(match_id TEXT NOT NULL,event_id TEXT NOT NULL,PRIMARY KEY(match_id,event_id));
        CREATE INDEX IF NOT EXISTS challenge_match_user ON challenge_matches(user_id,finished);
        ''')
        columns = {row['name'] for row in c.execute('PRAGMA table_info(challenge_progress)')}
        if 'claimed_at' not in columns:
            c.execute('ALTER TABLE challenge_progress ADD COLUMN claimed_at REAL')
        c.execute('CREATE TABLE IF NOT EXISTS challenge_coin_rewards(user_id INTEGER NOT NULL, challenge_id TEXT NOT NULL, amount INTEGER NOT NULL CHECK(amount>0), created REAL NOT NULL, PRIMARY KEY(user_id,challenge_id))')


def reward_data(reward):
    if reward['kind'] == 'gold_moons':
        low, high = reward['min'], reward['max']
        return {**reward, 'title': (str(low) if low == high else f'{low} à {high}') + ' Lunes d’or'}
    from .avatar_styles import BORDERS
    from .avatars import CATALOG as avatars
    from .stickers import STICKERS
    if reward['kind'] == 'avatar_choice':
        return {**reward, 'title': 'Un portrait au choix', 'choices': [reward_data({'kind': 'avatar', 'id': ident}) for ident in reward['ids']]}
    source = (next(a for a in avatars if a['id'] == reward['id']) if reward['kind'] == 'avatar'
              else next(b for b in BORDERS if b['id'] == reward['id']) if reward['kind'] == 'border'
              else STICKERS[reward['id']])
    result = {**reward, 'title': source.get('title', source.get('emotion', 'Sticker'))}
    if reward['kind'] == 'sticker':
        result.update(asset=f"assets/stickers/rewards/{reward['id']}.png", pack_id='stickers-rewards')
    else:
        result.update({k: source[k] for k in ('asset', 'pack_id', 'crop', 'opening', 'effect', 'colors') if k in source})
    return result


def earned_reward(c, uid, ident, reward):
    result = reward_data(reward)
    if reward['kind'] == 'gold_moons':
        row = c.execute('SELECT amount FROM challenge_coin_rewards WHERE user_id=? AND challenge_id=?', (uid, ident)).fetchone()
        if row:
            result.update(amount=row['amount'], title=f"+{row['amount']} Lunes d’or")
    return result


def grant(c, uid, challenge):
    for reward in challenge['rewards']:
        kind, ident = reward['kind'], reward.get('id')
        source = f"challenge:{challenge['id']}"
        if kind == 'gold_moons':
            amount = reward['min'] + secrets.randbelow(reward['max'] - reward['min'] + 1)
            created = c.execute('INSERT OR IGNORE INTO challenge_coin_rewards VALUES(?,?,?,?)', (uid, challenge['id'], amount, time.time())).rowcount
            if created:
                c.execute('INSERT INTO coin_wallets VALUES(?,?) ON CONFLICT(user_id) DO UPDATE SET balance=balance+excluded.balance', (uid, amount))
        elif kind == 'avatar':
            c.execute('INSERT OR IGNORE INTO avatar_unlocks VALUES(?,?,?)', (uid, ident, source))
        elif kind == 'border':
            c.execute('INSERT OR IGNORE INTO border_unlocks VALUES(?,?,?)', (uid, ident, source))
        elif kind == 'sticker':
            c.execute('INSERT OR IGNORE INTO collection_owned VALUES(?,?,?,?)', (uid, f'sticker-{ident}', source, time.time()))


def add(c, uid, metric, value=1, *, maximum=False):
    if value <= 0:
        return
    update = 'MAX(value,excluded.value)' if maximum else 'value+excluded.value'
    c.execute(f'INSERT INTO challenge_metrics VALUES(?,?,?) ON CONFLICT(user_id,metric) DO UPDATE SET value={update}', (uid, metric, value))


def distinct(c, uid, metric, value):
    c.execute('INSERT OR IGNORE INTO challenge_distinct VALUES(?,?,?)', (uid, metric, str(value)))
    count = c.execute('SELECT COUNT(*) FROM challenge_distinct WHERE user_id=? AND metric=?', (uid, metric)).fetchone()[0]
    add(c, uid, metric, count, maximum=True)


def reconcile(c, uid):
    metrics = dict(c.execute('SELECT metric,value FROM challenge_metrics WHERE user_id=?', (uid,)).fetchall())
    for challenge in CATALOG:
        value = min(challenge['target'], metrics.get(challenge['metric'], 0))
        row = c.execute('SELECT completed FROM challenge_progress WHERE user_id=? AND challenge_id=?', (uid, challenge['id'])).fetchone()
        if row and row['completed']:
            continue
        completed = time.time() if value >= challenge['target'] else None
        c.execute('INSERT INTO challenge_progress(user_id,challenge_id,value,completed) VALUES(?,?,?,?) ON CONFLICT(user_id,challenge_id) DO UPDATE SET value=excluded.value,completed=excluded.completed', (uid, challenge['id'], value, completed))


def ensure_user(c, uid):
    if not c.execute('SELECT 1 FROM users WHERE id=? AND email_verified=1 AND banned=0', (uid,)).fetchone():
        return
    if c.execute('SELECT 1 FROM challenge_users WHERE user_id=?', (uid,)).fetchone():
        return
    if not c.execute('INSERT OR IGNORE INTO challenge_users VALUES(?)', (uid,)).rowcount:
        return
    # Existing authoritative aggregate statistics can be retained exactly once.
    # Unrecorded historical role actions cannot be reconstructed.
    row = c.execute('SELECT COUNT(*) games,COALESCE(SUM(wins),0) wins,COALESCE(SUM(wolf_victims),0) victims,COALESCE(SUM(wolf_victims>0),0) hunts FROM social_match_stats WHERE user_id=?', (uid,)).fetchone()
    for metric, value in [('verified', 1), ('games', row['games']), ('wins', row['wins']), ('wolf_victims', row['victims'])]:
        add(c, uid, metric, value)
    reconcile(c, uid)


def list_in(c, uid):
    ensure_user(c, uid)
    progress = {r['challenge_id']: dict(r) for r in c.execute('SELECT * FROM challenge_progress WHERE user_id=?', (uid,))}
    return [{**challenge, 'rewards': [earned_reward(c, uid, challenge['id'], r) for r in challenge['rewards']],
             'progress': progress.get(challenge['id'], {}).get('value', 0),
             'completed_at': progress.get(challenge['id'], {}).get('completed'),
             'claimed_at': progress.get(challenge['id'], {}).get('claimed_at'),
             'choice': progress.get(challenge['id'], {}).get('choice')} for challenge in CATALOG]


def pending_count(c, uid):
    ensure_user(c, uid)
    return c.execute('SELECT COUNT(*) FROM challenge_progress WHERE user_id=? AND completed IS NOT NULL AND claimed_at IS NULL', (uid,)).fetchone()[0]


def pending_in(c, uid):
    return [ch for ch in list_in(c, uid) if ch['completed_at'] and not ch['claimed_at']]


def capture_events(c, engine):
    if getattr(engine, 'challenges_started', False):
        return
    engine.challenges_started = True
    for event in c.execute('SELECT id FROM challenge_events WHERE enabled=1 AND starts<=? AND ends>?', (time.time(), time.time())):
        c.execute('INSERT OR IGNORE INTO challenge_room_events VALUES(?,?)', (engine.social_id, event['id']))


def match_facts(game):
    """Replay only accepted server events; no client counters or chat parsing."""
    history = game.get('history', [])
    roles = dict(game.get('dealt_roles') or game.get('revealed_roles') or {})
    final_roles = game.get('revealed_roles', roles)
    winners = set(game.get('winner_ids', []))
    alive = set(game.get('alive_ids', []))
    facts = {p: {'role': role, 'wolf_victims': 0, 'hunt_nights': set(), 'seer_nights': set(), 'guards': set(), 'infections': set()} for p, role in roles.items()}
    infected, selections = set(), {}
    lovers = {}
    saved, protected = [], []
    def wolf(p):
        return p in infected or roles.get(p) in WOLVES
    for e in history:
        p, target, night = e.get('actor'), e.get('target'), e.get('night')
        f = facts.get(p)
        if e.get('kind') == 'action':
            action = e.get('action')
            selections[(p, action, night)] = e
            if action in {'seer.inspect', 'seer.double', 'seer.compare'} and f:
                f['seer_nights'].add(night)
                visions = [e.get('vision', {})] if action == 'seer.inspect' else (e.get('result') or {}).get('visions', [])
                if any(v.get('value') == 'wolves' if v.get('kind') == 'camp' else v.get('value') in WOLVES for v in visions):
                    f['seer_games'] = 1
            if action == 'cupid.link':
                pair = e.get('targets', [])
                if len(pair) == 2:
                    lovers = {pair[0]: pair[1], pair[1]: pair[0]}
            if action == 'metamorph.swap':
                roles.update(e.get('new_roles', {}))
        if e.get('kind') == 'effect':
            effect = e.get('effect')
            if effect == 'infection':
                infected.add(target)
                if f:
                    f['infections'].add(target)
                    f['infections_count'] = f.get('infections_count', 0)+1
            if effect == 'saved' and f and e.get('effective'):
                saved.append((p, target))
            if effect in {'protected', 'poison_blocked', 'guardian_sacrifice'} and f:
                protected.append((p, target, night))
            if effect in {'elder_resists', 'inherited_resistance', 'presage_saved'} and target in facts:
                facts[target]['elder_resists'] = 1
        if e.get('kind') != 'death':
            continue
        cause = e.get('source_cause', e.get('cause'))
        killed_wolf = e.get('camp') in {'wolves', 'white_wolf'} if e.get('camp') is not None else wolf(target)
        if cause == 'night':
            for member in e.get('pack_ids', []):
                if member in facts:
                    facts[member]['wolf_victims'] += 1
                    facts[member]['hunt_nights'].add(night)
            for (actor, action, turn), selection in selections.items():
                if turn == night and action == 'alpha.choose' and target in selection.get('targets', [selection.get('target')]) and actor in facts:
                    facts[actor]['alpha_kills'] = facts[actor].get('alpha_kills', 0)+1
        if cause in {'hunter', 'white_wolf'} and killed_wolf:
            action = 'hunter.shoot' if cause == 'hunter' else 'white_wolf.choose'
            candidates = [s for (actor, act, turn), s in selections.items() if act == action and turn == night and target in s.get('targets', [s.get('target')])]
            if candidates:
                actor = candidates[-1]['actor']
                if actor in facts:
                    facts[actor]['hunter_wolf' if cause == 'hunter' else 'white_kills'] = 1
                    if cause == 'white_wolf':
                        facts[actor]['wolf_victims'] += 1
        if e.get('cause') == 'vote' and killed_wolf:
            ballots = next((v.get('ballots', {}) for v in reversed(history[:history.index(e)]) if v.get('kind') == 'vote_result' and v.get('night') == night), {})
            for actor, choice in ballots.items():
                if choice == target and actor in facts:
                    facts[actor]['verdict_games'] = 1
    for actor, target, night in protected:
        # A blocked attack does not count when another simultaneous attack kills
        # the same player that night.
        died = any(e.get('kind') == 'death' and e.get('target') == target and e.get('night') == night for e in history)
        if not died:
            facts[actor]['guardian_games'] = 1
            facts[actor]['guards'].add(target)
    for actor, target in saved:
        facts[actor]['witch_games'] = 1
        if target != actor and actor in winners:
            facts[actor]['remedy_win'] = 1
    for p, f in facts.items():
        role = final_roles.get(p, f['role'])
        won = p in winners
        f.update(wins=int(won), games=1, devouring_games=int(bool(f['hunt_nights'])),
                 seer_nights_best=len(f['seer_nights']), hunt_nights_best=len(f['hunt_nights']),
                 villager_games=int(f['role'] in {'villager', 'villager_female'}),
                 lover_wins=int(won and p in lovers),
                 mixed_love_win=int(won and game.get('winner') == 'lovers' and p in lovers),
                 white_wins=int(won and game.get('winner') == 'white_wolf'),
                 white_alone=int(won and game.get('winner') == 'white_wolf' and alive == {p}),
                 piper_wins=int(won and game.get('winner') == 'piper'),
                 angel_wins=int(won and game.get('winner') == 'angel'),
                 wolf_wins=int(won and game.get('winner') == 'wolves'),
                 villager_survivor=int(won and game.get('winner') == 'village' and p in alive and role in {'villager', 'villager_female'}),
                 infection_win=int(won and game.get('winner') == 'wolves' and bool(f['infections'] & winners)))
        f['infections'] = f.get('infections_count', 0)
    return facts


def record_match(c, engine, accounts, practice):
    game = engine.snapshot['game']
    facts = match_facts(game)
    day = datetime.now(UTC).date().isoformat()
    for player, uid in accounts.items():
        if not c.execute('SELECT 1 FROM users WHERE id=?', (uid,)).fetchone():
            continue
        if c.execute('SELECT 1 FROM challenge_matches WHERE match_id=? AND user_id=?', (engine.social_id, uid)).fetchone():
            continue
        ensure_user(c, uid)
        before = {r['challenge_id']: dict(r) for r in c.execute('SELECT * FROM challenge_progress WHERE user_id=?', (uid,))}
        f = facts.get(player)
        eligible = not practice and f is not None
        reason = '' if eligible else 'Partie d’entraînement avec bots : les défis récompensés progressent uniquement entre joueurs humains.' if practice else 'Les données de cette partie ne permettent pas de valider les défis.'
        if eligible:
            for metric in {ch['metric'] for ch in CATALOG} - {'verified', 'roles', 'winning_roles', 'winning_camps', 'themes', 'days', 'guarded_players', 'events', 'friend_games', 'event_games'}:
                add(c, uid, metric, f.get(metric, 0), maximum=metric.endswith('_best'))
            role = f['role']
            distinct(c, uid, 'roles', 'villager' if role == 'villager_female' else role)
            distinct(c, uid, 'days', day)
            if f['wins']:
                distinct(c, uid, 'winning_roles', 'villager' if role == 'villager_female' else role)
                if game.get('winner') in {'village', 'wolves'}:
                    distinct(c, uid, 'winning_camps', game['winner'])
            theme = engine.snapshot.get('visual_pack', 'classic')
            if theme in {'classic', 'intense', 'horror'}:
                distinct(c, uid, 'themes', theme)
            # Player IDs are ephemeral. Bind a protected identity to its account
            # across games, or to this match when no account is linked.
            for target in f['guards']:
                distinct(c, uid, 'guarded_players', f"account:{accounts[target]}" if target in accounts else f'{engine.social_id}:{target}')
            from .social import friends
            if sum(friends(c, uid, other) for other in set(accounts.values())-{uid}) >= 3:
                add(c, uid, 'friend_games')
            events = c.execute('SELECT event_id FROM challenge_room_events WHERE match_id=?', (engine.social_id,)).fetchall()
            if events:
                add(c, uid, 'event_games')
            for event in events:
                distinct(c, uid, 'events', event['event_id'])
            reconcile(c, uid)
        changes = []
        for ch in list_in(c, uid):
            old = before.get(ch['id'], {}).get('value', 0)
            if ch['progress'] > old:
                changes.append({**ch, 'before': old, 'newly_completed': ch['completed_at'] is not None and not before.get(ch['id'], {}).get('completed')})
        c.execute('INSERT INTO challenge_matches VALUES(?,?,?,?,?,?,?)', (engine.social_id, uid, engine.snapshot.get('code', ''), time.time(), int(eligible), reason, json.dumps(changes, ensure_ascii=False)))


@router.get('/catalog')
def public_catalog():
    # Only static definitions. Never borrow another account's cached progress.
    return {'preview': True, 'challenges': [
        {**ch, 'rewards': [reward_data(r) for r in ch['rewards']],
         'progress': 0, 'completed_at': None, 'claimed_at': None, 'choice': None}
        for ch in CATALOG], 'pending_challenges': [], 'pending_count': 0,
        'rules': 'Connecte ton compte de la communauté pour enregistrer tes progrès et recevoir tes récompenses.'}


@router.get('/me')
def mine(*, user: User, db: DB):
    with db.db() as c:
        items = list_in(c, user['id'])
        pending = [ch for ch in items if ch['completed_at'] and not ch['claimed_at']]
        return {'challenges': items, 'pending_challenges': pending, 'pending_count': len(pending), 'rules': 'Parties en ligne terminées entre joueurs humains. Termine un défi, puis réclame sa récompense. Les parties locales et avec bots restent des entraînements.'}


@router.get('/matches/{match_id}')
def result(match_id: str, *, user: User, db: DB):
    with db.db() as c:
        row = c.execute('SELECT * FROM challenge_matches WHERE match_id=? AND user_id=?', (match_id, user['id'])).fetchone()
        if not row:
            raise HTTPException(404, 'Le bilan des défis n’est pas encore disponible pour ce compte.')
        changes = json.loads(row['changes'])
        for ch in changes:
            definition = next((item for item in CATALOG if item['id'] == ch['id']), None)
            if definition:
                ch.update(difficulty=definition['difficulty'], chest_tier=definition['chest_tier'])
            current = c.execute('SELECT choice,claimed_at FROM challenge_progress WHERE user_id=? AND challenge_id=?', (user['id'], ch['id'])).fetchone()
            if current:
                ch['choice'] = current['choice']
                ch['claimed_at'] = current['claimed_at']
        pending = pending_in(c, user['id'])
        return {'match_id': match_id, 'eligible': bool(row['eligible']), 'reason': row['reason'], 'changes': changes, 'pending_challenges': pending, 'pending_count': len(pending)}


class Claim(BaseModel):
    challenge_ids: list[str] | None = Field(default=None, min_length=1, max_length=42)


@router.post('/claim')
def claim(data: Claim, *, user: User, db: DB):
    """Collect server-verified cosmetics and coins in one transaction."""
    db.limit(('challenge_claim', user['id']), 60, 300)
    with db.db() as c:
        c.execute('BEGIN IMMEDIATE')
        ensure_user(c, user['id'])
        available = {ch['id']: ch for ch in list_in(c, user['id'])}
        ids = list(dict.fromkeys(data.challenge_ids)) if data.challenge_ids is not None else [ident for ident, ch in available.items() if ch['completed_at'] and not ch['claimed_at']]
        if any(ident not in available or not available[ident]['completed_at'] for ident in ids):
            raise HTTPException(403, 'Termine ces défis avant de réclamer leurs récompenses.')
        claimed, rewards = [], []
        stamp = time.time()
        for ident in ids:
            if available[ident]['claimed_at']:
                continue
            definition = next(ch for ch in CATALOG if ch['id'] == ident)
            grant(c, user['id'], definition)
            c.execute('UPDATE challenge_progress SET claimed_at=? WHERE user_id=? AND challenge_id=? AND claimed_at IS NULL', (stamp, user['id'], ident))
            claimed.append(ident)
            rewards.extend(dict(earned_reward(c, user['id'], ident, r), challenge_id=ident, challenge_title=definition['title']) for r in definition['rewards'])
        return {'user_id': user['id'], 'claimed_ids': claimed, 'claimed_count': len(claimed), 'rewards': rewards,
                'coin_balance': balance_in(c, user['id']),
                'challenges': list_in(c, user['id']), 'pending_count': pending_count(c, user['id'])}


class AvatarChoice(BaseModel):
    avatar_id: str = Field(min_length=3, max_length=80)


@router.post('/choices/{challenge_id}')
def choose_avatar(challenge_id: str, data: AvatarChoice, *, user: User, db: DB):
    ch = next((ch for ch in CATALOG if ch['id'] == challenge_id), None)
    reward = next((r for r in ch['rewards'] if r['kind'] == 'avatar_choice'), None) if ch else None
    if not reward or data.avatar_id not in reward['ids']:
        raise HTTPException(422, 'Ce portrait ne fait pas partie de cette récompense.')
    with db.db() as c:
        c.execute('BEGIN IMMEDIATE')
        row = c.execute('SELECT * FROM challenge_progress WHERE user_id=? AND challenge_id=?', (user['id'], challenge_id)).fetchone()
        if not row or not row['completed'] or not row['claimed_at']:
            raise HTTPException(403, 'Réclame la récompense de ce défi avant de choisir ton portrait.')
        if row['choice'] and row['choice'] != data.avatar_id:
            raise HTTPException(409, 'Le portrait de ce défi a déjà été choisi.')
        c.execute('INSERT OR IGNORE INTO avatar_unlocks VALUES(?,?,?)', (user['id'], data.avatar_id, f'challenge:{challenge_id}'))
        c.execute('UPDATE challenge_progress SET choice=? WHERE user_id=? AND challenge_id=?', (data.avatar_id, user['id'], challenge_id))
    return {'ok': True}


class Event(BaseModel):
    title: str = Field(min_length=3, max_length=100)
    starts: float = Field(ge=0, le=4_102_444_800)
    ends: float = Field(ge=0, le=4_102_444_800)
    enabled: bool = True

    @model_validator(mode='after')
    def dates(self):
        if self.ends <= self.starts:
            raise ValueError('La fin doit suivre le début.')
        return self


@router.get('/admin/events')
def events(*, admin: Admin, db: DB):
    with db.db() as c:
        return {'events': [dict(r) for r in c.execute('SELECT * FROM challenge_events ORDER BY starts DESC')]}


@router.put('/admin/events/{event_id}')
def save_event(event_id: str, data: Event, *, admin: Admin, db: DB):
    if not re.fullmatch('[a-z0-9-]{3,60}', event_id):
        raise HTTPException(422, 'Identifiant d’événement invalide.')
    from .administration import audit
    with db.db() as c:
        c.execute('INSERT INTO challenge_events VALUES(?,?,?,?,?) ON CONFLICT(id) DO UPDATE SET title=excluded.title,starts=excluded.starts,ends=excluded.ends,enabled=excluded.enabled', (event_id, data.title, data.starts, data.ends, int(data.enabled)))
        audit(c, admin, 'challenge.event', event_id)
    return {'ok': True}
