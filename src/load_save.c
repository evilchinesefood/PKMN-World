#include "global.h"
#include "malloc.h"
#include "berry_powder.h"
#include "fake_rtc.h"
#include "follower_npc.h"
#include "item.h"
#include "load_save.h"
#include "main.h"
#include "overworld.h"
#include "pokemon.h"
#include "pokemon_storage_system.h"
#include "random.h"
#include "save_location.h"
#include "script_pokemon_util.h"
#include "trainer_hill.h"
#include "wild_encounter_ow.h"
#include "gba/flash_internal.h"
#include "decoration_inventory.h"
#include "agb_flash.h"
#include "event_data.h"
#include "constants/event_objects.h"
#include "constants/regions.h"

static void ApplyNewEncryptionKeyToAllEncryptedData(u32 encryptionKey);

#define SAVEBLOCK_MOVE_RANGE    128

struct LoadedSaveData
{
 /*0x0000*/ struct Bag bag;
 /*0x02E8*/ struct Mail mail[MAIL_COUNT];
};

// EWRAM DATA
EWRAM_DATA struct SaveBlock3 gSaveblock3 = {};
EWRAM_DATA struct SaveBlock2ASLR gSaveblock2 = {0};
EWRAM_DATA struct SaveBlock1ASLR gSaveblock1 = {0};
EWRAM_DATA struct PokemonStorageASLR gPokemonStorage = {0};

EWRAM_DATA struct LoadedSaveData gLoadedSaveData = {0};
EWRAM_DATA u32 gLastEncryptionKey = 0;

// IWRAM common
COMMON_DATA bool32 gFlashMemoryPresent = 0;
COMMON_DATA struct SaveBlock1 *gSaveBlock1Ptr = NULL;
COMMON_DATA struct SaveBlock2 *gSaveBlock2Ptr = NULL;
IWRAM_INIT struct SaveBlock3 *gSaveBlock3Ptr = &gSaveblock3;
COMMON_DATA struct PokemonStorage *gPokemonStoragePtr = NULL;

// code

