# Kanto playthrough: fresh save to the Hall of Fame

A continuous Kanto campaign played by controller input under the patched `mgba-headless`, from
the new-game hub to the Hall of Fame and home again. It runs on the Johto playthrough harness
(`../johto-playthrough/`): the same planner, dialogue and battle driver, checkpoints and retry
rule. This directory holds the Kanto beats.

## Run it

```sh
make modern -j15
python3 test/overworld/johto-playthrough/run.py --campaign kanto                # the whole story
python3 test/overworld/johto-playthrough/run.py --campaign kanto --from koga    # resume after a beat
```

Checkpoints go to `_pwtest/kanto-play/` by default (`--out` changes it). A game fix that moves
code makes older checkpoints crash on load, so after one, run the campaign from the start.

## Files

`beats.lua` lists the story beats in order: Oak's lab, the parcel, Brock, Mt. Moon's fossil, Bill
and the S.S. Ticket, Misty, the S.S. Anne, Surge, the Game Corner and Rocket Hideout, Pokemon
Tower and Mr. Fuji, Erika, the Safari Zone's Surf and Gold Teeth, Koga, Strength, Tea, the Saffron
gate, Silph Co., Sabrina, the Pokemon Mansion and Cinnabar Gym, Giovanni, Victory Road and the
Indigo Plateau. Each beat has a completion predicate on the story vars and flags it writes,
following `docs/story-progress/kanto.md`. The only Kanto-specific harness pieces in `beats.lua`
are the Vermilion trash-can switches, the Silph Co. Card Key pads and doors, the Pokemon Mansion
statues, the Victory Road Strength boulder routes (computed outside the game with a Sokoban
search) and, for a Squirtle run, catching a Rattata as the Cut learner.

## Concessions (what is not natural play)

The same two as Johto and Hoenn. After the starter is chosen in Oak's lab, a Lv100 Mewtwo and
Rayquaza are added through the debug Give menu, with met level lowered to 5 so Gen 8+ obedience
lets them act. Mewtwo leads; the starter stays in the party. HP and PP are restored with the debug
menu's Heal Party after battles. Everything else is walking, talking and battling through the
game's scripts.

Bill's Sevii invitation after Blaine is optional and the main story never requires the islands, so
the default run declines and stays on the mainland. `PW_SEVII=1` plays them instead (see below).

`PW_STARTER=0|1|2` picks Bulbasaur, Squirtle or Charmander (their lab balls in that order). Squirtle
and the two legendaries cannot learn Cut, so a Squirtle run catches a Rattata on Route 1 before
Cut is needed. Vary a run with `PW_GENDER=F`, `PW_STARTER` and `PW_RTC=<epoch>`. `PW_DETOUR=starter|ship|empty` plays a
Hub Pass detour. Stop `ship` and `empty` with `--to detour_ship` and `--to detour_empty`, because they
leave the story somewhere the next beat can't continue from.

## Result

Fresh saves to the Hall of Fame and back home, on ROM `1D09FDC4561655E502388A9243FF304A` (built
from `8e06ecfdb9`). None had a crash screen, a hang or a retried beat:

| Run | Variation | Checks | Steps | Trainer | Wild |
| --- | --- | --- | --- | --- | --- |
| `base` | boy, Bulbasaur, default clock | 56/56 | 8,857 | 129 | 102 |
| `girl` | `PW_GENDER=F`, Bulbasaur | 56/56 | 8,834 | 129 | 101 |
| `squirtle` | `PW_STARTER=1`, with the Rattata catch | 57/57 | 8,830 | 129 | 97 |
| `charmander` | `PW_STARTER=2` | 56/56 | 8,840 | 130 | 94 |
| `alt` | `PW_RTC=1760000000` | 56/56 | 8,845 | 129 | 81 |

The Hub Pass detours (`PW_DETOUR=starter|ship|empty`) pass on the same ROM. `evidence/final-run-beats.log` is the `base` run, and `evidence/KantoPlay_55_home.png` is its last
frame: the player back in control inside the house at Pallet Town.

## The Sevii route

`PW_SEVII=1` accepts Bill's invitation and adds two blocks of beats, leaving default runs alone:

- Before the League: the One Island meeting, Two Island's Game Corner, the Three Island bikers,
  Lostelle in Berry Forest, the Meteorite and Moon Stone, and Bill's return to Cinnabar.
- After the `home` beat: the ferry out of Vermilion, Celio's request, Ember Spa, the Mt. Ember
  password guards, the Ruby and the Rainbow Pass, Icefall Cave with Lorelei, the Dotted Hole and
  the theft, the Rocket Warehouse and Gideon, the Sapphire back to Celio, and the ferry home.
  Boulders reset per floor, so Ruby Path has separate push lists for the way in and the way out.

Every island's main town and Pokemon Center is visited at least once.

```sh
PW_SEVII=1 python3 test/overworld/johto-playthrough/run.py --campaign kanto --out _pwtest/sevii-play
```

On ROM `461B450088D5CAD31AD2DA0B4ECF996E` a fresh save reached the end with 81/81 checks in one
uninterrupted run: 11,672 steps, 155 trainer battles, 147 wild battles and no retried beat.
`evidence/sevii-final-run-beats.log` is that run, and `evidence/KantoPlay_81_sevii_ferry_home.png`
is its last frame.

