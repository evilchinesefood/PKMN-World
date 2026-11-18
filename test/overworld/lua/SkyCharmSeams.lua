-- The Sky Charm must not carry the player across two map seams: into Route 28 while the Reception
-- Gate's guard still blocks the way to Mt. Silver, and into Saffron's stand-in at any time.
--
-- The guard (ReceptionGate obj 2) stands until the Johto Hall of Fame sets
-- FLAG_INDIGOJUNCTION_HIDE_SILVER_GUARD, the flag the Hub's Mt. Silver arrival also reads. Route 28
-- joins Route 26 North by a seam walkers never reach, but the Sky Charm (Johto's Storm Badge) flew
-- over it. Five badges reached Mt. Silver, its Center and the summit, where Red's win runs GameClear
-- (the Hall of Fame, champion ribbons, the any-region game-clear flag) before any League.
--
-- Routes 5 to 8 connect to SaffronCity_Connection_Frlg, scenery drawn in place of the walled city,
-- with no people, doors or warps; the real city is entered through its gatehouses. A flier entered
-- it, and so did a walker stepping off the sealed pockets those routes keep beside each seam.
--
-- Setup writes badges, gives the Sky Charm on Select and warps; every takeoff, flight, landing and
-- step uses real input. Two controls: a player already on Mt. Silver (a save that flew in before)
-- still flies home over Route 28, and after the Hall of Fame's own first-clear script the flight
-- from Route 26 North reaches Mt. Silver.
--
-- Run via test/overworld/mgba-run.sh test/overworld/lua/SkyCharmSeams.lua

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "SkyCharmSeams")

local HUB = 100
local ROUTE26, ROUTE26_NORTH, ROUTE28 = { 98, 0 }, { 98, 1 }, { 97, 10 }
local MT_SILVER, MT_SILVER_CENTER = { 97, 0 }, { 97, 9 }
local ROUTE5, ROUTE6, ROUTE7, ROUTE8 = { 37, 23 }, { 37, 24 }, { 37, 25 }, { 37, 26 }
local STAND_IN = { 37, 11 }
local ITEM_SKY_CHARM = 891
local FLAG_JOHTO_BADGE_1 = 0x63F8
local FLAG_KANTO_BADGE_3 = 0xA40 + 0x0D
local FLAG_GUARD_GONE = 0x6000 + 0x1E5
local CONTEXT_RUNNING, CONTEXT_SHUTDOWN = 0, 2

local function on(m) return F.grp() == m[1] and F.mapn() == m[2] end
local function flying() return F.r8(S.sFlightActive) ~= 0 end
local function where()
  local x, y = F.pos()
  return string.format("%d/%d (%d,%d) flying=%s", F.grp(), F.mapn(), x, y, tostring(flying()))
end
local function johtoFlag(id)
  local a, b = F.sb3() + S.SaveBlock3.johtoFlags + (id - 0x6000) // 8, (id - 0x6000) % 8
  return a, b
end
local function johtoFlagSet(id) local a, b = johtoFlag(id); F.w8(a, F.r8(a) | (1 << b)) end
local function johtoFlagGet(id) local a, b = johtoFlag(id); return (F.r8(a) >> b) & 1 == 1 end
local function flagSet(id) local a = F.sb1() + S.SaveBlock1.flags + id // 8; F.w8(a, F.r8(a) | (1 << (id % 8))) end
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

-- One tile in `dir`; a map seam counts, since the map changes across it.
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
local function goUntil(dir, done, limit, tag)
  for _ = 1, limit do
    if done() then return true end
    if not move(dir) then
      F.L("  " .. tag .. " stopped at " .. where())
      F.idle(40)
      return done()
    end
  end
  return done()
end
-- Press on in `dir` until the player stops; returns the map the player ends on.
local function pressOn(dir, tag)
  for _ = 1, 30 do
    if not move(dir) then break end
  end
  F.idle(40)
  F.L("  " .. tag .. " ended at " .. where())
  return F.grp(), F.mapn()
end
local function settle()
  for _ = 1, 20 do
    if hasControl() then break end
    F.press("B", 4); F.idle(30)
  end
  F.idle(20)
end
local function skyCharm(tag)
  F.press("Select", 4); F.idle(60)
  if tag then F.shot(tag) end
  F.idle(90)
  for _ = 1, 10 do
    if hasControl() then break end
    F.press("B", 4); F.idle(40)
  end
  F.idle(20)
