# Remaining sprite allocation candidates

Reviewed all **166 candidates in 42 files** at commit
`0a1438d0df3dd278f5d2b55c1d129f58b8907f4b`, after the fixes in PR #285.
The follow-up in [PR #285](https://github.com/evilchinesefood/PKMN-World/pull/285)
addresses all 61 selected allocation sites. The 75 uncertain candidates are tracked
in [issue #286](https://github.com/evilchinesefood/PKMN-World/issues/286); the 30
current-scope dismissals remain unchanged. The scanner now reports 105 matches.
The inventory preserves the original line numbers/verdicts and adds a resolution
column; the classifications below describe the pre-fix audit.

| Verdict | Sites | Meaning |
| --- | ---: | --- |
| Confirmed under exhaustion | 61 | Field allocation paths use an asserting allocator despite needing allocation-failure handling. 51 reproduced with emulator probes; 10 confirmed by source/caller tracing only. |
| Ignore for current scope | 30 | Disabled/unreachable code, a false scan match, bounded scenes, or an intentional required-allocation assertion. |
| Unconfirmed; keep assertions pending investigation | 75 | A nearby guard alone does not prove a player-facing bug or a safe fallback. Scene occupancy and lifecycle evidence are still needed. |

The [complete inventory](SpriteExhaustionTriage.tsv) records a verdict, evidence,
and individual reasoning for every candidate. IDs are stable for this snapshot;
line numbers will move after changes. These are allocation sites, not necessarily
independent bugs.

## What the probes establish

The [51 diagnostic fixtures](probes/sprite_exhaustion.c) fill the sprite pool and
invoke the relevant field effect, weather routine, wrapper, or registered-item
task. All 51 reach the allocator's **“Out of sprite slots”** assertion; the
[captured diagnostics](probes/sprite_exhaustion_results.txt) record each result.
This proves the failure path under injected exhaustion. It does not establish
that ordinary gameplay reaches full capacity at each site, nor validate recovery
after an allocator change. No natural gameplay reproduction is claimed for all
61 sites.

At the time of the baseline audit, the ten source-only sites were C028, C029, C040, C041, C043, C066, C075, C076,
C077, and C122. The follow-up adds runtime coverage for most of these; see the coverage limits above.

## Implemented recovery

Optional field effects now use recoverable allocation and remove their active-list
entry when no sprite fits. Ash still applies its tile change. Disguise reveal,
surf/flight decorations, player/follower dismount, and Rock Climb completion tolerate
missing visuals. Snow initialization caps its target at successful allocations;
weather teardown handles partial sets, including a bubble sheet with no sprites.
The registered-item wheel also handles its dark-cave OBJWIN twins.

A separate `CreateObjectGraphicsSpriteUnchecked` API serves surf and flight while
existing required-controller callers keep their asserting contract. Dowsing rolls
back its flag/ID and itemfinder chooses valid sprite/task state without reading a
missing sprite or `TASK_NONE` task.

Script-level retry tests also found the bug-track and spot-track entries reversed
relative to the numeric effect constants. Their table order is corrected so both
creation and cleanup address the requested effect.

**Configuration correction:** the two ORAS dowsing factories were exercised directly
in the baseline probes. Normal item entry is disabled by the current
`I_ORAS_DOWSING_FLAG=0` setting; those two probes were not proof of current gameplay
reachability. Their failure paths are hardened as part of this follow-up.

Validation: **73/73 exhaustion regression tests**, **10/10 boot smoke checks**,
`make modern -j8`, and `make validate` pass.

Regression coverage is in `test/sprite_exhaustion_field_effects.c`, alongside the
original eight regressions. It checks full/partial pools, preservation of unrelated
sprites and the sentinel, active-effect cleanup, script dispatch/retry, weather
restart, dark-cave wheel cancellation, missing disguise reveal, flight and mount
boundaries, and field-task completion. Rock Climb and Deoxys tests drive task stages;
they do not claim complete end-to-end field-move cutscene coverage. DexNav held-item
and star changes are source-verified; a complete HUD gameplay test is still outside
this regression set.

## Original findings

- **Registered-item wheel (C126):** opens over the live overworld and allocates
  its boxes there. The probe registers two items and runs the public field-use
  task, reproducing the assertion. Input and cleanup already recognize missing
  box sprites, but the asserting allocator blocks that path.
- **Weather (C078–C085):** clouds, snow, horizontal/diagonal fog, ash,
  sandstorm, swirl sand, and bubbles all reproduce. Snow needs more than an
  allocator substitution: failed creation does not advance its visible count,
  so synchronous initialization can keep waiting for an impossible target.
- **Field effects and trainer icons:** the probes cover ground effects,
  footprints, splashes, disguises, and additional trainer icons. Effect-list
  registration must be cleaned up on failure. “UnusedSand” and “WaterSurfacing”
  are used by DexNav and cannot be dismissed by name.
- **Disguises, Rock Climb, and dowsing:** recovery also needs state handling.
  Disguise and Rock Climb callers retain sprite IDs for later operations;
  dowsing sets state before allocation. Returning a failure ID alone is not a
  complete fix.
- **Flight decorations, rotating gates, and DexNav HUD:** source tracing finds
  field-pool allocations with blocked failure handling. Test allocation
  boundaries and teardown before changing these paths. The DexNav star guard
  also handles intentionally absent stars, so the entire guard is not dead.

## Why 30 can be set aside

The current configuration excludes six allocations during preprocessing. Eight
more belong to the inactive FRLG intro, six to the bypassed legacy storage UI,
and one to an inactive legacy enemy-shadow branch. A separate FRLG intro match
is a scanner false positive: its result is overwritten before the guard.

Seven allocations belong to bounded scenes that reset the pool: four Easy Chat
indicators (at most twelve sprites in the reviewed scene), two Fly-map
destination allocations (at most nineteen), and one Seagallop wake allocation
(conservative bound of fourteen, with finite wake lifetime). These bounds must
be revisited if scene allocation or lifetime behavior changes.

The remaining site is `CreateInvisibleSprite`: required controller callers
directly consume its result. Its redundant guard does not justify removing the
factory's assertion globally. This classification is scoped to the current
build and callers, not a claim that disabled configurations are safe.

## Why 75 remain unconfirmed

Most are battle animations or UI scenes. Resetting the pool on scene entry is
insufficient proof that later allocations fit; conversely, forcing every
required UI allocation to fail is insufficient proof of a normal gameplay bug.
The inventory describes the missing occupancy or lifecycle evidence per site.

Some apparent fallbacks are unsafe already: the older condition-sparkle helper
uses a sprite after a failed creation loop, the SwSh storage marking cursor has
later unchecked consumers, and a hail child-allocation failure can leave its
owner's active count outstanding. These observations argue against bulk
replacement with unchecked allocators. They do not establish natural sprite
exhaustion in those scenes.

## Reproduce

Run the current recovery regressions with:

```sh
make check -j8 TESTS='*exhaustion'
```


Refresh the heuristic inventory with:

```sh
python3 Testing/AuditSpriteAllocations.py > /tmp/sprite-allocation-candidates.tsv
```

To reproduce the **old crashes**, use the audited baseline commit (before the
fixes). With the project's test toolchain installed, copy the diagnostic fixture into
the test directory and run only its tests:

```sh
cp Testing/probes/sprite_exhaustion.c test/sprite_exhaustion_probe.c
make check -j8 TESTS='Sprite audit probe'
rm test/sprite_exhaustion_probe.c
```

The fixture marks each crash `KNOWN_CRASHING`; expected failures are evidence
of existing behavior, not passing regression tests for a fix. To capture the
exact assertion diagnostics, remove those markers from the temporary copy
before running. That run intentionally exits nonzero (51 failures in the
recorded baseline). Always remove the temporary copy afterward. The fixtures
are outside `test/` so they do not alter the normal suite.

The source review also checked current Emerald preprocessing and caller
dispatch, including `IS_FRLG`, `SWSH_STORAGE_SYSTEM`,
`SWSH_STORAGE_CHOOSE_BOX_GRID`, and the enemy-shadow configuration. The scanner
is heuristic and this review covers its 166 matches, not every sprite
allocation in the repository.
