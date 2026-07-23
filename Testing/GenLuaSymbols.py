#!/usr/bin/env python3
# Generate Testing/lua/symbols.lua from a built pokemonworld.elf.
#
# Every ROM rebuild moves the runtime addresses, which is why the old _pwtest scripts
# hardcoded per-build values and rotted on the next build. This reads them fresh from the
# ELF symbol table so a promoted suite just does `local S = require("symbols")` and never
# edits an address again.
#
# Usage (see the `symbols` make target):
#   python3 Testing/GenLuaSymbols.py pokemonworld.elf [arm-none-eabi-nm] > Testing/lua/symbols.lua
#
# The generated file is a build artifact (gitignored) — commit the generator, not its output.
import subprocess, sys, re

# Runtime symbols scripts need. sMenu is disambiguated by size (the 12-byte definition backs
# script multichoice / yes-no; the other same-named symbols are 4-byte pointers from other TUs).
WANT = [
    "CB2_Overworld",
    "gMain", "gSaveBlock1Ptr", "gSaveBlock2Ptr", "gSaveblock3",
    "gObjectEvents", "gPlayerAvatar",
    "gBattleTypeFlags", "gBattlersCount", "gBattleOutcome", "gBattleMons", "gBattleHistory",
    "gParties", "gPartiesCount", "gCurrentRegion",
    "gBagPockets", "sMartInfo",
]
SIZED = {"sMenu": 12}  # name -> exact byte size to pick among duplicates

# Struct offsets are ABI-fixed (they only change if the struct changes, which is a source edit,
# not a rebuild), so they live here as a curated table rather than being re-derived each build.
# All verified with the repo's own CFLAGS (-mabi=apcs-gnu) via an offsetof probe.
OFFSETS_LUA = """  -- struct offsets (ABI-fixed; verify with an offsetof probe if a struct changes)
  Pokemon      = { size = 100, status = 80, level = 84, hp = 86, maxHP = 88 },
  BoxPokemon   = { size = 80 },
  BattlePokemon= { size = 140, moves = 12, pp = 37, hp = 42, maxHP = 46, status1 = 80 },
  BagPocket    = { stride = 8, itemsPtr = 0, count = 4 },  -- ItemSlot{u16 id,u16 qty} stride 4
  ObjectEvent  = { stride = 0x24, x = 0x10, y = 0x12 },     -- byte0 bit0 = active; coords = map+7
  SaveBlock1   = { x = 0, y = 2, mapGroup = 4, mapNum = 5, flags = 4728, vars = 5246, money = 1168 },
  SaveBlock2   = { encryptionKey = 172, hardModeU16 = 0x16, hardModeBit = 0x10,
                   currentRegion = 0x90, followerSlot = 0x93, bp = 3768 },
  SaveBlock3   = { regionVars = 0x20, johtoFlags = 800, usmSaved = 928, kantoTrainerFlags = 941 },
"""


def load_syms(elf, nm):
    out = subprocess.run([nm, "-S", elf], capture_output=True, text=True, check=True).stdout
    by_name = {}          # name -> [(addr, size)]
    for line in out.splitlines():
        parts = line.split()
        if len(parts) == 4:
            addr, size, _typ, name = parts
            by_name.setdefault(name, []).append((int(addr, 16), int(size, 16)))
        elif len(parts) == 3:
            addr, _typ, name = parts
            by_name.setdefault(name, []).append((int(addr, 16), 0))
    return by_name


def main():
    if len(sys.argv) < 2:
        sys.exit("usage: GenLuaSymbols.py <pokemonworld.elf> [nm]")
    elf = sys.argv[1]
    nm = sys.argv[2] if len(sys.argv) > 2 else "arm-none-eabi-nm"
    syms = load_syms(elf, nm)

    lines = []
    for name in WANT:
        ent = syms.get(name)
        if not ent:
            sys.exit(f"symbol not found in {elf}: {name}")
        lines.append(f"  {name} = 0x{ent[0][0]:08x},")
    for name, want_size in SIZED.items():
        ent = syms.get(name, [])
        pick = [a for (a, s) in ent if s == want_size]
        if not pick:
            sys.exit(f"symbol {name} with size {want_size} not found in {elf}")
        lines.append(f"  {name} = 0x{pick[0]:08x},  -- {want_size}-byte definition (cursorPos at +2)")

    print("-- AUTO-GENERATED from pokemonworld.elf by Testing/GenLuaSymbols.py — do not edit.")
    print("-- Regenerated every build (`make symbols`); addresses move each rebuild.")
    print("return {")
    print("\n".join(lines))
    print(OFFSETS_LUA, end="")
    print("}")


if __name__ == "__main__":
    main()
