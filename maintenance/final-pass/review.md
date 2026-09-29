# Adversarial review of the last 30 commits

Baseline: `e38ee10ffb01c45d5e125dc7cfc5601a467c7c29`. Selection is exactly
`git log -30` at that revision, recorded in [reviewed-commits.txt](reviewed-commits.txt).
It is not the different set obtained by walking thirty first-parent ancestors.
Each selected commit was examined against its first parent; merges were also
compared with their feature parent. Two independent reviews covered documented
standards/evidence contracts and behavior/specification. Their findings were
reproduced before fixes. No commit was accepted solely from its subject line.

## Findings and disposition

| Finding | Impact and evidence | Fix / verification |
|---|---|---|
| Optional Mystery Gift/Event main-menu rows clip outside WIN0 after panel resizing | Dormant shipping configuration (`LINK_MYSTERY_GIFT`/events off), but an enablement regression. Production task-layout test failed at 3/8 before the fix. | Gift scrolls 32 px at its fourth row; Events scrolls 48 px when first entering lower rows. Return/restore/highlight offsets match. `check_optional_rows.lua`: 8/8 on the fresh ROM. |
| Hub gallery accepted a PASS verdict before a nonzero runner exit | Publisher could treat a failed capture as successful. Prior checks examined a verdict anywhere in the log. | Require a terminal verdict, allowing only the exact successful runner trailer. Negative tests reject failed exits, later failure text and aborted stale-PASS runs; both successful formats pass. |
| Lighting gallery accepted wrong/partial feature suites and duplicate or zero-assertion sweep rows | Incomplete evidence could satisfy its publishing gate. | Require lifecycle 48, delivery 3 and capture `6 × scene count` assertions (294 for 49 scenes); correct suite names, unique 50/51 regression rows and positive equal counts. Eight negative cases plus a complete contract pass. |
| Outfit delivery instructions omitted creating/populating its scratch library; exporter failed on a new parent directory | A fresh clone could not follow the documented reproduction commands. | Explicit mkdir/copy/current-symbol/expected-table/empty-hook setup; exporter creates its parent. Fresh nested export works. |
| Incremental build ignored palette `.pla` light-marker sidecars | Fresh and cached ROMs differed in 47 palette high-bit bytes; affected all-region warm-window assets. Generated palette rules listed only `.pal`. Adding/editing/removing a sidecar could leave stale night lights. | `scaninc` emits optional sidecar and source-directory prerequisites; Make regenerates dependency files when scaninc changes. Actual generated-rule regression failed before fix and passes 4/4 afterward. Incremental/fresh ROMs match. |

Two additional issues outside the selected thirty-commit behavior were repaired:
an invalid return warp in a sealed Hoenn league 2F, and the visual fixture builder's
Unicode decoding of a Git diff containing binary historical palettes. The builder
now hashes raw diff bytes. An obsolete respawn TODO was corrected without changing
behavior. No confirmed active campaign regression was found in these thirty changes.

## Commit-by-commit result

