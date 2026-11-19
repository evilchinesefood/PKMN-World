#include "global.h"
#include "regional_travel.h"
#include "malloc.h"
#include "berry_powder.h"
#include "fake_rtc.h"
#include "follower_npc.h"
#include "heal_location.h"
#include "item.h"
#include "load_save.h"
#include "text.h"
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
#include "constants/maps.h"
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

// Set on load when SaveBlock3's region banks fail their checksum. EWRAM, never saved.
EWRAM_DATA bool8 gRegionSaveCorrupt = FALSE;

EWRAM_DATA struct LoadedSaveData gLoadedSaveData = {0};
EWRAM_DATA u32 gLastEncryptionKey = 0;

// IWRAM common
COMMON_DATA bool32 gFlashMemoryPresent = 0;
COMMON_DATA struct SaveBlock1 *gSaveBlock1Ptr = NULL;
COMMON_DATA struct SaveBlock2 *gSaveBlock2Ptr = NULL;
IWRAM_INIT struct SaveBlock3 *gSaveBlock3Ptr = &gSaveblock3;
COMMON_DATA struct PokemonStorage *gPokemonStoragePtr = NULL;

// code

// Bind the saved obstacle bits to the generated table they were written under (issue #16).
//
// The bit index for a cut tree comes from tools/mapjson/GenObstacleTable.py's build-time enumeration of
// data/maps/, so adding or removing ANY obstacle renumbers every obstacle after it. Without this,
// a map edit would silently re-point saved bits at different trees — some regrowing, others
// pre-cleared, with nothing anywhere to explain it. Comparing the stored hash turns that into a
// single, understood event: after a map edit every obstacle regrows exactly once.
//
// Runs on load AND on new game, so a fresh save is stamped rather than left at hash 0.
void ResyncClearedObstacleTable(void)
{
    if (gSaveBlock3Ptr->region.obstacleTableHash == CLEARED_OBSTACLE_TABLE_HASH)
        return;
    memset(gSaveBlock3Ptr->region.clearedObstacleBits, 0,
           sizeof(gSaveBlock3Ptr->region.clearedObstacleBits));
    gSaveBlock3Ptr->region.obstacleTableHash = CLEARED_OBSTACLE_TABLE_HASH;
}

// --- SaveBlock3 integrity (issue #16) ---------------------------------------------------------
//
// The region banks are the only save state in the game with no checksum: HandleWriteSector()
// computes its checksum over the SaveBlock1/2/PokemonStorage chunk only, never over the
// saveBlock3Chunk riding along in the same sector (see struct SaveSector). saveVersion was their
// sole integrity guard, and a version stamp cannot detect a flipped bit.
//
// The reference value lives in SaveBlock2, which IS covered by the sector checksum — so a
// mismatch means SaveBlock3 drifted while its reference did not, rather than "one of the two is
// wrong and we cannot tell which".
static u16 RegionSaveChecksum(void)
{
    const u8 *p = (const u8 *)&gSaveBlock3Ptr->region;
    u32 i, sum = 0;

    for (i = 0; i < sizeof(struct RegionSave); i++)
        sum += p[i];
    return (u16)(sum + (sum >> 16));
}

void StampRegionSaveChecksum(void)
{
    gSaveBlock2Ptr->regionChecksum = RegionSaveChecksum();
}

// TRUE if SaveBlock3's region banks are intact. Deliberately NOT auto-repairing: the banks hold
// Johto/Kanto story progress, and blanket-zeroing a playthrough on a single flipped bit is worse
// than the corruption. The obstacle bits are the one part that is safely re-derivable, and
// ResyncClearedObstacleTable() already owns those. Callers surface it; they do not "fix" it.
bool32 VerifyRegionSaveChecksum(void)
{
    return gSaveBlock2Ptr->regionChecksum == RegionSaveChecksum();
}

