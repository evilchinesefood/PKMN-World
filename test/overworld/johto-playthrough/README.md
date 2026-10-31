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
python3 test/overworld/johto-playthrough/run.py --suite radio_quiz.lua
```

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

## Result (October 31, 2026)

One uninterrupted run, from a fresh hub save to the Johto Hall of Fame, on ROM
`FD6A7E3409CDEC44A493B418A8386AEC` (branch `fix/johto-full-playthrough`, all fixes below applied):

- **83/83 checks:** the fresh-save check and all 82 beats. No beat retried, no state edited
  beyond the two concessions above.
- **Play:** 9,718 steps, 139 trainer battles, 118 wild encounters. Every gym leader, the Elite
  Four and Lance were beaten, plus Ho-Oh at Tin Tower (GOLD at Baoba's prompt). The game ends at
  home in New Bark with `FLAG_JOHTO_CHAMPION` and `FLAG_SYS_GAME_CLEAR` set.
- **Evidence:** [`evidence/final-run-beats.log`](evidence/final-run-beats.log) has each beat,
  checkpoint, trainer battle and the final totals, and there are screenshots from the run.

On the same ROM, `test/overworld/run-all.sh` is 54/54 green. The #357 runners also pass:
`johto-progression/run.py` 7/7 and `run_audit.py` 12/12.

## Bugs found and fixed

Each one was found in play, confirmed against the source, fixed, and re-played.

1. **The Radio Tower quiz rejected the truthful answer.** The quiz is the only way past the
   Beauty blocking Whitney's Gym door. Question 3 asks whether Kurt makes his POKé BALLs from
   apricorns, and the script accepted only NO. That answer was left over from GSC, whose
   question was different, when HnS rewrote the question; upstream HnS has the same bug. A
   player who answered truthfully failed every attempt. `radio_quiz.lua` covers it.
2. **Cianwood was a one-way trip.** Route 40's water-arrow row warps the player to Route 41
   (37..45,12). Nothing led back. Route 41 row 11 and Route 40 row 61 were ocean tiles with the
   collision bit set, an invisible wall on both sides of the strait. The return warps on Route 41
   sit on plain ocean, which never fires a warp. Fly unlocks only at Jasmine's badge, and Jasmine
   needs the Secret Potion from Cianwood. Any player without Teleport who sailed to Cianwood was
   stuck there. Clearing the collision on those 18 open-water cells restores the two-way sea, as
   in GSC/HGSS; the arrow warps still carry players south. `../lua/Route41SeaReturn.lua` covers it.
3. **A Pidgeotto sealed the Ice Path.** Route 44's Ice Path door can be entered only from
   (68,13), and a scenery Pidgeotto that never moves stood on that tile. The only land route to
   Blackthorn, and so to the eighth badge, was shut. It had been moved there when the static
   overworld Pokémon were moved out of walls; its upstream tile is inside the cliff. It now stands
   in the dead-end nook at (64,13). `../lua/IcePathDoor.lua` covers it.
4. **Kurt's Fast Ball could lock the game.** After the Slowpoke Well, Kurt's gift was an ON_FRAME
   script keyed only on the story state. If the POKé BALLS pocket was full (16 ball types and no
   Fast Ball), the gift failed, the state stayed put, and the script fired again on the next
   frame. The player saw "take it", then "The BAG is full", forever, and could never open the
   Bag to make room. A long-time player carrying many ball types could hit it. The gift now runs
   once per entry to the house: a full bag gives control back, and the gift is offered again on
   the next visit. `kurt_fast_ball.lua` covers it.

## Not bugs, recorded so nobody chases them again

- The Tin Tower guard sage returns to his template tile on paper, but `ON_TRANSITION` moves him
  aside again with `setobjectxyperm` once the Clear Bell has been shown.
- An ambient Pidgey wanders on the Burned Tower's one-tile-wide steps and can stand in the way
  for a while. It always moves on.
- Overworld wild encounters sometimes leave the script context waiting after
  `InteractWithOverworldWildEncounter` fails to start a battle. The player's controls are
  unlocked, so nothing is stuck.
