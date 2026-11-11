# Independent implementation review

Reviewed the working tree against base `35bf05083e`, including new regional travel and Center modules, save migration, identity lifecycle hooks, departure scripts, three Fly callers, and supporting tests. This is an inherited Codex review; no cross-model comparison occurred. Application files were not edited.

## Verdict

Source review approved after correction: no confirmed correctness findings remain in the reviewed source. Runtime acceptance remains conditional on the new corruption regression tests and the final gates below. The implementation has a coherent plan-before-commit exchange, references current individuals instead of saved copies, preserves old structure offsets, and separates physical departure ownership from the active campaign.

### Resolved P2: Preview reads could mutate authoritative Pokemon data

The original implementation at `src/regional_travel.c:57-65` called `GetBoxMonData(..., MON_DATA_SPECIES)` on the original Pokemon while scanning party, PC, daycare, and fusion ownership. `src/pokemon.c:2139-2140` invokes `IsBadEgg`; lines 2034-2038 set the original `isBadEgg`, `isEgg`, and encrypted egg bit when a checksum is invalid. An unrelated corrupt boxed Pokemon is therefore changed by opening the recall preview, including previews subsequently canceled or refused. Departure validation can mutate the same way before it returns failure. This violates the explicit no-mutation preview/refusal contract, and existing normal-data snapshot tests do not cover it.

The follow-up introduces `ReadBoxData`, `ReadMonData`, and `ReadBoxNickname`, which operate on local copies. Bad-egg status reads explicitly force checksum validation on that copy before returning the status. All ordinary getters in the regional travel module are now confined to those wrappers. Both preview choices and departure capture use them; Center predicates receive the proposed party copy. Corrupt outgoing Pokemon are rejected before an exchange writes. This fixes the reported source path.

Three new tests cover unchanged corrupt storage during preview/refused allocation, preserved corrupt occupied slots during full-PC exchange, and corrupt outgoing-party refusal. They use raw state hashes or `memcmp` rather than ordinary getters to compare the damaged records. Their successful execution must still be recorded; the inspected 33/33 targeted log predates this new regression set.

## Additional review observations

- The final party, outgoing deposits, released PC slots, mail moves, follower remapping, warp, and recovery are planned before the exchange writes. Equal-size full-PC exchange and retained individuals are handled without cloning.
- Hatch continuation preserves identity, Shedinja clears the copied identity, incoming trades and Mystery Event imports clear foreign identities. Existing BoxPokemon layout widths are retained and v11 migration clears persisted party, PC, daycare, Route 5 daycare, and fusion identity bits.
- Accepted regional ferry and hub routes capture before boarding. Neutral-map classification prevents neutral parties from replacing a campaign memory. All three callers handle the changed Fly destination return type.
- Center predicates inspect the proposed party and destination badge bank. The inventory validator establishes authored arrival/exit tiles and recovery mapping, but does not by itself prove all outdoor escape routes or story scenes. Hoenn League currently checks only eight badges. Hub Pass is permitted by the current item guard in an ordinary League lobby; any reliance on that escape needs an explicit recorded acceptance case, not a generic assumption that the pass always works.
- Center entry is recorded in LoadMapFromWarp. Actual whiteout arrival also reaches this hook; changing only the respawn target does not. Ordinary Continue uses a separate map load path. The issue excludes respawn writes without a visit, not physical whiteout arrival, so this is not a defect.

## Comments and evidence

The added application comments describe save-version compatibility, persistent Center IDs, coordinate-sensitive scenes, and the existing getter's mutation semantics. No inaccurate or obsolete comment requiring deletion was identified. Zero comment deletions or restorations; no separate comment subagent was spawned under this review's no-nested-agent scope.

`git diff --check` passed during review. The latest inspected targeted C log (`feature-check-targeted-3.log`) reports 33/33 passes before the corruption regression additions; this review did not independently rerun that emulator job. The recorded baseline log paths and offline migration artifacts exist. `decisions.tsv` explicitly corrects its initial placeholder timestamp and identifies its evidence paths; its VERIFIED rows concern their named baseline/design/migration checks, not full feature acceptance.

`acceptance.md` still marks every row Pending. That is appropriately conservative while controller work and regression gates remain unfinished, but it must be replaced with concrete results and limitations before delivery. This review does not certify a complete Lua sweep, full final make check, feature-off builds, or natural playthrough acceptance.

## Final execution follow-up

The root agent completed the full C suite after this source review. All three corruption regressions passed within the 5,119 passing tests. The default build, host validation, full 56-suite overworld sweep, expanded 221-assertion travel suite, and all three feature-off builds passed. The explicit Hoenn League Hub Pass escape also passed. See [verification](verification.md) for counts, commands, provenance and limits.