#if ALL_REGIONS
// v5 -> v6 Kanto var rebase (see include/constants/vars_frlg.h): every FRLG-unique story var
// on raw IDs 0x4025-0x408A moved from the shared SaveBlock1.vars pool (where it aliased a live
// Hoenn var) to the Kanto regionVars slice. oldId is the raw pre-v6 SaveBlock1 var ID; the
// macro name resolves to the var's new VAR_KANTO_SLICE ID.
static const struct { u16 oldId; u16 newId; } sKantoVarRebase[] = {
    { 0x4025, VAR_MASSAGE_COOLDOWN_STEP_COUNTER },
    { 0x4026, VAR_DEOXYS_INTERACTION_STEP_COUNTER },
    { 0x4027, VAR_QUEST_LOG_MON_COUNTS },
    { 0x4028, VAR_WONDER_NEWS_STEP_COUNTER_FRLG },
    { 0x4029, VAR_0x4029 },
    { 0x402A, VAR_0x402A },
    { 0x402B, VAR_0x402B },
    { 0x402C, VAR_DAYS_FRLG },
    { 0x402D, VAR_0x402D },
    { 0x402E, VAR_0x402E },
    { 0x402F, VAR_0x402F },
    { 0x4030, VAR_ICE_STEP_COUNT_FRLG },
    { 0x4031, VAR_STARTER_MON_FRLG },
    { 0x4032, VAR_RESET_RTC_ENABLE_FRLG },
    { 0x4033, VAR_ENIGMA_BERRY_AVAILABLE_FRLG },
    { 0x4034, VAR_0x4034 },
    { 0x4035, VAR_RESORT_GOREGEOUS_STEP_COUNTER },
    { 0x4036, VAR_RESORT_GORGEOUS_REQUESTED_MON },
    { 0x4037, VAR_PC_BOX_TO_SEND_MON_FRLG },
    { 0x4038, VAR_FANCLUB_FAN_COUNTER_FRLG },
    { 0x4039, VAR_FANCLUB_LOSE_FAN_TIMER_FRLG },
    { 0x403A, VAR_ELEVATOR_FLOOR },
    { 0x403B, VAR_RESORT_GORGEOUS_REWARD },
    { 0x403C, VAR_0x403C },
    { 0x403D, VAR_HERACROSS_SIZE_RECORD },
    { 0x403E, VAR_DEOXYS_INTERACTION_NUM },
    { 0x403F, VAR_0x403F },
    { 0x4040, VAR_MAGIKARP_SIZE_RECORD },
    { 0x4041, VAR_0x4041 },
    { 0x4042, VAR_TRAINER_CARD_MON_ICON_TINT_IDX },
    { 0x4043, VAR_TRAINER_CARD_MON_ICON_1 },
    { 0x4044, VAR_TRAINER_CARD_MON_ICON_2 },
    { 0x4045, VAR_TRAINER_CARD_MON_ICON_3 },
    { 0x4046, VAR_TRAINER_CARD_MON_ICON_4 },
    { 0x4047, VAR_TRAINER_CARD_MON_ICON_5 },
    { 0x4048, VAR_TRAINER_CARD_MON_ICON_6 },
    { 0x4049, VAR_HOF_BRAG_STATE },
    { 0x404A, VAR_EGG_BRAG_STATE },
    { 0x404B, VAR_LINK_WIN_BRAG_STATE },
    { 0x404D, VAR_QL_ENTRANCE },
    { 0x404E, VAR_NATIONAL_DEX_FRLG },
    { 0x4050, VAR_MAP_SCENE_PALLET_TOWN_OAK },
    { 0x4051, VAR_MAP_SCENE_VIRIDIAN_CITY_OLD_MAN },
    { 0x4052, VAR_MAP_SCENE_CERULEAN_CITY_RIVAL },
    { 0x4053, VAR_VERMILION_CITY_TICKET_CHECK_TRIGGER },
    { 0x4054, VAR_MAP_SCENE_ROUTE22 },
    { 0x4055, VAR_MAP_SCENE_PALLET_TOWN_PROFESSOR_OAKS_LAB },
    { 0x4056, VAR_MAP_SCENE_PALLET_TOWN_PLAYERS_HOUSE_2F },
    { 0x4057, VAR_MAP_SCENE_VIRIDIAN_CITY_MART },
    { 0x4058, VAR_MAP_SCENE_PALLET_TOWN_RIVALS_HOUSE },
    { 0x4059, VAR_MAP_SCENE_POKEMON_TOWER_6F },
    { 0x405A, VAR_MAP_SCENE_VIRIDIAN_CITY_GYM_DOOR },
    { 0x405B, VAR_MAP_SCENE_S_S_ANNE_2F_CORRIDOR },
    { 0x405C, VAR_MAP_SCENE_SILPH_CO_7F },
    { 0x405D, VAR_MAP_SCENE_POKEMON_TOWER_2F },
    { 0x405E, VAR_MAP_SCENE_ROUTE16 },
    { 0x405F, VAR_MAP_SCENE_ROUTE23 },
    { 0x4060, VAR_MAP_SCENE_SILPH_CO_11F },
    { 0x4061, VAR_MAP_SCENE_PEWTER_CITY_MUSEUM_1F },
    { 0x4062, VAR_MAP_SCENE_ROUTE5_ROUTE6_ROUTE7_ROUTE8_GATES },
    { 0x4063, VAR_MAP_SCENE_SEAFOAM_ISLANDS_B4F },
    { 0x4064, VAR_MAP_SCENE_VICTORY_ROAD_1F },
    { 0x4065, VAR_MAP_SCENE_VICTORY_ROAD_2F_BOULDER1 },
    { 0x4066, VAR_MAP_SCENE_VICTORY_ROAD_2F_BOULDER2 },
    { 0x4067, VAR_MAP_SCENE_VICTORY_ROAD_3F },
    { 0x4068, VAR_MAP_SCENE_POKEMON_LEAGUE },
    { 0x4069, VAR_MAP_SCENE_CINNABAR_ISLAND_POKEMON_LAB_EXPERIMENT_ROOM_WHICH_FOSSIL },
    { 0x406A, VAR_MAP_SCENE_CINNABAR_ISLAND_POKEMON_LAB_EXPERIMENT_ROOM_REVIVE_STATE },
    { 0x406B, VAR_MAP_SCENE_ROUTE24 },
    { 0x406C, VAR_MAP_SCENE_PEWTER_CITY },
    { 0x406D, VAR_0x406D },
    { 0x406E, VAR_MAP_SCENE_FUCHSIA_CITY_SAFARI_ZONE_ENTRANCE },
    { 0x406F, VAR_CABLE_CLUB_STATE_FRLG },
    { 0x4070, VAR_MAP_SCENE_PALLET_TOWN_SIGN_LADY },
    { 0x4071, VAR_MAP_SCENE_CINNABAR_ISLAND },
    { 0x4072, VAR_0x4072 },
    { 0x4073, VAR_MAP_SCENE_SAFFRON_CITY_POKEMON_TRAINER_FAN_CLUB },
    { 0x4074, VAR_MAP_SCENE_SEVEN_ISLAND_HOUSE_ROOM1 },
    { 0x4075, VAR_MAP_SCENE_ONE_ISLAND_HARBOR },
    { 0x4076, VAR_MAP_SCENE_ONE_ISLAND_POKEMON_CENTER_1F },
    { 0x4077, VAR_0x4077 },
    { 0x4078, VAR_MAP_SCENE_TWO_ISLAND },
    { 0x4079, VAR_MAP_SCENE_TWO_ISLAND_JOYFUL_GAME_CORNER },
    { 0x407A, VAR_0x407A },
    { 0x407B, VAR_MAP_SCENE_THREE_ISLAND },
    { 0x407C, VAR_MAP_SCENE_POKEMON_CENTER_TEALA },
    { 0x407D, VAR_MAP_SCENE_CERULEAN_CITY_ROCKET },
    { 0x407E, VAR_MAP_SCENE_VERMILION_CITY },
    { 0x407F, VAR_MAP_SCENE_MT_EMBER_EXTERIOR },
    { 0x4080, VAR_MAP_SCENE_ICEFALL_CAVE_BACK },
    { 0x4081, VAR_MAP_SCENE_SAFFRON_CITY_DOJO },
    { 0x4082, VAR_MAP_SCENE_TRAINER_TOWER },
    { 0x4083, VAR_MAP_SCENE_FIVE_ISLAND_LOST_CAVE_ROOM10 },
    { 0x4084, VAR_MAP_SCENE_FIVE_ISLAND_RESORT_GORGEOUS },
    { 0x4085, VAR_MAP_SCENE_INDIGO_PLATEAU_EXTERIOR },
    { 0x4086, VAR_MAP_SCENE_FOUR_ISLAND },
    { 0x4087, VAR_0x4087 },
    { 0x4088, VAR_MAP_SCENE_ROCKET_WAREHOUSE },
    { 0x4089, VAR_MAP_SCENE_SIX_ISLAND_POKEMON_CENTER_1F },
    { 0x408A, VAR_MAP_SCENE_CINNABAR_ISLAND_2 },
};

