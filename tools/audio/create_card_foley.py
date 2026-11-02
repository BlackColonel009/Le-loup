"""Create the short original, role-neutral card handling sound (standard library)."""
import math
import random
import struct
import wave
from pathlib import Path

target = Path(__file__).resolve().parents[2] / 'apps/mordeviel/assets/audio/classic/card_flick.wav'
rng = random.Random(113)
rate = 24000
samples = []
low = 0.0
for i in range(int(rate * .19)):
    t = i / rate
    noise = rng.uniform(-1, 1)
    low = .70 * low + .30 * noise
    envelope = math.exp(-((t - .045) / .024) ** 2) + .4 * math.exp(-((t - .12) / .019) ** 2)
    signal = (noise - low) * envelope * .16 + low * envelope * .09
    samples.append(struct.pack('<h', int(max(-1, min(1, signal)) * 32767)))
with wave.open(str(target), 'wb') as out:
    out.setnchannels(1)
    out.setsampwidth(2)
    out.setframerate(rate)
    out.writeframes(b''.join(samples))
print('Card foley ready: 0.19 s, mono 24 kHz')
