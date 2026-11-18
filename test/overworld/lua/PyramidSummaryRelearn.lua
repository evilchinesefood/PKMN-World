-- The Summary's move relearner must not be offered while a Battle Pyramid challenge or the Battle
-- Tower multi partner room holds the party.
--
-- Both keep the real party in SaveBlock1's copy and, every time the field resumes (closing the
-- party screen included), RestorePyramidPlayerParty writes each challenge Pokemon back over its
-- saved copy. Any move the saved copy did not know is replaced with Sketch first: the vanilla
-- challenge has no way to change moves, so a new move can only be a cheat. The party screen's
-- Summary (SUMMARY_MODE_NORMAL) offered the move relearner on its moves page (Start), so a move
-- relearned on a Pyramid floor or in the partner room turned into Sketch, and the player's own
-- Pokemon kept Sketch in place of the move it had replaced after the challenge.
--
-- A control first opens the relearner the same way in the hub. Each case gives six level 50 Pokemon, takes the real Lv. 50 challenge with real input, opens
-- the lead's Summary from the Start menu's party screen, moves to the moves page and presses Start.
-- If the relearner opens, the first move is taught over the first slot. Back on the field, the lead
-- and its saved copy must not know Sketch, and after the challenge ends (Retire on the Pyramid
-- floor, quitting at the partner room attendant) the lead must have exactly the four moves it
-- entered with.
--
-- Run via test/overworld/mgba-run.sh test/overworld/lua/PyramidSummaryRelearn.lua <rom>

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "PyramidSummaryRelearn")

local HUB_GROUP = 100
local FRONTIER = 26
local PYRAMID_LOBBY, PYRAMID_FLOOR = 25, 26
local TOWER_LOBBY, PARTNER_ROOM = 5, 15
local USM_ICO_PARTY, USM_ICO_RETIRE = 1, 11
local SPECIES = { 1, 4, 7, 25, 152, 258 }
local MOVE_SKETCH = 166
local SB1_PARTY = 0x238 -- SaveBlock1.playerParty (STATIC_ASSERTed in src/load_save.c)

local function hasControl()
  return F.ow() and F.r8(S.sLockFieldControls) == 0 and F.r8(S.sGlobalScriptContextStatus) ~= 0
end
local function where() local x, y = F.pos(); return string.format("%d/%d (%d,%d)", F.grp(), F.mapn(), x, y) end
local function cb(a) return F.cb2() == (a & ~1) end
local function inPartyMenu() return cb(S.CB2_UpdatePartyMenu) or cb(S.CB2_InitPartyMenu) end
local function inRelearner() return cb(S.CB2_MoveRelearnerMain) end

local function giveMon(species)
  local h, t, o = species // 100, (species // 10) % 10, species % 10
  F.dbg(); F.sel(3); F.sel(1); F.idle(20)
  F.spin(h, t, o); F.idle(20); F.spin(0, 4, 9); F.idle(60); F.bOut(4)
end

local function moves(a)
  local pers = F.r32(a)
  local key = pers ~ F.r32(a + 4)
  local s1 = F.r8(S.sSubstructOffsets + 24 + pers % 24) * 3
  local w0, w1 = F.r32(a + 32 + s1 * 4) ~ key, F.r32(a + 32 + (s1 + 1) * 4) ~ key
  return { w0 & 0x7FF, (w0 >> 16) & 0x7FF, w1 & 0x7FF, (w1 >> 16) & 0x7FF }
end
local function fmt(m) return table.concat(m, ",") end
local function has(m, mv) for _, v in ipairs(m) do if v == mv then return true end end return false end
local function lead() return moves(S.gParties) end
local function savedLead() return moves(F.sb1() + SB1_PARTY) end

local function liveMenu()
  for i = 0, S.Task.count - 1 do
    local a = S.gTasks + i * S.Task.stride
    local fn = F.r32(a + S.Task.func) & 0xFFFFFFFE
    if F.r8(a + S.Task.isActive) ~= 0
      and (fn == S.Task_HandleYesNoInput or fn == S.Task_HandleMultichoiceInput or fn == S.Task_CallYesOrNoCallback) then
      return true
    end
  end
  return false
