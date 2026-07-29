#!/usr/bin/env python3
"""Event-script pointer-argument validator (host-side, no build needed).

The failure this catches (issue #48): `pokemart 0` in VioletCity_Mart/scripts.inc. The macro
emits `.4byte \\products` verbatim, so a literal 0 assembles clean, links clean, and boots clean.
It only surfaces when a player talks to the clerk — `SetShopItemsForSale(NULL)` trips
`assertf(items != NULL)` and blue-screens. No compiler, linker, or battle test can reject it.

Note the scope: an *undefined symbol* in a pointer slot already fails at link time, so a bare
integer literal is the entire silent-failure surface. That is what this scans for.

Run from the repo root: python3 Testing/ValidateScripts.py   (exit 0 = clean, 1 = violations)
or `make validate`. Also run by the .git/hooks/pre-push gate and the Check.yml validate job.

## Why this expands macros instead of hard-coding a command -> argument-index table

A hand-written table rots the moment a macro gains an argument, and it silently gets the hard
cases wrong. `goto_if_eq` is the example: it forwards to `trycompare`, whose pointer slot is the
LAST argument when three are given (`goto_if_eq VAR_X, 5, Label`) but the FIRST when one is
(`goto_if_eq Label`) — the operands in the three-argument form are numbers, legally. `msgbox`
emits nothing itself; it forwards to `loadword`. `applymovement` emits its pointer from inside
two different `.ifb` arms.

So this parses `.macro` blocks out of the event-script macro headers and symbolically expands
each invocation, tracking `.ifb`/`.ifnb` on argument blankness and following macro-to-macro
forwarding. A value is a pointer argument if and only if it reaches a `.4byte`. That derivation
is arity-aware and updates itself when a macro changes.

Slots that are NOT `.4byte` are excluded for free, which is the correct answer for the arguments
a number legitimately belongs in: `multichoice`'s list id, `setvar`/`special`, `addcoins` (a
`.2byte`), and `applymovement`'s first argument (`0` = the player).

`.4byte` does mean "32-bit word", not "pointer", so the money commands land in the same net with
a genuine numeric argument. Those are named in VALUE_SLOTS below and cross-checked against the
tree, so the exemption cannot quietly grow to cover a real pointer slot.

`--report` prints the numeric/symbolic split for every derived slot, which is how to decide
whether a newly-flagged macro is a bug or a value slot that needs classifying.
"""
import os
import re
import sys
from concurrent.futures import ThreadPoolExecutor

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# The macro headers `data/event_scripts.s` includes, in include order. Restricting the macro
# table to these keeps a same-named battle-script macro from being applied to event scripts.
MACRO_FILES = ["asm/macros.inc", "asm/macros/event.inc", "asm/macros/johto_compat.inc"]

SCAN_DIRS = ["data"]          # walked recursively for SCAN_SUFFIX
SCAN_SUFFIX = ".inc"
SCAN_FILES = ["data/event_scripts.s"]

# A parse that finds nothing must fail, not pass. Every check below is a lookup that succeeds
# vacuously against an empty table, so a moved file or a drifted regex would turn this script
# into a no-op that still prints OK. Floors are set well under the real counts.
MIN_MACROS_PARSED = 200
MIN_POINTER_MACROS = 30
MIN_INVOCATIONS = 5000

# (macro, 1-based argument index) that is a 32-bit NUMBER, not a pointer — `.4byte` is a word
# width, not a type. The money commands are the whole set: MAX_MONEY is 999999, which does not
# fit the `.2byte` the rest of the numeric commands use.
#
# Both directions are cross-checked below: an entry naming a slot that no longer exists fails,
# and so does one whose call sites in data/ turn out to be mostly labels. That keeps the
# exemption from silently growing into a blind spot over a real pointer slot.
VALUE_SLOTS = {
    ("addmoney", 1),
    ("removemoney", 1),
    ("checkmoney", 1),
}

# A VALUE_SLOTS entry must look like a value slot in the tree. Below MIN_SAMPLE call sites there
# is no signal either way and the entry is taken on trust.
VALUE_SLOT_MIN_SAMPLE = 5
VALUE_SLOT_MIN_NUMERIC = 0.5

# (macro, 1-based argument index) that is a real pointer slot, but where a literal ZERO is
# meaningful rather than broken. `message` documents it (asm/macros/event.inc): a NULL text
# argument means "the pointer is already in script data bank 0", which is what the caller's
# `loadword 0, <text>` put there. `data/scripts/follower.inc:30` is the live use, and says so.
#
# Deliberately narrower than VALUE_SLOTS: only 0 is waived here, so `message 12345` is still a
# finding, and the 653 label call sites keep their coverage. `pokemart` is NOT in this set and
# must never be — its opcode asserts on NULL rather than assigning it a meaning, which is
# exactly what issue #48 was.
NULL_OK_SLOTS = {
    ("message", 1),
}

