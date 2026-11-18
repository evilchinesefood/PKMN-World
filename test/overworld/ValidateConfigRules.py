#!/usr/bin/env python3
"""Scripts and text must follow this build's rules, not the source game's.

Kanto's scripts come from FireRed, Hoenn's from Emerald and Johto's from HeartGold/SoulSilver
through pokemonHnS. Each assumes its own game's rules, and `include/config/*.h` changed many of
them. The build stays green while an NPC states the old rule or a script still acts on it: the
Cinnabar Lab revived a fossil the player had sold (#597), Kanto tutors warned "learned only once"
with the one-time flags compiled out (#606), and gym leaders called reusable TMs single-use (#607).
One rule is an owner call rather than a toggle: every move tutor teaches again.

Each rule below names the config toggle, what this build does, what the source game did, and the
script or text shape that assumes the source game. A rule runs only while its toggle still
diverges, so flipping a toggle back retires its check. Rules read the config headers, the items
and species tables, the obedience code and every `.string` label in data/.

Run from the repo root: python3 test/overworld/ValidateConfigRules.py [--list]
--list prints the config census the rules key on. Exit status 1 on any finding.
"""
import glob
import os
import re
import sys
from dataclasses import dataclass
from typing import Callable

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
GENS = {f"GEN_{n}": n - 1 for n in range(1, 10)}
GENS.update({"GEN_LATEST": 8, "GEN_COUNT": 9})
STAT = r"(ATTACK|DEFENSE|SPEED|SPECIAL|SP\. ?ATK|SP\. ?DEF)"
MON = r"POK\S?MON"


def read(rel):
    with open(os.path.join(ROOT, rel), encoding="utf-8", errors="replace") as fh:
        return fh.read()


def strip_c_comments(text):
    return re.sub(r"//[^\n]*|/\*.*?\*/", "", text, flags=re.S)


class Config:
    """Every plain `#define NAME VALUE` in include/config, plus the GEN_* scale."""

    def __init__(self):
        self.raw = {}
        for path in sorted(glob.glob(os.path.join(ROOT, "include/config/*.h"))):
            for m in re.finditer(r"^\s*#define\s+(\w+)[ \t]+([^\n]+)", strip_c_comments(open(path).read()), re.M):
                self.raw.setdefault(m.group(1), m.group(2).strip())

    def value(self, name, depth=0):
        if name in GENS:
            return GENS[name]
        if name in ("TRUE", "FALSE"):
            return int(name == "TRUE")
        v = self.raw.get(name)
        if v is None or depth > 8:
            return 0
        if re.fullmatch(r"\(?\s*-?\d+\s*\)?", v):
            return int(v.strip("() "))
        if re.fullmatch(r"\w+", v):
            return self.value(v, depth + 1)
        return 0

    def holds(self, cond):
        """Evaluate a preprocessor condition the way cpp would, with unknown names as 0."""
        expr = cond.replace("&&", " and ").replace("||", " or ")
        expr = re.sub(r"!(?!=)", " not ", expr)
        expr = re.sub(r"defined\s*\(?\s*(\w+)\s*\)?", lambda m: str(int(m.group(1) in self.raw)), expr)
        expr = re.sub(r"\b[A-Za-z_]\w*\b", lambda m: m.group(0) if m.group(0) in ("and", "or", "not")
                      else str(self.value(m.group(0))), expr)
        try:
            return bool(eval(expr, {"__builtins__": {}}))
        except Exception:
            return True


def live_text(text, cfg, kind):
    """Drop the branches of #if (C) or .if (asm) blocks that this config compiles out."""
    if kind == "c":
        open_re, elif_re, else_re, end_re = r"#\s*if(?:def|ndef)?\b(.*)", r"#\s*elif\b(.*)", r"#\s*else\b", r"#\s*endif\b"
    else:
        open_re, elif_re, else_re, end_re = r"\.if\b(.*)", r"\.elseif\b(.*)", r"\.else\b", r"\.endif\b"
    out, stack = [], []
    for line in text.split("\n"):
        s = line.strip()
        m = re.match(open_re, s)
        if m:
            cond = m.group(1)
            if s.startswith("#ifdef"):
                cond = f"defined({cond.strip()})"
            elif s.startswith("#ifndef"):
                cond = f"!defined({cond.strip()})"
            ok = cfg.holds(cond)
            stack.append([ok, ok])
            out.append("")
            continue
        m = re.match(elif_re, s)
        if m and stack:
            ok = not stack[-1][1] and cfg.holds(m.group(1))
            stack[-1] = [ok, stack[-1][1] or ok]
            out.append("")
            continue
        if re.match(else_re, s) and stack:
            stack[-1] = [not stack[-1][1], True]
            out.append("")
            continue
        if re.match(end_re, s) and stack:
            stack.pop()
            out.append("")
            continue
        out.append(line if all(f[0] for f in stack) else "")
    return "\n".join(out)


