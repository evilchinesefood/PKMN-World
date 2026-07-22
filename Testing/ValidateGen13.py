#!/usr/bin/env python3
"""Gen 1-3 content-rule validator (host-side, no emulator).

The game's hard rule: obtainable content references Gen 1-3 species only. Enforcement is
per-family via P_FAMILY_* FALSE in include/config/species_enabled.h; a reference to a
disabled species compiles clean and blue-screens at battle start, so this scans every
obtainable-species source and fails on any disabled reference.

Run from the repo root: python3 Testing/ValidateGen13.py   (exit 0 = clean, 1 = violations)
"""
import re, sys, glob, os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

def read(path):
    with open(os.path.join(ROOT, path), encoding="utf-8", errors="replace") as f:
        return f.read()

# 1. Disabled families from species_enabled.h (FALSE = world-stripped).
disabled_families = set()
for m in re.finditer(r"#define\s+(P_FAMILY_\w+)\s+FALSE\b", read("include/config/species_enabled.h")):
    disabled_families.add(m.group(1))

# 2. species -> family from the gen_*_families.h #if P_FAMILY_* nesting.
#    Tracks the innermost P_FAMILY guard; collects SPECIES_ ids and display names.
species_family = {}   # "SPECIES_LUXRAY" -> "P_FAMILY_SHINX"
name_family = {}      # "luxray" (lowercased display name) -> family
for path in sorted(glob.glob(os.path.join(ROOT, "src/data/pokemon/species_info/gen_*_families.h"))):
    stack = []
    cur_species = None
    for line in open(path, encoding="utf-8", errors="replace"):
        m = re.match(r"\s*#if\s+(P_FAMILY_\w+)", line)
        if m:
            stack.append(m.group(1)); continue
        if re.match(r"\s*#if", line) or re.match(r"\s*#ifdef", line) or re.match(r"\s*#ifndef", line):
            stack.append(None); continue
        if re.match(r"\s*#endif", line):
            if stack: stack.pop()
            continue
        fam = next((s for s in reversed(stack) if s), None)
        m = re.match(r"\s*\[(SPECIES_\w+)\]\s*=", line)
        if m and fam:
            cur_species = m.group(1)
            species_family[cur_species] = fam
            continue
        m = re.search(r'\.speciesName\s*=\s*_\(\s*"([^"]+)"', line)
        if m and fam and cur_species:
            name_family.setdefault(m.group(1).lower(), fam)

def family_of(token):
    """token: SPECIES_X or a display name. Returns family or None if unresolvable."""
    if token.startswith("SPECIES_"):
        return species_family.get(token)
    return name_family.get(token.lower())

violations = []
def check(token, where):
    fam = family_of(token)
    if fam and fam in disabled_families:
        violations.append((where, token, fam))

# 3. Trainer party files (BOTH formats: display names + SPECIES_ constants).
KEY_LINE = re.compile(r"^\s*(\w[\w .']*?):\s")   # "Level: 5", "Ability: ..." etc.
for pf in ["src/data/trainers.party", "src/data/trainers_frlg.party",
           "src/data/battle_partners.party", "src/data/debug_trainers.party"]:
    if not os.path.exists(os.path.join(ROOT, pf)):
        continue
    for ln, line in enumerate(read(pf).splitlines(), 1):
        s = line.strip()
        if not s or s.startswith("===") or s.startswith("/*") or s.startswith("*") or s.startswith("//"):
            continue
        if KEY_LINE.match(s) or s.startswith("-") or s.startswith("."):
            continue
        # A mon header line: "Name (M) @ Item" / "SPECIES_X @ Item" / "Nickname (Name)"
        head = s.split("@")[0].strip()
        m = re.match(r"(SPECIES_\w+)", head)
        if m:
            check(m.group(1), f"{pf}:{ln}")
            continue
        base = re.sub(r"\s*\((M|F)\)\s*$", "", head)
        inner = re.match(r".*\(([^)]+)\)\s*$", base)  # "Nickname (Species)"
        cand = inner.group(1) if inner else base
        if cand.lower() in name_family:
            check(cand, f"{pf}:{ln}")

# 4. Wild encounters + facility/static data + scripts: every SPECIES_ token in these sources.
SPECIES_SOURCES = (
    glob.glob(os.path.join(ROOT, "src/data/wild_encounters*.h"))
    + glob.glob(os.path.join(ROOT, "src/data/ingame_trades*.h"))
    + glob.glob(os.path.join(ROOT, "src/data/trade.h"))
    + glob.glob(os.path.join(ROOT, "src/data/battle_frontier/*.h"))
)
for path in SPECIES_SOURCES:
    rel = os.path.relpath(path, ROOT)
    for ln, line in enumerate(open(path, encoding="utf-8", errors="replace"), 1):
        for m in re.finditer(r"\bSPECIES_\w+\b", line):
            check(m.group(0), f"{rel}:{ln}")

# 5. Gift/egg/static-battle script macros across data/.
GIVE = re.compile(r"\b(givemon|giveegg|setwildbattle|seteventmon|givenamedmon|giveoddegg)\b[^\n]*?(SPECIES_\w+)")
for path in glob.glob(os.path.join(ROOT, "data/**/*.inc"), recursive=True) + [os.path.join(ROOT, "data/event_scripts.s")]:
    rel = os.path.relpath(path, ROOT)
    try:
        text = open(path, encoding="utf-8", errors="replace").read()
    except OSError:
        continue
    for ln, line in enumerate(text.splitlines(), 1):
        for m in GIVE.finditer(line):
            check(m.group(2), f"{rel}:{ln}")

print(f"families disabled: {len(disabled_families)} | species mapped: {len(species_family)} "
      f"(+{len(name_family)} names)")
if violations:
    print(f"FAIL — {len(violations)} disabled-species reference(s):")
    for where, token, fam in violations:
        print(f"  {where}: {token} ({fam} is FALSE)")
    sys.exit(1)
print("OK — no disabled-species references in obtainable content.")
