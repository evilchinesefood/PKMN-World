-- JohtoDayNightWorld.lua — the rest of issue #52's playtest checklist, which #56 inherited.
--
-- #52 shipped the day/night HIDE flags but was closed without ever being run in game, and #56
-- carried its checklist forward. `JohtoDayNightLive.lua` covers the mechanism (the flags follow the
-- clock, and the world follows the flags, in place). This suite covers the CONTENT that mechanism
-- is supposed to reach, all of which had never been observed by anyone:
--
--   1. The two remaining `setmaplayoutindex` swaps. TinTower_RoofDay's is already covered by
--      TinTowerRoof.lua; the other two are MtSilver_SummitDay and
--      GoldenrodCity_DepartmentStore_7F. All three are `call_if_set FLAG_DAY_POKEMON -> SetNight`,
--      so a polarity slip shows up as the wrong layout rather than as a crash.
--   2. Three human NPCs that have never once spawned for any player: Route 35's Policeman Dirk,
--      and the Goldenrod Underground haircut brothers — a genuine day/night PAIR on one map, which
--      is the strongest shape available (the day one appearing is not enough; the night one must
--      also be gone, and vice versa).
--
-- Only TRAINER_KEITH (Route 34) and TRAINER_JAMIE (Route 39) are left unrun: both sit ~30 tiles
-- from their nearest warp, which is navigation cost with no new mechanism behind it.
--
-- ★ warpTo's success test is group+map ONLY, so calling it while already on the target map returns
-- true having warped nobody AND leaves the debug menu open, which then silently eats every step
-- that follows. Every warp below therefore goes to a DIFFERENT map than the current one; the day
-- and night passes are interleaved rather than run map-by-map for exactly that reason.
--
-- Run against a THROWAWAY COPY:
--   cp <repo>\pokemonworld.gba  BizHawk\Verify1.gba
--   EmuHawk.exe BizHawk\Verify1.gba --lua=<repo>\Testing\lua\JohtoDayNightWorld.lua
local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(require("symbols"), "JohtoDayNightWorld")

-- ---- constants (all read out of map_groups.h / layouts.h, not counted by hand) ----------------
local SB1_MAPLAYOUT = 50

local SUMMIT   = { g = 97, m =  8, warp = 0, day = 1013, night = 1014, name = "MtSilver_SummitDay" }
local DEPT7F   = { g = 84, m = 10, warp = 0, day =  854, night =  855, name = "Goldenrod_Dept_7F" }
local ROUTE35  = { g = 83, m =  1, warp = 2, name = "Route35" }          -- warp2 = (17,5)
local UNDER    = { g = 84, m = 28, warp = 2, name = "Goldenrod_Underground" } -- warp2 = (12,10)

local LOCALID_DIRK = 8              -- POLICEMAN (20,6), FLAG_NIGHT_POKEMON
local LOCALID_BROTHER_DAY = 3       -- WORKER_M  (6,20), FLAG_DAY_POKEMON
local LOCALID_BROTHER_NIGHT = 4     -- CLERK     (6,16), FLAG_NIGHT_POKEMON

local FLAG_JOHTO_BASE = 0x6000
local FLAG_DAY_POKEMON, FLAG_NIGHT_POKEMON = 0x6040, 0x6041
local NIGHT_HOUR, DAY_HOUR = 22, 14

