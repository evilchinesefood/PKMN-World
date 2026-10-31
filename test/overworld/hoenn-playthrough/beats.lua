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

  -- play.lua restores only the savestate on --from, so every beat re-derives the field moves.
  -- Hoenn unlocks: Rock Smash = Dynamo (badge 3), Surf = Balance (badge 5), src/field_move.c.
  local function segBMoves()
    N.run = true
    N.canSmash = badge(3)
    N.canSurf = badge(5)
  end

  -- Ride a warp tile on the current map and land on (ax,ay) of `dest` (Lavaridge Gym holes).
  local function hop(map, x, y, dest, ax, ay)
    assert(at(map), string.format('hop expects %s, at %s', map, N.mapName()))
    -- Holes and geysers fire on the step itself; a held key would walk us off the arrival tile.
    N.passGoal = { [x .. ',' .. y] = true }
    N.walk(function(px, py) return px == x and py == y end, { tag = string.format('hop(%d,%d)', x, y), allowWarp = true })
    N.passGoal = nil
    for _ = 1, 400 do if not at(map) then break end; N.idle(1) end
    for _ = 1, 120 do N.idle(1); if N.free() then break end end
    N.settle()
    local px, py = F.pos()
    assert(at(dest) and px == ax and py == ay,
      string.format('hop %s(%d,%d) landed at %s(%d,%d), want %s(%d,%d)', map, x, y, N.mapName(), px, py, dest, ax, ay))
  end

  -- Walk a run-length script ("N2 W11 ...") one tile per push, checking each landing tile.
  -- For rotating gates: the push that turns a gate also moves the player (src/rotating_gate.c).
  local DIR = { S = 1, N = 2, W = 3, E = 4 }
  local function walkScript(spec)
    local x, y = F.pos()
    local n = 0
    for tok in spec:gmatch('%S+') do
      local d = DIR[tok:sub(1, 1)]
      for _ = 1, tonumber(tok:sub(2)) do
        n = n + 1
        local tx, ty = x + N.DX[d], y + N.DY[d]
        for _ = 1, 3 do
          N.push(d)
          if not N.free() then N.settle() end
          local px, py = F.pos()
          if px == tx and py == ty then break end
          assert(px == x and py == y, string.format('step %d %s: at (%d,%d), want (%d,%d)', n, tok, px, py, tx, ty))
          N.idle(20)   -- bumped (a trainer walking up, a gate mid-turn): push again
        end
        local px, py = F.pos()
        assert(px == tx and py == ty, string.format('step %d %s blocked at (%d,%d)', n, tok, px, py))
        x, y = tx, ty
      end
    end
  end

  -- Without Go-Goggles the Route 111 desert is sealed by VAR_TEMP_3 push-back triggers, which the
  -- planner cannot see; it would plan straight through the sand. Go round by Fiery Path instead.
  beat('to_fiery_path', function()
    segBMoves()
    assert(N.travel('FieryPath'))   -- smashes Route111 rock 15 at (18,101) on the way
  end, function() return at('FieryPath') end)

  -- Arrive on the south arrow warp (26,36); leave by the north one (26,4) into Route 112 north.
  beat('fiery_path', function()
    segBMoves()
    assert(N.takeWarp(26, 4))
  end, function() local _, y = F.pos(); return at('Route112') and y < 20 end)

  beat('to_meteor_falls', function()
    segBMoves()
    assert(N.travel('MeteorFalls_1F_1R'))   -- Route112 -> Route111 north -> Route113 -> Fallarbor -> Route114
  end, function() return at('MeteorFalls_1F_1R') end)

  -- Coord event (14,18), VAR_METEOR_FALLS_STATE == 0: Magma steals the meteorite, Aqua follows.
  beat('meteor_falls', function()
    segBMoves()
    assert(N.go(14, 18))
    N.settle()
  end, function() return FL('FLAG_MET_ARCHIE_METEOR_FALLS') and V('VAR_METEOR_FALLS_STATE') >= 1 end)

  -- Back the way we came: the desert is still sealed, so north door of Fiery Path, then its south one.
  beat('back_to_fiery_path', function()
    segBMoves()
    assert(N.travel('FieryPath'))
    assert(N.takeWarp(26, 36))
  end, function() local _, y = F.pos(); return at('Route112') and y > 30 end)

  -- FLAG_HIDE_ROUTE_112_TEAM_MAGMA (MeteorFalls_1F_1R/scripts.inc:86) cleared the station door.
  -- Attendant: (6,6) on a first visit, (6,7) after any ride, (7,4) mid exit scene; talk to him live.
  beat('cable_car_up', function()
    segBMoves()
    assert(N.travel('Route112_CableCarStation'))
    assert(N.talk(1))      -- "ready to go up" -> YES (default policy); the ride takes no input
    N.settle()
  end, function() return at('MtChimney_CableCarStation') end)

  -- Tabitha and both grunts are forced on the way (two grunts at once is a double battle).
  -- Maxie (13,6) is reachable only from (13,7) or (12,6).
  beat('mt_chimney', function()
    segBMoves()
    assert(N.travel('MtChimney'))
    assert(N.talk(2, { side = 1 }))
    N.settle()
  end, function() return FL('FLAG_DEFEATED_EVIL_TEAM_MT_CHIMNEY') end)

  -- Down the arrow warp (20,41), Jagged Pass ledges, arrow warp (14,40), Route 112 (6,46), west.
  beat('jagged_pass', function()
    segBMoves()
    assert(N.travel('LavaridgeTown'))
  end, function() return at('LavaridgeTown') end)

  -- Hole/geyser chain (BFS-checked, avoids every buried trainer). Each landing tile is checked.
  beat('flannery', function()
    segBMoves()
    assert(N.travel('LavaridgeTown_Gym_1F'))
    local G1, G2 = 'LavaridgeTown_Gym_1F', 'LavaridgeTown_Gym_B1F'
    hop(G1, 8, 9, G2, 8, 9)
    hop(G2, 5, 14, G1, 5, 14)
    hop(G1, 0, 10, G2, 0, 10)
    hop(G2, 0, 6, G1, 0, 6)
    hop(G1, 2, 3, G2, 2, 3)
    hop(G2, 7, 2, G1, 7, 2)
    hop(G1, 10, 6, G2, 10, 6)
    hop(G2, 12, 12, G1, 12, 12)
    assert(N.talk(1, { side = 1 }))   -- Flannery (13,9) from (13,10)
    N.settle()
  end, function() return badge(4) and V('VAR_LAVARIDGE_TOWN_STATE') >= 1 end)

  -- ON_FRAME VAR_LAVARIDGE_TOWN_STATE == 1: the rival walks out of the Herb Shop with the goggles.
  beat('go_goggles', function()
    segBMoves()
    assert(N.travel('LavaridgeTown'))
    N.settle()
  end, function() return FL('FLAG_RECEIVED_GO_GOGGLES') and V('VAR_LAVARIDGE_TOWN_STATE') >= 2 end)

  -- No Fly before badge 6. On foot: Route112 -> Route111 -> Mauville -> Route117 -> Verdanturf ->
  -- Rusturf Tunnel (rock local 2 at (24,5), only from (25,5); its scene gives HM Strength) -> Route116.
  beat('to_rustboro', function()
    segBMoves()
    assert(N.travel('RustboroCity'))
  end, function() return at('RustboroCity') and FL('FLAG_RUSTURF_TUNNEL_OPENED') end)

  -- Rustboro (12..19,53) at VAR_RUSTBORO_CITY_STATE 7 and Petalburg (4,10..13) at
  -- VAR_SCOTT_PETALBURG_ENCOUNTER 0 fill their exits; if still armed, walk's fallback steps on them.
  beat('to_petalburg_gym', function()
    segBMoves()
    assert(N.travel('PetalburgCity_Gym'))
  end, function() return at('PetalburgCity_Gym') end)

  -- The doors are bg_event signs on collision tiles: talk from the south, YES to "go through?",
  -- and warpdoor lands in the next room. Each room's door stays locked until its trainer is
  -- beaten (goto_if_not_defeated). Accuracy (Mary) -> Defense (Alexia) -> Strength (Jody) -> Leader.
  beat('norman', function()
    segBMoves()
    for _, step in ipairs({ { nil, { 7, 105 } }, { 2, { 1, 92 } }, { 5, { 1, 53 } }, { 7, { 7, 14 } } }) do
      local trainer, door = step[1], step[2]
      if trainer then assert(N.talk(trainer, { side = 1 }), 'room trainer ' .. trainer); N.settle() end
      local _, y0 = F.pos()
      assert(N.talk(door, { side = 1 }), string.format('door (%d,%d)', door[1], door[2]))
      N.settle()
      local _, y1 = F.pos()
      assert(y1 < door[2] - 3, string.format('door (%d,%d) did not warp (y %d -> %d)', door[1], door[2], y0, y1))
    end
    assert(N.talk(1, { side = 1 }))   -- Norman (4,2) from (4,3)
    N.settle()   -- badge, TM Facade, Wally's dad, warp out, ON_FRAME walk to Wally's house, Surf
  end, function() return badge(5) and V('VAR_PETALBURG_GYM_STATE') >= 7 end)

  -- Normally already done by Norman's settle: PetalburgCity ON_FRAME (state 4) -> Wally's house
  -- ON_FRAME (state 4) -> giveitem ITEM_HM_SURF. The fallback re-enters the house.
  beat('surf', function()
    segBMoves()
    if not FL('FLAG_RECEIVED_HM_SURF') then
      assert(N.travel('PetalburgCity_WallysHouse'))
      N.settle()
    end
  end, function() return FL('FLAG_RECEIVED_HM_SURF') end)

  beat('to_route118', function()
    segBMoves()
    assert(N.travel('Route118'))   -- Route103 Surf -> Route110 -> Mauville, or back through Rusturf
  end, function() return at('Route118') end)

  -- Coord events (43..45,11), VAR_ROUTE118_STATE == 0, fill the only way north; Surf (16,12)->(31,12).
  beat('route118_steven', function()
    segBMoves()
    assert(N.go(44, 11))
    N.settle()
  end, function() return V('VAR_ROUTE118_STATE') >= 1 end)

  -- Shelly (4,6) only from (5,6). Her defeat sets VAR_WEATHER_INSTITUTE_STATE 1 and the scientist
  -- hands over Castform in the same script (nickname prompt -> NO, default policy).
  beat('weather_institute', function()
    segBMoves()
    assert(N.travel('Route119_WeatherInstitute_2F'))
    assert(N.talk(3, { side = 4 }))
    N.settle()
  end, function() return V('VAR_WEATHER_INSTITUTE_STATE') >= 1 end)

  beat('castform', function()
    segBMoves()
    if not FL('FLAG_RECEIVED_CASTFORM') then
      assert(N.travel('Route119_WeatherInstitute_2F'))
      assert(N.talk(5))   -- the scientist retries the gift until it fits
      N.settle()
    end
  end, function() return FL('FLAG_RECEIVED_CASTFORM') end)

  -- Coord events (25,31)/(26,31), VAR_ROUTE119_STATE == 0, are the only gap in row 31.
  beat('route119_rival', function()
    segBMoves()
    assert(N.travel('Route119'))
    assert(N.go(25, 31))
    N.settle()
  end, function() return V('VAR_ROUTE119_STATE') >= 1 and FL('FLAG_RECEIVED_HM_FLY') end)

  -- Steven (13,15) on the bridge, from the east (14,15). "Ready for battle?" -> YES; the Lv30
  -- Kecleon is a scripted wild battle (fight it; any end but a catch gives the scope).
  beat('devon_scope', function()
    segBMoves()
    assert(N.travel('Route120'))
    assert(N.talk(31, { side = 4 }))
    N.settle()
  end, function() return FL('FLAG_RECEIVED_DEVON_SCOPE') end)

  -- Invisible Kecleon 7 at (25,8) holds the ladder to the gym pocket. From (25,7): YES to the scope.
  beat('fortree_kecleon', function()
    segBMoves()
    assert(N.travel('FortreeCity'))
    assert(N.talk(7, { side = 2 }))
    N.settle()
  end, function() return FL('FLAG_KECLEON_FLED_FORTREE') end)

  -- Rotating gates (nav cannot plan them): a 101-step script simulated against src/rotating_gate.c.
  -- Flint + Edwardo spot at step 48 (9,10), Darius at step 59 (1,7); the others are avoided.
  beat('winona', function()
    segBMoves()
    assert(N.travel('FortreeCity_Gym'))
    N.settle()
    local x, y = F.pos()
    if x == 16 and y == 24 then N.push(3) end
    x, y = F.pos()
    assert(x == 15 and y == 24, string.format('gym start (%d,%d), want (15,24)', x, y))
    walkScript('N2 W11 N3 W2 S2 E1 N2 E1 N1 E3 N4 E2 N2 W2 S3 N1 E2 N4 W1 N1 W1 N1 W5 N1 W1 N1 E1 S2 E3 N6 W3 S6 E4 W1 N4 E9 N1 E1')
    assert(N.talk(1, { side = 1 }))   -- Winona (15,2) from (15,3)
    N.settle()
  end, function() return badge(6) end)

  return B
end
