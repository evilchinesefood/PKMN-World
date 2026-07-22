#include "global.h"
#include "battle_net.h"
#include "battle.h"
#include "battle_main.h"
#include "battle_setup.h"
#include "battle_frontier.h"
#include "battle_transition.h"
#include "event_data.h"
#include "difficulty.h"
#include "item.h"
#include "main.h"
#include "overworld.h"
#include "random.h"
#include "string_util.h"
#include "task.h"
#include "tv.h"
#include "constants/battle_net.h"
#include "constants/items.h"
#include "constants/flags.h"
#include "constants/opponents.h"
#include "constants/battle_frontier.h"

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

// ---------------------------------------------------------------------------
// P2: flagship floor (RegionHub_2F).
//
// The menus are script-level `multichoice`, NOT specials. A menu opened from a special is
// asynchronous, so the script would read VAR_RESULT before the player ever chose. These
// specials therefore do pure data work only; each *FromChoice mapper turns the index the
// script's multichoice left in VAR_RESULT into concrete items.
//
// Index order below is load-bearing: it must match MultichoiceList_Bnet* in
// src/data/script_menu.h exactly.
// ---------------------------------------------------------------------------

#define SHARD_PRICE_COMMON 20
#define SHARD_PRICE_STRONG 35
#define BP_PER_SHARD        4

// Greedy deduction order; also the shard-color menu order.
static const u16 sShardItems[] = { ITEM_RED_SHARD, ITEM_BLUE_SHARD, ITEM_YELLOW_SHARD, ITEM_GREEN_SHARD };

static const u16 sStarterStones[] =
{
    ITEM_VENUSAURITE, ITEM_CHARIZARDITE_X, ITEM_CHARIZARDITE_Y, ITEM_BLASTOISINITE,
    ITEM_SCEPTILITE,  ITEM_BLAZIKENITE,    ITEM_SWAMPERTITE,
};

static const struct { u16 item; u16 price; } sVendorStones[] =
{
    { ITEM_VENUSAURITE,    SHARD_PRICE_STRONG }, { ITEM_CHARIZARDITE_X, SHARD_PRICE_STRONG },
    { ITEM_CHARIZARDITE_Y, SHARD_PRICE_STRONG }, { ITEM_BLASTOISINITE,  SHARD_PRICE_STRONG },
    { ITEM_SCEPTILITE,     SHARD_PRICE_STRONG }, { ITEM_BLAZIKENITE,    SHARD_PRICE_STRONG },
    { ITEM_SWAMPERTITE,    SHARD_PRICE_STRONG }, { ITEM_GARDEVOIRITE,   SHARD_PRICE_STRONG },
    { ITEM_PINSIRITE,      SHARD_PRICE_COMMON }, { ITEM_MAWILITE,       SHARD_PRICE_COMMON },
};

STATIC_ASSERT(ARRAY_COUNT(sStarterStones) == 7, BattleNetStarterStoneCount);
STATIC_ASSERT(ARRAY_COUNT(sVendorStones) == 10, BattleNetVendorStoneCount);

// VAR_RESULT in = menu index; out = 1 picked / 0 cancelled. VAR_0x8008 = stone.
void BattleNetStarterStoneFromChoice(void)
{
    u32 choice = gSpecialVar_Result;

    gSpecialVar_0x8008 = ITEM_NONE;
    if (choice >= ARRAY_COUNT(sStarterStones))  // covers the Exit row and MULTI_B_PRESSED
    {
        gSpecialVar_Result = 0;
        return;
    }
    gSpecialVar_0x8008 = sStarterStones[choice];
    gSpecialVar_Result = 1;
}

