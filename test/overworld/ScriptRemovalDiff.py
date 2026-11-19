#!/usr/bin/env python3
"""Diff event scripts and map events between two revisions, keyed on what the old game could reach.

A content-removal commit edits map scripts by hand. The build proves no reference dangles; it does
not prove a reachable script still does what it did. This lists, for two git revisions:

  A. per map: surviving labels whose instruction body or fall-through target changed, and removed
     labels, each marked REACHABLE, dead or noop (body was only end/return) in the OLD tree. Roots
     are map.json script fields, <Map>_MapScripts and labels named in src/ or include/; reach then
     follows goto/call/table references and fall-through. A map.json root counts even when the map
     itself is sealed, so REACHABLE over-approximates;
  B. removed macros, flags, vars and script-cmd/special rows retargeted to a no-op, with every use
     in a script the OLD tree could reach, plus surviving uses in the NEW tree;
  C. map.json object, warp, coord and bg event changes by index, and warps elsewhere whose
     dest_warp_id lands on a changed warp slot;
  D. with --elf OLD.elf NEW.elf (each beside its .gba): gScriptCmdTable and gSpecials resolved to
     handler names by index, so a renumbered opcode or special shows as a row whose handler moved.

Usage: python3 test/overworld/ScriptRemovalDiff.py OLD_REV NEW_REV [--maps REGEX] [--elf OLD NEW]
"""
import argparse
import difflib
import json
import re
import subprocess
import sys

SCRIPT_GLOBS = ("data/maps/", "data/scripts/", "data/event_scripts.s", "data/specials.inc",
                "data/script_cmd_table.inc", "asm/macros/", "include/constants/")
SRC_PREFIXES = ("src/", "include/")
TERMINATORS = {"end", "return", "goto", "step_end", "goto_std"}
NOOP_BODIES = (["end"], ["return"], ["releaseall", "end"])
LABEL_RE = re.compile(r"^(\w+)::?(?:\s|$)")
TOKEN_RE = re.compile(r"[A-Za-z_]\w*")
DEFINE_RE = re.compile(r"^#define\s+((?:FLAG|VAR)_\w+)\b", re.M)
MACRO_RE = re.compile(r"^\s*\.macro\s+(\w+)", re.M)


def read_tree(rev):
    names = subprocess.run(["git", "ls-tree", "-r", "--name-only", rev], capture_output=True,
                           text=True, check=True).stdout.split("\n")
    want = [n for n in names if n.startswith(SCRIPT_GLOBS) and n.endswith((".inc", ".s", ".json", ".h"))
            or n.startswith(SRC_PREFIXES) and n.endswith((".c", ".h"))]
    proc = subprocess.run(["git", "cat-file", "--batch"], input="".join(f"{rev}:{n}\n" for n in want).encode(),
                          capture_output=True, check=True)
    out, pos, files = proc.stdout, 0, {}
    for name in want:
        header_end = out.index(b"\n", pos)
        size = int(out[pos:header_end].split()[2])
        files[name] = out[header_end + 1:header_end + 1 + size].decode("utf-8", "replace")
        pos = header_end + 1 + size + 1
    return files


def strip_comment(line):
    out, quoted = [], False
    for ch in line:
        if ch == '"':
            quoted = not quoted
        if ch == "@" and not quoted:
            break
        out.append(ch)
    return "".join(out).strip()


def parse_labels(files):
    """label -> {file, body: [normalized lines], next: label that follows in file order}"""
    labels = {}
    for name, text in files.items():
        if not (name.endswith(".inc") or name.endswith(".s")) or name.startswith("asm/"):
            continue
        current, prev = None, None
        for raw in text.split("\n"):
            m = LABEL_RE.match(raw)
            if m:
                prev, current = current, m.group(1)
                labels[current] = {"file": name, "body": [], "next": None}
                if prev:
                    labels[prev]["next"] = current
                rest = strip_comment(raw[m.end():])
                if rest:
                    labels[current]["body"].append(rest)
                continue
            line = strip_comment(raw)
            if current and line and not line.startswith((".if", ".endif", ".else", "#if", "#endif", "#else")):
                labels[current]["body"].append(line)
    return labels


def index_tokens(labels):
    """Attach per-line tokens to each label and return token -> labels that use it."""
    index = {}
    for label, info in labels.items():
        info["toks"] = [code_tokens(line) for line in info["body"]]
        for toks in info["toks"]:
            for t in toks:
                index.setdefault(t, set()).add(label)
    return index


def falls_through(body):
    if not body:
        return True
    last = body[-1]
    head = last.split()[0] if last.split() else ""
    return head not in TERMINATORS and not last.endswith('$"') and last not in (".2byte 0", ".byte 0")


def code_tokens(line):
    return TOKEN_RE.findall(re.sub(r'"[^"]*"', "", line))


