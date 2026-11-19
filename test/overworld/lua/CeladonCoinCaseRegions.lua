-- The Celadon Game Corner with a COIN CASE found in another region.
--
-- One bag serves all three regions, and the COIN CASE comes from Mauville (Hoenn), the Goldenrod
-- Underground (Johto) or the Celadon restaurant (Kanto). The player here finds it in the Goldenrod
-- Underground with real input and never meets the restaurant man, then plays the Celadon Game
-- Corner: the coin clerk sells 50 coins, refuses an empty wallet, fills a nearly full case charging
-- only for the 9 coins that fit, refuses a full case and a wallet one short of 5,000 coins, and
-- survives a seeded mash (PW_COIN_SEED, default 10) where every coin gained must cost exactly 20;
-- a hidden coin spot pays out, the fisher hands over his 10 coins, a slot machine starts, and all
-- three prize clerks open their lists (Abra is bought). Only the wallet and the coin balance are
-- seeded. Every talk must hand control back with no crash screen and a walkable field.
--
-- Run via test/overworld/mgba-run.sh test/overworld/lua/CeladonCoinCaseRegions.lua <rom>

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "CeladonCoinCaseRegions")

local JOHTO_G, TUNNEL_M = 84, 27
local KANTO_G, GAME_CORNER_M, PRIZE_ROOM_M = 44, 14, 15
local ITEM_COIN_CASE = 718
local FLAG_GOT_COIN_CASE = 0xA40 + 0x243
local CONTEXT_SHUTDOWN = 2
local BUF = S.gStringVar4 + 900
local SEED = tonumber(os.getenv("PW_COIN_SEED") or "10")
local seed = SEED

