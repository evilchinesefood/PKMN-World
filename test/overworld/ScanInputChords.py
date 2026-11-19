#!/usr/bin/env python3
"""List input handlers where two buttons pressed on one frame can both act.

A handler shaped like

    if (JOY_NEW(A_BUTTON)) { gTasks[taskId].func = Task_Next; BeginNormalPaletteFade(...); }
    if (JOY_NEW(B_BUTTON)) { gTasks[taskId].func = Task_Close; }

runs both branches when A and B land on the same frame, so the second undoes or overrides the
state change the first just made (PR #486: a black screen with an invisible list still taking
input). For every branch taken on a button (an `if` or a `switch` case) that changes state on a
path that does not return, this follows the code that can still run on that frame (later
siblings, then the code after each enclosing block, through `break` out of a switch) and reports
each later button read. A button read is a JOY_ or gMain key test, or a call to a function that
makes one (ListMenu_ProcessInput); a state change is a task func, main callback, fade, destroyed
menu or window, or a state variable write, made directly or by a helper up to two calls deep.

It is a token-level reader, not a C compiler. `#if` on a config flag every header defines TRUE or
FALSE keeps the arm the build compiles; any other `#if` keeps its first arm. Macros that hide
control flow are invisible. Each row is a candidate to read, not a verdict.

    python3 test/overworld/ScanInputChords.py            # every conflict
    python3 test/overworld/ScanInputChords.py --all      # also pairs whose second branch changes nothing
    python3 test/overworld/ScanInputChords.py --check    # fail on a conflict not in the allowlist

A conflict is a pair where both branches change state. The allowlist
(reference/input_chord_allowlist.tsv) keys a site by file, function and the two button sets (`*` for
any), so it survives line drift; every row carries the reason it is safe. A row that matches
nothing is reported as stale but does not fail the check.
"""

import argparse
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent
ALLOWLIST = Path(__file__).resolve().parent / "reference/input_chord_allowlist.tsv"

TOKEN = re.compile(r"[A-Za-z_]\w*|\d[\w.]*|->|\+\+|--|<<=|>>=|&&|\|\||<<|>>|[-+*/%&|^!=<>]=|\S")
INPUT = re.compile(r"\bJOY_(?:NEW|REPEAT|HELD|NEW_AND_REPEATED|HELD_RAW|NEW_RAW)\b"
                   r"|\bgMain \. (?:newKeys|newAndRepeatedKeys|heldKeys)\b")
BUTTON = re.compile(r"\b(A_BUTTON|B_BUTTON|START_BUTTON|SELECT_BUTTON|L_BUTTON|R_BUTTON"
                    r"|DPAD_(?:UP|DOWN|LEFT|RIGHT|ANY)|[A-Z_]*BUTTON[A-Z_]*)\b")
EFFECTS = {
    "FUNC": re.compile(r"(?:\.|->) func =(?!=)|\bSetTaskFuncWithFollowupFunc\b|\bSwitchTaskToFollowupFunc\b"),
    "CB": re.compile(r"\bSetMainCallback2\b|\bgMain \. callback[12] =(?!=)|\bgFieldCallback2? =(?!=)"
                     r"|\b(?:state|menu) -> callback =(?!=)"),
    "FADE": re.compile(r"\bBegin\w*PaletteFade\b|\bFadeScreen\b|\bBeginFastPaletteFade\b"),
    "DESTROY": re.compile(r"\bDestroyTask\b|\bDestroy\w*Menu\w*\b|\bRemoveWindow\b|\bFreeAllWindowBuffers\b"
                          r"|\bClearStdWindowAndFrame\w*\b|\bScriptContext_Enable\b"),
    "STATE": re.compile(r"\b\w*(?:[Ss]tate|[Ss]tep)\w* (?:=(?!=)|\+\+|--|\+=|-=)|(?:\+\+|--) \w*(?:[Ss]tate|[Ss]tep)\b"
                        r"|\bdata \[ 0 \] (?:=(?!=)|\+\+|--|\+=)|(?:\+\+|--) \w+ \[ \w+ \] \. data \[ 0 \]"),
}


