-- Drought weather keeps the day/night tint.
--
-- Symptom: at night, Sootopolis rendered at full daylight during the drought half of
-- WEATHER_ABNORMAL, while the downpour half and every neighbouring route were night-tinted.
-- ApplyColorMap's drought branch (negative colorMapIndex) and ApplyDroughtColorMapWithBlend built
-- the drought colours straight from gPlttBufferUnfaded and never applied the time blend.
--
-- State is seeded as SeafloorCavern_Room9 and the Sootopolis legendaries scene leave it:
-- FLAG_SYS_WEATHER_CTRL, FLAG_KYOGRE_ESCAPED_SEAFLOOR_CAVERN, VAR_SOOTOPOLIS_CITY_STATE 2. The map's
-- own ON_TRANSITION script then picks WEATHER_ABNORMAL, and Task_DoAbnormalWeather flips it to
-- drought after 600 frames. The clock lever is SaveBlock2.localTimeOffset (DayNightTint.lua).
--
-- Oracle: within one drought phase, palettes sampled at 22:30 and at 14:30 at the same drought
-- stage (gWeather.colorMapIndex) must differ, night darker. Unfixed they are identical, because
-- nothing in the drought path reads the clock. Then a warp into Route 126 during drought replays
-- the drought fade-in at night: no fade-in frame may be brighter than the settled night drought.
--
-- Run via test/overworld/mgba-run.sh test/overworld/lua/DroughtNightTint.lua

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "DroughtNightTint")

local HUB_GROUP = 100
local SOOTOPOLIS = { grp = 0, map = 7, warp = 0 }
local ROUTE126 = { grp = 0, map = 41, warp = 0 }
local W_CMI, W_PALSTATE, W_CURR = 0x200, 0x206, 0x210
local WEATHER_DROUGHT, WEATHER_DOWNPOUR = 12, 13
local PAL_STATE_FADING_IN, PAL_STATE_IDLE = 1, 3
local TIME_DAY, TIME_NIGHT = 1, 3
local TAG_NONE, BLEND_IMMUNE = 0xFFFF, 0x8000

local FLAG_KYOGRE_ESCAPED_SEAFLOOR_CAVERN = 0x81
local FLAG_SYS_WEATHER_CTRL = 0x972
local VAR_SOOTOPOLIS_CITY_STATE = 0x405E

local function setFlag(id)
  local a = F.sb1() + S.SaveBlock1.flags + (id >> 3)
  F.w8(a, F.r8(a) | (1 << (id & 7)))
end

local function setVar(id, v)
  F.w16(F.sb1() + S.SaveBlock1.vars + (id - 0x4000) * 2, v)
end

local function cmi() return F.rs8(S.gWeather + W_CMI) end
local function palState() return F.r8(S.gWeather + W_PALSTATE) end
local function curWeather() return F.r8(S.gWeather + W_CURR) end
local function tod() return F.r8(S.gTimeOfDay) end

local function localTime()
  return F.rs8(S.gLocalTime + S.Time.hours), F.rs8(S.gLocalTime + S.Time.minutes)
end

-- gLocalTime = sRtc - localTimeOffset, so winding the offset forward winds the clock back.
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
end

-- Sum of r+g+b over the colours of a palette range in gPlttBufferFaded (colour 0 skipped).
local function lum(firstPal, lastPal)
  local t = 0
  for p = firstPal, lastPal do
    for c = 1, 15 do
      local v = F.r16(S.gPlttBufferFaded + (p * 16 + c) * 2)
      t = t + (v & 0x1F) + ((v >> 5) & 0x1F) + ((v >> 10) & 0x1F)
    end
  end
  return t
end

local function bgLum() return lum(1, 12) end

-- Object palette slots the time blend is meant to reach: in use and not blend-immune.
local function objLum()
  local t, n = 0, 0
  for i = 0, 15 do
    local tag = F.r16(S.sSpritePaletteTags + i * 2)
    if tag ~= TAG_NONE and (tag & BLEND_IMMUNE) == 0 then
      t = t + lum(16 + i, 16 + i)
      n = n + 1
    end
  end
  return t, n
end

