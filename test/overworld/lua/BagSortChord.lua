-- START and A pressed on the same frame in a one-item bag pocket must do one thing.
--
-- START asks to sort the pocket. With one item there is nothing to sort, so the bag prints "There's
-- nothing to sort!" and hands its task to the message. That path used to `break` out of the input
-- switch into the list input below it, so an A on the same frame also opened the item's context
-- menu over the half-started message. The message never printed, and its blank box stayed over
-- the item description until the bag closed. This seeds three Potions as the only Items stack,
-- opens the real bag from the start menu, and presses START and A together for one frame. The
-- message must come up without the context menu, A must dismiss it back to the list, and the
-- Potions must be untouched.
--
-- Run via: test/overworld/mgba-run.sh test/overworld/lua/BagSortChord.lua <rom.gba>

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "BagSortChord")

local HUB_GROUP = 100
local ITEM_POTION, POCKET_ITEMS, USM_ICO_BAG = 28, 0, 2

local function instantText()
  local a = F.sb2() + S.SaveBlock2.optionsU16
  F.w16(a, (F.r16(a) & ~7) | 3)
end
local function qtyKey() return F.r32(F.sb2() + S.SaveBlock2.encryptionKey) & 0xFFFF end
local function pocketPtr(p) return F.r32(S.gBagPockets + p * S.BagPocket.stride) end
local function setPocket(p, id, qty)
  local ptr = pocketPtr(p)
  for s = 0, F.pocketCap(p) - 1 do F.w16(ptr + s * 4, 0); F.w16(ptr + s * 4 + 2, qtyKey()) end
  F.w16(ptr, id); F.w16(ptr + 2, qty ~ qtyKey())
end
local function potions()
  local ptr = pocketPtr(POCKET_ITEMS)
  return F.r16(ptr) == ITEM_POTION and (F.r16(ptr + 2) ~ qtyKey()) or 0
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
-- B out to the field; a bag message only closes on A.
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

F.run(function()
  if not F.boot(HUB_GROUP) then F.check("boot to the hub", false); F.finish(); return end
  instantText()
  setPocket(POCKET_ITEMS, ITEM_POTION, 3)
  F.w8(S.gBagPosition + 5, POCKET_ITEMS)
  F.w16(S.gBagPosition + 8 + POCKET_ITEMS * 2, 0)
  F.w16(S.gBagPosition + 18 + POCKET_ITEMS * 2, 0)

  F.press("Start", 2); F.idle(60)
  local opened = F.selectStartIcon(USM_ICO_BAG)
  if opened then F.press("A", 2); F.idle(150) end
  if not F.check("the bag opens on the Potions", opened and inBag() and bagTaskFunc() == "list" and potions() == 3,
      string.format("cb2=%08X task=%s potions=%d", F.cb2(), bagTaskFunc(), potions())) then
    F.finish(); return
  end
  F.shot("bag")

  joypad.set({ Start = true, A = true }); emu.frameadvance(); joypad.set({})
  F.idle(90)
  local after = bagTaskFunc()
  F.shot("after_chord")
  F.check("START+A does not open the item's context menu", after ~= "context menu", "task=" .. after)
  F.check("START+A shows the nothing-to-sort message", after == "message", "task=" .. after)

  F.press("A", 2); F.idle(60)
  local back = bagTaskFunc()
  F.shot("after_dismiss")
  F.check("A dismisses the message back to the item list", inBag() and back == "list", "task=" .. back)

  F.check("control returns to the field", recover(), string.format("cb2=%08X", F.cb2()))
  F.check("the three Potions are untouched", potions() == 3, "potions=" .. potions())
  F.finish()
end)
