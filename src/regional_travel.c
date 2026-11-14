#include "global.h"
#include "regional_travel.h"
#include "regional_centers.h"
#include "pokemon.h"
#include "pokemon_storage_system.h"
#include "regions.h"
#include "event_data.h"
#include "overworld.h"
#include "field_screen_effect.h"
#include "mail.h"
#include "script.h"
#include "event_scripts.h"
#include "story_progress.h"
#include "string_util.h"
#include "constants/battle.h"
#include "constants/flags.h"
#include "constants/vars.h"
#include "constants/maps.h"
#include "constants/map_groups.h"
#include "constants/heal_locations.h"
#include "constants/items.h"
#include "constants/pokemon.h"

struct RegionalMonLocation
{
    struct BoxPokemon *mon;
    u16 slot;
    u8 state;
    bool8 inParty;
};

struct RegionalTravelPlan
{
    struct Pokemon party[PARTY_SIZE];
    struct BoxPokemon deposits[PARTY_SIZE];
    struct Mail mail[MAIL_COUNT];
    u16 withdrawn[PARTY_SIZE];
    u16 deposited[PARTY_SIZE];
    struct WarpData warp;
    u16 healLocation;
    u8 withdrawnCount;
    u8 depositedCount;
    u8 partyCount;
    u8 followerSlot;
};

static EWRAM_DATA struct RegionalTravelPlan sPlan = {0};
static EWRAM_DATA struct RegionalTravelPreview sPreview = {0};

static bool32 IsCampaign(enum Region region)
{
    return region >= REGION_KANTO && region <= REGION_HOENN;
}

static struct RegionalTravelSave *TravelSave(void)
{
    return &gSaveBlock3Ptr->region.regionalTravel;
}

// The ordinary getters mark checksum failures as Bad Eggs. Preflight must inspect
// copies so even an unrelated damaged storage entry cannot mutate a refused trip.
static u32 ReadBoxData(const struct BoxPokemon *mon, s32 field)
{
    struct BoxPokemon copy = *mon;
    if (field == MON_DATA_SANITY_IS_BAD_EGG)
        GetBoxMonData(&copy, MON_DATA_SPECIES);
    return GetBoxMonData(&copy, field);
}

static u32 ReadMonData(const struct Pokemon *mon, s32 field)
{
    struct Pokemon copy = *mon;
    if (field == MON_DATA_SANITY_IS_BAD_EGG)
        GetMonData(&copy, MON_DATA_SPECIES);
    return GetMonData(&copy, field);
}

static void ReadBoxNickname(const struct BoxPokemon *mon, u8 *name)
{
    struct BoxPokemon copy = *mon;
    GetBoxMonData(&copy, MON_DATA_NICKNAME, name);
}

static bool32 HasMon(struct BoxPokemon *mon)
{
    return ReadBoxData(mon, MON_DATA_SPECIES) != SPECIES_NONE;
}

static void FindIdentityIn(struct RegionalMonLocation *found, u32 *matches, struct BoxPokemon *mon, u32 identity, u8 state, bool8 inParty, u16 slot)
{
    if (!HasMon(mon) || ReadBoxData(mon, MON_DATA_SANITY_IS_BAD_EGG)
     || ReadBoxData(mon, MON_DATA_REGIONAL_ID) != identity)
        return;
    (*matches)++;
    found->mon = mon;
    found->state = state;
    found->inParty = inParty;
    found->slot = slot;
}

static struct RegionalMonLocation FindIdentity(u32 identity)
{
    struct RegionalMonLocation found = {.state = REGIONAL_MEMBER_MISSING};
    u32 i, matches = 0;

    if (!identity || identity > REGIONAL_ID_MAX)
        return found;
    for (i = 0; i < PARTY_SIZE; i++)
        FindIdentityIn(&found, &matches, &gParties[B_TRAINER_PLAYER][i].box, identity, REGIONAL_MEMBER_AVAILABLE, TRUE, i);
    for (i = 0; i < TOTAL_BOXES_COUNT * IN_BOX_COUNT; i++)
        FindIdentityIn(&found, &matches, GetBoxedMonPtr(i / IN_BOX_COUNT, i % IN_BOX_COUNT), identity, REGIONAL_MEMBER_AVAILABLE, FALSE, i);
    for (i = 0; i < DAYCARE_MON_COUNT; i++)
        FindIdentityIn(&found, &matches, &gSaveBlock1Ptr->daycare.mons[i].mon, identity, REGIONAL_MEMBER_DAYCARE, FALSE, i);
    FindIdentityIn(&found, &matches, &gSaveBlock3Ptr->region.route5DayCareMon.mon, identity, REGIONAL_MEMBER_DAYCARE, FALSE, DAYCARE_MON_COUNT);
    for (i = 0; i < MAX_FUSION_STORAGE; i++)
        FindIdentityIn(&found, &matches, &gPokemonStoragePtr->fusions[i].box, identity, REGIONAL_MEMBER_FUSED, FALSE, i);
    if (matches > 1)
        found.state = REGIONAL_MEMBER_AMBIGUOUS;
    if (matches == 1 && ReadBoxData(found.mon, MON_DATA_SANITY_IS_BAD_EGG))
        found.state = REGIONAL_MEMBER_MISSING;
    return found;
}

