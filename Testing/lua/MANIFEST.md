# Testing/lua — tracked BizHawk/Lua suites

Reproducible, fresh-clone-runnable test suites for PKMN-World. Unlike the gitignored `_pwtest/`
scratch (which encodes specific playthrough saves + screenshots and rots per build), everything
here runs against a **fresh new-game on the current build with no address edits**.

## How it works

- **`symbols.lua`** — generated per build from `pokemonworld.elf` (`make symbols`, see
  `Testing/GenLuaSymbols.py`). Holds the runtime addresses that move on every rebuild, plus a
  curated ABI-fixed struct-offset table. **Generated artifact — gitignored, never committed.**
- **`lib.lua`** — shared helpers (boot loop, coordinate-verified stepping, the two debug spinners,
  cursor-verified multichoice, screenshots, object dumps, bag scans, assertion + verdict). Every
  suite does `local F = require("lib").new(require("symbols"), "SuiteName")`.
- Each suite bootstraps `require` to find `symbols`/`lib` next to itself, so it is launched simply:
  ```
  make -j12                                     # symbols.lua is now a prerequisite of `rom`
  cp pokemonworld.gba  BizHawk\Verify1.gba      # a THROWAWAY copy — see the two guards below
  EmuHawk.exe BizHawk\Verify1.gba --lua=<repo>\Testing\lua\<Suite>.lua
  ```
  Logs + screenshots land in `_pwtest/` (gitignored scratch) — test *output* is never committed.
  `lib.lua` creates `_pwtest/` if a fresh clone lacks it, and warns loudly if it still cannot write.

### Two guards that will abort a run (issue #31)

1. **ROM/symbols binding.** `symbols.lua` records the MD5 of the `.gba` it was generated from and
   `lib.new()` refuses to run against any other ROM. Without this, the normal accident — rebuild,
   launch a stale hand-copy — boots fine and reports every test green while exercising the
   *previous* build's code, because `gSaveblock3` is a fixed EWRAM symbol. `symbols.lua` is now a
   prerequisite of `rom`, so `make -j12` keeps it fresh; `make symbols` alone is no longer needed.
2. **Throwaway-ROM allowlist.** The ROM basename must match `Verify*`, `MigChk*` or `FixGen*`.
   `boot()` blind-presses A and Start for up to 120,000 frames, the shipped save profile has SAVE
   at wheel slot 2 of 4, and BizHawk flushes SaveRAM on exit — so pointing a suite at the real
   ROM/save pair is a live clobber path that has already happened once. Override deliberately with
   `opts.allowAnyRom = true`.

### Machine-readable verdict

`finish()` writes `_pwtest\<Suite>.PASS` or `.FAIL` (with the failing assertion names) and exits
non-zero on failure, so a wrapper or hook can gate on a run without parsing the log. Zero
assertions counts as a FAIL — a suite that aborted early must not report a perfect `0/0`.

## Suites

| Suite | Kind | What it proves |
|---|---|---|
| `SmokeBoot.lua` | **evidence** | symbols + lib load on a fresh build; boot to hub, empty party, step + object dump read correctly. The harness self-test. |
| `MigrateFixtures.lua` | **evidence** | That a pre-v7 save is **refused**, not half-loaded. Save format v7 reshaped SaveBlock1 and the owner chose new-saves-only, so `SAVE_FORMAT_LAYOUT_MIN` in `src/save.c` rejects older saves and the v0..v6 migration ladder is now unreachable. This suite was rewritten to assert the gate rather than a migration that can no longer happen. Any pre-v7 fixture works (v3/v4/v5 are all below the floor). |
| `VerifyBagLayout.lua` | **evidence** | Issue #24's expanded bag + item PC really shipped (Items 60 / Key Items 99 / PC 150), and a slot past the old 30-slot cap survives a save + core reboot. |

> **Why pointer gaps and not just capacities:** `gBagPockets[p].capacity` is assigned from
> `BAG_*_COUNT` at runtime, so reading it back only proves the *constant* changed. What #24
> actually did was resize `struct Bag` inside SaveBlock1. Consecutive pockets are contiguous
> fields, so the gap between two pocket pointers **is** the earlier pocket's real slot count x 4 —
> that distinguishes "the header says 99" from "the save block genuinely holds 99". The suite also
> pins `bag` at `+0x6F8`, which is the runtime check on the `include/global.h` offset comments
> (they were stale for the whole life of the expansion and read `0x568`, a pre-expansion value).
>
> **Occupancy is seeded by a direct RAM write, deliberately.** Driving `PC/Bag -> Fill...` was
> tried first and is not usable as evidence: debug submenu cursor state is documented to persist
> between opens, so a run where the fill silently never fires reports `occupied=0` — which is
> indistinguishable from a real defect. It produced exactly that false negative once.

> **Why the gate needs a test at all:** `bag` and `pcItems` both live in SaveBlock1 **chunk 0**, and
> `SAVEBLOCK_CHUNK` only varies the *last* chunk's size. So chunks 0-2 keep size 3968, their stored
> checksums still match the flash bytes, and a legacy save loads *successfully* into the shifted
> layout — only chunk 3 fails. The result is a half-loaded save with silently misaligned flags and
> vars. The checksum is not a gate; `SAVE_FORMAT_LAYOUT_MIN` is.

**Kind** = `evidence` (asserts a real, load-bearing contract) vs `probe` (exploratory/diagnostic;
its failures may be harness quirks, not defects).

## Fixtures (`fixtures/`)

Each `vN.srm` is the raw 131072-byte battery save from a **fresh new-game** built at that format
version's commit (see `../MakeMigrationFixtures.sh`) — no personal data, deterministic. They are
the inputs to `MigrateFixtures.lua`. When the format is bumped, add the previous version's fixture
here and extend the suite (this is the step Session C / issue #16 performs for v6).

Present: **v3, v4, v5** — each verified to migrate cleanly to the current version (8/8).

Gaps (documented, not silent):
- **v2** — its introducing commit (`12e04c20`) does not build with the current tree
  (`ItemUseOutOfBattle_SkyCharm` was declared a commit later); a historical commit is never
  patched to harvest a fixture.
- **v1** — its commit (`37af5518`) predates the region hub, so a fresh new-game runs the full
  classic Hoenn intro (truck → clock → Birch → starter) before the START menu can save; driving
  that headlessly wasn't attempted here. v1 is the only entry point that would exercise the
  v1→v2 (usmSaved) and v2→v3 (kantoTrainerFlags) ladder steps as a starting version.

**Sabotage-test note (folded #21):** fresh-new-game fixtures have mostly-zero SaveBlock3 banks, so
each `savedVersion < N` ladder step (which *zeros* a newly-appended field) is a no-op on them —
removing a step is not caught, because the field was already zero. What these fixtures DO catch
is **layout drift**: `MigrateFixtures.lua` reads each bank at its named offset, so a field
inserted/reordered before a bank shifts the reads and the exact `== 0` / `== version` asserts fail
loudly. That is the guard rail #16 needs for the v7 bump. A stronger step-level sabotage would
require a played (non-fresh) save, which would put personal data in the repo — out of scope.

## Not promoted

The `_pwtest/` corpus (~250 scripts) stays gitignored scratch by design: those suites drive
specific mid-playthrough saves (Battle Net floors, Mt Mortar shards, gym rematches) that a fresh
clone can't reproduce, so they can't satisfy the "runs on a fresh build" bar. Their durable
techniques are captured in `lib.lua` and `../BizHawkTesting.md`.
