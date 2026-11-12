# Special collection native art

`build_art.py` builds all seven collection variants from the repository's native Pokémon sprites and deterministic pixel accessories. It preserves native frame geometry and emits indexed PNGs, JASC palettes, graphics declarations, follower frame tables, and a SHA-256 manifest. It requires Python 3 and Pillow.

```sh
python3 tools/special_collection/build_art.py
python3 tools/special_collection/verify_art.py
python3 tools/special_collection/verify_pikachu.py
python3 tools/special_collection/review_art.py
```

Outputs live in `graphics/pokemon/special_collection/`. `review.png` displays every frame at 2× nearest-neighbor scale. Generated declarations live in `src/data/graphics/special_collection.h` and `src/data/object_events/special_collection_pic_tables.h`.

Each variant has two 64×64 front frames, one 64×64 back, two 32×32 party icon frames, and six 32×32 follower frames. Pirate has eight follower frames, including explicit east-facing art for its asymmetric accessories. All seven variants share the same art across genders, as requested during owner review. Ordinary gender ratios are unchanged. Battle and follower palettes are per variant; icons use the engine palette index recorded in the manifest.

Classic Cap reuses the existing original-cap Pikachu battle and icon art with collection-local black ear tips, and supplies matching direction-specific follower caps. Its two front slots contain the same pose. Other variants retain the base species' available front and walking poses with accessories added per view. The image service did not produce these assets.

## Verification boundary

`verify_art.py` checks all seven sets, 79 nonempty frames, PNG dimensions, indexed color bounds, palette ownership, shared-gender coverage, and manifest hashes. Passing those contracts does not prove in-game rendering or animation. The contact sheet supports visual review; runtime integration and gameplay tests are separate.

## Optional sheet importer

`import_art.py` is an alternative pipeline for accepted external sprite sheets. It expects four columns and three rows per variant: front pose 1, front pose 2, back, icon; south idle/step and north idle/step; west idle/step and east idle/step. It duplicates the supplied icon into both icon slots. Running it replaces the native asset outputs and requires fresh visual and contract review.

Earlier Classic Cap and Surfboard image-service attempts were rejected at output moderation (`other`), request IDs `6feb78c9-7b98-4166-899e-0da049b69204` and `751802a5-ed47-4e99-b61a-dd38dbf954fa`. No accepted generated sheets were imported.

## Owner alignment revision (2026-11-12)

The active build now contains seven variants. Explorer Treecko, Swim Ring Mudkip, and Buddy Scarf Eevee were removed at the owner's request, including gameplay distribution and checklist entries. Separate female art was also removed; normal gender ratios remain, with one shared appearance per entry.

The rejected pass used a common accessory anchor even where the underlying head moved between poses. A source-pixel comparison established these front-pose translations: Squirtle (-1,-2), Eevee (0,+1), Totodile (+2,-1). Icon second poses move one pixel down. The builder now draws accessories on a separate overlay and follows those measured translations. Follower head anchors remain fixed within each walking pair.

First-pose changes fit the glasses to the eyes, reduce the helmet brim, run the crown along the forehead, lower the scarf below the chin, and give the Totodile icon its own eye-patch coordinates. Cap ears overlap the cap; board perspective changes with follower direction; balloons have pose-specific string anchors, knots and shaded edges. These are deterministic edits of the native source sprites. Owner approval is still required before merge.

## Seven-variant feedback pass

Replaced the balloon white strokes with tonal color patches and shaded edges. The battle balloon palette preserves those tones within4bpp. Squad shades now have long pointed corners, small glints, short temple arms and no band across the back of the head. The helmet has a closed shaded shell, ridge, shield badge, full brim, rear guard and reflective marks. Pirate accessories leave the original uncovered eye pixels clear in the back, south and east views; the west patch is centered on its actual visible eye. Buddy Scarf was removed from the active art and gameplay catalog.

## Pikachu ear tips and surf wave

Only the native ear-tip masks of Classic Cap and Balloon front/back sprites are recolored to opaque RGB16/16/16. The legacy Original Cap source files and cap shading are unchanged. `verify_pikachu.py` verifies all400 masked pixels after palette conversion, including both front poses.

Surfboard Pikachu now rides a blue curling wave with foam in both battle poses, its back view and every follower direction. The board and follower body are fitted above the wave without clipping; battle/body geometry remains native. The wave is part of the mount art during Surf. Dedicated surf palettes retain yellow skin, red cheeks, black tips and water/foam colors. Party icons remain the compact board-only design.

`review_pikachu.py` produces `review-pikachu-wave.png` at3× native pixel scale and snapshots the full sheet to `review-seven-wave.png`. Owner review remains required before merge.
