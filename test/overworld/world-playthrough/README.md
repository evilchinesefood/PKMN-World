# World playthrough: all three regions on one save

Plays Kanto, Johto and Hoenn on a single save, swapping regions mid-story through the Hub. It runs
the region campaigns' own beats, cut into slices at points the next slice can continue from.

```sh
make modern -j15
PW_WORLD=A python3 test/overworld/johto-playthrough/run.py --campaign world   # Johto first, one slice each
PW_WORLD=B python3 test/overworld/johto-playthrough/run.py --campaign world   # Hoenn first, two slices each
```

Beats are prefixed by region (`j_`, `k_`, `h_`), and crossings are `cross<n>_to_<region>`, so
`--from`, `--to` and `PW_LOSE` take names like `k_to_cerulean`.

Each crossing checks that money and Poke Balls carry over, the party is boxed, the player lands in
the right region, and the whiteout respawn points into that region.

## Concessions

Those of the region campaigns, plus one. A crossing boxes the party, and the player would withdraw
it at a PC. This campaign writes the region's team straight back and removes the boxed copies,
because the storage screen isn't what it tests.

## Result

Fresh saves on ROM `9F0CA532CAD975CBDE18440CB80BA42F`, built from `14aef7643d`:

| Order | Checks | Crossings | Steps | Halls of Fame | Retried beats |
| --- | --- | --- | --- | --- | --- |
| A | 240/240 | 19 | 31,953 | 3 | None |
| B | 232/232 | 10 | 30,801 | 3 | `j_slowpoke_well`, `j_victory_road` |

No game bug came out of these runs. `evidence/order-A.log` and `evidence/order-B.log` list the beats,
and `evidence/seams.log` holds the checks below.

## Other cases played

- A whiteout right after a gate, in each region, lands in that region's start town with the party
  healed.
- The Hub Pass with Elm's starters still on the table: the walk to Route 29 is refused, and the lab
  still hands one over (`PW_DETOUR=opening` in the Johto campaign).
- The Hub Pass before Birch's rescue, which then plays normally (`PW_DETOUR=opening` in Hoenn).
- The Hub Pass right after Falkner lands in Goldenrod, and Azalea is reached from the north by Cut
  (`PW_DETOUR=goldenrod`, stop with `--to detour_goldenrod`).
- Talking to a trainer with an empty party is refused with a message (`PW_DETOUR=trainer` in Kanto,
  stop with `--to detour_trainer`). The check is in the shared trainer script.

## Slice limits, recorded so nobody chases them again

- Mt. Moon can't be walked to from the Vermilion gate with one badge, because Diglett's Cave comes
  out behind a Cut tree. Cerulean can be reached by the Underground Path, and the Dome Fossil is
  optional.
- Lavaridge has no walking route from Slateport, because the way down is the cable car. Hoenn's
  slice ends after the Go Goggles.
- Ice Path isn't planned backward, so Johto's slice runs on past Dragon's Den.

## Post-game

`PW_POSTGAME=1` adds detours after chosen checkpoints. A detour plays its scene, checks the result,
then restores the checkpoint it began from, so the campaign carries on unchanged. `PW_WORLD=J` plays
Johto alone, for a Johto champion who has never been to Kanto. `PW_PG_ONLY=<pattern>` keeps only the
detours whose names match, for iterating with `--from`.

```sh
PW_WORLD=A PW_POSTGAME=1 python3 test/overworld/johto-playthrough/run.py --campaign world
PW_WORLD=J PW_POSTGAME=1 python3 test/overworld/johto-playthrough/run.py --campaign world
```

Each Hall of Fame checks `VAR_DIFFICULTY`, the Hub tickets for that many champions, the Frontier
and World Championship gates, and every gate there and back. After the last Hall, `PW_WORLD=A` plays
Battle Net rematches (a stone with room, a stone with a full bag, then claiming it), the storage
refusal, the Battle Tower from entry to a win, retire and rest-and-resume, and the Exchange Corner
with a full bag. `PW_WORLD=J` plays Elm's ticket, the S.S. Aqua in both directions and obedience by
badges. `PW_WORLD=B` sails from the Frontier with the active region's tier set by a non-champion
region.

Debug setup, used only where it doesn't bypass what is under test: warps to gyms, `VAR_SSAQUA_STATE`
set to 6 aboard (the cabin story is Johto's), the Fly map opened from the debug menu, filled bags and
boxes written to memory, Frontier parties and BP.

Fresh saves on ROM `DC5AD7D7655C46010B72F45E6F071345`: order A 405/405, order J 169/169. Order B was
played fresh to the Hoenn Hall on this ROM, then resumed from `h_home` once the harness fix below was
in, and that resume is 137/137. `evidence/postgame-order-*.log` hold the checks.

One game bug came out of it. Flying from the Battle Frontier to a Hoenn city kept the previous
region active, so difficulty, obedience badges and the whiteout respawn stayed with that region.
`SetFlyDestination` now claims the destination's region, as the Frontier ferry does.
`evidence/fly-before-fix.log` has the failing lines from the ROM without the fix.

## Not covered

`FLAG_ENABLE_PROF_BIRCH_MATCH_CALL`
is set in Elm's lab, so a Johto-first player may never get Birch's phone registration. That is from
reading the scripts, and it was not checked in play.
