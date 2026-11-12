# Regional wardrobe and player colorways

Players choose a style and color during Oak's introduction or at the cabinet on
World Transit's main floor. Left and Right select Original, Kanto Classic,
Johto Classic, or Hoenn Classic. Up and Down select one of six colors. A confirms.
B leaves the initial picker open. At the cabinet, B cancels without changing the
equipped outfit. An older save already inside the hub needs one normal map
exit and return to populate the new cabinet. Both entry points use the same picker and show trainer and
small overworld previews together.

The saved identity remains the global `VAR_PLAYER_PALETTE`. Values 0 through 5
retain their original meanings. The new styles use values 6 through 23. Invalid
values render as Original Red. No save field, migration, or unlock gate is added. Dynamic object graphics IDs
413 through 428 also keep their saved-template meanings when new graphics are
added. The wardrobe fixture checks both ends of that legacy range.

The [artwork manifest and provenance](../../../graphics/player_outfits/README.md)
describe all six new designs, 36 new color combinations, and 72 production
sheets. The [catalog sheet](../../../graphics/player_outfits/review/catalog.png)
also includes the 12 original character and color combinations.

## Run the wardrobe checks

Build the ordinary game, audit the indexed artwork, and run the capture fixture.

```sh
make modern TOOLCHAIN=/opt/devkitpro/devkitARM -j8
python3 tools/player_outfits/verify_art.py
python3 test/overworld/player-outfits/run_capture.py --repo . \
  --rom pokemonworld.gba --elf pokemonworld.elf --out /tmp/wardrobe-capture
python3 test/validate-host.py
```

The capture runner checks all 48 combinations in the field, water reflections,
the local trainer card, and battle send-out. Both protagonist intro runs use real
buttons to preview every combination before confirmation. Both hub runs interact
with the physical cabinet and check Apply, Cancel, reopening, Red restoration,
and save followed by Continue. Preview navigation never writes the saved choice.
Assertions compare equipped graphics IDs and palette contents.

The pose fixture loads each new style's production activity graphics in Blue
and captures each supported facing direction. It checks normal movement, both
bikes, surfing, field moves, fishing, watering, underwater, and decorating.
This is a debug-assisted asset-routing check. It does not simulate every natural
activity transition. Source-art validation checks every authored animation frame.
The fixtures seed a party and use warps for setup. They do not alter the shipped
ROM or replace the production graphics and palette functions.

`run_capture.py` writes matching ROM hashes and fresh verdicts into its output.
Use the runner from an older source checkout for historical before captures.
The original #342 comparison below documents its own historical builds and
remains useful as palette provenance. Its original six-color picker assumptions
are superseded by the shared wardrobe tests above.

## Historical original colorway work


The old non-red outfits flattened several accent pairs and recolored Brendan's
shared hair/ink shades. The five new colorways use separate RGB5 ramps for each
gender and each live sprite layout. The C tables in
[`src/data/player_outfit_palettes.h`](../../../src/data/player_outfit_palettes.h)
are the hand-authored source of truth; no external generator is needed.

Open [`review/index.html`](review/index.html) through a local web server for the
interactive comparison, or inspect the complete
[after sheet](review/media/after-colorways.png) and
[before sheet](review/media/before-colorways.png) directly. Native screenshots
and lossless send-out clips cover all twelve character/outfit combinations.

The source gallery includes screenshots and clips, but the ROM/save bundle is
provided separately. On the owner's machine it is at
`_pwtest/player-outfits-342/PokemonWorld-Outfits-342.zip` relative to the repository
root; serving a fresh clone does not provide that download. The gallery's local
playtest link opens these setup instructions instead of assuming a ZIP exists at
the web server root.

## Palette contract

| Layout | Recolored entries | Protected entries |
| --- | --- | --- |
| Brendan and May overworld | 10–13 | 0–9, 14–15 |
| Brendan and May front/back | 5–6, 10–13 | 0–4, 7–9, 14–15 |

Pairs are stored shadow first, then highlight. In the tiny overworld sprites,
12/13 carry the clothing and 10/11 the band/bag. Brendan's 5–8 also occur in the
head and facial details, so overworld swapping now leaves them alone. In the
larger Brendan art, 5/6 carry garment fill and 7/8 are fixed hair/ink. May's
7/8 remain her original brown hair. Skin 1–4, whites 9/14, transparency 0, and
outline 15 never change. Red still returns before any palette write.

| Outfit | Direction |
| --- | --- |
| Blue | Cobalt/slate with gold accents |
| Green | Jade/earth with warm copper accents |
| Purple | Blue-violet with silver accents |
| Black | Graphite, teal accents, warm trim on Brendan's larger art |
| Pink | Rose with plum and cream |

Each of the six gender/layout tables has its own non-red rows. The larger back
sprites have lighter midtones so broad shaded areas remain readable. Different
surfaces retain a common outfit identity without sharing a single RGB row.

