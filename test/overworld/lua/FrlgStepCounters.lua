-- Two FRLG timers that count the player's steps: Selphy's wish at Resort Gorgeous expires after
-- 250 steps, and Daisy in Pallet Town grooms a Pokemon again once 500 steps have passed since
-- the last grooming. Both NPCs are talked to and every step is walked with real input.
--
-- Selphy: make a wish, walk 200 steps (the wish must stand), walk 60 more (it must expire), then
-- talk: she is tired of waiting and wishes again. Daisy: with the game cleared, accept a grooming,
-- walk 500 steps, and she must offer grooming again instead of only rating friendship.
--
-- Run via: test/overworld/mgba-run.sh test/overworld/lua/FrlgStepCounters.lua <rom.gba>

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "FrlgStepCounters")

local SELPHY_HOUSE, RIVALS_HOUSE = {71, 0}, {38, 2}
local LOCALID_DAISY = 1
local FLAG_HIDE_RESORT_GORGEOUS_INSIDE_SELPHY = 0xA40 + 0x95
local FLAG_SYS_GAME_CLEAR = 0x94C
local VAR_MASSAGE_COOLDOWN, VAR_RG_STEPS, VAR_RG_REQUESTED = 0xA000, 0xA010, 0xA011
local VAR_RG_SCENE, VAR_RIVALS_HOUSE_SCENE = 0xA05D, 0xA031
local REQUEST_EXPIRED = 0xFFFF

local function where() local x, y = F.pos(); return string.format("%d/%d (%d,%d)", F.grp(), F.mapn(), x, y) end
local function mapIs(m) return F.grp() == m[1] and F.mapn() == m[2] end
local function flag(id, value)
  local a, bit = F.sb1() + S.SaveBlock1.flags + id // 8, 1 << (id % 8)
  if value ~= nil then F.w8(a, value and (F.r8(a) | bit) or (F.r8(a) & ~bit & 0xFF)) end
  return (F.r8(a) & bit) ~= 0
end
local function varAddr(id) return F.sb3() + S.SaveBlock3.regionVars + (id - 0xA000) * 2 end
local function var(id, value) if value ~= nil then F.w16(varAddr(id), value) end return F.r16(varAddr(id)) end
local function digits(n) return n // 100, (n // 10) % 10, n % 10 end
local function warp(m, tag)
  local gh, gt, go = digits(m[1]); local mh, mt, mo = digits(m[2])
  return F.warpTo(gh, gt, go, mh, mt, mo, 0, 0, 0, m[1], m[2], tag)
end

local function scriptIdle() return F.ow() and F.r8(S.sGlobalScriptContextStatus) == 2 end
local function yesNoUp()
  for i = 0, S.Task.count - 1 do
    local a = S.gTasks + i * S.Task.stride
    local fn = F.r32(a + S.Task.func) & 0xFFFFFFFE
    if F.r8(a + S.Task.isActive) ~= 0 and (fn == S.Task_HandleYesNoInput or fn == S.Task_CallYesOrNoCallback) then return true end
  end
  return false
end

-- Talks in direction `dir` and drives the script to its end with `key`. A Yes/No box is answered
-- with `answer` (A = Yes, B = No); returns whether the script finished and whether a box appeared.
-- Crash screens are resumable and dismissed with Start, so a timer test still runs on a ROM whose
-- request sampler trips an assert.
local function talk(dir, tag, key, answer)
  local offered = false
  F.face(dir); F.press("A", 2); F.idle(20)
  if scriptIdle() then return false, false, false end
  for n = 1, 500 do
    if F.crashScreen() then
      F.press("Start", 2); F.idle(20)
    elseif yesNoUp() then
      if not offered then F.idle(12); F.shot(tag .. "_yesno") end
      offered = true
      F.press(answer, 2); F.idle(40)
    elseif scriptIdle() and n > 3 then
      return true, offered, true
    else
      F.press(key, 2); F.idle(20)
    end
  end
  F.shot(tag .. "_stuck")
  return false, offered, true
end

-- Walks `n` real steps back and forth along row `y` between columns x0 and x1.
local function walkSteps(n, y, x0, x1)
  local dir = "Right"
  for _ = 1, n do
    local x, py = F.pos()
    if py ~= y then return false end
    if x >= x1 then dir = "Left" elseif x <= x0 then dir = "Right" end
    if not F.step(dir) then return false end
  end
  return true
end

local function objectAt(localId)
  for i = 0, 15 do
    local b = S.gObjectEvents + i * S.ObjectEvent.stride
    if (F.r8(b) & 1) ~= 0 and F.r8(b + S.ObjectEvent.localId) == localId then
      return F.rs16(b + S.ObjectEvent.x) - 7, F.rs16(b + S.ObjectEvent.y) - 7
    end
  end
