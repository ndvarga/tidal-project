#!/usr/bin/env python3
"""Cut the original amen break (am_og) into one file per hit (am_slice).

Reads   ~/mixmatrix-samples/am_og/00_amen_break_og.wav   (from fetch_mixmatrix_samples.py)
Writes  ~/mixmatrix-samples/am_slice/NN_bB_sSS_<kind>.wav

The break is 4 bars of 16th notes. The script fits a tempo grid to the
transients, keeps the 16th steps that start a hit, cuts each hit at its
transient (until the next one) with short fades, and labels it kick, snare,
ride or crash from its frequency balance. NN is the slice number to use with
s "am_slice:NN"; B and SS are the bar (0-3) and 16th step (0-15) it came
from. The table it prints is what the "amen" song in main.tidal is built on.

Usage:  python3 slice_amen.py [--dry-run] [samples folder]
Needs Python 3.8+, no extra packages.
"""
import math
import os
import struct
import sys
import wave

DRY = '--dry-run' in sys.argv
ARGS = [a for a in sys.argv[1:] if a != '--dry-run']
ROOT = os.path.expanduser(ARGS[0] if ARGS else '~/mixmatrix-samples')
SRC = os.path.join(ROOT, 'am_og', '00_amen_break_og.wav')
DST = os.path.join(ROOT, 'am_slice')

STEPS = 64          # 4 bars of 16ths
ENV_MS = 1          # envelope resolution
SEARCH_MS = 15      # how far from a grid point a transient may be
ONSET_LEVEL = 0.10  # transient strength (relative to the strongest) that counts as a hit
PRE_MS = 1.5        # start each slice this long before its transient
FADE_IN_MS = 0.5
FADE_OUT_MS = 6


def read_wav(path):
    w = wave.open(path)
    ch, width, rate, n = w.getnchannels(), w.getsampwidth(), w.getframerate(), w.getnframes()
    if width != 2:
        sys.exit('expected 16-bit audio in ' + path)
    data = struct.unpack('<%dh' % (n * ch), w.readframes(n))
    frames = [data[i * ch:(i + 1) * ch] for i in range(n)]
    return frames, ch, rate


def onepole(xs, cutoff, rate, high=False):
    a = math.exp(-2 * math.pi * cutoff / rate)
    out, y = [], 0.0
    for x in xs:
        y = (1 - a) * x + a * y
        out.append(x - y if high else y)
    return out


def main():
    frames, ch, rate = read_wav(SRC)
    mono = [sum(f) / ch for f in frames]
    hop = rate * ENV_MS // 1000
    env = [sum(abs(v) for v in mono[i:i + hop]) / hop for i in range(0, len(mono) - hop, hop)]
    flux = [0.0] + [max(0.0, env[i] - env[i - 1]) for i in range(1, len(env))]
    fmax = max(flux)

    # tempo grid: start near the first transient, BPM around the classic 136-138
    first = next(i for i, f in enumerate(flux) if f > 0.2 * fmax)
    win = SEARCH_MS // ENV_MS

    def strength(t):
        i = int(round(t))
        return max(flux[max(0, i - win):min(len(flux), i + win + 1)] or [0])

    best = None
    for t0 in range(first - 10, first + 11):
        for bpm100 in range(13400, 14000, 2):
            step = 60000 / (bpm100 / 100) / 4 / ENV_MS
            score = sum(strength(t0 + k * step) for k in range(STEPS))
            if best is None or score > best[0]:
                best = (score, t0, bpm100 / 100, step)
    _, t0, bpm, step = best
    print('grid: %.2f BPM, first step at %.1f ms, 16th = %.1f ms' % (bpm, t0 * ENV_MS, step * ENV_MS))

    # which 16th steps start a hit, and exactly where
    hits = []
    strengths = [strength(t0 + k * step) for k in range(STEPS)]
    smax = max(strengths)
    for k in range(STEPS):
        if strengths[k] < ONSET_LEVEL * smax:
            continue
        c = int(round(t0 + k * step))
        lo, hi = max(1, c - win), min(len(flux) - 1, c + win)
        peak = max(range(lo, hi + 1), key=lambda i: flux[i])
        start = peak
        while start > lo and env[start - 1] < env[start]:
            start -= 1
        hits.append((k, start * hop - int(rate * PRE_MS / 1000), strengths[k] / smax))

    # cut, label and (unless --dry-run) write
    if not DRY:
        os.makedirs(DST, exist_ok=True)
        for f in os.listdir(DST):
            if f.lower().endswith('.wav'):
                os.remove(os.path.join(DST, f))
    fi, fo = int(rate * FADE_IN_MS / 1000), int(rate * FADE_OUT_MS / 1000)
    print(' #  bar step  length  level  low  high  kind')
    for idx, (k, s0, lvl) in enumerate(hits):
        s1 = hits[idx + 1][1] if idx + 1 < len(hits) else len(frames)
        s0 = max(0, s0)
        part = frames[s0:s1]
        head = [sum(f) / ch for f in part[:int(rate * 0.05)]]
        total = sum(v * v for v in head) or 1.0
        low = sum(v * v for v in onepole(head, 120, rate)) / total
        high = sum(v * v for v in onepole(head, 5000, rate, high=True)) / total
        # kick: lots of low end; crash: the long ringing hit; ride: almost no
        # low end and mostly top; everything else is snare (incl. ghost notes)
        if low > 0.3:
            kind = 'kick'
        elif len(part) > rate * 0.6:
            kind = 'crash'
        elif low < 0.06 and high > 0.2:
            kind = 'ride'
        else:
            kind = 'snare'
        name = '%02d_b%d_s%02d_%s.wav' % (idx, k // 16, k % 16, kind)
        print('%2d   %d   %2d   %4.0f ms  %.2f  %.2f  %.2f  %s' % (idx, k // 16, k % 16, len(part) * 1000 / rate, lvl, low, high, kind))
        if DRY:
            continue
        out = []
        n = len(part)
        for i, f in enumerate(part):
            g = min(1.0, i / fi if fi else 1.0, (n - 1 - i) / fo if fo else 1.0)
            out.extend(int(round(v * g)) for v in f)
        w = wave.open(os.path.join(DST, name), 'wb')
        w.setnchannels(ch)
        w.setsampwidth(2)
        w.setframerate(rate)
        w.writeframes(struct.pack('<%dh' % len(out), *out))
        w.close()
    print(('would write' if DRY else 'wrote') + ' %d slices to %s' % (len(hits), DST))


if __name__ == '__main__':
    main()
