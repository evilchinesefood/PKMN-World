-- Hoenn post-game beats, appended after 'home' when PW_POSTGAME=1. See README's Post-game section.
return function(F, N, C, log, H)
  local L = F.L
  local beat, V, FL, at, segDMoves = H.beat, H.V, H.FL, H.at, H.segDMoves
  local P, O = require('pwsym'), require('pwoff')
  local MAPS = require('pwmaps')

  local function need(name)
    return assert(C[name], 'pwconst has no ' .. name)
  end

  local function forget(map)
    local m = MAPS[map]
    N.mapMemory[m.g * 256 + m.m] = nil
  end

  local function checkFlags(tag, setNames, clearNames)
    for _, name in ipairs(setNames) do F.check(tag .. ': ' .. name .. ' set', N.flag(need(name))) end
    for _, name in ipairs(clearNames) do F.check(tag .. ': ' .. name .. ' clear', not N.flag(need(name))) end
  end

  -- The cracked floors above Sky Pillar 1F need the Mach Bike at speed, and Trainer Hill's upper floors
  -- are arrow-tile slides; the planner models neither, so both hop with the debug menu's warp.
  local function debugWarp(map, warpId)
    local m = MAPS[map]
    local digit = function(n, place) return (n // place) % 10 end
    assert(F.warpTo(digit(m.g, 100), digit(m.g, 10), digit(m.g, 1), digit(m.m, 100), digit(m.m, 10), digit(m.m, 1),
      digit(warpId, 100), digit(warpId, 10), digit(warpId, 1), m.g, m.m, map), 'debug warp to ' .. map)
    N.settle()
  end


  -- The game's SetGameClearFlags, read off the live save right after the Hall of Fame.
  beat('pg_state', function()
    segDMoves()
    checkFlags('clear', { 'FLAG_HOENN_CHAMPION', 'FLAG_IS_CHAMPION', 'FLAG_SYS_GAME_CLEAR',
      'FLAG_RECEIVED_SS_TICKET', 'FLAG_LATIOS_OR_LATIAS_ROAMING',
      'FLAG_HIDE_SLATEPORT_CITY_STERNS_SHIPYARD_MR_BRINEY', 'FLAG_HIDE_VICTORY_ROAD_ENTRANCE_WALLY',
      'FLAG_HIDE_SAFARI_ZONE_SOUTH_CONSTRUCTION_WORKERS', 'FLAG_HIDE_LILYCOVE_CITY_RIVAL',
      'FLAG_HIDE_LITTLEROOT_TOWN_BRENDANS_HOUSE_RIVAL_BEDROOM', 'FLAG_HIDE_LITTLEROOT_TOWN_MAYS_HOUSE_RIVAL_BEDROOM' },
      { 'FLAG_DEFEATED_ELITE_4_SIDNEY', 'FLAG_DEFEATED_ELITE_4_PHOEBE', 'FLAG_DEFEATED_ELITE_4_GLACIA',
        'FLAG_DEFEATED_ELITE_4_DRAKE', 'FLAG_HIDE_SS_TIDAL_CORRIDOR_MR_BRINEY',
        'FLAG_HIDE_MOSSDEEP_CITY_STEVENS_HOUSE_INVISIBLE_NINJA_BOY', 'FLAG_HIDE_VICTORY_ROAD_EXIT_WALLY',
        'FLAG_HIDE_SLATEPORT_CITY_HARBOR_SS_TIDAL', 'FLAG_HIDE_LILYCOVE_HARBOR_SSTIDAL',
        'FLAG_HIDE_SAFARI_ZONE_SOUTH_EAST_EXPANSION', 'FLAG_HIDE_MOSSDEEP_CITY_STEVENS_HOUSE_BELDUM_POKEBALL',
        'FLAG_DEFEATED_MEW', 'FLAG_DEFEATED_LATIAS_OR_LATIOS', 'FLAG_DEFEATED_DEOXYS', 'FLAG_DEFEATED_LUGIA', 'FLAG_DEFEATED_HO_OH' })
    F.check('clear: VAR_DIFFICULTY is Hard', V('VAR_DIFFICULTY') == 2, tostring(V('VAR_DIFFICULTY')))
    F.check('clear: VAR_ELITE_4_STATE 0', V('VAR_ELITE_4_STATE') == 0, tostring(V('VAR_ELITE_4_STATE')))
    F.check('clear: VAR_STEVENS_HOUSE_STATE 2', V('VAR_STEVENS_HOUSE_STATE') == 2, tostring(V('VAR_STEVENS_HOUSE_STATE')))
    L('  roamer species var=' .. V('VAR_ROAMER_POKEMON'))
  end, function() return FL('FLAG_HOENN_CHAMPION') end)

  -- Gym rematches. The script offers one to any Hoenn champion (OfferRematch), yes/no, then the
  -- Hard-tier party. A beat passes only if that trainer was fought and beaten at the Hard tier's
  -- lead level (src/data/trainers.h [DIFFICULTY_HARD]), which the normal party can't match.
  local rematches = {}
  local function rematch(name, trainer, lvl, go)
    beat('pg_' .. name, function()
      segDMoves()
      local before = N.battles.trainer
      -- Start healed: a rematch is the beat's whole test, and the last beat's wild fights leave the lead
      -- short of PP and HP while N.needHeal only fires after a trainer or below 60% HP. (A retry always
      -- healed right after its restore, which hid this.)
      N.debugHeal()
      go()
      N.settle()
      local last = N.battleLog[#N.battleLog]
      local fought = F.r16(P.gTrainerBattleParameter + O.tbp_opponentA) == need(trainer)
      local won = fought and last and last.outcome == C.B_OUTCOME_WON and N.battles.trainer > before
      F.check(name .. ': rematch fought and won', won, tostring(last and last.tag))
      F.check(name .. ': Hard tier party', N.lastFoe and N.lastFoe.level >= lvl, 'L' .. tostring(N.lastFoe and N.lastFoe.level) .. ' want at least L' .. lvl)
      rematches[name] = won
    end, function() return rematches[name] end)
  end

  rematch('norman', 'TRAINER_NORMAN_1', 59, function()
    assert(N.travel('PetalburgCity_Gym'))
    N.settle()
    assert(N.talk(1, { side = 1 }), 'Norman')
  end)

  rematch('roxanne', 'TRAINER_ROXANNE_1', 59, function()
    assert(N.travel('RustboroCity_Gym'))
    assert(N.talk(1), 'Roxanne')
  end)

  rematch('brawly', 'TRAINER_BRAWLY_1', 58, function()
    assert(N.travel('DewfordTown_Gym'))
    assert(N.talk(1), 'Brawly')
  end)

  local noHubShuttle = function(t, k)
    if k == 'yesno' and t:lower():find('world transit') then return 'no' end
    return N.defaultPolicy(t, k)
  end

  -- The Hub's harbor master hands out the Eon Ticket to one-region champions.
  beat('pg_hub_eon', function()
    segDMoves()
    assert(N.travel('SlateportCity_Harbor'))
    N.useHubPass()
    assert(N.talk(12, { side = 1 }), 'harbor master')
    N.settle()
    F.check('hub: Eon Ticket', N.itemCount(C.ITEM_EON_TICKET) >= 1)
    F.check('hub: ship enabled', FL('FLAG_ENABLE_SHIP_SOUTHERN_ISLAND'))
    N.crossGate(21)
  end, function() return at('SlateportCity_Harbor') and N.itemCount(C.ITEM_EON_TICKET) >= 1 end)

  -- Slateport harbor's attendant offers the hub first and the ticketed S.S. Tidal after it.
  beat('pg_tidal_board', function()
    segDMoves()
    assert(N.travel('SlateportCity_Harbor'))
    N.settle()
    assert(N.talk(1, { side = 1, policy = noHubShuttle }), 'ferry attendant')
    N.settle()
  end, function() return at('SSTidalCorridor') or at('SSTidalRooms') end)

  -- Cabin 2's bed passes the voyage; the sailor at the exit lets you off at the far port.
  beat('pg_tidal_ride', function()
    segDMoves()
    N.settle()
    assert(N.walk(function(x, y) return x == 9 and y == 3 end, { tag = 'near Briney' }))
    F.check('tidal: Briney aboard', N.object(3) ~= nil)
    assert(N.takeWarp(7, 9), 'cabin 2 door')
    assert(N.talk({ 15, 12 }, { side = 3 }), 'bed')
    N.settle()
    L('  after the bed: VAR_SS_TIDAL_STATE=' .. V('VAR_SS_TIDAL_STATE'))
    assert(N.travel('SSTidalCorridor'))
    assert(N.talk(1, { side = 2 }), 'exit sailor')
    N.settle()
  end, function() return at('LilycoveCity_Harbor') end)

  -- The Lilycove attendant opens with the first-time Eon Ticket offer, then the ticket list.
  beat('pg_lati', function()
    segDMoves()
    assert(N.talk(1, { side = 1 }), 'ferry attendant')
    N.settle()
    assert(at('SouthernIsland_Exterior'), 'at ' .. N.mapName())
    L('  Southern Island reached; roamer var=' .. V('VAR_ROAMER_POKEMON'))
    assert(N.takeWarp(14, 5), 'into the island')
    N.settle()
    assert(N.talk({ 13, 11 }, { side = 1 }), 'eon stone')
    N.settle()
    local last = N.battleLog[#N.battleLog]
    L('  Lati battle outcome=' .. tostring(last and last.outcome) .. ' tag=' .. tostring(last and last.tag))
    F.check('lati: resolved', FL('FLAG_DEFEATED_LATIAS_OR_LATIOS') or FL('FLAG_CAUGHT_LATIAS_OR_LATIOS'))
    assert(N.travel('SouthernIsland_Exterior'))
    assert(N.talk(1, { side = 2 }), 'sailor')
    N.settle()
  end, function() return at('LilycoveCity_Harbor') end)

  beat('pg_pokeblock', function()
    segDMoves()
    forget('LilycoveCity')
    assert(N.travel('LilycoveCity_ContestLobby'))
    assert(N.talkFrom(14, 4, 2, { policy = function(t, k) if k == 'multi' then return 2 end return N.defaultPolicy(t, k) end }), 'receptionist')
    N.settle()
  end, function() return N.itemCount(C.ITEM_POKEBLOCK_CASE) >= 1 end)

  beat('pg_safari_enter', function()
    segDMoves()
    assert(N.travel('Route121_SafariZoneEntrance'))
    assert(N.walk(function(x, y) return x == 8 and y == 4 end, { tag = 'safari counter' }))
    N.settle()
    assert(at('SafariZone_South'), 'not in the Safari Zone: ' .. N.mapName())
  end, function() return at('SafariZone_South') and FL('FLAG_SYS_SAFARI_MODE') end)

  beat('pg_safari_expansion', function()
    segDMoves()
    checkFlags('safari', {}, { 'FLAG_HIDE_SAFARI_ZONE_SOUTH_EAST_EXPANSION' })
    F.check('safari: construction workers gone', N.object(5) == nil and N.object(6) == nil)
    assert(N.travel('SafariZone_Southeast'))
    assert(N.talk(5, { side = 1 }), 'expansion attendant')
    N.settle()
    assert(N.travel('SafariZone_South'))
    local doorSide = { side = 1 }   -- the attendant stands in front of the door, facing the zone
    for _ = 1, 2 do
      if not at('SafariZone_South') then break end
      assert(N.talk(1, doorSide), 'exit attendant')
      N.settle()
    end
  end, function() return at('Route121_SafariZoneEntrance') and not FL('FLAG_SYS_SAFARI_MODE') end)

  rematch('winona', 'TRAINER_WINONA_1', 58, function()
    assert(N.travel('FortreeCity_Gym'))
    N.settle()
    local x, y = F.pos()
    if x == 16 and y == 24 then N.push(3) end
    x, y = F.pos()
    assert(x == 15 and y == 24, string.format('gym start (%d,%d), want (15,24)', x, y))
    H.walkScript('N2 W11 N3 W2 S2 E1 N2 E1 N1 E3 N4 E2 N2 W2 S3 N1 E2 N4 W1 N1 W1 N1 W5 N1 W1 N1 E1 S2 E3 N6 W3 S6 E4 W1 N4 E9 N1 E1')
    assert(N.talk(1, { side = 1 }), 'Winona')
  end)

  beat('pg_weather_institute', function()
    segDMoves()
    assert(N.travel('Route119_WeatherInstitute_2F'))
    assert(N.go(2, 3), 'next to the scientist')
    assert(N.talk(5, { side = 1 }), 'weather scientist')
    N.settle()
    L('  abnormal weather location=' .. V('VAR_ABNORMAL_WEATHER_LOCATION') .. ' steps=' .. V('VAR_ABNORMAL_WEATHER_STEP_COUNTER'))
  end, function() return V('VAR_ABNORMAL_WEATHER_LOCATION') ~= 0 end)

  -- Abnormal weather: the location is random (CreateAbnormalWeatherEvent), so pin it to Route 118
  -- East, on the way to Mauville. Marine Cave's dive route is not played (see README).
  beat('pg_terra', function()
    segDMoves()
    L('  institute picked location=' .. V('VAR_ABNORMAL_WEATHER_LOCATION'))
    N.setVar(C.VAR_ABNORMAL_WEATHER_LOCATION, 7)
    N.setVar(C.VAR_ABNORMAL_WEATHER_STEP_COUNTER, 0)
    assert(N.travel('Route118'))
    N.settle()
    assert(N.go(42, 7), 'below the cave at (42,6)')
    assert(N.takeWarp(42, 6), 'into the cave')
    N.settle()
    assert(at('TerraCave_Entrance'), 'cave entrance, at ' .. N.mapName())
    assert(N.takeWarp(14, 1), 'into the cave')
    N.settle()
    N.go(17, 27)
    N.go(17, 26, { allowTriggers = true })
    N.settle()
    F.check('terra: Groudon resolved', FL('FLAG_DEFEATED_GROUDON'))
    assert(N.takeWarp(5, 4), 'out to the entrance')
    assert(N.takeWarp(8, 18), 'out of the cave')
  end, function() return FL('FLAG_DEFEATED_GROUDON') end)

  -- The Lati roams at random: pin it to this route, then step in grass until it appears (TryStartRoamerEncounter
  -- still rolls 1/4 on every wild encounter). The fight OHKOs, so the check is that it can't come back.
  local function grassTile()
    local grid, x, y = N.liveGrid(), F.pos()
    for r = 1, 40 do
      for dy = -r, r do
        for dx = -r, r do
          if math.max(math.abs(dx), math.abs(dy)) == r then
            local tx, ty = x + dx, y + dy
            local m = grid.get(tx, ty)
            if m and grid.beh(m & 0x3FF) == C.MB_TALL_GRASS and N.go(tx, ty) then return tx, ty end
          end
        end
      end
    end
  end
  local roamerMet = false
  beat('pg_roamer', function()
    segDMoves()
    assert(N.travel('Route118'))
    N.settle()
    assert(P.sRoamerLocation, 'no sRoamerLocation symbol')
    F.w8(P.sRoamerLocation, F.grp())
    F.w8(P.sRoamerLocation + 1, F.mapn())
    local before = #N.battleLog
    assert(grassTile(), 'no grass here')
    local function isLati()
      return N.lastFoe and (N.lastFoe.species == C.SPECIES_LATIAS or N.lastFoe.species == C.SPECIES_LATIOS)
    end
    N.lastFoe = nil
    roamerMet = false
    for i = 1, 600 do
      N.push(i % 2 + 1)
      if not N.free() then N.settle() end
      if isLati() then roamerMet = true; break end
      F.w8(P.sRoamerLocation, F.grp())
      F.w8(P.sRoamerLocation + 1, F.mapn())
    end
    L(string.format('  roamer: %d encounters, met=%s species=%s level=%s', #N.battleLog - before, tostring(roamerMet),
      tostring(N.lastFoe and N.lastFoe.species), tostring(N.lastFoe and N.lastFoe.level)))
    F.check('roamer: met it', roamerMet, (#N.battleLog - before) .. ' encounters')
  end, function() return roamerMet end)

  -- Wattson leaves the Gym for Mauville's square after Norman, and only returns once New Mauville is
  -- done and TM Thunderbolt collected (MauvilleCity ON_TRANSITION), so his rematch sits behind the quest.
  beat('pg_basement_key', function()
    segDMoves()
    assert(N.travel('MauvilleCity'))
    assert(N.talk(8), 'Wattson in the square')
    N.settle()
  end, function() return FL('FLAG_GOT_BASEMENT_KEY_FROM_WATTSON') end)

  beat('pg_new_mauville', function()
    segDMoves()
    assert(N.travel('NewMauville_Entrance'))
    N.settle()
    assert(N.go(4, 2, { allowTriggers = true }), 'to the locked door')
    N.settle()
    F.check('new mauville: door opened', V('VAR_NEW_MAUVILLE_STATE') == 1, tostring(V('VAR_NEW_MAUVILLE_STATE')))
    assert(N.travel('NewMauville_Inside'))
    N.settle()
    -- Blue opens the walls at x=23, x=10 rows 16-19 and x=10 rows 0-3; green opens x=37, x=28, x=10
    -- rows 24-27 and x=21. In order: blue, west past x=23, green, through x=10 rows 24-27, blue,
    -- round the west side to the top room, green to open x=21, then east to the red switch.
    for _, b in ipairs({ { 30, 38 }, { 18, 36 }, { 16, 22, ball = 2 }, { 17, 10, ball = 4 } }) do
      if b.ball then assert(N.talk(b.ball), 'item ball on the button'); N.settle() end
      assert(N.go(b[1], b[2], { attempts = 6, strictTriggers = true, allowTriggers = false }),
        string.format('button (%d,%d)', b[1], b[2]))
      N.settle()
      L(string.format('  pressed (%d,%d)', b[1], b[2]))
    end
    assert(N.go(33, 6, { allowTriggers = true }), 'red switch')
    N.settle()
    -- The way out is the reverse colour order. The Voltorb "item balls" sit on these two buttons.
    for _, b in ipairs({ { 13, 10, ball = 8 }, { 25, 18, ball = 6 } }) do
      assert(N.talk(b.ball), 'Voltorb on the button'); N.settle()
      assert(N.go(b[1], b[2], { attempts = 6, strictTriggers = true, allowTriggers = false }), 'exit button')
      N.settle()
      L(string.format('  pressed (%d,%d) on the way out', b[1], b[2]))
    end
  end, function() return V('VAR_NEW_MAUVILLE_STATE') == 2 end)

  beat('pg_thunderbolt', function()
    segDMoves()
    assert(N.travel('MauvilleCity'))
    N.settle()
    assert(N.talk(8), 'Wattson for the TM')
    N.settle()
  end, function() return FL('FLAG_GOT_TM_THUNDERBOLT_FROM_WATTSON') end)

  rematch('wattson', 'TRAINER_WATTSON_1', 58, function()
    assert(N.travel('MauvilleCity_Gym'))
    assert(N.travel('MauvilleCity'))
    F.check('wattson: back in the Gym', not FL('FLAG_HIDE_MAUVILLE_GYM_WATTSON'))
    assert(N.travel('MauvilleCity_Gym'))
    N.settle()
    assert(N.talk(1, { side = 1 }), 'Wattson')
  end)

  beat('pg_bike', function()
    segDMoves()
    assert(N.travel('MauvilleCity_BikeShop'))
    assert(N.talk(1), 'Rydel')
    N.settle()
  end, function() return N.itemCount(C.ITEM_MACH_BIKE) >= 1 or N.itemCount(C.ITEM_ACRO_BIKE) >= 1 end)

  -- Fill every free non-key slot so CheckBagHasSpace fails for the roof prize, then free the slots
  -- to prove the owner still has it.
  local fillers = { [0] = C.ITEM_ANTIDOTE, [1] = C.ITEM_NET_BALL, [2] = C.ITEM_TM17, [3] = C.ITEM_CHERI_BERRY }
  local function fillBag()
    local key = F.r16(F.r32(P.gSaveBlock2Ptr) + O.sb2_encryptionKey)
    local n = 0
    for p = 0, 3 do
      local ptr = F.r32(F.S.gBagPockets + p * F.S.BagPocket.stride)
      for s = 0, F.pocketCap(p) - 1 do
        if F.r16(ptr + s * 4) == 0 then
          F.w16(ptr + s * 4, fillers[p])
          F.w16(ptr + s * 4 + 2, 1 ~ key)
          n = n + 1
        end
      end
    end
    L('  bag filled: ' .. n .. ' slots')
  end
  -- Scans for the fillers rather than remembering slots, so a --from resume can still empty the bag.
  local function emptyBag()
    local key = F.r16(F.r32(P.gSaveBlock2Ptr) + O.sb2_encryptionKey)
    local n = 0
    for p = 0, 3 do
      local ptr = F.r32(F.S.gBagPockets + p * F.S.BagPocket.stride)
      for s = 0, F.pocketCap(p) - 1 do
        if F.r16(ptr + s * 4) == fillers[p] and F.r16(ptr + s * 4 + 2) == (1 ~ key) then
          F.w16(ptr + s * 4, 0)
          F.w16(ptr + s * 4 + 2, 0)
          n = n + 1
        end
      end
    end
    L('  bag restored: ' .. n .. ' slots')
    return n
  end
  local hillPolicy = function(t, k)
    if k == 'yesno' and t:lower():find('save') then return 'yes' end
    return N.defaultPolicy(t, k)
  end

  beat('pg_hill_enter', function()
    segDMoves()
    assert(N.travel('TrainerHill_Entrance'))
    fillBag()
    assert(N.walk(function(x, y) return x == 9 and y == 6 end, { tag = 'hill counter' }))
    N.settle({ policy = hillPolicy })
    assert(N.travel('TrainerHill_1F'))
    N.settle()
  end, function() return at('TrainerHill_1F') end)

  local function clearFloor(tag)
    for _ = 1, 8 do
      local trainers = {}
      for _, o in ipairs(N.objects()) do
        if o.trainerType ~= 0 then trainers[#trainers + 1] = o end
      end
      if #trainers == 0 then return end
      for _, o in ipairs(trainers) do
        local before = N.battles.trainer
        if N.talk(o.localId, { attempts = 3 }) then
          N.settle()
          L(string.format('  hill %s: local %d battles %d->%d', tag, o.localId, before, N.battles.trainer))
        end
      end
    end
  end
  local HILL_FLOORS = { 'TrainerHill_1F', 'TrainerHill_2F', 'TrainerHill_3F', 'TrainerHill_4F' }
  beat('pg_hill_climb', function()
    segDMoves()
    for i = 1, 2 do
      local floor = HILL_FLOORS[i]
      assert(at(floor), 'expected ' .. floor .. ', at ' .. N.mapName())
      L('  on ' .. floor .. ' objects=' .. #N.objects())
      clearFloor(floor)
      assert(N.travel(HILL_FLOORS[i + 1]), 'next floor ' .. i)
      N.settle()
    end
    L('  3F and 4F are arrow-tile slides the planner cannot walk; warping to the roof')
    debugWarp('TrainerHill_Roof', 0)
    N.settle()
    F.reportCrash('hill')
  end, function() return at('TrainerHill_Roof') end)

  beat('pg_hill_prize', function()
    segDMoves()
    local ids = {}
    for _, o in ipairs(N.objects()) do ids[#ids + 1] = o.localId end
    L('  roof objects ' .. table.concat(ids, ','))
    assert(N.talk(1, { side = 1 }), 'owner')
    N.settle()
    local msgFull
    for i = #N.transcript, math.max(1, #N.transcript - 6), -1 do
      if N.transcript[i]:lower():find('full') then msgFull = N.transcript[i]; break end
    end
    F.check('hill: full bag message', msgFull ~= nil, tostring(msgFull))
    F.check('hill: fillers removed', emptyBag() > 0)
    local mark = #N.transcript
    assert(N.talk(1, { side = 1 }), 'owner again')
    N.settle()
    local got, stillFull
    for i = mark + 1, #N.transcript do
      local t = N.transcript[i]:lower()
      if t:find('obtained') then got = N.transcript[i] end
      if t:find('full') then stillFull = N.transcript[i] end
    end
    F.check('hill: prize handed over once there is room', got ~= nil and stillFull == nil, tostring(got or stillFull))
    assert(N.takeWarp(15, 5), 'roof elevator')
    N.settle()
  end, function() return at('TrainerHill_Entrance') and N.free() end)

  rematch('flannery', 'TRAINER_FLANNERY_1', 58, function()
    assert(N.travel('Route112_CableCarStation'))
    F.check('hill: challenge closed on leaving', V('VAR_TRAINER_HILL_IS_ACTIVE') == 0, tostring(V('VAR_TRAINER_HILL_IS_ACTIVE')))
    assert(N.talk(1), 'cable car attendant')
    N.settle()
    assert(at('MtChimney_CableCarStation'), 'cable car arrived')
    assert(N.travel('LavaridgeTown_Gym_1F'))
    N.settle()
    local G1, G2 = 'LavaridgeTown_Gym_1F', 'LavaridgeTown_Gym_B1F'
    H.hop(G1, 8, 9, G2, 8, 9)
    H.hop(G2, 5, 14, G1, 5, 14)
    H.hop(G1, 0, 10, G2, 0, 10)
    H.hop(G2, 0, 6, G1, 0, 6)
    H.hop(G1, 2, 3, G2, 2, 3)
    H.hop(G2, 7, 2, G1, 7, 2)
    H.hop(G1, 10, 6, G2, 10, 6)
    H.hop(G2, 12, 12, G1, 12, 12)
    assert(N.talk(1, { side = 1 }), 'Flannery')
  end)

  rematch('tate_liza', 'TRAINER_TATE_AND_LIZA_1', 60, function()
    -- A double battle fields slots 0 and 1: put both Lv100s up front against the Hard team.
    if N.partyMon(1).level < 100 then N.swapParty(1, 2) end
    L('  party for the double: ' .. N.partyMon(0).level .. ', ' .. N.partyMon(1).level)
    -- Earthquake misses this all-Levitate front line and hits the partner instead.
    N.avoidMoves = { [C.MOVE_EARTHQUAKE] = true }
    -- This Hard double can beat the harness's two-attacker team, so a loss walks back and tries
    -- again (the respawn is the Lilycove Center, where the S.S. Tidal left us).
    local won = false
    for attempt = 1, 5 do
      forget('LilycoveCity')
      assert(N.travel('MossdeepCity_Gym'))
      N.settle()
      local pad, press = H.pad, H.press
      pad(1, 33, 2)
      press(23, 24, 22, 24, 1)
      press(15, 34, 16, 34, 2)
      press(23, 24, 24, 24, 1)
      press(23, 21, 23, 22, 1)
      pad(23, 20, 1)
      pad(7, 18, 4)
      press(8, 10, 8, 11, 3)
      press(8, 6, 8, 5, 3)
      press(6, 7, 7, 7, 4)
      press(8, 10, 8, 9, 1)
      pad(11, 3, 1)
      pad(13, 32, 1)
      assert(N.talk(1, { side = 1 }), 'Tate')
      N.settle()
      won = N.battleLog[#N.battleLog].outcome == C.B_OUTCOME_WON
      L(string.format('  Tate and Liza attempt %d: %s', attempt, won and 'won' or 'lost'))
      if won then break end
    end
    N.avoidMoves = nil
    assert(won, 'lost every attempt at Tate and Liza')
    assert(N.go(21, 6, { allowTriggers = true }), 'exit pad')
    N.settle()
  end)

  beat('pg_beldum', function()
    segDMoves()
    local before = N.partyCount()
    assert(N.travel('MossdeepCity_StevensHouse'))
    assert(N.talk(2), 'Beldum ball')
    N.settle()
    F.check('beldum: joined the party', N.partyCount() == before + 1, N.partyCount() .. ' mons')
    L('  beldum: flag=' .. tostring(FL('FLAG_RECEIVED_BELDUM')) .. ' lead level=' .. N.partyMon(N.partyCount() - 1).level)
    assert(N.talk(3), 'Steven letter')
    N.settle()
  end, function() return FL('FLAG_RECEIVED_BELDUM') end)

  rematch('juan', 'TRAINER_JUAN_1', 59, function()
    assert(N.travel('SootopolisCity_Gym_1F'))
    N.settle()
    local x, y = F.pos()
    assert(x == 8 and y == 25, string.format('gym entry (%d,%d)', x, y))
    for _, t in ipairs(H.ICE) do
      H.stepTo(t[1], t[2])
      local want = H.STAIRS[t[1] .. ',' .. t[2]]
      if want then
        for _ = 1, 300 do if V('VAR_ICE_STEP_COUNT') >= want and N.free() then break end; N.idle(1) end
        N.settle()
      end
    end
    assert(N.talk(1, { side = 1 }), 'Juan')
  end)

  beat('pg_sky_pillar', function()
    segDMoves()
    assert(N.travel('Route131'), 'to Route 131')
    assert(N.travel('SkyPillar_Outside'))
    assert(N.travel('SkyPillar_1F'))
    N.settle()
    L('  Sky Pillar 1F reached on foot; state=' .. V('VAR_SKY_PILLAR_STATE'))
    debugWarp('SkyPillar_Top', 0)
    assert(at('SkyPillar_Top'))
    assert(N.talk(2, { side = 1 }), 'Rayquaza')
    N.settle()
    L('  Rayquaza: defeated=' .. tostring(FL('FLAG_DEFEATED_RAYQUAZA')))
    F.check('rayquaza: resolved', FL('FLAG_DEFEATED_RAYQUAZA'))
    debugWarp('SkyPillar_Entrance', 0)
  end, function() return FL('FLAG_DEFEATED_RAYQUAZA') end)

  rematch('wally', 'TRAINER_WALLY_VR_2', 1, function()
    assert(N.travel('VictoryRoad_1F'), 'to Victory Road')
    assert(N.takeWarp(9, 14), '1F -> B1F (8,3)')
    assert(N.go(5, 7)); H.shove(3, '(4,7) west')
    assert(N.go(8, 10)); H.shove(4, '(9,10) east')
    assert(N.go(17, 12)); H.smash(4)
    assert(N.takeWarp(30, 25), 'B1F -> B2F')
    assert(N.takeWarp(19, 12), 'B2F -> B1F lower')
    assert(N.go(19, 25)); H.smash(4)
    assert(N.go(20, 25)); H.shove(1, '(20,26) south')
    H.smash(4)
    assert(N.takeWarp(20, 21), 'B1F -> 1F (21,32)')
    N.settle()
    assert(N.talk(7), 'Wally')
  end)

  -- The league again, after the Hall of Fame cleared its flags.
  for _, e in ipairs({ { 'SidneysRoom', 'SIDNEY' }, { 'PhoebesRoom', 'PHOEBE' }, { 'GlaciasRoom', 'GLACIA' },
                       { 'DrakesRoom', 'DRAKE' } }) do
    local room, flag = 'EverGrandeCity_' .. e[1], 'FLAG_DEFEATED_ELITE_4_' .. e[2]
    beat('pg_' .. e[1], function()
      segDMoves()
      if not at(room) then assert(N.travel(room)) end
      N.settle()
      assert(not FL(flag), e[2] .. ' still defeated')
      assert(N.talk(1, { side = 1 }), e[2])
      N.settle()
      F.check(e[2] .. ': beaten again', FL(flag))
      assert(N.takeWarp(6, 2), 'out of ' .. room)
    end, function() return FL(flag) and not at(room) end)
  end

  beat('pg_champion', function()
    segDMoves()
    local before = N.battles.trainer
    assert(N.travel('EverGrandeCity_Hall4'))
    N.takeWarp(5, 2, { limit = 60 * 60 * 20 })
    for _ = 1, 60 * 60 * 20 // 12 do
      if F.ow() and N.free() and N.mapName():find('^LittlerootTown_') then break end
      if F.ow() and N.free() and at('EverGrandeCity_Hall4') then N.takeWarp(5, 2) end
      if N.inBattle() then N.settle() else F.press('A', 2); F.idle(10) end
    end
    N.settle()
    F.check('champion: Wallace fought again', N.battles.trainer > before)
    L('  second Hall of Fame back at ' .. N.mapName())
  end, function() return F.ow() and N.mapName():find('^LittlerootTown_') ~= nil end)

  -- A second Hall of Fame re-runs SetGameClearFlags: state must not regress.
  beat('pg_home_again', function()
    segDMoves()
    checkFlags('reclear', { 'FLAG_RECEIVED_BELDUM', 'FLAG_RECEIVED_SS_TICKET' },
      { 'FLAG_DEFEATED_ELITE_4_SIDNEY', 'FLAG_DEFEATED_ELITE_4_DRAKE' })
    F.check('reclear: ball not re-shown', FL('FLAG_HIDE_MOSSDEEP_CITY_STEVENS_HOUSE_BELDUM_POKEBALL'))
    F.check('reclear: VAR_ELITE_4_STATE 0', V('VAR_ELITE_4_STATE') == 0)
    assert(N.travel(H.HOME .. '_1F'))
    N.settle()
    F.check('reclear: ticket scene not re-armed', V('VAR_LITTLEROOT_HOUSES_STATE_MAY') ~= 3, tostring(V('VAR_LITTLEROOT_HOUSES_STATE_MAY')))
  end, function() return at(H.HOME .. '_1F') and N.free() end)

  return H
end
