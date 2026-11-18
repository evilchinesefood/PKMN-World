#!/usr/bin/env python3
"""List map objects that a hide flag removes for good, and story vars a script waits on forever.

Johto's Indigo Plateau Silver (PR #691) is the pattern. Route 27's first steps set
FLAG_HIDE_INDIGO_PLATEAU_SILVER, and the HnS script that cleared it (a post-League fight in
HnS's own Mt. Moon) never came over when Kanto was ported from FireRed. His teams and his daily
rematch sat behind a flag nothing in this tree clears. That builds, boots and plays clean until
someone goes looking for him.

The check reads every object event in data/maps/*/map.json and every write to its hide flag:

  * `setflag`/`clearflag` in data/**/*.inc and data/**/*.s, with `.set` aliases resolved;
  * `removeobject`/`removeobjectat` and `setfollowernpc`, which set the removed object's flag
    (RemoveObjectEventByLocalIdAndMap and follower_npc.c both call FlagSet on it);
  * `FlagSet`/`FlagClear` in src/**/*.c (debug.c excluded), plus the C functions that run the
    new-game reset scripts;
  * `addobject`/`addobjectat`, which spawn the object whatever its flag says, so they count as a
    clear here;
  * `setvar VAR_*, FLAG_*`, a flag id handed to a special, counted as both;
  * the temp and daily flag ranges, which the engine clears wholesale, are skipped.

Flags are compared by numeric id, through the real headers with ALL_REGIONS set, so an alias is
the same flag. A script label counts only when something live reaches it: a map event, a map's
script header, a C reference, or another live label (by name, or by falling through). A map
counts only when warps, connections or a live MAP_ reference lead to it.

Findings, per hide flag that some object with content (a script, trainer, item or gift) uses:

  HIDDEN-FOR-GOOD  something other than the object's own script sets the flag (another map, a
                   shared script, C, the new-game reset) and nothing live clears it. Cases (a)
                   and (b) of the stress-9 brief; Silver is one.
  DEAD-CLEARER     the only clears sit in labels nothing live reaches, or on maps nothing leads
                   to. Case (c).
  UNWRITTEN-VAR    a script, map script table or coord event waits for VAR == N (or >= N) on a
                   story var no script or C code ever writes N to (nor writes in a way that could
                   reach it: addvar, copyvar, VarSet with a non-literal).

LOCAL removals (an object whose flag only its own map's cutscene sets, and nothing clears) are
the ordinary one-time-NPC shape, so they print only with --all.

With --source NAME=DIR (pokeemerald, pokefirered, pokemonHnS checkouts) two more things run:

  UNREGISTERED     the source hides the object at new game, but here nothing outside the object's
                   own script sets its flag, so it stands in the world from turn one. Olivine's
                   Oak (the National Pokedex before the League) and seven gym-leader cameos were
                   this (stress pass 9).
  PARITY check     every PARITY claim below is re-read from its source: the source must also never
                   clear (or, for UNSET-FLAG, never set) that flag outside its new-game reset.

Every finding is triaged against its region's source game and recorded below: PARITY when the
source does the same, INTENDED with a reason when the difference is this tree's own decision,
PENDING when an open PR removes it. A finding in none of them fails the check, and so does a
PARITY or INTENDED entry that no longer matches a finding, so the list stays honest. Default
mode needs no checkout and no build, so validate-host runs it.

Usage:
    python3 test/overworld/AuditHideFlags.py [--all] [--root DIR] [--source NAME=DIR ...]
"""

import argparse
import collections
import glob
import json
import os
import re
import subprocess
import sys
import tempfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ValidateMapEvents as vme  # noqa: E402

TERMINATORS = re.compile(r"^(end|return|goto|step_end|\.string|\.byte|\.2byte|\.4byte|\.align|"
                         r"releaseall\s*;\s*end)\b")
TOKEN = re.compile(r"\b(\w+)\b")
COND = re.compile(r"^(goto|call)_if_(eq|ne|lt|le|gt|ge)\s+(VAR_\w+)\s*,\s*([\w()+\-* ]+?)\s*,")
COMPARE = re.compile(r"^compare(?:_var_to_value)?\s+(VAR_\w+)\s*,\s*([\w()+\-* ]+?)\s*$")
COND_AFTER_COMPARE = re.compile(r"^(goto|call)_if_(eq|ne|lt|le|gt|ge)\s+\w+\s*$")
MAP_SCRIPT_2 = re.compile(r"^map_script_2\s+(VAR_\w+)\s*,\s*([\w()+\-* ]+?)\s*,\s*(\w+)")
SWITCH = re.compile(r"^switch\s+(VAR_\w+)")
CASE = re.compile(r"^case\s+([\w()+\-* ]+?)\s*,")
SETVAR = re.compile(r"^setvar\s+(VAR_\w+)\s*,\s*([\w()+\-* ]+?)\s*$")
WILD_VAR = re.compile(r"^(addvar|subvar|copyvar|setorcopyvar|specialvar|random|getpartysize|"
                      r"checkitemspace|getpricereduction|buffer\w*)\s+(VAR_\w+)")
C_SET = re.compile(r"\bFlag(Set|Clear|Toggle)\s*\(\s*(FLAG_\w+)\s*\)")
C_VARSET = re.compile(r"\bVarSet\s*\(\s*(VAR_\w+)\s*,\s*([^;]*?)\)\s*;")
C_FUNC = re.compile(r"^[A-Za-z_][\w \*]*?\b(\w+)\s*\([^;]*$")
NEW_GAME_SCRIPTS = ("EventScript_ResetAllMapFlags", "EventScript_ResetAllMapFlagsFrlg")
NEW_GAME_FUNCS = ("NewGameInitData",)
NO_SCRIPT = {"", "0", "0x0", "NULL", "Common_EventScript_Nop", "Johto_EventScript_Nop"}

