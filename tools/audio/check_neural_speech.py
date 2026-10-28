"""Local transcription checks; reports content differences, not acting quality."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import unicodedata

from setup_local_neural import download, read

ROOT = Path(__file__).resolve().parents[2]
MODEL = ROOT / '.tools/audio/qwen_onnx/asr'

def words(text):
    return re.findall('[a-z]+', ''.join(c for c in unicodedata.normalize('NFD', text.lower())
                                      if unicodedata.category(c) != 'Mn'))

def word_error(expected, actual):
    left, right = words(expected), words(actual)
    previous = list(range(len(right) + 1))
    for i, a in enumerate(left, 1):
        current = [i]
        for j, b in enumerate(right, 1):
            current.append(min(current[-1] + 1, previous[j] + 1, previous[j-1] + (a != b)))
        previous = current
    return round(previous[-1] / max(len(left), 1), 3)

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--fetch', action='store_true')
    parser.add_argument('--pack', action='store_true')
    parser.add_argument('--events', action='store_true', help='Check only extra character/event lines')
    parser.add_argument('--narration', action='store_true', help='Check only shared MDJ announcements')
    parser.add_argument('--profile', help='Limit transcription to one voice profile')
    parser.add_argument('--resume', action='store_true', help='Keep unchanged files already transcribed')
    args = parser.parse_args()
    if args.fetch:
        repo = 'Systran/faster-whisper-base'
        revision = json.loads(read('https://huggingface.co/api/models/' + repo))['sha']
        entries = json.loads(read('https://huggingface.co/api/models/' + repo + '/tree/' + revision))
        MODEL.mkdir(exist_ok=True)
        for entry in entries:
            if entry['path'] in ['config.json', 'model.bin', 'tokenizer.json', 'vocabulary.json', 'vocabulary.txt', 'preprocessor_config.json']:
                download(repo, revision, entry, MODEL / entry['path'])
        (MODEL / 'source.json').write_text(json.dumps({'repo': repo, 'revision': revision}), encoding='utf-8')
        return
    from faster_whisper import WhisperModel
    import soundfile as sf
    from scipy.signal import resample_poly
    from math import gcd
    model = WhisperModel(str(MODEL), device='cpu', compute_type='int8', cpu_threads=4, local_files_only=True)
    tasks = []
    if args.pack:
        extra = json.loads((ROOT / 'tools/audio/neural_profiles.json').read_text(encoding='utf-8')).get('extra_lines', {})
        for manifest_path in (ROOT / 'apps/mordeviel/assets/audio/classic/neural').glob('*/manifest.json'):
            if args.profile and manifest_path.parent.name != args.profile: continue
            manifest = json.loads(manifest_path.read_text(encoding='utf-8'))
            tasks.extend((manifest_path.parent / (cue + '.wav'), info['text']) for cue, info in manifest['cues'].items()
                         if (not args.events or cue in extra.get(manifest_path.parent.name, {}))
                         and (not args.narration or cue.startswith('mdj_')))
    else:
        for audio in (ROOT / 'docs/audio-auditions').glob('*.wav'):
            metadata = json.loads(audio.with_suffix('.json').read_text(encoding='utf-8'))
            tasks.append((audio, metadata['text']))
    output = ROOT / 'docs/audio-auditions' / ('narration-transcription-checks.json' if args.narration else 'events-transcription-checks.json' if args.events else 'pack-transcription-checks.json' if args.pack else 'transcription-checks.json')
    cached = {}
    if args.resume and output.exists():
        cached = {entry['file']: entry for entry in json.loads(output.read_text(encoding='utf-8'))['files']}
    report = []
    for path, expected in tasks:
        identity = str(path.relative_to(ROOT))
        digest = hashlib.sha256(path.read_bytes()).hexdigest()
        previous = cached.get(identity)
        if previous and previous.get('sha256') == digest and previous['expected'] == expected:
            report.append(previous)
            continue
        audio, sample_rate = sf.read(str(path), dtype='float32')
        if audio.ndim > 1:
            audio = audio.mean(axis=1)
        common = gcd(sample_rate, 16000)
        audio = resample_poly(audio, 16000 // common, sample_rate // common)
        segments, _ = model.transcribe(audio, language='fr', beam_size=5, temperature=0,
            condition_on_previous_text=False, vad_filter=False)
        actual = ' '.join(s.text.strip() for s in segments)
        entry = {'file': str(path.relative_to(ROOT)), 'expected': expected,
                 'transcribed': actual, 'word_error_rate': word_error(expected, actual), 'sha256': digest}
        report.append(entry)
        print(path.parent.name + '/' + path.name + ': ' + str(entry['word_error_rate']) + ' | ' + actual, flush=True)
    output.write_text(json.dumps({'method': 'faster-whisper base, CPU int8, French',
        'note': 'ASR can mishear character voices; this is not a listening approval.',
        'files': report}, ensure_ascii=False, indent=2), encoding='utf-8')

if __name__ == '__main__':
    main()
