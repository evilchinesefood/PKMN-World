-- All three regions on one save. Joins slices of the region campaigns, crossing through the Hub
-- between them. PW_WORLD picks the order: A starts in Johto and rotates one slice at a time,
-- B starts in Hoenn and plays two slices of each region in a row.
return function(F, N, C, log)
  local L = F.L
  local here = (debug.getinfo(1, 'S').source:sub(2)):match('^(.*[/\\])')
  package.path = here .. '../hoenn-playthrough/?.lua;' .. package.path
  local P, O = require('pwsym'), require('pwoff')

  -- Harness settings the region campaigns write onto N. Each region keeps its own between visits.
  local KEYS = { 'run', 'screen', 'region', 'pokenavTicks', 'passGoal', 'canWaterfall', 'canSurf', 'canSmash', 'canCut',
    'canWhirlpool', 'waterTrail', 'defaultPolicy', 'starterMoved', 'planIgnoreObjects', 'catchWanted', 'acceptPrompts',
    'waterLandingMisses', 'solidBoulders', 'resetAvoid', 'passWild', 'noEnter', 'clearItems', 'beatSetup' }
  local function snapshot()
    local t = {}
    for _, k in ipairs(KEYS) do t[k] = N[k] end
    return t
  end
  local function restore(t) for _, k in ipairs(KEYS) do N[k] = t[k] end end

  local REGIONS, base = {}, snapshot()
  for _, r in ipairs({ { 'johto', 'j', 16 }, { 'kanto', 'k', 11 }, { 'hoenn', 'h', 21 } }) do
    restore(base)
    local beats = assert(loadfile(here .. '../' .. r[1] .. '-playthrough/beats.lua'))()(F, N, C, log)
    local index = {}
    for i, b in ipairs(beats) do index[b.name] = i end
    REGIONS[r[1]] = { beats = beats, index = index, prefix = r[2], gate = r[3], config = snapshot() }
  end

  local SLICES = {
    johto = { { 'to_johto', 'mom_farewell' }, { 'to_violet', 'whitney' }, { 'squirtbottle', 'morty' }, { 'theater_surf', 'jasmine' },
              { 'mahogany_arrive', 'pryce' }, { 'elm_radio_call', 'den_exit' }, { 'elm_master_ball', 'lance_and_hall_of_fame' } },
    kanto = { { 'to_kanto', 'brock' }, { 'to_cerulean', 'misty' }, { 'cut', 'erika' }, { 'snorlax', 'sabrina' },
              { 'to_cinnabar', 'giovanni' }, { 'to_victory_road', 'home' } },
    hoenn = { { 'to_hoenn', 'route103' }, { 'pokedex', 'sail_slateport' }, { 'devon_dock', 'wattson' }, { 'rock_smash', 'go_goggles' },
              { 'to_rustboro', 'winona' }, { 'route121_aqua', 'tate_liza' }, { 'space_center', 'juan' }, { 'to_victory_road', 'home' } },
  }
  local ORDERS = {
    A = { 'johto', 'kanto', 'hoenn', 'johto', 'kanto', 'hoenn', 'johto', 'kanto', 'hoenn', 'johto', 'kanto', 'hoenn', 'johto', 'kanto',
          'hoenn', 'johto', 'kanto', 'hoenn', 'johto', 'hoenn', 'hoenn' },
    B = { 'hoenn', 'hoenn', 'johto', 'johto', 'kanto', 'kanto', 'hoenn', 'hoenn', 'johto', 'johto', 'kanto', 'kanto', 'hoenn', 'hoenn',
          'johto', 'johto', 'kanto', 'kanto', 'hoenn', 'hoenn', 'johto' },
    J = { 'johto', 'johto', 'johto', 'johto', 'johto', 'johto', 'johto' },   -- for PW_POSTGAME: a Johto champion who never left
  }
  local order = assert(ORDERS[os.getenv('PW_WORLD') or 'A'], 'PW_WORLD')

  -- A crossing boxes the party, and the player would withdraw it at a PC. That storage screen isn't
  -- what this campaign tests, so the region's team is put back directly and its boxed copies removed.
  local stash, seen = {}, {}
  local function keepParty(region)
    local t = { count = N.partyCount() }
    for i = 0, 149 do t[i] = F.r32(P.gParties + i * 4) end
    stash[region] = t
    -- Kept on disk too, because a --from resume starts with an empty table.
    local f = assert(io.open(F.out .. 'stash_' .. region, 'w'))
    f:write(t.count, '\n')
    for i = 0, 149 do f:write(t[i], '\n') end
    f:close()
  end
  local function loadParty(region)
    local f = io.open(F.out .. 'stash_' .. region)
    if not f then return nil end
    local t = { count = f:read('n') }
    for i = 0, 149 do t[i] = f:read('n') end
    f:close()
    return t
  end
  local function restoreParty(region)
    local t = stash[region] or loadParty(region)
    stash[region] = t
    if not t then return end
    local want = {}
    for i = 0, t.count - 1 do want[t[i * 25]] = true end
    local base2 = F.r32(P.gPokemonStoragePtr) + O.ps_boxes
    local removed = 0
    for slot = 0, 14 * 30 - 1 do
      local b = base2 + slot * O.box_size
      local pid = F.r8(b) | F.r8(b + 1) << 8 | F.r8(b + 2) << 16 | F.r8(b + 3) << 24
      if pid ~= 0 and want[pid] then
        for off = 0, O.box_size - 1 do F.w8(b + off, 0) end
        removed = removed + 1
      end
    end
    for i = 0, 149 do F.w32(P.gParties + i * 4, t[i]) end
    F.w8(P.gPartiesCount, t.count)
    L(string.format('  party restored: %d mons, %d boxed copies removed', t.count, removed))
  end

  local function inRegion(group, region)
    local r = REGIONS[region].config.region
    return group >= r.lo and group <= r.hi
  end

  -- Per beat, not per crossing, so a --from resume starts with the right region's settings.
  local active
  local function enter(region)
    if active == region then return end
    if active then REGIONS[active].config = snapshot() end
    restore(REGIONS[region].config)
    active = region
  end

  local B, nextSlice, current, crossings = {}, {}, nil, 0
  local function cross(to)
    crossings = crossings + 1
    local from, first, money, balls = current, not seen[to], 0, 0
    local name = 'cross' .. crossings .. '_to_' .. to
    B[#B + 1] = { name = name, run = function()
      enter(from)
      money, balls = N.money(), N.itemCount(C.ITEM_POKE_BALL)
      keepParty(from)
      N.useHubPass()
      assert(N.mapName() == 'RegionHub', 'Hub Pass reached the Hub from ' .. N.mapName())
      enter(to)
      if not first then
        N.crossGate(REGIONS[to].gate)
        L(string.format('  landed at %s party=%d', N.mapName(), N.partyCount()))
        assert(N.partyCount() == 0, 'a crossing should box the party')
        restoreParty(to)
      end
    end, done = function()
      local heal = F.r8(F.sb1() + F.S.SaveBlock1.lastHealLocation)
      local same = N.money() == money and N.itemCount(C.ITEM_POKE_BALL) == balls
      if not same then L(string.format('  shared state changed: money %d -> %d, balls %d -> %d', money, N.money(), balls, N.itemCount(C.ITEM_POKE_BALL))) end
      if first then return same and N.mapName() == 'RegionHub' end
      local good = same and F.ow() and N.free() and inRegion(F.grp(), to) and inRegion(heal, to) and N.partyCount() == stash[to].count
      if not good then L(string.format('  landed: %s group %d, respawn group %d, party %d', N.mapName(), F.grp(), heal, N.partyCount())) end
      return good
    end }
    seen[to] = true
    current = to
  end

  local last
  for _, region in ipairs(order) do
    if current and current ~= region then cross(region) end
    if not current then current = region; seen[region] = true end
    local r, n = REGIONS[region], (nextSlice[region] or 0) + 1
    nextSlice[region] = n
    local s = assert(SLICES[region][n], 'no slice ' .. n .. ' for ' .. region)
    -- Mt. Moon can't be walked to from the Vermilion gate with one badge; Cerulean can, by the
    -- Underground Path. Only a player who stayed in Kanto after Brock goes through the mountain.
    if region == 'kanto' and n == 2 and last == 'kanto' then s = { 'mt_moon_fossil', 'misty' } end
    for i = assert(r.index[s[1]], s[1]), assert(r.index[s[2]], s[2]) do
      local b = r.beats[i]
      local loss = b.loss
      if loss and loss.replayFrom then
        local copy = {}
        for k, v in pairs(loss) do copy[k] = v end
        copy.replayFrom = r.prefix .. '_' .. loss.replayFrom
        loss = copy
      end
      B[#B + 1] = { name = r.prefix .. '_' .. b.name, run = function()
        enter(region)
        if N.beatSetup then N.beatSetup() end   -- a region re-entered from its gate needs its field moves
        b.run()
      end, done = b.done, loss = loss }
    end
    last = region
  end
  if os.getenv('PW_POSTGAME') then
    B = assert(loadfile(here .. 'postgame.lua'))()(F, N, C, log, B, {
      enter = enter, snapshot = snapshot, restore = restore, keepParty = keepParty, restoreParty = restoreParty,
      regions = REGIONS, gates = { johto = 16, kanto = 11, hoenn = 21 },
    })
  end
  return B
end
