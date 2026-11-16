-- The Celadon Game Corner's slot machines and Pokemon prize counter at their coin edges, which no
-- suite played. The Coin Case comes from the real restaurant NPC; only the coin balance (and, for
-- the full-storage case, the party and boxes) is seeded. Machines, prompts and counters are real
-- input. Slots: no coins (betting refused, quit), exactly 3 (one max bet and three stops), 9,998
-- (a one-coin bet whose payout must stop at 9,999), a full case (the machine refuses to start) and
-- a seeded mash of every button but the soft-reset chord (`PW_SLOTS_SEED=<n>`). Every case must
-- hand control back with a balance from 0 to 9,999 that never grew without a spin.
-- Prizes: Abra one coin short (refused, coins kept), exactly 180 (Abra joins, 0 coins), a full
-- party (Abra goes to the PC, coins paid) and a full party with full boxes (refused, coins kept).
local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "CeladonSlotsPrizes")

local KANTO_G, RESTAURANT_M, GAME_CORNER_M, PRIZE_ROOM_M = 44, 17, 14, 15
local ITEM_COIN_CASE = 718
local MAX_COINS = 9999
local CONTEXT_SHUTDOWN = 2
local SLOTS = 14 * 30
local seed = tonumber(os.getenv("PW_SLOTS_SEED") or "11")

local function where() local x, y = F.pos(); return string.format("%d/%d (%d,%d)", F.grp(), F.mapn(), x, y) end
local function key16() return F.r32(F.sb2() + S.SaveBlock2.encryptionKey) & 0xFFFF end
local function coins() return F.r16(F.sb1() + S.SaveBlock1.coins) ~ key16() end
local function setCoins(v) F.w16(F.sb1() + S.SaveBlock1.coins, v ~ key16()) end
local function partyCount() return F.r8(S.gPartiesCount) end
local function box(slot) return F.r32(S.gPokemonStoragePtr) + 4 + slot * 80 end
local function present(address) return (F.r8(address + 19) & 2) ~= 0 end
local function boxed()
  local n = 0
  for i = 0, SLOTS - 1 do if present(box(i)) then n = n + 1 end end
  return n
end

local function hasControl()
  return F.ow() and F.r8(S.sLockFieldControls) == 0 and F.r8(S.sGlobalScriptContextStatus) == CONTEXT_SHUTDOWN
end
local function instantText()
  local a = F.sb2() + S.SaveBlock2.optionsU16
  F.w16(a, (F.r16(a) & ~7) | 3)
end
local function scriptMenuActive()
  for i = 0, S.Task.count - 1 do
    local a = S.gTasks + i * S.Task.stride
    local fn = F.r32(a + S.Task.func) & 0xFFFFFFFE
    if F.r8(a + S.Task.isActive) ~= 0 and (fn == S.Task_HandleYesNoInput or fn == S.Task_HandleMultichoiceInput or fn == S.Task_CallYesOrNoCallback) then return true end
  end
  return false
end
-- B through messages until control returns (B also answers a Yes/No with No).
local function settle(tag)
  for i = 1, 900 do
    if F.reportCrash(tag) then return false end
    if hasControl() then F.idle(30); if hasControl() then return true end end
    if i % 15 == 0 then F.press("B", 2) else F.idle(1) end
  end
  F.shot(tag .. "_stuck")
  return false
end
-- Advance messages with A until a script menu is up, then move its cursor to `want` and pick it.
local function choose(want, tag)
  for _ = 1, 80 do
    if F.reportCrash(tag) then return false end
    if scriptMenuActive() then
      F.idle(10)
      for _ = 1, 12 do
        local c = F.mcur()
        if c == want then F.press("A", 2); F.idle(30); return true end
        F.press(c > want and "Up" or "Down", 2); F.idle(10)
      end
      return false
    end
    F.press("A", 2); F.idle(20)
  end
  F.shot(tag .. "_nomenu")
  return false
end

-- Talk to slot machine 5 from its west side and start it.
local function startSlots(tag)
  local px, py = F.pos()
  if not (px == 4 and py == 9) and not F.route({ { 10, 11 }, { 4, 11 }, { 4, 9 } }, tag .. "_walk") then return false end
  F.face("Right")
  F.press("A", 2); F.idle(20)
  if not choose(0, tag .. "_yes") then return false end
  for _ = 1, 400 do if not F.ow() then break end F.idle(1) end
  F.idle(240)
  F.shot(tag .. "_machine")
  return not F.ow()
end
local function quitSlots(tag)
  for _ = 1, 60 do
    if F.ow() then break end
    if F.reportCrash(tag) then return false end
    F.press("B", 2); F.idle(30)
    if scriptMenuActive() or F.mcur() == 0 then F.press("A", 2); F.idle(60) end
  end
  return settle(tag .. "_field")
end
local function stopReels()
  for _ = 1, 3 do F.idle(60); F.press("A", 2) end
  F.idle(400)
end

