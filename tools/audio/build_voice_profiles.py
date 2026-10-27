"""Construit les voix d'essai et le catalogue Dart à partir des WAV SAPI bruts.
Traitements légers, reproductibles : intelligibilité conservée, crêtes contrôlées.
"""
from pathlib import Path
raise SystemExit('Pipeline Windows/SAPI désactivé. Utiliser audition_neural.py et build_approved_neural.py ; ne pas écraser le catalogue validé.')
import json
import wave
import numpy as np

root = Path(__file__).resolve().parents[2]
catalog = json.loads((Path(__file__).parent / 'voice_profiles.json').read_text(encoding='utf-8'))
assets = root / 'apps/le_loup/assets/audio/classic'
lines = [
    '// Généré par tools/audio/build_voice_profiles.py.',
    'class VoiceProfile {',
    '  const VoiceProfile(this.id, this.label, this.edition, this.description, this.prefix, {this.isApproved = false});',
    '  final String id, label, edition, description, prefix;',
    '  final bool isApproved;',
    "  String assetFor(String cue) => '$prefix$cue';",
    '}',
    'const voiceProfiles = <VoiceProfile>[',
]
for profile in catalog['profiles']:
    identity, effect = profile['id'], profile['effect']
    prefix = '' if identity == 'classic_male' else f'voices/{identity}/'
    output = assets / prefix
    output.mkdir(parents=True, exist_ok=True)
    for cue in catalog['lines'][profile['edition']]:
        source = root / f'.tools/audio/voices_raw/{identity}/{cue}.wav'
        with wave.open(str(source), 'rb') as audio:
            sr = audio.getframerate()
            assert audio.getnchannels() == 1 and audio.getsampwidth() == 2
            dry = np.frombuffer(audio.readframes(audio.getnframes()), '<i2').astype(float)/32768
        t = np.arange(len(dry))/sr
        if effect == 'old':
            dry *= .9 + .08*np.sin(2*np.pi*4.7*t) + .02*np.sin(2*np.pi*11*t)
            f = np.fft.rfftfreq(len(dry), 1/sr)
            dry = np.fft.irfft(np.fft.rfft(dry)*(1-.25*np.exp(-((f-450)/300)**2)), len(dry))
        elif effect == 'beast':
            envelope = np.convolve(abs(dry), np.ones(400)/400, mode='same')
            growl = np.sin(2*np.pi*(77*t + .3*np.sin(t*8)))
            dry = .85*dry + .15*np.tanh(dry*2) + .22*growl*envelope
        elif effect == 'ghost':
            rng = np.random.default_rng(143)
            dry = .94*dry + .04*rng.normal(size=len(dry))*np.sqrt(abs(dry))
        echoes = {'classic':[(.075,.10),(.14,.065),(.23,.035)],
                  'deep':[(.09,.13),(.21,.08),(.36,.045)],
                  'duke':[(.12,.12),(.25,.07)], 'old':[(.08,.06)],
                  'beast':[(.07,.08),(.17,.04)],
                  'ghost':[(.20,.24),(.40,.17),(.66,.10)], 'dry':[]}[effect]
        tail = max([delay for delay, _ in echoes], default=0) + .08
        result = np.pad(dry, (0, round(sr*tail)))
        for delay, gain in echoes:
            offset = round(delay*sr)
            result[offset:offset+len(dry)] += dry*gain
        result *= .65 / max(1e-9, abs(result).max())
        with wave.open(str(output / f'{cue}.wav'), 'wb') as audio:
            audio.setparams((1, 2, sr, 0, 'NONE', 'not compressed'))
            audio.writeframes((result*32767).astype('<i2').tobytes())
    values = [profile[key] for key in ['id','label','edition','description']] + [prefix]
    lines.append('  VoiceProfile(' + ', '.join(json.dumps(v, ensure_ascii=False) for v in values) + '),')
    print(identity, len(catalog['lines'][profile['edition']]), 'fichiers')
lines += ['];', 'VoiceProfile voiceProfileById(String? id) => voiceProfiles.firstWhere((p) => p.id == id, orElse: () => voiceProfiles.first);', '']
(root / 'apps/le_loup/lib/audio/voice_profiles.dart').write_text('\n'.join(lines), encoding='utf-8')
