**Completion status:** Kanto, Johto, Hoenn and the world hub each have **100% registered-map structural audit coverage**. Feature-completion percentages remain **unverified**; full campaign/post-game playthroughs are still required. [Verified scope and remaining checks](maintenance/final-pass/zone-status.md).

<div align="center">

<img src="graphics/branding/logos/pokemon-world.png" width="340" height="170" alt="Pokémon World logo">

**Three regions. One connected adventure. One cartridge.**

A Game Boy Advance ROM hack built on
[pokeemerald-expansion](https://github.com/rh-hideout/pokeemerald-expansion).

[**Install**](INSTALL.md) · [**Features**](FEATURES.md) · [**Changelog**](CHANGELOG.md) · [**Credits**](CREDITS.md)

</div>

---

## What is it?

**Pokémon World** puts **Kanto**, **Johto** and **Hoenn** on one GBA cartridge. Each region has
its own story, 8 gyms, Elite Four and Champion — and you pick which to play
from a central **World Transit hub**.

Your **PC boxes, Pokédex, bag and money are shared** across all three, so the Pokémon you raise
travel with you. Badges, story flags and trainer defeats stay **per region**, so clearing Hoenn
doesn't hand you Johto's progress (or Johto's difficulty).

**Returning after a break?** Open **Story** from the Start menu, available from your first
normal menu in the hub or any region. Review Kanto, Johto and Hoenn without travelling:
status, regional badges, your current chapter, the next action and its destination,
prerequisites and last established milestone. Started optional errands have separate pages;
Champion campaigns keep their **Main story complete** status. [Controls and coverage](docs/story-progress/README.md).

The roster is **Generations 1–3 only**, family trees intact — later-gen evolutions of Gen 1–3
lines (Togekiss, Electivire, Weavile, Sylveon…) are kept and obtainable. All 339 Gen 4–9 families
are compiled out, and `make validate` fails if any wild table, gift or trainer party still
references one.

- **Engine:** pokeemerald-expansion 1.16.4 dev, untagged: upstream master `82598c4d88` (2026-08-23),
  past the 1.16.3 release (`include/constants/expansion.h`)
- **ROM:** `pokemonworld.gba` — title `POKEMON WRLD`, code `BPEE`

## Screenshots

Native 240 × 160 mGBA screenshots. Scenes use disposable saves, debug warps
and synthetic teams/items; menu/battle fixtures invoke the production renderer.
Images are unretouched. [Capture methods and hashes](graphics/branding/screenshots/showcase/README.md).

<table>
  <tr>
    <td><img src="graphics/branding/screenshots/showcase/01-title.png" width="240" height="160" alt="Title screen" title="Title screen"></td>
    <td><img src="graphics/branding/screenshots/showcase/02-world-transit.png" width="240" height="160" alt="World Transit hub" title="World Transit hub"></td>
    <td><img src="graphics/branding/screenshots/showcase/13-battle-frontier.png" width="240" height="160" alt="Battle Frontier" title="Battle Frontier"></td>
  </tr>
  <tr>
    <td><img src="graphics/branding/screenshots/showcase/05-kanto-celadon.png" width="240" height="160" alt="Kanto — Celadon City" title="Kanto — Celadon City"></td>
    <td><img src="graphics/branding/screenshots/showcase/06-johto-cherrygrove.png" width="240" height="160" alt="Johto — Cherrygrove City" title="Johto — Cherrygrove City"></td>
    <td><img src="graphics/branding/screenshots/showcase/09-hoenn-mossdeep.png" width="240" height="160" alt="Hoenn — Mossdeep City" title="Hoenn — Mossdeep City"></td>
  </tr>
  <tr>
    <td><img src="graphics/branding/screenshots/showcase/15-party.png" width="240" height="160" alt="Party and follower chooser" title="Party and follower chooser"></td>
    <td><img src="graphics/branding/screenshots/showcase/16-bag.png" width="240" height="160" alt="Bag" title="Bag"></td>
    <td><img src="graphics/branding/screenshots/showcase/17-summary.png" width="240" height="160" alt="Pokémon summary" title="Pokémon summary"></td>
  </tr>
  <tr>
    <td><img src="graphics/branding/screenshots/showcase/18-dexnav.png" width="240" height="160" alt="DexNav on Route 101" title="DexNav on Route 101"></td>
    <td><img src="graphics/branding/screenshots/showcase/19-battle.png" width="240" height="160" alt="Battle commands and BW healthboxes" title="Battle commands and BW healthboxes"></td>
    <td><img src="graphics/branding/screenshots/showcase/20-options.png" width="240" height="160" alt="World Panels Options" title="World Panels Options"></td>
  </tr>
</table>

## Build it

You need devkitARM. The build is modern-toolchain only — agbcc is not used.

```sh
make modern -j8      # produces pokemonworld.gba
```

Full setup, toolchain notes and troubleshooting live in **[INSTALL.md](INSTALL.md)**.

| Command | What it does |
|---|---|
| `make modern` | Build the ROM (this is the normal build) |
| `make validate` | Host-side content checks — species, scripts, map events, layouts/warps/connections and encounters |
| `make check` | The inherited battle-engine test suite (5,700 cases, including explicit upstream skipped categories) |
| `test/overworld/run-all.sh` | 51 mandatory in-game overworld suites on a patched headless mGBA (52 with the optional owner save). Local only — see `test/overworld/mgba/README.md` |
| `make RELEASE=1` | Optimized build with the debug menu stripped |

CI (`.github/workflows/Check.yml`) runs the host validators and `make check`. It never uploads a
ROM, and the emulator suites can't run there.

## Status

**Last tagged release: v1.7** (2026-09-30). See the [changelog](CHANGELOG.md) for the full
entry. Save format is **v10**, unchanged from v1.6; v7 and newer migrate forward, anything
older is refused. Headline items since v1.6:

- A **Black/White-style battle interface**, with battle backgrounds that match Ice Path,
  Mt. Silver and the time of day.
- **Story** in the Start menu shows each region's badges, current chapter and next step.
- Restyled **menus, Bag and PC**, **warm night windows** in 49 town maps, redrawn **outfit
  colours**, and a landscaped **Viridian City**.
- Friendship, move and partner evolutions **also happen at a level**, and **Eevee evolves by
  stone only**.

The v1.6 headlines, still in this build:

- A crowded overworld **skips a sprite it cannot fit** instead of crashing.
- **Victory Road, Seafoam Islands, Route 41, the Johto map marker, Bill's Eevee,
  the Dojo and Mt. Moon gifts, and the Rocket HQ multi battle** are fixed.
- The title screen is **Pokémon World**.

The campaigns and their post-game scripts are implemented. The final pass verified all
1,190 registered map structures and passed 51 fresh emulator suites, including boot,
regional travel and targeted progression checks. **Full continuous campaign and post-game
playthroughs remain unverified**; source presence and targeted tests do not establish a
feature-complete percentage. Battle Net balance also needs full-length human playtesting.
See the [final-pass report](maintenance/final-pass/README.md) and
[per-zone verification limits](maintenance/final-pass/zone-status.md).

<details>
<summary><b>Region-by-region</b></summary>

<br>

- **Hoenn** — the native Emerald campaign, plus HARD Elite Four and Champion rematches. The
  Battle Frontier is the shared post-game facility, reachable from the hub once you've cleared
  any one region's league.
- **Johto** — ported in: 252 registered maps with tilesets, scripts and dedicated trainer rosters, wild tables,
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
| `src/` · `include/` | Game and engine C source and headers. |
| `include/config/` | Feature-toggle headers — the first place to look to enable or tune a feature. |
| `data/` | Event/battle/field scripts, 1,190 registered maps (Hoenn + Kanto + ported Johto), `layouts/`, `tilesets/`, `text/`. |
| `graphics/` · `sound/` | Raw image and audio assets, converted to GBA formats at build time; branding and the screenshot gallery live in `graphics/branding/`. |
| `asm/` · `constants/` · `libagbsyscall/` | Hand-written assembly and macros, constant includes, GBA BIOS syscall library. |
| `tools/` | Build tools, compiled automatically by the Makefile. |
| `test/` | Battle-engine test suite (`make check`). |
| `test/overworld/` | This project's own checks: host validators (`Validate*.py`) and the Lua overworld suites. |

</details>

## Credits & license

Built on **pokeemerald-expansion** by the RH-Hideout team and its contributors, itself based on
[pokeemerald](https://github.com/pret/pokeemerald) by pret. See [CREDITS.md](CREDITS.md).

_Pokémon World is a free, non-commercial fan project. It is not affiliated with, endorsed by, or sponsored by Nintendo, Game Freak, or The Pokémon Company. No ROMs are distributed. You build the game from source using a legally obtained base ROM. It is not for sale or commercial use._

_All Pokémon names, characters, and related assets are the property of their respective owners. I claim no ownership or credit for any original work this project is based on. This project is provided as-is, with no warranty, and is used at your own risk._
