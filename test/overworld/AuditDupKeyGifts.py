#!/usr/bin/env python3
"""Audit every scripted give of a key-class item that the player can already own.

One bag serves all three regions, and IsDuplicateKeyClassItem (src/item.c) refuses a second
copy of any key-class item (Key Items pocket or HM01-HM08, minus its listed exemptions). The
refusal is safe for the item but not for the scene: `giveitem` routes through Std_ObtainItem,
which prints "But {PLAYER} already has one ..." in the middle of the speaker's lines, and
`giveitem_msg` plays the fanfare and says "received" for an item that never lands.

This lists every give site of a key-class item (giveitem, givekeyitem, giveitem_msg, additem,
finditem), the other sites that hand out the same item, and the map region of each. Item names
are resolved through ITEM_HM_<MOVE> and the Johto compat ids. A give whose item is a variable
is not resolved (none of those sites hands out a key-class item today). An item with more than
one live source can already be owned when any of its sites runs, so each such site must be:

  guarded      every path into the give passes `checkitem <item>` with a test on the result,
               so the scene can speak for itself when the player already has one;
  giver line   givekeyitem: Common_EventScript_GiveKeyItem has the giver say "Oh, you already
               have ...! Then you're all set." (the HM givers, whose scenes read on from it);
  item ball    finditem: Std_FindItem's EventScript_FoundDupKeyItem says the ball held one and
               the player already has one, with no speaker to contradict;
  allowlisted  checked by hand: the other source is unreachable once this one ran (shared
               flags, an earlier removeitem, mutually exclusive branches), listed with why.

Run from the repo root: python3 test/overworld/AuditDupKeyGifts.py [--all]
--all prints every key-class give site, single-source items included.
Exit status 1 when a multi-source site is unhandled or an allowlist entry is stale.
"""
import json
import os
import re
import sys
from collections import defaultdict

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import AuditCapacity as AC  # noqa: E402

ROOT = AC.ROOT
GIVE_OPS = {"giveitem": 0, "givekeyitem": 0, "giveitem_msg": 1, "additem": 0, "finditem": 0}
CANON = None
STD_FILES = {"data/scripts/obtain_item.inc", "data/scripts/item_ball_scripts.inc"}

# (file, label, item) -> why the site cannot meet a copy from another source.
ALLOWLIST = {
    # One shop bike across both regions: Rydel and the Goldenrod clerk share FLAG_RECEIVED_BIKE
    # (data/maps/GoldenrodCity/scripts.inc, src/load_save.c), so only one of them ever gives.
    ("data/maps/MauvilleCity_BikeShop/scripts.inc", "MauvilleCity_BikeShop_EventScript_GetMachBike", "ITEM_MACH_BIKE"):
        "FLAG_RECEIVED_BIKE is shared with the Goldenrod clerk; one shop bike across both regions",
    ("data/maps/MauvilleCity_BikeShop/scripts.inc", "MauvilleCity_BikeShop_EventScript_GetAcroBike", "ITEM_ACRO_BIKE"):
        "FLAG_RECEIVED_BIKE is shared with the Goldenrod clerk; one shop bike across both regions",
    ("data/maps/GoldenrodCity_BikeShop/scripts.inc", "GoldenrodCity_BikeShop_EventScript_Clerk_BikeAgreed", "ITEM_MACH_BIKE"):
        "FLAG_RECEIVED_BIKE is shared with Rydel; one shop bike across both regions",
    ("data/maps/MauvilleCity_BikeShop/scripts.inc", "MauvilleCity_BikeShop_EventScript_SwitchAcroForMach", "ITEM_MACH_BIKE"):
        "trade-in: removeitem of the only shop bike runs first",
    # Kurt takes the GS Ball (removeitem in his house) before he walks out and returns it.
    ("data/maps/AzaleaTown/scripts.inc", "AzaleaTown_EventScript_GSBall", "ITEM_GS_BALL"):
        "Kurt's house removeitem ITEM_GS_BALL runs before this return scene",
    # Brendan and May are one rival per save.
    ("data/maps/LavaridgeTown/scripts.inc", "LavaridgeTown_EventScript_MayGiveGoGoggles", "ITEM_GO_GOGGLES"):
        "rival branch by player gender; one of the two runs",
    ("data/maps/LavaridgeTown/scripts.inc", "LavaridgeTown_EventScript_BrendanGiveGoGoggles", "ITEM_GO_GOGGLES"):
        "rival branch by player gender; one of the two runs",
    # Daisy's map and Celio's map: Celio gives one only while the Pallet scene var is below 2
    # (Daisy's give sets it to 2), and his give sets FLAG_HIDE_TOWN_MAP, which removes Daisy's.
    ("data/maps/PalletTown_RivalsHouse_Frlg/scripts.inc", "PalletTown_RivalsHouse_EventScript_GiveTownMap", "ITEM_TOWN_MAP"):
        "Celio's copy sets FLAG_HIDE_TOWN_MAP, which removes this one",
    ("data/maps/OneIsland_PokemonCenter_1F_Frlg/scripts.inc", "OneIsland_PokemonCenter_1F_EventScript_ReceiveTownMap", "ITEM_TOWN_MAP"):
        "called only while VAR_MAP_SCENE_PALLET_TOWN_RIVALS_HOUSE < 2 (Daisy never gave hers) or on a checkitem miss",
    # Celio's Tri-Pass beats are one scene and its missed-pass retry, keyed on the same flags.
    ("data/maps/OneIsland_PokemonCenter_1F_Frlg/scripts.inc", "OneIsland_PokemonCenter_1F_EventScript_MeetCelioScene", "ITEM_TRI_PASS"):
        "first Celio scene; the retry below runs only when this one could not give",
    # The Mega Ring re-give is reached only from a checkitem miss in the Director's repeat talk.
    ("data/maps/RegionHub_2F/scripts.inc", "BattleNet_EventScript_Director", "ITEM_MEGA_RING"):
        "first talk only (FLAG_BNET_DIRECTOR_INTRO); the re-give below runs on a checkitem miss",
}


