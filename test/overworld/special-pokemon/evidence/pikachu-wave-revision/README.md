# Pikachu ear-tip and wave revision

Owner requested black ear tips on Hat/Classic Cap and Balloon Pikachu front/back sprites, plus a wave beneath Surfboard Pikachu in front, back and overworld views.

Classic source gray ear fills are recolored only inside native ear masks. Balloon gray had quantized to green; those masks now use a reserved opaque RGB16/16/16 palette entry. The legacy Original Cap graphics and cap shading are untouched. `tools/special_collection/verify_pikachu.py` verifies400 actual output ear-tip pixels across both front poses and backs.

Surfboard has a curling wave, blue body and foam beneath the board. All6 follower frames include it, with profile-direction mirroring and slight foam motion. The battle body remains unclipped; the follower and board sit above the wave. The surf palette retains yellow skin/red cheeks/black tips. Party icons stay board-only.

Validation:79-frame art contracts pass;400 ear-tip pixel checks pass; four non-Pikachu sets have unchanged manifest hashes; production build passes; visual emulator suite127/127 passes. Inspected front/back battle rendering for all3 Pikachu and actual Surf mount/water-movement screenshots showing the wave. No gameplay logic changed and no full campaign was rerun.

Final ROM SHA256 `06d7acdddcdfd7b3e8106b1b035a48de950480aaeca4f73f6205f24dae2597a4`, immutable copy `/tmp/pkmn-386/build-wave-final/`. Actual runtime `/tmp/pkmn-386/visual-wave-final/`. Earlier `/tmp/pkmn-386/build-wave/` is superseded by the palette-preserving final version.

Review: `graphics/pokemon/special_collection/review-pikachu-wave.png`; full7-entry sheet `review-seven-wave.png`. Owner approval remains pending. No merge.
