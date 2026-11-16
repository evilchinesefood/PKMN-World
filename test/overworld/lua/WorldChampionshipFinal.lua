-- The World Championship must end with RED in the final.
--
-- InitDomeTrainers swaps RED into the bracket slot opposite the player so the two can only meet in
-- the final, but the NPC matches on the way there were scored like any other pair of trainers, so
-- RED could lose in round 1, 2 or the semifinal and the player then won the championship without
-- ever facing him. A three-region champion takes the championship from the registrar with real
-- input three times (each run starts a different number of frames after the same savestate, so the
-- NPC match rolls differ), wins each Dome battle, and at every battle start reads the bracket:
-- RED must still be in it, and the fourth battle must be against RED alone. The championship win
-- must then set the title and clear the championship mode.
--
-- Run via: test/overworld/mgba-run.sh test/overworld/lua/WorldChampionshipFinal.lua <rom.gba>

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "WorldChampionshipFinal")

local LOBBY_G, LOBBY_M = 26, 18
local CHAMPION_FLAGS = { 0xA48, 0xA49, 0xA4A }
local FLAG_WORLD_CHAMPION = 0xD73
local VAR_WC_MODE = 0x40F7
local REGISTRAR = 5
local RED = 300
local DOME_TRAINERS, DOME_TRAINER_STRIDE = 0xD24, 4
local RUNS = 3

local function setFlag(id)
  local a = F.sb1() + S.SaveBlock1.flags + id // 8
  F.w8(a, F.r8(a) | (1 << (id % 8)))