def config_flags():
    """Macros every header defines to the same TRUE or FALSE, so `#if SWSH_ITEM_MENU` can be decided."""
    seen = {}
    for header in (ROOT / "include").rglob("*.h"):
        for m in re.finditer(r"^\s*#\s*define\s+([A-Z_][A-Z0-9_]*)\s+(TRUE|FALSE)\b",
                             header.read_text(errors="replace"), re.M):
            seen.setdefault(m[1], set()).add(m[2] == "TRUE")
    return {name: values.pop() for name, values in seen.items() if len(values) == 1}


FLAGS = config_flags()


def decide(expr):
    """True or False for `#if [!]FLAG` on a known config flag, None for anything else."""
    m = re.fullmatch(r"\s*(!?)\s*\(?\s*([A-Z_][A-Z0-9_]*)\s*\)?\s*", expr)
    if not m or m[2] not in FLAGS:
        return None
    return FLAGS[m[2]] != (m[1] == "!")


def preprocess(src):
    """Blank comments and literals and keep line numbers. A #if on a known config flag keeps the
    arm the build compiles; any other #if keeps its first arm only."""
    src = re.sub(r'/\*.*?\*/|//[^\n]*|"(?:\\.|[^"\\\n])*"|\'(?:\\.|[^\'\\\n])*\'',
                 lambda m: re.sub(r"[^\n]", " ", m.group()), src, flags=re.S)
    out, stack, cont = [], [], False
    for line in src.split("\n"):
        directive = line.strip()
        if cont or directive.startswith("#"):
            m = re.match(r"#\s*(\w+)(.*)", directive)
            word, rest = (m[1], m[2]) if m and not cont else ("", "")
            if word in ("if", "ifdef", "ifndef"):
                v = decide(rest) if word == "if" else None
                stack.append([v is not False, v is not False])
            elif word == "elif" and stack:
                v = None if stack[-1][1] else decide(rest)
                stack[-1] = [False, True] if stack[-1][1] else [v is not False, v is not False]
            elif word == "else" and stack:
                stack[-1] = [not stack[-1][1], True]
            elif word == "endif" and stack:
                stack.pop()
            cont = line.rstrip().endswith("\\")
            out.append("")
        else:
            out.append(line if all(active for active, _ in stack) else "")
    return "\n".join(out)


class Node:
    def __init__(self, kind, line, parent=None):
        self.kind, self.line, self.parent = kind, line, parent
        self.stmts, self.branches, self.body, self.text = [], [], None, ""


class Parser:
    def __init__(self, toks):
        self.toks, self.i = toks, 0

    def tok(self, k=0):
        j = self.i + k
        return self.toks[j][0] if j < len(self.toks) else ""

    def line(self):
        return self.toks[min(self.i, len(self.toks) - 1)][1]

    def balanced(self, open_, close):
        start, depth = self.i, 0
        while self.i < len(self.toks):
            t = self.tok()
            depth += (t == open_) - (t == close)
            self.i += 1
            if depth == 0:
                break
        return " ".join(t for t, _ in self.toks[start:self.i])

    def block(self, parent):
        node = Node("block", self.line(), parent)
        self.i += 1
        while self.i < len(self.toks) and self.tok() != "}":
            node.stmts.append(self.statement(node))
        self.i += 1
        return node

    def statement(self, parent):
        t, line = self.tok(), self.line()
        if t == "{":
            return self.block(parent)
        if t == "if":
            node = Node("if", line, parent)
            while True:
                self.i += 1
                cond_line = self.line()
                cond = self.balanced("(", ")")
                node.branches.append((cond, cond_line, self.statement(node)))
                if self.tok() == "else" and self.tok(1) == "if":
                    self.i += 1
                    continue
                if self.tok() == "else":
                    self.i += 1
                    node.branches.append((None, self.line(), self.statement(node)))
                return node
        if t in ("while", "for", "switch"):
            node = Node(t, line, parent)
            self.i += 1
            node.text = self.balanced("(", ")")
            node.body = self.statement(node)
            return node
        if t == "do":
            node = Node("do", line, parent)
            self.i += 1
            node.body = self.statement(node)
            if self.tok() == "while":
                self.i += 1
                self.balanced("(", ")")
            if self.tok() == ";":
                self.i += 1
            return node
        if t in ("case", "default") or (re.match(r"[A-Za-z_]\w*$", t) and self.tok(1) == ":"):
            while self.i < len(self.toks) and self.tok() != ":":
                self.i += 1
            self.i += 1
            return Node("label", line, parent)
        if t in ("return", "break", "continue", "goto"):
            node = Node(t, line, parent)
            while self.i < len(self.toks) and self.tok() != ";":
                self.i += 1
            self.i += 1
            return node
        node, start, depth = Node("expr", line, parent), self.i, 0
        while self.i < len(self.toks):
            t = self.tok()
            if depth == 0 and t in (";", "}"):
                break
            if depth == 0 and t == "{" and self.i > start and self.toks[self.i - 1][0] == ")":
                node.kind, node.text = "macro", " ".join(x for x, _ in self.toks[start:self.i])
                node.body = self.block(node)
                return node
            depth += (t in "([{") - (t in ")]}")
            self.i += 1
        node.text = " ".join(x for x, _ in self.toks[start:self.i])
        if self.tok() == ";":
            self.i += 1
        return node


