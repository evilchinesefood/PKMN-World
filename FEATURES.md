# Features

**Pokémon World** merges Kanto, Johto and Hoenn into one GBA game, built on
[pokeemerald-expansion](https://github.com/rh-hideout/pokeemerald-expansion) 1.16.2
(`include/constants/expansion.h`). It inherits most of the expansion's engine work, adds the
three-region merge on top, and ships a handful of ported community features.

A plain `make modern` produces the full three-region game — the feature flags in
`include/config/` are there for tuning, not because anything needs switching on. Sources and
authors for the ported work are in [CREDITS.md](CREDITS.md); build instructions are in
[INSTALL.md](INSTALL.md).

### What this build turns *off*

Worth knowing up front, because the upstream feature list advertises all of it:

| Turned off | Where |
|---|---|
| Every Gen 4–9 Pokémon family (339 of them) | `include/config/species_enabled.h` |
| Dynamax, Gigantamax, Terastallization | `species_enabled.h` (`P_GIGANTAMAX_FORMS`, `P_TERA_FORMS`) |
| Link-era features: Mystery Gift/Event, Wonder News, e-Reader, Union Room, wireless chat, record mixing, Cable Club | `include/config/link.h` — compiled out entirely |
| The quest / mission-log engine (never had content authored) | `include/config/quests.h` — compiled out, ~26 KB reclaimed |
| NPC followers (the "follow me" partner system) | `include/config/follower_npc.h` |
| XY berry mechanics: mutations, moisture, weeds, pests | `include/config/overworld.h` |
| Defog and Rock Climb as field moves | `include/config/overworld.h` |

## Contents

- [Three regions, one game](#three-regions-one-game)
- [World Transit hub](#world-transit-hub)
- [Moving between regions](#moving-between-regions)
- [What's shared, what isn't](#whats-shared-what-isnt)
- [Rematches and Hard Mode](#rematches-and-hard-mode)
- [Team Rocket ambushes](#team-rocket-ambushes)
- [World Championship](#world-championship)
- [Battle Net and the Mega economy](#battle-net-and-the-mega-economy)
- [Character customization](#character-customization)
- [Riding your Pokémon](#riding-your-pokémon)
- [Ported features](#ported-features)
- [Quality-of-life defaults](#quality-of-life-defaults)
- [For developers](#for-developers)

## Three regions, one game

Three self-contained campaigns on one cartridge. Each has its own story, 8 gyms and badges,
Elite Four, Champion and Hall of Fame, and you choose the order.

- **Kanto** — the FireRed campaign, wired live: every FRLG trainer fights its real FRLG party,
  with the real gym leader / Elite Four / Champion rosters, rival **GARY** (who is also the Kanto
  Champion), and the Route 23 badge checkpoints guarding Victory Road.
- **Johto** — ported in: **251 maps** with tilesets and scripts, **312 distinct trainers**,
  wild-encounter tables, the Johto town map with Fly and heal locations, rival **GARY** again, and
  the Johto League (Will / Koga / Bruno / Karen → **Champion Lance**) with HGSS-style portrait art
  for the eight gym leaders, the Elite Four and Lance. 67 trainers that used to share a Hoenn
  trainer's ID — and therefore its party and its defeat flag — were moved onto their own ID bank
  in save format v9; route, dungeon and gym copies run authentic GSC parties. Post-game: **Red at
  Mt. Silver**, the roaming beasts, the **Celebi** GS Ball chain, the **Ruins of Alph** puzzles, the
  National Park **Bug-Catching Contest**, and the Ho-Oh / Lugia events.
- **Hoenn** — the native Emerald campaign, plus the **Battle Frontier** as the shared post-game
  facility. It's reachable from the hub once you've cleared at least one region's league.

### The Gen 1–3 rule

Every wild, gift and trainer-owned Pokémon comes from the first three generations. Gen 1–3 lines
keep their **later-gen evolutions** — Togekiss, Electivire, Weavile, Sylveon and the rest — the
cross-gen evolution items are sold in-world, and those evolutions count toward the National Dex.

This is enforced, not just a style guide. Every Gen 4–9 family is `FALSE` in
`include/config/species_enabled.h`. A reference to a disabled species compiles clean and then
blue-screens at battle start, so `Testing/ValidateGen13.py` — run by `make validate` and the
pre-push hook — scans every obtainable-species source and fails on any disabled reference.

## World Transit hub

New games open with a unified Oak intro — gender, name, outfit picker, and a one-time **Hard
Mode** choice — then land in the **World Transit hub**, an Indigo-Plateau-styled terminal.

Four staffed departure gates (Kanto, Johto, Hoenn, Battle Frontier), a nurse and heal point, a
storage PC, and a **World Tour board** that reads your running badge total out of 24 with a
per-region breakdown.

The front-desk mart carries twelve ball types (Great through Premier — no plain Poké Balls),
top-tier heals, Max Repels and a free **Town Map**, and there are separate TM, training-item and
battle-item vendors.

Four staffers hand things out:

| Who | What |
|---|---|
| **Charm Curator** | A **Hub Pass** and a **Pokévial** on first contact, then a badge ladder: 4 badges → Catching Charm, 8 → Exp. Charm, 12 → Oval Charm, 16 → Shiny Charm, 24 → **EV/IV Changer** (a reusable key item for tuning a party Pokémon's EVs and IVs; press R to flip pages, EVs still capped at 252/510 and IVs at 0–31). |
| **Sky Charm keeper** | The free-flight key item, once you can actually fly — you need HM Fly *and* a Fly badge from some region. |
| **Harbor Master** | Event tickets as you win championships: Eon Ticket (1 championship), Old Sea Map (2), Mystic Ticket (all 3). Each also flips the matching ship flag, so the Lilycove and Vermilion counters honor it too. |
| **Dex researcher** | Caught-species milestones: 150 → PP Max, 300 → Master Ball, complete National Dex → 10 Rare Candies and a diploma. |

## Moving between regions

**First visit** to a region plays a short "Mom moves into the new house" arrival, then that
region's own canonical opening, including a choice of its three starters.

**Switching regions through a hub gate** boxes your current party to the shared PC so each
campaign starts fresh. Held mail moves to the PC mailbox — nothing is lost — and if the boxes or
the mailbox can't take the whole team, the crossing is refused up front rather than half-boxing
you. You can withdraw anything from any region at any time.

**Getting back to the hub** is the **HUB PASS**, a key item that warps you there from the bag.
It's a one-way trip, so you re-enter regions through the departure gates. The Charm Curator hands
it over, and every gate attendant force-gives it before letting you cross, so you can't strand
yourself. Each region also has its own in-world access point — the **Goldenrod Magnet Train
station**, **Vermilion City**, and the **Slateport harbor** — that the hub returns you to after
that region's first gym badge. Until then, later visits still drop you at home so the opening
campaign cannot resume halfway across the region.

**Johto ↔ Kanto by sea** is the one crossing that isn't a hub gate. Elm's S.S. Ticket sends the
new Johto Champion out of the **Olivine harbor** on the maiden voyage; you disembark in the
**Vermilion City port** and walk out onto Kanto's harbor. Because it's in-world travel rather than
a hub departure, **your party sails with you** — HG/SS treats the two regions as one journey.
Kanto still becomes the active region, so badges, obedience and difficulty follow the shore you're
standing on. The Vermilion pier sailor sells the return crossing, and after the first crossing the
Olivine destination board opens up: Vermilion plus the event-ticket runs (Battle Frontier,
Southern Island, Birth Island, Faraway Island). An event island remembers which harbor booked the
trip — sail from Olivine and you come home to Olivine; sail from Lilycove and you return to
Lilycove.

**Saves.** The active region and hub state live in a versioned save format with a migration
reader. The current format is **v9**; v7 and v8 saves migrate forward on load. Anything older is
**refused at load with an explanation** rather than migrated — the v7 bag/PC resize reshaped the
layout, and a legacy save would otherwise half-load with silently misaligned flags and vars.

## What's shared, what isn't

**Shared:** money, bag, TMs/HMs, PC boxes, and a single **National Pokédex**. Key items and HMs
deduplicate across regions — if one is already in your bag or your item PC, a second giver won't
hand you another. The **Exp. Share is exempt**: it's an ordinary held item here rather than a key
item, so each of its sources across the three regions gives you its own copy and you can end up
carrying several.

**Per region:** story flags, badges (each region has its own badge bank), and trainer-defeat
flags. Obedience and HM field moves are gated by the **current** region's badges, so a boxed
Kanto team obeys according to your Johto badges while you're in Johto.

The **trainer card has three badge pages** — L and R flip between Hoenn, Kanto and Johto.

## Rematches and Hard Mode

- **All 24 gym leaders** offer unlimited rematches once you're **that region's** Champion, each
  with a HARD team at **Lv 58–65** with held items and competitive movesets. Difficulty is
  contained per region: being Hoenn Champion doesn't harden Kanto's first-run gyms.
- Once you're a region's Champion, its **Elite Four and Champion rematch** field HARD teams. Your
  first clear still faces the normal gauntlet.

  | League | Rematch levels |
  |---|---|
  | Hoenn (Sidney → Wallace) | 62–68 |
  | Johto (Will → Lance) | 70–78, Lance's Dragonite at 78 |
  | Kanto Elite Four | 70–76 |
  | Kanto Champion (GARY) | 77–80 |

- **Hard Mode** is chosen once during the intro and locked for that save: Set-style battles, no
  bag items in trainer battles, and badge-based level caps.

## Team Rocket ambushes

**Jessie & James** stalk you across all three regions — five one-time duo encounters at **Mt.
Moon**, the **Rocket Hideout**, the **Slowpoke Well**, the **Goldenrod Radio Tower** and **Route
118**. Each is a deliberately unfair **1-vs-2 double** — you face both Rockets alone — capped off
with their trademark blast-off exit. They also take a seat in the World Championship bracket.

## World Championship

Once you're Champion of all three regions, a registrar in the Battle Dome lobby offers the
**World Championship**: a fixed 15-trainer Battle Dome bracket of cross-region champions — Red,
Blue, Lance, Steven, Wallace, eight Elite Four members (Lorelei, Agatha, Sidney, Phoebe, Glacia,
Drake, Karen, Will), Sabrina and Team Rocket — with **Red** seeded into the final slot opposite
you. Winning grants a permanent title and a one-time **Gold Bottle Cap**, and the tournament is
rematchable afterward.

## Battle Net and the Mega economy

Become any region's Champion and the **Battle Net terminal** in the hub unlocks the flagship floor
upstairs (RegionHub 2F) — the home of **Mega Evolution**.

**Stones and Shards**

- The **Director** hands you the **Mega Ring** plus a free Mega Stone for your starter's line
  (one-time; if your bag is full, both wait for you).
- Every HARD gym-leader, Elite Four and Champion rematch win pays **Shards** — 1 for leaders, 2
  for league members — repeatable.
- The **first** HARD win against each of the **28 stone-holding leaders** also drops their
  signature Mega Stone — the same stone their HARD party holds and Mega Evolves with against you.
  The Kanto Champion rematch drops the **Mewtwonite X and Y** pair on top, though that party
  doesn't use them. That is **30 stones** on the drop circuit in all, and the records board counts
  them out of 30.
- A full bag holds a stone for reclaim on a later win. A blocked Shard payout tells you and is
  forfeited, so make room first.
- The flagship **vendor** sells the remaining stones for Shards, and the **exchange clerk**
  converts Battle Points to Shards at **4 BP each**. A handful of Shards are hidden in the world
  for the Itemfinder.

**The sims**

Simulated battles pay **full EXP** and trigger evolutions as usual, while no money changes hands,
a loss never whites you out, and your party is restored around every match. That makes them the
game's training grounds. On a Hard Mode save the badge level caps apply to sim EXP like all other
EXP, so the sims train you up to your cap, not past it.

| Mode | Where | Pays |
|---|---|---|
| **Scaling Type Trainer** — 2–4 Pokémon of a type you pick, a few levels below your party | Any terminal | 1 BP + a 30% Shard drop |
| **Leader Sim** — replays any gym leader's HARD rematch; unlocks per region with that region's championship | Any terminal | 2 BP (no Shards or stones — those stay on the real gym visits) |
| **Tower Streak** — up to 7 sims in a row against random types, best run on the records board | Flagship floor | 1 BP per win, +5 BP for a perfect run |
| **Lv50 / Monotype / Little Cup rooms** — three-mon sims; your party has to match the rule | Flagship floor | 2 BP a win |

**Every Pokémon Center lobby** — 50 rooms in all, covering the three regions, the Sevii Islands,
the league lobbies, Mt. Silver, the Battle Frontier and the hub — has a **Battle Net wall
terminal** beside the PC carrying the Scaling Type Trainer and Leader Sim, so the sim economy
travels with you. The old Center 2Fs (and the link-era rooms they hosted) are gone; the hub's
flagship floor gained a real staircase.

## Character customization

You play as Brendan or May in every region. A **six-outfit palette-swap** system is chosen in the
new-game intro with a live preview on the trainer sprite, and applies everywhere: overworld,
battle back-sprite and trainer card.

## Riding your Pokémon

Surf and flight both put you on your own team, with a proper riding model — the mount's lower body
draws in front of you, so you sit *in* the saddle rather than perched on top, with a single soft
ground shadow.

- **Mount selection** (both moves): your walking follower rides first if it can use the move
  (knows it, or could learn it); otherwise the first capable party member in party order. The pick
  stays stable across warps, dives and saving.
- **Surf** (`OW_SURF_USES_MON_SPRITE`) — your Pokémon's real overworld sprite carries you, with a
  shadow on the water.
- **Flight** — the **Sky Charm** key item toggles free overworld flight and HM Fly mounts the same
  way (Flygon stands in if nothing capable is on the team). Flying in a region needs **that
  region's** Fly badge: Kanto Thunder, Johto Mineral, Hoenn Feather.

## Ported features

Ported from other community bases; sources and authors are in [CREDITS.md](CREDITS.md). All of
these are on, and each has its own config flag.

**Sword/Shield UI suite** — each screen is an independent toggle.

| Screen | What it adds | Flag |
|---|---|---|
| Party menu | SwSh party screen, idle animations, PC access, the follower "Follow" chooser | `SWSH_PARTY_MENU` |
| Summary screen | Nature-colored stats, IV/EV pages, category icons, status/type icons | `SWSH_SUMMARY_SCREEN` |
| Storage system | SwSh-styled PC boxes with a box-selection grid | `SWSH_STORAGE_SYSTEM` |
| Bag / item menu | In-bag item actions, in-battle bag path, TM/berry info | `SWSH_ITEM_MENU` |
| Message / name box | SwSh message and name box; NPC trainers can auto-show a name box | `SWSH_MESSAGE_BOX` |
| Map-name pop-up | Gen-8-style map pop-ups | `OW_POPUP_GENERATION == GEN_8` |

**Unbound-style graphical start menu** (`PW_GRAPHICAL_START_MENU`) — sprite-icon Start menu
entries the player can rearrange, day/night compatible. The classic list menu is kept as a
fallback.

**HGSS follower Pokémon** (`OW_FOLLOWERS_ENABLED`), plus a Pokémon World addition: a **"Follow"
chooser in the party menu**, so any party member — not just the lead — can be your follower.

**ORAS key-item registration wheel** (`I_KEY_ITEM_WHEEL`) — up to 4 key items registered to
SELECT, one per D-Pad direction.

**Pokévial** (`POKEVIAL_FEATURE`) — a refillable key item that fully heals the party. Two doses
per charge, refilled every time a Pokémon Center nurse heals you. There is no in-game upgrade
path today, so it stays at two.

**Field-move QoL gates** (`include/config/qol_field_moves.h`) — two ways to skip HM chores, both
on:

- `QOL_FIELD_MOVES_NO_TEACH` — a party Pokémon that *could learn* an HM performs its field move
  without being taught it. Badge gates still apply.
- `QOL_FIELD_MOVES_ITEM_GATE` — owning the matching tool item (`ITEM_CUT_TOOL` … `ITEM_DIVE_TOOL`)
  unlocks that field move outright.

## Quality-of-life defaults

**Battle and progression**

- **EXP RATE** and **CATCH RATE** multipliers in the Options menu — 0.5× / 1× / 1.5× / 2× each,
  defaulting to 1×.
- **SHARED EXP** toggle — party-wide Exp. Share, off by default. When it is on the share is **even**:
  a Pokémon that sat out earns the same base EXP as the one that fought, not the Gen 6+ half. Level
  weighting still applies per Pokémon, so an under-levelled party member still gains a little more
  and an over-levelled one a little less.
- **Level-ups are quiet.** No fanfare stall, no "grew to Lv." page and no stat box mid-battle; the
  Pokémon on the field still shows its level-up sparkle and its level ticking up in the healthbox.
  One **"Your team grew stronger!"** box after the battle lists everyone that levelled, with the
  levels they started and finished on. Move-learning prompts are unchanged and still appear as they
  are earned. EXP-gain messages are not printed — the EXP bar already shows it.
- **RUN SHORTCUT** for fleeing wild battles — Off / Cursor (B jumps to Run) / Instant. Cursor is
  the default.
- **AUTO RUN** and **NICKNAMES** toggles (the latter skips the catch/hatch naming prompt; prompts
  are on by default).
- Type and effectiveness indicators are always shown in battle.
- Move relearners are enabled, including the TM-move relearner.

**Exploration**

- **DexNav** — granted with each region's Pokédex; the hidden-Pokémon detector unlocks with your
  first championship. Hidden encounters are authored for **every land encounter table** in the
  three regions (405 of 405). The 11 Battle Pyramid / Battle Pike dummy headers are not land
  tables. Hidden slots skew rarer and slightly higher-level than the local grass.
- **Visible overworld encounters** run *alongside* vanilla random grass encounters — both fire on
  the same map by design.
- **Each region's starters are catchable** on its first route at roughly 10% each — Route 101,
  Route 1 and Route 29 — so the two you didn't pick are obtainable. Lab gifts stay exclusive.
- **Saffron Dojo Hitmons and Mt. Moon fossils are both obtainable.** Taking one no longer
  locks the other. Miguel does not steal the leftover fossil. Regional starters (Oak, Elm,
  Route 101 Birch, Birch’s post-National Dex Johto trio) stay one-choice.
- **Cut trees and smashed rocks stay gone** when you leave and re-enter a map.
- **Encounter tables are flat** — every Pokémon is catchable at any hour. Time of day still drives
  the lighting and which Pokémon walk the overworld; it does not gate what the grass gives you.
- **Whirlpool** clears the whirlpools on Route 41 and in the Dragon's Den, opening the Whirl
  Islands (and Lugia) and the Dragon's Den Shrine. It is gated on the **Glacier Badge** and works
  by walking into the whirlpool rather than from the party menu — the whirlpool stays put and is
  crossed again each time, as in HG/SS.
- **Kanto VS Seeker** — rematches from **85 trainer groups**, with teams that escalate as you earn
  badges. The Kanto offer state lives in EWRAM rather than the save, so offers don't survive
  saving and quitting; recharge the Seeker after reloading. Hoenn keeps Match Call, whose offers
  do survive moving between areas.
- **Autosave** (off by default) — quietly saves as you move between areas, at most once every 10
  minutes. It stands down while you're flying, inside a battle facility or the Safari Zone, and
  during a region's first-visit arrival scene.
- **Safari Zone continue** — pay ¥500 to keep going when the clock or your Safari Balls run out.
- Kanto keeps its **FRLG map-preview screens** for its dungeons (Viridian Forest, Mt. Moon and
  friends). They're gated to Kanto at runtime, so they don't fire in Hoenn or Johto.

**Convenience**

- **Reusable TMs** and **chain fishing**.
- **HMs are forgettable** like any other move, and **trade evolutions work offline** — use a
  **Linking Cord** (sold in the Celadon and Lilycove department stores, the Mahogany shop and the
  hub) like an evolution stone.
- **Nicknames** can be changed from the party menu or summary screen.
- **Item descriptions are shown on pickup**, and IV/EV pages are available in the summary screen.
- **HGSS-style Pokédex** — the main page is region-aware: your campaign region's SEEN/CAUGHT
  counts plus a cross-region TOTAL.
- Department stores carry curated held and evolution items — nothing that only serves unobtainable
  species — and PP Up / PP Max are on the vitamin clerks.
- The Goldenrod flower shop hands out the **Wailmer Pail** after the Squirtbottle event, so Johto
  berry growing can't dead-end. **Chansey attendants** assist the nurse in nearly every Pokémon
  Center.
- **The wall clock is set once, globally** — no re-setting it per region.

## For developers

**Build.** Modern toolchain only: `arm-none-eabi-gcc` and binutils, newlib, `libpng` for the
graphics tools, `python3` for build scripts. agbcc is not used — the build forces `-DMODERN=1`,
and `ALL_REGIONS` defaults to 1. The in-repo tools in `tools/` compile automatically: `preproc`,
`gbagfx`, `gbafix`, `mapjson`, `jsonproc`, `trainerproc`, `mid2agb`, `wav2agb`, `rsfont`,
`scaninc`, `ramscrgen`, `bin2c`, `learnset_helpers`, `compresSmol`, `patchelf`, plus the `mgba`
and `mgba-rom-test-hydra` test runners.

`make RELEASE=1` (or `make release`) builds with `-DRELEASE` and LTO, and strips the debug menu.

**Testing**, in increasing order of cost:

| Command | What it covers |
|---|---|
| `make validate` | Host-side, no build: the Gen 1–3 species rule, bare-integer script pointers, overworld Pokémon placements, map object events, plus the obstacle table and save-patch self-checks. Also run by the pre-push hook. |
| `make check` | The inherited battle-engine test framework in `test/`, ~5,500 tests through the bundled `mgba-rom-test` runners. Also runs in CI. |
| `Testing/run-all.sh` | 43 in-game overworld suites driven by a patched headless mGBA (44 with the optional owner save). **Local only** — the emulator is built from mGBA master with a local patch and isn't in the tree (`Testing/mgba/README.md`). |

**Debug menu.** Available in default builds — hold R and press START in the overworld — for warps,
flag/var toggling, Pokémon and item generation, Fly-to-map and more, with hold-to-repeat on
numeric inputs. `make RELEASE=1` strips it.

**Compile-time invariants.** `STATIC_ASSERT`s guard the recurring bug classes the merge
introduced: trainer-ID ranges, flag-bank boundaries, `MapHeader` layout, Battle Net flag blocks
and the Pokévial's save nibbles.

**Editing tools** (external, standard for this engine family):
[Porymap](https://github.com/huderlem/porymap) for maps,
[Poryscript](https://github.com/huderlem/poryscript) for event scripting,
[Tilemap Studio](https://github.com/Rangi42/tilemap-studio) for tilemaps, and
[Porytiles](https://github.com/grunt-lucas/porytiles) for tileset compilation.

**In-repo library:** `comfy_anim` (`src/comfy_anim.c` / `include/comfy_anim.h`), a small
easing/spring animation library over Q24.8 fixed-point values, backing the SwSh UI animations.

## Inherited from pokeemerald-expansion

Everything not described above comes from the base engine and is inherited as-is: the upgraded
battle engine (Mega Evolution, Primal Reversion, the physical/special split, Fairy type, every
item/ability/move effect up to Gen IX, modern damage and EXP calculations, improved AI, faster
battles), Showdown-syntax trainer teams with custom party data and Ace Pokémon, the modernized
Pokémon data structure and evolution/form-change systems, the interface improvements, the
day/night system, overworld and follower Pokémon, BW map pop-ups, and the developer tooling
(integrated testing, sprite visualizer, battle debug menu, learnset helper).

Some gimmicks the engine supports are technically compiled in but unreachable here because their
Pokémon or items are: Ultra Burst needs Necrozma (Gen 7, stripped), and no Z-Crystal is placed
anywhere in the world.

The upstream feature list is at
[rh-hideout/pokeemerald-expansion](https://github.com/rh-hideout/pokeemerald-expansion). Read it
against the *[What this build turns off](#what-this-build-turns-off)* table above — several
headline items are compiled out here. The config headers live in this repo under
`include/config/`; those are the authority for what is actually on.
