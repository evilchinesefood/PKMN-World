-- Johto post-game beats, appended after the Hall of Fame by PW_POSTGAME=1 (see README.md).
return function(F, N, C, B, beat, fieldMoves)
  local L = F.L
  local P = require('pwsym')
  local function V(name) return N.var(C[name]) end
  local function FL(name) return N.flag(C[name]) end
  local function at(map) return N.mapName() == map end
  local function baseBeat(name)
    for _, b in ipairs(B) do if b.name == name then return b end end
    error('no beat ' .. name)
  end
  local DIFFICULTY_HARD = 2
  local LONG = 60 * 60 * 20

  local function report(tag, names)
    local t = {}
    for _, n in ipairs(names) do
      local value = n:sub(1, 4) == 'VAR_' and V(n) or tostring(FL(n))
      t[#t + 1] = n:gsub('^FLAG_', '') .. '=' .. tostring(value)
    end
    L('  state[' .. tag .. '] ' .. table.concat(t, ' '))
  end
  local LEGENDS = { 'VAR_COMPLETED_LUGIA', 'FLAG_HIDE_LUGIA', 'FLAG_CAUGHT_LUGIA', 'VAR_COMPLETED_HO_OH', 'FLAG_HIDE_HO_OH', 'FLAG_CAUGHT_HO_OH',
    'FLAG_HIDE_MOLTRES', 'FLAG_FOUGHT_MOLTRES', 'VAR_SUICUNE_ENCOUNTERS', 'FLAG_FOUGHT_SUICUNE', 'FLAG_HIDE_ROUTE25_SUICUNE',
    'VAR_AZALEA_TOWN_STATE', 'FLAG_CAUGHT_CELEBI', 'FLAG_HIDE_ILEX_FOREST_SECOND_CELEBI', 'FLAG_CAUGHT_ENTEI', 'FLAG_CAUGHT_RAIKOU', 'FLAG_DEFEATED_RED', 'FLAG_HIDE_KYOGRE' }

  -- The foes seen across every turn of the coming battles.
  local seen
  local function watchFoes()
    seen = {}
    N.foeHook = function(species, level, trainer)
      if trainer and level > 0 then seen[species] = level end
    end
  end
  local function lowestFoe()
    local low, text = 999, {}
    for sp, lv in pairs(seen) do low = math.min(low, lv); text[#text + 1] = sp .. ':L' .. lv end
    table.sort(text)
    N.foeHook = nil
    return low, table.concat(text, ' ')
  end

  -- Records whether the Hall of Fame and the credits ran, from settle and from pressUntil.
  local show
  local function watchShow()
    show = { hof = false, credits = false }
    N.settleHook = function()
      local cb2 = F.cb2()
      if P.CB2_HallOfFame and cb2 == (P.CB2_HallOfFame & ~1) then show.hof = true end
      if P.CB2_Credits and cb2 == (P.CB2_Credits & ~1) then show.credits = true end
    end
  end
  local function endShow(tag)
    N.settleHook = nil
    L(string.format('  %s: at %s, Hall of Fame seen=%s, credits seen=%s', tag, N.mapName(), tostring(show.hof), tostring(show.credits)))
  end

  -- Press through a cutscene until the player is free somewhere that answers `done`.
  local function pressUntil(done, limit)
    for _ = 1, (limit or LONG) // 12 do
      if N.settleHook then N.settleHook() end
      if F.ow() and N.free() and done() then return true end
      F.press('A', 2); F.idle(10)
    end
    return false
  end

  ------------------------------------------------------------------ the first Hall of Fame's effects
  beat('pg_first_clear', function()
    report('after first HoF', LEGENDS)
    L('  difficulty=' .. V('VAR_DIFFICULTY') .. ' league=' .. V('VAR_LEAGUE_STATE'))
  end, function()
    return FL('FLAG_JOHTO_CHAMPION') and FL('FLAG_SYS_GAME_CLEAR') and V('VAR_DIFFICULTY') == DIFFICULTY_HARD
      and V('VAR_LEAGUE_STATE') == 1 and FL('FLAG_INDIGOJUNCTION_HIDE_SILVER_GUARD')
  end)

  ------------------------------------------------------------------ gym rematches on the HARD tier
  local function boulders()
    assert(N.go(9, 8))
    N.face(4); N.press('A'); N.idle(20); N.settle()
    assert(N.push(4), 'push (10,8) right')
    assert(N.go(10, 7))
    assert(N.push(2), 'push (10,6) up')
    assert(N.go(9, 4))
    assert(N.push(4), 'push (10,4) right')
  end

  local function rematch(name, map, shard, count, stone, bit, approach)
    local shards, stones, low
    beat('pg_rematch_' .. name, function()
      fieldMoves()
      assert(N.travel(map))
      shards, stones = N.itemQty(C[shard]), stone and N.itemQty(C[stone]) or 0
      watchFoes()
      approach()
      N.settle()
      local text
      low, text = lowestFoe()
      L(string.format('  %s: foes %s; %s %d -> %d%s', name, text, shard, shards, N.itemQty(C[shard]),
        stone and string.format('; %s %d -> %d', stone, stones, N.itemQty(C[stone])) or ''))
    end, function()
      return low >= 58 and N.itemQty(C[shard]) == shards + count and (not stone or N.itemQty(C[stone]) == stones + 1)
        and N.flag(C.FLAG_BNET_BEATEN_BASE + bit) and at(map) and N.free()
    end)
  end

  rematch('falkner', 'VioletCity_Gym', 'ITEM_BLUE_SHARD', 1, 'ITEM_PIDGEOTITE', 13, function() assert(N.talk(1, { side = 1 })) end)

  -- The second win against a leader pays the shard again and no second stone.
  local shards2, stones2
  beat('pg_rematch_falkner_again', function()
    fieldMoves()
    shards2, stones2 = N.itemQty(C.ITEM_BLUE_SHARD), N.itemQty(C.ITEM_PIDGEOTITE)
    assert(N.talk(1, { side = 1 }))
    L(string.format('  second rematch: shards %d -> %d, stones %d -> %d', shards2, N.itemQty(C.ITEM_BLUE_SHARD), stones2, N.itemQty(C.ITEM_PIDGEOTITE)))
  end, function() return N.itemQty(C.ITEM_BLUE_SHARD) == shards2 + 1 and N.itemQty(C.ITEM_PIDGEOTITE) == stones2 end)

  rematch('bugsy', 'AzaleaTown_Gym', 'ITEM_GREEN_SHARD', 1, 'ITEM_SCIZORITE', 14, function()
    assert(N.go(6, 39)); N.settle()
    assert(N.go(16, 23)); N.settle()
    assert(N.talk(2, { side = 1 }))
  end)
  beat('pg_leave_bugsy_gym', function()
    assert(N.go(11, 11)); N.settle()      -- ride to (16,23)
    assert(N.go(11, 27)); N.settle()      -- ride to (6,39)
    assert(N.travel('AzaleaTown'))
  end, function() return at('AzaleaTown') end)

  rematch('whitney', 'GoldenrodCity_Gym', 'ITEM_YELLOW_SHARD', 1, nil, 15, function() assert(N.talk(4, { side = 1 })) end)
  rematch('morty', 'EcruteakCity_Gym', 'ITEM_YELLOW_SHARD', 1, 'ITEM_SABLENITE', 16, function() assert(N.talk(8, { side = 1 })) end)

  ------------------------------------------------------------------ Ho-Oh, caught this time
  beat('pg_hooh_catch', function()
    fieldMoves()
    report('before Ho-Oh', { 'VAR_COMPLETED_HO_OH', 'FLAG_HIDE_HO_OH', 'FLAG_CAUGHT_HO_OH' })
    assert(N.travel('TinTower_RoofDay'))
    N.settle()
    assert(N.go(10, 13, { allowTriggers = true })); N.settle()   -- the dance trigger is spent at var 4
    N.ballFirst(C.ITEM_MASTER_BALL, 5)
    N.catchBall, N.catchWanted = C.ITEM_MASTER_BALL, function(sp) return sp == C.SPECIES_HO_OH end
    assert(N.talk(7, { side = 1 }))
    N.catchBall, N.catchWanted = nil, nil
    report('after Ho-Oh', { 'VAR_COMPLETED_HO_OH', 'FLAG_HIDE_HO_OH', 'FLAG_CAUGHT_HO_OH' })
  end, function() return FL('FLAG_CAUGHT_HO_OH') and FL('FLAG_HIDE_HO_OH') and V('VAR_COMPLETED_HO_OH') == 3 and N.free() end)

  rematch('jasmine', 'OlivineCity_Gym', 'ITEM_YELLOW_SHARD', 1, 'ITEM_STEELIXITE', 18, function() assert(N.talk(1, { side = 1 })) end)
  rematch('chuck', 'CianwoodGym', 'ITEM_RED_SHARD', 1, 'ITEM_HERACRONITE', 17, function()
    boulders()
    assert(N.talkFrom(10, 3, 2))
  end)

  ------------------------------------------------------------------ Lugia, fought and not caught
  beat('pg_lugia_ko', function()
    fieldMoves()
    report('before Lugia', { 'VAR_COMPLETED_LUGIA', 'FLAG_HIDE_LUGIA', 'FLAG_CAUGHT_LUGIA' })
    assert(N.travel('WhirlIslands_Descent', { tile = { 35, 87 } }))   -- B1F's other warp lands in a sealed pocket
    assert(N.go(35, 87), 'walk to the Lugia chamber door')
    local blocker = N.object(4)
    L('  the tile below the chamber door: ' .. (blocker and 'Tentacruel stands on (35,86)' or 'clear'))
    F.shot('lugia_door')
    assert(not blocker, 'a Tentacruel blocks the only tile leading to the Lugia chamber door')
    assert(N.takeWarp(35, 85), 'chamber door')
    N.settle()
    assert(at('WhirlIslands_LugiaChamber'))
    assert(N.talk(1, { side = 1 }))
    report('after Lugia', { 'VAR_COMPLETED_LUGIA', 'FLAG_HIDE_LUGIA', 'FLAG_CAUGHT_LUGIA' })
  end, function() return FL('FLAG_HIDE_LUGIA') and not FL('FLAG_CAUGHT_LUGIA') and V('VAR_COMPLETED_LUGIA') == 3 and N.free() end)

  rematch('pryce', 'MahoganyTown_Gym', 'ITEM_BLUE_SHARD', 1, nil, 19, function() assert(N.talk(6)) end)
  beat('pg_ice_path', function()
    fieldMoves()
    assert(N.travel('IcePath_1F'))
    baseBeat('ice_path_b1f').run()
    baseBeat('ice_path_lower').run()
  end, function() return at('IcePath_1F') end)

  rematch('clair', 'BlackthornCity_Gym', 'ITEM_RED_SHARD', 1, 'ITEM_AMPHAROSITE', 20, function()
    assert(N.go(20, 55)); N.settle()
    assert(N.go(19, 41)); N.settle()
    assert(N.go(25, 27)); N.settle()
    assert(N.go(19, 16)); N.settle()
    assert(N.talk(4, { side = 1 }))
  end)

  ------------------------------------------------------------------ Mt. Silver
  beat('pg_moltres', function()
    fieldMoves()
    assert(N.travel('MtSilver_1F_MoltresRoom'), 'no route to the Moltres room')
    report('before Moltres', { 'FLAG_HIDE_MOLTRES', 'FLAG_FOUGHT_MOLTRES' })
    assert(N.talk(1, { side = 1 }))
    report('after Moltres', { 'FLAG_HIDE_MOLTRES', 'FLAG_FOUGHT_MOLTRES' })
  end, function() return FL('FLAG_HIDE_MOLTRES') and FL('FLAG_FOUGHT_MOLTRES') and N.free() end)

  beat('pg_silver_summit', function()
    fieldMoves()
    assert(N.travel('MtSilver_SummitDay'), 'no route to the summit')
    N.settle()
  end, function() return at('MtSilver_SummitDay') and not FL('FLAG_HIDE_MTSILVER_RED') end)

  local redShow
  beat('pg_red_first', function()
    fieldMoves()
    watchShow()
    assert(N.talk(1, { side = 1, limit = LONG }))
    assert(pressUntil(function() return FL('FLAG_DEFEATED_RED') end), 'never returned to the overworld after Red')
    N.settle()
    redShow = show
    endShow('after Red')
  end, function()
    return FL('FLAG_DEFEATED_RED') and N.free() and redShow.hof and V('VAR_DIFFICULTY') == DIFFICULTY_HARD
      and not FL('FLAG_HIDE_MTSILVER_RED')
  end)

  local rematchShow
  beat('pg_red_rematch', function()
    fieldMoves()
    assert(N.travel('MtSilver_SummitDay'), 'no route back to the summit')
    N.settle()
    assert(not FL('FLAG_HIDE_MTSILVER_RED'), 'Red is hidden')
    watchShow()
    assert(N.talk(1, { side = 1, limit = LONG }))
    assert(pressUntil(function() return true end, 60 * 60), 'never returned to the overworld after the rematch')
    rematchShow = show
    endShow('after Red rematch')
  end, function()
    return at('MtSilver_SummitDay') and N.free() and not rematchShow.hof and not rematchShow.credits and N.object(1) ~= nil
  end)

  ------------------------------------------------------------------ the second Hall of Fame
  local function hallOfFameAgain(tag)
    beat('pg_' .. tag .. '_to_league', function()
      fieldMoves()
      baseBeat('victory_road').run()
      N.debugHeal()   -- wild legendaries drain PP without triggering the between-battles heal
    end, function() return at('JohtoIndigoPlateau') end)
    beat('pg_' .. tag .. '_entry', function() baseBeat('league_entry').run() end, baseBeat('league_entry').done)
    for _, room in ipairs({ 'e4_WillsRoom', 'e4_KogasRoom', 'e4_BrunosRoom', 'e4_KarensRoom' }) do
      beat('pg_' .. tag .. '_' .. room, function() baseBeat(room).run() end, baseBeat(room).done)
    end
    local lanceShow
    beat('pg_' .. tag .. '_lance', function()
      N.settle()
      watchFoes()
      watchShow()
      assert(N.talkFrom(6, 9, 2, { limit = LONG }))
      assert(pressUntil(function()
        if at('JohtoPokemonLeague_ChampionsRoom') then N.takeWarp(6, 2); return false end
        return not N.mapName():find('JohtoPokemonLeague')
      end), 'never returned to the overworld after Lance')
      N.settle()
      lanceShow = show
      endShow('after Lance')
      local _, text = lowestFoe()
      L('  Lance foes ' .. text)
      report('after ' .. tag .. ' HoF', LEGENDS)
    end, function() return N.free() and lanceShow.hof and FL('FLAG_IS_KANTO_CHAMPION') and V('VAR_LEAGUE_STATE') == 1 end)
  end

  hallOfFameAgain('second')
  beat('pg_second_clear', function() report('second clear', LEGENDS) end, function()
    -- Fought, so it comes back; caught, so it stays gone.
    return V('VAR_COMPLETED_LUGIA') == 4 and not FL('FLAG_HIDE_LUGIA')
      and V('VAR_COMPLETED_HO_OH') == 3 and FL('FLAG_HIDE_HO_OH')
  end)

  ------------------------------------------------------------------ Suicune
  -- Every rematch clear puts Route 36's Sudowoodo back on the road.
  beat('pg_sudowoodo_again', function()
    fieldMoves()
    assert(N.travel('Route36'))
    assert(N.talk(6))
  end, function() return FL('FLAG_HIDE_SUDOWOODO') and N.free() end)

  beat('pg_suicune_cianwood', function()
    fieldMoves()
    assert(N.travel('CianwoodCity'))
    assert(N.go(18, 22, { allowTriggers = true }))
    N.settle()
    report('Suicune sighting', { 'VAR_SUICUNE_ENCOUNTERS' })
  end, function() return V('VAR_SUICUNE_ENCOUNTERS') >= 2 end)

  beat('pg_suicune_route42', function()
    fieldMoves()
    assert(N.travel('Route42'))
    assert(N.go(36, 15, { allowTriggers = true }))
    N.settle()
    report('Suicune sighting', { 'VAR_SUICUNE_ENCOUNTERS' })
  end, function() return V('VAR_SUICUNE_ENCOUNTERS') >= 3 end)

  local function digit(n, place) return (n // place) % 10 end
  local function debugWarp(map)
    local m = require('pwmaps')[map]
    assert(F.warpTo(digit(m.g, 100), digit(m.g, 10), digit(m.g, 1), digit(m.m, 100), digit(m.m, 10), digit(m.m, 1), 0, 0, 0, m.g, m.m, 'pg'), 'debug warp to ' .. map)
    N.settle()
  end
  beat('pg_suicune_route25', function()
    fieldMoves()
    L('  concession: debug warp to Route 25, because the walk from Johto is a Kanto crossing')
    debugWarp('Route25_Frlg')
    N.settle()
    assert(N.talk(14, { side = 1 }), 'Suicune is not on Route 25')
    report('after Suicune', { 'FLAG_FOUGHT_SUICUNE', 'FLAG_HIDE_ROUTE25_SUICUNE' })
    debugWarp('NewBarkTown')
  end, function() return FL('FLAG_FOUGHT_SUICUNE') and FL('FLAG_HIDE_ROUTE25_SUICUNE') and N.free() end)

  ------------------------------------------------------------------ Route 47's tower
  beat('pg_tower_kyogre', function()
    fieldMoves()
    assert(N.travel('Route47'), 'no route to Route 47')
    -- The tower's sea-level approach starts behind Cliff Edge Cave's ladders, which the planner misses.
    assert(N.takeWarp(85, 33), 'Cliff Edge Cave door')
    assert(N.takeWarp(36, 8), 'cave ladder')
    assert(N.takeWarp(24, 28), 'cave exit to the sea')
    assert(N.travel('EmbeddedTower'), 'no route to the Embedded Tower')
    N.settle()
    assert(N.talk(3, { side = 1 }))
  end, function() return FL('FLAG_HIDE_KYOGRE') and N.free() end)

  ------------------------------------------------------------------ the roaming beasts
  local OBJ_EVENT_MON = 1 << 14
  local function roamerReport(tag)
    local r0, r1 = N.roamer(0), N.roamer(1)
    L(string.format('  roamers[%s] %d hp=%d active=%s | %d hp=%d active=%s', tag, r0.species, r0.hp, tostring(r0.active), r1.species, r1.hp, tostring(r1.active)))
  end
  local function roamerActive(species)
    for i = 0, 1 do
      local r = N.roamer(i)
      if r.active and r.species == species then return true end
    end
    return false
  end
  local function slotOf(species)
    for i = 0, 1 do if N.roamer(i).species == species then return i end end
  end
  local function grassPair()
    local g, px, py = N.liveGrid(), F.pos()
    local best, bd
    for y = 0, g.h - 1 do
      for x = 0, g.w - 2 do
        local v = g.get(x, y)
        local v2 = g.get(x + 1, y)
        if v and v2 and g.beh(v & 0x3FF) == C.MB_TALL_GRASS and g.beh(v2 & 0x3FF) == C.MB_TALL_GRASS then
          local d = math.abs(x - px) + math.abs(y - py)
          if not bd or d < bd then best, bd = { x, y }, d end
        end
      end
    end
    return best
  end
  -- Walk up and down a grass patch until the beast's overworld sprite spawns, then catch up with it.
  local function huntBeast(species, budget, resolved)
    local slot = assert(slotOf(species), 'roamer slot')
    local pair = assert(grassPair(), 'no grass here')
    local left = true
    for step = 1, budget do
      N.placeRoamerHere(slot)
      if resolved() then return true end
      for _, o in ipairs(N.objects()) do
        if (o.gfx & ~OBJ_EVENT_MON) == species and (o.gfx & OBJ_EVENT_MON) ~= 0 then
          L(string.format('  beast sprite %d seen at (%d,%d) after %d steps', species, o.x, o.y, step))
          N.chase(o.localId)
          N.settle()
          if resolved() then return true end
        end
      end
      N.go(pair[1] + (left and 0 or 1), pair[2], { attempts = 4 })
      left = not left
      N.settle()
    end
    return resolved()
  end
  local huntedEntei, huntedRaikou
  beat('pg_roamers', function()
    fieldMoves()
    assert(N.travel('Route29'))
    roamerReport('start')
    N.ballFirst(C.ITEM_MASTER_BALL, 5)
    N.catchBall, N.catchWanted = C.ITEM_MASTER_BALL, function(sp) return sp == C.SPECIES_ENTEI end
    huntedEntei = FL('FLAG_CAUGHT_ENTEI') or not roamerActive(C.SPECIES_ENTEI) or huntBeast(C.SPECIES_ENTEI, 500, function() return FL('FLAG_CAUGHT_ENTEI') end)
    N.catchBall, N.catchWanted = nil, nil
    N.fightWanted = function(sp) return sp == C.SPECIES_RAIKOU end
    -- A roamer met on the road earlier may already be down; the walk-in flee logic can fight it.
    huntedRaikou = not roamerActive(C.SPECIES_RAIKOU) or huntBeast(C.SPECIES_RAIKOU, 500, function() return not roamerActive(C.SPECIES_RAIKOU) end)
    N.fightWanted = nil
    roamerReport('hunted')
    L(string.format('  hunt: Entei caught=%s, Raikou fainted=%s', tostring(huntedEntei), tostring(huntedRaikou)))
  end, function() return huntedEntei and huntedRaikou end)

  ------------------------------------------------------------------ Celebi
  beat('pg_celebi_shrine', function()
    fieldMoves()
    L('  concession: VAR_AZALEA_TOWN_STATE set to 8; the Unown-puzzle route to the GS Ball is not driven')
    N.setVar(C.VAR_AZALEA_TOWN_STATE, 8)
    assert(N.travel('AzaleaTown'))
    N.settle()
    assert(V('VAR_AZALEA_TOWN_STATE') == 9, 'Azalea did not hand over the GS Ball')
    assert(N.travel('IlexForest'))
    assert(N.talkFrom(32, 37, 2))
    N.settle()
    report('after Celebi', { 'VAR_AZALEA_TOWN_STATE', 'FLAG_CAUGHT_CELEBI', 'FLAG_HIDE_CELEBI' })
  end, function() return V('VAR_AZALEA_TOWN_STATE') == 10 and not FL('FLAG_CAUGHT_CELEBI') end)

  ------------------------------------------------------------------ the third Hall of Fame
  hallOfFameAgain('third')
  beat('pg_third_clear', function()
    report('third clear', LEGENDS)
    roamerReport('third clear')
  end, function()
    -- Caught stays gone, fainted comes back.
    local function beastRight(caught, species) return FL(caught) ~= roamerActive(species) end
    local beastsRight = beastRight('FLAG_CAUGHT_ENTEI', C.SPECIES_ENTEI) and beastRight('FLAG_CAUGHT_RAIKOU', C.SPECIES_RAIKOU)
    return beastsRight and not FL('FLAG_HIDE_ROUTE25_SUICUNE') and not FL('FLAG_FOUGHT_SUICUNE')
      and not FL('FLAG_HIDE_KYOGRE') and not FL('FLAG_HIDE_ILEX_FOREST_SECOND_CELEBI')
  end)

  beat('pg_second_celebi', function()
    fieldMoves()
    assert(N.travel('IlexForest'))
    N.ballFirst(C.ITEM_MASTER_BALL, 5)
    N.catchBall, N.catchWanted = C.ITEM_MASTER_BALL, function(sp) return sp == C.SPECIES_CELEBI end
    assert(N.talk(19, { side = 1 }), 'the second Celebi is not at the shrine')
    N.catchBall, N.catchWanted = nil, nil
    report('after second Celebi', { 'FLAG_CAUGHT_CELEBI', 'FLAG_HIDE_ILEX_FOREST_SECOND_CELEBI' })
  end, function() return FL('FLAG_CAUGHT_CELEBI') and FL('FLAG_HIDE_ILEX_FOREST_SECOND_CELEBI') and N.free() end)
end
