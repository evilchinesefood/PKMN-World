-- Cancelling the left Pokemon's Bag choice from the right Pokemon's action menu must give back
-- only what the Bag took. In a trainer battle a thrown Poke Ball is not consumed
-- (B_TRY_CATCH_TRAINER_BALL >= GEN_4: ItemUseInBattle_BagMenu leaves it in the Bag), but the
-- cancel-partner refund in HandleInputChooseAction (src/battle_controller_player.c) adds the item
-- back whenever it is consumable, so every BAG -> ball -> B round grew the stack by one.
--
-- The trainer double comes from the debug Trainers menu (Trainer 1 + Trainer 2, one Pokemon each).
-- The player's two Pokemon come from createmon, as givemon makes them. Turn 1 is real input: the
-- left Pokemon uses Psychic on a foe, the right one Splash, so one foe faints and a Poke Ball may
-- be thrown. Then, with real input: BAG, the Balls pocket, the ball, USE; on the right Pokemon's
-- action menu, B. The ball count must not change, round after round. A Potion used on the left
-- Pokemon and cancelled the same way must still come back (the refund itself stays).
--
-- Run via test/overworld/mgba-run.sh test/overworld/lua/TrainerDoubleBallRefund.lua <rom>

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "TrainerDoubleBallRefund")

local PARTY_SIZE = 6
local CONTEXT_RUNNING = 0
local SPECIES_MEWTWO = 150
local ITEM_POKE_BALL, ITEM_MASTER_BALL, ITEM_POTION = 1, 4, 28
local MOVE_PSYCHIC, MOVE_SPLASH = 94, 150
local B_DOUBLE, B_TRAINER = 1 << 0, 1 << 3
local BM = S.BattlePokemon
local ROUNDS = 3

local function inBattle() return F.cb2() == (S.BattleMainCB2 & ~1) end
local function ctrl(b) return F.r32(S.gBattlerControllerFuncs + b * 4) & ~1 end
local function isAction(b)
  for _, p in ipairs(S.ActionInputFunctions) do if ctrl(b) == (p & ~1) then return true end end
  return false
