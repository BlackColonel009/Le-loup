"""Register challenge cosmetics and the portrait opening inside each frame."""
import json
import math
import random
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
path = ROOT / 'shared/avatars/rewards.json'
entries = json.loads(path.read_text(encoding='utf-8'))


def opening(file):
    image = Image.open(file).convert('RGBA')
    side = image.width
    alpha = image.getchannel('A').tobytes()
    unseen = bytearray(1 if value < 32 else 0 for value in alpha)
    holes = []
    for index in range(len(unseen)):
        if not unseen[index]:
            continue
        unseen[index] = 0
        queue, points, edge = [index], [], False
        while queue:
            i = queue.pop()
            y, x = divmod(i, side)
            points.append((x, y))
            if x == 0 or y == 0 or x == side-1 or y == side-1:
                edge = True
            for j in (i-side if y else -1, i+side if y < side-1 else -1,
                      i-1 if x else -1, i+1 if x < side-1 else -1):
                if j >= 0 and unseen[j]:
                    unseen[j] = 0
                    queue.append(j)
        if not edge and len(points) > side*side*.01:
            holes.append(points)
    if not holes:
        raise ValueError(f'No usable transparent portrait opening: {file.name}')
    largest = max(map(len, holes))
    boundary = []
    for hole in holes:
        if len(hole) < largest*.18:
            continue
        for x, y in hole:
            i = y*side+x
            if any(alpha[j] >= 32 for j in (i-1, i+1, i-side, i+side)):
                boundary.append((x, y))
    # Fit the circular inner rim, allowing bats, snakes and other ornaments to
    # overlap the portrait. An inscribed clear circle would shrink the face.
    rng = random.Random(file.name)
    best = None
    for _ in range(350):
        (ax, ay), (bx, by), (cx, cy) = rng.sample(boundary, 3)
        determinant = 2*(ax*(by-cy)+bx*(cy-ay)+cx*(ay-by))
        if abs(determinant) < 1:
            continue
        aa, bb, cc = ax*ax+ay*ay, bx*bx+by*by, cx*cx+cy*cy
        x = (aa*(by-cy)+bb*(cy-ay)+cc*(ay-by))/determinant
        y = (aa*(cx-bx)+bb*(ax-cx)+cc*(bx-ax))/determinant
        radius = math.hypot(ax-x, ay-y)
        if not (.12*side < radius < .4*side and .2*side < x < .8*side and .2*side < y < .8*side):
            continue
        score = sum(abs(math.hypot(px-x, py-y)-radius) < 1.8 for px, py in boundary)
        if best is None or score > best[0]:
            best = score, x, y, radius
    if best is None:
        raise ValueError(f'Inner rim not found: {file.name}')
    _, cx, cy, radius = best
    radius *= .99
    return [round(v/side, 6) for v in (cx-radius, cy-radius, radius*2, radius*2)]


avatars_path = ROOT / 'shared/avatars/catalog.json'
avatars = json.loads(avatars_path.read_text(encoding='utf-8'))
borders_path = ROOT / 'shared/avatars/borders.json'
borders = json.loads(borders_path.read_text(encoding='utf-8'))
avatars['avatars'] = [a for a in avatars['avatars'] if a.get('source_root') != 'rewards']
borders['borders'] = [b for b in borders['borders'] if b.get('pack_id') != 'borders-rewards']
for entry in entries:
    if entry['kind'] == 'portraits':
        avatars['avatars'].append({
            'id': entry['id'], 'role_id': 'cosmetic', 'title': entry['title'], 'theme': 'rewards',
            'pack_id': entry['pack_id'], 'asset': entry['asset'], 'source': entry['source'],
            'source_root': 'rewards', 'starter': False, 'full_art': True, 'crop': [0, 0, 1, 1],
        })
    else:
        rect = opening(ROOT / 'shared/avatars/rewards/borders' / entry['source'])
        entry['opening'] = rect
        borders['borders'].append({
            'id': entry['id'], 'title': entry['title'], 'effect': 'artwork',
            'colors': ['#705331', '#D6AE70', '#FFF1D7'], 'asset': entry['asset'],
            'pack_id': entry['pack_id'], 'opening': rect,
        })
for file, data in [(avatars_path, avatars), (borders_path, borders), (path, entries)]:
    file.write_text(json.dumps(data, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
print('15 profils et 25 bordures ajoutés aux catalogues de récompenses.')
