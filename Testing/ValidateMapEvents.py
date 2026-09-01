#!/usr/bin/env python3
"""Map object-event consistency scanner (host-side, no build needed).

The failures this catches all build, link and boot clean. They are wrong *content*, not wrong
code, so no compiler and no battle test can reject them -- they surface when a player walks up
to an NPC. Three real examples, each of which is now a check below:

  * Slowpoke Well's Kurt was OBJ_EVENT_GFX_BIG_WAILMER_DOLL. The script that talks to him is
    fine; a whale plush pivots to face you and delivers it. -> PROP-ACTS-ALIVE
  * Four Pokemon Centers (Route 32, Mt Silver, Safari Zone Gate, Indigo Plateau) had a second
    OBJ_EVENT_GFX_NURSE standing where the counter Chansey belongs, because the object was
    copied from the nurse next to it. The script attached is still the Chansey script, so the
    duplicate nurse says Chansey's line. -> SCRIPT-GFX-OUTLIER
  * Proton battles as TRAINER_CLASS_MAGMA_ADMIN with TRAINER_PIC_AQUA_ADMIN_M -- a Team Rocket
    executive announced as Team Magma with a Team Aqua portrait. -> TRAINER-FACTION
  * Slowpoke Well staged the Kurt who walks up after Proton on (17,8), the single square joining
    Proton's chamber to the rest of the well. `addobject` put a wall across the only door, and a
    player whose save spawned him there was sealed into a 22-tile dead end. -> CUTSCENE-SEALS-MAP

Run from the repo root:  python3 Testing/ValidateMapEvents.py   (exit 0 = clean, 1 = violations)
or `make validate`. Also run by the pre-push gate (Testing/hooks/pre-push) and Check.yml.

  --report   print every check's findings including the advisory tiers, and the census each
             threshold was tuned against. This is the mode to use when triaging a new hit.
  --strict   promote the advisory tier to failures.

## Two tiers, and why

Some of these checks are decidable: a script symbol either exists or it does not, a local id
either addresses an object or runs off the end of the table, a trainer's class and its portrait
either name the same team or they do not. Those are ERRORS and the tree is at zero, so any new
one fails the build.

The rest are *smells* derived from how the rest of the tree does the same thing -- "this object
disagrees with the 12 other objects that share its script", "these two maps fight the same
trainer id". They are real signal (the duplicate nurses were found by one) but a legitimate
exception is possible, and the tree is NOT at zero on them. Those are REVIEW findings: printed
with a baseline count, and failing only when the count grows or under --strict. A gate nobody
can get to zero gets disabled, so those checks would be worth nothing as errors.

A check earns its way out of the REVIEW tier by being triaged to zero, not by being deleted.
MUTE-STORY-NPC started here with a baseline of 61 and is now an error: every one of the 61 was
read and turned out to be correct, and the exclusions that explain them are recorded on the
check itself.

## Why the thresholds are derived rather than declared

The role checks compare each object against the consensus of every other object that plays the
same role, so they need no table of "a Pokemon Center contains one nurse and one Chansey" -- a
table that would be wrong for the next map someone adds. The cost is that the generic scripts
(0x0, Johto_EventScript_Nop, BattlePyramid_TrainerBattle) attach to arbitrary NPCs and carry no
role at all. Those are excluded by measuring their graphics spread, not by naming them: a script
whose objects use more than MAX_ROLE_GFX distinct sprites is not a role, it is a utility.
--report prints the spread for every multi-sprite script, which is how to check that a newly
generic script got excluded for the right reason.
"""
import collections
import glob
import json
import os
import re
import struct
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

MAPS_GLOB = os.path.join(ROOT, "data/maps/*/map.json")
# data/event_scripts.s holds the Common_/Johto_ scripts that maps attach directly to objects
# (the wireless-club attendant, Johto_EventScript_Nop), so a glob over *.inc alone would report
# every one of their call sites as a dangling reference.
SCRIPT_GLOBS = [os.path.join(ROOT, "data/**/*.inc"), os.path.join(ROOT, "data/**/*.s")]
TRAINERS_PARTY = [os.path.join(ROOT, "src/data/trainers.party"),
                  os.path.join(ROOT, "src/data/trainers_frlg.party")]
CONSTANT_HEADERS = os.path.join(ROOT, "include/constants/*.h")
LAYOUTS_JSON = os.path.join(ROOT, "data/layouts/layouts.json")

# A parse that finds nothing must fail rather than pass: every check is a lookup that succeeds
# vacuously against empty tables, so a moved file or a drifted regex would turn this whole script
# into a no-op that still prints OK. Floors are set well under the real counts.
MIN_MAPS = 900
MIN_OBJECTS = 6000
MIN_SCRIPT_LABELS = 3000
MIN_TRAINERS = 500
MIN_FLAG_DEFS = 2000
MIN_LAYOUTS = 900
# CUTSCENE-SEALS-MAP walks a collision grid, so it needs a floor of its own: if the blockdata
# stopped loading every map would look wall-free and the check would pass on everything.
MIN_COLLISION_MAPS = 900
# Hide flags that are cleared and never set again -- the "spawn and stay" class that
# MUTE-STORY-NPC is still able to judge. See the floor check inside that function.
MIN_SPAWN_AND_STAY_FLAGS = 30
# Heal respawn tiles actually evaluated. 57 entries today; a drop means the map-id
# lookup or heal_locations.json moved and the check is scanning nothing.
MIN_HEAL_RESPAWNS = 50
# How far a heal point may sit from a warp into its own respawn_map. 53 of 56 are the
# apron tile one square south of the door; the two Littleroot bedrooms are 4 away.
MAX_HEAL_DOOR_DIST = 4

# --- SCRIPT-GFX-OUTLIER tuning (see the docstring's last section) ---
# A script must be attached to this many objects before its graphics have a consensus worth
# disagreeing with.
MIN_ROLE_USES = 5
# More distinct sprites than this and the script is a utility that any NPC can carry, not a
# role. 0x0 / Johto_EventScript_Nop / BattlePyramid_TrainerBattle land far above it.
MAX_ROLE_GFX = 3
# The outlier must be a clear minority, not the smaller half of a split. A script that is
# genuinely used by two sprite variants in comparable numbers (the union-room attendant is the
# real case) stays quiet.
OUTLIER_MAX_SHARE_OF_TOP = 0.5

# Faction words that must agree between an overworld sprite, a trainer class, a trainer portrait
# and a trainer's encounter music. These three teams never share members, so a sprite from one
# and a class from another is always a mistake -- which is what made Proton visible.
FACTIONS = ("ROCKET", "MAGMA", "AQUA")

# Sprites that are scenery, furniture or a held object rather than a character. Matched by this
# set plus the _DOLL suffix.
#
# Note what is deliberately NOT here: item balls and poke balls. A ball on a lab table is a
# starter and a ball in New Mauville is an Electrode, and both legitimately run a msgbox and a
# battle. Listing them turned 20 correct upstream objects into findings. OBJ_EVENT_GFX_METEORITE
# is out for the same reason: Birth Island's triangle is a single-frame sprite, so the
# faceplayer in its upstream script is a no-op rather than a whale doll pivoting.
PROP_SPRITES = {
    "OBJ_EVENT_GFX_CUTTABLE_TREE", "OBJ_EVENT_GFX_BREAKABLE_ROCK",
    "OBJ_EVENT_GFX_PUSHABLE_BOULDER", "OBJ_EVENT_GFX_PUSHABLE_BOULDER_FRLG",
    "OBJ_EVENT_GFX_SIGN", "OBJ_EVENT_GFX_GYM_SIGN", "OBJ_EVENT_GFX_TRAINER_TIPS",
    "OBJ_EVENT_GFX_TOWN_MAP", "OBJ_EVENT_GFX_POKEDEX", "OBJ_EVENT_GFX_CLIPBOARD",
    "OBJ_EVENT_GFX_TRUCK", "OBJ_EVENT_GFX_MACHINE",
}

