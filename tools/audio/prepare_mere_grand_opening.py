"""Original plucked-string fairy flourish and soft parchment rustle; no external samples."""
import math
import random
import struct
import wave
from pathlib import Path

RATE = 44100
LENGTH = 4.5


def prepare():
    rng = random.Random(1052026)
    count = round(RATE * LENGTH)
    left, right = [0.0] * count, [0.0] * count

    def pluck(start, frequency, gain, pan, length=1.65):
        # A damped vibrating string, with a separate soft body resonance.
        delay = max(8, round(RATE / frequency))
        string = [rng.uniform(-1, 1) for _ in range(delay)]
        previous = 0.0
        offset = round(start * RATE)
        for i in range(min(round(length * RATE), count - offset)):
            index = i % delay
            value = string[index]
            string[index] = (value + string[(index + 1) % delay]) * .4975
            previous = previous * .52 + value * .48
            t = i / RATE
            envelope = min(1.0, t / .012) * math.exp(-t * 1.5)
            sample = gain * envelope * (previous + .11 * math.sin(2 * math.pi * frequency * t) * math.exp(-t * 2.3))
            left[offset + i] += sample * math.sqrt((1 - pan) / 2)
            right[offset + i] += sample * math.sqrt((1 + pan) / 2)

    notes = [523.251, 587.330, 659.255, 783.991, 880.000, 1046.502, 1318.510, 1567.982]
    for i, note in enumerate(notes):
        pluck(.13 + i * .205, note, .29 + .018 * i, -.6 + i * .16)
    for note, pan in [(1046.502, -.35), (1318.510, .15), (1567.982, .5)]:
        pluck(1.87, note, .24, pan, 2.0)
    pluck(3.07, 2093.005, .25, -.2, 1.35)
    pluck(3.18, 2637.020, .22, .3, 1.25)
    # Airy paper, with gentle granular friction rather than an electronic sweep.
    low, smooth = 0.0, 0.0
    for i in range(round(1.75 * RATE)):
        t = i / RATE
        noise = rng.uniform(-1, 1)
        low = low * .985 + noise * .015
        smooth = smooth * .7 + (noise - low) * .3
        envelope = math.sin(math.pi * t / 1.75) ** 1.3
        pressure = .55 + .45 * math.sin(t * 63) ** 2
        rustle = smooth * envelope * pressure * .035
        left[i] += rustle
        right[i] += rustle * .85
    # Cross-channel room echoes lend the plucked strings a small magical space.
    for seconds, gain in [(.085, .13), (.16, .09), (.275, .05)]:
        delay = round(seconds * RATE)
        for i in range(count - delay - 1, -1, -1):
            left[i + delay] += right[i] * gain
            right[i + delay] += left[i] * gain
    peak = max(max(abs(x) for x in left), max(abs(x) for x in right), .001)
    scale = .78 / peak
    target = Path(__file__).resolve().parents[2] / 'apps/mordeviel/assets/audio/classic/mere_grand_opening.wav'
    with wave.open(str(target), 'wb') as output:
        output.setparams((2, 2, RATE, count, 'NONE', 'not compressed'))
        frames = bytearray()
        for i in range(count):
            tail = min(1, (count - i) / (RATE * .23))
            frames.extend(struct.pack('<hh', round(left[i] * scale * tail * 32767), round(right[i] * scale * tail * 32767)))
        output.writeframes(frames)
    print(f'{target.name}: {LENGTH}s stereo, {target.stat().st_size / 1024:.0f} Kio')


if __name__ == '__main__':
    prepare()
