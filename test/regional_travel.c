#include "global.h"
#include "egg_hatch.h"
#include "event_data.h"
#include "load_save.h"
#include "item.h"
#include "mail.h"
#include "overworld.h"
#include "pokemon.h"
#include "pokemon_storage_system.h"
#include "regional_travel.h"
#include "regions.h"
#include "string_util.h"
#include "test/test.h"
#include "constants/battle.h"
#include "constants/flags.h"
#include "constants/items.h"
#include "constants/maps.h"
#include "constants/moves.h"
#include "constants/vars.h"

void TestCreateShedinja(enum Species preEvoSpecies, enum Species postEvoSpecies, struct Pokemon *mon);

static void ResetTravel(void)
{
    memset(gSaveBlock1Ptr, 0, sizeof(*gSaveBlock1Ptr));
    memset(gSaveBlock2Ptr, 0, sizeof(*gSaveBlock2Ptr));
    memset(gSaveBlock3Ptr, 0, sizeof(*gSaveBlock3Ptr));
    memset(gPokemonStoragePtr, 0, sizeof(*gPokemonStoragePtr));
    ZeroPlayerPartyMons();
    ClearAllMail();
    gSaveBlock3Ptr->region.regionalTravel.nextIdentity = 1;
    SetCurrentRegion(REGION_HOENN);
    FlagSet(GetBadgeFlag(REGION_KANTO, 0));
    FlagSet(GetBadgeFlag(REGION_JOHTO, 0));
    FlagSet(GetBadgeFlag(REGION_HOENN, 0));
    SetWarpDestination(MAP_GROUP(MAP_REGION_HUB), MAP_NUM(MAP_REGION_HUB), 0, 16, 4);
}

static struct Pokemon *MakePartyMon(u32 slot, enum Species species)
{
    struct Pokemon *mon = &gParties[B_TRAINER_PLAYER][slot];
    CreateMon(mon, species, 20, 12345, OTID_STRUCT_PRESET(54321));
    CalculateMonStats(mon);
    CalculatePlayerPartyCount();
    return mon;
}

static u32 MonId(struct Pokemon *mon)
{
    return GetMonData(mon, MON_DATA_REGIONAL_ID);
}

static struct RegionalTravelRequest Recall(enum Region destination)
{
    return (struct RegionalTravelRequest){destination, REGIONAL_TEAM_RECALL, FALSE, FALSE};
}

static void BoxPartyMon(u32 slot, u32 box, u32 position)
{
    struct Pokemon *mon = &gParties[B_TRAINER_PLAYER][slot];
    u32 lost = GetMonData(mon, MON_DATA_MAX_HP) - GetMonData(mon, MON_DATA_HP);
    u32 status = GetMonData(mon, MON_DATA_STATUS);
    SetBoxMonData(&mon->box, MON_DATA_HP_LOST, &lost);
    SetBoxMonData(&mon->box, MON_DATA_STATUS, &status);
    SetBoxMonAt(box, position, &mon->box);
    ZeroMonData(mon);
    CalculatePlayerPartyCount();
}

static u32 HashBytes(u32 hash, const void *data, u32 size)
{
    const u8 *bytes = data;
    while (size--)
        hash = (hash ^ *bytes++) * 16777619;
    return hash;
}

static u32 TravelStateHash(void)
{
    u32 hash = 2166136261u;
    hash = HashBytes(hash, gSaveBlock1Ptr, sizeof(*gSaveBlock1Ptr));
    hash = HashBytes(hash, gSaveBlock2Ptr, sizeof(*gSaveBlock2Ptr));
    hash = HashBytes(hash, gSaveBlock3Ptr, sizeof(*gSaveBlock3Ptr));
    hash = HashBytes(hash, gPokemonStoragePtr, sizeof(*gPokemonStoragePtr));
    hash = HashBytes(hash, gParties[B_TRAINER_PLAYER], sizeof(gParties[B_TRAINER_PLAYER]));
    hash = HashBytes(hash, &gPartiesCount[B_TRAINER_PLAYER], sizeof(gPartiesCount[B_TRAINER_PLAYER]));
    return HashBytes(hash, &gCurrentRegion, sizeof(gCurrentRegion));
}

static u32 CountIdentity(u32 identity)
{
    u32 box, slot, count = 0;
    for (slot = 0; slot < PARTY_SIZE; slot++)
        if (GetMonData(&gParties[B_TRAINER_PLAYER][slot], MON_DATA_SPECIES) != SPECIES_NONE
         && MonId(&gParties[B_TRAINER_PLAYER][slot]) == identity)
            count++;
    for (box = 0; box < TOTAL_BOXES_COUNT; box++)
        for (slot = 0; slot < IN_BOX_COUNT; slot++)
            if (GetBoxMonDataAt(box, slot, MON_DATA_SPECIES) != SPECIES_NONE
             && GetBoxMonDataAt(box, slot, MON_DATA_REGIONAL_ID) == identity)
                count++;
    return count;
}

static void FillPC(void)
{
    struct Pokemon filler;
    u32 box, slot;
    CreateMon(&filler, SPECIES_MAGIKARP, 5, 12345, OTID_STRUCT_PRESET(54321));
    for (box = 0; box < TOTAL_BOXES_COUNT; box++)
        for (slot = 0; slot < IN_BOX_COUNT; slot++)
            SetBoxMonAt(box, slot, &filler.box);
}

