#ifndef GUARD_FIELD_MOVE_H
#define GUARD_FIELD_MOVE_H

#include "global.h"
#include "constants/field_move.h"

struct FieldMoveInfo
{
    bool32 (*fieldMoveFunc)(void);
    bool32 (*isUnlockedFunc)(void);
    u16 moveID;
    u8 partyMsgID;
#if QOL_FIELD_MOVES_ITEM_GATE
    u16 toolItemId;
#endif
};

extern const struct FieldMoveInfo gFieldMoveInfo[];

static inline bool32 SetUpFieldMove(enum FieldMove fieldMove)
{
    return gFieldMoveInfo[fieldMove].fieldMoveFunc();
}

static inline bool32 IsFieldMoveUnlocked(enum FieldMove fieldMove)
{
    return gFieldMoveInfo[fieldMove].isUnlockedFunc();
}

static inline u32 FieldMove_GetMoveId(enum FieldMove fieldMove)
{
    return gFieldMoveInfo[fieldMove].moveID;
}

static inline u32 FieldMove_GetPartyMsgID(enum FieldMove fieldMove)
{
    return gFieldMoveInfo[fieldMove].partyMsgID;
}

#if QOL_FIELD_MOVES_NO_TEACH
// The 8 HMs that QOL_FIELD_MOVES_NO_TEACH covers (a can-learn party mon may use them
// without being taught). Non-HM field moves (Dig, Teleport, Secret Power, ...) are
// excluded so NO_TEACH never lets them satisfy a "party has this move" check.
static inline bool32 IsTeachableHMFieldMove(enum FieldMove fieldMove)
{
    switch (fieldMove)
    {
    case FIELD_MOVE_CUT:
    case FIELD_MOVE_FLASH:
    case FIELD_MOVE_ROCK_SMASH:
    case FIELD_MOVE_STRENGTH:
    case FIELD_MOVE_SURF:
    case FIELD_MOVE_FLY:
    case FIELD_MOVE_DIVE:
    case FIELD_MOVE_WATERFALL:
        return TRUE;
    default:
        return FALSE;
    }
}
#endif

#endif //GUARD_FIELD_MOVE_H