end
local function menu(want, tag)
  for _ = 1, 80 do
    if liveMenu() then
      F.idle(12)
      for _ = 1, 10 do
        local c = F.mcur()
        if c == want then F.shot(tag); F.press("A", 2); F.idle(40); return true end
        F.press(c > want and "Up" or "Down", 2); F.idle(12)
      end
      return false
    end
    F.press("A", 2); F.idle(25)
  end
  F.L("  menu " .. tag .. ": never opened")
  return false
end
local function choose(n)
  for _ = 1, 300 do
    if inPartyMenu() then break end
    F.press("A", 2); F.idle(20)
  end
  if not inPartyMenu() then return false end
  F.idle(60)
  for i = 1, n do
    F.press("A", 2); F.idle(30); F.press("A", 2); F.idle(40)
    if i < n then F.press("Down", 2); F.idle(20) end
  end
  F.press("Start", 2); F.idle(40)
  for _ = 1, 8 do
    if not inPartyMenu() then break end
    F.press("A", 2); F.idle(60)
  end
  return not inPartyMenu()
end

-- Start menu > party > lead > Summary (the first action in both rooms), then Start on the moves
-- page. Teaches the relearner's first move over the first slot if the relearner opens, then leaves
-- every screen for the field.
local function relearnFromSummary(tag, orig, lookOnly)
  F.press("Start", 2); F.idle(60)
  F.selectStartIcon(USM_ICO_PARTY)
  F.press("A", 2); F.idle(120)
  F.check(tag .. ": the party screen opened", inPartyMenu())
  F.press("A", 2); F.idle(40); F.shot(tag .. "_actions")
  F.press("A", 2); F.idle(120)
  F.press("Right", 2); F.idle(40); F.press("Right", 2); F.idle(60); F.shot(tag .. "_moves_page")
  F.press("Start", 2)
  local opened = false
  for _ = 1, 40 do F.idle(5); if inRelearner() then opened = true; break end end
  F.idle(60); F.shot(tag .. "_after_start")
  if lookOnly then return opened end
  if opened then
    for _ = 1, 200 do
      if fmt(lead()) ~= fmt(orig) then break end
      F.press("A", 2); F.idle(30)
    end
    F.L("  " .. tag .. ": the relearner taught, lead " .. fmt(lead()))
    F.idle(120); F.press("A", 2); F.idle(180)
    F.press("B", 2); F.idle(300); F.press("A", 2); F.idle(200)
  end
  for _ = 1, 8 do
    if F.ow() then break end
    F.press("B", 2); F.idle(120)
  end
  -- The party screen returns to the open Start menu; B closes it.
  for _ = 1, 20 do
    if hasControl() then break end
    F.press("B", 2); F.idle(30)
  end
  F.idle(60); F.shot(tag .. "_field")
  return opened
end

local function checkMoves(tag)
  local now, copy = lead(), savedLead()
  F.L(string.format("  %s back on the field: lead %s saved %s", tag, fmt(now), fmt(copy)))
  F.check(tag .. ": back on the field in control", hasControl(), where())
  F.check(tag .. ": the challenge lead does not know Sketch", not has(now, MOVE_SKETCH), fmt(now))
  F.check(tag .. ": the saved copy of the lead does not know Sketch", not has(copy, MOVE_SKETCH), fmt(copy))
end

