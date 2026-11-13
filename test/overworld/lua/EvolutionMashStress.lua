-- Mashing every button through the evolution flow must never crash, strand or corrupt the game.
--
-- Each scenario arms a real evolution, then drives the scene with a seeded pseudo-random mash
-- (A, B, Start, Select, L, R and the D-pad) and requires that the scene runs, ends, and hands the
-- player back a walkable field with a consistent party:
--
--   1. a level-up evolution after a battle, mashed throughout (species must change);
--   2. the same evolution held on B (species must NOT change; the control for 1);
--   3. an evolution that learns a move into a full moveset, through the forget-move prompt and
--      the move-select summary screen (moveset unique, PP sane, the new move's PP bonus cleared);
--   4. Nincada into Ninjask plus Shedinja with a full party, with five and a Poke Ball, and with
--      five and no Poke Ball (never a seventh slot, never a ball-less Shedinja);
--   5. three party members evolving back to back after one battle;
--   6. a Thunder Stone used from the bag on a party with an Egg of the same species in front of
--      it (the Egg must never evolve, the Pikachu behind it must);
--   7. the A+B+Start+Select soft reset in the middle of the scene, then Continue (the saved
--      party must load intact).
--
-- HOW THE EVOLUTIONS ARE ARMED. A post-battle level-up evolution needs TryEvolvePokemon to find
-- the slot's bit in gLeveledUpInBattle and the mon at or past its evolution level. The debug Give
-- menu creates each mon at the right level with matching EXP (CalculateMonStats at the end of
-- every battle re-derives the level from EXP, so a poked level byte would be undone), the suite
-- keeps those 100 raw bytes, and writes them into the player's party once a debug battle is
-- running, because Start Debug Battle replaces the party with the debug trainer's. The bit and
-- gBattleOutcome are then poked exactly as LevelUpSummary.lua seeds gLevelUpStartLevels: the
-- identical end-of-battle path runs, without having to out-level a debug trainer.
--
-- WHY B IS NEVER PRESSED ALONE in the evolving mashes. Task_EvolutionScene cancels when
-- gMain.heldKeys == B_BUTTON exactly. A mash that let B through alone would make "the species
-- changed" a coin toss, so the mash pairs every B with another button; scenario 2 then holds B
-- alone on purpose and requires the opposite result.
--
-- Run via test/overworld/mgba-run.sh test/overworld/lua/EvolutionMashStress.lua <rom>
-- PW_EVO_ONLY=<text> runs only the scenarios whose tag contains <text>; PW_EVO_SEED=<n> reseeds.

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "EvolutionMashStress")

local HUB_GROUP = 100
local ONLY = os.getenv("PW_EVO_ONLY")
local PARTY_SIZE = 6
local MON = S.Pokemon.size
local B_OUTCOME_WON = 1
local USM_ICO_SAVE, USM_ICO_BAG = 7, 2

local SPECIES = {
  BULBASAUR = 1, IVYSAUR = 2, VENUSAUR = 3, CHARMANDER = 4, CHARMELEON = 5,
  SQUIRTLE = 7, WARTORTLE = 8, PIKACHU = 25, RAICHU = 26,
  NINCADA = 290, NINJASK = 291, SHEDINJA = 292,
}
local ITEM_POKE_BALL, ITEM_RARE_CANDY, ITEM_THUNDER_STONE = 1, 102, 213
local MOVE_PETAL_BLIZZARD, PETAL_BLIZZARD_PP = 572, 15
local POCKET_ITEMS, POCKET_BALLS = 0, 1

-- Task_EvolutionScene's tState enum (src/evolution_scene.c).
local EVO_SET_MON_EVOLVED, EVO_END, EVO_CANCEL, EVO_REPLACE_MOVE = 14, 16, 17, 22

-- ---- seeded mash --------------------------------------------------------------------------------
local seed = tonumber(os.getenv("PW_EVO_SEED") or "") or 0xE70
local function rnd()
  seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF
  return seed >> 8
end
local DIRS = { "Up", "Down", "Left", "Right" }
local MASH = { A = 45, B = 35, Start = 15, Select = 15, L = 10, R = 10, dir = 45 }

-- One mashed frame. Never the soft-reset chord, and (unless allowLoneB) never B on its own.
local function mashKeys(w, allowLoneB)
  local t = {}
  for _, b in ipairs({ "A", "B", "Start", "Select", "L", "R" }) do
    if rnd() % 100 < (w[b] or 0) then t[b] = true end
  end
  if rnd() % 100 < (w.dir or 0) then t[DIRS[rnd() % 4 + 1]] = true end
  if t.A and t.B and t.Start and t.Select then t.Select = nil end
  if t.B and not allowLoneB then
    local n = 0
    for _ in pairs(t) do n = n + 1 end
    if n == 1 then t.A = true end
  end
  return t
end

-- ---- party decode -------------------------------------------------------------------------------
local function slotAddr(i) return S.gParties + i * MON end

local function order(p)
  local o = {}
  for i = 0, 3 do o[i] = F.r8(S.sSubstructOffsets + i * 24 + p % 24) * 3 end
  return o
end

