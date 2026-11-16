-- Rest in the Battle Pyramid from the graphical Start menu must end like the classic menu's: the
-- save pauses the challenge and puts the real party back while it writes, so the game must quit to
-- the title (SoftResetInBattlePyramid). Before 0829014ec0 the graphical menu's save handled the
-- success like a cancel and handed control back on the floor.
--
-- The suite gives six distinct Pokemon, takes the real Lv. 50 Pyramid challenge at the lobby
-- attendant with real input, waits for control on the first floor, then picks Rest on the Start
-- menu and answers Yes. The game must leave the field for the title without handing control back,
-- and Continue must resume on the Pyramid floor with the three chosen Pokemon.
--
-- Run via test/overworld/mgba-run.sh test/overworld/lua/PyramidRestUsm.lua <rom>

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "PyramidRestUsm")

local HUB_GROUP = 100
local FRONTIER = 26
local LOBBY, FLOOR = 25, 26
local USM_ICO_REST = 8
local SPECIES = { 1, 4, 7, 25, 152, 258 }

local CONTEXT_RUNNING = 0
-- The Pyramid floor is dark and walled, so a Left/Right step probe is unreliable; read the locks.
local function hasControl()
  return F.ow() and F.r8(S.sLockFieldControls) == 0 and F.r8(S.sGlobalScriptContextStatus) ~= CONTEXT_RUNNING
end
local function where() local x, y = F.pos(); return string.format("%d/%d (%d,%d)", F.grp(), F.mapn(), x, y) end

local function giveMon(species)
  local h, t, o = species // 100, (species // 10) % 10, species % 10
  F.dbg(); F.sel(3); F.sel(1); F.idle(20)
  F.spin(h, t, o); F.idle(20); F.spin(0, 3, 0); F.idle(60); F.bOut(4)
end

local function scriptMenuActive()
  for i = 0, S.Task.count - 1 do
    local a = S.gTasks + i * S.Task.stride
    local fn = F.r32(a + S.Task.func) & 0xFFFFFFFE
    if F.r8(a + S.Task.isActive) ~= 0
      and (fn == S.Task_HandleYesNoInput or fn == S.Task_HandleMultichoiceInput or fn == S.Task_CallYesOrNoCallback) then
      return true
    end
  end
  return false
end

local function menu(want, tag)
  for _ = 1, 80 do
    if scriptMenuActive() then
      F.idle(12)
      for _ = 1, 10 do
        local c = F.mcur()
        if c == want then
          F.shot(tag)
          F.press("A", 2); F.idle(40)
          return true
        end
        F.press(c > want and "Up" or "Down", 2); F.idle(12)
      end
      return false
    end
    F.press("A", 2); F.idle(25)
  end
  F.L("  menu " .. tag .. ": never opened")
  return false
end

local function inPartyMenu()
  local c = F.cb2()
  return c == (S.CB2_UpdatePartyMenu & ~1) or c == (S.CB2_InitPartyMenu & ~1)
end

local function choose(n)
  for _ = 1, 300 do
    if inPartyMenu() then break end
    F.press("A", 2); F.idle(20)
  end
  if not inPartyMenu() then return false end
  F.idle(60)
  for i = 1, n do
    F.press("A", 2); F.idle(30)
    F.press("A", 2); F.idle(40)
    if i < n then F.press("Down", 2); F.idle(20) end
  end
  F.press("Start", 2); F.idle(40)
  for _ = 1, 8 do
    if not inPartyMenu() then break end
    F.press("A", 2); F.idle(60)
  end
  return not inPartyMenu()
end

F.run(function()
  if not F.boot(HUB_GROUP) then F.check("boot to the hub", false); F.finish(); return end
  for _, sp in ipairs(SPECIES) do giveMon(sp) end
  F.check("six Pokemon in the party", F.r8(S.gPartiesCount) == 6, "n=" .. F.r8(S.gPartiesCount))

  if not F.warpTo(0, 2, 6, 0, 2, 5, 0, 0, 0, FRONTIER, LOBBY, "pyramid lobby") then
    F.check("warped to the Pyramid lobby", false); F.finish(); return
  end
  if not F.ensureFree() then F.dismiss(10) end
  local reached = F.route({ { 7, 14 }, { 7, 13 } }, "attendant")
  F.check("walked to the Pyramid attendant", reached, where())
  F.face("Up")
  F.press("A", 2); F.idle(40)
  local took = menu(0, "take_challenge") and menu(0, "level_50")
  F.check("took the Lv. 50 Pyramid challenge", took)
  local chose = took and choose(3)
  F.check("chose three Pokemon", chose)
  local saved = chose and menu(0, "save_before")
  F.check("agreed to save before the challenge", saved)

  local arrived = false
  for i = 1, 8000 do
    if F.grp() == FRONTIER and F.mapn() == FLOOR and i % 60 == 0 and hasControl() then
      F.idle(60)
      arrived = true
      break
    end
    if i % 40 == 1 then joypad.set({ A = true }) else joypad.set({}) end
    emu.frameadvance()
  end
  F.check("reached the first Pyramid floor in control", arrived, where())
  F.check("the challenge carries three Pokemon", F.r8(S.gPartiesCount) == 3, "n=" .. F.r8(S.gPartiesCount))
  if not arrived then F.finish(); return end

  local c0 = F.r32(S.gSaveCounter)
  F.press("Start", 2); F.idle(60)
  local offered = F.selectStartIcon(USM_ICO_REST)
  F.shot("rest_icon")
  F.check("the Pyramid Start menu offers Rest", offered)
  F.press("A", 2); F.idle(90)
  F.shot("rest_prompt")
  -- A through "Rest?" Yes and the save text, watching for the field coming back.
  local backInField, leftField = false, false
  for i = 1, 3000 do
    if i % 30 == 1 and i < 600 then joypad.set({ A = true }) else joypad.set({}) end
    emu.frameadvance()
    if not F.ow() then leftField = true end
    if i > 900 and hasControl() and F.r32(S.gSaveCounter) ~= c0 then backInField = true; break end
    if leftField and (F.cb2() == (S.MainCB2_WorldTitleScreen & ~1) or F.cb2() == (S.MainCB2_Intro & ~1)) then break end
  end
  F.shot("after_rest")
  F.L(string.format("  after Rest: cb2=%08X saves %d->%d party=%d at %s", F.cb2(), c0, F.r32(S.gSaveCounter),
    F.r8(S.gPartiesCount), where()))
  F.check("Rest quits to the title instead of handing control back", not backInField,
    string.format("cb2=%08X party=%d", F.cb2(), F.r8(S.gPartiesCount)))

  local booted = F.boot(nil, true)
  F.idle(240)
  for _ = 1, 20 do
    if hasControl() then break end
    F.press("A", 2); F.idle(40)
  end
  F.shot("after_continue")
  F.check("Rest wrote the save Continue loaded", F.r32(S.gSaveCounter) == c0 + 1,
    string.format("saves %d -> %d", c0, F.r32(S.gSaveCounter)))
  F.check("Continue resumes on the Pyramid floor", booted and F.grp() == FRONTIER and F.mapn() == FLOOR, where())
  F.check("the resumed challenge carries three Pokemon", F.r8(S.gPartiesCount) == 3, "n=" .. F.r8(S.gPartiesCount))
  F.check("no crash screen", not F.crashScreen())
  F.finish()
end)