static bool32 IdentityIsReferenced(u32 identity)
{
    u32 region, slot;
    for (region = 0; region < REGIONAL_CAMPAIGNS; region++)
        for (slot = 0; slot < PARTY_SIZE; slot++)
            if (TravelSave()->teams[region].members[slot].identity == identity)
                return TRUE;
    return FALSE;
}

bool32 RegionalTravel_RecordDeparture(enum Region source)
{
    struct RegionalTeamMemory memory = {0};
    u32 next = TravelSave()->nextIdentity;
    u32 identities[PARTY_SIZE] = {0};
    u32 i;

    if (!IsCampaign(source))
        return TRUE;
    if (!next)
        next = 1;
    for (i = 0; i < PARTY_SIZE; i++)
    {
        struct Pokemon *mon = &gParties[B_TRAINER_PLAYER][i];
        struct RegionalTeamMember *member;
        struct RegionalMonLocation location;
        if (!HasMon(&mon->box))
            continue;
        if (ReadMonData(mon, MON_DATA_SANITY_IS_BAD_EGG))
            return FALSE;
        identities[i] = ReadMonData(mon, MON_DATA_REGIONAL_ID);
        if (identities[i])
        {
            location = FindIdentity(identities[i]);
            if (location.state != REGIONAL_MEMBER_AVAILABLE || location.mon != &mon->box)
                return FALSE;
        }
        else
        {
            while (next <= REGIONAL_ID_MAX)
            {
                location = FindIdentity(next);
                if (!location.mon && !IdentityIsReferenced(next))
                    break;
                next++;
            }
            if (next > REGIONAL_ID_MAX)
                return FALSE;
            identities[i] = next++;
        }
        member = &memory.members[memory.count++];
        member->identity = identities[i];
        member->lastSpecies = ReadMonData(mon, MON_DATA_SPECIES);
    }
    for (i = 0; i < PARTY_SIZE; i++)
        if (identities[i])
            SetMonData(&gParties[B_TRAINER_PLAYER][i], MON_DATA_REGIONAL_ID, &identities[i]);
    TravelSave()->teams[source - REGION_KANTO] = memory;
    TravelSave()->nextIdentity = next;
    return TRUE;
}

void RegionalTravel_Migrate(void)
{
    u32 i, zero = 0;
    memset(TravelSave(), 0, sizeof(*TravelSave()));
    TravelSave()->nextIdentity = 1;
    for (i = 0; i < PARTY_SIZE; i++)
        SetMonData(&gSaveBlock1Ptr->playerParty[i], MON_DATA_REGIONAL_ID, &zero);
    for (i = 0; i < TOTAL_BOXES_COUNT * IN_BOX_COUNT; i++)
        SetBoxMonData(GetBoxedMonPtr(i / IN_BOX_COUNT, i % IN_BOX_COUNT), MON_DATA_REGIONAL_ID, &zero);
    for (i = 0; i < DAYCARE_MON_COUNT; i++)
        SetBoxMonData(&gSaveBlock1Ptr->daycare.mons[i].mon, MON_DATA_REGIONAL_ID, &zero);
    SetBoxMonData(&gSaveBlock3Ptr->region.route5DayCareMon.mon, MON_DATA_REGIONAL_ID, &zero);
    for (i = 0; i < MAX_FUSION_STORAGE; i++)
        SetMonData(&gPokemonStoragePtr->fusions[i], MON_DATA_REGIONAL_ID, &zero);
}

