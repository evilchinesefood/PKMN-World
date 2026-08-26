-- INSTRUMENTATION PROBE (not a promoted suite) -- Route 37 red-crash investigation.
--
-- Goal: exercise the Route36 <-> Route37 map CONNECTION crossing on foot (not a warp), with a
-- follower Pokemon out, and sample gObjectEvents/gSprites pool occupancy every frame around the
-- crossing so an "Out of sprite slots" fatal_assertf (src/sprite.c:436, via
-- TrySetupObjectEventSprite -> CreateSprite in src/event_object_movement.c:1891) can be caught
-- and correlated with slot pressure instead of just reported as an opaque hang.
--
-- Southbound first (Route37 -> Route36): Route37 IS reachable by warp (its only warps, both to
-- Ecruteak, sit at (17,10)/(18,10)); Route36 is not reachable by warp at all. Route37's south
-- edge connects to Route36 with offset -22 (map.json). BFS over Route37's own collision layout
-- (Testing scratch, not checked in) found an open corridor (17,10)->(17,21)->(15,21)->(15,40).
--
-- Run: Testing/mgba-run.sh Testing/lua/Route37CrossingProbe.lua

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "Route37CrossingProbe")

local HUB_GROUP = 100
local GRP_ROUTE37, MAP_ROUTE37, WARP_ROUTE37 = 83, 3, 0  -- Route 37, warp 0 = (17,10) from Ecruteak
local FOLLOWER = 0xFE
local ROW_GIVE, ROW_MON_BASIC = 3, 1

