# World playthrough: all three regions on one save

> **Note.** The run output this page cites (logs, screenshots and review pages) was removed from the repository in November 2026. It is still in git history before that removal. The results below are the record.

Plays Kanto, Johto and Hoenn on a single save, swapping regions mid-story through the Hub. It runs
the region campaigns' own beats, cut into slices at points the next slice can continue from.

```sh
make modern -j15
python3 test/overworld/johto-playthrough/run.py --campaign world --world A   # Johto first, one slice each
python3 test/overworld/johto-playthrough/run.py --campaign world --world B   # Hoenn first, two slices each
```

Beats are prefixed by region (`j_`, `k_`, `h_`), and crossings are `cross<n>_to_<region>`, so
`--from`, `--to` and `--lose` take names like `k_to_cerulean`.

Each crossing compares the wallet balance and total number of Poké Balls before departure and
after arrival. On a first visit the crossing spans two beats, so it checks both arrival at the Hub
and arrival in the new region. Return visits also check the remembered team, landing and whiteout
respawn. Runs before this quantity check counted occupied Poké Ball stacks and stopped the
first-visit supply check at the Hub.

## Concessions

Those of the region campaigns. A return crossing takes the gate's defaults: the region's remembered
team (#377) and its last eligible Center. The crossing checks that the party is exactly the team the
region last had, in order, and that the departing team sits in the PC once.

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
  still hands one over (`--detour opening` in the Johto campaign).
- The Hub Pass before Birch's rescue, which then plays normally (`--detour opening` in Hoenn).
- The Hub Pass right after Falkner lands in Goldenrod, and Azalea is reached from the north by Cut
  (`--detour goldenrod`, stop with `--to detour_goldenrod`).
- Talking to a trainer with an empty party is refused with a message (`--detour trainer` in Kanto,
  stop with `--to detour_trainer`). The check is in the shared trainer script.

## Slice limits, recorded so nobody chases them again

- Mt. Moon can't be walked to from the Vermilion gate with one badge, because Diglett's Cave comes
  out behind a Cut tree. Cerulean can be reached by the Underground Path, and the Dome Fossil is
  optional.
- Lavaridge has no walking route from Slateport, because the way down is the cable car. Hoenn's
  slice ends after the Go Goggles.
- Ice Path isn't planned backward, so Johto's slice runs on past Dragon's Den.

## Post-game

`--postgame` adds detours after chosen checkpoints. A detour plays its scene, checks the result,
then restores the checkpoint it began from, so the campaign carries on unchanged. `--world J` plays
Johto alone, for a Johto champion who has never been to Kanto. `--postgame-only <pattern>` keeps only the
detours whose names match, for iterating with `--from`.

```sh
python3 test/overworld/johto-playthrough/run.py --campaign world --world A --postgame
python3 test/overworld/johto-playthrough/run.py --campaign world --world J --postgame
```

Each Hall of Fame checks `VAR_DIFFICULTY`, the Hub tickets for that many champions, the Frontier
and World Championship gates, and every gate there and back. On orders A and B, the Hoenn Hall
checks Roxanne's reward and Brock's full bag, including claiming the stone later. At each order's
final story checkpoint (Hoenn for A, Johto for B and J), the run checks Falkner's rematch, a gate
swap with a PC one slot short and one with exact room (nothing lost or cloned), the Battle Tower from entry to a win, retire and rest-and-resume, and the Exchange Corner
with a full bag. Only `--world J` plays Elm's ticket, the S.S. Aqua in both directions and obedience by
badges. Orders A and B check Fly from the Frontier to Mauville after visiting it in Hoenn.
`--world B` sails from the Frontier with the active region's tier set by a non-champion
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

## Sevii

`--sevii` accepts Bill's invitation in the Kanto slices. The islands' pre-League beats already fall
in the Blaine to Giovanni slice. Kanto's last slice runs on from `home` through `sevii_ferry_home`,
as the Kanto campaign does. Kanto's own post-game beats are not part of the world order. `--world J`
has no Kanto, so `run.py` rejects `--sevii` there.

```sh
python3 test/overworld/johto-playthrough/run.py --campaign world --world A --postgame --sevii
```

A `--from` resume reads each region's remembered team from `ckpt_<beat>.stash_<region>`, saved
beside every checkpoint. A case directory from before that only has `stash_<region>`, which is the
team at that run's last crossing, so resume it from a checkpoint after its last crossing.

A Kanto gate lands at the last Center the player used, which after the pre-League islands is One
Island's. `to_victory_road` sails back to Vermilion first. The planner cannot route across the ferry.

On ROM `A77092BB16FD28FB494BD4BC7D807F67`, order A with `--postgame --sevii` was played from a fresh
save to `k_to_cinnabar`, resumed to `cross16_to_kanto` (all 8 pre-League island beats passed), then
resumed to the end at 251/251: the 17 post-League island beats, the remaining crossings, all three
Halls of Fame and every post-game detour. The first resume failed at `k_to_victory_road` with
`no route from OneIsland_PokemonCenter_1F_Frlg`, which is the sail-home fix above.

## Historical stress passes

Each row records the final integration run for that pass. World columns count campaign checks
passed in each order. The Lua sweep and host columns count passing suites and validators.
All five battle-test runs recorded zero failures.

| Pass | Landing PR | World A | World B | Lua sweep | Host | Battle tests passed |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| 4 | [#525](https://github.com/evilchinesefood/PKMN-World/pull/525) | 439/439 | 422/422 | 177/177 | 27/27 | 5,174 |
| 5 | [#572](https://github.com/evilchinesefood/PKMN-World/pull/572) | 439/439 | 421/421 | 215/215 | 27/27 | 5,191 |
| 6 | [#632](https://github.com/evilchinesefood/PKMN-World/pull/632) | 439/439 | 423/423 | 274/274 | 32/32 | 5,191 |
| 7 | [#670](https://github.com/evilchinesefood/PKMN-World/pull/670) | 440/440 | 423/423 | 309/309 | 39/39 | 5,191 |
| 8 | [#688](https://github.com/evilchinesefood/PKMN-World/pull/688) | 439/439 | 396/396 | 323/323 | 41/41 | 5,208 |
| 9 | [#706](https://github.com/evilchinesefood/PKMN-World/pull/706) | 439/439 | 397/397 | 339/339 | 48/48 | 5,208 |
| 10 | [#729](https://github.com/evilchinesefood/PKMN-World/pull/729) | 438/438 | 406/406 | 354/354 | 44/44 | 5,208 |

Both pass 7 campaigns finished with zero retries on integration commit `ddc15fd8e1`
(ROM SHA-256 `52ff4af450253f91e33ee5dd70ac78f67ab9c695275548494352928ca1be805e`).

Both pass 8 campaigns finished with zero retries on integration commit `a4a00957a4`
(ROM SHA-256 `6be3b21aff8da4e7218274e9c37058e417864cf4281a14cbc0ff98f2fa36cadf`). Pass 8 played world A with `--postgame --sevii` as the girl at
Instant text, and world B with `--postgame` only, so its world B count is not comparable with the
earlier rows. Before any fix, master `ce646ce30b` scored 440/440 (A, night clock) and 396/396 (B).

Pass 9 campaigns ran on integration commit `487a2e0963` (ROM MD5 `2c15aa760043124c2ecf867e271b5268`). World A
used `--postgame --sevii` as the girl at an afternoon clock with Instant text and finished with zero retries.
World B used `--postgame` as the boy at a night clock, with one bot retry: a wild encounter met the Dive press.
Before any fix, master `06307536b6` scored 440/440 (A, night clock) and 396/396 (B, morning clock).

Pass 10 campaigns ran on integration commit `77faf483fa` (ROM MD5 `cf6d1be37dd4a7336e373b51f1b3e34b`). World A
used `--postgame --sevii` as the girl at a night clock; world B used `--postgame` as the boy at a morning clock with
Instant text. Both finished with zero retries. Before any fix, master `ab414c43dd` scored 438/438 (A) and 405/405 (B).
The host count is lower than pass 9 because the save-format and content retirement before this pass removed four checks.

After the rematch fixes in [#730](https://github.com/evilchinesefood/PKMN-World/pull/730), both campaigns were rerun with
the same settings on master `ba5610eb82` (ROM MD5 `d1522e2e1ae706e0818a853d9189110e`). World A scored 438/438 in
35,963 steps and world B 406/406 in 31,951 steps, both with zero retries.