#define MAP_KEY(map) ((MAP_GROUP(map) << 8) | MAP_NUM(map))
enum Region RegionalTravel_PhysicalRegion(void)
{
    u32 map = (gSaveBlock1Ptr->location.mapGroup << 8) | (u8)gSaveBlock1Ptr->location.mapNum;
    switch (gMapHeader.regionMapSectionId)
    {
    case MAPSEC_DYNAMIC:
    case MAPSEC_SPECIAL_AREA:
    case MAPSEC_BATTLE_FRONTIER:
    case MAPSEC_SS_AQUA:
    case MAPSEC_BIRTH_ISLAND:
    case MAPSEC_FARAWAY_ISLAND:
    case MAPSEC_NAVEL_ROCK:
    case MAPSEC_SOUTHERN_ISLAND:
    case MAPSEC_TRAINER_HILL:
    case MAPSEC_TRAINER_TOWER:
    case MAPSEC_TRAINER_TOWER_2:
        return REGION_NONE;
    }
    switch (map)
    {
    case MAP_KEY(MAP_SLATEPORT_CITY_BATTLE_TENT_LOBBY):
    case MAP_KEY(MAP_SLATEPORT_CITY_BATTLE_TENT_CORRIDOR):
    case MAP_KEY(MAP_SLATEPORT_CITY_BATTLE_TENT_BATTLE_ROOM):
    case MAP_KEY(MAP_VERDANTURF_TOWN_BATTLE_TENT_LOBBY):
    case MAP_KEY(MAP_VERDANTURF_TOWN_BATTLE_TENT_CORRIDOR):
    case MAP_KEY(MAP_VERDANTURF_TOWN_BATTLE_TENT_BATTLE_ROOM):
    case MAP_KEY(MAP_FALLARBOR_TOWN_BATTLE_TENT_LOBBY):
    case MAP_KEY(MAP_FALLARBOR_TOWN_BATTLE_TENT_CORRIDOR):
    case MAP_KEY(MAP_FALLARBOR_TOWN_BATTLE_TENT_BATTLE_ROOM):
        return REGION_NONE;
    }
    return GetRegionForSectionId(gMapHeader.regionMapSectionId);
}

static bool32 IsWalkInFacilityEntrance(u8 mapGroup, u8 mapNum)
{
    switch ((mapGroup << 8) | mapNum)
    {
    case MAP_KEY(MAP_SLATEPORT_CITY_BATTLE_TENT_LOBBY):
    case MAP_KEY(MAP_VERDANTURF_TOWN_BATTLE_TENT_LOBBY):
    case MAP_KEY(MAP_FALLARBOR_TOWN_BATTLE_TENT_LOBBY):
    case MAP_KEY(MAP_TRAINER_HILL_ENTRANCE):
    case MAP_KEY(MAP_SEVEN_ISLAND_TRAINER_TOWER):
        return TRUE;
    }
    return FALSE;
}

bool32 RegionalTravel_TryEnterWalkInFacility(u8 mapGroup, u8 mapNum)
{
    if (!IsWalkInFacilityEntrance(mapGroup, mapNum))
        return TRUE;
    return RegionalTravel_RecordDeparture(RegionalTravel_PhysicalRegion());
}

bool32 RegionalTravel_IsOpeningComplete(enum Region region)
{
    u32 badge;
    if (!IsCampaign(region))
        return FALSE;
    if (IsRegionChampion(region))
        return TRUE;
    for (badge = 0; badge < NUM_BADGES; badge++)
        if (HasBadge(region, badge))
            return TRUE;
    switch (region)
    {
    case REGION_KANTO:
        return VarGet(VAR_MAP_SCENE_PALLET_TOWN_PROFESSOR_OAKS_LAB) >= 4;
    case REGION_JOHTO:
        return FlagGet(FLAG_JOHTO_STARTER_CHOSEN) && VarGet(VAR_NEWBARKTOWN_LABSTATE) >= 2;
    case REGION_HOENN:
        return VarGet(VAR_BIRCH_LAB_STATE) >= 3;
    default:
        return FALSE;
    }
}

// A Hub Pass trip out of a region whose opening is unfinished still records that region's team
// (the starter), but the hub gate's cross then boxes the party and lands the player back in the
// opening with nothing to battle with. Kanto's rival battle at Oak's lab is refused for an empty
// party, so the player could walk out and skip it. Withdraw the remembered team again.
void RegionalTravel_RestoreOpeningTeam(enum Region region)
{
    const struct RegionalTeamMemory *memory;
    u32 i, count = CalculatePlayerPartyCount();

    if (!IsCampaign(region) || RegionalTravel_IsOpeningComplete(region))
        return;
    memory = &TravelSave()->teams[region - REGION_KANTO];
    for (i = 0; i < memory->count && i < PARTY_SIZE && count < PARTY_SIZE; i++)
    {
        struct RegionalMonLocation location = FindIdentity(memory->members[i].identity);
        if (location.state != REGIONAL_MEMBER_AVAILABLE || location.inParty)
            continue;
        BoxMonToMon(location.mon, &gParties[B_TRAINER_PLAYER][count++]);
        ZeroBoxMonAt(location.slot / IN_BOX_COUNT, location.slot % IN_BOX_COUNT);
    }
    CalculatePlayerPartyCount();
}

