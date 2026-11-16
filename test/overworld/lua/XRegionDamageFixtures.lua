-- Fixture producer, not a regression suite: it must run on a build from BEFORE the cross-region
-- fixes (#602 Goldenrod's reset of FLAG_RECEIVED_BIKE, #604 the PokeGear setting
-- FLAG_RECEIVED_POKENAV), from inside that build's own tree, so the damage in the save is the
-- damage the old scripts wrote. test/overworld/lua/fixtures/v12xregion.md records the commit, the
-- ROM and the command line for each fixture.
--
-- PW_XREGION_CASE=damaged  Johto first (the mother's PokeGear), Rydel's Mach Bike, the first walk
--                          into Goldenrod, then Hoenn with the first badge: the Rustboro Center,
--                          out by Hub Pass and back through the Hoenn gate, which docks Mr. Briney
--                          and Peeko in the cottage. Saves inside the cottage with both standing.
-- PW_XREGION_CASE=voyage   The same PokeGear and Hoenn path without a bike (Goldenrod is still
--                          visited), then Mr. Briney, home too early, sails the player to Dewford.
--                          Saves in Dewford.
--
-- Run (inside the old build's tree):
--   test/overworld/mgba-run.sh --env PW_XREGION_CASE=damaged test/overworld/lua/XRegionDamageFixtures.lua pokemonworld.gba
-- then copy <case-dir>/emulator/Verify1.sav out as the fixture.

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "XRegionDamageFixtures")
local CASE = os.getenv("PW_XREGION_CASE") or "damaged"

local HUB = { 100, 0 }
local HOUSE_1F = { 76, 3 }
local MAUVILLE_BIKE_SHOP = { 10, 1 }
local GOLDENROD = { 83, 0 }
local RUSTBORO_CENTER = { 11, 5 }
local BRINEYS_HOUSE = { 17, 0 }
local DEWFORD = { 0, 11 }
local ITEM_MACH_BIKE, ITEM_ACRO_BIKE = 707, 708
local VAR_NEWBARK_TOWN_STATE = 0xA080
local VAR_GOLDENROD_CITY_STATE = 0xA083
local VAR_BRINEY_LOCATION = 0x4096
local FLAG_RECEIVED_BIKE = 0x5A
local FLAG_RECEIVED_POKENAV = 0xBC
local FLAG_BADGE01_GET = 0x94F
local FLAG_VISITED_DEWFORD_TOWN = 0x959
local FLAG_HIDE_BRINEYS_HOUSE_MR_BRINEY = 0x2E3
local LOCALID_BRINEY = 1
local USM_ICO_SAVE = 7
local SENTINEL = 0xFFFF
local CONTEXT_RUNNING = 0
local hubPass

local function where() local x, y = F.pos(); return string.format("%d/%d (%d,%d)", F.grp(), F.mapn(), x, y) end
local function mapIs(m) return F.grp() == m[1] and F.mapn() == m[2] end
local function varAddr(id)
  if id >= 0xA000 then return F.sb3() + S.SaveBlock3.regionVars + (id - 0xA000) * 2 end
  return F.sb1() + S.SaveBlock1.vars + (id - 0x4000) * 2
end
local function getVar(id) return F.r16(varAddr(id)) end
local function flagGet(id) return (F.r8(F.sb1() + S.SaveBlock1.flags + id // 8) >> (id % 8)) & 1 == 1 end
local function flagSet(id) local a = F.sb1() + S.SaveBlock1.flags + id // 8; F.w8(a, F.r8(a) | (1 << (id % 8))) end
local function d(n) return (n // 100) % 10, (n // 10) % 10, n % 10 end
local function warp(m, w, tag)
  local gh, gt, go = d(m[1]); local mh, mt, mo = d(m[2]); local wh, wt, wo = d(w)
  return F.warpTo(gh, gt, go, mh, mt, mo, wh, wt, wo, m[1], m[2], tag)
end
local function qty(id)
  local key = F.r32(F.sb2() + S.SaveBlock2.encryptionKey) & 0xFFFF
  local ptr = F.r32(S.gBagPockets + 4 * S.BagPocket.stride)
  local n = 0
  for s = 0, F.pocketCap(4) - 1 do
    if F.r16(ptr + s * 4) == id then n = n + (F.r16(ptr + s * 4 + 2) ~ key) end
  end
  return n
end
local function bikeStr() return string.format("mach=%d acro=%d", qty(ITEM_MACH_BIKE), qty(ITEM_ACRO_BIKE)) end

local SCRIPT_BUF = S.gStringVar4 + 960
local function le16(t, v) t[#t + 1] = v & 0xFF; t[#t + 1] = (v >> 8) & 0xFF end
local function le32(t, v) le16(t, v & 0xFFFF); le16(t, (v >> 16) & 0xFFFF) end
local function runScript(bytes)
  for i, b in ipairs(bytes) do F.w8(SCRIPT_BUF + i - 1, b) end
  F.w8(S.sGlobalScriptContext, 0)
  F.w8(S.sGlobalScriptContext + 1, 1)
  F.w32(S.sGlobalScriptContext + 4, 0)
  F.w32(S.sGlobalScriptContext + S.ScriptCtx.scriptPtr, SCRIPT_BUF)
  F.w8(S.sGlobalScriptContextStatus, CONTEXT_RUNNING)
  F.idle(20)
end
local function createMon(species, level)
  local b = { 0x23 }; le32(b, S.ScrCmd_createmon | 1)
  b[#b + 1] = 0; b[#b + 1] = 6
  le16(b, species); le16(b, level)
  le32(b, (1 << 17) | (1 << 18) | (1 << 19) | (1 << 20))
  for _ = 1, 4 do le16(b, 0) end
  b[#b + 1] = 0x02
  runScript(b)
end
local function hasControl()
  return F.ow() and F.r8(S.sLockFieldControls) == 0 and F.r8(S.sGlobalScriptContextStatus) ~= CONTEXT_RUNNING
end
local function waitControl(n)
  for _ = 1, n or 600 do if hasControl() then return true end; F.idle(1) end
  return hasControl()
end
local function scriptMenuActive()
  for i = 0, S.Task.count - 1 do
    local a = S.gTasks + i * S.Task.stride
    local fn = F.r32(a + S.Task.func) & 0xFFFFFFFE
    if F.r8(a + S.Task.isActive) ~= 0 and (fn == S.Task_HandleYesNoInput or fn == S.Task_HandleMultichoiceInput or fn == S.Task_CallYesOrNoCallback) then return true end
  end
  return false
end
local function menu(want, tag, maxA)
  for _ = 1, (maxA or 65) do
    if F.reportCrash(tag) then return false end
    if scriptMenuActive() then
      F.idle(12)
      for _ = 1, 10 do
        local c = F.mcur()
        if c == want then
          F.shot(tag)
          for _ = 1, 4 do
            F.press("A", 2)
            for _ = 1, 30 do
              if not scriptMenuActive() then F.idle(30); return true end
              F.idle(1)
            end
          end
          return false
        end
        F.press(c > want and "Up" or "Down", 2); F.idle(12)
      end
      return false
    end
    F.press("A", 2); F.idle(25)
  end
  F.shot(tag .. "_nomenu")
  return false
end
local function awaitMap(m, tag, budget)
  for _ = 1, budget or 400 do
    if mapIs(m) and F.ow() then F.idle(100); return true end
    if F.reportCrash(tag) then return false end
    F.press("A", 2); F.idle(14)
  end
  F.shot(tag .. "_failed")
  return false
end
local function awaitGroup(g, tag)
  for _ = 1, 400 do
    if F.grp() == g and F.ow() then F.idle(100); return true end
    if F.reportCrash(tag) then return false end
    F.press("A", 2); F.idle(14)
  end
  F.shot(tag .. "_failed")
  return false
end
local function drain()
  for _ = 1, 60 do
    if hasControl() then return true end
    F.press("B", 2); F.idle(16)
  end
  return hasControl()
end
local function crossGate(path, tag)
  if not F.route(path, tag .. "_walk") then return false end
  F.face("Up"); F.press("A", 3); F.idle(60)
  return menu(0, tag .. "_yes")
end
local function useHubPass(tag)
  F.w16(F.sb1() + S.SaveBlock1.registeredItem, hubPass)
  F.press("Select", 2); F.idle(90)
  return menu(0, tag .. "_hub_pass") and awaitMap(HUB, tag .. "_hub")
end
local function talk(dir, tag)
  F.face(dir)
  F.press("A", 2)
  local started = false
  for _ = 1, 120 do
    if not hasControl() then started = true; break end
    F.idle(1)
  end
  if not started then return false end
  for _ = 1, 400 do
    F.idle(20)
    if hasControl() then break end
    F.press("A", 2)
  end
  F.shot(tag)
  return waitControl(60)
end
local function cottageOthers()
  local px, py = F.pos()
  local out = {}
  for _, o in ipairs(F.objdump()) do
    if o.x ~= px or o.y ~= py then out[#out + 1] = o end
  end
  return out
end
local function fmtObjs(list)
  local t = {}
  for _, o in ipairs(list) do t[#t + 1] = string.format("(%d,%d)", o.x, o.y) end
  return table.concat(t, " ")
end

local function driveSave(tag)
  F.w16(S.gSaveAttemptStatus, SENTINEL)
  F.press("Start", 2); F.idle(60)
  if not F.selectStartIcon(USM_ICO_SAVE) then F.shot(tag .. "_noicon"); return "noicon" end
  for i = 1, 3000 do
    if F.r16(S.gSaveAttemptStatus) ~= SENTINEL then
      F.idle(30)
      for _ = 1, 6 do F.press("B", 2); F.idle(20) end
      F.idle(120)
      return F.r16(S.gSaveAttemptStatus) == 1 and "done" or "failed"
    end
    if i % 20 == 1 then joypad.set({ A = true }) else joypad.set({}) end
    emu.frameadvance()
  end
  return "timeout"
end

local function johtoPokegear()
  local seen = {}
  for _, id in ipairs(select(2, F.keyItemSlot(0xFFFF))) do seen[id] = true end
  F.check("johto: the first crossing goes to Johto", crossGate({ { 16, 4 }, { 16, 3 } }, "johto"))
  F.check("johto: landed in New Bark", awaitGroup(76, "johto_land"), where())
  drain()
  for _, id in ipairs(select(2, F.keyItemSlot(0xFFFF))) do if not seen[id] then hubPass = id end end
  F.check("johto: the first crossing gives the Hub Pass", hubPass ~= nil, where())
  for _ = 1, 10 do
    local x0, y0 = F.pos()
    F.press("Right", 20); F.idle(40)
    local x1, y1 = F.pos()
    if x1 ~= x0 or y1 ~= y0 then break end
  end
  local bx = F.pos()
  F.check("johto: walked to the wall clock", F.route({ { bx, 4 }, { 9, 4 }, { 9, 3 } }, "clock_walk"), where())
  for _ = 1, 300 do
    if getVar(VAR_NEWBARK_TOWN_STATE) >= 1 and hasControl() then break end
    if F.reportCrash("clock") then break end
    if F.ow() then F.press("A", 2); F.idle(14)
    else F.press("A", 2); F.idle(40); F.press("Up", 2); F.idle(20) end
  end
  local _, y = F.pos()
  F.route({ { 9, y }, { 9, 3 } }, "stairs_walk")
  for _, dir in ipairs({ "Up", "Left", "Right", "Up", "Left" }) do
    if mapIs(HOUSE_1F) then break end
    F.press(dir, 20); F.idle(60)
  end
  F.check("johto: went downstairs", awaitMap(HOUSE_1F, "downstairs"), where())
  F.press("Down", 20)
  for _ = 1, 600 do
    if getVar(VAR_NEWBARK_TOWN_STATE) >= 2 and hasControl() then break end
    if F.reportCrash("mom") then break end
    F.press("A", 2); F.idle(14)
  end
  F.shot("johto_mom")
  F.check("damage: the old PokeGear scene recorded Devon's PokeNav gift", flagGet(FLAG_RECEIVED_POKENAV),
    "newbark=" .. getVar(VAR_NEWBARK_TOWN_STATE))
end

local function rydelBike()
  F.check("rydel: warped into Rydel's Cycles", warp(MAUVILLE_BIKE_SHOP, 0, "rydel"), where())
  F.idle(30)
  F.check("rydel: walked up to Rydel", F.leg(2, 6), where())
  F.check("rydel: talked to Rydel", talk("Up", "rydel_gift"))
  F.check("rydel: Rydel gave the Mach Bike", qty(ITEM_MACH_BIKE) == 1 and qty(ITEM_ACRO_BIKE) == 0, bikeStr())
  F.check("rydel: the shop bike is recorded", flagGet(FLAG_RECEIVED_BIKE))
end

local function goldenrodFirstVisit()
  F.check("goldenrod: warped into Goldenrod for the first time", warp(GOLDENROD, 0, "goldenrod"), where())
  for _ = 1, 30 do
    if waitControl(60) then break end
    F.press("B", 2)
  end
  F.check("goldenrod: the first-visit setup ran", getVar(VAR_GOLDENROD_CITY_STATE) >= 1)
  F.check("goldenrod: the shop bike is unrecorded after the visit", not flagGet(FLAG_RECEIVED_BIKE), bikeStr())
end

local function hoennBrineyHome()
  flagSet(FLAG_BADGE01_GET)
  createMon(25, 30)
  F.check("hoenn: Briney is away from his cottage", flagGet(FLAG_HIDE_BRINEYS_HOUSE_MR_BRINEY))
  F.check("hoenn: warped into the Rustboro Pokemon Center", warp(RUSTBORO_CENTER, 0, "rustboro_center"), where())
  drain()
  F.check("damage: the Center recorded Briney's shore", getVar(VAR_BRINEY_LOCATION) == 1,
    "briney=" .. getVar(VAR_BRINEY_LOCATION))
  F.check("hoenn: Hub Pass out of Hoenn", useHubPass("hoenn_out"), where())
  drain()
  F.check("hoenn: Hoenn gate accepted", crossGate({ { 16, 4 }, { 21, 4 }, { 21, 3 } }, "hoenn_gate"))
  local menus = 0
  for _ = 1, 400 do
    if F.grp() ~= HUB[1] and hasControl() then break end
    if scriptMenuActive() then menu(menus == 0 and 1 or 0, "hoenn_dest", 3); menus = menus + 1 end
    F.press("A", 2); F.idle(14)
  end
  drain()
  F.check("hoenn: back in Hoenn", F.grp() ~= HUB[1], where())
  F.check("damage: the arrival docked Briney at his cottage", not flagGet(FLAG_HIDE_BRINEYS_HOUSE_MR_BRINEY))
  F.check("cottage: warped into Briney's cottage", warp(BRINEYS_HOUSE, 0, "cottage"), where())
  F.idle(60)
  F.shot("cottage")
  local others = cottageOthers()
  F.check("damage: Briney and Peeko stand in the cottage", #others == 2, fmtObjs(others))
end

-- Briney paces a small loop, so walk next to wherever he stands, face him and press A until his
-- own script is the one that started (gSpecialVar_LastTalked), then answer every prompt with A
-- (Yes: sail to Dewford).
local function brineyTile()
  for i = 0, 15 do
    local b = S.gObjectEvents + i * S.ObjectEvent.stride
    if (F.r8(b) & 1) == 1 and F.r8(b + S.ObjectEvent.localId) == LOCALID_BRINEY then
      return F.rs16(b + S.ObjectEvent.x) - 7, F.rs16(b + S.ObjectEvent.y) - 7
    end
  end
end
local SIDES = { { 0, 1, "Up" }, { 1, 0, "Left" }, { -1, 0, "Right" }, { 0, -1, "Down" } }
local function sailToDewford()
  local started = false
  for attempt = 1, 60 do
    local bx, by = brineyTile()
    if not bx then break end
    local side = SIDES[attempt % 4 + 1]
    if F.leg(bx + side[1], by + side[2]) then
      local nx, ny = brineyTile()
      if nx == bx and ny == by then
        F.w16(S.gSpecialVar_LastTalked, 0)
        F.face(side[3])
        F.press("A", 2)
        for _ = 1, 40 do
          if not hasControl() then break end
          F.idle(1)
        end
        if F.r16(S.gSpecialVar_LastTalked) == LOCALID_BRINEY then started = true end
      end
    end
    if started then F.L("  talked to Briney on attempt " .. attempt); break end
    drain()
  end
  F.check("voyage: talked to Briney", started, where())
  F.check("voyage: arrived in Dewford", awaitMap(DEWFORD, "voyage", 1500), where())
  drain()
  F.shot("dewford")
  F.check("voyage: Dewford is recorded as visited", flagGet(FLAG_VISITED_DEWFORD_TOWN))
end

F.run(function()
  if not F.boot(HUB[1]) then F.check("boot", false); F.finish(); return end
  F.L("  case=" .. CASE .. " saveVersion=" .. F.r8(F.sb2() + S.SaveBlock2.saveVersion))
  johtoPokegear()
  if CASE == "damaged" then rydelBike() end
  goldenrodFirstVisit()
  hoennBrineyHome()
  if CASE == "voyage" then sailToDewford() end
  F.L(string.format("  before save: %s %s pokenav=%s briney=%d", where(), bikeStr(),
    tostring(flagGet(FLAG_RECEIVED_POKENAV)), getVar(VAR_BRINEY_LOCATION)))
  F.check("save: saved from the Start menu", driveSave("save") == "done", where())
  F.finish()
end)