# Vehicles, ambient scenery and legendary encounter objects. These are flag-gated and mute by
# design: you board the SS Tidal through a warp, Marine Cave's Kyogre is fought from a
# coord_event, and OBJ_EVENT_GFX_LIGHT_SPRITE is the lamp that lights up outside Olivine Gym when
# Jasmine returns -- it is used nine times in Blackthorn alone. Unlike PROP_SPRITES these may
# legitimately be walked around by a cutscene, so they are only exempt from the mute-NPC check.
SCENERY_SPRITES = {
    "OBJ_EVENT_GFX_LIGHT_SPRITE", "OBJ_EVENT_GFX_SS_TIDAL", "OBJ_EVENT_GFX_MR_BRINEYS_BOAT",
    "OBJ_EVENT_GFX_SUBMARINE_SHADOW", "OBJ_EVENT_GFX_SEAGALLOP", "OBJ_EVENT_GFX_SS_ANNE",
    "OBJ_EVENT_GFX_CABLE_CAR", "OBJ_EVENT_GFX_KECLEON_BRIDGE_SHADOW",
    "OBJ_EVENT_GFX_GROUDON_SIDE", "OBJ_EVENT_GFX_GROUDON_FRONT", "OBJ_EVENT_GFX_GROUDON_ASLEEP",
    "OBJ_EVENT_GFX_KYOGRE_SIDE", "OBJ_EVENT_GFX_KYOGRE_FRONT", "OBJ_EVENT_GFX_KYOGRE_ASLEEP",
    "OBJ_EVENT_GFX_RAYQUAZA", "OBJ_EVENT_GFX_DEOXYS", "OBJ_EVENT_GFX_HOOH", "OBJ_EVENT_GFX_LUGIA",
}

# What separates a prop from a character is not whether it has a script -- a plush doll on a
# shelf legitimately runs `msgbox "It's a POKéMON plush doll"`, and so does Lorelei's Lapras
# doll. It is whether the script treats the object as *animate*: `faceplayer` turns it toward
# you and `applymovement` walks it around, and scenery can do neither. Kurt-as-a-Wailmer-doll
# ran `lock / faceplayer / msgbox`; every legitimate prop script in the tree examines the object
# without ever turning it.
ANIMATE_CMDS = re.compile(r"^(faceplayer|applymovement|turnobject)\b")

# Commands that actually start a trainer battle. `trainerbattle` covers the ordinary maps;
# `facilitytrainerbattle` is how the Battle Frontier facilities (Pyramid, Tower, Dome...) fight,
# and their objects carry a real trainer_type, so omitting it reported all 64 of them.
# No \b after the name: the real spellings are trainerbattle_single / _double / _no_intro, and
# an underscore is a word character, so \b would refuse to match any of them.
BATTLE_CMDS = re.compile(r"^(facility)?(do)?trainerbattle\w*\s")

# Hide flags that carry no story meaning, so an object behind one is not a "story-gated NPC":
# decorative leftovers and the ambient day/night overworld-Pokemon spawns are deliberately one
# flag across the whole region, and the item/temp/system prefixes are bookkeeping.
SHARED_FLAG_OK = {"FLAG_HIDE_JOHTO_DECOR", "FLAG_DAY_POKEMON", "FLAG_NIGHT_POKEMON",
                  "FLAG_MORN_POKEMON", "0", ""}
SHARED_FLAG_OK_PREFIX = ("FLAG_TEMP", "FLAG_ITEM", "FLAG_HIDDEN_ITEM", "FLAG_UNUSED",
                         "FLAG_SYS", "FLAG_DAILY", "FLAG_VISITED")

# Trainer ids that really are battled from more than one map, on purpose. Named here rather than
# folded into REVIEW_BASELINE's count so that each one carries its reason and a NEW collision on
# an unlisted id still fails, and so that an entry which stops firing is reported as stale instead
# of quietly covering for a future bug. Keep the reason in the value: it is what a reviewer reads.
DUPLICATE_TRAINER_OK = {
    # Vanilla Emerald's two rival placements around Rustboro. The player fights the rival on
    # Route 104 before Rustboro (gated on FLAG_DEFEATED_RIVAL_ROUTE_104) or outside the Devon
    # building after it (FLAG_DEFEATED_RIVAL_RUSTBORO) -- two scenes, two story flags, and both
    # use trainerbattle_no_intro, which never reads the trainer's defeat flag. One id per starter
    # per rival, so six.
    "TRAINER_BRENDAN_RUSTBORO_TREECKO": "Route104 / RustboroCity rival scenes, vanilla",
    "TRAINER_BRENDAN_RUSTBORO_TORCHIC": "Route104 / RustboroCity rival scenes, vanilla",
    "TRAINER_BRENDAN_RUSTBORO_MUDKIP":  "Route104 / RustboroCity rival scenes, vanilla",
    "TRAINER_MAY_RUSTBORO_TREECKO":     "Route104 / RustboroCity rival scenes, vanilla",
    "TRAINER_MAY_RUSTBORO_TORCHIC":     "Route104 / RustboroCity rival scenes, vanilla",
    "TRAINER_MAY_RUSTBORO_MUDKIP":      "Route104 / RustboroCity rival scenes, vanilla",
    # Gabby & Ty relocate between Route 111, 118 and 120 as VAR_GABBY_AND_TY_STATE advances, and
    # only one site is ever unhidden (FLAG_HIDE_ROUTE_{111,118,120}_GABBY_AND_TY_*). _6 is their
    # final party, and gabby_and_ty.inc does `cleartrainerflag TRAINER_GABBY_AND_TY_6` outright
    # "to allow infinite rematches" -- the shared defeat flag is the feature. Vanilla.
    "TRAINER_GABBY_AND_TY_6": "roaming interview duo, flag cleared on purpose for rematches",
    # Jessie & James turn up at five sites (Mt. Moon, Rocket Hideout, Slowpoke Well, Radio Tower,
    # Route 118) with one id pair for the early appearances and one for the late ones. Every site
    # uses trainerbattle_two_trainers, which reads no defeat flag, and each has its own
    # FLAG_HIDE_JESSIE_JAMES_* so exactly one is live at a time.
    "TRAINER_ROCKET_JESSIE":   "5-site recurring duo, trainerbattle_two_trainers, per-site hide flag",
    "TRAINER_ROCKET_JAMES":    "5-site recurring duo, trainerbattle_two_trainers, per-site hide flag",
    "TRAINER_ROCKET_JESSIE_2": "5-site recurring duo, trainerbattle_two_trainers, per-site hide flag",
    "TRAINER_ROCKET_JAMES_2":  "5-site recurring duo, trainerbattle_two_trainers, per-site hide flag",
}

