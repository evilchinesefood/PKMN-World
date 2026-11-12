#include "global.h"
#include "event_data.h"
#include "event_object_movement.h"
#include "battle.h"
#include "field_screen_effect.h"
#include "item.h"
#include "main.h"
#include "overworld.h"
#include "pokemon.h"
#include "pokemon_storage_system.h"
#include "save.h"
#include "special_pokemon.h"
#include "constants/flags.h"
#include "constants/maps.h"
#include "constants/items.h"
#include "constants/moves.h"
#include "constants/species.h"
#include "constants/vars.h"

static const struct
{
    u8 group;
    u8 number;
    u8 x;
    u8 y;
} sSources[] =
{
    {MAP_GROUP(MAP_PALLET_TOWN), MAP_NUM(MAP_PALLET_TOWN), 19, 15},
    {MAP_GROUP(MAP_ROUTE19), MAP_NUM(MAP_ROUTE19), 11, 12},
    {MAP_GROUP(MAP_ROUTE19), MAP_NUM(MAP_ROUTE19), 13, 12},
    {MAP_GROUP(MAP_GOLDENROD_CITY), MAP_NUM(MAP_GOLDENROD_CITY), 37, 39},
    {MAP_GROUP(MAP_VERMILION_CITY_POKEMON_FAN_CLUB), MAP_NUM(MAP_VERMILION_CITY_POKEMON_FAN_CLUB), 9, 8},
    {MAP_GROUP(MAP_VERMILION_CITY), MAP_NUM(MAP_VERMILION_CITY), 10, 20},
    {MAP_GROUP(MAP_VERMILION_CITY), MAP_NUM(MAP_VERMILION_CITY), 16, 21},
    {MAP_GROUP(MAP_AZALEA_TOWN_HOUSE1), MAP_NUM(MAP_AZALEA_TOWN_HOUSE1), 8, 7},
    {MAP_GROUP(MAP_AZALEA_TOWN), MAP_NUM(MAP_AZALEA_TOWN), 54, 9},
    {MAP_GROUP(MAP_CELADON_CITY), MAP_NUM(MAP_CELADON_CITY), 20, 17},
    {MAP_GROUP(MAP_CELADON_CITY), MAP_NUM(MAP_CELADON_CITY), 17, 25},
    {MAP_GROUP(MAP_CELADON_CITY), MAP_NUM(MAP_CELADON_CITY), 21, 21},
    {MAP_GROUP(MAP_OLIVINE_CITY), MAP_NUM(MAP_OLIVINE_CITY), 31, 55},
    {MAP_GROUP(MAP_OLIVINE_CITY), MAP_NUM(MAP_OLIVINE_CITY), 32, 55},
};

static void PrepareBattleParty(bool32 weak)
{
    for (u32 i = 0; i < gPartiesCount[B_TRAINER_PLAYER]; i++)
        CopyMonToPC(&gParties[B_TRAINER_PLAYER][i]);
    ZeroPlayerPartyMons();
    CreateMonWithIVs(&gParties[B_TRAINER_PLAYER][0], weak ? SPECIES_MAGIKARP : SPECIES_JOLTEON,
                    weak ? 1 : 100, 0x12345678, OTID_STRUCT_PLAYER_ID, 31);
    gPartiesCount[B_TRAINER_PLAYER] = 1;
    u32 metLevel = 1;
    SetMonData(&gParties[B_TRAINER_PLAYER][0], MON_DATA_MET_LEVEL, &metLevel);
    SetMonMoveSlot(&gParties[B_TRAINER_PLAYER][0], weak ? MOVE_SPLASH : MOVE_SEISMIC_TOSS, 0);
    for (u32 i = 1; i < MAX_MON_MOVES; i++)
        SetMonMoveSlot(&gParties[B_TRAINER_PLAYER][0], MOVE_NONE, i);
    if (weak)
    {
        u32 hp = 1;
        SetMonData(&gParties[B_TRAINER_PLAYER][0], MON_DATA_HP, &hp);
    }
    AddBagItem(ITEM_MASTER_BALL, 8);
    gLastUsedBall = gBallToDisplay = ITEM_MASTER_BALL;
}

static void ReportOwned(void)
{
    u32 mask = 0;
    u32 count = 0;
    for (u32 i = 0; i < PARTY_SIZE + TOTAL_BOXES_COUNT * IN_BOX_COUNT; i++)
    {
        struct BoxPokemon *mon = i < PARTY_SIZE ? &gParties[B_TRAINER_PLAYER][i].box
            : GetBoxedMonPtr((i - PARTY_SIZE) / IN_BOX_COUNT, (i - PARTY_SIZE) % IN_BOX_COUNT);
        u32 id = SpecialPokemon_FindSpecies(GetBoxMonData(mon, MON_DATA_SPECIES));
        if (id < SPECIAL_POKEMON_COUNT)
        {
            mask |= 1 << id;
            count++;
        }
    }
    gSpecialVar_Result = mask;
    gSpecialVar_0x8005 = count;
    gSpecialVar_0x8006 = CountTotalItemQuantityInBag(ITEM_MASTER_BALL);
}

void VisualFeatureFixture(void)
{
    u32 command = gSpecialVar_0x8004;
    u32 arg = gSpecialVar_0x8005;
    SetMainCallback2(CB2_Overworld);
    if (command == 0)
    {
        RemoveFollowingPokemon();
        CreateMonWithIVs(&gParties[B_TRAINER_PLAYER][0], SPECIES_JOLTEON, 80, 0x12345678, OTID_STRUCT_PLAYER_ID, 31);
        gPartiesCount[B_TRAINER_PLAYER] = 1;
        for (u32 i = FLAG_SPECIAL_COLLECTED_CLASSIC_CAP; i <= FLAG_SPECIAL_FLOWERS_TWO; i++)
            FlagClear(i);
        FlagSet(FLAG_SYS_POKEMON_GET);
        FlagSet(FLAG_SYS_POKEDEX_GET);
        FlagSet(FLAG_HUB_INTRO_TOUR_DONE);
        FlagSet(FLAG_TEMP_HIDE_FOLLOWER);
        VarSet(VAR_REGION_ARRIVAL, 0);
        VarSet(VAR_REPEL_STEP_COUNT, 250);
    }
    else if (command == 1 && arg < ARRAY_COUNT(sSources))
    {
        SetWarpDestination(sSources[arg].group, sSources[arg].number, WARP_ID_NONE, sSources[arg].x, sSources[arg].y);
        DoWarp();
    }
    else if (command == 2)
    {
        gSpecialVar_0x8005 = TrySavingData(SAVE_NORMAL);
    }
    else if (command == 3 || command == 4)
    {
        PrepareBattleParty(command == 4);
    }
    else if (command == 5)
    {
        ReportOwned();
    }
}
