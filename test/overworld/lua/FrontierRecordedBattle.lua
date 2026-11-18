-- A Battle Frontier battle recorded on the Frontier Pass must play back with the Pokemon that fought.
--
-- The lobby offers "record your last match" after the challenge, when the facility has already put
-- the player's own party back and cleared the opponent's. MoveRecordedBattleToSaveData copied the
-- live gParties at that moment, so the record held the player's full party in its own order and an
-- empty opponent party: playback sent out a nameless level 0 Pokemon against the wrong lead.
--
-- The suite takes the Battle Arena Lv. 50 challenge with real input, picking Venusaur, Blastoise and
-- Charizard in that order (the party itself leads with Charizard). The first six battles are won
-- with the opponents held at 1 HP; the seventh is fought straight (no memory writes, so its record
-- replays faithfully) and either result leads to the record prompt. Both leads and their max HP are
-- noted at the start of the seventh battle, and the record prompt is answered Yes. It then opens the Frontier Pass from the Start menu, moves the cursor to
-- Battle Record and plays the record: both leads at the start of playback must be the ones that
-- fought, and playback must return to the Frontier Pass.
--
-- Passing --env PW_CASE=palace checks the autonomous move and target chosen in the first Palace battle.
-- Passing --env PW_CASE=factory records the second Factory battle after swapping the lead rental for the first opponent.
-- Run via: test/overworld/mgba-run.sh test/overworld/lua/FrontierRecordedBattle.lua <rom.gba>

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "FrontierRecordedBattle")

local FRONTIER = 26
local facility = os.getenv("PW_CASE") or "arena"
local palace, factory = facility == "palace", facility == "factory"
local cases = {
  arena = { lobby = 28, bout = 7, attendant = { { 7, 11 }, { 7, 8 } } },
  palace = { lobby = 22, bout = 1, attendant = { { 12, 10 }, { 5, 10 }, { 5, 7 } } },
  factory = { lobby = 31, bout = 2, attendant = { { 9, 9 }, { 4, 9 }, { 4, 8 } } },
}
local case = assert(cases[facility], "Unknown recording case: " .. facility)
local rentals = require("frontier_rentals")
local FLAG_SYS_FRONTIER_PASS = 0x948 + 0x72
local USM_ICO_TRAINER = 5

