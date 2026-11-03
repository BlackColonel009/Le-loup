"""Create original soft arcade-like reward chimes (no third-party samples)."""

import math
import struct
import wave
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
RATE = 24000


def render(name, notes):
    length = max(start + duration for start, _, duration in notes) + .12
    values = [0.0] * int(length * RATE)
    for start, pitch, duration in notes:
        frequency = 440 * 2 ** ((pitch-69)/12)
        for i in range(int(duration*RATE)):
            t = i/RATE
            envelope = min(1, t/.007) * math.exp(-7*t/duration) * min(1, (duration-t)/.025)
            # A bell with restrained overtones and a rounded transient.
            sample = (math.sin(2*math.pi*frequency*t) + .26*math.sin(2*math.pi*frequency*2*t) + .09*math.sin(2*math.pi*frequency*3*t)) * envelope
            values[int(start*RATE)+i] += sample
    peak = max(abs(v) for v in values) or 1
    target = ROOT / f'apps/mordeviel/assets/audio/classic/challenge_{name}.wav'
    with wave.open(str(target), 'wb') as out:
        out.setparams((1, 2, RATE, 0, 'NONE', 'not compressed'))
        out.writeframes(b''.join(struct.pack('<h', round(v/peak * 21000)) for v in values))


render('progress', [(0, 76, .23), (.11, 79, .25), (.23, 83, .38), (.39, 88, .38)])
render('unlock', [(0, 72, .28), (.12, 76, .32), (.24, 79, .34), (.40, 84, .64), (.40, 88, .64), (.40, 91, .64)])
print('Deux carillons originaux créés, 24 kHz mono.')
