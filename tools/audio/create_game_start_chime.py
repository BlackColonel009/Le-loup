"""Create the short, bundled Android invitation using the approved Intense voice.

Run with .tools/audio/qwen_onnx/.venv/Scripts/python.exe.
The instrumental bed is original procedural audio, not an external sample.
"""

import hashlib
import json
import math
import random
from pathlib import Path

import numpy as np
import soundfile as sf

ROOT = Path(__file__).resolve().parents[2]
VOICE = ROOT / '.tmp/audio/game_start_voice.wav'
OUTPUT = ROOT / 'apps/mordeviel/android/app/src/main/res/raw/mordeviel_game_start.wav'
TEXT = 'Le village t’attend…'
PROFILE = 'intense_male'
SR = 24000


def render_voice():
    from local_neural import RUNTIME, Pipeline, save
    from transformers import AutoTokenizer

    metadata = json.loads((ROOT / f'docs/audio-auditions/{PROFILE}.json').read_text(encoding='utf-8'))
    if not metadata.get('approved'):
        raise ValueError('The reference voice must be approved.')
    model = RUNTIME / 'base'
    print('Loading the approved local voice...', flush=True)
    pipe = Pipeline(str(model / 'cpu_int4'), tts_dir=str(model))
    pipe._tok = AutoTokenizer.from_pretrained(str(model), trust_remote_code=False,
        local_files_only=True, fix_mistral_regex=True)
    codes = pipe.generate(TEXT, language='French',
        ref_audio=str(ROOT / f'docs/audio-auditions/{PROFILE}.wav'),
        ref_text=metadata['text'], max_new_tokens=200, seed=29102026)
    if not 0 < len(codes) < 200:
        raise ValueError('Voice generation did not finish.')
    VOICE.parent.mkdir(parents=True, exist_ok=True)
    save(pipe.decode_chunked(codes[None]), VOICE)
    print('Invitation voice ready.', flush=True)


def compose():
    if not VOICE.exists():
        render_voice()
    voice, rate = sf.read(VOICE, dtype='float32')
    if rate != SR or voice.ndim != 1 or not .5 < len(voice) / SR < 5:
        raise ValueError('Unexpected invitation voice format/duration.')
    duration = len(voice) / SR + 1.05
    times = np.arange(math.ceil(duration * SR)) / SR
    envelope = np.minimum(1, times / .22) * np.minimum(1, (duration - times) / .65)
    bed = np.zeros(len(times))
    # A low cinematic swell and three clear bell-like opening notes.
    for frequency, gain in [(73.416, .04), (146.832, .025), (220, .012), (155.563, .008)]:
        bed += gain * np.sin(2 * math.pi * frequency * times + .09 * np.sin(times * 4))
    for onset, frequency in [(0, 587.33), (.19, 698.46), (.38, 880)]:
        elapsed = np.maximum(0, times - onset)
        bed += (times >= onset) * .12 * np.exp(-elapsed * 4.3) * (
            np.sin(2 * math.pi * frequency * elapsed) + .2 * np.sin(2 * math.pi * frequency * 2.01 * elapsed))
    rng = random.Random(29102026)
    wind = np.array([rng.uniform(-1, 1) for _ in times])
    wind = np.convolve(wind, np.ones(35) / 35, mode='same')
    bed += wind * .025
    bed *= envelope
    offset = round(.45 * SR)
    # Keep the voice clearly above the atmospheric bed.
    bed[offset:offset + len(voice)] *= .33
    voice *= .79 / max(.01, float(np.max(np.abs(voice))))
    for delay, gain in [(0, 1), (.115, .10), (.23, .045)]:
        start = offset + round(delay * SR)
        bed[start:start + len(voice)] += voice * gain
    peak = float(np.max(np.abs(bed)))
    bed *= min(1, .90 / peak)
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    sf.write(OUTPUT, bed, SR, subtype='PCM_16')
    metadata = {
        'text': TEXT, 'profile': PROFILE, 'voice_generated_locally': True,
        'reference_approved_by_user': True, 'background': 'Original procedural suspense bed',
        'seed': 29102026, 'seconds': round(len(bed) / SR, 3),
        'sample_rate': SR, 'channels': 1, 'format': 'WAV PCM 16-bit',
        'sha256': hashlib.sha256(OUTPUT.read_bytes()).hexdigest(),
        'bundled_android_resource': 'raw/mordeviel_game_start.wav',
    }
    (ROOT / 'tools/audio/game_start_chime.json').write_text(
        json.dumps(metadata, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(f'Notification ready: {metadata["seconds"]} s, {OUTPUT.stat().st_size / 1024:.0f} KiB', flush=True)


if __name__ == '__main__':
    compose()
