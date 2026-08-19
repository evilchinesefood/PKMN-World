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
import subprocess, sys, re, os, hashlib

# Runtime symbols scripts need. sMenu is disambiguated by size (the 12-byte definition backs
# script multichoice / yes-no; the other same-named symbols are 4-byte pointers from other TUs).
WANT = [
    "CB2_Overworld",
    "gMain", "gSaveBlock1Ptr", "gSaveBlock2Ptr", "gSaveblock3",
    "gObjectEvents", "gPlayerAvatar",
    # The 64-sprite pool and the 16 OBJ palette tags. CreateSprite/CreateSpriteAtEnd FATAL on
    # exhaustion (src/sprite.c:436/452), so "how close does this map get to the cap" is a
    # measurable quantity rather than something to argue about from object counts.
    "gSprites", "sSpritePaletteTags",
    # The heap. Alloc/AllocZeroed FATAL on exhaustion (src/malloc.c:209/226) and InitWindows
    # fatals at window.c:51 when its buffer alloc fails, so "is the heap draining as you play"
    # is the measurable form of the most plausible overworld red screen.
    "gHeap",
    "gBattleTypeFlags", "gBattlersCount", "gBattleOutcome", "gBattleMons", "gBattleHistory",
    # Post-battle level-up summary. gLevelUpStartLevels is the u8[PARTY_SIZE] of pre-battle levels
    # that drives the box, and sLevelUpSummaryState is its stage machine — the only way a suite can
    # tell "the box is up and waiting for A" apart from "the box never appeared", since the whole
    # thing is drawn straight to VRAM and leaves no other observable.
    "gLevelUpStartLevels", "sLevelUpSummaryState",
    "gParties", "gPartiesCount", "gCurrentRegion",
    "gBagPockets", "sMartInfo",
    "gBackupMapLayout",
    # Tells an overworld-Pokemon collision apart from a grass encounter. ProcessPlayerFieldInput
    # clears it to LOCALID_NONE on every call and a grass roll fires inside that same call, whereas
    # TryTriggerOverworldWildEncounter sets it to the wild mon's local id and starts a script. So
    # non-zero at battle start means "walked into an overworld mon", which no proximity heuristic can
    # establish: the collision test matches previousCoords too, and the FOLLOWER can trigger it.
    "gSpecialVar_LastTalked",
    # The string buffer {STR_VAR_1} expands from. `bufferitemname` is load-bearing on every
    # credential row of the OLIVINE harbour board — OlivinePort_Text_NoPass prints {STR_VAR_1}
    # three times — and WHICH BRANCH RAN is not the same claim as WHAT IT PRINTED: a suite that
    # only checks the player did not sail stays green if the buffer call is deleted and the
    # refusal starts naming nothing. Reading it turns that into an assertion (see
    # OlivineHarborBoard.lua, which seeds EOS into byte 0 first so the check cannot pass on a
    # stale buffer).
    "gStringVar1",
    # The in-game clock. gLocalTime is recomputed from the RTC inside UpdateTimeOfDay() itself
    # (overworld.c:1857), so it is fresh whenever gTimeOfDay is, and a suite can read both to
    # prove the Johto day/night flags agree with the clock rather than with its own seeding.
    "gLocalTime", "gTimeOfDay",
    # sHoursOverride is the debug time menu's lever (SetTimeOfDay, src/overworld.c:4110) and it
    # lives in EWRAM, NOT in the save. That is what makes it the only way to build the state issue
    # #56 item 3 needs: a save whose flags disagree with its own clock. Wind localTimeOffset (which
    # IS saved) to night, override the displayed hour back to day, save, then reboot — EWRAM clears,
    # the override is gone, and the reloaded save reads night against day flags and day objects.
    # gTimeUpdateCounter is the TOD tick's countdown; SetTimeOfDay zeroes it to force an immediate
    # tick, and a suite can do the same instead of idling out a whole period.
    "sHoursOverride", "gTimeUpdateCounter",
    # Issue #55's bedroom-PC checklist. sTopMenuOptionOrder is the load-bearing one: the
    # no-decoration bedroom table and the regular player-PC table have IDENTICAL contents AND an
    # identical count (both {ITEMSTORAGE, MAILBOX, TURNOFF}), so only the table POINTER can tell
    # them apart — which is exactly the key PlayerPC_TurnOff branches on (src/player_pc.c:518).
    # Comparing counts there would be silently wrong.
    "sTopMenuNumOptions", "sTopMenuOptionOrder",
    "sPlayerPC_OptionOrder", "sBedroomPC_OptionOrder", "sBedroomPC_NoDecorOptionOrder",
    # gWindows[sMenu.windowId].window.height IS the drawn frame — AddWindow copies the template
    # verbatim (src/window.c) — so the "snug box" is assertable in RAM, not screenshot-only.
    "gWindows", "gMapHeader", "sGlobalScriptContext",
    # Animated doors. sDoorAnimGraphicsTable is the table GetDoorGraphics() walks, and it is the
    # only place the (metatile id, tileset POINTER) pairing exists at runtime -- a tileset that
    # borrows another tileset's door metatile and has no row of its own simply fails the lookup,
    # FieldAnimateDoorOpen returns -1, and the player warps through a door that never opened. It
    # is a file-local `static`, so nm lists it with a LOWERCASE type letter ('r'); load_syms()
    # keys off the field COUNT, never the type letter, so statics resolve like any other symbol.
    # gTileset_General is not read for its contents. It is the known-good anchor: row 0 of that
    # table is (METATILE_General_Door 0x021, &gTileset_General), so a suite can prove its decode of
    # struct DoorGraphics reproduces the source before trusting any other row.
    "sDoorAnimGraphicsTable", "gTileset_General",
    # The door animation itself. StartDoorAnimationTask is the ONLY caller of
    # CreateTask(Task_AnimateDoor), and it is reached only after GetDoorGraphics returns non-NULL,
    # so "is there a live task whose func is Task_AnimateDoor" is a behavioural read of the same
    # lookup -- an unregistered door never creates one. Also a lowercase-'t' static.
    "gTasks", "Task_AnimateDoor",
    # The four TURN OFF scripts PlayerPC_TurnOff dispatches to. Watching sGlobalScriptContext's
    # scriptPtr land inside one of these proves the shutdown branch independently of the tile,
    # which is what caught issue #57's mis-dispatch (New Bark ran May's script on a female save).
    "LittlerootTown_BrendansHouse_2F_EventScript_TurnOffPlayerPC",
    "LittlerootTown_MaysHouse_2F_EventScript_TurnOffPlayerPC",
    "EventScript_PalletTown_PlayersHouse_2F_ShutDownPC",
    "NewBarkTown_PlayersHouse_2F_EventScript_TurnOffPlayerPC",
]
SIZED = {"sMenu": 12}  # name -> exact byte size to pick among duplicates

