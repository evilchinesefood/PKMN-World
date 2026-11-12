// Test-only entry point, linked into checked-unused ROM padding. Never shipped.
#include "global.h"
#include "battle_setup.h"
#include "event_data.h"
#include "event_object_movement.h"
#include "field_screen_effect.h"
#include "main.h"
#include "overworld.h"
#include "palette_swap.h"
#include "player_outfit.h"
#include "trainer.h"
#include "field_player_avatar.h"
#include "sprite.h"
#include "constants/event_objects.h"
#include "pokemon.h"
#include "save.h"
#include "trainer_card.h"
#include "wild_encounter.h"
#include "constants/flags.h"
#include "constants/maps.h"
#include "constants/species.h"
#include "constants/trainers.h"
#include "constants/vars.h"

void VisualFeatureFixture(void)
{
    u32 command = gSpecialVar_0x8004;
    u32 arg = gSpecialVar_0x8005;
    SetMainCallback2(CB2_Overworld);
    switch (command)
    {
    case 0:
        RemoveFollowingPokemon();
        CreateMonWithIVs(&gParties[B_TRAINER_PLAYER][0], SPECIES_JOLTEON, 80, 0x12345678, OTID_STRUCT_PLAYER_ID, 31);
        gPartiesCount[B_TRAINER_PLAYER] = 1;
        FlagSet(FLAG_SYS_POKEMON_GET);
        FlagSet(FLAG_HUB_INTRO_TOUR_DONE);
        FlagSet(FLAG_TEMP_HIDE_FOLLOWER);
        VarSet(VAR_REPEL_STEP_COUNT, 250);
        gSpecialVar_0x8005 = TRAINER_PIC_COUNT;
        break;
    case 1:
        if (arg >= 48)
            return;
        gSaveBlock2Ptr->playerGender = arg / 24;
        VarSet(VAR_PLAYER_PALETTE, arg % 24);
        SetWarpDestination(MAP_GROUP(MAP_PETALBURG_CITY), MAP_NUM(MAP_PETALBURG_CITY), WARP_ID_NONE, 7, 22);
        gSpecialVar_0x8005 = GetTrainerPicTag(GetEquippedOutfitTrainerPic(), FALSE);
        DoWarp();
        break;
    case 2:
        ShowPlayerTrainerCard(CB2_ReturnToField);
        break;
    case 3:
        CreateWildMon(SPECIES_POOCHYENA, 2);
        BattleSetup_StartWildBattle();
        break;
    case 7:
        VarSet(VAR_OBJ_GFX_ID_0, OBJ_EVENT_GFX_NINJA_BOY);
        VarSet(VAR_OBJ_GFX_ID_F, OBJ_EVENT_GFX_LITTLE_BOY);
        gSpecialVar_0x8005 =
            (GetObjectEventGraphicsInfo(413) == GetObjectEventGraphicsInfo(OBJ_EVENT_GFX_NINJA_BOY))
            | ((GetObjectEventGraphicsInfo(428) == GetObjectEventGraphicsInfo(OBJ_EVENT_GFX_LITTLE_BOY)) << 1)
            | ((GetObjectEventGraphicsInfo(412) == GetObjectEventGraphicsInfo(OBJ_EVENT_GFX_NINJA_BOY)) << 2);
        break;
    case 6:
    {
        static const u16 poses[2][9] = {
            {OBJ_EVENT_GFX_BRENDAN_NORMAL, OBJ_EVENT_GFX_BRENDAN_MACH_BIKE, OBJ_EVENT_GFX_BRENDAN_ACRO_BIKE, OBJ_EVENT_GFX_BRENDAN_SURFING, OBJ_EVENT_GFX_BRENDAN_FIELD_MOVE, OBJ_EVENT_GFX_BRENDAN_FISHING, OBJ_EVENT_GFX_BRENDAN_WATERING, OBJ_EVENT_GFX_BRENDAN_UNDERWATER, OBJ_EVENT_GFX_BRENDAN_DECORATING},
            {OBJ_EVENT_GFX_MAY_NORMAL, OBJ_EVENT_GFX_MAY_MACH_BIKE, OBJ_EVENT_GFX_MAY_ACRO_BIKE, OBJ_EVENT_GFX_MAY_SURFING, OBJ_EVENT_GFX_MAY_FIELD_MOVE, OBJ_EVENT_GFX_MAY_FISHING, OBJ_EVENT_GFX_MAY_WATERING, OBJ_EVENT_GFX_MAY_UNDERWATER, OBJ_EVENT_GFX_MAY_DECORATING},
        };
        u16 pose = arg % 9;
        u16 graphicsId = GetOutfitGraphicsId(GetEquippedPlayerOutfit(), poses[gSaveBlock2Ptr->playerGender == FEMALE][pose]);
        ObjectEventSetGraphicsId(&gObjectEvents[gPlayerAvatar.objectEventId], graphicsId);
        StartSpriteAnim(&gSprites[gPlayerAvatar.spriteId], pose == 8 ? 0 : arg / 9);
        break;
    }
    case 5:
        SetWarpDestination(MAP_GROUP(MAP_REGION_HUB), MAP_NUM(MAP_REGION_HUB), WARP_ID_NONE, 7, 8);
        DoWarp();
        break;
    case 4:
        gSpecialVar_0x8005 = TrySavingData(SAVE_NORMAL);
        break;
    }
}