void RegionalTravel_RecordCenterEntry(void)
{
    u16 id = RegionalCenter_ForMap(gSaveBlock1Ptr->location.mapGroup, gSaveBlock1Ptr->location.mapNum);
    enum Region region = RegionalCenter_GetRegion(id);
    if (IsCampaign(region))
        TravelSave()->center[region - REGION_KANTO] = id;
}

static bool32 PartyIsUsable(struct Pokemon *party, u32 count)
{
    u32 i;
    for (i = 0; i < count; i++)
        if (ReadMonData(&party[i], MON_DATA_SPECIES) != SPECIES_NONE
         && !ReadMonData(&party[i], MON_DATA_IS_EGG)
         && !ReadMonData(&party[i], MON_DATA_SANITY_IS_BAD_EGG)
         && ReadMonData(&party[i], MON_DATA_HP) > 0)
            return TRUE;
    return FALSE;
}

// Before Surf, Mr. Briney's boat is the only way to Slateport until Rusturf Tunnel opens, which takes
// Rock Smash and Wattson's badge. Landing there before his voyages would cut the player off from
// Dewford, so the harbor waits until the player has reached Slateport.
// VAR_BRINEY_LOCATION values, as EventScript_ResetMrBriney reads them.
enum
{
    BRINEY_AT_HOUSE = 1,
    BRINEY_AT_ROUTE_109 = 3,
};

static bool32 IsHoennHarborOpen(void)
{
    // Briney's boat shows on Route 109 only after the Slateport voyage, even if the player never
    // walked into the city before leaving Hoenn. VAR_BRINEY_LOCATION can't say so: the voyage backs
    // it up and restores it, and only a Center updates it.
    return HasBadge(REGION_HOENN, 0)
        && (FlagGet(FLAG_VISITED_SLATEPORT_CITY) || !FlagGet(FLAG_HIDE_ROUTE_109_MR_BRINEY_BOAT));
}

static void StandardDestination(enum Region region, struct RegionalTravelPlan *plan)
{
    bool32 later = region == REGION_HOENN ? IsHoennHarborOpen() : HasBadge(region, 0);
    struct WarpData warp = {.warpId = WARP_ID_NONE, .x = -1, .y = -1};
    switch (region)
    {
    case REGION_KANTO:
        warp.mapGroup = MAP_GROUP(MAP_PALLET_TOWN_PLAYERS_HOUSE_2F);
        warp.mapNum = MAP_NUM(MAP_PALLET_TOWN_PLAYERS_HOUSE_2F);
        warp.x = 6;
        warp.y = 6;
        plan->healLocation = HEAL_LOCATION_PALLET_TOWN;
        if (later)
        {
            warp.mapGroup = MAP_GROUP(MAP_VERMILION_CITY);
            warp.mapNum = MAP_NUM(MAP_VERMILION_CITY);
            warp.x = 22;
            warp.y = 32;
        }
        break;
    case REGION_JOHTO:
        warp.mapGroup = MAP_GROUP(MAP_NEW_BARK_TOWN_PLAYERS_HOUSE_2F);
        warp.mapNum = MAP_NUM(MAP_NEW_BARK_TOWN_PLAYERS_HOUSE_2F);
        warp.warpId = 1;
        plan->healLocation = HEAL_LOCATION_NEW_BARK_TOWN;
        // Landing in Goldenrod before Ilex Forest leaves Azalea unreachable on foot.
        if (later && StoryProgress_JohtoPastIlex())
        {
            warp.mapGroup = MAP_GROUP(MAP_GOLDENROD_CITY_TRAIN_STATION);
            warp.mapNum = MAP_NUM(MAP_GOLDENROD_CITY_TRAIN_STATION);
            warp.warpId = 0;
        }
        break;
    case REGION_HOENN:
        if (gSaveBlock2Ptr->playerGender == FEMALE)
        {
            warp.mapGroup = MAP_GROUP(MAP_LITTLEROOT_TOWN_MAYS_HOUSE_2F);
            warp.mapNum = MAP_NUM(MAP_LITTLEROOT_TOWN_MAYS_HOUSE_2F);
            plan->healLocation = HEAL_LOCATION_LITTLEROOT_TOWN_MAYS_HOUSE_2F;
        }
        else
        {
            warp.mapGroup = MAP_GROUP(MAP_LITTLEROOT_TOWN_BRENDANS_HOUSE_2F);
            warp.mapNum = MAP_NUM(MAP_LITTLEROOT_TOWN_BRENDANS_HOUSE_2F);
            plan->healLocation = HEAL_LOCATION_LITTLEROOT_TOWN_BRENDANS_HOUSE_2F;
        }
        warp.x = 4;
        warp.y = 4;
        if (later)
        {
            warp.mapGroup = MAP_GROUP(MAP_SLATEPORT_CITY_HARBOR);
            warp.mapNum = MAP_NUM(MAP_SLATEPORT_CITY_HARBOR);
            warp.warpId = 0;
            warp.x = -1;
            warp.y = -1;
            plan->healLocation = gSaveBlock2Ptr->playerGender == FEMALE ? HEAL_LOCATION_LITTLEROOT_TOWN_MAYS_HOUSE : HEAL_LOCATION_LITTLEROOT_TOWN_BRENDANS_HOUSE;
        }
        break;
    default:
        break;
    }
    plan->warp = warp;
}

