#include "global.h"
#include "ambient_ripples.h"
#include "event_object_movement.h"
#include "field_camera.h"
#include "field_effect.h"
#include "field_weather.h"
#include "fieldmap.h"
#include "main.h"
#include "overworld.h"
#include "palette.h"
#include "random.h"
#include "script.h"
#include "sprite.h"
#include "test/test.h"
#include "constants/field_effects.h"
#include "constants/layouts.h"
#include "constants/maps.h"
#include "constants/metatile_behaviors.h"
#include "constants/species.h"
#include "constants/weather.h"

extern const struct MapLayout *const gMapLayouts[];
extern bool32 Test_OWECanLoadGraphics(enum Species species, s32 x, s32 y);
static EWRAM_DATA u16 sPondGrid[32 * 32] = {0};

struct RippleFixture
{
    struct MapHeader header;
    struct BackupMapLayout backup;
    struct WarpData location;
    struct Coords16 pos;
    MainCallback callback;
};

static struct RippleFixture SetUpPond(u32 map, u32 layout, u32 weather, u32 behavior)
{
    struct RippleFixture saved = {gMapHeader, gBackupMapLayout,
        gSaveBlock1Ptr->location, gSaveBlock1Ptr->pos, gMain.callback2};
    u32 tile;
    ResetSpriteData();
    FreeAllSpritePalettes();
    FieldEffectActiveListClear();
    memset(gObjectEvents, 0, sizeof(gObjectEvents));
    memset(gWeatherPtr, 0, sizeof(*gWeatherPtr));
    memset(&gFieldCamera, 0, sizeof(gFieldCamera));
    gTotalCameraPixelOffsetX = gTotalCameraPixelOffsetY = 0;
    gSpriteCoordOffsetX = gSpriteCoordOffsetY = 0;
    gMapHeader.mapLayout = gMapLayouts[layout - 1];
    gSaveBlock1Ptr->location.mapGroup = MAP_GROUP(map);
    gSaveBlock1Ptr->location.mapNum = MAP_NUM(map);
    gSaveBlock1Ptr->pos = (struct Coords16){0, 0};
    gWeatherPtr->currWeather = weather;
    gMain.callback2 = CB2_Overworld;
    gPaletteFade.active = FALSE;
    UnlockPlayerFieldControls();
    for (tile = 0; tile < NUM_METATILES_TOTAL; tile++)
        if (GetAttributeByMetatileIdAndMapLayout(tile, METATILE_ATTRIBUTE_BEHAVIOR) == behavior)
            break;
    EXPECT_LT(tile, NUM_METATILES_TOTAL);
    for (u32 i = 0; i < ARRAY_COUNT(sPondGrid); i++)
        sPondGrid[i] = tile;
    gBackupMapLayout = (struct BackupMapLayout){.width = 32, .height = 32, .map = sPondGrid};
    ResetAmbientRipples();
    return saved;
}

static void TearDownPond(struct RippleFixture *saved)
{
    ReclaimAmbientRipples();
    ResetSpriteData();
    FreeAllSpritePalettes();
    FieldEffectActiveListClear();
    UnlockPlayerFieldControls();
    gPaletteFade.active = FALSE;
    gMapHeader = saved->header;
    gBackupMapLayout = saved->backup;
    gSaveBlock1Ptr->location = saved->location;
    gSaveBlock1Ptr->pos = saved->pos;
    gMain.callback2 = saved->callback;
}

static u32 RingCount(void)
{
    u32 count = 0;
    for (u32 i = 0; i < MAX_SPRITES; i++)
        if (gSprites[i].inUse && gSprites[i].template->paletteTag == FLDEFF_PAL_TAG_AMBIENT_RIPPLE)
            count++;
    return count;
}

static void FillRings(void)
{
    for (u32 i = 0; i < 180; i++)
        UpdateAmbientRipples();
    EXPECT_EQ(RingCount(), 3);
}

