# Johto freeze and progression audit — #357

Tested October 8, 2026 on master base
`15d3888b0d81322a04d3c71b0bce18948761ee44`, with the local changes described below.
Parent: [#357](https://github.com/evilchinesefood/PKMN-World/issues/357).

## Findings and fixes

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

The two additional findings have [reviewable issue drafts](follow-up-issues.md).
They have not been published: automatic approval review rejected public issue
creation without explicit publication approval. #357 remains open.

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
executes six expanded suites (eight leaders, two alternate eastern Gym orders,
story scenes, League, reflection exhaustion). Both clear old verdicts and require
successful exit plus a fresh sentinel stamped with the tested ROM's MD5. The
expanded runner exports matching ELF addresses, map coordinates and preprocessed
constants, rather than reusing addresses from another build. `--suite` can target
one expanded suite.

The production ROM is never patched in place. Audit commands are appended only
to disposable ROM copies. Saves are isolated; the user's save is not written.
The baseline first-loss reproduction uses the base code without the home-heal
fix; regenerate symbols/controller addresses for that build. Pryce's baseline is
the base plus only the home-heal fix, before reflection handling was corrected.

## Build and save provenance

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

This is a detailed **natural opening plus staged later progression audit**, not a
continuous unmodified eight-badge campaign. The complete Farfetch'd chase,
Underground switch puzzle, every route/trainer encounter, every starter,
difficulty setting and optional/postgame quest were not played sequentially.
Some major scenes are entered by test warp with prerequisites supplied. Existing
Red Gyarados/Tin Tower/Whirlpool suites also have their own setup limits.
Accordingly, the audit supplies broad gameplay evidence and fixes confirmed
blockers; it does **not certify all of Johto bug-free or fully campaign-tested**.

## Validation and evidence

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
