#!/usr/bin/env python3
"""Find names in ported map scripts that mean something else here than in the game they came from.

The Johto map scripts were ported from pokemonHnS, and the Kanto and Sevii Islands map scripts
(the *_Frlg maps) from pokefirered, text for text. A constant, special or shared script they name
resolves against THIS tree, so a name both trees define but define differently assembles cleanly
and does the Emerald thing. Found so far: INGAME_TRADE_MR_MIME (HnS: Emy's Dodrio trade; here:
FRLG's Route 2 Abra trade), EASY_CHAT_TYPE_INTERVIEW (HnS checked the Odd Egg answer in its own
easy_chat.c), relearner specials reading VAR_0x8004 (#638), MUS_FOLLOW_ME (FRLG's guide theme;
here: Emerald's).

For every map whose scripts were ported, each name that BOTH its script and the original use is
fingerprinted in both trees by what the name means:

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

pokefirered (--source frlg) also fingerprints:

    std        MSGBOX_* / STD_*     the std script the number selects, and its body
    song       MUS_* / SE_*         the midi the song table plays for it (an FRLG song kept
                                    here under MUS_RG_* leaves the plain name on Emerald's)
    fanfare    playfanfare songs    the fanfare table's frame count (a missing row plays as
                                    a BGM and never ends the wait)
    fldeff     FLDEFF_*             the C functions its field effect script calls

and spells FRLG's MULTICHOICE_* ids as this tree's MULTI_*. Every source also pairs each menu by
where it sits (the label and its nth multichoice), so a port that shows a differently named
list there is compared row by row too.

A fingerprint that differs is reported unless the source's baseline explains it.

    AuditHnsPortSymbols.py [--source hns|frlg]
                                         check against the committed snapshot (no checkout needed)
    AuditHnsPortSymbols.py --report      list every difference, explained or not, exit 0
    AuditHnsPortSymbols.py --snapshot DIR [--source hns|frlg]
                                         refresh the snapshot from a source checkout with data,
                                         asm, include and src (and sound for frlg)

HnS is a sparse clone (see hns-upstream-is-the-oracle); pokefirered is pret/pokefirered.
"""
import argparse
import collections
import fnmatch
import glob
import hashlib
import json
import os
import re
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))

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
    def designated(self, path, prefix, defines=()):
        """[PREFIX_X] = { ... } blocks of one C table file -> name -> block text."""
        out = {}
        if not os.path.exists(path):
            return out
        if defines:
            # The original Kanto table contains both editions in one initializer.
            # Expand the selected branch before collecting fields with the same name.
            text = subprocess.check_output(["cc", "-E", "-P", "-x", "c", *defines, path], text=True)
        else:
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
        table = next((p for p in (self.path("src/data/trade.h"), self.path("src/data/ingame_trades.h"))
                      if os.path.exists(p)), "")
        defines = ("-DFIRERED",) if os.path.basename(table) == "ingame_trades.h" else ()
        for name, block in self.designated(table, "INGAME_TRADE_", defines).items():
            f = dict(re.findall(r"\.(\w+)\s*=\s*([^,\n]+)", block))
            out[name] = " ".join(f.get(k, "?").strip() for k in ("species", "requestedSpecies"))
        return out

    def items(self):
        """ITEM_X -> its spelled name; a TM or HM also names its move, since the number alone
        (TM28) would not show a tree that teaches another move under it."""
        def spell(name):
            return re.sub(r"[^A-Z0-9]", "", name.upper().replace("É", "E"))

        out = {}
        for name, block in self.designated(self.path("src/data/items.h"), "ITEM_").items():
            m = re.search(r"\.name\s*=\s*(?:ITEM_NAME|_)\(\"([^\"]*)\"", block)
            if m and spell(m.group(1)):
                out[name] = spell(m.group(1))
        path = self.path("src/data/items.json")
        if not out and os.path.exists(path):
            for it in json.loads(read(path))["items"]:
                if spell(it["english"]):
                    out[it["itemId"]] = spell(it["english"])
        for kind, moves in self.tmhm_moves().items():
            for n, move in enumerate(moves, 1):
                keys = ("ITEM_%s_%s" % (kind, move), "ITEM_%s%02d" % (kind, n))
                spelled = next((out[k] for k in keys if k in out), None)
                if spelled:
                    out.update((k, "%s %s" % (spelled, move)) for k in keys)
        return out

    def tmhm_moves(self):
        """TM / HM -> moves in number order: the expansion's FOREACH_TM list, else pokefirered's
        sTMHMMoves table (TMs, then the eight HMs)."""
        path = self.path("include/constants/tms_hms.h")
        if os.path.exists(path):
            text = read(path)
            return {kind: re.findall(r"F\((\w+)\)", re.search(r"#define FOREACH_%s\(F\)(.*?)\n\n" % kind,
                                                              text, re.S).group(1))
                    for kind in ("TM", "HM")}
        path = self.path("src/data/party_menu.h")
        m = re.search(r"sTMHMMoves\[\]\s*=\s*\{(.*?)\};", read(path), re.S) if os.path.exists(path) else None
        if not m:
            return {}
        moves = re.findall(r"MOVE_(\w+)", m.group(1))
        return {"TM": moves[:-8], "HM": moves[-8:]}

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
        return {k: "%s: %s" % (n.upper(), " ".join(sorted({re.sub(r"[^A-Z0-9]", "", x) for x in sp})))
                for k, (n, sp) in out.items()}

    def strings(self):
        """gText_X / gOtherText_X -> its text, from src/strings.c."""
        out = {}
        for path in self.files("src/strings.c"):
            for k, v in re.findall(r"\b(g\w*Text_\w+)\[\]\s*=\s*_\(\"((?:[^\"\\\\]|\\\\.)*)\"", read(path)):
                out[k] = v
        return out

    def multichoices(self):
        path = next((p for p in (self.path("src/data/script_menu.h"), self.path("src/script_menu.c"))
                     if os.path.exists(p)), None)
        if not path:
            return {}
        text = strip_c_comments(read(path))
        strings = self.strings()
        strings.update(re.findall(r"\b(\w+)\[\]\s*=\s*_\(\"((?:[^\"\\\\]|\\\\.)*)\"", text))

        def option(entry):
            m = re.search(r"COMPOUND_STRING\(\"([^\"]*)\"", entry)
            if m:
                return m.group(1)
            m = re.search(r"\b([gs]\w*Text_\w+)", entry)
            return strings.get(m.group(1), m.group(1)) if m else entry.strip()

        lists = {}
        entry = re.compile(r'\{((?:"(?:[^"\\\\]|\\\\.)*"|[^{}"])*)\}')
        for m in re.finditer(r"(\w+)\[\]\s*=\s*\{(.*?)\};", text, re.S):
            lists[m.group(1)] = " | ".join(option(e) for e in entry.findall(m.group(2)))
        return {name: lists.get(lst, "?" + lst)
                for name, lst in re.findall(r"\[(MULTI(?:CHOICE)?_\w+)\]\s*=\s*MULTICHOICE\((\w+)\)", text)}

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
            if re.search(r"battle_(script|anim|ai)|contest_ai", path):
                continue  # battle and contest AI scripts reuse command names (setvar) with other meanings
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
                    elif cur and not re.match(r"\s*\.include\b", line):
                        body.append(norm(line))
        return self._labels

    def pointer_table(self, path, table):
        """The labels a .4byte table lists, in index order."""
        text = read(self.path(path))
        m = re.search(r"^%s::?\n(.*?)^\S" % table, text, re.M | re.S)
        return re.findall(r"^\s*\.4byte\s+(\w+)", m.group(1), re.M) if m else []

    def stds(self):
        """MSGBOX_X / STD_X -> the std script gStdScripts runs for its number, with its body."""
        values = {}
        for path in self.files("asm/macros/event.inc"):
            values.update((k, int(v)) for k, v in re.findall(r"^\s*((?:MSGBOX|STD)_\w+)\s*=\s*(\d+)", read(path), re.M))
        table = self.pointer_table("data/event_scripts.s", "gStdScripts")
        return {k: "%s :: %s" % (table[v], re.sub(r"\b0x0\b", "NULL", self.labels().get(table[v], "?")))
                for k, v in values.items() if v < len(table)}

    def numbered(self, header, prefix):
        return {k: int(v) for k, v in re.findall(r"^#define\s+(%s\w+)\s+(\d+)" % prefix,
                                                 read(self.path(header)), re.M)}

    def songs(self):
        """MUS_X / SE_X -> the song table's symbol for its number and its midi's md5; two trees
        play the same song when the md5s match."""
        table = re.findall(r"^\s*song\s+(\w+)", read(self.path("sound/song_table.inc")), re.M)
        out = {}
        for name, num in self.numbered("include/constants/songs.h", r"(?:MUS|SE)_").items():
            if num < len(table):
                midi = self.path("sound/songs/midi", table[num] + ".mid")
                out[name] = ("%s %s" % (table[num], hashlib.md5(open(midi, "rb").read()).hexdigest()[:12])
                             if os.path.exists(midi) else table[num])
        return out

    def fanfares(self):
        """Song name -> the frame count sFanfares gives it; a song missing from the table has none."""
        m = re.search(r"sFanfares\[\]\s*=\s*\{(.*?)\};", strip_c_comments(read(self.path("src/sound.c"))), re.S)
        return {k: v for k, v in re.findall(r"\{\s*(MUS_\w+)\s*,\s*(\d+)\s*\}", m.group(1))} if m else {}

    def fldeffs(self):
        """FLDEFF_X -> the C functions its field effect script calls."""
        table = self.pointer_table("data/field_effect_scripts.s", "gFieldEffectScriptPointers")
        out = {}
        for name, num in self.numbered("include/constants/field_effects.h", "FLDEFF_").items():
            if num < len(table):
                body = self.labels().get(table[num], "")
                out[name] = " ".join(re.findall(r"callnative (\w+)", body)) or body
        return out


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
    if kind == "song":
        return theirs.split(" ")[-1] == ours.split(" ")[-1]
    if kind == "trainer":
        (n1, _, s1), (n2, _, s2) = theirs.partition(": "), ours.partition(": ")
        return n1 == n2 and bool(set(s1.split()) & set(s2.split()))
    return False


