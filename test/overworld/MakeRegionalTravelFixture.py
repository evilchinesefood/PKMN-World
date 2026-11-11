#!/usr/bin/env python3
"""Create a v10 fixture with dirty identity bits and an uninitialized v11 save tail."""
import argparse
from pathlib import Path
import struct

import SavePatch as SP

HERE = Path(__file__).resolve().parent
SOURCE = HERE / 'lua/fixtures/v10regional.srm'
DESTINATION = HERE / 'lua/fixtures/v10regionaldirty.srm'


def build():
    save = SP.self_test(SOURCE)
    SP.require_intact_slot(save)
    assert save.sb2[SP.V['SB2.saveVersion']] == 10
    assert save.sb1[SP.V['SB1.playerPartyCount']] == 1
    offset = SP.V['SB1.playerParty']
    mon = bytearray(save.sb1[offset:offset + SP.V['BoxPokemon.size']])
    personality, trainer = struct.unpack_from('<II', mon)
    key = personality ^ trainer
    plain = bytearray(struct.pack('<12I', *(value ^ key for value in struct.unpack_from('<12I', mon, 32))))
    assert sum(struct.unpack('<24H', plain)) & 0xFFFF == struct.unpack_from('<H', mon, 28)[0]
    for substruct, at, mask in ((0, 2, 0xFC00), (0, 6, 0xE000), (0, 10, 0xC000),
                               (1, 4, 0xF800), (1, 6, 0x3800), (3, 10, 0x1000)):
        pos = SP.SUBSTRUCT_OFFSETS[substruct][personality % 24] * 12 + at
        value = struct.unpack_from('<H', plain, pos)[0]
        assert value & mask == 0, 'the clean baseline must have zero legacy identity bits'
        struct.pack_into('<H', plain, pos, value | mask)
    struct.pack_into('<H', mon, 28, sum(struct.unpack('<24H', plain)) & 0xFFFF)
    struct.pack_into('<12I', mon, 32, *(value ^ key for value in struct.unpack('<12I', plain)))
    save.sb1[offset:offset + len(mon)] = mon
    recovered = bytearray(mon)
    SP.clear_regional_identity(recovered, 0)
    clean = SP.Save(SOURCE)
    assert recovered == clean.sb1[offset:offset + len(mon)]
    old_region = bytes(save.sb3[:SP.SB3_REGION_OFF + SP.V['RS.regionalTravel']])
    start = SP.SB3_REGION_OFF + SP.V['RS.regionalTravel']
    save.sb3[start:start + SP.V['RegionalTravel.size']] = b'\xA5' * SP.V['RegionalTravel.size']
    assert save.region_checksum() == save.u16(save.sb2, SP.V['SB2.regionChecksum'])
    assert bytes(save.sb3[:start]) == old_region
    save.writeback()
    return bytes(save.flash)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    blob = build()
    if args.check:
        assert DESTINATION.read_bytes() == blob, 'regional migration fixture differs from generator'
    else:
        DESTINATION.write_bytes(blob)
    checked = SP.self_test(DESTINATION)
    SP.require_intact_slot(checked)
    assert checked.region_checksum() == checked.u16(checked.sb2, SP.V['SB2.regionChecksum'])
    print('v10 regional fixture has valid sector and legacy regional checksums')


if __name__ == '__main__':
    main()
