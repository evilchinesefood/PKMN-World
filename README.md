<div align="center">

<img src=".github/pokemon_world_logo.png" width="340" alt="Pokémon World logo">

# World

**Three regions. Three complete adventures. One cartridge.**

A Game Boy Advance ROM hack built on
[pokeemerald-expansion](https://github.com/rh-hideout/pokeemerald-expansion).

[**Install**](INSTALL.md) · [**Features**](FEATURES.md) · [**Changelog**](CHANGELOG.md) · [**Credits**](CREDITS.md)

</div>

---

## What is it?

**Pokémon World** puts **Kanto**, **Johto** and **Hoenn** on one GBA cartridge. Each region is a
complete adventure — its own story, 8 gyms, Elite Four and Champion — and you pick which to play
from a central **World Transit hub**.

Your **PC boxes, Pokédex, bag and money are shared** across all three, so the Pokémon you raise
travel with you. Badges, story flags and trainer defeats stay **per region**, so clearing Hoenn
doesn't hand you Johto's progress (or Johto's difficulty).

The roster is **Generations 1–3 only**, family trees intact — later-gen evolutions of Gen 1–3
lines (Togekiss, Electivire, Weavile, Sylveon…) are kept and obtainable. All 339 Gen 4–9 families
are compiled out, and `make validate` fails if any wild table, gift or trainer party still
references one.

- **Engine:** pokeemerald-expansion 1.16.2 (`include/constants/expansion.h`)
- **ROM:** `pokemonworld.gba` — title `POKEMON WRLD`, code `BPEE`

## Build it

You need devkitARM. The build is modern-toolchain only — agbcc is not used.

```sh
make modern -j8      # produces pokemonworld.gba
```

Full setup, toolchain notes and troubleshooting live in **[INSTALL.md](INSTALL.md)**.

| Command | What it does |
|---|---|
| `make modern` | Build the ROM (this is the normal build) |
| `make validate` | Host-side content checks — Gen 1–3 rule, script pointers, map events. Seconds, no build needed |
| `make check` | The inherited battle-engine test suite (~5,500 tests, ~23 min) |
| `Testing/run-all.sh` | 43 in-game overworld suites on a patched headless mGBA (44 with the optional owner save). Local only — see `Testing/mgba/README.md` |
| `make RELEASE=1` | Optimized build with the debug menu stripped |

CI (`.github/workflows/Check.yml`) runs the host validators and `make check`. It never uploads a
ROM, and the emulator suites can't run there.

## Status

**Last tagged release: v1.5** (2026-08-24). See the [changelog](CHANGELOG.md) for the full
entry; the headline items since v1.4:

- The link-era features (Mystery Gift/Event, Union Room, record mixing, Cable Club) and the
  never-populated quest engine are **compiled out**.
- The Battle Net terminal moved into a **wall unit in all 50 Pokémon Center lobbies**, and the
  old Center 2Fs are sealed.
- The **S.S. Aqua actually lands in Kanto** — you disembark at the new Vermilion City port with
  your team intact.
- A long run of Johto script, trainer-data and save-migration fixes. The save format is now
  **v9**; v7 and v8 saves migrate forward, anything older is refused at load with an explanation.
- **Whirlpool is implemented**, which unseals **Lugia** and the **Dragon's Den Shrine** — both
  were unreachable in every save, walled off by invisible blockers that no move could clear.
- **Wild encounters are flat**: every Pokémon is catchable at any hour. The clock still changes
  the light and which Pokémon roam the overworld, but no longer gates the grass.
- Johto's **music pass is finished** — its own cycling, surfing and trainer-approach themes, and
  the Radio Tower plays the occupation theme while Rocket holds it.
- Caught up with **upstream pokeemerald-expansion** (merged to their master of 2026-08-23).

All three campaigns are playable end to end, including each region's post-game. What's left is a
**full-length human playthrough** of all three for story pacing and balance — the Battle Net in
particular has only been driven by scripted tests, so expect its numbers to move.

<details>
<summary><b>Region-by-region</b></summary>

<br>

- **Hoenn** — the native Emerald campaign, plus HARD Elite Four and Champion rematches. The
  Battle Frontier is the shared post-game facility, reachable from the hub once you've cleared
  any one region's league.
- **Johto** — ported in: 251 maps with tilesets and scripts, 312 distinct trainers, wild tables,
  the Johto town map with Fly and heal locations, HGSS-style portraits for the gym leaders and
  Elite Four, and the post-game (Red at Mt. Silver, roaming beasts, the Celebi GS Ball chain,
  Ruins of Alph, the Bug-Catching Contest, Ho-Oh and Lugia).
- **Kanto** — the FireRed campaign wired in: real FRLG trainer parties, gym/Elite Four/Champion
  rosters, rival **GARY** (who is also the Kanto Champion), and the Route 23 badge gate.
- **Cross-region** — the World Transit hub, region switching, per-region access points, a
  three-page trainer card (L/R flips between Hoenn, Kanto and Johto badges), and six outfits.

</details>

<details>
<summary><b>Project layout</b></summary>

<br>

A decomp-style project — the ROM is reassembled from C source, assembly, JSON data and raw
assets, following pokeemerald / pokeemerald-expansion conventions.

| Path | Contents |
|---|---|
| `src/` · `include/` | Game and engine C source (397 `.c` files) and headers. |
| `include/config/` | Feature-toggle headers — the first place to look to enable or tune a feature. |
| `data/` | Event/battle/field scripts, 1,189 maps (Hoenn + Kanto + ported Johto), `layouts/`, `tilesets/`, `text/`. |
| `graphics/` · `sound/` | Raw image and audio assets, converted to GBA formats at build time. |
| `asm/` · `constants/` · `libagbsyscall/` | Hand-written assembly and macros, constant includes, GBA BIOS syscall library. |
| `tools/` | Build tools, compiled automatically by the Makefile. |
| `test/` | Battle-engine test suite (`make check`). |
| `Testing/` | This project's own checks: host validators (`Validate*.py`) and the Lua overworld suites. |

</details>

## Credits & license

Built on **pokeemerald-expansion** by the RH-Hideout team and its contributors, itself based on
[pokeemerald](https://github.com/pret/pokeemerald) by pret. See [CREDITS.md](CREDITS.md).

_Pokémon World is a free, non-commercial fan project. It is not affiliated with, endorsed by, or sponsored by Nintendo, Game Freak, or The Pokémon Company. No ROMs are distributed. You build the game from source using a legally obtained base ROM. It is not for sale or commercial use._

_All Pokémon names, characters, and related assets are the property of their respective owners. I claim no ownership or credit for any original work this project is based on. This project is provided as-is, with no warranty, and is used at your own risk._
