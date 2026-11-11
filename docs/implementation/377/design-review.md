# Independent design review

Reviewed both candidates against the issue 377 rubric and current source at 35bf05083e. This is a design review, not runtime verification. The reviewer used the inherited Codex model. No cross-model comparison occurred.

## Verdict

Select Candidate A, subject to the corrections below. Its 168-byte travel bank and monotonic identity avoid Candidate B's generation recycling and registry retention rules. Both candidates correctly reject raw personality/OT matching and slot identity.

Scores use five as strongest. They grade the proposed design, not completed behavior.

| Criterion | A | B | Reason |
| --- | --- | --- | --- |
| Identity and lifecycle | 4 | 4 | Both preserve hatch continuation, split Shedinja identity, reject ambiguity, and clear foreign imports. B adds generation retirement hazards. |
| Save compatibility | 4 | 4 | Both append v11 data and preserve old checksum widths. A leaves substantially more reserved capacity. Actual migration fixtures remain required. |
| Atomic exchange and mail | 4 | 4 | Both plan all final slots and mail before mutation. Implementation must eliminate all fallible work after the first write. |
| Departure ownership | 4 | 4 | Both use accepted source departures rather than active-region setters. Center 2F ownership needs the correction below. |
| Read-only checkpoint safety | 3 | 3 | Both use destination region and proposed party. Neither has yet authored the complete predicate inventory, so this remains implementation work. |
| Maintainability | 5 | 3 | A has direct ordered identity references. B adds indexes, generations, and retention accounting for only eighteen references. |

## Required corrections

1. Candidate A's Hoenn opening predicate is wrong. `VAR_LITTLEROOT_INTRO_STATE >= 7` does not establish Birch handover completion. `data/scripts/players_house.inc:167` sets 7 after watching the broadcast, before the rescue. `data/maps/LittlerootTown_ProfessorBirchsLab/scripts.inc:18` documents lab state 2 as chosen starter and state 3 as received starter in the lab. The completed handover writes `VAR_BIRCH_LAB_STATE = 3` at line 134. Use that boundary and a separately justified mature-progress fallback. Test intro state 7 with lab state 0 and lab state 2 as negative controls.
2. Do not classify every Pokemon Center second floor as neutral for departure capture. `data/scripts/cable_club.inc:1373` defines the champion Hub Pad on regional second floors. The accepted branch warps at line 1380. Preserve the physical campaign of these floors while excluding them from Center checkpoints. Actual link-session rooms and temporary facilities can remain neutral. Add a controller or route audit case for this pad.
3. Correct Candidate A's rollback explanation. `src/save.c:930` already refuses a newer save version. A v11 save should be refused by the current v10 build rather than silently losing history. Document refusal and preservation of a pre-upgrade backup. Do not promise that downgrading and saving works.

## Grafts and implementation constraints

Keep Candidate B's explicit import-boundary warning. Duplicate detection alone cannot reject a foreign Pokemon that carries the token of a released local Pokemon when no other match survives. Clear foreign tokens before acquisition. Both candidates already favor first-memory allocation rather than allocation during every CreateMon call.

Use Candidate A's species-only historical display. Available members show current names. Unavailable rows show remembered position, species, and reason. This satisfies the required useful metadata without spending the remaining save budget on copied combat data or registry machinery.

Migrate the persisted party before runtime loading. `src/save.c:942` calls migration during load, and `src/load_save.c:687` later copies the persisted party into the live party. Clearing only gPlayerParty would leave old unused bits active after Continue. Audit every persisted Pokemon owner and backup. The migration must not fabricate references or checkpoints.

Checkpoint safety remains unverified until the full inventory and its actual exit/access rules exist. Do not count a generic predicate API as proof of safe island, League, or Sevii travel. Include a case where the destination's badges and recalled party disagree with the current campaign and carried party.

## Review boundary

No application files changed. This report selects the design and names specific source-grounded corrections. The accepted implementation still needs transaction conservation tests, lifecycle tests, controller travel, save/reload, all checkpoint rules, and the final regression gates listed in acceptance.md.
