-- The post-battle "Your team grew stronger!" box.
--
-- Level-ups are silent during a fight now: Cmd_getexp calls BattleScript_LevelUpQuiet instead of
-- BattleScript_LevelUp, which drops the MUS_LEVEL_UP fanfare, STRINGID_PKMNGREWTOLV and
-- drawlvlupbox (3 button presses and a ~1.33s unskippable stall, per mon, per level). The box
-- drawn at the end of the battle is the ONLY thing that now tells the player what happened, so if
-- it fails to appear the level-ups are completely invisible.
--
-- WHY A LIVE RUN. Nothing about this is observable from the build. The box is drawn straight into
-- VRAM from HandleEndTurn_FinishBattle, before BeginFastPaletteFade, and it is deliberately
-- disabled under the test runner (ShouldShowLevelUpSummary checks gTestRunnerEnabled, or every one
-- of the ~5500 battle tests would hang forever on a gMain.newKeys that never comes). So
-- `make check` cannot see this code path at all -- by construction. Only a real emulator can.
--
-- WHAT DISCRIMINATES, precisely. sLevelUpSummaryState is the box's own stage machine, and it only
-- reaches WAIT_PRESS if ShouldShowLevelUpSummary() passed AND the window was drawn AND the DMA
-- copy completed AND BG1 was scrolled into view. Asserting on that value therefore fails against a
-- build where the hook never runs, rather than passing vacuously. The run then does the same
-- battle again WITHOUT seeding any level-ups and requires that the box does NOT appear -- so a
-- version of this that always returned WAIT_PRESS would fail the control.
--
-- The levels are SEEDED rather than earned. gLevelUpStartLevels[] is written by Cmd_getexp when a
-- slot first levels and read only at the end of the battle, so poking it mid-battle exercises the
-- identical path without needing to out-level a debug trainer. What is under test here is the box
-- -- that the EXP maths fills the array is covered by test/battle/exp.c.
local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(require("symbols"), "LevelUpSummary")

-- Root row 2 = "Party…", party row 10 = "Start Debug Battle" (sDebugMenu_Actions_Main /
-- sDebugMenu_Actions_Party, src/debug.c). Same constants DebugParty.lua uses.
local ROW_PARTY_MENU, ROW_BATTLE = 2, 10

-- enum in src/battle_main.c, next to gLevelUpStartLevels.
local ST_INIT, ST_DRAW, ST_WAIT_DRAW, ST_WAIT_PRESS, ST_CLOSE, ST_DONE = 0, 1, 2, 3, 4, 5
local B_OUTCOME_WON = 1
local PARTY_SIZE = 6
local SEEDED_FROM_LEVEL = 5

local function state() return F.r8(S.sLevelUpSummaryState) end

-- lib's sel() taps Down for 2 frames with an 8-frame gap; press slower, exactly as DebugParty.lua
-- does, because the Down that scrolls the list past the visible rows is the one that gets eaten.
local function tap(n) for _ = 1, n do F.press("Down", 3); F.idle(16) end end

local function startDebugBattle(tag)
  F.dbg(); F.idle(60)
  tap(ROW_PARTY_MENU); F.press("A", 3); F.idle(60)
  tap(ROW_BATTLE); F.press("A", 3); F.idle(260)
  local n = F.r8(S.gBattlersCount)
  F.L(string.format("  %s: gBattlersCount=%d", tag, n))
  return n > 0
end

local function seedLevelUps(count)
  for i = 0, count - 1 do F.w8(S.gLevelUpStartLevels + i, SEEDED_FROM_LEVEL + i * 7) end
end

