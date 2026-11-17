#include "global.h"
#include "event_object_lock.h"
#include "event_object_movement.h"
#include "event_scripts.h"
#include "faraway_island.h"
#include "field_camera.h"
#include "field_effect.h"
#include "field_effect_helpers.h"
#include "field_player_avatar.h"
#include "field_specials.h"
#include "fieldmap.h"
#include "fldeff.h"
#include "malloc.h"
#include "metatile_behavior.h"
#include "overworld.h"
#include "party_menu.h"
#include "script.h"
#include "sound.h"
#include "sprite.h"
#include "task.h"
#include "tilesets.h"
#include "trig.h"
#include "constants/abilities.h"
#include "constants/event_objects.h"
#include "constants/field_effects.h"
#include "constants/songs.h"
#include "constants/metatile_labels.h"

extern struct MapPosition gPlayerFacingPosition;

extern const u8 FarawayIsland_Interior_EventScript_HideMewWhenGrassCut[];

extern const u8 gFieldEffectPic_CutGrass[];
extern const u16 gFieldEffectPal_CutGrass[];
extern const u16 gFieldEffectPal_FrostyCutGrass[];

// cut 'square' defines
#define CUT_NORMAL_SIDE 3
#define CUT_NORMAL_AREA CUT_NORMAL_SIDE * CUT_NORMAL_SIDE

#define CUT_HYPER_SIDE 5
#define CUT_HYPER_AREA CUT_HYPER_SIDE * CUT_HYPER_SIDE

#define CUT_SPRITE_ARRAY_COUNT 8

// A metatile id means something only in the tileset that holds it, so each rule is keyed on that
// tileset (the layout's primary for an id below its primary count, else its secondary).
struct CutGrassMetatile
{
    const struct Tileset *tileset;
    u16 grass;
    u16 cut;
};

struct HyperCutterUnk
{
    s8 x;
    s8 y;
    u8 unk2[2];
};

// this file's functions
static void FieldCallback_CutTree(void);
static void FieldCallback_CutGrass(void);
static void StartCutTreeFieldEffect(void);
static void StartCutGrassFieldEffect(void);
static void SetCutGrassMetatile(s16, s16);
static void SetCutGrassMetatiles(s16, s16);
static void CutGrassSpriteCallback1(struct Sprite *);
static void CutGrassSpriteCallback2(struct Sprite *);
static void CutGrassSpriteCallbackEnd(struct Sprite *);
static void HandleLongGrassOnHyper(u8, s16, s16);

// IWRAM variables
static u8 sCutSquareSide;
static u8 sTileCountFromPlayer_X;
static u8 sTileCountFromPlayer_Y;
static bool8 sHyperCutTiles[CUT_HYPER_AREA];

// EWRAM variables
static EWRAM_DATA u8 *sCutGrassSpriteArrayPtr = NULL;
static EWRAM_DATA bool8 sScheduleOpenDottedHole = FALSE;

// const rom data
static const struct HyperCutterUnk sHyperCutStruct[] =
{
    {-2, -2, {1}},
    {-1, -2, {1}},
    {0, -2, {2}},
    {1, -2, {3}},
    {2, -2, {3}},
    {-2, -1, {1}},
    {2, -1, {3}},
    {-2, 0, {4}},
    {2, 0, {6}},
    {-2, 1, {7}},
    {2, 1, {9}},
    {-2, 2, {7}},
    {-1, 2, {7}},
    {0, 2, {8}},
    {1, 2, {9}},
    {2, 2, {9}},
};

static const struct OamData sOamData_CutGrass =
{
    .y = 0,
    .affineMode = ST_OAM_AFFINE_OFF,
    .objMode = ST_OAM_OBJ_NORMAL,
    .mosaic = FALSE,
    .bpp = ST_OAM_4BPP,
    .shape = SPRITE_SHAPE(8x8),
    .x = 0,
    .matrixNum = 0,
    .size = SPRITE_SIZE(8x8),
    .tileNum = 1,
    .priority = 1,
    .paletteNum = 1,
    .affineParam = 0,
};

static const union AnimCmd sSpriteAnim_CutGrass[] =
{
    ANIMCMD_FRAME(0, 30),
    ANIMCMD_JUMP(0),
};

