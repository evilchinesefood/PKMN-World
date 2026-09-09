// Diagnostic fixtures for Testing/SpriteExhaustionTriage.md. Not part of the normal test build.
// Each expected crash proves an allocation path reaches the asserting allocator with a full pool.
#include "global.h"
#include "event_object_movement.h"
#include "field_effect.h"
#include "field_effect_helpers.h"
#include "field_player_avatar.h"
#include "field_weather.h"
#include "fldeff_misc.h"
#include "item.h"
#include "item_menu.h"
#include "sprite.h"
#include "task.h"
#include "test/test.h"
#include "constants/event_objects.h"
#include "constants/items.h"

extern u32 FldEff_Ash(void);
extern u32 FldEff_BerryTreeGrowthSparkle(void);
extern u32 FldEff_BikeTireTracks(void);
extern u32 FldEff_Bubbles(void);
extern u32 FldEff_DeepSandFootprints(void);
extern u32 FldEff_Dust(void);
extern u32 FldEff_FeetInFlowingWater(void);
extern u32 FldEff_HotSpringsWater(void);
extern u32 FldEff_JumpBigSplash(void);
extern u32 FldEff_JumpLongGrass(void);
extern u32 FldEff_JumpSmallSplash(void);
extern u32 FldEff_JumpTallGrass(void);
extern u32 FldEff_LongGrass(void);
extern u32 FldEff_ORASDowsing(void);
extern u32 FldEff_Ripple(void);
extern u32 FldEff_RockClimbDust(void);
extern u32 FldEff_SandFootprints(void);
extern u32 FldEff_SandPile(void);
extern u32 FldEff_ShakingGrass(void);
extern u32 FldEff_ShakingGrass2(void);
extern u32 FldEff_ShortGrass(void);
extern u32 FldEff_Sparkle(void);
extern u32 FldEff_Splash(void);
extern u32 FldEff_SurfBlob(void);
extern u32 FldEff_TallGrass(void);
extern u32 FldEff_TracksBug(void);
extern u32 FldEff_TracksSlither(void);
extern u32 FldEff_TracksSpot(void);
extern u32 FldEff_UnusedSand(void);
extern u32 FldEff_WaterSurfacing(void);
extern u32 ShowTreeDisguiseFieldEffect(void);
extern u8 FldEff_CaveDust(void);
extern u8 FldEff_DoubleExclMarkIcon(void);
extern u8 FldEff_HeartIcon(void);
extern u8 FldEff_QuestionMarkIcon(void);
extern u8 FldEff_SmileyFaceIcon(void);
extern u8 FldEff_XIcon(void);

static void FillPool(void)
{
    ResetSpriteData();
    FreeAllSpritePalettes();
    FieldEffectActiveListClear();
    ResetTasks();
    memset(gWeatherPtr, 0, sizeof(*gWeatherPtr));
    memset(gObjectEvents, 0, sizeof(gObjectEvents));
    memset(gFieldEffectArguments, 0, sizeof(gFieldEffectArguments));
    memset(&gPlayerAvatar, 0, sizeof(gPlayerAvatar));
    gObjectEvents[0].active = TRUE;
    gObjectEvents[0].localId = 1;
    gObjectEvents[0].graphicsId = OBJ_EVENT_GFX_LITTLE_BOY;
    gFieldEffectArguments[0] = 1;
    for (u32 i = 0; i < MAX_SPRITES; i++)
        CreateSprite(&gDummySpriteTemplate, 0, 0, 0);
}

TEST("Sprite audit probe 126: Task_KeyItemWheel")
{
    KNOWN_CRASHING;
    FillPool();
    AddBagItem(ITEM_MACH_BIKE, 1);
    AddBagItem(ITEM_ITEMFINDER, 1);
    SetRegisteredItem(0, ITEM_MACH_BIKE);
    SetRegisteredItem(1, ITEM_ITEMFINDER);
    ASSUME(CountRegisteredItems() == 2);
    ASSUME(UseRegisteredKeyItemOnField());
    RunTasks();
}

TEST("Sprite audit probe 034: CreateObjectGraphicsSpriteWithTag")
{
    KNOWN_CRASHING;
    FillPool();
    
    CreateObjectGraphicsSprite(OBJ_EVENT_GFX_LITTLE_BOY, SpriteCallbackDummy, 0, 0, 0);
}

TEST("Sprite audit probe 042: FldEff_CaveDust")
{
    KNOWN_CRASHING;
    FillPool();
    
    FldEff_CaveDust();
}

TEST("Sprite audit probe 044: FldEff_TallGrass")
{
    KNOWN_CRASHING;
    FillPool();
    
    FldEff_TallGrass();
}

