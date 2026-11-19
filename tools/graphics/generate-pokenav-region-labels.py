#!/usr/bin/env python3
"""Draw the Johto and Kanto PokeNav map labels from the Hoenn ones.

The PokeNav menu option (graphics/pokenav/options/hoenn_map.png) and the region map's left header
(graphics/pokenav/left_headers/hoenn_map.png) spell HOENN MAP in a 5x9 outlined font: body pixels
in colour 1, a colour 2 shadow to the right, below and below-right. This rewrites the five letters
of HOENN as JOHTO or KANTO and keeps " MAP". Glyphs come from the labels themselves (T from
MATCH CALL); the art has no J or K, so those two bodies are drawn here in the same style.

Run from the repository root: python3 tools/graphics/generate-pokenav-region-labels.py
"""
from pathlib import Path
from PIL import Image

NAV = Path('graphics/pokenav')
BODY, SHADOW, ROWS, CELL = 1, 2, 9, 6

DRAWN = {
    'J': ['....1', '....1', '....1', '....1', '....1', '....1', '1...1', '1...1', '.111.'],
    'K': ['1...1', '1...1', '1..1.', '1.1..', '11...', '1.1..', '1..1.', '1...1', '1...1'],
}


def option_strip(path):
    """The option label is four 32x16 subsprites stacked in a 32x64 image; return it as 128x16."""
    src = Image.open(path)
    strip = Image.new('P', (128, 16))
    strip.putpalette(src.getpalette())
    for k in range(4):
        strip.paste(src.crop((0, k * 16, 32, k * 16 + 16)), (k * 32, 0))
    return strip


def unstrip(strip, like):
    out = Image.new('P', like.size)
    out.putpalette(like.getpalette())
    for k in range(4):
        out.paste(strip.crop((k * 32, 0, k * 32 + 32, 16)), (0, k * 16))
    return out


def glyph(img, x, y):
    px = img.load()
    return [''.join('1' if px[x + i, y + r] == BODY else '.' for i in range(5)) for r in range(ROWS)]


def draw_word(img, word, x, y, background):
    px = img.load()
    for r in range(ROWS + 1):
        for i in range(CELL * len(word)):
            px[x + i, y + r] = background
    for n, rows in enumerate(word):
        for r, line in enumerate(rows):
            for i, c in enumerate(line):
                if c != '1':
                    continue
                px[x + n * CELL + i, y + r] = BODY
                for dx, dy in ((1, 0), (0, 1), (1, 1)):
                    if px[x + n * CELL + i + dx, y + r + dy] != BODY:
                        px[x + n * CELL + i + dx, y + r + dy] = SHADOW


def font(img, x, y, word):
    return {ch: glyph(img, x + n * CELL, y) for n, ch in enumerate(word) if ch != ' '}


def save4(img, path):
    img.save(path, bits=4)


def main():
    opt = option_strip(NAV / 'options/hoenn_map.png')
    letters = dict(DRAWN)
    letters.update(font(opt, 16, 4, 'HOENN MAP'))
    letters.update(font(option_strip(NAV / 'options/match_call.png'), 16, 4, 'MATCH'))
    like_opt = Image.open(NAV / 'options/hoenn_map.png')
    like_hdr = Image.open(NAV / 'left_headers/hoenn_map.png')
    for name in ('JOHTO', 'KANTO'):
        word = [letters[c] for c in name]
        strip = opt.copy()
        draw_word(strip, word, 16, 4, background=4)
        save4(unstrip(strip, like_opt), NAV / f'options/{name.lower()}_map.png')
        hdr = like_hdr.copy()
        draw_word(hdr, word, 4, 7, background=8)
        save4(hdr, NAV / f'left_headers/{name.lower()}_map.png')


if __name__ == '__main__':
    main()
