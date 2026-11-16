-- A Bag pocket with two stacks must offer to sort them. The START handler in
-- Task_BagMenu_HandleInput (src/swsh_item_menu.c) refused with "There's nothing to sort!" when
-- numItemStacks - 1 <= 1, which assumed a "Close Bag" row in the count; this Bag always hides that
-- row (hideCloseBagText is set at every open), so two stacks were refused as if they were one.
--
-- The Items pocket gets Super Potion then Potion, out of name order. The real Bag opens from the
-- start menu, START is pressed, and the sort menu must come up instead of the message; A on its
-- first row (name) must put Potion first and keep both quantities. With one stack START must still
-- print the message (the control from BagSortChord's case, without the chord).
--
-- Run via: test/overworld/mgba-run.sh test/overworld/lua/BagSortTwoItems.lua <rom.gba>

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "BagSortTwoItems")

local HUB_GROUP = 100
local ITEM_POTION, ITEM_SUPER_POTION, POCKET_ITEMS, USM_ICO_BAG = 28, 29, 0, 2

local function instantText()
  local a = F.sb2() + S.SaveBlock2.optionsU16
  F.w16(a, (F.r16(a) & ~7) | 3)
end
local function qtyKey() return F.r32(F.sb2() + S.SaveBlock2.encryptionKey) & 0xFFFF end
local function pocketPtr(p) return F.r32(S.gBagPockets + p * S.BagPocket.stride) end
local function setPocket(p, stacks)
  local ptr = pocketPtr(p)
  for s = 0, F.pocketCap(p) - 1 do F.w16(ptr + s * 4, 0); F.w16(ptr + s * 4 + 2, qtyKey()) end
  for i, st in ipairs(stacks) do F.w16(ptr + (i - 1) * 4, st[1]); F.w16(ptr + (i - 1) * 4 + 2, st[2] ~ qtyKey()) end
end
local function slot(p, s)
  local ptr = pocketPtr(p)
  return F.r16(ptr + s * 4), F.r16(ptr + s * 4 + 2) ~ qtyKey()
end

local function bagTaskFunc()
  local known = {
    [S.Task_BagMenu_HandleInput & ~1] = "list",
    [S.Task_ItemContext_MultipleRows & ~1] = "context menu",
    [S.Task_ContinueTaskAfterMessagePrints & ~1] = "message",
    [S.HandleErrorMessage & ~1] = "message",
  }
  for i = 0, S.Task.count - 1 do
    local a = S.gTasks + i * S.Task.stride
    local name = F.r8(a + S.Task.isActive) ~= 0 and known[F.r32(a + S.Task.func) & ~1]
    if name then return name end
  end
  return "none"
end

local function inBag() return F.cb2() == (S.CB2_BagMenuRun & ~1) end
local function recover()
  for i = 1, 2400 do
    if F.reportCrash("recover") then return false end
    if F.ow() and i % 60 == 0 and F.ensureFree() then return true end
    local key = (inBag() and bagTaskFunc() == "message") and "A" or "B"
    joypad.set((i % 24 < 2) and { [key] = true } or {})
    emu.frameadvance()
  end
  return false
end

local function openBag(stacks, tag)
  setPocket(POCKET_ITEMS, stacks)
  F.w8(S.gBagPosition + 5, POCKET_ITEMS)
  F.w16(S.gBagPosition + 8 + POCKET_ITEMS * 2, 0)
  F.w16(S.gBagPosition + 18 + POCKET_ITEMS * 2, 0)
  F.press("Start", 2); F.idle(60)
  local opened = F.selectStartIcon(USM_ICO_BAG)
  if opened then F.press("A", 2); F.idle(150) end
  return F.check(tag .. ": the Bag opens on the item list", opened and inBag() and bagTaskFunc() == "list",
    string.format("cb2=%08X task=%s", F.cb2(), bagTaskFunc()))
end

F.run(function()
  if not F.boot(HUB_GROUP) then F.check("boot to the hub", false); F.finish(); return end
  instantText()

  if openBag({ { ITEM_SUPER_POTION, 2 }, { ITEM_POTION, 5 } }, "two stacks") then
    F.press("Start", 2); F.idle(90)
    local t = bagTaskFunc()
    F.shot("two_start")
    F.check("two stacks: START opens the sort menu", t == "context menu", "task=" .. t)
    if t == "context menu" then
      F.press("A", 2); F.idle(90)
      F.shot("two_sorted")
      F.press("A", 2); F.idle(40)
    end
    local id0, q0 = slot(POCKET_ITEMS, 0)
    local id1, q1 = slot(POCKET_ITEMS, 1)
    F.check("two stacks: sorted by name, Potion first", id0 == ITEM_POTION and id1 == ITEM_SUPER_POTION,
      string.format("slots %d,%d", id0, id1))
    F.check("two stacks: quantities kept", (id0 == ITEM_POTION and q0 == 5 and q1 == 2) or (id0 == ITEM_SUPER_POTION and q0 == 2 and q1 == 5),
      string.format("%d x%d, %d x%d", id0, q0, id1, q1))
    F.check("two stacks: back to the field", recover())
  end

  if openBag({ { ITEM_POTION, 3 } }, "one stack") then
    F.press("Start", 2); F.idle(90)
    local t = bagTaskFunc()
    F.shot("one_start")
    F.check("one stack: START prints the nothing-to-sort message", t == "message", "task=" .. t)
    F.press("A", 2); F.idle(60)
    F.check("one stack: back to the field", recover())
  end
  F.finish()
end)
