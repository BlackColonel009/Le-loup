"""Render the opening using the game's approved local Qwen Intense male voice.

Run with .tools/audio/qwen_onnx/.venv/Scripts/python.exe. No online service,
system voice, or new reference identity is used. Raw takes are cached locally.
"""
import hashlib
import json
from pathlib import Path

import numpy as np
import soundfile as sf

ROOT = Path(__file__).resolve().parents[2]
OUTPUT = ROOT / '.tmp/audio/opening-qwen'
PROFILE = 'intense_male'
TEXT = 'Bienvenue dans Mordeviel Legendary… que la traque commence.'
# The brand's spoken spelling, requested by Logan; display metadata stays canonical.
TAKES = [('welcome', 'Bienvenue dans Mordeviel Lédjèndeuri.', 3112026),
         ('threat', 'Que la traque commence.', 3112027)]


def main():
    from local_neural import RUNTIME, SR, Pipeline, save
    from transformers import AutoTokenizer

    OUTPUT.mkdir(parents=True, exist_ok=True)
    metadata = json.loads((ROOT / f'docs/audio-auditions/{PROFILE}.json').read_text(encoding='utf-8'))
    reference = ROOT / f'docs/audio-auditions/{PROFILE}.wav'
    if not metadata.get('approved'):
        raise ValueError('An approved game voice is required.')
    pipe = None
    for cue, spoken, seed in TAKES:
        target = OUTPUT / f'{cue}.wav'
        if target.exists():
            continue
        if pipe is None:
            model = RUNTIME / 'base'
            print('Loading the approved Qwen game voice...', flush=True)
            pipe = Pipeline(str(model / 'cpu_int4'), tts_dir=str(model))
            pipe._tok = AutoTokenizer.from_pretrained(str(model), trust_remote_code=False,
                local_files_only=True, fix_mistral_regex=True)
        print(f'Rendering opening/{cue}...', flush=True)
        codes = pipe.generate(spoken, language='French', ref_audio=str(reference),
            ref_text=metadata['text'], max_new_tokens=180, seed=seed)
        if not 0 < len(codes) < 180:
            raise ValueError(f'Take {cue} did not finish normally.')
        details = save(pipe.decode_chunked(codes[None]), target)
        print(f'{cue}: {details["seconds"]} s', flush=True)
    parts = []
    for cue, _, _ in TAKES:
        audio, rate = sf.read(OUTPUT / f'{cue}.wav', dtype='float32')
        if rate != SR:
            raise ValueError('Unexpected voice sample rate.')
        # Trim only silence, preserving a short breath around each take.
        energy = np.convolve(audio ** 2, np.ones(480) / 480, mode='same')
        active = np.flatnonzero(energy > max(.000004, float(energy.max()) * .002))
        if not len(active):
            raise ValueError('Silent take.')
        audio = audio[max(0, active[0] - 1600):min(len(audio), active[-1] + 2400)]
        parts.append(audio)
    master = np.concatenate([parts[0], np.zeros(round(SR * .72)), parts[1]])
    path = OUTPUT / 'opening-voice.wav'
    sf.write(path, master, SR, subtype='PCM_16')
    details = {
        'text': TEXT, 'profile': PROFILE,
        'engine': json.loads((RUNTIME / 'base/source.json').read_text(encoding='utf-8')),
        'reference_sha256': hashlib.sha256(reference.read_bytes()).hexdigest(),
        'takes': [{'cue': cue, 'spoken_text': spoken, 'seed': seed} for cue, spoken, seed in TAKES],
        'pause_seconds': .72, 'seconds': round(len(master) / SR, 3),
        'sha256': hashlib.sha256(path.read_bytes()).hexdigest(),
        'generated_locally': True,
    }
    (OUTPUT / 'voice.json').write_text(json.dumps(details, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(f'Opening voice ready: {details["seconds"]} s', flush=True)


if __name__ == '__main__':
    main()
