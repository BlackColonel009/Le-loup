"""Real cloth recording, CC0 Joseph Sardin; no synthetic tearing waveform."""
import array
import hashlib
import math
import subprocess
import sys
import wave
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'tools/audio/sources/cloth_0013.mp3'
EXPECTED = '93ce221ab889ca535e21b948efe1646a58ef0e9d28ae2974a418cd455f647a63'

def main():
    if hashlib.sha256(SOURCE.read_bytes()).hexdigest() != EXPECTED:
        raise ValueError('The licensed source recording has changed.')
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument('--ffmpeg', required=True, help='Path to an FFmpeg executable')
    args = parser.parse_args()
    result = subprocess.run([args.ffmpeg, '-v', 'error', '-i', str(SOURCE), '-f', 's16le', '-ac', '1', '-ar', '22050', '-'], capture_output=True, check=True)
    samples = array.array('h', result.stdout)
    if sys.byteorder != 'little':
        samples.byteswap()
    target = ROOT / 'apps/mordeviel/assets/audio/classic'
    for filename, start, end, pan in [
        ('claw_1.wav', .47, 1.10, -.55),
        ('claw_2.wav', 2.11, 2.65, .55),
        ('curtain_tear.wav', 3.30, 5.35, 0),
    ]:
        cut = samples[round(start * 22050):round(end * 22050)]
        shaped = [math.tanh(v / 32768 * 11) for v in cut]
        peak = max(abs(v) for v in shaped)
        stereo = array.array('h')
        for i, value in enumerate(shaped):
            fade = min(1, i / (22050 * .008), (len(cut) - i) / (22050 * .045))
            value = value / peak * .88 * fade
            stereo.extend([round(value * math.sqrt((1 - pan) / 2) * 32767), round(value * math.sqrt((1 + pan) / 2) * 32767)])
        if sys.byteorder != 'little':
            stereo.byteswap()
        with wave.open(str(target / filename), 'wb') as output:
            output.setparams((2, 2, 22050, 0, 'NONE', 'not compressed'))
            output.writeframes(stereo.tobytes())
        print(filename, len(cut) / 22050)

if __name__ == '__main__':
    main()
