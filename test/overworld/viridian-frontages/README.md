# Viridian building frontages — #348

[Open the five-minute comparison](review/index.html).
Baseline: merged stage 2, `cf66c5e65d2e0e5fbbf6215ffc6fc59350567c3d`.

This completes the three-stage Viridian pilot. **25 cells in one map** reuse existing
metatiles. No tileset definitions, bitmap art, palettes, scripts, events, engine
code or other maps change. The prior gardens and ground transitions are preserved.
Existing [credits](../../../CREDITS.md) apply.

## Treatments and provenance

- **Northern house:** reuse the school's `0x298`, `0x29A–0x29C` flower-box fronts and
  `0x2A0/0x2A2` lower pieces. Its two existing bushes remain in front of the other
  planter ends, retaining their appearance and collision. Match the right lawn edge
  to the existing left apron with `0x0BF/0x0C7/0x0CF`.
- **School:** retain its original window boxes as the reference; complete its right
  lawn edge with the same existing mown-ground family. The prior junction flare is
  untouched.
- **Pokémon Center:** paired flowers on the two side lawns, using the existing
  stage-1 flower composites `0x2E5/0x2DF` and bottom lawn corners `0x0CD/0x0CF`.
  The entrance and sign remain clear.
- **Mart:** one planted side and one plain mown side, using the same existing ground
  pieces. The smaller treatment distinguishes it from the Center.
- **Gym:** two restrained mown strips at the sides of the open forecourt, using
  `0x0CD/0x0CF`. No new flowers or objects. The old man, door trigger, recoil path and
  sign cells are unchanged; the sign can still be read while standing on the lawn.

All additions remain within the issue's five frontage zones. No building footprint,
roof silhouette, door graphic, warp or sign changed. No new tileset capacity is
used; all 102 existing secondary definitions remain byte-identical. No lamps or
imported graphics were added.

[Exact edits](edits.json) records every coordinate and old/new metatile.
[Plan](plan.json) pins the merged baseline, baseline ROM hash and camera positions.
[Scope](review/scope.png) marks protected cells red and edited cells yellow;
[atlas](review/atlas.png) shows the reused pieces. These are labeled source renders;
the primary comparisons are unmodified native 240×160 emulator screenshots.
Historical stage-1 and stage-2 tools and evidence are unchanged.

## Verification

| Check | Result |
|---|---|
| Development build / content validation | Pass |
| Collision, elevation and nonvisual attributes | All 1,920 cells match the baseline |
| Protected cells | 380 exact matches, including 69 garden cells and all 70 prior path edits |
| Reachability from five doors and three connections | Same 843-cell walking component at each entry |
| Four shared routes | Route2/22/28/26North source renders identical |
| Source facade glass | 1,064 tracked pixels retain position, palette bank and color index |
| Native glass at noon, dusk, night | 3,192 pixel comparisons, all equal and visibly rendered with the expected hardware palette colors |
| Matched captures | 45/45 before and 45/45 after; 30 native screenshots |
| Runtime background palettes | All 15 before/after pairs byte-identical |
| Frontage movement/followers, doors, signs, story states, menus and Save/Continue | 55/55 |
| Prepared save on unpatched delivery ROM | 3/3 |
| Full existing Lua regression sweep | 50 suites / 1,331 assertions, including CatchTutorial |

The fixture seeds an ordinary late-story state for five door-entry/exit checks,
then tests both the early roadblock and open tutorial corridor. It exercises the
gym's real locked-door message and two-tile recoil, and the nearby old man's two
state-dependent dialogues. Four signs are verified by their text and return of
control. The actual early catch sequence is separately exercised on the unpatched
ROM by CatchTutorial. Player/follower routes cross the planted edges, and the exact
same synthetic save passes Continue on the unpatched delivery ROM.

The ordinary-walking flood fill does not model Surf or ledge jumps. Cell-level
nonvisual equality covers their map semantics; the gym's recoil is also tested
in the emulator. The house's original ledge and impassable bushes stay intact.

### Window proof

