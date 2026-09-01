#include "global.h"
#include "event_data.h"
#include "script.h"
#include "test/overworld_script.h"
#include "test/test.h"
#include "constants/event_objects.h"
#include "constants/flags.h"
#include "constants/vars.h"

extern const u8 MtMoon_B2F_OnTransition[];
extern const u8 FuchsiaCity_OnTransition[];

static void CallCinnabarCheckRevivedMtMoonFossil(void)
{
    RUN_OVERWORLD_SCRIPT(
        call CinnabarIsland_PokemonLab_ExperimentRoom_EventScript_CheckRevivedMtMoonFossil;
    );
}

static void CallCinnabarCheckAddHelix(void)
{
    RUN_OVERWORLD_SCRIPT(
        call CinnabarIsland_PokemonLab_ExperimentRoom_EventScript_CheckAddHelixFossilToList;
    );
}

static void CallCinnabarCheckAddDome(void)
{
    RUN_OVERWORLD_SCRIPT(
        call CinnabarIsland_PokemonLab_ExperimentRoom_EventScript_CheckAddDomeFossilToList;
    );
}

TEST("Greedy gifts: Mt. Moon OnTransition shows leftover Helix after Dome was taken")
{
    // Old saves hid both fossils behind FLAG_GOT_FOSSIL_FROM_MT_MOON even when
    // Miguel stole the leftover and FLAG_GOT_HELIX_FOSSIL was never set.
    FlagSet(FLAG_GOT_FOSSIL_FROM_MT_MOON);
    FlagSet(FLAG_GOT_DOME_FOSSIL);
    FlagClear(FLAG_GOT_HELIX_FOSSIL);
    FlagSet(FLAG_HIDE_DOME_FOSSIL);
    FlagSet(FLAG_HIDE_HELIX_FOSSIL);

    RunScriptImmediately(MtMoon_B2F_OnTransition);

    EXPECT(FlagGet(FLAG_HIDE_DOME_FOSSIL));
    EXPECT(!FlagGet(FLAG_HIDE_HELIX_FOSSIL));
}

TEST("Greedy gifts: Mt. Moon OnTransition shows leftover Dome after Helix was taken")
{
    FlagSet(FLAG_GOT_FOSSIL_FROM_MT_MOON);
    FlagSet(FLAG_GOT_HELIX_FOSSIL);
    FlagClear(FLAG_GOT_DOME_FOSSIL);
    FlagSet(FLAG_HIDE_DOME_FOSSIL);
    FlagSet(FLAG_HIDE_HELIX_FOSSIL);

    RunScriptImmediately(MtMoon_B2F_OnTransition);

    EXPECT(!FlagGet(FLAG_HIDE_DOME_FOSSIL));
    EXPECT(FlagGet(FLAG_HIDE_HELIX_FOSSIL));
}

TEST("Greedy gifts: Mt. Moon OnTransition shows both fossils when neither was taken")
{
    FlagClear(FLAG_GOT_FOSSIL_FROM_MT_MOON);
    FlagClear(FLAG_GOT_DOME_FOSSIL);
    FlagClear(FLAG_GOT_HELIX_FOSSIL);
    FlagSet(FLAG_HIDE_DOME_FOSSIL);
    FlagSet(FLAG_HIDE_HELIX_FOSSIL);

    RunScriptImmediately(MtMoon_B2F_OnTransition);

    EXPECT(!FlagGet(FLAG_HIDE_DOME_FOSSIL));
    EXPECT(!FlagGet(FLAG_HIDE_HELIX_FOSSIL));
}

TEST("Greedy gifts: Mt. Moon OnTransition hides both fossils when both were taken")
{
    FlagSet(FLAG_GOT_FOSSIL_FROM_MT_MOON);
    FlagSet(FLAG_GOT_DOME_FOSSIL);
    FlagSet(FLAG_GOT_HELIX_FOSSIL);
    FlagClear(FLAG_HIDE_DOME_FOSSIL);
    FlagClear(FLAG_HIDE_HELIX_FOSSIL);

    RunScriptImmediately(MtMoon_B2F_OnTransition);

    EXPECT(FlagGet(FLAG_HIDE_DOME_FOSSIL));
    EXPECT(FlagGet(FLAG_HIDE_HELIX_FOSSIL));
}

