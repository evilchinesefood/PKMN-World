# Regional wardrobe artwork

The catalog adds Kanto Vest, Johto Track and Hoenn Explorer for Brendan, and
Kanto Jacket, Johto Overalls and Hoenn Cape for May. Each has Red, Blue, Green,
Purple, Black and Pink. The original designs remain separate catalog entries.

The new garments are native indexed geometry over the project's existing
Brendan and May poses. They retain the original head, face, hands, movement
registration and equipment. Their new vest openings, jacket panels, collars,
pockets, skirt, bib and cape shapes are drawn in pixel coordinates. These are
new clothing drawings, not alternate palettes of the original clothes.

## Source and reproduction

The source bases are the matching files under
`graphics/object_events/pics/people/{brendan,may}` and
`graphics/trainers/{front_pics,back_pics}`. Their existing project attribution
continues to apply. The new garment coordinates and cabinet were authored for
issue #374. No external sprite pack is included. Two image-generation concept
requests failed before producing an image. No AI-generated bitmap is part of
these assets.

Run these commands from the repository root with Pillow installed.

```sh
python3 tools/player_outfits/build_art.py
python3 tools/player_outfits/review_art.py
python3 tools/player_outfits/verify_art.py
```

The generator changes only this asset directory. Its native garment patterns,
front-picture panels, animation placement rules and back-picture masks are the
editable source. All resulting PNGs remain indexed with at most 16 entries.
`manifest.json` records every source, output, dimension, animation frame count,
placement and content hash. No frame is silently replaced with an original
outfit sheet.

## Palette ownership

Every design deliberately uses the same protected index layout, so the six
existing color names remain consistent. Its `ow.pal` and `trainer.pal` are
explicit authored Red bases. The per-design contract is also in the manifest.

| Drawing | Main garment | Other clothing | Protected entries |
| --- | --- | --- | --- |
| Overworld | 13 shadow, 12 light | 11/10 band and bag | 0–9, 14–15 |
| Trainer front and back | 13 shadow, 12 light | 6/5 trousers, 11/10 band and bag | 0–4, 7–9, 14–15 |

New male trainer garments use the primary ramp from the existing male trainer
color row at indices 13/12 for non-Red variants. The original male sprite uses
those entries for accents, so applying its trim ramp would turn the new Black
tops gold. The new designs intentionally share the primary ramp while keeping
the original design's palette behavior unchanged. Red restores each design's
own base. All other color ramps retain the existing gender and drawing-specific
authored values. Neither source geometry nor variants alter skin or hair colors.

## Pose coverage

Each of the six designs has twelve source sheets. Walking and running include
all directions and steps. Mach Bike and Acro Bike include the complete original
riding frame sequences. Fishing includes all cast directions and phases.
Watering, field moves and decorating preserve their original pose ordering.
Surfing also supplies the flight rider presentation. Trainer front pictures
serve both picker and local trainer card. Back sheets include all four send-out
frames.

New underwater sprites retain the original submerged silhouette and explicitly
draw each style's visible garment panels. They use the protagonist's normal
palette, including the selected clothing color, rather than silently returning
to the original outfit. The original style keeps its original underwater art
and dedicated palette unchanged. This is a deliberate new-style underwater
presentation, not a claim that the old underwater colors are shared.

## Review

`review/concepts.png` records the first native design review before all poses
were produced. `review/catalog.png` shows the final 48 character/style/color
combinations. The six `review/*-poses.png` sheets cover every production source
pose. These are native source-art reviews. They do not replace the separate
in-game picker, field, card and battle capture evidence.
