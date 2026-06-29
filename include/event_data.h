#ifndef GUARD_EVENT_DATA_H
#define GUARD_EVENT_DATA_H

#include "constants/regions.h"

void InitEventData(void);
void ClearTempFieldEventData(void);
void ClearDailyFlags(void);
void DisableNationalPokedex(void);
void EnableNationalPokedex(void);
bool32 IsNationalPokedexEnabled(void);
void DisableMysteryEvent(void);
void EnableMysteryEvent(void);
bool32 IsMysteryEventEnabled(void);
void DisableMysteryGift(void);
void EnableMysteryGift(void);
bool32 IsMysteryGiftEnabled(void);
void ClearMysteryGiftFlags(void);
void ClearMysteryGiftVars(void);
void DisableResetRTC(void);
void EnableResetRTC(void);
bool32 CanResetRTC(void);
u16 *GetVarPointer(u16 id);
u16 VarGet(u16 id);
u16 VarGetIfExist(u16 id);
bool8 VarSet(u16 id, u16 value);
u16 VarGetObjectEventGraphicsId(u8 id);
u8 *GetFlagPointer(u16 id);
u8 FlagSet(u16 id);
u8 FlagToggle(u16 id);
u8 FlagClear(u16 id);
bool8 FlagGet(u16 id);

// Region merge: per-region var/flag bank accessors (see region_vars.h / region_flags.h).
u16 GetRegionVarBase(enum Region region);
u16 GetRegionVar(enum Region region, u16 localId);
bool8 SetRegionVar(enum Region region, u16 localId, u16 value);
u16 GetRegionFlagBase(enum Region region);
bool8 GetRegionFlag(enum Region region, u16 localId);
void SetRegionFlag(enum Region region, u16 localId);
void ClearRegionFlag(enum Region region, u16 localId);
u16 GetBadgeFlag(enum Region region, u8 badgeIndex);
bool8 HasBadge(enum Region region, u8 badgeIndex);
bool8 HasCurrentRegionBadge(u8 badgeIndex);

extern u16 gSpecialVar_0x8000;
extern u16 gSpecialVar_0x8001;
extern u16 gSpecialVar_0x8002;
extern u16 gSpecialVar_0x8003;
extern u16 gSpecialVar_0x8004;
extern u16 gSpecialVar_0x8005;
extern u16 gSpecialVar_0x8006;
extern u16 gSpecialVar_0x8007;
extern u16 gSpecialVar_0x8008;
extern u16 gSpecialVar_0x8009;
extern u16 gSpecialVar_0x800A;
extern u16 gSpecialVar_0x800B;
extern u16 gSpecialVar_Result;
extern u16 gSpecialVar_LastTalked;
extern u16 gSpecialVar_Facing;
extern u16 gSpecialVar_MonBoxId;
extern u16 gSpecialVar_MonBoxPos;
extern u16 gSpecialVar_Unused_0x8014;

extern const u16 gBadgeFlags[NUM_BADGES];

#endif // GUARD_EVENT_DATA_H
