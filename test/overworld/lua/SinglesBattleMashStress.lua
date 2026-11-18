-- Single battles (and a trainer double with one foe down) mashed with a Bag that has something in
-- every pocket: the BW battle UI, the in-battle Bag and the in-battle party screen must never crash,
-- strand the battle, corrupt the party, or put more of any item in the Bag than it started with.
--
-- Each scenario builds a party with createmon / giveegg (as givemon and the Daycare leave them):
-- three Machop (Guts, no Pickup, so a won battle hands out no items), an Egg and one fainted Machop.
-- The Bag gets X Attack, Dire Hit, Potion, Revive, Ether, Full Heal, Poke Doll, Poke and Great Balls,
-- an Oran Berry and a TM. Battles: wild Magikarp (setwildbattle + dowildbattle) at Instant text, the
-- same at Slow text, wild Magikarp with the party and every PC box full (the ball must be refused),
-- the debug single trainer, and the debug trainer double. A seeded mash of A, B, Start, L, R and the
-- D-pad (never Select: the debug battle menu) runs for a while, then a finisher wins or runs.
--
-- Checked on RAM after each battle: no crash screen, the field is back and walkable, every party
-- slot decrypts with a valid checksum, no Egg was ever on the field, the PC/party census has no
-- duplicate personality, and no item quantity grew.
--
-- PW_SMASH_SEED=<n> reseeds, PW_SMASH_ONLY=<text> runs matching scenarios.
-- Run via test/overworld/mgba-run.sh test/overworld/lua/SinglesBattleMashStress.lua <rom>

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "SinglesBattleMashStress")

local ONLY = os.getenv("PW_SMASH_ONLY")
local seed = tonumber(os.getenv("PW_SMASH_SEED") or "") or 0x5EED6
local PARTY_SIZE, BOX_SLOTS = 6, 14 * 30
local CONTEXT_RUNNING, CONTEXT_SHUTDOWN = 0, 2
local MAX_SPECIES_BITS = 0x7FF
local SPECIES_MACHOP, SPECIES_MAGIKARP, SPECIES_TOGEPI = 66, 129, 175
local MOVE_KARATE_CHOP, MOVE_LOW_KICK = 2, 67
local BAG = {
  { 121, 3 }, { 127, 2 }, { 28, 5 }, { 33, 2 }, { 49, 2 }, { 48, 2 }, { 129, 2 },
  { 1, 5 }, { 2, 3 }, { 520, 3 }, { 582, 1 },
}
local BM = S.BattlePokemon

local function inBattle() return F.cb2() == (S.BattleMainCB2 & ~1) end
local function ctrl(b) return F.r32(S.gBattlerControllerFuncs + b * 4) & ~1 end
local function isAction(b)
  for _, p in ipairs(S.ActionInputFunctions) do if ctrl(b) == (p & ~1) then return true end end
  return false
end
local function isMove(b) return ctrl(b) == (S.HandleInputChooseMove & ~1) end
local function isTarget(b) return ctrl(b) == (S.HandleInputChooseTarget & ~1) end
local function waitFor(pred, n) for _ = 1, n or 300 do if pred() then return true end F.idle(1) end return pred() end
local function partyAddr(s) return S.gParties + s * S.Pokemon.size end
local function partyCount() return F.r8(S.gPartiesCount) end
local function boxAddr(s) return F.r32(S.gPokemonStoragePtr) + 4 + s * S.BoxPokemon.size end
local function hasControl()
  return F.ow() and F.r8(S.sLockFieldControls) == 0 and F.r8(S.sGlobalScriptContextStatus) == CONTEXT_SHUTDOWN
end

local function options() return F.sb2() + S.SaveBlock2.optionsU16 end
local function textSpeed(v) F.w16(options(), (F.r16(options()) & ~7) | v) end
local function setStyle() F.w16(options(), F.r16(options()) | (1 << 9) | (1 << 10)) end   -- Set style, scene off

