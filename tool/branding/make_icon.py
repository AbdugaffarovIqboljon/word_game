#!/usr/bin/env python3
"""Generate the So'z Jangi 1024px app-icon master (single source asset).

No third-party deps (no PIL): draws directly and encodes PNG via stdlib zlib.
Design: two rounded "letter tiles" — S and J — in the board's correct-green on
the app background #0B1220, matching the design's app-icon tile look. Letters are
a clean 7-segment-style so they render crisply with only geometry + AA.

    python3 make_icon.py [out.png]   (default: app_icon_master.png next to this)
"""
from __future__ import annotations

import math
import os
import struct
import sys
import zlib

SIZE = 1024
BG = (0x0B, 0x12, 0x20)          # #0B1220 app background
TILE = (0x5F, 0xBE, 0x73)        # #5FBE73 successBright (correct-tile green)
TILE_EDGE = (0x4A, 0x9E, 0x5C)   # slightly darker bevel edge
INK = (0xFF, 0xFF, 0xFF)         # white letters


def smoothstep(edge0, edge1, x):
    if edge0 == edge1:
        return 0.0 if x < edge0 else 1.0
    t = max(0.0, min(1.0, (x - edge0) / (edge1 - edge0)))
    return t * t * (3 - 2 * t)


def rounded_rect_sd(px, py, cx, cy, hw, hh, r):
    """Signed distance to a rounded rect centred (cx,cy), half-size (hw,hh)."""
    qx = abs(px - cx) - (hw - r)
    qy = abs(py - cy) - (hh - r)
    ax, ay = max(qx, 0.0), max(qy, 0.0)
    return math.hypot(ax, ay) + min(max(qx, qy), 0.0) - r


def capsule_sd(px, py, ax, ay, bx, by, r):
    """Signed distance to a thick line (round caps) from A to B, radius r."""
    pax, pay = px - ax, py - ay
    bax, bay = bx - ax, by - ay
    denom = bax * bax + bay * bay
    h = 0.0 if denom == 0 else max(0.0, min(1.0, (pax * bax + pay * bay) / denom))
    dx, dy = pax - bax * h, pay - bay * h
    return math.hypot(dx, dy) - r


def segments(letter, x, y, w, h, t):
    """7-segment capsule endpoints for a letter in box (x,y,w,h), stroke t."""
    r = t / 2
    L, R = x + r, x + w - r
    T, M, B = y + r, y + h / 2, y + h - r
    seg = {
        'a': (L, T, R, T),   # top
        'b': (R, T, R, M),   # upper right
        'c': (R, M, R, B),   # lower right
        'd': (L, B, R, B),   # bottom
        'e': (L, M, L, B),   # lower left
        'f': (L, T, L, M),   # upper left
        'g': (L, M, R, M),   # middle
    }
    active = {'S': 'afgcd', 'J': 'bcde'}[letter]
    return [seg[k] for k in active], r


def blend(dst, src, a):
    return tuple(int(round(dst[i] * (1 - a) + src[i] * a)) for i in range(3))


def draw(scale=1.0, transparent=False):
    """Render the icon. scale<1 shrinks the tiles (adaptive-icon safe zone);
    transparent=True emits an RGBA buffer with a clear background."""
    ch_n = 4 if transparent else 3
    buf = bytearray(SIZE * SIZE * ch_n)

    # tile geometry
    tile_w = 392 * scale
    gap = 40 * scale
    total = tile_w * 2 + gap
    x0 = (SIZE - total) / 2
    y0 = (SIZE - tile_w) / 2
    radius = tile_w * 0.20
    tiles = [
        ('S', x0, y0),
        ('J', x0 + tile_w + gap, y0),
    ]
    # letter box inside a tile (padding scales with the tile)
    pad_x, pad_top, pad_bot = 118 * scale, 96 * scale, 96 * scale
    stroke = 60 * scale

    letters = []
    for ch, tx, ty in tiles:
        lx, ly = tx + pad_x, ty + pad_top
        lw, lh = tile_w - 2 * pad_x, tile_w - pad_top - pad_bot
        segs, sr = segments(ch, lx, ly, lw, lh, stroke)
        letters.append((tx, ty, segs, sr))

    for py in range(SIZE):
        fy = py + 0.5
        row = py * SIZE * ch_n
        for px in range(SIZE):
            fx = px + 0.5
            col = BG
            alpha = 0.0 if transparent else 1.0
            for i, (ch, tx, ty) in enumerate(tiles):
                cx, cy = tx + tile_w / 2, ty + tile_w / 2
                d = rounded_rect_sd(fx, fy, cx, cy, tile_w / 2, tile_w / 2, radius)
                cov = 1.0 - smoothstep(-1.0, 1.0, d)
                if cov <= 0:
                    continue
                edge = smoothstep(-3.0, -0.5, d)
                tilecol = blend(TILE, TILE_EDGE, edge * 0.6)
                col = blend(col, tilecol, cov)
                alpha = max(alpha, cov)
                _, _, segs, sr = letters[i]
                ld = min(capsule_sd(fx, fy, *s, sr) for s in segs)
                lcov = 1.0 - smoothstep(-1.0, 1.0, ld)
                if lcov > 0:
                    col = blend(col, INK, lcov)
            o = row + px * ch_n
            buf[o], buf[o + 1], buf[o + 2] = col
            if transparent:
                buf[o + 3] = int(round(alpha * 255))
    return buf


def write_png(path, buf, alpha=False):
    def chunk(tag, data):
        c = struct.pack('>I', len(data)) + tag + data
        return c + struct.pack('>I', zlib.crc32(tag + data) & 0xffffffff)

    ch_n = 4 if alpha else 3
    raw = bytearray()
    for y in range(SIZE):
        raw.append(0)  # filter: none
        raw.extend(buf[y * SIZE * ch_n:(y + 1) * SIZE * ch_n])
    png = b'\x89PNG\r\n\x1a\n'
    color_type = 6 if alpha else 2
    png += chunk(b'IHDR', struct.pack('>IIBBBBB', SIZE, SIZE, 8, color_type, 0, 0, 0))
    png += chunk(b'IDAT', zlib.compress(bytes(raw), 9))
    png += chunk(b'IEND', b'')
    with open(path, 'wb') as f:
        f.write(png)


def main():
    here = os.path.dirname(os.path.abspath(__file__))
    master = os.path.join(here, 'app_icon_master.png')
    foreground = os.path.join(here, 'app_icon_foreground.png')
    write_png(master, draw())
    print('wrote', master, f'({SIZE}x{SIZE})')
    # Adaptive-icon foreground: transparent bg, tiles shrunk into the safe zone.
    write_png(foreground, draw(scale=0.62, transparent=True), alpha=True)
    print('wrote', foreground, f'({SIZE}x{SIZE}, transparent)')


if __name__ == '__main__':
    main()
