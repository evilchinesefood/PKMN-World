-- Answering NO to a key item's YES/NO on the field must hand the field back with every object
-- free. SELECT freezes all objects before a registered item runs (UseRegisteredKeyItemOnField), and
-- so does the Start menu before the Bag's Use. The Hub Pass and Pokevial NO answers released only
-- the field controls, so the follower stayed frozen where the player left it. Frozen mid animation
-- it never finished, and talking to it started its script, whose `lock` waits for that animation:
-- the game locked with no message on screen. Each scenario answers NO with real input, then talks
-- to the follower.
--
-- Run via test/overworld/mgba-run.sh test/overworld/lua/RegisteredItemDecline.lua <rom>
local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "RegisteredItemDecline")

local HUB_GROUP = 100
local HUB_PASS, POKEVIAL = 893, 874
local FOLLOWER = 254
local POCKET_KEY_ITEMS, USM_ICO_BAG = 4, 2

local function where() local x, y = F.pos(); return string.format("%d/%d (%d,%d)", F.grp(), F.mapn(), x, y) end

local SCRIPT_BUF = S.gStringVar4 + 960
local function runScript(bytes)
  for i, b in ipairs(bytes) do F.w8(SCRIPT_BUF + i - 1, b) end
  F.w8(S.sGlobalScriptContext, 0)
  F.w8(S.sGlobalScriptContext + 1, 1)
  F.w32(S.sGlobalScriptContext + 4, 0)
  F.w32(S.sGlobalScriptContext + S.ScriptCtx.scriptPtr, SCRIPT_BUF)
  F.w8(S.sGlobalScriptContextStatus, 0)
  F.idle(20)
end
local function addItem(id) runScript({ 0x44, id & 0xFF, id >> 8, 1, 0, 0x02 }) end

local function giveMon()
  F.dbg(); F.sel(3); F.sel(1); F.idle(20)
  F.spin(3, 7, 5); F.idle(20); F.spin(1, 0, 0); F.idle(60); F.bOut(4)
end

local function taskActive(fn)
  for i = 0, S.Task.count - 1 do
    local a = S.gTasks + i * S.Task.stride
    if F.r8(a + S.Task.isActive) ~= 0 and (F.r32(a + S.Task.func) & ~1) == (fn & ~1) then return true end
  end
  return false
end
local function yesNoUp() return taskActive(S.Task_HandleYesNoInput) or taskActive(S.Task_CallYesOrNoCallback) end
local function hasControl() return F.ow() and F.r8(S.sLockFieldControls) == 0 and not yesNoUp() end
local function talkLocked() return taskActive(S.Task_FreezeSelectedObjectAndPlayer) end

local function follower()
  for i = 0, 15 do
    local b = S.gObjectEvents + i * S.ObjectEvent.stride
    if (F.r8(b) & 1) == 1 and F.r8(b + S.ObjectEvent.localId) == FOLLOWER then
      return { x = F.rs16(b + S.ObjectEvent.x) - 7, y = F.rs16(b + S.ObjectEvent.y) - 7,
               invisible = (F.r8(b + S.ObjectEvent.flags1) & 0x20) ~= 0,
               frozen = (F.r8(b + S.ObjectEvent.flags1) & 0x01) ~= 0,
               moving = (F.r8(b) & 0x02) ~= 0 }
    end
  end
end
local function followerText()
  local f = follower()
  if not f then return "no follower" end
  return string.format("follower (%d,%d)%s%s%s", f.x, f.y, f.invisible and " hidden" or "",
    f.frozen and " frozen" or "", f.moving and " mid-movement" or "")
end

local function awaitControl(frames)
  local held = 0
  for _ = 1, frames do
    if hasControl() then held = held + 1 else held = 0 end
    if held >= 20 then return true end
    F.idle(1)
  end
  return false
end

-- A debug warp skips the gate that would make Hoenn the current region, so set it as the gate does.
local function petalburg(tag)
  local ok = F.warpTo(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, tag)
  F.w8(F.sb2() + S.SaveBlock2.currentRegion, 3); F.w32(S.gCurrentRegion, 3)
  return ok and awaitControl(300)
end

-- Register the item alone in the key item wheel's first slot, as ItemMenu_Register leaves it,
-- and press SELECT.
local function fromSelect(item)
  for i = 0, 3 do F.w16(F.sb1() + S.SaveBlock1.registeredItem + i * 2, i == 0 and item or 0) end
  F.press("Select", 2); F.idle(30)
  return true
end

