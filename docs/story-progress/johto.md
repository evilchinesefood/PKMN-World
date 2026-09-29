# Johto reminder evidence

The resolver reads the Johto save bank and actual regional badge bits. It does
not write flags, variables, items or the active region. A reminder describes a
known scene or an immediate destination; it does not list future twists. Shared
HM receipts, the Pokédex, `FLAG_SYS_GAME_CLEAR`, foreign badges and held shared
keys do not complete Johto story scenes.

## Opening and Violet

- `data/maps/NewBarkTown_Lab/scripts.inc`: lab state 0 is Elm's introduction;
  1 is choosing a starter; 2/3 is the errand; 4 is the return/police scene;
  5 follows delivery of the Mystery Egg; 6 follows successfully receiving the
  aide's first Poké Balls. `FLAG_JOHTO_ADVENTURE_STARTED` is set at state 5,
  **before** the first-balls gift. State 5 therefore retains the aide reminder
  even when that flag is set. A full bag does not advance to 6.
- `data/maps/Route30_MrPokemonsHouse/scripts.inc`: Mr. Pokémon's completed
  scene sets lab state 4 and Cherrygrove state 2. Neither Mystery Egg ownership
  nor the shared Pokédex flag is used as evidence of this visit.
- `data/maps/SproutTower_3F/scripts.inc` and `data/maps/Route32/scripts.inc`:
  the required tower scene sets `VAR_SPROUT_TOWER = 1` and
  `FLAG_HIDE_SPROUT_TOWER_SILVER`. Route 32 checks that scene, Falkner's defeat
  and the aide's Egg. Sage Li's Flash gift is not the route's tower gate, and
  its shared HM receipt is not Johto completion evidence.
- `data/maps/VioletCity_Gym/scripts.inc` awards badge 1 and sets Violet state 3.
  `data/maps/VioletCity/scripts.inc` supplies the ensuing call; the aide in
  `data/maps/VioletCity_PokemonCenter/scripts.inc` sets `FLAG_RECEIVED_TOGEPI_EGG`.
  The Egg flag is set before the bag-checked Exp. Share gift; `violet-gift`
  keeps that retry visible until the local aide departure flag is set. Shared
  Exp. Share ownership does not complete it. Route 32 state 5 also establishes
  passage beyond those requirements.

The corresponding objectives are `elm`, `starter`, `mr-pokemon`, `return-elm`,
`first-balls`, `sprout`, `falkner`, `violet-egg` and `violet-gift`, prefixed with `johto.`.

## Azalea and Ilex

- `data/maps/AzaleaTown_KurtsHouse/scripts.inc`: Kurt opens the well by setting
  `FLAG_HIDE_AZALEA_TOWN_WELL_ROCKET`. His normal exit sets Azalea state 2;
  the north-facing player movement branch omits that state write, so the flag
  is also checked. Reminder `kurt` becomes `well` on either durable marker.
- `data/maps/SlowpokeWell_B1F/scripts.inc`: the Proton scene and guarded standing
  Kurt recovery both set Azalea state 3. The house's Fast Ball gift then
  advances to 4 only on success. State 3 keeps `kurt-return` on a full bag.
- `data/maps/AzaleaTown_Gym/scripts.inc`: Bugsy awards badge 2 and sets state 5.
  `data/maps/AzaleaTown/scripts.inc`: Silver's exit battle advances to 6.
  These delimit `bugsy` and `azalea-rival`.
- `data/maps/IlexForest/scripts.inc`: Farfetch'd state 0/1 means the rescue is
  unfinished (`ilex`); state 2 means the bird is home but the Cut gift remains
  (`ilex-cut`). Successful delivery sets Farfetch'd state 3 and Azalea state 7.
  State 4 is a subsequent Kimono Girl scene. Shared `FLAG_RECEIVED_HM_CUT` is
  deliberately ignored as completion evidence.

## Goldenrod and Ecruteak

- `data/maps/GoldenrodCity_Gym/scripts.inc`: Whitney's battle sets Goldenrod
  state 3 without awarding the badge; the nearby trainer advances to 4;
  talking to Whitney awards badge 3 and advances to 5. `whitney-badge` preserves
  the exact trainer-then-Whitney action at both 3 and 4.
- `data/maps/GoldenrodCity_FlowerShop/scripts.inc`: the SquirtBottle receipt
  flag is set only after successful delivery. `squirtbottle` leads there after
  badge 3; `sudowoodo` requires both the local receipt and the actual bottle.
