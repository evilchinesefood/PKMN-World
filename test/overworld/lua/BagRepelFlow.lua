-- Repels from the SwSh Bag and the Repel expiry prompt behave as the item rules say.
--
-- The Bag hands Use to the vanilla field functions (ItemUseOutOfBattle_Repel), and a step that
-- runs the count out starts EventScript_SprayWoreOff (data/scripts/repel.inc), which offers one
-- Repel with a Yes/No or several strengths with a menu (I_REPEL_LURE_MENU). Everything runs with
-- real input from a free hub:
--
--   1. Repel from the Bag with none active: 100 steps, one Repel used;
--   2. Repel from the Bag while one is active: it lingers, nothing used, the count unchanged;
--   3. expiry with only Repels: Yes uses one and restarts the count at 100;
--   4. expiry with a Repel and a Max Repel: the menu's second row uses the Max Repel (250 steps);
--   5. expiry with the menu cancelled: nothing used, the count stays 0;
--   6. expiry with none left: only the message, the count stays 0.
--
-- Run via test/overworld/mgba-run.sh test/overworld/lua/BagRepelFlow.lua <rom>

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "BagRepelFlow")

local HUB_GROUP = 100
local USM_ICO_BAG = 2
local POCKET_ITEMS = 0
local ITEM_REPEL, ITEM_MAX_REPEL = 114, 116
local VAR_REPEL_STEP_COUNT = 0x4021

local function repelSteps() return F.r16(F.sb1() + S.SaveBlock1.vars + (VAR_REPEL_STEP_COUNT - 0x4000) * 2) end
local function setRepelSteps(v) F.w16(F.sb1() + S.SaveBlock1.vars + (VAR_REPEL_STEP_COUNT - 0x4000) * 2, v) end

local function pocketPtr(p) return F.r32(S.gBagPockets + p * S.BagPocket.stride) end
local function qtyKey() return F.r32(F.sb2() + S.SaveBlock2.encryptionKey) & 0xFFFF end
local function countItem(id)
  local n, ptr, cap = 0, pocketPtr(POCKET_ITEMS), F.pocketCap(POCKET_ITEMS)
  for s = 0, cap - 1 do
    if F.r16(ptr + s * 4) == id then n = n + (F.r16(ptr + s * 4 + 2) ~ qtyKey()) end
  end
  return n
end
local function setPocket(entries)
  local ptr, cap = pocketPtr(POCKET_ITEMS), F.pocketCap(POCKET_ITEMS)
  for s = 0, cap - 1 do F.w16(ptr + s * 4, 0); F.w16(ptr + s * 4 + 2, qtyKey()) end
  for i, e in ipairs(entries) do
    F.w16(ptr + (i - 1) * 4, e[1]); F.w16(ptr + (i - 1) * 4 + 2, e[2] ~ qtyKey())
  end
end

local function inBag() return F.cb2() == (S.CB2_BagMenuRun & ~1) end
local function instantText()
  local a = F.sb2() + S.SaveBlock2.optionsU16
  F.w16(a, (F.r16(a) & ~7) | 3)
end

local function backToField()
  for _ = 1, 40 do
    if F.ow() then break end
    F.press("B", 2); F.idle(20)
  end
  F.idle(30)
  for _ = 1, 3 do F.press("B", 2); F.idle(20) end
  return F.ow()
end

local function useFirstItem(tag)
  local t = tag:gsub("%W", "_")
  F.w8(S.gBagPosition + 5, POCKET_ITEMS)
  F.w16(S.gBagPosition + 8 + POCKET_ITEMS * 2, 0)
  F.w16(S.gBagPosition + 18 + POCKET_ITEMS * 2, 0)
  F.press("Start", 2); F.idle(60)
  if not F.selectStartIcon(USM_ICO_BAG) then F.check(tag .. ": the bag icon", false); return false end
  F.press("A", 2)
  for _ = 1, 150 do if inBag() then break end; F.idle(2) end
  if not inBag() then F.check(tag .. ": the bag opened", false); return false end
  F.idle(30)
  F.press("A", 2); F.idle(40)
  F.press("A", 2); F.idle(90)
  F.shot(t .. "_message")
  F.press("A", 2); F.idle(40)
  F.check(tag .. ": no crash screen", not F.reportCrash(tag))
  return backToField()
end

-- The count is set to 1 first, so this one step runs it out.
local dirs = { "Left", "Right", "Up", "Down" }
local function stepOnce()
  for _, d in ipairs(dirs) do
    if F.step(d) then return d end
  end
  return nil
end

