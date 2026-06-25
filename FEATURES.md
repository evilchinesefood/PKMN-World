# What features are included?

**Pokémon World** is a private GBA ROM-hack built on
[pokeemerald-expansion](https://github.com/rh-hideout/pokeemerald-expansion)
(upstream commit `66ab6696`, ~v1.16.2). It inherits the full pokeemerald-expansion
feature set and adds a set of its own ported features on top.

Every feature added in Pokémon World ships **behind a default-OFF config flag**, so
a fresh build behaves like stock pokeemerald-expansion until each flag is opted in.
This document separates **inherited** features (from the base engine) from those
**added in Pokémon World**, and lists the tools and systems the project is built on.

For credits and source attribution, see [CREDITS.md](CREDITS.md). For setup and build
instructions, see [INSTALL.md](INSTALL.md).

## Table of Contents
- [What features are included?](#what-features-are-included)
  - [Table of Contents](#table-of-contents)
  - [Added in Pokémon World](#added-in-pokémon-world)
    - [SwSh UI suite](#swsh-ui-suite)
    - [comfy\_anim shared animation library](#comfy_anim-shared-animation-library)
    - [ORAS key-item registration wheel](#oras-key-item-registration-wheel)
    - [Pokevial — refillable party-heal key item](#pokevial--refillable-party-heal-key-item)
    - [QOL HM / field-move item gate](#qol-hm--field-move-item-gate)
    - [Quests system](#quests-system)
  - [Tools, libraries \& systems](#tools-libraries--systems)
  - [Planned / roadmap](#planned--roadmap)
  - [Inherited from pokeemerald-expansion](#inherited-from-pokeemerald-expansion)
    - [Configuration files](#configuration-files)
    - [Upgraded Battle Engine](#upgraded-battle-engine)
    - [Full Trainer customization](#full-trainer-customization)
    - [Pokémon data](#pokémon-data)
    - [Interface improvements](#interface-improvements)
    - [Engine improvements](#engine-improvements)
    - [Overworld improvements](#overworld-improvements)
    - [Developer tools](#developer-tools)

## Added in Pokémon World

These features were ported into this repo on top of pokeemerald-expansion. **All are
gated behind default-OFF config flags** (opt-in) — a clean build is byte-for-byte the
base engine until a flag is set to `TRUE`. Flag definitions live in
`include/config/` (and a couple of the larger UIs in `include/`); the exact flag names
are given below.

### SwSh UI suite

A Sword/Shield-styled interface suite, ported from
[montmoguri/pokeemerald-expansion](https://github.com/montmoguri). Each screen is an
independent toggle, so they can be enabled one at a time.

| Feature | Master flag | Header |
|---|---|---|
| Sword/Shield party menu | `SWSH_PARTY_MENU` | `include/config/swsh_party_menu.h` |
| SwSh summary screen | `SWSH_SUMMARY_SCREEN` | `include/swsh_summary_screen.h` |
| SwSh storage system (PC boxes) | `SWSH_STORAGE_SYSTEM` | `include/swsh_storage_system.h` |
| SwSh bag / item menu | `SWSH_ITEM_MENU` | `include/config/swsh_item_menu.h` |
| SwSh message / name box | `SWSH_MESSAGE_BOX` | `include/config/name_box.h` |
| SwSh map-name pop-up | `OW_POPUP_GENERATION == GEN_8` | `include/config/overworld.h` |

Notes:
- **Party menu** (`SWSH_PARTY_MENU`) — SwSh-style party screen with idle mon animations
  (`SWSH_PARTY_MON_IDLE_ANIMS`) and an optional PC-access toggle
  (`SWSH_PARTY_MENU_PC_ACCESS`).
- **Summary screen** (`SWSH_SUMMARY_SCREEN`) — reworked summary with nature-colored
  stats, category/split icons, IV/EV display, friendship heart, Gen 8 status/type icons,
  contest pages, optional Dynamax/Gigantamax/Tera-type readouts, scrolling background,
  mon shadows, and idle animations. Renaming and the move relearner reuse the base
  `P_SUMMARY_SCREEN_*` configs.
- **Storage system** (`SWSH_STORAGE_SYSTEM`) — SwSh-styled PC boxes with an optional
  box-selection grid (auto-disabled above 15 boxes) and a scrolling background.
- **Bag / item menu** (`SWSH_ITEM_MENU`) — SwSh bag with in-bag item actions (use/give
  without opening the party menu), an in-battle in-bag path, an HP bar in the party slot
  during item use, TM/HM contest info, and berry info.
- **Message / name box** (`SWSH_MESSAGE_BOX`) — SwSh message and name box; when `TRUE`,
  approaching NPC trainers can auto-show a name box (`OW_NAME_BOX_NPC_TRAINER`). When
  `FALSE` the build is byte-identical vanilla in both code and graphics.
- **Map-name pop-up** — the **`GEN_8` arm of `OW_POPUP_GENERATION`** (default `GEN_3`).
  Setting `OW_POPUP_GENERATION` to `GEN_8` selects the SwSh location pop-up instead of
  the Gen 3 / Gen 5 styles.

### comfy\_anim shared animation library

A small shared animation library (`src/comfy_anim.c` / `include/comfy_anim.h`) providing
easing- and spring-based animations on Q\_24\_8 fixed-point values. It backs the idle and
transition animations used across the SwSh UI suite.

### ORAS key-item registration wheel

An ORAS-style **SELECT registration wheel** for key items, behind `I_KEY_ITEM_WHEEL`
(`include/config/item.h`). When enabled, up to `I_MAX_REGISTERED_ITEMS` (default 4) key
items can be registered to SELECT — one per D-Pad direction. Slot 1 reuses the vanilla
`registeredItem`; the rest are stored in a new `registeredItemsExtra[]` field on
SaveBlock1 (so enabling the flag grows the save schema).

### Pokevial — refillable party-heal key item

A refillable key item that heals the whole party, behind `POKEVIAL_FEATURE`
(`include/config/pokevial.h`). Holds a configurable number of doses
(`POKEVIAL_MAX_SIZE`, default 15; `POKEVIAL_MIN_SIZE`, default 1) and adds a small field
to SaveBlock3. The `POKEVIAL_SKIP_CUTSCENE` sub-toggle heals the party instantly instead
of opening the party screen. The Pokevial's party-menu callbacks are wired into the SwSh
party menu so `POKEVIAL_FEATURE` and `SWSH_PARTY_MENU` can be enabled together.

### QOL HM / field-move item gate

A quality-of-life field-move gate behind `QOL_FIELD_MOVES_ITEM_GATE`
(`include/config/qol_field_moves.h`). When enabled, owning the corresponding tool item in
the bag (`ITEM_CUT_TOOL` … `ITEM_DIVE_TOOL`) unlocks that field move, bypassing the
badge/Pokémon requirement. Two further toggles (`QOL_FIELD_MOVES_AUTO_INTERACT`,
`QOL_FIELD_MOVES_NO_MESSAGING`) are defined as stubs and are **not** implemented in this
port.

### Quests system

A quest / mission-log system, ported with the quest menu deriving from FireRed quest-menu
code (quests-feature lineage from
[PokemonSanFran/pokeemerald](https://github.com/PokemonSanFran)). Configured in
`include/config/quests.h`:

- **`QUEST_MENU`** — adds a Quest menu (mission log) to the Start menu and enables the
  quest scripting commands. Enabling this grows SaveBlock3 (schema-critical).
- **`QUEST_MENU_ALLOW_FAVORITES`** — lets favorited quests be pinned to the top of the
  list.
- **`QUEST_MENU_SHOW_PERCENTAGE`** — shows completion percentage in the menu header.
- **`OW_QUEST_BRANCHING`** — complex per-quest branching: a quest's
  description/location/icon can vary by a game VAR. Reads ordinary game VARs, so it does
  **not** grow SaveBlock3. `OW_QUEST_MAX_STATES` (default 50 when branching is on, forced
  to 1 when off) caps the number of branch states per quest.

Implementation spans the quest menu UI, quest script commands (`scrcmd`), the Start-menu
hook, and the SaveBlock3 quest schema.

## Tools, libraries & systems

Pokémon World is a decomp-style project: the ROM is reassembled from C, assembly, JSON
data, and raw assets, following pokeemerald / pokeemerald-expansion conventions.

**Toolchain (modern only):**
- `arm-none-eabi-gcc` (Arm bare-metal C compiler) + `arm-none-eabi` binutils
  (`as`, `ld`, `objcopy`, `objdump`).
- **newlib** for `arm-none-eabi` — provides `libc.a` / `libnosys.a`.
- **agbcc is not used.** The build forces `-DMODERN=1` (`make agbcc` is deprecated).
- `libpng` (development headers) for the graphics tools, and `python3` for build scripts
  and preprocessing.

**In-repo build tools** (`tools/`, compiled automatically by the Makefile): `preproc`,
`gbagfx`, `gbafix`, `mapjson`, `jsonproc`, `trainerproc`, `mid2agb`, `wav2agb`, `rsfont`,
`scaninc`, `ramscrgen`, `bin2c`, `learnset_helpers`, `compresSmol`, `find_func`, and the
test runners `mgba` / `mgba-rom-test-hydra`, among others.

**Testing:** the battle-engine **test framework** in `test/` runs via `make check`
(sets `TEST=1`), executed through the bundled `mgba-rom-test` / `mgba-rom-test-hydra`
runners. A `make release` target builds with `NDEBUG` + LTO.

**Asset / map / script editing** (external, standard for this engine family):
- [Porymap](https://github.com/huderlem/porymap) — map editing.
- [Poryscript](https://github.com/huderlem/poryscript) — higher-level event scripting.
- [Tilemap Studio](https://github.com/Rangi42/tilemap-studio) — tilemap editing.
- [Porytiles](https://github.com/grunt-lucas/porytiles) — tileset compilation.

**Libraries / systems used in this repo:** the `comfy_anim` animation library (above), and
the [all-contributors](https://allcontributors.org/) spec for the credits table in
[CREDITS.md](CREDITS.md).

## Planned / roadmap

> **Not yet implemented.** Listed here for direction only — none of this is in the repo today.

- **Region merge — Hoenn + Kanto + Johto on one ROM.** Combine native Hoenn, the bundled
  FireRed/LeafGreen Kanto maps (currently present but inert / only reachable via a
  compile-time `IS_FRLG=1` switch), and Johto ported from
  [PokemonHnS-Development/pokemonHnS](https://github.com/PokemonHnS-Development/pokemonHnS).
  FireRed story reference: `evilchinesefood/FireRedDavesVersion`. The binding constraint is
  IWRAM (~2.2 KB free), then ROM headroom (~6.7 MB after tileset deduplication); region
  transitions would be scripted warps (ferry/train), not live map connections. See
  [docs/RegionMergePlan.md](docs/RegionMergePlan.md).

## Inherited from pokeemerald-expansion

Everything below comes from the **base engine**
([pokeemerald-expansion](https://github.com/rh-hideout/pokeemerald-expansion), itself built
on [pret/pokeemerald](https://github.com/pret/pokeemerald)). Pokémon World inherits these
as-is; many can be toggled in the configuration files.

### Configuration files
A lot of features listed below can be turned off as desired. Check which ones in these files. These headers live in this repo under `include/config/` (the links point to the upstream versions for reference):
- [AI config](https://github.com/rh-hideout/pokeemerald-expansion/blob/master/include/config/ai.h)
- [Battle config](https://github.com/rh-hideout/pokeemerald-expansion/blob/master/include/config/battle.h)
- [Caps config](https://github.com/rh-hideout/pokeemerald-expansion/blob/master/include/config/caps.h)
- [Debug config](https://github.com/rh-hideout/pokeemerald-expansion/blob/master/include/config/debug.h)
- [DexNav config](https://github.com/rh-hideout/pokeemerald-expansion/blob/master/include/config/dexnav.h)
- [General config](https://github.com/rh-hideout/pokeemerald-expansion/blob/master/include/config/general.h)
- [HGSS Pokédex config](https://github.com/rh-hideout/pokeemerald-expansion/blob/master/include/config/pokedex_plus_hgss.h)
- [Item config](https://github.com/rh-hideout/pokeemerald-expansion/blob/master/include/config/item.h)
- [NPC Follower config](https://github.com/rh-hideout/pokeemerald-expansion/blob/master/include/config/follower_npc.h)
- [Overworld config](https://github.com/rh-hideout/pokeemerald-expansion/blob/master/include/config/overworld.h)
- [Pokémon config](https://github.com/rh-hideout/pokeemerald-expansion/blob/master/include/config/pokemon.h)
- [Save config](https://github.com/rh-hideout/pokeemerald-expansion/blob/master/include/config/save.h)
- [Species enabled](https://github.com/rh-hideout/pokeemerald-expansion/blob/master/include/config/species_enabled.h)
- [Summary screen config](https://github.com/rh-hideout/pokeemerald-expansion/blob/master/include/config/summary_screen.h)

### Upgraded Battle Engine
- ***Battle gimmicks:*** Mega Evolution, Primal Reversion, Ultra Burst, Z-Moves, Dynamax, Gigantamax and Terastallization.
- ***Newer game battle types:*** Double Wild Battles, custom Multi Battles, Inverse Battles, 1v2/2v1 battles, Sky Battles.
- ***Updated battle mechanics:*** Critical capture, Frostbite support, Poké Ball quick menu, Move description menu, no badge boosts, Gen 4 Fog, obedience, Affection, Party swap upon catch, move effectiveness in battle, FRLG/Gen4+ whiteout money calculation, Gen 4-style shadows.
- ***Updated move data***: Fairy/Stellar types, Physical/Special split, flags.
- ***Updated calculations:*** Damage, experience, mid-turn speed, end-battle stats and EVs, Level 100 EVs.
- ***Every item, ability and move effect up to Gen IX:*** Includes contest data up to SwSh ([source](https://pokemonurpg.com/info/contests/rse-move-list/)).
- ***Initial battle conditions:*** Stat stages, battle terrain, Wild AI flags.
- ***Faster battles:*** Simultaneous HP reduction, shortcut to "Run" option, faster battle intro, faster HP drain, faster AI calculations.
- ***Easier customization:*** Cleaner codebase to implement custom moves and effects.
- ***Improved AI:*** Faster and considers new effects added by Expansion.
- ***Popular features:*** Level/EV Caps, Sleep Clause, Type Indicators.

### Full Trainer customization
- ***Compatible with Pokémon Showdown's team syntax:*** Create your trainer teams in the [teambuilder](https://play.pokemonshowdown.com/teambuilder) and paste the results!
- ***Custom Pokémon data:*** Nicknames, EVs, IVs, Moves, Abilities, Poké Balls, Friendship, Nature, Gender, Shininess, Dynamax level, Gigantamax Factor and Tera Type.
  - ***"Ace Pokémon":*** Will save a specific Pokémon for last.
  - ***Trainer Pools:*** A trainer may get a pool of randomized Pokémon instead of set teams.
- ***Custom sliding trainer messages:*** First Turn, landing a super-effective hit, before Mega Evolution, etc.
- ***New AI Flag options:*** Customize the intelligence of your trainers.
- ***Trainer class Poké Balls:*** Divers use Dive Balls, Breeders use Nest Balls, etc.

### Pokémon data
- ***Improved Pokémon Data structure:*** Optimized space to allow fitting more information, such as Tera type, 12-character names, Hyper-trained stats, evolution conditions, saved HP/status effect.
- ***Updated breeding mechanics:*** Poké Ball/Egg Move/Ability/Nature inheritance, Level 1 eggs automatic incense babies.
- ***Updated species data:*** Stats, Types, Abilities, Hidden Abilities, Egg Groups, EV Yields, movesets, Battle Facility bans, guaranteed perfect IV counts, ORAS Dex numbers.
- ***Simpler species data manipulation:***: Only requires to edit ~5 files instead of vanilla pokeemerald's 20+ to add a new Pokémon.
- ***Updated sprites:*** DS-style sprites with support for Emerald's 2-frame animations and gender difference.
- ***Species toggles:*** You can disable specific groups of Pokémon to save space, including families, cross-gen evolutions, Mega Evolutions, Regional forms, etc.
- ***Revamped Evolution System***: Multiple Evolution conditions can be stacked in order to create complex methods without additional coding. Every condition except Affection and console gyroscope is supported.
- ***Form Change System.*** Most form changes can be added without additional coding. This includes support for: Holding/using an item, HP thresholds being met, weather change in and/or out of battle, Fusions, and more.

### Interface improvements
- ***Pokémon Summary:*** Move relearner, EV/IV checks, Nature colors ([feature branch](https://github.com/DizzyEggg/pokeemerald/tree/nature_color) by @DizzyEggg).
- ***Party Menu:*** "Move Item" option.
- ***Pokémon Storage System:*** Move option as default, access from Box Link item.
- ***HGSS-style Pokédex*** ([original feature branch](https://github.com/TheXaman/pokeemerald/tree/tx_pokedexPlus_hgss) by @TheXaman): Detailed in-game information accessible to players.

### Engine improvements
- ***All base pokeemerald bugfixes implemented by default:*** Anything under the `BUGFIX` define.
- ***Improved sprite and palette compression:*** Assets use less space than vanilla compression.
- ***Modern compiler support:*** Detect potential errors in your code more easily.
- ***Dynamic Multichoice*** ([original branch](https://github.com/SBird1337/pokeemerald/tree/feature/dynmulti) by @SBird1337): Easier way to add multiple-choice menus for scripting.
- ***High-Quality RNG:*** No more broken vanilla RNG.

### Overworld improvements
- ***Modern Mechanics***: Defog field move, B2W2+ Repel system, Running indoors, Removed field poison, Chain fishing, VS. Seeker, FRLG+ whiteout message.
- ***Overworld and Follower Pokémon*** ([feature branch](https://github.com/aarant/pokeemerald/tree/followers-expanded-id) by @aarant)
    - *Includes Dynamic overworld palettes (DOWP) and Overworld Expansion for event IDs beyond 255.*
    - *Includes Pokémon sprites up to Generation IX.*
- ***Day/Night System:*** ([feature branch](https://github.com/aarant/pokeemerald/tree/lighting-expanded-id) by @aarant)
    - *Includes support for non-real time clock*.
- ***NPC Followers***: ([feature branch](https://github.com/ghoulslash/pokeemerald/tree/follow_me) by @ghoulslash)
- ***BW Map Pop-ups*** ([feature branch](https://github.com/ravepossum/pokeemerald/tree/bsbob_map_popups) by @BSBob)
- ***XY Berry Mechanics:*** Mutations, moisture, weeds, pests.
- ***Obtained Item descriptions*** (feature branch by @ghoulslash).

### Developer tools
- ***Integrated Testing:*** Pinpoint if your custom mechanics have broken something else in the game or not.
- ***Pokémon Sprite Visualizer:*** Test every Pokémon sprite and animation.
- ***Overworld debug menu** ([original feature branch](https://github.com/TheXaman/pokeemerald/tree/tx_debug_system) by @TheXaman)*: Support menu with an assortment of features to facilitate debugging, including warping, flag and var toggling, Pokémon and item generation and more.
- ***Battle Debug Menu:*** Modify data on the fly in the middle of a battle.
- ***Learnset Helper:*** Autogenerate movesets from your custom TM and Tutor data based on official compatibility data.
- ***Configurable script flags:*** Disabling Wild encounters, Disabling Trainer battles, Forcing/Disabling Shinies.
- ***Saveblock Cleansing*** ([feature branch](https://github.com/ghoulslash/pokeemerald/tree/saveblock) by @ghoulslash)
