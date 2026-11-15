#!/usr/bin/env python3
"""sheet.py <name> [step] [start] [end]: 8-wide contact sheet of every step-th frame, labelled."""
import sys, glob, os
from PIL import Image, ImageDraw
R = os.environ.get("CAPTURE_OUT") or os.path.join(os.path.dirname(os.path.abspath(__file__)), "../../../build/capture")
name = sys.argv[1]; step = int(sys.argv[2]) if len(sys.argv) > 2 else 60
start = int(sys.argv[3]) if len(sys.argv) > 3 else 1
end = int(sys.argv[4]) if len(sys.argv) > 4 else 10**9
frames = sorted(glob.glob(f"{R}/runs/{name}/frames/f*.png"))
picks = [f for f in frames if start <= int(f[-10:-4]) <= end][::step][:96]
cols = 8; rows = (len(picks) + cols - 1) // cols
sheet = Image.new("RGB", (cols * 240, rows * 160))
d = ImageDraw.Draw(sheet)
for i, f in enumerate(picks):
    x, y = (i % cols) * 240, (i // cols) * 160
    sheet.paste(Image.open(f).convert("RGB"), (x, y))
    d.rectangle([x, y, x + 44, y + 11], fill="black"); d.text((x + 2, y), f[-10:-4].lstrip("0"), fill="yellow")
out = f"{R}/runs/{name}/sheet_{start}_{step}.png"; sheet.save(out); print(out, len(picks))
