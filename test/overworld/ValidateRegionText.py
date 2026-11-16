#!/usr/bin/env python3
"""Every line a Johto map can show names no Hoenn place.

Johto maps reuse scripts written for Hoenn (Mauville's Game Corner clerk, Route 121's Safari
attendant, Oldale's Pokemon Center), and pokemonHnS reworded its copies of some of them. The
region merge kept Emerald's wording, so Goldenrod's coin clerk greeted "This is MAUVILLE GAME
CORNER." while the build stayed green.

A map is Johto when its region map section is, by the game's own rule (GetRegionForSectionId:
JOHTO_MAPSEC_START to JOHTO_MAPSEC_END in region_map_sections.json). From every script a Johto map can
start (map scripts, objects, signs and triggers) the check follows each label the script names,
through any file, and reads every string it reaches. A Hoenn town or the word HOENN in one of
them fails the check.

Run from the repo root: python3 test/overworld/ValidateRegionText.py
Exit status 1 on any finding.
"""
import glob
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
HOENN = re.compile(r"\b(HOENN|LITTLEROOT|OLDALE|PETALBURG|RUSTBORO|DEWFORD|SLATEPORT|MAUVILLE|VERDANTURF|"
                   r"FALLARBOR|LAVARIDGE|FORTREE|LILYCOVE|MOSSDEEP|SOOTOPOLIS|PACIFIDLOG|EVER GRANDE)\b")
LABEL = re.compile(r"^(\w+)::?", re.M)
WORD = re.compile(r"\b[A-Za-z_]\w*\b")
MAX_DEPTH = 8


def sources():
    files = glob.glob(os.path.join(ROOT, "data/maps/*/scripts.inc")) + glob.glob(os.path.join(ROOT, "data/scripts/*.inc"))
    files.append(os.path.join(ROOT, "data/event_scripts.s"))
    files += glob.glob(os.path.join(ROOT, "data/text/*.inc"))
    text, where = {}, {}
    for path in files:
        body = open(path, encoding="utf-8", errors="replace").read()
        text[path] = body
        starts = [(m.group(1), m.start()) for m in LABEL.finditer(body)]
        for k, (name, start) in enumerate(starts):
            end = starts[k + 1][1] if k + 1 < len(starts) else len(body)
            where.setdefault(name, (path, start, end))
    return text, where


def johto_maps():
    consts = open(os.path.join(ROOT, "src/data/region_map/region_map_sections.constants.json.txt")).read()
    first = re.search(r"#define JOHTO_MAPSEC_START\s+(\w+)", consts).group(1)
    last = re.search(r"#define JOHTO_MAPSEC_END\s+(\w+)", consts).group(1)
    ids = [sec["id"] for sec in json.load(open(os.path.join(ROOT, "src/data/region_map/region_map_sections.json")))["map_sections"]]
    johto = set(ids[ids.index(first):ids.index(last) + 1])
    out = []
    for path in sorted(glob.glob(os.path.join(ROOT, "data/maps/*/map.json"))):
        m = json.load(open(path))
        if m.get("region_map_section") in johto:
            out.append(m)
    return out


def entry_labels(m):
    names = {m["name"] + "_MapScripts"}
    for key in ("object_events", "bg_events", "coord_events"):
        for e in m.get(key, []):
            s = e.get("script")
            if s and s not in ("0", "NULL"):
                names.add(s)
    return names


def code_only(block):
    """The block without @ and // comments, which name labels the script never runs."""
    return "\n".join(line if ".string" in line else re.split(r"@|//", line)[0] for line in block.split("\n"))


def main():
    text, where = sources()
    findings = []
    for m in johto_maps():
        seen, stack = set(), [(n, 0, n) for n in entry_labels(m)]
        while stack:
            name, depth, via = stack.pop()
            if name in seen or name not in where or depth > MAX_DEPTH:
                continue
            seen.add(name)
            path, start, end = where[name]
            block = text[path][start:end]
            for s in re.findall(r'\.string "([^"]*)"', block):
                if HOENN.search(s):
                    findings.append((m["name"], via, name, os.path.relpath(path, ROOT), s))
            for w in set(WORD.findall(code_only(block))):
                if w != name and w in where:
                    stack.append((w, depth + 1, via))
    for mapname, via, label, path, s in sorted(set(findings)):
        print(f"{mapname}: {via} reaches {label} ({path}): \"{s}\"")
    if findings:
        print(f"FAIL: {len(set(findings))} Johto line(s) name a Hoenn place")
        return 1
    print("OK: no line a Johto map can show names a Hoenn place")
    return 0


if __name__ == "__main__":
    sys.exit(main())
