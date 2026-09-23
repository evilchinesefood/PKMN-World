# Title screen — scenery, logos and existing fog

The title screen has no Pokémon objects. It uses a clear static background, the full Pokémon World logo, and the game's existing title-screen cloud pattern and motion. `src/title_screen.c` dispatches the unified World build to `src/title_screen_world.c`. The main review page includes actual emulator screenshots and an interactive asset preview.

## Mode 0 background layout

| Layer | Type | Char base | Screen block | Priority |
| --- | --- | ---: | ---: | ---: |
| BG0 scenery | 8bpp regular text | 0 | 30 | 2 |
| BG1 fog | 4bpp regular text | 3 | 29 | 1 |
| BG2 title logo | 8bpp regular text | 0 | 31 | 0 |

All maps are 32 × 32 tiles. The visible screen is 240 × 160. The title logo and scenery have zero scroll; only BG1 scrolls and receives the scanline wave.

| File | Destination / use |
| --- | --- |
| `gba/background.8bpp` | Shared scenery and logo tiles at VRAM offset 0; 53,248 bytes |
| `gba/background-map.bin` | BG screen block 30 |
| `gba/logo-map.bin` | BG screen block 31 for the full Pokémon World title |
| `gba/world-logo-map.bin` | Alternative contents of screen block 31 for WORLD only |
| `gba/background.gbapal` | Complete 256-entry BG palette, including fog in its last bank |
| `gba/fog.4bpp` | 3,584 bytes at VRAM offset 0xD800 |
| `gba/fog-map.bin` | BG screen block 29; tile indices already offset by 192 |
| `gba/fog.gbapal` | Optional separate fog palette; same last bank as the complete BG palette |

The fog uses char base 3 (0xC000) plus 192 32-byte tiles (0x1800). It ends at 0xE600, before screen block 29 at 0xE800. Scenery and logo tiles end before the fog allocation. Three map blocks occupy the final 6 KiB of BG VRAM.

Palette indices 0–239 belong to the scene and logos; indices 240–255 hold the original cloud palette. Index zero in the 8bpp layers and local index zero in the 4bpp fog bank are transparent. The scene itself has no transparent pixels.

The exporter installs these already converted resources in `graphics/title_screen/world/` as `background_tiles.bin`, `background_map.bin`, `logo_map.bin`, `palette.bin`, `fog_tiles.bin` and `fog_map.bin`. The engine uses `INCBIN_U32` / `INCBIN_U16`, DMA copies and palette loading. They are not compressed. Compile-time size checks guard the allocation boundaries. All three backgrounds use regular text maps.

## Logo formatting

Both PNGs are full-screen transparent layers matching their tilemaps:

- Pokémon World: 160 × 80 at (39, 4), source ratio 2:1.
- WORLD only: 144 × 48 at (48, 20), source ratio 3:1.

The exporter computes the height from each master, centers the visible alpha silhouette on whole pixels, and retains opaque white within the metallic letters. The full logo has side margins of 43 and 44 pixels, the closest possible match for its odd 153-pixel visible width. WORLD-only has 52/53-pixel margins. The full logo's internal word alignment is preserved. Select one logo map for screen block 31. BG2 priority 0 keeps the logo above the fog without blending its letters.

## Reused fog

Source copies are preserved under `game/fog/`:

- `cloud-tiles-source.png`: exact copy of `graphics/title_screen/clouds.png`.
- `cloud-map-source.bin`: exact copy of `graphics/title_screen/clouds.bin`.
- `cloud-palette-source.pal`: exact copy of `graphics/title_screen/rayquaza_and_clouds.pal`.

The exported tile bytes are unchanged from the source. Only tilemap allocation fields change: the tile IDs gain 192, palette bank 14 becomes 15, and horizontal/vertical flips remain intact.

The preview follows `Task_TitleScreenPhase3` in `src/title_screen.c` and `GenerateWave` / `TaskFunc_UpdateWavePerFrame` in `src/scanline_effect.c`:

- Vertical BG offset advances one pixel every four frames, or 15 pixels/second at 60 fps.
- The horizontal scanline wave uses frequency 4, amplitude 4 and delay 0.
- The 64-entry wave is derived from the repo's actual Q8.8 `gSineTable`, including integer truncation.
- The existing title blend is EVA=6, EVB=15. BG1 is the first target and BG0/backdrop the second target.
- The pattern wraps at 256 pixels; the full scroll/wave cycle repeats after 1,024 frames.

Equivalent engine settings:

```c
SetGpuReg(REG_OFFSET_BLDCNT,
          BLDCNT_TGT1_BG1 | BLDCNT_EFFECT_BLEND
          | BLDCNT_TGT2_BG0 | BLDCNT_TGT2_BD);
SetGpuReg(REG_OFFSET_BLDALPHA, BLDALPHA_BLEND(6, 15));
ScanlineEffect_InitWave(0, DISPLAY_HEIGHT, 4, 4, 0,
                       SCANLINE_EFFECT_REG_BG1HOFS, TRUE);
```

The browser uses the exported cloud PNG, wave table and speed. It approximates the blend through canvas additive composition, so it is not a bit-exact emulator. `game/gba/preview-config.js` is generated alongside `game/fog/animation.json`, allowing the review page to work from `file://` without fetch or a local server.

## Integration and verification

The new initializer replaces the old Rayquaza, affine logo, shine and version-banner sequence for `ALL_REGIONS=1`. It retains the title music and white fades, Start/A menu entry, save-clear confirmation, RTC reset eligibility check, development SELECT quickstart, and the automatic return to the intro after the music ends. Held service chords take precedence over SELECT quickstart. HBlank fog DMA stops before every exit. Legacy single-region title code remains available for `ALL_REGIONS=0`.

The standard PRESS START prompt blinks at the bottom. Its five frames use tiles 0, 4, 8, 12 and 16 of the source's top row, preserving the row's centered transparent padding. The visible prompt has equal 75-pixel side margins and shares the logo's center to within half a native pixel. The development build also has its existing SELECT quickstart HUD; the release build omits it. No mascot graphics or Pokémon sprites are allocated.

Rebuild and run the native checks:

```sh
node assets/branding/pokemon-world/export-gba.mjs
make modern -j8
Testing/mgba-run.sh Testing/lua/WorldTitle.lua
Testing/mgba-run.sh Testing/lua/SmokeBoot.lua
make modern RELEASE=1 -j8
python3 Testing/GenLuaSymbols.py pokemonworld-release.elf --title > /tmp/world-title-release-symbols.lua
PW_TITLE_SYMBOLS=/tmp/world-title-release-symbols.lua Testing/mgba-run.sh Testing/lua/WorldTitle.lua pokemonworld-release.gba
```

Set `MGBA_HEADLESS` to the patched headless mGBA binary if it is not on PATH. `PW_OUT` selects the evidence folder. The runner uses disposable ROM copies with no player save. The release symbol table is generated separately because LTO removes unrelated debug symbols; the ROM hash guard remains active.

The title suite verifies hardware registers, byte-for-byte VRAM/palette loading, visible logo/prompt centering decoded from BG2 and OAM, stable logo and palette through a full fog cycle, scrolling/wrap, Start/A, service-chord precedence, clear-save cancellation and the music-end intro loop. The development run also exercises SELECT quickstart. The smoke suite verifies the normal new-game path and player movement. See [emulator/TEST-REPORT.md](emulator/TEST-REPORT.md) for this build's results and screenshots.