@dataclass
class Label:
    name: str
    path: str
    body: str      # live script lines of the label
    text: str      # its .string content, joined and flattened
    raw: str       # every line, compiled out or not


class Corpus:
    """Every script and text label in data/, with its live lines and flattened string."""

    def __init__(self, cfg):
        files = (glob.glob(os.path.join(ROOT, "data/maps/*/scripts.inc")) + glob.glob(os.path.join(ROOT, "data/scripts/*.inc"))
                 + glob.glob(os.path.join(ROOT, "data/text/*.inc")) + [os.path.join(ROOT, "data/event_scripts.s")])
        self.labels = {}
        for path in sorted(files):
            raw = open(path, encoding="utf-8", errors="replace").read().split("\n")
            live = live_text("\n".join(raw), cfg, "asm").split("\n")
            starts = [(m.group(1), i) for i, line in enumerate(live) for m in [re.match(r"(\w+)::?", line)] if m]
            for k, (name, start) in enumerate(starts):
                end = starts[k + 1][1] if k + 1 < len(starts) else len(live)
                block = "\n".join(live[start:end])
                strings = re.findall(r'\.string\s+"([^"]*)"', block)
                flat = re.sub(r"\\[nlp]", " ", "".join(strings)).replace("$", "")
                self.labels.setdefault(name, Label(name, os.path.relpath(path, ROOT), block,
                                                   re.sub(r"\s+", " ", flat).strip(), "\n".join(raw[start:end])))
        self.callers = {}
        for lab in self.labels.values():
            code = "\n".join(re.split(r"@|//", ln)[0] for ln in lab.body.split("\n") if ".string" not in ln)
            for word in set(re.findall(r"\b[A-Za-z_]\w*\b", code)):
                if word != lab.name and word in self.labels:
                    self.callers.setdefault(word, []).append(lab.name)

    def texts(self):
        return (lab for lab in self.labels.values() if lab.text)


@dataclass
class Finding:
    rule: str
    where: str
    detail: str


@dataclass
class Rule:
    name: str
    toggle: str
    diverges: Callable[[Config], bool]
    build_rule: str
    source_rule: str
    check: Callable[["Context"], list]


class Context:
    def __init__(self):
        self.cfg = Config()
        self.corpus = Corpus(self.cfg)
        self._items = None
        self._species = None

    @property
    def items(self):
        if self._items is None:
            self._items = parse_items(self.cfg)
        return self._items

    @property
    def species(self):
        if self._species is None:
            self._species = parse_species(self.cfg)
        return self._species


def parse_items(cfg):
    text = live_text(strip_c_comments(read("src/data/items.h")), cfg, "c")
    macros = dict(re.findall(r"#define\s+(\w+)\s+(\w+)\s*$", text, re.M))
    items = {}
    parts = re.split(r"\n\s*\[(ITEM_\w+)\]\s*=", text)
    for k in range(1, len(parts), 2):
        block = parts[k + 1]
        name = re.search(r'\.name\s*=\s*\w*\("([^"]*)"\)', block)
        func = re.search(r"\.fieldUseFunc\s*=\s*(\w+)", block)
        pocket = re.search(r"\.pocket\s*=\s*(\w+)", block)
        importance = re.search(r"\.importance\s*=\s*([^,\n]+)", block)
        f = func.group(1) if func else None
        f = macros.get(f, f)
        items[parts[k]] = {
            "name": name.group(1).upper() if name else parts[k],
            "func": f,
            "key": (pocket and pocket.group(1) == "POCKET_KEY_ITEMS") or bool(importance and importance.group(1).strip() not in ("0", "FALSE")),
        }
    return items


