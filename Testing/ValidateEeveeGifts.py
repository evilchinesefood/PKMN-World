#!/usr/bin/env python3
"""Check that Celadon's gift cannot satisfy Bill's receipt guard (#290)."""
import re
from pathlib import Path
def validate():
    root = Path(__file__).resolve().parent.parent
    bill = (root / 'data/maps/GoldenrodCity_BillsHouse/scripts.inc').read_text()
    celadon = (root / 'data/maps/CeladonCity_Condominiums_RoofRoom_Frlg/scripts.inc').read_text()
    city = (root / 'data/maps/GoldenrodCity/scripts.inc').read_text()
    guard = re.search(r'goto_if_unset (FLAG_\w+), GoldenrodCity_BillsHouse_EventScript_Bill_Eevee', bill)[1]
    celadon_flags = set(re.findall(r'^\s*setflag (FLAG_\w+)', celadon, re.M))
    assert guard not in celadon_flags, f'Celadon sets {guard}, which locks Bill out'
    assert f'setflag {guard}' in bill, 'Bill must record successful delivery'
    assert not re.search(r'^\s*clearflag ' + guard + r'\b', city, re.M), 'Entering Goldenrod must not reset Bill'
    assert 'clearflag FLAG_GOT_EEVEE' not in city, 'Goldenrod must not reset Kanto progress'
    assert bill.index('goto_if_eq VAR_RESULT, MON_CANT_GIVE') < bill.index(f'setflag {guard}'), 'Full storage must leave gift available'
    header = (root / 'include/constants/johto_flags.h').read_text()
    m = re.search(r'#define\s+' + guard + r'\s+FLAG_JOHTO_SLICE\((0x[0-9a-fA-F]+)\)', header)
    assert m, 'Bill receipt belongs to the Johto bank'
    offset = int(m[1],16)
    assert len(re.findall(r'FLAG_JOHTO_SLICE\(0x0*' + f'{offset:x}' + r'\)',header,re.I)) == 1, 'Receipt flag slot must be unique'
    print('PASS: independent Eevee receipt flags; failed delivery and Goldenrod entry preserve eligibility')


if __name__ == "__main__":
    validate()
