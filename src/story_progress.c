#include "global.h"
#include "story_progress.h"
#include "event_data.h"
#include "regions.h"
#include "item.h"
#include "constants/flags.h"
#include "constants/vars.h"
#include "constants/items.h"

// All conditions read absolute regional flag/var IDs. No bank/context switch,
// script side effect, quest history, save write or clock read belongs here.
#define F(flag) FlagGet(flag)
#define V(var) VarGet(var)
#define B(region, index) HasBadge(region, index)
#define I(item) CheckBagHasItem(item, 1)
#define STORY_OBJECTIVE(name, stableId, chapterText, recapText, actionText, whereText, whyText) \
    static const struct StoryObjective name = { \
        .id = stableId, .chapter = COMPOUND_STRING(chapterText), \
        .recap = COMPOUND_STRING(recapText), .action = COMPOUND_STRING(actionText), \
        .where = COMPOUND_STRING(whereText), .why = COMPOUND_STRING(whyText) }

STORY_OBJECTIVE(sKantoNotStarted, "kanto.not_started", "Not started",
    "Your Kanto journey awaits.", "Visit the Kanto gate.",
    "World Transit: Kanto attendant", "The gate takes you to Pallet.");
STORY_OBJECTIVE(sJohtoNotStarted, "johto.not_started", "Not started",
    "Your Johto journey awaits.", "Visit the Johto gate.",
    "World Transit: Johto attendant", "The gate takes you to New Bark.");
STORY_OBJECTIVE(sHoennNotStarted, "hoenn.not_started", "Not started",
    "Your Hoenn journey awaits.", "Visit the Hoenn gate.",
    "World Transit: Hoenn attendant", "The gate takes you home.");

#include "data/story_progress/kanto.inc"
#include "data/story_progress/johto.inc"
#include "data/story_progress/hoenn.inc"

static bool8 HasStarted(enum Region region, u8 badges)
{
    if (GetActiveRegion() == region || badges || IsRegionChampion(region))
        return TRUE;
    // Intro bits are not guaranteed in older saves. The opening's own state
    // supplies positive evidence; initial HIDE flags and shared Dex/HMs don't.
    switch (region)
    {
    case REGION_KANTO:
        return gSaveBlock2Ptr->kantoIntroDone || F(FLAG_VISITED_OAKS_LAB)
            || V(VAR_MAP_SCENE_PALLET_TOWN_OAK)
            || V(VAR_MAP_SCENE_PALLET_TOWN_PROFESSOR_OAKS_LAB)
            || F(FLAG_HELPED_BILL_IN_SEA_COTTAGE) || F(FLAG_RESCUED_MR_FUJI)
            || V(VAR_MAP_SCENE_SILPH_CO_11F)
            || V(VAR_MAP_SCENE_ONE_ISLAND_POKEMON_CENTER_1F);
    case REGION_JOHTO:
        return gSaveBlock2Ptr->johtoIntroDone || F(FLAG_JOHTO_STARTER_CHOSEN)
            || V(VAR_NEWBARKTOWN_LABSTATE) || F(FLAG_JOHTO_ADVENTURE_STARTED)
            || V(VAR_VIOLET_CITY_STATE) || V(VAR_SPROUT_TOWER)
            || V(VAR_AZALEA_TOWN_STATE) || V(VAR_GOLDENROD_CITY_STATE)
            || V(VAR_OLIVINE_CITY_STATE) || V(VAR_MAHOGANY_TOWN_STATE)
            || V(VAR_BLACKTHORN_CITY_STATE);
    case REGION_HOENN:
        return gSaveBlock2Ptr->hoennIntroDone || F(FLAG_RESCUED_BIRCH)
            || F(FLAG_RECEIVED_POKEDEX_FROM_BIRCH) || V(VAR_BIRCH_LAB_STATE)
            || V(VAR_LITTLEROOT_INTRO_STATE) || F(FLAG_RECEIVED_POKENAV)
            || F(FLAG_MET_ARCHIE_METEOR_FALLS) || V(VAR_MT_PYRE_STATE)
            || V(VAR_WEATHER_INSTITUTE_STATE) || V(VAR_SOOTOPOLIS_CITY_STATE)
            || F(FLAG_DEFEATED_MAGMA_SPACE_CENTER);
    default:
        return FALSE;
    }
}

void StoryProgress_Resolve(enum Region region, struct StoryProgress *progress)
{
    u8 i;
    if (region < REGION_KANTO || region > REGION_HOENN)
        region = REGION_KANTO;
    progress->badges = 0;
    progress->optional = NULL;
    for (i = 0; i < NUM_BADGES; i++)
        progress->badges += B(region, i) != FALSE;
    if (!HasStarted(region, progress->badges))
    {
        progress->status = STORY_NOT_STARTED;
        switch (region)
        {
        case REGION_JOHTO: progress->objective = &sJohtoNotStarted; break;
        case REGION_HOENN: progress->objective = &sHoennNotStarted; break;
        default: progress->objective = &sKantoNotStarted; break;
        }
        return;
    }
    progress->status = IsRegionChampion(region) ? STORY_COMPLETE : STORY_IN_PROGRESS;
    switch (region)
    {
    case REGION_KANTO:
        progress->objective = ResolveKanto();
        progress->optional = ResolveKantoOptional();
        break;
    case REGION_JOHTO:
        progress->objective = ResolveJohto();
        progress->optional = ResolveJohtoOptional();
        break;
    default:
        progress->objective = ResolveHoenn();
        progress->optional = ResolveHoennOptional();
        break;
    }
}

enum Region StoryProgress_DefaultRegion(void)
{
    enum Region region = GetActiveRegion();
    return region >= REGION_KANTO && region <= REGION_HOENN ? region : REGION_KANTO;
}
