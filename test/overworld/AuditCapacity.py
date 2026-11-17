#!/usr/bin/env python3
"""Audit every script give and charge for its failure outcome.

Scans the event scripts that data/event_scripts.s assembles and lists every Pokemon gift,
item gift and money or coin sink, then asks whether the script handles the outcome where
the gift does not fit or the wallet is short:

  mon     givemon, giveegg, givenamedmon, giveoddegg: VAR_RESULT must be tested for
          MON_CANT_GIVE afterwards (party and every box full), or a party-size check
          must stand on every path into the gift. givenamedmon and giveoddegg fill the
          party only, so their refusal must not be the "boxes are full" script.
  item    giveitem, additem, addpcitem, givedecoration, adddecoration: VAR_RESULT tested
          afterwards, or checkitemspace for the same item on every path in.
          giveitem_msg and a bare msgreceiveditem print "received" no matter what, and
          the std script overwrites VAR_RESULT, so they need checkitemspace first.
          finditem handles a full bag itself; it is flagged only when the caller goes on
          to change state without looking at VAR_RESULT.
  money   removemoney needs checkmoney on every path in; SubtractMoneyFromVar0x8005 needs
          IsEnoughForCostInVar0x8005.
  coins   removecoins needs checkcoins first or a VAR_RESULT test after (TRUE = failed);
          addcoins needs CheckAddCoins or checkcoins first.
  charge  a money or coin sink that flows into a gift must check room before it charges.
  commit  a gift that can fail must not first hide its ball or set its "given" flag.
  special C specials that create a Pokemon, add an item or take money (found by scanning
          their C bodies for the give and charge calls); each one is reviewed by hand and
          listed in ALLOWLIST with its reason. Daycare withdrawals and eggs need a party-size
          check, and ChooseStarter (which gives in C) needs a room check, on every path in.

An item gift whose pocket cannot fill is safe by capacity: the TM/HM and Key Items pockets
hold more slots than the game has distinct items for them.

A site that no map, script or C code can start, or that only the debug menu starts, is
counted as dead rather than unguarded.

Run from the repo root: python3 test/overworld/AuditCapacity.py [--all] [--quiet]
--all prints every site with its verdict; --quiet leaves out the allowlist.
Exit status 1 when a site is neither guarded nor allowlisted, or an allowlist entry is stale.
"""
import os
import re
import sys
from collections import defaultdict

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

MON_OPS = {"givemon", "giveegg", "givenamedmon", "giveoddegg"}
# The Johto compat gifts fill the party only, so their MON_CANT_GIVE means a full party; the
# stock no-room script says the PC boxes are full and must not answer it.
PARTY_ONLY_OPS = {"givenamedmon", "giveoddegg"}
BOXES_FULL_SCRIPT = "Common_EventScript_NoMoreRoomForPokemon"
BOX_RECEIPT_SCRIPT = "Common_EventScript_ReceivedGiftMon"
BOX_NOTICE_SCRIPTS = {BOX_RECEIPT_SCRIPT, "Common_EventScript_TransferredToPC"}
ITEM_POST_OPS = {"giveitem", "givekeyitem", "additem", "addpcitem", "givedecoration", "adddecoration"}
ITEM_PRE_OPS = {"giveitem_msg", "msgreceiveditem"}
MONEY_OPS = {"removemoney"}
COIN_OPS = {"removecoins", "addcoins"}
GIVE_OPS = MON_OPS | ITEM_POST_OPS | ITEM_PRE_OPS | {"giverandomberry"}

# specials that put a Pokemon in the party only; a party-size check must stand on every path in
PARTY_SPECIALS = {"GiveEggFromDaycare", "TakePokemonFromDaycare", "TakePokemonFromRoute5Daycare"}
MON_GUARDS = {"getpartysize", "GetMaxPartySize", "CalculatePlayerPartyCount", "GetPartySize"}
# specials that give a Pokemon to the party or the PC in C with no way to refuse; a room check
# must stand on every path in (Birch's bag gives its starter inside CB2_GiveStarter)
STORAGE_SPECIALS = {"ChooseStarter"}
STORAGE_GUARDS = MON_GUARDS | {"ScriptCheckFreePokemonStorageSpace"}

# specials that create a Pokemon, hand out an item or take money in C
SPECIAL_SITES = {
    "SpecialPokemon_Give", "TransferBugContestMon",
    "FavorLadyGetPrize", "SetQuizLadyState_GivePrize", "SampleResortGorgeousMonAndReward",
    "TryBattleNetRematchReward", "ClaimBattleNetStone", "TryBuyBattleNetShard",
    "GiveBattleNetRandomShard", "DaisyMassageServices",
    "BuyGameCornerCoins", "QuizLadyTakePrizeForCustomQuiz", "DeductBattleNetShards",
}

GIVE_API = re.compile(r"\b(AddBagItem|AddPCItem|GiveMonToPlayer|ScriptGiveMon|GiveScriptedMonToPlayer|SendMonToPC|"
                      r"CopyMonToPC|RemoveMoney|AddCoins|RemoveCoins|RemoveBagItem|DecorationAdd|CreateEgg)\b")


def specials_that_give():
    """Specials whose C body calls a give or charge API directly."""
    names = set(re.findall(r"def_special\s+(\w+)", open(os.path.join(ROOT, "data/specials.inc")).read()))
    found = set()
    for dirpath, _, files in os.walk(os.path.join(ROOT, "src")):
        for fn in files:
            if not fn.endswith(".c"):
                continue
            text = open(os.path.join(dirpath, fn), encoding="utf-8", errors="replace").read()
            for m in re.finditer(r"^\w[\w \*]*?\b(\w+)\s*\(void\)\s*\n\{", text, re.M):
                if m.group(1) in names:
                    end = text.find("\n}", m.end())
                    if GIVE_API.search(text[m.end():end]):
                        found.add(m.group(1))
    return found


TERMINATORS = {"end", "return", "goto", "step_end"}
NOT_BRANCH = {"callnative", "callstd", "callfunc"}

