-- The graphical Start menu keeps the player's icon order in SaveBlock3 (usmSaved). Special
-- contexts offer fewer icons: the Bug-Catching Contest hides Save and Debug, the Pike hides the
-- Bag and Save, the Pyramid swaps Save for Rest. Closing the menu in such a context must not
-- rewrite the saved order down to the icons that context shows, or every hidden icon falls out of
-- the player's order and comes back at its default position once the context ends.
--
-- The suite moves Save to the front of the wheel with real SELECT and D-pad input, enters the
-- contest at the National Park gate, opens the Start menu there and moves the Bag ahead of the
-- Party, retires at the exit, and opens the menu again: Save must still lead, and the Bag move
-- made in the contest must be kept.
--
-- Run via test/overworld/mgba-run.sh test/overworld/lua/UsmOrderSpecialContext.lua <rom>

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "UsmOrderSpecialContext")

local REGION_JOHTO = 2
local SPECIES_PIDGEY = 16
local GATE_G, GATE_M = 83, 7
local CONTEST_G, CONTEST_M = 83, 5
local FLAG_SYS_POKEMON_GET = 0x948
local FLAG_SYS_BUG_CONTEST_MODE = 0x948 + 0x21
local VAR_BUG_CONTEST_STATE = 0xA080 + 0x0E
local ATTENDANT_STAND = { 4, 2 }
local ROW_GIVE, ROW_MON_BASIC = 3, 1
local USM_ICO_PARTY, USM_ICO_BAG, USM_ICO_SAVE = 1, 2, 7
local ICO_COUNT = 12

