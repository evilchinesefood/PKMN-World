-- Catch-to-PC messages name the right box when a default deposit box is set.
--
-- "Make Default" in the PC's box menu makes new catches start in that box (VAR_DEFAULT_PC_BOX), but
-- the messages kept the box names of the vanilla flow: the box-full line named the box of the last
-- transfer instead of the default box, and the catch-swap line ("It was placed in BOX ...") named
-- the box from before the transfer instead of the one the Pokemon went to.
--
-- The scripted gift line (Common_EventScript_TransferredToPC) had the same box-full fault.
--
-- Setup gives six Bulbasaur through the debug menu. Making BOX3 the default (PC, Move Pokemon, the
-- box title, R, Make Default, back to BOX1 and out) is real input. BOX3 is then filled in RAM and
-- the Celadon Condominiums Eevee is taken with real input, declining the nickname: the box-full
-- line must name BOX3, then BOX4 where Eevee lands. A wild Pidgey (setwildbattle + dowildbattle)
-- is caught with a Master Ball from additem, answering No to "add it to your party?". BOX4 is
-- filled first, because the box-full line shows once until the landing box changes: it must name
-- BOX3, then BOX5 where Pidgey lands.
-- BOX3 is emptied again in RAM and a second Pidgey is caught, answering Yes and sending the sixth
-- Bulbasaur: the line must name BOX3, where that Bulbasaur lands. The throws, the naming screens
-- and every prompt are real input.
--
-- Run via test/overworld/mgba-run.sh test/overworld/lua/DefaultBoxCatchMessages.lua <rom.gba>

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "DefaultBoxCatchMessages")

local PARTY_SIZE, MON = 6, S.Pokemon.size
local PER_BOX, BOX_MON = 30, S.BoxPokemon.size
local BULBASAUR, SPECIES_PIDGEY, SPECIES_EEVEE = 1, 16, 133
local ROOF_ROOM_G, ROOF_ROOM_M, EEVEE_APPROACH = 44, 11, { 7, 4 }
local ITEM_MASTER_BALL = 4
local VAR_DEFAULT_PC_BOX = 0x40F9
local PC_MENU_ROWS, PC_MOVE_MONS, BOX_MENU_MAKE_DEFAULT = 5, 0, 3
local AREA_TITLE = 2
local PARTY_MENU_SLOT = 9   -- struct PartyMenu.slotId
local CH_B, CH_O, CH_X, CH_0, CH_9 = 0xBC, 0xC9, 0xD2, 0xA1, 0xAA

local function party(slot) return S.gParties + slot * MON end
local function storage() return F.r32(S.gPokemonStoragePtr) end
local function boxSlot(box, slot) return storage() + 4 + (box * PER_BOX + slot) * BOX_MON end
local function var(id) return F.r16(F.sb1() + S.SaveBlock1.vars + (id - 0x4000) * 2) end

local function order(p)
  local o = {}
  for i = 0, 3 do o[i] = F.r8(S.sSubstructOffsets + i * 24 + p % 24) * 3 end
  return o
end
local function words(a)
  local key = F.r32(a) ~ F.r32(a + 4)
  local w = {}
  for i = 0, 11 do w[i] = F.r32(a + 32 + i * 4) ~ key end
  return w, order(F.r32(a))
end
local function species(a) local w, o = words(a); return w[o[0]] & 0x7FF end
local function checksumOk(a)
  local w = words(a)
  local sum = 0
  for i = 0, 11 do sum = sum + (w[i] & 0xFFFF) + (w[i] >> 16) end
  return (sum & 0xFFFF) == F.r16(a + 28)
end

local function instantText()
  local a = F.sb2() + S.SaveBlock2.optionsU16
  F.w16(a, (F.r16(a) & ~7) | 3)
end

local function digits(n) n = n - 1; return n // 100, (n // 10) % 10, n % 10 end
local function giveParty(n, sp, level)
  for _ = 1, 3 do
    for off = 0, PARTY_SIZE * MON - 4, 4 do F.w32(S.gParties + off, 0) end
    F.w8(S.gPartiesCount, 0)
    F.dbg(); F.idle(30); F.bOut(4)
    for _ = 1, n do
      F.dbg(); F.sel(3); F.sel(1); F.idle(20)
      F.spin(digits(sp)); F.idle(20)
      F.spin(digits(level)); F.idle(60); F.bOut(4)
    end
    local ok = F.r8(S.gPartiesCount) == n
    for i = 0, n - 1 do ok = ok and checksumOk(party(i)) end
    if ok then return true end
    F.idle(60)
  end
  return false
end

local function menuMax() return F.rs8(S.sMenu + S.Menu.maxCursorPos) end
local function pcMenuLive() return F.ow() and menuMax() == PC_MENU_ROWS - 1 end
local function cursorTo(row)
  for _ = 1, 8 do
    if F.mcur() == row then return true end
    F.press(F.mcur() < row and "Down" or "Up", 2); F.idle(12)
  end
  return F.mcur() == row
