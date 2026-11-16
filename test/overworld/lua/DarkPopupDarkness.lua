-- A GEN_8 map-name pop-up clips its slide with WIN0 and sets WINOUT to show BG1-3 and sprites
-- outside it. In a dark place the light circle owns WIN0 through a per-scanline effect, so the
-- pop-up's banner never showed and, for the three seconds it ran, the whole dark map was lit
-- (WINOUT 0x001E instead of the field's 0x0101). Dark places now show no pop-up.
--
-- With real input the player climbs down Granite Cave B1F's ladder into dark B2F. For 200 frames
-- after the arrival no pop-up task may run and WINOUT must keep BG1-3 hidden outside the circle.
-- Control: a warp onto lit Route 106, outside the cave, still starts the pop-up.
--
-- Run via: test/overworld/mgba-run.sh test/overworld/lua/DarkPopupDarkness.lua <rom.gba>

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "DarkPopupDarkness")

local ROUTE_106, B1F, B2F = { 0, 21 }, { 24, 8 }, { 24, 9 }
local REG_WINOUT = 0x0400004A
local WINOUT_WIN01_BG123 = 0x000E

local function mapIs(m) return F.grp() == m[1] and F.mapn() == m[2] end
local function popupActive()
  for i = 0, S.Task.count - 1 do
    local a = S.gTasks + i * S.Task.stride
    if F.r8(a + S.Task.isActive) ~= 0 and (F.r32(a + S.Task.func) & ~1) == (S.Task_MapNamePopUpWindow & ~1) then
      return true
    end
  end
  return false
end

F.run(function()
  if not F.boot(100) then F.check("boot", false); F.finish(); return end
  F.dbg(); F.sel(0); F.sel(1); F.idle(20)
  F.spin(0, 0, 0); F.spin(0, 2, 1); F.spin(0, 0, 0)
  local seen = false
  for _ = 1, 400 do if popupActive() then seen = true; break end; F.idle(1) end
  F.idle(200)
  F.check("control: arriving on lit Route 106 starts the map-name pop-up", mapIs(ROUTE_106) and seen,
    string.format("%d/%d", F.grp(), F.mapn()))
  for _ = 1, 10 do F.press("B", 2); F.idle(20) end
  F.ensureFree()

  F.check("setup: on Granite Cave B1F's ladder down", F.warpTo(0, 2, 4, 0, 0, 8, 0, 0, 6, B1F[1], B1F[2], "b1f"))
  for _ = 1, 600 do if not popupActive() then break end; F.idle(2) end
  F.idle(30)
  local back
  for _ = 1, 8 do
    if F.step("Down") then back = "Up"; break end
    if F.step("Right") then back = "Left"; break end
    F.idle(60)
  end
  local x, y = F.pos()
  F.check("setup: stepped off the ladder (a wandering Pokemon may block one side)", back ~= nil, string.format("(%d,%d)", x, y))
  for _ = 1, 40 do joypad.set({ [back or "Up"] = true }); emu.frameadvance(); if mapIs(B2F) then break end end
  for _ = 1, 300 do if mapIs(B2F) then break end; F.idle(1) end
  F.check("climbed down into Granite Cave B2F", mapIs(B2F), string.format("%d/%d", F.grp(), F.mapn()))

  local lit, popup, worst = 0, false, F.r16(REG_WINOUT)
  for i = 1, 200 do
    F.idle(1)
    local winout = F.r16(REG_WINOUT)
    if (winout & WINOUT_WIN01_BG123) ~= 0 then lit = lit + 1; worst = winout end
    if popupActive() then popup = true end
    if i == 90 then F.shot("b2f_arrival") end
  end
  F.check("no map-name pop-up runs in the dark cave", not popup)
  F.check("the cave stays dark outside the light circle", lit == 0,
    string.format("%d of 200 frames lit (WINOUT=%04X)", lit, worst))
  F.check("no crash screen", not F.crashScreen())
  F.finish()
end)
