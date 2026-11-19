-- TM prizes the player already owns, at every Game Corner TM counter (Mauville, Goldenrod, Celadon).
--
-- TMs are reusable here (I_REUSABLE_TMS) and important items, so a second copy can never be used,
-- sold or tossed; the Poke Mart marks an owned TM SOLD OUT. Each counter is played with real input:
-- the first purchase must take the coins and add the TM, and asking for the same TM again must
-- keep the coins and the count. The Coin Case is seeded in the Key Items pocket (and the Celadon
-- restaurant flag set) and only the coin balance is written; menus and prompts are real input.
-- Then a seeded mash at each counter with a full case (PW_TM_SEED, default 7) may spend coins
-- only on TMs the bag did not hold, at their prices, one copy each.
--
-- Run via test/overworld/mgba-run.sh test/overworld/lua/GameCornerOwnedTms.lua <rom>

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "GameCornerOwnedTms")

local ITEM_COIN_CASE = 718
local FLAG_GOT_COIN_CASE = 0xA40 + 0x243
local CONTEXT_SHUTDOWN = 2
local BUF = S.gStringVar4 + 900

local SEED = tonumber(os.getenv("PW_TM_SEED") or "7")
local seed = SEED
local HOENN_TMS = { [613] = 1500, [610] = 3500, [616] = 4000, [605] = 4000, [594] = 4000 }
local KANTO_TMS = { [594] = 4000, [604] = 3500, [605] = 4000, [611] = 4500, [616] = 4000 }
local COUNTERS = {
  { name = "Mauville", g = 10, n = 3, x = 13, y = 4, row = 0, cancel = 5, price = 1500, item = 613, list = HOENN_TMS },
  { name = "Goldenrod", g = 84, n = 12, x = 18, y = 4, row = 1, cancel = 5, price = 3500, item = 610, list = HOENN_TMS },
  { name = "Celadon", g = 44, n = 15, x = 6, y = 4, row = 0, cancel = 5, price = 4000, item = 594, list = KANTO_TMS },
}

local function where() local x, y = F.pos(); return string.format("%d/%d (%d,%d)", F.grp(), F.mapn(), x, y) end
local function key16() return F.r32(F.sb2() + S.SaveBlock2.encryptionKey) & 0xFFFF end
local function coins() return F.r16(F.sb1() + S.SaveBlock1.coins) ~ key16() end
local function setCoins(v) F.w16(F.sb1() + S.SaveBlock1.coins, v ~ key16()) end
local function setFlag(id)
  local a = F.sb1() + S.SaveBlock1.flags + id // 8
  F.w8(a, F.r8(a) | (1 << (id % 8)))
end
local function quantity(id)
  local n = 0
  for p = 0, 4 do
    local base = F.r32(S.gBagPockets + p * S.BagPocket.stride)
    for s = 0, F.pocketCap(p) - 1 do
      if F.r16(base + s * 4) == id then n = n + (F.r16(base + s * 4 + 2) ~ key16()) end
    end
  end
  return n
end
local function giveKeyItem(id)
  local base = F.r32(S.gBagPockets + 4 * S.BagPocket.stride)
  for s = 0, F.pocketCap(4) - 1 do
    if F.r16(base + s * 4) == 0 then
      F.w16(base + s * 4, id)
      F.w16(base + s * 4 + 2, 1 ~ key16())
      return true
    end
  end
  return false
end

local function hasControl()
  return F.ow() and F.r8(S.sLockFieldControls) == 0 and F.r8(S.sGlobalScriptContextStatus) == CONTEXT_SHUTDOWN
end
local function instantText()
  local a = F.sb2() + S.SaveBlock2.optionsU16
  F.w16(a, (F.r16(a) & ~7) | 3)
end
local function menuTask()
  for i = 0, S.Task.count - 1 do
    local a = S.gTasks + i * S.Task.stride
    local fn = F.r32(a + S.Task.func) & 0xFFFFFFFE
    if F.r8(a + S.Task.isActive) ~= 0 then
      if fn == S.Task_HandleMultichoiceInput then return "list" end
      if fn == S.Task_HandleYesNoInput or fn == S.Task_CallYesOrNoCallback then return "yesno" end
    end
  end
  return nil
end
local function pickRow(want)
  F.idle(10)
  for _ = 1, 12 do
    local c = F.mcur()
    if c == want then F.press("A", 2); F.idle(30); return true end
    F.press(c > want and "Up" or "Down", 2); F.idle(10)
  end
  return false
end