# Writes to VAR_RESULT that end a post-check scan.
RESULT_WRITERS = {
    "checkitemspace", "checkitem", "checkitemtype", "getpartysize", "checkmoney", "checkcoins",
    "givemon", "giveegg", "giveitem", "givekeyitem", "additem", "removeitem", "addpcitem", "checkpcitem",
    "givenamedmon", "giveoddegg", "multichoice", "multichoicedefault", "multichoicegrid",
    "yesnobox", "checkpartymove", "giveitem_msg", "msgreceiveditem", "finditem",
    "removecoins", "addcoins", "checkplayergender", "random", "getpokenewsactive",
    "checkpcspace", "removenamedmon", "dynmultichoice", "checkdecor", "checkdecorspace",
}

COND_RE = re.compile(r"^(goto_if_|call_if_|compare$|switch$|goto_if$)")


def strip_comment(s):
    out, q = [], False
    for ch in s:
        if ch == '"':
            q = not q
        if ch == "@" and not q:
            break
        out.append(ch)
    s = "".join(out)
    s = s.split("//", 1)[0]
    return s.rstrip()


def split_args(s):
    args, depth, cur = [], 0, []
    for ch in s:
        if ch in "([":
            depth += 1
        elif ch in ")]":
            depth -= 1
        if ch == "," and depth == 0:
            args.append("".join(cur).strip())
            cur = []
        else:
            cur.append(ch)
    tail = "".join(cur).strip()
    if tail:
        args.append(tail)
    return args


class Instr:
    __slots__ = ("file", "line", "op", "args", "labels", "label", "idx")

    def __init__(self, file, line, op, args, label):
        self.file, self.line, self.op, self.args, self.label = file, line, op, args, label
        self.labels = []
        self.idx = -1

    def where(self):
        return "%s:%d" % (self.file, self.line)

    def text(self):
        return ("%s %s" % (self.op, ", ".join(self.args))).strip()


def included_files():
    seen, order = set(), []

    def walk(rel):
        if rel in seen:
            return
        seen.add(rel)
        path = os.path.join(ROOT, rel)
        if not os.path.exists(path):
            return
        order.append(rel)
        with open(path, encoding="utf-8", errors="replace") as fh:
            for raw in fh:
                m = re.match(r'\s*\.include\s+"([^"]+)"', raw)
                if m:
                    inc = m.group(1)
                    if inc.startswith(("data/maps/", "data/scripts/")) or inc == "data/event_scripts.s":
                        walk(inc)

    walk("data/event_scripts.s")
    return order


def parse():
    prog, labels = [], {}
    for rel in included_files():
        label = None
        pending = []
        with open(os.path.join(ROOT, rel), encoding="utf-8", errors="replace") as fh:
            for n, raw in enumerate(fh, 1):
                s = strip_comment(raw)
                if not s.strip() or s.lstrip().startswith("#"):
                    continue
                m = re.match(r"^\s*([A-Za-z_][A-Za-z0-9_]*)::?(?:\s+(.*))?$", s)
                if m:
                    label = m.group(1)
                    pending.append(label)
                    s = m.group(2) or ""
                    if not s.strip():
                        continue
                parts = s.strip().split(None, 1)
                op = parts[0]
                if op in (".if", ".ifdef", ".ifndef", ".else", ".elseif", ".endif"):
                    continue
                args = split_args(parts[1]) if len(parts) > 1 else []
                ins = Instr(rel, n, op, args, label)
                ins.labels = pending
                pending = []
                ins.idx = len(prog)
                for lb in ins.labels:
                    labels[lb] = ins.idx
                prog.append(ins)
    return prog, labels


def is_data(ins):
    return ins.op.startswith(".") or ins.op in ("map_script", "map_script_2")


def branch_targets(ins, labels):
    op = ins.op
    if op in NOT_BRANCH:
        return []
    if op.startswith(("goto", "call", "case", "trainerbattle", "vgoto", "vcall")):
        return [a for a in ins.args if a in labels]
    return []


def build_preds(prog, labels):
    preds = defaultdict(list)
    for i, ins in enumerate(prog):
        if is_data(ins):
            continue
        for t in branch_targets(ins, labels):
            preds[labels[t]].append(i)
        if ins.op in TERMINATORS:
            continue
        j = i + 1
        if j < len(prog) and prog[j].file == ins.file and not is_data(prog[j]):
            preds[j].append(i)
    return preds


def mentions(ins, var):
    return any(re.search(r"\b%s\b" % re.escape(var), a) for a in ins.args)


def tests_value(ins, name, number):
    vals = ins.args[1:-1] if len(ins.args) >= 3 else ins.args[1:2]
    return any(v in (name, number) for v in vals)


def writes_result(ins):
    if ins.op in RESULT_WRITERS or ins.op in ("callstd", "special"):
        return True
    if ins.op == "specialvar" and ins.args and ins.args[0] == "VAR_RESULT":
        return True
    if ins.op in ("setvar", "copyvar") and ins.args and ins.args[0] == "VAR_RESULT":
        return True
    if ins.op == "msgbox" and len(ins.args) > 1 and "YESNO" in ins.args[1]:
        return True
    if ins.op == "call" or ins.op.startswith(("call_if", "trainerbattle")):
        return True
    return False


