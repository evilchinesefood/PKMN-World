-- The Firefighter Squirtle quest's well helper must answer from the tile she faces.
--
-- The kiln helper sends the player to a helper "on the east side of SLOWPOKE WELL". She stood on
-- the elevation-2 platform beside the well facing down onto an elevation-3 tile, and an object
-- only answers a player on its own elevation, so walking up to her from the front and pressing A
-- did nothing. The suite starts the quest through the kiln helper with real input, walks to the
-- tile the well helper faces (read from her live object), talks to her, and finishes the quest at
-- the kiln.
--
-- Run via: test/overworld/mgba-run.sh test/overworld/lua/SpecialWellHelperApproach.lua <rom.gba>

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "SpecialWellHelperApproach")

local FLAG_SYS_POKEMON_GET = 0x948
local FIRE_STARTED, FIRE_WATER = 0xDE7, 0xDE8
local FIRE_UNLOCKED, FIRE_COLLECTED = 0xDDE, 0xDD4
local SPECIES_SQUIRTLE_FIREFIGHTER = 1577
local LOCALID_WELL_HELPER = 14
local AZALEA_G, AZALEA_M, AZALEA_PC_WARP = 80, 0, 3
local KILN_G, KILN_M = 81, 1
local DIRS = { [1] = { 0, 1, "Up" }, [2] = { 0, -1, "Down" }, [3] = { -1, 0, "Right" }, [4] = { 1, 0, "Left" } }

local function flag(id, value)
  local address, bit = F.sb1() + S.SaveBlock1.flags + id // 8, 1 << (id % 8)
  if value ~= nil then
    local old = F.r8(address)
    F.w8(address, value and (old | bit) or (old & ~bit & 0xFF))
  end
  return (F.r8(address) & bit) ~= 0
end

local function instantText()
  local a = F.sb2() + S.SaveBlock2.optionsU16
  F.w16(a, (F.r16(a) & ~7) | 3)
end

local function liveMenu()
  for i = 0, S.Task.count - 1 do
    local task = S.gTasks + i * S.Task.stride
    local fn = F.r32(task + S.Task.func) & 0xFFFFFFFE
    if F.r8(task + S.Task.isActive) ~= 0 and (fn == S.Task_HandleYesNoInput or fn == S.Task_HandleMultichoiceInput) then
      return true
    end
  end
  return false
end

local function scriptIdle() return F.ow() and F.r8(S.sGlobalScriptContextStatus) == 2 end

-- Press A facing `dir`. Returns whether a script started, then answers YES to every prompt and
-- advances every message until control returns.
local function talk(dir, tag)
  F.face(dir)
  F.press("A", 2); F.idle(20)
  local started = not scriptIdle()
  F.shot(tag)
  for n = 1, 400 do
    if F.reportCrash(tag) then return started end
    if liveMenu() then F.press("A", 2); F.idle(40)
    elseif n > 2 and scriptIdle() then return started
    else F.press("A", 2); F.idle(16) end
  end
  return started
end

local function warp(g, m, w, tag)
  return F.warpTo(g // 100, (g // 10) % 10, g % 10, m // 100, (m // 10) % 10, m % 10, 0, 0, w, g, m, tag)
end

local function helper()
  for i = 0, 15 do
    local b = S.gObjectEvents + i * S.ObjectEvent.stride
    if (F.r8(b) & 1) ~= 0 and F.r8(b + S.ObjectEvent.localId) == LOCALID_WELL_HELPER then
      return F.rs16(b + S.ObjectEvent.x) - 7, F.rs16(b + S.ObjectEvent.y) - 7, F.r16(b + S.ObjectEvent.facing) & 0xF
    end
  end
end

local function talkToKilnHelper(tag)
  if not warp(KILN_G, KILN_M, 0, tag) then return false end
  F.dismiss(10)
  if not F.route({ { 5, 7 }, { 8, 7 } }, tag) then return false end
  return talk("Up", tag)
end

local function partyCount() return F.r8(S.gPartiesCount) end
local function partySpecies(i)
  local a = S.gParties + i * S.Pokemon.size
  local pers, otid = F.r32(a), F.r32(a + 4)
  local slot = F.r8(S.sSubstructOffsets + pers % 24) * 3
  return (F.r32(a + 32 + slot * 4) ~ pers ~ otid) & 0x7FF
end

F.run(function()
  assert(F.boot(100), "Fresh game did not boot")
  instantText()
  flag(FLAG_SYS_POKEMON_GET, true)
  F.dbg(); F.sel(2); F.sel(9); F.idle(60); F.bOut(4)
  F.check("debug party set", partyCount() == 1, "party=" .. partyCount())

  F.check("kiln helper starts the quest", talkToKilnHelper("kiln_start") and flag(FIRE_STARTED) and not flag(FIRE_WATER))

  assert(warp(AZALEA_G, AZALEA_M, AZALEA_PC_WARP, "azalea"), "Azalea warp failed")
  F.dismiss(10)
  F.check("walked east toward Slowpoke Well", F.route({ { 31, 16 }, { 48, 16 } }, "well_approach"))
  local hx, hy, facing = helper()
  F.check("well helper is on the map", hx ~= nil)
  if hx then
    local d = DIRS[facing] or DIRS[1]
    local tx, ty = hx + d[1], hy + d[2]
    F.L(string.format("  well helper at (%d,%d) facing %d; front tile (%d,%d)", hx, hy, facing, tx, ty))
    F.check("walked to the tile the well helper faces", F.route({ { tx, 16 }, { tx, ty } }, "well_front"),
      string.format("pos=(%d,%d)", F.pos()))
    F.check("pressing A in front of the well helper starts her script", talk(d[3], "well_front_talk"))
    F.check("the well helper sends the water", flag(FIRE_WATER))
  end

  local before = partyCount()
  talkToKilnHelper("kiln_reward")
  F.check("kiln helper unlocks and gives Firefighter Squirtle", flag(FIRE_UNLOCKED) and flag(FIRE_COLLECTED)
    and partyCount() == before + 1 and partySpecies(before) == SPECIES_SQUIRTLE_FIREFIGHTER,
    string.format("party %d -> %d", before, partyCount()))
  F.shot("completed")
  F.finish()
end)
