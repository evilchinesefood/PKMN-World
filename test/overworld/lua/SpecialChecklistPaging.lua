-- Right on the Special Pokemon checklist's first page must turn to the second page from every row.
--
-- The list shows four rows a page and seven entries, so page 2 holds three. Right jumps four rows
-- down, the way the Pokedex list pages; from row 4 there is no entry four rows down, and the
-- Pokedex list it opens from clamps to the last entry. The suite opens the checklist from the
-- Pokedex START menu with real input and presses Right from each first-page row, then Left back,
-- and checks the row and the number of icons drawn.
--
-- Run via: test/overworld/mgba-run.sh test/overworld/lua/SpecialChecklistPaging.lua <rom.gba>

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "SpecialChecklistPaging")

local FLAG_SYS_POKEDEX_GET = 0x949
local FLAG_SYS_DEXNAV_GET = 0x948 + 0xBE
local USM_ICO_POKEDEX = 0
local ROWS, ENTRIES = 4, 7

local function flag(id, value)
  local a, bit = F.sb1() + S.SaveBlock1.flags + id // 8, 1 << (id % 8)
  if value ~= nil then F.w8(a, value and (F.r8(a) | bit) or (F.r8(a) & ~bit & 0xFF)) end
  return (F.r8(a) & bit) ~= 0
end
local function tap(key, n, wait) for _ = 1, (n or 1) do F.press(key, 2); F.idle(wait or 24) end end

local function menu() return F.r32(S.sSpecialPokemonMenu) end
local function selected() return F.r8(menu() + S.SpecialPokemonMenu.selected) end
local function icons()
  local n = 0
  for i = 0, S.Sprite.count - 1 do
    if (F.r8(S.gSprites + i * S.Sprite.stride + S.Sprite.inUse) & 1) ~= 0 then n = n + 1 end
  end
  return n
end
local function toRow(row)
  for _ = 1, ENTRIES do if selected() == row then break end tap(selected() > row and "Up" or "Down") end
  return selected() == row
end

F.run(function()
  assert(F.boot(100), "Fresh game did not boot")
  local opt = F.sb2() + S.SaveBlock2.optionsU16
  F.w16(opt, (F.r16(opt) & ~7) | 3)
  flag(FLAG_SYS_POKEDEX_GET, true)
  flag(FLAG_SYS_DEXNAV_GET, true)
  F.dbg(); F.sel(7); F.sel(2); F.idle(60); F.bOut(4)   -- Pokedex Flags All

  F.press("Start", 2); F.idle(60)
  F.check("Pokedex icon on the start menu", F.selectStartIcon(USM_ICO_POKEDEX))
  F.press("A", 2); F.idle(240)
  tap("Start", 1, 60); tap("Down", 3); tap("A", 1, 120)  -- Special Pokemon
  for _ = 1, 60 do if menu() ~= 0 then break end F.idle(5) end
  F.idle(30)
  F.check("checklist open on the first row", menu() ~= 0 and selected() == 0 and icons() == ROWS)
  F.shot("page_1")

  for row = 0, ROWS - 1 do
    local want = math.min(row + ROWS, ENTRIES - 1)
    F.check(string.format("row %d selected", row + 1), toRow(row))
    tap("Right", 1, 40)
    local got = selected()
    F.shot(string.format("right_from_row_%d", row + 1))
    F.check(string.format("Right from row %d turns to page 2", row + 1), got == want and icons() == ENTRIES - ROWS,
      string.format("selected %d (want %d), icons %d", got, want, icons()))
    tap("Right", 1, 40)
    F.check(string.format("Right on page 2 stays (from row %d)", row + 1), selected() == got, "selected " .. selected())
    tap("Left", 1, 40)
    F.check(string.format("Left returns to page 1 (from row %d)", row + 1), selected() == got - ROWS and icons() == ROWS,
      string.format("selected %d, icons %d", selected(), icons()))
  end

  for _ = 1, 30 do
    if F.ow() then break end
    tap("B", 1, 40)
  end
  F.check("back on the field", F.ow())
  F.finish()
end)
