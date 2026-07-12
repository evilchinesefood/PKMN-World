# What features are included?

**Pokémon World** merges **Kanto**, **Johto**, and **Hoenn** into a single GBA game, built on
[pokeemerald-expansion](https://github.com/rh-hideout/pokeemerald-expansion)
(upstream commit `66ab6696`, ~v1.16.2). It inherits the full pokeemerald-expansion
feature set, adds the three-region merge on top, and ships a suite of ported
community features — **all enabled by default** in the built game. The config flags
still exist in `include/config/` for tuning, but a bare `make` produces the full
three-region, all-features game.

This document covers the **region merge**, the features **added in Pokémon World**,
and the features **inherited** from the base engine.

For credits and source attribution, see [CREDITS.md](CREDITS.md). For setup and build
instructions, see [INSTALL.md](INSTALL.md).

## Table of Contents
- [What features are included?](#what-features-are-included)
  - [Table of Contents](#table-of-contents)
  - [Three regions, one game](#three-regions-one-game)
    - [The regions](#the-regions)
    - [World Transit hub](#world-transit-hub)
    - [Region switching](#region-switching)
    - [Shared vs. per-region progress](#shared-vs-per-region-progress)
    - [World Championship](#world-championship)
  - [Character customization](#character-customization)
  - [Ported features](#ported-features)
    - [SwSh UI suite](#swsh-ui-suite)
    - [comfy\_anim shared animation library](#comfy_anim-shared-animation-library)
    - [Unbound-style graphical start menu](#unbound-style-graphical-start-menu)
    - [HGSS follower Pokémon](#hgss-follower-pokémon)
    - [Sky Charm overworld flight](#sky-charm-overworld-flight)
    - [ORAS key-item registration wheel](#oras-key-item-registration-wheel)
    - [Pokevial — refillable party-heal key item](#pokevial--refillable-party-heal-key-item)
    - [QOL HM / field-move item gate](#qol-hm--field-move-item-gate)
    - [Quests system](#quests-system)
  - [QoL \& gameplay defaults](#qol--gameplay-defaults)
  - [Developer additions](#developer-additions)
  - [Tools, libraries \& systems](#tools-libraries--systems)
  - [Roadmap](#roadmap)
  - [Inherited from pokeemerald-expansion](#inherited-from-pokeemerald-expansion)
    - [Configuration files](#configuration-files)
    - [Upgraded Battle Engine](#upgraded-battle-engine)
    - [Full Trainer customization](#full-trainer-customization)
    - [Pokémon data](#pokémon-data)
    - [Interface improvements](#interface-improvements)
    - [Engine improvements](#engine-improvements)
    - [Overworld improvements](#overworld-improvements)
    - [Developer tools](#developer-tools)

## Three regions, one game

The headline feature: three complete, self-contained campaigns on one cartridge.
Each region has its own story, 8 gyms and badges, Elite Four, Champion, and Hall of
Fame — and you choose the order.

### The regions

- **Kanto** — the bundled FireRed campaign, wired live: all `IS_FRLG` compile-time
  switches migrated to runtime region checks, every FRLG trainer fights its **real
  FRLG party** (own trainer-ID block and defeat-flag bank), real gym leader / Elite
  Four / **Champion Blue** rosters, rival **Blue**, and an 8-badge Victory Road /
  league gate.
- **Johto** — ported from *Pokémon Heart & Soul* (pokemonHnS): ~245 maps with
  tilesets and scripts, 231 real trainer parties, wild-encounter tables, the Johto
  town map with Fly and heal locations, rival **Silver** (with daily rematches), and
  the Johto League (Will / Koga / Bruno / Karen → **Champion Lance**). Post-game:
  **Red at Mt. Silver** (rematchable), the Burned Tower **roaming beasts**, the
  **Celebi** GS Ball chain, the **Ruins of Alph** sliding puzzles, the National Park
  **Bug-Catching Contest**, and the Ho-Oh / Lugia events.
- **Hoenn** — the native Emerald campaign, plus the **Battle Frontier** as the
  shared post-game battle facility (reachable from the hub, gated behind
  clearing at least one region's league). Once you're Champion, the Elite
  Four/Champion **rematch** fields upgraded HARD-difficulty teams (Lv 62–68,
  competitive movesets) — your first clear still faces the normal gauntlet.
- **Gym leader rematches** — all **24 gym leaders** across the three regions offer
  unlimited rematches once you're **that region's** Champion, each with a new
  HARD team (Lv 58–65, held items, competitive movesets). Difficulty is contained
  per region: being Hoenn Champion doesn't harden Kanto's first-run gyms.

### World Transit hub

New games start with a unified Oak intro (gender, name, and **outfit picker**), then
land in the **World Transit hub** — an Indigo-Plateau-style terminal with four
staffed departure gates (Kanto, Johto, Hoenn, Battle Frontier), a nurse and heal
point, a storage PC, a front-desk mart plus six department vendors, and a
**world-tour board** tracking all 24 badges.

Three hub staffers handle handouts: the **Harbor Master** opens the event ferries
and hands out the event tickets (Eon Ticket, Old Sea Map, Mystic Ticket) as you win
championships, the **Charm Curator** hands out the charms at badge milestones —
plus a **PokéVial** as a welcome gift — and a post-game **Dex researcher** gives
escalating one-time rewards for caught-species count: 150 → PP Max, 300 → Master
Ball, and completing the National Dex → 10 Rare Candies plus a diploma. The hub
mart also stocks a free **Town Map**.

### Region switching

- **First visit** to a region plays a short "Mom moves into a new house" arrival,
  then the region's own canonical opening — including a **choice of that region's
  three starters** (Bulbasaur/Charmander/Squirtle, Chikorita/Cyndaquil/Totodile,
  Treecko/Torchic/Mudkip).
- **Switching regions** boxes your current party to the shared PC (mail is moved to
  the PC mailbox — nothing is lost) so each campaign starts fresh; withdraw anything
  from any region at any time.
- **Getting back to the hub** requires reaching the region's own access point in
  normal play: the **Goldenrod Magnet Train** (the Pass comes from the station
  president after the Radio Tower incident), the **Vermilion harbor**, or the
  **Slateport harbor**. Once you're a **champion of two regions**, every Pokémon
  Center (2F in Hoenn/Kanto, lobby in Johto) gains a World Transit warp pad.
- The active region and hub access are stored in the save; a versioned save format
  (`SAVE_FORMAT_VERSION 3`) with a migration reader keeps older dev saves loading.

### Shared vs. per-region progress

- **Shared/global:** money, bag, TMs/HMs, PC boxes, and a single **National
  Pokédex**. Key items **deduplicate across regions** — you never receive a second
  Exp. Share or HM you already own.
- **Per-region:** story flags and vars (dedicated banks per region), **badges**
  (each region has its own badge bank), and trainer-defeat flags. Obedience and HM
  field moves are gated by the **current** region's badges — a boxed Kanto team
  obeys according to your Johto badges while you're in Johto.
- The **Trainer Card is multi-page**: UP/DOWN (or L/R) flips between Hoenn,
  Kanto, and Johto badge pages.

### World Championship

Once you're Champion of **all three regions**, a registrar in the Battle Dome
lobby offers the **World Championship**: a 15-trainer Battle Dome bracket built
from cross-region champions — **Red, Blue, Lance, Steven, Wallace**, eight
**Elite Four** members from across the regions, and **Sabrina**/**Clair** —
with **Red** waiting in the final. Winning grants a permanent title and a
one-time **Gold Bottle Cap**, and the tournament is rematchable afterward.

## Character customization

You play as **Brendan or May** in every region. A **six-outfit palette-swap**
system (ported from the project lead's FireRed hack and regenerated per-gender for
the Brendan/May sprites) is chosen in the new-game intro — with a live preview on
the trainer sprite — and applies globally: overworld, battle back-sprite, and
trainer card.

## Ported features

These were ported into this repo from other community bases (sources and authors in
[CREDITS.md](CREDITS.md)). All are **enabled** in the shipped game; each remains
individually toggleable via its config flag.

### SwSh UI suite

A Sword/Shield-styled interface suite. Each screen is an independent toggle.

| Feature | Flag | Header |
|---|---|---|
| Sword/Shield party menu | `SWSH_PARTY_MENU` | `include/config/swsh_party_menu.h` |
| SwSh summary screen | `SWSH_SUMMARY_SCREEN` | `include/swsh_summary_screen.h` |
| SwSh storage system (PC boxes) | `SWSH_STORAGE_SYSTEM` | `include/swsh_storage_system.h` |
| SwSh bag / item menu | `SWSH_ITEM_MENU` | `include/config/swsh_item_menu.h` |
| SwSh message / name box | `SWSH_MESSAGE_BOX` | `include/config/name_box.h` |
| SwSh map-name pop-up | `OW_POPUP_GENERATION == GEN_8` | `include/config/overworld.h` |

Notes:
- **Party menu** — SwSh-style party screen with idle mon animations and PC access,
  plus the follower **"Follow" chooser** (below).
- **Summary screen** — nature-colored stats, category/split icons, IV/EV display,
  friendship heart, Gen 8 status/type icons, contest pages, scrolling background,
  mon shadows, and idle animations.
- **Storage system** — SwSh-styled PC boxes with a box-selection grid and scrolling
  background; opening the boxes from the party menu returns you to the party menu.
- **Bag / item menu** — in-bag item actions (use/give without the party menu), an
  in-battle in-bag path, an HP bar in the party slot during item use, TM/HM contest
  info, and berry info.
- **Message / name box** — SwSh message and name box; approaching NPC trainers can
  auto-show a name box.

### comfy\_anim shared animation library

A small shared animation library (`src/comfy_anim.c` / `include/comfy_anim.h`)
providing easing- and spring-based animations on Q\_24\_8 fixed-point values. It
backs the idle and transition animations used across the SwSh UI suite.

### Unbound-style graphical start menu

An Unbound-inspired graphical Start menu (`PW_GRAPHICAL_START_MENU`,
`include/config/start_menu.h`): sprite-icon entries the player can rearrange,
day/night compatible, with a Quests entry. The classic list menu is kept as a
fallback.

### HGSS follower Pokémon

HGSS-style follower Pokémon (`OW_FOLLOWERS_ENABLED`), with a Pokémon World
addition: a **"Follow" chooser in the party menu**, so any party member — not just
the lead — can be your follower.

### Sky Charm overworld flight

A key item (`ITEM_SKY_CHARM`) that toggles **free overworld flight**. Both the Sky
Charm and HM Fly now mount your actual **flying-capable Pokémon** (falling back to
Flygon if none is available), animated mid-flight and rendered above trees and
walls instead of clipping beneath them. Given by a keeper NPC in the World Transit
hub once you've earned your first badge in any region; flying requires the
**current** region's Fly badge — the same badge that authorizes HM Fly (Kanto
Thunder, Johto Mineral, Hoenn Feather).

### ORAS key-item registration wheel

An ORAS-style **SELECT registration wheel** for key items (`I_KEY_ITEM_WHEEL`,
`include/config/item.h`): up to `I_MAX_REGISTERED_ITEMS` (default 4) key items
registered to SELECT — one per D-Pad direction.

### Pokevial — refillable party-heal key item

A refillable key item that heals the whole party (`POKEVIAL_FEATURE`,
`include/config/pokevial.h`). Holds a configurable number of doses
(`POKEVIAL_MAX_SIZE`, default 15); `POKEVIAL_SKIP_CUTSCENE` heals instantly instead
of opening the party screen. Fully integrated with the SwSh party menu. Given as a
welcome gift by the hub's Charm Curator.

### QOL HM / field-move item gate

A quality-of-life field-move gate (`QOL_FIELD_MOVES_ITEM_GATE`,
`include/config/qol_field_moves.h`): owning the corresponding tool item
(`ITEM_CUT_TOOL` … `ITEM_DIVE_TOOL`) unlocks that field move, bypassing the
badge/Pokémon requirement.

### Quests system

A quest / mission-log system configured in `include/config/quests.h`:

- **`QUEST_MENU`** — the Quest menu (mission log), reachable from the Start menu
  (with its own icon in the graphical start menu).
- **`QUEST_MENU_ALLOW_FAVORITES`** — pin favorited quests to the top of the list.
- **`QUEST_MENU_SHOW_PERCENTAGE`** — completion percentage in the menu header.
- **`OW_QUEST_BRANCHING`** — per-quest branching: a quest's description, location,
  and icon can vary by a game VAR (`OW_QUEST_MAX_STATES` caps states per quest).

## QoL & gameplay defaults

Config flips and gameplay features that shape how the shipped game plays:

- **Reusable TMs** (`I_REUSABLE_TMS`) and **chain fishing** (`I_FISHING_CHAIN`).
- **IV/EV pages** in the summary screen (`P_SUMMARY_SCREEN_IV_EV_INFO`) and
  **dynamic move types** shown in battle/summary (`P_SHOW_DYNAMIC_TYPES`).
- **Move relearners enabled**, including the TM-move relearner
  (`P_ENABLE_MOVE_RELEARNERS`, `P_TM_MOVES_RELEARNER`).
- **Type and effectiveness indicators always shown** in battle (`B_SHOW_TYPES`,
  `B_SHOW_EFFECTIVENESS`).
- **HGSS-style Pokédex enabled** (`POKEDEX_PLUS_HGSS`) — the detailed HGSS Pokédex
  interface. The main page is region-aware: it shows your campaign region's name
  with that region's SEEN/CAUGHT counts, plus a TOTAL of species caught across
  all regions.
- **DexNav** (`DEXNAV_ENABLED`) — granted with each region's Pokédex; the
  hidden-Pokémon detector unlocks with your first championship. **Hidden encounters
  are authored for every land map**, skewing rarer and slightly higher-level than
  the local grass (hidden Pokémon never carry held items).
- **Kanto VS Seeker rematches** (`I_VS_SEEKER_CHARGING`) — the VS Seeker offers
  rematches from **85 trainer groups** across Kanto, with teams that escalate as
  you earn badges. Hoenn keeps Match Call, and its rematch offers now survive
  moving between areas. (Seeker offers don't survive saving and quitting — recharge
  the Seeker after reloading.)
- **Dynamic surf mount** (`OW_SURF_USES_MON_SPRITE`) — you surf on your own
  Pokémon: the first party member that knows Surf appears as your mount.
- **Nicknames** — rename Pokémon straight from the party menu or the summary
  screen (`P_SUMMARY_SCREEN_RENAME`); outsider Pokémon follow the usual Name Rater
  rules. A **Nicknames** Options toggle can also skip the catch/hatch naming prompt
  (on by default).
- **Item descriptions shown on pickup** (`OW_SHOW_ITEM_DESCRIPTIONS`).
- **Visible overworld wild encounters** (`WE_OW_ENCOUNTERS`) **in addition to**
  vanilla random grass encounters (`WE_VANILLA_RANDOM`) — both fire on the same map
  by design.
- **Each region's starters are catchable** (~10% grass slots) on its first route —
  Route 1, Route 29, and Route 101 — so the two starters you didn't pick are
  obtainable.
- **Autosave** — an optional autosave (off by default) that quietly saves as you
  move between areas — at most once every 10 minutes; it skips while flying.
- **Hard Mode** — Set-style battles, no bag items against trainers, and badge-based
  level caps — plus an **EXP multiplier** (0.5×–2×) and a **catch-rate multiplier**
  (0.5×–2×), all in the Options menu.
- **Run shortcut** for fleeing wild battles, in the Options menu — Off / Cursor
  (B moves the cursor to Run) / Instant (flee immediately).
- **Auto-Run toggle** in the Options menu (which now scrolls to fit extra options).
- **SHARED EXP toggle** in the Options menu (`FLAG_QOL_SHARED_EXP`, wired through
  `I_EXP_SHARE_FLAG`) — party-wide Exp. Share; **off by default**, so only battle
  participants gain EXP until you switch it on.
- **Safari Zone continue** — pay ¥500 to keep going when the Safari clock runs
  out or you run out of Safari Balls.
- **Chansey attendants** beside the nurse in every Pokémon Center, in all regions.
- The **Wailmer Pail** is available at the Goldenrod flower shop, so Johto berry
  growing can't dead-end.
- **The wall clock is set once, globally** — no re-setting it in each region's
  bedroom.

## Developer additions

- The **overworld debug menu ships enabled** — the release build is the dev build
  by policy (warps, flag/var toggling, Pokémon/item generation, Fly-to-map, and
  more). Numeric debug inputs support hold-to-repeat.
- Compile-time invariants (`STATIC_ASSERT`s) guard the recurring save-layout and
  overflow bug classes introduced by the merge (trainer-ID ranges, flag-bank
  boundaries, `MapHeader` layout).

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

## Roadmap

The three campaigns are built and link-green; the new-game flow is playtested and
hardware-verified. What remains:

- **Full-campaign and inter-region-travel playtest** — the main remaining gate.
- HGSS gym-leader / Elite Four portrait art (currently remapped to the nearest
  existing portraits).

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
