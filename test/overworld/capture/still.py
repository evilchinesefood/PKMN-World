#!/usr/bin/env python3
"""still.py <run> <frame> <out-stem>: 3x nearest-neighbour PNG still into out/."""
import os, sys
from PIL import Image
R = os.environ.get("CAPTURE_OUT") or os.path.join(os.path.dirname(os.path.abspath(__file__)), "../../../build/capture")
run, f, stem = sys.argv[1], int(sys.argv[2]), sys.argv[3]
os.makedirs(f"{R}/out/stills", exist_ok=True)
im = Image.open(f"{R}/runs/{run}/frames/f{f:06d}.png").convert("RGB")
im.resize((720, 480), Image.NEAREST).save(f"{R}/out/stills/{stem}.png"); print(stem)
