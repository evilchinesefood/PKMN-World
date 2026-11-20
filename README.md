> **Status: complete.** All three regions, their Leagues and their post-games are playable from a
> new save, and the game is tested end to end. Automated playthroughs take one fresh save through
> Kanto, Johto and Hoenn to all three Halls of Fame, in two different region orders, with the
> post-game and the Sevii Islands included. The latest runs (master `ba5610eb82`) passed 438 of 438
> and 406 of 406 checks with no retries.
> [World playthrough results](test/overworld/world-playthrough/README.md)

<div align="center">

<img src="graphics/branding/logos/pokemon-world.png" width="340" height="170" alt="Pokémon World logo">

**Three regions. One connected adventure. One cartridge.**

A Game Boy Advance ROM hack built on
[pokeemerald-expansion](https://github.com/rh-hideout/pokeemerald-expansion).

[**Install**](INSTALL.md) · [**Features**](FEATURES.md) · [**Pokédex**](POKEDEX.md) · [**Changelog**](CHANGELOG.md) · [**Credits**](CREDITS.md)

</div>

---

## What it is

Pokémon World puts **Kanto**, **Johto** and **Hoenn** on one GBA cartridge. Each region has its
own story, eight gyms, Elite Four and Champion. You choose a region from the central **World
Transit hub**.

- **Shared across regions:** PC boxes, Pokédex, Bag and money. The Pokémon you raise travel with you.
- **Kept per region:** badges, story flags and trainer defeats. Clearing Hoenn does not give you
  Johto's progress or change Johto's difficulty.
- **Story screen:** open **Story** from the Start menu in the hub or any region. It shows each
  region's status, badges, current chapter, next step and where to go.
  [Controls and coverage](docs/story-progress/README.md).
- **Roster:** Generations 1 to 3, with family trees intact. All 339 Gen 4 to 9 families are
  compiled out, and `make validate` fails if a wild table, gift or trainer party references one.
  [POKEDEX.md](POKEDEX.md) lists every Pokémon and item with where to get it.

| | |
|---|---|
| Regions | 3 (Kanto, Johto, Hoenn), plus the World Transit hub and the Sevii Islands |
| Badges | 24 (8 per region) |
| Pokémon | 404 obtainable: 383 of the 386 from Gen 1 to 3, plus 21 later-generation relatives such as Weavile, Magnezone and Leafeon |
| Mega Evolutions | 39 |
| Maps | 1,151 |
| Engine | pokeemerald-expansion 1.16.4 dev, untagged upstream master `82598c4d88` (2026-08-23), past the 1.16.3 release (`include/constants/expansion.h`) |
| ROM | `pokemonworld.gba`, title `POKEMON WRLD`, code `BPEE` |

## Custom features

- **World Transit hub.** Four departure gates, shops, a wardrobe, and staff who reward badge,
  championship and Pokédex milestones.
- **Regional teams.** Each gate remembers the party you last used in that region and can return
  you to the last Pokémon Center you entered there.
- **Story screen.** Per-region status, badges, next step and destination from the Start menu.
- **Champion rematches.** All 24 gym leaders, the three Elite Fours and the Champions field HARD
  teams once you are that region's Champion.
- **Battle Net.** Simulated battles at a wall terminal in 50 Pokémon Center lobbies, plus a
  flagship floor in the hub with streak and rule rooms.
- **Mega Evolution.** 39 Megas. Stones come from HARD rematch wins and a Shard vendor.
- **World Championship.** A 15-trainer bracket of champions, open after all three Leagues.
- **Team Rocket ambushes.** Five one-against-two battles with Jessie and James.
- **Costume Pokémon.** Seven one-off costume Pikachu, Squirtle, Eevee and Totodile to collect.
- **Riding.** Surf and fly on your own Pokémon. The Sky Charm gives free flight outdoors.
- **No HM chores.** A Pokémon that can learn a field move uses it without being taught.
- **Offline evolutions.** A Linking Cord or the trade item from the Bag replaces trading, and
  friendship, move and partner evolutions also happen at a set level.
- **Exploration.** Follower Pokémon, visible wild Pokémon, DexNav with hidden encounters on every
  land route, catchable starters, and wild tables that ignore the time of day.
- **Options.** Exp, Catch, Encounter and Money Loss rates, Shared Exp, Instant text, Autosave, Auto
  Run and a Run shortcut.
- **Presentation.** Black/White-style battle screen, Sword/Shield-style party, Bag, summary and PC,
  an icon Start menu, an HGSS-style Pokédex, a key-item wheel and a three-page trainer card.

[FEATURES.md](FEATURES.md) describes each one.

<details>
<summary><b>Region by region</b></summary>

<br>

- **Hoenn.** The native Emerald campaign, plus HARD Elite Four and Champion rematches. The
  Battle Frontier is the shared post-game facility. You reach it from the hub after you clear any
  one region's League.
- **Johto.** 249 ported maps with tilesets, scripts, trainer rosters and wild tables. It has its own
  town map with Fly and heal locations, and HGSS-style portraits for the gym leaders and Elite Four.
  The post-game includes Red at Mt. Silver, the roaming Entei and Raikou, the Celebi GS Ball chain, the Ruins
  of Alph, the Bug-Catching Contest, Ho-Oh and Lugia.
- **Kanto.** The FireRed campaign with real FRLG trainer parties and League rosters, the Route 23
  badge gate, and rival **GARY**, who is also the Kanto Champion.
- **Across regions.** The World Transit hub, region switching, per-region access points, a
  three-page trainer card (L and R flip between Hoenn, Kanto and Johto badges), and a wardrobe with
  regional outfits.

</details>

## Screenshots

Native 240 × 160 mGBA screenshots, unretouched. Scenes use disposable saves, debug warps and
synthetic teams and items. Menu and battle fixtures use the production renderer.
[Capture methods and hashes](graphics/branding/screenshots/showcase/README.md).

<table>
  <tr>
    <td><img src="graphics/branding/screenshots/showcase/01-title.png" width="240" height="160" alt="Title screen" title="Title screen"></td>
    <td><img src="graphics/branding/screenshots/showcase/02-world-transit.png" width="240" height="160" alt="World Transit hub" title="World Transit hub"></td>
    <td><img src="graphics/branding/screenshots/showcase/13-battle-frontier.png" width="240" height="160" alt="Battle Frontier" title="Battle Frontier"></td>
  </tr>
  <tr>
    <td><img src="graphics/branding/screenshots/showcase/05-kanto-celadon.png" width="240" height="160" alt="Kanto, Celadon City" title="Kanto, Celadon City"></td>
    <td><img src="graphics/branding/screenshots/showcase/06-johto-cherrygrove.png" width="240" height="160" alt="Johto, Cherrygrove City" title="Johto, Cherrygrove City"></td>
    <td><img src="graphics/branding/screenshots/showcase/09-hoenn-mossdeep.png" width="240" height="160" alt="Hoenn, Mossdeep City" title="Hoenn, Mossdeep City"></td>
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

## Build and test

You need devkitARM. The build uses the modern toolchain only, not agbcc.

```sh
make modern -j8      # produces pokemonworld.gba
```

[INSTALL.md](INSTALL.md) covers setup, toolchain notes and troubleshooting.

| Command | What it does |
|---|---|
| `make modern` | Builds the default ROM. |
| `python3 test/validate-host.py` | Validates host-side content without a game build. |
| `python3 test/verify.py build` | Builds the default ROM in isolation. |
| `python3 test/verify.py smoke` | Builds, then runs the startup, travel and save checks. |
| `python3 test/verify.py full` | Builds, then runs the Lua cases, early regional losses, battle checks, palette check and feature-off builds. |
| `make check TESTS='test name'` | Runs one battle-engine test. |
| `test/overworld/run-all.sh` | Runs the Lua overworld sweep against a ROM you already built. |

Pull requests and `master` pushes run host validation only. Builds and gameplay tests run when you
ask for them, locally or through [Verify on demand](.github/workflows/Verify.yml). Nothing runs on
a schedule, and CI uploads no build output. See the
[native verification guide](test/overworld/mgba/README.md) and the [release gate](RELEASING.md).

<details>
<summary><b>Project layout</b></summary>

<br>

The ROM is built from C source, assembly, JSON data and raw assets, following pokeemerald and
pokeemerald-expansion conventions.

| Path | Contents |
|---|---|
| `src/`, `include/` | Game and engine C source and headers. |
| `include/config/` | Feature-toggle headers. Start here to turn a feature on, off or tune it. |
| `data/` | Event, battle and field scripts; 1,151 registered maps across Hoenn, Kanto and Johto; `layouts/`, `tilesets/`, `text/`. |
| `graphics/`, `sound/` | Image and audio assets, converted at build time. Branding and screenshots are in `graphics/branding/`. |
| `asm/`, `constants/`, `libagbsyscall/` | Hand-written assembly and macros, constant includes, and the GBA BIOS syscall library. |
| `tools/` | Build tools. The Makefile compiles them. |
| `test/` | Battle-engine test suite (`make check`). |
| `test/overworld/` | Project checks: host validators (`Validate*.py`), Lua overworld suites and the campaign playthrough harnesses. |

</details>

## Credits and license

Built on **pokeemerald-expansion** by the RH-Hideout team and its contributors, which is based on
[pokeemerald](https://github.com/pret/pokeemerald) by pret. See [CREDITS.md](CREDITS.md).

_Pokémon World is a free, non-commercial fan project. It is not affiliated with, endorsed by, or sponsored by Nintendo, Game Freak, or The Pokémon Company. No ROMs are distributed. You build the game from source using a legally obtained base ROM. It is not for sale or commercial use._

_All Pokémon names, characters, and related assets are the property of their respective owners. I claim no ownership or credit for any original work this project is based on. This project is provided as-is, with no warranty, and is used at your own risk._