def parse_species(cfg):
    dex = re.findall(r"^\s*(NATIONAL_DEX_\w+)\s*,", read("include/constants/pokedex.h"), re.M)
    order = {n: i for i, n in enumerate(dex)}
    last_gen3 = order["NATIONAL_DEX_DEOXYS"]
    species = {}
    for path in sorted(glob.glob(os.path.join(ROOT, "src/data/pokemon/species_info/gen_*_families.h"))):
        text = live_text(strip_c_comments(open(path).read()), cfg, "c")
        parts = re.split(r"\n\s*\[(SPECIES_\w+)\]\s*=", text)
        for k in range(1, len(parts), 2):
            block = parts[k + 1]
            nat = re.search(r"\.natDexNum\s*=\s*(NATIONAL_DEX_\w+)", block)
            name = re.search(r'\.speciesName\s*=\s*_\("([^"]*)"\)', block)
            evos = []
            m = re.search(r"\.evolutions\s*=\s*EVOLUTION\((.*?)\)\s*,\s*\n", block, re.S)
            if m:
                for e in re.finditer(r"\{(EVO_\w+),\s*([^,]+?),\s*(SPECIES_\w+)\s*(?:,\s*CONDITIONS\((.*?)\)\s*)?\}", m.group(1), re.S):
                    evos.append((e.group(1), e.group(2).strip(), e.group(3), e.group(4) or ""))
            species[parts[k]] = {
                "name": name.group(1).upper() if name else parts[k],
                "gen3": bool(nat) and order.get(nat.group(1), 10**6) <= last_gen3,
                "evos": evos,
            }
    return species


def text_rule(name, patterns, scope=None):
    """Findings for every text label (optionally scoped by a regex on its text) that matches."""
    def check(ctx):
        out = []
        for lab in ctx.corpus.texts():
            if scope and not re.search(scope, lab.text, re.I):
                continue
            for p in patterns:
                m = re.search(p, lab.text, re.I)
                if m:
                    out.append(Finding(name, f"{lab.path}:{lab.name}", f"\"{snippet(lab.text, m)}\""))
                    break
        return out
    return check


def snippet(text, m, pad=50):
    a, b = max(0, m.start() - pad), min(len(text), m.end() + pad)
    return ("…" if a else "") + text[a:b] + ("…" if b < len(text) else "")


# --- script rules ----------------------------------------------------------------------------

def check_sellable_removed_unchecked(ctx):
    """A script that takes an item the player can sell or toss must first ask whether it is held.

    FRLG gated the Cinnabar revival on Mt. Moon's "got it" flags because a Key Item fossil never left
    the bag. Here a fossil is sellable (I_KEY_FOSSILS), so the flag no longer proves the item is
    there and `removeitem` fails silently after the reward is promised.
    """
    callees = {}
    for callee, names in ctx.corpus.callers.items():
        for n in names:
            callees.setdefault(n, set()).add(callee)

    def flow(start):
        """The scripts that lead to `start` and everything those scripts call, a few hops out."""
        up, frontier = {start}, {start}
        for _ in range(8):
            frontier = {c for f in frontier for c in ctx.corpus.callers.get(f, [])} - up
            up |= frontier
        seen, frontier = set(up), set(up)
        for _ in range(3):
            frontier = {c for f in frontier for c in callees.get(f, ())} - seen
            seen |= frontier
        return seen

    out = []
    for lab in ctx.corpus.labels.values():
        for item in sorted(set(re.findall(r"^\s*removeitem\s+(ITEM_\w+)", lab.body, re.M))):
            info = ctx.items.get(item)
            if info is None or info["key"] or not ctx.corpus.callers.get(lab.name):
                continue
            if not any(re.search(rf"^\s*checkitem\s+{item}\b", ctx.corpus.labels[n].body, re.M) for n in flow(lab.name)):
                out.append(Finding("sellable item taken without checkitem", f"{lab.path}:{lab.name}",
                                   f"removeitem {item}, but {item} is not a Key Item and no script on the way checkitems it"))
    return out