local function d(n) return (n // 100) % 10, (n // 10) % 10, n % 10 end

local function go(spec, tag)
  local gh, gt, go_ = d(spec.grp)
  local mh, mt, mo = d(spec.map)
  local wh, wt, wo = d(spec.warp)
  if not F.warpTo(gh, gt, go_, mh, mt, mo, wh, wt, wo, spec.grp, spec.map, tag) then
    F.check(tag .. "_warped", false, string.format("grp=%d map=%d", F.grp(), F.mapn()))
    return false
  end
  return true
end

local function inDrought()
  return curWeather() == WEATHER_DROUGHT and palState() == PAL_STATE_IDLE and cmi() < 0
end

local function waitFor(pred, maxFrames)
  for _ = 1, maxFrames do
    if pred() then return true end
    F.idle(1)
  end
  return pred()
end

-- One sample per drought stage seen during `frames` frames: stage -> { bg, obj, objSlots }.
local function sampleStages(frames)
  local byStage = {}
  for _ = 1, frames do
    if inDrought() then
      local s = cmi()
      if not byStage[s] then
        local o, n = objLum()
        byStage[s] = { bg = bgLum(), obj = o, objSlots = n }
      end
    end
    F.idle(1)
  end
  return byStage
end

local function stageList(t)
  local out = {}
  for s, v in pairs(t) do out[#out + 1] = string.format("%d:bg%d/obj%d", s, v.bg, v.obj) end
  table.sort(out)
  return table.concat(out, " ")
end

F.run(function()
  if not F.boot(HUB_GROUP) then F.check("boot", false); F.finish(); return end

  setFlag(FLAG_SYS_WEATHER_CTRL)
  setFlag(FLAG_KYOGRE_ESCAPED_SEAFLOOR_CAVERN)
  setVar(VAR_SOOTOPOLIS_CITY_STATE, 2)
  setClock(22, 30)
  F.idle(30)

  if not go(SOOTOPOLIS, "sootopolis") then F.finish(); return end
  setClock(22, 30)
  F.idle(60)
  F.check("night_at_sootopolis", tod() == TIME_NIGHT, "tod=" .. tod())

  -- First phase of WEATHER_ABNORMAL is downpour, then drought after 600 frames.
  local sawDownpour = waitFor(function() return curWeather() == WEATHER_DOWNPOUR end, 300)
  if sawDownpour then
    waitFor(function() return palState() == PAL_STATE_IDLE end, 300)
    F.L(string.format("  night downpour: cmi=%d bg=%d", cmi(), bgLum()))
    F.shot("night_downpour")
  end
  F.check("abnormal_weather_reaches_drought", waitFor(inDrought, 1500),
    string.format("weather=%d palState=%d cmi=%d", curWeather(), palState(), cmi()))

  local night = sampleStages(100)
  waitFor(function() return inDrought() and cmi() == -6 end, 60)
  F.L(string.format("  night drought stages: %s", stageList(night)))
  F.shot("night_drought")

  setClock(14, 30)
  waitFor(function() return tod() == TIME_DAY end, 60)
  local day = sampleStages(100)
  waitFor(function() return inDrought() and cmi() == -6 end, 60)
  F.L(string.format("  day drought stages: %s", stageList(day)))
  F.shot("day_drought")
  F.check("still_one_drought_phase", curWeather() == WEATHER_DROUGHT, "weather=" .. curWeather())

  local compared, bgDarker, objDarker, detail = 0, 0, 0, {}
  for s, n in pairs(night) do
    local dd = day[s]
    if dd then
      compared = compared + 1
      if n.bg * 10 < dd.bg * 8 then bgDarker = bgDarker + 1 end
      if n.objSlots > 0 and n.obj * 10 < dd.obj * 8 then objDarker = objDarker + 1 end
      detail[#detail + 1] = string.format("stage %d bg %d/%d obj %d/%d", s, n.bg, dd.bg, n.obj, dd.obj)
    end
  end
  table.sort(detail)
  F.check("same_drought_stages_sampled_day_and_night", compared >= 2, "stages=" .. compared)
  F.check("night_drought_map_palettes_darker_than_day", compared > 0 and bgDarker == compared,
    string.format("%d/%d stages darker: %s", bgDarker, compared, table.concat(detail, "; ")))
  F.check("night_drought_object_palettes_darker_than_day", compared > 0 and objDarker == compared,
    string.format("%d/%d stages darker", objDarker, compared))

  -- Drought fade-in at night: arrive on Route 126 while the abnormal weather is in its drought
  -- half, so FadeInScreen_Drought runs. The abnormal weather keeps alternating while the debug
  -- menu is open, so the warp is armed first and confirmed only once drought is current.
  setClock(22, 30)
  waitFor(function() return tod() == TIME_NIGHT end, 60)
  F.dbg(); F.sel(0); F.sel(1); F.idle(20)
  F.spin(d(ROUTE126.grp)); F.spin(d(ROUTE126.map))
  F.press("Right", 2); F.idle(8); F.press("Right", 2); F.idle(8)
  for _ = 1, 6 do F.press("Down", 2); F.idle(8) end
  F.check("drought_when_route126_warp_confirmed",
    waitFor(function() return curWeather() == WEATHER_DROUGHT end, 1500), "weather=" .. curWeather())
  F.press("A", 2)
  local fadeMax, fadeFrames = 0, 0
  for _ = 1, 500 do
    F.idle(1)
    if F.grp() == ROUTE126.grp and F.mapn() == ROUTE126.map
        and curWeather() == WEATHER_DROUGHT and palState() == PAL_STATE_FADING_IN then
      fadeFrames = fadeFrames + 1
      fadeMax = math.max(fadeMax, bgLum())
    end
  end
  F.check("arrived_route126", F.grp() == ROUTE126.grp and F.mapn() == ROUTE126.map,
    string.format("grp=%d map=%d", F.grp(), F.mapn()))
  F.check("route126_night", tod() == TIME_NIGHT, "tod=" .. tod())
  local settled = sampleStages(120)
  F.L(string.format("  route126 night drought: fade frames=%d fadeMax=%d settled %s",
    fadeFrames, fadeMax, stageList(settled)))
  F.shot("route126_night_drought")
  local brightest = 0
  for _, v in pairs(settled) do brightest = math.max(brightest, v.bg) end
  F.check("drought_fade_in_sampled", fadeFrames >= 4 and brightest > 0,
    string.format("fadeFrames=%d settledStages=%s", fadeFrames, stageList(settled)))
  F.check("drought_fade_in_never_brighter_than_settled_night", fadeMax <= brightest,
    string.format("fadeMax=%d settledMax=%d", fadeMax, brightest))

  F.finish()
end)
