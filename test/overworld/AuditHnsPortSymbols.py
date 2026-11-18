#!/usr/bin/env python3
"""Find names in Johto map scripts that mean something else here than they did in pokemonHnS.

The Johto map scripts were ported from pokemonHnS text for text. A constant, special or shared
script they name resolves against THIS tree, so a name both trees define but define differently
assembles cleanly and does the FRLG/Emerald thing. Found so far: INGAME_TRADE_MR_MIME (HnS:
Emy's Dodrio trade; here: FRLG's Route 2 Abra trade), EASY_CHAT_TYPE_INTERVIEW (HnS checked the
Odd Egg answer in its own easy_chat.c), relearner specials reading VAR_0x8004 (#638).

For every Johto map whose scripts came from HnS, each name that BOTH its script and the HnS
original use is fingerprinted in both trees by what the name means:

    trade      INGAME_TRADE_*       the species given and the species asked for
    special    special/specialvar/  which gSpecialVar_* the C function reads or writes, so a
               callnative           changed argument or result convention shows
    ctype      EASY_CHAT_TYPE_*     the C functions that branch on the type
    multi      MULTI_*              the multichoice options, in order (each pair must share a word)
    trainer    TRAINER_*            trainer name, and at least one species in common
    item       ITEM_*               item name (one spelling may abbreviate the other)
    map        MAP_*                which map it is (HnS map names translated by HNS_MAP_NAMES)
    macro      script commands      the asm macro body
    label      shared scripts       the body of a label the map calls but does not define
                                    (Common_*, EventScript_*, movements)

A fingerprint that differs is reported unless HnsPortSymbols_baseline.tsv explains it.

    AuditHnsPortSymbols.py               check against the committed HnS snapshot (no HnS needed)
    AuditHnsPortSymbols.py --report      list every difference, explained or not, exit 0
    AuditHnsPortSymbols.py --snapshot HNS
                                         refresh HnsPortSymbols.json from a pokemonHnS checkout
                                         with data/maps, data/scripts, asm, include and src

HNS is a sparse clone (see hns-upstream-is-the-oracle).
"""
import argparse
import fnmatch
import glob
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
SNAPSHOT = os.path.join(HERE, "HnsPortSymbols.json")
BASELINE = os.path.join(HERE, "HnsPortSymbols_baseline.tsv")

# Our Johto map -> its HnS original, where the port renamed the map so it would not collide with
# the FRLG map of the same name. Everything else keeps its HnS name.
OUR_MAP_FROM_HNS = {
    "IndigoPlateau": "JohtoIndigoPlateau",
    "IndigoPlateau_PokemonCenter": "JohtoIndigoPlateau_PokemonCenter",
    "PokemonLeague_BrunosRoom": "JohtoPokemonLeague_BrunosRoom",
    "PokemonLeague_ChampionsRoom": "JohtoPokemonLeague_ChampionsRoom",
    "PokemonLeague_HallOfFame": "JohtoPokemonLeague_HallOfFame",
    "PokemonLeague_KarensRoom": "JohtoPokemonLeague_KarensRoom",
    "PokemonLeague_KogasRoom": "JohtoPokemonLeague_KogasRoom",
    "PokemonLeague_WillsRoom": "JohtoPokemonLeague_WillsRoom",
    "Route23": "JohtoRoute23",
    "VictoryRoadKanto_1F": "JohtoVictoryRoad_1F",
    "VictoryRoadKanto_B1F": "JohtoVictoryRoad_B1F",
    "VictoryRoadKanto_B2F": "JohtoVictoryRoad_B2F",
    "RocketHideout_B1F": "MahoganyHideout_B1F",
    "RocketHideout_B2F": "MahoganyHideout_B2F",
    "RocketHideout_B3F": "MahoganyHideout_B3F",
}
HNS_MAP_FROM_OURS = {v: k for k, v in OUR_MAP_FROM_HNS.items()}

IDENT = re.compile(r"\b[A-Za-z_][A-Za-z0-9_]*\b")
LABEL_DEF = re.compile(r"^([A-Za-z_][A-Za-z0-9_]*)::?", re.M)
JUMPS = ("goto", "call", "applymovement", "trainerbattle", "msgbox")


def read(path):
    with open(path, encoding="utf-8", errors="replace") as f:
        return f.read()


def strip_c_comments(text):
    text = re.sub(r"/\*.*?\*/", " ", text, flags=re.S)
    return re.sub(r"//[^\n]*", "", text)


