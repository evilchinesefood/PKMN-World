# Johto freeze and progression audit for #357

Parent [#357](https://github.com/evilchinesefood/PKMN-World/issues/357) requires
runtime verification of first-battle recovery, Mom dialogue, and Johto progression.
[PR #358](https://github.com/evilchinesefood/PKMN-World/pull/358) merged the fixes
recorded below. [PR #360](https://github.com/evilchinesefood/PKMN-World/pull/360)
added a continuous controller-driven campaign and three further progression fixes.

## Current acceptance review on October 31, 2026

The verification target is merged master `a0557b387c30b2b943f159e85bf3777200ea9c13`.
This review adds evidence and corrects the acceptance record. It does not add a
second gameplay fix for a Mom freeze that has never been independently reproduced.

The [fresh focused results](evidence/2026-10-31/focused-results.json) pass all
seven cases and 106 assertions. Each case exited successfully and produced a fresh sentinel with
the tested ROM hash. The natural first loss returns control, Mom dialogue
completes, the player leaves home, and Save/Continue preserves the starter and
movement. Both genders pass the additional Mom and repeated-defeat fixtures.
The core-loop fixture passes healing, party-menu, capture, storage, and save checks.

The production ROM was built from clean source at the revision above in the
sibling `johto-open-issues` worktree. The acceptance worktree uses copies of that
ROM, its matching ELF, map, and generated build headers. Its gameplay source is
unchanged. The recorded `heal_location.c` SHA-256 matches this checkout.
The [build manifest](evidence/2026-10-31/build.json) records the production hashes.

- Production ROM MD5 is `CBF96BB4C1391D2C3B1FE86B8F16AFDA`.
- Production ROM SHA-256 is `587ac344543038df56dd15083b68f70792320876de049314b50a36ee83c9cc8c`.
- The separate core-loop fixture MD5 is `BAFB185FCCC651297F222872432319BC`.
- `make validate` passed. Its [raw output](evidence/2026-10-31/validate.log) is retained.

The [fresh staged audit](evidence/2026-10-31/audit-results.json) passes all twelve
suites and 737 assertions. Every suite exited successfully and produced a fresh
sentinel for fixture MD5 `BE61E04EE032A85A665667791D933724`. The
[fixture manifest](evidence/2026-10-31/audit-fixture-manifest.json) ties that
patched test ROM to the same production SHA-256. The new
[evidence index](evidence/2026-10-31/README.md) lists each suite and its limits.

The missing map and generated headers initially caused fixture setup errors.
Copying the matching build inputs corrected setup before the completed tests.
Those attempts were setup failures, not gameplay regressions.

The five historical follow-up records are [#361](https://github.com/evilchinesefood/PKMN-World/issues/361),
[#362](https://github.com/evilchinesefood/PKMN-World/issues/362),
[#363](https://github.com/evilchinesefood/PKMN-World/issues/363),
[#364](https://github.com/evilchinesefood/PKMN-World/issues/364), and
[#365](https://github.com/evilchinesefood/PKMN-World/issues/365).
Their fixes already merged in PR #358. This acceptance PR requests closure of
#357 and these five records. The [follow-up record](follow-up-issues.md) links
each issue to its reproduction and regression.

The [continuous campaign record](../johto-playthrough/README.md) reports 83/83
checks and zero retries on ROM MD5 `6434B3C6074481A1E07D50CB64FC2193`.
That October 31 run reached the Hall of Fame through all 82 story beats.
It used a debug-given level-100 party, a met-level adjustment for obedience, and
debug healing. It supplements the natural first-loss test and staged audit below.
It does not establish ordinary battle balance or exhaustive optional-quest coverage.

## Historical reproduction and fixes

The original tests started October 8, 2026 on master base
`15d3888b0d81322a04d3c71b0bce18948761ee44`. The following findings describe that
baseline and the fixes later merged in PR #358.

1. **First-battle defeat freeze — reproduced and fixed.** New Bark respawns beside
   Mom, but `IsLastHealLocationPlayerHouse()` omitted `HEAL_LOCATION_NEW_BARK_TOWN`.
   Whiteout ran the Center nurse script in the player's house and stalled at its
   movement wait. New Bark now uses the existing home/Mom recovery script. The
   baseline fresh game loses its first natural Route 29 battle using Growl and
   gets stuck at home `(8,4)`, script `0x083D213A`. The fixed production ROM heals,
   releases movement, permits Mom interaction, exits home, saves, Continues and
   moves again. No save-format change.
2. **Pryce battle-start crash — newly reproduced and fixed.** Ice reflections
   continue updating while the battle transition fills the sprite palette pool.
   Failed allocation returned `0xFF`, which was passed to weather blending:
   `BlendPalette out of bounds: palOffset=4336 numEntries=16`. This blocks the
   seventh Gym battle. Reproduced from fresh staged saves with both Mewtwo and
   Chikorita, alone and after other Gym victories. Reflection creation/update
   now shares the parent's valid palette when allocation fails and retries its
   filtered palette when space returns; bridge reflections retry blue. All
   three Pryce battle tiers now start, award the badge, and release control.
3. **Johto Gym victories wrote Hoenn trainer flags — newly verified and fixed.**
   All eight leaders called Hoenn's `Common_EventScript_SetGymTrainers`. A
   pre-fix Falkner victory leaves Rod/Abe undefeated and marks Hoenn's Josh
   defeated. A dedicated Johto dispatch now marks the actual subordinate
   trainers of each Johto Gym, with an empty return for Jasmine. Tests check
   every subordinate trainer and every corresponding Hoenn Gym trainer flag.

**A separate freeze from talking to Mom was not reproduced.** Fresh-game intro,
post-defeat interaction, before-adventure, waiting-for-Elm, farewell, repeat
healing and both genders complete. The injured-party case verifies full HP.
Baseline direct dialogue also passed. The original loss freeze prevents any
subsequent interaction, which may explain the report, but that is an inference;
an independent Mom defect remains unverified.

The [follow-up findings](follow-up-issues.md) record the additional confirmed
bugs and their merged fixes. The original October audit retained local drafts;
this acceptance review links their GitHub records.

## Second pass — staged Johto progression review (October 24, 2026)

Base `15d3888b0d` plus the three fixes above. Three further defects found, all confirmed on a
disposable ROM before being fixed, and all three are progression blockers rather than cosmetic.

4. **The Johto Elite Four was unreachable on every save.** `JohtoIndigoPlateau_PokemonCenter`
   warp 1 at (32,2) is the door to Will's Room. The layout's collision makes y=2 solid at every
   column except x=32, so (32,3) is the only tile it can be entered from — and an
   `OBJ_EVENT_GFX_BLACK_BELT` sits exactly there at elevation 0, colliding at every elevation.
   He hides behind `FLAG_HIDE_LEAGUE_BLACKBELT`, which is defined once, cleared once by the Hall
   of Fame, and **never set anywhere**, so he spawned on every save. Route 27's first-steps
   flagheap already hides Victory Road Silver, Plateau Silver and Mary/Oak; the Black Belt was
   missing from that list. Measured: before Route 27 the climb stops at (32,4); after it the
   same climb reaches (32,2) and warps.
5. **The Hall of Fame re-blocked that same door post-game.** It cleared the hide flag, putting
   him back on the only approach tile the moment the player became Champion — against the HARD
   Elite Four rematches the same script enables two lines later. The clear is gone.
6. **Saving inside a cleared Elite Four room sealed the player in permanently.** Each room opens
   its north exit with `setmetatile` on victory and seals the south entry behind the player, and
   the base layout ships both exit tiles closed. The shared `EliteFourRoom_OnLoad` restored only
   the entry seal, so a reload left both doors shut in an indoor map with `allow_escaping` false
   and no Fly, Dig or Escape Rope. Kanto's rooms already restore their door
   (`PokemonLeague_LoreleisRoom_OnLoad`); each Johto room now does too. Measured: beat Will, save
   at (6,10), reset, Continue — before, the climb stopped at (6,3) and the descent at (6,10);
   after, the same walk warps through to Koga's Room.

### Further staged regressions and review corrections

- **Pryce/hideout order:** staged victory at Mahogany state 5 previously wrote 15. The guard
  preserves unfinished hideout state, and hideout completion advances to 15 if the badge is
  already held. Normal play blocks the Gym with an NPC until hideout completion; this is
  defensive handling of abnormal or migrated state, not a demonstrated ordinary-route bug.
- **S.S. Aqua:** staged interaction with Stanly at voyage state 5 previously rewound it to 3.
  His update is now monotonic. The B1F sailor gates the captain's corridor in normal play, so
  the test does not establish a naturally reachable granddaughter-first softlock.
- **Initial visibility:** new games hide the Radio Tower grunt, Oak/Mary and six Ilex Forest
  objects before the route-entry flagheaps run. The grunt is removable by battle; Route 27
  already hides Oak/Mary before a normal League visit. Early appearance/collision was measured
  using fixture warps; neither proves an unavoidable progression block.

**Refuted: the Electrode respawn.** The audit predicted the three Electrodes respawn, letting
`VAR_ELECTRODES_FAINTED` overshoot the completion trigger's exact `== 3` match and strand the
player. It does not hold — `removeobject` goes through `RemoveObjectEventByLocalIdAndMap`, which
`FlagSet`s the object's own hide flag (`src/event_object_movement.c:1713`), so a beaten Electrode
stays gone. The overshoot only appeared in testing because the probe cleared those flags by hand.
The same mechanism refutes the claim that Stanly respawns. `audit_statefix.lua` keeps a case
asserting the `FlagSet` happens, because the conclusion rests on it.

Still unfixed and reported only: the three Electrode hide flags are **crossed** — each covers one
of Lance's scenery Electrodes at x=20 and one battleable Electrode at x=11 — so beating the
battleable set despawns Lance's, and his Hyper Beam flourish plays over empty floor. Cosmetic,
and separating them means allocating new flag slices, so it is left as a decision rather than
folded into a progression fix.

### Review correction — Hall of Fame with an Egg (October 25, 2026)

The continuous ceremony stall was a game defect. A short League run with Chikorita alone
completed; adding the real Violet gift Egg reproduced the hang without prior saves or a long
session. The ceremony waited in `Task_Hof_PrintMonInfoAfterAnimating` on the Egg sprite's
`WaitAnimEnd` callback. `SPECIES_EGG` had no `frontAnimFrames`, selecting an END-only dummy
animation that never set `animEnded`. The Egg now uses `sAnims_SingleFramePlaceHolder`.

The earlier claim that party differences were ruled out was incorrect: the continuous run
contained an Egg, while the isolated League run did not. `audit_hof.lua` now includes the actual
Violet gift before the ceremony. All audit failures are fatal again; the XFAIL exception was
removed. This remains a staged audit, not proof of a naturally played complete campaign.

### Suites added

- `audit_continuous.lua` — one save, the whole arc, no reboot between beats. The other suites
  each reboot and warp in with hand-set prerequisites, so none of them covered state that
  accumulates. Reaches the League by walking Route 27 and the Plateau door, which is what makes
  the blocked door visible. Records "chain gaps" where a beat's prerequisite was not set by the
  beats before it, then stages it and continues.
- `audit_probe.lua` — the Elite Four door, walked through the real Route 27 trigger. Checks the
  gatekeeper still blocks *before* Route 27, that the door opens after it, and that a cleared hide flag
  self-heals on re-entry for saves that already completed Route 27.
- `audit_e4lock.lua` — beat Will, save in the cleared room, reset, Continue, try both doors.
- `audit_hof.lua` — the ceremony with the Violet gift Egg, a clean save, one prior save and several, with
  `gDamagedSaveSectors` and `gSaveCounter` read at the end.

`audit_league.lua` now stages `FLAG_HIDE_LEAGUE_BLACKBELT` before the ceremony and asserts the
Hall of Fame leaves it set; without the staging that check would read clear either way and prove
nothing.

## Run the checks

Requires devkitARM and the patched `mgba-headless` in
[the emulator guide](../mgba/README.md).

```sh
make modern -j8
make validate
python3 test/overworld/johto-progression/run.py
python3 test/overworld/johto-progression/run_audit.py
PW_OUT="$PWD/_pwtest/357-regression" test/overworld/run-all.sh
```

`run.py` executes seven opening/Mom/recovery/core-loop cases. `run_audit.py`
executes twelve expanded suites covering Gym victories, two alternate eastern
Gym orders, story scenes, the League, reflection exhaustion, the staged
continuous arc, League entry, Hall of Fame parties, room reloads, initial hide
flags, and regional state transitions. Both clear old verdicts and require
successful exit plus a fresh sentinel stamped with the tested ROM's MD5. The
expanded runner exports matching ELF addresses, map coordinates and preprocessed
constants, rather than reusing addresses from another build. `--suite` can target
one expanded suite.

The production ROM is never patched in place. Audit commands are appended only
to disposable ROM copies. Saves are isolated; the user's save is not written.
The baseline first-loss reproduction uses the base code without the home-heal
fix; regenerate symbols/controller addresses for that build. Pryce's baseline is
the base plus only the home-heal fix, before reflection handling was corrected.

## Historical build and save provenance

- Final production MD5: `C763D32137B920F2CA308CE5F1C945F5`.
- Final production SHA-256:
  `3ce12c7e717c46dc42bf202e1cd85a763fae64f43b9eea0f889a3a6a8c0b6ba4`.
- Expanded audit ROM MD5: `4F8128922BBF0A3AE341CA3B3F95EE9C`.
- Core-loop fixture MD5: `5B933E21F58C791FA7D01BD4F791CBE1`.
- Original first-loss baseline MD5: `A15DFD14E4E53D29578425E42068F670`.
- Pryce baseline production SHA-256:
  `2288385cea662114f52f6b154b7e186d8801e65cb41ab3014fafb7fa4f2e2c2d`.
- Deterministic RTC: `1704110400` (2024-01-01 12:00 UTC).
- Natural opening/nickname runs: empty save, normal fresh-game defaults,
  Chikorita, controller input and memory reads only. No party, HP, outcome,
  region or story edits.
- Mom/defeat fixtures: debug-created party, explicit region/story/HP setup;
  targeted losses force battle HP/outcome. Natural loss separately establishes
  the production failure and repair.
- Core-loop fixture: prepared party/balls and an injected wild encounter;
  real nurse, menus, Bag capture, storage, Save and Continue code.
- Expanded audit: fresh disposable saves, party/region/story prerequisites and
  approach positions staged explicitly. Battles enter the real command menu;
  wins are forced there to isolate story continuations. These prove handoff and
  control behavior, not ordinary combat balance or naturally earned progression.

## Gameplay coverage

| Path | In-game checks and results |
| --- | --- |
| Natural opening | Hub → Johto bedroom → clock → Mom → town → Elm → Chikorita → errand → aide's potion → Route 29. Dialogue, actual starter and movement pass. Separate fresh run opens the nickname screen and returns control. |
| Natural first loss | Growl until the wild opponent wins; home recovery, Mom, home exit, real Save, reboot, Continue and movement pass. Baseline freezes. |
| Mom / repeat loss | States 0/2/4/5 dialogue and healing for both genders; six repeated home recoveries in states 0/2/5 pass. |
| Core loop | Cherrygrove nurse heals an injured lead; Party opens/closes; Route 29 Bag capture consumes the last ball, boxes a full-party catch, and persists through real Save/Continue. |
| Opening story handoffs | Mr. Pokémon Egg → return to Elm/police scene → aide's Balls; Sage Li battle; Violet Togepi Egg; charcoal master's Cut handoff pass. |
| Western story handoffs | Kurt opens the Well; beast release unlocks Morty; Squirt Bottle → Sudowoodo → road clear; pharmacy → Lighthouse medicine/healing; theater Rocket → Surf pass. |
| All eight leaders | Real NPC/battle entry and victory scripts for Falkner, Bugsy, Whitney, Morty, Chuck, Jasmine, Pryce and Clair pass. Whitney's crying/exit/revisit awards her badge. Clair opens the Den challenge. Gym trainer flags and Hoenn isolation pass. Chuck's staged approach is boxed by unpushed boulders, so returned control is verified through Party rather than an impossible step. |
| Eastern Gym variants | Orders Chuck/Jasmine/Pryce, Pryce/Chuck/Jasmine and Jasmine/Pryce/Chuck exercise each leader's first, second and third battle tier. All pass. |
| Rocket handoffs | Petrel → Basement Key; Director → Card Key → Radio Tower shutter; Archer → Director/wing scene; generator → Whirlpool reward and Mahogany state 14 pass. |
| Dragon's Den | All three entry approaches run the actual quiz menus, Clair arrival/departure, Rising Badge award and returned movement. |
| Kimono gauntlets | Both Lugia and Ho-Oh selections play all five actual trainer battle entries, complete the bell/cutscene handoff, reach theater state 7 and return movement. |
| League / durability | Entry-door scenes, Will/Koga/Bruno/Karen, Lance, Hall of Fame and return to New Bark complete. Champion flag survives a real Save/reboot/Continue; movement returns. |
| Allocation exhaustion | Pond, ice and bridge reflections survive a full palette pool during fade, retry their dedicated palette after freeing space, and preserve palette ownership. |
| Existing production sweep | Johto marts/healing, Azalea gym ride, Slowpoke Well rescue, Red Gyarados, Tin Tower, Tohjo Falls, field moves, travel, save migrations, menus and other regions are exercised by the existing suites. |

This runner combines a natural opening with staged later progression. Some
major scenes use test warps and supplied prerequisites. The separate campaign
in PR #360 subsequently covered the Farfetch'd chase and Underground switch
puzzle in sequence, with the debug-party and healing concessions stated above.
Neither run covers every starter, difficulty, optional quest, or postgame path.
The evidence supports the tested recovery and progression paths, not a claim
that all of Johto is bug-free.

## Historical validation and evidence

- `make modern -j8`: passed; existing map newline/RWX linker warnings.
- `make validate`: passed all source validators.
- Focused runner: **7/7 cases, 106 assertions** (94 production, 12 core fixture).
- Expanded audit: **6/6 suites, 336 assertions** (146 Gym/order, 107 story,
  22 League, 61 reflection). The Gym isolation checks were then strengthened to
  inspect every corresponding Hoenn trainer and rerun successfully.
- Final production sweep: **52/52 suites, 1,380 assertions**, with fresh matching-ROM sentinels.
- `git diff --check`: passed.

[Retained evidence](evidence/) includes original first-loss baseline, Pryce crash
and baseline fixture metadata, pre-fix Gym flag failures, final logs/results and
selected screenshots. Full local runs: `_pwtest/357-final-focused/`,
`_pwtest/357-final-audit/`, `_pwtest/357-final-gym-isolation/`,
`_pwtest/357-final-gym-order2/`, `_pwtest/357-final-gym-order3/`, and
`_pwtest/357-final-regression/`.

An earlier sweep overlapped a rebuild and correctly failed its stale-ROM audit;
it is excluded from the results above. Only the final stable-ROM sweep counts.
The shared library's count line prints `PASS` even on failed assertions: exit
status and fresh `.PASS`/`.FAIL` sentinels, not that word alone, are authoritative.
