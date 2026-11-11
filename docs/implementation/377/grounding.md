# Issue 377 architectural grounding

Baseline is master 35bf05083e. Source inspection only. No runtime claims.

## Overview

Regional travel currently changes active campaign, deposits a cross-region party, and arms a regional starting-town recovery point. It has no team references or entered-Center history. Physical map region and persisted active campaign differ in neutral locations. Capture cannot live in SetCurrentRegion because several callers are arrival handlers and neutral maps retain the old campaign.

## Save and identity

- `include/global.h` defines append-only `RegionSave` at SaveBlock3 offset 0x20. Current RegionSave size is 1232 bytes, including the v9 Johto trainer bank. SaveBlock3 currently occupies 1264 bytes of its 1624-byte capacity, leaving 360 bytes.
- `include/save.h` defines 116 bytes per sector across 14 sectors. `src/save.c:80` asserts capacity. SaveBlock2 is pinned at 0xF2C and has only two unused bytes at 0x96. Do not use the deprecated Hard Mode bit.
- `src/load_save.c:MigrateSaveFormatIfNeeded` owns sequential migrations. `RegionSaveWidthForVersion` must retain the old checksum width when appending a new bank. Checksum verification happens before migration. Update layout assertions and save-format constants together. Pre-feature saves must initialize references/checkpoints empty.
- `include/pokemon.h` keeps BoxPokemon at 80 bytes. Encrypted substruct unused bits total 20. Substruct0 has 6+3+2, substruct1 has 5+3, and substruct3 has 1. Two additional header bits exist. An embedded monotonic bounded ID is possible without resizing BoxPokemon. A slot-index side table does not fit the available save capacity and creates many movement hooks. A raw personality/OT tuple is not unique.
- Prefer a new MON_DATA identity accessor in `src/pokemon.c`, with zero meaning unassigned, monotonically allocated IDs, no reuse after release, and safe exhaustion behavior. Audit imported/colliding IDs and refuse ambiguous recall. Legacy migration must clear newly interpreted bits in party, PC, normal daycare and Route5 daycare rather than trust prior padding.
- `src/egg_hatch.c:CreateHatchedMon` reconstructs a Pokemon with CreateMonWithIVs and then assigns `*egg = *temp`. Explicitly preserve the egg identity across this path. `src/evolution_scene.c` copies Nincada for Shedinja. Retain identity on the evolved original and assign a distinct identity to Shedinja. Ordinary full-structure PC moves and daycare storage retain embedded fields automatically, but creation and trade need explicit audit.

## Departure ownership

- `src/item_use.c:Task_UseHubReturnOnField` is accepted Hub Pass departure, before SetWarpDestination/DoWarp. Cancellation precedes this function.
- Direct hub warps exist in `GoldenrodCity_TrainStation`, `SlateportCity_Harbor`, `VermilionCity_Frlg`, and `BattleFrontier_OutsideWest` scripts. The Frontier origin is neutral and must not recapture the previously active campaign.
- `OlivineCity_PortInside` has direct Vermilion, Frontier and event-island voyages, plus the initial SS Aqua voyage. Capture at accepted boarding before the ship map, not at Vermilion disembarkation. `VermilionCity_PortInside` owns return boarding to Olivine.
- `SlateportCity_Harbor` and `LilycoveCity_Harbor` have SS Tidal and Frontier boarding. Frontier return ferries call RegionHub_ScrSetCurrentRegion only after boarding and preserve the party.
- `RegionHub_ClaimRegionForFlyDestination` changes campaign for a neutral Frontier-to-Hoenn Fly. It must not recapture the old campaign's party. Neutral source ownership needs an explicit classification/latch, not GetCurrentRegion fallback.
- Capture Johto before entering Frontier. Subsequent Frontier/hub PC or rental changes must not replace that memory. A neutral-to-neutral move records nothing. Ordinary same-region warps record nothing.

## Hub exchange

