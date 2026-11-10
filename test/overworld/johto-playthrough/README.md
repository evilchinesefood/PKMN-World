# Johto playthrough — fresh save to the Hall of Fame

A continuous Johto campaign played by controller input under the patched `mgba-headless`, from
the new-game hub to the Hall of Fame. Earlier Johto work (`../johto-progression/`) played the
opening naturally and then warped into each later scene with its prerequisites set by hand.
This harness plays every story beat in order on one save. Each beat starts from the state the
previous beat left: Elm's lab, the Farfetch'd chase, the Radio Tower quiz, the Ecruteak Gym
pits, the Lighthouse floors, Chuck's boulders, the Rocket Hideout passwords and Murkrow, Pryce's
ice, the Underground switches, and the rest.

## Run it

```sh
make modern -j8
python3 test/overworld/johto-playthrough/run.py                  # the whole campaign
python3 test/overworld/johto-playthrough/run.py --from pryce     # resume after a beat
python3 test/overworld/johto-playthrough/run.py --suite kurt_fast_ball.lua
```

The same runner plays Hoenn with `--campaign hoenn`; see `../hoenn-playthrough/README.md`.

`run.py` regenerates symbols, constants, struct offsets and map ids from the ELF being tested
(`export.py`), then runs `play.lua`. Every beat ends with a savestate checkpoint in `--out`
(default `_pwtest/johto-play/`), so a failing beat can be fixed and resumed with `--from`
without replaying the campaign. The evidence run is the one without `--from`.

## How it plays

- `nav.lua` reads the live map and presses buttons. It reads collision, elevation, metatile
  behaviour, objects, warps, connections and coord triggers. It does breadth-first pathfinding
  that models ledges, ice slides, surfing, waterfalls, directional walls and unspawned objects.
  It routes across maps from the ROM's map headers, and handles internal warps such as holes
  and floor-to-floor arrows. It advances dialogue, answers Yes/No and multichoice prompts by
  reading the message text, and drives battles through the battle controller.
- `beats.lua` lists the story beats, each with a completion predicate on the story vars and
  flags it is meant to write. A beat fails when its predicate is false.
- Battles are fought for real. Wild battles started by a script (Sudowoodo, the red Gyarados,
  the Electrodes, Ho-Oh) are fought; random encounters are fled.

### Concessions (what is not natural play)

- **Party.** A Lv100 Mewtwo and Rayquaza are added through the debug Give menu on arrival in
  Johto. Their met level is then lowered to 5 so Gen 8+ obedience lets them act. The menu's
  numeric field is written directly, not dialled in. The real starter (Chikorita), the Togepi
  Egg and every gift are still received normally. Rayquaza and Chikorita are the Surf/Strength/
  Waterfall/Fly and Cut learners the field moves require.
- **Healing.** HP and PP are restored with the debug menu's Heal Party after each trainer
  battle, instead of walking to a Pokémon Center.
- Everything else is walking, talking and battling through the game's own scripts.

## Losing on purpose

`PW_LOSE=beat[:kind],...` loses the first matching battle of each named beat, checks the player ends
up in control in the right region with the party healed, then plays the beat again. `kind` is
`trainer` (default), `wild`, `any`, or a `TRAINER_` constant to single out one opponent. The faint
is forced: the party is fainted behind the lead, which drops to 1 HP knowing only Growl. Everything
after the faint is the game's own code. `kind` can also be a `SPECIES_` constant for one wild
Pokémon. A beat can pass a fourth argument with `check` (the story state a loss should leave),
`replayFrom` (restart from an earlier beat, for league rooms) or `replay` (what is left to do).
Otherwise the replay walks back, using the debug warp where the planner has no route. In partner
battles both sides go down. `evidence/early-losses.log` holds the early losses of all three regions
and `evidence/unusual-losses.log` holds the league, partner, double and scripted ones.

## Result (October 31, 2026)

One uninterrupted run, from a fresh hub save to the Johto Hall of Fame, on ROM
`6434B3C6074481A1E07D50CB64FC2193` (branch `fix/johto-full-playthrough`, all fixes below applied):

- **83/83 checks:** the fresh-save check and all 82 beats. No beat retried, no state edited
  beyond the two concessions above.