def code_lines(text):
    """Script lines without comments; .string lines are text, never names."""
    out = []
    for line in text.split("\n"):
        if re.match(r"\s*\.string\b", line):
            continue
        line = re.split(r"@|//", line)[0].rstrip()
        if line.strip():
            out.append(line)
    return out


def norm(line):
    return re.sub(r"\s+", " ", line.strip())


class Tree:
    """One source tree's meaning for every name a map script can use."""

    def __init__(self, root):
        self.root = root
        self._c = None
        self._labels = None

    def path(self, *parts):
        return os.path.join(self.root, *parts)

    def files(self, pattern):
        return sorted(glob.glob(self.path(pattern), recursive=True))

    # --- C functions ------------------------------------------------------------------------
    def c_functions(self):
        """name -> body for every top-level function in src/**/*.c."""
        if self._c is None:
            self._c = {}
            head = re.compile(r"^[A-Za-z_][\w \t\*]*?\b([A-Za-z_]\w*)\s*\([^;{)]*\)\s*\{", re.M)
            for path in self.files("src/**/*.c"):
                text = strip_c_comments(read(path))
                for m in head.finditer(text):
                    depth, i = 1, m.end()
                    while depth and i < len(text):
                        depth += {"{": 1, "}": -1}.get(text[i], 0)
                        i += 1
                    self._c.setdefault(m.group(1), text[m.end():i])
        return self._c

    def fp_special(self, name):
        """The special vars the function and its direct callees touch: a newer expansion reads
        VAR_0x8004 through GetSelectedBoxMonFromPcOrParty, not in the special's own body."""
        funcs = self.c_functions()
        if name not in funcs:
            return None
        used, seen, todo = set(), set(), [(name, 0)]
        while todo:
            fn, depth = todo.pop()
            if fn in seen or fn not in funcs:
                continue
            seen.add(fn)
            body = funcs[fn]
            used |= set(re.findall(r"gSpecialVar_(0x800[0-9A-Fa-f]|Result)\b", body))
            used |= set(re.findall(r"\bVAR_(0x800[0-9A-Fa-f]|RESULT)\b", body))
            if depth < 2:
                todo += [(c, depth + 1) for c in set(re.findall(r"\b([A-Z]\w+)\s*\(", body))]
        return " ".join(sorted(u.replace("RESULT", "Result") for u in used))

    def fp_ctype(self, name):
        users = sorted(f for f, body in self.c_functions().items() if re.search(r"\b%s\b" % name, body))
        return " ".join(users) if users else None

    # --- data tables ------------------------------------------------------------------------
    def designated(self, path, prefix):
        """[PREFIX_X] = { ... } blocks of one C table file -> name -> block text."""
        out = {}
        if not os.path.exists(path):
            return out
        text = strip_c_comments(read(path))
        for m in re.finditer(r"\[(%s\w+)\]\s*=\s*\{" % prefix, text):
            depth, i = 1, m.end()
            while depth and i < len(text):
                depth += {"{": 1, "}": -1}.get(text[i], 0)
                i += 1
            out.setdefault(m.group(1), text[m.end():i])
        return out

    def trades(self):
        out = {}
        for name, block in self.designated(self.path("src/data/trade.h"), "INGAME_TRADE_").items():
            f = dict(re.findall(r"\.(\w+)\s*=\s*([^,\n]+)", block))
            out[name] = " ".join(f.get(k, "?").strip() for k in ("species", "requestedSpecies"))
        return out

    def items(self):
        out = {}
        for name, block in self.designated(self.path("src/data/items.h"), "ITEM_").items():
            m = re.search(r"\.name\s*=\s*(?:ITEM_NAME|_)\(\"([^\"]*)\"", block)
            spelled = re.sub(r"[^A-Z0-9]", "", m.group(1).upper().replace("É", "E")) if m else ""
            if spelled:
                out[name] = spelled
        return out

    def trainers(self):
        """TRAINER_X -> its name and the species it sends out. The class is left out: the port
        moved Kimono Girls and Rocket admins to classes this tree has, a cosmetic change."""
        out = {}
        for path in self.files("src/data/trainers*.party"):
            for m in re.finditer(r"^=== (TRAINER_\w+) ===\n(.*?)(?=^===|\Z)", read(path), re.M | re.S):
                head, _, mons = m.group(2).partition("\n\n")
                name = re.search(r"^Name:\s*(.*)$", head, re.M)
                species = [re.sub(r"^SPECIES_", "", re.split(r"\s@|\s\(", chunk.strip().split("\n")[0])[0].strip()).upper()
                           for chunk in re.split(r"\n\s*\n", mons) if chunk.strip()]
                out.setdefault(m.group(1), (name.group(1) if name else "", species))
        parties = {}
        path = self.path("src/data/trainer_parties.h")
        if os.path.exists(path):
            for m in re.finditer(r"(sParty_\w+)\[\]\s*=\s*\{(.*?)\};", strip_c_comments(read(path)), re.S):
                parties[m.group(1)] = re.findall(r"\.species\s*=\s*SPECIES_(\w+)", m.group(2))
        for name, block in self.designated(self.path("src/data/trainers.h"), "TRAINER_").items():
            nm = re.search(r"\.trainerName\s*=\s*_\(\"([^\"]*)\"", block)
            party = re.search(r"\.party\s*=\s*[^;]*?(sParty_\w+)", block)
            out.setdefault(name, (nm.group(1) if nm else "", parties.get(party.group(1), []) if party else []))
        return {k: "%s: %s" % (n.upper(), " ".join(sorted(set(sp)))) for k, (n, sp) in out.items()}

    def strings(self):
        """gText_X -> its text, from src/strings.c."""
        out = {}
        for path in self.files("src/strings.c"):
            for k, v in re.findall(r"\b(gText_\w+)\[\]\s*=\s*_\(\"((?:[^\"\\\\]|\\\\.)*)\"", read(path)):
                out[k] = v
        return out

    def multichoices(self):
        path = self.path("src/data/script_menu.h")
        if not os.path.exists(path):
            return {}
        text = strip_c_comments(read(path))
        strings = self.strings()

        def option(entry):
            m = re.search(r"COMPOUND_STRING\(\"([^\"]*)\"", entry)
            if m:
                return m.group(1)
            m = re.search(r"(gText_\w+)", entry)
            return strings.get(m.group(1), m.group(1)) if m else entry.strip()

        lists = {}
        for m in re.finditer(r"(\w+)\[\]\s*=\s*\{(.*?)\};", text, re.S):
            lists[m.group(1)] = " | ".join(option(e) for e in re.findall(r"\{([^{}]*)\}", m.group(2)))
        return {name: lists.get(lst, "?" + lst)
                for name, lst in re.findall(r"\[(MULTI_\w+)\]\s*=\s*MULTICHOICE\((\w+)\)", text)}

    def maps(self, translate):
        out = {}
        for path in self.files("data/maps/*/map.json"):
            name = os.path.basename(os.path.dirname(path))
            mid = re.search(r'"id"\s*:\s*"(MAP_\w+)"', read(path))
            if mid:
                out[mid.group(1)] = re.sub(r"_Frlg$", "", translate.get(name, name))
        return out

    # --- assembly ---------------------------------------------------------------------------
    def macros(self):
        """Macro -> the shape of what it emits: parameter count, then each line's directive with
        the opcode byte dropped. Opcode numbers and parameter names differ between expansion
        versions without changing meaning; a callnative stand-in or a new field does not."""
        out = {}
        for path in self.files("asm/macros/**/*.inc"):
            if re.search(r"battle_(script|anim|ai)", path):
                continue  # battle scripts reuse command names (waitfanfare) with other meanings
            for m in re.finditer(r"^\s*\.macro\s+(\w+)([^\n]*)\n(.*?)^\s*\.endm", read(path), re.M | re.S):
                params = [p for p in re.split(r"[,\s]+", re.split(r"@", m.group(2))[0].strip()) if p]
                body = [norm(l).split(" ")[0] for l in code_lines(m.group(3))]
                if body[:1] == [".byte"]:
                    body = body[1:]
                out.setdefault(m.group(1), "%d :: %s" % (len(params), " ".join(body)))
        return out

    def labels(self):
        """Every label in data/ assembly -> its normalized body up to the next label."""
        if self._labels is None:
            self._labels = {}
            paths = self.files("data/**/*.inc") + self.files("data/*.s")
            for path in paths:
                lines = code_lines(read(path))
                cur, body = None, []
                for line in lines + ["__END__::"]:
                    m = LABEL_DEF.match(line)
                    if m:
                        if cur:
                            self._labels.setdefault(cur, " ; ".join(body))
                        cur, body = m.group(1), []
                    elif cur:
                        body.append(norm(line))
        return self._labels