TUTOR_MENU = re.compile(r"^\s*(special\s+ChooseMonForMoveTutor|chooseboxmon\s+SELECT_PC_MON_MOVE_TUTOR|move_tutor\s)", re.M)
FLAG_TEST = re.compile(r"^\s*(?:(?:goto|call)_if_(?:set|unset)|checkflag)\s+(FLAG_\w+)", re.M)
SET_FLAG = re.compile(r"^\s*setflag\s+(FLAG_\w+)", re.M)
SPECIAL = re.compile(r"^\s*special(?:var\s+\w+\s*,)?\s+(\w+)", re.M)
ONCE_LINE = re.compile(r"(learn|teach|taught)[^.!?]{0,30}\bonly once|\bonly once[^.!?]{0,30}(learn|teach)", re.I)


_C_FUNCTIONS = {}


def c_function(name):
    _cache = _C_FUNCTIONS
    if not _cache:
        for path in sorted(glob.glob(os.path.join(ROOT, "src/*.c"))):
            text = strip_c_comments(open(path, encoding="utf-8", errors="replace").read())
            for m in re.finditer(r"^\w[\w \*]*\b(\w+)\(void\)\s*\{", text, re.M):
                depth, i = 1, m.end()
                while depth and i < len(text):
                    depth += {"{": 1, "}": -1}.get(text[i], 0)
                    i += 1
                _cache.setdefault(m.group(1), text[m.end():i])
    return _cache.get(name, "")


def check_one_time_tutor(ctx):
    """A move tutor must teach again: no "learned only once" line, and no flag set by a teach may gate the next one.

    Emerald's `move_tutor` macro, FRLG's tutors and Cape Brink, and HnS's Headbutt tutor each set a
    "taught" flag after the party menu and tested it before the offer. The owner made every tutor
    reusable, so this reads every line, compiled out or not, so a config flip cannot bring a gate back.
    Specials called around the menu count too: their FlagGet flags as tests, their FlagSet flags as sets.
    """
    labels = ctx.corpus.labels
    code = {n: "\n".join(re.split(r"@|//", ln)[0] for ln in lab.raw.split("\n") if ".string" not in ln)
            for n, lab in labels.items()}
    refs = {n: {w for w in re.findall(r"\b[A-Za-z_]\w*\b", body) if w != n and w in labels} for n, body in code.items()}
    menus = {n for n, body in code.items() if re.search(r"^\s*(special\s+ChooseMonForMoveTutor|chooseboxmon\s+SELECT_PC_MON_MOVE_TUTOR)", body, re.M)}
    site = re.compile(TUTOR_MENU.pattern + "|" + r"^\s*call\s+(" + "|".join(sorted(menus)) + r")\b", re.M)
    referrers = {}
    for n, rs in refs.items():
        for r in rs:
            referrers.setdefault(r, set()).add(n)

    def reach(start, graph, hops):
        seen, frontier = set(start), set(start)
        for _ in range(hops):
            frontier = {c for f in frontier for c in graph.get(f, ())} - seen
            seen |= frontier
        return seen

    def c_flags(body, setting):
        flags = set()
        for sp in SPECIAL.findall(body):
            fn = c_function(sp)
            if setting:
                flags |= set(re.findall(r"FlagSet\((FLAG_\w+)\)", fn))
            elif "FlagGet(" in fn:
                flags |= set(re.findall(r"\bFLAG_\w+", fn))
        return flags

    out = []
    for lab in labels.values():
        strings = re.sub(r"\\[nlp]", " ", "".join(re.findall(r'\.string\s+"([^"]*)"', lab.raw)))
        m = ONCE_LINE.search(re.sub(r"\s+", " ", strings))
        if m:
            out.append(Finding("one-time move tutor", f"{lab.path}:{lab.name}", f"says a move is taught {m.group(0)!r}"))
    for name, body in code.items():
        if name in menus:
            continue
        for m in site.finditer(body):
            line = body[m.start():].split("\n")[0].strip()
            if line.startswith("move_tutor") and line.count(",") > 4:
                out.append(Finding("one-time move tutor", f"{labels[name].path}:{name}", "move_tutor passes a taught flag"))
            pre, post = body[:m.start()], body[m.end():]
            tested = set(FLAG_TEST.findall(pre)) | c_flags(pre, False)
            for up in reach({name}, referrers, 4) - {name} - menus:
                tested |= set(FLAG_TEST.findall(code[up])) | c_flags(code[up], False)
            after = reach({w for w in re.findall(r"\b[A-Za-z_]\w*\b", post) if w in labels}, refs, 4) - menus
            sets = set(SET_FLAG.findall(post)) | c_flags(post, True)
            for d in after:
                sets |= set(SET_FLAG.findall(code[d])) | c_flags(code[d], True)
            for flag in sorted(tested & sets):
                out.append(Finding("one-time move tutor", f"{labels[name].path}:{name}",
                                   f"{flag} is set after the tutor menu and tested before it"))
    return out


