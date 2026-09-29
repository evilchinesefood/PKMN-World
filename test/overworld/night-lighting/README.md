# Regional window lighting

Owner scope: extend warm window lighting through Johto, Hoenn and Kanto using
the existing engine and repo artwork. Sevii is included with Kanto. The owner
rejected the added lamp posts: all 71 additions have been removed, including
lanterns and the small dock fixture. Existing street fixtures are retained.

Open [the visual review](evidence/review/index.html) in a browser. It contains
three highlighted before/after comparisons, day/dusk/night controls, and
optional captures of all 49 maps. Native screenshots are in
[media](evidence/review/media); no ROM or save is published here.

## Coverage and implementation

- All 49 maps classified as towns/cities have building lighting. This includes
  14 Johto maps, 16 Hoenn
  maps and 19 Kanto/Sevii maps. These are map counts: both Indigo exteriors,
  Saffron's connection map, Lake of Rage, Mt. Silver and Safari Zone Gate count.
- Hoenn and Kanto shared window graphics are copied into unused primary tile
  slots. New primary variants point those cells at dedicated secondary palette
  banks: Hoenn bank 12 / alternate 5, Kanto bank 7 / alternate 0. Existing
  roofs, water and walls keep their original palette indices. The variants
  share the original attributes and animation callbacks; their eight door
  registrations reuse the existing frames.
- 27 compatible secondary outdoor families provide the matching palettes;
  176 layouts using these families receive the appropriate primary variant.
  Johto's four primary families use alternate palette 12 for shared bank 3
  glass. Existing golden/red lantern colors are retained. The exact three-color
  New Bark/Cherrygrove bank-8 treatment from #335 is preserved.
- [local_glass.json](local_glass.json) lists safely isolated local glass colors.
  Fallarbor's normal-house panes need a separate transparent glass overlay,
  because their original colors also occur in unrelated structures.
- A secondary shared with different primary artwork (Indigo/Viridian) keeps
  its original secondary window tile references. Specialty families using the
  reserved palette bank retain the original primary. These exceptions prevent
  palette and graphic conflicts on neighboring maps.

All map cells, borders, metatile attributes, events and original street-fixture
placements match the baseline. The unused graphics and metatile definitions
created solely for the added lamps are removed. Window palettes and primary
window definitions are byte-identical to the version the owner approved. All
147 runtime background-palette snapshots (49 maps × day/dusk/night) also match
that version exactly; see [the retention check](evidence/review/window-retention.json).

No new lighting engine, object sprites, scripts, save fields or story flags are
introduced. Existing repo [credits](../../../CREDITS.md) continue to apply. No HnS
Fuchsia graphics are added. Graphic allocation excludes animation DMA ranges.

## Reproduce the asset pass

Python 3 and Pillow are required. `BASE` must be a separate **unchanged** checkout
of `017a59de342ce5d8244144260da197b89f1239a0`. Run these from the feature checkout:

```sh
BASE=/path/to/baseline
python3 test/overworld/night-lighting/author.py --base "$BASE" --out .
python3 test/overworld/night-lighting/fallarbor_glass.py --out .
python3 test/overworld/night-lighting/check_data.py --base "$BASE" --repo . --out /tmp/regional-lighting-data
make modern TOOLCHAIN=/opt/devkitpro/devkitARM -j8
make validate
```

Run the two authors in order. They regenerate the window assets; use a clean
feature checkout, not a checkout containing hand-edited tileset work.
`prepare_capture.py` is an authoring aid that rewrites camera positions and the
capture fixture. Do not rerun it for ordinary verification: changing viewpoints
requires recapturing **both** sides.

## Runtime verification

Use the Lua-enabled headless mGBA described in `test/overworld/mgba/README.md`.
Keep matched ROM/ELF pairs in stable directories while tests run. The shared
fixture builder verifies unused ROM padding and patches only disposable copies.

