"""Two short original end-of-game stingers. No samples or external music."""
from pathlib import Path
import wave
import numpy as np

OUT = Path(__file__).resolve().parents[2] / 'apps/mordeviel/assets/audio/classic'
SR = 24000


def compose(dark):
    duration = 4.0
    mix = np.zeros((int(SR * duration), 2))
    notes = [48, 51, 54, 59] if dark else [60, 64, 67, 72, 76]
    for i, midi in enumerate(notes):
        start = .22 * i
        t = np.arange(len(mix) - int(start * SR)) / SR
        hz = 440 * 2 ** ((midi - 69) / 12)
        envelope = (1 - np.exp(-t * (5 if dark else 35))) * np.exp(-t * (1.0 if dark else 1.4))
        sound = np.sin(2 * np.pi * hz * t)
        sound += .18 * np.sin(2 * np.pi * hz * (2.003 if dark else 2) * t) * np.exp(-t)
        if dark:
            sound += .3 * np.sin(2 * np.pi * hz / 2 * t) * (.8 + .2 * np.cos(5 * t))
        pan = (i / max(1, len(notes) - 1) - .5) * .7
        mix[int(start * SR):, 0] += sound * envelope * np.sqrt((1 - pan) / 2)
        mix[int(start * SR):, 1] += sound * envelope * np.sqrt((1 + pan) / 2)
    fade = np.minimum(1, np.arange(len(mix))[::-1] / (SR * .65))
    mix *= fade[:, None]
    mix *= .72 / max(.001, np.max(np.abs(mix)))
    path = OUT / ('ending_dark.wav' if dark else 'ending_bright.wav')
    with wave.open(str(path), 'wb') as target:
        target.setparams((2, 2, SR, 0, 'NONE', 'not compressed'))
        target.writeframes((mix * 32767).astype('<i2').tobytes())
    print(path.name, flush=True)


if __name__ == '__main__':
    for dark in (False, True):
        compose(dark)
