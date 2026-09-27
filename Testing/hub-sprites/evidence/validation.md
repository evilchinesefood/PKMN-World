# Issue #330 validation

## Scope and source

- Game source: `13478c088b0dcb2a28c3c453ed6eac0e8040364b`.
- Integrated master: `ca5c9d2c99b183a3c52cb036102c6f5b2ef15165` (PR #340 merged after its follow-up review and all CI checks passed). The subsequent branch merge changes no gameplay inputs relative to the tested source.
- Before repository source: `732f15cec3f8459da98c4d7076e72b084c4abda4`; its ROM was compiled from `05b37db1a9b1dd8efda95233e4a61822680bba7b`. The intervening commits only add/fix evidence and documentation.
- Parsed map comparison proves exactly two changed `graphics_id` fields, events 12 and 13. All other map fields, fourteen events, scripts, positions, elevations, flags and movement types are identical. No global graphics definition or asset was edited.
- ROM/save hashes, fixture and suite hashes: [delivery.json](delivery.json). Full fixture provenance: [baseline](baseline-fixture.json), [feature](feature-fixture.json).

The clean committed build stamp is `v1.6-31-g13478c088b`, verified against the ROM's encoded text. [Binary comparison](rom-byte-diff.json) finds exactly sixteen changed bytes: four bytes for the two graphics IDs and twelve version-text bytes. The original artwork change is commit `388338478e17989b7428bbce07a7776ab23db9d3`. The delivery was rebuilt after committing so its visible version matches its source, then all checks below were rerun on that final binary.

## Results

| Check | Result |
| --- | --- |
| Matched baseline capture | 30/30 |
| FRLG NPC facing, walking, shadow, exact loaded palettes | 66/66 |
| Intro + every service approach, three follower variants | 412/412 |
| 12 gender/outfit choices × 2 entry paths × noon/night, menu returns | 997/997 |
| 10 outdoor capture anchors × 3 followers × noon/night | 480/480 |
| Prepared save, flash completion and reload | 16/16 |
| Unmodified ROM, prepared save, ordinary-controls owner route | 9/9 |
| Tracked Lua sweep | 50/50 suites, fresh ROM-stamped sentinels |
| Development + release configurations | Both build successfully |
| `make validate` | Pass; existing review/allowlist counts unchanged |

The targeted feature total is **1,980/1,980**, plus the 30 baseline checks. The full tracked sweep includes `OwMonSprites`, both Hub intro suites, the nurse-monitor check, stairs gate, Hub Pass return and Bnet terminal. See the logs and sentinels in this directory. The baseline's previous full sweep was also 50/50; its log is included separately and never counted as validation of the new ROM.

No battle-engine source changed. PR #340's final CI battle suite, shipping build and three off-switch builds passed before merge. The new feature PR runs the same CI gates independently.

## Visual and runtime findings

- Eleven native-resolution matched comparisons: all ten changed NPC views differ only inside the corresponding character's 16×21-pixel footprint. The nurse/Chansey control screenshot is pixel-identical (zero changed pixels). Exact bounds/counts are in `../review/capture-sources.json`.
- Each NPC's palette is checked against all fifteen opaque source colors and the tag's **actual allocated slot**. This expansion dynamically allocates object palettes; `graphicsInfo.paletteSlot` is not an ownership guarantee. No source palette change or allocation patch was necessary.
- All four directions, live walking out/back and a temporary jump exposing the shadow are captured. Animation WebPs are lossless; the renderer verifies decoded source pixels at their sample timestamps and total duration.
- Pichu supplies the small silhouette, Snorlax the large indoor-supported silhouette, and shiny Snorlax the shiny case. Each uses a 32×32 sheet, with visibly different occupied pixel areas. Species, shininess, source palette, actual visibility and follower adjacency are checked independently.
- Every Hub service approach is reached by normal walking after the intro. All fourteen NPCs are sampled visibly across the route. Peak active objects: 14 during the service run, 13 during the outfit matrix, and 11 in both matched comparison runs. These are camera-dependent counts, not an assertion that all fourteen NPCs plus player/follower must coexist on every frame.
- The intro uses the existing engine behavior: pocket the follower during scripted movement, then restore it when control/normal walking resumes. Three follower variants complete all nine stops, and the curator returns to normal service behavior.
- West entry is an actual descent on the 2F escalator, including the real 1F landing walk. It is not simulated by putting the player at a western coordinate. Both genders and all six outfits retain their actual player palettes through entry, day/night state and menu return.
- Outdoor screenshots preserve natural hide flags, movement and collision. CSVs list actual active/visible objects and their current positions separately from the authored anchors. Route 35's moving Growlithe/Yanma and National Park's day/night population therefore are not falsely counted as stationary, simultaneously present objects.
- The specified outdoor capture approaches support normal movement with each follower. No reproducible obstruction requiring a coordinate change was found in these sampled scenes. This is local readability evidence, not a claim of exhaustive pathfinding coverage for the entire two maps.

## Fixture boundaries and limits

Only the two Hub graphics IDs ship. Fixtures are linked into verified-unused padding of disposable ROM copies and never into the delivered game. The fixture seeds synthetic parties/outfits/time, warps to evidence viewpoints, temporarily poses the two NPCs and marks Route 35's nine trainers defeated solely to prevent battles interrupting visual captures. It does not move the outdoor Pokémon or disable their collision. The west-entry test alone sets the synthetic champion flag. The delivered save comes from a separate fresh run without that flag or the Route 35 trainer changes.

Initial fixture runs caught incorrect *test* assumptions: static palette slots, an approach below the curator's counter, tree-tile outdoor viewpoints, and checking flash-save completion too early. Those fixture assumptions were corrected; the game change stayed at two graphics IDs. Curator dialogue is allowed to finish fully before walking resumes. Only the completed corrected runs are included and counted here.

Validation uses the repository's Lua-enabled headless mGBA and pinned RTC. Hardware and other emulator frontends were not run. The optimized release configuration was compiled; per `RELEASING.md`, the prepared owner package uses the fully tested development configuration. No ROM or save is committed or uploaded to GitHub.

## Gallery review follow-up

The renderer now requires a positive completed baseline and every feature run,
matching PASS sentinels, no FAIL sentinel, and a completed current runner verdict for every run, including delivery. Baseline checks are recorded separately from the
1,980 targeted total. Failed preflight creates no output. The README now
packages `review/`, `evidence/` and its guide under one serving root; the
optional download manifest/ZIP share that root. HTML and manifest writes use
explicit UTF-8. [Black-box checks](renderer-check.log) cover nine rejected
stale/failed inputs, ASCII-locale output, totals, label escaping and all HTML
file links. No game source, ROM, save or media pixels changed in this follow-up.

The delivery command redirects stdout before launch. Its runner output is
mandatory, so early ROM-guard failures cannot reuse an older delivery log and
PASS sentinel. Missing delivery output and an aborted delivery retaining old
artifacts are both regression cases. The documented command was rerun on the
unmodified delivery ROM: 9/9.
