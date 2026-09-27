# Viridian ground transitions — #347

[Open the five-minute comparison](review/index.html).
Baseline: merged landscaping commit `e97b94307fca9e1b4de128433419f4bf35caeaf7`.

This stage changes **70 cells in one map**, using existing primary metatiles.
No tileset definitions, bitmap art, palettes, scripts, events, engine code or other
maps change. The prior landscaping and warm windows remain intact. Existing
[CREDITS.md](../../CREDITS.md) applies. Building frontages remain a separate #348.

## Composition

- **Southern approach:** a wider central arrival lines up with the northward city
  entrance and Route 1. The arms have a continuous lawn verge below the flowers.
  The central approach and sign access remain clear; each horizontal arm retains
  two paved rows, and its new lawn row retains its original walkability.
- **Eastern loop:** a lawn verge separates the southeastern paving from the ledge.
  The northern garden corner has a small flare; all prior garden cells and the
  wandering youngster's full movement range are untouched.
- **West entrance and central junction:** four-cell corner adjustments soften the
  west spur's lower entrance corner and flare the junction by the school approach.
  These are intentionally smaller changes than the two verges.

Yellow route paths and pale city paving remain distinct. The new grass is ordinary
walkable lawn, not encounter grass. All original walkable space remains walkable;
no fence, lamp, object or collision block has been added.

[Exact edits](edits.json) records each coordinate and old/new metatile.
[Plan](plan.json) pins the baseline commit and exact baseline ROM hash.
[Scope overlay](review/scope.png) shows protected cells in red and edited cells in
yellow; [atlas](review/atlas.png) shows the existing pieces used. Both are source
renders. The main comparisons are unmodified native 240×160 emulator screenshots.
The historical #346 gallery and its evidence are unchanged.

## Verification

| Check | Result |
|---|---|
| Development build and content validation | Pass |
| Collision/elevation and all nonvisual attributes | All 1,920 cells equal the baseline |
| Protected cells | 310 exact matches, including 69 garden cells, map perimeter, doors, tutorial and NPC ranges |
| Walking reachability from all five doors and three connections | Same 843-cell component at each entry |
| Shared Route2/22/28/26North source renders | Identical |
| Matched noon/dusk/night captures | 45/45 before and 45/45 after; 30 images |
| Runtime background palettes | All 15 before/after pairs byte-identical |
| Walking/running/cycling, follower, doors, connections, gym lock, menus, Save/Continue | 60/60 |
| Prepared save on unpatched delivery ROM | 3/3 |
| Existing Lua regression sweep | 50 suites, 1,331 assertions, including CatchTutorial |

The ordinary-walking flood fill does not model Surf or ledge jumps. Cell-level
nonvisual-attribute equality covers their map semantics; runtime checks exercise
the gym's real locked-door jump-back. The lifecycle fixture uses a synthetic
later-story state and resets Repel for each independent route so its expiry dialog
does not interrupt a movement test. The unpatched CatchTutorial suite separately
covers the early-story sequence. Running and cycling use actual avatar movement;
the disposable fixture selects their starting modes. Fixture hooks are absent from
the delivery ROM.

The publisher requires the exact pinned baseline ROM, checks map/tileset bytes
linked in both ROMs, reruns the source audit, and verifies positive run evidence
against the executed Lua-source and ROM hashes. It validates all native images
and paired palettes before producing the review. ROMs and saves stay local.

## Reproduce

Build and preserve an untouched ROM/ELF from the pinned baseline **before** authoring.
Then, in this feature checkout with Python 3, Pillow, devkitARM and mGBA available:

```sh
python3 Testing/viridian-transitions/art.py author
python3 Testing/viridian-transitions/art.py check --out /tmp/transitions-audit
make modern TOOLCHAIN=/opt/devkitpro/devkitARM -j8
make validate
```

Keep the tested delivery ROM/ELF stable; rebuilding after a commit changes the
embedded version stamp and therefore the ROM hash. Build both disposable fixtures
from the same final source, each linked against its matching ROM/ELF:

```sh
python3 Testing/visual-features/build_fixture.py --repo . \
  --rom "$ROM" --elf "$ELF" --out "$FIXTURE" \
  --source Testing/viridian-transitions/fixture.c
python3 Testing/viridian-art/run_suite.py --repo . --fixture "$FIXTURE" \
  --suite Testing/viridian-transitions/capture.lua --out "$CAPTURES"
```

Run the movement suite and verify its generated save against the unpatched ROM:

```sh
python3 Testing/viridian-art/run_suite.py --repo . --fixture "$AFTER_FIXTURE" \
  --suite Testing/viridian-transitions/lifecycle.lua --out /tmp/transitions-runs/lifecycle
python3 Testing/viridian-art/run_suite.py --repo . --rom "$DELIVERY_ROM" \
  --suite Testing/viridian-transitions/delivery.lua \
  --save /tmp/transitions-runs/lifecycle/VisualReview.sav --out /tmp/transitions-runs/delivery
PW_OUT=/tmp/transitions-runs/regression Testing/run-all.sh "$DELIVERY_ROM" \
  > /tmp/transitions-sweep.log 2>&1
cp /tmp/transitions-sweep.log /tmp/transitions-runs/regression/sweep.log
python3 Testing/viridian-transitions/render_review.py \
  --before-rom "$BEFORE_ROM" --before-elf "$BEFORE_ELF" \
  --delivery "$DELIVERY_ROM" --delivery-elf "$DELIVERY_ELF" \
  --before-fixture "$BEFORE_FIXTURE" --after-fixture "$AFTER_FIXTURE" \
  --before /tmp/transitions-runs/before --after /tmp/transitions-runs/after \
  --lifecycle /tmp/transitions-runs/lifecycle --delivery-run /tmp/transitions-runs/delivery \
  --regression /tmp/transitions-runs/regression --out Testing/viridian-transitions/review
```

`author` refuses unrelated edits and should not overwrite later stages. The audit
restricts production changes to this map and compares against immutable Git blobs.
The pinned baseline ROM hash identifies the actual reviewed build; another compiler
or version-stamp build needs its own verified provenance and new comparison runs,
not a silent replacement of the old baseline hash.

## Owner review

Use the three main before/after views, switch to dusk/night, then optionally open
the central-junction and eastern-verge views. The optional prepared save starts on
the eastern loop at night with a Pikachu follower. It already passes Continue and
walking checks on the unpatched game; use it separately from a personal save.
No manual fixture setup or debugging is needed.
