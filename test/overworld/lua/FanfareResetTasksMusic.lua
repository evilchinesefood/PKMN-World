-- A fanfare cut short by a menu must still hand the music back, or the next door with other music
-- blacks out.
--
-- PlayFanfare pauses the BGM and Task_Fanfare resumes it when the fanfare ends. Every menu and
-- field return calls ResetTasks, which killed that task, so any caller that handed control back
-- before its fanfare ended left the BGM paused for good. A door to a map with other music then
-- waits in FadeOutMapMusic for a paused song to stop, and the screen stays black. #624 fixed one
-- such caller (the summary relearner); this suite covers the class at the sound layer.
--
-- In Fallarbor below the Pokemon Center door, a script plays the 710-frame MUS_AWAKEN_LEGEND fanfare
-- and ends without waitfanfare, as such a caller would. With real input the player opens Start,
-- POKeMON (the party menu's init calls ResetTasks), backs out, waits out the fanfare and walks into
-- the Center. Setup creates a Charizard with a createmon script and sets FLAG_SYS_POKEMON_GET the way
-- a gift script does.
local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "FanfareResetTasksMusic")

local HUB = 100
local REGION_HOENN = 3
local FALLARBOR_GROUP, FALLARBOR_MAP = 0, 13
local CONTEXT_RUNNING, CONTEXT_SHUTDOWN = 0, 2
local SCRIPT_BUF = S.gStringVar4 + 960
local SCR_OP_END, SCR_OP_CALLNATIVE, SCR_OP_PLAYFANFARE = 0x02, 0x23, 0x31
local MUS_AWAKEN_LEGEND, AWAKEN_LEGEND_FRAMES = 388, 710

local function d(n) return (n // 100) % 10, (n // 10) % 10, n % 10 end

local function hasControl()
  return F.ow() and F.r8(S.sLockFieldControls) == 0 and F.r8(S.sGlobalScriptContextStatus) == CONTEXT_SHUTDOWN
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
      if F.ow() and F.grp() == grp and F.mapn() == map and px == x and py == y then
        F.idle(120)
        return true
      end
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

local function waitFor(pred, frames)
  for _ = 1, frames // 5 do if pred() then return true end; F.idle(5) end
  return pred()
end

local MUSICPLAYER_STATUS_PAUSE = 0x80000000
local function bgmStatus() return F.r32(S.gMPlayInfo_BGM + 4) end
local function bgmPaused() return bgmStatus() & MUSICPLAYER_STATUS_PAUSE ~= 0 end

F.run(function()
  if not F.boot(HUB) then F.check("boot", false); F.finish(); return end
  createMon(6, 50, { 10, 45, 52 })
  local FLAG_SYS_POKEMON_GET = 0x948
  local f = F.sb1() + S.SaveBlock1.flags + FLAG_SYS_POKEMON_GET // 8
  F.w8(f, F.r8(f) | (1 << (FLAG_SYS_POKEMON_GET % 8)))
  F.check("setup: a party for the Start menu", F.r8(S.gPartiesCount) >= 1, "n=" .. F.r8(S.gPartiesCount))
  F.w8(F.sb2() + S.SaveBlock2.currentRegion, REGION_HOENN)
  F.w32(S.gCurrentRegion, REGION_HOENN)
  if not F.check("setup: in Fallarbor below the Pokemon Center door",
    warpToCoords(FALLARBOR_GROUP, FALLARBOR_MAP, 14, 8, "fallarbor")) then F.finish(); return end

  local b = { SCR_OP_PLAYFANFARE }; le16(b, MUS_AWAKEN_LEGEND); b[#b + 1] = SCR_OP_END
  runScript(b)
  local t0 = emu.framecount()
  F.check("the fanfare pauses the town music", waitFor(function() return bgmPaused() and hasControl() end, 60),
    string.format("bgm status=%08X", bgmStatus()))

  F.press("Start", 2); F.idle(30)
  F.check("the Start menu offers POKeMON", F.selectStartIcon(1))
  F.press("A", 2)
  local opened = waitFor(function() return not F.ow() end, 200)
  local inMenu = emu.framecount() - t0
  F.L(string.format("  party menu open %d frames after the fanfare began", inMenu))
  F.check("the party menu opens while the fanfare plays", opened and inMenu < AWAKEN_LEGEND_FRAMES,
    string.format("cb2=%08X frames=%d", F.cb2(), inMenu))
  F.idle(20)
  for _ = 1, 40 do
    if hasControl() then break end
    F.press("B", 2); F.idle(20)
  end
  F.check("control returns to the field", hasControl())

  F.idle(math.max(0, AWAKEN_LEGEND_FRAMES + 60 - (emu.framecount() - t0)))
  F.check("the music resumed after the fanfare", not bgmPaused(), string.format("bgm status=%08X", bgmStatus()))

  -- The Pokemon Center plays other music than the town, so its door fades the town's song out
  -- before the warp.
  F.step("Up")
  local center = waitFor(function() return F.ow() and not (F.grp() == FALLARBOR_GROUP and F.mapn() == FALLARBOR_MAP) end, 900)
  F.shot("after_center_door")
  F.check("the Pokemon Center door loads the Center", center,
    string.format("%d/%d cb2=%08X bgm status=%08X", F.grp(), F.mapn(), F.cb2(), bgmStatus()))
  F.check("no crash", not F.crashScreen())
  F.finish()
end)