# Object-id arguments. A bare integer here is a landmine: inserting one object into the map json
# renumbers every object after it and these silently start addressing the wrong NPC. This is how
# Slowpoke Well ended up with `removeobject 11/12/13` hard-coding three Rocket grunts.
OBJECT_ID_CMDS = ("addobject", "removeobject", "applymovement", "turnobject", "faceplayer",
                  "showobjectat", "hideobjectat", "showobject", "hideobject",
                  "setobjectxy", "setobjectmovementtype", "copyobjectxytoperm",
                  "waitmovement", "moveobjectoffscreen", "setobjectsubpriority")
# Object-id slots where 0 means "the player" (OBJ_EVENT_ID_PLAYER), not object 0.
PLAYER_IS_ZERO = True

# Baseline REVIEW counts. These are the findings that exist in the tree today and have not been
# triaged. The gate is the count, not the contents: fixing one and introducing another still
# passes, but adding one fails. Lower these as they get triaged; never raise one without saying
# why in the commit.
REVIEW_BASELINE = {
    # Was 21: Johto maps reusing Hoenn trainer ids (Victory Road, Goldenrod Underground,
    # Radio Tower, Mt. Mortar). Those Johto copies now have dedicated TRAINER_*_JT ids.
    # Stays 0 through the 2026-08-26 widening: the check now counts every trainerbattle* in a
    # map's scripts instead of only the ones behind an object with a trainer_type, and the
    # legitimate cross-map reuse that surfaced is named in DUPLICATE_TRAINER_OK rather than
    # absorbed into this number. Raising this hides a real pre-defeated trainer.
    "DUPLICATE-TRAINER": 0,
    "NUMERIC-LOCALID": 0,
    # One: EventScript_Whirlpool is deliberately shared by two kinds of object. Each of the 8
    # whirlpool sites is an OBJ_EVENT_GFX_WHIRLPOOL marker ringed by four invisible
    # OBJ_EVENT_GFX_ARCHER blockers, and ALL 40 run the same script so the player can trigger the
    # crossing by bumping any of them -- which is the whole point, since the blockers are what
    # they actually walk into. 8 markers against 32 blockers reads as an outlier to this check.
    # Upstream is identical. A SECOND entry here means a script really did get shared by accident.
    "SCRIPT-GFX-OUTLIER": 1,
    # Nine upstream cutscene actors staged on the tile just inside a door -- the rival at the top
    # of the stairs in Littleroot, Archie and two grunts at the Oceanic Museum landing, Wallace
    # and Birch in the Champions Room. Each is real by this check's definition and harmless in
    # practice, because the scene walks the actor off that tile within a few commands and never
    # hands control back in between. They are the baseline rather than exceptions in code: what
    # made Slowpoke Well's Kurt a soft-lock was not the staging, it was that he outlived the
    # scene, and no static check can tell those apart. A new entry means someone put an actor on
    # a doorway and should say which of the two it is.
    "CUTSCENE-SEALS-MAP": 9,
}


def die(msg):
    print(f"FAIL - {msg}")
    sys.exit(1)


# ---------------------------------------------------------------- loading

def load_maps():
    maps = {}
    for path in sorted(glob.glob(MAPS_GLOB)):
        with open(path, encoding="utf-8") as fh:
            data = json.load(fh)
        data["_path"] = os.path.relpath(path, ROOT)
        maps[data["name"]] = data
    return maps


def load_script_labels():
    """label -> list of stripped body lines, for every `Label::` in data/**/*.inc.

    Also returns which map directory each label came from, so a numeric object id can be
    resolved against the right map's object table.
    """
    bodies = {}
    owner = {}
    for pattern in SCRIPT_GLOBS:
        for path in sorted(glob.glob(pattern, recursive=True)):
            rel = os.path.relpath(path, ROOT)
            mapdir = None
            m = re.match(r"data/maps/([^/]+)/scripts\.inc$", rel)
            if m:
                mapdir = m.group(1)
            cur = None
            with open(path, encoding="utf-8", errors="replace") as fh:
                for line in fh:
                    lm = re.match(r"^(\w+)::?\s*$", line)
                    if lm:
                        cur = lm.group(1)
                        bodies[cur] = []
                        owner[cur] = (rel, mapdir)
                    elif cur is not None:
                        bodies[cur].append(line.split("@")[0].strip())
    return bodies, owner


def load_collision():
    """map layout id -> (width, height, [row][col] collision), for layouts with blockdata.

    A metatile in map.bin is one u16: id in bits 0-9, collision in 10-11, elevation in 12-15.
    Only the collision nibble is read here; 0 is walkable and anything else is a wall.
    """
    with open(LAYOUTS_JSON, encoding="utf-8") as fh:
        layouts = json.load(fh)["layouts"]
    grids = {}
    for lay in layouts:
        if not lay or not lay.get("blockdata_filepath"):
            continue
        path = os.path.join(ROOT, lay["blockdata_filepath"])
        w, h = lay.get("width", 0), lay.get("height", 0)
        if not (w and h) or not os.path.exists(path):
            continue
        with open(path, "rb") as fh:
            raw = fh.read()
        if len(raw) < w * h * 2:
            continue
        cells = struct.unpack("<%dH" % (w * h), raw[:w * h * 2])
        grids[lay["id"]] = (w, h, [[(cells[y * w + x] >> 10) & 3 for x in range(w)]
                                   for y in range(h)])
    return grids


def load_flag_defs():
    flags = set()
    for path in glob.glob(CONSTANT_HEADERS):
        with open(path, encoding="utf-8", errors="replace") as fh:
            for m in re.finditer(r"^#define\s+(FLAG_\w+)", fh.read(), re.M):
                flags.add(m.group(1))
    return flags


def load_trainers():
    """TRAINER_X -> {name, cls, pic, music} from the .party files."""
    out = {}
    for path in TRAINERS_PARTY:
        if not os.path.exists(path):
            continue
        text = open(path, encoding="utf-8", errors="replace").read()
        parts = re.split(r"^=== (TRAINER_\w+) ===$", text, flags=re.M)
        for name, body in zip(parts[1::2], parts[2::2]):
            head = body.split("\n\n", 1)[0]

            def field(key):
                m = re.search(rf"^{key}: (.+)$", head, re.M)
                return m.group(1).strip() if m else ""

            out[name] = {"name": field("Name"), "cls": field("Class"),
                         "pic": field("Pic"), "music": field("Music"),
                         "file": os.path.relpath(path, ROOT)}
    return out


# ---------------------------------------------------------------- helpers

def normalize_gfx(gfx):
    """Collapse spellings of the same character so they do not read as a disagreement.

    OBJ_EVENT_GFX_SPECIES(CHANSEY) and OBJ_EVENT_GFX_CHANSEY are the dynamic and the static
    sprite for one Pokemon, and _FRLG is a regional art variant of the same role. Neither is a
    content mismatch, so both fold into one key before the outlier vote.
    """
    m = re.match(r"OBJ_EVENT_GFX_SPECIES(?:_SHINY|_FEMALE)*\((\w+)\)", gfx)
    if m:
        return m.group(1)
    base = gfx[len("OBJ_EVENT_GFX_"):] if gfx.startswith("OBJ_EVENT_GFX_") else gfx
    return re.sub(r"_FRLG$", "", base)


def faction_of(*names):
    """The single team named across these identifiers, or None if zero or several."""
    found = {f for f in FACTIONS for n in names if n and f in n}
    return found.pop() if len(found) == 1 else None