static const union AnimCmd *const sSpriteAnimTable_CutGrass[] =
{
    sSpriteAnim_CutGrass,
};

static const struct SpriteFrameImage sSpriteImageTable_CutGrass[] =
{
    {gFieldEffectPic_CutGrass, 0x20},
};

static const struct SpritePalette sSpritePalette_CutGrass = {gFieldEffectPal_CutGrass, FLDEFF_PAL_TAG_CUT_GRASS};
static const struct SpritePalette sSpritePalette_FrostyCutGrass = {gFieldEffectPal_FrostyCutGrass, FLDEFF_PAL_TAG_FROSTY_CUT_GRASS};

static const struct CutGrassMetatile sCutGrassMetatiles[] =
{
#include "data/field_effects/cut_grass_metatiles.h"
};

static const struct SpriteTemplate sSpriteTemplate_CutGrass =
{
    .tileTag = TAG_NONE,
    .paletteTag = TAG_NONE,
    .oam = &sOamData_CutGrass,
    .anims = sSpriteAnimTable_CutGrass,
    .images = sSpriteImageTable_CutGrass,
    .callback = CutGrassSpriteCallback1,
};

// code
bool32 SetUpFieldMove_Cut(void)
{
    s16 x, y;
    u8 i, j;
    u8 tileBehavior;
    enum Ability userAbility;
    bool8 cutTiles[CUT_NORMAL_AREA];
    bool8 ret;
    sScheduleOpenDottedHole = FALSE;
    if (CutMoveRuinValleyCheck() == TRUE)
    {
        sScheduleOpenDottedHole = TRUE;
        gFieldCallback2 = FieldCallback_PrepareFadeInFromMenu;
        gPostMenuFieldCallback = FieldCallback_CutGrass;
        return TRUE;
    }

    if (CheckObjectGraphicsInFrontOfPlayer(OBJ_EVENT_GFX_CUTTABLE_TREE) == TRUE || CheckObjectGraphicsInFrontOfPlayer(OBJ_EVENT_GFX_CUTTABLE_TREE_FRLG) == TRUE)
    {
        // Standing in front of cuttable tree.
        gFieldCallback2 = FieldCallback_PrepareFadeInFromMenu;
        gPostMenuFieldCallback = FieldCallback_CutTree;
        return TRUE;
    }
    else
    {
        PlayerGetDestCoords(&gPlayerFacingPosition.x, &gPlayerFacingPosition.y);
        userAbility = GetMonAbility(&gParties[B_TRAINER_PLAYER][GetCursorSelectionMonId()]);
        if (userAbility == ABILITY_HYPER_CUTTER)
        {
            sCutSquareSide = CUT_HYPER_SIDE;
            sTileCountFromPlayer_X = 2;
            sTileCountFromPlayer_Y = 2;
        }
        else
        {
            sCutSquareSide = CUT_NORMAL_SIDE;
            sTileCountFromPlayer_X = 1;
            sTileCountFromPlayer_Y = 1;
        }

        for (i = 0; i < CUT_NORMAL_AREA; i++)
            cutTiles[i] = FALSE;
        for (i = 0; i < CUT_HYPER_AREA; i++)
            sHyperCutTiles[i] = FALSE;

        ret = FALSE;

        for (i = 0; i < CUT_NORMAL_SIDE; i++)
        {
            y = i - 1 + gPlayerFacingPosition.y;
            for (j = 0; j < CUT_NORMAL_SIDE; j++)
            {
                x = j - 1 + gPlayerFacingPosition.x;
                if (MapGridGetElevationAt(x, y) == gPlayerFacingPosition.elevation)
                {
                    tileBehavior = MapGridGetMetatileBehaviorAt(x, y);
                    if (MetatileBehavior_IsPokeGrass(tileBehavior) == TRUE
                    || MetatileBehavior_IsAshGrass(tileBehavior) == TRUE)
                    {
                        // Standing in front of grass.
                        sHyperCutTiles[6 + (i * 5) + j] = TRUE;
                        ret = TRUE;
                    }
                #ifdef BUGFIX
                    // Collision has a range 0-3, any value != 0 is impassable
                    if (MapGridGetCollisionAt(x, y))
                #else
                    if (MapGridGetCollisionAt(x, y) == 1)
                #endif
                    {
                        cutTiles[i * 3 + j] = FALSE;
                    }
                    else
                    {
                        cutTiles[i * 3 + j] = TRUE;
                        if (MetatileBehavior_IsCuttableGrass(tileBehavior) == TRUE)
                            sHyperCutTiles[6 + (i * 5) + j] = TRUE;
                    }
                }
                else
                {
                    cutTiles[i * 3 + j] = FALSE;
                }
            }
        }

        if (userAbility != ABILITY_HYPER_CUTTER)
        {
            if (ret == TRUE)
            {
                gFieldCallback2 = FieldCallback_PrepareFadeInFromMenu;
                gPostMenuFieldCallback = FieldCallback_CutGrass;
            }
        }
        else
        {
            bool8 tileCuttable;
            for (i = 0; i < 16; i++)
            {
                x = gPlayerFacingPosition.x + sHyperCutStruct[i].x;
                y = gPlayerFacingPosition.y + sHyperCutStruct[i].y;
                tileCuttable = TRUE;

                for (j = 0; j < 2; ++j)
                {
                    if (sHyperCutStruct[i].unk2[j] == 0) break; // one line required to match -g
                    if (cutTiles[(u8)(sHyperCutStruct[i].unk2[j] - 1)] == FALSE)
                    {
                        tileCuttable = FALSE;
                        break;
                    }
                }

                if (tileCuttable == TRUE)
                {
                    if (MapGridGetElevationAt(x, y) == gPlayerFacingPosition.elevation)
                    {
                        u8 tileArrayId = ((sHyperCutStruct[i].y * 5) + 12) + (sHyperCutStruct[i].x);
                        tileBehavior = MapGridGetMetatileBehaviorAt(x, y);
                        if (MetatileBehavior_IsPokeGrass(tileBehavior) == TRUE
                        || MetatileBehavior_IsAshGrass(tileBehavior) == TRUE)
                        {
                            gFieldCallback2 = FieldCallback_PrepareFadeInFromMenu;
                            gPostMenuFieldCallback = FieldCallback_CutGrass;
                            sHyperCutTiles[tileArrayId] = TRUE;
                            ret = TRUE;
                        }
                        else
                        {
                            if (MetatileBehavior_IsCuttableGrass(tileBehavior) == TRUE)
                                sHyperCutTiles[tileArrayId] = TRUE;
                        }
                    }
                }
            }

            if (ret == TRUE)
            {
                gFieldCallback2 = FieldCallback_PrepareFadeInFromMenu;
                gPostMenuFieldCallback = FieldCallback_CutGrass;
            }
        }

        return ret;
    }
}