end
-- Daisy wanders, so chase her live position and talk once next to her.
local function talkDaisy(tag, key, answer)
  local sides = { { -1, 0 }, { 0, 1 }, { 0, -1 }, { 1, 0 } }
  for attempt = 1, 12 do
    local ox, oy = objectAt(LOCALID_DAISY)
    if not ox then return false, false end
    local side = sides[(attempt - 1) % 4 + 1]
    F.leg(ox + side[1], oy + side[2])
    local px, py = F.pos()
    ox, oy = objectAt(LOCALID_DAISY)
    local dx, dy = ox - px, oy - py
    if math.abs(dx) + math.abs(dy) == 1 then
      local ok, offered, started = talk(dx == 1 and "Right" or dx == -1 and "Left" or dy == 1 and "Down" or "Up", tag, key, answer)
      if started then return ok, offered end
    end
  end
  F.shot(tag .. "_chase_failed")
  return false, false
end

local function debugParty()
  F.dbg(); F.idle(40); F.sel(2); F.idle(40)
  for _ = 1, 9 do F.press("Down", 3); F.idle(16) end
  F.press("A", 3); F.idle(180)
  for _ = 1, 20 do if F.ensureFree() then break end F.press("B", 2); F.idle(20) end
  return F.r8(S.gPartiesCount) == 1
end

local function selphy()
  flag(FLAG_HIDE_RESORT_GORGEOUS_INSIDE_SELPHY, false)
  var(VAR_RG_SCENE, 2)
  F.dbg(); F.sel(7); F.sel(2); F.idle(60); F.bOut(4)   -- Pokedex Flags All: Selphy wishes only for seen species
  F.check("Selphy's house", warp(SELPHY_HOUSE, "selphy_house"), where())
  F.dismiss(10)
  F.check("walk to Selphy", F.route({ { 4, 6 }, { 4, 5 } }, "selphy"), where())
  local ok = talk("Up", "wish", "B", "A")
  local first = var(VAR_RG_REQUESTED)
  F.check("Selphy makes a wish", ok and first ~= 0 and first ~= REQUEST_EXPIRED, "request=" .. first)

  F.check("step off to the walking row", F.step("Down"))
  F.check("walk 200 steps", walkSteps(199, 6, 1, 9), where())
  F.check("after 200 steps the wish stands", var(VAR_RG_REQUESTED) == first,
    string.format("request=%d steps=%d", var(VAR_RG_REQUESTED), var(VAR_RG_STEPS)))
  F.check("walk 60 more steps", walkSteps(60, 6, 1, 9), where())
  local expired = var(VAR_RG_REQUESTED) == REQUEST_EXPIRED
  F.check("after 260 steps the wish has expired", expired,
    string.format("request=%d steps=%d", var(VAR_RG_REQUESTED), var(VAR_RG_STEPS)))

  F.check("back to Selphy", F.route({ { 4, 6 }, { 4, 5 } }, "selphy_back"), where())
  ok = talk("Up", "tired", "B", "A")
  local second = var(VAR_RG_REQUESTED)
  F.check("Selphy tires of waiting and wishes again", ok and expired and second ~= 0 and second ~= REQUEST_EXPIRED and var(VAR_RG_STEPS) == 0,
    string.format("request=%d steps=%d", second, var(VAR_RG_STEPS)))
end

local function daisy()
  F.check("a Pokemon to groom", debugParty())
  flag(FLAG_SYS_GAME_CLEAR, true)
  var(VAR_RIVALS_HOUSE_SCENE, 2)
  F.check("new game leaves grooming ready", var(VAR_MASSAGE_COOLDOWN) == 500, "cooldown=" .. var(VAR_MASSAGE_COOLDOWN))
  F.check("Daisy's house", warp(RIVALS_HOUSE, "rivals_house"), where())
  F.dismiss(10)
  F.check("step into the room", F.route({ { 4, 7 } }, "room"), where())
  local ok, offered = talkDaisy("groom", "A", "A")
  F.check("Daisy grooms the Pokemon", ok and offered and var(VAR_MASSAGE_COOLDOWN) == 0,
    string.format("offered=%s cooldown=%d", tostring(offered), var(VAR_MASSAGE_COOLDOWN)))

  F.check("back to the walking row", F.route({ { 4, 7 } }, "row"), where())
  F.check("walk 500 steps", walkSteps(500, 7, 1, 7), where())
  F.check("the cooldown has run out", var(VAR_MASSAGE_COOLDOWN) == 500, "cooldown=" .. var(VAR_MASSAGE_COOLDOWN))
  ok, offered = talkDaisy("again", "B", "B")
  F.check("Daisy offers grooming again", ok and offered, string.format("offered=%s", tostring(offered)))
end

F.run(function()
  assert(F.boot(100), "Fresh game did not boot")
  selphy()
  daisy()
  F.finish()
end)
