"""Prepare Logan's coin rain video and audio-derived impact timestamps."""
import argparse
import array
import hashlib
import json
import math
import subprocess
import wave
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('source', type=Path)
    parser.add_argument('--ffmpeg', required=True)
    args = parser.parse_args()
    out = ROOT / 'apps/mordeviel/assets/rewards'
    out.mkdir(parents=True, exist_ok=True)
    video = out / 'coin_rain.mp4'
    subprocess.run([args.ffmpeg, '-y', '-hide_banner', '-loglevel', 'error',
                    '-i', str(args.source), '-map', '0:v:0', '-map', '0:a:0',
                    '-vf', 'scale=540:960', '-c:v', 'libx264', '-crf', '24',
                    '-preset', 'medium', '-pix_fmt', 'yuv420p', '-c:a', 'aac',
                    '-b:a', '96k', '-movflags', '+faststart', str(video)], check=True)
    work = ROOT / '.tmp/coin-video'
    work.mkdir(parents=True, exist_ok=True)
    sound = work / 'impacts.wav'
    subprocess.run([args.ffmpeg, '-y', '-hide_banner', '-loglevel', 'error',
                    '-i', str(video), '-vn', '-af', 'highpass=f=1800',
                    '-ac', '1', '-ar', '22050', '-c:a', 'pcm_s16le', str(sound)], check=True)
    with wave.open(str(sound)) as wav:
        rate = wav.getframerate()
        samples = array.array('h', wav.readframes(wav.getnframes()))
    size = rate // 100
    energy = [math.sqrt(sum(x*x for x in samples[i:i+size])/size) for i in range(0, len(samples)-size, size)]
    scores = [max(0, energy[i]-sum(energy[max(0,i-4):i])/min(i,4)) if i else 0 for i in range(len(energy))]
    threshold = sorted(scores)[int(len(scores)*.7)]
    candidates = sorted((i for i in range(1,len(scores)-1)
                         if scores[i] > threshold and energy[i] > max(energy)*.13
                         and scores[i] >= scores[i-1] and scores[i] >= scores[i+1]
                         and .05 < i*size/rate < 8.5), key=lambda i: scores[i], reverse=True)
    peaks = []
    for i in candidates:
        if all(abs(i-other)*size/rate >= .11 for other in peaks):
            peaks.append(i)
    ticks = [round(i*size/rate*1000) for i in sorted(peaks)]
    manifest = {'duration_ms': round(len(samples)/rate*1000), 'impact_ms': ticks,
                'source_sha256': hashlib.sha256(args.source.read_bytes()).hexdigest(),
                'sync': 'High-frequency impact transients, spaced at least 110 ms apart.'}
    (out / 'coin_impacts.json').write_text(json.dumps(manifest, indent=2)+'\n', encoding='utf8')
    print(f'{video.stat().st_size/1024/1024:.2f} MiB, {len(ticks)} impact markers')


if __name__ == '__main__':
    main()
