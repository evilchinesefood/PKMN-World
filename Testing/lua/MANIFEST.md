# `Testing/lua` — the tracked overworld suites

Reproducible, fresh-clone-runnable test suites for PKMN-World. They run headlessly under a patched
**mGBA**, not BizHawk — see [`../mgba/README.md`](../mgba/README.md) to build the emulator, and
[`../BizHawkTesting.md`](../BizHawkTesting.md) for the field guide (boot signals, debug menu, warp
byte order, collision checking).

Almost everything here runs against a **fresh new game on the current build with no address edits**.
Four suites need a battery save instead, and one of those saves is not in the tree — see
[Fixtures](#fixtures) and [Running the whole battery](#running-the-whole-battery).

## What's in this directory

`Testing/lua/` holds **50 `.lua` files**: 46 suites plus four that are not suites and must never be
launched directly.

| File | Role |
|---|---|
| `lib.lua` | Shared helpers — boot loop, coordinate-verified stepping, the two debug spinners, cursor-verified multichoice, screenshots, object dumps, bag scans, crash-screen decoding, assertions and the verdict. Every suite starts `local F = require("lib").new(require("symbols"), "SuiteName")`. |
| `symbols.lua` | Generated per build from `pokemonworld.elf` by `Testing/GenLuaSymbols.py`. Runtime addresses that move every rebuild, a curated ABI-fixed struct-offset table, and the ROM's md5/sha1. **Build artifact — gitignored, never committed.** |
| `mgba_shim.lua` | The `--script` entry point. Provides the EmuHawk Lua API the suites are written against and loads the suite named by `$PW_SUITE`. Not a suite. |
| `SaveHarvest.lua` | In-emulator save harvester driven by `../MakeMigrationFixtures.sh` to produce the `fixtures/*.srm`. A utility, not a suite. |

`make modern` regenerates `symbols.lua` on its own: `modern` → `all` → `rom`, and
`rom: $(ROM) $(LUA_SYMBOLS)`. `make symbols` alone still works but is not needed.

> Some comments inside `lib.lua` and the generated `symbols.lua` still claim a plain build leaves
> `symbols.lua` stale and that only `make symbols` refreshes it. That was true before the
> prerequisite was added. The Makefile is the authority.

## Running one suite

```bash
make modern -j$(sysctl -n hw.ncpu)
Testing/mgba-run.sh Testing/lua/SmokeBoot.lua
Testing/mgba-run.sh Testing/lua/VerifyV7Migrate.lua pokemonworld.gba Testing/lua/fixtures/v7dirty.srm
```

Arguments are `<suite.lua> [rom.gba] [save.srm]`; the ROM defaults to the repo build. Exit code is
**0** pass, **1** suite failure, **2** setup error.

Output lands in `_pwtest/` (gitignored): `<Suite>.log`, numbered `<Suite>_NN_<step>.png`, and a
`<Suite>.PASS` / `.FAIL` sentinel. `lib.lua` creates `_pwtest/` if a fresh clone lacks it and warns
loudly if it still cannot write. Redirect with `PW_OUT`.

The last line of a run is the verdict:

```
VERDICT SmokeBoot: 10/10 PASS
```

and the sentinel records the same thing plus the ROM it ran against:

```
PASS 10/10 rom=0887BE3D4DAC670C3DB088B4C9FA536A at=2026-08-12T22:48:55Z suite=SmokeBoot
```

A `.FAIL` sentinel additionally lists each failing assertion by name. **Zero assertions is a
FAILURE, not a pass** — a suite that aborted before its first check must not report a perfect `0/0`.

## Running the whole battery

```bash
Testing/run-all.sh [rom.gba]        # defaults to ./pokemonworld.gba
```

It is not just a loop: it exists because "21/21 green" was once reported from 20 fresh runs plus
one `.PASS` that was six days and many builds old, for a suite that cannot run at all. So it:

1. **Deletes every `.PASS`/`.FAIL` in `_pwtest/` first**, so any sentinel left afterwards is one
   this sweep wrote.
2. Runs the 40 fresh-game suites, then the 3 save-backed ones, printing `rc=` and the verdict line
   per suite.
3. **Audits the sentinels**: each expected suite must have a `.PASS` *and* it must carry
   `rom=<md5 of the ROM under test>`. A `.FAIL`, a missing sentinel, or a stale md5 each fail the
   sweep by name.
4. Prints suites it knows about but could not run, under `NOT RUN`.

```
green 43 / 43 expected
SWEEP OK - every expected suite produced a fresh PASS stamped rom=<md5>
```

Exit code is **0** only for that. **1** means the sweep failed and the message says so outright —
`SWEEP FAILED - do not quote a suite count from this run.` **2** is a setup error (no ROM, no
`mgba-headless`, unhashable ROM).

### What a clean sweep looks like

On the owner's machine: **46/46, `SWEEP OK`, exit 0.**

On a fresh clone: **43 green, 1 optional, exit 0.** The one difference is `VerifyOwnerSave`, which
reads `pokemonworld.sav` — the owner's live battery save at the repo root. `*.sav` is gitignored,
and `MakeMigrationFixtures.sh` forbids committing a save harvested from a real playthrough, so no
clone can ever have one. It is therefore listed in `run-all.sh`'s `OPTIONAL_SAVE` rather than
`WITH_SAVE`: absent, it prints

```
VerifyOwnerSave          OPTIONAL - no pokemonworld.sav on this machine, not counted
```

and is left out of `EXPECTED` so the sentinel audit does not demand a `.PASS` for it.

That distinction is the point. A missing **tracked** fixture still fails the sweep — that means the
tree is broken. A missing **personal** save does not — that means nobody but the owner can run one
extra check. Reporting both as failures made a green run impossible and trained people to ignore
the exit code.

> Until 2026-08-12 this section documented the opposite, because it was true: `VerifyMapRenumber`
> had no committed fixture and sat in an `UNRUNNABLE` list, so the honest expectation was
> "19 green, 1 skipped, 1 not run, exit 1" and the battery could not pass anywhere. Its fixture is
> now generated by `Testing/MakeRenumberFixture.py` from the tracked fresh-new-game `v7.srm`, and
> `UNRUNNABLE` is empty.

### Environment knobs

| Variable | Effect |
|---|---|
| `PW_RTC` | Unix seconds for the pinned console clock. Default `1704110400` (2024-01-01 12:00 UTC). |
| `PW_OUT` | Where logs, screenshots and sentinels go. Default `_pwtest/`. |
| `PW_SAVE` | Battery save for `mgba-run.sh`, if not passed as the third argument. |
| `MGBA_HEADLESS` | Path to the emulator, if it is not on `PATH`. |
| `PW_EXPECT_GRP` / `PW_EXPECT_MAP` | `VerifyOwnerSave` only — where the save under test is standing. |

## Two guards that will abort a run

1. **ROM/symbols binding.** `symbols.lua` records the md5 of the `.gba` it was generated from and
   `lib.new()` refuses to run against any other ROM (`lib.lua:88`). Without this the normal
   accident — rebuild, then launch a stale hand-copy — boots fine and reports every test green while
   exercising the *previous* build's code, because `gSaveblock3` is a fixed EWRAM symbol. An **empty**
   hash is also a hard abort: it used to skip the comparison, which made the one guard the whole
   design leans on fail open on any host without BSD `md5`.
2. **Throwaway-ROM allowlist.** The ROM basename must match `^Verify`, `^MigChk` or `^FixGen`
   (`lib.lua:38`). `boot()` blind-presses A and Start for thousands of frames and the shipped save
   profile has SAVE on the start-menu wheel, so pointing a suite at the real ROM/save pair is a live
   clobber path that has already happened once. `mgba-run.sh` satisfies this automatically by copying
   the ROM to `Verify1.gba` in a temp dir. Override deliberately with `opts.allowAnyRom = true`.

## Never call `bit.*`

Use the native Lua operators — `&`, `|`, `~` (binary XOR and unary NOT), `<<`, `>>`. The BizHawk Lua
host printed a deprecation warning on **every** `bit.band` / `bit.bxor` / `bit.lshift` call: harmless
once, catastrophic inside a per-frame loop. A suite that read one bitfield per frame emitted roughly
60 warnings a second for an hour, filled the console and took the host machine down with it. The
current mGBA host does not even provide `bit`, so a stray call is now a hard error instead. `lib.lua`
is clean; keep it that way.

---

## The suites

| Suite | Needs | What it covers |
|---|---|---|
| [`SmokeBoot.lua`](#smokebootlua) | fresh new game | Harness self-test: symbols + lib load, boot to the hub, party / step / object dump all read correctly. |
| [`HubIntroTour.lua`](#hubintrotourlua) | fresh new game | The World Transit intro tour — all five reachable paths on one fresh game. |
| [`HubIntroTourFollower.lua`](#hubintrotourfollowerlua) | fresh new game | The same escort with a follower out, at the exact sprite budget. |
| [`HubStairsGate.lua`](#hubstairsgatelua) | fresh new game | The champion-gated hub escalator: refusal, admission, and the ride back down. |
| [`DebugParty.lua`](#debugpartylua) | fresh new game | Debug Set/Clear Party writes the party count and spawns the follower. |
| [`VerifyBagLayout.lua`](#verifybaglayoutlua) | fresh new game | The expanded bag + item PC really shipped, and survives a save + core reboot. |
| [`VerifyBedroomPC.lua`](#verifybedroompclua) | fresh new game | All four bedroom PCs, and the table-*pointer* test that distinguishes them. |
| [`VerifyPCScreen.lua`](#verifypcscreenlua) | fresh new game | Building-PC screen animation on the two layouts that were broken. |
| [`OwMonSprites.lua`](#owmonspriteslua) | fresh new game | Map-placed overworld Pokémon carry the `OBJ_EVENT_MON` bit, on seven Johto maps. |
| [`VioletMart.lua`](#violetmartlua) | fresh new game | Violet City's mart clerk stocks both tiers instead of blue-screening. |
| [`JohtoDayNightWorld.lua`](#johtodaynightworldlua) | fresh new game | The remaining day/night layout swaps, and three NPCs that had never spawned. |
| [`JohtoDayNightLive.lua`](#johtodaynightlivelua) | fresh new game | Johto's day/night world updates with no map reload, both directions, and on Continue. |
| [`NationalParkTiles.lua`](#nationalparktileslua) | fresh new game | Metatile-attribute width: the two arrow warps and the encounter band. |
| [`TinTowerRoof.lua`](#tintowerrooflua) | fresh new game | The Tin Tower roof after the night map's deletion, driven by the real clock. |
| [`OlivineHarborBoard.lua`](#olivineharborboardlua) | fresh new game | The OLIVINE board's BATTLE FRONTIER row now demands the S.S. TICKET. |
| [`SSAquaKantoCrossing.lua`](#ssaquakantocrossinglua) | fresh new game | The S.S. Aqua Kanto crossing in both directions, plus the persisted ferry departure record. |
| [`BnetTerminal1F.lua`](#bnetterminal1flua) | fresh new game | The Battle Net wall terminal on one map per placement row, and the BP payout invariants. |
| [`LevelUpSummary.lua`](#levelupsummarylua) | fresh new game | The post-battle "Your team grew stronger!" box, which `make check` cannot reach by construction. |
| [`DoorAnimsRegistered.lua`](#dooranimsregisteredlua) | fresh new game | Animated doors really resolve a `sDoorAnimGraphicsTable` row on the seventeen maps whose tilesets borrow another tileset's door metatile. |
| [`JohtoVictoryRoadTiles.lua`](#johtovictoryroadtileslua) | fresh new game | The three Johto Victory Road floors draw as a cave, not as a secret base, after the `layout_version` retag. |
| [`JohtoBerrySlots.lua`](#johtoberryslotslua) | fresh new game | Nine Johto berry trees no longer share save slots with nine other Johto trees. |
| [`AzaleaGymRide.lua`](#azaleagymridelua) | fresh new game | Azalea Gym Ariados ride carriers are species graphics, not a generic Lass. |
| [`DayCareFlowers.lua`](#daycareflowerslua) | fresh new game | Route 34 Day Care and Goldenrod Flower Shop flower tiles actually animate. |
| [`DaycareFullPartyEgg.lua`](#daycarefullpartyegglua) | fresh new game | A Route 34 daycare egg with a full party of 6 does not overwrite slot 5. |
| [`EncountersIncenseLink.lua`](#encountersincenselinklua) | fresh new game | Flat wild tables, Route 123 Roselia, Rose Incense mart, quest compile-out, Center 2F sealed. |
| [`EncountersIncenseLink_MainMenu.lua`](#encountersincenselink_mainmenulua) | fresh new game | Mystery Gift is compiled out of the title/main menu even with the flag set. |
| [`FollowerOutdoors.lua`](#followeroutdoorslua) | fresh new game | Grass/Bug followers comment on the outdoors (sniff / breeze / deep breath). |
| [`FrontierMidSave.lua`](#frontiermidsavelua) | fresh new game | A paused Battle Tower SAVE_LINK persists SaveBlock3 past the old 5-sector window. |
| [`HubNurseMonitor.lua`](#hubnursemonitorlua) | fresh new game | World Transit hub nurse heal spawns the FRLG 32x16 monitor, not Hoenn 24x16. |
| [`JohtoFlyTeleport.lua`](#johtoflyteleportlua) | fresh new game | Fly and Teleport land on Johto heal aprons, not Center doors. |
| [`JohtoHofLegendaries.lua`](#johtohoflegendarieslua) | fresh new game | Johto HOF rematch does not re-arm already-caught Mew/Deoxys. |
| [`JohtoMusicPass.lua`](#johtomusicpasslua) | fresh new game | Johto outdoor maps, cycling, and Radio Tower occupation play MUS_HG_*. |
| [`JohtoWhirlpool.lua`](#johtowhirlpoollua) | fresh new game | Whirlpool without the Glacier Badge refuses; with it, the slide walks over the blockers. |
| [`JohtoWhiteoutHeal.lua`](#johtowhiteoutheallua) | fresh new game | Johto whiteout lands on the Violet apron, Center heals store aprons, FRLG monitor. |
| [`KenyaMail.lua`](#kenyamaillua) | fresh new game | Randy's Kenya gift carries RetroMail; Route 31 sleeper removes her; TM41 bag-full is first. |
| [`PromptSafetyEvIv.lua`](#promptsafetyevivlua) | fresh new game | Intro Hard Mode defaults NO; outfit B is not a silent RED; EV/IV START flips page. |
| [`RedGyarados.lua`](#redgyaradoslua) | fresh new game | Lake of Rage Red Gyarados is MON\|SHINY\|GYARADOS in the overworld and in battle. |
| [`Route41SurfBgm.lua`](#route41surfbgmlua) | fresh new game | FldEff_UseSurf on Route 41 plays MUS_HG_SURF, not Hoenn MUS_SURF. |
| [`SlowpokeWellRescue.lua`](#slowpokewellrescuelua) | fresh new game | Slowpoke Well Jessie/James gate, Kurt no longer seals Proton, Rocket walk-out. |
| [`TohjoCelebi.lua`](#tohjocelebilua) | fresh new game | A full-HP Celebi follower arms the Tohjo Falls Giovanni scene. |
| [`VerifyV7Migrate.lua`](#verifyv7migratelua) | `fixtures/v7dirty.srm` | The v7→v8 ladder step runs, and the stale `mapView` does not repaint the old room. |
| [`MigrateFixtures.lua`](#migratefixtureslua) | `fixtures/v3.srm` | A pre-v7 save is *refused* at load, not half-loaded. |
| [`VerifyOwnerSave.lua`](#verifyownersavelua) | `pokemonworld.sav` (untracked, **optional**) | A real mid-playthrough save survives the v9 break. |
| [`VerifyMapRenumber.lua`](#verifymaprenumberlua) | `fixtures/v7renumber.srm` (generated) | The v9 map-renumber migration repoints persisted warps. |

Every entry below is **`evidence`**: it asserts a real, load-bearing contract, and where a
discrimination check was run it is recorded in the entry. (The other tier the harness
recognises is `probe` — exploratory or diagnostic, where a failure may be a harness quirk.
There are no probe suites in the tree right now.)

### `SmokeBoot.lua`

symbols + lib load on a fresh build; boot to hub, empty party, step + object dump read correctly. The harness self-test.

### `HubIntroTour.lua`

Issue #41's World Transit intro tour, all five reachable paths on one fresh new game: the warp-in offer fires with **no input at all** on a brand-new game (the thing a `coord_event` alone cannot do, because coord events only fire on a step); declining releases the player on the crest, sets `FLAG_HUB_INTRO_TOUR_DONE` and stops the crest triggers for good; the Charm Curator's re-offer, declined, falls straight through to his normal HUB PASS + POKéVIAL gives; accepted, it walks the player back to the crest and runs all nine stops (#59 added the BATTLE NET terminal and the flagship stairs) **in order** (the stop index only advances, so a tile matching a later stop early cannot fake a pass); the guide ends back at (22,7) facing down with **no stale held movement** — the issue-#42 trap — and stays there across a map reload; and with the flag cleared by hand, the crest `coord_event` still catches a walk-on, standing in for a legacy save that never saw the intro.

### `HubIntroTourFollower.lua`

The same escort with a **follower POKéMON out**. RegionHub has 14 object events against an `OBJECT_EVENTS_COUNT` of 16, so player + follower fills the sprite budget exactly, and a ~47-step scripted walk under that had never been run. Proves the follower spawns at all, that all nine stops (#59 added the BATTLE NET terminal and the flagship stairs) still run with it out, that it is back out beside the player at the end, and that the guide still gets home. It also pins the **mechanism**: `ScrCmd_applymovement` pockets the follower for the whole escort (`ScriptHideFollower`, because nothing sets `FLAG_SAFE_FOLLOWER_MOVEMENT` here), so the suite asserts zero visible frames *and* a ≤1 tile gap over any frame it is visible — if a future change stops pocketing it, the visible count leaves zero and the gap check starts doing real work. **★ `active` is not `visible`:** a pocketed follower stays active in `gObjectEvents` parked on its last tile, so an active-only check reads it as still on the map and reports a phantom desync that grows as the player walks away. Read `invisible` (`ObjectEvent.flags1` bit 5).

### `HubStairsGate.lua`

Issue #59 part C, the full staircase cycle live: a non-champion stepping onto the (2,14) apron is bounced back with the ACCESS DENIED message and control returns; a champion (flag set + map re-entered, so ON_TRANSITION disarms the gate) walks the same path, boards the escalator and rides to RegionHub_2F; the descent lands on (1,14) and `EscalatorWarpIn_End` auto-walks the player east onto the apron with control returned — the D1 guard behaviour on the new warp pair. ★ Two traps this suite paid for: a coord-event script that merely `end`s leaves the field controls LOCKED (script startup locks them and only a release path unlocks), so the admitted case must make the event stop MATCHING (the ON_TRANSITION var-arm idiom) rather than run a no-op branch; and `ensureFree()` beside an escalator RIDES it — prove control away from the tile.

### `DebugParty.lua`

Issue #44's debug party actions, in a real ROM. `DebugAction_Party_SetParty` filled `gParties` and never wrote `gPartiesCount`, so the game saw an empty party and the action failed **silently** — the menu just closed. This suite is the half `make check` structurally cannot cover: `battle_main.c` recomputes every party count from the array under `#if TESTING`, so the value self-corrects in a test build and the bug is only observable in a shipped ROM. Asserts the count on Set Party, that the follower spawns **on the same frame with no map reload** and is the party's lead (`graphicsId & 0x8FFF` == Wobbuffet), that Clear Party removes both count and follower, that Set → Clear → Set round-trips without leaving the map, and that a debug battle runs with a published player count. **★ Two traps this suite paid for:** the follower spawns *invisible under the player* and emerges on the first step, so sampling it after any `drain()` (which steps via `ensureFree()`) cannot tell "spawned hidden then stepped out" from "spawned visible" — sample before the drain; and Down + A pressed during the battle's send-out text is silently eaten, so the first run "opened" a party menu that was really still `Go! Buffie!` and the count assertion passed for the wrong reason. The menu is now proven open by `gMain.callback2` moving to `CB2_UpdatePartyMenu` and back, which a screenshot cannot establish — and closing it again is the anti-lockup check, since `maxMonIndex = count - 1` underflows to 255 at count 0.

### `VerifyBagLayout.lua`

Issue #24's expanded bag + item PC really shipped (Items 60 / Key Items 99 / PC 150), and a slot past the old 30-slot cap survives a save + core reboot.

> **Why pointer gaps and not just capacities:** `gBagPockets[p].capacity` is assigned from
> `BAG_*_COUNT` at runtime, so reading it back only proves the *constant* changed. What #24
> actually did was resize `struct Bag` inside SaveBlock1. Consecutive pockets are contiguous
> fields, so the gap between two pocket pointers **is** the earlier pocket's real slot count × 4 —
> that distinguishes "the header says 99" from "the save block genuinely holds 99". The suite also
> pins `bag` at `+0x6F8`, which is the runtime check on the `include/global.h` offset comments
> (they were stale for the whole life of the expansion and read `0x568`, a pre-expansion value).

> **Occupancy is seeded by a direct RAM write, deliberately.** Driving `PC/Bag → Fill…` was
> tried first and is not usable as evidence: debug submenu cursor state is documented to persist
> between opens, so a run where the fill silently never fires reports `occupied=0` — which is
> indistinguishable from a real defect. It produced exactly that false negative once.

### `VerifyBedroomPC.lua`

Issue #55's playtest checklist — all four bedroom PCs on one fresh new game. `6d86b3c2` stopped New Bark and Pallet offering a DECORATION entry the decoration system was never adapted to, by adding a third top-menu table selected on `gMapHeader.mapLayoutId`, and shipped without ever being run. **★ The load-bearing assertion is the table POINTER, not the count:** `sBedroomPC_NoDecorOptionOrder` and `sPlayerPC_OptionOrder` have identical contents *and* an identical count (both `{ITEMSTORAGE, MAILBOX, TURNOFF}`), so only the pointer distinguishes them — which is why `PlayerPC_TurnOff` (`src/player_pc.c:518`) must compare pointers while `InitPlayerPCMenu` (`:423`) must stay a row-count test (the two window templates differ in nothing but `.height` 6 vs 8). The two tests genuinely go in opposite directions and the suite checks both keys independently, plus `gWindows[sMenu.windowId].window.height == 2 × rows` for the "snug box" — which is assertable in RAM, not screenshot-only, because `AddWindow` copies the template verbatim. TURN OFF is verified by watching `sGlobalScriptContext.scriptPtr` enter the map's own shutdown script: if the pointer test were ever converted to a count test, both 3-option bedrooms would fall through to `ScriptContext_Enable()` and no script would run, which is exactly what that watch catches. **★ Both Littleroot bedrooms are gender-gated** (Brendan's MALE-only, May's FEMALE-only), so one run covers all four by seeding `SaveBlock2.playerGender` (+8). **★ Two pre-existing New Bark defects it had to be written around, neither caused by the fix:** #57 — its PC reuses Littleroot Brendan's gender-gated script, so a female player can never open it (the suite asserts the bug's *presence*, so it turns red the day #57 is fixed); #58 — its PC tile is metatile 648, behaviour `MB_NORMAL`, and the map holds no `MB_PC` tile, so the screen never animates and a `tileAt` "screen turned off" assert would pass on a build where the shutdown script never ran. New Bark asserts the tile is *inert* instead. **★ Use New Bark warp 1, never warp 0** — from (9,2) every southward route crosses the `coord_event` wall-clock triggers at (9,3)/(10,3), which hijack the run. **★ Never `F.pick`/`F.menuLive` on the 3-option menu** — they press Down to probe, and `Menu_ProcessInputNoWrap` *clamps* instead of wrapping, so a cursor driven past row 0 can never return. Full doll *placement* is deliberately not claimed: the shipped change cannot reach it, so the suite asserts the boundary of the changed code (DECORATION is present and really enters `DoPlayerRoomDecorationMenu`).

### `VerifyPCScreen.lua`

Issue #47's building-PC screen animation, on the two layouts that were broken. Johto centres picked their PC metatile by **region**, so "not Kanto" fell through to Hoenn's `METATILE_Building_PC_On` (5) — and mt 5 in `gTileset_Johto_Building` is a plain `MB_NORMAL` wall, which is why the reported symptom was both "the screen looks wrong" *and* "I couldn't use it again until I left and came back": the tile stopped being a PC, and only a map reload restored the blockdata. `RegionHub`'s PC had a second, unrelated failure — `IsBuildingPCTile` hardcoded `isFrlg = FALSE`, so the hub's **u32** attributes were read as u16 and its PC reported behaviour `0x5A` instead of `MB_PC`, so neither detector fired and it never animated at all. The suite reads the **live map grid** (`gBackupMapLayout`) across the whole 5-flicker cadence rather than screenshotting, because the wrong metatile still draws *something* — a screenshot assert would pass on the broken build. The load-bearing checks are the ones that fail on the old ROM: mt 4/5 must **never** appear at a Johto PC tile, the tile must still read 98 after the PC closes, and the PC must **re-open without leaving the map**, which is the user-visible regression itself.

### `OwMonSprites.lua`

Issue #49's map-placed overworld Pokémon, on seven Johto maps (Route 35, Route 36, National Park, Ecruteak City, Bellchime Trail, Route 46 and the Whirl Islands' Lugia chamber). All 741 were authored with `OBJ_EVENT_GFX_OW_MON`, which has no `OBJ_EVENT_MON` bit, so `GetObjectEventGraphicsInfo` skipped `SpeciesToGraphicsInfo` and indexed `gObjectEventGraphicsInfoPointers[]` onto `gObjectEventGraphicsInfo_Follower` — `TAG_NONE` tiles, `OBJ_EVENT_PAL_TAG_DYNAMIC` palette, no `.images` — and nothing fills those slots for a map-placed object, so the sprite drew whatever was resident. The assertion is on the **bit**: pre-fix every one of these objects reads `graphicsId == 240` with bit 14 clear, so the suite fails against the old ROM instead of passing on nothing. It then checks the masked species against the exact set each `map.json` places, because `OW_SUBSTITUTE_PLACEHOLDER = TRUE` makes a *wrong* species a silent Substitute doll rather than a crash. Counts are deliberately not asserted exactly: only the nearest objects spawn (`OBJECT_EVENTS_COUNT` 16 against up to 64 templates — BellchimeTrail sits at exactly 64) and the whole `FLAG_NIGHT_POKEMON` half is hidden, so an exact count would be flaky by construction; ≥1 spawned plus "every spawned one is legitimate" is the honest pair. Screenshots per map cover the visual half of the acceptance.

### `VioletMart.lua`

Issue #48's Violet City mart clerk. The clerk ran `pokemart 0`, so `SetShopItemsForSale(NULL)` tripped its `assertf` and blue-screened right after "How may I serve you?" — a runtime-only failure that built, linked and booted clean, which is why a playtest was the only thing that ever found it. Asserts on `sMartInfo`, not on a screenshot: the assert's own recovery block leaves `itemCount` at 0 with the dummy list, so requiring a specific non-zero count and the exact item ids fails against the old build instead of passing vacuously. Covers **both** stock tiers, including the one normal play cannot reach — the shared Cherrygrove script branches on `VAR_NEWBARK_TOWN_STATE >= 5`, and New Bark's only land exit is gated on Mom's farewell (the sole writer of 5), so the 2-item tier is dead data in a real playthrough. A debug warp arrives with the var still 0 and gets it for free; the run then writes 5 and re-opens to check the 4-item list players actually see, which is also what proves the region-var write reached `GetVarPointer`'s SaveBlock3 branch rather than agreeing with itself. **★ Two traps this suite paid for:** `sMartInfo` is a `static` that KEEPS the last shop's list after it closes, so a second read returns the first shop's stock unless it is cleared first; and `gText_HowMayIServeYou` is `"Welcome!\pHow may I serve you?"` — the `\p` is a page break that waits for a button, so a single A press opens the conversation but never reaches `pokemart`.

### `JohtoDayNightWorld.lua`

The rest of issue #52's playtest checklist, which #56 inherited and which nobody had ever run. Covers the two remaining `setmaplayoutindex` swaps (`MtSilver_SummitDay`, `GoldenrodCity_DepartmentStore_7F` — TinTowerRoof.lua has the third) in both directions, and three human NPCs that had never once spawned for any player: Route 35's Policeman Dirk (local id 8, three tiles from warp 2, so no navigation), and the Goldenrod Underground haircut brothers — a genuine day/night **pair** on one column, which is the strongest available shape because the negative half is asserted too. **★ Every warp deliberately targets a different map than the current one**, because `warpTo`'s success test is group+map only: called while already on the target it returns true having warped nobody *and* leaves the debug menu open, which then silently eats every later step. That is why the day and night passes are interleaved instead of run map-by-map. The Underground needs exactly one step down before sampling: from warp 2 at (12,10) the spawn window (`y in [py-7, py+9]`) reaches the night brother at y=16 but misses the day one at y=20 by a single row. `TRAINER_KEITH` (Route 34) and `TRAINER_JAMIE` (Route 39) are deliberately **not** covered — both sit ~30 tiles from their nearest warp, which is navigation cost behind no new mechanism.

### `JohtoDayNightLive.lua`

Issue #56 item 1: Johto's day/night world updates **without a map reload**. #52 shipped `UpdateJohtoDayNightFlags()` into the two map loaders only, so crossing 19:59 → 20:00 while standing still changed nothing on screen. Route 37 is the bed because it is unusually clean: local id 5 (VULPIX, `FLAG_NIGHT_POKEMON`) and local id 11 (PIDGEY, `FLAG_DAY_POKEMON`) sit on adjacent tiles three rows above warp 0, and only four of the map's 18 templates fall in `TrySpawnObjectEvents`' window from there — two of which are `LIGHT_SPRITE`s that take no `gObjectEvents` slot — so there is no slot pressure to confound a "did it spawn" check. **The "no map reload" clause is proved by polling `gMain.callback2` on every frame of the wait**, because every reload path in the engine (`CB2_LoadMap`, `CB2_ReturnToField`, a battle) swaps it away from `CB2_Overworld`; no positional check could establish it, since the player never moves either way. The flip is driven **both** directions, which rules out a one-shot latch that fires once and never re-arms, and it carries the **polarity** check that no compile-time gate can: an inverted build compiles, boots, tints correctly and inverts the whole world. A final phase covers item 3 — Continue — where the discriminating assertion is that the stale **day** mon is *gone*: `SpawnObjectEventsOnReturnToField` replays the saved `gObjectEvents` array verbatim and never re-reads the hide flags, and the camera update only ever ADDS objects, so nothing but the latched refresh can remove one that is in view. That phase must call `boot(group, keepScene = true)`: the default cleanup runs `ensureFree()`, which **steps the player**, and a step runs the camera update's own `TrySpawnObjectEvents` — spawning the night mon for a reason unrelated to the fix and making the check vacuous. **★ Two clock levers, and you need BOTH — this suite failed once for getting it wrong.** `SaveBlock2.localTimeOffset` (`+0x98`) is the only lever that survives a warp, because `LoadMapFromWarp` zeroes `sHoursOverride` at `src/overworld.c:989`, eighteen lines *before* the day/night hook at `:1007`; `gLocalTime = sRtc - localTimeOffset`, so winding the offset forward winds the clock back. But the offset **is save data**, so winding it after saving is undone by the reload — the first run of the Continue phase duly reported `resumed: clock 14:30`. Building "a save whose flags disagree with its own clock" (which in real play comes from the RTC advancing while the game is off) therefore needs `sHoursOverride`, which lives in **EWRAM and is not saved**: wind the offset to night, override the displayed hour back to day, save, then `client.reboot_core()` clears the override and the reloaded save reads night against day flags and day objects. **★ The TOD tick is not once a minute:** `gTimeUpdateCounter` is `3600 / FakeRtc_GetSecondsRatio()`, measured at **180 frames (~3 s)** on this config, which is why the suite's waits complete in ~150 frames rather than ~3600. Zero the counter to force a tick on the next frame, which is what `SetTimeOfDay` itself does.

### `NationalParkTiles.lua`

Issue #53's metatile-attribute width, on the worst-affected layout. `MapGridGetMetatileAttributeAt` took the width from `mapLayout->isFrlg`, but the width belongs to the **blob**: National Park is a `"johto"` layout whose primary is `gTileset_General_Frlg`, natively u32, so it was read at u16 stride — metatile `m` landing on byte `2m` made even ids return another metatile's behaviour and odd ids return ~0 = `MB_NORMAL`. 455 of the map's 2688 tiles were wrong. The load-bearing checks are the two **arrow warps**, because they are deterministic and they were a softlock: `TryArrowWarp` needs `IsArrowWarpMetatileBehavior` and `TryStartWarpEventScript` needs `IsWarpMetatileBehavior` — which does not include arrow warps — so with (12,49)/(13,49)/(40,19) all reading `MB_NORMAL` none of the park's five warp events could fire by either route, and entering it was a one-way trip. The grass half covers the acceptance clause: 207 walkable encounter tiles became 412, and the suite walks the 22-tile band at y=29 that the fix creates, after a 35-step control walk over tiles that are non-encounter under **both** reads — so the first battle of the run cannot be "a battle happened after walking about". **★ Four traps this suite paid for, three of which made a correct fix look broken:** the Bug Contest layout's four south-gate tiles carry a `coord_event` (the attendant's retire prompt) and `TryStartStepBasedScript` runs coord events *before* the arrow-warp check, so `MB_SOUTH_ARROW_WARP` is unreachable there by design and asserting it fails on a working build — that phase now checks the retire prompt instead, as a regression test; an alternating two-tile grass probe spends half its steps on bare ground and duly reported a battle starting on the bare tile, hence the contiguous band; **there is no `BATTLE_TYPE_WILD` bit** — a wild single battle is exactly `BATTLE_TYPE_IS_MASTER`, so `flags == 0` is not the test; and `gBattlersCount` is still 0 the frame the overworld callback drops, so it must be sampled after the transition settles or a real battle reads as none. Also: the park places 15 overworld Pokémon and walking into one starts a wild battle from any tile, so the suite dumps its neighbours at battle start and refuses the attribution if a map-placed mon was in bump range — **excluding the follower by local id (254), because the debug party's Wobbuffet lead makes the player's own pet carry `OBJ_EVENT_MON` too.**

### `TinTowerRoof.lua`

Issue #50's deletion of `MAP_TIN_TOWER_ROOF_NIGHT`, driven at **both** day/night states on one fresh new game — **and, since issue #56 item 2, driven by the real clock rather than by hand-seeded flags.** #52's map-load hook recomputes both flags from the RTC before `ON_TRANSITION` runs, so the old seed was overwritten in flight and whichever pass disagreed with the wall clock had to fail, at every hour; it was BizHawk-only, so CI could not see it. The suite now winds `SaveBlock2.localTimeOffset` and asserts the flags as an **outcome**, which is strictly stronger and is what #52's acceptance actually asked for. It asserts the player still lands on `MAP_TIN_TOWER_ROOF_DAY`, the map that owns the Ho-Oh scripts. It then proves the roof still *works*: the layout swaps to the now **map-less** `LAYOUT_TIN_TOWER_ROOF_NIGHT` (which is why its `layouts.json` entry had to stay), `ON_TRANSITION` clears `FLAG_HIDE_HO_OH`, the kimono coord event fires, and Ho-Oh descends to (10,6) on both layouts — the descent being pure Day-map script, i.e. exactly what the deleted twin could never have run. Also pins the D3 weather fix (`WEATHER_SUNNY` by day, `WEATHER_NONE` by night), which `setmaplayoutindex` cannot do on its own. The Ho-Oh **battle** is deliberately not driven: a fresh save has an empty party and `BattleSetup_StartLegendaryBattle` has no 0-party guard. **★ Three traps this suite paid for:** `warpTo` checks group+map only, so calling it while already on the target map returns true having warped nobody *and* leaves the debug menu open, silently eating every later step; TinTower_8F **has wild encounters**, so a step along the only westward corridor is intermittently eaten (the stationary `MOVEMENT_TYPE_TOWER_BEAM` Rayquaza is a red herring — that constant is `#define`d to `MOVEMENT_TYPE_NONE`); and Ho-Oh reaching (10,6) is the *middle* of the cutscene, not the end, so asserting there catches the player still under `lockall` — with kimono girls on three sides, `ensureFree()` can never report free, so an actual northward step is the release test.

### `OlivineHarborBoard.lua`

Issue #79's credential on the OLIVINE harbour board's BATTLE FRONTIER row. `OlivinePort_EventScript_ChoseBattleFrontier` was the one row of the six with no gate at all — the three island rows each do `checkitem` + `goto_if_unset FLAG_ENABLE_SHIP_*` and this one went straight to `call OlivinePort_EventScript_EnterShip` — so anyone who could open the board (`VAR_SSAQUA_STATE >= 7`) sailed to the Frontier for free. It now checks `ITEM_SS_TICKET` in the siblings' exact shape (`checkitem`, then `bufferitemname` because `OlivinePort_EventScript_Sailor_NoCredentials` prints `{STR_VAR_1}` three times, then the branch). One fresh new game, one seeding of the board state (`VAR_SSAQUA_STATE = 7`, `VAR_NEWBARKTOWN_LABSTATE = 11`, `FLAG_HIDE_OLIVINE_PORT_OAK` because PROF. OAK stands on the *exact* tile the player must occupy), two passes: **with** the ticket — put in the bag through the debug give-item spinner before anything moves — the row still boards and still lands on `MAP_BATTLE_FRONTIER_OUTSIDE_WEST`, which is the no-regression half a refuse-everybody gate would fail; **without** it the same row refuses, the player is still standing in `MAP_OLIVINE_CITY_PORT_INSIDE`, a box opened, and the box *names the ticket* — `bufferitemname`'s effect is asserted, not assumed, by seeding `EOS` into `gStringVar1[0]` beforehand so the check cannot pass on a stale buffer (which branch ran and what it printed are two different claims, and `OlivinePort_Text_NoPass` prints `{STR_VAR_1}` three times) — and control comes back. Segment A also carries the two guards this file's own header comment demands of anything near its `warpsilent`s: `gMain.vblankCounter1` still ticking (the only reliable assert-screen detector — `AssertfCrashScreen` busy-loops *inside* `CB2_Overworld`, so `F.ow()` reads green with the crash screen up), and the persisted region **unchanged**, which is issue #69's "this row makes no region claim" decision made assertable. Stash-verified: with the `scripts.inc` hunk removed and the ROM rebuilt the suite scores **18/20**, both failures in segment B and both naming the defect — `gStringVar1[0]=0xFF` (the seeded EOS survived, so `bufferitemname` never ran) and `grp=26 map=4 pos=(20,67)` (the ticketless player standing on the Frontier dock). **★ The gate deliberately omits `FLAG_HOENN_CHAMPION`**, which the Hoenn-side `BattleFrontier_OutsideWest_EventScript_FerryAttendant` demands on top of the ticket: that is Hoenn's champion bit (`FLAG_SYS_GAME_CLEAR` is the any-region first-HOF bit; GameClear sets it from Johto too), and a Johto champion is given `FLAG_IS_CHAMPION` / `FLAG_JOHTO_CHAMPION` instead (`JohtoPokemonLeague_HallOfFame/scripts.inc:61-62`), so a literal mirror would shut the row for precisely the players the board exists for — which is why this suite sets no Hoenn champion flag and still expects the first pass to sail. **★ Four traps it paid for.** The one that mattered: **`F.step()` is a coordinate-CHANGE detector, and `OlivinePort_EventScript_EnterShip` walks the player two tiles onto the boat with `applymovement`** — so a "press B until a step lands, then read the map" loop breaks out mid-cutscene, samples the map hundreds of frames before the `warpsilent`, and reports OLIVINE. The first version of this suite scored a full 17/17 against the *pre-fix* ROM for exactly that reason (the tell was `pos=(8,18)`, the boat tile, in its own detail string); the refusal is now settled on a fixed B-press budget that only stops early if the player really leaves the map. Then: `sMenu` is a **static that keeps the last menu's fields**, and this suite opens the same six-row board twice with only debug-menu (ListMenu) traffic in between, so the second wait returns true on its first probe against the *first* pass's `maxCursorPos` unless both it and `cursorPos` are zeroed first — the same trap `VioletMart.lua` pays for with `sMartInfo`; `lib`'s `menuLive()`/`pick()` are unusable on this board at all, because it is `message` + `waitmessage` + `multichoice` and their Down-probe lands mid-typewriter, letting the A press behind it select row 0 = VERMILION; and the berth corridor is one tile wide, so `ensureFree()`'s Left/Right always reports stuck and a vertical step is the freedom probe. The ticket is taken back by a direct write of `0` over the key-item slot's **id** (`{u16 id, u16 quantity}`, only the quantity is XORed against the encryption key, `src/item.c:66`), there being no debug remove-item action.

### `SSAquaKantoCrossing.lua`

Issue #65's S.S. Aqua Kanto disembark, both directions, on one fresh new game. **It boards for real first** (issue #70): from a pre-voyage save — `VAR_NEWBARKTOWN_LABSTATE = 11` for the A1 gate (below it the sailor takes the `NotSailingYet` branch and nothing is tested), `VAR_SSAQUA_STATE = 0`, and `FLAG_HIDE_OLIVINE_PORT_OAK` set because PROF. OAK stands on the *exact* tile the player must occupy — it puts `ITEM_SS_TICKET` in the bag through the debug give-item spinner and walks `OlivinePort_EventScript_Sailor` → `..._Sailor_MaidenVoyage` aboard the S.S.AQUA. That is the site #67's `warpsilent`-without-`waitstate` assert actually shipped on: five of that file's six warps were unreachable dead code and this is the one on the live post-League path every new Johto champion is sent down, and until now the fix was proved only **by shape** — the repeat crossing below runs the identical `call`/`warpsilent`/`waitstate` sequence — never by executing the site. Then, from a state 6 restart: seeds `VAR_SSAQUA_STATE = 6` (a finished maiden voyage), boards at the cabin door and walks the corridor to the 1F door sailor; he lands the player in `MAP_VERMILION_CITY_PORT_INSIDE` — a map this issue created — whose `ON_FRAME` arrival scene advances the var to 7. Then out the terminal door onto the Vermilion pier — landing on the port building's apron at (26,30), the door issue #68 built to make that link two-way — a lap of the pier, the pier sailor asserted to HAND the crossing off rather than sail it (his duplicate of the leg only existed while the terminal was arrival-only), back in through the city-side door and out to Olivine via the berth sailor, and finally through the `>= 7` harbour menu (asserted as six rows via `sMenu.maxCursorPos`, which was unreachable dead code before) picking VERMILION for a second crossing that must NOT re-run the arrival scene. Three more legs cover what the crossing dragged in: `MAP_LILYCOVE_CITY_HARBOR`'s new `ON_TRANSITION` region claim, entered with `gCurrentRegion` **and** `SaveBlock2.currentRegion` both forged to JOHTO (both, or the warp restores the one you did not write); the terminal's own boarding cutscene driven with a **follower** out, which is a fresh copy of Olivine's and had never run in a shipped ROM in either place, while the cutscene does `removeobject OBJ_EVENT_ID_PLAYER` + `SpawnCameraObject` with a second object tethered to the player; and the event islands' new two-homes return, driven from Birth Island's harbor in **both** directions — Johto-booked sails home to Olivine, Hoenn-booked still sails to Lilycove, which is the no-regression half. The flagheap decision — the riskiest judgement in the change — is asserted rather than argued: the whole SaveBlock1 flag array and the whole SaveBlock3 region-var array are snapshotted across the disembark (with Kanto's badge bytes pre-seeded so a mis-based write cannot land on zeroes and hide) and diffed byte for byte; the flag array must not move at all and the only region-var bytes allowed to move are `VAR_SSAQUA_STATE`'s. **The load-bearing assertion is `SaveBlock2.currentRegion` on every leg**: `src/region_switch.c`'s INVARIANT requires each cross-region entry to pass through `SetCurrentRegion`, `ResyncCurrentRegionFromMap` prefers the PERSISTED region so nothing would ever repair it, and the symptom — a Johto champion's HARD `VAR_DIFFICULTY` tier applied to first-run Kanto gyms — is invisible on screen. **★ Four traps this suite paid for:** warping to SSAqua_1F **warp 0** materialises the player on the ship's exit arrow-warp at (29,1), sharing the tile with the door sailor who is the only thing keeping players off it — the first Up press then rides it back to Olivine and the test proves nothing; use warp 1 (the cabin door) and walk. `lib`'s `dismiss()`/`ensureFree()` prove control with a Left/Right step and **both** port berths are one tile wide, so they always report stuck — step vertically instead. Every boarding cutscene contains a blocking `MSGBOX_DEFAULT`, so a poll loop that presses nothing waits forever in front of "We're departing soon" — and PROF. OAK stands in Olivine's berth corridor until his National-Dex scene runs, so a fresh save must set `FLAG_HIDE_OLIVINE_PORT_OAK` *before* the warp that rebuilds the object set. The suite is also what caught the `warpsilent`-without-`waitstate` assert (`src/script.c`'s "leaving script while a warp is in progress") on all six Olivine harbour warps — including the live maiden voyage — which blue-screens in the **shipped** ROM, not just a debug build. **★ Three more traps, all paid for by the maiden-voyage leg:** `F.spin(h, t, o)` does **not** mean `100h + 10t + o` on the item-id field. It floors the digit with six Downs before building the value back up and `Debug_HandleInput_Numeric` clamps at `min`; the warp spinners pass `min = 0`, but the item-id field passes `min = 1` and starts at 1 (`src/debug.c:2698`, `:2667`), so it yields `1 + 100h + 10t + o` — `ITEM_SS_TICKET` (727) needs `spin(7, 2, 6)`, and `spin(7, 2, 7)` silently hands over item 728 and gets `OlivinePort_Text_NoTicket` instead of a voyage. **`gMain.callback2` is not an assert-screen detector**, which is the trap that would have made the whole leg vacuous: `AssertfCrashScreen` (`src/assertf.c:436`) sets `REG_IME = 0` and busy-loops on `REG_VCOUNT` waiting for START *inside* `CB2_Overworld`'s own call stack, so `F.ow()` still reads `CB2_Overworld` with the crash screen up and would **pass** against exactly the build the leg exists to fail. What stops is the main loop — interrupts off means `VBlankIntr` never runs and `gMain.vblankCounter1` freezes — so that is what the suite samples, and nothing in the leg may press Start until its final park-ashore warp, because the screen is resumable and Start dismisses it. One precondition worth stating outright, since the leg's whole discriminating power rests on it: `assertf` compiles to `(void)0` under `#if RELEASE` (`include/assertf.h`) and `RELEASE` is set only by `make release`/`tidyrelease`, so this catches the regression against the `make modern` builds `_pwtest` actually drives — against a true `RELEASE` build the assert is absent and the leg would go green. And the voyage leaves the player **on** `MAP_SSAQUA_1F`, where `warpTo`'s group+map-only success test (`lib.lua:245`) would report a no-op warp as a success *and* leave the debug menu open to eat the next segment's input — so the leg parks back at Olivine (whose map-script table is empty, so parking there runs nothing) before handing over. The item *id* needs no decryption either: only `quantity` is XORed against `SaveBlock2.encryptionKey` (`src/item.c:66`), so `F.keyItemSlot` reads the same plaintext id `checkitem` compares. **★ Issue #80 — the persisted departure record, and what it did to segment H.** `Common_EventScript_FerrySailHomeFromIsland` now prefers `VAR_FERRY_DEPARTURE` (the reclaimed `VAR_UNUSED_0x40FA`) over the active-region probe, because a save whose `SaveBlock2.currentRegion` is still `REGION_NONE` cannot be read: `ResyncCurrentRegionFromMap` derives `REGION_HOENN` from the island's own mapsec on the warp in, so by the time the script runs a legacy Johto player is byte-identical to a genuine Hoenn one. Segment 0 asserts the record is `FERRY_DEPART_UNSET` on a fresh save (the only untouched one the suite ever sees — that is the state *every* pre-#80 save is in, and the reason the change needs no migration) and that the real `OlivinePort_EventScript_EnterShip` writes `OLIVINE`. Segment I proves the read side **by contradiction**: each leg sets the record to one harbour and the active region to a *different* one, so the two decision paths give different answers and the landing map says which ran — a leg whose record merely agreed with its region would pass on the pre-#80 ROM and prove nothing. It also drives the LILYCOVE write site *for real* (`FLAG_HOENN_CHAMPION` + `FLAG_ENABLE_SHIP_BIRTH_ISLAND` + an AURORA TICKET, with `FLAG_SHOWN_AURORA_TICKET` clear so the attendant takes the **first-time** branch, which is the only island path with no multichoice to steer) and sails the resulting trip home, so write and read are proved as one journey. That leg deliberately targets `LilycoveCity_Harbor_EventScript_BoardFerryWithSailor`, a *separate* helper from `BoardFerry` rather than a wrapper — a fix that patched only the obvious one would leave every first-time event ticket recordless. A second Lilycove leg drives the **Old Sea Map** row, the fourth and last write site, which calls *neither* named helper and boards inline with Briney's cutscene: every other assertion in the suite would still pass if that one `setvar` were dropped, which makes it precisely the line a refactor deletes unnoticed. It is not a rare alternative either — the attendant tests `VAR_TEMP_C == 2` at `scripts.inc:44` *before* the `VAR_TEMP_B == 4` at `:47`, so `:47` is unreachable and this is the only route a first Faraway Island trip ever takes (pre-existing, left alone). Note `ITEM_OLD_SEA_MAP` (731) needs `spin(7, 3, 0)`, not `(7, 3, 1)` — the `1 + 100h + 10t + o` rule again. Each arm also **consumes** the record on arrival, asserted after the round trip: nothing today depends on it (every route to the reader passes a writer), but it means a future island route added without a boarding write degrades to the region probe rather than reading a stale harbour — which would be *worse* than the pre-#80 answer, since a stale non-zero record suppresses the probe entirely. **The trap it paid for:** `new_game.inc:188` SETS `FLAG_HIDE_LILYCOVE_HARBOR_SSTIDAL` and only `hall_of_fame.inc:17` clears it, so on a fresh save the ferry object `Common_EventScript_FerryDepart` applymovements (via `VAR_0x8004`) is not spawned — it has to be cleared alongside `FLAG_HOENN_CHAMPION`, which is the same Hoenn post-game state anyway. **And segment H changed meaning:** it is now the *fallback* proof and each of its legs explicitly clears the record first, because segment 0's real boarding has already written `OLIVINE` into it — without the clear all eight of its legs would sail to Olivine on the record and the region argument would never be consulted, quietly collapsing eight assertions into one. Segment I also asserts the LANDING COORDINATE, not just the map: the Olivine arm moved from `(8,9)`, the terminal's north **door**, to `(8,16)`, its **berth**, matching Vermilion's arm and both S.S.AQUA arrivals — both port-inside maps are the same 18×28 layout with a one-tile corridor at x=8 running y=15..17, verified in the blockdata. **Discrimination measured, not assumed:** against a build with only the three `goto_if_eq VAR_FERRY_DEPARTURE` lines and the `(8,16)` coordinate reverted, this suite drops 94/94 → 86/94, and all eight failures are #80 read-side assertions.

### `BnetTerminal1F.lua`

The Battle Net wall terminal (issue #59), on one map per distinct row of the issue's placement table — all six 1F layouts, both League lobbies, One Island and the hub. Per map: standing on the pedestal facing the screen opens the combined menu (cursor read from menu.c's `sMenu`, never counted blind), EXIT closes it, and control returns with no orphaned lock — the `lock`/`release` pairing the sign form depends on. Once, on the hub: holding Up into the screen for 60 frames opens nothing, because the terminal's metatile behaviour is 0, not signpost-family — only the bg_event answers. The payout invariants carry forward from the retired `BnetCounter2F.lua` (whose 2F counter slots lost their staircase): a real Scaling win pays 1 BP through `ScalingRun`'s call-across-a-battle, and a Leader Sim win pays 2 BP and NOTHING else — whole-bag snapshot either side, quantities decrypted against the roaming encryption key. New here: the 0x24 bytes at `gObjectEvents[16]` are snapshotted around the whole Leader Sim launch and must come back identical — the sign form runs with `VAR_LAST_TALKED = LOCALID_NONE`, which is exactly the out-of-bounds recipe the no-reveal battle entry (D3) exists to prevent, so any regression writes precisely there.

### `LevelUpSummary.lua`

The post-battle level-up box. Level-ups are silent during a fight now — `Cmd_getexp` calls `BattleScript_LevelUpQuiet`, which drops the `MUS_LEVEL_UP` fanfare, `STRINGID_PKMNGREWTOLV` and `drawlvlupbox` (three button presses and an ~80-frame unskippable stall per mon per level, because `STRINGID_PKMNGREWTOLV` ends in `{WAIT_SE}` and `sound.c:42` gives that fanfare 80 frames) — so this box is the *only* thing that now reports what happened. If it fails to appear, every level-up in the game becomes invisible. **`make check` cannot cover this, by construction:** `ShouldShowLevelUpSummary()` returns FALSE when `gTestRunnerEnabled`, because the box waits on `gMain.newKeys` and would otherwise hang every one of the ~5500 battle tests forever. An emulator is the only thing that can execute this path. **What discriminates:** `sLevelUpSummaryState` (exported for this suite) only reaches `WAIT_PRESS` if the gate passed *and* the window drew *and* the DMA copy finished *and* BG1 scrolled into view, so asserting it fails against a build where the hook never runs rather than passing vacuously — and the run then fights the **same battle again with nothing levelled** and requires the box does NOT appear, which a stubbed-TRUE implementation would fail. Levels are **seeded** into `gLevelUpStartLevels[]` rather than earned: that array is written by `Cmd_getexp` when a slot first levels and read only at the end of the battle, so poking it mid-battle exercises the identical path without having to out-level a debug trainer — that the EXP maths fills it is `test/battle/exp.c`'s job, not this one. The suite also **clones party slot 0 across all six slots** with differing `Pokemon.level` bytes before the first battle, because the debug trainer's player party is a single Pokémon and a one-row box cannot show a column drifting, a row running off the bottom, or a nickname colliding with the numbers. **★ Three traps it paid for:** the box was first placed at rows 8–17 and B_WIN_MSG lives at rows 15–18 — BG1 sits above BG0 while the box is up, so the frame silently covered the "Your team grew stronger!" line; it now stops at row 14. And screenshotting the frame `WAIT_PRESS` is first observed catches the message window mid-typewriter and makes a correct box look truncated, so the shot idles 90 frames first. And the third is what the suite's last three assertions now guard: `AddTextPrinter` bakes the printer's colours into one **global** table, `sFontHalfRowLookupTable` (`src/text.c:496`), and `RenderText` regenerates it only for an in-string colour code — never when it resumes a printer. `B_WIN_MSG` types a character per frame out of `RunTextPrinters`, so drawing the box *after* starting the message repainted every glyph but the first in the box's colours: background `TEXT_DYNAMIC_COLOR_5` = 14, which is the box's own dark fill in palette 5 but a **red** in `B_WIN_MSG`'s palette 0. The box is therefore drawn first and the message printed last. The assertions read the message window's tiles **straight out of VRAM** — bg, width, height and `baseBlock` off `gWindows[0].window`, char base off that BG's own `BGxCNT`, nothing assumed. **The vacuity hole this had to be shaped around, found in review and then measured:** `B_WIN_MSG` is never blank at that moment, because the battle-end script has just printed into it — so a build with `BattlePutTextOnWindow` **deleted outright** still shows foreground glyphs and legal colours, and an earlier version of this check (index 14 absent, index 15 present) passed against exactly that ROM. Presence of text proves nothing here. The fix is a **baseline**: the window is digested at the frame the state machine leaves `INIT` — box up, summary not yet printed, which the new ordering guarantees — and again once the line has typed out, and the two must differ. That is why the watch loop polls every frame instead of every sixteenth: `DRAW` is one frame wide. The colour half then rejects **every** index outside 1/6/15 rather than 14 alone, because the pre-fix build stained the glyphs themselves with 13 as well. **Discrimination measured against two deliberately broken ROMs, each caught by a different assertion:** with the ordering reverted → `illegal idx13=269 idx14=1184` fails while the other two pass; with the `BattlePutTextOnWindow` call removed → `baseline=0xB7E524D1 final=0xB7E524D1` fails while the other two pass. The box borrows the VRAM (`baseBlock 0x100` on BG1) that `B_WIN_LEVEL_UP_BOX` and `B_WIN_LEVEL_UP_BANNER` used to hold — 146 tiles that are provably free precisely *because* `drawlvlupbox` is no longer called.

### `DoorAnimsRegistered.lua`

Issue #92. `GetDoorGraphics` (`src/field_door.c`) matches a door on the metatile id **and** the
tileset *pointer*, so a tileset that reuses another tileset's door metatile needs its own row in
`sDoorAnimGraphicsTable`. With no row the lookup returns NULL, `FieldAnimateDoorOpen` returns `-1`,
and `Task_DoDoorWarp` reads `-1` as "the animation already finished" — the player warps through a
door that never opened, with no crash, no build warning, and *still with a door sound*, because
`GetDoorSoundEffect` falls through to `SE_DOOR` when the lookup fails. **How it is asserted:** not by
timing the warp — frame parity is exactly the thing this project has been burned by. The suite
evaluates `GetDoorGraphics`' own condition on the live ROM: it warps to the map, reads
`gMapHeader.mapLayout->primaryTileset` / `->secondaryTileset` (the two pointers the game itself
compares), reads the metatile id actually present at the door's *(x,y)* out of the live map grid
`gBackupMapLayout`, then walks `sDoorAnimGraphicsTable` to its terminator applying the identical
rule. Comparing pointer values means no per-tileset symbol is needed and nothing is assumed about
which tileset *ought* to match. **The decode is proved before it is trusted:** `struct DoorGraphics`
hand-sums to 18 bytes but its real stride is 20 (alignment padding after the `u16`), and a wrong
stride fails *silently* — it reads garbage that happens not to match, i.e. it reports the bug as
present or absent at random. So row 0 must reproduce the source table's first entry exactly,
`METATILE_General_Door` `0x021` paired with `&gTileset_General` (address from the ELF), and the walk
terminates on `tiles == NULL` like the game does, not on an all-zero row — one live row (the cut
Battle Frontier door `0x3B0`) has a NULL *tileset* and must still be walked past. Each door
coordinate is also required to read `MB_ANIMATED_DOOR`, computed the way
`GetAttributeByMetatileIdAndMapLayout` computes it (640/512 primary split by `isFrlg || isJohto`,
attribute width from the *tileset's* `hasFrlgAttributes` — issue #53's trap), so the suite is
anchored to real doors and not to bare numbers. **What discriminates:** the eighteen positives are
every dead warp in #92's census, spanning eleven repaired maps — Battle Frontier Outside East's six
doors (`0x396` at (5,8) (4,44) (14,51),
`0x3FC` at (10,28) (22,51) (65,31) — the West tileset's ids, registered for the West tileset only);
Bellchime Trail's Tin Tower door (`0x333` at (35,41), registered for Ecruteak City's tileset only);
Dragon's Den's shrine entrance (`0x2FF` at (31,46), which is the *only* warp into
`MAP_DRAGONS_DEN_SHRINE`); the Johto Safari Zone hut (`0x2BF` at SafariZone2 (35,11), an id
registered for Fuchsia City's tileset only); the four Mahogany-tileset doors that one row
repairs across two maps (`0x2A2` at Mahogany Town (15,10) (27,10) and Lake of Rage (15,4) (39,41),
an id registered for Lavender Town's tileset only); and the five S.S. Aqua doors that a second row
repairs across five maps (`0x281` at SSAqua 1F (29,1) and at (2,1) in each of the Player's Room,
Room NW, Room NE and Room NNE — an id registered for S.S. Anne's tileset only). **The
negative controls** are what stop it being "a door exists": `bf_battle_tower_door` is `0x329` on the
*same* East map and already had its own row; Ecruteak City's four `0x333` warps are the *same
metatile id* as Bellchime's broken door behind a different tileset pointer; a plain walkable
metatile beside each door must match no row; and `*_foreign_tileset_door_id_has_no_row` looks up an
id that **is** in the table but only for tilesets this map does not use (`0x021` on Bellchime,
`0x333` on Battle Frontier East and Safari Zone 2, `0x32B` on Dragon's Den, `0x2D2` on Mahogany
Town) — if the id half alone decided the match, those would resolve. Three more shapes were added
with the later groups. **Cross-map twins**, the Ecruteak pattern repeated: Violet City's two `0x32B`
dojo doors carry the artwork Dragon's Den's row borrows, and Lavender Town's three doors carry the
very *same* id as Mahogany's, `0x2A2`, behind a different tileset pointer — each paired with an
assertion that the two maps share **no** tileset, so the comparison cannot be vacuous.
**`safari_johto_gate_door_id_resolves_on_this_tileset`**, the strongest of the lot: `0x2D2` is the
*other* door in `gTileset_SafariZoneJohto` and predates the fix, so looking it up on SafariZone2
runs the same map, the same pointer pair, the same walk and the same matcher as the repaired `0x2BF`
lookup and resolves on both ROMs — the two differ in the row and nothing else (and
`MAP_SAFARI_ZONE_GATE` is then visited so `0x2D2` is checked as a real `MB_ANIMATED_DOOR` at its own
coordinates). And **`*_door_id_also_has_a_foreign_row`**, the form `checkNoDoorRow` cannot express:
on Mahogany Town `0x2A2` *does* resolve after the fix, correctly, so "must not match" is the wrong
assertion — what must hold is that a row carrying that id is bound to a tileset this map does not
use (`&gTileset_LavenderTown`). That is what makes the positive read "the `&gTileset_MahoganyTown`
row is present" rather than "`0x2A2` is a known door metatile": on the pre-fix ROM the id was in the
table and the doors still never opened. Safari Zone 2 states the same against Fuchsia's `0x2BF` row.
**Supplementary, clearly labelled:** `*_live_door_animation_runs` walks into one repaired door per
map and watches `gTasks` for `Task_AnimateDoor`, whose only creator (`StartDoorAnimationTask`) is
reached only after `GetDoorGraphics` returns non-NULL; it screenshots the door twelve frames in, on
the last and widest of the four `DoorAnimFrame`s. It deliberately does *not* call `F.face("Up")`
first: the door tile is impassable, so that press is itself what fires `TryDoorWarp`, and the
animation could start and finish inside `face()`'s trailing idle before the poll ever looked.
**The S.S. Aqua group, and the claim it overturns.** `ssaqua` `0x281` is byte-equal to
`METATILE_SSAnne_Door`, and issue #92 read that as a trap rather than a gift: it reported
`ss_anne_frlg`'s art as "a solid door with a frame" against `ssaqua`'s "sparse alternating lattice
(every other pixel column transparent), with **no** top metatile layer at all", and concluded the
metatile had been copied from S.S. Anne without its art — that the fix was to *un*-animate it. There
is no lattice. `ssaqua`'s `tiles.png` is **8bpp**; decoding it as packed 4bpp splits each byte into
two nibbles and blanks alternate pixel columns, which manufactures exactly that pattern. The frames
are genuinely shared, so the row is S.S. Anne's own tiles and palettes at S.S. Anne's `size` of
**2** — `size 1` would draw the frames' upper half over the door itself. The suite covers all five
warps (1F's gangway plus the four northern cabins), and
`DoorAnimsRegistered_19_ssaqua_room_nne_door_door_animation.png` is the visual half of the
retraction: a solid panelled door, mid-open. That screenshot is also what caught the group's one
real defect. `size 2` means the animation redraws the metatile **above** the door too, and while
every S.S. Anne placement and SSAqua 1F carry `0x3BF` there (wall + ledge + door-top), the four
cabins carried `0x28C`, flat panelling — so opening the door conjured a lintel out of blank wall
and shutting it wiped the lintel away. Diffing the arrival frame against the animating frame showed
it immediately: rows 48–63, a whole tile above the door, changing. Four words of map data now match
every other placement, and the same diff shows only the door leaf moving. The cabins carry the group's sharpest control —
`0x03D` (`METATILE_Johto_General_Door`) **resolves** on SSAqua 1F, whose primary is
`gTileset_Johto_General`, and **must not** in a cabin, whose primary is `gTileset_Johto_Building`
and carries no door row at all. Same secondary, same matcher, same walk; only the primary pointer
differs. `MAP_SSANNE_1F_ROOM1` is the cross-map twin, the same `0x281` behind
`&gTileset_SSAnne` on a map sharing no tileset with any S.S. Aqua map — and the map whose art the
new row borrows.

**Discrimination run (2026-08-18):** the first two groups scored **38/38** on the fixed tree and
**29/38** against a ROM built with their rows removed, with exactly the nine fix-specific assertions
flipping (the six `bf_*_has_a_door_anim_row`, `bellchime_tin_tower_door_has_a_door_anim_row`, and
both live-animation checks). Re-run after the Dragon's Den, Johto Safari Zone and Mahogany rows were
added and covered: **86/86** on the fixed tree, **79/86** against a ROM built from the same tree with
*only* those three rows deleted — the seven that flipped being
`dragons_den_shrine_door_has_a_door_anim_row`, `safari_johto_town_door_has_a_door_anim_row`,
`mahogany_door_{1,2}_has_a_door_anim_row`, `lake_of_rage_door_{1,2}_has_a_door_anim_row` and the
supplementary `mahogany_door_live_door_animation_runs`. **Re-run once more (2026-08-19)** with the
S.S. Aqua group added and *every* row the fix introduced reverted — the strongest control of the
three, because it removes all seven rows at once rather than a subset: **114/114** on the fixed
tree, **92/114** on the unfixed one. The 22 that flipped are exactly **one
`*_has_a_door_anim_row` per repaired warp — all eighteen — plus the four supplementary
`*_live_door_animation_runs`**, which is the whole of #92's census expressed as a runtime failure
list. Every negative control stayed green on the unfixed ROM, including all eighteen
`*_is_an_animated_door` halves of the flipped pairs (the tiles are doors on both builds; only the
table lookup changes), the same-tileset `0x2D2` control, all three
`*_door_id_also_has_a_foreign_row` controls, the SSAqua-1F-vs-cabin `0x03D` pair, and Violet City's,
Lavender Town's and S.S. Anne's cross-map twins.

### `JohtoVictoryRoadTiles.lua`

`JohtoVictoryRoad_1F` / `_B1F` / `_B2F` were tagged `layout_version: "johto"` while their primary
tileset is the 512-metatile `gTileset_General`. `GetNumMetatilesInPrimary` returns **640** for a
layout whose `isFrlg` or `isJohto` byte is set, so the id space was split at 640 over a 512-entry
primary and every id in 512..639 indexed 128 entries past the end of `gMetatiles_General` — into
`gMetatiles_SecretBaseSecondary`. Nothing bounds-checks that, in either
`GetAttributeByMetatileIdAndMapLayout` or `DrawMetatileAt`, so it corrupted what was **drawn** as
well as the behaviour byte: 1989 of 1F's 2070 tiles sit in that band, and `_1F` and `_B1F` use no id
below 512 at all — about 96% of the first floor was rendering someone's secret base. The fix retags
all three to `"emerald"`, moving the split back to 512. **What needs a running ROM** (the host-side
validators can only re-derive the same spreadsheet the fix was reasoned from): that the retag
reached the binary (`MapLayout.isJohto` is 0), that the split the game will use fits the tileset it
splits (512 <= 512, both read live), and that the floor **draws** as a cave — the suite
reconstructs *both* candidate resolutions for the 16x16 metatile window the camera is showing from
live ROM pointers, reads the three overworld BG tilemaps straight out of VRAM, and asks which model
explains them. On the pre-fix ROM the answer flips and both halves fail, which is what keeps it from
degenerating into "the screen has tiles on it". **The control** is the Hoenn twin: `VictoryRoad_1F`
/`_B1F` pair the identical `gTileset_General` + `gTileset_Cave` at identical dimensions and were
always `"emerald"`, and the Johto floors are copies of them down to the warp coordinates — so the
Hoenn floor is read first and the Johto floors must report the same pointers and the same split.
No trainer suppression: one step per floor, onto a tile picked to sit outside every sight cone, so
the suite carries no hard-coded defeat flags to go stale.

### `JohtoBerrySlots.lua`

Issue #163: nine Johto berry trees shared save slots with nine other Johto berry trees, because
`johto_compat.h` aliased `BERRY_TREE_<berry>_<n>` onto `BERRY_TREE_JOHTO_<berry>_<n>`. The suite
reads `SaveBlock1.berryTrees[]` after a new game: slots 113-121 hold the right berry at
`BERRY_STAGE_BERRIES` (those indices were never written on the pre-fix ROM), and the total number
of seeded slots equals the number of `setberrytree` lines — so a future collision anywhere, not
just these nine, drops the count.

### `AzaleaGymRide.lua`

Issue #89: Azalea Gym Ariados ride carriers. Templates must be `OBJ_EVENT_GFX_SPECIES(ARIADOS)`,
not a generic Lass. Warps into the gym, checks spawned graphicsIds, then walks onto trigger 2 and
requires the ride to finish at trigger 6.

### `DayCareFlowers.lua`

Issue #165: Route 34 Day Care and Goldenrod Flower Shop have no flower object events — animation
is a tileset callback (`TilesetAnim_JohtoDayCare`) copying red/yellow flower sheets into VRAM.
The suite asserts that callback is hooked and that the flower tiles' VRAM signatures change over
an idle, rather than staying stuck on frame 0.

### `DaycareFullPartyEgg.lua`

A Route 34 daycare egg with a full party of 6 must not overwrite party slot 5: the overworld
"no room" branch has to actually run. Fresh new game, Debug Set Party, clone slot 0 across six
slots, RAM-stuff two compatible parents into the daycare, then talk to the Route 34 man. Slot 5's
pid/species stay put, the egg stays pending, and a message box opens.

### `EncountersIncenseLink.lua`

v1.5 wild-encounter / incense / link compile-outs on a fresh game: `gWildMonHeaders` is a flat
table (no time-of-day pointer fan-out), Route 123's land table can roll Roselia, Goldenrod 4F
stocks Rose Incense, the start-menu QUEST row is compiled out, and Oldale Pokémon Center 2F is
sealed. Title-screen Mystery Gift absence is the sibling suite.

### `EncountersIncenseLink_MainMenu.lua`

Issue #59: Mystery Gift compiled out of the title/main menu. Boots a fresh game, sets
`FLAG_SYS_MYSTERY_GIFT_ENABLE`, saves from the Start wheel, reboots, and waits for
`CB2_InitMainMenu` without `F.boot()` mash (that would Continue). `tMenuType` stays
`HAS_SAVED_GAME` with 3 rows; a compile-in would promote to 4. Never presses A on a menu item.

### `FollowerOutdoors.lua`

Issue #167: Grass/Bug followers comment on the outdoors. `COND_MSG_OUTDOORS` is
`MATCH_OUTDOORS + MATCH_TYPES(GRASS, BUG)` with `sOutdoorsTexts` { sniffing, breeze, deep breath }.
The suite puts an Oddish out on Route 29 and talks repeatedly until those three `sCondMsg51/52/53`
strings appear; the "happy to see what's outdoors" day-pool line is a negative control.

### `FrontierMidSave.lua`

A paused Battle Tower challenge saves through `SaveGameFrontier` → `TrySavingData(SAVE_LINK)`.
Unique SaveBlock3 bytes past the old 5-sector window (SB3[0..579]) must survive a core reboot
and Continue. Discriminates a save that only flushed the first five sectors.

### `HubNurseMonitor.lua`

World Transit hub nurse heal must spawn the FRLG 32×16 monitor, not Hoenn's 24×16. Fresh new
game, Debug Set Party, stand on (13,12) facing the desk (not Chansey's column), mash A through
the heal, and classify the sprite by OAM shape/size plus the live secondary tileset pointer.

### `JohtoFlyTeleport.lua`

v1.5 Fly and Teleport land on Johto heal **aprons**, not Center doors. Teleport copies
`lastHealLocation`; Fly uses the town-map picker / `HEAL_LOCATION_AZALEA_TOWN`. Both must be
Azalea (31,16), one tile south of the door (31,15).

### `JohtoHofLegendaries.lua`

Johto HOF rematch must not re-arm already-caught Mew/Deoxys.
`JohtoPokemonLeague_HallOfFame_EventScript_SetGameClearFlags` clears `FLAG_DEFEATED_MEW` /
`FLAG_DEFEATED_DEOXYS` (unresolved retries) and must leave `FLAG_CAUGHT_MEW` and
`FLAG_BATTLED_DEOXYS` (the caught markers) and the hide flags set.

### `JohtoMusicPass.lua`

Issue #173: Johto outdoor maps, cycling, and Radio Tower occupation play `MUS_HG_*` rather
than Hoenn/Kanto themes. Reads `gMPlayInfo_BGM` against `gSongTable` after each warp / bike /
occupation flag.

### `JohtoWhirlpool.lua`

Issue #160: Whirlpool / Glacier Badge. Without `FLAG_JOHTO_BADGE_7` the tile refuses with the
swirling-water message; with it, `applymovement` slides three tiles in the facing direction and
walks over the 2×2 invisible Archer blockers. Dragon's Den Cavern, from the dock, is the bed.

### `JohtoWhiteoutHeal.lua`

Johto whiteout / heal-tile landings plus Center monitor sprite. Fresh new game: Debug Set Party,
write `lastHealLocation` to the Violet apron (39,46), force a debug-battle whiteout, and require
the landing is that apron rather than the old Sprout Tower door (30,18). Azalea / Goldenrod /
Safari Gate heals store the apron, not the door; Johto Center heal animation is the FRLG 32×16
monitor keyed off tileset, including the hub (`MAPSEC_DYNAMIC`).

### `KenyaMail.lua`

Issue #66: Randy's Kenya gift carries RetroMail, the Route 31 sleeper actually removes her, and
TM41 bag-full is checked before the take. Talks Randy in the Goldenrod/Route 35 gate, then the
sleeper on Route 31, with a full TM pocket as the bag-full discriminator.

### `PromptSafetyEvIv.lua`

v1.5 prompt safety: intro Hard Mode defaults NO, outfit B is not a silent RED commit, Hub Pass
one-way confirm rests on NO, EV/IV Changer START flips page. Drives the Oak intro itself —
stock `F.boot()` would mash A+Start through the Hard Mode yes/no — reading oak-speech task
funcs / `sMenu` / `gWindows` before A.

### `RedGyarados.lua`

Issue #66: "The Red Gyarados is red". Lake of Rage template + spawned `graphicsId` is
`MON|SHINY|GYARADOS`; then Set Party, start the scripted fight, and read opponent shininess.
Dragon's Den elder Dratini (perfect-quiz shiny) is attempted only if a cheap warp works.

### `Route41SurfBgm.lua`

`FldEff_UseSurf` on Route 41 itself must play `MUS_HG_SURF` (670), not Hoenn `MUS_SURF` (365).
Does not surf across the Route 40 y=60 `warp_def` row — that `LoadMapFromWarp` drops SURFING
and never re-runs `FldEff`. Warps to Route 41 land, stands on an elev-3 beach, A → Surf Yes.

### `SlowpokeWellRescue.lua`

Issue #89: Slowpoke Well Jessie/James corridor gate, Kurt no longer seals Proton's chamber,
and beating Rocket walks you to Kurt's house. Coords from `SlowpokeWell_B1F/map.json`.

### `TohjoCelebi.lua`

Tohjo Falls Celebi gate. Arriving with a full-HP Celebi follower arms
`VAR_TOHJO_FALLS_GIOVANNI_STATE`. `CheckCelebi` requires lead SPECIES_CELEBI, HP==maxHP, and a
visible follower; `ON_TRANSITION` runs before `ResetObjectEvents`, so it sees the leftover
follower from the previous map. The suite then watches `sGlobalScriptContext` enter the
Giovanni scene.

### `VerifyV7Migrate.lua`

The one test that could not be written after the fact (issue #59): `fixtures/v7.srm` was harvested from the last PRE-EDIT build — a fresh game debug-warped into Oldale's Pokémon Center and manually saved at (7,4), where the saved `mapView` window covers both the Town Map poster and the escalator this branch removed. Proves `SAVE_FORMAT_LAYOUT_MIN` stayed 7 (Continue loads the save instead of refusing it), the v7→v8 ladder step ran (`saveVersion` reads 8 in RAM), and — the part that needs the fixture — the stale `mapView` did NOT repaint the old room: the live map grid holds the terminal metatiles and stair fills at the exact edited cells. On any post-edit save `mapView` is already clean and that check would pass vacuously.

> **Run it with `fixtures/v7dirty.srm`, not the `v7.srm` named above.** The entry describes
> where the v7 fixture came from, and that history is correct — but `v7.srm` happens to hold
> zeroes where `johtoTrainerFlags` lands, so the bank check passes there even with the memset
> removed. `run-all.sh` hard-codes the dirtied copy. See [Fixtures](#fixtures).

### `MigrateFixtures.lua`

That a pre-v7 save is **refused**, not half-loaded. Save format v7 reshaped SaveBlock1 and the owner chose new-saves-only, so `SAVE_FORMAT_LAYOUT_MIN` in `src/save.c` rejects older saves and the v0..v6 migration ladder is now unreachable. This suite was rewritten to assert the gate rather than a migration that can no longer happen. Any pre-v7 fixture works (v3/v4/v5 are all below the floor). As of save format v8 (issue #59) the LADDER is live again for exactly one step — v7 saves still load and get their `mapView` wiped on the way in — but that migration is proven by `VerifyV7Migrate.lua`, not here.

> **Why the gate needs a test at all:** `bag` and `pcItems` both live in SaveBlock1 **chunk 0**, and
> `SAVEBLOCK_CHUNK` only varies the *last* chunk's size. So chunks 0-2 keep size 3968, their stored
> checksums still match the flash bytes, and a legacy save loads *successfully* into the shifted
> layout — only chunk 3 fails. The result is a half-loaded save with silently misaligned flags and
> vars. The checksum is not a gate; `SAVE_FORMAT_LAYOUT_MIN` is.

### `VerifyOwnerSave.lua`

Salvage check for a **real mid-playthrough save** across the v9 break, run against the owner's battery save rather than a fixture. v9 does three things a save can notice and that save hits two: it appends `johtoTrainerFlags[]` to SaveBlock3 (un-checksummed tail, so it must be zeroed); it deletes two mid-group maps and renumbers 17 `gMapGroup_IndoorGoldenrod` and 3 `gMapGroup_MtSilver` mapNums, which are persisted in five `WarpData`s and in `objectEvents[]`; and it moves the Violet City and Route 32 heal coordinates, where `lastHealLocation` stores the COORDINATE and `GetHealLocationIndexByWarpData` matches on exact x/y, so a save holding the old pair silently stops matching the table and keeps whiting out to the old tile. Issue #51 explicitly accepted a save RESET for the renumber; this suite is the evidence that a migration was written instead and that a real save survives it. **The map-renumber half is VACUOUS here and the suite says so** — none of that save's warps are in either affected group, which is exactly why `VerifyMapRenumber.lua` exists. Where the save is STANDING and where it HEALS are separate facts; the standing map is overridable with `PW_EXPECT_GRP` / `PW_EXPECT_MAP` (defaults 75/6, Violet City) because a real save moves. **This suite cannot run on a fresh clone**: `pokemonworld.sav` is gitignored and untracked, and `MakeMigrationFixtures.sh` forbids committing a save harvested from a real playthrough. It is therefore in `run-all.sh`'s `OPTIONAL_SAVE` list — absent, it is reported `OPTIONAL` and not counted, and does **not** fail the sweep.

### `VerifyMapRenumber.lua`

The v9 deletions were not last in their groups, so every map after them renumbered down by one — 17 maps in `gMapGroup_IndoorGoldenrod` and 3 in `gMapGroup_MtSilver`. This suite proves the migration repoints the persisted indices: `lastHealLocation` 84/19 must read 84/18 and `escapeWarp` 97/11 must read 97/10, neither may land past the end of its now-shorter group, and `saveVersion` must read 9. Its own header records that it was verified to discriminate — without `MigrateDeletedTwinMaps()` both read back unchanged. The input is a **crafted** save: pre-deletion indices written into two warps with the SaveBlock1 sector checksum recomputed (SaveBlock1 **is** checksummed, unlike the SaveBlock3 banks). It was originally crafted from the owner's real save, which is why it could never be committed and why this suite sat unrunnable for anyone. `Testing/MakeRenumberFixture.py` now generates the same fixture from the tracked fresh-new-game `v7.srm`, so it carries no personal data and regenerates byte-for-byte — run `python3 Testing/MakeRenumberFixture.py --check` to assert the committed copy still matches. The generator refuses to write unless a no-op gather+writeback round trip is byte-identical to its input, because a wrong slot mapping or checksum arithmetic would otherwise yield a plausible but bogus fixture. Because the fresh save starts where `v7.srm` does, the suite's expected boot group is **2**, not Violet's 75; that constant is what `F.boot()` waits for and getting it wrong reports BOOT FAIL and looks exactly like a corrupt save.

---

## Fixtures

`fixtures/*.srm` are raw **131072-byte** battery saves (already mGBA's `.sav` format — converting is
a rename). Each `vN.srm` is a **fresh new game** built at that format version's commit, so there is
no personal data and they are deterministic. `../MakeMigrationFixtures.sh` produced v3–v5, driving
`SaveHarvest.lua` as the in-emulator harvester.

| Fixture | Used by | Role |
|---|---|---|
| `v3.srm` | `MigrateFixtures.lua` | Refusal input — the sweep passes this one. |
| `v4.srm`, `v5.srm` | `MigrateFixtures.lua` | Further refusal inputs; both are below the layout floor too. |
| `v7.srm` | — | The original hand-harvested v7 save. Kept, but **not** what the sweep runs. |
| `v7dirty.srm` | `VerifyV7Migrate.lua` | The live migration input. |

> **`VerifyV7Migrate` must use `v7dirty.srm`, not `v7.srm`.** `v7.srm` happens to hold zeroes where
> `johtoTrainerFlags` lands, so the bank check passes there **even with the memset removed** — an
> indistinguishable vacuous pass. `run-all.sh` hard-codes `v7dirty.srm` for exactly this reason; if
> you invoke the suite by hand, pass the same file.

Since the v7 layout gate (`SAVE_FORMAT_LAYOUT_MIN`), the pre-v7 fixtures are **refusal** inputs:
`MigrateFixtures.lua` asserts they are turned away at load, not migrated, because the v0→v6 ladder
steps are unreachable. `v7.srm` was hand-harvested from the last pre-#59 build (debug warp + in-game
save) and cannot be regenerated — treat it and its dirtied twin as irreplaceable. When the format is
bumped again, harvest a fixture of the outgoing version the same way and extend the migration suite
with the new ladder step.

**Two saves the suites need are NOT in the tree:**

- `pokemonworld.sav` — the owner's live save, read by `VerifyOwnerSave.lua`. Gitignored.
- ~~the crafted pre-deletion-warp save for `VerifyMapRenumber.lua`~~ — now committed as
  `fixtures/v7renumber.srm`, generated from `v7.srm` by `Testing/MakeRenumberFixture.py`. Also
  rebuildable with
  `Testing/SavePatch.py`, which patches a save and recomputes the SaveBlock1 checksum.

Gaps in the version ladder, documented rather than silent:

- **v2** — its introducing commit (`12e04c20`) does not build with the current tree
  (`ItemUseOutOfBattle_SkyCharm` was declared a commit later); a historical commit is never patched
  to harvest a fixture.
- **v1** — its commit (`37af5518`) predates the region hub, so a fresh new game runs the full classic
  Hoenn intro (truck → clock → Birch → starter) before the START menu can save; driving that
  headlessly wasn't attempted. v1 is the only entry point that would exercise the v1→v2 (`usmSaved`)
  and v2→v3 (`kantoTrainerFlags`) ladder steps as a starting version.

**Sabotage-test note (folded #21):** fresh-new-game fixtures have mostly-zero SaveBlock3 banks, so
each `savedVersion < N` ladder step (which *zeros* a newly-appended field) is a no-op on them —
removing a step is not caught, because the field was already zero. That is the whole reason
`v7dirty.srm` exists. What these fixtures DO catch is **layout drift**: `MigrateFixtures.lua` reads
each bank at its named offset, so a field inserted or reordered before a bank shifts the reads and
the exact `== 0` / `== version` asserts fail loudly. A stronger step-level sabotage would require a
played (non-fresh) save, which would put personal data in the repo — out of scope.

---

## Host-side validators (separate from these suites)

These are plain Python, read only tracked data files, need **no ROM and no emulator**, and run in
seconds. They catch the failure shape the Lua suites cannot reach cheaply: a data edit that builds,
links and boots clean, then faults or reads as broken later in play.

| Script | Catches |
|---|---|
| `../ValidateGen13.py` | References to disabled species in `.party` files and `wild_encounters.json` — blue-screens at battle send-out. |
| `../ValidateScripts.py` | Script-pointer arguments written as bare integers (`pokemart 0`). Derives the pointer slots by expanding `asm/macros/event.inc`, so it keeps working when a macro gains an argument. |
| `../ValidateOwMonPlacements.py` | Bad map-placed overworld Pokemon. A species with no `OVERWORLD(...)` entry renders as a Substitute doll rather than failing. |
| `../ValidateMapEvents.py` | Object-event consistency — who is standing there, whether the sprite matches the role, whether the trainer behind it belongs to the team it claims. Carries a REVIEW tier with recorded baselines; `--report` lists them. |
| `../GenObstacleTable.py --check` | Drift in the committed cut-tree / smashable-rock index table. The array index **is** the save bit index, so that table is save-layout-affecting data. |
| `../SavePatch.py --check` | The save tool's hard-coded sector geometry and SaveBlock sizes still matching the tree. A format bump that leaves them stale fails no build — it silently writes checksums into the wrong place. |
| `../ValidateDoorAnims.py --max 0` | Animated-door warps with no matching `sDoorAnimGraphicsTable` row. `GetDoorGraphics` matches on the metatile id **and** the tileset pointer, so a tileset that borrows another's door metatile silently loses its animation — no build error, no crash, just a warp through a shut door. Gated at zero; lower the ceiling when a batch is fixed, never raise it. A second gate, `--max-unresolved` (baseline **8**), pins the warps the census cannot read at all — it counts warps outside their map's rectangle *plus* warps whose metatile behaviour cannot be resolved, because either kind is a hole, and a hole makes the dead count go *down*. On this tree it sits at exactly its baseline with no slack: **8 out of bounds, 0 unreadable**. The eight are all coordinate errors, not tileset overflow — `BattleFrontier_BattleDomeCorridor` (6,8) and (7,8), `BattleFrontier_BattleDomePreBattleRoom` (6,8) and (7,8), `SlateportCity` (40,7), `SlateportCity_Harbor` (19,15) and (20,15), and `TinTower_8F` (-1,10). The overflow cases this gate used to hold — the Johto Victory Road floors, Route 28, Route 34's day care, Route 26 North, Mahogany Gym, the Goldenrod flower shop and the Indigo Plateau — have all had their blockdata repainted back inside their tilesets and no longer appear. A third gate catches the trap that having a row is not sufficient: `CopyDoorTilesToVram` overwrites a VRAM window at the top of the tile space while a door plays, so art *drawing* from that window is corrupted for as long as the door is open. The window is **not fixed** — it is 8 tiles at `NUM_TILES_TOTAL-8` normally but **16** at `NUM_TILES_TOTAL-16` for a `size 2` row on a non-FRLG/Johto layout, so checking only the 8-tile range would miss half of it. The check computes it per warp from the matched row's `size` and the layout's flags, exactly as the engine does, and counts every metatile the map can actually **draw** — which is more than its own blockdata. The border block is drawn all round the map, and a connected map's fringe is copied into `gBackupMapLayout` and rendered with *this* map's tilesets, so both are exposed to this map's window. The fringe depths mirror the four `Fill*Connection` routines and are **not uniform**: 7 rows/columns for north, south and west, but **8** for east, because `MAP_OFFSET_W = MAP_OFFSET * 2 + 1` makes the horizontal margin asymmetric. Using 7 for east skips its last column — 295 distinct metatile ids across 77 neighbours sit only there. That is not academic: three Goldenrod metatiles drawing tiles 1020-1023 are reachable **only** through its connection fringes, and a blockdata-only scan missed all three (41 findings vs 44 on the pre-fix data). Placement is still what keeps it honest, though — `gTileset_Johto_Building` has two metatiles drawing tile 1021, but the only maps placing either have no animated door, so flagging the tileset would be a false alarm. Four tilesets really did collide (Mahogany, Battle Frontier Outside East, Goldenrod, Goldenrod Dept. Store); their tiles were relocated and the gate is now at zero. |

Where they run:

- **`make validate`** runs all seven.
- **The pre-push hook** runs the same seven directly (not through `make`, which would trigger a full
  dependency scan for a source-only check). It is tracked at `../hooks/pre-push` — git does not clone
  hooks, so **install it after a fresh clone**: `Testing/hooks/install.sh` symlinks it into
  `.git/hooks`.
- **CI** (`.github/workflows/Check.yml`, job `validate`) mirrors all seven, so a `--no-verify` push is
  still caught.

`../GenObstacleTable.py` (no `--check`) and `../GenLuaSymbols.py` are the generators behind two of
those; `../SavePatch.py` doubles as the offline save-patching tool.

**CI does not run the Lua suites.** They need the patched, Lua-enabled headless emulator, which is
built from mGBA master and is not in the tree. `Check.yml` says so in its header. The suites are a
**local gate only** — nothing but a human running `Testing/run-all.sh` exercises them. CI runs the
content validators, the inherited upstream battle tests (`make check`), a shipping-configuration
build, and a three-leg feature-flag off-switch compile matrix.

---

## Not promoted

`_pwtest/` is gitignored scratch and, by design, nothing in it is a durable artifact. The v1.5
playtests that had a PASS on a fresh (or freshly-seeded) game now live in this directory. What
remains in `_pwtest/` is run output (logs, screenshots, sentinels) plus one-offs that still
cannot satisfy the "runs on a fresh build" bar — including `Route41Whirlpool.lua`, which has no
PASS. Do not send anyone to a `_pwtest/*.lua` path; the durable techniques all live in `lib.lua`
and [`../BizHawkTesting.md`](../BizHawkTesting.md), and the suites in this directory are the
reference implementations.

## Instrumentation probes (Route 37 red crash — open, unreproduced)

These three are **not suites and not gates**. They are deliberately absent from `run-all.sh`'s
`FRESH`/`WITH_SAVE` lists (which are explicit, not globbed), so the sweep neither runs nor expects
them. They are kept because the Route 37 crash is still open and each one closes a hypothesis with a
measurement — re-deriving that ground would cost far more than reading them.

The report: a red (`fatalf`) crash walking Route 37 shortly after entering from the bottom (from
Route 36), follower out, 2026-08-04, on the v8 save. Still **unreproduced**. Previously eliminated by
measurement: sprite pool, OBJ palettes, heap (all via a *warp* into Route 37 — see the asymmetry
below, which is why those numbers did not cover the crossing).

### `Route37CrossingProbe.lua`
Exercises the Route36 <-> Route37 map **connection** on foot rather than by warp, follower out,
sampling `gObjectEvents`/`gSprites` every step. A host-side collision scan of both `map.bin`s
establishes the connection is walkable at exactly one place — Route37 x=12..19 / Route36 x=34..41 —
so this is complete coverage of the crossing, not a sample. Result: both directions plus a deep walk
into Route 37's object cluster peaked at **8/16 objects, 23/64 sprites**. 41 slots of headroom kills
slot pressure at the crossing, and the crossing itself completes cleanly.
**Why a warp is not a substitute:** `ResumeMap()` calls `ResetSpriteData()` on the warp path, but
`LoadMapFromCameraTransition` deliberately does not (it must preserve on-screen sprites). Every
measurement taken after a warp is therefore measuring a pool that was just wiped.

### `OwnerSaveLeakProbe.lua`
Tests whether the pool was already elevated by a long real session, with the crossing merely tipping
it over. Loads a real save with `keepScene=true` so nothing moves the player before the first sample.
Result on the v8 save (`bak-prev8.sav`; player Dave, 6h30m06s, counter 20, `saveVersion 8`, verified
by parsing the flash image rather than trusting mtime): **3/16 objects, 7/64 sprites** before any
movement, flat across a confirmed walk. Lower than a fresh save. No leak.
**★ Harness trap this probe found:** `mgba-headless` autoload chokes on the 16-byte mGBA RTC
trailer. A 131,088-byte `.sav` does not fail loudly — it silently boots to **NEW GAME**, so a probe
that believes it is driving a real save is driving a fresh file. Truncate to the raw 131,072-byte
flash image; `VerifyOwnerSave.lua` went 0/1 -> 7/7 on nothing but that. Always run
`VerifyOwnerSave.lua` as the control before trusting any real-save measurement.

### `DayNightCrossingProbe.lua`
Drives the Johto day/night flip across the crossing: 3 alignments (flip before / on / after the
boundary step) x 2 directions x 2 polarities = 12 scenarios, 40 checks, follower out. All passed;
occupancy peaked at 10/16, 27/64 and fluctuated both ways as day/night mons swapped in and out of
view — not a climb. Both clock levers matter here; see the `JohtoDayNightLive` notes above for why
`SaveBlock2.localTimeOffset` and `sHoursOverride` are not interchangeable and why the TOD tick is
180 frames, not a minute.

**Status: all five hypotheses disconfirmed** (slot pressure, loader divergence, follower teardown,
day/night race, accumulated leak). The reproducible search space is exhausted. The next move is not
another probe — it is the crash screenshot, which names its own assert site: `F.crashScreen()`
decodes `FILE.C:LINE` straight out of VRAM. Never key off the screen's colour; that palette is
broken (see [`../BizHawkTesting.md`](../BizHawkTesting.md)).
