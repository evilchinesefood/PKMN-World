#include "global.h"
#include "clock.h"
#include "new_game.h"
#include "random.h"
#include "pokemon.h"
#include "roamer.h"
#include "pokemon_size_record.h"
#include "script.h"
#include "lottery_corner.h"
#include "play_time.h"
#include "mauville_old_man.h"
#include "match_call.h"
#include "lilycove_lady.h"
#include "load_save.h"
#include "pokeblock.h"
#include "dewford_trend.h"
#include "berry.h"
#include "rtc.h"
#include "easy_chat.h"
#include "event_data.h"
#include "money.h"
#include "trainer_hill.h"
#include "trainer_tower.h"
#include "tv.h"
#include "coins.h"
#include "text.h"
#include "overworld.h"
#include "mail.h"
#include "battle_records.h"
#include "item.h"
#include "pokedex.h"
#include "apprentice.h"
#include "frontier_util.h"
#include "pokedex.h"
#include "save.h"
#include "link_rfu.h"
#include "main.h"
#include "contest.h"
#include "item_menu.h"
#include "pokemon_storage_system.h"
#include "pokemon_jump.h"
#include "decoration_inventory.h"
#include "secret_base.h"
#include "string_util.h"
#include "player_pc.h"
#include "field_specials.h"
#include "berry_powder.h"
#include "mystery_gift.h"
#include "union_room_chat.h"
#include "quests.h"
#include "constants/map_groups.h"
#include "constants/items.h"
#include "difficulty.h"
#include "follower_npc.h"
#include "regions.h"
#include "constants/johto_flags.h"

extern const u8 EventScript_ResetAllMapFlags[];
extern const u8 EventScript_ResetAllMapFlagsFrlg[];

static void ClearFrontierRecord(void);
static void WarpToTruck(void);
static void ResetMiniGamesRecords(void);
static void ResetItemFlags(void);
static void ResetDexNav(void);

EWRAM_DATA bool8 gDifferentSaveFile = FALSE;
EWRAM_DATA bool8 gEnableContestDebugging = FALSE;

static const struct ContestWinner sContestWinnerPicDummy =
{
    .monName = _(""),
    .trainerName = _("")
};

void SetTrainerId(u32 trainerId, u8 *dst)
{
    dst[0] = trainerId;
    dst[1] = trainerId >> 8;
    dst[2] = trainerId >> 16;
    dst[3] = trainerId >> 24;
}

u32 GetTrainerId(u8 *trainerId)
{
    return (trainerId[3] << 24) | (trainerId[2] << 16) | (trainerId[1] << 8) | (trainerId[0]);
}

void CopyTrainerId(u8 *dst, u8 *src)
{
    s32 i;
    for (i = 0; i < TRAINER_ID_LENGTH; i++)
        dst[i] = src[i];
}

static void InitPlayerTrainerId(void)
{
    u32 trainerId = (Random() << 16) | GetGeneratedTrainerIdLower();
    SetTrainerId(trainerId, gSaveBlock2Ptr->playerTrainerId);
}

// L=A isnt set here for some reason.
static void SetDefaultOptions(void)
{
    gSaveBlock2Ptr->optionsTextSpeed = OPTIONS_TEXT_SPEED_MID;
    gSaveBlock2Ptr->optionsWindowFrameType = 0;
    gSaveBlock2Ptr->optionsSound = OPTIONS_SOUND_MONO;
    gSaveBlock2Ptr->optionsBattleStyle = OPTIONS_BATTLE_STYLE_SHIFT;
    gSaveBlock2Ptr->optionsBattleSceneOff = FALSE;
    gSaveBlock2Ptr->optionsAutosave = FALSE;
    gSaveBlock2Ptr->regionMapZoom = FALSE;
}

static void ClearPokedexFlags(void)
{
    gUnusedPokedexU8 = 0;
    memset(&gSaveBlock1Ptr->dexCaught, 0, sizeof(gSaveBlock1Ptr->dexCaught));
    memset(&gSaveBlock1Ptr->dexSeen, 0, sizeof(gSaveBlock1Ptr->dexSeen));
}

void ClearAllContestWinnerPics(void)
{
    s32 i;

    ClearContestWinnerPicsInContestHall();

    // Clear Museum paintings
    for (i = MUSEUM_CONTEST_WINNERS_START; i < NUM_CONTEST_WINNERS; i++)
        gSaveBlock1Ptr->contestWinners[i] = sContestWinnerPicDummy;
}

