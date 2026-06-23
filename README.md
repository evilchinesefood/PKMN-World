# Pokémon World

A private GBA ROM-hack project built on the
[pokeemerald-expansion](https://github.com/rh-hideout/pokeemerald-expansion) engine.

- **Base:** pokeemerald-expansion — upstream commit `66ab6696` (2026-06-23)
- **Output ROM:** `pokemonworld.gba`
- **ROM header:** title `POKEMON WRLD`, game code `BPEE`

## Building

This project uses the **modern** toolchain (`arm-none-eabi-gcc` + newlib). agbcc is not used.

```bash
make -j$(nproc)         # build pokemonworld.gba
make -j$(nproc) check   # build + run the battle-engine test suite
make clean
```

Requires on `PATH`: `arm-none-eabi-gcc`, `arm-none-eabi` binutils, newlib (`libc.a`/`libnosys.a`),
plus `make`, `gcc`/`g++`, `python3`, and `libpng`.

## Layout

- `src/`, `include/` — engine and game C source / headers
- `include/config/` — feature toggles and mechanics configuration
- `data/`, `graphics/`, `sound/` — game assets (maps, scripts, sprites, audio)
- `test/` — battle-engine test suite (`make check`)
- `tools/` — build tools (compiled automatically)
- `FEATURES.md` — overview of engine features inherited from the expansion

## Credits & License

Built on pokeemerald-expansion by the RH-Hideout team and its contributors, itself based on
[pokeemerald](https://github.com/pret/pokeemerald) by pret. See `CREDITS.md`. This repository is
private and intended for personal use.
