// These cases use the production resolver, with only save-state access mocked.
static void JohtoBadges(unsigned count)
{
    unsigned i;
    for (i = 0; i < count; i++)
        SetFlag(FLAG_JOHTO_BADGE_1 + i);
}

static void JohtoEarlyDone(void)
{
    SetStarted(REGION_JOHTO);
    SetFlag(FLAG_JOHTO_STARTER_CHOSEN);
    SetVar(VAR_NEWBARKTOWN_LABSTATE, 6);
    SetVar(VAR_VIOLET_CITY_STATE, 5);
    SetVar(VAR_SPROUT_TOWER, 1);
    SetVar(VAR_AZALEA_TOWN_STATE, 7);
    SetVar(VAR_ILEX_FOREST_FARFETCHD, 3);
}

static void JohtoMiddle(void)
{
    Reset();
    JohtoEarlyDone();
    JohtoBadges(4);
    SetFlag(FLAG_HIDE_SUDOWOODO);
    SetFlag(FLAG_RELEASED_BEASTS);
    SetVar(VAR_ECRUTEAK_CITY_THEATER, 3);
}

static void TestJohto(void)
{
    unsigned i;
    Reset();
    SetStarted(REGION_JOHTO);
    Expect(REGION_JOHTO, "johto.elm");
    SetVar(VAR_NEWBARKTOWN_LABSTATE, 1);
    Expect(REGION_JOHTO, "johto.starter");
    SetFlag(FLAG_JOHTO_STARTER_CHOSEN);
    SetVar(VAR_NEWBARKTOWN_LABSTATE, 2);
    Expect(REGION_JOHTO, "johto.mr-pokemon");
    SetVar(VAR_CHERRYGROVE_CITY_STATE, 2);
    SetVar(VAR_NEWBARKTOWN_LABSTATE, 4);
    Expect(REGION_JOHTO, "johto.return-elm");
    SetVar(VAR_NEWBARKTOWN_LABSTATE, 5);
    SetFlag(FLAG_JOHTO_ADVENTURE_STARTED); // Set by the Egg return before Balls.
    Expect(REGION_JOHTO, "johto.first-balls");
    SetVar(VAR_NEWBARKTOWN_LABSTATE, 6);
    Expect(REGION_JOHTO, "johto.sprout");
    SetFlag(FLAG_RECEIVED_HM_FLASH); // Shared Hoenn flag is not a tower clear.
    Expect(REGION_JOHTO, "johto.sprout");
    SetVar(VAR_SPROUT_TOWER, 1);
    Expect(REGION_JOHTO, "johto.falkner");
    SetFlag(FLAG_JOHTO_BADGE_1);
    Expect(REGION_JOHTO, "johto.violet-egg");
    SetVar(VAR_VIOLET_CITY_STATE, 4);
    SetFlag(FLAG_RECEIVED_TOGEPI_EGG);
    Expect(REGION_JOHTO, "johto.violet-gift");
    SetItem(ITEM_EXP_SHARE); // Shared item alone does not complete the aide scene.
    Expect(REGION_JOHTO, "johto.violet-gift");
    SetFlag(FLAG_HIDE_VIOLET_CITY_AIDE);
    Expect(REGION_JOHTO, "johto.kurt");
    SetVar(VAR_AZALEA_TOWN_STATE, 1);
    Expect(REGION_JOHTO, "johto.kurt");
    SetFlag(FLAG_HIDE_AZALEA_TOWN_WELL_ROCKET); // North-facing Kurt exit omits state2.
    Expect(REGION_JOHTO, "johto.well");
    SetVar(VAR_AZALEA_TOWN_STATE, 2);
    Expect(REGION_JOHTO, "johto.well");
    SetVar(VAR_AZALEA_TOWN_STATE, 3);
    Expect(REGION_JOHTO, "johto.kurt-return"); // Fast Ball bag-full retry.
    SetVar(VAR_AZALEA_TOWN_STATE, 4);
    Expect(REGION_JOHTO, "johto.bugsy");
    SetFlag(FLAG_JOHTO_BADGE_2);
    SetVar(VAR_AZALEA_TOWN_STATE, 5);
    Expect(REGION_JOHTO, "johto.azalea-rival");
    SetVar(VAR_AZALEA_TOWN_STATE, 6);
    SetFlag(FLAG_RECEIVED_HM_CUT); // Shared Hoenn receipt is not Ilex completion.
    Expect(REGION_JOHTO, "johto.ilex");
    SetVar(VAR_ILEX_FOREST_FARFETCHD, 2);
    Expect(REGION_JOHTO, "johto.ilex-cut");
    SetVar(VAR_ILEX_FOREST_FARFETCHD, 3);
    SetVar(VAR_AZALEA_TOWN_STATE, 7);
    Expect(REGION_JOHTO, "johto.whitney");
    SetVar(VAR_GOLDENROD_CITY_STATE, 3);
    Expect(REGION_JOHTO, "johto.whitney-badge");
    SetVar(VAR_GOLDENROD_CITY_STATE, 4);
    Expect(REGION_JOHTO, "johto.whitney-badge");
    SetFlag(FLAG_JOHTO_BADGE_3);
    SetVar(VAR_GOLDENROD_CITY_STATE, 5);
    Expect(REGION_JOHTO, "johto.squirtbottle");
    SetFlag(FLAG_RECEIVED_SQUIRTBOTTLE);
    SetItem(ITEM_SQUIRT_BOTTLE);
    Expect(REGION_JOHTO, "johto.sudowoodo");
    SetFlag(FLAG_HIDE_SUDOWOODO);
    Expect(REGION_JOHTO, "johto.burned-tower");
    SetFlag(FLAG_RELEASED_BEASTS);
    Expect(REGION_JOHTO, "johto.morty");
    SetFlag(FLAG_JOHTO_BADGE_4);
    SetFlag(FLAG_RECEIVED_HM_SURF); // Shared receipt alone is no Johto theater evidence.
    Expect(REGION_JOHTO, "johto.theater");
    SetVar(VAR_ECRUTEAK_CITY_THEATER, 2);
    Expect(REGION_JOHTO, "johto.surf");
    SetVar(VAR_ECRUTEAK_CITY_THEATER, 3);
    Expect(REGION_JOHTO, "johto.chuck");

    JohtoMiddle();
    SetFlag(FLAG_JOHTO_BADGE_5);
    Expect(REGION_JOHTO, "johto.lighthouse");
    ClearFlag(FLAG_JOHTO_BADGE_5);
    SetVar(VAR_OLIVINE_CITY_STATE, 3);
    Expect(REGION_JOHTO, "johto.medicine");
    SetVar(VAR_OLIVINE_CITY_STATE, 4); // Pharmacist may advance even when giveitem fails.
    Expect(REGION_JOHTO, "johto.medicine");
    SetItem(ITEM_SECRET_POTION);
    Expect(REGION_JOHTO, "johto.deliver-medicine");
    SetVar(VAR_OLIVINE_CITY_STATE, 5);
    SetFlag(FLAG_AMPHAROS_HEALED);
    ClearItem(ITEM_SECRET_POTION);
    Expect(REGION_JOHTO, "johto.chuck");
    SetFlag(FLAG_JOHTO_BADGE_5);
    Expect(REGION_JOHTO, "johto.jasmine");
    SetFlag(FLAG_JOHTO_BADGE_6);
    Expect(REGION_JOHTO, "johto.rage");
    SetVar(VAR_MAHOGANY_TOWN_STATE, 1);
    Expect(REGION_JOHTO, "johto.rage");
    SetVar(VAR_MAHOGANY_TOWN_STATE, 2);
    Expect(REGION_JOHTO, "johto.lance");
    SetVar(VAR_MAHOGANY_TOWN_STATE, 3); // Lance declined; still at lake.
    Expect(REGION_JOHTO, "johto.lance");
    SetVar(VAR_MAHOGANY_TOWN_STATE, 4);
    Expect(REGION_JOHTO, "johto.shop");
    for (i = 5; i <= 12; i++)
    {
        SetVar(VAR_MAHOGANY_TOWN_STATE, i);
        Expect(REGION_JOHTO, i < 7 ? "johto.hideout" : i < 9 ? "johto.hideout-passwords"
            : i < 12 ? "johto.hideout-murkrow" : "johto.hideout-room");
    }
    SetVar(VAR_MAHOGANY_TOWN_STATE, 7);
    SetVar(VAR_ROCKET_PASSWORD, 1);
    Expect(REGION_JOHTO, "johto.hideout-passwords");
    SetVar(VAR_ROCKET_PASSWORD, 2);
    Expect(REGION_JOHTO, "johto.hideout-door");
    SetVar(VAR_MAHOGANY_TOWN_STATE, 13);
    Expect(REGION_JOHTO, "johto.generator");
    SetVar(VAR_ELECTRODES_FAINTED, 3);
    Expect(REGION_JOHTO, "johto.whirlpool");
    SetVar(VAR_ELECTRODES_FAINTED, 4);
    SetVar(VAR_MAHOGANY_TOWN_STATE, 14);
    Expect(REGION_JOHTO, "johto.pryce");
    SetFlag(FLAG_JOHTO_BADGE_7);
    SetVar(VAR_MAHOGANY_TOWN_STATE, 15);
    Expect(REGION_JOHTO, "johto.radio-call");
    SetVar(VAR_MAHOGANY_TOWN_STATE, 16);
    SetVar(VAR_GOLDENROD_CITY_STATE, 6);
    SetItem(ITEM_BASEMENT_KEY);
    SetItem(ITEM_CARD_KEY); // Cross-region keys cannot bypass Petrel / state7.
    Expect(REGION_JOHTO, "johto.radio");
    SetVar(VAR_GOLDENROD_CITY_STATE, 7);
    Expect(REGION_JOHTO, "johto.underground");
    SetVar(VAR_GOLDENROD_CITY_STATE, 8);
    Expect(REGION_JOHTO, "johto.underground");
    SetVar(VAR_GOLDENROD_CITY_STATE, 9);
    Expect(REGION_JOHTO, "johto.radio-rescue");
    SetVar(VAR_GOLDENROD_CITY_STATE, 10);
    Expect(REGION_JOHTO, "johto.radio-director");
    SetVar(VAR_GOLDENROD_CITY_STATE, 11);
    SetVar(VAR_MAHOGANY_TOWN_STATE, 17);
    Expect(REGION_JOHTO, "johto.clair");
    SetVar(VAR_BLACKTHORN_CITY_STATE, 2);
    Expect(REGION_JOHTO, "johto.den");
    SetFlag(FLAG_JOHTO_BADGE_8);
    SetVar(VAR_BLACKTHORN_CITY_STATE, 3);
    Expect(REGION_JOHTO, "johto.den-exit");
    SetVar(VAR_BLACKTHORN_CITY_STATE, 4);
    Expect(REGION_JOHTO, "johto.elm-call");
    SetVar(VAR_BLACKTHORN_CITY_STATE, 5);
    SetVar(VAR_NEWBARKTOWN_LABSTATE, 7);
    Expect(REGION_JOHTO, "johto.elm-gift");
    SetVar(VAR_NEWBARKTOWN_LABSTATE, 8);
    SetVar(VAR_ECRUTEAK_CITY_THEATER, 4);
    Expect(REGION_JOHTO, "johto.kimono");
    SetVar(VAR_ECRUTEAK_CITY_THEATER, 6);
    Expect(REGION_JOHTO, "johto.kimono");
    SetVar(VAR_NEWBARKTOWN_LABSTATE, 8); // Stale invitation cannot outrank theater state7.
    SetVar(VAR_ECRUTEAK_CITY_THEATER, 7);
    SetVar(VAR_COMPLETED_LUGIA, 2);
    Expect(REGION_JOHTO, "johto.whirl-islands");
    SetVar(VAR_COMPLETED_LUGIA, 3);
    SetVar(VAR_COMPLETED_HO_OH, 2);
    Expect(REGION_JOHTO, "johto.tin-tower");
    SetVar(VAR_COMPLETED_HO_OH, 3);
    SetVar(VAR_ECRUTEAK_CITY_THEATER, 8);
    Expect(REGION_JOHTO, "johto.league"); // Completed theater outranks stale labstate8.
    SetVar(VAR_NEWBARKTOWN_LABSTATE, 9);
    SetVar(VAR_LEAGUE_STATE, 1);
    Expect(REGION_JOHTO, "johto.league-entry");
    for (i = 2; i <= 5; i++)
    {
        SetVar(VAR_LEAGUE_STATE, i);
        Expect(REGION_JOHTO, "johto.league-next");
    }
    SetVar(VAR_LEAGUE_STATE, 6);
    Expect(REGION_JOHTO, "johto.hall-of-fame");
    SetFlag(FLAG_JOHTO_CHAMPION);
    SetVar(VAR_NEWBARKTOWN_LABSTATE, 10);
    Expect(REGION_JOHTO, "johto.ss-ticket");
    SetVar(VAR_NEWBARKTOWN_LABSTATE, 11);
    Expect(REGION_JOHTO, "johto.postgame");

    // Unusual and migrated states: regional evidence skips stale opening vars;
    // active eastern chains take precedence over missing western badges.
    JohtoMiddle();
    SetVar(VAR_MAHOGANY_TOWN_STATE, 4);
    Expect(REGION_JOHTO, "johto.shop");
    SetVar(VAR_GOLDENROD_CITY_STATE, 6);
    Expect(REGION_JOHTO, "johto.radio");
    Reset();
    SetStarted(REGION_JOHTO);
    JohtoBadges(8);
    Expect(REGION_JOHTO, "johto.league-check"); // Theater gate needs explicit state8.
    SetVar(VAR_LEAGUE_STATE, 2);
    SetVar(VAR_BLACKTHORN_CITY_STATE, 3); // Old scene cannot outrank active gauntlet.
    Expect(REGION_JOHTO, "johto.league-next");

    Reset();
    SetStarted(REGION_JOHTO);
    SetItem(ITEM_GS_BALL);
    ExpectOptional(REGION_JOHTO, NULL); // Item possession does not start a local chain.
    SetVar(VAR_AZALEA_TOWN_STATE, 8);
    ExpectOptional(REGION_JOHTO, "johto.gs-kurt");
    SetVar(VAR_AZALEA_TOWN_STATE, 9);
    ExpectOptional(REGION_JOHTO, "johto.gs-shrine");
    SetVar(VAR_AZALEA_TOWN_STATE, 10);
    ExpectOptional(REGION_JOHTO, "johto.celebi-later"); // Retry waits for this region's Champion.
    SetFlag(FLAG_JOHTO_CHAMPION);
    ExpectOptional(REGION_JOHTO, "johto.celebi-retry");
    SetFlag(FLAG_CAUGHT_CELEBI);
    ExpectOptional(REGION_JOHTO, NULL);
}