// Region-merge save-format migration (deep-review T20 / plan E4). Runs once from
// LoadGameSave(SAVE_NORMAL) after the save blocks are in RAM, only when the slot loaded OK.
//
// A source-version LADDER, not a blanket wipe: each step upgrades only the specific transition
// it handles, so bumping SAVE_FORMAT_VERSION later never nukes a newer save's real region
// progress. A save stamped newer than this build is left untouched (not down-migratable).
//
// The region-merge state (the dedicated, UN-checksummed SaveBlock3 regionVars/johtoFlags banks
// + the SaveBlock2 region bits) is younger than the core save; before it existed those bytes
// were uninitialised flash with no checksum to reject them. The inline Kanto flag bank in
// SaveBlock1.flags[] is deliberately NOT touched: it lives in CHECKSUMMED SaveBlock1 (so an
// OK-loading save's bytes are authentic - zero for a legacy Hoenn save) and is interleaved with
// the daily/champion/hidden-item flags, which must never be blanket-cleared.
//
// IMPORTANT: because the SaveBlock3 banks are un-checksummed, saveVersion is their ONLY
// integrity guard. If any region-bank size (or the SaveBlock2 region-bit offset) changes, you
// MUST bump SAVE_FORMAT_VERSION and add a ladder step below - the STATIC_ASSERTs enforce it.
void MigrateSaveFormatIfNeeded(void)
{
    u8 savedVersion = gSaveBlock2Ptr->saveVersion;

    // Current or newer format: leave untouched (don't rewrite fields an older binary can't read).
    if (savedVersion >= SAVE_FORMAT_VERSION)
        return;

    // v0 -> v1: pre-versioning save. Its region banks/bits are untrustworthy flash, so re-init
    // them to a clean Hoenn start. A legacy save is a completed-intro Hoenn playthrough, so
    // Hoenn's arrival intro is already done (else the Littleroot welcome cutscene re-fires on the
    // next visit home); Kanto and Johto are genuinely unvisited. Stamps saveVersion in RAM only.
    if (savedVersion < 1)
    {
        memset(gSaveBlock3Ptr->region.regionVars, 0, sizeof(gSaveBlock3Ptr->region.regionVars));
        memset(gSaveBlock3Ptr->region.johtoFlags, 0, sizeof(gSaveBlock3Ptr->region.johtoFlags));

        gSaveBlock2Ptr->currentRegion    = REGION_HOENN;
        gSaveBlock2Ptr->hoennIntroDone   = TRUE;
        gSaveBlock2Ptr->kantoIntroDone   = FALSE;
        gSaveBlock2Ptr->johtoIntroDone   = FALSE;
        gSaveBlock2Ptr->regionBitsUnused = 0;
    }
    // v1 -> v2: SaveBlock3.usmSaved (graphical start menu icon order) was appended after the
    // region banks; on older saves those bytes are uninitialised flash. Zero ONLY the new
    // field - v1 region-bank/bit semantics are untouched.
    if (savedVersion < 2)
        memset(&gSaveBlock3Ptr->region.usmSaved, 0, sizeof(gSaveBlock3Ptr->region.usmSaved));
    // v2 -> v3: SaveBlock3.kantoTrainerFlags (Kanto trainer defeat-flag bank, E5-1) was
    // appended after usmSaved; on older saves those bytes are uninitialised flash. Zero ONLY
    // the new bank - no Kanto trainer was beatable before v3, so "none defeated" is correct.
    if (savedVersion < 3)
        memset(gSaveBlock3Ptr->region.kantoTrainerFlags, 0, sizeof(gSaveBlock3Ptr->region.kantoTrainerFlags));
    // v3 -> v4: SaveBlock3.route5DayCareMon (FRLG Route 5 single-mon day care, E7-1) was
    // appended after kantoTrainerFlags; on older saves those bytes are uninitialised flash.
    // Zero ONLY the new field - an all-zero DaycareMon is an empty day care (no stored mon).
    if (savedVersion < 4)
        memset(&gSaveBlock3Ptr->region.route5DayCareMon, 0, sizeof(gSaveBlock3Ptr->region.route5DayCareMon));
    // v4 -> v5: SaveBlock3.clearedObstacleCount/clearedObstacles (persistent cut trees + smashed
    // rocks) were appended after route5DayCareMon; on older saves those bytes are uninitialised
    // flash. Zero the count so the cleared-obstacle set starts empty.
    if (savedVersion < 5)
        gSaveBlock3Ptr->region.clearedObstacleCount = 0;
    // v5 -> v6: the FRLG story vars were rebased from raw SaveBlock1.vars IDs (0x4025-0x408A,
    // where they aliased live Hoenn vars) onto the reserved Kanto regionVars slice. Copy each
    // moved var's old shared cell into its new slot - the cell value is the best available
    // (Kanto and Hoenn wrote it interleaved); Hoenn keeps the cell afterward. Skipped for v0
    // sources: their Kanto is genuinely unvisited and the cells hold pure Hoenn values, so the
    // freshly zeroed slice (v0 -> v1 above) is already correct.
    if (savedVersion >= 1 && savedVersion < 6)
    {
        u32 i;
        for (i = 0; i < ARRAY_COUNT(sKantoVarRebase); i++)
            gSaveBlock3Ptr->region.regionVars[sKantoVarRebase[i].newId - REGION_VARS_START]
                = gSaveBlock1Ptr->vars[sKantoVarRebase[i].oldId - VARS_START];
    }

    gSaveBlock2Ptr->saveVersion = SAVE_FORMAT_VERSION;
}

