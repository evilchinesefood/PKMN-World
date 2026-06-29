#include "global.h"
#include "event_data.h"
#include "pokedex.h"
#include "regions.h"

#define SPECIAL_FLAGS_SIZE  (NUM_SPECIAL_FLAGS / 8)  // 8 flags per byte
#define TEMP_FLAGS_SIZE     (NUM_TEMP_FLAGS / 8)
#define DAILY_FLAGS_SIZE    (NUM_DAILY_FLAGS / 8)
#define TEMP_VARS_SIZE      (NUM_TEMP_VARS * 2)      // 1/2 var per byte

EWRAM_DATA u16 gSpecialVar_0x8000 = 0;
EWRAM_DATA u16 gSpecialVar_0x8001 = 0;
EWRAM_DATA u16 gSpecialVar_0x8002 = 0;
EWRAM_DATA u16 gSpecialVar_0x8003 = 0;
EWRAM_DATA u16 gSpecialVar_0x8004 = 0;
EWRAM_DATA u16 gSpecialVar_0x8005 = 0;
EWRAM_DATA u16 gSpecialVar_0x8006 = 0;
EWRAM_DATA u16 gSpecialVar_0x8007 = 0;
EWRAM_DATA u16 gSpecialVar_0x8008 = 0;
EWRAM_DATA u16 gSpecialVar_0x8009 = 0;
EWRAM_DATA u16 gSpecialVar_0x800A = 0;
EWRAM_DATA u16 gSpecialVar_0x800B = 0;
EWRAM_DATA u16 gSpecialVar_Result = 0;
EWRAM_DATA u16 gSpecialVar_LastTalked = 0;
EWRAM_DATA u16 gSpecialVar_Facing = 0;
EWRAM_DATA u16 gSpecialVar_MonBoxId = 0;
EWRAM_DATA u16 gSpecialVar_MonBoxPos = 0;
EWRAM_DATA u16 gSpecialVar_Unused_0x8014 = 0;
EWRAM_DATA static u8 sSpecialFlags[SPECIAL_FLAGS_SIZE] = {0};

#if TESTING
#define TEST_FLAGS_SIZE     1
#define TEST_VARS_SIZE      8
EWRAM_DATA static u8 sTestFlags[TEST_FLAGS_SIZE] = {0};
EWRAM_DATA static u16 sTestVars[TEST_VARS_SIZE] = {0};
#endif // TESTING

extern u16 *const gSpecialVars[];

const u16 gBadgeFlags[NUM_BADGES] =
{
    FLAG_BADGE01_GET,
    FLAG_BADGE02_GET,
    FLAG_BADGE03_GET,
    FLAG_BADGE04_GET,
    FLAG_BADGE05_GET,
    FLAG_BADGE06_GET,
    FLAG_BADGE07_GET,
    FLAG_BADGE08_GET,
};

void InitEventData(void)
{
    memset(gSaveBlock1Ptr->flags, 0, sizeof(gSaveBlock1Ptr->flags));
    memset(gSaveBlock1Ptr->vars, 0, sizeof(gSaveBlock1Ptr->vars));
    memset(sSpecialFlags, 0, sizeof(sSpecialFlags));
}

void ClearTempFieldEventData(void)
{
    memset(&gSaveBlock1Ptr->flags[TEMP_FLAGS_START / 8], 0, TEMP_FLAGS_SIZE);
    memset(&gSaveBlock1Ptr->vars[TEMP_VARS_START - VARS_START], 0, TEMP_VARS_SIZE);
    FlagClear(FLAG_SYS_ENC_UP_ITEM);
    FlagClear(FLAG_SYS_ENC_DOWN_ITEM);
    FlagClear(FLAG_SYS_USE_STRENGTH);
    FlagClear(FLAG_SYS_CTRL_OBJ_DELETE);
    FlagClear(FLAG_NURSE_UNION_ROOM_REMINDER);
}

void ClearDailyFlags(void)
{
    memset(&gSaveBlock1Ptr->flags[DAILY_FLAGS_START / 8], 0, DAILY_FLAGS_SIZE);
}

void DisableNationalPokedex(void)
{
    u16 *nationalDexVar = GetVarPointer(VAR_NATIONAL_DEX);
    gSaveBlock2Ptr->pokedex.nationalMagic = 0;
    *nationalDexVar = 0;
    FlagClear(FLAG_SYS_NATIONAL_DEX);
}

void EnableNationalPokedex(void)
{
    u16 *nationalDexVar = GetVarPointer(VAR_NATIONAL_DEX);
    gSaveBlock2Ptr->pokedex.nationalMagic = 0xDA;
    *nationalDexVar = 0x302;
    FlagSet(FLAG_SYS_NATIONAL_DEX);
    gSaveBlock2Ptr->pokedex.mode = DEX_MODE_NATIONAL;
    gSaveBlock2Ptr->pokedex.order = 0;
    ResetPokedexScrollPositions();
}