- `data/maps/Route36/scripts.inc`: the tree remains after fleeing. Only the
  completed encounter sets `FLAG_HIDE_SUDOWOODO`; item ownership is no clear.
- `data/maps/BurnedTower_1F/scripts.inc` and
  `data/maps/BurnedTower_B1F/scripts.inc`: the basement scene sets
  `FLAG_RELEASED_BEASTS`. `data/maps/EcruteakCity_Gym/scripts.inc` checks that
  flag before Morty's battle. Thus `burned-tower` precedes `morty` while needed.
- `data/maps/EcruteakCity_Theater/scripts.inc`: theater state 1 is the intruder
  scene; 2 is its completion; a successful Surf delivery advances to 3.
  `theater` and `surf` use that local state, never the shared HM receipt.

## Nonlinear western and eastern routes

- `data/maps/CianwoodGym/scripts.inc` awards badge 5 (`chuck`).
- `data/maps/OlivineCity_Lighthouse/scripts.inc`: Jasmine requests medicine at
  Olivine state 3; delivery at state 4 advances to 5 and sets the local
  `FLAG_AMPHAROS_HEALED`. `lighthouse`, `medicine`, `deliver-medicine` and
  `jasmine` use those boundaries. `data/maps/OlivineCity_Gym/scripts.inc`
  awards badge 6.
- `data/maps/CianwoodShop/scripts.inc`: **both pharmacist scripts can set
  state 4 even when the Secret Potion delivery fails**. State 4 without the
  Potion therefore keeps `medicine`, with an explicit make-room/retry reason.
  Potion presence is inspected only inside an established local medicine
  scene; it never establishes healing. Refusing Jasmine's delivery also keeps
  the delivery objective until state 5 or the local healed flag is present.
- `data/maps/LakeOfRage/scripts.inc`: successful red Gyarados/Red Scale scene
  sets Mahogany state 2. A full bag or fleeing does not set it. Lance's first
  conversation sets 3 even when his request is declined; acceptance sets 4.
  Thus `rage` precedes `lance`, and `lance` remains at 2/3.
- `data/maps/MahoganyTown_Shop/scripts.inc`: entering with state 4 reveals the
  stairs and advances to 5 (`shop` then `hideout`).
- `data/maps/MahoganyHideout_B1F/scripts.inc`,
  `data/maps/MahoganyHideout_B3F/scripts.inc`, and
  `data/maps/MahoganyHideout_B2F/scripts.inc`: states 5/6 use the spoiler-free `hideout` exploration lead. Lance reveals
  the two-password lock before writing state 7; states 7/8 use
  `hideout-passwords` until the actual `VAR_ROCKET_PASSWORD = 2` door predicate
  allows `hideout-door`. The revealed Murkrow sequence occupies states 9–11
  (`hideout-murkrow`); state 12 proves the voice-locked gate opened
  (`hideout-room`). No password or bird hint is shown before its saved reveal.
  State 13 is the generator task. `VAR_ELECTRODES_FAINTED = 3` means the player's
  side is done but Lance's Whirlpool gift may still fail (`whirlpool`). Only
  the successful gift tail writes electrode state 4 and Mahogany state 14.
- `data/maps/MahoganyTown_Gym/scripts.inc` awards badge 7 and sets Mahogany 15.
  `data/maps/Mahoganytown/scripts.inc` then calls Elm, sets Goldenrod 6 and
  Mahogany 16 (`pryce`, `radio-call`, then `radio`).

Already active eastern scenes take priority over missing Chuck/Jasmine badges.
An active medicine errand likewise remains visible rather than forcing Chuck
first. Missing actual gym badges are still requested afterward. Later local
milestones can bypass obsolete opening reminders on migrated saves, but cannot
award a badge or mark a currently unresolved final prerequisite complete.

## Radio Tower

`data/maps/GoldenrodCity_RadioTower_5F/scripts.inc` keeps Goldenrod state 6 until
Petrel's Basement Key gift succeeds, even if the battle is already defeated.
`radio` therefore also covers the full-bag retry. States 7/8 use `underground`:
`data/maps/GoldenrodCity_UndergroundTunnel/scripts.inc` requires local state 7
before the shared Basement Key can open the door. Its saved unlocked-door flag
supports reentry, and the Kimono scene advances to 8.

