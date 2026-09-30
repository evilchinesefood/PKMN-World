# Hoenn story reminders

The read-only resolver is `src/data/story_progress/hoenn.inc`. Its fixtures are
`test/overworld/story-progress/hoenn_cases.inc`, called by the shared host harness.
Every lead has a stable `hoenn.*` ID and five short fields; each line fits 30
characters and fields contain at most three lines. The first action line is the
overview instruction.

## Main journey and evidence

| Boundary | Shipped source and evidence | Lead while outstanding |
| --- | --- | --- |
| Home and neighbor | `LittlerootTown`, both player/rival house maps; `FLAG_SET_WALL_CLOCK`, `VAR_LITTLEROOT_RIVAL_STATE`, `VAR_LITTLEROOT_TOWN_STATE` | Set bedroom clock, meet the rival next door, then help Birch on Route 101. |
| Starter, rival, Dex | `Route101`, `Route103`, `LittlerootTown_ProfessorBirchsLab`; `FLAG_RESCUED_BIRCH`, `VAR_BIRCH_LAB_STATE` 2/3/4/5, `FLAG_DEFEATED_RIVAL_ROUTE103`, `FLAG_RECEIVED_POKEDEX_FROM_BIRCH` | Claim the starter at the lab, battle the rival on Route 103, return for Birch's Dex. Shared Dex flags do not complete this sequence. |
| Father and woods | `PetalburgCity_Gym`, `PetalburgWoods`; `VAR_PETALBURG_GYM_STATE >= 2`, `VAR_PETALBURG_WOODS_STATE != 0` | Visit Norman, help the Devon researcher, challenge Roxanne. |
| Rustboro theft | `RustboroCity`, `RusturfTunnel`, `RustboroCity_DevonCorp_3F`; `FLAG_RECOVERED_DEVON_GOODS`, `FLAG_RETURNED_DEVON_GOODS`, `FLAG_RECEIVED_POKENAV` / `VAR_DEVON_CORP_3F_STATE` | Recover the goods on Route 116, return to the worker, meet the president. |
| Two Devon recipients | `GraniteCave_StevensRoom`, `Route104_MrBrineysHouse`, `DewfordTown`, `SlateportCity_SternsShipyard_1F`, `SlateportCity_OceanicMuseum_2F`; independent `FLAG_DELIVERED_STEVEN_LETTER` and `FLAG_DELIVERED_DEVON_GOODS`, plus `FLAG_DOCK_REJECTED_DEVON_GOODS` | Steven's letter precedes Brawly and the goods. Dock must first direct the player to Stern at Museum 2F. Delivering the goods never completes the letter. Explicitly issued unfinished deliveries remain visible even with later scene progress. |
| Mauville approach | `Route110`, `MauvilleCity`, `MauvilleCity_Gym`, `MauvilleCity_House1`; `VAR_ROUTE110_STATE`, `FLAG_DEFEATED_WALLY_MAUVILLE`, Dynamo Badge, Rock Smash prerequisite | Follow Route 110, battle Wally outside the Gym, earn Wattson's badge, obtain Rock Smash before the northern rocks. Declining Wally's battle retains the lead. |
| Mountains and fourth badge | `MeteorFalls_1F_1R`, `MtChimney`, `LavaridgeTown_Gym_1F`; `FLAG_MET_ARCHIE_METEOR_FALLS` / `VAR_METEOR_FALLS_STATE`, `FLAG_DEFEATED_EVIL_TEAM_MT_CHIMNEY` | Investigate Meteor Falls, follow the teams to Mt. Chimney, challenge Flannery. The optional meteorite pickup does not block the journey. |
| Norman and eastern route | `PetalburgCity_Gym`, `PetalburgCity_WallysHouse`, `Route119_WeatherInstitute_2F`, `Route119`; Balance Badge, Surf prerequisite, `VAR_WEATHER_INSTITUTE_STATE`, `FLAG_RECEIVED_CASTFORM`, `VAR_ROUTE119_STATE` | Challenge Norman, receive Surf from Wally's father, clear the institute, collect the pending Castform, cross the bridge to the rival. |
| Fortree | `Route120`, `FortreeCity_Gym`; `FLAG_RECEIVED_DEVON_SCOPE`, Feather Badge | Meet Steven on the Route 120 bridge, then challenge Winona. |
| Mt. Pyre and hideouts | `MtPyre_Summit`, `JaggedPass`, `RusturfTunnel`, `MagmaHideout_4F`, `SlateportCity_Harbor`, `AquaHideout_B2F`; `VAR_MT_PYRE_STATE`, `FLAG_GROUDON_AWAKENED_MAGMA_HIDEOUT`, `FLAG_MET_TEAM_AQUA_HARBOR`, `FLAG_TEAM_AQUA_ESCAPED_IN_SUBMARINE` | Follow Aqua to Mt. Pyre, obtain Strength if needed, enter Magma's hideout, investigate Slateport Harbor, follow Aqua's submarine through its hideout. |
| Mossdeep | `MossdeepCity_Gym`, `MossdeepCity_SpaceCenter_2F`, `MossdeepCity_StevensHouse`; Mind Badge, `FLAG_DEFEATED_MAGMA_SPACE_CENTER`, Dive prerequisite | Challenge Tate and Liza, help Steven at Space Center 2F, visit Steven's northwest house for Dive. |
| Seafloor crisis | `SeafloorCavern_Room9`; `FLAG_KYOGRE_ESCAPED_SEAFLOOR_CAVERN`, `VAR_SOOTOPOLIS_CITY_STATE` | Follow the submarine under Route 128. Surf, Dive, Rock Smash and Strength are checked as field-move prerequisites when not yet in the crisis. |
| Sootopolis and Sky Pillar | `SootopolisCity`, `CaveOfOrigin_B1F`, `SkyPillar_Outside`, `SkyPillar_Top`; `FLAG_STEVEN_GUIDES_TO_CAVE_OF_ORIGIN`, `FLAG_WALLACE_GOES_TO_SKY_PILLAR`, `VAR_SOOTOPOLIS_CITY_STATE` 1–5, `VAR_SKY_PILLAR_STATE` | Find Steven, talk to Wallace in the cave, visit Sky Pillar and climb to the top, return to Sootopolis. The later Rayquaza capture flag is not a story requirement. |
| Resolution and final badge | `SootopolisCity`, `SootopolisCity_Gym_1F`; `FLAG_SOOTOPOLIS_ARCHIE_MAXIE_LEAVE`, Waterfall prerequisite, Rain Badge, `VAR_SOOTOPOLIS_CITY_STATE >= 6` | Speak to both leaders after returning, collect Wallace's gift, challenge Juan. Speaking to only one leader leaves their lead outstanding. Juan's scene state 6 suppresses already-ended crisis interactions in migrated saves. |
| League | `VictoryRoad_1F`, `EverGrandeCity_*Room`, regional Champion registration; `FLAG_DEFEATED_WALLY_VICTORY_ROAD`, `VAR_ELITE_4_STATE`, `FLAG_HOENN_CHAMPION` | Cross Victory Road, challenge the Elite Four and Champion, then visit World Transit's Frontier attendant. Elite Four state 1–4 records room entry, not trainer victory, and cannot prove Champion completion. |

