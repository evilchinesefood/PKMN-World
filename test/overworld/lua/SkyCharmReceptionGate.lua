-- The Johto League's Reception Gate must check badges, and the League door must open, for a player
-- who flew over Route 27 with the Sky Charm.
--
-- Route 27's first-steps trigger at (25,24)/(25,25) is the only writer of VAR_ROUTE27_STATE = 1.
-- That value arms the Reception Gate's eight-badge trigger, and the Indigo Plateau Center hides the
-- Black Belt who stands on the only tile in front of Will's door once it is at least 1. The Sky
-- Charm, which Johto unlocks at the Storm Badge, flies over coord events, and Route 27 is open water
-- east of New Bark Town, so a flier reaches Route 26 with the state still 0.
--
-- Setup writes Johto badges 1-5, gives the Sky Charm and registers it on Select, and warps to New
-- Bark Town. The takeoff, the flight across Route 27 and up Route 26, the landing, the walk into the
-- Reception Gate and up to its trigger use real input. Then badges 6-8 and the theater state are
-- written, the gate is walked again, and a debug warp carries the player past Victory Road to the
-- Plateau Center, where the walk to Will's door uses real input. Last, a control re-arms Route 27's
-- trigger and walks onto it, so the fisherman's scene still runs for a walker.
--
-- Run via test/overworld/mgba-run.sh test/overworld/lua/SkyCharmReceptionGate.lua

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "SkyCharmReceptionGate")

local HUB = 100
local NEW_BARK, ROUTE27, ROUTE26, ROUTE26_NORTH = { 75, 0 }, { 98, 4 }, { 98, 0 }, { 98, 1 }
local RECEPTION_GATE, VICTORY_ROAD = { 98, 10 }, { 99, 0 }
local PLATEAU_CENTER, WILLS_ROOM = { 99, 4 }, { 99, 5 }
local ITEM_SKY_CHARM = 891
local FLAG_JOHTO_BADGE_1 = 0x63F8
local VAR_ECRUTEAK_CITY_THEATER = 0xA080 + 0x04
local VAR_ROUTE27_STATE = 0xA080 + 0x39
local CONTEXT_RUNNING, CONTEXT_SHUTDOWN = 0, 2

local function on(m) return F.grp() == m[1] and F.mapn() == m[2] end
local function flying() return F.r8(S.sFlightActive) ~= 0 end
local function where()
  local x, y = F.pos()
  return string.format("%d/%d (%d,%d) flying=%s", F.grp(), F.mapn(), x, y, tostring(flying()))
end
local function varAddr(id) return F.sb3() + S.SaveBlock3.regionVars + (id - 0xA000) * 2 end
local function getVar(id) return F.r16(varAddr(id)) end
local function flagSet(id)
  local a, b = F.sb3() + S.SaveBlock3.johtoFlags + (id - 0x6000) // 8, (id - 0x6000) % 8
  F.w8(a, F.r8(a) | (1 << b))