// The region-merge save banks are UN-checksummed; saveVersion is their only integrity guard.
// If any of these change, bump SAVE_FORMAT_VERSION and add a matching ladder step above.
STATIC_ASSERT(NUM_REGION_VARS == 384, RegionVarBankSizeChanged_BumpSaveFormatVersion);
STATIC_ASSERT(NUM_JOHTO_FLAG_BYTES == 128, JohtoFlagBankSizeChanged_BumpSaveFormatVersion);
STATIC_ASSERT(NUM_KANTO_TRAINER_FLAG_BYTES == 80, KantoTrainerFlagBankSizeChanged_BumpSaveFormatVersion);
// SaveBlock3 is append-only: a field inserted/reordered BEFORE the region banks (e.g. by toggling
// a prefix #if like QUEST_MENU) shifts every bank with no checksum to catch it. Pin the start.
// The banks now live in struct RegionSave (layout-neutral wrapper); regionVars is its first field,
// so pinning the wrapper at 0x20 pins regionVars at 0x20 exactly as before.
STATIC_ASSERT(offsetof(struct SaveBlock3, region) == 0x20, SaveBlock3RegionMoved_BumpSaveFormatVersion);
// "Append-only, never reorder" must be ENFORCED, not just a comment: the offsets below depend on
// sizeof(Usm_SavedItems)/sizeof(DaycareMon), so a field inserted/resized BETWEEN banks would shift
// every later un-checksummed bank silently. Pin every interior bank offset + the exact struct size
// (probe-verified with the repo CFLAGS); any change forces a SAVE_FORMAT_VERSION bump + ladder step.
STATIC_ASSERT(offsetof(struct RegionSave, regionVars) == 0, RegionSaveRegionVarsMoved_BumpSaveFormatVersion);
STATIC_ASSERT(offsetof(struct RegionSave, johtoFlags) == 768, RegionSaveJohtoFlagsMoved_BumpSaveFormatVersion);
STATIC_ASSERT(offsetof(struct RegionSave, usmSaved) == 896, RegionSaveUsmSavedMoved_BumpSaveFormatVersion);
STATIC_ASSERT(offsetof(struct RegionSave, kantoTrainerFlags) == 909, RegionSaveKantoTrainerFlagsMoved_BumpSaveFormatVersion);
STATIC_ASSERT(offsetof(struct RegionSave, route5DayCareMon) == 992, RegionSaveRoute5DayCareMonMoved_BumpSaveFormatVersion);
STATIC_ASSERT(offsetof(struct RegionSave, clearedObstacleCount) == 1132, RegionSaveClearedObstacleCountMoved_BumpSaveFormatVersion);
STATIC_ASSERT(sizeof(struct RegionSave) == 1552, RegionSaveSizeChanged_BumpSaveFormatVersion);
STATIC_ASSERT(offsetof(struct SaveBlock2, currentRegion) == 0x90, SaveBlock2RegionStateMoved_BumpSaveFormatVersion);
// The party-menu "Follow" chooser (e0d958f1) carved followerSlot from the SAME 0x90-0x97 filler as
// the region bytes above. Pin its offset so a later edit to those bytes - e.g. a 9th intro bit
// spilling the 0x92 bitfield into 0x93 - can't silently relocate/collide it and lose the chosen
// follower on load. followerSlot lives in checksummed SaveBlock2, so no SAVE_FORMAT_VERSION bump.
STATIC_ASSERT(offsetof(struct SaveBlock2, followerSlot) == 0x93, SaveBlock2FollowerSlotMoved);
#endif // ALL_REGIONS

