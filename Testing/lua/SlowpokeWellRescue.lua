-- Issue #89: Slowpoke Well Jessie/James corridor gate, Kurt no longer
-- seals Proton's chamber, and beating Rocket walks you to Kurt's house.
-- Coords from data/maps/SlowpokeWell_B1F/map.json, not the changelog.
--
-- Run via Testing/mgba-run.sh Testing/lua/SlowpokeWellRescue.lua

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path

local S = require("symbols")
local F = require("lib").new(S, "SlowpokeWellRescue")

-- MAP_SLOWPOKE_WELL_B1F = (5 | (82 << 8)); MAP_AZALEA_TOWN_KURTS_HOUSE = (2 | (81 << 8))
local GRP_WELL, MAP_B1F = 82, 5
local GRP_AZALEA_INDOOR, MAP_KURTS_HOUSE = 81, 2
local HUB_GROUP = 100

-- events.inc local ids
local LOCALID_KURT_LYING, LOCALID_GRUNT21, LOCALID_GRUNT22, LOCALID_PROTON = 1, 2, 3, 4
local LOCALID_KURT_STANDING, LOCALID_JESSIE, LOCALID_JAMES = 8, 12, 13

-- include/constants/event_objects.h
local GFX_LASS, GFX_MAGMA_M, GFX_MAGMA_F = 47, 119, 120
local GFX_ROCKET_M, GFX_ROCKET_F = 276, 277
local GFX_KURT, GFX_KURT_LYING, GFX_PROTON = 402, 403, 408

-- Johto flags live in SaveBlock3; Jessie/James hide flag is the world-map bank in SaveBlock1.
local FLAG_JOHTO_BASE = 0x6000
local FLAG_HIDE_AZALEA_TOWN_ROCKETS        = FLAG_JOHTO_BASE + 0x75
local FLAG_HIDE_SLOWPOKE_WELL_KURT         = FLAG_JOHTO_BASE + 0x7B
local FLAG_HIDE_SLOWPOKE_WELL_KURT_STANDING = FLAG_JOHTO_BASE + 0x25B
local FLAG_HIDE_JESSIE_JAMES_SLOWPOKE_WELL = 0xD79  -- FLAG_WORLD_MAP_BANK + 0x39
local REGION_VARS_START = 0xA000
local VAR_AZALEA_TOWN_STATE = 0xA080 + 0x0C

local TRAINER_FLAGS_START = 0x500
local TRAINER_ETO, TRAINER_GRUNT_21, TRAINER_GRUNT_22 = 876, 878, 879

local B_OUTCOME_WON = 1
local MAPGRID_COLLISION_MASK = 0x0C00
local TEMPLATES = 3988
local TEMPLATE = { stride = 24, localId = 0, graphicsId = 1, x = 4, y = 6, flagId = 20 }
local WELL_OBJECTS = 13
local ROW_PARTY_MENU, ROW_SET = 2, 9
local MAIN_VBLANK_COUNTER1 = 0x20
local FOLLOWER, PLAYER, CAMERA = 0xFE, 0xFF, 0x7F

-- Entrance (26,29) -> east approach tile (22,2). BFS against map.bin + NPC tiles.
local PATH_TO_JJ = {
  {26,29},{26,28},{26,27},{26,26},{26,25},{26,24},{26,23},{26,22},
  {27,22},{27,21},{27,20},{27,19},{27,18},{27,17},{27,16},{27,15},
  {27,14},{27,13},{26,13},{26,12},{26,11},{26,10},{26,9},{26,8},
  {26,7},{26,6},{26,5},{26,4},{26,3},{25,3},{25,2},{24,2},{23,2},{22,2},
}

local function vblank() return F.r32(S.gMain + MAIN_VBLANK_COUNTER1) end

