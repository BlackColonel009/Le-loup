"""Generate original auditions or game cues locally, with no account or API.

Run with .tools/audio/qwen_onnx/.venv/Scripts/python.exe after
setup_local_neural.py design (auditions) or base (approved game cues).
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import sys
import time

ROOT = Path(__file__).resolve().parents[2]
RUNTIME = ROOT / '.tools/audio/qwen_onnx'
os.environ['HF_HUB_OFFLINE'] = '1'
os.environ['TRANSFORMERS_OFFLINE'] = '1'
os.environ['TOKENIZERS_PARALLELISM'] = 'false'
sys.path.insert(0, str(RUNTIME))
from inference import Pipeline, SR
import numpy as np
import soundfile as sf

def save(wav, output):
    wav = np.asarray(wav, dtype=np.float32).reshape(-1)
    if not np.isfinite(wav).all() or not .4 < len(wav) / SR < 35:
        raise ValueError('Unexpected waveform or duration')
    peak = float(np.max(np.abs(wav)))
    if peak < .01 or np.sqrt(np.mean(wav ** 2)) < .001:
        raise ValueError('Silent generation')
    if peak > .95:
        wav *= .95 / peak
    # Gentle edge fades only, no pitch/time manipulation or synthetic effects.
    edge = min(240, len(wav) // 2)
    wav[:edge] *= np.linspace(0, 1, edge)
    wav[-edge:] *= np.linspace(1, 0, edge)
    temporary = output.with_suffix('.pending.wav')
    sf.write(temporary, wav, SR, subtype='PCM_16')
    temporary.replace(output)
    return {'seconds': round(len(wav) / SR, 3),
            'sha256': hashlib.sha256(output.read_bytes()).hexdigest()}

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('mode', choices=['auditions', 'cues'])
    parser.add_argument('--profile')
    parser.add_argument('--limit', type=int)
    parser.add_argument('--cue', help='Render only this logical cue')
    parser.add_argument('--device', choices=['cpu', 'cuda'], default='cpu')
    args = parser.parse_args()
    kind = 'design' if args.mode == 'auditions' else 'base'
    model = RUNTIME / kind
    components = model / 'cpu_int4'
    if args.device == 'cuda':
        import onnxruntime as ort
        ort.preload_dlls(directory='')
        if 'CUDAExecutionProvider' not in ort.get_available_providers():
            raise RuntimeError('CUDA runtime unavailable; use CPU environment')
        components = model / 'cuda_local'
        components.mkdir(exist_ok=True)
        manifest = json.loads((model / 'cpu_int4/manifest.json').read_text(encoding='utf-8'))
        manifest['execution_provider'] = 'CUDAExecutionProvider'
        manifest['provider_options'] = {'arena_extend_strategy': 'kSameAsRequested',
            'cudnn_conv_use_max_workspace': '0', 'do_copy_in_default_stream': '1'}
        for component in manifest['sub_models'].values():
            target = components / component['filename']
            if not target.exists():
                os.link(model / 'cpu_int4' / component['filename'], target)
        (components / 'manifest.json').write_text(json.dumps(manifest), encoding='utf-8')
    print('Loading local ' + kind + ' model (' + args.device + ')...', flush=True)
    pipe = Pipeline(str(components), tts_dir=str(model))
    from transformers import AutoTokenizer
    pipe._tok = AutoTokenizer.from_pretrained(str(model), trust_remote_code=False,
        local_files_only=True, fix_mistral_regex=True)
    source = json.loads((model / 'source.json').read_text(encoding='utf-8'))
    print('Local model loaded.', flush=True)
    candidates = json.loads((ROOT / 'docs/audio-auditions/pending_profiles.json').read_text(encoding='utf-8'))
    descriptions = json.loads((ROOT / 'tools/audio/neural_profiles.json').read_text(encoding='utf-8'))['profiles']
    by_id = {p['id']: p for p in descriptions}
    profiles = candidates if args.mode == 'auditions' else by_id
    count = 0
    for index, profile in enumerate(profiles):
        if args.profile and profile != args.profile:
            continue
        folder = ROOT / 'docs/audio-auditions'
        metadata_path = folder / (profile + '.json')
        if args.mode == 'auditions':
            if metadata_path.exists():
                print('Preserving existing audition: ' + profile, flush=True)
                continue
            candidate = candidates[profile]
            started = time.monotonic()
            print('Rendering audition: ' + profile, flush=True)
            codes = pipe.generate(candidate['text'], language='French',
                instruct=candidate['direction'], max_new_tokens=350,
                seed=1701 + index)
            if len(codes) == 0 or len(codes) >= 350:
                raise ValueError('Generation did not complete normally')
            wav = pipe.decode_chunked(codes[None])
            details = save(wav, folder / (profile + '.wav'))
            metadata_path.write_text(json.dumps({**source, **candidate, **details,
                'approved': False, 'precision': 'int4', 'generated_locally': True,
                'seed': 1701 + index, 'device': args.device,
                'tokenizer_fix_mistral_regex': True}, ensure_ascii=False, indent=2), encoding='utf-8')
            print(profile + ': ready in ' + str(round(time.monotonic()-started)) + 's', flush=True)
            count += 1
        else:
            reference = folder / (profile + '.wav')
            if not metadata_path.exists():
                continue
            metadata = json.loads(metadata_path.read_text(encoding='utf-8'))
            if not metadata.get('approved'):
                continue
            target = ROOT / 'apps/le_loup/assets/audio/classic/neural' / profile
            manifest_path = target / 'manifest.json'
            manifest = json.loads(manifest_path.read_text(encoding='utf-8'))
            lines = json.loads((ROOT / 'tools/audio/voice_profiles.json').read_text(encoding='utf-8'))['lines'][by_id[profile]['edition']]
            extra = json.loads((ROOT / 'tools/audio/neural_profiles.json').read_text(encoding='utf-8')).get('extra_lines', {}).get(profile, {})
            lines = {**lines, **extra}
            for cue, text in lines.items():
                if args.cue and cue != args.cue:
                    continue
                if cue == 'preview' or cue in manifest['cues']:
                    continue
                print('Rendering ' + profile + '/' + cue, flush=True)
                codes = pipe.generate(text, language='French', ref_audio=str(reference),
                    ref_text=metadata['text'], max_new_tokens=350, seed=1701 + count)
                if len(codes) == 0 or len(codes) >= 350:
                    raise ValueError('Generation did not complete normally')
                details = save(pipe.decode_chunked(codes[None]), target / (cue + '.wav'))
                manifest['cues'][cue] = {**details, 'text': text, 'generation': source,
                    'generated_locally': True, 'precision': 'int4'}
                manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding='utf-8')
                print(profile + '/' + cue + ': ready', flush=True)
                count += 1
                if args.limit and count >= args.limit:
                    return
        if args.limit and count >= args.limit:
            return

if __name__ == '__main__':
    main()
