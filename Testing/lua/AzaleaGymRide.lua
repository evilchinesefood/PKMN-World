-- Issue #89: Azalea Gym Ariados ride carriers. Templates must be
-- OBJ_EVENT_GFX_SPECIES(ARIADOS), not a generic Lass.
-- Map: data/maps/AzaleaTown_Gym/map.json.
--
-- Run via Testing/mgba-run.sh Testing/lua/AzaleaGymRide.lua

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path

local S = require("symbols")
local F = require("lib").new(S, "AzaleaGymRide")

local GRP_GYM, MAP_GYM = 81, 0
local HUB_GROUP = 100
local OBJ_EVENT_MON = 1 << 14
local SPECIES_MASK = 0x8FFF
local SPECIES_ARIADOS = 168
local GFX_LASS = 47
local TEMPLATES = 3988
local TEMPLATE = { stride = 24, localId = 0, graphicsId = 1, x = 4, y = 6, flagId = 20 }
local GYM_OBJECTS = 13
local MAIN_VBLANK_COUNTER1 = 0x20
local PLAYER, CAMERA, FOLLOWER = 0xFF, 0x7F, 0xFE

-- Trigger 2 is (11,39); warp is (11,44). Not adjacent — five tiles north.
-- Script: Trigger_2 rides MID1, comment "2-9->6". End tile is (16,27) = trigger 6.
local TRIGGER = { 11, 39 }
local RIDE_END = { 16, 27 }

local function vblank() return F.r32(S.gMain + MAIN_VBLANK_COUNTER1) end

local function gfxLabel(gfx)
  if (gfx & OBJ_EVENT_MON) ~= 0 then
    local sp = gfx & SPECIES_MASK
    if sp == SPECIES_ARIADOS then return "ARIADOS" end
    return string.format("MON species=%d", sp)
  end
  if gfx == GFX_LASS then return "LASS" end
  return string.format("gfx=%d", gfx)
end

local function eachObj()
  local out = {}
  for i = 0, 15 do
    local b = S.gObjectEvents + i * S.ObjectEvent.stride
    if (F.r8(b) & 1) == 1 then
      out[#out + 1] = {
        i = i,
        localId = F.r8(b + S.ObjectEvent.localId),
        x = F.rs16(b + S.ObjectEvent.x) - 7,
        y = F.rs16(b + S.ObjectEvent.y) - 7,
        gfx = F.r16(b + S.ObjectEvent.graphicsId),
        invisible = (F.r8(b + S.ObjectEvent.flags1) & 0x20) ~= 0,
      }
    end
  end
  return out
end

