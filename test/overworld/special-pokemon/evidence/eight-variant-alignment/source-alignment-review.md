# Native sprite alignment review

Read-only inspection of source assets and the rejected detail-pass sheet. No repository edits.

## Confirmed pose translations

Exact-match search on opaque head patches, relative to first pose:

| Source | Front pose 1 offset | Matching patch pixels | Icon pose 1 offset |
|---|---:|---:|---:|
| Squirtle | (-1,-2) | 272/272 | (0,+1),72/72 |
| Eevee | (0,+1) | 152/156 | (0,+1),54/54 |
| Totodile | (+2,-1) | 108/108 | (0,+1),76/90 |
| Pikachu | not measured | — | approx(-1,+1),75/90 |

All tested follower head pairs (0/1,2/3,4/5) have (0,0) translation. Source layouts are standard: two vertical 64x64 fronts, two vertical 32x32 icons, horizontal 32x32 south/south/north/north/west/west. No slicing-order issue found.

## First-pose placement recommendations

- Squad front: eyes x19/y22 and x27..30/y21..25. Fit distinct far lens x17..22,y20..24 and near lens x25..33,y19..26. Current symmetric mask is broad and the second pose fails to follow the head. Back visible eye is x49,y19..23; band x30..47,y19..21, lens x47..51.
- Helmet front: crown x24..29,y14; dome centered~26 with brim y17, radius9–10,height7–8. Current ±15 brim extends31px across an~18px head. Back crown center(39,10), brim around16,radius10. Icon brim near15 and x5..18; current brim17 covers the eye at y18.
- Flower crown front: follow forehead diagonal with flower centers around(21,27),(27,26),(32,25), leaf tips inside x19..35. Current leaves reach x12 into empty space. Back flower centers(31,27),(37,27),(43,26), leaf ends x26..48. Icon center(13,18).
- Buddy scarf front: chin reaches~37; collar around(27,39), knot(31,40), tails end~47. Current cy37 overlaps chin. Back collar across x29..47,y35..38, knot near left edge(30,37), not center35. Profile follower knot should be toward body/right(x18,y25), not toward face(cx-2). Icon collar around(13,25), knot near17; shorten tails for32px frame.
- Pirate front: eye x28..32,y18..24. Use patch around x27..32,y19..25, with bandana fitted to upper head x22..36 (current x16..36 floats left of head). Head1 moves(+2,-1). Icon visible eye around(15,15), but current small function computes patch center(11,19), directly over the mouth. Separate icon patch coordinates from follower patch math. Icon bandana around center(14,14), patch(15,15–16).

Icons should have their own silhouettes instead of reusing follower accessory geometry: their heads are smaller and posed at a different angle. Back and side scarf/crown shapes also need actual perspective, not only changing an x/y anchor.

Reference grids: `squirtle.png`, `eevee.png`, `totodile.png` in this directory.

## Revised assets: residual review

The revised battle-pose offsets and icon anchors correct the earlier concrete issues. One remaining anatomical overlap was found in `decorate()`'s Buddy Scarf follower branch: all directions still use `cy=24`.

- South source nose is exactly `(15,24)`; mouth spans roughly x14..16/y25. The red collar currently crosses these pixels. Use a collar around y26.
- West profile cheek/mouth extends through y23–24. Use a collar around y26.
- North head ends at y20 and mane starts at21, so collar belongs around y21–22, not24.

This requires per-direction scarf anchors. No other definite residual alignment defect was found in the revised front/icon frames. Pirate bandana crown height was already being corrected by root and is not a new finding.
