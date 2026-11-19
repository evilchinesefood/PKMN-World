#include "global.h"
#include "mystery_gift.h"
#include "random.h"
#include "event_data.h"
#include "wonder_news.h"
#include "constants/items.h"
#include "item.h"
#include "constants/mystery_gift.h"

// The Wonder News reward man in CeruleanCity_House4 is on a LIVE map. His
// script branches specialvar-return against NEWS_REWARD_*; NONE routes to the
// "no news" line, which is also what the real code returns with no valid news.
u16 WonderNews_GetRewardInfo(void)
{
    gSpecialVar_Result = 0;
    return NEWS_REWARD_NONE;
}