local function pyramid(orig)
  local tag = "pyramid"
  assert(F.warpTo(0, 2, 6, 0, 2, 5, 0, 0, 0, FRONTIER, PYRAMID_LOBBY, tag), "Pyramid warp failed")
  if not F.ensureFree() then F.dismiss(10) end
  F.check(tag .. ": walked to the attendant", F.route({ { 7, 14 }, { 7, 13 } }, tag), where())
  F.face("Up"); F.press("A", 2); F.idle(40)
  F.check(tag .. ": took the Lv. 50 challenge",
    menu(0, tag .. "_take") and menu(0, tag .. "_lv50") and choose(3) and menu(0, tag .. "_save"))
  local arrived = false
  for i = 1, 8000 do
    if F.grp() == FRONTIER and F.mapn() == PYRAMID_FLOOR and i % 60 == 0 and hasControl() then arrived = true; break end
    if i % 40 == 1 then joypad.set({ A = true }) else joypad.set({}) end
    emu.frameadvance()
  end
  F.idle(60)
  F.check(tag .. ": on the first floor in control", arrived, where())
  if not arrived then return end

  local opened = relearnFromSummary(tag, orig)
  F.check(tag .. ": the Summary does not open the move relearner on the floor", not opened)
  checkMoves(tag)

  F.press("Start", 2); F.idle(60)
  F.selectStartIcon(USM_ICO_RETIRE)
  F.press("A", 2); F.idle(240); F.press("Up", 2); F.idle(20); F.press("A", 2); F.idle(30)
  local back = false
  for i = 1, 6000 do
    if F.grp() == FRONTIER and F.mapn() == PYRAMID_LOBBY and F.r8(S.gPartiesCount) == 6 and i % 30 == 0
      and hasControl() then
      back = true; break
    end
    if i % 40 == 1 then joypad.set({ B = true }) else joypad.set({}) end
    emu.frameadvance()
  end
  F.idle(60); F.shot(tag .. "_lobby")
  F.check(tag .. ": retired to the lobby with six Pokemon", back, where() .. " n=" .. F.r8(S.gPartiesCount))
  F.check(tag .. ": the lead kept the four moves it entered with", fmt(lead()) == fmt(orig),
    "now " .. fmt(lead()) .. " entered " .. fmt(orig))
end

local function partnerRoom(orig)
  local tag = "multi"
  assert(F.warpTo(0, 2, 6, 0, 0, 5, 0, 0, 0, FRONTIER, TOWER_LOBBY, tag), "Tower warp failed")
  if not F.ensureFree() then F.dismiss(10) end
  F.check(tag .. ": walked to the multi attendant", F.route({ { 12, 8 }, { 14, 8 }, { 14, 6 } }, tag), where())
  F.face("Up"); F.press("A", 2); F.idle(40)
  F.check(tag .. ": took the Lv. 50 multi challenge",
    menu(0, tag .. "_take") and menu(0, tag .. "_lv50") and choose(2) and menu(0, tag .. "_save"))
  local arrived = false
  for i = 1, 6000 do
    if F.grp() == FRONTIER and F.mapn() == PARTNER_ROOM and F.ow() and i % 60 == 0 and F.ensureFree() then
      arrived = true; break
    end
    if i % 40 == 1 then joypad.set({ A = true }) else joypad.set({}) end
    emu.frameadvance()
  end
  F.check(tag .. ": in the partner room in control", arrived, where())
  if not arrived then return end

  local opened = relearnFromSummary(tag, orig)
  F.check(tag .. ": the Summary does not open the move relearner in the partner room", not opened)
  checkMoves(tag)

  F.face("Up"); F.press("A", 2); F.idle(40)
  F.check(tag .. ": quit at the room attendant", menu(0, tag .. "_quit"), where())
  local back = false
  for i = 1, 3000 do
    if F.grp() == FRONTIER and F.mapn() == TOWER_LOBBY and F.ow() and i % 60 == 0 and F.ensureFree() then
      back = true; break
    end
    if i % 40 == 1 then joypad.set({ B = true }) else joypad.set({}) end
    emu.frameadvance()
  end
  F.shot(tag .. "_lobby")
  F.check(tag .. ": back in the lobby with six Pokemon", back and F.r8(S.gPartiesCount) == 6,
    where() .. " n=" .. F.r8(S.gPartiesCount))
  F.check(tag .. ": the lead kept the four moves it entered with", fmt(lead()) == fmt(orig),
    "now " .. fmt(lead()) .. " entered " .. fmt(orig))
end

F.run(function()
  if not F.boot(HUB_GROUP) then F.check("boot to the hub", false); F.finish(); return end
  for _, sp in ipairs(SPECIES) do giveMon(sp) end
  F.check("six Pokemon in the party", F.r8(S.gPartiesCount) == 6, "n=" .. F.r8(S.gPartiesCount))
  local orig = lead()
  F.L("  lead moves " .. fmt(orig))
  local base = F.out .. "PyramidSummaryRelearn_base.ss"
  client.savestate(base)
  F.check("control: the Summary opens the move relearner in the hub", relearnFromSummary("control", orig, true))
  client.loadstate(base); F.idle(10)
  pyramid(orig)
  client.loadstate(base); F.idle(10)
  partnerRoom(orig)
  F.check("no crash screen", not F.crashScreen())
  F.finish()
end)
