# October 31 acceptance evidence

These runs verify source revision `a0557b387c30b2b943f159e85bf3777200ea9c13`.
The production build came from the clean sibling `johto-open-issues` worktree.
Matching ROM, ELF, map, and generated headers were copied to the acceptance
worktree. Documentation edits do not change the tested gameplay source.

The [build manifest](build.json), [focused results](focused-results.json), and
[audit results](audit-results.json) identify the production and fixture hashes.
The audit manifest records the documentation diff present during fixture creation.
All 19 cases exited successfully and wrote fresh, hash-matched PASS sentinels.

## Reproduce

From the repository root, run the following commands. Each runner creates
disposable saves and clears old sentinels before checking the tested ROM hash.

```sh
make modern -j8
make validate
python3 test/overworld/johto-progression/run.py --out /tmp/pw357-focused
python3 test/overworld/johto-progression/run_audit.py --out /tmp/pw357-audit
```

## Focused cases

The seven cases pass 106 assertions. The natural opening and first defeat use
controller input and memory reads. Mom and repeated-defeat cases stage gender,
story state, and party data. The core-loop case injects a prepared encounter,
then exercises the real nurse, party menu, capture, storage, Save, and Continue.

| Case | Assertions | Raw log and sentinel |
| --- | --- | --- |
| playthrough | 24/24 | [Log](focused/playthrough/JohtoProgression357.log), [sentinel](focused/playthrough/JohtoProgression357.PASS) |
| nickname | 12/12 | [Log](focused/nickname/JohtoNicknameAudit.log), [sentinel](focused/nickname/JohtoNicknameAudit.PASS) |
| mom-gender0 | 12/12 | [Log](focused/mom-gender0/JohtoMom357.log), [sentinel](focused/mom-gender0/JohtoMom357.PASS) |
| mom-gender1 | 12/12 | [Log](focused/mom-gender1/JohtoMom357.log), [sentinel](focused/mom-gender1/JohtoMom357.PASS) |
| defeat-gender0 | 17/17 | [Log](focused/defeat-gender0/JohtoDefeat357.log), [sentinel](focused/defeat-gender0/JohtoDefeat357.PASS) |
| defeat-gender1 | 17/17 | [Log](focused/defeat-gender1/JohtoDefeat357.log), [sentinel](focused/defeat-gender1/JohtoDefeat357.PASS) |
| core-loop | 12/12 | [Log](focused/core-loop/JohtoCoreLoop357.log), [sentinel](focused/core-loop/JohtoCoreLoop357.PASS) |

## Staged audit

The twelve suites pass 737 assertions. They stage party data, progression
prerequisites, or positions, and force battle victories after command-menu
entry. They test script handoffs and recovery, not normal combat balance.
The continuous suite also stages missing prerequisites and is not the separate
controller-driven campaign from PR #360.

| Suite | Assertions | Raw log and sentinel |
| --- | --- | --- |
| gyms | 86/86 | [Log](audit/gyms/JohtoGymAudit.log), [sentinel](audit/gyms/JohtoGymAudit.PASS) |
| gyms-order2 | 30/30 | [Log](audit/gyms-order2/JohtoGymAudit.log), [sentinel](audit/gyms-order2/JohtoGymAudit.PASS) |
| gyms-order3 | 30/30 | [Log](audit/gyms-order3/JohtoGymAudit.log), [sentinel](audit/gyms-order3/JohtoGymAudit.PASS) |
| story | 107/107 | [Log](audit/story/JohtoStoryAudit.log), [sentinel](audit/story/JohtoStoryAudit.PASS) |
| league | 24/24 | [Log](audit/league/JohtoLeagueAudit.log), [sentinel](audit/league/JohtoLeagueAudit.PASS) |
| reflections | 61/61 | [Log](audit/reflections/JohtoReflectionAudit.log), [sentinel](audit/reflections/JohtoReflectionAudit.PASS) |
| continuous | 314/314 | [Log](audit/continuous/JohtoContinuous.log), [sentinel](audit/continuous/JohtoContinuous.PASS) |
| probe | 16/16 | [Log](audit/probe/JohtoProbe.log), [sentinel](audit/probe/JohtoProbe.PASS) |
| hof | 25/25 | [Log](audit/hof/JohtoHallOfFame.log), [sentinel](audit/hof/JohtoHallOfFame.PASS) |
| e4lock | 13/13 | [Log](audit/e4lock/JohtoE4Lock.log), [sentinel](audit/e4lock/JohtoE4Lock.PASS) |
| hideflags | 10/10 | [Log](audit/hideflags/JohtoHideFlags.log), [sentinel](audit/hideflags/JohtoHideFlags.PASS) |
| statefix | 21/21 | [Log](audit/statefix/JohtoStateFix.log), [sentinel](audit/statefix/JohtoStateFix.PASS) |

## Screenshots

- [Home recovery after the natural first loss](JohtoProgression357_13_first_defeat_recovery.png).
- [Continue returns to New Bark](JohtoProgression357_15_johto_continue.png).
- [A cleared Elite Four room after Continue](JohtoE4Lock_02_after_reload.png).

The accompanying logs establish returned movement and progression. A screenshot
alone cannot establish that the game is responsive.

An independent Mom freeze remains unverified. The fresh dialogue cases pass;
the historical baseline reproduction shows the first-loss freeze blocking
subsequent Mom dialogue. The acceptance record keeps those claims separate.
