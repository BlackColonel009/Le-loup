"""Fetch and prepare the CC0 originals listed in docs/sources-effets-elimination.md."""
import shutil
import urllib.request
from pathlib import Path

import numpy as np
import soundfile as sf


def main():
    root = Path(__file__).resolve().parents[2]
    folder = root / '.tmp/hunter-media'
    folder.mkdir(parents=True, exist_ok=True)
    for url, name in [
        ('https://bigsoundbank.com/UPLOAD/mp3/0532.mp3?v=d', 'shotgun.mp3'),
        ('https://opengameart.org/sites/default/files/bullet_hole_0.png', 'bullet_hole.png'),
    ]:
        if not (folder / name).exists():
            urllib.request.urlretrieve(url, folder / name)
    original, rate = sf.read(folder / 'shotgun.mp3', dtype='float32')
    shot = original[int(.065 * rate):int(1.22 * rate)]
    shot = np.interp(np.arange(0, len(shot), rate / 24000), np.arange(len(shot)), shot)
    shot[-960:] *= np.linspace(1, 0, 960)
    mix = np.zeros(int((1.1088 + len(shot)/24000) * 24000) + 1)
    for time in [0, .5544, 1.1088]:
        offset = round(time * 24000)
        mix[offset:offset + len(shot)] += shot
    mix *= .94 / max(.01, float(np.max(np.abs(mix))))
    sf.write(root / 'apps/mordeviel/assets/audio/classic/hunter_volley.wav', mix, 24000, subtype='PCM_16')
    effects = root / 'apps/mordeviel/assets/effects'
    effects.mkdir(exist_ok=True)
    shutil.copyfile(folder / 'bullet_hole.png', effects / 'bullet_hole.png')
    print('Three real discharges and the original decal are installed.')


if __name__ == '__main__':
    main()
