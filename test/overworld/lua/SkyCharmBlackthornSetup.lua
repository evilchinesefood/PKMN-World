-- Eastern Johto's first-visit setup must run for a Sky Charm flier who reaches Blackthorn City before
-- Mahogany Town.
--
-- MahoganyTown_EventScript_TownTrigger starts the story east of Ecruteak: it hides Clair, Lance and
-- Silver in Dragon's Den until their scenes and sets VAR_BLACKTHORN_CITY_STATE to 1, which arms the
-- elder's trigger in front of the Den. It runs from Route 42's east edge and from Mahogany's map
-- transition. Route 46 meets Route 29 near New Bark Town and climbs to Route 45 over one-way ledges,
-- so walkers always pass Mahogany first, but the Sky Charm (Johto's Storm Badge) flies up those
-- ledges into Blackthorn without touching Mahogany.
--
-- Setup writes Johto badges 1-5, gives the Sky Charm and registers it on Select, and warps to Route 46.
-- The takeoff, the flight up Route 46 and Route 45 into Blackthorn, the landing and the walk to the
-- Den use real input; a debug warp then looks inside the Den. Santos's gift is then taken before
-- Mahogany's first visit and asked for again after it, both talks with real input.
--
-- Run via test/overworld/mgba-run.sh test/overworld/lua/SkyCharmBlackthornSetup.lua

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "SkyCharmBlackthornSetup")

local HUB = 100
local ROUTE46, ROUTE45, BLACKTHORN = { 93, 2 }, { 93, 1 }, { 93, 0 }
local DEN_ENTRANCE, DEN_CAVERN, MAHOGANY = { 94, 13 }, { 94, 12 }, { 91, 0 }
local ITEM_SKY_CHARM, ITEM_SPELL_TAG = 891, 438
local FLAG_JOHTO_BADGE_1 = 0x63F8
local VAR_MAHOGANY_TOWN_STATE = 0xA080 + 0x11
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

local function objectAt(x, y)
  for _, o in ipairs(F.objdump()) do
    if o.x == x and o.y == y then return true end
  end
  return false
end

local function spellTags()
  local key = F.r32(F.sb2() + S.SaveBlock2.encryptionKey) & 0xFFFF
  local n = 0
  for p = 0, 4 do
    local ptr = F.r32(S.gBagPockets + p * S.BagPocket.stride)
    for slot = 0, F.pocketCap(p) - 1 do
      if F.r16(ptr + slot * 4) == ITEM_SPELL_TAG then n = n + (F.r16(ptr + slot * 4 + 2) ~ key) end
    end
  end
  return n
end

-- Walk from the Pokemon Center door to Santos and take his Saturday gift if he offers it.
local function talkToSantos(tag)
  if not warp(BLACKTHORN, 6, tag) then return false end
  settle()
  F.route({ { 23, 49 }, { 23, 40 }, { 27, 40 } }, tag .. "_walk")
  F.face("Up")
  F.press("A", 2); F.idle(30)
  F.pick(6, tag, 6)
  F.shot(tag)
  for i = 1, 60 do
    if hasControl() then break end
    F.press(i % 4 == 0 and "A" or "B", 2); F.idle(30)
  end
  F.idle(20)
  return hasControl()
end

F.run(function()
  if not F.boot(HUB) then F.check("boot", false); F.finish(); return end
  for b = 0, 4 do flagSet(FLAG_JOHTO_BADGE_1 + b) end
  runScript({ 0x44, ITEM_SKY_CHARM & 0xFF, ITEM_SKY_CHARM >> 8, 1, 0, 0x02 })
  F.w16(F.sb1() + S.SaveBlock1.registeredItem, ITEM_SKY_CHARM)

  if not F.check("setup: warped to Route 46", warp(ROUTE46, 0, "route46"), where()) then F.finish(); return end
  settle()
  F.check("setup: Mahogany never visited", getVar(VAR_MAHOGANY_TOWN_STATE) == 0,
    "state=" .. getVar(VAR_MAHOGANY_TOWN_STATE))

  skyCharm("takeoff")
  F.check("flight: took off on Route 46", flying(), where())
  flyUntil("Up", function() return select(2, F.pos()) <= 20 end, 30, "route46_north")
  F.check("flight: flew east onto Route 45", flyUntil("Right", function() return on(ROUTE45) end, 40, "east"), where())
  flyUntil("Right", function() return select(1, F.pos()) >= 31 end, 40, "to_x31")
  F.check("flight: flew north into Blackthorn City",
    flyUntil("Up", function() return on(BLACKTHORN) end, 120, "north"), where())
  flyUntil("Up", function() return select(2, F.pos()) <= 14 end, 60, "to_y14")
  flyUntil(select(1, F.pos()) < 26 and "Right" or "Left", function() return select(1, F.pos()) == 26 end, 20, "to_x26")
  skyCharm("landing")
  local x, y = F.pos()
  F.check("flight: landed below the Dragon's Den door", on(BLACKTHORN) and not flying() and x == 26 and y == 14,
    where())

  local stopped = false
  for _ = 1, 60 do
    if on(DEN_ENTRANCE) then break end
    joypad.set({ Up = true }); emu.frameadvance()
    if not hasControl() then stopped = true; break end
  end
  F.idle(30)
  F.shot("den_door")
  settle()
  F.check("blackthorn: the elder turns the player back from the Den", stopped and on(BLACKTHORN), where())
  F.check("blackthorn: walkable after the elder", on(DEN_ENTRANCE) or (F.step("Down") and F.step("Up")), where())

  if not F.check("den: warped into Dragon's Den", warp(DEN_CAVERN, 0, "den"), where()) then F.finish(); return end
  settle()
  F.leg(31, 12)
  F.idle(30)
  F.shot("den_cavern")
  F.check("den: Clair is not waiting before her scene", not objectAt(29, 14))

  F.check("santos: first talk returns control", talkToSantos("santos_first"), where())
  F.check("santos: gives one Spell Tag", spellTags() == 1, "count=" .. spellTags())
  F.check("mahogany: first visit by warp", warp(MAHOGANY, 0, "mahogany"), where())
  settle()
  F.check("santos: second talk returns control", talkToSantos("santos_second"), where())
  F.check("santos: still one Spell Tag after Mahogany's first visit", spellTags() == 1, "count=" .. spellTags())
  F.check("no_crash_screen", not F.crashSeen and not F.reportCrash("end"))
  F.finish()
end)
