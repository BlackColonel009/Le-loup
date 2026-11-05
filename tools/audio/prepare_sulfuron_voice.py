"""Original French imp voice using the project's installed local Qwen models."""
import gc
import json
from pathlib import Path

from local_neural import RUNTIME, Pipeline, save
from transformers import AutoTokenizer

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'apps/mordeviel/assets/audio/classic/characters/sulfuron'
LINES = {
    'bluff': 'Vous serez désorientés, mais vous ne me trouverez pas. Héhéhé !',
    'reveal': 'Un petit mouton conduit à l’abattoir… héhéhé !',
    'revive': 'Vous croyiez en avoir fini avec moi ? Encore une petite vie… héhéhé !',
    'death': 'Vous m’avez trouvé… mais qui rira le dernier ?',
    'ended': 'Vous avez chassé les loups… et livré le village au Fourbe. Héhéhé !',
}
DIRECTION = ('Native French male adult imp disguised as an ordinary villager. A nimble light tenor, '
             'slightly nasal and lightly raspy, sly cunning goblin-like charm with a smiling mischievous '
             'voice, quick playful inflections, secretive pauses and a short natural impish chuckle. '
             'Clearly intelligible expressive French character acting. Not a child, no shouting, '
             'no monstrous growl, no robotic or flat delivery, no singing.')


def load(kind):
    model = RUNTIME / kind
    print('Loading local ' + kind + ' model...', flush=True)
    pipe = Pipeline(str(model / 'cpu_int4'), tts_dir=str(model))
    pipe._tok = AutoTokenizer.from_pretrained(str(model), trust_remote_code=False,
        local_files_only=True, fix_mistral_regex=True)
    return pipe


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    manifest_path = OUT / 'manifest.json'
    manifest = json.loads(manifest_path.read_text(encoding='utf-8')) if manifest_path.exists() else {
        'id': 'sulfuron', 'engine': 'Qwen3-TTS local ONNX', 'direction': DIRECTION, 'cues': {}}
    preview = OUT / 'preview.wav'
    if not preview.exists():
        pipe = load('design')
        text = LINES['bluff']
        print('Designing Sulfuron’s original voice...', flush=True)
        codes = pipe.generate(text, language='French', instruct=DIRECTION, max_new_tokens=260, seed=5112026)
        if not 0 < len(codes) < 260:
            raise ValueError('Voice design did not finish normally')
        details = save(pipe.decode_chunked(codes[None]), preview)
        manifest['reference_text'] = text
        manifest['reference'] = details
        manifest_path.write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
        del pipe
        gc.collect()
    pipe = None
    for index,(cue,text) in enumerate(LINES.items()):
        if cue in manifest['cues'] and (OUT / (cue+'.wav')).exists():
            continue
        if cue == 'bluff':
            import shutil
            shutil.copyfile(preview, OUT / (cue+'.wav'))
            manifest['cues'][cue] = {**manifest['reference'], 'text': text}
        else:
            if pipe is None: pipe = load('base')
            print('Rendering Sulfuron/' + cue, flush=True)
            codes = pipe.generate(text,language='French',ref_audio=str(preview),
                ref_text=manifest['reference_text'], max_new_tokens=260,seed=5112027+index)
            if not 0 < len(codes) < 260:
                raise ValueError('Voice generation did not finish normally: '+cue)
            manifest['cues'][cue] = {**save(pipe.decode_chunked(codes[None]), OUT / (cue+'.wav')), 'text':text}
        manifest_path.write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
        print(cue + ': ready',flush=True)


if __name__=='__main__': main()
