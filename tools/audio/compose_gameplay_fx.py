"""Original short effects, generated locally without external samples."""
import math
import random
import struct
import wave
from pathlib import Path

OUT = Path(__file__).resolve().parents[2] / 'apps/mordeviel/assets/audio/classic'
SR = 24000


def save(name, values):
    peak = max(abs(v) for v in values) or 1
    with wave.open(str(OUT / name), 'wb') as f:
        f.setparams((1, 2, SR, 0, 'NONE', 'not compressed'))
        f.writeframes(b''.join(struct.pack('<h', int(max(-.92, min(.92, v / peak * .85)) * 32767)) for v in values))


def main():
    rng = random.Random(29102026)
    volley = []
    for i in range(int(SR * 1.15)):
        time = i / SR
        value = 0
        for start in (0, .3276, .6552):
            t = time - start
            if t >= 0:
                value += rng.uniform(-1, 1) * math.exp(-t * 38) + .8 * math.sin(2 * math.pi * 75 * t) * math.exp(-t * 15)
        volley.append(value)
    save('hunter_volley.wav', volley)
    electric = [rng.uniform(-1, 1) * (.35 + .65 * abs(math.sin(i / SR * 107))) * math.exp(-i / SR * 2) for i in range(int(SR * 1.2))]
    save('sentence_electric.wav', electric)
    cry, phase = [], 0
    for i in range(int(SR * 1.7)):
        t = i / SR
        hz = 420 * math.exp(-t * 1.9) + 85 + 7 * math.sin(t * 35)
        phase += 2 * math.pi * hz / SR
        envelope = min(1, t * 28) * math.exp(-t * 2.3) * min(1, (1.7-t)*8)
        cry.append(envelope * (math.sin(phase) + .43 * math.sin(phase * 2) + .24 * math.sin(phase * 3) + rng.uniform(-.2, .2)))
    save('wolf_fall.wav', cry)
    print('Three gameplay effects generated.')


if __name__ == '__main__':
    main()
