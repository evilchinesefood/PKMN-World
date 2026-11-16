-- Mahogany Town's first-visit setup (MahoganyTown_EventScript_TownTrigger) ran only from coord
-- events on Route 42's east edge. The Sky Charm, which Johto unlocks at the sixth badge, flies over
-- coord events, and Mahogany is the next gym, so a player who flew in from Route 42 skipped it:
-- Lance stood at the Lake of Rage before the red Gyarados, the Rocket hideout and Dragon's Den
-- actors were never hidden, and Blackthorn's story never started. Entering the town now runs the
-- setup. The suite takes off on Route 42 outside Mt. Mortar, flies east into Mahogany, lands, and
-- then looks at the Lake of Rage.
--
-- Run via test/overworld/mgba-run.sh test/overworld/lua/SkyCharmMahoganySetup.lua <rom>

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "SkyCharmMahoganySetup")

local HUB = 100
local MAHOGANY, ROUTE42, LAKE_OF_RAGE = { 91, 0 }, { 91, 1 }, { 91, 4 }
local ITEM_SKY_CHARM = 891
local FLAG_JOHTO_BADGE_1 = 0x63F8
local FLAG_HIDE_LAKE_OF_RAGE_LANCE = 0x6000 + 0x16F
local FLAG_HIDE_DRAGONS_DEN_CAVERN_LANCE = 0x6000 + 0x16A
local FLAG_VISITED_MAHOGANY_TOWN = 0x6000 + 0x189
local VAR_MAHOGANY_TOWN_STATE = 0xA080 + 0x11
local VAR_BLACKTHORN_CITY_STATE = 0xA080 + 0x2B
local CONTEXT_RUNNING, CONTEXT_SHUTDOWN = 0, 2

local function mapIs(m) return F.grp() == m[1] and F.mapn() == m[2] end
local function flying() return F.r8(S.sFlightActive) ~= 0 end
local function where()
  local x, y = F.pos()
  return string.format("%d/%d (%d,%d) flying=%s", F.grp(), F.mapn(), x, y, tostring(flying()))
end
local function getVar(id) return F.r16(F.sb3() + S.SaveBlock3.regionVars + (id - 0xA000) * 2) end
local function flagAddr(id)
  if id >= 0x6000 and id < 0x6400 then return F.sb3() + S.SaveBlock3.johtoFlags + (id - 0x6000) // 8, (id - 0x6000) % 8 end
  return F.sb1() + S.SaveBlock1.flags + id // 8, id % 8
end
local function flagGet(id) local a, b = flagAddr(id); return (F.r8(a) >> b) & 1 == 1 end
local function flagSet(id) local a, b = flagAddr(id); F.w8(a, F.r8(a) | (1 << b)) end
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
local function move(dir)
  local x0, y0, g0, m0 = F.pos(); g0, m0 = F.grp(), F.mapn()
  for _ = 1, 30 do
    joypad.set({ [dir] = true }); emu.frameadvance()
    local x, y = F.pos()
    if x ~= x0 or y ~= y0 or F.grp() ~= g0 or F.mapn() ~= m0 then F.idle(24); return true end
  end
  F.idle(10)
  return false
end
local function skyCharm()
  F.press("Select", 2); F.idle(150)
  for _ = 1, 10 do
    if hasControl() then break end
    F.press("B", 2); F.idle(40)
  end
  F.idle(20)
end

F.run(function()
  if not F.boot(HUB) then F.check("boot", false); F.finish(); return end
  for i = 0, 5 do flagSet(FLAG_JOHTO_BADGE_1 + i) end
  runScript({ 0x44, ITEM_SKY_CHARM & 0xFF, ITEM_SKY_CHARM >> 8, 1, 0, 0x02 })
  F.w16(F.sb1() + S.SaveBlock1.registeredItem, ITEM_SKY_CHARM)

  F.check("route42: warped to the Mt. Mortar door on Route 42", warp(ROUTE42, 3, "route42"), where())
  move("Down")
  F.check("route42: Mahogany is still unvisited", getVar(VAR_MAHOGANY_TOWN_STATE) == 0,
    "state=" .. getVar(VAR_MAHOGANY_TOWN_STATE))
  skyCharm()
  F.check("route42: took off with the Sky Charm", flying(), where())
  for _ = 1, 40 do
    if mapIs(MAHOGANY) and select(1, F.pos()) >= 10 then break end
    if not move("Right") then break end
  end
  F.check("flight: flew east into Mahogany", mapIs(MAHOGANY), where())
  local x, y = F.pos()
  for _ = 1, 4 do
    if y == 9 then break end
    move(y < 9 and "Down" or "Up"); x, y = F.pos()
  end
  skyCharm()
  F.shot("mahogany_landed")
  F.check("flight: landed in Mahogany", mapIs(MAHOGANY) and not flying(), where())
  F.check("mahogany: the town's first-visit setup ran", getVar(VAR_MAHOGANY_TOWN_STATE) >= 1,
    "state=" .. getVar(VAR_MAHOGANY_TOWN_STATE))
  F.check("mahogany: the town is recorded as visited", flagGet(FLAG_VISITED_MAHOGANY_TOWN))
  F.check("mahogany: Lance waits off the Lake of Rage until the red Gyarados",
    flagGet(FLAG_HIDE_LAKE_OF_RAGE_LANCE))
  F.check("mahogany: Dragon's Den's Lance is hidden", flagGet(FLAG_HIDE_DRAGONS_DEN_CAVERN_LANCE))
  F.check("mahogany: Blackthorn's story is started", getVar(VAR_BLACKTHORN_CITY_STATE) >= 1,
    "blackthorn=" .. getVar(VAR_BLACKTHORN_CITY_STATE))

  F.check("lake: warped to the Lake of Rage", warp(LAKE_OF_RAGE, 0, "lake"), where())
  F.idle(60)
  F.shot("lake_of_rage")
  local lance = false
  for _, o in ipairs(F.objdump()) do
    if (o.x == 30 or o.x == 31) and o.y == 37 then lance = true end
  end
  F.check("lake: nobody stands on Lance's tiles before the Gyarados", not lance)
  F.finish()
end)
