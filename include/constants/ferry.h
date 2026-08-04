#ifndef GUARD_CONSTANTS_FERRY_H
#define GUARD_CONSTANTS_FERRY_H

// Ferry departure record (issue #80), stored in VAR_FERRY_DEPARTURE (include/constants/vars.h).
//
// The event-ticket islands (SOUTHERN / BIRTH / FARAWAY / NAVEL ROCK) are bookable from more than
// one harbour, and Common_EventScript_FerrySailHomeFromIsland (data/event_scripts.s) has to pick
// which one to sail back to. Until #80 it inferred that from the ACTIVE REGION, which is right for
// every save that has one and wrong for a save that does not — see the long note on that script.
// This is the record it should have been reading: written when the player BOARDS, read when the
// sailor on the island is asked for a way home, and CONSUMED (set back to UNSET) by the arm that
// sails them there — so its lifetime is one voyage. Consuming it is a floor, not a requirement:
// every path to the reader passes a writer today, so it changes no current behaviour. It means a
// future island route added without a boarding write degrades to the region probe rather than
// reading a stale harbour, which would be worse than the pre-#80 answer.
//
// VALUE 0 MUST MEAN "UNSET". Every pre-#80 save has 0 here (the slot was VAR_UNUSED_0x40FA, and
// a var nothing ever wrote reads back as 0), including a save made mid-voyage — standing on an
// island having boarded before this record existed. Those saves fall through to the old region
// probe, so #80 changes nothing for them: the fix adds a preferred answer, it does not remove the
// old one.
//
// Deliberately NOT a per-region var. include/constants/region_vars.h reserves the 0xA000 bank for
// per-region STORY vars only; "which harbour did I sail from" is cross-region state by definition
// — the whole point is that the answer can name a harbour in a region the player is not in — so it
// belongs in the global SaveBlock1.vars[] pool with VAR_PLAYER_CHARACTER and VAR_PLAYER_PALETTE.
//
// The slot was reclaimed at its existing numeric id rather than appended: VARS_END is 0x40FF and
// VAR_DEXNAV_STEP_COUNTER already sits there, so the pool has no free tail, and reclaiming costs
// zero save-layout change. Same move as commit abb316aa (#59).
#define FERRY_DEPART_UNSET      0
#define FERRY_DEPART_LILYCOVE   1
#define FERRY_DEPART_OLIVINE    2
// No departure site writes VERMILION today: there is no Kanto-side island row. KANTO's own
// MYSTIC TICKET run sails to MAP_NAVEL_ROCK_HARBOR_FRLG, a different map with its own sailor home
// (src/seagallop.c), and VermilionPort_EventScript_Sailor sells the crossing back to OLIVINE, not
// a trip to an island. The constant and the read arm exist so that the KANTO arm #72 added to the
// sail-home script — itself a floor under a future Kanto island row — stays honest: whoever adds
// that row writes this value at the boarding site and the return already works.
#define FERRY_DEPART_VERMILION  3

#endif // GUARD_CONSTANTS_FERRY_H