SOURCE_FOR_REGION = {"HOENN": "pokeemerald", "KANTO": "pokefirered", "JOHTO": "pokemonHnS"}

# Findings the source game shares: it also never clears the flag outside its new-game reset
# (HIDDEN-FOR-GOOD, LOCAL) or never sets it (UNSET-FLAG). --source NAME=DIR re-checks each claim.
PARITY = {
    ("HIDDEN-FOR-GOOD", "FLAG_HIDE_AQUA_HIDEOUT_1F_GRUNT_1_BLOCKING_ENTRANCE"): "pokeemerald",
    ("HIDDEN-FOR-GOOD", "FLAG_HIDE_AQUA_HIDEOUT_1F_GRUNT_2_BLOCKING_ENTRANCE"): "pokeemerald",
    ("HIDDEN-FOR-GOOD", "FLAG_HIDE_AQUA_HIDEOUT_GRUNTS"): "pokeemerald",
    ("HIDDEN-FOR-GOOD", "FLAG_HIDE_JAGGED_PASS_MAGMA_GUARD"): "pokeemerald",
    ("HIDDEN-FOR-GOOD", "FLAG_HIDE_LILYCOVE_CITY_AQUA_GRUNTS"): "pokeemerald",
    ("HIDDEN-FOR-GOOD", "FLAG_HIDE_LILYCOVE_CITY_RIVAL"): "pokeemerald",
    ("HIDDEN-FOR-GOOD", "FLAG_HIDE_LILYCOVE_MOTEL_SCOTT"): "pokeemerald",
    ("HIDDEN-FOR-GOOD", "FLAG_HIDE_LILYCOVE_MUSEUM_CURATOR"): "pokeemerald",
    ("HIDDEN-FOR-GOOD", "FLAG_HIDE_LITTLEROOT_TOWN_BRENDANS_HOUSE_2F_POKE_BALL"): "pokeemerald",
    ("HIDDEN-FOR-GOOD", "FLAG_HIDE_LITTLEROOT_TOWN_BRENDANS_HOUSE_MOM"): "pokeemerald",
    ("HIDDEN-FOR-GOOD", "FLAG_HIDE_LITTLEROOT_TOWN_BRENDANS_HOUSE_RIVAL_MOM"): "pokeemerald",
    ("HIDDEN-FOR-GOOD", "FLAG_HIDE_LITTLEROOT_TOWN_BRENDANS_HOUSE_RIVAL_SIBLING"): "pokeemerald",
    ("HIDDEN-FOR-GOOD", "FLAG_HIDE_LITTLEROOT_TOWN_MAYS_HOUSE_2F_POKE_BALL"): "pokeemerald",
    ("HIDDEN-FOR-GOOD", "FLAG_HIDE_LITTLEROOT_TOWN_MAYS_HOUSE_MOM"): "pokeemerald",
    ("HIDDEN-FOR-GOOD", "FLAG_HIDE_LITTLEROOT_TOWN_MAYS_HOUSE_RIVAL_MOM"): "pokeemerald",
    ("HIDDEN-FOR-GOOD", "FLAG_HIDE_LITTLEROOT_TOWN_MAYS_HOUSE_RIVAL_SIBLING"): "pokeemerald",
    ("HIDDEN-FOR-GOOD", "FLAG_HIDE_LITTLEROOT_TOWN_PLAYERS_HOUSE_VIGOROTH_1"): "pokeemerald",
    ("HIDDEN-FOR-GOOD", "FLAG_HIDE_LITTLEROOT_TOWN_PLAYERS_HOUSE_VIGOROTH_2"): "pokeemerald",
    ("HIDDEN-FOR-GOOD", "FLAG_HIDE_METEOR_FALLS_1F_1R_COZMO"): "pokeemerald",
    ("HIDDEN-FOR-GOOD", "FLAG_HIDE_MOSSDEEP_CITY_SCOTT"): "pokeemerald",
    ("HIDDEN-FOR-GOOD", "FLAG_HIDE_MOSSDEEP_CITY_SPACE_CENTER_1F_STEVEN"): "pokeemerald",
    ("HIDDEN-FOR-GOOD", "FLAG_HIDE_MOSSDEEP_CITY_SPACE_CENTER_MAGMA_NOTE"): "pokeemerald",
    ("HIDDEN-FOR-GOOD", "FLAG_HIDE_PETALBURG_CITY_WALLYS_MOM"): "pokeemerald",
    ("HIDDEN-FOR-GOOD", "FLAG_HIDE_ROUTE_110_TEAM_AQUA"): "pokeemerald",
    ("HIDDEN-FOR-GOOD", "FLAG_HIDE_ROUTE_111_ROCK_SMASH_TIP_GUY"): "pokeemerald",
    ("HIDDEN-FOR-GOOD", "FLAG_HIDE_ROUTE_112_TEAM_MAGMA"): "pokeemerald",
    ("HIDDEN-FOR-GOOD", "FLAG_HIDE_ROUTE_116_WANDAS_BOYFRIEND"): "pokeemerald",
    ("HIDDEN-FOR-GOOD", "FLAG_HIDE_RUSTBORO_CITY_POKEMON_SCHOOL_SCOTT"): "pokeemerald",
    ("HIDDEN-FOR-GOOD", "FLAG_HIDE_SAFARI_ZONE_SOUTH_CONSTRUCTION_WORKERS"): "pokeemerald",
    ("HIDDEN-FOR-GOOD", "FLAG_HIDE_SEAFLOOR_CAVERN_AQUA_GRUNTS"): "pokeemerald",
    ("HIDDEN-FOR-GOOD", "FLAG_HIDE_SEAFLOOR_CAVERN_ENTRANCE_AQUA_GRUNT"): "pokeemerald",
    ("HIDDEN-FOR-GOOD", "FLAG_HIDE_SLATEPORT_CITY_OCEANIC_MUSEUM_AQUA_GRUNTS"): "pokeemerald",
    ("HIDDEN-FOR-GOOD", "FLAG_HIDE_SLATEPORT_CITY_TEAM_AQUA"): "pokeemerald",
    ("HIDDEN-FOR-GOOD", "FLAG_HIDE_SS_TIDAL_ROOMS_SNATCH_GIVER"): "pokeemerald",
    ("LOCAL", "FLAG_HIDE_MAUVILLE_CITY_WALLYS_UNCLE"): "pokeemerald",
    ("LOCAL", "FLAG_HIDE_MIRAGE_TOWER_CLAW_FOSSIL"): "pokeemerald",
    ("LOCAL", "FLAG_HIDE_MIRAGE_TOWER_ROOT_FOSSIL"): "pokeemerald",
    ("LOCAL", "FLAG_HIDE_MT_PYRE_SUMMIT_TEAM_AQUA"): "pokeemerald",
    ("LOCAL", "FLAG_HIDE_ROUTE_120_KECLEON_BRIDGE"): "pokeemerald",
    ("LOCAL", "FLAG_HIDE_UNDERWATER_SEA_FLOOR_CAVERN_STOLEN_SUBMARINE"): "pokeemerald",
    ("UNSET-FLAG", "FLAG_SYS_SET_TRAINER_CARD_PROFILE"): "pokeemerald",
    ("UNSET-FLAG", "FLAG_UNUSED_RS_LEGENDARY_BATTLE_DONE"): "pokeemerald",
    ("HIDDEN-FOR-GOOD", "FLAG_HIDE_CELADON_ROCKETS"): "pokefirered",
    ("HIDDEN-FOR-GOOD", "FLAG_HIDE_CERULEAN_CAVE_GUARD"): "pokefirered",
    ("HIDDEN-FOR-GOOD", "FLAG_HIDE_MISC_KANTO_ROCKETS"): "pokefirered",
    ("HIDDEN-FOR-GOOD", "FLAG_HIDE_NUGGET_BRIDGE_ROCKET"): "pokefirered",
    ("HIDDEN-FOR-GOOD", "FLAG_HIDE_RUIN_VALLEY_SCIENTIST"): "pokefirered",
    ("HIDDEN-FOR-GOOD", "FLAG_HIDE_SAFFRON_ROCKETS"): "pokefirered",
    ("HIDDEN-FOR-GOOD", "FLAG_HIDE_SEAFOAM_B1F_BOULDER_1"): "pokefirered",
    ("HIDDEN-FOR-GOOD", "FLAG_HIDE_SEAFOAM_B1F_BOULDER_2"): "pokefirered",
    ("HIDDEN-FOR-GOOD", "FLAG_HIDE_SEAFOAM_B2F_BOULDER_1"): "pokefirered",
    ("HIDDEN-FOR-GOOD", "FLAG_HIDE_SEAFOAM_B2F_BOULDER_2"): "pokefirered",
    ("HIDDEN-FOR-GOOD", "FLAG_HIDE_TOWN_MAP"): "pokefirered",
    ("HIDDEN-FOR-GOOD", "FLAG_HIDE_VICTORY_ROAD_2F_BOULDER"): "pokefirered",
    ("LOCAL", "FLAG_HIDE_GAME_CORNER_ROCKET"): "pokefirered",
    ("LOCAL", "FLAG_HIDE_ICEFALL_CAVE_LORELEI"): "pokefirered",
    ("LOCAL", "FLAG_HIDE_OLD_AMBER"): "pokefirered",
    ("LOCAL", "FLAG_HIDE_ONE_ISLAND_POKECENTER_BILL"): "pokefirered",
    ("LOCAL", "FLAG_HIDE_SILPH_ROCKETS"): "pokefirered",
    ("LOCAL", "FLAG_HIDE_THREE_ISLAND_ANTIBIKERS"): "pokefirered",
    ("LOCAL", "FLAG_HIDE_THREE_ISLAND_BIKERS"): "pokefirered",
    ("HIDDEN-FOR-GOOD", "FLAG_HIDE_GUIDE_GENT_CHERRYGROVE"): "pokemonHnS",
    ("LOCAL", "FLAG_DELIVERED_EGG"): "pokemonHnS",
    ("LOCAL", "FLAG_HIDE_CHIKORITABALL"): "pokemonHnS",
    ("LOCAL", "FLAG_HIDE_CYNDAQUILBALL"): "pokemonHnS",
    ("LOCAL", "FLAG_HIDE_SLOWPOKE_WELL_KURT"): "pokemonHnS",
    ("LOCAL", "FLAG_HIDE_TOTODILEBALL"): "pokemonHnS",
}

