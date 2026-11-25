#!/usr/bin/env python3
"""Makes App/Resources/burp-01.caf … burp-10.caf — the ten burps of FermentLog (6.5).

Made from scratch, no recording and no extra packages. Each burp is an uneven, low buzz (the throat's own
flutter) sent through three mouth resonances that open on "b", sit on "uh" and close towards "p", with a
little breath noise, a wobble and a soft edge. Each of the ten has its own recipe below; the same recipe
draws the same burp every time.

Run:  python3 tools/make-burp.py
"""
import math
import os
import random
import struct
import subprocess
import tempfile
import wave

RATE = 22050
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_DIR = os.path.join(ROOT, "App", "Resources")


def lerp(points, t):
    """Piecewise-linear value at t from [(time, value), ...]; times may be 0…1 (scaled by the caller)."""
    if t <= points[0][0]:
        return points[0][1]
    for (t0, v0), (t1, v1) in zip(points, points[1:]):
        if t <= t1:
            return v0 + (v1 - v0) * (t - t0) / (t1 - t0)
    return points[-1][1]


def scaled(points, length):
    return [(t * length, v) for t, v in points]


def resonate(x, freq_path, bw):
    y = [0.0] * len(x)
    y1 = y2 = 0.0
    T = 1.0 / RATE
    c = -math.exp(-2 * math.pi * bw * T)
    r = 2 * math.exp(-math.pi * bw * T)
    for i, xi in enumerate(x):
        f = lerp(freq_path, i / RATE)
        b = r * math.cos(2 * math.pi * f * T)
        a = 1.0 - b - c
        yi = a * xi + b * y1 + c * y2
        y2, y1 = y1, yi
        y[i] = yi
    return y


def burp(length, pitch, f1, f2, f3=None, jitter=0.13, shimmer=0.28, rough=0.08, breath=0.10,
         wobble=0.22, wobble_hz=19, drive=2.2, chest=0.35, loud=None, seed=7):
    """One burp as a list of samples (-1…1, peak 1). Paths are [(0…1 of the length, value)]."""
    rnd = random.Random(seed)
    n = int(RATE * length)
    pitch = scaled(pitch, length)
    f1, f2 = scaled(f1, length), scaled(f2, length)
    f3 = scaled(f3 or [(0, 2200), (0.06, 2450), (1, 2300)], length)
    loud = scaled(loud or [(0, 0), (0.012, 0.85), (0.08, 1), (0.45, 0.92), (0.8, 0.55), (0.95, 0.12), (1, 0)], length)

    # 1. The flutter: one soft pulse per beat, uneven in timing and strength; now and then weak/strong in turn.
    src = [0.0] * n
    t, run = 0.004, 0
    while True:
        i = int(t * RATE)
        if i >= n:
            break
        period = (1.0 / lerp(pitch, t)) * max(0.55, 1.0 + rnd.gauss(0, jitter))
        amp = max(0.2, 1.0 + rnd.gauss(0, shimmer))
        if run > 0:
            amp *= 0.45 if run % 2 else 1.25
            run -= 1
        elif rnd.random() < rough:
            run = rnd.randint(4, 10)
        width = 18
        for k in range(width):
            if i + k < n:
                src[i + k] -= amp * math.sin(math.pi * k / width) ** 2 * (1.0 - k / width)
        t += period

    # 2. Breath noise on top, and the little puff of the "b".
    lp = 0.0
    for i in range(n):
        lp += 0.25 * (rnd.gauss(0, 1) - lp)
        puff = 1.4 * math.exp(-i / (RATE * 0.008)) if i < RATE * 0.03 else 0.0
        src[i] += breath * lp + puff * lp

    # 3. The mouth, plus some raw "chest".
    sig = src
    for path, bw in zip((f1, f2, f3), (130.0, 170.0, 320.0)):
        sig = resonate(sig, path, bw)
    body = resonate(src, [(0, 180), (length, 150)], 90)
    sig = [s + chest * b for s, b in zip(sig, body)]

    # 4. Wobble, loudness shape, a little grit.
    out, ph = [], 0.0
    for i, s in enumerate(sig):
        tt = i / RATE
        ph += 2 * math.pi * (wobble_hz + 6 * math.sin(2 * math.pi * 1.3 * tt)) / RATE
        out.append(s * (1.0 + wobble * math.sin(ph)) * lerp(loud, tt))
    peak = max(abs(v) for v in out) or 1.0
    out = [math.tanh(drive * v / peak) / math.tanh(drive) for v in out]
    mean = sum(out) / len(out)
    out = [v - mean for v in out]
    peak = max(abs(v) for v in out) or 1.0
    return [v / peak for v in out]


def silence(seconds):
    return [0.0] * int(RATE * seconds)


