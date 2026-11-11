# Candidate A. Embedded identity and one travel transaction

This is a source-grounded design, not implemented or runtime verified. Baseline is 35bf05083e. The current save format is **10**, although the RegionSave layout last grew in version 9. The feature therefore appends version 11 data.

## Caller usage

Accepted Hub Pass use calls `RegionalTravel_RecordDeparture(source, destination)` immediately before `SetWarpDestination`. The source is the current physical map classification. The destination is World Transit. A canceled confirmation never reaches this call.

An Olivine sailor calls the same operation after ticket and destination checks but before boarding animation or the maiden-voyage ship warp. Onboard and disembarkation scripts do not record again. A direct regional voyage keeps the current party and port recovery behavior.

An eligible hub attendant starts `RegionalTravel_OpenGate(target)`. That function owns a normal controller menu, preview, destination selection, partial confirmation, and final acceptance. It calls `RegionalTravel_Commit(request)` only after confirmation. This returns a refusal reason without mutation or commits the party exchange, campaign, recovery point, and prepared warp together. The old opening route remains available only through the opening policy.

A successful map warp calls `RegionalTravel_OnMapEntered()` after the new map header and transition scripts are established. It records a Center only when the explicitly inventoried interior matches. Continue does not call this hook. Healing and synthetic respawn writes never call it.

## Persistent shape

Use the existing 20 unused encrypted bits for an unsigned individual ID. Zero means unassigned. Rename these fields to portions of `regionalIdentity` and expose only `MON_DATA_REGIONAL_ID` through Get/SetBoxMonData. Bits are split as 6, 3, 2, 5, 3, and 1 across existing substruct fields. The accessor owns packing. No caller sees the packing, and BoxPokemon stays 80 bytes.

A deliberately modest display snapshot keeps only the last species. Available members show their live nickname and species. Missing members show their remembered position and species with an honest reason. Species is enough to distinguish a missing team slot without taking a second Pokemon snapshot. It avoids truncating 12-character nicknames or consuming the entire remaining save capacity.

```c
struct RegionalTeamMember {
    u32 identity;
    u16 lastSpecies;
    u16 reserved;
};
struct RegionalTeamMemory {
    struct RegionalTeamMember members[PARTY_SIZE];
    u8 count;
    u8 reserved[3];
};
struct RegionalTravelSave {
    u32 nextIdentity;
    struct RegionalTeamMemory teams[3];
    u16 center[3];
    u8 reserved[2];
};
```

This uses 168 bytes with ordinary 4-byte alignment. Verify that size with static assertions, leaving 192 bytes of the current 360-byte capacity. IDs in the table are u32 for cheap access but restricted to 20 bits. Checkpoint IDs are explicit u16 constants, append-only, independent of map numbering. No persistent transaction state is needed because the entire commit happens synchronously while scripts hold field control.

`nextIdentity` starts at 1 and never wraps. Allocate only for an unassigned authoritative Pokemon when an accepted departure needs a reference. Do not allocate in CreateMon because that creates opponents, simulations, and previews too. New Pokemon start with zero identity from the normal zeroing path. Existing memory references are immutable until the next real departure from their campaign.

## Identity ownership and lifecycle

The identifier names one individual within this save. Ordinary PC moves, party reorder, evolution, nickname changes, training, and daycare transfers preserve it because they move the existing BoxPokemon. Neither species nor personality participates in matching. They cannot provide uniqueness.

`CreateHatchedMon` saves the egg's ID before recreating its body and writes that ID onto the hatched continuation. `CreateShedinja` clears the ID on the newly copied Shedinja immediately after the copy. The evolved Nincada continuation keeps its ID. Newly generated NPC trade replacements keep the creation default of zero. Link/import transfer acceptance explicitly clears foreign IDs before the incoming individual joins authoritative ownership. Audit every acquisition path that copies an external Pokemon instead of calling creation.

The resolver scans party, PC, both ordinary daycare slots, and Route 5 daycare. It counts matches across all those owners before classifying availability. Exactly one party/PC match is available. Exactly one daycare match is unavailable with reason `DAYCARE`. Zero matches is `NOT_PRESENT`. Multiple matches is `AMBIGUOUS`, including a collision between one available member and one daycare member. Never select the first match. Empty, Bad Egg, or invalid species occupants do not satisfy a reference.

Allocation checks candidate IDs against authoritative owners and all retained references before assigning. The monotonic counter normally guarantees absence, but the scan prevents an imported or damaged higher ID from being reused. Exhaustion is a controlled capture failure, never a wrap or silent collision. Because 1,048,575 identities are available and allocation happens only on remembered departures, this is an extreme limit. The caller must refuse the departure with an explanation if it cannot assign all outgoing members. All IDs and the new lineup are planned before any are written.

Capture of an already ambiguous individual also refuses until the ambiguity is resolved. Quietly assigning one colliding body a replacement would leave an old memory pointing to an arbitrary survivor. No identity cleanup may rewrite existing memories during preview.

