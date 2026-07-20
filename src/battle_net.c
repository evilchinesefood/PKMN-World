#include "global.h"
#include "battle_net.h"
#include "event_data.h"
#include "difficulty.h"
#include "constants/items.h"
#include "constants/flags.h"
#include "constants/opponents.h"

// Battle Net (issue #5) Mega Economy P1: shard + signature mega-stone rewards on HARD gym /
// Elite Four / Champion rematch wins. Reached from data/scripts/battle_net.inc, which is called
// by the 41 rematch victory sites, each setting VAR_0x8004 to the defeated trainer id.
//
//  - Gated on DIFFICULTY_HARD: the 5 Hoenn league sites also fire on first clears.
//  - Shards pay out on every HARD rematch win (repeatable), colored by the leader's type line.
//  - A signature stone drops ONCE per leader (guarded by FLAG_BNET_STONE_BASE + n); the script
//    sets the guard flag only after a confirmed give, so a full bag stays reclaimable.
//  - Stone drops are THEMATIC type-matches (the issue assigns champions Mewtwonite X/Y though
//    no trainer fields Mewtwo); where possible the leader actually fields the mega's species.
//    ONE drop source per stone; starter stones and the leftovers are flagship-vendor-only (P2).
//  - beatenFlag + battleNetHardWins feed the P2 records board; the champion trio (only one of
//    the three rival ids is ever fought per save) shares one beaten identity.
//  - The trainer id is read from gSpecialVar_0x8004; post-battle globals are never touched
//    (ResetTrainerOpponentIds makes their lifetime unreliable).

#define STONE(n)  (FLAG_BNET_STONE_BASE + (n))
#define BEATEN(n) (FLAG_BNET_BEATEN_BASE + (n))

struct BattleNetReward
{
    u16 trainerId;
    u16 shardItem;
    u8  shardCount;
    u16 stone1;
    u16 stone2;     // ITEM_NONE except the Kanto champion trio (Mewtwonite X + Y)
    u16 stoneFlag;  // guard flag for stone1; stone2 uses stoneFlag + 1
    u16 beatenFlag; // records-board marker: won at least one HARD rematch
};

