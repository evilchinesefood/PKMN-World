// Disposable evidence fixture. Linked only into verified-unused ROM padding by
// test/overworld/visual-features/build_fixture.py; never part of the production build.
#include "global.h"
#include "battle_setup.h"
#include "constants/opponents.h"
#include "main.h"
#include "event_data.h"
#include "event_object_movement.h"
#include "field_screen_effect.h"
#include "overworld.h"
#include "palette.h"
#include "palette_swap.h"
#include "pokemon.h"
#include "save.h"
#include "sprite.h"
#include "constants/event_objects.h"
#include "constants/event_object_movement.h"
#include "constants/flags.h"
#include "constants/maps.h"
#include "constants/species.h"
#include "constants/vars.h"

extern const u16 gObjectEventPal_Npc1[], gObjectEventPal_Npc3[];
extern const u16 gObjectEventPal_NpcPink[], gObjectEventPal_NpcWhite[];

static void Warp(u16 map, s8 x, s8 y)
{
    SetWarpDestination(MAP_GROUP(map), MAP_NUM(map), WARP_ID_NONE, x, y);
    DoWarp();
}

static struct ObjectEvent *Actor(u8 localId)
{
    for (u32 i = 0; i < OBJECT_EVENTS_COUNT; i++)
        if (gObjectEvents[i].active && gObjectEvents[i].localId == localId)
            return &gObjectEvents[i];
    return NULL;
}

