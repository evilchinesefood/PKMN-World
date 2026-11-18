-- Shared driver for FrontierFacilityStress.lua and FactoryRentalStress.lua: full Battle Frontier
-- challenges with real input, a Rest with Continue in the middle, and a soft reset with no save.
-- See FrontierFacilityStress.lua for what each case asserts.

return function(suiteName, CASES)
local S = require("symbols")
local F = require("lib").new(S, suiteName)

local rentals = require("frontier_rentals")
local FRONTIER = 26
local STATUS = S.SaveBlock2.frontierChallengeStatus
local CHALLENGE_STATUS_PAUSED = 2
local BP = S.SaveBlock2.bp
local FOLLOWER = 0xFE

-- Lobby map, warp digits for the map number, walk to the singles attendant, the Lv. 50 singles
-- win streak in SaveBlock2.frontier, the battles in a challenge, the streak one challenge leaves (the
-- Dome counts tourneys) and the first Battle Point award
-- (sBattlePointAwards tier 1).
local FACILITIES = {
  arena   = { map = 28, digits = { 0, 2, 8 }, walk = { { 7, 11 }, { 7, 8 } }, pick = 3, streak = 0xDDA, battles = 7, streakAfter = 7, bp = 1 },
  palace  = { map = 22, digits = { 0, 2, 2 }, walk = { { 12, 10 }, { 5, 10 }, { 5, 7 } }, pick = 3, streak = 0xDC8, battles = 7, streakAfter = 7, bp = 4 },
  factory = { map = 31, digits = { 0, 3, 1 }, walk = { { 9, 9 }, { 4, 9 }, { 4, 8 } }, pick = 0, streak = 0xDE2, battles = 7, streakAfter = 7, bp = 3 },
  dome    = { map = 18, digits = { 0, 1, 8 }, walk = { { 11, 12 }, { 5, 12 }, { 5, 11 } }, pick = 3, streak = 0xD0C, battles = 4, streakAfter = 1, bp = 1 },
}


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

