#!/usr/bin/env python3
"""Static census of every scripted legendary and static encounter (host-side, no build needed).

For each map script that starts a scripted wild battle it prints the species, the region, the
object the player meets and that object's hide flag, every flag the script writes before the
battle (kept even if the player whites out) and on each battle outcome, and every other script
or C file, by region, that reads or writes those flags.

The leads it prints are the shapes past bugs had:

  UNRESOLVED-WRITES  running or a Roar from the player (B_OUTCOME_RAN, B_OUTCOME_PLAYER_TELEPORTED)
                     leaves the Pokemon uncaught and unbeaten, but its path sets a fought/caught flag
                     or a hide flag nothing restores, so the Pokemon is gone without being resolved.
  PRE-BATTLE-WRITE   a persistent flag written before the battle starts survives a white-out.
  UNHANDLED-OUTCOME  the Pokemon knows a move that ends a wild battle (Teleport, Roar, Whirlwind,
                     Dragon Tail, Circle Throw) at its encounter level, and B_OUTCOME_MON_TELEPORTED
                     falls through to the caught/won path.
  WORLD-TWIN         a legendary with a twin site in another region (they share the object's hide
                     flag): a catch at one site sets nothing the twin's entry script reads, so the
                     twin offers a second one.

Leads checked against the source game and kept as designed sit in TRIAGED with the reason.

Run from the repo root:  python3 test/overworld/AuditLegends.py [--map NAME] [--leads | --check]
(--check is what test/validate-host.py runs.)
"""
import argparse
import collections
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ValidateMapEvents as vme  # noqa: E402

ROOT = vme.ROOT
START = re.compile(r"^(?:special\s+(BattleSetup_StartLegendaryBattle|StartGroudonKyogreBattle|"
                   r"StartRegiBattle|BattleSetup_StartLatiBattle|BattleSetup_StartScriptedWildBattle)"
                   r"|(dowildbattle))\b")
SPECIES = re.compile(r"^(?:setwildbattle|seteventmon)\s+(SPECIES_\w+)")
OUTCOME = re.compile(r"^goto_if_(eq|ne)\s+VAR_RESULT,\s*(B_OUTCOME_\w+),\s*(\w+)")
OUTCOME_CALL = re.compile(r"^call_if_eq\s+VAR_RESULT,\s*(B_OUTCOME_\w+),\s*(\w+)")
WRITE = re.compile(r"^(setflag|clearflag|setvar|addvar|removeobject)\s+(\w+)")
UNRESOLVED = ("B_OUTCOME_RAN", "B_OUTCOME_PLAYER_TELEPORTED", "B_OUTCOME_MON_FLED",
              "B_OUTCOME_MON_TELEPORTED")
RESOLVED = ("B_OUTCOME_WON", "B_OUTCOME_CAUGHT")
SKIP_FLAGS = re.compile(r"^FLAG_(TEMP_|SYS_CTRL_OBJ_DELETE|SYS_NO_CATCHING|HIDE_MAP_NAME)")


def map_dir_regions(maps):
    region_of_sec = vme.load_mapsec_regions()
    out = {}
    for d in maps.values():
        m = re.match(r"data/maps/([^/]+)/map\.json$", d["_path"])
        if m:
            out[m.group(1)] = region_of_sec(d.get("region_map_section", ""))
    return out


def label_regions(maps, bodies, owner, dir_region):
    regions = collections.defaultdict(set)
    for label, (_, mapdir) in owner.items():
        if mapdir in dir_region:
            regions[label].add(dir_region[mapdir])
    for d in maps.values():
        m = re.match(r"data/maps/([^/]+)/map\.json$", d["_path"])
        region = dir_region.get(m.group(1)) if m else None
        for e in d.get("object_events", []) + d.get("coord_events", []) + d.get("bg_events", []):
            if region and e.get("script") in bodies:
                regions[e["script"]].add(region)
    refs = {label: {t for line in body for t in vme.LABEL_TOKEN.findall(line)
                    if t in bodies and t != label} for label, body in bodies.items()}
    pending = list(regions)
    while pending:
        label = pending.pop()
        for target in refs.get(label, ()):
            if not regions[label] <= regions[target]:
                regions[target] |= regions[label]
                pending.append(target)
    return regions


