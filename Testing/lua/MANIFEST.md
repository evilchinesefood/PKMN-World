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

### Never call `bit.*` — it is deprecated and logs on EVERY call

BizHawk's Lua prints a deprecation warning for each `bit.band` / `bit.bxor` / `bit.lshift` call.
That is harmless once, and catastrophic inside a per-frame loop: a suite that read one bitfield per
frame emitted roughly 60 warnings a second for an hour, filled the Lua console, and took the host
machine down with it. Use the native Lua 5.4 operators instead — `&`, `|`, `~` (binary XOR and
unary NOT), `<<`, `>>`. `lib.lua` is clean; keep it that way.

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
| `BnetCounter2F.lua` | **evidence** | Issue #42's POKéMON CENTER 2F rewire, on **both** 2F layouts: the floor sim attendant is gone, the two right-hand counter slots open the type picker and the region picker *directly*, cancelling either returns control, a real Scaling match still pays 1 BP and returns to the retry prompt (the regression test for the shared payout body both slots now `call` across a battle), and a real Leader Sim win still pays 2 BP and **nothing else** — the whole bag is snapshotted either side, so the couch-farming invariant from #5 P3 is checked, not assumed. Supersedes the gitignored `_pwtest/BnetP4Terminals.lua` + `BnetP4Rerun.lua`, which walked to the deleted (11,4)/(11,5) NPC and cannot pass any more. |
| `HubIntroTour.lua` | **evidence** | Issue #41's World Transit intro tour, all five reachable paths on one fresh new game: the warp-in offer fires with **no input at all** on a brand-new game (the thing a `coord_event` alone cannot do, because coord events only fire on a step); declining releases the player on the crest, sets `FLAG_HUB_INTRO_TOUR_DONE` and stops the crest triggers for good; the Charm Curator's re-offer, declined, falls straight through to his normal HUB PASS + POKéVIAL gives; accepted, it walks the player back to the crest and runs all seven stops **in order** (the stop index only advances, so a tile matching a later stop early cannot fake a pass); the guide ends back at (22,7) facing down with **no stale held movement** — the issue-#42 trap — and stays there across a map reload; and with the flag cleared by hand, the crest `coord_event` still catches a walk-on, standing in for a legacy save that never saw the intro. |
| `VioletMart.lua` | **evidence** | Issue #48's Violet City mart clerk. The clerk ran `pokemart 0`, so `SetShopItemsForSale(NULL)` tripped its `assertf` and blue-screened right after "How may I serve you?" — a runtime-only failure that built, linked and booted clean, which is why a playtest was the only thing that ever found it. Asserts on `sMartInfo`, not on a screenshot: the assert's own recovery block leaves `itemCount` at 0 with the dummy list, so requiring a specific non-zero count and the exact item ids fails against the old build instead of passing vacuously. Covers **both** stock tiers, including the one normal play cannot reach — the shared Cherrygrove script branches on `VAR_NEWBARK_TOWN_STATE >= 5`, and New Bark's only land exit is gated on Mom's farewell (the sole writer of 5), so the 2-item tier is dead data in a real playthrough. A debug warp arrives with the var still 0 and gets it for free; the run then writes 5 and re-opens to check the 4-item list players actually see, which is also what proves the region-var write reached `GetVarPointer`'s SaveBlock3 branch rather than agreeing with itself. **★ Two traps this suite paid for:** `sMartInfo` is a `static` that KEEPS the last shop's list after it closes, so a second read returns the first shop's stock unless it is cleared first; and `gText_HowMayIServeYou` is `"Welcome!\pHow may I serve you?"` — the `\p` is a page break that waits for a button, so a single A press opens the conversation but never reaches `pokemart`. |
| `HubIntroTourFollower.lua` | **evidence** | The same escort with a **follower POKéMON out**. RegionHub has 14 object events against an `OBJECT_EVENTS_COUNT` of 16, so player + follower fills the sprite budget exactly, and a ~47-step scripted walk under that had never been run. Proves the follower spawns at all, that all seven stops still run with it out, that it is back out beside the player at the end, and that the guide still gets home. It also pins the **mechanism**: `ScrCmd_applymovement` pockets the follower for the whole escort (`ScriptHideFollower`, because nothing sets `FLAG_SAFE_FOLLOWER_MOVEMENT` here), so the suite asserts zero visible frames *and* a ≤1 tile gap over any frame it is visible — if a future change stops pocketing it, the visible count leaves zero and the gap check starts doing real work. **★ `active` is not `visible`:** a pocketed follower stays active in `gObjectEvents` parked on its last tile, so an active-only check reads it as still on the map and reports a phantom desync that grows as the player walks away. Read `invisible` (`ObjectEvent.flags1` bit 5). |
| `TinTowerRoof.lua` | **evidence** | Issue #50's deletion of `MAP_TIN_TOWER_ROOF_NIGHT`, driven at **both** day/night flag states on one fresh new game. The night pass reproduces the exact state the issue claimed would softlock — `FLAG_DAY_POKEMON` set, `FLAG_NIGHT_POKEMON` clear — and asserts the player still lands on `MAP_TIN_TOWER_ROOF_DAY`, the map that owns the Ho-Oh scripts. It then proves the roof still *works*: the layout swaps to the now **map-less** `LAYOUT_TIN_TOWER_ROOF_NIGHT` (which is why its `layouts.json` entry had to stay), `ON_TRANSITION` clears `FLAG_HIDE_HO_OH`, the kimono coord event fires, and Ho-Oh descends to (10,6) on both layouts — the descent being pure Day-map script, i.e. exactly what the deleted twin could never have run. Also pins the D3 weather fix (`WEATHER_SUNNY` by day, `WEATHER_NONE` by night), which `setmaplayoutindex` cannot do on its own. The Ho-Oh **battle** is deliberately not driven: a fresh save has an empty party and `BattleSetup_StartLegendaryBattle` has no 0-party guard. **★ Three traps this suite paid for:** `warpTo` checks group+map only, so calling it while already on the target map returns true having warped nobody *and* leaves the debug menu open, silently eating every later step; TinTower_8F **has wild encounters**, so a step along the only westward corridor is intermittently eaten (the stationary `MOVEMENT_TYPE_TOWER_BEAM` Rayquaza is a red herring — that constant is `#define`d to `MOVEMENT_TYPE_NONE`); and Ho-Oh reaching (10,6) is the *middle* of the cutscene, not the end, so asserting there catches the player still under `lockall` — with kimono girls on three sides, `ensureFree()` can never report free, so an actual northward step is the release test. |
| `VerifyPCScreen.lua` | **evidence** | Issue #47's building-PC screen animation, on the two layouts that were broken. Johto centres picked their PC metatile by **region**, so "not Kanto" fell through to Hoenn's `METATILE_Building_PC_On` (5) — and mt 5 in `gTileset_Johto_Building` is a plain `MB_NORMAL` wall, which is why the reported symptom was both "the screen looks wrong" *and* "I couldn't use it again until I left and came back": the tile stopped being a PC, and only a map reload restored the blockdata. `RegionHub`'s PC had a second, unrelated failure — `IsBuildingPCTile` hardcoded `isFrlg = FALSE`, so the hub's **u32** attributes were read as u16 and its PC reported behaviour `0x5A` instead of `MB_PC`, so neither detector fired and it never animated at all. The suite reads the **live map grid** (`gBackupMapLayout`) across the whole 5-flicker cadence rather than screenshotting, because the wrong metatile still draws *something* — a screenshot assert would pass on the broken build. The load-bearing checks are the ones that fail on the old ROM: mt 4/5 must **never** appear at a Johto PC tile, the tile must still read 98 after the PC closes, and the PC must **re-open without leaving the map**, which is the user-visible regression itself. |

