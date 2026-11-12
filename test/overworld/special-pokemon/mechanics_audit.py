#!/usr/bin/env python3
"""Resolve collection flag allocations with the host C compiler."""
from pathlib import Path
import re
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[3]
FLAGS = ['-DEMERALD', '-DALL_REGIONS=1', '-I' + str(ROOT / 'include')]


def main():
    macros = subprocess.check_output(
        ['cc', '-E', '-dM', '-x', 'c', *FLAGS, '-include', 'constants/flags.h', '/dev/null'], text=True)
    names = sorted(re.findall(r'^#define (FLAG_\w+)\s', macros, re.M))
    assert len(names) > 1000, 'flag inventory unexpectedly empty'
    source = '#include <stdio.h>\n#include "constants/flags.h"\nint main(void) {\n'
    for name in names:
        source += (f'if (({name}) >= 0xDD0 && ({name}) <= 0xDEF) '
                   f'printf("{name} %x\\n", (unsigned)({name}));\n')
    source += 'return 0; }\n'
    with tempfile.TemporaryDirectory(prefix='special-flags-') as directory:
        root = Path(directory)
        (root / 'flags.c').write_text(source)
        subprocess.run(['cc', *FLAGS, str(root / 'flags.c'), '-o', str(root / 'flags')], check=True)
        rows = subprocess.check_output([str(root / 'flags')], text=True).splitlines()
    actual = {}
    for row in rows:
        name, value = row.split()
        value = int(value, 16)
        assert name.startswith('FLAG_SPECIAL_'), f'collection overlaps {name}'
        assert value not in actual, f'{name} overlaps {actual.get(value)}'
        actual[value] = name
    assert set(actual) == (set(range(0xDD0, 0xDD8)) | set(range(0xDDA, 0xDE2)) | set(range(0xDE4, 0xDEC))) - {0xDD6, 0xDE0}, 'collection allocation is incomplete'
    print('PASS: 22 collection flags resolve to unique existing-capacity addresses, with no external alias')


if __name__ == '__main__':
    main()