Not played: the Moltres summit of Mt. Ember, Trainer Tower, Cape Brink, Tanoby Ruins, Lost Cave,
Sevault Canyon, Altering Cave, Birth and Navel Rock, and the Waterfall HM on Icefall Cave 1F. The
route only needs Waterfall to be usable, which the Volcano Badge and a party member that can learn
it already give.

## Bugs found and fixed

Each one was reproduced first, then fixed and re-played.

1. **Oak always named the same starter at the end of the game.** The Champion's Room ran
   `specialvar VAR_RESULT, GetStarterPokemon`, but `specialvar` passes no argument, so the function
   read a garbage index, clamped it to 0, and always returned the first species of the Kanto row:
   every player heard "since you first left with Charmander". The Kanto row was also ordered for
   Blue's counter-pick instead of the lab balls. A new `GetPlayerStarterSpecies` special reads
   `VAR_STARTER_MON`, and the row is now Bulbasaur, Squirtle, Charmander, which also corrects the
   starter the credits show. Before the fix a Bulbasaur run heard Charmander; with only the table
   fix, Squirtle and Charmander runs heard Bulbasaur; the runs above name each run's own starter.

2. **The Hub Pass could lose the Kanto starter for good.** Used after Oak says to choose but before
   a ball is taken, the gate returned to the bedroom, past the lab's exit triggers. The Viridian
   Mart scene then handed over the Parcel with an empty party, and all three balls read as taken.
   The gate now returns to the lab while that scene is open. `PW_DETOUR=starter` shows the Parcel
   handed over with no Pokemon before the fix, and the balls still waiting after.
3. **The Vermilion gate landed on the S.S. Anne warp tile.** One Down boarded the ship with no
   ticket, even after it had sailed. The gate now lands north of the ticket check.
   `PW_DETOUR=ship` shows both.

4. **The Dotted Hole door only opened to a Pokemon that knew Cut.** The door opens when Cut is used
   from the party menu, and the party menu lists only moves a Pokemon knows, while
   `QOL_FIELD_MOVES_NO_TEACH` means nobody needs to know it. A Cut-capable party could only read
   the braille. Reading the door now offers Cut. Before the fix the door stayed shut at
   `FLAG_USED_CUT_ON_RUIN_VALLEY_BRAILLE` unset; after it, "Bulbasaur used CUT!" and the warp opens.
5. **Celio asked for the Ruby before the League.** FRLG gated the request on the National Dex, which
   PKMN-World gives with the first Pokedex, so talking to Celio right after meeting him moved his
   scene from 1 to 4 and skipped the Meteorite errand. The gate is now `FLAG_KANTO_CHAMPION`.
   `PW_DETOUR=celio` with `--to detour_celio` shows scene 4 before the fix and scene 1 after.

6. **Touching a visible wild Pokemon with an empty party locked the game for good.** A region
   switch boxes the party, and the encounter script then waited on a battle that
   `BattleSetup_StartWildBattle` refuses to start. The script now releases first. `PW_DETOUR=grass`
   with `--to detour_grass` froze at Route 1 (16,16) before the fix and finishes after it.
7. **Bringing the Meteorite late rewound Celio's story.** A champion can take his Ruby request
   first, and the delivery then forced his scene back to 2. It now only moves him forward.
   `PW_SEVII=1 PW_DETOUR=meteorite` with `--to sevii_meteorite` fails before the fix and passes after.

8. **Losing in the Elite Four froze the game for good.** Indigo Plateau's whiteout named Ever
   Grande's nurse id, which on this map is a clerk parked off screen, so the bow waited forever. It
   now names its own nurse, and `ValidateMapEvents.py` rejects a healer who isn't on the respawn map.
9. **A Kanto Elite Four loss kept the rooms you had already beaten.** A whiteout reset only
   Hoenn's league. It now resets Kanto's too. `PW_LOSE=e4_BrunosRoom` shows Lorelei still beaten
   before the fix and the run restarting at her after it.

## Route 22

`PW_ROUTE22=0|1|2` adds a beat that steps on that row of the rival's trigger, north, middle or south,
each with its own approach. It plays once after Oak's parcel and again after Giovanni, and the early
one checks the north gate turns away a player with no badge. Combined with `PW_STARTER`, all three
early rival teams were fought, and all three rows win and lose early. The late rival was fought on
all three rows and lost on the middle one. The results are on ROM `D309CFD1CB01B8CC40ECF237E52BB6DB`.

## Not bugs, recorded so nobody chases them again

- Coming back without withdrawing the party and walking into the lab's rival trigger does not start
  a battle with nobody. The game stops it with "You don't have a single POKéMON with you!"
  (`PW_DETOUR=empty`).
- Route 23's `ON_TRANSITION` resets the Victory Road switch vars, so predicates there read
  position, not `VAR_MAP_SCENE_VICTORY_ROAD_*`.
- Victory Road's boulders on 3F (`(33,18)`) and 2F (`(33,19)`) are hidden until Route 23 and the
  hole respectively show them; `N.object` finds them only once they exist.
