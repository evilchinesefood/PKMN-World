-- Dive and emerge for the playthrough harness, and travel through Hoenn's underwater maps.
--
--   require('water')(F, N, C)   -- once, after nav; then N.travel('SootopolisCity') just works
--
-- Adds N.underwater(), N.dive(), N.emerge() and N.planWater(target), and wraps N.travel: trips
-- are planned with dive and emerge links too (each costs 30 steps). A plan that never dives goes
-- to nav's own N.travel; one that does is executed one hop at a time, re-planning after each.
--
-- Game rules modelled (src/field_control_avatar.c TrySetDiveWarp, src/overworld.c SetDiveWarp):
-- A on a diveable tile dives, a fresh B underwater emerges, unless the tile is no-surfacing or a
-- water door. Either way the player lands on the same x,y of the map's dive (5) or emerge (6)
-- connection. A map without that connection uses the setdivewarp of its ON_DIVE_WARP script,
-- which the header cannot show: FIXED lists the ones the story needs.
local P = require('pwsym')
local O = require('pwoff')
local MAPS = require('pwmaps')

return function(F, N, C)
  local L = F.L
  local DIVE, EMERGE = 5, 6
  local FIXED = {
    SeafloorCavern_Entrance = { kind = 'dive', map = 'Underwater_SeafloorCavern', x = 6, y = 5 },
    Underwater_SeafloorCavern = { kind = 'emerge', map = 'SeafloorCavern_Entrance', x = 10, y = 17 },
    SootopolisCity = { kind = 'dive', map = 'Underwater_SootopolisCity', x = 9, y = 6 },
    Underwater_SootopolisCity = { kind = 'emerge', map = 'SootopolisCity', x = 29, y = 53 },
  }
  local DIVEABLE = { [C.MB_DEEP_WATER] = true, [C.MB_INTERIOR_DEEP_WATER] = true, [C.MB_SOOTOPOLIS_DEEP_WATER] = true }
  local NO_EMERGE = { [C.MB_NO_SURFACING] = true, [C.MB_SEAWEED_NO_SURFACING] = true }

  function N.underwater() return (F.r8(P.gPlayerAvatar + O.pa_flags) & 0x10) ~= 0 end

  -- Underwater, B is the emerge key and nav holds B to run: keep running off until we surface.
  local runAfter
  local function noRun()
    if N.run then runAfter, N.run = true, false end
  end

  -- Press the key, answer the prompt, ride the warp. An A on deep water after arrival would
  -- offer Dive again, so nothing is pressed once the map has changed.
  local function useDive(key)
    local g0, m0 = F.grp(), F.mapn()
    N.idle(10); N.press(key); N.idle(20)
    local quiet = 0
    for _ = 1, 1500 do
      if F.grp() ~= g0 or F.mapn() ~= m0 then break end
      if N.activeTask(P.Task_HandleYesNoInput) then
        N.noteMessage(); N.idle(20); N.press('A'); N.idle(30); quiet = 0
      elseif F.ow() and N.scriptBusy() then
        N.noteMessage(); N.press('A'); N.idle(16); quiet = 0
      elseif not F.ow() then
        N.idle(4); quiet = 0
      else
        N.idle(2); quiet = quiet + 2
        if quiet > 480 then break end   -- the field move cut-in runs with the script idle
      end
    end
    if F.grp() == g0 and F.mapn() == m0 then
      local x, y = F.pos()
      L(string.format('  %s: no dive at %s (%d,%d)', key == 'A' and 'dive' or 'emerge', N.mapName(), x, y))
      return false
    end
    for _ = 1, 600 do
      if F.ow() and N.free() then break end
      N.idle(2)
    end
    N.idle(30)
    return true
  end

  function N.dive()
    noRun()
    return useDive('A')
  end
  function N.emerge()
    noRun()
    local ok = useDive('B')
    if ok and not N.underwater() and runAfter then N.run, runAfter = true, nil end
    return ok
  end

  ---------------------------------------------------------------- planning
  -- hop = { kind = 'warp'|'conn'|'dive'|'emerge', g, m, x, y (the tile it is taken from),
  --         tg, tm (the map it reaches), dir (conn only) }

  local function tileAt(x, y) return x .. ',' .. y end
  local function parse(k) local x, y = k:match('(-?%d+),(-?%d+)'); return tonumber(x), tonumber(y) end

  -- Dive or emerge hops from a map, given the tiles reachable on it: the cheapest launch tile per
  -- landing area of the map below (or above), so each area costs one node, not one per tile.
  local function waterHops(info, reach)
    local conn
    for _, c in ipairs(info.conns) do if c.dir == DIVE or c.dir == EMERGE then conn = c end end
    local fixed = not conn and FIXED[N.mapName(info.g, info.m)]
    if not conn and not fixed then return {} end
    local kind = conn and (conn.dir == DIVE and 'dive' or 'emerge') or fixed.kind
    local grid = N.staticGrid(info)
    local launch = {}
    for k, cost in pairs(reach) do
      local x, y = parse(k)
      local v = grid.get(x, y)
      local b = v and grid.beh(v & 0x3FF)
      if b and ((kind == 'dive' and DIVEABLE[b]) or (kind == 'emerge' and not NO_EMERGE[b] and not N.WARPB[b])) then
        launch[#launch + 1] = { x = x, y = y, cost = cost }
      end
    end
    table.sort(launch, function(a, b) return a.cost < b.cost end)
    local hops = {}
    if fixed then
      local to = MAPS[fixed.map]
      if launch[1] then
        hops[1] = { kind = kind, g = info.g, m = info.m, x = launch[1].x, y = launch[1].y, tg = to.g, tm = to.m,
                    ex = fixed.x, ey = fixed.y, cost = launch[1].cost }
      end
      return hops
    end
    local dest = N.header(conn.g, conn.m)
    local dg = N.staticGrid(dest)
    local covered = {}
    for _, t in ipairs(launch) do
      local v = dg.get(t.x, t.y)
      if not covered[tileAt(t.x, t.y)] and v and (v & 0x0C00) == 0 then
        hops[#hops + 1] = { kind = kind, g = info.g, m = info.m, x = t.x, y = t.y, tg = conn.g, tm = conn.m,
                            ex = t.x, ey = t.y, cost = t.cost }
        for kk in pairs(N.flood(dest, t.x, t.y, N.canSurf)) do covered[kk] = true end
      end
    end
    return hops
  end

  local function landHops(info, reach)
    local hops = {}
    for _, ex in ipairs(N.exitsOf(info)) do
      if ex.kind == 'warp' then
        -- Walk onto it, or (a door in a wall) stand next to it.
        local best
        for d = 0, 4 do
          local ax, ay = ex.x + (d > 0 and N.DX[d] or 0), ex.y + (d > 0 and N.DY[d] or 0)
          local r = reach[tileAt(ax, ay)]
          if r and (not best or r < best.cost) then best = { cost = r } end
        end
        if best then
          hops[#hops + 1] = { kind = 'warp', g = info.g, m = info.m, x = ex.x, y = ex.y, tg = ex.g, tm = ex.m,
                              ex = ex.ex, ey = ex.ey, cost = best.cost }
        end
      else
        local onEdge = N.connGoal(info, ex)
        local dg = N.staticGrid(ex.dest)
        for k, cost in pairs(reach) do
          local x, y = parse(k)
          if onEdge(x, y) then
            local d, o, dest = ex.dir, ex.offset, ex.dest
            local nx, ny
            if d == 1 then nx, ny = x - o, 0 elseif d == 2 then nx, ny = x - o, dest.h - 1
            elseif d == 3 then nx, ny = dest.w - 1, y - o else nx, ny = 0, y - o end
            local v = dg.get(nx, ny)
            if v and (v & 0x0C00) == 0 then
              hops[#hops + 1] = { kind = 'conn', g = info.g, m = info.m, x = x, y = y, tg = ex.g, tm = ex.m,
                                  ex = nx, ey = ny, dir = d, cost = cost }
            end
          end
        end
      end
    end
    return hops
  end

  -- Dijkstra over (map, entry tile), as nav's N.route, plus water hops. Returns the hop list.
  function N.planWater(target)
    N.resetPlanCaches()
    local tg = assert(MAPS[target], 'unknown map ' .. tostring(target))
    local g0, m0 = F.grp(), F.mapn()
    local sx, sy = F.pos()
    local function key(g, m, x, y) return g .. ':' .. m .. ':' .. x .. ',' .. y end
    local startK = key(g0, m0, sx, sy)
    local dist, back = { [startK] = 0 }, {}
    local frontier = { { k = startK, g = g0, m = m0, x = sx, y = sy, d = 0 } }
    local visited = 0
    while #frontier > 0 and visited < 3000 do
      table.sort(frontier, function(a, b) return a.d < b.d end)
      local n = table.remove(frontier, 1)
      if n.d <= dist[n.k] then
        visited = visited + 1
        if n.g == tg.g and n.m == tg.m then
          local path, k = {}, n.k
          while back[k] do table.insert(path, 1, back[k].hop); k = back[k].from end
          return path
        end
        local info = N.header(n.g, n.m)
        local reach = N.flood(info, n.x, n.y, N.canSurf)
        for _, list in ipairs({ landHops(info, reach), waterHops(info, reach) }) do
          for _, h in ipairs(list) do
            local k = key(h.tg, h.tm, h.ex, h.ey)
            local d = n.d + h.cost + ((h.kind == 'dive' or h.kind == 'emerge') and 30 or 10)
            if h.tg >= N.region.lo and h.tg <= N.region.hi and (dist[k] == nil or dist[k] > d) then
              dist[k], back[k] = d, { from = n.k, hop = h }
              frontier[#frontier + 1] = { k = k, g = h.tg, m = h.tm, x = h.ex, y = h.ey, d = d }
            end
          end
        end
      end
    end
  end

  ---------------------------------------------------------------- executing
  local function crossEdge(h)
    local g0, m0 = F.grp(), F.mapn()
    N.go(h.x, h.y, { tag = 'edge->' .. N.mapName(h.tg, h.tm) })
    -- Land on this side, water on the other: walking into it does nothing, so Surf across.
    local grid = N.liveGrid()
    local v = grid.raw(h.x + N.DX[h.dir], h.y + N.DY[h.dir])
    if v and N.canSurf and not N.surfing() and not N.underwater() and N.surfable(grid.beh(v & 0x3FF)) then
      N.face(h.dir); N.press('A'); N.idle(30)
      N.settle({ policy = function(_, k) return k == 'yesno' and 'yes' or 0 end })
    end
    for _ = 1, 3 do
      if F.grp() ~= g0 or F.mapn() ~= m0 then break end
      for _ = 1, 40 do joypad.set({ [N.KEY[h.dir]] = true }); emu.frameadvance() end
      N.idle(30)
      if not N.free() then N.settle() end
    end
    return F.grp() ~= g0 or F.mapn() ~= m0
  end

  local function takeHop(h)
    if h.kind == 'warp' then return N.takeWarp(h.x, h.y) end
    if h.kind == 'conn' then return crossEdge(h) end
    if not N.go(h.x, h.y, { tag = h.kind .. ' spot' }) then return false end
    if h.kind == 'dive' then return N.dive() end
    return N.emerge()
  end

  N.waterTrail = {}   -- hops taken by the wrapper, e.g. 'dive Route128 (38,27) -> Underwater_Route128'
  local baseTravel = N.travel
  function N.travel(target, opts)
    opts = opts or {}
    local tg = assert(MAPS[target], 'unknown map ' .. tostring(target))
    for _ = 1, 60 do
      if not N.free() then N.settle(opts) end
      if N.underwater() then noRun() end
      N.rememberMap()
      if F.grp() == tg.g and F.mapn() == tg.m then return true end
      local path = N.planWater(target)
      local wet = false
      for _, h in ipairs(path or {}) do wet = wet or h.kind == 'dive' or h.kind == 'emerge' end
      if not wet then return baseTravel(target, opts) end
      local h = path[1]
      local line = string.format('%s %s (%d,%d) -> %s', h.kind, N.mapName(h.g, h.m), h.x, h.y, N.mapName(h.tg, h.tm))
      L('  water: ' .. line .. string.format(' [%d hops to %s]', #path, target))
      if not takeHop(h) then L('  water: hop failed: ' .. line); F.shot('waterfail'); return false end
      N.waterTrail[#N.waterTrail + 1] = line
      N.settle(opts)
    end
    return F.grp() == tg.g and F.mapn() == tg.m
  end
end
