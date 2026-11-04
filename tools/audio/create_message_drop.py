"""Original short water-drop notification with a cave-like echo, no samples."""
import hashlib
import json
import math
import struct
import wave
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
RATE, SECONDS = 44100, 1.8


def main():
    sound = [0.0] * round(RATE * SECONDS)
    for onset, gain, frequency in [(0.03, 1.0, 1280), (.26, .68, 1530)]:
        for delay, echo in [(0, 1), (.105, .30), (.23, .19), (.39, .12), (.60, .07), (.85, .035)]:
            offset = round((onset + delay) * RATE)
            for i in range(min(round(.65 * RATE), len(sound) - offset)):
                t = i / RATE
                attack = 1 - math.exp(-t * 1300)
                phase = 2 * math.pi * (frequency * t + 95 * (1 - math.exp(-t * 35)) / 35)
                drop = math.sin(phase) * math.exp(-t * 24) + .24 * math.sin(phase * .5) * math.exp(-t * 14)
                sound[offset + i] += gain * echo * attack * drop
    peak = max(abs(value) for value in sound)
    raw = b''.join(struct.pack('<h', round(value / peak * .68 * 32767)) for value in sound)
    targets = ['apps/mordeviel/assets/audio/classic/message_drop.wav',
               'apps/mordeviel/android/app/src/main/res/raw/mordeviel_message_drop.wav']
    for target in targets:
        path = ROOT / target
        path.parent.mkdir(parents=True, exist_ok=True)
        with wave.open(str(path), 'wb') as output:
            output.setnchannels(1)
            output.setsampwidth(2)
            output.setframerate(RATE)
            output.writeframes(raw)
    (ROOT / 'tools/audio/message_drop.json').write_text(json.dumps({
        'description': 'Original two water drops with short cave reflections',
        'seconds': SECONDS, 'sample_rate': RATE, 'files': targets,
        'sha256': hashlib.sha256((ROOT / targets[0]).read_bytes()).hexdigest(),
    }, indent=2)+'\n', encoding='utf-8')
    print('Message notification sound created: 1.8 seconds.')


if __name__ == '__main__':
    main()
