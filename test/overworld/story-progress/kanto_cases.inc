static void KantoOpeningComplete(void)
{
    Reset();
    SetStarted(REGION_KANTO);
    SetVar(VAR_MAP_SCENE_PALLET_TOWN_PROFESSOR_OAKS_LAB, 6);
}

static void TestKanto(void)
{
    Reset();
    SetStarted(REGION_KANTO);
    Expect(REGION_KANTO, "kanto.starter");
    SetFlag(FLAG_SYS_POKEMON_GET);
    SetFlag(FLAG_SYS_POKEDEX_GET);
    SetFlag(FLAG_SYS_GAME_CLEAR);
    SetItem(ITEM_HM01);
    SetItem(ITEM_HM03);
    SetItem(ITEM_HM04);
    SetItem(ITEM_SILPH_SCOPE);
    SetItem(ITEM_CARD_KEY);
    Expect(REGION_KANTO, "kanto.starter");
    SetVar(VAR_MAP_SCENE_PALLET_TOWN_PROFESSOR_OAKS_LAB, 2);
    Expect(REGION_KANTO, "kanto.starter");
    SetVar(VAR_MAP_SCENE_PALLET_TOWN_PROFESSOR_OAKS_LAB, 3);
    Expect(REGION_KANTO, "kanto.rival");
    SetVar(VAR_MAP_SCENE_PALLET_TOWN_PROFESSOR_OAKS_LAB, 4);
    Expect(REGION_KANTO, "kanto.parcel");
    SetVar(VAR_MAP_SCENE_VIRIDIAN_CITY_MART, 1); /* Bag full: no parcel. */
    Expect(REGION_KANTO, "kanto.parcel");
    SetVar(VAR_MAP_SCENE_PALLET_TOWN_PROFESSOR_OAKS_LAB, 5);
    Expect(REGION_KANTO, "kanto.deliver_parcel");
    SetVar(VAR_MAP_SCENE_PALLET_TOWN_PROFESSOR_OAKS_LAB, 6);
    Expect(REGION_KANTO, "kanto.brock");
    SetFlag(FLAG_KANTO_BADGE_1);
    Expect(REGION_KANTO, "kanto.mt_moon");
    SetVar(VAR_MAP_SCENE_MT_MOON_B2F, 1); /* Fossil reward still pending. */
    Expect(REGION_KANTO, "kanto.mt_moon");
    SetFlag(FLAG_GOT_FOSSIL_FROM_MT_MOON);
    Expect(REGION_KANTO, "kanto.bill");
    SetFlag(FLAG_HELPED_BILL_IN_SEA_COTTAGE);
    Expect(REGION_KANTO, "kanto.ticket");
    SetFlag(FLAG_GOT_SS_TICKET);
    Expect(REGION_KANTO, "kanto.misty");
    SetFlag(FLAG_KANTO_BADGE_2);
    Expect(REGION_KANTO, "kanto.cut");
    /* Receipt scene advances only after CUT succeeds; departure removes captain. */
    SetVar(VAR_MAP_SCENE_VERMILION_CITY, 1);
    Expect(REGION_KANTO, "kanto.surge");
    SetVar(VAR_MAP_SCENE_VERMILION_CITY, 2);
    Expect(REGION_KANTO, "kanto.surge");
    SetVar(VAR_MAP_SCENE_VERMILION_CITY, 3);
    Expect(REGION_KANTO, "kanto.surge");
    ClearFlag(FLAG_GOT_SS_TICKET);
    ClearFlag(FLAG_HELPED_BILL_IN_SEA_COTTAGE);
    Expect(REGION_KANTO, "kanto.surge"); /* Sailed ship beats stale ticket flags. */
    SetFlag(FLAG_GOT_SS_TICKET);
    SetVar(VAR_MAP_SCENE_VERMILION_CITY, 4); /* Unrecognized migrated value. */
    Expect(REGION_KANTO, "kanto.cut");
    SetFlag(FLAG_GOT_HM01);
    SetVar(VAR_MAP_SCENE_VERMILION_CITY, 0);
    Expect(REGION_KANTO, "kanto.surge");
    SetFlag(FLAG_KANTO_BADGE_3);
    Expect(REGION_KANTO, "kanto.hideout");
    SetFlag(FLAG_HIDE_SILPH_SCOPE); /* Initially hidden, not collected. */
    Expect(REGION_KANTO, "kanto.hideout");
    SetFlag(FLAG_OPENED_ROCKET_HIDEOUT);
    Expect(REGION_KANTO, "kanto.lift_key");
    SetFlag(FLAG_CAN_USE_ROCKET_HIDEOUT_LIFT);
    Expect(REGION_KANTO, "kanto.hideout_boss");
    SetFlag(FLAG_HIDE_CELADON_ROCKETS);
    /* Scope was initially hidden; emulate Giovanni revealing it. */
    ClearFlag(FLAG_HIDE_SILPH_SCOPE);
    Expect(REGION_KANTO, "kanto.scope");
    SetFlag(FLAG_HIDE_SILPH_SCOPE);
    Expect(REGION_KANTO, "kanto.tower");
    SetVar(VAR_MAP_SCENE_POKEMON_TOWER_6F, 1);
    Expect(REGION_KANTO, "kanto.fuji");
    SetFlag(FLAG_RESCUED_MR_FUJI);
    Expect(REGION_KANTO, "kanto.flute");
    SetFlag(FLAG_GOT_POKE_FLUTE);
    Expect(REGION_KANTO, "kanto.erika");
    SetFlag(FLAG_KANTO_BADGE_4);
    Expect(REGION_KANTO, "kanto.surf");
    SetFlag(FLAG_GOT_HM03);
    Expect(REGION_KANTO, "kanto.koga");
    SetFlag(FLAG_KANTO_BADGE_5);
    Expect(REGION_KANTO, "kanto.teeth");
    ClearFlag(FLAG_GOT_HM03);
    Expect(REGION_KANTO, "kanto.surf"); /* KOGA can be defeated before SURF. */
    SetFlag(FLAG_GOT_HM03);
    Expect(REGION_KANTO, "kanto.teeth");
    SetFlag(FLAG_HIDE_SAFARI_ZONE_WEST_GOLD_TEETH);
    Expect(REGION_KANTO, "kanto.strength");
    SetFlag(FLAG_GOT_HM04);
    Expect(REGION_KANTO, "kanto.tea");
    SetFlag(FLAG_GOT_TEA);
    Expect(REGION_KANTO, "kanto.saffron_gate");
    SetVar(VAR_MAP_SCENE_ROUTE5_ROUTE6_ROUTE7_ROUTE8_GATES, 1);
    Expect(REGION_KANTO, "kanto.card_key");
    SetFlag(FLAG_HIDE_SILPH_CO_5F_CARD_KEY);
    Expect(REGION_KANTO, "kanto.silph");
    SetVar(VAR_MAP_SCENE_SILPH_CO_11F, 1);
    Expect(REGION_KANTO, "kanto.sabrina");
    SetFlag(FLAG_KANTO_BADGE_6);
    Expect(REGION_KANTO, "kanto.secret_key");
    SetFlag(FLAG_HIDE_POKEMON_MANSION_B1F_SECRET_KEY);
    Expect(REGION_KANTO, "kanto.blaine");
    SetFlag(FLAG_KANTO_BADGE_7);
    Expect(REGION_KANTO, "kanto.giovanni");
    SetFlag(FLAG_KANTO_BADGE_8);
    Expect(REGION_KANTO, "kanto.league");
    ClearFlag(FLAG_GOT_HM04);
    Expect(REGION_KANTO, "kanto.strength"); /* WARDEN still offers his gift. */
    SetFlag(FLAG_GOT_HM04);
    Expect(REGION_KANTO, "kanto.league");
    /* Silph departure beats stale gate/key state, and vice versa. */
    ClearFlag(FLAG_KANTO_BADGE_6);
    ClearFlag(FLAG_KANTO_BADGE_7);
    ClearFlag(FLAG_KANTO_BADGE_8);
    ClearFlag(FLAG_GOT_TEA);
    ClearFlag(FLAG_HIDE_SILPH_CO_5F_CARD_KEY);
    SetVar(VAR_MAP_SCENE_ROUTE5_ROUTE6_ROUTE7_ROUTE8_GATES, 0);
    SetVar(VAR_MAP_SCENE_SILPH_CO_11F, 0);
    SetFlag(FLAG_HIDE_SAFFRON_ROCKETS);
    Expect(REGION_KANTO, "kanto.sabrina");
    ClearFlag(FLAG_HIDE_SAFFRON_ROCKETS);
    Expect(REGION_KANTO, "kanto.tea");
    SetFlag(FLAG_KANTO_CHAMPION);
    Expect(REGION_KANTO, "kanto.champion");

    /* Later regional progress is sufficient evidence for migrated opening. */
    Reset();
    SetStarted(REGION_KANTO);
    SetFlag(FLAG_KANTO_BADGE_1);
    Expect(REGION_KANTO, "kanto.mt_moon");
    SetFlag(FLAG_KANTO_BADGE_2);
    Expect(REGION_KANTO, "kanto.bill");
    /* Tower/Silph completion does not require earlier hideout reward recovery. */
    KantoOpeningComplete();
    SetFlag(FLAG_KANTO_BADGE_1);
    SetFlag(FLAG_KANTO_BADGE_2);
    SetFlag(FLAG_KANTO_BADGE_3);
    SetFlag(FLAG_GOT_SS_TICKET);
    SetFlag(FLAG_GOT_HM01);
    SetFlag(FLAG_RESCUED_MR_FUJI);
    Expect(REGION_KANTO, "kanto.flute");
    ClearFlag(FLAG_RESCUED_MR_FUJI);
    SetVar(VAR_MAP_SCENE_POKEMON_TOWER_6F, 1);
    Expect(REGION_KANTO, "kanto.fuji");

    Reset();
    SetStarted(REGION_KANTO);
    ExpectOptional(REGION_KANTO, NULL);
    SetFlag(FLAG_HIDE_RUBY); /* Initial hidden item is not a started quest. */
    ExpectOptional(REGION_KANTO, NULL);
    SetVar(VAR_MAP_SCENE_ONE_ISLAND_POKEMON_CENTER_1F, 1);
    ExpectOptional(REGION_KANTO, "kanto.sevii_gifts");
    SetItem(ITEM_TRI_PASS);
    ExpectOptional(REGION_KANTO, "kanto.sevii_gifts");
    SetItem(ITEM_METEORITE);
    ExpectOptional(REGION_KANTO, "kanto.sevii_delivery");
    SetVar(VAR_MAP_SCENE_TWO_ISLAND_JOYFUL_GAME_CORNER, 1);
    SetVar(VAR_MAP_SCENE_THREE_ISLAND, 2);
    ExpectOptional(REGION_KANTO, "kanto.bikers");
    SetFlag(FLAG_SEVII_DETOUR_FINISHED); /* Port visitation, not errand completion. */
    ExpectOptional(REGION_KANTO, "kanto.bikers");
    SetVar(VAR_MAP_SCENE_THREE_ISLAND, 4);
    ExpectOptional(REGION_KANTO, "kanto.lostelle");
    SetFlag(FLAG_RESCUED_LOSTELLE);
    SetVar(VAR_MAP_SCENE_TWO_ISLAND_JOYFUL_GAME_CORNER, 3);
    ExpectOptional(REGION_KANTO, "kanto.meteorite");
    SetVar(VAR_MAP_SCENE_ONE_ISLAND_POKEMON_CENTER_1F, 2);
    SetFlag(FLAG_NO_ROOM_FOR_JOYFUL_GAME_CORNER_MOON_STONE);
    ExpectOptional(REGION_KANTO, "kanto.moon_stone");
    SetFlag(FLAG_GOT_MOON_STONE_FROM_JOYFUL_GAME_CORNER);
    ExpectOptional(REGION_KANTO, "kanto.return_bill");
    SetVar(VAR_MAP_SCENE_ONE_ISLAND_POKEMON_CENTER_1F, 3);
    ExpectOptional(REGION_KANTO, NULL);
    SetItem(ITEM_RUBY);
    SetItem(ITEM_SAPPHIRE);
    ExpectOptional(REGION_KANTO, NULL); /* Shared gems do not start a task. */
    SetVar(VAR_MAP_SCENE_ONE_ISLAND_POKEMON_CENTER_1F, 4);
    ExpectOptional(REGION_KANTO, "kanto.ruby");
    SetFlag(FLAG_GOT_RUBY);
    ExpectOptional(REGION_KANTO, "kanto.deliver_ruby");
    SetVar(VAR_MAP_SCENE_ONE_ISLAND_POKEMON_CENTER_1F, 5);
    ExpectOptional(REGION_KANTO, "kanto.icefall");
    SetVar(VAR_MAP_SCENE_ICEFALL_CAVE_BACK, 1);
    ExpectOptional(REGION_KANTO, "kanto.dotted_hole");
    SetFlag(FLAG_LEARNED_YES_NAH_CHANSEY);
    ExpectOptional(REGION_KANTO, "kanto.warehouse");
    SetFlag(FLAG_DEFEATED_ROCKETS_IN_WAREHOUSE);
    ExpectOptional(REGION_KANTO, "kanto.warehouse"); /* Gideon's gift can fail. */
    SetFlag(FLAG_RECOVERED_SAPPHIRE);
    ExpectOptional(REGION_KANTO, "kanto.deliver_sapphire");
    SetVar(VAR_MAP_SCENE_ONE_ISLAND_POKEMON_CENTER_1F, 6);
    ExpectOptional(REGION_KANTO, NULL);
    SetVar(VAR_MAP_SCENE_ONE_ISLAND_POKEMON_CENTER_1F, 7);
    ExpectOptional(REGION_KANTO, NULL);
}
