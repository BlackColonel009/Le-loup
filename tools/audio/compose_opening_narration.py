"""Mix the Qwen opening, export portrait MP4, optionally install its native asset.

The supplied film already contains inseparable mono narration. Replace that
track with the game's original instrumental and cloth/claw effects, not a second
overlapping voice. Source pixels are kept apart from its burned-in subtitle band.
Run with the local Qwen Python after create_opening_voice.py.
"""
import argparse
import hashlib
import json
import shutil
import subprocess
from pathlib import Path

import numpy as np
import soundfile as sf
from scipy import ndimage

ROOT = Path(__file__).resolve().parents[2]
WORK = ROOT / '.tmp/audio/opening-qwen'
EXPORT = ROOT / 'exports/intro-mordeviel'
RATE = 48000
DURATION = 10.0


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def decode(ffmpeg, path, filters=None):
    command = [ffmpeg, '-v', 'error', '-i', str(path)]
    if filters:
        command += ['-af', filters]
    command += ['-f', 'f32le', '-ac', '2', '-ar', str(RATE), '-']
    raw = subprocess.run(command, capture_output=True, check=True).stdout
    return np.frombuffer(raw, dtype=np.float32).reshape(-1, 2).copy()


def trim(audio):
    power = np.mean(audio ** 2, axis=1)
    smooth = np.convolve(power, np.ones(960) / 960, mode='same')
    active = np.flatnonzero(smooth > max(.000004, float(smooth.max()) * .002))
    if not len(active):
        raise ValueError('A voice take is silent.')
    return audio[max(0, active[0] - 2200):min(len(audio), active[-1] + 6000)]


