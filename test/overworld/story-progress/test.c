#include "global.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "constants/flags.h"
#include "constants/vars.h"
#include "constants/items.h"
#include "constants/regions.h"
#include "story_progress.h"

static u8 flags[65536], items[65536];
static u16 vars[65536];
static struct SaveBlock2 save;
struct SaveBlock2 *gSaveBlock2Ptr = &save;
static enum Region active;
static unsigned assertions;
static const char *covered[256];
static unsigned coveredCount;
bool8 FlagGet(u16 id) { return flags[id]; }
u16 VarGet(u16 id) { return vars[id]; }
bool8 CheckBagHasItem(u16 id, u16 count) { return items[id] >= count; }
bool8 HasBadge(enum Region region, u8 i)
{
    return flags[region == REGION_KANTO ? FLAG_KANTO_BADGE(i)
                 : region == REGION_JOHTO ? FLAG_JOHTO_BADGE(i) : FLAG_BADGE01_GET + i];
}
enum Region GetActiveRegion(void) { return active; }
bool8 IsRegionChampion(enum Region region)
{
    return flags[region == REGION_KANTO ? FLAG_KANTO_CHAMPION
                 : region == REGION_JOHTO ? FLAG_JOHTO_CHAMPION : FLAG_HOENN_CHAMPION];
}
#include "../../../src/story_progress.c"

#define MAP_HEIGHT 15
#define MAP_WIDTH 28
typedef u16 mapsec_u8_t;
#include "../../../src/data/region_map/region_map_layout.h"
#include "../../../src/data/region_map/region_map_layout_kanto.h"
#include "../../../src/data/region_map/region_map_layout_johto.h"
#include "../../../src/data/region_map/region_map_layout_sevii123.h"
#include "../../../src/data/region_map/region_map_layout_sevii45.h"
#include "../../../src/data/region_map/region_map_layout_sevii67.h"