# Struct offsets are ABI-fixed (they only change if the struct changes, which is a source edit,
# not a rebuild), so they live here as a curated table rather than being re-derived each build.
# All verified with the repo's own CFLAGS (-mabi=apcs-gnu) via an offsetof probe.
#
# NOTE the SaveBlock3 line is NOT here — it is derived from src/load_save.c's compiler-enforced
# STATIC_ASSERTs by saveblock3_offsets() below. It used to be hand-rebased in this table
# (johtoFlags = 800 is really 768 + 0x20, etc). All six happened to match, but nothing enforced
# it, and a stale SaveBlock3 offset does not crash — it reads zero, which every fixture assert
# accepts. That is a test suite reporting green while proving nothing.
OFFSETS_LUA = """  -- struct offsets (ABI-fixed; verify with an offsetof probe if a struct changes)
  Pokemon      = { size = 100, status = 80, level = 84, hp = 86, maxHP = 88 },
  BoxPokemon   = { size = 80 },
  BattlePokemon= { size = 140, moves = 12, pp = 37, hp = 42, maxHP = 46, status1 = 80 },
  BagPocket    = { stride = 8, itemsPtr = 0, count = 4 },  -- ItemSlot{u16 id,u16 qty} stride 4
  BackupMapLayout = { width = 0, height = 4, map = 8, mapOffset = 7 },
                                                            -- live map grid: map[(x+7) + (y+7)*width],
                                                            -- u16/block, metatile id = bits 0-9 (& 0x3FF)
  MemBlock     = { header = 16, allocated = 0x00, size = 0x04, sizeMask = 0x3FFFF, next = 0x0C },
                                                            -- include/malloc.h: allocated is bit 0
                                                            -- of the u16 at 0, size is bits 0-17 of
                                                            -- the u32 at 4. Walk `next` from gHeap
                                                            -- until it returns to the start.
  Sprite       = { stride = 68, inUse = 0x3E, count = 64 },
                                                            -- inUse is BIT 0 of the u16 at 0x3E
                                                            -- (struct Sprite's first bitfield).
                                                            -- gSprites is [MAX_SPRITES + 1]; only
                                                            -- 0..63 are real, index 64 is the
                                                            -- sentinel CreateSprite* returns on
                                                            -- exhaustion before fataling.
  SpritePalette= { count = 16, free = 0xFFFF },             -- sSpritePaletteTags, TAG_NONE = free
  ObjectEvent  = { stride = 0x24, x = 0x10, y = 0x12, localId = 0x08, facing = 0x18, flags1 = 0x01,
                   graphicsId = 0x04 },
                                                            -- graphicsId is u16; for a follower it is
                                                            --   species + OBJ_EVENT_MON (0x4000), so the
                                                            --   species is (graphicsId & 0x8FFF)
                                                            -- byte0 bit0 = active; coords = map+7
                                                            -- byte0 bit6 = heldMovementActive, bit7 = heldMovementFinished
                                                            -- byte1 (flags1) bit5 = invisible. ACTIVE IS NOT VISIBLE: a follower
                                                            --   pocketed by ScriptHideFollower stays active at its last tile with
                                                            --   this bit set, so an active-only check reads it as still on the map.
                                                            -- facing: low nibble of the u16 at 0x18 (DIR_SOUTH 1 / NORTH 2 / WEST 3 / EAST 4)
  SaveBlock1   = { x = 0, y = 2, mapGroup = 4, mapNum = 5, @SB1@ },
  SaveBlock2   = { encryptionKey = 172, hardModeU16 = 0x16, hardModeBit = 0x10,
                   currentRegion = 0x90, saveVersion = 0x91, followerSlot = 0x93, bp = 3768,
                   playerGender = 8, localTimeOffset = 0x98 },
                                                            -- playerGender: MALE 0 / FEMALE 1. Both
                                                            --   Littleroot bedroom PCs are gender-gated
                                                            --   (Brendan's MALE-only, May's FEMALE-only),
                                                            --   so a suite covering both must seed it.
                                                            -- gLocalTime = sRtc - localTimeOffset
                                                            --   (RtcCalcLocalTime, src/rtc.c:319), so
                                                            --   ADDING hours here SUBTRACTS them from the
                                                            --   in-game clock. This is the only clock lever
                                                            --   a warp-based suite can use: LoadMapFromWarp
                                                            --   zeroes sHoursOverride (overworld.c:989)
                                                            --   eighteen lines before the day/night hook.
  Time         = { size = 8, days = 0, hours = 2, minutes = 3, seconds = 4 },
                                                            -- size is 8, NOT the hand-summed 6
  TimeOfDay    = { MORNING = 0, DAY = 1, EVENING = 2, NIGHT = 3 },
  Menu         = { size = 12, left = 0, top = 1, cursorPos = 2, minCursorPos = 3,
                   maxCursorPos = 4, windowId = 5 },
                                                            -- struct Menu, src/menu.c:38. rows/columns
                                                            --   are NOT written by
                                                            --   InitMenuInUpperLeftCornerNormal, so
                                                            --   reading them is vacuous — row count is
                                                            --   maxCursorPos + 1.
  Window       = { stride = 12, window = 0, bg = 0, tilemapLeft = 1, tilemapTop = 2,
                   width = 3, height = 4 },
                                                            -- gWindows[i].window is a verbatim copy of
                                                            --   the WindowTemplate (sizeof 8), and
                                                            --   .height is what the frame is drawn at.
  MapHeader    = { mapLayout = 0x00, mapLayoutId = 0x12 },
  MapLayout    = { width = 0x00, height = 0x04, border = 0x08, map = 0x0C,
                   primaryTileset = 0x10, secondaryTileset = 0x14,
                   isFrlg = 0x18, borderWidth = 0x19, borderHeight = 0x1A, isJohto = 0x1B },
                                                            -- gMapHeader.mapLayout is the pointer
                                                            --   GetDoorGraphics compares against, so a
                                                            --   suite reading these two tileset pointers
                                                            --   is comparing exactly what the game does
                                                            --   and needs no per-tileset symbol.
  Tileset      = { size = 0x18, flags0 = 0x00, flags1 = 0x01, tiles = 0x04, palettes = 0x08,
                   metatiles = 0x0C, metatileAttributes = 0x10, callback = 0x14,
                   isSecondaryBit = 1 << 0, hasFrlgAttributesBit = 1 << 1 },
                                                            -- flags1 is the byte holding the two 1-bit
                                                            --   fields; little-endian bitfields fill from
                                                            --   the LSB, so isSecondary is bit 0 and
                                                            --   hasFrlgAttributes bit 1. The latter, NOT
                                                            --   MapLayout.isFrlg, selects the attribute
                                                            --   width (src/fieldmap.c, issue #53).
  DoorGraphics = { stride = 20, metatileNum = 0, tileset = 4, sound = 8, size = 9,
                   tiles = 12, palettes = 16 },
                                                            -- struct DoorGraphics, src/field_door.c. The
                                                            --   u16 metatileNum is followed by 2 bytes of
                                                            --   alignment padding before the pointer, so
                                                            --   the stride is 20 and NOT the hand-summed
                                                            --   18. GetDoorGraphics terminates on
                                                            --   `tiles == NULL`, not on the whole row
                                                            --   being zero -- one live row (0x3B0) has a
                                                            --   NULL TILESET and must still be walked.
  Task         = { stride = 40, func = 0, isActive = 4, count = 16, data = 8 },
                                                            -- struct Task, include/task.h. func holds a
                                                            --   Thumb pointer, so compare it to a symbol
                                                            --   address with the low bit masked off.
  ScriptCtx    = { scriptPtr = 8 },                         -- struct ScriptContext
  Hours        = { MORNING_BEGIN = 6, MORNING_END = 10, DAY_BEGIN = 10, DAY_END = 19,
                   EVENING_BEGIN = 19, EVENING_END = 20, NIGHT_BEGIN = 20, NIGHT_END = 6 },
                                                            -- OW_TIMES_OF_DAY = GEN_LATEST. Only TIME_NIGHT
                                                            --   counts as night for the Johto HIDE flags.
"""