TEST("Regional travel identity uses all twenty bits without changing Pokemon data")
{
    struct Pokemon mon;
    u32 identity = 0;
    PARAMETRIZE { identity = 1; }
    PARAMETRIZE { identity = 0x55555; }
    PARAMETRIZE { identity = REGIONAL_ID_MAX; }
    CreateMon(&mon, SPECIES_PIKACHU, 20, 12345, OTID_STRUCT_PRESET(54321));
    SetMonData(&mon, MON_DATA_REGIONAL_ID, &identity);
    EXPECT_EQ(MonId(&mon), identity);
    EXPECT_EQ(GetMonData(&mon, MON_DATA_SPECIES), SPECIES_PIKACHU);
    EXPECT_EQ(GetMonData(&mon, MON_DATA_PERSONALITY), 12345);
    EXPECT_EQ(GetMonData(&mon, MON_DATA_OT_ID), 54321);
    EXPECT_EQ(GetMonData(&mon, MON_DATA_SANITY_IS_BAD_EGG), FALSE);
    EXPECT_EQ(sizeof(struct BoxPokemon), 80);
    EXPECT_EQ(sizeof(struct Pokemon), 100);
}

TEST("Regional travel records ordered distinct individuals with identical personality and OT")
{
    ResetTravel();
    MakePartyMon(0, SPECIES_PIKACHU);
    MakePartyMon(1, SPECIES_PIKACHU);
    EXPECT(RegionalTravel_RecordDeparture(REGION_JOHTO));
    EXPECT_EQ(gSaveBlock3Ptr->region.regionalTravel.teams[1].count, 2);
    EXPECT_EQ(MonId(&gParties[B_TRAINER_PLAYER][0]), 1);
    EXPECT_EQ(MonId(&gParties[B_TRAINER_PLAYER][1]), 2);
    EXPECT_EQ(gSaveBlock3Ptr->region.regionalTravel.teams[1].members[0].identity, 1);
    EXPECT_EQ(gSaveBlock3Ptr->region.regionalTravel.teams[1].members[1].identity, 2);
}

TEST("Regional travel neutral departure and repeated previews preserve recorded memory")
{
    struct RegionalTravelPreview preview;
    struct RegionalTravelRequest request = Recall(REGION_JOHTO);
    u32 before;
    ResetTravel();
    MakePartyMon(0, SPECIES_PIKACHU);
    ASSUME(RegionalTravel_RecordDeparture(REGION_JOHTO));
    BoxPartyMon(0, 0, 0);
    MakePartyMon(0, SPECIES_BULBASAUR);
    before = TravelStateHash();
    EXPECT(RegionalTravel_RecordDeparture(REGION_NONE));
    EXPECT_EQ(RegionalTravel_Preview(&request, &preview), REGIONAL_TRAVEL_OK);
    EXPECT_EQ(RegionalTravel_Preview(&request, &preview), REGIONAL_TRAVEL_OK);
    EXPECT_EQ(TravelStateHash(), before);
    EXPECT_EQ(gSaveBlock3Ptr->region.regionalTravel.teams[1].members[0].lastSpecies, SPECIES_PIKACHU);
}

TEST("Regional travel recalls latest shared individual after evolution training rename and PC movement")
{
    struct RegionalTravelRequest request = Recall(REGION_KANTO);
    struct Pokemon *mon;
    u32 species = SPECIES_RAICHU, move = MOVE_THUNDERBOLT, item = ITEM_MAGNET;
    u32 hp = 7, status = STATUS1_POISON, exp;
    static const u8 name[] = _("SPARK");
    ResetTravel();
    mon = MakePartyMon(0, SPECIES_PIKACHU);
    ASSUME(RegionalTravel_RecordDeparture(REGION_KANTO));
    ASSUME(RegionalTravel_RecordDeparture(REGION_JOHTO));
    SetMonData(mon, MON_DATA_SPECIES, &species);
    SetMonData(mon, MON_DATA_NICKNAME, name);
    SetMonData(mon, MON_DATA_MOVE1, &move);
    SetMonData(mon, MON_DATA_HELD_ITEM, &item);
    exp = GetMonData(mon, MON_DATA_EXP) + 5000;
    SetMonData(mon, MON_DATA_EXP, &exp);
    CalculateMonStats(mon);
    SetMonData(mon, MON_DATA_HP, &hp);
    SetMonData(mon, MON_DATA_STATUS, &status);
    BoxPartyMon(0, 8, 17);
    MakePartyMon(0, SPECIES_BULBASAUR);
    EXPECT_EQ(RegionalTravel_Commit(&request), REGIONAL_TRAVEL_OK);
    EXPECT_EQ(GetMonData(mon, MON_DATA_SPECIES), SPECIES_RAICHU);
    EXPECT_EQ(GetMonData(mon, MON_DATA_MOVE1), MOVE_THUNDERBOLT);
    EXPECT_EQ(GetMonData(mon, MON_DATA_HELD_ITEM), ITEM_MAGNET);
    EXPECT_EQ(GetMonData(mon, MON_DATA_EXP), exp);
    EXPECT_EQ(GetMonData(mon, MON_DATA_HP), 7);
    EXPECT_EQ(GetMonData(mon, MON_DATA_STATUS), STATUS1_POISON);
    GetMonData(mon, MON_DATA_NICKNAME, gStringVar1);
    EXPECT_EQ(StringCompare(gStringVar1, name), 0);
    EXPECT_EQ(CountIdentity(1), 1);
    request.destination = REGION_JOHTO;
    EXPECT_EQ(RegionalTravel_Commit(&request), REGIONAL_TRAVEL_OK);
    EXPECT_EQ(MonId(mon), 1);
    EXPECT_EQ(CountIdentity(1), 1);
    EXPECT_EQ(GetMonData(mon, MON_DATA_HP), 7);
}

