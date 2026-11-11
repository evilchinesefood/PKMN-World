#!/usr/bin/env python3
import csv
from pathlib import Path
import tempfile

import NativeRunner


def main():
    original = NativeRunner.HERE
    rows = NativeRunner.read_inventory()
    required = [r for r in rows if r['scope'] == 'required']
    assert required and all(r['name'] != 'VerifyOwnerSave' for r in required)
    with tempfile.TemporaryDirectory(prefix='pw-catalog-test-') as temporary:
        root = Path(temporary)
        (root / 'lua').mkdir()
        for path in (original / 'lua').glob('*.lua'):
            (root / 'lua' / path.name).touch()
        NativeRunner.HERE = root
        def write(selected):
            with (root / 'cases.tsv').open('w') as file:
                writer = csv.DictWriter(file, fieldnames=rows[0].keys(), delimiter='\t')
                writer.writeheader(); writer.writerows(selected)
        def rejected(label, selected):
            write(selected)
            try:
                NativeRunner.read_inventory()
            except ValueError:
                print('PASS ' + label)
            else:
                raise AssertionError(label + ' was accepted')
        rejected('omitted required row', [r for r in rows if r is not required[-1]])
        rejected('duplicate suite', rows + [rows[0]])
        drifted = [dict(r, fixture='lua/fixtures/v7.srm') if r['name'] == 'VerifyV7Migrate' else r for r in rows]
        rejected('vacuous clean fixture substitution', drifted)
        (root / 'lua/NewRegression.lua').touch()
        rejected('unclassified new regression', rows)
        (root / 'lua/NewRegression.lua').unlink()
        write(rows)
        assert NativeRunner.read_inventory() == rows
        print('PASS complete inventory')
    NativeRunner.HERE = original
    print('Canonical inventory checks: 5/5 passed')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
