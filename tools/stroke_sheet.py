#!/usr/bin/env python3
"""Assembles tools/capture_strokes.gd frames into one sheet: a row per stroke.
Usage: python3 tools/stroke_sheet.py <prefix> <out.png> [frames]"""
import glob, sys
from PIL import Image, ImageDraw, ImageFont
prefix, out = sys.argv[1], sys.argv[2]
frames = int(sys.argv[3]) if len(sys.argv) > 3 else 6
kinds = []
for p in sorted(glob.glob(prefix + "-*-0.png")):
    kinds.append(p[len(prefix) + 1:-6])
order = ["wrist", "snap", "slap", "one_timer", "backhand", "pass", "saucer", "tip", "poke", "deke_fhbh", "deke_toe_drag", "deke_fake"]
kinds.sort(key=lambda k: order.index(k) if k in order else 99)
tile = 300
font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 20)
sheet = Image.new("RGB", (160 + tile * frames, tile * len(kinds)), (20, 24, 30))
d = ImageDraw.Draw(sheet)
for r, k in enumerate(kinds):
    d.text((10, r * tile + tile // 2 - 12), k.replace("_", " "), font=font, fill=(255, 220, 90))
    for n in range(frames):
        im = Image.open(f"{prefix}-{k}-{n}.png").convert("RGB")
        w, h = im.size
        s = min(w, h)
        im = im.crop(((w - s) // 2, (h - s) // 2, (w + s) // 2, (h + s) // 2)).resize((tile, tile))
        sheet.paste(im, (160 + n * tile, r * tile))
sheet.save(out)
print("sheet", out, len(kinds), "strokes")
