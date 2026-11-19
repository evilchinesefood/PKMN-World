#!/usr/bin/env python3
"""Report what a commit's map script and map.json edits change at runtime.

Reads both trees straight from git, so no checkout or build is needed:

    python3 test/overworld/MapScriptRemovalDiff.py OLD NEW [--maps REGEX]

For every map whose scripts.inc or map.json differs it lists:
  CHANGED  a label present in both trees whose code differs, with each removed or added
           line, and NOOP when the removed line only referenced a script whose body is `end`.
  FALLTHRU a surviving label with no terminator whose next label changed.
  REMOVED  a deleted label, tagged LIVE when the old tree could reach it from a map header,
           an object/coord/bg event or C, else DEAD. LIVE entries carry one reference path
           and the flags, vars, specials and commands their body used.
  EVENTS   map.json object, warp, coord and bg event changes by index, with every later
           index that shifted and the references that address this map by index.
  ORPHANED a surviving label the old tree reached and the new tree no longer does.
  SPECIALS specials whose table entry was removed or retargeted, and every reachable line in
           the selected maps that still calls one.
Run it from the repository root. It builds nothing, so it also runs on a clean checkout.
"""
import argparse
import json
import re
import subprocess
import sys
from collections import defaultdict, deque

IDENT = re.compile(r"[A-Za-z_][A-Za-z0-9_]*")
LABEL = re.compile(r"^([A-Za-z_][A-Za-z0-9_]*)::?\s*(?:@.*)?$")
STRING = re.compile(r'"(?:\\.|[^"\\])*"')
TERMINATORS = {"end", "return", "goto", "step_end"}
DATA_DIRECTIVES = {".string", ".braille", ".byte", ".2byte", ".4byte", ".align", ".fill"}


def git(*args, binary=False):
    out = subprocess.run(["git", *args], check=True, capture_output=True).stdout
    return out if binary else out.decode("utf-8", "replace")


class Tree:
    def __init__(self, rev):
        self.rev = rev
        names = git("ls-tree", "-r", "--name-only", rev, "--", "data", "src", "include").splitlines()
        self.script_files = [n for n in names if n.startswith("data/") and n.endswith((".inc", ".s"))
                             and not n.startswith(("data/maps/map_groups", "data/layouts"))]
        self.map_jsons = [n for n in names if re.fullmatch(r"data/maps/[^/]+/map\.json", n)]
        self.c_files = [n for n in names if n.endswith((".c", ".h"))]
        blobs = self._cat(self.script_files + self.map_jsons + self.c_files)
        self.labels = {}
        self.order = defaultdict(list)
        for path in self.script_files:
            self._parse_script(path, blobs[path])
        self.maps = {}
        for path in self.map_jsons:
            self.maps[path.split("/")[2]] = json.loads(blobs[path])
        self.c_idents = set()
        for path in self.c_files:
            text = re.sub(r"/\*.*?\*/", " ", blobs[path], flags=re.S)
            text = re.sub(r"//[^\n]*", " ", text)
            self.c_idents.update(IDENT.findall(STRING.sub(" ", text)))

    def _cat(self, paths):
        req = "".join(f"{self.rev}:{p}\n" for p in paths).encode()
        out = subprocess.run(["git", "cat-file", "--batch"], input=req, check=True,
                             capture_output=True).stdout
        blobs, pos = {}, 0
        for p in paths:
            header_end = out.index(b"\n", pos)
            size = int(out[pos:header_end].split()[2])
            blobs[p] = out[header_end + 1:header_end + 1 + size].decode("utf-8", "replace")
            pos = header_end + 1 + size + 1
        return blobs

    def _parse_script(self, path, text):
        current = None
        for raw in text.splitlines():
            line = strip_comment(raw).rstrip()
            m = LABEL.match(line)
            if m:
                current = m.group(1)
                self.labels[current] = {"file": path, "body": []}
                self.order[path].append(current)
                continue
            if current and line.strip():
                self.labels[current]["body"].append(" ".join(line.split()))

    def refs(self, label):
        out = set()
        for line in self.labels[label]["body"]:
            for tok in IDENT.findall(STRING.sub(" ", line)):
                if tok != label and tok in self.labels:
                    out.add(tok)
        return out

    def roots(self):
        roots = {}
        for name, m in self.maps.items():
            scripts_map = m.get("shared_scripts_map") or m["name"]
            roots[f"{scripts_map}_MapScripts"] = f"header of {name}"
            for kind in ("object_events", "coord_events", "bg_events"):
                for i, ev in enumerate(m.get(kind) or []):
                    script = ev.get("script")
                    if script and script != "0":
                        roots[script] = f"{name} {kind}[{i}]"
        for label in self.labels:
            if label in self.c_idents:
                roots.setdefault(label, "C reference")
        return roots

    def reachable(self):
        parent = {}
        queue = deque()
        for label, why in self.roots().items():
            if label in self.labels:
                parent[label] = why
                queue.append(label)
        while queue:
            cur = queue.popleft()
            nxt = self.refs(cur)
            if falls_through(self.labels[cur]["body"]):
                follow = self.next_label(cur)
                if follow:
                    nxt.add(follow)
            for ref in sorted(nxt):
                if ref not in parent:
                    parent[ref] = cur
                    queue.append(ref)
        return parent

    def next_label(self, label):
        seq = self.order[self.labels[label]["file"]]
        i = seq.index(label)
        return seq[i + 1] if i + 1 < len(seq) else None


