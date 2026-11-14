-- Money and items under adversarial play: the wallet at 0 and at the 999,999 cap, the hub mart's
-- buy and sell paths at their edges, mashing the buy list at Instant text, trainer prize money into
-- a full wallet, whiteouts at every Money Loss rate with wallets of 0 to 3, and the Mauville Game
-- Corner coin desk with a nearly full Coin Case. Every amount is read from RAM, and each prize or
-- loss is also matched against the number the battle message printed.
--
-- Discrimination: with the sell clamp in src/swsh_item_menu.c reverted, the three over-the-cap
-- sell scenarios fail (ten Nuggets go for 9,999); with BuyGameCornerCoins reverted to the scripts'
-- full-block charge, "coins near full" pays 100,000 for one coin.
--
-- Run via test/overworld/mgba-run.sh test/overworld/lua/EconomyStress.lua <rom>
-- PW_ECON_ONLY=<text> (runner --env) runs only the scenarios whose tag contains <text>.

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "EconomyStress")

local HUB_GROUP = 100
local ONLY = os.getenv("PW_ECON_ONLY")
local MAX_MONEY = 999999

local ITEM_GREAT_BALL, ITEM_ULTRA_BALL, ITEM_PREMIER_BALL, ITEM_NUGGET = 2, 3, 5, 135
local PRICE = { [ITEM_GREAT_BALL] = 600, [ITEM_NUGGET] = 20000 }
local POCKET_ITEMS, POCKET_BALLS, POCKET_KEY = 0, 1, 4
local ITEM_COIN_CASE = 718

-- ---- RAM helpers -----------------------------------------------------------------------------
local function key16() return F.r32(F.sb2() + S.SaveBlock2.encryptionKey) & 0xFFFF end
local function setMoney(v) F.w32(F.sb1() + S.SaveBlock1.money, v ~ F.r32(F.sb2() + S.SaveBlock2.encryptionKey)) end

local function pocket(p)
  local ptr = F.r32(S.gBagPockets + p * S.BagPocket.stride)
  return ptr, F.pocketCap(p)
end

local function qty(id)
  local n = 0
  for p = 0, 4 do
    local ptr, cap = pocket(p)
    if ptr >= 0x02000000 and ptr < 0x02040000 then
      for s = 0, cap - 1 do
        if F.r16(ptr + s * 4) == id then n = n + (F.r16(ptr + s * 4 + 2) ~ key16()) end
      end
    end
  end
  return n
end

local function clearPocket(p)
  local ptr, cap = pocket(p)
  for s = 0, cap - 1 do F.w16(ptr + s * 4, 0); F.w16(ptr + s * 4 + 2, key16()) end
end

local function setSlot(p, s, id, n)
  local ptr = pocket(p)
  F.w16(ptr + s * 4, id); F.w16(ptr + s * 4 + 2, n ~ key16())
end

local function findTask(fn)
  for i = 0, S.Task.count - 1 do
    local a = S.gTasks + i * S.Task.stride
    if F.r8(a + S.Task.isActive) ~= 0 and (F.r32(a + S.Task.func) & ~1) == (fn & ~1) then return a end
  end
  return nil
end

local function taskData(a, i) return F.rs16(a + S.Task.data + i * 2) end