- **Play:** 9,718 steps, 139 trainer battles, 118 wild encounters. Every gym leader, the Elite
  Four and Lance were beaten, plus Ho-Oh at Tin Tower (GOLD at Baoba's prompt). The game ends at
  home in New Bark with `FLAG_JOHTO_CHAMPION` and `FLAG_SYS_GAME_CLEAR` set.
- **Evidence:** [`evidence/final-run-beats.log`](evidence/final-run-beats.log) has each beat,
  checkpoint, trainer battle and the final totals, and there are screenshots from the run.

On the same ROM, `test/overworld/run-all.sh` is 54/54 green. The #357 runners also pass:
`johto-progression/run.py` 7/7 and `run_audit.py` 12/12.

## Post-game

`PW_POSTGAME=1` keeps playing past the Hall of Fame, with beats from `postgame.lua`. Without the
variable the campaign is unchanged. The beats play on from the champion save: all eight gym rematches
on the HARD tier (shards, one stone per leader, a second rematch paying no second stone), the
Hall of Fame respawns, Mt. Silver and Red (the first win plays the Hall of Fame, the rematch does not),
Route 25's Suicune, the Route 47 tower, and two more Elite Four runs.

Additional concessions, each logged by the beat that uses it: Master Balls are placed first in the
balls pocket for the catches, Route 25 is reached by debug warp, and the roaming beasts are moved to
the player's map so a hunt finishes. `VAR_AZALEA_TOWN_STATE` is set to 8 for the Celebi chain, because
the Unown puzzle is a screen the harness cannot drive. Everything after that value is played.

One uninterrupted run from a fresh hub save on ROM `E5F8155004D0811C1F0EE160B90F784D` passed 125/125
checks in 23,449 steps, with 1 retry (`pg_second_to_league`). The retry reloads a checkpoint, which
also clears the planner's remembered maps. [`evidence/postgame-final-run.log`](evidence/postgame-final-run.log)
has each beat.

## Natural difficulty (`PW_NATURAL=1`)

`PW_NATURAL=1` plays a region with a team caught in that region instead of the debug pair. The
hooks in `nav.lua` do nothing without it, so default campaigns are unchanged. `natural.lua` holds
the behaviour and `natural_regions.lua` holds each region's gyms, ace levels, grind allowances and
catches.

```sh
PW_NATURAL=1 python3 test/overworld/johto-playthrough/run.py --out _pwtest/nat/johto
PW_NATURAL=1 PW_STARTER=1 python3 test/overworld/johto-playthrough/run.py --campaign kanto --out _pwtest/nat/kanto
PW_NATURAL=1 python3 test/overworld/johto-playthrough/run.py --campaign hoenn --out _pwtest/nat/hoenn
```

The mode sets Exp. Share on and Hard Mode off by writing the save, and Exp stays at 1x. It:

- scores moves from `gMovesInfo` and `gTypeEffectivenessTable`, checked against known moves at startup
- switches when the active Pokemon has no move that can hurt the foe
- heals at Centers, on the way between maps and before each beat when the team is hurt
- buys Potions at Marts and uses them in battle and, where no Center is reachable, from the Bag
- accepts a level-up move that beats the weakest known move
- treats a whiteout as a loss: it grinds in grass and plays the beat again, up to six retries

Teams are Chikorita, Mareep, Wooper (Johto); Squirtle, Rattata, Geodude (Kanto); Torchic, Mudkip,
Electrike (Hoenn). A Togepi Egg and gift Pokemon stay in the party but are not counted as team.

### Results (November 10, 2026, ROM `F39A844A41F84F6B92AD030836D9D84F`)

Logs are `evidence/natural-johto.log`, `natural-kanto.log` and `natural-hoenn.log`. Limits are the
plan's: enter at ace minus 3, win in 2 attempts, at most 1,000 grind steps (2,000 at Koga, Tate and
Liza, and the Champion). The team level is average (min to max).

| Region | Reached | Result | Steps |
| --- | --- | --- | --- |
| Johto | Hall of Fame | 84/84 | 29,501 |
| Kanto | Lorelei beaten, stopped at Bruno after the retry limit | 8 badges, League not finished | 19,276 to Victory Road, then 12,494 |
| Hoenn | Reached Drake on one run, gave up after the retry limit | 8 badges, League not finished | see the log |

| Johto gym | Level | Ace | Attempts | Grind |
| --- | --- | --- | --- | --- |
| Falkner | 10 (9-11) | 11 | 4 | 1,071 |
| Bugsy | 22 (20-23) | 16 | 1 | 0 |
| Whitney | 23 (22-25) | 21 | 1 | 0 |
| Morty | 27 (26-28) | 25 | 3 | 374 |
| Chuck | 32 (32-34) | 31 | 1 | 0 |
| Jasmine | 35 (33-37) | 36 | 4 | 1,389 |
| Pryce | 44 (43-47) | 38 | 1 | 0 |
| Clair | 53 (51-56) | 45 | 1 | 0 |

| Kanto gym | Level | Ace | Attempts | Grind |
| --- | --- | --- | --- | --- |
| Brock | 11 (10-12) | 14 | 1 | 283 |
| Misty | 20 (18-22) | 21 | 1 | 0 |
| Surge | 23 (21-25) | 24 | 1 | 0 |
| Erika | 34 (33-35) | 29 | 3 | 937 |
| Koga | 40 (40-41) | 43 | 1 | 170 |
| Sabrina | 43 (36-47) | 43 | 1 | 0 |
| Blaine | 44 (38-48) | 47 | 1 | 0 |
| Giovanni | 47 (41-50) | 50 | 1 | 71 |

