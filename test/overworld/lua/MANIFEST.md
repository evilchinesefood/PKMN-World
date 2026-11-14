# Tracked overworld Lua suites

The [canonical case list](../cases.tsv) classifies fresh-game and fixture cases as `required` or `manual`.
`run-all.sh` selects required rows for Full and their marked subset for Smoke. Host validation
rejects missing rows, unclassified new suites, and changes to mandatory fixture mappings. This document describes
coverage; historical assertion counts below are observations, not the current required count.

The suites run under pinned, patched headless mGBA on Linux and macOS. See the
[native verification guide](../mgba/README.md) for setup and explicit Build, Smoke, and Full modes.
[TestHarnessGuide.md](../TestHarnessGuide.md) documents boot signals, the debug menu, warp byte order,
and collision checks used by the suites.

## Coverage and shared files

Most cases start a fresh game. Migration/refusal cases use tracked or generated fixtures.
These scenarios are debug-assisted and can modify RAM or use debug travel. They are not a
natural playthrough or complete campaign-balance test.

Smoke selects SmokeBoot, WorldTitle, StoryProgress, and RegionalTravelMigration.
StoryProgress reads all three campaign reminders while travelling between Kanto, Johto,
Hoenn, and the hub, then saves, reboots, and Continues. Its companion host checks live in
[story-progress](../story-progress/).

| File | Role |
|---|---|
| `lib.lua` | Shared boot, input, navigation, assertion, screenshot, and verdict helpers. |
| `symbols.lua` | Generated build addresses, ABI offsets, and ROM identity. Never committed. |
| `mgba_shim.lua` | mGBA compatibility entry point. Loads the selected suite and immutable symbols. |
| `SaveHarvest.lua` | Fixture-generation utility. Not a regression suite. |

## Run a focused suite or sweep

```sh
make modern -j8
test/overworld/mgba-run.sh test/overworld/lua/SmokeBoot.lua pokemonworld.gba
test/overworld/mgba-run.sh test/overworld/lua/VerifyV7Migrate.lua pokemonworld.gba test/overworld/lua/fixtures/v7dirty.srm
test/overworld/run-all.sh pokemonworld.gba
```

Use GNU make on macOS, normally `gmake`. The mode command `python3 test/verify.py smoke`
selects GNU make and handles the build/bootstrap automatically.

The focused arguments are `<suite.lua> [rom.gba] [save.srm]`. Explicit `--elf`, `--symbols`,
and `--out` options select build inputs and an output parent. Each invocation creates a unique
run/case directory for logs, screenshots, and sentinels. No command clears sibling evidence.
Missing fixture arguments mean a fresh game; inherited `PW_SAVE` is not a fixture selection.

Both focused and batch runs use the same verdict check. Process exit zero alone is insufficient.
A selected suite must write a fresh PASS with its name, matching ROM hash, and positive equal
passed/total assertion counts. A FAIL, crash, timeout, missing verdict, or bad binding fails.
Missing or corrupt required fixtures fail the sweep. The summary lists selected, passed,
failed, and excluded coverage and the exact input identities.

`VerifyOwnerSave` is an explicit local-only check, excluded from both canonical profiles and CI.
The runners never search for `pokemonworld.sav`. To check a personal save deliberately, pass
its path as the focused runner's third argument; the runner tests a disposable copy. This
optional result must be reported separately from the canonical sweep.

## Explicit controls and input guards

Use `--rtc` to select the console epoch and `--timeout` for a focused wall-clock limit.
The default RTC is `1704110400`, or 2024-01-01 12:00 UTC, advancing with emulated frames.
`MGBA_HEADLESS` selects the emulator executable. Profiles ignore inherited case selectors.
Suite-specific controls use explicit `--env KEY=VALUE` arguments. For example, an owner-save
check can pass `--env PW_EXPECT_GRP=75 --env PW_EXPECT_MAP=6` deliberately.

The runner reconstructs the ROM from the selected ELF with the normal build recipe and
compares it before generating symbols. It then uses immutable copies of the ROM and symbols.
The Lua helper also checks their ROM hash. This rejects an unrelated ELF even if a new symbols
file could otherwise be stamped with the selected ROM's hash.

