# Compact-digit comparison (#334)

**Recommendation: keep the current digits.** Candidate A is a reasonable cosmetic alternative, but its one-pixel reduction in height does not clearly improve readability at native GBA size. Candidate B also shifts punctuation within unchanged character advances, changing ordinary labels without a clear benefit. This is a visual judgment from the captures, not a claim that either candidate has a rendering defect.

[Open the two-minute comparison](index.html). The first three scenes show Lv.100/HP, move PP, and storage's long nickname. Native 240×160 images and nearest-neighbor 4× views are available. The owner only needs to choose the appearance; no emulator setup or fixtures are required.

No production font binding or game source was changed. Everything here is an isolated comparison study using graphics already bundled in the repository.

## Baseline and candidate scope

Source baseline: `45e1bf82ca5c2728910127863b926e627d4f18fc`, built ROM SHA256 recorded in [manifest.json](manifest.json). The user explicitly authorized completing the study now, so captures use the current SwSh UI before #328. The original dependency on landed #328 is therefore deferred for this comparison. If #328 changes these surfaces, refresh final control captures before any selected font adoption. The selected BW #336 outlined battle fonts and font-ID compatibility work remain excluded; refresh combined battle controls after that feature exists.

| Variant | Copied Latin glyph IDs | Bytes different from study baseline | Width / line metric changes |
| --- | --- | ---: | --- |
| Current | None | 0 | None |
| A: digits | `0xA1–0xAA` | 156 | None |
| B: digits and punctuation | A plus `0xAD`, `0xBA`, `0xF0` | 355 | None |

All three compact families were evaluated: `FONT_SHORT`, `FONT_SHORT_NARROW`, `FONT_SHORT_NARROWER`. The current `latin_short*.png` and bundled `latin_frlg_nums*.png` sources are bound/audited through [src/fonts.c](../../../src/fonts.c). Numeric advances remain 6, 5, and 4 pixels respectively. Digit foreground/shadow bounds change from y=2..11 to y=3..11: height 10→9 with the bottom baseline preserved. No candidate glyph overhangs the existing advance. The optional punctuation changes ink position/bounds more substantially; see [glyph-audit.csv](glyph-audit.csv).

The actual converter contract is [tools/gbagfx/font.c](../../../tools/gbagfx/font.c): 256×512 indexed sheets, 16×16 glyph cells, 64 bytes per Latin glyph. The first four indexed roles of all six tested sheets match. The build script uses the repository converter and verifies every current glyph array against its exact ELF symbol and ROM bytes before patching. It copies glyph bytes, never whole palettes or whole font sheets. Every non-whitelisted Latin glyph cell, normal/small font array, width table and engine instruction is byte-identical between comparison ROMs.

Each comparison ROM contains the **same** test-only callback in verified `0xFF` ROM padding at `0x09F00000`. Lua invokes that callback only to initialize deterministic RAM fixtures and enter existing production menu functions. That is separate from the 156/355-byte font difference. The callback, ROM hashes and size are in the manifest. No synthetic menu composition replaces the real summary, bag or PC renderer.

## Real call sites and capture coverage

The complete source search is in [font-call-sites.txt](font-call-sites.txt). The main relevant callers are:

| Family / surface | Actual source path | Native evidence |
| --- | --- | --- |
| `FONT_SHORT` | `src/swsh_item_menu.c:4492–4494`, bag pocket label | Real bag screens show this unchanged label; the separate native renderer specimen exercises its digits because that label contains none. |
| `FONT_SHORT_NARROW` | `src/swsh_summary_screen.c:155,3787–3794,3830–3834` | Summary levels 1/9/10/99/100; current HP1/9/10/99/100; IV31; EV252+252+6; PP1/35,40/40,10/20,5/30; move information and dash state. |
| `FONT_SHORT_NARROW` | `src/swsh_item_menu.c:4750–4776` | TM battle information, PP and power/accuracy, including Protect's dash state. |
| `FONT_SHORT_NARROWER` | `src/swsh_storage_system.c:4356,4407` | Twelve-character `WWWW99999999` nickname measures 60px in SHORT_NARROW and 48px in SHORT_NARROWER, exceeding the 58/56px limits and exercising the real fallback; Lv.100/stat readouts remain visible. |
| `FONT_NORMAL` control | Current EV/IV editor exercised by `PromptSafetyEvIv.lua` | Actual editor screenshot is pixel-identical across all three variants. It is not a claimed beneficiary of the compact digits. |