// VAR_RESULT in = menu index; out = 1 picked / 0 cancelled.
// VAR_0x8008 = stone, VAR_0x8009 = price in shards.
void BattleNetVendorStoneFromChoice(void)
{
    u32 choice = gSpecialVar_Result;

    gSpecialVar_0x8008 = ITEM_NONE;
    gSpecialVar_0x8009 = 0;
    if (choice >= ARRAY_COUNT(sVendorStones))
    {
        gSpecialVar_Result = 0;
        return;
    }
    gSpecialVar_0x8008 = sVendorStones[choice].item;
    gSpecialVar_0x8009 = sVendorStones[choice].price;
    gSpecialVar_Result = 1;
}

// VAR_RESULT in = menu index; out = 1 picked / 0 cancelled. VAR_0x8008 = shard item.
void BattleNetShardColorFromChoice(void)
{
    u32 choice = gSpecialVar_Result;

    gSpecialVar_0x8008 = ITEM_NONE;
    if (choice >= ARRAY_COUNT(sShardItems))
    {
        gSpecialVar_Result = 0;
        return;
    }
    gSpecialVar_0x8008 = sShardItems[choice];
    gSpecialVar_Result = 1;
}

// VAR_RESULT = total shards held across all four colors (saturated at 0xFFFF).
void GetBattleNetShardCount(void)
{
    u32 i, total = 0;

    for (i = 0; i < ARRAY_COUNT(sShardItems); i++)
        total += CountTotalItemQuantityInBag(sShardItems[i]);

    gSpecialVar_Result = (total > 0xFFFF) ? 0xFFFF : total;
}

// Removes VAR_0x8009 shards total, greedily in sShardItems order. The script must confirm
// affordability with GetBattleNetShardCount first; this bails out rather than over-removing.
void DeductBattleNetShards(void)
{
    u32 i;
    u32 owed = gSpecialVar_0x8009;

    for (i = 0; i < ARRAY_COUNT(sShardItems) && owed != 0; i++)
    {
        u32 have = CountTotalItemQuantityInBag(sShardItems[i]);
        u32 take = (have < owed) ? have : owed;

        if (take != 0 && RemoveBagItem(sShardItems[i], take))
            owed -= take;
    }
    gSpecialVar_Result = (owed == 0);
}

// VAR_RESULT = 1 if BP_PER_SHARD battle points were deducted, else 0. Guarded so the
// unsigned subtraction can never wrap.
void TryBuyBattleNetShard(void)
{
    if (gSaveBlock2Ptr->frontier.battlePoints < BP_PER_SHARD)
    {
        gSpecialVar_Result = 0;
        return;
    }
    gSaveBlock2Ptr->frontier.battlePoints -= BP_PER_SHARD;
    gSpecialVar_Result = 1;
}

// STR_VAR_1 = total HARD rematch wins, STR_VAR_2 = distinct leaders bested,
// STR_VAR_3 = signature stones claimed.
void BufferBattleNetRecords(void)
{
    u32 i, beaten = 0, stones = 0;

    for (i = 0; i < 39; i++)
    {
        if (FlagGet(FLAG_BNET_BEATEN_BASE + i))
            beaten++;
    }
    for (i = 0; i < 30; i++)
    {
        if (FlagGet(FLAG_BNET_STONE_BASE + i))
            stones++;
    }

    ConvertIntToDecimalStringN(gStringVar1, gSaveBlock2Ptr->frontier.battleNetHardWins, STR_CONV_MODE_LEFT_ALIGN, 5);
    ConvertIntToDecimalStringN(gStringVar2, beaten, STR_CONV_MODE_LEFT_ALIGN, 2);
    ConvertIntToDecimalStringN(gStringVar3, stones, STR_CONV_MODE_LEFT_ALIGN, 2);
}

// ---------------------------------------------------------------------------
// P3: battle modes (Scaling Type Trainer, Leader Sim support, Tower Streak,
// ruleset rooms). Sim battles replicate the Battle Tower launch flow
// (battle_frontier.c DoFacilityTrainerBattleInternal): BATTLE_TYPE_BATTLE_TOWER
// means "the enemy party is already filled" (no exp/money, no whiteout, clean
// return to the calling script after its waitstate). The end handler and start
// task are replicated here because battle_frontier.c's are static.
//
// The Leader Sim itself is plain trainerbattle_no_intro from battle_net.inc
// (real gTrainers HARD parties); only its BP payout comes through here.
// ---------------------------------------------------------------------------

