#!/usr/bin/env python3
"""Engine strings that name one region's people, places or devices, and who shows them.

Map scripts are covered by ValidateRegionText.py and ValidateConfigRules.py. This audit reads the C
side: every string literal under src/ that names a region-specific character, place or device (DAD,
BIRCH, OAK, ELM, LANETTE, POKéNAV, POKéGEAR, a town, a region), every place that uses it, and whether
the code there picks by region: the function calls GetCurrentRegion() or a friend, calls a helper
that does (GetPcCreator()), or the string sits in a table indexed by REGION_*. Two strings printed
Emerald's wording in Kanto and Johto this way: the item refusal's "DAD's advice" (PR #695) and the
Pokedex diploma's "HOENN" from Celadon's game designer.

A string fails --check when some use does not pick by region and the string is neither in REVIEWED
nor defined in a SCOPED file. Each entry says why the line is right in every region that can show it,
checked against pokeemerald, pokefirered and pokemonHnS at the same call site. A REVIEWED entry that
no longer matches an unpicked string fails too, so the table cannot rot.

Run from the repo root:
  python3 test/overworld/AuditEngineRegionText.py          # report every flagged string
  python3 test/overworld/AuditEngineRegionText.py --check  # exit 1 on an unreviewed or stale entry
"""
import bisect
import fnmatch
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

# Name -> region it belongs to. Upper-case forms are the GBA house style; the Title-case forms are
# the expansion's. Ambiguous words (AQUA, MAY, VIOLET, BILL) are matched upper-case only.
NAMES = {
    "HOENN": [r"HOENN|Hoenn", r"BIRCH|Birch", r"\bDAD\b|\bDad\b|NORMAN|Norman", r"LANETTE|Lanette",
              r"POKéNAV|PokéNav|Pokénav|POKENAV|PokeNav", r"STEVEN|Steven", r"WALLY|Wally",
              r"TEAM AQUA|Team Aqua|TEAM MAGMA|Team Magma|\bMAGMA\b|\bAQUA\b", r"\bMAY\b|BRENDAN",
              r"DEVON|Devon", r"BRINEY|Briney",
              r"LITTLEROOT|Littleroot|OLDALE|Oldale|PETALBURG|Petalburg|RUSTBORO|Rustboro|DEWFORD|Dewford|"
              r"SLATEPORT|Slateport|MAUVILLE|Mauville|VERDANTURF|Verdanturf|FALLARBOR|Fallarbor|"
              r"LAVARIDGE|Lavaridge|FORTREE|Fortree|LILYCOVE|Lilycove|MOSSDEEP|Mossdeep|"
              r"SOOTOPOLIS|Sootopolis|PACIFIDLOG|Pacifidlog|EVER GRANDE|Ever Grande"],
    "KANTO": [r"KANTO|Kanto", r"\bOAK\b|\bOak\b", r"\bBILL\b", r"PALLET|Pallet|VIRIDIAN|Viridian|PEWTER|Pewter|"
              r"CERULEAN|Cerulean|VERMILION|Vermilion|\bLAVENDER\b|CELADON|Celadon|FUCHSIA|Fuchsia|"
              r"SAFFRON|Saffron|CINNABAR|Cinnabar|SEVII|Sevii"],
    "JOHTO": [r"JOHTO|Johto", r"\bELM\b|\bElm\b", r"POKéGEAR|PokéGear|Pokégear|POKEGEAR", r"\bKURT\b|\bKurt\b",
              r"NEW BARK|New Bark|CHERRYGROVE|Cherrygrove|\bVIOLET\b|AZALEA|Azalea|GOLDENROD|Goldenrod|"
              r"ECRUTEAK|Ecruteak|OLIVINE|Olivine|CIANWOOD|Cianwood|MAHOGANY|Mahogany|BLACKTHORN|Blackthorn"],
}
NAME_RE = [(region, re.compile(p)) for region, pats in NAMES.items() for p in pats]

PICKS_REGION = re.compile(r"\b(GetCurrentRegion|GetActiveRegion|gCurrentRegion|GetRegionForSectionId|"
                          r"REGION_(?:KANTO|JOHTO|HOENN)|IsRegionChampion|currentRegion)\b")

# Data that is species, move, item or trainer lore, not something the engine says to the player.
SKIP = re.compile(r"^src/data/(pokemon|pokemon_graphics|moves_info|items|abilities|battle_frontier|trainers|"
                  r"text/(species|move|item|abilit|nature|gift_ribbon|ribbon))")

