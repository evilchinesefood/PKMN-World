# Features

**Pokémon World** puts Kanto, Johto and Hoenn on one Game Boy Advance cartridge. It is built on
[pokeemerald-expansion](https://github.com/rh-hideout/pokeemerald-expansion) 1.16.4. This page
lists what is in the game. Sources for ported work are in [CREDITS.md](CREDITS.md), build steps
are in [INSTALL.md](INSTALL.md), and every Pokémon and item is in [POKEDEX.md](POKEDEX.md).

## Contents

- [At a glance](#at-a-glance)
- [The three campaigns](#the-three-campaigns)
- [World Transit hub](#world-transit-hub)
- [Travelling between regions](#travelling-between-regions)
- [Shared and per-region progress](#shared-and-per-region-progress)
- [Story screen](#story-screen)
- [Pokémon](#pokémon)
- [Rematches](#rematches)
- [Battle Net](#battle-net)
- [Mega Evolution](#mega-evolution)
- [World Championship](#world-championship)
- [Team Rocket ambushes](#team-rocket-ambushes)
- [Facilities and side activities](#facilities-and-side-activities)
- [Field moves and riding](#field-moves-and-riding)
- [Exploration](#exploration)
- [Battles](#battles)
- [Options](#options)
- [Menus and presentation](#menus-and-presentation)
- [Player customization](#player-customization)
- [Convenience](#convenience)
- [Not in this game](#not-in-this-game)
- [For developers](#for-developers)

## At a glance

| | |
|---|---|
| Regions | Kanto, Johto and Hoenn, plus the Sevii Islands and the World Transit hub |
| Badges | 24, eight per region |
| Leagues | Three Elite Fours and Champions, each with a Hall of Fame |
| Pokémon | 404 obtainable (383 of the 386 from Generations 1 to 3, plus 21 later relatives) |
| Mega Evolutions | 39 |
| Maps | 1,151 (Hoenn 501, Kanto and Sevii 399, Johto 249, hub 2) |
| Save format | 14 |

## The three campaigns

Each region is a full story with eight gyms, an Elite Four, a Champion and a Hall of Fame. You
can play them in any order and switch between them mid-story.

- **Kanto.** The FireRed campaign with its original trainer parties, the Route 23 badge gates and
  the Sevii Islands (One to Seven Island, with the Lostelle, Meteorite, Ruby and Sapphire chains).
  The rival is GARY, who is also the Champion.
- **Johto.** 249 ported maps with their own scripts, trainers and wild tables, a Johto town map
  with Fly points, and portraits for the gym leaders and League. The rival is GARY again and the
  Champion is Lance. The post-game has Red on Mt. Silver, roaming Entei and Raikou, a static
  Suicune, the GS Ball and Celebi chain, the Ruins of Alph, the Bug-Catching Contest, Ho-Oh in the
  Tin Tower and Lugia in the Whirl Islands.
- **Hoenn.** The Emerald campaign. The rival is May or Brendan and the Champion is Wallace.

The end credits are removed. After a Hall of Fame the game saves and returns to the title screen.

## World Transit hub

A new game starts with one Professor Oak intro (gender, name and outfit) and then places you in
the hub. The Charm Curator offers an optional tour.

| Service | What it does |
|---|---|
| Departure gates | Kanto, Johto, Hoenn and the Battle Frontier. The Frontier gate opens after any one championship. |
| Nurse and PC | Heals the party and opens Pokémon storage. |
| Front desk | Twelve ball types (Great to Premier, no plain Poké Balls), Full Restore, Max Potion, Max Revive, Full Heal, Max Repel and a free Town Map. |
| TM vendor | 16 TMs, including Earthquake, Ice Beam, Thunderbolt, Flamethrower, Psychic and Shadow Ball. |
| Training vendor | Vitamins, PP Up, PP Max, the six feathers and all 21 nature mints. |
| Battle Depot | Six evolution stones, Everstone, Linking Cord and held items such as Leftovers, the Choice items, Life Orb and Eviolite. |
| World Tour board | Your badge total out of 24, split by region. |
| Wardrobe | Change outfit style and colour for free. |
| Battle Net | A wall terminal, and stairs to the flagship floor after any one championship. |

Four staff members give rewards:

| Who | Reward |
|---|---|
| Charm Curator | Hub Pass and Pokévial on first contact. Then by total badges: 4 Catching Charm, 8 Exp. Charm, 12 Oval Charm, 16 Shiny Charm, 24 EV/IV Changer. |
| Sky Charm keeper | The Sky Charm, once you hold HM Fly and a Fly badge from any region. |
| Harbor Master | Eon Ticket after one championship, Old Sea Map after two, Mystic Ticket after all three. |
| Dex researcher | PP Max at 150 caught, a Master Ball at 300, and 10 Rare Candies for a complete Pokédex. |

The **EV/IV Changer** is a reusable key item that sets a party Pokémon's EVs and IVs.

## Travelling between regions

- **First visit.** Your party is stored in the PC and you play that region's own opening,
  including its choice of three starters.
- **Later visits.** The gate offers **Use regional team** or **Keep current party**. Each region
  remembers the party you last left it with. The team is the same Pokémon, not copies, so training
  carries over. The gate previews missing members and asks before a partial recall.
- **Where you arrive.** Choose **Resume at Center** (the last Pokémon Center you entered there) or
  **Standard arrival**. Standard arrival is your bedroom, or after that region's first badge its
  access point: Vermilion City, the Goldenrod Magnet Train station (once you are past Ilex Forest)
  or Slateport Harbor (once you have reached Slateport).
- **Hub Pass.** A key item that warps you to the hub from the Bag. Every gate makes sure you carry
  it. It does not work in the Safari Zone, League rooms, the Bug-Catching Contest, Frontier
  challenges or underwater.
- **In-world exits.** The Vermilion pier, the Goldenrod Magnet Train, Slateport Harbor and the
  Battle Frontier shuttle also return you to the hub.
- **S.S. Aqua.** The Johto Champion sails from Olivine to Vermilion with the S.S. Ticket, keeping
  the party on board. The return trip is free. After the first crossing the Olivine board also
  sails to the Battle Frontier, Southern Island, Birth Island and Faraway Island with the right
  ticket.

Travel never heals the party, and the hub is never a white-out point.

## Shared and per-region progress

| Shared | Per region |
|---|---|
| Money, Bag, TMs and HMs | Badges |
| PC boxes and party Pokémon | Story flags |
| One National Pokédex | Trainer defeats |
| Options and the clock | Remembered team and return point |

- Obedience and field moves follow the badges of the region you are standing in.
- Key items and HMs are not handed out twice. Later givers skip an item you already own.
- The trainer card has three badge pages. L and R flip between Hoenn, Kanto and Johto.

## Story screen

**Story** in the Start menu shows each region's status, badges, current objective, where to go
and the last milestone you reached. It tracks 164 objectives (Kanto 46, Johto 64, Hoenn 51, plus a
not-started entry for each) and has extra pages for the Lostelle, GS Ball and New Mauville errands.
Press A to show the destination on the map. Details are in
[docs/story-progress](docs/story-progress/README.md).

## Pokémon

- **Roster.** Generations 1 to 3 only. All 339 Gen 4 to 9 families are compiled out, and
  `make validate` fails if anything obtainable references one.
- **Later relatives.** 21 later-generation members of Gen 1 to 3 lines can be obtained, such as
  Weavile, Magnezone, Leafeon, Gliscor, Mamoswine and Annihilape. A few others (for example
  Togekiss and Sylveon) are in the data but their evolution item has no source.
  [POKEDEX.md](POKEDEX.md) has the full list.
- **Catchable starters.** Each region's three starters appear on its first route (Route 1, Route
  29 and Route 101) at about 10% each.
- **Both choices.** You can take both Mt. Moon fossils and both Saffron Dojo Pokémon.
- **Costume Pokémon.** Seven one-off costume forms (three Pikachu, two Squirtle, an Eevee and a
  Totodile) come from short errands in Kanto and Johto. Each knows a themed move, and a Special
  Pokémon screen tracks the set.
- **Legendaries.** The static and roaming legendaries of all three regions are in, including the
  ticket islands (Southern Island, Faraway Island, Navel Rock and Birth Island).

### Evolution changes

- **No trading needed.** Use a **Linking Cord** on Kadabra, Machoke, Graveler and Haunter. Metal
  Coat, King's Rock, Dragon Scale, Up-Grade, Deep Sea Tooth and Deep Sea Scale are used from the
  Bag like a stone.
- **Level alternatives.** Friendship, move and partner evolutions also happen at a set level, for
  example Golbat at 32, Chansey at 40 and Piloswine at 45.
- **Eevee** evolves by stone only: Thunder, Water, Fire, Sun (Espeon), Moon (Umbreon) and Leaf.
- **Held-item evolutions** (Gligar, Sneasel, Happiny) work at any time of day.
- **Magneton and Nosepass** evolve with a Thunder Stone, or by levelling up in New Mauville.

## Rematches

- **Gym leaders.** Once you are a region's Champion, all eight of its leaders offer unlimited
  rematches against a HARD team at Lv. 58 to 65 with held items. 19 of the 24 leaders Mega Evolve.
- **Leagues.** The Elite Four and Champion also switch to HARD teams: Hoenn at Lv. 62 to 68, the
  Kanto Elite Four at 70 to 76, the Kanto Champion at 77 to 80 and Johto at 70 to 78. Steven has a
  HARD team at Lv. 78 to 82.
- **Per region.** Being Champion of one region does not raise the difficulty of another.
- **Hoenn Match Call.** Leaders still phone for rematches, and the champion rematch answers them.
- **Kanto VS Seeker.** 85 trainer groups, with teams that step up at 3, 5 and 7 badges and again
  after the League. It recharges in 100 steps.

## Battle Net

Simulated battles that pay full EXP. Your party is restored afterwards, a loss does not white you
out, and no prize money changes hands.

| Mode | Where | Pays |
|---|---|---|
| Scaling Type Trainer: two to four Pokémon of a type you pick, a few levels below your party | Any terminal | 1 BP and a 30% chance of a Shard |
| Leader Sim: replays a gym leader's HARD team, unlocked by that region's championship | Any terminal | 2 BP |
| Tower Streak: seven sims in a row | Flagship floor | 1 BP a win, 5 more for clearing all seven |
| Lv. 50, Monotype and Little Cup rooms: three-Pokémon sims with a party rule | Flagship floor | 2 BP a win |

- **Terminals.** 50 Pokémon Center lobbies across the three regions, the Sevii Islands, the League
  lobbies, the Battle Frontier and the hub have a wall terminal next to the PC. The old Center
  second floors are sealed.
- **Flagship floor.** Upstairs in the hub after any one championship: the Director, the stone
  vendor, the BP clerk, the streak attendant and a records board.

## Mega Evolution

- The Battle Net **Director** gives the Mega Ring and one free starter stone of your choice (the
  seven Kanto and Hoenn starter stones).
- **Stone drops.** The first HARD win over each of 28 stone-holding leaders and League members
  gives the stone their team uses. The Kanto Champion rematch adds Mewtwonite X and Y, for 30 stones.
- **Shards.** HARD leader wins pay one Shard and League wins pay two, every time. The BP clerk
  sells Shards for 4 BP each, and a few are hidden in the world.
- **Vendor.** Ten stones for Shards: the starter stones and Gardevoirite at 35, Pinsirite and
  Mawilite at 20.

## World Championship

After all three championships, the registrar in the Battle Dome lobby runs a fixed 15-trainer
bracket: Red, Blue, Lance, Steven, Wallace, eight Elite Four members, Sabrina and Team Rocket. Red
is always the other finalist. Each win pays one **Gold Bottle Cap** and the normal Battle Points.
If the Bag is full the caps wait with the registrar.

## Team Rocket ambushes

Jessie and James ambush you five times: Mt. Moon, the Rocket Hideout, Slowpoke Well, the Goldenrod
Radio Tower and Route 118. Each is a one-time battle against both of them at once.

## Facilities and side activities

- **Battle Frontier.** All seven facilities, reached from the hub gate or by ferry.
- **Trainer Hill**, open after the Hoenn League.
- **Safari Zones** in Kanto, Johto and Hoenn. When time or Safari Balls run out you can pay ¥500
  to continue.
- **Bug-Catching Contest** in the National Park.
- **Pokémon Contests** in Lilycove, with Pokéblocks and berry blending.
- **Game Corners** in Mauville, Celadon and Goldenrod, with prize Pokémon in the last two.
- **Day Cares**, move tutors, and move relearners in Fallarbor, Blackthorn and Two Island.

## Field moves and riding

- **No teaching needed.** A party Pokémon that can learn a field move uses it without knowing it.
  The badge requirement still applies.
- **Badges by region.** Each region gates field moves on its own badges. Fly needs the third Kanto
  badge, the fifth Johto badge or the sixth Hoenn badge.
- **HM moves can be forgotten** like any other move.
- **Cut trees and smashed rocks stay cleared** after you leave the map.
- **Whirlpool** works by walking into a whirlpool after the seventh Johto badge.
- **Surfing** shows your own Pokémon carrying you.
- **Sky Charm.** A key item that toggles free flight outdoors, in any region where you hold the
  Fly badge.
- **Pokévial.** A key item that fully heals the party twice per charge. Any Pokémon Center nurse
  refills it.

## Exploration

- **Follower Pokémon.** A party member walks behind you. **Follow** in the party menu picks which
  one, and the choice survives reordering the party.
- **Visible wild Pokémon** roam the grass, caves and water next to ordinary random encounters.
- **Ambient Pokémon.** More than 800 non-battling Pokémon are placed across the towns and routes.
- **DexNav.** Given with each region's Pokédex. The hidden-Pokémon search unlocks at your first
  Hall of Fame, and every land encounter table has hidden encounters.
- **Day and night** change the lighting, town windows and battle backgrounds. Wild tables are the
  same at every hour.
- **Autosave** (off by default) saves shortly after you change maps, at most once every 10 minutes.
- **Chain fishing**, a Repel prompt when one runs out, and item descriptions on pickup.
- **Running indoors**, and no poison damage in the field.
- Kanto keeps its dungeon preview screens.

## Battles

- **Black/White-style interface** with type-effectiveness hints, move descriptions on L and the
  last-used ball on R.
- **Backgrounds** match the location and the time of day.
- **Weather indicator.** A tab at the top of the screen shows the active battle weather while
  you choose an action.
- **Quiet level-ups.** No mid-battle level-up box. One "Your team grew stronger!" summary after
  the battle lists every level gained.
- **Shared Exp** gives every party member the same base EXP as the one that fought.
- **No level caps and no Hard Mode.** HARD teams appear only in champion rematches.
- **Exp. Share** is an ordinary held item.
- **Shiny Charm** adds two extra shiny rolls.

## Options

| Option | Choices | Default |
|---|---|---|
| Text Speed | Slow, Mid, Fast, Instant | Mid |
| Battle Style | Shift, Set | Shift |
| Button Mode | Normal, LR, L=A | Normal |
| Frame | 20 window frames | 1 |
| Auto Run | Off, On | Off |
| Autosave | Off, On | Off |
| Run Shortcut | Off, Cursor, Instant | Cursor |
| Nicknames | On, Off | On |
| Exp Rate | 0.5x, 1x, 1.5x, 2x | 1x |
| Catch Rate | 0.5x, 1x, 1.5x, 2x | 1x |
| Encounter Rate | 0.5x, 1x, 1.5x, 2x | 1x |
| Money Loss | 0.5x, 1x, 1.5x, 2x | 1x |
| Shared Exp | Off, On | Off |

Encounter Rate covers ordinary walking and surfing encounters. Money Loss scales what you pay
after a defeat.

## Menus and presentation

- **Start menu.** An icon menu with up to six entries on screen. Press SELECT to rearrange it.
- **Party, Bag, summary and PC** in the Sword/Shield style. The party menu reaches the PC, and the
  summary shows nature colours, IV grades and EVs, and can rename a Pokémon or relearn moves.
- **Pokédex** in the HGSS style, with seen and caught counts for the current region and a total,
  plus stats, evolution and area pages.
- **Key-item wheel.** Register up to four key items to SELECT, one per direction.
- **Pop-ups and message boxes.** Gen 8 style map names and speaker name boxes.
- **Title screen and main menu** with Pokémon World artwork and a shared panel style across the
  main menu, Options and the move relearner.
- **Town lighting.** Windows glow at night in towns and cities, and ponds ripple in the rain.

## Player customization

You play as Brendan or May. There are four outfit styles (Original, Kanto Classic, Johto Classic
and Hoenn Classic) in six colours (Red, Blue, Green, Purple, Black and Pink). The outfit shows in
the overworld, in battle and on the trainer card. Pick it in the intro and change it at the hub
wardrobe.

## Convenience

- **Reusable TMs.**
- **Nature mints and feathers** at the hub, Lilycove and Goldenrod.
- **Evolution items** on one shelf at the Celadon and Lilycove department stores and in Mahogany.
- **Move relearner** in the summary screen, including TM moves.
- **Tutors and in-game trades** can pick a Pokémon from the PC.
- **PC boxes** can sort items, page with L and R, and set a default box.
- **Bag** holds 60 item stacks and 99 key items.
- **Chansey attendants** in Pokémon Centers.
- **One clock** for all three regions.

## Not in this game

| Missing | Why |
|---|---|
| Gen 4 to 9 Pokémon families | Compiled out. |
| Primal Reversion, Z-Moves, Dynamax, Terastallization | Dynamax and Tera are compiled out. The orbs and Z-Crystals are not placed. |
| Link play: trading, link battles, Union Room, record mixing, Mystery Gift, wireless minigames | Removed. Pokémon Center second floors are sealed. |
| Sevii Trainer Tower, Mossdeep Game Corner, Two Island game corner | Closed. |
| Sound and Battle Scene options | Fixed to stereo with animations on. |
| NPC partner followers, berry mutations and mulch, Defog and Rock Climb in the field | Turned off in `include/config/`. |

The field-move tool items (Cut Tool to Dive Tool) are supported by the engine but no one in the
game gives them out.

## For developers

- **Build.** `make modern` with devkitARM. The build is modern-toolchain only. `make RELEASE=1`
  strips the debug menu.
- **Debug menu.** Hold R and press START in the overworld.
- **Config.** Feature toggles are in `include/config/`.

| Command | Covers |
|---|---|
| `make validate` | 44 host-side checks with no build: the Gen 1 to 3 rule, evolution routes, map events, warps, scripts, text width and more. |
| `make check` | The battle-engine test suite. |
| `python3 test/verify.py smoke` or `full` | Builds, then runs startup, travel, save and gameplay checks. |
| `test/overworld/run-all.sh` | The Lua overworld suites on a patched headless mGBA. |
| `test/overworld/johto-playthrough/run.py --campaign world` | A full three-region playthrough on one save. |

Everything not described here is inherited from pokeemerald-expansion: the modern battle engine
with the physical and special split, the Fairy type, later-generation moves, abilities and items,
and its testing tools.