def reachable(files, labels):
    roots = set()
    for name, text in files.items():
        if name.endswith("/map.json"):
            data = json.loads(text)
            roots.add(f"{data.get('name', '')}_MapScripts")
            for key in ("object_events", "coord_events", "bg_events"):
                for ev in data.get(key) or []:
                    if ev.get("script"):
                        roots.add(ev["script"])
        elif name.startswith(SRC_PREFIXES):
            roots.update(t for t in TOKEN_RE.findall(text) if t in labels)
    seen, stack = set(), [r for r in roots if r in labels]
    while stack:
        label = stack.pop()
        if label in seen:
            continue
        seen.add(label)
        info = labels[label]
        for toks in info["toks"]:
            stack.extend(t for t in toks if t in labels and t not in seen)
        if info["next"] and falls_through(info["body"]):
            stack.append(info["next"])
    return seen


def referrers(index, reach, target):
    return sorted(index.get(target, set()) & reach)


def map_of(path):
    return path.split("/")[2] if path.startswith("data/maps/") else None


def noop_map_script(line, old):
    toks = code_tokens(line)
    return toks[:1] in (["map_script"], ["map_script_2"]) and old.get(toks[-1], {}).get("body") in NOOP_BODIES


def section_a(old, new, old_index, old_reach, maps_re):
    print("== A. Script labels (old reachability; noop = body was only end/return) ==")
    for label in sorted(set(old) | set(new)):
        info = old.get(label) or new.get(label)
        mp = map_of(info["file"])
        if maps_re and not (mp and maps_re.search(mp)) and not (mp is None and label in old and label not in new):
            continue
        tag = "REACHABLE" if label in old_reach else "dead"
        if label in old and old[label]["body"] in NOOP_BODIES:
            tag = "noop"
        if label in old and label not in new:
            refs = referrers(old_index, old_reach, label)
            print(f"REMOVED  {tag:9} {info['file']}:{label}" + (f"  <- {', '.join(refs[:6])}" if refs else ""))
        elif label in old and old[label]["body"] != new[label]["body"]:
            delta = [d for d in difflib.unified_diff(old[label]["body"], new[label]["body"], lineterm="", n=0)
                     if not d.startswith(("---", "+++", "@@"))]
            if all(d.startswith("-") and noop_map_script(d[1:], old) for d in delta):
                tag = "noop"
            print(f"CHANGED  {tag:9} {info['file']}:{label}")
            for d in difflib.unified_diff(old[label]["body"], new[label]["body"], lineterm="", n=0):
                if not d.startswith(("---", "+++", "@@")):
                    print(f"           {d}")
        if label in old and label in new and label in old_reach and falls_through(old[label]["body"]) \
                and old[label]["next"] != new[label]["next"]:
            print(f"FALLTHROUGH {info['file']}:{label}: {old[label]['next']} -> {new[label]['next']}")
        if label not in old and mp and maps_re and maps_re.search(mp):
            print(f"ADDED              {info['file']}:{label}")


def uses(labels, index, reach, name, pred):
    hits = {}
    for label in index.get(name, set()) & reach:
        for line, toks in zip(labels[label]["body"], labels[label]["toks"]):
            if toks and pred(toks):
                hits.setdefault(label, line)
    return hits


def unused_specials(files):
    text = files.get("data/specials.inc", "")
    return set(re.findall(r"def_special\s+(\w+),\s*target=Special_Unused", text))


def nop_opcodes(files):
    text = files.get("data/script_cmd_table.inc", "")
    return {m.group(1) for m in re.finditer(r"script_cmd_table_entry\s+SCR_OP_(\w+)\s+ScrCmd_nop\w*", text)}


def section_b(old_files, new_files, old, new, old_index, new_index, old_reach, new_reach):
    print("\n== B. Removed identifiers and their uses ==")
    def defs(files, regex, prefix):
        return {d for n, t in files.items() if n.startswith(prefix) for d in regex.findall(t)}
    gone_macros = defs(old_files, MACRO_RE, "asm/macros/") - defs(new_files, MACRO_RE, "asm/macros/")
    gone_consts = defs(old_files, DEFINE_RE, "include/constants/") - defs(new_files, DEFINE_RE, "include/constants/")
    new_unused = unused_specials(new_files) - unused_specials(old_files)
    new_nops = nop_opcodes(new_files) - nop_opcodes(old_files)
    groups = [
        ("macro", gone_macros, lambda name: lambda toks: toks[0] == name),
        ("flag/var", gone_consts, lambda name: lambda toks: name in toks),
        ("special->Special_Unused", new_unused,
         lambda name: lambda toks: toks[0] in ("special", "specialvar", "special_waitstate") and name in toks),
        ("opcode->nop", new_nops, lambda name: lambda toks: toks[0] == name.lower()),
    ]
    for kind, names, mk in groups:
        for name in sorted(names):
            key = name.lower() if kind == "opcode->nop" else name
            old_hits = uses(old, old_index, old_reach, key, mk(name))
            new_hits = uses(new, new_index, new_reach, key, mk(name))
            print(f"{kind:24} {name:40} old-reachable uses {len(old_hits):3}  new-reachable uses {len(new_hits):3}")
            for label, line in sorted(old_hits.items()):
                print(f"    old {old[label]['file']}:{label}: {line}")
            for label, line in sorted(new_hits.items()):
                print(f"    NEW {new[label]['file']}:{label}: {line}")