def forward_conds(prog, i, limit=12, out=None, depth=0):
    """Conditionals that test the result of prog[i] before anything overwrites it.

    Follows fallthrough only; `compare VAR_RESULT, X` + `goto_if_eq L` counts as one test.
    copyvar into another var makes that var an alias of the result.
    """
    aliases = {out or "VAR_RESULT"}
    found = []
    j = i + 1
    steps = 0
    pending_compare = None
    while j < len(prog) and steps < limit and prog[j].file == prog[i].file:
        ins = prog[j]
        if is_data(ins):
            break
        if ins.op == "copyvar" and len(ins.args) == 2 and ins.args[1] in aliases:
            aliases.add(ins.args[0])
        elif ins.op == "compare" and ins.args and ins.args[0] in aliases:
            pending_compare = ins
        elif COND_RE.match(ins.op) and any(mentions(ins, a) for a in aliases):
            found.append(ins)
        elif ins.op.startswith(("goto_if_", "call_if_")) and pending_compare is not None and len(ins.args) == 1:
            found.append(Instr(ins.file, ins.line, ins.op, pending_compare.args + ins.args, ins.label))
        elif ins.op == "switch" and ins.args and ins.args[0] in aliases:
            k = j + 1
            while k < len(prog) and prog[k].op == "case":
                found.append(Instr(prog[k].file, prog[k].line, "goto_if_eq", ["VAR_RESULT"] + prog[k].args, prog[k].label))
                k += 1
            break
        elif writes_result(ins) and "VAR_RESULT" in aliases and not (ins.op == "copyvar"):
            aliases.discard("VAR_RESULT")
            if not aliases:
                break
        if ins.op in TERMINATORS:
            if ins.op == "goto" and ins.args and ins.args[0] in LABELS:
                j = LABELS[ins.args[0]]
                steps += 1
                continue
            if ins.op == "return" and "VAR_RESULT" in aliases and depth < 2:
                sites = call_sites(prog, j)
                per = [forward_conds(prog, c, limit, out, depth + 1) for c in sites]
                if sites and all(per):
                    found.extend(c for p in per for c in p)
            break
        j += 1
        steps += 1
    return found


def reaches_box_notice(prog, i, limit=80):
    """Some path out of prog[i] tests MON_GIVEN_TO_PC or calls a script that announces the box."""
    seen, stack = set(), [i + 1]
    while stack and len(seen) < limit:
        j = stack.pop()
        if j in seen or j >= len(prog) or is_data(prog[j]):
            continue
        seen.add(j)
        ins = prog[j]
        if "MON_GIVEN_TO_PC" in ins.args or (ins.op.startswith("call") and ins.args and ins.args[-1] in BOX_NOTICE_SCRIPTS):
            return True
        stack.extend(LABELS[t] for t in branch_targets(ins, LABELS) if not ins.op.startswith("call"))
        if ins.op not in TERMINATORS and j + 1 < len(prog) and prog[j + 1].file == ins.file:
            stack.append(j + 1)
    return False


def call_sites(prog, i, limit=40):
    """The call instructions whose subroutine reaches prog[i]."""
    seen, out, stack = set(), [], [i]
    while stack and len(seen) < limit:
        n = stack.pop()
        if n in seen:
            continue
        seen.add(n)
        for p in PREDS.get(n, []):
            q = prog[p]
            if (q.op == "call" or q.op.startswith("call_if")) and p != n - 1:
                out.append(p)
            else:
                stack.append(p)
    return out


def guard_ok(prog, i, guard_ops, item=None):
    """prog[i] is a guard op (or a call to a one-line subroutine holding one) that a test follows."""
    ins = prog[i]
    if (ins.op == "call" or ins.op.startswith("call_if")) and ins.args and ins.args[-1] in LABELS:
        k = LABELS[ins.args[-1]]
        body = prog[k:k + 2]
        return (len(body) == 2 and body[1].op == "return" and guard_ok_op(body[0], guard_ops, item)
                and bool(forward_conds(prog, i)))
    if not guard_ok_op(ins, guard_ops, item):
        return False
    if ins.op == "special":
        return True
    out = ins.args[0] if ins.op == "checkcoins" and ins.args else None
    return bool(forward_conds(prog, i, out=out))


def splits(ins):
    """A test splits the flow when its failure side does not come back to the next line."""
    if ins.op.startswith("goto_if") or ins.op == "goto_if":
        return True
    if ins.op.startswith("call_if") and ins.args and ins.args[-1] in LABELS:
        k = LABELS[ins.args[-1]]
        for q in PROG[k:k + 40]:
            if q.op == "return":
                return False
            if q.op == "end":
                return True
            if q.op == "goto":
                return True
    return False


def guard_ok_op(ins, guard_ops, item):
    if ins.op in ("specialvar", "special"):
        return bool(ins.args) and ins.args[-1] in guard_ops
    if ins.op not in guard_ops:
        return False
    if item is not None and ins.op in ("checkitemspace", "checkpcspace") and ins.args:
        a = ins.args[0]
        if a != item and not a.startswith("VAR_") and not item.startswith("VAR_"):
            return False
    return True


def all_paths_guarded(prog, preds, site, guard_ops, item=None, depth=60):
    """True if every backward path from `site` hits a guard; returns (ok, entry_or_None)."""
    seen = set()
    stack = [(p, 0) for p in preds.get(site, [])]
    if not stack:
        return False, prog[site]
    while stack:
        i, d = stack.pop()
        if i in seen:
            continue
        seen.add(i)
        if guard_ok(prog, i, guard_ops, item):
            continue
        if d > depth:
            return False, prog[i]
        ps = preds.get(i, [])
        if not ps:
            return False, prog[i]
        stack.extend((p, d + 1) for p in ps)
    return True, None


def checked_amounts(prog, preds, site, depth=60):
    """The checkmoney amounts that stand on the paths into a charge."""
    seen, amounts, stack = set(), set(), [(p, 0) for p in preds.get(site, [])]
    while stack:
        i, d = stack.pop()
        if i in seen or d > depth:
            continue
        seen.add(i)
        q = prog[i]
        body = q
        if (q.op == "call" or q.op.startswith("call_if")) and q.args and q.args[-1] in LABELS:
            body = prog[LABELS[q.args[-1]]]
        if body.op == "checkmoney" and body.args:
            amounts.add(body.args[0])
            continue
        stack.extend((p, d + 1) for p in preds.get(i, []))
    return amounts


def config_defines():
    defs = {}
    for fn in sorted(os.listdir(os.path.join(ROOT, "include/config"))):
        with open(os.path.join(ROOT, "include/config", fn), encoding="utf-8", errors="replace") as fh:
            for name, value in re.findall(r"^\s*#define\s+(\w+)\s+([^\s/]+)", fh.read(), re.M):
                defs.setdefault(name, value)
    return defs


