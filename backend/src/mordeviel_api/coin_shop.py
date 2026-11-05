"""Virtual-currency catalogue, ownership and deterministic daily selection."""

import hashlib
import time
from datetime import date

from .avatar_styles import BORDERS


def minimum_price(product):
    if product['kind'] == 'sticker':
        return 400
    if product['kind'] == 'card' and product['theme'] == 'intense':
        return 1800
    if product['kind'] == 'border':
        return 1000
    return None


def border_products():
    return [b for b in BORDERS if not b.get('free') and not b.get('creator_only')
            and b['id'] != 'welcome']


def owned_ids(c, uid):
    if uid is None:
        return set()
    result = {r[0] for r in c.execute(
        'SELECT product_id FROM collection_owned WHERE user_id=?', (uid,))}
    result.update('border-' + r[0] for r in c.execute(
        'SELECT border_id FROM border_unlocks WHERE user_id=?', (uid,)))
    return result


def daily_ids(products, day):
    """Three of each kind; a fixed cyclic order guarantees a new window each day."""
    selected = []
    for kind in ['sticker', 'card', 'border']:
        pool = sorted(
            (p for p in products if p['visible'] and p['shop'] and
             p['kind'] == kind and minimum_price(p) is not None and
             p['coin_price'] is not None and p['coin_price'] >= minimum_price(p)),
            key=lambda p: hashlib.sha256(p['id'].encode()).digest())
        if pool:
            count = min(3, len(pool))
            offset = date.fromisoformat(day).toordinal() * count % len(pool)
            selected.extend(pool[(offset + i) % len(pool)]['id'] for i in range(count))
    return selected


def grant(c, uid, product_ids, source):
    granted = []
    for pid in dict.fromkeys(product_ids):
        row = c.execute('SELECT * FROM collection_products WHERE id=?', (pid,)).fetchone()
        if row is None:
            continue
        c.execute('INSERT OR IGNORE INTO collection_owned VALUES(?,?,?,?)',
                  (uid, pid, source, time.time()))
        if c.execute('SELECT changes()').fetchone()[0]:
            granted.append(pid)
        if row['kind'] == 'border':
            c.execute('INSERT OR IGNORE INTO border_unlocks VALUES(?,?,?)',
                      (uid, row['role_id'], source))
    return granted
