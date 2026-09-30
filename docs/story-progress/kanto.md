# Kanto reminder evidence

`src/data/story_progress/kanto.inc` reads current state without writing to the save.
Kanto badges are zero-based through `HasBadge(REGION_KANTO, index)`. Story flags
are the rebased `ALL_REGIONS` Kanto bank, and FRLG scene variables use the
Kanto slice in `include/constants/vars_frlg.h`.

The order is a suggested route, not an assertion that Kanto is linear. It first
resolves an unmet prerequisite, then the next Gym/story milestone. Later explicit
completion evidence wins over stale prerequisites in that same chain. Badges
skip stale opening scenes, the CASCADEBADGE skips a missing Mt. Moon fossil
receipt, a calmed tower spirit skips the hideout prerequisites, and Fuji's rescue
skips the tower chain. Silph completion skips tea/gate/card-key recovery, and
Blaine's Badge skips Secret Key recovery. Missing local SURF/STRENGTH gift flags remain pending even if a shared HM item
is present from another region. CUT also accepts its direct successful-receipt
scene and the subsequent ship-departure scenes; it never sends a player to the
now-unavailable captain after departure.

## Main route boundaries

| Objective IDs | Evidence and source |
| --- | --- |
| `starter`, `rival`, `parcel`, `deliver_parcel`, `brock` | `PalletTown_Frlg/scripts.inc` sets lab scene 1 after Oak's route intervention. `PalletTown_ProfessorOaksLab_Frlg/scripts.inc` sets 2 for choosing, 3 after starter/rival selection, 4 after the first battle, and 6 after parcel delivery and Dex scene. `ViridianCity_Mart_Frlg/scripts.inc` sets lab 5 only after parcel receipt. Lab 0–2 means meet Oak/choose, 3 means lab battle, 4 means collect parcel, 5 means deliver. Lab >=6 or a Kanto Badge bypasses the opening. Shared Pokemon/Dex/any-region clear flags do not bypass it. |
| `mt_moon` | BOULDERBADGE from `PewterCity_Gym_Frlg/scripts.inc`; `MtMoon_B2F_Frlg/scripts.inc` sets `FLAG_GOT_FOSSIL_FROM_MT_MOON` only after a fossil successfully enters the bag. Its battle scene 1 alone is insufficient. |
| `bill`, `ticket`, `misty` | `Route25_SeaCottage_Frlg/scripts.inc`: cell separator sets `FLAG_HELPED_BILL_IN_SEA_COTTAGE`; successful ticket gift sets `FLAG_GOT_SS_TICKET`. The helped flag with no ticket is a return-to-Bill objective. `CeruleanCity_Gym_Frlg/scripts.inc` sets Kanto Badge 2. |
| `cut`, `surge` | `SSAnne_CaptainsOffice_Frlg/scripts.inc` sets `FLAG_GOT_HM01` only after successful CUT receipt, then Vermilion scene 1. `SSAnne_Exterior_Frlg/scripts.inc` advances this to scene 2 when the ship departs, and `VermilionCity_Frlg/scripts.inc` advances to scene 3 after walking off the pier. These three specific values prove CUT receipt and prior ship access even if gift/ticket flags are stale; an unrecognized scene 4 does not. `VermilionCity_Gym_Frlg/scripts.inc` sets Kanto Badge 3. CUT field use needs the CASCADEBADGE. |
| `hideout`, `lift_key`, `hideout_boss`, `scope` | `CeladonCity_GameCorner_Frlg/scripts.inc` opens the poster stairs with `FLAG_OPENED_ROCKET_HIDEOUT`. `RocketHideout_B4F_Frlg/scripts.inc` sets `FLAG_CAN_USE_ROCKET_HIDEOUT_LIFT` after successful LIFT KEY pickup. Defeating Giovanni sets `FLAG_HIDE_CELADON_ROCKETS` and **clears** `FLAG_HIDE_SILPH_SCOPE` to reveal the item. The object's normal successful pickup sets its hide flag. Scope collection therefore requires departure **and** the Scope hide flag; the initially hidden Scope alone proves nothing. |
| `tower`, `fuji`, `flute` | `PokemonTower_6F_Frlg/scripts.inc` sets scene 1 only after calming its ghost. `PokemonTower_7F_Frlg/scripts.inc` sets `FLAG_RESCUED_MR_FUJI` when speaking to Fuji. `LavenderTown_VolunteerPokemonHouse_Frlg/scripts.inc` sets `FLAG_GOT_POKE_FLUTE` only after successful gift. No shared item substitutes for these transitions. |
| `erika`, `surf`, `koga` | Kanto Badge 4 in `CeladonCity_Gym_Frlg/scripts.inc`; `SafariZone_SecretHouse_Frlg/scripts.inc` sets `FLAG_GOT_HM03` after successful gift. Kanto Badge 5 in `FuchsiaCity_Gym_Frlg/scripts.inc` permits SURF field use. |
| `teeth`, `strength` | Gold Teeth object in `SafariZone_West_Frlg/map.json` uses `FLAG_HIDE_SAFARI_ZONE_WEST_GOLD_TEETH`. `FuchsiaCity_WardensHouse_Frlg/scripts.inc` checks this pickup evidence, then sets `FLAG_GOT_HM04` and removes the teeth only after successful STRENGTH gift. |
| `tea`, `saffron_gate`, `card_key`, `silph` | `CeladonCity_Condominiums_1F_Frlg/scripts.inc` sets `FLAG_GOT_TEA` after successful gift. `Route7_EastEntrance_Frlg/scripts.inc` and the other Saffron gates set shared **Kanto** gate scene 1 after accepting Tea. `SaffronCity_Frlg/scripts.inc` moves the Silph guard only after Fuji rescue. The 5F Card Key object is `FLAG_HIDE_SILPH_CO_5F_CARD_KEY`. `SilphCo_11F_Frlg/scripts.inc` sets scene 1 and `FLAG_HIDE_SAFFRON_ROCKETS` after defeating Giovanni; either direct completion marker beats stale gate/key variables. Master Ball receipt is an optional reward and never delays Sabrina. |
| `sabrina`, `secret_key`, `blaine` | Kanto Badge 6 in `SaffronCity_Gym_Frlg/scripts.inc`. Secret Key object in `PokemonMansion_B1F_Frlg/map.json` uses `FLAG_HIDE_POKEMON_MANSION_B1F_SECRET_KEY`; `CinnabarIsland_Frlg/scripts.inc` checks it to unlock the Gym. Kanto Badge 7 in `CinnabarIsland_Gym_Frlg/scripts.inc`. |
| `giovanni`, `league`, `champion` | `ViridianCity_Frlg/scripts.inc` opens its Gym after Kanto Badges 2–7. Badge 8 is in `ViridianCity_Gym_Frlg/scripts.inc`. `Route23_Frlg/scripts.inc` performs Badge checks; Victory Road requires local SURF/STRENGTH capabilities. Champion evidence is exclusively `FLAG_KANTO_CHAMPION`, handled before any earlier missing milestone. `PokemonLeague_ChampionsRoom_Frlg/scripts.inc` and Hall of Fame processing establish regional completion. The League objective avoids revealing future opponents. The completed campaign directs players to the World Transit hub's north Frontier attendant, whose any-region Champion gate is documented in `RegionHub/scripts.inc`. |