Facilities may hold the player's real team in a saved backup while rentals occupy the live party. Facility movement never calls accepted-departure capture. Migration must enumerate stored real-team backups as well as normal owners, or clear IDs on backup restoration for pre-v11 saves. The latter requires an explicit migration marker and is less attractive. Prefer complete migration of every persisted Pokemon owner.

## Save migration

Append the travel bank after `johtoTrainerFlags`. Set save format to 11 and retain the existing minimum supported version. For every supported source below 11, initialize the bank empty with nextIdentity 1. Clear the newly assigned ID bits in every persisted Pokemon owner before runtime party loading. This cannot infer any historical team or Center. Preserve checksums through the ordinary SetBoxMonData path. Verify that the migration operates on SaveBlock1.playerParty, rather than only the live party, because SaveBlock migration occurs before LoadPlayerParty.

Add `if (version < 11) return offsetof(struct RegionSave, regionalTravel);` to checksum-width selection after the older width case. Preserve all old offset assertions and add new size/capacity assertions. A generated v10 fixture must contain nonzero tail bytes and nonzero newly interpreted Pokemon bits so removing either initialization causes a failure. Older builds already refuse newer save versions in src/save.c. A version 11 save is refused by version 10 builds. Document this rollback limitation and retain a pre-upgrade backup for use with older builds.

## Runtime transaction shape

```c
enum RegionalPartyChoice { REGIONAL_TEAM, CURRENT_PARTY, OPENING_PARTY };
enum RegionalArrivalChoice { LAST_CENTER, STANDARD_ARRIVAL };
enum RegionalMemberState { AVAILABLE, DAYCARE, NOT_PRESENT, AMBIGUOUS };
enum RegionalTravelResult {
    TRAVEL_OK, TRAVEL_PARTIAL_CONFIRMATION_REQUIRED, TRAVEL_NO_MEMORY,
    TRAVEL_NO_USABLE_MON, TRAVEL_PC_FULL, TRAVEL_MAILBOX_FULL,
    TRAVEL_IDENTITY_UNAVAILABLE, TRAVEL_STALE_PREVIEW, TRAVEL_OPENING_REQUIRED
};
struct RegionalTravelRequest {
    enum Region destination;
    enum RegionalPartyChoice party;
    enum RegionalArrivalChoice arrival;
    bool8 partialConfirmed;
};
struct RegionalTravelPlan {
    struct Pokemon finalParty[PARTY_SIZE];
    struct BoxPokemon outgoing[PARTY_SIZE];
    struct RegionalMonLocation incoming[PARTY_SIZE];
    struct RegionalMonLocation deposit[PARTY_SIZE];
    u8 outgoingPartySlots[PARTY_SIZE];
    u8 outgoingCount, finalCount, followerSlot;
    struct WarpData arrival;
    u16 healLocation;
    enum RegionalTravelResult result;
};
```

The plan is private EWRAM or a bounded allocation owned by the UI task. Do not put a multi-kilobyte plan on the GBA stack. The public preview contains only displayable members, statuses, destination text, mail detachment count, and refusal reason. Other modules cannot apply fragments of a plan.

Build the complete final party from current authoritative data. A carried recalled member enters directly with its mail and combat state. A PC member uses the same boxed-to-party conversion as normal withdrawal. For every outgoing party member not retained, select an empty PC slot or a slot vacated by an incoming PC member. This allows a full-PC equal-size exchange. Preserve remembered order while omitting unavailable members only after explicit partial confirmation. Require at least one non-Egg member with positive HP.

Count mailbox slots only for outgoing mail holders. A retained member keeps its party mail reference and text. Reserve distinct mailbox positions in the plan. Refuse if insufficient. Stage outgoing BoxPokemon using normal no-heal compression semantics. The apply phase first stages all incoming bodies, then detaches outgoing mail with prevalidated capacity, writes deposits into planned slots, clears remaining withdrawn slots, installs the final party, and remaps the follower by identity or clears it. No fallible lookup or allocation may remain after the first mutation.

Immediately before apply, rebuild from the current request and compare all displayed outcomes. If member identity, partial status, destination validity, or obstruction changes, refresh the preview and require confirmation again. Keep-current has no PC/mail exchange and still checks usability. After the final checks, apply, set campaign/difficulty, set respawn, and set warp destination in one function. There is no frame yield or save callback between those operations. Do not call the old partial DepositPartyToPC routine.

## Departure ownership

Use explicit physical ownership classification, with `REGION_NONE` for neutral maps. Do not consult persisted active campaign to fill in neutral ownership. A generated map inventory plus explicit neutral exclusions is preferable to another permissive fallback. Hub, Frontier maps, actual link-session rooms, battle facilities, ships, and temporary islands without a campaign owner are neutral. Regional Center second floors retain their campaign ownership for champion transit-pad departures, but never become resume checkpoints. Story maps and normal Centers belong to their actual campaigns.

`RegionalTravel_RecordDeparture` accepts both source and intended destination. It records only a playable source crossing into a different campaign or neutral transit. The caller has already accepted travel. Hub Pass, regional World Transit access points, Center-2F champion pads, accepted Olivine/Vermilion boarding, accepted SS Tidal mainland-to-Frontier boarding, and cross-region flight are the required seams. Same-region ferries do not record a departure. A neutral Frontier-to-hub or Frontier-to-Hoenn route does not recapture Johto even if the active campaign still says Johto. A maiden Aqua voyage records before its first ship warp and never again at disembarkation.