void VisualFeatureFixture(void)
{
    u32 command = gSpecialVar_0x8004;
    u32 arg = gSpecialVar_0x8005;
    SetMainCallback2(CB2_Overworld);
    if (command == 0)
    {
        static const u16 species[] = {SPECIES_PICHU, SPECIES_SNORLAX, SPECIES_SNORLAX};
        u32 shiny = arg == 2;
        if (arg >= ARRAY_COUNT(species))
            return;
        RemoveFollowingPokemon();
        CreateMonWithIVs(&gParties[B_TRAINER_PLAYER][0], species[arg], 40, 0x12345678, OTID_STRUCT_PLAYER_ID, 31);
        SetMonData(&gParties[B_TRAINER_PLAYER][0], MON_DATA_IS_SHINY, &shiny);
        gPartiesCount[B_TRAINER_PLAYER] = 1;
        FlagSet(FLAG_SYS_POKEMON_GET);
        FlagSet(FLAG_HUB_INTRO_TOUR_DONE);
        FlagClear(FLAG_TEMP_HIDE_FOLLOWER);
        VarSet(VAR_REPEL_STEP_COUNT, 250);
        UpdateFollowingPokemon();
    }
    else if (command == 1)
    {
        static const s8 coords[][2] = {{16,4}, {4,13}, {20,6}, {13,12}, {4,6}};
        if (arg < ARRAY_COUNT(coords))
            Warp(arg == 4 ? MAP_REGION_HUB_2F : MAP_REGION_HUB, coords[arg][0], coords[arg][1]);
    }
    else if (command == 2 && arg < 12)
    {
        gSaveBlock2Ptr->playerGender = arg / NUM_PLAYER_OUTFITS;
        VarSet(VAR_PLAYER_PALETTE, arg % NUM_PLAYER_OUTFITS);
        Warp(MAP_REGION_HUB, 20, 6);
    }
    else if (command == 3)
    {
        SetTimeOfDay(arg);
        UpdateTimeOfDay(TRUE);
    }
    else if (command == 4 || command == 8 || command == 9)
    {
        struct ObjectEvent *obj = Actor(arg & 0xFF);
        if (obj == NULL)
            return;
        ObjectEventClearHeldMovementIfActive(obj);
        if (command == 4)
            ObjectEventForceSetHeldMovement(obj, GetFaceDirectionMovementAction(arg >> 8));
        else if (command == 8)
            ObjectEventForceSetHeldMovement(obj, GetWalkNormalMovementAction(arg >> 8));
        else
            ObjectEventForceSetHeldMovement(obj, MOVEMENT_ACTION_JUMP_IN_PLACE_DOWN);
    }
    else if (command == 5)
    {
        struct ObjectEvent *obj = Actor(arg);
        gSpecialVar_0x8005 = 0;
        if (obj != NULL)
        {
            const struct ObjectEventGraphicsInfo *gfx = GetObjectEventGraphicsInfo(obj->graphicsId);
            const struct Sprite *sprite = &gSprites[obj->spriteId];
            const u16 *expected = NULL;
            bool32 colors = TRUE;
            switch (gfx->paletteTag)
            {
            case OBJ_EVENT_PAL_TAG_NPC_1: expected = gObjectEventPal_Npc1; break;
            case OBJ_EVENT_PAL_TAG_NPC_3: expected = gObjectEventPal_Npc3; break;
            case OBJ_EVENT_PAL_TAG_NPC_PINK: expected = gObjectEventPal_NpcPink; break;
            case OBJ_EVENT_PAL_TAG_NPC_WHITE: expected = gObjectEventPal_NpcWhite; break;
            }
            if (gfx->paletteTag == OBJ_EVENT_PAL_TAG_DYNAMIC)
                expected = OW_SHINY(obj) ? gSpeciesInfo[OW_SPECIES(obj)].overworldShinyPalette
                                        : gSpeciesInfo[OW_SPECIES(obj)].overworldPalette;
            gSpecialVar_0x8003 = arg == 12 ? OBJ_EVENT_GFX_SAILOR_FRLG
                : arg == 13 ? OBJ_EVENT_GFX_GENTLEMAN_FRLG : obj->graphicsId;
            if (expected != NULL)
                for (u32 i = 1; i < 16; i++)
                    if (gPlttBufferUnfaded[OBJ_PLTT_ID(sprite->oam.paletteNum) + i] != expected[i])
                        colors = FALSE;
            gSpecialVar_0x8005 = 1 | (sprite->inUse << 1) | (obj->invisible << 2)
                | (sprite->invisible << 3) | ((expected != NULL && colors) << 4)
                | ((sprite->oam.paletteNum == IndexOfSpritePaletteTag(gfx->paletteTag == OBJ_EVENT_PAL_TAG_DYNAMIC
                    ? GetDynamicFollowerPaletteTag(OW_SPECIES(obj), OW_SHINY(obj), OW_FEMALE(obj))
                    : gfx->paletteTag)) << 5);
            gSpecialVar_0x8006 = obj->graphicsId;
            gSpecialVar_0x8007 = sprite->oam.paletteNum;
            gSpecialVar_0x8008 = gfx->paletteTag;
            gSpecialVar_0x8009 = (gfx->width << 8) | gfx->height;
            gSpecialVar_0x800A = gfx->shadowSize | (obj->noShadow << 8);
            gSpecialVar_0x800B = obj->facingDirection;
        }
    }
    else if (command == 6)
        gSpecialVar_0x8005 = TrySavingData(SAVE_NORMAL);
    else if (command == 7)
    {
        FlagClear(FLAG_HUB_INTRO_TOUR_DONE);
        Warp(MAP_REGION_HUB, 16, 4);
    }
    else if (command == 10 && arg < 10)
    {
        static const s8 coords[][2] = {{11,40}, {12,17}, {12,20}, {25,17}, {27,8}, {33,46},
            {14,49}, {24,47}, {29,47}, {25,47}};
        Warp(arg < 6 ? MAP_ROUTE35 : MAP_NATIONAL_PARK_NORMAL, coords[arg][0], coords[arg][1]);
    }
    else if (command == 12)
    {
        static const u16 trainers[] = {TRAINER_IVAN_JT, TRAINER_ELLIOT, TRAINER_BROOKE,
            TRAINER_KIM, TRAINER_BRYAN_JT, TRAINER_IRWIN, TRAINER_ARNIE, TRAINER_WALT, TRAINER_DIRK};
        for (u32 i = 0; i < ARRAY_COUNT(trainers); i++)
            SetTrainerFlag(trainers[i]);
    }
    else if (command == 11)
        FlagSet(FLAG_HOENN_CHAMPION); // synthetic save only, for the real west-stairs return
}