def key_class_items():
    """Key-class item names, minus the exemptions IsDuplicateKeyClassItem returns FALSE for."""
    pockets = AC.load_pockets()
    src = open(os.path.join(ROOT, "src/item.c"), encoding="utf-8").read()
    body = src[src.index("bool32 IsDuplicateKeyClassItem("):]
    body = body[:body.index("\n}\n")]
    exempt = set(re.findall(r"itemId == (ITEM_\w+)\)\s*\n\s*return FALSE;", body))
    exempt |= set(re.findall(r"case (ITEM_\w+):", body))
    keys = {n for n, p in pockets.items() if p == "POCKET_KEY_ITEMS"}
    keys |= {"ITEM_HM0%d" % i for i in range(1, 9)}
    return keys - exempt, exempt


def item_aliases():
    """Alias name -> canonical item name: ITEM_HM_<MOVE> -> ITEM_HM0n and the Johto compat ids."""
    alias = {}
    tms = open(os.path.join(ROOT, "include/constants/tms_hms.h"), encoding="utf-8").read()
    hms = tms[tms.index("#define FOREACH_HM"):]
    hms = hms[:hms.index("\n\n")]
    for n, move in enumerate(re.findall(r"F\((\w+)\)", hms), 1):
        alias["ITEM_HM_" + move] = "ITEM_HM%02d" % n
    for fn in ("include/constants/johto_compat_ids.h",):
        for a, b in re.findall(r"^#define\s+(ITEM_\w+)\s+(ITEM_\w+)", open(os.path.join(ROOT, fn), encoding="utf-8").read(), re.M):
            alias[a] = b

    def canon(name):
        for _ in range(8):
            if name not in alias:
                return name
            name = alias[name]
        return name
    return canon


def mapsec_region():
    """GetRegionForSectionId (include/regions.h) over the MAPSEC enum.

    Reads the source JSON, not the generated header, so a clean checkout (CI) can run it; the
    generated enum lists the JSON's sections in the same order.
    """
    path = os.path.join(ROOT, "src/data/region_map/region_map_sections.json")
    sections = json.load(open(path, encoding="utf-8"))["map_sections"]
    order = {sec["id"]: i for i, sec in enumerate(sections)}

    def region(sec):
        i = order.get(sec)
        if i is None:
            return "None"
        if order["MAPSEC_PALLET_TOWN"] <= i < order["MAPSEC_SPECIAL_AREA"]:
            return "Kanto"
        if order["MAPSEC_NEW_BARK_TOWN"] <= i <= order["MAPSEC_JOHTO_INDIGO_PLATEAU"]:
            return "Johto"
        return "Hoenn"
    return region


