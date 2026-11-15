-- Shared helpers for the review captures. Load with:
--   local F, S, X = dofile(os.getenv("REC_TOOLS") .. "/Show.lua")("Name")
-- Patterns are copied from the repo suites named beside each helper.
package.path = os.getenv("REC_TOOLS") .. "/../lua/?.lua;" .. package.path

return function(name)
  local S = require("symbols")
  local F = require("lib").new(S, name)
  local X = {}
  local MON = S.Pokemon.size
  X.MON = MON

  X.SPECIES = {
    classic = 1573, surfboard = 1574, balloons = 1575, squad = 1576,
    firefighter = 1577, flower = 1578, pirate = 1580,
  }

  function X.rec(on) REC.on = on end
  function X.mark(label) REC.mark(label) end
  function X.hold(n) F.idle(n) end
  function X.tap(key, wait) F.press(key, 2); F.idle(wait or 20) end
  function X.taps(key, n, wait) for _ = 1, n do X.tap(key, wait) end end

  function X.flag(id, value)
    local address, bit = F.sb1() + S.SaveBlock1.flags + id // 8, 1 << (id % 8)
    if value ~= nil then
      local old = F.r8(address)
      F.w8(address, value and (old | bit) or (old & ~bit & 0xFF))
    end
    return (F.r8(address) & bit) ~= 0
  end

  function X.instantText()
    local opt = F.sb2() + S.SaveBlock2.optionsU16
    F.w16(opt, (F.r16(opt) & ~7) | 3)
  end
  function X.normalText()   -- fast but readable (StoryOverviewLine leaves options alone)
    local opt = F.sb2() + S.SaveBlock2.optionsU16
    F.w16(opt, (F.r16(opt) & ~7) | 2)
  end

  -- Script-context warp (StoryOverviewLine.lua).
  function X.warp(g, n, x, y)
    local buf = S.gStringVar4 + 960
    local b = { 0x39, g, n, 0xFF, x & 0xFF, x >> 8, y & 0xFF, y >> 8, 0x27, 0x02 }
    for i, v in ipairs(b) do F.w8(buf + i - 1, v) end
    F.w8(S.sGlobalScriptContext, 0)
    F.w8(S.sGlobalScriptContext + 1, 1)
    F.w32(S.sGlobalScriptContext + 4, 0)
    F.w32(S.sGlobalScriptContext + S.ScriptCtx.scriptPtr, buf)
    F.w8(S.sGlobalScriptContextStatus, 0)
    for _ = 1, 400 do
      F.idle(4)
      if F.grp() == g and F.mapn() == n and F.ow() then F.dismiss(20); return true end
    end
    return false
  end
  -- Debug-menu warp by group/map/warp id (SpecialPokemonCatchRecovery.lua).
  function X.warpId(g, m, w, tag)
    return F.warpTo(g // 100, (g // 10) % 10, g % 10, m // 100, (m // 10) % 10, m % 10, 0, 0, w, g, m, tag)
  end

  -- Party decoding (SpecialPokemonCatchRecovery.lua).
  function X.count() return F.r8(S.gPartiesCount) end
  function X.decode(i)
    local a = S.gParties + i * MON
    local pers, otid = F.r32(a), F.r32(a + 4)
    local key = pers ~ otid
    local w = {}
    for k = 0, 11 do w[k] = F.r32(a + 32 + k * 4) ~ key end
    local s0 = F.r8(S.sSubstructOffsets + pers % 24) * 3
    local s1 = F.r8(S.sSubstructOffsets + 24 + pers % 24) * 3
    return {
      species = w[s0] & 0x7FF, level = F.r8(a + S.Pokemon.level),
      moves = { w[s1] & 0x7FF, (w[s1] >> 16) & 0x7FF, w[s1 + 1] & 0x7FF, (w[s1 + 1] >> 16) & 0x7FF },
    }
  end
  function X.party()
    local t = {}
    for i = 0, X.count() - 1 do local m = X.decode(i); t[#t + 1] = m.species .. "@" .. m.level end
    return table.concat(t, ",")
  end

  -- Rewrite one party Pokemon's encrypted substructs: met level 1 so Gen 8 obedience lets it act
  -- with no badges, and optionally a new move list (SpecialPokemonCatchRecovery.giveLead).
  function X.patch(i, moves)
    local a = S.gParties + i * MON
    local pers, otid = F.r32(a), F.r32(a + 4)
    local key = pers ~ otid
    local w = {}
    for k = 0, 11 do w[k] = F.r32(a + 32 + k * 4) ~ key end
    local s1 = F.r8(S.sSubstructOffsets + 24 + pers % 24) * 3
    local s3 = F.r8(S.sSubstructOffsets + 72 + pers % 24) * 3
    if moves then
      w[s1] = (moves[1] or 0) | ((moves[2] or 0) << 16)
      w[s1 + 1] = (moves[3] or 0) | ((moves[4] or 0) << 16)
      w[s1 + 2] = 35 | (35 << 8) | (35 << 16) | (35 << 24)
    end
    w[s3] = (w[s3] & ~(0x7F << 16)) | (1 << 16)
    local sum = 0
    for k = 0, 11 do
      sum = sum + (w[k] & 0xFFFF) + ((w[k] >> 16) & 0xFFFF)
      F.w32(a + 32 + k * 4, (w[k] ~ key) & 0xFFFFFFFF)
    end
    F.w16(a + 28, sum & 0xFFFF)
  end

  -- Debug Give X > Pokemon (Basic): 4-digit species spinner, then the level spinner.
  local function spin4(n)
    n = n - 1
    local d = { n // 1000, (n // 100) % 10, (n // 10) % 10, n % 10 }
    for _ = 1, 3 do X.tap("Right", 8) end
    for _ = 1, 3 do X.tap("Down", 8) end
    for i = 1, 4 do
      for _ = 1, d[i] do X.tap("Up", 8) end
      if i < 4 then X.tap("Left", 8) end
    end
    X.tap("A", 45)
  end
  function X.give(species, lvT, lvO)
    local before = X.count()
    for _ = 1, 3 do
      F.dbg(); F.sel(3); F.sel(1); F.idle(20)
      spin4(species); F.idle(20)
      F.spin(0, lvT or 9, lvO or 9); F.idle(60); F.bOut(6)
      for _ = 1, 10 do if F.ensureFree() then break end F.press("B", 2); F.idle(20) end
      if X.count() == before + 1 then return X.decode(before) end
    end
    return nil
  end
  function X.clearParty()
    for o = 0, 6 * MON - 4, 4 do F.w32(S.gParties + o, 0) end
    F.w8(S.gPartiesCount, 0)
  end

  -- Talking and battles (SpecialPokemonCatchRecovery.lua).
  local function liveMenu()
    for i = 0, S.Task.count - 1 do
      local task = S.gTasks + i * S.Task.stride
      local fn = F.r32(task + S.Task.func) & 0xFFFFFFFE
      if F.r8(task + S.Task.isActive) ~= 0 and (fn == S.Task_HandleYesNoInput or fn == S.Task_HandleMultichoiceInput) then
        return true
      end
    end
    return false
  end
  X.liveMenu = liveMenu
  function X.scriptIdle() return F.ow() and F.r8(S.sGlobalScriptContextStatus) == 2 end
  function X.inBattle() return F.cb2() == (S.BattleMainCB2 & ~1) end
  -- Talk facing dir, reading each page for `read` frames; answer menus with `answer`.
  function X.talk(dir, answer, read)
    F.face(dir)
    F.press("A", 2); F.idle(read or 20)
    local menus = 0
    for n = 1, 300 do
      if X.inBattle() then return menus, true end
      if liveMenu() then
        menus = menus + 1
        F.idle(read or 20)
        F.press(answer and "A" or "B", 2); F.idle(40)
      elseif n > 2 and X.scriptIdle() then
        return menus, false
      else
        F.press("A", 2); F.idle(read or 16)
      end
    end
    for _ = 1, 300 do if X.inBattle() then return menus, true end F.idle(2) end
    return menus, false
  end
  function X.actionReady()
    local fn = F.r32(S.gBattlerControllerFuncs) & ~1
    for _, p in ipairs(S.ActionInputFunctions) do if fn == p then return true end end
    return false
  end
  function X.awaitAction(wait)
    for _ = 1, 600 do
      if X.actionReady() then F.idle(10); return true end
      if not X.inBattle() and F.ow() then return false end
      X.tap("B", wait or 10)
    end
    return false
  end
  function X.chooseAction(index)
    for _ = 1, 8 do
      local cursor = F.r8(S.gActionSelectionCursor)
      if cursor == index then break end
      if (cursor & 1) ~= (index & 1) then X.tap((index & 1) == 0 and "Left" or "Right", 14)
      else X.tap((index & 2) == 0 and "Up" or "Down", 14) end
    end
    X.tap("A")
  end
  function X.inMoveMenu() return (F.r32(S.gBattlerControllerFuncs) & ~1) == S.HandleInputChooseMove end
  function X.fight(slot, linger)
    X.chooseAction(0)
    for _ = 1, 120 do if X.inMoveMenu() then break end F.idle(2) end
    F.idle(linger or 20)
    for _ = 1, 4 do
      local c = F.r8(S.gMoveSelectionCursor)
      if c == slot then break end
      if (c & 1) ~= (slot & 1) then X.tap((slot & 1) == 0 and "Left" or "Right", 12) else X.tap((slot & 2) == 0 and "Up" or "Down", 12) end
    end
    F.idle(linger or 0)
    for _ = 1, 5 do
      X.tap("A", 30)
      if not X.inMoveMenu() then return end
    end
  end
  function X.finishBattle(wait)
    for _ = 1, 3000 do
      if F.reportCrash("battle") then return false end
      if not X.inBattle() and X.scriptIdle() then F.idle(30); return true end
      X.tap("B", wait or 10)
    end
    return false
  end

  -- Bag Poke Balls (SpecialPokemonCatchRecovery.setBalls).
  function X.setBalls(qty)
    local key = F.r32(F.sb2() + S.SaveBlock2.encryptionKey) & 0xFFFF
    local ptr, cap = F.r32(S.gBagPockets + 1 * S.BagPocket.stride), F.pocketCap(1)
    for s = 0, cap - 1 do F.w16(ptr + s * 4, 0); F.w16(ptr + s * 4 + 2, key) end
    if qty > 0 then F.w16(ptr, 1); F.w16(ptr + 2, qty ~ key) end
  end

  -- Party menu (FollowerPartyReorder.lua).
  function X.openParty()
    F.press("Start", 2); F.idle(60)
    if not F.selectStartIcon(1) then return false end
    F.press("A", 2); F.idle(90)
    return F.cb2() == (S.CB2_UpdatePartyMenu & ~1)
  end
  function X.closeParty()
    for _ = 1, 4 do F.press("B", 2); F.idle(60); if F.ow() then break end end
    for _ = 1, 20 do if F.ensureFree() then break end F.press("B", 2); F.idle(20) end
  end
  -- From an open party menu: pick slot and choose Follow (action list ends Follow, Nickname, Cancel).
  function X.follow(slot, linger)
    for _ = 1, slot do X.tap("Down", linger or 16) end
    X.tap("A", 40)
    for _ = 1, F.rs8(S.sMenu + S.Menu.maxCursorPos) - 2 do X.tap("Down", linger or 16) end
    F.idle(linger or 0)
    X.tap("A", 60); X.tap("A", 40)
  end

  return F, S, X
end
