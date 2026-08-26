#!/usr/bin/env python3
"""Host-side pin for Celio's first-meeting gifts (#205 leftover).

The cutscene MUST still end (Bill walks off, scene var leaves 0 so ON_FRAME cannot replay).
A full Key Items pocket must not consume the offers: Meteorite is additem-then-check, and
Celio's later talk re-offers missing Tri Pass / Town Map / Meteorite.

Run from the repo root: python3 Testing/ValidateCelioGifts.py
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "data/maps/OneIsland_PokemonCenter_1F_Frlg/scripts.inc")


def stripped_lines(text):
    out = []
    for i, raw in enumerate(text.splitlines(), 1):
        s = raw.split("@", 1)[0].rstrip()
        if s.strip():
            out.append((i, s))
    return out


def main():
    with open(SRC, encoding="utf-8", errors="replace") as fh:
        text = fh.read()
    lines = stripped_lines(text)
    bad = []

    # Meteorite: additem must be followed by a VAR_RESULT check before the next additem/giveitem.
    met = next(((i, n, s) for i, (n, s) in enumerate(lines) if "additem ITEM_METEORITE" in s), None)
    if met is None:
        bad.append("additem ITEM_METEORITE missing from One Island PC scripts")
    else:
        i, n, _ = met
        nxtn, nxts = lines[i + 1]
        if "VAR_RESULT" not in nxts:
            bad.append(f"{SRC}:{n}: additem ITEM_METEORITE is not followed by a VAR_RESULT check "
                       f"(next at {nxtn}: {nxts.strip()!r})")

    # Celio talk must re-offer the Tri Pass. The first-meeting parent always advances the
    # scene var, so the only way a full bag is recoverable is checkitem on later talk.
    celio = re.search(r"^OneIsland_PokemonCenter_1F_EventScript_Celio::\s*$", text, re.M)
    if not celio:
        bad.append("EventScript_Celio missing")
    else:
        rest = text[celio.end():]
        nxt = re.search(r"^[A-Za-z0-9_]+::\s*$", rest, re.M)
        body = rest[:nxt.start()] if nxt else rest
        if "checkitem ITEM_TRI_PASS" not in body and "TryGiveMissedFirstGifts" not in body:
            bad.append("EventScript_Celio never re-offers ITEM_TRI_PASS "
                       "(need checkitem or call TryGiveMissedFirstGifts)")

    # FLAG_SYS_SEVII_MAP_123 must not be set in MeetCelioScene itself: that script always
    # reaches the flag even when ReceiveTownMap's additem failed.
    meet = re.search(r"^OneIsland_PokemonCenter_1F_EventScript_MeetCelioScene::\s*$", text, re.M)
    if meet:
        rest = text[meet.end():]
        nxt = re.search(r"^[A-Za-z0-9_]+::\s*$", rest, re.M)
        body = rest[:nxt.start()] if nxt else rest
        if re.search(r"^\s*setflag FLAG_SYS_SEVII_MAP_123\s*$", body, re.M):
            bad.append("MeetCelioScene sets FLAG_SYS_SEVII_MAP_123 unconditionally; "
                       "move it onto the Town Map / extra-page success path")

    if bad:
        for b in bad:
            sys.stderr.write(f"FAIL {b}\n")
        return 1
    print("OK — Celio first gifts: Meteorite is checked, later talk can re-offer, "
          "Sevii map flag is not set from the cutscene parent.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
