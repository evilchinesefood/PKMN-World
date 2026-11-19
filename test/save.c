#include "global.h"
#include "agb_flash.h"
#include "load_save.h"
#include "pokemon_storage_system.h"
#include "save.h"
#include "constants/flags.h"
#include "constants/maps.h"
#include "test/test.h"

static u32 IndexOfByteNotEqual(const void *buf, u8 value, u32 size)
{
    const u8 *bytes = buf;
    u32 i;

    for (i = 0; i < size; i++)
    {
        if (bytes[i] != value)
            return i;
    }
    return size;
}

static void WriteCraftedOutOfRangeIdSector(u16 flashSector)
{
    memset(&gSaveDataBuffer, 0xFF, sizeof(gSaveDataBuffer));
    gSaveDataBuffer.id = 0xFFFF;
    gSaveDataBuffer.signature = SECTOR_SIGNATURE;
    gSaveDataBuffer.checksum = 0;
    gSaveDataBuffer.counter = 0;
    ASSUME(ProgramFlashSectorAndVerify(flashSector, (u8 *)&gSaveDataBuffer) == 0);
}

// Slot 1 with every logical id present and an odd counter so CopySaveSlotData
// reads flash sectors 14-27 (save slot 2).
static void WriteValidSlot1WithOddCounter(void)
{
    u32 i;

    for (i = 0; i < NUM_SECTORS_PER_SLOT; i++)
    {
        memset(&gSaveDataBuffer, 0, sizeof(gSaveDataBuffer));
        gSaveDataBuffer.id = i;
        gSaveDataBuffer.signature = SECTOR_SIGNATURE;
        gSaveDataBuffer.counter = 1;
        gSaveDataBuffer.checksum = 0;
        ASSUME(ProgramFlashSectorAndVerify(i, (u8 *)&gSaveDataBuffer) == 0);
    }
}

// Pin the save ABI. SavePatch also reads these constants for its sector checks.
#define T_SAVEBLOCK1_SIZE 14752
#define T_SAVEBLOCK2_SIZE 3884
#define T_SAVEBLOCK3_SIZE 1408
#define T_POKEMONSTORAGE_SIZE 34144

TEST("SaveBlock1 is backwards compatible")
{
    EXPECT_EQ(sizeof(struct SaveBlock1), T_SAVEBLOCK1_SIZE);
}

TEST("SaveBlock2 is backwards compatible")
{
    EXPECT_EQ(sizeof(struct SaveBlock2), T_SAVEBLOCK2_SIZE);
}

TEST("SaveBlock3 is backwards compatible")
{
    EXPECT_EQ(sizeof(struct SaveBlock3), T_SAVEBLOCK3_SIZE);
}

TEST("PokemonStorage is backwards compatible")
{
    EXPECT_EQ(sizeof(struct PokemonStorage), T_POKEMONSTORAGE_SIZE);
}

#undef T_SAVEBLOCK1_SIZE
#undef T_SAVEBLOCK2_SIZE
#undef T_SAVEBLOCK3_SIZE
#undef T_POKEMONSTORAGE_SIZE

// A sector with SECTOR_SIGNATURE and id 0xFFFF used to index locations[] and
// 1 << id past gRamSaveSectorLocations (NUM_SECTORS_PER_SLOT == 14).
TEST("LoadGameSave ignores flash sectors with out-of-range ids")
{
    u32 slot = 0;

    PARAMETRIZE { slot = 0; } // GetSaveValidStatus + CopySaveSlotData on slot 1
    PARAMETRIZE { slot = 1; } // GetSaveValidStatus + CopySaveSlotData on slot 2

    if (!gFlashMemoryPresent)
        CheckForFlashMemory();
    ASSUME(gFlashMemoryPresent == TRUE);

    ClearSaveData();
    if (slot == 1)
        WriteValidSlot1WithOddCounter();
    WriteCraftedOutOfRangeIdSector(slot * NUM_SECTORS_PER_SLOT);
    if (slot == 0)
        WriteCraftedOutOfRangeIdSector(NUM_SECTORS_PER_SLOT);

    memset(gSaveBlock1Ptr, 0xA5, sizeof(struct SaveBlock1));
    memset(gSaveBlock2Ptr, 0x5A, sizeof(struct SaveBlock2));
    memset(gPokemonStoragePtr, 0x3C, sizeof(struct PokemonStorage));

    LoadGameSave(SAVE_NORMAL);

    EXPECT_EQ(IndexOfByteNotEqual(gSaveBlock1Ptr, 0xA5, sizeof(struct SaveBlock1)), sizeof(struct SaveBlock1));
    EXPECT_EQ(IndexOfByteNotEqual(gSaveBlock2Ptr, 0x5A, sizeof(struct SaveBlock2)), sizeof(struct SaveBlock2));
    EXPECT_EQ(IndexOfByteNotEqual(gPokemonStoragePtr, 0x3C, sizeof(struct PokemonStorage)), sizeof(struct PokemonStorage));
}

