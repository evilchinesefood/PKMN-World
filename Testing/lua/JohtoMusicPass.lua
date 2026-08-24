-- Issue #173: Johto outdoor maps, cycling, and Radio Tower occupation
-- play MUS_HG_* rather than Hoenn/Kanto themes.
-- Follower grass/bug (#167) and Day Care flower anim (#165) are skipped (not trivial here).
--
-- Run via Testing/mgba-run.sh Testing/lua/JohtoMusicPass.lua

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "JohtoMusicPass")

local MUS_DUMMY            = 0
local MUS_SURF             = 365
local MUS_CYCLING          = 403
local MUS_RG_CYCLING       = 494
local MUS_RG_SURF          = 517
local MUS_HG_GOLDENROD     = 624
local MUS_HG_ROUTE30       = 644
local MUS_HG_ROUTE34       = 645
local MUS_HG_ROCKET_TAKEOVER = 641
local MUS_HG_CYCLING       = 669
local MUS_HG_SURF          = 670

local REGION_JOHTO = 2
local REGION_VARS_START = 0xA000
local VAR_GOLDENROD_CITY_STATE = 0xA080 + 0x03  -- VAR_JOHTO_SLICE(0x03)

local ITEM_BICYCLE = 706
local SAVED_MUSIC = 0x2C                     -- offsetof(SaveBlock1, savedMusic)
local AVATAR_FLAG_BIKE = (1 << 1) | (1 << 2) -- MACH | ACRO
local HUB_GROUP = 100

-- MAP_ROUTE31 = (4|(75<<8)), MAP_GOLDENROD_CITY = (0|(83<<8)),
-- MAP_GOLDENROD_CITY_RADIO_TOWER_1F = (18|(84<<8)), MAP_GATE_GOLDENROD_CITY_ROUTE35 = (6|(83<<8)).
local R31    = { g = 75, m =  4, w = 1, name = "Route31",    want = MUS_HG_ROUTE30,   tag = "route31" }
local GOLD   = { g = 83, m =  0, w = 0, name = "Goldenrod",  want = MUS_HG_GOLDENROD, tag = "goldenrod" }
local RADIO  = { g = 84, m = 18, w = 0, name = "RadioTower1F", want = MUS_HG_GOLDENROD, tag = "radio" }
local GATE   = { g = 83, m =  6, w = 0, name = "Route35Gate", want = MUS_HG_ROUTE34,   tag = "gate" }

local NAMES = {
  [0] = "MUS_DUMMY", [365] = "MUS_SURF", [403] = "MUS_CYCLING",
  [494] = "MUS_RG_CYCLING", [517] = "MUS_RG_SURF",
  [624] = "MUS_HG_GOLDENROD", [641] = "MUS_HG_ROCKET_TAKEOVER",
  [644] = "MUS_HG_ROUTE30", [645] = "MUS_HG_ROUTE34",
  [669] = "MUS_HG_CYCLING", [670] = "MUS_HG_SURF",
}
local function musName(id) return (NAMES[id] or ("song " .. tostring(id))) .. "(" .. tostring(id) .. ")" end

