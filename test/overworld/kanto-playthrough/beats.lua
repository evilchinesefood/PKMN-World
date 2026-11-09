-- Ordered Kanto story beats. Each beat: { name, run = function, done = predicate }.
-- Predicates follow docs/story-progress/kanto.md; coordinates come from data/maps/*_Frlg/map.json.
return function(F, N, C, log)
  local L = F.L
  local B = {}
  local function beat(name, run, done) B[#B + 1] = { name = name, run = run, done = done } end
  local function V(name) return N.var(C[name]) end
  local function FL(name) return N.flag(C[name]) end
  local function at(map) return N.mapName() == map end
  local function badge(n) return FL('FLAG_KANTO_BADGE_' .. n) end
  N.region = { lo = 34, hi = 74 }   -- Kanto's map groups (data/maps/map_groups.json)

  local P = require('pwsym')
  local GIRL = os.getenv('PW_GENDER') == 'F'
  -- PLAYER_STARTER_NUM in Oak's lab: 0 Bulbasaur, 1 Squirtle, 2 Charmander. Each is its own ball.
  local STARTER = tonumber(os.getenv('PW_STARTER') or '0')
  local BALLS = { [0] = 5, [1] = 6, [2] = 7 }
  local STARTER_SPECIES = { [0] = C.SPECIES_BULBASAUR, [1] = C.SPECIES_SQUIRTLE, [2] = C.SPECIES_CHARMANDER }
  local LAB = 'VAR_MAP_SCENE_PALLET_TOWN_PROFESSOR_OAKS_LAB'

  -- Species from the encrypted growth substruct (first halfword), to confirm a gift really arrived.
  local SUBSTRUCT_ORDER = { 'GAEM', 'GAME', 'GEAM', 'GEMA', 'GMAE', 'GMEA', 'AGEM', 'AGME', 'AEGM', 'AEMG', 'AMGE', 'AMEG',
    'EGAM', 'EGMA', 'EAGM', 'EAMG', 'EMGA', 'EMAG', 'MGAE', 'MGEA', 'MAGE', 'MAEG', 'MEGA', 'MEAG' }
  local O = require('pwoff')
  local function species(slot)
    local b = P.gParties + slot * O.mon_size
    local pid, otid = F.r32(b), F.r32(b + 4)
    local addr = b + 32 + 12 * (SUBSTRUCT_ORDER[(pid % 24) + 1]:find('G') - 1)
    return (F.r32(addr) ~ pid ~ otid) & 0x7FF
  end

  -- Bill's Sevii invitation after Blaine is optional; declining keeps the run on the mainland.
  -- PW_SEVII=1 accepts it and plays the islands (the two 'PW_SEVII' blocks below).
  local SEVII = os.getenv('PW_SEVII') ~= nil
  local seviiFerry
  if not SEVII then
    local kantoPolicy = N.defaultPolicy
    N.defaultPolicy = function(t, k)
      if k == 'yesno' and t:lower():find('spending time with me') then return 'no' end
      return kantoPolicy(t, k)
    end
  end

  local DETOUR = os.getenv('PW_DETOUR')
  local function moves()
    N.run = true
    N.clearItems = true
    N.solidBoulders = true
    N.resetAvoid = true
    -- The gates' guards refuse the player until Tea is delivered, but the planner can't see that.
    -- Route 17 is the Cycling Road: its gates turn away a player with no Bicycle.
    N.noEnter = { Route17_Frlg = true, SaffronCity_Frlg = V('VAR_MAP_SCENE_ROUTE5_ROUTE6_ROUTE7_ROUTE8_GATES') == 0 or nil }
    N.canCut = badge(2)
    N.canSurf = badge(5)
    N.canSmash = badge(6)
    if SEVII then N.canWaterfall = badge(7); N.passWild = badge(7) end
  end

  beat('to_kanto', function()
    if GIRL then F.w8(F.r32(P.gSaveBlock2Ptr) + 8, 1) end
    assert(N.approach(11, 2, { side = 1 }), 'hub Kanto attendant')
    for _ = 1, 500 do
      N.press('A'); N.idle(20)
      if F.grp() == 38 then break end
    end
    N.idle(200); N.settle()
  end, function() return at('PalletTown_PlayersHouse_2F_Frlg') end)

  -- Oak's route trigger (12,1) walks us to the lab; the lab's ON_FRAME scene ends on scene 2.
  beat('oak_lab', function()
    moves()
    assert(N.travel('PalletTown_Frlg'))
    assert(N.go(12, 1))
    N.settle()
  end, function() return V(LAB) == 2 and at('PalletTown_ProfessorOaksLab_Frlg') end)

  -- PW_DETOUR=starter: leave Oak's lab by Hub Pass with the three balls still on the table.
  -- Without a Pokemon the Viridian Mart parcel scene must not be reachable.
  if DETOUR == 'starter' then
    beat('detour_starter', function()
      N.useHubPass()
      N.crossGate(11)
      L('  gate landed at ' .. N.mapName() .. ' lab=' .. V(LAB))
      if not at('PalletTown_ProfessorOaksLab_Frlg') then
        assert(N.travel('ViridianCity_Mart_Frlg'))
        N.settle()
      end
      L('  after: ' .. N.mapName() .. ' lab=' .. V(LAB) .. ' mart=' .. V('VAR_MAP_SCENE_VIRIDIAN_CITY_MART') .. ' party=' .. N.partyCount())
    end, function() return at('PalletTown_ProfessorOaksLab_Frlg') and V(LAB) == 2 end)
  end

  beat('starter', function()
    moves()
    assert(N.talk(BALLS[STARTER], { side = 1 }))
    N.settle()
  end, function() return V(LAB) == 3 and V('VAR_STARTER_MON') == STARTER and species(0) == STARTER_SPECIES[STARTER] end)

  -- Parties are per region, so this happens in Kanto, after the starter is chosen normally.
  -- Lv100 Mewtwo and Rayquaza from the debug Give menu, met level lowered to 5 for obedience.
  -- PW_DETOUR=empty: bank the party by crossing to Johto, come home without withdrawing it, and
  -- walk into the rival's lab fight. The starter stays boxed, so run this with --to detour_empty.
  if DETOUR == 'empty' then
    beat('detour_empty', function()
      N.useHubPass()
      N.crossGate(16)
      L('  crossed to ' .. N.mapName() .. ' party=' .. N.partyCount())
      N.useHubPass()
      N.crossGate(11)
      L('  home at ' .. N.mapName() .. ' party=' .. N.partyCount() .. ' lab=' .. V(LAB))
      assert(N.partyCount() == 0, 'the party should still be boxed')
      assert(N.travel('PalletTown_ProfessorOaksLab_Frlg'))
      N.go(6, 8, { allowTriggers = true })
      N.settle()
      L('  after the trigger: ' .. N.mapName() .. ' party=' .. N.partyCount() .. ' lab=' .. V(LAB))
    end, function()
      return F.ow() and N.free() and at('PalletTown_ProfessorOaksLab_Frlg') and V(LAB) == 3
        and N.partyCount() == 0 and V('VAR_TEMP_2') ~= 0   -- the rival trigger ran and was refused
    end)
  end

  beat('party', function()
    assert(N.giveMon({ species = C.SPECIES_MEWTWO, level = 100, evs = { 4, 0, 0, 252, 252, 0 },
      moves = { C.MOVE_PSYSTRIKE, C.MOVE_AURA_SPHERE, C.MOVE_ICE_BEAM, C.MOVE_FLAMETHROWER } }))
    assert(N.giveMon({ species = C.SPECIES_RAYQUAZA, level = 100, evs = { 4, 252, 0, 252, 0, 0 },
      moves = { C.MOVE_EARTHQUAKE, C.MOVE_DRAGON_CLAW, C.MOVE_EXTREME_SPEED, C.MOVE_THUNDERBOLT } }))
    N.setMetLevel(1, 5)
    N.setMetLevel(2, 5)
    N.swapParty(0, 1)   -- Mewtwo leads; the starter stays in the party
  end, function() return N.partyCount() == 3 and N.partyMon(0).level == 100 end)

  beat('rival_lab', function()
    moves()
    assert(N.go(6, 8))
    N.settle()
  end, function() return V(LAB) == 4 end)

  -- Mart ON_FRAME (lab scene 4): the clerk hands over the parcel on entry.
  beat('parcel', function()
    moves()
    assert(N.travel('ViridianCity_Mart_Frlg'))
    N.settle()
  end, function() return V(LAB) == 5 and N.itemCount(C.ITEM_OAKS_PARCEL) > 0 end)

  beat('deliver_parcel', function()
    moves()
    assert(N.travel('PalletTown_ProfessorOaksLab_Frlg'))
    N.settle()
    assert(N.talk(4, { side = 1 }))
    N.settle()
  end, function() return V(LAB) == 6 and FL('FLAG_SYS_POKEDEX_GET') end)


  -- PW_ROUTE22=0|1|2 steps on that row of Route 22's rival trigger: north, middle or south, each
  -- with its own approach. Early here, and late once Giovanni arms the trigger again.
  local ROW22 = tonumber(os.getenv('PW_ROUTE22') or '')
  local function route22(want)
    moves()
    assert(N.travel('Route22_Frlg'))
    N.settle()
    L(string.format('  scene %d, walking onto (33,%d)', V('VAR_MAP_SCENE_ROUTE22'), 4 + ROW22))
    N.go(33, 4 + ROW22, { allowTriggers = true })
    N.settle()
    local x, y = F.pos()
    L(string.format('  after the rival: scene %d at (%d,%d), rival object %s', V('VAR_MAP_SCENE_ROUTE22'), x, y, tostring(N.object(1) ~= nil)))
    assert(N.free(), 'control after the rival')
  end
  -- The rival warns that the guard wants a badge: with none, the north gate must turn the player back.
  local refused
  if ROW22 then
    beat('detour_route22', function()
      route22()
      if not at('Route22_Frlg') or V('VAR_MAP_SCENE_ROUTE22') ~= 2 then return end
      assert(N.travel('Route22_NorthEntrance_Frlg'))
      local seen = #N.transcript
      N.go(7, 2, { allowTriggers = true })
      N.settle()
      local x, y = F.pos()
      local warned = false
      for i = seen + 1, #N.transcript do warned = warned or N.transcript[i]:find('BADGE', 1, true) ~= nil end
      L(string.format('  at the guard with no badge: %s (%d,%d) warned=%s', N.mapName(), x, y, tostring(warned)))
      refused = at('Route22_NorthEntrance_Frlg') and y > 2 and N.free() and warned
    end, function() return V('VAR_MAP_SCENE_ROUTE22') == 2 and refused end)
  end

  -- PW_DETOUR=grass: bank the party by crossing to Johto, come home without withdrawing it, and
  -- walk Route 1's grass with nobody to send out. Stop this one with --to detour_grass.
  local touched
  if DETOUR == 'grass' then
    beat('detour_grass', function()
      moves()
      N.useHubPass(); N.crossGate(16)
      N.useHubPass(); N.crossGate(11)
      L('  home at ' .. N.mapName() .. ' party=' .. N.partyCount())
      assert(N.partyCount() == 0, 'the party should still be boxed')
      assert(N.travel('Route1_Frlg'))
      local g, tiles = N.liveGrid(), {}
      for y = 0, g.h - 1 do
        for x = 0, g.w - 1 do
          local v = g.get(x, y)
          if v and (v & 0x0C00) == 0 and g.beh(v & 0x3FF) == C.MB_TALL_GRASS then tiles[#tiles + 1] = { x, y } end
        end
      end
      table.sort(tiles, function(a, b) return a[2] < b[2] end)
      local a, b, wild0 = tiles[1], tiles[#tiles], N.battles.wild
      for i = 1, 60 do
        local t = (i % 2 == 0) and a or b
        N.go(t[1], t[2])
        N.settle()
        -- Touching a visible wild Pokemon with nobody to send out used to lock the game for good.
        for _, o in ipairs(N.objects()) do
          if not touched and o.localId >= 249 and o.localId <= 252 and N.talk(o.localId) then
            N.settle()
            touched = N.free()
            L(string.format('  touched wild object %d with an empty party: free=%s', o.localId, tostring(touched)))
          end
        end
      end
      L(string.format('  60 grass walks with an empty party: wild battles %d, at %s, party=%d', N.battles.wild - wild0, N.mapName(), N.partyCount()))
    end, function() return F.ow() and N.free() and at('Route1_Frlg') and N.partyCount() == 0 and touched end)
  end

  -- Squirtle can't learn Cut, and neither can Mewtwo or Rayquaza: catch a Rattata in Route 1's
  -- grass with Oak's Poke Balls. Bulbasaur and Charmander carry it themselves.
  if STARTER == 1 then
    beat('catch_cut_user', function()
      moves()
      assert(N.travel('Route1_Frlg'))
      local g = N.liveGrid()
      local tiles = {}
      for y = 0, g.h - 1 do
        for x = 0, g.w - 1 do
          local v = g.get(x, y)
          if v and (v & 0x0C00) == 0 and g.beh(v & 0x3FF) == C.MB_TALL_GRASS then tiles[#tiles + 1] = { x, y } end
        end
      end
      assert(#tiles >= 2, 'no grass on Route 1')
      table.sort(tiles, function(a, b) return a[2] < b[2] end)
      local a, b = tiles[1], tiles[#tiles]
      N.catchWanted = function(sp) return sp == C.SPECIES_RATTATA end
      local n0 = N.partyCount()
      for i = 1, 80 do
        if N.partyCount() > n0 then break end
        local t = (i % 2 == 0) and a or b
        N.go(t[1], t[2])
        N.settle()
      end
      N.catchWanted = nil
      L('  party after grass: ' .. N.partyCount())
    end, function() return N.partyCount() == 4 end)
  end

  -- Viridian's old man is only in the way until the parcel is delivered (lab scene 6 clears him).
  beat('to_pewter', function()
    moves()
    assert(N.travel('PewterCity_Frlg'))
    N.settle()
  end, function() return at('PewterCity_Frlg') end)

  beat('brock', function()
    moves()
    assert(N.travel('PewterCity_Gym_Frlg'))
    assert(N.talk(1, { side = 1 }))
    N.settle()
  end, function() return badge(1) end)

  ------------------------------------------------------------------ Mt. Moon to Cerulean
  -- PW_DETOUR=ship: with only the Boulder Badge and no ticket, the Vermilion gate must not put the
  -- player past the S.S. Anne ticket check.
  if DETOUR == 'ship' then
    beat('detour_ship', function()
      N.useHubPass()
      N.crossGate(11)
      local x, y = F.pos()
      L(string.format('  gate landed at %s (%d,%d)', N.mapName(), x, y))
      assert(y < 33, 'landed at or past the ticket check')
      N.push(1)
      N.idle(120); N.settle()
      L('  after Down: ' .. N.mapName())
    end, function() return at('VermilionCity_Frlg') end)
  end

  beat('mt_moon_fossil', function()
    moves()
    assert(N.travel('MtMoon_B2F_Frlg', { tile = { 13, 7 } }))
    assert(N.talk(1, { side = 1 }), 'Dome Fossil')   -- Miguel's trigger (14,11) is on the way
    N.settle()
  end, function() return FL('FLAG_GOT_FOSSIL_FROM_MT_MOON') end)

  beat('to_cerulean', function()
    moves()
    assert(N.travel('CeruleanCity_Frlg'))
    N.settle()
  end, function() return at('CeruleanCity_Frlg') end)

  beat('bill', function()
    moves()
    assert(N.travel('Route25_SeaCottage_Frlg'))
    assert(N.talk(2), 'Clefairy Bill')
    N.settle()
    assert(N.talk({ 4, 5 }, { side = 1 }), 'cell separator')
    N.settle()
  end, function() return FL('FLAG_HELPED_BILL_IN_SEA_COTTAGE') end)

  beat('ticket', function()
    moves()
    assert(N.talk(1), 'Bill')
    N.settle()
  end, function() return FL('FLAG_GOT_SS_TICKET') end)

  beat('misty', function()
    moves()
    assert(N.travel('CeruleanCity_Gym_Frlg'))
    assert(N.talk(3, { side = 1 }), 'Misty')
    N.settle()
  end, function() return badge(2) end)

  ------------------------------------------------------------------ Vermilion
  beat('cut', function()
    moves()
    assert(N.travel('SSAnne_CaptainsOffice_Frlg'))
    assert(N.talk(1, { side = 1 }), 'Captain')
    N.settle()
  end, function() return FL('FLAG_GOT_HM01') end)

  -- Leaving the ship plays the departure; walking off the pier advances Vermilion to scene 3.
  beat('ship_sails', function()
    moves()
    assert(N.travel('VermilionCity_Frlg'))
    N.settle()
    assert(N.go(23, 30))
    N.settle()
  end, function() return V('VAR_MAP_SCENE_VERMILION_CITY') == 3 end)

  -- Two adjacent trash cans hide the switches; VAR_TEMP_0/1 hold their ids (SetVermilionTrashCans).
  local CANS = { { 1, 10 }, { 3, 10 }, { 5, 10 }, { 7, 10 }, { 9, 10 }, { 1, 12 }, { 3, 12 }, { 5, 12 }, { 7, 12 }, { 9, 12 },
                 { 1, 14 }, { 3, 14 }, { 5, 14 }, { 7, 14 }, { 9, 14 } }
  beat('surge', function()
    moves()
    assert(N.travel('VermilionCity_Gym_Frlg'))
    if not FL('FLAG_FOUND_BOTH_VERMILION_GYM_SWITCHES') then
      local a, b = V('VAR_TEMP_0'), V('VAR_TEMP_1')
      L(string.format('  trash can switches: %d then %d', a, b))
      assert(N.talk(CANS[a]), 'first can')     -- any side: Baily stands south of a row-10 can
      assert(N.talk(CANS[b]), 'second can')
      N.settle()
      assert(FL('FLAG_FOUND_BOTH_VERMILION_GYM_SWITCHES'), 'switches found')
    end
    assert(N.talk(1, { side = 1 }), 'Lt. Surge')
    N.settle()
  end, function() return badge(3) end)

  ------------------------------------------------------------------ Rocket Hideout
  local function pick(idx)
    return function(t, k) if k == 'multi' then return idx end return N.defaultPolicy(t, k) end
  end

  -- Cut Route 9's tree, then Rock Tunnel, Route 8 and the Underground Path to Celadon.
  beat('to_celadon', function()
    moves()
    assert(N.travel('CeladonCity_Frlg'))
    N.settle()
  end, function() return at('CeladonCity_Frlg') end)

  beat('game_corner', function()
    moves()
    assert(N.travel('CeladonCity_GameCorner_Frlg'))
    assert(N.talk(11), 'Rocket at the poster')
    N.settle()
    assert(N.talk({ 11, 1 }, { side = 1 }), 'poster')
    N.settle()
  end, function() return FL('FLAG_OPENED_ROCKET_HIDEOUT') end)

  -- Past the spin floors on B2F and B3F. Grunt 3 at (4,2) drops the Lift Key on B4F.
  beat('lift_key', function()
    moves()
    assert(N.travel('RocketHideout_B4F_Frlg', { tile = { 4, 2 } }))
    assert(N.talk(3), 'key grunt')
    N.settle()
    assert(N.talk(4), 'Lift Key')
    N.settle()
  end, function() return FL('FLAG_CAN_USE_ROCKET_HIDEOUT_LIFT') end)

  -- B1F's lift room is sealed by a barrier from its north side, so use B2F's; then B4F's door grunts and Giovanni.
  beat('hideout_boss', function()
    moves()
    if not at('RocketHideout_Elevator_Frlg') then
      assert(N.travel('RocketHideout_B2F_Frlg', { tile = { 28, 16 } }))
      assert(N.takeWarp(28, 16), 'into the lift')
    end
    assert(at('RocketHideout_Elevator_Frlg'), 'in the lift')
    assert(N.talk({ 0, 2 }, { side = 1, policy = pick(2) }), 'floor panel')
    N.settle()
    assert(N.takeWarp(2, 5), 'out of the lift')
    assert(at('RocketHideout_B4F_Frlg'), 'lift reached B4F')
    assert(N.talk(6), 'door grunt 1')
    N.settle()
    assert(N.talk(5), 'door grunt 2')
    N.settle()
    assert(N.talk(1, { side = 1 }), 'Giovanni')
    N.settle()
  end, function() return FL('FLAG_HIDE_CELADON_ROCKETS') end)

  beat('scope', function()
    moves()
    assert(N.talk(2), 'Silph Scope')
    N.settle()
  end, function() return FL('FLAG_HIDE_SILPH_SCOPE') and N.itemCount(C.ITEM_SILPH_SCOPE) > 0 end)

  -- The way out is the lift to B1F; Grunt 5 there holds the barrier to the Game Corner stairs.
  beat('leave_hideout', function()
    moves()
    assert(N.takeWarp(20, 23), 'into the lift')
    assert(at('RocketHideout_Elevator_Frlg'), 'in the lift')
    assert(N.talk({ 0, 2 }, { side = 1, policy = pick(0) }), 'floor panel')
    N.settle()
    assert(N.takeWarp(2, 5), 'out of the lift')
    assert(at('RocketHideout_B1F_Frlg'), 'lift reached B1F')
    if N.object(5) then assert(N.talk(5), 'Grunt at the barrier'); N.settle() end
    assert(N.travel('CeladonCity_GameCorner_Frlg'))
  end, function() return at('CeladonCity_GameCorner_Frlg') end)

  ------------------------------------------------------------------ Pokemon Tower and Erika
  -- Coord events (11,15)/(12,16) beside the stairs: Marowak's ghost, then Fuji's stairs.
  beat('tower', function()
    moves()
    assert(N.travel('PokemonTower_6F_Frlg', { tile = { 11, 16 } }))
    assert(N.go(11, 15))
    N.settle()
  end, function() return V('VAR_MAP_SCENE_POKEMON_TOWER_6F') >= 1 end)

  beat('fuji', function()
    moves()
    assert(N.travel('PokemonTower_7F_Frlg'))
    assert(N.talk(1, { side = 1 }), 'Mr. Fuji')
    N.settle()
  end, function() return FL('FLAG_RESCUED_MR_FUJI') end)

  beat('flute', function()
    moves()
    assert(N.travel('LavenderTown_VolunteerPokemonHouse_Frlg'))
    assert(N.talk(1, { side = 1 }), 'Mr. Fuji at home')
    N.settle()
  end, function() return FL('FLAG_GOT_POKE_FLUTE') and N.itemCount(C.ITEM_POKE_FLUTE) > 0 end)

  beat('erika', function()
    moves()
    assert(N.travel('CeladonCity_Gym_Frlg'))
    assert(N.talk(7, { side = 1 }), 'Erika')
    N.settle()
  end, function() return badge(4) end)

  ------------------------------------------------------------------ Fuchsia and the Safari Zone
  beat('snorlax', function()
    moves()
    assert(N.travel('Route12_Frlg', { tile = { 14, 69 } }))
    assert(N.talk(5, { side = 2 }), 'Snorlax')
    N.settle()
  end, function() return FL('FLAG_WOKE_UP_ROUTE_12_SNORLAX') end)

  beat('to_fuchsia', function()
    moves()
    assert(N.travel('FuchsiaCity_Frlg'))
    N.settle()
  end, function() return at('FuchsiaCity_Frlg') end)

  -- The entry trigger asks for 500 before walking us in; Safari wild battles are run from.
  beat('surf', function()
    moves()
    assert(N.travel('SafariZone_SecretHouse_Frlg'))
    N.settle()
    assert(N.talk(1, { side = 1 }), 'Secret House attendant')
    N.settle()
  end, function() return FL('FLAG_GOT_HM03') end)

  beat('teeth', function()
    moves()
    assert(N.travel('SafariZone_West_Frlg', { tile = { 28, 14 } }))
    assert(N.talk(1), 'Gold Teeth')
    N.settle()
  end, function() return FL('FLAG_HIDE_SAFARI_ZONE_WEST_GOLD_TEETH') and N.itemCount(C.ITEM_GOLD_TEETH) > 0 end)

  beat('koga', function()
    moves()
    assert(N.travel('FuchsiaCity_Gym_Frlg'))
    assert(N.talk(7, { side = 1 }), 'Koga')
    N.settle()
  end, function() return badge(5) end)

  beat('strength', function()
    moves()
    assert(N.travel('FuchsiaCity_WardensHouse_Frlg'))
    assert(N.talk(1), 'Warden')
    N.settle()
  end, function() return FL('FLAG_GOT_HM04') end)

  ------------------------------------------------------------------ Saffron and Silph Co.
  beat('tea', function()
    moves()
    assert(N.travel('CeladonCity_Condominiums_1F_Frlg'))
    assert(N.talk(4), 'old woman')
    N.settle()
  end, function() return FL('FLAG_GOT_TEA') end)

  -- Any gate guard takes the Tea and lets the player through (a shared scene for all four gates).
  beat('saffron_gate', function()
    moves()
    assert(N.travel('Route7_EastEntrance_Frlg'))
    assert(N.go(6, 5))
    N.settle()
  end, function() return V('VAR_MAP_SCENE_ROUTE5_ROUTE6_ROUTE7_ROUTE8_GATES') >= 1 end)

  beat('card_key', function()
    moves()
    -- The Card Key's corridor on 5F is entered only by arriving on its pad, from 9F's pad room.
    assert(N.travel('SilphCo_9F_Frlg', { tile = { 22, 18 } }))
    if select(1, F.pos()) == 22 then assert(N.go(21, 18)) end   -- the route here arrives standing on the pad
    assert(N.takeWarp(22, 18), '9F pad to 5F')
    assert(at('SilphCo_5F_Frlg'), 'pad reached 5F')
    assert(N.talk(8), 'Card Key')
    N.settle()
  end, function() return FL('FLAG_HIDE_SILPH_CO_5F_CARD_KEY') end)

  -- 3F's Door 2 opens from the east; the pad behind it reaches 7F, whose pad reaches 11F.
  beat('silph', function()
    moves()
    if not at('SilphCo_11F_Frlg') then
      assert(N.travel('SilphCo_3F_Frlg', { tile = { 22, 12 } }))
      assert(N.talk({ 21, 12 }, { side = 4 }), '3F Door 2')
      N.settle()
      N.rememberMap()   -- the route back out from 11F depends on this door being open
      assert(N.takeWarp(13, 14), '3F pad to 7F')
      assert(at('SilphCo_7F_Frlg'), 'pad reached 7F')
      assert(N.takeWarp(5, 8), '7F pad to 11F')
    end
    assert(at('SilphCo_11F_Frlg'), 'pad reached 11F')
    assert(N.talk({ 5, 17 }, { side = 1 }), '11F door')
    N.settle()
    assert(N.go(5, 15))
    N.settle()
  end, function() return V('VAR_MAP_SCENE_SILPH_CO_11F') >= 1 and FL('FLAG_HIDE_SAFFRON_ROCKETS') end)

  ------------------------------------------------------------------ Saffron Gym and Cinnabar
  -- Sabrina is surrounded by the gym's warp pads; goFar plans over same-map warps.
  beat('sabrina', function()
    moves()
    assert(N.travel('SaffronCity_Gym_Frlg'))
    assert(N.goFar(14, 12), 'to Sabrina')
    assert(N.talk(7, { side = 1 }), 'Sabrina')
    N.settle()
  end, function() return badge(6) end)

  beat('to_cinnabar', function()
    moves()
    assert(N.travel('CinnabarIsland_Frlg'))
    N.settle()
  end, function() return at('CinnabarIsland_Frlg') end)

  -- Statues toggle FLAG_POKEMON_MANSION_SWITCH_STATE, which swaps barriers on every floor. Route
  -- (BFS over tile and flag state): statue on 3F, fall to 1F, down to B1F, then both B1F statues.
  local function statue(x, y, want, what)
    assert(N.talk({ x, y }, { side = 1 }), what)
    N.settle()
    assert(FL('FLAG_POKEMON_MANSION_SWITCH_STATE') == want, what .. ' toggled')
  end
  beat('secret_key', function()
    moves()
    assert(N.travel('PokemonMansion_1F_Frlg'))
    assert(N.takeWarp(10, 13), '1F to 2F')
    assert(at('PokemonMansion_2F_Frlg'), 'on 2F')
    assert(N.takeWarp(9, 3), '2F to 3F')
    assert(at('PokemonMansion_3F_Frlg'), 'on 3F')
    statue(12, 5, true, '3F statue')
    assert(N.takeWarp(18, 18), 'fall to 1F')
    assert(at('PokemonMansion_1F_Frlg'), 'back on 1F')
    N.rememberMap()   -- the planner's memory of 1F predates the statue; the east door needs this state
    assert(N.takeWarp(25, 27), '1F to B1F')
    assert(at('PokemonMansion_B1F_Frlg'), 'on B1F')
    statue(24, 29, false, 'B1F statue 1')
    statue(27, 5, true, 'B1F statue 2')
    assert(N.talk(6), 'Secret Key')
    N.settle()
  end, function() return FL('FLAG_HIDE_POKEMON_MANSION_B1F_SECRET_KEY') end)

  -- The way back needs the opposite statue order; then the east door (34,33) in this state.
  beat('leave_mansion', function()
    moves()
    statue(27, 5, false, 'B1F statue 2')
    statue(24, 29, true, 'B1F statue 1')
    assert(N.takeWarp(34, 29), 'B1F to 1F')
    assert(N.travel('CinnabarIsland_Frlg'))
  end, function() return at('CinnabarIsland_Frlg') end)

  -- Each trainer also opens the quiz door he guards; Blaine's room is the last.
  beat('blaine', function()
    moves()
    assert(N.travel('CinnabarIsland_Gym_Frlg'))
    for _, t in ipairs({ { 1, 'Quinn' }, { 3, 'Avery' }, { 4, 'Ramon' }, { 5, 'Derek' }, { 6, 'Dusty' }, { 7, 'Zac' } }) do
      assert(N.talk(t[1]), t[2]); N.settle()
    end
    assert(N.talk(8, { side = 1 }), 'Blaine')
    N.settle()
  end, function() return badge(7) end)

  if SEVII then
    ---------------------------------------------------------------- Sevii Islands, before the League
    local PC_SCENE = 'VAR_MAP_SCENE_ONE_ISLAND_POKEMON_CENTER_1F'
    local HARBOR = { [0] = 'VermilionCity_Frlg', 'OneIsland_Harbor_Frlg', 'TwoIsland_Harbor_Frlg', 'ThreeIsland_Harbor_Frlg',
                     'FourIsland_Harbor_Frlg', 'FiveIsland_Harbor_Frlg', 'SixIsland_Harbor_Frlg', 'SevenIsland_Harbor_Frlg' }

    -- The ferry menu entries in order for one trip: 0 is Vermilion, 1..7 the islands. From a Rainbow
    -- Pass (scene 5) the menu is paged: Vermilion and islands up to 4 first, "OTHER" (index 4) for the rest.
    local function ferryPicks(origin, dest)
      if V(PC_SCENE) >= 5 then
        local page0, page1 = {}, {}
        for d = 0, 7 do if d ~= origin and #page0 < 4 then page0[#page0 + 1] = d end end
        for d = (origin < 5) and 5 or 4, 7 do if d ~= origin and #page1 < 3 then page1[#page1 + 1] = d end end
        for i, d in ipairs(page0) do if d == dest then return { i - 1 } end end
        for i, d in ipairs(page1) do if d == dest then return { 4, i - 1 } end end
        error('no ferry entry for ' .. dest .. ' from ' .. origin)
      end
      local list = {}
      if origin ~= 0 and V('VAR_MAP_SCENE_CINNABAR_ISLAND') >= 4 then list[1] = 0 end
      for d = 1, 3 do if d ~= origin then list[#list + 1] = d end end
      for i, d in ipairs(list) do if d == dest then return { i - 1 } end end
      error('no ferry entry for ' .. dest .. ' from ' .. origin)
    end

    local function sail(origin, dest)
      if not at(HARBOR[origin]) then assert(N.travel(HARBOR[origin]), 'to the harbor') end
      local picks, n = ferryPicks(origin, dest), 0
      local function policy(t, k)
        if k == 'yesno' then
          if t:lower():find('set sail') then return 'no' end   -- Vermilion's World Transit prompt
          return N.defaultPolicy(t, k)
        end
        n = n + 1
        return picks[math.min(n, #picks)]
      end
      assert(N.talk(origin == 0 and 6 or 2, { side = 2, policy = policy }), 'ferry sailor')
      N.settle()
      assert(at(HARBOR[dest]), 'ferry reached ' .. HARBOR[dest] .. ', now at ' .. N.mapName())
    end

    local function center(town, centerMap)
      assert(N.travel(centerMap), 'to ' .. centerMap)
      N.settle()
      L('  visited ' .. centerMap)
      assert(N.travel(town), 'back out to ' .. town)
    end

    seviiFerry = { picks = ferryPicks, sail = sail, center = center }

    beat('sevii_invite', function()
      moves()
      N.travel('CinnabarIsland_Frlg')   -- Bill's ON_FRAME scene sails us away mid-travel; the loop below ends it
      for _ = 1, 40 do
        if V(PC_SCENE) >= 1 and F.ow() and N.free() and at('OneIsland_PokemonCenter_1F_Frlg') then break end
        N.settle()
      end
    end, function() return V(PC_SCENE) == 1 and N.itemCount(C.ITEM_METEORITE) > 0 and N.itemCount(C.ITEM_TRI_PASS) > 0 end)

    -- PW_DETOUR=celio: before the League Celio must not start the gemstone chain; stop with --to detour_celio.
    if DETOUR == 'celio' then
      beat('detour_celio', function()
        moves()
        assert(N.talk(3), 'Celio')
        N.settle()
        L('  after talking to Celio: scene=' .. V(PC_SCENE) .. ' champion=' .. tostring(FL('FLAG_KANTO_CHAMPION')))
      end, function() return V(PC_SCENE) == 1 and V('VAR_MAP_SCENE_MT_EMBER_EXTERIOR') == 0 end)
    end

    beat('sevii_one_town', function()
      moves()
      assert(N.travel('OneIsland_Frlg'))
    end, function() return at('OneIsland_Frlg') end)

    beat('sevii_two', function()
      moves()
      sail(1, 2)
      center('TwoIsland_Frlg', 'TwoIsland_PokemonCenter_1F_Frlg')
      assert(N.travel('TwoIsland_JoyfulGameCorner_Frlg'))
      N.settle()
    end, function() return V('VAR_MAP_SCENE_TWO_ISLAND_JOYFUL_GAME_CORNER') == 1 and V('VAR_MAP_SCENE_THREE_ISLAND') == 2 end)

    -- Two coord rows south of the Biker gang: the boss's intro, then the four battles.
    beat('sevii_bikers', function()
      moves()
      sail(2, 3)
      assert(N.travel('ThreeIsland_Frlg'))
      if V('VAR_MAP_SCENE_THREE_ISLAND') == 2 then assert(N.go(9, 27)); N.settle() end
      if V('VAR_MAP_SCENE_THREE_ISLAND') == 3 then assert(N.go(9, 26)); N.settle() end
    end, function() return V('VAR_MAP_SCENE_THREE_ISLAND') == 4 end)

    beat('sevii_three_center', function()
      moves()
      center('ThreeIsland_Frlg', 'ThreeIsland_PokemonCenter_1F_Frlg')
    end, function() return at('ThreeIsland_Frlg') end)

    beat('sevii_lostelle', function()
      moves()
      assert(N.travel('ThreeIsland_BerryForest_Frlg', { tile = { 4, 9 } }))
      assert(N.talk(1, { side = 1 }), 'Lostelle')
      N.settle()
    end, function() return FL('FLAG_RESCUED_LOSTELLE') and at('TwoIsland_JoyfulGameCorner_Frlg') and V('VAR_MAP_SCENE_TWO_ISLAND_JOYFUL_GAME_CORNER') == 3 end)

    -- PW_DETOUR=meteorite: a champion may start Celio's gemstones first and bring the Meteorite last.
    -- With the Ruby already in the machine (scene 5) the delivery must not rewind his story. Stop
    -- this one with --to sevii_meteorite.
    beat('sevii_meteorite', function()
      moves()
      if DETOUR == 'meteorite' then N.setVar(C[PC_SCENE], 5) end
      assert(N.talk(1, { side = 1 }), 'Lostelle father')
      N.settle()
    end, function()
      return V(PC_SCENE) == (DETOUR == 'meteorite' and 5 or 2) and FL('FLAG_GOT_MOON_STONE_FROM_JOYFUL_GAME_CORNER')
    end)

    -- Bill leaves from the Center's x=12 column: the scene then sails back to Cinnabar.
    beat('sevii_return_bill', function()
      moves()
      sail(2, 1)
      assert(N.travel('OneIsland_PokemonCenter_1F_Frlg'))
      assert(N.go(12, 7, { allowTriggers = true }))
      for _ = 1, 40 do
        if V(PC_SCENE) == 3 and F.ow() and N.free() and at('CinnabarIsland_Frlg') and V('VAR_MAP_SCENE_CINNABAR_ISLAND') == 4 then break end
        N.settle()
      end
    end, function() return V(PC_SCENE) == 3 and at('CinnabarIsland_Frlg') and V('VAR_MAP_SCENE_CINNABAR_ISLAND') == 4 end)
  end

  ------------------------------------------------------------------ Viridian and the League
  -- Push the boulder in direction d with Strength, activating it first when it is not (every map
  -- load clears FLAG_SYS_USE_STRENGTH). A wild battle mid-push gets another try.
  local function shove(d, what)
    for _ = 1, 4 do
      if not N.free() then N.settle() end
      if not FL('FLAG_SYS_USE_STRENGTH') then
        N.face(d)
        if N.facing() == d then N.press('A'); N.idle(20); N.settle() end
      end
      local x0, y0 = F.pos()
      if FL('FLAG_SYS_USE_STRENGTH') and N.push(d) then return end
      local x, y = F.pos()
      if x ~= x0 or y ~= y0 then return end
      N.idle(60)
    end
    error('shove ' .. what)
  end

  -- A boulder route: a list of { standX, standY, dir }, each stand tile then one push.
  local function pushes(list, what)
    for i, p in ipairs(list) do
      assert(N.go(p[1], p[2]), string.format('%s stand %d (%d,%d)', what, i, p[1], p[2]))
      shove(p[3], string.format('%s push %d', what, i))
    end
  end

  -- Giovanni waits behind the spin floors, door opened by the seven other badges.
  beat('giovanni', function()
    moves()
    assert(N.travel('ViridianCity_Gym_Frlg'))
    assert(N.talk(8, { side = 1 }), 'Giovanni')
    N.settle()
  end, function() return badge(8) end)

  if ROW22 then
    beat('detour_route22_late', function() route22() end, function() return V('VAR_MAP_SCENE_ROUTE22') == 4 end)
  end

  -- Route 22's late rival fills the road west, and Route 23's guards check every badge.
  beat('to_victory_road', function()
    moves()
    assert(N.travel('VictoryRoad_1F_Frlg', { tile = { 7, 18 } }))
  end, function() return at('VictoryRoad_1F_Frlg') end)

  -- 1F: boulder (7,18) onto the switch (20,16), computed push by push.
  beat('victory_road_1f', function()
    moves()
    pushes({ { 7, 17, 1 }, { 6, 19, 4 }, { 7, 19, 4 }, { 8, 19, 4 }, { 9, 19, 4 }, { 11, 20, 2 }, { 10, 18, 4 }, { 12, 19, 2 },
             { 11, 17, 4 }, { 12, 17, 4 }, { 13, 17, 4 }, { 14, 17, 4 }, { 15, 17, 4 }, { 16, 17, 4 }, { 17, 17, 4 }, { 19, 18, 2 },
             { 19, 17, 2 }, { 18, 15, 4 }, { 20, 14, 1 } }, '1F boulder')
    N.settle()
    assert(N.travel('VictoryRoad_2F_Frlg'))
  end, function() return V('VAR_MAP_SCENE_VICTORY_ROAD_1F') == 100 end)

  -- 2F: the boulder (6,17) onto the west switch, then the east ladder to 3F (34,9).
  beat('victory_road_2f', function()
    moves()
    pushes({ { 6, 16, 1 }, { 7, 18, 3 }, { 6, 18, 3 }, { 4, 17, 1 }, { 5, 19, 3 }, { 4, 19, 3 } }, '2F west boulder')
    N.settle()
    assert(N.travel('VictoryRoad_3F_Frlg', { tile = { 34, 9 } }))
  end, function() return V('VAR_MAP_SCENE_VICTORY_ROAD_2F_BOULDER1') == 100 and at('VictoryRoad_3F_Frlg') end)

  -- 3F: boulder (32,5) to the far switch (7,7); then its neighbour (33,18) into the hole (34,18).
  beat('victory_road_3f', function()
    moves()
    pushes({ { 32, 6, 2 }, { 32, 5, 2 }, { 33, 3, 3 }, { 32, 3, 3 }, { 31, 3, 3 }, { 30, 3, 3 }, { 29, 3, 3 }, { 28, 3, 3 }, { 27, 3, 3 },
             { 26, 3, 3 }, { 25, 3, 3 }, { 24, 3, 3 }, { 23, 3, 3 }, { 22, 3, 3 }, { 21, 3, 3 }, { 20, 3, 3 }, { 19, 3, 3 }, { 18, 3, 3 },
             { 17, 3, 3 }, { 16, 3, 3 }, { 15, 3, 3 }, { 14, 3, 3 }, { 13, 3, 3 }, { 11, 2, 1 }, { 12, 4, 3 }, { 11, 4, 3 }, { 10, 4, 3 },
             { 9, 4, 3 }, { 8, 4, 3 }, { 6, 3, 1 }, { 6, 4, 1 }, { 6, 5, 1 }, { 5, 7, 4 } }, '3F boulder')
    N.settle()
    assert(N.go(32, 18))
    shove(4, 'boulder into the hole')
    assert(N.takeWarp(34, 18), 'fall through the hole')
  end, function() return V('VAR_MAP_SCENE_VICTORY_ROAD_3F') == 100 and at('VictoryRoad_2F_Frlg') end)

  -- 2F: the fallen boulder along row 19 onto the second switch, then the exit to Route 23 north.
  beat('victory_road_exit', function()
    moves()
    if N.object(12) then
      pushes({ { 34, 19, 3 }, { 33, 19, 3 }, { 32, 19, 3 }, { 31, 19, 3 }, { 30, 19, 3 }, { 29, 19, 3 }, { 28, 19, 3 }, { 27, 19, 3 },
               { 26, 19, 3 }, { 25, 19, 3 }, { 24, 19, 3 }, { 23, 19, 3 }, { 22, 19, 3 }, { 21, 19, 3 }, { 20, 19, 3 }, { 19, 19, 3 },
               { 18, 19, 3 }, { 17, 19, 3 }, { 16, 19, 3 } }, '2F fallen boulder')
      N.settle()
    end
    assert(N.travel('IndigoPlateau_Exterior_Frlg'))
  end, function() return at('IndigoPlateau_Exterior_Frlg') end)   -- Route 23's ON_TRANSITION resets the boulder vars

  ------------------------------------------------------------------ The League
  beat('to_league', function()
    moves()
    assert(N.travel('PokemonLeague_LoreleisRoom_Frlg'))
    N.settle()
  end, function() return at('PokemonLeague_LoreleisRoom_Frlg') end)

  -- Room scripts walk the player to the member and seal the south door; the member's defeat opens
  -- the north one.
  for _, e in ipairs({ { 'LoreleisRoom', 'LORELEI', 'BrunosRoom' }, { 'BrunosRoom', 'BRUNO', 'AgathasRoom' },
                       { 'AgathasRoom', 'AGATHA', 'LancesRoom' } }) do
    local room, flag, next = 'PokemonLeague_' .. e[1] .. '_Frlg', 'FLAG_DEFEATED_' .. e[2], 'PokemonLeague_' .. e[3] .. '_Frlg'
    beat('e4_' .. e[1], function()
      moves()
      if not at(room) then assert(N.travel(room)) end
      N.settle()
      if not FL(flag) then assert(N.talk(1, { side = 1 }), e[2]) end
      N.settle()
      assert(FL(flag), e[2] .. ' beaten')
      assert(N.takeWarp(6, 2), 'out of ' .. room)
      N.settle()
    end, function() return FL(flag) and at(next) end)
  end

  beat('e4_lance', function()
    moves()
    local room = 'PokemonLeague_LancesRoom_Frlg'
    if not at(room) then assert(N.travel(room)) end
    N.settle()
    if not FL('FLAG_DEFEATED_LANCE') then assert(N.talk(1, { side = 1 }), 'Lance') end
    N.settle()
  end, function() return FL('FLAG_DEFEATED_LANCE') end)

  -- Lance's room door (6,5) leads to the champion; the room's ON_FRAME battle, then Oak and the
  -- Hall of Fame and the credits. Mash A until the game hands control back.
  local CHAMP_MAPS = { PalletTown_PlayersHouse_2F_Frlg = true, PalletTown_Frlg = true, PalletTown_PlayersHouse_1F_Frlg = true,
                       IndigoPlateau_PokemonCenter_1F_Frlg = true, PokemonLeague_HallOfFame_Frlg = true, RegionHub = true }
  beat('champion', function()
    moves()
    assert(N.takeWarp(6, 5, { limit = 60 * 60 * 20 }))
    for _ = 1, 60 * 60 * 20 // 12 do
      if FL('FLAG_KANTO_CHAMPION') and F.ow() and N.free() and CHAMP_MAPS[N.mapName()] then break end
      if N.inBattle() then N.settle() else F.press('A', 2); F.idle(10) end
    end
    N.settle()
    L('  after the Hall of Fame: ' .. N.mapName() .. ' champion=' .. tostring(FL('FLAG_KANTO_CHAMPION'))
      .. ' game clear=' .. tostring(FL('FLAG_SYS_GAME_CLEAR')))
  end, function() return FL('FLAG_KANTO_CHAMPION') and F.ow() end)

  -- Back under control after the credits: walk home to prove the save resumes in play.
  beat('home', function()
    moves()
    local x0, y0 = F.pos()
    L('  under control at ' .. N.mapName() .. string.format(' (%d,%d)', x0, y0))
    assert(N.travel('PalletTown_PlayersHouse_1F_Frlg'))
    N.settle()
    local x, y = F.pos()
    L(string.format('  moved to %s (%d,%d)', N.mapName(), x, y))
  end, function() return FL('FLAG_KANTO_CHAMPION') and F.ow() and N.free() and at('PalletTown_PlayersHouse_1F_Frlg') end)

  if SEVII then
    ---------------------------------------------------------------- Sevii Islands, the post-game
    local PC_SCENE = 'VAR_MAP_SCENE_ONE_ISLAND_POKEMON_CENTER_1F'
    local ferryPicks, sail, center = seviiFerry.picks, seviiFerry.sail, seviiFerry.center

    beat('sevii_ferry_out', function()
      moves()
      sail(0, 1)
    end, function() return at('OneIsland_Harbor_Frlg') end)

    beat('sevii_ruby_request', function()
      moves()
      assert(N.travel('OneIsland_PokemonCenter_1F_Frlg'))
      for _ = 1, 3 do
        assert(N.talk(3), 'Celio')
        N.settle()
        if V(PC_SCENE) == 4 then break end
      end
    end, function() return V(PC_SCENE) == 4 end)

    beat('sevii_ember_spa', function()
      moves()
      assert(N.travel('OneIsland_KindleRoad_EmberSpa_Frlg'))
      assert(N.talk(5), 'HM06 giver')
      N.settle()
    end, function() return FL('FLAG_GOT_HM06') end)

    -- The password guards stand on Mt. Ember's door: the coord row sets scene 2, then both must be beaten.
    beat('sevii_ember_grunts', function()
      moves()
      assert(N.travel('MtEmber_Exterior_Frlg', { tile = { 38, 44 } }))
      if V('VAR_MAP_SCENE_MT_EMBER_EXTERIOR') == 1 then assert(N.go(38, 43)); N.settle() end
      assert(N.talk(2), 'grunt 1'); N.settle()
      assert(N.talk(3), 'grunt 2'); N.settle()
    end, function() return V('VAR_MAP_SCENE_MT_EMBER_EXTERIOR') >= 2 and not N.object(2) and not N.object(3) end)

    beat('sevii_ruby', function()
      moves()
      assert(N.travel('MtEmber_RubyPath_B2F_Frlg'))
      pushes({ { 8, 3, 4 }, { 9, 3, 4 }, { 11, 5, 4 }, { 12, 3, 2 } }, 'Ruby Path B2F')
      N.settle()
      assert(N.travel('MtEmber_RubyPath_B3F_Frlg'))
      pushes({ { 9, 4, 4 }, { 11, 3, 1 }, { 16, 13, 3 }, { 15, 13, 3 }, { 14, 13, 3 }, { 13, 13, 3 }, { 12, 13, 3 }, { 11, 13, 3 },
               { 10, 13, 3 }, { 9, 13, 3 }, { 8, 13, 3 } }, 'Ruby Path B3F')
      N.settle()
      assert(N.travel('MtEmber_RubyPath_B5F_Frlg', { tile = { 7, 8 } }))
      assert(N.talk(1, { side = 1 }), 'the Ruby')
      N.settle()
    end, function() return FL('FLAG_GOT_RUBY') and N.itemCount(C.ITEM_RUBY) > 0 end)

    -- Boulders reset when a floor reloads, so the way back shoves them aside again from the far side.
    beat('sevii_leave_ember', function()
      moves()
      assert(N.travel('MtEmber_RubyPath_B3F_Frlg'))
      pushes({ { 14, 13, 4 }, { 15, 13, 4 }, { 16, 13, 4 }, { 11, 4, 3 }, { 10, 4, 3 } }, 'Ruby Path B3F return')
      N.settle()
      assert(N.travel('MtEmber_RubyPath_B2F_Frlg'))
      pushes({ { 13, 5, 3 }, { 10, 3, 3 }, { 9, 3, 3 } }, 'Ruby Path B2F return')
      N.settle()
      assert(N.travel('MtEmber_Exterior_Frlg'))
    end, function() return at('MtEmber_Exterior_Frlg') end)

    beat('sevii_deliver_ruby', function()
      moves()
      assert(N.travel('OneIsland_PokemonCenter_1F_Frlg'))
      assert(N.talk(3), 'Celio')
      N.settle()
    end, function() return V(PC_SCENE) == 5 and N.itemCount(C.ITEM_RAINBOW_PASS) > 0 end)

    beat('sevii_four', function()
      moves()
      sail(1, 4)
      assert(N.travel('FourIsland_Frlg'))
      N.settle()
      center('FourIsland_Frlg', 'FourIsland_PokemonCenter_1F_Frlg')
    end, function() return at('FourIsland_Frlg') and V('VAR_MAP_SCENE_FOUR_ISLAND') >= 1 end)

    beat('sevii_icefall', function()
      moves()
      assert(N.travel('FourIsland_IcefallCave_Back_Frlg', { tile = { 12, 19 } }))
      assert(N.go(12, 18))
      N.settle()
    end, function() return V('VAR_MAP_SCENE_ICEFALL_CAVE_BACK') == 1 and FL('FLAG_HIDE_RUIN_VALLEY_SCIENTIST') end)

    beat('sevii_six', function()
      moves()
      assert(N.travel('FourIsland_Frlg'))
      sail(4, 6)
      assert(N.travel('SixIsland_Frlg'))
      center('SixIsland_Frlg', 'SixIsland_PokemonCenter_1F_Frlg')
    end, function() return at('SixIsland_Frlg') end)

    beat('sevii_dotted_hole', function()
      moves()
      assert(N.travel('SixIsland_RuinValley_Frlg', { tile = { 24, 25 } }))
      assert(N.go(24, 25))
      N.face(2)
      N.press('A'); N.idle(20)
      N.settle()
      assert(FL('FLAG_USED_CUT_ON_RUIN_VALLEY_BRAILLE'), 'Ruin Valley door opened')
      assert(N.travel('SixIsland_DottedHole_1F_Frlg'))
      assert(N.takeWarp(6, 5), '1F to B1F')
      assert(N.takeWarp(6, 1), 'B1F Up')
      assert(N.takeWarp(1, 5), 'B2F Left')
      assert(N.takeWarp(11, 5), 'B3F Right')
      assert(N.takeWarp(6, 9), 'B4F Down')
      assert(at('SixIsland_DottedHole_SapphireRoom_Frlg'), 'reached the Sapphire room')
      assert(N.talk(1), 'Sapphire')
      N.settle()
    end, function() return FL('FLAG_LEARNED_YES_NAH_CHANSEY') end)

    beat('sevii_five', function()
      moves()
      assert(N.travel('SixIsland_Harbor_Frlg'))
      sail(6, 5)
      assert(N.travel('FiveIsland_Frlg'))
      center('FiveIsland_Frlg', 'FiveIsland_PokemonCenter_1F_Frlg')
    end, function() return at('FiveIsland_Frlg') end)

    beat('sevii_warehouse', function()
      moves()
      assert(N.travel('FiveIsland_Meadow_Frlg', { tile = { 12, 22 } }))
      assert(N.go(12, 22))
      N.face(2)
      N.press('A'); N.idle(20)
      N.settle()
      assert(FL('FLAG_UNLOCKED_ROCKET_WAREHOUSE'), 'passwords')
      assert(N.travel('FiveIsland_RocketWarehouse_Frlg', { tile = { 26, 4 } }))
      N.settle()
      assert(N.talk(6, { side = 1 }), 'Gideon')
      N.settle()
    end, function() return FL('FLAG_RECOVERED_SAPPHIRE') end)

    beat('sevii_seven', function()
      moves()
      assert(N.travel('FiveIsland_Harbor_Frlg'))
      sail(5, 7)
      assert(N.travel('SevenIsland_Frlg'))
      center('SevenIsland_Frlg', 'SevenIsland_PokemonCenter_1F_Frlg')
    end, function() return at('SevenIsland_Frlg') end)

    beat('sevii_lorelei', function()
      moves()
      assert(N.travel('SevenIsland_Harbor_Frlg'))
      sail(7, 4)
      assert(N.travel('FourIsland_LoreleisHouse_Frlg'))
      assert(N.talk(1), 'Lorelei')
      N.settle()
    end, function() return FL('FLAG_TALKED_TO_LORELEI_AFTER_WAREHOUSE') end)

    beat('sevii_deliver_sapphire', function()
      moves()
      assert(N.travel('FourIsland_Harbor_Frlg'))
      sail(4, 1)
      assert(N.travel('OneIsland_PokemonCenter_1F_Frlg'))
      assert(N.talk(3), 'Celio')
      N.settle()
    end, function() return V(PC_SCENE) >= 6 end)

    beat('sevii_ferry_home', function()
      moves()
      assert(N.travel('OneIsland_Harbor_Frlg'))
      sail(1, 0)
    end, function() return at('VermilionCity_Frlg') end)
  end

  return B
end