def defines(tree):
    """#define A B aliases from include/constants: what a script name resolves to."""
    out = {}
    for path in tree.files("include/constants/*.h"):
        text = read(path)
        for a, b in re.findall(r"^#define\s+([A-Za-z_]\w*)\s+([A-Za-z_]\w*)\s*(?://.*)?$", text, re.M):
            out[a] = b
        for a, b in re.findall(r"^\s+([A-Z_][A-Z0-9_]*)\s*=\s*([A-Z_][A-Z0-9_]*)\s*,", text, re.M):
            out.setdefault(a, b)
    return out


def canonical(name, aliases):
    seen = set()
    while name in aliases and name not in seen:
        seen.add(name)
        name = aliases[name]
    return name


def lookup(name, aliases, table):
    """The table key naming the same thing as name: ITEM_HM_WHIRLPOOL -> ITEM_HM08 <- ITEM_HM_DIVE."""
    if name in table:
        return name
    target = canonical(name, aliases)
    for key in table:
        if canonical(key, aliases) == target:
            return key
    return target


def subsequence(short, long):
    it = iter(long)
    return all(c in it for c in short)


def words(option):
    """FLOOR 5 and 5F share 5; LOVE / PECHA and LOVE BALL share LOVE; SUNDAY and MONDAY share nothing."""
    return set(re.findall(r"[A-Z]+|[0-9]+", re.sub(r"\{[^}]*\}", " ", option.upper())))


