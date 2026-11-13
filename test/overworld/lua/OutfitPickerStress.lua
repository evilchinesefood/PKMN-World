-- Stress the World Transit wardrobe with a follower out: per-frame input spam, rapid open and
-- close cycles, then a warp and a save with Continue. The production picker runs on top of the
-- live hub field, so each cycle must hand back exactly the tasks and sprites it took.
--
-- Run via: test/overworld/mgba-run.sh test/overworld/lua/OutfitPickerStress.lua <rom.gba>

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "OutfitPickerStress")

local VAR_PLAYER_PALETTE = 0x40FC
local WARDROBE_FRONT = { 7, 8 }
local FOLLOWER = 0xFE

local function outfit() return F.r16(F.sb1() + S.SaveBlock1.vars + (VAR_PLAYER_PALETTE - 0x4000) * 2) end
local function active() return F.r8(S.gPlayerOutfitPicker + 2) ~= 0 end
local function preview() return F.r16(S.gPlayerOutfitPicker) end
local function partyCount() return F.r8(S.gPartiesCount) end

local function activeTasks()
  local n = 0
  for i = 0, S.Task.count - 1 do
    if F.r8(S.gTasks + i * S.Task.stride + S.Task.isActive) ~= 0 then n = n + 1 end
  end
  return n
end

local function activeSprites()
  local n = 0
  for i = 0, S.Sprite.count - 1 do
    if (F.r8(S.gSprites + i * S.Sprite.stride + S.Sprite.inUse) & 1) ~= 0 then n = n + 1 end
  end
  return n
end

local function follower()
  for i = 0, 15 do
    local b = S.gObjectEvents + i * S.ObjectEvent.stride
    if (F.r8(b) & 1) == 1 and F.r8(b + S.ObjectEvent.localId) == FOLLOWER then return true end
  end
  return false
end

local function scriptIdle() return F.ow() and F.r8(S.sGlobalScriptContextStatus) == 2 end

local function open(tag)
  F.face("Up"); F.idle(12)
  for _ = 1, 40 do
    if active() then F.idle(10); return true end
    if F.reportCrash("open_" .. tag) then return false end
    F.press("A", 2); F.idle(20)
  end
  F.shot(tag .. "_noopen")
  return false
end

local function closed(tag)
  for _ = 1, 300 do
    if not active() and scriptIdle() then F.idle(30); return true end
    if F.reportCrash("close_" .. tag) then return false end
    F.idle(4)
  end
  F.shot(tag .. "_stuck")
  return false
end

local function tapDown(n) for _ = 1, n do F.press("Down", 3); F.idle(16) end end

local function save()
  F.w16(S.gSaveAttemptStatus, 0xFFFF)
  F.press("Start", 2); F.idle(60)
  assert(F.selectStartIcon(7), "Save action unavailable")
  F.press("A", 2); F.idle(90)
  for _ = 1, 12 do
    F.press("A", 2); F.idle(45)
    if F.r16(S.gSaveAttemptStatus) == 1 then break end
  end
  F.idle(120)
  for _ = 1, 20 do
    if scriptIdle() and F.ensureFree() then break end
    F.press("B", 2); F.idle(30)
  end
  return F.r16(S.gSaveAttemptStatus) == 1
end

F.run(function()
  assert(F.boot(100), "Fresh game did not boot")
  F.dbg(); F.idle(60); tapDown(2); F.press("A", 3); F.idle(60); tapDown(9); F.press("A", 3); F.idle(180)
  for _ = 1, 10 do if F.ensureFree() then break end F.press("B", 3); F.idle(30) end
  F.check("debug party gives a follower", partyCount() >= 1, "party=" .. partyCount())
  assert(F.route({ { 9, 4 }, { 9, 6 }, { 8, 6 }, { 8, 8 }, WARDROBE_FRONT }, "wardrobe"), "Could not reach the wardrobe")
  F.idle(60)
  F.check("follower is out beside the wardrobe", follower())

  local tasks0, sprites0 = activeTasks(), activeSprites()
  F.check("wardrobe opens with a follower out", open("spam"))
  F.shot("picker_open")
  local keys = { "Left", "Down", "Right", "Up", "Down", "Down", "Left", "Up", "Right", "Right", "Down" }
  local seed = 7
  for i = 1, 600 do
    seed = (seed * 1103515245 + 12345) % 2147483648
    if i % 2 == 0 then joypad.set({ [keys[seed % #keys + 1]] = true }) else joypad.set({}) end
    emu.frameadvance()
    if i % 150 == 0 and F.reportCrash("spam_" .. i) then break end
  end
  F.idle(30)
  local chosen = preview()
  F.check("spam never commits a preview", outfit() == 0 and active(), string.format("saved=%d preview=%d", outfit(), chosen))
  F.check("spam keeps the selection in range", chosen < 24, "preview=" .. chosen)
  F.shot("picker_after_spam")
  F.press("A", 2)
  F.check("apply after spam returns control", closed("spam_apply"))
  F.check("apply stores the spammed preview", outfit() == chosen, string.format("saved=%d want=%d", outfit(), chosen))
  F.shot("applied_" .. chosen)

  local cycles = 0
  for round = 1, 12 do
    if not open("cycle" .. round) then break end
    F.press(round % 3 == 0 and "A" or "B", 1)
    if not closed("cycle" .. round) then break end
    cycles = cycles + 1
  end
  F.check("twelve rapid open and close cycles complete", cycles == 12, "cycles=" .. cycles)
  F.check("cycles keep the saved outfit", outfit() == chosen, "saved=" .. outfit())
  F.check("cycles return every task", activeTasks() == tasks0, string.format("tasks %d -> %d", tasks0, activeTasks()))
  F.check("cycles return every sprite", activeSprites() == sprites0, string.format("sprites %d -> %d", sprites0, activeSprites()))
  F.check("follower survives the cycles", follower())

  F.check("wardrobe reopens on the saved outfit", open("final") and preview() == chosen, "preview=" .. preview())
  F.press("Right", 2); F.idle(20); F.press("Down", 2); F.idle(20)
  local final = preview()
  F.press("A", 2)
  F.check("final apply returns control", closed("final"))
  F.check("final apply stores the new outfit", outfit() == final and final ~= chosen,
    string.format("saved=%d want=%d", outfit(), final))
  F.shot("hub_final_" .. final)

  assert(F.warpTo(0, 3, 7, 0, 0, 0, 0, 0, 0, 37, 0, "pallet"), "Pallet warp failed")
  F.dismiss(20)
  F.idle(120); F.step("Down"); F.step("Down"); F.idle(60)
  F.check("outfit survives a warp", outfit() == final)
  F.shot("pallet_" .. final)
  F.check("save completes", save())
  client.reboot_core()
  assert(F.boot(37, true), "Continue did not reach Pallet")
  F.idle(120)
  F.check("outfit survives Continue", outfit() == final, "saved=" .. outfit())
  F.shot("continue_" .. final)
  F.finish()
end)
