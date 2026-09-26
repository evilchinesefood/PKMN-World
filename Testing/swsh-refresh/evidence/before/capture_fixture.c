// Test-only entry point for isolated emulator fixtures. Never linked into the game.
#include "global.h"
#include "main.h"
#include "event_data.h"
#include "overworld.h"
#include "item.h"
#include "item_menu.h"
#include "money.h"
#include "pokemon.h"
#include "pokemon_storage_system.h"
#include "pokemon_summary_screen.h"
#include "party_menu.h"
#include "pokeblock.h"
#include "battle_pyramid_bag.h"
#include "berry_blender.h"
#include "shop.h"
#include "save.h"
#include "constants/items.h"
#include "constants/species.h"
#include "constants/moves.h"
#include "constants/flags.h"
#include "constants/vars.h"
#include "battle.h"
#include "battle_partner.h"
#include "load_save.h"
#include "constants/opponents.h"
#include "constants/battle_partner.h"
#include "battle_setup.h"
#include "wild_encounter.h"
#include "constants/battle.h"

static void SeedReview(void)
{
    static const u16 species[] = {SPECIES_PIKACHU, SPECIES_DRAGONITE, SPECIES_BLISSEY, SPECIES_SNORLAX, SPECIES_CHARMANDER, SPECIES_EEVEE};
    static const u16 items[] = {ITEM_POTION, ITEM_SUPER_POTION, ITEM_ETHER, ITEM_RARE_CANDY, ITEM_WATER_STONE, ITEM_LEFTOVERS, ITEM_POKE_BALL, ITEM_ULTRA_BALL, ITEM_TM01, ITEM_TM24, ITEM_HM01, ITEM_CHERI_BERRY, ITEM_CHOPLE_BERRY, ITEM_TOWN_MAP, ITEM_HUB_RETURN, ITEM_EV_IV_CHANGER, ITEM_POKEVIAL};
    ClearBag();
    ResetBagScrollPositions();
    for (u32 i = 0; i < ARRAY_COUNT(items); i++)
        AddBagItem(items[i], GetItemPocket(items[i]) == POCKET_KEY_ITEMS ? 1 : 99);
    AddBagItem(ITEM_SUPER_POTION, 900);
    SetMoney(&gSaveBlock1Ptr->money, 999999);
    FlagSet(FLAG_SYS_POKEMON_GET);
    FlagSet(FLAG_SYS_POKEDEX_GET);
    VarSet(VAR_REPEL_STEP_COUNT, 250);
    for (u32 i = 0; i < ARRAY_COUNT(species); i++)
    {
        struct Pokemon *mon = &gParties[B_TRAINER_PLAYER][i];
        u32 value;
        CreateMonWithIVs(mon, species[i], 40, 0x12345678 + i, OTID_STRUCT_PLAYER_ID, 31);
        SetMonMoveSlot(mon, MOVE_THUNDERBOLT, 0);
        SetMonMoveSlot(mon, MOVE_SURF, 1);
        SetMonMoveSlot(mon, MOVE_FLAMETHROWER, 2);
        SetMonMoveSlot(mon, MOVE_TACKLE, 3);
        value = i == 0 ? 1 : GetMonData(mon, MON_DATA_MAX_HP) / 2;
        SetMonData(mon, MON_DATA_HP, &value);
        value = 200; SetMonData(mon, MON_DATA_COOL, &value);
        value = 120; SetMonData(mon, MON_DATA_BEAUTY, &value);
        value = 80; SetMonData(mon, MON_DATA_CUTE, &value);
        value = 170; SetMonData(mon, MON_DATA_SMART, &value);
        value = 60; SetMonData(mon, MON_DATA_TOUGH, &value);
    }
    gPartiesCount[B_TRAINER_PLAYER] = ARRAY_COUNT(species);
    ResetPokemonStorageSystem();
    for (u32 box = 0; box < TOTAL_BOXES_COUNT; box++)
    {
        gPokemonStoragePtr->boxWallpapers[box] = box;
        for (u32 i = 0; i < ARRAY_COUNT(species); i++)
            SetBoxMonAt(box, i, &gParties[B_TRAINER_PLAYER][i].box);
    }
    gSaveBlock2Ptr->optionsTextSpeed = 2;
    gSaveBlock2Ptr->optionsButtonMode = OPTIONS_BUTTON_MODE_LR; // Existing Bag partner-page control.
    u32 zero = 0;
    SetMonData(&gParties[B_TRAINER_PLAYER][0], MON_DATA_PP1, &zero);
    u32 shiny = TRUE;
    SetMonData(&gParties[B_TRAINER_PLAYER][2], MON_DATA_IS_SHINY, &shiny);
    u32 status = STATUS1_POISON;
    SetMonData(&gParties[B_TRAINER_PLAYER][1], MON_DATA_STATUS, &status);
}