static void FieldCallback_CutGrass(void)
{
    gFieldEffectArguments[0] = GetCursorSelectionMonId();
    ScriptContext_SetupScript(EventScript_UseCutGrass);
}

bool8 FldEff_UseCutOnGrass(void)
{
    u8 taskId = CreateFieldMoveTask();

    gTasks[taskId].data[8] = (u32)StartCutGrassFieldEffect >> 16;
    gTasks[taskId].data[9] = (u32)StartCutGrassFieldEffect;
    IncrementGameStat(GAME_STAT_USED_CUT);
    return FALSE;
}

static void FieldCallback_CutTree(void)
{
    gFieldEffectArguments[0] = GetCursorSelectionMonId();
    ScriptContext_SetupScript(EventScript_UseCut);
}

bool8 FldEff_UseCutOnTree(void)
{
    u8 taskId = CreateFieldMoveTask();

    gTasks[taskId].data[8] = (u32)StartCutTreeFieldEffect >> 16;
    gTasks[taskId].data[9] = (u32)StartCutTreeFieldEffect;
    IncrementGameStat(GAME_STAT_USED_CUT);
    return FALSE;
}

static void StartCutGrassFieldEffect(void)
{
    FieldEffectActiveListRemove(FLDEFF_USE_CUT_ON_GRASS);
    if (sScheduleOpenDottedHole == TRUE)
        CutMoveOpenDottedHoleDoor();
    else
        FieldEffectStart(FLDEFF_CUT_GRASS);
}

