-- Visible wild Pokemon against Surf, ledges and trainers, with one Pokemon and two Eggs.
--
-- OweStressFuzz walks grass routes with no trainers. This one surfs Route 41 (water encounters
-- spawn only while surfing) and walks Route 45's ledges, both with trainers who battle on sight,
-- so an encounter's approach can overlap a ledge jump, a Surf mount or dismount, and a trainer's
-- approach. The party is a level 100 Lapras (Surf, Ice Beam) in front of two Eggs: every battle
-- has exactly one usable Pokemon and the Eggs must stay out of it.
--
-- The spawn countdown is zeroed before every action. A fixed pseudo-random sequence walks, runs,
-- presses A (twice, so a Surf prompt is accepted), opens the Start menu and waits. After every
-- action the game must come back to a free field inside the budget, with no crash screen; a
-- stretch that never gets there is reported with the script pointer and the live tasks. The party
-- must come out of the fuzz intact: three members, Lapras first, then the two Togepi.
--
-- Run via test/overworld/mgba-run.sh test/overworld/lua/OweSurfLedgeFuzz.lua
-- PW_FUZZ_ACTIONS (default 250 per map) lengthens it; PW_FUZZ_SEED reseeds it.

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "OweSurfLedgeFuzz")

local CONTEXT_RUNNING = 0
local SPECIES_LAPRAS, SPECIES_TOGEPI = 131, 175
local MOVE_SURF, MOVE_ICE_BEAM = 57, 58
local PARTY_SIZE = 6
local ITEM_SURF_TOOL = 876
local AVATAR_SURFING = 1 << 3
local ACTIONS = tonumber(os.getenv("PW_FUZZ_ACTIONS") or "250")
local SETTLE_BUDGET = 3600
local BATTLE_BUDGET = 30000
local DIRS = { "Up", "Down", "Left", "Right" }

-- Route 41 (2|87<<8) warp 4 lands on the sea from Route 40, already surfing. Route 45 (2|93<<8)
-- warp 0 is the Dark Cave mouth at the top of the ledges. Route 40 (1|87<<8) warp 9 is the
-- Trainer Hill gate door on the beach, north of the shallows and the sea.
local ROUTES = {
  { name = "Route41", g = 87, m = 2, w = 4, surf = true },
  { name = "Route40", g = 87, m = 1, w = 9, mount = true },
  { name = "Route45", g = 93, m = 2, w = 0 },
}

local seed = tonumber(os.getenv("PW_FUZZ_SEED") or "0x51A7E3")
local function rand(n)
  seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF
  return (seed >> 8) % n
end

local function hasControl()
  return F.ow() and F.r8(S.sLockFieldControls) == 0
    and F.r8(S.sGlobalScriptContextStatus) ~= CONTEXT_RUNNING
end
local function inBattle() return F.cb2() == (S.BattleMainCB2 & ~1) end
local function surfing() return (F.r8(S.gPlayerAvatar) & AVATAR_SURFING) ~= 0 end

