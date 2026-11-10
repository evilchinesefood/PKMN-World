-- Kanto post-game beats, run with PW_SEVII=1 PW_POSTGAME=1 after sevii_ferry_home. Gym and Elite
-- Four rematches on the HARD tier, Cerulean Cave, Moltres, and the Sevii islands' side maps.
return function(F, N, C, H)
  local L, P, O = F.L, require('pwsym'), require('pwoff')
  local beat, moves, V, FL, at, ferry, pushes = H.beat, H.moves, H.V, H.FL, H.at, H.ferry, H.pushes
  local sail = ferry.sail
  local WON = 1

  local function encKey() return F.r32(F.r32(P.gSaveBlock2Ptr) + O.sb2_encryptionKey) end

  -- Stack size of an item across the pockets. F.itemCount counts slots, not quantity.
  local function qty(id)
    local key, n = encKey() & 0xFFFF, 0
    for p = 0, 4 do
      local ptr = F.r32(F.S.gBagPockets + p * F.S.BagPocket.stride)
      local cap = F.pocketCap(p)
      if ptr >= 0x02000000 and ptr < 0x02040000 and cap > 0 and cap < 200 then
        for s = 0, cap - 1 do
          if F.r16(ptr + s * 4) == id then n = n + (F.r16(ptr + s * 4 + 2) ~ key) end
        end
      end
    end
    return n
  end

  local function enemyLeadLevel() return N.firstFoeLevel or 0 end
  local function wonLast() local b = N.battleLog[#N.battleLog]; return b and b.outcome == WON end

  local function setFlag(id)
    local a, n = F.sb1() + O.sb1_flags, id
    if id >= C.FLAG_JOHTO_BASE and id <= C.FLAG_JOHTO_END then a, n = F.sb3() + F.S.SaveBlock3.johtoFlags, id - C.FLAG_JOHTO_BASE end
    F.w8(a + (n >> 3), F.r8(a + (n >> 3)) | (1 << (n & 7)))
  end

  local function checkReward(tag, lvl, shard, nShard, stone, shards0, stones0)
    F.check(tag .. ' HARD team lead L' .. lvl, enemyLeadLevel() == lvl, 'lead L' .. enemyLeadLevel())
    F.check(tag .. ' won', wonLast())
    F.check(tag .. ' difficulty stays HARD', V('VAR_DIFFICULTY') == 2, 'difficulty ' .. V('VAR_DIFFICULTY'))
    F.check(tag .. ' shards +' .. nShard, qty(C[shard]) - shards0 == nShard, string.format('%d -> %d', shards0, qty(C[shard])))
    if stone then
      F.check(tag .. ' stone given', N.itemCount(C[stone]) - stones0 == 1, string.format('%d -> %d', stones0, N.itemCount(C[stone])))
    end
  end

  -- A rematch against a leader: talk, take the prompt, win, get the shard and the stone once.
  local function rematch(name, map, id, lvl, shard, stone, before)
    local s0, st0
    beat('pg_' .. name, function()
      moves()
      assert(N.travel(map), 'to ' .. map)
      if before then assert(before(), 'approach ' .. name) end
      s0, st0 = qty(C[shard]), stone and N.itemCount(C[stone]) or 0
      assert(N.talk(id, { side = 1 }), name)
      N.settle()
      checkReward('rematch ' .. name, lvl, shard, 1, stone, s0, st0)
    end, function() return F.ow() and N.free() and wonLast() end)
  end

  -- Vermilion's trash cans and Cinnabar's quiz doors stay open after the first clear.
  rematch('surge', 'VermilionCity_Gym_Frlg', 1, 58, 'ITEM_YELLOW_SHARD', nil)
  rematch('erika', 'CeladonCity_Gym_Frlg', 7, 58, 'ITEM_GREEN_SHARD', nil)
  rematch('sabrina', 'SaffronCity_Gym_Frlg', 7, 59, 'ITEM_YELLOW_SHARD', 'ITEM_ALAKAZITE', function() return N.goFar(14, 12) end)
  rematch('koga', 'FuchsiaCity_Gym_Frlg', 7, 58, 'ITEM_GREEN_SHARD', 'ITEM_BEEDRILLITE')

  -- A full Items pocket forfeits the shard and holds the stone; the next win pays both.
  beat('pg_misty_full_bag', function()
    moves()
    assert(N.travel('CeruleanCity_Gym_Frlg'), 'to the Cerulean Gym')
    -- The game re-keys bag quantities mid-battle, so what comes back must be re-encoded with the
    -- key of that moment.
    local ptr, cap, key = F.r32(F.S.gBagPockets), F.pocketCap(0), encKey() & 0xFFFF
    local saved = {}
    for s = 0, cap - 1 do saved[s] = { F.r16(ptr + s * 4), F.r16(ptr + s * 4 + 2) ~ key } end
    for s = 0, cap - 1 do F.w16(ptr + s * 4, C.ITEM_POTION); F.w16(ptr + s * 4 + 2, 1 ~ key) end
    local seen, s0 = #N.transcript, qty(C.ITEM_BLUE_SHARD)
    assert(N.talk(3, { side = 1 }), 'Misty')
    N.settle()
    local forfeited, pending = false, false
    for i = seen + 1, #N.transcript do
      forfeited = forfeited or N.transcript[i]:find('forfeited', 1, true) ~= nil
      pending = pending or N.transcript[i]:find('holding a MEGA STONE', 1, true) ~= nil
    end
    local after = encKey() & 0xFFFF
    for s = 0, cap - 1 do F.w16(ptr + s * 4, saved[s][1]); F.w16(ptr + s * 4 + 2, saved[s][2] ~ after) end
    F.check('full bag: rematch won', wonLast())
    F.check('full bag: shard forfeited', forfeited and qty(C.ITEM_BLUE_SHARD) == s0, tostring(forfeited))
    F.check('full bag: stone held, not lost', pending and not N.flag(C.FLAG_BNET_STONE_BASE + 23) and N.itemCount(C.ITEM_GYARADOSITE) == 0, tostring(pending))
  end, function() return F.ow() and N.free() and wonLast() end)
  rematch('misty', 'CeruleanCity_Gym_Frlg', 3, 58, 'ITEM_BLUE_SHARD', 'ITEM_GYARADOSITE')

  ------------------------------------------------------------------ Cerulean Cave
  beat('pg_cerulean_cave', function()
    moves()
    assert(N.travel('CeruleanCave_1F_Frlg'), 'into Cerulean Cave')
    assert(N.travel('CeruleanCave_B1F_Frlg'), 'down to B1F')
    assert(N.talk(3), 'Mewtwo')
    N.settle()
  end, function() return FL('FLAG_FOUGHT_MEWTWO') and at('CeruleanCave_B1F_Frlg') and F.ow() and N.free() end)

  rematch('brock', 'PewterCity_Gym_Frlg', 1, 58, 'ITEM_GREEN_SHARD', 'ITEM_AERODACTYLITE')

  -- Same leader again: the shard pays every win, the stone only once.
  beat('pg_brock_second', function()
    moves()
    local s0, st0 = qty(C.ITEM_GREEN_SHARD), N.itemCount(C.ITEM_AERODACTYLITE)
    assert(N.talk(1, { side = 1 }), 'Brock')
    N.settle()
    F.check('second rematch shard +1', qty(C.ITEM_GREEN_SHARD) - s0 == 1, string.format('%d -> %d', s0, qty(C.ITEM_GREEN_SHARD)))
    F.check('second rematch no second stone', N.itemCount(C.ITEM_AERODACTYLITE) == st0, tostring(N.itemCount(C.ITEM_AERODACTYLITE)))
  end, function() return F.ow() and N.free() and wonLast() end)

  rematch('giovanni', 'ViridianCity_Gym_Frlg', 8, 58, 'ITEM_RED_SHARD', nil)
  rematch('blaine', 'CinnabarIsland_Gym_Frlg', 8, 58, 'ITEM_RED_SHARD', 'ITEM_HOUNDOOMINITE')

  ------------------------------------------------------------------ The League again
  beat('pg_to_league', function()
    moves()
    F.check('league reset: Lorelei clear', not FL('FLAG_DEFEATED_LORELEI'))
    F.check('league reset: scene 0', V('VAR_MAP_SCENE_POKEMON_LEAGUE') == 0, 'scene ' .. V('VAR_MAP_SCENE_POKEMON_LEAGUE'))
    -- No Fly in the harness, and Route 23 resets the boulders: walk Victory Road again.
    assert(N.travel('VictoryRoad_1F_Frlg', { tile = { 7, 18 } }))
    for _, section in ipairs(H.victoryRoad) do section() end
    assert(N.travel('PokemonLeague_LoreleisRoom_Frlg'))
    N.settle()
  end, function() return at('PokemonLeague_LoreleisRoom_Frlg') end)

  local E4_SHARD = { LORELEI = 'ITEM_BLUE_SHARD', BRUNO = 'ITEM_RED_SHARD', AGATHA = 'ITEM_YELLOW_SHARD', LANCE = 'ITEM_RED_SHARD' }
  local E4_LEAD = { LORELEI = 70, BRUNO = 71, AGATHA = 72, LANCE = 73 }
  local function leagueRoom(room, member, next)
    local map = 'PokemonLeague_' .. room .. '_Frlg'
    local flag = 'FLAG_DEFEATED_' .. member
    local stone = member == 'AGATHA' and 'ITEM_GENGARITE' or nil
    beat('pg_' .. room, function()
      moves()
      if not at(map) then assert(N.travel(map)) end
      N.settle()
      local s0, st0 = qty(C[E4_SHARD[member]]), stone and N.itemCount(C[stone]) or 0
      assert(N.talk(1, { side = 1 }), member)
      N.settle()
      assert(FL(flag), member .. ' beaten')
      checkReward('rematch ' .. member, E4_LEAD[member], E4_SHARD[member], 2, stone, s0, st0)
      if next then assert(N.takeWarp(6, 2), 'out of ' .. map); N.settle() end
    end, function() return FL(flag) and (not next or at('PokemonLeague_' .. next .. '_Frlg')) end)
  end
  leagueRoom('LoreleisRoom', 'LORELEI', 'BrunosRoom')
  leagueRoom('BrunosRoom', 'BRUNO', 'AgathasRoom')
  leagueRoom('AgathasRoom', 'AGATHA', 'LancesRoom')
  leagueRoom('LancesRoom', 'LANCE', nil)

  -- Blue's room plays on its own; the Hall of Fame and the credits follow, then Pallet Town.
  beat('pg_champion', function()
    moves()
    local s0 = qty(C.ITEM_BLUE_SHARD)
    assert(N.takeWarp(6, 5, { limit = 60 * 60 * 20 }))
    local LEAGUE = { PokemonLeague_ChampionsRoom_Frlg = true, PokemonLeague_LancesRoom_Frlg = true,
                     PokemonLeague_HallOfFame_Frlg = true }
    local fought = false
    for _ = 1, 60 * 60 * 25 // 12 do
      fought = fought or N.inBattle()
      if fought and F.ow() and N.free() and not LEAGUE[N.mapName()] then break end
      if N.inBattle() then N.settle() else F.press('A', 2); F.idle(10) end
    end
    N.settle()
    L('  after the second Hall of Fame: ' .. N.mapName())
    checkReward('rematch champion', 77, 'ITEM_BLUE_SHARD', 2, nil, s0, 0)
    F.check('champion: both Mewtwonites', N.itemCount(C.ITEM_MEWTWONITE_X) == 1 and N.itemCount(C.ITEM_MEWTWONITE_Y) == 1)
    F.check('champion: league reset', not FL('FLAG_DEFEATED_LORELEI') and not FL('FLAG_DEFEATED_CHAMP') and V('VAR_MAP_SCENE_POKEMON_LEAGUE') == 0)
    F.check('champion: still champion', FL('FLAG_KANTO_CHAMPION'))
  end, function() return F.ow() and N.free() and FL('FLAG_DEFEATED_LANCE') == false end)

  ------------------------------------------------------------------ Sevii side maps
  beat('pg_ferry_out', function()
    moves()
    sail(0, 1)
  end, function() return at('OneIsland_Harbor_Frlg') end)

  -- Nurse healing, once per island: the party is set to 1 HP first so a real heal is visible.
  local function nurse(map, id, x, y)
    moves()
    assert(N.travel(map), 'to ' .. map)
    for i = 0, N.partyCount() - 1 do F.w16(P.gParties + i * O.mon_size + O.mon_hp, 1) end
    assert(N.talkFrom(x, y, 2), map .. ' nurse')
    N.settle()
    local full = true
    for i = 0, N.partyCount() - 1 do local m = N.partyMon(i); full = full and m.hp == m.maxHP end
    F.check('nurse heals on ' .. map, full and N.free())
  end
  local function nurseBeat(island, name, town)
    beat('pg_nurse_' .. name, function() nurse(island .. '_PokemonCenter_1F_Frlg', 1, 7, 4) end,
      function() return at(island .. '_PokemonCenter_1F_Frlg') end)
  end

  beat('pg_nurse_one', function() nurse('OneIsland_PokemonCenter_1F_Frlg', 1, 5, 4) end,
    function() return at('OneIsland_PokemonCenter_1F_Frlg') end)

  -- Two Strength boulders on Mt. Ember's lower slope wall off the summit path; routes solved offline.
  beat('pg_moltres', function()
    moves()
    assert(N.travel('MtEmber_Exterior_Frlg'), 'Mt. Ember')
    N.settle()
    pushes({ { 23, 45, 3 }, { 22, 45, 3 }, { 21, 45, 3 }, { 18, 46, 3 }, { 17, 46, 3 }, { 16, 46, 3 } }, 'Ember lower boulders')
    N.settle()
    assert(N.travel('MtEmber_Summit_Frlg'), 'Mt. Ember summit')
    N.settle()
    pushes({ { 10, 13, 2 }, { 10, 12, 3 }, { 9, 11, 3 }, { 8, 11, 2 }, { 7, 9, 4 }, { 8, 9, 4 } }, 'Moltres summit')
    N.settle()
    assert(N.talk(1, { side = 1 }), 'Moltres')
    N.settle()
  end, function() return FL('FLAG_FOUGHT_MOLTRES') and at('MtEmber_Summit_Frlg') and F.ow() and N.free() end)

  beat('pg_leave_ember', function()
    moves()
    assert(N.travel('MtEmber_SummitPath_1F_Frlg'), 'down the summit path')
    assert(N.travel('MtEmber_Exterior_Frlg'), 'back to the slope')
    pushes({ { 16, 46, 4 }, { 21, 45, 4 } }, 'Ember boulders, return')
    N.settle()
    assert(N.travel('OneIsland_Harbor_Frlg'), 'to the harbor')
  end, function() return at('OneIsland_Harbor_Frlg') end)

  beat('pg_cape_brink', function()
    moves()
    assert(N.travel('OneIsland_Harbor_Frlg'))
    sail(1, 2)
    assert(N.travel('TwoIsland_CapeBrink_House_Frlg'), 'Cape Brink house')
    -- The tutor wants a fully friendly, fully evolved starter in the lead; the run's Ivysaur is
    -- neither, so only his refusal plays here.
    assert(N.talk(1), 'tutor')
    N.settle()
  end, function() return at('TwoIsland_CapeBrink_House_Frlg') and N.free() end)

  beat('pg_nurse_two', function() nurse('TwoIsland_PokemonCenter_1F_Frlg', 1, 7, 4) end,
    function() return at('TwoIsland_PokemonCenter_1F_Frlg') end)

  beat('pg_lost_cave', function()
    moves()
    assert(N.travel('TwoIsland_Harbor_Frlg'))
    sail(2, 5)
    assert(N.travel('FiveIsland_LostCave_Room1_Frlg'), 'Lost Cave')
    local ROUTE = { { 8, 5 }, { 5, 1 }, { 5, 8 }, { 5, 8 }, { 8, 5 }, { 2, 5 }, { 5, 8 }, { 8, 5 }, { 5, 1 } }
    for i, w in ipairs(ROUTE) do
      assert(at('FiveIsland_LostCave_Room' .. i .. '_Frlg'), 'in room ' .. i .. ', at ' .. N.mapName())
      assert(N.takeWarp(w[1], w[2]), 'exit room ' .. i)
    end
    N.settle()
    N.settle()
  end, function() return FL('FLAG_HIDE_LOST_CAVE_SELPHY') end)

  beat('pg_nurse_five', function() nurse('FiveIsland_PokemonCenter_1F_Frlg', 1, 7, 4) end,
    function() return at('FiveIsland_PokemonCenter_1F_Frlg') end)

  beat('pg_altering_cave', function()
    moves()
    sail(5, 6)
    assert(N.travel('SixIsland_AlteringCave_Frlg'), 'Altering Cave')
    N.settle()
  end, function() return at('SixIsland_AlteringCave_Frlg') end)

  beat('pg_nurse_six', function() nurse('SixIsland_PokemonCenter_1F_Frlg', 1, 7, 4) end,
    function() return at('SixIsland_PokemonCenter_1F_Frlg') end)

  -- Seven boulders; the order keeps both corridors usable (computed by hand, see README).
  beat('pg_tanoby_key', function()
    moves()
    sail(6, 7)
    assert(N.travel('SevenIsland_SevaultCanyon_TanobyKey_Frlg'), 'Tanoby Key room')
    N.settle()
    pushes({ { 7, 7, 2 }, { 7, 6, 2 }, { 7, 5, 2 }, { 7, 4, 2 },              -- 1: up the middle to (7,2)
             { 5, 6, 4 }, { 7, 7, 2 }, { 7, 6, 2 },                           -- 7: east, then up
             { 6, 4, 4 }, { 7, 4, 4 }, { 8, 4, 4 },                           -- 7: on to (10,4)
             { 9, 6, 3 }, { 7, 7, 2 }, { 7, 6, 2 },                           -- 2: west, then up
             { 8, 4, 3 }, { 7, 4, 3 }, { 6, 4, 3 },                           -- 2: on to (4,4)
             { 7, 10, 3 }, { 5, 11, 2 }, { 5, 10, 2 },                        -- 4: to (5,8)
             { 7, 10, 4 },                                                    -- 5: into the east corridor
             { 6, 10, 2 }, { 6, 9, 2 }, { 6, 8, 2 }, { 7, 6, 3 },             -- 6: to (5,6)
             { 8, 10, 2 }, { 8, 9, 2 }, { 8, 8, 2 }, { 7, 6, 4 },             -- 3: to (9,6)
             { 9, 11, 2 }, { 9, 10, 2 } }, 'Tanoby Key')                       -- 5: to (9,8)
    N.settle()
  end, function() return FL('FLAG_SYS_UNLOCKED_TANOBY_RUINS') end)

  -- Chambers are empty until the Key puzzle is solved: walk a chamber and see what appears.
  beat('pg_tanoby_ruins', function()
    moves()
    assert(N.travel('SevenIsland_TanobyRuins_MoneanChamber_Frlg'), 'Monean Chamber')
    N.settle()
    local UNOWN = {}
    for name, v in pairs(C) do if name:find('^SPECIES_UNOWN') then UNOWN[v] = true end end
    local g = N.liveGrid()
    local a, b
    for y = 0, g.h - 1 do
      for x = 0, g.w - 1 do
        local v = g.get(x, y)
        if v and (v & 0x0C00) == 0 and not N.liveWarps()[x .. ',' .. y] then
          if not a then a = { x, y } elseif (x ~= a[1] or y ~= a[2]) then b = { x, y } end
        end
      end
    end
    local n0, unown = #N.battleLog, false
    for i = 1, 60 do
      local t = (i % 2 == 0) and a or b
      if t then N.go(t[1], t[2]); N.settle() end
      if #N.battleLog > n0 then
        unown = UNOWN[tonumber(N.battleLog[#N.battleLog].tag:match('foe=(%d+)'))] == true
        break
      end
    end
    L('  chamber walk: wild battles ' .. (#N.battleLog - n0) .. ', last ' .. tostring(N.battleLog[#N.battleLog] and N.battleLog[#N.battleLog].tag))
    F.check('tanoby: Unown appear after the Key', unown and #N.battleLog > n0, '')
    assert(N.travel('SevenIsland_TanobyRuins_Frlg'), 'out of the chamber')
  end, function() return at('SevenIsland_TanobyRuins_Frlg') end)

  beat('pg_nurse_seven', function() nurse('SevenIsland_PokemonCenter_1F_Frlg', 1, 7, 4) end,
    function() return at('SevenIsland_PokemonCenter_1F_Frlg') end)

  -- Trainer Tower is closed for renovations: the entry trigger must turn the player back.
  beat('pg_trainer_tower', function()
    moves()
    assert(N.travel('TrainerTower_Lobby_Frlg'), 'Trainer Tower lobby')
    local seen = #N.transcript
    N.go(9, 7, { allowTriggers = true })
    N.settle()
    local x, y = F.pos()
    local closed = false
    for i = seen + 1, #N.transcript do closed = closed or N.transcript[i]:lower():find('renovation', 1, true) ~= nil end
    L(string.format('  after the entry trigger: (%d,%d) closed-message=%s', x, y, tostring(closed)))
    F.check('trainer tower turned back', closed and y > 7, string.format('(%d,%d)', x, y))
    assert(N.travel('SevenIsland_TrainerTower_Frlg'), 'back out')
  end, function() return at('SevenIsland_TrainerTower_Frlg') and N.free() end)

  beat('pg_nurse_three', function()
    assert(N.travel('SevenIsland_Harbor_Frlg'))
    sail(7, 3)
    nurse('ThreeIsland_PokemonCenter_1F_Frlg', 1, 7, 4)
  end, function() return at('ThreeIsland_PokemonCenter_1F_Frlg') end)

  beat('pg_nurse_four', function()
    assert(N.travel('ThreeIsland_Harbor_Frlg'))
    sail(3, 4)
    nurse('FourIsland_PokemonCenter_1F_Frlg', 1, 7, 4)
  end, function() return at('FourIsland_PokemonCenter_1F_Frlg') end)

  beat('pg_ferry_home', function()
    moves()
    assert(N.travel('FourIsland_Harbor_Frlg'))
    sail(4, 0)
  end, function() return at('VermilionCity_Frlg') end)

  ------------------------------------------------------------------ Birth Island and Navel Rock
  -- The tickets come from Johto and the hub, outside a Kanto-only save, so they are granted here.
  local function ticketFerry(choice, harbor)
    assert(N.talk(6, { side = 2, policy = function(t, k)
      if k == 'yesno' then
        if t:lower():find('set sail') then return 'no' end
        return N.defaultPolicy(t, k)
      end
      return choice
    end }), 'ferry sailor')
    N.settle()
    assert(at(harbor), 'ferry reached ' .. harbor .. ', now at ' .. N.mapName())
  end

  -- Winning sets *_FLEW_AWAY (the fight respawns after a Hall of Fame); catching sets FOUGHT.
  local function deoxysMet() return FL('FLAG_FOUGHT_DEOXYS') or FL('FLAG_DEOXYS_FLEW_AWAY') end

  beat('pg_birth_island', function()
    moves()
    assert(N.debugGiveItem(C.ITEM_AURORA_TICKET, 1), 'give Aurora Ticket')
    setFlag(C.FLAG_ENABLE_SHIP_BIRTH_ISLAND)
    assert(N.travel('VermilionCity_Frlg', { tile = { 23, 32 } }))
    ticketFerry(1, 'BirthIsland_Harbor_Frlg')
    assert(N.travel('BirthIsland_Exterior_Frlg'), 'onto Birth Island')
    -- Each rock position has a step budget from the previous one (sStoneMaxStepCounts), so the
    -- side the player stands on matters; these stands fit all ten budgets.
    local STANDS = { { 15, 13, 2 }, { 12, 14, 3 }, { 15, 9, 2 }, { 18, 14, 4 }, { 13, 11, 3 }, { 17, 11, 4 }, { 15, 13, 1 },
                     { 12, 14, 3 }, { 18, 14, 4 }, { 15, 14, 1 }, { 15, 11, 2 } }
    for i, s in ipairs(STANDS) do
      assert(N.talkFrom(s[1], s[2], s[3]), 'triangle stand ' .. i)
      N.settle()
    end
  end, function() return deoxysMet() and at('BirthIsland_Exterior_Frlg') end)

  beat('pg_navel_rock', function()
    moves()
    assert(N.travel('BirthIsland_Harbor_Frlg'))
    assert(N.talk(2, { side = 2 }), 'Birth Island sailor')
    N.settle()
    assert(at('VermilionCity_Frlg'), 'sailed home, now at ' .. N.mapName())
    assert(N.debugGiveItem(C.ITEM_MYSTIC_TICKET, 1), 'give Mystic Ticket')
    setFlag(C.FLAG_ENABLE_SHIP_NAVEL_ROCK)
    ticketFerry(1, 'NavelRock_Harbor_Frlg')
    assert(N.travel('NavelRock_Summit_Frlg'), 'Navel Rock summit')
    N.go(9, 12, { allowTriggers = true })   -- the coord row brings Ho-Oh down
    N.settle()
  end, function() return (FL('FLAG_FOUGHT_HO_OH') or FL('FLAG_HO_OH_FLEW_AWAY')) and at('NavelRock_Summit_Frlg') end)

  beat('pg_lugia', function()
    moves()
    assert(N.travel('NavelRock_Base_Frlg'), 'Navel Rock base')
    assert(N.talk(1), 'Lugia')
    N.settle()
  end, function() return FL('FLAG_FOUGHT_LUGIA') or FL('FLAG_LUGIA_FLEW_AWAY') end)
end
