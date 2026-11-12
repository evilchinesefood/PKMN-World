// Test-only entry point linked into verified unused ROM padding.
#include "global.h"
#include "story_progress.h"
#include "main.h"
#include "event_data.h"
#include "fieldmap.h"
#include "field_screen_effect.h"

#include "overworld.h"
#include "pokemon.h"
#include "regions.h"
#include "item.h"
#include "start_menu.h"
#include "text.h"
#include "region_map.h"
#include "pokedex.h"
#include "pokedex_plus_hgss.h"
#include "constants/maps.h"
#include "constants/pokedex.h"
#include "constants/flags.h"
#include "constants/vars.h"

static u32 Hash(u32 value, const void *data, u32 size)
{
    const u8 *bytes = data;
    while (size--) value = (value ^ *bytes++) * 16777619;
    return value;
}

static u32 Snapshot(void)
{
    u32 value = 2166136261;
    // Exclude transient flags and menu-order preferences owned by Start itself.
    value = Hash(value, gSaveBlock1Ptr->flags + 4, sizeof(gSaveBlock1Ptr->flags) - 4);
    value = Hash(value, gSaveBlock1Ptr->vars + NUM_TEMP_VARS,
        sizeof(gSaveBlock1Ptr->vars) - NUM_TEMP_VARS * sizeof(u16));
    // Return-to-field deliberately relocates/rekeys save blocks. Compare
    // decrypted bag contents, not the changed encrypted quantity bytes.
    for (u32 pocket = 0; pocket < POCKETS_COUNT; pocket++)
        for (u32 slot = 0; slot < gBagPockets[pocket].capacity; slot++)
        {
            struct ItemSlot item = BagPocket_GetSlotData(&gBagPockets[pocket], slot);
            value = Hash(value, &item, sizeof(item));
        }
    value = Hash(value, gSaveBlock1Ptr, offsetof(struct SaveBlock1, savedMusic));
    value = Hash(value, &gMapHeader, sizeof(gMapHeader));
    value = Hash(value, &gSaveBlock2Ptr->currentRegion, 3);
    value = Hash(value, &gCurrentRegion, sizeof(gCurrentRegion));
    value = Hash(value, gSaveBlock3Ptr->region.regionVars, sizeof(gSaveBlock3Ptr->region.regionVars));
    value = Hash(value, gSaveBlock3Ptr->region.johtoFlags, sizeof(gSaveBlock3Ptr->region.johtoFlags));
    value = Hash(value, gSaveBlock3Ptr->region.kantoTrainerFlags, sizeof(gSaveBlock3Ptr->region.kantoTrainerFlags));
    value = Hash(value, gSaveBlock3Ptr->region.johtoTrainerFlags, sizeof(gSaveBlock3Ptr->region.johtoTrainerFlags));
    value = Hash(value, &gSaveBlock3Ptr->region.regionalTravel, sizeof(gSaveBlock3Ptr->region.regionalTravel));
    value = Hash(value, gParties[B_TRAINER_PLAYER], sizeof(gParties[B_TRAINER_PLAYER]));
    value = Hash(value, &gPartiesCount[B_TRAINER_PLAYER], sizeof(gPartiesCount[B_TRAINER_PLAYER]));
    return value;
}

