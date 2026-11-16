-- Teaching a move must not leave the music paused, or the next door with other music blacks out.
--
-- LearnMove played the level-up fanfare and handed input straight back. PlayFanfare pauses the BGM
-- and Task_Fanfare resumes it 80 frames later. Forgetting a move for a second one inside those
-- frames goes through the summary and back into the relearner, whose init calls ResetTasks; that
-- killed Task_Fanfare and left the BGM paused for good. A door to a map with other music then waits
-- in FadeOutMapMusic for a paused song to stop, and Task_WarpAndLoadMap holds the screen black
-- forever. InputSpamStress's dig mash found it.
--
-- With real input in Fallarbor below the Pokemon Center door: Start, POKeMON, the lead Charizard
-- (it knows three moves), Summary, the battle moves page, Start for the relearner; teach the first
-- move (A, YES); mash A at Instant text through a second teach that forgets a move; back out to
-- the field and walk into the Center. Setup creates the Charizard with a createmon script and sets
-- FLAG_SYS_POKEMON_GET the way a gift script does.
local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "RelearnerFanfareMusic")

local HUB = 100
local REGION_HOENN = 3
local FALLARBOR_GROUP, FALLARBOR_MAP = 0, 13
local CONTEXT_RUNNING, CONTEXT_SHUTDOWN = 0, 2
local SCRIPT_BUF = S.gStringVar4 + 960

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

