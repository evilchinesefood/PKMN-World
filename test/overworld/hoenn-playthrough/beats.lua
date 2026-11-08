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

  -- Coord events (25,5..8), VAR_ROUTE121_STATE == 0: the grunts at (30..31,7..8) walk off. Until
  -- then their templates wall off the route east, so the planner cannot see Route 122 at all.
  beat('route121_aqua', function()
    segBMoves()
    assert(N.travel('Route121'))
    assert(N.go(25, 6))
    N.settle()
  end, function() return V('VAR_ROUTE121_STATE') >= 1 end)

  -- Mt. Pyre 1F west door -> exterior -> summit; row y=7 (x 22..24) at VAR_MT_PYRE_STATE 0 plays
  -- Archie taking the orb, and the old lady gives the Magma Emblem.
  beat('mt_pyre', function()
    segBMoves()
    assert(N.travel('MtPyre_Summit'))
    assert(N.go(23, 7))
    N.settle()
  end, function()
    return V('VAR_MT_PYRE_STATE') >= 1 and FL('FLAG_RECEIVED_RED_OR_BLUE_ORB') and N.itemCount(C.ITEM_MAGMA_EMBLEM) > 0
  end)

  -- Jagged Pass climbs only on an Acro Bike, so ride the cable car and walk down from Mt. Chimney.
  -- With the Emblem, ON_RESUME sets VAR_JAGGED_PASS_STATE 1; trigger (14,15) then opens the door.
  beat('jagged_pass_open', function()
    segBMoves()
    if not (at('MtChimney_CableCarStation') or at('MtChimney') or at('JaggedPass')) then
      assert(N.travel('Route112_CableCarStation'))
      assert(N.talk(1))
      N.settle()
      assert(at('MtChimney_CableCarStation'), 'cable car arrived')
    end
    assert(N.travel('JaggedPass'))
    assert(N.go(14, 15))
    N.settle()
  end, function() return V('VAR_JAGGED_PASS_STATE') >= 2 end)

  -- Push the boulder in direction d with Strength, activating it first when it is not (every map
  -- load clears FLAG_SYS_USE_STRENGTH). A wild battle mid-push or an A dropped while the screen
  -- fades back in from one gets another try.
  local function shove(d, what)
    for _ = 1, 4 do
      if not FL('FLAG_SYS_USE_STRENGTH') then
        N.face(d)
        -- A wild battle can start mid-turn; an A facing elsewhere would wake a neighbouring boulder.
        if N.facing() == d then N.press('A'); N.idle(20); N.settle() end
      end
      local x0, y0 = F.pos()
      if FL('FLAG_SYS_USE_STRENGTH') and N.push(d) then return end
      local x, y = F.pos()
      local objs = {}
      for _, o in ipairs(N.objects()) do objs[#objs + 1] = string.format('%d@(%d,%d)', o.localId, o.x, o.y) end
      L(string.format('  shove %s: at (%d,%d) from (%d,%d) facing %d strength=%s objects %s', what, x, y, x0, y0,
        N.facing(), tostring(FL('FLAG_SYS_USE_STRENGTH')), table.concat(objs, ' ')))
      if x ~= x0 or y ~= y0 then return end
      N.idle(60)
    end
    error('shove ' .. what)
  end

  -- 1F: boulders (5,22) (7,22) (6,23) seal the only way north, column x=5. From (7,23) push (6,23)
  -- west, then from (6,22) push (5,22) west. Every entry respawns them (FLAG_TEMP_11..13).
  -- Maxie (16,21) is reachable only from (15,21).
  beat('magma_hideout', function()
    segBMoves()
    if not N.mapName():find('^MagmaHideout_[234]F') then
      assert(N.travel('MagmaHideout_1F'))
      assert(N.go(7, 23))
      shove(3, '(6,23) west')
      assert(N.go(6, 22))
      shove(3, '(5,22) west')
    end
    assert(N.travel('MagmaHideout_4F'))
    assert(N.talk(6, { side = 3 }), 'Maxie')
    N.settle()
  end, function() return FL('FLAG_GROUDON_AWAKENED_MAGMA_HIDEOUT') end)

  -- Slateport ON_TRANSITION (city state 1) parks Stern (local 11) in front of the harbor door; his
  -- interview walks us in. Column x=8 (y 11..14) at VAR_SLATEPORT_HARBOR_STATE 1: Aqua takes the sub.
  beat('slateport_harbor', function()
    segBMoves()
    if N.mapName():find('^MagmaHideout') then
      -- The boulders are back on 1F, now pushed from the north: (5,22) south, then (7,22) east.
      assert(N.travel('MagmaHideout_1F'))
      assert(N.go(5, 21))
      shove(1, '(5,22) south')
      assert(N.go(6, 22))
      shove(4, '(7,22) east')
    end
    if V('VAR_SLATEPORT_CITY_STATE') < 2 then
      assert(N.travel('SlateportCity'))
      assert(N.talk(11), 'Captain Stern')
      N.settle()
    end
    if not at('SlateportCity_Harbor') then assert(N.travel('SlateportCity_Harbor')) end
    assert(N.go(8, 13))
    N.settle()
  end, function() return FL('FLAG_MET_TEAM_AQUA_HARBOR') end)

  -- Step onto a same-map warp pad (Aqua Hideout, Mossdeep Gym). walk aims at the pad tile and
  -- re-plans toward it after the jump, so stand beside it and step on once.
  local function pad(x, y, side)
    assert(N.approach(x, y, { side = side }), string.format('beside pad (%d,%d)', x, y))
    N.push(N.facing())
    for _ = 1, 40 do
      local px, py = F.pos()
      if math.abs(px - x) + math.abs(py - y) > 1 then break end
      N.idle(10)
    end
    N.settle()
    local px, py = F.pos()
    assert(math.abs(px - x) + math.abs(py - y) > 1, string.format('pad (%d,%d) did not fire', x, y))
  end

  -- Surf into the water door (70,5) east of Lilycove. Matt's corner of B2F is reached only through
  -- B1F: door (22,1); pads (27,4) (32,19); door (18,1); pad (31,8); doors (3,3) (12,1); pad (8,8).
  beat('aqua_hideout', function()
    segBMoves()
    if not (at('AquaHideout_B2F') and select(1, F.pos()) >= 20) then
      assert(N.travel('AquaHideout_1F'))
      assert(N.takeWarp(22, 1), '1F -> B1F')
      pad(27, 4)
      pad(32, 19)
      assert(N.takeWarp(18, 1), 'B1F -> B2F (18,1)')
      pad(31, 8)
      assert(N.takeWarp(3, 3), 'B2F -> B1F (3,3)')
      assert(N.takeWarp(12, 1), 'B1F -> B2F (12,1)')
      pad(8, 8)
    end
    assert(N.talk(1, { side = 4 }), 'Matt')
    N.settle()
  end, function() return FL('FLAG_TEAM_AQUA_ESCAPED_IN_SUBMARINE') end)

  -- Press a Mossdeep Gym floor switch n times: each press steps onto the coord event, a repeat
  -- steps off to (ox,oy) and back. Walks never cross another switch or pad (strictTriggers).
  local function press(sx, sy, ox, oy, n)
    for i = 1, n do
      local x, y = F.pos()
      if x == sx and y == sy then assert(N.go(ox, oy, { strictTriggers = true }), 'step off switch') end
      assert(N.go(sx, sy, { strictTriggers = true }), string.format('switch (%d,%d) press %d/%d', sx, sy, i, n))
      N.settle()
    end
  end

  -- Rotating statues: each colour switch turns every object on that colour's arrows one step
  -- (src/rotating_tile_puzzle.c MoveRotatingTileObjects). Rotations survive the gym's own pads and
  -- reset on re-entry, so the beat starts from the door. Ends at yellow 0, blue 0, green 2,
  -- purple 3, red 3, which opens the way to Tate and Liza (23,7).
  beat('tate_liza', function()
    segBMoves()
    -- Lilycove was remembered with its Wailmer wall (LilycoveCity_OnLoad paints it until the sub
    -- escapes), which would leave no sea route east.
    local ly = require('pwmaps').LilycoveCity
    N.mapMemory[ly.g * 256 + ly.m] = nil
    assert(N.travel('MossdeepCity_Gym'))
    pad(1, 33, 2)                 -- -> (20,24)
    press(23, 24, 22, 24, 1)      -- purple 1
    press(15, 34, 16, 34, 2)      -- green 2
    press(23, 24, 24, 24, 1)      -- purple 2
    press(23, 21, 23, 22, 1)      -- purple 3
    pad(23, 20, 1)                -- -> (9,18)
    pad(7, 18, 4)                 -- -> (8,12)
    press(8, 10, 8, 11, 3)        -- blue 3
    press(8, 6, 8, 5, 3)          -- red 3
    press(6, 7, 7, 7, 4)          -- blue 7
    press(8, 10, 8, 9, 1)         -- blue 8 = 0
    pad(11, 3, 1)                 -- -> (11,35)
    pad(13, 32, 1)                -- -> (21,10)
    assert(N.talk(1, { side = 1 }), 'Tate')
    N.settle()
  end, function() return badge(7) end)

  -- Out by the exit pad (21,6), a coord event that warps to (7,30). Mossdeep's diagonal at
  -- VAR_MOSSDEEP_CITY_STATE 1 (x 40..42, y 21..26) sends Maxie into the Space Center. 1F: the stair
  -- guard (local 9). 2F: three grunts ("take us on?" -> yes), then Steven (local 4) twice: the
  -- second talk opens the half-party picker and the multi battle beside him.
  beat('space_center', function()
    segBMoves()
    if at('MossdeepCity_Gym') and select(2, F.pos()) < 12 then pad(21, 6, 1) end
    if V('VAR_MOSSDEEP_CITY_STATE') < 2 then
      assert(N.travel('MossdeepCity'))
      assert(N.go(41, 23))
      N.settle()
    end
    assert(N.travel('MossdeepCity_SpaceCenter_1F'))
    if not FL('FLAG_DEFEATED_GRUNT_SPACE_CENTER_1F') then assert(N.talk(9), 'stair guard'); N.settle() end
    assert(N.travel('MossdeepCity_SpaceCenter_2F'))
    N.settle()
    for _ = 1, 3 do
      if FL('FLAG_DEFEATED_MAGMA_SPACE_CENTER') then break end
      assert(N.talk(4), 'Steven')
      N.settle()
    end
  end, function() return FL('FLAG_DEFEATED_MAGMA_SPACE_CENTER') end)

  -- VAR_STEVENS_HOUSE_STATE 1: entering the house runs Steven's ON_FRAME gift of HM Dive.
  beat('dive', function()
    segBMoves()
    assert(N.travel('MossdeepCity_StevensHouse'))
    N.settle()
  end, function() return FL('FLAG_RECEIVED_HM_DIVE') end)

  -- Dive (badge 7) and Waterfall (badge 8): travel plans dive and emerge hops itself (water.lua).
  require('water')(F, N, C)
  local function segDMoves()
    segBMoves()
    N.canWaterfall = badge(8)
  end

  -- Route 128 (38,27) -> Underwater_Route128 -> water door -> surface in the cavern (setdivewarp).
  beat('seafloor_entrance', function()
    segDMoves()
    assert(N.travel('SeafloorCavern_Entrance'))
  end, function() return at('SeafloorCavern_Entrance') end)

  -- Rock Smash (5,10) on the way, then (5,11) south (east seals row 11) and (12,11) east.
  beat('seafloor_room1', function()
    segDMoves()
    if not at('SeafloorCavern_Room1') then assert(N.travel('SeafloorCavern_Room1')) end
    assert(N.go(5, 10))
    shove(1, '(5,11) south')
    assert(N.go(11, 11))
    shove(4, '(12,11) east')
    assert(N.takeWarp(6, 2))
  end, function() return at('SeafloorCavern_Room2') end)

  -- Rock Smash (8,7) on the way west, then (4,5) north three times, clear of the door (6,1).
  beat('seafloor_room2', function()
    segDMoves()
    assert(N.go(4, 6))
    for i = 1, 3 do shove(2, '(4,5) north ' .. i) end
    assert(N.takeWarp(6, 1))
  end, function() return at('SeafloorCavern_Room6') end)

  -- Currents all the way across; the loop near (14,9) feeds the door (14,8) back to the Entrance.
  beat('seafloor_room6', function()
    segDMoves()
    assert(N.takeWarp(4, 1))
  end, function() return at('SeafloorCavern_Room3') end)

  -- Shelly (9,5) and a grunt (5,5) both see row 5 at x 6-7: a double battle on the way.
  beat('seafloor_room3', function()
    segDMoves()
    assert(N.takeWarp(8, 1))
  end, function() return at('SeafloorCavern_Room8') end)

  -- Twelve boulders around the exit: nine pushes, never one onto (5,3) below the door.
  beat('seafloor_room8', function()
    segDMoves()
    for i, p in ipairs({ { 5, 8, 2 }, { 5, 7, 4 }, { 6, 6, 3 }, { 5, 6, 2 }, { 5, 5, 3 }, { 4, 5, 2 },
                         { 5, 5, 4 }, { 6, 5, 2 }, { 6, 4, 3 } }) do
      assert(N.go(p[1], p[2]), 'room8 stand ' .. i)
      shove(p[3], 'room8 push ' .. i)
    end
    assert(N.takeWarp(5, 2))
  end, function() return at('SeafloorCavern_Room9') end)

  -- Coord event (17,42): Archie, Kyogre, Maxie, then a warp to Route 128 (38,22), where the
  -- ON_FRAME Steven scene sets VAR_ROUTE128_STATE 2.
  beat('kyogre_awakens', function()
    segDMoves()
    N.go(17, 42, { allowTriggers = true, allowWarp = true })
    N.settle()
    if not at('Route128') then N.idle(120); N.settle() end
  end, function()
    return FL('FLAG_KYOGRE_ESCAPED_SEAFLOOR_CAVERN') and V('VAR_SOOTOPOLIS_CITY_STATE') >= 1
      and V('VAR_ROUTE128_STATE') >= 2 and at('Route128')
  end)

  -- Sootopolis is entered only by Dive: Route 126 -> water door -> surface in the crater pool.
  -- Any arrival but a Fly to (43,32) plays the Dive branch of the legendaries scene (state 1 -> 2).
  beat('sootopolis_arrive', function()
    segDMoves()
    assert(N.travel('SootopolisCity'))
    N.settle()
  end, function() return at('SootopolisCity') and V('VAR_SOOTOPOLIS_CITY_STATE') >= 2 end)

  -- Steven (20,36): his walk to the cave is written only for a player facing north or west.
  beat('steven_sootopolis', function()
    segDMoves()
    assert(N.talk(7, { side = 1 }))
    N.settle()
  end, function() return FL('FLAG_STEVEN_GUIDES_TO_CAVE_OF_ORIGIN') end)

  -- MULTI_WHERES_RAYQUAZA loops until SKY PILLAR (index 2).
  beat('wallace_cave_of_origin', function()
    segDMoves()
    assert(N.travel('CaveOfOrigin_B1F'))
    assert(N.talk(1, { policy = pick(2) }))
    N.settle({ policy = pick(2) })
  end, function() return FL('FLAG_WALLACE_GOES_TO_SKY_PILLAR') and V('VAR_SOOTOPOLIS_CITY_STATE') >= 3 end)

  -- Route 131's ON_TRANSITION loads LAYOUT_ROUTE131_SKY_PILLAR, the only layout with the door
  -- (36,6): the planner cannot see Sky Pillar until we stand on the route.
  beat('to_route131', function()
    segDMoves()
    assert(N.travel('Route131'))
  end, function() return at('Route131') end)

  -- Outside's ON_FRAME (city state 3) is Wallace opening the pillar; it leaves us at (14,7).
  beat('sky_pillar_wallace', function()
    segDMoves()
    assert(N.travel('SkyPillar_Outside'))
    N.settle()
  end, function() return V('VAR_SOOTOPOLIS_CITY_STATE') >= 4 end)

  -- Step from where we stand onto the cracked tile in direction d and fall to the floor below,
  -- landing on the same x,y (CrackedFloorPerStepCallback, CaveHole_CheckFallDownHole).
  local function fall(d, map, x, y)
    local from = N.mapName()
    for _ = 1, 600 do
      if N.mapName() ~= from then break end
      if N.free() then joypad.set({ [N.KEY[d]] = true }) end
      emu.frameadvance()
    end
    N.idle(60); N.settle()
    local px, py = F.pos()
    assert(at(map) and px == x and py == y, string.format('fell to %s (%d,%d), want %s (%d,%d)', N.mapName(), px, py, map, x, y))
  end

  -- The floors load their _CLEAN layouts while VAR_SKY_PILLAR_STATE < 2. Clean 4F is split: from
  -- its east half, fall through the cracked (6,4) into a 3F pocket whose door (7,1) climbs to the
  -- west half and the 5F stairs. Every cracked tile is a fall below Mach Bike speed.
  beat('sky_pillar_climb', function()
    segDMoves()
    assert(N.travel('SkyPillar_1F'))
    assert(N.takeWarp(10, 1), '1F -> 2F')
    assert(N.takeWarp(3, 1), '2F -> 3F')
    assert(N.takeWarp(11, 1), '3F -> 4F east')
    assert(N.go(5, 4))
    fall(4, 'SkyPillar_3F', 6, 4)
    assert(N.takeWarp(7, 1), '3F pocket -> 4F west')
    assert(N.takeWarp(3, 1), '4F -> 5F')
    assert(N.takeWarp(10, 1), '5F -> Top')
  end, function() return at('SkyPillar_Top') end)

  -- Coord event (14,9): Rayquaza wakes and flies off, no battle.
  beat('rayquaza_awakens', function()
    segDMoves()
    N.go(14, 9, { allowTriggers = true })
    N.settle()
  end, function() return V('VAR_SKY_PILLAR_STATE') >= 1 and V('VAR_SOOTOPOLIS_CITY_STATE') >= 5 end)

  -- Down without Fly: 5F's door (3,1) reaches 4F's west half; fall through (1,3) to 3F west.
  beat('sky_pillar_descend', function()
    segDMoves()
    assert(N.takeWarp(16, 14), 'Top -> 5F')
    assert(N.takeWarp(3, 1), '5F -> 4F west')
    assert(N.go(1, 2))
    fall(1, 'SkyPillar_3F', 1, 3)
    assert(N.travel('Route131'))
  end, function() return at('Route131') end)

  -- ON_FRAME VAR_SKY_PILLAR_STATE == 1: Rayquaza ends the fight; ON_WARP then sets it to 3.
  beat('sootopolis_rayquaza', function()
    segDMoves()
    assert(N.travel('SootopolisCity'))
    N.settle()
  end, function() return at('SootopolisCity') and V('VAR_SKY_PILLAR_STATE') >= 2 end)

  -- State 5 parks Maxie (33,35) and Archie (34,35) by the Gym; the second talk runs
  -- MaxieArchieLeave, which unlocks the Gym door.
  beat('archie_and_maxie', function()
    segDMoves()
    if not FL('FLAG_MET_ARCHIE_SOOTOPOLIS') then assert(N.talk(17, { side = 1 }), 'Archie') end
    if not FL('FLAG_SOOTOPOLIS_ARCHIE_MAXIE_LEAVE') then assert(N.talk(16, { side = 1 }), 'Maxie') end
    N.settle()
  end, function() return FL('FLAG_SOOTOPOLIS_ARCHIE_MAXIE_LEAVE') end)

  -- Wallace (31,33) stands on the only tile below the Gym door; facing him from the south, he
  -- gives HM Waterfall and steps right.
  beat('wallace_waterfall', function()
    segDMoves()
    assert(N.talk(18, { side = 1 }), 'Wallace')
    N.settle()
  end, function() return FL('FLAG_RECEIVED_HM_WATERFALL') end)

  -- One step to the adjacent (x,y), finished before the next (thin ice cracks behind us).
  local function stepTo(x, y)
    local px, py = F.pos()
    assert(math.abs(px - x) + math.abs(py - y) == 1, string.format('stepTo (%d,%d) from (%d,%d)', x, y, px, py))
    N.push((y > py and 1) or (y < py and 2) or (x < px and 3) or 4)
    local nx, ny = F.pos()
    assert(at('SootopolisCity_Gym_1F') and nx == x and ny == y,
      string.format('stepTo (%d,%d) ended on %s (%d,%d)', x, y, N.mapName(), nx, ny))
  end

  -- Thin ice: every MB_THIN_ICE tile once (a second step falls to B1F). VAR_ICE_STEP_COUNT starts
  -- at 1 and the ON_FRAME stairs open at 8, 28 and 67, each adding one more.
  local ICE = {
    { 8, 24 }, { 8, 23 }, { 8, 22 }, { 8, 21 }, { 8, 20 },
    { 8, 19 }, { 7, 19 }, { 7, 18 }, { 8, 18 }, { 9, 18 }, { 9, 17 }, { 8, 17 },
    { 8, 16 }, { 8, 15 },
    { 8, 14 }, { 9, 14 }, { 10, 14 }, { 11, 14 }, { 11, 13 }, { 11, 12 }, { 10, 12 }, { 9, 12 }, { 9, 13 },
    { 8, 13 }, { 7, 13 }, { 7, 14 }, { 6, 14 }, { 5, 14 }, { 5, 13 }, { 5, 12 }, { 6, 12 }, { 7, 12 }, { 8, 12 },
    { 8, 11 }, { 8, 10 },
    { 8, 9 }, { 7, 9 }, { 6, 9 }, { 6, 8 }, { 5, 8 }, { 5, 9 }, { 4, 9 }, { 3, 9 }, { 3, 8 }, { 3, 7 }, { 3, 6 },
    { 4, 6 }, { 4, 7 }, { 5, 7 }, { 6, 7 }, { 6, 6 }, { 7, 6 }, { 7, 7 }, { 8, 7 }, { 8, 8 }, { 9, 8 }, { 9, 9 },
    { 10, 9 }, { 10, 8 }, { 10, 7 }, { 11, 7 }, { 11, 8 }, { 12, 8 }, { 12, 9 }, { 13, 9 }, { 13, 8 }, { 13, 7 },
    { 13, 6 }, { 12, 6 }, { 11, 6 }, { 10, 6 }, { 9, 6 }, { 8, 6 },
    { 8, 5 }, { 8, 4 }, { 8, 3 },
  }
  local STAIRS = { ['8,17'] = 9, ['8,12'] = 29, ['8,6'] = 68 }
  beat('juan', function()
    segDMoves()
    assert(N.travel('SootopolisCity_Gym_1F'))
    local x, y = F.pos()
    assert(x == 8 and y == 25, string.format('gym entry (%d,%d)', x, y))
    for _, t in ipairs(ICE) do
      stepTo(t[1], t[2])
      local want = STAIRS[t[1] .. ',' .. t[2]]
      if want then
        for _ = 1, 300 do if V('VAR_ICE_STEP_COUNT') >= want and N.free() then break end; N.idle(1) end
        N.settle()
        assert(V('VAR_ICE_STEP_COUNT') >= want, string.format('stairs at (%d,%d): count %d', t[1], t[2], V('VAR_ICE_STEP_COUNT')))
      end
    end
    N.face(2); N.press('A'); N.idle(20)   -- Juan (8,2), no prompt
    N.settle()
  end, function() return badge(8) and V('VAR_SOOTOPOLIS_CITY_STATE') >= 6 end)

  -- The way back crosses only cracked ice: the fall to B1F and its ladder are on the route.
  -- Then Dive out of the crater, east by sea, and up Ever Grande's waterfall.
  beat('to_victory_road', function()
    segDMoves()
    assert(N.travel('VictoryRoad_1F'))
  end, function() return at('VictoryRoad_1F') end)

  local function smash(d)
    for _ = 1, 4 do
      N.face(d)
      if N.facing() == d then N.press('A'); N.idle(20); N.settle(); return end
      N.settle()
    end
    error('smash: cannot face ' .. d)
  end

  -- Johto's Victory Road layout and B1F puzzle. Wally's coord events (2,23)/(3,23) fill the only
  -- corridor to the (9,14) ladder, so the walk there runs his battle.
  beat('victory_road', function()
    segDMoves()
    if not FL('FLAG_DEFEATED_WALLY_VICTORY_ROAD') then
      assert(N.takeWarp(9, 14), '1F -> B1F (8,3)')
      assert(FL('FLAG_DEFEATED_WALLY_VICTORY_ROAD'), 'Wally on the way')
      assert(N.go(5, 7)); shove(3, '(4,7) west')
      assert(N.go(8, 10)); shove(4, '(9,10) east')
      assert(N.go(17, 12)); smash(4)
      assert(N.takeWarp(30, 25), 'B1F -> B2F')
      assert(N.takeWarp(19, 12), 'B2F -> B1F lower')
      assert(N.go(19, 25)); smash(4)
      assert(N.go(20, 25)); shove(1, '(20,26) south')
      smash(4)
      assert(N.takeWarp(20, 21), 'B1F -> 1F (21,32)')
    end
    assert(N.travel('EverGrandeCity_PokemonLeague_1F'))
  end, function() return FL('FLAG_DEFEATED_WALLY_VICTORY_ROAD') and at('EverGrandeCity_PokemonLeague_1F') end)

  -- ON_TRANSITION parks the guards on (9,2)/(10,2) until FLAG_ENTERED_ELITE_FOUR; either one
  -- checks the badges and steps aside.
  beat('league_gate', function()
    segDMoves()
    assert(N.talkFrom(9, 3, 2))
    N.settle()
    assert(N.travel('EverGrandeCity_Hall5'))
  end, function() return FL('FLAG_ENTERED_ELITE_FOUR') and at('EverGrandeCity_Hall5') end)

  -- Each room's ON_FRAME walks us in and seals the door; VAR_ELITE_4_STATE counts entries, so
  -- progress is the defeat flag. The member (6,5) opens the exit (6,2) when beaten.
  for _, e in ipairs({ { 'SidneysRoom', 'SIDNEY' }, { 'PhoebesRoom', 'PHOEBE' }, { 'GlaciasRoom', 'GLACIA' },
                       { 'DrakesRoom', 'DRAKE' } }) do
    local room, flag = 'EverGrandeCity_' .. e[1], 'FLAG_DEFEATED_ELITE_4_' .. e[2]
    beat('e4_' .. e[1], function()
      segDMoves()
      if not at(room) then assert(N.travel(room)) end
      N.settle()
      if not FL(flag) then assert(N.talk(1, { side = 1 }), e[2]) end
      assert(FL(flag), e[2] .. ' beaten')
      assert(N.takeWarp(6, 2), 'out of ' .. room)
    end, function() return FL(flag) and not at(room) end)
  end

  -- Hall4 (5,2) -> Champion's room: its ON_FRAME walks us to Wallace and starts the battle. Then
  -- the rival and Birch, the Hall of Fame (FLAG_HOENN_CHAMPION), its save, and a soft reset in
  -- place of the credits. The title screen's CONTINUE lands in the bedroom.
  beat('champion', function()
    segDMoves()
    assert(N.travel('EverGrandeCity_Hall4'))
    N.takeWarp(5, 2, { limit = 60 * 60 * 20 })
    for _ = 1, 60 * 60 * 20 // 12 do
      if FL('FLAG_HOENN_CHAMPION') and F.ow() and N.free() and N.mapName():find('^LittlerootTown_') then break end
      if F.ow() and N.free() and at('EverGrandeCity_Hall4') then N.takeWarp(5, 2) end
      if N.inBattle() then N.settle() else F.press('A', 2); F.idle(10) end
    end
    N.settle()
    L('  after the Hall of Fame: ' .. N.mapName() .. ' champion=' .. tostring(FL('FLAG_HOENN_CHAMPION'))
      .. ' game clear=' .. tostring(FL('FLAG_SYS_GAME_CLEAR')))
  end, function() return FL('FLAG_HOENN_CHAMPION') and F.ow() and at('LittlerootTown_BrendansHouse_2F') end)

  -- Back under control after the reset: walk downstairs (the 1F ON_FRAME gives the S.S. Ticket).
  beat('home', function()
    segDMoves()
    local x0, y0 = F.pos()
    assert(N.travel('LittlerootTown_BrendansHouse_1F'))
    N.settle()
    local x, y = F.pos()
    L(string.format('  moved from 2F (%d,%d) to 1F (%d,%d)', x0, y0, x, y))
  end, function() return FL('FLAG_HOENN_CHAMPION') and at('LittlerootTown_BrendansHouse_1F') and N.free() end)

  return B
end
