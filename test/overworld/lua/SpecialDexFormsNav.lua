-- The Pokedex Forms page must keep its button hint on screen, on every page.
--
-- #394 rewrote the Forms page with paging. Its PrintForms puts the whole-screen info window's
-- tilemap after the navigation window was drawn, and the info window covers the navigation
-- window's two rows, so the "A Form Mode / START Evos" hint was blank on arrival and vanished
-- again on every page change. The suite opens Pikachu's Forms page (18 forms, two pages) with
-- real input and reads BG2's tilemap where the navigation window lives: on arrival, in form
-- mode, after paging to page 2, after leaving form mode, and after a trip to Evos and back.
--
-- Run via: test/overworld/mgba-run.sh test/overworld/lua/SpecialDexFormsNav.lua <rom.gba>

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "SpecialDexFormsNav")

local FLAG_SYS_POKEDEX_GET = 0x949
local FLAG_SYS_DEXNAV_GET = 0x948 + 0xBE
local USM_ICO_POKEDEX = 0
local PIKACHU_LIST_INDEX = 24
-- WIN_NAVIGATION_BUTTONS in src/pokedex_plus_hgss.c: BG2, tilemap (0,18), 20x2, baseBlock 641.
local NAV_LEFT, NAV_TOP, NAV_W, NAV_H, NAV_BASE = 0, 18, 20, 2, 641
local REG_BG2CNT = 0x0400000C

local function flag(id, value)
  local address, bit = F.sb1() + S.SaveBlock1.flags + id // 8, 1 << (id % 8)
  if value ~= nil then
    local old = F.r8(address)
    F.w8(address, value and (old | bit) or (old & ~bit & 0xFF))
  end
  return (F.r8(address) & bit) ~= 0
end

local function tap(key, n, wait) for _ = 1, (n or 1) do F.press(key, 2); F.idle(wait or 20) end end

local function taskRunning(fn)
  for i = 0, S.Task.count - 1 do
    local task = S.gTasks + i * S.Task.stride
    if F.r8(task + S.Task.isActive) ~= 0 and (F.r32(task + S.Task.func) & 0xFFFFFFFE) == (fn & 0xFFFFFFFE) then
      return true
    end
  end
  return false
end

local function waitForms()
  for _ = 1, 300 do
    if taskRunning(S.Task_HandleFormsScreenInput) then F.idle(20); return true end
    F.idle(2)
  end
  return false
end

-- How many of the navigation window's 40 cells BG2 actually maps to the navigation window.
local function navCellsMapped()
  local base = 0x06000000 + ((F.r16(REG_BG2CNT) >> 8) & 0x1F) * 0x800
  local n = 0
  for y = 0, NAV_H - 1 do
    for x = 0, NAV_W - 1 do
      local entry = F.r16(base + 2 * ((NAV_TOP + y) * 32 + NAV_LEFT + x))
      if (entry & 0x3FF) == NAV_BASE + y * NAV_W + x then n = n + 1 end
    end
  end
  return n
end

local function checkNav(tag)
  local n = navCellsMapped()
  F.shot(tag:gsub("%W", "_"))
  F.check(tag .. ": the Forms button hint is on screen", n == NAV_W * NAV_H, string.format("%d/%d cells", n, NAV_W * NAV_H))
end

F.run(function()
  assert(F.boot(100), "Fresh game did not boot")
  local opt = F.sb2() + S.SaveBlock2.optionsU16
  F.w16(opt, (F.r16(opt) & ~7) | 3)
  flag(FLAG_SYS_POKEDEX_GET, true)
  flag(FLAG_SYS_DEXNAV_GET, true)
  F.dbg(); F.sel(7); F.sel(2); F.idle(60); F.bOut(4)   -- Pokedex Flags All
  F.dbg(); F.sel(7); F.sel(5); F.idle(60); F.bOut(4)   -- Toggle National Dex
  F.w8(F.sb2() + 0x19, 1)                               -- pokedex.mode = DEX_MODE_NATIONAL

  F.press("Start", 2); F.idle(60)
  F.check("Pokedex icon on the start menu", F.selectStartIcon(USM_ICO_POKEDEX))
  F.press("A", 2); F.idle(240)
  tap("Start", 1, 40); tap("Down"); tap("A", 1, 60)    -- List top
  for _ = 1, PIKACHU_LIST_INDEX do F.press("Down", 2); F.idle(16) end
  F.idle(40)
  F.shot("pikachu_selected")
  tap("A", 1, 120)                                      -- Info
  tap("Right", 3, 90)                                   -- Area, Stats, Evos
  tap("Start", 1, 30)                                   -- Forms
  F.check("Pikachu's Forms page opened", waitForms())
  checkNav("arrival")

  tap("A", 1, 30)
  checkNav("form mode")
  tap("Right", 12, 20)
  F.idle(30)
  checkNav("page 2")
  tap("B", 1, 30)
  checkNav("left form mode on page 2")

  tap("Start", 1, 150)                                  -- back to Evos
  tap("Start", 1, 30)                                   -- Forms again
  F.check("Forms page reopened from Evos", waitForms())
  checkNav("reopened")

  for _ = 1, 30 do
    if F.ow() then break end
    tap("B", 1, 40)
  end
  F.check("back on the field", F.ow())
  F.finish()
end)