local SCRIPT_BUF = S.gStringVar4 + 960
local function le16(t, v) t[#t + 1] = v & 0xFF; t[#t + 1] = (v >> 8) & 0xFF end
local function le32(t, v) le16(t, v & 0xFFFF); le16(t, (v >> 16) & 0xFFFF) end
local function runScript(bytes)
  for i, b in ipairs(bytes) do F.w8(SCRIPT_BUF + i - 1, b) end
  F.w8(S.sGlobalScriptContext, 0)
  F.w8(S.sGlobalScriptContext + 1, 1)
  F.w32(S.sGlobalScriptContext + 4, 0)
  F.w32(S.sGlobalScriptContext + S.ScriptCtx.scriptPtr, SCRIPT_BUF)
  F.w8(S.sGlobalScriptContextStatus, CONTEXT_RUNNING)
end
local function addItem(id, qty) local b = { 0x44 }; le16(b, id); le16(b, qty); b[#b + 1] = 0x02; runScript(b); F.idle(10) end
local function giveMon(species, level, moves)
  local b = { 0x23 }; le32(b, S.ScrCmd_createmon | 1)
  b[#b + 1] = 0; b[#b + 1] = PARTY_SIZE
  le16(b, species); le16(b, level)
  le32(b, (1 << 17) | (1 << 18) | (1 << 19) | (1 << 20))
  for k = 1, 4 do le16(b, moves[k] or 0) end
  b[#b + 1] = 0x02
  runScript(b); F.idle(20)
end
local function giveEgg(species) local b = { 0x7A }; le16(b, species); b[#b + 1] = 0x02; runScript(b); F.idle(20) end
local function clearParty()
  for off = 0, PARTY_SIZE * S.Pokemon.size - 4, 4 do F.w32(S.gParties + off, 0) end
  F.w8(S.gPartiesCount, 0)
end

local function monAt(a)
  local fl = F.r8(a + 19)
  local m = { present = (fl & 2) ~= 0, egg = (fl & 4) ~= 0, bad = (fl & 1) ~= 0, pid = F.r32(a) }
  if not m.present then return m end
  local key = F.r32(a) ~ F.r32(a + 4)
  local w, sum = {}, 0
  for i = 0, 11 do
    w[i] = F.r32(a + 32 + i * 4) ~ key
    sum = (sum + (w[i] & 0xFFFF) + (w[i] >> 16)) & 0xFFFF
  end
  m.species = w[F.r8(S.sSubstructOffsets + (m.pid % 24)) * 3] & MAX_SPECIES_BITS
  m.checksumOk = sum == F.r16(a + 28)
  return m
end
local function partySane()
  local n, bad, occupied = partyCount(), {}, 0
  for s = 0, PARTY_SIZE - 1 do
    local m = monAt(partyAddr(s))
    if m.present then
      occupied = occupied + 1
      if m.bad or not m.checksumOk then bad[#bad + 1] = "slot" .. s .. " checksum" end
      if not m.egg then
        local hp, mx = F.r16(partyAddr(s) + S.Pokemon.hp), F.r16(partyAddr(s) + S.Pokemon.maxHP)
        if mx == 0 or hp > mx then bad[#bad + 1] = string.format("slot%d hp=%d/%d", s, hp, mx) end
      end
    elseif s < n then bad[#bad + 1] = "slot" .. s .. " hole" end
  end
  if occupied ~= n then bad[#bad + 1] = string.format("occupied=%d count=%d", occupied, n) end
  return #bad == 0, table.concat(bad, "; ")
end
local function census()
  local seen, dups, total = {}, 0, 0
  local function add(a)
    local m = monAt(a)
    if m.present then total = total + 1; if seen[m.pid] then dups = dups + 1 end; seen[m.pid] = true end
  end
  for s = 0, PARTY_SIZE - 1 do add(partyAddr(s)) end
  for s = 0, BOX_SLOTS - 1 do add(boxAddr(s)) end
  return total, dups
end
local function qty(id)
  local key = F.r32(F.sb2() + S.SaveBlock2.encryptionKey) & 0xFFFF
  local n = 0
  for p = 0, 4 do
    local ptr = F.r32(S.gBagPockets + p * S.BagPocket.stride)
    local cap = F.pocketCap(p)
    if ptr >= 0x02000000 and ptr < 0x02040000 and cap > 0 and cap < 400 then
      for s = 0, cap - 1 do if F.r16(ptr + s * 4) == id then n = n + (F.r16(ptr + s * 4 + 2) ~ key) end end
    end
  end
  return n
end

local function tapDown(n) for _ = 1, n do F.press("Down", 3); F.idle(16) end end
local function debugRow(root, row, extra)
  F.dbg(); F.idle(40)
  tapDown(root); F.press("A", 3); F.idle(50)
  tapDown(row); F.press("A", 3); F.idle(extra or 120)
  for _ = 1, 8 do F.press("B", 3); F.idle(18) end
end
local function clearBag() debugRow(1, 2, 120) end
local function clearBoxes() debugRow(1, 3, 120) end
local function fillBoxes()
  F.dbg(); F.idle(40)
  tapDown(1); F.press("A", 3); F.idle(50)
  tapDown(1); F.press("A", 3); F.idle(50)
  F.press("A", 3); F.idle(400)
  for _ = 1, 8 do F.press("B", 3); F.idle(18) end
end

local function startWild()
  local b = { 0xB6 }; le16(b, SPECIES_MAGIKARP); b[#b + 1] = 8; le16(b, 0); le16(b, 0); b[#b + 1] = 0; le16(b, 0)
  b[#b + 1] = 0xB7; b[#b + 1] = 0x02
  runScript(b)
  return waitFor(function() return inBattle() and F.battlers() >= 2 end, 1500)
end
local function startTrainer(double)
  F.dbg(); F.idle(80)
  tapDown(6); F.press("A", 3); F.idle(80)
  tapDown(1); F.press("A", 3); F.idle(50)
  F.press("Up", 3); F.idle(16)
  F.press("A", 3); F.idle(80)
  if double then
    tapDown(2); F.press("A", 3); F.idle(50)
    F.press("Up", 3); F.idle(16); F.press("Up", 3); F.idle(16)
    F.press("A", 3); F.idle(80)
    tapDown(4); F.press("A", 3); F.idle(30)
    F.press("Down", 3); F.idle(16)
  else
    tapDown(4)
  end
  F.press("A", 3)
  return waitFor(function() return inBattle() and F.battlers() >= 2 end, 1500)
end

local KEYS = { "A", "A", "A", "B", "B", "Start", "L", "R", "Up", "Down", "Left", "Right" }
local function rnd(n) seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF; return (seed >> 8) % n end

local eggOnField = nil
local function guardEgg()
  if not inBattle() or F.battlers() < 2 then return end
  for _, b in ipairs({ 0, 2 }) do
    if b < F.battlers() and ((F.r8(S.gAbsentBattlerFlags) >> b) & 1) == 0 then
      local idx = F.r16(S.gBattlerPartyIndexes + b * 2)
      if idx < PARTY_SIZE and isAction(b) and monAt(partyAddr(idx)).egg then
        eggOnField = string.format("battler %d party %d", b, idx)
      end
    end
  end
end

local function steer(b, want)
  local cur = F.r8(S.gActionSelectionCursor + b)
  if cur == want then return "A" end
  if (cur & 1) ~= (want & 1) then return (cur & 1) < (want & 1) and "Right" or "Left" end
  return (cur & 2) < (want & 2) and "Down" or "Up"
end
local function moveSteer(b)
  local cur = F.r8(S.gMoveSelectionCursor + b)
  if cur == 0 then return "A" end
  if (cur & 1) ~= 0 then return "Left" end
  return "Up"
end

-- The forced switch after a faint refuses B, and the menu opens on the fainted Pokemon, so a fixed
-- key cycle never leaves it; the mash can also leave its Send Out box open there.
local partyKey = F.forcedSwitchKeys()

local fin = 0
local SAVE_DIR = os.getenv("PW_SMASH_SAVE")
local function finisher(wild)
  for b = 0, 2, 2 do
    if b < F.battlers() then
      if isAction(b) then return steer(b, wild and 3 or 0) end
      if isMove(b) then return moveSteer(b) end
      if isTarget(b) then return "A" end
    end
  end
  -- Off the battle screen (Bag, party, nickname): B backs out, a Bag message needs A, and the
  -- naming screen needs Start (cursor to OK) then A.
  if F.cb2() == (S.CB2_UpdatePartyMenu & ~1) then return partyKey() end
  if not inBattle() then fin = fin + 1; return ({ "B", "B", "Start", "A" })[fin % 4 + 1] end
  return "A"
end

local function battleLoop(tag, wild, mashFrames, budget)
  local f = 0
  while f < budget do
    if F.ow() and not inBattle() then return true end
    local key = (f < mashFrames) and KEYS[rnd(#KEYS) + 1] or finisher(wild)
    F.press(key, 2); F.idle(2 + rnd(4)); f = f + 6
    guardEgg()
    if f % 600 < 6 and F.reportCrash(tag) then return false end
  end
  return F.ow()
end

local function snapshotBag()
  local t = {}
  for _, it in ipairs(BAG) do t[it[1]] = qty(it[1]) end
  return t
end

local function scenario(name, opts)
  if ONLY and not name:find(ONLY, 1, true) then return end
  F.L("== " .. name .. string.format(" (seed %X)", seed))
  clearParty(); clearBag(); clearBoxes()
  for _ = 1, 3 do giveMon(SPECIES_MACHOP, 60, { MOVE_KARATE_CHOP, MOVE_LOW_KICK }) end
  giveEgg(SPECIES_TOGEPI)
  giveMon(SPECIES_MACHOP, 60, { MOVE_KARATE_CHOP })
  F.w16(partyAddr(4) + S.Pokemon.hp, 0)
  if opts.full then giveMon(SPECIES_MACHOP, 60, { MOVE_KARATE_CHOP }); fillBoxes() end
  for _, it in ipairs(BAG) do addItem(it[1], it[2]) end
  textSpeed(opts.text or 3); setStyle()
  local bag0 = snapshotBag()
  local total0, dups0 = census()
  eggOnField = nil
  local started = opts.trainer and startTrainer(opts.double) or startWild()
  F.check(name .. ": battle started", started)
  if not started then return end
  local back = battleLoop(name, not opts.trainer, opts.mash or 1800, 24000)
  F.shot(name .. "_end")
  if not back then
    local v0 = F.r32(S.gMain + 0x20); F.idle(60); local v1 = F.r32(S.gMain + 0x20)
    F.L(string.format("  STUCK vblank %d -> %d over 60 frames", v0, v1))
    if SAVE_DIR then client.savestate(SAVE_DIR .. "/" .. name .. ".ss") end
    local hp = {}
    for b = 0, F.battlers() - 1 do hp[#hp + 1] = F.r16(S.gBattleMons + b * BM.size + BM.hp) end
    local cf = {}
    for b = 0, F.battlers() - 1 do cf[#cf + 1] = string.format("%08X", ctrl(b)) end
    F.L(string.format("  STUCK outcome=%d hp=%s ctrl=%s absent=%02X main=%08X instr=%08X exec=%08X",
      F.outcome(), table.concat(hp, ","), table.concat(cf, ","), F.r8(S.gAbsentBattlerFlags),
      S.gBattleMainFunc and F.r32(S.gBattleMainFunc) or 0,
      S.gBattlescriptCurrInstr and F.r32(S.gBattlescriptCurrInstr) or 0,
      S.gBattleControllerExecFlags and F.r32(S.gBattleControllerExecFlags) or 0))
  end
  F.check(name .. ": no crash", not F.reportCrash(name))
  F.check(name .. ": back on the field", back, string.format("cb2=%08X", F.cb2()))
  F.check(name .. ": control returns", waitFor(hasControl, 600))
  local ok, why = partySane()
  F.check(name .. ": party sane", ok, why)
  F.check(name .. ": no Egg on the field", eggOnField == nil, eggOnField or "")
  local total, dups = census()
  F.check(name .. ": no duplicated Pokemon", dups == dups0, string.format("total %d -> %d dups %d -> %d", total0, total, dups0, dups))
  if opts.full then F.check(name .. ": nothing caught with party and boxes full", total == total0, total0 .. " -> " .. total) end
  local grew = {}
  for _, it in ipairs(BAG) do
    local now = qty(it[1])
    if now > bag0[it[1]] then grew[#grew + 1] = string.format("item %d: %d -> %d", it[1], bag0[it[1]], now) end
  end
  F.check(name .. ": no item grew", #grew == 0, table.concat(grew, "; "))
end

F.run(function()
  if not F.boot(100) then F.check("boot", false); F.finish(); return end
  F.dbg(); F.idle(30); F.bOut(4)
  for round = 1, 2 do
    scenario("wild_instant_" .. round, {})
    scenario("wild_slow_" .. round, { text = 0, mash = 1200 })
    scenario("wild_full_pc_" .. round, { full = true })
    scenario("trainer_single_" .. round, { trainer = true })
    scenario("trainer_double_" .. round, { trainer = true, double = true })
  end
  F.finish()
end)
