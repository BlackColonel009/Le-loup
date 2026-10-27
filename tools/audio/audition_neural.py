"""Generate an original character audition through Qwen's public Gradio API.

No Windows TTS, actor recording, credential or paid API is used.
Outputs are auditions only; they do not replace approved application assets.
"""
import argparse
import json
import os
from pathlib import Path
import urllib.request

BASE = 'https://qwen-qwen3-tts.hf.space'
PROFILES = {
    'werewolf': 'Native French male werewolf character. Very deep chest resonance, rough gravelly throat, controlled animal growl woven into clearly intelligible speech. Predatory, commanding, dangerous. Natural dramatic acting, measured pauses, no robotic cadence. Do not sing or howl over the words.',
    'ghost': 'Native French female ghost character. Airy fragile whisper with an eerie distant presence, breath between phrases, restrained haunting sadness, unsettling intimate delivery. Natural expressive acting, every French word remains intelligible. No singing.',
    'old_wizard': 'Native French elderly male sorcerer, eighty years old. Weathered cracked baritone, dry textured throat, slight age tremor, slow knowing delivery, dark mischievous authority. Expressive theatrical storytelling with natural pauses, never robotic or cartoonishly high pitched.',
    'old_witch': 'Native French elderly female witch, eighty years old. Croaky raspy aged contralto, sly ominous smile audible in her voice, slightly irregular breath, deliberate chilling delivery. Natural character acting, precise clear French, no exaggerated screeching.',
    'classic_male': 'Native French male storyteller, warm living baritone, inviting and mysterious. Calm adventure narration, subtle suspense, expressive phrasing and natural breath. Clear diction without announcer stiffness.',
    'classic_female': 'Native French female storyteller, warm rich mid register, lively subtle expression. Calm mysterious adventure narration, natural breathing, clear intimate diction, never flat or robotic.',
    'intense_male': 'Native French male dramatic narrator, rich deep bass baritone, tense contained power, cinematic suspense, deliberate pauses and natural emotional phrasing. Clear words, no shouting.',
    'intense_female': 'Native French female dramatic narrator, dark resonant contralto, intense restrained suspense, confident velvety presence, varied natural phrasing and deliberate pauses.',
    'duke': 'Native French older male medieval duke. Aristocratic rounded baritone, dignified royal authority, precise elegant diction, solemn measured cadence with expressive disdain and natural breathing. No parody accent.',
    'cold_killer': 'Native French adult male thriller antagonist. Quiet low intimate voice, unnervingly controlled, dry and emotionally cold, restrained menace, short deliberate pauses. Natural human phrasing, no growling or shouting.',
}

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('profile', choices=PROFILES)
    args = parser.parse_args()
    output = Path(__file__).resolve().parents[2] / 'docs' / 'audio-auditions'
    existing = output / (args.profile + '.json')
    if existing.exists() and json.loads(existing.read_text(encoding='utf-8')).get('approved'):
        raise SystemExit('This voice is approved: preserve its original reference. Use build_approved_neural.py for game cues.')
    text = 'Le village s’endort… Loups-garous, réveillez-vous. Quelle sera votre victime ?'
    headers = {'Content-Type': 'application/json'}
    if os.environ.get('HF_TOKEN'):
        headers['Authorization'] = 'Bearer ' + os.environ['HF_TOKEN']
    request = urllib.request.Request(
        BASE + '/gradio_api/call/generate_voice_design',
        data=json.dumps({'data': [text, 'French', PROFILES[args.profile]]}).encode(),
        headers=headers)
    with urllib.request.urlopen(request, timeout=45) as response:
        event = json.load(response)['event_id']
    print('Generation queued: ' + event, flush=True)
    event_request = urllib.request.Request(
        BASE + '/gradio_api/call/generate_voice_design/' + event,
        headers={k: v for k, v in headers.items() if k == 'Authorization'})
    with urllib.request.urlopen(event_request, timeout=60) as response:
        event_type = ''
        for raw in response:
            line = raw.decode().strip()
            if line.startswith('event: '):
                event_type = line[7:]
            if not line.startswith('data: '):
                continue
            if event_type == 'error':
                raise RuntimeError(line[6:])
            if event_type != 'complete':
                continue
            result = json.loads(line[6:])
            if not result[0]:
                raise RuntimeError(str(result[1:]))
            output.mkdir(parents=True, exist_ok=True)
            url = result[0].get('url') or BASE + '/gradio_api/file=' + result[0]['path']
            urllib.request.urlretrieve(url, output / (args.profile + '.wav'))
            (output / (args.profile + '.json')).write_text(json.dumps({
                'model': 'Qwen3-TTS-12Hz-1.7B-VoiceDesign', 'source': BASE,
                'text': text, 'direction': PROFILES[args.profile],
                'approved': False, 'status': result[1:]}, ensure_ascii=False, indent=2), encoding='utf-8')
            print(output / (args.profile + '.wav'))
            return
    raise RuntimeError('No completed audio returned')

if __name__ == '__main__':
    main()