def local_ids(mapdir, bodies, owner, mapdata):
    """LOCALID_* name -> object dict, from `.set` lines and map.json local_id fields."""
    objs = mapdata.get("object_events", [])
    out = {}
    for i, o in enumerate(objs):
        if o.get("local_id"):
            out[o["local_id"]] = o
        out[str(i + 1)] = o
    path = os.path.join(ROOT, "data/maps", mapdir, "scripts.inc")
    if os.path.exists(path):
        for line in open(path, encoding="utf-8", errors="replace"):
            m = re.match(r"\s*\.set\s+(LOCALID_\w+),\s*(\d+)", line)
            if m and 0 < int(m.group(2)) <= len(objs):
                out[m.group(1)] = objs[int(m.group(2)) - 1]
    return out


def writes(lines, ids, last_talked):
    out = []
    for line in lines:
        m = WRITE.match(line)
        if not m:
            continue
        op, arg = m.groups()
        if op == "removeobject":
            obj = last_talked if arg == "VAR_LAST_TALKED" else ids.get(arg)
            flag = obj.get("flag") if obj else None
            out.append(("hide", flag or f"?{arg}"))
        elif arg.startswith("FLAG_") and not SKIP_FLAGS.match(arg):
            out.append((op, arg))
        elif arg.startswith("VAR_") and not re.match(r"VAR_(TEMP_|0x8|RESULT|LAST_TALKED)", arg):
            out.append((op, arg))
    return out


def path_lines(label, bodies):
    return vme.reachable_bodies(label, bodies)


def analyse(label, bodies, ids, last_talked):
    body = bodies[label]
    at = next(i for i, line in enumerate(body) if START.match(line))
    pre, post = body[:at], body[at + 1:]
    branches, tail, calls = {}, [], collections.defaultdict(list)
    ne_target = None
    for i, line in enumerate(post):
        c = OUTCOME_CALL.match(line)
        if c:
            calls[c.group(1)].append(c.group(2))
            continue
        m = OUTCOME.match(line)
        if m:
            kind, outcome, target = m.groups()
            if kind == "eq":
                branches.setdefault(outcome, target)
            else:
                ne_target = (outcome, target)
            continue
        if line.startswith("specialvar VAR_RESULT, GetBattleOutcome"):
            continue
        tail.append(line)
        if re.match(r"^(end|return)\b", line):
            break
        gm = re.match(r"^goto\s+(\w+)$", line)
        if gm:
            tail += path_lines(gm.group(1), bodies)
            break
    result = {}
    for outcome in UNRESOLVED + RESOLVED:
        if outcome in branches:
            result[outcome] = writes(path_lines(branches[outcome], bodies), ids, last_talked)
        elif ne_target and outcome != ne_target[0]:
            result[outcome] = writes(path_lines(ne_target[1], bodies), ids, last_talked)
        else:
            result[outcome] = writes(tail, ids, last_talked)
        if outcome not in branches:
            for label_ in calls.get(outcome, ()):
                result[outcome] = writes(path_lines(label_, bodies), ids, last_talked) + result[outcome]
    return pre, result, branches


def flag_users(bodies, owner, regions, maps, dir_region):
    uses = collections.defaultdict(lambda: collections.defaultdict(set))
    for label, body in bodies.items():
        where = owner[label][0]
        for line in body:
            m = vme.STATE_WRITE.match(line)
            written = m.group(1) if m else None
            if line.startswith("removeobject"):
                continue
            for name in vme.STATE_TOKEN.findall(line):
                for region in regions.get(label, ()) or ("?",):
                    uses[name][("w" if name == written else "r", region)].add(where)
    for d in maps.values():
        m = re.match(r"data/maps/([^/]+)/map\.json$", d["_path"])
        region = dir_region.get(m.group(1), "?") if m else "?"
        for e in d.get("object_events", []):
            if e.get("flag", "").startswith("FLAG_"):
                uses[e["flag"]][("obj", region)].add(d["_path"])
    for dirpath, _, files in os.walk(os.path.join(ROOT, "src")):
        for fn in files:
            if not fn.endswith(".c"):
                continue
            path = os.path.join(dirpath, fn)
            text = open(path, encoding="utf-8", errors="replace").read()
            for name in set(vme.STATE_TOKEN.findall(text)):
                uses[name][("c", "C")].add(os.path.relpath(path, ROOT))
    return uses


ESCAPE_MOVES = {"MOVE_WHIRLWIND", "MOVE_ROAR", "MOVE_TELEPORT", "MOVE_DRAGON_TAIL", "MOVE_CIRCLE_THROW"}


