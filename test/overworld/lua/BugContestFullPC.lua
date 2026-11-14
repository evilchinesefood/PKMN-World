-- Bug-Catching Contest judging with every PC box full: the "make room" PC must not lose or clone
-- a Pokemon, and the judging scene itself must not raise an assert screen.
--
-- The contest parks the real party in SaveBlock1 and plays with a 1-mon contest party; the
-- closing script restores the parked party with LoadPlayerParty. When the boxes are full at
-- judging, the script opens the PC so the player can make room for the kept bug. Any edit made to
-- the party inside that PC must survive the restore: a Pokemon withdrawn from a box must still
-- exist after the contest, and only a Pokemon the player released may be gone.
--
-- Setup writes the region and fills the boxes through the debug menu, frees one slot for the
-- attendant's storage check, stands a debug-given Pokemon in for the catch and refills the slot
-- in RAM for a later catch that landed in the PC. The attendant, retiring, choosing the kept
-- Pokemon, judging, the PC and the trip back to the gate use real input.
--
-- Run via test/overworld/mgba-run.sh test/overworld/lua/BugContestFullPC.lua <rom.gba>

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "BugContestFullPC")

local REGION_JOHTO = 2
local GATE_G, GATE_M = 83, 7
local CONTEST_G, CONTEST_M = 83, 5
local FLAG_SYS_POKEMON_GET = 0x948
local FLAG_SYS_BUG_CONTEST_MODE = 0x948 + 0x21
local BOXES, PER_BOX, BOX_MON = 14, 30, S.BoxPokemon.size
local MON = S.Pokemon.size
local FREED_BOX, FREED_SLOT = BOXES - 1, PER_BOX - 1
local PC_MENU_ROWS = 5
local PC_MOVE_MONS, PC_WITHDRAW = 0, 2