`panes.py` decodes each source metatile to visible palette-bank/color-index pixels,
including flip bits and transparent overlay pixels. It compares each facade's
complete glass mask before/after. Existing house/school blue panes retain palette 3
and their ordinary night tint; existing shared warm glass retains palette 7 and
its night treatment. This pass does not change which panes illuminate.

The native check projects those masks into the matched screenshots using the
fixed camera anchors. For every pane pixel it verifies that **both** screenshots
show the expected RGB color from that run's dumped hardware background palette.
An unchanged palette alone cannot pass if a flower box or actor covers the glass.
The audit includes the house's 108 pane pixels, so the flower-box swap is verified
rather than inferred from its appearance.

The publisher additionally pins the exact baseline ROM, checks the map and tileset
blobs linked in both ROMs, reruns the source audit, checks all positive suite evidence
against run-time Lua/ROM hashes, and verifies all 30 native images before publishing.
ROMs and saves stay local. The fixture is never linked into the delivery ROM.

## Reproduce

Build and preserve the pinned baseline ROM/ELF before authoring. With Python 3,
Pillow, devkitARM and the repository's Lua-enabled mGBA available:

```sh
python3 test/overworld/viridian-frontages/art.py author
python3 test/overworld/viridian-frontages/art.py check --out /tmp/frontages-audit
make modern TOOLCHAIN=/opt/devkitpro/devkitARM -j8
make validate
```

Preserve the tested delivery ROM/ELF; rebuilding after committing changes the
embedded version stamp and its hash. Build before/after fixtures from the same
final source, each against its matching ROM and ELF:

```sh
python3 test/overworld/visual-features/build_fixture.py --repo . \
  --rom "$ROM" --elf "$ELF" --out "$FIXTURE" --source test/overworld/viridian-frontages/fixture.c
python3 test/overworld/viridian-art/run_suite.py --repo . --fixture "$FIXTURE" \
  --suite test/overworld/viridian-frontages/capture.lua --out "$CAPTURES"
python3 test/overworld/viridian-art/run_suite.py --repo . --fixture "$AFTER_FIXTURE" \
  --suite test/overworld/viridian-frontages/lifecycle.lua --out /tmp/frontages-runs/lifecycle
python3 test/overworld/viridian-art/run_suite.py --repo . --rom "$DELIVERY_ROM" \
  --suite test/overworld/viridian-frontages/delivery.lua \
  --save /tmp/frontages-runs/lifecycle/VisualReview.sav --out /tmp/frontages-runs/delivery
PW_OUT=/tmp/frontages-runs/regression test/overworld/run-all.sh "$DELIVERY_ROM" \
  > /tmp/frontages-sweep.log 2>&1
cp /tmp/frontages-sweep.log /tmp/frontages-runs/regression/sweep.log
python3 test/overworld/viridian-frontages/render_review.py \
  --before-rom "$BEFORE_ROM" --before-elf "$BEFORE_ELF" \
  --delivery "$DELIVERY_ROM" --delivery-elf "$DELIVERY_ELF" \
  --before-fixture "$BEFORE_FIXTURE" --after-fixture "$AFTER_FIXTURE" \
  --before /tmp/frontages-runs/before --after /tmp/frontages-runs/after \
  --lifecycle /tmp/frontages-runs/lifecycle --delivery-run /tmp/frontages-runs/delivery \
  --regression /tmp/frontages-runs/regression --out test/overworld/viridian-frontages/review
```

`author` refuses unrelated edits and should not overwrite future stages. The audit
reads the immutable baseline from Git and rejects production changes outside this
map. A different compiler/version-stamp baseline needs its own verified provenance
and new captures, not a silent substitution under the old baseline hash.

## Owner review

Compare the house, Center and Mart, then switch to dusk and night. The school and
gym are optional views below. Judge composition and how the planting sits beside
the buildings; mechanics and window visibility have already been checked.

The optional synthetic save starts beside the Center at night with a Pikachu
follower. Keep it separate from personal saves. No manual fixture setup is needed.
