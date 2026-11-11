# Regional team recall and safe resume

## Workflow

- [x] Read the Principles section of poteto-mode.
- [x] Phase A: Frame.
- [x] Phase B: Design the workflow.
- [x] Phase C: Run the loop.
- [x] Phase D: Keep the audit trail.
- [x] Phase E: Verify and hand back.

## Implementation and verification sequence

1. Ground identity, save compatibility, actual departures, Center entry, and existing test tools.
2. Compare two complete identity/transaction/checkpoint designs and review the selected contract.
3. Implement and verify identity persistence and legacy defaults.
4. Implement accepted-departure capture and atomic party exchange with the normal hub UI.
5. Implement the complete Center inventory, actual entry capture, destination validation, and resume UI.
6. Verify all campaign pairs, same-region travel, ferries, opening protections, mail/storage failures, identity lifecycle, and save/reload.
7. Run final build and required release gates, independent code review, and native emulator scenarios.
8. Commit ordered changes and open a ready PR. Do not merge.

## Throughput checkpoint

- Blocking first steps. Inspect current master and save format before allocating bytes or writing feature logic.
- Independent workstreams. Read-only design alternatives and verification inventory can run independently. Implementation has one owner.
- Shared mutable state. The isolated worktree owns the feature. The original checkout and UI-review files are untouched. Shared save and travel changes are serialized.
- Smallest safe decomposition. One implementation owner coordinates identity, exchange, and resume because their correctness depends on the same proposed final party and commit boundary.

## Completion predicate

All approved behavior and acceptance cases in GitHub issue 377 must be implemented together. Tests must exercise authoritative Pokemon movement, normal controller travel, Center entry without healing, correct recovery, migration without fabricated history, and refusal/cancellation without mutation. Compilation or source assertions alone do not establish gameplay acceptance. Record exact commands, configurations, commit and ROM hash, with any unverified behavior identified explicitly.

## Design rubric

Compare complete designs for stable identity and lifecycle coverage, supported save compatibility, atomic exchange and mail conservation, explicit departure ownership, read-only destination validation, and maintainability of normal gameplay UI and tests.

## Delivery

Ready pull request [#385](https://github.com/evilchinesefood/PKMN-World/pull/385) contains both features and the acceptance evidence. It remains unmerged. Local gates passed; GitHub Actions results are separate from the local evidence.
