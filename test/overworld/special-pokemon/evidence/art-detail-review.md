# Owner-requested art detail pass

Owner requested removal of separate female art, refinement of Classic Cap Pikachu followers, and another detail pass on all seven non-Pikachu looks. Merge remains blocked pending owner approval of the revised sheet.

All ten collection entries retain ordinary genders but now use shared battle, icon, and follower graphics. Removed the twenty female PNGs and the corresponding graphics/species overrides. No base-species or legacy Original Cap records changed.

Refined cap direction/panel/brim details; pointed Squad lenses and glints; firefighter dome seams, rim and badge; crown petals/leaves; scarf folds/knot/tails; pirate bandana ties/dots and patch; explorer satchel flap/buckle/stitching; and the swim ring's shaded four-panel tube. The assets are generated from the native pixel-art builder using the previously authorized method.

Validation:
- 10 complete indexed sets, 114 nonempty frames, palette and hash contracts passed.
- Production `make modern TOOLCHAIN=/opt/devkitpro/devkitARM -j8` succeeded.
- ROM SHA256: `b9583fc5a4a97ce4433436c4d3c9cb8e0eeb2c9a85aa736e49071285c75123c0`.
- Visual runtime suite: 175/175 assertions, ten variants plus five female samples; 109 screenshots.
- Inspected battle, party and south/north/west follower contact sheet for all ten, plus male/female Classic Cap battle comparison. Female graphics overrides are absent; normal fallback uses the shared collection art. Whole screenshot crops are not pixel-identical because screen rendering also varies, so no screenshot pixel-equality claim is made.
- The suite also exercises east movement, summary opening and board/ring water movement.
- `git diff --check` passed.

Evidence: `/tmp/pkmn-386/visual-detail/`, immutable build `/tmp/pkmn-386/build-detail/`, build log `/tmp/pkmn-386/build-detail.log`. Snapshot sheet: `graphics/pokemon/special_collection/review-detail-pass.png`.

This is an art revision and focused regression check. No full campaign, actual PC storage screen or full Fly transition was tested. A passing runtime suite is not owner art approval. No merge performed.
