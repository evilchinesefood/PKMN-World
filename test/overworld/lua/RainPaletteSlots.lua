-- Rain palette darkening for object palettes loaded mid-rain, and their recovery when rain ends.
--
-- Suspicion under test: ApplyColorMap (src/field_weather.c) darkens object palette slots that are
-- free, or that get loaded after the weather fade-in, so an NPC, overworld Pokemon or follower
-- spawned in the rain comes out the wrong shade, or stays dark once the rain stops.
--
-- Oracle: at 14:30 the day blend is the identity (asserted on a clear map first), so for every
-- in-use, non-blend-immune object slot the expected faded colour is the colour map applied per
-- channel to gPlttBufferUnfaded. Slot contrastColorMapSpritePalIndex (the weather palette) takes
-- sContrastColorMaps, the rest sDarkenedContrastColorMaps (ApplyColorMap's own selection). Clear
-- weather expects faded == unfaded. Each slot is checked at every phase, including slots whose tag
-- arrived after the fade-in (NPC spawns, a follower given mid-rain) and after rain stops in place.
--
-- Run via test/overworld/mgba-run.sh test/overworld/lua/RainPaletteSlots.lua

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "RainPaletteSlots")

local HUB_GROUP = 100
local W_CMI, W_PALSTATE, W_FINISH, W_CURR, W_NEXT, W_DONE, W_CONTRAST = 0x200, 0x206, 0x20E, 0x210, 0x211, 0x213, 0x215
local WEATHER_NONE, WEATHER_RAIN = 0, 3
local PAL_STATE_IDLE = 3
local TAG_NONE, BLEND_IMMUNE = 0xFFFF, 0x8000
local ROW_GIVE, ROW_MON_BASIC = 3, 1

