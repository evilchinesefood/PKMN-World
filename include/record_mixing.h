#ifndef GUARD_RECORD_MIXING_H
#define GUARD_RECORD_MIXING_H

struct PlayerHallRecords
{
    struct RankingHall1P onePlayer[HALL_FACILITIES_COUNT][FRONTIER_LVL_MODE_COUNT];
    struct RankingHall2P twoPlayers[FRONTIER_LVL_MODE_COUNT];
};

void RecordMixingPlayerSpotTriggered(void);
// Declared here because the struct is, but DEFINED in src/frontier_util.c: the
// Battle Frontier Ranking Hall is its only single-player caller, and leaving it
// in record_mixing.c would tie a live facility to a link module (issue #59 E4).
void GetPlayerHallRecords(struct PlayerHallRecords *dst);

#endif //GUARD_RECORD_MIXING_H