# Findings that are this tree's own decisions, each with its reason.
INTENDED = {
    ("HIDDEN-FOR-GOOD", "FLAG_HIDE_LEAGUE_BLACKBELT"):
        "HnS shows him after the first Hall of Fame to turn challengers away until Kanto's 16 badges. "
        "This tree's Kanto keeps its own League, so Route 27's first steps hide him for good; he stood "
        "on the only tile in front of the Elite Four door (2026-10-24 fix).",
    ("UNSET-FLAG", "FLAG_FINITE_TMS"):
        "HnS sets it from its tx_rac_menu challenge option, which was not ported; TMs are reusable here, "
        "so the incense clerk's finite-TM branch never runs.",
    ("UNSET-FLAG", "FLAG_UNLOCK_BIRDS"):
        "HnS sets it after Ho-Oh at its Navel Rock to swap Victory Road B2F to the Moltres layout. Here "
        "SwitchToModern sets the layout the map already uses, so the dead branch changes nothing.",
    ("UNSET-FLAG", "FLAG_MOSSDEEP_GYM_SWITCH_1"): "pokeemerald sets the R/S switch flags only in unreferenced labels too.",
    ("UNSET-FLAG", "FLAG_MOSSDEEP_GYM_SWITCH_2"): "pokeemerald sets the R/S switch flags only in unreferenced labels too.",
    ("UNSET-FLAG", "FLAG_MOSSDEEP_GYM_SWITCH_3"): "pokeemerald sets the R/S switch flags only in unreferenced labels too.",
    ("UNSET-FLAG", "FLAG_MOSSDEEP_GYM_SWITCH_4"): "pokeemerald sets the R/S switch flags only in unreferenced labels too.",
    ("UNSET-FLAG", "FLAG_TRICK_HOUSE_PUZZLE_7_SWITCH_1"): "pokeemerald's R/S teleport-pad leftover; its setters are unreferenced there too.",
    ("UNSET-FLAG", "FLAG_TRICK_HOUSE_PUZZLE_7_SWITCH_2"): "pokeemerald's R/S teleport-pad leftover; its setters are unreferenced there too.",
    ("UNSET-FLAG", "FLAG_TRICK_HOUSE_PUZZLE_7_SWITCH_3"): "pokeemerald's R/S teleport-pad leftover; its setters are unreferenced there too.",
    ("UNSET-FLAG", "FLAG_TRICK_HOUSE_PUZZLE_7_SWITCH_4"): "pokeemerald's R/S teleport-pad leftover; its setters are unreferenced there too.",
    ("UNSET-FLAG", "FLAG_TRICK_HOUSE_PUZZLE_7_SWITCH_5"): "pokeemerald's R/S teleport-pad leftover; its setters are unreferenced there too.",
    ("UNWRITTEN-VAR", "VAR_TRICK_HOUSE_PUZZLE_7_STATE_2==1"):
        "pokeemerald writes it only in the unreferenced R/S TeleportPad label too.",
    ("UNWRITTEN-VAR", "VAR_CONTEST_TYPE==5"):
        "CONTEST_TYPE_LINK: pokeemerald writes it only in the link contest lobby, which is not reachable here.",
    ("UNWRITTEN-VAR", "VAR_FRONTIER_BATTLE_MODE==3"):
        "FRONTIER_MODE_LINK_MULTIS is a link-cable mode; no offline path writes it, as in pokeemerald.",
    ("UNWRITTEN-VAR", "VAR_FERRY_DEPARTURE==3"):
        "FERRY_DEPART_VERMILION is a documented floor for a future Kanto island row "
        "(include/constants/ferry.h); no boarding site writes it yet.",
    ("UNREGISTERED", "FLAG_HIDE_ROUTE_30_NPCS"):
        "Mom's first-floor scene clears it before Route 30 is in reach; hiding Joey at new game would "
        "keep him hidden for any arrival that skips that scene.",
}

