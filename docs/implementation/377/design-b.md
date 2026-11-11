# Candidate B. Bounded remembered-member registry

This is a source-grounded design, not implemented behavior. The baseline is master 35bf05083e with save format 10. The feature must migrate to format 11.

## Caller usage

The ordinary accepted Hub Pass path calls `RegionalTravel_RecordDeparture(REGION_JOHTO)` immediately before its irreversible warp dispatch. It obtains ownership from the source map classification, never from the active campaign fallback. A Johto ferry calls the same operation at confirmed boarding. Frontier departures pass no campaign and record nothing.

A hub attendant calls `RegionalTravel_Open(REGION_JOHTO)`. The module owns team choice, destination choice, preview, explicit partial confirmation, and final commit. Scripts do not deposit the party or switch campaign while this dialog is open. Cancel releases the script without changing persistent state.

The completed Center map-entry path calls `RegionalTravel_RecordCenter(mapGroup, mapNum)`. This matches an explicit table. It does not run on Continue, a synthetic respawn update, an exterior visit, or an excluded facility.

## Data shape

Use an eighteen-entry registry because three six-member memories can reference at most eighteen distinct individuals. Each remembered lineup holds registry indexes. Each tagged Pokemon holds a twenty-bit token split across existing encrypted unused bits. Tokens encode an eighteen-entry slot index and a fifteen-bit generation. Tags are allocated only when the Pokemon first becomes remembered, rather than on every Pokemon creation.

```c
#define REGIONAL_MEMBER_CAPACITY 18
#define REGIONAL_TOKEN_INDEX_BITS 5
#define REGIONAL_TOKEN_MAX_GENERATION 32767

struct RegionalMemberRecord
{
    u16 generation;
    u16 lastSpecies;
    u8 lastNickname[POKEMON_NAME_LENGTH + 1];
};

struct RegionalTravelSave
{
    struct RegionalMemberRecord members[REGIONAL_MEMBER_CAPACITY];
    u8 teams[3][PARTY_SIZE];
    u16 lastCenter[3];
};

enum RegionalMemberAvailability
{
    REGIONAL_MEMBER_PARTY,
    REGIONAL_MEMBER_PC,
    REGIONAL_MEMBER_DAYCARE,
    REGIONAL_MEMBER_MISSING,
    REGIONAL_MEMBER_AMBIGUOUS,
};

struct RegionalTravelChoice
{
    enum Region destination;
    enum RegionalTeamChoice team;
    enum RegionalArrivalChoice arrival;
    bool8 partialConfirmed;
};

struct RegionalTravelPlan
{
    struct Pokemon finalParty[PARTY_SIZE];
    struct RegionalMemberLocation sources[PARTY_SIZE];
    struct RegionalStorageWrite outgoing[PARTY_SIZE];
    struct MailStruct mail[MAIL_COUNT];
    struct WarpData arrival;
    u16 recovery;
    u8 partyCount;
    u8 followerSlot;
    enum RegionalTravelFailure failure;
};

u32 RegionalIdentity_Get(const struct BoxPokemon *mon);
void RegionalIdentity_Clear(struct BoxPokemon *mon);
bool32 RegionalTravel_RecordDeparture(enum Region physicalSource);
void RegionalTravel_RecordCenter(u16 mapId);
void RegionalTravel_Open(enum Region destination);
```

The actual struct layout must be measured with the target compiler. With a thirteen-byte nickname buffer, each record rounds to eighteen bytes. Eighteen records, eighteen lineup indexes, and six checkpoint bytes require 348 bytes. The current 360-byte SaveBlock3 budget therefore leaves twelve bytes. Add assertions for this budget, the unchanged eighty-byte BoxPokemon, and old RegionSave offsets. Do not allocate those twelve bytes casually. A bit-packed metadata representation could reduce cost, but is not needed for this candidate.

Zero lineup indexes mean absent members. Valid indexes are one through eighteen. Zero tags mean never remembered. A tag is `(generation << 5) | index`. Generation zero is invalid. Neither species nor nickname participates in identity.

## Registry lifetime

Capture constructs the complete replacement lineup off to the side before mutation. Count the union of references after replacing the source lineup. Retire only entries that no remaining regional lineup references. Preserve each retired slot's last generation so reusing the slot produces a different token.

For every outgoing individual already associated with a unique live token, reuse that registry entry. Otherwise allocate an unreferenced entry and advance its generation. Retain missing members' entries while another region still remembers them. This preserves truthful unavailable previews and prevents a released member's slot from silently becoming a replacement Pokemon.

A full capture can always fit the distinct-reference count because two other memories use at most twelve entries. Allocation can nevertheless fail after a slot has exhausted all generations. Never wrap a generation. Refuse departure before any mutation and explain the inability to record safely. A wider token would reduce this theoretical limit but adds header-bit maintenance.

