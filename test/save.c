#include "global.h"
#include "pokemon_storage_system.h"
#include "test/test.h"

// If you would like to ensure save compatibility, update the values below with those for your hack. You can find these through the debug menu.
// Please note that this simple check is not 100% foolproof, but should be able to catch most unintended shifts.
//
// PKMN-World: these were upstream's placeholders (SaveBlock1 15568 / SaveBlock3 4) until 2026-07-24,
// so two of the four assertions below failed and `make check` could never pass — the repo's only
// automated layout tripwire protected nothing, and a permanently red suite meant the ~1,500
// inherited battle tests gave no signal either. The values are now this fork's real sizes.
//
// Derived from `arm-none-eabi-nm --print-size pokemonworld.elf`, NOT hand-summed. Note that
// gSaveblock1/2 and gPokemonStorage are declared through the *ASLR wrappers (include/load_save.h),
// which append u8 aslr[SAVEBLOCK_MOVE_RANGE] = 128 bytes, so subtract 128 from what nm reports for
// those three. gSaveblock3 is a bare struct, so its nm size is exact.
//
// This is the natural home for the frozen-layout invariant CLAUDE.md calls untouchable: it is
// host-side, needs no emulator, and carries no save-safety risk. Any change here means a
// SAVE_FORMAT_VERSION bump and a migration ladder step in src/load_save.c.
// Updated again for save format v7 (2026-07-24): the bag/item-PC expansion grew SaveBlock1 by
// 796 B and the two FREE_MYSTERY_* reclaims gave back more than that, so SaveBlock1 SHRANK
// 15,836 -> 14,752. SaveBlock3 shrank 1,584 -> 1,232 because the 104-entry cleared-obstacle list
// (313 B) became a 512-bit field + table hash (68 B). SaveBlock2 and PokemonStorage are
// deliberately unchanged — the SaveBlock3 checksum reference was carved from SaveBlock2's
// existing 0x94 filler rather than appended, so the block keeps its upstream size.
#define T_SAVEBLOCK1_SIZE 14752
#define T_SAVEBLOCK2_SIZE 3884
#define T_SAVEBLOCK3_SIZE 1232
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
