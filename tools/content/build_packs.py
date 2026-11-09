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


def pack(pack_id, title, files, kind, theme=None, asset_prefix=None):
    files = sorted(files)
    if not files:
        return
    entries = []
    for path in files:
        digest = hashlib.sha256(path.read_bytes()).hexdigest()
        asset = asset_prefix + path.name if asset_prefix else 'assets/' + path.relative_to(ASSETS).as_posix()
        entries.append({'asset': asset, 'size': path.stat().st_size, 'sha256': digest})
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
pack('victory-poses', 'Victoires · Poses des personnages',
     (ASSETS / 'chibis/victory').glob('*.png'), 'illustrations')
pack('stickers-rewards', 'Curiosités du village · Stickers à collectionner', (ASSETS / 'stickers/rewards').glob('*.png'), 'stickers')
avatars = json.loads((ROOT / 'shared/avatars/catalog.json').read_text(encoding='utf-8'))['avatars']
pack('avatars-classic', 'Visages du village · Classique',
     ((ROOT / 'shared/avatars/artwork' if a.get('source_root') == 'avatars' else ASSETS / 'cards') / a['source']
      for a in avatars if a['pack_id'] == 'avatars-classic'), 'avatars', 'classic', 'assets/avatars/classic/')
pack('avatars-rewards', 'Médaillons de légende · Profils à gagner',
     (ROOT / 'shared/avatars/rewards/portraits').glob('*.png'), 'avatars', 'rewards', 'assets/avatars/rewards/')
pack('borders-rewards', 'Cadres de légende · Bordures à gagner',
     (ROOT / 'shared/avatars/rewards/borders').glob('*.png'), 'borders', 'rewards', 'assets/borders/rewards/')
for directory in sorted((ASSETS / 'audio/classic/neural').iterdir()):
    if directory.is_dir() and not directory.name.startswith('classic_'):
        pack('voice-' + directory.name.replace('_', '-'), 'Voix · ' + voice_labels.get(directory.name, directory.name),
             (p for p in directory.glob('*.wav') if p.name != 'preview.wav'), 'audio')
pack('intense-cards', 'Intense · Cartes',
     (p for p in (ASSETS / 'cards/intense').rglob('*') if p.is_file()), 'cards', 'intense')
devour_videos = {ASSETS / 'village/horror' / name
                 for name in ('wolf_devour_clean.mp4', 'white_wolf_devour_clean.mp4')}
legacy_devour = {ASSETS / 'village/horror' / name
                for name in ('wolf_devour.mp4', 'white_wolf_devour.mp4')}
pack('horror-devour', 'Horreur · Vidéos de dévoration',
     (p for p in devour_videos if p.is_file()), 'video', 'horror')
for kind, directory in [('cards', 'cards/horror'), ('village', 'village/horror'), ('ambience', 'audio/horror')]:
    pack('horror-' + kind, 'Horreur · ' + {'cards': 'Cartes', 'village': 'Village et sentences', 'ambience': 'Ambiances'}[kind],
         (p for p in (ASSETS / directory).rglob('*')
          if p.is_file() and p not in devour_videos and p not in legacy_devour), kind, 'horror')
(OUT / 'catalog.json').write_text(json.dumps({'packs': packs}, ensure_ascii=False, indent=2), encoding='utf-8')
shared = ROOT / 'shared/content/catalog.json'
shared.parent.mkdir(parents=True, exist_ok=True)
shared.write_text(json.dumps({'packs': packs}, ensure_ascii=False, indent=2), encoding='utf-8')
print(f'{len(packs)} packs publiés, {sum(p["size"] for p in packs)/1048576:.1f} Mio.')