# string id -> why it is right in every region that can show it.
REVIEWED = {
    "STRINGID_DONTLEAVEBIRCH": "only in a BATTLE_TYPE_FIRST_BATTLE battle; Kanto's tutorial battle prints "
                               "pokefirered's OAK line instead (battle_controller_oak_old_man.c), Johto starts none",
    "gText_BirchInTrouble": "the starter bag of Birch's rescue on Route 101",
    "gText_DadsAdvice": "item refusals: DisplayDadsAdviceCannotUseItemMessage picks OAK (pokefirered), ELM "
                        "(pokemonHnS) or DAD by region (PR #695); the other caller is the Battle Pyramid bag",
    "gText_Dad": "the TV's MOM/DAD might like this program; every region's player has both, pokemonHnS keeps it",
    "gText_ExpandedPlaceholder_Aqua": "the {AQUA} placeholder of Emerald's scripts",
    "gText_ExpandedPlaceholder_Magma": "the {MAGMA} placeholder of Emerald's scripts",
    "gText_ExpandedPlaceholder_Brendan": "the Hoenn rival's Match Call name; {RIVAL} picks by region in "
                                         "ExpandPlaceholder_RivalName",
    "gText_ExpandedPlaceholder_May": "the Hoenn rival's Match Call name; {RIVAL} picks by region in "
                                     "ExpandPlaceholder_RivalName",
    "gText_MenuPokenav": "the player carries one PokéNav in every region (Johto's scripts hand over the POKéNAV "
                         "where pokemonHnS hands over a POKéGEAR); its own screens call it POKéNAV",
    "gText_MenuOptionPokenav": "the forced start menu of the PokéNav tutorial in Rustboro",
    "MultichoiceList_BattlePikeRules": "the Battle Pike's rules (Battle Frontier)",
    "MultichoiceList_BrineyOffDewford": "Mr. Briney's boat",
    "MultichoiceList_BrineyOnDewford": "Mr. Briney's boat",
    "gText_LilycoveCity": "S.S. Tidal destinations from Hoenn's harbors",
    "gText_SlateportCity": "S.S. Tidal destinations from Hoenn's harbors",
    "MultichoiceList_OlivineHarbor": "the ferry's destination, named as itself",
    "gText_Vermilion": "the Seagallop ferry's destination, named as itself",
    "MultichoiceList_BnetLeaderH2": "Battle Net leader picker; the player picks a region's leader by name",
    "MultichoiceList_BnetRegion": "Battle Net region picker",
    "sMultichoiceList_RegionHub": "the World Transit region picker",
    "gText_OakImportantToGetToKnowPokemonThroughly": "pokefirered's party-menu line in Kanto's tutorial battle",
    "gText_WhatWillWallyDo": "Wally's catching demo on Route 102",
    "gTrainerClasses": "trainer class names, each shown for its own trainers",
    "sEeveeOtName": "Bill's Eevee in Goldenrod, as in pokemonHnS",
    "sText_Steven": "the Lilycove Fan Club's trainer names",
    "src/map_name_popup.c:GetPopUpMapName:CELADON DEPT": "the popup of Kanto's Celadon Dept. Store maps",
    "sText_TrainerCardHoenn": "badge page labels; the card's page is the region whose badges it shows",
    "sText_TrainerCardJohto": "badge page labels; the card's page is the region whose badges it shows",
    "sText_TrainerCardKanto": "badge page labels; the card's page is the region whose badges it shows",
}

# Files whose every string is shown by one region only, or is not narration.
SCOPED_WHY = {
    "src/battle_controller_oak_old_man.c": "Kanto's tutorial battle and Old Man demo, pokefirered's lines",
    "src/landmark.c": "landmarks of Hoenn routes, looked up by Hoenn map section",
    "src/data/contest_opponents.h": "opponents in Hoenn's Contest Halls",
    "src/data/easy_chat/": "Easy Chat dictionary words",
    "src/debug.c": "the debug menu",
    "src/mystery_event_msg.c": "Emerald's e-Reader Mystery Event replies",
    "src/pokenav_match_call_data.c": "Match Call contacts, each named as themselves",
    "src/regional_centers.c": "every region's Pokemon Centers, looked up by map",
    "src/special_pokemon.c": "the Special Pokemon checklist, naming where each gift is found",
    "src/story_progress_menu.c": "the story menu's region names, one per region",
    "src/player_outfit.c": "outfit names",
}
SCOPED = tuple(SCOPED_WHY)

LITERAL = re.compile(r'(?:_|COMPOUND_STRING)\(\s*((?:"(?:[^"\\]|\\.)*"\s*)+)\)')
DEF = re.compile(r"(?:static\s+)?const\s+u8\s+(\w+)\s*\[[^\]]*\]\s*=\s*$")
SLOT = re.compile(r"\[\s*(\w+)\s*\]\s*=\s*$")
IDENT = re.compile(r"\b[A-Za-z_]\w*\b")