def functions(text):
    """Yield (name, body Node) for each function definition in a preprocessed file."""
    toks, line, pos = [], 1, 0
    for m in TOKEN.finditer(text):
        line += text.count("\n", pos, m.start())
        pos = m.start()
        toks.append((m.group(), line))
    i, depth = 0, 0
    while i < len(toks):
        t = toks[i][0]
        if t == "{" and depth == 0 and i and toks[i - 1][0] == ")":
            j, d = i - 1, 0
            while j >= 0:
                d += (toks[j][0] == ")") - (toks[j][0] == "(")
                if d == 0:
                    break
                j -= 1
            name = toks[j - 1][0] if j > 0 else "?"
            p = Parser(toks)
            p.i = i
            body = p.block(None)
            yield name, body
            i = p.i
            continue
        depth += (t == "{") - (t == "}")
        i += 1


def subtree(node):
    yield node
    for _, _, s in node.branches:
        yield from subtree(s)
    for s in node.stmts:
        yield from subtree(s)
    if node.body:
        yield from subtree(node.body)


def text_of(node):
    parts = []
    for n in subtree(node):
        parts.append(n.text)
        parts.extend(c for c, _, _ in n.branches if c)
    return " ".join(parts)


def exits(node):
    """How control unconditionally leaves this statement: 'return', 'break', 'continue', 'goto' or None."""
    if node.kind in ("return", "break", "continue", "goto"):
        return node.kind
    if node.kind == "block":
        for s in node.stmts:
            e = exits(s)
            if e:
                return e
        return None
    if node.kind == "if" and node.branches[-1][0] is None:
        kinds = {exits(s) for _, _, s in node.branches}
        if None in kinds:
            return None
        return "break" if "break" in kinds or "continue" in kinds else kinds.pop()
    return None


def breakable(node):
    while node.parent is not None:
        node = node.parent
        if node.kind in ("switch", "while", "for", "do", "macro"):
            return node
    return None


def continuation(node):
    """Statements that can still run, in order, after `node` completes and falls through."""
    out, cur = [], node
    while cur.parent is not None:
        p = cur.parent
        if p.kind != "block":
            cur = p
            continue
        jumped = None
        for s in p.stmts[p.stmts.index(cur) + 1:]:
            out.append(s)
            e = exits(s)
            if e in ("return", "goto", "continue"):
                return out
            if e == "break":
                jumped = breakable(s)
                if jumped is None:
                    return out
                break
        cur = jumped or p
    return out


def buttons(text):
    return "|".join(sorted(set(BUTTON.findall(text)))) or "?"


