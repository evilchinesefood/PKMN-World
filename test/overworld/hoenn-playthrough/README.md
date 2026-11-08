# Hoenn playthrough: fresh save to the Hall of Fame

A continuous Hoenn campaign played by controller input under the patched `mgba-headless`, from
the new-game hub to the Hall of Fame. It runs on the Johto playthrough harness
(`../johto-playthrough/`): the same planner, dialogue and battle driver, checkpoints and retry
rule. This directory holds the Hoenn beats and the pieces only Hoenn needs.

## Run it

```sh
make modern -j8
python3 test/overworld/johto-playthrough/run.py --campaign hoenn                # the whole story
python3 test/overworld/johto-playthrough/run.py --campaign hoenn --from winona  # resume after a beat
```

Checkpoints go to `_pwtest/hoenn-play/` by default (`--out` changes it). A game fix that moves
code makes older checkpoints crash on load, so after one, run the campaign from the start.

## Files

- `beats.lua` lists the 84 story beats, from the hub to walking downstairs at home after the Hall
  of Fame. Each beat has a completion predicate on the story vars and flags it writes, following
  `docs/story-progress/hoenn.md`. It also holds the Hoenn-only drivers: the POKéNAV Match Call
  tutorial, a savestate search over the Mauville Gym switches, the Lavaridge Gym holes, the
  Fortree Gym rotating gates, the Petalburg Gym doors, Strength pushes, and Juan's ice floor.
- `water.lua` adds Dive and emerge, and lets `N.travel` plan routes through underwater maps.
- `probe_dive.lua` proves the Dive routes into Seafloor Cavern and Sootopolis. It uses debug
  warps and badges, because it tests the swimming, not the story.
- `mapinfo.py <Map>` prints a map's objects with local ids, coord triggers, bg events and warps.

## Concessions (what is not natural play)

The same two as Johto. After the starter is chosen on Route 101, a Lv100 Mewtwo and Rayquaza are
added through the debug Give menu, with met level lowered to 5 so Gen 8+ obedience lets them act.
Mewtwo leads; the starter stays in the party. HP and PP are restored with the debug menu's Heal
Party after battles. Everything else is walking, talking and battling through the game's scripts.

## Result (November 8, 2026)

Four uninterrupted runs from fresh saves to the Hall of Fame and back home, all on ROM
`A27070BD1DC7DF76BD0FCABE2A16DA03`, each with no crash screen, hang or retried beat:

| Run | Variation | Checks | Steps | Trainer | Wild |
| --- | --- | --- | --- | --- | --- |
| `base` | boy, Torchic, clock pinned to the default | 85/85 | 10,922 | 159 | 152 |
| `alt` | different clock and RNG | 85/85 | 10,913 | 157 | 143 |
| `g1` | girl, Torchic | 85/85 | 10,937 | 157 | 167 |
| `briney` | Hub Pass detour after sailing to Dewford | 86/86 | 11,008 | 157 | 155 |

`evidence/final-run-beats.log` is the `base` run. The other nine combinations of clock, gender
and starter tried on the earlier build also reached the Hall of Fame, apart from the two runs that
hit the evolution freeze below. A run is deterministic for a given build and clock.

Vary a run with `PW_RTC=<epoch>`, `PW_GENDER=F`, `PW_STARTER=0|2` and `PW_DETOUR=briney|stern`.

## Bugs found and fixed

Each one was reproduced first, then fixed and re-played.

1. **The game froze on a "?" sprite during evolution.** If a Pokemon evolved, wanted a move with
   four already known, and the player said yes, the scene never recovered. It hit two of eleven
   runs. `StopShadowAnimDelayTask` (`src/pokemon.c`) trusted a task id that is zero at power-on,
   so the first summary or party screen destroyed task slot 0, which here was the evolution
   itself. It now checks the task is live and still its own.
2. **Using the Hub Pass with Mr. Briney docked at Dewford, before Surf, ended the story.** The
   gate lands at Slateport and nothing reachable from there leads back to Dewford, so Brawly, and
   every badge after him, were out of reach. The Slateport gate now brings him to Route 109, and
   he offers Dewford from there.
3. **Capt. Stern took Devon Parts the player never had.** Arriving at Slateport through the gate
   and talking to Dock cleared the Aqua grunts from the museum door. Dock now only mutters until
   the parts are in the bag, so the grunts stay and Stern stays out of reach.
4. **Earlier runs, kept for the record.** A crash screen on Route 116 when all 16 object slots
   were full (`ba14668cc8`). A crash screen when a wandering Pokemon touched the player during a
   Strength push (`db227a714c`). Reads past the object event array (`481598c4ad`).

Fixed by reading, not played: the Johto PokeGear set `FLAG_REGISTER_RIVAL_POKENAV`, which only
Route 104 reads, so a Johto-first player skipped the Hoenn rival's Match Call registration.

## Not bugs, recorded so nobody chases them again

- Losing the Space Center double battle with Steven has no `waitstate` after
  `special SetCB2WhiteOut`. A forced loss whites out home normally and leaves Steven's victory
  flags unset, so it was left alone.
- `shove` retries in Seafloor Cavern and Victory Road come from a wild battle starting during
  the push. They pass on retry.
- Mr. Briney paces a loop in his cottage, and the POKéNAV tutorial accepts only MATCH CALL, then
  only SWITCH OFF. Both are vanilla; the harness drives them.

## Found by reading, not fixed here

Both are cross-region and cannot happen in a Hoenn-only run.

- `VAR_STARTER_MON` is one variable for all three regions. A starter picked later in Johto or
  Kanto changes which team the Hoenn rival uses (`Route119/scripts.inc`, `LilycoveCity/scripts.inc`).
- `data/maps/GoldenrodCity/scripts.inc:22` clears `FLAG_RECEIVED_BIKE`, the flag Mauville's bike
  shop also checks, so a Johto visit lets Rydel give the bike again.
