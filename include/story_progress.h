#ifndef GUARD_STORY_PROGRESS_H
#define GUARD_STORY_PROGRESS_H

#include "global.h"
#include "constants/regions.h"

enum StoryStatus { STORY_NOT_STARTED, STORY_IN_PROGRESS, STORY_COMPLETE };

struct StoryObjective
{
    const char *id; // stable authoring/test identifier, never displayed
    const u8 *chapter;
    const u8 *recap;
    const u8 *action;
    const u8 *where;
    const u8 *why;
};

struct StoryProgress
{
    const struct StoryObjective *objective;
    const struct StoryObjective *optional;
    enum StoryStatus status;
    u8 badges;
};

void StoryProgress_Resolve(enum Region region, struct StoryProgress *progress);
enum Region StoryProgress_DefaultRegion(void);
void ShowStoryProgress(void (*returnCallback)(void));

#endif
