#ifndef GUARD_STORY_PROGRESS_H
#define GUARD_STORY_PROGRESS_H

#include "global.h"
#include "constants/regions.h"

enum StoryStatus { STORY_NOT_STARTED, STORY_IN_PROGRESS, STORY_COMPLETE };

enum StoryDestinationKind
{
    STORY_DESTINATION_PIN,
    STORY_DESTINATION_HUB,
    STORY_DESTINATION_FREE_ROAM,
    STORY_DESTINATION_MULTIPLE,
    STORY_DESTINATION_WAITING,
    STORY_DESTINATION_DYNAMIC,
};

struct StoryDestination
{
    u16 kind;
    u16 mapSecId;
};

struct StoryObjective
{
    const char *id; // stable authoring/test identifier, never displayed
    const u8 *chapter;
    const u8 *recap;
    const u8 *action;
    const u8 *where;
    const u8 *why;
    struct StoryDestination destination;
};

struct StoryProgress
{
    const struct StoryObjective *objective;
    const struct StoryObjective *optional;
    enum StoryStatus status;
    u8 badges;
};

const struct StoryDestination *StoryProgress_GetDestination(const struct StoryObjective *objective);
void ShowStoryDestinationMap(const struct StoryObjective *objective, void (*returnCallback)(void));
void StoryProgress_Resolve(enum Region region, struct StoryProgress *progress);
enum Region StoryProgress_DefaultRegion(void);
void ShowStoryProgress(void (*returnCallback)(void));

#endif
