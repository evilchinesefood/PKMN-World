-- Soft reset (A+B+Start+Select) at every stage of the front end, after #636 deleted the FRLG title,
-- the expansion intro and the quickstart. Without a save: during the copyright screen, the intro, the
-- World title, the main menu, the new-game speech, the gender choice and the naming screen. Each
-- reset must come back to the front end with no crash screen, and a reset before the first save must
-- leave no save behind (the next main menu still opens on NEW GAME). Then a new game is played to the
-- hub, saved from the Start menu, and the reset is pressed again on the World title, the main menu,
-- between CONTINUE and the field, and in the field; every Continue must land on the saved tile with
-- the saved party and give control back. A seeded single-button mash runs through the intro and the
-- title before each stage so stray input on those screens is covered too.
--
-- Run via test/overworld/mgba-run.sh test/overworld/lua/FrontEndSoftReset.lua <rom>

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "FrontEndSoftReset")

local HUB_GROUP = 100
local USM_ICO_SAVE = 7
local SENTINEL = 0xFFFF
local CONTEXT_RUNNING = 0

local rngState = 7
local function rnd(n)
  rngState = (rngState * 1103515245 + 12345) & 0x7FFFFFFF
  return rngState % n
end

local cb2 = F.cb2
local function isFrontEnd(c)
  return c == S.CB2_InitCopyrightScreenAfterBootup or c == S.MainCB2_Intro
    or c == S.MainCB2_WorldTitleScreen or c == S.CB2_InitTitleScreen
end
local function waitFor(pred, budget)
  for i = 1, budget do
    if pred(cb2()) then return true, i end
    joypad.set({}); emu.frameadvance()
    if i % 600 == 0 and F.noteCrash("wait" .. i) then return false, i end
  end
  return pred(cb2()), budget
end
local function is(target) return function(c) return c == target end end

local function softReset()
  for _ = 1, 10 do joypad.set({ A = true, B = true, Start = true, Select = true }); emu.frameadvance() end
  joypad.set({})
end