bool32 IsNationalPokedexEnabled(void)
{
    if (gSaveBlock2Ptr->pokedex.nationalMagic == 0xDA && VarGet(VAR_NATIONAL_DEX) == 0x302 && FlagGet(FLAG_SYS_NATIONAL_DEX))
        return TRUE;
    else
        return FALSE;
}

void DisableMysteryEvent(void)
{
    FlagClear(FLAG_SYS_MYSTERY_EVENT_ENABLE);
}

void EnableMysteryEvent(void)
{
    FlagSet(FLAG_SYS_MYSTERY_EVENT_ENABLE);
}

bool32 IsMysteryEventEnabled(void)
{
    return FlagGet(FLAG_SYS_MYSTERY_EVENT_ENABLE);
}

void DisableMysteryGift(void)
{
    FlagClear(FLAG_SYS_MYSTERY_GIFT_ENABLE);
}

void EnableMysteryGift(void)
{
    FlagSet(FLAG_SYS_MYSTERY_GIFT_ENABLE);
}

bool32 IsMysteryGiftEnabled(void)
{
    return FlagGet(FLAG_SYS_MYSTERY_GIFT_ENABLE);
}

void ClearMysteryGiftFlags(void)
{
    FlagClear(FLAG_MYSTERY_GIFT_DONE);
    FlagClear(FLAG_MYSTERY_GIFT_1);
    FlagClear(FLAG_MYSTERY_GIFT_2);
    FlagClear(FLAG_MYSTERY_GIFT_3);
    FlagClear(FLAG_MYSTERY_GIFT_4);
    FlagClear(FLAG_MYSTERY_GIFT_5);
    FlagClear(FLAG_MYSTERY_GIFT_6);
    FlagClear(FLAG_MYSTERY_GIFT_7);
    FlagClear(FLAG_MYSTERY_GIFT_8);
    FlagClear(FLAG_MYSTERY_GIFT_9);
    FlagClear(FLAG_MYSTERY_GIFT_10);
    FlagClear(FLAG_MYSTERY_GIFT_11);
    FlagClear(FLAG_MYSTERY_GIFT_12);
    FlagClear(FLAG_MYSTERY_GIFT_13);
    FlagClear(FLAG_MYSTERY_GIFT_14);
    FlagClear(FLAG_MYSTERY_GIFT_15);
}

void ClearMysteryGiftVars(void)
{
    VarSet(VAR_GIFT_PICHU_SLOT, 0);
    VarSet(VAR_GIFT_UNUSED_1, 0);
    VarSet(VAR_GIFT_UNUSED_2, 0);
    VarSet(VAR_GIFT_UNUSED_3, 0);
    VarSet(VAR_GIFT_UNUSED_4, 0);
    VarSet(VAR_GIFT_UNUSED_5, 0);
    VarSet(VAR_GIFT_UNUSED_6, 0);
    VarSet(VAR_GIFT_UNUSED_7, 0);
}

void DisableResetRTC(void)
{
    VarSet(VAR_RESET_RTC_ENABLE, 0);
    FlagClear(FLAG_SYS_RESET_RTC_ENABLE);
}

void EnableResetRTC(void)
{
    VarSet(VAR_RESET_RTC_ENABLE, 0x920);
    FlagSet(FLAG_SYS_RESET_RTC_ENABLE);
}

bool32 CanResetRTC(void)
{
    if (FlagGet(FLAG_SYS_RESET_RTC_ENABLE) && VarGet(VAR_RESET_RTC_ENABLE) == 0x920)
        return TRUE;
    else
        return FALSE;
}

u16 *GetVarPointer(u16 id)
{
    if (id < VARS_START)
        return NULL;
    else if (id < SPECIAL_VARS_START)
        return &gSaveBlock1Ptr->vars[id - VARS_START];
    // Region merge: per-region story var bank, stored in SaveBlock3 (see region_vars.h).
    else if (id >= REGION_VARS_START && id <= REGION_VARS_END)
        return &gSaveBlock3Ptr->regionVars[id - REGION_VARS_START];
#if TESTING
    else if (id >= TESTING_VARS_START)
        return &sTestVars[id - TESTING_VARS_START];
#endif // TESTING
    else
        return gSpecialVars[id - SPECIAL_VARS_START];
}

// Region merge: map a per-region var ID to its bank, indexing by (region - REGION_KANTO)
// so Kanto/Johto/Hoenn pack contiguously. localId is the per-region var index (0..0x7F).
u16 GetRegionVarBase(enum Region region)
{
    return REGION_VARS_START + (region - REGION_KANTO) * REGION_VAR_BANK_SIZE;
}

u16 GetRegionVar(enum Region region, u16 localId)
{
    return VarGet(GetRegionVarBase(region) + localId);
}

bool8 SetRegionVar(enum Region region, u16 localId, u16 value)
{
    return VarSet(GetRegionVarBase(region) + localId, value);
}

