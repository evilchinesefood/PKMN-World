# Native title-screen verification — centered title

Verified on 2026-09-23 using the local patched mGBA headless emulator. Screenshots are original 240 × 160 emulator output. All runs used disposable ROM copies without loading or modifying a player save.

## Results

- Development title: **35/35 passed**.
- Release title: **34/34 passed** (the development-only SELECT shortcut is omitted).
- Normal new-game smoke test: **10/10 passed**, including coordinate-verified movement at the Region Hub.
- `make validate` completed successfully. Its region-map checker still reports tolerated layout mismatches unrelated to this title-screen change.
- Offline browser checks passed: image loading, no JavaScript errors, fog animation, pause/resume, fog-off stability, logo variants/removal, native scaling and mobile overflow.

## Horizontal alignment

The emulator suite decodes visible logo pixels from BG2 tiles and PRESS START pixels from OBJ tiles/OAM. This checks the rendered artwork rather than the padded image or sprite containers.

| Element | Left margin | Right margin |
| --- | ---: | ---: |
| Full Pokémon World logo | 43 px | 44 px |
| PRESS START | 75 px | 75 px |

The logo has an odd visible width of 153 pixels, so its closest possible alignment is half a pixel from the exact center. The two logo words move together; their relative placement and proportions are unchanged. PRESS START previously began at tile 1 of its source row, which skipped eight pixels of padding and shifted the text left. It now starts at tile 0.

Other title checks compare actual VRAM tile/map bytes and the hardware RGB555 palette with the exported resources, verify layer configuration and blending, and observe fog scroll/wrap, stable logo/palette, Start/A menu transitions, the locked RTC shortcut, save-clear confirmation/cancel, and the music-end intro loop. The development run also checks SELECT quickstart.

The enabled RTC-reset path and physical GBA hardware were not exercised. No full gameplay regression suite was run for this artwork change.

## Builds

### Development

ROM: `/Users/dayers/Github/PKMN-World/pokemonworld.gba`

SHA-256: `68f01314c5567e66caff1d2daea3f19f8f75b76bac13666b875af47d354ed787`

```text
PASS 35/35 rom=FF787D0E4CCED40E78FFC08769D82963 at=2026-09-23T14:04:42Z suite=WorldTitle
PASS 10/10 rom=FF787D0E4CCED40E78FFC08769D82963 at=2026-09-23T14:06:09Z suite=SmokeBoot
```

### Release (LTO)

ROM: `/Users/dayers/Github/PKMN-World/pokemonworld-release.gba`

SHA-256: `1ce65ef6953a472f03c0d3ab8433f8f74036b086a81fdd233345e32da640b58f`

```text
PASS 34/34 rom=E612EAF4CC61F1C05B88E3B86907AF4D at=2026-09-23T14:06:14Z suite=WorldTitle
```

Both builds completed successfully. Compiler/linker warnings were present in unrelated existing code; no title-screen compilation errors occurred.

## Screenshots

- [Release title](release/WorldTitle_01_title.png)
- [Release title, 128 frames later](release/WorldTitle_02_fog_moved.png)
- [Release main menu after Start](release/WorldTitle_03_main_menu.png)
- [Release clear-save confirmation](release/WorldTitle_04_clear_save_confirmation.png)
- [Release title after the automatic intro loop](release/WorldTitle_05_title_after_intro_loop.png)
- [Development quickstart](debug/WorldTitle_06_quickstart.png)
- [Normal new-game Region Hub](debug/SmokeBoot_01_hub.png)

The two release title captures differ in the moving fog while retaining the same scenery and logo. The release title omits the development SELECT HUD.

## Reproduce

See [INTEGRATION.md](../INTEGRATION.md) for build and emulator commands. `WorldTitle.lua` is registered in `Testing/run-all.sh`. Logs and ROM-stamped PASS files are beside the screenshots.

The five exported iCloud PNGs were verified byte-for-byte against their source files during integration. Both standalone logo PNGs retain alpha transparency. This centering adjustment changes game placement, not those full-resolution export files.