bool8 FldEff_CutGrass(void)
{
    s16 x, y;
    u8 i = 0;
    const struct SpritePalette *palette = &sSpritePalette_CutGrass;
    u32 paletteNum;

    PlaySE(SE_M_CUT);
    PlayerGetDestCoords(&gPlayerFacingPosition.x, &gPlayerFacingPosition.y);
    for (i = 0; i < CUT_HYPER_AREA; i++)
    {
        if (sHyperCutTiles[i] == TRUE)
        {
            s8 xAdd = (i % 5) - 2;
            s8 yAdd = (i / 5) - 2;

            x = xAdd + gPlayerFacingPosition.x;
            y = yAdd + gPlayerFacingPosition.y;

            if (IsFrostyGrassAt(x, y))
                palette = &sSpritePalette_FrostyCutGrass;
            SetCutGrassMetatile(x, y);
            AllowObjectAtPosTriggerGroundEffects(x, y);
        }
    }

    SetCutGrassMetatiles(gPlayerFacingPosition.x - sTileCountFromPlayer_X, gPlayerFacingPosition.y - (1 + sTileCountFromPlayer_Y));
    DrawWholeMapView();
    sCutGrassSpriteArrayPtr = AllocZeroed(CUT_SPRITE_ARRAY_COUNT);
    FieldEffect_LoadFadedPalette(palette, COLOR_MAP_DARK_CONTRAST);
    paletteNum = IndexOfSpritePaletteTag(palette->tag);

    // populate sprite ID array
    for (i = 0; i < CUT_SPRITE_ARRAY_COUNT; i++)
    {
        sCutGrassSpriteArrayPtr[i] = CreateSprite(&sSpriteTemplate_CutGrass,
        gSprites[gPlayerAvatar.spriteId].oam.x + 8, gSprites[gPlayerAvatar.spriteId].oam.y + 20, 0);
        gSprites[sCutGrassSpriteArrayPtr[i]].oam.paletteNum = paletteNum;
        gSprites[sCutGrassSpriteArrayPtr[i]].data[2] = 32 * i;
    }

    return FALSE;
}

static const struct Tileset *GetMetatileTileset(u32 metatileId)
{
    const struct MapLayout *layout = gMapHeader.mapLayout;
    return metatileId < GetNumMetatilesInPrimary(layout) ? layout->primaryTileset : layout->secondaryTileset;
}

static void SetCutGrassMetatile(s16 x, s16 y)
{
    u32 i;
    u32 metatileId = MapGridGetMetatileIdAt(x, y);
    const struct Tileset *tileset = GetMetatileTileset(metatileId);

    for (i = 0; i < ARRAY_COUNT(sCutGrassMetatiles); i++)
    {
        if (sCutGrassMetatiles[i].grass == metatileId && sCutGrassMetatiles[i].tileset == tileset)
        {
            MapGridSetMetatileIdAt(x, y, sCutGrassMetatiles[i].cut);
            return;
        }
    }
}

// The grass that the stubble at (x, y) was cut from, or 0 when it is not stubble.
static u32 GetGrassCutAt(s16 x, s16 y)
{
    u32 i;
    u32 metatileId = MapGridGetMetatileIdAt(x, y);
    const struct Tileset *tileset = GetMetatileTileset(metatileId);

    for (i = 0; i < ARRAY_COUNT(sCutGrassMetatiles); i++)
    {
        if (sCutGrassMetatiles[i].cut == metatileId && sCutGrassMetatiles[i].tileset == tileset)
            return sCutGrassMetatiles[i].grass;
    }
    return 0;
}

enum
{
    LONG_GRASS_NONE,
    LONG_GRASS_FIELD,
    LONG_GRASS_BASE_LEFT,
    LONG_GRASS_BASE_CENTER,
    LONG_GRASS_BASE_RIGHT
};

