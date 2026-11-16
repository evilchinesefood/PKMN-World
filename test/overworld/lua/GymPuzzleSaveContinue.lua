-- Save and soft reset in the middle of Johto and Kanto gym puzzles, then Continue: position and puzzle
-- state must come back coherent and the puzzle must carry on. Continue runs the map's ON_LOAD script
-- but not ON_TRANSITION, so puzzles that rebuild from a var or flag at load, or keep state in saved
-- temp vars, are the ones at risk.
--
-- Blackthorn: the first coord trigger builds bridge 1 (VAR_BLACKTHORN_GYM_STATE 1), save, Continue,
-- walk it and fire trigger 2, save, Continue, walk bridge 2. Vermilion: the first switch's trash can
-- (VAR_TEMP_0, set by the map) half-opens the beam, save, Continue, the second can (VAR_TEMP_1)
-- must open both beams. Cinnabar: quiz 1 answered Yes opens its door. Saffron: a warp tile, then save.
-- Ecruteak: standing on the invisible floor. Goldenrod, Azalea, Olivine, Cianwood: a few steps in.
-- Every save is a real Start-menu save and a soft reset; the state compared is the map, tile and the
-- puzzle's metatiles or vars. Unrelated trainer battles on the way are won by setting the foe's HP
-- to 1 (the player's Lv. 10 Charmander obeys without badges).
--
-- Run via test/overworld/mgba-run.sh test/overworld/lua/GymPuzzleSaveContinue.lua <rom>
local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "GymPuzzleSaveContinue")
local MON = S.Pokemon.size
local USM_ICO_SAVE = 7
local ONLY = os.getenv("PW_GYM")
local BEAM_OFF = 0x281
local BRIDGE = 0x35A

local function digits(n) return n // 100, (n // 10) % 10, n % 10 end
local function sdigits(n) n = n - 1; return n // 100, (n // 10) % 10, n % 10 end
local function metatile(x, y)
  local w = F.r32(S.gBackupMapLayout); local map = F.r32(S.gBackupMapLayout + 8)
  return F.r16(map + ((x + 7) + (y + 7) * w) * 2) & 0x3FF
end
local function tempVar(i) return F.r16(F.sb1() + S.SaveBlock1.vars + i * 2) end
local function flag(fl) return (F.r8(F.sb1() + S.SaveBlock1.flags + (fl >> 3)) >> (fl & 7)) & 1 end
local function scriptDone() return F.ow() and F.r8(S.sGlobalScriptContextStatus) == 2 end
local function where() local x, y = F.pos(); return string.format("%d/%d (%d,%d)", F.grp(), F.mapn(), x, y) end
local function settle(n)
  local calm = 0
  for i = 1, n or 3000 do
    if scriptDone() then calm = calm + 1 else calm = 0 end
    if calm >= 6 then return true end
    if F.reportCrash("settle") then return false end
    if F.cb2() == (S.BattleMainCB2 & ~1) then
      for b = 1, 3, 2 do
        local a = S.gBattleMons + b * S.BattlePokemon.size
        if F.r16(a + S.BattlePokemon.hp) > 1 then F.w16(a + S.BattlePokemon.hp, 1) end
      end
      if F.r16(S.gBattleMons + S.BattlePokemon.hp) > 0 then
        F.w16(S.gBattleMons + S.BattlePokemon.maxHP, 999); F.w16(S.gBattleMons + S.BattlePokemon.hp, 999)
      end
    end
    if F.cb2() == (S.BattleMainCB2 & ~1) and (F.r32(S.gBattlerControllerFuncs) & ~1) == (S.HandleInputChooseMove & ~1) then
      F.press("Up", 2); F.idle(4); F.press("Left", 2); F.idle(4)
    end
    if calm == 0 then F.press("A", 2) end
    F.idle(10)
  end
  return scriptDone()
end

local function driveSave()
  F.w16(S.gSaveAttemptStatus, 0xFFFF)
  F.press("Start", 2); F.idle(60)
  if not F.selectStartIcon(USM_ICO_SAVE) then return "noicon" end
  for i = 1, 3000 do
    if F.r16(S.gSaveAttemptStatus) ~= 0xFFFF then
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
  joypad.set({}); F.idle(60)
end

local function saveContinue(tag, snap)
  local before = snap()
  F.shot(tag .. "_before_save")
  local r = driveSave()
  F.check(tag .. ": saved", r == "done", r)
  softReset()
  F.check(tag .. ": continued", F.boot(nil, true))
  F.idle(30)
  local after = snap()
  F.shot(tag .. "_after_continue")
  F.check(tag .. ": state after Continue matches", before == after, "before " .. before .. " | after " .. after)
