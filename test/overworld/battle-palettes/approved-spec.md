## Outcome
Battles in Ice Path and snowy Mt. Silver should retain the surrounding area's cold colors, and ordinary outdoor battles should match the time of day. Reuse and recolor graphics already in Pokémon World.

This is a planned feature, not an implemented or playtested change. Scope and integration constraints are defined below; no external graphics are required.

## Verified baseline
Source reviewed at [45e1bf82ca](https://github.com/evilchinesefood/PKMN-World/commit/45e1bf82ca5c2728910127863b926e627d4f18fc).
- [BattleSetup_GetEnvironmentId](https://github.com/evilchinesefood/PKMN-World/blob/45e1bf82ca/src/battle_setup.c#L892) selects generic cave graphics for underground maps and has no snow-specific visual selection.
- [battle_bg.c](https://github.com/evilchinesefood/PKMN-World/blob/45e1bf82ca/src/battle_bg.c#L893) loads one fixed environment palette; LoadChosenBattleElement separately reloads tiles, map and palette after transitions.
- SNOW/ICE entries in [src/data/battle_environment.h](https://github.com/evilchinesefood/PKMN-World/blob/45e1bf82ca/src/data/battle_environment.h#L466) define mechanics but have no complete background/entry graphics. Selecting these entries alone is not a valid visual fix.
- B_TERRAIN_BG_CHANGE is enabled. Terrain move backgrounds and later restoration must still work.

## Exact scope
1. IcePath_1F, IcePath_B1F, IcePath_B2F, IcePath_B3F, IcePath_B4F: reuse the current cave tiles, tilemap and entry animation, with a cold blue/gray palette derived from the existing cave_ice overworld colors.
2. MtSilver_Snow and MtSilver_SummitDay: reuse the current rock background and entry animation, with pale snow platforms, blue-gray shadows and enough contrast for white Pokémon. Apply only to ordinary land encounters; preserve water/grass behavior and special battle presentations.
3. Ordinary naturally lit outdoor battles across all three regions: apply a visual time tint using the existing overworld time-blend settings captured at battle entry. Morning, day, evening and night remain consistent with the field; indoor/underground battles do not receive outdoor time tint. Do not update the clock continuously during battle.
4. Keep the approved World title, logo offset, title input behavior and battle UI geometry outside this feature.

## Implementation
- Add a presentation resolver separate from the gameplay environment ID. Its inputs are the already-resolved base visual environment, map identity, battle flags and the time-blend snapshot. Return a complete background/entry/palette bundle with a valid existing fallback.
- Preserve existing precedence for test-forced environments, link/recorded/Frontier battles, legendary presentations, leader/champion scenes and explicit map battle scenes. Exclude capture/first-battle tutorials from the new override.
- Do not mutate gBattleEnvironment, terrain flags, Nature Power, Secret Power, Camouflage, encounters, species, saves or trainer rules to select artwork.
- Route initial loading, entry animation and LoadChosenBattleElement restoration through consistent visual selection. Active terrain-move backgrounds keep precedence; when terrain expires, restore the same location/time palette captured at entry.
- Reuse graphics/battle_environment/cave and rock art; add only derived palette data. Preserve tile dimensions, entry scroll behavior, compression conventions and existing palette-bank layout.
- Write only the background palette banks currently owned by environment graphics (the existing three-bank load starting at BG palette 2). Do not tint Pokémon, healthboxes, text, type indicators or ability popups.
- Keep authored day palettes separate from derived battle-entry tint buffers so restoration never applies a tint twice.
- Do not replace map types or map metatile behaviors to achieve this change.

## Acceptance and review evidence
- [ ] Before/after comparisons at native 240x160 and integer scale: Ice Path, snowy Mt. Silver, and one outdoor battle per region at noon and night, with the same party and scene.
- [ ] Cold backgrounds keep floor/platform edges visible and retain readable silhouettes for a white, dark and shiny Pokémon.
- [ ] All five Ice Path floors resolve to the intended cold presentation; Granite Cave remains unchanged.
- [ ] Ordinary Mt. Silver land battles use the snow palette; special trainer/legendary presentations retain their current precedence.
- [ ] Morning/evening tint and a night-start battle survive bag/party returns, animation background restoration and a terrain move starting/expiring without color flashes or double tinting.
- [ ] Gym/leader/champion, Frontier, double/partner, Kanto first-battle/capture tutorial and Wally tutorial layouts retain their existing graphics/control behavior.
- [ ] Nature Power, Secret Power and Camouflage produce the same gameplay results before and after this presentation change; use the existing focused battle tests for these moves.
- [ ] Meaningful resolver checks cover map/time eligibility, special-scene precedence, valid fallback and restoration. No screenshot-only assertion is presented as proof of gameplay parity.
- [ ] Build and the relevant existing checks pass; attach visual evidence before merge.

## Dependencies, effort and benefit
Independent of the pending HGSS-versus-BW battle UI choice. Coordinate with that eventual port only at battle_bg.c integration points.
Estimate: 3–5 developer days including focused regression checks.
Benefit: distinctive locations and nighttime exploration stay visually connected when entering battles, without importing a new art set or changing battle rules.

## Agent-owned delivery and final owner playtest
The owner has approved this feature spec and wants minimal involvement. The implementing agent owns the remaining engineering investigation, asset preparation, build setup, fixtures, automated checks, emulator operation, regression diagnosis and visual evidence.

- Work in an isolated branch/worktree and preserve unrelated workspace edits. Read the current repository instructions and this issue's dependencies before starting; the source baseline above is evidence, not permission to overwrite newer work.
- Resolve routine technical choices autonomously within the stated scope. Inspect every graphics/palette/window caller affected by a shared change. Never substitute an untested assertion for runtime evidence.
- Use test/overworld/mgba/README.md and tracked test/overworld/lua suites with the current symbol-generation workflow. Create reproducible test saves/fixtures as needed; do not request the owner's save, screenshots, manual warps, debug-menu operation or test results to complete engineering validation.
- Build development and release ROMs. Run the checks appropriate to the changed surfaces, investigate failures and repeat only when fixes justify it.
- Generate matched native-resolution before/after screenshots and short recordings for animation, palette transitions or return flows. Publish a concise evidence index with exact source commits, commands, results and any remaining limitation.
- Provide one ready-to-play release build using the project's existing delivery convention, its commit identifier/checksum, and a short final-playtest route or prepared test save. Owner playtesting must fit approximately 5–10 minutes and involve normal gameplay controls.
- Owner sign-off is final visual/gameplay judgment. It is not a substitute for the agent's regression tests or a request for the owner to configure the toolchain.
- If a prerequisite cannot be met, document the exact blocker and continue independent work. Do not claim readiness or ask the owner to perform routine technical work. Seek owner input only for an unresolved product/art choice that cannot be resolved from the approved direction.


## Combined owner handoff
When this feature ships with other approved visual changes, combine them into one concise evidence pack and one approximately 5–10 minute final owner playtest. Do not assign a separate manual test matrix for every issue. The agent runs the complete per-feature regression/capture matrix, prepares the build and any fixtures, and selects a short representative route. The owner judges the finished appearance and normal gameplay only.

## Selected battle UI coordination
The owner selected Mudskipper's BW battle UI; implementation is specified in #336. This background/palette feature remains approved. Coordinate the shared battle_bg.c changes and test the combined result. Preserve BW UI BG palettes 0–1 and 10–13 while this feature owns battlefield palettes 2–4; environment/terrain mechanics remain independent. The implementing agent handles integration order, merge conflicts and final combined captures.