-- The debug trainer's player party is a single Pokemon, which would only ever exercise a one-row
-- box -- and one row cannot show a column drifting, a row running off the bottom, or a nickname
-- colliding with the level numbers. Clone slot 0 across the party and give each copy a different
-- level so the screenshot shows the real six-row layout. Pokemon.level (offset 84) is the cached
-- byte GetMonData(MON_DATA_LEVEL) returns, so writing it is enough for what the box draws.
local function fillPartyForLayoutCheck()
  local src = S.gParties
  for slot = 1, PARTY_SIZE - 1 do
    local dst = src + slot * S.Pokemon.size
    for off = 0, S.Pokemon.size - 1 do F.w8(dst + off, F.r8(src + off)) end
    F.w8(dst + S.Pokemon.level, 100 - slot * 9)
  end
  F.w8(S.gPartiesCount, PARTY_SIZE)
end

local function clearLevelUps()
  for i = 0, PARTY_SIZE - 1 do F.w8(S.gLevelUpStartLevels + i, 0) end
end

-- Force the battle to finish and watch the stage machine. Presses A to page through the win texts,
-- but NEVER while the box is up -- checking the state immediately before each press is what stops
-- the run from dismissing the very thing it is trying to observe.
local function endBattleAndWatch(wantBox, tag)
  F.w8(S.gBattleOutcome, B_OUTCOME_WON)
  local sawBox = false
  for i = 1, 220 do
    if state() == ST_WAIT_PRESS then sawBox = true; break end
    if i % 3 == 0 and state() ~= ST_WAIT_PRESS then F.press("A", 2) end
    F.idle(16)
  end
  -- Let the "Your team grew stronger!" line finish typing before the screenshot. Shooting the
  -- frame WAIT_PRESS is first observed catches the message window mid-typewriter and makes a
  -- perfectly good box look truncated.
  if sawBox then F.idle(90); F.shot(tag .. "_box") else F.shot(tag .. "_nobox") end
  return sawBox
end

local function returnToField(tag)
  for i = 1, 150 do
    F.idle(20)
    if F.ensureFree() then return true end
    if i % 4 == 0 then F.press("A", 2) end
  end
  F.shot(tag .. "_stuck")
  return false
end

F.run(function()
  if not F.boot(100) then F.check("boot to overworld", false); F.finish(); return end

  -- ---- the box appears when party members levelled -------------------------------------------
  F.check("a debug battle started", startDebugBattle("seeded"))

  -- Baseline first: the array must be clear on entry, or a leftover value from some earlier state
  -- could make the box appear for reasons that have nothing to do with this battle.
  local dirty = 0
  for i = 0, PARTY_SIZE - 1 do
    if F.r8(S.gLevelUpStartLevels + i) ~= 0 then dirty = dirty + 1 end
  end
  F.check("gLevelUpStartLevels is clear at the start of a battle", dirty == 0, "non-zero slots=" .. dirty)

  local n = F.r8(S.gPartiesCount)
  F.check("the debug party has Pokemon in it", n > 0 and n <= PARTY_SIZE, "count=" .. n)

  fillPartyForLayoutCheck()
  F.check("party filled to six for the layout check", F.r8(S.gPartiesCount) == PARTY_SIZE,
    "count=" .. F.r8(S.gPartiesCount))
  seedLevelUps(PARTY_SIZE)

  local sawBox = endBattleAndWatch(true, "seeded")
  F.check("the summary box comes up and waits for a press", sawBox, "state=" .. state())

  -- Dismiss it and require that it actually tears down rather than sitting there forever.
  F.press("A", 3); F.idle(30)
  local closed = false
  for _ = 1, 90 do
    if state() == ST_DONE then closed = true; break end
    F.idle(10)
  end
  F.check("the summary closes on a button press", closed, "state=" .. state())
  F.check("field control returns after the summary", returnToField("seeded"))

  -- ---- the control: no level-ups, no box ------------------------------------------------------
  -- This is the half that stops the assertion above from being vacuous. Same battle, same code
  -- path, only difference is that nothing levelled.
  F.check("a second debug battle started", startDebugBattle("control"))
  clearLevelUps()
  local sawBoxAgain = endBattleAndWatch(false, "control")
  F.check("no summary box when nothing levelled up", not sawBoxAgain, "state=" .. state())
  F.check("field control returns without a summary", returnToField("control"))

  F.finish()
end)
