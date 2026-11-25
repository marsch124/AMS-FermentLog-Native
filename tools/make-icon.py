#!/usr/bin/env python3
"""Draws the app icon: a flat carrot-orange background with the white hand-drawn jar (the Home tab mark, stroke only).
Writes a 1024x1024 OPAQUE RGB PNG plus the Mac sizes into App/Resources/Assets.xcassets/AppIcon.appiconset.
   python3 tools/make-icon.py
"""
import math, os, re, sys
from PIL import Image, ImageDraw

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
SET = os.path.join(ROOT, "App/Resources/Assets.xcassets/AppIcon.appiconset")
BG = (232, 114, 44)        # carrot orange #e8722c
FG = (255, 255, 255)

# The jar from index.html (Home tab): the outline at stroke 1.9, the steam at 1.4, on the 24 grid.
OUTLINE = "M8 4h8 M8 4v1.4a3 3 0 0 1-.9 2.1A4 4 0 0 0 6 10.4V18a3 3 0 0 0 3 3h6a3 3 0 0 0 3-3v-7.6a4 4 0 0 0-1.1-2.9A3 3 0 0 1 16 5.4V4"
STEAM = "M9.2 12.4c-.7 1.2.7 2.1 0 3.3c-.7 1.2.7 2 0 3.1 M12 12.4c.7 1.2-.7 2.1 0 3.3c.7 1.2-.7 2 0 3.1 M14.8 12.4c-.7 1.2.7 2.1 0 3.3c.7 1.2-.7 2 0 3.1"

def tokens(d):
    return re.findall(r"[MmLlHhVvCcSsQqAaZz]|-?\d*\.?\d+(?:e-?\d+)?", d)

def arc_points(x1, y1, rx, ry, phi, fa, fs, x2, y2, n=24):
    # SVG endpoint arc -> centre parameterisation (SVG 1.1 appendix F.6)
    if rx == 0 or ry == 0: return [(x2, y2)]
    cp, sp = math.cos(math.radians(phi)), math.sin(math.radians(phi))
    dx, dy = (x1 - x2) / 2, (y1 - y2) / 2
    x1p, y1p = cp * dx + sp * dy, -sp * dx + cp * dy
    rx, ry = abs(rx), abs(ry)
    lam = x1p**2 / rx**2 + y1p**2 / ry**2
    if lam > 1: rx, ry = rx * math.sqrt(lam), ry * math.sqrt(lam)
    num = rx**2 * ry**2 - rx**2 * y1p**2 - ry**2 * x1p**2
    den = rx**2 * y1p**2 + ry**2 * x1p**2
    co = math.sqrt(max(0, num / den)) * (-1 if fa == fs else 1)
    cxp, cyp = co * rx * y1p / ry, -co * ry * x1p / rx
    cx, cy = cp * cxp - sp * cyp + (x1 + x2) / 2, sp * cxp + cp * cyp + (y1 + y2) / 2
    def ang(ux, uy, vx, vy):
        a = math.atan2(ux * vy - uy * vx, ux * vx + uy * vy)
        return a
    t1 = ang(1, 0, (x1p - cxp) / rx, (y1p - cyp) / ry)
    dt = ang((x1p - cxp) / rx, (y1p - cyp) / ry, (-x1p - cxp) / rx, (-y1p - cyp) / ry)
    if not fs and dt > 0: dt -= 2 * math.pi
    if fs and dt < 0: dt += 2 * math.pi
    pts = []
    for i in range(1, n + 1):
        t = t1 + dt * i / n
        x = cp * rx * math.cos(t) - sp * ry * math.sin(t) + cx
        y = sp * rx * math.cos(t) + cp * ry * math.sin(t) + cy
        pts.append((x, y))
    return pts