def strip_comment(line):
    out, in_str = [], False
    for i, ch in enumerate(line):
        if ch == '"' and (i == 0 or line[i - 1] != "\\"):
            in_str = not in_str
        if not in_str and (ch == "@" or line.startswith("//", i)):
            break
        out.append(ch)
    return "".join(out)


def kind_of(body):
    if not body:
        return "empty"
    first = {line.split()[0] for line in body}
    if first <= DATA_DIRECTIVES:
        return "text" if ".string" in first or ".braille" in first else "data"
    if "map_script" in first or "map_script_2" in first:
        return "mapscripts"
    if body[-1].split()[0] == "step_end":
        return "movement"
    return "script"


def falls_through(body):
    if not body:
        return True
    if kind_of(body) != "script":
        return False
    return body[-1].split()[0] not in TERMINATORS


def is_noop(tree, label):
    return label in tree.labels and tree.labels[label]["body"] in (["end"], ["return"], [])


def path_to(parent, label):
    chain = [label]
    while chain[-1] in parent and parent[chain[-1]] in parent:
        chain.append(parent[chain[-1]])
        if len(chain) > 12:
            break
    root = parent.get(chain[-1], "?")
    return " <- ".join(chain) + f" <- [{root}]"


def symbols_used(body):
    toks = set()
    for line in body:
        parts = line.split(None, 1)
        toks.add(parts[0])
        toks.update(IDENT.findall(STRING.sub(" ", parts[1] if len(parts) > 1 else "")))
    keep = {t for t in toks if re.match(r"(FLAG|VAR|SPECIAL|ITEM|TRAINER|MAP|OBJ|MOVE|SPECIES)_", t)}
    cmds = {line.split()[0] for line in body}
    specials = {line.split()[1].rstrip(",") for line in body
                if line.split()[0] in ("special", "specialvar") and len(line.split()) > 1}
    return sorted(keep), sorted(cmds), sorted(specials)


def map_of(path):
    m = re.match(r"data/maps/([^/]+)/", path)
    return m.group(1) if m else None


def diff_lines(old, new):
    rem, add = list(old), []
    for line in new:
        if line in rem:
            rem.remove(line)
        else:
            add.append(line)
    return rem, add


def event_key(kind, ev):
    if kind == "warp_events":
        return (ev.get("x"), ev.get("y"), ev.get("dest_map"), ev.get("dest_warp_id"))
    return tuple(sorted((k, str(v)) for k, v in ev.items()))


def report_events(name, old_map, new_map, old_tree, new_tree, out):
    for kind in ("object_events", "warp_events", "coord_events", "bg_events"):
        olds, news = old_map.get(kind) or [], new_map.get(kind) or []
        ok, nk = [event_key(kind, e) for e in olds], [event_key(kind, e) for e in news]
        if ok == nk:
            continue
        removed = [i for i, k in enumerate(ok) if k not in nk]
        added = [i for i, k in enumerate(nk) if k not in ok]
        out.append(f"  EVENTS {kind}: {len(olds)} -> {len(news)}")
        for i in removed:
            ev = olds[i]
            desc = ev.get("script") or ev.get("graphics_id") or ev.get("dest_map")
            out.append(f"    removed [{i}] {desc} at ({ev.get('x')},{ev.get('y')}) flag={ev.get('flag')}")
        for i in added:
            out.append(f"    added   [{i}] {news[i]}")
        shifts = []
        for i, k in enumerate(ok):
            if k in nk and nk.index(k) != i:
                shifts.append((i, nk.index(k)))
        if shifts:
            out.append("    shifted " + ", ".join(f"{a}->{b}" for a, b in shifts))
        if kind == "warp_events" and shifts:
            map_const = new_map.get("id")
            for other, m in new_tree.maps.items():
                for j, w in enumerate(m.get("warp_events") or []):
                    if w.get("dest_map") == map_const and int(w.get("dest_warp_id", 0)) in {a for a, _ in shifts}:
                        out.append(f"    ! {other} warp[{j}] targets shifted warp {w['dest_warp_id']}")
        if kind == "object_events" and (shifts or removed):
            first = min([a for a, _ in shifts] + removed) + 1
            pattern = re.compile(r"\b(?:applymovement|removeobject|addobject|showobjectat|hideobjectat|"
                                 r"setobjectxy|setobjectxyperm|turnobject|setobjectmovementtype|"
                                 r"copyobjectxytoperm|setobjectsubpriority|"
                                 r"resetobjectsubpriority|waitmovement)\s+(\d+)\b")
            for label, info in new_tree.labels.items():
                if map_of(info["file"]) != name:
                    continue
                for line in info["body"]:
                    m = pattern.search(line)
                    if m and int(m.group(1)) >= first:
                        out.append(f"    ? {label}: `{line}` uses raw local id {m.group(1)}")


