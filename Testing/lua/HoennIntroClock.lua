-- #195: Johto/Kanto-first Hoenn visit must not lock in the bedroom.
--
-- FLAG_SET_WALL_CLOCK is one global flag. Hub first-visit lands at intro state 4, 2F
-- ON_TRANSITION turns that into 5, and the clock used to only show the time. The already-set
-- branch must advance to 6 so the stairs bounce stops.
--
-- Run via Testing/mgba-run.sh Testing/lua/HoennIntroClock.lua

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "HoennIntroClock")

local HUB_GROUP = 100
local GRP2, MAP2, WARP2 = 1, 1, 0   -- MAP_LITTLEROOT_TOWN_BRENDANS_HOUSE_2F
local GRP1, MAP1 = 1, 0             -- MAP_LITTLEROOT_TOWN_BRENDANS_HOUSE_1F
local VAR_INTRO = 0x4092            -- VAR_LITTLEROOT_INTRO_STATE
local VARS_START = 0x4000
local FLAG_SET_WALL_CLOCK = 0x51
local FLAG_HIDE_RIVAL_BEDROOM = 0x2F8
local FLAG_HIDE_BEDROOM_MOM = 0x2F5  -- FLAG_HIDE_LITTLEROOT_TOWN_PLAYERS_BEDROOM_MOM

local function d(n) return (n // 100) % 10, (n // 10) % 10, n % 10 end

local function go(grp, map, warp, tag)
  local gh, gt, go_ = d(grp)
  local mh, mt, mo = d(map)
  local wh, wt, wo = d(warp)
  if not F.warpTo(gh, gt, go_, mh, mt, mo, wh, wt, wo, grp, map, tag) then
    F.check(tag .. "_warped", false, string.format("grp=%d map=%d", F.grp(), F.mapn()))
    return false
  end
  F.idle(60)
  return true
end

local function introAddr()
  return F.sb1() + S.SaveBlock1.vars + (VAR_INTRO - VARS_START) * 2
end
local function introState() return F.r16(introAddr()) end
local function setIntro(v) F.w16(introAddr(), v) end

local function flagAddr(id) return F.sb1() + S.SaveBlock1.flags + (id // 8) end
local function flagSet(id)
  F.w8(flagAddr(id), F.r8(flagAddr(id)) | (1 << (id % 8)))
end
local function flagGet(id)
  return (F.r8(flagAddr(id)) & (1 << (id % 8))) ~= 0
end

local function walkTo(tx, ty, tag)
  for _ = 1, 80 do
    if F.reportCrash("walk_" .. tag) then return false end
    local x, y = F.pos()
    if x == tx and y == ty then return true end
    local dir
    if x < tx then dir = "Right" elseif x > tx then dir = "Left"
    elseif y < ty then dir = "Down" else dir = "Up" end
    if not F.step(dir) then
      F.L(string.format("  walk %s blocked at (%d,%d)->(%d,%d)", tag, x, y, tx, ty))
      F.shot(tag .. "_stuck")
      return false
    end
  end
  return false
end

F.run(function()
  if not F.boot(HUB_GROUP) then F.check("boot", false); F.finish(); return end

  -- Cross-region arrival: clock already set elsewhere, intro not yet at 6.
  flagSet(FLAG_SET_WALL_CLOCK)
  flagSet(FLAG_HIDE_RIVAL_BEDROOM)
  flagSet(FLAG_HIDE_BEDROOM_MOM)
  setIntro(4)
  F.check("FLAG_SET_WALL_CLOCK is set", flagGet(FLAG_SET_WALL_CLOCK))
  F.check("seeded intro state 4", introState() == 4, "state=" .. introState())

  if not go(GRP2, MAP2, WARP2, "brendan_2f") then F.finish(); return end
  F.check("on Brendan 2F", F.grp() == GRP2 and F.mapn() == MAP2,
    string.format("grp=%d map=%d", F.grp(), F.mapn()))
  -- ON_TRANSITION BlockStairsUntilClockIsSet turns 4 into 5.
  F.check("2F ON_TRANSITION advanced intro 4 -> 5", introState() == 5,
    "state=" .. introState())
  F.shot("2f_arrival")

  -- Clock is bg_sign at (5,1). Stand on (5,2) facing north.
  local atClock = walkTo(5, 2, "clock")
  F.check("reached the clock tile (5,2)", atClock, string.format("pos=(%d,%d)", F.pos()))
  if not atClock then F.finish(); return end
  F.face("Up")
  F.press("A", 3); F.idle(40)
  -- ClockAlreadySetElsewhere views the clock (fade) then releases. Mash B/A through the view.
  for _ = 1, 40 do F.press("A", 2); F.idle(16); F.press("B", 2); F.idle(16) end
  F.dismiss(20)
  F.shot("after_clock")
  F.check("clock-already-set branch advanced intro to 6", introState() == 6,
    "state=" .. introState())

  -- Stairs warp is (7,1) to 1F. State 5 would bounce back to 2F; 6 must let us through.
  local atStairs = walkTo(7, 1, "stairs")
  F.check("reached the 2F stairs tile (7,1)", atStairs, string.format("pos=(%d,%d)", F.pos()))
  if atStairs then
    F.face("Up")
    F.press("Up", 8); F.idle(90)
  end
  F.shot("after_stairs")
  F.check("downstairs is 1F, not a mom-bounce back onto 2F",
    F.grp() == GRP1 and F.mapn() == MAP1,
    string.format("grp=%d map=%d intro=%d", F.grp(), F.mapn(), introState()))

  F.finish()
end)