// Menu ordinal (0..17) -> type. Keep in the same order as the three
// MultichoiceList_BnetType* pages in src/data/script_menu.h (6 per page).
static const u8 sBnetTypes[] =
{
    TYPE_NORMAL,   TYPE_FIGHTING, TYPE_FLYING,  TYPE_POISON, TYPE_GROUND, TYPE_ROCK,
    TYPE_BUG,      TYPE_GHOST,    TYPE_STEEL,   TYPE_FIRE,   TYPE_WATER,  TYPE_GRASS,
    TYPE_ELECTRIC, TYPE_PSYCHIC,  TYPE_ICE,     TYPE_DRAGON, TYPE_DARK,   TYPE_FAIRY,
};

STATIC_ASSERT(ARRAY_COUNT(sBnetTypes) == 18, BattleNetTypeMenuCount);

// Marks every species 1..386 that has a Gen 1-3 pre-evolution (a bit per id).
// One pass over the evolution tables instead of GetSpeciesPreEvolution per
// candidate (that helper scans ALL species per call - the O(n^2) trap).
static void BnetMarkPreEvos(u8 *mark)
{
    u32 s, j;

    for (s = 1; s <= SPECIES_DEOXYS; s++)
    {
        const struct Evolution *evos;

        if (!IsSpeciesEnabled(s))
            continue;
        evos = GetSpeciesEvolutions(s);
        if (evos == NULL)
            continue;
        for (j = 0; evos[j].method != EVOLUTIONS_END; j++)
        {
            u32 t = evos[j].targetSpecies;

            if (t >= 1 && t <= SPECIES_DEOXYS)
                mark[t / 8] |= 1 << (t % 8);
        }
    }
}

// Can still evolve into something that exists in this game (Gen 1-3 strip aware):
// Aipom (Ambipom disabled) is a dead end here, so it is NOT Little Cup material.
static bool32 BnetCanEvolve(u32 species)
{
    const struct Evolution *evos = GetSpeciesEvolutions(species);
    u32 j;

    if (evos == NULL)
        return FALSE;
    for (j = 0; evos[j].method != EVOLUTIONS_END; j++)
    {
        if (IsSpeciesEnabled(evos[j].targetSpecies))
            return TRUE;
    }
    return FALSE;
}

static bool32 BnetIsLittleCup(u32 species, const u8 *preEvoMark)
{
    if (species == 0 || species > SPECIES_DEOXYS)
        return FALSE;
    if (preEvoMark[species / 8] & (1 << (species % 8)))
        return FALSE;
    return BnetCanEvolve(species);
}

// Opponent pool filter. Iterating ids 1..SPECIES_DEOXYS keeps it to Gen 1-3 base
// forms (base-form ids follow the National Dex through 386). IsSpeciesEnabled is
// NOT Gen 1-3 proof on its own, but the id bound is.
static bool32 BnetPoolAccept(u32 species, u32 mode, u32 type, const u8 *preEvoMark)
{
    const struct SpeciesInfo *info = &gSpeciesInfo[species];

    if (!IsSpeciesEnabled(species))
        return FALSE;
    if (info->isFrontierBanned || info->isRestrictedLegendary || info->isSubLegendary || info->isMythical)
        return FALSE;
    if (mode == BNET_MODE_LC && !BnetIsLittleCup(species, preEvoMark))
        return FALSE;
    if ((mode == BNET_MODE_SCALING || mode == BNET_MODE_STREAK || mode == BNET_MODE_MONOTYPE)
     && type != TYPE_NONE && info->types[0] != type && info->types[1] != type)
        return FALSE;
    return TRUE;
}