end
local function mtSilverClosed()
  if not F.check("silver: warped to Route 26 North", warp(ROUTE26_NORTH, 0, "route26north"), where()) then return end
  settle()
  F.check("silver: the guard still stands", not johtoFlagGet(FLAG_GUARD_GONE))
  skyCharm("silver_takeoff")
  F.check("silver: took off on Route 26 North", flying(), where())
  goUntil("Left", function() return not on(ROUTE26_NORTH) end, 20, "west")
  F.shot("silver_west")
  F.check("silver: five badges are stopped at Route 26 North's west edge", on(ROUTE26_NORTH) and select(1, F.pos()) == 0,
    where())
  if on(ROUTE28) then goUntil("Right", function() return on(ROUTE26_NORTH) end, 20, "back") end
  goUntil("Right", function() return on(ROUTE26_NORTH) and select(1, F.pos()) >= 12 end, 20, "to_door")
  goUntil("Down", function() return select(2, F.pos()) >= 7 end, 2, "below_trigger")
  skyCharm("silver_land")
  F.check("silver: landed below the Reception Gate's door", on(ROUTE26_NORTH) and not flying(), where())
  F.check("silver: walkable after the landing", not flying() and F.step("Down") and F.step("Up"), where())

  skyCharm("seam_takeoff")
  local south = goUntil("Down", function() return on(ROUTE26) end, 40, "south")
  F.check("seam: flight still crosses an open seam, Route 26 North into Route 26", south and flying(), where())
end

-- A save that flew to Mt. Silver before the seam closed still flies home over Route 28.
local function mtSilverSideOpen()
  if not F.check("silver side: warped to Mt. Silver", warp(MT_SILVER, 0, "mt_silver"), where()) then return end
  settle()
  F.step("Down")
  skyCharm("silver_side_takeoff")
  F.check("silver side: took off on Mt. Silver", flying(), where())
  goUntil("Down", function() return select(2, F.pos()) >= 16 end, 10, "silver_side_row")
  local r28 = goUntil("Right", function() return on(ROUTE28) end, 50, "silver_side_east")
  F.check("silver side: flight crosses east into Route 28 before the guard leaves", r28, where())
  goUntil("Down", function() return select(2, F.pos()) >= 29 end, 25, "silver_side_down")
  local home = goUntil("Right", function() return on(ROUTE26_NORTH) end, 80, "silver_side_home")
  F.check("silver side: and on into Route 26 North", home, where())
end

local function saffron()
  flagSet(FLAG_KANTO_BADGE_3)
  if not F.check("saffron: warped to Route 5's gatehouse door", warp(ROUTE5, 2, "route5"), where()) then return end
  settle()
  F.step("Up")
  skyCharm("route5_takeoff")
  F.check("saffron: took off on Route 5", flying(), where())
  goUntil("Down", function() return not on(ROUTE5) end, 20, "route5_south")
  F.shot("route5_south")
  F.check("saffron: flight from Route 5 stops at its south edge", on(ROUTE5) and select(2, F.pos()) == 39, where())
  if on(STAND_IN) then move("Up") end
  skyCharm("route5_pocket_land")
  F.check("saffron: landed in Route 5's pocket below the gatehouse", on(ROUTE5) and not flying(), where())
  local g, m = pressOn("Down", "route5_pocket_walk")
  F.check("saffron: walking south out of Route 5's pocket stays on Route 5", g == ROUTE5[1] and m == ROUTE5[2], where())
  F.check("saffron: never inside the stand-in from Route 5", not on(STAND_IN), where())
  if on(STAND_IN) then pressOn("Up", "route5_back") end
  skyCharm("route5_pocket_takeoff")
  F.check("saffron: the Sky Charm lifts off from Route 5's pocket", flying(), where())

  if not F.check("saffron: warped to Route 6's gatehouse door", warp(ROUTE6, 1, "route6"), where()) then return end
  settle()
  skyCharm("route6_takeoff")
  local x6 = select(1, F.pos())
  goUntil("Up", function() return not on(ROUTE6) end, 20, "route6_north")
  F.shot("route6_north")
  F.check("saffron: flight from Route 6 stops at its north edge in the same column",
    on(ROUTE6) and select(2, F.pos()) == 0 and select(1, F.pos()) == x6, where())
  if on(STAND_IN) then
    goUntil("Down", function() return on(ROUTE6) end, 10, "route6_back")
    F.L("  back on Route 6 at " .. where() .. ", took off at x=" .. x6)
  end

  if not F.check("saffron: warped to Route 8's gatehouse door", warp(ROUTE8, 1, "route8"), where()) then return end
  settle()
  skyCharm("route8_takeoff")
  goUntil("Left", function() return not on(ROUTE8) end, 20, "route8_west")
  F.check("saffron: flight from Route 8 stops at its west edge", on(ROUTE8) and select(1, F.pos()) == 0, where())
  if on(STAND_IN) then move("Right") end
  skyCharm("route8_pocket_land")
  g, m = pressOn("Left", "route8_pocket_walk")
  F.shot("route8_pocket_walk")
  F.check("saffron: walking west out of Route 8's pocket stays on Route 8", g == ROUTE8[1] and m == ROUTE8[2], where())

  if not F.check("saffron: warped to Route 7's gatehouse door", warp(ROUTE7, 1, "route7"), where()) then return end
  settle()
  skyCharm("route7_takeoff")
  goUntil("Up", function() return select(2, F.pos()) <= 9 end, 5, "route7_row")
  goUntil("Right", function() return not on(ROUTE7) end, 20, "route7_east")
  F.check("saffron: flight from Route 7 stops at its east edge", on(ROUTE7) and select(1, F.pos()) == 23, where())
  if on(STAND_IN) then move("Left") end
  skyCharm("route7_pocket_land")
  g, m = pressOn("Right", "route7_pocket_walk")
  F.check("saffron: walking east out of Route 7's pocket stays on Route 7", g == ROUTE7[1] and m == ROUTE7[2], where())
  F.check("saffron: walkable in Route 7's pocket", F.step("Left") and F.step("Right"), where())