def eval_condition(cond, defs):
    """Value of an items.h #if line: a config name compared with a constant, or None if unknown."""
    def value(tok):
        for _ in range(8):
            if re.fullmatch(r"\d+", tok):
                return int(tok)
            if tok in ("TRUE", "FALSE"):
                return int(tok == "TRUE")
            if tok not in defs:
                return None
            tok = defs[tok]
        return None
    m = re.fullmatch(r"\(?\s*(\w+)\s*(>=|<=|==|!=|>|<)\s*(\w+)\s*\)?", cond.strip())
    if m:
        a, b = value(m.group(1)), value(m.group(3))
        if a is None or b is None:
            return None
        return {">=": a >= b, "<=": a <= b, "==": a == b, "!=": a != b, ">": a > b, "<": a < b}[m.group(2)]
    v = value(cond.strip())
    return None if v is None else bool(v)


def load_pockets():
    """Each item's pocket in this build: an `#if CONFIG` branch in items.h counts only when it is live."""
    pockets = {}
    name = None
    defs = config_defines()
    live = []  # one bool per open #if: is the current branch compiled in
    with open(os.path.join(ROOT, "src/data/items.h"), encoding="utf-8", errors="replace") as fh:
        for raw in fh:
            d = re.match(r"\s*#\s*(if|ifdef|ifndef|else|endif)\b\s*(.*)", raw)
            if d:
                kind, cond = d.group(1), d.group(2).split("//")[0]
                if kind == "if":
                    v = eval_condition(cond, defs)
                    live.append(True if v is None else v)
                elif kind in ("ifdef", "ifndef"):
                    live.append(True)
                elif kind == "else" and live:
                    live[-1] = not live[-1]
                elif kind == "endif" and live:
                    live.pop()
                continue
            if not all(live):
                continue
            m = re.match(r"\s*\[(ITEM_[A-Z0-9_]+)\]\s*=", raw)
            if m:
                name = m.group(1)
            m = re.search(r"\.pocket\s*=\s*(POCKET_[A-Z_]+)", raw)
            if m and name:
                pockets[name] = m.group(1)
    for name in re.findall(r"\b(ITEM_[TH]M\d+)\b", open(os.path.join(ROOT, "include/constants/items.h")).read()):
        pockets.setdefault(name, "POCKET_TM_HM")
    return pockets


def pocket_cannot_fill():
    """Pockets with more slots than distinct items the game can put in them."""
    glob = open(os.path.join(ROOT, "include/constants/global.h")).read()
    cap = {k: int(v) for k, v in re.findall(r"#define BAG_(\w+)_COUNT (\d+)", glob)}
    tms = open(os.path.join(ROOT, "include/constants/tms_hms.h")).read()
    n_tmhm = len(re.findall(r"^\s*F\(", tms, re.M))
    pockets = load_pockets()
    n_key = sum(1 for p in pockets.values() if p == "POCKET_KEY_ITEMS")
    safe = {}
    if n_tmhm <= cap["TMHM"]:
        safe["POCKET_TM_HM"] = "%d TMs and HMs exist, the pocket holds %d" % (n_tmhm, cap["TMHM"])
    if n_key <= cap["KEYITEMS"]:
        safe["POCKET_KEY_ITEMS"] = "%d key items exist, the pocket holds %d" % (n_key, cap["KEYITEMS"])
    return safe, pockets


