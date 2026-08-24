-- v1.5 playtest: flat wild tables, Roselia/Route123, Rose Incense mart,
-- start-menu quest compile-out, Pokemon Center 2F sealed.
--
-- Fresh game. Title-screen Mystery Gift absence is EncountersIncenseLink_MainMenu.lua.
--
-- Run via Testing/mgba-run.sh Testing/lua/EncountersIncenseLink.lua

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "EncountersIncenseLink")

local HEADER_STRIDE = 84          -- u8+u8+pad + 4 * (5 pointers)
local ENC_TYPES_OFF = 4
local ENC_TYPE_STRIDE = 20        -- land/water/rocks/fishing/hidden
local INFO_MONS_OFF = 4
local WILD_MON_STRIDE = 4
local LAND_SLOTS = 12
local TIMES_OF_DAY = 4
local TIME_DEFAULT, TIME_DAY, TIME_NIGHT = 0, 1, 3
local NIGHT_HOUR, DAY_HOUR = 22, 14
local MAP_UNDEFINED_GROUP, MAP_UNDEFINED_NUM = 0xFF, 0xFF

local SPECIES_ROSELIA = 315
local ITEM_ROSE_INCENSE = 410
local MART_ITEMLIST, MART_ITEMCOUNT = 8, 12
local MB_TALL_GRASS = 2
local USM_ICO_QUESTS = 6
local USM_NAMES = {
  [0] = "POKEDEX", "PARTY", "BAG", "POKENAV", "DEXNAV", "TRAINER",
  "QUESTS", "SAVE", "REST", "OPTIONS", "RETIRE", "DEBUG",
}

-- MAP_ROUTE123 = (38|(0<<8)), warp 0 = Berry Master's House door (22,6).
-- MAP_GOLDENROD_CITY_DEPARTMENT_STORE_4F = (7|(84<<8)).
-- MAP_VIOLET_CITY_POKEMON_CENTER = (4|(78<<8)).
-- MAP_OLDALE_TOWN_POKEMON_CENTER_1F = (2|(2<<8)); 2F still exists as map 3.
local R123 = { g = 0,  m = 38, w = 0, name = "Route123" }
local DEPT4 = { g = 84, m = 7,  w = 0, name = "GoldenrodDept4F" }
local VIOLET_PC = { g = 78, m = 4, w = 0, name = "VioletPC" }
local OLDALE_PC = { g = 2,  m = 2, w = 0, name = "OldalePC1F" }
local OLDALE_2F_MAP = 3