TEST("Regional travel supports every directed pair and same-region return")
{
    u32 source = REGION_KANTO, target = REGION_KANTO;
    u32 s, t;
    struct RegionalTravelRequest request;
    for (s = REGION_KANTO; s <= REGION_HOENN; s++)
        for (t = REGION_KANTO; t <= REGION_HOENN; t++)
            PARAMETRIZE { source = s; target = t; }
    ResetTravel();
    MakePartyMon(0, SPECIES_PIKACHU);
    ASSUME(RegionalTravel_RecordDeparture(target));
    BoxPartyMon(0, 2, 3);
    MakePartyMon(0, SPECIES_BULBASAUR);
    SetCurrentRegion(source);
    request = Recall(target);
    EXPECT_EQ(RegionalTravel_Commit(&request), REGIONAL_TRAVEL_OK);
    EXPECT_EQ(gCurrentRegion, target);
    EXPECT_EQ(gSaveBlock2Ptr->currentRegion, target);
    EXPECT_EQ(GetMonData(&gParties[B_TRAINER_PLAYER][0], MON_DATA_SPECIES), SPECIES_PIKACHU);
    EXPECT_EQ(CountIdentity(1), 1);
}

TEST("Regional travel full-PC exchanges use incoming slots for one or six outgoing members")
{
    u32 count = 1, i;
    struct RegionalTravelRequest request = Recall(REGION_JOHTO);
    PARAMETRIZE { count = 1; }
    PARAMETRIZE { count = PARTY_SIZE; }
    ResetTravel();
    FillPC();
    for (i = 0; i < count; i++)
        MakePartyMon(i, SPECIES_PIKACHU);
    ASSUME(RegionalTravel_RecordDeparture(REGION_JOHTO));
    for (i = 0; i < count; i++)
        BoxPartyMon(i, TOTAL_BOXES_COUNT - 1, IN_BOX_COUNT - 1 - i);
    for (i = 0; i < count; i++)
        MakePartyMon(i, SPECIES_BULBASAUR);
    EXPECT_EQ(RegionalTravel_Commit(&request), REGIONAL_TRAVEL_OK);
    EXPECT_EQ(gPartiesCount[B_TRAINER_PLAYER], count);
    EXPECT_EQ(CountAllStorageMons(), TOTAL_BOXES_COUNT * IN_BOX_COUNT);
    for (i = 0; i < count; i++)
    {
        EXPECT_EQ(MonId(&gParties[B_TRAINER_PLAYER][i]), i + 1);
        EXPECT_EQ(CountIdentity(i + 1), 1);
    }
}

TEST("Regional travel impossible full-PC exchange refuses without any state change")
{
    struct RegionalTravelRequest request = Recall(REGION_JOHTO);
    u32 before;
    const struct MapHeader *destination;
    ResetTravel();
    FillPC();
    MakePartyMon(0, SPECIES_PIKACHU);
    ASSUME(RegionalTravel_RecordDeparture(REGION_JOHTO));
    BoxPartyMon(0, 13, 29);
    MakePartyMon(0, SPECIES_BULBASAUR);
    MakePartyMon(1, SPECIES_CHARMANDER);
    before = TravelStateHash();
    destination = GetDestinationWarpMapHeader();
    EXPECT_EQ(RegionalTravel_Commit(&request), REGIONAL_TRAVEL_PC_FULL);
    EXPECT_EQ(TravelStateHash(), before);
    EXPECT_EQ(GetDestinationWarpMapHeader(), destination);
}

TEST("Regional travel retains overlapping carried members in remembered order and remaps follower")
{
    struct RegionalTravelRequest request = Recall(REGION_JOHTO);
    struct Pokemon swap;
    ResetTravel();
    MakePartyMon(0, SPECIES_PIKACHU);
    MakePartyMon(1, SPECIES_BULBASAUR);
    ASSUME(RegionalTravel_RecordDeparture(REGION_JOHTO));
    swap = gParties[B_TRAINER_PLAYER][0];
    gParties[B_TRAINER_PLAYER][0] = gParties[B_TRAINER_PLAYER][1];
    gParties[B_TRAINER_PLAYER][1] = swap;
    gSaveBlock2Ptr->followerSlot = 1;
    EXPECT_EQ(RegionalTravel_Commit(&request), REGIONAL_TRAVEL_OK);
    EXPECT_EQ(MonId(&gParties[B_TRAINER_PLAYER][0]), 1);
    EXPECT_EQ(MonId(&gParties[B_TRAINER_PLAYER][1]), 2);
    EXPECT_EQ(gSaveBlock2Ptr->followerSlot, 2);
    EXPECT_EQ(CountAllStorageMons(), 0);
    EXPECT_EQ(CountIdentity(1), 1);
    EXPECT_EQ(CountIdentity(2), 1);
}

