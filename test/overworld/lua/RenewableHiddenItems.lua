-- FRLG's renewable hidden items on the Sevii Islands. Every step counts toward
-- VAR_RENEWABLE_ITEM_STEP_COUNTER, which stops at 1500. Entering a map from FRLG's table at the
-- cap resets the count, hides every renewable item and shows one sampled tier on every table map.
-- A new game starts with them hidden. Treasure Beach's Ultra Ball is in all three tiers, so it
-- must come back after each regeneration; Trainer Tower's Nanab Berry is not in the table, so it
-- must stay gone even when the regeneration fires on its own map.
--
-- Every step is walked and every item is picked up with real input. The first regeneration fires
-- on a walk across the Seven Island connection, the second on a warp into Treasure Beach.
--
-- Run via: test/overworld/mgba-run.sh test/overworld/lua/RenewableHiddenItems.lua <rom.gba>

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "RenewableHiddenItems")

local SEVII_G, ONE_ISLAND, SEVEN_ISLAND, TREASURE_BEACH, TRAINER_TOWER = 37, 12, 17, 46, 58
local ITEM_ULTRA_BALL, ITEM_NANAB_BERRY = 3, 531
local FLAG_TREASURE_BEACH_ULTRA_BALL = 0xF00 + 0xDB
local FLAG_TRAINER_TOWER_NANAB_BERRY = 0xF00 + 0x12B
local VAR_RENEWABLE_STEPS = 0xA064
local CAP = 1500
local CONTEXT_SHUTDOWN = 2

