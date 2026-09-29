// Test-only capture entry point, linked into verified-unused ROM padding.
// It enters the real production screens; it is never linked into a release.
#include "global.h"
#include "main.h"
#include "event_data.h"
#include "fieldmap.h"
#include "field_screen_effect.h"
#include "field_weather.h"
#include "battle_setup.h"
#include "wild_encounter.h"
#include "region_map.h"
#include "save.h"
#include "item.h"
#include "constants/items.h"
#include "constants/johto_flags.h"
#include "option_menu.h"
#include "overworld.h"
#include "pokedex.h"
#include "pokedex_plus_hgss.h"
#include "pokemon.h"
#include "trainer_card.h"
#include "constants/flags.h"
#include "constants/maps.h"
#include "constants/pokedex.h"
#include "constants/species.h"
#include "constants/vars.h"

void VisualFeatureFixture(void)
{
    u32 command = gSpecialVar_0x8004;
    u32 arg = gSpecialVar_0x8005;
    if (command == 0)
    {
        FlagSet(FLAG_SYS_POKEDEX_GET);
        FlagSet(FLAG_SYS_POKEMON_GET);
        EnableNationalPokedex();
        VarSet(VAR_REPEL_STEP_COUNT, 250);
        gSaveBlock2Ptr->pokedex.mode = DEX_MODE_NATIONAL;
        if (gPartiesCount[B_TRAINER_PLAYER] == 0)
        {
            CreateMonWithIVs(&gParties[B_TRAINER_PLAYER][0], SPECIES_PIKACHU, 100, 0x12345678, OTID_STRUCT_PLAYER_ID, 31);
            gPartiesCount[B_TRAINER_PLAYER] = 1;
        }
        for (u32 i = 1; i <= 12; i++)
        {
            GetSetPokedexFlag(i, FLAG_SET_SEEN);
            GetSetPokedexFlag(i, FLAG_SET_CAUGHT);
        }
        SetMainCallback2(CB2_Overworld);
    }
    else if (command == 1)
    {
        CleanupOverworldWindowsAndTilemaps();
        gSaveBlock2Ptr->optionsWindowFrameType = arg;
        gMain.savedCallback = CB2_ReturnToField;
        SetMainCallback2(CB2_InitOptionMenu);
    }
    else if (command == 2)
    {
        if (arg)
        {
            FlagSet(FLAG_TEMP_1); // only used by the isolated Rider-enabled build
            FlagSet(FLAG_VISITED_PETALBURG_CITY);
            FlagSet(FLAG_VISITED_VIOLET_CITY);
            FlagSet(FLAG_WORLD_MAP_FUCHSIA_CITY);
        }
        CleanupOverworldWindowsAndTilemaps();
        FieldInitRegionMap(CB2_ReturnToField);
    }
    else if (command == 3)
    {
        CleanupOverworldWindowsAndTilemaps();
        ShowPlayerTrainerCard(CB2_ReturnToField);
    }
    else if (command == 4)
    {
        if (arg)
        {
            DisableNationalPokedex();
            gSaveBlock2Ptr->pokedex.mode = DEX_MODE_HOENN;
        }
        else
        {
            EnableNationalPokedex();
            gSaveBlock2Ptr->pokedex.mode = DEX_MODE_NATIONAL;
        }
        CleanupOverworldWindowsAndTilemaps();
        ResetPokedexScrollPositions();
        SetMainCallback2(CB2_OpenPokedexPlusHGSS);
    }
    else if (command == 5)
    {
        gSaveBlock2Ptr->optionsWindowFrameType = arg;
        SetMainCallback2(CB2_Overworld);
    }
    else if (command == 6)
    {
        SetWeather(arg);
        DoCurrentWeather();
        SetMainCallback2(CB2_Overworld);
    }
    else if (command == 7)
    {
        CleanupOverworldWindowsAndTilemaps();
        SetMainCallback2(CB2_OpenFlyMap);
    }
    else if (command == 8)
    {
        CreateWildMon(SPECIES_POOCHYENA, 2);
        SetMainCallback2(CB2_Overworld);
        BattleSetup_StartWildBattle();
    }
    else if (command == 9)
    {
        VarSet(VAR_REPEL_STEP_COUNT, arg);
        SetMainCallback2(CB2_Overworld);
    }
    else if (command == 10)
    {
        if (!CheckBagHasItem(ITEM_TOWN_MAP, 1))
            AddBagItem(ITEM_TOWN_MAP, 1);
        gSpecialVar_0x8005 = TrySavingData(SAVE_NORMAL);
        SetMainCallback2(CB2_Overworld);
    }
    else if (command == 20)
    {
        static const u16 maps[] = {MAP_PETALBURG_CITY, MAP_VIOLET_CITY, MAP_FUCHSIA_CITY, MAP_ROUTE119};
        static const s8 coords[][2] = {{7,22}, {23,28}, {14,20}, {7,60}};
        if (arg < ARRAY_COUNT(maps))
        {
            SetWarpDestination(MAP_GROUP(maps[arg]), MAP_NUM(maps[arg]), WARP_ID_NONE, coords[arg][0], coords[arg][1]);
            SetMainCallback2(CB2_Overworld);
            DoWarp();
        }
    }
}