def script_names(text, own_labels):
    """kind -> set of names one map script uses, and "menus": label#n -> the multichoice list
    the label's nth menu shows, so a port that swapped in a differently named list still pairs."""
    found = {k: set() for k in KINDS}
    found["menus"] = {}
    label, menus_in = None, collections.Counter()
    for line in code_lines(text):
        m = LABEL_DEF.match(line)
        if m:
            label = m.group(1)
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
        if cmd == "playfanfare" and args:
            found["fanfare"].add(args[0])
        menu = next((t for t in args if t.startswith(("MULTI_", "MULTICHOICE_"))), None)
        if cmd.startswith("multichoice") and menu and label:
            found["menus"]["%s#%d" % (label, menus_in[label])] = menu
            menus_in[label] += 1
        for t in args:
            for kind, prefix in PREFIX_KINDS:
                if t.startswith(prefix):
                    found[kind].add(t)
            if (re.search(r"[a-z]", t) and t not in own_labels and "_Text_" not in t
                    and not t.startswith("gText") and cmd.startswith(JUMPS)):
                found["label"].add(t)
    return found


PREFIX_KINDS = [("trade", "INGAME_TRADE_"), ("ctype", "EASY_CHAT_TYPE_"), ("multi", "MULTI_"),
                ("multi", "MULTICHOICE_"), ("trainer", "TRAINER_"), ("item", "ITEM_"), ("map", "MAP_"),
                ("std", "MSGBOX_"), ("std", "STD_"), ("song", "MUS_"), ("song", "SE_"), ("fldeff", "FLDEFF_")]
