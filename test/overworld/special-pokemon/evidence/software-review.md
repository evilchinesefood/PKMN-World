# Independent software review for issue 386

Reviewed the working implementation against baseline `534c199cc2`, including untracked collection source and test files. This is an independent same-model-family source review. It is not a merge verdict. Artwork, a complete ROM build, and runtime acceptance are still missing.

## Findings

1. **P2, corrected in source. Handle allocation failure inside the icon API.** The new Forms calls at `src/pokedex_plus_hgss.c:6958` and `:6966`, and checklist call at `src/special_pokemon_menu.c:78`, guard the returned sprite ID. Before correction, `CreateMonIconSprite` used `CreateSprite`, whose exhaustion assertion fires before those caller guards. The helper and public wrappers also unconditionally updated the returned slot. The fix now uses `CreateSpriteUnchecked`, returns the sentinel before touching that slot, and guards both wrapper frame updates. I inspected and accept this source correction and confirmed its targeted compile log. The focused failure/recovery fixture remains unrun. Precision correction to the initial review message: `gSprites` has an extra dummy slot, so this was an assertion and dummy-slot update problem, not an array out-of-bounds claim.

2. **P2, corrected in test source. Assert that Forms pages contain the expected active icons.** The first `ui.lua` version only tested uniqueness for valid-looking handles, so an empty page could pass. The updated `checkFormsIcons` now requires the exact visible count, active and distinct sprite handles, an active base icon and cursor, and sentinels in unused slots. The checklist also requires five list icons and one detail icon. I inspected and accept this test correction. Its Lua/synthetic-helper checks do not replace the pending ROM run or image inspection.

No additional confirmed defect was found in the bounded review of catalog mechanics, append-only form tables, source quests, gift/capture/trade collection marks, or the new menu lifecycle. That is a source-review finding, not proof of runtime behavior.

## Evidence boundaries

- The host source interpreter replaces C specials and skips rendering and battle execution. Its successful source-flow checks do not prove actual capture, battle loss, or storage delivery behavior. The existing report labels host interpretation separately, which is correct.
- `sources.lua` exercises gifts and quest conversations but declines the four catch targets. It does not prove successful catches, run/faint/defeat recovery, or save/Continue behavior. The separate mechanics fixture calls generation/delivery functions directly. Do not report those as natural capture flows.
- The prepared UI fixture has not run. It currently covers Pikachu and Unown, main-list checklist entry, detail navigation, and selected cleanup paths. Search-result entry/return, other newly expanded families, allocation failure, and native icon appearance require targeted observation before claiming the entire Forms acceptance criterion.
- The audit trail's initial artwork row cited pre-generation grounding. A superseding row now points to `tools/special_collection/README.md`, which records the two rejection results. This evidence-pointer issue is corrected. The baseline and compile log pointers match the limited claims made in the trail.

## Comment review

No new phase-narration comments or unsupported constraint comments were found. The changed case labels retain existing local style, and the flag allocation marker is useful with the compiler-based collision audit. No deletions, restorations, or prose-driven code changes are recommended.

## Merge boundary

No unresolved source defect remains from this bounded review. Do not treat host checks or per-object compilation as a green feature. Finish real artwork and declarations, build the actual ROM, run the prepared focused suites and allocation fixture, and inspect the resulting visuals. No placeholder recommendation is made.
