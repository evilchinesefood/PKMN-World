-- Lance's Rocket HQ multi battle must branch on how it ended: a forfeit whites the player out and
-- leaves the ambush armed, and a win runs the generator cutscene and hands back control. The
-- forfeit runs at Normal and at Hard: AreMultiPartiesFullTeams read the Hard trainer entry with no
-- Normal fallback, called the battle full-team, and on that path HandleSpecialTrainerBattleEnd
-- called it again after the battle, overwriting the outcome in VAR_RESULT with TRUE (a win).
--
-- The battle is reached the way a player reaches it: Rocket HQ B2F at VAR_MAHOGANY_TOWN_STATE 12
-- with the Murkrow gate open, a walk onto Ariana's trigger, her and Lance's lines, and three
-- Pokemon picked on the real half-party screen. The battle itself is driven with real input:
-- RUN and Yes to forfeit, then return visits: a forfeit at Hard and a fight to a win.
--
-- Run via test/overworld/mgba-run.sh test/overworld/lua/LanceMultiOutcome.lua <rom>

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "LanceMultiOutcome")

local HQ_GROUP, HQ_MAP = 92, 14
local VAR_MAHOGANY_TOWN_STATE = 0xA080 + 0x11
local FLAG_HIDE_ARIANA_AND_GRUNT = 0x6000 + 0x175
local FLAG_HIDE_GATE = 0x6000 + 0x176
local FLAG_HIDE_LANCE_DRAGONITE = 0x6000 + 0x177
local FLAG_HIDE_MURKROW_GATE = 0x6000 + 0x178
local CONTEXT_SHUTDOWN = 2
local VAR_DIFFICULTY = 0x40F8
local DIFFICULTY_HARD = 2

local function varAddr(id)
  if id >= 0xA000 then return F.sb3() + S.SaveBlock3.regionVars + (id - 0xA000) * 2 end
  return F.sb1() + S.SaveBlock1.vars + (id - 0x4000) * 2
end
local function getVar(id) return F.r16(varAddr(id)) end
local function setVar(id, v) F.w16(varAddr(id), v) end
local function flagAddr(id) return F.sb3() + S.SaveBlock3.johtoFlags + (id - 0x6000) // 8, (id - 0x6000) % 8 end
local function flagGet(id) local a, b = flagAddr(id); return (F.r8(a) >> b) & 1 == 1 end
local function flagSet(id) local a, b = flagAddr(id); F.w8(a, F.r8(a) | (1 << b)) end
local function onHq() return F.grp() == HQ_GROUP and F.mapn() == HQ_MAP end
local function where()
  local x, y = F.pos()
  return string.format("%d/%d (%d,%d) state=%d outcome=%d", F.grp(), F.mapn(), x, y, getVar(VAR_MAHOGANY_TOWN_STATE), F.outcome())
end
local function hasControl()
  return F.ow() and F.r8(S.sLockFieldControls) == 0 and F.r8(S.sGlobalScriptContextStatus) == CONTEXT_SHUTDOWN
end

local SCRIPT_BUF = S.gStringVar4 + 960
local function runScript(bytes)
  for i, b in ipairs(bytes) do F.w8(SCRIPT_BUF + i - 1, b) end
  F.w8(S.sGlobalScriptContext, 0)
  F.w8(S.sGlobalScriptContext + 1, 1)
  F.w32(S.sGlobalScriptContext + 4, 0)
  F.w32(S.sGlobalScriptContext + S.ScriptCtx.scriptPtr, SCRIPT_BUF)
  F.w8(S.sGlobalScriptContextStatus, 0)
  F.idle(20)
