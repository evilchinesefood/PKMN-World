#!/usr/bin/env bash
# Run a Testing/lua suite headlessly under mGBA (macOS/arm64 stand-in for BizHawk).
#
#   Testing/mgba-run.sh Testing/lua/SmokeBoot.lua [pokemonworld.gba]
#
# BizHawk has no macOS build, so the suites run under `mgba-headless --script` with
# Testing/lua/mgba_shim.lua providing the EmuHawk API. See Testing/mgba/README.md.
#
# Save safety (BizHawkTesting.md §2): a suite blind-presses A and Start for thousands of frames,
# and the shipped save profile puts SAVE at wheel slot 2 -- pointing one at the real ROM is a
# live clobber path. So we never drive the build output directly. The ROM is copied into a
# throwaway work dir under a Verify* name, which is also what lib.lua's ROM_ALLOWLIST expects,
# and any save the run produces dies with that directory.
set -euo pipefail

SUITE="${1:?usage: mgba-run.sh <suite.lua> [rom.gba] [save.srm]}"
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROM="${2:-$REPO/pokemonworld.gba}"
# Suites that exercise a migration ladder or read an existing profile need a battery save to
# boot into -- without one they land on NEW GAME and report BOOT FAIL. Fixtures live in
# Testing/lua/fixtures/*.srm (raw 128KB flash images, which is already mGBA's .sav format).
SAVE="${3:-${PW_SAVE:-}}"

[[ -f "$SUITE" ]] || { echo "no such suite: $SUITE" >&2; exit 2; }
[[ -f "$ROM"   ]] || { echo "no such ROM: $ROM (run 'make modern' first)" >&2; exit 2; }
[[ -z "$SAVE" || -f "$SAVE" ]] || { echo "no such save: $SAVE" >&2; exit 2; }

MGBA="${MGBA_HEADLESS:-$(command -v mgba-headless || true)}"
[[ -n "$MGBA" ]] || { echo "mgba-headless not found; see Testing/mgba/README.md" >&2; exit 2; }

WORK="$(mktemp -d "${TMPDIR:-/tmp}/pwtest.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

# The name must match ^Verify/^MigChk/^FixGen or lib.lua refuses to drive it.
cp "$ROM" "$WORK/Verify1.gba"
# mGBA autoloads the battery save sitting beside the ROM as <basename>.sav. Copying rather than
# symlinking matters: the run writes back to it, and the fixtures are tracked files.
[[ -n "$SAVE" ]] && cp "$SAVE" "$WORK/Verify1.sav"

OUT="${PW_OUT:-$REPO/_pwtest}"
mkdir -p "$OUT"

# lib.lua compares this against its expected-build hash to catch the stale-ROM trap.
export PW_SUITE="$(cd "$(dirname "$SUITE")" && pwd)/$(basename "$SUITE")"
export PW_ROM_NAME="Verify1"
export PW_ROM_HASH="$(md5 -q "$ROM" | tr '[:lower:]' '[:upper:]')"
export PW_OUT="$OUT"

echo "suite : $PW_SUITE"
echo "rom   : $ROM"
echo "md5   : $PW_ROM_HASH"
echo "out   : $OUT"

# Pin the console clock. Emerald seeds its RNG from the RTC at boot and the seed drives NPC
# movement, so an unpinned (wall-clock) RTC makes any suite that walks past an NPC flaky --
# TinTowerRoof scored 3/5, 27/27, 27/27 on three identical back-to-back runs before this.
# --rtc advances the clock off the emulated frame counter, so it still moves for the day/night
# suites but lands on the same value every run. Override with PW_RTC to test a different time.
# Default: 2024-01-01 12:00:00 UTC.
RTC="${PW_RTC:-1704110400}"
echo "rtc   : $RTC ($(date -r "$RTC" '+%Y-%m-%d %H:%M:%S %Z'))"
echo "---"

# -l 0 silences mGBA's per-DMA/BIOS chatter; console.log from the suite still reaches stdout.
set +e
"$MGBA" -l 0 --rtc "$RTC" --script "$REPO/Testing/lua/mgba_shim.lua" "$WORK/Verify1.gba"
rc=$?
set -e

echo "---"
echo "exit code: $rc"
exit $rc