ZERO = re.compile(r"^(?:0|0[xX]0+)$")

MAX_EXPANSION_DEPTH = 8

# The scan touches ~4,900 files. On ext4 that is free, but the working repo lives on /mnt/c
# where every stat and open is a 9p round trip, and serial that ran ~50-200s — enough to make
# the pre-push gate something you learn to skip. It is latency-bound, not CPU- or
# bandwidth-bound, so a small thread pool collapses it. Measured on /mnt/c:
#
#   glob("data/**/*.inc")   43.0s   ->  threaded os.scandir walk    1.8s
#   os.path.isfile per path 31.5s   ->  dropped (slurp handles it)  0.0s
#   reading every file     202.0s   ->  8 threads, chunked          5.8s
#
# 8 threads is the sweet spot; 64 was worse than 8, as 9p contends. Files are read in chunks so
# a full copy of data/ is never resident at once.
IO_THREADS = 8
READ_CHUNK = 256


def read(path):
    with open(os.path.join(ROOT, path), encoding="utf-8", errors="replace") as f:
        return f.read()


def die(msg):
    print(f"FAIL — {msg}")
    sys.exit(1)


def split_args(text):
    """Split a macro argument list on commas that are not inside quotes, parens or brackets."""
    args, depth, quote, cur = [], 0, None, ""
    for ch in text:
        if quote:
            cur += ch
            if ch == quote:
                quote = None
            continue
        if ch in "\"'":
            quote = ch
        elif ch in "([":
            depth += 1
        elif ch in ")]":
            depth -= 1
        elif ch == "," and depth == 0:
            args.append(cur.strip())
            cur = ""
            continue
        cur += ch
    if cur.strip() or args:
        args.append(cur.strip())
    return args


def strip_comment(line):
    """Drop `@` and `;` comments, respecting quotes. Charmap strings can contain either."""
    out, quote = "", None
    for ch in line:
        if quote:
            out += ch
            if ch == quote:
                quote = None
            continue
        if ch in "\"'":
            quote = ch
        elif ch in "@;":
            break
        out += ch
    return out


# ---------------------------------------------------------------------------
# 1. Parse `.macro` blocks out of the event-script macro headers.
# ---------------------------------------------------------------------------
MACRO_START = re.compile(r"^\s*\.macro\s+(\S+)\s*(.*)$")
MACRO_END = re.compile(r"^\s*\.endm\b")

macros = {}  # name -> {"params": [(name, default_or_None)], "body": [str]}

for mf in MACRO_FILES:
    path = os.path.join(ROOT, mf)
    if not os.path.exists(path):
        die(f"{mf} not found — the macro table would be incomplete and this scan would under-report.")
    name = None
    for raw in read(mf).splitlines():
        line = strip_comment(raw)
        if name is None:
            m = MACRO_START.match(line)
            if m:
                name = m.group(1).rstrip(",")
                params = []
                for p in split_args(m.group(2)):
                    if not p:
                        continue
                    if ":" in p:  # `foo:req`
                        params.append((p.split(":", 1)[0].strip(), None))
                    elif "=" in p:  # `foo=DEFAULT`
                        k, v = p.split("=", 1)
                        params.append((k.strip(), v.strip()))
                    else:  # optional, defaults to blank
                        params.append((p.strip(), ""))
                macros[name] = {"params": params, "body": []}
            continue
        if MACRO_END.match(line):
            name = None
            continue
        macros[name]["body"].append(line)

if len(macros) < MIN_MACROS_PARSED:
    die(f"only {len(macros)} macros parsed from {', '.join(MACRO_FILES)} "
        f"(expected >= {MIN_MACROS_PARSED}). A header moved or the .macro regex drifted — "
        f"this scan would pass vacuously.")


# ---------------------------------------------------------------------------
# 2. Symbolically expand an invocation and collect what reaches a `.4byte`.
# ---------------------------------------------------------------------------
PARAM_REF = re.compile(r"\\(\w+)")
IFB = re.compile(r"^\s*\.(ifb|ifnb)\s+(.*)$")
IF_OTHER = re.compile(r"^\s*\.if\w*\b")
ELSE = re.compile(r"^\s*\.else\b")
ENDIF = re.compile(r"^\s*\.endif\b")
FOURBYTE = re.compile(r"^\s*\.4byte\s+(.*)$")
DIRECTIVE = re.compile(r"^\s*[.#]")
INSTR = re.compile(r"^\s*(\S+)\s*(.*)$")