Regional badges always come from `HasBadge(REGION_HOENN, index)` with zero-based
indices. Missing badges remain outstanding even when a migrated save contains
later local scenes. No shared item, shared Dex flag, or generic game-clear flag
proves a regional scene or Hoenn completion.

## Retries, precedence, and limits

- Steven sets his delivery flag before trying to give Steel Wing; a full Bag does
  not undo the delivery. The resolver advances to Brawly or the goods without
  claiming the TM was received.
- Castform can fail when both party and PC lack room. The scientist remains on
  2F with an object flag of zero; Route 119 moving the other workers downstairs
  changes the institute state from 1 to 2, but the scientist still retries until
  `FLAG_RECEIVED_CASTFORM` is set.
- Later Hoenn scenes suppress obsolete opening chapters when older saves omit
  early variables. Each badge is still verified independently. Explicit issued
  Devon deliveries are checked separately before other main work.
- HMs can come from other regions. Their receipt flags or actual Bag items only
  satisfy field-move prerequisites after regional journey evidence; they do not
  advance Hoenn's chapter by themselves.
- The Mt. Pyre script sets state 1 and gives the Magma Emblem before setting
  `FLAG_RECEIVED_RED_OR_BLUE_ORB`. Jagged Pass actually checks the Emblem to open
  the hideout. The old lady's repeat conversation does not re-give the Emblem;
  this reminder does not invent a repair for a malformed migrated save missing
  that key item, nor mutate that save.
- Mandatory story leads omit gift TM collection, fossil recovery, rematches,
  optional legendary captures, and postgame chains. The Champion lead uses the
  Frontier gate in `RegionHub/scripts.inc`, unlocked by any regional Champion.

## Optional lead

Only the accepted New Mauville chain is advertised. `MauvilleCity/scripts.inc`
sets `FLAG_GOT_BASEMENT_KEY_FROM_WATTSON` only after successful key delivery;
`NewMauville_Inside/scripts.inc` sets `VAR_NEW_MAUVILLE_STATE = 2` at the generator's
red switch. Return to Wattson for the reward; `FLAG_GOT_TM_THUNDERBOLT_FROM_WATTSON`
is set only after the TM fits in the Bag, preserving a full-Bag retry. Possessing
an item or merely seeing Wattson does not advertise this quest. Completion yields
no optional lead.

## Validation

The ordered fixtures exercise every main objective before and after its durable
transition, the two Devon recipients independently, Castform retries across both
institute states, speaking to one crisis leader, optional completion and a full
Bag reward retry, missing field moves, late scene migration, and shared
item/flag isolation. The harness also snapshots save state around main resolution
to verify that reads leave it unchanged. Run:

```sh
python3 test/overworld/story-progress/run.py
```

Host fixtures validate resolver choices and read-only behavior. They do not
replace an in-game navigation/layout check of the Story interface.
