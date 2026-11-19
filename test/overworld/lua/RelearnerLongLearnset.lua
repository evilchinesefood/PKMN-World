-- The Move Relearner must list every level-up move of the longest learnsets, scroll to both ends
-- and teach the last one into a full moveset.
--
-- MAX_LEVEL_UP_MOVES caps how far GetRelearnerLevelUpMoves walks a learnset. It was 20, which hid
-- the tail of 33 enabled species' learnsets; Gallade's 33 moves are the longest. At level 100 with
-- the default moveset (Heal Pulse, Wide Guard, Quick Guard, Close Combat) Gallade has 29 moves to
-- relearn, ending in Swords Dance and Psycho Cut; Zangoose at 50 has 24 of its 28.
--
-- Each case gives the Pokemon (createmon, default moveset), warps into the Fallarbor relearner's
-- house with Heart Scales in the bag and drives the real script with input: talk, YES, pick the lead
-- in the chooser. On the list the suite reads sMoveRelearnerStruct and requires exactly the expected
-- moves in learnset order plus Cancel; drives the cursor to Cancel and back to the top; mashes the
-- list with a seeded mix of B, L, R, Select and the D-pad (no A, so nothing is taught and B only
-- reaches the give-up question, where B is No); then picks the last move, answers YES, chooses the
-- first move to forget and presses A through to the end. The first move slot must hold the taught
-- move at full PP, the other three must be unchanged, one Heart Scale must be spent, control must
-- return and no crash screen may appear.
--
-- Run via test/overworld/mgba-run.sh test/overworld/lua/RelearnerLongLearnset.lua <rom>
-- PW_RELEARN_ONLY=<text> runs matching cases, PW_RELEARN_SEED=<n> reseeds the mash.

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "RelearnerLongLearnset")

local HUB = 100
local ONLY = os.getenv("PW_RELEARN_ONLY")
local BASE = tonumber(os.getenv("PW_RELEARN_SEED") or "") or 0x7E1E
local MON = S.Pokemon.size
local REGION_HOENN = 3
local ITEM_HEART_SCALE = 152
local FALLARBOR_RELEARNER_GROUP, FALLARBOR_RELEARNER_MAP = 5, 5
local CONTEXT_RUNNING = 0
local LIST_CANCEL = 0xFFFFFFFE

local SPECIES_GALLADE, SPECIES_ZANGOOSE = 475, 335

-- Learnset order (src/data/pokemon/level_up_learnsets/gen_9.h) minus the default moveset.
local CASES = {
  {
    tag = "Gallade 100", species = SPECIES_GALLADE, level = 100,
    known = { 505, 469, 501, 370 },
    list = { 163, 400, 286, 719, 248, 210, 533, 204, 574, 347, 348, 104, 577, 95, 94, 93, 60, 45, 43, 138,
             821, 270, 364, 100, 332, 206, 182, 14, 427 },
    lastPP = 20,
  },
  {
    tag = "Zangoose 50", species = SPECIES_ZANGOOSE, level = 50,
    known = { 404, 269, 14, 370 },
    list = { 24, 50, 68, 154, 174, 175, 187, 364, 400, 458, 501, 515, 10, 43, 98, 210, 232, 468, 163, 644,
             306, 206, 415, 197 },
    lastPP = 5,
  },
}

local seed = BASE
local function rnd()
  seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF
  return seed >> 8
end
local function seedFor(tag)
  local h = BASE & 0x7FFFFFFF
  for i = 1, #tag do h = ((h ~ tag:byte(i)) * 16777619) & 0x7FFFFFFF end
  return h
end