local function d(n) return (n // 100) % 10, (n // 10) % 10, n % 10 end

local function goldStateAddr()
  return F.sb3() + S.SaveBlock3.regionVars + (VAR_GOLDENROD_CITY_STATE - REGION_VARS_START) * 2
end
local function setGoldState(v) F.w16(goldStateAddr(), v) end
local function goldState() return F.r16(goldStateAddr()) end

local function headerMusic() return F.r16(S.gMapHeader + 0x10) end
local function savedMusic() return F.r16(F.sb1() + SAVED_MUSIC) end
local function region() return F.r32(S.gCurrentRegion) end
local function avatarFlags() return F.r8(S.gPlayerAvatar) end

local function playingSong()
  local hdr = F.r32(S.gMPlayInfo_BGM)
  if hdr == 0 then return 0 end
  for id = 0, 700 do
    if F.r32(S.gSongTable + id * 8) == hdr then return id end
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
  F.L(string.format("  music[%s] play=%s header=%s saved=%s region=%d avatar=0x%02X pos=(%d,%d) grp=%d map=%d",
    tag, musName(p), musName(h), musName(s), region(), avatarFlags(),
    x, y, F.grp(), F.mapn()))
  return p, h, s
end

local function go(dest, tag)
  local gh, gt, go_ = d(dest.g)
  local mh, mt, mo = d(dest.m)
  local wh, wt, wo = d(dest.w)
  if not F.warpTo(gh, gt, go_, mh, mt, mo, wh, wt, wo, dest.g, dest.m, tag) then
    F.check(tag .. "_warped", false, string.format("grp=%d map=%d", F.grp(), F.mapn()))
    return false
  end
  F.idle(90)
  waitPlaying(nil, 90)
  return true
end

local function giveBicycle()
  local ptr = F.r32(S.gBagPockets + 4 * S.BagPocket.stride)
  local cap = F.pocketCap(4)
  local key = F.r32(F.sb2() + S.SaveBlock2.encryptionKey)
  if ptr < 0x02000000 or ptr >= 0x02040000 or cap < 1 then return false end
  F.w16(ptr, ITEM_BICYCLE)
  F.w16(ptr + 2, (1 ~ key) & 0xFFFF)
  F.w16(F.sb1() + 0x496, ITEM_BICYCLE)  -- SaveBlock1.registeredItem
  return F.r16(ptr) == ITEM_BICYCLE
end

F.run(function()
  if not F.boot(HUB_GROUP) then F.check("boot", false); F.finish(); return end

  -- ---- Johto outdoor header + currently playing BGM -----------------------------------------
  if not go(R31, "route31") then F.finish(); return end
  F.shot("route31")
  local p, h = dumpMusic("route31")
  F.check("Route 31 gCurrentRegion is JOHTO", region() == REGION_JOHTO, "region=" .. region())
  F.check("Route 31 header is MUS_HG_ROUTE30", h == MUS_HG_ROUTE30, musName(h))
  F.check("Route 31 is playing MUS_HG_ROUTE30 (not a Hoenn/Kanto route theme)",
    p == MUS_HG_ROUTE30, musName(p))
  F.check("Route 31 is not playing Hoenn MUS_CYCLING/MUS_SURF by accident",
    p ~= MUS_CYCLING and p ~= MUS_SURF, musName(p))

  if not go(GOLD, "goldenrod") then F.finish(); return end
  F.shot("goldenrod")
  p, h = dumpMusic("goldenrod")
  F.check("Goldenrod City header is MUS_HG_GOLDENROD", h == MUS_HG_GOLDENROD, musName(h))
  F.check("Goldenrod City is playing MUS_HG_GOLDENROD", p == MUS_HG_GOLDENROD, musName(p))

  -- ---- Radio Tower occupation vs peacetime --------------------------------------------------
  -- LoadMapFromWarp clears savedMusic, then ON_TRANSITION savebgm's takeover iff state in [6,11).
  setGoldState(6)
  F.check("seeded VAR_GOLDENROD_CITY_STATE=6", goldState() == 6, "state=" .. goldState())
  if not go(RADIO, "radio_occupied") then F.finish(); return end
  F.idle(30)
  waitPlaying(MUS_HG_ROCKET_TAKEOVER, 120)
  F.shot("radio_occupied")
  p, h = dumpMusic("radio_occupied")
  local saved = savedMusic()
  F.check("occupied Radio Tower 1F header stays MUS_HG_GOLDENROD (override is savebgm, not the header)",
    h == MUS_HG_GOLDENROD, musName(h))
  F.check("occupied Radio Tower 1F savedMusic is MUS_HG_ROCKET_TAKEOVER",
    saved == MUS_HG_ROCKET_TAKEOVER, musName(saved))
  F.check("occupied Radio Tower 1F is playing MUS_HG_ROCKET_TAKEOVER",
    p == MUS_HG_ROCKET_TAKEOVER, musName(p))

  -- Must leave the map: warpTo the current map is a documented no-op that leaves the debug menu open.
  setGoldState(0)
  F.check("cleared VAR_GOLDENROD_CITY_STATE=0", goldState() == 0, "state=" .. goldState())
  if not go(GATE, "gate_between") then F.finish(); return end
  dumpMusic("gate_between")
  if not go(RADIO, "radio_peace") then F.finish(); return end
  F.idle(30)
  waitPlaying(MUS_HG_GOLDENROD, 120)
  F.shot("radio_peace")
  p, h = dumpMusic("radio_peace")
  saved = savedMusic()
  F.check("peacetime Radio Tower 1F header is MUS_HG_GOLDENROD", h == MUS_HG_GOLDENROD, musName(h))
  F.check("peacetime Radio Tower 1F savedMusic is cleared", saved == MUS_DUMMY, musName(saved))
  F.check("peacetime Radio Tower 1F is playing MUS_HG_GOLDENROD (not leftover takeover)",
    p == MUS_HG_GOLDENROD, musName(p))

  -- ---- Cycling in Johto ---------------------------------------------------------------------
  -- Radio Tower forbids bikes. Warp to Route 31 (allow_cycling), register the Bicycle, Select.
  if not go(R31, "route31_bike") then F.finish(); return end
  dumpMusic("pre_bike")
  local gave = giveBicycle()
  F.check("wrote ITEM_BICYCLE into Key Items and registered it", gave,
    "key0=" .. tostring(F.r16(F.r32(S.gBagPockets + 4 * S.BagPocket.stride))))
  F.idle(20)
  F.press("Select", 2); F.idle(90)
  waitPlaying(MUS_HG_CYCLING, 120)
  F.shot("cycling")
  p = dumpMusic("cycling")
  local flags = avatarFlags()
  local onBike = (flags & AVATAR_FLAG_BIKE) ~= 0
  F.check("Select mounted the bicycle on Route 31", onBike, string.format("avatar=0x%02X", flags))
  if onBike then
    F.check("cycling in Johto plays MUS_HG_CYCLING (not MUS_CYCLING / MUS_RG_CYCLING)",
      p == MUS_HG_CYCLING, musName(p))
    F.check("cycling savedMusic is MUS_HG_CYCLING", savedMusic() == MUS_HG_CYCLING, musName(savedMusic()))
  else
    F.check("cycling in Johto plays MUS_HG_CYCLING (skipped: could not mount bike)", false,
      "play=" .. musName(p) .. " avatar=0x" .. string.format("%02X", flags))
  end

  -- Surfing: needs a Surf-capable party and a water tile. Not driven.
  F.L("  SKIP surf: no Surf user / water approach in this suite (FldEff_UseSurf is GetCurrentRegion-gated the same way as GetOnOffBike)")
  F.L("  SKIP #167 follower Grass/Bug outdoor message (not trivial)")
  F.L("  SKIP #165 Day Care flower animCmdIndex (not driven)")

  F.finish()
end)