local function dumpObjs(tag)
  local objs = eachObj()
  F.L(string.format("  --- gObjectEvents %s (n=%d) ---", tag, #objs))
  for _, o in ipairs(objs) do
    F.L(string.format("    slot%02d localId=%3d (%d,%d) %s vis=%s",
      o.i, o.localId, o.x, o.y, gfxLabel(o.gfx), o.invisible and "no" or "yes"))
  end
  return objs
end

local function assertAlive(tag)
  local t0 = vblank()
  F.idle(8)
  local crashed, text = F.reportCrash(tag)
  local t1 = vblank()
  F.check("no crash screen (" .. tag .. ")", not crashed, text or "clear")
  F.check("vblank advancing (" .. tag .. ")", t1 > t0,
    string.format("vblank %d -> %d cb2=0x%08X ow=%s", t0, t1, F.cb2(), tostring(F.ow())))
  return not crashed
end

local function scanTemplates()
  local base = F.sb1() + TEMPLATES
  local found, lass, bad, dump = 0, 0, {}, {}
  for i = 0, GYM_OBJECTS - 1 do
    local t = base + i * TEMPLATE.stride
    local gfx = F.r16(t + TEMPLATE.graphicsId)
    local x, y = F.rs16(t + TEMPLATE.x), F.rs16(t + TEMPLATE.y)
    local localId = F.r8(t + TEMPLATE.localId)
    dump[#dump + 1] = string.format("t%d id=%d (%d,%d) %s", i, localId, x, y, gfxLabel(gfx))
    if gfx == GFX_LASS then
      lass = lass + 1
      bad[#bad + 1] = string.format("template %d localId %d is LASS at (%d,%d)", i, localId, x, y)
    end
    if (gfx & OBJ_EVENT_MON) ~= 0 and (gfx & SPECIES_MASK) == SPECIES_ARIADOS then
      found = found + 1
    end
  end
  F.L("  templates: " .. table.concat(dump, "; "))
  return found, lass, bad
end

F.run(function()
  if not F.boot(HUB_GROUP) then F.check("boot to hub", false); F.finish(); return end
  assertAlive("boot")

  if not F.warpTo(0, 8, 1, 0, 0, 0, 0, 0, 0, GRP_GYM, MAP_GYM, "gym") then
    F.check("warp MAP_AZALEA_TOWN_GYM", false, "warpTo failed")
    F.finish(); return
  end
  F.check("on Azalea Gym", F.grp() == GRP_GYM and F.mapn() == MAP_GYM,
    string.format("grp=%d map=%d", F.grp(), F.mapn()))
  F.shot("gym_arrival")
  assertAlive("gym_arrival")

  local found, lass, bad = scanTemplates()
  F.check("six ARIADOS templates loaded (OBJ_EVENT_MON | SPECIES_ARIADOS)",
    found == 6, string.format("found %d/6", found))
  F.check("no gym carrier template is OBJ_EVENT_GFX_LASS", lass == 0,
    #bad > 0 and table.concat(bad, "; ") or "none")

  local objs = dumpObjs("arrival")
  local spawnedAriados, spawnedLass = 0, 0
  for _, o in ipairs(objs) do
    if o.localId ~= PLAYER and o.localId ~= CAMERA and o.localId ~= FOLLOWER then
      if (o.gfx & OBJ_EVENT_MON) ~= 0 and (o.gfx & SPECIES_MASK) == SPECIES_ARIADOS then
        spawnedAriados = spawnedAriados + 1
      end
      if o.gfx == GFX_LASS then spawnedLass = spawnedLass + 1 end
    end
  end
  -- ON_TRANSITION sets the three hide flags, so carriers should not be out on arrival.
  F.check("no LASS sprite spawned as a ride carrier", spawnedLass == 0, "lass=" .. spawnedLass)
  F.L(string.format("  spawned ARIADOS on arrival: %d (expected 0; hide flags set on transition)", spawnedAriados))

  local x0, y0 = F.pos()
  F.L(string.format("  gym warp landing (%d,%d); trigger 2 is (%d,%d)", x0, y0, TRIGGER[1], TRIGGER[2]))
  local dist = math.abs(x0 - TRIGGER[1]) + math.abs(y0 - TRIGGER[2])
  if dist > 8 then
    F.check("ride trigger is close enough to attempt", false,
      string.format("landing (%d,%d) is %d tiles from trigger 2 — skipping the ride", x0, y0, dist))
    F.finish(); return
  end

  -- Five tiles, not one. Stop on (11,40) then step north onto the trigger so the
  -- last F.step is the tile that fires the coord event (a mid-leg script lock
  -- would otherwise look like a blocked walk).
  local stepped = F.route({ { TRIGGER[1], TRIGGER[2] + 1 } }, "to_trigger2")
  if stepped then stepped = F.step("Up") end
  F.check("stepped onto trigger 2 (11,39)", stepped,
    string.format("at (%d,%d)", select(1, F.pos()), select(2, F.pos())))
  F.shot("on_trigger")
  if not stepped then F.finish(); return end

  -- Script locks the player and addobject's the mid Ariados. Wait for a carrier sprite.
  local sawAriados, sawLass, endReached = false, false, false
  local t0 = vblank()
  for i = 1, 1800 do
    if F.reportCrash("ride") then
      F.check("ride did not crash", false, "crash during Ariados ride")
      F.finish(); return
    end
    local x, y = F.pos()
    if x == RIDE_END[1] and y == RIDE_END[2] and F.ow() then
      -- still moving? give the script a moment to release
      endReached = true
    end
    for _, o in ipairs(eachObj()) do
      if o.localId ~= PLAYER and o.localId ~= CAMERA and o.localId ~= FOLLOWER then
        if (o.gfx & OBJ_EVENT_MON) ~= 0 and (o.gfx & SPECIES_MASK) == SPECIES_ARIADOS then
          sawAriados = true
        end
        if o.gfx == GFX_LASS then sawLass = true end
      end
    end
    if i == 40 then
      dumpObjs("ride_t40")
      F.shot("ride_mid")
    end
    if endReached and i > 80 then
      -- wait until movement settles on the end tile
      local x2, y2 = F.pos()
      if x2 == RIDE_END[1] and y2 == RIDE_END[2] then break end
    end
    F.idle(2)
  end
  local x, y = F.pos()
  dumpObjs("ride_end")
  F.shot("ride_end")
  assertAlive("ride_end")

  F.check("ride carrier that spawned was ARIADOS (not LASS)",
    sawAriados and not sawLass,
    string.format("ariados=%s lass=%s", tostring(sawAriados), tostring(sawLass)))
  if sawAriados and x == RIDE_END[1] and y == RIDE_END[2] then
    F.check("player finished the trigger-2 ride at (16,27)", true,
      string.format("(%d,%d) vblank +%d", x, y, vblank() - t0))
  elseif sawAriados then
    F.check("player finished the trigger-2 ride at (16,27)", false,
      string.format("sprite was ARIADOS but ended at (%d,%d) — ride too long/fragile or dest wrong", x, y))
    F.L("  stopping after the sprite assert as the ride did not settle on the expected tile")
  else
    F.check("player finished the trigger-2 ride at (16,27)", false,
      string.format("no ARIADOS spawned; ended (%d,%d)", x, y))
  end

  F.finish()
end)
