<div align="center">

<img src=".github/pokemon_world_logo.png" width="340" alt="Pokémon World logo">

# World

**Three regions. Three complete adventures. One cartridge.**

A Game Boy Advance ROM hack built on
[pokeemerald-expansion](https://github.com/rh-hideout/pokeemerald-expansion).

[**Install**](INSTALL.md) · [**Features**](FEATURES.md) · [**Credits**](CREDITS.md)

</div>

---

## 🌏 What is it?

**Pokémon World** merges **Kanto**, **Johto**, and **Hoenn** into a single Game Boy Advance game.
Each region is a full, self-contained adventure — its own story, 8 gyms, badges, Elite Four, and
Champion — and you choose which to play from a central **World Transit hub**. Your **PC box,
Pokédex, and bag are shared** across all three, so the Pokémon you raise travel with you between
worlds.

- **Engine:** pokeemerald-expansion (upstream `66ab6696`, 2026-06-23) + 20
  cherry-picked upstream fixes
- **ROM:** `pokemonworld.gba` — title `POKEMON WRLD`, code `BPEE`

## 📊 Status

**v1.4** (July 2026) — see the [changelog](CHANGELOG.md) for the full history.

All three campaigns are complete and playable end to end, including each region's post-game.
Earlier releases added the World Championship endgame, HARD-mode gym-leader and Elite Four
rematches, riding your own Pokémon for surf and flight, and a long run of fixes from
emulator-verified test passes.

**New in v1.4:** the **Battle Net**. Its flagship floor opens above the hub once you're a
Champion — HARD rematches drop signature Mega Stones, and all 28 stone-holding leaders Mega
Evolve against you — with its battle modes live: the Scaling Type Trainer, the Leader Sim, the
7-win Tower Streak, and the Lv50/Monotype/Little Cup ruleset rooms, plus a Battle Net wall terminal in
every Pokémon Center lobby. Sims pay **full EXP** (and evolutions), making them the game's training
grounds — in Hard Mode the badge level caps still apply, so they can't outrun your progression.
v1.4 also enforces the **Gen 1–3 roster** across every party, and carries a large fix wave from
scripted emulator test passes. The Battle Net hasn't had a human play pass yet, so expect
balance to move.

What's left: a **full-length human playthrough** of all three campaigns for story pacing and
balance.

<details>
<summary><b>Region-by-region status</b></summary>

<br>

- ✅ **Hoenn** — native (base engine), plus the upgraded HARD Elite Four/Champion rematch.
- ✅ **Johto** — fully ported (~254 maps, real trainer parties, gyms/badges, region map & Fly,
  and all post-game: Red at Mt. Silver, roaming beasts, Celebi, Ruins of Alph, Bug-Catching
  Contest, Ho-Oh/Lugia).
- ✅ **Kanto** — the FireRed campaign wired in: real FRLG trainer parties, gym/Elite Four/Champion
  rosters, rival **GARY** (who is also the Kanto Champion), and the 8-badge league gate.
- ✅ **Cross-region systems** — World Transit hub, region-switch travel, per-region access
  points and champion warp pads, a multi-page trainer card, and 6-outfit customization.
- 🟡 **In progress** — a full-length human playthrough of all three campaigns (story pacing
  + balance).

</details>

<details>
<summary><b>Project layout</b></summary>

<br>

A decomp-style project — the ROM is reassembled from C source, assembly, JSON data, and raw
assets, following pokeemerald / pokeemerald-expansion conventions.

| Path | Contents |
|---|---|
| `src/` · `include/` | Game + engine C source (~390 files) and matching headers. |
| `include/config/` | Feature-toggle headers — the first place to look to enable or tune a feature. |
| `data/` | Event/battle/field scripts, ~1190 map folders (Hoenn + Kanto + ported Johto), `layouts/`, `tilesets/`, `text/`. |
| `graphics/` · `sound/` | Raw image and audio assets, converted to GBA formats at build time. |
| `asm/` · `constants/` · `libagbsyscall/` | Hand-written assembly + macros, constant includes, GBA BIOS syscall library. |
| `Makefile` · `*.mk` · `tools/` | The modern (`arm-none-eabi-gcc`) build and its auto-compiled tools. |
| `test/` | Battle-engine test suite (`make check`). |

</details>

## 📦 Build & docs

- **[INSTALL.md](INSTALL.md)** — setup and build instructions.
- **[FEATURES.md](FEATURES.md)** — full feature list.
- **[CREDITS.md](CREDITS.md)** — credits.

## Credits & license

Built on **pokeemerald-expansion** by the RH-Hideout team and its contributors, itself based on
[pokeemerald](https://github.com/pret/pokeemerald) by pret. See [CREDITS.md](CREDITS.md).

_Pokémon World is a free, non-commercial fan project. It is not affiliated with, endorsed by, or sponsored by Nintendo, Game Freak, or The Pokémon Company. No ROMs are distributed. You build the game from source using a legally obtained base ROM. It is not for sale or commercial use._

_All Pokémon names, characters, and related assets are the property of their respective owners. I claim no ownership or credit for any original work this project is based on. This project is provided as-is, with no warranty, and is used at your own risk._