def script_trainers(body_lines):
    ids = []
    for line in body_lines:
        for m in re.finditer(r"\b(TRAINER_\w+)", line):
            # TRAINER_NONE is the null sentinel and has an entry in trainers.party like any
            # other id, so it has to be named here rather than filtered by existence.
            if m.group(1) not in ("TRAINER_TYPE_NONE", "TRAINER_TYPE_NORMAL", "TRAINER_NONE",
                                  "TRAINER_TYPE_SEE_ALL_DIRECTIONS", "TRAINER_TYPE_BURIED"):
                ids.append(m.group(1))
    return ids


def has_trainerbattle(body_lines):
    return any(BATTLE_CMDS.match(l) for l in body_lines)


def reachable_labels(label, bodies, seen=None, depth=0):
    """`label` plus every label it goto/call's, in traversal order.

    Split out of reachable_bodies so a check can ask WHICH script a line came from and not
    just what the lines are; reachable_bodies is now a thin wrapper over it and behaves
    exactly as before (same order, same `seen` sharing, same depth cap).
    """
    if seen is None:
        seen = set()
    if label in seen or depth > 12 or label not in bodies:
        return []
    seen.add(label)
    labels = [label]
    for line in bodies[label]:
        m = re.match(r"(?:goto|call|goto_if\w*|call_if\w*)\s+(?:[^,]+,\s*)?(\w+)\s*$", line)
        if m and m.group(1) in bodies:
            labels += reachable_labels(m.group(1), bodies, seen, depth + 1)
    return labels


def reachable_bodies(label, bodies, seen=None, depth=0):
    """Lines of `label` plus everything it goto/call's, so a check sees the whole event."""
    lines = []
    for lbl in reachable_labels(label, bodies, seen, depth):
        lines += bodies[lbl]
    return lines


# ---------------------------------------------------------------- checks

def check_dangling(maps, bodies, flagdefs):
    """A script or flag named by a map that does not exist anywhere."""
    errs = []
    for name, d in maps.items():
        for i, o in enumerate(d.get("object_events", []), 1):
            s = o.get("script")
            if s and s not in ("NULL", "0x0", "0") and s not in bodies:
                errs.append(f"{name} obj {i}: script '{s}' is not defined in data/**/*.inc")
            f = o.get("flag", "0")
            if f.startswith("FLAG_") and f not in flagdefs:
                errs.append(f"{name} obj {i}: flag '{f}' is not defined in include/constants/")
    return errs


def check_localids(maps, bodies, owner):
    """Object ids in scripts that address nothing, and bare integers that will rot."""
    errs, review = [], []
    for label, (rel, mapdir) in owner.items():
        if not mapdir:
            continue
        mp = next((d for d in maps.values() if d["name"] == mapdir), None)
        if mp is None:
            continue
        count = len(mp.get("object_events", []))
        named = any("local_id" in o for o in mp.get("object_events", []))
        for line in bodies[label]:
            m = re.match(r"(\w+)\s+(.*)$", line)
            if not m or m.group(1) not in OBJECT_ID_CMDS:
                continue
            arg = m.group(2).split(",")[0].strip()
            if not re.fullmatch(r"\d+|0x[0-9a-fA-F]+", arg):
                continue
            val = int(arg, 0)
            if val == 0 and PLAYER_IS_ZERO:
                continue
            if val > count:
                errs.append(f"{mapdir} {label}: {m.group(1)} {val} but the map has only "
                            f"{count} object events")
            elif named:
                obj = mp["object_events"][val - 1]
                review.append(f"{mapdir} {label}: {m.group(1)} {val} is a bare index into a map "
                              f"that uses local_id names (currently {obj['graphics_id']})")
    return errs, review


# There is deliberately no "addobject without a preceding clearflag" check. It looks like it
# should be one -- an object hidden behind a set flag ought not to spawn -- but `addobject` goes
# through TrySpawnObjectEventTemplate, which does NOT read the template's flag; only the map-load
# path (TrySpawnObjectEvents, the plural) filters on FlagGet. So `addobject` spawns a
# flag-hidden object just fine, and FLAG_HIDE_DEOXYS is the proof: it is set at new game and
# never cleared anywhere, yet Birth Island's addobject works. Written as a check it flagged 98
# call sites of untouched upstream code, all of them correct.


def check_prop_acts_alive(maps, bodies):
    """A doll, boulder or sign whose script turns it, walks it, or has it fight.

    Slowpoke Well's Kurt was OBJ_EVENT_GFX_BIG_WAILMER_DOLL running `lock / faceplayer / msgbox`
    -- a whale plush pivoting to face the player and delivering Kurt's dialogue. See ANIMATE_CMDS
    for why turning, not talking, is the test.
    """
    errs = []
    for name, d in maps.items():
        for i, o in enumerate(d.get("object_events", []), 1):
            gfx, s = o["graphics_id"], o.get("script")
            if not s or s in ("NULL", "0x0", "0"):
                continue
            if not (gfx in PROP_SPRITES or gfx.endswith("_DOLL")):
                continue
            lines = reachable_bodies(s, bodies)
            bad = next((l for l in lines if ANIMATE_CMDS.match(l) or BATTLE_CMDS.match(l)), None)
            if bad:
                errs.append(f"{name} obj {i} at ({o['x']},{o['y']}): {gfx} runs '{s}', which "
                            f"does '{bad}' -- scenery cannot turn, walk or battle")
    return errs


def check_trainer_type(maps, bodies):
    """trainer_type set on an object whose script never battles.

    The engine plays the spotted-exclamation approach and then runs a script with no
    trainerbattle in it, so the NPC charges the player and says nothing.
    """
    errs = []
    for name, d in maps.items():
        for i, o in enumerate(d.get("object_events", []), 1):
            tt = o.get("trainer_type", "TRAINER_TYPE_NONE")
            s = o.get("script")
            if tt in ("TRAINER_TYPE_NONE", "0", 0):
                continue
            # HandleBoulderFallThroughHole stores the FLAG_HIDE_* that reveals the
            # boulder on the floor below in trainerType, not a trainer class.
            if o.get("graphics_id") in ("OBJ_EVENT_GFX_PUSHABLE_BOULDER",
                                       "OBJ_EVENT_GFX_PUSHABLE_BOULDER_FRLG"):
                continue
            if not s or s in ("NULL", "0x0", "0"):
                errs.append(f"{name} obj {i}: {tt} with no script at all")
                continue
            if not has_trainerbattle(reachable_bodies(s, bodies)):
                errs.append(f"{name} obj {i}: {tt} but '{s}' contains no trainerbattle -- the "
                            f"NPC approaches the player and then never battles")
    return errs