-- Decrypt a struct Pokemon the way GetBoxMonData does: XOR the 48 secure bytes with
-- personality ^ otId, find each substruct through sSubstructOffsets, and recompute the checksum.
local function decode(a)
  local pers, otid = F.r32(a), F.r32(a + 4)
  local key = pers ~ otid
  local w = {}
  for i = 0, 11 do w[i] = F.r32(a + 32 + i * 4) ~ key end
  local sum = 0
  for i = 0, 11 do sum = sum + (w[i] & 0xFFFF) + (w[i] >> 16) end
  local o = order(pers)
  local s0, s1, s3 = o[0], o[1], o[3]
  local flags = F.r8(a + 19)
  local m = {
    pers = pers, otid = otid,
    species = w[s0] & 0x7FF,
    exp = w[s0 + 1] & 0x1FFFFF,
    ppBonuses = w[s0 + 2] & 0xFF,
    moves = { w[s1] & 0x7FF, (w[s1] >> 16) & 0x7FF, w[s1 + 1] & 0x7FF, (w[s1 + 1] >> 16) & 0x7FF },
    pp = { w[s1 + 2] & 0x7F, (w[s1 + 2] >> 8) & 0x7F, (w[s1 + 2] >> 16) & 0x7F, (w[s1 + 2] >> 24) & 0x7F },
    egg = ((w[s3 + 1] >> 30) & 1) == 1,
    headerEgg = (flags & 4) ~= 0,
    badEgg = (flags & 1) ~= 0,
    hasSpecies = (flags & 2) ~= 0,
    checksumOk = (sum & 0xFFFF) == F.r16(a + 28),
    level = F.r8(a + S.Pokemon.level),
    hp = F.r16(a + S.Pokemon.hp), maxHP = F.r16(a + S.Pokemon.maxHP),
    words = w, o = o,
  }
  return m
end