static u32 BnetCountUsableMons(void)
{
    u32 i, usable = 0;

    for (i = 0; i < gPartiesCount[B_TRAINER_PLAYER]; i++)
    {
        if (GetMonData(&gParties[B_TRAINER_PLAYER][i], MON_DATA_SPECIES) != SPECIES_NONE
         && !GetMonData(&gParties[B_TRAINER_PLAYER][i], MON_DATA_IS_EGG))
            usable++;
    }
    return usable;
}

static u32 BnetAvgPartyLevel(void)
{
    u32 i, total = 0, mons = 0;

    for (i = 0; i < gPartiesCount[B_TRAINER_PLAYER]; i++)
    {
        if (GetMonData(&gParties[B_TRAINER_PLAYER][i], MON_DATA_SPECIES) != SPECIES_NONE
         && !GetMonData(&gParties[B_TRAINER_PLAYER][i], MON_DATA_IS_EGG))
        {
            total += GetMonData(&gParties[B_TRAINER_PLAYER][i], MON_DATA_LEVEL);
            mons++;
        }
    }
    return mons != 0 ? total / mons : 5;
}

static void BnetHandleBattleEnd(void)
{
    // Clear the sim marker (0xFF = battle_special.c's "no special battle" idiom). The engine
    // PRESERVES specialTrainerBattleType across battles, and recorded Battle Tower playback
    // sets TRAINER|BATTLE_TOWER|RECORDED without writing it - a stale marker would make
    // IsBattleNetSimBattle() true mid-replay and award EXP inside a Battle Video. This
    // handler runs via gMain.savedCallback AFTER TryEvolvePokemon, so sim evolutions and
    // both read sites (getexp is mid-battle) have already happened.
    gBattleScripting.specialTrainerBattleType = 0xFF;
    SetMainCallback2(CB2_ReturnToFieldContinueScriptPlayMapMusic);
}

// TRUE while a Battle Net sim battle is running (issue #15). All three conditions on
// purpose: real facility launches always overwrite the marker with their FACILITY_* id,
// BnetHandleBattleEnd clears it after every sim, and the link/recorded exclusions keep a
// Battle Video replay or a link tower battle (both TRAINER|BATTLE_TOWER shaped, neither
// writes the marker) from ever counting as a sim. battle_script_commands.c (exp) and
// battle_main.c (evolutions) carve sims out of the no-EXP tower rules with this; money
// stays suppressed, sims pay BP.
bool32 IsBattleNetSimBattle(void)
{
    return (gBattleTypeFlags & BATTLE_TYPE_BATTLE_TOWER)
        && !(gBattleTypeFlags & (BATTLE_TYPE_LINK | BATTLE_TYPE_RECORDED | BATTLE_TYPE_RECORDED_LINK))
        && gBattleScripting.specialTrainerBattleType == SPECIAL_BATTLE_BNET_SIM;
}

static void Task_BnetStartBattle(u8 taskId)
{
    if (IsBattleTransitionDone() == TRUE)
    {
        gMain.savedCallback = BnetHandleBattleEnd;
        SetMainCallback2(CB2_InitBattle);
        DestroyTask(taskId);
    }
}

