-- A player who crosses into a new region has their party boxed (RegionHub_ScrEnterRegion ->
-- DepositPartyToPC) but keeps FLAG_SYS_POKEMON_GET from the region they came from, so until the
-- new region's starter they walk with no Pokemon. The Start menu must not open a party screen
-- for that empty party: the summary of the empty slot freezes on its first page change
-- (AdvanceMonIndex takes a modulo by maxMonIndex + 1, which is 0 for an empty party).
--
-- Run via test/overworld/mgba-run.sh test/overworld/lua/EmptyPartyMenu.lua <rom>

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "EmptyPartyMenu")

local USM_ICO_PARTY = 1
local FLAG_SYS_POKEMON_GET = 0x948

local function tap(k) F.press(k, 2); F.idle(12) end

local function flagGet(n)
  return (F.r8(F.sb1() + S.SaveBlock1.flags + n // 8) >> (n % 8)) & 1 == 1
end

local function scriptMenu()
  for i = 0, S.Task.count - 1 do
    local a = S.gTasks + i * S.Task.stride
    local fn = F.r32(a + S.Task.func) & ~1
    if F.r8(a + S.Task.isActive) ~= 0 and (fn == S.Task_HandleYesNoInput or fn == S.Task_HandleMultichoiceInput
        or fn == S.Task_CallYesOrNoCallback) then return true end
  end
  return false
end

local function choose(value)
  for _ = 1, 70 do
    if scriptMenu() then
      F.idle(12)
      for _ = 1, 10 do
        local c = F.mcur()
        if c == value then tap("A"); F.idle(40); return true end
        tap(c > value and "Up" or "Down")
      end
      return false
    end
    tap("A"); F.idle(12)
  end
  return false
end

-- Cross a hub gate the way a player does; the crossing boxes the carried party.
local function crossToKanto()
  if not F.route({ { 16, 4 }, { 11, 4 }, { 11, 3 } }, "gate_kanto") then return false end
  F.face("Up"); tap("A"); F.idle(60)
  for _ = 1, 400 do
    if F.grp() ~= 100 then break end
    if scriptMenu() then F.idle(12); tap("A") else tap("A") end
    if F.reportCrash("crossing") then return false end
  end
  for _ = 1, 600 do
    if F.ow() and F.ensureFree() then return F.grp() ~= 100 end
    tap("B"); F.idle(20)
  end
  return false
end

F.run(function()
  if not F.boot(100) then F.check("boot to the hub", false); F.finish(); return end
  F.dbg(); F.sel(3); F.sel(1); F.idle(20)
  F.spin(0, 0, 1); F.idle(20); F.spin(0, 1, 0); F.idle(60); F.bOut(4)
  F.check("a first Pokemon sets FLAG_SYS_POKEMON_GET", flagGet(FLAG_SYS_POKEMON_GET) and F.r8(S.gPartiesCount) == 1,
    "count=" .. F.r8(S.gPartiesCount))

  local crossed = crossToKanto()
  F.check("crossed a hub gate into a new region", crossed, string.format("grp=%d map=%d", F.grp(), F.mapn()))
  F.check("the crossing boxed the party", F.r8(S.gPartiesCount) == 0, "count=" .. F.r8(S.gPartiesCount))
  F.check("FLAG_SYS_POKEMON_GET survives the crossing", flagGet(FLAG_SYS_POKEMON_GET))
  F.shot("arrived_empty")

  F.press("Start", 2); F.idle(60)
  local offered = F.selectStartIcon(USM_ICO_PARTY)
  F.shot("start_menu")
  F.check("the Start menu offers no party screen for an empty party", not offered)
  if offered then
    -- What a player can then do: open the slot, view its summary, change page, change Pokemon.
    tap("A"); F.idle(90)
    tap("A"); F.idle(30)
    tap("A"); F.idle(120)
    F.shot("empty_summary")
    tap("Right"); F.idle(40)
    tap("Down"); F.idle(40)
  end
  for _ = 1, 30 do tap("B"); F.idle(20) end
  local back = false
  for _ = 1, 40 do
    if F.ow() and F.ensureFree() then back = true; break end
    tap("B"); F.idle(20)
  end
  F.check("the player is back on a walkable field", back, string.format("cb2=%08X", F.cb2()))
  F.check("no crash screen", not F.reportCrash("empty_party"))

  F.dbg(); F.sel(3); F.sel(1); F.idle(20)
  F.spin(0, 0, 4); F.idle(20); F.spin(0, 0, 5); F.idle(60); F.bOut(4)
  F.ensureFree()
  F.press("Start", 2); F.idle(60)
  F.check("the party screen returns with the region's first Pokemon",
    F.r8(S.gPartiesCount) == 1 and F.selectStartIcon(USM_ICO_PARTY), "count=" .. F.r8(S.gPartiesCount))
  F.shot("start_menu_with_party")
  for _ = 1, 4 do tap("B") end
  F.finish()
end)