static u8 GetLongGrassCaseAt(s16 x, s16 y)
{
    switch (GetGrassCutAt(x, y))
    {
    case METATILE_General_LongGrass:
    case METATILE_Fortree_LongGrass_Root:
        return LONG_GRASS_FIELD;
    case METATILE_Fortree_SecretBase_LongGrass_BottomLeft:
        return LONG_GRASS_BASE_LEFT;
    case METATILE_Fortree_SecretBase_LongGrass_BottomMid:
        return LONG_GRASS_BASE_CENTER;
    case METATILE_Fortree_SecretBase_LongGrass_BottomRight:
        return LONG_GRASS_BASE_RIGHT;
    default:
        return LONG_GRASS_NONE;
    }
}

// Long grass left standing above freshly cut stubble needs its roots drawn over that stubble again.
static void SetLongGrassRootAt(s16 x, s16 y)
{
    switch (GetLongGrassCaseAt(x, y))
    {
    case LONG_GRASS_FIELD:
        MapGridSetMetatileIdAt(x, y, METATILE_Fortree_LongGrass_Root);
        break;
    case LONG_GRASS_BASE_LEFT:
        MapGridSetMetatileIdAt(x, y, METATILE_Fortree_SecretBase_LongGrass_BottomLeft);
        break;
    case LONG_GRASS_BASE_CENTER:
        MapGridSetMetatileIdAt(x, y, METATILE_Fortree_SecretBase_LongGrass_BottomMid);
        break;
    case LONG_GRASS_BASE_RIGHT:
        MapGridSetMetatileIdAt(x, y, METATILE_Fortree_SecretBase_LongGrass_BottomRight);
        break;
    }
}

// Roots below long grass that was just cut lose the grass above them, so they are cut too.
static void CutLongGrassRootAt(s16 x, s16 y)
{
    if (MetatileBehavior_IsLongGrassSouthEdge(MapGridGetMetatileBehaviorAt(x, y)))
        SetCutGrassMetatile(x, y);
}

// Rebuilds the roots under Fortree's long grass around the cut square. Its metatile ids are
// Fortree's, so on any other tileset they name unrelated tiles.
static void SetCutGrassMetatiles(s16 x, s16 y)
{
    s16 i;
    s16 lowerY = y + sCutSquareSide;

    if (gMapHeader.mapLayout->secondaryTileset != &gTileset_Fortree)
        return;

    for (i = 0; i < sCutSquareSide; i++)
    {
        s16 currentX = x + i;
        if (MapGridGetMetatileIdAt(currentX, y) == METATILE_General_LongGrass)
            SetLongGrassRootAt(currentX, y + 1);
        if (GetLongGrassCaseAt(currentX, lowerY) == LONG_GRASS_FIELD)
            CutLongGrassRootAt(currentX, lowerY + 1);
    }

    if (sCutSquareSide == CUT_HYPER_SIDE)
    {
        HandleLongGrassOnHyper(0, x, y);
        HandleLongGrassOnHyper(1, x, y);
    }
}

static void HandleLongGrassOnHyper(u8 caseId, s16 x, s16 y)
{
    s16 newX;
    bool8 arr[3];

    if (caseId == 0)
    {
        arr[0] = sHyperCutTiles[5];
        arr[1] = sHyperCutTiles[10];
        arr[2] = sHyperCutTiles[15];
        newX = x;
    }
    else if (caseId == 1)
    {
        arr[0] = sHyperCutTiles[9];
        arr[1] = sHyperCutTiles[14];
        arr[2] = sHyperCutTiles[19];
        newX = x + 4;
    }
    else // invalid case
    {
        return;
    }

    if (arr[0] == TRUE)
        CutLongGrassRootAt(newX, y + 3);
    if (arr[1] == TRUE)
    {
        if (MapGridGetMetatileIdAt(newX, y + 2) == METATILE_General_LongGrass)
            SetLongGrassRootAt(newX, y + 3);
        CutLongGrassRootAt(newX, y + 4);
    }
    if (arr[2] == TRUE)
    {
        if (MapGridGetMetatileIdAt(newX, y + 3) == METATILE_General_LongGrass)
            SetLongGrassRootAt(newX, y + 4);
    }
}

static void CutGrassSpriteCallback1(struct Sprite *sprite)
{
    sprite->data[0] = 8;
    sprite->data[1] = 0;
    sprite->data[3] = 0;
    sprite->callback = CutGrassSpriteCallback2;
}

