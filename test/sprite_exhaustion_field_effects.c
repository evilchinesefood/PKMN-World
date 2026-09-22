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
#include "constants/field_effects.h"
#include "event_data.h"
#include "main.h"
#include "fieldmap.h"
#include "palette.h"
#include "pokemon.h"
#include "constants/species.h"
#include "constants/moves.h"
#include "rotating_gate.h"
#include "item_use.h"
#include "oras_dowse.h"
#include "constants/maps.h"

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

static void ExpectFullPoolUnchanged(void)
{
    for (u32 i = 0; i < MAX_SPRITES; i++)
    {
        EXPECT(gSprites[i].inUse);
        EXPECT_EQ(gSprites[i].callback, SpriteCallbackDummy);
    }
}

TEST("Sprite exhaustion recovery 126: item wheel cancels with partial sprites, including dark caves")
{
    u32 available, flashLevel;
    struct Sprite sentinel;
    PARAMETRIZE { available = 0; flashLevel = 0; }
    PARAMETRIZE { available = 1; flashLevel = 0; }
    PARAMETRIZE { available = 4; flashLevel = 0; }
    PARAMETRIZE { available = 0; flashLevel = 2; }
    PARAMETRIZE { available = 5; flashLevel = 2; }
    PARAMETRIZE { available = 8; flashLevel = 2; }
    FillPool();
    for (u32 i = MAX_SPRITES - available; i < MAX_SPRITES; i++)
        DestroySprite(&gSprites[i]);
    sentinel = gSprites[MAX_SPRITES];
    gSaveBlock1Ptr->flashLevel = flashLevel;
    AddBagItem(ITEM_MACH_BIKE, 1);
    AddBagItem(ITEM_ITEMFINDER, 1);
    SetRegisteredItem(0, ITEM_MACH_BIKE);
    SetRegisteredItem(1, ITEM_ITEMFINDER);
    ASSUME(CountRegisteredItems() == 2);
    ASSUME(UseRegisteredKeyItemOnField());
    RunTasks();
    if (flashLevel > 1)
        RunTasks();
    gMain.newKeys = B_BUTTON;
    RunTasks();
    gMain.newKeys = 0;
    RunTasks();
    EXPECT_EQ(memcmp(&sentinel, &gSprites[MAX_SPRITES], sizeof(sentinel)), 0);
    for (u32 i = 0; i < MAX_SPRITES; i++)
        EXPECT(gSprites[i].inUse == (i < MAX_SPRITES - available));
    for (u32 i = 0; i < NUM_TASKS; i++)
        EXPECT(!gTasks[i].isActive);
}

TEST("Sprite exhaustion recovery 034: CreateObjectGraphicsSpriteWithTag")
{
    struct Sprite sentinel;
    FillPool();
    sentinel = gSprites[MAX_SPRITES];
    CreateObjectGraphicsSpriteUnchecked(OBJ_EVENT_GFX_LITTLE_BOY, SpriteCallbackDummy, 0, 0, 0);
    EXPECT_EQ(memcmp(&sentinel, &gSprites[MAX_SPRITES], sizeof(sentinel)), 0);
    ExpectFullPoolUnchanged();
}

TEST("Sprite exhaustion recovery 042: FldEff_CaveDust")
{
    struct Sprite sentinel;
    FillPool();
    sentinel = gSprites[MAX_SPRITES];
    FieldEffectActiveListAdd(FLDEFF_CAVE_DUST);
    FldEff_CaveDust();
    EXPECT_EQ(memcmp(&sentinel, &gSprites[MAX_SPRITES], sizeof(sentinel)), 0);
    EXPECT(!FieldEffectActiveListContains(FLDEFF_CAVE_DUST));
    ExpectFullPoolUnchanged();
}

TEST("Sprite exhaustion recovery 044: FldEff_TallGrass")
{
    struct Sprite sentinel;
    FillPool();
    sentinel = gSprites[MAX_SPRITES];
    FieldEffectActiveListAdd(FLDEFF_TALL_GRASS);
    FldEff_TallGrass();
    EXPECT_EQ(memcmp(&sentinel, &gSprites[MAX_SPRITES], sizeof(sentinel)), 0);
    EXPECT(!FieldEffectActiveListContains(FLDEFF_TALL_GRASS));
    ExpectFullPoolUnchanged();
}

TEST("Sprite exhaustion recovery 045: FldEff_JumpTallGrass")
{
    struct Sprite sentinel;
    FillPool();
    sentinel = gSprites[MAX_SPRITES];
    FieldEffectActiveListAdd(FLDEFF_JUMP_TALL_GRASS);
    FldEff_JumpTallGrass();
    EXPECT_EQ(memcmp(&sentinel, &gSprites[MAX_SPRITES], sizeof(sentinel)), 0);
    EXPECT(!FieldEffectActiveListContains(FLDEFF_JUMP_TALL_GRASS));
    ExpectFullPoolUnchanged();
}

TEST("Sprite exhaustion recovery 046: FldEff_LongGrass")
{
    struct Sprite sentinel;
    FillPool();
    sentinel = gSprites[MAX_SPRITES];
    FieldEffectActiveListAdd(FLDEFF_LONG_GRASS);
    FldEff_LongGrass();
    EXPECT_EQ(memcmp(&sentinel, &gSprites[MAX_SPRITES], sizeof(sentinel)), 0);
    EXPECT(!FieldEffectActiveListContains(FLDEFF_LONG_GRASS));
    ExpectFullPoolUnchanged();
}

TEST("Sprite exhaustion recovery 047: FldEff_JumpLongGrass")
{
    struct Sprite sentinel;
    FillPool();
    sentinel = gSprites[MAX_SPRITES];
    FieldEffectActiveListAdd(FLDEFF_JUMP_LONG_GRASS);
    FldEff_JumpLongGrass();
    EXPECT_EQ(memcmp(&sentinel, &gSprites[MAX_SPRITES], sizeof(sentinel)), 0);
    EXPECT(!FieldEffectActiveListContains(FLDEFF_JUMP_LONG_GRASS));
    ExpectFullPoolUnchanged();
}

TEST("Sprite exhaustion recovery 048: FldEff_ShortGrass")
{
    struct Sprite sentinel;
    FillPool();
    sentinel = gSprites[MAX_SPRITES];
    FieldEffectActiveListAdd(FLDEFF_SHORT_GRASS);
    FldEff_ShortGrass();
    EXPECT_EQ(memcmp(&sentinel, &gSprites[MAX_SPRITES], sizeof(sentinel)), 0);
    EXPECT(!FieldEffectActiveListContains(FLDEFF_SHORT_GRASS));
    ExpectFullPoolUnchanged();
}