def check_duplicate_trainer(maps, bodies, owner, trainers):
    """One TRAINER_X battled from two different maps.

    The defeated flag is per trainer id, so beating either one marks both beaten and the second
    NPC becomes a permanently pre-defeated trainer.

    This used to look only at object events whose `trainer_type` was not TRAINER_TYPE_NONE, and
    that gate is what let every collision found in the 2026-08-26 sweep through: each one had a
    TRAINER_TYPE_NONE side, so the id counted on one map only and the gate read clean on a broken
    tree. Mt. Mortar's Kiyo is a gift NPC (no trainer_type, battled from inside his dialogue),
    Mahogany Gym's Pryce object is the standard gym-leader script object, and so were both Wally
    objects. Nothing about a shared defeat flag cares what the object's trainer_type is.

    So attribute every `trainerbattle*` LINE to a map instead, and take the id from that line's
    own arguments:

      * a battle written in `data/maps/<Dir>/scripts.inc` belongs to <Dir>'s map, full stop --
        no object needs to reach it, and its trainer_type is irrelevant;
      * a battle written in a shared script (data/scripts/**) belongs to every map whose object,
        coord or bg events can reach it. That is the mechanism the old check used, kept so the
        FRLG trainer table (data/scripts/trainers_frlg.inc, 227 ids) and the roaming
        Gabby & Ty script stay covered.

    Attributing per line rather than per id is what keeps the two-floor gyms quiet: Lavaridge
    Gym's ELI/JACE/JEFF/KEEGAN battles are written in LavaridgeTown_Gym_1F/scripts.inc but the
    objects that run them stand on LavaridgeTown_Gym_B1F. That is ONE battle site, and a per-id
    union of "file owner" and "object owner" would report it as two. Same shape for
    MtPyre_4F/5F, Route26/Route26North and SSAqua_1F/B1F.

    Only CROSS-map reuse is a collision. Same-map reuse is the norm (~136 ids): the
    trainerbattle_single + trainerbattle_rematch Match Call pair, the gym leaders'
    no_intro + rematch_double set, and trainerbattle_double emitted once per half of a
    pair (TRAINER_KATE_AND_JOY, AMY_AND_LIV_1, ANNA_AND_MEG_1).

    Two things deliberately do NOT count. A trainer named in a comment is invisible because
    load_script_labels strips `@` (BattleFrontier_BattlePyramidFloor's "@ TRAINER_PHILLIP is used
    as a placeholder"). And a bare defeat-flag READ is not a battle, which is why the S.S. Tidal
    submaps need no exception: SSTidalRooms / SSTidalLowerDeck fight those trainers and
    SSTidalCorridor only does `goto_if_not_defeated` on them.
    """
    # Which maps' event scripts can reach each label, for battles in shared (non-map) scripts.
    reach = collections.defaultdict(set)
    for name, d in maps.items():
        entries = [o.get("script") for o in d.get("object_events", [])]
        entries += [e.get("script") for e in d.get("coord_events", [])]
        entries += [e.get("script") for e in d.get("bg_events", [])]
        for s in entries:
            if not s or s in ("NULL", "0x0", "0") or s not in bodies:
                continue
            for lbl in reachable_labels(s, bodies):
                reach[lbl].add(name)

    home_of_dir = {}
    for name, d in maps.items():
        m = re.match(r"data/maps/([^/]+)/map\.json$", d["_path"])
        if m:
            home_of_dir[m.group(1)] = name

    seen = collections.defaultdict(set)
    for label, (rel, mapdir) in owner.items():
        home = home_of_dir.get(mapdir) if mapdir else None
        sites = {home} if home else reach.get(label, set())
        if not sites:
            continue
        for line in bodies[label]:
            if not BATTLE_CMDS.match(line):
                continue
            # Take the id from the battle command's own argument list. TRAINER_NONE and the
            # TRAINER_BATTLE_* type sentinels also appear there without naming a trainer;
            # requiring the id to exist in trainers.party drops them all.
            for t in script_trainers([line]):
                if t in trainers:
                    seen[t] |= sites

    dup = {t: ms for t, ms in seen.items() if len(ms) > 1}
    errs = [f"{t} is battled from {len(ms)} maps ({', '.join(sorted(ms))}) -- one defeated flag "
            f"covers them all"
            for t, ms in sorted(dup.items()) if t not in DUPLICATE_TRAINER_OK]
    # An exception that stops firing has to be deleted, or the next real collision on that id
    # would be waved through by a comment describing a fix that already landed.
    errs += [f"{t} is in DUPLICATE_TRAINER_OK but is no longer battled from more than one map -- "
             f"delete the exception ({DUPLICATE_TRAINER_OK[t]})"
             for t in sorted(DUPLICATE_TRAINER_OK) if t not in dup]
    return errs


def check_trainer_faction(trainers):
    """A trainer whose class, portrait and music do not name the same team.

    Proton is the case that started this: Class TRAINER_CLASS_MAGMA_ADMIN with Pic
    TRAINER_PIC_AQUA_ADMIN_M -- announced as Team Magma, drawn as Team Aqua.
    """
    errs = []
    for t, info in sorted(trainers.items()):
        cf = faction_of(info["cls"])
        pf = faction_of(info["pic"])
        if cf and pf and cf != pf:
            errs.append(f"{t} ({info['file']}): Class {info['cls']} is {cf} but Pic "
                        f"{info['pic']} is {pf}")
    return errs


def check_object_trainer_faction(maps, bodies, trainers):
    """An overworld sprite from one team wired to a trainer from another.

    Catches the half of the faction problem that lives in the map rather than the party file --
    a ROCKET_M standing in a cave who battles as a MAGMA class.
    """
    errs = []
    for name, d in maps.items():
        for i, o in enumerate(d.get("object_events", []), 1):
            gf = faction_of(o["graphics_id"])
            s = o.get("script")
            if not gf or not s or s in ("NULL", "0x0", "0") or s not in bodies:
                continue
            for t in script_trainers(reachable_bodies(s, bodies)):
                info = trainers.get(t)
                if not info:
                    continue
                tf = faction_of(info["cls"], info["pic"])
                if tf and tf != gf:
                    errs.append(f"{name} obj {i}: {o['graphics_id']} ({gf}) battles {t}, whose "
                                f"class/pic are {tf} ({info['cls']} / {info['pic']})")
    return errs


def role_table(maps):
    """script -> Counter of normalized graphics, plus where each spelling is used."""
    by_script = collections.defaultdict(collections.Counter)
    where = collections.defaultdict(list)
    for name, d in maps.items():
        for i, o in enumerate(d.get("object_events", []), 1):
            s = o.get("script")
            if not s or s in ("NULL", "0x0", "0"):
                continue
            key = normalize_gfx(o["graphics_id"])
            by_script[s][key] += 1
            where[(s, key)].append((name, i, o["graphics_id"]))
    return by_script, where


def check_script_gfx_outlier(by_script, where):
    """An object whose sprite disagrees with everyone else running the same script.

    This is what the duplicated Nurse Joys looked like in the data: twelve objects carrying
    CherryGrove_Pokecenter_Chansey were a Chansey and four were a second nurse.
    """
    review = []
    for s, counter in sorted(by_script.items()):
        total = sum(counter.values())
        if total < MIN_ROLE_USES or len(counter) < 2 or len(counter) > MAX_ROLE_GFX:
            continue
        top, top_n = counter.most_common(1)[0]
        for key, n in sorted(counter.items()):
            if key == top or n > top_n * OUTLIER_MAX_SHARE_OF_TOP:
                continue
            sites = where[(s, key)]
            shown = ", ".join(f"{m} obj {i}" for m, i, _ in sites[:6])
            more = f" (+{len(sites) - 6} more)" if len(sites) > 6 else ""
            review.append(f"'{s}': {n}x {sites[0][2]} vs {top_n}x {top} -- {shown}{more}")
    return review