All paths in the table are under `data/maps/`. Item hide flags are read only for
specific objects whose successful pickup removes the object; they are not generic
world visitation flags. Initial hide flags for future actors/items must never
start a campaign or optional chain.

## Started optional chains

One Island Pokemon Center's scene is intentionally overloaded:

- 0: first meeting not finished; not alone evidence of a started optional quest.
- 1: Bill/Celio meeting finished and island errand pending.
- 2: Meteorite delivered and ready to return to Bill.
- 3: first island visit finished; do not advertise future gemstone tasks.
- 4: Celio explicitly requested Ruby.
- 5: Ruby delivered and second gemstone requested.
- 6/7: Sapphire delivered; chain complete.

`OneIsland_PokemonCenter_1F_Frlg/scripts.inc` owns these transitions. Scene 1 can
be reached with a full bag before Meteorite or Tri-Pass receipt. `sevii_gifts`
uses inventory only to find those missing, required gifts and directs the player
to Celio's retry path. Inventory never establishes completion. Once Lostelle is
rescued, or Meteorite delivery set scene 2, rescue/delivery evidence takes
precedence over those items disappearing from the bag.

| Optional IDs | Evidence and source |
| --- | --- |
| `sevii_gifts`, `sevii_delivery`, `bikers`, `lostelle` | Center scene 1 or explicit Joyful Game Corner/rescue progress starts the chain. `TwoIsland_JoyfulGameCorner_Frlg/scripts.inc` sets Game Corner scene 1 and Three Island scene 2 on the father's request. `ThreeIsland_Frlg/scripts.inc` sets Three Island scene 4 after the biker battles. `ThreeIsland_BerryForest_Frlg/scripts.inc` sets `FLAG_RESCUED_LOSTELLE` and Game Corner scene 2 after rescue, then warps to her father. |
| `meteorite`, `moon_stone`, `return_bill` | Game Corner scene 2/3 or rescue means speak to the father. His Meteorite delivery sets Center scene 2 **before** the reward; Moon Stone bag-full sets `FLAG_NO_ROOM_FOR_JOYFUL_GAME_CORNER_MOON_STONE`. `FLAG_GOT_MOON_STONE_FROM_JOYFUL_GAME_CORNER` is the successful reward boundary. The pending reward is suggested before returning to Bill. Center scene 3 ends this first chain. `FLAG_SEVII_DETOUR_FINISHED` is deliberately ignored: `ThreeIsland_Port_Frlg/scripts.inc` sets it on port entry, before rescue/delivery may be complete. |
| `ruby`, `deliver_ruby` | Center scene 4 starts Celio's gemstone chain. `MtEmber_RubyPath_B3F_Frlg/scripts.inc` contains the B5F Ruby script and sets `FLAG_GOT_RUBY` only after successful gift. Scene 5 means Celio received Ruby, even though its receipt flag persists. The receipt flag therefore must not return the resolver to Ruby delivery once scene 5 is reached. |
| `icefall`, `dotted_hole`, `warehouse`, `deliver_sapphire` | In scene 5, `FourIsland_IcefallCave_Back_Frlg/scripts.inc` sets cave scene 1 after Lorelei's Rocket encounter and removes the scientist blocking Dotted Hole. `SixIsland_DottedHole_SapphireRoom_Frlg/scripts.inc` sets `FLAG_LEARNED_YES_NAH_CHANSEY` only after the theft and password disclosure, exposing the warehouse objective then. `FiveIsland_RocketWarehouse_Frlg/scripts.inc` sets `FLAG_RECOVERED_SAPPHIRE` after Gideon's successful gift. Rocket defeat alone does not mean Sapphire receipt. Center scene 6/7 ends the chain; flags and shared gem inventory cannot override completion. |

