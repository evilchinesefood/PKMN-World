-- JohtoDayNightLive.lua — issue #56 item 1: Johto's day/night world must update WITHOUT a map reload.
--
-- #52 shipped UpdateJohtoDayNightFlags() into the two map loaders only, so crossing 19:59 -> 20:00
-- while standing still on a Johto route changed nothing on screen; the world flipped on the next
-- map load. #56 item 1 adds the per-minute tick and the object refresh it implies. This suite is
-- that fix's acceptance, and it also covers the #52 playtest checklist's first two bullets — night
-- content really appears, and the POLARITY is right (an inverted build compiles, boots and tints
-- correctly while inverting the whole world, so no gate but this one can catch it).
--
-- Route 37 is the test bed because it is unusually clean for this:
--   local id  5 = VULPIX  (17,7) flag FLAG_NIGHT_POKEMON  -> visible at NIGHT
--   local id 11 = PIDGEY  (18,7) flag FLAG_DAY_POKEMON    -> visible by DAY
-- Adjacent tiles, three rows above warp 0 at (17,10), and only four of the map's 18 templates fall
-- inside TrySpawnObjectEvents' window from there (the other two are LIGHT_SPRITEs, which take no
-- gObjectEvents slot) — so there is no slot pressure to confound a "did it spawn" check.
-- Window, from src/event_object_movement.c:3114 with MAP_OFFSET 7 / _W 15 / _H 14:
--   npc.x in [pos.x-9, pos.x+10], npc.y in [pos.y-7, pos.y+9].
--
-- HIDE-flag polarity, which is the easiest thing in this feature to get backwards: the flag named
-- for a time of day is SET during the OTHER one. At night FLAG_DAY_POKEMON is SET (hiding the day
-- mons) and FLAG_NIGHT_POKEMON is CLEAR (revealing the night ones).
--
-- Run against a THROWAWAY COPY (lib.new refuses anything not Verify*/MigChk*/FixGen*):
--   cp <repo>\pokemonworld.gba  BizHawk\Verify1.gba
--   EmuHawk.exe BizHawk\Verify1.gba --lua=<repo>\Testing\lua\JohtoDayNightLive.lua
local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(require("symbols"), "JohtoDayNightLive")

-- ---- constants ------------------------------------------------------------------------------
local GRP_ROUTE37, MAP_ROUTE37 = 83, 3          -- MAP_ROUTE37 = (3 | (83 << 8))
local WARP0_X, WARP0_Y = 17, 10

local LOCALID_VULPIX, VULPIX_X, VULPIX_Y = 5, 17, 7   -- FLAG_NIGHT_POKEMON -> shows at night
local LOCALID_PIDGEY, PIDGEY_X, PIDGEY_Y = 11, 18, 7  -- FLAG_DAY_POKEMON   -> shows by day

local FLAG_JOHTO_BASE = 0x6000
local FLAG_DAY_POKEMON, FLAG_NIGHT_POKEMON = 0x6040, 0x6041

local NIGHT_HOUR, DAY_HOUR = 22, 14             -- night 20..6, day 10..19 (S.Hours, probed)

-- The per-minute tick is gTimeUpdateCounter = SECONDS_PER_MINUTE * 60 = 3600 frames, and it only
-- decrements while no palette fade is active, so budget well over one period.
local TICK_BUDGET = 6000

