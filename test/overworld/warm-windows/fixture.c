// Capture/save setup only; linked into verified unused padding of a disposable
// ROM by test/overworld/visual-features/build_fixture.py, never into a shipped ROM.
#include "global.h"
#include "battle_setup.h"
#include "event_data.h"
#include "event_object_movement.h"
#include "field_screen_effect.h"
#include "main.h"
#include "overworld.h"
#include "pokemon.h"
#include "save.h"
#include "wild_encounter.h"
#include "constants/flags.h"
#include "constants/johto_flags.h"
#include "constants/maps.h"
#include "constants/species.h"
#include "constants/vars.h"

void VisualFeatureFixture(void)
{
    u32 command = gSpecialVar_0x8004;
    u32 arg = gSpecialVar_0x8005;
    SetMainCallback2(CB2_Overworld);
    if (command == 0)
    {
        RemoveFollowingPokemon();
        CreateMonWithIVs(&gParties[B_TRAINER_PLAYER][0], SPECIES_PIKACHU, 100,
                        0x12345678, OTID_STRUCT_PLAYER_ID, 31);
        gPartiesCount[B_TRAINER_PLAYER] = 1;
        FlagSet(FLAG_SYS_POKEMON_GET);
        FlagSet(FLAG_TEMP_HIDE_FOLLOWER);
        FlagSet(FLAG_HUB_INTRO_TOUR_DONE);
        FlagSet(FLAG_HIDE_SILVER_NEWBARKTOWN);
        FlagSet(FLAG_HIDE_SILVER_CHERRYGROVE);
        FlagSet(FLAG_HIDE_GUIDE_GENT_CHERRYGROVE);
        gSaveBlock2Ptr->johtoIntroDone = TRUE;
        gSaveBlock2Ptr->kantoIntroDone = TRUE;
        gSaveBlock2Ptr->hoennIntroDone = TRUE;
        VarSet(VAR_CHERRYGROVE_CITY_STATE, 5);
        VarSet(VAR_REPEL_STEP_COUNT, 250);
    }
    else if (command == 1)
    {
        static const struct { u16 map; s8 x, y; } scenes[] =
        {
            {MAP_NEW_BARK_TOWN, 12, 10},
            {MAP_CHERRYGROVE_CITY, 34, 16},
            {MAP_CHERRYGROVE_CITY, 42, 17},
            {MAP_CHERRYGROVE_CITY, 50, 20},
            {MAP_ROUTE30, 35, 7},
            {MAP_ROUTE30, 26, 42},
            {MAP_ROUTE29, 35, 16},
            {MAP_ROUTE27, 80, 20},
            {MAP_ROUTE31, 30, 11},
            {MAP_ROUTE46, 13, 23},
            {MAP_NEW_BARK_TOWN, 1, 13},
        };
        if (arg < ARRAY_COUNT(scenes))
        {
            SetWarpDestination(MAP_GROUP(scenes[arg].map), MAP_NUM(scenes[arg].map),
                               WARP_ID_NONE, scenes[arg].x, scenes[arg].y);
            DoWarp();
        }
    }
    else if (command == 2)
    {
        CreateWildMon(SPECIES_POOCHYENA, 2);
        BattleSetup_StartWildBattle();
    }
    else if (command == 3)
        gSpecialVar_0x8005 = TrySavingData(SAVE_NORMAL);
}