TEST("Sprite exhaustion recovery 049: FldEff_SandFootprints")
{
    struct Sprite sentinel;
    FillPool();
    sentinel = gSprites[MAX_SPRITES];
    FieldEffectActiveListAdd(FLDEFF_SAND_FOOTPRINTS);
    FldEff_SandFootprints();
    EXPECT_EQ(memcmp(&sentinel, &gSprites[MAX_SPRITES], sizeof(sentinel)), 0);
    EXPECT(!FieldEffectActiveListContains(FLDEFF_SAND_FOOTPRINTS));
    ExpectFullPoolUnchanged();
}

TEST("Sprite exhaustion recovery 050: FldEff_DeepSandFootprints")
{
    struct Sprite sentinel;
    FillPool();
    sentinel = gSprites[MAX_SPRITES];
    FieldEffectActiveListAdd(FLDEFF_DEEP_SAND_FOOTPRINTS);
    FldEff_DeepSandFootprints();
    EXPECT_EQ(memcmp(&sentinel, &gSprites[MAX_SPRITES], sizeof(sentinel)), 0);
    EXPECT(!FieldEffectActiveListContains(FLDEFF_DEEP_SAND_FOOTPRINTS));
    ExpectFullPoolUnchanged();
}

TEST("Sprite exhaustion recovery 051: FldEff_TracksBug")
{
    struct Sprite sentinel;
    FillPool();
    sentinel = gSprites[MAX_SPRITES];
    FieldEffectActiveListAdd(FLDEFF_TRACKS_BUG);
    FldEff_TracksBug();
    EXPECT_EQ(memcmp(&sentinel, &gSprites[MAX_SPRITES], sizeof(sentinel)), 0);
    EXPECT(!FieldEffectActiveListContains(FLDEFF_TRACKS_BUG));
    ExpectFullPoolUnchanged();
}

TEST("Sprite exhaustion recovery 052: FldEff_TracksSpot")
{
    struct Sprite sentinel;
    FillPool();
    sentinel = gSprites[MAX_SPRITES];
    FieldEffectActiveListAdd(FLDEFF_TRACKS_SPOT);
    FldEff_TracksSpot();
    EXPECT_EQ(memcmp(&sentinel, &gSprites[MAX_SPRITES], sizeof(sentinel)), 0);
    EXPECT(!FieldEffectActiveListContains(FLDEFF_TRACKS_SPOT));
    ExpectFullPoolUnchanged();
}

TEST("Sprite exhaustion recovery 053: FldEff_BikeTireTracks")
{
    struct Sprite sentinel;
    FillPool();
    sentinel = gSprites[MAX_SPRITES];
    FieldEffectActiveListAdd(FLDEFF_BIKE_TIRE_TRACKS);
    FldEff_BikeTireTracks();
    EXPECT_EQ(memcmp(&sentinel, &gSprites[MAX_SPRITES], sizeof(sentinel)), 0);
    EXPECT(!FieldEffectActiveListContains(FLDEFF_BIKE_TIRE_TRACKS));
    ExpectFullPoolUnchanged();
}

TEST("Sprite exhaustion recovery 054: FldEff_TracksSlither")
{
    struct Sprite sentinel;
    FillPool();
    sentinel = gSprites[MAX_SPRITES];
    FieldEffectActiveListAdd(FLDEFF_TRACKS_SLITHER);
    FldEff_TracksSlither();
    EXPECT_EQ(memcmp(&sentinel, &gSprites[MAX_SPRITES], sizeof(sentinel)), 0);
    EXPECT(!FieldEffectActiveListContains(FLDEFF_TRACKS_SLITHER));
    ExpectFullPoolUnchanged();
}

TEST("Sprite exhaustion recovery 055: FldEff_Splash")
{
    struct Sprite sentinel;
    FillPool();
    sentinel = gSprites[MAX_SPRITES];
    FieldEffectActiveListAdd(FLDEFF_SPLASH);
    FldEff_Splash();
    EXPECT_EQ(memcmp(&sentinel, &gSprites[MAX_SPRITES], sizeof(sentinel)), 0);
    EXPECT(!FieldEffectActiveListContains(FLDEFF_SPLASH));
    ExpectFullPoolUnchanged();
}

TEST("Sprite exhaustion recovery 056: FldEff_JumpSmallSplash")
{
    struct Sprite sentinel;
    FillPool();
    sentinel = gSprites[MAX_SPRITES];
    FieldEffectActiveListAdd(FLDEFF_JUMP_SMALL_SPLASH);
    FldEff_JumpSmallSplash();
    EXPECT_EQ(memcmp(&sentinel, &gSprites[MAX_SPRITES], sizeof(sentinel)), 0);
    EXPECT(!FieldEffectActiveListContains(FLDEFF_JUMP_SMALL_SPLASH));
    ExpectFullPoolUnchanged();
}

TEST("Sprite exhaustion recovery 057: FldEff_JumpBigSplash")
{
    struct Sprite sentinel;
    FillPool();
    sentinel = gSprites[MAX_SPRITES];
    FieldEffectActiveListAdd(FLDEFF_JUMP_BIG_SPLASH);
    FldEff_JumpBigSplash();
    EXPECT_EQ(memcmp(&sentinel, &gSprites[MAX_SPRITES], sizeof(sentinel)), 0);
    EXPECT(!FieldEffectActiveListContains(FLDEFF_JUMP_BIG_SPLASH));
    ExpectFullPoolUnchanged();
}

TEST("Sprite exhaustion recovery 058: FldEff_FeetInFlowingWater")
{
    struct Sprite sentinel;
    FillPool();
    sentinel = gSprites[MAX_SPRITES];
    FieldEffectActiveListAdd(FLDEFF_FEET_IN_FLOWING_WATER);
    FldEff_FeetInFlowingWater();
    EXPECT_EQ(memcmp(&sentinel, &gSprites[MAX_SPRITES], sizeof(sentinel)), 0);
    EXPECT(!FieldEffectActiveListContains(FLDEFF_FEET_IN_FLOWING_WATER));
    ExpectFullPoolUnchanged();
}

TEST("Sprite exhaustion recovery 059: FldEff_Ripple")
{
    struct Sprite sentinel;
    FillPool();
    sentinel = gSprites[MAX_SPRITES];
    FieldEffectActiveListAdd(FLDEFF_RIPPLE);
    FldEff_Ripple();
    EXPECT_EQ(memcmp(&sentinel, &gSprites[MAX_SPRITES], sizeof(sentinel)), 0);
    EXPECT(!FieldEffectActiveListContains(FLDEFF_RIPPLE));
    ExpectFullPoolUnchanged();
}

