#ifndef GUARD_REGIONAL_TRAVEL_H
#define GUARD_REGIONAL_TRAVEL_H

#include "global.h"
#include "constants/regions.h"

#define REGIONAL_ID_MAX 0xFFFFF
#define REGIONAL_CAMPAIGNS 3

enum RegionalMemberState
{
    REGIONAL_MEMBER_AVAILABLE,
    REGIONAL_MEMBER_MISSING,
    REGIONAL_MEMBER_DAYCARE,
    REGIONAL_MEMBER_AMBIGUOUS,
    REGIONAL_MEMBER_FUSED,
};

enum RegionalTravelResult
{
    REGIONAL_TRAVEL_OK,
    REGIONAL_TRAVEL_NO_MEMORY,
    REGIONAL_TRAVEL_NO_USABLE_MON,
    REGIONAL_TRAVEL_PC_FULL,
    REGIONAL_TRAVEL_MAILBOX_FULL,
    REGIONAL_TRAVEL_BAD_MAIL,
    REGIONAL_TRAVEL_PARTIAL,
    REGIONAL_TRAVEL_IDENTITY_ERROR,
    REGIONAL_TRAVEL_OPENING,
};

enum RegionalTeamChoice
{
    REGIONAL_TEAM_RECALL,
    REGIONAL_TEAM_KEEP,
};

struct RegionalTravelRequest
{
    enum Region destination;
    enum RegionalTeamChoice team;
    bool8 resume;
    bool8 partialConfirmed;
};

struct RegionalTravelPreview
{
    u8 names[PARTY_SIZE][POKEMON_NAME_LENGTH + 1];
    u16 species[PARTY_SIZE];
    u8 memberState[PARTY_SIZE];
    u8 memberCount;
    u8 availableCount;
    u8 mailCount;
    bool8 partial;
    bool8 centerUnavailable;
    u16 center;
    enum RegionalTravelResult result;
};

struct ScriptContext;
enum Region RegionalTravel_PhysicalRegion(void);
bool32 RegionalTravel_RecordDeparture(enum Region source);
bool32 RegionalTravel_IsOpeningComplete(enum Region region);
enum RegionalTravelResult RegionalTravel_Preview(const struct RegionalTravelRequest *request, struct RegionalTravelPreview *preview);
enum RegionalTravelResult RegionalTravel_Commit(const struct RegionalTravelRequest *request);
void RegionalTravel_RecordCenterEntry(void);
void RegionalTravel_Migrate(void);
void RegionalTravel_ScrOpeningComplete(struct ScriptContext *ctx);
void RegionalTravel_ScrCaptureDeparture(struct ScriptContext *ctx);
void RegionalTravel_ScrPrepare(struct ScriptContext *ctx);
void RegionalTravel_ScrPreview(struct ScriptContext *ctx);
void RegionalTravel_ScrCommit(struct ScriptContext *ctx);
void RegionalTravel_ScrWarp(struct ScriptContext *ctx);

#endif
