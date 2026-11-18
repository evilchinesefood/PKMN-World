-- IndigoVictoryRoadExits.lua: each region's Victory Road top exit and the league town above it
-- join both ways on foot.
--
-- Johto Victory Road 1F's top exit (39,5) put the player on the Johto Indigo Plateau's south
-- stairs at (11,18). That cell is MB_ROCK_STAIRS, which fires no warp, and the stairs end at the
-- map edge one row lower with no connection, so nothing walked back into the cave. pokemonHnS
-- joins the plateau's south edge to Route 23, which holds the cave mouth.
--
-- Johto: leave Victory Road by its top exit, walk up to the plateau, then walk down its south
-- stairs to the cave mouth and back into Victory Road, which must land on the top exit again.
-- The exit's landing, Route 23's path and the stair foot are shot at 14:30 and 22:30. Kanto
-- (Indigo Plateau, Route 23, Victory Road 2F) and Hoenn (Ever Grande City, Victory Road 1F) are
-- controls: their exits already join both ways, so a failure there is the harness, not Johto's data.

package.path = (debug.getinfo(1, "S").source:sub(2):match("^(.*[/\\])") or "") .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "IndigoVictoryRoadExits")

local HUB_GROUP = 100
local CONTEXT_RUNNING = 0

local J_VR1F = { g = 99, m = 0, w = 1 }
local J_PLATEAU = { g = 99, m = 3 }
local J_ROUTE23 = { g = 99, m = 11 }
local J_STAIR_FOOT = { 11, 18 }
local J_EXIT = { 39, 5 }
local J_UP_TO_PATH = { { 21, 21 }, { 21, 17 }, { 20, 17 }, { 20, 12 } }
local J_UP_TO_PLATEAU = { { 20, 9 }, { 11, 9 }, { 11, 0 } }
local J_DOWN_TO_MOUTH = { { 11, 9 }, { 20, 9 }, { 20, 17 }, { 21, 17 }, { 21, 21 }, { 18, 21 } }

local K_PLATEAU = { g = 37, m = 9, w = 0 }
local K_ROUTE23 = { g = 37, m = 42 }
local K_VR2F = { g = 35, m = 40, w = 6 }
local H_EVER_GRANDE = { g = 0, m = 8 }
local H_VR1F = { g = 24, m = 43, w = 1 }

