-- The Battle Frontier lobby refusal must spell "ineligible".
--
-- CheckPartyIneligibility appends gText_FrontierFacilityAreInelegible or
-- gText_FrontierFacilityTotalCaughtSpeciesBanned to gStringVar1, and every lobby attendant prints it
-- when the party has too few eligible Pokemon. Both strings read "inelegible". Two parties are
-- refused at the Battle Arena attendant with real input (Challenge, Lv. 50): one with two banned
-- legendaries and one duplicate pair (the "you caught" sentence), one with only a duplicate pair (the
-- short "are ineligible" ending). gStringVar1 is decoded while the refusal is on screen.
--
-- Run via: test/overworld/mgba-run.sh test/overworld/lua/FrontierIneligibleText.lua <rom.gba>

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "FrontierIneligibleText")

local ARENA_G, ARENA_M = 26, 28

local SCRIPT_BUF = S.gStringVar4 + 960
local function le16(t, v) t[#t + 1] = v & 0xFF; t[#t + 1] = (v >> 8) & 0xFF end
local function le32(t, v) le16(t, v & 0xFFFF); le16(t, (v >> 16) & 0xFFFF) end
local function giveMon(species)
  local b = { 0x23 }; le32(b, S.ScrCmd_createmon | 1)
  b[#b + 1] = 0; b[#b + 1] = 6
  le16(b, species); le16(b, 50)
  le32(b, 1 << 17)
  le16(b, 33)
  b[#b + 1] = 0x02
  for i, v in ipairs(b) do F.w8(SCRIPT_BUF + i - 1, v) end
  F.w8(S.sGlobalScriptContext, 0)
  F.w8(S.sGlobalScriptContext + 1, 1)
  F.w32(S.sGlobalScriptContext + 4, 0)
  F.w32(S.sGlobalScriptContext + S.ScriptCtx.scriptPtr, SCRIPT_BUF)
  F.w8(S.sGlobalScriptContextStatus, 0)
  F.idle(20)
end

-- Letters, digits and spaces from the game charmap; anything else shows as '?' and a newline as '|'.
local function decode(addr)
  local out = {}
  for i = 0, 120 do
    local c = F.r8(addr + i)
    if c == 0xFF then break end
    if c == 0x00 then out[#out + 1] = " "
    elseif c >= 0xBB and c <= 0xD4 then out[#out + 1] = string.char(65 + c - 0xBB)
    elseif c >= 0xD5 and c <= 0xEE then out[#out + 1] = string.char(97 + c - 0xD5)
    elseif c >= 0xA1 and c <= 0xAA then out[#out + 1] = string.char(48 + c - 0xA1)
    elseif c == 0xFE then out[#out + 1] = "|"
    else out[#out + 1] = "?" end
  end
  return table.concat(out)
end

local function liveMenu()
  for i = 0, S.Task.count - 1 do
    local task = S.gTasks + i * S.Task.stride
    local fn = F.r32(task + S.Task.func) & 0xFFFFFFFE
    if F.r8(task + S.Task.isActive) ~= 0 and fn == S.Task_HandleMultichoiceInput then return true end
  end
end
local function pickRow0(tag)
  for _ = 1, 80 do
    if liveMenu() then
      F.idle(12)
      for _ = 1, 4 do if F.mcur() == 0 then break end; F.press("Up", 2); F.idle(12) end
      F.press("A", 2); F.idle(40); return true
    end
    F.press("A", 2); F.idle(30)
  end
  F.L("  " .. tag .. ": no menu"); return false
end

local function refusal(tag, species, expected)
  client.loadstate(F.out .. "FrontierIneligibleText_base.ss"); F.idle(10)
  for _, sp in ipairs(species) do giveMon(sp) end
  F.check(tag .. ": party built", F.r8(S.gPartiesCount) == #species, "n=" .. F.r8(S.gPartiesCount))
  assert(F.warpTo(0, 2, 6, 0, 2, 8, 0, 0, 0, ARENA_G, ARENA_M, tag), "Arena warp failed")
  F.idle(40)
  F.check(tag .. ": walked to the attendant", F.route({ { 7, 11 }, { 7, 8 } }, tag), string.format("(%d,%d)", F.pos()))
  F.face("Up"); F.press("A", 2); F.idle(30)
  local took = pickRow0(tag .. "_challenge")
  F.w8(S.gStringVar1, 0xFF)
  took = took and pickRow0(tag .. "_lv50")
  F.check(tag .. ": chose Challenge and Lv. 50", took)
  local text
  for _ = 1, 600 do
    if text then break end
    F.idle(1)
    if F.r8(S.gStringVar1) ~= 0xFF and F.r16(S.gSpecialVar_0x8004) == 1 then F.idle(60); text = decode(S.gStringVar1); break end
  end
  F.shot(tag .. "_refusal")
  F.L("  " .. tag .. " gStringVar1: " .. tostring(text))
  F.check(tag .. ": the party was refused", text ~= nil)
  F.check(tag .. ": " .. expected, text ~= nil and text:find(expected, 1, true) ~= nil, tostring(text))
  F.check(tag .. ": no \"inelegible\"", text ~= nil and not text:find("inelegible", 1, true), tostring(text))
  for _ = 1, 40 do
    if F.ow() and F.r8(S.sGlobalScriptContextStatus) == 2 then break end
    if liveMenu() then F.press("B", 2) else F.press("A", 2) end
    F.idle(30)
  end
end

F.run(function()
  assert(F.boot(100), "Fresh game did not boot")
  client.savestate(F.out .. "FrontierIneligibleText_base.ss")
  refusal("banned", { 150, 249, 6, 6 }, "you caught are ineligible")
  refusal("duplicates", { 6, 6, 9, 9 }, " are ineligible")
  F.check("no crash screen", not F.crashScreen())
  F.finish()
end)
