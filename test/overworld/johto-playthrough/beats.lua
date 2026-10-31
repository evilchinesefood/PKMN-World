-- Ordered Johto story beats. Each beat: { name, run = function, done = predicate }.
-- Coordinates and states come from data/maps/*/map.json and scripts.inc; see README.md.
return function(F, N, C, log)
  local L = F.L
  local B = {}
  local function beat(name, run, done) B[#B + 1] = { name = name, run = run, done = done } end
  local function V(name) return N.var(C[name]) end
  local function FL(name) return N.flag(C[name]) end
  local function at(map) return N.mapName() == map end

  beat('to_johto', function()
    assert(N.approach(16, 2, { side = 1 }), 'hub attendant')
    for _ = 1, 500 do
      N.press('A'); N.idle(20)
      if F.grp() == 76 then break end
    end
    N.idle(200); N.settle()
  end, function() return at('NewBarkTown_PlayersHouse_2F') end)

  -- Parties are per region, so this happens after arriving in Johto.
  -- Party: Lv100 Mewtwo and Rayquaza from the debug Give menu, so story battles need no grinding.
  -- Their met level is then set to 5 so Gen 8+ obedience (met level vs. badges) lets them act.
  -- The Johto starter is still chosen and carried normally.
  beat('party', function()
    assert(N.giveMon({ species = C.SPECIES_MEWTWO, level = 100, evs = { 4, 0, 0, 252, 252, 0 },
      moves = { C.MOVE_PSYSTRIKE, C.MOVE_AURA_SPHERE, C.MOVE_ICE_BEAM, C.MOVE_FLAMETHROWER } }))
    assert(N.giveMon({ species = C.SPECIES_RAYQUAZA, level = 100, evs = { 4, 252, 0, 252, 0, 0 },
      moves = { C.MOVE_EARTHQUAKE, C.MOVE_DRAGON_CLAW, C.MOVE_EXTREME_SPEED, C.MOVE_THUNDERBOLT } }))
    N.setMetLevel(0, 5)
    N.setMetLevel(1, 5)
  end, function() return N.partyCount() == 2 and N.partyMon(0).level == 100 end)

  beat('leave_home', function()
    assert(N.travel('NewBarkTown'))
  end, function() return at('NewBarkTown') and V('VAR_NEWBARK_TOWN_STATE') >= 2 end)

  beat('elm_intro', function()
    N.run = true
    assert(N.travel('NewBarkTown_Lab'))
    assert(N.go(6, 7))
    N.settle()
  end, function() return V('VAR_NEWBARKTOWN_LABSTATE') >= 1 end)

  beat('starter', function()
    assert(N.talk(4, { side = 1 }))     -- Chikorita's ball at (8,4), from below
  end, function() return FL('FLAG_JOHTO_STARTER_CHOSEN') and N.partyCount() == 3 end)

  beat('elm_errand', function()
    if V('VAR_NEWBARKTOWN_LABSTATE') < 2 then assert(N.talk(2, { side = 1 })) end
    assert(N.travel('NewBarkTown'))     -- the aide's Potion trigger is on the way out
  end, function() return at('NewBarkTown') and V('VAR_NEWBARKTOWN_LABSTATE') >= 2 end)

  -- Answer No to one prompt matching `pat`, Yes/first option to everything else.
  local function noTo(pat)
    return function(t, k)
      if k == 'yesno' and t:lower():find(pat) then return 'no' end
      return N.defaultPolicy(t, k)
    end
  end

  -- Cherrygrove's guide (No skips the tour; it still arms Mr. Pokémon), then Mr. Pokémon's house.
  beat('mr_pokemon', function()
    assert(N.travel('Route30_MrPokemonsHouse', { policy = noTo('') }))
    N.settle()
  end, function() return V('VAR_NEWBARKTOWN_LABSTATE') >= 4 and V('VAR_CHERRYGROVE_CITY_STATE') >= 2 and FL('FLAG_DELIVERED_EGG') end)

  -- Elm's call on leaving, the rival ambush in Cherrygrove, and the police scene in the lab.
  beat('rival_and_police', function()
    assert(N.travel('NewBarkTown_Lab'))
    N.settle()
  end, function() return V('VAR_CHERRYGROVE_CITY_STATE') >= 4 and V('VAR_NEWBARKTOWN_LABSTATE') >= 5 end)

  beat('first_balls', function()
    assert(N.travel('NewBarkTown'))
  end, function() return V('VAR_NEWBARKTOWN_LABSTATE') == 6 and FL('FLAG_RECEIVED_FIRST_BALLS') end)

  beat('mom_farewell', function()
    assert(N.travel('NewBarkTown_PlayersHouse_1F'))
    assert(N.talk(1))
  end, function() return FL('FLAG_MOM_VISITED') and V('VAR_NEWBARK_TOWN_STATE') == 5 end)

  beat('to_violet', function()
    assert(N.travel('VioletCity'))
  end, function() return at('VioletCity') and V('VAR_VIOLET_CITY_STATE') >= 1 end)

  beat('sprout_tower', function()
    assert(N.travel('SproutTower_3F'))
    assert(N.go(13, 7))
    N.settle()
  end, function() return V('VAR_SPROUT_TOWER') == 1 and FL('FLAG_HIDE_SPROUT_TOWER_SILVER') end)

  beat('falkner', function()
    assert(N.travel('VioletCity_Gym'))
    assert(N.talk(1, { side = 1 }))
  end, function() return FL('FLAG_JOHTO_BADGE_1') and V('VAR_VIOLET_CITY_STATE') >= 3 end)

  beat('togepi_egg', function()
    assert(N.travel('VioletCity_PokemonCenter'))
    assert(N.talk(6, { side = 1 }))
  end, function() return FL('FLAG_RECEIVED_TOGEPI_EGG') and FL('FLAG_HIDE_VIOLET_CITY_AIDE') end)

  beat('route32_gate', function()
    assert(N.travel('Route32'))
    assert(N.walk(function(x, y) return y >= 12 end, { tag = 'route32 south' }))
  end, function() return V('VAR_VIOLET_CITY_STATE') == 5 end)

  ------------------------------------------------------------------ Azalea and Ilex
  beat('azalea_arrive', function()
    assert(N.travel('AzaleaTown'))
  end, function() return at('AzaleaTown') and V('VAR_AZALEA_TOWN_STATE') >= 1 end)

  -- Kurt from the east: from the south his script skips the state write.
  beat('kurt', function()
    assert(N.travel('AzaleaTown_KurtsHouse'))
    assert(N.talk(1, { side = 4 }))
  end, function() return FL('FLAG_HIDE_AZALEA_TOWN_WELL_ROCKET') and V('VAR_AZALEA_TOWN_STATE') >= 2 end)

  beat('slowpoke_well', function()
    assert(N.travel('SlowpokeWell_B1F'))
    assert(N.talk(12, { side = 4 }))      -- Jessie & James, from (22,2)
    assert(N.talk(4, { side = 1 }))       -- Proton, from (14,4); Kurt walks us home
    N.settle()
  end, function() return V('VAR_AZALEA_TOWN_STATE') >= 4 end)

  -- Bugsy's gym: Ariados rides (6,39) -> (11,27), then (16,23) -> (11,11).
  beat('bugsy', function()
    assert(N.travel('AzaleaTown_Gym'))
    assert(N.go(6, 39)); N.settle()
    assert(N.go(16, 23)); N.settle()
    assert(N.talk(2, { side = 1 }))
  end, function() return FL('FLAG_JOHTO_BADGE_2') and V('VAR_AZALEA_TOWN_STATE') >= 5 end)

  beat('azalea_rival', function()
    assert(N.go(11, 11)); N.settle()      -- ride to (16,23)
    assert(N.go(11, 27)); N.settle()      -- ride to (6,39)
    assert(N.travel('AzaleaTown'))
    assert(N.travel('IlexForest'))        -- Silver's trigger guards the gate
  end, function() return V('VAR_AZALEA_TOWN_STATE') >= 6 and at('IlexForest') end)

  -- Farfetch'd: south of bird 1, north of bird 2 (sends bird 1 home), north of bird 1 (var 1),
  -- then east of it at (33,51) (var 2). Talking from its west or north at var 1 resets the chase.
  beat('ilex_chase', function()
    assert(N.talk(3, { side = 1 }))
    assert(N.talk(13, { side = 2 }))
    assert(N.talk(3, { side = 2 }))
    assert(V('VAR_ILEX_FOREST_FARFETCHD') == 1, 'chase state 1')
    assert(N.talk(3, { side = 4 }))
    assert(N.go(26, 43)); N.settle()
  end, function() return V('VAR_ILEX_FOREST_FARFETCHD') >= 3 and V('VAR_AZALEA_TOWN_STATE') >= 7 end)

  beat('ilex_cut', function()
    assert(N.talk({ 32, 40 }, { side = 1 }))   -- the Cut tree
    assert(N.travel('Route34'))                -- the Kimono Girl trigger is on the way
  end, function() return V('VAR_ILEX_FOREST_FARFETCHD') >= 4 and at('Route34') end)

  ------------------------------------------------------------------ Goldenrod
  beat('goldenrod_arrive', function()
    assert(N.travel('GoldenrodCity'))
  end, function() return V('VAR_GOLDENROD_CITY_STATE') >= 1 end)

  -- The receptionist's quiz unblocks the Gym door. Answered from what the game has told the player:
  -- this Kurt makes his BALLS from BERRIES ("I make BALLS from BERRIES"), so not apricorns.
  local function quiz(t, k)
    local l = t:lower()
    if k == 'yesno' then
      if l:find('charmander') or l:find('apricorn') then return 'no' end
      return 'yes'
    end
    return 0
  end
  beat('radio_quiz', function()
    assert(N.travel('GoldenrodCity_RadioTower_1F'))
    assert(N.talkFrom(14, 8, 1, { policy = quiz }))
  end, function() return V('VAR_GOLDENROD_CITY_STATE') >= 2 and FL('FLAG_HIDE_GOLDENROD_BEAUTY') end)

  beat('whitney', function()
    assert(N.travel('GoldenrodCity_Gym'))
    assert(N.talk(4, { side = 1 }))
    assert(N.go(15, 11)); N.settle()      -- Bridget's trigger
    assert(N.talk(4, { side = 1 }))
  end, function() return FL('FLAG_JOHTO_BADGE_3') and V('VAR_GOLDENROD_CITY_STATE') >= 5 end)

  beat('squirtbottle', function()
    assert(N.travel('GoldenrodCity_FlowerShop'))
    assert(N.talk(1, { side = 1 }))
  end, function() return FL('FLAG_RECEIVED_SQUIRTBOTTLE') end)

  beat('route35_cut', function()
    assert(N.travel('Route35'))
    assert(N.talk({ 31, 6 }, { side = 1 }))
    assert(N.travel('Route36'))
  end, function() return at('Route36') end)

  ------------------------------------------------------------------ Ecruteak
  beat('sudowoodo', function()
    assert(N.talk(6, { side = 1 }))
  end, function() return FL('FLAG_HIDE_SUDOWOODO') end)

  beat('ecruteak_arrive', function()
    assert(N.travel('EcruteakCity'))
  end, function() return at('EcruteakCity') and V('VAR_ECRUTEAK_CITY_STATE') >= 1 end)

  beat('burned_tower', function()
    assert(N.travel('BurnedTower_1F'))
    N.settle()
    assert(N.go(15, 12)); N.settle()      -- rival, then the floor gives way
    N.settle()
    assert(N.travel('EcruteakCity'))
  end, function() return FL('FLAG_RELEASED_BEASTS') and V('VAR_ECRUTEAK_CITY_STATE') >= 4 end)

  beat('morty', function()
    assert(N.travel('EcruteakCity_Gym'))
    assert(N.talk(8, { side = 1 }))       -- Morty at (4,4); the pits are warp tiles, which the walker avoids
  end, function() return FL('FLAG_JOHTO_BADGE_4') end)

  beat('theater_surf', function()
    assert(N.travel('EcruteakCity_Theater'))
    N.settle()
    assert(N.talkFrom(9, 4, 4))           -- the Rocket at (10,4)
    assert(N.go(10, 17)); N.settle()      -- the gentleman stops us at the exit with Surf
  end, function() return V('VAR_ECRUTEAK_CITY_THEATER') >= 3 end)

  ------------------------------------------------------------------ Olivine and Cianwood
  -- Field moves: badge plus a party member that can learn the move (no tool items are given).
  local function fieldMoves()
    N.canSurf = FL('FLAG_JOHTO_BADGE_4')
    N.canWaterfall = FL('FLAG_JOHTO_BADGE_8')
    N.canCut = FL('FLAG_JOHTO_BADGE_1')
    N.canSmash = FL('FLAG_JOHTO_BADGE_3')
    N.canWhirlpool = FL('FLAG_JOHTO_BADGE_7')
  end
  N.beatSetup = fieldMoves

  beat('olivine_arrive', function()
    fieldMoves()
    assert(N.travel('OlivineCity'))      -- Baoba's GOLD/SILVER prompt on Route 39: GOLD (index 0)
  end, function() return V('VAR_LUGIA_OR_HOOH') ~= 0 and V('VAR_OLIVINE_CITY_STATE') >= 1 end)

  beat('lighthouse_jasmine', function()
    fieldMoves()
    assert(N.travel('OlivineCity_Lighthouse'))   -- Silver's scene in the city is on the way
    assert(N.goFar(156, 10))
    N.face(2); N.press('A'); N.idle(20); N.settle()
  end, function() return V('VAR_OLIVINE_CITY_STATE') >= 3 end)

  beat('cianwood_potion', function()
    fieldMoves()
    assert(N.travel('CianwoodShop'))
    assert(N.talkFrom(8, 9, 2))
  end, function() return V('VAR_OLIVINE_CITY_STATE') >= 4 and N.itemCount(C.ITEM_SECRET_POTION) > 0 end)

  -- Chuck's gym: Strength on (10,8) -> right, (10,6) -> up, (10,4) -> right, then Chuck from (10,3).
  beat('chuck', function()
    fieldMoves()
    assert(N.travel('CianwoodGym'))
    assert(N.go(9, 8))
    N.face(4); N.press('A'); N.idle(20); N.settle()   -- "use STRENGTH?" -> yes
    assert(N.push(4), 'push (10,8) right')
    assert(N.go(10, 7))
    assert(N.push(2), 'push (10,6) up')
    assert(N.go(9, 4))
    assert(N.push(4), 'push (10,4) right')
    assert(N.talkFrom(10, 3, 2))
  end, function() return FL('FLAG_JOHTO_BADGE_5') end)

  beat('fly_gift', function()
    assert(N.travel('CianwoodCity'))
    N.settle()
  end, function() return at('CianwoodCity') end)

  -- Back to Olivine the way a player would at this point: by sea (Fly needs badge 6 here).
  beat('cianwood_to_olivine', function()
    fieldMoves()
    assert(N.travel('OlivineCity'), 'no way back from Cianwood by sea')
  end, function() return at('OlivineCity') end)

  beat('deliver_medicine', function()
    fieldMoves()
    assert(N.travel('OlivineCity_Lighthouse'))
    assert(N.goFar(156, 10))
    N.face(2); N.press('A'); N.idle(20); N.settle()
  end, function() return V('VAR_OLIVINE_CITY_STATE') >= 5 and FL('FLAG_AMPHAROS_HEALED') end)

  beat('jasmine', function()
    fieldMoves()
    assert(N.travel('OlivineCity_Gym'))      -- two row triggers on the way up are unavoidable
    assert(N.talk(1, { side = 1 }))
  end, function() return FL('FLAG_JOHTO_BADGE_6') end)

  ------------------------------------------------------------------ Mahogany and the hideout
  beat('mahogany_arrive', function()
    fieldMoves()
    assert(N.travel('Mahoganytown'))         -- Route 42 by Surf; the town trigger is on its east edge
  end, function() return V('VAR_MAHOGANY_TOWN_STATE') >= 1 end)

  beat('red_gyarados', function()
    fieldMoves()
    assert(N.travel('LakeOfRage'))
    assert(N.chase(8))                        -- it roams the lake; KO or catch, never run
  end, function() return V('VAR_MAHOGANY_TOWN_STATE') >= 2 end)

  beat('lance_lake', function()
    fieldMoves()
    assert(N.talk(3, { side = 1 }))           -- "help us investigate?" -> yes
  end, function() return V('VAR_MAHOGANY_TOWN_STATE') >= 4 end)

  beat('shop_raid', function()
    fieldMoves()
    assert(N.travel('MahoganyTown_Shop'))
    N.settle()
  end, function() return V('VAR_MAHOGANY_TOWN_STATE') >= 5 end)

  -- B1F: the first statue's grunts are forced at (45,3)/(45,4); one press of the switch at
  -- (31,11) disarms the rest (a second press re-arms them).
  beat('hideout_b1f', function()
    assert(N.travel('MahoganyHideout_B1F'))
    assert(N.talkFrom(31, 12, 2))
  end, function() return FL('FLAG_ROCKETHIDEOUT_SWITCH') end)

  beat('hideout_lance_heal', function()
    assert(N.travel('MahoganyHideout_B2F'))
    assert(N.go(9, 24)); N.settle()
  end, function() return V('VAR_MAHOGANY_TOWN_STATE') >= 6 end)

  -- B3F: Lance names the two-password lock; each password needs a second talk after the battle.
  beat('hideout_passwords', function()
    assert(N.travel('MahoganyHideout_B3F'))
    N.settle()
    assert(N.talk(1, { side = 1 })); assert(N.talk(1, { side = 1 }))      -- Grunt F at (29,9)
    assert(N.talk(10, { side = 4 })); assert(N.talk(10, { side = 4 }))    -- Eto at (4,16)
  end, function() return V('VAR_ROCKET_PASSWORD') >= 2 end)

  beat('hideout_door', function()
    assert(N.takeWarp(32, 2))       -- B3F -> B2F top corridor
    assert(N.takeWarp(3, 4))        -- B2F -> B3F west pocket
    assert(N.go(12, 13)); N.settle()                -- Silver's trigger at (8,13) is on the way
    assert(N.talkFrom(12, 13, 2))
  end, function() return FL('FLAG_HIDE_ROCKETHIDEOUT3_GATE') and V('VAR_MAHOGANY_TOWN_STATE') >= 8 end)

  beat('hideout_petrel', function()
    assert(N.talkFrom(10, 4, 2))
  end, function() return V('VAR_MAHOGANY_TOWN_STATE') >= 9 end)

  -- The Murkrow trail: B2F top corridor, B3F north-east stairs, then the voice-locked gate.
  beat('hideout_murkrow', function()
    assert(N.takeWarp(3, 2))        -- B3F -> B2F (3,4)
    assert(N.takeWarp(28, 6))       -- along the corridor (trigger at x=7/13) -> B3F (32,2)
    N.settle()
    assert(N.go(31, 2) or N.go(32, 3)); N.settle()
    assert(N.takeWarp(29, 18))      -- -> B2F (28,20)
    assert(N.go(16, 24)); N.settle()
  end, function() return V('VAR_MAHOGANY_TOWN_STATE') >= 12 end)

  beat('hideout_ariana', function()
    assert(N.go(15, 18)); N.settle()   -- multi battle beside Lance; the party picker takes the lead
  end, function() return V('VAR_MAHOGANY_TOWN_STATE') >= 13 end)

  beat('hideout_electrodes', function()
    assert(N.talkFrom(12, 15, 3)); assert(N.talkFrom(12, 12, 3)); assert(N.talkFrom(12, 9, 3))
    assert(V('VAR_ELECTRODES_FAINTED') == 3, 'three Electrodes')
    assert(N.go(14, 17)); N.settle()   -- Lance's Whirlpool gift
  end, function() return V('VAR_MAHOGANY_TOWN_STATE') >= 14 end)

  beat('pryce', function()
    fieldMoves()
    assert(N.travel('MahoganyTown_Gym'))
    assert(N.talk(6))                  -- the ice is pathfound slide by slide
  end, function() return FL('FLAG_JOHTO_BADGE_7') end)

  beat('elm_radio_call', function()
    assert(N.travel('Mahoganytown'))
    N.settle()
  end, function() return V('VAR_GOLDENROD_CITY_STATE') >= 6 and V('VAR_MAHOGANY_TOWN_STATE') >= 16 end)

  ------------------------------------------------------------------ Radio Tower takeover
  beat('radio_petrel', function()
    fieldMoves()
    assert(N.travel('GoldenrodCity_RadioTower_1F'))
    assert(N.talk(3, { side = 1 }))    -- the grunt standing on the 2F stairs
    assert(N.travel('GoldenrodCity_RadioTower_5F'))
    assert(N.talkFrom(11, 10, 2))      -- Petrel ignores you from the north
  end, function() return V('VAR_GOLDENROD_CITY_STATE') >= 7 and N.itemCount(C.ITEM_BASEMENT_KEY) > 0 end)

  beat('underground_door', function()
    assert(N.travel('GoldenrodCity_UndergroundTunnel'))
    assert(N.go(12, 11)); N.settle()   -- the Kimono Girl's trigger at x=8 is on the way
    N.face(2); N.press('A'); N.idle(20); N.settle()
  end, function() return V('VAR_GOLDENROD_CITY_STATE') >= 8 and FL('FLAG_UNLOCKED_GOLDENROD_UNDERGROUND_DOOR') end)

  beat('underground_switches', function()
    assert(N.travel('GoldenrodCity_UndergroundSwitches'))
    N.settle()
    assert(N.go(26, 5) or N.go(26, 6)); N.settle()      -- Silver
    assert(N.talkFrom(5, 2, 2))        -- panel 3
    assert(N.talkFrom(13, 2, 2))       -- panel 2
    assert(N.talkFrom(22, 2, 2))       -- panel 1
  end, function() return V('VAR_GOLDENROD_CITY_STATE') >= 9 and FL('FLAG_COMPLETED_SWITCHES') end)

  beat('card_key', function()
    assert(N.travel('GoldenrodCity_UndergroundStorage'))
    assert(N.talkFrom(14, 8, 3))
  end, function() return N.itemCount(C.ITEM_CARD_KEY) > 0 end)

  beat('radio_shutter', function()
    -- Back through the solved switch room and the unlocked door (both opened by setmetatile).
    assert(N.travel('GoldenrodCity_UndergroundSwitches'))
    assert(N.travel('GoldenrodCity_UndergroundTunnel'))
    assert(N.travel('GoldenrodCity_RadioTower_3F'))
    assert(N.talkFrom(25, 10, 2))
  end, function() return FL('FLAG_HIDE_RADIOTOWER_GATE') end)

  beat('archer', function()
    assert(N.takeWarp(29, 5))          -- 3F -> 4F east room
    assert(N.takeWarp(29, 5))          -- 4F -> 5F studio (Proton on the way)
    assert(N.talkFrom(25, 11, 1))
    N.settle()
  end, function() return V('VAR_GOLDENROD_CITY_STATE') >= 10 and V('VAR_MAHOGANY_TOWN_STATE') >= 17 end)

  beat('radio_freed', function()
    assert(N.takeWarp(24, 5))          -- studio -> 4F; both first steps there are triggers
    assert(N.walk(function(x, y) return x ~= 29 or y ~= 5 end, { tag = 'off the stairs', allowTriggers = true }))
    N.settle()
  end, function() return V('VAR_GOLDENROD_CITY_STATE') >= 11 end)

  ------------------------------------------------------------------ Ice Path and Blackthorn
  beat('ice_path_enter', function()
    fieldMoves()
    -- Out of the 4F east room by its own stairs: the 3F corner below is open only by setmetatile.
    if at('GoldenrodCity_RadioTower_4F') then assert(N.takeWarp(27, 5)) end
    assert(N.travel('IcePath_1F'), 'Route 44 to the Ice Path door')
  end, function() return at('IcePath_1F') end)

  -- 1F west -> B1F, where the puzzle-skip sign (10,21) warps to (15,12) beside the hole at (16,12).
  beat('ice_path_b1f', function()
    fieldMoves()
    assert(N.travel('IcePath_B1F'))
    assert(N.talkFrom(9, 21, 4))          -- "skip this puzzle?" -> yes
    assert(N.takeWarp(16, 12))            -- fall to B2F (16,16)
  end, function() return at('IcePath_B2F') end)

  beat('ice_path_lower', function()
    fieldMoves()
    assert(N.takeWarp(16, 15))            -- B2F -> B4F
    assert(N.takeWarp(21, 18))            -- B4F -> B3F
    assert(N.takeWarp(14, 21))            -- B3F -> B1F lower
    assert(N.takeWarp(10, 32))            -- B1F -> 1F east
  end, function() return at('IcePath_1F') end)

  beat('ice_path_kimono', function()
    fieldMoves()
    assert(N.talk(9, { side = 2 }))       -- from the north only; "push my back?" -> yes
  end, function() return V('VAR_ICE_PATH_STATE') >= 1 end)

  beat('blackthorn_arrive', function()
    fieldMoves()
    assert(N.travel('BlackthornCity'))
  end, function() return at('BlackthornCity') and FL('FLAG_VISITED_BLACKTHORN_CITY') end)

  -- Clair's gym: four bridge-trigger rows, each built by stepping on the previous one.
  beat('clair', function()
    fieldMoves()
    assert(N.travel('BlackthornCity_Gym'))
    assert(N.go(20, 55)); N.settle()
    assert(N.go(19, 41)); N.settle()
    assert(N.go(25, 27)); N.settle()
    assert(N.go(19, 16)); N.settle()
    assert(N.talk(4, { side = 1 }))
  end, function() return V('VAR_BLACKTHORN_CITY_STATE') >= 2 end)

  local function elder(t, k)
    local l = t:lower()
    if k == 'multi' then
      if l:find('pok.mon to you') then return 0 end
      if l:find('win battles') then return 0 end
      if l:find('kind of trainer') then return 1 end
      if l:find('raising') then return 0 end
      if l:find('strong') then return 2 end
      return 0
    end
    return N.defaultPolicy(t, k)
  end
  beat('dragons_den', function()
    fieldMoves()
    assert(N.travel('DragonsDen_Cavern'))
    assert(N.go(16, 37))
    N.face(1); N.press('A'); N.idle(30); N.settle(); N.idle(180)   -- Whirlpool
    assert(N.travel('DragonsDen_Shrine'))
    assert(N.go(6, 15, { policy = elder })); N.settle({ policy = elder })
  end, function() return FL('FLAG_JOHTO_BADGE_8') and V('VAR_BLACKTHORN_CITY_STATE') >= 3 end)

  beat('den_exit', function()
    fieldMoves()
    assert(N.travel('BlackthornCity'))    -- Clair at the cavern exit, then Elm's call in town
    N.settle()
  end, function() return V('VAR_BLACKTHORN_CITY_STATE') >= 5 and V('VAR_NEWBARKTOWN_LABSTATE') >= 7 end)

  beat('elm_master_ball', function()
    fieldMoves()
    assert(N.travel('NewBarkTown_Lab'))
    assert(N.talk(2, { side = 1 }))
  end, function() return V('VAR_NEWBARKTOWN_LABSTATE') >= 8 and V('VAR_ECRUTEAK_CITY_THEATER') >= 4 end)

  ------------------------------------------------------------------ Kimono Girls and Tin Tower
  beat('kimono_dances', function()
    fieldMoves()
    assert(N.travel('EcruteakCity'))
    assert(N.go(39, 41)); N.settle()      -- Silver bursts out of the theater
    assert(N.travel('EcruteakCity_Theater'))
    assert(N.walk(function(x, y) return y < 17 end, { tag = 'theater trigger', allowTriggers = true }))
    N.settle()                            -- Zuki "ready?" -> yes, then five battles and the bell
  end, function() return V('VAR_ECRUTEAK_CITY_THEATER') >= 7 end)

  beat('tin_tower_guard', function()
    fieldMoves()
    assert(N.travel('EcruteakCity_SageOffice1'))
    assert(N.talkFrom(16, 3, 2))
  end, function() return FL('FLAG_HIDE_TINTOWER_GUARD') end)

  beat('ho_oh', function()
    fieldMoves()
    assert(N.travel('TinTower_RoofDay'))
    N.settle()
    assert(N.go(10, 13, { allowTriggers = true })); N.settle()   -- the Kimono Girls' dance
    assert(N.talkFrom(10, 7, 2))          -- Ho-Oh: KO or catch, never run
  end, function() return V('VAR_ECRUTEAK_CITY_THEATER') >= 8 end)

  ------------------------------------------------------------------ Route 27 to the League
  beat('route27', function()
    fieldMoves()
    assert(N.travel('Route27'))           -- Surf east from New Bark; the first-steps trigger
    if V('VAR_ROUTE27_STATE') == 0 then assert(N.go(25, 24, { allowTriggers = true })) end
    N.settle()
  end, function() return V('VAR_ROUTE27_STATE') >= 1 and FL('FLAG_HIDE_LEAGUE_BLACKBELT') end)

  beat('reception_gate', function()
    fieldMoves()
    assert(N.travel('ReceptionGate'))     -- Tohjo Falls needs Surf and Waterfall
    assert(N.walk(function(x, y) return y < 14 end, { tag = 'gate check', allowTriggers = true }))
    N.settle()
  end, function() return V('VAR_ROUTE27_STATE') >= 2 end)

  -- Victory Road: two Strength pushes and a Rock Smash on B1F's upper level, Surf/Waterfall on B2F,
  -- then a smash, a push and a smash on B1F's lower level.
  local function useFieldMove(d) N.face(d); N.press('A'); N.idle(20); N.settle() end
  beat('victory_road', function()
    fieldMoves()
    assert(N.travel('JohtoVictoryRoad_1F'))
    assert(N.takeWarp(9, 14))                         -- 1F -> B1F (8,3)
    assert(N.go(5, 7)); useFieldMove(3)               -- Strength on (4,7)
    assert(N.push(3), 'push (4,7) west')
    assert(N.go(8, 10)); assert(N.push(4), 'push (9,10) east')
    assert(N.go(17, 12)); useFieldMove(4)             -- Rock Smash (18,12)
    assert(N.takeWarp(30, 25))                        -- B1F -> B2F
    assert(N.takeWarp(19, 12))                        -- B2F -> B1F lower (Surf, Waterfall)
    assert(N.go(19, 25)); useFieldMove(4)             -- Rock Smash (20,25)
    assert(N.go(20, 25)); useFieldMove(1)             -- Strength again on (20,26)
    assert(N.push(1), 'push (20,26) south')
    useFieldMove(4)                                   -- Rock Smash (21,26)
    assert(N.takeWarp(20, 21))                        -- B1F -> 1F (21,32)
    assert(N.travel('JohtoIndigoPlateau'))
  end, function() return at('JohtoIndigoPlateau') end)

  beat('league_entry', function()
    assert(N.travel('JohtoIndigoPlateau_PokemonCenter'))
    N.settle()
    assert(N.takeWarp(32, 2))                         -- the door to Will's room
  end, function() return V('VAR_LEAGUE_STATE') >= 1 and at('JohtoPokemonLeague_WillsRoom') end)

  for i, room in ipairs({ 'WillsRoom', 'KogasRoom', 'BrunosRoom', 'KarensRoom' }) do
    beat('e4_' .. room, function()
      N.settle()                                      -- the door seals behind us
      assert(N.talkFrom(6, 7, 2))
      assert(V('VAR_LEAGUE_STATE') >= i + 1, 'leader beaten')
      assert(N.takeWarp(6, 2))
    end, function() return V('VAR_LEAGUE_STATE') >= i + 1 and not at('JohtoPokemonLeague_' .. room) end)
  end

  -- Lance; his defeat runs straight on into the Mary/Oak scene, the walk to the Hall of Fame,
  -- the ceremony (Champion flag, save) and the credits, ending at home in New Bark.
  beat('lance_and_hall_of_fame', function()
    N.settle()
    assert(N.talkFrom(6, 9, 2, { limit = 60 * 60 * 20 }))
    for _ = 1, 60 * 60 * 20 // 12 do
      if FL('FLAG_JOHTO_CHAMPION') and F.ow() and N.free() then break end
      if F.ow() and N.free() and at('JohtoPokemonLeague_ChampionsRoom') then N.takeWarp(6, 2) end
      F.press('A', 2); F.idle(10)
    end
    N.settle()
    L('  after the ceremony: ' .. N.mapName() .. ' champion=' .. tostring(FL('FLAG_JOHTO_CHAMPION'))
      .. ' game clear=' .. tostring(FL('FLAG_SYS_GAME_CLEAR')))
  end, function() return FL('FLAG_JOHTO_CHAMPION') and F.ow() end)

  return B
end
