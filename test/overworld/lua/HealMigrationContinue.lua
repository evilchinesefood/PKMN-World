-- Heal-location migration through a real save and Continue.
--
-- 6fb180ccbd moved the Azalea, Goldenrod and Safari Zone Gate heal points one tile south, off the
-- Center door and onto the apron. lastHealLocation stores the coordinate, so a save that healed
-- there before the move still holds the door tile, and GetHealLocationIndexByWarpData no longer
-- matches it: a whiteout skips the Center and drops the player outside on the door.
-- MigrateMovedHealLocations (src/load_save.c) re-points the old pair on load.
--
-- Each case writes the old door coordinate and an older save version, saves from the Start menu,
-- soft resets and continues, so the migration runs on the real load path. Then it whites out from
-- a debug battle and requires the Center's nurse cutscene, the landing inside that Center, and
-- control. Versions 9 to 11 predate the format stamp on which the deep-review migration rides;
-- version 12 is a save that a Nov 11 to Nov 15 build loaded and saved again before the migration
-- existed.
--
-- PW_HEAL_ONLY=<text> (runner --env) runs matching cases, e.g. "azalea" or "v12".
--
-- Run via test/overworld/mgba-run.sh test/overworld/lua/HealMigrationContinue.lua <rom>

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "HealMigrationContinue")

local HUB_GROUP = 100
local USM_ICO_SAVE = 7
local SENTINEL = 0xFFFF
local CONTEXT_RUNNING = 0
local WARP_ID_NONE = 255
local B_OUTCOME_LOST = 2
local CURRENT_VERSION = S.SAVE_FORMAT_VERSION   -- generated from include/constants/global.h
local PKMN_SIZE, OFF_HP, OFF_MAXHP = S.Pokemon.size, S.Pokemon.hp, S.Pokemon.maxHP
local BP_STRIDE, BP_HP = S.BattlePokemon.size, S.BattlePokemon.hp
local ROW_PARTY_MENU, ROW_SET, ROW_BATTLE = 2, 9, 10
local ONLY = os.getenv("PW_HEAL_ONLY")