Resolve a token across authoritative player party, shared PC, both normal daycare slots, and Route 5 daycare. Available means exactly one matching authoritative Pokemon in the party or PC. A sole daycare match is unavailable. Multiple matches are ambiguous and unavailable. Temporary facility copies are not additional authoritative individuals, but their restore paths must preserve tokens and prevent stale tags from returning as replacements.

Incoming link or mystery-gift Pokemon must have foreign tags cleared at the acquisition boundary. Otherwise a single imported individual could satisfy a missing local token without producing a detectable duplicate. NPC trades create a new untagged Pokemon. Clearing on import makes a traded-away original remain unavailable if it returns through an import path. That behavior needs an explicit product decision if link-return continuity later becomes a requirement. The current issue explicitly covers NPC trades, not cross-cartridge identity federation.

Creation stays untagged. Ordinary structure copies used for movement preserve the tag. `CreateHatchedMon` saves and restores the tag because it reconstructs the egg through `CreateMonWithIVs`. `CreateShedinja` clears the copied tag on the new Shedinja while retaining Nincada's evolved continuation. Release requires no registry mutation. The reference remains and resolves missing. Tags must not be inferred from OT/personality when absent.

## Compatibility

Append RegionalTravelSave after the existing Johto trainer bank. Preserve RegionSave checksum width 1232 for pre-v11 formats, since checksum validation precedes migration. Keep all existing v10 migration behavior.

The v11 migration zeroes the new registry and checkpoint bank. It clears the twenty newly interpreted bits on all authoritative Pokemon locations, including both daycares. It preserves all other fields and recomputes Pokemon checksums through the normal setter. If saved temporary party backups can later become authoritative, clear their new bits too. Do not derive team history from the current party or checkpoint history from last-heal state.

Older builds must refuse newer save versions. Verify their existing gate and document rollback limits. No live bytes, deprecated difficulty bit, Pokemon-size change, or map-number-dependent checkpoint IDs are part of this design.

## Exchange ownership

`regional_travel.c` owns the registry, resolver, exchange planner, UI state, and commit. `regional_centers.c` owns the checkpoint table and predicates. Identity accessors belong in `pokemon.c` because they know encryption and checksums. Public scripts call one hub operation and one accepted-departure operation rather than sequencing partial transfers.

The planner copies the proposed final party in remembered order, skipping unavailable indexes only after explicit partial confirmation. It preserves latest authoritative stats, moves, items, HP, status, and identity. A carried member goes directly into the final party. A PC member frees its own PC slot. Outgoing carried members first occupy those freed slots, then pre-existing empty slots. Refuse only if this complete arrangement cannot fit.

Precompute mail detachment into a shadow mailbox. Only outgoing carried Pokemon need detachment. Preserve incoming carried mail slots and text. Require enough free mailbox slots before mutation. A PC member cannot legitimately carry held mail. Treat malformed ownership as a preflight failure rather than silently discard mail.

Capture the follower's token before rearrangement. Remap to its final party position if retained. Otherwise clear follower selection. If the follower lacks a remembered token, compare its original party source location in the plan. This avoids assigning tags during preview.

A keep-current plan validates at least one living non-Egg Pokemon, then leaves party, PC, mailbox, and follower unchanged. Canonical first-opening paths retain their own explicit empty-party exception.

On confirmation, rebuild the plan from current state. Compare the visible roster and destination with the current result and require a fresh preview if they differ. During one locked synchronous operation, apply PC writes, final party, mail, follower, campaign/difficulty, arrival warp, and recovery. No yield or save occurs until the entire operation completes. The issue requires no power-loss transaction beyond the existing save system.

## Real departure boundaries

Instrument confirmed Hub Pass dispatch and confirmed world access scripts for Goldenrod, Slateport, and Vermilion. Instrument Olivine/Vermilion voyages and Hoenn boarding before onboard activity. Capture before party boxing or source-context change. Inventory every regional-to-neutral or interregional route with a static route table/test.

Classify neutral maps explicitly, including World Transit, Frontier, ships, link rooms, and rental facilities. Do not classify them through GetCurrentRegion's Hoenn fallback. The Johto-to-Frontier voyage captures Johto at boarding. Frontier-to-hub and Frontier-to-Hoenn transitions capture nothing. A normal same-region warp captures nothing. A neutral active-campaign mirror is never evidence of a fresh departure.

A route-specific capture call is preferable to a generic SetCurrentRegion hook. Generic writes include arrivals and repairs. Boarding capture also avoids mistakenly remembering a ship's modified party at disembarkation.