# Findings an open PR removes; each may or may not still be present.
PENDING = {
    ("HIDDEN-FOR-GOOD", "FLAG_HIDE_INDIGO_PLATEAU_SILVER"):
        "PR #691 brings Silver back for his daily Indigo Plateau rematch (stress pass 9).",
}


def resolve_ids(root, names):
    """Constant name -> int, through every tracked include/constants header with ALL_REGIONS."""
    try:
        listed = subprocess.run(["git", "ls-files", "include/constants/*.h"], cwd=root,
                                capture_output=True, text=True, check=True).stdout.split()
    except (OSError, subprocess.CalledProcessError):
        listed = [os.path.relpath(p, root) for p in glob.glob(os.path.join(root, "include/constants/*.h"))]
    src = "".join(f'#include "{h[len("include/"):]}"\n' for h in sorted(listed))
    # The name goes in a string literal, which the preprocessor leaves alone.
    src += "".join(f'"{n}" {n}\n' for n in sorted(names))
    with tempfile.TemporaryDirectory() as td:
        path = os.path.join(td, "ids.c")
        with open(path, "w", encoding="utf-8") as fh:
            fh.write(src)
        cc = os.environ.get("HOSTCC", "cc")
        out = subprocess.run([cc, "-E", "-P", "-w", "-DALL_REGIONS=1", "-DMODERN=1", "-iquote", "include",
                              "-Iinclude", path], cwd=root, capture_output=True, text=True)
    if out.returncode:
        sys.exit(f"AuditHideFlags: preprocessing the constants headers failed:\n{out.stderr[-2000:]}")
    ids = {}
    for line in out.stdout.splitlines():
        m = re.match(r'"(\w+)"\s*(.*)$', line)
        if m and re.fullmatch(r"[0-9a-fA-FxXuU+\-*/%()<>| ]+", m.group(2).strip() or "x"):
            try:
                ids[m.group(1)] = eval(re.sub(r"(?<=[0-9a-fA-F])[uU]\b", "", m.group(2)).replace("/", "//"),
                                       {"__builtins__": {}})
            except Exception:
                pass
    return ids


def strip_c_comments(text):
    return re.sub(r"/\*.*?\*/|//[^\n]*", " ", text, flags=re.S)


def literal(expr, ids):
    expr = expr.strip()
    if expr in ids:
        return ids[expr]
    try:
        return int(expr, 0)
    except ValueError:
        if re.fullmatch(r"[\w()+\-* ]+", expr):
            try:
                return eval(TOKEN.sub(lambda m: str(ids.get(m.group(1), m.group(1))), expr),
                            {"__builtins__": {}})
            except Exception:
                return None
    return None