u16 VarGet(u16 id)
{
    u16 *ptr = GetVarPointer(id);
    if (!ptr)
        return id;
    return *ptr;
}

u16 VarGetIfExist(u16 id)
{
    u16 *ptr = GetVarPointer(id);
    if (!ptr)
        return 65535;
    return *ptr;
}

bool8 VarSet(u16 id, u16 value)
{
    u16 *ptr = GetVarPointer(id);
    if (!ptr)
        return FALSE;
    *ptr = value;
    return TRUE;
}

u16 VarGetObjectEventGraphicsId(u8 id)
{
    return VarGet(VAR_OBJ_GFX_ID_0 + id);
}

u8 *GetFlagPointer(u16 id)
{
    if (id == 0)
        return NULL;
    else if (id < SPECIAL_FLAGS_START)
        return &gSaveBlock1Ptr->flags[id / 8];
    // Region merge: reserved Johto flag bank, stored in SaveBlock3 (see region_flags.h).
    else if (id >= FLAG_JOHTO_BASE && id <= FLAG_JOHTO_END)
        return &gSaveBlock3Ptr->johtoFlags[(id - FLAG_JOHTO_BASE) / 8];
#if TESTING
    else if (id >= TESTING_FLAGS_START)
        return &sTestFlags[(id - TESTING_FLAGS_START) / 8];
#endif // TESTING
    else
        return &sSpecialFlags[(id - SPECIAL_FLAGS_START) / 8];
}

u8 FlagSet(u16 id)
{
    u8 *ptr = GetFlagPointer(id);
    if (ptr)
        *ptr |= 1 << (id & 7);
    return 0;
}

u8 FlagToggle(u16 id)
{
    u8 *ptr = GetFlagPointer(id);
    if (ptr)
        *ptr ^= 1 << (id & 7);
    return 0;
}

u8 FlagClear(u16 id)
{
    u8 *ptr = GetFlagPointer(id);
    if (ptr)
        *ptr &= ~(1 << (id & 7));
    return 0;
}

bool8 FlagGet(u16 id)
{
    u8 *ptr = GetFlagPointer(id);

    if (!ptr)
        return FALSE;

    if (!(((*ptr) >> (id & 7)) & 1))
        return FALSE;

    return TRUE;
}

// Region merge: per-region flag bank base (see region_flags.h). Each region's story
// and badge flags are isolated so campaign progress never aliases between regions.
//   Hoenn -> native flags (base 0)
//   Kanto -> the Phase-1 rebased FRLG bank (FLAG_KANTO_BASE, inline in SaveBlock1.flags)
//   Johto -> the reserved bank in SaveBlock3 (FLAG_JOHTO_BASE)
// localId is the per-region flag index within that region's bank.
u16 GetRegionFlagBase(enum Region region)
{
    switch (region)
    {
    case REGION_KANTO: return FLAG_KANTO_BASE;
    case REGION_JOHTO: return FLAG_JOHTO_BASE;
    default:           return 0; // Hoenn / native
    }
}

bool8 GetRegionFlag(enum Region region, u16 localId)
{
    return FlagGet(GetRegionFlagBase(region) + localId);
}

void SetRegionFlag(enum Region region, u16 localId)
{
    FlagSet(GetRegionFlagBase(region) + localId);
}

void ClearRegionFlag(enum Region region, u16 localId)
{
    FlagClear(GetRegionFlagBase(region) + localId);
}

// Per-region gym badges (K9). Hoenn keeps the native FLAG_BADGE01..08_GET system flags;
// Kanto and Johto store their 8 badges at the head of their per-region flag bank (see
// region_flags.h). badgeIndex is 0..7 in that region's gym order. Every badge consumer
// (obedience cap, level/EV caps, HM field-move gate, catch malus, badge counters) reads
// the CURRENT region's badges through these so completing one region never lights up
// another's badges.
u16 GetBadgeFlag(enum Region region, u8 badgeIndex)
{
    badgeIndex &= (NUM_BADGES - 1); // 0..7 — keeps the flag id provably inside the region's
                                    // bank so GetFlagPointer never falls through to sSpecialFlags
                                    // (the compiler's -Werror=array-bounds checks the full u8 range)
    switch (region)
    {
    case REGION_KANTO: return FLAG_KANTO_BADGE(badgeIndex);
    case REGION_JOHTO: return FLAG_JOHTO_BADGE(badgeIndex); // NOT bank base — see region_flags.h
    default:           return FLAG_BADGE01_GET + badgeIndex; // Hoenn / native
    }
}

bool8 HasBadge(enum Region region, u8 badgeIndex)
{
    return FlagGet(GetBadgeFlag(region, badgeIndex));
}

bool8 HasCurrentRegionBadge(u8 badgeIndex)
{
    return HasBadge(GetCurrentRegion(), badgeIndex);
}