static enum RegionalTravelResult ValidateMail(void)
{
    u32 used = 0, i;
    for (i = 0; i < PARTY_SIZE; i++)
    {
        struct Pokemon *mon = &gParties[B_TRAINER_PLAYER][i];
        u32 mail, item;
        if (!HasMon(&mon->box))
            continue;
        if (ReadMonData(mon, MON_DATA_SANITY_IS_BAD_EGG))
            return REGIONAL_TRAVEL_IDENTITY_ERROR;
        mail = ReadMonData(mon, MON_DATA_MAIL);
        item = ReadMonData(mon, MON_DATA_HELD_ITEM);
        if (!ItemIsMail(item))
        {
            if (mail != MAIL_NONE)
                return REGIONAL_TRAVEL_BAD_MAIL;
            continue;
        }
        if (mail >= PARTY_SIZE || (used & (1 << mail)) || gSaveBlock1Ptr->mail[mail].itemId != item)
            return REGIONAL_TRAVEL_BAD_MAIL;
        used |= 1 << mail;
    }
    return REGIONAL_TRAVEL_OK;
}

static enum RegionalTravelResult PlanExchange(const struct RegionalTravelRequest *request, struct RegionalTravelPreview *preview)
{
    const struct RegionalTeamMemory *memory = &TravelSave()->teams[request->destination - REGION_KANTO];
    bool8 retained[PARTY_SIZE] = {0};
    u16 freeSlots[PARTY_SIZE];
    u32 i, j, freeCount = 0;
    enum RegionalTravelResult result;

    if (!memory->count || memory->count > PARTY_SIZE)
        return REGIONAL_TRAVEL_NO_MEMORY;
    preview->memberCount = memory->count;
    for (i = 0; i < memory->count; i++)
    {
        struct RegionalMonLocation location = FindIdentity(memory->members[i].identity);
        preview->species[i] = memory->members[i].lastSpecies;
        preview->memberState[i] = location.state;
        for (j = 0; j < i; j++)
            if (memory->members[j].identity == memory->members[i].identity)
                preview->memberState[i] = REGIONAL_MEMBER_AMBIGUOUS;
        if (preview->memberState[i] != REGIONAL_MEMBER_AVAILABLE)
        {
            preview->partial = TRUE;
            continue;
        }
        preview->species[i] = ReadBoxData(location.mon, MON_DATA_SPECIES);
        ReadBoxNickname(location.mon, preview->names[i]);
        if (location.inParty)
        {
            sPlan.party[sPlan.partyCount] = gParties[B_TRAINER_PLAYER][location.slot];
            retained[location.slot] = TRUE;
            if (gSaveBlock2Ptr->followerSlot == location.slot + 1)
                sPlan.followerSlot = sPlan.partyCount + 1;
        }
        else
        {
            BoxMonToMon(location.mon, &sPlan.party[sPlan.partyCount]);
            if (ItemIsMail(ReadMonData(&sPlan.party[sPlan.partyCount], MON_DATA_HELD_ITEM)))
                return REGIONAL_TRAVEL_BAD_MAIL;
            sPlan.withdrawn[sPlan.withdrawnCount++] = location.slot;
        }
        sPlan.partyCount++;
    }
    preview->availableCount = sPlan.partyCount;
    if (!PartyIsUsable(sPlan.party, sPlan.partyCount))
        return REGIONAL_TRAVEL_NO_USABLE_MON;
    result = ValidateMail();
    if (result != REGIONAL_TRAVEL_OK)
        return result;
    memcpy(sPlan.mail, gSaveBlock1Ptr->mail, sizeof(sPlan.mail));
    for (i = 0; i < sPlan.withdrawnCount; i++)
        freeSlots[freeCount++] = sPlan.withdrawn[i];
    for (i = 0; i < TOTAL_BOXES_COUNT * IN_BOX_COUNT && freeCount < PARTY_SIZE; i++)
        if (!HasMon(GetBoxedMonPtr(i / IN_BOX_COUNT, i % IN_BOX_COUNT)))
            freeSlots[freeCount++] = i;
    for (i = 0; i < PARTY_SIZE; i++)
    {
        struct Pokemon outgoing;
        u32 value;
        if (retained[i] || !HasMon(&gParties[B_TRAINER_PLAYER][i].box))
            continue;
        if (sPlan.depositedCount >= freeCount)
            return REGIONAL_TRAVEL_PC_FULL;
        outgoing = gParties[B_TRAINER_PLAYER][i];
        if (MonHasMail(&outgoing))
        {
            u32 mail = ReadMonData(&outgoing, MON_DATA_MAIL);
            for (j = PARTY_SIZE; j < MAIL_COUNT; j++)
                if (sPlan.mail[j].itemId == ITEM_NONE)
                    break;
            if (j == MAIL_COUNT)
                return REGIONAL_TRAVEL_MAILBOX_FULL;
            sPlan.mail[j] = sPlan.mail[mail];
            ClearMail(&sPlan.mail[mail]);
            value = ITEM_NONE;
            SetMonData(&outgoing, MON_DATA_HELD_ITEM, &value);
            value = MAIL_NONE;
            SetMonData(&outgoing, MON_DATA_MAIL, &value);
            preview->mailCount++;
        }
        value = ReadMonData(&outgoing, MON_DATA_MAX_HP) - ReadMonData(&outgoing, MON_DATA_HP);
        SetBoxMonData(&outgoing.box, MON_DATA_HP_LOST, &value);
        value = ReadMonData(&outgoing, MON_DATA_STATUS);
        SetBoxMonData(&outgoing.box, MON_DATA_STATUS, &value);
        sPlan.deposits[sPlan.depositedCount] = outgoing.box;
        sPlan.deposited[sPlan.depositedCount] = freeSlots[sPlan.depositedCount];
        sPlan.depositedCount++;
    }
    return REGIONAL_TRAVEL_OK;
}

