#ifndef GUARD_COMPLEX_QUESTS_H
#define GUARD_COMPLEX_QUESTS_H

#include "config/quests.h"

#if OW_QUEST_BRANCHING

#include "global.h"
#include "quests.h"
#include "constants/event_objects.h"

//////////////////////////////////////////
////////////BEGIN QUEST NUMS//////////////

/* Controls how many descriptions/maps a branching quest has. */

enum Quest3_Enum
{
    QUEST_3_STATE_1,
    QUEST_3_STATE_2,
    QUEST_3_STATE_3,
    QUEST_3_TOTAL_STATES,
};

/////////////END QUEST NUMS/////////////
////////////////////////////////////////

/////////////////////////////////////////
///////////BEGIN QUEST STRINGS///////////

//Quest 3 Descriptions
static const u8 gComplexQuest_Quest3Desc_1[] = _("Find the lost {STR_VAR_1}.");
static const u8 gComplexQuest_Quest3Desc_2[] = _("Return it to its owner.");
static const u8 gComplexQuest_Quest3Desc_3[] = _("Collect your reward.");

//Quest 3 Maps
static const u8 gComplexQuest_Quest3Map_1[] = _("Route 1");
static const u8 gComplexQuest_Quest3Map_2[] = _("Petalburg City");
static const u8 gComplexQuest_Quest3Map_3[] = _("Rustboro City");

///////////END QUEST STRINGS/////////////
////////////////////////////////////////

#endif // OW_QUEST_BRANCHING

#endif // GUARD_COMPLEX_QUESTS_H