TEST("Regional travel clears a follower that leaves the final party")
{
    struct RegionalTravelRequest request = Recall(REGION_JOHTO);
    ResetTravel();
    MakePartyMon(0, SPECIES_PIKACHU);
    ASSUME(RegionalTravel_RecordDeparture(REGION_JOHTO));
    BoxPartyMon(0, 0, 0);
    MakePartyMon(0, SPECIES_BULBASAUR);
    gSaveBlock2Ptr->followerSlot = 1;
    EXPECT_EQ(RegionalTravel_Commit(&request), REGIONAL_TRAVEL_OK);
    EXPECT_EQ(gSaveBlock2Ptr->followerSlot, 0);
}

TEST("Regional travel missing daycare and fused members require explicit partial confirmation")
{
    u32 unavailable = REGIONAL_MEMBER_MISSING, before;
    struct RegionalTravelPreview preview;
    struct RegionalTravelRequest request = Recall(REGION_JOHTO);
    PARAMETRIZE { unavailable = REGIONAL_MEMBER_MISSING; }
    PARAMETRIZE { unavailable = REGIONAL_MEMBER_DAYCARE; }
    PARAMETRIZE { unavailable = REGIONAL_MEMBER_FUSED; }
    ResetTravel();
    MakePartyMon(0, SPECIES_PIKACHU);
    MakePartyMon(1, SPECIES_BULBASAUR);
    ASSUME(RegionalTravel_RecordDeparture(REGION_JOHTO));
    if (unavailable == REGIONAL_MEMBER_DAYCARE)
        gSaveBlock1Ptr->daycare.mons[0].mon = gParties[B_TRAINER_PLAYER][0].box;
    else if (unavailable == REGIONAL_MEMBER_FUSED)
        gPokemonStoragePtr->fusions[0] = gParties[B_TRAINER_PLAYER][0];
    ZeroMonData(&gParties[B_TRAINER_PLAYER][0]);
    CalculatePlayerPartyCount();
    before = TravelStateHash();
    EXPECT_EQ(RegionalTravel_Preview(&request, &preview), REGIONAL_TRAVEL_PARTIAL);
    EXPECT_EQ(preview.memberState[0], unavailable);
    EXPECT_EQ(preview.species[0], SPECIES_PIKACHU);
    EXPECT_EQ(preview.memberState[1], REGIONAL_MEMBER_AVAILABLE);
    EXPECT_EQ(preview.availableCount, 1);
    EXPECT_EQ(RegionalTravel_Commit(&request), REGIONAL_TRAVEL_PARTIAL);
    EXPECT_EQ(TravelStateHash(), before);
    request.partialConfirmed = TRUE;
    EXPECT_EQ(RegionalTravel_Commit(&request), REGIONAL_TRAVEL_OK);
    EXPECT_EQ(gPartiesCount[B_TRAINER_PLAYER], 1);
    EXPECT_EQ(MonId(&gParties[B_TRAINER_PLAYER][0]), 2);
    EXPECT_EQ(gSaveBlock3Ptr->region.regionalTravel.teams[1].count, 2);
    EXPECT(RegionalTravel_RecordDeparture(REGION_JOHTO));
    EXPECT_EQ(gSaveBlock3Ptr->region.regionalTravel.teams[1].count, 1);
    EXPECT_EQ(gSaveBlock3Ptr->region.regionalTravel.teams[1].members[0].identity, 2);
}

TEST("Regional travel ambiguous identity cannot choose a party PC or daycare copy")
{
    u32 duplicateOwner = 0, before;
    struct RegionalTravelPreview preview;
    struct RegionalTravelRequest request = Recall(REGION_JOHTO);
    PARAMETRIZE { duplicateOwner = 0; }
    PARAMETRIZE { duplicateOwner = 1; }
    PARAMETRIZE { duplicateOwner = 2; }
    ResetTravel();
    MakePartyMon(0, SPECIES_PIKACHU);
    MakePartyMon(1, SPECIES_BULBASAUR);
    ASSUME(RegionalTravel_RecordDeparture(REGION_JOHTO));
    if (duplicateOwner == 0)
        SetBoxMonAt(0, 0, &gParties[B_TRAINER_PLAYER][0].box);
    else if (duplicateOwner == 1)
        gSaveBlock1Ptr->daycare.mons[0].mon = gParties[B_TRAINER_PLAYER][0].box;
    else
        gSaveBlock3Ptr->region.route5DayCareMon.mon = gParties[B_TRAINER_PLAYER][0].box;
    before = TravelStateHash();
    EXPECT_EQ(RegionalTravel_Preview(&request, &preview), REGIONAL_TRAVEL_PARTIAL);
    EXPECT_EQ(preview.memberState[0], REGIONAL_MEMBER_AMBIGUOUS);
    EXPECT_EQ(TravelStateHash(), before);
    EXPECT(!RegionalTravel_RecordDeparture(REGION_JOHTO));
    EXPECT_EQ(TravelStateHash(), before);
}