local function d(n) return (n // 100) % 10, (n // 10) % 10, n % 10 end
local function warp(dst, tag)
  local gh, gt, go = d(dst.g)
  local mh, mt, mo = d(dst.m)
  local wh, wt, wo = d(dst.w)
  return F.warpTo(gh, gt, go, mh, mt, mo, wh, wt, wo, dst.g, dst.m, tag)
end
local function at(dst) return F.grp() == dst.g and F.mapn() == dst.m end
local function where()
  local x, y = F.pos()
  return string.format("map %d/%d (%d,%d)", F.grp(), F.mapn(), x, y)
end
local function on(x, y) local px, py = F.pos(); return px == x and py == y end

local function hasControl()
  return F.ow() and F.r8(S.sLockFieldControls) == 0 and F.r8(S.sGlobalScriptContextStatus) ~= CONTEXT_RUNNING
end
local function awaitControl(budget)
  for _ = 1, budget or 600 do
    if hasControl() then return true end
    F.idle(1)
  end
  return false
end

-- Press `dir` from the current cell until the map changes, then wait out the warp and any door
-- exit walk. Returns whether the player left the map they started on.
local function leave(dir, tag)
  local g0, m0 = F.grp(), F.mapn()
  local function moved() return F.grp() ~= g0 or F.mapn() ~= m0 end
  for _ = 1, 8 do
    for _ = 1, 16 do joypad.set({ [dir] = true }); emu.frameadvance() end
    if moved() then break end
  end
  F.idle(1)
  for _ = 1, 200 do
    if moved() then break end
    F.idle(2)
  end
  awaitControl(600)
  F.idle(30)
  F.shot(tag)
  return moved()
end

-- Step `dir` up to `n` times, stopping on arrival at `dst`.
local function cross(dir, dst, n)
  for _ = 1, n do
    if at(dst) then return true end
    if not F.step(dir) then break end
    F.idle(10)
  end
  awaitControl(300)
  return at(dst)
end

local function clock(h, m)
  local off = F.sb2() + S.SaveBlock2.localTimeOffset
  local function seconds(p)
    return F.rs8(p + S.Time.hours) * 3600 + F.rs8(p + S.Time.minutes) * 60 + F.rs8(p + S.Time.seconds)
  end
  local value = (seconds(off) + (seconds(S.gLocalTime) - (h * 3600 + m * 60)) % 86400) % 86400
  F.w8(off + S.Time.hours, value // 3600)
  F.w8(off + S.Time.minutes, (value // 60) % 60)
  F.w8(off + S.Time.seconds, value % 60)
  F.w8(S.sHoursOverride, 0)
  F.w16(S.gTimeUpdateCounter, 0)
  F.idle(240)
end
local function dayAndNight(tag)
  clock(14, 30); F.shot(tag .. "_day")
  clock(22, 30); F.shot(tag .. "_night")
  clock(14, 30)
end

local function johto()
  F.L("== Johto: Victory Road 1F top exit and the Indigo Plateau ==")
  if not F.check("warp onto Johto Victory Road 1F's top exit", warp(J_VR1F, "j_vr1f"), where()) then return end
  F.check("lands on the top exit (39,5)", on(J_EXIT[1], J_EXIT[2]), where())

  F.check("Down on the top exit leaves Victory Road", leave("Down", "j_exit_landing"), where())
  local ox, oy = F.pos()
  local og, om = F.grp(), F.mapn()
  dayAndNight("j_exit_landing")

  if at(J_ROUTE23) then
    if F.route(J_UP_TO_PATH, "j_path") then dayAndNight("j_route23_path") end
    F.route(J_UP_TO_PLATEAU, "j_up")
    cross("Up", J_PLATEAU, 2)
  end
  F.check("walks on to the Johto Indigo Plateau", at(J_PLATEAU), where())
  F.check("reaches the foot of the plateau's south stairs (11,18)",
          at(J_PLATEAU) and F.leg(J_STAIR_FOOT[1], J_STAIR_FOOT[2]), where())
  dayAndNight("j_stair_foot")

  local downOff = cross("Down", J_ROUTE23, 3)
  F.check("walking down from the stair foot leaves the plateau", not at(J_PLATEAU), where())
  F.shot("j_stairs_down")
  local atMouth = downOff and F.route(J_DOWN_TO_MOUTH, "j_down") and on(18, 21)
  F.check("walks on to the cave mouth below the plateau", atMouth, where())
  local inside = atMouth and leave("Up", "j_mouth") and at(J_VR1F)
  F.check("the cave mouth enters Victory Road 1F", inside, where())
  F.check("and lands on its top exit (39,5)", inside and on(J_EXIT[1], J_EXIT[2]), where())

  local back = inside and leave("Down", "j_exit_again")
  F.check("the top exit leads back to the same landing", back and F.grp() == og and F.mapn() == om and on(ox, oy),
          string.format("%s, first landing map %d/%d (%d,%d)", where(), og, om, ox, oy))
end

local function kanto()
  F.L("== Kanto control: Indigo Plateau, Route 23, Victory Road 2F ==")
  if not F.check("warp to Kanto's Indigo Plateau", warp(K_PLATEAU, "k_plateau"), where()) then return end
  F.check("reaches the foot of the plateau's south stairs (11,18)", F.leg(11, 18), where())
  F.check("walking down the stairs reaches Route 23", cross("Down", K_ROUTE23, 3), where())
  F.shot("k_route23")
  if not F.check("warp onto Victory Road 2F's exit", warp(K_VR2F, "k_vr2f"), where()) then return end
  F.check("Down on the exit lands on Route 23 at (18,29)", leave("Down", "k_exit") and at(K_ROUTE23) and on(18, 29), where())
  F.check("Up into the cave mouth returns to Victory Road 2F (48,12)",
          leave("Up", "k_mouth") and at(K_VR2F) and on(48, 12), where())
end

local function hoenn()
  F.L("== Hoenn control: Victory Road 1F top exit and Ever Grande City ==")
  if not F.check("warp onto Hoenn Victory Road 1F's top exit", warp(H_VR1F, "h_vr1f"), where()) then return end
  F.check("Down on the exit lands in Ever Grande City at (18,28)",
          leave("Down", "h_exit") and at(H_EVER_GRANDE) and on(18, 28), where())
  F.check("Up into the cave mouth returns to Victory Road 1F (39,5)",
          leave("Up", "h_mouth") and at(H_VR1F) and on(39, 5), where())
end

F.run(function()
  if not F.boot(HUB_GROUP) then F.check("boot to the hub", false); F.finish(); return end
  johto()
  kanto()
  hoenn()
  F.check("no crash screen", F.crashScreen() == nil, tostring(F.crashScreen()))
  F.finish()
end)