class Tree:
    def __init__(self, root):
        vme.ROOT = root
        self.root = root
        self.maps = {}
        for path in sorted(glob.glob(os.path.join(root, "data/maps/*/map.json"))):
            with open(path, encoding="utf-8") as fh:
                d = json.load(fh)
            d["_dir"] = os.path.basename(os.path.dirname(path))
            self.maps[d["name"]] = d
        with open(os.path.join(root, "data/maps/map_groups.json"), encoding="utf-8") as fh:
            groups = json.load(fh)
        self.grouped = {n for g in groups["group_order"] for n in groups[g]}
        self.by_id = {d["id"]: n for n, d in self.maps.items()}
        self.by_dir = {d["_dir"]: n for n, d in self.maps.items()}
        self.load_scripts()
        self.load_c()

    def load_scripts(self):
        """label -> body lines, file order per file, `.set` aliases, owning map."""
        self.bodies, self.owner, self.next_label, self.aliases = {}, {}, {}, {}
        files = glob.glob(os.path.join(self.root, "data/**/*.inc"), recursive=True)
        files += glob.glob(os.path.join(self.root, "data/**/*.s"), recursive=True)
        for path in sorted(files):
            rel = os.path.relpath(path, self.root)
            m = re.match(r"data/maps/([^/]+)/scripts\.inc$", rel)
            mapname = self.by_dir.get(m.group(1)) if m else None
            cur = None
            with open(path, encoding="utf-8", errors="replace") as fh:
                for raw in fh:
                    line = raw.split("@")[0].strip()
                    am = re.match(r"^\.set\s+(\w+)\s*,\s*(\w+)", line)
                    if am:
                        self.aliases[am.group(1)] = am.group(2)
                    lm = re.match(r"^(\w+)::?\s*$", line)
                    if lm:
                        if cur is not None:
                            self.next_label[cur] = lm.group(1)
                        cur = lm.group(1)
                        self.bodies[cur] = []
                        self.owner[cur] = (rel, mapname)
                    elif cur is not None and line:
                        self.bodies[cur].append(line)

    def load_c(self):
        """C flag writes (function, kind), var writes, and every identifier C mentions."""
        self.c_tokens = set()
        self.c_flag = collections.defaultdict(list)
        self.c_var = collections.defaultdict(set)
        self.c_var_wild = set()
        self.c_flag_refs = collections.defaultdict(set)
        paths = glob.glob(os.path.join(self.root, "src/**/*.c"), recursive=True)
        paths += glob.glob(os.path.join(self.root, "src/**/*.h"), recursive=True)
        paths += glob.glob(os.path.join(self.root, "include/**/*.h"), recursive=True)
        for path in sorted(paths):
            rel = os.path.relpath(path, self.root)
            if rel == "src/debug.c":
                continue
            with open(path, encoding="utf-8", errors="replace") as fh:
                text = strip_c_comments(fh.read())
            self.c_tokens.update(TOKEN.findall(text))
            # A var C reaches by pointer can take any value; a bare table entry is read.
            self.c_var_wild.update(re.findall(r"GetVarPointer\s*\(\s*(VAR_\w+)", text))
            if not rel.endswith(".c"):
                continue
            func = "?"
            for line in text.splitlines():
                fm = C_FUNC.match(line)
                if fm and not line.startswith((" ", "\t", "#")):
                    func = fm.group(1)
                for kind, flag in C_SET.findall(line):
                    self.c_flag[flag].append((kind.lower(), f"{rel}:{func}"))
                for var, expr in C_VARSET.findall(line):
                    self.c_var[var].add(expr.strip())
                for flag in re.findall(r"\bFLAG_\w+", line):
                    if not C_SET.search(line) or flag not in dict((f, k) for k, f in C_SET.findall(line)):
                        if "FlagGet" not in line:
                            self.c_flag_refs[flag].add(f"{rel}:{func}")


def live_labels(tree):
    roots = set()
    for name, d in tree.maps.items():
        if name not in tree.grouped:
            continue
        roots.add(f"{d['_dir']}_MapScripts")
        roots.add(f"{name}_MapScripts")
        for e in d.get("object_events", []) + d.get("coord_events", []) + d.get("bg_events", []):
            if e.get("script"):
                roots.add(e["script"])
    roots |= {lab for lab in tree.bodies if lab in tree.c_tokens}
    live, todo = set(), [r for r in roots if r in tree.bodies]
    while todo:
        lab = todo.pop()
        if lab in live:
            continue
        live.add(lab)
        body = tree.bodies[lab]
        for line in body:
            for t in TOKEN.findall(line):
                if t in tree.bodies and t not in live:
                    todo.append(t)
        if (not body or not TERMINATORS.match(body[-1])) and lab in tree.next_label:
            todo.append(tree.next_label[lab])
    return live


def reachable_maps(tree, live):
    seeds = set()
    for tok in tree.c_tokens:
        if tok in tree.by_id:
            seeds.add(tree.by_id[tok])
    for lab in live:
        for line in tree.bodies[lab]:
            for t in TOKEN.findall(line):
                if t in tree.by_id:
                    seeds.add(tree.by_id[t])
    seen, todo = set(), list(seeds)
    while todo:
        n = todo.pop()
        if n in seen or n not in tree.maps:
            continue
        seen.add(n)
        d = tree.maps[n]
        for w in d.get("warp_events", []):
            if w.get("dest_map") in tree.by_id:
                todo.append(tree.by_id[w["dest_map"]])
        for c in d.get("connections") or []:
            if c.get("map") in tree.by_id:
                todo.append(tree.by_id[c["map"]])
    return seen


def closure(tree, label, cache):
    if label in cache:
        return cache[label]
    seen, todo = set(), [label]
    while todo:
        lab = todo.pop()
        if lab in seen or lab not in tree.bodies:
            continue
        seen.add(lab)
        body = tree.bodies[lab]
        for line in body:
            for t in TOKEN.findall(line):
                if t in tree.bodies and not t.endswith("_Text") and "_Text_" not in t:
                    todo.append(t)
        if (not body or not TERMINATORS.match(body[-1])) and lab in tree.next_label:
            todo.append(tree.next_label[lab])
    cache[label] = seen
    return seen


def objects(tree):
    """(map, 1-based index, object) for every object event on a grouped map, and local ids."""
    out, localid = [], collections.defaultdict(list)
    for name, d in tree.maps.items():
        if name not in tree.grouped:
            continue
        for i, o in enumerate(d.get("object_events", []), 1):
            out.append((name, i, o))
            if o.get("local_id"):
                localid[o["local_id"]].append((name, i))
    return out, localid