static void CutGrassSpriteCallback2(struct Sprite *sprite)
{
    sprite->x2 = Sin(sprite->data[2], sprite->data[0]);
    sprite->y2 = Cos(sprite->data[2], sprite->data[0]);

    sprite->data[2] = (sprite->data[2] + 8) & 0xFF;
    sprite->data[0] += 1 + (sprite->data[3] >> 2); // right shift by 2 is dividing by 4
    sprite->data[3]++;

    if (sprite->data[1] != 28)
        sprite->data[1]++;
    else
        sprite->callback = CutGrassSpriteCallbackEnd; // done rotating the grass, execute clean up function
}

static void CutGrassSpriteCallbackEnd(struct Sprite *sprite)
{
    u8 i;

    for (i = 1; i < CUT_SPRITE_ARRAY_COUNT; i++)
        DestroySprite(&gSprites[sCutGrassSpriteArrayPtr[i]]);

    FieldEffectStop(&gSprites[sCutGrassSpriteArrayPtr[0]], FLDEFF_CUT_GRASS);
    FREE_AND_SET_NULL(sCutGrassSpriteArrayPtr);
    ScriptUnfreezeObjectEvents();
    UnlockPlayerFieldControls();

    if (IsMewPlayingHideAndSeek() == TRUE)
        ScriptContext_SetupScript(FarawayIsland_Interior_EventScript_HideMewWhenGrassCut);
}

void FixLongGrassMetatilesWindowTop(s16 x, s16 y)
{
    u8 metatileBehavior = MapGridGetMetatileBehaviorAt(x, y);
    if (MetatileBehavior_IsLongGrass_Duplicate(metatileBehavior))
    {
        switch (GetLongGrassCaseAt(x, y + 1))
        {
        case LONG_GRASS_FIELD:
            MapGridSetMetatileIdAt(x, y + 1, METATILE_Fortree_LongGrass_Root);
            break;
        case LONG_GRASS_BASE_LEFT:
            MapGridSetMetatileIdAt(x, y + 1, METATILE_Fortree_SecretBase_LongGrass_BottomLeft);
            break;
        case LONG_GRASS_BASE_CENTER:
            MapGridSetMetatileIdAt(x, y + 1, METATILE_Fortree_SecretBase_LongGrass_BottomMid);
            break;
        case LONG_GRASS_BASE_RIGHT:
            MapGridSetMetatileIdAt(x, y + 1, METATILE_Fortree_SecretBase_LongGrass_BottomRight);
            break;
        }
    }
}

void FixLongGrassMetatilesWindowBottom(s16 x, s16 y)
{
    if (MapGridGetMetatileIdAt(x, y) == METATILE_General_Grass)
    {
        u8 metatileBehavior = MapGridGetMetatileBehaviorAt(x, y + 1);
        if (MetatileBehavior_IsLongGrassSouthEdge(metatileBehavior))
        {
            s32 metatileId = MapGridGetMetatileIdAt(x, y + 1);
            switch (metatileId)
            {
            case METATILE_Fortree_LongGrass_Root:
                MapGridSetMetatileIdAt(x, y + 1, METATILE_General_Grass);
                break;
            case METATILE_Fortree_SecretBase_LongGrass_BottomLeft:
                MapGridSetMetatileIdAt(x, y + 1, METATILE_Fortree_SecretBase_LongGrass_TopLeft);
                break;
            case METATILE_Fortree_SecretBase_LongGrass_BottomMid:
                MapGridSetMetatileIdAt(x, y + 1, METATILE_Fortree_SecretBase_LongGrass_TopMid);
                break;
            case METATILE_Fortree_SecretBase_LongGrass_BottomRight:
                MapGridSetMetatileIdAt(x, y + 1, METATILE_Fortree_SecretBase_LongGrass_TopRight);
                break;
            }
        }
    }
}

static void StartCutTreeFieldEffect(void)
{
    PlaySE(SE_M_CUT);
    FieldEffectActiveListRemove(FLDEFF_USE_CUT_ON_TREE);
    ScriptContext_Enable();
}