# (file, label, op, first argument) -> why the site is safe. Every entry was checked by hand.
ALLOWLIST = {
    # The std scripts behind giveitem and givedecoration hand VAR_RESULT back to their callers,
    # and the callers are audited.
    ("data/scripts/obtain_item.inc", "Std_ObtainItem", "additem", "ITEMID"):
        "std script; returns VAR_RESULT to the giveitem caller",
    ("data/scripts/obtain_item.inc", "Std_ObtainDecoration", "adddecoration", "ITEMID"):
        "std script; returns VAR_RESULT to the givedecoration caller",
    # Honest forfeits: the speaker says the bag is full and the gift is not given.
    ("data/maps/RustboroCity/scripts.inc", "RustboroCity_EventScript_ReturnGoods", "giveitem", "ITEM_GREAT_BALL"):
        "vanilla: 'You're loaded with items. I can't give you this GREAT BALL.' and the story goes on",
    ("data/maps/LittlerootTown_ProfessorBirchsLab/scripts.inc", "LittlerootTown_ProfessorBirchsLab_EventScript_MayGivePokeBalls", "giveitem", "ITEM_POKE_BALL"):
        "vanilla: May says 'Oh? Your BAG's full.' and keeps the balls",
    ("data/maps/LittlerootTown_ProfessorBirchsLab/scripts.inc", "LittlerootTown_ProfessorBirchsLab_EventScript_BrendanGivePokeBalls", "giveitem", "ITEM_POKE_BALL"):
        "vanilla: Brendan says 'Hey, your BAG's full.' and keeps the balls",
    ("data/maps/ThreeIsland_BerryForest_Frlg/scripts.inc", "ThreeIsland_BerryForest_EventScript_Lostelle", "giveitem", "ITEM_IAPAPA_BERRY"):
        "vanilla FRLG: 'Your BERRY POUCH is full. I guess you don't want this.'",
    ("data/maps/Route123_BerryMastersHouse/scripts.inc", "Route123_BerryMastersHouse_EventScript_BerryMaster", "giverandomberry", "BERRY_ID_POMEG"):
        "vanilla: the daily flag covers the first berry, which was given; a full bag on the bonus berry says so",
    ("data/maps/BattleFrontier_BattlePyramidLobby/scripts.inc", "BattleFrontier_BattlePyramidLobby_EventScript_StoreHeldItemsInPyramidBag", "special", "TryStoreHeldItemsInPyramidBag"):
        "vanilla: a full Pyramid Bag sends the player to the keep-or-toss menu",
    ("data/scripts/mauville_man.inc", "MauvilleCity_PokemonCenter_1F_EventScript_PickDecorToGive", "special", "TraderDoDecorationTrade"):
        "vanilla: IsDecorationCategoryFull is tested first",
    # The check and the charge both switch on the drink the player chose (VAR_TEMP_1), so each
    # charge only meets its own check; the path union this audit sees mixes the three prices.
    ("data/maps/LilycoveCity_DepartmentStoreRooftop/scripts.inc", "LilycoveCity_DepartmentStoreRooftop_EventScript_RemoveMoneyFreshWater", "removemoney", "200"):
        "check and charge are both keyed on VAR_TEMP_1 == 0 (200)",
    ("data/maps/LilycoveCity_DepartmentStoreRooftop/scripts.inc", "LilycoveCity_DepartmentStoreRooftop_EventScript_RemoveMoneySodaPop", "removemoney", "300"):
        "check and charge are both keyed on VAR_TEMP_1 == 1 (300)",
    ("data/maps/CeladonCity_DepartmentStore_Roof_Frlg/scripts.inc", "CeladonCity_DepartmentStore_Roof_EventScript_RemoveMoneyFreshWater", "removemoney", "200"):
        "check and charge are both keyed on VAR_TEMP_1 == 0 (200)",
    ("data/maps/CeladonCity_DepartmentStore_Roof_Frlg/scripts.inc", "CeladonCity_DepartmentStore_Roof_EventScript_RemoveMoneySodaPop", "removemoney", "300"):
        "check and charge are both keyed on VAR_TEMP_1 == 1 (300)",
    ("data/maps/CeladonCity_DepartmentStore_Roof_Frlg/scripts.inc", "CeladonCity_DepartmentStore_Roof_EventScript_RemoveMoneyLemonade", "removemoney", "350"):
        "check and charge are both keyed on VAR_TEMP_1 == 2 (350)",
    ("data/maps/Gate_Route43/scripts.inc", "Gate_Route43_Rocket_EventScript_ShakedownBroke", "removemoney", "500"):
        "HGSS shakedown: a player short of the toll hands over all they have (RemoveMoney floors at 0); Route43Toll.lua covers it",
    # Deferred: the reward waits for the player.
    ("data/maps/Route110_TrickHouseEnd/scripts.inc", "Route110_TrickHouseEnd_EventScript_CompletedPuzzle1", "giveitem", "ITEM_RARE_CANDY"):
        "BagFull sets VAR_TRICK_HOUSE_PRIZE_PICKUP; the entrance hands the prize over later",
    ("data/maps/Route110_TrickHouseEnd/scripts.inc", "Route110_TrickHouseEnd_EventScript_CompletedPuzzle2", "giveitem", "ITEM_TIMER_BALL"):
        "BagFull sets VAR_TRICK_HOUSE_PRIZE_PICKUP; the entrance hands the prize over later",
    ("data/maps/Route110_TrickHouseEnd/scripts.inc", "Route110_TrickHouseEnd_EventScript_CompletedPuzzle3", "giveitem", "ITEM_HARD_STONE"):
        "BagFull sets VAR_TRICK_HOUSE_PRIZE_PICKUP; the entrance hands the prize over later",
    ("data/maps/Route110_TrickHouseEnd/scripts.inc", "Route110_TrickHouseEnd_EventScript_CompletedPuzzle4", "giveitem", "ITEM_SMOKE_BALL"):
        "BagFull sets VAR_TRICK_HOUSE_PRIZE_PICKUP; the entrance hands the prize over later",
    ("data/maps/Route110_TrickHouseEnd/scripts.inc", "Route110_TrickHouseEnd_EventScript_CompletedPuzzle6", "giveitem", "ITEM_MAGNET"):
        "BagFull sets VAR_TRICK_HOUSE_PRIZE_PICKUP; the entrance hands the prize over later",
    ("data/maps/Route110_TrickHouseEnd/scripts.inc", "Route110_TrickHouseEnd_EventScript_CompletedPuzzle7", "giveitem", "ITEM_PP_MAX"):
        "BagFull sets VAR_TRICK_HOUSE_PRIZE_PICKUP; the entrance hands the prize over later",
    ("data/maps/Route110_TrickHouseEnd/scripts.inc", "Route110_TrickHouseEnd_EventScript_GiveRedTent", "givedecoration", "DECOR_RED_TENT"):
        "NoRoomForTent sets VAR_TRICK_HOUSE_PRIZE_PICKUP; the entrance offers the tent again",
    ("data/maps/Route110_TrickHouseEnd/scripts.inc", "Route110_TrickHouseEnd_EventScript_GiveBlueTent", "givedecoration", "DECOR_BLUE_TENT"):
        "NoRoomForTent sets VAR_TRICK_HOUSE_PRIZE_PICKUP; the entrance offers the tent again",
    ("data/maps/TwoIsland_JoyfulGameCorner_Frlg/scripts.inc", "TwoIsland_JoyfulGameCorner_EventScript_GiveDaddyMeteorite", "removeitem", "ITEM_METEORITE"):
        "NoRoomForMoonStone sets FLAG_NO_ROOM_FOR_JOYFUL_GAME_CORNER_MOON_STONE and the Moon Stone is handed over later",
    ("data/maps/CeladonCity_DepartmentStore_Roof_Frlg/scripts.inc", "CeladonCity_DepartmentStore_Roof_EventScript_GiveDrink", "removeitem", "VAR_0x8008"):
        "the rewards are TM16, TM20 and TM33, and the TM pocket cannot fill",
    ("data/maps/RuinsOfAlph_Lab/scripts.inc", "RuinsOfAlph_Lab_EventScript_GiveEarlyKabuto", "givemon", "SPECIES_KABUTO"):
        "subroutine; ReceiveKabuto tests MON_GIVEN_TO_PARTY and MON_GIVEN_TO_PC after the call and falls to NoMoreRoomForPokemon",
    # C specials, read by hand.
    ("data/maps/MauvilleCity_GameCorner/scripts.inc", "MauvilleCity_GameCorner_EventScript_BuyCoins", "special", "BuyGameCornerCoins"):
        "charges only for the coins that fit and refuses when short (src/coins.c); EconomyStress.lua covers it",
    ("data/maps/CeladonCity_GameCorner_Frlg/scripts.inc", "CeladonCity_GameCorner_EventScript_DoBuyCoins", "special", "BuyGameCornerCoins"):
        "same BuyGameCornerCoins as Mauville",
    ("data/maps/PalletTown_RivalsHouse_Frlg/scripts.inc", "PalletTown_RivalsHouse_EventScript_GroomMon", "special", "DaisyMassageServices"):
        "free: raises friendship and resets the cooldown, gives and charges nothing",
    ("data/maps/FiveIsland_ResortGorgeous_House_Frlg/scripts.inc", "FiveIsland_ResortGorgeous_House_EventScript_RequestMon", "special", "SampleResortGorgeousMonAndReward"):
        "only picks the wish and the reward; the reward goes through a tested giveitem",
    ("data/maps/FiveIsland_ResortGorgeous_House_Frlg/scripts.inc", "FiveIsland_ResortGorgeous_House_EventScript_ShowRequestedMon", "special", "SampleResortGorgeousMonAndReward"):
        "only picks the wish and the reward; the reward goes through a tested giveitem",
    ("data/maps/RegionHub_2F/scripts.inc", "BattleNet_EventScript_VendorBuy", "special", "DeductBattleNetShards"):
        "checkitemspace for the stone runs before the shards are taken",
    ("data/maps/RegionHub_2F/scripts.inc", "BattleNet_EventScript_BpClerkLoop", "special", "TryBuyBattleNetShard"):
        "checkitemspace for the shard runs before the BP is taken",
    ("data/scripts/battle_net.inc", "BattleNet_EventScript_OnLeaderRematchWin", "special", "TryBattleNetRematchReward"):
        "shards are checkitemspace-guarded and forfeited with a message; stones stay pending until ClaimBattleNetStone",
    ("data/scripts/battle_net.inc", "BattleNet_EventScript_TryStone", "special", "ClaimBattleNetStone"):
        "runs only after a successful giveitem",
    ("data/scripts/battle_net.inc", "BattleNet_EventScript_TryStone2", "special", "ClaimBattleNetStone"):
        "runs only after a successful giveitem",
    ("data/scripts/battle_net.inc", "BattleNet_EventScript_ScalingShardRoll", "special", "GiveBattleNetRandomShard"):
        "only picks the shard; checkitemspace guards the giveitem and the forfeit says so",
    ("data/scripts/bug_contest.inc", "BugContest_EventScript_TransferKeep", "special", "TransferBugContestMon"):
        "the judging opens a make-room PC when the boxes are full; BugContestFullPC.lua covers it",
    ("data/scripts/lilycove_lady.inc", "LilycoveCity_PokemonCenter_1F_EventScript_FavorLadyPrize", "specialvar", "FavorLadyGetPrize"):
        "vanilla: picks the prize; the giveitem after it is tested",
    ("data/scripts/lilycove_lady.inc", "LilycoveCity_PokemonCenter_1F_EventScript_NoSpaceForQuizPrize", "special", "SetQuizLadyState_GivePrize"):
        "vanilla: a full bag puts the Quiz Lady back in her prize state so she gives it later",
    ("data/scripts/lilycove_lady.inc", "LilycoveCity_PokemonCenter_1F_EventScript_FinishMakingQuiz", "special", "QuizLadyTakePrizeForCustomQuiz"):
        "vanilla: takes the prize item the player chose from the bag for their own quiz",
    ("data/scripts/berry_tree.inc", "BerryTree_EventScript_PickBerry", "special", "ObjectEventInteractionPickBerryTree"):
        "AddBagItem's result comes back in VAR_0x8004 and BERRY_NORMAL_BAG_FULL is tested",
    ("data/scripts/apricorn_tree.inc", "ApricornTree_EventScript_PickApricorn", "special", "ObjectEventInteractionPickApricornTree"):
        "APRICORN_TREE_COUNT is 0 and no map places ApricornTreeScript",
    ("data/scripts/bug_contest.inc", "BugContest_EventScript_End", "special", "RemoveSafariBalls"):
        "takes back the contest's Park Balls",
    ("data/scripts/special_pokemon.inc", "SpecialPokemon_EventScript_GiftAnswer", "special", "SpecialPokemon_Give"):
        "refuses with 'no more room' when party and boxes are full; SpecialPokemonStorageStress.lua covers it",
}


