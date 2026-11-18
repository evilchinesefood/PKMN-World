-- The Hoenn League's door guards must want all eight Hoenn badges, because the Sky Charm flies over
-- the Ever Grande waterfall that used to stand in for badges seven and eight.
--
-- Emerald's guards check only the Feather Badge: the city sits above a waterfall, Waterfall needs
-- the Rain Badge, and Juan's gym needs Dive, which needs the Mind Badge. The Sky Charm needs only
-- the Feather Badge, so a six-badge player can fly from Mossdeep to the League door. Once that
-- player is champion, Tate and Liza go straight to their rematch offer and never award the Mind
-- Badge, so Team Magma never reaches the Space Center, Steven never gives Dive, and the rest of
-- Hoenn's story is shut for good.
--
-- Setup writes badges 1-6, gives the Sky Charm and registers it on Select, and warps to Mossdeep.
-- The takeoff, the flight through Route 127, Route 128 and over the waterfall, the landing, the
-- League door and both talks to the guard use real input.
--
-- Run via test/overworld/mgba-run.sh test/overworld/lua/SkyCharmLeagueGate.lua

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "SkyCharmLeagueGate")

local HUB_GROUP = 100
local MOSSDEEP = { 0, 6 }
local ROUTE128 = { 0, 43 }
local EVER_GRANDE = { 0, 8 }
local LEAGUE_1F = { 16, 10 }
local ITEM_SKY_CHARM = 891
local FLAG_BADGE01_GET = 0x948 + 7 -- SYSTEM_FLAGS + 7
local FLAG_ENTERED_ELITE_FOUR = 0x107
local LOCALID_LEAGUE_GUARD_1, LOCALID_LEAGUE_GUARD_2 = 3, 4
local CONTEXT_RUNNING, CONTEXT_SHUTDOWN = 0, 2