def load_learnsets():
    """SPECIES_* -> [(level, MOVE_*)] from the Gen 9 level-up tables (P_LVL_UP_LEARNSETS GEN_LATEST)."""
    text = open(os.path.join(ROOT, "src/data/pokemon/level_up_learnsets/gen_9.h"), encoding="utf-8").read()
    sets = {m.group(1): [(int(a), b) for a, b in re.findall(r"LEVEL_UP_MOVE\(\s*(\d+),\s*(MOVE_\w+)\)", m.group(2))]
            for m in re.finditer(r"static const struct LevelUpMove (s\w+LevelUpLearnset)\[\] = \{(.*?)\};", text, re.S)}
    out = {}
    for dirpath, _, files in os.walk(os.path.join(ROOT, "src/data/pokemon/species_info")):
        for fn in files:
            t = open(os.path.join(dirpath, fn), encoding="utf-8").read()
            for m in re.finditer(r"\[(SPECIES_\w+)\]\s*=\s*\{(.*?)\n    \},", t, re.S):
                mm = re.search(r"\.levelUpLearnset = (s\w+)", m.group(2))
                if mm and mm.group(1) in sets:
                    out[m.group(1)] = sets[mm.group(1)]
    out.setdefault("SPECIES_DEOXYS", out.get("SPECIES_DEOXYS_NORMAL", []))
    return out


def default_moves(learnset, level):
    """The four moves GiveMonInitialMoveset leaves: the last four distinct moves up to `level`."""
    moves = []
    for lvl, move in learnset:
        if lvl > level:
            break
        if move not in moves:
            moves.append(move)
            if len(moves) > 4:
                moves.pop(0)
    return moves


def new_game_flags():
    text = open(os.path.join(ROOT, "src/new_game.c"), encoding="utf-8").read()
    return set(re.findall(r"\b(FLAG_HIDE_\w+)", text))


# Leads read against the source game and kept as designed: "<map>:<lead kind>" -> why.
TRIAGED = {
    "AquaHideout_B1F:UNRESOLVED-WRITES": "pokeemerald: fleeing an Electrode counts as beating it",
    "NewMauville_Inside:UNRESOLVED-WRITES": "pokeemerald: fleeing a Voltorb counts as beating it",
    "PowerPlant_Frlg:UNRESOLVED-WRITES": "pokefirered: fleeing an Electrode counts as fighting it",
    "BattleFrontier_OutsideEast:UNRESOLVED-WRITES": "pokeemerald: the Sudowoodo leaves whatever the outcome",
    "Route120:UNRESOLVED-WRITES": "pokeemerald: the bridge Kecleon leaves whatever the outcome",
    "ThreeIsland_BerryForest_Frlg:UNRESOLVED-WRITES": "pokefirered: Lostelle is rescued whatever the outcome",
    "SkyPillar_Top:UNRESOLVED-WRITES": "pokeemerald: the still Rayquaza sprite is reshown by ON_TRANSITION via "
                                      "FLAG_DEFEATED_RAYQUAZA, not by its own hide flag",
    "IlexForest:UNRESOLVED-WRITES": "pokemonHnS: Celebi leaves whatever the outcome; the Johto Hall of Fame "
                                   "brings back an uncaught one (VAR_AZALEA_TOWN_STATE gate)",
    "Route12_Frlg:PRE-BATTLE-WRITE": "pokefirered: the Snorlax wakes and leaves before the battle",
    "Route16_Frlg:PRE-BATTLE-WRITE": "pokefirered: the Snorlax wakes and leaves before the battle",
}

RESOLVING = re.compile(r"FOUGHT|CAUGHT|DEFEATED|BATTLED|FLEW_AWAY")


