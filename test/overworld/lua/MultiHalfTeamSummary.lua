-- In a half-team multi battle the party menu draws the player's three Pokemon in rows 0-2 and the
-- partner's in rows 3-5, while the summary screen and GetMultiPartyForSummaryScreen use the
-- interleaved upstream order [P0, Partner0, P1, P2, Partner1, Partner2]. Summary from the party
-- menu must open the Pokemon under the cursor, and B must bring the cursor back to it
-- (0829014ec0 translates between the two at the hand-off).
--
-- The real Rocket HQ multi with Lance (MahoganyHideout_B2F_EventScript_DoLanceMultiBattle) runs
-- from its post-selection seam with three distinct debug-made Pokemon chosen. In battle, real
-- input opens POKEMON, moves to each of the player's rows, opens Summary and closes it. Rows 0, 1
-- and 2 must open summary indices 0, 2 and 3 (gLastViewedMonIndex, left by the summary on close, in
-- the interleaved order; the screenshots show Bulbasaur, Charmander and Squirtle), and B must put
-- the party cursor back on the row.
--
-- Run via test/overworld/mgba-run.sh test/overworld/lua/MultiHalfTeamSummary.lua <rom>

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "MultiHalfTeamSummary")

local MON = S.Pokemon.size
local TEAM = { 1, 4, 7 }
local PARTY_MENU_SLOT = 9
local MENU_TO_SUMMARY = { [0] = 0, 2, 3 }

local function digits(n) n = n - 1; return n // 100, (n // 10) % 10, n % 10 end
local function inBattle() return F.cb2() == (S.BattleMainCB2 & ~1) end
local function inPartyMenu() return F.cb2() == (S.CB2_UpdatePartyMenu & ~1) end
local function ctrl(b) return F.r32(S.gBattlerControllerFuncs + b * 4) & ~1 end
local function actionMenu()
  for _, p in ipairs(S.ActionInputFunctions) do if ctrl(0) == (p & ~1) then return true end end
  return false
end

F.run(function()
  if not F.boot(100) then F.check("boot", false); F.finish(); return end
  for off = 0, 6 * MON - 4, 4 do F.w32(S.gParties + off, 0) end
  F.w8(S.gPartiesCount, 0)
  F.dbg(); F.idle(30); F.bOut(4)
  for _, sp in ipairs(TEAM) do
    F.dbg(); F.sel(3); F.sel(1); F.idle(20); F.spin(digits(sp)); F.idle(20); F.spin(0, 4, 9); F.idle(60); F.bOut(4)
  end
  F.check("setup: three Pokemon", F.r8(S.gPartiesCount) == 3, "n=" .. F.r8(S.gPartiesCount))
  F.check("warp to Rocket HQ B2F", F.warpTo(0, 9, 2, 0, 1, 4, 0, 0, 0, 92, 14, "rocket_hq"))
  if F.grp() ~= 92 or F.mapn() ~= 14 then F.finish(); return end
  for i = 0, 2 do F.w8(S.gSelectedOrderFromParty + i, i + 1) end
  F.w8(S.sGlobalScriptContext, 0)
  F.w8(S.sGlobalScriptContext + 1, 1)
  F.w32(S.sGlobalScriptContext + 4, 0)
  F.w32(S.sGlobalScriptContext + S.ScriptCtx.scriptPtr, S.MahoganyHideout_B2F_EventScript_DoLanceMultiBattle)
  F.w8(S.sGlobalScriptContextStatus, 0)
  local ready = false
  for _ = 1, 3000 do
    if inBattle() and actionMenu() then ready = true; break end
    if F.reportCrash("intro") then break end
    F.press("A", 2); F.idle(10)
  end
  F.check("the multi battle reached the action menu", ready)
  if not ready then F.finish(); return end
  F.idle(30)
  F.press("Down", 2); F.idle(20)
  F.shot("action_pokemon")
  F.press("A", 2)
  for _ = 1, 200 do F.idle(3); if inPartyMenu() then break end end
  F.idle(60)
  F.shot("party_menu")
  for row = 0, 2 do
    F.press("A", 2); F.idle(40)
    F.shot("row" .. row .. "_actions")
    F.press("Down", 2); F.idle(20)      -- Summary under Shift
    F.press("A", 2)
    for _ = 1, 200 do F.idle(3); if not inPartyMenu() then break end end
    F.idle(90)
    F.shot("row" .. row .. "_summary")
    local opened = not inPartyMenu()
    F.press("B", 2)
    for _ = 1, 200 do F.idle(3); if inPartyMenu() then break end end
    F.idle(60)
    F.shot("row" .. row .. "_back")
    -- The summary leaves the index it showed in gLastViewedMonIndex when it closes.
    local idx = F.r8(S.gLastViewedMonIndex)
    F.check("row " .. row .. ": Summary opened the Pokemon under the cursor (index " .. MENU_TO_SUMMARY[row] .. ")",
      opened and idx == MENU_TO_SUMMARY[row], string.format("index=%d", idx))
    F.check("row " .. row .. ": B returns the party cursor to the row", inPartyMenu()
      and F.rs8(S.gPartyMenu + PARTY_MENU_SLOT) == row, "slot=" .. F.rs8(S.gPartyMenu + PARTY_MENU_SLOT))
    F.press("B", 2); F.idle(30)         -- the party menu reopens with the action menu up
    F.press("Down", 2); F.idle(20)
  end
  F.check("no crash screen", not F.crashScreen())
  F.finish()
end)