def same(kind, theirs, ours):
    if theirs == ours:
        return True
    if theirs is None or ours is None:
        return False
    if kind == "item":
        a, b = sorted((theirs, ours), key=len)
        return subsequence(a, b)
    if kind == "multi":
        a, b = theirs.split(" | "), ours.split(" | ")
        return len(a) == len(b) and all(words(x) & words(y) for x, y in zip(a, b))
    if kind == "trainer":
        (n1, _, s1), (n2, _, s2) = theirs.partition(": "), ours.partition(": ")
        return n1 == n2 and bool(set(s1.split()) & set(s2.split()))
    return False


def script_names(text, own_labels):
    """kind -> set of names one map script uses."""
    found = {k: set() for k in KINDS}
    for line in code_lines(text):
        if LABEL_DEF.match(line):
            continue
        toks = IDENT.findall(line)
        if not toks:
            continue
        cmd, args = toks[0], toks[1:]
        if cmd in ("special", "callnative") and args:
            found["special"].add(args[0])
        elif cmd == "specialvar" and len(args) > 1:
            found["special"].add(args[1])
        elif not line.startswith((" ", "\t")):
            pass
        else:
            found["macro"].add(cmd)
        for t in args:
            for kind, prefix in PREFIX_KINDS:
                if t.startswith(prefix):
                    found[kind].add(t)
            if (re.search(r"[a-z]", t) and t not in own_labels and "_Text_" not in t
                    and not t.startswith("gText") and cmd.startswith(JUMPS)):
                found["label"].add(t)
    return found


PREFIX_KINDS = [("trade", "INGAME_TRADE_"), ("ctype", "EASY_CHAT_TYPE_"), ("multi", "MULTI_"),
                ("trainer", "TRAINER_"), ("item", "ITEM_"), ("map", "MAP_")]
KINDS = ["trade", "special", "ctype", "multi", "trainer", "item", "map", "macro", "label"]


def fingerprints(tree, translate, wanted):
    """kind -> name -> fingerprint, for the names in wanted only."""
    aliases = defines(tree)
    tables = {
        "trade": tree.trades(), "multi": tree.multichoices(), "trainer": tree.trainers(),
        "item": tree.items(), "map": tree.maps(translate), "macro": tree.macros(),
        "label": tree.labels(),
    }
    out = {k: {} for k in KINDS}
    for kind in KINDS:
        for name in sorted(wanted[kind]):
            if kind == "special":
                fp = tree.fp_special(lookup(name, aliases, tree.c_functions()))
            elif kind == "ctype":
                fp = tree.fp_ctype(lookup(name, aliases, {}))
            else:
                fp = tables[kind].get(lookup(name, aliases, tables[kind]))
            out[kind][name] = fp
    return out


def map_scripts(root, names):
    out = {}
    for name in names:
        path = os.path.join(root, "data/maps", name, "scripts.inc")
        if os.path.exists(path):
            text = read(path)
            out[name] = script_names(text, set(LABEL_DEF.findall(text)))
    return out


