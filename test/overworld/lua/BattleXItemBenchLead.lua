-- X items and Dire Hit from the in-battle Bag in a single battle must work on whichever Pokemon is
-- on the field, not only when it sits in party slot 0 or 1.
--
-- In a single battle ItemMenu_UseInBattle (src/swsh_item_menu.c) sends an ITEM_USE_BATTLER item to
-- ItemUseInBattle_BagMenu (src/item_use.c), which checks it with CannotUseItemsInBattle. That
-- check reads gPartyMenu.slotId as a battle position (0 left, 1 right; anything else is "not on
-- the field") and refuses stat items for any other value.
--
-- Each case builds a party with createmon (as givemon does), starts a wild Magikarp battle with
-- setwildbattle + dowildbattle, and uses the item with real input: BAG on the action menu, A on
-- the item, A on USE. The field Pokemon's stat stage must rise and one item must leave the Bag.
-- Cases: the lead in slot 0 (control); slots 0 and 1 fainted so slot 2 leads, as a party leaves
-- a lost fight (X Attack, X Speed, and Dire Hit, which is checked by the Bag accepting and spending
-- it); and a real in-battle switch (POKEMON, slot 4, Shift) before the item.
--
-- Run via test/overworld/mgba-run.sh test/overworld/lua/BattleXItemBenchLead.lua <rom>

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "BattleXItemBenchLead")

local PARTY_SIZE = 6
local CONTEXT_RUNNING = 0
local SPECIES_MAGIKARP, SPECIES_ZIGZAGOON = 129, 263
local ITEM_X_ATTACK, ITEM_X_SPEED, ITEM_DIRE_HIT = 121, 125, 127
local MOVE_TACKLE, MOVE_SPLASH = 33, 150
local STAGE_ATK, STAGE_SPEED, DEFAULT_STAGE = 1, 3, 6
local BM = S.BattlePokemon
local STAT_STAGES = 24   -- struct BattlePokemon: statStages[] follows the u32 IV word at 20 (pp at 37 = 24 + 8 + 2 + 3)

local function inBattle() return F.cb2() == (S.BattleMainCB2 & ~1) end
local function ctrl(b) return F.r32(S.gBattlerControllerFuncs + b * 4) & ~1 end
local function isAction()
  for _, p in ipairs(S.ActionInputFunctions) do if ctrl(0) == (p & ~1) then return true end end
  return false
end
local function partyAddr(s) return S.gParties + s * S.Pokemon.size end
local function partyCount() return F.r8(S.gPartiesCount) end
local function stage(stat) return F.rs8(S.gBattleMons + STAT_STAGES + stat) end
local function partyIndex(b) return F.r16(S.gBattlerPartyIndexes + b * 2) end
local function waitFor(pred, n) for _ = 1, n or 300 do if pred() then return true end F.idle(1) end return pred() end