def bind(macro, actuals):
    """Positional actuals -> {param: value}, filling declared defaults then blank."""
    env = {}
    for i, (pname, default) in enumerate(macro["params"]):
        if i < len(actuals) and actuals[i] != "":
            env[pname] = actuals[i]
        else:
            env[pname] = default if default is not None else ""
    return env


def subst(text, env):
    return PARAM_REF.sub(lambda m: env.get(m.group(1), m.group(0)), text)


def pointer_args(name, actuals, depth=0):
    """Expand `name actuals...`; return the substituted expressions that reach a `.4byte`."""
    if depth > MAX_EXPANSION_DEPTH or name not in macros:
        return []
    macro = macros[name]
    env = bind(macro, actuals)
    found, stack = [], []
    for line in macro["body"]:
        m = IFB.match(line)
        if m:
            blank = subst(m.group(2), env).strip() == ""
            stack.append(blank if m.group(1) == "ifb" else not blank)
            continue
        if IF_OTHER.match(line):
            # An `.if` this expander cannot evaluate: take both arms rather than guess. Being
            # over-inclusive here can only surface a slot for review, never hide one.
            stack.append(True)
            continue
        if ELSE.match(line):
            if stack:
                stack[-1] = not stack[-1]
            continue
        if ENDIF.match(line):
            if stack:
                stack.pop()
            continue
        if not all(stack):
            continue
        m = FOURBYTE.match(line)
        if m:
            found.append(subst(m.group(1), env).strip())
            continue
        if DIRECTIVE.match(line):
            continue
        m = INSTR.match(line)
        if not m:
            continue
        callee = subst(m.group(1), env).strip().rstrip(",")
        if callee in macros:
            found += pointer_args(callee, split_args(subst(m.group(2), env)), depth + 1)
    return found


# Derive, per macro, which 1-based argument indices can land in a `.4byte`. Probed with unique
# sentinels so the mapping is read back off the expansion rather than assumed. Two probes are
# needed because optional arguments change the answer (`goto_if_eq`): one saturated with every
# argument present, one minimal with only the required ones.
def probe(name):
    params = macros[name]["params"]
    slots = set()
    required = sum(1 for _, d in params if d is None)
    for count in {len(params), max(required, 1)}:
        sentinels = [f"__A{i + 1}__" for i in range(count)]
        for expr in pointer_args(name, sentinels):
            for i, s in enumerate(sentinels):
                if s in expr:
                    slots.add(i + 1)
    return slots


pointer_slots = {}  # macro -> {1-based arg index}
for name in macros:
    slots = probe(name)
    if slots:
        pointer_slots[name] = slots

if len(pointer_slots) < MIN_POINTER_MACROS:
    die(f"only {len(pointer_slots)} macros resolved to a .4byte pointer argument "
        f"(expected >= {MIN_POINTER_MACROS}). The macro expander drifted — this scan "
        f"would pass vacuously.")

for label, table in (("VALUE_SLOTS", VALUE_SLOTS), ("NULL_OK_SLOTS", NULL_OK_SLOTS)):
    for name, idx in sorted(table):
        if idx not in pointer_slots.get(name, ()):
            die(f"{label} lists ({name}, {idx}), but that is no longer a derived .4byte slot. "
                f"The macro changed; re-check the exemption and remove it if it is stale.")

if NULL_OK_SLOTS & VALUE_SLOTS:
    die(f"{sorted(NULL_OK_SLOTS & VALUE_SLOTS)} is in both VALUE_SLOTS and NULL_OK_SLOTS. "
        f"A slot is either a 32-bit number or a pointer that tolerates NULL, not both.")

# Sanity-check the derivation against the case that motivated this script. If `pokemart`'s
# products argument ever stops resolving, the guard is not guarding anything.
if 1 not in pointer_slots.get("pokemart", ()):
    die("pokemart's products argument no longer resolves to a .4byte pointer slot — the "
        "expander is broken and issue #48 would not be caught again.")


# ---------------------------------------------------------------------------
# 3. Scan the event-script sources for bare integers in those slots.
# ---------------------------------------------------------------------------
NUMERIC = re.compile(r"^(?:0[xX][0-9a-fA-F]+|\d+)$")

def walk_suffix(root, suffix, pool):
    """Recursive file listing, one thread per directory level. See the IO_THREADS note."""
    files, pending = [], [root]
    while pending:
        nxt = []
        for entries in pool.map(lambda d: list(os.scandir(d)), pending):
            for e in entries:
                if e.is_dir(follow_symlinks=False):
                    nxt.append(e.path)
                elif e.name.endswith(suffix):
                    files.append(e.path)
        pending = nxt
    return files


