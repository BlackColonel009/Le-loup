"""Publish deterministic, hashed packs; never modify original artwork/audio."""
import hashlib
import json
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
ASSETS = ROOT / 'apps/mordeviel/assets'
OUT = ROOT / 'backend/content/packs'
OUT.mkdir(parents=True, exist_ok=True)
packs = []
voice_labels = {p['id']: p['label'] for p in json.loads((ROOT / 'tools/audio/neural_profiles.json').read_text(encoding='utf-8'))['profiles']}


def pack(pack_id, title, files, kind, theme=None):
    files = sorted(files)
    if not files:
        return
    entries = []
    for path in files:
        digest = hashlib.sha256(path.read_bytes()).hexdigest()
        entries.append({'asset': 'assets/' + path.relative_to(ASSETS).as_posix(), 'size': path.stat().st_size, 'sha256': digest})
    version = hashlib.sha256(json.dumps(entries, sort_keys=True).encode()).hexdigest()[:16]
    target = OUT / pack_id / version
    target.mkdir(parents=True, exist_ok=True)
    for path, entry in zip(files, entries):
        if not (target / entry['sha256']).exists():
            shutil.copyfile(path, target / entry['sha256'])
        entry['url'] = f"/content/packs/{pack_id}/{version}/{entry['sha256']}"
    manifest = {'id': pack_id, 'title': title, 'kind': kind, 'theme': theme,
                'version': version, 'size': sum(e['size'] for e in entries), 'files': entries}
    (target / 'manifest.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding='utf-8')
    packs.append(manifest)


pack('stickers-classic', 'Émotions du village', (ASSETS / 'stickers/classic').glob('*.png'), 'stickers')
for directory in sorted((ASSETS / 'audio/classic/neural').iterdir()):
    if directory.is_dir() and not directory.name.startswith('classic_'):
        pack('voice-' + directory.name.replace('_', '-'), 'Voix · ' + voice_labels.get(directory.name, directory.name),
             (p for p in directory.glob('*.wav') if p.name != 'preview.wav'), 'audio')
for kind, directory in [('cards', 'cards/horror'), ('village', 'village/horror'), ('ambience', 'audio/horror')]:
    pack('horror-' + kind, 'Horreur · ' + {'cards': 'Cartes', 'village': 'Village et sentences', 'ambience': 'Ambiances'}[kind],
         (p for p in (ASSETS / directory).rglob('*') if p.is_file()), kind, 'horror')
(OUT / 'catalog.json').write_text(json.dumps({'packs': packs}, ensure_ascii=False, indent=2), encoding='utf-8')
shared = ROOT / 'shared/content/catalog.json'
shared.parent.mkdir(parents=True, exist_ok=True)
shared.write_text(json.dumps({'packs': packs}, ensure_ascii=False, indent=2), encoding='utf-8')
print(f'{len(packs)} packs publiés, {sum(p["size"] for p in packs)/1048576:.1f} Mio.')
