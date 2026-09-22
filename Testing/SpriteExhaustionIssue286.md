# Issue 286 sprite budgets

Reviewed on `origin/master` after PR #285. `MAX_SPRITES` is 64.
`CreateSprite` and `CreateSpriteAtEnd` still fatal-assert when the pool is
full, so a following `if (spriteId == MAX_SPRITES)` does not run.

All **75** candidates in issue #286 stay on that asserting allocator.
Each one was bounded in the scene that actually reaches it. The fullest
scene still has free slots. Switching these calls to an unchecked allocator
would not make them safe: several of the existing failure paths hang or
dereference a missing sprite, and those paths are not reached in play.

A bound counts sprites that are still `inUse`. Invisible sprites count.
Sprites destroyed earlier in the same scene do not. Resetting the pool at
scene entry is not, by itself, the bound. The bound is what the scene
allocates after that reset, including overlays that are added on top of
sprites that were only hidden.

## Tightest peaks

| Scene | Peak | Free slots | What is live |
| --- | ---: | ---: | --- |
| PC, Move Items, message open | 61 | 3 | 45 box chrome + 3 item icons + 7 info-panel sprites + 6 message-window sprites |
| Trade evolution spray | 59 | 5 | 3 trade/evolution mon sprites + 56 spray sparkles |
| Field evolution spray | 58 | 6 | Pre-evo, post-evo, and 56 spray sparkles |
| Doubles battle, Glare | 48 | 16 | 24 battle HUD sprites + 24 eye dots, if every pair is still alive |
| Dome final, return to field | 49 | 15 | 32 audience sprites, then 16 object events and one warp arrow |

## PC (C137–C148)

`ResetForPokeStorage` calls `ResetSpriteData` (`src/swsh_storage_system.c`).
A full box then holds:

- 1 cursor, 6 party icons, 30 box icons, 2 title sprites, 4 title-frame sprites, 2 arrows (45)
- Move Items also creates all 3 item-icon sprites up front (`MAX_ITEM_ICONS`)
- The info panel adds gender, shiny, two types, two nature labels, and one marking combo (7), and hiding that panel does not free them
- The message window is 6 sprites (`sMessageWindowSpriteIds`)
- The SwSh markings menu is 3 window pieces, 4 marks, and 1 cursor (8)

Those overlays do not stack. Mark is only on the Pokémon menu, which does
not create the 3 item icons, and choosing Mark clears the message window
first. The choose-box grid adds a hover sprite and a count sprite (2) and
replaces the title sprites instead of keeping both. Box scrolling destroys
a column before creating the incoming column, so the box stays at 30 icons.
Picking up a Pokémon reuses its icon as the held sprite.

The fullest moment is Move Items with the info panel populated and the
message window open: 45 + 3 + 7 + 6 = 61.

## Evolution sparkles (C036–C039)

Field evolution resets sprites (`src/evolution_scene.c`) and keeps the
pre-evo and post-evo pictures. The four sparkle phases run one after
another, and each phase's sprites are gone before the next phase starts.

Spray is the largest. `EvolutionSparkles_SprayAndFlash` creates 8 sparkles
on its first step and one more on each later step while its timer is below
50, except the fade step at 32. That is 56 sparkles. Each one lives 128
steps, so they are all alive together: 2 + 56 = 58.

`test/sprite_exhaustion_scene_budgets.c` runs the arc and spray tasks and
checks those peaks.

Trade evolution does not reset the pool. It keeps the sent Pokémon, the
received Pokémon, and creates the post-evolution picture, then runs the
same spray: 3 + 56 = 59. The release Poké Ball and its particles are
finished hundreds of frames before that scene.

Arc creates 9 sparkles on each of 6 steps (54). Circle creates 16, waits
until they finish, then creates 16 more. Spiral creates 4 every 8 steps
for 64 steps (32) and those sprites finish before the task ends.

## Return to field (C035)

`ResumeMap` resets sprites before `SpawnObjectEventsOnReturnToField`.
`StartWeather` and `ResumePausedWeather` do not create weather particles
on that frame. `SetUpFieldTasks` and the Mirage Tower blend create tasks
only. Reflections and map lights run after the object loop.

`RunOnResumeMapScript` runs the map's resume script to completion first.
The only sprite command in those scripts is `createvobject`, and the
largest one is the Dome final audience: 32 calls. Virtual objects use
`CreateSpriteAtEndUnchecked`, so a shortfall there skips a spectator
instead of asserting. Contest Hall's master audience is 27 and is the
next largest.