TEST("Regional travel no usable recalled member refuses safely")
{
    u32 unusable = 0, value, before;
    struct RegionalTravelRequest request = Recall(REGION_JOHTO);
    PARAMETRIZE { unusable = 0; }
    PARAMETRIZE { unusable = 1; }
    PARAMETRIZE { unusable = 2; }
    ResetTravel();
    MakePartyMon(0, SPECIES_PIKACHU);
    ASSUME(RegionalTravel_RecordDeparture(REGION_JOHTO));
    if (unusable == 0)
        ZeroMonData(&gParties[B_TRAINER_PLAYER][0]);
    else if (unusable == 1)
    {
        value = TRUE;
        SetMonData(&gParties[B_TRAINER_PLAYER][0], MON_DATA_IS_EGG, &value);
    }
    else
    {
        value = 0;
        SetMonData(&gParties[B_TRAINER_PLAYER][0], MON_DATA_HP, &value);
    }
    CalculatePlayerPartyCount();
    request.partialConfirmed = TRUE;
    before = TravelStateHash();
    EXPECT_EQ(RegionalTravel_Commit(&request), REGIONAL_TRAVEL_NO_USABLE_MON);
    EXPECT_EQ(TravelStateHash(), before);
}

TEST("Regional travel keep-current validates usability without healing or storage side effects")
{
    struct RegionalTravelRequest request = {REGION_JOHTO, REGIONAL_TEAM_KEEP, FALSE, FALSE};
    struct Pokemon beforeParty;
    u32 hp = 7, status = STATUS1_POISON, boxesBefore;
    ResetTravel();
    MakePartyMon(0, SPECIES_PIKACHU);
    SetMonData(&gParties[B_TRAINER_PLAYER][0], MON_DATA_HP, &hp);
    SetMonData(&gParties[B_TRAINER_PLAYER][0], MON_DATA_STATUS, &status);
    gSaveBlock2Ptr->followerSlot = 1;
    beforeParty = gParties[B_TRAINER_PLAYER][0];
    boxesBefore = HashBytes(0, gPokemonStoragePtr, sizeof(*gPokemonStoragePtr));
    EXPECT_EQ(RegionalTravel_Commit(&request), REGIONAL_TRAVEL_OK);
    EXPECT_EQ(memcmp(&beforeParty, &gParties[B_TRAINER_PLAYER][0], sizeof(beforeParty)), 0);
    EXPECT_EQ(HashBytes(0, gPokemonStoragePtr, sizeof(*gPokemonStoragePtr)), boxesBefore);
    EXPECT_EQ(gSaveBlock2Ptr->followerSlot, 1);
    hp = 0;
    SetMonData(&gParties[B_TRAINER_PLAYER][0], MON_DATA_HP, &hp);
    boxesBefore = TravelStateHash();
    EXPECT_EQ(RegionalTravel_Commit(&request), REGIONAL_TRAVEL_NO_USABLE_MON);
    EXPECT_EQ(TravelStateHash(), boxesBefore);
}

TEST("Regional travel mail text and ownership survive outgoing deposit and retained member reorder")
{
    struct RegionalTravelRequest request = Recall(REGION_JOHTO);
    struct Mail outgoing, retained;
    u32 mail1, mail2;
    ResetTravel();
    MakePartyMon(0, SPECIES_PIKACHU);
    ASSUME(RegionalTravel_RecordDeparture(REGION_JOHTO));
    MakePartyMon(1, SPECIES_BULBASAUR);
    mail1 = GiveMailToMonByItemId(&gParties[B_TRAINER_PLAYER][0], ITEM_ORANGE_MAIL);
    mail2 = GiveMailToMonByItemId(&gParties[B_TRAINER_PLAYER][1], ITEM_HARBOR_MAIL);
    ASSUME(mail1 < PARTY_SIZE && mail2 < PARTY_SIZE);
    gSaveBlock1Ptr->mail[mail1].words[0] = 17;
    gSaveBlock1Ptr->mail[mail2].words[0] = 23;
    retained = gSaveBlock1Ptr->mail[mail1];
    outgoing = gSaveBlock1Ptr->mail[mail2];
    EXPECT_EQ(RegionalTravel_Commit(&request), REGIONAL_TRAVEL_OK);
    EXPECT_EQ(GetMonData(&gParties[B_TRAINER_PLAYER][0], MON_DATA_MAIL), mail1);
    EXPECT_EQ(GetMonData(&gParties[B_TRAINER_PLAYER][0], MON_DATA_HELD_ITEM), ITEM_ORANGE_MAIL);
    EXPECT_EQ(memcmp(&gSaveBlock1Ptr->mail[mail1], &retained, sizeof(retained)), 0);
    EXPECT_EQ(memcmp(&gSaveBlock1Ptr->mail[PARTY_SIZE], &outgoing, sizeof(outgoing)), 0);
    EXPECT_EQ(gSaveBlock1Ptr->mail[mail2].itemId, ITEM_NONE);
    EXPECT_EQ(GetBoxMonDataAt(0, 0, MON_DATA_HELD_ITEM), ITEM_NONE);
}