def check_relearner_result_vars(ctx):
    """A move relearner script must read the lesson's result from VAR_RESULT.

    Emerald and FRLG zeroed VAR_0x8004 on a give-up and set VAR_0x8005 to the number of relearnable
    moves when a POKeMON was chosen. This build's relearner leaves VAR_0x8004 as the chosen slot,
    reports the lesson in VAR_RESULT and sets VAR_0x8005 nowhere, so a script testing those took the
    payment on a give-up, taught the first slot for free and opened an empty list.
    """
    out = []
    for name, lab in ctx.corpus.labels.items():
        body = "\n".join(re.split(r"@|//", ln)[0] for ln in lab.raw.split("\n") if ".string" not in ln)
        for special, var in (("TeachMoveRelearnerMove", "VAR_0x8004"), ("ChooseMonForMoveRelearner", "VAR_0x8005")):
            m = re.search(r"^\s*special\s+" + special + r"\b", body, re.M)
            if m and re.search(r"^\s*goto_if_\w+\s+" + var + r"\b", body[m.end():], re.M):
                out.append(Finding("relearner result variable", f"{lab.path}:{name}",
                                   f"tests {var} after {special}; the relearner reports in VAR_RESULT"))
    return out


NICKNAME_SLOT = re.compile(r"^\s*(setvar|copyvar)\s+VAR_0x8004\b|^\s*call\s+Common_EventScript_GetGiftMonPartySlot\b", re.M)


def check_nickname_target(ctx):
    """A script that opens the nickname screen itself must first say whose name it is.

    ChangePokemonNickname renames the party slot in VAR_0x8004, or the PC slot the last deposit
    recorded when VAR_0x8004 is PC_MON_CHOSEN. FRLG named a boxed gift with ChangeBoxPokemonNickname,
    which needed neither, so a ported PC branch that kept only the special renamed whatever VAR_0x8004
    last held: a party Pokemon, or memory past gParties, while the gift kept its name.
    """
    out = []
    for name, lab in ctx.corpus.labels.items():
        body = "\n".join(re.split(r"@|//", ln)[0] for ln in lab.body.split("\n") if ".string" not in ln)
        m = re.search(r"^\s*special\s+ChangePokemonNickname\b", body, re.M)
        if m and name != "Common_EventScript_NameReceivedPartyMon" and not NICKNAME_SLOT.search(body[:m.start()]):
            out.append(Finding("nickname target", f"{lab.path}:{name}",
                               "opens the nickname screen without setting VAR_0x8004 (a party slot or PC_MON_CHOSEN)"))
    return out


def obedience_table():
    src = read("src/battle_util.c")
    body = src[src.index("GetAttackerObedienceForAction(void)"):]
    body = body[:body.index("levelReferenced <= obedienceLevel")]
    full = {int(n) for n in re.findall(r"HasActiveRegionBadge\((\d)\)\)[^\n]*\n\s*return OBEYS", body)}
    levels = {int(n): int(v) for n, v in re.findall(r"HasActiveRegionBadge\((\d)\)\)[^\n]*\n\s*obedienceLevel = (\d+);", body)}
    return levels, full


BADGES = {
    "BOULDER": 0, "CASCADE": 1, "THUNDER": 2, "RAINBOW": 3, "SOUL": 4, "MARSH": 5, "VOLCANO": 6, "EARTH": 7,
    "ZEPHYR": 0, "HIVE": 1, "PLAIN": 2, "FOG": 3, "STORM": 4, "MINERAL": 5, "GLACIER": 6, "RISING": 7,
    "STONE": 0, "KNUCKLE": 1, "DYNAMO": 2, "HEAT": 3, "BALANCE": 4, "FEATHER": 5, "MIND": 6, "RAIN": 7,
}
BADGE_IN_TEXT = re.compile(r"\b(" + "|".join(BADGES) + r") ?BADGE\b")
BADGE_IN_LABEL = re.compile(r"(" + "|".join(b.capitalize() for b in BADGES) + r")Badge")


