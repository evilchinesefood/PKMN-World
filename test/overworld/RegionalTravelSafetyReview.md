# Regional travel safety review (#378)

## Scope and evidence boundary

Source inventory started at `86363dc2620460fba8aac9fdfb8b3ae2d6fc629e`. Implementation: `40eb3e01a6`; regression coverage: `6caf68f85c`. Review covers hub travel, ferries, applicable Fly, and neutral facilities. Physical map region, active campaign, and temporary battle/facility context are separate. Working route policies remain intact. No save-layout, flag/variable-ID, or identity migration is needed.

The table records source inspection unless the evidence section explicitly identifies an emulator check. Debug prerequisites and party setup permit focused interaction tests; they do not establish natural progression, game balance, or a full campaign playthrough.

## Current route policies

| Route | Acceptance / capture | Campaign / party | Arrival / recovery |
|---|---|---|---|
| Hub Pass mainland → hub | Yes callback precedes `RecordDeparture(PhysicalRegion())` at item_use.c:420; No returns at 445 without capture | Neutral hub preserves active campaign and party | Existing recovery remains; warp resets cruise/field state |
| Vermilion pier → hub | Yes then capture, VermilionCity_Frlg/scripts.inc:71–81 | Preserve campaign/party | Neutral hub; no respawn setter |
| Goldenrod station → hub | Rail pass admits boarding; capture first in BoardTrain at GoldenrodCity_TrainStation/scripts.inc:32 | Preserve campaign/party | Neutral hub; no respawn setter |
| Slateport → hub | Yes then capture at SlateportCity_Harbor/scripts.inc:168–177 | Preserve campaign/party | Neutral hub |
| Hub → uncompleted regional opening | Yes; capacity/mail guard precedes legacy entry at RegionHub/scripts.inc:145→148,192→195,228→231 | Cross-region boxes whole team; same active region retains party | Region-specific protected opening and start respawn; script chooses bedroom/lab as appropriate |
| Hub → completed regional opening | Team choice, destination choice, partial-team consent when needed, final Yes; Preview then Commit at RegionHub/scripts.inc:1901–1948 | Regional-team/current-party choice via existing transaction helpers | Eligible Center resume or standard arrival fallback via helper |
| Hub ↔ Battle Frontier | Champion gate + Yes, RegionHub/scripts.inc:338; reverse Yes BattleFrontier_OutsideWest/scripts.inc:12 | Neutral-to-neutral; no recapture; preserve party and campaign | No new respawn; appropriate for prior mainland departure snapshot |
| Hoenn ports → Battle Frontier | Accepted Yes then capture before boarding, Slateport scripts:231–240, Lilycove scripts:123–132 | Neutral excursion; preserve campaign/party | Normal ferry warp |
| Olivine → islands/Frontier | Every selected destination calls EnterShip; capture first at OlivineCity_PortInside/scripts.inc:310 | Neutral excursion; preserve campaign/party | Records ferry origin and sets Olivine recovery at end of boarding helper |
| Lilycove → Hoenn ticket islands, first and repeat | Capture before actual boarding at Lilycove scripts:78,87,96,105,231,250,266,302,321 | Neutral excursion; preserve party/campaign | Persisted origin var written by normal, first-time, or inline Old Sea Map boarding path |
| Hoenn ticket islands → home | Accepted sailor Yes uses shared home helper, e.g. SouthernIsland_Exterior/scripts.inc:9–25; dispatch event_scripts.s:1716 | No recapture; party preserved; persisted harbor origin consumed | Returns Olivine/Vermilion/Lilycove; legacy origin-unset fallback uses campaign; avoids unconditional campaign claim |
| Olivine → maiden S.S. Aqua → Vermilion | Capture before initial boarding at Olivine scripts:310; no recapture aboard or disembarking | Ship neutral; final Kanto claim retains current party | SSAqua_1F/scripts.inc:65 sets Kanto then explicitly Vermilion respawn |
| Olivine ↔ Vermilion repeat | Select/Yes then shared capture-before-movement helper, Olivine scripts:161,310; VermilionCity_PortInside scripts:77–85,118 | In-world ferry retains party; explicitly claims destination campaign | Explicit destination port recovery after claim, Olivine scripts:165–167, Vermilion scripts:110–114 |
| Frontier → mainland Hoenn ports | Yes then claim Hoenn at BattleFrontier_OutsideWest/scripts.inc:65–90 | Retains party; intentionally does not capture neutral team | Existing implementation arms standard Hoenn start recovery through claim; no explicit port respawn here |
| Ordinary Lilycove harbor visit | On-transition TargetIsCurrent guard at Lilycove scripts:25–32 | Already-Hoenn skips claim, preserves party/campaign | Guard prevents routine visit resetting earned Center recovery |
| Slateport ↔ Lilycove S.S. Tidal cruise | Accepted Yes, state write, boarding, ship warp at Slateport scripts:221–228 and Lilycove scripts:113–121 | Ship MAPSEC_DYNAMIC is neutral; campaign/party unchanged | Missing capture reproduced on the baseline; corrected at accepted cruise confirmation |
| Mainland → idle battle tent / Trainer Hill lobby | Ordinary map warp; no capture scripts | Explicitly neutral in PhysicalRegion; campaign/party unchanged | Missing capture reproduced at the Slateport door; Trainer Hill uses a separate step-on warp, also covered by the fix |
| Kanto Seagallop ordinary islands + FRLG event island twins | Selection then shared SetSail at data/scripts/seagallop.inc:85–108, destination warp src/seagallop.c:310–316 | Same physical campaign; FRLG Birth/Navel mapsecs are distinct from neutral Hoenn versions | No regional team recapture needed solely for these same-region routes |

