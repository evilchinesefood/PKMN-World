# Eight-variant alignment revision

Owner requested removal of Explorer Treecko and Swim Ring Mudkip and a further detail/alignment pass on all eight retained variants. The dropped species, forms, distribution NPCs, tasks, checklist entries and asset outputs are absent from the active build. Ordinary retained genders still share the same artwork.

Measured native source-head translations corrected the attachment model: Squirtle front pose 2 (-1,-2), Eevee (0,+1), Totodile (+2,-1). Icons use their own anchors and second-frame bob. Follower scarf anchors are direction-specific, clearing the nose/mouth and sitting at the rear neckline. Other refinements cover cap ear occlusion, board perspective, balloon strings and knots, fitted lenses and helmet, crown forehead contour, and a separate icon eye patch.

Art contract: 8 complete indexed sets, 90 nonempty frames; exact active directories, manifest hashes, shared-gender coverage and runtime icon palette bindings pass. Production build passed. No dropped species/symbols remain in src/include/data or current art scripts/declarations.

ROM `199900ac8cf91a40a2f9753a8e0f5ade86545e9f7fc596d78c5bb25c98189e29`: visual 149/149, mechanics 5/5, sources31/31, capture23/23. Runtime sprites were inspected in battle, party, and follower south/north/west views. Host validation23/23 passed. Capture checks cover both retained catches and repeat/recovery paths.

The initial UI state suite1318/1318 passed but screenshot inspection exposed inherited BG scroll shifting text offscreen. This is explicitly not accepted visual evidence for the checklist. The initialization fix and fresh UI regression are recorded below when complete.

The final art sheet remains subject to owner approval. No merge. No full campaign, actual PC storage screen or full Fly transition tested.

## Checklist rendering correction

Dex startup left BG0 vertical scroll at80 pixels. `InitCollection` now resets both BG axes through the engine API. The new regression first observes the real Dex offset80, then checks both checklist pages and all8 details for zero scroll. The unfixed ROM failed all10 new checks; the corrected ROM passed1329/1329 UI checks. Both pages and the Pirate detail screenshot were inspected: header/count0/8, aligned row icons/text, and complete hint text are visible.

Final production ROM SHA256: `3b23d0f7687174d860e7f28f4549480b0a72285ea3b5d3c4c8151c06fe1afda2`. Build `/tmp/pkmn-386/build-eight-ui/`; UI `/tmp/pkmn-386/ui-eight-fixed/`. The only production delta from the art/gameplay-tested build is this menu scroll initialization fix. Art assets are unchanged. `git diff --check` passed.

Review artifacts: `graphics/pokemon/special_collection/review-eight-aligned.png` and `review-eight-motion.gif`. The GIF alternates source poses for alignment review; it does not reproduce the engine's entire battle animation sequence.

Principles used: Attack the Premise replaced generic fixed accessory placement with measured anatomical anchors; Prove It Works required actual screenshot inspection, which exposed the scroll defect despite passing state assertions.
