# Review of f1c1fd2392…05b37db1a9

Used `/Users/dayers/.agents/skills/code-review/SKILL.md`, with independent
read-only Standards and Spec reviewers. The fixed point is the merged BW UI
source from which this issue branch was created.

## Standards

No documented-standard violations or concrete correctness regressions found.
One non-blocking heuristic: possible Repeated Switches / Duplicated Code in
`DrawBattleEntryBackground`. Legendary, leader/champion and ordinary branches
now all invoke `LoadBattleEnvironmentEntryGfx()` because the captured bundle owns
selection. Collapsing those legacy branches is an optional cleanup; they are
retained here to preserve the recognizable special-intro control flow.

## Spec

No concrete Spec findings. Location palettes, naturally lit map eligibility,
frozen blending, fallback art, scene exclusions, entry slides, palette ownership,
mechanical independence, terrain restoration, cleanup and both evolution loaders
match the approved behavior. The reproduced menu-memory fix supports the required
restoration path and is within scope.

The reviewer identified a validation gap: morning/evening had capture coverage,
while menu returns were tested at night only. Added explicit morning/evening
Bag/Party return checks; the expanded restoration suite passes 55/55.

Totals: Standards 0 hard violations and 1 low-priority heuristic; Spec 0 defects.