def referenced_names(prog):
    """Every identifier something outside a label definition mentions."""
    names = set()
    for ins in prog:
        for a in ins.args:
            names.update(re.findall(r"[A-Za-z_][A-Za-z0-9_]*", a))
    for base, exts in (("data/maps", (".json",)), ("src", (".c", ".h")), ("include", (".h",))):
        for dirpath, _, files in os.walk(os.path.join(ROOT, base)):
            for fn in files:
                if fn.endswith(exts):
                    with open(os.path.join(dirpath, fn), encoding="utf-8", errors="replace") as fh:
                        text = fh.read()
                    names.update(re.findall(r"[A-Za-z_][A-Za-z0-9_]*_EventScript_[A-Za-z0-9_]*|Debug_[A-Za-z0-9_]+", text))
                    # A map event starts whatever script it names, e.g. MahoganyHideout_B2F_Trigger_Electrode.
                    names.update(re.findall(r'"script"\s*:\s*"(\w+)"', text))
    return names


def entry_labels(prog, preds, i, limit=200):
    """Labels with no script predecessor that can reach prog[i]."""
    seen, out, stack = set(), set(), [i]
    while stack and len(seen) < limit:
        n = stack.pop()
        if n in seen:
            continue
        seen.add(n)
        ps = preds.get(n, [])
        if not ps:
            out.update(prog[n].labels or [prog[n].label])
        stack.extend(ps)
    return out