-- A single-button mash on the intro and title. It never presses A or Start, so it cannot leave the
-- title; Select skips the intro, the other presses are stray input on both screens.
local function mash(frames)
  local quiet = { "B", "Select", "L", "R", "Up", "Down", "Left", "Right" }
  local f = 0
  while f < frames do
    local hold = 1 + rnd(4)
    local b = quiet[rnd(#quiet) + 1]
    for _ = 1, hold do joypad.set({ [b] = true }); emu.frameadvance() end
    f = f + hold
  end
  joypad.set({})
end

local function toTitle()
  local ok = waitFor(function(c) return c == S.MainCB2_Intro or c == S.MainCB2_WorldTitleScreen end, 3000)
  if not ok then return false end
  mash(240)
  for _ = 1, 40 do
    if cb2() == S.MainCB2_WorldTitleScreen then break end
    F.press("Start", 2); F.idle(30)
  end
  F.idle(120)
  return cb2() == S.MainCB2_WorldTitleScreen
end
local function toMainMenu()
  if not toTitle() then return false end
  F.press("Start", 2)
  local ok = waitFor(is(S.CB2_MainMenu), 600)
  F.idle(90)
  return ok
end

-- After a reset the game must restart from the copyright screen and reach the title. stayInIntro
-- leaves it in the intro instead, so the next stage can reset there.
local function checkReset(tag, stayInIntro)
  softReset()
  local back = waitFor(isFrontEnd, 1200)
  F.check(tag .. ": soft reset returns to the front end", back, string.format("cb2=%08X", cb2()))
  if stayInIntro then
    if F.reportCrash(tag) then F.check(tag .. ": no crash screen", false) end
    return back
  end
  local title = back and toTitle()
  F.check(tag .. ": the World title comes back after the reset", title, string.format("cb2=%08X", cb2()))
  if F.reportCrash(tag) then F.check(tag .. ": no crash screen", false) end
  return title
end

-- With no save the main menu's first row is NEW GAME, so its task is the plain one.
local function mainMenuRows()
  return F.r8(S.gSaveFileStatus)
end

local function hasControl()
  return F.ow() and F.r8(S.sLockFieldControls) == 0 and F.r8(S.sGlobalScriptContextStatus) ~= CONTEXT_RUNNING
end
local function partyHash()
  local n = F.r8(S.gPartiesCount)
  local h = n
  for i = 0, n * S.Pokemon.size - 1, 4 do h = (h * 31 + F.r32(S.gParties + i)) & 0xFFFFFFFF end
  return h
end
local function snap()
  local x, y = F.pos()
  return { g = F.grp(), m = F.mapn(), x = x, y = y, p = partyHash() }
end
local function fmt(s) return string.format("%d/%d (%d,%d) party=%08X", s.g, s.m, s.x, s.y, s.p) end

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

local function continueFromTitle(tag, saved)
  if not toMainMenu() then F.check(tag .. ": main menu opens", false, string.format("cb2=%08X", cb2())); return false end
  F.press("A", 2)
  local ok = waitFor(function() return F.ow() end, 3000)
  F.check(tag .. ": Continue reaches the field", ok, string.format("cb2=%08X", cb2()))
  if not ok then return false end
  for i = 1, 900 do if hasControl() then break end; if i % 30 == 0 then F.press("B", 2) else F.idle(1) end end
  local now = snap()
  F.check(tag .. ": Continue lands on the saved tile with the saved party",
    now.g == saved.g and now.m == saved.m and now.x == saved.x and now.y == saved.y and now.p == saved.p,
    fmt(now) .. " vs " .. fmt(saved))
  F.check(tag .. ": control returns", hasControl())
  return true
end

F.run(function()
  client.speedmode(F.speed)
  F.idle(10)

  -- Without a save.
  local ok = waitFor(is(S.CB2_InitCopyrightScreenAfterBootup), 200)
  F.idle(20)
  F.shot("copyright")
  checkReset("copyright", true)

  ok = waitFor(is(S.MainCB2_Intro), 3000)
  F.check("the intro starts", ok, string.format("cb2=%08X", cb2()))
  -- No mash here: Select skips the intro, and this stage must reset inside it.
  F.idle(400)
  F.check("still in the intro when the reset is pressed", cb2() == S.MainCB2_Intro, string.format("cb2=%08X", cb2()))
  F.shot("intro")
  checkReset("intro")

  F.shot("title")
  checkReset("title")

  F.check("setup: main menu opens", toMainMenu())
  local status = mainMenuRows()
  F.shot("main_menu_new")
  checkReset("main menu (no save)")

  F.check("setup: main menu opens again", toMainMenu())
  F.press("A", 2) -- NEW GAME
  ok = waitFor(is(S.CB2_NewGameScene), 900)
  F.check("NEW GAME starts the new-game scene", ok, string.format("cb2=%08X", cb2()))
  F.idle(400)
  F.shot("new_game_speech")
  checkReset("new-game speech")

  -- Gender choice: press A through the speech until the gender task runs.
  F.check("setup: main menu opens for the gender case", toMainMenu())
  F.press("A", 2)
  local seenGender = false
  for i = 1, 6000 do
    if F.taskRunning and F.taskRunning(S.Task_OakSpeech_HandleGenderInput) then seenGender = true; break end
    local any = false
    for t = 0, S.Task.count - 1 do
      local a = S.gTasks + t * S.Task.stride
      if F.r8(a + S.Task.isActive) ~= 0 and (F.r32(a + S.Task.func) & ~1) == (S.Task_OakSpeech_HandleGenderInput & ~1) then any = true end
    end
    if any then seenGender = true; break end
    if i % 40 == 1 then joypad.set({ A = true }) else joypad.set({}) end
    emu.frameadvance()
  end
  F.check("the gender choice comes up", seenGender)
  F.shot("gender")
  checkReset("gender choice")

  -- Naming screen.
  F.check("setup: main menu opens for the naming case", toMainMenu())
  F.press("A", 2)
  local seenNaming = false
  for i = 1, 9000 do
    if cb2() == S.CB2_NamingScreen then seenNaming = true; break end
    if i % 40 == 1 then joypad.set({ A = true }) else joypad.set({}) end
    emu.frameadvance()
  end
  F.check("the naming screen comes up", seenNaming, string.format("cb2=%08X", cb2()))
  F.idle(60)
  F.shot("naming")
  checkReset("naming screen")

  F.check("setup: main menu opens after the naming reset", toMainMenu())
  F.check("a reset before the first save leaves no save", F.r8(S.gSaveFileStatus) == status,
    string.format("gSaveFileStatus=%d (was %d)", F.r8(S.gSaveFileStatus), status))
  softReset()

  -- Play a new game to the hub and save.
  if not F.boot(HUB_GROUP) then F.check("a new game reaches the hub", false); F.finish(); return end
  F.dbg(); F.idle(60)
  for _ = 1, 2 do F.press("Down", 3); F.idle(16) end; F.press("A", 3); F.idle(60)
  for _ = 1, 9 do F.press("Down", 3); F.idle(16) end; F.press("A", 3); F.idle(180)
  for _ = 1, 6 do F.press("B", 3); F.idle(20) end
  F.check("setup: Set Party published a party", F.r8(S.gPartiesCount) > 0)
  F.check("save in the hub", driveSave() == "done")
  local saved = snap()
  F.L("  saved " .. fmt(saved))

  checkReset("field (saved)")
  continueFromTitle("after a field reset", saved)

  checkReset("field again")
  F.check("setup: main menu with a save", toMainMenu())
  F.shot("main_menu_continue")
  checkReset("main menu (saved)")
  continueFromTitle("after a main-menu reset", saved)

  -- Reset between CONTINUE and the field, at several offsets.
  for _, delay in ipairs({ 1, 20, 45, 90, 150 }) do
    local tag = "continue +" .. delay
    checkReset(tag .. " setup")
    if toMainMenu() then
      F.press("A", 2)
      F.idle(delay)
      F.L(string.format("  %s: reset at cb2=%08X", tag, cb2()))
      checkReset(tag)
      continueFromTitle(tag, saved)
    else
      F.check(tag .. ": main menu opens", false)
    end
  end
  F.finish()
end)
