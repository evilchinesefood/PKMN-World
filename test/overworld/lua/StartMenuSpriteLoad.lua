-- The Start menu opened on a crowded rainy route.
--
-- Rain keeps 24 sprites alive, every object event has a shadow sprite, and visible wild Pokemon,
-- the follower, footprints and reflections add more. The Start menu wheel then needs up to six icon
-- sprites and two arrows. Found by OweSurfLedgeFuzz: on Route 40 the field already held 59
-- sprites and the sixth icon hit sprite.c's "Out of sprite slots" assert screen.
--
-- The suite builds that scene the way play does: a level 100 Lapras follower on Route 40's beach,
-- the encounter spawn countdown zeroed so visible wild Pokemon fill their slots, and running
-- along the sand. Once the field holds at least LOAD sprites with control free, it presses Start.
-- Each opening must show no crash screen, keep the main loop running, and B must hand control back.
-- At least one opening must find 57 or more sprites already in use, where the menu cannot fit.
--
-- Run via test/overworld/mgba-run.sh test/overworld/lua/StartMenuSpriteLoad.lua

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "StartMenuSpriteLoad")

local CONTEXT_RUNNING = 0
local PARTY_SIZE = 6
local SPECIES_LAPRAS = 131
local MOVE_SURF, MOVE_ICE_BEAM = 57, 58
local LOAD = 58
local OPENINGS = 5
local NEEDS = 57 -- six icons and two arrows overflow 64 from here
local ROUTE40_G, ROUTE40_M = 87, 1

local function inBattle() return F.cb2() == (S.BattleMainCB2 & ~1) end
local function hasControl()
  return F.ow() and F.r8(S.sLockFieldControls) == 0
    and F.r8(S.sGlobalScriptContextStatus) ~= CONTEXT_RUNNING
end
local function vblank() return F.r32(S.gMain + 0x20) end
local function spritesInUse()
  local n = 0
  for i = 0, S.Sprite.count - 1 do
    if (F.r16(S.gSprites + i * S.Sprite.stride + S.Sprite.inUse) & 1) == 1 then n = n + 1 end
  end
  return n
end

local SCRIPT_BUF = S.gStringVar4 + 960
local function le16(t, v) t[#t + 1] = v & 0xFF; t[#t + 1] = (v >> 8) & 0xFF end
local function le32(t, v) le16(t, v & 0xFFFF); le16(t, (v >> 16) & 0xFFFF) end
local function runScript(bytes)
  for i, b in ipairs(bytes) do F.w8(SCRIPT_BUF + i - 1, b) end
  F.w8(S.sGlobalScriptContext, 0)
  F.w8(S.sGlobalScriptContext + 1, 1)
  F.w32(S.sGlobalScriptContext + 4, 0)
  F.w32(S.sGlobalScriptContext + S.ScriptCtx.scriptPtr, SCRIPT_BUF)
  F.w8(S.sGlobalScriptContextStatus, CONTEXT_RUNNING)
end
local function createMon(species, level, moves)
  local b = { 0x23 }; le32(b, S.ScrCmd_createmon | 1)
  b[#b + 1] = 0; b[#b + 1] = PARTY_SIZE
  le16(b, species); le16(b, level)
  le32(b, (1 << 17) | (1 << 18) | (1 << 19) | (1 << 20))
  for k = 1, 4 do le16(b, moves[k] or 0) end
  b[#b + 1] = 0x02
  runScript(b); F.idle(20)
  return F.r8(S.gPartiesCount)
end

-- Battles that interrupt the run (a trainer's sight, a wild Pokemon's contact) are won with Surf
-- and Ice Beam in turn; the action cursor is pinned to FIGHT.
local function settle(tag)
  for f = 1, 30000 do
    if inBattle() then
      local slot = (f // 900) % 2
      F.w8(S.gActionSelectionCursor, 0)
      F.w8(S.gMoveSelectionCursor, slot)
      F.w8(S.gBattleMons + S.BattlePokemon.pp + slot, 10)
      if f % 10 == 0 then F.press("A", 2) else F.idle(1) end
    elseif hasControl() then
      return true
    else
      if f % 20 == 0 then F.press("B", 2) else F.idle(1) end
    end
    if f % 120 == 0 and F.reportCrash(tag) then return false end
  end
  return false
end

-- Run along the sand between x=10 and x=30 on rows 15 and 16 until the field holds LOAD sprites.
local function buildLoad(tag)
  local peak, dir = 0, "Right"
  for round = 1, 400 do
    F.w8(S.sOWESpawnCountdown, 0)
    for _ = 1, 24 do
      joypad.set({ [dir] = true, B = true }); emu.frameadvance()
      local n = spritesInUse()
      if n > peak then peak = n end
      if n >= LOAD and hasControl() then joypad.set({}); return true, n end
    end
    joypad.set({})
    if not settle(tag .. "_r" .. round) then return false, peak end
    local x = F.pos()
    if x >= 30 then dir = "Left" elseif x <= 10 then dir = "Right" end
  end
  return false, peak
end

F.run(function()
  if not F.boot(100) then F.check("boot to the hub", false); F.finish(); return end
  F.check("a level 100 Lapras leads", createMon(SPECIES_LAPRAS, 100, { MOVE_SURF, MOVE_ICE_BEAM }) == 1)
  local ok = F.warpTo(0, 8, 7, 0, 0, 1, 0, 0, 9, ROUTE40_G, ROUTE40_M, "route40")
  if not F.check("warp to Route 40's beach", ok) then F.finish(); return end
  F.step("Down")
  local fullest = 0
  for i = 1, OPENINGS do
    local tag = "opening " .. i
    local loaded, n = buildLoad(tag)
    if not F.check(tag .. string.format(": the field reached %d sprites", LOAD), loaded, "peak=" .. n) then break end
    F.L(string.format("  %s: %d sprites in use at (%d,%d)", tag, n, F.pos()))
    local v0 = vblank()
    for _ = 1, 20 do
      if F.r8(S.sLockFieldControls) ~= 0 then break end
      joypad.set({ Start = true }); emu.frameadvance(); emu.frameadvance()
      joypad.set({}); emu.frameadvance()
    end
    local atOpen = spritesInUse()
    if atOpen > fullest then fullest = atOpen end
    F.L(string.format("  %s: %d sprites in use as the menu opens", tag, atOpen))
    F.idle(150)
    local crashed = F.reportCrash(tag)
    F.check(tag .. ": Start opens with no crash screen", not crashed)
    F.check(tag .. ": the main loop keeps running", vblank() - v0 > 100, string.format("vblank +%d", vblank() - v0))
    F.check(tag .. ": the menu is up", not hasControl() and F.r8(S.sLockFieldControls) ~= 0)
    if crashed then break end
    for _ = 1, 10 do
      if hasControl() then break end
      F.press("B", 2); F.idle(30)
    end
    F.check(tag .. ": B hands control back", hasControl())
    F.check(tag .. ": still on Route 40", F.grp() == ROUTE40_G and F.mapn() == ROUTE40_M)
  end
  F.check(string.format("an opening met the menu with %d or more sprites in use", NEEDS), fullest >= NEEDS,
    "fullest=" .. fullest)
  F.finish()
end)
