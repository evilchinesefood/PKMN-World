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

## Result (October 31, 2026)

One uninterrupted run, from a fresh hub save to the Hall of Fame and back home, on ROM
`AF8DEF850A0CA001501E96C0C080DAE1` (branch `test/hoenn-playthrough`, both fixes below applied):

- **85/85 checks:** the fresh-save check and all 84 beats. No beat retried, no state edited beyond
  the two concessions above.
- **Play:** 10,941 steps, 159 trainer battles, 152 wild encounters. All eight gym leaders, the
  Elite Four and Champion Wallace were beaten. Kyogre was woken at Seafloor Cavern and Rayquaza at
  Sky Pillar. The game ends under player control in the bedroom after the Hall of Fame's soft
  reset, with `FLAG_HOENN_CHAMPION` set.
- **Evidence:** [`evidence/final-run-beats.log`](evidence/final-run-beats.log) has each beat and
  trainer battle and the final totals. A second run from scratch gave identical totals.

After the planner changes this campaign needed, the Johto campaign still passes 83/83 with its
recorded totals.

## Bugs found and fixed

Each one was found in play, confirmed against the source, fixed, and re-played.

1. **A crash screen on Route 116.** Walking toward Rusturf Tunnel, the game stopped on "could
   not spawn generated overworld encounter. too many object events exist". Route 116 shows 14
   NPCs and wandering Pokémon; with the player and the follower that fills all 16 object slots.
   The failed spawn was checked with `assertf` (`src/wild_encounter_ow.c:319`), which stops a
   non-release build before its own recovery runs. It is now a plain check: the spawn is skipped
   and retried later (`ba14668cc8`).
2. **A crash screen after a Strength push.** In Magma Hideout 1F, a wandering overworld Pokémon
   that touched the player while a boulder was still moving started its encounter script.
   `PushBoulder_End` then unlocked the controls mid-script, the next frame reset
   `VAR_LAST_TALKED` to 0, and the script stopped on "species was not found for specified object.
   localid: 0" (`src/wild_encounter_ow.c:805`). Encounter contact is now ignored while the field
   controls are locked (`db227a714c`). A probe that pushed at 150 frame offsets crashed 19 times
   before the fix and never after.

## Not bugs, recorded so nobody chases them again

- Losing the Space Center double battle with Steven has no `waitstate` after
  `special SetCB2WhiteOut`. A forced loss whites out home normally and leaves Steven's victory
  flags unset, so it was left alone.
- Mr. Briney paces a loop in his cottage, and the POKéNAV tutorial accepts only MATCH CALL, then
  only SWITCH OFF. Both are vanilla; the harness drives them.

## Found by reading, not fixed here

Both are cross-region and cannot happen in a Hoenn-only run.

- `VAR_STARTER_MON` is one variable for all three regions. A starter picked later in Johto or
  Kanto changes which team the Hoenn rival uses (`Route119/scripts.inc`, `LilycoveCity/scripts.inc`).
- `data/maps/GoldenrodCity/scripts.inc:22` clears `FLAG_RECEIVED_BIKE`, the flag Mauville's bike
  shop also checks, so a Johto visit lets Rydel give the bike again.
