"""À lancer après render_voices.ps1 : courte réverbération, crêtes contrôlées."""
from pathlib import Path
import wave
import numpy as np

root = Path(__file__).resolve().parents[2] / 'apps/le_loup/assets/audio/classic'
for path in root.glob('*.wav'):
    if path.stem not in {'role_reveal', 'sleep', 'seer', 'wolves', 'witch', 'dawn',
                         'hunter', 'day', 'voting', 'vote_result',
                         'ended_village', 'ended_wolves', 'ended_draw'}:
        continue
    with wave.open(str(path), 'rb') as source:
        sr = source.getframerate()
        assert source.getnchannels() == 1 and source.getsampwidth() == 2
        samples = np.frombuffer(source.readframes(source.getnframes()), '<i2').astype(float) / 32768
    out = np.pad(samples, (0, int(sr*.35)))
    for delay, gain in [(.075, .10), (.14, .065), (.23, .035)]:
        offset = round(delay*sr)
        out[offset:offset+len(samples)] += samples * gain
    out *= .65 / max(1e-9, np.max(np.abs(out)))
    with wave.open(str(path), 'wb') as target:
        target.setparams((1, 2, sr, 0, 'NONE', 'not compressed'))
        target.writeframes((out * 32767).astype('<i2').tobytes())