local function where() local x, y = F.pos(); return string.format("%d/%d (%d,%d)", F.grp(), F.mapn(), x, y) end
local function onMap(num) return F.grp() == SEVII_G and F.mapn() == num end
local function flag(id)
  return (F.r8(F.sb1() + S.SaveBlock1.flags + id // 8) & (1 << (id % 8))) ~= 0
end
local function steps() return F.r16(F.sb3() + S.SaveBlock3.regionVars + (VAR_RENEWABLE_STEPS - 0xA000) * 2) end

local function quantity(id)
  local key = F.r32(F.sb2() + S.SaveBlock2.encryptionKey) & 0xFFFF
  local n = 0
  for p = 0, 4 do
    local ptr = F.r32(S.gBagPockets + p * S.BagPocket.stride)
    local cap = F.pocketCap(p)
    if ptr >= 0x02000000 and ptr < 0x02040000 and cap > 0 and cap < 200 then
      for s = 0, cap - 1 do
        if F.r16(ptr + s * 4) == id then n = n + (F.r16(ptr + s * 4 + 2) ~ key) end
      end
    end
  end
  return n
end

local function instantText()
  local a = F.sb2() + S.SaveBlock2.optionsU16
  F.w16(a, (F.r16(a) & ~7) | 3)
end

local function hasControl()
  return F.ow() and F.r8(S.sLockFieldControls) == 0
    and F.r8(S.sGlobalScriptContextStatus) == CONTEXT_SHUTDOWN
end

-- Presses A at the faced tile and B through any message that follows.
local function interact(tag)
  for _ = 1, 3 do
    F.idle(20); F.press("A", 2); F.idle(6)
    if not hasControl() then break end
  end
  for i = 1, 900 do
    if F.reportCrash(tag) then return end
    if hasControl() then F.idle(30); if hasControl() then return end end
    if i % 20 == 0 then F.press("B", 2) else F.idle(1) end
  end
  F.shot(tag .. "_stuck")
end

local function digits(n) return n // 100, (n // 10) % 10, n % 10 end
local function warp(num, warpId, tag)
  local gh, gt, go = digits(SEVII_G); local mh, mt, mo = digits(num); local wh, wt, wo = digits(warpId)
  local ok = F.warpTo(gh, gt, go, mh, mt, mo, wh, wt, wo, SEVII_G, num, tag)
  instantText()
  return ok
end

-- Treasure Beach's boy wanders one tile around (13,20), so a blocked leg is retried.
local function go(pts, tag)
  for _, p in ipairs(pts) do
    local ok = false
    for _ = 1, 6 do
      if F.leg(p[1], p[2]) then ok = true; break end
      F.idle(90)
    end
    if not ok then F.shot(tag .. "_stuck"); return false end
  end
  return true
end

-- Walks `n` real steps back and forth along row `y` between columns x0 and x1.
local function walkSteps(n, y, x0, x1)
  local dir = "Right"
  for i = 1, n do
    local x, py = F.pos()
    if py ~= y then return false end
    if x >= x1 then dir = "Left" elseif x <= x0 then dir = "Right" end
    if not F.step(dir) then
      if F.reportCrash("walk" .. i) then return false end
      F.idle(60)
      if not F.step(dir) then return false end
    end
  end
  return true
end

-- Searches the Ultra Ball's tile from (15,23) facing Up; returns how many were found.
local function searchUltraBall(tag)
  if not F.check(tag .. ": reached the Ultra Ball's tile", go({ { 12, 23 }, { 15, 23 } }, tag), where()) then return 0 end
  F.face("Up")
  local before = quantity(ITEM_ULTRA_BALL)
  interact(tag)
  F.shot(tag)
  return quantity(ITEM_ULTRA_BALL) - before
end

-- Both searches end on a sideways step, so the face("Up") turns the player instead of walking.
local function searchNanabBerry(tag)
  if not F.check(tag .. ": reached the Nanab Berry's tile", go({ { 58, 33 }, { 59, 33 } }, tag), where()) then return 0 end
  F.face("Up")
  local before = quantity(ITEM_NANAB_BERRY)
  interact(tag)
  F.shot(tag)
  return quantity(ITEM_NANAB_BERRY) - before
end

local function intoTrainerTower(tag)
  F.check(tag .. ": Seven Island", warp(SEVEN_ISLAND, 2, tag), where())
  F.check(tag .. ": walk to the north edge", go({ { 12, 4 }, { 8, 4 }, { 8, 0 } }, tag), where())
  F.step("Up")
  F.idle(60)
  return F.check(tag .. ": walked into the Trainer Tower area", onMap(TRAINER_TOWER), where())
end

F.run(function()
  if not F.boot(100) then F.check("boot to the hub", false); F.finish(); return end
  instantText()

  F.check("Treasure Beach", warp(TREASURE_BEACH, 0, "beach_new_game"), where())
  local found = searchUltraBall("new_game")
  F.check("a new game shows no renewable item before the first regeneration",
    found == 0 and flag(FLAG_TREASURE_BEACH_ULTRA_BALL), string.format("found=%d steps=%d", found, steps()))

  if intoTrainerTower("nanab") then
    found = searchNanabBerry("nanab")
    F.check("the Nanab Berry is picked up", found == 1 and flag(FLAG_TRAINER_TOWER_NANAB_BERRY), "found=" .. found)
  end

  F.check("walk to the walking row", go({ { 57, 37 } }, "row"), where())
  F.check("walk 1500 steps", walkSteps(CAP, 37, 55, 59), where())
  F.check("the step counter stops at 1500", steps() == CAP, "steps=" .. steps())

  F.check("step south to Seven Island", go({ { 57, 39 } }, "south") and F.step("Down") and onMap(SEVEN_ISLAND), where())
  F.step("Up")
  F.idle(60)
  F.check("walk back into the Trainer Tower area", onMap(TRAINER_TOWER), where())
  F.check("entering a table map at the cap restarts the count", steps() < 10, "steps=" .. steps())
  found = searchNanabBerry("nanab_after")
  F.check("the Nanab Berry stays gone after the regeneration on its own map",
    found == 0 and flag(FLAG_TRAINER_TOWER_NANAB_BERRY), "found=" .. found)

  F.check("Treasure Beach after the regeneration", warp(TREASURE_BEACH, 0, "beach_regen1"), where())
  found = searchUltraBall("regen1")
  F.check("the Ultra Ball is there and picked up", found == 1, string.format("found=%d steps=%d", found, steps()))

  F.check("walk 1000 steps", go({ { 11, 23 } }, "beach_row") and walkSteps(1000, 23, 6, 11), where())
  F.check("leave for One Island", warp(ONE_ISLAND, 0, "one_island_1"), where())
  F.check("back to Treasure Beach below the cap", warp(TREASURE_BEACH, 0, "beach_below_cap"), where())
  found = searchUltraBall("below_cap")
  F.check("below the cap the Ultra Ball has not come back", found == 0, string.format("found=%d steps=%d", found, steps()))

  F.check("walk 500 more steps", go({ { 11, 23 } }, "beach_row2") and walkSteps(500, 23, 6, 11), where())
  F.check("the step counter is at the cap again", steps() == CAP, "steps=" .. steps())
  F.check("leave for One Island again", warp(ONE_ISLAND, 0, "one_island_2"), where())
  F.check("warp back to Treasure Beach at the cap", warp(TREASURE_BEACH, 0, "beach_regen2"), where())
  F.check("the warp in restarts the count", steps() == 0, "steps=" .. steps())
  found = searchUltraBall("regen2")
  F.check("the Ultra Ball has come back and is picked up again", found == 1, string.format("found=%d steps=%d", found, steps()))
  F.check("the Nanab Berry is still gone", flag(FLAG_TRAINER_TOWER_NANAB_BERRY))
  F.finish()
end)