def encounter_level(lines):
    for line in lines:
        m = re.match(r"^(?:setwildbattle\w*|seteventmon)\s+SPECIES_\w+,\s*(\d+)", line)
        if m:
            return int(m.group(1))
    return None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--map")
    ap.add_argument("--leads", action="store_true", help="print only the leads")
    ap.add_argument("--check", action="store_true",
                    help="print only the leads; exit 1 on an untriaged lead or a stale TRIAGED entry")
    args = ap.parse_args()

    maps = vme.load_maps()
    by_dir = {}
    for d in maps.values():
        m = re.match(r"data/maps/([^/]+)/map\.json$", d["_path"])
        if m:
            by_dir[m.group(1)] = d
    bodies, owner = vme.load_script_labels()
    dir_region = map_dir_regions(maps)
    regions = label_regions(maps, bodies, owner, dir_region)
    uses = flag_users(bodies, owner, regions, maps, dir_region)
    registered = new_game_flags()
    learnsets = load_learnsets()

    records = []
    for label, body in sorted(bodies.items(), key=lambda kv: (owner[kv[0]][1] or "", kv[0])):
        mapdir = owner[label][1]
        if not mapdir or not any(START.match(line) for line in body):
            continue
        if args.map and args.map != mapdir:
            continue
        mapdata = by_dir.get(mapdir, {})
        ids = local_ids(mapdir, bodies, owner, mapdata)
        events = []
        for e in mapdata.get("object_events", []):
            if e.get("script") and label in vme.reachable_labels(e["script"], bodies):
                events.append(("obj", e))
        for e in mapdata.get("coord_events", []) + mapdata.get("bg_events", []):
            if e.get("script") and label in vme.reachable_labels(e["script"], bodies):
                events.append(("evt", e))
        talked = next((e for k, e in events if k == "obj"), None)
        scope = vme.reachable_bodies(events[0][1]["script"], bodies) if events else bodies[label]
        species = sorted({m.group(1) for line in scope for m in [SPECIES.match(line)] if m})
        level = encounter_level(scope)
        pre, outcomes, branches = analyse(label, bodies, ids, talked)
        entry_writes, entry_reads, resume_hides = [], set(), set()
        for line in bodies.get(f"{mapdir}_MapScripts", []):
            mm = re.match(r"map_script\s+MAP_SCRIPT_(ON_TRANSITION|ON_LOAD|ON_RESUME),\s*(\w+)", line)
            if mm and mm.group(1) == "ON_RESUME":
                # FLAG_SYS_CTRL_OBJ_DELETE: the resume script removes the object after a catch.
                resume_hides |= {f for op, f in writes(path_lines(mm.group(2), bodies), ids, talked) if op == "hide"}
            elif mm:
                lines = path_lines(mm.group(2), bodies)
                entry_writes += writes(lines, ids, talked)
                entry_reads |= {t for line in lines if not WRITE.match(line) for t in vme.STATE_TOKEN.findall(line)}
        restored = {f for op, f in entry_writes if op == "clearflag"}
        escape = sorted({mv for sp in species for mv in default_moves(learnsets.get(sp, learnsets.get(
                             sp + "_NORMAL", [])), level or 0)
                         if mv in ESCAPE_MOVES})
        species = sorted({re.sub(r"_NORMAL$", "", sp) for sp in species})
        added = {(ids.get(m.group(1)) or {}).get("flag") for line in scope
                 for m in [re.match(r"^addobject\s+(\w+)", line)] if m}
        records.append(dict(mapdir=mapdir, region=dir_region.get(mapdir, "?"), label=label, species=species,
                            resume_hides=resume_hides, added=added,
                            level=level, events=events, pre=writes(pre, ids, talked), outcomes=outcomes,
                            branches=branches, entry_writes=entry_writes, entry_reads=entry_reads,
                            restored=restored, escape=escape))

    leads, notes = [], []

    def lead(r, text):
        leads.append(f"{r['mapdir']} [{r['region']}] {'/'.join(s[8:] for s in r['species']) or '?'}: {text}")

    def bad_writes(r, ws):
        return [w for w in ws if (w[0] == "setflag" and RESOLVING.search(w[1]))
                or (w[0] in ("hide", "setflag") and w[1].startswith("FLAG_HIDE") and w[1] not in r["restored"])]

    for r in records:
        for w in r["pre"]:
            if w[0] in ("hide", "setflag") and (RESOLVING.search(w[1]) or w[1].startswith("FLAG_HIDE")):
                lead(r, f"PRE-BATTLE-WRITE {w[0]} {w[1]} (kept after a white-out)")
        for o in ("B_OUTCOME_RAN", "B_OUTCOME_PLAYER_TELEPORTED"):
            bad = bad_writes(r, r["outcomes"][o])
            if bad:
                lead(r, f"UNRESOLVED-WRITES {o[10:]}: " + ", ".join(" ".join(w) for w in bad))
        if r["escape"] and "B_OUTCOME_MON_TELEPORTED" not in r["branches"]:
            bad = bad_writes(r, r["outcomes"]["B_OUTCOME_MON_TELEPORTED"])
            if bad:
                lead(r, f"UNHANDLED-OUTCOME MON_TELEPORTED (knows {', '.join(m[5:] for m in r['escape'])} at "
                        f"L{r['level']}): " + ", ".join(" ".join(w) for w in bad))

    # One legendary per world: twin sites in two regions share the object's hide flag. A catch at
    # one must set something each twin's entry script reads, directly or through a script that
    # writes what the entry script reads (the Johto Hall of Fame sets VAR_COMPLETED_HO_OH for Tin
    # Tower from FLAG_CAUGHT_HO_OH), or hide the shared object where the twin never clears it.
    writers = collections.defaultdict(set)
    for label, body in bodies.items():
        for line in body:
            m = vme.STATE_WRITE.match(line)
            if m:
                writers[m.group(1)].add(label)

    def guard_reads(r):
        reads = set(r["entry_reads"])
        for name in r["entry_reads"]:
            for label in writers.get(name, ()):
                if owner[label][1] != r["mapdir"]:
                    reads |= {t for line in bodies[label] if not WRITE.match(line)
                              for t in vme.STATE_TOKEN.findall(line)}
        return reads

    def hide_flags(r):
        return ({e["flag"] for _, e in r["events"] if e.get("flag", "").startswith("FLAG_HIDE")}
                | {f for op, f in r["entry_writes"] if op == "setflag" and f.startswith("FLAG_HIDE")}
                | {f for f in r["resume_hides"] if f.startswith("FLAG_HIDE")})

    for a in records:
        caught = {w[1] for w in a["outcomes"]["B_OUTCOME_CAUGHT"] if w[0] in ("setflag", "hide")}
        caught |= a["resume_hides"]
        for b in records:
            shared = hide_flags(a) & hide_flags(b)
            if b["region"] == a["region"] or not shared or not set(a["species"]) & set(b["species"]):
                continue
            hidden_for_good = caught & shared - b["restored"] - b["added"]
            if caught & guard_reads(b) or hidden_for_good:
                continue
            lead(a, f"WORLD-TWIN a catch here sets {sorted(caught) or 'nothing'}; the twin at "
                    f"{b['mapdir']} [{b['region']}] reads none of it, so it offers a second one")

    fired = set()
    for line in list(leads):
        key = line.split(":", 1)[0].split(" [")[0] + ":" + line.split(": ", 1)[1].split(" ")[0]
        if key in TRIAGED:
            fired.add(key)
            leads.remove(line)
            notes.append(f"{line}  -- {TRIAGED[key]}")
    stale = [] if args.map else sorted(set(TRIAGED) - fired)

    if not (args.leads or args.check):
        for r in records:
            print(f"== {r['mapdir']} [{r['region']}] {r['label']}  species={','.join(r['species']) or '?'} "
                  f"L{r['level']}" + (f"  escape={','.join(r['escape'])}" if r["escape"] else ""))
            for k, e in r["events"]:
                print(f"   {k} {e.get('local_id', '')} script={e['script']} flag={e.get('flag', '-')}"
                      + ("" if not e.get("flag", "").startswith("FLAG_HIDE") or e["flag"] in registered
                         else "  (hide flag not set in new_game.c)"))
            print(f"   pre-battle writes: {r['pre']}")
            for o in UNRESOLVED + RESOLVED:
                tag = "branch" if o in r["branches"] else "fall"
                print(f"   {o[10:]:<18} [{tag}] {r['outcomes'][o]}")
            print(f"   on entry: writes={r['entry_writes']} reads={sorted(r['entry_reads'])}")
            flags = {f for ws in r["outcomes"].values() for _, f in ws} | {f for _, f in r["pre"]}
            flags |= {e["flag"] for _, e in r["events"] if e.get("flag", "").startswith("FLAG_")}
            for f in sorted(flags):
                if f.startswith("?") or not f.startswith("FLAG_"):
                    continue
                parts = []
                for (k, rg), files in sorted(uses.get(f, {}).items()):
                    files = sorted(x for x in files if r["mapdir"] not in x)
                    if files:
                        parts.append(f"{k}:{rg}=" + ",".join(
                            os.path.basename(os.path.dirname(x)) if x.endswith((".inc", ".json")) else x
                            for x in files[:6]))
                print(f"   {f}: " + ("; ".join(parts) if parts else "(this map only)"))
    print(f"\n{len(records)} encounter scripts, {len(leads)} leads, {len(notes)} triaged")
    for line in [] if args.check else notes:
        print("NOTE " + line)
    for line in leads:
        print("LEAD " + line)
    for key in stale:
        print(f"STALE TRIAGED entry {key} no longer fires; delete it")
    if args.check and (leads or stale):
        sys.exit(1)


if __name__ == "__main__":
    main()