def check_mute_story_npc(maps, bodies, stats):
    """A story-gated NPC that is left standing with nothing to say.

    The object is hidden behind a flag that some script clears and does not set again, so the
    player can walk up to it after that point -- and it has no script.

    ## Why the exclusions below are as broad as they are

    The first version of this check reported 61 objects and every one of them turned out to be
    correct. `script: NULL` on a flag-gated object is the *normal* spelling for scene machinery,
    not a defect, because the player never interacts with it by pressing A:

      * Cutscene puppets. Sprout Tower's Silver is spawned by his hide flag, walked around by
        `applymovement` from a coord event, then `removeobject`ed. Talking to him is not part of
        the scene and never happens -- the coord trigger fires first.
      * Vehicles and scenery. Mr Briney's boat, the SS Tidal, the submarine shadow, and the
        OBJ_EVENT_GFX_LIGHT_SPRITE lamp that switches on outside Olivine Gym when Jasmine comes
        back. Nobody talks to a lamp.
      * Legendaries. Marine Cave's Kyogre is fought from a coord_event trigger, so the object
        itself carries no script by design.

    So a missing script is only evidence of a bug when the object is *not* scene machinery, and
    the mechanical tell for machinery is that something takes it away again: the hide flag is
    re-set somewhere, or the object is explicitly removed. Excluding those leaves zero findings
    today, which is what makes this an error rather than a baselined smell -- a newly added story
    NPC whose flag is only ever cleared, and who was never given dialogue, still fails.

    Note that this would NOT have caught Slowpoke Well's Kurt on its own, and it is not supposed
    to: his object was `addobject`ed and walked through a cutscene like any other puppet. What
    was actually wrong there was the hide-flag collision with Kurt's house, which made the puppet
    reachable during free roam. That is the bug class, and it is not decidable from the data --
    see the note on the dropped cross-map flag check below.
    """
    # A flag that any script sets, and an object that any script removes, both mean the object
    # is taken off the map again -- scene machinery rather than a resident NPC.
    reset_flags = set()
    removed_objects = set()
    for lines in bodies.values():
        for line in lines:
            m = re.match(r"setflag\s+(FLAG_\w+)", line)
            if m:
                reset_flags.add(m.group(1))
            m = re.match(r"removeobject\s+(\S+)", line)
            if m:
                removed_objects.add(m.group(1).rstrip(","))

    persists = collections.defaultdict(list)
    for label, lines in bodies.items():
        open_clears = {}
        for idx, line in enumerate(lines):
            m = re.match(r"clearflag\s+(FLAG_\w+)", line)
            if m:
                open_clears.setdefault(m.group(1), idx)
            m = re.match(r"setflag\s+(FLAG_\w+)", line)
            if m:
                open_clears.pop(m.group(1), None)
        for f in open_clears:
            persists[f].append(label)

    errs = []
    for name, d in sorted(maps.items()):
        for i, o in enumerate(d.get("object_events", []), 1):
            f, gfx = o.get("flag", "0"), o["graphics_id"]
            if o.get("script") not in (None, "NULL", "0x0", "0"):
                continue
            if f in SHARED_FLAG_OK or f.startswith(SHARED_FLAG_OK_PREFIX):
                continue
            # Overworld Pokemon are mute by design and have their own validator.
            if gfx.startswith("OBJ_EVENT_GFX_SPECIES") or gfx in PROP_SPRITES:
                continue
            if gfx in SCENERY_SPRITES or gfx.endswith("_DOLL"):
                continue
            if f not in persists:
                continue
            stats["candidates"] += 1
            if f in reset_flags:
                stats["excluded_flag_reset"] += 1
                continue
            if o.get("local_id") in removed_objects or str(i) in removed_objects:
                stats["excluded_removed"] += 1
                continue
            errs.append(f"{name} obj {i} at ({o['x']},{o['y']}): {gfx} spawns when "
                        f"{f} is cleared (by {persists[f][0]}), is never hidden or removed "
                        f"again, and has no script")
    # The exclusions above are broad -- they drop about nine in ten flag-gated mute objects, and
    # that is the point, because nine in ten are scene machinery. But an exclusion that grew to
    # cover *everything* would leave this check passing on an empty set, which reads exactly like
    # a clean tree. Count the spawn-and-stay hide flags it can still see and fail if that
    # collapses. 56 such flags exist today.
    stats["checkable_flags"] = len({f for f in persists if f.startswith("FLAG_HIDE")
                                    and f not in reset_flags})
    if stats["checkable_flags"] < MIN_SPAWN_AND_STAY_FLAGS:
        die(f"MUTE-STORY-NPC can only see {stats['checkable_flags']} spawn-and-stay hide flags "
            f"(expected >= {MIN_SPAWN_AND_STAY_FLAGS}) -- its exclusions have swallowed the "
            f"check; it would now pass vacuously")
    return errs


def check_cutscene_seals_map(maps, bodies, owner, grids):
    """An `addobject` actor staged on the one tile that joins part of a map to its exits.

    This is the half of the Slowpoke Well trap that map data can be held to. Kurt's template sat
    on (17,8), the single square between Proton's chamber and the rest of the well, so spawning
    him walled a 22-tile pocket off from both warps -- and its only other way out is a STRENGTH
    boulder, which is why boulders count as walls here and not as doors.

    Restricted to `addobject` on purpose. Every object on a map is a potential wall, but almost
    all of them are gated behind a hide flag that the story sets and clears, so asking "could
    this object ever seal the map" reports 132 maps and thousands of tiles -- the Sootopolis
    Wailmer and every gym guard, all working as designed. `addobject` is the decidable case:
    TrySpawnObjectEventTemplate does not read the hide flag, so the actor lands on that tile
    every single time the command runs, whatever the save looks like.
    """
    # One finding per staged actor, not per call site: the Battle Palace opponent is addobject'd
    # from two scripts and is one piece of staging either way.
    staged = collections.defaultdict(set)
    for label, (_rel, mapdir) in sorted(owner.items()):
        if not mapdir:
            continue
        for line in bodies[label]:
            m = re.match(r"addobject\s+([A-Za-z_]\w*)\s*$", line)
            if m:
                staged[(mapdir, m.group(1))].add(label)

    review = []
    for (mapdir, localid), labels in sorted(staged.items()):
        d = maps.get(mapdir)
        if d is None:
            continue
        grid = grids.get(d.get("layout"))
        warps = d.get("warp_events") or []
        if grid is None or not warps:
            continue
        w, h, coll = grid

        def on_map(x, y):
            return 0 <= x < w and 0 <= y < h

        objs = d.get("object_events", [])
        # A pushable boulder needs an HM the player may not carry yet, so it is not an exit.
        walls = {(o["x"], o["y"]) for o in objs
                 if o.get("graphics_id", "").startswith("OBJ_EVENT_GFX_PUSHABLE_BOULDER")}

        def reachable(extra):
            blocked = walls | extra
            seen, queue = set(), collections.deque()
            for wp in warps:
                start = (wp["x"], wp["y"])
                if on_map(*start) and coll[start[1]][start[0]] == 0 and start not in blocked:
                    if start not in seen:
                        seen.add(start)
                        queue.append(start)
            while queue:
                x, y = queue.popleft()
                for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                    if (on_map(nx, ny) and (nx, ny) not in seen
                            and coll[ny][nx] == 0 and (nx, ny) not in blocked):
                        seen.add((nx, ny))
                        queue.append((nx, ny))
            return seen

        o = next((o for o in objs if o.get("local_id") == localid), None)
        if o is None:
            continue
        # A wanderer steps off its template tile on its own, so it is not a permanent wall.
        if not o.get("movement_type", "").startswith(
                ("MOVEMENT_TYPE_NONE", "MOVEMENT_TYPE_FACE_", "MOVEMENT_TYPE_LOOK_AROUND",
                 "MOVEMENT_TYPE_ROTATE_")):
            continue
        tile = (o["x"], o["y"])
        if not on_map(*tile) or coll[tile[1]][tile[0]] != 0:
            continue
        lost = reachable(set()) - reachable({tile}) - {tile}
        if lost:
            review.append(f"{mapdir}: addobject {localid} stages an actor on {tile}, which "
                          f"seals {len(lost)} tile(s) off from every warp on the map while it "
                          f"stands there (from {', '.join(sorted(labels))})")
    return review