local function d(n) return (n // 100) % 10, (n // 10) % 10, n % 10 end

-- Give X… / Pokémon (Basic): species spinner starts at 1, digit 0 = ones. Oddish=43 (Grass/Poison,
-- irrelevant here -- any species with a walk animation works; reusing FollowerOutdoors' recipe).
local function giveOddish()
  F.dbg(); F.idle(60)
  for _ = 1, ROW_GIVE do F.press("Down", 3); F.idle(16) end
  F.press("A", 3); F.idle(50)
  for _ = 1, ROW_MON_BASIC do F.press("Down", 3); F.idle(16) end
  F.press("A", 3); F.idle(40)
  F.press("Right", 2); F.idle(10)
  for _ = 1, 4 do F.press("Up", 2); F.idle(8) end
  F.press("Left", 2); F.idle(10)
  for _ = 1, 2 do F.press("Up", 2); F.idle(8) end
  F.press("A", 3); F.idle(30)
  for _ = 1, 9 do F.press("Up", 2); F.idle(8) end  -- level 10
  F.press("A", 3); F.idle(60)
  for _ = 1, 8 do F.press("B", 3); F.idle(20) end
end

local function obj(localId)
  for i = 0, 15 do
    local b = S.gObjectEvents + i * S.ObjectEvent.stride
    if (F.r8(b) & 1) == 1 and F.r8(b + S.ObjectEvent.localId) == localId then
      return { i = i, b = b,
        invisible = (F.r8(b + S.ObjectEvent.flags1) & 0x20) ~= 0 }
    end
  end
  return nil
end

-- Route37's corridor is tall grass -- wild encounters interrupt F.step (coords don't change, so
-- it reports "blocked" even though nothing is actually obstructing the tile). Mash B then A until
-- back in the overworld (memory: "the settle loop must mash A as well as B; a wild battle does
-- not exit on B alone" -- route37-red-crash-unfound.md).
local function settleBattle()
  if F.ow() then return true end
  F.L("  wild encounter interrupted movement, settling...")
  for _ = 1, 400 do
    if F.ow() then F.idle(20); return true end
    F.press("B", 2); F.idle(4)
    F.press("A", 2); F.idle(6)
  end
  return F.ow()
end

-- F.leg gives up (and calls reportCrash) the first time step() reports "blocked", which is
-- exactly what a wild-battle interrupt looks like from the outside. Retry through any number of
-- encounters as long as we keep landing back in the overworld.
local function legSafe(tx, ty, tries)
  for _ = 1, (tries or 8) do
    if F.leg(tx, ty) then return true end
    if not F.ow() then
      if not settleBattle() then return false end
    else
      return false -- genuinely blocked (not a battle) -- leg() already logged + shot it
    end
  end
  return false
end

-- Count active gObjectEvents slots (0..15) and in-use gSprites slots (0..63).
local function census()
  local oe, sp = 0, 0
  for i = 0, 15 do
    local b = S.gObjectEvents + i * S.ObjectEvent.stride
    if (F.r8(b) & 1) == 1 then oe = oe + 1 end
  end
  for i = 0, 63 do
    local b = S.gSprites + i * S.Sprite.stride
    if (F.r16(b + S.Sprite.inUse) & 1) == 1 then sp = sp + 1 end
  end
  return oe, sp
end

F.run(function()
  if not F.boot(HUB_GROUP) then F.check("boot to the hub", false); F.finish(); return end
  F.idle(40)

  giveOddish()
  local n = F.r8(S.gPartiesCount)
  F.check("Give gave a party member", n ~= 0, "count=" .. n)

  local gh, gt, go_ = d(GRP_ROUTE37)
  local mh, mt, mo = d(MAP_ROUTE37)
  local wh, wt, wo = d(WARP_ROUTE37)
  if not F.warpTo(gh, gt, go_, mh, mt, mo, wh, wt, wo, GRP_ROUTE37, MAP_ROUTE37, "route37") then
    F.check("warped to Route 37", false)
    F.finish(); return
  end
  F.idle(60)
  F.L(string.format("  arrived grp=%d map=%d pos=(%d,%d)", F.grp(), F.mapn(), F.pos()))

  -- Coax the follower visible (same trick as FollowerOutdoors.lua: warp respawns it invisible).
  local o
  for _, dir in ipairs({ "Down", "Left", "Right", "Up", "Down" }) do
    F.step(dir); F.idle(24)
    o = obj(FOLLOWER)
    if o and not o.invisible then break end
  end
  o = obj(FOLLOWER)
  F.check("follower is out before the crossing", o ~= nil and not o.invisible,
    o and "invisible" or "ABSENT")
  do
    local oe, sp = census()
    F.L(string.format("  census before walk: objEvents=%d/16 sprites=%d/64", oe, sp))
  end

  -- BFS'd open corridor down Route37's own layout to its south edge (y=40), avoiding the object
  -- events clustered off to the sides. See header comment.
  local waypoints = {
    {17, 21}, {15, 21}, {15, 40},
  }
  local stuck = false
  for _, wp in ipairs(waypoints) do
    if not legSafe(wp[1], wp[2]) then
      F.L(string.format("  route stuck heading to (%d,%d), pos=(%d,%d)", wp[1], wp[2], F.pos()))
      F.shot("stuck_" .. wp[1] .. "_" .. wp[2])
      stuck = true
      break
    end
    local oe, sp = census()
    local x, y = F.pos()
    F.L(string.format("  at (%d,%d) grp=%d map=%d objEvents=%d/16 sprites=%d/64", x, y, F.grp(), F.mapn(), oe, sp))
    if F.reportCrash("waypoint_" .. wp[1] .. "_" .. wp[2]) then F.finish(); return end
  end
  F.check("reached the pre-crossing waypoint", not stuck, "pos=" .. table.concat({F.pos()}, ","))

  -- Step repeatedly through the actual connection crossing, sampling every single step (not just
  -- at waypoints) since the crash -- if it exists -- fires inside TrySpawnObjectEvents /
  -- CameraUpdate on the frame the connection triggers, not on a settled tile.
  local function crossingWalk(dir, steps, tag)
    local crashed = false
    local maxOE, maxSP = 0, 0
    for i = 1, steps do
      local before_grp, before_map = F.grp(), F.mapn()
      local moved = F.step(dir)
      if F.reportCrash(tag .. "_" .. i) then crashed = true; break end
      if not moved and not F.ow() then
        if not settleBattle() then F.L("  never returned from battle, stopping"); break end
        if F.reportCrash(tag .. "_" .. i .. "_postbattle") then crashed = true; break end
        moved = true -- treat as a non-blocking interruption, keep walking
      end
      local oe, sp = census()
      if oe > maxOE then maxOE = oe end
      if sp > maxSP then maxSP = sp end
      local x, y = F.pos()
      F.L(string.format("  [%s] step %d moved=%s pos=(%d,%d) grp=%d map=%d objEvents=%d/16 sprites=%d/64",
        tag, i, tostring(moved), x, y, F.grp(), F.mapn(), oe, sp))
      if before_grp ~= F.grp() or before_map ~= F.mapn() then
        F.L(string.format("  *** MAP TRANSITION at step %d: (%d,%d) -> (%d,%d) ***",
          i, before_grp, before_map, F.grp(), F.mapn()))
      end
      if not moved then
        F.L("  [" .. tag .. "] step blocked, stopping")
        break
      end
    end
    F.L(string.format("  [%s] peak: objEvents=%d/16 sprites=%d/64", tag, maxOE, maxSP))
    return crashed, maxOE, maxSP
  end

  local crashedS, maxOE_S, maxSP_S = crossingWalk("Down", 25, "southbound")
  F.check("no crash crossing SOUTH (Route37 -> Route36)", not crashedS)
  F.check("ended on Route 36 (grp=83 map=2) after southbound crossing",
    F.grp() == 83 and F.mapn() == 2, string.format("grp=%d map=%d", F.grp(), F.mapn()))
  F.shot("post_southbound")

  -- This is the literal reported scenario: entering Route 37 FROM THE BOTTOM (walking north out
  -- of Route 36), with a follower out. Turn around and walk back north through the SAME physical
  -- corridor (Route36's north border is a single ~9-tile-wide gap at x=33..41 -- confirmed by a
  -- host-side collision scan; nothing else in that row is walkable) back into Route 37.
  if not crashedS then
    local crashedN, maxOE_N, maxSP_N = crossingWalk("Up", 25, "northbound")
    F.check("no crash crossing NORTH (Route36 -> Route37, the reported direction)", not crashedN)
    F.check("ended on Route 37 (grp=83 map=3) after northbound crossing",
      F.grp() == 83 and F.mapn() == 3, string.format("grp=%d map=%d", F.grp(), F.mapn()))
    F.shot("post_northbound")

    -- "Shortly after entering" (the report's wording) suggests the crash isn't on the border
    -- tile itself but a few steps further in. Keep walking north/back toward the warp, through
    -- Route 37's own object cluster (LIGHT_SPRITEs at (14,13)/(21,13)/(21,23)/(8,23), day/night
    -- mons VULPIX(17,7)/PIDGEY(18,7)) so UpdateJohtoDayNightFlags-driven spawns are exercised too.
    if not crashedN then
      local deeper = { {15, 21}, {17, 21}, {17, 13}, {17, 10} }
      for _, wp in ipairs(deeper) do
        if not legSafe(wp[1], wp[2]) then
          F.L(string.format("  post-crossing walk stuck heading to (%d,%d), pos=(%d,%d)", wp[1], wp[2], F.pos()))
          F.shot("deep_stuck_" .. wp[1] .. "_" .. wp[2])
          break
        end
        if F.reportCrash("deep_" .. wp[1] .. "_" .. wp[2]) then break end
        local oe, sp = census()
        local dx, dy = F.pos()
        F.L(string.format("  deep at (%d,%d) objEvents=%d/16 sprites=%d/64", dx, dy, oe, sp))
      end
      F.check("no crash walking deeper into Route 37 post-crossing", not F.reportCrash("deep_final"))
      F.shot("post_deep_walk")
    end
  end

  F.finish()
end)