static const struct BattleNetReward sBattleNetRewards[] =
{
    // Hoenn gyms (1 shard)
    { TRAINER_ROXANNE_1,        ITEM_GREEN_SHARD,  1, ITEM_AGGRONITE,      ITEM_NONE, STONE(0),  BEATEN(0) },
    { TRAINER_BRAWLY_1,         ITEM_RED_SHARD,    1, ITEM_MEDICHAMITE,    ITEM_NONE, STONE(1),  BEATEN(1) },
    { TRAINER_WATTSON_1,        ITEM_YELLOW_SHARD, 1, ITEM_MANECTITE,      ITEM_NONE, STONE(2),  BEATEN(2) },
    { TRAINER_FLANNERY_1,       ITEM_RED_SHARD,    1, ITEM_CAMERUPTITE,    ITEM_NONE, STONE(3),  BEATEN(3) },
    { TRAINER_NORMAN_1,         ITEM_YELLOW_SHARD, 1, ITEM_KANGASKHANITE,  ITEM_NONE, STONE(4),  BEATEN(4) },
    { TRAINER_WINONA_1,         ITEM_BLUE_SHARD,   1, ITEM_ALTARIANITE,    ITEM_NONE, STONE(5),  BEATEN(5) },
    { TRAINER_TATE_AND_LIZA_1,  ITEM_YELLOW_SHARD, 1, ITEM_METAGROSSITE,   ITEM_NONE, STONE(6),  BEATEN(6) },
    { TRAINER_JUAN_1,           ITEM_BLUE_SHARD,   1, ITEM_SHARPEDONITE,   ITEM_NONE, STONE(7),  BEATEN(7) },
    // Hoenn Elite Four + Champion (2 shards)
    { TRAINER_SIDNEY,           ITEM_YELLOW_SHARD, 2, ITEM_TYRANITARITE,   ITEM_NONE, STONE(8),  BEATEN(8) },
    { TRAINER_PHOEBE,           ITEM_YELLOW_SHARD, 2, ITEM_BANETTITE,      ITEM_NONE, STONE(9),  BEATEN(9) },
    { TRAINER_GLACIA,           ITEM_BLUE_SHARD,   2, ITEM_GLALITITE,      ITEM_NONE, STONE(10), BEATEN(10) },
    { TRAINER_DRAKE,            ITEM_RED_SHARD,    2, ITEM_LATIOSITE,      ITEM_NONE, STONE(11), BEATEN(11) },
    { TRAINER_WALLACE,          ITEM_BLUE_SHARD,   2, ITEM_LATIASITE,      ITEM_NONE, STONE(12), BEATEN(12) },
    // Johto gyms (1 shard)
    { TRAINER_FALKNER_1,        ITEM_BLUE_SHARD,   1, ITEM_PIDGEOTITE,     ITEM_NONE, STONE(13), BEATEN(13) },
    { TRAINER_BUGSY_1,          ITEM_GREEN_SHARD,  1, ITEM_SCIZORITE,      ITEM_NONE, STONE(14), BEATEN(14) },
    { TRAINER_WHITNEY_1,        ITEM_YELLOW_SHARD, 1, ITEM_NONE,           ITEM_NONE, 0,         BEATEN(15) },
    { TRAINER_MORTY_1,          ITEM_YELLOW_SHARD, 1, ITEM_SABLENITE,      ITEM_NONE, STONE(15), BEATEN(16) },
    { TRAINER_CHUCK_1,          ITEM_RED_SHARD,    1, ITEM_HERACRONITE,    ITEM_NONE, STONE(16), BEATEN(17) },
    { TRAINER_JASMINE_1,        ITEM_YELLOW_SHARD, 1, ITEM_STEELIXITE,     ITEM_NONE, STONE(17), BEATEN(18) },
    { TRAINER_PRYCE_1,          ITEM_BLUE_SHARD,   1, ITEM_NONE,           ITEM_NONE, 0,         BEATEN(19) },
    { TRAINER_CLAIR_1,          ITEM_RED_SHARD,    1, ITEM_AMPHAROSITE,    ITEM_NONE, STONE(18), BEATEN(20) },
    // Johto Elite Four + Champion (2 shards)
    { TRAINER_WILL_2,           ITEM_YELLOW_SHARD, 2, ITEM_SLOWBRONITE,    ITEM_NONE, STONE(19), BEATEN(21) },
    { TRAINER_KOGA_2,           ITEM_YELLOW_SHARD, 2, ITEM_NONE,           ITEM_NONE, 0,         BEATEN(22) },
    { TRAINER_BRUNO_2,          ITEM_RED_SHARD,    2, ITEM_NONE,           ITEM_NONE, 0,         BEATEN(23) },
    { TRAINER_KAREN_2_JT,       ITEM_YELLOW_SHARD, 2, ITEM_ABSOLITE,       ITEM_NONE, STONE(20), BEATEN(24) },
    { TRAINER_LANCE_2,          ITEM_RED_SHARD,    2, ITEM_SALAMENCITE,    ITEM_NONE, STONE(21), BEATEN(25) },
    // Kanto gyms (1 shard)
    { TRAINER_LEADER_BROCK,     ITEM_GREEN_SHARD,  1, ITEM_AERODACTYLITE,  ITEM_NONE, STONE(22), BEATEN(26) },
    { TRAINER_LEADER_MISTY,     ITEM_BLUE_SHARD,   1, ITEM_GYARADOSITE,    ITEM_NONE, STONE(23), BEATEN(27) },
    { TRAINER_LEADER_LT_SURGE,  ITEM_YELLOW_SHARD, 1, ITEM_NONE,           ITEM_NONE, 0,         BEATEN(28) },
    { TRAINER_LEADER_ERIKA,     ITEM_GREEN_SHARD,  1, ITEM_NONE,           ITEM_NONE, 0,         BEATEN(29) },
    { TRAINER_LEADER_KOGA,      ITEM_GREEN_SHARD,  1, ITEM_BEEDRILLITE,    ITEM_NONE, STONE(24), BEATEN(30) },
    { TRAINER_LEADER_BLAINE,    ITEM_RED_SHARD,    1, ITEM_HOUNDOOMINITE,  ITEM_NONE, STONE(25), BEATEN(31) },
    { TRAINER_LEADER_SABRINA,   ITEM_YELLOW_SHARD, 1, ITEM_ALAKAZITE,      ITEM_NONE, STONE(26), BEATEN(32) },
    { TRAINER_LEADER_GIOVANNI,  ITEM_RED_SHARD,    1, ITEM_NONE,           ITEM_NONE, 0,         BEATEN(33) },
    // Kanto Elite Four (2 shards)
    { TRAINER_ELITE_FOUR_LORELEI_2, ITEM_BLUE_SHARD,   2, ITEM_NONE,       ITEM_NONE, 0,         BEATEN(34) },
    { TRAINER_ELITE_FOUR_AGATHA_2,  ITEM_YELLOW_SHARD, 2, ITEM_GENGARITE,  ITEM_NONE, STONE(27), BEATEN(35) },
    { TRAINER_ELITE_FOUR_BRUNO_2,   ITEM_RED_SHARD,    2, ITEM_NONE,       ITEM_NONE, 0,         BEATEN(36) },
    { TRAINER_ELITE_FOUR_LANCE_2,   ITEM_RED_SHARD,    2, ITEM_NONE,       ITEM_NONE, 0,         BEATEN(37) },
    // Kanto Champion rematch: starter-matched rival; only one of the three ids is ever fought
    // per save, so the trio shares the Mewtwonite X/Y guard pair STONE(28)/STONE(29) and one
    // beaten identity BEATEN(38).
    { TRAINER_CHAMPION_REMATCH_SQUIRTLE,   ITEM_BLUE_SHARD, 2, ITEM_MEWTWONITE_X, ITEM_MEWTWONITE_Y, STONE(28), BEATEN(38) },
    { TRAINER_CHAMPION_REMATCH_BULBASAUR,  ITEM_BLUE_SHARD, 2, ITEM_MEWTWONITE_X, ITEM_MEWTWONITE_Y, STONE(28), BEATEN(38) },
    { TRAINER_CHAMPION_REMATCH_CHARMANDER, ITEM_BLUE_SHARD, 2, ITEM_MEWTWONITE_X, ITEM_MEWTWONITE_Y, STONE(28), BEATEN(38) },
};