end
local function tap(k) F.press(k, 2); F.idle(16) end
local function area() return F.r8(S.sCursorArea) end
local function currentBox() return F.r8(storage()) end

-- PC (debug Access PC), Move Pokemon, box title, R x2, Make Default, L x2, then out to the field.
local function makeBox3Default()
  F.w8(S.sMenu + 2, 0); F.w8(S.sMenu + S.Menu.maxCursorPos, 0)
  F.dbg(); F.idle(60)
  F.press("Down", 3); F.idle(16); F.press("A", 3); F.idle(60)
  F.press("A", 3); F.idle(60)
  for _ = 1, 200 do
    if pcMenuLive() then break end
    F.press("A", 2); F.idle(18)
  end
  if not pcMenuLive() then return false end
  F.idle(30)
  cursorTo(PC_MOVE_MONS); F.press("A", 2); F.idle(150)
  for _ = 1, 6 do
    if area() == AREA_TITLE then break end
    tap("Up")
  end
  for _ = 1, 2 do tap("R"); F.idle(30) end
  F.check("setup: the PC shows BOX3", currentBox() == 2 and area() == AREA_TITLE, "box=" .. currentBox())
  tap("A"); F.idle(10)
  cursorTo(BOX_MENU_MAKE_DEFAULT)
  F.shot("box_menu")
  tap("A"); F.idle(30); F.shot("make_default")
  tap("A"); F.idle(20)
  for _ = 1, 2 do tap("L"); F.idle(30) end
  for _ = 1, 30 do
    if pcMenuLive() then break end
    F.press("B", 2); F.idle(30)
    F.press("Down", 2); F.idle(12); F.press("A", 2); F.idle(60)
  end
  for _ = 1, 10 do
    if F.ow() and menuMax() ~= PC_MENU_ROWS - 1 then break end
    F.press("B", 2); F.idle(30)
  end
  for _ = 1, 6 do F.press("B", 2); F.idle(20) end
  return F.ow()
end