local function d(n) return (n // 100) % 10, (n // 10) % 10, n % 10 end

local function go(grp, map, warp, tag)
  local gh, gt, go_ = d(grp)
  local mh, mt, mo = d(map)
  local wh, wt, wo = d(warp)
  if not F.warpTo(gh, gt, go_, mh, mt, mo, wh, wt, wo, grp, map, tag) then
    F.check(tag .. "_warped", false, string.format("grp=%d map=%d", F.grp(), F.mapn()))
    return false
  end
  F.idle(120)
  return true
end

local function localTime()
  return F.rs8(S.gLocalTime + S.Time.hours), F.rs8(S.gLocalTime + S.Time.minutes)
end

-- Same clock lever DayNightTint.lua uses: wind SaveBlock2.localTimeOffset so gLocalTime lands on
-- the requested minute, then force the TOD tick.
local function setClock(targetHour, targetMin)
  local off = F.sb2() + S.SaveBlock2.localTimeOffset
  local h, m = localTime()
  local deltaMin = ((h * 60 + m) - (targetHour * 60 + targetMin)) % (24 * 60)
  local newMin = F.rs8(off + S.Time.minutes) + (deltaMin % 60)
  local carry = 0
  if newMin >= 60 then newMin, carry = newMin - 60, 1 end
  F.w8(off + S.Time.minutes, newMin % 60)
  F.w8(off + S.Time.hours, (F.rs8(off + S.Time.hours) + (deltaMin // 60) + carry) % 24)
  F.w8(S.sHoursOverride, 0)
  F.w16(S.gTimeUpdateCounter, 0)
  F.idle(120)
end

local function cmi() return F.rs8(S.gWeather + W_CMI) end
local function palState() return F.r8(S.gWeather + W_PALSTATE) end
local function curWeather() return F.r8(S.gWeather + W_CURR) end
local function slotTag(i) return F.r16(S.sSpritePaletteTags + i * 2) end
local function unf(i, c) return F.r16(S.gPlttBufferUnfaded + (256 + i * 16 + c) * 2) end
local function fad(i, c) return F.r16(S.gPlttBufferFaded + (256 + i * 16 + c) * 2) end

local function mapped(color, map)
  local r, g, b = color & 0x1F, (color >> 5) & 0x1F, (color >> 10) & 0x1F
  return F.r8(map + r) | (F.r8(map + g) << 5) | (F.r8(map + b) << 10)
end

local function tagsNow()
  local t = {}
  for i = 0, 15 do t[i] = slotTag(i) end
  return t
end

-- Returns the number of in-use slots checked and a list of mismatch descriptions.
local function auditSlots()
  local idx = cmi()
  local contrast = F.r8(S.gWeather + W_CONTRAST)
  local checked, bad = 0, {}
  for i = 0, 15 do
    local tag = slotTag(i)
    if tag ~= TAG_NONE and (tag & BLEND_IMMUNE) == 0 then
      checked = checked + 1
      local map = nil
      if idx > 0 then
        local base = (i == 0 or i == contrast) and S.sContrastColorMaps or S.sDarkenedContrastColorMaps
        map = base + (idx - 1) * 32
      end
      for c = 0, 15 do
        local want = unf(i, c)
        if map then want = mapped(want, map) end
        local got = fad(i, c)
        if got ~= want then
          bad[#bad + 1] = string.format("slot %d tag %04X col %d unf %04X want %04X got %04X", i, tag, c, unf(i, c), want, got)
          break
        end
      end
    end
  end
  return checked, bad
end

local function waitIdle(maxFrames)
  for _ = 1, maxFrames do
    if palState() == PAL_STATE_IDLE then return true end
    F.idle(1)
  end
  return palState() == PAL_STATE_IDLE
end

local function audit(tag, wantCmi)
  F.check(tag .. "_weather_palette_idle", waitIdle(600), "palState=" .. palState())
  F.check(tag .. "_color_map_index", cmi() == wantCmi, string.format("cmi=%d want %d weather=%d", cmi(), wantCmi, curWeather()))
  local n, bad = auditSlots()
  local x, y = F.pos()
  F.L(string.format("  %s: map %d.%d (%d,%d) weather=%d cmi=%d checked %d slots", tag, F.grp(), F.mapn(), x, y, curWeather(), cmi(), n))
  for _, b in ipairs(bad) do F.L("    " .. b) end
  F.check(tag .. "_every_object_slot_matches_weather", n > 0 and #bad == 0,
    string.format("%d/%d slots wrong%s", #bad, n, #bad > 0 and (": " .. bad[1]) or ""))
end

-- SetNextWeather (src/field_weather.c) minus its sound effect: the same three fields the debug
-- weather menu and a map-connection crossing write.
local function setNextWeather(w)
  F.w8(S.gWeather + W_DONE, 0)
  F.w8(S.gWeather + W_NEXT, w)
  F.w16(S.gWeather + W_FINISH, 0)
end

local function newTags(before)
  local list = {}
  for i = 0, 15 do
    local t = slotTag(i)
    if t ~= TAG_NONE and t ~= before[i] then list[#list + 1] = string.format("%d:%04X", i, t) end
  end
  return list
end

local function tapDown(n)
  for _ = 1, n do F.press("Down", 3); F.idle(16) end
end

-- Debug Give X -> Pokemon (Basic), Oddish Lv10: the first party mon becomes the follower.
local function giveOddish()
  F.dbg(); F.idle(60)
  tapDown(ROW_GIVE); F.press("A", 3); F.idle(50)
  tapDown(ROW_MON_BASIC); F.press("A", 3); F.idle(40)
  F.press("Right", 2); F.idle(10)
  F.press("Left", 2); F.idle(10)
  for _ = 1, 2 do F.press("Up", 2); F.idle(8) end
  F.press("A", 3); F.idle(30)
  for _ = 1, 9 do F.press("Up", 2); F.idle(8) end
  F.press("A", 3); F.idle(60)
  for _ = 1, 8 do F.press("B", 3); F.idle(20) end
end

local function followerSlot()
  for i = 0, 15 do
    local b = S.gObjectEvents + i * S.ObjectEvent.stride
    if (F.r8(b) & 1) == 1 and F.r8(b + S.ObjectEvent.localId) == 0xFE then
      return string.format("obj %d inv=%d", i, (F.r8(b + S.ObjectEvent.flags1) >> 5) & 1)
    end
  end
  return "ABSENT"
end

local function walk(dirs)
  for _, dir in ipairs(dirs) do F.step(dir) end
  F.idle(60)
end

F.run(function()
  if not F.boot(HUB_GROUP) then F.check("boot to the hub", false); F.finish(); return end
  F.check("player is free", F.ensureFree())
  giveOddish()
  F.check("party has a follower candidate", F.r8(S.gPartiesCount) >= 1, "count=" .. F.r8(S.gPartiesCount))
  setClock(14, 30)

  -- Control: Route 101 (no rain) at day. Proves the day blend is the identity, so the rain
  -- expectation below is exactly the colour map.
  if not go(0, 16, 0, "route101") then F.finish(); return end
  audit("clear_route101", 0)

  -- Olivine City is WEATHER_RAIN (cmi 3). Slots loaded during the warp fade-in, follower included.
  if not go(87, 0, 0, "olivine") then F.finish(); return end
  F.check("olivine_is_raining", curWeather() == WEATHER_RAIN, "weather=" .. curWeather())
  walk({ "Left" })
  F.L("  follower: " .. followerSlot())
  F.check("rain_follower_present", followerSlot() ~= "ABSENT", followerSlot())
  audit("rain_entry", 3)
  F.shot("rain_entry")

  -- Overworld Pokemon (dynamic species palettes) and NPC palettes loaded by camera spawns after
  -- the fade-in, into slots that were free when the rain colour map was applied.
  local before = tagsNow()
  walk({ "Left", "Left", "Down", "Down", "Down", "Down", "Down", "Left", "Left", "Left", "Left", "Left" })
  local spawned = newTags(before)
  F.L("  tags loaded mid-rain by spawns: " .. table.concat(spawned, " "))
  F.check("rain_spawns_loaded_new_palettes", #spawned >= 2, #spawned .. " new tags")
  audit("rain_after_spawns", 3)
  F.shot("rain_spawns")

  -- Rain stops in place. Everything loaded during the rain must return to its unfaded colours.
  setNextWeather(WEATHER_NONE)
  F.idle(240)
  audit("rain_stopped", 0)
  F.shot("rain_stopped")

  -- Rain starts again in place.
  setNextWeather(WEATHER_RAIN)
  F.idle(240)
  audit("rain_restarted", 3)
  F.shot("rain_restarted")

  F.finish()
end)
