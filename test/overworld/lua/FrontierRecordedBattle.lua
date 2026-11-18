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
-- noted at the start of the seventh battle, and the record prompt is answered Yes. It then opens the
-- Frontier Pass from the Start menu, moves the cursor to Battle Record and plays the record: both
-- leads at the start of playback must be the ones that fought, and playback must return to the
-- Frontier Pass. Every recorded turn must start with the same Pokemon and HP, and the replay must
-- end with the original outcome.
--
-- PW_CASE picks the facility:
--   palace    the autonomous move and target chosen in the first Palace battle.
--   dome      the first round of a Battle Dome tourney.
--   factory   the second Factory battle, after swapping the lead rental for the first opponent.
--   tower     the first Battle Tower singles battle. Before the record is saved, the lobby prompt is
--             replayed from a savestate with a soft reset at several frame offsets after Yes and with
--             seeded mashes; each Continue must leave a walkable lobby. Playback is mashed with every
--             button but B, then watched again and quit with B mid-battle.
--   seminar   the first Battle Tower singles battle led by Snorlax, whose Body Slam is not very
--             effective against the default seed's Geodude. Battle TV's seminar estimate runs on that
--             message during the live battle only, so it must not spend the battle's RNG.
--   batonpass the seminar battle with the opponent's lead rewritten during the battle transition to
--             know only Baton Pass, so the trainer AI chooses a Pokemon in the middle of the turn.
--   batonslow the batonpass battle with Snorlax using Vital Throw (priority -1), so the trainer AI
--             chooses the Baton Pass replacement before Snorlax's damage roll.
--   encore    Battle Tower doubles. On turn 1 Clefable Encores its ally Jolteon; on turn 2 Jolteon's
--             move is chosen, Clefable's action menu is cancelled with B, and Jolteon chooses again.
--             The cancel must remove all three of Jolteon's recorded bytes (action, slot, target).
--   legacy    continues the save passed to the runner (fixtures/palace_legacy_record.srm, a Palace
--             record made before turn seeding) and plays it. The trace must equal that ROM's own
--             playback; PW_EXPECT_TRACE and PW_EXPECT_CHOICES override it for another fixture.
--   overflow  Battle Tower singles. The first battle is recorded from the battle room's Record option;
--             the second is stretched past the record buffer with both sides' HP held, cancelled move
--             and switch menus every turn, then lost. The lobby must not offer to record it, and the
--             Frontier Pass must still play the first battle.
-- PW_SEED varies the mashes (default 1). PW_TEXT sets the text speed (0 slow .. 3 instant).
-- Run via: test/overworld/mgba-run.sh test/overworld/lua/FrontierRecordedBattle.lua <rom.gba>

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "FrontierRecordedBattle")

local FRONTIER = 26
local BATTLER_RECORD_SIZE = 388
local facility = os.getenv("PW_CASE") or "arena"
local seed = tonumber(os.getenv("PW_SEED") or "1")
local textSpeed = tonumber(os.getenv("PW_TEXT") or "")

