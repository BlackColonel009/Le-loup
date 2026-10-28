"""Pluie en boucle et grondement d'orage originaux, sans extrait tiers."""
from pathlib import Path
import wave
import numpy as np

out = Path(__file__).resolve().parents[2] / 'apps/mordeviel/assets/audio/classic'
sr = 22050
rng = np.random.default_rng(97856)


def colored(seconds, rain=False):
    n = round(seconds*sr)
    f = np.fft.rfftfreq(n, 1/sr)
    spectrum = np.fft.rfft(rng.normal(size=n))
    if rain:
        filt = (1-np.exp(-(f/210)**2)) * np.exp(-(f/6100)**2) / np.maximum(f, 240)**.32
    else:
        filt = np.exp(-(f/320)**2) / np.maximum(f, 28)**.65
        filt *= 1-np.exp(-(f/23)**4)
    signal = np.fft.irfft(spectrum*filt, n)
    return signal / max(1e-9, np.std(signal))


def save(name, signal, peak):
    signal *= peak / max(1e-9, abs(signal).max())
    out.mkdir(parents=True, exist_ok=True)
    with wave.open(str(out / name), 'wb') as target:
        target.setparams((2, 2, sr, 0, 'NONE', 'not compressed'))
        target.writeframes((signal*32767).astype('<i2').tobytes())


t = np.arange(sr*12)/sr
shared = colored(12, rain=True)
rain = np.column_stack([.75*shared + .25*colored(12, rain=True),
                        .75*shared + .25*colored(12, rain=True)])
rain *= (1 + .07*np.sin(2*np.pi*t/12))[:, None]
edge = 600
join = (rain[0] + rain[-1])/2
rain[:edge] = join + (rain[:edge]-join)*np.linspace(0, 1, edge)[:, None]
rain[-edge:] = join + (rain[-edge:]-join)*np.linspace(1, 0, edge)[:, None]
save('rain_loop.wav', rain, .36)

seconds = 6.5
t = np.arange(round(sr*seconds))/sr
envelope = (1-np.exp(-t*12))*np.exp(-t*.48)*(1 + .28*np.sin(t*4))
envelope *= np.clip((seconds-t)/.6, 0, 1)
thunder = np.column_stack([colored(seconds), colored(seconds)]) * envelope[:, None]
thunder += .2*np.sin(2*np.pi*(58*t - 1.6*t*t))[:, None]*envelope[:, None]
save('thunder.wav', thunder, .68)
print('Pluie et grondement enregistrés dans', out)
