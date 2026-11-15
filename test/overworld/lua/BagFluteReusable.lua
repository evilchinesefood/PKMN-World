-- A Blue Flute used from the Bag on a sleeping Pokemon wakes it and stays in the Bag.
--
-- The flutes are reusable: the vanilla party menu's ItemUseCB_Medicine plays SE_GLASS_FLUTE and
-- skips RemoveBagItem for them (IsItemFlute in src/party_menu.c), and so does the SwSh party menu.
-- The SwSh Bag uses medicine itself (SWSH_ITEM_MENU_ACTION_IN_BAG, BagMenu_UseMedicine in
-- src/swsh_item_menu.c), and it must keep the flute the same way.
--
-- Setup gives a Bulbasaur through the debug Give menu and puts it to sleep (status 3). The Bag,
-- Use, the party select and the message then run with real input:
--
--   1. Blue Flute on the sleeping Bulbasaur: it wakes, the flute stays;
--   2. control: Awakening on the sleeping Bulbasaur: it wakes, the Awakening is used up.
--
-- Run via test/overworld/mgba-run.sh test/overworld/lua/BagFluteReusable.lua <rom>

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "BagFluteReusable")

local HUB_GROUP = 100
local PARTY_SIZE = 6
local MON = S.Pokemon.size
local USM_ICO_BAG = 2
local POCKET_ITEMS = 0
local BULBASAUR = 1
local ITEM_AWAKENING, ITEM_BLUE_FLUTE = 47, 109
local SLEEP_3 = 3

local function party(slot) return S.gParties + slot * MON end
local function status(slot) return F.r32(party(slot) + S.Pokemon.status) end

local function pocketPtr(p) return F.r32(S.gBagPockets + p * S.BagPocket.stride) end
local function qtyKey() return F.r32(F.sb2() + S.SaveBlock2.encryptionKey) & 0xFFFF end
local function countItem(id)
  local n, ptr, cap = 0, pocketPtr(POCKET_ITEMS), F.pocketCap(POCKET_ITEMS)
  for s = 0, cap - 1 do
    if F.r16(ptr + s * 4) == id then n = n + (F.r16(ptr + s * 4 + 2) ~ qtyKey()) end
  end
  return n
end
local function setPocket(p, id, qty)
  local ptr, cap = pocketPtr(p), F.pocketCap(p)
  for s = 0, cap - 1 do F.w16(ptr + s * 4, 0); F.w16(ptr + s * 4 + 2, qtyKey()) end
  if qty > 0 then F.w16(ptr, id); F.w16(ptr + 2, qty ~ qtyKey()) end
end

local function inBag() return F.cb2() == (S.CB2_BagMenuRun & ~1) end
local function instantText()
  local a = F.sb2() + S.SaveBlock2.optionsU16
  F.w16(a, (F.r16(a) & ~7) | 3)
end

local function digits(n) n = n - 1; return n // 100, (n // 10) % 10, n % 10 end
local function giveMon(species, level)
  for _ = 1, 3 do
    for off = 0, PARTY_SIZE * MON - 4, 4 do F.w32(S.gParties + off, 0) end
    F.w8(S.gPartiesCount, 0)
    F.dbg(); F.idle(30); F.bOut(4)
    F.dbg(); F.sel(3); F.sel(1); F.idle(20)
    F.spin(digits(species)); F.idle(20)
    F.spin(digits(level)); F.idle(60); F.bOut(4)
    if F.r8(S.gPartiesCount) == 1 then return true end
    F.idle(60)
  end
  return false
end

local function openBagOnFirstItem()
  F.w8(S.gBagPosition + 5, POCKET_ITEMS)
  F.w16(S.gBagPosition + 8 + POCKET_ITEMS * 2, 0)
  F.w16(S.gBagPosition + 18 + POCKET_ITEMS * 2, 0)
  F.press("Start", 2); F.idle(60)
  if not F.selectStartIcon(USM_ICO_BAG) then return false end
  F.press("A", 2)
  for _ = 1, 150 do
    if inBag() then return true end
    F.idle(2)
  end
  return false
end

local function backToField()
  for _ = 1, 40 do
    if F.ow() then break end
    F.press("B", 2); F.idle(20)
  end
  F.idle(30)
  return F.ow()
end

-- Item, Use, slot 0, then A through the message. Two A presses: the party select, then the
-- message. More would reach the Bag list and act on the item again.
local function useOnSlot0(tag, item)
  setPocket(POCKET_ITEMS, item, 1)
  if not openBagOnFirstItem() then F.check(tag .. ": the bag opened", false); return false end
  F.idle(30)
  F.press("A", 2); F.idle(40)          -- action menu: Use | Give / Toss | Cancel
  F.press("A", 2); F.idle(60)          -- Use: party select on slot 0
  F.shot(tag:gsub("%W", "_") .. "_party_select")
  local crash = false
  for i = 1, 200 do
    if i % 8 == 0 and F.reportCrash(tag) then crash = true; break end
    joypad.set((i % 60 < 2 and i < 120) and { A = true } or {})
    emu.frameadvance()
    if i == 80 then F.shot(tag:gsub("%W", "_") .. "_message") end
  end
  joypad.set({})
  F.check(tag .. ": no crash screen", not crash)
  return true
end

local function runCase(tag, item, expectLeft)
  F.L("== " .. tag .. " ==")
  if not giveMon(BULBASAUR, 10) then F.check(tag .. ": the debug Give made the Bulbasaur", false) else
    F.w32(party(0) + S.Pokemon.status, SLEEP_3)
    instantText()
    if useOnSlot0(tag, item) then
      F.L(string.format("  after: status=%d left=%d", status(0), countItem(item)))
      F.check(tag .. ": the Bulbasaur woke up", status(0) == 0, "status=" .. status(0))
      F.check(tag .. ": " .. expectLeft .. " left in the Bag", countItem(item) == expectLeft, "left=" .. countItem(item))
    end
  end
  if not backToField() then F.check(tag .. ": back on the field", false, string.format("cb2=%08X", F.cb2())) end
end

F.run(function()
  if not F.boot(HUB_GROUP) then F.check("boot to the hub", false); F.finish(); return end
  instantText()
  runCase("Blue Flute on a sleeping Bulbasaur", ITEM_BLUE_FLUTE, 1)
  runCase("Awakening on a sleeping Bulbasaur", ITEM_AWAKENING, 0)
  F.finish()
end)
