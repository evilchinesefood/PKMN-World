#include "global.h"
#include "trainer_tower.h"
#include "constants/trainer_tower.h"

// Trainer Tower is cut in this hack. The facility is closed for renovations
// (see data/maps/TrainerTower_Lobby_Frlg/scripts.inc) so the challenge can no
// longer be started, and its ~31 KB of challenge trainer sets have been removed.
//
// SetUpTrainerTowerDataStruct() in src/trainer_tower.c still references
// gTrainerTowerLocalHeader and gTrainerTowerFloors unconditionally, so both are
// kept here as an inert one-floor stub. The data is never used at runtime.

const struct EReaderTrainerTowerSetSubstruct gTrainerTowerLocalHeader = {
    .numFloors = MAX_TRAINER_TOWER_FLOORS,
    .id = 1
};

static const struct TrainerTowerFloor sTrainerTowerFloor_Stub = {
    .id = 1,
    .floorIdx = MAX_TRAINER_TOWER_FLOORS,
    .challengeType = CHALLENGE_TYPE_SINGLE,
    .prize = TTPRIZE_HP_UP,
};

const struct TrainerTowerFloor *const gTrainerTowerFloors[NUM_TOWER_CHALLENGE_TYPES][MAX_TRAINER_TOWER_FLOORS] = {
    [CHALLENGE_TYPE_SINGLE] = {
        &sTrainerTowerFloor_Stub, &sTrainerTowerFloor_Stub, &sTrainerTowerFloor_Stub, &sTrainerTowerFloor_Stub,
        &sTrainerTowerFloor_Stub, &sTrainerTowerFloor_Stub, &sTrainerTowerFloor_Stub, &sTrainerTowerFloor_Stub
    },
    [CHALLENGE_TYPE_DOUBLE] = {
        &sTrainerTowerFloor_Stub, &sTrainerTowerFloor_Stub, &sTrainerTowerFloor_Stub, &sTrainerTowerFloor_Stub,
        &sTrainerTowerFloor_Stub, &sTrainerTowerFloor_Stub, &sTrainerTowerFloor_Stub, &sTrainerTowerFloor_Stub
    },
    [CHALLENGE_TYPE_KNOCKOUT] = {
        &sTrainerTowerFloor_Stub, &sTrainerTowerFloor_Stub, &sTrainerTowerFloor_Stub, &sTrainerTowerFloor_Stub,
        &sTrainerTowerFloor_Stub, &sTrainerTowerFloor_Stub, &sTrainerTowerFloor_Stub, &sTrainerTowerFloor_Stub
    },
    [CHALLENGE_TYPE_MIXED] = {
        &sTrainerTowerFloor_Stub, &sTrainerTowerFloor_Stub, &sTrainerTowerFloor_Stub, &sTrainerTowerFloor_Stub,
        &sTrainerTowerFloor_Stub, &sTrainerTowerFloor_Stub, &sTrainerTowerFloor_Stub, &sTrainerTowerFloor_Stub
    }
};
