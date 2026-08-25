-- #205 leftover: Celio's first-meeting gifts must survive a full Key Items pocket.
--
-- MeetCelioScene still has to finish (Bill walks off, scene leaves 0 so ON_FRAME cannot
-- replay). The offers that did not fit must come back when the player talks to Celio.
--
-- Run via Testing/mgba-run.sh Testing/lua/CelioBagFull.lua

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "CelioBagFull")

local HUB_GROUP = 100
local GRP, MAPN, WARP = 64, 0, 0   -- MAP_ONE_ISLAND_POKEMON_CENTER_1F
local ITEM_TOWN_MAP, ITEM_METEORITE, ITEM_TRI_PASS = 713, 743, 753
local REGION_VARS_START = 0xA000
local VAR_SCENE = 0xA000 + 0x4F    -- VAR_MAP_SCENE_ONE_ISLAND_POKEMON_CENTER_1F
local POCKET_KEY = 4

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

local function sceneVar()
  return F.r16(F.sb3() + S.SaveBlock3.regionVars + (VAR_SCENE - REGION_VARS_START) * 2)
end

local function keyPtr()
  return F.r32(S.gBagPockets + POCKET_KEY * S.BagPocket.stride)
end

local function fillKeyPocket(full)
  local ptr, cap = keyPtr(), F.pocketCap(POCKET_KEY)
  local key = F.r32(F.sb2() + S.SaveBlock2.encryptionKey)
  local qty = full and ((1 ~ key) & 0xFFFF) or 0
  if ptr < 0x02000000 or ptr >= 0x02040000 or cap < 1 or cap > 120 then
    F.L(string.format("  key pocket unusable ptr=0x%08X cap=%d", ptr, cap))
    return false
  end
  local id = 1
  for s = 0, cap - 1 do
    if full then
      F.w16(ptr + s * 4, id)
      F.w16(ptr + s * 4 + 2, qty)
      id = id + 1
    else
      F.w16(ptr + s * 4, 0)
      F.w16(ptr + s * 4 + 2, 0)
    end
  end
  return true
end

local function walkTo(tx, ty, tag)
  for _ = 1, 80 do
    if F.reportCrash("walk_" .. tag) then return false end
    local x, y = F.pos()
    if x == tx and y == ty then return true end
    local dir
    if x < tx then dir = "Right" elseif x > tx then dir = "Left"
    elseif y < ty then dir = "Down" else dir = "Up" end
    if not F.step(dir) then
      F.L(string.format("  walk %s blocked at (%d,%d)->(%d,%d)", tag, x, y, tx, ty))
      F.shot(tag .. "_stuck")
      return false
    end
  end
  return false
end

local function mashA(tries, tag)
  for i = 1, (tries or 120) do
    if F.reportCrash(tag) then return false end
    F.press("A", 2); F.idle(20)
    if i % 8 == 0 and F.ensureFree() then return true end
  end
  return F.ensureFree()
end

local function dismiss()
  for _ = 1, 40 do F.press("B", 2); F.idle(20) end
  F.ensureFree()
end

F.run(function()
  if not F.boot(HUB_GROUP) then F.check("boot", false); F.finish(); return end

  local filled = fillKeyPocket(true)
  F.check("Key Items pocket filled (99 occupied, none of the three gifts)",
    filled and F.itemCount(ITEM_METEORITE) == 0 and F.itemCount(ITEM_TRI_PASS) == 0
      and F.itemCount(ITEM_TOWN_MAP) == 0,
    string.format("filled=%s met=%d tri=%d map=%d cap=%d",
      tostring(filled), F.itemCount(ITEM_METEORITE), F.itemCount(ITEM_TRI_PASS),
      F.itemCount(ITEM_TOWN_MAP), F.pocketCap(POCKET_KEY)))

  if not go(GRP, MAPN, WARP, "oneisland_pc") then F.finish(); return end
  F.check("on One Island Pokemon Center 1F", F.grp() == GRP and F.mapn() == MAPN,
    string.format("grp=%d map=%d", F.grp(), F.mapn()))
  F.shot("arrival")

  -- ON_FRAME at scene 0 runs MeetCelioScene. Mash A through movements + bag-full boxes.
  mashA(180, "meet_celio")
  dismiss()
  F.shot("after_cutscene")

  F.check("scene advanced to 1 (cutscene cannot replay)", sceneVar() == 1,
    "scene=" .. sceneVar())
  F.check("Meteorite not taken into a full pocket", F.itemCount(ITEM_METEORITE) == 0,
    "count=" .. F.itemCount(ITEM_METEORITE))
  F.check("Tri Pass not taken into a full pocket", F.itemCount(ITEM_TRI_PASS) == 0,
    "count=" .. F.itemCount(ITEM_TRI_PASS))
  F.check("Town Map not taken into a full pocket", F.itemCount(ITEM_TOWN_MAP) == 0,
    "count=" .. F.itemCount(ITEM_TOWN_MAP))

  F.check("emptied Key Items pocket for retry", fillKeyPocket(false))
  F.check("pocket empty before retry", F.itemCount(ITEM_METEORITE) == 0
    and F.itemCount(ITEM_TRI_PASS) == 0 and F.itemCount(ITEM_TOWN_MAP) == 0)

  -- Celio's default tile is (15,6). Talk from the south.
  local atCelio = walkTo(15, 7, "celio")
  F.check("reached Celio's talk tile (15,7)", atCelio, string.format("pos=(%d,%d)", F.pos()))
  if not atCelio then F.finish(); return end
  F.face("Up")
  F.shot("before_retry")
  mashA(80, "celio_retry")
  dismiss()
  F.shot("after_retry")

  F.check("Meteorite received on Celio retry", F.itemCount(ITEM_METEORITE) >= 1,
    "count=" .. F.itemCount(ITEM_METEORITE))
  F.check("Tri Pass received on Celio retry", F.itemCount(ITEM_TRI_PASS) >= 1,
    "count=" .. F.itemCount(ITEM_TRI_PASS))
  F.check("Town Map received on Celio retry", F.itemCount(ITEM_TOWN_MAP) >= 1,
    "count=" .. F.itemCount(ITEM_TOWN_MAP))

  F.finish()
end)
