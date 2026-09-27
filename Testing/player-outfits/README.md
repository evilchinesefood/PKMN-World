# Player outfit colorways — issue #342

The old non-red outfits flattened several accent pairs and recolored Brendan's
shared hair/ink shades. The five new colorways use separate RGB5 ramps for each
gender and each live sprite layout. The C tables in
[`src/data/player_outfit_palettes.h`](../../src/data/player_outfit_palettes.h)
are the hand-authored source of truth; no external generator is needed.

Open [`review/index.html`](review/index.html) through a local web server for the
interactive comparison, or inspect the complete
[after sheet](review/media/after-colorways.png) and
[before sheet](review/media/before-colorways.png) directly. Native screenshots
and lossless send-out clips cover all twelve character/outfit combinations.

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
python3 Testing/player-outfits/run_capture.py --repo . \
  --rom pokemonworld.gba --elf pokemonworld.elf --out /tmp/outfits/after
```

Run the same capture command with the baseline repo and its matching ROM/ELF,
`--baseline`, and a separate `/tmp/outfits/before` output. Do not rebuild an old
ROM against a newer checkout. The runner exports addresses from the matching
ELF; `HandleInputChooseAction` is resolved from the player controller's linked
sections to avoid same-named partner/Wally functions.

For the ordinary delivery check, populate a scratch Lua library with
`Testing/lua/*.lua`, the after `assets/outfit_expected.lua`, and the extra symbols
from `export_symbols.py`. Its `feature_symbols.lua` must contain `return {}`:

```sh
python3 Testing/player-outfits/export_symbols.py pokemonworld.elf \
  /tmp/outfits/delivery-lib/outfit_symbols.lua
mkdir -p /tmp/outfits/delivery
PW_FEATURE_LIB=/tmp/outfits/delivery-lib PW_OUT=/tmp/outfits/delivery \
  Testing/mgba-run.sh Testing/player-outfits/OutfitDelivery.lua pokemonworld.gba \
  /tmp/outfits/after/surfaces/VisualReview.sav \
  > /tmp/outfits/delivery/runner.log 2>&1
PW_OUT=/tmp/outfits/regression Testing/run-all.sh
```

`render_review.py --runs /tmp/outfits --out Testing/player-outfits/review
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
saves stay in the local delivery folder, following [`RELEASING.md`](../../RELEASING.md).