def resolve_flag(tree, name, ids):
    seen = set()
    while name in tree.aliases and name not in seen and name not in ids:
        seen.add(name)
        name = tree.aliases[name]
    return ids.get(name)


def audit(root):
    tree = Tree(root)
    live = live_labels(tree)
    reach = reachable_maps(tree, live)
    objs, localid = objects(tree)

    names = set()
    for _, _, o in objs:
        if str(o.get("flag", "")).startswith("FLAG_"):
            names.add(o["flag"])
    for body in tree.bodies.values():
        for line in body:
            names.update(re.findall(r"\b(?:FLAG|VAR)_\w+", line))
    names.update(tree.c_flag)
    names.update(tree.c_var)
    names.update(tree.aliases.values())
    for d in tree.maps.values():
        for e in d.get("coord_events", []):
            if str(e.get("var", "")).startswith("VAR_"):
                names.add(e["var"])
    for body in tree.bodies.values():
        for line in body:
            if re.match(r"^((goto|call)_if_\w+|compare\w*|map_script_2|case|setvar)\b", line):
                names.update(re.findall(r"\b[A-Z][A-Z0-9_]+\b", line))
    for exprs in tree.c_var.values():
        for expr in exprs:
            names.update(re.findall(r"\b[A-Z][A-Z0-9_]+\b", expr))
    names.update(("DAILY_FLAGS_START", "DAILY_FLAGS_END"))
    ids = resolve_ids(root, names)

    def transient(fid):
        return vme.is_transient_state("FLAG", fid) or ids["DAILY_FLAGS_START"] <= fid <= ids["DAILY_FLAGS_END"]

    def flag_id(name):
        return resolve_flag(tree, name, ids)

    obj_by_map_index = {(m, i): o for m, i, o in objs}

    def target(arg, mapname):
        arg = arg.strip()
        if arg in localid:
            hits = [h for h in localid[arg] if mapname is None or h[0] == mapname] or localid[arg]
            return hits
        n = literal(arg, ids)
        if n is not None and mapname is not None:
            return [(mapname, n)]
        return []

    # Writes per flag id: (kind, site, label or None, map or None)
    writes = collections.defaultdict(list)
    for lab, body in tree.bodies.items():
        rel, mapname = tree.owner[lab]
        for line in body:
            m = re.match(r"^(setflag|clearflag)\s+(\w+)", line)
            if m:
                fid = flag_id(m.group(2))
                if fid is not None:
                    writes[fid].append(("set" if m.group(1) == "setflag" else "clear", lab, lab, mapname))
                continue
            # A flag id handed to a special through a var (Silph Co.'s card-key doors) can go
            # either way.
            m = re.match(r"^setvar\s+VAR_\w+\s*,\s*(FLAG_\w+)", line)
            if m:
                fid = flag_id(m.group(1))
                if fid is not None:
                    writes[fid].append(("set", lab, lab, mapname))
                    writes[fid].append(("clear", lab, lab, mapname))
                continue
            # removeobject and setfollowernpc set the object's flag; addobject spawns it
            # whatever the flag says, so for this audit it reveals the object like a clear.
            m = re.match(r"^(removeobject|addobject|setfollowernpc)\s+([^,]+)(?:,\s*(\w+))?", line)
            m2 = re.match(r"^(removeobjectat|addobjectat)\s+([^,]+),\s*(\w+)", line)
            if m2:
                cmd, arg, mp = m2.group(1), m2.group(2), tree.by_id.get(m2.group(3), mapname)
            elif m and m.group(1) != "setfollowernpc":
                cmd, arg = m.group(1), m.group(2)
                mp = tree.by_id.get(m.group(3), mapname) if m.group(3) else mapname
            elif m:
                cmd, arg, mp = m.group(1), m.group(2), mapname
            else:
                continue
            kind = "clear" if cmd.startswith("addobject") else "set"
            for tm, ti in target(arg, mp):
                o = obj_by_map_index.get((tm, ti))
                if o and str(o.get("flag", "")).startswith("FLAG_"):
                    fid = flag_id(o["flag"])
                    if fid is not None:
                        writes[fid].append((kind, lab, lab, mapname))
    for name, sites in tree.c_flag.items():
        fid = flag_id(name)
        if fid is None:
            continue
        for kind, site in sites:
            kinds = ("set", "clear") if kind == "toggle" else (kind,)
            for k in kinds:
                func = site.split(":")[-1]
                writes[fid].append((k, "NEWGAME:" + site if func in NEW_GAME_FUNCS else site, None, None))
    c_refs = collections.defaultdict(set)
    for name, sites in tree.c_flag_refs.items():
        fid = flag_id(name)
        if fid is not None:
            c_refs[fid] |= sites

    newgame = set()
    for s in NEW_GAME_SCRIPTS:
        newgame |= closure(tree, s, {})

    findings = []
    cache = {}
    by_flag = collections.defaultdict(list)
    for mapname, idx, o in objs:
        flag = str(o.get("flag", ""))
        if not flag.startswith("FLAG_"):
            continue
        fid = flag_id(flag)
        if fid is None or transient(fid):
            continue
        by_flag[fid].append((mapname, idx, o, flag))

    for fid, users in sorted(by_flag.items()):
        content = [u for u in users if u[2].get("script", "") not in NO_SCRIPT
                   or u[2].get("trainer_type", "TRAINER_TYPE_NONE") != "TRAINER_TYPE_NONE"]
        if not content:
            continue
        sets = [w for w in writes[fid] if w[0] == "set" and (w[2] is None or w[2] in live)]
        clears = [w for w in writes[fid] if w[0] == "clear"]
        live_clears = [w for w in clears if w[2] is None or (w[2] in live and (w[3] is None or w[3] in reach))]
        if not sets or live_clears or fid in c_refs:
            continue
        own = set()
        for m, i, o, _ in content:
            own |= closure(tree, o.get("script", ""), cache)
        external, local = [], []
        for w in sets:
            if w[2] in own:
                continue
            if w[2] in newgame or w[1].startswith("NEWGAME:"):
                external.append("new game (" + (w[2] or w[1].split(":", 1)[1]) + ")")
            elif w[3] is not None and w[3] in {u[0] for u in content}:
                local.append(w[1])
            else:
                external.append(w[1] + (f" [{w[3]}]" if w[3] else ""))
        if not external and not local:
            continue
        flag = content[0][3]
        where = ", ".join(sorted({f"{m}#{i}" for m, i, _, _ in content}))
        if clears:
            kind = "DEAD-CLEARER"
            why = "clears only in " + ", ".join(sorted({w[1] for w in clears}))
        elif external:
            kind = "HIDDEN-FOR-GOOD"
            why = "set by " + ", ".join(sorted(set(external)))
        else:
            kind = "LOCAL"
            why = "set by " + ", ".join(sorted(set(local)))
        findings.append((kind, flag, where, why))

    findings += unset_flags(tree, live, objs, writes, c_refs, flag_id, transient)
    findings += unwritten_vars(tree, live, ids)
    return findings, len(objs), len(live), len(reach)


