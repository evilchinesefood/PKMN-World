-- An Egg's summary cannot turn pages (ChangePage returns for an Egg), so it must not draw the page
-- tabs or the left and right page arrows in its header. The suite gives a debug party and a debug
-- Egg, opens the Egg's summary from the party menu with real input, and reads the summary's BG2
-- screen block from VRAM: header rows 1 and 2, columns 0 to 9 (arrow, four 2x2 tabs, arrow) must be
-- the plain header tile. Right and Left must leave the Egg on its page. Up to the Pokemon above
-- must bring the tabs and arrows back (control), and Down to the Egg must hide them again.
--
-- Run via: test/overworld/mgba-run.sh test/overworld/lua/EggSummaryPageTabs.lua <rom.gba>

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "EggSummaryPageTabs")

local FLAG_SYS_POKEMON_GET = 0x948
local REG_BG2CNT, VRAM = 0x0400000C, 0x06000000
local HEADER_BLANK, TAB_INFO_HL = 0x33, 0x01

local function tap(key, n, wait) for _ = 1, (n or 1) do F.press(key, 2); F.idle(wait or 24) end end
local function count() return F.r8(S.gPartiesCount) end
local function flag(id)
  local a = F.sb1() + S.SaveBlock1.flags + id // 8
  F.w8(a, F.r8(a) | (1 << (id % 8)))
end
-- Tile numbers of header rows 1 and 2, columns 0 to 9.
local function headerTiles()
  local base = VRAM + ((F.r16(REG_BG2CNT) >> 8) & 0x1F) * 0x800
  local t = {}
  for row = 1, 2 do
    for col = 0, 9 do t[#t + 1] = F.r16(base + (row * 32 + col) * 2) & 0x3FF end
  end
  return t
end
local function describe(t)
  local s = {}
  for i, v in ipairs(t) do s[#s + 1] = string.format("%02X", v) end
  return table.concat(s, " ")
end
local function headerBlank()
  local t = headerTiles()
  for _, v in ipairs(t) do if v ~= HEADER_BLANK then return false, describe(t) end end
  return true, describe(t)
end
local function tabsShown()
  local t = headerTiles()
  return t[2] == TAB_INFO_HL, describe(t)
end

F.run(function()
  assert(F.boot(100), "boot")
  flag(FLAG_SYS_POKEMON_GET)
  F.dbg(); F.idle(40); F.sel(2); F.idle(40)
  for _ = 1, 9 do F.press("Down", 3); F.idle(16) end
  F.press("A", 3); F.idle(180)
  for _ = 1, 30 do F.press("B", 2); F.idle(16); if F.ensureFree() then break end end
  local before = count()
  F.dbg(); F.sel(3); F.sel(3); F.idle(30)
  tap("A", 1, 60); F.idle(30); F.bOut(6)
  for _ = 1, 10 do if F.ensureFree() then break end F.press("B", 2); F.idle(20) end
  F.check("setup: debug party and an Egg", before >= 1 and count() == before + 1, "n=" .. count())

  F.press("Start", 2); F.idle(60)
  F.check("the start menu has the party icon", F.selectStartIcon(1))
  F.press("A", 2); F.idle(90)
  tap("Down", count() - 1, 16)
  tap("A", 1, 50)
  tap("A", 1, 120)
  F.shot("egg_summary")
  local ok, d = headerBlank()
  F.check("the Egg's summary draws no page tabs or arrows", ok, d)
  tap("Right", 1, 90)
  ok, d = headerBlank()
  F.check("Right leaves the Egg on its page, still without tabs", ok, d)
  tap("Left", 1, 90)
  ok, d = headerBlank()
  F.check("Left leaves the Egg on its page, still without tabs", ok, d)
  tap("Up", 1, 120)
  F.shot("mon_summary")
  ok, d = tabsShown()
  F.check("Up to the Pokemon above shows its tabs and arrows", ok, d)
  tap("Down", 1, 120)
  F.shot("egg_summary_again")
  ok, d = headerBlank()
  F.check("Down back to the Egg hides them again", ok, d)
  F.finish()
end)