end

local function mtSilverOpen()
  runScript({ 0x04, S.JohtoPokemonLeague_HallOfFame_EventScript_SetFirstGameClearFlags & 0xFF,
    (S.JohtoPokemonLeague_HallOfFame_EventScript_SetFirstGameClearFlags >> 8) & 0xFF,
    (S.JohtoPokemonLeague_HallOfFame_EventScript_SetFirstGameClearFlags >> 16) & 0xFF,
    (S.JohtoPokemonLeague_HallOfFame_EventScript_SetFirstGameClearFlags >> 24) & 0xFF, 0x02 })
  F.check("champion: the Hall of Fame's first clear sends the guard away", johtoFlagGet(FLAG_GUARD_GONE))
  if not F.check("champion: warped to Route 26 North", warp(ROUTE26_NORTH, 0, "route26north_champ"), where()) then return end
  settle()
  skyCharm("champ_takeoff")
  local crossed = goUntil("Left", function() return on(ROUTE28) end, 20, "champ_west")
  F.check("champion: flight crosses into Route 28", crossed, where())
  goUntil("Up", function() return select(2, F.pos()) <= 10 end, 40, "champ_up")
  F.check("champion: flight crosses into Mt. Silver", goUntil("Left", function() return on(MT_SILVER) end, 80, "champ_mt"),
    where())
  goUntil("Left", function() return select(1, F.pos()) <= 25 end, 40, "champ_center_x")
  goUntil("Down", function() return select(2, F.pos()) >= 15 end, 10, "champ_center_y")
  skyCharm("champ_land")
  for _ = 1, 60 do
    joypad.set({ Up = true }); emu.frameadvance()
    if on(MT_SILVER_CENTER) then break end
  end
  F.idle(90); settle()
  F.shot("champ_center")
  F.check("champion: walked into the Mt. Silver Pokemon Center", on(MT_SILVER_CENTER) and hasControl(), where())
end

F.run(function()
  if not F.boot(HUB) then F.check("boot", false); F.finish(); return end
  for b = 0, 4 do johtoFlagSet(FLAG_JOHTO_BADGE_1 + b) end
  runScript({ 0x44, ITEM_SKY_CHARM & 0xFF, ITEM_SKY_CHARM >> 8, 1, 0, 0x02 })
  F.w16(F.sb1() + S.SaveBlock1.registeredItem, ITEM_SKY_CHARM)

  mtSilverClosed()
  mtSilverSideOpen()
  saffron()
  mtSilverOpen()
  F.check("no_crash_screen", not F.crashSeen and not F.reportCrash("end"))
  F.finish()
end)
