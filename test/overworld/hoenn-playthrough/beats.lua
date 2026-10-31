-- Ordered Hoenn story beats. Each beat: { name, run = function, done = predicate }.
-- Predicates follow docs/story-progress/hoenn.md; coordinates come from data/maps/*/map.json.
return function(F, N, C, log)
  local L = F.L
  local B = {}
  local function beat(name, run, done) B[#B + 1] = { name = name, run = run, done = done } end
  local function V(name) return N.var(C[name]) end
  local function FL(name) return N.flag(C[name]) end
  local function at(map) return N.mapName() == map end
  local function badge(n) return FL('FLAG_BADGE0' .. n .. '_GET') end
  N.region = { lo = 0, hi = 33 }   -- Hoenn's map groups (data/maps/map_groups.json)

  -- Rustboro's Match Call tutorial opens a start menu and insists on POKéNAV (slot 3).
  local basePolicy = N.defaultPolicy
  N.defaultPolicy = function(t, k)
    if k == 'multi' and t:lower():find('select the pok.-nav') then return 3 end
    return basePolicy(t, k)
  end
  -- ...then opens the POKéNAV, which only lets go after a Match Call (mode 1 -> 2), and then
  -- only through SWITCH OFF (src/pokenav_menu_handler.c HandleMainMenuInputEndTutorial).
  local P = require('pwsym')
  N.screen = function()
    if F.cb2() ~= (P.CB2_Pokenav & ~1) then N.pokenavTicks = 0; return false end
    local res = F.r32(P.gPokenavResources)
    local mode = res ~= 0 and F.r16(res + 8) or 0
    if mode == 1 then
      -- Down twice only once, from the main menu: later Downs would move the list cursor.
      -- The menu ignores input while it fades in, so wait first.
      N.pokenavTicks = (N.pokenavTicks or 0) + 1
      if N.pokenavTicks == 1 then N.idle(150) end
      local keys = N.pokenavTicks == 1 and { 'Down', 'Down', 'A' } or { 'A' }
      for _, k in ipairs(keys) do N.press(k); N.idle(60) end
    else
      for _, k in ipairs({ 'B', 'B', 'B', 'Down', 'A' }) do N.press(k); N.idle(40) end
    end
    L('  pokenav tutorial: mode ' .. mode)
    return true
  end

  beat('to_hoenn', function()
    assert(N.approach(21, 2, { side = 1 }), 'hub Hoenn attendant')
    for _ = 1, 500 do
      N.press('A'); N.idle(20)
      if F.grp() == 1 then break end
    end
    N.idle(200); N.settle()
  end, function() return at('LittlerootTown_BrendansHouse_2F') end)

  beat('clock', function()
    assert(N.talk({ 5, 1 }, { side = 1 }))
    N.settle()
  end, function() return FL('FLAG_SET_WALL_CLOCK') end)

  beat('meet_rival', function()
    assert(N.travel('LittlerootTown_MaysHouse_2F'))
    assert(N.talk({ 5, 4 }))
    N.settle()
  end, function() return V('VAR_LITTLEROOT_RIVAL_STATE') >= 3 end)

  beat('rescue_birch', function()
    assert(N.travel('Route101'))
    N.settle()
    assert(N.talk(3))   -- Birch's bag
    N.settle()
  end, function() return FL('FLAG_RESCUED_BIRCH') end)

  beat('starter_lab', function()
    N.settle()
    if not at('LittlerootTown_ProfessorBirchsLab') then assert(N.travel('LittlerootTown_ProfessorBirchsLab')) end
    N.settle()
  end, function() return V('VAR_BIRCH_LAB_STATE') >= 3 end)

  -- Parties are per region, so this happens in Hoenn, after the starter is chosen normally.
  -- Lv100 Mewtwo and Rayquaza from the debug Give menu, met level lowered to 5 for obedience.
  beat('party', function()
    assert(N.giveMon({ species = C.SPECIES_MEWTWO, level = 100, evs = { 4, 0, 0, 252, 252, 0 },
      moves = { C.MOVE_PSYSTRIKE, C.MOVE_AURA_SPHERE, C.MOVE_ICE_BEAM, C.MOVE_FLAMETHROWER } }))
    assert(N.giveMon({ species = C.SPECIES_RAYQUAZA, level = 100, evs = { 4, 252, 0, 252, 0, 0 },
      moves = { C.MOVE_EARTHQUAKE, C.MOVE_DRAGON_CLAW, C.MOVE_EXTREME_SPEED, C.MOVE_THUNDERBOLT } }))
    N.setMetLevel(1, 5)
    N.setMetLevel(2, 5)
    N.swapParty(0, 1)   -- Mewtwo leads; the starter stays in the party
  end, function() return N.partyCount() == 3 and N.partyMon(0).level == 100 end)

  beat('route103', function()
    N.run = true
    assert(N.travel('Route103'))
    assert(N.talk(2))
    N.settle()
  end, function() return FL('FLAG_DEFEATED_RIVAL_ROUTE103') end)

  beat('pokedex', function()
    assert(N.travel('LittlerootTown_ProfessorBirchsLab'))
    N.settle()
  end, function() return FL('FLAG_RECEIVED_POKEDEX_FROM_BIRCH') end)

  -- Norman sends us out with Wally to Route 102 for the catching tutorial, then back to the Gym.
  beat('petalburg', function()
    assert(N.travel('PetalburgCity_Gym'))
    N.settle()
    assert(N.talk(1))
    N.settle()
    if not at('PetalburgCity_Gym') then N.travel('PetalburgCity_Gym'); N.settle() end
  end, function() return V('VAR_PETALBURG_GYM_STATE') >= 2 end)

  beat('woods', function()
    assert(N.travel('PetalburgWoods'))
    assert(N.go(26, 23))
    N.settle()
  end, function() return V('VAR_PETALBURG_WOODS_STATE') ~= 0 end)

  beat('roxanne', function()
    assert(N.travel('RustboroCity_Gym'))
    assert(N.talk(1))
  end, function() return badge(1) end)

  -- Leaving the Gym, the thief runs past on x = 23; then the Devon employee by the corp asks for help.
  beat('devon_stolen', function()
    assert(N.travel('RustboroCity'))
    assert(N.walk(function(x, y) return x == 23 and y >= 20 and y <= 24 end, { tag = 'theft row' }))
    N.settle()
  end, function() return FL('FLAG_DEVON_GOODS_STOLEN') end)

  beat('devon_recover', function()
    assert(N.travel('RusturfTunnel'))
    assert(N.talk(6))   -- the grunt, beside Peeko
    N.settle()
  end, function() return FL('FLAG_RECOVERED_DEVON_GOODS') end)

  beat('devon_return', function()
    assert(N.travel('RustboroCity'))
    assert(N.walk(function(x, y) return (x == 30 and y >= 9 and y <= 12) or (x == 31 and y == 10) end, { tag = 'devon employee' }))
    N.settle()
  end, function() return FL('FLAG_RETURNED_DEVON_GOODS') end)

  beat('devon_president', function()
    assert(N.travel('RustboroCity_DevonCorp_3F'))
    assert(N.talk(1))
    N.settle()
  end, function() return FL('FLAG_RECEIVED_POKENAV') end)

  -- Mr. Briney sails from his cottage on Route 104 (Peeko was rescued in the tunnel).
  beat('sail_dewford', function()
    assert(N.travel('Route104_MrBrineysHouse'))
    assert(N.intercept(1))   -- he paces a loop around the room
    N.settle()
  end, function() return at('DewfordTown') end)

  beat('steven_letter', function()
    assert(N.travel('GraniteCave_StevensRoom'))
    assert(N.talk(1))
    N.settle()
  end, function() return FL('FLAG_DELIVERED_STEVEN_LETTER') end)

  beat('brawly', function()
    assert(N.travel('DewfordTown_Gym'))
    assert(N.talk(1))
  end, function() return badge(2) end)

  local function pick(idx)
    return function(t, k) if k == 'multi' then return idx end return N.defaultPolicy(t, k) end
  end

  beat('sail_slateport', function()
    assert(N.travel('DewfordTown'))
    assert(N.talk(2, { policy = pick(1) }))   -- PETALBURG / SLATEPORT / EXIT
    N.settle()
  end, function() return at('Route109') or at('SlateportCity') end)   -- Briney docks on Route 109's beach

  beat('devon_dock', function()
    assert(N.travel('SlateportCity_SternsShipyard_1F'))
    assert(N.talk(1))
  end, function() return FL('FLAG_DOCK_REJECTED_DEVON_GOODS') end)

  beat('devon_stern', function()
    assert(N.travel('SlateportCity_OceanicMuseum_2F'))
    assert(N.talk(1))
    N.settle()
  end, function() return FL('FLAG_DELIVERED_DEVON_GOODS') end)

  beat('route110', function()
    assert(N.travel('Route110'))
    assert(N.walk(function(x, y) return y == 56 and x >= 33 and x <= 35 end, { tag = 'route110 rival' }))
    N.settle()
  end, function() return V('VAR_ROUTE110_STATE') >= 1 end)

  beat('wally_mauville', function()
    assert(N.travel('MauvilleCity'))
    assert(N.talk(6))
    N.settle()
  end, function() return FL('FLAG_DEFEATED_WALLY_MAUVILLE') end)

  -- A live path to (tx,ty)'s side from where we stand, through the current barriers and
  -- without stepping on a switch (stepping on one changes the barriers).
  local function reachable(tx, ty)
    local x, y = F.pos()
    local goals = {}
    for _, d in ipairs({ { 0, 1 }, { 0, -1 }, { 1, 0 }, { -1, 0 } }) do goals[(tx + d[1]) .. ',' .. (ty + d[2])] = true end
    local occ = {}
    for _, o in ipairs(N.objects()) do occ[o.x .. ',' .. o.y] = o end
    for k in pairs(N.activeTriggers()) do occ[k] = true end
    return N.bfs(N.liveGrid(), x, y, N.elevation(), N.surfing(), function(px, py) return goals[px .. ',' .. py] end, { occ = occ }) ~= nil
  end

  -- Floor-switch puzzles (Mauville Gym): breadth-first search over switch presses. Each node is
  -- a savestate; a press walks to a switch without crossing another one, so a node's barriers
  -- are exactly what its press sequence made. Ends standing in the first state that can reach
  -- (tx,ty).
  local function solveSwitches(switches, tx, ty, stateVar)
    local tmp = F.out .. 'switch_'
    local n = 0
    local function save() n = n + 1; local f = tmp .. n .. '.ss'; client.savestate(f); return f end
    local function key() return V(stateVar) .. ':' .. table.concat({ F.pos() }, ',') .. ':' .. tostring(FL('FLAG_MAUVILLE_GYM_BARRIERS_STATE')) end
    if reachable(tx, ty) then return true end
    local q, head, seen = { save() }, 1, { [key()] = true }
    while head <= #q and n < 60 do
      local node = q[head]; head = head + 1
      for i, sw in ipairs(switches) do
        client.loadstate(node); N.idle(10); N.resetPlanCaches()
        if V(stateVar) ~= i and N.go(sw[1], sw[2], { attempts = 4, strictTriggers = true, allowTriggers = false }) then
          N.settle()
          local k = key()
          L(string.format('  switch %d at (%d,%d) -> %s', i, sw[1], sw[2], k))
          if reachable(tx, ty) then return true end
          if not seen[k] then seen[k] = true; q[#q + 1] = save() end
        end
      end
    end
    return false
  end

  beat('wattson', function()
    assert(N.travel('MauvilleCity_Gym'))
    -- Trainers who spot us walk into the corridors, so re-solve from wherever a walk gives up.
    for _ = 1, 4 do
      assert(solveSwitches({ { 0, 15 }, { 4, 12 }, { 3, 9 }, { 8, 9 } }, 5, 2, 'VAR_MAUVILLE_GYM_STATE'), 'Mauville switches')
      if N.talk(1, { strictTriggers = true, attempts = 6 }) and badge(3) then break end
    end
  end, function() return badge(3) end)

  beat('rock_smash', function()
    assert(N.travel('MauvilleCity_House1'))
    assert(N.talk(1))
  end, function() return FL('FLAG_RECEIVED_HM_ROCK_SMASH') end)

  return B
end