TEST("Regional travel full mailbox refuses before moving Pokemon or detaching mail")
{
    struct RegionalTravelRequest request = Recall(REGION_JOHTO);
    u32 i, before;
    ResetTravel();
    MakePartyMon(0, SPECIES_PIKACHU);
    ASSUME(RegionalTravel_RecordDeparture(REGION_JOHTO));
    BoxPartyMon(0, 0, 0);
    MakePartyMon(0, SPECIES_BULBASAUR);
    ASSUME(GiveMailToMonByItemId(&gParties[B_TRAINER_PLAYER][0], ITEM_ORANGE_MAIL) < PARTY_SIZE);
    for (i = PARTY_SIZE; i < MAIL_COUNT; i++)
        gSaveBlock1Ptr->mail[i].itemId = ITEM_HARBOR_MAIL;
    before = TravelStateHash();
    EXPECT_EQ(RegionalTravel_Commit(&request), REGIONAL_TRAVEL_MAILBOX_FULL);
    EXPECT_EQ(TravelStateHash(), before);
}

TEST("Regional travel preview and refused capture never repair unrelated corrupt boxed data")
{
    struct RegionalTravelRequest request = Recall(REGION_JOHTO);
    struct RegionalTravelPreview preview;
    u32 before;
    ResetTravel();
    MakePartyMon(0, SPECIES_PIKACHU);
    ASSUME(RegionalTravel_RecordDeparture(REGION_JOHTO));
    SetBoxMonAt(0, 0, &gParties[B_TRAINER_PLAYER][0].box);
    gPokemonStoragePtr->boxes[0][0].checksum ^= 1;
    before = TravelStateHash();
    EXPECT_EQ(RegionalTravel_Preview(&request, &preview), REGIONAL_TRAVEL_OK);
    EXPECT_EQ(TravelStateHash(), before);
    MakePartyMon(1, SPECIES_BULBASAUR);
    MakePartyMon(2, SPECIES_CHARMANDER);
    gSaveBlock3Ptr->region.regionalTravel.nextIdentity = REGIONAL_ID_MAX;
    before = TravelStateHash();
    EXPECT(!RegionalTravel_RecordDeparture(REGION_JOHTO));
    EXPECT_EQ(TravelStateHash(), before);
}

TEST("Regional travel full-PC exchange preserves corrupt occupied slots")
{
    struct RegionalTravelRequest request = Recall(REGION_JOHTO);
    struct BoxPokemon corruptBefore;
    ResetTravel();
    FillPC();
    MakePartyMon(0, SPECIES_PIKACHU);
    ASSUME(RegionalTravel_RecordDeparture(REGION_JOHTO));
    BoxPartyMon(0, TOTAL_BOXES_COUNT - 1, IN_BOX_COUNT - 1);
    MakePartyMon(0, SPECIES_BULBASAUR);
    gPokemonStoragePtr->boxes[0][0].checksum ^= 1;
    corruptBefore = gPokemonStoragePtr->boxes[0][0];
    EXPECT_EQ(RegionalTravel_Commit(&request), REGIONAL_TRAVEL_OK);
    EXPECT_EQ(memcmp(&corruptBefore, &gPokemonStoragePtr->boxes[0][0], sizeof(corruptBefore)), 0);
    EXPECT_EQ(GetBoxMonDataAt(TOTAL_BOXES_COUNT - 1, IN_BOX_COUNT - 1, MON_DATA_SPECIES), SPECIES_BULBASAUR);
    EXPECT_EQ(GetMonData(&gParties[B_TRAINER_PLAYER][0], MON_DATA_SPECIES), SPECIES_PIKACHU);
}

TEST("Regional travel corrupt outgoing party refuses exchange without mutation")
{
    struct RegionalTravelRequest request = Recall(REGION_JOHTO);
    u32 before;
    ResetTravel();
    MakePartyMon(0, SPECIES_PIKACHU);
    ASSUME(RegionalTravel_RecordDeparture(REGION_JOHTO));
    BoxPartyMon(0, 0, 0);
    MakePartyMon(0, SPECIES_BULBASAUR);
    gParties[B_TRAINER_PLAYER][0].box.checksum ^= 1;
    before = TravelStateHash();
    EXPECT_EQ(RegionalTravel_Commit(&request), REGIONAL_TRAVEL_IDENTITY_ERROR);
    EXPECT_EQ(TravelStateHash(), before);
}

TEST("Regional travel allocation exhaustion does not partially assign IDs or replace memory")
{
    u32 before;
    ResetTravel();
    MakePartyMon(0, SPECIES_PIKACHU);
    MakePartyMon(1, SPECIES_BULBASAUR);
    gSaveBlock3Ptr->region.regionalTravel.nextIdentity = REGIONAL_ID_MAX;
    before = TravelStateHash();
    EXPECT(!RegionalTravel_RecordDeparture(REGION_JOHTO));
    EXPECT_EQ(TravelStateHash(), before);
    EXPECT_EQ(MonId(&gParties[B_TRAINER_PLAYER][0]), 0);
    EXPECT_EQ(MonId(&gParties[B_TRAINER_PLAYER][1]), 0);
}

TEST("Regional travel allocation does not reuse a released member reference")
{
    u32 oldIdentity;
    ResetTravel();
    MakePartyMon(0, SPECIES_PIKACHU);
    ASSUME(RegionalTravel_RecordDeparture(REGION_JOHTO));
    oldIdentity = MonId(&gParties[B_TRAINER_PLAYER][0]);
    MakePartyMon(0, SPECIES_PIKACHU);
    gSaveBlock3Ptr->region.regionalTravel.nextIdentity = oldIdentity;
    EXPECT(RegionalTravel_RecordDeparture(REGION_KANTO));
    EXPECT_EQ(MonId(&gParties[B_TRAINER_PLAYER][0]), oldIdentity + 1);
    EXPECT_EQ(gSaveBlock3Ptr->region.regionalTravel.teams[1].members[0].identity, oldIdentity);
}