// VAR_0x8004 = BNET_MODE_*, VAR_0x8005 = type ordinal (SCALING/MONOTYPE).
// VAR_RESULT = 1 -> battle launched, the script MUST waitstate; 0 -> refused
// (no usable mon / empty pool), no battle was started so do NOT waitstate.
void DoBattleNetSimBattle(void)
{
    u32 mode = gSpecialVar_0x8004;
    u32 type = TYPE_NONE;
    u32 i, s, count, level, pool, idx, otID;
    u16 picked[4];
    u8 preEvoMark[SPECIES_DEOXYS / 8 + 1] = {0};

    if (BnetCountUsableMons() == 0)
    {
        gSpecialVar_Result = 0;
        return;
    }

    if (mode == BNET_MODE_SCALING || mode == BNET_MODE_MONOTYPE)
        type = sBnetTypes[gSpecialVar_0x8005 < ARRAY_COUNT(sBnetTypes) ? gSpecialVar_0x8005 : 0];
    else if (mode == BNET_MODE_STREAK)
        type = sBnetTypes[Random() % ARRAY_COUNT(sBnetTypes)];

    switch (mode)
    {
    case BNET_MODE_LV50:
        level = 50;
        break;
    case BNET_MODE_LC:
        level = 5;
        BnetMarkPreEvos(preEvoMark);
        break;
    default: // SCALING / STREAK / MONOTYPE: a few levels below the party average
    {
        // Guard BEFORE subtracting: level is unsigned, and an early party (average <= 4)
        // would wrap past zero, dodge the < 5 clamp, and field Lv100 opponents.
        u32 sub = 2 + Random() % 4;

        level = BnetAvgPartyLevel();
        level = (level > sub + 5) ? level - sub : 5;
        if (level > MAX_LEVEL)
            level = MAX_LEVEL;
        break;
    }
    }

    if (mode == BNET_MODE_SCALING || mode == BNET_MODE_STREAK)
        count = 2 + Random() % 3;
    else
        count = 3;

    pool = 0;
    for (s = 1; s <= SPECIES_DEOXYS; s++)
    {
        if (BnetPoolAccept(s, mode, type, preEvoMark))
            pool++;
    }
    if (pool == 0 && type != TYPE_NONE)
    {
        // Defensive: no enabled species of that type (should be impossible for
        // all 18 types under the Gen 1-3 roster). Fall back to any type.
        type = TYPE_NONE;
        for (s = 1; s <= SPECIES_DEOXYS; s++)
        {
            if (BnetPoolAccept(s, mode, type, preEvoMark))
                pool++;
        }
    }
    if (pool == 0)
    {
        gSpecialVar_Result = 0;
        return;
    }
    if (count > pool)
        count = pool;

    // Pick `count` distinct ordinals into the pool, then map them to species.
    for (i = 0; i < count; i++)
    {
        u32 j, ord;
    retry:
        ord = Random() % pool;
        for (j = 0; j < i; j++)
        {
            if (picked[j] == ord)
                goto retry;
        }
        picked[i] = ord;
    }
    idx = 0;
    for (s = 1; s <= SPECIES_DEOXYS && idx < pool; s++)
    {
        if (BnetPoolAccept(s, mode, type, preEvoMark))
        {
            for (i = 0; i < count; i++)
            {
                if (picked[i] == idx)
                    picked[i] = 0x8000 | s; // resolved marker (species ids stay < 0x8000)
            }
            idx++;
        }
    }

    ZeroEnemyPartyMons();
    otID = Random32();
    for (i = 0; i < count; i++)
    {
        struct TrainerMon fmon = {0};

        fmon.species = picked[i] & 0x7FFF;
        fmon.heldItem = ITEM_NONE;
        fmon.ball = 0xFF; // random ball
        fmon.nature = Random() % NUM_NATURES;
        CreateFacilityMon(&fmon, level, mode == BNET_MODE_SCALING || mode == BNET_MODE_STREAK ? 15 : 20, otID, 0, &gParties[B_TRAINER_OPPONENT_A][i]);
        // fmon.moves is all MOVE_NONE and CreateFacilityMon copies it verbatim
        // (all-zero moves would mean Struggle), so derive a real moveset.
        GiveMonInitialMoveset(&gParties[B_TRAINER_OPPONENT_A][i]);
    }

    // Cosmetic identity only (intro name/sprite resolve through the facility
    // tables under BATTLE_TYPE_BATTLE_TOWER). Ids 0..29 are in range for both
    // gBattleFrontierTrainers (316) and the tent table (30).
    TRAINER_BATTLE_PARAM.opponentA = Random() % 30;
    gBattleScripting.specialTrainerBattleType = SPECIAL_BATTLE_BNET_SIM;
    gBattleTypeFlags = BATTLE_TYPE_TRAINER | BATTLE_TYPE_BATTLE_TOWER;
    CreateTask(Task_BnetStartBattle, 1);
    PlayMapChosenOrBattleBGM(0);
    BattleTransition_StartOnField(GetSpecialBattleTransition(B_TRANSITION_GROUP_B_TOWER));
    gSpecialVar_Result = 1;
}