TEST("Sprite audit probe 045: FldEff_JumpTallGrass")
{
    KNOWN_CRASHING;
    FillPool();
    
    FldEff_JumpTallGrass();
}

TEST("Sprite audit probe 046: FldEff_LongGrass")
{
    KNOWN_CRASHING;
    FillPool();
    
    FldEff_LongGrass();
}

TEST("Sprite audit probe 047: FldEff_JumpLongGrass")
{
    KNOWN_CRASHING;
    FillPool();
    
    FldEff_JumpLongGrass();
}

TEST("Sprite audit probe 048: FldEff_ShortGrass")
{
    KNOWN_CRASHING;
    FillPool();
    
    FldEff_ShortGrass();
}

TEST("Sprite audit probe 049: FldEff_SandFootprints")
{
    KNOWN_CRASHING;
    FillPool();
    
    FldEff_SandFootprints();
}

TEST("Sprite audit probe 050: FldEff_DeepSandFootprints")
{
    KNOWN_CRASHING;
    FillPool();
    
    FldEff_DeepSandFootprints();
}

TEST("Sprite audit probe 051: FldEff_TracksBug")
{
    KNOWN_CRASHING;
    FillPool();
    
    FldEff_TracksBug();
}

TEST("Sprite audit probe 052: FldEff_TracksSpot")
{
    KNOWN_CRASHING;
    FillPool();
    
    FldEff_TracksSpot();
}

TEST("Sprite audit probe 053: FldEff_BikeTireTracks")
{
    KNOWN_CRASHING;
    FillPool();
    
    FldEff_BikeTireTracks();
}

TEST("Sprite audit probe 054: FldEff_TracksSlither")
{
    KNOWN_CRASHING;
    FillPool();
    
    FldEff_TracksSlither();
}

TEST("Sprite audit probe 055: FldEff_Splash")
{
    KNOWN_CRASHING;
    FillPool();
    
    FldEff_Splash();
}

TEST("Sprite audit probe 056: FldEff_JumpSmallSplash")
{
    KNOWN_CRASHING;
    FillPool();
    
    FldEff_JumpSmallSplash();
}

TEST("Sprite audit probe 057: FldEff_JumpBigSplash")
{
    KNOWN_CRASHING;
    FillPool();
    
    FldEff_JumpBigSplash();
}

TEST("Sprite audit probe 058: FldEff_FeetInFlowingWater")
{
    KNOWN_CRASHING;
    FillPool();
    
    FldEff_FeetInFlowingWater();
}

TEST("Sprite audit probe 059: FldEff_Ripple")
{
    KNOWN_CRASHING;
    FillPool();
    
    FldEff_Ripple();
}

TEST("Sprite audit probe 060: FldEff_HotSpringsWater")
{
    KNOWN_CRASHING;
    FillPool();
    
    FldEff_HotSpringsWater();
}

TEST("Sprite audit probe 061: FldEff_ShakingGrass")
{
    KNOWN_CRASHING;
    FillPool();
    
    FldEff_ShakingGrass();
}

TEST("Sprite audit probe 062: FldEff_ShakingGrass2")
{
    KNOWN_CRASHING;
    FillPool();
    
    FldEff_ShakingGrass2();
}

TEST("Sprite audit probe 063: FldEff_UnusedSand")
{
    KNOWN_CRASHING;
    FillPool();
    
    FldEff_UnusedSand();
}

TEST("Sprite audit probe 064: FldEff_WaterSurfacing")
{
    KNOWN_CRASHING;
    FillPool();
    
    FldEff_WaterSurfacing();
}

TEST("Sprite audit probe 065: FldEff_Ash")
{
    KNOWN_CRASHING;
    FillPool();
    
    FldEff_Ash();
}

TEST("Sprite audit probe 067: FldEff_SurfBlob")
{
    KNOWN_CRASHING;
    FillPool();
    gFieldEffectArguments[2] = 1;
    FldEff_SurfBlob();
}

TEST("Sprite audit probe 068: FldEff_Dust")
{
    KNOWN_CRASHING;
    FillPool();
    
    FldEff_Dust();
}

TEST("Sprite audit probe 069: FldEff_RockClimbDust")
{
    KNOWN_CRASHING;
    FillPool();
    
    FldEff_RockClimbDust();
}

TEST("Sprite audit probe 070: FldEff_SandPile")
{
    KNOWN_CRASHING;
    FillPool();
    
    FldEff_SandPile();
}