| `DebugParty.lua` | **evidence** | Issue #44's debug party actions, in a real ROM. `DebugAction_Party_SetParty` filled `gParties` and never wrote `gPartiesCount`, so the game saw an empty party and the action failed **silently** — the menu just closed. This suite is the half `make check` structurally cannot cover: `battle_main.c` recomputes every party count from the array under `#if TESTING`, so the value self-corrects in a test build and the bug is only observable in a shipped ROM. Asserts the count on Set Party, that the follower spawns **on the same frame with no map reload** and is the party's lead (`graphicsId & 0x8FFF` == Wobbuffet), that Clear Party removes both count and follower, that Set → Clear → Set round-trips without leaving the map, and that a debug battle runs with a published player count. **★ Two traps this suite paid for:** the follower spawns *invisible under the player* and emerges on the first step, so sampling it after any `drain()` (which steps via `ensureFree()`) cannot tell "spawned hidden then stepped out" from "spawned visible" — sample before the drain; and Down + A pressed during the battle's send-out text is silently eaten, so the first run "opened" a party menu that was really still `Go! Buffie!` and the count assertion passed for the wrong reason. The menu is now proven open by `gMain.callback2` moving to `CB2_UpdatePartyMenu` and back, which a screenshot cannot establish — and closing it again is the anti-lockup check, since `maxMonIndex = count - 1` underflows to 255 at count 0. |

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