-- Re-encrypt edited secure words (decode's m.words) with a fresh checksum.
local function encode(a, m)
  local key = F.r32(a) ~ F.r32(a + 4)
  local sum = 0
  for i = 0, 11 do
    local v = m.words[i] & 0xFFFFFFFF
    sum = sum + (v & 0xFFFF) + (v >> 16)
    F.w32(a + 32 + i * 4, v ~ key)
  end
  F.w16(a + 28, sum & 0xFFFF)
end

local function blank(a)
  for off = 0, MON - 4, 4 do if F.r32(a + off) ~= 0 then return false end end
  return true
end

local function describe(i)
  local a = slotAddr(i)
  if blank(a) then return string.format("[%d] empty", i) end
  local m = decode(a)
  return string.format("[%d] sp=%d lv=%d hp=%d/%d egg=%s moves=%d,%d,%d,%d pp=%d,%d,%d,%d bon=%02X sum=%s",
    i, m.species, m.level, m.hp, m.maxHP, tostring(m.egg), m.moves[1], m.moves[2], m.moves[3], m.moves[4],
    m.pp[1], m.pp[2], m.pp[3], m.pp[4], m.ppBonuses, m.checksumOk and "ok" or "BAD")
end

local function dumpParty(tag)
  F.L(string.format("  party %s: count=%d", tag, F.r8(S.gPartiesCount)))
  for i = 0, PARTY_SIZE - 1 do F.L("    " .. describe(i)) end
end

-- Every occupied slot decrypts cleanly, is not a bad egg, and the count covers exactly the
-- occupied prefix (no hole, no seventh mon, nothing past the count).
local function partyConsistent()
  local n = F.r8(S.gPartiesCount)
  if n > PARTY_SIZE then return false, "count=" .. n end
  for i = 0, PARTY_SIZE - 1 do
    local a = slotAddr(i)
    if i < n then
      if blank(a) then return false, "hole at slot " .. i end
      local m = decode(a)
      if not m.checksumOk then return false, "bad checksum at slot " .. i end
      if m.badEgg then return false, "bad egg at slot " .. i end
      if m.species == 0 or not m.hasSpecies then return false, "no species at slot " .. i end
    elseif not blank(a) and decode(a).species ~= 0 then
      return false, "slot " .. i .. " occupied past count " .. n
    end
  end
  return true, "count=" .. n
end

local function movesetSane(m)
  local seen = {}
  for k = 1, 4 do
    local mv, pp = m.moves[k], m.pp[k]
    if mv == 0 then
      if pp ~= 0 then return false, "empty slot " .. k .. " has pp " .. pp end
    else
      if mv >= 1000 then return false, "move id " .. mv end
      if seen[mv] then return false, "duplicate move " .. mv end
      seen[mv] = true
      if pp == 0 or pp > 64 then return false, "move " .. mv .. " pp " .. pp end
    end
  end
  if m.moves[1] == 0 then return false, "no first move" end
  return true, ""
end

-- ---- bag ----------------------------------------------------------------------------------------
local function pocketPtr(p) return F.r32(S.gBagPockets + p * S.BagPocket.stride) end
local function qtyKey() return F.r32(F.sb2() + S.SaveBlock2.encryptionKey) & 0xFFFF end
local function countItem(id)
  local n = 0
  for p = 0, 4 do
    local ptr, cap = pocketPtr(p), F.pocketCap(p)
    if ptr >= 0x02000000 and ptr < 0x02040000 and cap < 400 then
      for s = 0, cap - 1 do
        if F.r16(ptr + s * 4) == id then n = n + (F.r16(ptr + s * 4 + 2) ~ qtyKey()) end
      end
    end
  end
  return n
end
-- Empty a pocket, then put `qty` of `id` in its first slot (qty 0 leaves it empty).
local function setPocket(p, id, qty)
  local ptr, cap = pocketPtr(p), F.pocketCap(p)
  for s = 0, cap - 1 do F.w16(ptr + s * 4, 0); F.w16(ptr + s * 4 + 2, qtyKey()) end
  if qty > 0 then F.w16(ptr, id); F.w16(ptr + 2, qty ~ qtyKey()) end
end

-- ---- field, debug menu, battle ------------------------------------------------------------------
local function inBag() local c = F.cb2(); return c == (S.CB2_Bag & ~1) or c == (S.CB2_BagMenuRun & ~1) end

local BACK = { Left = "Right", Right = "Left", Up = "Down", Down = "Up" }
-- Right first: lib's Left-first ensureFree rides the hub escalator from its apron.
local function free()
  local x0, y0 = F.pos()
  for _, dir in ipairs({ "Right", "Left", "Down", "Up" }) do
    if F.step(dir) then
      F.step(BACK[dir])
      local x, y = F.pos()
      return x == x0 and y == y0
    end
  end
  return false
end

local TRACE = os.getenv("PW_EVO_TRACE")
local function recover(tag, budget)
  local last, seq = -1, {}
  for i = 1, budget or 3000 do
    if TRACE and F.cb2() ~= last then
      last = F.cb2()
      seq[#seq + 1] = string.format("%d:%08X", i, last)
      if #seq % 12 == 0 then F.L("  trace " .. table.concat(seq, " ")); seq = {} end
    end
    if F.reportCrash(tag) then return false, "crash" end
    if F.ow() and i % 60 == 0 and free() then return true, "free after " .. i end
    if i % 24 < 2 then
      -- A only off the field and out of the bag: on the field it would reopen the Start menu's
      -- last icon (the bag, after a bag scenario) and cycle there forever.
      local useA = (i // 24) % 5 == 4 and not F.ow() and not inBag()
      joypad.set({ [useA and "A" or "B"] = true })
    else
      joypad.set({})
    end
    emu.frameadvance()
  end
  return false, string.format("cb2=%08X", F.cb2())
end

local function instantText()
  local a = F.sb2() + S.SaveBlock2.optionsU16
  F.w16(a, (F.r16(a) & ~7) | 3)
end

local function zeroParty()
  for off = 0, PARTY_SIZE * MON - 4, 4 do F.w32(S.gParties + off, 0) end
  F.w8(S.gPartiesCount, 0)
end

local function writeParty(list)
  zeroParty()
  for i, bytes in ipairs(list) do
    local a = slotAddr(i - 1)
    for off = 0, MON - 1 do F.w8(a + off, bytes[off + 1]) end
  end
  F.w8(S.gPartiesCount, #list)
end

local function readSlot(i)
  local a, t = slotAddr(i), {}
  for off = 0, MON - 1 do t[off + 1] = F.r8(a + off) end
  return t
end

-- Give X(3) -> Pokemon (Basic)(1); both spinners count up from 1 (src/debug.c), so the values
-- entered are species - 1 and level - 1.
local function digits(n) n = n - 1; return n // 100, (n // 10) % 10, n % 10 end
local function giveMon(species, level)
  local n0 = F.r8(S.gPartiesCount)
  F.dbg(); F.sel(3); F.sel(1); F.idle(20)
  F.spin(digits(species)); F.idle(20)
  F.spin(digits(level)); F.idle(60); F.bOut(4)
  return F.r8(S.gPartiesCount) == n0 + 1
end

-- A template: the raw 100 bytes the debug Give menu produced for (species, level), checked to
-- decrypt to that species and level before it is kept.
local templates, templateMoves = {}, {}
local function makeTemplate(name, species, level)
  zeroParty()
  if not giveMon(species, level) then F.L("  give " .. name .. " failed"); return false end
  local m = decode(slotAddr(0))
  F.L(string.format("  template %s: %s", name, describe(0)))
  if m.species ~= species or m.level ~= level or not m.checksumOk then return false end
  templates[name] = readSlot(0)
  templateMoves[name] = m.moves
  return true
end

local function tapDown(n) for _ = 1, n do F.press("Down", 3); F.idle(16) end end
-- gBattlersCount outlives a battle and the battle transition runs under CB2_Overworld, so both
-- "count > 0" and "not on the field" are true while BattleStartClearSetData is still to come --
-- and that zeroes gBattleOutcome and gLeveledUpInBattle. Zero the stale count first and wait for
-- the battle's own callback, then give the intro time to pass the reset.
local function startDebugBattle(tag)
  F.w8(S.gBattlersCount, 0)
  F.dbg(); F.idle(60)
  tapDown(2); F.press("A", 3); F.idle(60)    -- Party...(2)
  tapDown(10); F.press("A", 3)                -- Start Debug Battle(10)
  for _ = 1, 120 do
    F.idle(10)
    if F.r8(S.gBattlersCount) > 0 and F.cb2() == (S.BattleMainCB2 & ~1) then F.idle(120); return true end
  end
  F.L(string.format("  %s: the debug battle never started cb2=%08X", tag, F.cb2()))
  return false
end

local function evoTask()
  for i = 0, S.Task.count - 1 do
    local a = S.gTasks + i * S.Task.stride
    if F.r8(a + S.Task.isActive) ~= 0 and (F.r32(a + S.Task.func) & ~1) == (S.Task_EvolutionScene & ~1) then
      return a
    end
  end
  return nil
end

local SCENE_CB = {
  [S.CB2_EvolutionSceneUpdate & ~1] = true,
  [S.CB2_BeginEvolutionScene & ~1] = true,
  [S.CB2_EvolutionSceneLoadGraphics & ~1] = true,
}
local function inScene() return SCENE_CB[F.cb2()] == true end

-- Mash from now until the field is back. Records how many separate evolution scenes ran and
-- every Task_EvolutionScene state seen. `hold` replaces the mash with a fixed key set.
local function mashThrough(tag, opts)
  opts = opts or {}
  local r = { scenes = 0, states = {}, ended = false, crash = false, frames = 0 }
  local was = false
  local budget = opts.frames or 20000
  for i = 1, budget do
    if i % 4 == 0 and F.reportCrash(tag) then r.crash = true; r.frames = i; break end
    -- One scene = one sEvoStructPtr lifetime: EvolutionScene allocates it and EVOSTATE_END frees
    -- it. Counting callback entries instead would count the return from the move-select summary
    -- screen (CB2_EvolutionSceneLoadGraphics) as a second evolution.
    local now = F.r32(S.sEvoStructPtr) ~= 0
    if now and not was then r.scenes = r.scenes + 1 end
    was = now
    local t = evoTask()
    if t then r.states[F.r16(t + S.Task.data)] = true end
    if F.r8(S.sLevelUpSummaryState) == 3 then r.box = true end
    if i == 3000 and r.scenes == 0 then
      F.shot(tag:gsub("%W", "_") .. "_no_scene_yet")
      F.L(string.format("  %s: no scene after 3000 frames cb2=%08X ctrl=%08X main=%08X outcome=%d",
        tag, F.cb2(), F.r32(S.gBattlerControllerFuncs), F.r32(S.gBattleMainFunc), F.outcome()))
    end
    if opts.onFrame and opts.onFrame(i, r) then r.frames = i; r.stopped = true; break end
    if F.ow() and r.scenes >= (opts.minScenes or 1) then r.ended = true; r.frames = i; break end
    if F.ow() and i > 600 and r.scenes == 0 then r.frames = i; break end
    -- A forced gBattleOutcome only ends the battle at the end of a turn, so a fixed-key run
    -- taps A (FIGHT, then the first move) until the first scene opens.
    local keys
    if opts.hold and r.scenes == 0 then keys = (i % 8 < 2) and { A = true } or {}
    elseif opts.hold then keys = opts.hold(i)
    else keys = mashKeys(opts.w or MASH, opts.allowLoneB) end
    joypad.set(keys)
    emu.frameadvance()
  end
  joypad.set({})
  r.frames = r.frames > 0 and r.frames or budget
  local st = {}
  for k in pairs(r.states) do st[#st + 1] = k end
  table.sort(st)
  r.stateList = table.concat(st, ",")
  F.L(string.format("  %s: scenes=%d ended=%s stopped=%s frames=%d states=[%s] cb2=%08X", tag, r.scenes,
    tostring(r.ended), tostring(r.stopped == true), r.frames, r.stateList, F.cb2()))
  return r
end

-- The player's battler still holds the debug Wobbuffet that Start Debug Battle sent out, and the
-- battle writes its moves, PP and HP back into party slot 0 (PP after every move used). In a
-- real game the battler and the slot are the same mon; make them so here, or a mashed move
-- grafts Wobbuffet's moveset onto the evolving mon (seen: Venusaur with two Celebrates).
local function syncBattler()
  local m = decode(slotAddr(0))
  local b = S.gBattleMons
  F.w16(b, m.species)
  for k = 1, 4 do
    F.w16(b + S.BattlePokemon.moves + (k - 1) * 2, m.moves[k])
    F.w8(b + S.BattlePokemon.pp + (k - 1), m.pp[k])
  end
  F.w16(b + S.BattlePokemon.hp, m.hp)
  F.w8(b + S.BattlePokemon.hp + 2, m.level)
  F.w16(b + S.BattlePokemon.maxHP, m.maxHP)
end

-- Debug battle -> seed party + level-up bits -> force the win -> mash until the field is back.
local function battleEvolve(tag, party, bits, opts)
  if not startDebugBattle(tag) then return nil end
  writeParty(party)
  syncBattler()
  F.w8(S.gLeveledUpInBattle, bits)
  F.w8(S.gTriedEvolving, 0)
  -- Optionally arm the post-battle "Your team grew stronger!" box too (LevelUpSummary.lua), so
  -- the box and the evolution scene that follows it are mashed through as one flow.
  for slot, from in pairs(opts and opts.startLevels or {}) do F.w8(S.gLevelUpStartLevels + slot, from) end
  dumpParty(tag .. " armed")
  F.w8(S.gBattleOutcome, opts and opts.outcome or B_OUTCOME_WON)
  return mashThrough(tag, opts)
end

-- The follower is the first non-Egg party member (GetFirstLiveMon). After an evolution its
-- object must show the evolved species, not the one it had before the scene.
local function followerSpecies()
  for i = 0, 15 do
    local b = S.gObjectEvents + i * S.ObjectEvent.stride
    if (F.r8(b) & 1) == 1 and F.r8(b + S.ObjectEvent.localId) == 0xFE then
      return F.r16(b + S.ObjectEvent.graphicsId) & 0x0FFF
    end
  end
  return nil
end
local function leadSpecies()
  for i = 0, F.r8(S.gPartiesCount) - 1 do
    local m = decode(slotAddr(i))
    if not m.egg and m.hp > 0 then return m.species end
  end
  return nil
end

local function scenario(tag, body)
  if ONLY and not tag:find(ONLY, 1, true) then return end
  F.L(string.format("== %s == seed=%d", tag, seed))
  instantText()
  local r = body()
  if r == "skip" then return end
  local ok, how = recover(tag)
  if not ok then
    F.shot(tag:gsub("%W", "_") .. "_stuck")
    local v0 = F.r32(S.gMain + 0x20)
    F.idle(30)
    local tl = {}
    for i = 0, S.Task.count - 1 do
      local a = S.gTasks + i * S.Task.stride
      if F.r8(a + S.Task.isActive) ~= 0 then tl[#tl + 1] = string.format("%08X", F.r32(a + S.Task.func)) end
    end
    F.L(string.format("  stuck: cb2=%08X main.state=%d vblank %d->%d tasks=[%s] bagExit=%08X saved=%08X fade=%08X",
      F.cb2(), F.r8(S.gMain + 0x438), v0, F.r32(S.gMain + 0x20), table.concat(tl, ","),
      F.r32(S.gBagPosition), F.r32(S.gMain + 8), F.r32(S.gPaletteFade or 0)))
    local last, seq = -1, {}
    for _ = 1, 240 do
      if F.cb2() ~= last then last = F.cb2(); seq[#seq + 1] = string.format("%08X", last) end
      if #seq < 20 and _ % 60 == 1 then joypad.set({ B = true }) else joypad.set({}) end
      emu.frameadvance()
    end
    F.L("  stuck cb2 sequence under B: " .. table.concat(seq, " "))
  end
  F.check(tag .. ": control returns to a walkable field", ok, how)
  local fs, ls = followerSpecies(), leadSpecies()
  F.check(tag .. ": the follower shows the party lead's current species", fs == ls,
    string.format("follower=%s lead=%s", tostring(fs), tostring(ls)))
  local pc, pcWhy = partyConsistent()
  F.check(tag .. ": the party is consistent afterwards", pc, pcWhy)
  dumpParty(tag .. " after")
end

local function sceneChecks(tag, r, wantScenes)
  F.check(tag .. ": the evolution scene ran", r ~= nil and r.scenes >= 1,
    r and ("scenes=" .. r.scenes) or "battle never started")
  if not r then return false end
  F.check(tag .. ": no crash screen", not r.crash, "frames=" .. r.frames)
  F.check(tag .. ": the scene ended and the field came back", r.ended and F.ow(),
    string.format("ended=%s cb2=%08X", tostring(r.ended), F.cb2()))
  if wantScenes then
    F.check(tag .. ": exactly " .. wantScenes .. " evolution scene(s) ran", r.scenes == wantScenes,
      "scenes=" .. r.scenes)
  end
  return true
end

local function speciesAt(i)
  local a = slotAddr(i)
  if blank(a) then return 0 end
  return decode(a).species
end

-- ---- bag UI -------------------------------------------------------------------------------------
local function waitBagRun(frames)
  for _ = 1, frames or 300 do
    if F.cb2() == (S.CB2_BagMenuRun & ~1) then return true end
    F.idle(2)
  end
  return false
end
-- Open the bag on the Items pocket with the cursor on its first row (gBagPosition: pocket at +5,
-- cursorPosition[] at +8, scrollPosition[] at +8 + 2 * POCKETS_COUNT).
local function openBagOnFirstItem()
  F.w8(S.gBagPosition + 5, POCKET_ITEMS)
  F.w16(S.gBagPosition + 8 + POCKET_ITEMS * 2, 0)
  F.w16(S.gBagPosition + 18 + POCKET_ITEMS * 2, 0)
  F.press("Start", 2); F.idle(60)
  if not F.selectStartIcon(USM_ICO_BAG) then return false end
  F.press("A", 2)
  return waitBagRun()
end

-- Make a party slot an Egg the way SetMonData(MON_DATA_IS_EGG) does: the substruct bit and the
-- header bit both.
local function makeEgg(i)
  local a = slotAddr(i)
  local m = decode(a)
  m.words[m.o[3] + 1] = m.words[m.o[3] + 1] | (1 << 30)
  encode(a, m)
  F.w8(a + 19, F.r8(a + 19) | 4)
end

-- ---- save / soft reset (SaveResetStress.lua's drive) --------------------------------------------
local SAVE_SENTINEL = 0xFFFF
local function saveGame()
  F.w16(S.gSaveAttemptStatus, SAVE_SENTINEL)
  F.press("Start", 2); F.idle(60)
  if not F.selectStartIcon(USM_ICO_SAVE) then return false end
  for i = 1, 3000 do
    if F.r16(S.gSaveAttemptStatus) ~= SAVE_SENTINEL then
      F.idle(30)
      for _ = 1, 6 do F.press("B", 2); F.idle(20) end
      return F.r16(S.gSaveAttemptStatus) == 1
    end
    if i % 20 == 1 then joypad.set({ A = true }) else joypad.set({}) end
    emu.frameadvance()
  end
  return false
end

local function softReset()
  for _ = 1, 8 do joypad.set({ A = true, B = true, Start = true, Select = true }); emu.frameadvance() end
  joypad.set({})
end

-- ---- main ---------------------------------------------------------------------------------------
F.run(function()
  if not F.boot(HUB_GROUP) then F.check("boot to the hub", false); F.finish(); return end
  instantText()

  local made = true
  for _, t in ipairs({
    { "bulba16", SPECIES.BULBASAUR, 16 }, { "char16", SPECIES.CHARMANDER, 16 },
    { "squirt16", SPECIES.SQUIRTLE, 16 }, { "ivy32", SPECIES.IVYSAUR, 32 },
    { "ninc20", SPECIES.NINCADA, 20 }, { "pika20", SPECIES.PIKACHU, 20 },
    { "bulba15", SPECIES.BULBASAUR, 15 }, { "ivy31", SPECIES.IVYSAUR, 31 },
    { "ninc19", SPECIES.NINCADA, 19 },
  }) do
    made = makeTemplate(t[1], t[2], t[3]) and made
  end
  zeroParty()
  F.check("the debug Give menu built every template at its level", made)
  if not made then F.finish(); return end

  -- Filler that never evolves on level-up (Pikachu evolves by stone only).
  local filler = templates.pika20

  -- 1. Level-up evolution, mashing everything except a lone B.
  scenario("level-up evolution mashed", function()
    local r = battleEvolve("mash", { templates.bulba16, filler }, 0x01)
    if sceneChecks("level-up evolution mashed", r, 1) then
      F.check("level-up evolution mashed: Bulbasaur became Ivysaur", speciesAt(0) == SPECIES.IVYSAUR,
        describe(0))
      F.check("level-up evolution mashed: the scene reached SET_MON_EVOLVED and never cancelled",
        r.states[EVO_SET_MON_EVOLVED] and not r.states[EVO_CANCEL], "states=" .. r.stateList)
      F.check("level-up evolution mashed: the untouched slot did not change",
        speciesAt(1) == SPECIES.PIKACHU, describe(1))
    end
  end)

  -- 2. Cancel with B held alone: the control for 1.
  scenario("B cancels the evolution", function()
    local r = battleEvolve("cancel", { templates.bulba16, filler }, 0x01, { hold = function(i) return (i % 2 == 0) and { B = true } or {} end })
    if sceneChecks("B cancels the evolution", r, 1) then
      F.check("B cancels the evolution: Bulbasaur stayed a Bulbasaur", speciesAt(0) == SPECIES.BULBASAUR,
        describe(0))
      F.check("B cancels the evolution: the scene took the CANCEL branch",
        r.states[EVO_CANCEL] == true, "states=" .. r.stateList)
      F.check("B cancels the evolution: level and EXP untouched",
        decode(slotAddr(0)).level == 16, describe(0))
    end
  end)

  -- 3. Evolution move into a full moveset: Ivysaur 32 -> Venusaur learns Petal Blizzard.
  for k, variant in ipairs({ { "mashed", nil }, { "B declines", { A = 10, B = 60, dir = 20 } } }) do
    local tag = "forget-move prompt " .. variant[1]
    scenario(tag, function()
      local r = battleEvolve("learn" .. k, { templates.ivy32, filler }, 0x01, { w = variant[2] })
      if sceneChecks(tag, r, 1) then
        local m = decode(slotAddr(0))
        F.check(tag .. ": Ivysaur became Venusaur", m.species == SPECIES.VENUSAUR, describe(0))
        F.check(tag .. ": the forget-move prompt was reached", r.states[EVO_REPLACE_MOVE] == true,
          "states=" .. r.stateList)
        local ok, why = movesetSane(m)
        F.check(tag .. ": the moveset is unique with sane PP", ok, why .. " " .. describe(0))
        -- Every move is either one Ivysaur already knew or the one it was offered: nothing foreign
        -- grafted in, and declining leaves the old four exactly.
        local known, foreign, slot = {}, 0, nil
        for _, mv in ipairs(templateMoves.ivy32) do known[mv] = true end
        for s = 1, 4 do
          if m.moves[s] == MOVE_PETAL_BLIZZARD then slot = s
          elseif not known[m.moves[s]] then foreign = foreign + 1 end
        end
        F.check(tag .. ": every move is an old move or the offered one", foreign == 0, describe(0))
        if slot then
          F.check(tag .. ": the learned move has its base PP and no inherited PP bonus",
            m.pp[slot] == PETAL_BLIZZARD_PP and ((m.ppBonuses >> ((slot - 1) * 2)) & 3) == 0,
            describe(0))
        else
          F.check(tag .. ": declining kept the old moveset intact", m.moves[4] ~= 0, describe(0))
        end
      end
    end)
  end

  -- 4. Nincada -> Ninjask + Shedinja.
  local function nincada(tag, fillers, balls, wantCount, wantShedinja)
    scenario(tag, function()
      local list = { templates.ninc20 }
      for _ = 1, fillers do list[#list + 1] = filler end
      setPocket(POCKET_BALLS, ITEM_POKE_BALL, balls)
      local ballsBefore = countItem(ITEM_POKE_BALL)
      local r = battleEvolve(tag, list, 0x01)
      if sceneChecks(tag, r, 1) then
        local n = F.r8(S.gPartiesCount)
        F.check(tag .. ": Nincada became Ninjask", speciesAt(0) == SPECIES.NINJASK, describe(0))
        F.check(tag .. ": party count is " .. wantCount, n == wantCount, "count=" .. n)
        local shed = 0
        for i = 0, PARTY_SIZE - 1 do if speciesAt(i) == SPECIES.SHEDINJA then shed = shed + 1 end end
        F.check(tag .. ": Shedinja " .. (wantShedinja and "joined once" or "did not appear"),
          shed == (wantShedinja and 1 or 0), "shedinja=" .. shed)
        local fillOk = true
        for i = 1, fillers do if speciesAt(i) ~= SPECIES.PIKACHU then fillOk = false end end
        F.check(tag .. ": the other party members are untouched", fillOk)
        local spent = ballsBefore - countItem(ITEM_POKE_BALL)
        F.check(tag .. ": Poke Balls spent = " .. (wantShedinja and 1 or 0),
          spent == (wantShedinja and 1 or 0), string.format("before=%d after=%d", ballsBefore, countItem(ITEM_POKE_BALL)))
        if wantShedinja then
          local sm = decode(slotAddr(n - 1))
          F.check(tag .. ": Shedinja is a sound party member", sm.checksumOk and not sm.egg and sm.hp > 0
            and sm.maxHP > 0 and sm.level == 20, describe(n - 1))
        end
      end
      setPocket(POCKET_BALLS, ITEM_POKE_BALL, 0)
    end)
  end
  nincada("Shedinja with a full party", 5, 5, 6, false)
  nincada("Shedinja with five and a ball", 4, 5, 6, true)
  nincada("Shedinja with five and no ball", 4, 0, 5, false)

  -- 5. Three evolutions back to back after one battle, behind the level-up summary box.
  scenario("three evolutions back to back", function()
    local r = battleEvolve("chain", { templates.bulba16, filler, templates.char16, templates.squirt16 }, 0x0D,
      { minScenes = 3, startLevels = { [0] = 15, [2] = 15, [3] = 15 } })
    F.check("three evolutions back to back: the level-up summary box came up first", r ~= nil and r.box == true)
    if sceneChecks("three evolutions back to back", r, 3) then
      F.check("three evolutions back to back: every armed slot evolved",
        speciesAt(0) == SPECIES.IVYSAUR and speciesAt(2) == SPECIES.CHARMELEON and speciesAt(3) == SPECIES.WARTORTLE,
        string.format("%d %d %d", speciesAt(0), speciesAt(2), speciesAt(3)))
      F.check("three evolutions back to back: the unarmed slot did not change",
        speciesAt(1) == SPECIES.PIKACHU, describe(1))
      F.check("three evolutions back to back: count unchanged", F.r8(S.gPartiesCount) == 4,
        "count=" .. F.r8(S.gPartiesCount))
    end
  end)

  -- 5b. The same chain mashed with B allowed on its own, as a real player would: any of the three
  -- may be cancelled, but every armed slot must end as exactly its old or its new species.
  scenario("three evolutions with lone B in the mash", function()
    local tag = "three evolutions with lone B in the mash"
    local r = battleEvolve("chainB", { templates.bulba16, filler, templates.char16, templates.squirt16 }, 0x0D,
      { minScenes = 3, allowLoneB = true })
    if sceneChecks(tag, r, 3) then
      local function either(i, a, b) local sp = speciesAt(i); return sp == a or sp == b end
      F.check(tag .. ": each armed slot is its old or its new species",
        either(0, SPECIES.BULBASAUR, SPECIES.IVYSAUR) and either(2, SPECIES.CHARMANDER, SPECIES.CHARMELEON)
          and either(3, SPECIES.SQUIRTLE, SPECIES.WARTORTLE),
        string.format("%d %d %d", speciesAt(0), speciesAt(2), speciesAt(3)))
      F.check(tag .. ": the unarmed slot did not change", speciesAt(1) == SPECIES.PIKACHU, describe(1))
    end
  end)

  -- 5c. Lost battle: Gen 6+ evolves after a whiteout (B_EVOLUTION_AFTER_WHITEOUT), then the
  -- whiteout itself must still run and hand back the field.
  scenario("evolution then whiteout", function()
    local tag = "evolution then whiteout"
    local r = battleEvolve("whiteout", { templates.bulba16, filler }, 0x01, { outcome = 2 })
    if sceneChecks(tag, r, 1) then
      F.check(tag .. ": Bulbasaur became Ivysaur before the whiteout", speciesAt(0) == SPECIES.IVYSAUR, describe(0))
    end
  end)
  -- The whiteout lands on the last heal location; the bag scenarios want the hub's open floor.
  if F.grp() ~= HUB_GROUP then F.warpTo(1, 0, 0, 0, 0, 0, 0, 0, 0, HUB_GROUP, 0, "hub") end

  -- 6. Thunder Stone from the bag, with an Egg Pikachu in front of a real Pikachu.
  scenario("stone evolution from the bag", function()
    local tag = "stone evolution from the bag"
    writeParty({ templates.pika20, templates.pika20 })
    makeEgg(0)
    setPocket(POCKET_ITEMS, ITEM_THUNDER_STONE, 3)
    local e0 = decode(slotAddr(0))
    F.check(tag .. ": slot 0 is an Egg Pikachu before the stone", e0.egg and e0.headerEgg and e0.checksumOk
      and e0.species == SPECIES.PIKACHU, describe(0))
    if not openBagOnFirstItem() then F.check(tag .. ": the bag opened", false); return end
    F.idle(30)
    F.press("A", 2); F.idle(40)           -- the item's action menu (Use is the first entry)
    F.press("A", 2); F.idle(60)           -- Use: party select opens on slot 0
    F.shot("stone_party_select")
    F.check(tag .. ": the bag armed an evolution-stone use",
      (F.r32(S.gItemUseCB) & ~1) == (S.ItemUseCB_EvolutionStone & ~1) and F.r16(S.gSpecialVar_ItemId) == ITEM_THUNDER_STONE,
      string.format("cb=%08X item=%d", F.r32(S.gItemUseCB), F.r16(S.gSpecialVar_ItemId)))
    -- A on the Egg, repeatedly: refused every time, nothing spent, no scene.
    local eggScene = false
    for _ = 1, 6 do
      F.press("A", 2)
      for _ = 1, 30 do F.idle(1); if F.r32(S.sEvoStructPtr) ~= 0 or not inBag() then eggScene = true end end
    end
    F.check(tag .. ": A on the Egg starts no evolution", not eggScene and inBag(),
      string.format("cb2=%08X evo=%08X", F.cb2(), F.r32(S.sEvoStructPtr)))
    F.check(tag .. ": A on the Egg spends no stone", countItem(ITEM_THUNDER_STONE) == 3,
      "stones=" .. countItem(ITEM_THUNDER_STONE))
    -- Down to the Pikachu and use it, then mash from the confirming A onward.
    F.press("Down", 2); F.idle(20)
    F.press("A", 2)
    local r = mashThrough("stone", { frames = 4000, onFrame = function(_, rr)
      return rr.scenes >= 1 and F.r32(S.sEvoStructPtr) == 0 and inBag()
    end })
    F.check(tag .. ": the evolution scene ran", r.scenes == 1, "scenes=" .. r.scenes)
    F.check(tag .. ": no crash screen", not r.crash)
    F.check(tag .. ": the scene ended back in the bag", r.stopped == true,
      string.format("cb2=%08X", F.cb2()))
    F.check(tag .. ": the Pikachu became a Raichu", speciesAt(1) == SPECIES.RAICHU, describe(1))
    -- Keep mashing in the re-entered party select: the Egg must stay refused.
    local r2 = mashThrough("stone_reentry", { frames = 1500, onFrame = function() return false end,
      w = { A = 50, B = 0, Start = 0, Select = 0, dir = 50 } })
    F.check(tag .. ": mashing the re-entered party select starts no second scene", r2.scenes == 0,
      "scenes=" .. r2.scenes)
    local e1 = decode(slotAddr(0))
    F.check(tag .. ": the Egg never evolved", e1.egg and e1.species == SPECIES.PIKACHU and e1.checksumOk,
      describe(0))
    F.check(tag .. ": exactly one stone was spent", countItem(ITEM_THUNDER_STONE) == 2,
      "stones=" .. countItem(ITEM_THUNDER_STONE))
  end)

  -- 6b. Rare Candies from the bag: a multi-use that crosses a move prompt and then evolves, and a
  -- single candy whose evolution opens the forget-move summary from inside a bag-started scene.
  -- The Nincada row adds Shedinja as a sixth member while the bag is the screen to return to,
  -- so the re-entered party panel is rebuilt for a party that grew under it.
  for _, v in ipairs({ { "three Rare Candies through a move prompt", "bulba15", 3, SPECIES.IVYSAUR, 18, 1 },
                       { "Rare Candy into an evolution-move prompt", "ivy31", 1, SPECIES.VENUSAUR, 32, 1 },
                       { "Rare Candy Nincada adds Shedinja under the bag", "ninc19", 1, SPECIES.NINJASK, 20, 4 } }) do
    local tag, tpl, uses, want, wantLevel, fillers = v[1], v[2], v[3], v[4], v[5], v[6]
    scenario(tag, function()
      local list = { templates[tpl] }
      for _ = 1, fillers do list[#list + 1] = filler end
      writeParty(list)
      setPocket(POCKET_BALLS, ITEM_POKE_BALL, 1)
      setPocket(POCKET_ITEMS, ITEM_RARE_CANDY, 5)
      if not openBagOnFirstItem() then F.check(tag .. ": the bag opened", false); return end
      F.idle(30)
      F.press("A", 2); F.idle(40)           -- action menu
      F.press("A", 2); F.idle(60)           -- Use: party select on slot 0
      F.press("A", 2); F.idle(60)           -- slot 0: "Use how many?" (5 candies in the bag)
      for _ = 2, uses do F.press("Up", 2); F.idle(12) end
      F.shot(tpl .. "_candy_count")
      F.press("A", 2)                       -- confirm the count, then mash everything after it
      local r = mashThrough("candy_" .. tpl, { frames = 9000, onFrame = function(_, rr)
        return rr.scenes >= 1 and F.r32(S.sEvoStructPtr) == 0 and inBag()
      end })
      F.check(tag .. ": the evolution scene ran once", r.scenes == 1, "scenes=" .. r.scenes)
      if want == SPECIES.VENUSAUR then
        F.check(tag .. ": the forget-move prompt was reached inside the bag-started scene",
          r.states[EVO_REPLACE_MOVE] == true, "states=" .. r.stateList)
      end
      F.check(tag .. ": no crash screen", not r.crash)
      F.check(tag .. ": the scene ended back in the bag", r.stopped == true, string.format("cb2=%08X", F.cb2()))
      for _ = 1, 8 do F.press("B", 2); F.idle(20) end
      local m = decode(slotAddr(0))
      F.check(tag .. ": evolved to species " .. want .. " at level " .. wantLevel,
        m.species == want and m.level == wantLevel, describe(0))
      local ok, why = movesetSane(m)
      F.check(tag .. ": the moveset is unique with sane PP", ok, why .. " " .. describe(0))
      F.check(tag .. ": exactly " .. uses .. " candies spent", countItem(ITEM_RARE_CANDY) == 5 - uses,
        "candies=" .. countItem(ITEM_RARE_CANDY))
      if want == SPECIES.NINJASK then
        F.check(tag .. ": Shedinja joined as the sixth member and took the ball",
          F.r8(S.gPartiesCount) == 6 and speciesAt(5) == SPECIES.SHEDINJA and countItem(ITEM_POKE_BALL) == 0,
          string.format("count=%d slot5=%d balls=%d", F.r8(S.gPartiesCount), speciesAt(5), countItem(ITEM_POKE_BALL)))
      end
      setPocket(POCKET_BALLS, ITEM_POKE_BALL, 0)
    end)
  end

  -- 7. Soft reset in the middle of the scene, then Continue.
  scenario("soft reset mid-scene", function()
    local tag = "soft reset mid-scene"
    writeParty({ templates.bulba16, filler })
    F.w8(S.gPartiesCount, 2)
    local saved = { readSlot(0), readSlot(1) }
    local savedGroup = F.grp()
    F.check(tag .. ": the game saved", saveGame())
    local r = battleEvolve("reset", { templates.bulba16, filler }, 0x01, {
      onFrame = function(_, rr)
        local t = evoTask()
        if t and F.r16(t + S.Task.data) == 8 then softReset(); return true end
        return false
      end })
    F.check(tag .. ": the reset landed inside the scene", r ~= nil and r.stopped == true and r.scenes == 1,
      r and ("scenes=" .. r.scenes) or "battle never started")
    F.idle(60)
    local ok = F.boot(savedGroup)
    F.check(tag .. ": Continue reloads the saved game", ok)
    if not ok then return end
    instantText()
    local n = F.r8(S.gPartiesCount)
    local same = n == 2
    for i = 0, 1 do
      local now = readSlot(i)
      for off = 1, 80 do if now[off] ~= saved[i + 1][off] then same = false end end
    end
    F.check(tag .. ": the saved party loaded byte for byte", same, "count=" .. n)
    F.check(tag .. ": the reset kept the pre-evolution species", speciesAt(0) == SPECIES.BULBASAUR, describe(0))
    F.check(tag .. ": no evolution scene is left behind", F.r32(S.sEvoStructPtr) == 0 and F.ow(),
      string.format("evo=%08X cb2=%08X", F.r32(S.sEvoStructPtr), F.cb2()))
  end)

  F.finish()
end)
