"""Download only the pinned ONNX components needed for account-free local TTS.

Dependencies live in .tools/audio/qwen_onnx/.venv; models in the same ignored
directory. No application build or global Python configuration is changed.
"""
import argparse
from concurrent.futures import ThreadPoolExecutor
import hashlib
import json
import os
from pathlib import Path
import urllib.request

ROOT = Path(__file__).resolve().parents[2] / '.tools/audio/qwen_onnx'

def read(url):
    with urllib.request.urlopen(url, timeout=60) as response:
        return response.read()

def download(repo, revision, entry, target):
    expected = entry.get('lfs', {}).get('oid')
    if target.exists() and target.stat().st_size == entry['size']:
        if not expected or hashlib.sha256(target.read_bytes()).hexdigest() == expected:
            print('Verified ' + target.name, flush=True)
            return
    if expected and not target.exists():
        for other in ROOT.glob('*/cpu_int4/' + target.name):
            if other != target and other.stat().st_size == entry['size']:
                with other.open('rb') as existing:
                    digest = hashlib.file_digest(existing, 'sha256').hexdigest()
                if digest == expected:
                    os.link(other, target)
                    print('Reused verified ' + target.name, flush=True)
                    return
    print('Downloading ' + target.name + ' (' + str(round(entry['size'] / 1e6)) + ' MB)', flush=True)
    partial = target.with_suffix(target.suffix + '.part')
    digest = hashlib.sha256()
    offset = partial.stat().st_size if partial.exists() else 0
    headers = {'Range': f'bytes={offset}-'} if offset else {}
    url = 'https://huggingface.co/' + repo + '/resolve/' + revision + '/' + entry['path']
    with urllib.request.urlopen(urllib.request.Request(url, headers=headers), timeout=60) as response:
        resume = offset > 0 and response.status == 206
        if resume:
            with partial.open('rb') as existing:
                while chunk := existing.read(1024 * 1024):
                    digest.update(chunk)
        else:
            offset = 0
        total, reported = offset, offset // (64 * 1024 * 1024)
        with partial.open('ab' if resume else 'wb') as output:
            while chunk := response.read(1024 * 1024):
                digest.update(chunk)
                output.write(chunk)
                total += len(chunk)
                if total // (64 * 1024 * 1024) > reported:
                    reported = total // (64 * 1024 * 1024)
                    print(target.name + ': ' + str(round(total / 1e6)) + ' MB', flush=True)
    if partial.stat().st_size != entry['size'] or expected and digest.hexdigest() != expected:
        raise ValueError('Download integrity failure: ' + target.name)
    partial.replace(target)
    print('Ready ' + target.name, flush=True)

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('kind', choices=['design', 'base'])
    args = parser.parse_args()
    model = 'Qwen3-TTS-12Hz-1.7B-' + ('VoiceDesign' if args.kind == 'design' else 'Base')
    repo = 'onnx-community/' + model
    revision = json.loads(read('https://huggingface.co/api/models/' + repo))['sha']
    folder = ROOT / args.kind
    onnx = folder / 'cpu_int4'
    onnx.mkdir(parents=True, exist_ok=True)
    prefix = 'https://huggingface.co/' + repo + '/raw/' + revision + '/'
    manifest = json.loads(read(prefix + 'cpu_int4/manifest.json'))
    if 'talker_cache' in manifest['sub_models']:
        manifest['sub_models'].pop('talker', None)
    if args.kind == 'design':
        manifest['sub_models'].pop('tok_encoder', None)
    filenames = {m['filename'] for m in manifest['sub_models'].values()}
    if any(Path(name).name != name or not name.endswith('.onnx') for name in filenames):
        raise ValueError('Unexpected manifest filenames')
    entries = json.loads(read('https://huggingface.co/api/models/' + repo + '/tree/' + revision + '/cpu_int4'))
    jobs = [e for e in entries if Path(e['path']).name in filenames]
    if len(jobs) != len(filenames):
        raise ValueError('Missing model components')
    with ThreadPoolExecutor(max_workers=3) as pool:
        futures = [pool.submit(download, repo, revision, entry, onnx / Path(entry['path']).name) for entry in jobs]
        for future in futures:
            future.result()
    (onnx / 'manifest.json').write_text(json.dumps(manifest, indent=2), encoding='utf-8')
    original = 'Qwen/' + model
    original_revision = json.loads(read('https://huggingface.co/api/models/' + original))['sha']
    listing = json.loads(read('https://huggingface.co/api/models/' + original + '/tree/' + original_revision))
    for entry in listing:
        if entry['path'] in ('config.json', 'tokenizer_config.json', 'tokenizer.json', 'vocab.json', 'merges.txt', 'LICENSE'):
            download(original, original_revision, entry, folder / entry['path'])
    source_code = read(prefix + 'inference.py').decode('utf-8')
    source_code = source_code.replace('trust_remote_code=True', 'trust_remote_code=False, local_files_only=True')
    source_code = source_code.replace('so.log_severity_level = 3', 'so.log_severity_level = 3\n        so.intra_op_num_threads = 8\n        so.inter_op_num_threads = 1')
    source_code = source_code.replace('so, providers=[prov])', 'so, providers=[prov], provider_options=[self.manifest.get("provider_options", {})])')
    (ROOT / 'inference.py').write_text(source_code, encoding='utf-8')
    (folder / 'source.json').write_text(json.dumps({'repo': repo, 'revision': revision,
        'tokenizer_repo': original, 'tokenizer_revision': original_revision,
        'local_changes': ['disable remote code', 'limit CPU threads to eight', 'omit unused design encoder']}, indent=2), encoding='utf-8')
    print('Local ' + args.kind + ' model ready.', flush=True)

if __name__ == '__main__':
    main()