local function expire(tag, answer)
  local t = tag:gsub("%W", "_")
  setRepelSteps(1)
  local x0, y0 = F.pos()
  if not stepOnce() then
    F.shot(t .. "_no_step")
    F.check(tag .. ": the player stepped", false, string.format("pos=(%d,%d)", x0, y0))
    return false
  end
  F.idle(40)
  F.shot(t .. "_wore_off")
  answer()
  for _ = 1, 6 do
    if F.reportCrash(tag) then F.check(tag .. ": no crash screen", false); return false end
    F.idle(40)
    F.press("A", 2)
  end
  F.idle(60)
  F.shot(t .. "_after")
  F.check(tag .. ": no crash screen", not F.reportCrash(tag))
  F.check(tag .. ": control returns", backToField(), string.format("cb2=%08X", F.cb2()))
  return true
end

F.run(function()
  if not F.boot(HUB_GROUP) then F.check("boot to the hub", false); F.finish(); return end
  instantText()

  do
    local tag = "Repel with none active"
    F.L("== " .. tag .. " ==")
    setRepelSteps(0); setPocket({ { ITEM_REPEL, 2 } })
    useFirstItem(tag)
    F.L(string.format("  steps=%d repels=%d", repelSteps(), countItem(ITEM_REPEL)))
    F.check(tag .. ": 100 steps", repelSteps() == 100, "steps=" .. repelSteps())
    F.check(tag .. ": one Repel used", countItem(ITEM_REPEL) == 1, "repels=" .. countItem(ITEM_REPEL))
  end

  do
    local tag = "Repel while one is active"
    F.L("== " .. tag .. " ==")
    setRepelSteps(50); setPocket({ { ITEM_REPEL, 2 } })
    useFirstItem(tag)
    F.L(string.format("  steps=%d repels=%d", repelSteps(), countItem(ITEM_REPEL)))
    F.check(tag .. ": the count is unchanged", repelSteps() == 50, "steps=" .. repelSteps())
    F.check(tag .. ": no Repel used", countItem(ITEM_REPEL) == 2, "repels=" .. countItem(ITEM_REPEL))
  end

  do
    local tag = "Expiry with Repels only, Yes"
    F.L("== " .. tag .. " ==")
    setPocket({ { ITEM_REPEL, 2 } })
    expire(tag, function() F.press("A", 2); F.idle(30) end)
    F.L(string.format("  steps=%d repels=%d", repelSteps(), countItem(ITEM_REPEL)))
    F.check(tag .. ": the count restarts at 100", repelSteps() == 100, "steps=" .. repelSteps())
    F.check(tag .. ": one Repel used", countItem(ITEM_REPEL) == 1, "repels=" .. countItem(ITEM_REPEL))
  end

  do
    local tag = "Expiry with a Repel and a Max Repel, pick Max"
    F.L("== " .. tag .. " ==")
    setPocket({ { ITEM_REPEL, 1 }, { ITEM_MAX_REPEL, 1 } })
    expire(tag, function()
      F.press("Down", 2); F.idle(20)
      F.shot("menu_on_max_repel")
      F.press("A", 2); F.idle(30)
    end)
    F.L(string.format("  steps=%d repels=%d maxRepels=%d", repelSteps(), countItem(ITEM_REPEL), countItem(ITEM_MAX_REPEL)))
    F.check(tag .. ": 250 steps", repelSteps() == 250, "steps=" .. repelSteps())
    F.check(tag .. ": the Max Repel used", countItem(ITEM_MAX_REPEL) == 0, "max=" .. countItem(ITEM_MAX_REPEL))
    F.check(tag .. ": the Repel kept", countItem(ITEM_REPEL) == 1, "repels=" .. countItem(ITEM_REPEL))
  end

  do
    local tag = "Expiry menu cancelled"
    F.L("== " .. tag .. " ==")
    setPocket({ { ITEM_REPEL, 1 }, { ITEM_MAX_REPEL, 1 } })
    expire(tag, function() F.press("B", 2); F.idle(30) end)
    F.L(string.format("  steps=%d repels=%d maxRepels=%d", repelSteps(), countItem(ITEM_REPEL), countItem(ITEM_MAX_REPEL)))
    F.check(tag .. ": the count stays 0", repelSteps() == 0, "steps=" .. repelSteps())
    F.check(tag .. ": nothing used", countItem(ITEM_REPEL) == 1 and countItem(ITEM_MAX_REPEL) == 1)
  end

  do
    local tag = "Expiry with none left"
    F.L("== " .. tag .. " ==")
    setPocket({})
    expire(tag, function() end)
    F.check(tag .. ": the count stays 0", repelSteps() == 0, "steps=" .. repelSteps())
  end

  F.finish()
end)