def flatten(d):
    """SVG path data -> list of polylines (M L H V C S Q A Z, absolute and relative)."""
    t = tokens(d); i = 0
    subs, cur, pos, start, cmd, lastc = [], [], (0.0, 0.0), (0.0, 0.0), None, None
    def num():
        nonlocal i
        v = float(t[i]); i += 1; return v
    def flag():
        # arc flags may be glued to the next number ("0 0 1-.9"): the tokenizer already splits at '-',
        # but "01" style pairs would not occur in our paths.
        return int(num())
    while i < len(t):
        if re.match(r"[A-Za-z]", t[i]): cmd = t[i]; i += 1
        rel = cmd.islower(); C = cmd.upper()
        ox, oy = pos if rel else (0, 0)
        if C == "Z":
            if cur: cur.append(start); subs.append(cur); cur = []
            pos = start; lastc = None; continue
        if C == "M":
            if cur: subs.append(cur)
            x, y = num() + ox, num() + oy; pos = start = (x, y); cur = [pos]; cmd = "l" if rel else "L"; lastc = None
        elif C == "L":
            pos = (num() + ox, num() + oy); cur.append(pos); lastc = None
        elif C == "H":
            pos = (num() + ox, pos[1]); cur.append(pos); lastc = None
        elif C == "V":
            pos = (pos[0], num() + oy); cur.append(pos); lastc = None
        elif C in "CS":
            if C == "C": p1 = (num() + ox, num() + oy)
            else: p1 = (2 * pos[0] - lastc[0], 2 * pos[1] - lastc[1]) if lastc else pos
            p2 = (num() + ox, num() + oy); p3 = (num() + ox, num() + oy)
            for k in range(1, 25):
                u = k / 24; a = (1 - u)**3; b = 3 * (1 - u)**2 * u; c = 3 * (1 - u) * u**2; e = u**3
                cur.append((a * pos[0] + b * p1[0] + c * p2[0] + e * p3[0], a * pos[1] + b * p1[1] + c * p2[1] + e * p3[1]))
            pos = p3; lastc = p2
        elif C == "Q":
            p1 = (num() + ox, num() + oy); p2 = (num() + ox, num() + oy)
            for k in range(1, 17):
                u = k / 16
                cur.append(((1 - u)**2 * pos[0] + 2 * (1 - u) * u * p1[0] + u**2 * p2[0], (1 - u)**2 * pos[1] + 2 * (1 - u) * u * p1[1] + u**2 * p2[1]))
            pos = p2; lastc = None
        elif C == "A":
            rx, ry, phi, fa, fs = num(), num(), num(), flag(), flag()
            end = (num() + ox, num() + oy)
            cur.extend(arc_points(pos[0], pos[1], rx, ry, phi, fa, fs, end[0], end[1])); pos = end; lastc = None
        else:
            raise SystemExit("unsupported command " + cmd)
    if cur: subs.append(cur)
    return subs

def draw(size):
    """Render at 4x for smooth edges, then shrink."""
    S = size * 4
    img = Image.new("RGB", (S, S), BG)
    dr = ImageDraw.Draw(img)
    k = S * 0.58 / 24                      # the jar fills about two thirds of the tile
    ox = oy = (S - 24 * k) / 2
    def stroke(d, w):
        r = w * k / 2
        for poly in flatten(d):
            pts = [(ox + x * k, oy + y * k) for x, y in poly]
            # every segment is a thick line with a round end: smooth joins and caps, no speckles
            for a, b in zip(pts, pts[1:]):
                dr.line([a, b], fill=FG, width=int(round(w * k)))
            for (x, y) in pts:
                dr.ellipse((x - r, y - r, x + r, y + r), fill=FG)
    stroke(OUTLINE, 1.9 * 1.1)            # a little heavier than the tab mark: it is small on a Home Screen
    stroke(STEAM, 1.4 * 1.1)
    return img.resize((size, size), Image.LANCZOS)

if __name__ == "__main__":
    os.makedirs(SET, exist_ok=True)
    big = draw(1024)
    assert big.mode == "RGB"
    big.save(os.path.join(SET, "icon-1024.png"))
    for base in (16, 32, 128, 256, 512):
        for scale, suffix in ((1, ""), (2, "@2x")):
            px = base * scale
            im = big.resize((px, px), Image.LANCZOS)
            assert im.mode == "RGB"
            im.save(os.path.join(SET, f"mac-{base}{suffix}.png"))
    print("icons written to", SET)
