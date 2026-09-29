# Warm Johto glass — #335

The production change enables secondary palette bit 1 on New Bark and Cherrygrove
(physical bank 8 in Johto), and fills alternate slot 1 with day slot 8 plus the
approved amber ramp at entries 8–10. No new art, engine logic, map scripts, or
palette-immunity masks are introduced.

The six placements are New Bark `(12,7)`, Cherrygrove `(34,13)`, `(42,14)`,
`(50,17)`, and Route 30 `(35,4)`, `(26,39)`. These are the small glazed panes
in the house/lab door metatiles. Other windows remain outside this pilot.

## Runtime correction to the original study

The existing `.pla` high bits exempt glass from the outdoor tint, but do **not**
make it a raw RGB passthrough. `TimeMixPalettes` blends protected entries toward
`DEFAULT_LIGHT_COLOR` `(248,224,120)` instead. The baseline already appears pale
cream at night; this change makes it amber. The engine behavior remains intact.

| Entry | Day RGB5 | Alternate source RGB5 | Final full-night RGB5 |
| --- | --- | --- | --- |
| 8 | 19,25,30 | 31,29,20 | 31,28,17 |
| 9 | 12,19,29 | 31,25,13 | 31,26,14 |
| 10 | 7,15,27 | 27,19,8 | 29,23,11 |

## Reproduce the evidence

Use a clean committed build and the toolchain/emulator described in
[`../mgba/README.md`](../mgba/README.md). The capture fixture is linked only into
verified unused padding of a disposable ROM; it supplies a fresh save, warps,
one normal wild encounter, and a save call. It never alters palettes or tiles.

```sh
make modern TOOLCHAIN=/opt/devkitpro/devkitARM -j8
make release TOOLCHAIN=/opt/devkitpro/devkitARM -j8
make validate
python3 test/overworld/warm-windows/check_data.py --repo . --out /tmp/window-audit
python3 test/overworld/visual-features/build_fixture.py --repo . \
  --rom pokemonworld.gba --elf pokemonworld.elf \
  --source test/overworld/warm-windows/fixture.c --out /tmp/window-fixture
PW_WINDOWS_AFTER=1 python3 test/overworld/visual-features/run_fixture.py --repo . \
  --fixture /tmp/window-fixture --suite test/overworld/warm-windows/capture.lua \
  --out /tmp/window-runs/after
PW_WINDOWS_AFTER=1 python3 test/overworld/visual-features/run_fixture.py --repo . \
  --fixture /tmp/window-fixture --suite test/overworld/warm-windows/lifecycle.lua \
  --out /tmp/window-runs/after-lifecycle
PW_OUT=/tmp/window-tracked test/overworld/run-all.sh
mkdir -p /tmp/window-runs/delivery
PW_OUT=/tmp/window-runs/delivery test/overworld/mgba-run.sh \
  test/overworld/warm-windows/verify_delivery.lua pokemonworld.gba \
  /tmp/window-runs/after-lifecycle/VisualReview.sav \
  > /tmp/window-runs/delivery/runner.log 2>&1
```

Build the same fixture against the matching **before** ROM/ELF and run both suites
without `PW_WINDOWS_AFTER`, into `before` and `before-lifecycle`. The fixture
builder exports symbols from each ELF and guards the isolated ROM hash. Record
the actual build commit separately from a later documentation-only checkout.

`render_review.py` requires those five successful runs, including fresh runner
stdout and a matching delivery ROM hash. Pass `--runs`, `--out`, `--before-source`,
`--after-source`, `--delivery-md5`, and `--atlas /tmp/window-audit/palette-atlas.png`.
It checks every native frame and all 256
BG palette words: all noon frames and four unaffected-map views must be identical;
every other changed pixel must match one of the three glass color pairs. It also
decodes lossless clips and compares every frame and duration against the sources.

The lifecycle suite checks both real RTC boundaries for 200 emulated seconds
without changing the clock, counter, callbacks, or position during the wait.
Separate clock-set time-lapses show the full two-hour dusk and four-hour dawn.
Normal door, connection, menu, battle escape, and Continue paths verify returns.

## Owner review

The local delivery contains the ordinary tested development ROM, a matching
synthetic save, and a five-minute route around Cherrygrove's three houses. This
follows [`../../RELEASING.md`](../../../RELEASING.md): release configuration is compiled,
but the tested development configuration is the one delivered. No ROM or save is
uploaded to GitHub. See `evidence/validation.md` for exact commits, hashes and results.
