#!/usr/bin/env python3
"""Generate Testing/lua/fixtures/v7renumber.srm, the input VerifyMapRenumber needs.

Why this script exists rather than a committed blob
---------------------------------------------------
VerifyMapRenumber proves the v9 migration that renumbers the maps left behind when
MAP_GOLDENROD_CITY_DEPARTMENT_STORE_7FNIGHT (gMapGroup_IndoorGoldenrod index 11) and
MAP_MT_SILVER_SUMMIT_NIGHT (gMapGroup_MtSilver index 9) were deleted. Neither was last in its
group, so the 17 Goldenrod maps and 3 Mt Silver maps after them renumbered down by one. mapNum
is persisted in SaveBlock1's WarpDatas, so a pre-v9 save silently re-points at the neighbouring
room -- for lastHealLocation, that means whiting out somewhere the player never healed.

Proving it needs a save whose warps actually sit in those groups. The original crafted fixture was
made from the owner's real playthrough save, which is why it was never committed and why the suite
has been unrunnable from a clean checkout ever since. Testing/MakeMigrationFixtures.sh states the
project rule plainly: "Fixtures come from FRESH new-games only -- no personal data, deterministic.
Never commit a .srm harvested from a real playthrough."

So this builds the same fixture from v7.srm, which is already a tracked fresh-new-game save. The
only edits are two WarpData group/num pairs. Everything else -- trainer name GEKI, 1m05s of play
time, empty party -- is the fresh save's own, so the result carries no personal data and anyone
can regenerate it byte-for-byte.

Usage:
    python3 Testing/MakeRenumberFixture.py            # write the fixture
    python3 Testing/MakeRenumberFixture.py --check    # verify the committed one still matches
"""
import argparse
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import SavePatch as SP  # noqa: E402  (needs HERE on the path first)

SRC = os.path.join(HERE, 'lua', 'fixtures', 'v7.srm')
DST = os.path.join(HERE, 'lua', 'fixtures', 'v7renumber.srm')

# Pre-deletion indices, i.e. what a v7 save written before the twins were removed would hold.
# The migration must pull each down by one, because both sit AFTER the deleted index in their
# group. These are the two the suite asserts on.
#   84/19 GoldenrodCity_RadioTower_1F -> must become 84/18
#   97/11 Route28                     -> must become 97/10
EDITS = {'lastHealLocation': (84, 19), 'escapeWarp': (97, 11)}


def build():
    with open(SRC, 'rb') as f:
        original = f.read()

    # Guard 1: prove the writer is faithful BEFORE trusting it with an edit. A no-op gather +
    # writeback must reproduce the input byte for byte. If it does not, the slot mapping or the
    # checksum arithmetic is wrong and every "fixture" this script makes would be quietly bogus.
    sv = SP.Save(SRC)
    sv.gather()
    sv.writeback()
    if bytes(sv.flash) != original:
        raise SystemExit('no-op round trip changed the file; refusing to write a fixture')

    # Guard 2: the source must be a pre-v9 save, or there is nothing for the ladder to migrate
    # and the suite would pass vacuously.
    ver = sv.sb2[SP.V['SB2.saveVersion']]
    if ver >= SP.SAVE_FORMAT_VERSION:
        raise SystemExit(f'{SRC} is already v{ver}; need a pre-v{SP.SAVE_FORMAT_VERSION} save')

    for field, (group, num) in EDITS.items():
        off = SP.V['SB1.' + field]
        sv.sb1[off] = group
        sv.sb1[off + 1] = num
    sv.writeback()
    return ver, bytes(sv.flash)


def describe(blob):
    import tempfile
    with tempfile.NamedTemporaryFile(suffix='.srm', delete=False) as t:
        t.write(blob)
        tmp = t.name
    try:
        sv = SP.Save(tmp)
        sv.gather()
        return {f: sv.warp(f)[:2] for f in EDITS}
    finally:
        os.unlink(tmp)


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--check', action='store_true',
                    help='verify the committed fixture matches what this script generates')
    args = ap.parse_args()

    ver, blob = build()
    got = describe(blob)
    for field, want in EDITS.items():
        if got[field] != want:
            raise SystemExit(f'{field} read back as {got[field]}, expected {want}')

    if args.check:
        if not os.path.exists(DST):
            raise SystemExit(f'missing {DST}; run this script without --check')
        with open(DST, 'rb') as f:
            on_disk = f.read()
        if on_disk != blob:
            raise SystemExit(f'{DST} does not match a fresh generation; regenerate it')
        print(f'OK - {os.path.basename(DST)} matches a fresh generation from '
              f'{os.path.basename(SRC)} (v{ver})')
        return

    with open(DST, 'wb') as f:
        f.write(blob)
    print(f'wrote {DST} ({len(blob)} bytes) from {os.path.basename(SRC)} (v{ver})')
    for field, (g, n) in got.items():
        print(f'  {field:18} {g}/{n}')


if __name__ == '__main__':
    main()