void CheckForFlashMemory(void)
{
    if (!IdentifyFlash())
    {
        gFlashMemoryPresent = TRUE;
        InitFlashTimer();
    }
    else
    {
        gFlashMemoryPresent = FALSE;
    }
}

void ClearSav3(void)
{
    CpuFill16(0, &gSaveblock3, sizeof(struct SaveBlock3));
    FakeRtc_Reset();
}

void ClearSav2(void)
{
    CpuFill16(0, &gSaveblock2, sizeof(struct SaveBlock2ASLR));
}

void ClearSav1(void)
{
    CpuFill16(0, &gSaveblock1, sizeof(struct SaveBlock1ASLR));
}

// Offset is the sum of the trainer id bytes
void SetSaveBlocksPointers(u16 offset)
{
    struct SaveBlock1 **sav1_LocalVar = &gSaveBlock1Ptr;

    offset = (offset + Random()) & (SAVEBLOCK_MOVE_RANGE - 4);

    gSaveBlock2Ptr = (void *)(&gSaveblock2) + offset;
    *sav1_LocalVar = (void *)(&gSaveblock1) + offset;
    gPokemonStoragePtr = (void *)(&gPokemonStorage) + offset;

    SetBagItemsPointers();
    SetDecorationInventoriesPointers();
}