def badge_of(ctx, lab):
    m = BADGE_IN_TEXT.search(lab.text)
    if m:
        return m.group(1)
    for name in [lab.name] + ctx.corpus.callers.get(lab.name, []):
        m = BADGE_IN_LABEL.search(name)
        if m:
            return m.group(1).upper()
    return None


def check_obedience_levels(ctx):
    """A badge speech must quote the obedience level GetAttackerObedienceForAction grants for it."""
    levels, full = obedience_table()
    out = []
    for lab in ctx.corpus.texts():
        if not re.search(r"\bobey", lab.text, re.I):
            continue
        badge = badge_of(ctx, lab)
        if badge is None:
            continue
        idx = BADGES[badge]
        m = re.search(r"up to (?:Lv\.|LV|L|Level) ?(\d+)", lab.text)
        if m:
            said = int(m.group(1))
            real = "every level" if idx in full else levels.get(idx, 10)
            if said != real:
                out.append(Finding("obedience level", f"{lab.path}:{lab.name}",
                                   f"{badge} BADGE (badge {idx + 1}) says level {said}; the build grants {real}"))
        elif re.search(r"any level|full obedience|All POK\S?MON will obey|obey your every command without question", lab.text, re.I):
            if idx not in full:
                out.append(Finding("obedience level", f"{lab.path}:{lab.name}",
                                   f"{badge} BADGE (badge {idx + 1}) promises every level; the build grants {levels.get(idx, 10)}"))
    return out


def check_trade_only_evolutions(ctx):
    """Every Gen 1-3 evolution needs a route that works without a link cable.

    Link trade is compiled out, and FEATURES.md promises trade evolutions work offline: the Linking
    Cord and the held evolution items (Metal Coat, King's Rock, ...) are sold to be used like
    stones. An EVO_ITEM row only fires from the Bag when the item's field function is
    ItemUseOutOfBattle_EvolutionStone.
    """
    out = []
    usable = {i for i, v in ctx.items.items() if v["func"] == "ItemUseOutOfBattle_EvolutionStone"}
    for sp, info in sorted(ctx.species.items()):
        if not info["gen3"]:
            continue
        targets = {}
        for method, param, target, _ in info["evos"]:
            if not ctx.species.get(target, {}).get("gen3"):
                continue
            offline = method != "EVO_TRADE" and not (method == "EVO_ITEM" and param not in usable)
            targets.setdefault(target, []).append((method, param, offline))
        for target, routes in sorted(targets.items()):
            if not any(r[2] for r in routes):
                items = [p for m, p, _ in routes if m == "EVO_ITEM"]
                why = ", ".join(f"{i} has {ctx.items.get(i, {}).get('func')}" for i in items) or "trade only"
                out.append(Finding("trade-only evolution", "src/data/pokemon/species_info",
                                   f"{sp} -> {target} has no offline route ({why})"))
    return out


def check_evolution_claims(ctx):
    """An NPC naming the level or held item a species evolves with must match the species table."""
    names = {v["name"]: k for k, v in ctx.species.items() if v["gen3"]}
    item_names = {v["name"]: k for k, v in ctx.items.items()}
    out = []
    for lab in ctx.corpus.texts():
        for m in re.finditer(r"([^.!?]*?) evolves? at (?:LVL|LV\.?|level|L) ?(\d+)", lab.text):
            level = m.group(2)
            for n in re.findall(r"\b[A-Z][A-Z'\.]+\b", m.group(1).split(" while ")[-1]):
                sp = names.get(n)
                if sp and not any(e[0] == "EVO_LEVEL" and e[1] == level for e in ctx.species[sp]["evos"]):
                    out.append(Finding("evolution claim", f"{lab.path}:{lab.name}",
                                       f"says {n} evolves at level {level}; the table has {[e[:2] for e in ctx.species[sp]['evos']]}"))
        m = re.search(r"([A-Z][A-Z ]+[A-Z])[^.]{0,80}evolve[^.]{0,60}while holding and leveling up", lab.text)
        if m and m.group(1).strip() in item_names:
            item = item_names[m.group(1).strip()]
            held = any(e[0] == "EVO_LEVEL" and item in e[3] for v in ctx.species.values() for e in v["evos"])
            if not held:
                out.append(Finding("evolution claim", f"{lab.path}:{lab.name}",
                                   f"says {m.group(1)} evolves a POKéMON held through a level-up; no species does"))
    return out