TEST("Sprite exhaustion recovery 060: FldEff_HotSpringsWater")
{
    struct Sprite sentinel;
    FillPool();
    sentinel = gSprites[MAX_SPRITES];
    FieldEffectActiveListAdd(FLDEFF_HOT_SPRINGS_WATER);
    FldEff_HotSpringsWater();
    EXPECT_EQ(memcmp(&sentinel, &gSprites[MAX_SPRITES], sizeof(sentinel)), 0);
    EXPECT(!FieldEffectActiveListContains(FLDEFF_HOT_SPRINGS_WATER));
    ExpectFullPoolUnchanged();
}

TEST("Sprite exhaustion recovery 061: FldEff_ShakingGrass")
{
    struct Sprite sentinel;
    FillPool();
    sentinel = gSprites[MAX_SPRITES];
    FieldEffectActiveListAdd(FLDEFF_SHAKING_GRASS);
    FldEff_ShakingGrass();
    EXPECT_EQ(memcmp(&sentinel, &gSprites[MAX_SPRITES], sizeof(sentinel)), 0);
    EXPECT(!FieldEffectActiveListContains(FLDEFF_SHAKING_GRASS));
    ExpectFullPoolUnchanged();
}

TEST("Sprite exhaustion recovery 062: FldEff_ShakingGrass2")
{
    struct Sprite sentinel;
    FillPool();
    sentinel = gSprites[MAX_SPRITES];
    FieldEffectActiveListAdd(FLDEFF_SHAKING_LONG_GRASS);
    FldEff_ShakingGrass2();
    EXPECT_EQ(memcmp(&sentinel, &gSprites[MAX_SPRITES], sizeof(sentinel)), 0);
    EXPECT(!FieldEffectActiveListContains(FLDEFF_SHAKING_LONG_GRASS));
    ExpectFullPoolUnchanged();
}

TEST("Sprite exhaustion recovery 063: FldEff_UnusedSand")
{
    struct Sprite sentinel;
    FillPool();
    sentinel = gSprites[MAX_SPRITES];
    FieldEffectActiveListAdd(FLDEFF_SAND_HOLE);
    FldEff_UnusedSand();
    EXPECT_EQ(memcmp(&sentinel, &gSprites[MAX_SPRITES], sizeof(sentinel)), 0);
    EXPECT(!FieldEffectActiveListContains(FLDEFF_SAND_HOLE));
    ExpectFullPoolUnchanged();
}

TEST("Sprite exhaustion recovery 064: FldEff_WaterSurfacing")
{
    struct Sprite sentinel;
    FillPool();
    sentinel = gSprites[MAX_SPRITES];
    FieldEffectActiveListAdd(FLDEFF_WATER_SURFACING);
    FldEff_WaterSurfacing();
    EXPECT_EQ(memcmp(&sentinel, &gSprites[MAX_SPRITES], sizeof(sentinel)), 0);
    EXPECT(!FieldEffectActiveListContains(FLDEFF_WATER_SURFACING));
    ExpectFullPoolUnchanged();
}

TEST("Sprite exhaustion recovery 065: FldEff_Ash")
{
    struct Sprite sentinel;
    FillPool();
    sentinel = gSprites[MAX_SPRITES];
    FieldEffectActiveListAdd(FLDEFF_ASH);
    gFieldEffectArguments[0] = 100;
    gFieldEffectArguments[1] = 100;
    FldEff_Ash();
    EXPECT_EQ(memcmp(&sentinel, &gSprites[MAX_SPRITES], sizeof(sentinel)), 0);
    EXPECT(!FieldEffectActiveListContains(FLDEFF_ASH));
    ExpectFullPoolUnchanged();
}

TEST("Sprite exhaustion recovery 067: FldEff_SurfBlob")
{
    struct Sprite sentinel;
    FillPool();
    sentinel = gSprites[MAX_SPRITES];
    FieldEffectActiveListAdd(FLDEFF_SURF_BLOB);
    gFieldEffectArguments[2] = 1;
    FldEff_SurfBlob();
    EXPECT_EQ(memcmp(&sentinel, &gSprites[MAX_SPRITES], sizeof(sentinel)), 0);
    EXPECT(!FieldEffectActiveListContains(FLDEFF_SURF_BLOB));
    ExpectFullPoolUnchanged();
}

TEST("Sprite exhaustion recovery 068: FldEff_Dust")
{
    struct Sprite sentinel;
    FillPool();
    sentinel = gSprites[MAX_SPRITES];
    FieldEffectActiveListAdd(FLDEFF_DUST);
    FldEff_Dust();
    EXPECT_EQ(memcmp(&sentinel, &gSprites[MAX_SPRITES], sizeof(sentinel)), 0);
    EXPECT(!FieldEffectActiveListContains(FLDEFF_DUST));
    ExpectFullPoolUnchanged();
}

TEST("Sprite exhaustion recovery 069: FldEff_RockClimbDust")
{
    struct Sprite sentinel;
    FillPool();
    sentinel = gSprites[MAX_SPRITES];
    FieldEffectActiveListAdd(FLDEFF_ROCK_CLIMB_DUST);
    FldEff_RockClimbDust();
    EXPECT(!FieldEffectActiveListContains(FLDEFF_ROCK_CLIMB_DUST));
    EXPECT_EQ(memcmp(&sentinel, &gSprites[MAX_SPRITES], sizeof(sentinel)), 0);
    ExpectFullPoolUnchanged();
}

TEST("Sprite exhaustion recovery 070: FldEff_SandPile")
{
    struct Sprite sentinel;
    FillPool();
    sentinel = gSprites[MAX_SPRITES];
    FieldEffectActiveListAdd(FLDEFF_SAND_PILE);
    FldEff_SandPile();
    EXPECT_EQ(memcmp(&sentinel, &gSprites[MAX_SPRITES], sizeof(sentinel)), 0);
    EXPECT(!FieldEffectActiveListContains(FLDEFF_SAND_PILE));
    ExpectFullPoolUnchanged();
}

TEST("Sprite exhaustion recovery 071: FldEff_Bubbles")
{
    struct Sprite sentinel;
    FillPool();
    sentinel = gSprites[MAX_SPRITES];
    FieldEffectActiveListAdd(FLDEFF_BUBBLES);
    FldEff_Bubbles();
    EXPECT_EQ(memcmp(&sentinel, &gSprites[MAX_SPRITES], sizeof(sentinel)), 0);
    EXPECT(!FieldEffectActiveListContains(FLDEFF_BUBBLES));
    ExpectFullPoolUnchanged();
}

