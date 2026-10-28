"""Expose only real, verified neural cues belonging to user-approved voices."""
import hashlib
import json
from pathlib import Path
import re
import wave

ROOT = Path(__file__).resolve().parents[2]
APP = ROOT / 'apps/mordeviel'

def main():
    catalog_path = APP / 'lib/audio/voice_profiles.dart'
    header = catalog_path.read_text(encoding='utf-8').split('const voiceProfiles = <VoiceProfile>[')[0]
    catalog = [header.rstrip(), '', 'const voiceProfiles = <VoiceProfile>[']
    declarations = []
    profiles = json.loads((ROOT / 'tools/audio/neural_profiles.json').read_text(encoding='utf-8'))['profiles']
    for info in profiles:
        profile = info['id']
        reference = ROOT / 'docs/audio-auditions' / (profile + '.wav')
        metadata = json.loads(reference.with_suffix('.json').read_text(encoding='utf-8')) if reference.with_suffix('.json').exists() else {}
        folder = APP / 'assets/audio/classic/neural' / profile
        approved = metadata.get('approved') is True and (folder / 'manifest.json').exists()
        cues = set()
        if approved:
            cues = verify_profile(reference, folder)
        prefix = 'neural/' + profile + '/'
        values = [info['id'], info['label'], info['edition'], info['description'], prefix]
        catalog.append('  VoiceProfile(' + ', '.join(json.dumps(v, ensure_ascii=False) for v in values) + ',')
        catalog.append('    isApproved: ' + str(approved).lower() + ',')
        catalog.append('    availableCues: {' + ', '.join("'" + c + "'" for c in sorted(cues)) + '},')
        catalog.append('  ),')
        declarations.extend('    - assets/audio/classic/' + prefix + cue for cue in sorted(cues) if profile.startswith('classic_') or cue == 'preview.wav')
    catalog.extend(['];', 'VoiceProfile voiceProfileById(String? id) => voiceProfiles.firstWhere(',
                    '  (p) => p.id == id, orElse: () => voiceProfiles.first,', ');', ''])
    pubspec_path = APP / 'pubspec.yaml'
    pubspec = pubspec_path.read_text(encoding='utf-8')
    pubspec, count = re.subn(r'(?:    - assets/audio/classic/neural/[^\n]+\n)+', '\n'.join(declarations) + '\n', pubspec)
    if count != 1:
        raise ValueError('Unexpected pubspec structure')
    # All inputs validated before changing application metadata.
    catalog_path.write_text('\n'.join(catalog), encoding='utf-8')
    pubspec_path.write_text(pubspec, encoding='utf-8')
    print('Verified and declared ' + str(len(declarations)) + ' neural assets.')

def verify_profile(reference, folder):
        manifest = json.loads((folder / 'manifest.json').read_text(encoding='utf-8'))
        if hashlib.sha256(reference.read_bytes()).hexdigest() != manifest['reference_sha256']:
            raise ValueError('Reference changed: ' + reference.stem)
        cues = {'preview.wav'}
        for cue, info in manifest['cues'].items():
            path = folder / (cue + '.wav')
            if not re.fullmatch('[a-z_]+', cue) or hashlib.sha256(path.read_bytes()).hexdigest() != info['sha256']:
                raise ValueError('Cue integrity failure: ' + cue)
            with wave.open(str(path)) as audio:
                if audio.getframerate() != 24000 or audio.getnchannels() != 1:
                    raise ValueError('Unexpected cue format')
            cues.add(cue + '.wav')
        if (folder / 'preview.wav').read_bytes() != reference.read_bytes():
            raise ValueError('Preview changed: ' + reference.stem)
        return cues

if __name__ == '__main__':
    main()
