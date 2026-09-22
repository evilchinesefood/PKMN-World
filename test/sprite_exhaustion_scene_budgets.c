#include "global.h"
#include "constants/species.h"
#include "evolution_graphics.h"
#include "sprite.h"
#include "task.h"
#include "test/test.h"

static u32 CountUsedSprites(void)
{
    u32 count = 0;

    for (u32 i = 0; i < MAX_SPRITES; i++)
    {
        if (gSprites[i].inUse)
            count++;
    }
    return count;
}

static void PrepareEvolutionScene(void)
{
    ResetSpriteData();
    FreeAllSpritePalettes();
    ResetTasks();
    LoadEvoSparkleSpriteAndPal();
    // Field evolution keeps the pre-evo and post-evo pictures.
    CreateSprite(&gDummySpriteTemplate, 0, 0, 0);
    CreateSprite(&gDummySpriteTemplate, 0, 0, 0);
}

static u32 PeakWhileTaskRuns(u8 taskId, u32 frames)
{
    u32 peak = CountUsedSprites();

    for (u32 frame = 0; frame < frames && gTasks[taskId].isActive; frame++)
    {
        RunTasks();
        if (CountUsedSprites() > peak)
            peak = CountUsedSprites();
    }
    return peak;
}

TEST("Evolution arc sparkles fit under the sprite cap")
{
    PrepareEvolutionScene();
    u8 taskId = EvolutionSparkles_ArcDown();
    u32 peak = PeakWhileTaskRuns(taskId, 20);

    // 6 steps of 9 sparkles, on top of the two evolution pictures.
    EXPECT_EQ(peak, 56);
    EXPECT(peak < MAX_SPRITES);
    ResetTasks();
}

TEST("Evolution spray sparkles fit under the sprite cap")
{
    PrepareEvolutionScene();
    u8 taskId = EvolutionSparkles_SprayAndFlash(SPECIES_WOBBUFFET);
    u32 peak = PeakWhileTaskRuns(taskId, 80);

    // 8 sparkles on the first step, then one per step under timer 50
    // except the fade step. All 56 are alive together.
    EXPECT_EQ(peak, 58);
    EXPECT(peak < MAX_SPRITES);
    ResetTasks();
}