-- ---- accessors ------------------------------------------------------------------------------
-- Johto flags live in SaveBlock3.region.johtoFlags (event_data.c:275), not SaveBlock1.flags.
local function johtoFlag(id)
  local a = F.sb3() + S.SaveBlock3.johtoFlags + ((id - FLAG_JOHTO_BASE) // 8)
  return (F.r8(a) & (1 << (id % 8))) ~= 0
end

local function localTime()
  return F.rs8(S.gLocalTime + S.Time.hours), F.rs8(S.gLocalTime + S.Time.minutes)
end

-- gLocalTime = sRtc - localTimeOffset (RtcCalcLocalTime, src/rtc.c:319), so winding the offset
-- FORWARD winds the in-game clock BACK. Work in total minutes so the hour and minute borrows
-- resolve together, and land on :30 — half an hour from either boundary, which keeps this correct
-- even though gLocalTime is only recomputed on the tick.
--
-- sHoursOverride (the debug time menu) is NOT usable here: LoadMapFromWarp zeroes it at
-- src/overworld.c:989, eighteen lines before the day/night hook at :1007.
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

-- Resolve by LOCAL ID, never by array index: gObjectEvents order is spawn order and moves. Return
-- the map coords so a positional assert can print what it actually found (a stale hardcoded local
-- id and a genuinely absent object otherwise produce the same failure text).
local function findLocal(want)
  for i = 0, 15 do
    local b = S.gObjectEvents + i * S.ObjectEvent.stride
    if (F.r8(b) & 1) == 1 and F.r8(b + S.ObjectEvent.localId) == want then
      return F.rs16(b + S.ObjectEvent.x) - 7, F.rs16(b + S.ObjectEvent.y) - 7, i
    end
  end
  return nil
end

local function activeCount()
  local n = 0
  for i = 0, 15 do
    if (F.r8(S.gObjectEvents + i * S.ObjectEvent.stride) & 1) == 1 then n = n + 1 end
  end
  return n
end

local function dumpObjs(tag)
  local parts = {}
  for i = 0, 15 do
    local b = S.gObjectEvents + i * S.ObjectEvent.stride
    if (F.r8(b) & 1) == 1 then
      parts[#parts + 1] = string.format("i%d:id%d(%d,%d)", i, F.r8(b + S.ObjectEvent.localId),
        F.rs16(b + S.ObjectEvent.x) - 7, F.rs16(b + S.ObjectEvent.y) - 7)
    end
  end
  F.L("    " .. tag .. ": " .. table.concat(parts, " "))
end

-- ---- the wait that is also the proof ----------------------------------------------------------
-- Wait for the minute tick to move the flags, WITHOUT ever leaving the overworld callback. Every
-- map-reload path in the engine (CB2_LoadMap, CB2_ReturnToField, a battle) swaps gMain.callback2
-- away from CB2_Overworld, so "ow() held true on every one of these frames" is a direct proof that
-- the change under test happened in place. That is the entire claim of item 1, and no positional
-- check can establish it — the player never moves either way.
local function waitForNight(wantNight)
  local frames, leftOverworld = 0, false
  while frames < TICK_BUDGET do
    if not F.ow() then leftOverworld = true end
    if johtoFlag(FLAG_DAY_POKEMON) == wantNight and johtoFlag(FLAG_NIGHT_POKEMON) == (not wantNight) then
      -- The refresh runs from OverworldBasic() on the frame the latch is seen, but give the
      -- remove+respawn a few frames to land before sampling gObjectEvents.
      for _ = 1, 30 do
        if not F.ow() then leftOverworld = true end
        F.idle(1); frames = frames + 1
      end
      return true, frames, leftOverworld
    end
    F.idle(1); frames = frames + 1
  end
  return false, frames, leftOverworld
end

-- ---- one direction --------------------------------------------------------------------------
-- Flip the clock in place and assert the world followed it. `night` is the state being flipped TO.
local function flipTo(night, tag)
  local wantHour = night and NIGHT_HOUR or DAY_HOUR
  local g0, m0 = F.grp(), F.mapn()
  local x0, y0 = F.pos()
  local n0 = activeCount()
  F.L(string.format("== flip to %s (hour %d) from map %d/%d at (%d,%d), %d objects active ==",
    night and "NIGHT" or "DAY", wantHour, g0, m0, x0, y0, n0))

  setLocalTime(wantHour)
  local flipped, frames, leftOverworld = waitForNight(night)
  local lh, lm = localTime()
  F.L(string.format("  after %d frames: clock %02d:%02d timeOfDay=%d day=%s night=%s",
    frames, lh, lm, F.r8(S.gTimeOfDay), tostring(johtoFlag(FLAG_DAY_POKEMON)),
    tostring(johtoFlag(FLAG_NIGHT_POKEMON))))
  dumpObjs(tag)

  -- 1. The per-minute tick reached UpdateJohtoDayNightFlags() at all.
  F.check(tag .. "_tick_flipped_flags", flipped,
    string.format("waited %d frames; day=%s night=%s", frames,
      tostring(johtoFlag(FLAG_DAY_POKEMON)), tostring(johtoFlag(FLAG_NIGHT_POKEMON))))
  if not flipped then return end

  -- 2. It happened in place. See waitForNight's comment: this is the "no map reload" clause.
  F.check(tag .. "_no_map_reload", not leftOverworld and F.grp() == g0 and F.mapn() == m0,
    string.format("leftOverworld=%s map %d/%d -> %d/%d", tostring(leftOverworld), g0, m0,
      F.grp(), F.mapn()))
  local x1, y1 = F.pos()
  F.check(tag .. "_player_did_not_move", x1 == x0 and y1 == y0,
    string.format("(%d,%d) -> (%d,%d)", x0, y0, x1, y1))

  -- 3. The object refresh: the mon for the new time of day is on the map and the other one is off
  --    it. POLARITY LIVES HERE — an inverted build passes checks 1 and 2 and fails these.
  local shownId, shownX, shownY = LOCALID_VULPIX, VULPIX_X, VULPIX_Y
  local hiddenId = LOCALID_PIDGEY
  if not night then
    shownId, shownX, shownY = LOCALID_PIDGEY, PIDGEY_X, PIDGEY_Y
    hiddenId = LOCALID_VULPIX
  end

  local sx, sy, si = findLocal(shownId)
  F.check(tag .. "_shown_mon_spawned", sx ~= nil and sx == shownX and sy == shownY,
    sx and string.format("local id %d at (%d,%d) slot %d, want (%d,%d)", shownId, sx, sy, si,
      shownX, shownY)
       or string.format("local id %d absent (expected at (%d,%d))", shownId, shownX, shownY))
  local hx, hy = findLocal(hiddenId)
  F.check(tag .. "_hidden_mon_despawned", hx == nil,
    hx and string.format("local id %d STILL at (%d,%d)", hiddenId, hx, hy)
       or string.format("local id %d is gone", hiddenId))

  -- 4. One in, one out — the refresh swapped rather than leaking slots. A remove that never
  --    respawned, or a respawn that never removed, both show up here.
  F.check(tag .. "_object_count_stable", activeCount() == n0,
    string.format("%d active before, %d after", n0, activeCount()))
  F.shot(tag)
end

-- ---- main -------------------------------------------------------------------------------------
F.run(function()
  if not F.boot(100) then F.check("boot to overworld", false); F.finish(); return end
  F.check("booted to the RegionHub (map group 100)", F.grp() == 100, "grp=" .. F.grp())

  -- Start from DAY so the first map load spawns the day mon; the flip under test is then day->night,
  -- which is the boundary the issue names (19:59 -> 20:00).
  setLocalTime(DAY_HOUR)

  -- warpTo(group h,t,o, mapNum h,t,o, warpId h,t,o, expectGroup, expectMap, tag); group 83, map 3,
  -- warp 0 = (17,10). Its success test is group+map ONLY, so verify the arrival TILE too — a false
  -- pass there leaves the debug menu open and silently eats everything that follows.
  if not F.warpTo(0, 8, 3, 0, 0, 3, 0, 0, 0, GRP_ROUTE37, MAP_ROUTE37, "to_route37") then
    F.check("warped to Route 37", false); F.finish(); return
  end
  F.idle(120)
  local px, py = F.pos()
  F.check("arrived on Route 37 warp 0 tile (17,10)", px == WARP0_X and py == WARP0_Y,
    string.format("(%d,%d)", px, py))
  dumpObjs("on_arrival")

  -- Baseline: the map load applied the DAY flags and spawned the day mon. This is the map-loader
  -- half that #52 already shipped, asserted here so a later failure is attributable to the tick.
  F.check("map load set the DAY flags", johtoFlag(FLAG_DAY_POKEMON) == false
    and johtoFlag(FLAG_NIGHT_POKEMON) == true,
    string.format("day=%s night=%s", tostring(johtoFlag(FLAG_DAY_POKEMON)),
      tostring(johtoFlag(FLAG_NIGHT_POKEMON))))
  local bx, by = findLocal(LOCALID_PIDGEY)
  F.check("day mon PIDGEY spawned by the map load", bx ~= nil and bx == PIDGEY_X and by == PIDGEY_Y,
    bx and string.format("(%d,%d)", bx, by) or "local id 11 absent")
  F.check("night mon VULPIX is hidden by day", findLocal(LOCALID_VULPIX) == nil, "local id 5 absent")

  -- The feature: cross the boundary standing still, twice, in both directions. Doing it BOTH ways
  -- rules out a one-shot latch that happens to fire once and then never re-arms.
  flipTo(true, "day_to_night")
  flipTo(false, "night_to_day")

  -- ---- issue #56 item 3: an ordinary Continue --------------------------------------------------
  -- CB2_ContinueSavedGame reaches CB2_LoadMap only when UseContinueGameWarp() is TRUE (frontier /
  -- contest / trade / record-mix / whiteout). A plain save-and-reload takes the else branch to
  -- CB2_ReturnToField(), and InitMapFromSavedGame() runs RunOnLoadMapScript(), NOT
  -- RunOnTransitionMapScript() — so neither map-loader hook is reached. Save in the day, resume at
  -- night, and the flags, the saved objects and the saved layout are all stale on that one map.
  --
  -- Building the state this needs is the whole difficulty, and the obvious way does not work:
  -- localTimeOffset IS save data, so winding it after the save is undone by the reload (the first
  -- run of this suite failed exactly there, reporting `resumed: clock 14:30`). In real play the
  -- disagreement comes from the RTC advancing while the game is off, which an emulator run cannot
  -- reproduce.
  --
  -- sHoursOverride can. It is the debug time menu's lever, it lives in EWRAM, and it is NOT saved:
  --   wind localTimeOffset (saved) to NIGHT, then override the displayed hour back to DAY, so the
  --   world stays day and the SAVE captures day flags + a day object array against a night clock.
  --   reboot_core() clears EWRAM, the override vanishes, and the reloaded save reads NIGHT.
  -- Both writes happen with no frame advance between them, so the tick cannot fire in the gap.
  F.L("== save a DAY world against a NIGHT clock, then resume (issue #56 item 3) ==")
  setLocalTime(NIGHT_HOUR)
  F.w8(S.sHoursOverride, DAY_HOUR)
  F.w16(S.gTimeUpdateCounter, 0)          -- what SetTimeOfDay does: force the tick next frame
  F.idle(60)
  local oh, om = localTime()
  F.L(string.format("  override in force: gLocalTime %02d:%02d, timeOfDay=%d, day=%s night=%s",
    oh, om, F.r8(S.gTimeOfDay), tostring(johtoFlag(FLAG_DAY_POKEMON)),
    tostring(johtoFlag(FLAG_NIGHT_POKEMON))))
  F.check("override holds the world in DAY against a NIGHT clock",
    oh == NIGHT_HOUR and johtoFlag(FLAG_DAY_POKEMON) == false and findLocal(LOCALID_PIDGEY) ~= nil,
    string.format("clock hour=%d dayFlag=%s pidgey=%s", oh, tostring(johtoFlag(FLAG_DAY_POKEMON)),
      tostring(findLocal(LOCALID_PIDGEY) ~= nil)))

  F.press("Start", 2); F.idle(60)
  for _ = 1, 10 do F.press("Left", 2); F.idle(8) end               -- pin wheel slot 0
  F.press("Right", 2); F.idle(12); F.press("Right", 2); F.idle(12) -- -> Save
  F.press("A", 2); F.idle(90); F.press("A", 2); F.idle(60); F.press("A", 2); F.idle(240)
  F.idle(300)                                                      -- let flash flush
  F.L("  saved a DAY world; rebooting the core, which clears the EWRAM override")

  client.reboot_core()
  F.idle(240)

  -- keepScene = TRUE is load-bearing, not a nicety: boot()'s cleanup calls ensureFree(), which
  -- STEPS the player left then right, and a step runs the camera update's own TrySpawnObjectEvents.
  -- That would spawn the night mon for a reason unrelated to the fix and make the check vacuous.
  if not F.boot(GRP_ROUTE37, true) then
    F.check("Continue reaches the overworld on Route 37", false)
  else
    F.check("Continue reaches the overworld on Route 37", F.mapn() == MAP_ROUTE37,
      string.format("grp=%d map=%d", F.grp(), F.mapn()))
    local lh, lm = localTime()
    F.L(string.format("  resumed: clock %02d:%02d timeOfDay=%d day=%s night=%s",
      lh, lm, F.r8(S.gTimeOfDay), tostring(johtoFlag(FLAG_DAY_POKEMON)),
      tostring(johtoFlag(FLAG_NIGHT_POKEMON))))
    dumpObjs("after_continue")

    F.check("Continue recomputed the day/night flags from the clock",
      johtoFlag(FLAG_DAY_POKEMON) == true and johtoFlag(FLAG_NIGHT_POKEMON) == false,
      string.format("day=%s night=%s", tostring(johtoFlag(FLAG_DAY_POKEMON)),
        tostring(johtoFlag(FLAG_NIGHT_POKEMON))))

    -- THE discriminating one. SpawnObjectEventsOnReturnToField() replays the SAVED gObjectEvents
    -- array verbatim — it never re-reads the templates or the hide flags — so without the latched
    -- refresh the day mon comes back at night and nothing ever removes it. A stray step cannot
    -- produce this result either: the camera update only ADDS objects, it never removes one that
    -- is in view.
    local dx, dy = findLocal(LOCALID_PIDGEY)
    F.check("Continue despawned the stale day mon", dx == nil,
      dx and string.format("local id 11 STILL at (%d,%d)", dx, dy) or "local id 11 is gone")
    local nx, ny = findLocal(LOCALID_VULPIX)
    F.check("Continue spawned the night mon", nx ~= nil and nx == VULPIX_X and ny == VULPIX_Y,
      nx and string.format("local id 5 at (%d,%d)", nx, ny) or "local id 5 absent")
    F.shot("after_continue")
  end

  F.finish()
end)