local function count() return F.r8(S.gPartiesCount) end
local function where() local x, y = F.pos(); return string.format("%d/%d (%d,%d)", F.grp(), F.mapn(), x, y) end
local function inContest() return F.grp() == CONTEST_G and F.mapn() == CONTEST_M end
local function atGate() return F.grp() == GATE_G and F.mapn() == GATE_M end
local function sb1Flag(id, on)
  local a, m = F.sb1() + S.SaveBlock1.flags + (id // 8), 1 << (id % 8)
  if on == nil then return (F.r8(a) & m) ~= 0 end
  F.w8(a, on and (F.r8(a) | m) or (F.r8(a) & ~m & 0xFF))
end
local function setJohto()
  F.w32(S.gCurrentRegion, REGION_JOHTO)
  F.w8(F.sb2() + S.SaveBlock2.currentRegion, REGION_JOHTO)
end

local function storage() return F.r32(S.gPokemonStoragePtr) end
local function boxSlot(box, slot) return storage() + 4 + (box * PER_BOX + slot) * BOX_MON end
local function partySlot(i) return S.gParties + i * MON end
local function occupied(a) return F.r32(a) ~= 0 or F.r32(a + 4) ~= 0 end

-- Personality, OT id, nickname, OT name and checksum (bytes 0-29). The debug fill shares one
-- personality across every box, but each slot holds a different species, so the nickname and
-- checksum tell them apart. Bytes 30-31 hold HP lost, which healing and boxing rewrite.
local function fingerprint(a)
  local t = {}
  for i = 0, 29 do t[#t + 1] = string.format("%02X", F.r8(a + i)) end
  return table.concat(t)
end
local function bytes(a, n)
  local t = {}
  for i = 0, n - 1 do t[#t + 1] = F.r8(a + i) end
  return t
end
local function putBytes(a, t) for i = 1, #t do F.w8(a + i - 1, t[i]) end end

local function census()
  local seen, n = {}, 0
  local function add(a)
    if occupied(a) then local k = fingerprint(a); seen[k] = (seen[k] or 0) + 1; n = n + 1 end
  end
  for i = 0, 5 do add(partySlot(i)) end
  for box = 0, BOXES - 1 do for slot = 0, PER_BOX - 1 do add(boxSlot(box, slot)) end end
  return seen, n
end
local function boxCount()
  local n = 0
  for box = 0, BOXES - 1 do for slot = 0, PER_BOX - 1 do if occupied(boxSlot(box, slot)) then n = n + 1 end end end
  return n
end

local function tapDown(n) for _ = 1, n do F.press("Down", 3); F.idle(16) end end
local function drain(tries)
  for i = 1, tries or 40 do
    F.press("B", 3); F.idle(20)
    if i % 5 == 0 and F.ensureFree() then return true end
  end
  return F.ensureFree()
end
local function debugAction(path, tag)
  F.dbg(); F.idle(60)
  for i, row in ipairs(path) do
    tapDown(row); F.press("A", 3); F.idle(i == #path and 240 or 60)
  end
  if not drain(20) then F.L("  debug action " .. tag .. " did not return to the field") return false end
  return true
end
local function give(sp)
  F.dbg(); F.idle(60)
  tapDown(3); F.press("A", 3); F.idle(50)
  tapDown(1); F.press("A", 3); F.idle(40)
  F.press("Right", 2); F.idle(10)
  for _ = 1, (sp // 10) % 10 do F.press("Up", 2); F.idle(8) end
  F.press("Left", 2); F.idle(10)
  for _ = 1, sp % 10 - 1 do F.press("Up", 2); F.idle(8) end
  F.press("A", 3); F.idle(30)
  F.press("A", 3); F.idle(80)
  for _ = 1, 10 do F.press("B", 3); F.idle(20) end
  drain(20)
end

local function menuMax() return F.rs8(S.sMenu + S.Menu.maxCursorPos) end
local function clearMenu() F.w8(S.sMenu + 2, 0); F.w8(S.sMenu + S.Menu.maxCursorPos, 0) end
local function pcMenuLive() return F.ow() and menuMax() == PC_MENU_ROWS - 1 end

local function cursorTo(row)
  for _ = 1, 8 do
    if F.mcur() == row then return true end
    F.press(F.mcur() < row and "Down" or "Up", 2); F.idle(12)
  end
  return F.mcur() == row
end

-- From the contest map: retire at the exit, keep party slot 1, sit through judging, and stop on
-- the PC menu the full-box branch opens. Returns whether the PC opened and whether an assert
-- screen came up on the way.
local function retireToPC()
  F.leg(13, 48)
  F.step("Down")
  clearMenu()
  for _ = 1, 900 do
    if F.reportCrash("retire") then return false, true end
    if pcMenuLive() then F.idle(30); return true, false end
    if F.cb2() == (S.CB2_UpdatePartyMenu & ~1) then
      F.idle(30); F.press("Down", 2); F.idle(20); F.press("A", 2); F.idle(40)
      if F.cb2() == (S.CB2_UpdatePartyMenu & ~1) then F.press("A", 2); F.idle(40) end
    else
      F.press("A", 2); F.idle(18)
    end
  end
  F.shot("retire_nopc")
  return false, false
end

local function leavePC()
  for _ = 1, 6 do
    if F.ow() and not pcMenuLive() then break end
    F.press("B", 2); F.idle(60)
  end
end

-- Inside the storage screen with the cursor on box slot 0: open the action menu and pick `row`.
local function boxAction(row, tag)
  F.idle(60)
  F.press("A", 2); F.idle(40)
  F.shot(tag .. "_menu")
  for _ = 1, row do F.press("Down", 2); F.idle(12) end
  F.press("A", 2); F.idle(90)
end

local function exitStorage()
  for _ = 1, 4 do
    F.press("B", 2); F.idle(60)
    if F.ow() then break end
  end
  F.idle(60)
end

F.run(function()
  if not F.boot(100) then F.check("boot to the hub", false); F.finish(); return end
  setJohto()
  sb1Flag(FLAG_SYS_POKEMON_GET, true)
  F.check("setup: debug Set Party ran", debugAction({ 2, 9 }, "set_party") and count() >= 1, "count=" .. count())
  for _, sp in ipairs({ 19, 21, 27, 29, 32 }) do if count() < 6 then give(sp) end end
  F.check("setup: a full party of six", count() == 6, "count=" .. count())
  F.check("setup: debug Fill PC Boxes Fast ran", debugAction({ 1, 1, 0 }, "fill_pc") and boxCount() == BOXES * PER_BOX,
    "boxed=" .. boxCount())

  local parked = boxSlot(FREED_BOX, FREED_SLOT)
  local parkedBytes = bytes(parked, BOX_MON)
  for o = 0, BOX_MON - 4, 4 do F.w32(parked + o, 0) end

  if not F.warpTo(0, 8, 3, 0, 0, 7, 0, 0, 0, GATE_G, GATE_M, "gate") then
    F.check("warp to the National Park gate", false, where()); F.finish(); return
  end
  setJohto()
  local before = census()

  F.leg(4, 2); F.face("Left"); F.press("A", 3); F.idle(40)
  for _ = 1, 400 do
    F.press("A", 2); F.idle(18)
    if inContest() and F.ow() then break end
  end
  drain(30)
  F.check("the attendant lets the player in with one free box slot", inContest() and sb1Flag(FLAG_SYS_BUG_CONTEST_MODE), where())
  F.check("the contest party is the lead alone", count() == 1, "count=" .. count())

  give(13)
  F.check("setup: a contest catch joins the party", count() == 2, "count=" .. count())
  local keep = fingerprint(partySlot(1))
  putBytes(boxSlot(FREED_BOX, FREED_SLOT), parkedBytes) -- the storage block moves on every warp
  local refilled = fingerprint(boxSlot(FREED_BOX, FREED_SLOT))
  F.check("setup: the boxes are full again", boxCount() == BOXES * PER_BOX, "boxed=" .. boxCount())

  local opened, crashed = retireToPC()
  F.shot("pc_menu")
  F.check("retiring and judging raise no assert screen", not crashed)
  F.check("judging with full boxes opens the PC", opened, where())
  if not opened then F.finish(); return end

  local withdrawn, released
  cursorTo(PC_WITHDRAW); F.press("A", 2); F.idle(120)
  if not F.ow() then
    local box0 = {}
    for box = 0, BOXES - 1 do for slot = 0, PER_BOX - 1 do box0[box * PER_BOX + slot] = fingerprint(boxSlot(box, slot)) end end
    boxAction(0, "withdraw")
    F.shot("withdrawn")
    for box = 0, BOXES - 1 do
      for slot = 0, PER_BOX - 1 do
        if not occupied(boxSlot(box, slot)) then withdrawn = box0[box * PER_BOX + slot] end
      end
    end
    F.L("  withdrew " .. tostring(withdrawn) .. " party=" .. count())
    exitStorage()
  else
    F.L("  Withdraw refused at the PC menu")
    F.shot("withdraw_refused")
    F.press("B", 2); F.idle(30)
  end
  leavePC()

  -- Still full: the script reopens the PC. Release one box Pokemon to make room.
  clearMenu()
  for _ = 1, 300 do
    if pcMenuLive() or atGate() then break end
    F.press("A", 2); F.idle(18)
  end
  if pcMenuLive() then
    F.idle(30)
    cursorTo(PC_MOVE_MONS); F.press("A", 2); F.idle(120)
    local slot0 = fingerprint(boxSlot(0, 0))
    boxAction(4, "release")
    F.press("Up", 2); F.idle(12); F.press("A", 2); F.idle(90)
    for _ = 1, 6 do F.press("A", 2); F.idle(60) end
    if not occupied(boxSlot(0, 0)) then released = slot0 end
    F.shot("released")
    exitStorage()
    leavePC()
  end

  for _ = 1, 600 do
    if atGate() and F.ow() and not sb1Flag(FLAG_SYS_BUG_CONTEST_MODE) then break end
    if F.reportCrash("end") then break end
    F.press("A", 2); F.idle(18)
  end
  drain(30)
  F.shot("back_at_gate")
  F.check("the contest ends back at the gate", atGate() and not sb1Flag(FLAG_SYS_BUG_CONTEST_MODE), where())

  local after = census()
  local missing, extra = {}, {}
  local expected = {}
  for k, v in pairs(before) do expected[k] = v end
  expected[keep] = (expected[keep] or 0) + 1
  expected[refilled] = (expected[refilled] or 0) + 1
  if released then expected[released] = expected[released] - 1 end
  for k, v in pairs(expected) do
    local got = after[k] or 0
    if got < v then missing[#missing + 1] = k .. "x" .. (v - got) end
    if got > v then extra[#extra + 1] = k .. "x" .. (got - v) end
  end
  for k, v in pairs(after) do if not expected[k] then extra[#extra + 1] = k .. "x" .. v end end
  F.L(string.format("  withdrawn=%s released=%s", tostring(withdrawn and withdrawn:sub(17, 36)), tostring(released and released:sub(17, 36))))
  F.check("the kept bug reaches the PC", (after[keep] or 0) >= 1)
  F.check("no Pokemon the player kept is lost", #missing == 0, table.concat(missing, " "))
  F.check("no Pokemon is cloned", #extra == 0, table.concat(extra, " "))
  if withdrawn then
    F.check("the Pokemon withdrawn in the make-room PC still exists", (after[withdrawn] or 0) >= 1)
  end
  F.check("the player has a party after the contest", count() >= 1, "count=" .. count())
  F.check("no crash", not F.crashScreen())
  F.finish()
end)