CALL = re.compile(r"\b([A-Za-z_]\w*) \(")
_parsed, _summary = {}, None


def parse(path):
    if path not in _parsed:
        _parsed[path] = list(functions(preprocess(path.read_text(errors="replace"))))
    return _parsed[path]


def summary():
    """Per function in src/: the effects it makes directly, and whether it reads buttons directly.

    Effects reach two calls deep (DisplayItemMessage -> DisplayMessageAndContinueTask swaps the
    task func); button reads one. STATE is left out of helpers: nearly every one writes a field."""
    global _summary
    if _summary is None:
        direct, calls, readers = {}, {}, set()
        for path in sorted((ROOT / "src").glob("*.c")):
            for fname, body in parse(path):
                text = text_of(body)
                direct.setdefault(fname, set()).update(
                    k for k, rx in EFFECTS.items() if k != "STATE" and rx.search(text))
                calls.setdefault(fname, set()).update(CALL.findall(text))
                if INPUT.search(text):
                    readers.add(fname)
        effects_of = {f: direct[f].union(*(direct.get(g, set()) for g in calls[f])) for f in direct}
        _summary = ({f: e for f, e in effects_of.items() if e}, readers)
    return _summary


def reads_input(text):
    """The button test in `text`, or None: a JOY_ or gMain key read, or a call to a helper that makes one."""
    if not text:
        return None
    if INPUT.search(text):
        return buttons(text)
    helpers = [name for name in CALL.findall(text) if name in summary()[1]]
    return helpers[0] + "()" if helpers else None


def live_text(node):
    """The text of the paths through `node` that can fall out of it rather than return."""
    if exits(node) in ("return", "goto", "continue"):
        return ""
    if node.kind == "block":
        parts = []
        for s in node.stmts:
            if exits(s) in ("return", "goto", "continue"):
                break
            parts.append(live_text(s))
        return " ".join(parts)
    if node.kind == "if":
        return " ".join((c or "") + " " + live_text(s) for c, _, s in node.branches)
    if node.kind == "switch":
        parts = [node.text]
        for _, group in case_groups(node):
            ends = next((e for e in map(exits, group) if e), None)
            if ends not in ("return", "goto", "continue"):
                parts.extend(live_text(s) for s in group)
        return " ".join(parts)
    return text_of(node)


def effects(nodes, live=False):
    if not isinstance(nodes, list):
        nodes = [nodes]
    body = " ".join((live_text if live else text_of)(n) for n in nodes)
    found = [k for k, rx in EFFECTS.items() if rx.search(body)]
    effects_of = summary()[0]
    for name in dict.fromkeys(CALL.findall(body)):
        found += [k + "*" for k in sorted(effects_of.get(name, ())) if k not in found and k + "*" not in found]
    return found


def case_groups(switch):
    """A switch body split at its case labels: [(line, [statements])]."""
    groups = []
    for s in switch.body.stmts if switch.body.kind == "block" else []:
        if s.kind == "label":
            groups.append((s.line, []))
        elif groups:
            groups[-1][1].append(s)
    return groups


def first_sites(body):
    """(input text, line, statements, node that ends the branch) for every branch taken on a button."""
    for node in subtree(body):
        if node.kind == "if":
            for cond, line, stmt in node.branches:
                read = reads_input(cond)
                if read:
                    yield read, line, [stmt], node, exits(stmt)
        elif node.kind == "switch":
            read = reads_input(node.text)
            if read:
                for line, group in case_groups(node):
                    e = None
                    for s in group:
                        e = exits(s)
                        if e:
                            break
                    yield read, line, group, node, "fall" if e == "break" else e


def second_sites(later):
    """Each input read that can still run: (input text, line, effects)."""
    for k, s in enumerate(later):
        for n in subtree(s):
            if n.kind == "if":
                for cond, line, stmt in n.branches:
                    read = reads_input(cond)
                    if read:
                        yield read, line, effects(stmt)
            elif n.kind == "switch" and reads_input(n.text):
                yield reads_input(n.text), n.line, effects(n.body)
            elif n.kind == "expr" and reads_input(n.text):
                siblings = n.parent.stmts[n.parent.stmts.index(n):] if n.parent and n.parent.kind == "block" else [n]
                yield reads_input(n.text), n.line, effects(siblings + later[k + 1:])