end
local function le16(t, v) t[#t + 1] = v & 0xFF; t[#t + 1] = (v >> 8) & 0xFF end
local function le32(t, v) le16(t, v & 0xFFFF); le16(t, (v >> 16) & 0xFFFF) end
local function createMon(species, level, moves)
  local b = { 0x23 }; le32(b, S.ScrCmd_createmon | 1)
  b[#b + 1] = 0; b[#b + 1] = 6
  le16(b, species); le16(b, level)
  le32(b, (1 << 17) | (1 << 18) | (1 << 19) | (1 << 20))
  for k = 1, 4 do le16(b, moves[k] or 0) end
  b[#b + 1] = 0x02
  runScript(b)
end

local function inBattle() return F.cb2() == (S.BattleMainCB2 & ~1) end
local function controller() return F.r32(S.gBattlerControllerFuncs) & ~1 end
local function actionMenu()
  local fn = controller()
  for _, p in ipairs(S.ActionInputFunctions) do if fn == (p & ~1) then return true end end
  return false
end

-- Walk onto Ariana's trigger, advance her and Lance's lines, and pick the first three Pokemon on
-- the half-party screen (A opens a slot's menu, A takes Enter, Start confirms). Returns once the
-- battle is on screen.
local function ambush(tag, difficulty)
  if not F.warpTo(0, 9, 2, 0, 1, 4, 0, 0, 0, HQ_GROUP, HQ_MAP, tag) then return false end
  -- The field load re-syncs VAR_DIFFICULTY to the saved region, so a tier is set after the warp.
  if difficulty then setVar(VAR_DIFFICULTY, difficulty) end
  if not F.route({ { 3, 25 }, { 10, 25 }, { 10, 23 }, { 14, 23 }, { 14, 18 } }, tag .. "_walk") then return false end
  local menu = false
  for _ = 1, 400 do
    if F.cb2() == S.CB2_UpdatePartyMenu then menu = true; break end
    F.press("A", 2); F.idle(20)
  end
  F.check(tag .. ": the ambush reached the half-party screen", menu, where())
  if not menu then F.shot(tag .. "_no_menu"); return false end
  F.idle(60)
  for slot = 1, 3 do
    F.press("A", 2); F.idle(30); F.press("A", 2); F.idle(40)
    if slot < 3 then F.press("Down", 2); F.idle(20) end
  end
  F.press("Start", 2)
  local picked = {}
  for i = 0, 2 do picked[#picked + 1] = F.r8(S.gSelectedOrderFromParty + i) end
  F.L(string.format("  %s: picked %s", tag, table.concat(picked, ",")))
  -- The multi battle shows both sides' parties before its intro; A moves past it.
  for _ = 1, 150 do
    if inBattle() then return true end
    F.press("A", 2); F.idle(18)
  end
  F.shot(tag .. "_no_battle")
  F.check(tag .. ": the multi battle started", false, where())
  return false
end

-- Advance the battle with real input: on the action menu either RUN (steered by the cursor) or FIGHT
-- (A); Up and A answer the forfeit prompt; A advances text and picks a move and its target.
local function driveBattle(tag, run, assist)
  local atPrompt = false
  for i = 1, 20000 do
    if F.reportCrash(tag) then return false end
    if not inBattle() then return true end
    if assist and i % 30 == 0 then
      for b = 0, F.battlers() - 1 do
        local a = S.gBattleMons + b * S.BattlePokemon.size
        local hp = F.r16(a + S.BattlePokemon.hp)
        if b % 2 == 1 and hp > 1 then F.w16(a + S.BattlePokemon.hp, 1) end
        if b % 2 == 0 and hp > 0 then F.w16(a + S.BattlePokemon.hp, F.r16(a + S.BattlePokemon.maxHP)) end
      end
    end
    local key
    if i % 12 < 2 then
      local fn = controller()
      if fn == (S.PlayerHandleYesNoInput & ~1) then
        key = atPrompt and "A" or "Up"; atPrompt = not atPrompt
      elseif run and actionMenu() then
        local cur = F.r8(S.gActionSelectionCursor)
        key = cur == 3 and "A" or (cur % 2 == 0 and "Right" or "Down")
      else
        key = "A"
      end
    end
    joypad.set(key and { [key] = true } or {})
    emu.frameadvance()
  end
  return false
end

-- After the battle: advance any lines with A until the player can walk.
local function settle(tag)
  for _ = 1, 3000 do
    if F.reportCrash(tag) then return false end
    if hasControl() then F.idle(30); if hasControl() then return true end end
    F.press("A", 2); F.idle(10)
  end
  return false
end

local function forfeit(tag, difficulty)
  if not ambush(tag, difficulty) then return false end
  local ended = driveBattle(tag, true, false)
  F.L("  " .. tag .. ": battle ended " .. where())
  F.check(tag .. ": the battle ended in a forfeit", ended and F.outcome() == 9, where())
  local free = settle(tag)
  F.shot("after_" .. tag)
  F.check(tag .. ": the player regains control", free, where())
  F.check(tag .. ": the player whited out of Rocket HQ", not onHq(), where())
  F.check(tag .. ": the ambush is still armed (state 12)", getVar(VAR_MAHOGANY_TOWN_STATE) == 12, where())
  F.check(tag .. ": Ariana and her Grunt are hidden again", flagGet(FLAG_HIDE_ARIANA_AND_GRUNT))
  return free
end

F.run(function()
  if not F.boot(100) then F.check("boot to the hub", false); F.finish(); return end
  while F.r8(S.gPartiesCount) < 3 do
    local n = F.r8(S.gPartiesCount)
    createMon(({ 6, 9, 3 })[n + 1], 50, { 33 })
    if F.r8(S.gPartiesCount) == n then break end
  end
  F.check("party of three", F.r8(S.gPartiesCount) >= 3, "n=" .. F.r8(S.gPartiesCount))

  -- Rocket HQ as the Murkrow gate scene leaves it: state 12, the gate open, Ariana, her Grunt,
  -- Lance and his Dragonite still hidden until the ambush adds them.
  setVar(VAR_MAHOGANY_TOWN_STATE, 12)
  for _, id in ipairs({ FLAG_HIDE_GATE, FLAG_HIDE_MURKROW_GATE, FLAG_HIDE_ARIANA_AND_GRUNT, FLAG_HIDE_LANCE_DRAGONITE }) do flagSet(id) end

  if not forfeit("forfeit") then F.finish(); return end
  -- Hard is the tier SyncDifficultyForRegion gives a region champion. Ariana's Hard entry has no
  -- party, so her Normal one (Multi Party: Half) is the one that battles, and the half-team check
  -- must read the same entry.
  if not forfeit("hard_forfeit", DIFFICULTY_HARD) then F.finish(); return end

  if not ambush("win") then F.finish(); return end
  ended = driveBattle("win", false, true)
  F.L("  win: battle ended " .. where())
  F.check("win: the battle was won", ended and F.outcome() == 1, where())
  free = settle("win")
  F.shot("after_win")
  F.check("win: the player regains control", free, where())
  local x, y = F.pos()
  F.check("win: the cutscene ran to the generator (state 13)", getVar(VAR_MAHOGANY_TOWN_STATE) == 13, where())
  F.check("win: the player stands beside Lance at (12,17)", onHq() and x == 12 and y == 17, where())
  F.finish()
end)