Additional controls include bag quantities1/9/10/99, box title/count context, the longest existing item-name group (the 19-character `Unremarkable Teacup`), maximum-length Pokémon nickname, 16-character move-name limit (`Stomping Tantrum` on the test Mew), é, gender/multiplication symbols and punctuation. The later-generation teacup is only a valid bag-rendering stress fixture already defined in the ROM; this study does not add it to gameplay or enable later-generation systems.

`999` and `252/510` also appear in the explicit native text-renderer specimen. There is no ordinary legal Eevee HP999 fixture; the study does not invent one. The specimen is clearly labeled as a diagnostic window, not a normal gameplay screen. Its three rows use the actual production GBA text renderer and the three original font IDs; the last row is the unchanged NORMAL-symbol control. [Native glyph strip](glyph-strip-native.png) / [4× strip](glyph-strip-4x.png).

The long-item-name screen is pixel-identical between current and A. B changes its description's period. The EV/IV editor is pixel-identical for both candidates. Exact per-screen pixel counts/bounds are in [capture-diffs.json](capture-diffs.json). Native captures remain untouched; 4× exports in `4x/` use nearest-neighbor enlargement only.

## Runtime results

All results are stamped with the exact final study-ROM MD5s. Each variant passed:

| Suite | Assertions | What it proves |
| --- | ---: | --- |
| `DigitsStudy` | 12/12 | Fixture party, summary return flows, bag/TM return flows, live storage callback; 27 real-menu captures. |
| `DigitsCalibration` | 1/1 | Native renderer specimen initialized after a successful boot; image review checks glyph appearance. |
| `VerifyBagLayout` | 23/23 | Current bag layout and save/reload invariants. |
| `PromptSafetyEvIv` | 30/30 | Existing prompt/editor interaction checks, plus unchanged editor capture. |
| `VerifyPCScreen` | 10/10 | Existing building-PC animation/interaction checks. This is distinct from storage UI, which the study driver captures. |

**228/228 assertions across three variants**, plus 29 selected matched scenes per variant in the review page (27 menu scenes, specimen, editor control). Logs, fresh PASS files and additional test captures are under `evidence/`; structured results are in [results.json](results.json). Passing logic checks supplement the inspected native images; they are not presented as visual proof by themselves.

Scope limits are explicit: this is an English-interface, comparison-only result. `FONT_SHORT_COPY_1..3` and Japanese fallback pointers share existing glyph storage (`src/fonts.c:335,371,407`); no independent Japanese-language/traded-name fixture was run. Any future adoption must inspect those aliases and refresh changed #328/#336 controls rather than treating this study as a release-wide font sign-off. No port, engine ABI change, gameplay change or shared font rebind is approved by this study.

## Reproduce

Requirements: a matching built World `.gba`/`.elf`, repository `tools/gbagfx/gbagfx`, Pillow, devkitARM at `/opt/devkitpro/devkitARM`, and the configured `~/.local/bin/mgba-headless` described in [Testing/mgba/README.md](../../mgba/README.md). The script fails if source glyphs, ELF symbols and ROM bytes disagree. It writes only the specified scratch build/output paths, never the input game repository.

Commands used:

```sh
python3 Testing/visual-studies/digits/build_study.py \
  --repo /Users/dayers/Github/PKMN-World \
  --rom /Users/dayers/Github/PKMN-World/pokemonworld.gba \
  --elf /Users/dayers/Github/PKMN-World/pokemonworld.elf \
  --out /tmp/pkmn-world-digits-study/study-build
```

For each variant `baseline`, `digits`, `punctuation`, run each suite `capture`, `calibration`, `VerifyBagLayout`, `PromptSafetyEvIv`, `VerifyPCScreen`:

```sh
python3 Testing/visual-studies/digits/run_study.py \
  --repo /Users/dayers/Github/PKMN-World \
  --build /tmp/pkmn-world-digits-study/study-build \
  --out /tmp/pkmn-world-visual-work/Testing/visual-studies/digits/evidence \
  --variant digits --suite capture

python3 Testing/visual-studies/digits/package_review.py \
  --build /tmp/pkmn-world-digits-study/study-build
```

The runner uses the normal protected temporary-ROM mechanism, fixed RTC1704110400, copied suite libraries and symbol addresses derived from the unchanged input ELF. Because the candidate changes only glyph bytes and adds code in unused ROM padding, all production symbol addresses and struct offsets remain unchanged; only each study copy's recorded ROM hashes are refreshed. The fixture hook's entry and argument addresses are derived from the ELF, not guessed offsets.

No ROM binaries or ELF files are included in this durable evidence folder. All art is already in the repository; no external graphics or credit changes were introduced.
