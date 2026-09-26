# Visual features: implementation and review

[Open the five-minute review](index.html). Implementation: `59214f5b6b`; baseline: `45e1bf82ca5c2728910127863b926e627d4f18fc`. The tested delivery ROM SHA-256 is `4bf80320a7294ec7df22a4e8b4097c3f56493b8968412777e4ed49e6882697d3`. [Checksums and results](delivery.json).

## Delivered behavior

- **#329 — ambient ripples.** Existing ripple art animates on interior pond tiles in Petalburg, Violet and Fuchsia, and on Route119 puddles during rain. Caps are 3 in clear weather and 5 in rain. Placement avoids shore edges and actors, uses independent cosmetic randomness, and yields resources to gameplay. A persistent template and private palette tag establish ownership without occupying the field-effect active list. Sprite/tile/palette allocation and OWE admission can reclaim rings and retry once. Reclamation also removes queued tile copies and buffered OAM before resources can be reused; affine matrix values survive.
- **#332 — default frame.** The existing nine-tile SwSh frame and its own indexed palette replace FRAME1 in user-frame menus. FRAME2–FRAME20 retain their identities and saved selection. Battle uses an explicit separate loader: classic FRAME1 or the player's existing nondefault selection. Exported classic assets used by DexNav/save-error screens remain unchanged. This does not import #328's 25-tile message-box allocation changes.
- **#333 — hints and palette bounds.** SELECT reads Done while rearranging the wheel; owner trainer-card fronts show L/R around the region. The field map retains its region title and has a separate eligible-only R-Fly window. The HGSS dex no longer reads 96 bytes past its three-bank palettes: bank 3 is initialized explicitly, unused banks 4/5 are cleared, and the area/search screens retain their own palettes. Light-mode neutral colors and the Fly frame use existing SwSh colors; chromatic art and dark-mode colors retain their roles.

**R-Fly is disabled by the current `OW_FLAG_POKE_RIDER = 0` configuration.** Production correctly displays no shortcut. Its enabled appearance was verified in an isolated configuration with `FLAG_TEMP_1`; this feature does not grant Fly eligibility or change destinations. The same control build uses `SWSH_MESSAGE_BOX = FALSE` and `HGSS_DARK_MODE = TRUE` to verify those existing alternatives.

