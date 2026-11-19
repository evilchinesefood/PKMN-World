-- The service NPCs that inspect and change a Pokemon, in all three regions, played with real input:
-- move tutors, Move Deleters, Move Relearners and Name Raters.
--
-- A tutor or relearner that teaches into a full moveset asks which move to forget on the summary
-- screen and must give the new move its full PP with that slot's PP Ups cleared, as Emerald's and
-- FireRed's tutors do (RemoveMonPPBonus, then SetMonMoveSlot). Hoenn's tutors resume their learning
-- task after that screen, and the resumed task lost its "recover PP" bit, so the new move kept the
-- forgotten move's PP: Fury Cutter at 16 of 20 over a boosted Psychic, Rollout at 0 of 20 over a
-- spent Metronome. The Kanto tutor and the three relearners are the controls.
--
-- A Move Deleter must shift the later moves up with their PP and PP Ups, refuse an Egg and a
-- Pokemon with one move, delete an HM (all three source games allow it), work on a Pokemon in the
-- PC, and change nothing on every cancel: NO at the offer, B in the chooser, B mashed on the move
-- list, NO at the final question. A Name Rater must store a twelve-letter nickname whole, keep the
-- name when the new one is empty, refuse an Egg, and refuse a traded Pokemon where its source game
-- does (Slateport, Lavender; pokemonHnS commented Goldenrod's check out).
--
-- Setup is debug only: Mew from the debug Give menu, its moves, PP, PP Ups, OT and nickname written
-- into the party or a PC box, items given by an additem script, a warp in front of the NPC. Every
-- flow is then driven with button presses through the real scripts and menus, at Instant text.
-- Every scenario checks the moves, PP, PP Ups, nickname, OT and checksum of each party slot, the
-- text the NPC printed, no crash, and that control comes back.
local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "ServiceNpcStress")

local MON, PARTY_SIZE = S.Pokemon.size, 6
local SPECIES_MEW = 151
local REGION_KANTO, REGION_JOHTO, REGION_HOENN = 1, 2, 3
local CONTEXT_SHUTDOWN = 2
local MOVE = { POUND = 1, MEGA_PUNCH = 5, SURF = 57, SEISMIC_TOSS = 69, PSYCHIC = 94, METRONOME = 118, ROLLOUT = 205,
  FURY_CUTTER = 210 }
local BASE_PP = { [1] = 35, [5] = 20, [57] = 15, [69] = 20, [94] = 10, [118] = 10, [205] = 20, [210] = 20, [513] = 15 }

local function instantText()
  local a = F.sb2() + S.SaveBlock2.optionsU16
  F.w16(a, (F.r16(a) & ~7) | 3)
end
local function hasControl()
  return F.ow() and F.r8(S.sLockFieldControls) == 0 and F.r8(S.sGlobalScriptContextStatus) == CONTEXT_SHUTDOWN
end
local function yesNoUp() return F.taskLive(S.Task_HandleYesNoInput) end

local function slotAddr(i) return S.gParties + i * MON end
local function order(p)
  local o = {}
  for i = 0, 3 do o[i] = F.r8(S.sSubstructOffsets + i * 24 + p % 24) * 3 end
  return o
