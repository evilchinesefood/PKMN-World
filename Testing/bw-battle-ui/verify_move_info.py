#!/usr/bin/env python3
"""Compare the restored panel to World's original capture, ignoring its backdrop."""
import argparse
import json
from pathlib import Path
from PIL import Image

p = argparse.ArgumentParser()
p.add_argument('--before', type=Path, required=True)
p.add_argument('--after', type=Path, required=True)
p.add_argument('--out', type=Path, required=True)
a = p.parse_args()
before = Image.open(a.before).convert('RGB')
after = Image.open(a.after).convert('RGB')
frame = Image.open(Path(__file__).resolve().parents[2] / 'graphics/text_window/swsh/1.png')
assert frame.mode == 'P' and frame.size == (24, 24)
checked = changed = 0
for y in range(48, 112):
    for x in range(160):
        inside = 8 <= x < 152 and 56 <= y < 104
        fx = x % 8 + (0 if x < 8 else 16 if x >= 152 else 8)
        fy = y % 8 + (0 if y < 56 else 16 if y >= 104 else 8)
        # Index zero is transparent: the BW healthboxes/backdrop may show through.
        if inside or frame.getpixel((fx, fy)) != 0:
            checked += 1
            changed += before.getpixel((x, y)) != after.getpixel((x, y))
result = {'before': str(a.before), 'after': str(a.after),
          'checked_panel_pixels': checked, 'changed_panel_pixels': changed}
a.out.write_text(json.dumps(result, indent=2) + '\n')
assert changed == 0, result
print(f'PASS: {checked} opaque frame/content pixels match the original window')