TEST("Sprite exhaustion recovery 072: FldEff_BerryTreeGrowthSparkle")
{
    struct Sprite sentinel;
    FillPool();
    sentinel = gSprites[MAX_SPRITES];
    FieldEffectActiveListAdd(FLDEFF_BERRY_TREE_GROWTH_SPARKLE);
    FldEff_BerryTreeGrowthSparkle();
    EXPECT_EQ(memcmp(&sentinel, &gSprites[MAX_SPRITES], sizeof(sentinel)), 0);
    EXPECT(!FieldEffectActiveListContains(FLDEFF_BERRY_TREE_GROWTH_SPARKLE));
    ExpectFullPoolUnchanged();
}

TEST("Sprite exhaustion recovery 073: ShowDisguiseFieldEffect")
{
    struct Sprite sentinel;
    FillPool();
    sentinel = gSprites[MAX_SPRITES];
    FieldEffectActiveListAdd(FLDEFF_TREE_DISGUISE);
    ShowTreeDisguiseFieldEffect();
    EXPECT_EQ(memcmp(&sentinel, &gSprites[MAX_SPRITES], sizeof(sentinel)), 0);
    EXPECT(!FieldEffectActiveListContains(FLDEFF_TREE_DISGUISE));
    ExpectFullPoolUnchanged();
}

TEST("Sprite exhaustion recovery 074: FldEff_Sparkle")
{
    struct Sprite sentinel;
    FillPool();
    sentinel = gSprites[MAX_SPRITES];
    FieldEffectActiveListAdd(FLDEFF_SPARKLE);
    FldEff_Sparkle();
    EXPECT_EQ(memcmp(&sentinel, &gSprites[MAX_SPRITES], sizeof(sentinel)), 0);
    EXPECT(!FieldEffectActiveListContains(FLDEFF_SPARKLE));
    ExpectFullPoolUnchanged();
}

TEST("Sprite exhaustion recovery 078: CreateCloudSprites")
{
    struct Sprite sentinel;
    FillPool();
    sentinel = gSprites[MAX_SPRITES];
    Clouds_Main(); Clouds_Main();
    EXPECT_EQ(memcmp(&sentinel, &gSprites[MAX_SPRITES], sizeof(sentinel)), 0);
    ExpectFullPoolUnchanged();
}

TEST("Sprite exhaustion recovery 079: CreateSnowflakeSprite")
{
    struct Sprite sentinel;
    FillPool();
    sentinel = gSprites[MAX_SPRITES];
    gWeatherPtr->targetSnowflakeSpriteCount = 1; gWeatherPtr->snowflakeVisibleCounter = 36;
    Snow_Main();
    EXPECT_EQ(memcmp(&sentinel, &gSprites[MAX_SPRITES], sizeof(sentinel)), 0);
    ExpectFullPoolUnchanged();
}

TEST("Sprite exhaustion recovery 080: CreateFogHorizontalSprites")
{
    struct Sprite sentinel;
    FillPool();
    sentinel = gSprites[MAX_SPRITES];
    FogHorizontal_Main();
    EXPECT_EQ(memcmp(&sentinel, &gSprites[MAX_SPRITES], sizeof(sentinel)), 0);
    ExpectFullPoolUnchanged();
}

TEST("Sprite exhaustion recovery 081: CreateAshSprites")
{
    struct Sprite sentinel;
    FillPool();
    sentinel = gSprites[MAX_SPRITES];
    gWeatherPtr->initStep = 1;
    Ash_Main();
    EXPECT_EQ(memcmp(&sentinel, &gSprites[MAX_SPRITES], sizeof(sentinel)), 0);
    ExpectFullPoolUnchanged();
}

TEST("Sprite exhaustion recovery 082: CreateFogDiagonalSprites")
{
    struct Sprite sentinel;
    FillPool();
    sentinel = gSprites[MAX_SPRITES];
    FogDiagonal_Main();
    EXPECT_EQ(memcmp(&sentinel, &gSprites[MAX_SPRITES], sizeof(sentinel)), 0);
    ExpectFullPoolUnchanged();
}

TEST("Sprite exhaustion recovery 083: CreateSandstormSprites")
{
    struct Sprite sentinel;
    FillPool();
    sentinel = gSprites[MAX_SPRITES];
    Sandstorm_Main();
    EXPECT_EQ(memcmp(&sentinel, &gSprites[MAX_SPRITES], sizeof(sentinel)), 0);
    ExpectFullPoolUnchanged();
}

TEST("Sprite exhaustion recovery 084: CreateSwirlSandstormSprites")
{
    struct Sprite sentinel;
    FillPool();
    sentinel = gSprites[MAX_SPRITES];
    gWeatherPtr->sandstormSpritesCreated = TRUE;
    Sandstorm_Main();
    EXPECT_EQ(memcmp(&sentinel, &gSprites[MAX_SPRITES], sizeof(sentinel)), 0);
    ExpectFullPoolUnchanged();
}

TEST("Sprite exhaustion recovery 085: CreateBubbleSprite")
{
    struct Sprite sentinel;
    FillPool();
    sentinel = gSprites[MAX_SPRITES];
    gWeatherPtr->initStep = 2; gWeatherPtr->bubblesDelayCounter = 0x7fff;
    Bubbles_Main();
    EXPECT_EQ(memcmp(&sentinel, &gSprites[MAX_SPRITES], sizeof(sentinel)), 0);
    ExpectFullPoolUnchanged();
}

TEST("Sprite exhaustion recovery 086: DoSecretBaseGlitterMatSparkle")
{
    struct Sprite sentinel;
    FillPool();
    sentinel = gSprites[MAX_SPRITES];
    DoSecretBaseGlitterMatSparkle();
    EXPECT_EQ(memcmp(&sentinel, &gSprites[MAX_SPRITES], sizeof(sentinel)), 0);
    ExpectFullPoolUnchanged();
}

TEST("Sprite exhaustion recovery 087: CreateRecordMixingLights")
{
    struct Sprite sentinel;
    FillPool();
    sentinel = gSprites[MAX_SPRITES];
    CreateRecordMixingLights();
    EXPECT_EQ(memcmp(&sentinel, &gSprites[MAX_SPRITES], sizeof(sentinel)), 0);
    ExpectFullPoolUnchanged();
}