TEST("Ambient ripples: eligible maps cap rings and preserve both RNG streams")
{
    u32 map, layout, weather, behavior, cap;
    PARAMETRIZE { map = MAP_PETALBURG_CITY; layout = LAYOUT_PETALBURG_CITY; weather = WEATHER_SUNNY; behavior = MB_POND_WATER; cap = 3; }
    PARAMETRIZE { map = MAP_VIOLET_CITY; layout = LAYOUT_VIOLET_CITY; weather = WEATHER_SHADE; behavior = MB_POND_WATER; cap = 3; }
    PARAMETRIZE { map = MAP_FUCHSIA_CITY; layout = LAYOUT_FUCHSIA_CITY; weather = WEATHER_RAIN; behavior = MB_POND_WATER; cap = 5; }
    PARAMETRIZE { map = MAP_ROUTE119; layout = LAYOUT_ROUTE119; weather = WEATHER_DOWNPOUR; behavior = MB_PUDDLE; cap = 5; }
    struct RippleFixture saved = SetUpPond(map, layout, weather, behavior);
    rng_value_t rng = gRngValue, rng2 = gRng2Value;
    u32 peak = 0;
    for (u32 i = 0; i < 600; i++)
    {
        UpdateAmbientRipples();
        u32 count = RingCount();
        if (count > peak)
            peak = count;
        EXPECT_LE(count, cap);
        if (i < (cap == 5 ? 14 : 29))
            EXPECT_EQ(count, 0);
        AnimateSprites();
        BuildOamBuffer();
        ProcessSpriteCopyRequests();
    }
    EXPECT_EQ(peak, cap);
    EXPECT_EQ(memcmp(&rng, &gRngValue, sizeof(rng)), 0);
    EXPECT_EQ(memcmp(&rng2, &gRng2Value, sizeof(rng2)), 0);
    EXPECT(!FieldEffectActiveListContains(FLDEFF_RIPPLE));
    TearDownPond(&saved);
}

TEST("Ambient ripples: unsupported weather, maps, surfaces and locked controls skip")
{
    u32 weather, map, behavior;
    PARAMETRIZE { weather = WEATHER_SNOW; map = MAP_PETALBURG_CITY; behavior = MB_POND_WATER; }
    PARAMETRIZE { weather = WEATHER_FOG_HORIZONTAL; map = MAP_PETALBURG_CITY; behavior = MB_POND_WATER; }
    PARAMETRIZE { weather = WEATHER_SANDSTORM; map = MAP_PETALBURG_CITY; behavior = MB_POND_WATER; }
    PARAMETRIZE { weather = WEATHER_SUNNY; map = MAP_LITTLEROOT_TOWN; behavior = MB_POND_WATER; }
    PARAMETRIZE { weather = WEATHER_SUNNY; map = MAP_ROUTE119; behavior = MB_POND_WATER; }
    PARAMETRIZE { weather = WEATHER_SUNNY; map = MAP_PETALBURG_CITY; behavior = MB_NORMAL; }
    struct RippleFixture saved = SetUpPond(map, LAYOUT_PETALBURG_CITY, weather, behavior);
    for (u32 i = 0; i < 600; i++)
        UpdateAmbientRipples();
    EXPECT_EQ(RingCount(), 0);
    EXPECT_EQ(CountFreePaletteSlots(), 16);
    gSaveBlock1Ptr->location.mapGroup = MAP_GROUP(MAP_PETALBURG_CITY);
    gSaveBlock1Ptr->location.mapNum = MAP_NUM(MAP_PETALBURG_CITY);
    gWeatherPtr->currWeather = WEATHER_SUNNY;
    LockPlayerFieldControls();
    for (u32 i = 0; i < 90; i++)
        UpdateAmbientRipples();
    EXPECT_EQ(RingCount(), 0);
    UnlockPlayerFieldControls();
    gPaletteFade.active = TRUE;
    for (u32 i = 0; i < 90; i++)
        UpdateAmbientRipples();
    EXPECT_EQ(RingCount(), 0);
    TearDownPond(&saved);
}