COMMENT_OR_QUOTE = re.compile(r'//[^\n]*|/\*.*?\*/|"(?:\\.|[^"\\\n])*"|\'(?:\\.|[^\'\\\n])*\'', re.S)
TOKEN = re.compile(r'"(?:\\.|[^"\\\n])*"|\'(?:\\.|[^\'\\\n])*\'|[{};]|\n(?=#)')


def strip_comments(src):
    """Blank // and /* */ comments, keep strings and line numbers."""
    def blank(m):
        t = m.group(0)
        return t if t[0] in "\"'" else re.sub(r"[^\n]", " ", t)
    return COMMENT_OR_QUOTE.sub(blank, src)


class CFile:
    """A C file split into top-level items: functions (name, body) and data initializers."""

    def __init__(self, path):
        self.path = path
        self.rel = os.path.relpath(path, ROOT)
        self.text = strip_comments(open(path, encoding="utf-8", errors="replace").read())
        self.items = []  # [start, end, kind, name]
        self.newlines = [m.start() for m in re.finditer("\n", self.text)]
        depth, start, t = 0, 0, self.text
        for m in TOKEN.finditer(t):
            c = m.group(0)
            if c == "{":
                if depth == 0:
                    self.items.append([m.start(), len(t), *self.classify(t[start:m.start()])])
                depth += 1
            elif c == "}":
                depth -= 1
                if depth == 0 and self.items:
                    self.items[-1][1] = m.start()
                    start = m.end()
            elif depth == 0 and (c == ";" or c == "\n"):
                start = m.end()
        self.starts = [it[0] for it in self.items]

    @staticmethod
    def classify(head):
        head = re.sub(r"^\s*#.*$", "", head, flags=re.M).strip()
        if "=" in head:
            m = re.search(r"(\w+)\s*(?:\[[^\]]*\]\s*)*=\s*$", head)
            return "data", m.group(1) if m else "?"
        m = re.search(r"(\w+)\s*\([^()]*(?:\([^()]*\)[^()]*)*\)\s*$", head)
        if m:
            return "func", m.group(1)
        return "other", "?"

    def owner(self, pos):
        k = bisect.bisect_right(self.starts, pos) - 1
        if k >= 0:
            start, end, kind, name = self.items[k]
            if pos <= end:
                return kind, name, self.text[start:end]
        return "top", None, ""

    def line(self, pos):
        return bisect.bisect_left(self.newlines, pos) + 1


def region_hits(s):
    return sorted({(region, m.group(0)) for region, rx in NAME_RE for m in rx.finditer(s)})


def tracked(*patterns):
    """Committed files only: build outputs (map events, generated headers) differ between checkouts."""
    try:
        out = subprocess.run(["git", "ls-files", "-z", "--", *patterns], cwd=ROOT, capture_output=True, check=True).stdout
        names = out.decode().split("\0")
    except (OSError, subprocess.CalledProcessError):
        # The release gate checks a built source snapshot with no .git. test/verify.py lists the
        # snapshot's source files there; like a git pathspec, fnmatch lets `*` cross directories.
        with open(os.path.join(ROOT, ".tracked-files"), encoding="utf-8") as fh:
            names = [n for n in fh.read().split("\n") if any(fnmatch.fnmatch(n, pat) for pat in patterns)]
    return sorted(p for p in names if p and os.path.isfile(os.path.join(ROOT, p)))


def load():
    files = [CFile(os.path.join(ROOT, p)) for p in tracked("src/*.c", "src/*.h")]
    index = {}  # identifier -> [(CFile or asm path, pos)]
    for f in files:
        for m in IDENT.finditer(f.text):
            index.setdefault(m.group(0), []).append((f, m.start()))
    asm = {}
    for rel in tracked("data/*.inc", "data/*.s"):
        asm[rel] = open(os.path.join(ROOT, rel), encoding="utf-8", errors="replace").read()
        for m in IDENT.finditer(asm[rel]):
            index.setdefault(m.group(0), []).append((rel, m.start()))
    return files, asm, index


def collect_strings(files):
    """Every flagged literal: (id, file, line, text, names). id is the variable it initialises, or
    file:line for an anonymous COMPOUND_STRING."""
    found = []
    for f in files:
        if SKIP.match(f.rel):
            continue
        for m in LITERAL.finditer(f.text):
            text = "".join(re.findall(r'"((?:[^"\\]|\\.)*)"', m.group(1)))
            names = region_hits(text)
            if not names:
                continue
            before = f.text[max(0, m.start() - 200):m.start()]
            d = DEF.search(before)
            kind, owner, _ = f.owner(m.start())
            slot = SLOT.search(f.text, max(0, m.start() - 120), m.start())
            if d and (kind == "top" or d.group(1) == owner):
                sid = d.group(1)
            elif kind == "data" and slot and slot.group(1).startswith("REGION_"):
                sid = f"{owner}[{slot.group(1)}]"  # a table indexed by region: the index picks
            elif kind == "data" and slot and slot.group(1).startswith("STRINGID_"):
                sid = slot.group(1)  # battle strings: code and scripts name the id, not the table
            elif kind == "data" and owner and not owner.startswith("?"):
                sid = owner  # a literal inside a table: the table is what the code reads
            elif kind == "func":
                sid = f"{f.rel}:{owner}:{text}"
            else:
                sid = f"{f.rel}:{f.line(m.start())}"
            found.append((sid, f, m.start(), text, names))
    return found