local SCRIPT_BUF = S.gStringVar4 + 960
local function le16(t, v) t[#t + 1] = v & 0xFF; t[#t + 1] = (v >> 8) & 0xFF end
local function le32(t, v) le16(t, v & 0xFFFF); le16(t, (v >> 16) & 0xFFFF) end
local function giveMon(species, moves)
  local b = { 0x23 }; le32(b, S.ScrCmd_createmon | 1)
  b[#b + 1] = 0; b[#b + 1] = 6
  le16(b, species); le16(b, 50)
  le32(b, (1 << 17) | (1 << 18) | (1 << 19) | (1 << 20))
  for i = 1, 4 do le16(b, moves[i] or 0) end
  b[#b + 1] = 0x02
  for i, v in ipairs(b) do F.w8(SCRIPT_BUF + i - 1, v) end
  F.w8(S.sGlobalScriptContext, 0)
  F.w8(S.sGlobalScriptContext + 1, 1)
  F.w32(S.sGlobalScriptContext + 4, 0)
  F.w32(S.sGlobalScriptContext + S.ScriptCtx.scriptPtr, SCRIPT_BUF)
  F.w8(S.sGlobalScriptContextStatus, 0)
  F.idle(20)
end
local function setFlag(id)
  local a = F.sb1() + S.SaveBlock1.flags + id // 8
  F.w8(a, F.r8(a) | (1 << (id % 8)))
end

local function liveMenu()
  for i = 0, S.Task.count - 1 do
    local task = S.gTasks + i * S.Task.stride
    local fn = F.r32(task + S.Task.func) & 0xFFFFFFFE
    if F.r8(task + S.Task.isActive) ~= 0 then
      if fn == S.Task_HandleYesNoInput or fn == S.Task_CallYesOrNoCallback then return "yesno" end
      if fn == S.Task_HandleMultichoiceInput then return "multi" end
    end
  end
end
local function choose(want)
  for _ = 1, 8 do
    local c = F.mcur()
    if c == want then F.press("A", 2); F.idle(45); return true end
    F.press(c > want and "Up" or "Down", 2); F.idle(12)
  end
  return false
end
local function menu(want, tag)
  for _ = 1, 80 do
    if F.reportCrash("menu_" .. tag) then return false end
    if liveMenu() then F.idle(12); return choose(want) end
    F.press("A", 2); F.idle(30)
  end
  F.L("  " .. tag .. ": no menu went live"); return false
end

local function cb(addr) return F.cb2() == (addr & ~1) end
local function inPartyMenu() return cb(S.CB2_UpdatePartyMenu) or cb(S.CB2_InitPartyMenu) end
local function inBattle() return cb(S.BattleMainCB2) end
local function scriptIdle() return F.r8(S.sGlobalScriptContextStatus) == 2 end

-- Party slots 3, 2, 1: each pick is A (open the slot's menu) and A (Enter).
local function pickReversed()
  for _ = 1, 300 do
    if inPartyMenu() then break end
    F.press("A", 2); F.idle(20)
  end
  if not inPartyMenu() then return false end
  F.idle(60)
  F.press("Down", 2); F.idle(20); F.press("Down", 2); F.idle(20)
  for i = 1, 3 do
    F.press("A", 2); F.idle(30); F.press("A", 2); F.idle(40)
    if i < 3 then F.press("Up", 2); F.idle(20) end
  end
  F.shot("picked")
  F.press("Start", 2); F.idle(40)
  for _ = 1, 8 do
    if not inPartyMenu() then break end
    F.press("A", 2); F.idle(60)
  end
  return not inPartyMenu()
end

local function leads()
  local function mon(b)
    local a = S.gBattleMons + b * S.BattlePokemon.size
    return { species = F.r16(a), maxHP = F.r16(a + S.BattlePokemon.maxHP) }
  end
  return { player = mon(0), foe = mon(1) }
end
local function fmt(l) return string.format("player %d (%d HP) foe %d (%d HP)", l.player.species, l.player.maxHP, l.foe.species, l.foe.maxHP) end

-- Waits out the battle intro so gBattleMons holds both leads.
local function settleLeads()
  for _ = 1, 600 do
    F.idle(1)
    local l = leads()
    if F.r8(S.gBattlersCount) > 0 and l.player.maxHP > 0 and (l.foe.maxHP > 0 or l.foe.species == 0) then F.idle(120); return leads() end
  end
  return leads()
end

local function steerBattle(f, honest)
  if not honest then
    for b = 1, 3, 2 do
      local a = S.gBattleMons + b * S.BattlePokemon.size
      if F.r16(a + S.BattlePokemon.hp) > 1 then F.w16(a + S.BattlePokemon.hp, 1) end
    end
    local a = S.gBattleMons
    local mx = F.r16(a + S.BattlePokemon.maxHP)
    if F.r16(a + S.BattlePokemon.hp) > 0 and mx > 0 then F.w16(a + S.BattlePokemon.hp, mx) end
  end
  if f % 20 ~= 0 then F.idle(1); return end
  if (F.r32(S.gBattlerControllerFuncs) & ~1) == (S.HandleInputChooseMove & ~1) then
    local slot = 0
    if factory then
      slot = (f // 20) % 4
    elseif not honest then
      slot = (f // 20) % 2
    end
    F.press("Up", 2); F.idle(4); F.press("Left", 2); F.idle(4)
    if slot % 2 == 1 then F.press("Right", 2); F.idle(4) end
    if slot >= 2 then F.press("Down", 2); F.idle(4) end
  end
  F.press("A", 2)
end

local trace
local frameadvance = emu.frameadvance
emu.frameadvance = function()
  if trace and cb(S.CB2_QuitRecordedBattle) then trace.quit = true end
  if trace and inBattle() then
    local ordering = (F.r32(S.gBattleMainFunc) & ~1) == S.SetActionsAndBattlersTurnOrder
    if ordering and not trace.ordering then
      local p = S.gBattleMons
      local e = p + S.BattlePokemon.size
      if palace then
        local flags = S.ProtectStruct
        local unable = F.r16(S.gProtectStructs) & flags.palaceUnableToUseMove
        local foeUnable = F.r16(S.gProtectStructs + flags.size) & flags.palaceUnableToUseMove
        trace.choices[#trace.choices + 1] = string.format("%d:%d/%d:%d", F.r16(S.gChosenMoveByBattler), unable,
          F.r16(S.gChosenMoveByBattler + 2), foeUnable)
      elseif factory then
        trace.choices[#trace.choices + 1] = string.format("%d/%d", F.r16(S.gChosenMoveByBattler),
          F.r16(S.gChosenMoveByBattler + 2))
      end
      trace[#trace + 1] = string.format("%d:%d/%d:%d", F.r16(p), F.r16(p + S.BattlePokemon.hp),
        F.r16(e), F.r16(e + S.BattlePokemon.hp))
    end
    trace.ordering = ordering
    local outcome = F.r8(S.gBattleOutcome)
    if #trace > 0 and outcome ~= 0 then trace.outcome = outcome end
  end
  return frameadvance()
end

F.run(function()
  assert(F.boot(100), "Fresh game did not boot")
  giveMon(6, { 53, 89 }); giveMon(9, { 57, 58 }); giveMon(3, { 202, 89 }); giveMon(25, { 85 })
  F.check("four Pokemon in the party", F.r8(S.gPartiesCount) == 4, "n=" .. F.r8(S.gPartiesCount))
  setFlag(FLAG_SYS_FRONTIER_PASS)
  local lobby, bout = case.lobby, case.bout
  assert(F.warpTo(0, 2, 6, 0, lobby // 10, lobby % 10, 0, 0, 0, FRONTIER, lobby, "lobby"), "lobby warp failed")
  F.idle(60)
  F.check("walked to the facility attendant", F.route(case.attendant, "attendant"))
  F.face("Up"); F.press("A", 2); F.idle(30)
  F.check("took the Lv. 50 challenge",
    menu(0, "challenge") and menu(0, "lv50") and (factory or pickReversed()) and menu(0, "save"))

  local original, playback = { choices = {} }, { choices = {} }
  local battles, inB, last, ended = 0, false, nil, false
  local tradeSpecies
  for f = 1, 120000 do
    if F.reportCrash("challenge_" .. f) then break end
    if factory and cb(S.CB2_SelectScreen) then
      rentals.rentThree(F)
    elseif factory and cb(S.Swap_CB2) then
      rentals.swapFirst(F)
    elseif inBattle() then
      if not inB then
        inB, battles = true, battles + 1
        if battles == bout then trace = original; last = settleLeads(); F.L("  recorded battle: " .. fmt(last)) end
      end
      if factory and battles == 1 and not tradeSpecies then
        local foe = S.gBattleMons + S.BattlePokemon.size
        if F.r16(foe + S.BattlePokemon.hp) > 0 then tradeSpecies = F.r16(foe) end
      end
      steerBattle(f, battles == bout)
    elseif inPartyMenu() then
      F.idle(60)
      for slot = 1, 2 do
        if F.r16(S.gParties + slot * S.Pokemon.size + S.Pokemon.hp) > 0 then
          for _ = 1, 6 do
            if F.rs8(S.gPartyMenu + 9) == slot then break end
            F.press("Down", 2); F.idle(12)
          end
          F.press("A", 2); F.idle(40); F.press("A", 2); F.idle(60)
          break
        end
      end
    else
      if inB and F.ow() then inB = false end
      if liveMenu() then
        F.idle(20)
        local lastOption = F.r8(S.sMenu + S.Menu.maxCursorPos)
        -- After the tested bout, return to the lobby to save its record.
        choose((palace or factory) and battles == bout and lastOption >= 2 and lastOption or 0)
      elseif f % 30 == 0 then
        F.press("A", 2)
      else
        F.idle(1)
      end
      if battles >= bout and F.grp() == FRONTIER and F.mapn() == lobby and F.ow() and scriptIdle() and not liveMenu() then
        F.idle(240)
        if scriptIdle() and not liveMenu() then ended = true; break end
      end
    end
  end
  trace = nil
  F.check("completed the expected battle and came back to the lobby", ended and battles == bout, "battles=" .. battles)
  local expectedLead = 3
  if factory then expectedLead = tradeSpecies end
  F.check(factory and "the traded rental led the recorded battle" or "the recorded battle led with Venusaur",
    last ~= nil and last.player.species == expectedLead, last and fmt(last) or "none")
  if not last then F.finish(); return end

  F.press("Start", 2); F.idle(60)
  F.check("the Start menu offers the Frontier Pass", F.selectStartIcon(USM_ICO_TRAINER))
  F.press("A", 2); F.idle(200)
  -- The pass cursor moves 2 px a frame; from where it opens this lands on Battle Record.
  for _ = 1, 60 do joypad.set({ Left = true }); emu.frameadvance() end
  for _ = 1, 25 do joypad.set({ Down = true }); emu.frameadvance() end
  for _ = 1, 6 do joypad.set({ Up = true }); emu.frameadvance() end
  F.idle(20); F.shot("pass_battle_record")
  F.press("A", 2)

  local played, back = nil, false
  trace = playback
  for f = 1, (factory and 150000 or 30000) do
    if F.reportCrash("playback_" .. f) then break end
    if not played and inBattle() then
      played = settleLeads()
      F.shot("playback")
      F.L("  playback: " .. fmt(played))
    end
    if played and not inBattle() and f % 60 == 0 then
      F.idle(240)
      back = cb(S.CB2_FrontierPass)
      break
    end
    F.idle(1)
  end
  trace = nil
  F.shot("after_playback")
  F.check("the record plays", played ~= nil)
  F.check("playback leads with the Pokemon that fought", played ~= nil and played.player.species == last.player.species
    and played.player.maxHP == last.player.maxHP, played and fmt(played) or "no playback")
  F.check("playback's opponent is the one that fought", played ~= nil and played.foe.species == last.foe.species
    and played.foe.maxHP == last.foe.maxHP and last.foe.species ~= 0, played and fmt(played) or "no playback")
  F.check("playback returns to the Frontier Pass", back, string.format("cb2=%08X", F.cb2()))
  F.check("the same Pokemon and HP start every recorded turn",
    #original > 0 and table.concat(original, ",") == table.concat(playback, ","),
    table.concat(original, ",") .. " vs " .. table.concat(playback, ","))
  if palace or factory then
    F.check(palace and "the Palace keeps both selected moves and inability flags on every turn"
      or "the Factory replays both trainers' chosen moves on every turn",
      #original.choices > 0 and table.concat(original.choices, ",") == table.concat(playback.choices, ","),
      table.concat(original.choices, ",") .. " vs " .. table.concat(playback.choices, ","))
  end
  F.check("the replay ends with the original battle outcome",
    not playback.quit and (original.outcome == 1 or original.outcome == 2 or original.outcome == 3) and original.outcome == playback.outcome,
    tostring(original.outcome) .. " vs " .. tostring(playback.outcome) .. (playback.quit and " (quit)" or ""))
  F.check("no crash screen", not F.crashScreen())
  F.finish()
end)
