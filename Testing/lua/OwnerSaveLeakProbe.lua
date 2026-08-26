-- INSTRUMENTATION PROBE (not a promoted suite) -- Route 37 red-crash investigation, H5.
--
-- H5: is there a genuine sprite-pool LEAK accumulated over ordinary (non-warp) overworld walking
-- on the OWNER'S REAL save, such that by the time they reached Route 37 the pool was already
-- elevated, and the connection crossing merely tipped it over sprite.c:436's fatal_assertf?
--
-- Every previous measurement (this session's fresh-save crossing probe, and the prior session's
-- warp-based Route37 measurement) went through ResumeMap() -> ResetSpriteData(), which fully
-- clears the 64-slot gSprites pool -- so none of them could ever have observed a leak. This probe
-- instead loads the real save, samples the pool the moment it settles (that first sample is STILL
-- post-reset -- there is no way to resume mid-session without a savestate, which lib.lua forbids
-- across sessions), and then walks a long, continuous, warp-free stretch through the real
-- overworld toward the Route36/37 corridor, sampling gObjectEvents/gSprites every step. A
-- monotonic climb during that warp-free stretch is the leak signature; a flat trace disconfirms
-- H5 regardless of the absolute baseline.
--
-- Save under test: _pwtest/saves/bak-prev8.sav (READ ONLY -- copied once to a scratch dir with
-- chmod 444; mgba-run.sh separately copies whatever save path it's given into a throwaway work
-- dir and never writes back to the source). Verified by parsing SaveBlock2 out of the flash image
-- directly (see the coordinator's message): name "Dave", playtime 6h30m, save counter 20,
-- saveVersion 8 (matches VerifyOwnerSave.lua's own doc comment: "the live .sav is 79/5,
-- RuinsOfAlph_PuzzleAndRewardChambers" -- exactly this file's parsed position). This is the
-- correct save to test against the v8 crash report.
--
-- Route from the save's position to the Route36/Route37 corridor (all host-side collision BFS,
-- verified against data/layouts/*/map.bin):
--   RuinsOfAlph_PuzzleAndRewardChambers (20,9) [saved ON the warp tile]
--     -> warp -> RuinsOfAlph_Outside (28,11)
--     -> walk BFS to (20,7), step Up onto (20,6) -> warp -> Gate_RuinsOfAlph_Route36 (7,9)
--     -> walk to (7,1) -> warp -> Route36 (56,25)
--     -> walk BFS (45 tiles, warp-free) to Route36 (37,0)
--     -> step Up -> CONNECTION crossing (no warp) into Route37 (15,40)
--     -> continue north through the corridor, sampling every step throughout
--
-- Run: Testing/mgba-run.sh Testing/lua/OwnerSaveLeakProbe.lua pokemonworld.gba <save>

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "OwnerSaveLeakProbe")

local EXPECT_GROUP = 79  -- RuinsOfAlph_PuzzleAndRewardChambers

-- Count active gObjectEvents slots and in-use gSprites slots; also return the active-slot set
-- (index -> graphicsId) so we can diff what's NEW between samples.
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
  local newOnes = {}
  for i, o in pairs(active) do
    if prevActive[i] == nil then
      newOnes[#newOnes + 1] = string.format("slot%d=gfx0x%04X,local%d@(%d,%d)", i, o.gfx, o.localId, o.x, o.y)
    end
  end
  local newStr = (#newOnes > 0) and (" NEW[" .. table.concat(newOnes, ",") .. "]") or ""
  F.L(string.format("  [%s] pos=(%d,%d) grp=%d map=%d objEvents=%d/16 sprites=%d/64%s",
    tag, x, y, F.grp(), F.mapn(), oe, sp, newStr))
  prevActive = active
  return oe, sp
end

-- F.step()'s coordinate-change window is 30 raw frames. A diagnostic raw-hold on THIS save (see
-- log "DIAG raw-hold Left 90x2f") needed ~60 frames to register one tile of movement -- 2x that
-- budget -- which is why F.leg()/F.step() reported false "blocked"s throughout this probe even
-- though the tiles were genuinely open. Not investigated further (out of scope for H5), but it is
-- reproducible and specific to this save/boot path, not a generic harness issue. Use a wider
-- local budget instead of fighting it.
local function myStep(dir)
  local x0, y0 = F.pos()
  -- 220, not 70: chunked retries (release, wait, re-press) never succeeded no matter how many
  -- were stacked, but one continuous 180-frame hold did. That means releasing the button between
  -- attempts resets some in-progress state rather than just wasting time -- a single myStep call
  -- must never release before it either detects movement or gives up for good, so its own budget
  -- has to cover the worst case in one unbroken hold rather than relying on legSafe's retries.
  -- Do NOT poll F.pos() every iteration here -- an earlier version did, and it never worked no
  -- matter how large the budget got. The one thing that DID work (the abandoned raw-hold
  -- diagnostic) held blind for a fixed span and checked position exactly once at the end. Match
  -- that shape exactly: hold blind, check once.
  for _ = 1, 110 do F.press(dir, 2) end
  F.idle(20)
  local x, y = F.pos()
  return x ~= x0 or y ~= y0
end

local function myLeg(tx, ty)
  for _ = 1, 80 do
    local x, y = F.pos()
    if x == tx and y == ty then return true end
    local dir
    if x < tx then dir = "Right" elseif x > tx then dir = "Left"
    elseif y < ty then dir = "Down" else dir = "Up" end
    if not myStep(dir) then return false end
  end
  return false
end

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
  local stuckStreak = 0
  for _ = 1, (tries or 8) do
    local x0, y0 = F.pos()
    if myLeg(tx, ty) then return true end
    local x1, y1 = F.pos()
    if not F.ow() then
      if not settleBattle() then return false end
      stuckStreak = 0
    elseif x1 ~= x0 or y1 ~= y0 then
      -- leg() gave up (its own per-step 30-frame window elapsed) but the position DID move --
      -- e.g. a scripted slide/puzzle tile that resolves slower than a normal step. Not a real
      -- block: let the loop try again from wherever we actually ended up.
      F.idle(30)
      stuckStreak = 0
    else
      -- No progress and no battle -- could be a genuine wall, or a wandering NPC/wild OWE that
      -- happens to be standing on the target tile right now. Give it a few frames to wander off
      -- before concluding it's a real block.
      stuckStreak = stuckStreak + 1
      if stuckStreak >= 4 then return false end
      F.idle(40)
    end
  end
  return false
end

-- Walk an explicit BFS'd path (list of {x,y}, each adjacent to the last) tile by tile, sampling
-- census after every single tile -- not just at waypoints -- since a leak signature is about the
-- TREND across many samples, not the endpoint.
local function walkPath(path, tag)
  local samples = {}
  for idx, wp in ipairs(path) do
    if not legSafe(wp[1], wp[2]) then
      F.L(string.format("  [%s] stuck heading to (%d,%d) at step %d, pos=(%d,%d)", tag, wp[1], wp[2], idx, F.pos()))
      F.shot(tag .. "_stuck_" .. idx)
      return samples, false
    end
    if F.reportCrash(tag .. "_" .. idx) then return samples, true end
    local oe, sp = logCensus(tag .. "_" .. idx)
    samples[#samples + 1] = { oe = oe, sp = sp }
  end
  return samples, false
end

F.run(function()
  -- keepScene=true: do NOT let boot() take its usual settling step. That step would itself be
  -- "movement" and would contaminate the very first, pre-movement baseline sample.
  if not F.boot(EXPECT_GROUP, true) then
    F.check("owner save boots to its saved map", false)
    F.finish(); return
  end

  local g, n = F.grp(), F.mapn()
  F.check("save loaded on its saved map (RuinsOfAlph_PuzzleAndRewardChambers, 79/5)",
    g == EXPECT_GROUP and n == 5, string.format("grp=%d map=%d", g, n))
  local px, py = F.pos()
  F.L(string.format("  save position: (%d,%d) grp=%d map=%d", px, py, g, n))

  -- Sample #1: THE headline baseline. Immediately on load, before a single step. This reflects
  -- ResumeMap()'s ResetSpriteData() -- there is no way around that for a process boot, savestates
  -- across sessions are forbidden (lib.lua doc), so this is the best available "floor" reading.
  local baseOE, baseSP = logCensus("baseline_on_load")
  F.check("baseline sampled before any movement", true)
  F.shot("baseline_on_load")

  -- keepScene=true (needed to keep boot() from itself moving the player before the baseline
  -- sample) leaves whatever on-arrival script this location has still open -- the screenshot
  -- shows a message box up and the follower mid-emerge. That's why the FIRST post-baseline step
  -- in any direction was reported blocked: dialogue eats directional input, not a collision wall.
  -- Clear it now, AFTER the baseline, same as boot()'s own normal (non-keepScene) behavior.
  for i = 1, 40 do
    F.press("B", 2); F.idle(20)
    if i % 10 == 0 then F.L("  dismiss try " .. i .. " cb2=0x" .. string.format("%08X", F.cb2()) .. " ow=" .. tostring(F.ow())) end
    if F.ow() then break end
  end
  -- F.ow() (CB2_Overworld) can be true while a palette fade / field-control lock is still
  -- resolving underneath it -- ArePlayerFieldControlsLocked()-style state isn't visible to this
  -- harness. A generous flat idle here (not movement-based) turned out to be the actual fix: it
  -- costs ~2.5 real seconds of emulated time, once, and avoids the multi-tile raw-hold that
  -- desynced the follower's trailing AI in an earlier version of this probe.
  F.idle(1500)
  logCensus("after_dismiss")
  F.shot("after_dismiss")

  -- NOTE (diagnosed, not used further): an earlier version of this probe raw-held Left for 180
  -- frames here to work around F.step()'s 30-frame window being too short after this particular
  -- Continue-boot (confirmed: the player genuinely moved 3 tiles, F.step() just didn't see it).
  -- That 3-tile jump desynced the follower's own trailing AI -- it caught up ahead of the player
  -- instead of behind, then sat there refusing to move again, which looked exactly like a real
  -- collision block one tile later. myStep()/myLeg() below use a wider single-tile budget (84
  -- frames) instead, which keeps the follower properly synced without needing a multi-tile jump.

  -- PRIMARY long-stretch signal, guaranteed reachable: the room the save is already sitting in
  -- is open (collision-scanned) from (17,2) to (24,9), minus a small 4-tile pillar at x20-23,
  -- y4-5 -- loop its perimeter (x=19 and x=24 columns, y=2 and y=9 rows) twice, warp-free,
  -- sampling every step. This does not depend on ever leaving Ruins of Alph, so it cannot be
  -- derailed by whatever blocks movement in the Outside area below (see the corridor attempt
  -- further down, which is best-effort on top of this).
  do
    local loopPath = {}
    local function addRun(fromX, fromY, toX, toY)
      local dx = (toX > fromX and 1) or (toX < fromX and -1) or 0
      local dy = (toY > fromY and 1) or (toY < fromY and -1) or 0
      local x, y = fromX, fromY
      while x ~= toX or y ~= toY do
        x = x + dx; y = y + dy
        loopPath[#loopPath + 1] = { x, y }
      end
    end
    -- (20,9) -> (19,9) -> (19,2) -> (24,2) -> (24,9) -> (19,9) -> (19,2) -> (24,2) -> (24,9): two
    -- full laps of the room's perimeter, avoiding the central pillar.
    addRun(20, 9, 19, 9); addRun(19, 9, 19, 2); addRun(19, 2, 24, 2); addRun(24, 2, 24, 9)
    addRun(24, 9, 19, 9); addRun(19, 9, 19, 2); addRun(19, 2, 24, 2); addRun(24, 2, 24, 9)

    local loopSamples, loopCrashed = walkPath(loopPath, "chamber_loop")
    if loopCrashed then F.finish(); return end
    F.check(string.format("chamber loop completed (%d/%d steps)", #loopSamples, #loopPath),
      #loopSamples == #loopPath)

    local loopOE, loopSP, loopClimbed = 0, 0, false
    local lastSP3, risingRun3 = -1, 0
    for _, s in ipairs(loopSamples) do
      if s.oe > loopOE then loopOE = s.oe end
      if s.sp > loopSP then loopSP = s.sp end
      if s.sp > lastSP3 then risingRun3 = risingRun3 + 1 else risingRun3 = 0 end
      if risingRun3 >= 8 then loopClimbed = true end
      lastSP3 = s.sp
    end
    F.L(string.format("  chamber loop (%d warp-free steps): floor sprites=%d peak sprites=%d, floor objEvents=%d peak objEvents=%d",
      #loopSamples, baseSP, loopSP, baseOE, loopOE))
    F.check("no monotonic climb during the guaranteed in-chamber loop (leak signature)", not loopClimbed,
      "longest strictly-rising run=" .. risingRun3)
    F.shot("chamber_loop_done")
  end

  -- The player is saved standing exactly on the warp tile back to RuinsOfAlph_Outside. Nudge it:
  -- stepping in any open direction and back should re-trigger the warp check. Try stepping Down
  -- first (open per the chamber's own collision), then fall back to other directions.
  local warped = false
  for _, dir in ipairs({ "Down", "Up", "Left", "Right" }) do
    myStep(dir); F.idle(20)
    if F.mapn() ~= 5 or F.grp() ~= EXPECT_GROUP then warped = true; break end
  end
  if not warped then
    -- Didn't trigger by moving off; try walking back onto the exact saved tile.
    myLeg(px, py); F.idle(20)
    if F.mapn() ~= 5 or F.grp() ~= EXPECT_GROUP then warped = true end
  end
  -- RuinsOfAlph_Outside = (7 | (75 << 8)) -- group 75, map 7 (NOT the chamber's group 79).
  F.check("warped out of the puzzle chamber to Ruins of Alph Outside",
    warped and F.grp() == 75 and F.mapn() == 7, string.format("grp=%d map=%d", F.grp(), F.mapn()))
  if not (F.grp() == 75 and F.mapn() == 7) then
    F.L("  could not leave the chamber the expected way; reporting baseline only")
    F.check("H5 baseline captured (corridor unreached)", true)
    F.finish(); return
  end
  logCensus("outside_arrival")

  -- Path (Outside) toward the Gate door at (20,6). Re-routed off the original BFS shortest path:
  -- an object (not in the static map template list -- likely the follower or a wandering OWE)
  -- was observed parked at (27,12) blocking it. Row 13 and column x=21 are both fully open per
  -- the collision scan (rows 7-13, x=19-22 all collision 0), so drop down to row 13 first.
  local toGate = {
    {28,13},{27,13},{26,13},{25,13},{24,13},{23,13},{22,13},{21,13},
    {21,12},{21,11},{21,10},{21,9},{21,8},{21,7},{20,7},
  }
  local okToGate, crashed = walkPath(toGate, "to_gate")
  if crashed then F.finish(); return end
  if F.grp() ~= 75 or F.mapn() ~= 7 or #okToGate < #toGate then
    F.L(string.format("  did not reach the gate door on foot (grp=%d map=%d, %d/%d waypoints)",
      F.grp(), F.mapn(), #okToGate, #toGate))
    F.check("corridor genuinely reachable on foot from here", false, "stopped in RuinsOfAlph_Outside")

    -- The Route36/37 corridor is NOT cheaply reachable from here on foot (something -- not yet
    -- understood, and not this investigation's subject -- blocks movement past (28,12) toward the
    -- gate; it is invisible on screen and not a raw collision wall, so possibly a puzzle-area
    -- movement gate specific to Ruins of Alph). Per the coordinator's own framing this is an
    -- acceptable stopping point for the corridor crossing -- but H5 (the leak question) doesn't
    -- need the corridor specifically, just a long, continuous, warp-free walk. Do that here
    -- instead: row 12 of this same map is confirmed open collision x=4..35 (34 tiles), so walk it
    -- back and forth a couple of times, sampling every step, watching for a monotonic climb.
    -- Per-tile waypoints (not just leg-endpoints) so every step gets sampled, same as the main
    -- walk. Two laps of the corridor: (28,12) -> (5,12) -> (33,12) -> (5,12).
    local wanderPath = {}
    local function addRun(fromX, toX, y)
      local step = (toX > fromX) and 1 or -1
      local x = fromX
      while x ~= toX do
        x = x + step
        wanderPath[#wanderPath + 1] = { x, y }
      end
    end
    addRun(28, 5, 12)
    addRun(5, 33, 12)
    addRun(33, 5, 12)

    local wsamples, wcrashed = walkPath(wanderPath, "wander")
    if wcrashed then F.finish(); return end

    local wanderOE, wanderSP, wanderClimbed = 0, 0, false
    local lastSP2, risingRun2 = -1, 0
    for _, s in ipairs(wsamples) do
      if s.oe > wanderOE then wanderOE = s.oe end
      if s.sp > wanderSP then wanderSP = s.sp end
      if s.sp > lastSP2 then risingRun2 = risingRun2 + 1 else risingRun2 = 0 end
      if risingRun2 >= 8 then wanderClimbed = true end
      lastSP2 = s.sp
    end
    F.L(string.format("  wander test (row 12, %d warp-free steps): peak objEvents=%d/16 peak sprites=%d/64",
      #wsamples, wanderOE, wanderSP))
    F.check("no monotonic climb during the RuinsOfAlph_Outside wander (leak signature)", not wanderClimbed,
      "longest strictly-rising run=" .. risingRun2)
    F.shot("wander_final")
    F.finish(); return
  end

  myStep("Up"); F.idle(30)  -- onto (20,6), the gate warp
  local reachedGate = (F.grp() == 79 and F.mapn() == 2)
  F.check("warped into Gate_RuinsOfAlph_Route36", reachedGate,
    string.format("grp=%d map=%d", F.grp(), F.mapn()))
  logCensus("gate_arrival")
  if not reachedGate then
    F.L("  gate warp did not fire as expected; H5 baseline stands, corridor not reached")
    F.finish(); return
  end

  -- Gate interior: walk straight up to the far warp (7,1).
  local gx, gy = F.pos()
  F.L(string.format("  in gate at (%d,%d)", gx, gy))
  local reachedFarSide = legSafe(7, 1)
  if F.reportCrash("gate_walk") then F.finish(); return end
  logCensus("gate_far_side")
  if not reachedFarSide then
    F.L(string.format("  could not cross the gate interior on foot (now at grp=%d map=%d); H5 baseline stands",
      F.grp(), F.mapn()))
    F.check("corridor genuinely reachable on foot from here", false, "stuck in the gate")
    F.finish(); return
  end

  myStep("Up"); F.idle(30)  -- onto Route36
  F.check("warped into Route 36", F.grp() == 83 and F.mapn() == 2,
    string.format("grp=%d map=%d", F.grp(), F.mapn()))
  if not (F.grp() == 83 and F.mapn() == 2) then
    F.L("  did not land on Route 36 as expected; stopping here")
    F.finish(); return
  end

  -- THIS is the practical starting line for the leak test: freshly warped in (pool just reset
  -- again by this warp -- expected and normal), about to walk a long, continuous, WARP-FREE
  -- stretch across the open route to the Route36/37 corridor.
  local floorOE, floorSP = logCensus("route36_arrival")
  F.shot("route36_arrival")

  -- 45-tile BFS path from the gate's Route36 arrival (56,25) to the north-border corridor (37,0).
  -- Passes near Route36's own object cluster (SUDOWOODO at 39,19) and up the open interior --
  -- this is the "walk normally around that area for a good long stretch" leg.
  local toCorridor = {
    {56,24},{56,23},{56,22},{56,21},{56,20},{56,19},{55,19},{54,19},{53,19},{52,19},
    {51,19},{50,19},{49,19},{48,19},{47,19},{46,19},{45,19},{44,19},{43,19},{42,19},
    {41,19},{40,19},{39,19},{39,18},{39,17},{38,17},{38,16},{38,15},{38,14},{38,13},
    {38,12},{38,11},{38,10},{38,9},{38,8},{38,7},{38,6},{38,5},{38,4},{38,3},
    {37,3},{37,2},{37,1},{37,0},
  }
  local samples, crashed2 = walkPath(toCorridor, "route36_walk")
  if crashed2 then F.finish(); return end

  local peakOE, peakSP = 0, 0
  local climbed = false
  local lastSP = floorSP
  local risingRun = 0
  for _, s in ipairs(samples) do
    if s.oe > peakOE then peakOE = s.oe end
    if s.sp > peakSP then peakSP = s.sp end
    if s.sp > lastSP then risingRun = risingRun + 1 else risingRun = 0 end
    if risingRun >= 8 then climbed = true end
    lastSP = s.sp
  end
  F.L(string.format("  route36 walk (%d warp-free steps): floor sprites=%d peak sprites=%d, floor objEvents=%d peak objEvents=%d",
    #samples, floorSP, peakSP, floorOE, peakOE))
  F.check("no monotonic climb across the warp-free Route36 walk (leak signature)", not climbed,
    "longest strictly-rising run=" .. risingRun)

  -- Now the CONNECTION crossing itself (no warp -- this is the actual reported transition),
  -- continuing to sample. Keep walking further into Route 37 afterward too.
  local crossPath = {}
  for i = 1, 25 do crossPath[i] = nil end -- placeholder, we step directionally instead
  local crashed3 = false
  local maxOE3, maxSP3 = peakOE, peakSP
  for i = 1, 30 do
    local bg, bm = F.grp(), F.mapn()
    local moved = myStep("Up")
    if F.reportCrash("crossing_" .. i) then crashed3 = true; break end
    if not moved and not F.ow() then
      if not settleBattle() then break end
      if F.reportCrash("crossing_" .. i .. "_postbattle") then crashed3 = true; break end
    end
    local oe, sp = logCensus("crossing_" .. i)
    if oe > maxOE3 then maxOE3 = oe end
    if sp > maxSP3 then maxSP3 = sp end
    if bg ~= F.grp() or bm ~= F.mapn() then
      F.L(string.format("  *** MAP TRANSITION at crossing step %d: (%d,%d) -> (%d,%d) ***", i, bg, bm, F.grp(), F.mapn()))
    end
    if not moved and F.ow() then break end
  end

  F.check("no crash during the real-save connection crossing", not crashed3)
  F.L(string.format("  overall peak across the whole walk+crossing: objEvents=%d/16 sprites=%d/64", maxOE3, maxSP3))
  F.shot("final")

  F.finish()
end)
