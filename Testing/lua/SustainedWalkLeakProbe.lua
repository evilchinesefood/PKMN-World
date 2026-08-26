-- INSTRUMENTATION PROBE (not a promoted suite) -- Route 37 red-crash investigation, H5 (retry).
--
-- The coordinator's correction: sprite-pool occupancy is RAM, not save data. Loading ANY save
-- (real or fresh) begins from a freshly-initialised pool via ResumeMap() -> ResetSpriteData(), so
-- a "baseline on load" measurement -- on the real save OR a fresh one -- can never speak to H5
-- (accumulation during hours of continuous non-warp play). That is why the previous round's real-
-- save baseline (3/16, 7/64) was ruled inconclusive rather than a disconfirmation.
--
-- H5 does not need the real save at all: the claim is about accumulation during ordinary walking,
-- which a fresh save can exhibit identically, and this sidesteps last round's real-save movement/
-- input anomaly entirely. Built directly on Route37CrossingProbe.lua's proven mechanics (fresh
-- hub boot, debug-given follower, the same corridor waypoints) rather than OwnerSaveLeakProbe.lua.
--
-- Protocol:
--   1. Warp ONCE (hub -> Route37), then NEVER warp again for the rest of the run. A warp calls
--      ResetSpriteData() and would erase exactly the accumulation signal under test.
--   2. Walk many laps back and forth across the Route36/Route37 connection (crossing it, which
--      does NOT reset the pool -- see LoadMapFromCameraTransition, src/overworld.c:908) and across
--      Route37's own object-dense stretch (4 LIGHT_SPRITEs, day/night VULPIX/PIDGEY).
--   3. Sample gObjectEvents/gSprites on every single tile, every step, for the whole run.
--   4. The signal is monotonicity of the PER-LAP FLOOR (minimum), not the peak. A pool that
--      oscillates 7..27 forever is healthy; a floor that creeps upward lap over lap is the leak.
--   5. If the floor climbs, dump the object list at each lap's floor moment so the diff shows
--      exactly what graphicsId/localId is newly present and persisting.
--
-- Run: Testing/mgba-run.sh Testing/lua/SustainedWalkLeakProbe.lua

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "SustainedWalkLeakProbe")

local HUB_GROUP = 100
local GRP_ROUTE37, MAP_ROUTE37, WARP_ROUTE37 = 83, 3, 0  -- Route 37, warp 0 = (17,10)
local FOLLOWER = 0xFE
local ROW_GIVE, ROW_MON_BASIC = 3, 1
local LAPS = tonumber(os.getenv and os.getenv("PW_LAPS") or "") or 40

