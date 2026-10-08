"""Generates the app icon sets and their preview images into Assets.xcassets.

Every color style comes with every glyph (neutral wallet, ₸, ₽, $, €), so the app can
switch the icon to match the selected currency. Pure Python (no Pillow needed): shapes
are signed distance fields, which gives smooth anti-aliased edges. Re-run after edits:

    python tools/generate_icons.py

To use your own artwork, replace the PNGs inside the *.appiconset and IconPreview-*
.imageset folders (keep the file names). "AppIcon" (Classic + Neutral) is the primary icon.
"""
import json
import math
import os
import shutil
import struct
import zlib

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "MoneyManager", "Assets.xcassets")

# style -> (gradient top-left, gradient bottom-right, glyph color, ring alpha)
STYLES = {
    "Classic":  ((0x34, 0x95, 0xE5), (0x4B, 0x3F, 0xD8), (0xFF, 0xFF, 0xFF), 0.28),
    "Midnight": ((0x1C, 0x1C, 0x2E), (0x05, 0x05, 0x0A), (0x5E, 0xEA, 0xD4), 0.35),
    "Emerald":  ((0x2E, 0xCC, 0x71), (0x0E, 0x7A, 0x5A), (0xFF, 0xFF, 0xFF), 0.28),
    "Sunset":   ((0xFF, 0x9F, 0x43), (0xEE, 0x3D, 0x7A), (0xFF, 0xFF, 0xFF), 0.28),
    "Minimal":  ((0xFF, 0xFF, 0xFF), (0xE9, 0xEB, 0xF0), (0x1C, 0x1C, 0x1E), 0.18),
}


# ---------------------------------------------------------------- SDF primitives

def sd_box(px, py, cx, cy, hw, hh, r=0.0):
    qx = abs(px - cx) - hw + r
    qy = abs(py - cy) - hh + r
    return math.hypot(max(qx, 0.0), max(qy, 0.0)) + min(max(qx, qy), 0.0) - r


def sd_circle(px, py, cx, cy, radius):
    return math.hypot(px - cx, py - cy) - radius


def sd_ring(px, py, cx, cy, radius, thickness):
    return abs(math.hypot(px - cx, py - cy) - radius) - thickness / 2


def sd_quadrant(px, py, x0, y0, sx, sy):
    """Region where sx*(x-x0) > 0 and sy*(y-y0) > 0 (sx, sy are +1/-1)."""
    dx = sx * (px - x0)
    dy = sy * (py - y0)
    if dx > 0 and dy > 0:
        return -min(dx, dy)
    return math.hypot(max(-dx, 0.0), max(-dy, 0.0))


def subtract(d, cut):
    return max(d, -cut)


# ---------------------------------------------------------------- glyphs
# Each glyph is a list of layers: (sdf(u, v) -> distance, mode, alpha).
# mode "ink" paints the glyph color, "cut" paints the background back.

def glyph_tenge():
    def bars(u, v):
        return min(
            sd_box(u, v, 0.5, 0.315, 0.215, 0.042, 0.042),
            sd_box(u, v, 0.5, 0.435, 0.215, 0.042, 0.042),
            sd_box(u, v, 0.5, 0.605, 0.044, 0.185, 0.044),
        )
    return [(bars, "ink", 1.0)]


def glyph_ruble():
    def shape(u, v):
        stem = sd_box(u, v, 0.43, 0.505, 0.042, 0.235, 0.02)
        # The bowl of the "P": a rounded rectangle outline sharing its left wall with the stem.
        outer = sd_box(u, v, 0.538, 0.375, 0.15, 0.115, 0.11)
        inner = sd_box(u, v, 0.565, 0.375, 0.08, 0.037, 0.037)
        bowl = subtract(outer, inner)
        bar = sd_box(u, v, 0.475, 0.605, 0.165, 0.036, 0.02)
        return min(stem, bowl, bar)
    return [(shape, "ink", 1.0)]


def glyph_dollar():
    def shape(u, v):
        r, t = 0.105, 0.072
        upper = sd_ring(u, v, 0.5, 0.405, r, t)
        upper = subtract(upper, sd_quadrant(u, v, 0.5, 0.405 - 0.03, 1, 1))   # open on the right, lower half
        lower = sd_ring(u, v, 0.5, 0.595, r, t)
        lower = subtract(lower, sd_quadrant(u, v, 0.5, 0.595 + 0.03, -1, -1))  # open on the left, upper half
        line = sd_box(u, v, 0.5, 0.5, 0.022, 0.29, 0.022)
        return min(upper, lower, line)
    return [(shape, "ink", 1.0)]


def glyph_euro():
    def shape(u, v):
        c = sd_ring(u, v, 0.55, 0.5, 0.2, 0.075)
        c = subtract(c, sd_box(u, v, 0.80, 0.5, 0.2, 0.105))  # opening of the "C" on the right
        bars = min(
            sd_box(u, v, 0.40, 0.455, 0.14, 0.03, 0.03),
            sd_box(u, v, 0.40, 0.545, 0.14, 0.03, 0.03),
        )
        return min(c, bars)
    return [(shape, "ink", 1.0)]


