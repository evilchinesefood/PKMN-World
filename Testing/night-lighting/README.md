# Regional night lighting

Owner scope: extend lit windows and street fixtures through Johto, Hoenn and
Kanto using the existing engine and repo artwork, with automated verification
and a short final visual review. Sevii is included with Kanto.

Open [the visual review](evidence/review/index.html) in a browser. It contains
three highlighted before/after comparisons, day/dusk/night controls, four lamp
examples, and optional captures of all 49 maps. Native screenshots are in
[media](evidence/review/media); no ROM or save is published here.

## Coverage and implementation

- All 49 maps classified as towns/cities have building lighting and either new
  fixtures or an existing lamp network. This includes 14 Johto maps, 16 Hoenn
  maps and 19 Kanto/Sevii maps. These are map counts: both Indigo exteriors,
  Saffron's connection map, Lake of Rage, Mt. Silver and Safari Zone Gate count.
- 71 lamps/lanterns are added to 44 maps. Violet, Goldenrod, Ecruteak, Olivine
  and Blackthorn retain their existing networks. The exact coordinates, new
  metatile IDs and source tiles are recorded in [lamps.json](lamps.json).
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

The modern lamp reuses Olivine's cap, bulb and foot
(`data/tilesets/secondary/olivine_city`, metatiles 0x348, 0x350, 0x358).
Johto additions reuse Blackthorn's lantern
(`data/tilesets/secondary/blackthorn_city`, 0x298, 0x2A0).
Pacifidlog uses a one-cell cap/bulb fixture beside its Pokémon Center to preserve
the narrow dock. All donor art already belongs to the repo; the existing
[credits](../../CREDITS.md) continue to apply. No HnS Fuchsia graphics are added.

No new lighting engine, object sprites, lamp scripts, save fields or story flags
are introduced. Lamps are map tiles: their foot blocks movement, while the head
uses the appropriate drawing layer. Original ground effects and elevation are
retained. Allocation excludes animation DMA ranges, referenced/named metatiles,
script literal IDs and reserved metatile 1023 (`MAPGRID_UNDEFINED`).

## Reproduce the asset pass

Python 3 and Pillow are required. `BASE` must be a separate **unchanged** checkout
of `017a59de342ce5d8244144260da197b89f1239a0`. Run these from the feature checkout:

```sh
BASE=/path/to/baseline
python3 Testing/night-lighting/author.py --base "$BASE" --out .
python3 Testing/night-lighting/lamps.py --base "$BASE" --out .
python3 Testing/night-lighting/fallarbor_glass.py --out .
python3 Testing/night-lighting/check_data.py --base "$BASE" --repo . --out /tmp/regional-lighting-data
make modern TOOLCHAIN=/opt/devkitpro/devkitARM -j8
make validate
```

Run the three authors in order. They regenerate the listed assets and town map
cells; use a clean feature checkout, not a checkout containing hand-edited map
work. Placement overrides are explicit in `placement_overrides.json`.
`prepare_capture.py` is an authoring aid that rewrites camera positions and the
capture fixture. Do not rerun it for ordinary verification: changing viewpoints
requires recapturing **both** sides.

## Runtime verification

Use the Lua-enabled headless mGBA described in `Testing/mgba/README.md`.
Keep matched ROM/ELF pairs in stable directories while tests run. The shared
fixture builder verifies unused ROM padding and patches only disposable copies.

```sh
python3 Testing/visual-features/build_fixture.py --repo . \
  --rom /tmp/lighting-after/pokemonworld.gba --elf /tmp/lighting-after/pokemonworld.elf \
  --source Testing/night-lighting/fixture.c --out /tmp/lighting-capture
python3 Testing/night-lighting/run_captures.py --repo "$PWD" \
  --fixture /tmp/lighting-capture --out /tmp/lighting-runs/after
python3 Testing/visual-features/build_fixture.py --repo . \
  --rom /tmp/lighting-after/pokemonworld.gba --elf /tmp/lighting-after/pokemonworld.elf \
  --source Testing/night-lighting/lifecycle_fixture.c --out /tmp/lighting-lifecycle
python3 Testing/visual-features/run_fixture.py --repo "$PWD" \
  --fixture /tmp/lighting-lifecycle --suite Testing/night-lighting/lifecycle.lua \
  --out /tmp/lighting-runs/lifecycle
PW_OUT=/tmp/lighting-runs/regression Testing/run-all.sh /tmp/lighting-after/pokemonworld.gba \
  > /tmp/lighting-sweep.log 2>&1
cp /tmp/lighting-sweep.log /tmp/lighting-runs/regression/sweep.log
PW_OUT=/tmp/lighting-runs/delivery/ Testing/mgba-run.sh Testing/night-lighting/delivery.lua \
  /tmp/lighting-after/pokemonworld.gba /tmp/lighting-runs/lifecycle/VisualReview.sav
```

Build a clean baseline and repeat the capture with the same `fixture.c` for the
before side. Each town starts from an independent synthetic save reset. The
gallery publisher requires all fixture hashes, positive terminal verdicts,
matching PASS sentinels, the exact delivery ROM, and a green full sweep:

```sh
python3 Testing/night-lighting/render_review.py --repo . \
  --before /tmp/lighting-runs/before --after /tmp/lighting-runs/after \
  --before-fixture /tmp/lighting-before-capture --after-fixture /tmp/lighting-capture \
  --lifecycle /tmp/lighting-runs/lifecycle --lifecycle-fixture /tmp/lighting-lifecycle \
  --regression /tmp/lighting-runs/regression \
  --data-audit /tmp/regional-lighting-data/data-audit.json \
  --delivery /tmp/lighting-after/pokemonworld.gba --out Testing/night-lighting/evidence/review
```

The focused checks cover all 49 maps at noon, dusk and night (294 assertions per
build), plus 56 lifecycle assertions: lamp collision, leaving a loaded position
under a new fixture, normal doors, menus, wild battle/Run, and Save/Continue in
each region. `check_data.py` compares 35,180 original metatile renderings, checks
every new lamp has a lit bulb and preserved ground/depth, and rejects event/NPC
overlap or disconnected walking areas. Grid connectivity excludes water and
does not model directional ledges. The audit records 44 pre-existing invalid
metatile references rather than silently treating them as verified.
The original metatile attributes are also compared using their native blob width.
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
remain unchanged. Lamps have bright bulbs, without new ground-light pools.
The conservative placement pass adds one or two fixtures per uncovered map,
not a full street grid. Some surrounding routes inherit shared window palettes.

Source-art checks isolate daytime preservation from animation/NPC timing in
the captures. Synthetic saves may show intro props (notably Littleroot's trucks).
The final owner review is warmth, visual fit and lamp placement; the automated
checks already cover the listed functional flows. The local playtest bundle uses
the unpatched development ROM, as required by `RELEASING.md`.