# The SaveBlock3 banks the Lua suites read, as offsets from the START of SaveBlock3.
# Source of truth: the STATIC_ASSERTs in src/load_save.c, which the compiler enforces every build.
SB3_FIELDS = ["regionVars", "johtoFlags", "usmSaved", "kantoTrainerFlags",
              "route5DayCareMon", "obstacleTableHash", "clearedObstacleBits",
              "johtoTrainerFlags"]

# The SaveBlock1 banks the suites read, derived the same way and for the same reason. These WERE
# hardcoded in the table above and silently rotted across save format v7: flags moved 4728 -> 5524
# and vars 5246 -> 6042, so a suite writing a flag wrote into neighbouring save data, read its own
# write back, and agreed with itself while the game saw nothing.
SB1_FIELDS = ["flags", "vars", "money"]


def load_save_src(root):
    path = os.path.join(root, "src", "load_save.c")
    try:
        return path, open(path, encoding="utf-8", errors="replace").read()
    except OSError as e:
        sys.exit(f"cannot read {path} to derive save-block offsets: {e}")


def saveblock1_offsets(root):
    """Derive SaveBlock1 bank offsets from load_save.c's asserts instead of hardcoding them."""
    path, src = load_save_src(root)
    out = {}
    for field in SB1_FIELDS:
        m = re.search(r"offsetof\s*\(\s*struct\s+SaveBlock1\s*,\s*" + field
                      + r"\s*\)\s*==\s*(0x[0-9a-fA-F]+|\d+)", src)
        if not m:
            sys.exit(f"{path}: no STATIC_ASSERT pinning offsetof(struct SaveBlock1, {field}) — "
                     f"the Lua suites read that bank and would silently read the wrong address")
        out[field] = int(m.group(1), 0)
    return out


