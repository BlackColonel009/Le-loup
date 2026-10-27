"""Composition originale : 64 secondes, ré mineur, nappes et harpe, sans batterie.
Reproductible avec numpy ; aucun extrait musical tiers.
"""
from pathlib import Path
import wave
import numpy as np

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'apps/le_loup/assets/audio/classic'
SR = 22050
DURATION = 64
n = SR * DURATION
mix = np.zeros((n, 2), dtype=np.float64)


def hz(midi):
    return 440 * 2 ** ((midi - 69) / 12)


def add(start, signal, pan=0):
    indices = (np.arange(len(signal)) + round(start * SR)) % n
    mix[indices, 0] += signal * np.sqrt((1 - pan) / 2)
    mix[indices, 1] += signal * np.sqrt((1 + pan) / 2)


# Chaque accord se recouvre avec le suivant ; les queues traversent la boucle.
chords = [[38, 50, 53, 57, 64], [34, 46, 53, 58, 62],
          [41, 48, 53, 57, 60], [36, 48, 52, 55, 62]]
for bar in range(8):
    t = np.arange(SR * 12) / SR
    env = np.sin(np.pi * t / 12) ** 2
    for j, note in enumerate(chords[bar % 4]):
        f = hz(note)
        pad = sum(np.sin(2*np.pi*(f * (1 + detune))*t + j*.3)
                  for detune in [-.0012, 0, .0012]) / 3
        pad += .12*np.sin(2*np.pi*2*f*t)
        add(bar*8 - 2, pad * env * (.052 if j else .075), (j-2)*.22)

melody = [69, 72, 74, 76, 77, 74, 72, 69, 65, 69, 72, 74, 72, 67, 64, 67]
for i, note in enumerate(melody):
    t = np.arange(SR * 6) / SR
    f = hz(note)
    env = (1-np.exp(-t*2.4))*np.exp(-t*.8)
    flute = np.sin(2*np.pi*f*t + .018*np.sin(2*np.pi*4.2*t))
    flute += .12*np.sin(2*np.pi*f*2*t)
    add(i*4 + .5, flute*env*.065, .28*np.sin(i))
    # Harpe étouffée, attaques douces et longues résonances.
    harp = sum(np.sin(2*np.pi*hz(note-12)*k*t) / k**2 for k in range(1, 6))
    add(i*4 + 2, harp*(1-np.exp(-t*12))*np.exp(-t*1.4)*.045, -.35)

dry = mix.copy()
for delay, gain in [(.19, .15), (.37, .10), (.73, .07), (1.13, .04)]:
    mix += np.roll(dry[:, ::-1], round(delay*SR), axis=0)*gain
# Crête modérée, pas de limiteur agressif ; couture courte et continue.
mix *= .48 / max(1e-9, np.max(np.abs(mix)))
edge = 128
join = (mix[0] + mix[-1]) / 2
mix[:edge] = join + (mix[:edge]-join)*np.linspace(0, 1, edge)[:, None]
mix[-edge:] = join + (mix[-edge:]-join)*np.linspace(1, 0, edge)[:, None]
OUT.mkdir(parents=True, exist_ok=True)
with wave.open(str(OUT / 'moonlit_village.wav'), 'wb') as out:
    out.setparams((2, 2, SR, 0, 'NONE', 'not compressed'))
    out.writeframes((np.clip(mix, -1, 1)*32767).astype('<i2').tobytes())
print('Composition originale enregistrée :', OUT / 'moonlit_village.wav')