# There is deliberately no "one hide flag drives objects on two maps" check either, even though
# a flag collision is exactly what put a mute duplicate Kurt in Slowpoke Well (his object shared
# FLAG_HIDE_KURT_1 with the Kurt in Kurt's house). Sharing one flag across maps is the *normal*
# way to hide a group -- FLAG_HIDE_AQUA_HIDEOUT_GRUNTS covers three floors, FLAG_HIDE_SILPH_ROCKETS
# covers ten -- so the pattern alone says nothing. Written as a check it reported 21 findings, all
# of them legitimate group flags, and it did not report Kurt: both of his objects were
# OBJ_EVENT_GFX_OLD_MAN_1, so no sprite-difference heuristic separated them from a group.
# The half of that bug that is actually detectable is the duplicate having nothing to say, and
# MUTE-STORY-NPC below catches it.





def check_heal_respawn_sealed(maps, grids):
    """A whiteout respawn tile that is a wall, or is walled off from every warp on its map.

    heal_locations.json makes respawn_x/respawn_y OPTIONAL, defaulting to
    DEFAULT_POKEMON_CENTER_(X,Y) = (7,4). That is right for the 47 entries whose respawn map is a
    stock Pokemon Center layout, and silently wrong for any BESPOKE one: JohtoIndigoPlateau's
    Center is 35x18, and (7,4) there is metatile 0x000 -- unpainted void, in a 117-tile pocket
    with no warp in it. The map is MAP_TYPE_INDOOR with allow_escaping false, so Escape Rope, Dig,
    Fly and Teleport are all refused: losing to the Johto Elite Four left the player with no exit
    but a soft reset, and saving there ended the file.

    Keyed on the respawn coordinate only. The heal location's own x/y is a separate hazard (it is
    the Fly/Teleport destination AND the key GetHealLocationIndexByWarpData matches a save's
    lastHealLocation on), so moving one needs a migration -- see MigrateMovedHealLocations.
    """
    path = os.path.join(ROOT, "src/data/heal_locations.json")
    try:
        with open(path, encoding="utf-8") as fh:
            entries = json.load(fh)["heal_locations"]
    except (OSError, ValueError, KeyError):
        die("could not read src/data/heal_locations.json -- HEAL-RESPAWN-SEALED cannot run")

    by_id = {d.get("id"): d for d in maps.values() if d.get("id")}
    if len(by_id) < MIN_MAPS:
        die(f"only {len(by_id)} maps carry an `id` (expected >= {MIN_MAPS}) -- "
            f"HEAL-RESPAWN-SEALED would pass vacuously. Note heal_locations.json references the "
            f"map `id` (MAP_FOO_BAR), not its `name` (FooBar).")

    errors, checked = [], 0
    for e in entries:
        d = by_id.get(e.get("respawn_map"))
        if d is None:
            continue
        grid = grids.get(d.get("layout"))
        warps = [(w["x"], w["y"]) for w in (d.get("warp_events") or [])]
        if grid is None or not warps:
            continue
        w, h, coll = grid
        x, y = e.get("respawn_x", 7), e.get("respawn_y", 4)
        checked += 1
        if not (0 <= x < w and 0 <= y < h):
            errors.append(f"{e['id']}: respawn ({x},{y}) is outside {e['respawn_map']} ({w}x{h})")
            continue
        if coll[y][x] != 0:
            errors.append(f"{e['id']}: respawn ({x},{y}) on {e['respawn_map']} is impassable "
                          f"(the player materialises inside furniture or a wall)")
            continue
        seen, queue = {(x, y)}, collections.deque([(x, y)])
        while queue:
            cx, cy = queue.popleft()
            for nx, ny in ((cx + 1, cy), (cx - 1, cy), (cx, cy + 1), (cx, cy - 1)):
                if (0 <= nx < w and 0 <= ny < h and (nx, ny) not in seen and coll[ny][nx] == 0):
                    seen.add((nx, ny))
                    queue.append((nx, ny))
        if not any(wp in seen for wp in warps):
            errors.append(f"{e['id']}: respawn ({x},{y}) on {e['respawn_map']} is sealed -- its "
                          f"{len(seen)}-tile area contains none of the map's {len(warps)} warp(s), "
                          f"so a whiting-out player cannot leave")
    if checked < MIN_HEAL_RESPAWNS:
        die(f"only {checked} heal respawn tiles evaluated (expected >= {MIN_HEAL_RESPAWNS}) -- "
            f"HEAL-RESPAWN-SEALED would pass vacuously.")
    return errors


def check_heal_point_stranded(maps, grids):
    """A heal location's own x/y is impassable, or nowhere near the door it belongs to.

    This coordinate does three jobs: it is where Fly and Teleport drop the player, and it is the
    key GetHealLocationIndexByWarpData matches a save's lastHealLocation against. It is NOT the
    whiteout respawn tile (that is respawn_x/respawn_y -- see HEAL-RESPAWN-SEALED).

    Two rules, both decidable, and the tree is at zero on both:

      * Passable. Azalea (31,15), Goldenrod (28,36) and Safari Zone Gate (11,15) each sat on the
        PokeCenter DOOR tile itself -- metatile 0x062, collision 1. Fly arrives via
        FieldCallback_FlyIntoMap, which runs no door-exit task, so the player materialised drawn
        on top of a closed door, apparently inside the wall.
      * Near its door. 53 of 56 heal points are exactly the apron tile one square south of a warp
        into their respawn_map; the rest are within MAX_HEAL_DOOR_DIST. This is the rule that
        catches the #85 class -- Violet City's heal point was (30,18), five tiles under the SPROUT
        TOWER door and 36 tiles from its own Pokemon Center, and Route 32's was 60 tiles out.
        Skipped when respawn_map is the map itself (Southern Island heals in place).

    Moving one of these coordinates is a SAVE BREAK: an existing save whose lastHealLocation holds
    the old pair silently stops matching and keeps whiting out to the old tile. Pair any move with
    an entry in MigrateMovedHealLocations (src/load_save.c), the way Violet City and Route 32 got
    one in #85.
    """
    path = os.path.join(ROOT, "src/data/heal_locations.json")
    try:
        with open(path, encoding="utf-8") as fh:
            entries = json.load(fh)["heal_locations"]
    except (OSError, ValueError, KeyError):
        die("could not read src/data/heal_locations.json -- HEAL-POINT-STRANDED cannot run")

    by_id = {d.get("id"): d for d in maps.values() if d.get("id")}
    errors, checked = [], 0
    for e in entries:
        d = by_id.get(e.get("map"))
        if d is None:
            continue
        grid = grids.get(d.get("layout"))
        if grid is None:
            continue
        w, h, coll = grid
        x, y = e.get("x"), e.get("y")
        if x is None or y is None or not (0 <= x < w and 0 <= y < h):
            errors.append(f"{e['id']}: heal point ({x},{y}) is outside {e['map']} ({w}x{h})")
            continue
        checked += 1
        if coll[y][x] != 0:
            errors.append(f"{e['id']}: heal point ({x},{y}) on {e['map']} is impassable -- Fly and "
                          f"Teleport drop the player onto a wall or a closed door")
            continue
        if e.get("respawn_map") == e.get("map"):
            continue
        doors = [(wp["x"], wp["y"]) for wp in (d.get("warp_events") or [])
                 if wp.get("dest_map") == e.get("respawn_map")]
        if not doors:
            continue
        dist = min(abs(dx - x) + abs(dy - y) for dx, dy in doors)
        if dist > MAX_HEAL_DOOR_DIST:
            errors.append(f"{e['id']}: heal point ({x},{y}) is {dist} tiles from the nearest warp "
                          f"into {e['respawn_map']} -- it is pointing at the wrong building")
    if checked < MIN_HEAL_RESPAWNS:
        die(f"only {checked} heal points evaluated (expected >= {MIN_HEAL_RESPAWNS}) -- "
            f"HEAL-POINT-STRANDED would pass vacuously.")
    return errors