// Highest stone guard used is STONE(29) (Mewtwonite Y); the flag block reserves 32.
// Highest beaten marker is BEATEN(38); the block reserves 40.
STATIC_ASSERT(FLAG_BNET_STONE_BASE + 29 < FLAG_BNET_STONE_END, BattleNetStoneFlagsFit);
STATIC_ASSERT(FLAG_BNET_BEATEN_BASE + 38 < FLAG_BNET_BEATEN_END, BattleNetBeatenFlagsFit);

static u16 sPendingStoneFlag1;
static u16 sPendingStoneFlag2;

static const struct BattleNetReward *FindReward(u16 trainerId)
{
    u32 i;

    for (i = 0; i < ARRAY_COUNT(sBattleNetRewards); i++)
    {
        if (sBattleNetRewards[i].trainerId == trainerId)
            return &sBattleNetRewards[i];
    }
    return NULL;
}

// Outputs for data/scripts/battle_net.inc:
//   VAR_RESULT  = 1 if a reward is due (HARD win vs a known leader), else 0
//   VAR_0x8006  = shard item, VAR_0x8007 = shard count (given every qualifying win)
//   VAR_0x8008  = stone to give, or ITEM_NONE (already claimed / this leader has none)
//   VAR_0x8009  = second stone (champion trio only), or ITEM_NONE
void TryBattleNetRematchReward(void)
{
    const struct BattleNetReward *reward;

    sPendingStoneFlag1 = 0;
    sPendingStoneFlag2 = 0;
    gSpecialVar_0x8008 = ITEM_NONE;
    gSpecialVar_0x8009 = ITEM_NONE;

    if (GetCurrentDifficultyLevel() != DIFFICULTY_HARD)
    {
        gSpecialVar_Result = 0;
        return;
    }

    reward = FindReward(gSpecialVar_0x8004);
    if (reward == NULL)
    {
        gSpecialVar_Result = 0;
        return;
    }

    FlagSet(reward->beatenFlag);
    if (gSaveBlock2Ptr->frontier.battleNetHardWins < 0xFFFF)
        gSaveBlock2Ptr->frontier.battleNetHardWins++;

    gSpecialVar_0x8006 = reward->shardItem;
    gSpecialVar_0x8007 = reward->shardCount;

    if (reward->stone1 != ITEM_NONE && !FlagGet(reward->stoneFlag))
    {
        gSpecialVar_0x8008 = reward->stone1;
        sPendingStoneFlag1 = reward->stoneFlag;
    }
    if (reward->stone2 != ITEM_NONE && !FlagGet(reward->stoneFlag + 1))
    {
        gSpecialVar_0x8009 = reward->stone2;
        sPendingStoneFlag2 = reward->stoneFlag + 1;
    }

    gSpecialVar_Result = 1;
}

// Sets a signature-stone guard flag after the script confirms the give succeeded (a full bag
// leaves the flag unset so the stone can be reclaimed next win). VAR_0x8005 selects the stone
// (1 = stone1, 2 = stone2).
void ClaimBattleNetStone(void)
{
    if (gSpecialVar_0x8005 == 1 && sPendingStoneFlag1 != 0)
        FlagSet(sPendingStoneFlag1);
    else if (gSpecialVar_0x8005 == 2 && sPendingStoneFlag2 != 0)
        FlagSet(sPendingStoneFlag2);
}