static void Reset(void)
{
    memset(flags, 0, sizeof(flags));
    memset(vars, 0, sizeof(vars));
    memset(items, 0, sizeof(items));
    memset(&save, 0, sizeof(save));
    active = REGION_NONE;
}
static void SetStarted(enum Region r)
{
    if (r == REGION_KANTO) save.kantoIntroDone = TRUE;
    if (r == REGION_JOHTO) save.johtoIntroDone = TRUE;
    if (r == REGION_HOENN) save.hoennIntroDone = TRUE;
}
static void SetFlag(u16 id) { flags[id] = TRUE; }
static void ClearFlag(u16 id) { flags[id] = FALSE; }
static void SetVar(u16 id, u16 val) { vars[id] = val; }
static void SetItem(u16 id) { items[id] = TRUE; }
static void ClearItem(u16 id) { items[id] = FALSE; }
static void SetBadge(enum Region r, u8 i)
{
    SetFlag(r == REGION_KANTO ? FLAG_KANTO_BADGE(i)
            : r == REGION_JOHTO ? FLAG_JOHTO_BADGE(i) : FLAG_BADGE01_GET + i);
}
static void Assert(bool32 ok, const char *message)
{
    assertions++;
    if (!ok) { fprintf(stderr, "FAIL: %s\n", message); exit(1); }
}
static void ValidateDestination(const struct StoryObjective *objective)
{
    const struct StoryDestination *destination = &objective->destination;
    const u16 (*layouts[])[MAP_WIDTH] = {
        sRegionMap_MapSectionLayout, sRegionMapSections_Kanto, sRegionMapSections_Johto,
        sRegionMapSections_Sevii123, sRegionMapSections_Sevii45, sRegionMapSections_Sevii67,
    };
    unsigned found = 0;
    Assert(destination->kind <= STORY_DESTINATION_DYNAMIC, "authored destination has a valid kind");
    if (destination->kind != STORY_DESTINATION_PIN)
    {
        Assert(destination->mapSecId == MAPSEC_NONE, "exemption never invents a map section");
        return;
    }
    Assert(destination->mapSecId < MAPSEC_NONE && destination->mapSecId != MAPSEC_DYNAMIC,
        "pin has a concrete map section");
    for (unsigned layout = 0; layout < ARRAY_COUNT(layouts); layout++)
    {
        bool8 present = FALSE;
        for (unsigned y = 0; y < MAP_HEIGHT; y++)
            for (unsigned x = 0; x < MAP_WIDTH; x++)
                if (layouts[layout][y][x] == destination->mapSecId) present = TRUE;
        found += present;
    }
    if (found != 1) fprintf(stderr, "Invalid destination for %s: %u\n", objective->id, destination->mapSecId);
    Assert(found == 1, "pin belongs to exactly one actual map layout");
}
static void Record(const char *id)
{
    unsigned i;
    for (i = 0; i < coveredCount; i++) if (!strcmp(covered[i], id)) return;
    Assert(coveredCount < ARRAY_COUNT(covered), "objective coverage buffer fits");
    covered[coveredCount++] = id;
}
static void Expect(enum Region r, const char *id)
{
    struct StoryProgress p;
    u8 flagsBefore[65536], itemsBefore[65536];
    u16 varsBefore[65536];
    struct SaveBlock2 saveBefore = save;
    enum Region activeBefore = active;
    memcpy(flagsBefore, flags, sizeof(flags));
    memcpy(varsBefore, vars, sizeof(vars));
    memcpy(itemsBefore, items, sizeof(items));
    StoryProgress_Resolve(r, &p);
    if (strcmp(p.objective->id, id))
    {
        fprintf(stderr, "Region %d: expected %s, got %s\n", r, id, p.objective->id);
        exit(1);
    }
    assertions++;
    Record(p.objective->id);
    ValidateDestination(p.objective);
    Assert(StoryProgress_GetDestination(p.objective)->kind <= STORY_DESTINATION_DYNAMIC, "explicit destination kind");
    Assert(!memcmp(flagsBefore, flags, sizeof(flags)) && !memcmp(varsBefore, vars, sizeof(vars))
           && !memcmp(itemsBefore, items, sizeof(items)) && !memcmp(&saveBefore, &save, sizeof(save))
           && active == activeBefore, "resolver leaves save and campaign state intact");
}
static void ExpectOptional(enum Region r, const char *id)
{
    struct StoryProgress p;
    StoryProgress_Resolve(r, &p);
    Assert(id ? p.optional != NULL && !strcmp(p.optional->id, id) : p.optional == NULL,
           id ? id : "no undiscovered/completed optional lead");
    if (p.optional)
    {
        Record(p.optional->id);
        ValidateDestination(p.optional);
    }
}

#include "kanto_cases.inc"
#include "johto_cases.inc"
#include "hoenn_cases.inc"

static void ExpectPin(enum Region region, bool8 optional, u16 section)
{
    struct StoryProgress progress;
    StoryProgress_Resolve(region, &progress);
    const struct StoryDestination *destination = StoryProgress_GetDestination(optional ? progress.optional : progress.objective);
    if (destination->kind != STORY_DESTINATION_PIN || destination->mapSecId != section)
        fprintf(stderr, "Destination expected %u, got %u\n", section, destination->mapSecId);
    Assert(destination->kind == STORY_DESTINATION_PIN && destination->mapSecId == section,
        "current next action selects its literal expected destination");
}