# Mouth shapes (F1, F2): "uh" is the plain burp; "aw" bigger; "oo" small and round.
UH = ([(0, 300), (0.06, 560), (0.7, 600), (1, 380)], [(0, 700), (0.06, 980), (0.7, 1020), (1, 760)])
AW = ([(0, 320), (0.05, 680), (0.7, 700), (1, 420)], [(0, 720), (0.05, 1050), (0.7, 1080), (1, 800)])
OO = ([(0, 280), (0.08, 420), (1, 340)], [(0, 650), (0.08, 800), (1, 700)])

# The ten — number, file, how loud (0…1 of full), and the recipe. Names live in the app (BurpSounds.swift).
BURPS = {
    # 1 Classic — a plain, honest burp (the 6.5 first burp)
    1: (0.92, lambda: burp(1.05, [(0, 92), (0.1, 104), (0.33, 96), (0.71, 78), (1, 58)], *UH, seed=7)),
    # 2 Short pop — quick and done
    2: (0.92, lambda: burp(0.38, [(0, 110), (0.3, 118), (1, 80)], *UH, jitter=0.10, rough=0.04,
                           loud=[(0, 0), (0.03, 1), (0.5, 0.8), (0.85, 0.25), (1, 0)], seed=21)),
    # 3 Deep rumble — low, from the cellar
    3: (0.95, lambda: burp(1.35, [(0, 62), (0.15, 70), (0.6, 58), (1, 42)], *AW, jitter=0.18, shimmer=0.35,
                           rough=0.12, chest=0.6, wobble=0.18, wobble_hz=11, seed=33)),
    # 4 Long one — takes its time
    4: (0.90, lambda: burp(2.0, [(0, 96), (0.08, 106), (0.4, 92), (0.8, 74), (1, 56)], *UH, jitter=0.14,
                           loud=[(0, 0), (0.008, 0.8), (0.05, 1), (0.6, 0.85), (0.88, 0.45), (0.97, 0.1), (1, 0)], seed=44)),
    # 5 Squeaky — high and small
    5: (0.85, lambda: burp(0.7, [(0, 175), (0.3, 195), (1, 150)], *OO, jitter=0.09, shimmer=0.2, rough=0.03,
                           chest=0.15, breath=0.06, wobble=0.15, wobble_hz=24, seed=55)),
    # 6 Double — two in a row
    6: (0.92, lambda: burp(0.42, [(0, 100), (0.3, 110), (1, 84)], *UH, seed=61)
                     + silence(0.09)
                     + [0.85 * v for v in burp(0.6, [(0, 94), (0.3, 100), (1, 66)], *UH, seed=62)]),
    # 7 Gurgle — wet and wobbly
    7: (0.92, lambda: burp(1.15, [(0, 88), (0.2, 96), (0.7, 80), (1, 60)], *UH, jitter=0.2, shimmer=0.4,
                           rough=0.15, breath=0.18, wobble=0.55, wobble_hz=14, seed=77)),
    # 8 Rising — ends going up, like a question
    8: (0.90, lambda: burp(0.95, [(0, 84), (0.45, 78), (0.8, 110), (1, 138)], *UH, jitter=0.11,
                           loud=[(0, 0), (0.015, 0.85), (0.1, 1), (0.6, 0.8), (0.9, 0.6), (1, 0)], seed=88)),
    # 9 Tiny — a polite little one
    9: (0.55, lambda: burp(0.26, [(0, 130), (0.4, 136), (1, 110)], *OO, jitter=0.08, shimmer=0.15, rough=0.0,
                           chest=0.2, breath=0.05, wobble=0.1,
                           loud=[(0, 0), (0.05, 1), (0.6, 0.7), (1, 0)], seed=99)),
    # 10 Big one — loud and rough
    10: (1.0, lambda: burp(1.5, [(0, 78), (0.12, 92), (0.5, 80), (1, 50)], *AW, jitter=0.2, shimmer=0.42,
                           rough=0.2, drive=3.4, chest=0.55, breath=0.14, wobble=0.3, wobble_hz=16, seed=101)),
}


def write(number, gain, samples):
    fade = int(RATE * 0.03)
    s = [gain * v for v in samples]
    for k in range(min(fade, len(s))):
        s[len(s) - 1 - k] *= k / fade
    out = os.path.join(OUT_DIR, f"burp-{number:02d}.caf")
    with tempfile.TemporaryDirectory() as tmp:
        wav = os.path.join(tmp, "b.wav")
        with wave.open(wav, "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(RATE)
            w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, v)) * 32767)) for v in s))
        subprocess.run(["afconvert", "-f", "caff", "-d", f"LEI16@{RATE}", wav, out], check=True)
    print(f"burp-{number:02d}.caf  {len(s) / RATE:.2f} s")


if __name__ == "__main__":
    os.makedirs(OUT_DIR, exist_ok=True)
    for number, (gain, make) in BURPS.items():
        write(number, 0.92 * gain, make())