def unset_flags(tree, live, objs, writes, c_refs, flag_id, transient):
    """Flags a live script branches on being set that nothing ever sets."""
    exempt = set()
    for _, _, o in objs:
        # An object's own script can remove it through VAR_LAST_TALKED, which names no flag.
        if str(o.get("flag", "")).startswith("FLAG_") and o.get("script", "") not in NO_SCRIPT:
            exempt.add(flag_id(o["flag"]))
    for d in tree.maps.values():
        for e in d.get("bg_events", []):
            if str(e.get("flag", "")).startswith("FLAG_"):
                exempt.add(flag_id(e["flag"]))
    reads = collections.defaultdict(set)
    for lab in live:
        for line in tree.bodies[lab]:
            m = re.match(r"^(goto_if_set|call_if_set|vgoto_if_set|checkflag)\s+(FLAG_\w+)", line)
            if m:
                reads[m.group(2)].add(lab)
    out = []
    for name, sites in sorted(reads.items()):
        fid = flag_id(name)
        if fid is None or fid == 0 or transient(fid) or fid in exempt or fid in c_refs:
            continue
        if any(w[0] == "set" and (w[2] is None or w[2] in live) for w in writes[fid]):
            continue
        out.append(("UNSET-FLAG", name, ", ".join(sorted(sites)[:3]), "nothing live sets it"))
    return out


def unwritten_vars(tree, live, ids):
    """(var, value) a live reader waits for that no writer can produce."""
    reads = collections.defaultdict(set)
    writes = collections.defaultdict(set)
    wild = set()

    def vid(name):
        return resolve_flag(tree, name, ids)

    for lab in live:
        body = tree.bodies[lab]
        pending = None
        switch = None
        for line in body:
            m = COND.match(line)
            if m and m.group(2) in ("eq", "ge", "gt"):
                v = literal(m.group(4), ids)
                if v is not None:
                    reads[(m.group(3), v + (1 if m.group(2) == "gt" else 0), m.group(2) != "eq")].add(lab)
            m = COMPARE.match(line)
            if m:
                pending = (m.group(1), literal(m.group(2), ids))
                continue
            m = COND_AFTER_COMPARE.match(line)
            if m and pending and pending[1] is not None and m.group(2) in ("eq", "ge", "gt"):
                reads[(pending[0], pending[1] + (1 if m.group(2) == "gt" else 0), m.group(2) != "eq")].add(lab)
            m = MAP_SCRIPT_2.match(line)
            if m:
                v = literal(m.group(2), ids)
                if v is not None:
                    reads[(m.group(1), v, False)].add(lab)
            m = SWITCH.match(line)
            if m:
                switch = m.group(1)
            m = CASE.match(line)
            if m and switch:
                v = literal(m.group(1), ids)
                if v is not None:
                    reads[(switch, v, False)].add(lab)
            m = SETVAR.match(line)
            if m:
                v = literal(m.group(2), ids)
                if v is None:
                    wild.add(vid(m.group(1)))
                else:
                    writes[vid(m.group(1))].add(v)
            m = WILD_VAR.match(line)
            if m:
                wild.add(vid(m.group(2)))
    for name, d in tree.maps.items():
        if name not in tree.grouped:
            continue
        for e in d.get("coord_events", []):
            var = str(e.get("var", ""))
            if var.startswith("VAR_") and e.get("script") in live:
                v = literal(str(e.get("var_value", "0")), ids)
                if v is not None:
                    reads[(var, v, False)].add(f"{name} coord ({e.get('x')},{e.get('y')})")
    for var, exprs in tree.c_var.items():
        for expr in exprs:
            v = literal(expr, ids)
            if v is None:
                wild.add(vid(var))
            else:
                writes[vid(var)].add(v)
    # A var C reaches by address, through a table or a macro can take any value.
    wild |= {vid(v) for v in tree.c_var_wild}

    out = []
    for (var, value, atleast), sites in sorted(reads.items()):
        i = vid(var)
        if i is None or value == 0 or vme.is_transient_state("VAR", i) or i in wild:
            continue
        got = writes.get(i, set())
        if (value in got) if not atleast else any(g >= value for g in got):
            continue
        op = ">=" if atleast else "=="
        out.append(("UNWRITTEN-VAR", f"{var}{op}{value}", ", ".join(sorted(sites)[:3]),
                    "writes " + (",".join(str(g) for g in sorted(got)) or "none")))
    return out