enum RegionalTravelResult RegionalTravel_Preview(const struct RegionalTravelRequest *request, struct RegionalTravelPreview *preview)
{
    enum RegionalTravelResult result = REGIONAL_TRAVEL_OK;
    u16 center;
    u32 i;
    memset(&sPlan, 0, sizeof(sPlan));
    memset(preview, 0, sizeof(*preview));
    if (!IsCampaign(request->destination) || !RegionalTravel_IsOpeningComplete(request->destination))
        return preview->result = REGIONAL_TRAVEL_OPENING;
    if (request->team == REGIONAL_TEAM_RECALL)
        result = PlanExchange(request, preview);
    else if (request->team == REGIONAL_TEAM_KEEP)
    {
        for (i = 0; i < PARTY_SIZE; i++)
        {
            struct Pokemon *mon = &gParties[B_TRAINER_PLAYER][i];
            if (!HasMon(&mon->box))
                continue;
            preview->species[sPlan.partyCount] = ReadMonData(mon, MON_DATA_SPECIES);
            ReadBoxNickname(&mon->box, preview->names[sPlan.partyCount]);
            sPlan.party[sPlan.partyCount++] = *mon;
        }
        if (!PartyIsUsable(sPlan.party, sPlan.partyCount))
            result = REGIONAL_TRAVEL_NO_USABLE_MON;
        preview->availableCount = sPlan.partyCount;
        preview->memberCount = sPlan.partyCount;
    }
    else
        result = REGIONAL_TRAVEL_NO_MEMORY;
    StandardDestination(request->destination, &sPlan);
    center = TravelSave()->center[request->destination - REGION_KANTO];
    if (center && RegionalCenter_IsSafe(center, request->destination, sPlan.party, sPlan.partyCount))
    {
        if (request->resume && RegionalCenter_GetDestination(center, &sPlan.warp, &sPlan.healLocation))
            preview->center = center;
    }
    else
        preview->centerUnavailable = center != 0;
    if (result == REGIONAL_TRAVEL_OK && preview->partial && !request->partialConfirmed)
        result = REGIONAL_TRAVEL_PARTIAL;
    return preview->result = result;
}

