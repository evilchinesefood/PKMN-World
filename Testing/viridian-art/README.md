# Viridian landscaping — #346

[Open the five-minute comparison](review/index.html). Baseline:
`63c328ee3d6299bd94ce75d049a5ef3a7009bf72`.

The first stage arranges existing Kanto flowers and mown lawn tiles into five small
gardens and three southern flower clusters. It changes 59 map cells and appends
seven metatile compositions (112 bytes plus 28 bytes of attributes). No bitmap,
palette, script, event, door, collision, elevation or encounter data is changed.
The compositions use the existing mown ground's lower four tile words and the
existing flower's upper four words. Existing [credits](../../CREDITS.md) apply.

The primary night tileset and the original 95 secondary definitions are untouched.
The appended attributes retain the secondary's 32-bit format. Four other layouts
share this secondary; their source renders are checked for exact equality.
The next stages are [#347 ground transitions](https://github.com/evilchinesefood/PKMN-World/issues/347)
and [#348 building frontages](https://github.com/evilchinesefood/PKMN-World/issues/348).

## Verification

| Check | Result |
|---|---|
| Development build / content validators | Pass |
| Collision, elevation and nonvisual attributes | All 1,920 cells identical to baseline |
| Protected story, actor and event cells | 65 exact cell matches |
| Walking components at five doors and three entrances | Same 843-cell component at every entry |
| Route2, Route22, Route28, Route26North | Source renders identical |
| Matched native captures | 45/45 assertions before and after; 30 screenshots |
| Runtime background palettes | All 15 paired day/dusk/night snapshots identical |
| Garden walking, follower, five doors, three bidirectional connections, gym lock, menus and Save/Continue | 39/39 |
| Prepared save on unpatched delivery ROM | 3/3 |
| Full existing Lua regression sweep | 50/50 suites, 1,331 assertions, including CatchTutorial |
| Publication failure checks | Missing delivery proof, wrong delivery hash, wrong baseline ROM and changed current map all rejected |
| Browser checks | Day/dusk/night controls, all 30 images, evidence links and mobile width pass in Chromium |

[Map audit](review/audit.json), [exact edits and source hashes](edits.json),
[ROM/capture provenance](review/manifest.json), [runtime evidence](review/verification/),
[full regression result](review/regression.log).

The walking-component audit is conservative ordinary walking; it does not simulate
Surf or ledge jumps. Cell-level nonvisual attribute equality covers those mechanics,
and the focused runtime suite separately exercises the gym's actual jump-back.
The fixture seeds a later-story state for ordinary door checks, including the
Mart's completed Parcel scene. The existing CatchTutorial suite exercises the
early-story old-man sequence on the unpatched ROM. No story code was changed.

## Reproduce

`art.py` reads its baseline directly from immutable Git blobs. The Git history must
contain the pinned baseline. Python 3 and Pillow are required. `author` refuses to
replace unrelated edits; it is a stage-1 authoring tool and should not overwrite
later stages. Preserve an untouched baseline ROM/ELF before applying the map edits.

```sh
python3 Testing/viridian-art/art.py author
python3 Testing/viridian-art/art.py check --out /tmp/viridian-audit
make modern TOOLCHAIN=/opt/devkitpro/devkitARM -j8
make validate
PW_OUT=/tmp/viridian-runs/regression Testing/run-all.sh pokemonworld.gba \
  > /tmp/viridian-sweep.log 2>&1
cp /tmp/viridian-sweep.log /tmp/viridian-runs/regression/sweep.log
```

Use the same `fixture.c` for both clean-baseline and changed ROM captures:

```sh
python3 Testing/visual-features/build_fixture.py --repo . \
  --rom "$ROM" --elf "$ELF" --out "$FIXTURE" --source Testing/viridian-art/fixture.c
python3 Testing/viridian-art/run_suite.py --repo . --fixture "$FIXTURE" \
  --suite Testing/viridian-art/capture.lua --out "$CAPTURES"
```

Run `lifecycle.lua` through the same runner on the changed fixture, then verify its
generated `VisualReview.sav` on the unpatched ROM:

```sh
python3 Testing/viridian-art/run_suite.py --repo . --fixture "$AFTER_FIXTURE" \
  --suite Testing/viridian-art/lifecycle.lua --out /tmp/viridian-runs/lifecycle
python3 Testing/viridian-art/run_suite.py --repo . \
  --suite Testing/viridian-art/delivery.lua --rom "$DELIVERY_ROM" \
  --save /tmp/viridian-runs/lifecycle/VisualReview.sav --out /tmp/viridian-runs/delivery
python3 Testing/viridian-art/render_review.py \
  --before-rom "$BEFORE_ROM" --before-elf "$BEFORE_ELF" \
  --delivery "$DELIVERY_ROM" --delivery-elf "$DELIVERY_ELF" \
  --before-fixture "$BEFORE_FIXTURE" --after-fixture "$AFTER_FIXTURE" \
  --before /tmp/viridian-runs/before --after /tmp/viridian-runs/after \
  --lifecycle /tmp/viridian-runs/lifecycle --delivery-run /tmp/viridian-runs/delivery \
  --regression /tmp/viridian-runs/regression --out Testing/viridian-art/review
```

Publication first requires the exact baseline ROM SHA-256 pinned in `plan.json`.
`run_suite.py` records the suite-source and ROM hashes at execution time; publication
rejects stale source hashes, failed runs and missing records.
Publication verifies the map/metatile/attribute bytes actually linked in both ROMs
against the baseline and authored source, validates fixture hashes and all positive
run verdicts, and reruns the source audit. An existing audit file is never an input.
Native screenshots are unchanged emulator output. Full-map images are explicitly
labeled source renders and omit actors. Disposable fixture hooks are absent from
the delivery ROM. ROMs and saves remain local and are not uploaded to GitHub.

## Final visual check

Use the gallery's eastern garden, west approach and pond views, then switch to
night. The optional save begins in Viridian near the eastern garden, with a
Pikachu follower and the gym unlocked. Walk into the garden, return to the Center,
then visit the pond and west approach. This is a synthetic test profile; keep it
separate from personal saves. The agent has already performed the mechanical checks.
