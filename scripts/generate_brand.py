#!/usr/bin/env python3
"""Generate the small branded web splash/icons with stdlib only."""
import math
import struct
import zlib
from pathlib import Path

OUT = Path(__file__).resolve().parent.parent / "assets" / "brand"
OUT.mkdir(parents=True, exist_ok=True)


def write_png(path, width, height, pixels):
    raw = bytearray()
    for y in range(height):
        raw.append(0)
        for x in range(width):
            raw.extend(pixels[y * width + x])
    def chunk(tag, data):
        return (struct.pack(">I", len(data)) + tag + data
                + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF))
    png = (b"\x89PNG\r\n\x1a\n"
           + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0))
           + chunk(b"IDAT", zlib.compress(bytes(raw), 9))
           + chunk(b"IEND", b""))
    path.write_bytes(png)


def mix(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def line(pixels, w, h, x0, y0, x1, y1, color, width=1):
    steps = max(abs(x1 - x0), abs(y1 - y0), 1)
    for i in range(steps + 1):
        x = round(x0 + (x1 - x0) * i / steps)
        y = round(y0 + (y1 - y0) * i / steps)
        for dy in range(-width // 2, width // 2 + 1):
            for dx in range(-width // 2, width // 2 + 1):
                xx, yy = x + dx, y + dy
                if 0 <= xx < w and 0 <= yy < h:
                    pixels[yy * w + xx] = color


def ring(pixels, w, h, cx, cy, r, color, width=2):
    steps = max(64, int(r * 8))
    pts = []
    for i in range(steps):
        a = 2 * math.pi * i / steps
        pts.append((cx + math.cos(a) * r, cy + math.sin(a) * r))
    for i in range(steps):
        x0, y0 = pts[i]
        x1, y1 = pts[(i + 1) % steps]
        line(pixels, w, h, x0, y0, x1, y1, color, width)


def make_splash():
    w, h = 800, 600
    top, bottom = (11, 15, 23), (26, 36, 52)
    pixels = [mix(top, bottom, y / h) for y in range(h) for _ in range(w)]
    grid = (20, 28, 40)
    for x in range(0, w, 40):
        line(pixels, w, h, x, 0, x, h, grid)
    for y in range(0, h, 40):
        line(pixels, w, h, 0, y, w, y, grid)
    cyan, dim, white = (71, 184, 240), (41, 107, 153), (229, 234, 242)
    cx, cy = w // 2, h // 2 - 20
    ring(pixels, w, h, cx, cy, 88, dim, 3)
    ring(pixels, w, h, cx, cy, 58, cyan, 2)
    line(pixels, w, h, cx - 120, cy, cx - 30, cy, cyan, 3)
    line(pixels, w, h, cx + 30, cy, cx + 120, cy, cyan, 3)
    line(pixels, w, h, cx, cy - 120, cx, cy - 30, cyan, 3)
    line(pixels, w, h, cx, cy + 30, cx, cy + 120, cyan, 3)
    for x in range(cx - 180, cx + 180, 12):
        line(pixels, w, h, x, h - 70, x + 8, h - 70, dim)
    line(pixels, w, h, 120, h - 120, w - 120, h - 120, dim, 2)
    write_png(OUT / "splash.png", w, h, pixels)


def make_icon(size):
    w = h = size
    bg = (11, 15, 23)
    pixels = [bg for _ in range(w * h)]
    cyan, dim, white = (71, 184, 240), (41, 107, 153), (229, 234, 242)
    cx = cy = size // 2
    r = int(size * 0.36)
    ring(pixels, w, h, cx, cy, r, dim, max(2, size // 96))
    gap = int(size * 0.12)
    arm = int(size * 0.20)
    th = max(2, size // 64)
    line(pixels, w, h, cx - gap - arm, cy, cx - gap, cy, cyan, th)
    line(pixels, w, h, cx + gap, cy, cx + gap + arm, cy, cyan, th)
    line(pixels, w, h, cx, cy - gap - arm, cx, cy - gap, cyan, th)
    line(pixels, w, h, cx, cy + gap, cx, cy + gap + arm, cyan, th)
    write_png(OUT / f"icon_{size}.png", w, h, pixels)


if __name__ == "__main__":
    make_splash()
    for s in (192, 512):
        make_icon(s)
    print("generated", ", ".join(p.name for p in sorted(OUT.glob("*.png"))))