def source_index(root):
    """Flag sets and clears in a source decomp, its new-game reset kept apart."""
    sets, clears, newgame = collections.defaultdict(set), collections.defaultdict(set), set()
    files = glob.glob(os.path.join(root, "data/**/*.inc"), recursive=True)
    files += glob.glob(os.path.join(root, "data/**/*.s"), recursive=True)
    for path in sorted(files):
        rel = os.path.relpath(path, root)
        label = None
        with open(path, encoding="utf-8", errors="replace") as fh:
            for raw in fh:
                line = raw.split("@")[0].strip()
                lm = re.match(r"^(\w+)::?$", line)
                if lm:
                    label = lm.group(1)
                    continue
                m = re.match(r"^(setflag|clearflag)\s+(FLAG_\w+)", line)
                if not m:
                    continue
                if rel.endswith("new_game.inc") or label in NEW_GAME_SCRIPTS:
                    if m.group(1) == "setflag":
                        newgame.add(m.group(2))
                    continue
                (sets if m.group(1) == "setflag" else clears)[m.group(2)].add(rel)
    for path in sorted(glob.glob(os.path.join(root, "src/**/*.c"), recursive=True)):
        rel = os.path.relpath(path, root)
        with open(path, encoding="utf-8", errors="replace") as fh:
            text = strip_c_comments(fh.read())
        for kind, flag in re.findall(r"\bFlag(Set|Clear)\s*\(\s*(FLAG_\w+)", text):
            if rel.endswith("new_game.c"):
                if kind == "Set":
                    newgame.add(flag)
                continue
            (sets if kind == "Set" else clears)[flag].add(rel)
    return sets, clears, newgame


def check_sources(root, sources):
    """Verify every PARITY claim against its source, and list UNREGISTERED objects: a hide flag
    the source sets at new game that this tree sets nowhere but in the object's own script, so the
    object stands in the world from turn one (Olivine's Oak, issue of stress pass 9)."""
    index = {name: source_index(path) for name, path in sources.items()}
    out, errors = [], []
    for (kind, key), name in sorted(PARITY.items()):
        if name not in index:
            continue
        sets, clears, _ = index[name]
        if kind in ("HIDDEN-FOR-GOOD", "LOCAL") and key in clears:
            errors.append(f"PARITY-WRONG {kind} {key}: {name} clears it in " + ", ".join(sorted(clears[key])))
        if kind == "UNSET-FLAG" and key in sets:
            errors.append(f"PARITY-WRONG {kind} {key}: {name} sets it in " + ", ".join(sorted(sets[key])))
    tree = Tree(root)
    objs, _ = objects(tree)
    tree_sets = collections.defaultdict(set)
    for lab, body in tree.bodies.items():
        for line in body:
            m = re.match(r"^setflag\s+(FLAG_\w+)", line)
            if m:
                tree_sets[m.group(1)].add(lab)
    for flag, sites in tree.c_flag.items():
        tree_sets[flag] |= {site for kind, site in sites if kind != "clear"}
    region = vme.load_mapsec_regions()
    cache, seen = {}, set()
    for mapname, idx, o in objs:
        flag = str(o.get("flag", ""))
        if not flag.startswith("FLAG_") or flag in seen:
            continue
        seen.add(flag)
        name = SOURCE_FOR_REGION[region(tree.maps[mapname].get("region_map_section", ""))]
        if name not in index or flag not in index[name][2]:
            continue
        own = closure(tree, o.get("script", ""), cache)
        if not tree_sets[flag] - own:
            out.append(("UNREGISTERED", flag, f"{mapname}#{idx}",
                        f"{name} hides it at new game; here only its own script sets it"))
    return out, errors


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--root", default=vme.ROOT)
    ap.add_argument("--all", action="store_true", help="also print LOCAL removals and baselined findings")
    ap.add_argument("--source", action="append", default=[], metavar="NAME=DIR",
                    help="a source decomp checkout (pokeemerald, pokefirered, pokemonHnS); verifies the "
                         "PARITY claims and adds UNREGISTERED findings")
    args = ap.parse_args()
    sources = dict(item.split("=", 1) for item in args.source)
    for name in sources:
        if name not in SOURCE_FOR_REGION.values():
            sys.exit(f"AuditHideFlags: unknown source {name}; use one of {sorted(SOURCE_FOR_REGION.values())}")
    findings, nobj, nlive, nreach = audit(args.root)
    errors = []
    if sources:
        extra, errors = check_sources(args.root, sources)
        findings += extra
        for e in errors:
            print(e)
    unexplained, matched = [], set()
    for kind, key, where, why in findings:
        k = (kind, key)
        if k in PARITY:
            reason = f"{PARITY[k]} does the same (rerun with --source to verify)"
        else:
            reason = INTENDED.get(k) or PENDING.get(k)
        if reason:
            matched.add(k)
        elif kind != "LOCAL":
            unexplained.append(key)
        if (reason or kind == "LOCAL") and not args.all:
            continue
        tag = "baseline" if reason else ("info" if kind == "LOCAL" else "FAIL")
        print(f"{kind} [{tag}] {key}  at {where}  {why}")
        if reason:
            print(f"    baseline: {reason}")
    checked = {k for k in set(PARITY) | set(INTENDED) if k[0] != "UNREGISTERED" or sources}
    stale = sorted(checked - matched)
    for k in stale:
        print(f"STALE-BASELINE {k[0]} {k[1]}: no longer a finding; delete the entry")
    counts = collections.Counter(f[0] for f in findings)
    print(f"AuditHideFlags: {nobj} objects, {nlive} live labels, {nreach} reachable maps; "
          + ", ".join(f"{k} {v}" for k, v in sorted(counts.items()))
          + f"; {len(unexplained)} unexplained, {len(stale)} stale baseline"
          + (f", {len(errors)} wrong parity claims" if sources else ""))
    return 1 if unexplained or stale or errors else 0


if __name__ == "__main__":
    sys.exit(main())