TEST("Ambient ripples: reclaim preserves gameplay ripples and cached sheet zero")
{
    static const u32 tiles[32] = {0};
    static const struct SpriteSheet sheet = {tiles, sizeof(tiles), 0x7000};
    struct RippleFixture saved = SetUpPond(MAP_PETALBURG_CITY, LAYOUT_PETALBURG_CITY, WEATHER_SUNNY, MB_POND_WATER);
    EXPECT_EQ(LoadSpriteSheet(&sheet), 0);
    memset(gFieldEffectArguments, 0, sizeof(gFieldEffectArguments));
    FieldEffectStart(FLDEFF_RIPPLE);
    u32 playerId = MAX_SPRITES - 1;
    struct Sprite player = gSprites[playerId];
    EXPECT(player.inUse);
    FillRings();
    EXPECT(ReclaimAmbientRipples());
    EXPECT_EQ(RingCount(), 0);
    EXPECT_EQ(memcmp(&player, &gSprites[playerId], sizeof(player)), 0);
    EXPECT(FieldEffectActiveListContains(FLDEFF_RIPPLE));
    EXPECT_EQ(GetSpriteTileStartByTag(sheet.tag), 0);
    EXPECT_NE(IndexOfSpritePaletteTag(FLDEFF_PAL_TAG_GENERAL_1), 0xFF);
    EXPECT_EQ(IndexOfSpritePaletteTag(FLDEFF_PAL_TAG_AMBIENT_RIPPLE), 0xFF);
    EXPECT(!ReclaimAmbientRipples());
    TearDownPond(&saved);
}

TEST("Ambient ripples: same-frame sprite pressure reclaims before failing")
{
    u32 fromEnd;
    PARAMETRIZE { fromEnd = FALSE; }
    PARAMETRIZE { fromEnd = TRUE; }
    struct RippleFixture saved = SetUpPond(MAP_PETALBURG_CITY, LAYOUT_PETALBURG_CITY, WEATHER_SUNNY, MB_POND_WATER);
    FillRings();
    for (u32 i = 0; i < MAX_SPRITES; i++)
        if (!gSprites[i].inUse)
            EXPECT_EQ(CreateSpriteUnchecked(&gDummySpriteTemplate, 0, 0, 0), i);
    EXPECT_EQ(RingCount(), 3);
    u32 id = fromEnd ? CreateSpriteAtEndUnchecked(&gDummySpriteTemplate, 0, 0, 0)
                     : CreateSpriteUnchecked(&gDummySpriteTemplate, 0, 0, 0);
    EXPECT_LT(id, MAX_SPRITES);
    EXPECT_EQ(RingCount(), 0);
    EXPECT_EQ(gSprites[id].callback, SpriteCallbackDummy);
    TearDownPond(&saved);
}

TEST("Ambient ripples: same-frame tile pressure reclaims exact owned tiles")
{
    u32 fragmented;
    PARAMETRIZE { fragmented = FALSE; }
    PARAMETRIZE { fragmented = TRUE; }
    struct RippleFixture saved = SetUpPond(MAP_PETALBURG_CITY, LAYOUT_PETALBURG_CITY, WEATHER_SUNNY, MB_POND_WATER);
    FillRings();
    for (u32 i = 0; i < 1024; i++)
        if (!fragmented || i < 12 || (i & 1))
            SpriteTileAllocBitmapOp(i, 1);
    EXPECT(!CanAllocSpriteTiles(8));
    EXPECT_EQ(AllocSpriteTiles(8), 0);
    EXPECT_EQ(RingCount(), 0);
    for (u32 i = 12; i < 1024; i++)
        EXPECT_EQ(SpriteTileAllocBitmapOp(i, 2) != 0, !fragmented || (i & 1));
    EXPECT_EQ(AllocSpriteTiles(16), -1); // exhausted/fragmented after bounded reclamation
    TearDownPond(&saved);
}

TEST("Ambient ripples: same-frame palette demand reclaims before OWE eviction")
{
    static const u16 colors[16] = {0};
    static const struct SpritePalette requested = {colors, 0x7100};
    struct RippleFixture saved = SetUpPond(MAP_PETALBURG_CITY, LAYOUT_PETALBURG_CITY, WEATHER_SUNNY, MB_POND_WATER);
    FillRings();
    for (u32 i = 0; CountFreePaletteSlots(); i++)
        EXPECT_NE(AllocSpritePalette(0x7200 + i), 0xFF);
    EXPECT_EQ(RingCount(), 3);
    EXPECT_LT(LoadSpritePalette(&requested), 16);
    EXPECT_EQ(RingCount(), 0);
    EXPECT_NE(IndexOfSpritePaletteTag(requested.tag), 0xFF);
    TearDownPond(&saved);
}