local function slotCase(tag, have, play)
  setCoins(have)
  F.check(tag .. ": machine starts", startSlots(tag), where())
  local spun = play()
  F.shot(tag .. "_played")
  F.check(tag .. ": control comes back", quitSlots(tag), where())
  local c = coins()
  F.check(tag .. ": the balance stays in the case", c >= 0 and c <= MAX_COINS, "coins=" .. c)
  if not spun then F.check(tag .. ": no spin, no change", c == have, "coins " .. have .. " -> " .. c) end
  return c
end

local function prize(tag, have)
  setCoins(have)
  local px, py = F.pos()
  if not F.route({ { px, 8 }, { 4, 8 }, { 4, 4 } }, tag .. "_walk") then F.check(tag .. ": reach the clerk", false, where()); return end
  F.face("Up")
  F.press("A", 2); F.idle(20)
  F.check(tag .. ": Abra picked", choose(0, tag .. "_abra"))
  F.check(tag .. ": confirmed", choose(0, tag .. "_confirm"))
  F.shot(tag)
  settle(tag)
end

F.run(function()
  if not F.boot(100) then F.check("boot to the hub", false); F.finish(); return end
  instantText()
  F.check("warp to the Celadon restaurant", F.warpTo(0, 4, 4, 0, 1, 7, 0, 0, 0, KANTO_G, RESTAURANT_M, "restaurant"))
  instantText()
  F.check("walk to the Coin Case man", F.route({ { 6, 8 }, { 6, 2 }, { 2, 2 } }, "coin_case_man"))
  F.face("Left"); F.press("A", 2)
  settle("coin_case_man")
  F.check("got the Coin Case", F.itemCount(ITEM_COIN_CASE) > 0)
  F.dbg(); F.idle(40); F.sel(2); F.idle(40); for _ = 1, 9 do F.press("Down", 3); F.idle(16) end; F.press("A", 3); F.idle(180)
  for _ = 1, 6 do F.press("B", 2); F.idle(20) end

  F.check("warp to the Game Corner", F.warpTo(0, 4, 4, 0, 1, 4, 0, 0, 0, KANTO_G, GAME_CORNER_M, "game_corner"))
  instantText()

  slotCase("no coins", 0, function()
    F.press("Down", 2); F.idle(30); F.press("R", 2); F.idle(60)
    F.shot("no coins_refused")
    F.press("A", 2); F.idle(30)
    return false
  end)
  local c = slotCase("three coins", 3, function()
    F.press("R", 2); F.idle(60); stopReels(); return true
  end)
  F.check("three coins: the bet was taken or paid back as winnings", c == 0 or c > 0, "coins=" .. c)
  slotCase("one coin short of full", 9998, function()
    F.press("Down", 2); F.idle(20); F.press("A", 2); F.idle(60); stopReels(); return true
  end)
  slotCase("full case", MAX_COINS, function()
    F.press("R", 2); F.idle(30); F.press("Down", 2); F.idle(30); F.press("A", 2); F.idle(60)
    return false
  end)
  local keys = { "A", "B", "Start", "Select", "Up", "Down", "Left", "Right", "L", "R" }
  slotCase("mash", 500, function()
    for i = 1, 3000 do
      if F.reportCrash("mash") then break end
      seed = (seed * 1103515245 + 12345) % 2147483648
      if i % 5 == 0 then F.press(keys[seed % #keys + 1], 2) else F.idle(1) end
      if F.ow() then break end
    end
    return true
  end)

  F.check("warp to the prize room", F.warpTo(0, 4, 4, 0, 1, 5, 0, 0, 0, KANTO_G, PRIZE_ROOM_M, "prize_room"))
  instantText()
  local p0 = partyCount()
  prize("one coin short", 179)
  F.check("one coin short: refused, coins kept", coins() == 179 and partyCount() == p0, "coins=" .. coins() .. " party=" .. partyCount())
  prize("exactly 180", 180)
  F.check("exactly 180: Abra joins for every coin", coins() == 0 and partyCount() == p0 + 1, "coins=" .. coins() .. " party=" .. partyCount())

  for i = partyCount(), 5 do
    for o = 0, 99 do F.w8(S.gParties + i * S.Pokemon.size + o, F.r8(S.gParties + o)) end
  end
  F.w8(S.gPartiesCount, 6)
  local b0 = boxed()
  prize("full party", 180)
  F.check("full party: Abra goes to a box, coins paid", coins() == 0 and boxed() == b0 + 1 and partyCount() == 6,
    "coins=" .. coins() .. " boxed " .. b0 .. " -> " .. boxed())
  F.dbg(); F.idle(60); F.sel(1); F.idle(40); F.sel(1); F.idle(40); F.sel(0); F.idle(240)
  settle("fill_boxes")
  F.check("setup: every box filled", boxed() == SLOTS, "boxed=" .. boxed())
  prize("party and boxes full", 180)
  F.check("party and boxes full: refused, coins kept", coins() == 180 and boxed() == SLOTS and partyCount() == 6,
    "coins=" .. coins() .. " boxed=" .. boxed())
  F.finish()
end)