local function partyBytes()
  local t = {}
  for i = 0, F.r8(S.gPartiesCount) * S.Pokemon.size - 1 do t[#t + 1] = F.r8(S.gParties + i) end
  return F.r8(S.gPartiesCount) .. ":" .. table.concat(t, ",")
end
local function personalities()
  local t = {}
  for i = 0, F.r8(S.gPartiesCount) - 1 do t[#t + 1] = string.format("%08X", F.r32(S.gParties + i * S.Pokemon.size)) end
  return table.concat(t, " ")
end
local function where() local x, y = F.pos(); return string.format("%d/%d (%d,%d)", F.grp(), F.mapn(), x, y) end

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
  F.L("  " .. tag .. ": no menu went live"); F.shot(tag .. "_nomenu")
  return false
end

local function cb(addr) return F.cb2() == (addr & ~1) end
local function inPartyMenu() return cb(S.CB2_UpdatePartyMenu) or cb(S.CB2_InitPartyMenu) end
local function inBattle() return cb(S.BattleMainCB2) end
local function atTitle() return cb(S.MainCB2_WorldTitleScreen) or cb(S.MainCB2_Intro) end
local function scriptIdle() return F.r8(S.sGlobalScriptContextStatus) == 2 end

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

local function steerBattle(f)
  for b = 1, 3, 2 do
    local a = S.gBattleMons + b * S.BattlePokemon.size
    if F.r16(a + S.BattlePokemon.hp) > 1 then F.w16(a + S.BattlePokemon.hp, 1) end
  end
  local a = S.gBattleMons
  local mx = F.r16(a + S.BattlePokemon.maxHP)
  if F.r16(a + S.BattlePokemon.hp) > 0 and mx > 0 then F.w16(a + S.BattlePokemon.hp, mx) end
  if f % 20 ~= 0 then F.idle(1); return end
  if cb(S.BattleMainCB2) and (F.r32(S.gBattlerControllerFuncs) & ~1) == (S.HandleInputChooseMove & ~1) then
    -- Walk the cursor over all four moves so an immunity or an evasion loop cannot stall the bot.
    local slot = (f // 20) % 4
    F.press("Up", 2); F.idle(4); F.press("Left", 2); F.idle(4)
    if slot % 2 == 1 then F.press("Right", 2); F.idle(4) end
    if slot >= 2 then F.press("Down", 2); F.idle(4) end
  end
  F.press("A", 2)
end

local function softReset(tag)
  F.shot("reset_" .. tag)
  for _ = 1, 10 do joypad.set({ A = true, B = true, Start = true, Select = true }); emu.frameadvance() end
  F.idle(30)
end

local function follower()
  for i = 0, 15 do
    local a = S.gObjectEvents + i * S.ObjectEvent.stride
    if (F.r8(a) & 1) ~= 0 and F.r8(a + S.ObjectEvent.localId) == FOLLOWER then
      return { gfx = F.r16(a + S.ObjectEvent.graphicsId), visible = (F.r8(a + 1) & 0x20) == 0 }
    end
  end
end

local function runCase(c, base)
  local fac = FACILITIES[c.fac]
  local tag = c.name
  client.loadstate(base); F.idle(10)
  assert(F.warpTo(0, 2, 6, fac.digits[1], fac.digits[2], fac.digits[3], 0, 0, 0, FRONTIER, fac.map, tag), "lobby warp failed")
  F.idle(60)
  local party0 = partyBytes()
  local follower0 = follower()
  local bp0 = F.r16(F.sb2() + BP)
  if not F.check(tag .. ": walked to the attendant", F.route(fac.walk, tag), where()) then return end
  F.face("Up"); F.press("A", 2); F.idle(30)
  local took = menu(0, tag .. "_challenge") and menu(0, tag .. "_lv50")
  if took and fac.pick > 0 then took = pickMons(fac.pick) end
  took = took and menu(0, tag .. "_save")
  if not F.check(tag .. ": took the Lv. 50 singles challenge", took) then return end

  local battles, inB, rented, swapped, resumed, ended, resetDone = 0, false, nil, nil, false, false, false
  local domeMenus = 0
  for f = 1, 150000 do
    if F.reportCrash(tag .. "_" .. f) then break end
    if cb(S.CB2_SelectScreen) then
      rentals.rentThree(F)
      rented = personalities()
    elseif cb(S.Swap_CB2) then
      if c.mode == "reset" then softReset("swap"); resetDone = true
      elseif not swapped then
        local function slot0()
          local t = {}
          for i = 0, S.Pokemon.size - 1 do t[#t + 1] = F.r8(S.gParties + i) end
          return table.concat(t, ",")
        end
        swapped = { before = slot0() }
        rentals.swapFirst(F)
      else
        F.idle(120); F.press("B", 2); F.idle(60); F.press("A", 2); F.idle(120)
      end
    elseif cb(S.CB2_TourneyTree) then
      if c.mode == "reset" and battles >= 1 then F.idle(120); softReset("tree"); resetDone = true
      else F.idle(90); F.shot(tag .. "_tree"); F.press("B", 2); F.idle(60) end
    elseif inPartyMenu() and not inB then
      pickMons(2)
    elseif inPartyMenu() then
      F.idle(60); F.press("Down", 2); F.idle(30); F.press("A", 2); F.idle(40); F.press("A", 2); F.idle(60)
    elseif inBattle() then
      if not inB then
        inB, battles = true, battles + 1
        -- factory_swapmons runs after the swap screen closes, so look at the party in the next battle.
        if swapped and not swapped.after then
          local t = {}
          for i = 0, S.Pokemon.size - 1 do t[#t + 1] = F.r8(S.gParties + i) end
          swapped.after = table.concat(t, ",")
        end
      end
      steerBattle(f)
    elseif atTitle() then
      F.shot(tag .. "_title")
      local booted = F.boot(nil, true)
      local status = F.r8(F.sb2() + STATUS)
      F.L(string.format("  %s: continued at %s status=%d party=%d", tag, where(), status, F.r8(S.gPartiesCount)))
      if c.mode == "rest" then
        resumed = true
        F.check(tag .. ": Continue lands in the lobby with the challenge paused", booted and F.grp() == FRONTIER
          and F.mapn() == fac.map and status == CHALLENGE_STATUS_PAUSED, string.format("%s status=%d", where(), status))
      else
        F.check(tag .. ": Continue lands in the lobby", booted and F.grp() == FRONTIER and F.mapn() == fac.map, where())
      end
    else
      if inB and F.ow() then inB = false end
      local k = liveMenu()
      if k then
        F.idle(20)
        local mx = F.r8(S.sMenu + S.Menu.maxCursorPos)
        local want = 0
        if k == "multi" and mx >= 4 and c.fac == "dome" then
          -- Dome: Opponent, Tourney tree, Ready, [Record], Rest, Retire. Look at the tree once.
          domeMenus = domeMenus + 1
          want = (domeMenus == 1 or (c.mode == "reset" and battles >= 1)) and 1 or 2
          if c.mode == "rest" and battles == 1 and not resumed then want = mx - 1 end
        elseif k == "multi" and mx >= 2 and c.mode == "rest" and battles == 1 and not resumed then
          want = mx - 1
        end
        choose(want)
      elseif f % 30 == 0 then
        F.press("A", 2)
      else
        F.idle(1)
      end
      local over = battles >= fac.battles or resetDone
      if over and F.grp() == FRONTIER and F.mapn() == fac.map and F.ow() and scriptIdle() and not liveMenu() then
        F.idle(240)
        if scriptIdle() and not liveMenu() then ended = true; break end
      end
    end
  end
  F.shot(tag .. "_end")

  local streak = F.r16(F.sb2() + fac.streak)
  local status = F.r8(F.sb2() + STATUS)
  local bp = F.r16(F.sb2() + BP)
  F.check(tag .. ": back in the lobby with control", ended and F.grp() == FRONTIER and F.mapn() == fac.map, where())
  F.check(tag .. ": the party is byte-identical to the one that entered", partyBytes() == party0,
    "now " .. personalities())
  F.check(tag .. ": frontier status cleared", status == 0, "status=" .. status)
  if c.fac == "factory" then
    F.check(tag .. ": three rentals replaced the party", rented ~= nil and not rented:find(string.format("%08X", F.r32(S.gParties)), 1, true),
      tostring(rented))
  end
  if c.mode == "rest" then
    F.check(tag .. ": Rest went through the title and Continue", resumed)
    F.check(tag .. ": every battle was won", battles == fac.battles, "battles=" .. battles)
    F.check(tag .. ": the win streak counts the challenge", streak == fac.streakAfter, "streak=" .. streak)
    F.check(tag .. ": first Battle Point award added", bp - bp0 == fac.bp, string.format("%d -> %d", bp0, bp))
    if c.fac == "factory" then
      -- Rentals' personalities repeat (they follow the nature), so compare the whole slot.
      F.check(tag .. ": the swap traded the first rental", swapped ~= nil and swapped.before ~= swapped.after,
        swapped and "slot 0 unchanged at the next battle" or "no swap screen")
    end
  else
    F.check(tag .. ": soft reset hit its screen", resetDone)
    F.check(tag .. ": the unsaved run ended the streak", streak == 0, "streak=" .. streak)
    F.check(tag .. ": no Battle Points for the unsaved run", bp == bp0, string.format("%d -> %d", bp0, bp))
  end
  F.step("Down"); F.idle(20); F.step("Down"); F.idle(60)
  local fol = follower()
  F.check(tag .. ": the follower walks behind the player again", fol ~= nil and fol.visible and follower0 ~= nil
    and fol.gfx == follower0.gfx, fol and string.format("gfx=%04X visible=%s", fol.gfx, tostring(fol.visible)) or "none")
end

F.run(function()
  assert(F.boot(100), "Fresh game did not boot")
  giveMon(6, { 53, 89, 0, 0 }); giveMon(9, { 57, 58, 0, 0 }); giveMon(3, { 202, 89, 0, 0 }); giveMon(25, { 85, 0, 0, 0 })
  F.check("four Pokemon in the party", F.r8(S.gPartiesCount) == 4, "n=" .. F.r8(S.gPartiesCount))
  local base = F.out .. suiteName .. "_base.ss"
  client.savestate(base)
  local only = os.getenv("PW_CASE")
  for _, c in ipairs(CASES) do
    if not only or c.name:find(only, 1, true) then runCase(c, base) end
  end
  F.check("no crash screen", not F.crashScreen())
  F.finish()
end)
end