end

local function warp(g, m, tag)
  local a, b, c = digits(g); local d, e, f = digits(m)
  return F.check(tag .. ": warp", F.warpTo(a, b, c, d, e, f, 0, 0, 0, g, m, tag))
end

local CASES = {}
CASES.blackthorn = function()
  if not warp(94, 0, "blackthorn") then return end
  F.route({ { 20, 56 } }, "bt"); F.step("Up"); settle()
  local snap = function() return where() .. string.format(" bridge1=%03X bridge2=%03X", metatile(20, 50), metatile(17, 37)) end
  F.check("blackthorn: trigger 1 built bridge 1", metatile(20, 50) == BRIDGE, snap())
  saveContinue("blackthorn1", snap)
  F.route({ { 20, 46 }, { 19, 46 }, { 19, 42 } }, "bt2"); settle()
  F.check("blackthorn: walk the rebuilt bridge", F.route({ { 19, 42 } }, "bt2b"), where())
  F.step("Up"); settle()
  F.check("blackthorn: trigger 2 built bridge 2", metatile(17, 37) == BRIDGE, snap())
  saveContinue("blackthorn2", snap)
  F.check("blackthorn: walk bridge 2", F.route({ { 17, 41 }, { 17, 35 } }, "bt3"), where())
  F.shot("blackthorn_bridge2_walked")
end
-- Trash cans sit on odd columns of rows 10, 12 and 14; even columns and odd rows are floor. A
-- trainer who walks up to battle can end on the approach column, so re-plan around live objects.
local function occupied(x, y)
  for i = 1, 15 do
    local b = S.gObjectEvents + i * S.ObjectEvent.stride
    if (F.r8(b) & 1) == 1 and F.rs16(b + S.ObjectEvent.x) - 7 == x and F.rs16(b + S.ObjectEvent.y) - 7 == y
      and F.r8(b + S.ObjectEvent.localId) ~= 254 then return true end
  end
  return false