def map_events(files):
    out = {}
    for name, text in files.items():
        if name.endswith("/map.json"):
            data = json.loads(text)
            out[data["name"]] = {"id": data.get("id"), **{k: data.get(k) or [] for k in
                                 ("object_events", "warp_events", "coord_events", "bg_events")}}
    return out


def section_c(old_files, new_files, maps_re):
    print("\n== C. map.json events ==")
    old_maps, new_maps = map_events(old_files), map_events(new_files)
    changed_warps = {}
    for name in sorted(set(old_maps) | set(new_maps)):
        o, n = old_maps.get(name), new_maps.get(name)
        if o is None or n is None:
            if maps_re is None or maps_re.search(name):
                print(f"MAP {'ADDED' if o is None else 'REMOVED'} {name}")
            if n is None:
                changed_warps[o["id"]] = set(range(len(o["warp_events"])))
            continue
        for key in ("object_events", "warp_events", "coord_events", "bg_events"):
            if o[key] == n[key]:
                continue
            bad = [i for i in range(max(len(o[key]), len(n[key])))
                   if i >= len(o[key]) or i >= len(n[key]) or o[key][i] != n[key][i]]
            if key == "warp_events":
                changed_warps[o["id"]] = set(bad)
            if maps_re is None or maps_re.search(name):
                print(f"{name} {key}: {len(o[key])} -> {len(n[key])}; index changes at {bad}")
                for i in bad:
                    print(f"    [{i}] old {json.dumps(o[key][i]) if i < len(o[key]) else '-'}")
                    print(f"    [{i}] new {json.dumps(n[key][i]) if i < len(n[key]) else '-'}")
    for name, m in sorted(new_maps.items()):
        for i, w in enumerate(m["warp_events"]):
            slots = changed_warps.get(w.get("dest_map"))
            if slots is not None and int(w.get("dest_warp_id", -1)) in slots:
                print(f"INBOUND WARP {name}[{i}] -> {w['dest_map']} warp {w['dest_warp_id']} (slot changed)")


def table_handlers(elf, start, end=None):
    syms = []
    for line in subprocess.run(["arm-none-eabi-nm", "-n", elf], capture_output=True, text=True,
                               check=True).stdout.split("\n"):
        parts = line.split()
        if len(parts) == 3:
            syms.append((int(parts[0], 16), parts[2]))
    by_addr = {}
    for addr, name in syms:
        by_addr.setdefault(addr, name)
    base = next(a for a, n in syms if n == start)
    stop = next(a for a, n in syms if n == end) if end else next(a for a, n in syms if a > base)
    with open(elf[:-4] + ".gba", "rb") as rom:
        rom.seek(base - 0x08000000)
        raw = rom.read(stop - base)
    words = [int.from_bytes(raw[i:i + 4], "little") for i in range(0, len(raw), 4)]
    return [by_addr.get((w - 0x02000000 if w >= 0x0A000000 else w) & ~1, hex(w)) for w in words]


def section_d(old_elf, new_elf):
    print("\n== D. Opcode and special tables by index ==")
    for start, end in (("gScriptCmdTable", "gScriptCmdTableEnd"), ("gSpecials", None)):
        o, n = table_handlers(old_elf, start, end), table_handlers(new_elf, start, end)
        print(f"{start}: {len(o)} -> {len(n)} entries")
        for i in range(max(len(o), len(n))):
            a = o[i] if i < len(o) else "-"
            b = n[i] if i < len(n) else "-"
            if a != b:
                print(f"    [{i:#05x}] {a} -> {b}")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("old")
    ap.add_argument("new")
    ap.add_argument("--maps", help="regex on map folder names for sections A and C")
    ap.add_argument("--elf", nargs=2, metavar=("OLD_ELF", "NEW_ELF"))
    args = ap.parse_args()
    maps_re = re.compile(args.maps) if args.maps else None
    old_files, new_files = read_tree(args.old), read_tree(args.new)
    old, new = parse_labels(old_files), parse_labels(new_files)
    old_index, new_index = index_tokens(old), index_tokens(new)
    old_reach, new_reach = reachable(old_files, old), reachable(new_files, new)
    print(f"labels old {len(old)} (reachable {len(old_reach)}), new {len(new)} (reachable {len(new_reach)})")
    if len(old_reach) < 1000 or len(new_reach) < 1000:
        sys.exit("reachability found too few labels; the parser drifted")
    section_a(old, new, old_index, old_reach, maps_re)
    section_b(old_files, new_files, old, new, old_index, new_index, old_reach, new_reach)
    section_c(old_files, new_files, maps_re)
    if args.elf:
        section_d(*args.elf)


if __name__ == "__main__":
    main()