local function tasks()
  local t = {}
  for i = 0, S.Task.count - 1 do
    local a = S.gTasks + i * S.Task.stride
    if F.r8(a + S.Task.isActive) ~= 0 then t[#t + 1] = string.format("%08X", F.r32(a + S.Task.func)) end
  end
  return table.concat(t, ",")
end

local function state()
  return string.format("cb2=%08X tasks=[%s] money=%d grp=%d map=%d", F.cb2(), tasks(), F.money(), F.grp(), F.mapn())
end

local function shop() return F.r32(S.sShopData) end
local function maxQty() return F.r16(shop() + S.ShopData.maxQuantity) end
local function totalCost() return F.r32(shop() + S.ShopData.totalCost) end

local function instantText()
  local a = F.sb2() + S.SaveBlock2.optionsU16
  F.w16(a, (F.r16(a) & ~7) | 3)
end

local function tap(k, n) F.press(k, 2); F.idle(n or 10) end

-- Wait up to `frames` for pred, pressing `key` every `every` frames (nil key: just wait).
local function pump(pred, key, frames, every)
  for i = 1, frames do
    if pred() then return true end
    if F.reportCrash("pump") then return false end
    if key and i % (every or 20) == 0 then F.press(key, 2) else F.idle(1) end
  end
  return pred()
end

local function scenario(tag, body)
  if ONLY and not tag:find(ONLY, 1, true) then return end
  F.L("== " .. tag .. " ==")
  local ok, err = pcall(body)
  if not ok then F.check(tag .. ": scenario ran", false, tostring(err)) end
  F.check(tag .. ": no crash screen", not F.crashScreen(), state())
end

-- ---- the hub mart ----------------------------------------------------------------------------
-- The front-desk clerk stands at (0,7) behind the counter at (1,7); the player talks from (2,7).

local function toHub()
  if F.grp() == HUB_GROUP and F.mapn() == 0 then return true end
  return F.warpTo(1, 0, 0, 0, 0, 0, 0, 0, 0, HUB_GROUP, 0, "hub")
end

local function inShopMenu() return findTask(S.Task_ShopMenu) ~= nil end
local function inBuyList() return F.cb2() == (S.CB2_BuyMenu & ~1) and findTask(S.Task_BuyMenu) ~= nil end
local function inHowMany() return findTask(S.Task_BuyHowManyDialogueHandleInput) ~= nil end

local function openMart()
  if not F.leg(2, 4) or not F.leg(2, 7) then return false end
  F.face("Left")
  F.w32(S.sMartInfo + 12, 0)
  if not pump(inShopMenu, "A", 600, 30) then F.L("  shop menu never opened " .. state()); return false end
  F.idle(20)
  return true
end

local function openBuy()
  if not openMart() then return false end
  tap("A")
  if not pump(inBuyList, nil, 400) then F.L("  buy list never opened " .. state()); return false end
  F.idle(40)
  return true
end

-- Leave the buy list and the shop and get back to a walkable field.
local function leaveShop()
  for _ = 1, 80 do
    if F.ow() and not inShopMenu() and F.r8(S.sLockFieldControls) == 0 then break end
    F.press("B", 2); F.idle(20)
  end
  F.idle(30)
  return F.ensureFree()
end

-- From the buy list with the cursor on an item: A, then wait for the spinner or for the list to
-- come back (refusal). Returns "howmany", "list" or "stuck".
-- While a shop message shows, the list task's func is the message-wait task, so Task_BuyMenu
-- disappearing and coming back brackets a refusal.
local function chooseItem()
  F.idle(20)
  F.press("A", 2)
  local left = false
  for i = 1, 600 do
    if inHowMany() then F.idle(10); return "howmany" end
    local listed = findTask(S.Task_BuyMenu) ~= nil
    if not listed then left = true end
    if left and listed then F.idle(10); return "list" end
    if left and i % 30 == 0 then F.press("A", 2) else F.idle(1) end
  end
  return "stuck"
end

local function count() return taskData(findTask(S.Task_BuyHowManyDialogueHandleInput), 1) end

-- Confirm the spinner's quantity and say Yes; wait for the list.
local function confirmPurchase()
  tap("A", 20)
  return pump(function() return findTask(S.Task_BuyMenu) ~= nil end, "A", 900, 25)
end

-- ---- selling through the shop's bag ---------------------------------------------------------

local BAGPOS_POCKET, BAGPOS_CURSOR, BAGPOS_SCROLL = 5, 8, 18
local SELL_QUANTITY = 2   -- tQuantity, src/swsh_item_menu.c

local function inSellSpinner() return findTask(S.Task_ChooseHowManyToSell) ~= nil end

-- Open the shop's Sell bag on the Items pocket, top row. Returns true once the bag is up.
local function openSell()
  if not openMart() then return false end
  F.w8(S.gBagPosition + BAGPOS_POCKET, POCKET_ITEMS)
  F.w16(S.gBagPosition + BAGPOS_CURSOR, 0)
  F.w16(S.gBagPosition + BAGPOS_SCROLL, 0)
  tap("Down", 12); tap("A")
  if not pump(function() return F.cb2() == (S.CB2_Bag & ~1) end, nil, 400) then
    F.L("  sell bag never opened " .. state()); return false
  end
  F.idle(90)
  return true
end

-- Sell the top Items-pocket stack at the spinner's maximum (Down from 1 wraps to it). Returns the
-- spinner cap the game offered (nil when no spinner opened).
local function sellTopAtMax(tag)
  tap("A", 30)
  F.shot(tag:gsub("%W", "_") .. "_offer")
  local cap
  if pump(inSellSpinner, nil, 120) then
    cap = taskData(findTask(S.Task_ChooseHowManyToSell), SELL_QUANTITY)
    tap("Down", 12)
    tap("A", 40)
  end
  -- Yes on "I can pay ...", then B through "Turned over ..." and out of the bag.
  tap("A", 60)
  return cap
end

-- ---- battles ----------------------------------------------------------------------------------

local PKMN_SIZE, OFF_HP, OFF_MAXHP, OFF_LEVEL = S.Pokemon.size, S.Pokemon.hp, S.Pokemon.maxHP, S.Pokemon.level
local BP_STRIDE, BP_HP = S.BattlePokemon.size, S.BattlePokemon.hp
local CONTEXT_SHUTDOWN = 2
local ROW_PARTY_MENU, ROW_SET, ROW_BATTLE = 2, 9, 10
local HALF_UNITS = { [0] = 2, [1] = 1, [2] = 3, [3] = 4 }   -- OPTIONS_RATE_1X / 0_5X / 1_5X / 2X
local RATE_NAME = { [0] = "1x", [1] = "0.5x", [2] = "1.5x", [3] = "2x" }

local function tapDown(n) for _ = 1, n do F.press("Down", 3); F.idle(16) end end
local function closeDbg() for _ = 1, 16 do F.press("B", 3); F.idle(20) end end

local function hasControl()
  return F.ow() and F.r8(S.sLockFieldControls) == 0
    and F.r8(S.sGlobalScriptContextStatus) == CONTEXT_SHUTDOWN
end

local function setMoneyLoss(rate)
  local a = F.sb2() + S.SaveBlock2.ratesU16
  F.w16(a, (F.r16(a) & ~S.SaveBlock2.moneyLossMask) | (rate << 8))
end

local function setParty()
  F.dbg(); F.idle(60)
  tapDown(ROW_PARTY_MENU); F.press("A", 3); F.idle(60)
  tapDown(ROW_SET); F.press("A", 3); F.idle(180)
  closeDbg()
  return F.r8(S.gPartiesCount)
end

local function topLevel()
  local top = 1
  for i = 0, F.r8(S.gPartiesCount) - 1 do
    local lv = F.r8(S.gParties + i * PKMN_SIZE + OFF_LEVEL)
    if lv > top then top = lv end
  end
  return top
end

-- PREPARE_WORD_NUMBER_BUFFER lays gBattleTextBuff1 out as placeholder, B_BUFF_NUMBER, size,
-- digits, then the u32 value at +4.
local function moneyBuffer() return F.r32(S.gBattleTextBuff1 + 4) end

local function battleText()
  local a, t = S.gDisplayedStringBattle, {}
  for i = 0, 399 do
    local b = F.r8(a + i)
    if b == 255 then break end
    if b >= 161 and b <= 170 then t[#t + 1] = string.char(48 + b - 161)
    elseif b >= 187 and b <= 212 then t[#t + 1] = string.char(65 + b - 187)
    elseif b >= 213 and b <= 238 then t[#t + 1] = string.char(97 + b - 213)
    elseif b == 0 or b == 254 or b == 250 or b == 251 then t[#t + 1] = " " end
  end
  return table.concat(t)
end

local function startDebugWildBattle()
  F.dbg(); F.idle(60)
  tapDown(ROW_PARTY_MENU); F.press("A", 3); F.idle(60)
  tapDown(ROW_BATTLE); F.press("A", 3); F.idle(30)
  return pump(function() return not F.ow() end, nil, 2400)
end

local function faintParty()
  for i = 0, 5 do
    local b = S.gParties + i * PKMN_SIZE
    if F.r16(b + OFF_MAXHP) ~= 0 then F.w16(b + OFF_HP, 0) end
  end
  for i = 0, 3 do F.w16(S.gBattleMons + i * BP_STRIDE + BP_HP, 0) end
end

local function healParty()
  for i = 0, 5 do
    local b = S.gParties + i * PKMN_SIZE
    F.w16(b + OFF_HP, F.r16(b + OFF_MAXHP))
  end
end

-- Drive a battle that is ending to the field. `pattern` captures a number from the battle text.
local TRACE = os.getenv("PW_ECON_TRACE")
local function battleToField(tag, pattern, budget)
  local seen, lastText
  local leftField = not F.ow()
  for f = 1, budget or 6000 do
    local t = battleText()
    if t ~= lastText then lastText = t; if TRACE then F.L("  text: " .. t) end end
    for _, pat in ipairs(type(pattern) == "table" and pattern or { pattern }) do
      local n = t:match(pat)
      if n then seen = tonumber(n) end
    end
    if f % 20 == 0 then F.press(leftField and F.ow() and "B" or "A", 2) else F.idle(1) end
    if f % 60 == 0 and F.reportCrash(tag) then return false, seen, "crash screen" end
    if not F.ow() then leftField = true end
    if leftField and F.ow() and f % 10 == 0 and hasControl() then
      F.idle(30)
      if hasControl() then return true, seen, f end
    end
  end
  return false, seen, state()
end

-- Debug menu Trainers... -> Trainer 1 spinner up to id 1 -> Try Battle.
local function startDebugTrainerBattle()
  F.dbg(); F.idle(60)
  tapDown(6); F.press("A", 3); F.idle(60)
  tapDown(1); F.press("A", 3); F.idle(40)
  F.press("Up", 3); F.idle(20); F.press("A", 3); F.idle(60)
  tapDown(5); F.press("A", 3); F.idle(30)
  return pump(function() return not F.ow() end, nil, 2400)
end

local function winTrainerBattle()
  pump(function() return F.battlers() > 0 end, nil, 600)
  F.idle(240)
  for i = 0, 5 do F.w16(S.gParties + 6 * PKMN_SIZE + i * PKMN_SIZE + OFF_HP, 0) end
  F.w16(S.gBattleMons + BP_STRIDE + BP_HP, 0)
end

-- ---- mashing ------------------------------------------------------------------------------------

local seed = tonumber(os.getenv("PW_ECON_SEED") or "") or 0xC0175
local function rnd()
  seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF
  return seed >> 8
end

local function mash(tag, frames, w)
  local keys = { "A", "B", "Up", "Down", "Left", "Right", "Start" }
  for i = 1, frames do
    if F.reportCrash(tag) then return "crash", i end
    local t = {}
    for _, k in ipairs(keys) do if rnd() % 100 < (w[k] or 0) then t[k] = true end end
    joypad.set(t)
    emu.frameadvance()
  end
  return "ok", frames
end

F.run(function()
  if not F.boot(HUB_GROUP) then F.check("boot to the hub", false); F.finish(); return end
  instantText()

  scenario("mart one short", function()
    clearPocket(POCKET_BALLS)
    setMoney(599)
    if not F.check("mart one short: buy list opens", openBuy(), state()) then return end
    local r = chooseItem()
    F.check("mart one short: refused before the quantity window", r == "list", r .. " " .. state())
    F.check("mart one short: money unchanged", F.money() == 599, "money=" .. F.money())
    F.check("mart one short: no Great Ball", qty(ITEM_GREAT_BALL) == 0, "qty=" .. qty(ITEM_GREAT_BALL))
    F.shot("one_short")
    F.check("mart one short: leaves the shop", leaveShop(), state())
  end)

  scenario("mart exactly enough", function()
    clearPocket(POCKET_BALLS)
    setMoney(600)
    if not F.check("mart exactly enough: buy list opens", openBuy(), state()) then return end
    local r = chooseItem()
    if not F.check("mart exactly enough: quantity window opens", r == "howmany", r .. " " .. state()) then leaveShop(); return end
    F.check("mart exactly enough: spinner cap is 1", maxQty() == 1, "max=" .. maxQty())
    tap("Up"); F.check("mart exactly enough: Up at the cap stays 1", count() == 1, "count=" .. count())
    tap("Down"); F.check("mart exactly enough: Down at 1 stays 1", count() == 1, "count=" .. count())
    tap("Right"); F.check("mart exactly enough: Right stays 1", count() == 1, "count=" .. count())
    F.check("mart exactly enough: cost is 600", totalCost() == 600, "cost=" .. totalCost())
    F.check("mart exactly enough: purchase completes", confirmPurchase(), state())
    F.check("mart exactly enough: money is 0", F.money() == 0, "money=" .. F.money())
    F.check("mart exactly enough: one Great Ball", qty(ITEM_GREAT_BALL) == 1, "qty=" .. qty(ITEM_GREAT_BALL))
    F.shot("exactly_enough")
    leaveShop()
  end)

  scenario("mart at the cap", function()
    clearPocket(POCKET_BALLS)
    setMoney(MAX_MONEY)
    if not F.check("mart at the cap: buy list opens", openBuy(), state()) then return end
    local r = chooseItem()
    if not F.check("mart at the cap: quantity window opens", r == "howmany", r .. " " .. state()) then leaveShop(); return end
    F.check("mart at the cap: spinner cap is 999", maxQty() == 999, "max=" .. maxQty())
    tap("Down"); F.check("mart at the cap: Down at 1 wraps to 999", count() == 999, "count=" .. count())
    tap("Up"); F.check("mart at the cap: Up at 999 wraps to 1", count() == 1, "count=" .. count())
    tap("Left"); F.check("mart at the cap: Left at 1 stays 1", count() == 1, "count=" .. count())
    tap("Down")
    F.check("mart at the cap: cost of 999 is 599400", totalCost() == 599400, "cost=" .. totalCost())
    F.check("mart at the cap: purchase completes", confirmPurchase(), state())
    F.check("mart at the cap: money is 400599", F.money() == 400599, "money=" .. F.money())
    F.check("mart at the cap: 999 Great Balls", qty(ITEM_GREAT_BALL) == 999, "qty=" .. qty(ITEM_GREAT_BALL))
    F.check("mart at the cap: 99 bonus Premier Balls", qty(ITEM_PREMIER_BALL) == 99, "qty=" .. qty(ITEM_PREMIER_BALL))
    F.shot("at_cap")
    -- One more onto a full 999 stack spills into a new slot.
    r = chooseItem()
    if F.check("mart at the cap: second quantity window opens", r == "howmany", r .. " " .. state()) then
      F.check("mart at the cap: second purchase completes", confirmPurchase(), state())
      F.check("mart at the cap: money is 399999", F.money() == 399999, "money=" .. F.money())
      F.check("mart at the cap: 1000 Great Balls across slots", qty(ITEM_GREAT_BALL) == 1000, "qty=" .. qty(ITEM_GREAT_BALL))
    end
    leaveShop()
  end)

  scenario("mart full pocket", function()
    clearPocket(POCKET_BALLS)
    local _, cap = pocket(POCKET_BALLS)
    for s = 0, cap - 1 do setSlot(POCKET_BALLS, s, ITEM_ULTRA_BALL, 999) end
    setMoney(5000)
    if not F.check("mart full pocket: buy list opens", openBuy(), state()) then return end
    local r = chooseItem()
    if not F.check("mart full pocket: quantity window opens", r == "howmany", r .. " " .. state()) then leaveShop(); return end
    tap("Up"); tap("Up")
    F.check("mart full pocket: spinner at 3", count() == 3, "count=" .. count())
    F.check("mart full pocket: list returns after the refusal", confirmPurchase(), state())
    F.check("mart full pocket: money unchanged", F.money() == 5000, "money=" .. F.money())
    F.check("mart full pocket: no Great Ball", qty(ITEM_GREAT_BALL) == 0, "qty=" .. qty(ITEM_GREAT_BALL))
    F.check("mart full pocket: Ultra Balls untouched", qty(ITEM_ULTRA_BALL) == 999 * cap, "qty=" .. qty(ITEM_ULTRA_BALL))
    F.shot("full_pocket")
    leaveShop()
    clearPocket(POCKET_BALLS)
  end)

  -- Selling: every Nugget that leaves the bag must be paid for in full. A sale the wallet cannot
  -- absorb would take the item and drop the money over the cap.
  local NUGGET_SELL = PRICE[ITEM_NUGGET] // 4
  for _, c in ipairs({ { "sell from empty", 0, 5 }, { "sell toward the cap", 990000, 10 },
                       { "sell one past the cap", 997000, 1 }, { "sell at the cap", MAX_MONEY, 3 } }) do
    local tag, wallet, n = c[1], c[2], c[3]
    scenario(tag, function()
      clearPocket(POCKET_ITEMS)
      setSlot(POCKET_ITEMS, 0, ITEM_NUGGET, n)
      setMoney(wallet)
      if not F.check(tag .. ": sell bag opens", openSell(), state()) then leaveShop(); return end
      local cap = sellTopAtMax(tag)
      leaveShop()
      local sold = n - qty(ITEM_NUGGET)
      local gained = F.money() - wallet
      F.L(string.format("  %s: wallet=%d held=%d cap=%s sold=%d gained=%d", tag, wallet, n, tostring(cap), sold, gained))
      F.check(tag .. ": wallet within the cap", F.money() <= MAX_MONEY, "money=" .. F.money())
      F.check(tag .. ": every Nugget sold was paid in full", gained == sold * NUGGET_SELL,
        string.format("sold=%d gained=%d want=%d", sold, gained, sold * NUGGET_SELL))
      local room = (MAX_MONEY - wallet) // NUGGET_SELL
      local want = math.min(n, room)
      F.check(tag .. ": sold as many as the wallet can take", sold == want,
        string.format("sold=%d want=%d", sold, want))
    end)
  end
  clearPocket(POCKET_ITEMS)

  -- Mash the shop at Instant text with nothing in the bag to sell or toss. The mash can leave the
  -- shop, open the Start menu and come back, so only a wallet under every price has a strict
  -- ledger: nothing bought, nothing paid. The free Town Map is a key item and is not counted.
  local function bagTotal()
    local n = 0
    for p = 0, 3 do
      local ptr, cap = pocket(p)
      for s = 0, cap - 1 do
        if F.r16(ptr + s * 4) ~= 0 then n = n + (F.r16(ptr + s * 4 + 2) ~ key16()) end
      end
    end
    return n
  end
  for _, c in ipairs({ { "mash broke", 0 }, { "mash short", 19 }, { "mash flush", 50000 } }) do
    local tag, wallet = c[1], c[2]
    scenario(tag, function()
      for p = 0, 3 do clearPocket(p) end
      setMoney(wallet)
      if not F.check(tag .. ": buy list opens", openBuy(), state()) then leaveShop(); return end
      local r, at = mash(tag, 2400, { A = 40, B = 6, Up = 20, Down = 25, Left = 10, Right = 10, Start = 3 })
      F.check(tag .. ": no crash while mashing", r ~= "crash", "frame " .. at .. " " .. state())
      if r == "crash" then return end
      F.check(tag .. ": leaves the shop", leaveShop(), state())
      F.check(tag .. ": wallet in range", F.money() >= 0 and F.money() <= MAX_MONEY, "money=" .. F.money())
      if wallet < 20 then
        F.check(tag .. ": a wallet under every price buys nothing", F.money() == wallet and bagTotal() == 0,
          string.format("money=%d bag=%d", F.money(), bagTotal()))
      end
    end)
  end
  for p = 0, 3 do clearPocket(p) end

  -- Battles need a party.
  F.check("debug Set Party gave a party", setParty() > 0, "n=" .. F.r8(S.gPartiesCount))

  -- Trainer prize money into a full or nearly full wallet.
  for _, c in ipairs({ { "prize at the cap", MAX_MONEY }, { "prize just under the cap", MAX_MONEY - 9 },
                       { "prize from empty", 0 } }) do
    local tag, wallet = c[1], c[2]
    scenario(tag, function()
      toHub(); healParty()
      setMoney(wallet)
      if not F.check(tag .. ": trainer battle starts", startDebugTrainerBattle(), state()) then return end
      winTrainerBattle()
      local ok, shown, how = battleToField(tag, "You got%s*(%d+)")
      F.check(tag .. ": control returns", ok, tostring(how))
      F.check(tag .. ": battle won", F.outcome() == 1, "outcome=" .. F.outcome())
      local prize = moneyBuffer()
      F.L(string.format("  %s: wallet=%d prize=%d shown=%s money=%d", tag, wallet, prize, tostring(shown), F.money()))
      F.check(tag .. ": prize is positive", prize > 0, "prize=" .. prize)
      F.check(tag .. ": wallet gains the prize up to the cap", F.money() == math.min(MAX_MONEY, wallet + prize),
        string.format("money=%d want=%d", F.money(), math.min(MAX_MONEY, wallet + prize)))
      F.check(tag .. ": the message shows the prize", shown == prize, "shown=" .. tostring(shown))
    end)
  end

  -- Whiteouts at every Money Loss rate, at tiny wallets and a large one. The charge is
  -- 8 x top level (no badges) scaled by the rate and capped at the wallet; the message must show
  -- the amount actually taken.
  for rate = 0, 3 do
    for _, wallet in ipairs({ 0, 1, 2, 3, 50000 }) do
      local tag = string.format("whiteout %s wallet %d", RATE_NAME[rate], wallet)
      scenario(tag, function()
        toHub(); healParty()
        setMoneyLoss(rate)
        setMoney(wallet)
        local charge = 8 * topLevel() * HALF_UNITS[rate] // 2
        local want = math.min(wallet, charge)
        if not F.check(tag .. ": wild battle starts", startDebugWildBattle(), state()) then return end
        pump(function() return F.battlers() > 0 end, nil, 600)
        F.idle(240)
        faintParty()
        local ok, shown, how = battleToField(tag, { "dropped%s*(%d+)", "gave%s*(%d+)" })
        F.check(tag .. ": control returns", ok, tostring(how))
        F.check(tag .. ": charged min(wallet, rate x base)", F.money() == wallet - want,
          string.format("money=%d want=%d charge=%d", F.money(), wallet - want, charge))
        F.check(tag .. ": the message shows the amount taken", shown == want, "shown=" .. tostring(shown))
        F.check(tag .. ": the message buffer holds the amount taken", moneyBuffer() == want,
          "buffer=" .. moneyBuffer())
      end)
    end
  end
  setMoneyLoss(0)

  -- Mauville Game Corner coin desk. A purchase fills the case to MAX_COINS; it must charge only
  -- for the coins that fit.
  local function coins() return F.r16(F.sb1() + S.SaveBlock1.coins) ~ key16() end
  local function setCoins(v) F.w16(F.sb1() + S.SaveBlock1.coins, v ~ key16()) end
  local function giveCoinCase()
    if qty(ITEM_COIN_CASE) > 0 then return end
    local ptr, cap = pocket(POCKET_KEY)
    for s = 0, cap - 1 do
      if F.r16(ptr + s * 4) == 0 then setSlot(POCKET_KEY, s, ITEM_COIN_CASE, 1); return end
    end
  end
  local function buyCoins(row)
    if F.grp() ~= 10 or F.mapn() ~= 3 then
      if not F.warpTo(0, 1, 0, 0, 0, 3, 0, 0, 0, 10, 3, "game_corner") then return false end
      instantText()
    end
    if not F.leg(11, 4) then return false end
    F.face("Up")
    F.w8(S.sMenu + S.Menu.cursorPos, 0); F.w8(S.sMenu + S.Menu.maxCursorPos, 0)
    if not pump(function() return findTask(S.Task_HandleMultichoiceInput) ~= nil end, "A", 600, 30) then return false end
    F.idle(20)
    for _ = 1, 8 do
      if F.mcur() == row then break end
      tap("Down", 12)
    end
    if F.mcur() ~= row then return false end
    tap("A", 30)
    for _ = 1, 30 do F.press("B", 2); F.idle(20); if hasControl() then break end end
    return hasControl()
  end
  for _, c in ipairs({ { "coins near full", 9998, 200000, 2, 9999, 200000 - 20 },
                       { "coins partial fill", 9990, 180, 0, 9999, 0 },
                       { "coins full", 9999, 200000, 2, 9999, 200000 },
                       { "coins one short", 0, 99999, 2, 0, 99999 },
                       { "coins exact", 0, 100000, 2, 5000, 0 } }) do
    local tag, have, wallet, row, wantCoins, wantMoney = c[1], c[2], c[3], c[4], c[5], c[6]
    scenario(tag, function()
      giveCoinCase()
      setCoins(have); setMoney(wallet)
      F.check(tag .. ": bought through the desk", buyCoins(row), state())
      F.check(tag .. ": coins", coins() == wantCoins, string.format("coins=%d want=%d", coins(), wantCoins))
      F.check(tag .. ": money", F.money() == wantMoney, string.format("money=%d want=%d", F.money(), wantMoney))
    end)
  end

  F.finish()
end)