| Commit | Claim checked and adversarial result |
|---|---|
| `e38ee10ffb` | World Panels merge: tree matches feature parent; main/options/relearner code retained. Optional lower-row clipping found and fixed above. |
| `1c74905686` | Remaining menu title case: action strings change while battle command labels intentionally stay uppercase; no command-ID/routing change. |
| `24aec5f0e3` | Panels/readability: background tile allocation, moving BG/static windows and main-menu borders inspected; optional Gift/Event window bounds were incomplete. |
| `bb5d17896a` | Frontage merge: feature tree preserved, no event or collision change hidden in merge. |
| `4c7e578c9e` | Frontages: source edits regenerate committed map data; 25 affected metatiles checked. Collision, events and scripts preserved. |
| `cf66c5e65d` | Road-edge merge: feature tree preserved; preceding gardens survive. |
| `bca2206cb4` | Road/garden transitions: 70 affected tiles regenerate correctly; map borders, walkability and event positions preserved. |
| `e97b94307f` | Garden merge: feature tree preserved. |
| `78e9c1f985` | Garden proof binding: before/after and delivery hashes/suites checked; archived evidence remains tied to historical builds. |
| `a1cba5f7fa` | Gardens: 59 metatile edits regenerate correctly and retain collision bits/events; later frontage/transition edits compose rather than overwrite the pass. |
| `63c328ee3d` | Regional lighting merge: feature parent retained; map geometry/events untouched. Sidecar dependency gap independently exposed by fresh build. |
| `adccc8bcfb` | Clean lighting baseline: checkout/commit/ROM binding inspected, rather than assuming a dirty build matched a named revision. |
| `f597f3b77c` | Delivery/fresh audit gate: intended requirements present, but assertion counts and sweep uniqueness remained insufficient; now fixed. |
| `c211371569` | Lamp removal: final tree removes additions while keeping warm-window palettes/night metatiles; geometry/events/attributes preserved against pre-lighting source. |
| `e54f2bfabb` | Regional windows/lamps: lamp addition was deliberately superseded; current lighting is 49 towns without new lamps. Palette sidecars were not tracked by incremental builds. |
| `017a59de34` | Outfit merge: feature tree preserved; protected palette ownership retained. |
| `64a6575b9e` | Portable outfit instructions: relative bundle guidance correct, but scratch-library setup incomplete; repaired. |
| `56b7f93ad4` | Outfit captures: every gender/color/layout surface and genuine Oak input path examined; evidence is historical, not today's fresh-build proof. |
| `fab4890260` | Colorways: masks leave skin/white/ink/hair protected, Red returns before swaps, reflections inherit live palette. No unsupported separate reflection recolor claimed. |
| `58d972c6c3` | Warm-window merge: feature parent retained. |
| `8a1abe1495` | Binary snapshots: `.pal.bin` avoids text palette conversion for new runtime evidence; earlier binary-looking archives preserved as history. Raw-byte diff hashing now handles both. |
| `11409b5f75` | Warm transitions: palette-phase/restoration evidence checked, including before/after provenance and source geometry exclusions. |
| `3bc343d033` | Six Johto panes: palette/night-metatile edits checked; geometry/collision remain unchanged. Later regional lighting retains them. |
| `5defc44ffd` | Hub sprite merge: feature tree preserved, only intended researcher/gentleman art replaced. |
| `124e190e1a` | Current delivery logs: additional gate exists, but runner exit handling was incomplete; repaired. |
| `01faa52405` | Failed-capture rejection: catches assertion failures but could accept a later nonzero runner exit; reproduced and repaired. |
| `42f99d8069` | Clean Hub evidence: published captures/hashes bound to actual historical build; not reused as current execution evidence. |
| `13478c088b` | Hub review docs: sprite dimensions/palette/source and real-scene checks agree with changed art; setup commands updated for consolidated paths. |
| `d1dafab57f` | Remote master merge: first-parent tree is unchanged; no concealed production change. |
| `ca5c9d2c99` | Battle palette merge: feature tree retained; visual resolver keeps gameplay environment separate, terrain backgrounds win, frozen tint restores from authored colors, loaders/cleanup clear snapshot. |

## Interactions and review limits

All nine feature-merge trees equal their feature parent's tree; the remote-master
merge is empty against its first parent. Combined Viridian garden/edge/frontage
changes regenerate the committed blocks. Combined lighting passes preserve every
map cell/border/event/script/metatile attribute against their pre-lighting source.
Outfit color masks preserve protected colors and existing reflection/weather
ownership. UI allocations were checked alongside BW battle windows and battle
background restoration. The review decoded 810 unique PNG/WebP evidence files
and verified the 12 World Panels capture hashes.

The source-only gallery validators cannot reproduce a *fresh* complete Hub gallery
from trimmed archived evidence: some raw runners/PNGs are absent there. Negative
contract tests run independently against temporary real files. We preserve the
archive and do not manufacture missing logs. New screenshots and the fresh
51-suite sweep have their own recorded ROM hashes.

Repeated equivalent switch branches in battle presentation are a maintainability
observation, not a proven defect; no speculative refactor was made. Automated
coverage is substantial but does not replace all three campaign playthroughs or
all post-game state permutations. Source/ROM labels supplied by gallery callers
remain provenance assertions; the new evidence records its hashes explicitly.
