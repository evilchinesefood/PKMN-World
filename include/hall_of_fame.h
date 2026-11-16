#ifndef GUARD_HALL_OF_FAME_H
#define GUARD_HALL_OF_FAME_H

struct HallofFameMon
{
    u32 tid;
    u32 personality;
    u16 isShiny:1;
    u16 species:15;
    u8 lvl;
    u8 nickname[POKEMON_NAME_LENGTH];
};

struct HallofFameTeam
{
    struct HallofFameMon mon[PARTY_SIZE];
};

// Both induction screens and both PC viewers share one record buffer, so they share its cap.
#define HALL_OF_FAME_MAX_TEAMS 50

extern struct HallofFameTeam *gHoFSaveBuffer;

void CB2_DoHallOfFameScreen(void);
void CB2_DoHallOfFameScreenDontSaveData(void);
void CB2_DoHallOfFamePC(void);
void HallOfFame_NormalizeLegacyEggs(void);
u32 HallOfFame_CountTeams(void);
void HallOfFame_AddTeam(const struct HallofFameTeam *team);

// hof_pc.c
void ReturnFromHallOfFamePC(void);

#endif // GUARD_HALL_OF_FAME_H