local function d(n) return (n // 100) % 10, (n // 10) % 10, n % 10 end

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
  -- Level 100, not 10: a lone level-10 Oddish CAN lose to Route36/37's wild mons (STANTLER,
  -- GROWLITHE, PIDGEOTTO...), and a whiteout is a WARP -- SetWarpDestination + a warp-style map
  -- load -- which calls ResetSpriteData() and silently destroys the exact "no warps for the whole
  -- run" invariant this probe depends on. Discovered the hard way: a first attempt at this walk
  -- teleported to Petalburg City (the fresh save's heal location) mid-lap after a wild battle the
  -- level-10 follower lost. The level spinner clamps at 100 (BizHawkTesting.md), so over-pressing
  -- is safe.
  for _ = 1, 99 do F.press("Up", 2); F.idle(8) end
  F.press("A", 3); F.idle(60)
  for _ = 1, 8 do F.press("B", 3); F.idle(20) end
end

-- ---- census -------------------------------------------------------------------------------
local function census()
  local oe, sp = 0, 0
  local active = {}
  for i = 0, 15 do
    local b = S.gObjectEvents + i * S.ObjectEvent.stride
    if (F.r8(b) & 1) == 1 then
      oe = oe + 1
      active[i] = {
        gfx = F.r16(b + S.ObjectEvent.graphicsId),
        localId = F.r8(b + S.ObjectEvent.localId),
        x = F.rs16(b + S.ObjectEvent.x) - 7,
        y = F.rs16(b + S.ObjectEvent.y) - 7,
      }
    end
  end
  for i = 0, 63 do
    local b = S.gSprites + i * S.Sprite.stride
    if (F.r16(b + S.Sprite.inUse) & 1) == 1 then sp = sp + 1 end
  end
  return oe, sp, active
end

local function dumpActive(active)
  local parts = {}
  for i, o in pairs(active) do
    parts[#parts + 1] = string.format("slot%d=id%d,gfx0x%04X@(%d,%d)", i, o.localId, o.gfx, o.x, o.y)
  end
  table.sort(parts)
  return table.concat(parts, " ")
end

-- ---- movement (proven in Route37CrossingProbe.lua) -------------------------------------------
local GRP_JOHTO_ROUTES = 83  -- Route36/Route37's shared group
local invariantBroken = false  -- set TRUE if a whiteout/unexpected warp is ever detected

local function settleBattle()
  if F.ow() then return true end
  for _ = 1, 400 do
    if F.ow() then
      F.idle(20)
      -- Belt-and-suspenders for the level-100 fix: if the follower's party somehow still lost
      -- (or anything else warped us away -- a whiteout is SetWarpDestination + a warp-style load),
      -- we are no longer in the warp-free walk this probe promises. Catch it explicitly rather
      -- than silently mis-measuring: an out-of-Johto map here means ResetSpriteData() already
      -- fired without this script knowing, and every sample from here on is contaminated.
      if F.grp() ~= GRP_JOHTO_ROUTES then
        F.L(string.format("  *** INVARIANT BROKEN: settled at grp=%d map=%d (%d,%d), not Route36/37 ***",
          F.grp(), F.mapn(), F.pos()))
        F.L("  *** this means a whiteout or other unexpected warp happened -- ResetSpriteData() fired ***")
        invariantBroken = true
        return false
      end
      return true
    end
    F.press("B", 2); F.idle(4)
    F.press("A", 2); F.idle(6)
  end
  return F.ow()
end

local function legSafe(tx, ty, tries)
  for _ = 1, (tries or 8) do
    if F.leg(tx, ty) then return true end
    if not F.ow() then
      if not settleBattle() then return false end
    else
      return false
    end
  end
  return false
end

-- ---- global tracking across the ENTIRE run ------------------------------------------------
local totalSteps = 0
local runMaxOE, runMaxSP = 0, 0
local runMinOE, runMinSP = 999, 999
local crashedGlobal = false
local floorSeries = {}  -- per-lap {lapMinOE, lapMinSP, lapMaxOE, lapMaxSP, floorActive}

local function addRun(fromX, fromY, toX, toY)
  local path = {}
  local dx = (toX > fromX and 1) or (toX < fromX and -1) or 0
  local dy = (toY > fromY and 1) or (toY < fromY and -1) or 0
  local x, y = fromX, fromY
  while x ~= toX or y ~= toY do
    x = x + dx; y = y + dy
    path[#path + 1] = { x, y }
  end
  return path
end

-- THE connection crossing is not a walkable diagonal -- the game recomputes x/y via the
-- connection's offset transform (SetPositionFromConnection) the instant the player steps off the
-- map edge. It is always exactly ONE F.step() in the border direction (proven in
-- Route37CrossingProbe.lua: Down from Route37 (15,40) lands Route36 (37,0); Up from Route36 (37,0)
-- lands Route37 (15,40)), never a leg() walk toward the other map's coordinates.
local function crossStep(dir, tag, lapMinOE, lapMinSP)
  local moved = F.step(dir)
  if F.reportCrash(tag .. "_cross") then crashedGlobal = true; return lapMinOE, lapMinSP, nil, nil, false end
  if not moved and not F.ow() then
    if not settleBattle() then return lapMinOE, lapMinSP, nil, nil, false end
    if F.reportCrash(tag .. "_cross_postbattle") then crashedGlobal = true; return lapMinOE, lapMinSP, nil, nil, false end
  elseif not moved then
    return lapMinOE, lapMinSP, nil, nil, false
  end
  local oe, sp, active = census()
  totalSteps = totalSteps + 1
  if oe > runMaxOE then runMaxOE = oe end
  if sp > runMaxSP then runMaxSP = sp; F.L(string.format("  [%s] NEW RUN-MAX sprites=%d/64 at step %d (%s)", tag, sp, totalSteps, dumpActive(active))) end
  if oe < runMinOE then runMinOE = oe end
  if sp < runMinSP then runMinSP = sp end
  local floorDump, floorAt = nil, nil
  if oe < lapMinOE then lapMinOE = oe end
  if sp < lapMinSP then
    lapMinSP = sp
    floorDump = dumpActive(active)
    floorAt = tag .. "_cross pos=" .. table.concat({ F.pos() }, ",")
  end
  return lapMinOE, lapMinSP, floorDump, floorAt, true
end

-- Walk a tile-by-tile path WITHIN one map, sampling census on EVERY tile. Returns lap-local
-- min/max and whether it completed, plus the active-object dump at whichever step produced the
-- lap-local sprite min (the "floor moment").
local function walkPath(path, tag, lapMinOE, lapMinSP)
  local floorDump, floorAt = nil, nil
  for idx, wp in ipairs(path) do
    if not legSafe(wp[1], wp[2]) then
      F.L(string.format("  [%s] stuck at step %d heading to (%d,%d), pos=(%d,%d)", tag, idx, wp[1], wp[2], F.pos()))
      F.shot(tag .. "_stuck_" .. idx)
      return lapMinOE, lapMinSP, floorDump, floorAt, false
    end
    if F.reportCrash(tag .. "_" .. idx) then crashedGlobal = true; return lapMinOE, lapMinSP, floorDump, floorAt, false end
    local oe, sp, active = census()
    totalSteps = totalSteps + 1
    if oe > runMaxOE then runMaxOE = oe end
    if sp > runMaxSP then runMaxSP = sp; F.L(string.format("  [%s] NEW RUN-MAX sprites=%d/64 at step %d (%s)", tag, sp, totalSteps, dumpActive(active))) end
    if oe < runMinOE then runMinOE = oe end
    if sp < runMinSP then runMinSP = sp end
    if oe < lapMinOE then lapMinOE = oe end
    if sp < lapMinSP then
      lapMinSP = sp
      floorDump = dumpActive(active)
      floorAt = string.format("%s_%d pos=(%d,%d)", tag, idx, wp[1], wp[2])
    end
  end
  return lapMinOE, lapMinSP, floorDump, floorAt, true
end

F.run(function()
  if not F.boot(HUB_GROUP) then F.check("boot to the hub", false); F.finish(); return end
  F.idle(40)
  giveOddish()
  local n = F.r8(S.gPartiesCount)
  F.check("Give gave a party member", n ~= 0, "count=" .. n)

  -- THE ONLY WARP in this run.
  local gh, gt, go_ = d(GRP_ROUTE37)
  local mh, mt, mo = d(MAP_ROUTE37)
  local wh, wt, wo = d(WARP_ROUTE37)
  if not F.warpTo(gh, gt, go_, mh, mt, mo, wh, wt, wo, GRP_ROUTE37, MAP_ROUTE37, "route37") then
    F.check("warped to Route 37", false); F.finish(); return
  end
  F.idle(60)
  F.L("  ONLY WARP OF THE RUN complete. Everything from here is warp-free walking.")

  local o
  local function findFollower()
    for i = 0, 15 do
      local b = S.gObjectEvents + i * S.ObjectEvent.stride
      if (F.r8(b) & 1) == 1 and F.r8(b + S.ObjectEvent.localId) == FOLLOWER then
        return (F.r8(b + S.ObjectEvent.flags1) & 0x20) == 0
      end
    end
    return false
  end
  for _, dir in ipairs({ "Down", "Left", "Right", "Up", "Down" }) do
    F.step(dir); F.idle(24)
    if findFollower() then break end
  end
  F.check("follower is out before the walk", findFollower())

  if not legSafe(17, 21) then F.check("reached pre-corridor waypoint", false); F.finish(); return end
  if not legSafe(15, 21) then F.check("reached pre-corridor waypoint 2", false); F.finish(); return end
  if not legSafe(15, 40) then F.check("reached Route37 edge", false); F.finish(); return end
  F.L(string.format("  at Route37 edge (15,40), starting %d laps, warp-free from here on", LAPS))

  local startTime = os.clock and os.clock() or 0
  local lastLapFloorDump, lastLapFloorAt = nil, nil  -- outer scope: survives past the loop

  for lap = 1, LAPS do
    if crashedGlobal then break end
    local lapMinOE, lapMinSP = 999, 999
    local lapFloorDump, lapFloorAt = nil, nil
    local completedLap = true
    local tag = string.format("lap%d", lap)

    -- Cross south (Route37 -> Route36) -- ONE step, not a walkPath (see crossStep's comment) --
    -- dip into Route36's open pocket and back, cross north (Route36 -> Route37), walk up into
    -- the light-sprite/day-night-mon stretch and back.
    local ok
    local dumpOut, atOut

    lapMinOE, lapMinSP, dumpOut, atOut, ok = crossStep("Down", tag .. "_southcross", lapMinOE, lapMinSP)
    if dumpOut then lapFloorDump, lapFloorAt = dumpOut, atOut end
    if ok then
      lapMinOE, lapMinSP, dumpOut, atOut, ok = walkPath(addRun(37, 0, 37, 6), tag .. "_r36in", lapMinOE, lapMinSP)
      if dumpOut then lapFloorDump, lapFloorAt = dumpOut, atOut end
    end
    if ok then
      lapMinOE, lapMinSP, dumpOut, atOut, ok = walkPath(addRun(37, 6, 37, 0), tag .. "_r36out", lapMinOE, lapMinSP)
      if dumpOut then lapFloorDump, lapFloorAt = dumpOut, atOut end
    end
    if ok then
      lapMinOE, lapMinSP, dumpOut, atOut, ok = crossStep("Up", tag .. "_northcross", lapMinOE, lapMinSP)
      if dumpOut then lapFloorDump, lapFloorAt = dumpOut, atOut end
    end
    if ok then
      lapMinOE, lapMinSP, dumpOut, atOut, ok = walkPath(addRun(15, 40, 15, 15), tag .. "_r37in", lapMinOE, lapMinSP)
      if dumpOut then lapFloorDump, lapFloorAt = dumpOut, atOut end
    end
    if ok then
      lapMinOE, lapMinSP, dumpOut, atOut, ok = walkPath(addRun(15, 15, 15, 40), tag .. "_r37out", lapMinOE, lapMinSP)
      if dumpOut then lapFloorDump, lapFloorAt = dumpOut, atOut end
    end
    completedLap = ok

    if crashedGlobal then break end

    floorSeries[#floorSeries + 1] = { lap = lap, minOE = lapMinOE, minSP = lapMinSP, completed = completedLap }
    if lapFloorDump then lastLapFloorDump, lastLapFloorAt = lapFloorDump, lapFloorAt end
    F.L(string.format("  LAP %d/%d %s: floor oe=%d sp=%d | runMax oe=%d sp=%d | runMin oe=%d sp=%d | steps=%d",
      lap, LAPS, completedLap and "ok" or "INCOMPLETE", lapMinOE, lapMinSP, runMaxOE, runMaxSP,
      runMinOE, runMinSP, totalSteps))

    if not completedLap then
      F.L("  lap did not complete (stuck); stopping the walk here")
      break
    end
  end

  local elapsed = (os.clock and os.clock() or 0) - startTime
  F.L(string.format("== walk complete: %d steps, %d laps, %.1fs wall ==", totalSteps, #floorSeries, elapsed))

  -- ---- the actual verdict: is the per-lap floor monotonically rising? -------------------------
  F.L("  per-lap floor series (sprites): ")
  local floorLine = {}
  for _, r in ipairs(floorSeries) do floorLine[#floorLine + 1] = tostring(r.minSP) end
  F.L("    " .. table.concat(floorLine, ","))

  local risingLaps, lastFloor = 0, nil
  local maxRisingRun, curRisingRun = 0, 0
  for _, r in ipairs(floorSeries) do
    if lastFloor ~= nil then
      if r.minSP > lastFloor then
        risingLaps = risingLaps + 1
        curRisingRun = curRisingRun + 1
        if curRisingRun > maxRisingRun then maxRisingRun = curRisingRun end
      else
        curRisingRun = 0
      end
    end
    lastFloor = r.minSP
  end

  local firstFloor = floorSeries[1] and floorSeries[1].minSP or nil
  local lastFloorVal = floorSeries[#floorSeries] and floorSeries[#floorSeries].minSP or nil
  local netClimb = (firstFloor and lastFloorVal) and (lastFloorVal - firstFloor) or nil

  F.check(string.format("ran a meaningful number of steps (>=500)"), totalSteps >= 500,
    "totalSteps=" .. totalSteps)
  F.check("no crash during the sustained warp-free walk", not crashedGlobal)
  F.check("the warp-free invariant held for the whole run (no whiteout/unexpected warp)",
    not invariantBroken)
  F.check(string.format("per-lap sprite FLOOR did not climb (longest consecutive-rising run < %d laps)",
    math.max(3, LAPS // 4)),
    maxRisingRun < math.max(3, LAPS // 4),
    string.format("longest rising run=%d laps, first floor=%s last floor=%s net=%s",
      maxRisingRun, tostring(firstFloor), tostring(lastFloorVal), tostring(netClimb)))

  if lastLapFloorDump then
    F.L("  floor moment at last completed lap: " .. tostring(lastLapFloorAt))
    F.L("  active objects at that floor: " .. tostring(lastLapFloorDump))
  end

  F.shot("final")
  F.finish()
end)