// VAR_0x8004 = BNET_MODE_* (LV50/MONOTYPE/LC), VAR_0x8005 = type ordinal for
// MONOTYPE. VAR_RESULT = 1 if every battle-relevant party mon (non-egg) obeys
// the room's rule and at least one exists.
void CheckBattleNetRuleParty(void)
{
    u32 i, mode = gSpecialVar_0x8004;
    u32 type = TYPE_NONE;
    u32 usable = 0;
    u8 preEvoMark[SPECIES_DEOXYS / 8 + 1] = {0};

    if (mode == BNET_MODE_MONOTYPE)
        type = sBnetTypes[gSpecialVar_0x8005 < ARRAY_COUNT(sBnetTypes) ? gSpecialVar_0x8005 : 0];
    if (mode == BNET_MODE_LC)
        BnetMarkPreEvos(preEvoMark);

    for (i = 0; i < gPartiesCount[B_TRAINER_PLAYER]; i++)
    {
        u32 species = GetMonData(&gParties[B_TRAINER_PLAYER][i], MON_DATA_SPECIES);

        if (species == SPECIES_NONE || GetMonData(&gParties[B_TRAINER_PLAYER][i], MON_DATA_IS_EGG))
            continue;
        usable++;
        switch (mode)
        {
        case BNET_MODE_LV50:
            if (GetMonData(&gParties[B_TRAINER_PLAYER][i], MON_DATA_LEVEL) > 50)
            {
                gSpecialVar_Result = 0;
                return;
            }
            break;
        case BNET_MODE_MONOTYPE:
            if (gSpeciesInfo[species].types[0] != type && gSpeciesInfo[species].types[1] != type)
            {
                gSpecialVar_Result = 0;
                return;
            }
            break;
        case BNET_MODE_LC:
            if (GetMonData(&gParties[B_TRAINER_PLAYER][i], MON_DATA_LEVEL) != 5
             || !BnetIsLittleCup(species, preEvoMark))
            {
                gSpecialVar_Result = 0;
                return;
            }
            break;
        }
    }
    gSpecialVar_Result = usable != 0;
}

// battlePoints += VAR_0x8005, clamped. Mirrors the frontier's daily-BP TV stat.
void AddBattleNetPoints(void)
{
    u32 points = gSaveBlock2Ptr->frontier.battlePoints + gSpecialVar_0x8005;

    if (points > MAX_BATTLE_FRONTIER_POINTS)
        points = MAX_BATTLE_FRONTIER_POINTS;
    gSaveBlock2Ptr->frontier.battlePoints = points;
    IncrementDailyBattlePoints(gSpecialVar_0x8005);
}

// 30% chance: VAR_0x8008 = a random shard color, else ITEM_NONE. The script
// gives it (checkitemspace-guarded, same forfeit idiom as the rematch payout).
void GiveBattleNetRandomShard(void)
{
    gSpecialVar_0x8008 = ITEM_NONE;
    if (Random() % 10 < 3)
        gSpecialVar_0x8008 = sShardItems[Random() % ARRAY_COUNT(sShardItems)];
}

// VAR_0x8005 = wins this Tower Streak run; keeps the best on the records board.
void UpdateBattleNetStreak(void)
{
    if (gSpecialVar_0x8005 > gSaveBlock2Ptr->frontier.battleNetBestStreak)
        gSaveBlock2Ptr->frontier.battleNetBestStreak = gSpecialVar_0x8005;
}

// STR_VAR_1 = best Tower Streak (records board page 2).
void BufferBattleNetStreak(void)
{
    ConvertIntToDecimalStringN(gStringVar1, gSaveBlock2Ptr->frontier.battleNetBestStreak, STR_CONV_MODE_LEFT_ALIGN, 3);
}
