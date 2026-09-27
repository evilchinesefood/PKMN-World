// Disposable capture/save setup, linked into scratch ROM padding only.
#include "global.h"
#include "event_data.h"
#include "event_object_movement.h"
#include "field_screen_effect.h"
#include "main.h"
#include "overworld.h"
#include "pokemon.h"
#include "save.h"
#include "constants/flags.h"
#include "constants/maps.h"
#include "constants/species.h"
#include "constants/vars.h"

static void Warp(u8 x, u8 y)
{
    SetWarpDestination(MAP_GROUP(MAP_VIRIDIAN_CITY), MAP_NUM(MAP_VIRIDIAN_CITY), WARP_ID_NONE, x, y);
    DoWarp();
}

void VisualFeatureFixture(void)
{
    u32 command = gSpecialVar_0x8004;
    u32 arg = gSpecialVar_0x8005;
    SetMainCallback2(CB2_Overworld);
    if (command == 0)
    {
        RemoveFollowingPokemon();
        CreateMonWithIVs(&gParties[B_TRAINER_PLAYER][0], SPECIES_PIKACHU, 40,
                        0x12345678, OTID_STRUCT_PLAYER_ID, 31);
        gPartiesCount[B_TRAINER_PLAYER] = 1;
        FlagSet(FLAG_SYS_POKEMON_GET);
        FlagSet(FLAG_HUB_INTRO_TOUR_DONE);
        FlagClear(FLAG_TEMP_HIDE_FOLLOWER);
        gSaveBlock2Ptr->johtoIntroDone = TRUE;
        gSaveBlock2Ptr->kantoIntroDone = TRUE;
        gSaveBlock2Ptr->hoennIntroDone = TRUE;
        VarSet(VAR_MAP_SCENE_VIRIDIAN_CITY_OLD_MAN, 2);
        VarSet(VAR_MAP_SCENE_VIRIDIAN_CITY_GYM_DOOR, 1);
        // Ordinary shop entry; the first-visit Parcel dialogue owns input at 0.
        VarSet(VAR_MAP_SCENE_VIRIDIAN_CITY_MART, 2);
        VarSet(VAR_REPEL_STEP_COUNT, 250);
        UpdateFollowingPokemon();
    }
    else if (command == 1)
    {
        static const u8 scenes[][2] = {{11,18}, {20,27}, {31,27}, {35,14}, {30,33}};
        if (arg < ARRAY_COUNT(scenes))
            Warp(scenes[arg][0], scenes[arg][1]);
    }
    else if (command == 2)
        gSpecialVar_0x8005 = TrySavingData(SAVE_NORMAL);
    else if (command == 3)
        Warp(arg & 0xFF, arg >> 8);
    else if (command == 4)
        gSpecialVar_0x8005 = IsFollowerVisible();
    else if (command == 5)
    {
        VarSet(VAR_MAP_SCENE_VIRIDIAN_CITY_GYM_DOOR, arg != 0);
        Warp(36, 12);
    }
}