-- Open the Bag on the Key Items pocket with the cursor on the item, then Use it.
local function fromBag(item)
  local ptr = F.r32(S.gBagPockets + POCKET_KEY_ITEMS * S.BagPocket.stride)
  local slot
  for i = 0, F.pocketCap(POCKET_KEY_ITEMS) - 1 do
    if F.r16(ptr + i * 4) == item then slot = i; break end
  end
  if not slot then return false end
  F.w8(S.gBagPosition + 5, POCKET_KEY_ITEMS)
  F.w16(S.gBagPosition + 8 + POCKET_KEY_ITEMS * 2, slot)
  F.w16(S.gBagPosition + 18 + POCKET_KEY_ITEMS * 2, 0)
  F.press("Start", 2); F.idle(60)
  if not F.selectStartIcon(USM_ICO_BAG) then return false end
  F.press("A", 2)
  for _ = 1, 150 do if F.cb2() == (S.CB2_BagMenuRun & ~1) then break end; F.idle(2) end
  F.idle(30)
  F.shot("bag_cursor")
  F.press("A", 2); F.idle(40)
  F.shot("bag_menu")
  F.press("A", 2); F.idle(30)
  return true
end

-- Page through the item's message with A and answer NO: the Hub Pass cursor already rests on NO,
-- so A takes it; the Pokevial's rests on YES, so B takes NO there.
local function decline(tag, noKey)
  local up = false
  for _ = 1, 20 do
    if yesNoUp() then up = true; break end
    F.press("A", 2); F.idle(30)
  end
  F.check(tag .. ": the item's YES/NO opened", up, where())
  if not up then return false end
  F.idle(20)
  F.shot(tag .. "_prompt")
  F.press(noKey, 2)
  local back = awaitControl(300)
  F.shot(tag .. "_declined")
  F.check(tag .. ": NO hands the field back", back, where() .. " " .. followerText())
  return back
end

-- Face the follower, talk to it, and back out of its lines with B. A field that never comes back
-- with the talk lock still waiting is the bug.
local function talkToFollower(tag, dir)
  F.face(dir)
  F.press("A", 2); F.idle(40)
  F.shot(tag .. "_talk")
  local talked = not hasControl() and F.r16(S.gSpecialVar_LastTalked) == FOLLOWER
  for _ = 1, 40 do
    if awaitControl(30) then break end
    if not talkLocked() then F.press("B", 2) end
  end
  local back = hasControl()
  if not back then F.shot(tag .. "_stuck") end
  F.check(tag .. ": the follower was talked to", talked, followerText())
  F.check(tag .. ": control returns after talking to the follower", back,
    string.format("%s %s talkLock=%s", where(), followerText(), tostring(talkLocked())))
end

-- Each scenario starts from the same hub savestate, so one that locks cannot hide the next.
-- `walk` takes two steps Left first, so the follower is out behind the player; `step` takes one
-- more after the NO, which a thawed follower follows.
local SCENARIOS = {
  { tag = "walked_hub_pass", item = HUB_PASS, use = fromSelect, noKey = "A", walk = true },
  -- Straight off a warp the follower waits hidden on the player's tile until the first step.
  { tag = "arrived_hub_pass", item = HUB_PASS, use = fromSelect, noKey = "A", step = true },
  { tag = "walked_pokevial", item = POKEVIAL, use = fromSelect, noKey = "B", walk = true },
  -- The Start menu freezes every object as well, and the Bag's Use reaches the same NO.
  { tag = "bag_hub_pass", item = HUB_PASS, use = fromBag, noKey = "A", walk = true, step = true },
}

local function behind(tag, what)
  local f = follower()
  local x, y = F.pos()
  F.check(tag .. ": " .. what, f and not f.invisible and f.x == x + 1 and f.y == y, "player " .. where() .. " " .. followerText())
end

local function scenario(sc)
  if not petalburg(sc.tag .. "_warp") then F.check(sc.tag .. ": reached Petalburg", false, where()); return end
  if sc.walk then
    F.step("Left"); F.step("Left"); F.idle(40)
    behind(sc.tag, "the follower is out behind the player")
  end
  if not F.check(sc.tag .. ": the item was used", sc.use(sc.item), where()) then return end
  if not decline(sc.tag, sc.noKey) then return end
  if sc.step then
    F.step("Left"); F.idle(40)
    behind(sc.tag, "the follower comes along on the next step")
  end
  talkToFollower(sc.tag, "Right")
end

F.run(function()
  if not F.boot(HUB_GROUP) then F.check("boot to the hub", false); F.finish(); return end
  giveMon()
  F.check("a lead Pokemon to follow", F.r8(S.gPartiesCount) >= 1, "party " .. F.r8(S.gPartiesCount))
  addItem(HUB_PASS); addItem(POKEVIAL)
  local base = F.out .. "RegisteredItemDecline_base.ss"
  client.savestate(base)
  for _, sc in ipairs(SCENARIOS) do
    client.loadstate(base); F.idle(10)
    F.L("== " .. sc.tag)
    scenario(sc)
  end
  F.finish()
end)