void MoveSaveBlocks_ResetHeap(void)
{
    void *vblankCB, *hblankCB;
    u32 encryptionKey;
    struct SaveBlock2 *saveBlock2Copy;
    struct SaveBlock1 *saveBlock1Copy;
    struct PokemonStorage *pokemonStorageCopy;

    // save interrupt functions and turn them off
    vblankCB = gMain.vblankCallback;
    hblankCB = gMain.hblankCallback;
    gMain.vblankCallback = NULL;
    gMain.hblankCallback = NULL;
    gTrainerHillVBlankCounter = NULL;

    saveBlock2Copy = (struct SaveBlock2 *)(gHeap);
    saveBlock1Copy = (struct SaveBlock1 *)(gHeap + sizeof(struct SaveBlock2));
    pokemonStorageCopy = (struct PokemonStorage *)(gHeap + sizeof(struct SaveBlock2) + sizeof(struct SaveBlock1));

    // backup the saves.
    *saveBlock2Copy = *gSaveBlock2Ptr;
    *saveBlock1Copy = *gSaveBlock1Ptr;
    *pokemonStorageCopy = *gPokemonStoragePtr;

    // change saveblocks' pointers
    // argument is a sum of the individual trainerId bytes
    SetSaveBlocksPointers(
      saveBlock2Copy->playerTrainerId[0] +
      saveBlock2Copy->playerTrainerId[1] +
      saveBlock2Copy->playerTrainerId[2] +
      saveBlock2Copy->playerTrainerId[3]);

    // restore saveblock data since the pointers changed
    *gSaveBlock2Ptr = *saveBlock2Copy;
    *gSaveBlock1Ptr = *saveBlock1Copy;
    *gPokemonStoragePtr = *pokemonStorageCopy;

    // heap was destroyed in the copying process, so reset it
    InitHeap(gHeap, HEAP_SIZE);

    // restore interrupt functions
    gMain.hblankCallback = hblankCB;
    gMain.vblankCallback = vblankCB;

    // create a new encryption key
    encryptionKey = Random32();
    ApplyNewEncryptionKeyToAllEncryptedData(encryptionKey);
    gSaveBlock2Ptr->encryptionKey = encryptionKey;
}

u32 UseContinueGameWarp(void)
{
    return gSaveBlock2Ptr->specialSaveWarpFlags & CONTINUE_GAME_WARP;
}

void ClearContinueGameWarpStatus(void)
{
    gSaveBlock2Ptr->specialSaveWarpFlags &= ~CONTINUE_GAME_WARP;
}

void SetContinueGameWarpStatus(void)
{
    gSaveBlock2Ptr->specialSaveWarpFlags |= CONTINUE_GAME_WARP;
}

void SetContinueGameWarpStatusToDynamicWarp(void)
{
    SetContinueGameWarpToDynamicWarp(0);
    gSaveBlock2Ptr->specialSaveWarpFlags |= CONTINUE_GAME_WARP;
}

void ClearContinueGameWarpStatus2(void)
{
    gSaveBlock2Ptr->specialSaveWarpFlags &= ~CONTINUE_GAME_WARP;
}

void SavePlayerParty(void)
{
    int i;
    *GetSavedPlayerPartyCount() = gPartiesCount[B_TRAINER_PLAYER];

    for (i = 0; i < PARTY_SIZE; i++)
        SavePlayerPartyMon(i, &gParties[B_TRAINER_PLAYER][i]);
}

void LoadPlayerParty(void)
{
    int i;

    gPartiesCount[B_TRAINER_PLAYER] = *GetSavedPlayerPartyCount();

    for (i = 0; i < PARTY_SIZE; i++)
    {
        u32 data;
        gParties[B_TRAINER_PLAYER][i] = *GetSavedPlayerPartyMon(i);

        // TODO: Turn this into a save migration once those are available.
        // At which point we can remove hp and status from Pokemon entirely.
        data = gParties[B_TRAINER_PLAYER][i].maxHP - gParties[B_TRAINER_PLAYER][i].hp;
        SetBoxMonData(&gParties[B_TRAINER_PLAYER][i].box, MON_DATA_HP_LOST, &data);
        data = gParties[B_TRAINER_PLAYER][i].status;
        SetBoxMonData(&gParties[B_TRAINER_PLAYER][i].box, MON_DATA_STATUS, &data);
    }
}

