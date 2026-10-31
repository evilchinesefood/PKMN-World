# Additional findings from #357

These historical bugs were fixed in
[PR #358](https://github.com/evilchinesefood/PKMN-World/pull/358).
They remain documented separately to satisfy the follow-up requirement in
[parent #357](https://github.com/evilchinesefood/PKMN-World/issues/357).
The October audit retained local drafts. The October 31 acceptance review
publishes their records and verifies the merged fixes. The acceptance PR requests
closure of the parent and these five records; their closure depends on its merge.

| Confirmed historical bug | GitHub record |
| --- | --- |
| Pryce reflection palette exhaustion | [#361](https://github.com/evilchinesefood/PKMN-World/issues/361) |
| Johto victories changing Hoenn trainer flags | [#362](https://github.com/evilchinesefood/PKMN-World/issues/362) |
| League entrance blocked before and after the Hall of Fame | [#363](https://github.com/evilchinesefood/PKMN-World/issues/363) |
| Elite Four exits sealed after Continue | [#364](https://github.com/evilchinesefood/PKMN-World/issues/364) |
| Hall of Fame hangs with the Violet gift Egg | [#365](https://github.com/evilchinesefood/PKMN-World/issues/365) |

## Johto: Mahogany Gym crashes when ice reflections exhaust palettes during Pryce's battle fade

**Impact:** starting the seventh Gym battle can hit an assertion screen instead
of entering battle.

**Reproduction:** base master `15d3888b0d81322a04d3c71b0bce18948761ee44`, plus only
the New Bark home-heal correction; fresh isolated save, staged party/region and
Mahogany Gym position `(12,5)`, then face up and talk to Pryce. Reproduced with
both Mewtwo and Chikorita parties, alone and following other leader victories.
This stages the approach; it does not claim a continuous campaign reproduction.

**Actual:** `src/util.c:228: BlendPalette out of bounds: palOffset=4336 numEntries=16`.
**Expected:** transition into Pryce's battle, award the Glacier Badge on victory,
and return player control.

**Cause:** ice reflections still update during the trainer battle fade.
`LoadSpritePalette` returns `0xFF` when the palette pool is full. Reflection code
passes it to weather blending, producing offset `(16 + 255) * 16 = 4336` outside
the 512-entry palette buffer.

**Merged fix:** reflection creation/update checks allocation failure, temporarily
shares the parent object's valid palette, and retries a dedicated filtered
palette when space returns. Bridge reflections retry their blue palette.

**Verification:** Pryce's three badge-order battle variants complete in the
emulator. Exhaustion fixtures exercise pond, ice and bridge creation, retry, and
preservation of palette ownership. See retained `evidence/pryce-baseline.log`,
`pryce-baseline.png`, and the final audit logs/results.

## Johto Gym victories clear Hoenn trainer flags instead of their own

**Impact:** beating a Johto leader silently marks trainers in the corresponding
Hoenn Gym defeated and leaves Johto Gym trainers active. This corrupts independent
regional progress and can interrupt the intended Gym-exit story handoff.

**Reproduction:** fresh isolated save, staged party/Johto region and Violet Gym
position `(9,5)`, face up, talk to Falkner, win the battle. The audit forces the
win at the real battle command boundary to isolate post-battle scripting.

**Actual:** Johto trainers Rod/Abe remain undefeated; Hoenn trainer Josh becomes
defeated. All eight Johto leaders call the Hoenn `Common_EventScript_SetGymTrainers`
with their badge number.

**Expected:** only trainers belonging to that Johto Gym are marked defeated;
Hoenn remains unchanged.

**Merged fix:** add a Johto dispatch with the actual trainer IDs from each Gym's
scripts, and point all eight Johto leaders at it. Jasmine's Gym has no subordinate
battles, so its entry returns without setting unrelated trainer flags.

**Verification:** a pre-fix Falkner run fails Rod/Abe and Hoenn-preservation
assertions. Post-fix tests verify all subordinate trainer IDs, badge/challenge
handoffs, and Hoenn preservation for all eight leaders and alternate eastern
Gym orders. See `evidence/gym-flags-baseline.log` and final Gym audit logs.


## Johto League entrance remains blocked before and after the Hall of Fame

The Black Belt at `(32,3)` blocks the only approach to the Plateau Center's
Elite Four door at `(32,2)`. The old scripts never set his hide flag, and the
Hall of Fame cleared it again. Route 27 now sets the flag, the Center transition
repairs old saves, and the Hall of Fame preserves it.

The staged `audit_probe.lua` walks through the real Route 27 trigger and tests
the door before and after it. `audit_league.lua` checks that the Hall of Fame
preserves the flag. These tests do not claim a naturally played baseline campaign.

## Saving in a cleared Johto Elite Four room seals both exits

After beating Will, save at `(6,10)`, restart, and Continue. The old load hook
restored the sealed entrance but not the opened north door. Both exits stayed
closed. Each room now restores its north exit from `VAR_LEAGUE_STATE`.

`audit_e4lock.lua` stages the League prerequisites, runs Will's battle handoff,
saves through the menu, restarts, and walks through the north exit. Saving near
the south end keeps the north door outside the saved map-view window and exposes
the missing load-time restoration.

## The Hall of Fame hangs with the unhatched Violet gift Egg

The ceremony completed with Chikorita alone but hung after receiving the Violet
gift Egg. `SPECIES_EGG` lacked `frontAnimFrames`. Its END-only placeholder never
set `animEnded`, so `Task_Hof_PrintMonInfoAfterAnimating` waited indefinitely.
The Egg now uses `sAnims_SingleFramePlaceHolder`.

`audit_hof.lua` receives the actual gift through its script and verifies the
ceremony with the Egg, a clean save, one prior save, and several prior saves.
The League prerequisites and victories are staged. The campaign in PR #360
supplies separate continuous progression evidence with its documented concessions.