local function d(n) return (n // 100) % 10, (n // 10) % 10, n % 10 end

local CONTEXT_SHUTDOWN = 2
local function hasControl()
  return F.ow() and F.r8(S.sLockFieldControls) == 0 and F.r8(S.sGlobalScriptContextStatus) ~= CONTEXT_RUNNING
end
local function freeOnField()
  return F.ow() and F.r8(S.sLockFieldControls) == 0 and F.r8(S.sGlobalScriptContextStatus) == CONTEXT_SHUTDOWN
end

local SCRIPT_BUF = S.gStringVar4 + 960
local function runScript(bytes)
  for i, b in ipairs(bytes) do F.w8(SCRIPT_BUF + i - 1, b) end
  F.w8(S.sGlobalScriptContext, 0)
  F.w8(S.sGlobalScriptContext + 1, 1)
  F.w32(S.sGlobalScriptContext + 4, 0)
  F.w32(S.sGlobalScriptContext + S.ScriptCtx.scriptPtr, SCRIPT_BUF)
  F.w8(S.sGlobalScriptContextStatus, CONTEXT_RUNNING)
  for _ = 1, 200 do F.idle(4); if hasControl() then break end end
  F.idle(30)
end
local function le16(t, v) t[#t + 1] = v & 0xFF; t[#t + 1] = (v >> 8) & 0xFF end
local function le32(t, v) le16(t, v & 0xFFFF); le16(t, (v >> 16) & 0xFFFF) end
local function addItem(id, n) local b = { 0x44 }; le16(b, id); le16(b, n); b[#b + 1] = 0x02; runScript(b) end
-- createmon with no optional fields: the species' default level-up moveset.
local function createMon(species, level)
  local b = { 0x23 }; le32(b, S.ScrCmd_createmon | 1)
  b[#b + 1] = 0; b[#b + 1] = 6
  le16(b, species); le16(b, level); le32(b, 0)
  b[#b + 1] = 0x02
  runScript(b)
end

local function clearParty()
  for off = 0, 6 * MON - 4, 4 do F.w32(S.gParties + off, 0) end
  F.w8(S.gPartiesCount, 0)
end

local function order(p)
  local o = {}
  for i = 0, 3 do o[i] = F.r8(S.sSubstructOffsets + i * 24 + p % 24) * 3 end
  return o
end
local function decode(a)
  local key = F.r32(a) ~ F.r32(a + 4)
  local w = {}
  for i = 0, 11 do w[i] = F.r32(a + 32 + i * 4) ~ key end
  local sum = 0
  for i = 0, 11 do sum = sum + (w[i] & 0xFFFF) + (w[i] >> 16) end
  local o = order(F.r32(a))
  local s1 = o[1]
  return {
    species = w[o[0]] & 0x7FF,
    moves = { w[s1] & 0x7FF, (w[s1] >> 16) & 0x7FF, w[s1 + 1] & 0x7FF, (w[s1 + 1] >> 16) & 0x7FF },
    pp = { w[s1 + 2] & 0x7F, (w[s1 + 2] >> 8) & 0x7F, (w[s1 + 2] >> 16) & 0x7F, (w[s1 + 2] >> 24) & 0x7F },
    sum = (sum & 0xFFFF) == F.r16(a + 28),
    level = F.r8(a + S.Pokemon.level),
  }
end
local function describe(m)
  return string.format("sp=%d lv=%d moves=%d,%d,%d,%d pp=%d,%d,%d,%d sum=%s", m.species, m.level,
    m.moves[1], m.moves[2], m.moves[3], m.moves[4], m.pp[1], m.pp[2], m.pp[3], m.pp[4], m.sum and "ok" or "BAD")
end

local function warpToCoords(grp, map, x, y, tag)
  for _ = 1, 4 do
    F.dbg(); F.sel(0); F.sel(1); F.idle(20)
    F.spin(d(grp)); F.spin(d(map))
    F.press("A", 2)
    for _ = 1, 400 do
      F.w8(S.sWarpDestination + 2, 0xFF)
      F.w16(S.sWarpDestination + 4, x)
      F.w16(S.sWarpDestination + 6, y)
      F.idle(1)
      local px, py = F.pos()
      if F.ow() and F.grp() == grp and F.mapn() == map and px == x and py == y then
        F.idle(120)
        return true
      end
    end
    F.bOut(5)
  end
  F.shot(tag .. "_warpfail")
  return false
end

-- gStringVar4 as uppercase ASCII; Gen 3 A = 0xBB, a = 0xD5.
local function message()
  local s = {}
  for i = 0, 200 do
    local c = F.r8(S.gStringVar4 + i)
    if c == 0xFF then break end
    if c >= 0xBB and c <= 0xD4 then s[#s + 1] = string.char(65 + c - 0xBB)
    elseif c >= 0xD5 and c <= 0xEE then s[#s + 1] = string.char(65 + c - 0xD5)
    else s[#s + 1] = " " end
  end
  return table.concat(s)
end

local function yesNoUp()
  for i = 0, S.Task.count - 1 do
    local a = S.gTasks + i * S.Task.stride
    local fn = F.r32(a + S.Task.func) & 0xFFFFFFFE
    if F.r8(a + S.Task.isActive) ~= 0 and (fn == S.Task_HandleYesNoInput or fn == S.Task_HandleMultichoiceInput) then return true end
  end
  return false
end

local function waitFor(pred, frames)
  for _ = 1, frames // 5 do if pred() then return true end; F.idle(5) end
  return pred()
end

local function relearner() return F.r32(S.sMoveRelearnerStruct) end
local function inRelearner()
  local p = relearner()
  return F.cb2() == (S.CB2_MoveRelearnerMain & ~1) and p >= 0x02000000 and p < 0x02040000
end
local function listCount() return F.r8(relearner() + S.MoveRelearner.numMenuChoices) end
local function listMoves()
  local t = {}
  for k = 0, listCount() - 2 do t[#t + 1] = F.r16(relearner() + S.MoveRelearner.movesToLearn + k * 2) end
  return t
end
local function lastItemId()
  return F.r32(relearner() + S.MoveRelearner.menuItems + (listCount() - 1) * S.MoveRelearner.menuItemStride + 4)
end
local function cursor() return F.r16(S.sMoveRelearnerScrollState) + F.r16(S.sMoveRelearnerScrollState + 2) end
local function onList() return inRelearner() and message():find("TEACH WHICH") ~= nil end

local function steer(target, tag)
  for _ = 1, 80 do
    local c = cursor()
    if c == target then return true end
    F.press(c < target and "Down" or "Up", 2); F.idle(8)
    if F.reportCrash(tag) then return false end
  end
  return cursor() == target
end

local function mashList(tag, frames)
  local keys = { "B", "L", "R", "Select", "Up", "Down", "Left", "Right" }
  for i = 1, frames do
    if i % 20 == 0 and F.reportCrash(tag) then return false end
    local t = {}
    if i % 3 == 0 then t[keys[rnd() % #keys + 1]] = true end
    joypad.set(t)
    emu.frameadvance()
  end
  joypad.set({})
  -- A B from the mash may have opened the give-up question; B answers No.
  for _ = 1, 12 do
    if onList() then break end
    F.press("B", 2); F.idle(40)
  end
  F.idle(60)
  return true
end

local function openList(c)
  clearParty()
  createMon(c.species, c.level)
  F.w8(F.sb2() + S.SaveBlock2.currentRegion, REGION_HOENN)
  F.w32(S.gCurrentRegion, REGION_HOENN)
  if not warpToCoords(FALLARBOR_RELEARNER_GROUP, FALLARBOR_RELEARNER_MAP, 4, 5, "house") then return false end
  F.face("Up"); F.press("A", 2); F.idle(30)
  local chooser = false
  for _ = 1, 300 do
    if not F.ow() then chooser = true; break end
    if yesNoUp() then F.idle(16) end
    F.press("A", 2); F.idle(14)
  end
  if not chooser then return false end
  F.idle(90)
  for _, k in ipairs({ "Left", "Up", "A", "A" }) do F.press(k, 2); F.idle(45) end
  waitFor(F.ow, 400)
  for _ = 1, 60 do
    if not F.ow() then break end
    F.press("A", 2); F.idle(20)
  end
  return waitFor(onList, 600)
end

local function runCase(c)
  local tag = c.tag
  if ONLY and not tag:find(ONLY, 1, true) then return end
  seed = seedFor(tag)
  F.L(string.format("== %s == seed=%d", tag, seed))
  local scales0 = F.itemCount(ITEM_HEART_SCALE)

  local opened = openList(c)
  F.idle(60)
  F.shot(tag:gsub("%W", "_") .. "_list")
  if not F.check(tag .. ": the relearner opens on its move list", opened, string.format("cb2=%08X msg=%s", F.cb2(), message())) then
    return
  end
  local before = decode(S.gParties)
  F.L("  " .. describe(before))
  local knownOk = true
  for k = 1, 4 do knownOk = knownOk and before.moves[k] == c.known[k] end
  F.check(tag .. ": the default moveset is the last four level-up moves", knownOk, describe(before))

  local got = listMoves()
  F.L(string.format("  list (%d + Cancel): %s", #got, table.concat(got, ",")))
  local same = #got == #c.list
  for k = 1, math.min(#got, #c.list) do same = same and got[k] == c.list[k] end
  F.check(string.format("%s: lists all %d relearnable moves in learnset order, then Cancel", tag, #c.list),
    same and lastItemId() == LIST_CANCEL, string.format("count=%d last id=%08X", #got, lastItemId()))

  local n = listCount()
  local reachedEnd = steer(n - 1, tag)
  F.idle(30)
  F.shot(tag:gsub("%W", "_") .. "_end")
  local reachedTop = steer(0, tag)
  F.idle(30)
  F.check(tag .. ": the cursor reaches Cancel at the end and comes back to the top", reachedEnd and reachedTop and onList(),
    string.format("cursor=%d n=%d", cursor(), n))

  mashList(tag, 900)
  F.shot(tag:gsub("%W", "_") .. "_mash")
  local afterMash = decode(S.gParties)
  F.check(tag .. ": after the mash the relearner is still on its list, nothing taught", onList() and not F.crashScreen()
    and describe(afterMash) == describe(before) and F.itemCount(ITEM_HEART_SCALE) == scales0,
    string.format("onList=%s %s", tostring(onList()), describe(afterMash)))

  local lastMove = c.list[#c.list]
  local steered = steer(n - 2, tag)
  F.check(tag .. ": the cursor rests on the last move", steered and listMoves()[cursor() + 1] == lastMove,
    string.format("cursor=%d move=%d", cursor(), listMoves()[cursor() + 1] or -1))
  -- A teaches: "Teach X?" YES, "Delete an older move?" YES, the summary opens on the first move, A
  -- picks it, and A runs the rest of the text until the script hands control back.
  -- A stops once the field is back (A there would talk to the relearner again); B closes her text.
  local taught = false
  for i = 1, 4000 do
    if i > 200 and F.ow() then break end
    if i % 40 == 0 and F.reportCrash(tag) then break end
    joypad.set((i % 24 < 2) and { A = true } or {})
    emu.frameadvance()
  end
  joypad.set({})
  for _ = 1, 40 do
    if freeOnField() then taught = true; break end
    F.press("B", 2); F.idle(30)
  end
  local after = decode(S.gParties)
  F.L("  after: " .. describe(after))
  F.shot(tag:gsub("%W", "_") .. "_after")
  F.check(tag .. ": control returns after teaching", taught)
  F.check(tag .. ": the last move replaced the first slot at full PP", after.moves[1] == lastMove and after.pp[1] == c.lastPP
    and after.sum, describe(after))
  F.check(tag .. ": the other three moves are unchanged", after.moves[2] == before.moves[2] and after.moves[3] == before.moves[3]
    and after.moves[4] == before.moves[4], describe(after))
  F.check(tag .. ": one Heart Scale was spent", F.itemCount(ITEM_HEART_SCALE) == scales0 - 1 or
    (scales0 == 1 and F.itemCount(ITEM_HEART_SCALE) == 0), "slots=" .. F.itemCount(ITEM_HEART_SCALE))
  F.check(tag .. ": no crash screen", not F.crashScreen())
end

local function heartScales()
  local n = 0
  for p = 0, 4 do
    local ptr = F.r32(S.gBagPockets + p * S.BagPocket.stride)
    local cap = F.pocketCap(p)
    for s = 0, cap - 1 do
      if F.r16(ptr + s * 4) == ITEM_HEART_SCALE then
        n = n + (F.r16(ptr + s * 4 + 2) ~ (F.r32(F.sb2() + S.SaveBlock2.encryptionKey) & 0xFFFF))
      end
    end
  end
  return n
end
F.itemCount = function(id) if id == ITEM_HEART_SCALE then return heartScales() end return 0 end

F.run(function()
  if not F.boot(HUB) then F.check("boot", false); F.finish(); return end
  local a = F.sb2() + S.SaveBlock2.optionsU16
  F.w16(a, (F.r16(a) & ~7) | 3)
  addItem(ITEM_HEART_SCALE, 5)
  F.check("setup: five Heart Scales", heartScales() == 5, "n=" .. heartScales())
  for _, c in ipairs(CASES) do runCase(c) end
  F.check("no crash", not F.crashScreen())
  F.finish()
end)