The HnS and digit studies are separate: [#331](../visual-studies/hns/README.md), [#334](../visual-studies/digits/README.md). Neither candidate was adopted. The title/logo and cancelled regional palette proposal are untouched.

## Verification

| Check | Result | Evidence |
|---|---|---|
| Full Lua sweep on the delivery ROM | **50/50 suites**, fresh matching-ROM sentinels | [Sweep](evidence/lua-sweep.log), [sentinels](evidence/lua-sentinels.txt) |
| Full C suite | **5,076 passed**, 8 expected failures; 14 existing known failures and 595 TODOs; exit 0, no unexpected failures | [Full results](evidence/engine-tests.log) |
| Ripple ownership/resource regressions | **9 test groups**, parameterized maps/weather/allocation cases | [Results](evidence/ripple-tests.log) |
| Late queued-copy regression | Failed on the original destruction path; passes after cancellation and OAM cleanup | [Failing reproduction](evidence/ripple-red-regression.log), [fixed results](evidence/ripple-tests.log) |
| Existing sprite-exhaustion / OWE checks | **77 + 2 groups pass** | [Sprites](evidence/sprite-tests.log), [OWE](evidence/owe-tests.log) |
| Actual battle frame loader | FRAME1/2/20/invalid selection, Battle Arena and tutorial cases pass | [Results](evidence/frame-tests.log) |
| Native capture matrix | **37 matched scenes**; after **46/46**, baseline **35/35**, alternate config **46/46** | [After](evidence/after/capture.log), [before](evidence/before/capture.log), [controls](evidence/controls/capture.log) |
| Regional dex palette paths | Light and dark **4/4** each, including regional list/detail and return to National | [Light](evidence/palette-light/VisualPaletteControls.log), [dark](evidence/palette-dark/VisualPaletteControls.log) |
| Repeated real map/menu/battle transitions | **50 cycles**, including 10 ordinary wild-battle escapes; stable nonambient usage: 17 sprites, 86 tiles, 7 palettes, 11,520 heap bytes | [After stress](evidence/after/stress.log), [before stress](evidence/before/stress.log) |
| Rain stress | **1,800 emulated frames** with visible follower and OWE throughout; after peak 3 ambient rings, no unexpected screen change | [After animation](evidence/after/rain.webp), [before animation](evidence/before/rain.webp) |
| Prepared synthetic save on the unmodified delivery ROM | **8/8**: boot, walk, open/rearrange/close wheel | [Results](evidence/save/VisualReviewSave.log) |
| Builds / validators | Development, release-mode and isolated alternate configuration compile; validators pass with the same 7 pre-existing region-map mismatches | [Development](evidence/development-build.log), [release](evidence/release-build.log), [controls](evidence/control-build.log), [validators](evidence/validators.log) |

The full sweep covers existing prompt/EV-IV, Bag/PC, Fly/Teleport, day/night, overworld Pokémon, followers, surfing, intro/catch tutorial, healthboxes and migration regressions. FRAME2 and FRAME20 Options captures are pixel-identical to baseline. [Pixel differences](pixel-differences.json) are descriptive, not automated aesthetic judgments. A timing-sensitive BnetTerminal1F test was corrected to use eight-frame A presses with its original approximately 9,600-frame timeout; the former two-frame pattern stopped at a continue prompt. Both baseline and changed builds accept normal longer presses, and the corrected full sweep passes.

No live multiplayer/link session or physical GBA performance profiling was performed. The rain animation samples native frames at 15 fps for a 30-second presentation; the logged VBlank counter is a harness diagnostic, not proof that every game update meets a hardware frame budget. Link-card suppression is preserved by the existing `isLink` guard. Unchanged specialized map callbacks were source-audited; the 50-cycle test is not a claim that every map in the game was visited.

## Palette ownership audit

The nine-tile SwSh border uses indices 1/2/14; binding `std_menu.pal` to it would use different color roles, so its embedded palette is loaded. Battle bank 1 uses classic FRAME1 through `LoadBattleWindowBorderGfx` while battle text bank 5 retains its existing loader.

The dex's six list/detail arrays each contain 48 colors. Lists/details use bank 0; info/caught text uses auxiliary bank 3. Active windows use 0/8/9/15, and the area map reloads its own map banks. The search menu has a separate four-bank loader. Light palette edits are restricted to entries 1–4; entry 5 and chromatic entries are preserved. After RGB5 quantization, the actual dex differences are entry 2 (28,28,28 → 27,27,27) and entry 3 (25,25,25 → 26,26,25). The Fly frame's entries 3/4 use (21,21,21)/(27,27,27); land/water geography colors are untouched.

[Index-use masks](palette-index-usage.png) and [pixel counts](palette-index-usage.json) show the affected raw indices on the source tile sheets. These are diagnostic plots; the native runtime captures above verify the palettes after composition.

## Reproduce and final playtest

`fixture.c` is test-only. `build_fixture.py` compiles it against a matching ELF and inserts it into verified unused ROM padding; production source and delivery ROM are not patched. It enters actual production screens after normal overworld cleanup, supplies deterministic RAM fixtures, and uses fresh isolated saves. Route119 rain is explicitly selected through the weather API for comparison. `run_fixture.py` retains only its own generated save. Native PNGs are unchanged emulator output; WebP animations are lossless frame sequences. [Evidence hashes](evidence-manifest.json) identify the retained files. Each capture directory also retains its exact `fixture.c`, matched to its recorded source hash; pass `--source` to `build_fixture.py` to reproduce that historical fixture.

```sh
make modern TOOLCHAIN=/opt/devkitpro/devkitARM -j8
Testing/run-all.sh
make check TOOLCHAIN=/opt/devkitpro/devkitARM -j8
make validate
python3 Testing/visual-features/build_fixture.py --repo "$PWD" \
  --rom pokemonworld.gba --elf pokemonworld.elf --out /tmp/visual-fixture
PW_FEATURE_LIB=/tmp/visual-fixture/lua PW_OUT=/tmp/visual-captures \
  Testing/mgba-run.sh Testing/visual-features/capture.lua /tmp/visual-fixture/VerifyFeatures.gba
python3 Testing/visual-features/run_fixture.py --repo "$PWD" \
  --fixture /tmp/visual-fixture --suite Testing/visual-features/stress.lua --out /tmp/visual-stress
```

The local handoff is `_pwtest/visual-review/VisualReview.zip` in the owner's main checkout. It contains the tested **development ROM**, a synthetic save beside Petalburg's pond, Town Map, checksums, and a 5–10 minute normal-controls route. This follows `RELEASING.md`'s instruction to distribute the development configuration. No ROM is committed/uploaded to GitHub, no release tag is cut, and no personal save is used.
