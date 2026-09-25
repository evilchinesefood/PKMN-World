#include "global.h"
#include "overworld.h"
#include "pokemon.h"
#include "test/test.h"
#include "constants/items.h"
#include "constants/map_groups.h"
#include "constants/moves.h"

// Evolution-method overrides: many "complicated" evolutions gain a plain level-up
// route while keeping their original method, Eevee gains Sun/Moon/Shiny Stone, and
// the day/night restriction is lifted from Happiny, Gligar and Sneasel. Eevee is
// stones only (its friendship and map rows were removed).
//
// Clock: SetTimeOfDay(hours) overrides the hour GetTimeOfDay() sees. 0 means "no
// override". The override is an EWRAM static the runner does not reset and a failed
// EXPECT exits early, so every test that pins it clears it first as well as last.
#define HOUR_NIGHT 22
#define HOUR_DAY   12

// A mon with no evolution-relevant state: friendship 0, nothing held, and a single
// Tackle, so a "knows move X" original method cannot be the thing that fires.
static void CreateNeutralMon(struct Pokemon *mon, enum Species species, u8 level, u32 personality)
{
    u32 friendship = 0;
    u16 heldItem = ITEM_NONE;
    u16 tackle = MOVE_TACKLE;
    u16 none = MOVE_NONE;

    CreateMon(mon, species, level, personality, OTID_STRUCT_PLAYER_ID);
    SetMonData(mon, MON_DATA_FRIENDSHIP, &friendship);
    SetMonData(mon, MON_DATA_HELD_ITEM, &heldItem);
    SetMonData(mon, MON_DATA_MOVE1, &tackle);
    SetMonData(mon, MON_DATA_MOVE2, &none);
    SetMonData(mon, MON_DATA_MOVE3, &none);
    SetMonData(mon, MON_DATA_MOVE4, &none);
}

static enum Species LevelUpTarget(struct Pokemon *mon)
{
    return GetEvolutionTargetSpecies(mon, EVO_MODE_NORMAL, ITEM_NONE, NULL, NULL, CHECK_EVO);
}

static enum Species ItemUseTarget(struct Pokemon *mon, u16 item)
{
    return GetEvolutionTargetSpecies(mon, EVO_MODE_ITEM_USE, item, NULL, NULL, CHECK_EVO);
}