def check_fog_maps(ctx):
    """Every map whose fog was scenery in its source game now changes its battles."""
    out = []
    for path in sorted(glob.glob(os.path.join(ROOT, "data/maps/*/map.json"))):
        if re.search(r'"weather":\s*"WEATHER_FOG_(HORIZONTAL|DIAGONAL)"', read(path)):
            out.append(Finding("fog changes battles", os.path.relpath(path, ROOT), "map weather is fog"))
    for lab in ctx.corpus.labels.values():
        if re.search(r"^\s*setweather WEATHER_FOG_(HORIZONTAL|DIAGONAL)\b", lab.body, re.M):
            out.append(Finding("fog changes battles", f"{lab.path}:{lab.name}", "sets fog weather"))
    return out


RULES = [
    Rule("TMs called single-use", "I_REUSABLE_TMS", lambda c: c.value("I_REUSABLE_TMS"),
         "a TM teaches its move any number of times", "a TM is consumed when used",
         text_rule("TMs called single-use", [
             r"(TM|TECHNICAL MACHINE)[^.!?]{0,40}\b(only once|one-time|one use|single use)",
             r"unlike a TM",
             r"\bTM\b[^.!?]{0,30}it's gone",
         ])),
    Rule("one-time move tutor", "move tutor policy", lambda c: True,
         "every move tutor in every region teaches again", "Emerald, FRLG and HGSS tutors taught once and warned so",
         check_one_time_tutor),
    Rule("relearner result variable", "move relearner in src/move_relearner.c", lambda c: True,
         "the relearner reports a lesson in VAR_RESULT and leaves VAR_0x8004 as the chosen slot",
         "Emerald and FRLG zeroed VAR_0x8004 on a give-up and counted relearnable moves in VAR_0x8005",
         check_relearner_result_vars),
    Rule("nickname target", "ChangePokemonNickname in src/tv.c", lambda c: True,
         "the nickname screen renames the slot VAR_0x8004 names, PC_MON_CHOSEN for a boxed gift",
         "FRLG named a boxed gift with ChangeBoxPokemonNickname, which read the deposit slot itself",
         check_nickname_target),
    Rule("sellable item taken without checkitem", "I_KEY_FOSSILS", lambda c: c.value("I_KEY_FOSSILS") >= GENS["GEN_4"],
         "fossils are Items-pocket goods a mart buys", "fossils are Key Items that never leave the bag",
         check_sellable_removed_unchecked),
    Rule("badge stat boost", "B_BADGE_BOOST", lambda c: c.value("B_BADGE_BOOST") >= GENS["GEN_4"],
         "badges raise no stat", "Gen 3 badges raise one stat by 10%",
         text_rule("badge stat boost", [
             rf"BADGE[^.!?]*\b(raises?|boosts?|heightens?|enhances?|cranks? up|increases?)\b[^.!?]*\b{STAT}",
             rf"{STAT}( stat)?s?( of (all )?your {MON})?[^.!?]{{0,30}}\b(increases?|rises?|rise a little|will increase)\b",
             rf"\b(make|makes) your {MON} (a little bit faster|more powerful|stronger)",
             rf"{STAT} of {MON}",
         ], scope=r"BADGE|stat of all your")),
    Rule("obedience level", "obedience table in src/battle_util.c", lambda c: True,
         "each badge of the active region raises the cap by 10 (src/battle_util.c)",
         "Gen 3 caps moved only at the 2nd, 4th, 6th and 8th badge; GSC's STORMBADGE gave 70",
         check_obedience_levels),
    Rule("field poison", "OW_POISON_DAMAGE", lambda c: c.value("OW_POISON_DAMAGE") >= GENS["GEN_5"],
         "poison does no damage outside battle", "poison drains HP every four steps until the POKéMON faints",
         text_rule("field poison", [
             r"walk around with a poisoned [^.!?]*lose HP",
             r"HP will drop while it is traveling",
             r"poisoned! It fainted while we were walking",
             r"poisoned my POK\S?MON! I just kept going, but then my POK\S?MON fainted",
             r"poison[^.!?]{0,60}(while (we were )?(walking|traveling)|as you walk)[^.!?]{0,40}(HP|faint)",
         ])),
    Rule("HM moves unforgettable", "P_CAN_FORGET_HIDDEN_MOVE", lambda c: c.value("P_CAN_FORGET_HIDDEN_MOVE"),
         "an HM move is forgotten like any other", "only the Move Deleter removes an HM move",
         text_rule("HM moves unforgettable", [
             r"(can't|cannot|can not|won't|unable to) (easily )?(forget|be forgotten|erase|delete)[^.!?]{0,20}(those|HM|hidden) moves",
             r"(HM|hidden) moves?[^.!?]{0,30}(can't|cannot|can not|won't) be (forgotten|erased|deleted)",
         ], scope=r"\bHMs?\b|HIDDEN MACHINE|hidden move")),
    Rule("field move must be known", "QOL_FIELD_MOVES_NO_TEACH", lambda c: c.value("QOL_FIELD_MOVES_NO_TEACH"),
         "a party POKéMON that can learn an HM move may use it untaught", "only a POKéMON that knows the move can use it",
         text_rule("field move must be known", [
             r"must know the move (CUT|FLASH|SURF|STRENGTH|ROCK SMASH|WATERFALL|DIVE|FLY) to use it",
         ])),
    Rule("trade-only evolution", "I_USE_EVO_HELD_ITEMS_FROM_BAG", lambda c: True,
         "link trade is compiled out; trade evolutions use items from the Bag", "trade evolutions need a link cable",
         check_trade_only_evolutions),
    Rule("evolution claim", "I_USE_EVO_HELD_ITEMS_FROM_BAG", lambda c: True,
         "the species table decides how each POKéMON evolves", "pokemonHnS evolved trade POKéMON by level and held item",
         check_evolution_claims),
    Rule("fog changes battles", "B_OVERWORLD_FOG",
         lambda c: c.value("B_OVERWORLD_FOG") == GENS["GEN_4"] or c.value("B_OVERWORLD_FOG") >= GENS["GEN_8"],
         "overworld fog starts Misty Terrain (Gen 8+) or fog weather (Gen 4) in battle", "Gen 3 fog is scenery",
         check_fog_maps),
]