def saveblock3_offsets(root):
    """Derive SaveBlock3 bank offsets from load_save.c's asserts instead of hand-rebasing them."""
    path, src = load_save_src(root)

    m = re.search(r"offsetof\s*\(\s*struct\s+SaveBlock3\s*,\s*region\s*\)\s*==\s*(0x[0-9a-fA-F]+|\d+)", src)
    if not m:
        sys.exit(f"{path}: no STATIC_ASSERT pinning offsetof(struct SaveBlock3, region) — "
                 f"cannot derive the Lua offsets; restore the assert or update this generator")
    base = int(m.group(1), 0)

    out = {}
    for field in SB3_FIELDS:
        m = re.search(r"offsetof\s*\(\s*struct\s+RegionSave\s*,\s*" + field
                      + r"\s*\)\s*==\s*(0x[0-9a-fA-F]+|\d+)", src)
        if not m:
            sys.exit(f"{path}: no STATIC_ASSERT pinning offsetof(struct RegionSave, {field}) — "
                     f"the Lua suites read that bank and would silently read the wrong address")
        out[field] = base + int(m.group(1), 0)
    return out


# Values a door suite has to agree with the game about. These live in headers rather than in
# load_save.c, so there is no STATIC_ASSERT to key off — but they are still DERIVED, because every
# one of them is a silent-wrong-answer if it rots. MB_ANIMATED_DOOR is an unnumbered enum member,
# so inserting a behaviour above it renumbers it and a hardcoded 105 would then match some other
# behaviour entirely; the primary metatile counts pick which half of the tileset pair a metatile id
# belongs to, and getting that wrong reads a completely different tileset's attributes.
def behavior_enum(root):
    """Number the MB_* enum in include/constants/metatile_behaviors.h."""
    path = os.path.join(root, "include", "constants", "metatile_behaviors.h")
    try:
        src = open(path, encoding="utf-8", errors="replace").read()
    except OSError as e:
        sys.exit(f"cannot read {path} to derive metatile behaviours: {e}")
    src = re.sub(r"//[^\n]*", "", re.sub(r"/\*.*?\*/", "", src, flags=re.S))
    m = re.search(r"enum\s*\{(.*?)\}\s*;", src, re.S)
    if not m:
        sys.exit(f"{path}: could not find the MB_* enum")
    values, counter = {}, 0
    for entry in m.group(1).split(","):
        entry = entry.strip()
        if not entry:
            continue
        if "=" in entry:
            name, val = entry.split("=", 1)
            counter, name = int(val.strip(), 0), name.strip()
        else:
            name = entry
        values[name] = counter
        counter += 1
    return values


