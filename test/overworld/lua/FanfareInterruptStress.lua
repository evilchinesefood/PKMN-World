-- A fanfare interrupted by anything the player can do must never leave the music paused or doubled.
--
-- PlayFanfare pauses the BGM and Task_Fanfare resumes it; since #627 MapMusicMain (src/sound.c)
-- finishes the count when a scene init's ResetTasks killed the task. This suite plays the 710-frame
-- MUS_AWAKEN_LEGEND fanfare in Fallarbor below the Pokemon Center door (a script that ends without
-- waitfanfare, standing in for an early caller) and interrupts it with real input: walking straight
-- into the door, the Summary from the party menu, the Bag, a Save from the Start menu, a message
-- mashed with A and B, a wild battle started and fled, a debug warp, and a soft reset that continues
-- from the save. After each interruption the player walks into the Center, whose music differs from
-- the town's. Oracle: no crash screen, the door loads the Center, the BGM is not paused once the
-- fanfare's length has passed, the Center's song is the one playing, and the fanfare's own music
-- player (SE2) has stopped, so nothing plays twice.
local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "FanfareInterruptStress")

local HUB = 100
local REGION_HOENN = 3
local FALLARBOR_GROUP, FALLARBOR_MAP = 0, 13
local USM_ICO_PARTY, USM_ICO_BAG, USM_ICO_SAVE = 1, 2, 7
local CONTEXT_RUNNING, CONTEXT_SHUTDOWN = 0, 2
local SCRIPT_BUF = S.gStringVar4 + 960
local SCR_OP_END, SCR_OP_CALLNATIVE, SCR_OP_PLAYFANFARE = 0x02, 0x23, 0x31
local MUS_AWAKEN_LEGEND, AWAKEN_LEGEND_FRAMES = 388, 710
local MUSICPLAYER_STATUS_PAUSE = 0x80000000
local ONLY = os.getenv("PW_FANFARE_ONLY")