## Corrected runtime ownership

The original issue described two paths that are no longer live:

- Oak uses Brendan/May trainer sprites and `ApplyPlayerPaletteSwapFrontPic`,
  the same layout as the local trainer card. The legacy shared Red/Leaf portrait
  table and `ApplyPlayerPaletteSwapPortrait` have no caller and remain unchanged.
- Live reflections copy the player's current overworld palette, then apply the
  existing water filter (blue +10, capped at 31) and weather/time handling.
  The old reflection `.pal` files and reflection-slot swap helper are outside
  that live path. No additional reflection ramp or new tint logic is needed.

The underwater sprite uses its existing dedicated shared palette and does not
enter the outfit swap. All 22 affected source sheets (including biking, fishing,
surfing, movement animations and every back-pic pose) retain their protected
entries. Remote trainer cards retain their existing ownership guard. Production
changes are palette tables/masks and corrected comments only.

## Evidence and reproduction

[`review/manifest.json`](review/manifest.json) pins the actual before/after game
commits and input/fixture ROM hashes. Baseline input was built at
`3bc343d0331064646d4ce99b4b691291e1a6bf0c`; its later checkout HEAD includes
documentation-only commits. The tested new game build is
`fab489026058484960b7bd3ef7418e14466c6356` (`v1.6-40-gfab4890260`). Evidence-only
commits after that do not change or rebuild the delivered ROM.

The disposable fixture seeds a party, selects outfits, warps to a real pond,
opens the real card, starts an ordinary wild battle, and saves. It does **not**
write any palette, sprite art, or reflection state. The actual Oak intro is
driven with ordinary button presses, including gender selection, all six outfit
choices, B staying on the picker, returning to Red, and confirming into the hub.
The ordinary-build delivery check contains no fixture calls or RAM writes.

Use the toolchain/emulator setup in [`../mgba/README.md`](../mgba/README.md):

```sh
make modern TOOLCHAIN=/opt/devkitpro/devkitARM -j8
make release TOOLCHAIN=/opt/devkitpro/devkitARM -j8
make validate
python3 test/overworld/player-outfits/run_capture.py --repo . \
  --rom pokemonworld.gba --elf pokemonworld.elf --out /tmp/outfits/after
```

Run the same capture command with the baseline repo and its matching ROM/ELF,
`--baseline`, and a separate `/tmp/outfits/before` output. Do not rebuild an old
ROM against a newer checkout. The runner exports addresses from the matching
ELF; `HandleInputChooseAction` is resolved from the player controller's linked
sections to avoid same-named partner/Wally functions.

For the ordinary delivery check, populate a scratch Lua library with
`test/overworld/lua/*.lua`, the after `assets/outfit_expected.lua`, and the extra symbols
from `export_symbols.py`. Its `feature_symbols.lua` must contain `return {}`:

```sh
mkdir -p /tmp/outfits/delivery-lib /tmp/outfits/delivery
cp test/overworld/lua/*.lua /tmp/outfits/delivery-lib/
python3 test/overworld/GenLuaSymbols.py pokemonworld.elf \
  > /tmp/outfits/delivery-lib/symbols.lua
cp /tmp/outfits/after/assets/outfit_expected.lua /tmp/outfits/delivery-lib/
printf 'return {}\n' > /tmp/outfits/delivery-lib/feature_symbols.lua
python3 test/overworld/player-outfits/export_symbols.py pokemonworld.elf \
  /tmp/outfits/delivery-lib/outfit_symbols.lua
python3 test/overworld/viridian-art/run_suite.py --repo . \
  --suite test/overworld/player-outfits/OutfitDelivery.lua --rom pokemonworld.gba \
  --save /tmp/outfits/after/surfaces/VisualReview.sav --out /tmp/outfits/delivery \
  --env PW_FEATURE_LIB=/tmp/outfits/delivery-lib
PW_OUT=/tmp/outfits/regression test/overworld/run-all.sh
```

`render_review.py --runs /tmp/outfits --out test/overworld/player-outfits/review
--before-source <actual-before-game-commit> --after-source <actual-after-game-commit>
--delivery-rom pokemonworld.gba` requires all seven runs to have fresh terminal
verdicts, positive equal assertion counts, and matching ROM-stamped PASS files.
It also verifies ten Red frames pixel-for-pixel and decodes every lossless clip
against its source pixels and timing. Raw palette snapshots use `.pal.bin` to
avoid the repository's text/EOL treatment of `.pal` files.

See [`evidence/validation.md`](evidence/validation.md) for results. The owner
download contains the ordinary tested development ROM and one matching synthetic
save beside Petalburg's pond as May in Black. Open the ROM and Continue; inspect
the reflection and Start → Trainer. The gallery supplies the other combinations,
so owner review requires no engineering setup or twelve new games. ROMs and
saves stay in the local delivery folder, following [`RELEASING.md`](../../../RELEASING.md).
