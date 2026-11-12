# Seven-variant owner feedback revision

Buddy Scarf Eevee is removed from gameplay, forms, scripts, NPC placement, flags, checklist and active art. Pirate's existing species number1580 is retained; only catalog positions compact. Active collection count7,5 gifts and2 catch encounters. Shared-gender art remains.

Requested visual corrections:
- Balloon front/back: replaced white strokes with colored highlight patches and darker rounded edges. Pinned battle palette retains the shading and original bright-yellow body tone within4bpp.
- Squad: long pointed outer lens corners, small glints, short temple arms. No band across the back of the head.
- Firefighter: closed shell, shaded panels, raised ridge, full brim, shield badge, rear guard and reflective marks. Both battle views and small sprites were updated.
- Pirate: rerouted the strap and protected the entire native uncovered-eye region in battle back, south follower and east follower. West patch fully covers its intended eye.

Pixel comparisons against the base sprite remapped through the output palette passed for open-eye and outline regions: back x35:44,y13:25; south frames0/1 x17:22,y17:23; east frames6/7 x16:20,y18:23. Independent visual review also checked that all three white pixels of the west-facing eye are covered by its single patch and that no second patch appears.

Verification on immutable ROM SHA256 `e8c2025a08b983f428aa65d2a0f512ef7c5e1b53b7df84ea07770040734e22e1`:
- production build succeeded;
- 7 complete indexed sets,79 nonempty frames, palette/hash/runtime-binding checks passed;
- host23/23;
- visual127/127;
- UI1326/1326, including actual inherited-scroll regression;
- mechanics5/5;
- sources31/31;
- capture23/23;
- diff whitespace check passed.

Inspected actual battle and all four follower-direction screenshots for the four revised designs, plus the checklist's second page showing0/7 and only Flower Crown/Pirate. No full campaign, actual PC storage screen or full Fly transition is claimed.

Final review artifacts: `graphics/pokemon/special_collection/review-seven-revised.png` and `review-seven-details.png`. Owner art approval remains outstanding. No commit, PR or merge. Historical8/10-variant review images and evidence are superseded, not active catalog assets.