-- ---- accessors (same derivations as JohtoDayNightLive.lua) ------------------------------------
local function johtoFlag(id)
  local a = F.sb3() + S.SaveBlock3.johtoFlags + ((id - FLAG_JOHTO_BASE) // 8)
  return (F.r8(a) & (1 << (id % 8))) ~= 0
end

local function localTime()
  return F.rs8(S.gLocalTime + S.Time.hours), F.rs8(S.gLocalTime + S.Time.minutes)
end

-- gLocalTime = sRtc - localTimeOffset, so winding the offset forward winds the clock back. Land on
-- :30, half an hour from either boundary. sHoursOverride cannot be used: LoadMapFromWarp zeroes it
-- (src/overworld.c:989) eighteen lines before the day/night hook at :1007.
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

local function layoutId() return F.r16(F.sb1() + SB1_MAPLAYOUT) end

local function findLocal(want)
  for i = 0, 15 do
    local b = S.gObjectEvents + i * S.ObjectEvent.stride
    if (F.r8(b) & 1) == 1 and F.r8(b + S.ObjectEvent.localId) == want then
      return F.rs16(b + S.ObjectEvent.x) - 7, F.rs16(b + S.ObjectEvent.y) - 7
    end
  end
  return nil
end

local function dumpObjs(tag)
  local parts = {}
  for i = 0, 15 do
    local b = S.gObjectEvents + i * S.ObjectEvent.stride
    if (F.r8(b) & 1) == 1 then
      parts[#parts + 1] = string.format("id%d(%d,%d)", F.r8(b + S.ObjectEvent.localId),
        F.rs16(b + S.ObjectEvent.x) - 7, F.rs16(b + S.ObjectEvent.y) - 7)
    end
  end
  F.L("    " .. tag .. ": " .. table.concat(parts, " "))
end

-- Wind the clock, then warp: the warp is what makes the engine act on it (LoadMapFromWarp runs
-- DoTimeBasedEvents() and UpdateJohtoDayNightFlags(), then ON_TRANSITION). Reading map state the
-- instant mapNum flips is too early — the warp is still in flight and ON_TRANSITION, which sets the
-- layout, has not run — so settle afterwards.
local function goThere(dest, night, tag)
  setLocalTime(night and NIGHT_HOUR or DAY_HOUR)
  local d = function(n) return (n // 100) % 10, (n // 10) % 10, n % 10 end
  local gh, gt, go = d(dest.g)
  local mh, mt, mo = d(dest.m)
  local wh, wt, wo = d(dest.warp)
  if not F.warpTo(gh, gt, go, mh, mt, mo, wh, wt, wo, dest.g, dest.m, tag) then
    F.check(tag .. "_warped", false, "never reached " .. dest.name)
    return false
  end
  F.idle(180)
  local x, y = F.pos()
  local lh, lm = localTime()
  F.L(string.format("  %s: (%d,%d) clock %02d:%02d timeOfDay=%d day=%s night=%s layout=%d",
    tag, x, y, lh, lm, F.r8(S.gTimeOfDay), tostring(johtoFlag(FLAG_DAY_POKEMON)),
    tostring(johtoFlag(FLAG_NIGHT_POKEMON)), layoutId()))
  -- The flags are the precondition for everything below; assert them so a content failure is not
  -- misread as a flag failure.
  F.check(tag .. "_flags", johtoFlag(FLAG_DAY_POKEMON) == night
    and johtoFlag(FLAG_NIGHT_POKEMON) == (not night),
    string.format("day=%s night=%s (want day=%s)", tostring(johtoFlag(FLAG_DAY_POKEMON)),
      tostring(johtoFlag(FLAG_NIGHT_POKEMON)), tostring(night)))
  return true
end

local function checkLayout(dest, night, tag)
  if not goThere(dest, night, tag) then return end
  local want = night and dest.night or dest.day
  F.check(tag .. "_layout", layoutId() == want,
    string.format("layout=%d want=%d (%s)", layoutId(), want, night and "night" or "day"))
  F.shot(tag)
end

-- ---- main -------------------------------------------------------------------------------------
F.run(function()
  if not F.boot(100) then F.check("boot to overworld", false); F.finish(); return end
  F.check("booted to the RegionHub (map group 100)", F.grp() == 100, "grp=" .. F.grp())

  -- 1. The two remaining setmaplayoutindex swaps, interleaved so no warp targets the current map.
  F.L("== setmaplayoutindex swaps ==")
  checkLayout(SUMMIT, false, "summit_day")
  checkLayout(DEPT7F, false, "dept7f_day")
  checkLayout(SUMMIT, true,  "summit_night")
  checkLayout(DEPT7F, true,  "dept7f_night")

  -- 2. Route 35's Policeman Dirk — a night-only HUMAN NPC, three tiles from warp 2 at (17,5), so
  --    no navigation is needed to bring him inside TrySpawnObjectEvents' window.
  F.L("== Route 35 Policeman Dirk (night-only, never spawned before) ==")
  if goThere(ROUTE35, true, "dirk_night") then
    dumpObjs("dirk_night")
    local x, y = findLocal(LOCALID_DIRK)
    F.check("dirk_spawns_at_night", x ~= nil and x == 20 and y == 6,
      x and string.format("local id 8 at (%d,%d)", x, y) or "local id 8 absent")
    F.shot("dirk_night")
  end

  -- 3. The Goldenrod Underground haircut brothers: a real pair on one map, four tiles apart on the
  --    same column. Warp 2 lands at (12,10), from which the window (y in [py-7, py+9]) reaches the
  --    night brother at y=16 but misses the day one at y=20 by exactly one row — so take a single
  --    step down before sampling. Do it on BOTH passes so the two are measured identically.
  local function brothers(night, tag)
    if not goThere(UNDER, night, tag) then return end
    local stepped = false
    for _ = 1, 3 do
      if F.step("Down") then stepped = true; break end
    end
    local px, py = F.pos()
    F.check(tag .. "_stepped_into_window", stepped and py >= 11,
      string.format("at (%d,%d) after step=%s", px, py, tostring(stepped)))
    F.idle(30)
    dumpObjs(tag)
    local dx, dy = findLocal(LOCALID_BROTHER_DAY)
    local nx, ny = findLocal(LOCALID_BROTHER_NIGHT)
    if night then
      F.check("night_brother_spawns", nx ~= nil and nx == 6 and ny == 16,
        nx and string.format("CLERK at (%d,%d)", nx, ny) or "local id 4 absent")
      F.check("day_brother_hidden_at_night", dx == nil,
        dx and string.format("WORKER_M STILL at (%d,%d)", dx, dy) or "local id 3 absent")
    else
      F.check("day_brother_spawns", dx ~= nil and dx == 6 and dy == 20,
        dx and string.format("WORKER_M at (%d,%d)", dx, dy) or "local id 3 absent")
      F.check("night_brother_hidden_by_day", nx == nil,
        nx and string.format("CLERK STILL at (%d,%d)", nx, ny) or "local id 4 absent")
    end
    F.shot(tag)
  end

  F.L("== Goldenrod Underground haircut brothers (a day/night pair) ==")
  brothers(true,  "underground_night")
  -- Route 35 in between so the next Underground warp is not a no-op warpTo. It also gives the
  -- negative half of Dirk for free: by day he must be gone.
  if goThere(ROUTE35, false, "dirk_day") then
    dumpObjs("dirk_day")
    local x, y = findLocal(LOCALID_DIRK)
    F.check("dirk_hidden_by_day", x == nil,
      x and string.format("local id 8 STILL at (%d,%d)", x, y) or "local id 8 absent")
  end
  brothers(false, "underground_day")

  F.finish()
end)
