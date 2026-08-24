-- Issue #165: Day Care / Goldenrod Flower Shop flower animation.
-- These maps have no flower object events. johto_day_care shipped red_flower and
-- yellow_flower sheets that InitTilesetAnim_JohtoDayCare now copies into VRAM
-- (secondary local tiles 88-91 and 92-95, i.e. FRLG-primary 640 + 88/92).
-- A stuck frame-0 the whole idle is the old bug.
--
-- Run via Testing/mgba-run.sh Testing/lua/DayCareFlowers.lua

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "DayCareFlowers")

local HUB_GROUP = 100
local GRP_DAY, MAP_DAY, WARP_DAY = 81, 5, 0     -- MAP_ROUTE34_DAY_CARE
local GRP_SHOP, MAP_SHOP, WARP_SHOP = 84, 11, 0 -- MAP_GOLDENROD_CITY_FLOWER_SHOP
local TILE_PRIMARY_FRLG = 640
local TILE_SIZE = 32
local VRAM = 0x06000000
local RED_TILE, YEL_TILE = TILE_PRIMARY_FRLG + 88, TILE_PRIMARY_FRLG + 92
local RED_VRAM = VRAM + RED_TILE * TILE_SIZE
local YEL_VRAM = VRAM + YEL_TILE * TILE_SIZE
local CTRL_VRAM = VRAM + (TILE_PRIMARY_FRLG + 0) * TILE_SIZE  -- non-flower secondary tile 0
local IDLE_FRAMES = 120

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

local function tileSig(addr)
  -- 4 tiles * 32 bytes. Mix so a frame swap is visible even if a few pixels match.
  local h = 0
  for i = 0, 63 do
    h = (h + F.r16(addr + i * 2) * (i + 1)) & 0xFFFFFFFF
  end
  return h
end

local function dumpObjs(tag)
  local n = 0
  F.L("  objects[" .. tag .. "]:")
  for i = 0, 15 do
    local b = S.gObjectEvents + i * S.ObjectEvent.stride
    if (F.r8(b) & 1) == 1 then
      n = n + 1
      local sid = F.r8(b + 0x23)
      local acmd, afrm = -1, -1
      if sid < 64 then
        local sp = S.gSprites + sid * S.Sprite.stride
        acmd = F.r8(sp + 0x2B)  -- Sprite.animCmdIndex is a bitfield near animNum
        afrm = F.r8(sp + 0x2C)
      end
      F.L(string.format("    i=%d local=%d gfx=0x%04X xy=(%d,%d) sprite=%d acmd=%d aframe=%d",
        i, F.r8(b + S.ObjectEvent.localId), F.r16(b + S.ObjectEvent.graphicsId),
        F.rs16(b + S.ObjectEvent.x) - 7, F.rs16(b + S.ObjectEvent.y) - 7, sid, acmd, afrm))
    end
  end
  if n == 0 then F.L("    (none)") end
end

local function watchMap(tag)
  local cb = F.r32(S.sSecondaryTilesetAnimCallback)
  local cnt0 = F.r16(S.sSecondaryTilesetAnimCounter)
  F.L(string.format("  %s callback=0x%08X counter=%d want~=0x%08X",
    tag, cb, cnt0, S.TilesetAnim_JohtoDayCare))
  F.check(tag .. ": JohtoDayCare tileset callback is hooked",
    (cb & ~1) == S.TilesetAnim_JohtoDayCare,
    string.format("callback=0x%08X", cb))

  dumpObjs(tag .. "_start")
  local red0, yel0, ctrl0 = tileSig(RED_VRAM), tileSig(YEL_VRAM), tileSig(CTRL_VRAM)
  local redSeen, yelSeen = { [red0] = true }, { [yel0] = true }
  local nRed, nYel, nCtrl = 1, 1, 1
  local redLast, yelLast, ctrlLast = red0, yel0, ctrl0
  local cntLast = cnt0
  local cntChanged = false
  F.L(string.format("  %s t0 red=%08X yel=%08X ctrl=%08X", tag, red0, yel0, ctrl0))

  for f = 1, IDLE_FRAMES do
    F.idle(1)
    local red, yel, ctrl = tileSig(RED_VRAM), tileSig(YEL_VRAM), tileSig(CTRL_VRAM)
    local cnt = F.r16(S.sSecondaryTilesetAnimCounter)
    if cnt ~= cntLast then cntChanged = true; cntLast = cnt end
    if red ~= redLast then
      if not redSeen[red] then nRed = nRed + 1; redSeen[red] = true end
      redLast = red
    end
    if yel ~= yelLast then
      if not yelSeen[yel] then nYel = nYel + 1; yelSeen[yel] = true end
      yelLast = yel
    end
    if ctrl ~= ctrlLast then nCtrl = nCtrl + 1; ctrlLast = ctrl end
    if f == 60 or f == IDLE_FRAMES then
      F.L(string.format("  %s t%d red=%08X(%d) yel=%08X(%d) ctrl_changes=%d counter=%d",
        tag, f, red, nRed, yel, nYel, nCtrl - 1, cnt))
    end
  end

  F.shot(tag .. "_idle")
  F.check(tag .. ": secondary anim counter advances", cntChanged,
    "counter stuck at " .. tostring(cnt0))
  F.check(tag .. ": red flower VRAM actually changes (not stuck on frame 0)",
    nRed >= 2, "unique_sigs=" .. nRed)
  F.check(tag .. ": yellow flower VRAM actually changes (not stuck on frame 0)",
    nYel >= 2, "unique_sigs=" .. nYel)
end

F.run(function()
  if not F.boot(HUB_GROUP) then F.check("boot to the hub", false); F.finish(); return end
  F.idle(40)

  if not go(GRP_DAY, MAP_DAY, WARP_DAY, "daycare") then F.finish(); return end
  F.shot("daycare_arrival")
  watchMap("daycare")

  if not go(GRP_SHOP, MAP_SHOP, WARP_SHOP, "flowershop") then F.finish(); return end
  F.shot("flowershop_arrival")
  watchMap("flowershop")

  F.finish()
end)