-- Talks to the clerk. On the prize list the first visit picks `row`, later visits pick `cancel`;
-- every Yes/No is answered YES. A through messages until control returns.
local function shop(c, tag)
  F.face("Up")
  F.press("A", 2); F.idle(20)
  local lists = 0
  for i = 1, 1200 do
    if i % 100 == 0 and F.reportCrash(tag) then return false end
    if hasControl() then F.idle(30); if hasControl() then return true end end
    local m = menuTask()
    if m == "list" then
      lists = lists + 1
      pickRow(lists == 1 and c.row or c.cancel)
    elseif m == "yesno" then
      pickRow(0)
    elseif i % 10 == 0 then
      F.press("A", 2)
    else
      F.idle(1)
    end
  end
  F.shot(tag .. "_stuck")
  return false
end

local function walkable(tag)
  if F.reportCrash(tag) then return false end
  for _, d in ipairs({ { "Down", "Up" }, { "Left", "Right" }, { "Right", "Left" }, { "Up", "Down" } }) do
    if F.step(d[1]) then F.step(d[2]); return true end
  end
  F.shot(tag .. "_stuck")
  return false
end

-- A seeded mash of A, B, Up and Down at the counter. Every coin spent must buy a TM the bag did
-- not hold, at its price, and no TM may end up with two copies.
local function mash(c, tag)
  local before = {}
  for id in pairs(c.list) do before[id] = quantity(id) end
  local c0 = coins()
  F.face("Up")
  F.press("A", 2); F.idle(20)
  local keys = { "A", "A", "B", "Up", "Down" }
  for i = 1, 4000 do
    if F.reportCrash(tag) then break end
    if hasControl() then F.idle(30); if hasControl() then break end end
    seed = (seed * 1103515245 + 12345) % 2147483648
    if i % 4 == 0 then F.press(keys[(seed >> 8) % #keys + 1], 2) else F.idle(1) end
  end
  for _ = 1, 60 do
    if hasControl() then break end
    F.press("B", 2); F.idle(20)
  end
  local spent, dupes, bought = 0, 0, {}
  for id, price in pairs(c.list) do
    local q = quantity(id)
    spent = spent + (q - before[id]) * price
    if q > 1 then dupes = dupes + 1 end
    if q ~= before[id] then bought[#bought + 1] = id .. "x" .. (q - before[id]) end
  end
  return c0 - coins() == spent and dupes == 0,
    string.format("seed=%d coins %d -> %d, bought %s, duplicated %d", SEED, c0, coins(), table.concat(bought, ","), dupes)
end

local function warp(g, n, x, y)
  local bytes = { 0x39, g, n, 0xFF, x & 0xFF, x >> 8, y & 0xFF, y >> 8, 0x27, 0x02 }
  for i, v in ipairs(bytes) do F.w8(BUF + i - 1, v) end
  F.w8(S.sGlobalScriptContext, 0)
  F.w8(S.sGlobalScriptContext + 1, 1)
  F.w32(S.sGlobalScriptContext + 4, 0)
  F.w32(S.sGlobalScriptContext + S.ScriptCtx.scriptPtr, BUF)
  F.w8(S.sGlobalScriptContextStatus, 0)
  for _ = 1, 600 do
    F.idle(4)
    local px, py = F.pos()
    if F.grp() == g and F.mapn() == n and px == x and py == y and hasControl() then F.idle(30); instantText(); return true end
  end
  return false
end

F.run(function()
  if not F.boot(100) then F.check("boot to the hub", false); F.finish(); return end
  instantText()
  F.check("setup: Coin Case in the bag", giveKeyItem(ITEM_COIN_CASE) and F.itemCount(ITEM_COIN_CASE) == 1)
  setFlag(FLAG_GOT_COIN_CASE)

  for _, c in ipairs(COUNTERS) do
    local tag = c.name
    if F.check(tag .. ": warp to the TM counter", warp(c.g, c.n, c.x, c.y), where()) then
      local start = c.price * 2
      setCoins(start)
      F.check(tag .. ": first purchase hands control back", shop(c, tag .. "_first"), where())
      F.shot(tag .. "_first")
      F.check(tag .. ": first purchase takes the coins and adds the TM",
        coins() == start - c.price and quantity(c.item) == 1,
        string.format("coins=%d tm=%d", coins(), quantity(c.item)))
      F.check(tag .. ": second request hands control back", shop(c, tag .. "_again"), where())
      F.shot(tag .. "_again")
      F.check(tag .. ": an owned TM keeps the coins and the count",
        coins() == start - c.price and quantity(c.item) == 1,
        string.format("coins=%d tm=%d", coins(), quantity(c.item)))
      setCoins(9999)
      local ok, why = mash(c, tag .. "_mash")
      F.check(tag .. ": mash hands control back", hasControl(), where())
      F.check(tag .. ": mash spends coins only on TMs it adds, one copy each", ok, why)
      F.check(tag .. ": field walkable", walkable(tag), where())
    end
  end
  F.finish()
end)