def clean_subtitles(ffmpeg, source):
    """Fill just the cream letters and their outlines, keeping the scenery crisp."""
    target = WORK / f'clean-letters-v2-{digest(source)[:12]}.mkv'
    if target.exists():
        return target
    decoder = subprocess.Popen([ffmpeg, '-v', 'error', '-i', str(source),
        '-map', '0:v:0', '-f', 'rawvideo', '-pix_fmt', 'rgb24', '-'], stdout=subprocess.PIPE)
    encoder = subprocess.Popen([ffmpeg, '-v', 'error', '-y', '-f', 'rawvideo',
        '-pix_fmt', 'rgb24', '-s', '720x1280', '-r', '24', '-i', '-',
        '-c:v', 'ffv1', '-level', '3', '-pix_fmt', 'bgr0', '-threads', '4', str(target)],
        stdin=subprocess.PIPE)
    frame_size = 720 * 1280 * 3
    count = 0
    try:
        while True:
            raw = decoder.stdout.read(frame_size)
            if not raw:
                break
            if len(raw) != frame_size:
                raise ValueError('Incomplete source video frame.')
            image = np.frombuffer(raw, dtype=np.uint8).reshape(1280, 720, 3).copy()
            time = count / 24
            left, right = ((73, 647) if 3 <= time <= 5.6 else
                           (173, 549) if 6.3 <= time <= 9.65 else (0, 0))
            if right:
                region = image[934:983, left:right]
                colors = region.astype(np.float32)
                red, green, blue = colors.transpose(2, 0, 1)
                letters = (red > 170) & (green > 150) & (blue > 110) & (green > red * .86) & (blue > red * .65)
                mask = ndimage.binary_fill_holes(ndimage.binary_dilation(letters, iterations=8))
                if mask.any() and not mask.all():
                    indices = ndimage.distance_transform_edt(mask, return_distances=False, return_indices=True)
                    filled = ndimage.gaussian_filter(colors[tuple(indices)], sigma=(1.2, 1.2, 0))
                    feather = ndimage.gaussian_filter(mask.astype(np.float32), sigma=.65)[:, :, None]
                    region[:] = np.clip(filled * feather + colors * (1 - feather), 0, 255).astype(np.uint8)
            encoder.stdin.write(image.tobytes())
            count += 1
        encoder.stdin.close()
        decoder.stdout.close()
        if decoder.wait() or encoder.wait() or count != 240:
            raise ValueError('Video cleanup did not finish correctly.')
    except BaseException:
        decoder.kill()
        encoder.kill()
        target.unlink(missing_ok=True)
        raise
    print('Source subtitles removed with a local letter mask.', flush=True)
    return target


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path, required=True)
    parser.add_argument('--ffmpeg', required=True)
    parser.add_argument('--apply', action='store_true')
    args = parser.parse_args()
    source = args.source.resolve()
    if not source.is_file():
        raise ValueError('The supplied video is missing.')
    EXPORT.mkdir(parents=True, exist_ok=True)
    voice_info = json.loads((WORK / 'voice.json').read_text(encoding='utf-8'))
    treatments = (
        'highpass=f=75,lowpass=f=10000,'
        'equalizer=f=2800:t=q:w=1:g=1.5,'
        'loudnorm=I=-17:TP=-2:LRA=7,'
        'aecho=0.9:0.95:72|145:0.11|0.045'
    )
    welcome = trim(decode(args.ffmpeg, WORK / 'welcome.wav', treatments))
    threat = trim(decode(args.ffmpeg, WORK / 'threat.wav', 'atempo=0.94,' + treatments))
    pause = .72
    voice = np.concatenate([welcome, np.zeros((round(RATE * pause), 2)), threat])
    voice_duration = len(voice) / RATE
    start = min(3.2, 9.45 - voice_duration)
    if start < 2.1:
        raise ValueError('Voice would not fit naturally in the supplied film.')
    finish = start + voice_duration
    samples = round(DURATION * RATE)
    times = np.arange(samples) / RATE
    classic = ROOT / 'apps/mordeviel/assets/audio/classic'
    music = decode(args.ffmpeg, classic / 'moonlit_village.wav')
    if len(music) < samples:
        music = np.tile(music, (int(np.ceil(samples / len(music))), 1))
    music = music[:samples]
    music *= .15 / max(.001, float(np.max(np.abs(music))))
    # Smooth attenuation under speech, with a gentle recovery after the last word.
    envelope = np.interp(times, [0, .65, start - .25, start + .06,
        finish - .08, finish + .3, DURATION - .18, DURATION],
        [0, 1, 1, .24, .24, 1, 1, 0])
    mix = music * envelope[:, None]

    def overlay(audio, onset, gain):
        offset = round(onset * RATE)
        size = min(len(audio), samples - offset)
        mix[offset:offset + size] += audio[:size] * gain

    for name, onset, gain in [('claw_1.wav', 1.12, .49),
                              ('claw_2.wav', 1.78, .49),
                              ('curtain_tear.wav', 4.5, .16)]:
        fx = decode(args.ffmpeg, classic / name)
        overlay(fx, onset, gain)
    overlay(voice, start, .95)
    peak = float(np.max(np.abs(mix)))
    mix *= min(1, .93 / max(.001, peak))
    master = WORK / 'opening-mix.wav'
    sf.write(master, mix, RATE, subtype='PCM_24')
    voice_export = EXPORT / 'voix-qwen-intense.wav'
    sf.write(voice_export, voice, RATE, subtype='PCM_16')
    # Existing subtitles are burned into the input, not a separate subtitle track.
    clean = clean_subtitles(args.ffmpeg, source)
    outputs = [(EXPORT / 'mordeviel-intro-qwen-1080x1920.mp4', 1080, 1920, '20'),
               (WORK / 'intro-app.mp4', 720, 1280, '21')]
    for output, width, height, quality in outputs:
        command = [args.ffmpeg, '-v', 'error', '-y', '-i', str(clean), '-i', str(master),
            '-map', '0:v:0', '-map', '1:a:0', '-vf',
            f'scale={width}:{height}:flags=lanczos,setsar=1',
            '-c:v', 'libx264', '-preset', 'medium', '-crf', quality,
            '-profile:v', 'high', '-level:v', '4.0', '-pix_fmt', 'yuv420p', '-threads', '4',
            '-c:a', 'aac', '-b:a', '192k', '-ar', str(RATE), '-ac', '2',
            '-t', str(DURATION), '-movflags', '+faststart', '-map_metadata', '-1', str(output)]
        subprocess.run(command, check=True)
        print(f'Ready: {output.name} ({output.stat().st_size / 1048576:.2f} MiB)', flush=True)
    exported = outputs[0][0]
    native = outputs[1][0]
    metadata = {
        'source_filename': source.name, 'source_sha256': digest(source),
        'text': voice_info['text'], 'voice': voice_info,
        'voice_start_seconds': round(start, 3), 'voice_end_seconds': round(finish, 3),
        'second_part_tempo': .94, 'reverb_delays_ms': [72, 145],
        'music': 'Game original moonlit_village.wav; ducked during narration',
        'effects': ['claw_1.wav', 'claw_2.wav', 'curtain_tear.wav'],
        'original_narration_replaced': True, 'burned_in_subtitles_removed': True,
        'export': str(exported.relative_to(ROOT)), 'export_sha256': digest(exported),
        'export_dimensions': [1080, 1920], 'duration_seconds': DURATION,
        'app_dimensions': [720, 1280], 'app_sha256': digest(native),
        'app_bytes': native.stat().st_size,
        'codecs': 'H.264 High / AAC stereo 48 kHz',
        'note': 'Source 720x1280; export upscaled proportionally, app keeps native resolution.',
    }
    if args.apply:
        asset = ROOT / 'apps/mordeviel/assets/branding/opening/intro_gemini.mp4'
        manifest_path = ROOT / 'tools/audio/opening_video.json'
        old = json.loads(manifest_path.read_text(encoding='utf-8'))
        if asset.exists() and digest(asset) != digest(native):
            archive = ROOT / 'media/opening/archive-video-2026-11-03' / f'intro-before-qwen-{digest(asset)[:12]}.mp4'
            archive.parent.mkdir(parents=True, exist_ok=True)
            if not archive.exists():
                shutil.copy2(asset, archive)
            metadata['previous_video_archive'] = str(archive.relative_to(ROOT))
        previous = old.get('previous_versions', [])
        if old['original_filename'] != source.name:
            previous.append({k: v for k, v in old.items() if k != 'previous_versions'})
        shutil.copy2(native, asset)
        manifest_path.write_text(json.dumps({
            'source': 'Gemini video supplied by Logan; approved local Qwen game narration',
            'original_filename': source.name, 'original_sha256': digest(source),
            'asset': str(asset.relative_to(ROOT)).replace('\\', '/'),
            'asset_sha256': digest(asset), 'asset_bytes': asset.stat().st_size,
            'duration_seconds': DURATION, 'width': 720, 'height': 1280, 'fps': 24,
            'video_codec': 'H.264', 'audio_codec': 'AAC stereo 48000Hz',
            'processing': 'Native portrait, subtitle removal, approved Qwen voice and game audio mix.',
            'archive': old.get('archive'), 'previous_versions': previous,
        }, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
        print('Application opening asset updated; previous video archived.', flush=True)
    (ROOT / 'tools/audio/opening_narration.json').write_text(
        json.dumps(metadata, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')


if __name__ == '__main__':
    main()
