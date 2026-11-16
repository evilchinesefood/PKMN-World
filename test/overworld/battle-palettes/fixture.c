// Disposable-ROM fixture only. Normal battle entry still selects the map's
// gameplay environment; no shipped code, map data or save layout is patched.
#define VisualFeatureFixture BWVisualFeatureFixture
#include "../bw-battle-ui/fixture.c"
#undef VisualFeatureFixture
#include "battle_bg.h"
#include "palette.h"
#include "evolution_scene.h"

extern void CaptureBattlePresentation(void) __attribute__((weak));

void VisualFeatureFixture(void)
{
    u32 command = gSpecialVar_0x8004, arg = gSpecialVar_0x8005;
    if (command < 200)
    {
        BWVisualFeatureFixture();
        return;
    }
    SetMainCallback2(command >= 250 ? BattleMainCB2 : CB2_Overworld);
    switch (command)
    {
    case 200:
    {
        static const struct { u16 map; s16 x, y; } locations[] = {
            {MAP_ICE_PATH_1F, 14, 23}, {MAP_ICE_PATH_B1F, 9, 19},
            {MAP_ICE_PATH_B2F, 7, 20}, {MAP_ICE_PATH_B3F, 14, 9},
            {MAP_ICE_PATH_B4F, 9, 17}, {MAP_MT_SILVER_SNOW, 14, 40},
            {MAP_MT_SILVER_SUMMIT_DAY, 10, 20}, {MAP_GRANITE_CAVE_1F, 37, 11},
            {MAP_ROUTE101, 9, 9}, {MAP_ROUTE29, 25, 9}, {MAP_ROUTE1, 10, 10},
        };
        if (arg >= ARRAY_COUNT(locations))
            break;
        gIsDebugBattle = FALSE;
        SetWarpDestination(MAP_GROUP(locations[arg].map), MAP_NUM(locations[arg].map), WARP_ID_NONE, locations[arg].x, locations[arg].y);
        DoWarp();
        break;
    }
    case 201:
    case 250:
        SetTimeOfDay(arg);
        UpdateTimeOfDay(TRUE);
        break;
    case 202:
    {
        static const u16 species[] = {SPECIES_ABSOL, SPECIES_UMBREON, SPECIES_GARDEVOIR};
        SeedParty();
        struct Pokemon *mon = &gParties[B_TRAINER_PLAYER][0];
        CreateMonWithIVs(mon, species[arg % 3], 40, 0x12345678, OTID_STRUCT_PLAYER_ID, 31);
        u32 value = 5;
        SetMonData(mon, MON_DATA_MET_LEVEL, &value);
        value = arg == 2;
        SetMonData(mon, MON_DATA_IS_SHINY, &value);
        SetMonMoveSlot(mon, MOVE_GRASSY_TERRAIN, 0);
        SetMonMoveSlot(mon, MOVE_SPLASH, 1);
        SetMonMoveSlot(mon, MOVE_SURF, 2);
        SetMonMoveSlot(mon, MOVE_SHADOW_BALL, 3);
        break;
    }
    case 204:
        // Exercise the shared loader with a deliberately retained snow snapshot.
        // Evolution must clear it even when called outside normal battle cleanup.
        if (CaptureBattlePresentation)
            CaptureBattlePresentation();
        FreeAllWindowBuffers();
        CreateMonWithIVs(&gParties[B_TRAINER_PLAYER][0], SPECIES_EEVEE, 5, 0x12345678, OTID_STRUCT_PLAYER_ID, 31);
        gCB2_AfterEvolution = CB2_ReturnToField;
        BeginEvolutionScene(&gParties[B_TRAINER_PLAYER][0], SPECIES_VAPOREON, FALSE, 0);
        break;
    case 205:
        gSpecialVar_0x8005 = GetMonData(&gParties[B_TRAINER_PLAYER][0], MON_DATA_SPECIES);
        break;
    case 206:
        // Start the owner on an existing MB_CAVE encounter tile. The entrance
        // approach used for map screenshots has encounter-free mountain tiles.
        gIsDebugBattle = FALSE;
        SetWarpDestination(MAP_GROUP(MAP_ICE_PATH_1F), MAP_NUM(MAP_ICE_PATH_1F), WARP_ID_NONE, 19, 24);
        DoWarp();
        break;
    case 207:
    {
        // One standing tile per battle background. Tile-selected rows stand on that tile type;
        // scene-selected rows stand inside a map whose battle_scene picks the background.
        static const struct { u16 map; s16 x, y; } backgrounds[] = {
            {MAP_ROUTE101, 11, 10},                              // tall grass
            {MAP_ROUTE119, 36, 117},                             // long grass
            {MAP_ROUTE113, 41, 13},                              // sand
            {MAP_ROUTE124, 68, 39},                              // deep water
            {MAP_ROUTE102, 45, 4},                               // pond
            {MAP_UNDERWATER_ROUTE124, 9, 42},                    // underwater
            {MAP_ROUTE114, 5, 61},                               // mountain
            {MAP_GRANITE_CAVE_1F, 37, 11},                       // cave
            {MAP_ROUTE101, 9, 9},                                // plain
            {MAP_OLDALE_TOWN_POKEMON_CENTER_1F, 7, 8},           // building
            {MAP_POWER_PLANT, 4, 38},                            // FRLG indoor scene (not Pokemon Tower: its ghost battles redraw the field)
            {MAP_RUSTBORO_CITY_GYM, 5, 19},                      // Hoenn Gym
            {MAP_VIOLET_CITY_GYM, 9, 19},                        // Johto Gym
            {MAP_AQUA_HIDEOUT_1F, 13, 27},                       // Aqua
            {MAP_BATTLE_FRONTIER_BATTLE_TOWER_BATTLE_ROOM, 5, 8},// Frontier
            {MAP_EVER_GRANDE_CITY_SIDNEYS_ROOM, 6, 13},
            {MAP_EVER_GRANDE_CITY_PHOEBES_ROOM, 6, 13},
            {MAP_EVER_GRANDE_CITY_GLACIAS_ROOM, 6, 13},
            {MAP_EVER_GRANDE_CITY_DRAKES_ROOM, 6, 13},
            {MAP_POKEMON_LEAGUE_LORELEIS_ROOM, 6, 12},
            {MAP_POKEMON_LEAGUE_BRUNOS_ROOM, 6, 12},
            {MAP_POKEMON_LEAGUE_AGATHAS_ROOM, 6, 12},
            {MAP_POKEMON_LEAGUE_LANCES_ROOM, 23, 13},
            {MAP_JOHTO_POKEMON_LEAGUE_WILLS_ROOM, 6, 12},
            {MAP_JOHTO_POKEMON_LEAGUE_KOGAS_ROOM, 6, 2},
            {MAP_JOHTO_POKEMON_LEAGUE_BRUNOS_ROOM, 6, 12},
            {MAP_JOHTO_POKEMON_LEAGUE_KARENS_ROOM, 6, 12},
        };
        if (arg >= ARRAY_COUNT(backgrounds))
            break;
        gIsDebugBattle = FALSE;
        SetWarpDestination(MAP_GROUP(backgrounds[arg].map), MAP_NUM(backgrounds[arg].map), WARP_ID_NONE, backgrounds[arg].x, backgrounds[arg].y);
        DoWarp();
        break;
    }
    case 251:
    {
        // Probe the actual restoration entry points, including all palette banks.
        u16 before[PLTT_BUFFER_SIZE];
        memcpy(before, gPlttBufferUnfaded, sizeof(before));
        u8 environment = gBattleEnvironment;
        if (arg)
            DrawMainBattleBackground();
        else
            for (u32 i = 3; i <= 5; i++)
                LoadChosenBattleElement(i);
        gSpecialVar_0x8005 = BytesEqual(before + 32, gPlttBufferUnfaded + 32, 96);
        gSpecialVar_0x8006 = BytesEqual(before, gPlttBufferUnfaded, 64)
            && BytesEqual(before + 80, gPlttBufferUnfaded + 80, sizeof(before) - 160);
        gSpecialVar_0x8007 = environment == gBattleEnvironment;
        break;
    }
    }
}
