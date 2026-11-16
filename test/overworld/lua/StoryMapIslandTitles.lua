-- The Story destination map titles each regional map it pins. The Kanto islands are the ORANGE
-- ISLANDS in every player-facing string (b1af7bc9a3), but the map's title still read "Sevii".
-- Celio's quest state is written the way his scripts leave it (scene 4, then 5, then 5 with
-- Icefall Cave's back room done), which makes the optional Kanto objective pin Kindle Road, Four
-- Island and Ruin Valley; the Story screen, its pages and the map are opened with real input.
-- Oracle: the title string the map prints for that pin's regional map (sTitles indexed by the
-- island map's enum RegionMapType), checked while that map is on screen, plus a screenshot of it.
local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "StoryMapIslandTitles")

local USM_ICO_QUESTS = 6
-- enum RegionMapType (include/region_map.h): SEVII123 2, SEVII45 3, SEVII67 4.
local VAR_CELIO = 0xA000 + 0x4F
local VAR_ICEFALL_BACK = 0xA000 + 0x59
local function var(id, value) F.w16(F.sb3() + S.SaveBlock3.regionVars + (id - 0xA000) * 2, value) end

local CHARS = {}
for i = 0, 25 do CHARS[0xBB + i] = string.char(65 + i); CHARS[0xD5 + i] = string.char(97 + i) end
for i = 0, 9 do CHARS[0xA1 + i] = string.char(48 + i) end
CHARS[0x00] = " "; CHARS[0xAE] = "-"; CHARS[0xAD] = "."
local function str(addr)
  local t = {}
  for i = 0, 31 do
    local b = F.r8(addr + i)
    if b == 0xFF then break end
    t[#t + 1] = CHARS[b] or "?"
  end
  return table.concat(t)
end
local function title(mapType) return str(F.r32(S.sTitles + mapType * 4)) end

local function openPinnedOptional(tag)
  F.press("Start", 2); F.idle(40)
  if not F.selectStartIcon(USM_ICO_QUESTS) then return false end
  F.press("A", 2); F.idle(150)
  F.press("A", 2); F.idle(40)
  for _ = 1, 3 do F.press("Right", 2); F.idle(30) end
  F.shot(tag .. "_page")
  F.press("A", 2); F.idle(200)
  F.shot(tag .. "_map")
  return true
end
local function close()
  for _ = 1, 3 do F.press("B", 2); F.idle(80) end
  for _ = 1, 200 do if F.ow() then break end F.press("B", 2); F.idle(20) end
  F.idle(60)
  return F.ow()
end

F.run(function()
  if not F.boot(100) then F.check("fresh boot", false); F.finish(); return end
  for _, c in ipairs({
    { "kindle_road", 4, 0, "1-3", 2 },
    { "four_island", 5, 0, "4-5", 3 },
    { "ruin_valley", 5, 1, "6-7", 4 },
  }) do
    var(VAR_CELIO, c[2]); var(VAR_ICEFALL_BACK, c[3])
    F.check(c[1] .. ": Story map opens", openPinnedOptional(c[1]))
    local t = title(c[5])
    F.check(c[1] .. ": the title names the Orange Islands " .. c[4],
      not F.ow() and t:find("Orange") ~= nil and t:find(c[4], 1, true) ~= nil and t:find("Sevii") == nil, "title=" .. t)
    F.check(c[1] .. ": back to the field", close())
  end
  F.finish()
end)