# Toggles that diverge from a source game where no script or text was found to assume the old rule.
CLEARED = [
    ("I_SELL_VALUE_FRACTION", "items sell for a quarter", "treasures carry TREASURE_FACTOR 2, so the Route 10 Nugget still sells for 5000"),
    ("I_EXP_SHARE_ITEM", "a held item", "Mr. Stone and the Route 15 aide describe a held item"),
    ("OW_TIME_OF_DAY_ENCOUNTERS", "random tables ignore the clock",
     "Johto's day and night overworld POKéMON (FLAG_DAY_POKEMON) keep the 'only at night' hints partly true"),
    ("OW_RUNNING_INDOORS", "running works indoors", "no line forbids it"),
    ("P_FRIENDSHIP_EVO_THRESHOLD", "friendship evolutions happen at a set level", "no friendship hint remains"),
    ("QOL_FIELD_MOVES_ITEM_GATE", "a tool item or the badge unlocks a field move", "a badge still allows its move"),
]


def census(cfg):
    keys = sorted(set().union(*[re.findall(r"\b[A-Z][A-Z0-9_]{3,}\b", r.toggle) for r in RULES]))
    print("Audited toggles:")
    for k in keys:
        print(f"  {k} = {cfg.raw.get(k, '(unset)')} -> {cfg.value(k)}")
    print("Cleared toggles:")
    for k, rule, why in CLEARED:
        print(f"  {k} = {cfg.raw.get(k, '(unset)')}: {rule}; {why}")


def main():
    ctx = Context()
    if "--list" in sys.argv:
        census(ctx.cfg)
    findings = []
    for rule in RULES:
        if not rule.diverges(ctx.cfg):
            print(f"skip {rule.name}: {rule.toggle} no longer diverges")
            continue
        found = rule.check(ctx)
        for f in found:
            print(f"{f.rule} [{rule.toggle}: {rule.build_rule}; source: {rule.source_rule}]\n  {f.where}: {f.detail}")
        findings += found
    if findings:
        print(f"FAIL: {len(findings)} script or text line(s) assume a rule this build's config changed")
        return 1
    print(f"OK: {len(RULES)} config rules, no script or text assumes the source game's rule")
    return 0


if __name__ == "__main__":
    sys.exit(main())