TEST("Sprite exhaustion recovery 103: FldEff_ORASDowsing")
{
    struct Sprite sentinel;
    FillPool();
    sentinel = gSprites[MAX_SPRITES];
    FieldEffectActiveListAdd(FLDEFF_ORAS_DOWSE);
    gPlayerAvatar.gender = MALE;
    FldEff_ORASDowsing();
    EXPECT_EQ(memcmp(&sentinel, &gSprites[MAX_SPRITES], sizeof(sentinel)), 0);
    EXPECT(!FieldEffectActiveListContains(FLDEFF_ORAS_DOWSE));
    ExpectFullPoolUnchanged();
    EXPECT(!FlagGet(I_ORAS_DOWSING_FLAG));
    EXPECT_EQ(gObjectEvents[0].fieldEffectSpriteId, MAX_SPRITES);
}

TEST("Sprite exhaustion recovery 104: FldEff_ORASDowsing")
{
    struct Sprite sentinel;
    FillPool();
    sentinel = gSprites[MAX_SPRITES];
    FieldEffectActiveListAdd(FLDEFF_ORAS_DOWSE);
    gPlayerAvatar.gender = FEMALE;
    FldEff_ORASDowsing();
    EXPECT_EQ(memcmp(&sentinel, &gSprites[MAX_SPRITES], sizeof(sentinel)), 0);
    EXPECT(!FieldEffectActiveListContains(FLDEFF_ORAS_DOWSE));
    ExpectFullPoolUnchanged();
    EXPECT(!FlagGet(I_ORAS_DOWSING_FLAG));
    EXPECT_EQ(gObjectEvents[0].fieldEffectSpriteId, MAX_SPRITES);
}

TEST("Sprite exhaustion recovery 154: FldEff_QuestionMarkIcon")
{
    struct Sprite sentinel;
    FillPool();
    sentinel = gSprites[MAX_SPRITES];
    FieldEffectActiveListAdd(FLDEFF_QUESTION_MARK_ICON);
    gFieldEffectArguments[7] = 0;
    FldEff_QuestionMarkIcon();
    EXPECT_EQ(memcmp(&sentinel, &gSprites[MAX_SPRITES], sizeof(sentinel)), 0);
    EXPECT(!FieldEffectActiveListContains(FLDEFF_QUESTION_MARK_ICON));
    ExpectFullPoolUnchanged();
}

TEST("Sprite exhaustion recovery 155: FldEff_QuestionMarkIcon")
{
    struct Sprite sentinel;
    FillPool();
    sentinel = gSprites[MAX_SPRITES];
    FieldEffectActiveListAdd(FLDEFF_QUESTION_MARK_ICON);
    gFieldEffectArguments[7] = -1;
    FldEff_QuestionMarkIcon();
    EXPECT_EQ(memcmp(&sentinel, &gSprites[MAX_SPRITES], sizeof(sentinel)), 0);
    EXPECT(!FieldEffectActiveListContains(FLDEFF_QUESTION_MARK_ICON));
    ExpectFullPoolUnchanged();
}

TEST("Sprite exhaustion recovery 156: FldEff_HeartIcon")
{
    struct Sprite sentinel;
    FillPool();
    sentinel = gSprites[MAX_SPRITES];
    FieldEffectActiveListAdd(FLDEFF_HEART_ICON);
    gFieldEffectArguments[7] = -1;
    FldEff_HeartIcon();
    EXPECT_EQ(memcmp(&sentinel, &gSprites[MAX_SPRITES], sizeof(sentinel)), 0);
    EXPECT(!FieldEffectActiveListContains(FLDEFF_HEART_ICON));
    ExpectFullPoolUnchanged();
}

TEST("Sprite exhaustion recovery 157: FldEff_DoubleExclMarkIcon")
{
    struct Sprite sentinel;
    FillPool();
    sentinel = gSprites[MAX_SPRITES];
    FieldEffectActiveListAdd(FLDEFF_DOUBLE_EXCL_MARK_ICON);
    gFieldEffectArguments[7] = -1;
    FldEff_DoubleExclMarkIcon();
    EXPECT_EQ(memcmp(&sentinel, &gSprites[MAX_SPRITES], sizeof(sentinel)), 0);
    EXPECT(!FieldEffectActiveListContains(FLDEFF_DOUBLE_EXCL_MARK_ICON));
    ExpectFullPoolUnchanged();
}

TEST("Sprite exhaustion recovery 158: FldEff_XIcon")
{
    struct Sprite sentinel;
    FillPool();
    sentinel = gSprites[MAX_SPRITES];
    FieldEffectActiveListAdd(FLDEFF_X_ICON);
    gFieldEffectArguments[7] = -1;
    FldEff_XIcon();
    EXPECT_EQ(memcmp(&sentinel, &gSprites[MAX_SPRITES], sizeof(sentinel)), 0);
    EXPECT(!FieldEffectActiveListContains(FLDEFF_X_ICON));
    ExpectFullPoolUnchanged();
}

TEST("Sprite exhaustion recovery 159: FldEff_SmileyFaceIcon")
{
    struct Sprite sentinel;
    FillPool();
    sentinel = gSprites[MAX_SPRITES];
    FieldEffectActiveListAdd(FLDEFF_SMILEY_FACE_ICON);
    gFieldEffectArguments[7] = -1;
    FldEff_SmileyFaceIcon();
    EXPECT_EQ(memcmp(&sentinel, &gSprites[MAX_SPRITES], sizeof(sentinel)), 0);
    EXPECT(!FieldEffectActiveListContains(FLDEFF_SMILEY_FACE_ICON));
    ExpectFullPoolUnchanged();
}