TEST("Evo methods: new level routes fire at their level and not one below")
{
    enum Species from = SPECIES_NONE, to = SPECIES_NONE;
    u32 level = 0, personality = 0;
    struct Pokemon mon;

    PARAMETRIZE { from = SPECIES_PICHU;      to = SPECIES_PIKACHU;     level = 12; personality = 1; }
    PARAMETRIZE { from = SPECIES_CLEFFA;     to = SPECIES_CLEFAIRY;    level = 12; personality = 1; }
    PARAMETRIZE { from = SPECIES_IGGLYBUFF;  to = SPECIES_JIGGLYPUFF;  level = 12; personality = 1; }
    PARAMETRIZE { from = SPECIES_AZURILL;    to = SPECIES_MARILL;      level = 12; personality = 1; }
    PARAMETRIZE { from = SPECIES_TOGEPI;     to = SPECIES_TOGETIC;     level = 15; personality = 1; }
    PARAMETRIZE { from = SPECIES_BUDEW;      to = SPECIES_ROSELIA;     level = 15; personality = 1; }
    PARAMETRIZE { from = SPECIES_CHINGLING;  to = SPECIES_CHIMECHO;    level = 20; personality = 1; }
    PARAMETRIZE { from = SPECIES_MUNCHLAX;   to = SPECIES_SNORLAX;     level = 30; personality = 1; }
    PARAMETRIZE { from = SPECIES_GOLBAT;     to = SPECIES_CROBAT;      level = 32; personality = 1; }
    PARAMETRIZE { from = SPECIES_CHANSEY;    to = SPECIES_BLISSEY;     level = 40; personality = 1; }
    PARAMETRIZE { from = SPECIES_MANTYKE;    to = SPECIES_MANTINE;     level = 25; personality = 1; }
    PARAMETRIZE { from = SPECIES_LICKITUNG;  to = SPECIES_LICKILICKY;  level = 33; personality = 1; }
    PARAMETRIZE { from = SPECIES_TANGELA;    to = SPECIES_TANGROWTH;   level = 33; personality = 1; }
    PARAMETRIZE { from = SPECIES_YANMA;      to = SPECIES_YANMEGA;     level = 33; personality = 1; }
    PARAMETRIZE { from = SPECIES_AIPOM;      to = SPECIES_AMBIPOM;     level = 32; personality = 1; }
    PARAMETRIZE { from = SPECIES_GIRAFARIG;  to = SPECIES_FARIGIRAF;   level = 32; personality = 1; }
    PARAMETRIZE { from = SPECIES_DUNSPARCE;  to = SPECIES_DUDUNSPARCE_TWO_SEGMENT;   level = 32; personality = 1; }
    PARAMETRIZE { from = SPECIES_DUNSPARCE;  to = SPECIES_DUDUNSPARCE_THREE_SEGMENT; level = 32; personality = 100; }
    PARAMETRIZE { from = SPECIES_BONSLY;     to = SPECIES_SUDOWOODO;   level = 17; personality = 1; }
    PARAMETRIZE { from = SPECIES_MIME_JR;    to = SPECIES_MR_MIME;     level = 18; personality = 1; }
    PARAMETRIZE { from = SPECIES_PILOSWINE;  to = SPECIES_MAMOSWINE;   level = 45; personality = 1; }
    PARAMETRIZE { from = SPECIES_PRIMEAPE;   to = SPECIES_ANNIHILAPE;  level = 35; personality = 1; }
    PARAMETRIZE { from = SPECIES_STANTLER;   to = SPECIES_WYRDEER;     level = 30; personality = 1; }

    // Mantyke's original method is "Remoraid in the party"; keep the party empty.
    ZeroPlayerPartyMons();

    CreateNeutralMon(&mon, from, level, personality);
    EXPECT_EQ(LevelUpTarget(&mon), to);

    CreateNeutralMon(&mon, from, level - 1, personality);
    EXPECT_EQ(LevelUpTarget(&mon), SPECIES_NONE);
}

TEST("Evo methods: Eevee evolves with each of its eight stones")
{
    u16 item = ITEM_NONE;
    enum Species to = SPECIES_NONE;
    struct Pokemon mon;

    PARAMETRIZE { item = ITEM_THUNDER_STONE; to = SPECIES_JOLTEON; }
    PARAMETRIZE { item = ITEM_WATER_STONE;   to = SPECIES_VAPOREON; }
    PARAMETRIZE { item = ITEM_FIRE_STONE;    to = SPECIES_FLAREON; }
    PARAMETRIZE { item = ITEM_SUN_STONE;     to = SPECIES_ESPEON; }
    PARAMETRIZE { item = ITEM_MOON_STONE;    to = SPECIES_UMBREON; }
    PARAMETRIZE { item = ITEM_LEAF_STONE;    to = SPECIES_LEAFEON; }
    PARAMETRIZE { item = ITEM_ICE_STONE;     to = SPECIES_GLACEON; }
    PARAMETRIZE { item = ITEM_SHINY_STONE;   to = SPECIES_SYLVEON; }

    CreateNeutralMon(&mon, SPECIES_EEVEE, 5, 1);
    EXPECT_EQ(ItemUseTarget(&mon, item), to);
}

