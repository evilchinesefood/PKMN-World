-- Navigation, dialogue and battle driver for the Johto playthrough.
--
-- Everything here acts through the joypad. Memory is only READ, to decide which button to press:
-- the live map grid (collision, elevation, metatile behaviour), the object events, the warp and
-- connection tables in ROM, the script context, the battle controller and the current message.
-- The one exception is the debug "Give Pokémon" menu, whose numeric spinner value is written
-- straight into its task data instead of being dialled in digit by digit (see N.giveMon).
local P = require('pwsym')
local O = require('pwoff')
local C = require('pwconst')
local MAPS = require('pwmaps')
local CH = require('pwchar')

return function(F, S)
  local N = {}
  local r8, r16, r32, rs16 = F.r8, F.r16, F.r32, F.rs16
  local w16 = F.w16
  local L = F.L

  local MAPNAME = {}
  for name, id in pairs(MAPS) do MAPNAME[id.g * 256 + id.m] = name end
  N.MAPNAME = MAPNAME
  function N.mapName(g, m) return MAPNAME[(g or F.grp()) * 256 + (m or F.mapn())] or '?' end
  function N.here() return N.mapName(), F.pos() end

  -- Directions: game DIR_* order (SOUTH=1, NORTH=2, WEST=3, EAST=4).
  local DX = { 0, 0, -1, 1 }
  local DY = { 1, -1, 0, 0 }
  local KEY = { 'Down', 'Up', 'Left', 'Right' }
  local OPP = { 2, 1, 4, 3 }
  N.KEY, N.DX, N.DY = KEY, DX, DY

  ---------------------------------------------------------------- save data
  function N.flag(id)
    local base, n
    if id >= C.FLAG_JOHTO_BASE and id <= C.FLAG_JOHTO_END then
      base, n = F.sb3() + S.SaveBlock3.johtoFlags, id - C.FLAG_JOHTO_BASE
    elseif C.FLAG_JOHTO_TRAINER_BASE and id >= C.FLAG_JOHTO_TRAINER_BASE and id <= C.FLAG_JOHTO_TRAINER_END then
      base, n = F.sb3() + S.SaveBlock3.johtoTrainerFlags, id - C.FLAG_JOHTO_TRAINER_BASE
    elseif C.FLAG_KANTO_TRAINER_BASE and id >= C.FLAG_KANTO_TRAINER_BASE and id <= C.FLAG_KANTO_TRAINER_END then
      base, n = F.sb3() + S.SaveBlock3.kantoTrainerFlags, id - C.FLAG_KANTO_TRAINER_BASE
    else
      base, n = F.sb1() + O.sb1_flags, id
    end
    return (r8(base + (n >> 3)) & (1 << (n & 7))) ~= 0
  end
  function N.setVar(id, v)
    if id >= 0xA000 then F.w16(F.sb3() + S.SaveBlock3.regionVars + (id - 0xA000) * 2, v)
    else F.w16(F.sb1() + O.sb1_vars + (id - 0x4000) * 2, v) end
  end
  function N.var(id)
    if id >= 0xA000 then return r16(F.sb3() + S.SaveBlock3.regionVars + (id - 0xA000) * 2) end
    return r16(F.sb1() + O.sb1_vars + (id - 0x4000) * 2)
  end
  function N.partyCount() return r8(P.gPartiesCount) end
  function N.partyMon(i)
    local b = P.gParties + i * O.mon_size
    return { hp = r16(b + O.mon_hp), maxHP = r16(b + O.mon_maxHP), level = r8(b + O.mon_level) }
  end
  function N.itemCount(id) return F.itemCount(id) end

  ---------------------------------------------------------------- text
  local function decode(addr, max)
    local t, i = {}, 0
    while i < (max or 400) do
      local b = r8(addr + i)
      if b == 0xFF then break
      elseif b == 0xFE or b == 0xFA or b == 0xFB then t[#t + 1] = ' '
      elseif b == 0xFC then i = i + 1   -- control code + one argument (good enough for logs)
      elseif b == 0xFD then i = i + 1; t[#t + 1] = '{VAR}'
      else t[#t + 1] = CH[b] or '' end
      i = i + 1
    end
    return table.concat(t)
  end
  N.decode = decode
  function N.message() return decode(P.gStringVar4) end

  ---------------------------------------------------------------- state probes
  local function status() return r8(S.sGlobalScriptContextStatus) end
  local function scriptPtr() return r32(S.sGlobalScriptContext + 8) end
  N.scriptPtr = scriptPtr
  local function activeTask(fn)
    for j = 0, 15 do
      local t = S.gTasks + j * 40
      if r8(t + 4) ~= 0 and (r32(t) & ~1) == (fn & ~1) then return t end
    end
  end
  N.activeTask = activeTask
  -- The player's battlers are 0 and (in doubles) 2. N.activeBattler is whichever one is waiting
  -- for input; isCtl checks that battler's controller.
  N.activeBattler = 0
  local INPUT = { 'HandleInputChooseAction', 'HandleInputChooseMove', 'OakOldManHandleInputChooseMove', 'HandleInputChooseTarget',
                  'HandleInputShowEntireFieldTargets', 'HandleInputShowTargets', 'PlayerHandleYesNoInput' }
  local function controller(b) return r32(P.gBattlerControllerFuncs + 4 * (b or N.activeBattler)) & ~1 end
  local function isSym(addr, name)
    for _, a in ipairs(P._all[name] or { P[name] }) do
      if addr == (a & ~1) then return true end
    end
    return false
  end
  local function pickActive()
    for _, b in ipairs({ 0, 2 }) do
      local c = controller(b)
      for _, name in ipairs(INPUT) do
        if isSym(c, name) then N.activeBattler = b; return b end
      end
    end
    N.activeBattler = 0
  end
  local function isCtl(name) return isSym(controller(), name) end
  N.isCtl = isCtl
  local function choosingMove() return isCtl('HandleInputChooseMove') or isCtl('OakOldManHandleInputChooseMove') end
  function N.inBattle() return F.cb2() == (P.BattleMainCB2 & ~1) end
  -- A script left waiting with the player's controls unlocked (e.g. an overworld wild encounter
  -- whose battle never started) does not stop the player, so it does not count as busy.
  local function scriptBusy()
    local st = status()
    -- An incoming Match Call freezes the player with no script running; its "……" page waits for A.
    return st == 0 or (st == 1 and r8(P.sLockFieldControls) ~= 0) or activeTask(P.ExecuteMatchCall) ~= nil
  end
  N.scriptBusy = scriptBusy
  function N.free() return F.ow() and not scriptBusy() and not activeTask(P.Task_HandleYesNoInput)
    and not activeTask(P.Task_HandleMultichoiceInput) end

  local function playerObj()
    local id = r8(P.gPlayerAvatar + O.pa_objectEventId)
    return S.gObjectEvents + id * O.oe_size, id
  end
  function N.elevation() return r8(playerObj() + 0x0B) & 0x0F end
  function N.surfing() return (r8(P.gPlayerAvatar + O.pa_flags) & 8) ~= 0 end

  function N.objects()
    local list = {}
    local _, pid = playerObj()
    for i = 0, 15 do
      local b = S.gObjectEvents + i * O.oe_size
      if (r8(b) & 1) == 1 and i ~= pid then
        local lid = r8(b + O.oe_localId)
        if lid ~= 0xFE and lid ~= 0xFF then
          list[#list + 1] = {
            i = i, localId = lid, gfx = r16(b + O.oe_graphicsId),
            x = rs16(b + O.oe_currentCoords) - 7, y = rs16(b + O.oe_currentCoords + 2) - 7,
            px = rs16(b + O.oe_previousCoords) - 7, py = rs16(b + O.oe_previousCoords + 2) - 7,
            invisible = (r8(b + 1) & 0x20) ~= 0, trainerType = r8(b + O.oe_trainerType),
          }
        end
      end
    end
    return list
  end
  function N.object(localId)
    for _, o in ipairs(N.objects()) do if o.localId == localId then return o end end
  end

  ---------------------------------------------------------------- map grids
  local function behaviorFn(layout)
    local prim, sec = r32(layout + 0x10), r32(layout + 0x14)
    local np = (r8(layout + 0x18) ~= 0 or r8(layout + 0x1B) ~= 0) and 640 or 512
    local cache = {}
    return function(id)
      local b = cache[id]
      if b then return b end
      local ts, idx = prim, id
      if id >= np then ts, idx = sec, id - np end
      if ts == 0 or id >= 1024 then b = 255
      else
        local attrs = r32(ts + 0x10)
        if (r8(ts + 1) & 2) ~= 0 then b = r32(attrs + 4 * idx) & 0x1FF else b = r16(attrs + 2 * idx) & 0xFF end
      end
      cache[id] = b
      return b
    end
  end
  local function surfable(b) return b < 256 and (r8(P.sTileBitAttributes + b) & 2) ~= 0 end
  N.surfable = surfable

  local function liveGrid()
    local vw, vmap = r32(P.gBackupMapLayout), r32(P.gBackupMapLayout + 8)
    local vh = r32(P.gBackupMapLayout + 4)
    local layout = r32(P.gMapHeader)
    local lw, lh = r32(layout), r32(layout + 4)
    return {
      w = lw, h = lh, live = true,
      get = function(x, y)
        -- In-bounds only: the border ring holds the connected maps' tiles, and planning a path
        -- through them crosses into the neighbour mid-route. Edges are left by pushing off them.
        if x < 0 or y < 0 or x >= lw or y >= lh then return nil end
        local mx, my = x + 7, y + 7
        if mx < 0 or my < 0 or mx >= vw or my >= vh then return nil end
        return r16(vmap + 2 * (mx + my * vw))
      end,
      -- The border ring too (the connected map's tiles), for checking across a map edge.
      raw = function(x, y)
        local mx, my = x + 7, y + 7
        if mx < 0 or my < 0 or mx >= vw or my >= vh then return nil end
        return r16(vmap + 2 * (mx + my * vw))
      end,
      beh = behaviorFn(layout),
    }
  end
  N.liveGrid = liveGrid

  local headerCache = {}
  local function header(g, m)
    local k = g * 256 + m
    if headerCache[k] then return headerCache[k] end
    local h = r32(r32(P.gMapGroups + 4 * g) + 4 * m)
    local layout = r32(h)
    local ev = r32(h + 4)
    local info = { g = g, m = m, layout = layout, w = r32(layout), h = r32(layout + 4), warps = {}, conns = {} }
    info.objs = {}
    local no, op = r8(ev), r32(ev + 4)
    for i = 0, no - 1 do
      local a = op + i * O.ote_size
      if r8(a + 3) == 0 then
        info.objs[#info.objs + 1] = { localId = r8(a), gfx = r16(a + 1), x = rs16(a + 4), y = rs16(a + 6),
                                      movement = r8(a + 9), script = r32(a + 0x10), flag = r16(a + 0x14) }
      end
    end
    local nw, wp = r8(ev + 1), r32(ev + 8)
    for i = 0, nw - 1 do
      local a = wp + i * 8
      info.warps[#info.warps + 1] = { x = rs16(a), y = rs16(a + 2), warpId = r8(a + 5), m = r8(a + 6), g = r8(a + 7), idx = i }
    end
    local cp = r32(h + 12)
    if cp ~= 0 then
      local n, arr = r32(cp), r32(cp + 4)
      for i = 0, n - 1 do
        local a = arr + i * 12
        local off = r32(a + 4)
        if off >= 0x80000000 then off = off - 0x100000000 end
        info.conns[#info.conns + 1] = { dir = r8(a), offset = off, g = r8(a + 8), m = r8(a + 9) }
      end
    end
    headerCache[k] = info
    return info
  end
  N.header = header

  -- Grids of maps we have stood on this session, as they were live (setmetatile changes: opened
  -- shutters, revealed stairs). Planning through those maps uses the remembered grid.
  N.mapMemory = {}
  function N.rememberMap()
    local g, m = F.grp(), F.mapn()
    local live = liveGrid()
    local t = {}
    for y = 0, live.h - 1 do
      for x = 0, live.w - 1 do t[x + y * live.w] = live.get(x, y) end
    end
    -- Where objects really stood (scripts move NPCs off their template tiles, e.g. the Tin Tower
    -- guard stepping aside); keep earlier sightings of objects now off camera.
    local prev = N.mapMemory[g * 256 + m]
    local objs = prev and prev.objs or {}
    for _, o in ipairs(N.objects()) do objs[o.localId] = { x = o.x, y = o.y } end
    N.mapMemory[g * 256 + m] = { w = live.w, h = live.h, tiles = t, objs = objs }
  end

  local function staticGrid(info)
    local mem = N.mapMemory[info.g * 256 + info.m]
    if mem and mem.w == info.w and mem.h == info.h then
      return {
        w = mem.w, h = mem.h, live = false,
        get = function(x, y)
          if x < 0 or y < 0 or x >= mem.w or y >= mem.h then return nil end
          return mem.tiles[x + y * mem.w]
        end,
        beh = behaviorFn(info.layout),
      }
    end
    local mp = r32(info.layout + 0x0C)
    local w, h = info.w, info.h
    return {
      w = w, h = h, live = false,
      get = function(x, y)
        if x < 0 or y < 0 or x >= w or y >= h then return nil end
        return r16(mp + 2 * (x + y * w))
      end,
      beh = behaviorFn(info.layout),
    }
  end

  ---------------------------------------------------------------- pathfinding
  local MB = C
  local JUMP = { [1] = MB.MB_JUMP_SOUTH, [2] = MB.MB_JUMP_NORTH, [3] = MB.MB_JUMP_WEST, [4] = MB.MB_JUMP_EAST }
  local function blockedLeaving(b, d)
    if d == 1 then return b == MB.MB_IMPASSABLE_SOUTH or b == MB.MB_IMPASSABLE_SOUTHEAST or b == MB.MB_IMPASSABLE_SOUTHWEST or b == MB.MB_IMPASSABLE_SOUTH_AND_NORTH
    elseif d == 2 then return b == MB.MB_IMPASSABLE_NORTH or b == MB.MB_IMPASSABLE_NORTHEAST or b == MB.MB_IMPASSABLE_NORTHWEST or b == MB.MB_IMPASSABLE_SOUTH_AND_NORTH
    elseif d == 3 then return b == MB.MB_IMPASSABLE_WEST or b == MB.MB_IMPASSABLE_NORTHWEST or b == MB.MB_IMPASSABLE_SOUTHWEST or b == MB.MB_IMPASSABLE_WEST_AND_EAST
    else return b == MB.MB_IMPASSABLE_EAST or b == MB.MB_IMPASSABLE_NORTHEAST or b == MB.MB_IMPASSABLE_SOUTHEAST or b == MB.MB_IMPASSABLE_WEST_AND_EAST end
  end
  local function isIce(b) return b == MB.MB_ICE end
  local CURRENT = {}
  for name, d in pairs({ MB_SOUTHWARD_CURRENT = 1, MB_NORTHWARD_CURRENT = 2, MB_WESTWARD_CURRENT = 3, MB_EASTWARD_CURRENT = 4 }) do
    if MB[name] then CURRENT[MB[name]] = d end
  end
  -- Acro Bike tiles read as open floor but collide unless riding one (CheckAcroBikeCollision).
  local ACRO = {}
  for _, name in ipairs({ 'MB_BUMPY_SLOPE', 'MB_ISOLATED_VERTICAL_RAIL', 'MB_ISOLATED_HORIZONTAL_RAIL',
                          'MB_VERTICAL_RAIL', 'MB_HORIZONTAL_RAIL' }) do
    if MB[name] then ACRO[MB[name]] = true end
  end

  -- FRLG arrow floors: the player spins from tile to tile until a stop tile or a collision.
  local SPIN = {}
  for name, d in pairs({ MB_SPIN_RIGHT = 4, MB_SPIN_LEFT = 3, MB_SPIN_UP = 2, MB_SPIN_DOWN = 1 }) do
    if MB[name] then SPIN[MB[name]] = d end
  end

  N.canSurf, N.canCut, N.canSmash = false, false, false
  -- Cuttable trees and breakable rocks exist as separate Hoenn and FRLG object graphics.
  local CLEARS_CUT = { [C.OBJ_EVENT_GFX_CUTTABLE_TREE] = true, [C.OBJ_EVENT_GFX_CUTTABLE_TREE_FRLG] = true }
  local CLEARS_SMASH = { [C.OBJ_EVENT_GFX_BREAKABLE_ROCK] = true, [C.OBJ_EVENT_GFX_BREAKABLE_ROCK_FRLG] = true }
  -- Item balls that sit in a one-tile corridor are picked up on the way (N.clearItems).
  local CLEARS_ITEM = { [C.OBJ_EVENT_GFX_ITEM_BALL] = true }
  N.run = false   -- hold B while walking once the Running Shoes are owned
  N.canWaterfall = false
  N.canCut, N.canSmash = false, false
  N.canWhirlpool = false
  N.avoid = {}   -- per-plan temporary blocks: "x,y" -> true

  -- One move from (x,y,e,s) in direction d. Returns nx, ny, ne, ns, kind or nil.
  -- kind: 'walk' | 'jump' | 'slide' | 'surf' (start surfing) | 'land' (stop surfing)
  local function stepFrom(grid, occ, x, y, e, s, d, oneStep)
    local cur = grid.get(x, y)
    local curB = cur and grid.beh(cur & 0x3FF) or 0
    if blockedLeaving(curB, d) then return nil end
    local tx, ty = x + DX[d], y + DY[d]
    local v = grid.get(tx, ty)
    if not v then return nil end
    local b = grid.beh(v & 0x3FF)
    if not s and b == JUMP[d] then
      local lx, ly = tx + DX[d], ty + DY[d]
      if occ[lx .. ',' .. ly] then return nil end
      local lv = grid.get(lx, ly)
      if not lv then return nil end
      local le = lv >> 12
      return lx, ly, (le == 15) and e or le, s, 'jump'
    end
    local o = occ[tx .. ',' .. ty]
    if type(o) == 'table' and s and N.canWhirlpool and o.script == P.EventScript_Whirlpool then
      -- A whirlpool (or one of its invisible blockers): A from here slides us three tiles across.
      local lx, ly = x + 3 * DX[d], y + 3 * DY[d]
      local lv = grid.get(lx, ly)
      if lv and (lv & 0x0C00) == 0 and surfable(grid.beh(lv & 0x3FF)) and not occ[lx .. ',' .. ly] then
        return lx, ly, lv >> 12, true, 'whirl'
      end
      return nil
    end
    if type(o) == 'table' and not s and ((CLEARS_CUT[o.gfx] and N.canCut)
        or (CLEARS_SMASH[o.gfx] and N.canSmash) or (CLEARS_ITEM[o.gfx] and N.clearItems)) and not N.avoid[tx .. ',' .. ty] then
      return tx, ty, e, s, 'clear'   -- Cut the tree / smash the rock, then step in
    end
    if occ[tx .. ',' .. ty] or N.avoid[tx .. ',' .. ty] then return nil end
    if N.passGoal and N.passGoal[tx .. ',' .. ty] then return tx, ty, e, s, 'walk' end
    if (v & 0x0C00) ~= 0 then return nil end
    if blockedLeaving(b, OPP[d]) then return nil end
    if ACRO[b] then return nil end
    local te = v >> 12
    local mismatch = e ~= 0 and te ~= 0 and te ~= 15 and te ~= e
    local kind = 'walk'
    if s and b == MB.MB_WATERFALL then
      -- Up a waterfall needs the Waterfall field move and climbs it in one go; down it carries
      -- the surfer to its foot. Either way we end on the first tile past it.
      if d == 2 and not N.canWaterfall then return nil end
      if d ~= 1 and d ~= 2 then return nil end
      local wx, wy = tx, ty
      for _ = 1, 32 do
        local v2 = grid.get(wx + DX[d], wy + DY[d])
        if not v2 or grid.beh(v2 & 0x3FF) ~= MB.MB_WATERFALL then break end
        wx, wy = wx + DX[d], wy + DY[d]
      end
      local ex2, ey2 = wx + DX[d], wy + DY[d]
      local v3 = grid.get(ex2, ey2)
      if not v3 or (v3 & 0x0C00) ~= 0 or occ[ex2 .. ',' .. ey2] then return nil end
      return ex2, ey2, v3 >> 12, true, (d == 2) and 'waterfall' or 'slide'
    end
    if s then
      if surfable(b) then
        if mismatch and te ~= 1 then return nil end
      elseif mismatch then
        -- CanStopSurfing: an elevation step onto a default-elevation (3) tile.
        if te ~= 3 then return nil end
        kind = 'land'
      end
      -- Otherwise a non-water tile at the surfer's own elevation (a waterfall's foot) is ridden over.

    else
      -- Surfing starts only across an elevation step (IsPlayerFacingSurfableFishableWater); a
      -- surfable tile with no step, like a bridge at elevation 15, is simply walked on.
      if surfable(b) and mismatch then
        if not N.canSurf then return nil end
        kind = 'surf'
      elseif mismatch then return nil end
    end
    local ne = (te == 15) and e or te
    local ns = s
    if kind == 'surf' then ns, ne = true, te end
    if kind == 'land' then ns = false end
    if b == MB.MB_MUDDY_SLOPE and not ns then
      -- On foot a muddy slope always slides us south (ForcedMovement_MuddySlope; only a Mach Bike
      -- climbs it), so it cannot be climbed and stepping on it ends at its foot.
      if d == 2 then return nil end
      local sx, sy = tx, ty
      for _ = 1, 32 do
        local v2 = grid.get(sx, sy + 1)
        if not v2 or (v2 & 0x0C00) ~= 0 or occ[sx .. ',' .. (sy + 1)] then break end
        sy = sy + 1
        if grid.beh(v2 & 0x3FF) ~= MB.MB_MUDDY_SLOPE then break end
      end
      return sx, sy, ne, ns, 'slide'
    end
    if ns and CURRENT[b] and not oneStep then
      -- A sea current carries the surfer along it until it ends or something stops it
      -- (ForcedMovement_Pushed*ByCurrent): no steering, so it cannot be ridden upstream. Each
      -- push obeys the same collision rules as a step, so one can end by landing on the shore.
      local cd = CURRENT[b]
      local sx, sy, se, ss = tx, ty, ne, ns
      for _ = 1, 128 do
        local nx2, ny2, ne2, ns2, k2 = stepFrom(grid, occ, sx, sy, se, ss, cd, true)
        if not nx2 or (k2 ~= 'walk' and k2 ~= 'land') then break end
        sx, sy, se, ss = nx2, ny2, ne2, ns2
        cd = CURRENT[grid.beh(grid.get(sx, sy) & 0x3FF)]
        if not ss or not cd then break end
      end
      return sx, sy, se, ss, 'slide'
    end
    if SPIN[b] and not ns then
      local sx, sy, se, sd = tx, ty, ne, SPIN[b]
      for _ = 1, 256 do
        local nx2, ny2 = sx + DX[sd], sy + DY[sd]
        local v2 = grid.get(nx2, ny2)
        if not v2 or (v2 & 0x0C00) ~= 0 or occ[nx2 .. ',' .. ny2] then break end
        local e2 = v2 >> 12
        if se ~= 0 and e2 ~= 0 and e2 ~= 15 and e2 ~= se then break end
        sx, sy = nx2, ny2
        if e2 ~= 15 then se = e2 end
        local b2 = grid.beh(v2 & 0x3FF)
        if b2 == MB.MB_STOP_SPINNING then break end
        if SPIN[b2] then sd = SPIN[b2] end
      end
      return sx, sy, se, ns, 'slide'
    end
    if isIce(b) and not ns then
      -- Slide until the next tile refuses us or a non-ice tile is reached.
      local sx, sy, se = tx, ty, ne
      for _ = 1, 64 do
        local nx2, ny2 = sx + DX[d], sy + DY[d]
        local v2 = grid.get(nx2, ny2)
        if not v2 or (v2 & 0x0C00) ~= 0 or occ[nx2 .. ',' .. ny2] then break end
        local e2 = v2 >> 12
        if se ~= 0 and e2 ~= 0 and e2 ~= 15 and e2 ~= se then break end
        sx, sy = nx2, ny2
        if e2 ~= 15 then se = e2 end
        if not isIce(grid.beh(v2 & 0x3FF)) then break end
      end
      return sx, sy, se, ns, 'slide'
    end
    return tx, ty, ne, ns, kind
  end

  -- Coord-event tiles whose condition currently holds: stepping on one runs its script.
  function N.activeTriggers()
    local t = {}
    local ev = r32(P.gMapHeader + 4)
    local n, arr = r8(ev + 2), r32(ev + 12)
    for i = 0, n - 1 do
      local a = arr + i * 16
      local var, val = r16(a + 6), r16(a + 8)
      if var >= 0x4000 and (var < 0x8000 or var >= 0xA000) and N.var(var) == val then t[rs16(a) .. ',' .. rs16(a + 2)] = { var = var, val = val } end
    end
    return t
  end

  -- Warp-event tiles on the current map (holes and pits look like floor; only the event marks them).
  function N.liveWarps()
    local t = {}
    local ev = r32(P.gMapHeader + 4)
    local n, arr = r8(ev + 1), r32(ev + 8)
    for i = 0, n - 1 do t[rs16(arr + i * 8) .. ',' .. rs16(arr + i * 8 + 2)] = true end
    return t
  end

  -- Movement types that keep an object on its template tile (wanderers are re-planned around live).
  local STATIONARY = {}
  for name, v in pairs(C) do
    if name:match('^MOVEMENT_TYPE_') and (name:find('FACE') or name:find('LOOK') or name:find('NONE')
        or name:find('IN_PLACE') or name:find('BERRY') or name:find('INVISIBLE') or name:find('ROTATE')) then STATIONARY[v] = true end
  end

  local function occupancy(grid)
    local occ = {}
    if grid.live then
      local seen = {}
      local tpl = {}
      for _, t in ipairs(header(F.grp(), F.mapn()).objs) do tpl[t.localId] = t end
      for _, o in ipairs(N.objects()) do
        seen[o.localId] = true
        o.script = tpl[o.localId] and tpl[o.localId].script
        -- Objects with no template are wandering wild Pokemon: walking into one starts its battle
        -- instead of blocking the corridor. Only campaigns that set N.passWild plan through them.
        if tpl[o.localId] or not N.passWild then
          occ[o.x .. ',' .. o.y] = o
          if o.px ~= o.x or o.py ~= o.y then occ[o.px .. ',' .. o.py] = o end
        end
      end
      -- Objects off camera are not spawned yet but will be by the time we get there (they matter
      -- on ice, where they are what stops a slide): block their template tiles too.
      for _, t in ipairs(header(F.grp(), F.mapn()).objs) do
        if not seen[t.localId] and STATIONARY[t.movement] and (t.flag == 0 or not N.flag(t.flag)) then
          local k = t.x .. ',' .. t.y
          occ[k] = occ[k] or t
        end
      end
    end
    return occ
  end

  -- Breadth-first search. goal(x,y,s) -> bool. Returns list of {d, x, y, kind} or nil.
  local function bfs(grid, sx, sy, se, ss, goal, opts)
    opts = opts or {}
    local occ = opts.occ or occupancy(grid)
    if opts.allowObj then for k in pairs(opts.allowObj) do occ[k] = nil end end
    local function key(x, y, s, e) return x .. ',' .. y .. (s and 's' or '') .. ',' .. (e or '') end
    local start = key(sx, sy, ss, se)
    local prev = { [start] = false }
    local q = { { sx, sy, se, ss } }
    local head = 1
    local maxN = opts.max or 20000
    while head <= #q and head < maxN do
      local n = q[head]; head = head + 1
      local x, y, e, s = n[1], n[2], n[3], n[4]
      if goal(x, y, s) and head > 1 then
        local path, k = {}, key(x, y, s, e)
        while prev[k] do
          local p = prev[k]
          table.insert(path, 1, { d = p.d, x = p.x, y = p.y, kind = p.kind })
          k = p.from
        end
        return path
      end
      for d = 1, 4 do
        local nx, ny, ne, ns, kind = stepFrom(grid, occ, x, y, e, s, d)
        if nx then
          local k = key(nx, ny, ns, ne)
          if prev[k] == nil then
            prev[k] = { from = key(x, y, s, e), d = d, x = nx, y = ny, kind = kind }
            q[#q + 1] = { nx, ny, ne, ns }
          end
        end
      end
    end
    if goal(sx, sy, ss) then return {} end
    return nil
  end
  N.bfs = bfs

  ---------------------------------------------------------------- input primitives
  local function press(k, n) F.press(k, n or 2) end
  local function idle(n) F.idle(n) end
  N.press, N.idle = press, idle

  local function waitStill(maxF)
    local lx, ly = F.pos()
    local still = 0
    for _ = 1, (maxF or 240) do
      idle(1)
      local x, y = F.pos()
      if x == lx and y == ly then still = still + 1 else still = 0; lx, ly = x, y end
      if still >= 10 then return end
    end
  end

  -- Hold d until the coordinates change (or give up). Returns true if we moved.
  local function holdUntilMoved(d, maxF)
    local x0, y0 = F.pos()
    local m0, g0 = F.mapn(), F.grp()
    for _ = 1, (maxF or 36) do
      joypad.set({ [KEY[d]] = true, B = N.run and not N.surfing() or nil }); emu.frameadvance()
      local x, y = F.pos()
      if x ~= x0 or y ~= y0 or F.mapn() ~= m0 or F.grp() ~= g0 then return true end
      if not F.ow() then return false end
    end
    return false
  end

  -- One step in direction d, pushing whatever is there (Strength boulders). True if we moved.
  function N.push(d)
    local ok = holdUntilMoved(d, 60)
    waitStill(90)
    if not N.free() then N.settle() end
    return ok
  end

  function N.facing() return r8(playerObj() + 0x18) & 0x0F end
  -- Turn to d without stepping: wait for the current step to end, then tap until the avatar
  -- reports that facing (a tap during a step is swallowed).
  function N.face(d)
    waitStill(40)
    for _ = 1, 6 do
      if N.facing() == d then break end
      for _ = 1, 2 do joypad.set({ [KEY[d]] = true }); emu.frameadvance() end
      idle(8)
    end
    idle(6)
  end

  ---------------------------------------------------------------- battle
  local TYPE = C
  -- Effectiveness of our attacking types against one defending type (only the types we carry).
  local CHART = {
    [TYPE.TYPE_PSYCHIC] = { [TYPE.TYPE_FIGHTING] = 2, [TYPE.TYPE_POISON] = 2, [TYPE.TYPE_PSYCHIC] = 0.5, [TYPE.TYPE_STEEL] = 0.5, [TYPE.TYPE_DARK] = 0 },
    [TYPE.TYPE_FIGHTING] = { [TYPE.TYPE_NORMAL] = 2, [TYPE.TYPE_ICE] = 2, [TYPE.TYPE_ROCK] = 2, [TYPE.TYPE_DARK] = 2, [TYPE.TYPE_STEEL] = 2,
                             [TYPE.TYPE_POISON] = 0.5, [TYPE.TYPE_FLYING] = 0.5, [TYPE.TYPE_PSYCHIC] = 0.5, [TYPE.TYPE_BUG] = 0.5, [TYPE.TYPE_FAIRY] = 0.5, [TYPE.TYPE_GHOST] = 0 },
    [TYPE.TYPE_ICE] = { [TYPE.TYPE_GRASS] = 2, [TYPE.TYPE_GROUND] = 2, [TYPE.TYPE_FLYING] = 2, [TYPE.TYPE_DRAGON] = 2,
                        [TYPE.TYPE_FIRE] = 0.5, [TYPE.TYPE_WATER] = 0.5, [TYPE.TYPE_ICE] = 0.5, [TYPE.TYPE_STEEL] = 0.5 },
    [TYPE.TYPE_FIRE] = { [TYPE.TYPE_GRASS] = 2, [TYPE.TYPE_ICE] = 2, [TYPE.TYPE_BUG] = 2, [TYPE.TYPE_STEEL] = 2,
                         [TYPE.TYPE_FIRE] = 0.5, [TYPE.TYPE_WATER] = 0.5, [TYPE.TYPE_ROCK] = 0.5, [TYPE.TYPE_DRAGON] = 0.5 },
    [TYPE.TYPE_ELECTRIC] = { [TYPE.TYPE_WATER] = 2, [TYPE.TYPE_FLYING] = 2, [TYPE.TYPE_ELECTRIC] = 0.5, [TYPE.TYPE_GRASS] = 0.5,
                             [TYPE.TYPE_DRAGON] = 0.5, [TYPE.TYPE_GROUND] = 0 },
    [TYPE.TYPE_GROUND] = { [TYPE.TYPE_FIRE] = 2, [TYPE.TYPE_ELECTRIC] = 2, [TYPE.TYPE_POISON] = 2, [TYPE.TYPE_ROCK] = 2, [TYPE.TYPE_STEEL] = 2,
                           [TYPE.TYPE_GRASS] = 0.5, [TYPE.TYPE_BUG] = 0.5, [TYPE.TYPE_FLYING] = 0 },
    [TYPE.TYPE_NORMAL] = { [TYPE.TYPE_ROCK] = 0.5, [TYPE.TYPE_STEEL] = 0.5, [TYPE.TYPE_GHOST] = 0 },
    [TYPE.TYPE_DRAGON] = { [TYPE.TYPE_DRAGON] = 2, [TYPE.TYPE_STEEL] = 0.5, [TYPE.TYPE_FAIRY] = 0 },
    [TYPE.TYPE_GHOST] = { [TYPE.TYPE_PSYCHIC] = 2, [TYPE.TYPE_GHOST] = 2, [TYPE.TYPE_DARK] = 0.5, [TYPE.TYPE_NORMAL] = 0 },
  }
  -- Moves the harness knows how to score: id -> {type, power}. Anything else scores 0.
  N.MOVES = {}
  function N.knowMove(id, ty, pow) N.MOVES[id] = { ty = ty, pow = pow } end

  local function bmon(i) return P.gBattleMons + i * O.bm_size end
  function N.battleSnapshot()
    local b0, b1 = bmon(0), bmon(1)
    return { mySpecies = r16(b0), myHP = r16(b0 + O.bm_hp), myMax = r16(b0 + O.bm_maxHP),
             foeSpecies = r16(b1), foeHP = r16(b1 + O.bm_hp), foeLevel = r8(b1 + O.bm_level),
             foeTypes = { r8(b1 + O.bm_types), r8(b1 + O.bm_types + 1), r8(b1 + O.bm_types + 2) } }
  end

  -- Slots the game refused this turn (disabled, Taunt, Torment, Choice lock): skip them.
  N.badSlots = {}
  N.refused = {}
  -- Moves that left the foe's HP unchanged twice this battle (Sucker Punch against a status move,
  -- an immunity the chart doesn't know): keyed by our species, then slot.
  local duds, lastPick = {}, nil
  local function foeState()
    local f1, f3 = bmon(1), bmon(3)
    return r16(f1) * 65536 + r16(f3), r16(f1 + O.bm_hp) + r16(f3 + O.bm_hp)
  end
  local function freshBad()
    local me = r16(bmon(N.activeBattler))
    local b0 = bmon(N.activeBattler)
    local mine, usable = duds[me] or {}, false
    for i = 0, 3 do
      if not mine[i] and r16(b0 + O.bm_moves + 2 * i) ~= 0 and r8(b0 + O.bm_pp + i) > 0 then usable = true end
    end
    -- Every move with PP left is a dud: forget them rather than pick a slot with no PP.
    if not usable then duds[me] = {}; mine = duds[me] end
    local bad = {}
    for slot in pairs(mine) do bad[slot] = true end
    return bad
  end
  local function notePick(slot)
    local foes, hp = foeState()
    lastPick = { me = r16(bmon(N.activeBattler)), battler = N.activeBattler, slot = slot, foes = foes, hp = hp,
      misses = (lastPick and lastPick.slot == slot and lastPick.misses) or 0 }
  end
  local function judgeLastPick()
    local p = lastPick
    if not p or p.battler ~= N.activeBattler or r16(bmon(N.activeBattler)) ~= p.me then return end
    local foes, hp = foeState()
    if foes ~= p.foes then return end
    if hp < p.hp then p.misses = 0; return end
    p.misses = p.misses + 1
    if p.misses >= 2 then
      duds[p.me] = duds[p.me] or {}
      duds[p.me][p.slot] = true
      L(string.format('  slot %d of species %d did no damage twice: not picking it again this battle', p.slot, p.me))
    end
  end
  -- Spread moves that also strike the user's own partner in a double battle.
  local HITS_ALLY = { [C.MOVE_EARTHQUAKE] = true }
  local function bestMoveSlot()
    if N.natural then return N.natural.bestSlot(N.activeBattler, N.badSlots) end
    local b0 = bmon(N.activeBattler)
    local allyUp = (r32(P.gBattleTypeFlags) & C.BATTLE_TYPE_DOUBLE) ~= 0
      and r16(bmon(N.activeBattler ~ 2) + O.bm_hp) > 0
    local foe = bmon(1)
    if r16(foe + O.bm_hp) == 0 and r16(bmon(3) + O.bm_hp) > 0 then foe = bmon(3) end
    local types = { r8(foe + O.bm_types), r8(foe + O.bm_types + 1), r8(foe + O.bm_types + 2) }
    local best, bestScore = 0, -1
    for i = 0, 3 do
      local mv = r16(b0 + O.bm_moves + 2 * i)
      local pp = r8(b0 + O.bm_pp + i)
      if mv ~= 0 and pp > 0 and not N.badSlots[i] and not (N.avoidMoves and N.avoidMoves[mv])
          and not (allyUp and HITS_ALLY[mv]) then
        local info = N.MOVES[mv]
        local score = 1
        if info then
          score = info.pow
          local seen = {}
          for _, t in ipairs(types) do
            if not seen[t] then
              seen[t] = true
              local row = CHART[info.ty]
              local m = row and row[t]
              if m then score = score * m end
            end
          end
        end
        if score > bestScore then best, bestScore = i, score end
      end
    end
    return best
  end

  -- Throw a Poke Ball from the in-battle bag: Bag (top right of the action menu), the balls pocket
  -- (gBagPosition.pocket == 1), the first entry, Use.
  local function useBall()
    press('Up'); idle(4); press('Left'); idle(4); press('Right'); idle(4); press('A'); idle(30)
    for _ = 1, 240 do
      if F.cb2() == (P.CB2_BagMenuRun & ~1) then break end
      idle(1)
    end
    for _ = 1, 8 do
      if r8(P.gBagPosition + 5) == 1 then break end
      press('Right'); idle(24)
    end
    -- The bag ignores keys while it fades in, and a pocket switch ignores A while it animates, so a
    -- fixed pair of A presses could stop at the Use menu every turn. Press A until it is up, then Use.
    local function useMenu() return activeTask(P.Task_ItemContext_SingleRow) or activeTask(P.Task_ItemContext_MultipleRows) end
    for _ = 1, 8 do
      if useMenu() then break end
      press('A'); idle(20)
    end
    press('A'); idle(30)
  end

  N.battles = { trainer = 0, wild = 0, fled = 0 }
  N.battleLog = {}
  local scriptedFlag = false

  local function chooseMove(slot)
    local cur = r8(P.gMoveSelectionCursor + N.activeBattler)
    if (cur & 1) ~= (slot & 1) then press((slot & 1) == 1 and 'Right' or 'Left', 2); idle(6) end
    if (cur & 2) ~= (slot & 2) then press((slot & 2) == 2 and 'Down' or 'Up', 2); idle(6) end
    press('A', 2); idle(30)
  end

  -- Deliberate losses (PW_LOSE, see play.lua). N.throw is { kind = 'trainer' | 'wild' | 'any' |
  -- a TRAINER_ constant name }. Everything after the faint is the game's own code; only getting to
  -- the faint is forced: the party is fainted behind the lead, which drops to 1 HP knowing only Growl.
  local function throwMatches(trainer)
    local kind = N.throw and N.throw.kind
    if not kind then return false end
    if kind == 'any' then return true end
    if kind == 'trainer' then return trainer end
    if kind == 'wild' then return not trainer end
    if kind:sub(1, 8) == 'SPECIES_' then return not trainer and r16(bmon(1)) == assert(C[kind], kind) end
    local wanted = assert(C[kind], kind)
    return trainer and (r16(P.gTrainerBattleParameter + O.tbp_opponentA) == wanted
      or r16(P.gTrainerBattleParameter + O.tbp_opponentB) == wanted)
  end
  local function throwBattle()
    -- A partner's battler indexes its own party, so only our battlers mark party slots.
    local flags = r32(P.gBattleTypeFlags)
    local double = (flags & C.BATTLE_TYPE_DOUBLE) ~= 0
    local partner = (flags & (C.BATTLE_TYPE_MULTI | C.BATTLE_TYPE_INGAME_PARTNER)) ~= 0
    local mine = { [r16(P.gBattlerPartyIndexes)] = true }
    if double and not partner then mine[r16(P.gBattlerPartyIndexes + 4)] = true end
    for i = 0, N.partyCount() - 1 do
      F.w16(P.gParties + i * O.mon_size + O.mon_hp, mine[i] and 1 or 0)
    end
    -- A surviving partner fights on alone and can win, so its side goes down the same way.
    if partner then
      local base, kept = P.gParties + C.B_TRAINER_PARTNER * 6 * O.mon_size, r16(P.gBattlerPartyIndexes + 4)
      for i = 0, 5 do
        local mon = base + i * O.mon_size
        if r16(mon + O.mon_maxHP) ~= 0 then F.w16(mon + O.mon_hp, i == kept and 1 or 0) end
      end
    end
    for _, battler in ipairs(double and { 0, 2 } or { 0 }) do
      local m = bmon(battler)
      F.w16(m + O.bm_hp, 1)
      for i = 0, 3 do F.w16(m + O.bm_moves + 2 * i, C.MOVE_GROWL) end
    end
    -- The party as it went into the battle: Birch's rescue starts with none and hands one over first.
    N.threw = { kind = N.throw.kind, map = N.mapName(), money = N.money(), region = F.grp(),
      activeCampaign = F.r8(F.sb2() + S.SaveBlock2.currentRegion),
      party = N.partyCount(), opponent = r16(P.gTrainerBattleParameter + O.tbp_opponentA) }
    N.throw = nil
    L('  THROWING this battle at ' .. N.threw.map)
  end

  -- Drive one battle to its end. fight=true attacks; otherwise wild battles are fled.
  function N.battle(opts)
    opts = opts or {}
    local trainer = (r32(P.gBattleTypeFlags) & C.BATTLE_TYPE_TRAINER) ~= 0
    -- A battle started by a script (a static encounter) leaves the script context waiting
    -- underneath it; a random encounter starts with no script running.
    local scripted = status() ~= 2
    local fight = trainer or opts.fight or scripted
    local snap = N.battleSnapshot()
    local tag = string.format('%s %s foe=%d L%d at %s', trainer and 'TRAINER' or 'WILD', fight and 'fight' or 'flee',
      snap.foeSpecies, snap.foeLevel, N.mapName())
    if trainer then N.battles.trainer = N.battles.trainer + 1 else N.battles.wild = N.battles.wild + 1 end
    local turns, frames = 0, 0
    N.fleeTries = 0
    N.pickerTries = 0   -- its A and Start alternate, so a second picker has to start the cycle afresh
    if N.natural then N.natural.battleStart() end
    duds, lastPick = {}, nil
    -- A natural Elite Four battle with weather and Potions runs well past the debug team's battles.
    local frameLimit = 60 * 60 * (N.natural and 40 or 12)
    while frames < frameLimit do
      if N.natural then N.natural.trace() end
      if F.cb2() ~= (P.CB2_UpdatePartyMenu & ~1) then N.menuRefused = nil end   -- refusals are per menu visit
      if F.cb2() == (P.CB2_UpdatePartyMenu & ~1) then
        -- In-battle party screen: send out the first member TrySwitchInPokemon would accept.
        -- The menu shows the party in battle order (UpdatePartyToBattleOrder), and
        -- gBattlerPartyIndexes holds field order, so each menu slot goes through
        -- gBattlePartyCurrentOrder. A partner's battler indexes a different party.
        local flags = r32(P.gBattleTypeFlags)
        local partner = (flags & (C.BATTLE_TYPE_MULTI | C.BATTLE_TYPE_INGAME_PARTNER)) ~= 0
        local taken = { [r16(P.gBattlerPartyIndexes)] = true }
        if (flags & C.BATTLE_TYPE_DOUBLE) ~= 0 and not partner then taken[r16(P.gBattlerPartyIndexes + 4)] = true end
        -- Both battlers fainted: the first replacement is reserved but not in battle yet.
        if not partner then taken[r8(r32(P.gBattleStruct) + O.bs_prevSelectedPartySlot)] = true end
        -- A member the menu keeps refusing ("A is already in battle") is not asked for again this visit.
        local refused = N.menuRefused or {}
        local function open(i)
          local order = r8(P.gBattlePartyCurrentOrder + (i // 2))
          local fieldId = (i % 2 == 1) and (order & 0xF) or (order >> 4)
          return not taken[fieldId] and (refused[i] or 0) < 2
        end
        local target
        for i = 0, N.partyCount() - 1 do
          local pm = N.partyMon(i)
          if pm.hp > 0 and pm.level > 0 and open(i) and not target then target = i end
        end
        if N.natural and not partner then target = N.natural.pickSendOut(open) or target end
        -- Refusals only steer the choice: a forced send-out can't be backed out of, so with every member
        -- refused, ask again for the first one not on the field rather than pressing B forever.
        if not target and next(refused) then
          refused = {}
          for i = 0, N.partyCount() - 1 do
            local pm = N.partyMon(i)
            if pm.hp > 0 and pm.level > 0 and open(i) and not target then target = i end
          end
          N.menuRefused = nil
        end
        -- A voluntary switch the game refuses (trapped, or Shadow Tag): only B leaves.
        local action = r8(P.gPartyMenu + 11)   -- PartyMenu.action
        if action == 2 or action == 4 then target = nil end   -- PARTY_ACTION_CANT_SWITCH, _ABILITY_PREVENTS
        if target then
          for _ = 1, 8 do
            if r8(P.gPartyMenu + 9) == target then break end
            press('Down'); idle(10)
          end
          if r8(P.gPartyMenu + 9) ~= target then
            -- The cursor would not move: a refusal message is still up and swallows the keys, and an A
            -- would only pick the slot under the cursor again. B dismisses the message; try again.
            L('  party menu: cursor stuck at ' .. r8(P.gPartyMenu + 9) .. ', wanted ' .. target .. '; dismissing')
            press('B'); idle(30)
          else
            L('  party menu: sending out slot ' .. target)
            N.menuRefused = N.menuRefused or {}
            N.menuRefused[target] = (N.menuRefused[target] or 0) + 1
            press('A'); idle(20); press('A'); idle(40)
          end
        else
          L('  party menu: no member to send, B (action ' .. action .. ')')
          press('B'); idle(30)
        end
        frames = frames + 80
      elseif (pickActive() or true) and not N.inBattle() then
        -- A battle can be followed by evolution, a Pokédex entry or a nickname prompt.
        if F.ow() then break end
        if N.natural and N.natural.menu() then
          -- handled: an evolution's learn-move prompt or the forget-a-move screen
        elseif F.cb2() == (P.CB2_NamingScreen & ~1) then press('Start'); idle(20); press('A'); idle(40)
        elseif frames % 600 > 480 and not N.acceptPrompts then press('B'); idle(10)   -- back out of a summary screen opened by mistake
        else press('A'); idle(10) end
        frames = frames + 12
      elseif isCtl('HandleInputChooseAction') then
        turns = turns + 1
        if turns == 1 then N.firstFoeLevel = r8(bmon(1) + O.bm_level) end
        if turns > 200 then error('battle runaway: ' .. tag) end
        judgeLastPick()
        N.badSlots = freshBad()
        N.refused = {}
        N.lastFoe = { species = r16(bmon(1)), level = r8(bmon(1) + O.bm_level) }
        if N.battleDebug then
          local me, f1, f3 = bmon(N.activeBattler), bmon(1), bmon(3)
          L(string.format('    turn %d battler %d: me %d hp %d | foe1 %d hp %d | foe3 %d hp %d | slot %d',
            turns, N.activeBattler, r16(me), r16(me + O.bm_hp), r16(f1), r16(f1 + O.bm_hp), r16(f3), r16(f3 + O.bm_hp), bestMoveSlot()))
          if turns <= 12 then F.shot('turn' .. turns) end
        end
        if throwMatches(trainer) then throwBattle(); fight = true end
        -- Evaluated per turn: at the battle's first instant the foe's data isn't loaded yet.
        if N.foeHook then N.foeHook(r16(bmon(1)), r8(bmon(1) + O.bm_level), trainer) end
        if N.fightWanted and N.fightWanted(r16(bmon(1))) then fight = true end
        local catching = not trainer and N.catchWanted and N.catchWanted(r16(bmon(1))) and (N.catchBall and N.itemCount(N.catchBall) > 0 or not N.catchBall and N.itemQty(C.ITEM_POKE_BALL) + N.itemQty(C.ITEM_GREAT_BALL) > 0)
        -- A foe with Arena Trap or Shadow Tag can't be fled: after two failed tries, fight it.
        if not fight and not catching then
          N.fleeTries = (N.fleeTries or 0) + 1
          if N.fleeTries > 2 then fight = true; L('  flee failed twice, fighting') end
        end
        if fight and not catching and N.natural and N.natural.turn(trainer) then
          frames = frames + 60
        elseif catching then
          useBall()
        elseif fight then
          press('Up'); idle(4); press('Left'); idle(4); press('A'); idle(20)
          for _ = 1, 30 do if choosingMove() then break end; idle(2) end
          if choosingMove() then N.lastSlot = bestMoveSlot(); notePick(N.lastSlot); chooseMove(N.lastSlot) end
        else
          press('Down'); idle(4); press('Right'); idle(4); press('A'); idle(30)
        end
        frames = frames + 60
      elseif choosingMove() then
        -- Back at the move list without a new turn: the last pick was refused.
        if N.lastSlot then N.badSlots[N.lastSlot] = true; N.refused[N.lastSlot] = true end
        -- Encore or a Choice lock can force the one move already written off as a dud; once every
        -- other slot is refused, the duds go back on the table.
        local b0, open = bmon(N.activeBattler), false
        for i = 0, 3 do
          if r16(b0 + O.bm_moves + 2 * i) ~= 0 and r8(b0 + O.bm_pp + i) > 0 and not N.badSlots[i] then open = true end
        end
        if not open then
          N.badSlots = {}
          for slot in pairs(N.refused) do N.badSlots[slot] = true end
        end
        N.lastSlot = bestMoveSlot(); notePick(N.lastSlot); chooseMove(N.lastSlot); frames = frames + 40
      elseif isCtl('HandleInputChooseTarget') or isCtl('HandleInputShowEntireFieldTargets') or isCtl('HandleInputShowTargets') then
        press('A'); idle(20); frames = frames + 22
      elseif isCtl('PlayerHandleYesNoInput') then
        -- "Will you switch POKéMON?" -- no.
        press('B'); idle(20); frames = frames + 22
      elseif N.natural and N.natural.battleText() then
        frames = frames + 30
      else
        -- Battle text and the script's own Yes/No boxes ("Will you change POKéMON?", "Stop
        -- learning?"): B advances text and answers No. A B that lands on the action menu arms the
        -- run shortcut, which Instant text makes likely, so a battle meant to be fought advances with A.
        press((N.natural or fight) and 'A' or 'B'); idle(8); frames = frames + 10
      end
    end
    local outcome = r8(S.gBattleOutcome)
    if N.threw and N.threw.outcome == nil then N.threw.outcome = outcome end
    if N.inBattle() then
      error(string.format('battle did not finish: %s ctl%d=%08x cb2=%08x turns=%d msg=%q', tag, N.activeBattler, controller(), F.cb2(), turns, N.message()))
    end
    if turns == 0 or outcome == 0 then
      L(string.format('  battle exit: cb2=%08x inBattle=%s ow=%s ctl0=%08x ctl2=%08x frames=%d', F.cb2(),
        tostring(N.inBattle()), tostring(F.ow()), controller(0), controller(2), frames))
    end
    local after = N.partyMon(0)
    L(string.format('  battle %s -> outcome=%d turns=%d lead hp=%d/%d', tag, outcome, turns, after.hp, after.maxHP))
    N.battleLog[#N.battleLog + 1] = { tag = tag, outcome = outcome }
    if N.natural then N.natural.battleEnd(trainer, outcome) end
    if trainer or after.hp * 5 < after.maxHP * 3 then N.needHeal = true end
    scriptedFlag = false
    return outcome
  end

  ---------------------------------------------------------------- dialogue
  N.transcript = {}
  local lastMsg = ''
  local function noteMessage()
    local m = N.message()
    if m ~= lastMsg and m ~= '' then
      lastMsg = m
      N.transcript[#N.transcript + 1] = N.mapName() .. ': ' .. m
      L('    msg: ' .. m)
    end
    return m
  end
  N.noteMessage = noteMessage

  -- policy(text, kind) -> 'yes' | 'no' | <0-based multichoice index>. Default: yes / first option.
  N.defaultPolicy = function(text, kind)
    local t = text:lower()
    if kind == 'yesno' then
      if t:find('nickname') then return 'no' end
      if t:find('save the game') or t:find('want to save') or t:find('like to save') then return 'no' end
      return 'yes'
    end
    return 0
  end

  local function answerYesNo(ans)
    -- Task_HandleYesNoInput: cursor starts on YES.
    if ans == 'no' then press('B'); idle(30) else press('A'); idle(30) end
  end
  local function answerMulti(idx)
    for _ = 1, 12 do
      local cur = r8(S.sMenu + 2)
      if cur == idx then break end
      press(cur < idx and 'Down' or 'Up'); idle(10)
    end
    press('A'); idle(30)
  end

  -- Advance whatever is happening until the player is free again.
  function N.settle(opts)
    opts = opts or {}
    local policy = opts.policy or N.defaultPolicy
    local freeFor, frames = 0, 0
    local limit = opts.limit or 60 * 60 * 6
    while frames < limit do
      if N.settleHook then N.settleHook() end
      if F.reportCrash and frames % 600 == 0 and F.ow() == false and not N.inBattle() then
        if F.reportCrash('settle') then error('crash screen during settle at ' .. N.mapName()) end
      end
      if N.inBattle() then
        N.battle(opts); freeFor = 0
      elseif F.ow() and scriptBusy() and not activeTask(P.Task_HandleYesNoInput)
          and not activeTask(P.Task_HandleMultichoiceInput) then
        -- A script is running with no menu up: advance its text.
        noteMessage()
        press('A', 2); idle(16); frames = frames + 18; freeFor = 0
        -- Scripted wild battles start from here; remember that so we fight instead of fleeing.
        scriptedFlag = true
      elseif activeTask(P.Task_HandleYesNoInput) then
        idle(20)
        local m = noteMessage()
        local ans = policy(m, 'yesno')
        L('    yes/no -> ' .. tostring(ans))
        answerYesNo(ans); frames = frames + 60; freeFor = 0
      elseif activeTask(P.Task_HandleMultichoiceInput) then
        idle(20)
        local m = noteMessage()
        local ans = policy(m, 'multi')
        if type(ans) ~= 'number' then ans = 0 end
        L('    multichoice -> ' .. ans)
        answerMulti(ans); frames = frames + 60; freeFor = 0
      elseif F.cb2() == (P.CB2_NamingScreen & ~1) then
        press('Start'); idle(20); press('A'); idle(60); frames = frames + 80; freeFor = 0
      elseif F.cb2() == (P.CB2_UpdatePartyMenu & ~1) and not N.noPicker then
        -- A script opened the party (Lance's "choose your POKéMON" before the hideout multi
        -- battle). This SwSh-style picker marks a member with A and confirms with Start.
        idle(30)
        local tries = (N.pickerTries or 0) + 1
        N.pickerTries = tries
        if N.natural then N.natural.picker(tries)
        elseif tries % 2 == 1 then press('A'); idle(30) end
        press('Start'); idle(60)
        L('  party picker: A + Start (try ' .. tries .. ')')
        frames = frames + 120; freeFor = 0
      elseif F.cb2() == (P.CB2_WallClock & ~1) then
        -- Accept the shown time; its own Yes/No opens on No, so Up first.
        press('Up'); idle(6); press('A'); idle(30); frames = frames + 36; freeFor = 0
      elseif N.screen and N.screen() then
        -- A campaign-specific full-screen menu (Hoenn's POKéNAV tutorial) took a step.
        frames = frames + 60; freeFor = 0
      elseif not F.ow() or activeTask(P.Task_RushInjuredPokemonToCenter) then
        -- The second case is the whiteout's "scurried back" page, which waits for A with no script.
        press('A'); idle(10); frames = frames + 12; freeFor = 0
      else
        idle(2); frames = frames + 2
        freeFor = freeFor + 2
        if freeFor >= (opts.quiet or 24) and (not N.threw or N.free()) then
          scriptedFlag = false
          if N.natural and N.natural.takeWhiteout() then N.needHeal = false; error(N.WHITEOUT, 0) end
          if N.threw then N.needHeal = false; error(N.LOSS_PLAYED, 0) end
          -- Restore HP and PP after trainer battles (debug heal; a documented concession).
          if N.needHeal and not opts.noHeal then N.needHeal = false; N.debugHeal() end
          return true
        end
      end
    end
    N.reportCallbacks()
    L('  settle TIMEOUT at ' .. N.mapName() .. string.format(' (%d,%d) status=%d script=%08x', F.pos(), select(2, F.pos()), status(), scriptPtr()))
    F.shot('settle_timeout')
    return false
  end

  -- Names the running callbacks and tasks, so a hang says which screen it is on.
  function N.reportCallbacks()
    local function name(addr)
      addr = addr & ~1
      for k, v in pairs(P) do if type(v) == 'number' and (v & ~1) == addr then return k end end
      return string.format('%08x', addr)
    end
    local tasks = {}
    for i = 0, 15 do
      local t = P.gTasks + i * 40
      if F.r8(t + 4) ~= 0 then tasks[#tasks + 1] = name(F.r32(t)) end
    end
    L('  callbacks: cb1=' .. name(F.r32(P.gMain)) .. ' cb2=' .. name(F.r32(P.gMain + 4)) .. ' tasks=' .. table.concat(tasks, ','))
    if N.natural and client.readRegister then
      -- Name where the CPU is, sampled over frames: a hang inside one callback shows up as one place.
      local list = {}
      for k, v in pairs(P) do if type(v) == 'number' then list[#list + 1] = { v & ~1, k } end end
      table.sort(list, function(a, b) return a[1] < b[1] end)
      local function nearest(pc)
        local lo, hi = 1, #list
        while lo < hi do
          local mid = (lo + hi + 1) // 2
          if list[mid][1] <= pc then lo = mid else hi = mid - 1 end
        end
        return string.format('%s+0x%x', list[lo][2], pc - list[lo][1])
      end
      local seen = {}
      for _ = 1, 24 do
        idle(7)
        local at = nearest(client.readRegister('pc') & ~1)
        seen[at] = (seen[at] or 0) + 1
      end
      for at, n in pairs(seen) do L('  cpu at ' .. at .. ' x' .. n) end
      L('  lr: ' .. nearest(client.readRegister('lr') & ~1))
      -- The assert trapped through an SWI, so sp is the BIOS stack; the user stack is still in IWRAM.
      for a = 0x03007600, 0x03007FFC, 4 do
        local w = F.r32(a)
        if w >= 0x08000000 and w < 0x0a000000 and w % 2 == 1 then L(string.format('  stack %08x: %s', a, nearest(w & ~1))) end
      end
    end
    if N.natural then
      L(string.format('  field callbacks: gFieldCallback=%s gFieldCallback2=%s state=%d', name(F.r32(P.gFieldCallback)), name(F.r32(P.gFieldCallback2)), F.r8(P.gMain + 0x439)))
    end
  end

  ---------------------------------------------------------------- walking
  N.steps = 0
  local function stuckReport(tag)
    local x, y = F.pos()
    L(string.format('  STUCK %s at %s (%d,%d) elev=%d surf=%s', tag, N.mapName(), x, y, N.elevation(), tostring(N.surfing())))
  end

  -- Execute one planned edge. Returns 'ok', 'moved-elsewhere', 'blocked' or 'event'.
  local function doEdge(e)
    local x0, y0 = F.pos()
    local m0, g0 = F.mapn(), F.grp()
    if e.kind == 'surf' then
      N.face(e.d)
      press('A'); idle(30)
      N.settle({ policy = function(t, k) if k == 'yesno' then return 'yes' end return 0 end })
      waitStill(120)
    elseif e.kind == 'waterfall' then
      N.face(e.d)
      press('A'); idle(30)
      N.settle({ policy = function(t, k) if k == 'yesno' then return 'yes' end return 0 end })
      waitStill(240)
    elseif e.kind == 'whirl' then
      N.face(e.d); press('A'); idle(30)
      N.settle({ policy = function(t, k) if k == 'yesno' then return 'yes' end return 0 end })
      waitStill(200); idle(180)   -- an early d-pad press re-triggers the slide (JohtoWhirlpool.lua)
    elseif e.kind == 'clear' then
      N.face(e.d); press('A'); idle(30)
      N.settle({ policy = function(t, k) if k == 'yesno' then return 'yes' end return 0 end })
      waitStill(60)
      -- A follower that does the field move first swaps places with us (EventScript_FollowerFieldMove),
      -- so we may no longer stand beside the cleared tile. Stepping e.d from there walks somewhere else
      -- (with Strength on, into a boulder). Re-plan from where the swap left us.
      local cx, cy = F.pos()
      if cx ~= x0 or cy ~= y0 then return 'moved-elsewhere' end
      if not holdUntilMoved(e.d, 40) then return 'blocked' end
      waitStill(30)
    elseif e.kind == 'interact' then
      N.face(e.d); press('A'); idle(30)
      N.settle({ policy = function(t, k) if k == 'yesno' then return 'yes' end return 0 end })
      waitStill(60)
      return 'ok'
    else
      if not holdUntilMoved(e.d, e.kind == 'land' and 60 or 36) then
        if not N.free() then return 'event' end
        return 'blocked'
      end
      N.steps = N.steps + 1
      if e.kind == 'jump' or e.kind == 'slide' or e.kind == 'land' then
        waitStill(240)
      else
        -- Keep holding through the rest of the tile so walking stays continuous.
        for _ = 1, 3 do joypad.set({ [KEY[e.d]] = true, B = N.run or nil }); emu.frameadvance() end
      end
    end
    if F.mapn() ~= m0 or F.grp() ~= g0 then return 'warped' end
    if not F.ow() or scriptBusy() then return 'event' end
    local x, y = F.pos()
    if x == e.x and y == e.y then return 'ok' end
    if x == x0 and y == y0 then return 'blocked' end
    return 'moved-elsewhere'
  end

  -- Walk until goal(x,y,surfing) holds on the current map. Returns true/false, and 'warped' if
  -- the map changed underneath us (doors, triggers that warp).
  function N.walk(goal, opts)
    opts = opts or {}
    N.avoid = {}
    local tag = opts.tag or 'walk'
    local noPath = 0
    for attempt = 1, (opts.attempts or 60) do
      if not N.free() then N.settle(opts) end
      local x, y = F.pos()
      if goal(x, y, N.surfing()) then idle(4); return true end
      local m0, g0 = F.mapn(), F.grp()
      local grid = liveGrid()
      -- Mid surf-mount/dismount the avatar flag and the tile disagree; let the animation finish.
      for _ = 1, 20 do
        local v = grid.get(F.pos())
        if not v or N.surfing() == surfable(grid.beh(v & 0x3FF)) then break end
        idle(6)
      end
      local path
      -- Fifteen waits have not cleared the way: plan through wild Pokemon. A wanderer leashed
      -- inside a one-tile corridor never leaves while we stand still (the camera does not move, so
      -- it never despawns either); walking into it starts a battle, which despawns it (DespawnOWEOnBattleStart).
      local passWild0 = N.passWild
      if noPath > 15 then N.passWild = true end
      if not opts.allowTriggers then
        local occ = occupancy(grid)
        for k in pairs(N.liveWarps()) do
          local tx, ty = k:match('(-?%d+),(-?%d+)')
          if not goal(tonumber(tx), tonumber(ty), false) then occ[k] = occ[k] or true end
        end
        for k in pairs(N.activeTriggers()) do
          local tx, ty = k:match('(-?%d+),(-?%d+)')
          if not goal(tonumber(tx), tonumber(ty), false) then occ[k] = occ[k] or true end
        end
        path = bfs(grid, x, y, N.elevation(), N.surfing(), goal, { occ = occ, allowObj = opts.allowObj })
      end
      -- strictTriggers: never fall back to a path over a live trigger (puzzle switches).
      if not path and not opts.strictTriggers then path = bfs(grid, x, y, N.elevation(), N.surfing(), goal, opts) end
      N.passWild = passWild0
      if not path then
        -- A resumable assertf crash screen keeps the overworld callback, so it looks like a wall.
        if F.reportCrash and F.reportCrash('walk') then error('crash screen during walk at ' .. N.mapName()) end
        stuckReport(tag .. ' no-path')
        local objs = {}
        for _, o in ipairs(N.objects()) do objs[#objs + 1] = string.format('%d@(%d,%d)', o.localId, o.x, o.y) end
        L('    objects: ' .. table.concat(objs, ' '))
        noPath = noPath + 1
        if noPath <= 15 then
          -- A wandering Pokémon or NPC may be standing in a corridor; wait for it to move, then
          -- forget temporary blocks. (Counted apart from attempts: battles on the way use those.)
          idle(120); N.avoid = {}
        elseif noPath > 16 or passWild0 then
          return false
        else
          N.avoid = {}   -- one more plan, through wild Pokemon
        end
      else
        for i, e in ipairs(path) do
          local r = doEdge(e)
          if r == 'warped' then
            if opts.allowWarp then idle(10); waitStill(60); return true, 'warped' end
            N.settle(opts); idle(30)
            if F.mapn() ~= m0 or F.grp() ~= g0 then return false, 'warped' end
            break
          elseif r == 'event' then
            N.settle(opts)
            if F.mapn() ~= m0 or F.grp() ~= g0 then
              if opts.allowWarp then return true, 'warped' end
              return false, 'warped'
            end
            break
          elseif r == 'blocked' then
            N.avoid[e.x .. ',' .. e.y] = true
            idle(20)
            break
          elseif r == 'moved-elsewhere' then
            break
          end
        end
      end
    end
    local x, y = F.pos()
    stuckReport(tag .. ' attempts')
    return goal(x, y, N.surfing())
  end

  function N.go(tx, ty, opts)
    opts = opts or {}
    opts.tag = opts.tag or string.format('goto(%d,%d)', tx, ty)
    return N.walk(function(x, y) return x == tx and y == ty end, opts)
  end

  -- Stand next to (tx,ty) and face it. side: optional DIR the player must stand on (1=below...).
  function N.approach(tx, ty, opts)
    opts = opts or {}
    local sides = opts.side and { opts.side } or { 1, 2, 3, 4 }
    local goals = {}
    for _, sd in ipairs(sides) do
      -- standing tile = target + offset in direction sd (1 = south of target)
      goals[(tx + DX[sd]) .. ',' .. (ty + DY[sd])] = OPP[sd]
    end
    opts.tag = opts.tag or string.format('approach(%d,%d)', tx, ty)
    local ok = N.walk(function(x, y) return goals[x .. ',' .. y] ~= nil end, opts)
    if not ok then return false end
    local x, y = F.pos()
    local d = goals[x .. ',' .. y]
    N.face(d)
    return true
  end

  -- Talk to an object by local id (live position) or to a fixed tile.
  function N.talk(target, opts)
    opts = opts or {}
    local tx, ty
    if type(target) == 'table' then tx, ty = target[1], target[2]
    else
      local o = N.object(target)
      if not o then
        -- Objects only spawn near the camera: walk toward the template position, then look again.
        for _, t in ipairs(header(F.grp(), F.mapn()).objs) do
          if t.localId == target then
            if not N.walk(function(x, y) return math.abs(x - t.x) + math.abs(y - t.y) <= 4 end, { tag = 'near obj ' .. target }) then
              N.approach(t.x, t.y, opts)   -- e.g. ice, where only some tiles near it are stopping places
            end
            break
          end
        end
        o = N.object(target)
      end
      if not o then L('  talk: object ' .. tostring(target) .. ' not present on ' .. N.mapName()); return false end
      tx, ty = o.x, o.y
    end
    for _ = 1, 12 do
      if not N.approach(tx, ty, opts) then
        L(string.format('  talk: cannot reach a side of (%d,%d)', tx, ty))
        return false
      end
      -- A patrolling object may have moved on while we walked: chase it rather than talk to air.
      if type(target) ~= 'table' then
        local o = N.object(target)
        if not o then return false end
        local px, py = F.pos()
        local fd = N.facing()
        if o.x ~= px + DX[fd] or o.y ~= py + DY[fd] then
          L(string.format('  talk: %d moved to (%d,%d); we are at (%d,%d) facing %d', target, o.x, o.y, px, py, fd))
          tx, ty = o.x, o.y
          goto continue
        end
      end
      w16(S.gSpecialVar_LastTalked, 0)
      press('A'); idle(20)
      if not N.free() then
        local who = r16(S.gSpecialVar_LastTalked)
        N.settle(opts)
        -- Only count it if this object's script ran (not the follower, a sign, or a passer-by).
        if type(target) == 'table' or who == target then return true end
        L(string.format('  talk: reached object %d instead of %d; retrying', who, target))
      end
      -- The NPC walked off between planning and pressing A: re-read and retry.
      if type(target) ~= 'table' then
        local o = N.object(target)
        if not o then return false end
        tx, ty = o.x, o.y
      end
      ::continue::
    end
    return false
  end

  -- Talk to an object that keeps moving (the red Gyarados roams the whole lake): re-plan one
  -- step at a time toward it and press A the moment it is beside us.
  function N.chase(target, opts)
    opts = opts or {}
    for _ = 1, 600 do
      if not N.free() then N.settle(opts) end
      local o = N.object(target)
      if not o then
        for _, t in ipairs(header(F.grp(), F.mapn()).objs) do
          if t.localId == target then N.go(t.x, t.y + 3, opts) end
        end
        o = N.object(target)
        if not o then return false end
      end
      local x, y = F.pos()
      for d = 1, 4 do
        if x + DX[d] == o.x and y + DY[d] == o.y then
          N.face(d)
          w16(S.gSpecialVar_LastTalked, 0)
          press('A'); idle(20)
          if not N.free() then
            local who = r16(S.gSpecialVar_LastTalked)
            N.settle(opts)
            if who == target then return true end
          end
        end
      end
      local goals = {}
      for d = 1, 4 do goals[(o.x + DX[d]) .. ',' .. (o.y + DY[d])] = true end
      local path = bfs(liveGrid(), x, y, N.elevation(), N.surfing(), function(px, py) return goals[px .. ',' .. py] end, {})
      if path and path[1] then doEdge(path[1]) else idle(20) end
    end
    return false
  end

  -- Talk to an object that walks a fixed loop: watch it every few frames, and the moment it is
  -- beside us turn to it and press A; otherwise take one planned step toward it.
  function N.intercept(target, opts)
    opts = opts or {}
    for i = 1, 3000 do
      if not N.free() then N.settle(opts) end
      local o = N.object(target)
      if not o then return false end
      local x, y = F.pos()
      local hit
      for d = 1, 4 do if x + DX[d] == o.x and y + DY[d] == o.y then hit = d end end
      if hit then
        if N.facing() ~= hit then press(KEY[hit], 1); idle(2) end
        w16(S.gSpecialVar_LastTalked, 0)
        press('A'); idle(20)
        if not N.free() then
          local who = r16(S.gSpecialVar_LastTalked)
          N.settle(opts)
          if who == target then return true end
        end
      elseif i % 15 == 0 then
        local goals = {}
        for d = 1, 4 do goals[(o.x + DX[d]) .. ',' .. (o.y + DY[d])] = true end
        local path = bfs(liveGrid(), x, y, N.elevation(), N.surfing(), function(px, py) return goals[px .. ',' .. py] end, {})
        if path and path[1] then doEdge(path[1]) end
      else
        idle(2)
      end
    end
    return false
  end

  -- Stand on (x,y), face d and press A (counters, signs, objects behind desks).
  function N.talkFrom(x, y, d, opts)
    opts = opts or {}
    if not N.go(x, y, opts) then return false end
    N.face(d); press('A'); idle(20)
    N.settle(opts)
    return true
  end

  ---------------------------------------------------------------- cross-map travel
  -- Static reachability inside one map from (sx,sy). goal(x,y) picks the target tile(s); returns
  -- the reached tile or nil. passGoal lets the goal tile itself read solid (doors in walls).
  local reachCache = {}
  local function staticReach(info, sx, sy, key, goal, surf, passGoal)
    local k = string.format('%d:%d:%d:%d:%s:%s:%s', info.g, info.m, sx, sy, key, tostring(surf), tostring(N.planIgnoreObjects))
    local c = reachCache[k]
    if c ~= nil then return c or nil end
    local grid = staticGrid(info)
    local v = grid.get(sx, sy)
    local e = v and (v >> 12) or 0
    if e == 15 then e = 0 end
    local saved, savedPass = N.canSurf, N.passGoal
    N.canSurf, N.passGoal = surf, passGoal
    -- Objects that are currently shown block their template tile (sages, guards, scenery).
    local occ = {}
    local mem = N.mapMemory[info.g * 256 + info.m]
    for _, o in ipairs(N.planIgnoreObjects and {} or info.objs) do
      local clearable = (CLEARS_CUT[o.gfx] and N.canCut) or (CLEARS_SMASH[o.gfx] and N.canSmash)
        or (CLEARS_ITEM[o.gfx] and N.clearItems)
      if (o.flag == 0 or not N.flag(o.flag)) and not clearable then
        local at = mem and mem.objs and mem.objs[o.localId] or o
        occ[at.x .. ',' .. at.y] = (o.script == P.EventScript_Whirlpool) and o or true
      end
    end
    local path = bfs(grid, sx, sy, e, false, function(x, y) return goal(x, y) end, { occ = occ, max = 12000 })
    N.canSurf, N.passGoal = saved, savedPass
    local res = false
    if path then
      local last = path[#path]
      res = last and { x = last.x, y = last.y } or { x = sx, y = sy }
    end
    reachCache[k] = res
    return res or nil
  end

  local WARPB = {}
  for name, v in pairs(C) do
    if name:match('^MB_') and (name:find('_DOOR$') or name:find('WARP') or name:find('LADDER') or name:find('ESCALATOR')
        or name:find('HOLE')) then WARPB[v] = true end
  end
  N.WARPB = WARPB

  -- Map groups the planner may route through: Johto by default; a campaign sets its own region.
  N.region = { lo = 75, hi = 99 }
  local function inRegion(g) return g >= N.region.lo and g <= N.region.hi end

  local function exitsOf(info)
    local list = {}
    -- The current map's live grid knows tiles a script swapped in (stairs revealed by setmetatile).
    local grid = (info.g == F.grp() and info.m == F.mapn()) and liveGrid() or staticGrid(info)
    for _, w in ipairs(info.warps) do
      if inRegion(w.g) then
        local dest = header(w.g, w.m)
        local dw = dest.warps[w.warpId + 1]
        local v = grid.get(w.x, w.y)
        if dw and v and WARPB[grid.beh(v & 0x3FF)] then
          list[#list + 1] = { kind = 'warp', x = w.x, y = w.y, g = w.g, m = w.m, ex = dw.x, ey = dw.y }
        end
      end
    end
    for _, c in ipairs(info.conns) do
      -- Directions 5 and 6 are dive/emerge links, not walkable edges (taken by N.dive).
      if inRegion(c.g) and c.dir <= 4 then
        list[#list + 1] = { kind = 'conn', dir = c.dir, offset = c.offset, g = c.g, m = c.m, dest = header(c.g, c.m) }
      end
    end
    return list
  end

  N.exitsOf, N.staticGrid = exitsOf, staticGrid

  -- Edge tile test for a connection exit, and the entry tile it leads to.
  local function connGoal(info, ex)
    local d, o, dest = ex.dir, ex.offset, ex.dest
    -- MapConnection.direction: 1 = south, 2 = north, 3 = west, 4 = east
    return function(x, y)
      if d == 1 then return y == info.h - 1 and x - o >= 0 and x - o < dest.w
      elseif d == 2 then return y == 0 and x - o >= 0 and x - o < dest.w
      elseif d == 3 then return x == 0 and y - o >= 0 and y - o < dest.h
      else return x == info.w - 1 and y - o >= 0 and y - o < dest.h end
    end
  end
  local function connEntry(ex, x, y)
    local d, o, dest = ex.dir, ex.offset, ex.dest
    if d == 1 then return x - o, 0 elseif d == 2 then return x - o, dest.h - 1
    elseif d == 3 then return dest.w - 1, y - o else return 0, y - o end
  end
  N.connGoal = connGoal

  -- Every tile reachable from (sx,sy) on a map, with its step count. Static (layout plus
  -- remembered changes and object templates) for other maps; live for where we stand.
  local flood, floodLive
  local floodCache = {}
  -- Reachability depends on field moves, hide flags and remembered maps, none of which are in the
  -- cache keys: start every planning pass from empty caches.
  local function resetPlanCaches()
    for k in pairs(floodCache) do floodCache[k] = nil end
    for k in pairs(reachCache) do reachCache[k] = nil end
  end
  N.resetPlanCaches = resetPlanCaches
  local function floodGrid(grid, sx, sy, e, s, occ)
    -- States are (tile, elevation, surfing): the same tile reached surfing at elevation 1 and on
    -- foot at elevation 4 leads to different places (a bridge over water).
    local reach, seen = { [sx .. ',' .. sy] = 0 }, { [sx .. ',' .. sy .. ',' .. e .. tostring(s)] = true }
    local q, head = { { sx, sy, e, s, 0 } }, 1
    while head <= #q and head < 60000 do
      local n = q[head]; head = head + 1
      for d = 1, 4 do
        local nx, ny, ne, ns = stepFrom(grid, occ, n[1], n[2], n[3], n[4], d)
        if nx then
          local sk = nx .. ',' .. ny .. ',' .. ne .. tostring(ns)
          if not seen[sk] then
            seen[sk] = true
            if reach[nx .. ',' .. ny] == nil then reach[nx .. ',' .. ny] = n[5] + 1 end
            q[#q + 1] = { nx, ny, ne, ns, n[5] + 1 }
          end
        end
      end
    end
    return reach
  end
  function flood(info, sx, sy, surf)
    local k = string.format('%d:%d:%d:%d:%s:%s:%s', info.g, info.m, sx, sy, tostring(surf), tostring(N.canWaterfall), tostring(N.planIgnoreObjects))
    if floodCache[k] then return floodCache[k] end
    local grid = staticGrid(info)
    local v = grid.get(sx, sy)
    local e = v and (v >> 12) or 0
    if e == 15 then e = 0 end
    local startSurf = v ~= nil and surfable(grid.beh(v & 0x3FF))
    local occ = {}
    local mem = N.mapMemory[info.g * 256 + info.m]
    for _, o in ipairs(N.planIgnoreObjects and {} or info.objs) do
      local clearable = (CLEARS_CUT[o.gfx] and N.canCut) or (CLEARS_SMASH[o.gfx] and N.canSmash)
        or (CLEARS_ITEM[o.gfx] and N.clearItems)
      if (o.flag == 0 or not N.flag(o.flag)) and not clearable then
        local at = mem and mem.objs and mem.objs[o.localId] or o
        occ[at.x .. ',' .. at.y] = (o.script == P.EventScript_Whirlpool) and o or true
      end
    end
    local saved = N.canSurf
    N.canSurf = surf
    local r = floodGrid(grid, sx, sy, e, startSurf and surf, occ)
    N.canSurf = saved
    floodCache[k] = r
    return r
  end
  N.flood = function(...) return flood(...) end
  -- Wandering objects are ignored here (they move). A campaign whose boulders can seal the exit it
  -- would plan through sets N.solidBoulders (Kanto's Victory Road); the others keep their routes.
  local BOULDER = { [C.OBJ_EVENT_GFX_PUSHABLE_BOULDER] = true, [C.OBJ_EVENT_GFX_PUSHABLE_BOULDER_FRLG] = true }
  function floodLive()
    local x, y = F.pos()
    local occ = {}
    if N.solidBoulders then
      local seen = {}
      for _, o in ipairs(N.objects()) do
        seen[o.localId] = true
        if BOULDER[o.gfx] then occ[o.x .. ',' .. o.y] = true end
      end
      for _, t in ipairs(header(F.grp(), F.mapn()).objs) do
        if BOULDER[t.gfx] and not seen[t.localId] and (t.flag == 0 or not N.flag(t.flag)) then occ[t.x .. ',' .. t.y] = true end
      end
    end
    return floodGrid(liveGrid(), x, y, N.elevation(), N.surfing(), occ)
  end
  N.floodLive = function() return floodLive() end

  local function reachesTile(reach, t)
    if reach[t[1] .. ',' .. t[2]] then return true end
    for d = 1, 4 do
      if reach[(t[1] + DX[d]) .. ',' .. (t[2] + DY[d])] then return true end
    end
    return false
  end

  -- Dijkstra over (map, entry tile). Returns the first exit to take from the current position.
  function N.route(target, opts)
    opts = opts or {}
    resetPlanCaches()
    if N.resetAvoid then N.avoid = {} end   -- a walk's bumps must not poison a cross-map plan
    local tg = MAPS[target]
    assert(tg, 'unknown map ' .. tostring(target))
    local g0, m0 = F.grp(), F.mapn()
    local sx, sy = F.pos()
    local surf = N.canSurf
    local dist, first = {}, {}
    local startK = string.format('%d:%d:%d:%d', g0, m0, sx, sy)
    dist[startK] = 0
    local frontier = { { k = startK, g = g0, m = m0, x = sx, y = sy, d = 0 } }
    local visited = 0
    while #frontier > 0 and visited < 3000 do
      table.sort(frontier, function(a, b) return a.d < b.d end)
      local n = table.remove(frontier, 1)
      visited = visited + 1
      if N.debugRoute == 'pop' then L(string.format('    pop %s(%d,%d) d=%d', N.mapName(n.g, n.m), n.x, n.y, n.d)) end
      local info = header(n.g, n.m)
      local isStart = n.g == g0 and n.m == m0 and n.x == sx and n.y == sy
      local reach = isStart and floodLive() or flood(info, n.x, n.y, surf)
      -- With opts.tile the destination is that tile or a neighbour of it, not just the map: a map
      -- can be several unconnected pieces (Mt. Moon's fossil chamber).
      if n.g == tg.g and n.m == tg.m and (not opts.tile or reachesTile(reach, opts.tile)) then return first[n.k], n end
      local function push(ex, tx, ty, exx, exy)
        local cost = reach[tx .. ',' .. ty] + 10
        local k = string.format('%d:%d:%d:%d', ex.g, ex.m, exx, exy)
        if dist[k] == nil or dist[k] > n.d + cost then
          dist[k] = n.d + cost
          -- The first hop remembers which edge tile it planned: rows of one edge can lead into
          -- different parts of the next map.
          first[k] = first[n.k] or setmetatable({ edgeX = tx, edgeY = ty }, { __index = ex })
          frontier[#frontier + 1] = { k = k, g = ex.g, m = ex.m, x = exx, y = exy, d = n.d + cost }
        end
        return true
      end
      for _, ex in ipairs(exitsOf(info)) do
        local any = false
        if N.noEnter and N.noEnter[N.mapName(ex.g, ex.m)] then goto nextExit end
        if ex.kind == 'warp' then
          -- Walk onto it, or (a door in a wall) stand next to it.
          local best
          for d = 0, 4 do
            local ax, ay = ex.x + (d > 0 and DX[d] or 0), ex.y + (d > 0 and DY[d] or 0)
            local r = reach[ax .. ',' .. ay]
            if r and (not best or r < reach[best[1] .. ',' .. best[2]]) then best = { ax, ay } end
          end
          if best then any = push(ex, best[1], best[2], ex.ex, ex.ey) end
        else
          -- Every reachable tile on the edge is a candidate: different rows can lead into
          -- different, unconnected parts of the neighbouring map.
          local onEdge = connGoal(info, ex)
          for k, _ in pairs(reach) do
            local tx, ty = k:match('(-?%d+),(-?%d+)')
            tx, ty = tonumber(tx), tonumber(ty)
            if onEdge(tx, ty) then
              local exx, exy = connEntry(ex, tx, ty)
              local dv = staticGrid(ex.dest).get(exx, exy)
              if dv and (dv & 0x0C00) == 0 then   -- the tile across the seam must be enterable
                any = push(ex, tx, ty, exx, exy) or any
              end
            end
          end
        end
        if N.debugRoute then
          L(string.format('    route %s(%d,%d) -> %s %s %s', N.mapName(n.g, n.m), n.x, n.y, ex.kind,
            N.mapName(ex.g, ex.m), any and 'ok' or 'UNREACHED'))
        end
        ::nextExit::
      end
    end
    return nil
  end

  -- Standing on a warp tile: push the way it fires. Arrow and side-stair warps have a direction;
  -- otherwise only push toward tiles we cannot walk onto, so we never step off by accident.
  local ARROW = {
    [C.MB_NORTH_ARROW_WARP or -1] = 2, [C.MB_SOUTH_ARROW_WARP or -1] = 1, [C.MB_WEST_ARROW_WARP or -1] = 3,
    [C.MB_EAST_ARROW_WARP or -1] = 4, [C.MB_WATER_SOUTH_ARROW_WARP or -1] = 1,
    [C.MB_UP_RIGHT_STAIR_WARP or -1] = 4, [C.MB_DOWN_RIGHT_STAIR_WARP or -1] = 4,
    [C.MB_UP_LEFT_STAIR_WARP or -1] = 3, [C.MB_DOWN_LEFT_STAIR_WARP or -1] = 3,
  }
  function N.pushWarp()
    local g0, m0 = F.grp(), F.mapn()
    local x0, y0 = F.pos()
    local grid = liveGrid()
    local v = grid.get(x0, y0)
    local dirs = {}
    local ad = v and ARROW[grid.beh(v & 0x3FF)]
    if ad then dirs = { ad }
    else
      for d = 1, 4 do
        local nv = grid.get(x0 + DX[d], y0 + DY[d])
        if not nv or (nv & 0x0C00) ~= 0 then dirs[#dirs + 1] = d end
      end
    end
    for _, d in ipairs(dirs) do
      for _ = 1, 40 do joypad.set({ [KEY[d]] = true }); emu.frameadvance() end
      idle(60)
      if F.grp() ~= g0 or F.mapn() ~= m0 then return true end
      local x, y = F.pos()
      if x ~= x0 or y ~= y0 then return true end   -- an intra-map warp moved us
    end
    return false
  end

  -- A step-on warp (a teleport pad) does not fire for the tile we arrived on, and pushWarp only
  -- pushes into walls. When a plan starts ON such a warp, step off onto a plain tile and back.
  function N.reenterWarp()
    local g0, m0 = F.grp(), F.mapn()
    local x0, y0 = F.pos()
    local grid, warpAt = liveGrid(), {}
    for _, w in ipairs(header(g0, m0).warps) do warpAt[w.x .. ',' .. w.y] = true end
    for d = 1, 4 do
      local nx, ny = x0 + DX[d], y0 + DY[d]
      local nv = grid.get(nx, ny)
      if nv and (nv & 0x0C00) == 0 and not warpAt[nx .. ',' .. ny] and holdUntilMoved(d, 36) then
        waitStill(30)
        if F.grp() ~= g0 or F.mapn() ~= m0 then return true end
        holdUntilMoved(({ 2, 1, 4, 3 })[d], 36)
        idle(60)
        waitStill(60)
        if F.grp() ~= g0 or F.mapn() ~= m0 then return true end
        local x, y = F.pos()
        if not ((x == x0 and y == y0) or (x == nx and y == ny)) then return true end
        if x == nx and y == ny then holdUntilMoved(({ 2, 1, 4, 3 })[d], 36); waitStill(30) end
      end
    end
    return false
  end

  -- Take one exit from the current map. Returns true when the map changed.
  local function takeExit(ex, opts)
    local g0, m0 = F.grp(), F.mapn()
    if ex.kind == 'conn' then
      local info = header(g0, m0)
      local onEdge = connGoal(info, ex)
      local grid = liveGrid()
      local function crossable(x, y)
        if not onEdge(x, y) then return false end
        local v = grid.raw(x + DX[ex.dir], y + DY[ex.dir])
        return v ~= nil and (v & 0x0C00) == 0
      end
      local planned = ex.edgeX and function(x, y) return x == ex.edgeX and y == ex.edgeY end
      if not (planned and N.walk(planned, { tag = 'edge->' .. N.mapName(ex.g, ex.m), policy = opts.policy }))
          and not N.walk(crossable, { tag = 'edge->' .. N.mapName(ex.g, ex.m), policy = opts.policy }) then
        N.walk(function(x, y) return onEdge(x, y) end, { tag = 'edge->' .. N.mapName(ex.g, ex.m), policy = opts.policy })
      end
      for _ = 1, 3 do
        if F.grp() ~= g0 or F.mapn() ~= m0 then break end
        for _ = 1, 40 do joypad.set({ [KEY[ex.dir]] = true }); emu.frameadvance() end
        idle(30)
        if not N.free() then N.settle(opts) end
      end
      idle(20)
      return F.grp() ~= g0 or F.mapn() ~= m0
    end
    -- Warp tile: walk onto it, allowing the destination tile itself even if it reads solid.
    N.passGoal = { [ex.x .. ',' .. ex.y] = true }
    local ok = N.walk(function(x, y) return x == ex.x and y == ex.y end,
      { tag = 'warp->' .. N.mapName(ex.g, ex.m), allowWarp = true, policy = opts.policy })
    N.passGoal = nil
    idle(30)
    if F.grp() ~= g0 or F.mapn() ~= m0 then waitStill(60); return true end
    -- A trigger on the warp tile (an aide, a rival) may still be running.
    N.settle(opts)
    if F.grp() ~= g0 or F.mapn() ~= m0 then waitStill(60); return true end
    -- Arrow warps fire when pushed in their arrow's direction; doors in walls when pushed into.
    local x, y = F.pos()
    if x == ex.x and y == ex.y then
      if N.pushWarp() then N.settle(opts); waitStill(60); return true end
    else
      for d = 1, 4 do
        if x + DX[d] == ex.x and y + DY[d] == ex.y then
          for _ = 1, 40 do joypad.set({ [KEY[d]] = true }); emu.frameadvance() end
          idle(60)
          if F.grp() ~= g0 or F.mapn() ~= m0 then N.settle(opts); waitStill(60); return true end
        end
      end
    end
    -- Not adjacent: walk next to it and push.
    if N.approach(ex.x, ex.y, { tag = 'door' }) then
      local px, py = F.pos()
      for d = 1, 4 do
        if px + DX[d] == ex.x and py + DY[d] == ex.y then
          for _ = 1, 40 do joypad.set({ [KEY[d]] = true }); emu.frameadvance() end
          idle(60)
        end
      end
      local qx, qy = F.pos()
      if F.grp() == g0 and F.mapn() == m0 and qx == ex.x and qy == ex.y then N.pushWarp() end
    end
    if F.grp() ~= g0 or F.mapn() ~= m0 then N.settle(opts); waitStill(60); return true end
    return false
  end

  -- Reach (tx,ty) on the current map, using the map's own internal warps (holes, arrow warps
  -- between "floors" of one map, like the Olivine Lighthouse) when it cannot be walked to.
  function N.goFar(tx, ty, opts)
    opts = opts or {}
    N.resetPlanCaches()
    local g, m = F.grp(), F.mapn()
    local info = header(g, m)
    local function atT(x, y) return x == tx and y == ty end
    for hop = 1, 20 do
      if not N.free() then N.settle(opts) end
      if F.grp() ~= g or F.mapn() ~= m then return false end
      local sx, sy = F.pos()
      if atT(sx, sy) then return true end
      local direct = bfs(liveGrid(), sx, sy, N.elevation(), N.surfing(), atT, {})
      if direct then return N.go(tx, ty, opts) end
      -- Dijkstra over same-map warps; the first hop is checked against the live map.
      local inner = {}
      local sg = staticGrid(info)
      N.deadWarps = N.deadWarps or {}
      for _, w in ipairs(info.warps) do
        local v = sg.get(w.x, w.y)
        local key = g .. ':' .. m .. ':' .. w.x .. ',' .. w.y
        if w.g == g and w.m == m and v and WARPB[sg.beh(v & 0x3FF)] and not N.deadWarps[key] then
          local dw = info.warps[w.warpId + 1]
          if dw then inner[#inner + 1] = { x = w.x, y = w.y, ex = dw.x, ey = dw.y } end
        end
      end
      local dist, first = { [sx .. ',' .. sy] = 0 }, {}
      local frontier = { { x = sx, y = sy, d = 0, start = true } }
      local chosen
      while #frontier > 0 and not chosen do
        table.sort(frontier, function(a, b) return a.d < b.d end)
        local n = table.remove(frontier, 1)
        local k = n.x .. ',' .. n.y
        local reachT = n.start and direct or staticReach(info, n.x, n.y, 't' .. tx .. ',' .. ty, atT, N.canSurf)
        if reachT then chosen = first[k]; break end
        for _, w in ipairs(inner) do
          local ok
          if n.start then
            N.passGoal = { [w.x .. ',' .. w.y] = true }
            ok = bfs(liveGrid(), sx, sy, N.elevation(), N.surfing(), function(x, y) return x == w.x and y == w.y end, {})
            N.passGoal = nil
          else
            ok = staticReach(info, n.x, n.y, 'w' .. w.x .. ',' .. w.y, function(x, y) return x == w.x and y == w.y end,
              N.canSurf, { [w.x .. ',' .. w.y] = true })
          end
          local ek = w.ex .. ',' .. w.ey
          if ok and dist[ek] == nil then
            dist[ek] = n.d + 1
            first[ek] = first[k] or w
            frontier[#frontier + 1] = { x = w.ex, y = w.ey, d = n.d + 1 }
          end
        end
      end
      if not chosen then L(string.format('  goFar: no warp route to (%d,%d) on %s', tx, ty, N.mapName())); return false end
      L(string.format('  goFar (%d,%d): via inner warp (%d,%d) -> (%d,%d)', tx, ty, chosen.x, chosen.y, chosen.ex, chosen.ey))
      N.passGoal = { [chosen.x .. ',' .. chosen.y] = true }
      N.walk(function(x, y) return x == chosen.x and y == chosen.y end, { tag = 'inner warp', allowWarp = true })
      N.passGoal = nil
      idle(30)
      local x, y = F.pos()
      if x == chosen.x and y == chosen.y then
        if not N.pushWarp() then
          L(string.format('  goFar: warp (%d,%d) did not fire; not using it again', x, y))
          N.deadWarps[g .. ':' .. m .. ':' .. x .. ',' .. y] = true
        end
      end
      waitStill(60)
    end
    return false
  end

  -- Walk onto a specific warp tile on this map and make it fire. True when we went somewhere.
  function N.takeWarp(x, y, opts)
    local g0, m0 = F.grp(), F.mapn()
    for attempt = 1, 3 do
      N.passGoal = { [x .. ',' .. y] = true }
      N.walk(function(px, py) return px == x and py == y end, { tag = string.format('warp(%d,%d)', x, y), allowWarp = true })
      N.passGoal = nil
      idle(30)
      if F.grp() ~= g0 or F.mapn() ~= m0 then break end
      local px, py = F.pos()
      if px == x and py == y then
        if N.pushWarp() then waitStill(60); break end
      end
      idle(60)   -- something (a wandering Pokémon) was in the way: try again
    end
    waitStill(60)
    if not N.free() then N.settle(opts) end
    local px, py = F.pos()
    -- Success is a map change or an internal warp (we are no longer on, or next to, the warp tile).
    return F.grp() ~= g0 or F.mapn() ~= m0 or math.abs(px - x) + math.abs(py - y) > 1
  end

  function N.travel(target, opts)
    opts = opts or {}
    local tg = MAPS[target]
    for hop = 1, 60 do
      if not N.free() then N.settle(opts) end
      N.rememberMap()
      if N.natural then N.natural.maybeHeal() end
      if N.resetAvoid then N.avoid = {} end
      if F.grp() == tg.g and F.mapn() == tg.m and (not opts.tile or reachesTile(floodLive(), opts.tile)) then return true end
      local ex = N.route(target, opts)
      if not ex then
        -- Objects scripts have moved since (setobjectxyperm) still sit on their template tiles in
        -- the static view of maps we have not seen this session: plan once without them.
        N.planIgnoreObjects = true
        ex = N.route(target, opts)
        N.planIgnoreObjects = false
        if ex then L('  travel: planned ignoring off-map objects') end
      end
      if not ex then L('  travel: no route from ' .. N.mapName() .. ' to ' .. target); F.shot('noroute'); return false end
      L(string.format('  travel %s -> %s via %s (%s,%s) to %s', N.mapName(), target, ex.kind, tostring(ex.x or ex.dir), tostring(ex.y or ''), N.mapName(ex.g, ex.m)))
      if ex.kind == 'warp' and ex.g == F.grp() and ex.m == F.mapn() then
        -- An internal warp of this map (a hole, a floor-to-floor arrow): ride it and re-plan.
        local x0, y0 = F.pos()
        N.passGoal = { [ex.x .. ',' .. ex.y] = true }
        N.walk(function(x, y) return x == ex.x and y == ex.y end, { tag = 'inner warp', allowWarp = true })
        N.passGoal = nil
        idle(30)
        local x, y = F.pos()
        if x == ex.x and y == ex.y and not N.pushWarp() and x == x0 and y == y0 then N.reenterWarp() end
        waitStill(60)
        local x2, y2 = F.pos()
        if x2 == x0 and y2 == y0 then L('  travel: inner warp failed at ' .. N.mapName()); return false end
      elseif not takeExit(ex, opts) then
        L('  travel: exit failed at ' .. N.mapName()); F.shot('exitfail')
        return false
      end
      N.settle(opts)
    end
    return F.grp() == tg.g and F.mapn() == tg.m
  end

  ---------------------------------------------------------------- debug menu helpers
  local function dbg() press('R', 1); for _ = 1, 3 do joypad.set({ R = true, Start = true }); emu.frameadvance() end; idle(50) end
  local function downs(n) for _ = 1, n do press('Down', 3); idle(16) end end

  -- Give a Pokémon through Debug > Give X > Pokémon (Complex). spec = {species, level, moves={...}}
  function N.giveMon(spec)
    local before = N.partyCount()
    dbg(); idle(30)
    downs(3); press('A', 3); idle(50)          -- Give X…
    downs(2); press('A', 3); idle(80)          -- Pokémon (Complex)
    local want = {
      [P.DebugAction_Give_Pokemon_SelectId] = function() return spec.species end,
      [P.DebugAction_Give_Pokemon_SelectLevel] = function() return spec.level or 100 end,
      [P.DebugAction_Give_Pokemon_SelectIVs] = function() return 31 end,
      [P.DebugAction_Give_Pokemon_SelectEVs] = function(t) return (spec.evs or { 0, 0, 0, 0, 0, 0 })[r16(t + 8 + 14) + 1] end,
    }
    local moveFn = P.DebugAction_Give_Pokemon_Move
    for _ = 1, 80 do
      local found
      for j = 0, 15 do
        local t = S.gTasks + j * 40
        if r8(t + 4) ~= 0 then
          local fn = r32(t) & ~1
          for f, val in pairs(want) do
            if fn == (f & ~1) then found = true; w16(t + 8 + 6, val(t)) end
          end
          if fn == (moveFn & ~1) then
            found = true
            local it = r16(t + 8 + 14)
            w16(t + 8 + 6, spec.moves[it + 1] or 0)
          end
          for _, name in ipairs({ 'DebugAction_Give_Pokemon_SelectShiny', 'DebugAction_Give_Pokemon_SelectNature',
                                   'DebugAction_Give_Pokemon_SelectAbility', 'DebugAction_Give_Pokemon_SelectTeraType',
                                   'DebugAction_Give_Pokemon_SelectDynamaxLevel', 'DebugAction_Give_Pokemon_SelectGigantamaxFactor' }) do
            if P[name] and fn == (P[name] & ~1) then found = true end
          end
        end
      end
      if not found then break end
      idle(4); press('A', 3); idle(30)
    end
    for _ = 1, 6 do press('B', 2); idle(20) end
    N.settle({ quiet = 30 })
    L(string.format('  giveMon species=%d -> party %d -> %d', spec.species, before, N.partyCount()))
    return N.partyCount() == before + 1
  end

  -- Give an item through Debug > Give X > Give item XYZ.
  function N.debugGiveItem(item, qty)
    dbg(); idle(30)
    downs(3); press('A', 3); idle(50)
    press('A', 3); idle(60)
    for _ = 1, 40 do
      local found
      for j = 0, 15 do
        local t = S.gTasks + j * 40
        if r8(t + 4) ~= 0 then
          local fn = r32(t) & ~1
          if fn == (P.DebugAction_Give_Item_SelectId & ~1) then found = true; w16(t + 8 + 6, item)
          elseif fn == (P.DebugAction_Give_Item_SelectQuantity & ~1) then found = true; w16(t + 8 + 6, qty) end
        end
      end
      if not found then break end
      idle(4); press('A', 3); idle(30)
    end
    for _ = 1, 6 do press('B', 2); idle(20) end
    N.settle({ quiet = 30 })
    return N.itemCount(item) > 0
  end

  -- Lower a party member's met level (substruct 3, encrypted, checksummed). The game recalculates
  -- every party member's stats after each battle, so the level must be real; Gen 8+ obedience then
  -- keys off the met level, which the debug Give menu sets equal to the given level.
  local SUB3 = { 3, 2, 3, 2, 1, 1, 3, 2, 3, 2, 1, 1, 3, 2, 3, 2, 1, 1, 0, 0, 0, 0, 0, 0 }
  function N.setMetLevel(slot, lvl)
    local b = P.gParties + slot * O.mon_size
    local pid, otid = r32(b), r32(b + 4)
    local key = pid ~ otid
    local addr = b + 32 + 12 * SUB3[(pid % 24) + 1]
    local old = r32(addr) ~ key
    local new = (old & ~(0x7F << 16)) | ((lvl & 0x7F) << 16)
    local function halves(v) return (v & 0xFFFF) + (v >> 16) end
    local sum = (r16(b + 28) - halves(old) + halves(new)) & 0xFFFF
    F.w32(addr, new ~ key)
    w16(b + 28, sum)
    L(string.format('  setMetLevel slot %d: met level %d -> %d', slot, (old >> 16) & 0x7F, lvl))
  end

  -- Experience, the low 21 bits of the growth substruct's second word.
  local SUBSTRUCT_ORDER = { 'GAEM', 'GAME', 'GEAM', 'GEMA', 'GMAE', 'GMEA', 'AGEM', 'AGME', 'AEGM', 'AEMG', 'AMGE', 'AMEG',
    'EGAM', 'EGMA', 'EAGM', 'EAMG', 'EMGA', 'EMAG', 'MGAE', 'MGEA', 'MAGE', 'MAEG', 'MEGA', 'MEAG' }
  function N.setExp(slot, exp)
    local b = P.gParties + slot * O.mon_size
    local pid, otid = r32(b), r32(b + 4)
    local key = pid ~ otid
    local addr = b + 32 + 12 * (SUBSTRUCT_ORDER[(pid % 24) + 1]:find('G') - 1) + 4
    local old = r32(addr) ~ key
    local new = (old & ~0x1FFFFF) | (exp & 0x1FFFFF)
    local function halves(v) return (v & 0xFFFF) + (v >> 16) end
    local sum = (r16(b + 28) - halves(old) + halves(new)) & 0xFFFF
    F.w32(addr, new ~ key)
    w16(b + 28, sum)
  end

  -- Swap two party slots byte for byte (each mon is encrypted with its own key, so this is safe).
  function N.swapParty(a, b)
    local pa, pb = P.gParties + a * O.mon_size, P.gParties + b * O.mon_size
    for off = 0, O.mon_size - 4, 4 do
      local va, vb = r32(pa + off), r32(pb + off)
      F.w32(pa + off, vb); F.w32(pb + off, va)
    end
  end

  -- SELECT a registered Hub Pass and answer its confirm, which opens on NO after a page of text.
  function N.useHubPass()
    F.w16(F.sb1() + F.S.SaveBlock1.registeredItem, C.ITEM_HUB_RETURN)
    press('Select'); idle(90)
    local function confirmOpen()
      return activeTask(P.Task_CallYesOrNoCallback) ~= nil or activeTask(P.Task_HandleYesNoInput) ~= nil
    end
    for _ = 1, 40 do
      if confirmOpen() then idle(30); press('Up'); idle(12); press('A'); idle(60); break end
      press('A'); idle(30)
    end
    for _ = 1, 400 do
      if N.mapName() == 'RegionHub' and N.free() then break end
      press('A'); idle(10)
    end
    assert(N.mapName() == 'RegionHub', 'Hub Pass left us at ' .. N.mapName())
  end

  -- Talk to the hub attendant standing at (x, 2) and board.
  function N.crossGate(x)
    assert(N.approach(x, 2, { side = 1 }), 'hub attendant')
    for _ = 1, 500 do
      press('A'); idle(20)
      if N.mapName() ~= 'RegionHub' then break end
    end
    idle(200); N.settle()
    assert(N.mapName() ~= 'RegionHub', 'the gate did not board')
  end

  N.LOSS_PLAYED = 'deliberate loss played out'
  N.WHITEOUT = 'whited out in natural mode'
  function N.money()
    return F.r32(F.sb1() + O.sb1_money) ~ F.r32(F.r32(P.gSaveBlock2Ptr) + O.sb2_encryptionKey)
  end

  function N.debugHeal()
    dbg(); idle(30)
    downs(2); press('A', 3); idle(50)   -- Party…
    downs(2); press('A', 3); idle(60)   -- Heal party
    for _ = 1, 6 do press('B', 2); idle(20) end
    N.settle({ quiet = 30, noHeal = true })
    N.heals = (N.heals or 0) + 1
  end

  -- Johto roamers. Their location lives in EWRAM (sRoamerLocation), so a test can bring one here.
  function N.roamer(i)
    local b = F.sb1() + O.sb1_roamer + i * O.roamer_size
    return { species = r16(b + O.roamer_species), hp = r16(b + O.roamer_hp), active = r8(b + O.roamer_active) ~= 0 }
  end
  function N.placeRoamerHere(i)
    F.w8(P.sRoamerLocation + i * 2, F.grp())
    F.w8(P.sRoamerLocation + i * 2 + 1, F.mapn())
  end

  ---------------------------------------------------------------- bag
  local function pocketSlots(p)
    local b = P.gBagPockets + p * S.BagPocket.stride
    return r32(b), r16(b + 4) & 0x3FF
  end
  local function bagKey() return F.r32(F.r32(P.gSaveBlock2Ptr) + O.sb2_encryptionKey) & 0xFFFF end
  -- Total quantity across the five pockets, unlike F.itemCount, which counts slots.
  function N.itemQty(id)
    local n = 0
    for p = 0, 4 do
      local ptr, cap = pocketSlots(p)
      for s = 0, cap - 1 do
        if r16(ptr + s * 4) == id then n = n + (r16(ptr + s * 4 + 2) ~ bagKey()) end
      end
    end
    return n
  end
  -- Put `id` in the first slot of the balls pocket, which is the slot N.battle throws from.
  -- qty, when given, sets the count. A documented concession: see README, Post-game.
  function N.ballFirst(id, qty)
    local ptr, cap = pocketSlots(1)
    local at, free
    for s = 0, cap - 1 do
      local i = r16(ptr + s * 4)
      if i == id then at = s end
      if i == 0 and not free then free = s end
    end
    at = at or assert(free, 'balls pocket full')
    local a, b = ptr + at * 4, ptr
    local ida, qa, idb, qb = r16(a), r16(a + 2), r16(b), r16(b + 2)
    if ida == 0 then ida, qa = id, 1 ~ bagKey() end
    w16(b, ida); w16(b + 2, qty and (qty ~ bagKey()) or qa)
    if at ~= 0 then w16(a, idb); w16(a + 2, qb) end
  end

  ---------------------------------------------------------------- checkpoints
  function N.checkpoint(name)
    local path = F.out .. 'ckpt_' .. name .. '.ss'
    local ok = client.savestate(path)
    L(string.format('CHECKPOINT %s -> %s (%s) at %s (%d,%d)', name, path, tostring(ok), N.mapName(), F.pos(), select(2, F.pos())))
    return ok
  end
  function N.restore(name, directory)
    local file = 'ckpt_' .. name .. '.ss'
    local path = (directory and (directory .. '/') or F.out) .. file
    -- Each run writes to a fresh directory, so the checkpoint a run resumed from (--from) exists
    -- only in the prior case directory. Rewinds and retries to it must look there too.
    local resume = os.getenv('PW_RESUME_DIR')
    if not directory and resume then
      local own = io.open(path, 'rb')
      if own then own:close() else path = resume .. '/' .. file end
    end
    local ok = client.loadstate(path)
    idle(10)
    N.resetPlanCaches()
    N.mapMemory = {}   -- a restore returns to the past; the remembered grids describe a later state
    L(string.format('RESTORED %s (%s) at %s (%d,%d)', name, tostring(ok), N.mapName(), F.pos(), select(2, F.pos())))
    return ok
  end

  return N
end
