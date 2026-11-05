"""Original short dry paper crackle and ember hiss for Sulfuron's card."""
import math
import random
import struct
import wave
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
rate, seconds = 24000, 2.1
rng = random.Random(511)
samples, low, pop = [], 0.0, 0.0
for i in range(round(rate*seconds)):
    t = i/rate
    envelope = min(1, t/.08)*min(1, (seconds-t)/.5)
    noise = rng.uniform(-1, 1)
    low = .86*low+.14*noise
    if rng.random() < .0025:
        pop = rng.uniform(.2, .8)
    pop *= .965
    value = envelope*(.19*low + .07*noise + pop*math.sin(i*2.31))
    samples.append(struct.pack('<h', round(max(-.9,min(.9,value))*32767)))
path = ROOT / 'apps/mordeviel/assets/audio/classic/sulfuron_fire.wav'
with wave.open(str(path),'wb') as output:
    output.setparams((1, 2, rate, len(samples), 'NONE', 'not compressed'))
    output.writeframes(b''.join(samples))
print('Sulfuron fire foley ready.')
