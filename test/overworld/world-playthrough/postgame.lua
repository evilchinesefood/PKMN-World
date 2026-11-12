-- PW_POSTGAME: post-game shared content, played as detours off a world run's checkpoints.
-- A detour plays its scene, then restores the checkpoint it started from, so the campaign carries on
-- from the state it would have had. See README.md, "Post-game".
return function(F, N, C, log, B, ctx)
  local L, S = F.L, F.S
  local P, O, MAPS = require('pwsym'), require('pwoff'), require('pwmaps')

  local NORMAL, HARD = 1, 2
  local REGION = { kanto = 1, johto = 2, hoenn = 3 }
  local ITEM_POCKET, BALL_POCKET = 0, 1
  local FRONTIER = { lo = 26, hi = 26 }
  local GROUP_HUB = 100

  local function difficulty() return N.var(C.VAR_DIFFICULTY) end
  local function active() return F.r8(F.sb2() + S.SaveBlock2.currentRegion) end
  local function FL(name) return N.flag(assert(C[name], name)) end
  local function champion(region)
    return FL('FLAG_' .. region:upper() .. '_CHAMPION')
  end
  local function champions()
    local n = 0
    for r in pairs(REGION) do if champion(r) then n = n + 1 end end
    return n
  end
  local function tier(tag, region)
    local want = champion(region) and HARD or NORMAL
    F.check(tag .. ': active region is ' .. region, active() == REGION[region], 'currentRegion=' .. active())
    F.check(tag .. ': tier follows the ' .. region .. ' champion flag', difficulty() == want,
      string.format('VAR_DIFFICULTY=%d want %d champions=%d', difficulty(), want, champions()))
  end

  local function said(from, needle)
    local t = table.concat(N.transcript, ' | ', from + 1)
    return t:find(needle, 1, true) ~= nil, t
  end
  local function talkAt(x, y, side, opts)
    local from = #N.transcript
    assert(N.approach(x, y, { side = side }), string.format('reach (%d,%d)', x, y))
    N.press('A'); N.idle(20)
    N.settle(opts)
    return from
  end

  local function warpMap(name)
    local m, digit = assert(MAPS[name], name), function(n, place) return (n // place) % 10 end
    assert(F.warpTo(digit(m.g, 100), digit(m.g, 10), digit(m.g, 1), digit(m.m, 100), digit(m.m, 10), digit(m.m, 1), 0, 0, 0, m.g, m.m, name), 'warp ' .. name)
    N.settle()
  end

  -- Whatever the game prints in battle goes through this buffer.
  local OBEY = { 'obey', 'nap', 'ignored', 'loafing', 'pretended', 'turned away' }
  local function whileIdling(scan, fn)
    local idle0, press0 = F.idle, F.press
    F.idle = function(n) for _ = 1, n do idle0(1); scan() end end
    F.press = function(k, n) press0(k, n); scan() end
    local ok, err = pcall(fn)
    F.idle, F.press = idle0, press0
    if not ok then error(err, 0) end
  end
  local function watchObedience(fn)
    local seen, last = 0, ''
    whileIdling(function()
      local m = N.decode(P.gDisplayedStringBattle, 200)
      if m ~= last then
        last = m
        for _, w in ipairs(OBEY) do
          if m:find(w, 1, true) then seen = seen + 1; L('    disobedient: ' .. m) end
        end
      end
    end, fn)
    return seen
  end

  -- Lead with met level above the badge limit, fight one wild battle on the live map's grass.
  local function wildBattle(map, tag, skipSetup)
    if not skipSetup then N.setMetLevel(0, 70); warpMap(map) end
    local grid, tx, ty, best = N.liveGrid(), nil, nil, 1e9
    for k, d in pairs(N.floodLive()) do
      local x, y = k:match('(-?%d+),(-?%d+)')
      x, y = tonumber(x), tonumber(y)
      local v = grid.get(x, y)
      if v and grid.beh(v & 0x3FF) == C.MB_TALL_GRASS and d < best then tx, ty, best = x, y, d end
    end
    assert(tx, 'no reachable grass on ' .. N.mapName())
    assert(N.go(tx, ty, { tag = 'grass', fight = true }), 'reached grass')
    local battles0 = N.battles.wild
    local seen = watchObedience(function()
      local dirs = { 3, 4 }
      for i = 1, 1200 do
        if N.battles.wild > battles0 then break end
        local d = dirs[i % 2 + 1]
        local x, y = F.pos()
        if N.liveGrid().get(x + N.DX[d], y + N.DY[d]) then N.walk(function(px) return px == x + N.DX[d] end, { attempts = 2, tag = 'grass step', fight = true }) end
        N.settle({ fight = true })
      end
    end)
    F.check(tag .. ': a wild battle played', N.battles.wild > battles0, N.battles.wild - battles0)
    return seen
  end

  local function respawnGroup() return F.r8(F.sb1() + S.SaveBlock1.lastHealLocation) end

  local function itemKey() return F.r32(F.sb2() + S.SaveBlock2.encryptionKey) & 0xFFFF end
  local function pocketSlots(pocket)
    local ptr, cap = F.r32(S.gBagPockets + pocket * S.BagPocket.stride), F.pocketCap(pocket)
    return ptr, cap
  end
  local function clearItem(id, pocket)
    local ptr, cap = pocketSlots(pocket)
    for s = 0, cap - 1 do
      if F.r16(ptr + s * 4) == id then F.w32(ptr + s * 4, 0) end
    end
  end
  -- Every empty Items slot gets a distinct item the rewards aren't made of.
  local function fillItemsPocket(keepFree, avoid)
    local ptr, cap = pocketSlots(ITEM_POCKET)
    local used, free = {}, {}
    for s = 0, cap - 1 do
      local id = F.r16(ptr + s * 4)
      if id == 0 then free[#free + 1] = s else used[id] = true end
    end
    local id = C.ITEM_POTION
    local key = itemKey()
    for i = 1, #free - (keepFree or 0) do
      while used[id] or id == avoid or id == C.ITEM_RED_SHARD or id == C.ITEM_BLUE_SHARD or id == C.ITEM_YELLOW_SHARD or id == C.ITEM_GREEN_SHARD do id = id + 1 end
      used[id] = true
      F.w32(ptr + free[i] * 4, id | ((1 ~ key) << 16))
    end
    L(string.format('  Items pocket: %d slots, %d were empty, %d left free', cap, #free, keepFree or 0))
  end
  local function freeItemSlots(n)
    local ptr, cap = pocketSlots(ITEM_POCKET)
    for s = cap - 1, 0, -1 do
      if n == 0 then break end
      local id = F.r16(ptr + s * 4)
      if id ~= 0 and id ~= C.ITEM_RED_SHARD and id ~= C.ITEM_BLUE_SHARD and id ~= C.ITEM_YELLOW_SHARD and id ~= C.ITEM_GREEN_SHARD then
        F.w32(ptr + s * 4, 0); n = n - 1
      end
    end
  end

  local function quantity(id)
    local total, key = 0, itemKey()
    for p = 0, 4 do
      local ptr, cap = pocketSlots(p)
      for s = 0, cap - 1 do
        if F.r16(ptr + s * 4) == id then total = total + (F.r16(ptr + s * 4 + 2) ~ key) end
      end
    end
    return total
  end

  ---------------------------------------------------------------- the Hub
  local function harbor()
    return talkAt(3, 14, 1)
  end

  local function harborTiers()
    local n = champions()
    local from = harbor()
    if n == 0 then
      F.check('harbor: refuses with no champion', (said(from, 'LEAGUE CHAMPION')) and N.itemCount(C.ITEM_EON_TICKET) == 0, n .. ' champions')
      return
    end
    F.check('harbor: Eon Ticket at ' .. n .. ' champion(s)', N.itemCount(C.ITEM_EON_TICKET) == 1 and FL('FLAG_ENABLE_SHIP_SOUTHERN_ISLAND'))
    from = harbor()
    if n < 2 then
      F.check('harbor: Old Sea Map refused at one champion', (said(from, 'TWO')) and N.itemCount(C.ITEM_OLD_SEA_MAP) == 0, table.concat(N.transcript, ' | ', from + 1))
      return
    end
    F.check('harbor: Old Sea Map at two champions', N.itemCount(C.ITEM_OLD_SEA_MAP) == 1 and FL('FLAG_ENABLE_SHIP_FARAWAY_ISLAND'))
    from = harbor()
    if n < 3 then
      F.check('harbor: Mystic Ticket refused at two champions', N.itemCount(C.ITEM_MYSTIC_TICKET) == 0, table.concat(N.transcript, ' | ', from + 1))
      return
    end
    F.check('harbor: Mystic Ticket at three champions', N.itemCount(C.ITEM_MYSTIC_TICKET) == 1 and FL('FLAG_ENABLE_SHIP_NAVEL_ROCK'))
    from = harbor()
    F.check('harbor: nothing left to give', (said(from, 'in your hands')), table.concat(N.transcript, ' | ', from + 1))
  end

  local function frontierGate()
    local n = champions()
    if n == 0 then
      local from = talkAt(4, 2, 1)
      F.check('frontier gate: locked with no champion', N.mapName() == 'RegionHub', table.concat(N.transcript, ' | ', from + 1))
      return
    end
    N.crossGate(4)
    F.check('frontier gate: open at ' .. n .. ' champion(s)', N.mapName():find('BattleFrontier') ~= nil, N.mapName())
  end

  local function domeRegistrar()
    N.settle()
    N.region = FRONTIER
    assert(N.travel('BattleFrontier_BattleDomeLobby'), 'to the Dome lobby')
    N.settle()
    local from = #N.transcript
    assert(N.talk(5, { policy = function(_, kind) if kind == 'yesno' then return 'no' end return 0 end }), 'dome registrar')
    local n, text = champions(), table.concat(N.transcript, ' | ', from + 1)
    if n < 3 then
      F.check('world championship: locked at ' .. n .. ' champion(s)', (said(from, 'Clear KANTO')), text)
    else
      F.check('world championship: offered at three champions', (said(from, 'Come back')) , text)
    end
    F.check('world championship: mode left clear', N.var(C.VAR_WORLD_CHAMPIONSHIP_MODE) == 0, N.var(C.VAR_WORLD_CHAMPIONSHIP_MODE))
  end

  local function leaderSimRefused(rowForRegion)
    local stage = 0
    local from = #N.transcript
    assert(N.go(9, 10)); N.face(2); N.press('A'); N.idle(20)
    N.settle({ policy = function(_, kind)
      if kind == 'yesno' then return 'no' end
      stage = stage + 1
      if stage == 1 then return 1 end            -- Leader Sim
      if stage == 2 then return rowForRegion end
      return 3                                   -- Exit
    end })
    return said(from, 'CHAMPION')
  end

  ---------------------------------------------------------------- Fly map, opened from the debug menu
  local function debugFly(mapsec)
    F.dbg(); F.sel(0); F.sel(0); F.idle(60)
    for _ = 1, 120 do if F.cb2() == (P.CB2_FlyMap & ~1) then break end; F.idle(5) end
    F.idle(90)
    local map = F.r32(P.sRegionMap)
    local entry = P.gRegionMapEntries + mapsec * 8
    local tx, ty = F.r8(entry) + 1, F.r8(entry + 1) + 2
    for _ = 1, 80 do
      if F.r16(map) == mapsec then break end
      local cx, cy = F.r16(map + O.rm_cursorPosX), F.r16(map + O.rm_cursorPosY)
      if cx < tx then N.press('Right', 2) elseif cx > tx then N.press('Left', 2)
      elseif cy < ty then N.press('Down', 2) elseif cy > ty then N.press('Up', 2) else break end
      F.idle(14)
    end
    L(string.format('  fly cursor on mapsec %d (wanted %d) type %d', F.r16(map), mapsec, F.r8(map + 2)))
    assert(F.r16(map) == mapsec, 'fly cursor reached the city')
    N.press('A', 2)
    local g0, m0 = F.grp(), F.mapn()
    for _ = 1, 600 do
      F.idle(5)
      if F.grp() ~= g0 or F.mapn() ~= m0 then break end
    end
    F.shot('after_fly_pick')
    L('  after fly pick: ' .. N.mapName() .. string.format(' cb2=%08x', F.cb2()))
    N.settle()
  end

  ---------------------------------------------------------------- Battle Net rematches
  -- gParties[B_TRAINER_OPPONENT_A][0], still there after the battle: HARD leaders field Lv58+.
  local function foeLeadLevel()
    return F.r8(P.gParties + C.B_TRAINER_OPPONENT_A * 6 * O.mon_size + O.mon_level)
  end
  local LEADERS = {
    roxanne = { map = 'RustboroCity_Gym', at = { 5, 2 }, shard = 'ITEM_GREEN_SHARD', stone = 'ITEM_AGGRONITE', stoneIdx = 0, beatenIdx = 0, shards = 1 },
    brock = { map = 'PewterCity_Gym_Frlg', at = { 6, 5 }, shard = 'ITEM_GREEN_SHARD', stone = 'ITEM_AERODACTYLITE', stoneIdx = 22, beatenIdx = 26, shards = 1 },
    falkner = { map = 'VioletCity_Gym', at = { 9, 4 }, shard = 'ITEM_BLUE_SHARD', stone = 'ITEM_PIDGEOTITE', stoneIdx = 13, beatenIdx = 13, shards = 1 },
  }
  local function rematch(who)
    local l = LEADERS[who]
    if N.mapName() ~= l.map then warpMap(l.map) end
    N.settle()
    local battles = N.battles.trainer
    local from, level = nil, 0
    whileIdling(function() level = math.max(level, foeLeadLevel()) end, function() from = talkAt(l.at[1], l.at[2], 1) end)
    F.check(who .. ': rematch battle played', N.battles.trainer == battles + 1, N.battles.trainer - battles)
    F.check(who .. ': HARD team', level >= 50, 'lead Lv' .. level)
    return from
  end
  local function stoneFlag(who) return C.FLAG_BNET_STONE_BASE + LEADERS[who].stoneIdx end
  local function beatenFlag(who) return C.FLAG_BNET_BEATEN_BASE + LEADERS[who].beatenIdx end

  local function rewardRoom(who, region)
    if not champion(region) then L('  not a ' .. region .. ' champion; skipped'); return end
    local l = LEADERS[who]
    local shardId, stoneId = C[l.shard], C[l.stone]
    local before = quantity(shardId)
    F.check(who .. ': stone not owned before', quantity(stoneId) == 0 and not N.flag(stoneFlag(who)))
    rematch(who)
    F.check(who .. ': shards paid', quantity(shardId) == before + l.shards, quantity(shardId) .. ' from ' .. before)
    F.check(who .. ': stone given', quantity(stoneId) == 1 and N.flag(stoneFlag(who)), quantity(stoneId))
    F.check(who .. ': beaten marker', N.flag(beatenFlag(who)))
    rematch(who)
    F.check(who .. ': shards repeat', quantity(shardId) == before + 2 * l.shards, quantity(shardId) .. ' from ' .. before)
    F.check(who .. ': stone once only', quantity(stoneId) == 1, quantity(stoneId))
  end

  local function rewardFullBag(who)
    local l = LEADERS[who]
    local shardId, stoneId = C[l.shard], C[l.stone]
    clearItem(shardId, ITEM_POCKET)
    fillItemsPocket(0)
    F.check(who .. ' full bag: no shard stack to add to', quantity(shardId) == 0)
    local from = rematch(who)
    local forfeit, t = said(from, 'forfeited')
    F.check(who .. ' full bag: shards forfeited with a message', forfeit and quantity(shardId) == 0, t)
    F.check(who .. ' full bag: stone pending with a message', (said(from, 'holding')) and quantity(stoneId) == 0, t)
    F.check(who .. ' full bag: stone flag left clear', not N.flag(stoneFlag(who)))
    F.check(who .. ' full bag: the win still counts', N.flag(beatenFlag(who)))
    F.check(who .. ' full bag: back in control', N.free(), N.mapName())
    freeItemSlots(2)
    from = rematch(who)
    F.check(who .. ' after room: shards paid', quantity(shardId) == l.shards, quantity(shardId))
    F.check(who .. ' after room: stone claimed', quantity(stoneId) == 1 and N.flag(stoneFlag(who)), table.concat(N.transcript, ' | ', from + 1))
  end

  local function crossFor(region)
    N.useHubPass()
    ctx.enter(region)
    N.crossGate(ctx.gates[region])
    ctx.restoreParty(region)
  end

  ---------------------------------------------------------------- storage refusal
  local function fillBoxes(spare)
    local base = F.r32(P.gPokemonStoragePtr) + O.ps_boxes
    local src = P.gParties
    local filled, slots = 0, 14 * 30
    local empty = {}
    for slot = 0, slots - 1 do
      local b = base + slot * O.box_size
      if F.r32(b) == 0 and F.r32(b + 4) == 0 and F.r32(b + 8) == 0 then empty[#empty + 1] = slot end
    end
    for i = 1, #empty - spare do
      local b = base + empty[i] * O.box_size
      for off = 0, O.box_size - 4, 4 do F.w32(b + off, F.r32(src + off)) end
      filled = filled + 1
    end
    L(string.format('  boxes: %d of %d were empty, %d filled, %d left', #empty, slots, filled, #empty - filled))
    return #empty - filled
  end

  ---------------------------------------------------------------- Frontier
  local function frontierPolicy(levelRow)
    local stage = 0
    return function(text, kind)
      if kind == 'yesno' then return text:find('list of') and 'no' or 'yes' end
      stage = stage + 1
      if stage == 1 then return 0 end            -- take the challenge
      if stage == 2 then return levelRow end
      return 0
    end
  end

  local function pickFrontierParty(slots)
    F.idle(60)
    for _, s in ipairs(slots) do
      for _ = 1, 8 do
        if F.r8(P.gPartyMenu + 9) == s then break end
        N.press('Down'); F.idle(14)
      end
      N.press('A'); F.idle(30)
      if F.r8(P.gSelectedOrderFromParty) ~= s + 1 and F.r8(P.gSelectedOrderFromParty + 1) ~= s + 1 and F.r8(P.gSelectedOrderFromParty + 2) ~= s + 1 then
        N.press('A'); F.idle(30)                 -- the action menu's ENTER row
      end
    end
    local o = {}
    for i = 0, 3 do o[#o + 1] = F.r8(P.gSelectedOrderFromParty + i) end
    L('  picked order ' .. table.concat(o, ','))
    N.press('Start'); F.idle(60)
  end

  local function retainParty(keep)
    for i = keep, 5 do
      local b = P.gParties + i * O.mon_size
      for off = 0, O.mon_size - 4, 4 do F.w32(b + off, 0) end
    end
    F.w8(P.gPartiesCount, keep)
  end

  local BUILD = {
    { species = 'SPECIES_SNORLAX', evs = { 252, 252, 0, 0, 0, 0 }, moves = { 'MOVE_BODY_SLAM', 'MOVE_EARTHQUAKE', 'MOVE_CRUNCH', 'MOVE_REST' } },
    { species = 'SPECIES_STARMIE', evs = { 0, 0, 0, 252, 252, 0 }, moves = { 'MOVE_SURF', 'MOVE_ICE_BEAM', 'MOVE_THUNDERBOLT', 'MOVE_PSYCHIC' } },
    { species = 'SPECIES_DRAGONITE', evs = { 0, 252, 0, 252, 0, 0 }, moves = { 'MOVE_DRAGON_CLAW', 'MOVE_EARTHQUAKE', 'MOVE_FIRE_PUNCH', 'MOVE_THUNDER_PUNCH' } },
    { species = 'SPECIES_ALAKAZAM', evs = { 0, 0, 0, 252, 252, 0 }, moves = { 'MOVE_PSYCHIC', 'MOVE_FIRE_PUNCH', 'MOVE_ICE_PUNCH', 'MOVE_THUNDER_PUNCH' } },
  }
  BUILD.banned1 = { species = 'SPECIES_MEWTWO', evs = { 0, 0, 0, 252, 252, 0 }, moves = { 'MOVE_PSYSTRIKE', 'MOVE_ICE_BEAM', 'MOVE_FLAMETHROWER', 'MOVE_THUNDERBOLT' } }
  BUILD.banned2 = { species = 'SPECIES_RAYQUAZA', evs = { 4, 252, 0, 252, 0, 0 }, moves = { 'MOVE_EARTHQUAKE', 'MOVE_DRAGON_CLAW', 'MOVE_EXTREME_SPEED', 'MOVE_THUNDERBOLT' } }
  local function give(i)
    local b = BUILD[i]
    local moves = {}
    for _, m in ipairs(b.moves) do moves[#moves + 1] = assert(C[m], m) end
    assert(N.giveMon({ species = C[b.species], level = 50, evs = b.evs, moves = moves }), 'give ' .. b.species)
  end

  local function towerAttendant(x, policy)
    local from = #N.transcript
    assert(N.approach(x, 5, { side = 1 }), 'tower attendant')
    N.press('A'); F.idle(20)
    N.settle({ policy = policy })
    return from
  end

  local function towerRefusals()
    assert(N.travel('BattleFrontier_BattleTowerLobby'))
    N.settle()
    retainParty(0)
    give('banned1'); give('banned2')             -- Mewtwo and Rayquaza: banned at the Frontier
    local from = towerAttendant(6, frontierPolicy(1))
    F.check('tower singles: refused with no eligible team', (said(from, 'eligible')), table.concat(N.transcript, ' | ', from + 1))
    F.check('tower singles: refusal returns control', N.free() and N.mapName() == 'BattleFrontier_BattleTowerLobby', N.mapName())
    give(1); give(2)
    from = towerAttendant(6, frontierPolicy(1))
    F.check('tower singles: refused with two eligible', (said(from, 'three eligible')), table.concat(N.transcript, ' | ', from + 1))
    give(3)
    from = towerAttendant(10, frontierPolicy(1))
    F.check('tower doubles: refused with three eligible', (said(from, 'four eligible')), table.concat(N.transcript, ' | ', from + 1))
    retainParty(2); give(1)
    from = towerAttendant(14, frontierPolicy(1))
    F.check('tower multis: refused with one eligible', (said(from, 'two eligible')), table.concat(N.transcript, ' | ', from + 1))
  end

  local function lastRow() return F.r8(S.sMenu + 4) end

  local function towerFirstBattle(rest)
    assert(N.travel('BattleFrontier_BattleTowerLobby'))
    N.settle()
    retainParty(0)
    give('banned1'); give('banned2')
    for i = 1, 4 do give(i) end
    local stage, screen, rested, retired = 0, N.screen, false, false
    N.noPicker = true
    N.screen = function()
      if F.cb2() == (P.CB2_UpdatePartyMenu & ~1) then
        pickFrontierParty({ 2, 3, 4 })
        return true
      end
      return screen and screen() or false
    end
    local policy = function(text, kind)
      local t = text:lower()
      if kind == 'yesno' then return 'yes' end
      stage = stage + 1
      if stage == 1 then return 0 end
      if stage == 2 then return 1 end             -- open level
      if t:find('cancel your') then retired = true; return 0 end
      if rest and not rested then rested = true; L('  choosing REST'); return lastRow() - 1 end
      return lastRow()                            -- RETIRE is always the bottom row
    end
    local battles0 = N.battles.trainer
    assert(N.approach(6, 5, { side = 1 }), 'tower attendant')
    N.press('A'); F.idle(20)
    for i = 1, 40 do
      N.settle({ policy = policy, noHeal = true, limit = 60 * 60 * 2 })
      L(string.format('  tower %d: %s (%d,%d)', i, N.mapName(), F.pos()))
      if N.mapName() == 'BattleFrontier_BattleTowerLobby' and retired and N.free() then break end
      if N.battles.trainer > battles0 + 1 then break end
      F.idle(30)
    end
    N.noPicker = nil
    F.check('tower: a battle was fought', N.battles.trainer > battles0, N.battles.trainer - battles0)
    F.check('tower: back in the lobby under control', N.mapName() == 'BattleFrontier_BattleTowerLobby' and N.free(), N.mapName())
    F.check('tower: party back to full', N.partyCount() == 6, N.partyCount())
    F.check('tower: no crash', not F.reportCrash('tower'))
  end

  local function exchange()
    assert(N.travel('BattleFrontier_ExchangeServiceCorner'))
    N.settle()
    local bpAddr = F.sb2() + S.SaveBlock2.bp
    F.w16(bpAddr, 100)
    clearItem(C.ITEM_PROTEIN, ITEM_POCKET)
    fillItemsPocket(0, C.ITEM_PROTEIN)
    local protein0 = quantity(C.ITEM_PROTEIN)
    local list = P.ScrollableMultichoice_ProcessInput
    local function buy(wantRefusal)
      local from = #N.transcript
      assert(N.go(9, 7), 'vitamin clerk counter'); N.face(2)
      N.press('A'); F.idle(20)
      local bought = false
      for _ = 1, 600 do
        N.noteMessage()
        if F.ow() and N.free() then break end
        if N.activeTask(P.Task_HandleYesNoInput) then
          F.idle(20); N.noteMessage(); N.press('A'); F.idle(30)
          bought = true
        elseif N.activeTask(list) then
          F.idle(10)
          N.press(bought and 'B' or 'A'); F.idle(30)
        else
          N.press('A'); F.idle(12)
        end
      end
      N.settle()
      return from
    end
    local from = buy()
    F.check('exchange: full bag refused', (said(from, 'space')) or (said(from, 'room')), table.concat(N.transcript, ' | ', from + 1))
    F.check('exchange: full bag took no BP', F.r16(bpAddr) == 100, F.r16(bpAddr))
    F.check('exchange: full bag gave nothing', quantity(C.ITEM_PROTEIN) == protein0)
    freeItemSlots(1)
    from = buy()
    F.check('exchange: bought with room', quantity(C.ITEM_PROTEIN) == protein0 + 1, quantity(C.ITEM_PROTEIN))
    F.check('exchange: BP charged', F.r16(bpAddr) < 100, F.r16(bpAddr))
    F.check('exchange: back in control', N.free(), N.mapName())
  end

  ---------------------------------------------------------------- detours
  local after = {}
  local only = os.getenv('PW_PG_ONLY')
  local detours = 0
  local function detour(anchor, name, region, fn)
    if only and not name:find(only) then return end
    local at
    for i, b in ipairs(B) do if b.name == (after[anchor] or anchor) then at = i end end
    if not at then L('  no anchor ' .. anchor .. ' in this order; skipping pg_' .. name); return end
    local full = 'pg_' .. name
    detours = detours + 1
    table.insert(B, at + 1, { name = full, run = function()
      local saved = ctx.snapshot()
      ctx.enter(region)
      local ok, err = xpcall(fn, debug.traceback)
      if not ok then
        L('  detour error: ' .. tostring(err))
        F.shot(full .. '_error')
        F.reportCrash(full)
      end
      ctx.enter(region)        -- a detour that crossed regions must leave the region table as it found it
      ctx.restore(saved)
      N.avoid = {}
      assert(N.restore(anchor), 'rewind to ' .. anchor)
      F.idle(30); N.debugHeal()
      if not ok then error(err, 0) end
    end, done = function() return true end })
    after[anchor] = full
  end

  -- Each region's Hall of Fame, as played in a world run, then a Hub trip from it.
  local function afterHall(anchor, region)
    detour(anchor, region .. '_hall_tier', region, function()
      F.check(region .. ' hall: champion flag set', champion(region))
      tier(region .. ' hall', region)
      L('  party ' .. N.partyCount() .. ' respawn group ' .. respawnGroup())
    end)
    detour(anchor, region .. '_hub_tickets', region, function()
      N.useHubPass()
      tier(region .. ' hub', region)
      harborTiers()
      frontierGate()
      domeRegistrar()
    end)
    detour(anchor, region .. '_gates', region, function()
      -- Every gate recalls the destination's remembered team and boxes the departing one (#377).
      local from = region
      ctx.keepParty(from)
      N.useHubPass()
      for _, to in ipairs({ 'kanto', 'johto', 'hoenn', region }) do
        if to ~= region or to == region and N.mapName() == 'RegionHub' then
          ctx.enter(to)
          N.crossGate(ctx.gates[to])
          L(string.format('  gate to %s landed %s party=%d', to, N.mapName(), N.partyCount()))
          tier('gate to ' .. to, to)
          if to ~= from then
            F.check('gates: ' .. to .. ' recalls its team', ctx.checkRecall(to, ctx.stashOf(from)))
          end
          from = to
          ctx.keepParty(from)
          N.useHubPass()
          ctx.enter(region)
        end
      end
    end)
  end

  -- Fly off the Frontier, which is a Hoenn map to the region map whatever region the player brought.
  local function frontierFly(anchor, region)
    detour(anchor, region .. '_frontier_fly', region, function()
      if not FL('FLAG_VISITED_MAUVILLE_CITY') then L('  Mauville not visited; skipped'); return end
      N.useHubPass()
      N.crossGate(4)
      N.settle()
      N.region = FRONTIER
      assert(N.travel('BattleFrontier_OutsideWest'))
      L('  at the Frontier: active region ' .. active() .. ', tier ' .. difficulty())
      debugFly(C.MAPSEC_MAUVILLE_CITY)
      L('  flew to ' .. N.mapName())
      F.check('frontier fly: landed in Hoenn', N.mapName() == 'MauvilleCity', N.mapName())
      tier('frontier fly', 'hoenn')
      local home, group = ctx.regions.hoenn.config.region, respawnGroup()
      F.check('frontier fly: whiteout respawn is in Hoenn', group >= home.lo and group <= home.hi, 'respawn group ' .. group)
    end)
  end

  -- Ferries change the active region without a Hub gate, so they don't box the party.
  local function ferryFrontier(row, destination, region)
    return function()
      local n0 = N.partyCount()
      N.region = FRONTIER
      assert(N.travel('BattleFrontier_OutsideWest'))
      local from = talkAt(19, 68, nil, { policy = function(_, kind) if kind == 'yesno' then return 'yes' end return row end })
      F.check('frontier ferry: sailed to ' .. destination, N.mapName() == destination, N.mapName() .. ' | ' .. table.concat(N.transcript, ' | ', from + 1))
      F.check('frontier ferry: party not boxed', N.partyCount() == n0, N.partyCount())
      tier('frontier ferry to ' .. destination, region)
      L('  respawn group ' .. respawnGroup())
    end
  end
  local function enterFrontier(partyRegion)
    N.useHubPass()
    if partyRegion then
      N.crossGate(ctx.gates[partyRegion])
      ctx.restoreParty(partyRegion)
      tier('gate to ' .. partyRegion, partyRegion)
      N.useHubPass()
    end
    N.crossGate(4)
    N.settle()
  end

  detour('k_giovanni', 'no_champion', 'kanto', function()
    F.check('no champion: tier NORMAL', difficulty() == NORMAL, difficulty())
    N.useHubPass()
    harborTiers()
    frontierGate()
    F.check('no champion: leader sims refused', leaderSimRefused(2))
  end)

  afterHall('k_home', 'kanto')
  afterHall('j_lance_and_hall_of_fame', 'johto')
  afterHall('h_home', 'hoenn')
  frontierFly('k_home', 'kanto')
  frontierFly('j_lance_and_hall_of_fame', 'johto')

  -- A Johto champion who has never been to Kanto: Elm's ticket, the ferry, and back.
  detour('j_lance_and_hall_of_fame', 'johto_ferry', 'johto', function()
    if champions() ~= 1 then L('  not a Johto-only champion; skipped'); return end
    assert(N.travel('NewBarkTown_Lab'))
    local from = talkAt(6, 3, 1)
    F.check('elm gives the S.S. Ticket', N.itemCount(C.ITEM_SS_TICKET) == 1, table.concat(N.transcript, ' | ', from + 1))
    warpMap('OlivineCity_PortInside')
    local n0 = N.partyCount()
    if not FL('FLAG_HIDE_OLIVINE_PORT_OAK') then talkAt(8, 16, 2) end
    N.settle()
    talkAt(8, 17, 2)
    F.check('maiden voyage boards', N.mapName() == 'SSAqua_1F', N.mapName())
    N.settle()
    N.setVar(C.VAR_SSAQUA_STATE, 6)   -- the ship's story belongs to Johto's own post-game
    talkAt(29, 2, 1)
    N.settle()
    F.check('maiden voyage lands in Vermilion', N.mapName() == 'VermilionCity_PortInside', N.mapName())
    F.check('maiden voyage: party not boxed', N.partyCount() == n0, N.partyCount())
    F.check('maiden voyage: no Kanto badges to obey', not N.flag(C.FLAG_KANTO_BADGE_1), '')
    tier('maiden voyage', 'kanto')
    F.check('maiden voyage: arrival scene advanced the ferry', N.var(C.VAR_SSAQUA_STATE) == 7, N.var(C.VAR_SSAQUA_STATE))
    L('  respawn group ' .. respawnGroup())
    ctx.enter('kanto')
    local kanto = wildBattle('Route1_Frlg', 'kanto obedience')
    for _ = 1, 8 do                   -- an obeying first move ends the battle, so keep fighting
      if kanto > 0 then break end
      kanto = kanto + wildBattle('Route1_Frlg', 'kanto obedience', true)
    end
    F.check('obedience follows Kanto (no badges): the Lv100 lead disobeyed', kanto > 0, kanto .. ' lines')
    N.setMetLevel(0, 5)
    warpMap('VermilionCity_PortInside')
    local n1 = N.partyCount()
    talkAt(8, 17, 2)
    F.check('return ferry lands in Olivine', N.mapName() == 'OlivineCity_PortInside', N.mapName())
    F.check('return ferry: party not boxed', N.partyCount() == n1, N.partyCount())
    tier('return ferry', 'johto')
    ctx.enter('johto')
    local johto = wildBattle('Route29', 'johto obedience')
    F.check('obedience follows Johto (8 badges): the Lv100 lead obeyed', johto == 0, johto .. ' lines')
    N.setMetLevel(0, 5)
    warpMap('OlivineCity_PortInside')
    talkAt(8, 17, 2)
    F.check('repeat crossing lands in Vermilion', N.mapName() == 'VermilionCity_PortInside', N.mapName())
    tier('repeat crossing', 'kanto')
    F.check('repeat crossing: party not boxed', N.partyCount() == n1, N.partyCount())
  end)

  detour('h_home', 'ferry_slateport_from_johto_party', 'hoenn', function()
    enterFrontier('johto')
    ferryFrontier(0, 'SlateportCity_Harbor', 'hoenn')()
  end)
  detour('h_home', 'ferry_lilycove_from_johto_party', 'hoenn', function()
    enterFrontier('johto')
    ferryFrontier(1, 'LilycoveCity_Harbor', 'hoenn')()
  end)

  local JOHTO_ONLY = os.getenv('PW_WORLD') == 'J'
  local FINAL, FINAL_REGION = JOHTO_ONLY and 'j_lance_and_hall_of_fame' or 'h_home', JOHTO_ONLY and 'johto' or 'hoenn'

  detour('h_home', 'bnet_roxanne', 'hoenn', function() rewardRoom('roxanne', 'hoenn') end)
  detour('h_home', 'bnet_brock_full_bag', 'hoenn', function()
    crossFor('kanto')
    tier('rematch in kanto', 'kanto')
    rewardFullBag('brock')
  end)
  detour(FINAL, 'bnet_falkner', FINAL_REGION, function()
    crossFor('johto')
    rewardRoom('falkner', 'johto')
  end)

  -- A gate swaps teams through the PC (#377): the remembered team comes out as the departing one
  -- goes in, so a tight PC still fits and nothing may be lost or cloned.
  local function occupied()
    local n, base = N.partyCount(), F.r32(P.gPokemonStoragePtr) + O.ps_boxes
    for slot = 0, 14 * 30 - 1 do if F.r32(base + slot * O.box_size) ~= 0 then n = n + 1 end end
    return n
  end
  local function tightCross(tag, spare)
    local other = FINAL_REGION == 'kanto' and 'johto' or 'kanto'
    ctx.keepParty(FINAL_REGION)
    N.useHubPass()
    local filler = F.r32(P.gParties)   -- fillBoxes copies the lead, so its PID repeats in the PC
    local left = fillBoxes(spare)
    local before = occupied()
    ctx.enter(other)
    N.crossGate(ctx.gates[other])
    F.check(tag .. ': gate allows the cross', N.mapName() ~= 'RegionHub', N.mapName() .. ' with ' .. left .. ' free slots')
    F.check(tag .. ': party is the remembered team', ctx.checkRecall(other, ctx.stashOf(FINAL_REGION), filler))
    F.check(tag .. ': every Pokemon kept, none cloned', occupied() == before, before .. ' -> ' .. occupied())
  end
  detour(FINAL, 'bank_tight', FINAL_REGION, function()
    tightCross('PC one short of the party', N.partyCount() - 1)
  end)
  detour(FINAL, 'bank_exact_fit', FINAL_REGION, function()
    tightCross('PC room for the party', N.partyCount())
  end)

  detour(FINAL, 'frontier', FINAL_REGION, function()
    N.useHubPass()
    N.crossGate(4)
    N.settle()
    N.region = FRONTIER
    towerRefusals()
    towerFirstBattle()
    exchange()
  end)
  detour(FINAL, 'tower_rest_resume', FINAL_REGION, function()
    N.useHubPass()
    N.crossGate(4)
    N.settle()
    N.region = FRONTIER
    towerFirstBattle(true)
  end)

  -- A misspelt PW_PG_ONLY would otherwise drop every detour and pass without testing anything.
  assert(not only or detours > 0, 'PW_PG_ONLY matched no detour: ' .. tostring(only))
  return B
end