def glyph_neutral():
    """A wallet with a card peeking out."""
    return [
        (lambda u, v: sd_box(u, v, 0.47, 0.36, 0.19, 0.08, 0.035), "ink", 0.55),   # card
        (lambda u, v: sd_box(u, v, 0.5, 0.56, 0.27, 0.19, 0.07), "ink", 1.0),      # wallet body
        (lambda u, v: sd_box(u, v, 0.735, 0.56, 0.085, 0.065, 0.05), "cut", 1.0),  # clasp
        (lambda u, v: sd_circle(u, v, 0.715, 0.56, 0.024), "ink", 1.0),            # clasp button
    ]


GLYPHS = {
    "Neutral": glyph_neutral(),
    "Tenge": glyph_tenge(),
    "Ruble": glyph_ruble(),
    "Dollar": glyph_dollar(),
    "Euro": glyph_euro(),
}
RING = (0.5, 0.5, 0.385, 0.022)


# ---------------------------------------------------------------- rendering

def render(size, style, layers):
    top, bottom, glyph, ring_alpha = style
    rows = []
    inv = 1.0 / size
    for y in range(size):
        v = (y + 0.5) * inv
        row = bytearray()
        for x in range(size):
            u = (x + 0.5) * inv
            t = min(max((u + v) / 2, 0.0), 1.0)
            bg = (top[0] + (bottom[0] - top[0]) * t,
                  top[1] + (bottom[1] - top[1]) * t,
                  top[2] + (bottom[2] - top[2]) * t)
            r, g, b = bg

            cov = min(max(0.5 - sd_ring(u, v, *RING) * size, 0.0), 1.0) * ring_alpha
            if cov > 0:
                r += (glyph[0] - r) * cov
                g += (glyph[1] - g) * cov
                b += (glyph[2] - b) * cov

            if 0.18 < u < 0.82 and 0.18 < v < 0.82:
                for sdf, mode, alpha in layers:
                    cov = min(max(0.5 - sdf(u, v) * size, 0.0), 1.0) * alpha
                    if cov <= 0:
                        continue
                    target = glyph if mode == "ink" else bg
                    r += (target[0] - r) * cov
                    g += (target[1] - g) * cov
                    b += (target[2] - b) * cov

            row += bytes((int(r + 0.5), int(g + 0.5), int(b + 0.5)))
        rows.append(bytes(row))
    return rows


def write_png(path, size, rows):
    raw = b"".join(b"\x00" + row for row in rows)

    def chunk(tag, data):
        body = tag + data
        return struct.pack(">I", len(data)) + body + struct.pack(">I", zlib.crc32(body) & 0xFFFFFFFF)

    png = b"\x89PNG\r\n\x1a\n"
    png += chunk(b"IHDR", struct.pack(">IIBBBBB", size, size, 8, 2, 0, 0, 0))  # 8-bit RGB, no alpha
    png += chunk(b"IDAT", zlib.compress(raw, 9))
    png += chunk(b"IEND", b"")
    with open(path, "wb") as f:
        f.write(png)


def write_json(path, data):
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        json.dump(data, f, indent=2)
        f.write("\n")


def icon_set_name(style, glyph):
    return "AppIcon" if (style, glyph) == ("Classic", "Neutral") else f"AppIcon-{style}-{glyph}"


def main():
    # Remove previously generated sets so renamed variants don't linger.
    for entry in os.listdir(ROOT):
        if (entry.startswith("AppIcon") and entry.endswith(".appiconset")) or \
           (entry.startswith("IconPreview-") and entry.endswith(".imageset")):
            shutil.rmtree(os.path.join(ROOT, entry))

    for style_name, style in STYLES.items():
        for glyph_name, layers in GLYPHS.items():
            icon_set = icon_set_name(style_name, glyph_name)
            print(f"Rendering {icon_set} ...", flush=True)

            icon_dir = os.path.join(ROOT, f"{icon_set}.appiconset")
            os.makedirs(icon_dir)
            icon_file = f"{icon_set}-1024.png"
            write_png(os.path.join(icon_dir, icon_file), 1024, render(1024, style, layers))
            write_json(os.path.join(icon_dir, "Contents.json"), {
                "images": [{"filename": icon_file, "idiom": "universal", "platform": "ios", "size": "1024x1024"}],
                "info": {"author": "xcode", "version": 1},
            })

            preview = f"IconPreview-{style_name}-{glyph_name}"
            preview_dir = os.path.join(ROOT, f"{preview}.imageset")
            os.makedirs(preview_dir)
            write_png(os.path.join(preview_dir, f"{preview}.png"), 180, render(180, style, layers))
            write_json(os.path.join(preview_dir, "Contents.json"), {
                "images": [{"filename": f"{preview}.png", "idiom": "universal"}],
                "info": {"author": "xcode", "version": 1},
            })


if __name__ == "__main__":
    import sys
    if len(sys.argv) > 1 and sys.argv[1] == "--sample":
        # Quick look at every glyph in one style without touching the asset catalog.
        out = sys.argv[2] if len(sys.argv) > 2 else "."
        for glyph_name, layers in GLYPHS.items():
            write_png(os.path.join(out, f"sample-{glyph_name}.png"), 256, render(256, STYLES["Classic"], layers))
    else:
        main()