# ---------------------------------------------------------------- main

def main():
    report = "--report" in sys.argv
    strict = "--strict" in sys.argv

    maps = load_maps()
    bodies, owner = load_script_labels()
    flagdefs = load_flag_defs()
    trainers = load_trainers()
    grids = load_collision()
    objects = sum(len(d.get("object_events", [])) for d in maps.values())

    if len(maps) < MIN_MAPS:
        die(f"parsed only {len(maps)} maps (expected >= {MIN_MAPS}) -- {MAPS_GLOB} moved?")
    if objects < MIN_OBJECTS:
        die(f"parsed only {objects} object events (expected >= {MIN_OBJECTS})")
    if len(bodies) < MIN_SCRIPT_LABELS:
        die(f"parsed only {len(bodies)} script labels (expected >= {MIN_SCRIPT_LABELS})")
    if len(trainers) < MIN_TRAINERS:
        die(f"parsed only {len(trainers)} trainers (expected >= {MIN_TRAINERS})")
    if len(flagdefs) < MIN_FLAG_DEFS:
        die(f"parsed only {len(flagdefs)} flag definitions (expected >= {MIN_FLAG_DEFS})")
    if len(grids) < MIN_LAYOUTS:
        die(f"parsed only {len(grids)} layout collision grids (expected >= {MIN_LAYOUTS}) -- "
            f"did data/layouts/layouts.json or the blockdata paths move?")
    with_coll = sum(1 for d in maps.values() if d.get("layout") in grids)
    if with_coll < MIN_COLLISION_MAPS:
        die(f"only {with_coll} maps resolved to a collision grid (expected >= "
            f"{MIN_COLLISION_MAPS}) -- CUTSCENE-SEALS-MAP would be a no-op")

    mute_stats = collections.Counter()
    by_script, where = role_table(maps)
    localid_errs, localid_review = check_localids(maps, bodies, owner)

    errors = [
        ("DANGLING-REF", check_dangling(maps, bodies, flagdefs)),
        ("BAD-LOCALID", localid_errs),
        ("PROP-ACTS-ALIVE", check_prop_acts_alive(maps, bodies)),
        ("TRAINER-TYPE", check_trainer_type(maps, bodies)),
        ("TRAINER-FACTION", check_trainer_faction(trainers)),
        ("OBJECT-TRAINER-FACTION", check_object_trainer_faction(maps, bodies, trainers)),
        ("MUTE-STORY-NPC", check_mute_story_npc(maps, bodies, mute_stats)),
        ("HEAL-RESPAWN-SEALED", check_heal_respawn_sealed(maps, grids)),
        ("HEAL-POINT-STRANDED", check_heal_point_stranded(maps, grids)),
    ]
    reviews = [
        ("SCRIPT-GFX-OUTLIER", check_script_gfx_outlier(by_script, where)),
        ("DUPLICATE-TRAINER", check_duplicate_trainer(maps, bodies, owner, trainers)),
        ("NUMERIC-LOCALID", localid_review),
        ("CUTSCENE-SEALS-MAP", check_cutscene_seals_map(maps, bodies, owner, grids)),
    ]

    if report:
        print(f"-- census: {len(maps)} maps, {objects} object events, {len(bodies)} script "
              f"labels, {len(trainers)} trainers, {len(flagdefs)} flag defines")
        multi = {s: c for s, c in by_script.items()
                 if len(c) > 1 and sum(c.values()) >= MIN_ROLE_USES}
        roles = {s: c for s, c in multi.items() if len(c) <= MAX_ROLE_GFX}
        print(f"-- mute-NPC census: {mute_stats['candidates']} flag-gated mute objects "
              f"considered; {mute_stats['excluded_flag_reset']} excluded because the hide flag "
              f"is re-set elsewhere and {mute_stats['excluded_removed']} because a script "
              f"removes the object (both mean scene machinery); "
              f"{mute_stats['checkable_flags']} spawn-and-stay hide flags remain judgeable")
        print(f"-- role table: {len(by_script)} scripts carry objects; {len(multi)} use more "
              f"than one sprite; {len(roles)} of those are within MAX_ROLE_GFX={MAX_ROLE_GFX} "
              f"and get an outlier vote, {len(multi) - len(roles)} are treated as generic")
        for s, c in sorted(multi.items(), key=lambda kv: -len(kv[1]))[:12]:
            tag = "role" if len(c) <= MAX_ROLE_GFX else "generic"
            print(f"     [{tag:7s}] {s}: " + ", ".join(f"{n}x{k}" for k, n in c.most_common()))

    failed = 0
    for tag, items in errors:
        if items:
            failed += len(items)
            print(f"FAIL - {tag}: {len(items)} violation(s)")
            for line in items:
                print(f"    {line}")

    review_failed = 0
    for tag, items in reviews:
        base = REVIEW_BASELINE.get(tag, 0)
        over = len(items) - base
        if items and (report or strict or over > 0):
            print(f"{'FAIL' if (strict or over > 0) else 'REVIEW'} - {tag}: {len(items)} "
                  f"finding(s), baseline {base}")
            for line in items:
                print(f"    {line}")
        elif items:
            print(f"REVIEW - {tag}: {len(items)} finding(s) at baseline {base} "
                  f"(--report to list)")
        if strict and items:
            review_failed += len(items)
        elif over > 0:
            review_failed += over
            print(f"    ^ {over} more than the recorded baseline of {base}")

    if failed or review_failed:
        print(f"\nFAIL - {failed} error(s) and {review_failed} unbaselined review finding(s).")
        return 1

    print(f"OK - {objects} object events across {len(maps)} maps: every script and flag they "
          f"name is defined, no object id runs off a map's table.")
    print(f"OK - {len(trainers)} trainers: no class/portrait faction mismatch, no overworld "
          f"sprite fighting for the wrong team, every trainer_type object can actually battle.")
    print(f"OK - role consistency: {len(by_script)} object-carrying scripts checked for sprite "
          f"outliers, prop sprites checked for dialogue.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