static void TestDestinationTransitions(void)
{
    Reset();
    SetStarted(REGION_KANTO);
    SetVar(VAR_MAP_SCENE_PALLET_TOWN_PROFESSOR_OAKS_LAB, 4);
    ExpectPin(REGION_KANTO, FALSE, MAPSEC_VIRIDIAN_CITY);
    SetVar(VAR_MAP_SCENE_PALLET_TOWN_PROFESSOR_OAKS_LAB, 5);
    ExpectPin(REGION_KANTO, FALSE, MAPSEC_PALLET_TOWN);
    SetVar(VAR_MAP_SCENE_PALLET_TOWN_PROFESSOR_OAKS_LAB, 6);
    SetFlag(FLAG_KANTO_BADGE_1);
    ExpectPin(REGION_KANTO, FALSE, MAPSEC_ROUTE_4);
    SetVar(VAR_MAP_SCENE_ONE_ISLAND_POKEMON_CENTER_1F, 4);
    ExpectPin(REGION_KANTO, TRUE, MAPSEC_KINDLE_ROAD);
    SetFlag(FLAG_GOT_RUBY);
    ExpectPin(REGION_KANTO, TRUE, MAPSEC_ONE_ISLAND);
    SetVar(VAR_MAP_SCENE_ONE_ISLAND_POKEMON_CENTER_1F, 5);
    ExpectPin(REGION_KANTO, TRUE, MAPSEC_FOUR_ISLAND);
    SetVar(VAR_MAP_SCENE_ICEFALL_CAVE_BACK, 1);
    ExpectPin(REGION_KANTO, TRUE, MAPSEC_RUIN_VALLEY);
    SetFlag(FLAG_LEARNED_YES_NAH_CHANSEY);
    ExpectPin(REGION_KANTO, TRUE, MAPSEC_FIVE_ISLE_MEADOW);
    SetFlag(FLAG_RECOVERED_SAPPHIRE);
    ExpectPin(REGION_KANTO, TRUE, MAPSEC_ONE_ISLAND);
}

int main(void)
{
    struct StoryProgress p;
    Assert(StoryProgress_GetDestination(NULL)->kind == STORY_DESTINATION_DYNAMIC, "unknown objective has no invented pin");
    Assert(StoryProgress_GetDestination(NULL)->mapSecId == MAPSEC_NONE, "unknown objective has no map section");
    Reset();
    Expect(REGION_KANTO, "kanto.not_started");
    Expect(REGION_JOHTO, "johto.not_started");
    Expect(REGION_HOENN, "hoenn.not_started");
    Assert(StoryProgress_DefaultRegion() == REGION_KANTO, "fresh hub starts with Kanto selection");
    active = REGION_JOHTO;
    Assert(StoryProgress_DefaultRegion() == REGION_JOHTO, "hub follows active campaign");
    SetFlag(FLAG_SYS_GAME_CLEAR);
    SetFlag(FLAG_SYS_POKEDEX_GET);
    SetItem(ITEM_HM03);
    Expect(REGION_KANTO, "kanto.not_started");
    Expect(REGION_HOENN, "hoenn.not_started");
    for (enum Region r = REGION_KANTO; r <= REGION_HOENN; r++)
    {
        Reset();
        SetFlag(r == REGION_KANTO ? FLAG_KANTO_CHAMPION : r == REGION_JOHTO
                ? FLAG_JOHTO_CHAMPION : FLAG_HOENN_CHAMPION);
        StoryProgress_Resolve(r, &p);
        Assert(p.status == STORY_COMPLETE, "regional Champion overrides incomplete scenes");
        Assert(p.badges == 0, "badge count is actual regional bits");
        for (enum Region other = REGION_KANTO; other <= REGION_HOENN; other++)
            if (other != r) { StoryProgress_Resolve(other, &p); Assert(p.status == STORY_NOT_STARTED, "Champion isolation"); }
    }
    Reset();
    SetFlag(FLAG_KANTO_BADGE(3));
    SetFlag(FLAG_JOHTO_BADGE(2));
    SetFlag(FLAG_BADGE01_GET);
    StoryProgress_Resolve(REGION_KANTO, &p);
    Assert(p.badges == 1 && p.status == STORY_IN_PROGRESS, "badge implies started on older save");
    TestKanto();
    TestJohto();
    TestHoenn();
    TestDestinationTransitions();
    for (unsigned i = 0; i < coveredCount; i++) printf("COVERED %s\n", covered[i]);
    printf("Story Progress: %u assertions passed\n", assertions);
    return 0;
}
