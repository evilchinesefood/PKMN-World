# Pokémon World — Changelog

All notable player-facing changes. For the full feature reference see
[FEATURES.md](FEATURES.md); for credits see [CREDITS.md](CREDITS.md).

## Unreleased

_Nothing yet._

## v1.5 — 2026-08-24

> **Save format is now v9** (from v1.4's v7). v1.4 saves migrate forward
> automatically on load — v8 for the reworked Pokémon Center 1F layouts, v9
> for the Johto work below. Saves from v1.3.6 or earlier are still refused —
> and the game now *says so* at the main menu instead of showing a blank
> NEW-GAME-only screen.
>
> **v9** (#51) gives Johto's own trainers their own defeat flags, renumbers
> the maps left behind by deleting two dead day/night duplicates, and
> re-points two wrong Johto heal coordinates. It applies itself on load, but
> two consequences are worth knowing if you are mid-playthrough:
>
> - Every Johto trainer that was given a new id reads as **undefeated**, so
>   they can be fought again. That is the intended outcome, not a loss of
>   progress: until now each of them shared one defeat flag *and one party*
>   with a Hoenn or Kanto trainer, so the trainer you beat mostly wasn't the
>   one standing there.
> - Fly is corrected for everyone immediately (it reads the game's table),
>   but **Teleport and whiteouts** use the heal coordinate stored in your
>   save. Violet City's and Route 32's are migrated for you; the three that
>   moved off Pokémon Center door tiles (Azalea, Goldenrod, Safari Zone Gate)
>   are not, so heal at that Center once to pick up the new spot.

### World & systems

- **SHARED EXP now shares evenly, and the EXP phase is quiet.** Two changes that
  belong together, because the first makes the second necessary.

  The share was never even. Gen 6+ rules give anyone who was *sent out* the whole
  pot and anyone who was not exactly half of it — a hard 2:1 ratio, which is why
  the Pokémon that fought always visibly out-earned the rest of the party no
  matter what you did. The new `B_EXP_SHARE_DIVISOR` makes the base equal.
  Level-difference weighting still applies per Pokémon, so an under-levelled
  party member still gains a bit more and an over-levelled one a bit less —
  equal input, not identical output. **Party EXP intake rises a lot**; the
  **EXP RATE** option (0.5×) is the intended way to tune it back without a
  rebuild.

  With everyone levelling constantly, the old ceremony became unbearable: each
  level-up cost three button presses (`STRINGID_PKMNGREWTOLV`, then both pages
  of the stat box) plus an ~80-frame stall nothing could skip, because that
  message ends in `{WAIT_SE}` and waits out the whole `MUS_LEVEL_UP` fanfare —
  about **20 presses and 8 seconds for one knockout** with a full party. Level-ups
  are now silent during the fight, the EXP-gain lines are gone (the EXP bar
  already showed the number), and a single **"Your team grew stronger!"** box
  after the battle lists everyone that levelled with their start and end levels.
  The Pokémon on the field still gets its level-up sparkle and its healthbox
  level ticking up, so the fight still reads. **Move learning is untouched** — it
  runs at exactly the same point it always did, so nothing can silently fail to
  learn a move — and EVs, evolutions and the level maths are all unchanged.

- **Link-era features compiled out** (#59): Mystery Gift, Mystery Event,
  Wonder News, the e-Reader, the Union Room, wireless chat, record mixing,
  and the Cable Club link rooms are removed from the build. The two save
  fields the removal freed are reserved (part of the v8 bump). Trade-only
  evolutions were already item-based, so no species is stranded.
- **Battle Net terminals moved to the lobby** (#59/#60): the regional
  terminal is now a wall unit beside the PC in all 50 Pokémon Center
  lobbies; the Center 2Fs (old link floors) are sealed off.
- **Quest system removed**: the dormant quest engine is compiled out
  (~26 KB reclaimed). It never had content; its save space is reserved.
- **The S.S. Aqua sails to Kanto** (#65): the voyage now ends where it was
  always meant to. Step off in the new **Vermilion City port terminal**,
  walk out onto the harbor, and you are in Kanto with your team — Johto and
  Kanto are one continuous journey, so nothing is boxed. The Vermilion pier
  sailor sells the return crossing to Olivine, and it is offered whether or
  not you have touched Kanto's own S.S. Anne story. Earlier builds announced
  the arrival and then turned the ship around; before that, the finished
  voyage had no exit at all.
- **Olivine harbor opens up**: once you have crossed to Kanto, the Olivine
  sailor's destination board goes live — Vermilion, plus the event-ticket
  runs (Battle Frontier, Southern Island, Birth Island, Faraway Island),
  which were unreachable from Johto until now. Sail to an event island from
  Olivine and its sailor brings you **back to Olivine**; book the same trip
  at Lilycove and you come home to Lilycove, exactly as before. The Birth
  Island run also landed you inside a wall; it now docks at the island's
  harbor like Lilycove's, and the tickets check the same unlock flag
  Lilycove checks rather than the ticket alone. *(The Battle Frontier row
  turned out to have no check at all — see the next entry.)*
- **Boarding a ferry no longer blue-screens**: every sailing from the
  Olivine harbor — including the maiden voyage the post-league story sends
  you on — ended its script while the warp was still in flight, tripping
  the engine's "leaving script while a warp is in progress" assert. Same
  fix for the Johto Hall of Fame entrance.
- **Battle Frontier ferry fixes the world**: sailing from the Frontier dock
  to Slateport/Lilycove now correctly makes Hoenn your active region.
  Before, your previous region's difficulty, obedience rules, and Battle
  Net payouts followed you into mainland Hoenn. Coming home from any
  event island to the Lilycove harbor now does the same, which matters now
  that those islands can be reached from Johto.
- **Johto Hall of Fame respawn fix**: re-clearing the Johto league no
  longer re-arms an already-caught Mew or Deoxys as a farmable duplicate.
- **The Battle Frontier ferry at Olivine wants a ticket** (#79): its row on
  the harbor board was the only one of the six with no credential check at
  all, so the Frontier was a free ride for anyone who could open the menu.
  It now asks for the **S.S. TICKET**, in the same shape the three island
  rows ask for theirs. Nobody who reached the board legitimately is short
  one — the maiden voyage that opens the board already demanded the ticket,
  and the ticket can't be tossed or sold. It is deliberately *not* also
  gated on a game-clear flag: that flag is Hoenn's, and a Johto champion
  never sets it, so copying the Hoenn-side attendant would have shut the row
  for exactly the players it exists for.
- **Vermilion's port terminal is a building you can walk back into** (#68):
  the arrival hall was one visit long. Its city-side warp sat on an ordinary
  plank with no warp tile under it, so the terminal had no door, the pier
  had no building behind it, and the crossing back to Olivine had to be
  duplicated onto a sailor standing outside. There's a real terminal on the
  pier deck now, and the berth desk inside is the one place the S.S. Aqua
  sails from — gated so a first-run Kanto player who has never heard of the
  ship can't wander in and take what is a one-way trip to Johto.
- **Kenya arrives with her mail — and can actually be handed over** (#66):
  the Route 31 gift SPEAROW came with no letter, and "hand her to the
  sleeping man" was a stub that never removed her, so you kept Kenya *and*
  collected TM41 Torment. She now carries a real RetroMail written by her
  original trainer, the sleeper really takes her, and four refusal lines
  that were written but unreachable (wrong mail, no mail, that's your last
  Pokémon, you declined) work. The same stub served Cianwood's SHUCKIE
  quest, which could close with SHUCKIE still in your party. Route 31 also
  checks for bag room *before* taking her, because TM41 could otherwise be
  swallowed by a full bag with no second chance.
- **The Red Gyarados is red** (#66): the Lake of Rage encounter is built
  entirely on the Gyarados being the wrong colour, and it was an ordinary
  blue one — in the battle and on the map. Both halves are shiny now, and it
  stays shiny once caught. The Dragon's Den elder's DRATINI is shiny too,
  on the perfect-quiz branch.
- **Jessie and James are on the way to Proton** (#89): their Slowpoke Well
  ambush stood down a south-western branch that the 45-step route to the
  boss never touches, so a playthrough could reach Proton without ever
  meeting them. They now hold the corridor on the last stretch before the
  drop south, with a free tile on each side so the fight starts from
  whichever way you walked up.
- **Azalea Gym's carriers are ARIADOS again** (#89): the gym's twelve
  trigger tiles are a ride along a web line, and the six carriers had been
  left as a generic Lass — a woman escorted you across the gym, while every
  script in the room already named ARIADOS. Their hide flags pointed at
  nothing either, so ~800 lines of visibility bookkeeping were inert (it
  never showed, because the spawn doesn't read those flags). *If you saved
  inside the gym, the old sprites stay until you step out and back in.*

- **Whirlpool works, and Lugia is reachable** (#160). Route 41 and the
  Dragon's Den shipped eight whirlpool sites — a marker ringed by four
  invisible, solid blockers — and every one of the forty objects ran a
  silent do-nothing script. They were permanent walls, not obstacles:
  flagging an object invisible only stops it *drawing*, and at the
  elevation these used it collides at every height. A flood fill of the
  cavern's own collision data puts the damage at 393 sealed tiles. Between
  them they closed all four Whirl Islands entrances — the only way to
  **Lugia** — and the only door to the **Dragon's Den Shrine**.

  Whirlpool is now a real crossing: walk into one with the **Glacier Badge**
  and your Pokémon carries you over. It is deliberately not a party-menu
  field move; it is the obstacle itself that responds, which is how HG/SS
  does it. The whirlpool stays where it is and is re-crossed every time.
  Dragon's Den's two "breakable rocks" were never rocks — they were these,
  wearing the wrong sprite, which is why Rock Smash never did anything to
  them.

- **Wild encounters are flat: every Pokémon is catchable at any hour**
  (#110). Day/night encounter tables are gone by design. The clock still
  changes how the world *looks* and which Pokémon wander the overworld — it
  no longer decides what the grass will give you.

  Two species come back from the dead on the way. **Roselia** existed in
  exactly one slot in the entire game, at 5%, in a table the game never
  read — so Roselia, **Budew** and **Roserade** were all unobtainable.
  Roselia now grows on Route 123 at any hour. Budew needed one more thing:
  its only route is breeding with a **Rose Incense**, and that item was
  never placed anywhere in the world. It is now sold in the Goldenrod
  Department Store, next door to the Day Care it serves.

- **Johto's music pass is finished** (#173). Cycling and surfing play
  Johto's own themes instead of falling through to Hoenn's. Trainers who
  spot you in Johto get HG/SS approach jingles rather than Hoenn ones. The
  Radio Tower plays the Rocket occupation theme while Rocket holds it,
  matching the city outside instead of reverting to the peacetime theme the
  moment you walk in. Lance's prize money was double Blue's for the same
  job; it is now the same.

  One real regression is fixed with it: repointing Johto's map music in the
  previous pass silently killed your **follower's reactions** in every Johto
  mart and in Victory Road, because those lines are keyed to the music id.

- **Followers notice the outdoors.** Grass- and Bug-type followers now have
  something to say about fresh air.

- **The Day Care flowers move.** Route 34's Day Care and the Goldenrod
  Flower Shop shipped flower animation frames that nothing ever played.

### Fixes

- **Johto's doors don't open.** Walking into a building in Azalea Town warped
  you straight in with the door standing shut. `GetDoorGraphics` matches a door
  on its metatile id *and* its tileset **pointer**, and Johto's regional
  recolours — `Johto_South`, `Johto_NorthEast`, `Johto_NorthWest` — keep
  `Johto_General`'s door metatiles while being different tileset objects, so the
  lookup missed and `Task_DoDoorWarp` read the failure as "the animation already
  finished". Nine table rows fix it with no new art: the door metatiles and every
  tile they reference are byte-identical across all four Johto primaries, and the
  palettes those doors draw from are identical too. That is **19 dead door warps**
  — all five in Azalea, plus Ecruteak, Blackthorn, Cianwood, Mahogany, Mt Silver,
  Ruins of Alph, Safari Zone Gate and Route 28 — and it also restores the sliding
  door sound the Poké Center, Mart and Gym doors had been falling through to
  `SE_DOOR` without.
- **The other eighteen doors that never opened** (#92). The same lookup, the
  rest of the way — and it turned out **none** of them needed art drawn. Seven
  more table rows cover six tilesets that borrow another tileset's door
  metatile: **Battle Frontier Outside East** (six warps, on the *West* map's
  metatile ids — the East labels had sat unreferenced since vanilla Emerald),
  **Bellchime Trail**'s Tin Tower entrance, **Dragon's Den**'s shrine door —
  the only way into the shrine, so its single approach was a door that never
  opened — the **Johto Safari Zone**'s entrance hut, **Mahogany Town** and
  **Lake of Rage** (four warps repaired by one row, since they share a
  secondary), and all five **S.S. Aqua** cabin doors. Every one reuses frames
  already in the tree, verified down to the pixel: the borrowed tiles are
  identical, and each door draws through a palette that matches on every index
  its frames touch. *Two small data edits go with them. `safari_zone_johto`
  palette 8 entry 15 was an unused black padding slot and is now Fuchsia's grey,
  which is the colour those borrowed frames draw the door's outline in. And the
  four S.S. Aqua cabins had flat panelling where every other S.S. Anne doorway
  has a door header, so the opening animation — two tiles tall — was painting a
  lintel onto blank wall and wiping it away again; they now carry the same
  header as the rest, which is what they should have looked like shut. Mahogany's
  roof also had to move out of the way: the door animation borrows VRAM tiles
  1016–1023 while it runs, and 20 of that tileset's metatiles drew from 1016/1017
  — one of them directly above each of the four doors — so opening a door wiped
  the roof's ridge detail until it shut. That art now lives lower in the tileset,
  pixel-for-pixel unchanged — as does Goldenrod City's and the dept. store's,
  which had the same collision behind doors that were already animating.* That is **18 dead door
  warps**, and with the 19 above it takes the tree-wide count to **zero** —
  `Testing/ValidateDoorAnims.py` now gates that at zero in `make validate`, the
  pre-push hook and CI.
- **The Pokémon Center heal animation only lit part of the screen** in Johto.
  `CreatePokecenterMonitorSprite` picked the monitor sprite by **region**, but
  which sprite is correct depends on the **tileset**: Johto's Centers are drawn
  with the FRLG counter art (`kanto_pokemon_center/tiles.png` is byte-identical
  to `pokemon_center_frlg/tiles.png`), so they were handed Hoenn's narrower
  24×16 monitor over a 32×16 screen, in the wrong palette, and missed the
  synchronised palette pulse the FRLG art is built around. Now keyed off the
  tileset. **14 maps** are corrected — all 13 Johto Centers and the World Transit
  hub, which is `MAPSEC_DYNAMIC` and so read as Hoenn — and none regress; Trainer
  Tower's lobby is Kanto but uses its own tileset and keeps the wide monitor.

- **Sealed into the Slowpoke Well (critical)** (#89): after Team Rocket is
  beaten, Kurt walks up, says "let's get out of here" — and nothing happens.
  Two faults, and it took both. He was staged on the single tile joining
  Proton's chamber to the rest of the cave, so spawning him dropped a wall
  across the only door; the chamber's other way out is a STRENGTH boulder,
  and there's no HM for it in Azalea. And his line ended without doing
  anything. He now stands where he can't cut the map in two and finishes the
  scene properly, walking you home to Kurt's house. The half that matters
  for anyone already trapped reaches an existing save, because object
  scripts are re-read from the ROM every time you Continue.
- **Losing to the Johto Elite Four dropped you into a void (critical)**
  (#89): the Indigo Plateau Pokémon Center had no respawn point of its own,
  so it fell back to the standard Center default — which on that bespoke
  35×18 map is unpainted floor in a 117-tile pocket that is disjoint from
  the playable area and contains neither a warp nor the nurse. The map is
  indoors, so Escape Rope, Dig, Fly and Teleport are all refused; being
  healed means you can't white out a second time; the only exit is a soft
  reset, and saving there ends the file. The Center is the mandatory route
  to Will, so any loss in the league did it. Respawn is now in front of the
  counter. (New Bark Town's player house had the same defaulted coordinate
  and stood you on the furniture — cosmetic, but fixed with it.)
- **Warps that crash the game you actually play** (#89): a warp not followed
  by a wait lets its script run on while the map is still loading, which
  trips an engine assert and drops you on the crash screen — in the release
  build, not a debug one. The Ruins of Alph and Burned Tower puzzles were
  fixed with save v9; walking every warp in the game then found **22 more**,
  among them both Slowpoke Well cutscenes, the Tin Tower trail, the Ice Path
  puzzle skip, the Indigo Plateau Abra teleport, the S.S. Aqua captain's
  room and three Bug-Catching Contest exits. Fourteen department-store,
  Safari and contest sites had papered over it with a fixed delay, which a
  slow music fade outlives.
- **Johto whiteouts and door-tile landings** (#51, #89): Johto had no
  entries at all in the table that walks you into the Pokémon Center after a
  whiteout, so the game used the raw heal coordinate — and Violet City's sat
  five tiles under the SPROUT TOWER door. All 14 Johto healers are
  registered now, Violet and Route 32 are corrected (and migrated in saves
  that hold the old spot), and Azalea, Goldenrod and the Safari Zone Gate no
  longer land you *on* the Pokémon Center door tile, drawn on top of a
  closed door.
- **Route 32's Lv43 Magneton, and 46 trainers who were someone else**
  (#51, #89): 51 Johto trainer ids were shared with a Hoenn or Kanto
  trainer, and the defeat flag is derived from the id — so each pair shared
  one flag *and one party*. 38 route and dungeon trainers were given their
  own ids and their authentic GSC teams. That sweep didn't cover gym
  interiors; a later one found 8 more, including Azalea's "Bug Catcher
  Benny", who was really Bird Keeper Benny with three Lv36 flying types in a
  gym whose leader tops out at a Lv16 Scyther, and "Bug Catcher Josh", a
  Rock-type Youngster borrowed from Rustboro Gym. What's left is Johto's
  Victory Road (still a parked copy of Hoenn's roster) and the deliberate
  cameos.
- **Team Rocket looked like Team Magma** (#87): every Johto Rocket executive
  was classed as a MAGMA ADMIN — Proton, Petrel and Ariana announced as
  Magma and drawn with an *Aqua* portrait, Archer drawn as Maxie. They're
  Rockets now, and Giovanni is a boss. In the Slowpoke Well, Kurt was a
  giant Wailmer doll and Proton wore a Magma grunt's sprite; and the Kurt
  who turns up after the fight shared a hide flag with the Kurt in Kurt's
  house, so clearing it for the house also spawned a mute duplicate in the
  cave.
- **Two Nurse Joys** (#87): Route 32, Mt. Silver, the Safari Zone Gate and
  Indigo Plateau each had a second nurse standing where the counter Chansey
  belongs — running the Chansey's script — and Cianwood used a static prop
  instead of the Chansey the other twelve Johto Centers use. All five match
  now.
- **Sailing home from an event island** (#69, #80): the island sailors
  decided where to take you by reading your *active region*, which a save
  made before regions were tracked doesn't have — so a Johto player who
  booked at Olivine was landed at Lilycove with no way back that doesn't box
  the party. The harbor you board at is recorded when you board and consumed
  when you get home. Navel Rock was also the last island still warping
  straight to Lilycove regardless of where you came from; it goes through
  the shared way-home script like the other three, which gained a Kanto arm
  as well. Coming home to Olivine now puts you on the berth instead of at
  the terminal's north door.
- **The v9 save migration only half-ran** (#89): the step that renumbers
  saved map ids never reached anything — the game copied the object list out
  of the save 36 lines *before* the migration ran, then wrote the stale
  values straight back over it. A save made in one of the 20 rooms that
  renumbered — Goldenrod's gym, Game Corner, Radio Tower, Pokémon Center,
  flower shop, houses, train station and underground, plus the Mt. Silver
  Pokémon Center, Route 28 and its house — came back with every NPC there
  invisible to scripts, so cutscenes in that room ran with no actors. It
  cleared on the next map change, but Continuing and saving in place made it
  permanent, because the migration never runs twice. Also fixed: the region
  save block's integrity check summed it at the *current* build's width
  against a stamp written at the older, shorter one. Real saves have zeros
  in the extra bytes so it didn't fire in practice, but the next append
  would have made every save report "region save damaged".
- **Battle Frontier saves no longer roll back progress**: the Frontier's
  mid-challenge quick-save wrote only part of the save; Johto story flags,
  Kanto trainer defeats, cut trees, and the Route 5 daycare silently
  reverted to your last full save (a duplication vector). It now writes the
  whole slot.
- **Route 34 daycare egg with a full party**: collecting the egg with six
  Pokémon no longer overwrites (deletes!) your sixth party member — the
  "no room" branch actually runs now.
- **Tohjo Falls**: the Celebi-led encounter gate works — arriving with a
  full-HP Celebi follower now actually arms the event (it never could).
- **Prompt safety**: the intro's permanent Hard Mode choice and the one-way
  HUB PASS warp both rest their cursor on NO, Hard Mode echoes what you
  picked, the outfit pick says it's permanent (and B no longer silently
  commits RED), and the HUB PASS confirm/description say it's one-way.
- **EV/IV Changer**: START also flips the EVs/IVs page (shoulder buttons
  still work).

- **Nine Johto berry trees shared save slots with nine others** (#163).
  Two trees on different routes wrote the same entry in your save, so
  harvesting Azalea's Leppa emptied Route 43's, Route 31's Rawst emptied
  Route 38's, and so on for all nine pairs. Each tree now owns its slot.
  The symptom was invisible until someone harvested, which is exactly how
  it survived the pass that was supposed to have fixed it.

  On an existing save the nine become bare plantable spots rather than
  pre-grown trees. Nothing else changes.

- **185 floating girls and twelve invisible walls removed** (#123). The
  decoration markers left over from the Johto port had been hidden behind a
  flag rather than deleted, so any save made before that flag existed still
  showed all 185 of them standing in the air. They are gone from the map
  data now, so no save can show them.

  The twelve walls were the fix for a previous eyesore: nine stationary
  Rayquaza on the Tin Tower floors and three more in Sprout Tower had been
  made invisible — which stops them drawing but not colliding, leaving an
  invisible wall on the centre tile of every floor. They carried no script
  and no behaviour, so they are deleted outright.

- **Every previously-cut tree and smashed rock regrows once.** The two
  changes above shift entries in the cleared-obstacle table, which is
  bound to your save by a hash. On a mismatch the game clears the bits and
  re-stamps them, so obstacles come back exactly once rather than drifting
  silently out of step. This is the designed behaviour, not a bug.

### Developer & tooling

- **macOS support** (#64): the build, the pre-push gate, and the Lua
  suites all run on macOS.
- **Pokévial off-switch builds again** (#61).
- **A dead-door census** (#92): `Testing/ValidateDoorAnims.py` cross-references
  every warp event in the tree against `sDoorAnimGraphicsTable`, applying
  `GetDoorGraphics`' own two-key rule, and gates the count at zero in `make
  validate`, the pre-push hook and CI. Nothing else catches this class: a door
  with no table row produces no build error, no crash, and still plays a door
  *sound*, so it reads as normal play. Everything it needs is derived from the
  tree rather than assumed — including the trap that the primary metatile count
  is 640 for FRLG/Johto layouts and 512 elsewhere, and that the attribute width
  follows the *tileset*, not the layout (#53). `Testing/lua/DoorAnimsRegistered.lua`
  is its runtime half, evaluating the same condition against the live ROM on
  seventeen maps. A second gate pins the census's own blind spot: 18 warps whose
  behaviour cannot be read *at all*, because three Johto Victory Road floors and
  two other maps paint metatile ids past the end of the tileset actually wired to
  them. That is a separate authoring bug, but an unreadable warp is a hole in the
  count — and a hole makes the dead total go *down* — so its number is pinned
  rather than ignored. A third gate catches the trap that a table row alone is
  not enough: the animation borrows VRAM tiles 1016–1023 while it plays, so any
  tileset drawing from that window has its art wiped for as long as the door is
  open. Four did — Mahogany Town, Battle Frontier Outside East, Goldenrod City
  and the Goldenrod dept. store — and their tiles were moved out of the way.
- **A map-event scanner** (#87, #88, #89): `Testing/ValidateMapEvents.py`,
  wired into `make validate`, the pre-push hook and CI. Run against the tree
  before the fixes above it reports each of them on its own, and it has since
  grown checks for warps missing their wait, heal points on impassable tiles
  or aimed at the wrong building, respawn tiles sealed off from every exit,
  and cutscene actors staged on a tile that cuts a map in two. Every check is
  proven to fail on the unfixed tree before it's trusted. The "mute story
  NPC" smell was triaged rather than baselined: all 61 findings read and all
  61 correct, so the check now excludes scene machinery and errors at zero.
- **A save reader and offline migrator** (#89): `Testing/SavePatch.py` reads
  a save file without booting anything and applies the same migration ladder
  to the bytes, so a save copied to a second device carries the fixed values
  instead of waiting for the next in-game save. Guarded three ways: struct
  offsets re-read from the tree on every run, a no-op round trip that must
  come out byte-identical, and a refusal to touch an incomplete slot.
- **The test harness could report PASS without doing the work** (#86, #89):
  three routes through the Lua runner exited 0 having asserted nothing — and
  one of them left the *previous* run's verdict on disk looking current —
  `boot()` could settle in the wrong map and run its assertions there, and
  the stale-ROM guard failed open off macOS. `Testing/run-all.sh` clears
  every sentinel, runs the battery and demands a fresh pass stamped with the
  ROM under test: 20/20 in about a minute, naming anything it couldn't run
  instead of counting it. Crash screens are now decoded to FILE.C:LINE
  rather than surfacing as "the game stopped responding" (the crash screen's
  *colours* are wrong in this build — read the text, not the palette).
- **New emulator suites**: the Olivine harbor board, the map renumber, and a
  check that the owner's real save still boots. The S.S. Aqua crossing suite
  grew from 38 assertions to 94 — it now starts from a fresh new game and
  drives the maiden-voyage boarding at Olivine, the leg it used to skip.
- **Overworld palettes for shiny followers** (#78): the guard deciding
  whether a species had a usable overworld palette tested a different field
  from the one the code then loaded, so a shiny request could reach the
  loader with a null palette. No shipped species is affected — every entry
  passes both palettes or neither — but shiny overworld sprites are content
  this project now uses, so the mapping lives in one function.
- **Scripted wild battles own their single/double state** (#77): the flag
  that makes a scripted wild battle a double was a sticky file-static that
  nothing cleared. Not reachable as the tree stands, but one Johto script
  edit away from starting a double battle against a one-Pokémon party.
- **Johto's content-stage stubs are recorded as wontfix** (#66): five
  markers promised work in a stage that isn't happening. Each now says what
  it does today and why that's the answer — the Baoba safari quest is
  unreachable dead content (its quest state is never set, and its prompts
  name areas the shipped Fuchsia safari doesn't have), and the `chooseitem`
  macro has had no callers since the Ice Path berry puzzle was reworked.

- **Caught up with upstream pokeemerald-expansion** (#120). This tree was
  further behind than its own version header claimed: it read 1.16.2 while
  actually sitting on upstream master from 2026-06-25, seventeen commits
  *before* 1.16.2 was tagged, with about twenty later PRs replayed on top
  in no particular order. The base was established by matching file
  contents against 133 upstream commits rather than by trusting the header,
  and the tree is now merged up to upstream master of 2026-08-23 — 193
  commits, past their 1.16.3 release. The header now records the exact
  upstream commit and date, so the next reader can diff against a real
  point in history.

  Five of the eight known hazards in that merge produce no conflict marker
  and are wrong by default — a "keep ours" resolution would have silently
  reverted an upstream fix, and one of ours would have printed the wrong
  rival's name in a Kanto tutorial. Each was resolved deliberately. Two new
  battle options that arrived switched on are pinned to preserve current
  behaviour, so changing them stays a visible decision rather than a side
  effect of the merge.

  It also fixes a Lua suite that had been red on master for some time:
  the Johto Victory Road tileset check, which the merge repairs without
  being aimed at it.

- **A test-suite heap bug that reported as eighteen unrelated failures**
  (#120). One dangling free corrupted the heap in a single test-runner
  process, and every test that landed on that process afterwards died
  reporting only "CRASH". The count moved around whenever an unrelated test
  was touched, because that reshuffled which tests were unlucky. The free
  is gone; the test suite is clean.

- **A berry-slot suite that actually discriminates.** The new
  `JohtoBerrySlots` check reads the save's berry-tree bank directly and
  was verified to fail on a build without its fix — 22/22 fixed, 12/22
  unfixed — because a suite that passes either way proves nothing.

## v1.4 — 2026-07-27

The Battle Net release. Mega Evolution finally has a way in, every Pokémon
Center becomes a training ground, and the three-region roster is enforced
everywhere.

> **⚠️ New saves only.** The save format moved to **v7** and saves made in
> v1.3.6 or earlier are **refused at load** rather than migrated. The bag and
> item PC were resized for a three-region game, which reshapes the save layout —
> a legacy save would otherwise *half-load* with silently misaligned flags and
> vars, so it is turned away deliberately. **Start a new game.**

### The Battle Net

- **Battle Net & Mega Evolution**: become any region's Champion and the hub's
  **Battle Net terminal** opens the flagship floor upstairs. The Director hands
  you the **Mega Ring** and a free Mega Stone for your starter's line; every
  **HARD** gym-leader/Elite-Four/Champion rematch win pays **Shards** (leaders 1,
  league 2), and the first HARD win against each of the 28 stone-holding leaders
  drops their **signature Mega Stone** — the same one they now Mega Evolve with
  against you. The flagship vendor sells the remaining stones for Shards, the
  exchange clerk converts Battle Points to Shards (4 BP each), and a few Shards
  are hidden in the world. A full bag holds a stone for reclaim on a later win;
  a blocked Shard payout now tells you and is forfeited, so make room first.
- **Battle Net battle modes & regional terminals**: the flagship's sim pods are
  live. The **Scaling Type Trainer** picks any type and fields 2–4 of it a few
  levels below your party (1 BP a win plus a 30% Shard chance); the **Leader
  Sim** reruns any gym leader's HARD rematch as a simulation for 2 BP — no
  Shards or stones, those stay on the real gym visits; the **Tower Streak**
  chains up to 7 sims (1 BP per win, +5 for a perfect run, best streak on the
  records board); and the **Lv50 / Monotype / Little Cup ruleset rooms** pay
  2 BP a win to a party that matches the rule. Sim battles run under Battle
  Tower rules — no money at stake, no whiteout, party restored around every
  match. A **Battle Net terminal** was also installed in every regional
  Pokémon Center (49 rooms across all three regions) carrying the Scaling
  Type Trainer and Leader Sim. *(Reworked post-release into a 1F wall
  terminal in all 50 lobbies — see Unreleased.)*
- **Battle Net sims pay EXP**: the Scaling Type Trainer, Tower Streak, and
  ruleset rooms now award full experience (and post-battle evolutions) — the
  sims are meant to be the game's training grounds. Money still never changes
  hands in a sim, a loss still can't white you out, and your party is still
  restored around every match.

### World & content

- **Gen 1–3 roster enforced**: every trainer party is swept back to Generations
  1–3 (36 later-gen slots across the endgame teams were rebuilt with type- and
  role-equivalent picks), matching the game's three-region cast.
- **Route trainers were fielding boss teams**: 22 ordinary trainer slots had
  been overwritten with Kanto boss parties — the Bug Catcher in Petalburg Woods
  was Elite Four **Lorelei** at Lv 63–66, and a junior in Rustboro Gym (where
  Roxanne is Lv 12–15) was **Sabrina** at Lv 38–43. All 22 are restored to their
  real teams; the actual Kanto bosses were never affected.
- **Lunatone and Zangoose are catchable**: neither had a single wild slot
  anywhere (a version-exclusive leftover inherited from Emerald) while Solrock
  and Seviper were placed normally. Lunatone now appears through Meteor Falls at
  10–15%, Zangoose on Route 114 at 4% — alongside their counterparts, not
  instead of them.
- **League HARD rematches everywhere**: Johto's Elite Four + Lance and Kanto's
  round-two Elite Four + Champion now field HARD-difficulty teams once you're
  that region's Champion (Johto Lv 70–78 with Lance's Dragonite at 78; Kanto
  E4 Lv 70–76, Champion Lv 77–80 per starter) — completing the set Hoenn's
  league started. First clears are untouched, and trainers without a HARD
  team keep fighting their normal one.
- **Team Rocket — Jessie & James**: five one-time 1-vs-2 duo ambushes at Mt. Moon,
  the Rocket Hideout, the Slowpoke Well, the Goldenrod Radio Tower, and Route 118,
  and Team Rocket joins the World Championship Dome bracket (replacing Clair).
- **Johto portraits**: native HGSS-style battle portraits for all eight Johto
  gym leaders, the Elite Four, and Champion Lance — no more borrowed
  Kanto/Hoenn faces.
- **Violet City trade**: the classic Bellsprout ↔ Onix trade is live — bring
  Rudy a Bellsprout and ROCKY the Onix is yours.
- **Orange Islands**: Kanto's Sevii Islands are renamed the Orange Islands
  throughout (region map, ferry menu, Rainbow Pass, and island scripts).
- **Rival is Gary** in both Kanto and Johto (region-derived), replacing Blue/Silver.

### Bag, storage & quality of life

- **A three-region bag**: Items **30 → 60**, Key Items **30 → 99**, and the item
  PC **50 → 150**. Paid for by dropping Mystery Gift and the Mystery Event
  buffers — neither is reachable in a fan project that never links to a
  distribution server — so the MYSTERY GIFT entry is gone from the title screen.
  This is the change that breaks old saves; see the note at the top.
- **Cut trees and smashed rocks stay cleared**: only the 104 most recently
  cleared obstacles were remembered and the world holds 297, so past that point
  new clears silently stopped persisting — mid-playthrough, not at completion.
  Every obstacle now has its own permanent slot.
- **Hub Pass**: a key item that warps you one-way back to the World Transit hub
  from the bag anytime (blocked inside the Safari Zone, Bug-Catching Contest,
  Battle Frontier facilities, and link rooms). You're handed one automatically on
  your first trip out of the hub, and the Charm Curator still stocks a
  replacement.
- **EV/IV Changer**: the Curator's 24-badge capstone now tunes IVs too (it was
  EVs only). Use it on a party POKéMON and press R to flip between the EV and
  IV pages; Left/Right nudge the selected stat by 1, holding moves in steps
  of 10. EVs stay capped at the legal 252 per stat / 510 total, IVs at 0-31,
  and stats recalculate live. Owners of the old EV Changer keep it; the item
  simply gained its new name and powers.
- Also fixed from the EV-only version: using the item from the bag now actually
  opens the editor (the bag used to bounce straight back), and the editor
  window draws fully opaque (it was invisible, then see-through).
- **PC quality-of-life**: a **SORT ITEMS** action in the PC item storage; a
  **Make Default** box option so new catches land in a chosen box; and L/R now
  page storage boxes under every button mode.
- **Endgame credits removed**: after the Hall of Fame the game saves and returns
  to the title; Continue drops you into the overworld post-game state (Johto
  champions resume in New Bark Town, Kanto in Pallet, Hoenn in Littleroot).

### Fixes

- **The Johto League could be locked shut for good (critical)**: a full bag
  during the Ecruteak theater scene swallowed the **Clear Bell** without a word,
  and the Tin Tower sage checks for it — with no second copy anywhere, the
  league gate could never open. Thirteen one-time gives (the bells, the Rainbow
  and Silver Wings, gym TMs, the Lake of Rage Red Scale) now check for room
  *before* anything advances, and the Radio Tower director will re-hand a lost
  wing.
- **Stranded outside the hub**: a region gate let you through even when the Hub
  Pass couldn't be handed over (full Key Items pocket) — and Johto's only other
  way out is gated behind the Radio Tower. The gate now refuses the trip and
  tells you why.
- **Party corruption at the Bug-Catching Contest**: the party count wasn't
  recalculated at five places that edit your party directly. The National Park
  gate warps straight into the contest, leaving the count too high with the
  other five slots blank — and autosave could write that to your file.
- **Hard Mode caps follow the region you're in**: level caps and obedience read
  your *active* campaign's badges, and the champion tier is per region. Before,
  clearing one region lifted the cap everywhere, and the hub counted as Hoenn —
  which zeroed Battle Net sim EXP for Hard Mode players partway through Johto.
- **Battles with an empty party**: fishing, Rock Smash and overworld encounters
  could start a wild battle with no Pokémon at all right after a region switch.
- **The Leader Sim paid prize money**: it doesn't now — "no money at stake" is
  true of every sim.
- **Battle Net Director**: talking to him again announced a Mega Ring you were
  already holding. The ring is marked given the moment it's handed over; the
  free starter stone stays claimable.
- **Hub Pass inside the Frontier**: using it mid-run in the Tower, Dome,
  Factory, Arena or Palace warped you out without ending the challenge. Those
  runs are covered now.
- **Steven's HARD rematch** is Lv 78–82 — it had been sitting *below* his
  normal-difficulty superboss team (Lv 75–78).
- **Ice Path TM**: TM14 Blizzard is obtainable again (a dead item-choice stub
  blocked the exchange, and the berry could be lost to it).
- **Day Care** cost and level readouts no longer underflow for a Pokémon above
  your current level cap.
- **Illegal moves**: six moves their species can't legally learn were swapped
  for equivalents in the HARD boss teams.
- **Nine FireRed system flags did nothing** (they pointed at a null flag id):
  Kanto's Cycling Road now puts you on your bike, the Orange Islands appear on
  the region map as you unlock them, and the Tanoby Ruins, trainer-card profile
  and help-system states stick.
- **Rival name fix**: Johto rival battles now announce **GARY** in the battle
  intro/defeat strings too (they said SILVER while the dialogue said Gary). The
  very first encounter still shows "???" until he's introduced.
- **Johto starter fix**: starting Johto after Kanto no longer locks the New Bark
  starter balls ("shouldn't touch") — starter choice is now tracked per region.
- **Shop fix**: Soul Dew is no longer sold in department stores (a pricing quirk
  made it free and unlimited).
- **DexNav**: walk or run right up to a hidden Pokémon to trigger it (the
  slow-walk/sneak penalty is gone); an R-press where the registered species can't
  be found keeps the registration instead of wiping it; and a stuck-search glitch
  that flashed a garbage DexNav window is fixed. Cave overworld encounters no
  longer spawn on unreachable floor inside walls.
- **Rock-Smash Tool**: its description overflowed the bag and shop windows.
- **Battle Net odds and ends**: Shard purchases are all-or-nothing, the tower
  streak counter is clamped, the daily BP payout matches what it actually
  awarded, and the Bug-Catching Contest scores Pokémon over 255 HP correctly.
- **Crash hardening**: bounds checks across the Bag's PokéVial icon, the sliding
  block puzzles, EV items, script commands and the AI's switch fallback — and
  the region save block (badges, per-region flags) is now checksummed and
  repaired on load instead of trusted.

## v1.3.6 — 2026-07-13

Mount polish round two.

- **Your follower rides first**: surfing and Sky-Charm flight now mount the
  Pokémon walking with you whenever it can use the move (including the
  party-menu FOLLOW pick); otherwise the first capable team member by party
  order carries you. The pick also stays stable across warps, dives and
  save-continue while surfing.
- **Fly shadow**: normal walking-shadow size — the oversized slab is gone —
  and it hides correctly during battle transitions and fog.
- **Surf shadow**: your Pokémon now casts a soft dark shadow on the water
  while you ride it.
- **Pokédex**: the region/SEEN/CAUGHT/TOTAL readout sits snug in its panel
  (3px left, 10px up).
- **Hub**: vendor NPCs repositioned along the north wall; the World Tour
  Board moved up a tile.

## v1.3.5 — 2026-07-12

The eyes-on checklist batch: your four reported bugs plus the intro done right.

- **START menu / save safety**: the saved icon-order block lives in an
  un-checksummed corner of flash; it's now fully validated every time the menu
  opens. A corrupt entry there could crash the game and overwrite neighboring
  save data (Kanto trainer flags) on the first START press after Continue.
- **Trainer Card**: the EVOLVED count moved to the card's stats side (flip the
  card) — on the front it was printing on top of the TIME row, and the
  blinking-colon redraw garbled both.
- **Pokédex**: the region/SEEN/CAUGHT/TOTAL readout sits on a fixed layer now,
  so it can't drift when the list scrolls — that layer mismatch is why two
  position nudges never fixed it.
- **DexNav**: unregistering with R updates the header to "R TO REGISTER!"
  immediately — no more stale "Search {name}" until you reopen.
- **New game**: the Hard Mode YES/NO box no longer covers the question text.
  The original Oak welcome (Nidoran demo and all) is restored, and the world
  intro — three regions, the hub, the credit line — now lives on the three
  narration pages right before Oak, where it belonged.

## v1.3.4 — 2026-07-12

Riding polish: surfing and Sky-Charm flight now look like actually riding your
Pokémon (modeled on ghoulslash's dynamic_surf_ows).

- **Surf**: you sit IN your Pokémon — its lower body is drawn in front of you,
  tucking your legs in, instead of you perching wholly on top of the sprite.
- **Flight**: the same riding model in all four facings. Gone: the direction
  flip that drew the whole mon over you facing south/east/west, and the bug
  where the rider slipped behind treetops and buildings while the mon stayed
  visible above them.
- **Flight shadow**: exactly one soft ground shadow while airborne (it used to
  double up with the walking shadow over land), and your normal shadow comes
  back the moment you land.
- **Trainer Card**: opening the card no longer blue-screens with a "disabled
  species" error.

## v1.3.3 — 2026-07-12

Deep-review fixes + the QoL backlog's remaining items.

- **World Tour Board readable at last**: the hub "leaderboard" sign sat on a
  walkable tile, so pressing A walked you onto it instead of reading it. Stand
  below it and face up — it now shows your 24-badge world-tour progress.
- **EV Changer** (new): a reusable KEY item from the hub Curator at 24 badges.
  Use it on any party POKéMON to freely raise or lower each stat's EVs (hold R
  to move faster); it will never let you exceed 252 in a stat or 510 total.
- **Trainer Card**: the front now shows your caught count out of the national
  total, plus how many species you own that are evolved forms.
- **Pokédex**: the region SEEN / CAUGHT / TOTAL readout is aligned and legible
  again (each label now sits with its own number).
- **Sky Charm flight**: the wind-gust puff now draws in its correct colors.
- **Hub shops**: tidied — a couple of stray/duplicate department-store items
  and clerks removed.
- **Note**: on saves created before the options rework, Sound and Battle Scene
  keep whatever they were set to (those toggles now live at new-game setup).

## v1.3.2 — 2026-07-12

Public-release polish.

- **Title screen**: the WORLD wordmark sits 4px further right and 8px higher,
  clearing the Pokémon logo cleanly.
- **Docs refreshed for public release**: README (fan-project notice), INSTALL,
  FEATURES (gym-leader rematches section, autosave cadence), and CREDITS —
  now crediting every imported feature branch (followers & day/night lighting
  by aarant, HGSS Pokédex & debug menu by TheXaman, NPC followers/item
  descriptions/saveblock work by ghoulslash, BW map pop-ups by BSBob, dynamic
  multichoice by SBird1337, nature colors by DizzyEggg, bundled pret tools).
- **Battle Frontier verified**: reachable from the World Transit hub as any
  region's Champion (no S.S. Ticket needed), all seven facilities and their
  Pokémon pools confirmed intact.

## v1.3.1 — 2026-07-11

Ten-agent deep review of the whole codebase; every confirmed finding fixed.

### Progression fixes

- **Blackthorn soft-lock (critical)**: becoming Hoenn or Kanto Champion before
  beating Clair no longer locks you out of the Rising Badge — her post-league
  dialogue now keys on the JOHTO championship only.
- **Johto first-clear as an outside champion**: clearing the Johto league after
  already being another region's Champion now correctly runs the first-clear
  sequence (post-game Johto events, S.S. AQUA state, Indigo guards) instead of
  the repeat-clear one.
- **Gym TM can no longer be lost**: if your bag was full when a leader first
  awarded their TM, the re-offer now happens before the champion rematch gate
  in all eight Hoenn gyms (the other regions were already correct).
- **Norman's HARD rematch is permanent**: the vanilla match-call rematch no
  longer permanently replaces his champion rematch offer.

### Fixes

- **Egg-only party**: trainers no longer start a battle when your party is only
  an egg (previously possible after a region switch plus a gift egg).
- **Flight shadow on bridges**: the Sky Charm ground shadow now follows the
  terrain under you instead of vanishing beneath bridges.
- **Old champion saves**: continuing a pre-rematch champion save now applies
  HARD difficulty immediately instead of after the first hub trip.
- Blackthorn's gym guide now finishes his pep talk ("You got this!"), and five
  rematch lines were shortened to fit the message window.

## v1.3.0 — 2026-07-11

### Gym Leader rematches (Feature C)

- **All 24 gym leaders offer unlimited rematches once you're that region's
  Champion** — talk to them in their gym. Every leader fields a new HARD team
  (Lv 58–65, ace ~65, held items, competitive movesets): Steelix Brock,
  Light-Ball Raichu Surge, Scizor Bugsy, Mamoswine Pryce, Kingdra Clair and
  Juan, Slaking Norman, a Solrock+Lunatone double core for Tate & Liza, and
  more.
- Difficulty now follows the region you're in: champion regions fight HARD
  rematch teams, regions you haven't cleared stay normal — so a Hoenn
  champion starting Kanto still faces the classic first-run gyms.

### Fixes

- **Fishing actually works now**: the hidden half-second reaction test after
  "Oh! A bite!" is gone — the bite waits for your A-press, and pressing A
  early during the dots no longer scares it away. One bite, one press, one
  battle.
- **Sky Charm flight**: facing up, you now ride visibly on your Pokémon's
  back; in every other direction the Pokémon correctly overlaps you. A
  ground shadow tracks beneath you for the whole flight.
- **Trainer Card**: region label repositioned next to "BADGES".
- **Autosave** now waits at least 10 minutes between saves.

## v1.2.0 — 2026-07-11

### Kanto polish

- **Map previews are back**: entering Kanto dungeons (Mt. Moon, Viridian
  Forest, Rock Tunnel…) shows FireRed's full-screen area preview — long on
  your first visit, quick on returns. Johto and Hoenn are unaffected, and the
  name popup no longer appears twice.
- **FireRed canon restored**: Professor Oak's name suggestions are FireRed's
  (RED, FIRE…), and Kanto's in-game trades use the FireRed offers (MS. NIDO
  the Nidoran♀, NINA the Nidorina, and the Golduck-for-Lickitung request).

### Slimming (ROM 90.9% → 67.0% full)

- **265 Pokémon families from Gen 4–9 that never appear anywhere in the three
  campaigns are disabled** [now 339 after the later 74-family purge] (~6.75 MiB). Nothing you can catch, evolve, or
  fight is affected — every Gen 1–3 line and all their evolutions remain. The
  National Dex diploma and the hub's completion reward now count only
  obtainable species.
- Gigantamax and Terastal form data removed (nothing here can trigger them);
  the **Mega Evolution system stays** for possible future endgame content.
- **Trainer Tower is closed for renovations** — the Sevii facility was never
  functional in this merge; the Battle Frontier is the endgame facility.
- Engine slimming: GameCube/e-Reader/Berry-fix link-era payloads removed,
  empty trainer-slide tables made sparse, Japanese glyph sets dropped
  (English-only build).

## v1.1.3 — 2026-07-11

### Fixes

- The **Magnet Train** departure now shows an actual magnet train gliding down
  the track (a station clerk had been standing in for the train).
- The **Goldenrod haircut brothers** now offer haircuts again each new day.
- Challenging a trainer with an **empty party** (right after a region switch)
  now gets a polite refusal instead of a broken battle.
- Mt. Silver mountainside Pokémon patrol their full intended ranges.
- Minor gym text cleanups (Olivine, Violet).

## v1.1.2 — 2026-07-10

### Fixes

- **Fishing** reworked to a single reaction — one bite, one prompt.
- The rider now sits properly on the **mount's back** instead of floating
  alongside.
- **Safari Zone** exit and ¥500-continue fixes across all regions.
- **Trainer Card** badge-page label corrected; pages flip with UP/DOWN (or L/R).
- **Chuck** now correctly awards the **Storm Badge**.
- Each region's **Elite Four** fields its own per-region difficulty.
- **Legendary encounters** guard against duplicates, and the **Celebi** event
  can be retried.
- **Gift Pokémon** are no longer lost when your party is full.
- **Johto League** Fly and respawn locations corrected.
- Assorted text fixes (ellipses, stray spaces, dashes) across Johto and the hub.

## v1.1.1 — 2026-07-10

### Fixes

- **Fly** now shows the Pokémon you picked (Sky Charm and HM), not Flygon, and
  the landing no longer plays a second swoop.
- Leaving the **Kanto Safari Zone** returns you to Fuchsia City instead of
  Hoenn's Route 121 entrance.

### Quality of life

- Running out of **Safari Balls** now offers the same ¥500 continue as running
  out of steps (refills 30 balls + steps); declining exits normally.
- The **Pokédex** main page now shows your current region's SEEN/CAUGHT plus a
  TOTAL caught across all regions (replaces the old HOENN/NATIONAL rows).
- The **Trainer Card** also cycles regions with UP/DOWN (L/R still works).
- **Autosave** fires at most every ~2 minutes (was ~1).

## v1.1 — 2026-07-10

### Endgame

- **World Championship** — once you're Champion of all three regions, a registrar
  in the Battle Dome lobby offers a 15-trainer bracket of cross-region champions
  (Red, Blue, Lance, Steven, Wallace, the four Elite Fours, and Sabrina/Clair),
  with Red waiting in the final. Rewards a permanent title and a Gold Bottle Cap,
  and is rematchable afterward.
- The **Battle Frontier** is now gated behind clearing at least one region's
  league.
- **Hoenn's Elite Four and Champion rematch** now fields genuinely upgraded HARD
  teams (Lv 62–68, competitive movesets) once you're Champion — your first clear
  still faces the normal gauntlet.

### Quality of life

- **Fly** and the **Sky Charm** now show your actual flying Pokémon carrying you,
  instead of a generic bird or a fixed Flygon. The Sky Charm mount now renders
  above trees and walls.
- **CATCH RATE** gains a 0.5× tier, matching EXP RATE (now 0.5×/1×/1.5×/2×).
- The **Pokédex** adds a CAUGHT counter (total captures) below SEEN/OWN.
- All **evolution items** (Steel Coat, etc.) are now sold in the department
  stores.
- A new **post-game Dex-reward NPC** in the World Transit hub: 150 caught → PP
  Max, 300 → Master Ball, full National Dex → 10 Rare Candies + a diploma.

### Fixes

- Game Corner coin buying now fills the case to max instead of blocking when
  it's nearly full, and a larger 3rd coin-buy tier was added.
- Celadon's prize-corner Pokémon purchase is fixed (was showing "WEEZING" and
  not giving the Pokémon).

### Engine

- Synced 20 upstream rh-hideout battle/AI fixes.

## v1.0-beta — 2026-07-05

### The Game

**Pokémon World** merges **Kanto**, **Johto**, and **Hoenn** into a single Game
Boy Advance game, built on pokeemerald-expansion. Each region is a complete,
self-contained adventure — its own story, 8 gyms and badges, Elite Four, and
Champion — chosen from a central **World Transit hub**. Your bag, PC boxes, and
Pokédex are shared across all three, so the Pokémon you raise travel with you
between worlds.

### Regions & Campaigns

- **Kanto** — the full FireRed campaign: every trainer fights their authentic
  FireRed team, real gym leader / Elite Four / **Champion Blue** rosters, rival
  **Blue**, and the 8-badge league gate.
- **Johto** — fully ported from *Heart & Soul*: 251 maps, 231 real trainer
  parties, its own wild encounters, town map, Fly and heal locations, rival
  **Silver**, and the Johto League (Will, Koga, Bruno, Karen → **Champion
  Lance**). Post-game: **Red at Mt. Silver**, the roaming beasts, the Celebi
  GS Ball chain, the Ruins of Alph puzzles, the Bug-Catching Contest, and the
  Ho-Oh / Lugia events.
- **Hoenn** — the native Emerald campaign, with the **Battle Frontier** as the
  shared post-game battle facility for all three regions (reachable straight
  from the hub).
- Each region's **starter trio is catchable in the wild** on its first route
  (Route 1, Route 29, Route 101) — the two starters you didn't pick aren't
  lost.

### World Systems

- **World Transit hub** — new games open with a unified intro (gender, name,
  outfit), then land in a terminal with staffed departure gates for Kanto,
  Johto, Hoenn, and the Battle Frontier, plus a nurse, a PC, a mart with
  department vendors, and a world-tour board tracking all 24 badges.
- **Region switching** — your first visit to a region plays a short "Mom moves
  into a new house" arrival and a choice of that region's three starters.
  Switching regions boxes your party to the shared PC (mail is moved to the PC
  mailbox — nothing is lost). You return to the hub through each region's own
  access point — the Goldenrod Magnet Train, Vermilion harbor, or Slateport
  harbor — and once you're champion of two regions, every Pokémon Center 2F
  gains a World Transit warp pad. *(Replaced in v1.4 by the HUB PASS.)*
- **Shared progress** — one bag, one PC, one Pokédex, one wallet. Story,
  badges, and trainer defeats are tracked per region; obedience and HM field
  moves follow your **current** region's badges.
- **Multi-page Trainer Card** — L/R flips between the Hoenn, Kanto, and Johto
  badge pages.
- **Character customization** — play as **Brendan or May** everywhere, with a
  six-outfit color picker (live preview in the intro) that applies globally:
  overworld, battle, and trainer card.

### Major Features

- **Follower Pokémon** — HGSS-style walking followers, plus a "Follow" chooser
  in the party menu so any party member (not just the lead) can walk with you.
- **Overworld flight** — the **Sky Charm** key item toggles free flight over
  the outdoors on a Flygon mount. Granted at the hub after your first badge in
  any region; flying within a region requires that region's Fly badge.
- **Graphical start menu** — a sprite-icon Start menu with entries you can
  rearrange, day/night aware, including a Quests entry.
- **DexNav** — granted with each region's Pokédex; the hidden-Pokémon detector
  unlocks with your first championship. Hidden encounters are authored for
  every land map, skewing rarer and slightly higher-level than the local
  grass.
- **VS Seeker rematches in Kanto** — the VS Seeker now offers rematches from
  85 trainer groups across Kanto, with teams that escalate as you earn badges.
  Hoenn keeps Match Call, and its rematch offers now survive moving between
  areas.
- **Dynamic surf** — you surf on your own Pokémon: the first party member that
  knows Surf appears as your mount.
- **Autosave** — an optional autosave (off by default) that quietly saves as
  you move between areas.
- **Hard Mode & battle options** — Hard Mode (Set-style battles, no bag items
  against trainers, badge-based level caps), an EXP multiplier (0.5×–2×), a
  catch-rate multiplier (1×–2×), and a Run shortcut for fleeing wild battles —
  all in the Options menu, which now scrolls to fit.
- **HGSS-style Pokédex** — the detailed HGSS Pokédex interface.
- **Sword/Shield interface suite** — SwSh-styled party menu, summary screen,
  PC storage, bag, message and name boxes, and map-name pop-ups.
- **Quests** — a mission-log Quest menu on the Start menu. *(Removed — see
  Unreleased.)*
- **Key-item wheel** — ORAS-style SELECT registration for up to four key
  items, one per D-Pad direction.

### Quality of Life

- Battle **type and effectiveness icons** are always shown.
- **Nicknames** — rename Pokémon straight from the party menu or the summary
  screen (outsider Pokémon follow the usual Name Rater rules).
- **PokéVial** — a refillable full-party heal, given as a welcome gift by the
  hub's Charm Curator.
- **Hub distribution** — the Harbor Master hands out the event tickets (Eon
  Ticket, Old Sea Map, Mystic Ticket) as you win championships and opens their
  ferries; the Charm Curator hands out the charms at badge milestones; the hub
  mart stocks a free Town Map.
- The **Wailmer Pail** is available at the Goldenrod flower shop, so Johto
  berry growing can't dead-end.
- **Chansey attendants** beside the nurse in every Pokémon Center, in all
  regions.
- **Safari Zone** — pay ₽500 to keep going when your Safari time runs out.
- **Auto-Run toggle**, reusable TMs, chain fishing, IV/EV pages on the summary
  screen, move relearners (including TM moves), item descriptions on pickup,
  and visible overworld encounters alongside normal grass encounters.
- The wall clock is set **once, globally** — no re-setting it in each region's
  bedroom.

### Fixes

- **Kanto trainer parties** — every trainer in Kanto now fights their real
  FireRed team, with Kanto's trainer progress tracked independently of the
  other regions.
- **Magnet Train** — the Pass is now obtainable (from the station president
  after the Radio Tower incident), so the train actually runs.
- **Key items no longer duplicate** — you can't collect a second Exp. Share or
  HM across regions; the Cianwood double-Fly and the Mystery Egg / Devon
  Letter mix-up are fixed; and formerly placeholder items (Secret Potion,
  Silver Wing, Rainbow Wing) are now real items.
- **PC** — closing the boxes after opening them from the party menu returns
  you to the party menu; the stuck PC message is gone.
- **Textbox alignment sweep** — message windows across the bag, shops, party
  menu, battle tutorial, and more no longer clip against the right edge of the
  Sword/Shield message frame.
- The **Aurora Ticket** event now correctly opens its ferry (fixed
  retroactively for older saves).
- Lavender Town's Pokémon Center upstairs now uses the correct floor layout.
- The summary screen's sheen meter shows empty at zero sheen instead of a
  phantom sparkle.
- Declining "Retire" at the Battle Pyramid now reopens the menu properly.

### Known notes

- The hidden-Pokémon **detector** activates only after your **first
  championship**, and hidden Pokémon never carry held items.
- **VS Seeker** rematch offers don't survive saving and quitting — recharge
  the Seeker after reloading.
- **Saving is blocked while flying** (land first); autosave also skips while
  airborne.
- In Ghost encounters without the Silph Scope, the effectiveness indicator
  stays hidden — that's intended.
- The overworld **debug menu ships enabled** by design in this build.
