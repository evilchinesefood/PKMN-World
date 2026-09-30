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
    if (p.optional) Record(p.optional->id);
}

#include "kanto_cases.inc"
#include "johto_cases.inc"
#include "hoenn_cases.inc"

int main(void)
{
    struct StoryProgress p;
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
    for (unsigned i = 0; i < coveredCount; i++) printf("COVERED %s\n", covered[i]);
    printf("Story Progress: %u assertions passed\n", assertions);
    return 0;
}
