// Ordered transitions exercise each objective and keep overlapping work visible.
static void TestHoenn(void)
{
    Reset();
    SetStarted(REGION_HOENN);
    Expect(REGION_HOENN, "hoenn.clock");
    SetFlag(FLAG_SET_WALL_CLOCK);
    Expect(REGION_HOENN, "hoenn.meet_rival");
    SetVar(VAR_LITTLEROOT_RIVAL_STATE, 3);
    Expect(REGION_HOENN, "hoenn.rescue_birch");
    SetFlag(FLAG_RESCUED_BIRCH);
    SetVar(VAR_BIRCH_LAB_STATE, 2);
    Expect(REGION_HOENN, "hoenn.starter_lab");
    SetVar(VAR_BIRCH_LAB_STATE, 3);
    Expect(REGION_HOENN, "hoenn.route103");
    SetFlag(FLAG_DEFEATED_RIVAL_ROUTE103);
    SetVar(VAR_BIRCH_LAB_STATE, 4);
    Expect(REGION_HOENN, "hoenn.pokedex");
    SetFlag(FLAG_RECEIVED_POKEDEX_FROM_BIRCH);
    SetVar(VAR_BIRCH_LAB_STATE, 5);
    Expect(REGION_HOENN, "hoenn.petalburg");
    SetVar(VAR_PETALBURG_GYM_STATE, 2);
    Expect(REGION_HOENN, "hoenn.woods");
    SetVar(VAR_PETALBURG_WOODS_STATE, 1);
    Expect(REGION_HOENN, "hoenn.roxanne");
    SetBadge(REGION_HOENN, 0);
    Expect(REGION_HOENN, "hoenn.devon_recover");
    SetFlag(FLAG_DEVON_GOODS_STOLEN);
    Expect(REGION_HOENN, "hoenn.devon_recover");
    SetFlag(FLAG_RECOVERED_DEVON_GOODS);
    Expect(REGION_HOENN, "hoenn.devon_return");
    SetFlag(FLAG_RETURNED_DEVON_GOODS);
    Expect(REGION_HOENN, "hoenn.devon_president");
    SetFlag(FLAG_RECEIVED_POKENAV);
    SetVar(VAR_DEVON_CORP_3F_STATE, 1);
    Expect(REGION_HOENN, "hoenn.devon_steven");
    // The letter is delivered before the TM gift, including a full Bag.
    SetFlag(FLAG_DELIVERED_STEVEN_LETTER);
    Expect(REGION_HOENN, "hoenn.brawly");
    SetBadge(REGION_HOENN, 1);
    Expect(REGION_HOENN, "hoenn.devon_dock");
    SetFlag(FLAG_DOCK_REJECTED_DEVON_GOODS);
    Expect(REGION_HOENN, "hoenn.devon_stern");
    SetFlag(FLAG_DELIVERED_DEVON_GOODS);
    Expect(REGION_HOENN, "hoenn.route110");
    SetVar(VAR_ROUTE110_STATE, 1);
    Expect(REGION_HOENN, "hoenn.wally_mauville");
    SetFlag(FLAG_DECLINED_WALLY_BATTLE_MAUVILLE);
    Expect(REGION_HOENN, "hoenn.wally_mauville");
    SetFlag(FLAG_DEFEATED_WALLY_MAUVILLE);
    Expect(REGION_HOENN, "hoenn.wattson");
    SetBadge(REGION_HOENN, 2);
    Expect(REGION_HOENN, "hoenn.rock_smash");
    SetFlag(FLAG_RECEIVED_HM_ROCK_SMASH);
    Expect(REGION_HOENN, "hoenn.meteor_falls");
    SetFlag(FLAG_MET_ARCHIE_METEOR_FALLS);
    SetVar(VAR_METEOR_FALLS_STATE, 1);
    Expect(REGION_HOENN, "hoenn.mt_chimney");
    SetFlag(FLAG_DEFEATED_EVIL_TEAM_MT_CHIMNEY);
    Expect(REGION_HOENN, "hoenn.flannery");
    SetBadge(REGION_HOENN, 3);
    Expect(REGION_HOENN, "hoenn.norman");
    SetBadge(REGION_HOENN, 4);
    Expect(REGION_HOENN, "hoenn.surf");
    SetFlag(FLAG_RECEIVED_HM_SURF);
    Expect(REGION_HOENN, "hoenn.weather_institute");
    SetVar(VAR_WEATHER_INSTITUTE_STATE, 1);
    // No room in party or PC: the scientist retains the gift.
    Expect(REGION_HOENN, "hoenn.castform");
    SetVar(VAR_WEATHER_INSTITUTE_STATE, 2);
    Expect(REGION_HOENN, "hoenn.castform");
    SetFlag(FLAG_RECEIVED_CASTFORM);
    Expect(REGION_HOENN, "hoenn.route119");
    SetVar(VAR_ROUTE119_STATE, 1);
    Expect(REGION_HOENN, "hoenn.devon_scope");
    SetFlag(FLAG_RECEIVED_DEVON_SCOPE);
    Expect(REGION_HOENN, "hoenn.winona");
    SetBadge(REGION_HOENN, 5);
    Expect(REGION_HOENN, "hoenn.mt_pyre");
    SetVar(VAR_MT_PYRE_STATE, 1);
    SetFlag(FLAG_RECEIVED_RED_OR_BLUE_ORB);
    SetItem(ITEM_MAGMA_EMBLEM);
    Expect(REGION_HOENN, "hoenn.strength");
    SetFlag(FLAG_RECEIVED_HM_STRENGTH);
    Expect(REGION_HOENN, "hoenn.magma_hideout");
    SetFlag(FLAG_GROUDON_AWAKENED_MAGMA_HIDEOUT);
    Expect(REGION_HOENN, "hoenn.slateport_harbor");
    SetFlag(FLAG_MET_TEAM_AQUA_HARBOR);
    Expect(REGION_HOENN, "hoenn.aqua_hideout");
    SetFlag(FLAG_TEAM_AQUA_ESCAPED_IN_SUBMARINE);
    Expect(REGION_HOENN, "hoenn.tate_liza");
    SetBadge(REGION_HOENN, 6);
    Expect(REGION_HOENN, "hoenn.space_center");
    SetFlag(FLAG_DEFEATED_MAGMA_SPACE_CENTER);
    Expect(REGION_HOENN, "hoenn.dive");
    SetFlag(FLAG_RECEIVED_HM_DIVE);
    Expect(REGION_HOENN, "hoenn.seafloor");
    SetFlag(FLAG_KYOGRE_ESCAPED_SEAFLOOR_CAVERN);
    SetVar(VAR_SOOTOPOLIS_CITY_STATE, 1);
    Expect(REGION_HOENN, "hoenn.sootopolis_steven");
    SetVar(VAR_SOOTOPOLIS_CITY_STATE, 2);
    Expect(REGION_HOENN, "hoenn.sootopolis_steven");
    SetFlag(FLAG_STEVEN_GUIDES_TO_CAVE_OF_ORIGIN);
    Expect(REGION_HOENN, "hoenn.origin_wallace");
    SetVar(VAR_SOOTOPOLIS_CITY_STATE, 3);
    SetFlag(FLAG_WALLACE_GOES_TO_SKY_PILLAR);
    Expect(REGION_HOENN, "hoenn.sky_pillar");
    SetVar(VAR_SOOTOPOLIS_CITY_STATE, 4);
    Expect(REGION_HOENN, "hoenn.sky_pillar");
    SetVar(VAR_SOOTOPOLIS_CITY_STATE, 5);
    SetVar(VAR_SKY_PILLAR_STATE, 1);
    Expect(REGION_HOENN, "hoenn.return_sootopolis");
    SetVar(VAR_SKY_PILLAR_STATE, 2);
    Expect(REGION_HOENN, "hoenn.sootopolis_leaders");
    SetFlag(FLAG_MET_ARCHIE_SOOTOPOLIS);
    Expect(REGION_HOENN, "hoenn.sootopolis_leaders");
    SetFlag(FLAG_SOOTOPOLIS_ARCHIE_MAXIE_LEAVE);
    Expect(REGION_HOENN, "hoenn.waterfall");
    SetFlag(FLAG_RECEIVED_HM_WATERFALL);
    Expect(REGION_HOENN, "hoenn.juan");
    SetBadge(REGION_HOENN, 7);
    Expect(REGION_HOENN, "hoenn.victory_road");
    SetFlag(FLAG_DEFEATED_WALLY_VICTORY_ROAD);
    Expect(REGION_HOENN, "hoenn.league");
    SetVar(VAR_ELITE_4_STATE, 4);
    Expect(REGION_HOENN, "hoenn.league");
    SetFlag(FLAG_HOENN_CHAMPION);
    Expect(REGION_HOENN, "hoenn.complete");

    // Optional chain is absent until its local quest is actually started.
    ExpectOptional(REGION_HOENN, NULL);
    SetFlag(FLAG_GOT_BASEMENT_KEY_FROM_WATTSON);
    ExpectOptional(REGION_HOENN, "hoenn.new_mauville");
    SetVar(VAR_NEW_MAUVILLE_STATE, 2);
    ExpectOptional(REGION_HOENN, "hoenn.new_mauville_reward");
    // Full Bag does not set the reward flag.
    ExpectOptional(REGION_HOENN, "hoenn.new_mauville_reward");
    SetFlag(FLAG_GOT_TM_THUNDERBOLT_FROM_WATTSON);
    ExpectOptional(REGION_HOENN, NULL);

    // Alternate Devon order: Stern's receipt never delivers Steven's letter.
    Reset(); SetStarted(REGION_HOENN);
    SetFlag(FLAG_RECEIVED_POKENAV);
    SetFlag(FLAG_DELIVERED_DEVON_GOODS);
    SetBadge(REGION_HOENN, 0);
    Expect(REGION_HOENN, "hoenn.devon_steven");
    SetFlag(FLAG_DELIVERED_STEVEN_LETTER);
    Expect(REGION_HOENN, "hoenn.brawly");

    // Late regional evidence suppresses old opening/Devon scenes in migrations.
    Reset(); SetStarted(REGION_HOENN);
    SetVar(VAR_SOOTOPOLIS_CITY_STATE, 6);
    SetFlag(FLAG_SOOTOPOLIS_ARCHIE_MAXIE_LEAVE);
    SetFlag(FLAG_RECEIVED_HM_WATERFALL);
    Expect(REGION_HOENN, "hoenn.roxanne");
    SetBadge(REGION_HOENN, 0); SetBadge(REGION_HOENN, 1);
    SetBadge(REGION_HOENN, 2); SetBadge(REGION_HOENN, 3);
    SetBadge(REGION_HOENN, 4); SetBadge(REGION_HOENN, 5);
    SetBadge(REGION_HOENN, 6); SetBadge(REGION_HOENN, 7);
    Expect(REGION_HOENN, "hoenn.victory_road");

    // Juan's scene state proves the crisis is over even if old flags are absent.
    ClearFlag(FLAG_SOOTOPOLIS_ARCHIE_MAXIE_LEAVE);
    ClearFlag(FLAG_RECEIVED_HM_WATERFALL);
    Expect(REGION_HOENN, "hoenn.victory_road");

    // Required field moves remain prerequisites, not regional story evidence.
    Reset(); SetStarted(REGION_HOENN);
    for (u8 i = 0; i < 7; i++) SetBadge(REGION_HOENN, i);
    SetFlag(FLAG_DEFEATED_MAGMA_SPACE_CENTER);
    Expect(REGION_HOENN, "hoenn.surf");
    SetItem(ITEM_HM_SURF);
    Expect(REGION_HOENN, "hoenn.dive");
    SetItem(ITEM_HM_DIVE);
    Expect(REGION_HOENN, "hoenn.rock_smash");
    SetItem(ITEM_HM_ROCK_SMASH);
    Expect(REGION_HOENN, "hoenn.strength");
    SetItem(ITEM_HM_STRENGTH);
    Expect(REGION_HOENN, "hoenn.seafloor");

    // Shared HM/Dex/game-clear flags and items cannot complete Hoenn scenes.
    Reset(); SetStarted(REGION_HOENN);
    SetFlag(FLAG_SYS_POKEDEX_GET); SetFlag(FLAG_SYS_GAME_CLEAR);
    SetItem(ITEM_HM_SURF); SetItem(ITEM_MAGMA_EMBLEM);
    Expect(REGION_HOENN, "hoenn.clock");
    ExpectOptional(REGION_HOENN, NULL);
}
