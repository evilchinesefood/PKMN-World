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

-- ---- the message line's own pixels ------------------------------------------------------------
-- B_WIN_MSG (window 0) prints with foreground 1, shadow 6 and background 15
-- (sTextOnWindowsInfo_Normal, src/battle_message.c), and it is filled with PIXEL_FILL(0xF) before
-- printing -- so those three nibbles are the ONLY palette indices its tiles may legally contain,
-- and 1 and 6 are only there if a glyph was actually drawn.
--
-- Index 14 turning up there is one specific defect, not a vague "looks off". AddTextPrinter bakes
-- the printer's colours into a single GLOBAL table, sFontHalfRowLookupTable (src/text.c:496), and
-- RenderText regenerates it only for an in-string colour code -- never when it resumes a printer.
-- B_WIN_MSG types a character per frame out of RunTextPrinters, so any window printed while it is
-- still typing repaints every remaining glyph in that other window's colours. The summary box
-- prints on background TEXT_DYNAMIC_COLOR_5 = 14, which is its own dark fill in palette 5 but a
-- muddy red in B_WIN_MSG's palette 0: drawing the box after starting the message left the "Y"
-- correct and put a red block behind "our team grew stronger!". Hence the box goes up first.
--
-- Read out of VRAM rather than the window's EWRAM buffer, so this is what the screen is showing.
-- Everything is derived: bg, width, height and baseBlock come from gWindows[0].window, and the
-- char base from that BG's own BGxCNT -- nothing here assumes a layout that a later edit could
-- move underneath it.
--
-- WHAT THE ASSERTIONS DEMAND, and the two vacuity holes they are shaped around.
--
-- (1) "The line rendered" cannot be read off the pixels alone. B_WIN_MSG is NEVER blank here: the
-- battle-end script has just printed its own text into it, so foreground pixels are present even
-- on a build where BattlePutTextOnWindow is deleted outright -- measured, not assumed, against a
-- ROM built with exactly that line removed. Presence of glyphs therefore proves nothing. What
-- does is a BASELINE: the window is digested at the moment the state machine leaves ST_INIT --
-- the box is up but the summary has not printed yet, by construction of the ordering -- and again
-- once the line has finished typing. Stale battle text digests identically twice; a line that
-- actually printed does not.
--
-- (2) The colour check rejects every index outside 1/6/15, not index 14 alone. The pre-fix build
-- stained the glyphs themselves with 13 (TEXT_DYNAMIC_COLOR_4, the box's foreground) as well as
-- their backgrounds with 14 -- 277 pixels of it -- so naming only 14 would have missed that half
-- of the same defect.
local B_WIN_MSG = 0
local REG_BG0CNT = 0x04000008
local VRAM = 0x06000000

local function msgWindowRead()
  local w      = S.gWindows + B_WIN_MSG * S.Window.stride
  local bg     = F.r8(w + S.Window.bg)
  local width  = F.r8(w + S.Window.width)
  local height = F.r8(w + S.Window.height)
  local base   = F.r16(w + S.Window.baseBlock)
  local charBase = (F.r16(REG_BG0CNT + bg * 2) >> 2) & 3
  local addr   = VRAM + charBase * 0x4000 + base * 32
  local counts, digest = {}, 0
  for off = 0, width * height * 32 - 4, 4 do
    local v = F.r32(addr + off)
    digest = (digest + v * (1 + off)) & 0xFFFFFFFF
    for n = 0, 7 do
      local idx = (v >> (n * 4)) & 0xF
      counts[idx] = (counts[idx] or 0) + 1
    end
  end
  F.L(string.format("  B_WIN_MSG bg=%d base=0x%03X %dx%d tiles at 0x%08X digest=0x%08X",
    bg, base, width, height, addr, digest))
  return counts, digest
end

local MSG_LEGAL = { [1] = true, [6] = true, [15] = true }

-- Every index the window may not contain, as "idx=count" -- named, so a failure says which colour
-- bled in rather than only that one did.
local function illegalIndexes(counts)
  local n, parts = 0, {}
  for idx = 0, 15 do
    if not MSG_LEGAL[idx] and (counts[idx] or 0) > 0 then
      n = n + counts[idx]
      parts[#parts + 1] = string.format("idx%d=%d", idx, counts[idx])
    end
  end
  return n, (#parts > 0 and table.concat(parts, " ") or "none")
end

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
  local sawBox, baseline = false, nil
  -- Single-frame polling, where the old loop idled 16 at a time: the baseline has to be taken
  -- while the box is up and the summary line is NOT yet printed, and ST_DRAW is one frame wide.
  -- Landing a frame late on ST_WAIT_DRAW is harmless -- one glyph in still differs from a full
  -- line, and on a build that never prints, both samples are the same stale text either way.
  for i = 1, 3600 do
    local st = state()
    if st == ST_WAIT_PRESS then sawBox = true; break end
    if baseline == nil and st ~= ST_INIT then local _; _, baseline = msgWindowRead() end
    if i % 48 == 0 then F.press("A", 2) end
    F.idle(1)
  end
  -- Let the "Your team grew stronger!" line finish typing before the screenshot. Shooting the
  -- frame WAIT_PRESS is first observed catches the message window mid-typewriter and makes a
  -- perfectly good box look truncated.
  if sawBox then F.idle(90); F.shot(tag .. "_box") else F.shot(tag .. "_nobox") end
  return sawBox, baseline
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

  local sawBox, baseline = endBattleAndWatch(true, "seeded")
  F.check("the summary box comes up and waits for a press", sawBox, "state=" .. state())

  -- Still on WAIT_PRESS here, message fully typed, nothing dismissed yet -- the one frame where
  -- the line can be read. Index 15 must be present as well, or a check that read the wrong
  -- address entirely would pass by finding no index 14 in a region of zeroes.
  local counts, digest = msgWindowRead()
  local bad, badWhich = illegalIndexes(counts)
  local fg, shadow = counts[1] or 0, counts[6] or 0
  -- Split three ways so a failure says WHICH half broke: line never printed, line blank, or line
  -- miscoloured. A missing baseline is a failure too, not a silent skip -- it means the run never
  -- observed the box being built and has nothing to compare against.
  F.check("the summary printed its own line over the battle-end text",
    baseline ~= nil and digest ~= baseline,
    baseline == nil and "no pre-print baseline captured"
      or string.format("baseline=0x%08X final=0x%08X", baseline, digest))
  F.check("the message line actually rendered glyphs",
    fg > 0 and shadow > 0,
    string.format("fg(idx1)=%d shadow(idx6)=%d bg(idx15)=%d", fg, shadow, counts[15] or 0))
  F.check("the message line is drawn in its own colours, not the box's",
    bad == 0, "illegal " .. badWhich)

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
