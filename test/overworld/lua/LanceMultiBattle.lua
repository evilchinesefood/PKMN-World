-- Drive the real Rocket HQ battle script from its post-party-selection seam.
-- Seed selected party slots; no fake trainer IDs or battle parties are installed.
local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "LanceMultiBattle")
F.run(function()
  if not F.boot(100) then F.check("boot", false); F.finish(); return end
  F.check("warp to Rocket HQ B2F", F.warpTo(0,9,2,0,1,4,0,0,0,92,14,"rocket_hq"))
  if F.grp() ~= 92 or F.mapn() ~= 14 then F.finish(); return end
  -- A valid three-mon selection, using the fixture's starter for each slot.
  for slot = 1, 2 do
    for byte = 0, S.Pokemon.size - 1 do
      F.w8(S.gParties + slot * S.Pokemon.size + byte, F.r8(S.gParties + byte))
    end
  end
  F.w8(S.gPartiesCount, 3)
  for i = 0, 2 do F.w8(S.gSelectedOrderFromParty + i, i + 1) end
  -- ScriptContext_SetupScript equivalent after the selection UI returns.
  F.w8(S.sGlobalScriptContext, 0)
  F.w8(S.sGlobalScriptContext + 1, 1)
  F.w32(S.sGlobalScriptContext + 4, 0)
  F.w32(S.sGlobalScriptContext + S.ScriptCtx.scriptPtr, S.MahoganyHideout_B2F_EventScript_DoLanceMultiBattle)
  F.w8(S.sGlobalScriptContextStatus, 0)
  for _ = 1, 100 do
    F.press("A", 2); F.idle(20)
    if F.reportCrash("battle_intro") then F.check("battle intro survives", false); F.finish(); return end
    if F.r8(S.gBattlersCount) == 4 and F.r16(S.gBattleMons + 2 * S.BattlePokemon.size) == 149 then break end
  end
  F.check("four battlers initialized", F.r8(S.gBattlersCount) == 4)
  F.check("Ariana opens with Arbok", F.r16(S.gBattleMons + S.BattlePokemon.size) == 24)
  F.check("Lance opens with Dragonite", F.r16(S.gBattleMons + 2 * S.BattlePokemon.size) == 149)
  F.check("Grunt opens with his existing Golbat", F.r16(S.gBattleMons + 3 * S.BattlePokemon.size) == 42)
  F.idle(240)
  F.check("Lance remains initialized after trainer intro", F.r16(S.gBattleMons + 2 * S.BattlePokemon.size) == 149)
  F.check("trainer intro did not assert", not F.reportCrash("after_intro"))
  F.shot("battle_intro")
  F.finish()
end)