TEST("Sprite audit probe 071: FldEff_Bubbles")
{
    KNOWN_CRASHING;
    FillPool();
    
    FldEff_Bubbles();
}

TEST("Sprite audit probe 072: FldEff_BerryTreeGrowthSparkle")
{
    KNOWN_CRASHING;
    FillPool();
    
    FldEff_BerryTreeGrowthSparkle();
}

TEST("Sprite audit probe 073: ShowDisguiseFieldEffect")
{
    KNOWN_CRASHING;
    FillPool();
    
    ShowTreeDisguiseFieldEffect();
}

TEST("Sprite audit probe 074: FldEff_Sparkle")
{
    KNOWN_CRASHING;
    FillPool();
    
    FldEff_Sparkle();
}

TEST("Sprite audit probe 078: CreateCloudSprites")
{
    KNOWN_CRASHING;
    FillPool();
    
    Clouds_Main(); Clouds_Main();
}

TEST("Sprite audit probe 079: CreateSnowflakeSprite")
{
    KNOWN_CRASHING;
    FillPool();
    gWeatherPtr->targetSnowflakeSpriteCount = 1; gWeatherPtr->snowflakeVisibleCounter = 36;
    Snow_Main();
}

TEST("Sprite audit probe 080: CreateFogHorizontalSprites")
{
    KNOWN_CRASHING;
    FillPool();
    
    FogHorizontal_Main();
}

TEST("Sprite audit probe 081: CreateAshSprites")
{
    KNOWN_CRASHING;
    FillPool();
    gWeatherPtr->initStep = 1;
    Ash_Main();
}

TEST("Sprite audit probe 082: CreateFogDiagonalSprites")
{
    KNOWN_CRASHING;
    FillPool();
    
    FogDiagonal_Main();
}

TEST("Sprite audit probe 083: CreateSandstormSprites")
{
    KNOWN_CRASHING;
    FillPool();
    
    Sandstorm_Main();
}

TEST("Sprite audit probe 084: CreateSwirlSandstormSprites")
{
    KNOWN_CRASHING;
    FillPool();
    gWeatherPtr->sandstormSpritesCreated = TRUE;
    Sandstorm_Main();
}

TEST("Sprite audit probe 085: CreateBubbleSprite")
{
    KNOWN_CRASHING;
    FillPool();
    gWeatherPtr->initStep = 2; gWeatherPtr->bubblesDelayCounter = 0x7fff;
    Bubbles_Main();
}

TEST("Sprite audit probe 086: DoSecretBaseGlitterMatSparkle")
{
    KNOWN_CRASHING;
    FillPool();
    
    DoSecretBaseGlitterMatSparkle();
}

TEST("Sprite audit probe 087: CreateRecordMixingLights")
{
    KNOWN_CRASHING;
    FillPool();
    
    CreateRecordMixingLights();
}

TEST("Sprite audit probe 103: FldEff_ORASDowsing")
{
    KNOWN_CRASHING;
    FillPool();
    gPlayerAvatar.gender = MALE;
    FldEff_ORASDowsing();
}

TEST("Sprite audit probe 104: FldEff_ORASDowsing")
{
    KNOWN_CRASHING;
    FillPool();
    gPlayerAvatar.gender = FEMALE;
    FldEff_ORASDowsing();
}

TEST("Sprite audit probe 154: FldEff_QuestionMarkIcon")
{
    KNOWN_CRASHING;
    FillPool();
    gFieldEffectArguments[7] = 0;
    FldEff_QuestionMarkIcon();
}

TEST("Sprite audit probe 155: FldEff_QuestionMarkIcon")
{
    KNOWN_CRASHING;
    FillPool();
    gFieldEffectArguments[7] = -1;
    FldEff_QuestionMarkIcon();
}

TEST("Sprite audit probe 156: FldEff_HeartIcon")
{
    KNOWN_CRASHING;
    FillPool();
    gFieldEffectArguments[7] = -1;
    FldEff_HeartIcon();
}

TEST("Sprite audit probe 157: FldEff_DoubleExclMarkIcon")
{
    KNOWN_CRASHING;
    FillPool();
    gFieldEffectArguments[7] = -1;
    FldEff_DoubleExclMarkIcon();
}

TEST("Sprite audit probe 158: FldEff_XIcon")
{
    KNOWN_CRASHING;
    FillPool();
    gFieldEffectArguments[7] = -1;
    FldEff_XIcon();
}

TEST("Sprite audit probe 159: FldEff_SmileyFaceIcon")
{
    KNOWN_CRASHING;
    FillPool();
    gFieldEffectArguments[7] = -1;
    FldEff_SmileyFaceIcon();
}