local SCRIPT_BUF = S.gStringVar4 + 960
local function le16(t, v) t[#t + 1] = v & 0xFF; t[#t + 1] = (v >> 8) & 0xFF end
local function runScript(b)
  for i, v in ipairs(b) do F.w8(SCRIPT_BUF + i - 1, v) end
  F.w8(S.sGlobalScriptContext, 0)
  F.w8(S.sGlobalScriptContext + 1, 1)
  F.w32(S.sGlobalScriptContext + 4, 0)
  F.w32(S.sGlobalScriptContext + S.ScriptCtx.scriptPtr, SCRIPT_BUF)
  F.w8(S.sGlobalScriptContextStatus, 0)
end

local function inBattle() return F.cb2() == (S.BattleMainCB2 & ~1) end
local function inPartyMenu() return F.cb2() == (S.CB2_UpdatePartyMenu & ~1) end
local function ctrl(b) return F.r32(S.gBattlerControllerFuncs + b * 4) & ~1 end
local function actionMenu()
  for _, p in ipairs(S.ActionInputFunctions) do if ctrl(0) == (p & ~1) then return true end end
  return false
end
local function atGiveCaughtMon() return F.r32(S.gBattlescriptCurrInstr) == S.BattleScript_GiveCaughtMonAfterNick end

-- Every "BOX<n>" box name in a text buffer (the battle text by default).
local function boxNames(seen, list, a)
  a = a or S.gDisplayedStringBattle
  for i = 0, 300 do
    local c = F.r8(a + i)
    if c == 0xFF then break end
    if c == CH_B and F.r8(a + i + 1) == CH_O and F.r8(a + i + 2) == CH_X then
      local n, j = 0, i + 3
      while F.r8(a + j) >= CH_0 and F.r8(a + j) <= CH_9 do n = n * 10 + F.r8(a + j) - CH_0; j = j + 1 end
      if j > i + 3 and not seen[n] then seen[n] = true; list[#list + 1] = n end
    end
  end
end

-- Throw a Master Ball at a wild Pidgey; addToParty picks the answer to "add it to your party?"
-- and, for Yes, the party slot to send to the PC. Returns the box names the battle text showed.
local function catchPidgey(tag, addToParty, sendSlot)
  local b = { 0x44 }; le16(b, ITEM_MASTER_BALL); le16(b, 1); b[#b + 1] = 0x02   -- additem, end
  runScript(b); F.idle(30)
  local w = { 0xB6 }                                                            -- setwildbattle
  le16(w, SPECIES_PIDGEY); w[#w + 1] = 3; le16(w, 0); le16(w, 0); w[#w + 1] = 0; le16(w, 0)
  w[#w + 1] = 0xB7; w[#w + 1] = 0x02                                            -- dowildbattle, end
  runScript(w)
  local started = false
  for _ = 1, 1500 do
    F.idle(1)
    if inBattle() and F.battlers() >= 2 then started = true; break end
  end
  F.check(tag .. ": a wild Pidgey battle started", started)
  local seen, names, threw, picked = {}, {}, false, false
  for _ = 1, 4000 do
    if inBattle() then boxNames(seen, names) end
    if inPartyMenu() then
      F.idle(40)
      if not picked then
        for _ = 1, 12 do
          local s = F.rs8(S.gPartyMenu + PARTY_MENU_SLOT)
          if s == sendSlot then break end
          F.press(s < sendSlot and "Down" or "Up", 2); F.idle(16)
        end
        picked = true
        F.press("A", 2); F.idle(40); F.press("A", 2); F.idle(60)
      else
        F.press("B", 2); F.idle(20)
      end
    elseif inBattle() then
      if actionMenu() and not threw then
        F.idle(10); F.press("R", 2); F.idle(30); threw = true
      elseif atGiveCaughtMon() and not addToParty then
        F.press("B", 2); F.idle(10)
      else
        F.press("A", 2); F.idle(10)
      end
    elseif F.ow() and threw then
      break
    else
      F.press("Start", 2); F.idle(20); F.press("A", 2); F.idle(40)   -- naming screen: START jumps to OK
    end
  end
  F.idle(40)
  F.check(tag .. ": back on the field after the catch", F.ow() and F.outcome() == 7, "outcome=" .. F.outcome())
  local shown = {}
  for _, n in ipairs(names) do shown[#shown + 1] = "BOX" .. n end
  F.L("  " .. tag .. ": box names shown: " .. table.concat(shown, ", "))
  return names
end

local function boxHolds(box, pred)
  for s = 0, PER_BOX - 1 do if pred(boxSlot(box, s)) then return true end end
  return false
end
local function setBoxFull(box, full)
  for s = 0, PER_BOX - 1 do
    local a = boxSlot(box, s)
    if full then
      for off = 0, BOX_MON - 4, 4 do F.w32(a + off, F.r32(party(0) + off)) end
    else
      for off = 0, BOX_MON - 4, 4 do F.w32(a + off, 0) end
    end
  end
end

F.run(function()
  if not F.boot(100) then F.check("boot to the hub", false); F.finish(); return end
  instantText()
  F.check("setup: the debug Give made six Bulbasaur", giveParty(6, BULBASAUR, 10), "count=" .. F.r8(S.gPartiesCount))
  F.check("setup: BOX3 made the default with real input", makeBox3Default() and var(VAR_DEFAULT_PC_BOX) == 3
    and currentBox() == 0, string.format("default=%d box=%d", var(VAR_DEFAULT_PC_BOX), currentBox()))
  instantText()

  setBoxFull(2, true)
  do
    local tag = "gift"
    F.check(tag .. ": warp to the Celadon Condominiums roof room",
      F.warpTo(0, 4, 4, 0, 1, 1, 0, 0, 1, ROOF_ROOM_G, ROOF_ROOM_M, "roof_room"))
    instantText()
    local seen, names = {}, {}
    if F.leg(EEVEE_APPROACH[1], EEVEE_APPROACH[2]) then
      F.face("Up"); F.press("A", 2); F.idle(30)
      for _ = 1, 120 do
        boxNames(seen, names, S.gStringVar4)
        if F.r8(S.sGlobalScriptContextStatus) == 2 then break end
        F.press("B", 2); F.idle(20)
      end
    end
    F.idle(30)
    F.L("  gift: box names shown: BOX" .. table.concat(names, ", BOX"))
    F.check(tag .. ": the line names BOX3 as full, then BOX4", names[1] == 3 and names[2] == 4,
      "names=" .. table.concat(names, ","))
    F.check(tag .. ": Eevee landed in BOX4", boxHolds(3, function(a) return species(a) == SPECIES_EEVEE end))
  end

  do
    local tag = "BOX3 and BOX4 full"
    setBoxFull(3, true)
    local names = catchPidgey(tag, false)
    F.check(tag .. ": the line names BOX3 as full, then BOX5", names[1] == 3 and names[2] == 5,
      "names=" .. table.concat(names, ","))
    F.check(tag .. ": Pidgey landed in BOX5", boxHolds(4, function(a) return species(a) == SPECIES_PIDGEY end))
  end

  do
    local tag = "swap"
    setBoxFull(2, false)
    local sentPid = F.r32(party(5))
    local names = catchPidgey(tag, true, 5)
    F.check(tag .. ": the sixth Bulbasaur landed in BOX3", boxHolds(2, function(a) return F.r32(a) == sentPid end))
    F.check(tag .. ": the line names BOX3", #names == 1 and names[1] == 3, "names=" .. table.concat(names, ","))
  end

  F.check("no crash", not F.reportCrash("end"))
  F.finish()
end)