| `OwMonSprites.lua` | **evidence** | Issue #49's map-placed overworld Pokémon, on the six densest Johto maps. All 741 were authored with `OBJ_EVENT_GFX_OW_MON`, which has no `OBJ_EVENT_MON` bit, so `GetObjectEventGraphicsInfo` skipped `SpeciesToGraphicsInfo` and indexed `gObjectEventGraphicsInfoPointers[]` onto `gObjectEventGraphicsInfo_Follower` — `TAG_NONE` tiles, `OBJ_EVENT_PAL_TAG_DYNAMIC` palette, no `.images` — and nothing fills those slots for a map-placed object, so the sprite drew whatever was resident. The assertion is on the **bit**: pre-fix every one of these objects reads `graphicsId == 240` with bit 14 clear, so the suite fails against the old ROM instead of passing on nothing. It then checks the masked species against the exact set each `map.json` places, because `OW_SUBSTITUTE_PLACEHOLDER = TRUE` makes a *wrong* species a silent Substitute doll rather than a crash. Counts are deliberately not asserted exactly: only the nearest objects spawn (`OBJECT_EVENTS_COUNT` 16 against up to 64 templates — BellchimeTrail sits at exactly 64) and the whole `FLAG_NIGHT_POKEMON` half is hidden, so an exact count would be flaky by construction; ≥1 spawned plus "every spawned one is legitimate" is the honest pair. Screenshots per map cover the visual half of the acceptance. |

| `NationalParkTiles.lua` | **evidence** | Issue #53's metatile-attribute width, on the worst-affected layout. `MapGridGetMetatileAttributeAt` took the width from `mapLayout->isFrlg`, but the width belongs to the **blob**: National Park is a `"johto"` layout whose primary is `gTileset_General_Frlg`, natively u32, so it was read at u16 stride — metatile `m` landing on byte `2m` made even ids return another metatile's behaviour and odd ids return ~0 = `MB_NORMAL`. 455 of the map's 2688 tiles were wrong. The load-bearing checks are the two **arrow warps**, because they are deterministic and they were a softlock: `TryArrowWarp` needs `IsArrowWarpMetatileBehavior` and `TryStartWarpEventScript` needs `IsWarpMetatileBehavior` — which does not include arrow warps — so with (12,49)/(13,49)/(40,19) all reading `MB_NORMAL` none of the park's five warp events could fire by either route, and entering it was a one-way trip. The grass half covers the acceptance clause: 207 walkable encounter tiles became 412, and the suite walks the 22-tile band at y=29 that the fix creates, after a 35-step control walk over tiles that are non-encounter under **both** reads — so the first battle of the run cannot be "a battle happened after walking about". **★ Four traps this suite paid for, three of which made a correct fix look broken:** the Bug Contest layout's four south-gate tiles carry a `coord_event` (the attendant's retire prompt) and `TryStartStepBasedScript` runs coord events *before* the arrow-warp check, so `MB_SOUTH_ARROW_WARP` is unreachable there by design and asserting it fails on a working build — that phase now checks the retire prompt instead, as a regression test; an alternating two-tile grass probe spends half its steps on bare ground and duly reported a battle starting on the bare tile, hence the contiguous band; **there is no `BATTLE_TYPE_WILD` bit** — a wild single battle is exactly `BATTLE_TYPE_IS_MASTER`, so `flags == 0` is not the test; and `gBattlersCount` is still 0 the frame the overworld callback drops, so it must be sampled after the transition settles or a real battle reads as none. Also: the park places 15 overworld Pokémon and walking into one starts a wild battle from any tile, so the suite dumps its neighbours at battle start and refuses the attribution if a map-placed mon was in bump range — **excluding the follower by local id (254), because the debug party's Wobbuffet lead makes the player's own pet carry `OBJ_EVENT_MON` too.** |

## Not promoted

The `_pwtest/` corpus (~250 scripts) stays gitignored scratch by design: those suites drive
specific mid-playthrough saves (Battle Net floors, Mt Mortar shards, gym rematches) that a fresh
clone can't reproduce, so they can't satisfy the "runs on a fresh build" bar. Their durable
techniques are captured in `lib.lua` and `../BizHawkTesting.md`.
