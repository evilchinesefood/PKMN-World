#include "global.h"
#include "battle.h"
#include "debug.h"
#include "pokemon.h"
#include "test/test.h"

// The debug party actions mutate gParties and gPartiesCount independently of each
// other, so the invariant worth pinning is that the cached count always matches the
// slots that are actually populated.

TEST("Debug Set Party publishes the party count")
{
    Debug_SetPlayerDebugParty();
    EXPECT_NE(gPartiesCount[B_TRAINER_PLAYER], 0);
    EXPECT_EQ(gPartiesCount[B_TRAINER_PLAYER], CalculatePartyCount(B_TRAINER_PLAYER));
}

TEST("Debug Clear Party zeroes the party count")
{
    Debug_SetPlayerDebugParty();
    Debug_ClearPlayerDebugParty();
    EXPECT_EQ(gPartiesCount[B_TRAINER_PLAYER], 0);
    EXPECT_EQ(gPartiesCount[B_TRAINER_PLAYER], CalculatePartyCount(B_TRAINER_PLAYER));
}

TEST("Debug Set/Clear/Set round-trips the party count")
{
    Debug_SetPlayerDebugParty();
    u32 seeded = gPartiesCount[B_TRAINER_PLAYER];
    Debug_ClearPlayerDebugParty();
    EXPECT_EQ(gPartiesCount[B_TRAINER_PLAYER], 0);
    Debug_SetPlayerDebugParty();
    EXPECT_EQ(gPartiesCount[B_TRAINER_PLAYER], seeded);
    EXPECT_EQ(gPartiesCount[B_TRAINER_PLAYER], CalculatePartyCount(B_TRAINER_PLAYER));
}
