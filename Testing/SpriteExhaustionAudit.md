# Sprite exhaustion audit — issue #284

Reviewed 2026-09-09. This PR fixes the original three #284 paths plus warp arrows, rain, trainer exclamation marks, and map lights.

## Confirmed by emulator tests

`make check -j8 TESTS='*exhaustion'`

| Path | Reproduced before its fix | Recovery implemented |
| --- | --- | --- |
| `CreateWarpArrowSprite`, `src/field_effect_helpers.c:290` | Crashes at the asserting allocator before returning `MAX_SPRITES`. | Use recoverable allocation and ignore the failure ID in `ShowWarpArrowSprite` and `SetSpriteInvisible`. Test that failed creation leaves the reserved sentinel sprite unchanged, then free a slot and check show/hide behavior. |
| `Rain_Main` → `CreateRainSprite`, `src/field_weather_effect.c:680` | Crashes before the existing NULL-entry fallback and counter increment. | Use recoverable allocation and guard NULL entries in both visibility directions. Test initialization, increased intensity, and teardown with 0, 1, and 24 available slots. |
| `FieldEffectStart(FLDEFF_EXCLAMATION_MARK_ICON)`, `src/trainer_see.c:1054` | Crashes before the existing guard. | Remove the active field-effect entry when allocation fails. Test failure, successful retry, and normal callback cleanup. |

The trainer failure was also tested with **only** its allocator temporarily changed to
`CreateSpriteAtEndUnchecked`. The test reached its final assertion and failed because
`FieldEffectActiveListContains(FLDEFF_EXCLAMATION_MARK_ICON)` remained true.
`FieldEffectStart` registers the effect before allocation; `WaitTrainerExclamationMark`
will keep waiting while it is registered. This verifies the stale effect state; a full
trainer encounter was not played. That allocator-only experiment was replaced by the
complete allocation-and-cleanup fix.

These are now ordinary regression tests: no expected-crash markers remain. Map lights also
use recoverable allocation, with a test that drives the real map-object spawn loop through
exhaustion and successful retry. The original object, virtual-object, and shadow regression
tests remain in `test/event_object_movement.c`.

Correction to the initial audit: `gSprites` has `MAX_SPRITES + 1` entries. Indexing
`MAX_SPRITES` touches the reserved sentinel, not memory beyond the array. It is still an
invalid allocation result, and arrow consumers now avoid modifying that entry.

## Battle Dome evidence

The room has 15 map object events, no warp events, and `WEATHER_NONE`.
Its audience scripts add 0 / 11 / 21 / **32 virtual sprites** by round. The final's 32
extra sprites are absent from the original issue's map-object census. The 15 map objects
plus that audience already account for 47 slots before the player, shadows, and other
engine sprites. This is a concrete source of pressure, not a measured peak occupancy.
The transition script sets `FLAG_TEMP_HIDE_FOLLOWER`, so do not assume an active follower
contributes to the room's steady-state budget.

The new passing test executes the **actual** `AddFinalAudience` script with 0, 40, and 64
slots already occupied. It observes 32, 64, and 64 total occupied slots respectively,
and verifies that pre-existing sprites retain their callbacks. This tests successful
creation and skipped audience members under pressure with the #284 patch.

No warp events does **not** make the room inaccessible in principle: the pre-battle room
script uses `warp MAP_BATTLE_FRONTIER_BATTLE_DOME_BATTLE_ROOM, 9, 5`. The current Lua helper
only exposes warp-event selection. A coordinate-warp harness plus valid tournament save
state could test the complete entrance/final; that has not been implemented or played here.
The audience capacity test does not establish the player's original crash-time occupancy.

## Other source-confirmed candidates

- Flight shadow and wind, `src/field_player_avatar.c:1124` and `:1138`: asserting creates
  precede explicit failure checks. Audit the mount and overlay dependencies together.
- `CreateObjectGraphicsSpriteWithTag`, `src/event_object_movement.c:2156`: the wrapper
  exposes the same mismatch to its callers. Returning an error safely requires auditing
  those callers; its local guard alone is insufficient.
- Grass, footprints, splashes, and other effects in `field_effect_helpers.c` share the
  pattern. Effect registration/cleanup must be checked individually, as the trainer
  reproduction demonstrates.

Do not remove allocator assertions globally. For example, `CreateReflectionEffectSprites`
immediately indexes both returned IDs without guards. Also, resetting sprites on entry
to a menu or battle does not prove that subsequent allocation can never exhaust the pool.

## Repeatable discovery

```sh
python3 Testing/AuditSpriteAllocations.py > /tmp/sprite-allocation-candidates.tsv
```

The initial scan (after only the original three-site fix) found **170 candidates in 42
source files**; this PR leaves **166 candidates in 42 files**. Run the scanner to refresh
the inventory after additional fixes.
This is a heuristic count of direct assignments followed within eight lines by a
comparison against `MAX_SPRITES`. Comments and quoted text are excluded. It is not a
control-flow analysis, a complete caller audit, or an exact count of bugs. It can miss
wrapper-mediated/distant checks and include reassigned variables. It deliberately does
not fail `make validate` or automatically rewrite allocations.

Follow-up: audit the remaining effect lifecycles, weather variants, and optional overworld
visuals. Keep each change paired with exhaustion and recovery tests before expanding into UI
and battle code. The current PR does not claim to fix every heuristic candidate.
