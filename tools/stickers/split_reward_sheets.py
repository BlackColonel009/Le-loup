"""Split Logan's imagegen-extracted sheets, preserving their RGBA pixels.

Background extraction was performed with imagegen, not by this script.
Only isolate components, crop, and pad the existing cut-outs here.
"""
import json
from pathlib import Path

from PIL import Image, ImageChops, ImageFilter

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'apps/mordeviel/assets/stickers/rewards'
OUT.mkdir(parents=True, exist_ok=True)
CATALOG = json.loads((ROOT / 'shared/stickers/rewards.json').read_text(encoding='utf-8'))


def components(image, minimum=750):
    width, height = image.size
    data = bytearray(1 if a > 200 else 0 for a in image.getchannel('A').tobytes())
    found = []
    for index in range(len(data)):
        if not data[index]:
            continue
        data[index] = 0
        queue, pixels = [index], []
        left, top, right, bottom = width, height, 0, 0
        while queue:
            i = queue.pop()
            y, x = divmod(i, width)
            pixels.append(i)
            left, right = min(left, x), max(right, x)
            top, bottom = min(top, y), max(bottom, y)
            for j in (i-width if y else -1, i+width if y < height-1 else -1,
                      i-1 if x else -1, i+1 if x < width-1 else -1):
                if j >= 0 and data[j]:
                    data[j] = 0
                    queue.append(j)
        if len(pixels) >= minimum:
            found.append(((left, top, right+1, bottom+1), pixels))
    return found


def isolate(image, parts):
    mask = bytearray(image.width * image.height)
    for _, pixels in parts:
        for index in pixels:
            mask[index] = 255
    matte = Image.frombytes('L', image.size, bytes(mask)).filter(ImageFilter.MaxFilter(3))
    result = image.copy()
    result.putalpha(ImageChops.multiply(image.getchannel('A'), matte))
    result = result.crop(result.getbbox())
    output = Image.new('RGBA', (result.width+12, result.height+12))
    output.alpha_composite(result, (6, 6))
    return output


for sheet in ('roles', 'reactions'):
    image = Image.open(ROOT / f'shared/stickers/sources/{sheet}-transparent.png').convert('RGBA')
    entries = [item for item in CATALOG if item['sheet'] == sheet]
    cuts = []
    if sheet == 'roles':
        parts = components(image)
        # Exclude the extra caption with no character at the far right of row 5.
        parts = [p for p in parts if not (p[0][0] > 1400 and 590 < p[0][1] < 730)]
        parts.sort(key=lambda p: (int((p[0][1]+5)/145), p[0][0]))
        for part in parts:
            cuts.append(isolate(image, [part]))
    else:
        xs = [0, 407, 698, 985, 1277, image.width]
        ys = [(0, 233), (228, 445), (444, 660), (650, image.height)]
        for row, (top, bottom) in enumerate(ys):
            for col in range(5):
                cell = image.crop((xs[col], top, xs[col+1], bottom))
                parts = components(cell, minimum=400)
                # The last caption is detached from its running wolf.
                selected = sorted(parts, key=lambda p: len(p[1]), reverse=True)
                keep = selected[:2] if row == 3 and col == 3 else selected[:1]
                if not keep:
                    raise ValueError(f'Empty sticker {row}, {col}')
                cuts.append(isolate(cell, keep))
    if len(cuts) != len(entries):
        raise ValueError(f'{sheet}: {len(cuts)} cut-outs for {len(entries)} entries')
    for entry, cut in zip(entries, cuts, strict=True):
        cut.save(OUT / (entry['id']+'.png'), optimize=True)
print(f'{len(CATALOG)} PNG transparents séparés.')