TEST("Sprite exhaustion recovery: field scripts can retry and release their sprites")
{
    u32 effect;
    PARAMETRIZE { effect = FLDEFF_TALL_GRASS; }
    PARAMETRIZE { effect = FLDEFF_RIPPLE; }
    PARAMETRIZE { effect = FLDEFF_DUST; }
    PARAMETRIZE { effect = FLDEFF_ROCK_CLIMB_DUST; }
    PARAMETRIZE { effect = FLDEFF_JUMP_TALL_GRASS; }
    PARAMETRIZE { effect = FLDEFF_SAND_FOOTPRINTS; }
    PARAMETRIZE { effect = FLDEFF_JUMP_BIG_SPLASH; }
    PARAMETRIZE { effect = FLDEFF_SPLASH; }
    PARAMETRIZE { effect = FLDEFF_JUMP_SMALL_SPLASH; }
    PARAMETRIZE { effect = FLDEFF_LONG_GRASS; }
    PARAMETRIZE { effect = FLDEFF_JUMP_LONG_GRASS; }
    PARAMETRIZE { effect = FLDEFF_SHAKING_GRASS; }
    PARAMETRIZE { effect = FLDEFF_SHAKING_LONG_GRASS; }
    PARAMETRIZE { effect = FLDEFF_SAND_HOLE; }
    PARAMETRIZE { effect = FLDEFF_WATER_SURFACING; }
    PARAMETRIZE { effect = FLDEFF_BERRY_TREE_GROWTH_SPARKLE; }
    PARAMETRIZE { effect = FLDEFF_DEEP_SAND_FOOTPRINTS; }
    PARAMETRIZE { effect = FLDEFF_TREE_DISGUISE; }
    PARAMETRIZE { effect = FLDEFF_QUESTION_MARK_ICON; }
    PARAMETRIZE { effect = FLDEFF_FEET_IN_FLOWING_WATER; }
    PARAMETRIZE { effect = FLDEFF_BIKE_TIRE_TRACKS; }
    PARAMETRIZE { effect = FLDEFF_SAND_PILE; }
    PARAMETRIZE { effect = FLDEFF_SHORT_GRASS; }
    PARAMETRIZE { effect = FLDEFF_HOT_SPRINGS_WATER; }
    PARAMETRIZE { effect = FLDEFF_HEART_ICON; }
    PARAMETRIZE { effect = FLDEFF_BUBBLES; }
    PARAMETRIZE { effect = FLDEFF_SPARKLE; }
    PARAMETRIZE { effect = FLDEFF_X_ICON; }
    PARAMETRIZE { effect = FLDEFF_DOUBLE_EXCL_MARK_ICON; }
    PARAMETRIZE { effect = FLDEFF_TRACKS_BUG; }
    PARAMETRIZE { effect = FLDEFF_TRACKS_SPOT; }
    PARAMETRIZE { effect = FLDEFF_TRACKS_SLITHER; }
    PARAMETRIZE { effect = FLDEFF_CAVE_DUST; }
    PARAMETRIZE { effect = FLDEFF_SMILEY_FACE_ICON; }

    FillPool();
    gFieldEffectArguments[7] = -1;
    FieldEffectStart(effect);
    EXPECT(!FieldEffectActiveListContains(effect));
    DestroySprite(&gSprites[MAX_SPRITES - 1]);
    memset(gFieldEffectArguments, 0, sizeof(gFieldEffectArguments));
    gFieldEffectArguments[0] = 1;
    gFieldEffectArguments[7] = -1;
    FieldEffectStart(effect);
    EXPECT(gSprites[MAX_SPRITES - 1].inUse);
    EXPECT(FieldEffectActiveListContains(effect));
    FieldEffectStop(&gSprites[MAX_SPRITES - 1], effect);
    EXPECT(!gSprites[MAX_SPRITES - 1].inUse);
    EXPECT(!FieldEffectActiveListContains(effect));
    for (u32 i = 0; i < MAX_SPRITES - 1; i++)
        EXPECT(gSprites[i].inUse);
}

TEST("Sprite exhaustion recovery: weather finishes with zero or partial capacity and can restart")
{
    u32 available, frames;
    void (*init)(void);
    bool8 (*finish)(void);
    PARAMETRIZE { available = 0; init = Clouds_InitAll; finish = Clouds_Finish; }
    PARAMETRIZE { available = 1; init = Clouds_InitAll; finish = Clouds_Finish; }
    PARAMETRIZE { available = 8; init = Clouds_InitAll; finish = Clouds_Finish; }
    PARAMETRIZE { available = 0; init = Snow_InitAll; finish = Snow_Finish; }
    PARAMETRIZE { available = 1; init = Snow_InitAll; finish = Snow_Finish; }
    PARAMETRIZE { available = 8; init = Snow_InitAll; finish = Snow_Finish; }
    PARAMETRIZE { available = 0; init = FogHorizontal_InitAll; finish = FogHorizontal_Finish; }
    PARAMETRIZE { available = 1; init = FogHorizontal_InitAll; finish = FogHorizontal_Finish; }
    PARAMETRIZE { available = 8; init = FogHorizontal_InitAll; finish = FogHorizontal_Finish; }
    PARAMETRIZE { available = 0; init = Ash_InitAll; finish = Ash_Finish; }
    PARAMETRIZE { available = 1; init = Ash_InitAll; finish = Ash_Finish; }
    PARAMETRIZE { available = 8; init = Ash_InitAll; finish = Ash_Finish; }
    PARAMETRIZE { available = 0; init = FogDiagonal_InitAll; finish = FogDiagonal_Finish; }
    PARAMETRIZE { available = 1; init = FogDiagonal_InitAll; finish = FogDiagonal_Finish; }
    PARAMETRIZE { available = 8; init = FogDiagonal_InitAll; finish = FogDiagonal_Finish; }
    PARAMETRIZE { available = 0; init = Sandstorm_InitAll; finish = Sandstorm_Finish; }
    PARAMETRIZE { available = 1; init = Sandstorm_InitAll; finish = Sandstorm_Finish; }
    PARAMETRIZE { available = 8; init = Sandstorm_InitAll; finish = Sandstorm_Finish; }
    PARAMETRIZE { available = 0; init = Bubbles_InitAll; finish = Bubbles_Finish; }
    PARAMETRIZE { available = 1; init = Bubbles_InitAll; finish = Bubbles_Finish; }
    PARAMETRIZE { available = 8; init = Bubbles_InitAll; finish = Bubbles_Finish; }

    FillPool();
    for (u32 i = MAX_SPRITES - available; i < MAX_SPRITES; i++)
        DestroySprite(&gSprites[i]);
    for (u32 cycle = 0; cycle < 2; cycle++)
    {
        init();
        EXPECT(gWeatherPtr->weatherGfxLoaded);
        gWeatherPtr->finishStep = 0;
        for (frames = 0; frames < 2048 && finish(); frames++);
        EXPECT_LT(frames, 2048);
        for (u32 i = 0; i < MAX_SPRITES; i++)
            EXPECT(gSprites[i].inUse == (i < MAX_SPRITES - available));
    }
}

TEST("Sprite exhaustion recovery: missing disguises finish revealing and retry")
{
    struct ObjectEvent *object;
    struct Sprite sentinel;
    FillPool();
    sentinel = gSprites[MAX_SPRITES];
    object = &gObjectEvents[0];
    object->directionSequenceIndex = 1;
    object->fieldEffectSpriteId = FieldEffectStart(FLDEFF_TREE_DISGUISE);
    EXPECT_EQ(object->fieldEffectSpriteId, MAX_SPRITES);
    StartRevealDisguise(object);
    EXPECT(UpdateRevealDisguise(object));
    EXPECT_EQ(object->directionSequenceIndex, 2);
    EXPECT_EQ(memcmp(&sentinel, &gSprites[MAX_SPRITES], sizeof(sentinel)), 0);
    DestroySprite(&gSprites[MAX_SPRITES - 1]);
    object->fieldEffectSpriteId = FieldEffectStart(FLDEFF_TREE_DISGUISE);
    EXPECT_EQ(object->fieldEffectSpriteId, MAX_SPRITES - 1);
    object->directionSequenceIndex = 1;
    StartRevealDisguise(object);
    EXPECT_EQ(gSprites[MAX_SPRITES - 1].data[0], 1);
    gSprites[MAX_SPRITES - 1].data[7] = TRUE;
    EXPECT(UpdateRevealDisguise(object));
}