TEST("Evo methods: Eevee is stones only - no level-up evolution at all")
{
    struct Pokemon mon;
    u32 hour = 0, friendship = 0;
    u16 move = MOVE_NONE, map = MAP_UNDEFINED;

    // The old friendship rows (Espeon by day, Umbreon by night, Sylveon with a Fairy
    // move) are gone: max friendship plus a Fairy move must not evolve, day or night.
    PARAMETRIZE { hour = HOUR_DAY;   friendship = MAX_FRIENDSHIP; move = MOVE_BABY_DOLL_EYES; }
    PARAMETRIZE { hour = HOUR_NIGHT; friendship = MAX_FRIENDSHIP; move = MOVE_BABY_DOLL_EYES; }
    PARAMETRIZE { hour = HOUR_DAY;   friendship = MAX_FRIENDSHIP; move = MOVE_TACKLE; }
    PARAMETRIZE { hour = HOUR_NIGHT; friendship = MAX_FRIENDSHIP; move = MOVE_TACKLE; }
    PARAMETRIZE { hour = HOUR_DAY;   friendship = 0;              move = MOVE_TACKLE; }
    // The old Leafeon / Glaceon rows fired on levelling up in these two maps.
    PARAMETRIZE { hour = HOUR_DAY;   friendship = 0;              move = MOVE_TACKLE; map = MAP_PETALBURG_WOODS; }
    PARAMETRIZE { hour = HOUR_DAY;   friendship = 0;              move = MOVE_TACKLE; map = MAP_SHOAL_CAVE_LOW_TIDE_ICE_ROOM; }

    SetTimeOfDay(0);
    SetTimeOfDay(hour);
    if (map != MAP_UNDEFINED)
    {
        gSaveBlock1Ptr->location.mapGroup = MAP_GROUP(map);
        gSaveBlock1Ptr->location.mapNum = MAP_NUM(map);
    }
    CreateNeutralMon(&mon, SPECIES_EEVEE, 50, 1);
    SetMonData(&mon, MON_DATA_FRIENDSHIP, &friendship);
    SetMonData(&mon, MON_DATA_MOVE1, &move);
    EXPECT_EQ(LevelUpTarget(&mon), SPECIES_NONE);

    CreateNeutralMon(&mon, SPECIES_EEVEE, MAX_LEVEL, 1);
    SetMonData(&mon, MON_DATA_FRIENDSHIP, &friendship);
    SetMonData(&mon, MON_DATA_MOVE1, &move);
    EXPECT_EQ(LevelUpTarget(&mon), SPECIES_NONE);
    SetTimeOfDay(0);
}

TEST("Evo methods: time restriction lifted for Happiny, Gligar and Sneasel")
{
    enum Species from = SPECIES_NONE, to = SPECIES_NONE;
    u16 item = ITEM_NONE;
    u32 hour = 0;
    bool32 heldLevelUp = FALSE;
    u16 heldItem;
    struct Pokemon mon;

    // Happiny used to be day-only; Gligar and Sneasel used to be night-only.
    PARAMETRIZE { from = SPECIES_HAPPINY; to = SPECIES_CHANSEY; item = ITEM_OVAL_STONE; hour = HOUR_NIGHT; heldLevelUp = FALSE; }
    PARAMETRIZE { from = SPECIES_HAPPINY; to = SPECIES_CHANSEY; item = ITEM_OVAL_STONE; hour = HOUR_NIGHT; heldLevelUp = TRUE; }
    PARAMETRIZE { from = SPECIES_GLIGAR;  to = SPECIES_GLISCOR; item = ITEM_RAZOR_FANG; hour = HOUR_DAY;   heldLevelUp = FALSE; }
    PARAMETRIZE { from = SPECIES_GLIGAR;  to = SPECIES_GLISCOR; item = ITEM_RAZOR_FANG; hour = HOUR_DAY;   heldLevelUp = TRUE; }
    PARAMETRIZE { from = SPECIES_SNEASEL; to = SPECIES_WEAVILE; item = ITEM_RAZOR_CLAW; hour = HOUR_DAY;   heldLevelUp = FALSE; }
    PARAMETRIZE { from = SPECIES_SNEASEL; to = SPECIES_WEAVILE; item = ITEM_RAZOR_CLAW; hour = HOUR_DAY;   heldLevelUp = TRUE; }

    SetTimeOfDay(0);
    SetTimeOfDay(hour);
    CreateNeutralMon(&mon, from, 10, 1);

    // Control: with nothing held and no item used, there is no evolution.
    EXPECT_EQ(LevelUpTarget(&mon), SPECIES_NONE);

    if (heldLevelUp)
    {
        heldItem = item;
        SetMonData(&mon, MON_DATA_HELD_ITEM, &heldItem);
        EXPECT_EQ(LevelUpTarget(&mon), to);
    }
    else
    {
        EXPECT_EQ(ItemUseTarget(&mon, item), to);
    }
    SetTimeOfDay(0);
}