Prefer narrowly located capture calls at accepted travel boundaries over a generic SetCurrentRegion hook. Add a host audit enumerating travel scripts and asserting the accepted branch includes capture. This makes future warp additions reviewable without treating every warp as a departure.

## Opening policy

One pure `RegionalTravel_IsOpeningComplete(region)` predicate owns the new UI gate. Kanto requires completion of the opening rival, represented by Oak lab scene at least 4, with trustworthy later Kanto progress as a fallback. Hoenn requires completed Birch handover, represented by VAR_BIRCH_LAB_STATE at least 3, again with mature Hoenn progress fallback. Littleroot intro state 7 occurs before the rescue and cannot establish completion. Johto requires FLAG_JOHTO_STARTER_CHOSEN and VAR_NEWBARKTOWN_LABSTATE at least 2, covering both successful receipt and Elm's subsequent Mr Pokemon handoff. Use trustworthy later Johto progress as a fallback. These are actual script boundaries, not narration or shared Pokemon-get.

For unfinished destinations, preserve the existing protected script route and its party rules. Interrupted Kanto starter scene returns to Oak's lab. Do not box away a starter needed to finish the same campaign. Do not apply these hub-only restrictions to the normal maiden Johto-to-Kanto ferry.

## Center inventory and access

Use one explicit authored table of stable checkpoint IDs with campaign, interior map, safe arrival tile, heal location, display name, and access rule. All eligible Center interiors must appear exactly once. A host audit compares the table against map/layout/healer inventory, including naming exceptions such as Cianwood's clinic and Ever Grande's League lobby. Exclusions need reasons in the same inventory, covering Frontier, hub, ship healers, link floors, and scripted temporary recovery sites.

Record on actual successful entry, even without nurse interaction. Keep recording separate from selection validity. An entered Center may become invalid later, but the history remains truthful and the UI can explain fallback. A reload in a Center does not synthesize a visit. Resume uses an interior safe floor tile away from entrance triggers, nurse movement, and mandatory scenes, plus its established regional recovery ID.

The access API is `RegionalCheckpoint_IsSafe(id, destination, finalParty, finalCount)`. It reads destination flags, destination badge banks, bag tools/HMs, and the proposed final party. It never sets gCurrentRegion, swaps the party, or invokes the current-map field-move helpers. Extract a narrow read-only field capability helper with explicit region and party arguments where that avoids duplicating Surf/Fly/tool policy. Existing normal field callers can pass their real region/party.

Access rules must cover island escape and special story gates. Examples include Cianwood requiring a currently usable route home, Sootopolis requiring a usable water/flight escape, Sevii requiring its current ferry/story permissions, and League areas requiring their regional admission contract. The exact inventory must derive requirements from exit scripts and reachable terrain, not merely from the fact that a save once visited. The approved Hub Pass can be an escape only where its current use rules actually allow it; do not turn it into a blanket justification.

If the remembered checkpoint is invalid, keep the standard arrival selected and display a reason. Do not silently replace it with a different Center. Revalidate against the final recalled team, not the outgoing team. On arrival, arm the Center's intended whiteout recovery without healing the current party.

## UI and tests

For an eligible gate, default to Use regional team if a usable memory can be resolved. Otherwise explain no memory or missing members and offer Keep current party and PC preparation. Show all remembered positions, live names for available members, missing species and reason for gaps, the proposed destination, mail detachment, and any refusal. Provide Resume at Center and Standard regional arrival. A partial recall has its own explicit confirmation before the final travel confirmation. Cancel destroys only the UI task and its local plan.

Tests should snapshot party, storage, mail, save bank, campaign, warp, and recovery before refusal/cancel, then compare exact values. Exercise 6 directed region pairs and 3 same-region returns, both choices, full-PC exchange, full mailbox, retained mail, daycare ambiguity, identical-looking individuals, hatch continuation, Shedinja split, all checkpoint records and access predicates, first-opening thresholds, and migration dirt. Controller suites must perform accepted boarding, hub choice, Center entry, and cancel themselves. Prerequisite memory setup does not prove those transitions.

## Rejected alternatives and limits

A PC-slot identity side table exceeds available space and requires hooks at every move. Personality/OT keys cannot distinguish identical-looking individuals. Growing BoxPokemon breaks all PC and save offsets. Persisted team snapshots duplicate progress and items. A persistent transfer journal consumes save space and adds recovery states despite a synchronous operation with no save yield. Reusing SetCurrentRegion as capture records arrivals and neutral/rental parties at the wrong time.

The bounded identity scheme is a real limit. Exhaustion must refuse safely and be covered by a direct boundary test. Candidate A trades the last-known nickname of an unavailable member for spare save capacity and a simple fixed structure. The preview still identifies the ordered missing member by species. If product review requires historical full nicknames, a packed 18-byte member layout fits but leaves much less growth space and requires explicit serialization.
