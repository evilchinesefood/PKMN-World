-- Mash every button at the World Transit wardrobe so presses land on its message, the picker's
-- first frame, Apply, Cancel and the field reload that follows. Whatever the mash commits must be
-- a valid outfit drawn on the player, the follower must stay out, and once input stops the field
-- must hold no leftover picker, task or sprite.
--
-- Run via: test/overworld/mgba-run.sh test/overworld/lua/OutfitTransitionMash.lua <rom.gba>

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "OutfitTransitionMash")

local VAR_PLAYER_PALETTE = 0x40FC
local WARDROBE_FRONT = { 7, 8 }
local FOLLOWER = 0xFE
local USM_SAVE = 7

local function outfit() return F.r16(F.sb1() + S.SaveBlock1.vars + (VAR_PLAYER_PALETTE - 0x4000) * 2) end
local function active() return F.r8(S.gPlayerOutfitPicker + 2) ~= 0 end
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

local function objectByLocalId(id)
  for i = 0, 15 do
    local b = S.gObjectEvents + i * S.ObjectEvent.stride
    if (F.r8(b) & 1) == 1 and F.r8(b + S.ObjectEvent.localId) == id then return b end
  end
  return nil
end

local function playerGraphics()
  local b = S.gObjectEvents + F.r8(S.gPlayerAvatar + 5) * S.ObjectEvent.stride
  return F.r16(b + S.ObjectEvent.graphicsId)
end

local function settle(tag)
  for _ = 1, 60 do
    if F.reportCrash(tag) then return false end
    if not active() and F.ow() and F.r8(S.sGlobalScriptContextStatus) == 2 and F.r32(S.sUsmMemory) == 0 then
      F.idle(30)
      if not active() and F.ow() and F.r8(S.sGlobalScriptContextStatus) == 2 and F.r32(S.sUsmMemory) == 0 then return true end
    end
    F.press("B", 2); F.idle(30)
  end
  F.shot(tag .. "_unsettled")
  return false
end

local seed = 41
local KEYS = { "A", "A", "A", "B", "B", "Up", "Down", "Left", "Right", "Start", "Select" }
local function mash(frames, tag)
  for i = 1, frames do
    seed = (seed * 1103515245 + 12345) % 2147483648
    if i % 2 == 0 then joypad.set({ [KEYS[seed % #KEYS + 1]] = true }) else joypad.set({}) end
    emu.frameadvance()
    if i % 200 == 0 then
      if F.reportCrash(tag .. "_" .. i) then return false end
      if F.ow() and F.r32(S.sUsmMemory) == 0 and not active() and F.r8(S.sGlobalScriptContextStatus) == 2 then
        local x, y = F.pos()
        if x ~= WARDROBE_FRONT[1] or y ~= WARDROBE_FRONT[2] then F.leg(WARDROBE_FRONT[1], WARDROBE_FRONT[2]) end
        F.face("Up")
      end
    end
  end
  return true
end

F.run(function()
  assert(F.boot(100), "Fresh game did not boot")
  F.dbg(); F.sel(2); F.sel(9); F.idle(180)
  for _ = 1, 10 do if F.ensureFree() then break end F.press("B", 3); F.idle(30) end
  F.check("debug party gives a follower", partyCount() >= 1, "party=" .. partyCount())
  assert(F.route({ { 9, 4 }, { 9, 6 }, { 8, 6 }, { 8, 8 }, WARDROBE_FRONT }, "wardrobe"), "Could not reach the wardrobe")
  F.idle(60); F.face("Up")
  F.check("follower is out beside the wardrobe", objectByLocalId(FOLLOWER) ~= nil)
  local tasks0, sprites0, gfx0 = activeTasks(), activeSprites(), playerGraphics()
  F.shot("before")

  local committed = {}
  for round = 1, 8 do
    local ok = mash(1200, "round" .. round)
    F.check("round " .. round .. ": no crash while mashing", ok)
    if not ok then break end
    F.check("round " .. round .. ": field settles with the picker closed", settle("round" .. round))
    local saved = outfit()
    committed[#committed + 1] = saved
    F.check("round " .. round .. ": committed outfit is valid", saved < 24, "saved=" .. saved)
    F.check("round " .. round .. ": follower still out", objectByLocalId(FOLLOWER) ~= nil)
    F.check("round " .. round .. ": tasks back to the field's own", activeTasks() == tasks0,
      string.format("tasks %d -> %d", tasks0, activeTasks()))
    F.check("round " .. round .. ": sprites back to the field's own", activeSprites() == sprites0,
      string.format("sprites %d -> %d", sprites0, activeSprites()))
    F.shot(string.format("round%d_outfit%d", round, saved))
    local x, y = F.pos()
    if x ~= WARDROBE_FRONT[1] or y ~= WARDROBE_FRONT[2] then F.leg(WARDROBE_FRONT[1], WARDROBE_FRONT[2]) end
    F.face("Up")
  end
  F.L("  committed outfits: " .. table.concat(committed, ","))
  F.check("player walks after the mash", F.ensureFree())
  F.check("player graphics follow the outfit style", (outfit() // 6 == 0) == (playerGraphics() == gfx0),
    string.format("outfit=%d gfx=%d start=%d", outfit(), playerGraphics(), gfx0))
  F.finish()
end)
