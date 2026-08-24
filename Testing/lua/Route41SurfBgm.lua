-- FldEff_UseSurf on Route 41 itself must play MUS_HG_SURF(670),
-- not Hoenn MUS_SURF(365). Does NOT surf across the Route 40 y=60 warp_def row
-- (that LoadMapFromWarp drops SURFING / Overworld_ClearSavedMusic and never
-- re-runs FldEff). Warp to Route 41 land, stand on an elev-3 beach facing
-- 12B water, A -> Surf Yes.
--
-- Run via Testing/mgba-run.sh Testing/lua/Route41SurfBgm.lua

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "Route41SurfBgm")

-- MAP_ROUTE41 = (2|(87<<8)). Warp 4 is (37,12), the Route 40 seam (land).
local GRP_OLIVINE, MAP_ROUTE40, MAP_ROUTE41 = 87, 1, 2
local HUB_GROUP = 100

local FLAG_JOHTO_BASE = 0x6000
local FLAG_JOHTO_BADGE_4 = 0x6000 + 0x3F8 + 3          -- Fog Badge
local FLAG_HIDE_WHIRL_ISLANDS_TENTACRUEL = 0x6000 + 0x102
local TRAINER_FLAGS_START = 0x500
local VARS_START = 0x4000
local VAR_REPEL_STEP_COUNT = 0x4021
local REGION_VARS_START = 0xA000
local VAR_OLIVINE_CITY_STATE = 0xA080 + 0x24

local ITEM_SURF_TOOL = 876
local PLAYER_AVATAR_FLAG_SURFING = 1 << 3
local OBJ_EVENT_MON = 1 << 14
local ID_PLAYER, ID_FOLLOWER = 255, 254
local LOCALID_OWE_END, OWE_SPAWNS_MAX = 252, 4
local MAP_OFFSET = 7
local REGION_JOHTO = 2
local DIR_SOUTH, DIR_NORTH, DIR_WEST, DIR_EAST = 1, 2, 3, 4

local gMPlayInfo_BGM = S.gMPlayInfo_BGM
local gSongTable     = S.gSongTable
local gWeather       = 0x02001b20
local WEATHER_CURR, WEATHER_NEXT = 0x210, 0x211
local WEATHER_TARGET_RAIN, WEATHER_RAIN_COUNT = 0x219, 0x21A
local SB1_WEATHER, WEATHER_NONE = 0x2E, 0
local MUS_SURF, MUS_RG_SURF, MUS_HG_SURF = 365, 517, 670
local MUS_HG_ROUTE38, SAVED_MUSIC = 646, 0x2C

-- Route 40 beach analogue on this map: elev-3 sand 11D/03 facing 12B/01 south.
-- Warp 4 (37,12) is elev-1 rock (2BE/01) facing same-elev water, so A-press Surf
-- (IsPlayerFacingSurfableFishableWater needs ELEVATION_DEFAULT=3 + mismatch)
-- cannot fire there. (13,39) is the island beach south of cave warp 0.
local BEACH = { 13, 39 }
local WATER_ID = 0x12B

local NAMES = {
  [0] = "MUS_DUMMY", [365] = "MUS_SURF", [517] = "MUS_RG_SURF",
  [646] = "MUS_HG_ROUTE38", [670] = "MUS_HG_SURF",
}
local function musName(id)
  return (NAMES[id] or ("song " .. tostring(id))) .. "(" .. tostring(id) .. ")"
end

local TRAINERS = { 953, 958, 1044, 1048, 1052, 1055, 1063, 1064, 1066, 1074, 1076, 1082, 1083, 1085 }