// Recreate the historical long SaveBlock1 tail using a nonzero word beyond
// today's final chunk. The same cartridge is then tested with a torn write,
// a duplicate ID, or a damaged checksum; none should receive a version verdict.
TEST("Save version refusal distinguishes intact older layouts from damaged slots")
{
    enum { INTACT, MIXED_COUNTER, DUPLICATE_ID, DAMAGED };
    const u32 flagOffset = offsetof(struct SaveBlock1, flags) + FLAG_QOL_SHARED_EXP / 8;
    const u8 flagMask = 1u << (FLAG_QOL_SHARED_EXP % 8);
    u32 version = 3, fault = INTACT, expected = SAVE_STATUS_EMPTY, reason = SAVE_VERSION_REFUSAL_TOO_OLD;
    PARAMETRIZE { }
    PARAMETRIZE { version = SAVE_FORMAT_VERSION - 1; }
    PARAMETRIZE { version = SAVE_FORMAT_VERSION + 1; reason = SAVE_VERSION_REFUSAL_TOO_NEW; }
    PARAMETRIZE { version = SAVE_FORMAT_VERSION; expected = SAVE_STATUS_OK; reason = SAVE_VERSION_REFUSAL_NONE; }
    PARAMETRIZE { fault = MIXED_COUNTER; expected = SAVE_STATUS_CORRUPT; reason = SAVE_VERSION_REFUSAL_NONE; }
    PARAMETRIZE { fault = DUPLICATE_ID; expected = SAVE_STATUS_CORRUPT; reason = SAVE_VERSION_REFUSAL_NONE; }
    PARAMETRIZE { fault = DAMAGED; expected = SAVE_STATUS_CORRUPT; reason = SAVE_VERSION_REFUSAL_NONE; }
    PARAMETRIZE { version = SAVE_FORMAT_VERSION; fault = DAMAGED; expected = SAVE_STATUS_CORRUPT; reason = SAVE_VERSION_REFUSAL_NONE; }

    if (!gFlashMemoryPresent)
        CheckForFlashMemory();
    ASSUME(gFlashMemoryPresent);
    ClearSaveData();
    for (u32 i = 0; i < NUM_SECTORS_PER_SLOT; i++)
    {
        memset(&gSaveDataBuffer, 0, sizeof(gSaveDataBuffer));
        gSaveDataBuffer.signature = SECTOR_SIGNATURE;
        gSaveDataBuffer.id = i;
        if (i == SECTOR_ID_SAVEBLOCK2)
        {
            gSaveDataBuffer.data[offsetof(struct SaveBlock2, saveVersion)] = version;
            gSaveDataBuffer.checksum = version << 8;
        }
        if (i == SECTOR_ID_SAVEBLOCK1_START + flagOffset / SECTOR_DATA_SIZE)
        {
            gSaveDataBuffer.data[flagOffset % SECTOR_DATA_SIZE] = flagMask;
            u32 word = (u32)flagMask << (8 * (flagOffset % 4));
            gSaveDataBuffer.checksum = word + (word >> 16);
        }
        if (version == 3 && i == SECTOR_ID_SAVEBLOCK1_END)
        {
            gSaveDataBuffer.data[SECTOR_DATA_SIZE - 4] = 1;
            gSaveDataBuffer.checksum = 1;
        }
        if (i == SECTOR_ID_PKMN_STORAGE_END)
        {
            if (fault == MIXED_COUNTER)
                gSaveDataBuffer.counter = 2;
            if (fault == DUPLICATE_ID)
                gSaveDataBuffer.id = SECTOR_ID_PKMN_STORAGE_START;
            if (fault == DAMAGED)
                gSaveDataBuffer.checksum++;
        }
        ASSUME(ProgramFlashSectorAndVerify(i, (u8 *)&gSaveDataBuffer) == 0);
    }
    EXPECT_EQ(LoadGameSave(SAVE_NORMAL), expected);
    EXPECT_EQ(gSaveVersionRefusal, reason);
    if (reason != SAVE_VERSION_REFUSAL_NONE || expected == SAVE_STATUS_OK)
        EXPECT_EQ(gSaveBlock1Ptr->flags[FLAG_QOL_SHARED_EXP / 8] & flagMask,
                  expected == SAVE_STATUS_OK ? flagMask : 0);
}