void VisualFeatureFixture(void)
{
    u32 command = gSpecialVar_0x8004;
    if (command == 0)
    {
        // Three deliberately different campaign positions.
        gSaveBlock2Ptr->kantoIntroDone = TRUE;
        gSaveBlock2Ptr->johtoIntroDone = TRUE;
        gSaveBlock2Ptr->hoennIntroDone = TRUE;
        VarSet(VAR_MAP_SCENE_PALLET_TOWN_PROFESSOR_OAKS_LAB, 5);
        FlagSet(FLAG_JOHTO_STARTER_CHOSEN);
        VarSet(VAR_NEWBARKTOWN_LABSTATE, 2);
        FlagSet(FLAG_SET_WALL_CLOCK);
        VarSet(VAR_LITTLEROOT_RIVAL_STATE, 3);
        SetCurrentRegion(REGION_KANTO);
        u32 hash = Snapshot();
        gSpecialVar_0x8006 = hash;
        gSpecialVar_0x8007 = hash >> 16;
        SetMainCallback2(CB2_Overworld);
    }
    else if (command == 1)
    {
        CleanupOverworldWindowsAndTilemaps();
        ShowStoryProgress(CB2_ReturnToField);
    }
    else if (command == 2)
    {
        gSpecialVar_Result = Snapshot() == ((u32)gSpecialVar_0x8006 | (u32)gSpecialVar_0x8007 << 16);
        SetMainCallback2(CB2_Overworld);
    }
    else if (command == 3)
    {
        // Width measurement uses the production font routine and compiled text.
        const u8 *text = (const u8 *)((u32)gSpecialVar_0x8008 | (u32)gSpecialVar_0x8009 << 16);
        gSpecialVar_Result = GetStringWidth(FONT_SMALL, text, 0);
        SetMainCallback2(CB2_Overworld);
    }
    else if (command == 4)
    {
        // Scripted menu opens use the classic menu even in graphical builds.
        FlagSet(FLAG_SYS_POKEDEX_GET);
        FlagSet(FLAG_SYS_POKEMON_GET);
        FlagSet(FLAG_SYS_POKENAV_GET);
        FlagSet(FLAG_SYS_DEXNAV_GET);
        SetMainCallback2(CB2_Overworld);
        ShowStartMenu();
    }
    else if (command == 5)
    {
        FlagSet(FLAG_KANTO_CHAMPION);
        for (u32 i = 0; i < NUM_BADGES; i++)
            FlagSet(FLAG_KANTO_BADGE_1 + i);
        VarSet(VAR_MAP_SCENE_ONE_ISLAND_POKEMON_CENTER_1F, 4);
        SetMainCallback2(CB2_Overworld);
    }
    else if (command == 6)
    {
        const struct StoryObjective *objective = (const void *)((u32)gSpecialVar_0x8008 | (u32)gSpecialVar_0x8009 << 16);
        CleanupOverworldWindowsAndTilemaps();
        ShowStoryDestinationMap(objective, CB2_ReturnToField);
    }
    else if (command == 7 || command == 8 || command == 13)
    {
        MainCallback resume = (MainCallback)((u32)gSpecialVar_0x8008 | (u32)gSpecialVar_0x8009 << 16);
        u32 hash = Snapshot();
        if (command == 13)
            VarSet(VAR_MAP_SCENE_PALLET_TOWN_PROFESSOR_OAKS_LAB, gSpecialVar_0x8005);
        else if (command == 7)
        {
            gSpecialVar_0x8006 = hash;
            gSpecialVar_0x8007 = hash >> 16;
        }
        else
            gSpecialVar_Result = hash == ((u32)gSpecialVar_0x8006 | (u32)gSpecialVar_0x8007 << 16);
        SetMainCallback2(resume);
    }
    else if (command == 9)
    {
        CleanupOverworldWindowsAndTilemaps();
        FieldInitRegionMap(CB2_ReturnToField);
    }
    else if (command == 10)
    {
        static const u16 maps[] = {MAP_PALLET_TOWN, MAP_NEW_BARK_TOWN, MAP_LITTLEROOT_TOWN,
            MAP_ONE_ISLAND, MAP_FOUR_ISLAND, MAP_SIX_ISLAND, MAP_REGION_HUB, MAP_REGION_HUB_2F};
        static const s8 coords[][2] = {{8,10}, {12,10}, {10,10}, {12,12}, {12,12}, {12,12}, {7,7}, {7,7}};
        u32 arg = gSpecialVar_0x8005;
        if (arg < ARRAY_COUNT(maps))
        {
            SetCurrentRegion(arg == 1 ? REGION_JOHTO : arg == 2 ? REGION_HOENN : REGION_KANTO);
            SetWarpDestination(MAP_GROUP(maps[arg]), MAP_NUM(maps[arg]), WARP_ID_NONE, coords[arg][0], coords[arg][1]);
            SetMainCallback2(CB2_Overworld);
            DoWarp();
        }
    }
    else if (command == 11)
    {
        FlagSet(FLAG_SYS_POKEDEX_GET);
        EnableNationalPokedex();
        gSaveBlock2Ptr->pokedex.mode = DEX_MODE_NATIONAL;
        for (u32 i = 1; i <= 12; i++)
        {
            GetSetPokedexFlag(i, FLAG_SET_SEEN);
            GetSetPokedexFlag(i, FLAG_SET_CAUGHT);
        }
        CleanupOverworldWindowsAndTilemaps();
        ResetPokedexScrollPositions();
        SetMainCallback2(CB2_OpenPokedexPlusHGSS);
    }
}