def classify(prog, preds, labels):
    safe_pockets, pockets = pocket_cannot_fill()
    refs = referenced_names(prog)
    rows = []

    def add(ins, kind, status, why):
        if status == "UNGUARDED":
            entries = entry_labels(prog, preds, ins.idx)
            if entries and not any(e in refs for e in entries):
                status, why = "unreachable", "no map, script or C code starts %s" % ", ".join(sorted(entries))
            elif entries and all(e.startswith("Debug_") for e in entries if e in refs):
                status, why = "debug-only", "reached only from the debug menu"
        rows.append((ins, kind, status, why))

    for i, ins in enumerate(prog):
        op = ins.op
        arg0 = ins.args[0] if ins.args else ""
        if op in MON_OPS:
            conds = forward_conds(prog, i)
            cant = [c for c in conds if tests_value(c, "MON_CANT_GIVE", "2")]
            party = [c for c in conds if tests_value(c, "MON_GIVEN_TO_PARTY", "0") and c.op.startswith("goto")]
            pc = [c for c in conds if tests_value(c, "MON_GIVEN_TO_PC", "1") and c.op.startswith("goto")]
            if op in PARTY_ONLY_OPS and any(c.args and c.args[-1] == BOXES_FULL_SCRIPT for c in cant):
                add(ins, "mon", "UNGUARDED", "fills the party only but answers MON_CANT_GIVE with %s, "
                    "which says the boxes are full" % BOXES_FULL_SCRIPT)
                continue
            if op == "givemon" and any(splits(c) for c in cant) \
                    and not any(tests_value(c, "MON_GIVEN_TO_PC", "1") for c in conds) \
                    and not reaches_box_notice(prog, i):
                add(ins, "mon", "UNGUARDED", "a full party sends it to a box and nothing says so: test "
                    "MON_GIVEN_TO_PC or call %s" % BOX_RECEIPT_SCRIPT)
                continue
            if any(splits(c) for c in cant) or (party and pc):
                add(ins, "mon", "guarded", "result tested for MON_CANT_GIVE")
                continue
            ok, entry = all_paths_guarded(prog, preds, i, MON_GUARDS)
            if ok:
                add(ins, "mon", "guarded", "party size checked on every path in")
                continue
            why = "result never tested for MON_CANT_GIVE" if not conds else "tests %s but not MON_CANT_GIVE" % ", ".join(sorted({c.args[-2] if len(c.args) > 1 else c.args[0] for c in conds}))
            add(ins, "mon", "UNGUARDED", why + "; reachable unguarded from %s" % entry.label)
        elif op in ITEM_POST_OPS or op in ITEM_PRE_OPS or op == "giverandomberry":
            item = ins.args[1] if op in ITEM_PRE_OPS and len(ins.args) > 1 else arg0
            pocket = pockets.get(item)
            post = forward_conds(prog, i) if op in ITEM_POST_OPS or op == "giverandomberry" else []
            if any(splits(c) for c in post):
                add(ins, "item", "guarded", "result tested")
                continue
            guards = {"checkdecorspace"} if op in ("givedecoration", "adddecoration") else {"checkitemspace", "checkpcspace"}
            if pocket == "POCKET_BERRIES":
                guards = guards | {"PlayerHasBerries"}
            ok, entry = all_paths_guarded(prog, preds, i, guards, item)
            if ok:
                add(ins, "item", "guarded", "%s on every path in" % "/".join(sorted(guards)))
                continue
            if op in ("givedecoration", "adddecoration", "addpcitem"):
                pass
            elif pocket in safe_pockets:
                add(ins, "item", "safe-capacity", "%s: %s" % (pocket, safe_pockets[pocket]))
                continue
            if op == "msgreceiveditem" and i and prog[i - 1].op == "additem":
                continue
            if post:
                why = "result tested only by %s, which comes back and carries on" % post[0].text()
            elif op in ITEM_PRE_OPS:
                why = "prints received with no room check"
            else:
                why = "result never tested"
            add(ins, "item", "UNGUARDED", "%s (%s); reachable from %s" % (why, pocket or "item in a var", entry.label))
        elif op == "finditem":
            j = i + 1
            nxt = prog[j] if j < len(prog) else None
            tail = []
            while nxt is not None and nxt.file == ins.file and nxt.op not in TERMINATORS and len(tail) < 6:
                tail.append(nxt)
                j += 1
                nxt = prog[j] if j < len(prog) else None
            changes = [t for t in tail if t.op in ("setflag", "setvar", "addvar", "clearflag", "removeobject", "giveitem", "additem", "removeitem", "removemoney", "setobjectmovementtype")]
            if changes and not forward_conds(prog, i):
                add(ins, "item", "UNGUARDED", "finditem then %s without testing VAR_RESULT" % changes[0].text())
            else:
                add(ins, "item", "guarded", "finditem handles a full bag")
        elif op in MONEY_OPS:
            ok, entry = all_paths_guarded(prog, preds, i, {"checkmoney", "IsEnoughForCostInVar0x8005"})
            checked = checked_amounts(prog, preds, i)
            if ok and checked and checked != {arg0}:
                add(ins, "money", "UNGUARDED", "charges %s but checks %s" % (arg0, ", ".join(sorted(checked))))
            elif ok:
                add(ins, "money", "guarded", "checkmoney on every path in")
            else:
                add(ins, "money", "UNGUARDED", "charge with no checkmoney on the path from %s" % entry.label)
        elif op in COIN_OPS:
            if op == "removecoins" and any(splits(c) for c in forward_conds(prog, i)):
                add(ins, "coins", "guarded", "result tested")
                continue
            guards = {"checkcoins"} if op == "removecoins" else {"checkcoins", "CheckAddCoins"}
            ok, entry = all_paths_guarded(prog, preds, i, guards)
            if ok:
                add(ins, "coins", "guarded", "coin count checked on every path in")
            else:
                add(ins, "coins", "UNGUARDED", "%s with no coin check on the path from %s" % (op, entry.label))
        elif op in ("special", "specialvar"):
            name = ins.args[-1] if ins.args else ""
            if name == "SubtractMoneyFromVar0x8005":
                ok, entry = all_paths_guarded(prog, preds, i, {"IsEnoughForCostInVar0x8005", "checkmoney"})
                if ok:
                    add(ins, "money", "guarded", "IsEnoughForCostInVar0x8005 on every path in")
                else:
                    add(ins, "money", "UNGUARDED", "SubtractMoneyFromVar0x8005 with no cost check from %s" % entry.label)
            elif name in PARTY_SPECIALS:
                ok, entry = all_paths_guarded(prog, preds, i, MON_GUARDS)
                if ok:
                    add(ins, "mon", "guarded", "party size checked on every path in")
                else:
                    add(ins, "mon", "UNGUARDED", "%s with no party-size check from %s" % (name, entry.label))
            elif name in STORAGE_SPECIALS:
                ok, entry = all_paths_guarded(prog, preds, i, STORAGE_GUARDS)
                if ok:
                    add(ins, "mon", "guarded", "room checked on every path in")
                else:
                    add(ins, "mon", "UNGUARDED", "%s gives in C with no room check from %s" % (name, entry.label))
            elif name in SPECIAL_SITES or name in AUTO_SPECIALS:
                add(ins, "special", "REVIEW", "C special %s: review by hand" % name)

    # a gift that can fail must not commit the "already given" state before it runs
    status_of = {}
    for ins, kind, status, why in rows:
        status_of[ins.idx] = status
    for i, ins in enumerate(prog):
        if ins.op not in GIVE_OPS or status_of.get(i) == "safe-capacity":
            continue
        if ins.op in ITEM_POST_OPS | ITEM_PRE_OPS:
            item = ins.args[1] if ins.op in ITEM_PRE_OPS and len(ins.args) > 1 else (ins.args[0] if ins.args else "")
            if pockets.get(item) in safe_pockets:
                continue
            guards = {"checkdecorspace"} if "decoration" in ins.op else {"checkitemspace", "checkpcspace"}
        else:
            item, guards = None, MON_GUARDS
        if all_paths_guarded(prog, preds, i, guards, item)[0]:
            continue
        j, steps = i, 0
        while steps < 10:
            ps = preds.get(j, [])
            if len(ps) != 1 or ps[0] != j - 1:
                break
            j = ps[0]
            q = prog[j]
            steps += 1
            if guard_ok(prog, j, guards, item):
                break
            if q.op in ("setflag", "setvar") and q.args and re.search(r"RECEIVED|_GOT_|GIFT|_STATE|HIDE", q.args[0]) and "TEMP" not in q.args[0]:
                add(ins, "commit", "UNGUARDED", "%s at line %d runs before %s can fail" % (q.text(), q.line, ins.op))
                break
            if q.op == "removeobject" and q.args and q.args[0] == "VAR_LAST_TALKED":
                add(ins, "commit", "UNGUARDED", "%s at line %d runs before %s can fail" % (q.text(), q.line, ins.op))
                break

    # a sink that flows into a gift must have checked room before it charged
    for i, ins in enumerate(prog):
        is_sink = ins.op in ("removemoney", "removecoins", "removeitem") or (ins.op == "special" and ins.args and ins.args[0] == "SubtractMoneyFromVar0x8005")
        if not is_sink:
            continue
        j, steps = i + 1, 0
        while j < len(prog) and steps < 25 and prog[j].file == ins.file:
            g = prog[j]
            if is_data(g):
                break
            if g.op in GIVE_OPS:
                guards = MON_GUARDS if g.op in MON_OPS else ({"checkdecorspace"} if "decoration" in g.op else {"checkitemspace", "checkpcspace"})
                item = None if g.op in MON_OPS else (g.args[0] if g.args else None)
                ok, entry = all_paths_guarded(prog, preds, i, guards, item)
                if not ok:
                    if g.op not in MON_OPS and pockets.get(item) in safe_pockets:
                        break
                    add(ins, "charge", "UNGUARDED", "charges before checking room for %s at line %d" % (g.text(), g.line))
                break
            if g.op in TERMINATORS:
                if g.op == "goto" and g.args and g.args[0] in labels:
                    j = labels[g.args[0]]
                    steps += 1
                    continue
                break
            j += 1
            steps += 1
    return rows