The emulator receives a disposable `Verify1.gba` with a copied fixture beside it. The name
satisfies the helper's ROM allowlist, and game writes cannot alter the input fixture or a
personal save.

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
| `WorldTitle.lua` | fresh boot, ALL_REGIONS | Native title tiles/maps/palette and layer registers; World wordmark's four-pixel offset; centered PRESS START; scrolling fog and wrap; Start/A, service-chord guard, clear-save cancel, music-end intro loop; SELECT quickstart and its badge disabled. Screenshots at each transition. Release/LTO symbols: `GenLuaSymbols.py pokemonworld-release.elf [nm] --title`, then set `PW_TITLE_SYMBOLS` to that generated file. |
| [`HubIntroTour.lua`](#hubintrotourlua) | fresh new game | The World Transit intro tour — all five reachable paths on one fresh game. |
| [`HubIntroTourFollower.lua`](#hubintrotourfollowerlua) | fresh new game | The same escort with a follower out, at the exact sprite budget. |
| [`EscortStress.lua`](#escortstresslua) | fresh new game | Cherrygrove guide gent, Violet Earl and Pewter gym guide escorts run from every reachable start and mashed through: no freeze, no menu, right final tile, flags landed. |
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
| [`EvolutionMashStress.lua`](#evolutionmashstresslua) | fresh new game | Every evolution path (after battle, cancel, forget-move prompt, Shedinja, chains, whiteout, stone, Rare Candy, soft reset) mashed without a crash, strand or corrupt party. |
| [`EconomyStress.lua`](#economystresslua) | fresh new game | The wallet at 0 and at the cap: mart buys and sells at their edges, buy-list mashing, trainer prizes, whiteouts at every Money Loss rate, and the Game Corner coin desk. |
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
| [`IcePathDoor.lua`](#icepathdoorlua) | fresh new game | Route 44's Ice Path door can be walked into: nothing stands on (68,13), its only approach tile. |
| [`JohtoHofLegendaries.lua`](#johtohoflegendarieslua) | fresh new game | Johto HOF rematch does not re-arm already-caught Mew/Deoxys. |
| [`JohtoMusicPass.lua`](#johtomusicpasslua) | fresh new game | Johto outdoor maps, cycling, and Radio Tower occupation play MUS_HG_*. |
| [`JohtoWhirlpool.lua`](#johtowhirlpoollua) | fresh new game | Whirlpool without the Glacier Badge refuses; with it, the slide walks over the blockers. |
| [`JohtoWhiteoutHeal.lua`](#johtowhiteoutheallua) | fresh new game | Johto whiteout lands on the Violet apron, Center heals store aprons, FRLG monitor. |
| [`KenyaMail.lua`](#kenyamaillua) | fresh new game | Randy's Kenya gift carries RetroMail; Route 31 sleeper removes her; TM41 bag-full is first. |
| [`FamilyOptions.lua`](#familyoptionslua) | fresh new game | Four choices on every rate control and Text Speed, staged writes, reopen, real save/Continue, and global regional travel. |
| [`FamilyOptionsFieldStress.lua`](#familyoptionsfieldstresslua) | fresh new game | Options from the main menu (before New Game and Continue) and from the Start menu with a follower, a Repel, rain and Surf, restoring the field each time. |
| [`InstantTextStress.lua`](#instanttextstresslua) | fresh new game | Instant text mashed through nurses in all three regions, building PCs, the Pokedex, Trainer Card, PokeNav, Name Raters, Move Relearners, a Day Care, TV, a catch with nickname, Cut, Rock Smash, Strength and Flash, Safari Zone time's up and Bug-Catching Contest judging. |
| [`StartOptionsStateStress.lua`](#startoptionsstatestresslua) | fresh new game | Start-menu Options during a DexNav search, in a Flash-dark cave before and after Flash, on both bikes, mid fishing chain, in both Safari Zones, in the Bug-Catching Contest and a Frontier lobby, restoring each state. |
| [`FamilyOptionsMigration.lua`](#familyoptionsmigrationlua) | generated v11 Hard Mode fixture | Continue initializes only new rate bits and preserves preferences, money, Pokemon, and location. |
| [`PromptSafetyEvIv.lua`](#promptsafetyevivlua) | fresh new game | Intro skips difficulty selection; outfit B stays on the picker; EV/IV START flips page. |
| [`RedGyarados.lua`](#redgyaradoslua) | fresh new game | Lake of Rage Red Gyarados is MON\|SHINY\|GYARADOS in the overworld and in battle. |
| [`Route41SeaReturn.lua`](#route41seareturnlua) | fresh new game | The Route 40/41 strait is two-way: surf north from a Route 41 sea arrival onto Route 40 past its arrow row. |
| [`Route41SurfBgm.lua`](#route41surfbgmlua) | fresh new game | FldEff_UseSurf on Route 41 plays MUS_HG_SURF, not Hoenn MUS_SURF. |
| [`SlowpokeWellRescue.lua`](#slowpokewellrescuelua) | fresh new game | Slowpoke Well Jessie/James gate, Kurt no longer seals Proton, Rocket walk-out. |
| [`TohjoCelebi.lua`](#tohjocelebilua) | fresh new game | A full-HP Celebi follower arms the Tohjo Falls Giovanni scene. |
| [`ExpansionHealthboxes.lua`](#expansionhealthboxeslua) | fresh new game | Issue #120 A: Safari leftover-ball text (FillSpriteRect left=55), singles nick/HP numbers, doubles healthboxes. |
| [`CatchTutorial.lua`](#catchtutoriallua) | fresh new game | Issue #120 B: Viridian Old Man tutorial does not say WALLY; Petalburg Wally control still does. |
| [`DayNightTint.lua`](#daynighttintlua) | fresh new game | Issue #120 C: day/night palette tint on Hoenn/Kanto/Johto routes, cave control, night fade-in. |
| [`RainPaletteSlots.lua`](#rainpaletteslotslua) | fresh new game | Object palettes loaded mid-rain take exactly the rain colour map, and every slot returns to its unfaded colours when rain stops in place. |
| [`HubPassReCross.lua`](#hubpassrecrosslua) | fresh new game | The Hoenn hub gate seeds Littleroot ONCE on **both** gender branches; re-crossing does not rewind; `hoennIntroDone` only latches arrival narration, while the Stone Badge alone unlocks Slateport. |
| [`VerifyV7Migrate.lua`](#verifyv7migratelua) | `fixtures/v7dirty.srm` | The v7→v8 ladder step runs, and the stale `mapView` does not repaint the old room. |
| [`MigrateFixtures.lua`](#migratefixtureslua) | `fixtures/v3.srm` | A pre-v7 save is *refused* at load, not half-loaded. |
| [`VerifyOwnerSave.lua`](#verifyownersavelua) | explicit personal-save path, local only | A real mid-playthrough save survives the v9 break. |
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

### `EscortStress.lua`

Every escort the hack ships outside the hub tour, started from its real trigger and then mashed: A, B, Start, Select, L, R and all four directions cycle every few frames from the moment the guide moves until the script context shuts down. Cherrygrove guide gent: decline at a coord trigger (state 1, gent stays), the talk re-offer from (57,9), and the Top / Mid / Bottom triggers, each ending on (41,16) with the gent removed, `FLAG_HIDE_GUIDE_GENT_CHERRYGROVE` set, the house copy shown and `VAR_CHERRYGROVE_CITY_STATE` 1. Violet Earl, talked to from the south and from the east (the only two open sides, and the two `VAR_FACING` cases the script switches on), both ending on (38,38) with Earl hidden. Pewter gym guide via the coord trigger, from the west, and from the Route 3 side, where `VAR_FACING` is WEST and the script skips the walk by design. Every run asserts no vblank stall or crash screen, Start never opened the menu mid-walk (so a mid-escort save is unreachable), the field callback never changed, the final tile, and that a real step lands afterwards. **The guide's removal is read at script end:** Pewter's script clears `FLAG_HIDE_PEWTER_CITY_GYM_GUIDE`, so he respawns home on the next camera update by design.

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

### `EvolutionMashStress.lua`

Adversarial mashing through the evolution flow. Each scenario arms a real evolution and drives the scene with a seeded pseudo-random mash of A, B, Start, Select, L, R and the D-pad, then requires that the scene ran (one `sEvoStructPtr` lifetime per evolution), no crash screen came up, the field came back walkable, every party slot still decrypts with a valid checksum, the count covers exactly the occupied slots, and the follower shows the lead's current species. **Arming:** the debug Give menu builds each mon at its level with matching EXP (the end-of-battle `CalculateMonStats` re-derives level from EXP, so a poked level byte would be undone); the suite keeps those raw bytes and writes them into the party once a debug battle is running, mirrors slot 0 into the player's battler (the battle writes the battler's moves and PP back into slot 0, so a mismatch would graft the debug Wobbuffet's moveset onto the evolving mon), then sets the slot's bit in `gLeveledUpInBattle` and forces `gBattleOutcome`. **Scenarios:** Bulbasaur 16 mashed (must become Ivysaur, never cancelling) and the same evolution held on B (must stay Bulbasaur, through the CANCEL branch); Ivysaur 32 into Venusaur with a full moveset, mashed and B-declined (forget-move prompt reached, moveset unique, PP sane, the learned Petal Blizzard at base PP with its slot's PP bonus cleared); Nincada with a full party, with five and a Poke Ball, and with five and none (never a seventh slot, Shedinja only when a ball was there to spend); three evolutions back to back behind the level-up summary box, and again with B allowed alone; an evolution followed by a whiteout; a Thunder Stone from the bag with an Egg Pikachu in front of a real one (the Egg is refused and never evolves, one stone spent); three Rare Candies across a move prompt into an evolution, one candy into Venusaur's evolution-move prompt from a bag-started scene, and one candy that adds Shedinja under the bag; and the A+B+Start+Select soft reset during the sprite cycle, then Continue (the saved party loads byte for byte). **Why B is never alone in the evolving mashes:** `Task_EvolutionScene` cancels when `gMain.heldKeys == B_BUTTON` exactly, so a lone B would make "the species changed" a coin toss; the B-held scenario is the control. `PW_EVO_SEED=<n>` reseeds the mash and `PW_EVO_ONLY=<text>` runs only matching scenarios.

### `EconomyStress.lua`

Money and items at their edges, every amount read from RAM. **Mart (hub front desk):** one short of a Great Ball is refused before the quantity window and changes nothing; exactly 600 buys one with a spinner capped at 1 (Up, Down and Right stay put); 999,999 caps the spinner at 999, Down from 1 wraps to 999 and Up wraps back, 999 cost 599,400 with 99 bonus Premier Balls, and a 1,000th ball spills into a new slot; a Balls pocket full of 999-stacks refuses the purchase without taking money. **Selling (the shop's SwSh bag):** every Nugget that leaves the bag must be paid in full and the sale is limited to what the wallet can absorb, from 0, 990,000, 997,000 and 999,999. **Mashing:** a seeded mash of the shop at Instant text (Start included, so it can leave and come back) with an empty bag and 0, 19 and 50,000 must not crash, must hand control back, and a wallet under the cheapest price (the 20 Premier Ball) buys nothing. **Prizes:** a debug trainer win at 999,999, 999,990 and 0 must add the prize up to the cap, and the "You got" line must print the prize (`gBattleTextBuff1`). **Whiteouts:** a debug-battle defeat at every Money Loss rate with wallets 0, 1, 2, 3 and 50,000 must take `min(wallet, 8 x top level x rate)` and print exactly that amount. **Coins:** the Mauville desk with 9,998, 9,990 and 9,999 coins and with exactly or one short of 100,000. **Discrimination measured:** with the sell clamp reverted the three over-the-cap sell scenarios fail (ten Nuggets for 9,999, three Nuggets for nothing at the cap); with `BuyGameCornerCoins` reverted, a near-full case pays 100,000 for one coin. `PW_ECON_ONLY=<text>` runs matching scenarios, `PW_ECON_SEED=<n>` reseeds the mash and `PW_ECON_TRACE=1` logs the battle text.

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

### `JohtoHofUnchosenBirdReach.lua`

The Johto Hall of Fame's first clear offers the bird the player did not pick, and must clear what
blocks it: the Whirl Islands Tentacruel on a GOLD save and the Tin Tower sage on a SILVER save. The
suite seeds the branch the campaign doesn't play and runs the real ceremony script.

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

The introduction completes without a permanent difficulty prompt. Outfit B stays on the picker,
Hub Pass confirmation rests on NO, and EV/IV Changer START flips pages. The driver reads tasks
and windows before advancing the introduction. After checking the Mid default, it selects Instant
for the field confirmation and EV/IV controls.

### `IcePathDoor.lua`

The Ice Path door on Route 44, warp 0 at (68,12), is entered only from (68,13). A scenery Pidgeotto
(object 24, flag 0) sat on that tile after the July re-pointing of static overworld Pokemon (its upstream
tile, (68,9), is inside the cliff), sealing the only land route to Blackthorn. Arrives by debug warp,
steps back and walks into the door. Found by `test/overworld/johto-playthrough/`.

### `RedGyarados.lua`

Issue #66: "The Red Gyarados is red". Lake of Rage template + spawned `graphicsId` is
`MON|SHINY|GYARADOS`; then Set Party, start the scripted fight, and read opponent shininess.
Dragon's Den elder Dratini (perfect-quiz shiny) is attempted only if a cheap warp works.

### `Route41SeaReturn.lua`

Route 40's water-arrow row is the way to Cianwood, and Route 41 row 11 / Route 40 row 61 used to be
ocean tiles with the collision bit set, so nothing led back: a Cianwood softlock until Jasmine's badge
unlocked Fly, which itself needs the Secret Potion from Cianwood. Warps to a sea arrival (41,12) and
surfs north through both former walls to Route 40 y<=59. Found by `test/overworld/johto-playthrough/`.

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

### `ExpansionHealthboxes.lua`

Issue #120 playtest A, which `make check` cannot see: `FillSpriteRect` healthbox text. Safari leftover-ball text is the only `FillSpriteRectColor(..., left=55, ...)` caller (`src/battle_interface.c:1963`, `55%8=7`, the unaligned case). The suite warps to Safari Zone South, sets `FLAG_SYS_SAFARI_MODE` and `gNumSafariBalls=30`, walks grass until `gBattleTypeFlags` has `BATTLE_TYPE_SAFARI`, screenshots the "Safari Balls / Left: $N" box at 30, throws, and requires `gNumSafariBalls` 30→29 with a second screenshot. Singles is Start Debug Battle: trainer flag, in-battle, an HP word in `gBattleMons` actually changed (so a clean HP *bar* from `MoveBattleBar` cannot pass it), player and foe healthbox sprites live. Doubles cannot use the debug trainer (`Battle Type: Singles`); the Trainers debug menu's Try Battle with trainer 1 + trainer 2 sets `BATTLE_TYPE_DOUBLE | BATTLE_TYPE_TWO_OPPONENTS`. If that battle is not reached, `doubles_healthbox_reached` FAILs rather than skipping. **★ Set Party before any battle.** Safari step counter must be written too: 0 fires the times-up script on the first step.

### `CatchTutorial.lua`

Issue #120 playtest B. `GetCurrentRegion()==REGION_KANTO` chooses "The old man" / `SetControllerToOakOrOldMan`; otherwise "WALLY" / `SetControllerToWally`. The pre-fix `IS_FRLG` arm was hard-0 in ALL_REGIONS, so every catch tutorial printed WALLY — including Viridian. **The load-bearing assert is `kanto_text_has_no_WALLY`:** pokeStr of `gDisplayedStringBattle` during `StartOldManTutorialBattle` (WEEDLE) must contain OLD MAN / WEEDLE and must not contain WALLY. The Petalburg control (`StartWallyTutorialBattle`, region Hoenn via a warp first) must contain WALLY / RALTS and must not contain OLD MAN, so a suite that never printed anything cannot go green. Do not use debug Cheat start: `IS_FRLG` is hard-0 and it always runs Hoenn CheatStart.

### `DayNightTint.lua`

Issue #120 playtest C. This is palette tint, **not** Johto object swap — `JohtoDayNightLive.lua` already crosses 19:59→20:00 on Route 37 and asserts flags/objects. Standing still, no warp during the tick: outdoor Hoenn Route 101, Kanto Route 1, Johto Route 37, plus Granite Cave 1F as the indoor control (`MapHasNaturalLight` is false for `MAP_TYPE_UNDERGROUND`, so `ApplyWeatherColorMapIfIdle` is skipped). Clock lever is `SaveBlock2.localTimeOffset` (survives a warp); `gTimeUpdateCounter=0` forces the tick. Outdoors: after 20:00, `gTimeOfDay` is night AND (`gTimeBlend` words changed). Cave: `gTimeOfDay` may still advance but map pals in `gPlttBufferFaded` must not take the night tint. Fade-in at night warps into Route 101 with a night clock (the `field_weather.c` TRUE path).


### `RainPaletteSlots.lua`

Recomputes every in-use, non-blend-immune object palette from `gPlttBufferUnfaded` and the ROM colour maps (`sDarkenedContrastColorMaps`, `sContrastColorMaps` for the weather palette slot, indexed `colorMapIndex - 1`, exactly as `ApplyColorMap` picks them) and compares to `gPlttBufferFaded`. The clock is pinned to 14:30 and a clear Route 101 audit proves the day blend is the identity first. Then Olivine City (`WEATHER_RAIN`): slots loaded during the warp fade-in, the follower, and Tentacool / Tentacruel / NPC palettes loaded by camera spawns into previously free slots after the fade-in. Then rain stops in place (the three fields `SetNextWeather` writes) and every slot, mid-rain loads included, must equal its unfaded colours, then rain restarts. **Discrimination:** with `LoadDynamicFollowerPalette`'s weather call disabled the suite fails on the follower and both spawned Pokémon slots (18/20).

### `HubPassReCross.lua`

Issue #195's five scenarios on one fresh new game, driven end to end through the real scripts —
no `warpTo` anywhere in the journey. `hoennIntroDone` (`SaveBlock2 +0x92` bit 2) is written by
**one** site, `region_intro_done_hook` on Littleroot Town's `ON_FRAME`, so a player who takes the
HUB PASS back out of the bedroom before ever stepping outside still reads as a first visit, and
`RegionHub_EventScript_AttendantHoennBoard` re-ran its whole seed on the next cross. **S2** — a
genuine first visit still seeds (intro state 5, because 2F's `ON_TRANSITION` turns the seeded 4
into 5 before anything can read it; houses state 1; the six hide flags; `setrespawn` overriding the
arrival respawn). **S1** — reach state 6 through the clock-already-set branch, stage a houses state
of 2 and an OLDALE POKéMON CENTER respawn, SELECT the HUB PASS out of the bedroom, re-cross, and
assert nothing rewound. **S3** — walk 2F → 1F → outdoors, catch `VAR_REGION_ARRIVAL` at 1 while the
arrival box is still up, then assert the hook latched the bit and cleared the var. **S3b** proves
that latch is not the travel unlock: with `hoennIntroDone` set but the Stone Badge clear, the same
attendant returns the player to Brendan's 2F. **S3c** changes only `FLAG_BADGE01_GET`, crosses
again, and requires SLATEPORT HARBOR (`RegionHub_EventScript_ReturnHoenn`).

**S4/S5 are the same fix on the FEMALE branch,** added as a second segment rather than a sibling
suite. S1–S3 pin `playerGender == MALE`, so every one of their assertions walks straight past
`goto_if_eq VAR_RESULT, FEMALE` and `RegionHub_EventScript_FirstVisitHoennFemale` — which got the
identical `call_if_eq VAR_LITTLEROOT_INTRO_STATE, 0` guard — had **no coverage at all**. It is not a
copy of the male script either: it writes `VAR_LITTLEROOT_HOUSES_STATE_MAY` (`0x4082`, *not*
`..._BRENDAN + 1`), a different six hide flags, `HEAL_LOCATION_LITTLEROOT_TOWN_MAYS_HOUSE_2F` and a
warp to May's 2F, so a regression there is invisible to S1/S2/S3. **S4** rewrites the persisted
facts that define a Hoenn first-timer (`playerGender`, the intro state, the houses state,
`hoennIntroDone`, and the Stone Badge) and clears the six female seed flags, then HUB PASSes
back to the hub and crosses for real — landing in `MAP_LITTLEROOT_TOWN_MAYS_HOUSE_2F` `(1,3)` is by
itself proof the gender branch was taken, since only `goto_if_eq VAR_RESULT, FEMALE` reaches that
map. **S5** repeats S1 on that branch: clock → 6, stage houses(MAY) = 2 and an OLDALE respawn, HUB
PASS out, re-cross, assert nothing rewound. Nothing about the *journey* is forged — the pass is used
from the field and the gate's own scripts pick the branch, seed the state and place the warp.

**Discrimination measured, not assumed.** Against a ROM built at `549ff1400f` without the guard the
suite drops **67/67 → 52/57**, and every failure names the defect: `intro=5 houses=1` after the male
re-cross and the downstream mom-bounce that puts the player back on 2F, then `intro=5 housesMay=1`
after the female one. Three fixed and three unfixed runs were byte-identical, ~10 s each.

**★ Two traps the May segment paid for.** May's house is the horizontal **mirror** of Brendan's
(`x → 8−x` on the 9-wide 2F layout), so the male coordinates do **not** carry over — except the two
that sit on the mirror axis, which is why the gate warps both genders to `4, 4` and both heal
locations are `(4,2)`. The wall clock sign is at `(3,1)` — stand on `(3,2)` facing Up, against the
male `(5,1)`/`(5,2)` — and the stairs are at `(1,1)`, not `(7,1)`. And the route to the clock needs an explicit waypoint up the `x=4` column:
`leg()` walks x before y, so a bare route from the arrival tile `(4,4)` hops through `(3,4)`, which
is where May's 2F parks its PICHU DOLL (Brendan's has an ITEM BALL there, which is why the male
segment never met it). Separately, **both `FLAG_HIDE_..._TRUCK` flags are in both seed lists** — the
hub hides both trucks whichever gender crosses — so S4 clears all six female seed flags before its
cross, or two of its six flag assertions would pass on S2's leftovers no matter what the female
script did.

**★ The respawn is a CONTRACT check, not a discriminator, and the suite says so in its own
assertion name.** `setrespawn` deliberately stays *outside* the guard — the gate warps the player to
2F on every PRE-BADGE visit, so 2F is the right respawn on those visits — so it reads `(1,1)@(4,2)` on both
ROMs — and `(1,3)@(4,2)` for the female twin. An earlier draft asserted "the respawn was not
stomped back to the bedroom" and failed on the **fixed** ROM; the bytecode at `RegionHub_EventScript_AttendantHoennBoard` (`setrespawn` at
`0x083AFEC4`, *before* the `compare`/`call_if`) is what settled it. Assert the fix's scope, not the
issue title's.

**★ Four more traps this suite paid for.** `lib`'s `pick()` cannot drive a YES/NO: both
`ScriptMenu_YesNo` and the field item confirm run `Menu_ProcessInputNoWrapClearOnChoose`, so Down at
the bottom row does **not** wrap and `pick()`'s Down-only walk burns its whole budget — and the HUB
PASS confirm rests on **NO** by design (`item_use.c`), so a suite that only presses Down/A declines
the warp. The local `yesNo()` probes with Down *then* Up and then drives the cursor by reading
`sMenu`. The HUB PASS item id is **derived**, not hardcoded: `ITEM_HUB_RETURN` is the one key item
that appears across the first cross, so an `ITEMS_COUNT` shift cannot make the suite drive the wrong
item. `"downstairs is 1F"` must be re-read **after** the arrival scene, not on the frame the warp
lands: at the rewound state 5, 1F's `ON_TRANSITION` parks Mom on the stairs and
`GoUpstairsToSetClock` warps you straight back to 2F, so the on-arrival sample reports 1F for a run
that got bounced — that is the single assertion that turned S3 from a cascade into a diagnosis. And
1F's `PetalburgGymReport` cutscene applymovements the player to the TV at (4,5), where both Right
*and* Down are furniture: walk back out the way the cutscene walked you in (east to (8,5)), then
south onto the door mat.

**Symbols added for it:** `SaveBlock2.introDoneBits = 0x92` (the table used to jump `0x91 → 0x93`,
so #195's only persisted observable was unreadable) and `SaveBlock1.registeredItem = 0x496`, both in
`test/overworld/GenLuaSymbols.py`. Regenerating `symbols.lua` from the same ELF is otherwise byte-identical.

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

Salvage check for a **real mid-playthrough save** across the v9 break, run against the owner's battery save rather than a fixture. v9 does three things a save can notice and that save hits two: it appends `johtoTrainerFlags[]` to SaveBlock3 (un-checksummed tail, so it must be zeroed); it deletes two mid-group maps and renumbers 17 `gMapGroup_IndoorGoldenrod` and 3 `gMapGroup_MtSilver` mapNums, which are persisted in five `WarpData`s and in `objectEvents[]`; and it moves the Violet City and Route 32 heal coordinates, where `lastHealLocation` stores the COORDINATE and `GetHealLocationIndexByWarpData` matches on exact x/y, so a save holding the old pair silently stops matching the table and keeps whiting out to the old tile. Issue #51 explicitly accepted a save RESET for the renumber; this suite is the evidence that a migration was written instead and that a real save survives it. **The map-renumber half is VACUOUS here and the suite says so** — none of that save's warps are in either affected group, which is exactly why `VerifyMapRenumber.lua` exists. Where the save is STANDING and where it HEALS are separate facts; the standing map is overridable with `PW_EXPECT_GRP` / `PW_EXPECT_MAP` (defaults 75/6, Violet City) because a real save moves. **This suite cannot run on a fresh clone**: `pokemonworld.sav` is gitignored and untracked, and `MakeMigrationFixtures.sh` forbids committing a save harvested from a real playthrough. It is excluded from the canonical case list and CI. Run it only as an explicit focused local check with a selected save path.

### `VerifyMapRenumber.lua`

The v9 deletions were not last in their groups, so every map after them renumbered down by one — 17 maps in `gMapGroup_IndoorGoldenrod` and 3 in `gMapGroup_MtSilver`. This suite proves the migration repoints the persisted indices: `lastHealLocation` 84/19 must read 84/18 and `escapeWarp` 97/11 must read 97/10, neither may land past the end of its now-shorter group, and `saveVersion` must read 9. Its own header records that it was verified to discriminate — without `MigrateDeletedTwinMaps()` both read back unchanged. The input is a **crafted** save: pre-deletion indices written into two warps with the SaveBlock1 sector checksum recomputed (SaveBlock1 **is** checksummed, unlike the SaveBlock3 banks). It was originally crafted from the owner's real save, which is why it could never be committed and why this suite sat unrunnable for anyone. `test/overworld/MakeRenumberFixture.py` now generates the same fixture from the tracked fresh-new-game `v7.srm`, so it carries no personal data and regenerates byte-for-byte — run `python3 test/overworld/MakeRenumberFixture.py --check` to assert the committed copy still matches. The generator refuses to write unless a no-op gather+writeback round trip is byte-identical to its input, because a wrong slot mapping or checksum arithmetic would otherwise yield a plausible but bogus fixture. Because the fresh save starts where `v7.srm` does, the suite's expected boot group is **2**, not Violet's 75; that constant is what `F.boot()` waits for and getting it wrong reports BOOT FAIL and looks exactly like a corrupt save.

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
> indistinguishable vacuous pass. The canonical case list selects `v7dirty.srm` for exactly this reason; if
> you invoke the suite by hand, pass the same file.

Since the v7 layout gate (`SAVE_FORMAT_LAYOUT_MIN`), the pre-v7 fixtures are **refusal** inputs:
`MigrateFixtures.lua` asserts they are turned away at load, not migrated, because the v0→v6 ladder
steps are unreachable. `v7.srm` was hand-harvested from the last pre-#59 build (debug warp + in-game
save) and cannot be regenerated — treat it and its dirtied twin as irreplaceable. When the format is
bumped again, harvest a fixture of the outgoing version the same way and extend the migration suite
with the new ladder step.

`VerifyMapRenumber` uses tracked `fixtures/v7renumber.srm`, generated from `v7.srm` by
`MakeRenumberFixture.py`. RegionalTravelMigration uses tracked `v10regionaldirty.srm`.
FamilyOptionsMigration uses a generated v11 fixture in the unique run directory.
The canonical list owns these mappings. No required case depends on a personal save.

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

## Host-side validators

`python3 test/validate-host.py` directly runs the current Python/content validators and the
native Story resolver checks. The [script](../../validate-host.py) owns that command inventory.
It needs no ROM, ARM compiler, or emulator and does not evaluate the game Makefile.

[Check.yml](../../../.github/workflows/Check.yml) invokes this command for every PR and master
push, including documentation-only changes. Its stable result is `Content validation (host-side)`.
The optional local [pre-push hook](../hooks/pre-push) also runs direct content checks.
Do not use `make validate` for automatic host-only validation because Makefile parsing can
start game build setup.

Builds, Lua suites, battle checks, and feature-off builds run only through explicit local
commands or [Verify on demand](../../../.github/workflows/Verify.yml). Smoke and Full can run
on Linux CI or local macOS. There are no schedules and no build-output uploads. The
[release checklist](../../../RELEASING.md) still requires deliberate complete candidate checks.

---

## Not promoted

`_pwtest/` is gitignored scratch and, by design, nothing in it is a durable artifact. The v1.5
playtests that had a PASS on a fresh (or freshly-seeded) game now live in this directory. What
remains in `_pwtest/` is run output (logs, screenshots, sentinels) plus one-offs that still
cannot satisfy the "runs on a fresh build" bar — including `Route41Whirlpool.lua`, which has no
PASS. Do not send anyone to a `_pwtest/*.lua` path; the durable techniques all live in `lib.lua`
and [`../TestHarnessGuide.md`](../TestHarnessGuide.md), and the suites in this directory are the
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
Aimed at H5 — was the pool already elevated by a long real session, with the crossing merely tipping
it over? Loads a real save with `keepScene=true` so nothing moves the player before the first sample.
Measured on the v8 save (`bak-prev8.sav`; player Dave, 6h30m06s, counter 20, `saveVersion 8`,
verified by parsing the flash image rather than trusting mtime): **3/16 objects, 7/64 sprites** before
any movement.

**★ Read this before citing that number: it does NOT disconfirm H5, and the probe as designed
cannot.** Sprite-pool occupancy is RAM, not save data. Loading a save therefore always begins from a
freshly initialised pool, so the accumulated state H5 posits is destroyed by the very act of loading
the save — the 3/16, 7/64 figure describes a fresh boot, not the machine state the owner was in after
hours of play. It is evidence about this save's *resume-position object density* and nothing more.
The intended extended walk was also never achieved: a reproducible movement/input anomaly on this
particular `keepScene=true` boot path reduced the movement evidence to a single confirmed 3-tile
sample, which is far too short to show or exclude accumulation.

**H5 was therefore reopened after this probe, and settled by `SustainedWalkLeakProbe.lua` below** —
which needs no real save at all, because the hypothesis is about accumulation during ordinary
non-warp play. Keep this section as the worked example of a measurement that cannot bear the
conclusion drawn from it.

### `SustainedWalkLeakProbe.lua`
The probe H5 actually needed. Fresh save, follower out, **one** warp at the very start and never
again, then 60 laps / **3,820 steps**: cross south over the Route37<->Route36 connection, dip into
Route36 and back, cross north, walk up through Route 37's object-dense stretch (4 `LIGHT_SPRITE`s,
day/night VULPIX/PIDGEY) and back. Sampled every tile.

**The signal is the per-lap FLOOR, not the peak** — a pool oscillating high and low forever is
healthy; a rising *minimum* is the leak. Reading only the peak is what made earlier numbers look
reassuring. Result: the floor sat at 10, blipping to 12 three times in 60 laps, longest
consecutive-rising run **1 lap**. Object floor flat at 2-3. Run-max 9/16 and 27/64, consistent with
every other probe. Warp-free by construction and by assertion.

**★ Methodology hazard this probe hit, worth reusing:** the follower lost a wild battle mid-run and
the whiteout teleported it to Petalburg — a whiteout is a warp-style load, i.e. exactly the
`ResetSpriteData()` this probe exists to avoid, and it would have voided the invariant silently.
Fixed by leveling the follower to 100 and asserting `grp() == 83` after every battle settle. Any
long-walk probe needs that guard, or it can quietly measure nothing.

Why this closes H5 rather than merely failing to reproduce: every warp AND every battle init calls
`ResetSpriteData()` (`src/battle_main.c:609`), so the only window in which sprites can accumulate at
all is a walking stretch between resets. 3,820 steps far exceeds any window real play can produce.

Static audit done alongside it: `TrySetupObjectEventSprite` -> `RemoveObjectEventInternal` ->
`DestroySprite` is paired; `SpawnLightSprite` dedups and self-cleans via `UpdateLightSprite`;
`GetAvailableObjectEventId` dedups by localId+map so repeated walk-bys cannot double-spawn a
template. One genuine asymmetry, **masked today and not an explanation for anything here**:
`DespawnOWEOnBattleStart()` (`src/wild_encounter_ow.c:1551`) calls `ClearObjectEvent()` rather than
`RemoveObjectEvent()`, so it never `DestroySprite()`s — harmless only because battle init resets the
whole pool moments later. A refactor that reorders or skips that reset would turn it into a real
leak.

Also worth knowing, since it sets the failure mode for the whole investigation: the defensive
`>= MAX_SPRITES` bailouts in `TrySetupObjectEventSprite` and `SpawnLightSprite` are dead code,
because `CreateSprite()` (`src/sprite.c:433`) `fatal_assertf`s before it could return that sentinel.
True pool exhaustion red-crashes rather than degrading gracefully — so the crash shape is consistent
with exhaustion, it is just that nothing tested across four rounds got past 27/64.
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

**Status: all five hypotheses disconfirmed by measurement** — slot pressure at the crossing, loader
divergence, follower teardown, the day/night race, and the accumulated leak. Note the leak took two
attempts: the real-save baseline could never have tested it (see the ★ above), and only the 3,820-step
warp-free walk actually did. If you are tempted to retire a hypothesis on a single number, check
first that the measurement can physically exhibit the thing you are ruling out.

The next move is not another probe. It is the crash screenshot, which names its own assert site:
`F.crashScreen()` decodes `FILE.C:LINE` straight out of VRAM. Never key off the screen's colour;
that palette is broken (see [`../TestHarnessGuide.md`](../TestHarnessGuide.md)).


### `RegionalTravel.lua`

Issue #377 controller acceptance, fresh save. Drives the actual hub choices for all six
directed campaign pairs and three same-region returns; both team and arrival choices,
Hub Pass cancellation/departure, three physical Center entries without healing, real
save/Continue after keep-current arrival, Center entry without healing, hub departure,
successful recall, cancellation and partial recall, explicit partial confirmation and
forced whiteout recovery. Drives maiden SS Aqua boarding, disembark, return ferry,
Olivine–Frontier voyage, the reception gate and neutral hub shuttle; checks departure
ownership with a changed onboard/neutral party. Seeds checkpoint/progress prerequisites
for actual safe/fallback menu travel at Cianwood, Sootopolis, Sevii, Kanto League and
Mt Silver; Cianwood distinguishes outgoing versus recalled party and source versus
destination badges. Hoenn League resumes with a non-water/non-flight party and exits
through the actual Hub Pass. Also drives direct Slateport harbor-to-hub capture and
S.S. Tidal Slateport-to-Frontier boarding/capture with its normal (19,67) dock arrival,
then proves a changed neutral party cannot overwrite the Hoenn departure on Hub Pass
return. The ordinary intra-Hoenn Slateport–Lilycove cruise is not a campaign departure.
Expanded standalone measured **221/221**, ROM MD5
`30B28AF582B8B400855381A27E3C79FA`. The complete sweep passed 56/56 suites and
1,589 assertions with the prior 189-assertion version on the same unchanged ROM.
Prerequisite setup is not evidence of natural acquisition, and the forced battle outcome
is not a gameplay balance test. The dock-to-shuttle route must pass through reception:
there is no walkable north path from the dock across the building wall.

### `RegionalTravelMigration.lua`

Issue #377 in-game migration acceptance. Requires
`fixtures/v10regionaldirty.srm`; provenance is in `fixtures/v10regional.md`. Loads a
checksummed version-10 save with dirty identity-padding and appended-history bytes,
checks the original boxed individual exactly after cleanup and empty regional history,
then proves that Continue inside a Center does not synthesize entry while a later actual
door entry records the Center. Measured **10/10**; no save fixture means this test must
not be counted as run. Offline complementary tests are
`../TestRegionalTravelMigration.py`, including all 433 saved owners and all 24 substructure
orders.

### `FamilyOptions.lua`

Exercises every rate and text selection in both directions, including wraparound. Verifies staged
values, unchanged adjacent settings, real save/Continue, and global settings across Kanto, Johto,
and Hoenn travel. Captures each row for native label review. `TestFamilyOptionsMigration.py`
checks the offline v12 migration separately; target C tests verify the game migration and layout.

### `FamilyOptionsFieldStress.lua`

Opens Options from the main menu before New Game and checks the choices reach the new game, then
from the Start menu in the hub with a follower, during a Repel, twice in Cianwood's rain, and twice
while surfing in Dragon's Den. Each visit moves every row Right and Left, then leaves Text Speed and
the four rates on a different column, so every value is written from the field. Each return is
compared with a snapshot taken before Start: map, tile, facing, avatar flags, object events and
the follower, the playing song, the Repel count, the map's BG palettes, each OBJ palette by its
tag, and that no sprite draws from a freed palette slot. Ends with a save, reboot, main menu
Options without changes, and Continue. Free OBJ slots and BG 13-15 are excluded on purpose: the
fade into a menu copies weather-tinted colours into them and nothing on the field reads them.
Passed 167/167. It found no field-restore defect; the whiteout badge defect it was written beside
is pinned by the `Family money loss counts the campaign region's badges` C test.

### `InstantTextStress.lua`

Sets Text Speed to Instant, then starts each message-heavy flow the way a player does (warping to
the tile in front of the NPC, sign or obstacle and pressing A, or running the shared script a bg
event runs) and mashes a seeded A/B mix (Start too where a naming screen opens) until the player
has control again. Covers the nurse in a Johto, a Hoenn and a Kanto Center (A and B mashing), the
building PC and Hall of Fame PC, the Pokedex, Trainer Card and PokeNav, the Hoenn, Johto and Kanto
Name Raters, two Move Relearners, the Route 34 Day Care, TV, a scripted wild catch thrown with the
R last-ball shortcut through the Pokedex page, nickname prompt and naming screen, Cut and Rock
Smash in each region, Flash in Dark Cave, Strength twice (the Mt Mortar boulder must then move),
both Safari Zones' last step (pay to continue, and decline back to the gate), and the
Bug-Catching Contest's time limit through judging and the prize. Each case fails on a crash screen,
a stopped vblank counter, no control inside its budget, the wrong map afterwards, or a field
message-box pixel in palette indices 10-15 (the shared half-row colour table leaking from another
window). The log lists the screens (CB2) each case passed through. `PW_ITS_ONLY=<text>` runs the
matching cases. Passed **199/199**. Against a build from before `eed10e7a7d` the contest case
stopped on the `overworld.c` "no object event template for localId 255" assert screen (**8/11** for
that case alone); that defect was fixed on master while this suite was written. No Instant-specific
defect was found.

### `StartOptionsStateStress.lua`

FamilyOptionsFieldStress's field-restore comparison applied to states whose data lives outside the
map header: a DexNav search on Route 29 (the Start menu ends it by design; afterwards no search
window, sprite or palette may remain, and R must start a new search), a fishing chain streak, the
Mach and Acro Bikes (cycling music, avatar flags, riding afterwards), Dark Cave before and after
Flash (the lit width on the middle scanline from `gScanlineEffectRegBuffers`), the Hoenn and Kanto
Safari Zones entered through `EnterSafariMode` (balls, steps, mode, then one step costs one step),
the Bug-Catching Contest entered through the attendant (timer start, timer running, mode) and the
Battle Tower lobby. Each visit moves every Options row and leaves Text Speed and the rates on a new
column. A 400-frame control snapshot with no visit names what changes on its own (the map name
popup, the bike music fading in), and those keys are logged and skipped; BG colours with bit 15 set
are night lights the day/night blend rewrites, and OBJ palettes are compared only for tags loaded
both before and after. `PW_SOS_ONLY=<text>` runs the matching states. Passed **178/178**; it found
no restore defect.

### `FamilyOptionsMigration.lua`

Loads a generated supported save through Continue and verifies option bits, text selection,
wallet, original Pokemon, and location. The canonical run uses the v11 Hard Mode fixture.
`MakeFamilyOptionsFixtures.py --output DIR` generates v7 through v12 cases with the old bit
set and clear. Pass `--env PW_FAMILY_VERSION=7 --env PW_FAMILY_HARD=1` to the focused runner for an additional v7 case, or select the corresponding version and old-bit values. These are
disposable derivatives of the tracked fresh-game fixture, not personal saves.

### `FamilyBattleOptions.lua`

Native controller coverage for issue #383. On an old-Hard-bit save with Instant text, opens
the trainer-battle Bag and uses a Potion, defeats an opponent to compare the actual Shift
and Set flows, and checks free leader-simulation defeat and unchanged simulation-win money
at 2x Money Loss. Confirms the existing leader-simulation forfeit deducts and displays
1,600 instead of the baseline 800. Uses disposable debug-created parties and controlled HP for deterministic
battle transitions. Passed 27/27; this is targeted acceptance, not a natural campaign run.

### `DoubleBattleStress.lua`

Wild and trainer doubles played adversarially from a fresh game. No encounter table in this build
rolls a wild double (`WE_DOUBLE_WILD_CHANCE` 0, no force flag, NPC followers compiled out), so the
suite calls the shipped entry `BattleSetup_StartDoubleWildBattle` through a three-command EWRAM
script (`setwildbattle` with two species, `callnative`, `end`), and the scripted entry through
`dowildbattle`. Trainer doubles come from the debug Trainers menu. Covers seeded every-button
mashing (wild, trainer, with balls, with an Egg), one usable Pokemon with Eggs or fainted members,
an Egg-only party refusing both wild-double entries, catching with both targets up, with one down
on either side, by the right-hand Pokemon, with one ball, with a Master Ball, with a full party and
full PC, into the PC, and with the swap-into-party prompt, the R shortcut after its display fell
back, the Bag from both battlers (with and without items), a Potion refunded by cancel-partner,
both player Pokemon fainting in one turn, running (the right-hand Pokemon is
refused and B cancels back), the instant B run shortcut, whiting out, and a trainer double that
faints down to one with voluntary and forced switches (B refused on the forced menu), then levels
up (summary box) and evolves while the end is mashed; the same level-up and evolution on the
right-hand Pokemon with the left slot empty, and a benched four-move Pokemon learning a move
through SHARED EXP. Party, PC and Bag are checked by decoding every slot (checksum, species,
HP, count) and counting personality values. `PW_DBL_ONLY=<text>` runs a subset and
`PW_DBL_TRACE=1` logs every input decision. Two checks discriminate against fixes made with the
suite: the Egg-only scripted refusal failed (script left waiting, controls locked) before the
deferred release in `RefuseScriptedWildBattleIfPartyless`, and "R shortcut after the display fell
back" failed (no throw, display stuck on a ball the Bag no longer held) before
`TryAddLastUsedBallItemSprites` re-pointed the display at the last thrown ball.

### `BugContestFullPC.lua`

The Bug-Catching Contest's judging with every PC box full, which no earlier suite reached: the
other contest suites retire without a catch and take the "didn't catch" branch. Setup fills the
party and the boxes through the debug menu, frees one slot for the attendant's storage check, gives
a Pokemon inside the contest as the catch and refills the freed slot in RAM as a later catch that
landed in the PC. The attendant, retiring at the exit, choosing the kept Pokemon, judging, the
make-room PC (Withdraw, then Move Pokemon and Release) and the walk back to the gate are real
input. Every Pokemon is fingerprinted by its first 30 bytes before entry and after the contest, so
a lost or cloned Pokemon shows up by identity, not only by count. Two checks discriminate against
fixes made with the suite: the judging scene raised `overworld.c` "no object event template for
localId 255" (its `setobjectmovementtype OBJ_EVENT_ID_PLAYER` targets the player, who has no
template) before that line was removed, and a Pokemon withdrawn in the make-room PC was deleted by
the closing `LoadPlayerParty` before `BugContest_EventScript_NeedBoxSpace` restored the parked
party around the PC.

### `BugContestPodium.lua`

The player's kept Pokémon on the judging podium at (20,29). Two contests run back to back, one
with a Weedle and one with a Growlithe (a non-bug, as a DexNav catch would be), each given through
the debug menu inside the contest; the attendant, retiring, choosing the kept Pokémon, judging and
the return to the gate are real input. Each contest checks that the podium object (appended local
id 44, drawn through `VAR_OBJ_GFX_ID_0`) is absent while the contest runs, stands visible at
(20,29) during judging with `OBJ_EVENT_MON` set and the chosen species in its graphics id, is gone
back at the gate, and that no assert screen came up. Measured **20/20** fixed and **16/20**
without the change, where the four failures read "no podium object" for both species: the old
`ShowBugContestChosenMon` returned local ids 22-31 of stand-ins deleted in c85504af39.

### `RegionalSequenceBreaks.lua`

Sequence breaks through the World Transit gate's Center resume. Before Surf, Mr. Briney's boat is
the only way back to Dewford, and a Hub Pass used on Dewford leaves him docked there. The standard
Hoenn arrival already moved him to Route 109, but resuming at a remembered mainland Center
(Slateport, Mauville) skipped that, so a player who had not beaten Brawly could not reach Dewford.
From a fresh game the suite seeds the Stone Badge, Briney's Dewford dock and the remembered Center,
then drives the Hoenn gate's team, arrival and confirm choices and the Hub Pass with real input.
It checks the standard arrival, Slateport and Mauville resumes (Briney moved to Route 109),
Dewford's own Center (Briney stays) and a post-Norman resume (Briney stays, Surf reaches Dewford).
Briney's position is read from the same hide flags and `VAR_BRINEY_LOCATION` the gate writes; the
suite does not walk to Route 109. Measured **16/16** fixed and **14/16** without the
`RegionalTravel_Commit` change, where both failures read `dewford=true/true route109=false/false var=2`.

### `BugContestPrizeBagFull.lua`

The Bug-Catching Contest prize with a full bag. `giveitem` prints nothing when `additem` fails, so
a full Items or Berries pocket dropped the stone or berry without a word. Setup gives a party
through the debug menu, fills both pockets in RAM with non-prize items and gives a Pokemon inside
the contest as the catch. The attendant, retiring, choosing the kept Pokemon, judging and the walk
back to the gate are real input. It checks that a reward-table item reached the item PC, that
`gStringVar4` carried the "sent to your PC" line, and that the full pockets were left alone.
Measured **10/10** fixed and **8/10** without the `bug_contest.inc` change, where the prize is in
neither the bag nor the PC and the PC line never prints. `--env PW_PRIZE_PC_FULL=1` also fills the item PC
as a control: the prize is then forfeited and the suite requires the "Too bad! The BAG is full"
line instead (**9/9** fixed).

### `StorageItemToBagFull.lua`

PC storage, Move Items, "Bag" on a boxed Pokemon's held item while the Items pocket is full. Setup
gives a party and fills the boxes through the debug menu, writes a held Potion onto box 1 slot 1 and
fills the Items pocket in RAM. Opening the PC (debug Access PC), Move Items, the item menu and the
key press are real input. The message window's sprites (`sMessageWindowSpriteIds`, the storage
screen's 6-byte array, picked by size in `GenLuaSymbols.py`) must exist while the message is up and
be gone after a key press. Measured **12/12** fixed and **11/12** without the `Task_ItemToBag`
change, where the sprite is still allocated after the key and the key moved the cursor instead.

### `FollowerPartyReorder.lua`

The Pokemon chosen with the party menu's Follow must keep following when the party reorders.
`followerSlot` is a party index, and a Switch or a PC deposit used to hand the follow to whichever
Pokemon landed in that slot. Setup gives a three-Pokemon party through the debug menu; Follow,
Switch (L), debug Access PC, Deposit and Withdraw are real input, and a warp to the hub respawns
the follower before each read of its graphics id. It checks a Switch of the chosen Pokemon, a
deposit of a Pokemon ahead of it, and that once the chosen Pokemon is boxed the lead follows and a
later withdrawal does not take over. Measured **15/15** fixed and **12/15** without the
`GetFollowerSlot` change; each failure names the Pokemon that followed instead.

### `GateRecallStress.lua`

World Transit gate recall after the remembered team changed, plus input abuse. Every Pokémon has a
distinct personality, and the party, all PC boxes and the Day Care are counted before and after each
step. A Hoenn team leaves with one Egg; in the hub one member evolves, the Egg hatches, one goes to
the Day Care and one is released. The partial recall must carry the four reachable members in
remembered order, the evolved species and the hatched Pokémon, and leave the Day Care member where
it is. A remembered team of only Eggs must be refused in the hub while keep-current still travels.
It then mashes six A/B/Start/Select/D-pad patterns through each of the three gates at Instant text,
holds Select (the registered Hub Pass) through the gate's warp and the Hub Pass's own warp, and
soft resets on 13 frame offsets between the final Yes and the arrival, each of which must Continue
in the hub with the saved party, PC and memories. The reset helper holds the buttons until the game
resets, because the commit's PC scan stalls the main loop for about eight frames. Measured
**121/121**; no defect found.

### `HubPassVesselBreaks.lua`

A Hub Pass used aboard a ship whose story scene finishes on the way off it. On the S.S. Anne after
the captain's Cut, the departure scene must still play, and release the player in Vermilion, when
they return through the gate and walk back down the pier from the town side. Mid maiden voyage on
the S.S. Aqua, the Olivine sailor must offer the voyage again from state 1 and the restarted voyage
must reach Vermilion. Measured **28/28**; no defect found.

### `NortheastHoennResume.lua`

Fortree and Lilycove sit north and east of Route 118's river, and every land route off that block
crosses it, so leaving needs Surf or Fly. The gate offered both Centers as resume points to a party
that could do neither. The suite drives the real gate with a carried Caterpie, Squirtle with Surf
and Charizard with Fly, before and after the Feather Badge. Measured **17/17** fixed and **13/17**
on the unfixed ROM, where the four failures land the Caterpie or the badgeless Charizard in the
Fortree (`12/2`) or Lilycove (`13/6`) Center instead of Slateport Harbor.
The champion case adds a Caterpie after all eight badges. Lilycove Harbor sails a Hoenn champion to
Slateport, which the suite proves by boarding the S.S. Tidal, so the gate must resume a champion at
Lilycove. Measured **22/22** fixed and **21/22** without the `LILYCOVE` rule, where the champion
lands at Slateport Harbor (`9/9`).

### `BrineyRespawnShore.lua`

Before Surf, Mr. Briney's boat is the only link between the west mainland, Dewford and Route 109. A
whiteout or Teleport moves him to `VAR_BRINEY_LOCATION`, which each Center visit records, but the
gate sets the respawn without one. The suite drives the standard Hoenn arrival, a Teleport from
Dewford with Abra and a Petalburg Center resume, each with Briney docked at Dewford, and reads his
hide flags and the variable. Measured **12/12** fixed and **8/12** unfixed: the Teleport lands in
Littleroot with Briney at Route 109 (`docked=route109 var=3`), and the Petalburg resume docks him at
Route 109 across the uncut Rusturf Tunnel.

### `RegionalRecallMail.lua`

Gate recall with held Mail and a chosen follower. A kept member and a deposited stranger both hold
Mail; the suite chooses Follow on the kept member and moves it with a party-menu Switch right before
the gate, then checks the recalled party, both messages byte for byte, the mailbox, the follower
index and a save and Continue. It also refuses a full-PC and a full-mailbox recall and checks no
Mail record changed. Measured **24/24** before and after the travel fixes. A tamper build that drops
the mailbox copy and the follower remap scores **21/24**, so the checks bite.

### `BrineyEastArrival.lua`

Before Surf, Slateport is cut off from the west mainland until Rusturf Tunnel opens, which takes Rock
Smash and Wattson's badge. Mr. Briney's boat is the only other way. The suite crosses the Hoenn gate
four times with Roxanne's badge: the standard arrival before his first voyage, the standard arrival
and a Slateport Center resume after Slateport is reached with Briney at his house, and the standard
arrival after a Dewford visit but before Slateport. It reads the landing map, his hide flags and
`VAR_BRINEY_LOCATION`. Measured **18/18** fixed and **12/18** unfixed: the first arrival lands at
Slateport Harbor with Briney at his house, both later east arrivals leave him there
(`docked=house var=1`), and the Dewford case lands at the harbor too.

### `JohtoGoldenrodArrival.lua`

Goldenrod station sits north of Ilex Forest's Cut tree and east of Route 36's Sudowoodo. The
standard Johto arrival used to land there after Falkner alone, before the player could walk back
to Azalea: Cut needs the Hive Badge and the Ilex gift, Sudowoodo needs the Plain Badge. The suite
drives the real gate after Falkner only, after Bugsy with Ilex unfinished, with Farfetch'd home
but no Cut gift, after the Cut gift, and with Whitney's badge. Measured **11/11** fixed and
**8/11** on the unfixed ROM, where the first three land at Goldenrod station (`84/23`) instead
of New Bark (`76/4`).

### `SSAnnePierHeal.lua`

A party at 1 HP walks the Vermilion ticket check and pier, boards the S.S. Anne, Hub Passes off
the ship, returns through the Kanto gate and walks the pier into the departure scene. HP stays
at 1 after every step. The only heal on this route is the opt-in woman in 1F Room 6, inherited
from FRLG. Measured **15/15**; no defect found.
### `HubPassEliteFour.lua`

The Hub Pass used mid Elite Four run. Each region's rooms reopen their exits on load when the
previous member is already beaten, and Hoenn and Kanto clear that progress only on whiteout or the
Hall of Fame (Johto's reset in the Indigo Plateau Center is bypassed by the outdoor E4 door). The
suite debug-warps into Phoebe's, Kanto Bruno's and Koga's rooms with the previous member beaten and
presses Select with the Hub Pass registered. Each room must refuse it and keep the player there;
the League lobby must still allow it. Measured **12/12** fixed and **6/12** on the unfixed ROM,
where all three rooms warped to the hub with the beaten flag or League state intact.

### `PayDayMoneyText.lua`

Pay Day's "picked up" line against the wallet delta. A level 100 Meowth holding an Amulet Coin uses
Pay Day on a level 2 wild Pidgey with the u16 pot seeded to 40000 after battle start, so the
doubled payout is 81000. Measured **7/7** fixed and **6/7** on the unfixed ROM, which printed
15464 (81000 truncated to 16 bits) while paying 81000.