| Hoenn gym | Level | Ace | Attempts | Grind |
| --- | --- | --- | --- | --- |
| Roxanne | 12 (11-13) | 15 | 4 | 1,269 |
| Brawly | 19 (19-20) | 19 | 1 | 0 |
| Wattson | 21 (15-24) | 24 | 1 | 102 |
| Flannery | 26 (22-29) | 29 | 1 | 0 |
| Norman | 28 (24-31) | 31 | 5 | 9,250 |
| Winona | 36 (32-39) | 33 | 1 | 0 |
| Tate and Liza | 42 (39-45) | 42 | 1 | 0 |
| Juan | 47 (45-50) | 46 | 4 | 0 |

The bot only attacks, switches on immunity and drinks Potions, so a human will do better. Kanto and
Hoenn were resumed from checkpoints after harness fixes and bought no Potions, so their League
stops are not clean difficulty results. Johto's final run predates the last Mart changes.

### Game bug found

A text printer still linked when the heap reset hung the return to the field at `src/malloc.c:97`.
The fix is in `src/load_save.c`; `text_printer_heap.lua` scores 4/5 without it and 5/5 with it.

## Bugs found and fixed

Each one was found in play, confirmed against the source, fixed, and re-played.

1. **Cianwood was a one-way trip.** Route 40's water-arrow row warps the player to Route 41
   (37..45,12). Nothing led back. Route 41 row 11 and Route 40 row 61 were ocean tiles with the
   collision bit set, an invisible wall on both sides of the strait. The return warps on Route 41
   sit on plain ocean, which never fires a warp. Fly unlocks only at Jasmine's badge, and Jasmine
   needs the Secret Potion from Cianwood. Any player without Teleport who sailed to Cianwood was
   stuck there. Clearing the collision on those 18 open-water cells restores the two-way sea, as
   in GSC/HGSS; the arrow warps still carry players south. `../lua/Route41SeaReturn.lua` covers it.
2. **A Pidgeotto sealed the Ice Path.** Route 44's Ice Path door can be entered only from
   (68,13), and a scenery Pidgeotto that never moves stood on that tile. The only land route to
   Blackthorn, and so to the eighth badge, was shut. It had been moved there when the static
   overworld Pokémon were moved out of walls; its upstream tile is inside the cliff. It now stands
   at (69,13), beside the approach rather than on it. `../lua/IcePathDoor.lua` covers it.
3. **Kurt's Fast Ball could lock the game.** After the Slowpoke Well, Kurt's gift was an ON_FRAME
   script keyed only on the story state. If the POKé BALLS pocket was full (16 ball types and no
   Fast Ball), the gift failed, the state stayed put, and the script fired again on the next
   frame. The player saw "take it", then "The BAG is full", forever, and could never open the
   Bag to make room. A long-time player carrying many ball types could hit it. The gift now runs
   once per entry to the house: a full bag gives control back, and the gift is offered again on
   the next visit. `kurt_fast_ball.lua` covers it.
4. **The Hall of Fame brought back a bird nobody could reach.** The first clear offers the bird the
   player did not pick. On a GOLD save a Tentacruel stayed on (35,86), the only tile below the Lugia
   chamber door, and beating it does not move it. On a SILVER save the sage kept the Tin Tower shut,
   because the Clear Bell never comes. Upstream cleared both at Pewter's Gramps, a scene that was not
   ported, so `JohtoHoF_RespawnLugia` and `JohtoHoF_RespawnHoOh` now do it. `pg_lugia_ko` fails at the
   door without the fix. `../lua/JohtoHofUnchosenBirdReach.lua` is 3/5 without it and 5/5 with it, and
   covers the SILVER branch the campaign does not play.

## Not bugs, recorded so nobody chases them again

- Every rematch Hall of Fame puts Route 36's Sudowoodo back on the road. Upstream does the same, and
  the Squirtbottle clears it again.
- `MtSilver_1F_MoltresRoom` has no `B_OUTCOME_PLAYER_TELEPORTED` guard, unlike the other legendaries,
  but Teleport swaps party members in this build, so the outcome did not come up when it was forced.

- The Radio Tower quiz's question 3 ("KURT … uses apricorns as ingredients?") wants **No**. That
  is wrong by GSC canon, but in this game Kurt says "I make BALLS from BERRIES", and Whitney's line
  after the quiz ("I thought the answer to the third question was surely apricorns!") confirms it.
  An earlier commit on this branch changed the answer to YES on canon grounds; it was reverted.

- The Tin Tower guard sage returns to his template tile on paper, but `ON_TRANSITION` moves him
  aside again with `setobjectxyperm` once the Clear Bell has been shown.
- An ambient Pidgey wanders on the Burned Tower's one-tile-wide steps and can stand in the way
  for a while. It always moves on.
- Overworld wild encounters sometimes leave the script context waiting after
  `InteractWithOverworldWildEncounter` fails to start a battle. The player's controls are
  unlocked, so nothing is stuck.