-- gStringVar4 as uppercase ASCII; Gen 3 A = 0xBB, a = 0xD5.
local function message()
  local s = {}
  for i = 0, 200 do
    local c = F.r8(S.gStringVar4 + i)
    if c == 0xFF then break end
    if c >= 0xBB and c <= 0xD4 then s[#s + 1] = string.char(65 + c - 0xBB)
    elseif c >= 0xD5 and c <= 0xEE then s[#s + 1] = string.char(65 + c - 0xD5)
    elseif c == 0xAC then s[#s + 1] = "?"
    else s[#s + 1] = " " end
  end
  return table.concat(s)
end

local function le16(t, v) t[#t + 1] = v & 0xFF; t[#t + 1] = (v >> 8) & 0xFF end
local function le32(t, v) le16(t, v & 0xFFFF); le16(t, (v >> 16) & 0xFFFF) end
local function createMon(species, level, moves)
  local b = { 0x23 }; le32(b, S.ScrCmd_createmon | 1)
  b[#b + 1] = 0; b[#b + 1] = 6
  le16(b, species); le16(b, level)
  le32(b, (1 << 17) | (1 << 18) | (1 << 19) | (1 << 20))
  for k = 1, 4 do le16(b, moves[k] or 0) end
  b[#b + 1] = 0x02
  for i, v in ipairs(b) do F.w8(SCRIPT_BUF + i - 1, v) end
  F.w8(S.sGlobalScriptContext, 0)
  F.w8(S.sGlobalScriptContext + 1, 1)
  F.w32(S.sGlobalScriptContext + 4, 0)
  F.w32(S.sGlobalScriptContext + S.ScriptCtx.scriptPtr, SCRIPT_BUF)
  F.w8(S.sGlobalScriptContextStatus, CONTEXT_RUNNING)
  for _ = 1, 200 do F.idle(4); if hasControl() then break end end
  F.idle(30)
end

local function waitFor(pred, frames)
  for _ = 1, frames // 5 do if pred() then return true end; F.idle(5) end
  return pred()
end

local MUSICPLAYER_STATUS_PAUSE = 0x80000000
local function bgmPaused() return F.r32(S.gMPlayInfo_BGM + 4) & MUSICPLAYER_STATUS_PAUSE ~= 0 end

F.run(function()
  if not F.boot(HUB) then F.check("boot", false); F.finish(); return end
  createMon(6, 50, { 10, 45, 52 })
  local FLAG_SYS_POKEMON_GET = 0x948 -- what a gift script sets; it puts POKeMON on the Start menu
  local f = F.sb1() + S.SaveBlock1.flags + FLAG_SYS_POKEMON_GET // 8
  F.w8(f, F.r8(f) | (1 << (FLAG_SYS_POKEMON_GET % 8)))
  F.check("setup: a Charizard that knows three moves", F.r8(S.gPartiesCount) >= 1, "n=" .. F.r8(S.gPartiesCount))
  F.w8(F.sb2() + S.SaveBlock2.currentRegion, REGION_HOENN)
  F.w32(S.gCurrentRegion, REGION_HOENN)
  if not F.check("setup: in Fallarbor below the Pokemon Center door",
    warpToCoords(FALLARBOR_GROUP, FALLARBOR_MAP, 14, 8, "fallarbor")) then F.finish(); return end

  -- Start > POKeMON > the lead > Summary (first in its list), Right twice to the battle moves
  -- page, Start opens the relearner.
  local a = F.sb2() + S.SaveBlock2.optionsU16
  F.w16(a, (F.r16(a) & ~7) | 3)
  F.press("Start", 2); F.idle(60)
  F.check("the Start menu offers POKeMON", F.selectStartIcon(1))
  F.press("A", 2); F.idle(120); F.press("A", 2); F.idle(30); F.press("A", 2); F.idle(120)
  F.press("Right", 2); F.idle(40); F.press("Right", 2); F.idle(40)
  F.shot("moves_page")
  F.press("Start", 2)
  local opened = waitFor(function() return F.cb2() == S.CB2_MoveRelearnerMain end, 400)
  F.idle(60)
  F.shot("move_list")
  F.check("Start on the moves page opens the relearner", opened, string.format("cb2=%08X", F.cb2()))

  -- Teach the first move into the empty fourth slot: A, A on YES, and A past "learned".
  local function answerYes(word)
    if not waitFor(function() return message():find(word) ~= nil end, 200) then return false end
    F.idle(16)
    F.press("A", 2)
    return true
  end
  F.press("A", 2)
  F.check("the relearner asks to teach the move", answerYes("TEACH [A-Z ]+%?"), message())
  waitFor(function() return message():find("LEARNED") ~= nil end, 200)
  local learned = false
  for _ = 1, 100 do
    if bgmPaused() then learned = true; break end
    F.press("A", 2); F.idle(2)
  end
  F.check("the level-up fanfare plays", learned, message())
  local t0 = emu.framecount()
  -- Inside the fanfare, mash A to teach a second move: four are known now, so A through "Should
  -- a move be deleted", YES and "Which move should be forgotten?" opens the summary's move list,
  -- and A there forgets the first move and returns to the relearner.
  local visited, back = false, false
  for _ = 1, 400 do
    if F.cb2() ~= S.CB2_MoveRelearnerMain then visited = true end
    if visited and F.cb2() == S.CB2_MoveRelearnerMain then back = true; break end
    F.press("A", 2); F.idle(2)
  end
  F.L(string.format("  back in the relearner %d frames after the fanfare began", emu.framecount() - t0))
  F.check("forgetting a move goes through the summary and back", back, string.format("cb2=%08X", F.cb2()))
  F.idle(200)
  F.check("the music resumed after the fanfare", not bgmPaused(), string.format("bgm status=%08X", F.r32(S.gMPlayInfo_BGM + 4)))
  for _ = 1, 400 do
    if hasControl() then F.idle(20); if hasControl() then break end end
    if message():find("STOP") then F.press("A", 2) else F.press("B", 2) end
    F.idle(20)
  end
  F.check("control returns to the field", hasControl())

  -- The Pokemon Center plays other music than the town, so its door fades the town's song out
  -- before the warp.
  F.step("Up")
  local center = waitFor(function() return F.ow() and not (F.grp() == FALLARBOR_GROUP and F.mapn() == FALLARBOR_MAP) end, 900)
  F.shot("after_center_door")
  F.check("the Pokemon Center door loads the Center", center,
    string.format("%d/%d cb2=%08X bgm status=%08X", F.grp(), F.mapn(), F.cb2(), F.r32(S.gMPlayInfo_BGM + 4)))
  F.check("no crash", not F.crashScreen())
  F.finish()
end)