TEST("Sprite exhaustion recovery: missing surf blob ignores bob and visibility updates")
{
    struct Sprite sentinel;
    FillPool();
    sentinel = gSprites[MAX_SPRITES];
    gFieldEffectArguments[2] = 1; // Generic NPC blob, independent of the player's mount choice.
    EXPECT_EQ(FieldEffectStart(FLDEFF_SURF_BLOB), MAX_SPRITES);
    SetSurfBlob_BobState(MAX_SPRITES, 1);
    SetSurfBlob_DontSyncAnim(MAX_SPRITES, TRUE);
    SetSurfBlob_PlayerOffset(MAX_SPRITES, TRUE, 8);
    gObjectEvents[0].fieldEffectSpriteId = MAX_SPRITES;
    gPlayerAvatar.flags = PLAYER_AVATAR_FLAG_SURFING;
    SetPlayerInvisibility(TRUE);
    EXPECT_EQ(memcmp(&sentinel, &gSprites[MAX_SPRITES], sizeof(sentinel)), 0);
    DestroySprite(&gSprites[MAX_SPRITES - 1]);
    EXPECT_EQ(FieldEffectStart(FLDEFF_SURF_BLOB), MAX_SPRITES - 1);
    EXPECT(!FieldEffectActiveListContains(FLDEFF_SURF_BLOB));
}

TEST("Sprite exhaustion recovery: optional object graphics retry without allocating in a full pool")
{
    FillPool();
    EXPECT_EQ(CreateObjectGraphicsSpriteUnchecked(OBJ_EVENT_GFX_LITTLE_BOY, SpriteCallbackDummy, 0, 0, 0), MAX_SPRITES);
    DestroySprite(&gSprites[MAX_SPRITES - 1]);
    EXPECT_EQ(CreateObjectGraphicsSpriteUnchecked(OBJ_EVENT_GFX_LITTLE_BOY, SpriteCallbackDummy, 0, 0, 0), MAX_SPRITES - 1);
}

TEST("Sprite exhaustion recovery: ash applies the tile change without a sprite")
{
    u16 map[32 * 32] = {0};
    FillPool();
    gBackupMapLayout.width = 32;
    gBackupMapLayout.height = 32;
    gBackupMapLayout.map = map;
    gFieldEffectArguments[0] = 30;
    gFieldEffectArguments[1] = 30;
    gFieldEffectArguments[4] = 3;
    FieldEffectStart(FLDEFF_ASH);
    EXPECT_EQ(map[30 * 32 + 30], 3);
    EXPECT(gObjectEvents[0].triggerGroundEffectsOnMove);
    EXPECT(!FieldEffectActiveListContains(FLDEFF_ASH));
    ExpectFullPoolUnchanged();
}

TEST("Sprite exhaustion recovery: flight enters and exits with missing mount decorations")
{
    u32 available;
    struct Sprite sentinel;
    PARAMETRIZE { available = 0; }
    PARAMETRIZE { available = 1; }
    PARAMETRIZE { available = 2; }
    PARAMETRIZE { available = 3; }
    PARAMETRIZE { available = 4; }
    FillPool();
    for (u32 i = MAX_SPRITES - available; i < MAX_SPRITES; i++)
        DestroySprite(&gSprites[i]);
    sentinel = gSprites[MAX_SPRITES];
    gObjectEvents[0].movementDirection = DIR_SOUTH;
    gObjectEvents[0].facingDirection = DIR_SOUTH;
    StartOverworldFlight();
    EXPECT(IsPlayerFlying());
    for (u32 i = MAX_SPRITES - available; i < MAX_SPRITES; i++)
        if (gSprites[i].inUse)
            gSprites[i].callback(&gSprites[i]);
    EndOverworldFlight();
    EXPECT(!IsPlayerFlying());
    EXPECT_EQ(memcmp(&sentinel, &gSprites[MAX_SPRITES], sizeof(sentinel)), 0);
    // Landing may create one ordinary shadow, but must preserve existing occupants.
    for (u32 i = 1; i < MAX_SPRITES - available; i++)
    {
        EXPECT(gSprites[i].inUse);
        EXPECT_EQ(gSprites[i].callback, SpriteCallbackDummy);
    }
}

TEST("Sprite exhaustion recovery: Rock Climb completes without a blob")
{
    struct ObjectEvent *object;
    struct Sprite sentinel;
    FillPool();
    object = &gObjectEvents[0];
    object->movementDirection = DIR_SOUTH;
    object->facingDirection = DIR_SOUTH;
    sentinel = gSprites[MAX_SPRITES];
    FieldEffectStart(FLDEFF_USE_ROCK_CLIMB);
    ASSUME(gTasks[0].isActive);
    // Enter the jump stage after the separate field-move cutscene.
    gTasks[0].data[0] = 3;
    RunTasks();
    EXPECT_EQ(object->fieldEffectSpriteId, MAX_SPRITES);
    EXPECT_EQ(gTasks[0].data[0], 4);
    object->heldMovementFinished = TRUE;
    RunTasks();
    EXPECT_EQ(gTasks[0].data[0], 6);
    // Complete the final jump, checking the same task's teardown.
    gTasks[0].data[0] = 8;
    object->heldMovementFinished = TRUE;
    RunTasks();
    EXPECT(!gTasks[0].isActive);
    EXPECT(!gPlayerAvatar.preventStep);
    EXPECT(!FieldEffectActiveListContains(FLDEFF_USE_ROCK_CLIMB));
    EXPECT_EQ(memcmp(&sentinel, &gSprites[MAX_SPRITES], sizeof(sentinel)), 0);
}

extern void SetMewAboveGrass(void);
extern void DestroyMewEmergingGrassSprite(void);

