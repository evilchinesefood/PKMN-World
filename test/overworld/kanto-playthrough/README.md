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

RESULT_TABLE

## Bugs found and fixed

Each one was reproduced first, then fixed and re-played.

1. **Oak named the wrong starter at the end of the game.** `specialvar VAR_RESULT, GetStarterPokemon`
   in the Champion's Room read the Kanto row of `sStarterMon` (`src/starter_choose.c`), which was
   ordered for Blue's counter-pick (Charmander/Bulbasaur/Squirtle), so a player who chose Bulbasaur
   was told "since you first left with Charmander". The row now lists the balls the player picks
   from. Before: `_pwtest/kanto-oak-before.out` (Bulbasaur run, "left with Charmander"). After: the
   evidence run's Champion beat ("left with Bulbasaur").

## Not bugs, recorded so nobody chases them again

- Route 23's `ON_TRANSITION` resets the Victory Road switch vars, so predicates there read
  position, not `VAR_MAP_SCENE_VICTORY_ROAD_*`.
- Victory Road's boulders on 3F (`(33,18)`) and 2F (`(33,19)`) are hidden until Route 23 and the
  hole respectively show them; `N.object` finds them only once they exist.