local function where() local x, y = F.pos(); return string.format("%d/%d (%d,%d)", F.grp(), F.mapn(), x, y) end
local function key16() return F.r32(F.sb2() + S.SaveBlock2.encryptionKey) & 0xFFFF end
local function coins() return F.r16(F.sb1() + S.SaveBlock1.coins) ~ key16() end
local function setCoins(v) F.w16(F.sb1() + S.SaveBlock1.coins, v ~ key16()) end
local function setMoney(v) F.w32(F.sb1() + S.SaveBlock1.money, v ~ F.r32(F.sb2() + S.SaveBlock2.encryptionKey)) end
local function flagSet(id) return (F.r8(F.sb1() + S.SaveBlock1.flags + id // 8) >> (id % 8)) & 1 == 1 end
local function partyCount() return F.r8(S.gPartiesCount) end

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

local function settle(tag)
  for i = 1, 900 do
    if F.reportCrash(tag) then return false end
    if hasControl() then F.idle(30); if hasControl() then return true end end
    if i % 15 == 0 then F.press("B", 2) else F.idle(1) end
  end
  F.shot(tag .. "_stuck")
  return false
end
-- A through messages until a script menu is up, then put its cursor on `want` and pick it. Returns
-- false when the talk ends without a menu.
local function choose(want, tag)
  for _ = 1, 60 do
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
    if hasControl() then F.idle(20); if hasControl() then return false end end
    F.press("A", 2); F.idle(20)
  end
  F.shot(tag .. "_nomenu")
  return false
end
-- Face and press A until a script starts.
local function talk(facing, tag)
  F.face(facing)
  for _ = 1, 4 do
    F.idle(30)
    F.press("A", 2)
    F.idle(4)
    if not hasControl() then F.idle(16); return true end
  end
  F.shot(tag .. "_nothing")
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

  F.check("warp to the Goldenrod Underground", warp(JOHTO_G, TUNNEL_M, 12, 11), where())
  F.check("walk to the COIN CASE ball", F.route({ { 12, 12 }, { 12, 13 } }, "ball"), where())
  talk("Right", "ball")
  F.check("the ball's message closes", settle("ball"), where())
  F.shot("johto_coin_case")
  F.check("found the COIN CASE in Johto", F.itemCount(ITEM_COIN_CASE) == 1, "count=" .. F.itemCount(ITEM_COIN_CASE))
  F.check("never met the Celadon restaurant man", not flagSet(FLAG_GOT_COIN_CASE))

  setMoney(5000)
  setCoins(0)
  F.check("warp to the Celadon Game Corner", warp(KANTO_G, GAME_CORNER_M, 6, 4), where())
  talk("Up", "clerk")
  local picked = choose(0, "clerk")
  F.shot("clerk_after_pick")
  settle("clerk")
  F.check("coin clerk: 50 coins for 1,000", picked and coins() == 50 and F.money() == 4000,
    string.format("picked=%s coins=%d money=%d", tostring(picked), coins(), F.money()))

  local function clerk(tag, money, have, row, wantCoins, wantMoney)
    setMoney(money)
    setCoins(have)
    talk("Up", tag)
    local ok = choose(row, tag)
    F.check(tag .. ": control returns", settle(tag) and ok, where())
    F.check(tag, coins() == wantCoins and F.money() == wantMoney, string.format("coins=%d money=%d", coins(), F.money()))
  end
  clerk("clerk, no money", 0, 50, 0, 50, 0)
  clerk("clerk, 9 coins short of a full case", 999999, 9990, 1, 9999, 999999 - 9 * 20)
  clerk("clerk, full case", 999999, 9999, 0, 9999, 999999)
  clerk("clerk, one short of 5,000 coins' price", 99999, 0, 2, 0, 99999)

  setMoney(50000)
  setCoins(9000)
  talk("Up", "clerk_mash")
  local keys = { "A", "A", "B", "Up", "Down" }
  for i = 1, 3000 do
    if F.reportCrash("clerk_mash") then break end
    if hasControl() then F.idle(30); if hasControl() then break end end
    seed = (seed * 1103515245 + 12345) % 2147483648
    if i % 4 == 0 then F.press(keys[(seed >> 8) % #keys + 1], 2) else F.idle(1) end
  end
  local gained = coins() - 9000
  F.check("clerk mash: control returns", settle("clerk_mash"), where())
  F.check("clerk mash: coins stay in the case and cost 20 each",
    gained >= 0 and coins() <= 9999 and F.money() == 50000 - gained * 20,
    string.format("seed=%d coins=%d money=%d", SEED, coins(), F.money()))

  setCoins(50)
  F.check("walk to the hidden coins", F.route({ { 6, 5 }, { 3, 5 }, { 3, 4 } }, "hidden_walk"), where())
  F.check("hidden coins: the spot answers A", talk("Left", "hidden"), where())
  settle("hidden")
  F.shot("hidden_coins")
  F.check("hidden coins: ten more coins", coins() == 60, "coins=" .. coins())

  F.check("walk to the fisher", F.route({ { 3, 11 }, { 4, 11 }, { 4, 8 } }, "fisher"), where())
  talk("Up", "fisher")
  settle("fisher")
  F.shot("fisher")
  F.check("fisher: ten coins", coins() == 70, "coins=" .. coins())

  F.check("walk to slot machine 5", F.leg(4, 9), where())
  talk("Right", "slots")
  local yes = choose(0, "slots")
  local started = false
  for _ = 1, 400 do if not F.ow() then started = true; break end F.idle(1) end
  F.idle(240)
  F.shot("slots")
  F.check("slot machine starts", yes and started, "menu=" .. tostring(yes))
  for _ = 1, 60 do
    if F.ow() then break end
    if F.reportCrash("slots_quit") then break end
    F.press("B", 2); F.idle(30)
    if scriptMenuActive() or F.mcur() == 0 then F.press("A", 2); F.idle(60) end
  end
  F.check("control returns from the slots", settle("slots_quit"), where())

  F.check("warp to the prize room", warp(KANTO_G, PRIZE_ROOM_M, 4, 4), where())
  setCoins(180)
  local p0 = partyCount()
  talk("Up", "mons")
  local abra = choose(0, "mons_list") and choose(0, "mons_confirm")
  settle("mons")
  F.shot("mons")
  F.check("Pokemon prize clerk: Abra for 180 coins", abra and coins() == 0 and partyCount() == p0 + 1,
    string.format("coins=%d party %d -> %d", coins(), p0, partyCount()))

  F.check("walk to the TM clerk", F.leg(6, 4), where())
  talk("Up", "tms")
  local list = choose(5, "tms_list")
  settle("tms")
  F.check("TM prize clerk opens the prize list", list)

  F.check("walk to the item clerk", F.leg(2, 4), where())
  talk("Up", "items")
  list = choose(5, "items_list")
  settle("items")
  F.check("item prize clerk opens the prize list", list)

  F.check("field walkable after the Game Corner", walkable("end"), where())
  F.finish()
end)
