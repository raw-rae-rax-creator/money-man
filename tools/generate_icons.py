"""Generates the app icon sets and their preview images into Assets.xcassets.

Pure Python (no Pillow needed): shapes are drawn as signed distance fields for
smooth anti-aliased edges. Re-run after tweaking colors:

    python tools/generate_icons.py

To use your own artwork instead, replace the PNGs inside the *.appiconset and
IconPreview-*.imageset folders (keep the file names).
"""
import json
import math
import os
import struct
import zlib

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "MoneyManager", "Assets.xcassets")

# name -> (gradient top-left, gradient bottom-right, glyph color, ring alpha)
VARIANTS = {
    "Default": ((0x34, 0x95, 0xE5), (0x4B, 0x3F, 0xD8), (0xFF, 0xFF, 0xFF), 0.28),
    "Dark":    ((0x1C, 0x1C, 0x2E), (0x05, 0x05, 0x0A), (0x5E, 0xEA, 0xD4), 0.35),
    "Green":   ((0x2E, 0xCC, 0x71), (0x0E, 0x7A, 0x5A), (0xFF, 0xFF, 0xFF), 0.28),
    "Sunset":  ((0xFF, 0x9F, 0x43), (0xEE, 0x3D, 0x7A), (0xFF, 0xFF, 0xFF), 0.28),
    "Mono":    ((0xFF, 0xFF, 0xFF), (0xE9, 0xEB, 0xF0), (0x1C, 0x1C, 0x1E), 0.18),
}


def sd_round_box(px, py, cx, cy, hw, hh, r):
    qx = abs(px - cx) - hw + r
    qy = abs(py - cy) - hh + r
    outside = math.hypot(max(qx, 0.0), max(qy, 0.0))
    inside = min(max(qx, qy), 0.0)
    return outside + inside - r


def sd_ring(px, py, cx, cy, radius, thickness):
    return abs(math.hypot(px - cx, py - cy) - radius) - thickness / 2


# The tenge sign ₸: two horizontal bars and a stem, in 0..1 icon coordinates.
BARS = [
    (0.5, 0.315, 0.215, 0.042, 0.042),
    (0.5, 0.435, 0.215, 0.042, 0.042),
    (0.5, 0.605, 0.044, 0.185, 0.044),
]
RING = (0.5, 0.5, 0.385, 0.022)


def render(size, top, bottom, glyph, ring_alpha):
    rows = []
    inv = 1.0 / size
    for y in range(size):
        v = (y + 0.5) * inv
        row = bytearray()
        for x in range(size):
            u = (x + 0.5) * inv
            # Diagonal gradient background.
            t = min(max((u + v) / 2, 0.0), 1.0)
            r = top[0] + (bottom[0] - top[0]) * t
            g = top[1] + (bottom[1] - top[1]) * t
            b = top[2] + (bottom[2] - top[2]) * t

            # Subtle ring.
            d = sd_ring(u, v, *RING)
            cov = min(max(0.5 - d * size, 0.0), 1.0) * ring_alpha
            if cov > 0:
                r += (glyph[0] - r) * cov
                g += (glyph[1] - g) * cov
                b += (glyph[2] - b) * cov

            # Glyph (cheap bounding box test first).
            if 0.26 < u < 0.74 and 0.25 < v < 0.81:
                d = min(sd_round_box(u, v, *bar) for bar in BARS)
                cov = min(max(0.5 - d * size, 0.0), 1.0)
                if cov > 0:
                    r += (glyph[0] - r) * cov
                    g += (glyph[1] - g) * cov
                    b += (glyph[2] - b) * cov

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


def main():
    for name, (top, bottom, glyph, ring_alpha) in VARIANTS.items():
        icon_set = "AppIcon" if name == "Default" else f"AppIcon-{name}"
        icon_dir = os.path.join(ROOT, f"{icon_set}.appiconset")
        os.makedirs(icon_dir, exist_ok=True)
        icon_file = f"{icon_set}-1024.png"
        print(f"Rendering {icon_set} ...")
        write_png(os.path.join(icon_dir, icon_file), 1024, render(1024, top, bottom, glyph, ring_alpha))
        write_json(os.path.join(icon_dir, "Contents.json"), {
            "images": [{"filename": icon_file, "idiom": "universal", "platform": "ios", "size": "1024x1024"}],
            "info": {"author": "xcode", "version": 1},
        })

        preview_dir = os.path.join(ROOT, f"IconPreview-{name}.imageset")
        os.makedirs(preview_dir, exist_ok=True)
        preview_file = f"IconPreview-{name}.png"
        write_png(os.path.join(preview_dir, preview_file), 180, render(180, top, bottom, glyph, ring_alpha))
        write_json(os.path.join(preview_dir, "Contents.json"), {
            "images": [{"filename": preview_file, "idiom": "universal"}],
            "info": {"author": "xcode", "version": 1},
        })


if __name__ == "__main__":
    main()
