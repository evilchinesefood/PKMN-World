-- HM Flash is one item in the shared Bag, so its received flag is one per world. Sprout Tower's
-- Sage Li checked that flag before his battle, so a player who had HM Flash from Hoenn's Granite
-- Cave walked up to him and got his after-battle line: the battle never happened. Li now fights
-- first and only skips the gift. The suite records Hoenn's Flash gift as Granite Cave leaves it,
-- stands in front of Li with a party member and talks to him.
--
-- Run via test/overworld/mgba-run.sh test/overworld/lua/SageLiAfterHoennFlash.lua <rom>

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "SageLiAfterHoennFlash")

local HUB = 100
local SPROUT_3F = { 78, 8 }
local FLAG_RECEIVED_HM_FLASH = 0x6D
local BATTLE_TYPE_TRAINER = 1 << 3
local CONTEXT_RUNNING = 0

local function where() local x, y = F.pos(); return string.format("%d/%d (%d,%d)", F.grp(), F.mapn(), x, y) end
local function d(n) return (n // 100) % 10, (n // 10) % 10, n % 10 end
local function flagSet(id) local a = F.sb1() + S.SaveBlock1.flags + id // 8; F.w8(a, F.r8(a) | (1 << (id % 8))) end
local function warpToCoords(m, x, y, tag)
  for _ = 1, 4 do
    F.dbg(); F.sel(0); F.sel(1); F.idle(20)
    F.spin(d(m[1])); F.spin(d(m[2]))
    F.press("A", 2)
    for _ = 1, 400 do
      F.w8(S.sWarpDestination + 2, 0xFF)
      F.w16(S.sWarpDestination + 4, x)
      F.w16(S.sWarpDestination + 6, y)
      F.idle(1)
      local px, py = F.pos()
      if F.ow() and F.grp() == m[1] and F.mapn() == m[2] and px == x and py == y then
        F.idle(120)
        return true
      end
    end
    F.bOut(5)
  end
  F.shot(tag .. "_warpfail")
  return false
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
  F.idle(20)
end
local function createMon(species, level)
  local b = { 0x23 }; le32(b, S.ScrCmd_createmon | 1)
  b[#b + 1] = 0; b[#b + 1] = 6
  le16(b, species); le16(b, level)
  le32(b, (1 << 17) | (1 << 18) | (1 << 19) | (1 << 20))
  for _ = 1, 4 do le16(b, 0) end
  b[#b + 1] = 0x02
  runScript(b)
end

F.run(function()
  if not F.boot(HUB) then F.check("boot", false); F.finish(); return end
  createMon(25, 50)
  runScript({ 0x25, 0, 0, 0x02 })   -- special HealPlayerParty; end
  flagSet(FLAG_RECEIVED_HM_FLASH)
  F.check("setup: standing in front of Sage Li", warpToCoords(SPROUT_3F, 11, 4, "li"), where())
  F.face("Up")
  F.press("A", 2)
  local battled = false
  for _ = 1, 120 do
    F.idle(20)
    if F.battlers() > 0 and (F.battleFlags() & BATTLE_TYPE_TRAINER) ~= 0 then battled = true; break end
    if F.ow() and F.r8(S.sLockFieldControls) == 0 and F.r8(S.sGlobalScriptContextStatus) ~= CONTEXT_RUNNING then break end
    F.press("A", 2)
  end
  F.shot("li_talk")
  F.check("li: Sage Li battles a player who already has HM Flash", battled,
    string.format("battlers=%d flags=%X", F.battlers(), F.battleFlags()))
  F.finish()
end)