WATERFALL is collected within Icefall Cave before reaching its back. Dotted Hole
requires CUT; Ruby path requires STRENGTH. These directions stay within the
already started chain and do not disclose later opponents, plot twists, or
unstarted quests.

## Verification

`test/overworld/story-progress/kanto_cases.inc` drives the production resolver
through every returned objective. It covers failed parcel/fossil/gift transitions,
initially hidden Scope, separate Scope pickup, ship receipt/departure scenes with missing gift/ticket flags, shared global flags, premature Three Island port completion flag, migrated badge
states, tower completion overriding earlier rewards, overloaded Celio scenes,
missed first island gifts, Moon Stone bag-full, persistent Ruby receipt after
delivery, Sapphire gift failure after Rocket defeat, and completed optional chains.

A local native run used `ALL_REGIONS=1` and the MacOSX26 SDK. The default MacOSX27
SDK currently fails native linking with an unsupported `arm64e.x1` TAPI target;
this is an environment issue, not a resolver assertion failure.

## Late HM availability review

A Koga Badge does not prove the Safari SURF gift was received: the Gym can be
completed first. The Secret House attendant remains available and branches only
on `FLAG_GOT_HM03`, offering the gift again when unset. The Warden likewise
remains available after later Badges and offers STRENGTH whenever its local gift
flag is unset and the specific Gold Teeth pickup flag is set. Neither NPC is
removed by later badge progress. Their objectives therefore remain actionable,
and badge-only completion inference is intentionally avoided. CUT differs
because ship departure permanently removes the captain; the direct scene chain
provides the reliable evidence needed to bypass that unavailable reward.