// Layout changes require a save-format review.
STATIC_ASSERT(NUM_REGION_VARS == 384, RegionVarBankSizeChanged_BumpSaveFormatVersion);
STATIC_ASSERT(NUM_JOHTO_FLAG_BYTES == 128, JohtoFlagBankSizeChanged_BumpSaveFormatVersion);
STATIC_ASSERT(NUM_KANTO_TRAINER_FLAG_BYTES == 80, KantoTrainerFlagBankSizeChanged_BumpSaveFormatVersion);
STATIC_ASSERT(NUM_JOHTO_TRAINER_FLAG_BYTES == 32, JohtoTrainerFlagBankSizeChanged_BumpSaveFormatVersion);
// Nothing in the tree pinned either of these, yet the entire "one extra PC box costs 2,412 B"
// finding — the reason box count stays at 14 — rests on sizeof(struct BoxPokemon) being 80.
// If a field is ever added to a boxed mon, that arithmetic and every stored save silently change.
STATIC_ASSERT(sizeof(struct BoxPokemon) == 80, BoxPokemonSizeChanged_BumpSaveFormatVersion);
STATIC_ASSERT(sizeof(struct Pokemon) == 100, PokemonSizeChanged_BumpSaveFormatVersion);
// Keep the v14 region banks at their on-flash offset.
STATIC_ASSERT(offsetof(struct SaveBlock3, region) == 0x08, SaveBlock3RegionMoved_BumpSaveFormatVersion);
// "Append-only, never reorder" must be ENFORCED, not just a comment: the offsets below depend on
// sizeof(Usm_SavedItems)/sizeof(DaycareMon), so a field inserted/resized BETWEEN banks would shift
// every later un-checksummed bank silently. Pin every interior bank offset + the exact struct size
// (probe-verified with the repo CFLAGS); any change forces a SAVE_FORMAT_VERSION bump and a layout review.
STATIC_ASSERT(offsetof(struct RegionSave, regionVars) == 0, RegionSaveRegionVarsMoved_BumpSaveFormatVersion);
STATIC_ASSERT(offsetof(struct RegionSave, johtoFlags) == 768, RegionSaveJohtoFlagsMoved_BumpSaveFormatVersion);
STATIC_ASSERT(offsetof(struct RegionSave, usmSaved) == 896, RegionSaveUsmSavedMoved_BumpSaveFormatVersion);
STATIC_ASSERT(offsetof(struct RegionSave, kantoTrainerFlags) == 909, RegionSaveKantoTrainerFlagsMoved_BumpSaveFormatVersion);
STATIC_ASSERT(offsetof(struct RegionSave, route5DayCareMon) == 992, RegionSaveRoute5DayCareMonMoved_BumpSaveFormatVersion);
// v7 reshaped the tail: a u8 count + 104 {group,num,localId} triples became a u32 table hash + a
// 512-bit field, removing the 104 cap (the map data holds 293 obstacles) and shrinking
// sizeof(struct RegionSave) 1552 -> 1200, i.e. 352 bytes back to SaveBlock3.
STATIC_ASSERT(offsetof(struct RegionSave, obstacleTableHash) == 1132, RegionSaveObstacleHashMoved_BumpSaveFormatVersion);
STATIC_ASSERT(offsetof(struct RegionSave, clearedObstacleBits) == 1136, RegionSaveObstacleBitsMoved_BumpSaveFormatVersion);
STATIC_ASSERT(offsetof(struct RegionSave, johtoTrainerFlags) == 1200, RegionSaveJohtoTrainerFlagsMoved_BumpSaveFormatVersion);
STATIC_ASSERT(offsetof(struct RegionSave, regionalTravel) == 1232, RegionalTravelOffset);
STATIC_ASSERT(sizeof(struct RegionSave) == 1400, RegionSaveSizeChanged_BumpSaveFormatVersion);
// Every obstacle in the map data must have a bit. GenObstacleTable.py refuses to emit a table
// larger than the slot count, but pin it here too so a hand-edited header cannot slip past.
STATIC_ASSERT(CLEARED_OBSTACLE_COUNT <= CLEARED_OBSTACLE_SLOTS, ClearedObstacleTableExceedsReservedBits);
STATIC_ASSERT(offsetof(struct SaveBlock2, currentRegion) == 0x90, SaveBlock2RegionStateMoved_BumpSaveFormatVersion);
STATIC_ASSERT(offsetof(struct SaveBlock2, saveVersion) == 0x91, SaveVersionOffsetMustSurviveLayoutChanges);
// The party-menu "Follow" chooser (e0d958f1) carved followerSlot from the SAME 0x90-0x97 filler as
// the region bytes above. Pin its offset so a later edit to those bytes - e.g. a 9th intro bit
// spilling the 0x92 bitfield into 0x93 - can't silently relocate/collide it and lose the chosen
// follower on load. followerSlot lives in checksummed SaveBlock2, so no SAVE_FORMAT_VERSION bump.
STATIC_ASSERT(offsetof(struct SaveBlock2, followerSlot) == 0x93, SaveBlock2FollowerSlotMoved);
// Same reserve, same reasoning: regionChecksum is the integrity reference for the un-checksummed
// SaveBlock3 banks, so if it silently relocated the checksum would compare against garbage and
// every load would report the banks corrupt.
STATIC_ASSERT(offsetof(struct SaveBlock2, regionChecksum) == 0x94, SaveBlock2RegionChecksumMoved);

