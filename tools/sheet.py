#!/usr/bin/env python3
"""Build a labelled comparison sheet from renders (replaces ad-hoc PIL snippets).

  tools/sheet.py out.png --cols 2 [--scale 0.5] [--crop x0,y0,x1,y1] \\
      "BEFORE=a.png" "AFTER=b.png" ...

Each image argument is LABEL=path (or just a path). Images are cropped (same
box for all, in source pixels), scaled, and laid out in a grid with the label
in a dark strip above each cell. Use it for every before/after sheet saved to
docs/screenshots/.

--diff adds a last cell showing where the first two images differ (per-pixel
colour change, amplified, in red over a dimmed copy of the first image) and
prints the share of changed pixels - check that a fix only touched what it
was meant to.
"""
import argparse
from PIL import Image, ImageDraw, ImageFont

ap = argparse.ArgumentParser()
ap.add_argument("out")
ap.add_argument("images", nargs="+")
ap.add_argument("--cols", type=int, default=2)
ap.add_argument("--scale", type=float, default=0.5)
ap.add_argument("--crop", default="")
ap.add_argument("--diff", action="store_true")
a = ap.parse_args()

cells = []
for spec in a.images:
    label, _, path = spec.rpartition("=") if "=" in spec else ("", "", spec)
    im = Image.open(path).convert("RGB")
    if a.crop:
        im = im.crop(tuple(int(v) for v in a.crop.split(",")))
    if a.scale != 1.0:
        im = im.resize((max(1, int(im.width * a.scale)), max(1, int(im.height * a.scale))), Image.LANCZOS)
    cells.append((label, im))

if a.diff and len(cells) >= 2:
    import numpy as np
    x = np.asarray(cells[0][1], dtype=np.float32)
    y = np.asarray(cells[1][1].resize(cells[0][1].size), dtype=np.float32)
    d = np.abs(x - y).max(axis=2)
    changed = d > 12.0
    base = x * 0.35
    base[..., 0] = np.maximum(base[..., 0], np.clip(d * 4.0, 0, 255))
    cells.append((f"DIFF ({changed.mean() * 100:.1f}% of pixels)", Image.fromarray(base.astype(np.uint8))))
    print(f"changed pixels: {changed.mean() * 100:.2f}%  (|delta| > 12 of 255)")

w = max(im.width for _, im in cells)
h = max(im.height for _, im in cells)
strip = 34 if any(l for l, _ in cells) else 0
rows = (len(cells) + a.cols - 1) // a.cols
sheet = Image.new("RGB", (w * a.cols, (h + strip) * rows), (18, 20, 24))
draw = ImageDraw.Draw(sheet)
try:
    font = ImageFont.truetype("DejaVuSans-Bold.ttf", 20)
except OSError:
    font = ImageFont.load_default()
for i, (label, im) in enumerate(cells):
    x, y = (i % a.cols) * w, (i // a.cols) * (h + strip)
    if strip:
        draw.text((x + 10, y + 6), label, fill=(235, 238, 242), font=font)
    sheet.paste(im, (x, y + strip))
sheet.save(a.out)
print(f"{a.out}: {sheet.width}x{sheet.height}, {len(cells)} cells")