def scan_file(path):
    rel = str(path.relative_to(ROOT))
    for fname, body in parse(path):
        for read, line, stmts, node, e in first_sites(body):
            first = effects(stmts, live=True)
            if not first or e in ("return", "goto", "continue"):
                continue
            if e == "break":
                b = breakable(stmts[-1]) if stmts else None
                later = continuation(b) if b else []
            else:
                later = continuation(node)
            seen = set()
            for read2, line2, eff2 in second_sites(later):
                if line2 in seen:
                    continue
                seen.add(line2)
                yield {"file": rel, "func": fname, "line": line, "buttons": read, "effects": first,
                       "line2": line2, "buttons2": read2, "effects2": eff2}


def load_allowlist():
    """{(file, function, buttons, buttons2): reason}; `*` in a button column matches any."""
    allowed = {}
    if ALLOWLIST.exists():
        for raw in ALLOWLIST.read_text().splitlines():
            if not raw.strip() or raw.startswith("#"):
                continue
            cols = raw.split("\t")
            if len(cols) < 5 or not cols[4].strip():
                sys.exit(f"{ALLOWLIST.name}: every row needs file, function, buttons, buttons2, reason: {raw!r}")
            allowed[tuple(cols[:4])] = cols[4]
    return allowed


def allowlist_row(r, allowed):
    for key in allowed:
        if key[:2] == (r["file"], r["func"]) and key[2] in ("*", r["buttons"]) and key[3] in ("*", r["buttons2"]):
            return key
    return None


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--check", action="store_true",
                    help="print only the summary and exit 1 on a conflict the allowlist does not name")
    ap.add_argument("--all", action="store_true", help="also list pairs whose second branch changes no state")
    ap.add_argument("files", nargs="*", type=Path, help="limit the scan to these files")
    args = ap.parse_args()

    paths = [p.resolve() for p in args.files] or sorted((ROOT / "src").glob("*.c"))
    allowed = load_allowlist()
    rows = [r for p in paths for r in scan_file(p)]
    conflicts = [r for r in rows if r["effects2"]]
    used, unlisted = set(), []
    table = [] if args.check else ["verdict\tfile:line\tfunction\tfirst\teffects\tlater:line\tsecond\teffects2"]
    for r in rows if args.all else conflicts:
        key = allowlist_row(r, allowed) if r["effects2"] else None
        verdict = "allowed" if key else "conflict" if r["effects2"] else "weak"
        if key:
            used.add(key)
        elif verdict == "conflict":
            unlisted.append(r)
        if not args.check:
            table.append(f"{verdict}\t{r['file']}:{r['line']}\t{r['func']}\t{r['buttons']}\t{','.join(r['effects'])}"
                         f"\t{r['line2']}\t{r['buttons2']}\t{','.join(r['effects2']) or '-'}")
    if table:
        print("\n".join(table))
    sites = {(r["file"], r["func"]) for r in conflicts}
    stale = sorted(set(allowed) - used) if not args.files else []
    print(f"\n{len(rows)} pairs, {len(conflicts)} conflicts in {len(sites)} functions, "
          f"{len(conflicts) - len(unlisted)} allowlisted, {len(unlisted)} not allowlisted", file=sys.stderr)
    # A stale row is a site that no longer conflicts (fixed, or moved). It warns rather than fails,
    # so a fix that lands before or after the row's removal keeps the check green either way.
    for key in stale:
        print("stale allowlist row (remove it): " + "\t".join(key), file=sys.stderr)
    for r in unlisted:
        print(f"NOT ALLOWLISTED: {r['file']}:{r['line']} {r['func']} {r['buttons']} then "
              f"{r['buttons2']} at line {r['line2']}", file=sys.stderr)
    if args.check and unlisted:
        sys.exit(1)


if __name__ == "__main__":
    main()
