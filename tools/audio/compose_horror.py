"""Original owl sound design, no third-party recording or Windows speech."""
from pathlib import Path
import wave
import numpy as np

out = Path(__file__).resolve().parents[2] / 'apps/mordeviel/assets/audio/horror'
out.mkdir(parents=True, exist_ok=True)
sr = 24000
t = np.arange(sr * 5) / sr
signal = np.zeros_like(t)
for start, duration, pitch in [(0.25, .32, 480), (.82, .63, 390), (2.3, .28, 490), (2.85, .8, 370)]:
    local = t - start
    mask = (local >= 0) & (local < duration)
    u = np.clip(local / duration, 0, 1)
    envelope = np.sin(np.pi * u) ** .7 * mask
    frequency = pitch + 35 * np.sin(np.pi * u) + 5 * np.sin(2 * np.pi * 7 * t)
    phase = 2 * np.pi * np.cumsum(frequency) / sr
    signal += envelope * (np.sin(phase) + .12 * np.sin(2 * phase))
# Faint delayed tail; rounded peaks, no sudden volume spike.
delay = int(sr * .19)
signal[delay:] += .12 * signal[:-delay].copy()
signal *= .52 / max(np.max(np.abs(signal)), 1e-9)
with wave.open(str(out / 'owl.wav'), 'wb') as f:
    f.setparams((1, 2, sr, 0, 'NONE', 'not compressed'))
    f.writeframes((signal * 32767).astype('<i2').tobytes())
print('Original owl sound saved.')