// Before Surf, Mr. Briney's boat is the only link between the west mainland, Dewford and Route 109,
// so dock him on the shore the player lands on. An east arrival needs a visited Slateport, so his
// first voyage is already behind him. A whiteout or Teleport moves him to VAR_BRINEY_LOCATION, which
// each Center visit records. The standard arrival respawns in Littleroot without one, so it records
// his house, the shore Littleroot can walk to.
static void DockBrineyForArrival(u16 center)
{
    bool32 west = center ? RegionalCenter_IsHoennWest(center) : !IsHoennHarborOpen();

    if (!HasBadge(REGION_HOENN, 0) || FlagGet(FLAG_DEFEATED_PETALBURG_GYM) || VarGet(VAR_BRINEY_LOCATION) == 0
     || center == RegionalCenter_ForMap(MAP_GROUP(MAP_DEWFORD_TOWN_POKEMON_CENTER_1F), MAP_NUM(MAP_DEWFORD_TOWN_POKEMON_CENTER_1F)))
        return;
    VarSet(VAR_BRINEY_LOCATION, west ? BRINEY_AT_HOUSE : BRINEY_AT_ROUTE_109);
    RunScriptImmediately(EventScript_ResetMrBriney);
    if (center == 0)
        VarSet(VAR_BRINEY_LOCATION, BRINEY_AT_HOUSE);
}

enum RegionalTravelResult RegionalTravel_Commit(const struct RegionalTravelRequest *request)
{
    enum RegionalTravelResult result = RegionalTravel_Preview(request, &sPreview);
    u32 i;
    if (result != REGIONAL_TRAVEL_OK)
        return result;
    if (request->team == REGIONAL_TEAM_RECALL)
    {
        for (i = 0; i < sPlan.withdrawnCount; i++)
            ZeroBoxMonAt(sPlan.withdrawn[i] / IN_BOX_COUNT, sPlan.withdrawn[i] % IN_BOX_COUNT);
        for (i = 0; i < sPlan.depositedCount; i++)
            SetBoxMonAt(sPlan.deposited[i] / IN_BOX_COUNT, sPlan.deposited[i] % IN_BOX_COUNT, &sPlan.deposits[i]);
        memcpy(gParties[B_TRAINER_PLAYER], sPlan.party, sizeof(sPlan.party));
        gPartiesCount[B_TRAINER_PLAYER] = sPlan.partyCount;
        memcpy(gSaveBlock1Ptr->mail, sPlan.mail, sizeof(sPlan.mail));
        gSaveBlock2Ptr->followerSlot = sPlan.followerSlot;
    }
    SetCurrentRegion(request->destination);
    SetLastHealLocationWarp(sPlan.healLocation);
    SetWarpDestination(sPlan.warp.mapGroup, sPlan.warp.mapNum, sPlan.warp.warpId, sPlan.warp.x, sPlan.warp.y);
    if (request->destination == REGION_HOENN)
        DockBrineyForArrival(sPreview.center);
    return REGIONAL_TRAVEL_OK;
}

static struct RegionalTravelRequest ScriptRequest(void)
{
    return (struct RegionalTravelRequest)
    {
        .destination = REGION_KANTO + gSpecialVar_0x8008,
        .team = gSpecialVar_0x8009,
        .resume = gSpecialVar_0x800A == 0,
        .partialConfirmed = gSpecialVar_0x800B != 0,
    };
}

void RegionalTravel_ScrOpeningComplete(struct ScriptContext *ctx)
{
    gSpecialVar_Result = RegionalTravel_IsOpeningComplete(REGION_KANTO + gSpecialVar_0x8008);
}

void RegionalTravel_ScrCaptureDeparture(struct ScriptContext *ctx)
{
    gSpecialVar_Result = RegionalTravel_RecordDeparture(RegionalTravel_PhysicalRegion());
}

void RegionalTravel_ScrPrepare(struct ScriptContext *ctx)
{
    struct RegionalTravelRequest request = {
        .destination = REGION_KANTO + gSpecialVar_0x8008,
        .team = REGIONAL_TEAM_RECALL,
        .resume = TRUE,
    };
    enum RegionalTravelResult result = RegionalTravel_Preview(&request, &sPreview);
    gSpecialVar_Result = result != REGIONAL_TRAVEL_NO_MEMORY && result != REGIONAL_TRAVEL_NO_USABLE_MON;
    if (result == REGIONAL_TRAVEL_NO_MEMORY)
        StringCopy(gStringVar4, COMPOUND_STRING("No team has been remembered here.\nKeep your current party, or cancel\land prepare a team at the PC."));
    else if (result == REGIONAL_TRAVEL_NO_USABLE_MON)
        StringCopy(gStringVar4, COMPOUND_STRING("This region's remembered team has\nno usable POKéMON available.\lKeep your party or prepare at the PC."));
    else
        StringCopy(gStringVar4, COMPOUND_STRING("Use this region's remembered team,\nor keep the party you carry?"));
}