TEST("Regional travel egg hatch retains the remembered individual's identity")
{
    u32 egg = TRUE;
    ResetTravel();
    MakePartyMon(0, SPECIES_TOGEPI);
    SetMonData(&gParties[B_TRAINER_PLAYER][0], MON_DATA_IS_EGG, &egg);
    ASSUME(RegionalTravel_RecordDeparture(REGION_JOHTO));
    gSpecialVar_0x8004 = 0;
    ScriptHatchMon();
    EXPECT_EQ(GetMonData(&gParties[B_TRAINER_PLAYER][0], MON_DATA_IS_EGG), FALSE);
    EXPECT_EQ(MonId(&gParties[B_TRAINER_PLAYER][0]), 1);
    EXPECT_EQ(gSaveBlock3Ptr->region.regionalTravel.teams[1].members[0].identity, 1);
}

TEST("Regional travel split evolution preserves Ninjask memory and assigns Shedinja a new identity")
{
    struct Pokemon *original;
    struct RegionalTravelPreview preview;
    struct RegionalTravelRequest request = Recall(REGION_JOHTO);
    u32 species = SPECIES_NINJASK;
    ResetTravel();
    original = MakePartyMon(0, SPECIES_NINCADA);
    ASSUME(RegionalTravel_RecordDeparture(REGION_JOHTO));
    ASSUME(AddBagItem(ITEM_POKE_BALL, 1));
    SetMonData(original, MON_DATA_SPECIES, &species);
    TestCreateShedinja(SPECIES_NINCADA, SPECIES_NINJASK, original);
    EXPECT_EQ(gPartiesCount[B_TRAINER_PLAYER], 2);
    EXPECT_EQ(GetMonData(original, MON_DATA_SPECIES), SPECIES_NINJASK);
    EXPECT_EQ(MonId(original), 1);
    EXPECT_EQ(GetMonData(&gParties[B_TRAINER_PLAYER][1], MON_DATA_SPECIES), SPECIES_SHEDINJA);
    EXPECT_EQ(MonId(&gParties[B_TRAINER_PLAYER][1]), 0);
    EXPECT(RegionalTravel_RecordDeparture(REGION_KANTO));
    EXPECT_EQ(MonId(&gParties[B_TRAINER_PLAYER][1]), 2);
    EXPECT_EQ(CountIdentity(1), 1);
    EXPECT_EQ(CountIdentity(2), 1);
    EXPECT_EQ(gSaveBlock3Ptr->region.regionalTravel.teams[1].count, 1);
    EXPECT_EQ(gSaveBlock3Ptr->region.regionalTravel.teams[1].members[0].identity, 1);
    EXPECT_EQ(RegionalTravel_Preview(&request, &preview), REGIONAL_TRAVEL_OK);
    EXPECT_EQ(preview.species[0], SPECIES_NINJASK);
}

TEST("Regional travel opening predicates use actual starter handovers rather than narration bits")
{
    ResetTravel();
    FlagClear(GetBadgeFlag(REGION_KANTO, 0));
    FlagClear(GetBadgeFlag(REGION_JOHTO, 0));
    FlagClear(GetBadgeFlag(REGION_HOENN, 0));
    gSaveBlock2Ptr->kantoIntroDone = TRUE;
    gSaveBlock2Ptr->johtoIntroDone = TRUE;
    gSaveBlock2Ptr->hoennIntroDone = TRUE;
    FlagSet(FLAG_SYS_POKEMON_GET);
    VarSet(VAR_LITTLEROOT_INTRO_STATE, 7);
    EXPECT(!RegionalTravel_IsOpeningComplete(REGION_HOENN));
    VarSet(VAR_BIRCH_LAB_STATE, 2);
    EXPECT(!RegionalTravel_IsOpeningComplete(REGION_HOENN));
    VarSet(VAR_BIRCH_LAB_STATE, 3);
    EXPECT(RegionalTravel_IsOpeningComplete(REGION_HOENN));
    VarSet(VAR_MAP_SCENE_PALLET_TOWN_PROFESSOR_OAKS_LAB, 2);
    EXPECT(!RegionalTravel_IsOpeningComplete(REGION_KANTO));
    VarSet(VAR_MAP_SCENE_PALLET_TOWN_PROFESSOR_OAKS_LAB, 4);
    EXPECT(RegionalTravel_IsOpeningComplete(REGION_KANTO));
    FlagSet(FLAG_JOHTO_STARTER_CHOSEN);
    VarSet(VAR_NEWBARKTOWN_LABSTATE, 1);
    EXPECT(!RegionalTravel_IsOpeningComplete(REGION_JOHTO));
    VarSet(VAR_NEWBARKTOWN_LABSTATE, 2);
    EXPECT(RegionalTravel_IsOpeningComplete(REGION_JOHTO));
}