local function options() return F.sb2() + S.SaveBlock2.optionsU16 end
local function instantText() F.w16(options(), (F.r16(options()) & ~7) | 3) end
local function fastBattles() F.w16(options(), F.r16(options()) | (1 << 9) | (1 << 10)) end

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
local function addItem(id, qty)
  local b = { 0x44 }; le16(b, id); le16(b, qty); b[#b + 1] = 0x02
  runScript(b); F.idle(10)
end
local function giveMon(species, level)
  local b = { 0x23 }; le32(b, S.ScrCmd_createmon | 1)
  b[#b + 1] = 0; b[#b + 1] = PARTY_SIZE
  le16(b, species); le16(b, level)
  le32(b, (1 << 17) | (1 << 18) | (1 << 19) | (1 << 20))
  for _, m in ipairs({ MOVE_TACKLE, 0, 0, 0 }) do le16(b, m) end
  b[#b + 1] = 0x02
  local before = partyCount()
  runScript(b); F.idle(20)
  return partyCount() == before + 1
end

local function clearParty()
  for off = 0, PARTY_SIZE * S.Pokemon.size - 4, 4 do F.w32(S.gParties + off, 0) end
  F.w8(S.gPartiesCount, 0)
end

local function tapDown(n) for _ = 1, n do F.press("Down", 3); F.idle(16) end end
local function clearBag()
  F.dbg(); F.idle(40)
  tapDown(1); F.press("A", 3); F.idle(50)
  tapDown(2); F.press("A", 3); F.idle(120)
  for _ = 1, 8 do F.press("B", 3); F.idle(18) end
end

local function startWild()
  local b = { 0xB6 }; le16(b, SPECIES_MAGIKARP); b[#b + 1] = 5; le16(b, 0)
  le16(b, 0); b[#b + 1] = 0; le16(b, 0)   -- no second species
  b[#b + 1] = 0xB7; b[#b + 1] = 0x02
  runScript(b)
  return waitFor(function() return inBattle() and F.battlers() >= 2 end, 1500)
end

local function toAction(budget)
  for _ = 1, budget or 600 do
    if isAction() then F.idle(20); return true end
    F.press("A", 2); F.idle(6)
  end
  return isAction()
end

local function steer(want)
  for _ = 1, 8 do
    local cur = F.r8(S.gActionSelectionCursor)
    if cur == want then return true end
    local key
    if (cur & 1) ~= (want & 1) then key = (cur & 1) < (want & 1) and "Right" or "Left"
    else key = (cur & 2) < (want & 2) and "Down" or "Up" end
    F.press(key, 2); F.idle(10)
  end
  return F.r8(S.gActionSelectionCursor) == want
end

local function count(id)
  local key = F.r32(F.sb2() + S.SaveBlock2.encryptionKey) & 0xFFFF
  local n = 0
  for p = 0, 4 do
    local ptr = F.r32(S.gBagPockets + p * S.BagPocket.stride)
    local cap = F.pocketCap(p)
    if ptr >= 0x02000000 and ptr < 0x02040000 and cap > 0 and cap < 400 then
      for s = 0, cap - 1 do
        if F.r16(ptr + s * 4) == id then n = n + (F.r16(ptr + s * 4 + 2) ~ key) end
      end
    end
  end
  return n
end

-- BAG -> A on the first Items row -> A on USE. Returns once the battle screen is back or the Bag
-- has had time to print its refusal.
local function useFirstItem(tag)
  steer(1); F.press("A", 2)
  local left = waitFor(function() return not inBattle() end, 200)
  F.idle(90)
  F.shot(tag .. "_bag")
  F.press("A", 2); F.idle(40)
  F.shot(tag .. "_context")
  F.press("A", 2)
  local back = waitFor(inBattle, 240)
  if not back then F.idle(40); F.shot(tag .. "_refused") end
  return left, back
end

local function leaveBagAndRun()
  for _ = 1, 30 do
    if inBattle() then break end
    F.press("B", 2); F.idle(20)
  end
  waitFor(inBattle, 300)
end

local function finishBattle()
  for _ = 1, 2400 do
    if F.ow() then return true end
    if isAction() then steer(3) end
    F.press("A", 2); F.idle(6)
  end
  return F.ow()
end

local function case(name, item, stat, buildParty, beforeItem, wantIndex)
  F.L("== " .. name)
  clearParty()
  buildParty()
  clearBag()
  addItem(item, 3)
  local before = count(item)
  F.check(name .. ": battle started", startWild())
  F.check(name .. ": action menu", toAction())
  if beforeItem then beforeItem(name) end
  F.check(name .. ": field Pokemon is party slot " .. wantIndex, partyIndex(0) == wantIndex,
    "index=" .. partyIndex(0))
  local s0 = stat and stage(stat) or 0
  local left, back = useFirstItem(name)
  F.check(name .. ": the Bag opened", left)
  F.check(name .. ": the item was accepted (Bag closed back to the battle)", back)
  if not back then leaveBagAndRun() end
  if stat then
    local acted = waitFor(function() return stage(stat) ~= s0 end, 900)
    F.check(name .. ": stat stage rose", acted and stage(stat) > s0,
      string.format("stage %d -> %d", s0, stage(stat)))
  else
    waitFor(isAction, 900)
  end
  F.shot(name .. "_after")
  F.check(name .. ": one item spent", count(item) == before - 1,
    string.format("%d -> %d", before, count(item)))
  F.check(name .. ": back to the field", finishBattle())
  F.check(name .. ": no crash", not F.reportCrash(name))
end

local function faint(slot) F.w16(partyAddr(slot) + S.Pokemon.hp, 0) end

local function switchTo(slot)
  return function(name)
    steer(2); F.press("A", 2)
    waitFor(function() return not inBattle() end, 200); F.idle(90)
    for _ = 1, slot do F.press("Down", 2); F.idle(12) end
    F.shot(name .. "_party")
    F.press("A", 2); F.idle(40)
    F.shot(name .. "_party_action")
    F.press("A", 2)
    F.check(name .. ": switch accepted", waitFor(inBattle, 300))
    F.check(name .. ": action menu after the switch", toAction(900))
  end
end

F.run(function()
  if not F.boot(100) then F.check("boot", false); F.finish(); return end
  instantText(); fastBattles()
  F.dbg(); F.idle(30); F.bOut(4)

  local function three() for _ = 1, 3 do giveMon(SPECIES_ZIGZAGOON, 30) end end
  local function five() for _ = 1, 5 do giveMon(SPECIES_ZIGZAGOON, 30) end end

  case("xattack_slot0", ITEM_X_ATTACK, STAGE_ATK, three, nil, 0)
  case("xattack_slot2_after_faints", ITEM_X_ATTACK, STAGE_ATK, function() three(); faint(0); faint(1) end, nil, 2)
  case("xspeed_slot2_after_faints", ITEM_X_SPEED, STAGE_SPEED, function() three(); faint(0); faint(1) end, nil, 2)
  case("direhit_slot2_after_faints", ITEM_DIRE_HIT, nil, function() three(); faint(0); faint(1) end, nil, 2)
  case("xattack_after_switch_to_slot4", ITEM_X_ATTACK, STAGE_ATK, five, switchTo(4), 4)
  F.finish()
end)