// The three SaveBlock1 banks the BizHawk/Lua suites read. These used to be hand-typed numbers in
// test/overworld/GenLuaSymbols.py's curated table, and they ROTTED: save format v7 reshaped SaveBlock1
// (bag/pcItems capacities grew) and pushed flags 4728 -> 5524 and vars 5246 -> 6042, but the
// generator kept emitting the pre-v7 values. A wrong offset here does not crash and does not read
// back as an error - FlagGet-style reads just land in neighbouring save data, so a suite that sets
// a flag and reads it back agrees with itself while the game sees nothing. That is a suite
// reporting green having proved nothing, and it is exactly the failure the SaveBlock3 asserts
// above were added to prevent. Pinned here so the generator can derive them and the BUILD fails
// on drift instead of the harness silently lying.
STATIC_ASSERT(offsetof(struct SaveBlock1, flags) == 5524, SaveBlock1FlagsMoved_RegenLuaSymbols);
STATIC_ASSERT(offsetof(struct SaveBlock1, vars) == 6042, SaveBlock1VarsMoved_RegenLuaSymbols);
STATIC_ASSERT(offsetof(struct SaveBlock1, money) == 1168, SaveBlock1MoneyMoved_RegenLuaSymbols);
// NewGameOverSave.lua decrypts the game stats (XORed with the roaming encryption key) before it
// compares save images. Probe-verified with the repo CFLAGS.
STATIC_ASSERT(offsetof(struct SaveBlock1, gameStats) == 6556, SaveBlock1GameStatsMoved_RegenLuaSymbols);
// #163: the berry-tree suite reads this bank directly to prove the nine Johto trees that used to
// share slots 92-100 through the johto_compat.h aliases now own 113-121. Probe-verified with the
// repo CFLAGS (-mabi=apcs-gnu -march=armv4t); sizeof(struct BerryTree) is 8, so slot N is at
// berryTrees + 8*N.
STATIC_ASSERT(offsetof(struct SaveBlock1, berryTrees) == 6812, SaveBlock1BerryTreesMoved_RegenLuaSymbols);
STATIC_ASSERT(sizeof(struct BerryTree) == 8, BerryTreeSizeChanged_RegenLuaSymbols);
// #203: DaycareFullPartyEgg.lua RAM-stuffs the daycare bank to force the "no room for the egg"
// branch. It hardcoded 0x3434 while global.h's comment said /*0x3030*/, and nothing pinned either
// number. Probe-verified under the repo CFLAGS (-mabi=apcs-gnu -march=armv4t) against the two
// asserts above as controls: the probe reproduces flags == 5524 and berryTrees == 6812 exactly, so
// its daycare answer is trustworthy - 13364 (0x3434). The Lua constant was right and the header
// comment was the stale one; the comments have been corrected. Pinned so the next SaveBlock1
// insert breaks the BUILD instead of letting the suite stuff a neighbouring field and still pass.
STATIC_ASSERT(offsetof(struct SaveBlock1, daycare) == 13364, SaveBlock1DaycareMoved_RegenLuaSymbols);
// RegionalRecallMail.lua writes and reads Mail records here. Probe-verified under the repo CFLAGS.
STATIC_ASSERT(offsetof(struct SaveBlock1, mail) == 12260, SaveBlock1MailMoved_RegenLuaSymbols);
// ResortGorgeousRequest.lua seeds the seen Pokedex here. Probe-verified under the repo CFLAGS.
STATIC_ASSERT(offsetof(struct SaveBlock1, dexSeen) == 13900, SaveBlock1DexSeenMoved_RegenLuaSymbols);
// DiplomaRegionName.lua seeds the caught Pokedex here. Probe-verified under the repo CFLAGS.
STATIC_ASSERT(offsetof(struct SaveBlock1, dexCaught) == 14029, SaveBlock1DexCaughtMoved_RegenLuaSymbols);
// RoamerParkRelease.lua reads the roamer slots here. Probe-verified under the repo CFLAGS.
STATIC_ASSERT(offsetof(struct SaveBlock1, roamer) == 13792, SaveBlock1RoamerMoved_RegenLuaSymbols);
// PokeblockFeedScene.lua writes the Pokeblock Case here. Probe-verified under the repo CFLAGS.
STATIC_ASSERT(offsetof(struct SaveBlock1, pokeblocks) == 2924, SaveBlock1PokeblocksMoved_RegenLuaSymbols);
// PalaceLobbyCancel.lua reads the party SavePlayerParty keeps here to prove it is stale.
STATIC_ASSERT(offsetof(struct SaveBlock1, playerPartyCount) == 564, SaveBlock1PlayerPartyCountMoved_RegenLuaSymbols);
STATIC_ASSERT(offsetof(struct SaveBlock1, playerParty) == 568, SaveBlock1PlayerPartyMoved_RegenLuaSymbols);

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
    ForgetAllTextPrinters();

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
    // Checksummed but not validated: a crafted/corrupt save can carry up to 255 here, and
    // every fork loop that trusts the count (battle_net, pokevial) walks past the party row.
    if (gPartiesCount[B_TRAINER_PLAYER] > PARTY_SIZE)
        gPartiesCount[B_TRAINER_PLAYER] = PARTY_SIZE;

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
    // Every save path in src/save.c funnels through here, which makes it the one place a
    // SaveBlock3 checksum can be stamped without chasing each write entry point individually.
    // It must run BEFORE the sectors are written, which is exactly where this sits.
    StampRegionSaveChecksum();
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