KINDS = ["trade", "special", "ctype", "multi", "trainer", "item", "map", "macro", "label",
         "std", "song", "fanfare", "fldeff"]


def fingerprints(tree, translate, wanted):
    """kind -> name -> fingerprint, for the names in wanted only."""
    aliases = defines(tree)
    tables = {
        "trade": tree.trades, "multi": tree.multichoices, "trainer": tree.trainers,
        "item": tree.items, "map": lambda: tree.maps(translate), "macro": tree.macros,
        "label": tree.labels, "std": tree.stds, "song": tree.songs, "fanfare": tree.fanfares,
        "fldeff": tree.fldeffs,
    }
    out = {k: {} for k in KINDS}
    for kind in KINDS:
        table = tables[kind]() if wanted[kind] and kind in tables else {}
        for name in sorted(wanted[kind]):
            if kind == "special":
                fp = tree.fp_special(lookup(name, aliases, tree.c_functions()))
            elif kind == "ctype":
                fp = tree.fp_ctype(lookup(name, aliases, {}))
            else:
                fp = table.get(lookup(name, aliases, table))
            out[kind][name] = fp
    return out


def map_scripts(root, names):
    """name -> kind -> names its script uses. A name with a slash is a shared script file."""
    out = {}
    for name in names:
        path = os.path.join(root, name if "/" in name else os.path.join("data/maps", name, "scripts.inc"))
        if os.path.exists(path):
            text = read(path)
            out[name] = script_names(text, set(LABEL_DEF.findall(text)))
    return out


