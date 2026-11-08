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

The Sevii Islands are not played: Bill's invitation after Blaine is optional. The main story
never requires them, so the run declines and stays on the mainland.

`PW_STARTER=0|1|2` picks Bulbasaur, Squirtle or Charmander (their lab balls in that order). Squirtle
and the two legendaries cannot learn Cut, so a Squirtle run catches a Rattata on Route 1 before
Cut is needed. Vary a run with `PW_GENDER=F`, `PW_STARTER`, and `PW_RTC=<epoch>`.

## Result

Fresh saves to the Hall of Fame and back home, on ROM `87CCBDAA63124D60B512244777C6296D` (built
from `cf348aca43`). None had a crash screen, a hang or a retried beat:

| Run | Variation | Checks | Steps | Trainer | Wild |
| --- | --- | --- | --- | --- | --- |
| `base` | boy, Bulbasaur, default clock | 56/56 | 8,857 | 129 | 102 |
| `girl` | `PW_GENDER=F`, Bulbasaur | 56/56 | 8,834 | 129 | 101 |
| `squirtle` | `PW_STARTER=1`, with the Rattata catch | 57/57 | 8,830 | 129 | 97 |
| `charmander` | `PW_STARTER=2` | 56/56 | 8,840 | 130 | 94 |
| `alt` | `PW_RTC=1760000000` | 56/56 | 8,845 | 129 | 81 |

`evidence/final-run-beats.log` is the `base` run, and `evidence/KantoPlay_55_home.png` is its last
frame: the player back in control inside the house at Pallet Town.

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

## Not bugs, recorded so nobody chases them again

- Route 23's `ON_TRANSITION` resets the Victory Road switch vars, so predicates there read
  position, not `VAR_MAP_SCENE_VICTORY_ROAD_*`.
- Victory Road's boulders on 3F (`(33,18)`) and 2F (`(33,19)`) are hidden until Route 23 and the
  hole respectively show them; `N.object` finds them only once they exist.
