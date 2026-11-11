#!/usr/bin/env python3
"""Generate disposable supported-save cases for the native options migration suite."""
import argparse
from pathlib import Path
import struct

import SavePatch as SP

SOURCE = Path(__file__).resolve().parent / 'lua/fixtures/v10regional.srm'


def build(version, old_hard):
    save = SP.self_test(SOURCE)
    SP.require_intact_slot(save)
    SP.migrate(save)
    save.sb2[SP.V['SB2.saveVersion']] = version
    text_speed = (version - 7) % 3 if version < 12 else 3
    struct.pack_into('<HH', save.sb2, 0x14, 0x1000 | text_speed,
                     0xFFE6 | (0x10 if old_hard else 0))
    struct.pack_into('<H', save.sb2, SP.V['SB2.regionChecksum'], save.region_checksum())
    save.writeback()
    return bytes(save.flash)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', required=True, type=Path)
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    for version in range(7, 13):
        for hard in (False, True):
            path = args.output / f'v{version}-{"hard" if hard else "normal"}.srm'
            path.write_bytes(build(version, hard))
            save = SP.self_test(path)
            SP.require_intact_slot(save)
            assert save.region_checksum() == save.u16(save.sb2, SP.V['SB2.regionChecksum'])
    print('12 disposable options fixtures have valid sector and regional checksums')


if __name__ == '__main__':
    main()
