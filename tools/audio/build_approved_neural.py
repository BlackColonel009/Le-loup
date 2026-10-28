"""Render game cues from the three original, user-approved neural references.

Uses the official public Gradio endpoint. Stops on service errors and resumes
from verified outputs; never substitutes Windows speech or a different voice.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import urllib.request
import uuid
import wave

ROOT = Path(__file__).resolve().parents[2]
BASE = 'https://qwen-qwen3-tts.hf.space'
PROFILES = ('werewolf', 'ghost', 'old_wizard')
OUT = ROOT / 'apps/mordeviel/assets/audio/classic/neural'

def request(path, data=None, headers=None):
    headers = dict(headers or {})
    if os.environ.get('HF_TOKEN'):
        headers['Authorization'] = 'Bearer ' + os.environ['HF_TOKEN']
    return urllib.request.urlopen(urllib.request.Request(
        BASE + path, data=data, headers=headers), timeout=60)

def upload(path):
    boundary = uuid.uuid4().hex
    body = (f'--{boundary}\r\nContent-Disposition: form-data; name="files"; '
            f'filename="{path.name}"\r\nContent-Type: audio/wav\r\n\r\n').encode()
    body += path.read_bytes() + f'\r\n--{boundary}--\r\n'.encode()
    with request('/gradio_api/upload', body,
                 {'Content-Type': 'multipart/form-data; boundary=' + boundary}) as response:
        return json.load(response)[0]

def generate(reference, transcript, text):
    data = [{'path': reference, 'meta': {'_type': 'gradio.FileData'}},
            transcript, text, 'French', False, '1.7B']
    with request('/gradio_api/call/generate_voice_clone',
                 json.dumps({'data': data}).encode(),
                 {'Content-Type': 'application/json'}) as response:
        event = json.load(response)['event_id']
    with request('/gradio_api/call/generate_voice_clone/' + event) as response:
        kind = ''
        for raw in response:
            line = raw.decode().strip()
            if line.startswith('event: '):
                kind = line[7:]
            elif line.startswith('data: ') and kind == 'error':
                raise RuntimeError('Public Qwen service error: ' + line[6:])
            elif line.startswith('data: ') and kind == 'complete':
                result = json.loads(line[6:])
                if not result[0]:
                    raise RuntimeError(str(result[1:]))
                return result[0].get('url') or BASE + '/gradio_api/file=' + result[0]['path']
    raise RuntimeError('No audio returned')

def validate(path):
    with wave.open(str(path)) as audio:
        seconds = audio.getnframes() / audio.getframerate()
        if audio.getnchannels() != 1 or audio.getsampwidth() != 2 or not 0.4 < seconds < 35:
            raise ValueError('Unexpected audio format or duration: ' + str(path))
        return round(seconds, 3)

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--profile', choices=PROFILES)
    args = parser.parse_args()
    lines = json.loads((ROOT / 'tools/audio/voice_profiles.json').read_text(encoding='utf-8'))['lines']['Horreur']
    for profile in ([args.profile] if args.profile else PROFILES):
        source = ROOT / 'docs/audio-auditions' / (profile + '.wav')
        metadata = json.loads(source.with_suffix('.json').read_text(encoding='utf-8'))
        target = OUT / profile
        target.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source, target / 'preview.wav')
        manifest_path = target / 'manifest.json'
        manifest = json.loads(manifest_path.read_text(encoding='utf-8')) if manifest_path.exists() else {
            'source': BASE, 'model': 'Qwen3-TTS-12Hz-1.7B-Base',
            'reference_sha256': hashlib.sha256(source.read_bytes()).hexdigest(),
            'reference_approved_by_user': True, 'cues': {}}
        reference = None
        for cue, text in lines.items():
            if cue == 'preview':
                continue
            output = target / (cue + '.wav')
            if output.exists() and cue in manifest['cues']:
                validate(output)
                continue
            if reference is None:
                reference = upload(source)
            print(profile + '/' + cue + ': generating', flush=True)
            url = generate(reference, metadata['text'], text)
            temporary = target / (cue + '.pending.wav')
            urllib.request.urlretrieve(url, temporary)
            seconds = validate(temporary)
            temporary.replace(output)
            manifest['cues'][cue] = {'text': text, 'seconds': seconds,
                                    'sha256': hashlib.sha256(output.read_bytes()).hexdigest()}
            manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding='utf-8')
            print(profile + '/' + cue + ': ready', flush=True)

if __name__ == '__main__':
    main()
