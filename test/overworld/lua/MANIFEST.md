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
| `XRegionDamageFixtures.lua` | Fixture producer for the two `XRegionSaveRepair` suites. Runs only on a pre-fix build, from that build's tree (`manual`). |

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
| [`JohtoNightLights.lua`](#johtonightlightslua) | fresh new game | Johto street lamps, the Olivine beacon and Whirl Islands glow lichen draw their own lights, not Poke Mart signs. |
| [`OlivineHarborBoard.lua`](#olivineharborboardlua) | fresh new game | The OLIVINE board's BATTLE FRONTIER row now demands the S.S. TICKET. |
| [`OlivineSeaBorder.lua`](#olivineseaborderlua) | fresh new game | Olivine's south-west and south-east sea corners, which no connection covers, draw sea rather than the old forest border, including after swimming in from Route 40. |
| [`JohtoSealedSea.lua`](#johtosealedsealua) | fresh new game | The uncovered sea corners of Cherrygrove, Route 26 and Route 34 stay off screen: the rocks and fences that seal them block real input, and no reachable view holds an undefined cell. |
| [`SSAquaKantoCrossing.lua`](#ssaquakantocrossinglua) | fresh new game | The S.S. Aqua Kanto crossing in both directions, plus the persisted ferry departure record. |
| [`BnetTerminal1F.lua`](#bnetterminal1flua) | fresh new game | The Battle Net wall terminal on one map per placement row, and the BP payout invariants. |
| [`LevelUpSummary.lua`](#levelupsummarylua) | fresh new game | The post-battle "Your team grew stronger!" box, which `make check` cannot reach by construction. |
| [`EvolutionMashStress.lua`](#evolutionmashstresslua) | fresh new game | Every evolution path (after battle, cancel, forget-move prompt, Shedinja, chains, whiteout, stone, Rare Candy, soft reset) mashed without a crash, strand or corrupt party. |
| [`EconomyStress.lua`](#economystresslua) | fresh new game | The wallet at 0 and at the cap: mart buys and sells at their edges, buy-list mashing, trainer prizes, whiteouts at every Money Loss rate, and the Game Corner coin desk. |
| [`DoorAnimsRegistered.lua`](#dooranimsregisteredlua) | fresh new game | Animated doors really resolve a `sDoorAnimGraphicsTable` row on the seventeen maps whose tilesets borrow another tileset's door metatile. |
| [`JohtoVictoryRoadTiles.lua`](#johtovictoryroadtileslua) | fresh new game | The three Johto Victory Road floors draw as a cave, not as a secret base, after the `layout_version` retag. |
| [`JohtoTilesetArt.lua`](#johtotilesetartlua) | fresh new game | The Johto League rooms, Hall of Fame and Cianwood shop draw pokemonHnS's art, not the same-named FRLG or Emerald tileset's. |
| [`JohtoHeadbuttTutor.lua`](#johtoheadbutttutorlua) | fresh new game | The Ilex Forest Headbutt tutor can teach Headbutt (his menu marked every Pokemon NOT ABLE) and sets `FLAG_GET_HEADBUTT`. |
| [`JohtoGiftReceipts.lua`](#johtogiftreceiptslua) | fresh new game | Bill's Eevee, Kirk's Shuckie, Randy's Kenya, the Karate King's Tyrogue and both Dragon's Den Dratini print "received", and a gift a full party sends to a box says which PC. |
| [`AlphFossilLab.lua`](#alphfossillablua) | fresh new game | The Ruins of Alph lab and Devon's lab revive fossils on separate machines; a pre-split save's pending Johto fossil still comes back at Alph. |
| [`JohtoPlaceNames.lua`](#johtoplacenameslua) | fresh new game | Goldenrod's coin clerk, the Johto Safari Zone's welcome attendant and Victory Road's Owen name Johto places, not Mauville, Hoenn and Petalburg. |
| [`GoldenrodPrizeClerk.lua`](#goldenrodprizeclerklua) | fresh new game | Goldenrod's Pokemon prize clerk: her own no-Coin-Case line, refusals at 0 and 119 coins, Abra at exactly 120, no charge for a NO, and a full-party Dratini to box 1 with the PC notice. |
| [`AlphSlidingPuzzles.lua`](#alphslidingpuzzleslua) | fresh new game | All four Ruins of Alph sliding puzzles solved with real input: quit-and-retry, the floor drop to B1F, each reward picked up, and the Kabuto sensor and reward-room door. |
| [`JohtoHeadbuttTrees.lua`](#johtoheadbutttreeslua) | fresh new game | A Johto tree answers A: the small-tree refusal without the Headbutt flag or a Pokemon that could know Headbutt, then "used Headbutt!" and a wild battle from the map's Headbutt table. |
| [`JohtoViridianIndigoTiles.lua`](#johtoviridianindigotileslua) | fresh new game | Route 28, Route 26 North and the Johto Indigo Plateau draw pokemonHnS's art, and their window glass is blue by day and amber at night. |
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
| [`AmbientWanderBlockers.lua`](#ambientwanderblockerslua) | fresh new game | Wandering Pokemon in Ecruteak, Blackthorn, Mt. Silver and Route 26 never stand on a door, its approach tile or the Burned Tower stair corridor. |
| [`JohtoHofLegendaries.lua`](#johtohoflegendarieslua) | fresh new game | Johto HOF rematch does not re-arm already-caught Mew/Deoxys. |
| [`JohtoMusicPass.lua`](#johtomusicpasslua) | fresh new game | Johto outdoor maps, cycling, and Radio Tower occupation play MUS_HG_*. |
| [`JohtoWhirlpool.lua`](#johtowhirlpoollua) | fresh new game | Whirlpool without the Glacier Badge refuses; with it, the slide walks over the blockers. |
| [`JohtoWhiteoutHeal.lua`](#johtowhiteoutheallua) | fresh new game | Johto whiteout lands on the Violet apron, Center heals store aprons, FRLG monitor. |
| [`KenyaMail.lua`](#kenyamaillua) | fresh new game | Randy's Kenya gift carries RetroMail; Route 31 sleeper removes her; TM41 bag-full is first. |
| [`FamilyOptions.lua`](#familyoptionslua) | fresh new game | Four choices on every rate control and Text Speed, staged writes, reopen, real save/Continue, and global regional travel. |
| [`FamilyOptionsFieldStress.lua`](#familyoptionsfieldstresslua) | fresh new game | Options from the main menu (before New Game and Continue) and from the Start menu with a follower, a Repel, rain and Surf, restoring the field each time. |
| [`InstantTextStress.lua`](#instanttextstresslua) | fresh new game | Instant text mashed through nurses in all three regions, building PCs, the Pokedex, Trainer Card, PokeNav, Name Raters, Move Relearners, a Day Care, TV, a catch with nickname, Cut, Rock Smash, Strength and Flash, Safari Zone time's up and Bug-Catching Contest judging. |
| [`StartOptionsStateStress.lua`](#startoptionsstatestresslua) | fresh new game | Start-menu Options during a DexNav search, in a Flash-dark cave before and after Flash, on both bikes, mid fishing chain, in both Safari Zones, in the Bug-Catching Contest and a Frontier lobby, restoring each state. |
| [`ContinueOddMoments.lua`](#continueoddmomentslua) | fresh new game | Save then Continue (soft reset or power cut) while surfing with a follower, underwater, next to a visible wild Pokemon, aboard the S.S. Anne and S.S. Aqua, and in the hub after a Hub Pass fired from Surf: same map, tile, party, region, whiteout point and avatar state, and control returns. |
| [`FamilyOptionsMigration.lua`](#familyoptionsmigrationlua) | generated v11 Hard Mode fixture | Continue initializes only new rate bits and preserves preferences, money, Pokemon, and location. |
| [`PromptSafetyEvIv.lua`](#promptsafetyevivlua) | fresh new game | Intro skips difficulty selection; outfit B stays on the picker; EV/IV START flips page. |
| [`RedGyarados.lua`](#redgyaradoslua) | fresh new game | Lake of Rage Red Gyarados is MON\|SHINY\|GYARADOS in the overworld and in battle. |
| [`Route41SeaReturn.lua`](#route41seareturnlua) | fresh new game | The Route 40/41 strait is two-way: surf north from a Route 41 sea arrival onto Route 40 past its arrow row. |
| [`Route41SurfBgm.lua`](#route41surfbgmlua) | fresh new game | FldEff_UseSurf on Route 41 plays MUS_HG_SURF, not Hoenn MUS_SURF. |
| [`Route41SurfArrival.lua`](#route41surfarrivallua) | fresh new game | Each Route 41 sea arrival starts the player surfing on its tile, and the player can surf south from it. |
| [`LanceMultiBattle.lua`](#lancemultibattlelua) | fresh new game | The Rocket HQ multi battle starts with four battlers (Ariana, Lance, the Grunt) and its trainer intro does not assert. |
| [`LanceMultiOutcome.lua`](#lancemultioutcomelua) | fresh new game | Lance's Rocket HQ multi battle, reached through Ariana's trigger: a forfeit (Normal and Hard) whites out and re-arms the ambush, a win runs the generator cutscene. |
| [`Route37CrossingProbe.lua`](#route37crossingprobelua) | fresh new game | Walking the Route 36/37 connection both ways with a follower does not crash. |
| [`DayNightCrossingProbe.lua`](#daynightcrossingprobelua) | fresh new game | The Johto day/night flip at every alignment with the Route 36/37 crossing, both ways. |
| [`SlowpokeWellRescue.lua`](#slowpokewellrescuelua) | fresh new game | Slowpoke Well Jessie/James gate, Kurt no longer seals Proton, Rocket walk-out. |
| [`TohjoCelebi.lua`](#tohjocelebilua) | fresh new game | A full-HP Celebi follower arms the Tohjo Falls Giovanni scene. |
| [`ExpansionHealthboxes.lua`](#expansionhealthboxeslua) | fresh new game | Issue #120 A: Safari leftover-ball text (FillSpriteRect left=55), singles nick/HP numbers, doubles healthboxes. |
| [`CatchTutorial.lua`](#catchtutoriallua) | fresh new game | Issue #120 B: Viridian Old Man tutorial does not say WALLY; Petalburg Wally control still does. |
| [`DayNightTint.lua`](#daynighttintlua) | fresh new game | Issue #120 C: day/night palette tint on Hoenn/Kanto/Johto routes, cave control, night fade-in. |
| [`RainPaletteSlots.lua`](#rainpaletteslotslua) | fresh new game | Object palettes loaded mid-rain take exactly the rain colour map, and every slot returns to its unfaded colours when rain stops in place. |
| [`DroughtNightTint.lua`](#droughtnighttintlua) | fresh new game | Drought keeps the day/night tint: Sootopolis's abnormal weather at 22:30 is darker than at 14:30 at every drought stage, and the drought fade-in never outshines the settled night palette. |
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

### `OlivineSeaBorder.lua`

Olivine City (52x72) connects to Route 40 on the left (covering x < 0), Olivine Port Outside below at offset 5 (x 5..36) and Route 39 above, so nothing covers x 0..4 or x >= 37 below the city or x >= 52 beside it, and the camera draws Olivine's own border there. That border was four tree metatiles (inherited unchanged from pokemonHnS), so surfing into either sea corner showed a hard-edged block of forest in open water. Route 40, the port and Route 41 all use deep-sea metatile 0x051 as their border, and Olivine now does too. The suite gives a level-100 Lapras, holds `VAR_REPEL_STEP_COUNT`, and reaches each corner with a debug warp to a coordinate (`sWarpDestination` held at `WARP_ID_NONE` so `SetPlayerCoordsFromWarp` takes its x,y; arriving on water starts Surf), then takes the last steps with real input so the camera draws the corner as it scrolls. **Oracle:** for every uncovered cell on screen (`gBackupMapLayout` holds `MAPGRID_UNDEFINED`), the eight tile entries `DrawMetatile` wrote to `gOverworldTilemapBuffer_Bg1/2/3` (at the slot `MapPosToBgTilemapOffset` derives from `sFieldCameraOffset`) must equal those of an open sea cell on the same screen, meaning a covered cell whose metatile behaviour is `MB_OCEAN_WATER` and whose collision is clear. It also requires the uncovered cells to lie only in the expected corner, which pins the premise that the port connection covers x >= 5. **Three segments.** South-west warp-in at (8,69), walked to (4,71): 30 gap cells. The crossing: from Route 40 (31,39), swim east across the connection to (4,71), then a Bag round trip to force `DrawWholeMapView`. This is how the worldB2 campaign saw a block seven tiles wide: `CameraMove`'s `MoveMapViewToBackup` copies Route 40's view into Olivine's grid, `MAPGRID_UNDEFINED` cells included, so x 5..6 lose the port connection and also draw the border (42 cells). South-east warp-in at (46,68), walked to (46,71): 100 cells. **Discrimination:** unfixed 12/15 (all three draw checks; trees signature `0013.018A.0001.019A...`), fixed 15/15. `ValidateBorderTerrain.py` (`make validate`) is the host-side scan for the same class across every map.

### `JohtoSealedSea.lua`

Cherrygrove City, Route 26 and Route 34 (pokemonHnS layouts) each have sea that runs off an edge no connection covers, so the camera would draw the map's tree or rock border there. Screenshots of forest or rock squares in open sea came from debug warps into that water, which no player can reach: Cherrygrove's west channel sits behind rocks at x 2..7 and its outer bay behind the rock line at y 25; Route 26's south-east bay and bottom rows sit behind two diagonal rock staircases and the rock line at y 74..76, and Route 27's rock line at y 33 seals the sea that leads into them; Route 34's strip at y 0..1 sits behind the fence at x 24 and Goldenrod's harbour wall. `ValidateBorderTerrain.py` floods every map from its warps and reaches the same verdict on the data; this suite checks it on the engine. It gives a level-100 Lapras, holds `VAR_REPEL_STEP_COUNT`, warps to a reachable coordinate and walks or surfs to the reachable cell nearest each corner with real input. **Oracle:** each step past the seal is refused (position unchanged), and no cell on screen (15 columns, 4.5 rows either side, half rows included) holds `MAPGRID_UNDEFINED` before or after the probes, so the border is never drawn where the player can look. Six segments: Cherrygrove west (7,10) and south (8,24), Route 26 bay seam (28,60) and beach seam (15,73), Route 27 rock line (100,32), Route 34 fence (25,0). **Discrimination:** no game data changed, so the suite passes on both sides (27/27). A tamper run that clears the collision of the one rock at Route 26 (29,60) at runtime lets the player through: the seal check fails, and at (38,80) the screen holds 117 undefined cells that draw the rock border (1/3).

### `OlivineShockWave.lua`

Olivine City's TM Shock Wave ball (object 21) stood at (48,69), open sea in a pocket (x 31..48, y 67..71) that rock walls seal: x 29..30 on the west, row 66 on the north and the port's rocks below. pokemonHnS gives Shock Wave from the Olivine Lighthouse ball and parks this second ball, on the same flag, at (53,47), off the east edge of the 52-wide map; #177 rewired the lighthouse ball to TM Bulk Up, and 74416d2c4d moved this one into the pocket to make Shock Wave obtainable. `ValidateReachability.py` found the pocket unreached: only a Sky Charm landing on the pocket's one mis-tagged sea tile (36,70), metatile 0x050 tagged `MB_NORMAL`, gets in, and the player then walks on the water. The ball now stands at (43,50), the reachable cell nearest the HnS position, at the east end of the lighthouse yard. The suite gives a level-100 Lapras, holds `VAR_REPEL_STEP_COUNT`, and starts each segment with a debug warp to a coordinate (arriving on water starts Surf). **West seam:** surf down the channel beside the pier to (28,69); three presses east into the pocket leave the player at (28,69). **North seam:** surf to (35,65); three presses south leave the player at (35,65). **Collect:** walk from (39,52) up and east to (42,50), face east, press A. **Oracle:** the TM Shock Wave slot count goes from 0 to 1. **Discrimination:** unfixed 9/10 (`tm_shock_wave_picked_up`, slots 0 -> 0), fixed 10/10.

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
for the field confirmation and EV/IV controls. The picker opens with no message before it, so the
driver watches for it on every frame while it advances text, and the run fails if the intro never
offered it. Before that guard an A pressed blind confirmed Original Red two frames after the picker
opened, and the seven outfit checks never ran while the suite still scored 25/25; it now scores
33/33.

### `IcePathDoor.lua`

The Ice Path door on Route 44, warp 0 at (68,12), is entered only from (68,13). A scenery Pidgeotto
(object 24, flag 0) sat on that tile after the July re-pointing of static overworld Pokemon (its upstream
tile, (68,9), is inside the cliff), sealing the only land route to Blackthorn. Arrives by debug warp,
steps back and walks into the door. Found by `test/overworld/johto-playthrough/`.

### `AmbientWanderBlockers.lua`

Ecruteak's Pidgey (object 13) and Vulpix (object 14) wandered a 9x9 box that took in the one-tile
stair corridor to the Burned Tower, (22,15) to (22,18), and the door warp at (22,14); a world campaign
sat below the stairs for 17 plans while the Pidgey stood on the door. `ValidateAmbientBlockers.py`
lists every scriptless moving object that can stand where it cuts the player off from an exit. This
suite watches the four daylight cases with a warp nearby (Ecruteak's pair, Blackthorn's Dratini at
the Ice Path entrance, Mt. Silver's Venusaur at the cave, Route 26's Charmander at house 1) for 15,000
frames each after parking the player with real input, and fails if one stands on a cell the audit
names. Ecruteak then walks up the stairs into the Burned Tower. 14/19 on the unfixed ROM, 19/19 fixed.

### `RedGyarados.lua`

Issue #66: "The Red Gyarados is red". Lake of Rage template + spawned `graphicsId` is
`MON|SHINY|GYARADOS`; then Set Party, start the scripted fight, and read opponent shininess.
Dragon's Den elder Dratini (perfect-quiz shiny) is attempted only if a cheap warp works.

### `Route41SeaReturn.lua`

Route 40's water-arrow row is the way to Cianwood, and Route 41 row 11 / Route 40 row 61 used to be
ocean tiles with the collision bit set, so nothing led back: a Cianwood softlock until Jasmine's badge
unlocked Fly, which itself needs the Secret Potion from Cianwood. Warps to a sea arrival (41,12) and
surfs north through both former walls to Route 40 y<=59. Found by `test/overworld/johto-playthrough/`.

### `Route41SurfArrival.lua`

Issue #289. Warps to Route 41 sea arrivals 4, 8 and 9 through real field initialization, checks the
player starts surfing on the arrival tile, then surfs one tile south. Passed 15/15 at three RTC
values, about 7 s each.

### `LanceMultiBattle.lua`

Starts `MahoganyHideout_B2F_EventScript_DoLanceMultiBattle` from the seam after party selection,
with three seeded party slots and no fake trainer data, then checks the four opening battlers and that
the trainer intro does not assert. `ValidateLanceMultiBattle.py` checks the script host-side. Passed
7/7 at three RTC values, under 11 s each.

### `LanceMultiOutcome.lua`

Reaches Lance's Rocket HQ multi battle the way a player does: B2F at `VAR_MAHOGANY_TOWN_STATE` 12
with the Murkrow gate open, a walk from warp 0 onto Ariana's trigger at (14,18), her and Lance's
lines, and three Pokemon picked on the half-party screen (A, A per slot, Start to confirm). The
battle is driven with real input. A forfeit (RUN, Yes) must white the player out of B2F with the
state still 12 and Ariana hidden again; a second visit does the same at Hard (set after the warp,
since the field load re-syncs `VAR_DIFFICULTY`); a third is fought to a win (opponents assisted to
1 HP) and must run the generator cutscene to state 13 with the player free at (12,17).
`AreMultiPartiesFullTeams` read the Hard trainer entry with no Normal fallback, so at Hard it called
Ariana's half-team battle full-team, and on that path `HandleSpecialTrainerBattleEnd` called it
again after the battle and overwrote the outcome in `VAR_RESULT` with TRUE: the forfeit ran
Ariana's retreat and the generator cutscene. Normal play does not reach Hard before Johto's title
(the hub gate syncs the tier); a debug warp from a Hoenn champion save does. **Discrimination:**
unfixed 11/14 (Hard forfeit at state 13 beside Lance), fixed 18/18.

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

### `DroughtNightTint.lua`

Drought ignored the clock. `ApplyColorMap`'s negative-index branch and `ApplyDroughtColorMapWithBlend` (`src/field_weather.c`) looked drought colours up straight from `gPlttBufferUnfaded`, so at night the drought half of `WEATHER_ABNORMAL` drew Sootopolis at full daylight while the downpour half and every neighbouring route were tinted. State is seeded as the game leaves it after Seafloor Cavern and the legendaries scene (`FLAG_SYS_WEATHER_CTRL`, `FLAG_KYOGRE_ESCAPED_SEAFLOOR_CAVERN`, `VAR_SOOTOPOLIS_CITY_STATE` 2), so Sootopolis's own `ON_TRANSITION` picks the abnormal weather and `Task_DoAbnormalWeather` flips it to drought. Clock lever is `SaveBlock2.localTimeOffset`, as in `DayNightTint.lua`. Within one drought phase it samples map palettes 1..12 and the in-use, non-blend-immune object slots at every drought stage (`gWeather.colorMapIndex` -2..-6) at 22:30 and at 14:30: night must be below 80% of day at every stage (unfixed they are identical). It then confirms a debug warp to Route 126 only once drought is current, samples every frame of `FadeInScreen_Drought`, and requires no fade-in frame to be brighter than the settled night drought. **Discrimination:** unfixed 9/11 (both day/night comparisons); with only `ApplyColorMap` fixed 10/11 (the fade-in check, `fadeMax` 9334 against a settled 5370).
### `UnderfootHiddenItem.lua`

FRLG marks six hidden items underfoot: the Leftovers on both Snorlax spots (Routes 12 and 16), Mr. Fuji's Soothe Bell (Pokemon Tower 7F), Giovanni's Macho Brace (Viridian Gym), the Navel Rock summit's Sacred Ash and Cape Brink's PP Max. Facing one does nothing (`GetInteractedBackgroundEventScript` returns NULL for them); pokefirered's Itemfinder digs one up when the player stands on it (`itemfinder.c` `SetUnderfootHiddenItem`, `EventScript_ItemfinderDigUpUnderfootItem`). This tree runs Emerald's Itemfinder, which spun the player on the spot, printed "The ITEMFINDER's shaking wildly!" and gave nothing, so all six were lost. `Task_StandingOnHiddenItem` now hands an unflagged underfoot item under the player to `EventScript_HiddenItemScript`, the same script facing a normal hidden item runs. The suite warps onto Cape Brink's PP Max cell (16,28), the one with no object standing on it, gives the Itemfinder with an injected `additem`, registers it on Select and presses Select, then advances the messages until control returns. **Oracle:** PP Max (72) is in the bag, the hidden-item flag 0x1011 is set, the player is still on (16,28) and has control. **Discrimination:** unfixed 5/7 (`pp_max_dug_up` slots 0, `hidden_item_flag_set` false), fixed 7/7.

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

[`ScanInputChords.py`](../ScanInputChords.py) `--check` is one of those checks. It lists input
handlers where one button's branch changes state (task func, main callback, fade, destroyed menu or
window, state variable) and a later, non-`else` button read can still run on the same frame, the
shape behind `DexMenuChord.lua`, `EvoMoveLearnChord.lua` and `BagSortChord.lua`. It fails on a
conflict that [`input_chord_allowlist.tsv`](../input_chord_allowlist.tsv) does not name; each row
there records why that site is safe or which PR fixes it. A fixed site's row is reported as stale
rather than failing, so the row can be removed after the fix lands. Reproduce a new site with the
two buttons in one `joypad.set` before allowlisting it.

[`ValidateMapEvents.py`](../ValidateMapEvents.py)'s `CROSS-REGION-STATE` check lists every flag or var
id that scripts of two regions touch with at least one of them writing it: the pattern behind the
shared starter var (#577), Goldenrod clearing Rydel's bike flag (#602), the PokeGear setting Hoenn's
PokeNav flag (#604) and the shared lottery counters (#611). Region comes from each map's
`region_map_section`; a shared script belongs to every region whose maps reach it; names resolve to
ids through the real headers (a host `cc -E`, `HOSTCC` overrides), so aliases count as one id.
Temporary flags and vars, EWRAM special flags and 0x8000 script vars are skipped. Every deliberate
world-wide id is named in `SHARED_STATE_OK` with its reason (one legendary per world, one Bag, the
wall clock, the event-island ferries, and so on), and an entry that stops firing fails as stale. Ids
an open PR fixes sit in `SHARED_STATE_PENDING`, printed as notes and never failed; delete each once
its fix is on master.

[`ValidateConfigRules.py`](../ValidateConfigRules.py) pairs each `include/config` toggle that
diverges from a source game with the script and text shapes that assume the old rule: TMs called
single-use or a "learned only once" prompt with its flag compiled out (`I_REUSABLE_TMS`), a sellable
fossil taken without `checkitem` (`I_KEY_FOSSILS`), badge stat boosts (`B_BADGE_BOOST`), obedience
levels against `GetAttackerObedienceForAction`, field-poison damage (`OW_POISON_DAMAGE`), unforgettable
HM moves (`P_CAN_FORGET_HIDDEN_MOVE`), a field move that must be known (`QOL_FIELD_MOVES_NO_TEACH`),
Gen 1-3 evolutions with no route that works without a link cable, and NPC claims about evolution
levels and held items against the species table. A rule runs only while its toggle still diverges.
`--list` prints the audited toggles and the ones checked and cleared.

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

`Route37CrossingProbe` and `DayNightCrossingProbe` run in the full profile. Each takes about
5 to 17 s and passed at six RTC values (00:00 to 23:00 local) after their follower was raised to
level 100. At level 10 both failed at RTC `1704150000`: a night wild battle on Route 37 knocked
out the follower, and the whiteout warped the player to Petalburg before the crossing.
`OwnerSaveLeakProbe` and `SustainedWalkLeakProbe` stay `manual`. The first needs one specific
save (`bak-prev8.sav`, standing in Ruins of Alph, group 79). That file is no longer on disk, and
any other save fails its boot check (`BOOT FAIL grp=75 want=79` with the current owner save). The
second passes 6/6 but takes about 130 s, and the hypothesis it was written for is closed. They
are kept because the Route 37 crash is still open and each one closes a hypothesis with a
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
where all three rooms warped to the hub with the beaten flag or League state intact. The same check runs in
Hoenn's four corridors between rooms (Hall 1 to Hall 4), entered with the members before each one
beaten: they are indoor maps with no escape either. Leaving from a corridor kept the beaten flags
and `VAR_ELITE_4_STATE`, and on the way back in Sidney's room `ON_LOAD` shuts the entry door on
the arrival tile, so the player stood boxed in at (6,13) with no move in any direction and the
Hub Pass refused in that room (measured with a debug warp in with all four beaten and state 4). Measured **24/24** fixed and
**16/24** before the corridors joined the refusal list, where all four halls warped to the hub.

### `PayDayMoneyText.lua`

Pay Day's "picked up" line against the wallet delta. A level 100 Meowth holding an Amulet Coin uses
Pay Day on a level 2 wild Pidgey with the u16 pot seeded to 40000 after battle start, so the
doubled payout is 81000. Measured **7/7** fixed and **6/7** on the unfixed ROM, which printed
15464 (81000 truncated to 16 bits) while paying 81000.

### `HiddenCoinsCase.lua`

Hidden coins on the Celadon Game Corner floor against a nearly full Coin Case. The Coin Case comes
from the real restaurant NPC, whose `giveitem` leaves `VAR_0x8006` at 718; only the coin balance is
seeded. Ten coins into 9,300 must land (9,310), twenty into 9,979 must fill the case exactly, ten
into 9,995 are refused with nothing lost, the refused spot still pays out once the case has room,
and a collected spot stays empty. Measured **20/20** fixed and **18/20** on the unfixed ROM, where
`CheckAddCoins` added `VAR_0x8006` instead of the found amount in `VAR_0x8009` and refused both
pickups as a full case.
### `ElmLabFullParty.lua`

Elm's starter when the party already holds Pokemon. The first Johto crossing boxes the team, but
the Hub Pass and the same-region Johto gate keep a team withdrawn at the hub PC, so the player can
reach Elm's balls with a full party. The suite crosses, Hub Passes back, restores the team in
memory as the hub PC would, crosses again and plays Elm's introduction and the ball picks. The
starter must go to the PC exactly once, count as the Johto starter, and leave no second ball to
take. Measured **17/17** fixed and **15/17** on the unfixed ROM, where Chikorita went to the PC
behind a "no more room" line with the starter flag unset, and Cyndaquil could then be taken too.
`--env PW_ELM_PARTY=5` runs a partial party and types one letter at the nickname prompt: **19/19**
fixed, **18/19** unfixed, where the name went to the party's lead instead of the starter.
With the full party the suite then fills every box through the debug menu and picks Chikorita: with
nowhere to put a Pokemon the pick must be refused, nothing given, no starter recorded and the ball
left on the table (`FLAG_HIDE_CHIKORITABALL` clear and the object drawn). One boxed Pokemon is then
released in memory and the rest of the run picks the same ball. Measured **15/16** on the unfixed
ROM, where `removeobject VAR_LAST_TALKED` ran before `givemon` failed and the ball was gone for good.

### `OaksLabFullParty.lua`

Oak's starter when a Johto champion sails the S.S. Aqua to Vermilion with a full party, then keeps it
through the Hub Pass and the same-region Kanto gate. Before the first pick the suite fills every box
through the debug menu: the Bulbasaur pick must be refused, nothing given, the choice left open
(`VAR_MAP_SCENE_PALLET_TOWN_PROFESSOR_OAKS_LAB` still 2) and the ball left on the table
(`FLAG_HIDE_BULBASAUR_BALL` clear and the object drawn). One boxed Pokemon is then released in memory
and the same ball must give exactly one starter, to the PC. Measured **24/25** on the unfixed ROM,
where the ball was hidden before `givemon` reported `MON_CANT_GIVE`.
### `PikeRoomSave.lua`

A Start-menu save inside a Battle Pike room. The challenge carries the three chosen Pokémon while
the other three wait in SaveBlock1's party copy, which a normal save overwrites. The suite gives six
Pokémon, takes the real Lv. 50 challenge (party screen, save before entering), tries Save in the
three-path room, then cuts the power and continues. Measured **10/10** fixed and **8/10** on the
unfixed ROM, where Save is offered and Continue resumes in the room (`26/36`) with three Pokémon
and the other three gone from the party and the PC.

It also holds the Pike menu to the vanilla one's missing Bag. The lead enters holding Leftovers
with one Potion in the bag, the suite tries Bag > Give of the Potion to the lead in the room, then
ends the challenge the way a lost battle does (challenge status `LOST`, warp to the lobby, whose
script reloads the saved party and restores held items). Measured **15/15** fixed and **12/15**
with Save hidden but the Bag still offered: the lead comes back holding Leftovers while the
swapped-out Leftovers stays in the bag (two) and the Potion is gone.

### `TowerMultiRoomMenu.lua`

The Battle Tower multi partner room's Start menu against the vanilla one (no Save, no Bag). The
challenge carries the two chosen Pokémon while the other four wait in SaveBlock1's party copy. The
suite gives six Pokémon, takes the real Lv. 50 multi challenge, rides to the partner room, tries
Save and looks for the Bag, quits at the room attendant, then cuts the power and continues.
Measured **13/13** fixed. An earlier cut of the suite (same flow, plus a Bag > Give) scored
**12/16** on the unfixed ROM: Save and Bag offered, the lobby handed back two Pokémon, and four
were gone from the party and the PC after Continue. The Give itself did no harm there, because
the room's `pyramid_resetparty` on resume writes the live challenge Pokémon back into the copy.
### `LedgeSelectStress.lua`

Start, and Select with each field item registered, pressed once on every frame offset of a ledge
jump (Route 102, 25 offsets) and of walking into a door (Petalburg's west house, 24 offsets from
before the door opens through the fade). Items: Mach Bike, Acro Bike, Hub Pass (prompt declined
with B) and Sky Charm. Every run must return control with no script running, leave the player
object on the saved tile, and end on the north tile, the south tile, outside on the approach or
inside on the house entry. A run that ends on the ledge row on foot fails; a flight may hover over
the ledge or the door only when it took off before the move began. When the key stopped the jump,
a second jump must still land. Measured **864/864** on the build of
`061127921d`; no defect found.
### `SkyCharmLanding.lua`

`StartOverworldFlight` sets the player to `ELEVATION_TRANSITION` so `CanLandOverworldFlight` accepts ground at any height, and landing left it there. That elevation matches every tile, so the first step off a shore went onto the water on foot, the water's elevation then stuck, and the player walked across the sea without Surf. Landing now takes the tile's elevation, and `CanLandOverworldFlight` refuses transition (0), surf-level (1) and bridge (15) tiles, which give no ground level; Olivine's (36,70) is metatile 0x050, a sea tile tagged `MB_NORMAL` at elevation 1. The suite works in Olivine City with Johto badge 6 set and the Sky Charm given by an injected `additem` and registered on Select. **Shore:** take off on the pier at (19,66), fly north one tile, land on (19,65), step west. **Sea tile:** fly to (36,70) and press Select. **Yard (control):** fly to the lighthouse yard (39,52), land, step north. **Oracle:** the step west leaves the player on (19,65); at (36,70) the player is still flying; the yard landing and the step north on land both work. **Discrimination:** unfixed 8/10 (the player walks onto the sea at (18,65), and lands on (36,70)), fixed 10/10. `LedgeSelectStress` (864/864), `AutosaveStress` (220/220) and `RegionalTravelBoundaries` (103/103) pass on the fixed build.

### `SafariStress.lua`

Every way out of the Kanto, Johto and Hoenn Safari Zones, through the real attendants and exits.
Setup gives one Pokemon, a Pokeblock case and the wallet; the step that ends the clock, the
pay-to-continue prompt, a real wild battle down to the last ball, the walk back through the
entrance and the start menu's RETIRE are real input. The clock and ball count are lowered in RAM
to one left. Each zone checks paying 500 (30 balls and the region's 600 or 500 steps again),
declining, 499 in the wallet, leaving early and staying, RETIRE declined then accepted, and (Kanto
and Hoenn) the last ball thrown in battle, which misses in Kanto and catches in Hoenn on the pinned
clock. Every exit must land in the entrance with Safari mode and the Kanto exit scene cleared and
the field free. Declining RETIRE reopens the start menu from inside the prompt script, and the
script's end then unlocked the field under it: the player could walk with the menu drawn, Start
stacked a second menu, and the next RETIRE hung with no message box. Measured **130/130** fixed
and **37/52** on the unfixed ROM, which hangs at the Kanto RETIRE and fails every later warp.
`--env PW_SAFARI_ONLY=<zone_scenario>` runs matching scenarios (`kanto_retire`, `hoenn_balls`).

### `BugContestEggOnly.lua`

The Bug-Catching Contest with an Egg as the only party member, the state a Hub gate leaves when a
gift Egg follows the boxed party. The Egg comes from the debug Give Egg (`ScriptGiveEgg`, the call
gift scripts use); talking to the Route 35 and Route 36 gate attendants is real input. Each must
refuse with "can't battle", hand out no contest balls and leave the Egg and the field alone. The
one-Pokemon branch skipped the `remove5mons` lead check, so the Egg went in with 30 balls to a
contest where every wild battle is refused. Measured **12/12** fixed and **4/7** on the unfixed
ROM, which entered the contest at the Route 35 attendant. `--env PW_EGG_GATE=east` runs only the
Route 36 attendant: **7/7** fixed, **5/7** unfixed.

### `StartMenuSpriteLoad.lua`

The Start menu wheel opened on a crowded rainy route. Rain keeps 24 sprites alive, every object
event carries a shadow sprite, and visible wild Pokemon, the follower, footprints and reflections
add more; the wheel then needs six icons and two arrows. A level 100 Lapras follower runs along
Route 40's beach with the encounter spawn countdown zeroed until the field holds 58 sprites, then
Start is pressed, five times. Each opening must show no crash screen, put the menu up and hand
control back on B, and at least one opening must meet the menu with 57 or more sprites already in
use. Found by `OweSurfLedgeFuzz` (seed 777). Measured **33/33** fixed and **17/18** on the
unfixed ROM, which stopped on the `sprite.c` "Out of sprite slots" assert screen at 58 sprites.

### `OweSurfLedgeFuzz.lua`

`OweStressFuzz` taken onto water, ledges and trainer routes, with one usable Pokemon. The party is
a level 100 Lapras (Surf, Ice Beam) in front of two Eggs. Route 41 is surfed from its Route 40
arrival (water encounters spawn only while surfing), Route 40 is entered on the beach and surfed
from the shallows, and Route 45's ledges are walked; all three have trainers who battle on sight,
so an encounter's approach can overlap a ledge jump, a Surf mount or dismount and a trainer's
approach. The spawn countdown is zeroed before each of 250 seeded actions per map (walk, run,
A presses that accept a Surf prompt, Start, wait). Every action must return to a free field with
no crash screen, and the party must come out as Lapras and the two Togepi (a long run hatches them). The run must also see water
encounters while surfing and at least one Surf mount or dismount. Battles pin the action cursor to
FIGHT (a wrapped Pokemon that keeps choosing RUN is refused forever) and the lead's met level is
lowered to 5 (at met level 100 it disobeys and naps through every battle). `PW_FUZZ_SEED` and
`PW_FUZZ_ACTIONS` reseed and lengthen it (pass them with `--env`). Seed 777 found the Start menu
sprite exhaustion pinned by `StartMenuSpriteLoad`.

### `DoubleKoWhiteout.lua`

Battles that end with both sides down, with one Pokemon in front of two Eggs, at Instant text and
2x Money Loss. A level 50 Electrode's Explosion and a level 50 Misdreavus's Perish Song each knock
out a wild Magikarp and themselves on the same turn through a real `setwildbattle`/`dowildbattle`.
Each must end as a draw (`gBattleOutcome` 3), white out to the field with control back, charge
exactly 800 (8 x level 50, doubled), and leave the party as the same Pokemon, healed, and two Eggs.
A Struggle case empties a Mewtwo's PP mid-battle against a foe left with only Splash and requires
a win with recoil damage. Measured **23/23**; no defect found.

### `DomeRegistrarWalk.lua`

The World Championship registrar must send the player through the singles door the way the singles
attendant does. A party of three level 50 Pokemon is built, the three champion flags are set, and
the singles attendant flow is driven once through Lv50, three entries and the save to record the
reference walk: (5,11) to the door at (5,4), facing north. The registrar is then talked to from
below, left, right and above (it wanders around (8,14)), the offer is accepted, and the same menus
and save are driven. Every tile the player occupies from the save to the warp must match the
reference, end on the door facing north, and never be a tile with collision (other than the door)
or another object's tile. Accepting and then pressing B at the challenge menu must leave the player
on a free tile with control and the championship mode clear. On the unfixed ROM the player walked
five tiles north from beside the registrar, through the counter, and warped from (6..9,6..8).

### `SafariFullStorage.lua`

The Kanto and Hoenn Safari Zones' pay-to-continue prompt with the party and every PC box full.
The entrances refuse a player with no room, since no Safari Ball can be thrown then, but a catch
into the last free box slot fills the storage mid-game. Setup fills the party and the boxes through
the debug menu and frees one slot so the real attendant lets the player in; inside, the slot is
refilled (the storage that catch leaves), the clock is lowered to one step and the times-up prompt
is answered Yes with 5000 in the wallet. The wallet must be untouched and the player must land in
the entrance with Safari mode off and the field free. The unfixed ROM took 500 and refilled 30
balls the player could not throw. Measured **18/18** fixed and **14/18** on the unfixed ROM.
### `RegionMapAnywhereStress.lua`

Opens the Story destination map, the Fly map and the PokeNav map from places the regional maps
were never drawn for: World Transit, Pallet, Cerulean Cave, the Safari Zone, One Island, New Bark,
Ice Path, Littleroot, Granite Cave, the Battle Frontier, Faraway Island and Navel Rock. Each Story
visit first opens the map cleanly for a screenshot of the marker and its details page, then reopens
it with every button mashed through the fades in and out. Each map must return to a settled field
(script idle, Start menu closed) with no crash screen and the heap as it was. Repel stays on so
cave encounters do not interrupt. Measured **48/48**; no defect found. The S.S. Tidal is left out:
a debug warp onto its corridor outside a voyage loops the arrival dialogue, a state play never reaches.

### `OutfitTransitionMash.lua`

Mashes every button at the World Transit wardrobe for eight rounds of 1200 frames with a follower
out, so presses land on the wardrobe message, the picker's first frame, Apply, Cancel and the field
reload after it. After each round the field must settle with the picker closed, the committed
outfit must be a valid selection, the follower must still be out and the task and sprite counts
must match the field before the mash. Measured **52/52**; no defect found.

### `FlowerCrownQuestStorage.lua`

Drives the Celadon florist's real quest (florist, both residents, florist) with a full party. The
Flower Crown Eevee must land in the first free PC slot and set its collection mark, a repeat gift
must take the next slot without touching the first, and both must survive a save and Continue
byte for byte with the party and flags intact. Measured **13/13**; no defect found.
### `ContinueOddMoments.lua`

Each case saves from the Start menu, then soft resets (A+B+Start+Select) or cuts the power, continues
the file, and compares the map, tile, party bytes, saved region, whiteout point and Surf/Dive avatar
bits against the snapshot taken before the save, then waits for control. Cases: surfing on Route 41
with a Lapras follower (soft and power), underwater on Route 124, next to a visible wild Pokemon on
Route 29 (after Continue the player walks into it, and the battle must start and return to the
field), aboard the S.S. Anne and the S.S. Aqua, and the Hub Pass fired from Select while surfing
(the hub arrival must be on foot) followed by a hub save. The debug warp lands underwater on a
walled tile, so that case checks state and control, not a step. `PW_CONT_ONLY=<text>` runs the
matching cases. Measured clean on its first runs; no defect found.

### `InputSpamStress.lua` transition scenarios

Added to the mash battery: the real Fly map with every Hoenn town visited (no B, so the mash
must pick a town and fly), an Escape Rope used from the Bag in Granite Cave, Dig and Teleport from
a lead Abra's party menu (Dig in Granite Cave, Teleport in Petalburg), the Hub Pass registered to
Select and mashed through its Yes/No, and a lost trainer battle mashed through the whiteout and the
respawn. Fly and Dig assert the mash actually left the map. Measured clean; no defect found.

Persona and clock knobs (stress pass 5): `PW_SPAM_GENDER=1` plays as the girl, `PW_SPAM_OUTFIT=<n>`
sets `VAR_PLAYER_PALETTE`, and `PW_SPAM_TEXT=<0..3>` mashes at that text speed (backing out stays
at Instant); each takes effect from the first warp. Ten runs with new seeds crossed them with the
runner's `--rtc` at 23:58:30 (the midnight rollover), 02:30, 12:00 and 19:59: the girl with
outfits 4, 13 and 19, outfits 10 and 22, and Slow, Mid and Fast text. No run crashed or stranded
the field. Six scored 88/88. Four missed goal checks that depend on the seed (the Fly map, Dig or
Hub Pass mash closed the screen before using it); one of them, a Mid-text run at midnight, also
left the Tate and Liza double battle running past the recovery budget: the recovery's Run cannot
forfeit a battle the mash failed to win, and the state cycled through the party menu and action
menu without hanging (replayed from the kept savestate).

Tag battle and whiteout (stress pass 6). With per-scenario seeds two scenarios failed on chance,
not on the game. The tag battle started Lance's Rocket HQ battle script straight after a debug warp,
so the player stood at warp 0 instead of where Ariana's trigger leaves them; a won battle's cutscene
then walked the player by fixed steps to (-1,17), off the map, where no direction is walkable. The
debug warp also kept the Hoenn champion's Hard tier. The scenario now sets B2F as the Murkrow gate
scene leaves it, restores Johto's Normal tier, walks onto Ariana's trigger, advances the lines,
picks the first three Pokemon that can battle on the half-party screen, and mashes from there
through the battle and whichever ending follows. The whiteout scenario's lead could still win when
a mash committed a move, or the mash spent all 15,000 frames in the Bag, party and summary screens;
the lead's attacking stats are now held at 1, and after 8,000 frames without a defeat the battle
keys back out and forfeit. Both scenarios now pass on the integ2 and integ3 builds at the default
base and at `PW_SPAM_BASE` 1 to 4.
### `OakPokeBallsFullPocket.lua`

Oak's five POKé BALLS when the 16-slot POKé BALLS pocket is full. A player who starts Kanto after
Johto and Hoenn can already hold 16 other ball types (12 from the Hub clerk, 7 from Kurt), and the
POKéDEX scene used `giveitem_msg`, which has no space check. It printed "received five POKé BALLS"
and the bag stayed unchanged. Setup boots a new game, crosses the Kanto gate and plays Oak's
starter scene with real input, writes what `EndRivalBattle` writes instead of fighting the rival,
and lets the Viridian clerk's real scene hand over the PARCEL. The pocket is then filled in RAM
with 16 real ball ids, none a POKé BALL. Delivering the PARCEL and three more talks to Oak use real
input. It checks that the scene still ends (lab scene 6, POKéDEX received), that `gStringVar4`
carried Oak's "no room for these" line instead of "received five", that Oak keeps them while the
pocket is full, gives exactly five once a slot is free, and gives them only once. Measured
**24/24** fixed and **18/24** without the `PalletTown_ProfessorOaksLab_Frlg` change, where the
scene prints "received five POKé BALLS" with no POKé BALL in the bag and no later talk gives any.
### `BagRareCandyMoves.lua`

A Rare Candy used from the Bag must offer every move the new level teaches. Bulbasaur learns
Poison Powder and Sleep Powder at level 15, and the Bag runs its own candy flow
(`BagMenu_RareCandyDoLearnMoveStep`, `src/swsh_item_menu.c`). Four cases give a real Bulbasaur
through the debug Give menu and use candies from the Bag with real input while recording every
`gMoveToLearn` the game offers: one candy with two free move slots (both powders learned), one
candy with four moves and every prompt accepted (both offered, in order), one candy with every
prompt cancelled with B (both offered, old moveset untouched), and three candies from level 13
that cross 15 and evolve into Ivysaur at 16 (both learned, three candies spent). Before the fix
the step moved to the next level after any learned move, so Sleep Powder was never offered:
**16/22** on the unfixed ROM, **22/22** with the fix.
### `BagGiveOverMail.lua`

Giving an item from the Bag to a Pokemon that holds Mail must be refused, as the party menu's
Give refuses it. A Bulbasaur is handed Orange Mail the way `GiveMailToMonByItemId` leaves it
(letter in mailbox slot 0, held item, mail index), then the Bag, Give, the party select and the
switch prompt run with real input: a Potion onto the Mail holder must leave the Mail, the letter
and its link in place and the Potion in the Bag; a Potion onto an Oran Berry holder (control)
must switch the items. Before the fix `BagMenu_GiveItem` switched the Mail into the Bag without
`TakeMailFromMon`, orphaning the letter and its mailbox slot: **5/8** on the unfixed ROM,
**8/8** with the fix.
### `BagCheckMail.lua`

Checking a Mail item from the Bag must open the blank letter and come back without a crash. Each
case puts one Mail (Orange, Harbor, Bead, Dream, Retro) in the Items pocket, opens the Bag with
real input, picks Check, holds the letter open, closes it with B, and requires no crash screen
throughout, the Bag back with the Mail still in it, and the field back. Before the fix
`CB2_CheckMail` handed `ReadMail` a pointer to a stack `struct Mail` that the screen read on later
frames, and the icon step asserted on a garbage species (`pokemon.c:6551: disabled species: 768`)
for every Mail: **10/20** on the unfixed ROM, **15/15** with the fix (the recovery checks only run
after a failure).
### `BagFluteReusable.lua`

A Blue Flute used from the Bag on a sleeping Pokemon must wake it and stay in the Bag, as the
vanilla and SwSh party menus keep the reusable flutes (`IsItemFlute`). A Bulbasaur from the debug
Give menu is put to sleep, then the Bag, Use, the party select and the message run with real
input: the Blue Flute must clear the sleep and leave one flute in the Bag; an Awakening (control)
must clear the sleep and be used up. Before the fix `BagMenu_UseMedicine` removed every medicine it
used, flutes included: **5/6** on the unfixed ROM, **6/6** with the fix.
### `PartyGiveSwitchDecline.lua`

Declining the party menu's "switch the two items?" prompt must leave the Bag and the held item
alone. A Bulbasaur from the debug Give menu holds an Oran Berry and the Items pocket holds one
Potion; then the party menu, Item, Give, the Bag pick and the prompt run with real input. Answering
No must leave one Potion in the Bag and the Oran Berry held; answering Yes (control) must switch
them. Before the fix the SwSh No branch called `AddBagItem` for an item the prompt had never
removed, so every decline added a copy: **7/8** on the unfixed ROM, **8/8** with the fix.
### `PartyMoveItemOntoMail.lua`

The party menu's Item, Move must refuse a target that holds Mail, as Give does. Two Bulbasaur come
from the debug Give menu; the first holds a Potion, then the party menu, Item, Move and the target
pick run with real input. Onto a Mail holder (letter in mailbox slot 0, linked the way
`GiveMailToMonByItemId` leaves it) nothing may move and the letter must stay linked; onto an Oran
Berry holder (control) the items must switch. Before the fix `CursorCb_MoveItemCallback` swapped
the held items alone, so the first Bulbasaur held the Mail with no mail index (Read showed a blank
letter from `mail[255]`) and the second kept the letter's link while holding the Potion:
**3/5** on the unfixed ROM, **5/5** with the fix.
### `SelectWheelStaleSlot.lua`

SELECT with one usable registered key item must use it, even when an earlier key item wheel slot
names a key item that has left the Bag. At Petalburg City a Mach Bike is added with `additem` and
the wheel slots are written the way `ItemMenu_Register` leaves them; SELECT runs with real input.
With only the Mach Bike registered (control) SELECT must mount it; with Devon Parts (not in the
Bag) in slot 0 and the Mach Bike in slot 1 SELECT must mount it too. Before the fix
`UseRegisteredKeyItemOnField` took the first registered slot, found it missing, cleared it and
showed "An item in the BAG can be registered..." instead: **7/8** on the unfixed ROM, **8/8** with
the fix.
### `BagRepelFlow.lua`

Repels from the Bag and the Repel expiry prompt (`EventScript_SprayWoreOff`, with
`I_REPEL_LURE_MENU`) behave as the item rules say. From a free hub, with real input: a Repel from
the Bag with none active sets 100 steps and uses one; a Repel while one is active lingers and uses
nothing; at expiry with only Repels, Yes uses one and restarts the count; with a Repel and a Max
Repel the menu's second row uses the Max Repel (250 steps); cancelling the menu uses nothing; with
none left only the message shows. Coverage for a flow the third stress pass found clean:
**22/22**.
### `ArtisanCaveDeparture.lua`

Artisan Cave is part of the Battle Frontier island: both entrances open off the Frontier and no
route reaches it from mainland Hoenn. A Hoenn team leaves through the Hub Pass, another team
boards the hub's Frontier attendant, and the suite debug-warps onto the beach below the cave's
west entrance (reached by Surf), walks in and uses the Hub Pass from the cave. The Frontier
outdoors (control) and the cave must both leave Hoenn's remembered team alone, and the Hoenn
gate's recall must bring that team back, with the party and every PC box counted. Before the fix
`RegionalTravel_PhysicalRegion` read the cave's Hoenn map section as mainland Hoenn, so the Hub
Pass replaced the remembered team with the carried one (`count=3`) and the recall brought the
carried team (`party=B0,B1,B2`): **14/16** on the unfixed ROM, **16/16** with the fix.
### `BnetMenuOverlap.lua`

Battle Net lists taller than six rows open with the message box closed. A static multichoice at
(0,0) with seven or more rows reaches the message band (tile rows 14 to 19), so the list hid the
start of each text line and its border cut through the first one. From a free hub, with real
input: the hub terminal's three Type Trainer pages (eight rows), the 2F director's starter-stone
offer on two visits (eight rows) and the stone vendor's two pages (seven rows). With each list
open the BG0 screen map must hold nothing in that band outside the list's own frame, and control
must return afterwards. The unfixed ROM left the terminal, director and vendor text on screen
behind every one of the seven lists.
### `SpecialWellHelperApproach.lua`

The Firefighter Squirtle quest's well helper must answer from the tile she faces. The kiln helper
starts the quest with real input; the suite then walks to the tile the well helper faces (read from
her live object and facing), presses A, and returns to the kiln for the reward. She stood on the
elevation-2 platform beside Slowpoke Well facing down onto an elevation-3 tile, and an object only
answers a player on its own elevation, so A in front of her did nothing and the quest could only be
finished by finding the side approach from the stairs: **5/8** on the unfixed ROM, **8/8** with the
fix.
### `SpecialDexFormsNav.lua`

The Pokédex Forms page must keep its button hint on screen on every page. With every Pokédex flag
set, real input opens Pikachu's Forms page (18 forms, two pages) and the suite reads BG2's tilemap
where the navigation window lives: on arrival, in form mode, after paging to page 2, after leaving
form mode there, and after a trip to Evos and back. `Task_HandleFormsScreenInput` (exported for
this suite) proves the page is open before each read. #394's paged `PrintForms` put the full-screen
info window's tilemap after the navigation window was drawn, so the "Form Mode / Evos" hint was
blank on arrival and vanished on every page change: **6/9** on the unfixed ROM, **9/9** with the fix.
### `AzaleaGsBallExit.lua`

Kurt's GS Ball scene waits outside his door: once he has taken the ball the player walks out, is
walked three tiles south, and Kurt runs out after them. A Hub Pass out of Kurt's house leaves without
that door. Kurt's own script takes the ball with real input and the Hub Pass is real; the suite then
debug-warps into the Ilex Forest gate and into a house so the player walks into Azalea from
elsewhere. The player must be free with the scene still waiting, and walking in and out of Kurt's
door must play it, return the ball and leave the player at (19,15). Before the fix the scene ran on
any arrival and walked the player into the trees below the Ilex gate (`80/0 (8,19) dirs=`) and onto
the ledge below the house (`(38,27)`), with no step possible in any direction: **11/18** on the
unfixed ROM, **18/18** with the fix.
### `DexMenuChord.lua`

A Pokedex START-menu row that changes screens must not be undone by B or START pressed on the same
frame. Both START menus handled A and then, on the same frame, START/B as "close the menu", so a
chord on Special Pokemon, Close Pokedex or (in search results) Back to Pokedex let the fade finish
on a black screen while the invisible list kept taking input. From the field, with real input
(and a real search for the search-results cases), the cursor is put on the row and A is pressed
with B or START for the same two frames. Each case must reach its own destination (the Special
Pokemon checklist, the full list, or the field), must not leave every palette colour black, and
must hand control back. Unfixed ROM **15/28** (all six cases on a black screen), fixed **28/28**.
### `StoryOverviewLine.lua`

The Story overview row shows only the first line of a region's next action, so that line must read
as a whole instruction. A fresh game is taken into Pallet, New Bark and Littleroot, Story is opened
from the Start menu with real input, and the action each of the three rows prints is read from the
live resolver results: its first line must end in `.`, `!` or `?`. The unfixed ROM printed
"Meet Prof. Oak and choose" for Kanto on every visit. `test/overworld/story-progress/run.py`
applies the same rule to all 164 authored objectives. Unfixed ROM **22/25** (the Kanto row on all
three visits), fixed **25/25**.
### `HubPassContexts.lua`

The Hub Pass in each self-contained session it must refuse and in the facilities where it must
work. Each context is entered the way its entry script leaves it (session flag or var, then a debug
warp) and the Hub Pass is SELECT with real input. Refused, with the player left in place and in
control: Safari Zone, Bug-Catching Contest, a live Trainer Hill challenge, a Battle Pike room, the
Battle Pyramid, a live Frontier challenge, underwater. Allowed: the Slateport Battle Tent lobby, the
Trainer Hill lobby, the S.S. Tidal mid-cruise (the corridor's own script starts the cruise, and the
cruise flag and `VAR_SS_TIDAL_STATE` must not outlive the warp) and the Lilycove contest lobby. Only
the contest lobby, which is mainland Hoenn, may rewrite Hoenn's remembered team. Coverage for a
predicate set the fourth stress pass found clean: **37/37**. A tamper build without the Bug Contest
and underwater refusals scores **31/37**, naming both.
### `SpecialPokemonCatchRecovery.lua`

Every recovery path of the two visible special catches, Surfboard Pikachu on Route 19 and Pirate
Totodile at Olivine, with real input. A level 100 Mewtwo from the debug Give menu leads (met level
set to 1 so it obeys without badges). For each source: the target offers no battle before its intro
NPC speaks, the offer can be declined, running and knocking the target out leave it uncollected and
available, a battle with no Poké Balls hides the ball shortcut and R throws nothing, and Poké Balls
are thrown until one holds (break-outs included, one ball spent per throw); the catch must set the
collection mark and deliver the catalog level, the themed move, no held item and a non-shiny
Pokémon. On Pirate Totodile the suite also loses on purpose (whiteout keeps the source unlocked and
the next talk starts a battle again) and fights with a full party and a full PC (the ball is refused
and not spent). Coverage the capture evidence for #394 listed as missing: **42/42**.
### `SpecialPokemonRules.lua`

The special Pokémon rules with real input. From the Bag, a Thunder Stone on each special Pikachu
and every Eevee stone (Fire, Water, Thunder, Leaf, Ice, Sun, Moon, Shiny) on Flower Crown Eevee do
nothing and keep the stone; Rare Candies take Squad and Firefighter Squirtle to 16 and Pirate
Totodile to 18 with no evolution scene. A won Pirate Totodile battle with shared EXP levels Squad
Squirtle and Pirate Totodile past their evolution levels without evolving them. Each path has an
ordinary control that evolves (Pikachu with a Thunder Stone, Squirtle with a candy, Squirtle in the
battle). The Move Reminder offers Classic Cap Pikachu its forgotten Thunderbolt and teaches it. At
the Route 34 Day Care, Classic Cap Pikachu with a traded Ditto gets the "prefer to play with other
POKéMON" verdict and no Egg in 1600 steps, while ordinary Pikachu with the same Ditto gets an Egg.
`PW_RULES_ONLY=<text>` runs matching scenarios. Coverage; no defect found: **33/33**.
### `MoneySinkEdges.lua`

Script money sinks at the wallet's edges, driven with real input: walking, talking, Yes/No, menus
and the Day Care deposit picker. Each sink runs with 0, one short of the price and exactly the
price (plus a comfortable wallet where it is cheap). A short wallet must be refused with the money
unchanged and nothing handed over; the exact wallet must end at 0 with one delivery; the field
must come back. Money, items, Pokemon, flags, vars and Safari state are read from RAM. Sinks: the
Day Care withdrawal at Route 117, Route 5, Four Island and Route 34, after a real deposit and a
walk until the fee reaches 400 (`VAR_0x8005` and the printed fee must both equal 100 plus 100 per
level, modelled from the Rattata's Exp and step count), and the Route 117 level menu's second slot
with two Pokemon in care, where that slot asks 100 and the first asks 300; the Route 4 Magikarp
salesman (500); Safari Zone entry in Kanto, Hoenn and Johto (500 for Safari mode, 30 balls and the
zone); every drink in the Lilycove and Celadon vending machines (200, 300, 350); the Route 109
Seashore House Soda Pop (300); the Mt. Chimney Lava Cookie (200); the Slateport and Pewter museum
fees (50); the Mahogany RageCandyBar merchant when talked to and when he stops the player (300);
Route 39 Moomoo Milk (500, where a second bottle meets the emptied wallet); the Celadon photo
printer (50) and all three coin desk rows (1,000, 10,000, 100,000); and the Goldenrod haircut
brothers by day and by night (500, 300). The Route 43 toll, the Hub mart and the Mauville coin desk
are covered by `Route43Toll` and `EconomyStress`. Measured **405/405**; no defect found. With the
Magikarp salesman's `checkmoney` lowered to 499 the suite failed on that sink alone, **402/405**:
499 bought a Magikarp and left 0, and that extra Magikarp filled the party so the comfortable
purchase went to the PC. `--env PW_SINK_ONLY=<text>` runs matching sinks (`daycare`, `safari`).

### `BirchBagFullParty.lua`

Birch's bag on Route 101 when a Johto champion arrives with a full party (Frontier ferry, then the
same-region gate). The starter goes to the PC, and the lab scene must name the starter, say it went
to the PC and nickname it rather than the party's lead. Before the bag, the full-party run fills
every box through the debug menu: the starter is given inside `CB2_GiveStarter`, where nothing can
refuse it, so the bag itself must stay shut, the rescue unfinished (`VAR_ROUTE101_STATE` 2,
`FLAG_RESCUED_BIRCH` clear) and the party and boxes unchanged. One boxed Pokemon is then released in
memory and the rest of the run uses the bag. Measured **4/6** on the unfixed ROM, where the picker
opened with no room anywhere; played on from there, the first battle and the lab scene ran, Birch
said "I'd like you to have the POKéMON you used earlier" with `STR_VAR_1` naming it, and the chosen
starter was in neither the party nor a box. `--env PW_BIRCH_PARTY=0` runs the empty-party control.

### `NamedGiftFullParty.lua`

Johto's named gift Pokemon with six in the party and empty boxes. `givenamedmon` (Randy's Kenya,
Kirk's Shuckie, Bill's Eevee, the Dragon's Den Dratini) places its Pokemon in the party only, so a
full party makes it report `MON_CANT_GIVE` however much room the PC has. For Randy, Kirk and Bill
(seeded present the way the Ecruteak Pokemon Center scene leaves him) the suite talks, answers Yes
and reads every message from `gStringVar4`: the refusal must say the party is full and must not
claim the boxes are, and nothing may be given or recorded. With one party slot freed in memory the
same talk must give the Pokemon. Measured **20/26** on the unfixed ROM, where all three refusals
printed "There's no more room for POKéMON! The POKéMON BOXES are full and can't accept any more!"
with every box empty.
### `JohtoNightLights.lua`

The Johto maps came from pokemonHnS, which has six light types; this engine had three and
`SpawnLightSprite` clamped every larger type to the Poke Mart sign. Goldenrod, Route 34, both
National Park maps and Olivine use type 3 (street lamp) and every Whirl Islands floor plus the
Olivine lighthouse use type 4 (glow), so 120 lamps drew a teal "MART" sign beside the post at night.
At 22:30 the suite walks Goldenrod from the Game Corner door to the campaign's (32,43) viewpoint,
crosses into Route 34 (playing through the first-visit Elm call at y=5), and visits the National
Park east gate, Olivine (walking east until the lighthouse beacon is in view) and two Whirl Islands
floors. For every lamp in view it finds the `UpdateLightSprite` sprite at the lamp's coordinates
and asserts the picture table of its template (street lamp: `SmallLight`; glow: `BallLight`) and
that it is lit. A day pass at 14:30 asserts that Whirl Islands glow lichen stays lit (HnS keeps
type 4 on by day) and that Goldenrod's street lamps go dark, the control that a day light switches
off. `make validate` also gained `LIGHT-TYPE` in `ValidateMapEvents.py`: every light sprite's type
must index `gFieldEffectLightTemplates` (120 violations on the unfixed tree, 0 now).
**47/81** on the unfixed ROM, **81/81** with the fix.
### `EvoMoveLearnChord.lua`

A and B pressed on the same frame at the evolution scene's "forget a move?" prompt must act once.
A Rare Candy from the Bag levels a debug-given Ivysaur 31 with four moves to 32, it evolves into
Venusaur, and Venusaur tries to learn Petal Blizzard; with the cursor on YES, A and B go down
together for one frame with real input. The move-select summary must open, the screen must not be
left black, and choosing the first move there must teach Petal Blizzard over it (one candy spent).
Before the fix `Task_EvolutionScene` took YES (state to the move-select screen, fade to black) and
then, in a separate `if`, NO on the same frame, so "did not learn" waited for a press on a black
screen and the move was never learned: **7/10** on the unfixed ROM, **10/10** with the fix.
### `BagSortChord.lua`

START and A pressed on the same frame in a one-item Bag pocket must do one thing. Three Potions are
the only Items stack; the Bag opens from the start menu and START and A go down together for one
frame with real input. The "There's nothing to sort!" message must come up without the item's
context menu, A must dismiss it back to the item list, and the Potions must be untouched. Before
the fix that START path in `Task_BagMenu_HandleInput` (`src/swsh_item_menu.c`) used `break` and
fell into the list input below it, so the same A opened the context menu over the half-started
message and its blank box stayed over the item description until the Bag closed: **3/6** on the
unfixed ROM, **6/6** with the fix.
### `JohtoTilesetArt.lua`

The five Johto League rooms, the Johto Hall of Fame and Cianwood's shop were ported from pokemonHnS
with layouts naming `gTileset_PokemonLeague`, `gTileset_HallOfFame` and `gTileset_BikeShop`, which
here are the FRLG and Emerald tilesets of those names. The Champion's room drew black void squares
beside its stairs (the 15 blank references `ValidateMetatileBounds.py` had pinned as legitimate),
Koga's and Karen's rooms drew FRLG ice pillars and fangs, and the Hall of Fame entrance was a void
square. For each sampled cell the suite builds the picture the running game draws: the metatile id
from `gBackupMapLayout`, its eight tile entries from the live layout's tilesets, and each tile's
pixels from BG VRAM, hashed as palette-slot and colour indices. The expected ids and hashes are
pokemonHnS's, produced by `test/overworld/JohtoTilesetArtExpect.py <HnS clone>` (it prints the
suite's table). Every room has a control cell the port always drew right, which passes on both
ROMs. With `VAR_LEAGUE_STATE` seeded to 2, as Will's defeat script leaves it, the suite also walks
Will's opened north exit into Koga's room. **15/30** on the unfixed ROM, **30/30** with the fix.
### `MtSilverEscape.lua`

Escape Rope and Dig on Mt. Silver's outdoor map. `MtSilver_Outside` was the only city or town map
that allowed escaping, and nothing there sets the escape warp: the player walks out of the
Mt. Silver Pokemon Center or in from Route 28, so the warp still names the last building or cave
entered from outdoors, in any region. The World Transit gate resumes a Johto trip at that Center.
The suite visits the Center for real, walks into Diglett's Cave from Route 11 in Kanto, resumes
Johto at Mt. Silver through the gate, walks out, and uses an Escape Rope from the Bag and Dig from
the party menu, then checks both still work in Diglett's Cave. Before the fix both carried the
player to Kanto's Route 11 with Johto still the saved region (`37/29 (6,8) region=2`): **18/21**
on the unfixed ROM, **21/21** with the fix.
### `TravelSaveContinue.lua`

Save and Continue after Dig, Escape Rope, Teleport and Fly in Kanto, Johto and Hoenn, each straight
after a World Transit gate crossing: Teleport or Fly as the first move after the arrival, then a cave
door walked into, a save inside it, an Escape Rope and a Dig out of it, and the other of Teleport and
Fly. Every landing is saved from the Start menu and soft reset or power cut; the Continue must
restore the map, tile, saved region, whiteout point, escape warp, party, PC, money and regional
memory. After a Dig in Johto a power cut on six frames of the 247-frame flash write must load the
cave save or the Dig save whole. From the Battle Frontier, reached from Kanto, Fly to a Hoenn town
must claim Hoenn and re-arm the whiteout point in Littleroot without recording a departure, and a
later Teleport from the Frontier must land there. Select with the Hub Pass registered is held
through each move's warp and landing: the Hub Pass only answers after the landing. Setup seeds
badges, visited towns and a lead with Teleport, Dig and Fly; a debug warp only puts the player on
each cave door's outdoor tile. `PW_TSC_ONLY=<text>` runs the matching cases. Measured **292/292**;
no defect found. A tamper build that stops `UpdateEscapeWarp` refreshing the escape warp scores
**268/292**.

### `GateRecallTrades.lua`

Gate recall after the remembered team changed through the game's own flows. Johto remembers six:
a Caterpie, Squad Squirtle from `SpecialPokemon_Give`, a Spearow, a Pidgey, an Egg and an Abra. In
Kanto, with real input, the Abra is traded for Mr. Mime in the Route 2 house, the Pidgey goes to the
Route 5 Day Care, the Egg hatches through the hatch scene and a Rare Candy evolves the Caterpie. The
Johto recall must name the Day Care and the missing Abra in its preview, carry the four reachable
members in remembered order as Metapod and Togepi, keep Squad Squirtle's form, box Mr. Mime and
leave the Pidgey in the Day Care. The Kanto recall must bring the Kanto-traded Mr. Mime back out of
the PC. Every Pokemon is counted by personality across the party, the PC and both Day Cares, then a
save and Continue closes the run. Measured **34/34**; no defect found. A tamper build that drops
the regional identity in `CreateHatchedMon` scores **32/34**: the hatched Togepi is left behind,
which `GateRecallStress` (it clears the Egg bit in memory) cannot see.
### `StorageItemMailMenu.lua`

PC storage, Move Items, A on a party Pokemon that holds Mail. The PC cannot take, bag or switch
Mail, so the item menu has no row for it and must not open. Three Bulbasaur come from the debug
Give menu; the first holds a Potion and the second Orange Mail (letter in mailbox slot 0, linked
the way `GiveMailToMonByItemId` leaves it). Opening the PC, Move Items, the cursor and every menu
choice are real input. Case one takes the Potion, gives it to the third Bulbasaur and presses A, A
on the Mail holder; case two, in a fresh PC session, opens and closes the first Bulbasaur's Give
menu and presses A, A on the Mail holder. The Mail and its letter must stay linked, no Potion may
be copied and the Bag must not open. Before the fix `SetMenuTexts_Item` built a menu with zero
rows and A ran the row left over from the previous menu: a stale Give copied the Potion over the
Mail, and a stale Give from the Bag opened the Bag.
### `StorageMailIntoBox.lua`

PC storage, Move Pokemon: a party Pokemon that holds Mail must never reach a box, where its letter
would be orphaned in the mailbox. Three Bulbasaur come from the debug Give menu; the second holds
Orange Mail (letter in mailbox slot 0, linked the way `GiveMailToMonByItemId` leaves it). Opening
the PC, Move Pokemon, the cursor and every menu choice are real input. A control Bulbasaur without
Mail moves Right into the box and goes down with B; the Mail holder, picked up with Move and again
by a Shift with the boxed Bulbasaur, is pushed Right each time. Right must keep the cursor in the
party with "Please remove the mail." up, and the Mail holder must end in the party with its letter
linked. The SwSh PC keeps the party on screen, so nothing produced the vanilla `INPUT_HIDE_PARTY`
refusal and the Mail holder walked into the box: **13/21** on the unfixed ROM (it landed in box 1
slot 1 both times), **23/23** with the fix.
### `CatchSwapMailHolder.lua`

A catch with a full party, answering Yes to "add it to your party?": the party Pokemon sent to the
PC in its place must not hold Mail, or its letter is orphaned in the mailbox. Six Bulbasaur come
from the debug Give menu, the third holding Orange Mail (letter in mailbox slot 0, linked the way
`GiveMailToMonByItemId` leaves it); one Master Ball comes from `additem` and a wild Pidgey from
`setwildbattle` + `dowildbattle`. The throw (R shortcut), the nickname prompt and naming screen,
"add to party?", the party pick and "send to the PC?" are real input. Picking the Mail holder must
be refused with the party menu still choosing; picking the fourth Bulbasaur (control) must box it.
The Mail holder must end in the party with its letter linked, Pidgey in the party and exactly one
Pokemon boxed. The SwSh party menu's `PARTY_ACTION_SEND_MON_TO_BOX` refused only partner Pokemon
and HM users: **7/10** on the unfixed ROM (the Mail holder went to box 1 slot 1), **12/12** with
the fix.
### `StorageReleaseHeldItem.lua`

PC storage, Move Pokemon, Release on a Pokemon that holds an item. `OW_PC_RELEASE_ITEM` sends a
released Pokemon's held item to the Bag. Five Bulbasaur come from the debug Give menu, three of
them holding a Potion (a release needs three Pokemon left over). Opening the PC, Move Pokemon, the
cursor, the menus, the release prompt and its messages are real input. One Bulbasaur is picked up
with Move and released from the hand, and one is released from its party slot (control): each
Potion must reach the Bag. Then, in a fresh PC session with the Items pocket filled with other
items in RAM, a third release must be refused with "The bag is full." and leave the Pokemon and
its Potion alone. Before the fix `ReleaseMon` skipped the item of the Pokemon in hand, and a Bag
with no room let the release go ahead and dropped the item: **17/20** on the unfixed ROM,
**20/20** with the fix.
### `NormaTangelaTrade.lua`

Norma's in-game trade in the Cinnabar Pokemon Lab lounge (a Venonat for her Tangela, TANGENY). The
trade specials read the trade id from `VAR_0x8005` and the party slot from `VAR_0x8004`, and every
other in-game trade goes through the shared `EventScript_*InGameTrade*` wrappers; Norma's script kept
FRLG's order. One Venonat comes from the debug Give menu and the suite warps into the lounge.
Declining Clifton's trade (which leaves his trade id in `VAR_0x8005`, as in normal play), talking to
Norma, Yes, the party pick and the trade scene are real input. The party's only Pokemon must become
Tangela and `FLAG_DID_TANGENY_TRADE` must be set. On the unfixed ROM Norma asked for Clifton's
Raichu: **6/9**, where the Venonat was refused; a probe that offered a Raichu instead kept it, got
nothing and still used up the trade. **9/9** with the fix.
### `DefaultBoxCatchMessages.lua`

The box names in the "sent to the PC" lines when a default deposit box is set (the PC box menu's
"Make Default", `VAR_DEFAULT_PC_BOX`). Six Bulbasaur come from the debug Give menu, and BOX3 is made
the default with real input (box title, R, Make Default, back to BOX1, out). With BOX3 filled in RAM,
the Celadon Condominiums Eevee is taken (nickname declined): the box-full line must name BOX3, then
BOX4. With BOX4 filled too (the line shows once per landing box), a wild Pidgey from
`setwildbattle` + `dowildbattle` is caught with a Master Ball, answering No to "add it to your
party?": BOX3, then BOX5. With BOX3 emptied, a second Pidgey is caught answering Yes and sending
the sixth Bulbasaur: the line must name BOX3, where it lands. Names are read from the battle text
and `gStringVar4`. Before the fix the box-full lines named the box of the previous transfer and the
swap line the box from before the transfer: **12/15** on the unfixed ROM (BOX1, BOX4 and BOX5),
**15/15** with the fix.
### `PCStorageMashStress.lua`

The PC storage screen under seeded random input. Four Bulbasaur come from the debug Give menu (two
holding a Potion), debug Fill PC Boxes Fast fills every box, part of BOX1 and BOX2 is emptied, five
boxed Pokemon get a Potion and the Bag gets five more. Sixteen sessions each open the PC (debug Access
PC), take Move Pokemon, Deposit, Withdraw and Move Items in turn and mash A, B, the D-pad, L/R paging,
Select (cursor modes, multi-select moves) and Start for 3,000 frames, going back in whenever the mash
leaves; a session ends by putting down whatever is in hand and leaving the PC. On the field the suite
counts every Pokemon by personality and every Potion held or in the Bag: only a release (each counted
from `Task_ReleaseMon` as it runs) may remove a Pokemon, nothing may be copied, and no Potion may be
lost. In the summary screen L, R and Select are skipped, because they open the move relearner and the
debug sprite visualizer. `--env PW_SEED=<n>` picks another input stream. Coverage for the area the
fourth stress pass fixed by hand: **4/4** on seeds 4242, 1, 2, 3, 5, 7, 8, 9 and 10 with the pass's
fixes, and on 4242, 1 and 2 on the earlier tree.
### `LakeOfRageMagikarpSale.lua`

The Lake of Rage fisherman's Magikarp sale (`removegenericmon`, after the Rocket event) must follow
the rules every other removal follows. The party comes from the debug Give menu and `giveegg`,
`VAR_MAHOGANY_TOWN_STATE` is set to 14 and the suite warps into the house; talking, Yes, the party
pick and every message are real input. Selling the Magikarp of a Magikarp-and-Egg party must be
refused ("don't let me take your last POKéMON"); a Magikarp Egg must be refused as not a Magikarp;
a Magikarp next to a healthy Bulbasaur (control) sells for 2,000; and a second Magikarp holding
Orange Mail (letter in mailbox slot 0, linked) sells and frees its letter. Before the fix the script
refused only a party of one, the species check read through Eggs and the slot was zeroed with the
letter still allocated: **18/23** on the unfixed ROM, **23/23** with the fix.
### `ResortGorgeousRequest.lua`

Selphy's wish at Resort Gorgeous must name a Pokemon the player can show. With every Gen 1 to 3
species seen (written to the Pokedex) and Selphy at home, the suite talks to her five times with
real input: each request must be a seen, enabled base species, and showing that species (from the
debug Give menu) must earn the butler's reward; leaving and re-entering the house clears her
"just fulfilled" flag between rounds. A last case loads Galarian Ponyta, a request the unfixed ROM
wrote, and Selphy must replace it. Before the fix `SampleResortGorgeousMon` drew any species id:
40% of 40 sampled requests were forms (Megas, Unown letters, regional forms, Pikachu forms) that
the exact-species party check refuses forever, and 23 of the 40 showed the
`SRC/POKEMON.C: DISABLED SPECIES` assert screen first. **7/11** on the unfixed ROM, **53/53** with
the fix.
### `SpecialChecklistPaging.lua`

Right on the Special Pokémon checklist's first page must turn to page 2 from every row. Real input
opens the checklist from the Pokédex START menu, then presses Right from each first-page row,
Right again on page 2, and Left back, reading the selected row (`sSpecialPokemonMenu`, exported for
this suite) and the icons drawn. #394 wrote the jump for a ten-entry catalog and it only moved when
an entry sat exactly five rows down, so on the five-row list Right did nothing from rows 3 to 5:
**17/23** on the unfixed ROM, **23/23** with the fix. The list now shows four rows a page so the
32-pixel icons have room (Balloon Pikachu's balloons covered Surfboard Pikachu's board on 23-pixel
rows); page 2 holds three of the seven entries and row 4 lands on the last one, as the Pokédex
list clamps.
### `SpecialQuestRegionSwitch.lua`

The Vermilion Fan Club's Squad Squirtle task must survive a Hub Pass and two region switches in the
middle. With real input the suite crosses to Kanto, starts the task with the organizer, finds the
first Squirtle (chasing its live position), Hub Passes to the hub, crosses to Johto, Hub Passes
back and crosses to Kanto again, checking `gCurrentRegion` and the task flags after each switch.
It then finds the second Squirtle, accepts the organizer's gift and declines the repeat offer:
exactly one Squad Squirtle must arrive. Setup writes travel flags only; every task flag comes from
the NPC scripts. Coverage, no defect found: **17/17**. A tamper build that clears the first
Squirtle's flag on entering Johto scores **12/17**.
### `FrlgStepCounters.lua`

Two FRLG timers that count the player's steps, walked with real input. Selphy at Resort Gorgeous
makes a wish (every Pokédex flag set from the debug menu); after 200 steps the wish must stand,
after 260 it must have expired, and talking to her then must give a new wish ("tired of waiting").
Daisy in Pallet Town, with the game cleared, grooms the debug party's Pokémon, and after 500 steps
she must offer grooming again instead of only rating friendship. Crash screens are dismissed so the
timers are tested even where Selphy's sampler trips an assert. The port never called
`IncrementResortGorgeousStepCounter` or `RunMassageCooldownStepCounter` on a step, so the wish
never expired and Daisy groomed once per save: **15/19** on the unfixed ROM, **19/19** with the fix.
### `RegisteredItemDecline.lua`

Answering NO to a key item's YES/NO on the field must give the field back with every object free.
At Petalburg City a lead Pokemon follows the player; the item use, its message, the NO and a talk
to the follower all run with real input. Four cases from one savestate: the Hub Pass from SELECT
with the follower already out walking, the Hub Pass from SELECT straight off a warp (the follower
still hidden on the player's tile, so one step must bring it out), the Pokevial from SELECT, and
the Hub Pass from the Bag followed by one step. `UseRegisteredKeyItemOnField` and the Start menu
freeze every object first, and both NO handlers released only the field controls
(`ScriptContext_Enable`). The follower stayed frozen where the player left it. Frozen mid-animation
(the SELECT cases), talking to it started `EventScript_Follower`, whose `lock` waited forever in
`Task_FreezeSelectedObjectAndPlayer` with nothing on screen. This is the lock `InputSpamStress`'s
registered Hub Pass mash reached on the stress pass 4 integration build: **20/26** on the unfixed
ROM, **26/26** with the fix.
### `RenewableHiddenItems.lua`

FRLG's renewable hidden items on the Sevii Islands, walked and picked up with real input. Every step
counts toward `VAR_RENEWABLE_ITEM_STEP_COUNTER`, which stops at 1500; entering a map from FRLG's
table at the cap restarts the count, hides every renewable item and shows one sampled tier on every
table map. The suite uses Treasure Beach's Ultra Ball, which is in all three tiers, and Trainer
Tower's Nanab Berry, which is not in the table. A new game finds no Ultra Ball; the Nanab Berry is
picked up; 1500 steps cap the count; walking back into the Trainer Tower area from Seven Island
restarts it, the Nanab Berry stays gone and the Ultra Ball is then on the beach; after 1000 more
steps a warp back in finds nothing; after 500 more the warp in restarts the count and the Ultra Ball
is back. The port defined the counter (on a raw id that is Hoenn's `VAR_STARTER_MON`) and never
counted a step or regenerated anything, so a renewable item taken once was gone for good:
**27/32** on the unfixed ROM, **32/32** with the fix.

### `JohtoHeadbuttTutor.lua`

The Ilex Forest Headbutt tutor offered `TUTOR_MOVE_HEADBUTT`, an HnS alias of `MOVE_HEADBUTT` that
`tools/learnset_helpers/make_tutors.py` does not recognise (it reads `setvar VAR_0x8005, MOVE_*`),
so Headbutt was never a tutor move, no teachable learnset held it, and his party menu showed every
Pokemon NOT ABLE. With real input from the Route 34 entrance the suite walks 94 tiles to the tutor
at (42,26), says YES and picks a level 5 Pidgey (a level 100 Lapras leads so the Repel holds), then
checks Pidgey knows Headbutt and that the script set `FLAG_GET_HEADBUTT`. **7/9** on the unfixed
ROM, **9/9** with the fix.

### `JohtoHeadbuttTrees.lua`

The Johto tilesets came from pokemonHnS with HnS's metatile behaviour numbers, and HnS numbers 45
behaviours differently. Its 0xA1, `MB_HEADBUTT_TREE`, read here as `MB_INDIGO_PLATEAU_SIGN_1`,
which only answers in Kanto, so the 1,317 Headbutt-tree cells on Johto maps did nothing, while the
Ilex Forest tutor and the Route 39 sign tell the player to Headbutt trees and 35 maps keep HnS's
Headbutt table as `rock_smash_mons` with no rock to smash. Azalea Town is the bed: its only wild
table is that one (rate 60) and it has no grass. With real input the suite walks to (28,13) under
the small tree at (28,12). A at the wall beside it runs no script (control). A Magikarp, which can
never learn Headbutt, gets "It's a small tree..." and no battle, without and then with
`FLAG_GET_HEADBUTT` (Bugsy's win and the Ilex tutor set it). A Pidgey that does not know Headbutt
but can be taught it is refused without the flag; with it the tree says "Pidgey used Headbutt!"
and a wild battle against a species from Azalea's table starts within 30 tries (HnS accepts a
Pokemon the tutor could teach). `HnsMetatileBehaviors.py` (host check) keeps HnS numbers out of
the Johto tilesets. **11/18** on the unfixed ROM, **18/18** with the fix.

### `JohtoViridianIndigoTiles.lua`

Route 28, Route 26 North and the Johto Indigo Plateau came from pokemonHnS with layouts naming
`gTileset_ViridianCity` and `gTileset_IndigoPlateau`, which here are FRLG's tilesets: the Route 28
house roof and door, the reception gates' tree bases and the Indigo statues and doorway drew
speckled garbage (two blockdata patches had papered over the worst of it). Four camera views (the
Route 28 house, both reception gates, the Indigo building) are checked at 14:30 and 22:30. By day
each sampled cell must hash to HnS's picture (`test/overworld/JohtoTilesetArtExpect.py <HnS>
JohtoViridianIndigoTiles` prints the table, and the last cell of each view is a control the port
always drew right), and the window glass must be blue. At night the same glass colours must be warm
in `gPlttBufferFaded`: the amber treatment `night-lighting/johto_glass.py` authors for HnS's masked
glass. **9/22** on the unfixed ROM; **19/22** on a build without the amber alternates (HnS's own
mask glows pale grey-green); **22/22** with the fix.
### `SummaryMoveCancelRace.lua`

Up pressed while the SwSh summary's move panel is still sliding in must not show a move past the
list. On the moves page A starts move select, and `Task_ShowEffectTilemap` slides the details
panel in over six frames before it prints the move under the cursor. Move select takes input
during the slide, and Up from the first move lands on the Cancel row (index `MAX_MON_MOVES`). The
panel's last step read `summary.moves[4]`, one past the array: the first two PP bytes as a move id
(2580 for this Abra's Teleport and Dig). The debug build stops on `INCLUDE/MOVE.H:232: INVALID
MOVE: 2580`; Start resumes into placeholder text, a category icon and a garbage accuracy on Cancel,
or, where the entry past `gMovesInfo` has a NULL description, a CPU crash (InputSpamStress's dig
mash found it that way). A debug-made Abra leads and the summary opens from the party menu with
real input. Controls: after a finished slide Teleport shows its Status icon and Up to Cancel
clears it. Then Up one, three and five frames after A: the game must keep running, Cancel must
show no category icon, Down must wrap to Teleport, B must leave move select, and B must close the
summary to the party menu and the field. **6/20** on the unfixed ROM, **20/20** with the fix.
### `OweContactCoordEvent.lua`

A visible wild Pokemon that walks into the player mid-step must not swallow the coord event on the
tile the player arrives on. Victory Road 1F's Wally battle is the coord event pair at (2,23) and
(3,23), the only corridor to the B1F ladder. The player stands at (2,22) facing the trigger with a
generated encounter moved beside the corridor (west of the trigger, or west of the tile the player
leaves), and each trial loads that state, waits 0 to 127 frames and steps down with real input. The
encounter's wandering, contact and battle are the game's own; battles are won by pressing A with a
debug-given Mewtwo. A contact before the step ends the trial untested. Sweep A has the trigger live:
every trial that takes the step must start Wally's scene (the script pointer inside
`VictoryRoad_1F_EventScript_WallyBattleTrigger1` to `WallyEntranceBattle`) before the player leaves
(2,23). Sweep B sets `VAR_VICTORY_ROAD_1F_STATE` to 1, the value Wally's scene leaves, so the same
step lands on a plain tile, and requires contacts made during the step to still start their battle by
the frame after it. The encounter's step is checked from its sprite callback and started its script
there, so on 16 consecutive offsets per placement the script held the field controls through the next
`ProcessPlayerFieldInput`, the one that runs the arrival's coord event; after the battle the player
stood on the trigger and walked past Wally, as a world campaign did on the stress pass 4 integration
ROM. Measured **8/8** fixed and **6/8** on the unfixed ROM (32 of 256 sweep A trials walked past,
and sweep B shows the same 32 contacts locking before the walk ended); on the fixed ROM those
contacts start their battle on the frame after the walk on a plain tile and yield to Wally on the
trigger. `PW_OWE_OFFSETS` (pass with `--env`) changes the offsets per sweep.
### `TowerMultiRoomBoxes.lua`

The SwSh party menu's R (Boxes, `SWSH_PARTY_MENU_PC_ACCESS`) must not open the PC in the Battle
Tower multi partner room. The lobby parks the full party in SaveBlock1 and the challenge's end
reloads it, so a Pokémon moved through the PC from the two-member stand-in party is cloned
(deposited) or deleted (withdrawn). The suite gives six Pokémon, takes the real Lv. 50 multi
challenge, rides to the partner room, opens the party from the Start menu and presses R; if the PC
opens it moves the second Pokémon into Box 1 with real input. It quits at the room attendant and
counts each Pokémon's copies across the party and the boxes. Control: in the lobby afterwards the
same R opens the PC. Measured **14/14** fixed and **12/14** on the unfixed ROM (the PC opened and
the deposited Charmeleon existed twice after the challenge).
### `UsmOrderSpecialContext.lua`

Closing the graphical Start menu in a context that hides icons must not drop them from the
player's saved icon order (`SaveBlock3.usmSaved`). The suite moves Save to the front of the wheel
with real SELECT and D-pad input, enters the Bug-Catching Contest at the National Park gate
(which hides Save), moves the Bag ahead of the Party in the contest menu, retires at the exit and
opens the menu again. Save must still lead and the contest's Bag move must be kept. Before the fix
`Usm_SaveItems` wrote back only the icons the contest showed, so Save fell out of the order and
returned at its default slot. Measured **9/9** fixed and **6/9** on the unfixed ROM.

### `HoldBStaticEncounter.lua`

Holding B at the start of a wild battle auto-runs, and B is also the overworld run button, so a
player who runs up to a placed encounter and presses A is still holding B when its battle starts.
Auto-run is for ordinary random and visible encounters; a scripted static battle treats RAN as
resolved (the Power Plant's Electrode is removed, Snorlax returns to the mountains), so fleeing it
on a held B lost the encounter for good. A debug party enters the Power Plant and walks to
Electrode 1 with real input (random encounters on the way are fled by holding B, which must still
work: the last check counts them). Holding B, A is pressed on the Electrode "item ball" and then
tapped only to page the battle intro. The fixed game reaches the action menu and stays there with
B held; the suite then picks RUN. **7/8** on the unfixed ROM (the battle ends on its own),
**8/8** with the fix.
### `BagTMCancelMessage.lua`

Cancelling a TM's in-bag party select must take its "Teach ... to a POKéMON?" prompt down. The
prompt stays up over the party select (`SWSH_ITEM_MENU_ACTION_IN_BAG`), and `BagMenu_ClosePartySelect`
returned to the list without removing it, so the message box covered the TM description, followed
the player into the Items pocket and was cut through by the next Give's description. A debug-made
Pokémon leads; with real input the suite Uses TM01, answers Yes, presses B, switches to Items and
starts a Give of a Revive. It counts windows with the item message template in `gWindows` (the main
list keeps an identical always-allocated `WIN_MESSAGE`, so two means the prompt is up). Control: the
prompt is up during the select on both ROMs. Measured **7/7** fixed and **4/7** on the unfixed ROM.

### `SkyCharmBikeAloft.lua`

The Mach Bike and the Acro Bike pressed on Select while the Sky Charm flight is airborne. The Sky
Charm only takes off on foot, but the bike accepted the reverse order: in mid-air it set the bike
avatar flag, swapped the rider's sprite and started the region's cycling theme as the saved music.
Landing put the player on foot with the cycling theme still playing, and the saved music brought it
back after battles and menus until the next map change. `IsBikingDisallowedByPlayer` now refuses
while flying. In Olivine City with Johto badge 6 and the Sky Charm and both bikes given by an
injected `additem`, each bike case takes off on the pier, flies over the sea at (18,65), presses
Select with the bike (refused: still flying, on foot, the same sprite, the map music and no saved
music), lands on the pier and checks the music on foot, then mounts and dismounts the bike on the
pier as a control. Measured **19/19** fixed and **11/19** on the unfixed ROM, where both bikes
mounted aloft and `MUS_HG_CYCLING` (669) kept playing on foot after landing.
### `BagCallbackGiveStress.lua`

The Bag's in-place party select serves Use and Give, with Use's callback left in `gItemUseCB` and
Give's mode in the static `sPartyGiveMode`. For each party-callback item (Potion, Revive, Max
Revive, Rare Candy, Fire Stone, Ether, PP Up, Sacred Ash with and without an effect, TM01) the
suite Uses it with real input, backs out (B at the select; A then B B for the PP items; No-effect
or real Sacred Ash; Yes then B for the TM), then Gives a Revive to the lead: exactly one Revive
must move, no Pokémon's HP may change and the backed-out item must stay. Then Orange Mail onto a
holder (refused) and onto a non-holder (letter opened, quit with Yes), then Use Potion on the hurt
lead in the reopened Bag must heal it, not give it. Measured **64/64** on master and **58/64** with
`0829014ec0`'s `swsh_item_menu.c` hunks reverted (one Revive revived the fainted Charmander through
the stale Sacred Ash callback, and the Potion after the Mail give was given instead of used).
`PW_ONLY=<plan name>` (pass with `--env`) runs one plan.
### `IconRowStacking.lua`

A Pokemon icon must draw in front of the icon in the row below it in the party menu, the PC's party
column and the PC's box grid. Icons are 32 pixels tall on 24-pixel rows in all three, and sprites
with equal subpriority sort the lower one in front; the party menu and the PC's party column gave
every icon one subpriority and box icons differed only by column, so Balloon Pikachu's balloons hid
Surfboard Pikachu's board whenever Balloon sat below it (the overlap #529 fixed on the Special
Pokemon checklist). Classic Cap, Surfboard and Balloon Pikachu come from the debug Give menu. With
real input the party menu opens and switches its first and third Pokemon, then the PC (Move Pokemon)
moves Surfboard to box row 1 and Balloon to the slot below it. The suite compares the OAM sort keys
`BuildOamBuffer` builds for each upper and lower icon: in the party menu before and after the switch,
the PC's party column, the box after the moves, after reopening the PC, after Surfboard is picked up
and put back (a re-created box icon took OAM priority 2 while the box's first icons have 1, so the
lower icon won on priority alone) and after scrolling to the next box and back. **20/30** on the
unfixed ROM (all ten pairs), **30/30** with the fix.
### `UsmOpenCloseStress.lua`

The graphical Start menu opened and closed 125 times with real input while the icon set changes
between opens (Pokédex, PokéNav and DexNav flags toggled as setup). Cycles vary the D-pad walk,
hold past the auto-repeat delay and reorder with SELECT. After every close the in-use sprites,
sprite-VRAM tiles (`sSpriteTileAllocBitmap`) and OAM matrices (`gOamMatrixAllocBitmap`) must equal
the field baseline, and every open must put the cursor on a real icon. Every 12th cycle opens
Options from the last icon, removes three icons while Options is up and returns: the restored
cursor must be in range and A must open the icon it shows. Options returns through a field reload
that can respawn the follower, so the baseline is re-taken there and every reload must settle on
the same counts. Measured **7/7** on master and **4/7** with `0829014ec0`'s
`unbound_start_menu.c` hunks reverted (16 tiles leaked per close, the restored offset 3 exceeded
the 6-icon list and A on it opened nothing). `PW_USM_CYCLES` (pass with `--env`) sets the count.
### `SpecialChecklistStress.lua`

The Special Pokémon checklist under real input with 0, 1 and all 7 collected (the collection marks
come from `SpecialPokemon_ReconcileOwned` finding debug-given Pokémon). On each list page the suite
reads every in-use sprite: page 1 must draw four icons and page 2 exactly three, each on its row's y
(36 plus 32 a row, so neighbouring 32-pixel icons never overlap; on #529's 29-pixel rows Balloon
Pikachu's balloons covered the bottom of Surfboard Pikachu's board) with nothing on page 2's fourth
row, and each icon at a lower subpriority than the one below it (#529's draw order). Up on the first entry, Left on page 1, Down on the last entry
and Right on page 2 must clamp; Up from entry 5 crosses back to page 1. Held Down, Up, Right and
Left (key repeat) must run to the ends and stop. B pressed during the opening fade is ignored and a
second B closes; three fast open and close rounds; every detail page with one icon, Right clamped on
the last, B back to the right page, held Left through the details; an A/B mash. Unfixed (29-pixel
rows) **39/51**, fixed **51/51**.
### `SpecialFormsIdentity.lua`

The seven special forms keep their themed types (#528) wherever the game uses them. Six come from
the debug Give menu (the seventh goes to the PC). Each leads a wild battle (`setwildbattle`) against
the next form, and `gBattleMons` must hold the lead's and the wild Pokémon's themed types; Fight
shows the move menu's effectiveness marks (screenshots: Take Down on Pirate Totodile reads immune,
Discharge on Squad Squirtle super effective). Each summary's three pages, each form's Pokédex form
info page (national dex on) and the PC with Pirate Totodile boxed are opened with real input and
screenshotted. `--env PW_ID_ONLY=dex` skips to the Pokédex and PC part. Coverage, no defect found:
**58/58**.

### `RoamerParkRelease.lua`

`ROAMER_COUNT` is 2 and the regions run in either order, so a Hoenn Lati can already roam when
Burned Tower releases Entei and Raikou. 0829014ec0 keeps the Lati and parks the beast that finds
no slot (always Raikou: Entei goes first) until a slot frees. Its release re-ran the League
respawn for both beasts into the first free slot, so defeating Entei brought Entei straight back
with a fresh personality and shiny roll (outside this case a defeated beast returns only at the
Johto Hall of Fame) and Raikou never left. Setup gives a level 100 Arena Trap Dugtrio (a roamer
flees on its first turn and running beats any move), runs the Lati TV special as the Littleroot
scene does, and arms the Burned Tower scene, which then plays on real input. After the Hub and back
only Latias and Entei roam. Entei's EWRAM map is moved onto Route 31 (a roamer's map is re-rolled
on every map change), the Dugtrio walks the grass by the Dark Cave until Entei appears and
defeats it with Earthquake. On the next map load Raikou must roam, Entei must not, the Latias must
be the same Pokemon, and nothing may be duplicated after more loads and the Hub. **12/14** on the
unfixed ROM (Entei back with a new personality, Raikou still parked), **14/14** with the fix.
`test/roamer.c` covers the same release and the League respawn parking a beast with no free slot.

### `EggOnlyStaticRefusal.lua`

0829014ec0 refuses scripted wild battles for an empty or Egg-only party with "You don't have a
single POKéMON" and replaces the encounter script, so the encounter must be left exactly as it
was. Scripts that change state before reaching the battle undo that promise: Ilex Forest's GS
Ball shrine cleared Celebi's hide flag and walked Celebi in, so after the refusal a scriptless
Celebi stood by the shrine and, at Azalea state 9 where nothing re-hides it, came back on every
visit. An Egg is given with `giveegg` and the walks are real input (visible wild Pokemon spawns
are held off in Ilex Forest's one-tile passages). The Power Plant's Electrode 1, refused inside
the battle starter, is the control: no battle, control back, Electrode still there, its flags
clear. At the shrine, answered YES with A and Start mashed: no battle, control back,
`FLAG_HIDE_CELEBI` still set, the event still armed, and after leaving and returning no Celebi
at (24,33). **13/15** on the unfixed ROM, **15/15** with the fix. The same pre-scene refusal
also guards the Southern Island Lati and both Birth Island Deoxys scripts (untested here; their
state resets on a map reload, but the refused scene left the Pokemon standing for the visit).

### `GoldenrodSceneStress.lua`

Coverage for three Goldenrod changes in 0829014ec0, each driven on real input with A, B and Start
mashed through it. The Hub's Johto gate (Zephyr and Hive Badges, Ilex Forest done) lands the
player in the Train Station at `VAR_GOLDENROD_CITY_STATE` 0; walking out of the station's door
must run the city's new ON_FRAME first-visit setup (Elm's PokeNav call, state 1, visited flag,
Rockets and Bill hidden, nobody beside the door) and hand control back, and going back in and
out must play nothing. The Name Rater's TV news, which used to end in a `waitstate` NameRival
never resumed, must hand control back, and its text (read from `gStringVar4`) must name the boy
("His name is GARY") instead of ending on HnS's "Do YOU know his name?" for the removed naming
screen. The Radio Tower quiz won at state 5 (after the Plain Badge) must enable the radio and leave
the state at 5 instead of rewinding it to 2. Unfixed TV text **16/17**, fixed **17/17**.

### `HubPassLeagueRooms.lua`

Coverage for dcd1570afe's Hub Pass refusal in the champion rooms. The Johto Champion's Room is the
one that hands the player control before the champion (Hoenn's and Kanto's walk straight into the
battle on entry), so it is the room where the refusal matters. The pass is given with `additem`,
registered, and fired from Select in the Johto Champion's Room, Karen's Room and Ever Grande's
Hall 4 after each room's entry scene, with A, B and Start pressed through the message: refused,
the player stays on the same tile, and control returns. In the Johto Indigo Plateau Pokemon
Center the same Select reaches the hub (control). **12/12** on the master ROM it was written
against.

### `FrontierSavePowerCut.lua`

A power cut during a Battle Frontier save (`SaveGameFrontier`, `TrySavingData(SAVE_LINK)`). The
link save rewrote the current slot in place, so a cut anywhere in its write tore the newest save
and the next boot fell back to the save before it; near the end of the write no sector of the torn
slot carried a valid signature yet, so the slot read as empty and the main menu did not even say a
save was lost. `SAVE_LINK` now writes the other slot, as `SAVE_NORMAL` does. Each trial saves twice
from the Start menu in the hub with distinct markers (the seventh player-name byte in SaveBlock2,
the registered-item word and the tile in SaveBlock1, the last Johto flag byte in the SaveBlock3
chunk and the last box's wallpaper in the PC), writes a third marking, seeds a paused Battle Tower
challenge the way `tower_save` leaves it and warps into the lobby, where the attendant's
ResumeChallenge script saves. The first trial completes the Frontier save and must load it; the
others cut the power at eight offsets spread over the measured write plus its last frame and must
load the second Start-menu save or the Frontier save, whole. Measured **23/23** fixed and **14/23**
on the unfixed ROM, where all nine cuts (frames 0 to 336 of a 337-frame write) loaded the first
save. `PW_FSP_OFFSETS=<n>` changes the number of spread offsets.

### `SaveWritePowerCut.lua`

A power cut on every frame of a Start-menu save's flash write. Each trial marks four places in
different sectors (the seventh player-name byte in SaveBlock2, the registered-item word and the
tile in SaveBlock1, the last Johto flag byte in the SaveBlock3 chunk and the last box's wallpaper
in the PC), saves, writes the other marking on a neighbouring tile, saves again and cuts the power
when that write has run `off` frames, then boots and Continues. Every marker must come back from
the same save, a new save must load with a clean status, and every eighth trial saves once more
after the recovery and must reboot into that save with a clean status. Coverage: with
`PW_CUT_STEP=1` (and `PW_MAX_FRAMES=1500000`) all 254 offsets of a 252-frame write ran **576/576**:
the cut on frame 0 loads the previous save with status OK, every cut from frame 1 to the last write
frame loads it with the "previous save loaded" status, and only the completed write loads the new
save. The registered default samples every third frame plus the frame after the write and scores
**198/198**. No defect found.

### `HubWardrobeSprite.lua`

The World Transit wardrobe (`OBJ_EVENT_GFX_WARDROBE`, local id 15 at (7,7)) drew only its shadow.
The graphics info has no tile tag, so the frame reaches VRAM only when an animation command sets a
frame, and it used `gDummySpriteAnimTable`, which has none: the object's OBJ tiles stayed blank,
the hub showed bare floor with a stray medium shadow, and a player standing at the wardrobe hid the
shadow, so the wardrobe suites' screens looked right. It now uses `sAnimTable_Inanimate`, like every
other inanimate object. From a fresh hub boot the player walks to (8,8), beside the wardrobe; its
sprite must be active with non-blank tiles that match the start of `gObjectEventPic_Wardrobe`
(added to `GenLuaSymbols.py`). As a control, A at (7,8) facing up opens the outfit picker and B
closes it. Measured **9/9** fixed and **7/9** on the unfixed ROM (both tile checks fail on blank
tiles). `OutfitPickerStress` 18/18, `OutfitTransitionMash` 52/52 and `SmokeBoot` 10/10 pass on the
fixed build.
### `SummaryDexNumberNoDex.lua`

Before the National Pokédex, the summary's info page must print a dex number only for a species in
the current region's dex. Johto has no regional dex here and borrowed the Hoenn order, whose lookup
returns 0 outside that dex, and 0 passed `<= REGIONAL_DEX_COUNT`: a Johto starter showed "000" and a
Zubat its Hoenn number until Elm's Pokédex. The suite gives each Pokémon with the debug Give menu,
warps to a map of the region (the region is map-derived), opens the summary from the Start menu
with real input and counts lit pixels where the number prints in the species window (12 with no
number, over 100 with three digits). Johto (National Park gate): Chikorita and Zubat show no
number. Control: Kanto (Viridian City) Bulbasaur shows its Kanto number. Measured **9/9** fixed and
**7/9** on the unfixed ROM.
### `PokedexAreaAfterBattle.lua`

The Pokédex area page must mark the same places before and after a battle, in Johto as well as
Kanto. The wild-header region index used to be cached on the heap across visits, and battles and
field returns re-init the heap; Johto maps sit in their own map groups, which the old group switch
dropped. With every dex flag set and the Pokédex held, the suite opens the Pokédex from the Start
menu with real input on a Johto map (National Park gate) and reads the area page's species, glow
count and marker count for Pidgey (routes) and Zubat (caves). It wins a wild battle
(`setwildbattle`/`dowildbattle`, Psychic from a level 100 lead) and reads both again, then repeats
for Pidgey in Viridian City. Counts must be non-zero and unchanged. Measured **13/13** on master and
**10/13** with `0829014ec0`'s `pokedex_area_screen.c` hunks reverted (no Johto glow or markers, and
Kanto Pidgey's 13 routes read 0 through the stale index).
### `MultiHalfTeamSummary.lua`

In a half-team multi battle, Summary from the party menu must open the Pokémon under the cursor and
B must return the cursor to it. The party menu draws the player's three in rows 0-2 and the
partner's in rows 3-5, while the summary uses the interleaved order `[P0, Partner0, P1, P2,
Partner1, Partner2]`. The real Rocket HQ multi with Lance runs from its post-selection seam with
three distinct debug-made Pokémon; real input opens POKéMON, then Summary and B on each of the
player's rows. Rows 0, 1, 2 must leave summary indices 0, 2, 3 in `gLastViewedMonIndex` (the
screenshots show Bulbasaur, Charmander, Squirtle) and the party cursor back on the row. Measured
**10/10** on master and **8/10** with the two `0829014ec0` call-site translations reverted (rows 1
and 2 opened indices 1 and 2: Lance's Dragonite and the wrong own Pokémon).
### `SummaryEggPages.lua`

An Egg's summary must not leak what hatching reveals. A shiny Bulbasaur leads (control: star and
friendship heart show) and a shiny Togepi Egg from the debug Give Egg menu follows (shininess set
through the unencrypted `shinyModifier` bit). With real input the suite opens Bulbasaur's summary
from the Start menu's party, scrolls onto the Egg, tries Left and Right, and reads the shiny star
and friendship heart sprites by their fixed positions in `gSprites`; then from each of Bulbasaur's
other pages Down must skip the Egg (the party cursor returns to the lead on close). Measured
**15/15** on master and **11/15** with `0829014ec0`'s Egg checks in `SetShinySprite` and
`SetFriendshipSprite` reverted (star and heart shown on the Egg).
### `LastBallBounceHide.lua`

The BW battle UI's last-used-ball icon must not be recreated after its window hides mid-bounce.
A wild Pidgey battle starts by `setwildbattle`/`dowildbattle` with three ball types in the Bag. At
the action menu, with real input, the suite holds R, taps Right (the cycle bounce starts), releases
R and presses A on FIGHT 0 to 12 frames later, then B back. The in-use sprite count in move
selection must equal a plain A's, and the action menu's count must return to its baseline each
round. Measured **7/7** on master and **6/7** with `0829014ec0`'s `bw_battle_ui.c` hunk reverted
(at 0 and 1 frames an extra ball icon stayed up in move selection).
### `UsmDarkPopupIcons.lua`

The graphical Start menu opened in a dark place while the map-name pop-up is still up must show its
icons. In Flash caves and the Battle Pyramid the icons draw through the OBJ window
(`DISPCNT_OBJWIN_ON` plus `WINOUT_WINOBJ_OBJ`), and `Usm_InitStartMenu` called
`HideMapNamePopUpWindow` after setting them; hiding a GEN_8 pop-up rewrites WINOUT to the field
default, so only the banner and label showed. The suite warps into Dark Cave, presses Start with
real input while the arrival pop-up task runs, reads `REG_WINOUT` and screenshots the menu.
Control: the same after the pop-up has gone. Measured **7/7** fixed and **6/7** on the unfixed ROM.
The Pyramid shows the same on its first floor (its "Floor" pop-up is up when control returns).
Since `DarkPopupDarkness.lua` dark places start no pop-up, so the suite now requires none on arrival
and the menu opened right after the arrival must still show its icons.

### `DarkPopupDarkness.lua`

A GEN_8 map-name pop-up clips its slide with WIN0 and sets WINOUT to show BG1-3 and sprites outside
it. In a dark place the light circle owns WIN0 through a per-scanline effect, so the banner never
showed and the whole dark map was lit (WINOUT `0x001E` instead of `0x0101`) for the three seconds the
pop-up ran. `ShowMapNamePopup` now starts no GEN_8 pop-up when the flash level is above 0 or on a
Battle Pyramid floor. With real input the player climbs down Granite Cave B1F's ladder into dark
B2F (stepping off the ladder to the side a wandering Pokémon leaves free); for 200 frames no pop-up
task may run and WINOUT must keep BG1-3 out. Control: a debug warp onto lit Route 106 still starts
the pop-up. Unfixed **5/7** (186 of 200 frames lit), fixed **7/7**.
### `PyramidRestUsm.lua`

Rest in the Battle Pyramid from the graphical Start menu must quit to the title like the classic
menu's Rest. The suite gives six Pokémon, takes the real Lv. 50 Pyramid challenge at the lobby
attendant with real input, waits for control on floor 1 (field locks, not a step probe: the floor
is dark and walled), picks Rest and answers Yes. The game must not hand control back on the floor,
and Continue must load the Rest save and resume on the floor with the three chosen Pokémon.
Measured **13/13** on master and **11/13** with `0829014ec0`'s `save_dialog.c` hunk reverted (after
Rest the player walked on the floor holding all six Pokémon).
### `BugContestPartyLock.lua`

While the Bug-Catching Contest parks the team, the party menu must not open the PC (R, Boxes) or
offer the lead's held-item, Follow and Nickname rows, which the contest's end would undo or double.
The suite gives a team, enters the contest through the real attendant, opens the party from the
Start menu, presses R, and counts the lead's action rows through `sMenu` (Summary and Cancel only).
Control: after retiring at the exit, the same R opens the PC. Measured **8/8** on master and **6/8**
with `0829014ec0`'s contest gates reverted (the PC opened and the lead had five rows).

### `EggSummaryPageTabs.lua`

An Egg's summary cannot turn pages (`ChangePage` returns for an Egg), but its header still drew the
four page tabs and both page arrows. The suite gives a debug party and a debug Egg, opens the Egg's
summary from the party menu with real input and reads BG2's screen block in VRAM: header rows 1 and 2,
columns 0 to 9, must all be the plain header tile 0x33. Right and Left must leave the Egg on its page
with the header still plain; Up to the Pokémon above must bring the tabs back (tile 0x01 at column 1,
the control) and Down to the Egg must clear them again. Unfixed **3/7**, fixed **7/7**.

### `NewGameOverSave.lua`

New Game over a played save, without a power cycle. A fresh new game is dumped twice (the second
after a soft reset and 173 extra title frames, so the RNG-drawn bytes differ). The second file is
then played: two Pokemon, money, items, three badges, Shared Exp, a non-default outfit, every
Pokedex flag, the opening flags of all three regions and a real World Transit gate crossing into
Johto, saved from the Start menu. After a soft reset the title menu's NEW GAME (read from the main
menu task's cursor) starts over that loaded save. SaveBlock1, SaveBlock2, SaveBlock3 and the PC are
compared bit by bit, with money, coins, game stats, Berry Powder and bag quantities decrypted first
(the key rerolls on every map load; `gameStats` and `berryPowder` were added to
`GenLuaSymbols.py`, with a `load_save.c` pin for the first). A bit leaks when both fresh games agree
on it, the played file changed it and the new game still holds the played value. Kept by design
and masked: the name and gender, the title-menu options, the RTC offset and berry clock, the region
checksum (restamped by every save) and the Shared Exp flag. The new game must also have an empty
party, 3000 money, no region, the intro's outfit and a free field. Measured **19/19**; no defect
found. A tamper build that skips the `johtoIntroDone` reset in `NewGameInitData` scores **18/19**.

### `EggOnlyIslandLegends.lua`

The Southern Island Lati and both Birth Island Deoxys scenes (Hoenn's, and Kanto's reached by the
Seagallop) with an Egg as the whole party, on real input. Each Birth Island puzzle is solved rock by
rock with real steps inside every rock's step limit; Southern Island is the sign under the Eon
stone. The refusal must print "You don't have a single POKéMON", start no battle, leave no
legendary object, keep the map's music (Birth Island is MUS_NONE) and free the field. A level 100
Mewtwo then joins on the same visit, as when the Egg hatches there, and the scene must play: the
Lati battle and the Deoxys battle start, and RUN leaves each. `DoDeoxysRockInteraction` marks the
puzzle complete before the script's party check, so the refused stone answered nothing for the rest
of the visit. Measured **35/35** fixed and **31/33** on the unfixed ROM (both Deoxys replays fail with
`FLAG_DEOXYS_ROCK_COMPLETE` still set).

### `BirthIslandRockReset.lua`

Leaving Birth Island mid-puzzle must start the Deoxys puzzle over on the next visit. With a real
Pokemon in the party the player walks in from the harbor, touches the stone once (level 1), walks
out to the harbor and back in. `VAR_DEOXYS_ROCK_LEVEL` and `VAR_DEOXYS_ROCK_STEP_COUNT` must read 0
and the first touch of the new visit must climb to level 1. Kanto's Birth Island script reset FRLG's
rebased `VAR_DEOXYS_INTERACTION_*` copies, which nothing reads, so the stone kept its old level and
the first touch failed on the steps walked since. Hoenn's island is the control. Measured **23/23**
fixed and **20/23** on the unfixed ROM.

### `BirthIslandRockPalette.lua`

The Deoxys puzzle stone's colours on both Birth Islands. With a real Pokemon in the party the
player touches the stone, follows it to its second tile and touches it again, then opens and
closes the party menu (the map's return-to-field reload). The stone sprite's unfaded palette, read
through its OAM slot, must hold each level's colours: Kanto's from `meteorite.pal` and
`graphics/field_specials/deoxys_rock_N.pal`, Hoenn's from `field_effects/palettes`. The 32 bytes that
palette slot 0xFF addresses past each palette buffer are set to a sentinel around every action and
must survive. With `FLAG_BATTLED_DEOXYS` or `FLAG_FOUGHT_DEOXYS` set the stone is hidden, and a party
menu round trip there must stay in bounds too. The rock code looked up Hoenn's palette tag on Kanto's
island (it uses the meteorite tag), got 0xFF, never recoloured the stone and wrote each palette into
`sSpeciesPreEvolution`; the hidden stone did the same on both islands. Measured **35/35** fixed and
**28/35** on the unfixed ROM.
### `CyclingRoadSaveContinue.lua`

Kanto's Cycling Road on real input. With a Bicycle registered and every Kanto trainer already
beaten (the road's bikers would otherwise cut the ride short), the player walks across the Route 16
gate on foot, and the gate's warp puts them on the bike with `MUS_RG_CYCLING`. Select must answer
"You can't dismount your BIKE here." and leave the player on the bike, as on Route 110 and in FRLG:
the Bicycle's use checked only Route 110's `FLAG_SYS_CYCLING_ROAD`, never Kanto's
`FLAG_SYS_ON_CYCLING_ROAD`. The bike then rides onto Route 17, the slope carries it down (Start is
ignored while it does), the game is saved at the foot, soft reset and continued: same tile, still on
the bike, the same music, control back. The Hub Pass then leaves the road, and Fly's reset must clear
`FLAG_SYS_ON_CYCLING_ROAD` so the player can get off the bike elsewhere (also cleared now after
Teleport, Dig, Escape Rope and a whiteout). Measured **16/16** fixed and **14/16** on the unfixed ROM.
### `PokenavRegionNames.lua`

The PokéNav's map option, its help line and the region map's left header said HOENN MAP in every
region. They now name the region the map shows (`GetCurrentRegion()`, as `region_map.c` picks the
map): JOHTO MAP and KANTO MAP labels are drawn from the Hoenn art by
`tools/pokenav/region_map_labels.py` and appended to the options sheet. With the PokéNav flag set,
the suite opens the PokéNav from the Start menu with real input on Route 106, in Goldenrod City and
in Pallet Town and reads the map option's sprite tile relative to the Condition option's (Hoenn
0x000, Johto 0x1A0, Kanto 0x1C0); it screenshots the menu with its help line and the full and zoomed
maps with their headers. Unfixed **10/12** (Johto and Kanto read 0x000), fixed **12/12**.
### `HealMigrationContinue.lua`

The Azalea, Goldenrod and Safari Zone Gate heal points moved off the Center door onto the apron
after save format v9 shipped, and `MigrateMovedHealLocations` re-points a stored door tile on load.
Each case writes the old door coordinate into `lastHealLocation` and an older `saveVersion` (9, 10,
11 or 12), saves from the Start menu, soft resets and continues, so the repair runs on the real load
path. It then loses a debug battle: the whiteout must run the nurse's cutscene inside that Center,
not drop the player on the door outside, and control must return. Version 12 is a save written by a
build between the v12 bump and the repair. Measured **121/121** fixed and **115/121** on the unfixed
ROM, where the repair ran only below v12 and all three v12 cases whited out onto the door.
`--env PW_HEAL_ONLY=<text>` runs matching cases (`azalea`, `v12`).
### `LittleCupRules.lua`

The Battle Net Little Cup room at the Hub 2F streak attendant, with real input. Each case builds a
party (script `createmon` at a level, or the debug Give Egg), talks to the attendant and picks
LITTLE CUP. A refusal must print the Little Cup rule (read from `gStringVar4`) and return to the
menu with the party and BP untouched; an accepted party must start a sim battle against three level
5 opponents, and a win (forced through `gBattleOutcome`) must print the award line and pay 2 BP.
Accepted: Bulbasaur, Pichu, Azurill and Eevee at level 5, and an Egg with a level 5 Bulbasaur.
Refused: Bulbasaur at 4 and 6, Ivysaur, Pikachu, Chansey, Roselia, Marill and Ditto at 5, a
Flower Crown Eevee (a special form that cannot evolve), Bulbasaur with Ivysaur, and an Egg alone.
Measured **82/82**, and **74/82** with `0829014ec0`'s `BnetMarkPreEvos` bound reverted to #386,
where Chansey (Happiny) and Roselia (Budew) were let in and won BP. `--env PW_LC_ONLY=<text>` runs
matching cases.
### `BugContestDayChange.lua`

The Bug-Catching Contest's once-a-day limit and clock across day changes, on the emulator's running
RTC. The suite sets the clock the way New Bark's wall clock does (`FLAG_SYS_CLOCK_SET`, `VAR_DAYS`
and a local time of 23:38 through `localTimeOffset`), then plays three contests through the real
attendant: one retired with a catch before midnight; one after saving in the gate, waiting there
until the RTC passes midnight and continuing the pre-midnight save; and one started at 23:57 on a
clock wound two days on, so midnight rolls over while it runs. The last two walk until "Time's up",
which must ring at 8 minutes of frames. Each contest must return the parked party unchanged, put
one prize in the bag, take the Safari Balls, set the day's flag and leave the attendant refusing a
second contest; Continue on the new day must clear the flag and record the day. Measured **37/37**,
and **9/13** with `0829014ec0`'s `setflag FLAG_DAILY_BUG_CONTEST_COMPLETED` removed (a second
contest started the same day). The catch is a debug-given Weedle inside the contest.
### `FrontierLobbyContinue.lua`

Save and Continue inside the seven Battle Frontier lobbies, the Fallarbor, Verdanturf and Slateport
Battle Tents and the Trainer Tower lobby, plus a soft reset inside the Hoenn Safari Zone. Each lobby
case walks in from the door with a debug Set Party follower out, saves from the Start menu, soft
resets and continues; the map, tile and facing, the playing song (`gMPlayInfo_BGM` against
`gSongTable`), the follower (shown beside the player) and control must come back as they were, and
the player must walk. The Safari case saves in the entrance, enters through the attendant (a
Pokeblock case is put in the bag), walks until the step counter moves, requires that the Safari
Start menu offers no SAVE, then soft resets: Continue must land on the entrance save with Safari mode
off and no Safari Balls. Measured **111/111**; no defect found. `--env PW_LOBBY_ONLY=<text>` runs
matching cases.
### `MoneyCapPayouts.lua`

Money payouts at the 999,999 cap that `EconomyStress` and `MoneySinkEdges` do not reach. The Lake
of Rage fisherman (after the Rocket event; talk, Yes and the party pick are real input) pays 100,000
for a level 100 Magikarp and 2,000 for a smaller one: from 950,000 the big payout must stop at
999,999, and at 999,999 both must leave it there, with the money box drawing all six digits
(screenshots). Pay Day with an Amulet Coin, the pot seeded to 40,000 after the battle starts, from
999,000 and from 999,999: the wallet must end at 999,999 and the line must print the doubled
81,000, as trainer prize lines print the prize at the cap. Measured **28/28**; no defect found.
### `JohtoGiftReceipts.lua`

The pokemonHnS port replaced HnS's `Common_EventScript_GiftMon` / `GiftMonNamed` calls with only the
full-party branch at six Johto gifts, so Bill's Eevee, Kirk's Shuckie, Randy's Kenya and the Dragon's
Den elder's Dratini joined the party with no fanfare and no "received" line, and the Karate King's
Tyrogue and the elder's basic Dratini went to a PC box without a word when the party was full. With
real input the suite talks to each giver (YES to the offer, NO to the nickname question) and records
every line the game prints into `gStringVar4`: the four party-room gifts must print "received" and
grow the party; then, with a full party of six, Kiyo (after `FLAG_BEAT_KIYO`) and the elder (after a
quiz with a wrong answer) must print "received" and the "transferred to" PC notice, and the Pokemon
must be in box 1. **23/30** on the unfixed ROM, **30/30** with the fix. `AuditCapacity.py` now also
flags a `givemon` whose box outcome reaches no PC notice (it named exactly Tyrogue and the basic
Dratini before the fix).

### `BattleXItemBenchLead.lua`

X items and Dire Hit from the in-battle Bag in a single battle must work on the Pokemon on the field
whichever party slot it came from. Each case builds a party with createmon, starts a wild Magikarp
battle (`setwildbattle` + `dowildbattle`) and uses the item with real input: BAG, A on the item, A on
USE. The field Pokemon's stat stage must rise (Dire Hit: the Bag must accept and spend it) and one
item must leave the Bag. Cases: the lead in slot 0 (control); slots 0 and 1 fainted so slot 2 leads,
as a lost fight leaves the party (X Attack, X Speed, Dire Hit); and a real in-battle switch to slot 4
(POKEMON, Shift) before the item. Before the fix `ItemUseInBattle_BagMenu` set `gPartyMenu.slotId` to
the party index, which `CannotUseItemsInBattle` reads as the field slot, so every stat item was
refused with "It won't have any effect." for a Pokemon from slot 2 or later: **35/46** on the
unfixed ROM, **46/46** with the fix.

### `TrainerDoubleBallRefund.lua`

Cancelling the left Pokemon's Bag choice with B on the right Pokemon's action menu must give back
only what the Bag took. A trainer double comes from the debug Trainers menu (Trainer 1 + Trainer 2,
one Pokemon each) with two createmon Mewtwo. Turn 1 is real input (Psychic and Splash) so one foe
faints and a ball may be thrown. Then three rounds of BAG, Balls pocket, Poke Ball, USE, and B on the
right Pokemon's menu: the ball count must not change. Controls: a Potion on the hurt left Pokemon is
taken and the cancel gives it back, and a ball thrown for real is blocked by the trainer and stays in
the Bag. Before the fix the refund in `HandleInputChooseAction` added any consumable item back, but a
ball aimed at a trainer's Pokemon is never taken (`B_TRY_CATCH_TRAINER_BALL`), so each round made a
ball (Master Balls too): **26/27** on the unfixed ROM (10 balls became 11, 12, 13), **27/27** with
the fix. `IsBattleItemTakenFromBag` (`src/item_use.c`) is now the one rule for taking and refunding.
### `AlphFossilLab.lua`

The Ruins of Alph lab came from pokemonHnS reading and writing Hoenn's `VAR_FOSSIL_RESURRECTION_STATE`
and `VAR_WHICH_FOSSIL_REVIVED`, so the two regions shared one regenerator. A Helix Fossil handed in at
Alph left Devon's fossil scientist mute (his script knows only Lileep and Anorith and fell through to
`end`), and a Root Fossil handed in at Devon came back as a Lileep from the Johto researcher. With
real input the suite hands a Helix Fossil in at Alph, talks to Devon's scientist (greeting, nothing
handed out), collects the Omanyte at Alph, hands a Root Fossil in at Devon, checks the Alph researcher
greets and hands out nothing, and collects the Lileep at Devon. Last, a Kabuto pending in the shared
pair (the only form a save from before the split can hold) must come back at Alph. **20/24** on the
unfixed ROM, **24/24** with the fix.

### `StarterIndexPerRegion.lua`

Oak's lab, Elm's lab and Birch's bag all wrote one shared `VAR_STARTER_MON`, and each region's rival
scripts read it, so a starter chosen in a second region changed the first region's rival team. The
suite takes Charmander in Oak's lab (Blue takes the Squirtle ball in front of the player), leaves by
Hub Pass before Blue's lab battle, plays Elm's intro and takes Cyndaquil, then crosses back: the
Kanto gate returns to the lab and Blue's trigger starts the battle. **Oracle:** the lead of Blue's
battle party (`gParties[B_TRAINER_OPPONENT_A][0]`, decrypted) is Squirtle (7). Setup is two debug
warps (Pallet Town, Elm's lab); the gate crossings, Oak's trigger, Elm's intro, both ball picks, the
Hub Pass and Blue's trigger are real input. **Discrimination:** unfixed 21/22 (Blue leads with
Bulbasaur, the team for a Squirtle player, because the Cyndaquil pick wrote 1), fixed 22/22.
### `TrainerCardRegionPages.lua`

The Trainer Card's front badge row pages through Hoenn, Kanto and Johto. The badge flags are written
where the gym scripts leave them (Hoenn system flags, the Kanto bank in SaveBlock1, the Johto bank in
SaveBlock3); the card is opened from the Start menu and paged with real L, R and Down presses, plus
an R R L mash two frames apart, then flipped to the back and closed. Seven scenarios: no badges, some,
a mix (all Hoenn, no Kanto, two Johto) and all, from the Hub; and one badge set opened in Viridian
City, Cherrygrove City and Slateport City, where the card must open on that region's page.
**Oracle:** the BG3 tilemap in VRAM (screen base 31), where badge i sits at (4 + 3i, 15) as tiles
192 + 2i, 193 + 2i and 208 + 2i and an empty slot holds tile 0, must match that page's flags.
Measured **69/69**; no defect found. Screenshots of every page were checked by eye: each label reads
HOENN, KANTO or JOHTO between the L and R icons and each page draws its own region's badge art.

### `BagSortTwoItems.lua`

A Bag pocket with two stacks must offer to sort them. Super Potion and Potion (out of name order) are
the Items pocket; the real Bag opens from the start menu and START is pressed. The sort menu must
come up, A on "name" must put Potion first, and both quantities must be kept. A one-stack pocket must
still print "There's nothing to sort!". Before the fix the START handler in `Task_BagMenu_HandleInput`
refused when `numItemStacks - 1 <= 1`, counting a Close Bag row this Bag never shows
(`hideCloseBagText` is set at every open), so two stacks were refused like one: **6/8** on the
unfixed ROM, **8/8** with the fix. `BagSortChord` stays 6/6.
### `RelearnerDeclineHeartScale.lua`

Declining a move at the Move Relearner's "Teach X?" prompt took the Heart Scale anyway. Every
relearner script runs `Special_HasMoveToRelearn` first, which leaves `VAR_RESULT` TRUE, and
`LearnMove`'s No/B branch at the confirmation prompt (`src/chooseboxmon.c`) returned without
clearing it, so the relearner closed as if a move was learned and the script printed "handed over
one HEART SCALE" and removed it. With real input in the Fallarbor relearner's house the suite says
YES, picks the debug Wobbuffet in the storage chooser, answers NO (cursor-verified) and then B at the
prompt for Safeguard, and gives up from the list. The list must stay open after each decline, the
Heart Scale must stay in the bag and the Wobbuffet's bytes must not change. Measured **9/13** on the
unfixed ROM, **13/13** with the fix.

### `SinglesBattleMashStress.lua`

Single battles, and a trainer double, mashed with a Bag that has something in every pocket
(X Attack, Dire Hit, Potion, Revive, Ether, Full Heal, Poke Doll, Poke and Great Balls, Oran Berry, a
TM). The party is three createmon Machop (Guts, so no Pickup items), an Egg and a fainted Machop.
Battles: wild Magikarp at Instant and at Slow text, wild Magikarp with the party and all PC boxes
full, the debug single trainer and the debug trainer double, twice each with fresh seeds. A seeded
mash of A, B, Start, L, R and the D-pad (never Select) runs, then a finisher wins or runs (it backs
out of the Bag, answers Bag messages, and confirms the nickname screen). After each battle: no crash
screen, the field and control are back, every party slot decrypts with a valid checksum, no Egg was
ever on the field, the PC/party census gained no duplicate personality, nothing was caught with the
party and boxes full, and no item quantity grew. Measured **82/82** with the default seed and with
`PW_SMASH_SEED=0xA11CE` and `0xBEEF7`; the mash found the two-stack sort refusal fixed in
`BagSortTwoItems`. `PW_SMASH_SEED=<n>` reseeds, `PW_SMASH_ONLY=<text>` runs matching scenarios and
`PW_SMASH_SAVE=<dir>` keeps a savestate of a battle that does not end.
### `JohtoPlaceNames.lua`

Three Johto lines named Hoenn places. Goldenrod Game Corner's coin clerk runs Mauville's script and
greeted "This is MAUVILLE GAME CORNER.", the Johto Safari Zone gate's welcome attendant runs Route
121's and promised Pokemon "rarely seen in HOENN.", and Johto Victory Road's Owen said the tough kid
"is from PETALBURG CITY." pokemonHnS had reworded the first two in its copies; the merge kept
Emerald's. With real input (a Lapras in the party, Owen's defeat flag set as the battle leaves it) the
suite talks to all three and reads the printed line: no Hoenn name, and the Johto one in its place.
**6/12** on the unfixed ROM, **12/12** with the fix. `ValidateRegionText.py` (in `make validate`) now
reads every string a Johto map can reach and failed on exactly these three.
### `SecretBaseMoveStress.lua`

Secret Power on all three Hoenn entrance types and moving the base twice, which no suite touched.
With every decoration given (an `adddecoration` script per id) and Secret Power written into the
debug Wobbuffet's last slot, the suite makes a base in the Route 116 blue cave, opens its PC and the
Decorate category list, then moves to the Route 110 tree and the Route 119 shrub. Each move must
name the route of the base being left ("near ROUTE 116", then "near ROUTE 110"), land in the right
base map in front of its PC (25/2, 25/16, 25/17), and the live map grid must show the Route 116
indent open while the base is there and closed after the move, and the Route 110 vines gone. Talks,
YES answers and the PC menus are real input; the warps are debug warps. Coverage, no defect found:
**23/23**.
### `SeafoamCurrents.lua`

Seafoam Islands' falls and currents (FRLG), which no campaign beat or suite reached before. The
player passes Route 20 (whose map script resets the boulder puzzle), then each case writes only the
boulder hide flags the falls leave and warps next to a hole; the step into the hole and everything
after it are real input and the maps' own scripts, with a seeded mash of every button but the
soft-reset chord through each fall and ride (`PW_SEAFOAM_SEED=<n>`). **B2F hole, current running:**
the fall lands on B3F water and the current carries the player into B4F on Surf, where control
returns in the east pool. **B2F hole, both B3F boulders in:** B3F records the stopped current and
the player stays afloat with control. **B3F hole, current running:** the B4F current carries the
player to the stairs and puts them ashore. **B3F hole, both B4F boulders in:** B4F records the
stopped current and the player stays afloat. Measured **19/19** with seeds 7 and 99; no defect found.
### `WorldChampionshipFinal.lua`

The World Championship must end with RED in the final. `InitDomeTrainers` swaps RED into the bracket
slot opposite the player, but the NPC matches between the player's battles scored RED like any
other trainer, so he could fall in round 2 or the semifinal and the player won the championship
without meeting him. A three-region champion takes the championship from the registrar with real
input three times (each run starts a different number of frames after one savestate, so the match
rolls differ), wins each Dome battle (opponents held at 1 HP), and reads the bracket
(`frontier.domeTrainers`, 4-byte entries) at every battle start: RED must never be knocked out and
the fourth battle must leave RED as the only other trainer standing. The win must set
`FLAG_WORLD_CHAMPION` and clear `VAR_WORLD_CHAMPIONSHIP_MODE`. Measured **26/26** fixed and
**20/26** on the unfixed ROM (RED out in round 2, 2 and 3 of the three runs).
### `StoryMapIslandTitles.lua`

The Kanto islands were renamed the ORANGE ISLANDS in every player-facing string (b1af7bc9a3), but
the Story destination map still titled their three regional maps "Sevii 1-3", "Sevii 4-5" and
"Sevii 6-7". The suite writes Celio's quest state the way his scripts leave it (scene 4, scene 5,
and scene 5 with Icefall Cave's back room done), so the optional Kanto objective pins Kindle Road,
Four Island and Ruin Valley, and opens Story, its optional page and the map with real input.
**Oracle:** with the map on screen, the title for that island map (`sTitles` indexed by its
`enum RegionMapType`) names the Orange Islands and the island range, and never "Sevii"; each map is
screenshot. **Discrimination:** unfixed 6/9 (`title=Sevii 1-3`, `Sevii 4-5`, `Sevii 6-7`), fixed 9/9.
### `FrontierIneligibleText.lua`

The Battle Frontier lobby refusal must spell "ineligible". `CheckPartyIneligibility` builds the end
of every lobby attendant's "not enough eligible Pokemon" message in `gStringVar1` from two strings
that read "inelegible". Two parties are refused at the Battle Arena attendant with real input
(Challenge, Lv. 50), each from the same post-boot savestate: Mewtwo, Lugia and a duplicate pair
(the "species you caught are ineligible" sentence) and two duplicate pairs (the short "are
ineligible" ending). `gStringVar1` is poisoned before the level choice and decoded while the refusal
is on screen. Measured **13/13** fixed and **9/13** on the unfixed ROM.
### `GoldenrodPrizeClerk.lua`

Goldenrod Game Corner's Pokemon prize clerk, which no suite drove. Without a Coin Case she ran
Mauville's coin-desk refusal ("Okay, you wanted some COINS for the games?..."), while her own
"Oh? You don't have a COIN CASE." sat unused. With real input the suite asks her with no Coin Case,
then with one: 0 and 119 coins must refuse Abra and keep the coins, exactly 120 must buy it, a NO at
"is what you want?" must charge nothing, and with a full party a Dratini must cost 5,500 and go to
box 1 with the PC notice. **28/30** on the unfixed ROM, **30/30** with the fix.
### `HofSharedCap.lua`

The Hall of Fame records are one save buffer that two induction screens and two PC viewers share:
Hoenn and Johto champions go through `hall_of_fame.c`, Kanto champions through
`hall_of_fame_frlg.c`, and the PC viewer is the Kanto one in Kanto and the Emerald one elsewhere.
The files capped the buffer at 30 and 50 teams, so past 30 records a Hoenn induction dropped the
oldest team and wrote at index 29, ahead of the later Kanto teams, and the two viewers opened on
different "latest" teams. Every record is made by a real induction: the suite warps onto each Hall
of Fame room's arrival tile, the room's script runs the induction, the screen saves and soft
resets, and Continue returns to the field; the lead's level is set to the induction number first so
each record names its place in the order. After 32 Kanto inductions and one Hoenn induction it
opens HALL OF FAME at the Viridian and Oldale Center PCs with real input, then inducts in Kanto
once more and opens the Oldale viewer again. Each viewer must open on the latest induction and the
loaded records must be every induction, oldest first (screenshots of each first page). Unfixed
**48/53** (the Kanto viewer opens on Lv32 under "No. 33", the records read `2..30,33,31,32`, and
after the next Kanto induction the Hoenn viewer still opens on Lv33), fixed **53/53**.
### `CeladonSlotsPrizes.lua`

The Celadon Game Corner's slot machines and Pokemon prize counter at their coin edges; no suite had
played a slot machine. The Coin Case comes from the real restaurant NPC and only the coin balance
(and, for the last prize case, the party and boxes) is seeded; machines, prompts and counters are
real input. **Slots:** no coins (betting refused, "run out of COINS"), exactly 3 (one max bet and
three stops), 9,998 (a one-coin bet), a full case (the machine refuses to start) and a seeded mash of
every button but the soft-reset chord (`PW_SLOTS_SEED=<n>`); each must hand control back with a
balance from 0 to 9,999, unchanged where no spin happened. **Prizes:** Abra one coin short (refused,
coins kept), exactly 180 (Abra joins, 0 coins), a full party (Abra goes to a box, coins paid) and a
full party with every box full (refused, coins kept). Measured **36/36** with seeds 11 and 4242; no
defect found.
### `AlphSlidingPuzzles.lua`

The Ruins of Alph's four sliding puzzles and the Kabuto reward chamber, which no suite drove. Setup
sets the four B1F item hide flags as Violet City's first-visit heap does. For each chamber the suite
reads the sign and, on the puzzle screen, moves the cursor, picks up, rotates (R) and places tiles
with real input until `sSlidingPuzzle` reads solved, then presses A. The completion flag must be set,
the floor must drop the player to B1F on the same tile, and the reward (Dome Fossil, Helix Fossil, Old
Amber, GS Ball) must stand one tile north and go into the bag on A. Before the Kabuto solve, B with a
tile in hand must return control with the flag clear and a fresh board on the next visit, and the
Kabuto drop must show B1F's "strange presence" line. Last, the Kabuto chamber's sensor must refuse a
Lapras lead and react to a Kabuto lead (swapped to the front in RAM), and its door must lead into the
reward room. Measured **40/40**; no defect found.
### `CapeBrinkUltimateMoves.lua`

The Cape Brink tutor offers a fully friendly Venusaur, Charizard or Blastoise its ultimate move. The
move is chosen in C (`CapeBrinkGetMoveToTeachLeadPokemon`), and `tools/learnset_helpers/make_tutors.py`
only reads `setvar VAR_0x8005, MOVE_*` from scripts, so Frenzy Plant, Blast Burn and Hydro Cannon were
never tutor moves, no teachable learnset held them, and the party menu showed the starter NOT ABLE
("Buffie and Frenzy Plant are not compatible"). They are now listed in `extraTutors`
(`src/data/pokemon/special_movesets.json`), the helper's input for tutors defined outside scripts.
The suite turns the debug party's lead into each starter at 255 friendship with three moves, then
the talk, both Yes answers and the party pick are real input. **Oracle:** the lead knows the
ultimate move afterwards and the tutor's flag is set. **Discrimination:** unfixed 3/12 (all three
refused as not compatible), fixed 12/12.
### `OddSaveSpots.lua`

Save and Continue on spots `ContinueOddMoments`, `TravelSaveContinue` and `CyclingRoadSaveContinue`
do not stand on: the middle of Route 119's bridge over the river, on foot (soft reset) and riding
the Mach Bike with the cycling music playing (power cut); Cianwood City in the rain; and the
Sootopolis Gym's first ice field with three tiles cracked. Each case walks there with real input
from a debug warp onto a door (the Route 119 Aqua grunts and rival are hidden, as after the
Weather Institute), saves from the Start menu, and continues. The map, tile, facing, the player's
elevation (4 on the bridge) and avatar flags, the playing song, the weather, the follower, the
cracked ice metatiles and the `VAR_TEMP_8`..`A` ice rows must come back, and the player must move
on: off the bridge both ways but not down into the river, riding across and dismounting, and onto
the next ice tile. Measured **57/57**; no defect found. `--env PW_OSS_ONLY=<text>` runs matching
cases.
### `TrickHouseRewards.lua`

The Trick House loop for all eight levels. Each level walks in from Route 110, finds the Trick
Master at that level's hiding spot (desk, tree, dresser, window, planter, cupboard, window,
cushion) with real input, watches him leave, opens the scroll door and enters that level's puzzle
room. The puzzle itself is skipped by warping onto the end room's arrival tile; the Trick Master is
talked to for the reward, and the player walks out through the corridor and the front door, so
every entrance state comes from the game's own scripts. Level 1 is taken with a full Items pocket:
the Rare Candy must wait (`VAR_TRICK_HOUSE_PRIZE_PICKUP`) and the Trick Master must hand it over at
the entrance once there is room. Level 8 takes the RED TENT. Measured **89/89**; no defect found.
### `MirageTowerCollapse.lua`

Mirage Tower's collapse with a follower out. The player talks to the Root Fossil on 4F, answers
YES and mashes A/B through the ceiling crumble, the warp to Route 111, the fall, the tower's
disintegration and the fossil message. The fossil must be in the bag, the fossil flags and
`VAR_MIRAGE_TOWER_STATE` must advance, the player must land on (19,59) with control, the follower
must never stand visible while the player is hidden and must come back beside them after a step,
and re-entering Route 111 must leave the tower gone (state 3). Measured **14/14**; no defect found.
### `HoennRegiPuzzles.lua`

The Regi chain with real input. The Sealed Chamber's back wall is read with the wrong party order
(nothing opens) and then with Wailord first and Relicanth last (the tombs open). In the Desert
Ruins Rock Smash, and in the Ancient Tomb Flash, is picked from the field party menu, first one
tile off the braille spot (nothing opens) and then on it (the inner wall opens). The player walks
through, talks to the Regi and runs from the battle by reading the action cursor: the Regi must fly
away with its defeated flag clear and be back when the tomb is entered again. Measured **28/28**;
no defect found.
### `AbandonedShipScanner.lua`

The Abandoned Ship's Storage Key and Capt. Stern's Scanner trade. The storage door is tried
without the key and then with it: the key is used up, the door stays unlocked after the map
reloads, and the player walks into the storage room. At the Slateport harbor Stern is offered the
Scanner with a full Items pocket (refused, Scanner kept), then with room (DEEP SEA TOOTH received,
Scanner gone), then talked to again (nothing traded twice). Measured **13/13**; no defect found.
### `CinnabarFossilNeedsFossil.lua`

The Cinnabar Lab scientist must revive only a fossil the player still carries. `I_KEY_FOSSILS` is
`GEN_LATEST`, so the Helix Fossil, Dome Fossil and Old Amber are Items-pocket goods a mart buys, and
the Ruins of Alph lab revives them from the bag. The Cinnabar script came from pokefirered and chose
what to offer from Mt. Moon's and the Pewter Museum's "got it" flags, so a sold fossil (or one
already revived at Alph) was still offered, `removeitem` failed silently and the Pokemon came back
anyway. The suite seeds Mt. Moon's result (an injected `setflag FLAG_GOT_HELIX_FOSSIL` and `additem`),
sells the fossil at the Cinnabar Mart with real input, then asks the scientist, leaves the room and
asks again. **Oracle:** no revival starts (revive state 0), `FLAG_REVIVED_HELIX` stays clear and the
party stays empty. Control: an Old Amber in the bag is still taken, and after the leave-and-return
Aerodactyl joins. The scientist wanders, so the suite talks to him only when he stands next to the
player (his object, local id 2, not the follower). **Discrimination:** unfixed 18/20 (revive state 1;
party 0 -> 1 with `FLAG_REVIVED_HELIX` set), fixed 20/20.
### `PcOwnerName.lua`

The storage PC's owner name in all three regions. Each region keeps its source game's owner and
unlock: Lanette in Hoenn (`FLAG_SYS_PC_LANETTE`), Bill in Johto (`FLAG_SYS_PC_BILL`, set when he
leaves the Ecruteak Pokemon Center) and Bill in Kanto (FireRed names his PC in the script that hands
over the S.S. Ticket, so `FLAG_GOT_SS_TICKET`). Every unlock is the region's own script with real
input: Ecruteak Bill, Sea Cottage Bill (with the flags the cell separator cutscene leaves) and
Lanette in her house. At Pokemon Center PCs in all three regions, before and after each unlock, the
menu is opened with real input, "Accessed ...'s PC." is read from `gStringVar4`, and the menu's first
row is fingerprinted from the window tile data; each name must keep one fingerprint. With a full
party, the Celadon Eevee gift line (`gStringVar4`) and a Master Ball catch of a wild Pidgey (battle
text) must name Bill's PC. Measured **28/28**, and **21/28** before the fix: Johto said SOMEONE'S
PC after Bill, Kanto's Bill set Lanette's flag so Hoenn said LANETTE'S PC, the Kanto gift said
LANETTE'S PC, and the Johto access line said LANETTE's while its menu row said BILL'S.
### `FrontierFacilityStress.lua`

Full Lv. 50 singles challenges at the Battle Arena, Palace and Dome with real input, on the shared
driver `frontier_facility.lua`. Each case starts from one post-boot savestate with four Pokemon
(Charizard leads and follows), walks to the singles attendant and takes the challenge through the
real menus, party pick and save; battles are won on the real move menu with the opponents held at
1 HP. The Dome picks two Pokemon before each round and opens the tourney tree once. A Rest after the
first win must save and return to the title, and Continue must land in the lobby with the challenge
paused; the challenge then runs to the end. The player must end in the lobby with control, the
party byte-identical to the one that entered, the frontier status cleared, the win streak at 7 (1
for the Dome), the first Battle Point award (Arena 1, Palace 4, Dome 1) added and the follower
walking behind again. A soft reset on the Dome tourney tree with no save must come back to the
"didn't save" ending: streak 0, status cleared, party unchanged, no BP. Measured **45/45**; no
defect found. `--env PW_CASE=<text>` runs matching cases.
### `FactoryRentalStress.lua`

The Battle Factory on the `FrontierFacilityStress` driver (split out for the 300,000-frame cap).
The rental screen rents the first three Pokemon, the first win is followed by a Rest, Continue and
a swap of the first rental for the opponent's first Pokemon, and all seven battles are won. Three
rentals must replace the party, the swap must change the first party slot by the next battle, and
the challenge must end with the party byte-identical, streak 7, 3 BP and the follower back. A soft
reset on the swap screen with no save must end the streak with the party restored and no BP.
Measured **26/26**; no defect found.
### `HofDexNumbers.lua`

The "No." line in both Hall of Fame PC viewers. The National Pokedex is switched on by the special
the professors' scripts run. Two records come from real Kanto inductions with a one-Pokemon team,
Wobbuffet (no Kanto dex number) and then Nidoqueen. Each record is viewed at the Viridian PC (Kanto
viewer, `hall_of_fame_frlg.c`) and the Oldale PC (Emerald viewer, `hall_of_fame.c`) with real
input, and the "No." line is read from window 0's tile data as a colour-blind pixel mask at the same
screen position. Both viewers must draw the same pixels for one record, and the records must
differ. Before the fix the Kanto viewer printed three digits ("No. 202") where the Emerald viewer
and the Pokedex print four ("No. 0202"): **17/19** unfixed, **19/19** fixed.
### `KurtBallFullBag.lua`

Kurt's BALL making with a full POKé BALLS pocket. Setup puts Azalea past the Slowpoke Well
(`VAR_AZALEA_TOWN_STATE` 4, the crafting Kurt shown), gives five Pecha Berries and fills the 16-slot
pocket in RAM with 16 ball types that are not a Love Ball. Talking to Kurt and picking LOVE BALL is
real input, and every line he prints is read from `gStringVar4`. With the pocket full he must say
the bag has no room before he starts, never "I'll get started" or "I just finished your BALL", and
keep the berries. With one slot freed the same talk must turn five berries into five Love Balls.
Before the fix he hammered, said he had finished the BALL, and then "The BAG is full": **7/10**
unfixed, **10/10** fixed.
### `KantoTutorRepeatPrompt.lua`

A Kanto move tutor that teaches again must not warn that its move can be learned only once.
`I_REUSABLE_TMS` is `TRUE`, so `move_tutors_frlg.inc` compiles out the fifteen FRLG tutors' "taught"
flags and each tutor offers its move on every visit, yet each still asked "This move can be learned
only once. Is that okay?" before the party menu. The warning is now compiled out with the flags.
Cape Brink's ultimate-move tutor keeps its flags in C and stays one-time, so it keeps the warning.
The suite gives two level 5 Mew, enters the Pewter Museum by its back door and asks the Seismic
Toss tutor twice with real input, answering YES to every Yes/No box and picking the other Mew the
second time. **Oracle:** each visit raises exactly one Yes/No box (`Task_HandleYesNoInput` going
live) before the party menu, and both Mew learn Seismic Toss. **Discrimination:** unfixed 7/9
(`boxes=2` on both visits; the screenshots show the warning), fixed 9/9.
### `TmAdviceReusable.lua`

TM advice must match reusable TMs. `I_REUSABLE_TMS` is `TRUE`, so every TM keeps teaching its move,
yet three explanations still called a TM single-use: Brock's TM39 speech ("A TM is good for only one
use"), Roxanne's Rock Tomb speech ("a TM can be used only once") and the Route 104 boy who gives
the Bullet Seed TM ("good only for one-time use ... Once you use it, it's gone."). All three now say
a TM never wears out. The suite drives the Route 104 boy with real input: the first talk gives the
TM, the second prints his advice. **Oracle:** the advice, decoded from `gStringVar4` (where the field
message is expanded), names the TECHNICAL MACHINE and neither calls it one-time nor says it is gone.
**Discrimination:** unfixed 4/6 (the old line quoted in both failures), fixed 6/6. Brock's and
Roxanne's new lines were rendered with an injected `msgbox` and checked by eye for fit.
### `FrontierRecordedBattle.lua`

A Battle Frontier battle recorded on the Frontier Pass must play back with the Pokemon that fought.
The lobby's "record your last match" prompt comes after the facility has put the player's party back
and cleared the opponent's, and `MoveRecordedBattleToSaveData` copied the live `gParties`, so the
record held the player's own party in its own order and an empty opponent party. The suite takes the
Battle Arena Lv. 50 challenge with real input, picking Venusaur, Blastoise, Charizard (the party
leads with Charizard); six battles are won with the opponents held at 1 HP and the seventh is fought
straight so its record replays faithfully. Both leads and their max HP are noted at the seventh
battle's start and the prompt is answered Yes. The Frontier Pass is opened from the Start menu, the
cursor moved onto Battle Record and the record played: both leads must match, and playback must
return to the pass. Measured **11/11** fixed and **9/11** on the unfixed ROM (playback led with
Charizard against species 0 with 0 HP).
### `KantoPropsStress.lua`

Kanto story props with a level 50 Venusaur follower out, real input after the setup warps. **Draw
order:** the follower walks a seeded 60-step path in the Cape Brink house and three Three Island
houses; every frame the engine's OAM sort key (`sprite.c` `BuildOamBuffer`: priority, subpriority,
159 minus the top y, sprite index) is rebuilt for the player and the follower, and the follower may
sort in front only when its feet are not above the player's (12,152 frames). A follower directly
south of the player covers the player's legs, which is correct depth, not a defect. **Celadon
elevator:** every floor in a scrambled order, with A, B, Start, Select, L, R and the D-pad spammed
until the ride hands control back; the dynamic warp must open on the chosen floor. **S.S. Anne
departure:** from `VAR_MAP_SCENE_VERMILION_CITY` 1 (the captain's state) the cutscene runs, the player
lands in Vermilion and walks, and the follower comes back out beside the player. **Silph Co. 5F**
after Giovanni (`FLAG_HIDE_SILPH_ROCKETS`): the Card Key opens door 1, the player saves beyond it,
soft resets and continues, walks back through, opens door 2 and takes the west pad to 3F, where the
follower comes out beside the player. Measured **68/68**; no defect found. Control:
`--env PW_TAMPER_SUBPRIORITY=1` zeroes the follower's subpriority each frame, the follower visibly
draws over the player's shoulder and a resident, and the draw-order check fails (3,352 frames, 67/68).

### `BikeShopsAcrossRegions.lua`

Rydel's Cycles in Mauville and the Goldenrod bike shop share `FLAG_RECEIVED_BIKE`, so one shop bike
across Hoenn and Johto is the rule: Rydel swaps the bike the player holds and the Goldenrod clerk
gives nothing to a player who has one. Goldenrod's first-visit setup cleared that flag with the rest
of its HnS reset list. The suite talks to Rydel for the Mach Bike and again to switch it for the Acro
Bike, walks into Goldenrod for the first time, talks to the Goldenrod clerk, then to Rydel, and reads
the Bag after each talk (quantities decoded with the encryption key). **Oracle:** the flag survives
the Goldenrod visit and the Bag never holds more than one bike. **Discrimination:** unfixed 16/18
(flag cleared; the clerk gives a Mach Bike beside the Acro Bike), fixed 18/18.
### `CyclingRoadAnyBike.lua`

Kanto's Cycling Road gates (Route 16 north entrance and Route 18 east entrance) let only
`FLAG_GOT_BICYCLE` through, so a player carrying a Mach or Acro Bike from Hoenn or Johto in the shared
Bag was stopped as a pedestrian. With only a Mach Bike (Route 16 gate), only an Acro Bike (Route 18
gate) and no bike (Route 16 gate), the suite walks west across each gate on foot. **Oracle:** with a
bike the player reaches the road on that bike (`gPlayerAvatar` Mach or Acro flag); with none the guard
still turns them back. **Discrimination:** unfixed 6/10 (both bike owners stopped at the counter),
fixed 10/10. Screenshots show the Mach and Acro riders on Routes 16 and 18.

### `PokegearKeepsHoennPokenav.lua`

Johto's mother gave the PokeGear by setting `FLAG_RECEIVED_POKENAV`, Hoenn's flag for Devon's PokeNav
scene. Every Hoenn Pokemon Center then ran `Common_EventScript_UpdateBrineyLocation` early, and the
next Hoenn arrival docked Mr. Briney and Peeko at the cottage while Peeko was still missing. The suite
crosses the hub's Johto gate, gets out of bed, sets the wall clock and walks downstairs for the
mother's scene; then, with the first Hoenn badge and a party, enters the Rustboro Pokemon Center,
leaves by Hub Pass and comes back through the Hoenn gate (team prompt: keep the party), and visits the
cottage. **Oracle:** the PokeGear works (`FLAG_SYS_POKENAV_GET`), `FLAG_RECEIVED_POKENAV` stays clear,
`VAR_BRINEY_LOCATION` stays 0, and the cottage holds nobody but the player. **Discrimination:** unfixed
14/18 (Briney's shore recorded as 1, Briney and Peeko home at (2,6) and (6,3)), fixed 18/18.
### `SkyCharmMahoganySetup.lua`

Mahogany Town's first-visit setup (`MahoganyTown_EventScript_TownTrigger`: Lake of Rage Lance, the Rocket
hideout and Dragon's Den actors, Blackthorn's story state) ran only from coord events on Route 42's
east edge. The Sky Charm, unlocked in Johto at the sixth badge with Mahogany the next gym, flies over
coord events. With Johto badges 1 to 6 and the Sky Charm registered, the suite takes off outside Mt.
Mortar's east door on Route 42, flies east into Mahogany, lands at (10,9), then warps to the Lake of
Rage. **Oracle:** `VAR_MAHOGANY_TOWN_STATE` reaches 1, `FLAG_VISITED_MAHOGANY_TOWN`,
`FLAG_HIDE_LAKE_OF_RAGE_LANCE` and `FLAG_HIDE_DRAGONS_DEN_CAVERN_LANCE` are set, `VAR_BLACKTHORN_CITY_STATE`
reaches 1, and no object stands on Lance's tiles (30,37)/(31,37). **Discrimination:** unfixed 6/12
(state 0, Lance and his Dragonite spawned at the lake), fixed 12/12.

### `LotteryCountersPerRegion.lua`

The Goldenrod Radio Tower lottery reused Lilycove's `FLAG_DAILY_PICKED_LOTO_TICKET` and its held-prize
vars `VAR_POKELOT_PRIZE_ITEM`/`_PLACE`, so a draw in one region closed the other counter for the day
and a prize held for a full Bag in one was handed out by the other. The suite talks to the Radio Tower
clerk and draws (Yes), then talks to the Lilycove clerk. **Oracle:** the Radio Tower draw leaves
Lilycove's flag clear, and the Lilycove clerk still offers a draw (a Yes/No prompt appears) and records
it. **Discrimination:** unfixed 6/8 (Lilycove answers "come back tomorrow"), fixed 8/8.
### `SkyCharmLockedGymDoors.lua`

Cinnabar's and Viridian's gym doors are locked only by a coord trigger on the tile in front of them
(the Secret Key at Cinnabar, the seventh badge at Viridian). The Sky Charm, unlocked in Kanto at the
third badge, skips coord events while airborne and could land on that tile, so one press of Up walked
into the gym. `CanLandOverworldFlight` now refuses a tile whose coord script would start on a step
there (`IsCoordScriptPendingAt`, which runs nothing). With Kanto's third badge and the Sky Charm
registered, the suite flies to each lock tile and presses Select, then lands beside it (south at
Cinnabar, west at Viridian, whose south tile is a ledge) and walks in. **Oracle:** the landing on the
lock tile is refused (still flying), and walking in never reaches the gym map. **Discrimination:**
unfixed 6/10 (landed on both lock tiles and walked into Cinnabar Gym and Viridian Gym), fixed 12/12.
`SkyCharmLanding` 10/10, `SkyCharmBikeAloft` 19/19 and `SkyCharmMahoganySetup` 12/12 on the fixed ROM.
### `HeldItemTradeEvolution.lua`

The trade evolutions that need a held item must work from the Bag. Link trade is compiled out and
the stores sell the Metal Coat, King's Rock, Dragon Scale, Up-Grade and both Deep Sea items to be
used like stones, but `I_USE_EVO_HELD_ITEMS_FROM_BAG` left them on `ItemUseOutOfBattle_CannotUse`.
Eight cases (Scyther and Onix with a Metal Coat, Seadra, Porygon, Slowpoke and Poliwhirl, Clamperl
with each Deep Sea item) give the base species through the debug Give menu and one item, then open
the Bag, pick Use and the party slot and drive the evolution with A; Kadabra with a Linking Cord is
the control. Each must arm an evolution-stone use, evolve into its trade evolution and spend the
item. Measured **13/45** on the unfixed ROM (Use printed Dad's advice; only the control evolved)
and **45/45** fixed. `--env PW_EVO_ONLY=<text>` runs matching cases.
### `SageLiAfterHoennFlash.lua`

HM Flash is one item in the shared Bag, so `FLAG_RECEIVED_HM_FLASH` is one per world (Granite Cave in
Hoenn, Sprout Tower in Johto). Sprout Tower's Sage Li checked that flag before his battle, so a player
who already had Flash from Hoenn got his after-battle line and never fought him. The suite sets the
flag as Granite Cave leaves it, gives a level 50 party member, debug-warps to (11,4) in front of Li,
faces him and presses A. **Oracle:** a trainer battle starts (`gBattlersCount` > 0 with
`BATTLE_TYPE_TRAINER`). **Discrimination:** unfixed 1/2 (no battle), fixed 2/2.
### `BadgeSpeechRules.lua`

Badge speeches must state this build's badge rules: `B_BADGE_BOOST` is `GEN_LATEST`, so no badge
raises a stat, and `GetAttackerObedienceForAction` raises the obedience cap by 10 with every badge of
the active region. The Cerulean badge describer is talked to four times with real input and its
BOULDER, THUNDER, SOUL and VOLCANO rows must quote obedience up to level 20, 40, 60 and 80 and no
stat; Roxanne is talked to and battled (the win is forced once the battle starts, her gym trainers'
flags are set) and her STONE BADGE speech must quote level 20 and no ATTACK boost. Text is read
from `gStringVar4`. Measured **11/21** on the unfixed ROM (every row promised a stat boost) and
**21/21** fixed. `ValidateConfigRules.py` covers the other leaders' lines.
### `FieldPoisonText.lua`

Field-poison advice must match `OW_POISON_DAMAGE` (`GEN_LATEST`: no damage outside battle). A party
POKéMON is poisoned the way a battle leaves it and walks 40 steps in the Petalburg Mart with real
input: its HP and poison must be unchanged. Then the Petalburg Mart man, the Vermilion Pokemon Center
man (chased along his wander row) and the Cherrygrove Mart boy are talked to with real input; their
lines, read from `gStringVar4`, must name poison and claim no HP loss or fainting while walking.
Measured **13/16** on the unfixed ROM (all three said it) and **16/16** fixed. The Rustboro school
notebook line is covered by `ValidateConfigRules.py`.
### `HmTmRulesText.lua`

The Rustboro Cutter's HM speech must match this build's move rules: TMs are reusable
(`I_REUSABLE_TMS`) and a POKéMON that can learn CUT may use it untaught
(`QOL_FIELD_MOVES_NO_TEACH`). The Cutter is talked to twice with real input (the HM gift, then the
repeat explanation); the explanation, read from `gStringVar4`, must not say "unlike a TM" and must
name "can learn CUT". Measured **4/8** on the unfixed ROM and **8/8** fixed. Route 14's Carter
(HM moves "can't" be forgotten, against `P_CAN_FORGET_HIDDEN_MOVE`) has no warp to reach him;
`ValidateConfigRules.py` covers his line.

### `XRegionSaveRepair.lua`

#602 and #604 stop two cross-region writes, but a save already damaged keeps the damage: Goldenrod's
first visit had cleared `FLAG_RECEIVED_BIKE` beside Rydel's bike, and the Johto PokeGear had set
`FLAG_RECEIVED_POKENAV`, so a Center recorded Mr. Briney's cottage and a hub return docked him and
Peeko there before the rescue. The v12 -> v13 step of `MigrateSaveFormatIfNeeded` repairs both on
proof: a Mach or Acro Bike in the Bag or item PC restores the bike flag; the PokeNav flag with
`VAR_DEVON_CORP_3F_STATE` still 0 (Devon's scene sets both) and no Dewford visit (every first voyage
lands there) clears it, zeroes `VAR_BRINEY_LOCATION`, re-hides Briney and Peeko and drops them from a
save's live object list. The fixture `v12xregiondamaged.srm` was written by the pre-fix build driving
the old scripts (`fixtures/v12xregion.md`) and saved inside the cottage with both standing. The suite
Continues it and reads the flags, the cottage on Continue and after walking back in, a Rustboro
Center visit and Rydel (a new-bike offer is answered Acro). **Control:** Devon's real PokeNav scene,
then a v12 stamp, Start-menu save, reset and Continue: the legitimate flag, shore and bike stay.
**Discrimination:** unfixed 20/28 (bike flag clear, Briney and Peeko in the cottage on Continue and
after re-entry, shore 1, Rydel hands over an Acro Bike beside the Mach Bike), fixed 28/28. Mutants:
the cottage object loop removed 27/28, the Devon guard removed 26/28. A save migrated offline with
`SavePatch.py --migrate` also passes 28/28.
### `XRegionSaveRepairVoyage.lua`

The other half: `v12xregionvoyage.srm` has the PokeGear damage and an early Briney who already sailed
the player to Dewford, and no bike. From Dewford on, the route depends on where the save put Briney,
so the repair must leave him tracked; with no bike anywhere the bike flag must stay clear. The suite
Continues in Dewford, reads the flags, and takes Rydel's first bike. **Oracle:** the PokeNav flag,
`VAR_BRINEY_LOCATION = 1` and Briney's Dewford dock survive; Rydel gives the first Mach Bike. Passes
11/11 on both the unfixed and the fixed build by design; with the Dewford guard removed it drops to
9/11. `test/overworld/TestXRegionSaveRepair.py` checks the same files against SavePatch's mirror.
### `SummaryNoDynamaxRow.lua`

Dynamax and Terastal are off in this Gen 1-3 game (`B_FLAG_DYNAMAX_BATTLE 0`, no Dynamax Band,
Dynamax Candy, Max Soup or Tera Orb anywhere a player can reach), so the SwSh summary must not draw
a "Dmax Lv." row or a Tera type badge. With real input the suite opens a Pokemon's summary from the
Start menu party, from a PC box (Withdraw mode, Summary) and in the Rocket HQ multi battle with
Lance, where it also scrolls onto his Dragonite. On each info page no sprite may sit visible at the
Tera badge position; on each skills page BG2's tilemap row 11 must start with the Ability label
(tiles `0x7B`-`0x7E` of `page_skills.bin`, not the Dmax label `0x84`-`0x87`) and the ability window
must sit at tilemap row 11, directly under the stats. Measured **17/17**, and **6/17** with
`SWSH_SUMMARY_SHOW_DYNAMAX_LEVEL` and `SWSH_SUMMARY_SHOW_TERA_TYPE` back on.
### `ExchangeCornerPurchases.lua`

The Battle Frontier Exchange Service Corner at the edges, all four clerks with real input (the two
side clerks across their side counters). From one savestate: 1 BP buys a Protein (1 BP) and 0 BP is
refused with the list coming back; 47 BP is refused for Leftovers (48) and 48 BP buys it; a full Items
pocket (debug Fill Pocket Items) refuses Leftovers, keeps the BP and ends the conversation; 16 BP buys
a Kiss Poster and a full poster inventory refuses it the same way; 255 BP is refused for the Blastoise
Doll (256) and 256 buys it. BP, bag counts and `gDecorationInventories` are the verdict. Measured
**42/42**; no defect found.
### `GymPuzzleSaveContinue.lua`

Start-menu save, soft reset and Continue in the middle of gym puzzles. Continue runs ON_LOAD but not
ON_TRANSITION, so state must come back from saved vars, flags and temp vars. Blackthorn: coord
trigger 1 builds bridge 1, save, Continue, walk it, trigger 2 builds bridge 2, save, Continue, walk
it. Vermilion: the first switch's trash can (`VAR_TEMP_0`) half-opens the beam, save, Continue, the
second can (`VAR_TEMP_1`) opens both beams (the walk re-plans around trainers who stepped in).
Cinnabar: quiz 1 answered Yes opens its door. Saffron: after a warp tile. Ecruteak: on the invisible
floor. Goldenrod, Azalea, Olivine, Cianwood: a few steps in. Map, tile and puzzle metatiles must match
across Continue. Trainer battles on the way are won by setting the foe's HP to 1. Measured **53/53**,
and the Vermilion case 10/10 at seven RTC values (seven different switch pairs); no defect found.
`--env PW_GYM=<name>` runs one gym.
### `BoxRenameStress.lua`

The SwSh PC box rename. An empty name (Backspace past the start, then OK) keeps `BOX1`; the Select
page cycle returns to upper case; eight W's fill the name and the ninth A press saves exactly eight
(screenshots of the title bar and the Jump view); four seeded mash sessions across the naming and
storage screens leave all 14 names terminated within nine bytes; the names survive a Start-menu save,
soft reset and Continue byte for byte. Measured **13/13**; no defect found.
### `FrontierPassStress.lua`

The Frontier Pass with five symbol states seeded through `FLAG_SYS_<FACILITY>_SILVER/GOLD` (none, all
silver, all gold, mixed, gold without silver) and 0 to 9,999 BP. Each case opens the pass from the
Start menu, zooms and flips the Trainer Card, zooms the Frontier map and walks its facility list both
ways, points at Battle Record with no record, then mashes 2,500 seeded presses; the pass must return to
the field with no crash. Hover descriptions, symbol placement and colours were checked by eye.
Measured **11/11**; no defect found.
### `MasterRankMuseum.lua`

Manual (about 160 seconds, needs `--timeout 1200 --env PW_MAX_FRAMES=1500000`). A Master Rank win in
all five contest categories through the real contest flow. Setup maxes a Milotic's conditions and
sheen, gives it each category's Hyper ribbon (substructs re-encrypted with a fresh checksum) and leaves
`FLAG_HIDE_LILYCOVE_MUSEUM_CURATOR` and `VAR_LILYCOVE_MUSEUM_2F_STATE` as following the 1F curator does.
Each category: receptionist, Enter, Master Rank, category, Milotic, a different move each turn, accept
the artist. A category is retried until a win scores the artist's 800 points; each must leave the
Master ribbon and the painting flag. The museum 2F must then hang five different paintings and the
curator must give the Glass Ornament. Measured **27/27**; no defect found.

### `RelearnerFanfareMusic.lua`

Teaching a move left the music paused, and the next door to a map with other music held the screen
black forever. `LearnMove` (`src/chooseboxmon.c`) played the level-up fanfare and handed input back
at once. `PlayFanfare` pauses the BGM, and `Task_Fanfare` resumes it 80 frames later. Forgetting a
move for a second one inside those frames goes through the summary and back into the relearner, and
`CB2_InitLearnMoveReturnFromSelectMove` calls `ResetTasks`. That killed `Task_Fanfare` and left the
BGM paused. A door then waits in `FadeOutMapMusic` for a paused song to stop, so `Task_WarpAndLoadMap`
never warps. Same-music doors un-pause it, which is why it hides indoors. `LearnMove` now holds until
the fanfare ends, as Emerald's relearner did. With real input in Fallarbor below the Pokemon Center
door the suite opens Start, POKeMON, the lead Charizard (three moves), Summary, the battle moves page
and the relearner (Start). It teaches the first move, mashes A at Instant text through a second
teach that forgets a move, backs out and walks into the Center. **Discrimination:** unfixed 9/11
(BGM status `0x800001FF`, black screen at the Center door), fixed 11/11. Found by
`InputSpamStress`'s dig mash at `PW_SPAM_BASE=1` on the stress-6 integ3 build.

### `FanfareResetTasksMusic.lua`

A fanfare cut short by a menu left the music paused, and the next door to a map with other music held
the screen black forever. `PlayFanfare` pauses the BGM and `Task_Fanfare` resumes it when the fanfare
ends, but every menu and field return calls `ResetTasks`, which killed the task. `RelearnerFanfareMusic`
covers the one caller that handed control back early (#624); this suite covers the class at the sound
layer. `MapMusicMain` (`src/sound.c`) now finishes the count of a fanfare whose task is gone and
resumes the BGM itself. In Fallarbor below the Pokemon Center door a script plays the 710-frame
`MUS_AWAKEN_LEGEND` fanfare and ends without `waitfanfare`, standing in for such a caller. With real
input the suite opens Start and POKeMON (the party menu's init calls `ResetTasks`), backs out, waits
out the fanfare and walks into the Center. **Discrimination:** unfixed 7/9 (BGM status `0x800001FF`,
black screen at the Center door), fixed 9/9.