end
local function isMove(b) return ctrl(b) == (S.HandleInputChooseMove & ~1) end
local function isTarget(b) return ctrl(b) == (S.HandleInputChooseTarget & ~1) end
local function bhp(b) return F.r16(S.gBattleMons + b * BM.size + BM.hp) end
local function partyCount() return F.r8(S.gPartiesCount) end
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
local function giveMon(species, level, moves)
  local b = { 0x23 }; le32(b, S.ScrCmd_createmon | 1)
  b[#b + 1] = 0; b[#b + 1] = PARTY_SIZE
  le16(b, species); le16(b, level)
  le32(b, (1 << 17) | (1 << 18) | (1 << 19) | (1 << 20))
  for k = 1, 4 do le16(b, moves[k] or 0) end
  b[#b + 1] = 0x02
  local before = partyCount()
  runScript(b); F.idle(20)
  return partyCount() == before + 1
end
local function clearParty()
  for off = 0, PARTY_SIZE * S.Pokemon.size - 4, 4 do F.w32(S.gParties + off, 0) end
  F.w8(S.gPartiesCount, 0)
end
local function qty(id)
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

local function tapDown(n) for _ = 1, n do F.press("Down", 3); F.idle(16) end end
local function startTrainerDouble()
  F.dbg(); F.idle(80)
  tapDown(6); F.press("A", 3); F.idle(80)
  tapDown(1); F.press("A", 3); F.idle(50)
  F.press("Up", 3); F.idle(16)
  F.press("A", 3); F.idle(80)
  tapDown(2); F.press("A", 3); F.idle(50)
  F.press("Up", 3); F.idle(16)
  F.press("Up", 3); F.idle(16)
  F.press("A", 3); F.idle(80)
  tapDown(4); F.press("A", 3); F.idle(30)
  F.press("Down", 3); F.idle(16)
  F.press("A", 3)
  return waitFor(function() return inBattle() and F.battlers() >= 4 end, 1500)
end

local function steer(b, want)
  for _ = 1, 8 do
    local cur = F.r8(S.gActionSelectionCursor + b)
    if cur == want then return true end
    local key
    if (cur & 1) ~= (want & 1) then key = (cur & 1) < (want & 1) and "Right" or "Left"
    else key = (cur & 2) < (want & 2) and "Down" or "Up" end
    F.press(key, 2); F.idle(10)
  end
  return F.r8(S.gActionSelectionCursor + b) == want
end

local function moveCursorTo(b, want)
  for _ = 1, 8 do
    local cur = F.r8(S.gMoveSelectionCursor + b)
    if cur == want then return true end
    local key
    if (cur & 1) ~= (want & 1) then key = (cur & 1) < (want & 1) and "Right" or "Left"
    else key = (cur & 2) < (want & 2) and "Down" or "Up" end
    F.press(key, 2); F.idle(10)
  end
  return F.r8(S.gMoveSelectionCursor + b) == want
end

local function waitAction(b, n)
  for _ = 1, n or 900 do
    if isAction(b) then F.idle(20); return true end
    if not (isAction(0) or isAction(2) or isMove(0) or isMove(2) or isTarget(0) or isTarget(2)) then
      F.press("A", 2); F.idle(4)
    else
      F.idle(1)
    end
  end
  return isAction(b)
end

local function fight(b, slot)
  steer(b, 0); F.press("A", 2)
  waitFor(function() return isMove(b) end, 120); F.idle(10)
  moveCursorTo(b, slot); F.press("A", 2); F.idle(20)
  if isTarget(b) then F.press("A", 2); F.idle(20) end
end

-- BAG -> pocket `pocket` (Right until gBagPosition.pocket says so) -> A on the first row -> A on
-- USE (-> A on the panel's first slot for a party item).
local POCKET_ITEMS, POCKET_BALLS = 0, 1
local function bagPocket() return F.r8(S.gBagPosition + 5) end
local function useFromBag(tag, pocket, panel)
  steer(0, 1); F.press("A", 2)
  waitFor(function() return not inBattle() end, 200)
  F.idle(90)
  for _ = 1, 6 do
    if bagPocket() == pocket then break end
    F.press("Right", 2); F.idle(30)
  end
  F.shot(tag .. "_bag")
  F.press("A", 2); F.idle(40)
  F.press("A", 2); F.idle(40)
  if panel then F.shot(tag .. "_panel"); F.press("A", 2) end
  return waitFor(inBattle, 300)
end

F.run(function()
  if not F.boot(100) then F.check("boot", false); F.finish(); return end
  instantText(); fastBattles()
  F.dbg(); F.idle(30); F.bOut(4)
  local badge = 0x956 -- Hoenn BADGE08_GET makes the level-80 party obey in the hub.
  local badgeByte = F.sb1() + S.SaveBlock1.flags + badge // 8
  F.w8(badgeByte, F.r8(badgeByte) | (1 << (badge % 8)))
  clearParty()
  F.check("setup: two Pokemon", giveMon(SPECIES_MEWTWO, 80, { MOVE_PSYCHIC, MOVE_SPLASH })
    and giveMon(SPECIES_MEWTWO, 80, { MOVE_PSYCHIC, MOVE_SPLASH }))
  addItem(ITEM_POKE_BALL, 10)
  addItem(ITEM_POTION, 5)
  F.check("trainer double started", startTrainerDouble())
  local fl = F.battleFlags()
  F.check("it is a trainer double", (fl & B_DOUBLE) ~= 0 and (fl & B_TRAINER) ~= 0, string.format("flags=%X", fl))

  F.check("turn 1: left action menu", waitAction(0))
  fight(0, 0)
  F.check("turn 1: right action menu", waitAction(2, 300))
  fight(2, 1)
  F.check("turn 2: left action menu", waitAction(0, 2400))
  local foesUp = (bhp(1) > 0 and 1 or 0) + (bhp(3) > 0 and 1 or 0)
  F.check("one foe left on the field", foesUp == 1, string.format("hp1=%d hp3=%d", bhp(1), bhp(3)))
  F.shot("one_foe_left")

  local balls0 = qty(ITEM_POKE_BALL)
  local grew = {}
  for r = 1, ROUNDS do
    local ok = useFromBag("ball" .. r, POCKET_BALLS, false)
    F.check("round " .. r .. ": the ball was accepted", ok)
    local onRight = waitAction(2, 300)
    F.check("round " .. r .. ": right action menu", onRight)
    F.shot("ball" .. r .. "_right_menu")
    F.press("B", 2)
    F.check("round " .. r .. ": B went back to the left Pokemon", waitAction(0, 300))
    grew[#grew + 1] = qty(ITEM_POKE_BALL)
  end
  local last = grew[#grew]
  F.check("cancelling a ball choice gives back no extra balls", last == balls0,
    string.format("start=%d after rounds=%s", balls0, table.concat(grew, ",")))

  -- Control: a Potion on the hurt left Pokemon is taken by the Bag, so the cancel gives it back.
  local injuredHp = bhp(0) // 2
  F.w16(S.gBattleMons + BM.hp, injuredHp)
  F.w16(S.gParties + S.Pokemon.hp, injuredHp)
  local pot0 = qty(ITEM_POTION)
  local ok = useFromBag("potion", POCKET_ITEMS, true)
  F.check("control: the Potion was accepted", ok)
  F.check("control: the Bag took the Potion", qty(ITEM_POTION) == pot0 - 1, string.format("%d -> %d", pot0, qty(ITEM_POTION)))
  F.check("control: right action menu", waitAction(2, 300))
  F.press("B", 2)
  F.check("control: back to the left Pokemon", waitAction(0, 300))
  F.check("control: the cancelled Potion came back", qty(ITEM_POTION) == pot0, string.format("%d -> %d", pot0, qty(ITEM_POTION)))

  -- The ball turn itself: blocked by the trainer, not consumed.
  local b1 = qty(ITEM_POKE_BALL)
  F.check("thrown: the ball was accepted", useFromBag("thrown", POCKET_BALLS, false))
  F.check("thrown: right action menu", waitAction(2, 300))
  fight(2, 1)
  F.check("thrown: next turn", waitAction(0, 2400))
  F.check("thrown: the blocked ball stays in the Bag", qty(ITEM_POKE_BALL) == b1, string.format("%d -> %d", b1, qty(ITEM_POKE_BALL)))
  F.shot("after_throw")
  F.check("no crash", not F.reportCrash("end"))
  F.finish()
end)