-- Doors and aprons from data/maps/*/map.json and src/data/heal_locations.json; the Center
-- interiors are the respawn maps.
local CENTERS = {
  { tag = "azalea",    healG = 80, healM = 0, door = { 31, 15 }, apron = { 31, 16 }, pcG = 81, pcM = 4 },
  { tag = "goldenrod", healG = 83, healM = 0, door = { 28, 36 }, apron = { 28, 37 }, pcG = 84, pcM = 17 },
  { tag = "safari",    healG = 96, healM = 0, door = { 11, 15 }, apron = { 11, 16 }, pcG = 96, pcM = 1 },
}
local VERSIONS = { 9, 10, 11, 12 }

local function d(n) return (n // 100) % 10, (n // 10) % 10, n % 10 end
local function warp(g, m, w, tag)
  local gh, gt, go = d(g)
  local mh, mt, mo = d(m)
  local wh, wt, wo = d(w)
  return F.warpTo(gh, gt, go, mh, mt, mo, wh, wt, wo, g, m, tag)
end

local function heal()
  local b = F.sb1() + S.SaveBlock1.lastHealLocation
  return { g = F.r8(b), m = F.r8(b + 1), w = F.r8(b + 2), x = F.rs16(b + 4), y = F.rs16(b + 6) }
end
local function fmtHeal(h) return string.format("%d/%d warp=%d (%d,%d)", h.g, h.m, h.w, h.x, h.y) end
local function writeHeal(g, m, x, y)
  local b = F.sb1() + S.SaveBlock1.lastHealLocation
  F.w8(b, g); F.w8(b + 1, m); F.w8(b + 2, WARP_ID_NONE); F.w16(b + 4, x); F.w16(b + 6, y)
end
local function saveVersion() return F.r8(F.sb2() + S.SaveBlock2.saveVersion) end
local function where()
  local x, y = F.pos()
  return string.format("%d/%d (%d,%d)", F.grp(), F.mapn(), x, y)
end

local function hasControl()
  return F.ow() and F.r8(S.sLockFieldControls) == 0
    and F.r8(S.sGlobalScriptContextStatus) ~= CONTEXT_RUNNING
end
local function awaitControl(budget)
  for i = 1, budget or 600 do
    if hasControl() then return true end
    if i % 30 == 0 then F.press("B", 2) else F.idle(1) end
  end
  return hasControl()
end

local function driveSave()
  F.w16(S.gSaveAttemptStatus, SENTINEL)
  F.press("Start", 2); F.idle(60)
  if not F.selectStartIcon(USM_ICO_SAVE) then return "noicon" end
  for i = 1, 3000 do
    if F.r16(S.gSaveAttemptStatus) ~= SENTINEL then
      F.idle(30)
      for _ = 1, 6 do F.press("B", 2); F.idle(20) end
      return F.r16(S.gSaveAttemptStatus) == 1 and "done" or "failed"
    end
    if i % 20 == 1 then joypad.set({ A = true }) else joypad.set({}) end
    emu.frameadvance()
  end
  return "timeout"
end

local function softReset()
  for _ = 1, 8 do joypad.set({ A = true, B = true, Start = true, Select = true }); emu.frameadvance() end
  joypad.set({})
end

local function tapDown(n) for _ = 1, n do F.press("Down", 3); F.idle(16) end end
local function closeDbg() for _ = 1, 16 do F.press("B", 3); F.idle(20) end end

local function setParty()
  F.dbg(); F.idle(60)
  tapDown(ROW_PARTY_MENU); F.press("A", 3); F.idle(60)
  tapDown(ROW_SET); F.press("A", 3); F.idle(180)
  closeDbg()
  return F.r8(S.gPartiesCount)
end

local function zeroHp()
  for i = 0, 5 do
    local b = S.gParties + i * PKMN_SIZE
    if F.r16(b + OFF_MAXHP) ~= 0 then F.w16(b + OFF_HP, 0) end
  end
  local n = F.battlers()
  if n > 4 then n = 4 end
  for i = 0, n - 1 do F.w16(S.gBattleMons + i * BP_STRIDE + BP_HP, 0) end
end

-- Loses a debug battle and follows the whiteout to the field. Returns whether the nurse's
-- cutscene ran (a script held the field after the landing) and whether control came back.
local function whiteOut(tag)
  F.dbg(); F.idle(60)
  tapDown(ROW_PARTY_MENU); F.press("A", 3); F.idle(60)
  tapDown(ROW_BATTLE); F.press("A", 3); F.idle(30)
  local left = false
  for _ = 1, 800 do
    F.idle(8)
    if not F.ow() then left = true; break end
  end
  if not left then return false, false, "the debug battle never started" end
  for _ = 1, 400 do if F.battlers() > 0 then break end; F.idle(4) end
  local back = false
  for t = 1, 4000 do
    F.w8(S.gBattleOutcome, B_OUTCOME_LOST)
    zeroHp()
    F.press("A", t % 3 == 0 and 2 or 1); F.idle(1)
    if t % 60 == 0 and F.reportCrash(tag) then return false, false, "crash" end
    if F.ow() then back = true; break end
  end
  if not back then return false, false, "the whiteout never reached the field" end
  local landing = where()
  local scripted = false
  for _ = 1, 120 do
    if F.r8(S.sGlobalScriptContextStatus) == CONTEXT_RUNNING or F.r8(S.sLockFieldControls) ~= 0 then
      scripted = true; break
    end
    F.idle(1)
  end
  F.shot(tag .. "_landed")
  local control = awaitControl(1500)
  return scripted, control, landing
end

local function case(tag, body)
  if ONLY and not tag:find(ONLY, 1, true) then return end
  F.L("== " .. tag .. " ==")
  local ok, err = pcall(body)
  if not ok then F.check(tag .. ": ran without a Lua error", false, tostring(err)) end
end

local function seedAndContinue(tag, c, version)
  writeHeal(c.healG, c.healM, c.door[1], c.door[2])
  F.w8(F.sb2() + S.SaveBlock2.saveVersion, version)
  F.L(string.format("  seeded v%d heal %s at %s", version, fmtHeal(heal()), where()))
  if not F.check(tag .. ": saved with the old door coordinate", driveSave() == "done") then return false end
  softReset(); F.idle(60)
  if not F.check(tag .. ": continued to the field", F.boot(nil, true)) then return false end
  F.check(tag .. ": control after Continue", awaitControl(900), where())
  local h = heal()
  F.L(string.format("  after Continue v%d heal %s", saveVersion(), fmtHeal(h)))
  F.check(tag .. ": the save is stamped current", saveVersion() == CURRENT_VERSION, "v" .. saveVersion())
  F.check(tag .. ": the whiteout point moved to the apron",
    h.g == c.healG and h.m == c.healM and h.x == c.apron[1] and h.y == c.apron[2], fmtHeal(h))
  return true
end

F.run(function()
  if not F.boot(HUB_GROUP) then F.check("boot to the hub", false); F.finish(); return end
  F.check("Set Party gave a party", setParty() > 0)

  for _, c in ipairs(CENTERS) do
    for _, v in ipairs(VERSIONS) do
      local tag = string.format("%s v%d", c.tag, v)
      case(tag, function()
        if not seedAndContinue(tag, c, v) then return end
        local scripted, control, landing = whiteOut(c.tag .. "_v" .. v)
        local x, y = F.pos()
        F.L(string.format("  whiteout landed %s, now %s", tostring(landing), where()))
        F.check(tag .. ": whiteout lands inside the Center",
          F.grp() == c.pcG and F.mapn() == c.pcM, "landed " .. tostring(landing) .. " now " .. where())
        F.check(tag .. ": the nurse's cutscene ran", scripted, tostring(landing))
        F.check(tag .. ": whiteout does not land on the Center door",
          not (F.grp() == c.healG and F.mapn() == c.healM and x == c.door[1] and y == c.door[2]), where())
        F.check(tag .. ": control after the whiteout", control, where())
        F.check(tag .. ": the player can walk after the whiteout", F.step("Down") or F.step("Left"), where())
      end)
    end
  end

  F.finish()
end)
