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

Fresh saves to the Hall of Fame and back home, on ROM `929D25FED5FFF260666D20064C800A82` (built
from `a5dfa11af9`). None had a crash screen, a hang or a retried beat:

| Run | Variation | Checks | Steps | Trainer | Wild |
| --- | --- | --- | --- | --- | --- |
| `base` | boy, Torchic, default clock | 85/85 | 10,918 | 159 | 156 |
| `alt` | different clock and RNG | 85/85 | 10,913 | 157 | 143 |
| `g1` | girl, Torchic | 85/85 | 10,917 | 155 | 165 |
| `briney` | Hub Pass detour after sailing to Dewford | 86/86 | 11,008 | 157 | 155 |

`evidence/final-run-beats.log` is the `base` run. On the earlier build, eleven runs across clock,
gender and starter ran: nine finished clean or with a harness retry, `g1` froze once and got
past it on retry, and `alt` froze on both attempts.

A fresh run is deterministic for a given build and clock. Resuming from a checkpoint is not: the
restore heals the party, which changes the RNG, so a retry can pass a beat a fresh run fails.

Vary a run with `PW_RTC=<epoch>`, `PW_GENDER=F`, `PW_STARTER=0|2` and
`PW_DETOUR=briney|stern|evolve`.

## Bugs found and fixed

Each one was reproduced first, then fixed and re-played.

1. **The game froze on a "?" sprite during evolution.** If a Pokemon evolved, wanted a move with
   four already known, and the player said yes, the scene never recovered. `StopShadowAnimDelayTask`
   (`src/pokemon.c`) trusted a task id that is zero at power-on, so the first summary or party
   screen destroyed task slot 0, which here was the evolution itself. It now checks the task is
   live and still its own. `PW_DETOUR=evolve` forces the case: a build without the fix stops with
   no tasks and the fixed build finishes. The Mauville Gym freeze was traced directly; the Route
   118 one has the same signature.
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
Route 104 reads, so a Johto-first player skipped the Hoenn rival's Match Call registration. Saves
that already received the PokeGear keep the old behaviour.

## Post-game

`PW_POSTGAME=1` appends beats after `home` from `postgame.lua`; without it the campaign is unchanged.

```sh
PW_POSTGAME=1 python3 test/overworld/johto-playthrough/run.py --campaign hoenn
PW_POSTGAME=1 python3 test/overworld/johto-playthrough/run.py --campaign hoenn --from pg_winona
```

Played, in order: the state `SetGameClearFlags` leaves; all eight gym rematches at the Hard tier
(including the New Mauville quest that brings Wattson back); the Hub Eon Ticket; the S.S. Tidal from
Slateport to Lilycove; Southern Island and its Lati; the Safari Zone expansion and early exit; the
Weather Institute and Terra Cave (Groudon); the roaming Lati; the Mach Bike; Trainer Hill's first two
floors and its prize-full branch; Beldum; Rayquaza; Wally at the Victory Road exit; the Elite Four and
Wallace again; and a second Hall of Fame.

Concessions on top of the campaign's own:

- Terra Cave's location is pinned to Route 118 East; the institute's roll is random and this run's
  roll was a Marine Cave location.
- The roamer is pinned to Route 118 before stepping in grass, because its location is random.
- Tate and Liza's Hard double puts both Lv100s up front and bans Earthquake (it missed their all-Levitate
  team and hit the partner), with up to five attempts if the team still loses.
- Trainer Hill floors 3 and 4 are arrow-tile slides the planner can't walk, so it warps to the roof.
  Every other Hill step is played, including the owner holding the prize until the bag has room. The
  bag is filled by writing free slots directly.
- Sky Pillar is walked to 1F, then warped to the top: the cracked floors need the Mach Bike at speed,
  and the harness has no bike driver. Rayquaza is fought for real.

Not played: Marine Cave (the planner found no water route to the Route 125 pool), Faraway Island
(its Old Sea Map needs two regions' championships, and Mew's hide-and-seek has no driver), and the
Mach Bike ride up Sky Pillar.

Resuming with `--from` starts with an empty map memory, so a resume can report "no route" where a
fresh run does not. Resume from a checkpoint earlier on the same stretch, or play from the start.

The gym leaders' random rematch path is dead code here: each leader's script offers a rematch to any
Hoenn champion before it reaches `ShouldTryRematchBattle`, so `UpdateGymLeaderRematch` has no visible
effect on them (read, not played).

One uninterrupted run from a fresh save through every beat above, on ROM
`36FFF414D347081E9E4DFFD91359E8BA`: 196/196 checks, no retries, 17,113 steps, 184 trainer battles and
223 wild encounters. `evidence/postgame-final-run.log` holds its beats and checks.

### Bug found and fixed

Wattson could never be rematched. He leaves the Gym after Norman and returns only once New Mauville
is finished, and his script tested that finished state before the champion rematch offer, so a
champion always got the post-quest line instead. `data/maps/MauvilleCity_Gym/scripts.inc` now checks
the champion flag first. `evidence/postgame-wattson-before.log` shows the unfixed ROM with no battle;
`evidence/postgame-wattson-after.log` shows the rematch fought at level 59 and its Battle Net reward.

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