local function where() local x, y = F.pos(); return string.format("%d/%d (%d,%d)", F.grp(), F.mapn(), x, y) end
local function inContest() return F.grp() == CONTEST_G and F.mapn() == CONTEST_M end
local function sb1Flag(id, on)
  local a, m = F.sb1() + S.SaveBlock1.flags + (id // 8), 1 << (id % 8)
  if on == nil then return (F.r8(a) & m) ~= 0 end
  F.w8(a, on and (F.r8(a) | m) or (F.r8(a) & ~m & 0xFF))
end
local function contestState() return F.r16(F.sb3() + S.SaveBlock3.regionVars + (VAR_BUG_CONTEST_STATE - 0xA000) * 2) end
local function setJohto()
  F.w32(S.gCurrentRegion, REGION_JOHTO)
  F.w8(F.sb2() + S.SaveBlock2.currentRegion, REGION_JOHTO)
end

local function saved()
  local base = F.sb3() + S.SaveBlock3.usmSaved
  local n = F.r8(base + ICO_COUNT)
  local t = {}
  for i = 0, math.min(n, ICO_COUNT) - 1 do t[#t + 1] = F.r8(base + i) end
  return t
end
local function fmt(t) return "{" .. table.concat(t, ",") .. "}" end
local function indexOf(t, v) for i, x in ipairs(t) do if x == v then return i end end return nil end

-- The live menu's item list (sUsmState->items at +11, itemCount at +23), read while it is open.
local function liveItems()
  local p = F.r32(S.sUsmState)
  if p < 0x02000000 or p >= 0x02040000 then return {} end
  local t = {}
  for i = 0, F.r8(p + 23) - 1 do t[#t + 1] = F.r8(p + 11 + i) end
  return t
end

local function tapDown(n) for _ = 1, n do F.press("Down", 3); F.idle(16) end end
local function drain(tries)
  for i = 1, tries or 40 do
    F.press("B", 3); F.idle(20)
    if i % 5 == 0 and F.ensureFree() then return true end
  end
  return F.ensureFree()
end
local function give(sp)
  F.dbg(); F.idle(60)
  tapDown(ROW_GIVE); F.press("A", 3); F.idle(50)
  tapDown(ROW_MON_BASIC); F.press("A", 3); F.idle(40)
  F.press("Right", 2); F.idle(10)
  for _ = 1, (sp // 10) % 10 do F.press("Up", 2); F.idle(8) end
  F.press("Left", 2); F.idle(10)
  for _ = 1, sp % 10 - 1 do F.press("Up", 2); F.idle(8) end
  F.press("A", 3); F.idle(30)
  F.press("A", 3); F.idle(80)
  for _ = 1, 10 do F.press("B", 3); F.idle(20) end
  drain(20)
end

local function openStart() F.press("Start", 2); F.idle(60); return F.r32(S.sUsmState) ~= 0 end
local function closeStart()
  F.press("B", 2); F.idle(40)
  return drain(10)
end

F.run(function()
  if not F.boot(100) then F.check("boot to the hub", false); F.finish(); return end
  setJohto()
  sb1Flag(FLAG_SYS_POKEMON_GET, true)
  give(SPECIES_PIDGEY)
  F.check("setup: one Pokemon in the party", F.r8(S.gPartiesCount) == 1, "n=" .. F.r8(S.gPartiesCount))

  -- Move Save to the front: select it, SELECT to grab, Left until it is first, SELECT to drop.
  openStart()
  local found = F.selectStartIcon(USM_ICO_SAVE)
  F.check("the field menu offers Save", found)
  F.press("Select", 2); F.idle(20)
  for _ = 1, ICO_COUNT do F.press("Left", 2); F.idle(14) end
  F.press("Select", 2); F.idle(20)
  F.shot("save_moved_first")
  local live = liveItems()
  F.L("  live order after the move: " .. fmt(live))
  closeStart()
  local before = saved()
  F.L("  saved order before the contest: " .. fmt(before))
  F.check("setup: Save is first in the saved order", before[1] == USM_ICO_SAVE, fmt(before))

  if not F.warpTo(0, 8, 3, 0, 0, 7, 0, 0, 0, GATE_G, GATE_M, "gate") then
    F.check("warp to the National Park gate", false, where()); F.finish(); return
  end
  setJohto()
  if not F.leg(ATTENDANT_STAND[1], ATTENDANT_STAND[2]) then
    F.check("walk to the contest attendant", false, where()); F.finish(); return
  end
  F.face("Left")
  F.press("A", 3); F.idle(40)
  for _ = 1, 400 do
    F.press("A", 2); F.idle(18)
    if inContest() and F.ow() and contestState() == 2 then break end
    if F.reportCrash("entry") then break end
  end
  drain(30)
  F.check("the attendant sends the player into the contest", inContest() and sb1Flag(FLAG_SYS_BUG_CONTEST_MODE),
    string.format("at %s state=%d", where(), contestState()))

  openStart()
  F.shot("contest_menu")
  local contestLive = liveItems()
  F.L("  contest menu: " .. fmt(contestLive))
  F.check("the contest menu hides Save", indexOf(contestLive, USM_ICO_SAVE) == nil, fmt(contestLive))
  -- Reorder inside the contest too: the Bag moves one place left, ahead of the Party.
  F.selectStartIcon(USM_ICO_BAG)
  F.press("Select", 2); F.idle(20)
  F.press("Left", 2); F.idle(14)
  F.press("Select", 2); F.idle(20)
  F.shot("contest_bag_moved")
  closeStart()
  local during = saved()
  F.L("  saved order after closing the contest menu: " .. fmt(during))
  F.check("closing the contest menu keeps Save in the saved order", indexOf(during, USM_ICO_SAVE) ~= nil, fmt(during))
  local want = {}
  for _, v in ipairs(before) do want[#want + 1] = v end
  local b, p = indexOf(want, USM_ICO_BAG), indexOf(want, USM_ICO_PARTY)
  if b and p and b == p + 1 then want[b], want[p] = want[p], want[b] end

  if inContest() then
    F.leg(13, 48)
    F.step("Down")
    for _ = 1, 300 do
      F.press("A", 2); F.idle(18)
      if F.grp() == GATE_G and F.mapn() == GATE_M and F.ow() and not sb1Flag(FLAG_SYS_BUG_CONTEST_MODE) then break end
    end
    drain(30)
  end
  F.check("retired from the contest", not sb1Flag(FLAG_SYS_BUG_CONTEST_MODE), where())

  openStart()
  local after = liveItems()
  F.shot("menu_after_contest")
  closeStart()
  F.L("  field menu after the contest: " .. fmt(after) .. " saved=" .. fmt(saved()))
  F.check("Save is still first on the wheel after the contest", after[1] == USM_ICO_SAVE, fmt(after))
  F.check("the field order keeps Save first and the Bag move made in the contest", fmt(saved()) == fmt(want),
    "want=" .. fmt(want) .. " after=" .. fmt(saved()))
  F.finish()
end)