local function d(n) return (n // 100) % 10, (n // 10) % 10, n % 10 end

local function go(grp, map, warp, tag)
  local gh, gt, go_ = d(grp)
  local mh, mt, mo = d(map)
  local wh, wt, wo = d(warp)
  if not F.warpTo(gh, gt, go_, mh, mt, mo, wh, wt, wo, grp, map, tag) then
    F.check(tag .. "_warped", false, string.format("grp=%d map=%d", F.grp(), F.mapn()))
    return false
  end
  F.idle(60)
  return true
end

local function localTime()
  return F.rs8(S.gLocalTime + S.Time.hours), F.rs8(S.gLocalTime + S.Time.minutes)
end

-- JohtoDayNightLive.lua: gLocalTime = sRtc - localTimeOffset, so winding the
-- offset forward winds the clock back. Land on :30. sHoursOverride is the
-- debug-time lever; LoadMapFromWarp zeroes it, so set it AFTER the warp.
local function setLocalTime(targetHour)
  local off = F.sb2() + S.SaveBlock2.localTimeOffset
  local h, m = localTime()
  local deltaMin = ((h * 60 + m) - (targetHour * 60 + 30)) % (24 * 60)
  local newMin = F.rs8(off + S.Time.minutes) + (deltaMin % 60)
  local carry = 0
  if newMin >= 60 then newMin, carry = newMin - 60, 1 end
  F.w8(off + S.Time.minutes, newMin % 60)
  F.w8(off + S.Time.hours, (F.rs8(off + S.Time.hours) + (deltaMin // 60) + carry) % 24)
  F.w8(S.sHoursOverride, targetHour)
  F.w16(S.gTimeUpdateCounter, 0)
end

local function waitTod(want, budget)
  for f = 1, (budget or 200) do
    if F.r8(S.gTimeOfDay) == want then return true, f end
    F.idle(1)
  end
  return false, budget or 200
end

local function findHeader(grp, map)
  for i = 0, 512 do
    local h = S.gWildMonHeaders + i * HEADER_STRIDE
    local hg, hm = F.r8(h), F.r8(h + 1)
    if hg == MAP_UNDEFINED_GROUP and hm == MAP_UNDEFINED_NUM then return nil, i end
    if hg == grp and hm == map then return h, i end
  end
  return nil, -1
end

local function landInfo(header, tod)
  return F.r32(header + ENC_TYPES_OFF + tod * ENC_TYPE_STRIDE)
end

-- GetTimeOfDayForEncounters with OW_TIME_OF_DAY_ENCOUNTERS==FALSE always
-- returns TIME_OF_DAY_DEFAULT. Fallback is what a TRUE build would do on a
-- NULL night slot, so both paths are logged; the game-used pointer is slot 0.
local function resolveLand(header, tod)
  local info = landInfo(header, tod)
  local usedTod = tod
  if info == 0 then
    info = landInfo(header, TIME_DEFAULT)
    usedTod = TIME_DEFAULT
  end
  return info, usedTod
end

local function landSpecies(info)
  local t = {}
  if info == 0 then return t end
  local mons = F.r32(info + INFO_MONS_OFF)
  if mons < 0x08000000 or mons >= 0x0A000000 then return t end
  for i = 0, LAND_SLOTS - 1 do
    t[#t + 1] = F.r16(mons + i * WILD_MON_STRIDE + 2)
  end
  return t
end

local function fmtList(t)
  if #t == 0 then return "{}" end
  return "{" .. table.concat(t, ",") .. "}"
end

local function listsEq(a, b)
  if #a ~= #b then return false end
  for i = 1, #a do if a[i] ~= b[i] then return false end end
  return true
end

local function hasSpecies(t, id)
  for i = 1, #t do if t[i] == id then return i - 1 end end
  return nil
end

local function dumpTodSlots(header, tag)
  local parts = {}
  for tod = 0, TIMES_OF_DAY - 1 do
    parts[#parts + 1] = string.format("tod%d=0x%08x", tod, landInfo(header, tod))
  end
  F.L("  " .. tag .. " land slots: " .. table.concat(parts, " "))
end

local function playerMb()
  return F.r8(S.gObjectEvents + 0x1E)
end

local function mapBlock(x, y)
  local layout = S.gBackupMapLayout
  local width = F.r32(layout + S.BackupMapLayout.width)
  local map = F.r32(layout + S.BackupMapLayout.map)
  local gx, gy = x + S.BackupMapLayout.mapOffset, y + S.BackupMapLayout.mapOffset
  if width == 0 or map < 0x02000000 then return 0 end
  return F.r16(map + (gx + gy * width) * 2)
end

local function metatileBehavior(x, y)
  local id = mapBlock(x, y) & S.Metatiles.idMask
  local mapLayout = F.r32(S.gMapHeader + S.MapHeader.mapLayout)
  local primary = F.r32(mapLayout + S.MapLayout.primaryTileset)
  local secondary = F.r32(mapLayout + S.MapLayout.secondaryTileset)
  local inPrimary = S.Metatiles.inPrimary
  local flags1 = F.r8(primary + S.Tileset.flags1)
  if (flags1 & S.Tileset.hasFrlgAttributesBit) ~= 0 or F.r8(mapLayout + S.MapLayout.isFrlg) ~= 0
     or F.r8(mapLayout + S.MapLayout.isJohto) ~= 0 then
    inPrimary = S.Metatiles.inPrimaryFrlg
  end
  local ts, localId
  if id < inPrimary then ts, localId = primary, id else ts, localId = secondary, id - inPrimary end
  local attrs = F.r32(ts + S.Tileset.metatileAttributes)
  local frlg = (F.r8(ts + S.Tileset.flags1) & S.Tileset.hasFrlgAttributesBit) ~= 0
  if frlg then
    return F.r32(attrs + localId * 4) & S.Metatiles.behaviorMaskFrlg
  end
  return F.r16(attrs + localId * 2) & S.Metatiles.behaviorMask
end

local function findGrassNear(cx, cy, rad)
  for r = 0, rad do
    for dy = -r, r do
      for dx = -r, r do
        if math.abs(dx) == r or math.abs(dy) == r then
          local x, y = cx + dx, cy + dy
          if metatileBehavior(x, y) == MB_TALL_GRASS then return x, y end
        end
      end
    end
  end
  return nil
end

local function martCount() return F.r16(S.sMartInfo + MART_ITEMCOUNT) end
local function martList() return F.r32(S.sMartInfo + MART_ITEMLIST) end
local function clearMartInfo()
  F.w32(S.sMartInfo + MART_ITEMLIST, 0)
  F.w16(S.sMartInfo + MART_ITEMCOUNT, 0)
end
local function martItems()
  local p, n, t = martList(), martCount(), {}
  if p ~= 0 and n > 0 and n < 64 then
    for i = 0, n - 1 do t[#t + 1] = F.r16(p + i * 2) end
  end
  return t
end

local function talkMart(tx, ty, faceDir, tag)
  if not F.leg(tx, ty) then
    F.check(tag .. "_reached_clerk", false, string.format("wanted (%d,%d) at (%d,%d)", tx, ty, F.pos()))
    return false
  end
  F.face(faceDir)
  clearMartInfo()
  for _ = 1, 16 do
    F.press("A", 2); F.idle(40)
    if martCount() > 0 then F.idle(30); return true end
  end
  F.L("  " .. tag .. ": shop did not open after 16 A presses")
  F.shot("noshop_" .. tag)
  return true
end

local function usmSaved()
  local a = F.sb3() + S.SaveBlock3.usmSaved
  local n = F.r8(a + 12)
  local items = {}
  if n > 12 then n = 12 end
  for i = 0, n - 1 do items[#items + 1] = F.r8(a + i) end
  return items, n
end

local function fmtUsm(items)
  local names = {}
  for i = 1, #items do names[#names + 1] = USM_NAMES[items[i]] or tostring(items[i]) end
  return table.concat(names, ",")
end

-- USM stays on CB2_Overworld (it freezes the avatar rather than swapping
-- callback2), so "menu is open" is usmSaved.count, not F.ow().
local function openStartMenu()
  F.idle(60)
  F.press("Start", 2); F.idle(90)
  local _, n = usmSaved()
  if n > 0 then return true end
  F.press("Start", 2); F.idle(90)
  _, n = usmSaved()
  return n > 0
end

local function warpEvents()
  local events = F.r32(S.gMapHeader + 4)
  if events < 0x08000000 then return {}, 0 end
  local n = F.r8(events + 1)
  local p = F.r32(events + 8)
  local t = {}
  if n > 16 then n = 16 end
  for i = 0, n - 1 do
    local b = p + i * 8
    t[#t + 1] = {
      x = F.rs16(b), y = F.rs16(b + 2),
      destMap = F.r8(b + 6), destGroup = F.r8(b + 7),
    }
  end
  return t, n
end

F.run(function()
  -- Probe the header table against Route 101 (group 0, map 16) so a bad stride
  -- cannot silently walk past Route 123.
  do
    local hg, hm = F.r8(S.gWildMonHeaders), F.r8(S.gWildMonHeaders + 1)
    F.check("S.gWildMonHeaders[0] is Route101 (group 0 map 16)", hg == 0 and hm == 16,
      string.format("group=%d map=%d", hg, hm))
  end

  if not F.boot(100) then F.check("boot to overworld", false); F.finish(); return end
  F.check("booted to the RegionHub (map group 100)", F.grp() == 100, "grp=" .. F.grp())

  -- ---- start menu: QUEST compiled out -------------------------------------------------------
  -- FLAG_SYS_QUEST_MENU_GET would surface a QUESTS icon if QUEST_MENU were TRUE.
  do
    local id = 0x94B  -- SYSTEM_FLAGS + 3
    local a = F.sb1() + S.SaveBlock1.flags + (id // 8)
    F.w8(a, F.r8(a) | (1 << (id % 8)))
  end
  F.check("start_menu_opened", openStartMenu())
  F.idle(30)
  local usmItems, usmN = usmSaved()
  F.L("  start-menu items (" .. usmN .. "): " .. fmtUsm(usmItems) .. " ids=" .. fmtList(usmItems))
  local hasQuest = false
  for i = 1, #usmItems do if usmItems[i] == USM_ICO_QUESTS then hasQuest = true end end
  F.check("start menu has no QUEST/MISSION row", not hasQuest,
    "items=" .. fmtUsm(usmItems))
  F.check("start menu has at least BAG/TRAINER/SAVE/OPTION", usmN >= 3 and usmN <= 8,
    "count=" .. usmN)
  F.shot("start_menu")
  F.press("B", 2); F.idle(60)
  F.check("start menu closed back to overworld", F.ow())

  -- ---- Route 123: flat wild tables + Roselia ------------------------------------------------
  if not go(R123.g, R123.m, R123.w, "to_route123") then F.finish(); return end
  F.check("on Route 123", F.grp() == 0 and F.mapn() == 38,
    string.format("grp=%d map=%d", F.grp(), F.mapn()))
  local header = findHeader(0, 38)
  F.check("Route 123 has a wild header", header ~= nil)
  if not header then F.finish(); return end

  dumpTodSlots(header, "on_arrival")
  local morningPtr = landInfo(header, TIME_DEFAULT)
  F.check("TIME_MORNING land table is non-NULL", morningPtr ~= 0,
    string.format("ptr=0x%08x", morningPtr))
  -- With OW_TIME_OF_DAY_ENCOUNTERS FALSE the generator only fills TIME_MORNING.
  local nightSlot = landInfo(header, TIME_NIGHT)
  local daySlot = landInfo(header, TIME_DAY)
  F.check("TIME_DAY land slot is empty (no separate day table)", daySlot == 0,
    string.format("ptr=0x%08x", daySlot))
  F.check("TIME_NIGHT land slot is empty (no separate night table)", nightSlot == 0,
    string.format("ptr=0x%08x", nightSlot))

  setLocalTime(DAY_HOUR)
  local dayOk, dayFrames = waitTod(TIME_DAY, 240)
  local dh, dm = localTime()
  F.L(string.format("  day clock %02d:%02d tod=%d after %d frames", dh, dm, F.r8(S.gTimeOfDay), dayFrames))
  F.check("clock wound to DAY (gTimeOfDay=TIME_DAY)", dayOk,
    "tod=" .. F.r8(S.gTimeOfDay))
  local dayUsed, dayUsedTod = resolveLand(header, F.r8(S.gTimeOfDay))
  local dayDefault = landInfo(header, TIME_DEFAULT)
  local daySpecies = landSpecies(dayDefault)
  F.L("  day game-used land ptr=0x" .. string.format("%08x", dayDefault)
      .. " (index-by-gTimeOfDay -> tod " .. dayUsedTod .. " ptr=0x" .. string.format("%08x", dayUsed) .. ")")
  F.L("  day species " .. fmtList(daySpecies))
  F.shot("route123_day")

  setLocalTime(NIGHT_HOUR)
  local nightOk, nightFrames = waitTod(TIME_NIGHT, 240)
  local nh, nm = localTime()
  F.L(string.format("  night clock %02d:%02d tod=%d after %d frames", nh, nm, F.r8(S.gTimeOfDay), nightFrames))
  F.check("clock wound to NIGHT (gTimeOfDay=TIME_NIGHT)", nightOk,
    "tod=" .. F.r8(S.gTimeOfDay))
  F.check("gTimeOfDay actually changed day -> night", F.r8(S.gTimeOfDay) ~= TIME_DAY,
    "tod=" .. F.r8(S.gTimeOfDay))
  local nightUsed, nightUsedTod = resolveLand(header, F.r8(S.gTimeOfDay))
  local nightDefault = landInfo(header, TIME_DEFAULT)
  local nightSpecies = landSpecies(nightDefault)
  F.L("  night game-used land ptr=0x" .. string.format("%08x", nightDefault)
      .. " (index-by-gTimeOfDay -> tod " .. nightUsedTod .. " ptr=0x" .. string.format("%08x", nightUsed) .. ")")
  F.L("  night species " .. fmtList(nightSpecies))
  F.shot("route123_night")

  F.check("day and night use the SAME land table pointer", dayDefault == nightDefault and dayDefault ~= 0,
    string.format("day=0x%08x night=0x%08x", dayDefault, nightDefault))
  F.check("day and night species lists are identical", listsEq(daySpecies, nightSpecies),
    "day " .. fmtList(daySpecies) .. " night " .. fmtList(nightSpecies))
  F.check("index-by-gTimeOfDay with fallback also matches", dayUsed == nightUsed and dayUsed == dayDefault,
    string.format("dayUsed=0x%08x nightUsed=0x%08x", dayUsed, nightUsed))

  local slot = hasSpecies(daySpecies, SPECIES_ROSELIA)
  F.check("SPECIES_ROSELIA is in Route 123 land table", slot ~= nil,
    slot and ("slot " .. slot .. " species=" .. SPECIES_ROSELIA) or ("list " .. fmtList(daySpecies)))

  -- One grass step if a tall-grass tile is in walking range of warp 0.
  local px, py = F.pos()
  local gx, gy = findGrassNear(px, py, 24)
  if gx then
    F.L(string.format("  grass tile (%d,%d) mb=%d from (%d,%d)", gx, gy, metatileBehavior(gx, gy), px, py))
    local walked = F.leg(gx, gy)
    local wx, wy = F.pos()
    F.check("walked onto a Route 123 grass tile", walked and F.ow(),
      string.format("at (%d,%d) mb=%d ow=%s", wx, wy, playerMb(), tostring(F.ow())))
    F.shot("route123_grass")
  else
    F.L("  no tall-grass tile within 8 of warp 0; skipping the cheap walk")
    F.check("Route 123 land table still readable without a grass walk", #daySpecies == LAND_SLOTS)
  end

  -- ---- Goldenrod Dept 4F: Rose Incense ------------------------------------------------------
  if not go(DEPT4.g, DEPT4.m, DEPT4.w, "to_dept4f") then F.finish(); return end
  F.check("on Goldenrod Dept Store 4F", F.grp() == 84 and F.mapn() == 7,
    string.format("grp=%d map=%d", F.grp(), F.mapn()))
  -- Worker M at (13,6) runs GoldenrodDeptStore4_EventScript_Cooltrainer (the incense mart).
  -- Warp 0 is (17,5); axis-first to (13,7) walks through the NPC at (13,6), so drop
  -- to y=7 first. Greeting is gText_HowMayIServeYou with a \p.
  F.check("dept4f_approached_clerk", F.route({ { 17, 7 }, { 13, 7 } }, "to_incense_clerk"),
    string.format("at (%d,%d)", F.pos()))
  local opened = talkMart(13, 7, "Up", "rose_incense")
  F.check("4F incense clerk opened a shop", opened and martCount() > 0,
    "itemCount=" .. martCount() .. " list=0x" .. string.format("%08x", martList()))
  local items = martItems()
  F.L("  mart items " .. fmtList(items))
  local hasRose = false
  for i = 1, #items do if items[i] == ITEM_ROSE_INCENSE then hasRose = true end end
  F.check("ITEM_ROSE_INCENSE is in the 4F mart list", hasRose,
    "ids=" .. fmtList(items) .. " want " .. ITEM_ROSE_INCENSE)
  F.check("Rose Incense is the first item", items[1] == ITEM_ROSE_INCENSE,
    "first=" .. tostring(items[1]))
  F.shot("dept4f_mart")
  F.check("cancelling the shop returns field control", F.dismiss(60))

  -- ---- Pokemon Center 2F sealed -------------------------------------------------------------
  if not go(VIOLET_PC.g, VIOLET_PC.m, VIOLET_PC.w, "to_violet_pc") then F.finish(); return end
  F.check("on Violet Pokemon Center 1F", F.grp() == 78 and F.mapn() == 4,
    string.format("grp=%d map=%d", F.grp(), F.mapn()))
  local warps, warpN = warpEvents()
  F.L("  Violet PC warps: count=" .. warpN)
  for i, w in ipairs(warps) do
    F.L(string.format("    warp%d (%d,%d) -> group %d map %d", i, w.x, w.y, w.destGroup, w.destMap))
  end
  F.check("Violet PC has no 2F/Cable Club warp (only the 1F exit)", warpN == 1,
    "warpCount=" .. warpN)
  if warps[1] then
    F.check("the one warp is the street exit, not a 2F map",
      not (warps[1].destGroup == 78 and warps[1].destMap ~= 4) and warps[1].destGroup ~= 2,
      string.format("dest group=%d map=%d", warps[1].destGroup, warps[1].destMap))
  end
  -- Classic Emerald 1F stair tiles. Johto layout may wall them; either blocked
  -- or walkable-with-no-map-change satisfies "2F sealed".
  local stairTried = false
  for _, tile in ipairs({ { 1, 6 }, { 2, 6 }, { 1, 5 }, { 2, 5 } }) do
    local x0, y0 = F.pos()
    local reached = F.leg(tile[1], tile[2])
    F.idle(40)
    local nx, ny = F.pos()
    local still = F.grp() == 78 and F.mapn() == 4
    F.L(string.format("  stair tile (%d,%d) reached=%s still1F=%s now=(%d,%d) map=%d/%d",
      tile[1], tile[2], tostring(reached), tostring(still), nx, ny, F.grp(), F.mapn()))
    if reached then
      stairTried = true
      F.check("standing on old stair tile (" .. tile[1] .. "," .. tile[2] .. ") does not leave 1F",
        still, string.format("grp=%d map=%d", F.grp(), F.mapn()))
      break
    else
      -- restore if the walk stuck partway
      if not (x0 == select(1, F.pos()) and y0 == select(2, F.pos())) then
        F.leg(x0, y0)
      end
    end
  end
  if not stairTried then
    F.check("old 2F stair tiles are blocked on Violet 1F (no warp to 2F)", true,
      "could not occupy (1,6)/(2,6)/(1,5)/(2,5)")
  end
  F.shot("violet_pc")
  F.check("still on Violet 1F after the stair probe", F.grp() == 78 and F.mapn() == 4,
    string.format("grp=%d map=%d", F.grp(), F.mapn()))

  -- Hoenn Oldale: 2F map still exists (group 2 map 3) but the 1F stair warps are gone.
  if go(OLDALE_PC.g, OLDALE_PC.m, OLDALE_PC.w, "to_oldale_pc") then
    F.check("on Oldale Pokemon Center 1F", F.grp() == 2 and F.mapn() == 2,
      string.format("grp=%d map=%d", F.grp(), F.mapn()))
    local ow, on = warpEvents()
    F.L("  Oldale PC 1F warps: count=" .. on)
    local to2F = false
    for i, w in ipairs(ow) do
      F.L(string.format("    warp%d (%d,%d) -> group %d map %d", i, w.x, w.y, w.destGroup, w.destMap))
      if w.destGroup == 2 and w.destMap == OLDALE_2F_MAP then to2F = true end
    end
    F.check("Oldale 1F has no warp to PokemonCenter_2F", not to2F, "warpCount=" .. on)
    -- Vanilla stair tiles (1,6)/(2,6). Walk on; map must stay 1F.
    local route = { { 4, 8 }, { 1, 8 }, { 1, 6 } }
    local got = F.route(route, "oldale_stairs")
    F.idle(60)
    local still1F = F.grp() == 2 and F.mapn() == 2
    F.check("Oldale old stair tile does not warp to 2F", still1F,
      string.format("reached=%s grp=%d map=%d pos=(%d,%d)", tostring(got), F.grp(), F.mapn(), F.pos()))
    F.shot("oldale_pc_stairs")
  end

  F.finish()
end)
