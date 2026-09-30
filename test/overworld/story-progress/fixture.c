// Test-only entry point linked into verified unused ROM padding.
#include "global.h"
#include "story_progress.h"
#include "main.h"
#include "event_data.h"
#include "fieldmap.h"
#include "overworld.h"
#include "pokemon.h"
#include "regions.h"
#include "item.h"
#include "start_menu.h"
#include "text.h"
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
    value = Hash(value, &gSaveBlock1Ptr->location, sizeof(gSaveBlock1Ptr->location));
    value = Hash(value, &gSaveBlock1Ptr->lastHealLocation, sizeof(gSaveBlock1Ptr->lastHealLocation));
    value = Hash(value, &gSaveBlock2Ptr->currentRegion, 1);
    value = Hash(value, &gCurrentRegion, sizeof(gCurrentRegion));
    value = Hash(value, gSaveBlock3Ptr->region.regionVars, sizeof(gSaveBlock3Ptr->region.regionVars));
    value = Hash(value, gSaveBlock3Ptr->region.johtoFlags, sizeof(gSaveBlock3Ptr->region.johtoFlags));
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
}
