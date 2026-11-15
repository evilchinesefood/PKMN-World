-- Giving an item from the Bag to a Pokemon that holds Mail must be refused.
--
-- A held Mail owns a letter in SaveBlock1.mail, linked from the holder's mail index. The party
-- menu's Give refuses a Pokemon holding Mail ("MAIL must be removed before holding an item"),
-- because only Take runs TakeMailFromMon, which moves the letter out. The Bag gives items itself
-- (SWSH_ITEM_MENU_ACTION_IN_BAG, BagMenu_GiveItem in src/swsh_item_menu.c), and its switch prompt
-- must refuse the same way, or the letter is lost and its mailbox slot stays taken.
--
-- Setup gives a Bulbasaur through the debug Give menu and hands it Orange Mail the way
-- GiveMailToMonByItemId leaves it (letter in mailbox slot 0, held item, mail index). The Bag, the
-- Give action, the party select and the switch prompt then run with real input:
--
--   1. Potion onto the Mail holder, A through every prompt: refused, nothing moves;
--   2. control: Potion onto a Bulbasaur holding an Oran Berry: the two items switch.
--
-- Run via test/overworld/mgba-run.sh test/overworld/lua/BagGiveOverMail.lua <rom>

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "BagGiveOverMail")

local HUB_GROUP = 100
local PARTY_SIZE = 6
local MON = S.Pokemon.size
local USM_ICO_BAG = 2
local POCKET_ITEMS = 0
local BULBASAUR = 1
local ITEM_POTION, ITEM_ORAN_BERRY, ITEM_ORANGE_MAIL = 28, 520, 199
local MAIL_SIZE, MON_MAIL, MAIL_NONE = 36, 85, 0xFF

local function party(slot) return S.gParties + slot * MON end
local function mail(i) return F.sb1() + S.SaveBlock1.mail + i * MAIL_SIZE end

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
local function checksumOk(a)
  local w = words(a)
  local sum = 0
  for i = 0, 11 do sum = sum + (w[i] & 0xFFFF) + (w[i] >> 16) end
  return (sum & 0xFFFF) == F.r16(a + 28)
end

local function bytes(base, size)
  local t = {}
  for i = 0, size - 1 do t[#t + 1] = string.char(F.r8(base + i)) end
  return table.concat(t)
end
local function putBytes(base, value) for i = 1, #value do F.w8(base + i - 1, value:byte(i)) end end
local function letter(seed, item)
  local w = {}
  for i = 0, 8 do w[#w + 1] = string.char((seed + i) & 255, (seed >> 8) & 255) end
  return table.concat(w) .. "PLAYER\255\255\0\0\0\0" .. string.char(BULBASAUR, 0, item & 255, item >> 8, 0, 0)
end

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
    if F.r8(S.gPartiesCount) == 1 and checksumOk(party(0)) then return true end
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

-- Potion, Give, slot 0, then A through the switch prompt.
local function givePotionToSlot0(tag)
  setPocket(POCKET_ITEMS, ITEM_POTION, 1)
  if not openBagOnFirstItem() then F.check(tag .. ": the bag opened", false); return false end
  F.idle(30)
  F.press("A", 2); F.idle(40)          -- action menu: Use | Give / Toss | Cancel
  F.press("Right", 2); F.idle(20)
  F.shot(tag:gsub("%W", "_") .. "_give_selected")
  F.press("A", 2); F.idle(60)          -- Give: party select on slot 0
  local crash = false
  -- Three A presses: the switch prompt's Yes, then the message that follows it. More would reach
  -- the Bag list behind the panel and act on whatever item the give left there.
  for i = 1, 240 do
    if i % 8 == 0 and F.reportCrash(tag) then crash = true; break end
    joypad.set((i % 60 < 2 and i < 180) and { A = true } or {})
    emu.frameadvance()
    if i == 100 then F.shot(tag:gsub("%W", "_") .. "_after_prompt") end
  end
  joypad.set({})
  F.check(tag .. ": no crash screen", not crash)
  return true
end

F.run(function()
  if not F.boot(HUB_GROUP) then F.check("boot to the hub", false); F.finish(); return end
  instantText()

  do
    local tag = "Potion onto a Mail holder"
    F.L("== " .. tag .. " ==")
    if not giveMon(BULBASAUR, 10) then F.check(tag .. ": the debug Give made the Bulbasaur", false) else
      for i = 0, 15 do for b = 0, MAIL_SIZE - 1 do F.w8(mail(i) + b, 0) end end
      local text = letter(0x1234, ITEM_ORANGE_MAIL)
      putBytes(mail(0), text)
      setHeldItem(party(0), ITEM_ORANGE_MAIL)
      F.w8(party(0) + MON_MAIL, 0)
      instantText()
      if givePotionToSlot0(tag) then
        F.L(string.format("  after: held=%d mailIndex=%d potions=%d mailInBag=%d", heldItem(party(0)),
          F.r8(party(0) + MON_MAIL), countItem(ITEM_POTION), countItem(ITEM_ORANGE_MAIL)))
        F.check(tag .. ": the Bulbasaur still holds the Orange Mail", heldItem(party(0)) == ITEM_ORANGE_MAIL
          and checksumOk(party(0)), "held=" .. heldItem(party(0)))
        F.check(tag .. ": the Potion stayed in the Bag", countItem(ITEM_POTION) == 1, "potions=" .. countItem(ITEM_POTION))
        F.check(tag .. ": no Orange Mail went into the Bag", countItem(ITEM_ORANGE_MAIL) == 0,
          "mail=" .. countItem(ITEM_ORANGE_MAIL))
        F.check(tag .. ": the letter is still linked and unchanged",
          F.r8(party(0) + MON_MAIL) == 0 and bytes(mail(0), MAIL_SIZE) == text, "index=" .. F.r8(party(0) + MON_MAIL))
      end
    end
    if not backToField() then F.check(tag .. ": back on the field", false, string.format("cb2=%08X", F.cb2())) end
  end

  do
    local tag = "Potion onto a berry holder"
    F.L("== " .. tag .. " ==")
    if not giveMon(BULBASAUR, 10) then F.check(tag .. ": the debug Give made the Bulbasaur", false) else
      setHeldItem(party(0), ITEM_ORAN_BERRY)
      F.w8(party(0) + MON_MAIL, MAIL_NONE)
      instantText()
      if givePotionToSlot0(tag) then
        F.L(string.format("  after: held=%d potions=%d", heldItem(party(0)), countItem(ITEM_POTION)))
        F.check(tag .. ": the Bulbasaur now holds the Potion", heldItem(party(0)) == ITEM_POTION and checksumOk(party(0)),
          "held=" .. heldItem(party(0)))
        F.check(tag .. ": the Potion left the Bag", countItem(ITEM_POTION) == 0, "potions=" .. countItem(ITEM_POTION))
      end
    end
    if not backToField() then F.check(tag .. ": back on the field", false, string.format("cb2=%08X", F.cb2())) end
  end

  F.finish()
end)
