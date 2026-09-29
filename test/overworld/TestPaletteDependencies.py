#!/usr/bin/env python3
"""Exercise generated Make rules when palette alpha sidecars change."""
from pathlib import Path
import os
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parents[2]
with tempfile.TemporaryDirectory(prefix='pw-palette-deps-') as tmp:
    base = Path(tmp)
    source = base / 'sample.c'
    palette = base / 'sample.pal'
    alpha = palette.with_suffix('.pla')
    palette.write_text('JASC-PAL\n0100\n16\n' + '0 0 0\n' * 16)
    source.write_text('const unsigned short palette[] = INCGFX_U16("sample.pal", ".gbapal");\n')
    subprocess.check_output([str(ROOT/'tools/scaninc/scaninc'), '-M', 'sample.d', '-g', 'assets', 'sample.c'], text=True, cwd=base)
    rules = (base/'sample.d').read_text()
    makefile = base / 'Makefile'
    makefile.write_text(f'GFX := {ROOT}/tools/gbagfx/gbagfx\n' + rules)
    target = base/'assets/sample.pal.gbapal'
    def build():
        subprocess.run(['make', '--no-print-directory', '-f', str(makefile), 'assets/sample.pal.gbapal'], cwd=base, check=True, stdout=subprocess.DEVNULL)
        return int.from_bytes(target.read_bytes()[:2], 'little')
    def changed():
        # Avoid coarse filesystem timestamp ties without sleeping.
        past = time.time() - 5
        os.utime(target, (past, past))
    old = time.time() - 60
    os.utime(palette, (old, old))
    assert build() == 0, 'base palette must have no light marker'
    changed(); alpha.write_text('0\n')
    assert build() == 0x8000, 'adding .pla must rebuild its palette'
    changed(); alpha.write_text('1\n')
    assert build() == 0, 'editing .pla must rebuild its palette'
    changed(); alpha.unlink()
    assert build() == 0 and not target.read_bytes()[3] & 0x80, 'removing .pla must rebuild its palette'
print('Palette dependency checks: 4/4 PASS')