TEST("Greedy gifts: Cinnabar does not treat Helix-only revive as done when Dome was also taken")
{
    FlagSet(FLAG_GOT_HELIX_FOSSIL);
    FlagSet(FLAG_GOT_DOME_FOSSIL);
    FlagSet(FLAG_REVIVED_HELIX);
    FlagClear(FLAG_REVIVED_DOME);

    CallCinnabarCheckRevivedMtMoonFossil();

    EXPECT_EQ(VarGet(VAR_RESULT), FALSE);
}

TEST("Greedy gifts: Cinnabar reports Mt. Moon fossils revived only after both obtained fossils are revived")
{
    FlagSet(FLAG_GOT_HELIX_FOSSIL);
    FlagSet(FLAG_GOT_DOME_FOSSIL);
    FlagSet(FLAG_REVIVED_HELIX);
    FlagSet(FLAG_REVIVED_DOME);

    CallCinnabarCheckRevivedMtMoonFossil();

    EXPECT_EQ(VarGet(VAR_RESULT), TRUE);
}

TEST("Greedy gifts: Cinnabar still offers Dome after Helix is revived")
{
    FlagSet(FLAG_GOT_HELIX_FOSSIL);
    FlagSet(FLAG_GOT_DOME_FOSSIL);
    FlagSet(FLAG_REVIVED_HELIX);
    FlagClear(FLAG_REVIVED_DOME);

    CallCinnabarCheckAddHelix();
    EXPECT_EQ(VarGet(VAR_RESULT), FALSE);

    CallCinnabarCheckAddDome();
    EXPECT_EQ(VarGet(VAR_RESULT), TRUE);
}

TEST("Greedy gifts: Cinnabar Helix-only saves still count as revived after Helix")
{
    FlagSet(FLAG_GOT_HELIX_FOSSIL);
    FlagClear(FLAG_GOT_DOME_FOSSIL);
    FlagSet(FLAG_REVIVED_HELIX);
    FlagClear(FLAG_REVIVED_DOME);

    CallCinnabarCheckRevivedMtMoonFossil();

    EXPECT_EQ(VarGet(VAR_RESULT), TRUE);
}

TEST("Greedy gifts: Cinnabar Dome-only saves still count as revived after Dome")
{
    FlagClear(FLAG_GOT_HELIX_FOSSIL);
    FlagSet(FLAG_GOT_DOME_FOSSIL);
    FlagClear(FLAG_REVIVED_HELIX);
    FlagSet(FLAG_REVIVED_DOME);

    CallCinnabarCheckRevivedMtMoonFossil();

    EXPECT_EQ(VarGet(VAR_RESULT), TRUE);
}

TEST("Greedy gifts: Fuchsia exhibit sprite is Kabuto when only Helix was taken")
{
    FlagClear(FLAG_GOT_DOME_FOSSIL);
    FlagSet(FLAG_GOT_HELIX_FOSSIL);

    RunScriptImmediately(FuchsiaCity_OnTransition);

    EXPECT_EQ(VarGet(VAR_OBJ_GFX_ID_0), OBJ_EVENT_GFX_KABUTO);
}

TEST("Greedy gifts: Fuchsia exhibit sprite is Omanyte when only Dome was taken")
{
    FlagSet(FLAG_GOT_DOME_FOSSIL);
    FlagClear(FLAG_GOT_HELIX_FOSSIL);

    RunScriptImmediately(FuchsiaCity_OnTransition);

    EXPECT_EQ(VarGet(VAR_OBJ_GFX_ID_0), OBJ_EVENT_GFX_OMANYTE);
}

TEST("Greedy gifts: Fuchsia exhibit sprite is Omanyte when both fossils were taken")
{
    FlagSet(FLAG_GOT_DOME_FOSSIL);
    FlagSet(FLAG_GOT_HELIX_FOSSIL);

    RunScriptImmediately(FuchsiaCity_OnTransition);

    EXPECT_EQ(VarGet(VAR_OBJ_GFX_ID_0), OBJ_EVENT_GFX_OMANYTE);
}