local STARTERS = { { 6, { 53, 89 } }, { 9, { 57, 58 } }, { 3, { 202, 89 } }, { 25, { 85 } } }
local TOWER_SINGLES = { { 12, 6 }, { 6, 6 } }
local cases = {
  arena = { lobby = 28, bout = 7, attendant = { { 7, 11 }, { 7, 8 } }, party = STARTERS, pick = { 2, 1, 0 } },
  palace = { lobby = 22, bout = 1, attendant = { { 12, 10 }, { 5, 10 }, { 5, 7 } }, party = STARTERS,
    pick = { 2, 1, 0 }, retire = true, choices = true },
  factory = { lobby = 31, bout = 2, attendant = { { 9, 9 }, { 4, 9 }, { 4, 8 } }, party = STARTERS,
    retire = true, choices = true, rentals = true },
  tower = { lobby = 5, bout = 1, attendant = TOWER_SINGLES, party = STARTERS, pick = { 2, 1, 0 },
    retire = true, resetSweep = true, mash = true },
  dome = { lobby = 18, bout = 1, attendant = { { 11, 12 }, { 5, 12 }, { 5, 11 } }, party = STARTERS, pick = { 2, 1, 0 },
    retire = true },
  seminar = { lobby = 5, bout = 1, attendant = TOWER_SINGLES, retire = true,
    party = { { 143, { 34, 89 } }, { 9, { 57, 58 } }, { 3, { 202, 89 } } }, pick = { 0, 1, 2 } },
  batonpass = { lobby = 5, bout = 1, attendant = TOWER_SINGLES, retire = true, foeBatonPass = true,
    party = { { 143, { 34, 89 } }, { 9, { 57, 58 } }, { 3, { 202, 89 } } }, pick = { 0, 1, 2 } },
  batonslow = { lobby = 5, bout = 1, attendant = TOWER_SINGLES, retire = true, foeBatonPass = true,
    party = { { 143, { 233, 34 } }, { 9, { 57, 58 } }, { 3, { 202, 89 } } }, pick = { 0, 1, 2 } },
  encore = { lobby = 5, bout = 1, attendant = { { 12, 6 }, { 10, 6 } }, doubles = true, retire = true,
    party = { { 135, { 85, 98 } }, { 36, { 34, 227 } }, { 3, { 202, 188 } }, { 9, { 58, 56 } } }, pick = { 0, 1, 2, 3 } },
  -- fixtures/palace_legacy_record.srm, recorded on 3557e2bab6, and that ROM's own playback of it.
  legacy = { lobby = 22, legacy = true, expect = "3:145/15:126,3:105/15:109,3:114/15:91,3:122/15:75,3:131/15:57",
    expectChoices = "202:0/41:0,202:0/97:0,202:0/97:0,202:0/97:0,202:16384/283:0" },
  overflow = { lobby = 5, bout = 2, saved = 1, attendant = TOWER_SINGLES, battleSceneOff = true, text = 3,
    party = { { 373, { 337, 89, 150, 45 } }, { 376, { 309, 89, 150, 45 } }, { 248, { 157, 242, 150, 45 } } }, pick = { 0, 1, 2 } },
}
local case = assert(cases[facility], "Unknown recording case: " .. facility)
local factory, palace = facility == "factory", facility == "palace" or facility == "legacy"
local savedBout = case.saved or case.bout
local rentals = require("frontier_rentals")
local FLAG_SYS_FRONTIER_PASS = 0x948 + 0x72
local FLAG_SYS_POKEMON_GET = 0x948
local USM_ICO_TRAINER = 5

local rngState = seed
local function rand(n)
  rngState = (rngState * 1103515245 + 12345) % 2147483648
  return (rngState >> 16) % n
end

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
local function setOptions()
  local a = F.sb2() + S.SaveBlock2.optionsU16
  local v = F.r16(a)
  local speed = textSpeed or case.text
  if speed then v = (v & ~7) | speed end
  if case.battleSceneOff then v = v | (1 << 10) end
  F.w16(a, v)
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
local function partySlot() return F.rs8(S.gPartyMenu + 9) end