void VisualFeatureFixture(void)
{
    u32 command = gSpecialVar_0x8004;
    u32 arg = gSpecialVar_0x8005;
    SetMainCallback2(CB2_Overworld);
    switch (command)
    {
    case 0:
        SeedReview();
        break;
    case 1:
        CleanupOverworldWindowsAndTilemaps();
        GoToBagMenu(ITEMMENULOCATION_FIELD, arg, CB2_ReturnToField);
        break;
    case 2:
        CleanupOverworldWindowsAndTilemaps();
        GoToBagMenu(ITEMMENULOCATION_SHOP, arg, CB2_ReturnToField);
        break;
    case 3:
        CleanupOverworldWindowsAndTilemaps();
        ShowPokemonSummaryScreen(SUMMARY_MODE_NORMAL, gParties[B_TRAINER_PLAYER], arg, 5, CB2_ReturnToField);
        break;
    case 4:
        ShowPokemonStorageSystemPC();
        break;
    case 5:
        CleanupOverworldWindowsAndTilemaps();
        ChooseMonForTradingBoard(PARTY_MENU_TYPE_FIELD, CB2_ReturnToField);
        break;
    case 6:
    {
        static const u16 stock[] = {ITEM_POTION, ITEM_SUPER_POTION, ITEM_POKE_BALL, ITEM_ULTRA_BALL, ITEM_NONE};
        CreatePokemartMenu(stock);
        break;
    }
    case 7:
        CleanupOverworldWindowsAndTilemaps();
        gSaveBlock2Ptr->frontier.lvlMode = 0;
        gSaveBlock2Ptr->frontier.pyramidBag.itemId[0][0] = ITEM_POTION;
        gSaveBlock2Ptr->frontier.pyramidBag.quantity[0][0] = 9;
        GoToBattlePyramidBagMenu(PYRAMIDBAG_LOC_FIELD, CB2_ReturnToField);
        break;
    case 8:
    {
        const struct Pokeblock block = {.color = PBLOCK_CLR_RED, .spicy = 20, .dry = 10, .feel = 12};
        ClearPokeblocks();
        AddPokeblock(&block);
        CleanupOverworldWindowsAndTilemaps();
        OpenPokeblockCase(PBLOCK_CASE_FIELD, CB2_ReturnToField);
        break;
    }
    case 9:
        gSpecialVar_0x8004 = 1; // One NPC blender partner.
        CleanupOverworldWindowsAndTilemaps();
        DoBerryBlending();
        break;
    case 10:
        gPokemonStoragePtr->boxWallpapers[StorageGetCurrentBox()] = arg;
        break;
    case 12:
        ClearBag();
        break;
    case 13:
        CreateWildMon(SPECIES_MAGIKARP, 2);
        if (arg == 0)
            BattleSetup_StartWildBattle();
        else
        {
            gParties[B_TRAINER_OPPONENT_A][1] = gParties[B_TRAINER_OPPONENT_A][0];
            BattleSetup_StartDoubleWildBattle();
        }
        break;
    case 14:
    {
        // Read results through production accessors only after a menu returns.
        gSpecialVar_0x8005 = GetMonData(&gParties[B_TRAINER_PLAYER][arg], MON_DATA_HP);
        gSpecialVar_0x8006 = CountTotalItemQuantityInBag(ITEM_POTION);
        gSpecialVar_0x8007 = GetMonData(&gParties[B_TRAINER_PLAYER][arg], MON_DATA_PP1);
        break;
    }
    case 19:
    {
        struct BagPocket *pocket = &gBagPockets[POCKET_ITEMS];
        struct ItemSlot item = BagPocket_GetSlotData(pocket, 1);
        BagPocket_SetSlotItemIdAndCount(pocket, 1, ITEM_NONE, 0);
        BagPocket_SetSlotData(pocket, 40, item);
        break;
    }
    case 18:
        gSpecialVar_0x8005 = GetMonData(&gParties[B_TRAINER_PLAYER][arg], MON_DATA_SPECIES);
        gSpecialVar_0x8006 = GetMonData(&gParties[B_TRAINER_PLAYER][arg], MON_DATA_HELD_ITEM);
        gSpecialVar_0x8007 = GetMonData(&gParties[B_TRAINER_PLAYER][arg], MON_DATA_MOVE4);
        break;
    case 17:
        SavePlayerParty();
        TRAINER_BATTLE_PARAM.opponentA = TRAINER_CALVIN_1;
        TRAINER_BATTLE_PARAM.opponentB = TRAINER_BILLY;
        gPartnerTrainerId = TRAINER_PARTNER(PARTNER_LANCE);
        gBattleTypeFlags = BATTLE_TYPE_TRAINER | BATTLE_TYPE_DOUBLE | BATTLE_TYPE_MULTI | BATTLE_TYPE_INGAME_PARTNER | BATTLE_TYPE_TWO_OPPONENTS;
        for (u32 i = 0; i < MAX_FRONTIER_PARTY_SIZE; i++)
        {
            gSelectedOrderFromParty[i] = i + 1;
            gSaveBlock2Ptr->frontier.selectedPartyMons[i] = i + 1;
        }
        FillPartnerParty(gPartnerTrainerId);
        gBattleEnvironment = BattleSetup_GetEnvironmentId();
        CalculateEnemyPartyCount();
        BattleSetup_StartTrainerBattle_Debug();
        break;
    case 15:
    {
        u32 value = 1;
        SetMonData(&gParties[B_TRAINER_PLAYER][arg], MON_DATA_IS_EGG, &value);
        break;
    }
    case 11:
        gSpecialVar_0x8005 = TrySavingData(SAVE_NORMAL);
        break;
    }
}