TEST("Evo methods: original methods still work below the new level")
{
    struct Pokemon mon;
    u32 friendship = MAX_FRIENDSHIP;
    u16 rollout = MOVE_ROLLOUT;

    ZeroPlayerPartyMons();

    // Friendship: Golbat well below Lv. 32.
    CreateNeutralMon(&mon, SPECIES_GOLBAT, 22, 1);
    SetMonData(&mon, MON_DATA_FRIENDSHIP, &friendship);
    EXPECT_EQ(LevelUpTarget(&mon), SPECIES_CROBAT);

    // Knows a move: Lickitung with Rollout below Lv. 33.
    CreateNeutralMon(&mon, SPECIES_LICKITUNG, 20, 1);
    SetMonData(&mon, MON_DATA_MOVE1, &rollout);
    EXPECT_EQ(LevelUpTarget(&mon), SPECIES_LICKILICKY);

    // Party partner: Mantyke with a Remoraid in the party below Lv. 25.
    CreateNeutralMon(&mon, SPECIES_MANTYKE, 10, 1);
    EXPECT_EQ(LevelUpTarget(&mon), SPECIES_NONE);
    CreateMon(&gParties[B_TRAINER_PLAYER][0], SPECIES_REMORAID, 10, 1, OTID_STRUCT_PLAYER_ID);
    EXPECT_EQ(LevelUpTarget(&mon), SPECIES_MANTINE);
    ZeroPlayerPartyMons();
}

// The HGSS dex evolution page (src/pokedex_plus_hgss.c) lists a species' pre-evolutions and then
// every evolution row, recursing into each target once (under the last row that reaches it). Its
// per-page arrays hold 10 entries and it writes arrowSpriteDist[row + 1] after each row, so a page
// longer than 8 rows writes past the end of sEvoScreenData. Mirror that walk and hold every page to 8.
#define HGSS_DEX_MAX_PAGE_ROWS 8

static u32 CountDexEvolutionRows(enum Species species)
{
    const struct Evolution *evolutions = GetSpeciesEvolutions(species);
    u32 i, j, times = 0, rows = 0;

    if (evolutions == NULL)
        return 0;
    while (evolutions[times].method != EVOLUTIONS_END)
        times++;
    if (times > 10)
        times = 10;
    for (i = 0; i < times; i++)
    {
        enum Species target = evolutions[i].targetSpecies;
        bool32 later = FALSE;
        if (!IsSpeciesEnabled(target))
            continue;
        rows++;
        for (j = i + 1; j < times; j++)
        {
            if (evolutions[j].targetSpecies == target)
                later = TRUE;
        }
        if (!later)
            rows += CountDexEvolutionRows(target);
    }
    return rows;
}

TEST("Evo methods: every dex evolution page fits the page arrays (8 rows)")
{
    u32 species, rows;
    enum Species pre;

    for (species = 1; species < NUM_SPECIES; species++)
    {
        // Milcery's Alcremie table is upstream Gen 8 data (not in this hack) that the dex caps at 9 rows.
        if (!IsSpeciesEnabled(species) || species == SPECIES_MILCERY)
            continue;
        rows = CountDexEvolutionRows(species);
        for (pre = GetSpeciesPreEvolution(species); pre != SPECIES_NONE; pre = GetSpeciesPreEvolution(pre))
            rows++;
        if (rows > HGSS_DEX_MAX_PAGE_ROWS)
            Test_ExitWithResult(TEST_RESULT_FAIL, __LINE__, "%s:%d: species %d (%S) has a %d-row dex evolution page, arrays fit %d",
                gTestRunnerState.test->filename, __LINE__, species, gSpeciesInfo[species].speciesName, rows, HGSS_DEX_MAX_PAGE_ROWS);
    }
}