local function liveTasks()
  local t = {}
  for j = 0, S.Task.count - 1 do
    local b = S.gTasks + j * S.Task.stride
    if F.r8(b + S.Task.isActive) ~= 0 then t[#t + 1] = string.format("%08X", F.r32(b)) end
  end
  return table.concat(t, ",")
end

local function partyAddr(s) return S.gParties + s * S.Pokemon.size end
local function partyCount() return F.r8(S.gPartiesCount) end

-- BoxPokemon flags byte 19 (bit1 hasSpecies, bit2 isEgg); species is the low 11 bits of
-- substruct 0's first word, located through sSubstructOffsets.
local function monAt(slot)
  local b = partyAddr(slot)
  local pid = F.r32(b)
  local key = pid ~ F.r32(b + 4)
  local w0 = F.r32(b + 32 + F.r8(S.sSubstructOffsets + (pid % 24)) * 12) ~ key
  return w0 & 0x7FF, (F.r8(b + 19) & 4) ~= 0, F.r16(b + S.Pokemon.hp)
end

local stats = { battles = 0, approaches = 0, surfed = 0, maxOwe = 0, waterOwe = 0, maps = {} }

local function countOwes()
  local n = 0
  for i = 0, 15 do
    local o = S.gObjectEvents + i * S.ObjectEvent.stride
    if (F.r8(o) & 1) ~= 0 and F.r8(o + 7) == 0xFF then n = n + 1 end
  end
  return n
end

local function settle(tag)
  local battled, approached = false, false
  for f = 1, SETTLE_BUDGET + BATTLE_BUDGET do
    if not inBattle() and f > SETTLE_BUDGET and not battled then break end
    if inBattle() then
      battled = true
      -- Alternate Surf and Ice Beam so a Water Absorb foe still goes down.
      local slot = (f // 900) % 2
      F.w8(S.gMoveSelectionCursor, slot)
      F.w8(S.gBattleMons + S.BattlePokemon.pp + slot, 10)
      -- Always FIGHT: a wrapped Pokemon that keeps choosing RUN is refused forever.
      F.w8(S.gActionSelectionCursor, 0)
      if f % 10 == 0 then F.press("A", 2) else F.idle(1) end
    elseif F.ow() then
      if hasControl() then
        if battled then stats.battles = stats.battles + 1 end
        if approached then stats.approaches = stats.approaches + 1 end
        return true
      end
      for j = 0, S.Task.count - 1 do
        local b = S.gTasks + j * S.Task.stride
        if F.r8(b + S.Task.isActive) ~= 0 and (F.r32(b) & ~1) == (S.Task_OWEApproachForBattle & ~1) then approached = true end
      end
      if f % 20 == 0 then F.press(f % 40 == 0 and "A" or "B", 2) else F.idle(1) end
    else
      if f % 20 == 0 then F.press("B", 2) else F.idle(1) end
    end
    if f % 120 == 0 and F.reportCrash(tag) then return false, "crash screen" end
  end
  if inBattle() then
    local BM = S.BattlePokemon
    return false, string.format("battle: main=%08X ctrl0=%08X ctrl1=%08X instr=%08X outcome=%d cursor=%d mon0=%d hp%d foe=%d hp%d/%d",
      F.r32(S.gBattleMainFunc), F.r32(S.gBattlerControllerFuncs), F.r32(S.gBattlerControllerFuncs + 4),
      F.r32(S.gBattlescriptCurrInstr), F.outcome(), F.r8(S.gActionSelectionCursor),
      F.r16(S.gBattleMons), F.r16(S.gBattleMons + BM.hp), F.r16(S.gBattleMons + BM.size),
      F.r16(S.gBattleMons + BM.size + BM.hp), F.r16(S.gBattleMons + BM.size + BM.maxHP))
  end
  return false, string.format("cb2=%08X lock=%d script=%d pc=%08X tasks=%s at %d/%d (%d,%d)",
    F.cb2(), F.r8(S.sLockFieldControls), F.r8(S.sGlobalScriptContextStatus),
    F.r32(S.sGlobalScriptContext + S.ScriptCtx.scriptPtr), liveTasks(), F.grp(), F.mapn(),
    select(1, F.pos()), select(2, F.pos()))
end

local function act(k)
  F.w8(S.sOWESpawnCountdown, 0)
  local wasSurfing = surfing()
  local r = rand(20)
  if r < 10 then
    F.press(DIRS[rand(4) + 1], 16 * (1 + rand(3)))
  elseif r < 13 then
    local d = DIRS[rand(4) + 1]
    for _ = 1, 16 * (1 + rand(3)) do joypad.set({ [d] = true, B = true }); emu.frameadvance() end
  elseif r < 15 then
    F.press("Start", 2); F.idle(20 + rand(40)); F.press("B", 2); F.idle(20)
  elseif r < 18 then
    F.press(DIRS[rand(4) + 1], 2); F.idle(6)
    F.press("A", 2); F.idle(30); F.press("A", 2); F.idle(30); F.press("A", 2); F.idle(10)
  else
    F.idle(20 + rand(60))
  end
  joypad.set({})
  local n = countOwes()
  if n > stats.maxOwe then stats.maxOwe = n end
  if wasSurfing and n > 0 then stats.waterOwe = stats.waterOwe + 1 end
  local ok, why = settle("act" .. k)
  if ok and surfing() ~= wasSurfing then stats.surfed = stats.surfed + 1 end
  return ok, why
end

local function task(fn)
  for j = 0, S.Task.count - 1 do
    local t = S.gTasks + j * S.Task.stride
    if F.r8(t + S.Task.isActive) ~= 0 and (F.r32(t) & ~1) == (fn & ~1) then return t end
  end
end

-- Debug Give X > Pokemon (Basic) or Give Egg, writing the spinner's input directly.
local function giveMon(species, level)
  F.dbg(); F.idle(30)
  for _ = 1, 3 do F.press("Down", 3); F.idle(16) end
  F.press("A", 3); F.idle(50)
  for _ = 1, (level and 1 or 3) do F.press("Down", 3); F.idle(16) end
  F.press("A", 3); F.idle(80)
  local t = task(S.DebugAction_Give_Pokemon_SelectId)
  if t then
    F.w16(t + S.Task.data + 6, species); F.idle(4); F.press("A", 3); F.idle(40)
    if level then
      local t2 = task(S.DebugAction_Give_Pokemon_SelectLevel)
      if t2 then F.w16(t2 + S.Task.data + 6, level); F.idle(4); F.press("A", 3); F.idle(60) end
    end
  end
  for _ = 1, 8 do F.press("B", 2); F.idle(20) end
  return partyCount()
end

local SCRIPT_BUF = S.gStringVar4 + 960
local function runScript(bytes)
  for i, b in ipairs(bytes) do F.w8(SCRIPT_BUF + i - 1, b) end
  F.w8(S.sGlobalScriptContext, 0)
  F.w8(S.sGlobalScriptContext + 1, 1)
  F.w32(S.sGlobalScriptContext + 4, 0)
  F.w32(S.sGlobalScriptContext + S.ScriptCtx.scriptPtr, SCRIPT_BUF)
  F.w8(S.sGlobalScriptContextStatus, CONTEXT_RUNNING)
end
local function le16(t, v) t[#t + 1] = v & 0xFF; t[#t + 1] = (v >> 8) & 0xFF end
local function le32(t, v) le16(t, v & 0xFFFF); le16(t, (v >> 16) & 0xFFFF) end
-- createmon for the player, moves pinned; a player-OT Pokemon obeys at any level.
local function createMon(species, level, moves)
  local b = { 0x23 }; le32(b, S.ScrCmd_createmon | 1)
  b[#b + 1] = 0; b[#b + 1] = PARTY_SIZE
  le16(b, species); le16(b, level)
  le32(b, (1 << 17) | (1 << 18) | (1 << 19) | (1 << 20))
  for k = 1, 4 do le16(b, moves[k] or 0) end
  b[#b + 1] = 0x02
  runScript(b); F.idle(20)
  return partyCount()
end
local function addItem(id, qty)
  runScript({ 0x44, id & 0xFF, id >> 8, qty & 0xFF, qty >> 8, 0x02 }); F.idle(10)
end

-- Gen 8+ obedience reads the met level against the badge cap, so a level 100 met at 100 naps
-- through every battle. Lower it to 5 the way the campaign harness does (substruct 3, encrypted
-- with personality ^ otId, checksum adjusted).
local SUB3 = { 3, 2, 3, 2, 1, 1, 3, 2, 3, 2, 1, 1, 3, 2, 3, 2, 1, 1, 0, 0, 0, 0, 0, 0 }
local function setMetLevel(slot, lvl)
  local b = partyAddr(slot)
  local pid, otid = F.r32(b), F.r32(b + 4)
  local key = pid ~ otid
  local addr = b + 32 + 12 * SUB3[(pid % 24) + 1]
  local old = F.r32(addr) ~ key
  local new = (old & ~(0x7F << 16)) | ((lvl & 0x7F) << 16)
  local function halves(v) return (v & 0xFFFF) + (v >> 16) end
  F.w32(addr, new ~ key)
  F.w16(b + 28, (F.r16(b + 28) - halves(old) + halves(new)) & 0xFFFF)
end

local function d(n) return (n // 100) % 10, (n // 10) % 10, n % 10 end

local function partyIntact(tag)
  local s0, e0, hp0 = monAt(0)
  local s1, e1 = monAt(1)
  local s2, e2 = monAt(2)
  -- A long run walks far enough to hatch the Eggs, which is play; they must still be Togepi.
  F.check(tag .. ": party is Lapras and the two Togepi",
    partyCount() == 3 and s0 == SPECIES_LAPRAS and not e0 and hp0 > 0 and s1 == SPECIES_TOGEPI and s2 == SPECIES_TOGEPI,
    string.format("count=%d %d/%s/hp%d %d/%s %d/%s", partyCount(), s0, tostring(e0), hp0, s1, tostring(e1), s2, tostring(e2)))
end

F.run(function()
  if not F.boot(100) then F.check("boot to the hub", false); F.finish(); return end
  F.check("a level 100 Lapras leads", createMon(SPECIES_LAPRAS, 100, { MOVE_SURF, MOVE_ICE_BEAM }) == 1)
  setMetLevel(0, 5)
  F.check("two Eggs behind it", giveMon(SPECIES_TOGEPI) == 2 and giveMon(SPECIES_TOGEPI) == 3)
  addItem(ITEM_SURF_TOOL, 1)
  F.check("Surf tool in Key Items", F.keyItemSlot(ITEM_SURF_TOOL) >= 0)
  partyIntact("before the fuzz")
  for _, r in ipairs(ROUTES) do
    local gh, gt, go = d(r.g)
    local mh, mt, mo = d(r.m)
    local wh, wt, wo = d(r.w)
    local warped = F.warpTo(gh, gt, go, mh, mt, mo, wh, wt, wo, r.g, r.m, r.name)
    F.check("warp to " .. r.name, warped)
    if warped then
      if r.surf then F.check(r.name .. ": arrives surfing", surfing()) end
      if r.mount then
        for _ = 1, 12 do if not F.step("Down") then break end end
        for i = 1, 8 do
          F.press("A", 2); F.idle(40)
          if surfing() then break end
        end
        F.idle(120)
        F.check(r.name .. ": Surf from the beach", surfing(), string.format("at (%d,%d)", F.pos()))
        if surfing() then stats.surfed = stats.surfed + 1 end
      end
      local ok, why = settle(r.name .. "_arrive")
      local failed
      for k = 1, (ok and ACTIONS or 0) do
        stats.maps[F.grp() * 256 + F.mapn()] = true
        ok, why = act(r.name .. k)
        if not ok then failed = k; break end
      end
      F.check(r.name .. ": every action returned to a free field", ok,
        failed and string.format("action %d: %s", failed, why) or tostring(why or ""))
      if not ok then F.shot(r.name .. "_stuck"); break end
      partyIntact(r.name)
    end
  end
  local nmaps = 0
  for _ in pairs(stats.maps) do nmaps = nmaps + 1 end
  F.L(string.format("  stats: battles=%d approaches=%d surf-changes=%d max-owes=%d actions-with-water-owes=%d maps=%d",
    stats.battles, stats.approaches, stats.surfed, stats.maxOwe, stats.waterOwe, nmaps))
  F.check("visible wild Pokemon spawned while surfing", stats.waterOwe > 0, "actions=" .. stats.waterOwe)
  F.check("Surf was mounted or dismounted during the fuzz", stats.surfed > 0, "changes=" .. stats.surfed)
  F.check("the fuzz reached battles", stats.battles > 0, "battles=" .. stats.battles)
  F.finish()
end)
