#ifndef GUARD_CONFIG_QOL_FIELD_MOVES_H
#define GUARD_CONFIG_QOL_FIELD_MOVES_H

// When TRUE: owning a tool item in the bag unlocks the corresponding field move,
// bypassing the badge/mon requirement. Items: ITEM_CUT_TOOL … ITEM_DIVE_TOOL.
#define QOL_FIELD_MOVES_ITEM_GATE    TRUE

// When TRUE: walking into a tile that requires a field move triggers it automatically.
// STUB — not implemented in this port. Define only.
#define QOL_FIELD_MOVES_AUTO_INTERACT TRUE

// When TRUE: suppresses the party-selection messaging for field moves.
// STUB — not implemented in this port. Define only.
#define QOL_FIELD_MOVES_NO_MESSAGING  TRUE

// When TRUE: an HM field move (Cut, Flash, Rock Smash, Strength, Surf, Fly, Dive,
// Waterfall) can be used if a party mon CAN LEARN it — no need to actually teach it.
// The per-region badge gate (IsFieldMoveUnlocked) still applies.
#define QOL_FIELD_MOVES_NO_TEACH      TRUE

#endif // GUARD_CONFIG_QOL_FIELD_MOVES_H
