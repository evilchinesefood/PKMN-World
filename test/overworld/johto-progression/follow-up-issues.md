# Additional findings from #357

These are concrete GitHub issue drafts. They have **not been published**:
automatic approval review rejected the issue-create action because it considered
public disclosure of derived crash details insufficiently authorized. Code and
local tests proceeded. Parent: [#357](https://github.com/evilchinesefood/PKMN-World/issues/357).

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

**Local fix:** reflection creation/update checks allocation failure, temporarily
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

**Local fix:** add a Johto dispatch with the actual trainer IDs from each Gym's
scripts, and point all eight Johto leaders at it. Jasmine's Gym has no subordinate
battles, so its entry returns without setting unrelated trainer flags.

**Verification:** a pre-fix Falkner run fails Rod/Abe and Hoenn-preservation
assertions. Post-fix tests verify all subordinate trainer IDs, badge/challenge
handoffs, and Hoenn preservation for all eight leaders and alternate eastern
Gym orders. See `evidence/gym-flags-baseline.log` and final Gym audit logs.
