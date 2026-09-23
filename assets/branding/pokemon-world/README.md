# Pokémon World visual assets — revision 04

Open [index.html](index.html) in a browser to review the finished cover, actual emulator screenshots and interactive title preview. The page works directly from the filesystem. The assets are integrated into the native game, and both development and release ROMs have been built.

Full review path:

```text
/Users/dayers/Github/PKMN-World/assets/branding/pokemon-world/index.html
```

## Current artwork

| Deliverable | File |
| --- | --- |
| Revised box front with the reference-style GBA sidebar | [box/box-front.png](box/box-front.png) |
| Full transparent Pokémon World logo | [logos/pokemon-world.png](logos/pokemon-world.png) |
| Transparent WORLD wordmark | [logos/world.png](logos/world.png) |
| Clean character illustration | [artwork/artwork-clean.png](artwork/artwork-clean.png) |
| Clear title background, painted fog and clouds removed | [game/masters/title-background.png](game/masters/title-background.png) |
| Native 240 × 160 background | [game/gba/background.png](game/gba/background.png) |
| Full logo, centered on a transparent 240 × 160 layer | [game/gba/logo-layer.png](game/gba/logo-layer.png) |
| WORLD-only alternative, centered on a transparent 240 × 160 layer | [game/gba/world-logo-layer.png](game/gba/world-logo-layer.png) |
| Existing game fog reconstructed as a transparent 256 × 256 layer | [game/gba/fog-layer.png](game/gba/fog-layer.png) |

The revised sidebar follows the supplied Minish Cap reference: a curved silver column, white embossed GAME BOY lettering, black ADVANCE lettering, and an indigo ONLY FOR corner tab. The earlier front is preserved in `box/archive/box-front-v1.png`. The cover remains a flat front face, not a box dieline.

The title screen contains **no Pokémon sprites**. The original painted clouds, fog and volcanic smoke have been removed from the game background; the characters remain in the separate box and key-art illustrations.

## Review controls

Use the title selector for Pokémon World, World only, or no logo. Toggle the moving fog, pause/play, scrub its position, and switch between native, 2×, and 3× display scales. Reduced-motion preferences pause playback initially.

The fog reuses `graphics/title_screen/clouds.png`, `clouds.bin`, and `rayquaza_and_clouds.pal`. Its scroll speed and scanline wave match the existing title-screen code; the browser approximates its additive GBA blend. The logo renders above the fog. The interactive canvas is an asset preview; `game/emulator/` contains actual screenshots captured from the built ROMs.

For quick image previews, see [the title screen](game/title-preview.png), [another fog position](game/title-preview-frame-2.png), and [the clear title screen](game/title-preview-clear.png).

## Game exports

`game/gba/` holds the active indexed PNGs, raw tiles, RGB555 palettes, tilemaps, and [manifest](game/gba/manifest.json). Both logos preserve their source aspect ratios: the full logo is 160 × 80 at (39, 4), and WORLD is 144 × 48 at (48, 20). Placement centers the visible outline, excluding uneven transparent padding. The full logo has 43/44-pixel side margins; PRESS START has equal 75-pixel margins. The stack's internal alignment is unchanged. Transparent index zero and integer placement are retained. Both title variants share the scene palette; the final palette bank is reserved for fog.

Rebuild with Node.js, ImageMagick, and the repo's compiled `tools/gbagfx/gbagfx`:

```sh
node assets/branding/pokemon-world/export-gba.mjs
```

The exporter also installs six canonical raw binaries under `graphics/title_screen/world/`. `src/title_screen_world.c` loads them directly; `CB2_InitTitleScreen` selects this scene for the unified World build (`ALL_REGIONS=1`). The full logo is active in the ROM. WORLD-only remains an alternative export.

See [game/INTEGRATION.md](game/INTEGRATION.md) for allocations, rendering settings and test commands. Prior mascot exports are kept in `game/archive/mascot-v1/`; the earlier source and walking sheets remain in `game/sprites/` and `game/overworld/`. None are loaded by the title screen.

## Finished files

The two standalone logos have real PNG alpha transparency. These five full-resolution files have been copied to the requested folder:

```text
/Users/dayers/Library/Mobile Documents/com~apple~CloudDocs/Games/Emulators/GBA/PKMN-World/Pokemon - World - Box Art.png
/Users/dayers/Library/Mobile Documents/com~apple~CloudDocs/Games/Emulators/GBA/PKMN-World/Pokemon - World - Logo.png
/Users/dayers/Library/Mobile Documents/com~apple~CloudDocs/Games/Emulators/GBA/PKMN-World/World - Logo.png
/Users/dayers/Library/Mobile Documents/com~apple~CloudDocs/Games/Emulators/GBA/PKMN-World/Pokemon - World - Artwork.png
/Users/dayers/Library/Mobile Documents/com~apple~CloudDocs/Games/Emulators/GBA/PKMN-World/Pokemon - World - Background.png
```

The updated ROMs are `/Users/dayers/Github/PKMN-World/pokemonworld-release.gba` and `/Users/dayers/Github/PKMN-World/pokemonworld.gba`. The existing iCloud ROM and saves are unchanged.

## Source and validation

The built-in `image_gen` tool produced the cover revision and clear background. Exact prompts are in [PROMPTS.md](PROMPTS.md). The original cover and supplied sidebar reference remain in `source/`; the earlier cloudy background is in `game/masters/archive/`.

Export checks cover tilemap reconstruction, logo geometry, palette allocation and VRAM limits. The fog tile bytes and palette match the repo's native converter. The native `WorldTitle.lua` suite verifies actual VRAM and palette contents, hardware layering, fog motion/wrap, title input, the clear-save cancel path and the music-end intro loop. `SmokeBoot.lua` checks starting a new game and player movement. See [the test report](game/emulator/TEST-REPORT.md) for exact ROM hashes, results and screenshots.
