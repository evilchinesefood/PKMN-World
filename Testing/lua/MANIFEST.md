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
  make symbols        # once per build — refresh addresses
  EmuHawk.exe <rom> --lua=<repo>\Testing\lua\<Suite>.lua
  ```
  Logs + screenshots land in `_pwtest/` (gitignored scratch) — test *output* is never committed.

## Suites

| Suite | Kind | What it proves |
|---|---|---|
| `SmokeBoot.lua` | **evidence** | symbols + lib load on a fresh build; boot to hub, empty party, step + object dump read correctly. The harness self-test. |
| `MigrateFixtures.lua` | **evidence** | Loading each historical save format (v1..v5, real `.srm` fixtures under `fixtures/`) migrates cleanly to the current `SAVE_FORMAT_VERSION`: one asserted value per un-checksummed SaveBlock3 bank + `currentRegion` + `saveVersion`. The guard rail for any future save-format bump. |

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