TEST("Sprite exhaustion recovery: Mew grass skips creation and can retry")
{
    FillPool();
    gSaveBlock1Ptr->location.mapGroup = 0;
    gSaveBlock1Ptr->location.mapNum = 0;
    SetMewAboveGrass();
    DestroyMewEmergingGrassSprite();
    ExpectFullPoolUnchanged();
    DestroySprite(&gSprites[MAX_SPRITES - 1]);
    SetMewAboveGrass();
    EXPECT(gSprites[MAX_SPRITES - 1].inUse);
    DestroyMewEmergingGrassSprite();
    EXPECT(!gSprites[MAX_SPRITES - 1].inUse);
}

TEST("Sprite exhaustion recovery: rotating gates retry when the camera updates")
{
    FillPool();
    gSaveBlock1Ptr->location.mapGroup = MAP_GROUP(MAP_FORTREE_CITY_GYM);
    gSaveBlock1Ptr->location.mapNum = MAP_NUM(MAP_FORTREE_CITY_GYM);
    gSaveBlock1Ptr->pos.x = 6;
    gSaveBlock1Ptr->pos.y = 7;
    RotatingGate_InitPuzzleAndGraphics();
    ExpectFullPoolUnchanged();
    DestroySprite(&gSprites[MAX_SPRITES - 1]);
    RotatingGatePuzzleCameraUpdate(0, 0);
    EXPECT(gSprites[MAX_SPRITES - 1].inUse);
    gSaveBlock1Ptr->pos.x = 100;
    gSaveBlock1Ptr->pos.y = 100;
    RotatingGatePuzzleCameraUpdate(0, 0);
    EXPECT(!gSprites[MAX_SPRITES - 1].inUse);
}

TEST("Sprite exhaustion recovery: Deoxys rock fragments skip missing slots")
{
    u32 available;
    PARAMETRIZE { available = 0; }
    PARAMETRIZE { available = 1; }
    PARAMETRIZE { available = 4; }
    FillPool();
    for (u32 i = MAX_SPRITES - available; i < MAX_SPRITES; i++)
        DestroySprite(&gSprites[i]);
    FieldEffectStart(FLDEFF_DESTROY_DEOXYS_ROCK);
    for (u32 i = 0; i < 122; i++)
        RunTasks();
    EXPECT_EQ(gTasks[0].data[1], 2);
    EXPECT(gObjectEvents[0].invisible);
    for (u32 i = MAX_SPRITES - available; i < MAX_SPRITES; i++)
        EXPECT(gSprites[i].inUse);
    for (u32 frame = 0; frame < 32; frame++)
        for (u32 i = MAX_SPRITES - available; i < MAX_SPRITES; i++)
            if (gSprites[i].inUse)
                gSprites[i].callback(&gSprites[i]);
    for (u32 i = MAX_SPRITES - available; i < MAX_SPRITES; i++)
        EXPECT(!gSprites[i].inUse);
    // Finish the palette fade and let the camera-shake task wind down.
    gPaletteFade.active = FALSE;
    for (u32 frame = 0; frame < 128; frame++)
        RunTasks();
    EXPECT(!FieldEffectActiveListContains(FLDEFF_DESTROY_DEOXYS_ROCK));
    EXPECT(!gTasks[0].isActive);
}

extern u32 FldEff_OWE_SpawnAnim(void);
TEST("Sprite exhaustion recovery: encounter decoration skips a full pool")
{
    FillPool();
    FieldEffectActiveListAdd(FLDEFF_OW_ENCOUNTER_SPAWN_ANIM);
    EXPECT_EQ(FldEff_OWE_SpawnAnim(), MAX_SPRITES);
    EXPECT(!FieldEffectActiveListContains(FLDEFF_OW_ENCOUNTER_SPAWN_ANIM));
    ExpectFullPoolUnchanged();
}

TEST("Sprite exhaustion recovery: surf mount tolerates missing overlay and shadow")
{
    u32 available;
    u32 spriteId;
    PARAMETRIZE { available = 0; }
    PARAMETRIZE { available = 1; }
    PARAMETRIZE { available = 2; }
    PARAMETRIZE { available = 3; }
    FillPool();
    CreateMon(&gParties[B_TRAINER_PLAYER][0], SPECIES_LAPRAS, 30, 0, OTID_STRUCT_PLAYER_ID);
    SetMonMoveSlot(&gParties[B_TRAINER_PLAYER][0], MOVE_SURF, 0);
    ASSUME(GetSurfMountGraphicsId() != OBJ_EVENT_GFX_SPECIES(NONE));
    for (u32 i = MAX_SPRITES - available; i < MAX_SPRITES; i++)
        DestroySprite(&gSprites[i]);
    spriteId = FieldEffectStart(FLDEFF_SURF_BLOB);
    EXPECT_EQ(spriteId == MAX_SPRITES, available == 0);
    if (spriteId != MAX_SPRITES)
    {
        FieldEffectFreeGraphicsResources(&gSprites[spriteId]);
        for (u32 i = MAX_SPRITES - available; i < MAX_SPRITES; i++)
            if (gSprites[i].inUse)
                gSprites[i].callback(&gSprites[i]);
    }
    for (u32 i = 0; i < MAX_SPRITES; i++)
        EXPECT(gSprites[i].inUse == (i < MAX_SPRITES - available));
}

TEST("Sprite exhaustion recovery: dowsing rolls back, retries, and stops")
{
    static const struct MapEvents events = {0};
    static const struct MapLayout layout = {.width = 100, .height = 100};
    u32 gender;
    u32 spriteId;
    PARAMETRIZE { gender = MALE; }
    PARAMETRIZE { gender = FEMALE; }
    FillPool();
    gPlayerAvatar.gender = gender;
    gMapHeader.events = &events;
    gMapHeader.mapLayout = &layout;
    gObjectEvents[0].currentCoords.x = 32;
    gObjectEvents[0].currentCoords.y = 32;
    gObjectEvents[0].movementDirection = DIR_SOUTH;
    EXPECT_EQ(FieldEffectStart(FLDEFF_ORAS_DOWSE), MAX_SPRITES);
    EXPECT(!FlagGet(I_ORAS_DOWSING_FLAG));
    EXPECT(!ItemfinderCheckForHiddenItems(&events, TASK_NONE));
    DestroySprite(&gSprites[MAX_SPRITES - 1]);
    spriteId = FieldEffectStart(FLDEFF_ORAS_DOWSE);
    EXPECT_EQ(spriteId, MAX_SPRITES - 1);
    EXPECT_EQ(FlagGet(I_ORAS_DOWSING_FLAG), I_ORAS_DOWSING_FLAG != 0);
    EXPECT_EQ(gObjectEvents[0].fieldEffectSpriteId, spriteId);
    EndORASDowsing();
    gSprites[spriteId].callback(&gSprites[spriteId]);
    EXPECT(!gSprites[spriteId].inUse);
}