end
local function flag(id) return (F.r8(F.sb1() + S.SaveBlock1.flags + id // 8) >> (id % 8)) & 1 == 1 end
local function var(id) return F.r16(F.sb1() + S.SaveBlock1.vars + (id - 0x4000) * 2) end

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

local function bracket()
  local list = {}
  for i = 0, 15 do
    local v = F.r16(F.sb2() + DOME_TRAINERS + i * DOME_TRAINER_STRIDE)
    list[#list + 1] = { id = v & 0x3FF, out = ((v >> 10) & 1) == 1, round = (v >> 11) & 3 }
  end
  return list
end
local function fmtBracket(list)
  local t = {}
  for _, e in ipairs(list) do t[#t + 1] = e.id .. (e.out and ("x" .. e.round) or "") end
  return table.concat(t, " ")
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
local function untilMenu(tag)
  for _ = 1, 80 do
    if F.reportCrash("menu_" .. tag) then return nil end
    local kind = liveMenu()
    if kind then F.idle(12); return kind end
    F.press("A", 2); F.idle(30)
  end
  F.L("  " .. tag .. ": no menu went live"); F.shot(tag .. "_nomenu")
end
local function choose(want, tag)
  for _ = 1, 8 do
    local c = F.mcur()
    if c == want then F.press("A", 2); F.idle(45); return true end
    F.press(c > want and "Up" or "Down", 2); F.idle(12)
  end
  F.L("  " .. tag .. ": cursor never reached " .. want)
  return false
end
local function menu(want, tag) return untilMenu(tag) ~= nil and choose(want, tag) end

local function inPartyMenu() return F.cb2() == (S.CB2_UpdatePartyMenu & ~1) or F.cb2() == (S.CB2_InitPartyMenu & ~1) end
local function inBattle() return F.cb2() == (S.BattleMainCB2 & ~1) end

local function pickMons(n)
  for _ = 1, 300 do
    if inPartyMenu() then break end
    F.press("A", 2); F.idle(20)
  end
  if not inPartyMenu() then return false end
  F.idle(60)
  for i = 1, n do
    F.press("A", 2); F.idle(30)
    F.press("A", 2); F.idle(40)
    if i < n then F.press("Down", 2); F.idle(20) end
  end
  F.press("Start", 2); F.idle(40)
  for _ = 1, 8 do
    if not inPartyMenu() then break end
    F.press("A", 2); F.idle(60)
  end
  return not inPartyMenu()
end

-- Opponents go down to 1 HP so any hit ends them, and the player's side is kept topped up: winning
-- every battle is setup here, the NPC matches between the player's battles are what is under test.
local function steerBattle(f)
  for b = 1, 3, 2 do
    local a = S.gBattleMons + b * S.BattlePokemon.size
    if F.r16(a + S.BattlePokemon.hp) > 1 then F.w16(a + S.BattlePokemon.hp, 1) end
  end
  local a = S.gBattleMons
  local mx = F.r16(a + S.BattlePokemon.maxHP)
  if F.r16(a + S.BattlePokemon.hp) > 0 and mx > 0 then F.w16(a + S.BattlePokemon.hp, mx) end
  if f % 20 ~= 0 then F.idle(1); return end
  if (F.r32(S.gBattlerControllerFuncs) & ~1) == (S.HandleInputChooseMove & ~1) then
    F.press("Left", 2); F.idle(4)
    if (f // 20) % 2 == 1 then F.press("Right", 2); F.idle(4) end
  end
  F.press("A", 2)
end

local function talkToRegistrar()
  for _ = 1, 30 do
    local rx, ry
    for i = 0, 15 do
      local a = S.gObjectEvents + i * S.ObjectEvent.stride
      if (F.r8(a) & 1) ~= 0 and F.r8(a + S.ObjectEvent.localId) == REGISTRAR then
        rx, ry = F.rs16(a + S.ObjectEvent.x) - 7, F.rs16(a + S.ObjectEvent.y) - 7
      end
    end
    if rx and F.route({ { 11, 16 }, { rx, 16 }, { rx, ry + 1 } }, "registrar") then
      F.w16(S.gSpecialVar_LastTalked, 0)
      F.face("Up"); F.press("A", 2); F.idle(30)
      if F.r16(S.gSpecialVar_LastTalked) == REGISTRAR and F.r8(S.sGlobalScriptContextStatus) ~= 2 then return true end
      for _ = 1, 6 do F.press("B", 2); F.idle(30) end
    end
    F.idle(40)
  end
  return false
end

-- One championship from the registrar to the lobby. Returns the bracket seen at each battle start.
local function championship(run)
  local tag = "run" .. run
  if not F.check(tag .. ": talked to the registrar", talkToRegistrar(), string.format("(%d,%d)", F.pos())) then return end
  if not F.check(tag .. ": took the championship", menu(0, tag .. "_offer") and menu(0, tag .. "_challenge")
      and menu(0, tag .. "_lv50") and pickMons(3) and menu(0, tag .. "_save")) then return end
  F.check(tag .. ": championship mode on", var(VAR_WC_MODE) == 1, "mode=" .. var(VAR_WC_MODE))

  local seen, inB, battles, finalShotAt = {}, false, 0, -1
  for f = 1, 60000 do
    if F.reportCrash(tag .. "_" .. f) then return seen end
    if inPartyMenu() and not inB then
      pickMons(2)
    elseif inPartyMenu() then
      -- A fainted battler: send in the next one.
      F.idle(60); F.press("Down", 2); F.idle(30); F.press("A", 2); F.idle(40); F.press("A", 2); F.idle(60)
    elseif inBattle() then
      if not inB then
        inB, battles = true, battles + 1
        F.idle(30)
        seen[battles] = bracket()
        F.L(string.format("  %s battle %d: %s", tag, battles, fmtBracket(seen[battles])))
        if battles == 4 then finalShotAt = f + 300 end
      end
      if f == finalShotAt then F.shot(tag .. "_final") end
      steerBattle(f)
    else
      if inB and F.ow() then inB = false end
      local k = liveMenu()
      if k then
        F.idle(20)
        local want = 0
        -- The Dome's between-rounds menu: row 2 is "Ready to Start".
        if k == "multi" and F.r8(S.sMenu + S.Menu.maxCursorPos) >= 4 then want = 2 end
        choose(want, tag .. "_menu" .. f)
      elseif f % 30 == 0 then
        F.press("A", 2)
      else
        F.idle(1)
      end
      if F.grp() == LOBBY_G and F.mapn() == LOBBY_M and battles >= 1 and F.ow()
          and F.r8(S.sGlobalScriptContextStatus) == 2 and not liveMenu() then
        F.idle(120)
        if F.r8(S.sGlobalScriptContextStatus) == 2 then break end
      end
    end
  end
  F.shot(tag .. "_lobby")
  F.check(tag .. ": four Dome battles", battles == 4, "battles=" .. battles)
  return seen
end

F.run(function()
  assert(F.boot(100), "Fresh game did not boot")
  giveMon(6, { 53, 89 }); giveMon(9, { 57, 58 }); giveMon(3, { 202, 89 })
  F.check("three Pokemon in the party", F.r8(S.gPartiesCount) == 3, "n=" .. F.r8(S.gPartiesCount))
  assert(F.warpTo(0, 2, 6, 0, 1, 8, 0, 0, 0, LOBBY_G, LOBBY_M, "dome"), "Dome warp failed")
  F.idle(60)
  for _, id in ipairs(CHAMPION_FLAGS) do setFlag(id) end
  local base = F.out .. "WorldChampionshipFinal_base.ss"
  client.savestate(base)

  for run = 1, RUNS do
    client.loadstate(base); F.idle(10 + run * 37)
    local seen = championship(run)
    if not seen then break end
    local redAlive, lost = true, ""
    for b = 1, 4 do
      for _, e in ipairs(seen[b] or {}) do
        if e.id == RED and e.out and redAlive then
          redAlive, lost = false, string.format("RED out in round %d, seen at battle %d", e.round + 1, b)
        end
      end
    end
    F.check(string.format("run%d: RED is never knocked out before the final", run), redAlive, lost)
    local final, rivals, redIn = seen[4], 0, false
    for _, e in ipairs(final or {}) do
      if not e.out and e.id == RED then redIn = true end
      if not e.out and e.id > RED and e.id <= RED + 15 then rivals = rivals + 1 end
    end
    F.check(string.format("run%d: the final is against RED alone", run), final ~= nil and redIn and rivals == 0,
      final and fmtBracket(final) or "no fourth battle")
    F.check(string.format("run%d: the championship title is set", run), flag(FLAG_WORLD_CHAMPION))
    F.check(string.format("run%d: championship mode is cleared", run), var(VAR_WC_MODE) == 0, "mode=" .. var(VAR_WC_MODE))
  end
  F.check("no crash screen", not F.crashScreen())
  F.finish()
end)
