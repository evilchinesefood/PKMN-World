# Pokémon World

A private GBA ROM-hack project built on the
[pokeemerald-expansion](https://github.com/rh-hideout/pokeemerald-expansion) engine.

- **Base:** pokeemerald-expansion — upstream commit `66ab6696` (2026-06-23)
- **Output ROM:** `pokemonworld.gba`
- **ROM header:** title `POKEMON WRLD`, game code `BPEE`

See [INSTALL.md](INSTALL.md) for setup and build instructions.
See [FEATURES.md](FEATURES.md) for the feature list.

## Layout

This is a decomp-style project: the ROM is reassembled from C source, assembly, JSON
data, and raw assets. The top-level organization follows pokeemerald / pokeemerald-expansion
conventions.

### Source

- `src/` — the bulk of the game and engine C source (~390 files). Includes the project's
  ported features alongside the inherited engine: `comfy_anim.c` (shared animation library),
  the SwSh UI suite (`swsh_party_menu.c`, `swsh_summary_screen.c`, `swsh_storage_system.c`,
  `swsh_item_menu.c`), `quests.c` (quest system), `pokevial.c` (refillable party-heal key
  item), and `field_move.c` (HM / field-move handling).
- `include/` — C headers matching `src/`.
- `include/config/` — feature-toggle headers. Most ported features ship behind default-OFF
  flags here: `quests.h`, `pokevial.h`, `qol_field_moves.h`, `swsh_party_menu.h`,
  `swsh_item_menu.h`, `summary_screen.h`, `name_box.h`, `overworld.h` (`OW_POPUP_GENERATION`),
  `item.h` (`I_KEY_ITEM_WHEEL`), plus the broader engine config (`battle.h`, `pokemon.h`,
  `general.h`, `caps.h`, `wild_encounter.h`, etc.). This is the first place to look when
  enabling or tuning a feature.
- `asm/` — hand-written assembly and macros (`macros.inc`) still required by the build.
- `constants/` — assembly-side constant includes (`constants.inc`, `gba_constants.inc`,
  `global.inc`, `m4a_constants.inc`).
- `libagbsyscall/` — GBA BIOS syscall library.

### Data and assets

- `data/` — game data as assembly and scripts: event/battle/field-effect scripts
  (`event_scripts.s`, `battle_scripts_*.s`), map data (`maps/` — ~940 map folders covering
  native Hoenn plus the bundled-but-inert FRLG/Kanto maps), `layouts/`, `tilesets/`, and
  `text/`.
- `graphics/` — raw image assets (sprites, tilesets, UI, battle anims, fonts, etc.), converted
  to GBA formats at build time.
- `sound/` — music (`songs/`), cries, and sample data; assembled into the audio engine.

### Build system and tools

- `Makefile`, `config.mk`, and the `*.mk` rule files (`audio_rules.mk`, `graphics_file_rules.mk`,
  `map_data_rules.mk`, etc.) — the modern (`arm-none-eabi-gcc` + newlib) build. See
  [INSTALL.md](INSTALL.md).
- `ld_script.ld`, `ld_script_modern.ld`, `ld_script_test.ld` — linker scripts.
- `tools/` — build tools (`preproc`, `gbagfx`, `mapjson`, `jsonproc`, `mid2agb`, `gbafix`,
  `trainerproc`, etc.), compiled automatically during the build.
- `build/` — build output (object files, intermediates); not tracked.

### Tests

- `test/` — the battle-engine test suite, run via `make check`. See [INSTALL.md](INSTALL.md).

### Scripts

- `migration_scripts/` — upstream helpers for migrating between refactored expansion systems,
  plus project-specific scripts (e.g. `add_region_hoenn_attribute_to_hoenn_maps.py`,
  `frlg_metatile_behavior_converter.py`) used while integrating the bundled maps. See
  `migration_scripts/README.md`.
- `dev_scripts/` — local developer utilities (e.g. `delete_frlg_maps.py`, `gba_gfx/`,
  `followers/`).

### Documentation

- Internal planning and review docs (architecture overview, region-merge roadmap, port
  reviews) are kept locally under `docs/` and are **not** tracked in this repository.
- [FEATURES.md](FEATURES.md) — feature list.
- [INSTALL.md](INSTALL.md) — setup and build instructions.
- [CREDITS.md](CREDITS.md) — credits.

## Credits & License

Built on pokeemerald-expansion by the RH-Hideout team and its contributors, itself based on
[pokeemerald](https://github.com/pret/pokeemerald) by pret. See [CREDITS.md](CREDITS.md).

This repository is private and intended for personal use only.
