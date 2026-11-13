-- The Route 43 gate Rockets charge a toll while Mahogany's Rocket plot runs. A player who can pay
-- loses 500, one who has less pays everything, and one with nothing is waved through with the
-- "totally broke" line. Neither case may lock the player in the gate or take more than they have.
-- Setup writes only money, the region and the Mahogany story var; the toll runs on real entry.
local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "Route43Toll")

local REGION_JOHTO = 2
local GATE_G, GATE_M = 92, 6
local ROUTE43_G, ROUTE43_M = 91, 2
local VAR_MAHOGANY_TOWN_STATE = 0xA080 + 0x11
local VAR_TEMP_0 = 0x4000

local function where() local x, y = F.pos(); return string.format("%d/%d (%d,%d)", F.grp(), F.mapn(), x, y) end
local function setMoney(v) F.w32(F.sb1() + S.SaveBlock1.money, v ~ F.r32(F.sb2() + S.SaveBlock2.encryptionKey)) end
local function setVar(id, v)
  if id >= 0xA000 then F.w16(F.sb3() + S.SaveBlock3.regionVars + (id - 0xA000) * 2, v)
  else F.w16(F.sb1() + S.SaveBlock1.vars + (id - 0x4000) * 2, v) end
end
local function getVar(id) return F.r16(F.sb1() + S.SaveBlock1.vars + (id - 0x4000) * 2) end
local function setJohto()
  F.w32(S.gCurrentRegion, REGION_JOHTO)
  F.w8(F.sb2() + S.SaveBlock2.currentRegion, REGION_JOHTO)
end

local function enterGate(tag)
  if not F.warpTo(0, 9, 2, 0, 0, 6, 0, 0, 0, GATE_G, GATE_M, tag) then return false end
  for _ = 1, 40 do
    F.press("A", 2); F.idle(24)
    if getVar(VAR_TEMP_0) == 1 and F.ensureFree() then return true end
  end
  for _ = 1, 20 do F.press("B", 2); F.idle(24) end
  return F.ensureFree()
end

local function toll(start, want, tag)
  setVar(VAR_MAHOGANY_TOWN_STATE, 1)
  setMoney(start)
  local free = enterGate(tag)
  F.shot(tag)
  F.check(string.format("toll with %d leaves %d", start, want), F.money() == want,
    string.format("money=%d at %s", F.money(), where()))
  F.check(string.format("player is free to move after the toll with %d", start), free, where())
  return free
end

F.run(function()
  if not F.boot(100) then F.check("boot to the hub", false); F.finish(); return end
  setJohto()

  toll(2000, 1500, "pays_full")
  toll(300, 0, "pays_all")
  if toll(0, 0, "broke") then
    F.leg(6, 2)
    F.leg(7, 2)
    F.step("Up")
    for _ = 1, 120 do F.idle(2); if F.grp() == ROUTE43_G and F.mapn() == ROUTE43_M and F.ow() then break end end
    F.idle(60)
    F.check("a broke player walks through to Route 43", F.grp() == ROUTE43_G and F.mapn() == ROUTE43_M, where())
  end
  F.check("no crash", not F.crashScreen())
  F.finish()
end)