-- Picks the given party slots in order: each pick is A (open the slot's menu) and A (Enter).
local function pickSlots(order)
  for _ = 1, 300 do
    if inPartyMenu() then break end
    F.press("A", 2); F.idle(20)
  end
  if not inPartyMenu() then return false end
  F.idle(60)
  for _, slot in ipairs(order) do
    for _ = 1, 8 do
      if partySlot() == slot then break end
      F.press(partySlot() > slot and "Up" or "Down", 2); F.idle(20)
    end
    F.press("A", 2); F.idle(30); F.press("A", 2); F.idle(40)
  end
  F.shot("picked")
  F.press("Start", 2); F.idle(40)
  for _ = 1, 8 do
    if not inPartyMenu() then break end
    F.press("A", 2); F.idle(60)
  end
  return not inPartyMenu()
end

local function mon(b) return S.gBattleMons + b * S.BattlePokemon.size end
local function leads()
  local function info(b) return { species = F.r16(mon(b)), maxHP = F.r16(mon(b) + S.BattlePokemon.maxHP) } end
  return { player = info(0), foe = info(1) }
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

local function recordSize(b) return F.r16(S.sBattlerRecordSizes + b * 2) end
local function dropped(b) return S.sDroppedRecordBytes ~= 0 and F.r32(S.sDroppedRecordBytes + b * 4) or 0 end
local function controller(b) return F.r32(S.gBattlerControllerFuncs + b * 4) & ~1 end
local function choosingAction(b)
  for _, fn in ipairs(S.ActionInputFunctions) do
    if controller(b) == (fn & ~1) then return true end
  end
  return false
end
local function choosingMove(b) return controller(b) == (S.HandleInputChooseMove & ~1) end
local function choosingTarget(b) return controller(b) == (S.HandleInputChooseTarget & ~1) end

local function moveCursor(slot)
  F.press("Up", 2); F.idle(4); F.press("Left", 2); F.idle(4)
  if slot % 2 == 1 then F.press("Right", 2); F.idle(4) end
  if slot >= 2 then F.press("Down", 2); F.idle(4) end
end

local function steerBattle(f, honest)
  if not honest then
    for b = 1, 3, 2 do
      if F.r16(mon(b) + S.BattlePokemon.hp) > 1 then F.w16(mon(b) + S.BattlePokemon.hp, 1) end
    end
    local mx = F.r16(mon(0) + S.BattlePokemon.maxHP)
    if F.r16(mon(0) + S.BattlePokemon.hp) > 0 and mx > 0 then F.w16(mon(0) + S.BattlePokemon.hp, mx) end
  end
  if f % 20 ~= 0 then F.idle(1); return end
  if choosingMove(0) then
    local slot = 0
    if factory then
      slot = (f // 20) % 4
    elseif not honest then
      slot = (f // 20) % 2
    end
    moveCursor(slot)
  end
  F.press("A", 2)
end

local trace

-- The opponent's lead knows only Baton Pass, so the trainer's AI picks the Pokemon it passes to in
-- the middle of the turn. Written while the battle transition runs, before the record copies the parties.
local BATTLE_TYPE_BATTLE_TOWER, MOVE_BATON_PASS = 1 << 8, 226
local function foeLeadBatonPassOnly()
  local a = S.gParties + 6 * S.Pokemon.size
  local personality = F.r32(a)
  if personality == 0 then return false end
  local key = personality ~ F.r32(a + 4)
  local w = {}
  for i = 0, 11 do w[i] = F.r32(a + 32 + i * 4) ~ key end
  local o = F.r8(S.sSubstructOffsets + 24 + personality % 24) * 3
  w[o], w[o + 1], w[o + 2] = MOVE_BATON_PASS, 0, 40
  local sum = 0
  for i = 0, 11 do sum = sum + w[i] + (w[i] >> 16) end
  F.w16(a + 28, sum & 0xFFFF)
  for i = 0, 11 do F.w32(a + 32 + i * 4, w[i] ~ key) end
  return true
end

-- Doubles: turn 1 Clefable (battler 2) Encores Jolteon (battler 0); turn 2 Clefable cancels back.
local encore = { cancels = {} }
local function steerEncore(f)
  local turn = #trace + 1
  for b = 0, 2, 2 do
    if choosingAction(b) then
      if b == 2 and turn == 2 and #encore.cancels == 0 then
        local before = recordSize(0) + dropped(0)
        F.press("B", 2)
        for _ = 1, 120 do F.idle(1); if choosingAction(0) then break end end
        encore.cancels[1] = { before = before, after = recordSize(0) + dropped(0) }
        F.L(string.format("  turn 2 cancel: Jolteon's record %d -> %d bytes", before, encore.cancels[1].after))
      else
        F.press("Up", 2); F.idle(4); F.press("Left", 2); F.idle(4); F.press("A", 2); F.idle(8)
      end
      return
    elseif choosingMove(b) then
      moveCursor((b == 2 and turn == 1) and 1 or 0)
      F.press("A", 2); F.idle(8)
      return
    elseif choosingTarget(b) then
      if b == 2 and turn == 1 then
        for _ = 1, 6 do
          if F.r8(S.gMultiUsePlayerCursor) == 0 then break end
          F.press("Left", 2); F.idle(8)
        end
      end
      F.press("A", 2); F.idle(8)
      return
    end
  end
  if f % 20 == 0 then F.press("A", 2) else F.idle(1) end
end

-- Overflow: hold both sides' HP and fill the player's record with moves, cancelled menus and
-- switches until it overflows, then let the player's Pokemon fall.
local stall = { turns = 0, phase = "fill", cancelledMove = false, cancelSwitch = false, switchNext = false,
  overflowTurn = nil, accounting = {}, attempts = 0 }
local function steerStall(f)
  local hp = S.BattlePokemon.hp
  local foeMax = F.r16(mon(1) + S.BattlePokemon.maxHP)
  if foeMax > 0 then F.w16(mon(1) + hp, foeMax) end
  local mx = F.r16(mon(0) + S.BattlePokemon.maxHP)
  if stall.phase == "fill" then
    if mx > 0 and F.r16(mon(0) + hp) > 0 then F.w16(mon(0) + hp, mx) end
  elseif F.r16(mon(0) + hp) > 1 then
    F.w16(mon(0) + hp, 1)
  end
  if choosingAction(0) then
    if stall.phase == "fill" and stall.turns % 6 == 5 and not stall.cancelSwitch and not stall.switchNext then
      -- POKEMON, then B out of the party menu.
      stall.cancelSwitch = true
      F.press("Up", 2); F.idle(4); F.press("Left", 2); F.idle(4); F.press("Down", 2); F.idle(4)
      F.press("A", 2); F.idle(20)
    elseif stall.phase == "fill" and stall.switchNext then
      stall.switchNext = false
      F.press("Up", 2); F.idle(4); F.press("Left", 2); F.idle(4); F.press("Down", 2); F.idle(4)
      F.press("A", 2); F.idle(20)
    else
      F.press("Up", 2); F.idle(4); F.press("Left", 2); F.idle(4); F.press("A", 2); F.idle(8)
    end
    return
  end
  if choosingMove(0) then
    if stall.phase == "fill" and not stall.cancelledMove then
      local before = recordSize(0) + dropped(0)
      F.press("B", 2)
      for _ = 1, 60 do F.idle(1); if choosingAction(0) then break end end
      local after = recordSize(0) + dropped(0)
      stall.accounting[#stall.accounting + 1] = { size = recordSize(0), before = before, after = after }
      stall.cancelledMove = true
      return
    end
    stall.attempts = stall.attempts + 1
    moveCursor((stall.turns + stall.attempts) % 4)
    F.press("A", 2); F.idle(8)
    return
  end
  if f % 20 == 0 then F.press("A", 2) else F.idle(1) end
end
local function stallTurnEnded()
  stall.turns = stall.turns + 1
  stall.cancelledMove, stall.attempts = false, 0
  if stall.turns % 11 == 10 then stall.switchNext = true end
  local full = recordSize(0) >= BATTLER_RECORD_SIZE
  if full and not stall.overflowTurn then stall.overflowTurn = stall.turns end
  if stall.overflowTurn and stall.turns >= stall.overflowTurn + 6 and stall.phase == "fill" then
    stall.phase = "lose"
    F.L(string.format("  overflow: record full on turn %d, dropped %d, letting the party fall on turn %d",
      stall.overflowTurn, dropped(0), stall.turns))
  end
  if stall.turns % 10 == 0 then
    F.L(string.format("  stall turn %d: record %d/%d bytes, dropped %d/%d", stall.turns, recordSize(0), recordSize(1), dropped(0), dropped(1)))
  end
end

local frameadvance = emu.frameadvance
local stalling = false
emu.frameadvance = function()
  if trace and cb(S.CB2_QuitRecordedBattle) then trace.quit = true end
  if (trace or stalling) and inBattle() then
    local ordering = (F.r32(S.gBattleMainFunc) & ~1) == S.SetActionsAndBattlersTurnOrder
    local t = trace or stall
    if ordering and not t.ordering then
      if stalling then
        stallTurnEnded()
      else
        local p, e = mon(0), mon(1)
        if palace then
          local flags = S.ProtectStruct
          local unable = F.r16(S.gProtectStructs) & flags.palaceUnableToUseMove
          local foeUnable = F.r16(S.gProtectStructs + flags.size) & flags.palaceUnableToUseMove
          trace.choices[#trace.choices + 1] = string.format("%d:%d/%d:%d", F.r16(S.gChosenMoveByBattler), unable,
            F.r16(S.gChosenMoveByBattler + 2), foeUnable)
        elseif factory or case.doubles then
          local moves = {}
          for b = 0, F.r8(S.gBattlersCount) - 1 do moves[#moves + 1] = F.r16(S.gChosenMoveByBattler + b * 2) end
          trace.choices[#trace.choices + 1] = table.concat(moves, "/")
        end
        local hps = {}
        for b = 0, F.r8(S.gBattlersCount) - 1 do
          hps[#hps + 1] = string.format("%d:%d", F.r16(mon(b)), F.r16(mon(b) + S.BattlePokemon.hp))
        end
        trace[#trace + 1] = table.concat(hps, "/")
        local sizes = {}
        for b = 0, F.r8(S.gBattlersCount) - 1 do sizes[#sizes + 1] = recordSize(b) end
        trace.sizes = trace.sizes or {}
        trace.sizes[#trace.sizes + 1] = table.concat(sizes, "/")
      end
    end
    t.ordering = ordering
    if trace then
      local outcome = F.r8(S.gBattleOutcome)
      if #trace > 0 and outcome ~= 0 then trace.outcome = outcome end
    end
  end
  return frameadvance()
end

local function softReset()
  for _ = 1, 10 do joypad.set({ A = true, B = true, Start = true, Select = true }); emu.frameadvance() end
  F.idle(30)
end

local function openBattleRecord()
  F.press("Start", 2); F.idle(60)
  if not F.selectStartIcon(USM_ICO_TRAINER) then return false end
  F.press("A", 2); F.idle(200)
  -- The pass cursor moves 2 px a frame; from where it opens this lands on Battle Record.
  for _ = 1, 60 do joypad.set({ Left = true }); emu.frameadvance() end
  for _ = 1, 25 do joypad.set({ Down = true }); emu.frameadvance() end
  for _ = 1, 6 do joypad.set({ Up = true }); emu.frameadvance() end
  F.idle(20)
  return cb(S.CB2_FrontierPass)
end

-- Plays the record from the pass's Battle Record cursor. quitAfter stops it with B once that many
-- turns have started; mash presses every button but B throughout.
local function playRecord(t, opts)
  opts = opts or {}
  local MASH = { "A", "Start", "Select", "L", "R", "Up", "Down", "Left", "Right" }
  local played, back, quitPressed = nil, false, false
  trace = t
  F.press("A", 2)
  for f = 1, 150000 do
    if F.reportCrash("playback_" .. f) then break end
    if not played and inBattle() then
      played = settleLeads()
      F.shot(opts.tag or "playback")
      F.L("  playback: " .. fmt(played))
    end
    if played and not inBattle() and f % 60 == 0 then
      F.idle(240)
      back = cb(S.CB2_FrontierPass)
      break
    end
    if opts.quitAfter and played and #t >= opts.quitAfter and inBattle() then
      quitPressed = true
      for _ = 1, 30 do joypad.set({ B = true }); emu.frameadvance() end
    elseif opts.mash and played and inBattle() and f % 9 == 0 then
      F.press(MASH[rand(#MASH) + 1], 2)
    else
      F.idle(1)
    end
  end
  trace = nil
  return played, back, quitPressed
end

local function partyBytes()
  local t = {}
  for i = 0, F.r8(S.gPartiesCount) * S.Pokemon.size - 1 do t[#t + 1] = F.r8(S.gParties + i) end
  return F.r8(S.gPartiesCount) .. ":" .. table.concat(t, ",")
end

-- At the lobby's record prompt: replays it from a savestate with soft resets after Yes and with
-- mashes. Every Continue must come back to a walkable lobby with the party the save holds.
local function resetSweep(lobby)
  local state = F.out .. "record_prompt.ss"
  client.savestate(state)
  local results = {}
  local offsets = { 0, 1, 2, 4, 8, 16, 40, 90 }
  for i = 1, #offsets + 2 do
    client.loadstate(state)
    F.idle(2)
    local label
    if i <= #offsets then
      label = "reset+" .. offsets[i]
      F.press("Up", 2); F.idle(6); F.press("A", 2)
      F.idle(offsets[i])
    else
      label = "mash" .. (i - #offsets)
      local KEYS = { "A", "B", "Up", "Down", "Start", "Select", "L", "R" }
      for _ = 1, 40 do F.press(KEYS[rand(#KEYS) + 1], 2); F.idle(rand(6)) end
    end
    softReset()
    local booted = F.boot(FRONTIER)
    local here = F.grp() == FRONTIER and F.mapn() == lobby
    local walk = booted and F.ensureFree()
    local crash = F.crashScreen()
    results[#results + 1] = string.format("%s:%s%s%s", label, booted and "boot" or "NOBOOT", here and ",lobby" or ",away",
      walk and ",walk" or ",STUCK")
    F.check("after " .. label .. " Continue returns to a walkable lobby", booted and here and walk and not crash,
      results[#results] .. (crash and (" crash " .. crash) or ""))
  end
  F.L("  reset sweep: " .. table.concat(results, " "))
  client.loadstate(state)
  F.idle(2)
end

-- Continues a save whose Palace record was made before Frontier turn seeding and plays it.
local function playLegacyRecord()
  assert(F.boot(FRONTIER), "the legacy save did not continue at the Frontier")
  local t = { choices = {}, isPlayback = true }
  F.check("the Start menu opens the Frontier Pass on Battle Record", openBattleRecord())
  local played, back = playRecord(t)
  local got, gotChoices = table.concat(t, ","), table.concat(t.choices, ",")
  F.L("  legacy playback: " .. got .. " choices " .. gotChoices)
  F.check("the legacy record plays", played ~= nil)
  F.check("legacy playback returns to the Frontier Pass", back, string.format("cb2=%08X", F.cb2()))
  local expect = os.getenv("PW_EXPECT_TRACE") or case.expect
  local expectChoices = os.getenv("PW_EXPECT_CHOICES") or case.expectChoices
  F.check("legacy playback matches the pre-seeding ROM's own playback", got == expect and gotChoices == expectChoices,
    got .. " choices " .. gotChoices .. " vs " .. expect .. " choices " .. expectChoices)
  F.check("no crash screen", not F.crashScreen())
  F.finish()
end

F.run(function()
  if case.legacy then return playLegacyRecord() end
  assert(F.boot(100), "Fresh game did not boot")
  for _, m in ipairs(case.party) do giveMon(m[1], m[2]) end
  F.check("the party is in place", F.r8(S.gPartiesCount) == #case.party, "n=" .. F.r8(S.gPartiesCount))
  setFlag(FLAG_SYS_FRONTIER_PASS)
  setFlag(FLAG_SYS_POKEMON_GET)
  setOptions()
  local lobby, bout = case.lobby, case.bout
  assert(F.warpTo(0, 2, 6, 0, lobby // 10, lobby % 10, 0, 0, 0, FRONTIER, lobby, "lobby"), "lobby warp failed")
  F.idle(60)
  F.check("walked to the facility attendant", F.route(case.attendant, "attendant"))
  F.face("Up"); F.press("A", 2); F.idle(30)
  F.check("took the Lv. 50 challenge",
    menu(0, "challenge") and menu(0, "lv50") and (case.rentals or pickSlots(case.pick)) and menu(0, "save"))

  local original, playback = { choices = {} }, { choices = {} }
  local battles, inB, last, ended = 0, false, nil, false
  local tradeSpecies
  local recordedFromRoom, lobbyPrompts, swept, rigged = false, 0, false, false
  for f = 1, 300000 do
    if F.reportCrash("challenge_" .. f) then break end
    if f % 20000 == 0 then
      F.L(string.format("  frame %d: cb2=%08X battles=%d map=%d/%d stall turns=%d record=%d/%d", f, F.cb2(), battles,
        F.grp(), F.mapn(), stall.turns, recordSize(0), recordSize(1)))
      F.shot("progress")
    end
    if case.foeBatonPass and not rigged and not inBattle() and (F.r32(S.gBattleTypeFlags) & BATTLE_TYPE_BATTLE_TOWER) ~= 0 then
      rigged = foeLeadBatonPassOnly()
      if rigged then F.L("  the opponent's lead now knows only Baton Pass") end
    end
    if factory and cb(S.CB2_SelectScreen) then
      rentals.rentThree(F)
    elseif factory and cb(S.Swap_CB2) then
      rentals.swapFirst(F)
    elseif facility == "dome" and cb(S.CB2_TourneyTree) then
      F.idle(90); F.press("B", 2); F.idle(60)
    elseif facility == "dome" and inPartyMenu() and not inB then
      pickSlots({ 0, 1 })
    elseif inBattle() then
      if not inB then
        inB, battles = true, battles + 1
        stalling = facility == "overflow" and battles == 2
        if battles == savedBout then trace = original; last = settleLeads(); F.L("  recorded battle: " .. fmt(last)) end
      end
      if factory and battles == 1 and not tradeSpecies then
        local foe = mon(1)
        if F.r16(foe + S.BattlePokemon.hp) > 0 then tradeSpecies = F.r16(foe) end
      end
      if stalling then
        steerStall(f)
      elseif case.doubles and battles == savedBout then
        steerEncore(f)
      else
        steerBattle(f, battles == savedBout)
      end
    elseif inPartyMenu() then
      F.idle(60)
      if stall.cancelSwitch then
        stall.cancelSwitch = false
        local before = recordSize(0) + dropped(0)
        F.press("B", 2)
        for _ = 1, 200 do F.idle(1); if not inPartyMenu() then break end end
        for _ = 1, 120 do F.idle(1); if choosingAction(0) then break end end
        stall.accounting[#stall.accounting + 1] = { size = recordSize(0), before = before, after = recordSize(0) + dropped(0) }
      else
        -- The menu lists the battle order, so try each bench slot until one is sent out.
        local first = case.doubles and 2 or 1
        for slot = first, F.r8(S.gPartiesCount) - 1 do
          for _ = 1, 6 do
            if partySlot() == slot then break end
            F.press(partySlot() > slot and "Up" or "Down", 2); F.idle(12)
          end
          F.press("A", 2); F.idle(40); F.press("A", 2); F.idle(60)
          if not inPartyMenu() then break end
          F.press("B", 2); F.idle(30); F.press("B", 2); F.idle(30)
        end
      end
    else
      if inB and F.ow() then
        inB = false
        if trace == original then trace = nil end
        stalling = false
      end
      if liveMenu() then
        F.idle(20)
        local lastOption = F.r8(S.sMenu + S.Menu.maxCursorPos)
        local inLobby = F.grp() == FRONTIER and F.mapn() == lobby
        if facility == "dome" and lastOption >= 4 and battles < bout then
          -- Opponent, Tourney tree, Ready, [Record,] Rest, Retire.
          choose(2)
        elseif facility == "overflow" and battles == 1 and lastOption >= 2 then
          -- Battle room after the first battle: Record it once, then go on.
          choose(recordedFromRoom and 0 or 1)
          recordedFromRoom = true
        elseif facility == "overflow" and battles == 2 and inLobby then
          lobbyPrompts = lobbyPrompts + 1
          F.shot("overflow_record_prompt")
          choose(0)
        elseif case.resetSweep and inLobby and battles == bout and not swept then
          swept = true
          resetSweep(lobby)
          choose(0)
        else
          -- After the tested bout, retire to the lobby and save its record there.
          choose(case.retire and battles == bout and lastOption >= 2 and lastOption or 0)
        end
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
  local expectedLead = case.party[case.pick and case.pick[1] + 1 or 1][1]
  if factory then expectedLead = tradeSpecies end
  F.check("the recorded battle led with the first pick", last ~= nil and last.player.species == expectedLead,
    last and fmt(last) or "none")
  if case.doubles then
    local c = encore.cancels[1]
    F.check("cancelling Clefable's action removed all three of Jolteon's recorded bytes",
      c ~= nil and c.before - c.after == 3, c and string.format("%d -> %d", c.before, c.after) or "no cancel on turn 2")
  end
  if facility == "overflow" then
    F.check("the stalled battle filled the player's record", stall.overflowTurn ~= nil,
      string.format("turns=%d record=%d dropped=%d", stall.turns, recordSize(0), dropped(0)))
    local bad = {}
    for _, a in ipairs(stall.accounting) do
      if a.before - a.after ~= 1 then bad[#bad + 1] = string.format("%d:%d->%d", a.size, a.before, a.after) end
    end
    F.check("every cancelled menu removed exactly its one action byte", #stall.accounting > 0 and #bad == 0,
      string.format("%d cancels, bad: %s", #stall.accounting, table.concat(bad, " ")))
    F.check("the lobby did not offer to record the overflowing battle", lobbyPrompts == 0, "prompts=" .. lobbyPrompts)
  end
  if not last then F.finish(); return end

  local partyBefore, countBefore = partyBytes(), F.r8(S.gPartiesCount)
  F.check("the Start menu opens the Frontier Pass on Battle Record", openBattleRecord())
  F.shot("pass_battle_record")
  local played, back = playRecord(playback, { mash = case.mash })
  F.shot("after_playback")
  F.check("the record plays", played ~= nil)
  F.check("playback leads with the Pokemon that fought", played ~= nil and played.player.species == last.player.species
    and played.player.maxHP == last.player.maxHP, played and fmt(played) or "no playback")
  F.check("playback's opponent is the one that fought", played ~= nil and played.foe.species == last.foe.species
    and played.foe.maxHP == last.foe.maxHP and last.foe.species ~= 0, played and fmt(played) or "no playback")
  F.check("playback returns to the Frontier Pass", back, string.format("cb2=%08X", F.cb2()))
  F.L("  record bytes at each turn: " .. table.concat(original.sizes or {}, ",") .. " vs read " .. table.concat(playback.sizes or {}, ","))
  F.check("the same Pokemon and HP start every recorded turn",
    #original > 0 and table.concat(original, ",") == table.concat(playback, ","),
    table.concat(original, ",") .. " vs " .. table.concat(playback, ","))
  if case.choices or case.doubles then
    F.check("both trainers' chosen moves replay on every turn",
      #original.choices > 0 and table.concat(original.choices, ",") == table.concat(playback.choices, ","),
      table.concat(original.choices, ",") .. " vs " .. table.concat(playback.choices, ","))
  end
  F.check("the replay ends with the original battle outcome",
    not playback.quit and (original.outcome == 1 or original.outcome == 2 or original.outcome == 3) and original.outcome == playback.outcome,
    tostring(original.outcome) .. " vs " .. tostring(playback.outcome) .. (playback.quit and " (quit)" or ""))
  F.L(string.format("  party count %d before playback, %d in the pass after it", countBefore, F.r8(S.gPartiesCount)))

  if case.mash then
    local quitTrace = { choices = {} }
    F.idle(60)
    local qPlayed, qBack, quitPressed = playRecord(quitTrace, { quitAfter = 2, tag = "quit_playback" })
    F.check("B quits the second viewing mid-battle back to the Frontier Pass",
      qPlayed ~= nil and quitPressed and qBack and quitTrace.quit, string.format("pressed=%s back=%s quit=%s turns=%d",
      tostring(quitPressed), tostring(qBack), tostring(quitTrace.quit), #quitTrace))
  end
  for _ = 1, 10 do
    if not cb(S.CB2_FrontierPass) then break end
    F.press("B", 2); F.idle(60)
  end
  -- The pass returns to the field with the Start menu open; building it recounts the party.
  F.idle(120); F.press("B", 2); F.idle(60)
  F.shot("field_after_pass")
  F.check("leaving the pass returns to a walkable field", F.ow() and F.ensureFree(), string.format("cb2=%08X", F.cb2()))
  F.check("the player's party is the one from before playback", partyBytes() == partyBefore,
    string.format("party count %d before, %d after", countBefore, F.r8(S.gPartiesCount)))
  F.check("no crash screen", not F.crashScreen())
  F.finish()
end)
