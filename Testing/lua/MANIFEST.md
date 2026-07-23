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
version's commit (see `MakeMigrationFixtures.sh`) — no personal data, deterministic. They are the
inputs to `MigrateFixtures.lua`. When the format is bumped, add the previous version's fixture
here and extend the suite (this is the step Session C / issue #16 performs for v6).

## Not promoted

The `_pwtest/` corpus (~250 scripts) stays gitignored scratch by design: those suites drive
specific mid-playthrough saves (Battle Net floors, Mt Mortar shards, gym rematches) that a fresh
clone can't reproduce, so they can't satisfy the "runs on a fresh build" bar. Their durable
techniques are captured in `lib.lua` and `../BizHawkTesting.md`.
