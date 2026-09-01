#!/usr/bin/env python3
"""Host-side pin for exclusive-choice gift QoL (#240).

Dojo Hitmons and Mt. Moon fossils must both be obtainable. Regional starters
must stay exclusive. No SaveBlock layout change (existing per-slot flags only).

Run from the repo root: python3 Testing/ValidateGreedyGifts.py
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DOJO = os.path.join(ROOT, "data/maps/SaffronCity_Dojo_Frlg/scripts.inc")
MTMOON = os.path.join(ROOT, "data/maps/MtMoon_B2F_Frlg/scripts.inc")
FUCHSIA = os.path.join(ROOT, "data/maps/FuchsiaCity_Frlg/scripts.inc")
CINNABAR = os.path.join(ROOT, "data/maps/CinnabarIsland_PokemonLab_ExperimentRoom_Frlg/scripts.inc")
OAK = os.path.join(ROOT, "data/maps/PalletTown_ProfessorOaksLab_Frlg/scripts.inc")
ELM = os.path.join(ROOT, "data/maps/NewBarkTown_Lab/scripts.inc")
BIRCH = os.path.join(ROOT, "data/maps/LittlerootTown_ProfessorBirchsLab/scripts.inc")


def read(path):
    with open(path, encoding="utf-8", errors="replace") as fh:
        return fh.read()


def script_body(text, name):
    m = re.search(rf"^{re.escape(name)}::\s*$", text, re.M)
    if not m:
        return None
    rest = text[m.end():]
    nxt = re.search(r"^[A-Za-z0-9_]+::\s*$", rest, re.M)
    return rest[:nxt.start()] if nxt else rest


def main():
    bad = []

    dojo = read(DOJO)
    lee = script_body(dojo, "SaffronCity_Dojo_EventScript_HitmonleeBall")
    chan = script_body(dojo, "SaffronCity_Dojo_EventScript_HitmonchanBall")
    koichi = script_body(dojo, "SaffronCity_Dojo_EventScript_MasterKoichi")
    if lee is None or chan is None or koichi is None:
        bad.append("Dojo Hitmonlee/Hitmonchan/Koichi scripts missing")
    else:
        if "FLAG_GOT_HITMON_FROM_DOJO" in lee:
            bad.append("HitmonleeBall still locks on shared FLAG_GOT_HITMON_FROM_DOJO")
        if "FLAG_HIDE_DOJO_HITMONLEE_BALL" not in lee:
            bad.append("HitmonleeBall does not guard on FLAG_HIDE_DOJO_HITMONLEE_BALL")
        if "FLAG_GOT_HITMON_FROM_DOJO" in chan:
            bad.append("HitmonchanBall still locks on shared FLAG_GOT_HITMON_FROM_DOJO")
        if "FLAG_HIDE_DOJO_HITMONCHAN_BALL" not in chan:
            bad.append("HitmonchanBall does not guard on FLAG_HIDE_DOJO_HITMONCHAN_BALL")
        if "setflag FLAG_GOT_HITMON_FROM_DOJO" not in dojo:
            bad.append("Dojo no longer sets FLAG_GOT_HITMON_FROM_DOJO on receive")
        if "FLAG_GOT_HITMON_FROM_DOJO" not in koichi:
            bad.append("Koichi no longer recognizes FLAG_GOT_HITMON_FROM_DOJO")
    if "Better not get greedy" in dojo:
        bad.append("Dojo still has the anti-greedy line")

    mtmoon = read(MTMOON)
    ontrans = script_body(mtmoon, "MtMoon_B2F_OnTransition")
    dome = script_body(mtmoon, "MtMoon_B2F_EventScript_DomeFossil")
    helix = script_body(mtmoon, "MtMoon_B2F_EventScript_HelixFossil")
    if ontrans is None or dome is None or helix is None:
        bad.append("Mt. Moon OnTransition/Dome/Helix scripts missing")
    else:
        if "FLAG_GOT_FOSSIL_FROM_MT_MOON" in ontrans:
            bad.append("Mt. Moon OnTransition still gates both fossils on FLAG_GOT_FOSSIL_FROM_MT_MOON")
        if "FLAG_GOT_DOME_FOSSIL" not in ontrans or "FLAG_GOT_HELIX_FOSSIL" not in ontrans:
            bad.append("Mt. Moon OnTransition does not show fossils from per-slot GOT flags")
        if "removeobject LOCALID_HELIX_FOSSIL" in dome:
            bad.append("Taking Dome still removeobjects the Helix fossil")
        if "removeobject LOCALID_DOME_FOSSIL" in helix:
            bad.append("Taking Helix still removeobjects the Dome fossil")
        if "LOCALID_MIGUEL" in dome or "LOCALID_MIGUEL" in helix:
            bad.append("Taking a fossil still warps Miguel onto the leftover")
        if "setflag FLAG_GOT_DOME_FOSSIL" not in dome:
            bad.append("Dome take no longer sets FLAG_GOT_DOME_FOSSIL")
        if "setflag FLAG_GOT_HELIX_FOSSIL" not in helix:
            bad.append("Helix take no longer sets FLAG_GOT_HELIX_FOSSIL")
    if "No being greedy" in mtmoon:
        bad.append("Mt. Moon still has the anti-greedy line")
    if "Then this fossil is mine" in mtmoon:
        bad.append("Mt. Moon still has Miguel claiming the leftover fossil")
    miguel = script_body(mtmoon, "MtMoon_B2F_EventScript_Miguel")
    if miguel is None:
        bad.append("Mt. Moon Miguel script missing")
    elif "FLAG_GOT_FOSSIL_FROM_MT_MOON" in miguel:
        bad.append("Miguel still treats FLAG_GOT_FOSSIL_FROM_MT_MOON as fully done after one fossil")
    elif "FLAG_GOT_DOME_FOSSIL" not in miguel or "FLAG_GOT_HELIX_FOSSIL" not in miguel:
        bad.append("Miguel does not wait for both GOT fossil flags before the Cinnabar line")

    fuchsia = read(FUCHSIA)
    sign = script_body(fuchsia, "FuchsiaCity_EventScript_FossilMonSign")
    sign_has_dome = script_body(fuchsia, "FuchsiaCity_EventScript_FossilMonSignHasDome")
    sign_both = script_body(fuchsia, "FuchsiaCity_EventScript_FossilMonSignBoth")
    sign_all = "".join(s or "" for s in (sign, sign_has_dome, sign_both))
    if sign is None:
        bad.append("Fuchsia fossil exhibit sign missing")
    elif "FLAG_GOT_HELIX_FOSSIL" not in sign_all:
        bad.append("Fuchsia fossil sign does not handle owning both fossils (FLAG_GOT_HELIX_FOSSIL)")

    cinnabar = read(CINNABAR)
    helix_check = script_body(cinnabar, "CinnabarIsland_PokemonLab_ExperimentRoom_EventScript_CheckRevivedHelix")
    if helix_check is None:
        bad.append("Cinnabar CheckRevivedHelix missing")
    elif "FLAG_GOT_DOME_FOSSIL" not in helix_check:
        bad.append("Cinnabar Helix-revived path never requires Dome when FLAG_GOT_DOME_FOSSIL is set")

    # Regional starters stay exclusive.
    elm = read(ELM)
    birch = read(BIRCH)
    oak = read(OAK)
    if "Probably shouldn't touch" not in elm:
        bad.append("Elm lab starter lock text missing; regional starters must stay exclusive")
    if "Better leave the others alone" not in birch:
        bad.append("Birch Johto-trio lock text missing; regional starters must stay exclusive")
    if "VAR_MAP_SCENE_PALLET_TOWN_PROFESSOR_OAKS_LAB" not in oak:
        bad.append("Oak lab starter scene-var lock missing; regional starters must stay exclusive")

    if bad:
        for b in bad:
            sys.stderr.write(f"FAIL {b}\n")
        return 1
    print("OK — Dojo and Mt. Moon gifts are per-slot, Cinnabar/Fuchsia follow both fossils, "
          "starters stay exclusive.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
