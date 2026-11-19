#ifndef GUARD_BUG_CONTEST_H
#define GUARD_BUG_CONTEST_H

#include "global.h"

struct Pokemon;

#define BUG_CONTEST_TIME_LIMIT_FRAMES (60 * 60 * 8) // 8 minutes at 60 FPS

void EnterBugContestMode(void);
void ExitBugContestMode(void);
bool8 BugContestCheckTimeLimit(void);
bool32 GetBugContestFlag(void);
bool8 JudgeBugContestMon(void);
bool8 TransferBugContestMon(void);
void KeepBugContestLead(void);
bool32 CanKeepBugContestNewMon(void);
void KeepBugContestNewMon(struct Pokemon *mon);
void CB2_EndBugContestBattle(void);
bool8 RemoveSafariBalls(void);
bool8 ShowBugContestChosenMon(void);

extern const u8 BugContest_EventScript_TimesUp[];
extern const u8 BugContest_EventScript_WhiteOut[];

#endif // GUARD_BUG_CONTEST_H