local function d(n) return (n // 100) % 10, (n // 10) % 10, n % 10 end
local function flagGet(id) return (F.r8(F.sb1() + S.SaveBlock1.flags + id // 8) >> (id % 8)) & 1 == 1 end
local function flying() return F.r8(S.sFlightActive) ~= 0 end
local function hasControl()
  return F.ow() and F.r8(S.sLockFieldControls) == 0 and F.r8(S.sGlobalScriptContextStatus) == CONTEXT_SHUTDOWN
end
local function on(map) return F.grp() == map[1] and F.mapn() == map[2] end
local function where()
  local x, y = F.pos()
  return string.format("%d/%d (%d,%d) flying=%s", F.grp(), F.mapn(), x, y, tostring(flying()))
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
local function setflag(id) runScript({ 0x29, id & 0xFF, id >> 8, 0x02 }) end

local function warpToCoords(map, x, y, tag)
  for _ = 1, 4 do
    F.dbg(); F.sel(0); F.sel(1); F.idle(20)
    F.spin(d(map[1])); F.spin(d(map[2]))
    F.press("A", 2)
    for _ = 1, 400 do
      F.w8(S.sWarpDestination + 2, 0xFF)
      F.w16(S.sWarpDestination + 4, x)
      F.w16(S.sWarpDestination + 6, y)
      F.idle(1)
      local px, py = F.pos()
      if F.ow() and on(map) and px == x and py == y then
        F.idle(120)
        F.L("  WARP " .. tag .. " ok " .. where())
        return true
      end
    end
    F.bOut(5)
  end
  F.shot(tag .. "_warpfail")
  return false
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

local function guardAt(localId)
  for i = 0, 15 do
    local b = S.gObjectEvents + i * S.ObjectEvent.stride
    if (F.r8(b) & 1) == 1 and F.r8(b + S.ObjectEvent.localId) == localId then
      return F.rs16(b + S.ObjectEvent.x) - 7, F.rs16(b + S.ObjectEvent.y) - 7
    end
  end
end
local function guardsBlocking()
  local x1, y1 = guardAt(LOCALID_LEAGUE_GUARD_1)
  local x2, y2 = guardAt(LOCALID_LEAGUE_GUARD_2)
  return x1 == 9 and y1 == 2 and x2 == 10 and y2 == 2,
    string.format("guards (%s,%s) (%s,%s)", tostring(x1), tostring(y1), tostring(x2), tostring(y2))
end

-- Talk to the left guard from (9,3) and wait for the script to hand control back.
local function talkToGuard(tag)
  F.face("Up")
  F.press("A", 2)
  local started = false
  for i = 1, 600 do
    F.idle(4)
    if F.r8(S.sGlobalScriptContextStatus) ~= CONTEXT_SHUTDOWN then started = true end
    if started and hasControl() then break end
    -- B pages the text but never talks again once the script has ended.
    if started and i % 6 == 0 then F.press("B", 2) end
  end
  F.idle(30)
  F.shot(tag)
  return started and hasControl()
end

F.run(function()
  if not F.boot(HUB_GROUP) then F.check("boot", false); F.finish(); return end
  if not F.check("warp_to_mossdeep", warpToCoords(MOSSDEEP, 55, 34, "mossdeep")) then F.finish(); return end
  for b = 0, 5 do setflag(FLAG_BADGE01_GET + b) end
  runScript({ 0x44, ITEM_SKY_CHARM & 0xFF, ITEM_SKY_CHARM >> 8, 1, 0, 0x02 })
  F.w16(F.sb1() + S.SaveBlock1.registeredItem, ITEM_SKY_CHARM)
  local badges = 0
  for b = 0, 7 do if flagGet(FLAG_BADGE01_GET + b) then badges = badges + 1 end end
  F.check("setup_six_hoenn_badges", badges == 6 and flagGet(FLAG_BADGE01_GET + 5) and not flagGet(FLAG_BADGE01_GET + 6),
    badges .. " badges")

  skyCharm("takeoff")
  F.check("took_off_in_mossdeep", flying(), where())
  local south = flyUntil("Down", function() local _, y = F.pos(); return on(ROUTE128) and y >= 20 end, 200, "south")
  F.check("flew_south_to_route_128", south, where())
  local east = flyUntil("Right", function() return on(EVER_GRANDE) end, 120, "east")
  F.check("flew_into_ever_grande_below_the_waterfall", east, where())
  flyUntil("Right", function() local x = F.pos(); return x >= 18 end, 30, "to_x18")
  flyUntil("Up", function() local _, y = F.pos(); return y <= 6 end, 80, "north")
  local x, y = F.pos()
  F.check("over_the_league_door_approach", flying() and on(EVER_GRANDE) and x == 18 and y == 6, where())
  skyCharm("landing")
  x, y = F.pos()
  F.check("landed_in_front_of_the_league", not flying() and on(EVER_GRANDE) and x == 18 and y == 6, where())
  F.shot("landed")

  for _ = 1, 120 do
    joypad.set({ Up = true }); emu.frameadvance()
    if on(LEAGUE_1F) then break end
  end
  F.idle(120)
  F.check("entered_league_1f", on(LEAGUE_1F) and F.ow(), where())
  F.leg(9, 3)
  x, y = F.pos()
  F.check("reached_the_guards", on(LEAGUE_1F) and x == 9 and y == 3, where())
  local blocking, gd = guardsBlocking()
  F.check("guards_block_the_door_before_the_talk", blocking, gd)

  F.check("six_badge_talk_returns_control", talkToGuard("six_badges"), where())
  blocking, gd = guardsBlocking()
  F.check("six_badges_refused", not flagGet(FLAG_ENTERED_ELITE_FOUR) and blocking,
    string.format("FLAG_ENTERED_ELITE_FOUR=%s %s", tostring(flagGet(FLAG_ENTERED_ELITE_FOUR)), gd))
  F.check("six_badges_walkable_after", F.step("Down") and F.step("Up"), where())

  setflag(FLAG_BADGE01_GET + 6)
  setflag(FLAG_BADGE01_GET + 7)
  F.check("eight_badge_talk_returns_control", talkToGuard("eight_badges"), where())
  blocking, gd = guardsBlocking()
  F.check("eight_badges_admitted", flagGet(FLAG_ENTERED_ELITE_FOUR) and not blocking,
    string.format("FLAG_ENTERED_ELITE_FOUR=%s %s", tostring(flagGet(FLAG_ENTERED_ELITE_FOUR)), gd))
  F.check("no_crash_screen", not F.crashSeen and not F.reportCrash("end"))

  F.finish()
end)