with ThreadPoolExecutor(IO_THREADS) as pool:
    paths = []
    for d in SCAN_DIRS:
        paths += walk_suffix(os.path.join(ROOT, d), SCAN_SUFFIX, pool)
    paths += [os.path.join(ROOT, f) for f in SCAN_FILES]

violations = []
numeric_count = {}   # (macro, idx) -> bare-integer call sites
symbol_count = {}    # (macro, idx) -> label/constant call sites
invocations = 0


def slurp(path):
    try:
        with open(path, encoding="utf-8", errors="replace") as f:
            return path, f.read()
    except OSError:
        return path, None


def scan(rel, text):
    global invocations
    # Reset per file. A `.macro` left open at EOF must not silence the next file — that would
    # quietly drop whole directories from the scan and still report OK.
    in_macro = False
    for ln, raw in enumerate(text.splitlines(), 1):
        line = strip_comment(raw)
        # A `.macro` body inside data/ is a definition, not an invocation: its arguments are
        # `\name` references, and its own callers are what this scan checks.
        if MACRO_START.match(line):
            in_macro = True
            continue
        if MACRO_END.match(line):
            in_macro = False
            continue
        if in_macro:
            continue
        m = INSTR.match(line)
        if not m:
            continue
        name = m.group(1).rstrip(",")
        if name not in pointer_slots:
            continue
        invocations += 1
        args = split_args(m.group(2))
        for idx in sorted(pointer_slots[name]):
            if idx > len(args) or not args[idx - 1]:
                continue
            arg = args[idx - 1]
            key = (name, idx)
            if NUMERIC.match(arg):
                numeric_count[key] = numeric_count.get(key, 0) + 1
                waived = key in VALUE_SLOTS or (key in NULL_OK_SLOTS and ZERO.match(arg))
                if not waived:
                    violations.append((f"{rel}:{ln}", name, idx, arg))
            else:
                symbol_count[key] = symbol_count.get(key, 0) + 1


# No isfile() filter: that is 4,861 extra 9p stats, and slurp already returns None for anything
# unreadable (a directory raises IsADirectoryError, an OSError subclass). A genuinely missing
# SCAN_FILES entry is caught by the MIN_INVOCATIONS floor, not by a stat.
scan_paths = sorted(set(paths))
with ThreadPoolExecutor(IO_THREADS) as pool:
    for start in range(0, len(scan_paths), READ_CHUNK):
        for path, text in pool.map(slurp, scan_paths[start:start + READ_CHUNK]):
            if text is None:
                continue
            scan(os.path.relpath(path, ROOT).replace(os.sep, "/"), text)

if invocations < MIN_INVOCATIONS:
    die(f"only {invocations} pointer-taking macro invocations scanned across data/ "
        f"(expected >= {MIN_INVOCATIONS}). The scan globs drifted — this check would "
        f"pass vacuously.")

if "--report" in sys.argv:
    print(f"{'macro':<28}{'arg':>4}{'numeric':>9}{'symbol':>8}  class")
    for key in sorted(set(numeric_count) | set(symbol_count)):
        n, s = numeric_count.get(key, 0), symbol_count.get(key, 0)
        kind = ("value" if key in VALUE_SLOTS else
                "pointer/null-ok" if key in NULL_OK_SLOTS else "pointer")
        print(f"{key[0]:<28}{key[1]:>4}{n:>9}{s:>8}  {kind}")

# A classified value slot whose call sites are mostly labels is a misclassification, and it
# would be hiding exactly the bug this script exists to find.
for key in sorted(VALUE_SLOTS):
    n, s = numeric_count.get(key, 0), symbol_count.get(key, 0)
    if n + s >= VALUE_SLOT_MIN_SAMPLE and n / (n + s) < VALUE_SLOT_MIN_NUMERIC:
        die(f"VALUE_SLOTS lists {key[0]} argument {key[1]} as a 32-bit number, but {s} of "
            f"{n + s} call sites in data/ pass a symbol. That slot looks like a pointer — "
            f"the exemption is wrong and is suppressing real findings.")

print(f"macros parsed: {len(macros)} | pointer-taking: {len(pointer_slots)} | "
      f"invocations scanned: {invocations}")

if violations:
    print(f"FAIL — {len(violations)} script pointer argument(s) set to a bare integer:")
    for where, name, idx, arg in violations:
        print(f"  {where}: {name} argument {idx} is `{arg}`, but that slot is emitted as a "
              f".4byte pointer")
    print("  A numeric literal here assembles, links and boots clean, then faults at runtime")
    print("  when the script runs. Point it at a real label (see issue #48).")
    print("  If the macro genuinely takes a 32-bit number there (as the money commands do),")
    print("  run with --report and add it to VALUE_SLOTS instead.")
    sys.exit(1)

print("OK — every script pointer argument in data/ is a label, not a bare integer.")
