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


def burp(length, pitch, f1, f2, f3=None, jitter=0.07, shimmer=0.16, rough=0.02, breath=0.07,
         wobble=0.12, wobble_hz=19, drive=1.6, chest=0.15, loud=None, bounce=0.0, bounce_hz=6.0, seed=7):
    """One burp as a list of samples (-1…1, peak 1). Paths are [(0…1 of the length, value)]."""
    rnd = random.Random(seed)
    n = int(RATE * length)
    pitch = scaled(pitch, length)
    f1, f2 = scaled(f1, length), scaled(f2, length)
    f3 = scaled(f3 or [(0, 2600), (0.06, 2900), (1, 2800)], length)
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
        lift = 1.0 + bounce * math.sin(2 * math.pi * bounce_hz * tt)      # a gentle, cheerful bounce
        out.append(s * (1.0 + wobble * math.sin(ph)) * lift * lerp(loud, tt))
    peak = max(abs(v) for v in out) or 1.0
    out = [math.tanh(drive * v / peak) / math.tanh(drive) for v in out]
    mean = sum(out) / len(out)
    out = [v - mean for v in out]
    peak = max(abs(v) for v in out) or 1.0
    return [v / peak for v in out]


def silence(seconds):
    return [0.0] * int(RATE * seconds)


def bloop(dur=0.06, f0=500, f1=1100, amp=0.35):
    """A small bubble pop: a quick rising whistle that dies away (like a bubble leaving the brine)."""
    n = int(RATE * dur)
    out, ph = [], 0.0
    for i in range(n):
        t = i / RATE
        f = f0 * (f1 / f0) ** (t / dur)
        ph += 2 * math.pi * f / RATE
        env = (1 - math.exp(-t / 0.002)) * math.exp(-t / (dur * 0.35))
        out.append(amp * env * math.sin(ph))
    return out


def mix(base, add, at):
    """`add` laid over `base` from `at` seconds on (the result grows when needed)."""
    start = int(RATE * at)
    out = base + [0.0] * max(0, start + len(add) - len(base))
    for i, v in enumerate(add):
        out[start + i] += v
    peak = max(abs(v) for v in out) or 1.0
    return [v / peak for v in out] if peak > 1 else out


# Mouth shapes (F1, F2) — 6.6: bright and open, like a smile ("ah", "eh"); softer "uh" for contrast.
HA = ([(0, 400), (0.06, 750), (0.7, 780), (1, 560)], [(0, 1000), (0.06, 1450), (0.7, 1500), (1, 1150)])
EH = ([(0, 380), (0.06, 620), (1, 520)], [(0, 1200), (0.06, 1750), (1, 1500)])
UH = ([(0, 360), (0.06, 680), (1, 480)], [(0, 950), (0.06, 1250), (1, 1000)])

# The ten — number, how loud (0…1 of full), and the recipe. Names live in the app (BurpSounds.swift).
# 6.6: all remade happier (his words: "a bit more happy … now they are very maskuline"): pitch about
# 150–330 Hz instead of 45–200, brighter mouths, little growl, most lift at the end, some end in a bubble.
BURPS = {
    # 1 Classic — a cheerful little burp
    1: (0.92, lambda: burp(0.8, [(0, 170), (0.15, 200), (0.6, 185), (0.85, 175), (1, 215)], *HA, seed=7)),
    # 2 Short pop — quick and bubbly
    2: (0.92, lambda: mix(burp(0.32, [(0, 210), (0.4, 235), (1, 250)], *EH,
                               loud=[(0, 0), (0.04, 1), (0.6, 0.8), (0.9, 0.3), (1, 0)], seed=21),
                          bloop(0.07, 500, 1100, 0.45), 0.3)),
    # 3 Chuckle — burps like a happy laugh ("ha-ha-ha-buurp")
    3: (0.92, lambda: burp(1.0, [(0, 190), (0.3, 180), (0.6, 200), (1, 230)], *HA,
                           loud=[(0, 0), (0.02, 0.9), (0.09, 0.25), (0.13, 0.95), (0.2, 0.25), (0.24, 1.0),
                                 (0.31, 0.3), (0.36, 1.0), (0.8, 0.75), (0.93, 0.4), (1, 0)], seed=33)),
    # 4 Long one — takes its time, with a smile (a little song: up, down, up)
    4: (0.90, lambda: burp(1.6, [(0, 165), (0.1, 190), (0.45, 200), (0.75, 180), (0.9, 195), (1, 230)], *HA,
                           bounce=0.15, bounce_hz=5.5,
                           loud=[(0, 0), (0.01, 0.8), (0.06, 1), (0.6, 0.85), (0.88, 0.5), (0.97, 0.12), (1, 0)], seed=44)),
    # 5 Squeaky — high and small
    5: (0.85, lambda: burp(0.5, [(0, 280), (0.3, 320), (1, 330)], *EH, jitter=0.05, chest=0.05, seed=55)),
    # 6 Double — two in a row, the second one higher
    6: (0.92, lambda: burp(0.35, [(0, 180), (1, 200)], *HA, seed=61)
                     + silence(0.07)
                     + burp(0.5, [(0, 220), (0.5, 250), (1, 270)], *EH, seed=62)),
    # 7 Bubbles — fizzy, like a fresh jar: a burp and four little bubbles going up
    7: (0.92, lambda: mix(mix(mix(mix(burp(0.7, [(0, 175), (0.4, 195), (1, 205)], *HA, seed=77),
                                      bloop(0.06, 400, 900, 0.40), 0.68),
                                  bloop(0.06, 500, 1100, 0.36), 0.80),
                              bloop(0.06, 650, 1300, 0.33), 0.90),
                          bloop(0.07, 800, 1600, 0.30), 1.00)),
    # 8 Rising — ends going up, like a question
    8: (0.90, lambda: burp(0.85, [(0, 160), (0.4, 165), (0.8, 240), (1, 300)], *UH,
                           loud=[(0, 0), (0.015, 0.85), (0.1, 1), (0.6, 0.85), (0.9, 0.65), (1, 0)], seed=88)),
    # 9 Tiny — a polite little one
    9: (0.55, lambda: burp(0.25, [(0, 240), (1, 270)], *EH, jitter=0.04, chest=0.08, breath=0.04, wobble=0.06,
                           loud=[(0, 0), (0.05, 1), (0.6, 0.7), (1, 0)], seed=99)),
    # 10 Ta-da — proud, ends on a high note (and a bubble)
    10: (1.0, lambda: mix(burp(1.2, [(0, 180), (0.15, 210), (0.5, 205), (0.75, 230), (1, 280)], *HA,
                               drive=2.0, chest=0.25, wobble=0.15, seed=101),
                          bloop(0.08, 700, 1500, 0.35), 1.16)),
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
