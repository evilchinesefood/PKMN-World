-- Field-poison advice must match OW_POISON_DAMAGE.
--
-- OW_POISON_DAMAGE is GEN_LATEST: poison does no damage outside battle (the step counter that
-- drained HP every four steps is compiled out, src/field_control_avatar.c). Emerald's Petalburg Mart
-- man and Rustboro school notebook, FRLG's Vermilion Pokemon Center man and HnS's Cherrygrove Mart
-- boy still said a poisoned POKéMON loses HP, or faints, while walking.
--
-- The suite poisons a party POKéMON (status written the way a battle leaves it), walks 40 steps with
-- real input and requires its HP and poison unchanged (the rule the advice must match), then talks
-- to the Petalburg, Vermilion and Cherrygrove NPCs with real input. Oracle: their lines, read from
-- gStringVar4, name poison and claim no HP loss or fainting while walking.
local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "FieldPoisonText")

local HUB_GROUP = 100
local PETALBURG_MART_G, PETALBURG_MART_M = 8, 5
local VERMILION_PC_G, VERMILION_PC_M = 43, 1
local CHERRYGROVE_MART_G, CHERRYGROVE_MART_M = 77, 1
local CONTEXT_SHUTDOWN = 2
local PARTY_SIZE = 6
local MON = S.Pokemon.size
local STATUS1_POISON = 1 << 3

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

local function zeroParty()
  for off = 0, PARTY_SIZE * MON - 4, 4 do F.w32(S.gParties + off, 0) end
  F.w8(S.gPartiesCount, 0)
end
local function digits(n) n = n - 1; return n // 100, (n // 10) % 10, n % 10 end
local function giveMon(species, level)
  for _ = 1, 3 do
    zeroParty()
    F.dbg(); F.idle(30); F.bOut(4)
    F.dbg(); F.sel(3); F.sel(1); F.idle(20)
    F.spin(digits(species)); F.idle(20)
    F.spin(digits(level)); F.idle(60); F.bOut(4)
    if F.r8(S.gPartiesCount) == 1 then return true end
    F.idle(60)
  end
  return false
end

local function talkUntilControl(dir, tag)
  if dir then F.face(dir) end
  local before = decode(S.gStringVar4)
  F.press("A", 2)
  local all = { [before] = true }
  for i = 1, 900 do
    if i % 8 == 0 and F.reportCrash(tag) then break end
    local t = decode(S.gStringVar4)
    if not all[t] then
      all[t] = true; all[#all + 1] = t; F.L("  " .. tag .. ": " .. t)
      F.idle(20); F.shot(tag)
    end
    -- A press on the final movement frame can be ignored. Allow another
    -- input window before giving up on an interaction that produced no text.
    if i > 30 and hasControl() and (#all > 0 or i > 100) then break end
    if i % 40 == 0 then F.press("A", 2) else F.idle(1) end
  end
  backToControl()
  return table.concat(all, " | ")
end

local function hp() return F.r16(S.gParties + S.Pokemon.hp) end
local function poisoned() return (F.r32(S.gParties + S.Pokemon.status) & STATUS1_POISON) ~= 0 end

F.run(function()
  if not F.boot(HUB_GROUP) then F.check("boot to the hub", false); F.finish(); return end
  instantText()
  F.check("give a party POKéMON", giveMon(1, 20))
  F.w32(S.gParties + S.Pokemon.status, STATUS1_POISON)

  F.check("warp to the Petalburg Mart", F.warpTo(0, 0, 8, 0, 0, 5, 0, 0, 0, PETALBURG_MART_G, PETALBURG_MART_M, "petalburg_mart"))
  instantText()
  local hp0 = hp()
  local steps = 0
  F.leg(5, 7)
  for _ = 1, 4 do
    for _, x in ipairs({ 10, 5 }) do
      local x0 = F.pos()
      if F.leg(x, 7) then steps = steps + math.abs(x - x0) end
    end
  end
  F.check("walked 40 steps with a poisoned POKéMON", steps >= 40, "steps=" .. steps)
  F.check("poison took no HP outside battle", hp() == hp0 and hp0 > 0, string.format("hp %d -> %d", hp0, hp()))
  F.check("the POKéMON is still poisoned", poisoned())

  F.check("walk to the Petalburg Mart man", F.route({ { 9, 7 }, { 9, 5 } }, "petalburg_man"), where())
  local t = talkUntilControl("Up", "petalburg_man")
  F.check("Petalburg: the poison advice was read", t:find("ANTIDOTES", 1, true) ~= nil, t)
  F.check("Petalburg: claims no HP lost while walking", not t:find("walk around with a poisoned", 1, true)
    and not t:find("lose HP until it faints", 1, true), t)

  F.check("warp to the Vermilion Pokemon Center", F.warpTo(0, 4, 3, 0, 0, 1, 0, 0, 0, VERMILION_PC_G, VERMILION_PC_M, "vermilion_pc"))
  instantText()
  -- Approach facing his patrol from above. Poll the actual object each frame so
  -- he cannot walk off during the turn-and-wait that fixed-position NPCs allow.
  local reached = F.route({ { 6, 7 }, { 4, 7 }, { 4, 6 }, { 4, 7 } }, "vermilion_man")
  F.check("walk to the Vermilion man", reached, where())
  t = ""
  if reached then
    for _ = 1, 1800 do
      for _, obj in ipairs(F.objdump()) do
        local addr = S.gObjectEvents + obj.i * S.ObjectEvent.stride
        if F.r8(addr + S.ObjectEvent.localId) == 2 and obj.x == 4 and obj.y == 8 then
          t = talkUntilControl(nil, "vermilion_man")
          break
        end
      end
      if t ~= "" then break end
      F.idle(1)
    end
  end
  F.check("Vermilion: the poison story was read", t:find("was poisoned", 1, true) ~= nil, t)
  F.check("Vermilion: no fainting while walking", not t:find("while we were walking", 1, true), t)

  F.check("warp to the Cherrygrove Mart", F.warpTo(0, 7, 7, 0, 0, 1, 0, 0, 0, CHERRYGROVE_MART_G, CHERRYGROVE_MART_M, "cherrygrove_mart"))
  instantText()
  F.check("walk to the Cherrygrove boy", F.route({ { 4, 5 } }, "cherrygrove_boy"), where())
  t = talkUntilControl("Left", "cherrygrove_boy")
  F.check("Cherrygrove: the poison story was read", t:find("poisoned my", 1, true) ~= nil, t)
  F.check("Cherrygrove: no fainting from walking on", not t:find("kept going", 1, true), t)
  F.finish()
end)