def johto_maps():
    sys.path.insert(0, HERE)
    import ValidateRegionText
    return sorted(m["name"] for m in ValidateRegionText.johto_maps())


def hns_pairs(root):
    return {m: HNS_MAP_FROM_OURS.get(m, m) for m in johto_maps()}


def frlg_pairs(root):
    """Each *_Frlg map with its pokefirered map, and each pokefirered shared script file with the
    file here that holds the port (its _frlg copy, else the file of the same name)."""
    pairs = {os.path.basename(os.path.dirname(p)): os.path.basename(os.path.dirname(p))[:-len("_Frlg")]
             for p in glob.glob(os.path.join(ROOT, "data/maps/*_Frlg/map.json"))}
    pairs["data/event_scripts.s"] = "data/event_scripts.s"
    for path in glob.glob(os.path.join(root, "data/scripts/*.inc")):
        name = os.path.basename(path)
        for ours in (name[:-4] + "_frlg.inc", name):
            if os.path.exists(os.path.join(ROOT, "data/scripts", ours)):
                pairs["data/scripts/" + ours] = "data/scripts/" + name
                break
    return pairs


def frlg_name(name):
    """The port's spelling of an FRLG name: MULTICHOICE_X is MULTI_X here."""
    if name == "SCR_MENU_CANCEL":
        return "MULTI_B_PRESSED"
    if name.startswith("MULTICHOICE_"):
        return "MULTI_" + name[len("MULTICHOICE_"):]
    return name


Source = collections.namedtuple("Source", "title snapshot baseline pairs map_names rename kinds needs")
BASE_KINDS = ["trade", "special", "ctype", "multi", "trainer", "item", "map", "macro", "label"]
NEEDS = ("data/maps", "data/scripts", "data/event_scripts.s", "asm/macros", "include/constants", "src/data")
SOURCES = {
    "hns": Source("HnS", "HnsPortSymbols.json", "HnsPortSymbols_baseline.tsv", hns_pairs, OUR_MAP_FROM_HNS,
                  lambda n: n, BASE_KINDS, NEEDS),
    "frlg": Source("FRLG", "FrlgPortSymbols.json", "FrlgPortSymbols_baseline.tsv", frlg_pairs, {},
                   frlg_name, KINDS,
                   NEEDS + ("sound/song_table.inc", "sound/songs/midi", "data/field_effect_scripts.s",
                            "src/script_menu.c", "src/sound.c")),
}


