# Design verdict for issue 386

PASS TO IMPLEMENT. Use candidate B's ownership split with candidate A's mechanics hooks. This is an independent same-model-family review of the two grounded designs, not runtime verification or a cross-model comparison.

| Criterion, 1 to 5 | A | B | Evidence |
|---|---:|---:|---|
| Save and identity compatibility | 5 | 4 | A specifies append-only form IDs, lazy identity allocation, legacy-cap isolation, and actual-ownership scans. B preserves save layout but delegates these details. |
| All-ten coverage and recovery | 4 | 4 | Both use the ten-entry registry and success-only marks. B gives concrete quest ownership and repeat-encounter visibility. Neither has implemented evidence yet. |
| Bounded UI | 2 | 5 | A flags the issue but does not specify allocation or exit paths. B gives a fixed visible sprite array, page navigation, and cleanup on every transition. |
| Maintainability | 4 | 5 | B keeps local quest dialogue in existing scripts and centralizes shared acquisition rules in C. Both avoid an extra save structure. |

Use one catalog for species, base species, move, level, source kind, unlock and collection flags, display name, location, and direct hint. Species metadata owns art through the catalog's species ID. Scripts own the four short task sequences and unlock sources. Only successful delivery and reconciliation set collected flags. Reuse the ordinary gift and wild-battle flows.

Graft A's explicit random-form exclusion, both Move Reminder hooks, new-record creation, trade marking, and complete ownership reconciliation into B. Keep B's 12-visible-icon Forms state and normal text window for the new Pokédex menu entry. Reject a new C quest framework because it duplicates existing script state and dialogue control.

Implementation conditions, not unresolved product questions:

- Audit the old SPECIES_EGG sentinel before assigning the first new custom ID. The current proposal moves it. Demonstrate that no supported save path persists the sentinel as a real species, or retain its numeric value. Preserve all real species and form indices.
- Confirm the flag window with expanded constants. The comment identifying 0xDD0 is a lead, not collision proof.
- Keep legacy-cap recognition separate from the collection-species predicate. Recognition may add its checklist mark. It must not change its shininess, gender, mechanics, or distribution.
- Inspect field-HM eligibility. A granted Surf/Fly move must remain usable through ordinary gates without granting the exception to ordinary Pikachu. Follower/mount selection can have its own eligibility test.
- Make the Treecko reveal recompute from permanent unlock state on load, including old saves whose new hide flag starts clear. A battle must not consume the unlock.
- Free only successfully allocated icon handles, and cover A-to-info as well as B/Start exits and page changes. Include sprite-allocation failure in the bounded design.
- Full storage must retain unlock and leave the collected mark unset. Capture failure/run/defeat must leave a deliberate retry, not immediately retrigger battle.
- Artwork needs actual native-scale and emulator inspection. A complete manifest or valid indexed PNG does not establish readable accessories or correct mounted overlays.

No design blocker prevents implementation. These conditions are merge gates. The planned focused checks should cover every catalog row and each distinct recovery path. Keep host, headless-runtime, and observed visual evidence separate as the issue requires.
