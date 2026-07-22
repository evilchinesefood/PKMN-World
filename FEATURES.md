# What features are included?

**Pokémon World** merges **Kanto**, **Johto**, and **Hoenn** into a single GBA game, built on
[pokeemerald-expansion](https://github.com/rh-hideout/pokeemerald-expansion)
(upstream commit `66ab6696`, ~v1.16.2). It inherits the full expansion feature set, adds the
three-region merge on top, and ships a suite of ported community features — **all enabled by
default**: a bare `make` produces the full three-region game. The flags in `include/config/`
remain for tuning.

For credits and source attribution, see [CREDITS.md](CREDITS.md). For setup and build
instructions, see [INSTALL.md](INSTALL.md).

## Table of Contents
- [Three regions, one game](#three-regions-one-game)
  - [The regions](#the-regions)
  - [World Transit hub](#world-transit-hub)
  - [Region switching](#region-switching)
  - [Shared vs. per-region progress](#shared-vs-per-region-progress)
  - [Rematches \& Hard difficulty](#rematches--hard-difficulty)
  - [World Championship](#world-championship)
  - [Battle Net \& the Mega economy](#battle-net--the-mega-economy)
- [Character customization](#character-customization)
- [Riding your Pokémon](#riding-your-pokémon)
- [Ported features](#ported-features)
  - [SwSh UI suite](#swsh-ui-suite)
  - [Unbound-style graphical start menu](#unbound-style-graphical-start-menu)
  - [HGSS follower Pokémon](#hgss-follower-pokémon)
  - [ORAS key-item registration wheel](#oras-key-item-registration-wheel)
  - [Pokévial](#pokévial)
  - [Field-move QoL gates](#field-move-qol-gates)
  - [Quests system (dormant)](#quests-system-dormant)
- [QoL \& gameplay defaults](#qol--gameplay-defaults)
- [Developer additions](#developer-additions)
- [Tools, libraries \& systems](#tools-libraries--systems)
- [Roadmap](#roadmap)
- [Inherited from pokeemerald-expansion](#inherited-from-pokeemerald-expansion)

## Three regions, one game

Three complete, self-contained campaigns on one cartridge. Each region has its own story,
8 gyms and badges, Elite Four, Champion, and Hall of Fame — and you choose the order.

### The regions

- **Kanto** — the FireRed campaign, wired live: every FRLG trainer fights its **real FRLG
  party**, with real gym leader / Elite Four rosters, rival **Gary** (who is also the Kanto
  **Champion**), and an 8-badge Victory Road / league gate.
- **Johto** — ported from *Pokémon Heart & Soul*: ~235 maps with tilesets and scripts,
  231 real trainer parties, wild-encounter tables, the Johto town map with Fly and heal
  locations, rival **Gary** (with daily rematches), and the Johto League
  (Will / Koga / Bruno / Karen → **Champion Lance**) — with native HGSS-style
  portrait art for all eight gym leaders, the Elite Four, and Lance.
  Post-game: **Red at Mt. Silver**
  (rematchable), the roaming beasts, the **Celebi** GS Ball chain, the **Ruins of Alph**
  puzzles, the National Park **Bug-Catching Contest**, and the Ho-Oh / Lugia events.
- **Hoenn** — the native Emerald campaign, plus the **Battle Frontier** as the shared
  post-game battle facility (reachable from the hub, gated behind clearing at least one
  region's league).

**The roster is Generations 1–3 only.** Every Pokémon in the game — wild, gift, and
trainer-owned — comes from the first three generations, keeping the cast consistent with
the three regions it draws from.

### World Transit hub

New games start with a unified Oak intro (gender, name, **outfit picker**, and a one-time
**Hard Mode** choice), then land in the **World Transit hub** — an Indigo-Plateau-style
terminal with four staffed departure gates (Kanto, Johto, Hoenn, Battle Frontier), a nurse
and heal point, a storage PC, a front-desk general mart (every ball, top-tier heals, and a
free **Town Map**), specialist **TM, training, and battle-item vendors**, and a
**World Tour board** tracking all 24 badges.

Three hub staffers handle handouts:

- The **Harbor Master** opens the event ferries and hands out the event tickets
  (Eon Ticket, Old Sea Map, Mystic Ticket) as you win championships.
- The **Charm Curator** greets you with a **Pokévial** and a **Hub Pass** (a key item that
  warps you one-way back to the hub from the bag anywhere — see *Region switching* below),
  then rewards World Tour badge
  milestones: 4 → Catching Charm, 8 → Exp. Charm, 12 → Oval Charm, 16 → Shiny Charm,
  24 → **EV/IV Changer** (a reusable key item for freely tuning a party
  Pokémon's EVs and IVs; press R in its menu to flip pages. EVs stay capped
  at the legal 252 per stat / 510 total, IVs at 0-31).
- A post-game **Dex researcher** rewards caught-species milestones: 150 → PP Max,
  300 → Master Ball, and completing the National Dex → 10 Rare Candies plus a diploma.

### Region switching

- **First visit** to a region plays a short "Mom moves into a new house" arrival, then the
  region's own canonical opening — including a **choice of that region's three starters**.
- **Switching regions** boxes your current party to the shared PC (mail is moved to the PC
  mailbox — nothing is lost) so each campaign starts fresh; withdraw anything from any
  region at any time.
- **Getting back to the hub**: the **Hub Pass** key item (handed out by the hub's Charm
  Curator on your first visit) warps you straight there from the bag at any time — it's a
  one-way trip, so you re-enter regions through the hub's departure gates. You can also reach
  a region's own access point in normal play: the **Goldenrod Magnet Train** (the Pass comes
  from the station president after the Radio Tower incident), the **Vermilion harbor**, or the
  **Slateport harbor**. Once you're a **champion of two regions**, every Pokémon Center
  (2F in Hoenn/Kanto, lobby in Johto) gains a World Transit warp pad.
- The active region and hub access live in a versioned save format with a migration reader,
  so older saves keep loading across updates.

### Shared vs. per-region progress

- **Shared/global:** money, bag, TMs/HMs, PC boxes, and a single **National Pokédex**.
  Key items **deduplicate across regions** — you never receive a second Exp. Share or an
  HM you already own.
- **Per-region:** story flags, **badges** (each region has its own badge bank), and
  trainer-defeat flags. Obedience and HM field moves are gated by the **current** region's
  badges — a boxed Kanto team obeys according to your Johto badges while you're in Johto.
- The **Trainer Card is multi-page**: flip between Hoenn, Kanto, and Johto badge pages.

### Rematches & Hard difficulty

- **All 24 gym leaders** offer unlimited rematches once you're **that region's** Champion,
  each with a new HARD team (Lv 58–65, held items, competitive movesets). Difficulty is
  contained per region: being Hoenn Champion doesn't harden Kanto's first-run gyms.
- Once you're a region's Champion, that region's **Elite Four/Champion rematch** fields
  upgraded HARD-difficulty teams — your first clear still faces the normal gauntlet.
  Hoenn re-runs the gauntlet at Lv 62–68; Johto's league rematch climbs Lv 70–78 with
  Lance's Dragonite at 78; Kanto's round-two Elite Four runs Lv 70–76 and the Champion
  rematch peaks at Lv 77–80.
- **Hard Mode** (chosen once at new game, locked for that save): Set-style battles, no bag
  items against trainers, and badge-based level caps.

### Team Rocket ambushes

**Jessie & James** stalk you across all three regions: five one-time duo encounters at
**Mt. Moon**, the **Rocket Hideout**, the **Slowpoke Well**, the **Goldenrod Radio Tower**,
and **Route 118**. Each is a deliberately "unfair" **1-vs-2 double** — you face both Rockets
alone — capped off with their trademark blast-off exit. Team Rocket also takes a seat in the
World Championship bracket below.

### World Championship

Once you're Champion of **all three regions**, a registrar in the Battle Dome lobby offers
the **World Championship**: a 15-trainer Battle Dome bracket of cross-region champions —
**Red, Blue, Lance, Steven, Wallace**, eight **Elite Four** members, and
**Sabrina**/**Team Rocket** — with **Red** waiting in the final. Winning grants a permanent title
and a one-time **Gold Bottle Cap**, and the tournament is rematchable afterward.

### Battle Net & the Mega economy

Become any region's Champion and the **Battle Net terminal** in the hub unlocks its
flagship floor upstairs (RegionHub 2F) — the home of **Mega Evolution**:

- The **Director** hands you the **Mega Ring** plus a free Mega Stone for your starter's
  line (one-time; if your bag is full, both wait for you).
- Every **HARD gym-leader, Elite Four, and Champion rematch win pays Shards** (leaders 1,
  league 2). The **first HARD win** against each of the 28 stone-holding leaders also drops
  their **signature Mega Stone** — the same stone they Mega Evolve with against you. A full
  bag holds a stone for reclaim on a later win; a blocked Shard payout tells you and is
  forfeited, so make room first.
- The flagship **vendor** sells the remaining stones for Shards, and the **exchange clerk**
  converts Battle Points to Shards (4 BP each). A handful of Shards are also hidden in the
  world for the Itemfinder.
- The **sim terminal** runs simulated battles — your Pokémon **keep the full EXP** (and
  evolve as usual), while no money changes hands, a loss never whites you out, and your
  party is restored around every match, which makes the sims the game's training grounds.
  The **Scaling Type Trainer**
  fields 2–4 Pokémon of any type you pick, a few levels below your party, for **1 BP** a
  win plus a 30% bonus Shard. The **Leader Sim** replays any gym leader's **HARD** rematch
  as a simulation for **2 BP** — BP only, since Shards and stone drops stay on the real
  gym visits — and each region's leaders unlock with that region's championship.
- The **streak attendant** runs the flagship-exclusive modes: **Tower Streak** — up to 7
  sims in a row against random types, **1 BP per win, +5 BP for a perfect run**, with your
  best run on the records board — and three **ruleset rooms**, **Lv50**, **Monotype**, and
  **Little Cup** (Lv5, unevolved, still able to evolve), each a three-mon sim paying
  **2 BP** a win to a party that matches the rule.
- Every regional **Pokémon Center** link floor — Hoenn and Kanto's Center 2Fs, Johto's
  single-floor Centers, 49 rooms in all — hosts a **Battle Net terminal** carrying the
  Scaling Type Trainer and Leader Sim, so the sim economy travels with you.

## Character customization

You play as **Brendan or May** in every region. A **six-outfit palette-swap** system is
chosen in the new-game intro — with a live preview on the trainer sprite — and applies
globally: overworld, battle back-sprite, and trainer card.

## Riding your Pokémon

Surf and flight both put you on your **own team**, with a proper riding model — the mount's
lower body draws in front of you, so you sit *in* the saddle rather than perched on top,
with a single soft ground shadow.

- **Mount selection** (both moves): your **walking follower rides first** if it can use the
  move (knows it, or could learn it); otherwise the first capable party member by party
  order. The pick stays stable across warps, dives, and saving.
- **Surf** (`OW_SURF_USES_MON_SPRITE`) — your Pokémon's real overworld sprite carries you,
  with a shadow on the water.
- **Flight** — the **Sky Charm** key item toggles free overworld flight; HM Fly mounts the
  same way (Flygon stands in if nothing capable is on the team). The hub's **Charm Curator**
  hands it over once you hold **HM Fly** and a Fly badge from any region; flying in a region
  requires **that region's** Fly badge (Kanto Thunder, Johto Mineral, Hoenn Feather).

## Ported features

Ported from other community bases (sources and authors in [CREDITS.md](CREDITS.md)). All
are **enabled** in the shipped game; each remains individually toggleable via its config flag.

### SwSh UI suite

A Sword/Shield-styled interface suite; each screen is an independent toggle.

| Feature | What it adds | Flag |
|---|---|---|
| Party menu | SwSh party screen, idle animations, PC access, the follower **"Follow" chooser** | `SWSH_PARTY_MENU` |
| Summary screen | Nature-colored stats, IV/EV pages, category icons, status/type icons, idle animations | `SWSH_SUMMARY_SCREEN` |
| Storage system | SwSh-styled PC boxes with a box-selection grid | `SWSH_STORAGE_SYSTEM` |
| Bag / item menu | In-bag item actions, in-battle bag path, TM/berry info | `SWSH_ITEM_MENU` |
| Message / name box | SwSh message + name box; NPC trainers can auto-show a name box | `SWSH_MESSAGE_BOX` |
| Map-name pop-up | Gen-8-style map pop-ups | `OW_POPUP_GENERATION == GEN_8` |

### Unbound-style graphical start menu

Sprite-icon Start menu entries the player can rearrange, day/night compatible
(`PW_GRAPHICAL_START_MENU`). The classic list menu is kept as a fallback.

### HGSS follower Pokémon

HGSS-style follower Pokémon (`OW_FOLLOWERS_ENABLED`), plus a Pokémon World addition:
a **"Follow" chooser in the party menu**, so any party member — not just the lead — can be
your follower.

### ORAS key-item registration wheel

An ORAS-style **SELECT registration wheel** (`I_KEY_ITEM_WHEEL`): up to 4 key items
registered to SELECT, one per D-Pad direction.

### Pokévial

A refillable key item that fully heals the party (`POKEVIAL_FEATURE`): **two doses** per
charge, refilled every time a Pokémon Center nurse heals you. Given as a welcome gift by
the hub's Charm Curator.

### Field-move QoL gates

Two ways to use field moves without HM chores (`include/config/qol_field_moves.h`):

- **No-teach** (`QOL_FIELD_MOVES_NO_TEACH`) — a party Pokémon that *could learn* an HM
  performs its field move without being taught it. Badge gates still apply.
- **Item gate** (`QOL_FIELD_MOVES_ITEM_GATE`) — owning the matching tool item
  (`ITEM_CUT_TOOL` … `ITEM_DIVE_TOOL`) unlocks that field move outright.

### Quests system (dormant)

An Unbound-style quest / mission-log engine (`QUEST_MENU`, `include/config/quests.h`) with
favorites pinning, completion percentage, and per-quest branching driven by game VARs. The
engine is compiled in but **deliberately dormant**: no quests are authored and the Start-menu
entry never unlocks, so it is unreachable in play.

## QoL & gameplay defaults

How the shipped game plays, grouped by what they touch.

**Battle & progression**

- **EXP multiplier** and **catch-rate multiplier** (0.5×–2× each) in the Options menu.
- **SHARED EXP** Options toggle — party-wide Exp. Share, **off by default**.
- **Run shortcut** for fleeing wild battles — Off / Cursor (B jumps to Run) / Instant.
- **Auto-Run** Options toggle.
- **Type and effectiveness indicators always shown** in battle.
- Move relearners enabled, including the **TM-move relearner**.

**Exploration**

- **DexNav** — granted with each region's Pokédex; the hidden-Pokémon detector unlocks with
  your first championship. **Hidden encounters are authored for every land map**, skewing
  rarer and slightly higher-level than the local grass.
- **Visible overworld encounters** *in addition to* vanilla random grass encounters — both
  fire on the same map by design.
- **Each region's starters are catchable** (~10% grass slots) on its first route — the two
  you didn't pick are obtainable.
- **Cut trees and smashed rocks stay gone** when you leave and re-enter a map.
- **Kanto VS Seeker** — rematches from **85 trainer groups**, with teams that escalate as
  you earn badges (offers don't survive saving and quitting — recharge the Seeker after
  reloading). Hoenn keeps Match Call, and its offers survive moving between areas.
- **Autosave** (off by default) — quietly saves as you move between areas, at most once
  every 10 minutes; it skips while flying.
- **Safari Zone continue** — pay ¥500 to keep going when the clock or your Safari Balls
  run out.

**Convenience**

- **Reusable TMs** and **chain fishing**.
- **HMs are forgettable** like any other move, and **trade evolutions work offline** — use
  a **Linking Cord** (sold in department stores) like an evolution stone.
- **Nicknames** — rename Pokémon from the party menu or summary screen; a **Nicknames**
  Options toggle skips the catch/hatch naming prompt (prompts on by default).
- **Item descriptions shown on pickup**.
- IV/EV pages in the summary screen and **dynamic move types** shown in battle.
- **HGSS-style Pokédex** — the main page is region-aware: your campaign region's
  SEEN/CAUGHT counts plus a cross-region TOTAL.
- Department stores carry **curated held and evolution items** (nothing that only serves
  unobtainable species); **PP Up / PP Max** on the vitamins clerks.
- The Goldenrod flower shop hands out the **Wailmer Pail** (after the Squirtbottle event),
  so Johto berry growing can't dead-end. **Chansey attendants** assist the nurse in nearly
  every Pokémon Center.
- **The wall clock is set once, globally** — no re-setting it per region.

## Developer additions

- The **overworld debug menu** is available in default builds (hold R + press START):
  warps, flag/var toggling, Pokémon/item generation, Fly-to-map, and more, with
  hold-to-repeat on numeric inputs. `make RELEASE=1` builds strip it.
- Compile-time invariants (`STATIC_ASSERT`s) guard the recurring save-layout and overflow
  bug classes introduced by the merge (trainer-ID ranges, flag-bank boundaries,
  `MapHeader` layout).

## Tools, libraries & systems

Pokémon World is a decomp-style project: the ROM is reassembled from C, assembly, JSON
data, and raw assets, following pokeemerald / pokeemerald-expansion conventions.

**Toolchain (modern only):**
- `arm-none-eabi-gcc` + `arm-none-eabi` binutils (`as`, `ld`, `objcopy`, `objdump`).
- **newlib** for `arm-none-eabi` — provides `libc.a` / `libnosys.a`.
- **agbcc is not used.** The build forces `-DMODERN=1`.
- `libpng` (development headers) for the graphics tools, and `python3` for build scripts.

**In-repo build tools** (`tools/`, compiled automatically by the Makefile): `preproc`,
`gbagfx`, `gbafix`, `mapjson`, `jsonproc`, `trainerproc`, `mid2agb`, `wav2agb`, `rsfont`,
`scaninc`, `ramscrgen`, `bin2c`, `learnset_helpers`, `compresSmol`, `patchelf`, and the
test runners `mgba` / `mgba-rom-test-hydra`, among others.

**Testing:** the battle-engine **test framework** in `test/` runs via `make check`,
executed through the bundled `mgba-rom-test` runners. A `make release` target builds with
`NDEBUG` + LTO.

**Asset / map / script editing** (external, standard for this engine family):
- [Porymap](https://github.com/huderlem/porymap) — map editing.
- [Poryscript](https://github.com/huderlem/poryscript) — higher-level event scripting.
- [Tilemap Studio](https://github.com/Rangi42/tilemap-studio) — tilemap editing.
- [Porytiles](https://github.com/grunt-lucas/porytiles) — tileset compilation.

**Libraries / systems used in this repo:** `comfy_anim`
(`src/comfy_anim.c` / `include/comfy_anim.h`) — a small easing/spring animation library on
Q24.8 fixed-point values, backing the SwSh UI animations — and the
[all-contributors](https://allcontributors.org/) spec for the credits table in
[CREDITS.md](CREDITS.md).

## Roadmap

- A **full playthrough of all three campaigns** (and inter-region travel) for pacing and
  balance.

## Inherited from pokeemerald-expansion

Everything below comes from the **base engine**
([pokeemerald-expansion](https://github.com/rh-hideout/pokeemerald-expansion), itself built
on [pret/pokeemerald](https://github.com/pret/pokeemerald)). Pokémon World inherits these
as-is; many can be toggled in the configuration files.

### Configuration files
Many of the features below are toggleable. The headers live in this repo under
`include/config/`; the links point to the upstream versions for reference:
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
- ***Updated move data:*** Fairy/Stellar types, Physical/Special split, flags.
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
- ***Simpler species data manipulation:*** Only requires to edit ~5 files instead of vanilla pokeemerald's 20+ to add a new Pokémon.
- ***Updated sprites:*** DS-style sprites with support for Emerald's 2-frame animations and gender difference.
- ***Species toggles:*** You can disable specific groups of Pokémon to save space, including families, cross-gen evolutions, Mega Evolutions, Regional forms, etc.
- ***Revamped Evolution System:*** Multiple Evolution conditions can be stacked in order to create complex methods without additional coding. Every condition except Affection and console gyroscope is supported.
- ***Form Change System:*** Most form changes can be added without additional coding. This includes support for: Holding/using an item, HP thresholds being met, weather change in and/or out of battle, Fusions, and more.

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
- ***Modern Mechanics:*** Defog field move, B2W2+ Repel system, Running indoors, Removed field poison, Chain fishing, VS. Seeker, FRLG+ whiteout message.
- ***Overworld and Follower Pokémon*** ([feature branch](https://github.com/aarant/pokeemerald/tree/followers-expanded-id) by @aarant)
    - *Includes Dynamic overworld palettes (DOWP) and Overworld Expansion for event IDs beyond 255.*
    - *Includes Pokémon sprites up to Generation IX.*
- ***Day/Night System*** ([feature branch](https://github.com/aarant/pokeemerald/tree/lighting-expanded-id) by @aarant)
    - *Includes support for non-real time clock.*
- ***NPC Followers*** ([feature branch](https://github.com/ghoulslash/pokeemerald/tree/follow_me) by @ghoulslash)
- ***BW Map Pop-ups*** ([feature branch](https://github.com/ravepossum/pokeemerald/tree/bsbob_map_popups) by @BSBob)
- ***XY Berry Mechanics:*** Mutations, moisture, weeds, pests.
- ***Obtained Item descriptions*** (feature branch by @ghoulslash).

### Developer tools
- ***Integrated Testing:*** Pinpoint if your custom mechanics have broken something else in the game or not.
- ***Pokémon Sprite Visualizer:*** Test every Pokémon sprite and animation.
- ***Overworld debug menu*** ([original feature branch](https://github.com/TheXaman/pokeemerald/tree/tx_debug_system) by @TheXaman): Support menu with an assortment of features to facilitate debugging, including warping, flag and var toggling, Pokémon and item generation and more.
- ***Battle Debug Menu:*** Modify data on the fly in the middle of a battle.
- ***Learnset Helper:*** Autogenerate movesets from your custom TM and Tutor data based on official compatibility data.
- ***Configurable script flags:*** Disabling Wild encounters, Disabling Trainer battles, Forcing/Disabling Shinies.
- ***Saveblock Cleansing*** ([feature branch](https://github.com/ghoulslash/pokeemerald/tree/saveblock) by @ghoulslash)
