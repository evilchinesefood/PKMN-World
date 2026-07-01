# Pokémon World

A private GBA ROM-hack project built on the
[pokeemerald-expansion](https://github.com/rh-hideout/pokeemerald-expansion) engine.

- **Base:** pokeemerald-expansion — upstream commit `66ab6696` (2026-06-23)
- **Output ROM:** `pokemonworld.gba`
- **ROM header:** title `POKEMON WRLD`, game code `BPEE`

## Goal & status

**Pokémon World** merges **three regions into one game** — **Kanto** (FRLG-derived), **Johto**
(ported from the pokeemerald-based *Heart & Soul*), and **Hoenn** (native Emerald) — each a complete
self-contained campaign chosen from a central **World Transit hub**, with a shared PC box / Pokédex /
inventory and per-region badges + champions. `ALL_REGIONS` is permanently on.

- ✅ **Hoenn** — native (base).
- ✅ **Johto** — **fully ported** (~245 maps, trainers, encounters, gyms/badges, region map/Fly, and all
  post-game: roaming beasts, Celebi, Ruins of Alph puzzles, Bug Contest, Ho-Oh/Lugia). Link-green; a
  runtime playtest is the remaining gate.
- ✅ **Kanto** — FRLG campaign wired: `IS_FRLG`→runtime migration done, plus an 8-Kanto-badge Elite
  Four gate, rival **BLUE**, per-region champion flags, and region-aware starters. Playtest gate.
- ✅ **Cross-region glue** — the World Transit hub + region-switch travel (unified Oak intro → hub →
  spatial gates, "Mom moves in" arrival, party-boxing region switch + resume-at-access-point, per-region
  access points, a 2-region-champion PC-2F warp pad), the multi-page trainer card, and 6-outfit character
  customization are all **BUILT** (link-green, pushed). The **Battle Frontier** is the shared super-endgame.
  Runtime playtest is the remaining gate.

The full roadmap lives in `.plans/MasterPlan.md` (local, not tracked).

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
  (`event_scripts.s`, `battle_scripts_*.s`), map data (`maps/` — ~1180 map folders covering
  native Hoenn, the bundled FRLG/Kanto maps, and the fully-ported Johto maps), `layouts/`,
  `tilesets/`, and `text/`.
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

Build-time helpers and assets live in the standard decomp locations (`tools/`, `*.mk`,
`charmap.txt`, `libagbsyscall/`). Migration and one-off developer scripts are **kept local
and untracked** under dot-prefixed folders (`.migration_scripts/`, `.dev_scripts/`) — they
are not part of the build, so they are gitignored rather than published.

### Documentation

- Internal planning and review docs (architecture overview, region-merge roadmap, design specs,
  port reviews) are kept locally under `.plans/` (organized into `features/`, `reviews/`, `done/`,
  with `MasterPlan.md` as the index) and are **not** tracked in this repository.
- [FEATURES.md](FEATURES.md) — feature list.
- [INSTALL.md](INSTALL.md) — setup and build instructions.
- [CREDITS.md](CREDITS.md) — credits.

## Credits & License

Built on pokeemerald-expansion by the RH-Hideout team and its contributors, itself based on
[pokeemerald](https://github.com/pret/pokeemerald) by pret. See [CREDITS.md](CREDITS.md).

This repository is private and intended for personal use only.