```sh
python3 test/overworld/visual-features/build_fixture.py --repo . \
  --rom /tmp/lighting-after/pokemonworld.gba --elf /tmp/lighting-after/pokemonworld.elf \
  --source test/overworld/night-lighting/fixture.c --out /tmp/lighting-capture
python3 test/overworld/night-lighting/run_captures.py --repo "$PWD" \
  --fixture /tmp/lighting-capture --out /tmp/lighting-runs/after
python3 test/overworld/visual-features/build_fixture.py --repo . \
  --rom /tmp/lighting-after/pokemonworld.gba --elf /tmp/lighting-after/pokemonworld.elf \
  --source test/overworld/night-lighting/lifecycle_fixture.c --out /tmp/lighting-lifecycle
python3 test/overworld/visual-features/run_fixture.py --repo "$PWD" \
  --fixture /tmp/lighting-lifecycle --suite test/overworld/night-lighting/lifecycle.lua \
  --out /tmp/lighting-runs/lifecycle
PW_OUT=/tmp/lighting-runs/regression test/overworld/run-all.sh /tmp/lighting-after/pokemonworld.gba \
  > /tmp/lighting-sweep.log 2>&1
cp /tmp/lighting-sweep.log /tmp/lighting-runs/regression/sweep.log
PW_OUT=/tmp/lighting-runs/delivery/ test/overworld/mgba-run.sh test/overworld/night-lighting/delivery.lua \
  /tmp/lighting-after/pokemonworld.gba /tmp/lighting-runs/lifecycle/VisualReview.sav
```

Build a clean baseline and repeat the capture with the same `fixture.c` for the
before side. Each town starts from an independent synthetic save reset. The
gallery publisher requires all fixture hashes, positive terminal verdicts,
matching PASS sentinels, the exact delivery ROM and its successful delivery run,
and a green full sweep. It recomputes the map audit from the baseline and current
source assets on every publication; a saved audit is never accepted as input.
The publisher verifies the baseline's Git revision and requires a clean working
tree before recording that revision in the gallery manifest:

```sh
python3 test/overworld/night-lighting/render_review.py --base "$BASE" --repo . \
  --before /tmp/lighting-runs/before --after /tmp/lighting-runs/after \
  --before-fixture /tmp/lighting-before-capture --after-fixture /tmp/lighting-capture \
  --lifecycle /tmp/lighting-runs/lifecycle --lifecycle-fixture /tmp/lighting-lifecycle \
  --regression /tmp/lighting-runs/regression \
  --delivery /tmp/lighting-after/pokemonworld.gba --delivery-run /tmp/lighting-runs/delivery \
  --out test/overworld/night-lighting/evidence/review
```

Publisher rejection checks also passed: missing delivery PASS, failed verdict,
wrong ROM, wrong suite, a FAIL sentinel, and changed metatile attributes in either
the baseline or reviewed source all abort before publication. A successful
`mgba-run.sh` delivery log/PASS is accepted without a `runner.log`.
Wrong baseline revisions and tracked or untracked baseline edits are also rejected.

The focused checks cover all 49 maps at noon, dusk and night (294 assertions per
build), plus 48 lifecycle assertions: normal doors, menus, wild battle/Run, and
Save/Continue in each region. `check_data.py` compares 35,180 original daytime
metatile renderings and requires all map cells, borders, events and metatile
attribute blobs to match the baseline. This verifies original collision,
elevation and walking effects for every map. The audit records 44 pre-existing
invalid metatile references rather than silently treating them as verified.
Three delivery checks prove the prepared save loads at night and can move on the
unpatched ROM; fixture hooks are not needed to continue playing.

The broad sweep exposed a separate harness defect in `NationalParkTiles.lua`:
manually clearing live object/sprite allocation bits could corrupt movement.
It now freezes/parks generated encounters and lets the engine own cleanup. The
grass route is asserted, and the test passes on both the baseline and this ROM.
No encounter implementation changes are part of the lighting pass.

## Limits and owner review

This establishes town coverage; it does not promise every decorative window is
lit. Closed panes and special structures whose colors cannot safely be separated
remain unchanged. Some surrounding routes inherit shared window palettes.

Source-art checks isolate daytime preservation from animation/NPC timing in
the captures. Synthetic saves may show intro props (notably Littleroot's trucks).
The final owner review is window warmth and visual fit; the automated
checks already cover the listed functional flows. The local playtest bundle uses
the unpatched development ROM, as required by `RELEASING.md`.
