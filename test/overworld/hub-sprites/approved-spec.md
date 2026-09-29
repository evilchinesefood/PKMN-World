## Result and scope
The hub combines FRLG-style room art, nurse and attendants with two generic Emerald NPC sheets. Use the already bundled matching FRLG sheets for the harbor master and curator. Deliver a tested consistency improvement without changing character identity, services, object count or story behavior.

The owner approved this detailed direction. This issue is independent of the pending hub floor/layout choice; coordinate changes are out of scope.

## Exact changes
In `data/maps/RegionHub/map.json`:
| Event / current position | Current graphics | Replacement |
| --- | --- | --- |
| `RegionHub_EventScript_HarborMaster`, (3,14), FACE_UP | `OBJ_EVENT_GFX_SAILOR` | `OBJ_EVENT_GFX_SAILOR_FRLG` |
| `LOCALID_REGION_HUB_CURATOR` / `RegionHub_EventScript_CharmCurator`, (22,7), FACE_DOWN | `OBJ_EVENT_GFX_GENTLEMAN` | `OBJ_EVENT_GFX_GENTLEMAN_FRLG` |

Keep every other map-event field unchanged. No global replacement of the old graphics IDs.

Bundled source assets:
- `graphics/object_events/pics/people/sailor_frlg.png`
- `graphics/object_events/pics/people/gentleman_frlg.png`
- Definitions in `src/data/object_events/object_event_graphics_info.h`, `object_event_pic_tables.h`, `object_event_graphics_info_pointers.h`.

Both replacements are existing 16×32, 256-byte, standard-animation sheets; their picture tables have ten frames. SailorFrlg uses NPC_PINK / PALSLOT_NPC_2; GentlemanFrlg uses NPC_WHITE / PALSLOT_NPC_4, unlike the originals' NPC_1/NPC_3. Use the full graphics definition through the map graphics ID, not a raw pixel-pointer substitution. Confirm actual palette allocation beside all fourteen hub events, player and follower.

## Agent-owned visual validation
1. Capture matched harbor/curator close-ups before and after, at 240×160 and integer enlargement. Include all four facings in a temporary fixture to detect missing/flipped frame or palette defects.
2. Traverse the hub intro and every service approach with a small follower and a large follower, plus a shiny example. Preserve the current object-resource budget and the nurse/Chansey, PC and attendant appearances.
3. Audit six player outfit palettes, male/female sprites, normal/west hub entry, noon/night and return from a menu. The agent operates all fixtures/emulator input.
4. Readability evidence also covers the existing Route35 Pokémon at (10,39), (12,16), (12,19), (26,16), (28,9), (32,45), and NationalPark_Normal southern approaches around (14,47), (25,44), (29,44), (26,47). These are capture targets, not preapproved coordinate edits. Verify runtime position and visible active events; do not assume every map.json event is loaded simultaneously.
5. If these captures prove a real obstruction, record its exact scene/condition and a bounded proposed fix in this issue. Routine evidence gathering stays with the agent. Do not silently move trainers, roaming Pokémon or lights as part of a two-sprite style change.

## Acceptance
- Only the two specified event graphics IDs change in the hub data; service scripts, coordinates, movements, flags, elevation and fourteen-event count remain identical.
- Correct palette, walking/facing animation and shadow; no substitute graphics or palette corruption with large/shiny followers.
- `python3 test/overworld/ValidateMapEvents.py` and `python3 test/overworld/ValidateOwMonPlacements.py` retain the baseline result.
- Run `test/overworld/lua/OwMonSprites.lua`, `HubIntroTour.lua`, `HubIntroTourFollower.lua` and relevant service checks with the tracked runner. Establish baseline first and fix regressions attributable to this change.
- Provide evidence and a normal-controls final playtest: visit both NPCs, interact, then walk past the nurse with a follower. No owner debug setup.

Estimated effort: ½–1 day for the swap and full verification; readability evidence may take another day. Visual impact: small individually, useful for hub consistency.
Baseline inspected: master `45e1bf82ca5c2728910127863b926e627d4f18fc`.

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
