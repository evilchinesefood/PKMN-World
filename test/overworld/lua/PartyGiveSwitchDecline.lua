-- Declining the party menu's "switch items?" prompt must leave the Bag and the held item alone.
--
-- Party menu, Item, Give opens the Bag to pick an item (CB2_SelectBagItemToGive). For a Pokemon
-- that already holds something, CB2_GiveHoldItem asks to switch. The item is still in the Bag at
-- that point: only the Yes branch removes it. The vanilla No branch (src/party_menu.c) just returns
-- to the party, and the SwSh party menu's No (src/swsh_party_menu.c) must not hand the item back a
-- second time.
--
-- Setup gives a Bulbasaur through the debug Give menu holding an Oran Berry and puts one Potion in
-- the Items pocket. The party menu, Item, Give, the Bag pick and the prompt run with real input:
--
--   1. answer No: still one Potion in the Bag, the Bulbasaur still holds the Oran Berry;
--   2. control, answer Yes: the Bulbasaur holds the Potion, the Oran Berry is in the Bag.
--
-- Run via test/overworld/mgba-run.sh test/overworld/lua/PartyGiveSwitchDecline.lua <rom>

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "PartyGiveSwitchDecline")

local HUB_GROUP = 100
local PARTY_SIZE = 6
local MON = S.Pokemon.size
local USM_ICO_PARTY = 1
local POCKET_ITEMS, POCKET_BERRIES = 0, 3
local BULBASAUR = 1
local ITEM_POTION, ITEM_ORAN_BERRY = 28, 520

local function party(slot) return S.gParties + slot * MON end

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
local function writeWords(a, w)
  local key = F.r32(a) ~ F.r32(a + 4)
  local sum = 0
  for i = 0, 11 do
    sum = (sum + (w[i] & 0xFFFF) + (w[i] >> 16)) & 0xFFFF
    F.w32(a + 32 + i * 4, w[i] ~ key)
  end
  F.w16(a + 28, sum)
end
local function heldItem(a) local w, o = words(a); return (w[o[0]] >> 16) & 0x3FF end
local function setHeldItem(a, item)
  local w, o = words(a)
  w[o[0]] = (w[o[0]] & ~(0x3FF << 16)) | (item << 16)
  writeWords(a, w)
end

local function pocketPtr(p) return F.r32(S.gBagPockets + p * S.BagPocket.stride) end
local function qtyKey() return F.r32(F.sb2() + S.SaveBlock2.encryptionKey) & 0xFFFF end
local function countItem(p, id)
  local n, ptr, cap = 0, pocketPtr(p), F.pocketCap(p)
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
local function inParty() return F.cb2() == (S.CB2_UpdatePartyMenu & ~1) end
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

local function waitFor(pred, frames)
  for _ = 1, frames do
    if pred() then return true end
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

-- Party menu, slot 0, Item, Give, the Potion, then the switch prompt answered with `answer`.
local function giveFromParty(tag, answer)
  local t = tag:gsub("%W", "_")
  F.w8(S.gBagPosition + 5, POCKET_ITEMS)
  F.w16(S.gBagPosition + 8 + POCKET_ITEMS * 2, 0)
  F.w16(S.gBagPosition + 18 + POCKET_ITEMS * 2, 0)
  F.press("Start", 2); F.idle(60)
  if not F.selectStartIcon(USM_ICO_PARTY) then F.check(tag .. ": the party icon", false); return false end
  F.press("A", 2)
  if not waitFor(inParty, 150) then F.check(tag .. ": the party menu opened", false); return false end
  F.idle(40)
  F.press("A", 2); F.idle(40)          -- action list: Summary | Item | Follow | Nickname | Cancel
  F.press("Down", 2); F.idle(20)
  F.shot(t .. "_item_row")
  F.press("A", 2); F.idle(40)          -- Item: Give | Take | Move | Cancel
  F.shot(t .. "_give_row")
  F.press("A", 2)
  if not waitFor(inBag, 200) then F.check(tag .. ": Give opened the Bag", false); return false end
  F.idle(40)
  F.shot(t .. "_bag_potion")
  F.press("A", 2)
  if not waitFor(inParty, 200) then F.check(tag .. ": picking the Potion returned to the party", false); return false end
  F.idle(90)
  F.shot(t .. "_already_holding")
  F.press("A", 2); F.idle(60)
  if answer == "No" then F.press("Down", 2); F.idle(20) end
  F.shot(t .. "_answer_" .. answer)
  F.press("A", 2); F.idle(60)
  F.shot(t .. "_after_answer")
  for _ = 1, 3 do
    if F.reportCrash(tag) then F.check(tag .. ": no crash screen", false); return false end
    F.press("A", 2); F.idle(30)
    if not inParty() then break end
  end
  F.check(tag .. ": no crash screen", not F.reportCrash(tag))
  return true
end

local function runCase(tag, answer, expect)
  F.L("== " .. tag .. " ==")
  if not giveMon(BULBASAUR, 10) then F.check(tag .. ": the debug Give made the Bulbasaur", false) else
    setHeldItem(party(0), ITEM_ORAN_BERRY)
    setPocket(POCKET_ITEMS, ITEM_POTION, 1)
    setPocket(POCKET_BERRIES, ITEM_ORAN_BERRY, 0)
    instantText()
    if giveFromParty(tag, answer) then
      local potions, berries, held = countItem(POCKET_ITEMS, ITEM_POTION), countItem(POCKET_BERRIES, ITEM_ORAN_BERRY), heldItem(party(0))
      F.L(string.format("  after: held=%d potions=%d oranBerries=%d", held, potions, berries))
      F.check(tag .. ": the Bulbasaur holds item " .. expect.held, held == expect.held, "held=" .. held)
      F.check(tag .. ": " .. expect.potions .. " Potion in the Bag", potions == expect.potions, "potions=" .. potions)
      F.check(tag .. ": " .. expect.berries .. " Oran Berry in the Bag", berries == expect.berries, "berries=" .. berries)
    end
  end
  if not backToField() then F.check(tag .. ": back on the field", false, string.format("cb2=%08X", F.cb2())) end
end

F.run(function()
  if not F.boot(HUB_GROUP) then F.check("boot to the hub", false); F.finish(); return end
  instantText()
  runCase("Decline the switch", "No", { held = ITEM_ORAN_BERRY, potions = 1, berries = 0 })
  runCase("Accept the switch", "Yes", { held = ITEM_POTION, potions = 0, berries = 1 })
  F.finish()
end)