static void BufferPreview(const struct RegionalTravelRequest *request)
{
    u32 i;
    u8 *text = gStringVar4;
    if (request->team == REGIONAL_TEAM_KEEP)
        text = StringCopy(text, COMPOUND_STRING("Keep current party."));
    else
        text = StringCopy(text, COMPOUND_STRING("Remembered regional team"));
    for (i = 0; i < sPreview.memberCount; i++)
    {
        text = StringCopy(text, COMPOUND_STRING("\p"));
        text = ConvertIntToDecimalStringN(text, i + 1, STR_CONV_MODE_LEFT_ALIGN, 1);
        text = StringCopy(text, COMPOUND_STRING(". "));
        if (sPreview.memberState[i] == REGIONAL_MEMBER_AVAILABLE)
        {
            text = StringCopy(text, sPreview.names[i]);
            text = StringCopy(text, COMPOUND_STRING("\n"));
            text = StringCopy(text, GetSpeciesName(sPreview.species[i]));
        }
        else
        {
            if (sPreview.species[i] < NUM_SPECIES)
                text = StringCopy(text, GetSpeciesName(sPreview.species[i]));
            text = StringCopy(text, COMPOUND_STRING("\nUnavailable: "));
            switch (sPreview.memberState[i])
            {
            case REGIONAL_MEMBER_DAYCARE:
                text = StringCopy(text, COMPOUND_STRING("at DAY CARE."));
                break;
            case REGIONAL_MEMBER_AMBIGUOUS:
                text = StringCopy(text, COMPOUND_STRING("identity conflict."));
                break;
            case REGIONAL_MEMBER_FUSED:
                text = StringCopy(text, COMPOUND_STRING("held in a fusion."));
                break;
            default:
                text = StringCopy(text, COMPOUND_STRING("not in party or PC."));
                break;
            }
        }
    }
    text = StringCopy(text, COMPOUND_STRING("\p"));
    if (sPreview.center)
    {
        text = StringCopy(text, COMPOUND_STRING("Resume at "));
        text = StringCopy(text, RegionalCenter_GetName(sPreview.center));
        text = StringCopy(text, COMPOUND_STRING("\nPOKéMON CENTER."));
    }
    else if (sPreview.centerUnavailable && request->resume)
        text = StringCopy(text, COMPOUND_STRING("The remembered CENTER is not safe\nfor this team and current progress.\lUse the standard regional arrival."));
    else if (request->resume)
        text = StringCopy(text, COMPOUND_STRING("No eligible CENTER visit is saved.\nUse the standard regional arrival."));
    else
        text = StringCopy(text, COMPOUND_STRING("Standard regional arrival."));
    if (sPreview.mailCount)
        text = StringCopy(text, COMPOUND_STRING("\pOutgoing held MAIL will move to\nthe PC mailbox with its message."));
    switch (sPreview.result)
    {
    case REGIONAL_TRAVEL_NO_MEMORY:
        StringCopy(text, COMPOUND_STRING("\pThere is no remembered team.\nKeep your current party or use the PC."));
        break;
    case REGIONAL_TRAVEL_NO_USABLE_MON:
        StringCopy(text, COMPOUND_STRING("\pThis team has no usable POKéMON.\nUse the PC or nurse before travel."));
        break;
    case REGIONAL_TRAVEL_PC_FULL:
        StringCopy(text, COMPOUND_STRING("\pThe final team exchange will not fit.\nMake room in the PC BOXES first."));
        break;
    case REGIONAL_TRAVEL_MAILBOX_FULL:
        StringCopy(text, COMPOUND_STRING("\pThe PC mailbox cannot hold the MAIL.\nMake room before recalling this team."));
        break;
    case REGIONAL_TRAVEL_BAD_MAIL:
        StringCopy(text, COMPOUND_STRING("\pA held MAIL record cannot be moved\nsafely. Check your party and mailbox."));
        break;
    case REGIONAL_TRAVEL_IDENTITY_ERROR:
        StringCopy(text, COMPOUND_STRING("\pA party POKéMON cannot be moved\nsafely. Check your party at the PC."));
        break;
    case REGIONAL_TRAVEL_OPENING:
        StringCopy(text, COMPOUND_STRING("\pFinish this region's opening first."));
        break;
    default:
        break;
    }
}

void RegionalTravel_ScrPreview(struct ScriptContext *ctx)
{
    struct RegionalTravelRequest request = ScriptRequest();
    gSpecialVar_Result = RegionalTravel_Preview(&request, &sPreview);
    BufferPreview(&request);
}

void RegionalTravel_ScrCommit(struct ScriptContext *ctx)
{
    struct RegionalTravelRequest request = ScriptRequest();
    gSpecialVar_Result = RegionalTravel_Commit(&request);
    if (gSpecialVar_Result != REGIONAL_TRAVEL_OK)
        BufferPreview(&request);
}

void RegionalTravel_ScrWarp(struct ScriptContext *ctx)
{
    DoWarp();
}
