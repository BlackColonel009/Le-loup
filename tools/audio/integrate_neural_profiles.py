"""Install generated original voices following the user's direct-integration request.

Only existing WAV references are installed. Never invents missing announcements
and never copies historical Windows audio into a neural pack.
"""
import hashlib
import json
from pathlib import Path
import shutil
from sync_neural_assets import main as sync_assets

ROOT = Path(__file__).resolve().parents[2]

def main():
    profiles = json.loads((ROOT / 'tools/audio/neural_profiles.json').read_text(encoding='utf-8'))['profiles']
    for profile in profiles:
        name = profile['id']
        source = ROOT / 'docs/audio-auditions' / (name + '.wav')
        if not source.exists() or not source.with_suffix('.json').exists():
            continue
        metadata = json.loads(source.with_suffix('.json').read_text(encoding='utf-8'))
        metadata['approved'] = True
        metadata['status'] = 'integrated'
        metadata.setdefault('approval_date', '2026-10-26')
        metadata.setdefault('approval_type', 'direct_integration_authorized_by_user')
        source.with_suffix('.json').write_text(json.dumps(metadata, ensure_ascii=False, indent=2), encoding='utf-8')
        folder = ROOT / 'apps/mordeviel/assets/audio/classic/neural' / name
        folder.mkdir(parents=True, exist_ok=True)
        manifest_path = folder / 'manifest.json'
        digest = hashlib.sha256(source.read_bytes()).hexdigest()
        if manifest_path.exists():
            manifest = json.loads(manifest_path.read_text(encoding='utf-8'))
            if manifest['reference_sha256'] != digest:
                raise ValueError('Preserve approved reference: ' + name)
        else:
            manifest = {'source': metadata.get('source', metadata.get('repo')),
                'reference_sha256': digest, 'reference_approved_by_user': True,
                'cues': {'wolves': {'text': metadata['text'], 'sha256': digest}},
                'note': 'Original reference used for preview and wolves call; other cues generated from this reference.'}
            shutil.copyfile(source, folder / 'wolves.wav')
        shutil.copyfile(source, folder / 'preview.wav')
        manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding='utf-8')
    sync_assets()

if __name__ == '__main__':
    main()
