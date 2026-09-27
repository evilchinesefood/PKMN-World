// Capture/save setup only; linked into verified unused padding of a disposable
// ROM by Testing/visual-features/build_fixture.py, never into a shipped ROM.
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
            {MAP_AZALEA_TOWN, 31, 18},
            {MAP_BLACKTHORN_CITY, 27, 28},
            {MAP_CELADON_CITY, 28, 21},
            {MAP_CERULEAN_CITY, 22, 22},
            {MAP_CHERRYGROVE_CITY, 32, 16},
            {MAP_CIANWOOD_CITY, 12, 28},
            {MAP_CINNABAR_ISLAND, 14, 14},
            {MAP_DEWFORD_TOWN, 2, 13},
            {MAP_ECRUTEAK_CITY, 36, 28},
            {MAP_EVER_GRANDE_CITY, 27, 51},
            {MAP_FALLARBOR_TOWN, 14, 10},
            {MAP_FIVE_ISLAND, 18, 9},
            {MAP_FORTREE_CITY, 20, 13},
            {MAP_FOUR_ISLAND, 18, 23},
            {MAP_FUCHSIA_CITY, 25, 34},
            {MAP_GOLDENROD_CITY, 27, 23},
            {MAP_INDIGO_PLATEAU_EXTERIOR, 11, 9},
            {MAP_JOHTO_INDIGO_PLATEAU, 11, 9},
            {MAP_LAKE_OF_RAGE, 39, 44},
            {MAP_LAVARIDGE_TOWN, 9, 9},
            {MAP_LAVENDER_TOWN, 6, 8},
            {MAP_LILYCOVE_CITY, 24, 17},
            {MAP_LITTLEROOT_TOWN, 10, 10},
            {MAP_MAHOGANYTOWN, 17, 13},
            {MAP_MAUVILLE_CITY, 22, 8},
            {MAP_MOSSDEEP_CITY, 37, 20},
            {MAP_MT_SILVER_OUTSIDE, 23, 16},
            {MAP_NEW_BARK_TOWN, 14, 23},
            {MAP_OLDALE_TOWN, 14, 9},
            {MAP_OLIVINE_CITY, 30, 35},
            {MAP_ONE_ISLAND, 12, 10},
            {MAP_PACIFIDLOG_TOWN, 8, 18},
            {MAP_PALLET_TOWN, 8, 10},
            {MAP_PETALBURG_CITY, 14, 10},
            {MAP_PEWTER_CITY, 28, 21},
            {MAP_RUSTBORO_CITY, 24, 21},
            {MAP_SAFARI_ZONE_GATE, 13, 17},
            {MAP_SAFFRON_CITY_CONNECTION, 30, 17},
            {MAP_SAFFRON_CITY, 40, 24},
            {MAP_SEVEN_ISLAND, 12, 6},
            {MAP_SIX_ISLAND, 11, 14},
            {MAP_SLATEPORT_CITY, 13, 29},
            {MAP_SOOTOPOLIS_CITY, 30, 34},
            {MAP_THREE_ISLAND, 18, 15},
            {MAP_TWO_ISLAND, 21, 10},
            {MAP_VERDANTURF_TOWN, 12, 6},
            {MAP_VERMILION_CITY, 29, 20},
            {MAP_VIOLET_CITY, 27, 26},
            {MAP_VIRIDIAN_CITY, 26, 29},
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
    else if (command == 4)
    {
        static const struct { u16 map; s8 x, y; } doors[] =
        {
            {MAP_OLDALE_TOWN, 6, 17},
            {MAP_CINNABAR_ISLAND, 14, 12},
            {MAP_CHERRYGROVE_CITY, 34, 14},
        };
        if (arg < ARRAY_COUNT(doors))
        {
            SetWarpDestination(MAP_GROUP(doors[arg].map), MAP_NUM(doors[arg].map),
                               WARP_ID_NONE, doors[arg].x, doors[arg].y);
            DoWarp();
        }
    }
}
