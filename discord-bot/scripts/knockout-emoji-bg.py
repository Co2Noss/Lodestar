#!/usr/bin/env python3
"""Knock out the light studio background so Discord emojis are actually transparent."""

from collections import deque
from pathlib import Path

from PIL import Image

DIR = Path(__file__).resolve().parent.parent / "emojis"


def is_studio_paper(r, g, b, a):
    if a == 0:
        return True
    mx, mn = max(r, g, b), min(r, g, b)
    # near-white / light gray, low saturation (the generated studio backdrop)
    return mx >= 205 and (mx - mn) <= 24


def is_contact_shadow(r, g, b, a):
    """Soft drop-shadow / anti-aliased halo around the icon, not the icon itself."""
    mx, mn = max(r, g, b), min(r, g, b)
    sat = mx - mn
    if sat > 22:
        return False
    if a < 180:
        return True
    return mx >= 168


def flood_mask(im):
    w, h = im.size
    px = im.load()
    seen = [[False] * w for _ in range(h)]
    q = deque()

    def push(x, y, pred):
        if x < 0 or y < 0 or x >= w or y >= h or seen[y][x]:
            return
        r, g, b, a = px[x, y]
        if not pred(r, g, b, a):
            return
        seen[y][x] = True
        q.append((x, y))

    for x in range(w):
        push(x, 0, is_studio_paper)
        push(x, h - 1, is_studio_paper)
    for y in range(h):
        push(0, y, is_studio_paper)
        push(w - 1, y, is_studio_paper)

    while q:
        x, y = q.popleft()
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            push(x + dx, y + dy, is_studio_paper)

    # Second pass: eat contact shadows that touch already-cleared paper.
    q.clear()
    for y in range(h):
        for x in range(w):
            if seen[y][x]:
                q.append((x, y))
    while q:
        x, y = q.popleft()
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            push(x + dx, y + dy, is_contact_shadow)

    return seen


def unblend_white(r, g, b, a):
    if a <= 0:
        return (r, g, b, 0)
    if a >= 255:
        return (r, g, b, a)
    fa = a / 255.0
    def ch(c):
        v = (c / 255.0 - (1.0 - fa)) / fa
        return int(max(0, min(255, round(v * 255))))
    return (ch(r), ch(g), ch(b), a)


def apply(im):
    im = im.convert("RGBA")
    mask = flood_mask(im)
    px = im.load()
    w, h = im.size
    for y in range(h):
        for x in range(w):
            if mask[y][x]:
                r, g, b, _ = px[x, y]
                px[x, y] = (r, g, b, 0)
                continue
            r, g, b, a = px[x, y]
            mx, mn = max(r, g, b), min(r, g, b)
            neighbor = False
            for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < w and 0 <= ny < h and mask[ny][nx]:
                    neighbor = True
                    break
            if not neighbor:
                continue
            # leftover paper mixed into the silhouette: convert to alpha and
            # pull RGB off white so Discord's dark theme does not show a halo
            if mx >= 190 and (mx - mn) <= 32:
                fade = int(255 * max(0.0, (230 - mx) / 50))
                a = max(0, min(a, fade))
            px[x, y] = unblend_white(r, g, b, a)
    return im


def main():
    for path in sorted(DIR.glob("*.png")):
        im = Image.open(path)
        out = apply(im)
        out.save(path, "PNG", optimize=True)
        px = out.load()
        w, h = out.size
        transparent = sum(1 for y in range(h) for x in range(w) if px[x, y][3] == 0)
        print(f"{path.name:16} transparent={transparent:5}/{w * h} size={path.stat().st_size}")


if __name__ == "__main__":
    main()
