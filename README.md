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

## ✨ Features

| Feature | What it does |
|---|---|
| 🗺️ **Three regions, one game** | Kanto (FireRed-derived), Johto (ported from *Heart & Soul*), and Hoenn (native Emerald) — each a complete campaign with its own league and post-game. |
| 🚉 **World Transit hub** | Pick your starting region at a central hub, then travel between regions once you've opened each one. |
| 🎒 **Shared progress** | One PC box, Pokédex, and bag across all three regions. Boxed Pokémon obey based on your *current* region's badge count. |
| 🐉 **Ride your own Pokémon** | Surf and fly on your actual team — your walking follower mounts up first if it's able, with a proper riding model for both. |
| 👕 **Character customization** | Play as **Brendan or May** with a 6-color outfit picker — one global choice, applied everywhere. |
| 🏆 **Per-region endgame** | Each region keeps its own league — **Gary** (Kanto), **Lance → Red at Mt. Silver** (Johto), and Hoenn's native league — plus HARD-mode Elite Four and **gym-leader rematches (all 24 leaders)** once you're that region's Champion, with the **Battle Frontier** as the shared post-game. |
| 🌐 **World Championship** | Beat all three regions' leagues, then face a 15-trainer Battle Dome gauntlet of cross-region champions — Red included — for a permanent title and a Gold Bottle Cap. |
| 💎 **Mega Evolution & the Battle Net** | Become a Champion and the **Battle Net** opens above the hub: a director hands you the **Mega Ring** and a free starter-line Mega Stone. Every HARD gym-leader, Elite Four and Champion rematch pays **Shards**, and each leader drops their own **signature Mega Stone** the first time you beat them — the same stone they Mega Evolve with against you. Trade Shards for the rest at the flagship vendor, or swap Battle Points for Shards at the exchange counter. |
| 🧬 **Gen 1–3 only** | Every Pokémon in the game — wild, gift, and trainer-owned — comes from the first three generations, so the roster stays consistent with the three regions it draws from. |
| 🛠️ **Expansion + QoL** | The full pokeemerald-expansion engine plus a suite of ported quality-of-life features behind config toggles. |

## 📊 Status

**v1.3.6** (July 2026) — see the [changelog](CHANGELOG.md) for the full history.

All three campaigns are complete and playable end to end, including each region's post-game.
Recent releases added the World Championship endgame, HARD-mode gym-leader and Elite Four
rematches, riding your own Pokémon for surf and flight, and a long run of fixes from
emulator-verified test passes.

**Newest, and not yet playtested:** Mega Evolution now has a way in. The Battle Net flagship
floor opens above the hub once you're a Champion, HARD rematches drop signature Mega Stones,
and all 28 stone-holding leaders Mega Evolve against you. The trainer roster was also swept
back to Gen 1–3 only, which rebuilt parts of several endgame teams. These systems build clean
but have not had a play pass yet, so expect balance to move.

What's left before a 1.0: a **full-length human playthrough** of all three campaigns for story
pacing and balance, plus the remaining Battle Net battle modes.

<details>
<summary><b>Region-by-region status</b></summary>

<br>

- ✅ **Hoenn** — native (base engine), plus the upgraded HARD Elite Four/Champion rematch.
- ✅ **Johto** — fully ported (~235 maps, real trainer parties, gyms/badges, region map & Fly,
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

_Pokémon Pokemon World is a free, non-commercial fan project. It is not affiliated with, endorsed by, or sponsored by Nintendo, Game Freak, or The Pokémon Company. No ROMs are distributed. You build the game from source using a legally obtained base ROM. It is not for sale or commercial use._

_All Pokémon names, characters, and related assets are the property of their respective owners. I claim no ownership or credit for any original work this project is based on. This project is provided as-is, with no warranty, and is used at your own risk._
