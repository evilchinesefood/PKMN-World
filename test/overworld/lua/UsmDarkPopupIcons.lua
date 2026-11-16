-- In a dark place (a Flash cave, the Battle Pyramid) the graphical Start menu draws its icons
-- through the OBJ window: Usm_InitStartMenu turns on DISPCNT_OBJWIN_ON and WINOUT_WINOBJ_OBJ and
-- gives each icon an OBJ-window copy. Opening the menu while the map-name pop-up is still up must
-- keep that: HideMapNamePopUpWindow (GEN_8 pop-ups) rewrote WINOUT to the field default after the
-- menu had set the OBJ-window bit, so every icon vanished and only the label and banner showed.
--
-- The suite warps into Dark Cave (dark without Flash) and presses Start with real input while the
-- arrival pop-up is still sliding, then reads REG_WINOUT and screenshots the menu. Control: the
-- same after the pop-up has gone.
--
-- Run via test/overworld/mgba-run.sh test/overworld/lua/UsmDarkPopupIcons.lua <rom>

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "UsmDarkPopupIcons")

local DARK_CAVE = { 94, 16 }
local ROUTE_31 = { 94, 0 }
local REG_DISPCNT, REG_WINOUT = 0x04000000, 0x0400004A
local DISPCNT_OBJWIN_ON, WINOUT_WINOBJ_OBJ = 0x8000, 0x1000

local function warp(m, tag)
  local function d(n) return n // 100, (n // 10) % 10, n % 10 end
  local gh, gt, go = d(m[1]); local mh, mt, mo = d(m[2])
  return F.warpTo(gh, gt, go, mh, mt, mo, 0, 0, 0, m[1], m[2], tag)
end
local function popupActive()
  for i = 0, S.Task.count - 1 do
    local a = S.gTasks + i * S.Task.stride
    if F.r8(a + S.Task.isActive) ~= 0 and (F.r32(a + S.Task.func) & ~1) == (S.Task_MapNamePopUpWindow & ~1) then
      return true
    end
  end
  return false
end

-- Opens the menu and returns whether the icons can show through the OBJ window.
local function openAndRead(tag)
  F.press("Start", 2)
  for _ = 1, 60 do F.idle(1); if F.r32(S.sUsmMemory) ~= 0 then break end end
  F.idle(30)
  local dispcnt, winout = F.r16(REG_DISPCNT), F.r16(REG_WINOUT)
  F.shot(tag)
  F.L(string.format("  %s: DISPCNT=%04X WINOUT=%04X", tag, dispcnt, winout))
  F.press("B", 2)
  for _ = 1, 60 do F.idle(2); if F.r32(S.sUsmMemory) == 0 then break end end
  F.idle(30)
  return (dispcnt & DISPCNT_OBJWIN_ON) ~= 0, (winout & WINOUT_WINOBJ_OBJ) ~= 0
end

F.run(function()
  if not F.boot(100) then F.check("boot", false); F.finish(); return end
  F.check("setup: on Route 31", warp(ROUTE_31, "route31"))
  for _ = 1, 10 do F.press("B", 2); F.idle(20) end
  F.ensureFree()

  -- Walk into the dark: the cave's arrival pop-up starts on the warp.
  F.check("setup: in Dark Cave", warp(DARK_CAVE, "dark_cave"))
  local waited = 0
  while not popupActive() and waited < 120 do F.idle(1); waited = waited + 1 end
  F.check("setup: the arrival pop-up is up", popupActive())
  local objwin, objInWin = openAndRead("menu_during_popup")
  F.check("with the pop-up up: the menu turns the OBJ window on", objwin)
  F.check("with the pop-up up: icons show through the OBJ window (WINOUT_WINOBJ_OBJ)", objInWin)

  for _ = 1, 600 do if not popupActive() then break end; F.idle(2) end
  F.idle(60)
  local objwin2, objInWin2 = openAndRead("menu_after_popup")
  F.check("control: after the pop-up the icons show through the OBJ window", objwin2 and objInWin2)
  F.check("no crash screen", not F.crashScreen())
  F.finish()
end)