def defines(path, prefix, names):
    """Parse `#define <PREFIX>FOO 0x123` style constants, failing loudly on a missing one."""
    out, pat = {}, re.compile(r"^\s*#define\s+(" + re.escape(prefix)
                              + r"\w+)\s+\(?\s*(0[xX][0-9a-fA-F]+|\d+)\s*\)?\s*$")
    try:
        text = open(path, encoding="utf-8", errors="replace").read()
    except OSError as e:
        sys.exit(f"cannot read {path}: {e}")
    for line in text.splitlines():
        m = pat.match(re.sub(r"//[^\n]*", "", line))
        if m:
            out[m.group(1)] = int(m.group(2), 0)
    for n in names:
        if n not in out:
            sys.exit(f"{path}: no `#define {n}` — the Lua suites need it and would otherwise "
                     f"assume a value that has already changed")
    return out


def door_constants(root):
    beh = behavior_enum(root)
    for n in ("MB_ANIMATED_DOOR", "MB_PETALBURG_GYM_DOOR"):
        if n not in beh:
            sys.exit(f"include/constants/metatile_behaviors.h: {n} not found")
    counts = defines(os.path.join(root, "include", "fieldmap.h"), "NUM_METATILES_",
                     ("NUM_METATILES_IN_PRIMARY", "NUM_METATILES_IN_PRIMARY_FRLG",
                      "NUM_METATILES_TOTAL"))
    attrs = defines(os.path.join(root, "include", "global.fieldmap.h"), "METATILE_ATTR_",
                    ("METATILE_ATTR_BEHAVIOR_MASK", "METATILE_ATTR_BEHAVIOR_MASK_FRLG"))
    grid = defines(os.path.join(root, "include", "global.fieldmap.h"), "MAPGRID_",
                   ("MAPGRID_METATILE_ID_MASK", "MAPGRID_METATILE_ID_SHIFT"))
    return beh, counts, attrs, grid