end
local function d(n) return (n // 100) % 10, (n // 10) % 10, n % 10 end
local function warp(m, w, tag)
  local gh, gt, go = d(m[1]); local mh, mt, mo = d(m[2]); local wh, wt, wo = d(w)
  return F.warpTo(gh, gt, go, mh, mt, mo, wh, wt, wo, m[1], m[2], tag)
end
local function hasControl()
  return F.ow() and F.r8(S.sLockFieldControls) == 0 and F.r8(S.sGlobalScriptContextStatus) == CONTEXT_SHUTDOWN
end
local SCRIPT_BUF = S.gStringVar4 + 960
local function runScript(bytes)
  for i, b in ipairs(bytes) do F.w8(SCRIPT_BUF + i - 1, b) end
  F.w8(S.sGlobalScriptContext, 0)
  F.w8(S.sGlobalScriptContext + 1, 1)
  F.w32(S.sGlobalScriptContext + 4, 0)
  F.w32(S.sGlobalScriptContext + S.ScriptCtx.scriptPtr, SCRIPT_BUF)
  F.w8(S.sGlobalScriptContextStatus, CONTEXT_RUNNING)
  for _ = 1, 200 do
    F.idle(4)
    if hasControl() then break end
  end
  F.idle(30)
end

-- One tile in `dir`; a map connection counts, since the coordinates change across it.
local function move(dir)
  local g0, m0 = F.grp(), F.mapn()
  local x0, y0 = F.pos()
  for _ = 1, 40 do
    joypad.set({ [dir] = true }); emu.frameadvance()
    local x, y = F.pos()
    if x ~= x0 or y ~= y0 or F.grp() ~= g0 or F.mapn() ~= m0 then F.idle(10); return true end
  end
  F.idle(10)
  return false
end
local function flyUntil(dir, done, limit, tag)
  for _ = 1, limit do
    if done() then return true end
    if not move(dir) then
      F.L("  FLIGHT " .. tag .. " stopped at " .. where())
      return done()
    end
  end
  return done()
end
-- Page any arrival text with B until the field is the player's again.
local function settle()
  for _ = 1, 20 do
    if hasControl() then break end
    F.press("B", 2); F.idle(30)
  end
  F.idle(20)
end
local function skyCharm(tag)
  F.press("Select", 2); F.idle(60)
  if tag then F.shot(tag) end
  F.idle(90)
  for _ = 1, 10 do
    if hasControl() then break end
    F.press("B", 2); F.idle(40)
  end
  F.idle(20)
end

-- Walk north through the gate hall from its south door. A trigger that stops the player shows text
-- and walks them back down; B pages it. Returns the northernmost row reached.
local function walkNorthThroughGate(tag)
  local north = select(2, F.pos())
  for _ = 1, 30 do
    if on(VICTORY_ROAD) then break end
    joypad.set({ Up = true }); emu.frameadvance()
    for _ = 1, 15 do joypad.set({ Up = true }); emu.frameadvance() end
    if not hasControl() then
      F.shot(tag .. "_trigger")
      for _ = 1, 40 do
        if hasControl() then break end
        F.press("B", 2); F.idle(30)
      end
      F.idle(20)
      if on(RECEPTION_GATE) then north = math.min(north, select(2, F.pos())) end
      break
    end
    if on(RECEPTION_GATE) then north = math.min(north, select(2, F.pos())) end
  end
  F.idle(60)
  return north
end

local function objectAt(x, y)
  for _, o in ipairs(F.objdump()) do
    if o.x == x and o.y == y then return true end
  end
  return false
end

F.run(function()
  if not F.boot(HUB) then F.check("boot", false); F.finish(); return end
  for b = 0, 4 do flagSet(FLAG_JOHTO_BADGE_1 + b) end
  runScript({ 0x44, ITEM_SKY_CHARM & 0xFF, ITEM_SKY_CHARM >> 8, 1, 0, 0x02 })
  F.w16(F.sb1() + S.SaveBlock1.registeredItem, ITEM_SKY_CHARM)

  if not F.check("setup: warped to New Bark Town", warp(NEW_BARK, 1, "newbark"), where()) then F.finish(); return end
  settle()
  F.check("setup: Route 27 never walked", getVar(VAR_ROUTE27_STATE) == 0, "state=" .. getVar(VAR_ROUTE27_STATE))

  skyCharm("takeoff")
  F.check("flight: took off in New Bark Town", flying(), where())
  flyUntil("Down", function() return select(2, F.pos()) >= 13 end, 4, "down")
  local crossed = flyUntil("Right", function() return on(ROUTE27) and select(1, F.pos()) >= 26 end, 40, "route27")
  F.check("flight: flew over Route 27's first-steps trigger", crossed and select(2, F.pos()) == 24, where())
  F.check("flight: flew east onto Route 26", flyUntil("Right", function() return on(ROUTE26) end, 200, "east"), where())
  flyUntil("Right", function() return select(1, F.pos()) >= 12 end, 20, "to_x12")
  flyUntil("Up", function() return on(ROUTE26_NORTH) and select(2, F.pos()) <= 7 end, 120, "north")
  skyCharm("landing")
  local x, y = F.pos()
  F.check("flight: landed below the Reception Gate's door", on(ROUTE26_NORTH) and not flying() and x == 12 and y == 7,
    where())

  for _ = 1, 90 do
    joypad.set({ Up = true }); emu.frameadvance()
    if on(RECEPTION_GATE) then break end
  end
  F.idle(90)
  settle()
  F.check("gate: entered the Reception Gate", on(RECEPTION_GATE) and F.ow(), where())
  local north = walkNorthThroughGate("five_badges")
  F.shot("five_badges_after")
  F.check("gate: five badges are turned back at the trigger", on(RECEPTION_GATE) and north >= 14 and hasControl(),
    "northmost row " .. north .. " " .. where())
  if on(RECEPTION_GATE) and north < 14 then
    F.route({ { 12, 7 }, { 12, 2 }, { 11, 2 } }, "five_to_victory_road"); F.step("Up"); F.idle(90)
  end
  F.check("gate: five badges never reach Victory Road", not on(VICTORY_ROAD), where())
  F.check("gate: walkable after the five-badge attempt", on(VICTORY_ROAD) or (F.step("Down") and F.step("Up")), where())

  for b = 5, 7 do flagSet(FLAG_JOHTO_BADGE_1 + b) end
  F.w16(varAddr(VAR_ECRUTEAK_CITY_THEATER), 8)
  for _ = 1, 60 do
    if not on(VICTORY_ROAD) then break end
    joypad.set({ Down = true }); emu.frameadvance()
  end
  F.idle(90); settle()
  if on(RECEPTION_GATE) and select(2, F.pos()) < 14 then
    F.route({ { 12, 2 }, { 12, 13 }, { 11, 13 } }, "back_south"); F.step("Down"); F.step("Down")
  end
  F.check("gate: back at the gate's south hall with eight badges", on(RECEPTION_GATE) and F.leg(11, 15), where())
  walkNorthThroughGate("eight_badges")
  if on(RECEPTION_GATE) then F.route({ { 11, 13 }, { 12, 13 }, { 12, 2 }, { 11, 2 } }, "to_victory_road"); F.step("Up"); F.idle(90) end
  F.check("gate: eight badges pass on to Victory Road", on(VICTORY_ROAD), where())

  if not F.check("plateau: warped to the Plateau Center", warp(PLATEAU_CENTER, 0, "plateau"), where()) then F.finish(); return end
  F.idle(60)
  F.route({ { 19, 12 }, { 31, 12 }, { 31, 4 }, { 32, 4 } }, "to_door")
  F.shot("plateau_door_approach")
  F.check("plateau: Silver is not waiting in the Center", not objectAt(32, 8))
  F.step("Up")
  for _ = 1, 40 do
    joypad.set({ Up = true }); emu.frameadvance()
    if on(WILLS_ROOM) then break end
  end
  F.idle(120)
  F.shot("league_door")
  F.check("plateau: the Elite Four door lets the player into Will's room", on(WILLS_ROOM), where())
  settle()

  -- Control: a walker still meets the fisherman on Route 27's first-steps tiles.
  F.w16(varAddr(VAR_ROUTE27_STATE), 0)
  F.check("walker: warped to Tohjo Falls' mouth on Route 27", warp(ROUTE27, 0, "route27"), where())
  settle()
  F.step("Down")
  F.route({ { 29, 20 }, { 29, 25 }, { 26, 25 } }, "to_first_steps")
  local stopped = false
  for _ = 1, 30 do
    joypad.set({ Left = true }); emu.frameadvance()
    if F.r8(S.sGlobalScriptContextStatus) ~= CONTEXT_SHUTDOWN then stopped = true; break end
  end
  F.idle(60)
  F.shot("walker_fisherman")
  settle()
  F.check("walker: the fisherman stops the player on the first-steps tile", stopped and on(ROUTE27), where())
  F.check("walker: the first steps arm the Reception Gate", getVar(VAR_ROUTE27_STATE) == 1,
    "state=" .. getVar(VAR_ROUTE27_STATE))
  F.check("walker: walkable after the fisherman", F.step("Left") and F.step("Right"), where())
  F.check("no_crash_screen", not F.crashSeen and not F.reportCrash("end"))
  F.finish()
end)
