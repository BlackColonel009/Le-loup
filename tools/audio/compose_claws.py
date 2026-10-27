"""Deux coups de griffes originaux : frottement granuleux, déchirure et grondement.
Synthèse déterministe numpy ; aucune prise de son ou ressource tierce.
"""
from pathlib import Path
import wave
import numpy as np

out = Path(__file__).resolve().parents[2] / 'apps/le_loup/assets/audio/classic'
sr = 22050
for strike, duration in [(1, .68), (2, .86)]:
    rng = np.random.default_rng(854 + strike)
    t = np.arange(round(duration * sr)) / sr
    spectrum = np.fft.rfft(rng.normal(size=len(t)))
    freq = np.fft.rfftfreq(len(t), 1/sr)
    band = np.exp(-((freq-1800)/(1600 + strike*300))**2)
    band *= 1-np.exp(-(freq/250)**4)
    rasp = np.fft.irfft(spectrum*band, len(t))
    rasp /= max(1e-9, np.std(rasp))
    grain = .3 + .7*np.sin(2*np.pi*(48*t + 23*t*t))**4
    env = (1-np.exp(-t*80))*np.exp(-t*4.8) * np.minimum(1, (duration-t)/.06)
    growl_phase = 2*np.pi*(110*t-34*t*t + .012*np.sin(2*np.pi*31*t))
    growl = np.tanh(2*np.sin(growl_phase))
    rip = rasp * grain * .6 + growl * .22
    rip += .15*np.sin(2*np.pi*(1100*t+1200*t*t))*np.exp(-t*10)
    sound = rip*env
    sound += np.concatenate([np.zeros(round(.055*sr)), sound[:-round(.055*sr)]])*.14
    sound *= .72 / max(1e-9, abs(sound).max())
    pan = np.linspace(-.6, .6, len(t)) * (1 if strike == 1 else -1)
    stereo = np.column_stack([sound*np.sqrt((1-pan)/2), sound*np.sqrt((1+pan)/2)])
    out.mkdir(parents=True, exist_ok=True)
    path = out / f'claw_{strike}.wav'
    with wave.open(str(path), 'wb') as target:
        target.setparams((2, 2, sr, 0, 'NONE', 'not compressed'))
        target.writeframes((stereo*32767).astype('<i2').tobytes())
    print(path.name)
