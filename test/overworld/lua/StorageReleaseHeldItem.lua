-- PC storage, Move Pokemon, Release a Pokemon that holds an item.
--
-- OW_PC_RELEASE_ITEM is on, so a released Pokemon's held item goes back to the Bag. Two paths lost
-- it instead: releasing the Pokemon in hand (picked up with Move) skipped the item, and a Bag with
-- no room for the item let the release go ahead and dropped the item. The Pokemon in hand must
-- return its item like any other, and a release whose item the Bag cannot take must be refused
-- with "The bag is full." and leave the Pokemon and its item alone.
--
-- Setup gives five Bulbasaur through the debug menu; the second, third and fourth hold a Potion.
-- (A release needs at least three Pokemon left over, or it is refused for another reason.)
-- Opening the PC (debug Access PC), Move Pokemon, the cursor, the menus, the release prompt and
-- its messages are real input:
--   1. the second Bulbasaur is picked up with Move and released from the hand;
--   2. control: the third Bulbasaur is released from its party slot;
--   3. with the Items pocket filled with other items (in RAM, in a fresh PC session) the fourth
--      Bulbasaur's release must be refused.
--
-- Run via test/overworld/mgba-run.sh test/overworld/lua/StorageReleaseHeldItem.lua <rom.gba>

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "StorageReleaseHeldItem")

local PARTY_SIZE, MON = 6, S.Pokemon.size
local BOXES, PER_BOX, BOX_MON = 14, 30, S.BoxPokemon.size
local BULBASAUR = 1
local ITEM_POTION, ITEM_FILLER = 28, 29
local POCKET_ITEMS = 0
local PC_MENU_ROWS, PC_MOVE_MONS = 5, 0
local AREA_PARTY, AREA_TITLE = 1, 2
local NO_SPRITE = 64

local function party(slot) return S.gParties + slot * MON end
local function boxSlot(box, slot) return F.r32(S.gPokemonStoragePtr) + 4 + (box * PER_BOX + slot) * BOX_MON end

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

local function instantText()
  local a = F.sb2() + S.SaveBlock2.optionsU16
  F.w16(a, (F.r16(a) & ~7) | 3)
end

local function digits(n) n = n - 1; return n // 100, (n // 10) % 10, n % 10 end
local function giveParty(n, species, level)
  for _ = 1, 3 do
    for off = 0, PARTY_SIZE * MON - 4, 4 do F.w32(S.gParties + off, 0) end
    F.w8(S.gPartiesCount, 0)
    F.dbg(); F.idle(30); F.bOut(4)
    for _ = 1, n do
      F.dbg(); F.sel(3); F.sel(1); F.idle(20)
      F.spin(digits(species)); F.idle(20)
      F.spin(digits(level)); F.idle(60); F.bOut(4)
    end
    local ok = F.r8(S.gPartiesCount) == n
    for i = 0, n - 1 do ok = ok and checksumOk(party(i)) end
    if ok then return true end
    F.idle(60)
  end
  return false
end

local function pocketPtr(p) return F.r32(S.gBagPockets + p * S.BagPocket.stride + S.BagPocket.itemsPtr) end
local function fillPocket(p, id)
  local ptr, cap = pocketPtr(p), F.pocketCap(p)
  if ptr < 0x02000000 or ptr >= 0x02040000 or cap < 1 or cap > 200 then return false end
  local qty = (1 ~ F.r32(F.sb2() + S.SaveBlock2.encryptionKey)) & 0xFFFF
  for s = 0, cap - 1 do F.w16(ptr + s * 4, id); F.w16(ptr + s * 4 + 2, qty) end
  return true
end

local function menuMax() return F.rs8(S.sMenu + S.Menu.maxCursorPos) end
local function pcMenuLive() return F.ow() and menuMax() == PC_MENU_ROWS - 1 end
local function cursorTo(row)
  for _ = 1, 8 do
    if F.mcur() == row then return true end
    F.press(F.mcur() < row and "Down" or "Up", 2); F.idle(12)
  end
  return F.mcur() == row
end
local function openMoveMons()
  if not pcMenuLive() then
    F.w8(S.sMenu + 2, 0); F.w8(S.sMenu + S.Menu.maxCursorPos, 0)
    F.dbg(); F.idle(60)
    F.press("Down", 3); F.idle(16); F.press("A", 3); F.idle(60)
    F.press("A", 3); F.idle(60)
    for _ = 1, 200 do
      if pcMenuLive() then break end
      F.press("A", 2); F.idle(18)
    end
    if not pcMenuLive() then return false end
    F.idle(30)
  end
  cursorTo(PC_MOVE_MONS); F.press("A", 2); F.idle(150)
  return not F.ow()
end
-- B, then No at "Continue Box operations?", back to the storage menu.
local function closeToPcMenu()
  for _ = 1, 30 do
    if F.ow() then break end
    F.press("B", 2); F.idle(30)
    F.press("Down", 2); F.idle(12); F.press("A", 2); F.idle(60)
  end
  for _ = 1, 60 do
    if pcMenuLive() then return true end
    F.idle(5)
  end
  return pcMenuLive()
end