end
local function reachCan(k, tag)
  local x, y = 1 + 2 * ((k - 1) % 5), 10 + 2 * ((k - 1) // 5)
  local spots = { { x, y + 1, "Up" }, { x - 1, y, "Right" }, { x + 1, y, "Left" }, { x, y - 1, "Down" } }
  for _ = 1, 4 do
    for _, t in ipairs(spots) do
      local px, py = F.pos()
      if px == t[1] and py == t[2] then F.face(t[3]); return true end
    end
    local planned = false
    for _, t in ipairs(spots) do
      local px, py = F.pos()
      if not planned and py == t[2] and py % 2 == 1 and not occupied(t[1], t[2]) then
        local clear = true
        for cx = math.min(px, t[1]), math.max(px, t[1]) do if cx ~= px and occupied(cx, py) then clear = false end end
        if clear then F.route({ { t[1], t[2] } }, tag); planned = true end
      end
      if not planned and t[1] >= 0 and t[1] <= 10 and not occupied(t[1], t[2]) then
        for _, c in ipairs({ t[1], x + 1, x - 1 }) do
          local clear = c >= 0 and c <= 10 and c % 2 == 0
          for r = math.min(t[2], 16), 16 do if clear and occupied(c, r) then clear = false end end
          if clear and not planned then
            local px, py = F.pos()
            local pts = {}
            if px % 2 == 1 then
              local side = (px + 1 <= 10 and not occupied(px + 1, py)) and px + 1 or px - 1
              pts[#pts + 1] = { side, py }
            end
            pts[#pts + 1] = { pts[1] and pts[1][1] or px, 16 }
            pts[#pts + 1] = { c, 16 }; pts[#pts + 1] = { c, t[2] }; pts[#pts + 1] = { t[1], t[2] }
            F.route(pts, tag)
            planned = true
          end
        end
      end
    end
    settle()
  end
  for _, t in ipairs(spots) do
    local px, py = F.pos()
    if px == t[1] and py == t[2] then F.face(t[3]); return true end
  end
  return false
end
CASES.vermilion = function()
  if not warp(43, 6, "vermilion") then return end
  F.route({ { 6, 19 }, { 6, 16 } }, "v0")
  F.L(string.format("vermilion switches %d %d", tempVar(0), tempVar(1)))
  if not F.check("vermilion: reached the first switch's can", reachCan(tempVar(0), "v1"), where()) then return end
  F.press("A", 2); settle()
  local snap = function() return where() .. string.format(" t0=%d t1=%d found1=%d beam=%03X", tempVar(0), tempVar(1), flag(1), metatile(5, 6)) end
  F.check("vermilion: the first lock opened", flag(1) == 1, snap())
  saveContinue("vermilion", snap)
  if not F.check("vermilion: reached the second switch's can", reachCan(tempVar(1), "v2"), where()) then return end
  F.press("A", 2); settle()
  F.shot("vermilion_after_can2")
  F.check("vermilion: after Continue the second can opens both beams", metatile(5, 6) == BEAM_OFF, snap())
end
CASES.cinnabar = function()
  if not warp(46, 0, "cinnabar") then return end
  local door0 = metatile(26, 9)
  F.check("cinnabar: reach quiz 1", F.route({ { 26, 22 }, { 26, 13 }, { 23, 13 }, { 23, 11 } }, "c1"), where())
  settle(); F.route({ { 23, 11 } }, "c1b")
  F.face("Up"); F.press("A", 2)
  for _ = 1, 200 do
    if F.r8(S.sMenu + S.Menu.maxCursorPos) == 1 and not scriptDone() then end
    F.press("A", 2); F.idle(15)
    if scriptDone() then break end
  end
  local snap = function() return where() .. string.format(" door=%03X", metatile(26, 9)) end
  F.check("cinnabar: quiz 1 opened its door", metatile(26, 9) ~= door0, snap())
  saveContinue("cinnabar", snap)
end
CASES.saffron = function()
  if not warp(48, 3, "saffron") then return end
  F.route({ { 17, 21 }, { 18, 21 } }, "s1"); F.step("Up"); F.idle(120)
  local snap = function() return where() end
  F.check("saffron: the warp tile moved the player out of the entrance room", F.pos() ~= 18, snap())
  saveContinue("saffron", snap)
end
CASES.ecruteak = function()
  if not warp(86, 0, "ecruteak") then return end
  F.route({ { 10, 44 } }, "e1"); F.step("Up"); F.step("Up"); F.idle(60)
  local snap = function() return where() end
  F.check("ecruteak: standing on the invisible floor", snap() == "86/0 (10,42)", snap())
  saveContinue("ecruteak", snap)
end
CASES.goldenrod = function()
  if not warp(84, 13, "goldenrod") then return end
  for _ = 1, 4 do F.step("Up") end
  settle()
  local snap = function() return where() end
  saveContinue("goldenrod", snap)
end
CASES.azalea = function()
  if not warp(81, 0, "azalea") then return end
  for _ = 1, 3 do F.step("Up") end
  settle()
  local snap = function() return where() end
  saveContinue("azalea", snap)
end
CASES.olivine = function()
  if not warp(88, 1, "olivine") then return end
  for _ = 1, 3 do F.step("Up") end
  settle()
  saveContinue("olivine", where)
end
CASES.cianwood = function()
  if not warp(90, 0, "cianwood") then return end
  for _ = 1, 3 do F.step("Up") end
  settle()
  saveContinue("cianwood", where)
end

F.run(function()
  if not F.boot(100) then F.check("boot", false); F.finish(); return end
  F.w16(F.sb2() + S.SaveBlock2.optionsU16, (F.r16(F.sb2() + S.SaveBlock2.optionsU16) & ~7) | 3)
  for off = 0, 6 * MON - 4, 4 do F.w32(S.gParties + off, 0) end
  F.w8(S.gPartiesCount, 0)
  F.dbg(); F.idle(30); F.bOut(4)
  F.dbg(); F.sel(3); F.sel(1); F.idle(20); F.spin(sdigits(4)); F.idle(20); F.spin(0, 1, 0); F.idle(60); F.bOut(4)
  F.check("one Pokemon", F.r8(S.gPartiesCount) == 1)
  local base = F.out .. "GymPuzzleSaveContinue_base.ss"
  client.savestate(base)
  for _, name in ipairs({ "blackthorn", "vermilion", "cinnabar", "saffron", "ecruteak", "goldenrod", "azalea", "olivine", "cianwood" }) do
    if not ONLY or name:find(ONLY, 1, true) then
      client.loadstate(base); F.idle(10)
      F.L("== " .. name)
      local ok, err = pcall(CASES[name])
      if not ok then F.check(name .. ": no Lua error", false, tostring(err)) end
    end
  end
  F.check("no crash", not F.crashScreen())
  F.finish()
end)
