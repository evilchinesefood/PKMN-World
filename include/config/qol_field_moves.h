#ifndef GUARD_CONFIG_QOL_FIELD_MOVES_H
#define GUARD_CONFIG_QOL_FIELD_MOVES_H

// When TRUE: owning a tool item in the bag unlocks the corresponding field move,
// bypassing the badge/mon requirement. Items: ITEM_CUT_TOOL … ITEM_DIVE_TOOL.
#define QOL_FIELD_MOVES_ITEM_GATE    FALSE

// When TRUE: walking into a tile that requires a field move triggers it automatically.
// STUB — not implemented in this port. Define only.
#define QOL_FIELD_MOVES_AUTO_INTERACT FALSE

// When TRUE: suppresses the party-selection messaging for field moves.
// STUB — not implemented in this port. Define only.
#define QOL_FIELD_MOVES_NO_MESSAGING  FALSE

#endif // GUARD_CONFIG_QOL_FIELD_MOVES_H