`data/maps/GoldenrodCity_UndergroundSwitches/scripts.inc` sets state 9 after
Silver's battle. `data/maps/GoldenrodCity_UndergroundStorage/scripts.inc` gives
the Director's Card Key without a dedicated local receipt marker. Because Kanto
uses the same item, state 9 deliberately keeps a combined `radio-rescue`
instruction: find the Director, then use his key at the Radio Tower. It does
**not** assert that possession of a Card Key proves a rescue. The third-floor
gate also requires local state 7 in addition to the item.

Tower state 10 proves the final battle is over, but the Director's gift and
departure can remain incomplete (`radio-director`). Only that successful tail
writes Goldenrod 11 and Mahogany 17. Wing ownership and generic hide flags do
not skip the conversation.

## Dragon's Den, final invitation and League

- `data/maps/BlackthornCity_Gym/scripts.inc`: Clair's defeat sets Blackthorn 2
  without awarding badge 8 (`den`).
- `data/maps/DragonsDen_Shrine/scripts.inc`: the Elder's test awards badge 8 and
  sets Blackthorn 3. `data/maps/DragonsDen_Cavern/scripts.inc`: Clair's exit
  encounter advances to 4 (`den-exit`). The city call advances to 5 and lab 7
  (`elm-call`, `elm-gift`). Elm's gift advances lab to 8 and theater to 4 only
  after its bag check succeeds.
- `data/maps/EcruteakCity/scripts.inc` and
  `data/maps/EcruteakCity_Theater/scripts.inc`: theater 4/5/6 is the invited
  Kimono sequence (`kimono`). State 7 and a selected legend's local state 2
  establish their disclosed destination (`whirl-islands` or `tin-tower`).
  `data/maps/WhirlIslands_LugiaChamber/scripts.inc` and
  `data/maps/TinTower_RoofDay/scripts.inc` finish the event at theater 8. They
  do not require a successful catch to finish the main story scene.
- `data/maps/ReceptionGate/scripts.inc`: entry requires **all eight regional
  badges and theater state at least 8**. The resolver's `league` objective
  respects both. An eight-badge migrated save with no final-scene evidence
  gets `league-check`, a conservative Elm/theater check, without inventing an
  invitation or reconstructing unsaved events.
- `data/maps/JohtoIndigoPlateau_PokemonCenter/scripts.inc` sets League state 1
  on entry, including retries after losing (`league-entry`). The Johto League
  Will/Koga/Bruno/Karen room scripts advance to 2/3/4/5 (`league-next`), and
  `data/maps/JohtoPokemonLeague_ChampionsRoom/scripts.inc` advances to 6
  (`hall-of-fame`). Active League evidence outranks stale Den/invitation vars. Theater 7/8 also
  outranks stale lab state 8: the saved disclosed destination or completed
  encounter is stronger evidence than an old invitation. Tests exercise both
  overlaps; the resolver never sends a completed theater scene back to battles.
- `data/maps/JohtoPokemonLeague_HallOfFame/scripts.inc` sets the regional
  Champion flag. Champion status takes priority over unfinished old scenes.
  The available `ss-ticket` lead points to Elm's call/gift; lab 11 proves the
  local gift succeeded and changes to the open-ended `postgame` port lead.
  A shared S.S. Ticket alone does not establish receiving Elm's gift.

## Started optional GS Ball chain

`data/maps/AzaleaTown_KurtsHouse/scripts.inc` starts the saved chain at Azalea
state 8 after Kurt accepts and removes the GS Ball (`gs-kurt`). Neither a hidden
GS Ball item flag nor inventory alone reliably proves that handoff.
`data/maps/AzaleaTown/scripts.inc` returns the ball and advances to 9 only after
successful delivery (`gs-shrine`). `data/maps/IlexForest/scripts.inc` advances
to 10 after the shrine encounter even if Celebi was not caught. Catching sets
the dedicated `FLAG_CAUGHT_CELEBI`, which suppresses the optional lead.

The second Celebi's map-entry script requires state 10, an unset caught flag
and **Johto Champion**, so `celebi-retry` is offered only after that regional
milestone. Before it, `celebi-later` keeps the known incomplete chain visible and
explicitly directs the player to continue toward Johto Champion. No
inaccessible encounter is recommended. Optional GS Ball scenes
never hold up the main reminder.

## Verification

`test/overworld/story-progress/johto_cases.inc` invokes the production resolver
through the host harness. It covers the boundaries above, gift retries, declined
Lance, the shared Flash/Cut/Surf flags, foreign shared keys, actual first-balls
started-flag ordering, east-before-west travel, final theater gating, stale old
scene vars during an active League run, and the optional handoff/catch states.
The shared harness checks that main resolution leaves save state unchanged.
