-- Hidden coins on the Celadon Game Corner floor against a nearly full Coin Case.
--
-- The hidden-item script asks CheckAddCoins whether the coins fit before it picks them up. The
-- found amount lives in VAR_0x8009 (field_control_avatar.c), but CheckAddCoins added VAR_0x8006,
-- which every giveitem leaves holding the last item given. Right after the Coin Case man hands
-- over the case that is ITEM_COIN_CASE (718), so a case with room for the coins refused them as
-- full. The Coin Case comes from the real restaurant NPC; only the coin balance is seeded.
--
-- Run via test/overworld/mgba-run.sh test/overworld/lua/HiddenCoinsCase.lua <rom>

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "HiddenCoinsCase")

local KANTO_G, RESTAURANT_M, GAME_CORNER_M = 44, 17, 14
local ITEM_COIN_CASE = 718
local CONTEXT_SHUTDOWN = 2

local function key16() return F.r32(F.sb2() + S.SaveBlock2.encryptionKey) & 0xFFFF end
local function coins() return F.r16(F.sb1() + S.SaveBlock1.coins) ~ key16() end
local function setCoins(v) F.w16(F.sb1() + S.SaveBlock1.coins, v ~ key16()) end

local function hasControl()
  return F.ow() and F.r8(S.sLockFieldControls) == 0
    and F.r8(S.sGlobalScriptContextStatus) == CONTEXT_SHUTDOWN
end

local function instantText()
  local a = F.sb2() + S.SaveBlock2.optionsU16
  F.w16(a, (F.r16(a) & ~7) | 3)
end

-- Press A at what the player faces, then B through every message until the field is free.
local function interact(tag)
  for _ = 1, 4 do
    F.idle(30)
    F.press("A", 2)
    F.idle(4)
    if not hasControl() then break end
  end
  local started = false
  for i = 1, 600 do
    if F.reportCrash(tag) then return false end
    if not hasControl() then started = true end
    if started and hasControl() then F.idle(30); if hasControl() then return true end end
    if i % 20 == 0 then F.press("B", 2) else F.idle(1) end
  end
  F.shot(tag .. "_stuck")
  return false
end

local function pickUp(tag, tile, facing, have, want, empty)
  setCoins(have)
  if not F.check(tag .. ": reached the spot", F.leg(tile[1], tile[2]), string.format("at %d,%d", F.pos())) then return end
  F.face(facing)
  local ran = interact(tag)
  if not empty then F.check(tag .. ": script finished", ran) end
  F.shot(tag:gsub("%W", "_"))
  F.check(tag .. ": coins", coins() == want, string.format("coins=%d want=%d", coins(), want))
end

F.run(function()
  if not F.boot(100) then F.check("boot to the hub", false); F.finish(); return end
  instantText()

  F.check("warp to the Celadon restaurant", F.warpTo(0, 4, 4, 0, 1, 7, 0, 0, 0, KANTO_G, RESTAURANT_M, "restaurant"))
  instantText()
  F.check("walk to the Coin Case man", F.route({ { 6, 8 }, { 6, 2 }, { 2, 2 } }, "coin_case_man"))
  F.face("Left")
  F.check("Coin Case man's script finished", interact("coin_case_man"))
  F.check("got the Coin Case", F.itemCount(ITEM_COIN_CASE) > 0)

  F.check("warp to the Game Corner", F.warpTo(0, 4, 4, 0, 1, 4, 0, 0, 0, KANTO_G, GAME_CORNER_M, "game_corner"))
  instantText()
  F.check("walk into the Game Corner", F.route({ { 9, 12 }, { 3, 12 }, { 3, 5 } }, "floor"))

  pickUp("ten coins into a case with room", { 3, 4 }, "Left", 9300, 9310)
  pickUp("twenty coins that exactly fill the case", { 8, 4 }, "Down", 9979, 9999)
  pickUp("ten coins into a full case", { 10, 5 }, "Up", 9995, 9995)
  F.leg(9, 5)
  pickUp("the refused coins are still there", { 10, 5 }, "Up", 0, 10)
  F.leg(9, 5)
  pickUp("a found spot stays empty", { 10, 5 }, "Up", 0, 0, true)
  F.finish()
end)