def map_regions():
    regions, mentions = {}, defaultdict(set)
    base = os.path.join(ROOT, "data/maps")
    by_sec = mapsec_region()
    for d in os.listdir(base):
        path = os.path.join(base, d, "map.json")
        if not os.path.exists(path):
            continue
        header = json.load(open(path))
        region = header.get("region", "REGION_NONE").replace("REGION_", "").title()
        if region == "None":
            region = by_sec(header.get("region_map_section", ""))
        regions["data/maps/%s/scripts.inc" % d] = region
        for fn in ("map.json", "scripts.inc"):
            p = os.path.join(base, d, fn)
            if os.path.exists(p):
                for name in set(re.findall(r"\b\w+_EventScript_\w+\b", open(p, encoding="utf-8", errors="replace").read())):
                    mentions[name].add(region)
    return regions, mentions


def region_of(ins, entries, regions, mentions):
    if ins.file in regions:
        return regions[ins.file]
    found = set()
    for e in entries:
        found |= mentions.get(e, set())
    return "/".join(sorted(found)) if found else "shared"


def guarded(prog, preds, site, item, depth=80):
    """Every backward path from the give meets `checkitem item` whose result is tested."""
    stack = [(p, 0) for p in preds.get(site, [])]
    if not stack:
        return False
    seen = set()
    while stack:
        i, d = stack.pop()
        if i in seen:
            continue
        seen.add(i)
        ins = prog[i]
        if ins.op == "checkitem" and ins.args and CANON(ins.args[0]) == item and AC.forward_conds(prog, i):
            continue
        ps = preds.get(i, [])
        if d > depth or not ps:
            return False
        stack.extend((p, d + 1) for p in ps)
    return True


def main():
    show_all = "--all" in sys.argv
    prog, labels = AC.parse()
    preds = AC.build_preds(prog, labels)
    AC.LABELS, AC.PROG, AC.PREDS = labels, prog, preds
    keys, exempt = key_class_items()
    global CANON
    canon = CANON = item_aliases()
    refs = AC.referenced_names(prog)
    regions, mentions = map_regions()

    sites = defaultdict(list)
    for ins in prog:
        if ins.op not in GIVE_OPS or ins.file in STD_FILES or len(ins.args) <= GIVE_OPS[ins.op]:
            continue
        item = canon(ins.args[GIVE_OPS[ins.op]])
        if item not in keys:
            continue
        entries = AC.entry_labels(prog, preds, ins.idx)
        live = [e for e in entries if e in refs]
        if not live or all(e.startswith("Debug_") for e in live):
            continue
        sites[item].append((ins, region_of(ins, entries, regions, mentions)))

    bad, used, rows = [], set(), []
    for item in sorted(sites):
        group = sites[item]
        for ins, region in group:
            others = ["%s %s" % (r, o.label) for o, r in group if o is not ins]
            key = (ins.file, ins.label, item)
            if not others:
                verdict = "single source"
            elif ins.op == "finditem":
                verdict = "item ball"
            elif ins.op == "givekeyitem":
                verdict = "giver line"
            elif guarded(prog, preds, ins.idx, item):
                verdict = "guarded"
            elif key in ALLOWLIST:
                verdict = "allowlisted: " + ALLOWLIST[key]
                used.add(key)
            else:
                verdict = "UNHANDLED"
                bad.append((item, ins, region, others))
            if show_all or others:
                rows.append((item, region, ins, verdict, others))

    print("Key-class give sites with another source")
    print("| item | region | site | op | verdict | other sources |")
    print("|---|---|---|---|---|---|")
    for item, region, ins, verdict, others in rows:
        print("| %s | %s | %s %s | `%s` | %s | %s |" % (
            item, region, ins.where(), ins.label, ins.op, verdict, "; ".join(others) or "none"))
    multi = sum(1 for g in sites.values() if len(g) > 1)
    print()
    print("%d key-class items given by script, %d of them from more than one site; exempt from the "
          "duplicate refusal: %s." % (len(sites), multi, ", ".join(sorted(exempt)) or "none"))
    stale = [k for k in ALLOWLIST if k not in used]
    if bad:
        print("Unhandled duplicate gives (a second copy is refused mid-scene):")
        for item, ins, region, others in bad:
            print("  %s %s (%s) %s; also from %s" % (ins.where(), ins.label, region, item, "; ".join(others)))
    if stale:
        print("Stale allowlist entries (no longer match an unguarded multi-source site):")
        for k in stale:
            print("  %s" % (k,))
    return 1 if bad or stale else 0


if __name__ == "__main__":
    sys.exit(main())