TEST("Ambient ripples: late reclamation cancels stale copies and OAM before tile reuse")
{
    static const u32 replacement[32] = {[0 ... 31] = 0xAAAAAAAA};
    static const struct SpriteSheet sheet = {replacement, sizeof(replacement), 0x7400};
    static const u32 unrelated[8] = {[0 ... 7] = 0x55555555};
    struct RippleFixture saved = SetUpPond(MAP_PETALBURG_CITY, LAYOUT_PETALBURG_CITY, WEATHER_SUNNY, MB_POND_WATER);
    FillRings();
    AnimateSprites(); // queues each ring's first frame
    BuildOamBuffer(); // the late OWE update runs after this in CB2_Overworld
    for (u32 i = 0; i < 128; i++)
        gMain.oamBuffer[i].affineParam = 0x1234 + i;
    RequestSpriteCopy((const u8 *)unrelated, (u8 *)OBJ_VRAM0 + 12 * TILE_SIZE_4BPP, sizeof(unrelated));
    for (u32 i = 0; i < 1024; i++)
        SpriteTileAllocBitmapOp(i, 1);
    EXPECT_EQ(LoadSpriteSheet(&sheet), 0); // reclaims and synchronously reuses ring tiles
    EXPECT_EQ(RingCount(), 0);
    ProcessSpriteCopyRequests(); // VBlank must not overwrite the new sheet
    EXPECT_EQ(memcmp((void *)OBJ_VRAM0, replacement, sizeof(replacement)), 0);
    EXPECT_EQ(memcmp((u8 *)OBJ_VRAM0 + 12 * TILE_SIZE_4BPP, unrelated, sizeof(unrelated)), 0);
    for (u32 i = 0; i < 128; i++)
    {
        EXPECT_EQ(gMain.oamBuffer[i].affineParam, 0x1234 + i);
        if (gMain.oamBuffer[i].tileNum < 12)
            EXPECT_EQ((u32)gMain.oamBuffer[i].y, DISPLAY_HEIGHT);
    }
    TearDownPond(&saved);
}

TEST("Ambient ripples: OWE admission retries the selected species without RNG")
{
    struct RippleFixture saved = SetUpPond(MAP_PETALBURG_CITY, LAYOUT_PETALBURG_CITY, WEATHER_SUNNY, MB_POND_WATER);
    FillRings();
    for (u32 i = 0; CountFreePaletteSlots() > 1; i++)
        EXPECT_NE(AllocSpritePalette(0x7300 + i), 0xFF);
    rng_value_t rng = gRngValue, rng2 = gRng2Value;
    EXPECT(Test_OWECanLoadGraphics(SPECIES_PSYDUCK, 5, 5));
    EXPECT_EQ(RingCount(), 0);
    EXPECT_EQ(CountFreePaletteSlots(), 2);
    EXPECT_EQ(memcmp(&rng, &gRngValue, sizeof(rng)), 0);
    EXPECT_EQ(memcmp(&rng2, &gRng2Value, sizeof(rng2)), 0);
    EXPECT(Test_OWECanLoadGraphics(SPECIES_PSYDUCK, 5, 5));
    TearDownPond(&saved);
}

TEST("Ambient ripples: reset, reused slots and fifty lifecycle cycles retain ownership")
{
    struct RippleFixture saved = SetUpPond(MAP_PETALBURG_CITY, LAYOUT_PETALBURG_CITY, WEATHER_SUNNY, MB_POND_WATER);
    for (u32 cycle = 0; cycle < 50; cycle++)
    {
        FillRings();
        ResetAmbientRipples();
        EXPECT_EQ(RingCount(), 0);
        EXPECT_EQ(CountFreePaletteSlots(), 16);
        EXPECT(CanAllocSpriteTiles(1024));
    }
    FillRings();
    ResetSpriteData();
    FreeAllSpritePalettes();
    u32 id = CreateSpriteAtEndUnchecked(&gDummySpriteTemplate, 40, 40, 0);
    struct Sprite reused = gSprites[id];
    ResetAmbientRipples();
    EXPECT_EQ(memcmp(&reused, &gSprites[id], sizeof(reused)), 0);
    EXPECT_EQ(CountFreePaletteSlots(), 16);
    TearDownPond(&saved);
}