static void ClearFrontierRecord(void)
{
    CpuFill32(0, &gSaveBlock2Ptr->frontier, sizeof(gSaveBlock2Ptr->frontier));

    gSaveBlock2Ptr->frontier.opponentNames[0][0] = EOS;
    gSaveBlock2Ptr->frontier.opponentNames[1][0] = EOS;
}

static void WarpToTruck(void)
{
#if ALL_REGIONS
    // Region-switch: every new game lands in the World Transit hub; the destination region is
    // chosen by talking to a gate attendant (data/maps/RegionHub). startRegion stays
    // REGION_NONE until then. Spawn on the departure-concourse crest at (16,4) via
    // WARP_ID_NONE + explicit coords (the FRLG new-game pattern above) - same tile as hub
    // warp 0, a plain floor anchor with no warp behavior, so the fade-in can never
    // re-trigger a warp.
    SetWarpDestination(MAP_GROUP(MAP_REGION_HUB), MAP_NUM(MAP_REGION_HUB), WARP_ID_NONE, 16, 4);
#else
    if (IS_FRLG)
        SetWarpDestination(MAP_GROUP(MAP_PALLET_TOWN_PLAYERS_HOUSE_2F), MAP_NUM(MAP_PALLET_TOWN_PLAYERS_HOUSE_2F), WARP_ID_NONE, 6, 6);
    else
        SetWarpDestination(MAP_GROUP(MAP_INSIDE_OF_TRUCK), MAP_NUM(MAP_INSIDE_OF_TRUCK), WARP_ID_NONE, -1, -1);
#endif
    WarpIntoMap();
}

void Sav2_ClearSetDefault(void)
{
    ClearSav2();
    SetDefaultOptions();
}

void ResetMenuAndMonGlobals(void)
{
    gDifferentSaveFile = FALSE;
    ResetPokedexScrollPositions();
    ZeroPlayerPartyMons();
    ZeroEnemyPartyMons();
    ResetBagScrollPositions();
    ResetPokeblockScrollPositions();
}