## Checkpoint ownership and safety

Author one explicit stable-ID table for every ordinary regional Center, including Sevii and naming exceptions such as Cianwood or League lobbies. Maintain IDs independently of map array order. Each row includes interior map, safe floor tile, campaign, respawn ID, label, and access predicate. A validation script checks complete coverage against authored Center maps and an explicit exclusion list. Frontier, hub, upstairs link rooms, ships, and temporary facilities are excluded.

The true map-entry loader records the matched checkpoint after successful load. Continue does not record. Healing is not needed. Resume itself enters a known previously visited Center and may reaffirm the same ID. A standard regional arrival cannot invent a checkpoint unless it truly enters an approved Center.

Read-only predicates accept destination region and the proposed final party. They read regional flags/badges explicitly. They must not change active campaign or install the temporary party to reuse current-region field-move helpers. For isolated islands, require an actual safe escape path under current ferry/story permissions or field-move capabilities. Examine Cianwood, Sootopolis, Ever Grande, Pacifidlog, and Sevii individually rather than assuming every historical visit stays escapable.

Use region-specific completed-opening predicates plus mature-progress fallbacks. Kanto requires its completed opening rival/lab boundary. Johto requires successful starter receipt and handoff. Hoenn requires Birch lab completion. The shared Pokemon-get flag and narration bits are insufficient. Existing protected interrupted-opening routes run before the new UI.

## Normal player UI

For eligible regions, default team selection to remembered recall when present. Show all six positions, current nicknames/species for available members, saved display metadata for unavailable members, and reasons such as daycare or ambiguous identity. Show mailbox/storage failures and destination before confirmation. Distinguish no historical team from a remembered but entirely unavailable team.

Offer Keep current party and Cancel. Disable both recall and keep-current when neither yields a usable Pokemon, with a direction to the PC or nurse. A partially available team has a separate explicit confirmation. Missing members are not silently replaced.

Default destination to the last entered Center only if valid for the proposed final party. Offer Standard regional arrival. Explain absent or unavailable checkpoints. Cancel leaves all persistent state exactly unchanged from before the dialog. The party remembered on entering the hub remains intact across later PC edits, previews, and cancellations.

## Verification

Tests must exercise all nine region-pair hub returns, both team choices, both destination choices, and actual ferries separately. Controller scripts must drive acceptance/cancellation menus and Center entries. Direct memory setup may prepare prerequisites but cannot stand in for the transition under test.

Unit coverage includes registry reuse, generation exhaustion, duplicate tokens, imported tags, missing members, full registry replacement, identical OT/personality individuals, egg hatch, Shedinja, daycare, PC reorder, evolution, and repeated shared-member recall. Exchange tests compare Pokemon/item/mail totals and serialized persistent state before refusals and cancellation. Test full-PC equal swaps and impossible final capacity.

A destination predicate test must make current campaign/current party yield a different result from destination campaign/final party. Exercise every checkpoint's ownership and tile/exit, special gate classes at runtime, and a forced whiteout after arrival. Migration fixtures need nonzero old tail bytes and unused Pokemon bits, with no fabricated history after loading. Final checks include the complete required overworld sweep, battle suite, host validation, normal ROM build, and feature-off matrix.

## Alternatives and recommendation

This registry avoids consuming identity numbers for every wild, trainer, or newly created Pokemon. It also centralizes shared display metadata and caps the set of tracked individuals at the exact domain bound. It needs generation recycling, retention accounting, two levels of references, and a full-registry replacement plan. The 348-byte layout uses almost the entire available bank.

A simple twenty-bit monotonic token allocated only when a Pokemon first becomes remembered retains the main allocation advantage without slot generations or registry indirection. Per-region compact references can fit if display metadata is chosen carefully. I recommend that simpler embedded-token design if its final measured layout fits. Do not choose this registry merely to avoid an allocator counter. Its extra lifetime rules outweigh its metadata deduplication for eighteen references.

## Source evidence

- `include/global.h` defines the append-only RegionSave and frozen SaveBlock2.
- `include/pokemon.h` contains the twenty encrypted unused bits.
- `src/load_save.c` owns checksum-width selection and sequential migrations through v10.
- `src/egg_hatch.c:311` reconstructs hatched Pokemon.
- `src/evolution_scene.c:553` creates Shedinja by copying the original.
- `src/item_use.c:417` owns accepted Hub Pass warp dispatch.
- `src/region_switch.c:399` has the existing preflight and partial deposit behavior.
- `src/overworld.c:967` owns the normal warp map-entry loader.
- `data/maps/RegionHub/scripts.inc` owns existing protected opening routes and gate UI.
- `docs/implementation/377/grounding.md` inventories departure routes and test infrastructure.