local function tap(k) F.press(k, 2); F.idle(14) end
local function area() return F.r8(S.sCursorArea) end
local function cursor() return F.r8(S.sCursorPosition) end
local function holding() return F.r8(S.sIsMonBeingMoved) ~= 0 end
local function messageUp() return F.r8(S.sMessageWindowSpriteIds) ~= NO_SPRITE end
local function releasePromptUp()
  for i = 0, S.Task.count - 1 do
    local a = S.gTasks + i * S.Task.stride
    if F.r8(a + S.Task.isActive) ~= 0 and (F.r32(a + S.Task.func) & ~1) == (S.Task_ReleaseMon & ~1) then return true end
  end
  return false
end
local function toPartySlot(slot)
  for _ = 1, 30 do
    if area() == AREA_PARTY and cursor() == slot then return true end
    if area() == AREA_TITLE then tap("Down")
    elseif area() ~= AREA_PARTY then tap("Left")
    else tap(cursor() < slot and "Down" or "Up") end
  end
  return area() == AREA_PARTY and cursor() == slot
end

local function partySlotOf(pid)
  for i = 0, PARTY_SIZE - 1 do if pid ~= 0 and F.r32(party(i)) == pid then return i end end
  return nil
end
local function stored(pid)
  if partySlotOf(pid) then return true end
  for b = 0, BOXES - 1 do
    for s = 0, PER_BOX - 1 do if F.r32(boxSlot(b, s)) == pid then return true end end
  end
  return false
end

-- A on the cursor, Release (the menu's last row), then the prompt: true when it was offered.
local function chooseRelease(tag)
  tap("A"); F.idle(10)
  cursorTo(menuMax())
  F.shot(tag .. "_menu")
  tap("A"); F.idle(30)
  F.shot(tag .. "_after_release_row")
  return releasePromptUp()
end
local function confirmRelease(tag)
  tap("Up"); tap("A"); F.idle(150)
  F.shot(tag .. "_released")
  for _ = 1, 2 do tap("A"); F.idle(30) end
  for _ = 1, 60 do
    if not releasePromptUp() then break end
    F.idle(5)
  end
end

F.run(function()
  if not F.boot(100) then F.check("boot to the hub", false); F.finish(); return end
  instantText()
  F.check("setup: the debug Give made five Bulbasaur", giveParty(5, BULBASAUR, 10), "count=" .. F.r8(S.gPartiesCount))
  for i = 1, 3 do setHeldItem(party(i), ITEM_POTION) end
  local inHand, control, refused = F.r32(party(1)), F.r32(party(2)), F.r32(party(3))
  local function bagPotions()
    local ptr, cap, n = pocketPtr(POCKET_ITEMS), F.pocketCap(POCKET_ITEMS), 0
    local key = F.r32(F.sb2() + S.SaveBlock2.encryptionKey) & 0xFFFF
    for s = 0, cap - 1 do if F.r16(ptr + s * 4) == ITEM_POTION then n = n + (F.r16(ptr + s * 4 + 2) ~ key) end end
    return n
  end
  local potions = bagPotions()

  F.check("the Move Pokemon screen opened", openMoveMons())

  do
    local tag = "in hand"
    F.check(tag .. ": cursor on the second Bulbasaur", toPartySlot(1))
    tap("A"); tap("A"); F.idle(20)
    F.check(tag .. ": Move picked it up", holding())
    F.check(tag .. ": the release prompt opened", chooseRelease("in_hand"))
    confirmRelease("in_hand")
    F.check(tag .. ": it was released", not stored(inHand) and not holding())
    F.check(tag .. ": its Potion went to the Bag", bagPotions() == potions + 1,
      string.format("bag potions %d -> %d", potions, bagPotions()))
    potions = bagPotions()
  end

  do
    local tag = "control"
    local slot = partySlotOf(control)
    F.check(tag .. ": cursor on the third Bulbasaur", slot ~= nil and toPartySlot(slot))
    F.check(tag .. ": the release prompt opened", chooseRelease("control"))
    confirmRelease("control")
    F.check(tag .. ": it was released", not stored(control))
    F.check(tag .. ": its Potion went to the Bag", bagPotions() == potions + 1,
      string.format("bag potions %d -> %d", potions, bagPotions()))
  end

  F.check("back at the storage menu", closeToPcMenu())
  F.check("setup: Items pocket full of another item", fillPocket(POCKET_ITEMS, ITEM_FILLER) and F.itemCount(ITEM_POTION) == 0)
  F.check("the Move Pokemon screen opened again", openMoveMons())

  do
    local tag = "Bag full"
    local slot = partySlotOf(refused)
    F.check(tag .. ": cursor on the fourth Bulbasaur", slot ~= nil and toPartySlot(slot))
    local prompted = chooseRelease("bag_full")
    F.check(tag .. ": no release prompt", not prompted)
    F.check(tag .. ": The bag is full message is up", messageUp(), "spriteId=" .. F.r8(S.sMessageWindowSpriteIds))
    if prompted then confirmRelease("bag_full") else tap("B"); F.idle(20) end
    slot = partySlotOf(refused)
    F.check(tag .. ": the Bulbasaur is still in the party with its Potion",
      slot ~= nil and heldItem(party(slot)) == ITEM_POTION, "slot=" .. tostring(slot))
    F.check(tag .. ": the full pocket is unchanged", F.itemCount(ITEM_FILLER) == F.pocketCap(POCKET_ITEMS)
      and F.itemCount(ITEM_POTION) == 0)
  end

  F.check("no crash", not F.reportCrash("end"))
  F.finish()
end)