`data/maps/RegionHub/scripts.inc` owns the three attendant paths and special opening routes. `src/region_switch.c` owns existing preflight and DepositPartyToPC. Current deposit can partially apply and can discard mail if called without its old preflight. Do not compose a new exchange from this unsafe routine.

Plan the final party and outgoing PC slots before writing anything. Incoming PC occupants free capacity for outgoing members. Keep carried incoming members in the final party directly. Mailbox demand includes only outgoing party members with mail. Party-slot follower selection must be remapped by individual identity or deliberately cleared. BoxPokemon stores hpLost/compressedStatus, so conversion must retain existing no-heal semantics.

Keep-current must check for at least one non-Egg living member but must preserve the canonical empty-party opening exception. Team preview must not assign/capture history as a side effect. A single locked commit function should revalidate, exchange, change campaign, set arrival and recovery, and return control without any intermediate save opportunity.

Existing opening narration bits are insufficient. Inspect Kanto lab scene 2/rival completion, Johto successful starter handoff, and Hoenn Birch lab handover plus mature progress fallbacks. Current Kanto gate explicitly returns an interrupted scene 2 player to Oak's lab.

## Center resume

`src/overworld.c:LoadMapFromWarp` loads map data and runs OnTransition scripts. It is a candidate successful-entry hook. Continue has a separate OnLoad path, so recording only here distinguishes actual entry from reloading a save. `src/data/heal_locations.json` contains existing heal/recovery destinations, but synthetic SetLastHealLocationWarp calls do not prove entry.

Use a stable-ID checkpoint table with explicit interior map, safe tile, campaign, recovery ID and read-only access predicate. Enumerate all regional Centers including Sevii. Exclude hub, Frontier, ships, temporary facilities and second-floor link rooms explicitly. Access-sensitive islands and late-game Centers need current story/escape checks. Validate the destination campaign and planned final party without changing live globals.

`src/field_move.c` unlock helpers read GetCurrentRegion or HasCurrentRegionBadge and therefore cannot be reused blindly while standing in the hub. Surf requires Johto badge index 3, Kanto/Hoenn index 4, with a QOL tool-item bypass. Access validation must also account for final party move availability when the item-gate configuration requires it.

## Verification infrastructure

- `test/region_switch.c` contains the target-first-badge test and is a natural neighbor for state/transaction tests.
- `test/overworld/lua/HubPassReCross.lua` covers existing hub travel. `SSAquaKantoCrossing`, `OlivineHarborBoard`, `JohtoWhiteoutHeal`, `KenyaMail`, and migration suites provide adjacent controller examples.
- `test/overworld/mgba-run.sh` copies the ROM/save into a throwaway directory and pins RTC. `mgba-headless` is installed at `/Users/dayers/.local/bin/mgba-headless`. It accepts PW_OUT and optional fixture arguments.
- `test/overworld/run-all.sh` clears sentinels and verifies every PASS against current ROM MD5. Extend its suite lists for feature tests. Tracked v3/v7/v7dirty/v7renumber fixtures exist; add v9 fixtures that put nonzero bytes in new bank space to make migration tests meaningful.
- `RELEASING.md` requires make check, full Lua sweep, make validate, default-config build, and feature-off matrix for POKEVIAL_FEATURE, QOL_FIELD_MOVES_ITEM_GATE, PW_GRAPHICAL_START_MENU. The shipped/tested configuration is the dev build, not LTO release.

## Recommended ownership seams

1. Identity/save owner changes Pokemon accessors, creation/hatch/Shedinja identity handling, append-only save bank and migration tests.
2. One travel owner integrates departure capture, exchange planner, checkpoint table and hub script UI against the agreed identity/save contract. These parts share transaction state and should not write overlapping files independently.
3. A test owner builds controller scenarios and acceptance matrix after exported hooks are agreed. Independent review audits all departure call sites and all checkpoint rules.

The highest-risk decisions are bounded identity allocation/collision behavior, save capacity/checksum migration, and source ownership through neutral transit. Settle these before parallel implementation.
