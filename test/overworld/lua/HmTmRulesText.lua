-- The Rustboro Cutter's HM speech must match this build's move rules.
--
-- I_REUSABLE_TMS is TRUE and QOL_FIELD_MOVES_NO_TEACH lets a POKéMON that can learn CUT use it
-- untaught, but the Emerald speech said "Any POKéMON that's learned CUT" and "unlike a TM, an HM can
-- be used more than once". The suite talks to the Cutter twice with real input (the HM gift, then
-- the repeat explanation). Oracle: the explanation, read from gStringVar4, no longer contrasts HMs
-- with single-use TMs and names "can learn CUT". Route 14's Carter ("POKéMON can't forget those
-- moves easily", against P_CAN_FORGET_HIDDEN_MOVE) has no warp to reach him; ValidateConfigRules.py
-- covers his line.
local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "HmTmRulesText")

local HUB_GROUP = 100
local CUTTER_G, CUTTER_M = 11, 11
local CONTEXT_SHUTDOWN = 2

local function where() local x, y = F.pos(); return string.format("%d/%d (%d,%d)", F.grp(), F.mapn(), x, y) end
local function hasControl()
  return F.ow() and F.r8(S.sLockFieldControls) == 0 and F.r8(S.sGlobalScriptContextStatus) == CONTEXT_SHUTDOWN
end
local function instantText()
  local a = F.sb2() + S.SaveBlock2.optionsU16
  F.w16(a, (F.r16(a) & ~7) | 3)
end

local function decode(addr, max)
  local out = {}
  for i = 0, (max or 400) - 1 do
    local c = F.r8(addr + i)
    if c == 0xFF then break end
    if c == 0x00 then out[#out + 1] = " "
    elseif c >= 0xBB and c <= 0xD4 then out[#out + 1] = string.char(65 + c - 0xBB)
    elseif c >= 0xD5 and c <= 0xEE then out[#out + 1] = string.char(97 + c - 0xD5)
    elseif c >= 0xA1 and c <= 0xAA then out[#out + 1] = string.char(48 + c - 0xA1)
    elseif c == 0xAB then out[#out + 1] = "!"
    elseif c == 0xAD then out[#out + 1] = "."
    elseif c == 0xAE then out[#out + 1] = "-"
    elseif c == 0xB8 then out[#out + 1] = ","
    elseif c == 0xB4 then out[#out + 1] = "'"
    elseif c == 0xFE or c == 0xFA or c == 0xFB then out[#out + 1] = " "
    else out[#out + 1] = "?" end
  end
  return table.concat(out)
end

local function backToControl()
  for _ = 1, 80 do
    if hasControl() then return true end
    F.press("B", 2); F.idle(20)
  end
  return hasControl()
end

local function talkUntilControl(dir, tag)
  F.face(dir)
  F.w8(S.gStringVar4, 0xFF)           -- a repeat talk prints the same text; start from an empty buffer
  F.press("A", 2)
  local all = {}
  for i = 1, 900 do
    if i % 8 == 0 and F.reportCrash(tag) then break end
    local t = decode(S.gStringVar4)
    if not all[t] then
      all[t] = true; all[#all + 1] = t; F.L("  " .. tag .. ": " .. t)
      F.idle(20); F.shot(tag)
    end
    if i > 30 and hasControl() then break end
    if i % 40 == 0 then F.press("A", 2) else F.idle(1) end
  end
  backToControl()
  local said = {}
  for k = 2, #all do said[#said + 1] = all[k] end
  return table.concat(said, " | ")
end

F.run(function()
  if not F.boot(HUB_GROUP) then F.check("boot to the hub", false); F.finish(); return end
  instantText()
  F.check("warp to the Cutter's house", F.warpTo(0, 1, 1, 0, 1, 1, 0, 0, 0, CUTTER_G, CUTTER_M, "cutter"))
  instantText()
  F.check("walk up to the Cutter", F.route({ { 5, 7 }, { 7, 7 }, { 7, 6 } }, "cutter"), where())
  local first = talkUntilControl("Up", "cutter_gift")
  local again = talkUntilControl("Up", "cutter_again")
  for _, t in ipairs({ { "the HM gift", first }, { "the repeat talk", again } }) do
    local tag, text = t[1], t[2]
    F.check(tag .. ": the CUT explanation was read", text:find("HIDDEN MACHINE", 1, true) ~= nil, text)
    F.check(tag .. ": does not call TMs single-use", not text:find("unlike a TM", 1, true), text)
    F.check(tag .. ": a POKéMON that can learn CUT may use it", text:find("can learn CUT", 1, true) ~= nil, text)
  end
  F.finish()
end)