end
local function decode(a)
  local pers, otid = F.r32(a), F.r32(a + 4)
  local key = pers ~ otid
  local w = {}
  for i = 0, 11 do w[i] = F.r32(a + 32 + i * 4) ~ key end
  local sum = 0
  for i = 0, 11 do sum = sum + (w[i] & 0xFFFF) + (w[i] >> 16) end
  local o = order(pers)
  local s0, s1, s3 = o[0], o[1], o[3]
  local nick = {}
  for i = 0, 9 do nick[#nick + 1] = F.r8(a + 8 + i) end
  nick[11] = (w[s0 + 1] >> 21) & 0xFF
  nick[12] = (w[s0 + 2] >> 22) & 0xFF
  local ot = {}
  for i = 0, 6 do ot[#ot + 1] = F.r8(a + 20 + i) end
  return {
    pers = pers, otid = otid,
    species = w[s0] & 0x7FF,
    ppBonuses = w[s0 + 2] & 0xFF,
    moves = { w[s1] & 0x7FF, (w[s1] >> 16) & 0x7FF, w[s1 + 1] & 0x7FF, (w[s1 + 1] >> 16) & 0x7FF },
    pp = { w[s1 + 2] & 0x7F, (w[s1 + 2] >> 8) & 0x7F, (w[s1 + 2] >> 16) & 0x7F, (w[s1 + 2] >> 24) & 0x7F },
    egg = ((w[s3 + 1] >> 30) & 1) == 1,
    checksumOk = (sum & 0xFFFF) == F.r16(a + 28),
    nick = table.concat(nick, ","), ot = table.concat(ot, ","),
    words = w, o = o,
  }
end
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

-- Write a moveset with PP and PP Ups (2 bits per slot) into a Pokemon, keeping the other words.
local function setMovesAt(a, moves, pp, bonuses)
  local m = decode(a)
  local s0, s1 = m.o[0], m.o[1]
  local w = m.words
  w[s1] = (w[s1] & 0xF800F800) | moves[1] | (moves[2] << 16)
  w[s1 + 1] = (w[s1 + 1] & 0xF800F800) | moves[3] | (moves[4] << 16)
  w[s1 + 2] = (w[s1 + 2] & 0x80808080) | pp[1] | (pp[2] << 8) | (pp[3] << 16) | (pp[4] << 24)
  w[s0 + 2] = (w[s0 + 2] & 0xFFFFFF00) | bonuses
  encode(a, m)
end
local function setMoves(slot, moves, pp, bonuses) setMovesAt(slotAddr(slot), moves, pp, bonuses) end

-- Box 1, slot 1 of the PC. A copy of a party Mew's BoxPokemon puts a Mew there.
local BOX_MON = 80
local function boxAddr() return F.r32(S.gPokemonStoragePtr) + 4 end
local function putInBox(fromSlot)
  for off = 0, BOX_MON - 4, 4 do F.w32(boxAddr() + off, F.r32(slotAddr(fromSlot) + off)) end
end
local function clearBox() for off = 0, BOX_MON - 4, 4 do F.w32(boxAddr() + off, 0) end end
local function describeAt(a)
  local m = decode(a)
  return string.format("box sp=%d moves=%d,%d,%d,%d pp=%d,%d,%d,%d bon=%02X sum=%s", m.species, m.moves[1], m.moves[2],
    m.moves[3], m.moves[4], m.pp[1], m.pp[2], m.pp[3], m.pp[4], m.ppBonuses, m.checksumOk and "ok" or "BAD")
end
local function setEgg(slot)
  local a = slotAddr(slot)
  local m = decode(a)
  local s3 = m.o[3]
  m.words[s3 + 1] = m.words[s3 + 1] | (1 << 30)
  encode(a, m)
  F.w8(a + 19, F.r8(a + 19) | 4)
end

local function nickname(i)
  local b = {}
  for c in decode(slotAddr(i)).nick:gmatch("%d+") do b[#b + 1] = tonumber(c) end
  return b
end
-- The nickname is ten header bytes plus two characters kept in the encrypted growth substruct.
local function setNickname(i, b)
  local a = slotAddr(i)
  local m = decode(a)
  for k = 0, 9 do F.w8(a + 8 + k, b[k + 1] or 0xFF) end
  local s0 = m.o[0]
  m.words[s0 + 1] = (m.words[s0 + 1] & ~(0xFF << 21)) | ((b[11] or 0xFF) << 21)
  m.words[s0 + 2] = (m.words[s0 + 2] & ~(0xFF << 22)) | ((b[12] or 0xFF) << 22)
  encode(a, m)
end
local function nickText(b)
  local out = {}
  for k = 1, 12 do
    local c = b[k]
    if c == 0xFF then break end
    out[#out + 1] = (c >= 0xBB and c <= 0xD4) and string.char(65 + c - 0xBB) or ((c >= 0xD5 and c <= 0xEE) and string.char(97 + c - 0xD5) or "~")
  end
  return table.concat(out)
end
-- A traded-in Pokemon: another trainer's ID. The secure words are re-encrypted with the new key.
local function setOtId(i, id)
  local a = slotAddr(i)
  local m = decode(a)
  F.w32(a + 4, id)
  encode(a, m)
end

local function describe(i)
  local m = decode(slotAddr(i))
  return string.format("[%d] sp=%d egg=%s moves=%d,%d,%d,%d pp=%d,%d,%d,%d bon=%02X sum=%s", i, m.species,
    tostring(m.egg), m.moves[1], m.moves[2], m.moves[3], m.moves[4], m.pp[1], m.pp[2], m.pp[3], m.pp[4],
    m.ppBonuses, m.checksumOk and "ok" or "BAD")
end
local function snapshot()
  local t = {}
  for i = 0, F.r8(S.gPartiesCount) - 1 do t[i] = decode(slotAddr(i)) end
  return t
end
local function sameMon(a, b)
  return a.pers == b.pers and a.otid == b.otid and a.species == b.species and a.nick == b.nick and a.ot == b.ot
end
local function sameMoves(a, b)
  for k = 1, 4 do if a.moves[k] ~= b.moves[k] or a.pp[k] ~= b.pp[k] then return false end end
  return a.ppBonuses == b.ppBonuses
end

local function digits(n) n = n - 1; return n // 100, (n // 10) % 10, n % 10 end
local function giveMon(species, level)
  local n0 = F.r8(S.gPartiesCount)
  for _ = 1, 3 do
    F.dbg(); F.idle(30); F.bOut(4)
    F.dbg(); F.sel(3); F.sel(1); F.idle(20)
    F.spin(digits(species)); F.idle(20)
    F.spin(digits(level)); F.idle(60); F.bOut(4)
    if F.r8(S.gPartiesCount) == n0 + 1 then return true end
    F.idle(60)
  end
  return false
end

local function d3(n) return (n // 100) % 10, (n // 10) % 10, n % 10 end
local function warpToCoords(region, grp, map, x, y, tag)
  F.w8(F.sb2() + S.SaveBlock2.currentRegion, region)
  F.w32(S.gCurrentRegion, region)
  for _ = 1, 4 do
    F.dbg(); F.sel(0); F.sel(1); F.idle(20)
    F.spin(d3(grp)); F.spin(d3(map))
    F.press("A", 2)
    for _ = 1, 400 do
      F.w8(S.sWarpDestination + 2, 0xFF)
      F.w16(S.sWarpDestination + 4, x)
      F.w16(S.sWarpDestination + 6, y)
      F.idle(1)
      local px, py = F.pos()
      if F.ow() and F.grp() == grp and F.mapn() == map and px == x and py == y then
        F.idle(120)
        instantText()
        return true
      end
    end
    F.bOut(5)
  end
  F.shot(tag .. "_warpfail")
  return false
end

local function readText(addr)
  local out = {}
  for i = 0, 399 do
    local c = F.r8(addr + i)
    if c == 0xFF then break end
    if c >= 0xBB and c <= 0xD4 then out[#out + 1] = string.char(65 + c - 0xBB)
    elseif c >= 0xD5 and c <= 0xEE then out[#out + 1] = string.char(97 + c - 0xD5)
    elseif c >= 0xA1 and c <= 0xAA then out[#out + 1] = string.char(48 + c - 0xA1)
    elseif c == 0x00 or c == 0xFE or c == 0xFA or c == 0xFB then out[#out + 1] = " "
    elseif c == 0xAB then out[#out + 1] = "!"
    elseif c == 0xAC then out[#out + 1] = "?"
    elseif c == 0xAD then out[#out + 1] = "."
    elseif c == 0xB8 then out[#out + 1] = ","
    elseif c == 0xB4 then out[#out + 1] = "'"
    else out[#out + 1] = "~" end
  end
  return table.concat(out)
end

local function summaryLive() return F.taskLive(S.Task_HandleReplaceMoveInput) end
local function chooserLive() return F.taskLive(S.Task_PokeStorageMain) or F.taskLive(S.Task_HandleChooseMonInput) end

-- Keys that pick party slot `slot` in each chooser. The storage chooser opens on the box; Left
-- lands on party slot 1, Up reaches slot 0, Down the later slots, A opens the action list and A
-- selects. The party menu opens on slot 0; Down walks the list and A chooses.
local function pickKeys(chooser, slot)
  local k = {}
  if chooser == "storage" then
    k[#k + 1] = "Left"
    if slot == 0 then k[#k + 1] = "Up" else for _ = 2, slot do k[#k + 1] = "Down" end end
    k[#k + 1] = "A"; k[#k + 1] = "A"
  else
    for _ = 1, slot do k[#k + 1] = "Down" end
    k[#k + 1] = "A"
  end
  return k
end

-- Talk to the NPC in front and play the flow. `steps` lists what the player does, in order, at
-- each Yes/No box a script opens, each Pokemon chooser and each move list:
--   { yes = true } / { yes = false }      answer the Yes/No box with A or B
--   { pick = n, chooser = c } / { keys }  pick party slot n in the chooser, or press these keys
--   { move = n } / { keys }               pick move n on the move list, or press these keys
-- `page = true` on a chooser step keeps paging text with A until the field is back (the party
-- menu prints a tutor's messages itself). Text on the field is paged with the key that answers
-- the next Yes/No box, so a press landing on the frame a box opens still gives the intended
-- answer. Returns the events seen, comma separated, and every message the field printed.
local function talk(face, steps, tag, shots)
  F.face(face)
  F.w8(S.gStringVar4, 0xFF)
  F.press("A", 2)
  local si, seen, texts, last = 1, {}, {}, ""
  local function note()
    local t = readText(S.gStringVar4)
    if t ~= last and t ~= "" then texts[#texts + 1] = t; last = t end
  end
  local wasUp, started, calm, page, pickDone, moveDone, nameDone, relearnDone = false, false, 0, false, false, false, false, false
  local function take(kind)
    local s = steps[si]; si = si + 1
    if s and (s[kind] ~= nil or (s.keys and kind ~= "yes")) then seen[#seen + 1] = kind; return s end
    seen[#seen + 1] = kind .. "?"
    return nil
  end
  local function pageKey()
    local s = steps[si]
    if s and s.yes == false then return "B" end
    return "A"
  end
  local function keys(list, gap)
    for _, k in ipairs(list) do
      if type(k) == "number" then F.idle(k) else F.press(k, 2); F.idle(gap or 30) end
    end
  end
  for i = 1, 9000 do
    if F.reportCrash(tag) then seen[#seen + 1] = "crash"; break end
    local ow = F.ow()
    if ow then pickDone, moveDone, nameDone, relearnDone = false, false, false, false end
    local up = yesNoUp()
    if not started and (F.r8(S.sGlobalScriptContextStatus) ~= CONTEXT_SHUTDOWN or F.r8(S.sLockFieldControls) ~= 0) then
      started = true
    end
    if up and not wasUp then
      note()
      local s = take("yes")
      F.idle(4)
      F.shot(string.format("%s_%d_yesno", tag, #seen))
      F.press((s and s.yes) and "A" or "B", 2)
    elseif not moveDone and summaryLive() then
      moveDone = true
      local s = take("move")
      F.idle(30)
      F.shot(string.format("%s_%d_moves", tag, #seen))
      if s and s.move then
        local k = {}
        for _ = 1, s.move do k[#k + 1] = "Down" end
        k[#k + 1] = "A"
        keys(k)
      elseif s then keys(s.keys, s.gap)
      else keys({ "B" }) end
    elseif not relearnDone and F.cb2() == S.CB2_MoveRelearnerMain then
      relearnDone = true
      local s = take("relearn")
      F.idle(60)
      F.shot(string.format("%s_%d_relearner", tag, #seen))
      keys(s and s.relearn or { "B" }, 40)
      page = true
    elseif not nameDone and F.cb2() == S.CB2_NamingScreen then
      nameDone = true
      local s = take("name")
      F.idle(90)
      F.shot(string.format("%s_%d_naming", tag, #seen))
      keys(s and s.keys or { "B" }, s and s.gap or 15)
      F.shot(string.format("%s_%d_named", tag, #seen))
      if s then keys({ "Start", "A" }, 30) end
    elseif not pickDone and not ow and chooserLive() then
      pickDone = true
      local s = take("pick")
      F.idle(60)
      F.shot(string.format("%s_%d_chooser", tag, #seen))
      if s and s.pick then keys(pickKeys(s.chooser, s.pick), 40)
      elseif s then keys(s.keys, s.gap or 40)
      else keys({ "B", "B" }, 40) end
      page = s and s.page or false
    elseif started and hasControl() then
      calm = calm + 1
      if calm > 20 then break end
      F.idle(1)
    elseif not up and (ow or (page and not summaryLive())) and i % 25 == 0 then
      calm = 0
      note()
      if shots and ow then F.shot(string.format("%s_page%d", tag, i)) end
      F.press(pageKey(), 2)
    else
      calm = 0
      F.idle(1)
    end
    wasUp = up
  end
  if not hasControl() then
    for _ = 1, 300 do if hasControl() then break end F.press("B", 2); F.idle(20) end
  end
  note()
  local s, said = table.concat(seen, ","), table.concat(texts, " | ")
  F.L(string.format("  %s events=%s steps=%d/%d control=%s", tag, s, si - 1, #steps, tostring(hasControl())))
  F.L("    said: " .. said)
  return s, said
end

local function checkIntact(tag, before, after, except)
  for i = 0, F.r8(S.gPartiesCount) - 1 do
    local b, a = before[i], after[i]
    F.check(string.format("%s: slot %d is the same Pokemon with nickname and OT intact", tag, i),
      b and a and sameMon(a, b) and a.checksumOk, describe(i))
    if i ~= except then
      F.check(string.format("%s: slot %d moves, PP and PP Ups untouched", tag, i), b and a and sameMoves(a, b), describe(i))
    end
  end
end

-- Party: Mew A (slot 0), Mew B (slot 1), a one-move Mew (slot 2), an Egg (slot 3).
local function resetParty()
  setMoves(0, { MOVE.PSYCHIC, MOVE.POUND, MOVE.MEGA_PUNCH, MOVE.METRONOME }, { 16, 35, 20, 10 }, 0x03)
  setMoves(1, { MOVE.SURF, MOVE.POUND, MOVE.MEGA_PUNCH, MOVE.METRONOME }, { 16, 30, 20, 10 }, 0x39)
  setMoves(2, { MOVE.POUND, 0, 0, 0 }, { 35, 0, 0, 0 }, 0)
end

local DELETERS = {
  { tag = "lilycove", region = REGION_HOENN, g = 13, n = 11, x = 4, y = 5, chooser = "storage" },
  { tag = "fuchsia", region = REGION_KANTO, g = 45, n = 6, x = 4, y = 5, chooser = "party" },
  { tag = "blackthorn", region = REGION_JOHTO, g = 94, n = 3, x = 4, y = 5, chooser = "party" },
}

local function pick(chooser, slot) return { pick = slot, chooser = chooser } end

-- Items are given the way RelearnerDeclineHeartScale.lua does it: an additem script run by the
-- global script context. Quantities in the Bag are XORed with the low half of the save's key.
local SCRIPT_BUF = S.gStringVar4 + 960
local function addItem(id, n)
  local bytes = { 0x44, id & 0xFF, id >> 8, n, 0, 0x02 }
  for i, b in ipairs(bytes) do F.w8(SCRIPT_BUF + i - 1, b) end
  F.w8(S.sGlobalScriptContext, 0)
  F.w8(S.sGlobalScriptContext + 1, 1)
  F.w32(S.sGlobalScriptContext + 4, 0)
  F.w32(S.sGlobalScriptContext + S.ScriptCtx.scriptPtr, SCRIPT_BUF)
  F.w8(S.sGlobalScriptContextStatus, 0)
  for _ = 1, 200 do F.idle(4); if hasControl() then break end end
  F.idle(30)
end
local function itemQty(id)
  local key, n = F.r32(F.sb2() + S.SaveBlock2.encryptionKey) & 0xFFFF, 0
  for p = 0, 4 do
    local ptr = F.r32(S.gBagPockets + p * S.BagPocket.stride)
    local cap = F.pocketCap(p)
    if ptr >= 0x02000000 and ptr < 0x02040000 and cap > 0 and cap < 200 then
      for slot = 0, cap - 1 do
        if F.r16(ptr + slot * 4) == id then n = n + (F.r16(ptr + slot * 4 + 2) ~ key) end
      end
    end
  end
  return n
end
local ITEM_BIG_MUSHROOM, ITEM_HEART_SCALE = 138, 152

F.run(function()
  if not F.boot(100) then F.check("boot to the hub", false); F.finish(); return end
  instantText()
  for off = 0, PARTY_SIZE * MON - 4, 4 do F.w32(S.gParties + off, 0) end
  F.w8(S.gPartiesCount, 0)
  local ok = true
  for _ = 1, 4 do ok = ok and giveMon(SPECIES_MEW, 50) end
  F.check("setup: four Mew", ok and F.r8(S.gPartiesCount) == 4)
  setEgg(3)
  resetParty()
  for i = 0, 3 do F.L("  setup " .. describe(i)) end

  -- Tutors teach into Mew A's full moveset over Psychic, which carries three PP Ups (16 of 16 PP).
  -- The new move must arrive with its full PP and the slot's PP Ups cleared. The tutor's "forget
  -- a move?" box belongs to the learning task, not a script yes/no, so the A that pages the text
  -- answers it YES.
  local TUTORS = {
    { tag = "tutor_hoenn", region = REGION_HOENN, g = 6, n = 4, x = 9, y = 6, face = "Right", chooser = "storage",
      move = MOVE.FURY_CUTTER, name = "Fury Cutter at Verdanturf" },
    { tag = "tutor_kanto", region = REGION_KANTO, g = 40, n = 0, x = 25, y = 7, face = "Right", chooser = "party",
      move = MOVE.SEISMIC_TOSS, name = "Seismic Toss at the Pewter Museum" },
  }
  for _, tu in ipairs(TUTORS) do
    local t = tu.tag
    resetParty()
    if F.check(t .. ": stand before the " .. tu.name .. " tutor", warpToCoords(tu.region, tu.g, tu.n, tu.x, tu.y, t)) then
      local before = snapshot()
      local ev = talk(tu.face, { { yes = true }, { pick = 0, chooser = tu.chooser, page = tu.chooser == "party" }, { move = 0 } }, t)
      local after = snapshot()
      local m = after[0]
      F.check(t .. ": offer, chooser and move list came up", ev == "yes,pick,move", ev)
      F.check(t .. ": the new move replaced Psychic in slot 1", m.moves[1] == tu.move and m.moves[2] == MOVE.POUND
        and m.moves[3] == MOVE.MEGA_PUNCH and m.moves[4] == MOVE.METRONOME, describe(0))
      F.check(t .. ": the new move has its full PP", m.pp[1] == BASE_PP[tu.move], describe(0))
      F.check(t .. ": the replaced slot's PP Ups are cleared", m.ppBonuses == 0x00, describe(0))
      F.check(t .. ": the other moves keep their PP", m.pp[2] == 35 and m.pp[3] == 20 and m.pp[4] == 10, describe(0))
      checkIntact(t, before, after, 0)
      F.check(t .. ": control returns", hasControl())
    end
  end

  -- Mauville's Rollout tutor over Metronome, which has no PP left. Rollout must arrive usable,
  -- with 20 PP, and Psychic keeps its own PP Ups.
  resetParty()
  setMoves(0, { MOVE.PSYCHIC, MOVE.POUND, MOVE.MEGA_PUNCH, MOVE.METRONOME }, { 16, 35, 20, 0 }, 0x03)
  if F.check("tutor_mauville: stand before the Rollout tutor", warpToCoords(REGION_HOENN, 0, 2, 12, 7, "tutor_mauville")) then
    local before = snapshot()
    local ev = talk("Right", { { yes = true }, pick("storage", 0), { move = 3 } }, "tutor_mauville")
    local after = snapshot()
    local m = after[0]
    F.check("tutor_mauville: offer, chooser and move list came up", ev == "yes,pick,move", ev)
    F.check("tutor_mauville: Rollout replaced the spent Metronome", m.moves[1] == MOVE.PSYCHIC and m.moves[4] == MOVE.ROLLOUT, describe(0))
    F.check("tutor_mauville: Rollout has its full 20 PP", m.pp[4] == BASE_PP[MOVE.ROLLOUT], describe(0))
    F.check("tutor_mauville: Psychic keeps its PP and PP Ups", m.pp[1] == 16 and m.ppBonuses == 0x03, describe(0))
    checkIntact("tutor_mauville", before, after, 0)
    F.check("tutor_mauville: control returns", hasControl())
  end

  -- The same lesson for a Mew in a PC box, picked straight from the storage chooser.
  resetParty()
  putInBox(0)
  setMovesAt(boxAddr(), { MOVE.PSYCHIC, MOVE.POUND, MOVE.MEGA_PUNCH, MOVE.METRONOME }, { 16, 35, 20, 10 }, 0x03)
  if F.check("tutor_box: stand before the Verdanturf Fury Cutter tutor", warpToCoords(REGION_HOENN, 6, 4, 9, 6, "tutor_box")) then
    local before = snapshot()
    local ev = talk("Right", { { yes = true }, { keys = { "A", "A" } }, { move = 0 } }, "tutor_box")
    local m = decode(boxAddr())
    F.check("tutor_box: offer, chooser and move list came up", ev == "yes,pick,move", ev)
    F.check("tutor_box: Fury Cutter replaced Psychic in the boxed Mew", m.moves[1] == MOVE.FURY_CUTTER and m.moves[2] == MOVE.POUND
      and m.moves[3] == MOVE.MEGA_PUNCH and m.moves[4] == MOVE.METRONOME and m.checksumOk, describeAt(boxAddr()))
    F.check("tutor_box: Fury Cutter has its full 20 PP and no PP Ups", m.pp[1] == 20 and m.ppBonuses == 0, describeAt(boxAddr()))
    checkIntact("tutor_box", before, snapshot())
    F.check("tutor_box: control returns", hasControl())
  end
  clearBox()

  for _, dl in ipairs(DELETERS) do
    local t, c = dl.tag, dl.chooser
    resetParty()
    if F.check(t .. ": stand before the Move Deleter", warpToCoords(dl.region, dl.g, dl.n, dl.x, dl.y, t)) then
      local base = snapshot()

      local ev, said = talk("Up", { { yes = false } }, t .. "_no")
      F.check(t .. ": NO at the offer says come again", ev == "yes" and said:find("Come again") ~= nil, ev .. " / " .. said)
      checkIntact(t .. "_no", base, snapshot())

      ev, said = talk("Up", { { yes = true }, { keys = { "B", "B" } } }, t .. "_bchooser")
      F.check(t .. ": B in the chooser closes it", ev == "yes,pick" and said:find("Come again") ~= nil, ev .. " / " .. said)
      checkIntact(t .. "_bchooser", base, snapshot())

      ev, said = talk("Up", { { yes = true }, pick(c, 3) }, t .. "_egg")
      F.check(t .. ": an Egg is refused before any move list", ev == "yes,pick" and said:find("No EGG should know") ~= nil,
        ev .. " / " .. said)
      checkIntact(t .. "_egg", base, snapshot())

      ev, said = talk("Up", { { yes = true }, pick(c, 2) }, t .. "_onemove")
      F.check(t .. ": a Pokemon with one move is refused before any move list", ev == "yes,pick"
        and said:find("only one") ~= nil, ev .. " / " .. said)
      checkIntact(t .. "_onemove", base, snapshot())

      local mash = {}
      for _ = 1, 8 do mash[#mash + 1] = "B" end
      ev, said = talk("Up", { { yes = true }, pick(c, 1), { keys = mash, gap = 6 }, { keys = { "B", "B" } } }, t .. "_bmoves")
      F.check(t .. ": B mashed on the move list goes back to the chooser, B there leaves", ev == "yes,pick,move,pick", ev)
      checkIntact(t .. "_bmoves", base, snapshot())

      ev, said = talk("Up", { { yes = true }, pick(c, 1), { move = 1 }, { yes = false } }, t .. "_noconfirm")
      F.check(t .. ": NO at the final question keeps the move", ev == "yes,pick,move,yes"
        and said:find("Pound%?") ~= nil and said:find("Come again") ~= nil, ev .. " / " .. said)
      checkIntact(t .. "_noconfirm", base, snapshot())

      -- Mew B: Surf (1 PP Up), Pound (2), Mega Punch (3), Metronome (0). Deleting Pound must
      -- leave Surf, Mega Punch, Metronome with their own PP and PP Ups, and an empty fourth slot.
      ev, said = talk("Up", { { yes = true }, pick(c, 1), { move = 1 }, { yes = true } }, t .. "_delete")
      local after = snapshot()
      local m = after[1]
      F.check(t .. ": the delete flow ran and names the move", ev == "yes,pick,move,yes"
        and said:find("forgotten Pound") ~= nil, ev .. " / " .. said)
      F.check(t .. ": Pound is gone and the later moves moved up", m.moves[1] == MOVE.SURF and m.moves[2] == MOVE.MEGA_PUNCH
        and m.moves[3] == MOVE.METRONOME and m.moves[4] == 0, describe(1))
      F.check(t .. ": PP moved with the moves", m.pp[1] == 16 and m.pp[2] == 20 and m.pp[3] == 10 and m.pp[4] == 0, describe(1))
      F.check(t .. ": PP Ups moved with the moves", m.ppBonuses == 0x0D, describe(1))
      checkIntact(t .. "_delete", base, after, 1)

      -- The HM: every source game's Move Deleter forgets an HM, and P_CAN_FORGET_HIDDEN_MOVE agrees.
      ev, said = talk("Up", { { yes = true }, pick(c, 1), { move = 0 }, { yes = true } }, t .. "_hm")
      after = snapshot()
      m = after[1]
      F.check(t .. ": Surf, an HM, can be deleted", ev == "yes,pick,move,yes" and said:find("forgotten Surf") ~= nil
        and m.moves[1] == MOVE.MEGA_PUNCH
        and m.moves[2] == MOVE.METRONOME and m.moves[3] == 0 and m.pp[1] == 20 and m.pp[2] == 10 and m.ppBonuses == 0x03, describe(1))
      if dl.chooser == "storage" then
        -- A Mew in the PC: the storage chooser opens on box 1, slot 1.
        resetParty()
        putInBox(1)
        setMovesAt(boxAddr(), { MOVE.SURF, MOVE.POUND, MOVE.MEGA_PUNCH, MOVE.METRONOME }, { 16, 30, 20, 10 }, 0x39)
        local partyBefore = snapshot()
        ev, said = talk("Up", { { yes = true }, { keys = { "A", "A" } }, { move = 1 }, { yes = true } }, t .. "_box")
        m = decode(boxAddr())
        F.check(t .. ": a boxed Mew forgets Pound", ev == "yes,pick,move,yes" and said:find("forgotten Pound") ~= nil, ev .. " / " .. said)
        F.check(t .. ": the boxed Mew's moves, PP and PP Ups moved up", m.moves[1] == MOVE.SURF and m.moves[2] == MOVE.MEGA_PUNCH
          and m.moves[3] == MOVE.METRONOME and m.moves[4] == 0 and m.pp[1] == 16 and m.pp[2] == 20 and m.pp[3] == 10
          and m.pp[4] == 0 and m.ppBonuses == 0x0D and m.checksumOk, describeAt(boxAddr()))
        checkIntact(t .. "_box", partyBefore, snapshot())
        clearBox()
      end
      F.check(t .. ": control returns", hasControl())
    end
  end

  -- Move Relearners. Each teaches a forgotten level-up move into Mew A's full moveset over Psychic
  -- (three PP Ups) for its fee. The new move must arrive with its full PP, the slot's PP Ups cleared,
  -- and exactly one fee taken.
  local RELEARNERS = {
    { tag = "relearn_fallarbor", region = REGION_HOENN, g = 5, n = 5, x = 4, y = 5, chooser = "storage", fee = ITEM_HEART_SCALE },
    { tag = "relearn_twoisland", region = REGION_KANTO, g = 65, n = 1, x = 7, y = 6, chooser = "party", fee = ITEM_BIG_MUSHROOM },
    { tag = "relearn_blackthorn", region = REGION_JOHTO, g = 94, n = 3, x = 7, y = 5, chooser = "party", fee = ITEM_HEART_SCALE },
  }
  for _, rl in ipairs(RELEARNERS) do
    local t = rl.tag
    resetParty()
    if F.check(t .. ": stand before the Move Relearner", warpToCoords(rl.region, rl.g, rl.n, rl.x, rl.y, t)) then
      addItem(rl.fee, 1)
      local fee0 = itemQty(rl.fee)
      local before = snapshot()
      local ev, said = talk("Up", { { yes = true }, pick(rl.chooser, 0), { relearn = { "A" } }, { move = 0 } }, t)
      local after = snapshot()
      local m = after[0]
      F.check(t .. ": offer, chooser, relearner and move list came up", ev == "yes,pick,relearn,move", ev .. " / " .. said)
      F.check(t .. ": a new move replaced Psychic", m.moves[1] ~= MOVE.PSYCHIC and m.moves[1] ~= 0 and m.moves[2] == MOVE.POUND
        and m.moves[3] == MOVE.MEGA_PUNCH and m.moves[4] == MOVE.METRONOME, describe(0))
      F.check(t .. ": the new move has its full PP and no PP Ups", BASE_PP[m.moves[1]] ~= nil and m.pp[1] == BASE_PP[m.moves[1]]
        and m.ppBonuses == 0, describe(0))
      F.check(t .. ": exactly one fee was taken", fee0 >= 1 and itemQty(rl.fee) == fee0 - 1, fee0 .. " -> " .. itemQty(rl.fee))
      checkIntact(t, before, after, 0)
      F.check(t .. ": control returns", hasControl())
    end
  end

  -- Name Raters. Slot 0 is the player's Mew, slot 1 a Mew traded in from another trainer, slot 3
  -- the Egg. A twelve-letter nickname (the most the naming screen takes) must be stored whole; an
  -- empty one keeps the old name; the Egg and, in Hoenn and Kanto, the traded Mew are refused.
  -- pokemonHnS left Goldenrod's OT check commented out, so the Johto rater offers to rename it.
  local MEW = { 0xC7, 0xBF, 0xD1, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF }
  -- The keyboard drops to lower case after the first letter, so twelve A presses spell Aaaaaaaaaaaa.
  local TWELVE = { 0xBB }
  for k = 2, 12 do TWELVE[k] = 0xD5 end
  -- The page flip after the first letter swallows a press made during it.
  local typeTwelve = { "A", 60 }
  for _ = 2, 12 do typeTwelve[#typeTwelve + 1] = "A" end
  local RATERS = {
    { tag = "rater_slateport", region = REGION_HOENN, g = 9, n = 5, x = 7, y = 6, chooser = "storage", refuse = "magnificent" },
    { tag = "rater_lavender", region = REGION_KANTO, g = 42, n = 4, x = 4, y = 5, chooser = "party", refuse = "truly impeccable" },
    { tag = "rater_goldenrod", region = REGION_JOHTO, g = 84, n = 14, x = 4, y = 5, chooser = "party" },
  }
  local playerOt = F.r32(slotAddr(0) + 4)
  setOtId(1, playerOt ~ 0x00010001)
  for _, nr in ipairs(RATERS) do
    local t, c = nr.tag, nr.chooser
    setNickname(0, MEW)
    if F.check(t .. ": stand before the Name Rater", warpToCoords(nr.region, nr.g, nr.n, nr.x, nr.y, t)) then
      local base = snapshot()

      local ev, said = talk("Up", { { yes = true }, pick(c, 3) }, t .. "_egg")
      F.check(t .. ": the Egg is refused", ev == "yes,pick" and said:find("merely an EGG") ~= nil, ev .. " / " .. said)
      checkIntact(t .. "_egg", base, snapshot())

      ev, said = talk("Up", { { yes = true }, pick(c, 0), { yes = false } }, t .. "_decline")
      F.check(t .. ": NO to a better name keeps it", ev == "yes,pick,yes" and said:find("visit again") ~= nil
        and nickText(nickname(0)) == "MEW", ev .. " / " .. said)
      checkIntact(t .. "_decline", base, snapshot())

      ev, said = talk("Up", { { yes = true }, pick(c, 0), { yes = true }, { keys = typeTwelve, gap = 20 } }, t .. "_rename", true)
      local nick = nickname(0)
      F.check(t .. ": the rename flow ran", ev == "yes,pick,yes,name", ev .. " / " .. said)
      F.check(t .. ": all twelve letters are stored", table.concat(nick, ",") == table.concat(TWELVE, ","), table.concat(nick, ","))
      F.check(t .. ": the rater announces the new name as a change", said:find("known as Aaaaaaaaaaaa!") ~= nil
        and said:find("better name than before") ~= nil, said)
      local after = snapshot()
      F.check(t .. ": the renamed Mew keeps its OT, moves and checksum", after[0].pers == base[0].pers and after[0].otid == base[0].otid
        and after[0].ot == base[0].ot and sameMoves(after[0], base[0]) and after[0].checksumOk, describe(0))

      ev, said = talk("Up", { { yes = true }, pick(c, 0), { yes = true }, { keys = { "B", "B", "B", "B", "B", "B", "B", "B", "B", "B", "B", "B" } } },
        t .. "_empty", true)
      F.check(t .. ": an empty name keeps the twelve letters", ev == "yes,pick,yes,name"
        and table.concat(nickname(0), ",") == table.concat(TWELVE, ","), table.concat(nickname(0), ","))
      F.check(t .. ": and the rater reads it back unchanged", said:find("Aaaaaaaaaaaa, is it%?") ~= nil
        and said:find("no different") ~= nil, said)

      local before = snapshot()
      if nr.refuse then
        ev, said = talk("Up", { { yes = true }, pick(c, 1) }, t .. "_traded")
        F.check(t .. ": a traded Pokemon is refused", ev == "yes,pick" and said:find(nr.refuse) ~= nil, ev .. " / " .. said)
      else
        ev, said = talk("Up", { { yes = true }, pick(c, 1), { yes = false } }, t .. "_traded")
        F.check(t .. ": pokemonHnS offers to rename a traded Pokemon", ev == "yes,pick,yes" and said:find("better name") ~= nil,
          ev .. " / " .. said)
      end
      checkIntact(t .. "_traded", before, snapshot())
      F.check(t .. ": control returns", hasControl())
    end
  end

  F.check("no crash", not F.crashScreen())
  F.finish()
end)