def special_targets(rev):
    targets = {}
    for line in git("show", f"{rev}:data/specials.inc").splitlines():
        m = re.match(r"\s*def_special\s+(\w+)(.*)", strip_comment(line))
        if m:
            t = re.search(r"target=(\w+)", m.group(2))
            targets[m.group(1)] = t.group(1) if t else m.group(1)
    return targets


def report_specials(args, maps, new, new_reach):
    old_t, new_t = special_targets(args.old), special_targets(args.new)
    moved = {k: (v, new_t.get(k)) for k, v in old_t.items() if new_t.get(k) != v}
    if not moved:
        return
    print("SPECIALS retargeted or removed: " + ", ".join(f"{k} {a}->{b}" for k, (a, b) in sorted(moved.items())))
    for label in sorted(new_reach):
        info = new.labels[label]
        if map_of(info["file"]) not in maps:
            continue
        for line in info["body"]:
            parts = line.replace(",", " ").split()
            if parts and parts[0] in ("special", "specialvar") and parts[-1] in moved:
                print(f"  ! {label}: `{line}` now calls {moved[parts[-1]][1]}")


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("old")
    ap.add_argument("new")
    ap.add_argument("--maps", default=".", help="regex on map folder names")
    ap.add_argument("--live-only", action="store_true", help="hide DEAD removals and NOOP lines")
    args = ap.parse_args()
    maps_re = re.compile(args.maps)

    changed = git("diff", "--name-only", args.old, args.new, "--", "data/maps").splitlines()
    maps = sorted({map_of(p) for p in changed if map_of(p) and maps_re.match(map_of(p))})
    old, new = Tree(args.old), Tree(args.new)
    old_reach = old.reachable()
    new_reach = new.reachable()

    totals = defaultdict(int)
    for name in maps:
        out = []
        path = f"data/maps/{name}/scripts.inc"
        old_labels = old.order.get(path, [])
        new_labels = set(new.order.get(path, []))
        for label in old_labels:
            obody = old.labels[label]["body"]
            if label in new_labels:
                nbody = new.labels[label]["body"]
                if obody != nbody:
                    rem, add = diff_lines(obody, nbody)
                    live = label in old_reach
                    out.append(f"  CHANGED {label} ({kind_of(obody)}, {'LIVE' if live else 'DEAD'})")
                    totals["changed"] += 1
                    for line in rem:
                        refs = [t for t in IDENT.findall(STRING.sub(" ", line)) if t in old.labels and t != label]
                        noop = refs and all(is_noop(old, r) for r in refs) and line.split()[0] in (
                            "map_script", "map_script_2", "call", "goto")
                        if noop and args.live_only:
                            continue
                        out.append(f"    - {line}" + ("   NOOP" if noop else ""))
                    for line in add:
                        out.append(f"    + {line}")
                if falls_through(nbody):
                    onext, nnext = old.next_label(label), new.next_label(label)
                    if onext != nnext or (nnext and old.labels.get(onext, {}).get("body") != new.labels[nnext]["body"]):
                        out.append(f"  FALLTHRU {label}: next label {onext} -> {nnext}")
                        totals["fallthru"] += 1
            else:
                live = label in old_reach
                totals["removed_live" if live else "removed_dead"] += 1
                if not live and args.live_only:
                    continue
                k = kind_of(obody)
                tag = "LIVE" if live else "DEAD"
                if live and is_noop(old, label):
                    tag = "LIVE-NOOP"
                out.append(f"  REMOVED {label} ({k}, {tag})")
                if live:
                    out.append(f"    path: {path_to(old_reach, label)}")
                    if k == "script":
                        consts, cmds, specials = symbols_used(obody)
                        out.append(f"    cmds: {' '.join(cmds)}")
                        if specials:
                            out.append(f"    specials: {' '.join(specials)}")
                        if consts:
                            out.append(f"    consts: {' '.join(consts)}")
        for label in new.order.get(path, []):
            if label not in old.labels:
                out.append(f"  ADDED {label} ({kind_of(new.labels[label]['body'])})")
        if name in old.maps and name in new.maps:
            report_events(name, old.maps[name], new.maps[name], old, new, out)
        elif name in old.maps:
            out.append("  MAP DELETED")
            refs = [o for o, m in new.maps.items()
                    for w in m.get("warp_events") or [] if w.get("dest_map") == old.maps[name].get("id")]
            if refs:
                out.append(f"    ! still warped to from {sorted(set(refs))}")
        live_new = [l for l in new.order.get(path, []) if l not in new_reach and l in old_reach]
        for label in live_new:
            out.append(f"  ORPHANED {label}: reachable before, unreachable now")
            totals["orphaned"] += 1
        if out:
            print(name)
            print("\n".join(out))
    report_specials(args, set(maps), new, new_reach)
    print("TOTALS " + " ".join(f"{k}={v}" for k, v in sorted(totals.items())), file=sys.stderr)


if __name__ == "__main__":
    main()
