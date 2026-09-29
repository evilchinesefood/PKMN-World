# Quest log decision — no implementation

**Recommendation: a lightweight per-region objective reminder.** Let the player
see the next story step in each campaign plus a short list of the optional chains
currently started. A full journal with hundreds of errands is not justified by the
current structure. This pass does not enable or build either system.

## What is actually present

`include/config/quests.h` disables `QUEST_MENU` and `OW_QUEST_BRANCHING`.
The 30 entries in `include/complex_quests.h` are demonstration placeholders, not
30 playable quests. No live script grants `FLAG_SYS_QUEST_MENU_GET`. Therefore
there are **zero authored formal quest-log entries**, across all three regions.
That is different from having no quests in the narrative.

There is no canonical quest registry from which to count every story scene,
optional favor, item gift and repeatable activity. For a useful comparison, this
inventory groups multi-stage stories into chains and excludes ordinary trainers,
item pickups, single-dialogue gifts and repeatable activities. It identifies
**26 named story chains plus 27 badge/league milestones = 53 major objectives**,
before optional legendary, facility and hub reward chains. This is an explicit
minimum inventory, not an exhaustive claim about every quest in the game.

| Region | Main milestones | Named chains counted here | Representative source |
|---|---:|---|---|
| Kanto | 8 gyms + league = 9 | 9: Oak's parcel; Bill's restoration/ticket; S.S. Anne Cut; Rocket Hideout/Silph Scope; Pokémon Tower/Fuji/flute; Safari Surf/Gold Teeth/Strength; Silph Co; Lostelle; Celio Ruby/Sapphire | `ViridianCity_Mart_Frlg`, `Route25_SeaCottage_Frlg`, `SSAnne_CaptainsOffice_Frlg`, `RocketHideout_B4F_Frlg`, `PokemonTower_7F_Frlg`, `FuchsiaCity_WardensHouse_Frlg`, `SilphCo_11F_Frlg`, `ThreeIsland_BerryForest_Frlg`, `OneIsland_PokemonCenter_1F_Frlg` scripts |
| Johto | 8 gyms + league = 9 | 9: Mr. Pokémon's egg; Sprout Tower; Slowpoke Well/Kurt; Ilex Farfetch'd/Cut; Sudowoodo; Jasmine's medicine; Lake of Rage/Mahogany HQ; Radio Tower; Dragon's Den | `Route30_MrPokemonsHouse`, `SproutTower_3F`, `SlowpokeWell_B1F`, `IlexForest`, `Route36`, `CianwoodShop`, `MahoganyHideout_B2F`, `GoldenrodCity_RadioTower_5F`, `DragonsDen_Shrine` scripts |
| Hoenn | 8 gyms + league = 9 | 8: Birch rescue; Devon letter/goods deliveries; Meteor Falls/Mt. Chimney; Weather Institute; Mt. Pyre; villain hideouts; Seafloor Cavern; Sootopolis/Rayquaza resolution | `Route101`, `RustboroCity_DevonCorp_3F`, `MtChimney`, `Route119_WeatherInstitute_2F`, `MtPyre_Summit`, `AquaHideout_B1F`, `SeafloorCavern_Room9`, `SootopolisCity` scripts |

These source files contain dialogue, flags/vars and event branches rather than
mission records. The inventory intentionally groups linked objectives; splitting
Devon's errands or Celio's two gems would produce a different total.

Optional content increases the memory burden: GS Ball/Celebi, Tohjo Celebi, Red,
Ruins of Alph, Bug-Catching Contest, legendary encounters, Sevii/event-ticket
travel, Battle Frontier, Battle Net progression and the World Championship.
The hub adds badge, championship and caught-species reward ladders.

## How the game explains progress

NPC conversations and scripted scenes give directions; story flags and variables
hold progress; badge/HM gates narrow where the player can go. The Town Map and
regional Fly points explain geography. The trainer card has three regional badge
pages. The hub's World Tour board reports badges out of 24, and its reward staff
explain their own milestones and ticket requirements. These are useful progress
summaries, but none gives a persistent next-story-step reminder for all regions.

A single campaign is mostly linear and familiar. The difficulty comes from being
allowed to leave it, spend hours in another campaign, and return with a shared
bag full of plot items. A player can forget the recipient of a delivery, the
current villain sequence, or which region's next badge gate is active. Optional
chains span distant maps and can outlive long pauses.

## Decision boundary

Choose **lightweight** if you want region hopping to remain comfortable after
long breaks. Track only started chains and one next objective per region; derive
it from existing flags/vars and suppress spoilers. Do not revive the unused
30-placeholder quest system as a shortcut: it has no authored content and its
old save fields were deliberately collapsed. A full journal becomes worthwhile
only if future development adds many simultaneous branching quests. No log is
acceptable for players who stay in one region at a time, but it leaves the
cross-region forgetting problem unresolved.
