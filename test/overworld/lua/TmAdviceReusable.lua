-- TM advice must match reusable TMs.
--
-- I_REUSABLE_TMS is TRUE: every TM is a key-importance item that teaches its move any number of
-- times. Three explanations still called a TM single-use: Brock's TM39 speech, Roxanne's Rock Tomb
-- speech and the Route 104 boy who gives the Bullet Seed TM ("good only for one-time use ... Once you
-- use it, it's gone."). The suite drives the Route 104 boy with real input: the first talk gives the
-- TM, the second prints his advice. Oracle: the advice (read from gStringVar4, where the field
-- message is expanded) does not call a TM one-time or gone once used.
local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "TmAdviceReusable")

local ROUTE104_G, ROUTE104_M = 0, 19
local CONTEXT_SHUTDOWN = 2
local ITEM_TM_BULLET_SEED = 590                       -- ITEM_TM09
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

local function talk(tag, record)
  F.face("Right")
  F.press("A", 2)
  local seen = {}
  for i = 1, 900 do
    if F.reportCrash(tag) then break end
    if i > 20 and hasControl() then break end
    if record and i % 10 == 0 then
      local t = decode(S.gStringVar4)
      if not seen[t] then seen[t] = true; seen[#seen + 1] = t; F.shot(string.format("%s_%d", tag, #seen)) end
    end
    if i % 40 == 0 then F.press("A", 2) else F.idle(1) end
  end
  for _ = 1, 300 do if hasControl() then break end F.press("B", 2); F.idle(20) end
  return seen
end

F.run(function()
  if not F.boot(100) then F.check("boot to the hub", false); F.finish(); return end
  instantText()
  F.check("warp to Route 104 by the flower shop", F.warpTo(0, 0, 0, 0, 1, 9, 0, 0, 1, ROUTE104_G, ROUTE104_M, "r104"))
  instantText()
  F.check("walk to the Bullet Seed boy", F.route({ { 5, 19 }, { 4, 19 }, { 4, 26 } }, "boy"), where())
  talk("gift", false)
  F.check("the boy gave the Bullet Seed TM", F.itemCount(ITEM_TM_BULLET_SEED) == 1)
  local advice = talk("advice", true)
  local all = {}
  for _, t in ipairs(advice) do all[#all + 1] = t; F.L("  line: " .. t) end
  local text = table.concat(all, " | ")
  F.check("the advice was read", text:find("TECHNICAL MACHINE", 1, true) ~= nil, text)
  F.check("the advice does not call a TM one-time", not text:find("one-time", 1, true) and not text:find("only once", 1, true), text)
  F.check("the advice does not say a used TM is gone", not text:find("it's gone", 1, true), text)
  F.finish()
end)
