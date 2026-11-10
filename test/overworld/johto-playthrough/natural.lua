-- Natural-difficulty play (PW_NATURAL=1): a team caught in the region, no debug team and no debug
-- heals, Pokemon Centers, whiteouts as a real loss, and a grass grind to the level a gym wants.
-- Installed by play.lua as N.natural; the hooks in nav.lua stay inert without it.
local P = require('pwsym')
local O = require('pwoff')
local C = require('pwconst')
local MAPS = require('pwmaps')

-- ace = the leader's highest level, from the plan's table; limit = the grind allowance in steps.
local REGIONS = require('natural_regions')

return function(F, N, S, here)
  local L = F.L
  local r8, r16, r32 = F.r8, F.r16, F.r32
  local press, idle = F.press, F.idle
  local CAMPAIGN = os.getenv('PW_CAMPAIGN') or 'johto'
  local CFG = assert(REGIONS[CAMPAIGN], 'no natural config for ' .. CAMPAIGN)
  local GYM = {}
  for _, g in ipairs(CFG.gyms) do GYM[g.beat] = g end

  local Nat = {}
  local stats = { gyms = {}, grindSteps = 0, catchSteps = 0, centerTrips = 0, potions = 0, whiteouts = 0,
                  warps = 0, learned = 0, skippedDebugHeals = 0, order = {}, battlesLost = 0 }
  Nat.stats = stats
  local healing, grinding = false, false
  local pendingLoss

  local function bmon(i) return P.gBattleMons + i * O.bm_size end

  ---------------------------------------------------------------- party data (encrypted substructs)
  local ORDER = { 'GAEM', 'GAME', 'GEAM', 'GEMA', 'GMAE', 'GMEA', 'AGEM', 'AGME', 'AEGM', 'AEMG', 'AMGE', 'AMEG',
    'EGAM', 'EGMA', 'EAGM', 'EAMG', 'EMGA', 'EMAG', 'MGAE', 'MGEA', 'MAGE', 'MAEG', 'MEGA', 'MEAG' }
  local function subWords(slot, letter)
    local b = P.gParties + slot * O.mon_size
    local pid, otid = r32(b), r32(b + 4)
    local key = pid ~ otid
    local base = b + 32 + 12 * (ORDER[(pid % 24) + 1]:find(letter) - 1)
    return r32(base) ~ key, r32(base + 4) ~ key, r32(base + 8) ~ key
  end
  local function partySpecies(slot) return (subWords(slot, 'G')) & 0x7FF end
  local function partyPP(slot) local _, _, w2 = subWords(slot, 'A'); return { w2 & 0xFF, (w2 >> 8) & 0xFF, (w2 >> 16) & 0xFF, (w2 >> 24) & 0xFF } end
  local function partyMoves(slot)
    local w0, w1 = subWords(slot, 'A')
    return { w0 & 0xFFFF, w0 >> 16, w1 & 0xFFFF, w1 >> 16 }
  end
  local function speciesTypes(sp)
    local a = P.gSpeciesInfo + sp * O.si_size + O.si_types
    return { r8(a), r8(a + 1) }
  end
  Nat.partySpecies, Nat.partyMoves = partySpecies, partyMoves

  local function member(slot)
    local sp = partySpecies(slot)
    for _, ex in ipairs(CFG.exclude or {}) do if sp == C[ex] then return false end end
    return true
  end
  function Nat.level()
    local mn, mx, sum, n = 1000, 0, 0, 0
    for i = 0, N.partyCount() - 1 do
      if member(i) then
        local lv = N.partyMon(i).level
        mn, mx, sum, n = math.min(mn, lv), math.max(mx, lv), sum + lv, n + 1
      end
    end
    if n == 0 then return 0, 0, 0 end
    return mn, sum // n, mx
  end

  ---------------------------------------------------------------- move scoring
  local moveCache = {}
  local function moveInfo(id)
    if moveCache[id] then return moveCache[id] end
    local a = P.gMovesInfo + id * O.mi_size
    -- MoveInfo: effect:16 type:5 category:2 power:9 in the word at +8, accuracy:7 target:9 at +12.
    local w8, w12 = r32(a + 8), r32(a + 12)
    local m = { effect = w8 & 0xFFFF, type = (w8 >> 16) & 0x1F, category = (w8 >> 21) & 3,
                power = (w8 >> 23) & 0x1FF, accuracy = w12 & 0x7F }
    moveCache[id] = m
    return m
  end
  Nat.moveInfo = moveInfo

  local function eff(atk, def)
    return r32(P.gTypeEffectivenessTable + (atk * O.types_count + def) * 4) / 4096
  end

  -- These turn the score to 0 or discount it; nothing else is special-cased.
  local NEVER = { [C.MOVE_EXPLOSION] = true, [C.MOVE_SELF_DESTRUCT] = true, [C.MOVE_MEMENTO] = true,
                  [C.MOVE_HEALING_WISH] = true, [C.MOVE_FINAL_GAMBIT] = true }
  local TWO_TURN = { [C.MOVE_SOLAR_BEAM] = true, [C.MOVE_SKY_ATTACK] = true, [C.MOVE_RAZOR_WIND] = true,
                     [C.MOVE_SKULL_BASH] = true, [C.MOVE_FLY] = true, [C.MOVE_DIG] = true, [C.MOVE_DIVE] = true,
                     [C.MOVE_BOUNCE] = true }
  local IMMUNE_ABILITY = {
    [C.ABILITY_LEVITATE] = C.TYPE_GROUND, [C.ABILITY_VOLT_ABSORB] = C.TYPE_ELECTRIC, [C.ABILITY_LIGHTNING_ROD] = C.TYPE_ELECTRIC,
    [C.ABILITY_MOTOR_DRIVE] = C.TYPE_ELECTRIC, [C.ABILITY_WATER_ABSORB] = C.TYPE_WATER, [C.ABILITY_DRY_SKIN] = C.TYPE_WATER,
    [C.ABILITY_STORM_DRAIN] = C.TYPE_WATER, [C.ABILITY_FLASH_FIRE] = C.TYPE_FIRE, [C.ABILITY_SAP_SIPPER] = C.TYPE_GRASS,
  }
  local function baseScore(id, myTypes)
    if id == 0 or NEVER[id] then return 0 end
    local m = moveInfo(id)
    if m.category == 2 or m.power == 0 then return 0 end  -- status, or no base power (counters, HP-based)
    -- Power 1 is the "fixed or variable" marker (Seismic Toss, Low Kick); assume a middling hit.
    local power = (m.power == 1) and 50 or m.power
    if TWO_TURN[id] then power = power * 0.6 end
    local acc = (m.accuracy == 0) and 100 or m.accuracy
    local stab = 1
    for _, t in ipairs(myTypes) do if t == m.type then stab = 1.5 end end
    return power * acc / 100 * stab
  end
  Nat.baseScore = baseScore

  local function vsFoe(id, myTypes, foeTypes, ability)
    local s = baseScore(id, myTypes)
    if s == 0 then return 0 end
    local m = moveInfo(id)
    if IMMUNE_ABILITY[ability] == m.type then return 0 end
    local seen = {}
    for _, t in ipairs(foeTypes) do
      if not seen[t] then seen[t] = true; s = s * eff(m.type, t) end
    end
    return s
  end

  local function foeOf(battler)
    local foe = bmon(1)
    if r16(foe + O.bm_hp) == 0 and r16(bmon(3) + O.bm_hp) > 0 then foe = bmon(3) end
    return { r8(foe + O.bm_types), r8(foe + O.bm_types + 1), r8(foe + O.bm_types + 2) }, r16(foe + O.bm_ability)
  end
  local function myTypes(b) return { r8(b + O.bm_types), r8(b + O.bm_types + 1), r8(b + O.bm_types + 2) } end

  -- Highest-scoring usable slot for the battler; 0 if nothing scores.
  function Nat.bestSlot(battler, bad)
    local b = bmon(battler)
    local foeTypes, ability = foeOf(battler)
    local types = myTypes(b)
    local best, bestScore = 0, -1
    for i = 0, 3 do
      local mv = r16(b + O.bm_moves + 2 * i)
      if mv ~= 0 and r8(b + O.bm_pp + i) > 0 and not (bad and bad[i]) then
        local s = vsFoe(mv, types, foeTypes, ability)
        if s > bestScore then best, bestScore = i, s end
      end
    end
    return best, math.max(bestScore, 0)
  end

  ---------------------------------------------------------------- calibration
  -- The bitfield read above is only as good as the layout; check it on known moves at startup.
  local function calibrate()
    local want = { { C.MOVE_THUNDERBOLT, 90, 100, C.TYPE_ELECTRIC, 1 }, { C.MOVE_TACKLE, 40, 100, C.TYPE_NORMAL, 0 },
      { C.MOVE_SWIFT, 60, 0, C.TYPE_NORMAL, 1 }, { C.MOVE_EARTHQUAKE, 100, 100, C.TYPE_GROUND, 0 },
      { C.MOVE_THUNDER_WAVE, 0, 90, C.TYPE_ELECTRIC, 2 } }
    for _, w in ipairs(want) do
      moveCache[w[1]] = nil
      local m = moveInfo(w[1])
      local good = m.power == w[2] and m.accuracy == w[3] and m.type == w[4] and m.category == w[5]
      L(string.format('NAT calibrate move %d: power %d acc %d type %d cat %d %s', w[1], m.power, m.accuracy, m.type, m.category, good and 'ok' or 'MISMATCH'))
      assert(good, 'gMovesInfo layout does not match the bitfields natural.lua reads')
    end
    local fire, grass, fw = C.TYPE_FIRE, C.TYPE_GRASS, eff(C.TYPE_FIRE, C.TYPE_WATER)
    L(string.format('NAT calibrate types: fire>grass %.2f fire>water %.2f normal>ghost %.2f', eff(fire, grass), fw, eff(C.TYPE_NORMAL, C.TYPE_GHOST)))
    assert(eff(fire, grass) == 2 and fw == 0.5 and eff(C.TYPE_NORMAL, C.TYPE_GHOST) == 0, 'type chart does not read back')
  end

  ---------------------------------------------------------------- learn moves
  local function teamScore(slot)
    local types = speciesTypes(partySpecies(slot))
    local s = {}
    for i, mv in ipairs(partyMoves(slot)) do s[i] = baseScore(mv, types) end
    return s, types
  end
  -- A new move is good when it beats the weakest of the four, which is the one it replaces.
  local function decideLearn(slot, newMove)
    local s, types = teamScore(slot)
    local newS = baseScore(newMove, types)
    local weakest, weakestScore = 1, 1 / 0
    for i, v in ipairs(s) do if v < weakestScore then weakest, weakestScore = i, v end end
    local accept = newS > weakestScore
    L(string.format('NAT learn: slot %d move %d score %.0f vs weakest slot %d score %.0f -> %s', slot, newMove, newS, weakest - 1, weakestScore,
      accept and 'yes' or 'no'))
    return accept, weakest - 1
  end

  local pendingForget, forgetDone
  local function activeAny(name)
    for _, a in ipairs(P._all[name] or { P[name] }) do
      local t = N.activeTask(a)
      if t then return t end
    end
  end

  -- The in-battle Yes/No is a battle-script command, not a controller state: read the instruction.
  local LEARN_OP
  for op = 0, 255 do
    if (r32(P.gBattleScriptingCommandsTable + 4 * op) & ~1) == (P.Cmd_yesnoboxlearnmove & ~1) then LEARN_OP = op; break end
  end
  function Nat.battleText()
    if r8(r32(P.gBattlescriptCurrInstr)) == LEARN_OP then
      local slot = r8(r32(P.gBattleStruct) + O.bs_expGetterMonId)
      local yes, weakest = decideLearn(slot, r16(P.gMoveToLearn))
      if yes then pendingForget = weakest; press('A'); idle(40); stats.learned = stats.learned + 1
      else pendingForget = nil; press('B'); idle(20) end
      return true
    end
    return false
  end
  -- After a battle (evolution scene, summary screen). True when it pressed something.
  function Nat.menu()
    if F.cb2() == (P.CB2_BagMenuRun & ~1) then press('B'); idle(20); return true end
    local t = activeAny('Task_HandleReplaceMoveInput')
    if t then
      if not forgetDone then
        forgetDone = true
        idle(40)
        if pendingForget then
          for _ = 1, pendingForget do press('Down', 2); idle(12) end
          press('A', 2); idle(40)
        else
          press('B', 2); idle(30)
        end
        pendingForget = nil
      else
        idle(10)
      end
      return true
    end
    forgetDone = false
    t = activeAny('Task_EvolutionScene')
    if t and r16(t + 8) == 22 and r16(t + 8 + 12) == 4 then
      local slot = r16(t + 8 + 20)
      local yes, weakest = decideLearn(slot, r16(P.gMoveToLearn))
      if yes then pendingForget = weakest; press('A'); idle(40); stats.learned = stats.learned + 1
      else pendingForget = nil; press('B'); idle(20) end
      return true
    end
    return false
  end

  ---------------------------------------------------------------- switching and Potions
  local switches = 0
  local function benchSlot()
    -- The bench member with the highest move score against this foe, in field order.
    local foeTypes, ability = foeOf(N.activeBattler)
    local best, bestScore = nil, 0
    local active = r16(P.gBattlerPartyIndexes + 2 * N.activeBattler)
    for i = 0, N.partyCount() - 1 do
      local pm = N.partyMon(i)
      if i ~= active and pm.hp > 0 and pm.level > 0 and member(i) then
        local types = speciesTypes(partySpecies(i))
        for _, mv in ipairs(partyMoves(i)) do
          local s = vsFoe(mv, types, foeTypes, ability)
          if s > bestScore then best, bestScore = i, s end
        end
      end
    end
    return best, bestScore
  end
  local function monId(slot) return r32(P.gParties + slot * O.mon_size) end

  local function switchTo(slot)
    local want = monId(slot)
    press('Up'); idle(4); press('Left'); idle(4); press('Down'); idle(4); press('A'); idle(30)
    for _ = 1, 240 do
      if F.cb2() == (P.CB2_UpdatePartyMenu & ~1) then break end
      idle(1)
    end
    idle(30)
    -- The menu shows battle order and gParties is reordered while it is open.
    local menuSlot
    for i = 0, N.partyCount() - 1 do if monId(i) == want then menuSlot = i end end
    if not menuSlot then press('B'); idle(30); return false end
    for _ = 1, 8 do
      if r8(P.gPartyMenu + 9) == menuSlot then break end
      press('Down'); idle(10)
    end
    L('NAT switch: party slot ' .. slot)
    press('A'); idle(20); press('A'); idle(40)
    return true
  end

  local potionsOff = false
  local POTIONS = { 'ITEM_FULL_RESTORE', 'ITEM_MAX_POTION', 'ITEM_HYPER_POTION', 'ITEM_SUPER_POTION', 'ITEM_POTION' }
  local function itemRow(id)
    local ptr = r32(P.gBagPockets)
    for s = 0, F.pocketCap(0) - 1 do if r16(ptr + s * 4) == id then return s end end
  end
  local function qty(id)
    local ptr = r32(P.gBagPockets)
    for s = 0, F.pocketCap(0) - 1 do
      if r16(ptr + s * 4) == id then return r16(ptr + s * 4 + 2) ~ (r32(r32(P.gSaveBlock2Ptr) + O.sb2_encryptionKey) & 0xFFFF) end
    end
    return 0
  end
  Nat.qty = qty
  local function usePotion()
    local id, row
    for _, name in ipairs(POTIONS) do
      if C[name] and F.itemCount(C[name]) > 0 then id, row = C[name], itemRow(C[name]); break end
    end
    if not row then return false end
    local active = r16(P.gBattlerPartyIndexes + 2 * N.activeBattler)
    press('Up'); idle(4); press('Left'); idle(4); press('Right'); idle(4); press('A'); idle(30)
    for _ = 1, 240 do
      if F.cb2() == (P.CB2_BagMenuRun & ~1) then break end
      idle(1)
    end
    idle(30)
    for _ = 1, 8 do
      if r8(P.gBagPosition + 5) == 0 then break end
      press('Left'); idle(20)
    end
    for _ = 1, 40 do
      local cur = r16(P.gBagPosition + 8) + r16(P.gBagPosition + 18)   -- cursorPosition[0] + scrollPosition[0]
      if cur == row then break end
      press(cur < row and 'Down' or 'Up'); idle(10)
    end
    local before = qty(id)
    press('A'); idle(30)        -- context menu
    press('A'); idle(40)        -- Use
    idle(40)                    -- the party input waits for its icon animation
    local slotTask = activeAny('Task_BagMenu_PartyInput')
    L(string.format('NAT potion: party input task %s, slot cursor %d, want %d', tostring(slotTask ~= nil), slotTask and r16(slotTask + 8 + 8) or -1, active))
    for _ = 1, 10 do
      if not slotTask or r16(slotTask + 8 + 8) == active then break end
      press('Down'); idle(16)
    end
    press('A'); idle(50)
    for i = 1, 40 do
      if F.cb2() == (P.BattleMainCB2 & ~1) then break end
      press((i % 3 == 0) and 'B' or 'A'); idle(10)
    end
    local used = before > qty(id)
    L(string.format('NAT potion: item %d on slot %d used=%s (%d -> %d) back=%s', id, active, tostring(used), before, qty(id), tostring(F.cb2() == (P.BattleMainCB2 & ~1))))
    if not used then potionsOff = true; return false end
    stats.potions = stats.potions + 1
    return true
  end

  local battleMap
  function Nat.battleStart() switches = 0; potionsOff = false; battleMap = N.mapName() end
  function Nat.turn(trainer)
    local b = bmon(N.activeBattler)
    local hp, max = r16(b + O.bm_hp), r16(b + O.bm_maxHP)
    if (trainer or grinding) and not potionsOff and max > 0 and hp * 3 < max and usePotion() then return true end
    if switches < 3 then
      local _, score = Nat.bestSlot(N.activeBattler, N.badSlots)
      if score == 0 then
        local slot, benchScore = benchSlot()
        if slot and benchScore > 0 and switchTo(slot) then switches = switches + 1; return true end
      end
    end
    return false
  end

  function Nat.pickSendOut(allowed)
    local foeTypes, ability = foeOf(0)
    local best, bestScore = nil, -1
    for i = 0, N.partyCount() - 1 do
      local pm = N.partyMon(i)
      if pm.hp > 0 and pm.level > 0 and allowed(i) and member(i) then
        local types = speciesTypes(partySpecies(i))
        local top = 0
        for _, mv in ipairs(partyMoves(i)) do top = math.max(top, vsFoe(mv, types, foeTypes, ability)) end
        local s = top * (0.5 + 0.5 * pm.hp / pm.maxHP)
        if s > bestScore then best, bestScore = i, s end
      end
    end
    if best then L('NAT send-out: menu slot ' .. best) end
    return best
  end

  ---------------------------------------------------------------- whiteouts
  function Nat.battleEnd(trainer, outcome)
    if outcome == C.B_OUTCOME_LOST or outcome == C.B_OUTCOME_DREW then
      stats.battlesLost = stats.battlesLost + 1
      pendingLoss = { map = battleMap, trainer = trainer }
      L(string.format('NAT LOSS trainer=%s at %s level %d/%d/%d', tostring(trainer), battleMap, Nat.level()))
    end
  end
  -- A loss is a whiteout only if the game sent us away; early rivals carry on regardless.
  function Nat.takeWhiteout()
    if not pendingLoss then return false end
    local moved = pendingLoss.map ~= N.mapName()
    pendingLoss = nil
    if moved then stats.whiteouts = stats.whiteouts + 1 end
    return moved
  end

  ---------------------------------------------------------------- Pokemon Centers
  local function teamCondition()
    local fainted, hp, max = 0, 0, 0
    for i = 0, N.partyCount() - 1 do
      if member(i) then
        local pm = N.partyMon(i)
        hp, max = hp + pm.hp, max + pm.maxHP
        if pm.hp == 0 then fainted = fainted + 1 end
      end
    end
    return fainted, max > 0 and hp / max or 1
  end
  -- Damaging PP left across the team; grinding runs it dry long before HP.
  local function teamPP()
    local total = 0
    for i = 0, N.partyCount() - 1 do
      if member(i) then
        local types = speciesTypes(partySpecies(i))
        local pp = partyPP(i)
        for j, mv in ipairs(partyMoves(i)) do
          if baseScore(mv, types) > 0 then total = total + pp[j] end
        end
      end
    end
    return total
  end
  local function needCenter(force)
    local fainted, frac = teamCondition()
    if force then return fainted > 0 or frac < 0.999 end
    return fainted > 0 or frac < 0.5 or teamPP() < 8
  end
  -- Centers, nearest first by map hops over warps and connections from where we stand.
  local function centersByHops()
    N.resetPlanCaches()
    local lo, hi = N.region.lo, N.region.hi
    local start = F.grp() * 256 + F.mapn()
    local seen, q, head, found = { [start] = true }, { { F.grp(), F.mapn() } }, 1, {}
    while head <= #q and #found < 8 do
      local g, m = q[head][1], q[head][2]; head = head + 1
      local info = N.header(g, m)
      for _, ex in ipairs(N.exitsOf(info)) do
        local k = ex.g * 256 + ex.m
        if not seen[k] and ex.g >= lo and ex.g <= hi then
          seen[k] = true
          local name = N.mapName(ex.g, ex.m)
          if name:find('PokemonCenter') and not name:find('2F') then found[#found + 1] = name end
          q[#q + 1] = { ex.g, ex.m }
        end
      end
    end
    return found
  end

  local BLOCKED = {}
  function Nat.heal(force, why)
    if healing or BLOCKED[N.mapName()] or not N.free() then return false end
    if not needCenter(force) then return false end
    local from = N.mapName()
    local steps0 = N.steps
    healing = true
    local reached
    for _, center in ipairs(centersByHops()) do
      local ok, res = pcall(N.travel, center, { policy = N.defaultPolicy })
      if ok and res and N.mapName() == center then reached = center; break end
      if not ok and res == N.WHITEOUT then healing = false; error(res, 0) end
      L('NAT heal: could not reach ' .. center .. ': ' .. tostring(res))
    end
    healing = false
    if not reached then
      L('NAT heal: no reachable Center from ' .. from)
      BLOCKED[from] = true
      return false
    end
    local ok = N.talk({ 7, 3 }, { side = 1 })
    stats.centerTrips = stats.centerTrips + 1
    L(string.format('NAT center %s (%s) from %s: nurse talk %s, steps %d, party %s', reached, why or 'hp', from, tostring(ok),
      N.steps - steps0, Nat.partyText()))
    return ok
  end
  function Nat.maybeHeal() if needCenter(false) then Nat.heal(false, 'low hp') end end

  ---------------------------------------------------------------- Poke Marts
  local function martMap()
    local lo, hi = N.region.lo, N.region.hi
    local start = F.grp() * 256 + F.mapn()
    local seen, q, head = { [start] = true }, { { F.grp(), F.mapn() } }, 1
    while head <= #q and head < 120 do
      local g, m = q[head][1], q[head][2]; head = head + 1
      for _, ex in ipairs(N.exitsOf(N.header(g, m))) do
        local k = ex.g * 256 + ex.m
        if not seen[k] and ex.g >= lo and ex.g <= hi then
          seen[k] = true
          if N.mapName(ex.g, ex.m):find('Mart') then return N.mapName(ex.g, ex.m) end
          q[#q + 1] = { ex.g, ex.m }
        end
      end
    end
  end
  local function potionsCarried()
    local n = 0
    for _, name in ipairs(POTIONS) do if C[name] then n = n + qty(C[name]) end end
    return n
  end
  local function waitTask(name, frames)
    for _ = 1, frames or 300 do
      if activeAny(name) then return true end
      idle(1)
    end
    return activeAny(name) ~= nil
  end
  -- Back to the field through the shop's own exits. N.settle would mash A and buy the first item.
  local function leaveShop()
    for _ = 1, 60 do
      if N.free() then return end
      if activeAny('Task_BuyMenu') or activeAny('Task_ShopMenu') then press('B'); idle(50)
      else press('A'); idle(25) end
    end
  end
  local function buy(itemId, count)
    local info = N.header(F.grp(), F.mapn())
    local clerk
    for _, o in ipairs(info.objs) do if o.gfx == C.OBJ_EVENT_GFX_CLERK then clerk = o end end
    if not clerk then L('NAT shop: no clerk at ' .. N.mapName()); return 0 end
    -- The counter is between the clerk and the floor; the side differs by map, so try each.
    local inMenu
    for _, side in ipairs({ { 2, 0, 3 }, { 0, 2, 2 }, { -2, 0, 4 } }) do
      if N.go(clerk.x + side[1], clerk.y + side[2]) then
        N.face(side[3])
        press('A'); idle(30)
        for _ = 1, 12 do
          if activeAny('Task_ShopMenu') then inMenu = true; break end
          press('A'); idle(30)
        end
        if inMenu then break end
        leaveShop()
      end
    end
    if not inMenu then L('NAT shop: no shop menu at ' .. N.mapName()); return 0 end
    press('A')   -- Buy
    if not waitTask('Task_BuyMenu', 600) then L('NAT shop: no buy menu'); N.settle(); return 0 end
    idle(30)
    local list, cnt = r32(P.sMartInfo + 8), r16(P.sMartInfo + 12)
    local row
    for i = 0, cnt - 1 do if r16(list + i * 2) == itemId then row = i end end
    if not row then
      L('NAT shop: item ' .. itemId .. ' not in this mart')
      leaveShop()
      return 0
    end
    for _ = 1, 12 do
      local cur = r16(r32(P.sShopData) + 0x2006) + r16(r32(P.sShopData) + 0x2008)
      if cur == row then break end
      press(cur < row and 'Down' or 'Up'); idle(12)
    end
    press('A'); idle(40)
    if not waitTask('Task_BuyHowManyDialogueHandleInput', 300) then
      L('NAT shop: no quantity prompt')
      leaveShop()
      return 0
    end
    for _ = 2, count do press('Up'); idle(12) end
    press('A'); idle(40)
    for _ = 1, 8 do
      if activeAny('Task_CallYesOrNoCallback') then break end
      press('A'); idle(30)
    end
    press('A'); idle(40)                 -- Yes
    press('A'); idle(40)                 -- "Here you go"
    leaveShop()
    return count
  end

  -- Top up the Potions at the nearest Mart when the wallet allows it.
  function Nat.restock()
    if not N.free() or potionsCarried() >= (CFG.potionTarget or 6) then return end
    local money = N.money()
    if money < 1500 then return end
    local map = martMap()
    if not map then return end
    local ok, res = pcall(N.travel, map, { policy = N.defaultPolicy })
    if not ok then if res == N.WHITEOUT then error(res, 0) end; L('NAT shop: ' .. tostring(res)); return end
    if not res or N.mapName() ~= map then L('NAT shop: could not reach ' .. map); return end
    local afford = math.min(10, (money - 400) // 300)
    local before = money
    local n = buy(C.ITEM_SUPER_POTION, math.min(8, afford))
    if n == 0 then n = buy(C.ITEM_POTION, afford) end
    stats.bought = (stats.bought or 0) + n
    L(string.format('NAT shop: bought %d at %s, money %d -> %d, carrying %d', n, map, before, N.money(), potionsCarried()))
  end

  ---------------------------------------------------------------- grass and grinding
  local GRASS = { [C.MB_TALL_GRASS] = true, [C.MB_LONG_GRASS] = true, [C.MB_ASHGRASS or -1] = true }
  -- Tiles worth pacing on: grass, or any open floor when the map is a cave (encounters everywhere).
  local cavePacing = false
  local function grassTiles()
    local g = N.liveGrid()
    local reach = N.floodLive()
    local px, py = F.pos()
    local tiles = {}
    for y = 0, g.h - 1 do
      for x = 0, g.w - 1 do
        local v = g.get(x, y)
        if v and (v & 0x0C00) == 0 and (cavePacing or GRASS[g.beh(v & 0x3FF)]) and reach[x .. ',' .. y] then
          tiles[#tiles + 1] = { x, y, reach[x .. ',' .. y] }
        end
      end
    end
    table.sort(tiles, function(a, b) return a[3] < b[3] end)
    return tiles
  end
  -- Two neighbouring grass tiles, nearest first, so pacing never leaves the grass.
  local function pair()
    local set, tiles = {}, grassTiles()
    for _, t in ipairs(tiles) do set[t[1] .. ',' .. t[2]] = t end
    for _, t in ipairs(tiles) do
      for d = 1, 4 do
        local nb = set[(t[1] + N.DX[d]) .. ',' .. (t[2] + N.DY[d])]
        if nb then return t, nb end
      end
    end
  end
  local function grassCount(info)
    local grid = N.staticGrid(info)
    local n = 0
    for y = 0, grid.h - 1 do
      for x = 0, grid.w - 1 do
        local v = grid.get(x, y)
        if v and GRASS[grid.beh(v & 0x3FF)] then n = n + 1 end
      end
    end
    return n
  end
  -- The nearest map with a usable grass patch, walking the same map graph the planner uses.
  local function goToGrass(preferred)
    if preferred then assert(N.travel(preferred), 'no route to grind map ' .. preferred) end
    if pair() then return true end
    local start = F.grp() * 256 + F.mapn()
    local seen, q, head = { [start] = true }, { { F.grp(), F.mapn() } }, 1
    local lo, hi = N.region.lo, N.region.hi
    while head <= #q and head < 200 do
      local g, m = q[head][1], q[head][2]; head = head + 1
      for _, ex in ipairs(N.exitsOf(N.header(g, m))) do
        local k = ex.g * 256 + ex.m
        if not seen[k] and ex.g >= lo and ex.g <= hi then
          seen[k] = true
          local name = N.mapName(ex.g, ex.m)
          local avoid = false
          for _, pat in ipairs(CFG.noGrind or {}) do if name:find(pat) then avoid = true end end
          if not avoid and grassCount(N.header(ex.g, ex.m)) >= 4 then
            local ok, res = pcall(N.travel, name, { policy = N.defaultPolicy })
            if not ok and res == N.WHITEOUT then error(res, 0) end
            if ok and res and pair() then return true end
          end
          q[#q + 1] = { ex.g, ex.m }
        end
      end
    end
    return false
  end

  -- Walk a two-tile grass pace until cond() holds or budget steps pass. Fights everything.
  local function pace(cond, budget, preferredMap, opts)
    local whiteouts = 0
    local base = N.steps
    while not cond() and N.steps - base < budget do
      if not pair() then
        local got, err = pcall(goToGrass, preferredMap)
        if not got then
          if err == N.WHITEOUT then whiteouts = whiteouts + 1 else L('NAT pace: ' .. tostring(err)); return whiteouts end
        elseif err ~= true then L('NAT pace: no grass reachable'); return whiteouts end
      end
      local a, b = pair()
      if not a then return whiteouts end
      -- Pace in a burst, then re-evaluate the condition and the party's health.
      for i = 1, 16 do
        if cond() or N.steps - base >= budget then break end
        local t = (i % 2 == 0) and a or b
        local ok, err = pcall(function() N.go(t[1], t[2], opts); N.settle(opts) end)
        if not ok then
          if err == N.WHITEOUT then whiteouts = whiteouts + 1; L('NAT pace: whited out, going back'); break
          else error(err, 0) end
        end
      end
      if needCenter(false) then Nat.heal(false, 'pace') end
    end
    return whiteouts, N.steps - base
  end

  local function mapGood(name) return name and MAPS[name] end

  function Nat.grind(target, budget, map, opts)
    local _, avg = Nat.level()
    if avg >= target then return 0, 0 end
    L(string.format('NAT grind: to average L%d (now L%d) budget %d steps', target, avg, budget))
    grinding = true
    local s0 = N.steps
    local wo = pace(function() local _, a = Nat.level(); return a >= target end, budget, mapGood(map), { fight = true, policy = N.defaultPolicy })
    grinding = false
    local spent = N.steps - s0
    stats.grindSteps = stats.grindSteps + spent
    local _, now = Nat.level()
    L(string.format('NAT grind done: L%d after %d steps, %d whiteouts', now, spent, wo))
    return spent, wo
  end

  ---------------------------------------------------------------- catching
  function Nat.catch(spec)
    N.catchWanted = function(sp) return sp == C[spec.species] end
    local before = N.partyCount()
    local s0 = N.steps
    if spec.map then assert(N.travel(spec.map), 'no route to catch map') end
    cavePacing = spec.cave or false
    pace(function() return N.partyCount() > before or N.itemCount(C.ITEM_POKE_BALL) == 0 end, spec.budget or 400, spec.map,
      { fight = true, policy = N.defaultPolicy })
    cavePacing = false
    N.catchWanted = nil
    stats.catchSteps = stats.catchSteps + (N.steps - s0)
    L(string.format('NAT catch %s: party %d -> %d after %d steps', spec.species, before, N.partyCount(), N.steps - s0))
    return N.partyCount() > before
  end

  ---------------------------------------------------------------- beats
  function Nat.partyText()
    local t = {}
    for i = 0, N.partyCount() - 1 do
      local pm = N.partyMon(i)
      t[#t + 1] = string.format('%d:L%d %d/%d', partySpecies(i), pm.level, pm.hp, pm.maxHP)
    end
    return table.concat(t, ' ')
  end

  local function gymLine(g, s)
    return string.format('NAT-GYM %s: entered L%d/%d/%d (min/avg/max) vs ace %d (target %d), attempts %d, grind %d steps (limit %d), %s',
      g.beat, s.entryMin, s.entryAvg, s.entryMax, g.ace, g.ace - 3, s.attempts, s.grind, g.limit, s.won and 'WON' or 'LOST')
  end

  -- Before a gym: a full heal if it costs little, and a grind to ace minus 3 inside the allowance.
  function Nat.beforeBeat(b)
    -- Cut trees and smashed rocks respawn when a Center trip leaves the map, so the planner needs
    -- the field moves from the start of every beat, not only where the beat wrote them in.
    if N.beatSetup then N.beatSetup() end
    local g = GYM[b.name]
    if not g then
      if needCenter(false) then Nat.heal(false, 'before ' .. b.name) end
      return
    end
    Nat.heal(true, 'pre-gym')
    pcall(Nat.restock)
    local s = stats.gyms[b.name] or { attempts = 0, grind = 0, won = false }
    stats.gyms[b.name] = s
    if s.attempts == 0 then stats.order[#stats.order + 1] = b.name end
    s.attempts = s.attempts + 1
    local spent = Nat.grind(g.ace - 3, g.limit, CFG.grindMap and CFG.grindMap[b.name])
    s.grind = s.grind + spent
    if needCenter(true) then Nat.heal(true, 'pre-gym') end
    s.entryMin, s.entryAvg, s.entryMax = Nat.level()
    L(string.format('NAT enter %s attempt %d: L%d/%d/%d, party %s', b.name, s.attempts, s.entryMin, s.entryAvg, s.entryMax, Nat.partyText()))
  end

  -- After a loss: grind past where we were, then play it again. Gyms get their allowance; a story
  -- battle (Slowpoke Well, the Radio Tower) gets a smaller one, counted the same way.
  function Nat.afterLoss(b, attempts)
    local g = GYM[b.name]
    local _, avg = Nat.level()
    stats.beatWhiteouts = stats.beatWhiteouts or {}
    stats.beatWhiteouts[b.name] = (stats.beatWhiteouts[b.name] or 0) + 1
    Nat.restock()
    local target = math.max(g and (g.ace - 3) or 0, avg + attempts)
    local budget = (g and g.limit or CFG.storyGrind or 400) * attempts
    local spent = Nat.grind(target, budget, CFG.grindMap and CFG.grindMap[b.name])
    if g then
      local s = stats.gyms[b.name]
      s.grind = s.grind + spent
      s.attempts = s.attempts + 1
    end
  end

  function Nat.afterBeat(b, won)
    local g = GYM[b.name]
    if not g then return end
    local s = stats.gyms[b.name]
    if s then s.won = won; L(gymLine(g, s)) end
  end

  ---------------------------------------------------------------- checkpoints
  local function ser(v)
    if type(v) == 'table' then
      local t = {}
      for k, x in pairs(v) do t[#t + 1] = '[' .. ser(k) .. ']=' .. ser(x) end
      return '{' .. table.concat(t, ',') .. '}'
    end
    if type(v) == 'string' then return string.format('%q', v) end
    return tostring(v)
  end
  function Nat.saveCheckpoint(name)
    local f = io.open(F.out .. 'nat_' .. name .. '.lua', 'w')
    if f then f:write('return ' .. ser(stats)); f:close() end
  end
  function Nat.loadCheckpoint(name)
    local fn = loadfile(F.out .. 'nat_' .. name .. '.lua')
    if fn then
      local t = fn()
      for k in pairs(stats) do stats[k] = nil end
      for k, v in pairs(t) do stats[k] = v end
    end
  end

  ---------------------------------------------------------------- setup
  function Nat.install()
    N.acceptPrompts = true
    N.natural = Nat
    N.debugHeal = function() stats.skippedDebugHeals = stats.skippedDebugHeals + 1 end
  end

  function Nat.setup()
    calibrate()
    -- Hard Mode is the bit from gSaveBlock2 byte 22 (probed against the bitfield); the intro's
    -- prompt may have left it on while boot mashes through. Exp 1x is the same byte's low bits.
    local b22 = r8(F.sb2() + 22)
    L(string.format('NAT options byte: 0x%02x (hard=%d, exp=%d)', b22, (b22 >> 4) & 1, b22 & 3))
    F.w8(F.sb2() + 22, b22 & ~0x13)
    local flagBase = F.sb1() + O.sb1_flags
    local id = C.FLAG_QOL_SHARED_EXP
    F.w8(flagBase + (id // 8), r8(flagBase + (id // 8)) | (1 << (id % 8)))
    assert(LEARN_OP, 'Cmd_yesnoboxlearnmove is not in the opcode table')
    L('NAT setup: Exp Share on, Hard Mode off, Exp 1x, opcode ' .. LEARN_OP)
  end

  -- The SwSh picker before a partner battle: mark the healthy team members, then Start confirms.
  function Nat.picker(tries)
    if tries > 1 then return end
    for i = 0, N.partyCount() - 1 do
      local pm = N.partyMon(i)
      if pm.hp > 0 and member(i) then
        for _ = 1, 8 do
          if r8(P.gPartyMenu + 9) == i then break end
          press('Down'); idle(12)
        end
        press('A'); idle(30)
      end
    end
  end

  function Nat.report()
    local lines = {}
    for _, name in ipairs(stats.order) do
      local g, s = GYM[name], stats.gyms[name]
      lines[#lines + 1] = gymLine(g, s)
    end
    lines[#lines + 1] = string.format('NAT-TOTAL steps=%d grind=%d catch=%d centers=%d potions=%d whiteouts=%d lostbattles=%d learned=%d warps=%d skippedDebugHeals=%d',
      N.steps, stats.grindSteps, stats.catchSteps, stats.centerTrips, stats.potions, stats.whiteouts, stats.battlesLost, stats.learned, stats.warps, stats.skippedDebugHeals)
    for _, l in ipairs(lines) do L(l) end
    local f = io.open(F.out .. 'natural_report.txt', 'w')
    if f then f:write(table.concat(lines, '\n') .. '\n'); f:close() end
  end

  -- Team-building beats, in order, spliced after the beats they follow.
  function Nat.patchBeats(beats)
    local out = {}
    for _, b in ipairs(beats) do
      if b.name ~= 'party' then
        if CFG.done and CFG.done[b.name] then b.done = CFG.done[b.name](F, N, C) end
        out[#out + 1] = b
        for _, spec in ipairs(CFG.catches) do
          if spec.after == b.name then
            out[#out + 1] = { name = 'catch_' .. spec.species:gsub('SPECIES_', ''):lower(), run = function()
              local got = Nat.catch(spec)
              if not got and not spec.optional then error('catch failed: ' .. spec.species) end
            end, done = function() return true end }
          end
        end
      end
    end
    return out
  end

  return Nat
end