def johto_maps():
    sys.path.insert(0, HERE)
    import ValidateRegionText
    return sorted(m["name"] for m in ValidateRegionText.johto_maps())


def snapshot(hns_root):
    for need in ("data/maps", "data/scripts", "data/event_scripts.s", "asm/macros", "include/constants", "src/data"):
        if not os.path.exists(os.path.join(hns_root, need)):
            sys.exit(f"{hns_root} has no {need}; widen the sparse checkout before taking a snapshot")
    ours = johto_maps()
    hns_names = {m: HNS_MAP_FROM_OURS.get(m, m) for m in ours}
    used = map_scripts(hns_root, hns_names.values())
    wanted = {k: set() for k in KINDS}
    for found in used.values():
        for k in KINDS:
            wanted[k] |= found[k]
    fps = fingerprints(Tree(hns_root), OUR_MAP_FROM_HNS, wanted)
    data = {
        "maps": {ourname: {k: sorted(used[h][k]) for k in KINDS if used[h][k]}
                 for ourname, h in hns_names.items() if h in used},
        "fingerprints": {k: {n: v for n, v in fps[k].items()} for k in KINDS},
    }
    with open(SNAPSHOT, "w") as f:
        json.dump(data, f, indent=1, sort_keys=True)
        f.write("\n")
    print(f"wrote {os.path.relpath(SNAPSHOT, ROOT)}: {len(data['maps'])} maps, "
          f"{sum(len(v) for v in fps.values())} names")


def load_baseline():
    out = {}
    if os.path.exists(BASELINE):
        for line in read(BASELINE).splitlines():
            if line.strip() and not line.startswith("#"):
                kind, name, why = line.split("\t", 2)
                out[(kind, name)] = why
    return out


def audit(report):
    snap = json.loads(read(SNAPSHOT))
    ours_used = map_scripts(ROOT, snap["maps"].keys())
    wanted = {k: set() for k in KINDS}
    shared = {}
    for m, hns_found in snap["maps"].items():
        for k, names in hns_found.items():
            for n in set(names) & ours_used.get(m, {}).get(k, set()):
                wanted[k].add(n)
                shared.setdefault((k, n), []).append(m)
    mine = fingerprints(Tree(ROOT), {}, wanted)
    baseline = load_baseline()
    rows = []
    for (k, n), where in sorted(shared.items()):
        theirs, ours = snap["fingerprints"][k].get(n), mine[k].get(n)
        if theirs is None or same(k, theirs, ours):
            continue
        why = next((w for (bk, bn), w in baseline.items() if bk == k and fnmatch.fnmatchcase(n, bn)), None)
        rows.append((k, n, theirs, ours, sorted(set(where)), why))
    unexplained = [r for r in rows if r[5] is None]
    stale = sorted((bk, bn) for bk, bn in baseline
                   if not any(r[0] == bk and fnmatch.fnmatchcase(r[1], bn) for r in rows))
    for k, n, theirs, ours, where, why in (rows if report else unexplained):
        print(f"{'BASELINE' if why else 'DIFFERS'} {k} {n}  ({', '.join(where[:4])}{' ...' if len(where) > 4 else ''})")
        print(f"    HnS:  {theirs}")
        print(f"    here: {ours}")
        if why:
            print(f"    why:  {why}")
    for k, n in stale:
        print(f"STALE baseline row {k} {n}: nothing differs any more; delete the row")
    total = sum(len(v) for v in wanted.values())
    if total < 500:
        print(f"FAIL: only {total} shared names found; the script parse is broken")
        return 1
    if report:
        print(f"{len(rows)} difference(s) in {total} shared names, {len(unexplained)} unexplained")
        return 0
    if unexplained:
        print(f"FAIL: {len(unexplained)} name(s) in ported Johto scripts mean something else here than in "
              f"HnS; fix the script or explain the row in {os.path.relpath(BASELINE, ROOT)}")
        return 1
    print(f"OK: {total} names shared with the HnS originals, {len(rows)} known difference(s) explained")
    return 0


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--snapshot", metavar="HNS")
    ap.add_argument("--report", action="store_true")
    a = ap.parse_args()
    if a.snapshot:
        snapshot(a.snapshot)
        return 0
    return audit(a.report)


if __name__ == "__main__":
    sys.exit(main())