-- ---- accessors -------------------------------------------------------------------------------
local function johtoFlagSet(id, on)
  local a, m = F.sb3() + S.SaveBlock3.johtoFlags + ((id - FLAG_JOHTO_BASE) // 8), 1 << (id % 8)
  local v = F.r8(a)
  F.w8(a, on and (v | m) or (v & ~m & 0xFF))
end
local function johtoFlagGet(id)
  local a, m = F.sb3() + S.SaveBlock3.johtoFlags + ((id - FLAG_JOHTO_BASE) // 8), 1 << (id % 8)
  return (F.r8(a) & m) ~= 0
end
local function sb1FlagSet(id, on)
  local a, m = F.sb1() + S.SaveBlock1.flags + (id // 8), 1 << (id % 8)
  local v = F.r8(a)
  F.w8(a, on and (v | m) or (v & ~m & 0xFF))
end
local function sb1VarSet(id, v)
  F.w16(F.sb1() + S.SaveBlock1.vars + (id - VARS_START) * 2, v)
end
local function regionVarSet(id, v)
  F.w16(F.sb3() + S.SaveBlock3.regionVars + (id - REGION_VARS_START) * 2, v)
end

local function here()
  local x, y = F.pos()
  return string.format("grp=%d map=%d pos=(%d,%d)", F.grp(), F.mapn(), x, y)
end
local function surfing()
  return (F.r8(S.gPlayerAvatar) & PLAYER_AVATAR_FLAG_SURFING) ~= 0
end
local function scriptPtr()
  return F.r32(S.sGlobalScriptContext + S.ScriptCtx.scriptPtr)
end
local function crash(tag)
  return F.reportCrash(tag)
end
local function region()
  return F.r32(S.gCurrentRegion)
end
local function avatarFlags()
  return F.r8(S.gPlayerAvatar)
end
local function headerMusic()
  return F.r16(S.gMapHeader + 0x10)
end
local function savedMusic()
  return F.r16(F.sb1() + SAVED_MUSIC)
end

local function playingSong()
  local hdr = F.r32(gMPlayInfo_BGM)
  if hdr == 0 then return 0 end
  for id = 0, 700 do
    if F.r32(gSongTable + id * 8) == hdr then return id end
  end
  return -1
end

local function waitPlaying(want, frames)
  for _ = 1, (frames or 200) do
    F.idle(1)
    local p = playingSong()
    if want then
      if p == want then return p end
    elseif p > 0 then
      return p
    end
  end
  return playingSong()
end

local function dumpMusic(tag)
  local p, h, s = playingSong(), headerMusic(), savedMusic()
  local x, y = F.pos()
  F.L(string.format("  music[%s] play=%s header=%s saved=%s region=%d avatar=0x%02X surf=%s pos=(%d,%d) grp=%d map=%d",
    tag, musName(p), musName(h), musName(s), region(), avatarFlags(),
    tostring(surfing()), x, y, F.grp(), F.mapn()))
  return p, h, s
end

local function blockAt(x, y)
  local w = F.r32(S.gBackupMapLayout + S.BackupMapLayout.width)
  local map = F.r32(S.gBackupMapLayout + S.BackupMapLayout.map)
  return F.r16(map + ((x + MAP_OFFSET) + (y + MAP_OFFSET) * w) * 2)
end

local function playerObj()
  for i = 0, 15 do
    local b = S.gObjectEvents + i * S.ObjectEvent.stride
    if (F.r8(b) & 1) == 1 and F.r8(b + S.ObjectEvent.localId) == ID_PLAYER then
      return b
    end
  end
  return S.gObjectEvents
end

local function elevNibble()
  local e = F.r8(playerObj() + 0x0B)
  return e & 0xF, (e >> 4) & 0xF
end

local function dumpAround(tag)
  local px, py = F.pos()
  local av = S.gPlayerAvatar
  local curE, prevE = elevNibble()
  F.L(string.format("  dump %s at (%d,%d) surf=%s script=0x%08X flags=0x%02X preventStep=%d elev=%d/%d facing=%d",
    tag, px, py, tostring(surfing()), scriptPtr(), F.r8(av), F.r8(av + 6),
    curE, prevE, F.r16(playerObj() + S.ObjectEvent.facing) & 0xF))
  for y = py - 2, py + 2 do
    local bits = {}
    for x = px - 3, px + 3 do
      local b = blockAt(x, y)
      bits[#bits + 1] = string.format("%03X/%d%d%s", b & 0x3FF, (b >> 10) & 3, (b >> 12) & 0xF,
        (x == px and y == py) and "*" or " ")
    end
    F.L(string.format("    y=%d %s", y, table.concat(bits, " ")))
  end
end

local function behaviorAt(x, y)
  local id = blockAt(x, y) & S.Metatiles.idMask
  local layout = F.r32(S.gMapHeader + S.MapHeader.mapLayout)
  local frlgOrJohto = F.r8(layout + S.MapLayout.isFrlg) ~= 0
                   or F.r8(layout + S.MapLayout.isJohto) ~= 0
  local inPrimary = frlgOrJohto and S.Metatiles.inPrimaryFrlg or S.Metatiles.inPrimary
  local tileset, localId
  if id < inPrimary then
    tileset, localId = F.r32(layout + S.MapLayout.primaryTileset), id
  elseif id < S.Metatiles.total then
    tileset, localId = F.r32(layout + S.MapLayout.secondaryTileset), id - inPrimary
  else
    return -1, id
  end
  local attrs = F.r32(tileset + S.Tileset.metatileAttributes)
  if (F.r8(tileset + S.Tileset.flags1) & S.Tileset.hasFrlgAttributesBit) ~= 0 then
    return F.r32(attrs + localId * 4) & S.Metatiles.behaviorMaskFrlg, id
  end
  return F.r16(attrs + localId * 2) & S.Metatiles.behaviorMask, id
end

local function killWeather()
  F.w8(F.sb1() + SB1_WEATHER, WEATHER_NONE)
  F.w8(gWeather + WEATHER_CURR, WEATHER_NONE)
  F.w8(gWeather + WEATHER_NEXT, WEATHER_NONE)
  F.w8(gWeather + WEATHER_TARGET_RAIN, 0)
  F.w8(gWeather + WEATHER_RAIN_COUNT, 0)
end

local OBJ_TEMPLATES, OBJ_TEMPLATE_STRIDE = 0xF94, 24
local function hideTemplates()
  local keepWp = (F.grp() == GRP_OLIVINE and F.mapn() == MAP_ROUTE41)
  for i = 0, 63 do
    local t = F.sb1() + OBJ_TEMPLATES + i * OBJ_TEMPLATE_STRIDE
    local lid = F.r8(t)
    if lid ~= 0 and not (keepWp and lid >= 34 and lid <= 63) then
      F.w8(t, 0)
    end
  end
end

local PARK_X, PARK_Y = 1 + 7, 1 + 7
local OBJ_PREV_X, OBJ_SPRITE_ID = 0x14, 0x23
local function despawnOwMons()
  local n = 0
  for i = 0, 15 do
    local b = S.gObjectEvents + i * S.ObjectEvent.stride
    if (F.r8(b) & 1) == 1 then
      local id = F.r8(b + S.ObjectEvent.localId)
      local keepWp = F.grp() == GRP_OLIVINE and F.mapn() == MAP_ROUTE41
                     and id >= 34 and id <= 63
      if id ~= ID_PLAYER and not keepWp then
        local sid = F.r8(b + OBJ_SPRITE_ID)
        if sid < S.Sprite.count then
          local sp = S.gSprites + sid * S.Sprite.stride
          F.w16(sp + S.Sprite.inUse, F.r16(sp + S.Sprite.inUse) & ~1)
        end
        F.w16(b + S.ObjectEvent.x, PARK_X)
        F.w16(b + S.ObjectEvent.y, PARK_Y)
        F.w16(b + OBJ_PREV_X, PARK_X)
        F.w16(b + OBJ_PREV_X + 2, PARK_Y)
        F.w8(b, F.r8(b) & ~1)
        n = n + 1
      end
    end
  end
  return n
end

local function parkFollower()
  for i = 0, 15 do
    local b = S.gObjectEvents + i * S.ObjectEvent.stride
    if (F.r8(b) & 1) == 1 and F.r8(b + S.ObjectEvent.localId) == ID_FOLLOWER then
      F.w16(b + S.ObjectEvent.x, PARK_X)
      F.w16(b + S.ObjectEvent.y, PARK_Y)
      F.w16(b + OBJ_PREV_X, PARK_X)
      F.w16(b + OBJ_PREV_X + 2, PARK_Y)
      F.w8(b + S.ObjectEvent.flags1, F.r8(b + S.ObjectEvent.flags1) | 0x20)
    end
  end
end

local function isWarpTile(x, y)
  if y == 12 and x >= 37 and x <= 45 then return true end
  if (x == 13 and y == 37) or (x == 48 and y == 38)
     or (x == 21 and y == 64) or (x == 56 and y == 76) then
    return true
  end
  return false
end

-- Face without taking a step: (37,12) south is walkable-on-foot 12B (same elev),
-- and walking back onto the warp row sends us to Route 40.
local function faceInPlace(dir)
  local d = ({ Down = DIR_SOUTH, Up = DIR_NORTH, Left = DIR_WEST, Right = DIR_EAST })[dir]
  local pob = playerObj()
  local v = F.r16(pob + S.ObjectEvent.facing)
  F.w16(pob + S.ObjectEvent.facing, (v & 0xFF00) | (d << 4) | d)
  F.w8(pob + 0x20, (F.r8(pob + 0x20) & 0xF0) | d)   -- previousMovementDirection
  F.idle(8)
end

local function tryStartSurf(dir, tag)
  local x0, y0 = F.pos()
  faceInPlace(dir)
  F.idle(12)
  local fx, fy = x0, y0
  if dir == "Down" then fy = y0 + 1 elseif dir == "Up" then fy = y0 - 1
  elseif dir == "Right" then fx = x0 + 1 else fx = x0 - 1 end
  local beh, mid = behaviorAt(fx, fy)
  local b = blockAt(fx, fy)
  F.L(string.format("  tryStartSurf %s from (%d,%d) %s front=(%d,%d) %03X/%d%d beh=%d warp=%s",
    dir, x0, y0, tag, fx, fy, b & 0x3FF, (b >> 10) & 3, (b >> 12) & 0xF, beh,
    tostring(isWarpTile(fx, fy))))
  for _ = 1, 8 do
    F.press("A", 2); F.idle(40)
    if surfing() then break end
    if crash("surf_" .. tag) then return false end
  end
  F.idle(200)
  waitPlaying(MUS_HG_SURF, 90)
  local x1, y1 = F.pos()
  F.L(string.format("  after surf attempt %s surf=%s (%d,%d)->(%d,%d)",
    tag, tostring(surfing()), x0, y0, x1, y1))
  return surfing()
end

-- Stay on Route 41. Do not walk onto y=12 x=37-45 (warp_def back to Route 40).
local function placeOnMap(x, y)
  F.w16(F.sb1() + S.SaveBlock1.x, x)
  F.w16(F.sb1() + S.SaveBlock1.y, y)
  local ob = playerObj()
  F.w16(ob + S.ObjectEvent.x, x + 7)
  F.w16(ob + S.ObjectEvent.y, y + 7)
  F.w16(ob + OBJ_PREV_X, x + 7)
  F.w16(ob + OBJ_PREV_X + 2, y + 7)
  F.w8(ob + 0x0B, 0x33)                                -- current+previous elevation = 3
  F.w8(S.gPlayerAvatar, 0x01)
  F.w8(S.gPlayerAvatar + 6, 0)
  F.w8(ob, F.r8(ob) & ~0xC0)
  F.idle(20)
end

local function settleField()
  hideTemplates()
  despawnOwMons()
  parkFollower()
  killWeather()
  sb1VarSet(VAR_REPEL_STEP_COUNT, 250)
end

-- ---- debug give ------------------------------------------------------------------------------
local function tapDown(n)
  for _ = 1, n do F.press("Down", 3); F.idle(16) end
end

local function giveSurfTool()
  F.dbg(); F.idle(60)
  tapDown(3); F.press("A", 3); F.idle(60)
  F.press("A", 3); F.idle(60)
  F.spin(8, 7, 5)
  F.press("A", 2); F.idle(60)
  F.bOut(4); F.idle(60)
end

local function giveLapras()
  F.dbg(); F.idle(60)
  tapDown(3); F.press("A", 3); F.idle(60)
  tapDown(1); F.press("A", 3); F.idle(60)
  F.spin(1, 3, 0)
  F.spin(0, 9, 9)
  F.idle(90)
  F.bOut(4); F.idle(60)
end

local function seedFlags()
  johtoFlagSet(FLAG_JOHTO_BADGE_4, true)
  johtoFlagSet(FLAG_HIDE_WHIRL_ISLANDS_TENTACRUEL, true)
  regionVarSet(VAR_OLIVINE_CITY_STATE, 5)
  for i = 0, 31 do
    F.w8(F.sb3() + S.SaveBlock3.johtoTrainerFlags + i, 0xFF)
  end
  for _, id in ipairs(TRAINERS) do
    sb1FlagSet(TRAINER_FLAGS_START + id, true)
  end
  sb1VarSet(VAR_REPEL_STEP_COUNT, 250)
end

-- ---- main ------------------------------------------------------------------------------------
F.run(function()
  if not F.boot(HUB_GROUP) then F.check("boot", false); F.finish(); return end
  if crash("post_boot") then F.check("boot survived", false); F.finish(); return end

  giveLapras()
  local nParty = F.r8(S.gPartiesCount)
  F.check("Lapras reached the party (QOL_FIELD_MOVES_NO_TEACH can then Surf)",
    nParty >= 1, "gPartiesCount=" .. nParty)
  if nParty < 1 then F.shot("no_party"); F.finish(); return end

  local toolSlot = -1
  for _ = 1, 3 do
    giveSurfTool()
    toolSlot = F.keyItemSlot(ITEM_SURF_TOOL)
    if toolSlot >= 0 then break end
    F.bOut(6); F.idle(60)
  end
  F.check("ITEM_SURF_TOOL is in KEY ITEMS (unlocks Surf without Fog Badge)",
    toolSlot >= 0, "slot=" .. tostring(toolSlot))
  if toolSlot < 0 then F.shot("no_surf_tool"); F.finish(); return end

  F.w8(F.sb2() + S.SaveBlock2.followerSlot, 0)
  parkFollower()
  seedFlags()
  F.check("FLAG_JOHTO_BADGE_4 (Fog / Surf) is set", johtoFlagGet(FLAG_JOHTO_BADGE_4))

  -- Land tile, not a Route 40 water warp. warp 4 = Route 40 seam at (37,12).
  F.check("warp_to_route41_land",
    F.warpTo(0, 8, 7, 0, 0, 2, 0, 0, 4, GRP_OLIVINE, MAP_ROUTE41, "route41") and F.ow(),
    here())
  if crash("after_r41_warp") then F.check("Route 41 warp survived", false); F.finish(); return end
  F.idle(60)
  -- Floor warp can bounce back to Route 40. Re-warp; never Surf from Route 40.
  if F.grp() == GRP_OLIVINE and F.mapn() == MAP_ROUTE40 then
    F.L("  warp 4 bounced to Route 40 -- re-warping to Route 41, not surfing across y=60")
    F.shot("bounced_route40")
    F.warpTo(0, 8, 7, 0, 0, 2, 0, 0, 4, GRP_OLIVINE, MAP_ROUTE41, "route41_retry")
    F.idle(60)
  end
  F.check("standing on Route 41 (not Route 40)",
    F.grp() == GRP_OLIVINE and F.mapn() == MAP_ROUTE41, here())
  if F.grp() ~= GRP_OLIVINE or F.mapn() ~= MAP_ROUTE41 then F.finish(); return end

  settleField()
  dumpAround("route41_arrival")
  dumpMusic("route41_arrival")
  F.shot("route41_land")

  local sx, sy = F.pos()
  F.L(string.format("  Surf-start candidate after warp 4: (%d,%d) warpTile=%s",
    sx, sy, tostring(isWarpTile(sx, sy))))

  -- From (37,12) the south tile is 12B water and is NOT a warp. Try that first.
  -- Do not F.step onto it: same-elev 12B is walkable on foot and walking back
  -- north onto the warp row LoadMapFromWarp's us to Route 40.
  local gotSurf = false
  local startX, startY = sx, sy
  local south = blockAt(sx, sy + 1)
  if (south & 0x3FF) == WATER_ID and not isWarpTile(sx, sy + 1) then
    F.shot("facing_water")
    gotSurf = tryStartSurf("Down", "seam_south")
  end
  if not gotSurf then
    for _, dir in ipairs({ "Left", "Right", "Up" }) do
      if tryStartSurf(dir, "seam_" .. dir) then gotSurf = true; break end
    end
  end

  -- Elev-1 seam does not satisfy IsPlayerFacingSurfableFishableWater. The
  -- Route 40 analogue is elev-3 11D/03 at (13,39) facing 12B/01 at (13,40).
  if not gotSurf then
    F.L("  seam A-press did not Surf (elev-1 rock vs same-elev water); placing on island beach (13,39)")
    placeOnMap(BEACH[1], BEACH[2])
    settleField()
    local px, py = F.pos()
    startX, startY = px, py
    dumpAround("island_beach")
    F.shot("island_beach")
    local front = blockAt(px, py + 1)
    F.check("island beach south tile is 12B water and not a warp",
      (front & 0x3FF) == WATER_ID and not isWarpTile(px, py + 1),
      string.format("front=%03X warp=%s %s", front & 0x3FF, tostring(isWarpTile(px, py + 1)), here()))
    gotSurf = tryStartSurf("Down", "island_beach")
    if not gotSurf then
      gotSurf = tryStartSurf("Left", "beach_west") or tryStartSurf("Right", "beach_east")
    end
  end

  F.check("player is surfing on Route 41 after FldEff_UseSurf (A → Surf Yes)",
    gotSurf or surfing(), here() .. " surf=" .. tostring(surfing()))
  F.idle(30)
  waitPlaying(MUS_HG_SURF, 120)
  local p, h, s = dumpMusic("route41_fld_eff")
  F.shot("route41_fld_eff")

  F.check("gCurrentRegion is JOHTO", region() == REGION_JOHTO, "region=" .. region())
  F.check("avatar SURFING flag is set",
    (avatarFlags() & PLAYER_AVATAR_FLAG_SURFING) ~= 0,
    string.format("avatar=0x%02X", avatarFlags()))
  F.check("still on Route 41 (grp=87 map=2)",
    F.grp() == GRP_OLIVINE and F.mapn() == MAP_ROUTE41, here())
  F.check("FldEff_UseSurf on Route 41 plays MUS_HG_SURF, not Hoenn MUS_SURF",
    p == MUS_HG_SURF, musName(p) .. " saved=" .. musName(s) .. " header=" .. musName(h))
  F.check("not playing Hoenn MUS_SURF / MUS_RG_SURF",
    p ~= MUS_SURF and p ~= MUS_RG_SURF, musName(p))

  F.L(string.format("  RESULT start=(%d,%d) now=%s play=%s header=%s saved=%s region=%d avatar=0x%02X",
    startX, startY, here(), musName(p), musName(h), musName(s), region(), avatarFlags()))
  crash("end")
  F.finish()
end)