def region_pickers(files):
    """Functions that branch on the region themselves, such as GetPcCreator()."""
    return {name for f in files for start, end, kind, name in f.items
            if kind == "func" and PICKS_REGION.search(f.text[start:end])}


def picks(body, pickers):
    """How the code around a use picks by region: itself, through a helper that does, or not at all."""
    if PICKS_REGION.search(body):
        return "picks region"
    for name in sorted(set(IDENT.findall(body)) & pickers):
        return f"picks via {name}()"
    return None


def uses_of(sid, asm, index, pickers, depth=0, seen=None):
    """Use sites of a symbol as (where, how it picks). Follows a table up to the code that reads it."""
    seen = seen if seen is not None else set()
    if sid in seen or depth > 2:
        return []
    seen.add(sid)
    out = []
    for f, pos in index.get(sid, []):
        if isinstance(f, str):
            out.append((f"{f}:{asm[f].count(chr(10), 0, pos) + 1} (script)", None))
            continue
        kind, owner, body = f.owner(pos)
        if kind == "func":
            out.append((f"{f.rel}:{f.line(pos)} {owner}()", picks(body, pickers)))
        elif kind == "data" and owner and owner != sid:
            sub = uses_of(owner, asm, index, pickers, depth + 1, seen)
            out += [(f"{w} via {owner}", how) for w, how in sub] or [(f"{f.rel}:{f.line(pos)} in {owner} (unread)", None)]
    return out


def audit():
    files, asm, index = load()
    pickers = region_pickers(files)
    report = {}
    for sid, f, pos, text, names in collect_strings(files):
        if "[REGION_" in sid:
            uses = [(f"{f.rel}:{f.line(pos)} {sid}", "indexed by region")]
        elif ":" in sid:
            kind, owner, body = f.owner(pos)
            uses = [(f"{f.rel}:{f.line(pos)} {owner}()", picks(body, pickers))]
        else:
            uses = uses_of(sid, asm, index, pickers)
        entry = report.setdefault(sid, {"def": f"{f.rel}:{f.line(pos)}", "texts": [], "names": set(), "uses": uses})
        entry["texts"].append(text)
        entry["names"].update(names)
    for sid, e in report.items():
        bare = [w for w, how in e["uses"] if not how]
        e["status"] = ("UNUSED" if not e["uses"] else "PICKED" if not bare
                       else "REVIEWED" if sid in REVIEWED or e["def"].startswith(SCOPED) else "OPEN")
    return report


def main():
    check = "--check" in sys.argv
    report = audit()
    open_ids = sorted(sid for sid, e in report.items() if e["status"] == "OPEN")
    stale = sorted(sid for sid in REVIEWED if report.get(sid, {}).get("status") != "REVIEWED")
    for sid in sorted(report):
        e = report[sid]
        if check and e["status"] != "OPEN":
            continue
        regions = ",".join(sorted({r for r, _ in e["names"]}))
        print(f"[{e['status']}] {sid} ({e['def']}) names {regions}: {sorted({w for _, w in e['names']})}")
        print(f"    \"{e['texts'][0][:110]}\"" + (f" (+{len(e['texts']) - 1} more)" if len(e["texts"]) > 1 else ""))
        if e["status"] == "REVIEWED":
            print(f"    reviewed: {REVIEWED.get(sid) or SCOPED_WHY[next(p for p in SCOPED if e['def'].startswith(p))]}")
        for w, how in e["uses"][:8]:
            print(f"    {how or 'any region'}: {w}")
        if len(e["uses"]) > 8:
            print(f"    ... {len(e['uses']) - 8} more uses")
    counts = {k: sum(e["status"] == k for e in report.values()) for k in ("PICKED", "REVIEWED", "UNUSED", "OPEN")}
    print(f"{len(report)} flagged strings: " + ", ".join(f"{v} {k.lower()}" for k, v in counts.items()))
    for sid in stale:
        print(f"STALE: REVIEWED[{sid!r}] matches no string with an unpicked use; delete the entry")
    if check and stale:
        return 1
    if check and open_ids:
        print(f"FAIL: {len(open_ids)} string(s) shown in any region name one region; pick the string by "
              f"GetCurrentRegion() at the call site, or check the source game of every region that shows it "
              f"and add a REVIEWED entry")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