def rom_hashes(elf):
    """MD5 + SHA1 of the .gba beside the ELF, so a suite can refuse a stale/mismatched ROM."""
    rom = os.path.splitext(elf)[0] + ".gba"
    if not os.path.exists(rom):
        sys.exit(f"ROM not found beside the ELF: {rom} — symbols.lua must be bound to a ROM")
    data = open(rom, "rb").read()
    return os.path.basename(rom), hashlib.md5(data).hexdigest(), hashlib.sha1(data).hexdigest()


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
        # Fail loud on AMBIGUOUS names too, not just missing ones: a file-local static shadowing a
        # global (or a symbol in a discarded section) would otherwise silently resolve to whichever
        # occurrence nm listed first, making every test read the wrong RAM. Add it to SIZED (like
        # sMenu) to disambiguate by size.
        addrs = {a for (a, _s) in ent}
        if len(addrs) > 1:
            sys.exit(f"AMBIGUOUS symbol {name}: {sorted(hex(a) for a in addrs)} "
                     f"— disambiguate by size in SIZED before trusting an address")
        lines.append(f"  {name} = 0x{ent[0][0]:08x},")
    for name, want_size in SIZED.items():
        ent = syms.get(name, [])
        pick = [a for (a, s) in ent if s == want_size]
        if not pick:
            sys.exit(f"symbol {name} with size {want_size} not found in {elf}")
        lines.append(f"  {name} = 0x{pick[0]:08x},  -- {want_size}-byte definition (cursorPos at +2)")

    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    sb1 = saveblock1_offsets(root)
    sb3 = saveblock3_offsets(root)
    romName, romMD5, romSHA1 = rom_hashes(elf)

    print("-- AUTO-GENERATED from pokemonworld.elf by Testing/GenLuaSymbols.py — do not edit.")
    print("-- Regenerated every build (`make symbols`); addresses move each rebuild.")
    print("return {")
    print("\n".join(lines))
    print(OFFSETS_LUA.replace("@SB1@", ", ".join(f"{k} = {sb1[k]}" for k in SB1_FIELDS)), end="")
    # Derived from src/load_save.c's compiler-enforced asserts — never hand-edit these.
    print("  SaveBlock3   = { " + ", ".join(f"{k} = {sb3[k]}" for k in SB3_FIELDS) + " },")
    # Derived from the headers by door_constants() — never hand-edit these either.
    beh, counts, attrs, grid = door_constants(root)
    print("  MetatileBehavior = { ANIMATED_DOOR = %d, PETALBURG_GYM_DOOR = %d },"
          % (beh["MB_ANIMATED_DOOR"], beh["MB_PETALBURG_GYM_DOOR"]))
    print("                                                            "
          "-- MetatileBehavior_IsDoor() accepts exactly")
    print("                                                            "
          "--   these two (src/metatile_behavior.c).")
    print("  Metatiles    = { inPrimary = %d, inPrimaryFrlg = %d, total = %d,"
          % (counts["NUM_METATILES_IN_PRIMARY"], counts["NUM_METATILES_IN_PRIMARY_FRLG"],
             counts["NUM_METATILES_TOTAL"]))
    print("                   behaviorMask = 0x%08X, behaviorMaskFrlg = 0x%08X,"
          % (attrs["METATILE_ATTR_BEHAVIOR_MASK"], attrs["METATILE_ATTR_BEHAVIOR_MASK_FRLG"]))
    print("                   idMask = 0x%04X, idShift = %d },"
          % (grid["MAPGRID_METATILE_ID_MASK"], grid["MAPGRID_METATILE_ID_SHIFT"]))
    print("                                                            "
          "-- GetNumMetatilesInPrimary() picks 640 for an")
    print("                                                            "
          "--   isFrlg OR isJohto layout and 512 otherwise;")
    print("                                                            "
          "--   below that the metatile is the PRIMARY's,")
    print("                                                            "
          "--   above it the SECONDARY's, rebased.")
    print()
    print("  -- Binds this symbol table to the ROM it was generated from. lib.new() refuses to run")
    print("  -- against anything else: `make -j12` does NOT refresh symbols.lua (only `make symbols`")
    print("  -- does), and the ROM actually launched in BizHawk is routinely a stale hand-copy, so")
    print("  -- fresh-symbols-against-old-ROM is the normal accident, not an edge case. gSaveblock3")
    print("  -- is a fixed EWRAM symbol, so that pairing boots happily and reports 8/8 having")
    print("  -- exercised the PREVIOUS build's code.")
    print(f'  romName = "{romName}",')
    print(f'  romMD5  = "{romMD5}",')
    print(f'  romSHA1 = "{romSHA1}",')
    print("}")


if __name__ == "__main__":
    main()