void NewGameInitData(void)
{
#if IS_FRLG || ALL_REGIONS
    u8 rivalName[PLAYER_NAME_LENGTH + 1];
    // The Oak intro's outfit picker sets VAR_PLAYER_PALETTE, but ClearSav1() below wipes all
    // SaveBlock1 vars. Carry the pick across (like rivalName) so the chosen outfit actually
    // reaches the overworld/battle player sprites.
    u16 playerOutfit = VarGet(VAR_PLAYER_PALETTE);
#endif
    if (gSaveFileStatus == SAVE_STATUS_EMPTY || gSaveFileStatus == SAVE_STATUS_CORRUPT)
        RtcReset();

#if ALL_REGIONS
    // {RIVAL} is derived from the current region at text-expand time now (see string_util.c),
    // so no fixed rival name is stored here. The old per-region copy keyed on GetStartRegion(),
    // which was always REGION_HOENN (startRegion was never set), so only this EOS path ever ran.
    rivalName[0] = EOS;
#elif IS_FRLG
    StringCopy(rivalName, gSaveBlock1Ptr->rivalName);
#endif
    gDifferentSaveFile = TRUE;
    gSaveBlock2Ptr->encryptionKey = 0;
    ZeroPlayerPartyMons();
    ZeroEnemyPartyMons();
    ResetPokedex();
    ClearFrontierRecord();
    ClearSav1();
    ClearSav3();
    ClearAllMail();
    gSaveBlock2Ptr->specialSaveWarpFlags = 0;
    gSaveBlock2Ptr->gcnLinkFlags = 0;
#if ALL_REGIONS
    // Region merge: stamp the save format; intro-done / travel-pass bits and the
    // per-region var/flag banks default clear (SaveBlock3 zeroed by ClearSav3 above).
    gSaveBlock2Ptr->saveVersion = SAVE_FORMAT_VERSION;
#endif
    InitPlayerTrainerId();
    PlayTimeCounter_Reset();
    ClearPokedexFlags();
    InitEventData();
#if IS_FRLG || ALL_REGIONS
    VarSet(VAR_PLAYER_PALETTE, playerOutfit); // restore the intro outfit pick wiped by ClearSav1
#endif
    ClearTVShowData();
    ResetGabbyAndTy();
    ClearSecretBases();
    ClearBerryTrees();
    SetMoney(&gSaveBlock1Ptr->money, 3000);
    SetCoins(0);
    ResetLinkContestBoolean();
    ResetGameStats();
    ClearAllContestWinnerPics();
    ClearPlayerLinkBattleRecords();
    InitSeedotSizeRecord();
    InitLotadSizeRecord();
    gPartiesCount[B_TRAINER_PLAYER] = 0;
    ZeroPlayerPartyMons();
    ResetPokemonStorageSystem();
    DeactivateAllRoamers();
    gSaveBlock1Ptr->registeredItem = ITEM_NONE;
#if I_KEY_ITEM_WHEEL
    memset(gSaveBlock1Ptr->registeredItemsExtra, 0, sizeof(gSaveBlock1Ptr->registeredItemsExtra));
#endif //I_KEY_ITEM_WHEEL
    ClearBag();
    NewGameInitPCItems();
    ClearPokeblocks();
    ClearDecorationInventories();
    InitEasyChatPhrases();
    SetMauvilleOldMan();
    InitDewfordTrend();
    ResetFanClub();
    ResetLotteryCorner();
    UpdateDailySeed();
    WarpToTruck();
#if ALL_REGIONS
    // The hub flow leaves startRegion REGION_NONE at new game (a region is only chosen at
    // a hub attendant), so the old region-conditional resets never ran: Kanto's FRLG hide
    // flags stayed clear and its scene NPCs (Oak in Pallet, Bill, the rivals, ...) were
    // visible from the start. All three regions coexist in one save - run every region's
    // new-game reset unconditionally.
    RunScriptImmediately(EventScript_ResetAllMapFlags);
    RunScriptImmediately(EventScript_ResetAllMapFlagsFrlg);
    // Fixed per-region rival name (set above); restore for all regions (empty = Hoenn fallback).
    StringCopy(gSaveBlock1Ptr->rivalName, rivalName);
    // Playtest fixes: keep the decorative leftover objects hidden (H2); hide the Cherrygrove
    // rival until the Mr. Pokemon's-house script clears it (M3); hide the second Mr. Pokemon
    // object until the give-egg scene swaps it in (else both render at once - the "walked
    // over to himself" dup).
    FlagSet(FLAG_HIDE_JOHTO_DECOR);
    FlagSet(FLAG_HIDE_SILVER_CHERRYGROVE);
    FlagSet(FLAG_HIDE_MRPOKEMON);
#else
    if (IS_FRLG)
        RunScriptImmediately(EventScript_ResetAllMapFlagsFrlg);
    else
        RunScriptImmediately(EventScript_ResetAllMapFlags);
#if IS_FRLG
        StringCopy(gSaveBlock1Ptr->rivalName, rivalName);
#endif
#endif
    ResetMiniGamesRecords();
    InitUnionRoomChatRegisteredTexts();
    InitLilycoveLady();
    ResetAllApprenticeData();
    ClearRankingHallRecords();
    InitMatchCallCounters();
    ClearMysteryGift();
    WipeTrainerNameRecords();
    ResetTrainerHillResults();
    ResetTrainerTowerResults();
    ResetContestLinkResults();
#if QUEST_MENU
    QuestMenu_ResetMenuSaveData();
#endif
    SetCurrentDifficultyLevel(DIFFICULTY_NORMAL);
    ResetItemFlags();
    ResetDexNav();
    ClearFollowerNPCData();
}

static void ResetMiniGamesRecords(void)
{
    CpuFill16(0, &gSaveBlock2Ptr->berryCrush, sizeof(struct BerryCrush));
    SetBerryPowder(&gSaveBlock2Ptr->berryCrush.berryPowderAmount, 0);
    ResetPokemonJumpRecords();
    CpuFill16(0, &gSaveBlock2Ptr->berryPick, sizeof(struct BerryPickingResults));
}

static void ResetItemFlags(void)
{
#if OW_SHOW_ITEM_DESCRIPTIONS == OW_ITEM_DESCRIPTIONS_FIRST_TIME
    memset(&gSaveBlock3Ptr->itemFlags, 0, sizeof(gSaveBlock3Ptr->itemFlags));
#endif
}

static void ResetDexNav(void)
{
#if USE_DEXNAV_SEARCH_LEVELS == TRUE
    memset(gSaveBlock3Ptr->dexNavSearchLevels, 0, sizeof(gSaveBlock3Ptr->dexNavSearchLevels));
#endif
    gSaveBlock3Ptr->dexNavChain = 0;
}
