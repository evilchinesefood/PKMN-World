-- PC storage, Move Items, "Bag" on a boxed Pokemon's held item while that pocket is full.
--
-- The "BAG is full" message must wait for a key and then close. Before the fix the task skipped
-- to its redraw states, returned to the main loop at once, and left the message window sprites
-- on screen with nothing to clear them.
--
-- Setup gives a party and fills the boxes through the debug menu, writes a held Potion onto box 1
-- slot 1 and fills the Items pocket in RAM. Opening the PC (debug Access PC), the storage menu,
-- the item menu and the key press use real input.
--
-- Run via test/overworld/mgba-run.sh test/overworld/lua/StorageItemToBagFull.lua <rom.gba>

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "StorageItemToBagFull")

local FLAG_SYS_POKEMON_GET = 0x948
local PER_BOX, BOX_MON = 30, S.BoxPokemon.size
local POCKET_ITEMS = 0
local ITEM_POTION, ITEM_FILLER = 28, 29
local MAX_SPRITES = 64
local PC_MENU_ROWS, PC_MOVE_ITEMS = 5, 3
local ITEM_MENU_BAG = 1

local function count() return F.r8(S.gPartiesCount) end
local function sb1Flag(id)
  local a = F.sb1() + S.SaveBlock1.flags + (id // 8)
  F.w8(a, F.r8(a) | (1 << (id % 8)))
end
local function boxSlot(box, slot) return F.r32(S.gPokemonStoragePtr) + 4 + (box * PER_BOX + slot) * BOX_MON end

local function secure(a)
  local pers = F.r32(a)
  local key = pers ~ F.r32(a + 4)
  local w = {}
  for i = 0, 11 do w[i] = F.r32(a + 32 + i * 4) ~ key end
  local s0 = F.r8(S.sSubstructOffsets + pers % 24) * 3
  return w, s0, key
end
local function heldItem(a) local w, s0 = secure(a); return (w[s0] >> 16) & 0x3FF end
local function setHeldItem(a, item)
  local w, s0, key = secure(a)
  w[s0] = (w[s0] & ~(0x3FF << 16)) | (item << 16)
  local sum = 0
  for i = 0, 11 do
    local v = w[i] & 0xFFFFFFFF
    sum = sum + (v & 0xFFFF) + (v >> 16)
    F.w32(a + 32 + i * 4, v ~ key)
  end
  F.w16(a + 28, sum & 0xFFFF)
end

local function pocketPtr(p) return F.r32(S.gBagPockets + p * S.BagPocket.stride + S.BagPocket.itemsPtr) end
local function fillPocket(p, id)
  local ptr, cap = pocketPtr(p), F.pocketCap(p)
  if ptr < 0x02000000 or ptr >= 0x02040000 or cap < 1 or cap > 200 then return false end
  local qty = (1 ~ F.r32(F.sb2() + S.SaveBlock2.encryptionKey)) & 0xFFFF
  for s = 0, cap - 1 do F.w16(ptr + s * 4, id); F.w16(ptr + s * 4 + 2, qty) end
  return true
end

local function msgSprite() return F.r8(S.sMessageWindowSpriteIds) end

local function tapDown(n) for _ = 1, n do F.press("Down", 3); F.idle(16) end end
local function drain(tries)
  for i = 1, tries or 40 do
    F.press("B", 3); F.idle(20)
    if i % 5 == 0 and F.ensureFree() then return true end
  end
  return F.ensureFree()
end
local function debugAction(path, tag)
  F.dbg(); F.idle(60)
  for i, row in ipairs(path) do
    tapDown(row); F.press("A", 3); F.idle(i == #path and 240 or 60)
  end
  if not drain(20) then F.L("  debug action " .. tag .. " did not return to the field") return false end
  return true
end

local function menuMax() return F.rs8(S.sMenu + S.Menu.maxCursorPos) end
local function clearMenu() F.w8(S.sMenu + 2, 0); F.w8(S.sMenu + S.Menu.maxCursorPos, 0) end
local function pcMenuLive() return F.ow() and menuMax() == PC_MENU_ROWS - 1 end
local function cursorTo(row)
  for _ = 1, 8 do
    if F.mcur() == row then return true end
    F.press(F.mcur() < row and "Down" or "Up", 2); F.idle(12)
  end
  return F.mcur() == row
end

F.run(function()
  if not F.boot(100) then F.check("boot to the hub", false); F.finish(); return end
  sb1Flag(FLAG_SYS_POKEMON_GET)
  F.check("setup: debug Set Party ran", debugAction({ 2, 9 }, "set_party") and count() >= 1, "count=" .. count())
  F.check("setup: debug Fill PC Boxes Fast ran", debugAction({ 1, 1, 0 }, "fill_pc") and F.r32(boxSlot(0, 0)) ~= 0)

  local mon = boxSlot(0, 0)
  setHeldItem(mon, ITEM_POTION)
  F.check("setup: box 1 slot 1 holds a Potion", heldItem(mon) == ITEM_POTION, "held=" .. heldItem(mon))
  F.check("setup: Items pocket full of another item", fillPocket(POCKET_ITEMS, ITEM_FILLER) and F.itemCount(ITEM_POTION) == 0)

  clearMenu()
  F.dbg(); F.idle(60)
  tapDown(1); F.press("A", 3); F.idle(60)
  F.press("A", 3); F.idle(60)
  for _ = 1, 200 do
    if pcMenuLive() then break end
    F.press("A", 2); F.idle(18)
  end
  F.check("the storage menu opened", pcMenuLive())
  if not pcMenuLive() then F.shot("no_pc_menu"); F.finish(); return end
  F.idle(30)
  cursorTo(PC_MOVE_ITEMS); F.press("A", 2); F.idle(150)
  F.check("entered the storage screen", not F.ow())

  F.press("A", 2); F.idle(40)
  F.shot("item_menu")
  tapDown(ITEM_MENU_BAG); F.press("A", 2); F.idle(60)
  F.shot("bag_full_msg")
  F.check("the BAG is full message is up", msgSprite() ~= MAX_SPRITES, "spriteId=" .. msgSprite())
  F.idle(120)
  F.shot("bag_full_after_wait")
  F.check("the message is still up while no key is pressed", msgSprite() ~= MAX_SPRITES, "spriteId=" .. msgSprite())

  F.press("Right", 2); F.idle(40)
  F.shot("after_key")
  F.check("a key press closes the BAG is full message", msgSprite() == MAX_SPRITES, "spriteId=" .. msgSprite())
  F.check("the Potion stays on the Pokemon", heldItem(mon) == ITEM_POTION, "held=" .. heldItem(mon))
  F.check("no Potion was added to the full bag", F.itemCount(ITEM_POTION) == 0, "count=" .. F.itemCount(ITEM_POTION))
  F.check("no crash", not F.crashScreen())
  F.finish()
end)