def snapshot(src, root):
    """The source's side of every map: the names its script uses (in this tree's vocabulary) and
    what each one means there. Keys of "maps" are this tree's map names."""
    for need in src.needs:
        if not os.path.exists(os.path.join(root, need)):
            sys.exit(f"{root} has no {need}; widen the sparse checkout before taking a snapshot")
    pairs = src.pairs(root)
    used = map_scripts(root, pairs.values())
    wanted = {k: set() for k in KINDS}
    original = {}
    for found in used.values():
        for k in src.kinds:
            for n in found[k]:
                wanted[k].add(n)
                original[(k, src.rename(n))] = n
    fps = fingerprints(Tree(root), src.map_names, wanted)
    for n, body in fps["label"].items():
        if body:
            fps["label"][n] = IDENT.sub(lambda m: src.rename(m.group(0)), body)
    data = {
        "maps": {ours: dict({k: sorted({src.rename(n) for n in used[h][k]}) for k in src.kinds if used[h][k]},
                            **({"menus": {slot: src.rename(n) for slot, n in used[h]["menus"].items()}}
                               if used[h]["menus"] else {}))
                 for ours, h in pairs.items() if h in used},
        "fingerprints": {k: {n: fps[k][o] for (kk, n), o in original.items() if kk == k} for k in src.kinds},
    }
    path = os.path.join(HERE, src.snapshot)
    with open(path, "w") as f:
        json.dump(data, f, indent=1, sort_keys=True)
        f.write("\n")
    print(f"wrote {os.path.relpath(path, ROOT)}: {len(data['maps'])} maps, "
          f"{sum(len(v) for v in fps.values())} names")


def load_baseline(src):
    out = {}
    path = os.path.join(HERE, src.baseline)
    if os.path.exists(path):
        for line in read(path).splitlines():
            if line.strip() and not line.startswith("#"):
                kind, name, why = line.split("\t", 2)
                out[(kind, name)] = why
    return out


def audit(src, report):
    snap = json.loads(read(os.path.join(HERE, src.snapshot)))
    ours_used = map_scripts(ROOT, snap["maps"].keys())
    wanted = {k: set() for k in KINDS}
    shared = {}
    menus = {}
    for m, their_found in snap["maps"].items():
        for k, names in their_found.items():
            if k == "menus":
                continue
            for n in set(names) & ours_used.get(m, {}).get(k, set()):
                wanted[k].add(n)
                shared.setdefault((k, n), []).append(m)
        for slot, theirs in their_found.get("menus", {}).items():
            ours = ours_used.get(m, {}).get("menus", {}).get(slot)
            if ours and ours != theirs:
                wanted["multi"].add(ours)
                menus.setdefault((ours, theirs), []).append(m)
    mine = fingerprints(Tree(ROOT), {}, wanted)
    baseline = load_baseline(src)
    compared = [(k, n, snap["fingerprints"][k].get(n), mine[k].get(n), where, "")
                for (k, n), where in sorted(shared.items())]
    compared += [("multi", ours, snap["fingerprints"]["multi"].get(theirs), mine["multi"].get(ours), where,
                  "(their %s) " % theirs) for (ours, theirs), where in sorted(menus.items())]
    rows = []
    for k, n, theirs, ours, where, their_name in compared:
        if theirs is None or same(k, theirs, ours):
            continue
        theirs = their_name + theirs
        why = next((w for (bk, bn), w in baseline.items() if bk == k and fnmatch.fnmatchcase(n, bn)), None)
        rows.append((k, n, theirs, ours, sorted(set(where)), why))
    unexplained = [r for r in rows if r[5] is None]
    stale = sorted((bk, bn) for bk, bn in baseline
                   if not any(r[0] == bk and fnmatch.fnmatchcase(r[1], bn) for r in rows))
    for k, n, theirs, ours, where, why in (rows if report else unexplained):
        print(f"{'BASELINE' if why else 'DIFFERS'} {k} {n}  ({', '.join(where[:4])}{' ...' if len(where) > 4 else ''})")
        print(f"    {src.title + ':':5} {theirs}")
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
        print(f"FAIL: {len(unexplained)} name(s) in ported scripts mean something else here than in "
              f"{src.title}; fix the script or explain the row in {src.baseline}")
        return 1
    print(f"OK: {total} names shared with the {src.title} originals, {len(rows)} known difference(s) explained")
    return 0


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--source", choices=sorted(SOURCES), default="hns")
    ap.add_argument("--snapshot", metavar="DIR")
    ap.add_argument("--report", action="store_true")
    a = ap.parse_args()
    src = SOURCES[a.source]
    if a.snapshot:
        snapshot(src, a.snapshot)
        return 0
    return audit(src, a.report)


if __name__ == "__main__":
    sys.exit(main())
