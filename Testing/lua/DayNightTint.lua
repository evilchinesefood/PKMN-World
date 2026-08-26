-- Issue #120 playtest C: day/night TINT (not Johto objects).
--
-- OverworldBasic (src/overworld.c:2019-2038) calls UpdateTimeOfDay(TRUE) each
-- tick and ApplyWeatherColorMapIfIdle when gTimeBlend changes AND MapHasNaturalLight.
-- field_weather.c:798 TRUE is fade-in. rtc.c:333 FALSE is GetTimeOfDay (no blend).
-- JohtoDayNightLive.lua already crosses 19:59→20:00 on Route 37 but asserts
-- flags/objects, NOT palettes. This suite copies its setLocalTime /
-- gTimeUpdateCounter=0 technique and reads gTimeBlend + gPlttBufferFaded.
--
-- Do not claim a Johto object swap as tint.
--
-- Run via Testing/mgba-run.sh Testing/lua/DayNightTint.lua

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "DayNightTint")

local HUB_GROUP = 100
local TIME_MORNING, TIME_DAY, TIME_EVENING, TIME_NIGHT = 0, 1, 2, 3
local MAP_TYPE_ROUTE, MAP_TYPE_TOWN, MAP_TYPE_CITY, MAP_TYPE_UNDERGROUND = 3, 1, 2, 4
local DAY_HOUR, NIGHT_CROSS_FROM, NIGHT_CROSS_TO, NIGHT_HOUR = 14, 19, 20, 22

-- Maps. Warp id 0: Route 101 / Route 1 have empty warp lists, and the debug
-- warp then centres the map. Route 37 warp 0 is (17,10). Granite Cave 1F warp 0
-- is the Route 106 entrance at (37,12).
local MAPS = {
  { name = "hoenn_route101", grp = 0,  map = 16, warp = 0, outdoor = true },
  { name = "kanto_route1",   grp = 37, map = 19, warp = 0, outdoor = true },
  { name = "johto_route37",  grp = 83, map = 3,  warp = 0, outdoor = true },
  { name = "cave_granite",   grp = 24, map = 7,  warp = 0, outdoor = false },
}