LABELS = {}
PREDS = {}
AUTO_SPECIALS = set()
PROG = []


def main():
    global LABELS, PREDS, PROG, AUTO_SPECIALS
    AUTO_SPECIALS = specials_that_give() - PARTY_SPECIALS - {"SubtractMoneyFromVar0x8005"}
    show_all = "--all" in sys.argv
    prog, labels = parse()
    LABELS = labels
    PROG = prog
    preds = build_preds(prog, labels)
    PREDS = preds
    rows = classify(prog, preds, labels)
    counts = defaultdict(int)
    bad, allowed = [], []
    for ins, kind, status, why in rows:
        key = (ins.file, ins.label, ins.op, ins.args[0] if ins.args else "")
        if ins.op in ("special", "specialvar"):
            key = (ins.file, ins.label, ins.op, ins.args[-1] if ins.args else "")
        counts[(kind, "sites")] += 1
        if status in ("UNGUARDED", "REVIEW"):
            if key in ALLOWLIST:
                allowed.append((ins, kind, ALLOWLIST[key]))
                counts[(kind, "allowlisted")] += 1
            else:
                bad.append((ins, kind, status, why))
                counts[(kind, "unguarded")] += 1
        else:
            counts[(kind, status)] += 1
            if status in ("unreachable", "debug-only"):
                counts[(kind, "dead")] += 1
        if show_all:
            print("%-8s %-13s %-60s %s | %s" % (kind, status, ins.where(), ins.text(), why))
    used = {(i.file, i.label, i.op, (i.args[-1] if i.op in ("special", "specialvar") else (i.args[0] if i.args else ""))) for i, _, _ in allowed}
    stale = [k for k in ALLOWLIST if k not in used]

    print("Unguarded sites")
    print("| site | label | kind | op | why |")
    print("|---|---|---|---|---|")
    for ins, kind, status, why in bad:
        print("| %s | %s | %s | `%s` | %s |" % (ins.where(), ins.label, kind, ins.text(), why))
    if allowed and "--quiet" not in sys.argv:
        print()
        print("Allowlisted (checked by hand)")
        for ins, kind, why in allowed:
            print("  %s %s `%s`: %s" % (ins.where(), ins.label, ins.text(), why))
    print()
    kinds = sorted({k for k, _ in counts})
    total = sum(v for (k, s), v in counts.items() if s == "sites")
    print("Scanned %d sites in %d script files." % (total, len({i.file for i in prog})))
    for k in kinds:
        print("  %-8s sites %4d  guarded %4d  safe-capacity %3d  dead %2d  allowlisted %3d  unguarded %3d" % (
            k, counts[(k, "sites")], counts[(k, "guarded")], counts[(k, "safe-capacity")],
            counts[(k, "dead")], counts[(k, "allowlisted")], counts[(k, "unguarded")]))
    if stale:
        print("Stale allowlist entries (no longer match a flagged site):")
        for k in stale:
            print("  %s" % (k,))
    return 1 if bad or stale else 0


if __name__ == "__main__":
    sys.exit(main())
