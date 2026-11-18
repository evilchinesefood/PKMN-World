#!/usr/bin/env python3
"""Run source/content checks without evaluating the game Makefile."""

from pathlib import Path
import subprocess
import sys
import time


ROOT = Path(__file__).resolve().parents[1]
CHECKS = (
    ("TestCaseInventory.py",),
    ("TestVerificationModes.py",),
    ("ValidateGen13.py",),
    ("ValidateRegionalCenters.py",),
    ("TestRegionalTravelMigration.py",),
    ("TestFamilyOptionsMigration.py",),
    ("TestXRegionSaveRepair.py",),
    ("MakeRegionalTravelFixture.py", "--check"),
    ("story-progress/run.py",),
    ("ValidateScripts.py",),
    ("ValidateOwMonPlacements.py",),
    ("ValidateMapEvents.py",),
    ("ValidateZoneStructure.py",),
    ("ValidateRoute41Surf.py",),
    ("ValidateMetatileBounds.py",),
    ("ValidateBorderTerrain.py",),
    ("ValidateReachability.py",),
    ("ValidateAmbientBlockers.py",),
    ("GenObstacleTable.py", "--check"),
    ("ValidateDoorAnims.py", "--max", "0"),
    ("ValidateTilesetAnimBounds.py",),
    ("ValidateTilesetPalettes.py",),
    ("HnsMetatileBehaviors.py",),
    ("SavePatch.py", "--check"),
    ("ValidateCelioGifts.py",),
    ("ValidateGreedyGifts.py",),
    ("AuditDupKeyGifts.py",),
    ("TestChampionshipPrizes.py",),
    ("special-pokemon/sources.py",),
    ("special-pokemon/mechanics_audit.py",),
    ("ValidateRegionMap.py",),
    ("ValidateRegionText.py",),
    ("ValidateLanceMultiBattle.py",),
    ("ScanInputChords.py", "--check"),
    ("ValidateEllipsis.py",),
    ("ValidateTextWidth.py",),
    ("ValidateConfigRules.py",),
    ("AuditEngineRegionText.py", "--check"),
    ("ValidateDeadEvoItems.py",),
    ("ValidateBattleScenes.py",),
    ("ValidateFrostyGrass.py",),
    ("ValidateCutGrass.py",),
)


def main():
    started = time.monotonic()
    failed = []
    for script, *args in CHECKS:
        print(f"HOST CHECK {script} {' '.join(args)}", flush=True)
        result = subprocess.run(
            [sys.executable, str(ROOT / "test/overworld" / script), *args],
            cwd=ROOT,
        )
        if result.returncode:
            failed.append(script)
    print(f"Host validation: {len(CHECKS) - len(failed)}/{len(CHECKS)} passed "
          f"in {time.monotonic() - started:.1f}s", flush=True)
    print("No game build, battle test, or emulator coverage was requested.", flush=True)
    if failed:
        print("Failed: " + ", ".join(failed), file=sys.stderr)
    return bool(failed)


if __name__ == "__main__":
    raise SystemExit(main())