local function d(n) return (n // 100) % 10, (n // 10) % 10, n % 10 end

local function go(grp, map, warp, tag)
  local gh, gt, go_ = d(grp)
  local mh, mt, mo = d(map)
  local wh, wt, wo = d(warp)
  if not F.warpTo(gh, gt, go_, mh, mt, mo, wh, wt, wo, grp, map, tag) then
    F.check(tag .. "_warped", false, string.format("grp=%d map=%d", F.grp(), F.mapn()))
    return false
  end
  F.idle(90)
  return true
end

local function localTime()
  return F.rs8(S.gLocalTime + S.Time.hours), F.rs8(S.gLocalTime + S.Time.minutes)
end

-- gLocalTime = sRtc - localTimeOffset, so winding the offset FORWARD winds the
-- clock BACK. sHoursOverride is NOT usable across a warp (LoadMapFromWarp zeroes
-- it). Land on the requested minute so 19:59→20:00 is a real crossing.
local function setClock(targetHour, targetMin)
  targetMin = targetMin or 30
  local off = F.sb2() + S.SaveBlock2.localTimeOffset
  local h, m = localTime()
  local deltaMin = ((h * 60 + m) - (targetHour * 60 + targetMin)) % (24 * 60)
  local newMin = F.rs8(off + S.Time.minutes) + (deltaMin % 60)
  local carry = 0
  if newMin >= 60 then newMin, carry = newMin - 60, 1 end
  F.w8(off + S.Time.minutes, newMin % 60)
  F.w8(off + S.Time.hours, (F.rs8(off + S.Time.hours) + (deltaMin // 60) + carry) % 24)
  F.w8(S.sHoursOverride, 0)
end

local function forceTick()
  F.w16(S.gTimeUpdateCounter, 0)
  -- ApplyWeatherColorMapIfIdle may start a palette fade; wait it out.
  F.idle(120)
end

local function mapType()
  return F.r8(S.gMapHeader + 0x18)
end

local function blendWords()
  return F.r32(S.gTimeBlend), F.r32(S.gTimeBlend + 4), F.r32(S.gTimeBlend + 8)
end

-- Map pals 1-12 (skip pal 0 UI). 192 words.
local PAL_LO, PAL_HI = 16, 16 * 13 - 1

local function palSnap()
  local t = {}
  for i = PAL_LO, PAL_HI do
    t[#t + 1] = F.r16(S.gPlttBufferFaded + i * 2)
  end
  return t
end

local function palChanged(a, b)
  if not a or not b or #a ~= #b then return 0, 0 end
  local n = 0
  for i = 1, #a do
    if a[i] ~= b[i] then n = n + 1 end
  end
  return n, #a
end

local function palDigest(snap)
  local d = 0
  for i = 1, #snap do
    d = (d + snap[i] * i) & 0xFFFFFFFF
  end
  return d
end

local function hwPlttSample()
  -- Hardware BG_PLTT, same window lib.lua's crashScreen reads. Informational:
  -- VBlank copies gPlttBufferFaded over it.
  return F.r16(0x05000000), F.r16(0x05000000 + 2), F.r16(0x05000000 + 32), F.r16(0x05000000 + 34)
end

local function logState(tag)
  local h, m = localTime()
  local b0, b1, b2 = blendWords()
  local p0, p1, p16, p17 = hwPlttSample()
  F.L(string.format(
    "  %s: clock %02d:%02d tod=%d mapType=%d blend=%08X %08X %08X fadedDigest=0x%08X BG_PLTT[0,1,16,17]=%04X %04X %04X %04X",
    tag, h, m, F.r8(S.gTimeOfDay), mapType(), b0, b1, b2, palDigest(palSnap()), p0, p1, p16, p17))
end

local function crossOnMap(spec)
  local tag = spec.name
  -- Always warp from a different map so warpTo cannot no-op (group+map success test).
  if F.grp() == spec.grp and F.mapn() == spec.map then
    if not go(HUB_GROUP, 0, 0, tag .. "_via_hub") then return end
  end
  if not go(spec.grp, spec.map, spec.warp, tag) then return end
  F.check(tag .. "_on_map", F.grp() == spec.grp and F.mapn() == spec.map,
    string.format("grp=%d map=%d", F.grp(), F.mapn()))

  local g0, m0 = F.grp(), F.mapn()
  local x0, y0 = F.pos()
  local leftOw = false

  -- DAY baseline. Standing still, no warp during the tick.
  setClock(DAY_HOUR, 30)
  forceTick()
  if not F.ow() then leftOw = true end
  logState(tag .. "_day")
  local dayBlend = { blendWords() }
  local dayPal = palSnap()
  local dayTod = F.r8(S.gTimeOfDay)
  F.shot(tag .. "_day")
  F.check(tag .. "_day_is_day_or_morning",
    dayTod == TIME_DAY or dayTod == TIME_MORNING, "tod=" .. dayTod)

  -- 19:59 evening, still standing.
  setClock(NIGHT_CROSS_FROM, 59)
  forceTick()
  if not F.ow() then leftOw = true end
  logState(tag .. "_1959")
  F.shot(tag .. "_1959")

  -- 20:00 night crossing. This is NIGHT_HOUR_BEGIN.
  setClock(NIGHT_CROSS_TO, 0)
  forceTick()
  if not F.ow() then leftOw = true end
  logState(tag .. "_2000")
  local nightBlend = { blendWords() }
  local nightPal = palSnap()
  local nightTod = F.r8(S.gTimeOfDay)
  F.shot(tag .. "_night")

  F.check(tag .. "_no_warp_during_tick",
    not leftOw and F.ow() and F.grp() == g0 and F.mapn() == m0,
    string.format("leftOw=%s map %d/%d -> %d/%d ow=%s",
      tostring(leftOw), g0, m0, F.grp(), F.mapn(), tostring(F.ow())))
  local x1, y1 = F.pos()
  F.check(tag .. "_player_did_not_move", x1 == x0 and y1 == y0,
    string.format("(%d,%d)->(%d,%d)", x0, y0, x1, y1))

  local nCh, nTot = palChanged(dayPal, nightPal)
  local blendChanged = dayBlend[1] ~= nightBlend[1]
    or dayBlend[2] ~= nightBlend[2]
    or dayBlend[3] ~= nightBlend[3]
  F.L(string.format("  %s: palWordsChanged=%d/%d blendChanged=%s tod %d->%d",
    tag, nCh, nTot, tostring(blendChanged), dayTod, nightTod))

  F.check(tag .. "_gTimeOfDay_is_night_after_20",
    nightTod == TIME_NIGHT, "tod=" .. nightTod)

  if spec.outdoor then
    F.check(tag .. "_outdoor_tint_changed",
      nCh > 0 or blendChanged,
      string.format("palChanged=%d/%d blend %08X/%08X/%08X -> %08X/%08X/%08X",
        nCh, nTot, dayBlend[1], dayBlend[2], dayBlend[3],
        nightBlend[1], nightBlend[2], nightBlend[3]))
    -- Outdoor maps have natural light. A handful of words is not enough to
    -- prove DNS ran if a tileset anim flipped one colour, but blend+many pals
    -- together is. Require the blend (UpdateTimeOfDay TRUE) at minimum.
    F.check(tag .. "_gTimeBlend_words_changed", blendChanged,
      string.format("%08X %08X %08X -> %08X %08X %08X",
        dayBlend[1], dayBlend[2], dayBlend[3],
        nightBlend[1], nightBlend[2], nightBlend[3]))
  else
    F.check(tag .. "_cave_mapType_is_underground",
      mapType() == MAP_TYPE_UNDERGROUND, "mapType=" .. mapType())
    -- MapHasNaturalLight is false for UNDERGROUND, so ApplyWeatherColorMapIfIdle
    -- is skipped. gTimeOfDay / gTimeBlend may still advance; map pals must not
    -- take the night tint. Tileset anim can flip a few words — night tint
    -- would flip most of pals 1-12.
    F.check(tag .. "_cave_map_pals_not_night_tinted",
      nCh < 40,
      string.format("palChanged=%d/%d (cave should stay put; outdoor night flips most of these)",
        nCh, nTot))
  end
end

-- Fade-in at night: field_weather.c TRUE path. Be outdoors at night, warp in
-- (LoadMapFromWarp fades from black). localTimeOffset survives the warp;
-- sHoursOverride does not.
local function fadeInNight()
  -- Leave the current map first so the Route 101 warp actually fires.
  if F.grp() == 0 and F.mapn() == 16 then
    if not go(HUB_GROUP, 0, 0, "fade_via_hub") then return end
  end
  setClock(NIGHT_HOUR, 0)
  if not go(0, 16, 0, "fadein_route101") then return end
  logState("fadein_night")
  F.check("fadein_night_is_night", F.r8(S.gTimeOfDay) == TIME_NIGHT,
    "tod=" .. F.r8(S.gTimeOfDay))
  F.check("fadein_night_is_outdoor_route", mapType() == MAP_TYPE_ROUTE,
    "mapType=" .. mapType())
  local b0, b1, b2 = blendWords()
  F.check("fadein_night_gTimeBlend_is_nonzero_tint",
    b0 ~= 0 or b1 ~= 0 or b2 ~= 0,
    string.format("blend %08X %08X %08X", b0, b1, b2))
  F.shot("fadein_night_outdoor")
end

F.run(function()
  if not F.boot(HUB_GROUP) then F.check("boot to the hub", false); F.finish(); return end
  F.check("player is free before the clock work", F.ensureFree())

  -- Interleave outdoor/indoor so no two consecutive warps target the same
  -- group+map (warpTo's success test is group+map only).
  for _, spec in ipairs(MAPS) do
    crossOnMap(spec)
  end
  fadeInNight()

  F.finish()
end)