void SaveObjectEvents(void)
{
    int i;
    u16 graphicsId;

    for (i = 0; i < OBJECT_EVENTS_COUNT; i++)
    {
        gSaveBlock1Ptr->objectEvents[i] = gObjectEvents[i];
        // Swap graphicsId bytes when saving and loading
        // This keeps compatibility with vanilla,
        // since the lower graphicsIds will be in the same place as vanilla
        graphicsId = gObjectEvents[i].graphicsId;
        gSaveBlock1Ptr->objectEvents[i].graphicsId = (graphicsId >> 8) | (graphicsId << 8);
        gSaveBlock1Ptr->objectEvents[i].spriteId = 127; // magic number
        // To avoid crash on vanilla, save follower as inactive
        if (gObjectEvents[i].localId == OBJ_EVENT_ID_FOLLOWER)
            gSaveBlock1Ptr->objectEvents[i].active = FALSE;
    }
}

void LoadObjectEvents(void)
{
    int i;
    u16 graphicsId;

    for (i = 0; i < OBJECT_EVENTS_COUNT; i++)
    {
        gObjectEvents[i] = gSaveBlock1Ptr->objectEvents[i];
        // Swap graphicsId bytes when saving and loading
        // This keeps compatibility with vanilla,
        // since the lower graphicsIds will be in the same place as vanilla
        graphicsId = gObjectEvents[i].graphicsId;
        gObjectEvents[i].graphicsId = (graphicsId >> 8) | (graphicsId << 8);
        if (gObjectEvents[i].spriteId != 127)
            gObjectEvents[i].graphicsId &= 0xFF;
        gObjectEvents[i].spriteId = 0;
        // Try to restore saved inactive follower
        if (gObjectEvents[i].localId == OBJ_EVENT_ID_FOLLOWER &&
            !gObjectEvents[i].active &&
            gObjectEvents[i].graphicsId & OBJ_EVENT_MON)
            gObjectEvents[i].active = TRUE;
    }
    SetMinimumOWESpawnTimer();
}

void CopyPartyAndObjectsToSave(void)
{
    SavePlayerParty();
    SaveObjectEvents();
}

void CopyPartyAndObjectsFromSave(void)
{
    LoadPlayerParty();
    LoadObjectEvents();
}

void LoadPlayerBag(void)
{
    int i;

    // load player bag.
    memcpy(&gLoadedSaveData.bag, &gSaveBlock1Ptr->bag, sizeof(struct Bag));

    // load mail.
    for (i = 0; i < MAIL_COUNT; i++)
        gLoadedSaveData.mail[i] = gSaveBlock1Ptr->mail[i];

    gLastEncryptionKey = gSaveBlock2Ptr->encryptionKey;
}

void SavePlayerBag(void)
{
    int i;
    u32 encryptionKeyBackup;

    // save player bag.
    memcpy(&gSaveBlock1Ptr->bag, &gLoadedSaveData.bag, sizeof(struct Bag));

    // save mail.
    for (i = 0; i < MAIL_COUNT; i++)
        gSaveBlock1Ptr->mail[i] = gLoadedSaveData.mail[i];

    encryptionKeyBackup = gSaveBlock2Ptr->encryptionKey;
    gSaveBlock2Ptr->encryptionKey = gLastEncryptionKey;
    ApplyNewEncryptionKeyToBagItems(encryptionKeyBackup);
    gSaveBlock2Ptr->encryptionKey = encryptionKeyBackup; // updated twice?
}

void ApplyNewEncryptionKeyToHword(u16 *hWord, u32 newKey)
{
    *hWord ^= gSaveBlock2Ptr->encryptionKey;
    *hWord ^= newKey;
}

void ApplyNewEncryptionKeyToWord(u32 *word, u32 newKey)
{
    *word ^= gSaveBlock2Ptr->encryptionKey;
    *word ^= newKey;
}

static void ApplyNewEncryptionKeyToAllEncryptedData(u32 encryptionKey)
{
    ApplyNewEncryptionKeyToGameStats(encryptionKey);
    ApplyNewEncryptionKeyToBagItems(encryptionKey);
    ApplyNewEncryptionKeyToBerryPowder(encryptionKey);
    ApplyNewEncryptionKeyToWord(&gSaveBlock1Ptr->money, encryptionKey);
    ApplyNewEncryptionKeyToHword(&gSaveBlock1Ptr->coins, encryptionKey);
}