TEST("Regional travel unavailable remembered team defaults to keeping the current party")
{
    u32 before;
    ResetTravel();
    MakePartyMon(0, SPECIES_PIKACHU);
    ASSUME(RegionalTravel_RecordDeparture(REGION_JOHTO));
    MakePartyMon(0, SPECIES_BULBASAUR);
    gSpecialVar_0x8008 = REGION_JOHTO - REGION_KANTO;
    before = TravelStateHash();
    RegionalTravel_ScrPrepare(NULL);
    EXPECT_EQ(gSpecialVar_Result, FALSE);
    EXPECT_EQ(TravelStateHash(), before);
    ASSUME(RegionalTravel_RecordDeparture(REGION_JOHTO));
    before = TravelStateHash();
    RegionalTravel_ScrPrepare(NULL);
    EXPECT_EQ(gSpecialVar_Result, TRUE);
    EXPECT_EQ(TravelStateHash(), before);
}

TEST("Regional travel mature regional progress overrides stale opening variables")
{
    u32 region = REGION_KANTO;
    PARAMETRIZE { region = REGION_KANTO; }
    PARAMETRIZE { region = REGION_JOHTO; }
    PARAMETRIZE { region = REGION_HOENN; }
    ResetTravel();
    EXPECT(RegionalTravel_IsOpeningComplete(region));
}

TEST("Regional travel unfinished opening refuses new choices without mutation")
{
    struct RegionalTravelRequest request = Recall(REGION_JOHTO);
    u32 before;
    ResetTravel();
    MakePartyMon(0, SPECIES_PIKACHU);
    ASSUME(RegionalTravel_RecordDeparture(REGION_JOHTO));
    FlagClear(GetBadgeFlag(REGION_JOHTO, 0));
    before = TravelStateHash();
    EXPECT_EQ(RegionalTravel_Commit(&request), REGIONAL_TRAVEL_OPENING);
    EXPECT_EQ(TravelStateHash(), before);
}

TEST("Regional travel legacy migration clears history and identity padding in every saved owner")
{
    struct Pokemon source;
    u32 identity = REGIONAL_ID_MAX, item = ITEM_MAGNET;
    ResetTravel();
    CreateMon(&source, SPECIES_PIKACHU, 20, 12345, OTID_STRUCT_PRESET(54321));
    SetMonData(&source, MON_DATA_REGIONAL_ID, &identity);
    SetMonData(&source, MON_DATA_HELD_ITEM, &item);
    gSaveBlock1Ptr->playerParty[0] = source;
    gSaveBlock1Ptr->playerPartyCount = 1;
    gSaveBlock1Ptr->daycare.mons[0].mon = source.box;
    gSaveBlock1Ptr->daycare.mons[1].mon = source.box;
    gSaveBlock3Ptr->region.route5DayCareMon.mon = source.box;
    SetBoxMonAt(13, 29, &source.box);
    gPokemonStoragePtr->fusions[3] = source;
    memset(&gSaveBlock3Ptr->region.regionalTravel, 0xA5, sizeof(gSaveBlock3Ptr->region.regionalTravel));
    RegionalTravel_Migrate();
    EXPECT_EQ(gSaveBlock3Ptr->region.regionalTravel.nextIdentity, 1);
    EXPECT_EQ(gSaveBlock3Ptr->region.regionalTravel.teams[0].count, 0);
    EXPECT_EQ(gSaveBlock3Ptr->region.regionalTravel.teams[1].count, 0);
    EXPECT_EQ(gSaveBlock3Ptr->region.regionalTravel.teams[2].count, 0);
    EXPECT_EQ(gSaveBlock3Ptr->region.regionalTravel.center[0], 0);
    EXPECT_EQ(gSaveBlock3Ptr->region.regionalTravel.center[1], 0);
    EXPECT_EQ(gSaveBlock3Ptr->region.regionalTravel.center[2], 0);
    EXPECT_EQ(MonId(&gSaveBlock1Ptr->playerParty[0]), 0);
    EXPECT_EQ(GetBoxMonData(&gSaveBlock1Ptr->daycare.mons[0].mon, MON_DATA_REGIONAL_ID), 0);
    EXPECT_EQ(GetBoxMonData(&gSaveBlock1Ptr->daycare.mons[1].mon, MON_DATA_REGIONAL_ID), 0);
    EXPECT_EQ(GetBoxMonData(&gSaveBlock3Ptr->region.route5DayCareMon.mon, MON_DATA_REGIONAL_ID), 0);
    EXPECT_EQ(GetBoxMonDataAt(13, 29, MON_DATA_REGIONAL_ID), 0);
    EXPECT_EQ(MonId(&gPokemonStoragePtr->fusions[3]), 0);
    EXPECT_EQ(GetMonData(&gSaveBlock1Ptr->playerParty[0], MON_DATA_SPECIES), SPECIES_PIKACHU);
    EXPECT_EQ(GetMonData(&gSaveBlock1Ptr->playerParty[0], MON_DATA_HELD_ITEM), ITEM_MAGNET);
    EXPECT_EQ(GetMonData(&gSaveBlock1Ptr->playerParty[0], MON_DATA_PERSONALITY), 12345);
    EXPECT_EQ(GetMonData(&gSaveBlock1Ptr->playerParty[0], MON_DATA_SANITY_IS_BAD_EGG), FALSE);
}