local function d(n) return (n // 100) % 10, (n // 10) % 10, n % 10 end
local function hasControl()
  return F.ow() and F.r8(S.sLockFieldControls) == 0 and F.r8(S.sGlobalScriptContextStatus) == CONTEXT_SHUTDOWN
end
local function waitFor(pred, frames)
  for _ = 1, frames // 5 do if pred() then return true end; F.idle(5) end
  return pred()
end
local function warpToCoords(grp, map, x, y, tag)
  for _ = 1, 4 do
    F.dbg(); F.sel(0); F.sel(1); F.idle(20)
    F.spin(d(grp)); F.spin(d(map))
    F.press("A", 2)
    for _ = 1, 400 do
      F.w8(S.sWarpDestination + 2, 0xFF)
      F.w16(S.sWarpDestination + 4, x)
      F.w16(S.sWarpDestination + 6, y)
      F.idle(1)
      local px, py = F.pos()
      if F.ow() and F.grp() == grp and F.mapn() == map and px == x and py == y then F.idle(120); return true end
    end
    F.bOut(5)
  end
  F.shot(tag .. "_warpfail")
  return false
end
local function le16(t, v) t[#t + 1] = v & 0xFF; t[#t + 1] = (v >> 8) & 0xFF end
local function le32(t, v) le16(t, v & 0xFFFF); le16(t, (v >> 16) & 0xFFFF) end
local function runScript(b)
  for i, v in ipairs(b) do F.w8(SCRIPT_BUF + i - 1, v) end
  F.w8(S.sGlobalScriptContext, 0)
  F.w8(S.sGlobalScriptContext + 1, 1)
  F.w32(S.sGlobalScriptContext + 4, 0)
  F.w32(S.sGlobalScriptContext + S.ScriptCtx.scriptPtr, SCRIPT_BUF)
  F.w8(S.sGlobalScriptContextStatus, CONTEXT_RUNNING)
end
local function createMon(species, level, moves)
  local b = { SCR_OP_CALLNATIVE }; le32(b, S.ScrCmd_createmon | 1)
  b[#b + 1] = 0; b[#b + 1] = 6
  le16(b, species); le16(b, level)
  le32(b, (1 << 17) | (1 << 18) | (1 << 19) | (1 << 20))
  for k = 1, 4 do le16(b, moves[k] or 0) end
  b[#b + 1] = SCR_OP_END
  runScript(b)
  for _ = 1, 200 do F.idle(4); if hasControl() then break end end
  F.idle(30)
end
local function addItem(id, n)
  runScript({ 0x44, id & 0xFF, id >> 8, n, 0, SCR_OP_END })
  for _ = 1, 200 do F.idle(4); if hasControl() then break end end
  F.idle(30)
end

local function bgmStatus() return F.r32(S.gMPlayInfo_BGM + 4) end
local function bgmPaused() return bgmStatus() & MUSICPLAYER_STATUS_PAUSE ~= 0 end
local function playerPlaying(addr) local st = F.r32(addr + 4); return (st & 0xFFFF) ~= 0 and (st & MUSICPLAYER_STATUS_PAUSE) == 0 end
local function bgmSong() return F.r32(S.gMPlayInfo_BGM) end
local function inTown() return F.ow() and F.grp() == FALLARBOR_GROUP and F.mapn() == FALLARBOR_MAP end

local function startFanfare()
  local b = { SCR_OP_PLAYFANFARE }; le16(b, MUS_AWAKEN_LEGEND); b[#b + 1] = SCR_OP_END
  runScript(b)
  waitFor(function() return bgmPaused() and hasControl() end, 60)
  return emu.framecount()
end

local function backToField(tag)
  for _ = 1, 120 do
    if hasControl() then F.idle(10); if hasControl() then return true end end
    F.press("B", 2); F.idle(15)
  end
  F.L("  " .. tag .. ": no control after backing out")
  return false
end

local function openStartIcon(icon)
  F.press("Start", 2); F.idle(40)
  if not F.selectStartIcon(icon) then F.press("B", 2); F.idle(30); return false end
  F.press("A", 2)
  return true
end

-- Each interruption runs with the fanfare playing and returns whether it got started at all.
local CASES = {
  { name = "door_at_once", run = function() return true end },
  { name = "summary", run = function()
      if not openStartIcon(USM_ICO_PARTY) then return false end
      waitFor(function() return not F.ow() end, 200); F.idle(60)
      F.press("A", 2); F.idle(30); F.press("A", 2); F.idle(120)   -- the lead's Summary
      F.press("Right", 2); F.idle(30)
      return backToField("summary")
    end },
  { name = "bag", run = function()
      if not openStartIcon(USM_ICO_BAG) then return false end
      waitFor(function() return not F.ow() end, 200); F.idle(60)
      F.press("Right", 2); F.idle(20); F.press("Left", 2); F.idle(20)
      return backToField("bag")
    end },
  { name = "save", run = function()
      if not openStartIcon(USM_ICO_SAVE) then return false end
      for _ = 1, 60 do
        if hasControl() then break end
        F.press("A", 2); F.idle(40)
      end
      return backToField("save")
    end },
  { name = "message_mash", run = function()
      -- A three-page message (lockall, message, waitmessage, waitbuttonpress, closemessage,
      -- releaseall) mashed with A and B the way an impatient player does.
      local text = SCRIPT_BUF + 64
      local page = { 0xC2, 0xBF, 0xC6, 0xC6, 0xC9 }   -- HELLO
      local t = {}
      for p = 1, 3 do for _, c in ipairs(page) do t[#t + 1] = c end; t[#t + 1] = p < 3 and 0xFA or 0xFF end
      for i, c in ipairs(t) do F.w8(text + i - 1, c) end
      local b = { 0x69, 0x67 }; le32(b, text)
      for _, op in ipairs({ 0x66, 0x6D, 0x68, 0x6B, SCR_OP_END }) do b[#b + 1] = op end
      runScript(b)
      for i = 1, 40 do F.press(i % 2 == 0 and "A" or "B", 2); F.idle(6) end
      return backToField("message_mash")
    end },
  { name = "wild_battle_flee", run = function()
      -- setwildbattle SPECIES_ZIGZAGOON 3, ITEM_NONE; dowildbattle
      local b = { 0xB6 }; le16(b, 263); b[#b + 1] = 3; le16(b, 0); le16(b, 0); b[#b + 1] = 0; le16(b, 0)
      b[#b + 1] = 0xB7; b[#b + 1] = SCR_OP_END
      runScript(b)
      if not waitFor(function() return not F.ow() and F.r8(S.gBattlersCount) > 0 end, 900) then return false end
      F.idle(200)
      for _ = 1, 400 do
        if hasControl() then break end
        if F.ow() then F.press("A", 2); F.idle(20)
        else
          -- Run is the bottom-right battle action: Down, Right, A; A again to clear "Got away safely".
          F.press("Down", 2); F.idle(8); F.press("Right", 2); F.idle(8); F.press("A", 2); F.idle(40)
        end
      end
      return backToField("wild_battle_flee")
    end },
  { name = "debug_warp", run = function()
      return warpToCoords(FALLARBOR_GROUP, 14, 2, 8, "away") and warpToCoords(FALLARBOR_GROUP, FALLARBOR_MAP, 14, 8, "back")
    end },
  { name = "soft_reset_continue", setup = "save", run = function()
      for _ = 1, 10 do joypad.set({ A = true, B = true, Start = true, Select = true }); emu.frameadvance() end
      F.idle(60)
      return F.boot(FALLARBOR_GROUP, true) and backToField("soft_reset")
    end },
}

local function saveNow()
  if not openStartIcon(USM_ICO_SAVE) then return false end
  for _ = 1, 60 do
    if hasControl() then break end
    F.press("A", 2); F.idle(40)
  end
  return backToField("presave")
end

F.run(function()
  if not F.boot(HUB) then F.check("boot", false); F.finish(); return end
  createMon(6, 50, { 10, 45, 52 })
  local FLAG_SYS_POKEMON_GET = 0x948
  local f = F.sb1() + S.SaveBlock1.flags + FLAG_SYS_POKEMON_GET // 8
  F.w8(f, F.r8(f) | (1 << (FLAG_SYS_POKEMON_GET % 8)))
  addItem(28, 3)
  F.w8(F.sb2() + S.SaveBlock2.currentRegion, REGION_HOENN)
  F.w32(S.gCurrentRegion, REGION_HOENN)
  local a = F.sb2() + S.SaveBlock2.optionsU16
  F.w16(a, (F.r16(a) & ~7) | 3)

  for _, c in ipairs(CASES) do
    if not ONLY or c.name:find(ONLY, 1, true) then
      local tag = c.name
      if not F.check(tag .. ": below the Pokemon Center door",
        warpToCoords(FALLARBOR_GROUP, FALLARBOR_MAP, 14, 8, tag)) then F.finish(); return end
      if c.setup == "save" then F.check(tag .. ": saved first", saveNow()) end
      local townSong = bgmSong()
      local t0 = startFanfare()
      F.check(tag .. ": the fanfare pauses the town music", bgmPaused(), string.format("bgm=%08X", bgmStatus()))
      local ran = c.run()
      local spent = emu.framecount() - t0
      F.check(tag .. ": the interruption ran", ran, "frames=" .. spent)
      if F.reportCrash(tag) then break end
      if not inTown() then warpToCoords(FALLARBOR_GROUP, FALLARBOR_MAP, 14, 8, tag .. "_again") end
      F.step("Up")
      local center = waitFor(function() return F.ow() and not inTown() end, 1200)
      F.idle(math.max(60, AWAKEN_LEGEND_FRAMES + 90 - (emu.framecount() - t0)))
      F.shot(tag .. "_center")
      F.check(tag .. ": the Center door loads the Center", center,
        string.format("%d/%d cb2=%08X bgm=%08X", F.grp(), F.mapn(), F.cb2(), bgmStatus()))
      F.check(tag .. ": the music plays, not paused", not bgmPaused() and (bgmStatus() & 0xFFFF) ~= 0,
        string.format("bgm=%08X", bgmStatus()))
      F.check(tag .. ": the Center's song replaced the town's", bgmSong() ~= townSong,
        string.format("song=%08X town=%08X", bgmSong(), townSong))
      if S.gMPlayInfo_SE2 then
        F.check(tag .. ": the fanfare player has stopped", not playerPlaying(S.gMPlayInfo_SE2),
          string.format("se2=%08X", F.r32(S.gMPlayInfo_SE2 + 4)))
      end
    end
  end
  F.check("no crash", not F.crashScreen())
  F.finish()
end)