local function johtoFlagAddr(id) return F.sb3() + S.SaveBlock3.johtoFlags + ((id - FLAG_JOHTO_BASE) // 8) end
local function johtoFlagGet(id) return (F.r8(johtoFlagAddr(id)) & (1 << (id % 8))) ~= 0 end
local function johtoFlagSet(id, on)
  local a, m = johtoFlagAddr(id), 1 << (id % 8)
  local cur = F.r8(a)
  F.w8(a, on and (cur | m) or (cur & ~m & 0xFF))
end
local function sb1FlagGet(id)
  return (F.r8(F.sb1() + S.SaveBlock1.flags + (id // 8)) & (1 << (id % 8))) ~= 0
end
local function sb1FlagSet(id, on)
  local a, m = F.sb1() + S.SaveBlock1.flags + (id // 8), 1 << (id % 8)
  local cur = F.r8(a)
  F.w8(a, on and (cur | m) or (cur & ~m & 0xFF))
end
local function regionVarSet(id, val) F.w16(F.sb3() + S.SaveBlock3.regionVars + (id - REGION_VARS_START) * 2, val) end

local function gfxName(gfx)
  local names = {
    [GFX_LASS] = "LASS", [GFX_MAGMA_M] = "MAGMA_M", [GFX_MAGMA_F] = "MAGMA_F",
    [GFX_ROCKET_M] = "ROCKET_M", [GFX_ROCKET_F] = "ROCKET_F",
    [GFX_KURT] = "KURT", [GFX_KURT_LYING] = "KURT_LYING", [GFX_PROTON] = "PROTON",
  }
  return names[gfx] or string.format("gfx=%d", gfx)
end

local function eachObj()
  local out = {}
  for i = 0, 15 do
    local b = S.gObjectEvents + i * S.ObjectEvent.stride
    if (F.r8(b) & 1) == 1 then
      local localId = F.r8(b + S.ObjectEvent.localId)
      out[#out + 1] = {
        i = i, localId = localId,
        x = F.rs16(b + S.ObjectEvent.x) - 7,
        y = F.rs16(b + S.ObjectEvent.y) - 7,
        gfx = F.r16(b + S.ObjectEvent.graphicsId),
        invisible = (F.r8(b + S.ObjectEvent.flags1) & 0x20) ~= 0,
      }
    end
  end
  return out
end

local function dumpObjs(tag)
  local objs = eachObj()
  F.L(string.format("  --- gObjectEvents %s (n=%d) ---", tag, #objs))
  for _, o in ipairs(objs) do
    F.L(string.format("    slot%02d localId=%3d (%d,%d) %s vis=%s",
      o.i, o.localId, o.x, o.y, gfxName(o.gfx), o.invisible and "no" or "yes"))
  end
  return objs
end

local function dumpTemplates(tag)
  local base = F.sb1() + TEMPLATES
  local out = {}
  F.L(string.format("  --- objectEventTemplates %s ---", tag))
  for i = 0, WELL_OBJECTS - 1 do
    local t = base + i * TEMPLATE.stride
    local rec = {
      i = i,
      localId = F.r8(t + TEMPLATE.localId),
      gfx = F.r16(t + TEMPLATE.graphicsId),
      x = F.rs16(t + TEMPLATE.x),
      y = F.rs16(t + TEMPLATE.y),
      flagId = F.r16(t + TEMPLATE.flagId),
    }
    out[#out + 1] = rec
    F.L(string.format("    t%02d localId=%3d (%d,%d) %s flag=0x%X",
      rec.i, rec.localId, rec.x, rec.y, gfxName(rec.gfx), rec.flagId))
  end
  return out
end

local function findTmpl(tmpls, localId)
  for _, t in ipairs(tmpls) do if t.localId == localId then return t end end
end

local function findLocal(objs, localId)
  for _, o in ipairs(objs) do if o.localId == localId then return o end end
end

local function findAt(objs, x, y)
  local hit = {}
  for _, o in ipairs(objs) do
    if o.x == x and o.y == y and o.localId ~= PLAYER and o.localId ~= CAMERA and o.localId ~= FOLLOWER then
      hit[#hit + 1] = o
    end
  end
  return hit
end

local function assertAlive(tag)
  local t0 = vblank()
  F.idle(8)
  local crashed, text = F.reportCrash(tag)
  local t1 = vblank()
  F.check("no crash screen (" .. tag .. ")", not crashed, text or "clear")
  -- AssertfCrashScreen keeps CB2_Overworld; vblank still ticks. A freeze does not.
  F.check("vblank advancing (" .. tag .. ")", t1 > t0,
    string.format("vblank %d -> %d cb2=0x%08X ow=%s", t0, t1, F.cb2(), tostring(F.ow())))
  return not crashed
end

local function occupiedSet(objs)
  local occ = {}
  for _, o in ipairs(objs) do
    if o.localId ~= PLAYER and o.localId ~= CAMERA and o.localId ~= FOLLOWER and not o.invisible then
      occ[o.x .. "," .. o.y] = o
    end
  end
  return occ
end

local function tileBlocked(x, y)
  local w = F.r32(S.gBackupMapLayout + S.BackupMapLayout.width)
  local map = F.r32(S.gBackupMapLayout + S.BackupMapLayout.map)
  if map < 0x02000000 or w < 8 or w > 128 then return true end
  local idx = (x + 7) + (y + 7) * w
  return (F.r16(map + idx * 2) & MAPGRID_COLLISION_MASK) ~= 0
end

local function bfs(sx, sy, gx, gy, occ, ignoreGoalOcc)
  local function key(x, y) return x .. "," .. y end
  local q, head = { {sx, sy} }, 1
  local seen = { [key(sx, sy)] = true }
  local prev = {}
  while head <= #q do
    local x, y = q[head][1], q[head][2]; head = head + 1
    if x == gx and y == gy then
      local path, cx, cy = {}, x, y
      while cx do
        path[#path + 1] = { cx, cy }
        local p = prev[key(cx, cy)]
        if not p then break end
        cx, cy = p[1], p[2]
      end
      local rev = {}
      for i = #path, 1, -1 do rev[#rev + 1] = path[i] end
      return rev
    end
    for _, d in ipairs({ {1,0}, {-1,0}, {0,1}, {0,-1} }) do
      local nx, ny = x + d[1], y + d[2]
      if nx >= 0 and ny >= 0 and nx < 40 and ny < 40 then
        local k = key(nx, ny)
        if not seen[k] then
          local isGoal = (nx == gx and ny == gy)
          local blockedByNpc = occ[k] and not (ignoreGoalOcc and isGoal)
          if not tileBlocked(nx, ny) and not blockedByNpc then
            seen[k] = true
            prev[k] = { x, y }
            q[#q + 1] = { nx, ny }
          end
        end
      end
    end
  end
  return nil
end

local function occupancyFrom(objs, tmpls)
  local occ = occupiedSet(objs)
  if tmpls then
    for _, t in ipairs(tmpls) do
      local hidden = false
      if t.flagId >= FLAG_JOHTO_BASE then hidden = johtoFlagGet(t.flagId)
      elseif t.flagId ~= 0 then hidden = sb1FlagGet(t.flagId) end
      if not hidden then occ[t.x .. "," .. t.y] = t end
    end
  end
  return occ
end

local function tapDown(n)
  for _ = 1, n do F.press("Down", 3); F.idle(16) end
end

local function setParty()
  F.dbg(); F.idle(60)
  tapDown(ROW_PARTY_MENU); F.press("A", 3); F.idle(60)
  tapDown(ROW_SET); F.press("A", 3); F.idle(180)
  for _ = 1, 8 do F.press("B", 3); F.idle(20) end
  local n = F.r8(S.gPartiesCount)
  F.check("Set Party published a live party", n > 0, "count=" .. n)
  return n > 0
end

local forceWinUntil
local function resolveLock(tag)
  F.L(string.format("  resolveLock %s ow=%s battlers=%d cb2=0x%08X pos=(%d,%d)",
    tag, tostring(F.ow()), F.battlers(), F.cb2(), F.pos()))
  -- Trainer-see: still overworld, or already fading (ow=false, battlers=0). Mash until
  -- the battle publishes battlers, then force the win.
  local sawBattle = false
  for _ = 1, 400 do
    if F.reportCrash(tag) then return false end
    if F.battlers() > 0 then sawBattle = true; break end
    if F.ow() and F.battlers() == 0 then
      -- maybe the lock was a message; keep tapping a bit more then give up
    end
    F.press("A", 2); F.idle(4)
  end
  if sawBattle or F.battlers() > 0 then
    local ok = forceWinUntil(function() return F.ow() end, tag, 2000)
    F.idle(40)
    for _ = 1, 80 do F.press("A", 2); F.idle(6) end
    return ok
  end
  return F.ow()
end

local function walkPath(pts, tag)
  for i, p in ipairs(pts) do
    if not F.leg(p[1], p[2]) then
      local x, y = F.pos()
      F.L(string.format("  walk %s blocked wp%d want (%d,%d) at (%d,%d) ow=%s battlers=%d",
        tag, i, p[1], p[2], x, y, tostring(F.ow()), F.battlers()))
      if not resolveLock(tag .. "_wp" .. i) then
        F.shot(tag .. "_stuck")
        F.reportCrash(tag .. "_stuck")
        return false
      end
      if not F.leg(p[1], p[2]) then
        x, y = F.pos()
        F.L(string.format("  walk %s still stuck wp%d at (%d,%d)", tag, i, x, y))
        F.shot(tag .. "_stuck")
        return false
      end
    end
  end
  return true
end

local function waitBattle(tag, frames)
  for i = 1, (frames or 500) do
    if F.reportCrash(tag .. "_prebattle") then return false end
    if (not F.ow()) and F.battlers() > 0 then return true end
    if i % 20 == 0 then F.press("A", 2) end
    F.idle(2)
  end
  return (not F.ow()) and F.battlers() > 0
end

forceWinUntil = function(pred, tag, frames)
  F.w8(S.gBattleOutcome, B_OUTCOME_WON)
  for i = 1, (frames or 2400) do
    if F.reportCrash(tag .. "_battle") then return false end
    if pred() then return true end
    if (not F.ow()) and F.battlers() > 0 then F.w8(S.gBattleOutcome, B_OUTCOME_WON) end
    F.press("A", 2); F.idle(2)
  end
  return pred()
end

local function mashUntilMap(grp, map, tag, frames)
  for i = 1, (frames or 2400) do
    if F.reportCrash(tag) then return false end
    if F.grp() == grp and F.mapn() == map then F.idle(40); return true end
    if i % 8 == 0 then F.press("A", 2) end
    F.idle(4)
  end
  return F.grp() == grp and F.mapn() == map
end

local function armKurtSceneFlags()
  -- Proton script after the battle: hide rockets + lying Kurt. Standing Kurt is addobject'd;
  -- ON_TRANSITION always re-sets FLAG_HIDE_SLOWPOKE_WELL_KURT_STANDING, so we also clear it
  -- every frame during the next warp in case spawn happens after the map script.
  johtoFlagSet(FLAG_HIDE_AZALEA_TOWN_ROCKETS, true)
  johtoFlagSet(FLAG_HIDE_SLOWPOKE_WELL_KURT, true)
  johtoFlagSet(FLAG_HIDE_SLOWPOKE_WELL_KURT_STANDING, false)
  regionVarSet(VAR_AZALEA_TOWN_STATE, 2)
end

local function warpWell(warpOnes, tag, holdFlags, expectX, expectY)
  local eg, em = GRP_WELL, MAP_B1F
  resolveLock(tag .. "_prewarp")
  local x0, y0 = F.pos()
  for _ = 1, 6 do
    F.dbg(); F.sel(0); F.sel(1); F.idle(20)
    F.spin(0, 8, 2); F.spin(0, 0, 5); F.spin(0, 0, warpOnes)
    for _ = 1, 280 do
      if holdFlags then armKurtSceneFlags() end
      emu.frameadvance()
      local x, y = F.pos()
      if F.ow() and F.grp() == eg and F.mapn() == em
          and (x ~= x0 or y ~= y0 or (expectX and x == expectX)) then
        for _ = 1, 50 do
          if holdFlags then armKurtSceneFlags() end
          emu.frameadvance()
        end
        x, y = F.pos()
        F.L(string.format("  WARP %s ok (%d,%d)", tag, x, y))
        if expectX and (x ~= expectX or y ~= expectY) then
          F.L(string.format("  WARP %s landed (%d,%d) want (%d,%d)", tag, x, y, expectX, expectY))
        end
        return true
      end
    end
    for _ = 1, 5 do F.press("B", 2); F.idle(20) end
  end
  F.shot(tag .. "_warpfail")
  return false
end

F.run(function()
  if not F.boot(HUB_GROUP) then F.check("boot to hub", false); F.finish(); return end
  F.check("boot reached overworld", F.ow())
  assertAlive("boot")

  -- Party first so a later trainer battle cannot strand us. Grunt flags persist across warps.
  setParty()
  sb1FlagSet(TRAINER_FLAGS_START + TRAINER_GRUNT_21, true)
  sb1FlagSet(TRAINER_FLAGS_START + TRAINER_GRUNT_22, true)
  sb1FlagSet(TRAINER_FLAGS_START + TRAINER_ETO, true)
  F.check("grunt trainer flags seeded (stay out of sight cones)",
    sb1FlagGet(TRAINER_FLAGS_START + TRAINER_GRUNT_21)
      and sb1FlagGet(TRAINER_FLAGS_START + TRAINER_GRUNT_22)
      and sb1FlagGet(TRAINER_FLAGS_START + TRAINER_ETO))

  -- A. Fresh well, story flags at default.
  if not F.warpTo(0, 8, 2, 0, 0, 5, 0, 0, 0, GRP_WELL, MAP_B1F, "well_fresh") then
    F.check("warp MAP_SLOWPOKE_WELL_B1F", false, "warpTo failed")
    F.finish(); return
  end
  F.check("on Slowpoke Well B1F", F.grp() == GRP_WELL and F.mapn() == MAP_B1F,
    string.format("grp=%d map=%d", F.grp(), F.mapn()))
  F.shot("well_fresh")
  assertAlive("well_fresh")

  F.L(string.format("  flags: HIDE_ROCKETS=%s HIDE_KURT=%s HIDE_KURT_STANDING=%s HIDE_JJ=%s",
    tostring(johtoFlagGet(FLAG_HIDE_AZALEA_TOWN_ROCKETS)),
    tostring(johtoFlagGet(FLAG_HIDE_SLOWPOKE_WELL_KURT)),
    tostring(johtoFlagGet(FLAG_HIDE_SLOWPOKE_WELL_KURT_STANDING)),
    tostring(sb1FlagGet(FLAG_HIDE_JESSIE_JAMES_SLOWPOKE_WELL))))
  -- Camera spawn box is [player.y, player.y+16] — Jessie/James at y=2 are off-screen from
  -- the (26,29) warp. Templates are loaded regardless; spawned objects are asserted after
  -- walking into range.
  local tmpls = dumpTemplates("fresh")
  local objs = dumpObjs("fresh")
  local tJessie, tJames = findTmpl(tmpls, LOCALID_JESSIE), findTmpl(tmpls, LOCALID_JAMES)
  local tProton = findTmpl(tmpls, LOCALID_PROTON)
  local tKurtStand = findTmpl(tmpls, LOCALID_KURT_STANDING)
  local tGruntM, tGruntF = findTmpl(tmpls, LOCALID_GRUNT21), findTmpl(tmpls, LOCALID_GRUNT22)

  F.check("Jessie template is at corridor (21,2)", tJessie ~= nil and tJessie.x == 21 and tJessie.y == 2,
    tJessie and string.format("(%d,%d) %s", tJessie.x, tJessie.y, gfxName(tJessie.gfx)) or "ABSENT")
  F.check("James template is at corridor (20,2)", tJames ~= nil and tJames.x == 20 and tJames.y == 2,
    tJames and string.format("(%d,%d) %s", tJames.x, tJames.y, gfxName(tJames.gfx)) or "ABSENT")
  F.check("Jessie template is ROCKET_F, not MAGMA/LASS",
    tJessie ~= nil and tJessie.gfx ~= GFX_MAGMA_M and tJessie.gfx ~= GFX_MAGMA_F and tJessie.gfx ~= GFX_LASS
      and (tJessie.gfx == GFX_ROCKET_F or (tGruntF and tJessie.gfx == tGruntF.gfx)),
    tJessie and gfxName(tJessie.gfx) or "ABSENT")
  F.check("James template is ROCKET_M, not MAGMA/LASS",
    tJames ~= nil and tJames.gfx ~= GFX_MAGMA_M and tJames.gfx ~= GFX_MAGMA_F and tJames.gfx ~= GFX_LASS
      and (tJames.gfx == GFX_ROCKET_M or (tGruntM and tJames.gfx == tGruntM.gfx)),
    tJames and gfxName(tJames.gfx) or "ABSENT")
  F.check("Proton template is at (14,3)", tProton ~= nil and tProton.x == 14 and tProton.y == 3,
    tProton and string.format("(%d,%d) %s", tProton.x, tProton.y, gfxName(tProton.gfx)) or "ABSENT")
  F.check("standing Kurt template is at (14,8), not the (17,8) choke",
    tKurtStand ~= nil and tKurtStand.x == 14 and tKurtStand.y == 8,
    tKurtStand and string.format("(%d,%d)", tKurtStand.x, tKurtStand.y) or "ABSENT")

  local kurtLie = findLocal(objs, LOCALID_KURT_LYING)
  local kurtStand = findLocal(objs, LOCALID_KURT_STANDING)
  F.check("lying Kurt is at the entrance (27,26), not the choke",
    kurtLie ~= nil and kurtLie.x == 27 and kurtLie.y == 26,
    kurtLie and string.format("(%d,%d) %s", kurtLie.x, kurtLie.y, gfxName(kurtLie.gfx)) or "ABSENT")
  F.check("standing Kurt is hidden on a fresh load (post-Rocket scene not active)",
    kurtStand == nil, kurtStand and string.format("(%d,%d)", kurtStand.x, kurtStand.y) or "absent")
  local choke = findAt(objs, 17, 8)
  F.check("nobody occupies the old door tile (17,8)", #choke == 0,
    #choke > 0 and string.format("localId %d %s", choke[1].localId, gfxName(choke[1].gfx)) or "clear")

  F.L("  BFS occupancy from templates + spawned objects")
  local occ = occupancyFrom(objs, tmpls)
  local px, py = F.pos()
  local toProton = bfs(px, py, 14, 3, occ, true)
  local toApproach = bfs(px, py, 22, 2, occ, false)
  F.check("Jessie/James cut the Proton path from the entrance",
    toProton == nil,
    toProton and ("reachable in " .. (#toProton - 1) .. " steps") or "no path (gate holds)")
  F.check("east approach tile (22,2) is reachable",
    toApproach ~= nil, toApproach and ((#toApproach - 1) .. " steps") or "NO PATH")

  F.L("  walking PATH_TO_JJ (entrance -> (22,2))")
  local walked = walkPath(PATH_TO_JJ, "to_jj")
  F.check("walked to (22,2) east of Jessie", walked and select(1, F.pos()) == 22 and select(2, F.pos()) == 2,
    string.format("at (%d,%d)", select(1, F.pos()), select(2, F.pos())))
  F.shot("jj_corridor")
  objs = dumpObjs("at_corridor")
  local jessie, james = findLocal(objs, LOCALID_JESSIE), findLocal(objs, LOCALID_JAMES)
  local proton = findLocal(objs, LOCALID_PROTON)
  F.check("Jessie spawned in camera range at (21,2)",
    jessie ~= nil and jessie.x == 21 and jessie.y == 2,
    jessie and string.format("(%d,%d) %s", jessie.x, jessie.y, gfxName(jessie.gfx)) or "ABSENT")
  F.check("James spawned in camera range at (20,2)",
    james ~= nil and james.x == 20 and james.y == 2,
    james and string.format("(%d,%d) %s", james.x, james.y, gfxName(james.gfx)) or "ABSENT")
  F.check("spawned Jessie is not MAGMA/LASS",
    jessie ~= nil and jessie.gfx ~= GFX_MAGMA_M and jessie.gfx ~= GFX_MAGMA_F and jessie.gfx ~= GFX_LASS,
    jessie and gfxName(jessie.gfx) or "ABSENT")
  F.check("spawned James is not MAGMA/LASS",
    james ~= nil and james.gfx ~= GFX_MAGMA_M and james.gfx ~= GFX_MAGMA_F and james.gfx ~= GFX_LASS,
    james and gfxName(james.gfx) or "ABSENT")
  F.check("Proton spawned at (14,3) once in range",
    proton ~= nil and proton.x == 14 and proton.y == 3,
    proton and string.format("(%d,%d) %s", proton.x, proton.y, gfxName(proton.gfx)) or "ABSENT")
  assertAlive("at_corridor")

  -- Fight the gate: talking from (22,2) facing west starts the duo, then they removeobject.
  if walked then
    F.face("Left")
    F.press("A", 3); F.idle(40)
    local started = waitBattle("jj", 900)
    F.check("Jessie/James battle started from the east approach tile", started,
      string.format("ow=%s battlers=%d", tostring(F.ow()), F.battlers()))
    if started then
      local back = forceWinUntil(function() return F.ow() end, "jj_win", 2400)
      F.check("returned to overworld after Jessie/James", back)
      for _ = 1, 240 do
        if findLocal(eachObj(), LOCALID_JESSIE) == nil then break end
        F.press("A", 2); F.idle(6)
      end
      objs = dumpObjs("after_jj")
      F.check("Jessie removed after the battle", findLocal(objs, LOCALID_JESSIE) == nil)
      F.check("James removed after the battle", findLocal(objs, LOCALID_JAMES) == nil)
      F.check("FLAG_HIDE_JESSIE_JAMES_SLOWPOKE_WELL is set",
        sb1FlagGet(FLAG_HIDE_JESSIE_JAMES_SLOWPOKE_WELL))
      occ = occupiedSet(objs)
      px, py = F.pos()
      toProton = bfs(px, py, 14, 3, occ, true)
      F.check("Proton path opens after Jessie/James are gone",
        toProton ~= nil, toProton and ((#toProton - 1) .. " steps") or "still cut")
      F.shot("after_jj")
    end
  end
  assertAlive("after_jj")

  -- Drive Proton if the gate is gone. Approach from the south (14,4), facing up.
  objs = dumpObjs("pre_proton")
  proton = findLocal(objs, LOCALID_PROTON)
  local droveKurt = false
  if proton and findLocal(eachObj(), LOCALID_JESSIE) == nil then
    -- Corridor drops south at x=20 (y=7 x=19 is solid). Then along row 8 through the old door.
    local toSouth = { {20, 2}, {20, 8}, {14, 8}, {14, 4} }
    local reached = F.route(toSouth, "to_proton")
    F.check("reached Proton's tile from the west approach",
      reached and select(1, F.pos()) == 14 and select(2, F.pos()) == 4,
      string.format("at (%d,%d)", select(1, F.pos()), select(2, F.pos())))
    F.shot("at_proton")
    if reached then
      F.face("Up")
      F.press("A", 3); F.idle(40)
      local started = waitBattle("proton", 1200)
      F.check("Proton battle started", started,
        string.format("ow=%s battlers=%d", tostring(F.ow()), F.battlers()))
      if started then
        -- Cutscene: fade, addobject Kurt, walk, msgbox, warp to Kurt's house.
        local home = forceWinUntil(function()
          return F.grp() == GRP_AZALEA_INDOOR and F.mapn() == MAP_KURTS_HOUSE
        end, "proton_win", 3600)
        if not home then home = mashUntilMap(GRP_AZALEA_INDOOR, MAP_KURTS_HOUSE, "proton_home", 1200) end
        F.check("Proton scene warped to MAP_AZALEA_TOWN_KURTS_HOUSE", home,
          string.format("grp=%d map=%d", F.grp(), F.mapn()))
        droveKurt = home
        F.shot("after_proton")
      end
    end
  else
    F.L("  skip Proton drive: Proton missing or Jessie still on the map")
  end
  assertAlive("after_proton")

  -- B. Rocket-beaten / Kurt-scene-armed reload. Standing Kurt's hide flag is re-set by
  -- ON_TRANSITION, so a Continue/warp must not park him on (17,8).
  armKurtSceneFlags()
  if not warpWell(1, "well_armed", true, 11, 19) then
    F.check("reload Slowpoke Well with Kurt scene flags armed", false)
  else
    F.check("reloaded B1F via warp 1 (west/Proton side)", F.grp() == GRP_WELL and F.mapn() == MAP_B1F)
    F.shot("well_armed")
    objs = dumpObjs("armed")
    assertAlive("well_armed")
    choke = findAt(objs, 17, 8)
    F.check("armed reload: nothing on the old door tile (17,8)", #choke == 0,
      #choke > 0 and string.format("localId %d (%d,%d) %s", choke[1].localId, choke[1].x, choke[1].y, gfxName(choke[1].gfx)) or "clear")
    kurtStand = findLocal(objs, LOCALID_KURT_STANDING)
    if kurtStand then
      F.check("standing Kurt is at (14,8), not the (17,8) choke",
        kurtStand.x == 14 and kurtStand.y == 8,
        string.format("(%d,%d)", kurtStand.x, kurtStand.y))
      F.check("standing Kurt is GFX_KURT", kurtStand.gfx == GFX_KURT, gfxName(kurtStand.gfx))
      -- Drive A on him if we are not already in his house from the Proton scene.
      if not droveKurt then
        local toKurt = F.route({ {15, 8} }, "to_standing_kurt")
        F.check("walked to (15,8) beside standing Kurt", toKurt)
        if toKurt then
          F.face("Left")
          F.press("A", 3); F.idle(30)
          local home = mashUntilMap(GRP_AZALEA_INDOOR, MAP_KURTS_HOUSE, "kurt_talk", 1800)
          F.check("talking to standing Kurt warps to MAP_AZALEA_TOWN_KURTS_HOUSE", home,
            string.format("grp=%d map=%d", F.grp(), F.mapn()))
          droveKurt = home
          F.shot("after_kurt_talk")
        end
      else
        F.L("  standing Kurt present; Proton scene already walked us home, not re-talking")
      end
    else
      F.L("  standing Kurt did not spawn (ON_TRANSITION re-hid him). That is the stale-save fix;")
      F.L("  the template tile is (14,8), so even a spawn would not seal (17,8).")
      F.check("standing Kurt not occupying any tile after armed reload", true, "hidden by ON_TRANSITION")
    end
  end

  F.check("Kurt walk-home scene reached MAP_AZALEA_TOWN_KURTS_HOUSE this run", droveKurt,
    droveKurt and "Proton cutscene (and/or standing-Kurt talk) warped home"
      or "neither Proton cutscene nor standing-Kurt talk produced MAP_AZALEA_TOWN_KURTS_HOUSE")
  -- The armed-reload probe returns to B1F on purpose; do not require we still sit in the house.
  assertAlive("end")

  F.finish()
end)
