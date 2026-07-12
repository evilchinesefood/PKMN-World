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
  cherry-picked upstream battle/AI fixes
- **ROM:** `pokemonworld.gba` — title `POKEMON WRLD`, code `BPEE`

## ✨ Features

| | |
|---|---|
| 🗺️ **Three regions, one game** | Kanto (FireRed-derived), Johto (ported from *Heart & Soul*), and Hoenn (native Emerald) — each a complete campaign. |
| 🚉 **World Transit hub** | Pick your starting region at a central hub, then travel between regions once you've opened each one. |
| 🎒 **Shared progress** | One PC box, Pokédex, and bag across all three regions. Boxed Pokémon obey based on your *current* region's badge count. |
| 👕 **Character customization** | Play as **Brendan or May** with a 6-color outfit picker — one global choice, applied everywhere. |
| 🏆 **Per-region endgame** | Each region keeps its own league — **Blue** (Kanto), **Lance → Red at Mt. Silver** (Johto), and Hoenn's native league (now with an upgraded HARD-mode Elite Four/Champion rematch) — with the **Battle Frontier**, gated behind your first league clear, as the shared post-game. |
| 🌐 **World Championship** | Beat all three regions' leagues, then face a 15-trainer Battle Dome gauntlet of cross-region champions — Red included — for a permanent title and a Gold Bottle Cap. |
| 🛠️ **Expansion + QoL** | The full pokeemerald-expansion engine plus a suite of ported quality-of-life features behind config toggles. |

## 📊 Status

**v1.1** (2026-07-10) — see the [changelog](CHANGELOG.md). All three campaigns are built,
link-green, and a broad **feature wave** has shipped (overworld flight, follower Pokémon, a
graphical start menu, DexNav, Kanto VS Seeker rematches, dynamic surf, autosave, hard mode, the
HGSS Pokédex, a **World Championship** endgame, and more). Every major system has been
**runtime-verified** on hardware (BizHawk): the new-game flow, hub economy, region switching,
flight and its guardrails, followers, DexNav + hidden-mon detector, autosave, hard mode, the v3
save migration, and VS Seeker rematches all pass.
The remaining gate is a **full-length human campaign playthrough** for story pacing and balance.

<details>
<summary><b>Region-by-region status</b></summary>

<br>

- ✅ **Hoenn** — native (base engine).
- ✅ **Johto** — fully ported (~245 maps, trainers, encounters, gyms/badges, region map & Fly, and all
  post-game: roaming beasts, Celebi, Ruins of Alph puzzles, Bug Contest, Ho-Oh/Lugia).
- ✅ **Kanto** — FireRed campaign wired in: `IS_FRLG`→runtime migration done, 8-badge Elite Four gate,
  rival **Blue**, per-region champion flags, and region-aware starters.
- ✅ **Cross-region glue** — World Transit hub, region-switch travel (unified intro → hub → spatial
  gates, "Mom moves in" arrival, party-boxing switch + resume-at-access-point, per-region access
  points, a champion warp pad), a multi-page trainer card, and 6-outfit customization.
- ✅ **New-game flow** — hardware-verified in BizHawk (2026-07): freeze fixed, blue intro bars,
  Brendan/May sprites, working outfit picker + overworld application, unclipped story pages, and
  visible hub gate signs.
- ✅ **Feature wave + systems** — flight, followers, DexNav, VS Seeker rematches, autosave, hard
  mode, dynamic surf, HGSS dex, hub item distribution, and the save-format migration are all
  runtime-verified in BizHawk (deep probe + test cycles, 2026-07).
- 🟡 **Remaining gate** — a full-length human campaign playthrough (story pacing + balance across
  all three regions).

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
| `data/` | Event/battle/field scripts, ~1180 map folders (Hoenn + bundled FRLG/Kanto + ported Johto), `layouts/`, `tilesets/`, `text/`. |
| `graphics/` · `sound/` | Raw image and audio assets, converted to GBA formats at build time. |
| `asm/` · `constants/` · `libagbsyscall/` | Hand-written assembly + macros, constant includes, GBA BIOS syscall library. |
| `Makefile` · `*.mk` · `tools/` | The modern (`arm-none-eabi-gcc`) build and its auto-compiled tools. |
| `test/` | Battle-engine test suite (`make check`). |

Internal planning/review docs (`.plans/`) and one-off dev scripts (`.dev_scripts/`,
`.migration_scripts/`) are kept **local and untracked** — not part of the build.

</details>

## 📦 Build & docs

- **[INSTALL.md](INSTALL.md)** — setup and build instructions.
- **[FEATURES.md](FEATURES.md)** — full feature list.
- **[CREDITS.md](CREDITS.md)** — credits.

## Credits & license

Built on **pokeemerald-expansion** by the RH-Hideout team and its contributors, itself based on
[pokeemerald](https://github.com/pret/pokeemerald) by pret. See [CREDITS.md](CREDITS.md).

_Pokémon World is a free fan project. It is not affiliated with, endorsed by, or
sponsored by Nintendo, Game Freak, or The Pokémon Company. No ROMs are
distributed — you build the game from source with a legally obtained base.
Not for sale or commercial use._