The object loop then creates at most `OBJECT_EVENTS_COUNT` (16) sprites.
The Dome room has 15 map objects, and the player fills the 16th slot.
Only the player object also creates a warp arrow. Link-player sprites
replace those object slots rather than adding to them.

Peak at the asserting `CreateSprite`: 32 + 16 + 1 = 49.

## Battle and contest (C001–C026, C160)

Battle setup resets sprites (`src/battle_main.c`). A doubles battle then
holds 24 sprites for the whole fight:

- 4 battler sprites
- 12 healthbox sprites (left, right, and bar for each of 4 battlers)
- 4 gimmick indicators
- 4 enemy shadows (two per opponent; `B_ENEMY_MON_SHADOW_STYLE` is `GEN_LATEST` and GBA-style sprites are off)

One move animation runs at a time. Snowscape and the other weather
animations are themselves that one move; they are not a second layer
under a later move. Snowscape's three flake tasks keep about 21 flakes
alive, which is under the HUD plus Glare.

The largest bursts on top of the 24 HUD sprites:

| Call | Burst | Total |
| --- | ---: | ---: |
| Glare eye dots, `tPairMax` 12 pairs | 24, if none have expired | 48 |
| Water Spout launch droplets | 20 in one loop | 44 |
| Eruption launch rocks | 7 | 31 |
| Grudge flames | 6 | 30 |
| Hail particles | paced, about 10 alive | 34 |

Hail's impact sprite is created and then the old particle is destroyed.
If that create were allowed to fail, the owner's child count would never
drop and the task would wait forever (`AnimHailBegin`). It does not fail
here. The other battle candidates create one sprite per step or a burst
smaller than the table above. Contest scenes keep fewer fixed sprites
than the doubles HUD, and they use the same animation tasks.

`CreateEnemyShadowSprite` (C025, C026) is part of the 24, created while
the pool still has the battler sprites and healthboxes only. Type icons
(C160) add one sprite per icon on top of that HUD.

## Menus that reset

| Candidates | Peak | Contents |
| --- | ---: | --- |
| Summary C149–C150 | 36 | Info-page icons stay allocated. Move-slot sprites (5 slots × 5) are destroyed before the conditions page adds 5 category icons, 10 sheen sparkles, and 5 max-condition sparkles |
| Bag C125, C127 | 34 | Cursor, 5 hover pieces, thumb, 2 arrows, item icon, 6 party icons, 6 status icons, held-item icon, 6 shop frames, 5 berry marks. ComfyAnim is not a sprite |
| Party C128–C136 | 54 | 6 icons, 6 held items, 6 status, hover, preview, shadow, 16 message, 6 multiuse, 7 select-frame, 4 move-type icons, counted as if every panel were open together |
| Pokéblock and condition sparkles C097, C161–C166 | 25 | 2 titles, 1 picture, 7 party/cancel icons, 5 up/down arrows, 10 sparkles |
| PokéNav conditions and markings C098–C102, C115–C118 | 25 | Main menu resets in `InitPokenavMainMenu`. Conditions adds the same party icons and picture; the markings menu adds 8 sprites on that screen |
| Pokédex areas C105–C106 | 33 | Player icon plus at most 32 area markers. The 3 Area Unknown sprites are created only when there are no markers |
| Region-map cursor C119 | 10 | Field and Fly reset, then cursor, player icon, and a few labels. Zoom frees the old cursor first |
| Pokémon Jump C107–C108 | 19 | Wireless indicator, 5 mons, 5 stars, then 8 vine sprites |

`CreateConditionSparkleSprites` writes `sprites[count]` after the loop.
That write expects every requested sparkle to exist. The condition screens
that call it top out at 25 sprites, so the loop does not stop short.
The summary screen's sheen helper already chains from the last sparkle
that was actually created. The SwSh markings cursor is dereferenced on
left/right, and party status graphics use the stored sprite id. Both sit
in scenes with free slots, so those reads are not reached with a missing
sprite.

## What this does not change

The 61 field sites fixed in PR #285 stay recoverable. Injecting a full
pool still crashes these 75 callers, and that is the intended guard.
Revisit a row above if a scene gains sprites, if `MAX_SPRITES` changes,
or if two of these overlays start staying on screen together.
