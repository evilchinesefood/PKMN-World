-- INSTRUMENTATION PROBE (not a promoted suite) -- Route 37 red-crash investigation, H4.
--
-- H4: does the Johto day/night flip landing WHILE (or immediately around) a live connection
-- crossing corrupt object state, unlike the ordinary case (flip while stationary, handled by the
-- deferred TryRefreshJohtoDayNightObjects()) or a fully-settled crossing (H1/H2/H3, already
-- disconfirmed by Route37CrossingProbe.lua)?
--
-- Code-reading context (src/overworld.c OverworldBasic(), read this session):
--   CameraUpdate() [the crossing: LoadMapFromCameraTransition, TrySpawnObjectEvents] runs BEFORE
--   the TOD tick check in the SAME per-frame function, and TryRefreshJohtoDayNightObjects() runs
--   every frame right after the tick check. LoadMapFromCameraTransition itself calls
--   UpdateJohtoDayNightFlags()/ClearJohtoDayNightRefresh() fresh, synchronously, as part of the
--   transition -- so a newly-loaded map's objects are always built against whatever the clock says
--   AT THAT INSTANT, and the periodic tick / deferred refresh are a separate, later step in the
--   same frame loop that only matters for a STATIONARY player. This reads as self-consistent by
--   design, which is why H4 was disconfirmed on code reading alone last round -- but code reading
--   is not a controlled reproduction, so this probe drives it for real across three alignments,
--   both directions, both polarities (12 scenarios), per the coordinator's brief.
--
-- Clock levers (Testing/lua/MANIFEST.md ~line 263, and JohtoDayNightLive.lua's proven recipe):
--   SaveBlock2.localTimeOffset (survives a warp; gLocalTime = sRtc - localTimeOffset, so winding
--   the offset FORWARD winds the clock BACK) + zeroing gTimeUpdateCounter (what SetTimeOfDay does
--   to force the periodic tick, and therefore UpdateJohtoDayNightFlags()+the deferred refresh, to
--   fire on the very next frame instead of waiting out the ~180-frame/~3s period).
--
-- Alignment definitions (per-tile stepping is this harness's finest granularity; frame-level
-- placement within a single F.step() call is approximated, and that approximation is named
-- explicitly at each call site below):
--   BEFORE : inject the flip while standing at the edge tile, then idle(60) -- long enough for the
--            tick AND the deferred refresh to fully resolve -- before starting the crossing step.
--            The loader therefore sees fully-settled NEW-polarity flags.
--   ON     : inject the flip (zero the counter) with NO idle, then immediately start the crossing
--            step. The tick fires on the crossing step's very first advanced frame, landing the
--            flag flip + deferred refresh within (near the start of) the same multi-frame step
--            that contains the border crossing -- the closest this harness can land the flip
--            relative to CameraUpdate() actually executing LoadMapFromCameraTransition.
--   AFTER  : cross normally under the OLD polarity, arrive, then inject the flip and continue
--            walking deeper (2-3 more tiles) so the deferred refresh runs against the newly
--            loaded, already-settled map -- issue #56 item 1's ordinary case, but immediately
--            after a crossing rather than long after one.
--
-- Uses a FRESH save (hub boot + debug-given follower), not the real save: H4 is about timing, not
-- accumulated state, and the real save hit a reproducible movement/input anomaly in the previous
-- probe that has nothing to do with this hypothesis. If that anomaly reappears here anyway (it
-- shouldn't, this never touches a real save), note it and treat it as a hard stop for that
-- scenario, not a game bug.
--
-- Run: Testing/mgba-run.sh Testing/lua/DayNightCrossingProbe.lua

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "DayNightCrossingProbe")

local HUB_GROUP = 100
local GRP_ROUTE37, MAP_ROUTE37, WARP_ROUTE37 = 83, 3, 0  -- Route 37, warp 0 = (17,10)
local FOLLOWER = 0xFE
local ROW_GIVE, ROW_MON_BASIC = 3, 1

local FLAG_JOHTO_BASE = 0x6000
local FLAG_DAY_POKEMON, FLAG_NIGHT_POKEMON = 0x6040, 0x6041
local NIGHT_HOUR, DAY_HOUR = 22, 14

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
  for _ = 1, 9 do F.press("Up", 2); F.idle(8) end
  F.press("A", 3); F.idle(60)
  for _ = 1, 8 do F.press("B", 3); F.idle(20) end
end

-- ---- day/night levers (JohtoDayNightLive.lua's proven recipe) --------------------------------
local function johtoFlag(id)
  local a = F.sb3() + S.SaveBlock3.johtoFlags + ((id - FLAG_JOHTO_BASE) // 8)
  return (F.r8(a) & (1 << (id % 8))) ~= 0
end

local function localTime()
  return F.rs8(S.gLocalTime + S.Time.hours), F.rs8(S.gLocalTime + S.Time.minutes)
end

-- gLocalTime = sRtc - localTimeOffset: winding the offset FORWARD winds the clock BACK. This only
-- moves gLocalTime; it does NOT itself flip the flags or refresh objects -- call armTick() (or
-- just wait ~180 frames) for that.
local function setLocalTime(targetHour)
  local off = F.sb2() + S.SaveBlock2.localTimeOffset
  local h, m = localTime()
  local deltaMin = ((h * 60 + m) - (targetHour * 60 + 30)) % (24 * 60)
  local newMin = F.rs8(off + S.Time.minutes) + (deltaMin % 60)
  local carry = 0
  if newMin >= 60 then newMin, carry = newMin - 60, 1 end
  F.w8(off + S.Time.minutes, newMin % 60)
  F.w8(off + S.Time.hours, (F.rs8(off + S.Time.hours) + (deltaMin // 60) + carry) % 24)
end

-- Force the periodic tick to fire on the NEXT frame advance instead of waiting out ~180 frames.
-- This is exactly what SetTimeOfDay() does (MANIFEST.md ~line 263).
local function armTick()
  F.w16(S.gTimeUpdateCounter, 0)
end

-- Set the clock AND arm the tick with no frame advance between the two writes, so the tick cannot
-- fire in the gap between them (both take effect on the SAME next frame).
local function flipTo(targetHour)
  setLocalTime(targetHour)
  armTick()
end

-- ---- object/sprite census (same shape as the other two probes this session) -------------------
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

local prevActive = {}
local function logCensus(tag)
  local oe, sp, active = census()
  local x, y = F.pos()
  local newOnes, goneOnes = {}, {}
  for i, o in pairs(active) do
    if prevActive[i] == nil then
      newOnes[#newOnes + 1] = string.format("slot%d=id%d,gfx0x%04X@(%d,%d)", i, o.localId, o.gfx, o.x, o.y)
    end
  end
  for i, o in pairs(prevActive) do
    if active[i] == nil then
      goneOnes[#goneOnes + 1] = string.format("slot%d=id%d,gfx0x%04X@(%d,%d)", i, o.localId, o.gfx, o.x, o.y)
    end
  end
  local extra = ""
  if #newOnes > 0 then extra = extra .. " NEW[" .. table.concat(newOnes, ",") .. "]" end
  if #goneOnes > 0 then extra = extra .. " GONE[" .. table.concat(goneOnes, ",") .. "]" end
  F.L(string.format("  [%s] pos=(%d,%d) grp=%d map=%d objEvents=%d/16 sprites=%d/64 day=%s night=%s%s",
    tag, x, y, F.grp(), F.mapn(), oe, sp, tostring(johtoFlag(FLAG_DAY_POKEMON)),
    tostring(johtoFlag(FLAG_NIGHT_POKEMON)), extra))
  prevActive = active
  return oe, sp
end

-- ---- movement (proven in Route37CrossingProbe.lua) ---------------------------------------------
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

local crashedGlobal = false
local function checkCrash(tag)
  if F.reportCrash(tag) then crashedGlobal = true; return true end
  return false
end

-- ---- the 12-scenario matrix ---------------------------------------------------------------------
-- ROUTE37_EDGE = (15,40), the tile that steps Down into Route36. ROUTE36_EDGE = (37,0), the tile
-- that steps Up into Route37 (both proven reachable/clear in Route37CrossingProbe.lua).
local ROUTE37_EDGE = { 15, 40 }
local ROUTE36_EDGE = { 37, 0 }

local results = {}

-- direction: "south" (Route37 edge -> Route36) or "north" (Route36 edge -> Route37)
-- alignment: "before" | "on" | "after"
-- targetNight: true -> flip TO night (starting from day); false -> flip TO day (starting from night)
local function runScenario(direction, alignment, targetNight)
  local tag = string.format("%s_%s_%s", direction, alignment, targetNight and "d2n" or "n2d")
  F.L(string.format("== scenario %s ==", tag))

  -- 1. Get to the correct edge tile for this direction (whichever side we ended the previous
  --    scenario on; both edges sit on the SAME proven-clear column, so a direct legSafe suffices).
  local edge = (direction == "south") and ROUTE37_EDGE or ROUTE36_EDGE
  if not legSafe(edge[1], edge[2]) then
    F.L("  could not reach the " .. direction .. " edge tile; skipping scenario")
    results[#results + 1] = { tag = tag, skipped = true }
    return
  end
  if checkCrash(tag .. "_getedge") then return end

  -- 2. Force the STARTING polarity (opposite of target) and let it fully settle while stationary,
  --    so the crossing begins from a clean, known state regardless of scenario order.
  flipTo(targetNight and DAY_HOUR or NIGHT_HOUR)
  F.idle(220)  -- well over one tick period (~180f); also lets any settle-triggered refresh finish
  if checkCrash(tag .. "_presettle") then return end
  local startOE, startSP = logCensus(tag .. "_start")

  local dir = (direction == "south") and "Down" or "Up"
  local wantHour = targetNight and NIGHT_HOUR or DAY_HOUR

  if alignment == "before" then
    flipTo(wantHour)
    F.idle(60)  -- let the tick + deferred refresh fully resolve BEFORE the crossing step begins
    if checkCrash(tag .. "_preflip") then return end
    logCensus(tag .. "_flipped_before_crossing")
  end

  if alignment == "on" then
    flipTo(wantHour)  -- no idle: the tick fires on the crossing step's own first frame
  end

  -- 3. THE crossing step itself.
  local before_grp, before_map = F.grp(), F.mapn()
  local moved = F.step(dir)
  if checkCrash(tag .. "_crossing_step") then return end
  if not moved and not F.ow() then
    if not settleBattle() then F.L("  never returned from battle during crossing; aborting scenario"); return end
    if checkCrash(tag .. "_crossing_step_postbattle") then return end
  end
  local crossedOE, crossedSP = logCensus(tag .. "_crossed")
  local didTransition = (before_grp ~= F.grp() or before_map ~= F.mapn())
  F.L(string.format("  transitioned=%s (%d/%d -> %d/%d)", tostring(didTransition),
    before_grp, before_map, F.grp(), F.mapn()))

  if alignment == "after" then
    flipTo(wantHour)
    logCensus(tag .. "_flipped_after_arrival")
  end

  -- 4. Walk a few tiles deeper (post-crossing settle / deferred-refresh window), sampling and
  --    crash-checking every step. Direction continues the same way we were travelling.
  local maxOE, maxSP = crossedOE, crossedSP
  local crashedHere = false
  for i = 1, 4 do
    local mv = F.step(dir)
    if checkCrash(tag .. "_deep_" .. i) then crashedHere = true; break end
    if not mv and not F.ow() then
      if not settleBattle() then break end
      if checkCrash(tag .. "_deep_" .. i .. "_postbattle") then crashedHere = true; break end
    end
    local oe, sp = logCensus(tag .. "_deep_" .. i)
    if oe > maxOE then maxOE = oe end
    if sp > maxSP then maxSP = sp end
    if not mv then break end
  end

  -- Verdict for this scenario: transition happened, no crash, flags match the intended target,
  -- and object/sprite pools stayed sane (no explosion, which would itself hint at a double-spawn).
  local flagsOk = johtoFlag(FLAG_DAY_POKEMON) == targetNight and johtoFlag(FLAG_NIGHT_POKEMON) == (not targetNight)
  F.check(tag .. "_no_crash", not crashedHere)
  F.check(tag .. "_transitioned", didTransition)
  F.check(tag .. "_flags_match_target", flagsOk,
    string.format("day=%s night=%s want targetNight=%s", tostring(johtoFlag(FLAG_DAY_POKEMON)),
      tostring(johtoFlag(FLAG_NIGHT_POKEMON)), tostring(targetNight)))
  results[#results + 1] = {
    tag = tag, crashed = crashedHere, transitioned = didTransition, flagsOk = flagsOk,
    startOE = startOE, startSP = startSP, crossedOE = crossedOE, crossedSP = crossedSP,
    maxOE = maxOE, maxSP = maxSP,
  }
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
    F.check("warped to Route 37", false); F.finish(); return
  end
  F.idle(60)

  -- Coax the follower visible (warp respawns it invisible).
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
  F.check("follower is out before testing", findFollower())

  if not legSafe(17, 21) then F.check("reached pre-corridor waypoint", false); F.finish(); return end
  if not legSafe(15, 21) then F.check("reached pre-corridor waypoint 2", false); F.finish(); return end
  if not legSafe(15, 40) then F.check("reached Route37 edge", false); F.finish(); return end
  F.L("  at Route37 edge, starting the alignment matrix")

  -- 12 scenarios: 3 alignments x 2 directions x 2 polarities. Each scenario forces its own
  -- starting polarity, so order doesn't matter for correctness -- but grouped by alignment first
  -- keeps the log easy to read against the coordinator's brief.
  for _, alignment in ipairs({ "before", "on", "after" }) do
    if crashedGlobal then break end
    runScenario("south", alignment, true)   -- day -> night, crossing south
    if not crashedGlobal then runScenario("north", alignment, false) end  -- night -> day, crossing north
    if not crashedGlobal then runScenario("south", alignment, false) end  -- night -> day, crossing south
    if not crashedGlobal then runScenario("north", alignment, true) end   -- day -> night, crossing north
  end

  F.L("== summary ==")
  local nCrash, nSkip, nOk = 0, 0, 0
  for _, r in ipairs(results) do
    if r.skipped then
      nSkip = nSkip + 1
      F.L("  " .. r.tag .. ": SKIPPED (could not reach edge)")
    elseif r.crashed then
      nCrash = nCrash + 1
      F.L("  " .. r.tag .. ": CRASHED")
    else
      nOk = nOk + 1
      F.L(string.format("  %s: ok transitioned=%s flagsOk=%s start=%d/%d,%d/%d crossed=%d/%d peak=%d/%d,%d/%d",
        r.tag, tostring(r.transitioned), tostring(r.flagsOk), r.startOE, 16, r.startSP, 64,
        r.crossedOE, r.crossedSP, r.maxOE, 16, r.maxSP, 64))
    end
  end
  F.L(string.format("  %d ok / %d crashed / %d skipped / %d total scenarios", nOk, nCrash, nSkip, #results))
  F.check("no scenario crashed across the full alignment x direction x polarity matrix",
    nCrash == 0 and not crashedGlobal, string.format("%d crashed", nCrash))
  F.check("every attempted scenario completed (none skipped for reachability)", nSkip == 0)

  F.finish()
end)