| Seven Island → outdoor Trainer Tower | Northbound map connection; no accepted snapshot on baseline | Neutral outdoor area preserves campaign and party | Actual walking and Hub Pass reproduce stale Kanto memory on baseline; fixed at accepted displacement |

## Findings and implementation boundary

The immutable baseline ROM (`SHA256 954be4ba069a68a2a7a6047dc7887ea54af02af48a562ab4aad04707f887d58c`) reproduces three distinct missing-capture paths: normal Slateport cruise, Slateport tent door, and Seven Island outdoor connection. Each test establishes team A, changes the mainland party to B, crosses using actual input, then uses Hub Pass. All 11 setup/interaction checks passed; all six expected B-memory checks failed. This distinguishes route defects from fixture failures.

Both normal cruise confirmations require capture before boarding-state writes. Walk-in facility entry requires capture before warp or displacement admission. Trainer Hill uses a nonanimated step-on warp, so both door and generic step-on warp dispatch are guarded. A refused Hill entry leaves the player on the source entrance tile; stepping off and back on retries it. The bounded destination set is three tent lobbies, Trainer Hill entrance, and outdoor Trainer Tower. Internal facility movement and other neutral destinations remain outside this rule. Existing script captures remain at their earlier acceptance points.

A collision query is not accepted departure: subsequent collisions can still reject movement. Camera transition is too late for safe refusal. The selected movement seam records at accepted displacement admission before installing the held movement; source map identity remains available and a refused snapshot installs no movement.

## Reviewed non-findings

- Recall preview/commit preserve full-PC exchange, mailbox refusal, identities, followers, partial confirmation, protected openings and destination-party checks. No additional defect was demonstrated in those core paths.
- All three reachable legacy whole-party hub deposit callers have capacity/mail preflight.
- Same-region and canceled Fly do not capture. Cross-region Fly retains the current party and existing eligibility. Southern Island's apparent claim mismatch is unreachable through the inspected Fly selectors.
- Continue does not capture departure. Eligible regional Centers and vanilla recovery are distinct; unsafe remembered Centers use fallback without erasing the memory.
- Ordinary same-region Lilycove harbor entry skips the campaign claim and preserves earned recovery.
- Existing ferry recovery differences are preserved: Aqua explicitly chooses destination-port recovery; neutral-island return uses saved origin; Frontier-to-Hoenn uses its existing campaign claim.
- Neutral PC edits, ship rooms, hub/Frontier transfers and battle returns must not overwrite accepted mainland memory.

## Verification

Baseline default build passed. Direct host validation passed 20/20. Existing native suites passed: RegionalTravel 221/221, JohtoFlyTeleport 31/31, StoryProgress 31/31, RegionalTravelMigration 10/10.

Fixed ROM SHA256: `458ecec477a2c857eab719e203fa632ee4c595828cf2b3f9e492c9e39762c11d`. The independent original boundary probe passes 17/17 on the fixed implementation versus 11/17 on the baseline. The same probe uses a west-side town approach to avoid a wandering NPC; it still crosses the actual outdoor connection with directional input.

The focused C test command is `gmake check TESTS='Regional*'`: 38/38 pass, covering regional Centers and travel, including all five bounded facility destinations, physical-source versus active-campaign ownership, duplicate-identity refusal/retry, and neutral/non-entry no-ops. Existing tests retain the full storage/mailbox, corrupt party, identity, follower, protected opening and fallback checks.

Final native results on that immutable ROM:

| Suite | Result | Evidence scope |
|---|---:|---|
| RegionalTravelBoundaries | 103/103 | Both ordinary cruise directions: No, duplicate-identity refusal and repaired retry; tent and Trainer Hill refusal/retry; actual Tower connection on foot, Mach Bike, flying mount and directional Acro side-jump; physical Kanto with active Johto; neutral party edits, real save/Continue, outdoor-to-lobby entry and Hub Pass preservation |
| RegionalTravel | 221/221 | Existing recall, partial confirmation, recovery, cancellation, save/Continue and ferry contracts; includes actual Johto → Frontier → hub → Hoenn with neutral party changes |
| JohtoFlyTeleport | 31/31 | Existing Fly/Teleport destination and recovery checks |
| StoryProgress | 31/31 | Read-only destination/progress viewing and Continue |
| RegionalTravelMigration | 10/10 | Tracked v10 fixture, Continue and actual Center-entry distinction |
| Independent BoundaryProbe | 17/17 | Same three-path reproducer that fails six memory checks on baseline |

Final direct host validation passes 20/20; whitespace/diff checks pass. Independent source review found no remaining actionable production defect after reviewing the additional Trainer Hill seam. One added implementation comment was removed because the code expresses its ordering directly. Earlier route-setup obstructions were test navigation failures and are not counted as game defects.

Coverage limits: runtime door checks use Slateport tent and Trainer Hill; all three tent entrance IDs also have parametrized C coverage. Invalid-party runtime checks use duplicate identities; existing C tests cover corrupt-party refusal and allocator exhaustion. No full campaign, exhaustive route cross-product, hardware timing or natural-progression acceptance is claimed.

Reproduce native checks with the built ROM and a matching immutable bundle:

```sh
python3 test/overworld/NativeRunner.py bundle --rom pokemonworld.gba --elf pokemonworld.elf --out /tmp/travel-bundle
python3 test/overworld/NativeRunner.py run test/overworld/lua/RegionalTravelBoundaries.lua /tmp/travel-bundle/pokemonworld.gba --bundle /tmp/travel-bundle --out /tmp/travel-boundaries --emulator /path/to/mgba-headless
```

The suite is registered in `cases.tsv` for the explicit Full profile. No new automatic gameplay workflow was introduced. Source review also checked the supported input movement paths and current connection geometry; this does not claim interception of every scripted movement in the engine.
