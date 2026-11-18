-- Two Johto gifts ported from pokemonHnS, driven with real input.
--
-- Blackthorn House 2: Emy trades her Mr. Mime (MIMIEN, OT EMY) for a Dodrio. Her script names
-- INGAME_TRADE_MR_MIME, and that name is also FRLG's Route 2 trade (REYLEY's Mr. Mime for an Abra),
-- so she asked for an Abra and handed over a second copy of the Kanto Mr. Mime. With an Abra and a
-- Dodrio in the party, the Dodrio is offered: it must become Emy's Mr. Mime (her trainer ID), the
-- Abra must stay, her flag must be set, and a second talk must not trade again.
--
-- Route 34 Day Care: the couple's son gives the Odd Egg only for one of seven four-word answers the
-- bookshelves hint at (BABE POKEMON <type word> <ability word>), and the answer picks the baby. The
-- answer matcher was not ported, so any changed phrase gave a Pichu Egg. A one-word answer picked on
-- the real word screen (A on the first slot, first group, first word) must be refused with no Egg;
-- the Elekid answer must give an Elekid Egg that knows Dizzy Punch; a third talk must give nothing.
-- The Elekid answer is written into the Easy Chat screen's phrase while it is open (what the word
-- picker does); confirming it with Start and Yes is real input.
--
-- Run via test/overworld/mgba-run.sh test/overworld/lua/JohtoTradeOddEgg.lua <rom.gba>

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "JohtoTradeOddEgg")

local MON = S.Pokemon.size
local SP = { abra = 63, dodrio = 85, mime = 122, pichu = 172, elekid = 239 }
local EMY_OT_ID, REYLEY_OT_ID = 10283, 1985
local MOVE_DIZZY_PUNCH = 146
local FLAG_RECEIVED_ODD_EGG, FLAG_BLACKTHORN_NPC_TRADE_COMPLETED = 0x608D, 0x61B1
local EC_EMPTY_WORD = 0xFFFF
local function ec(group, index) return (group << 9) | index end
local ELEKID_ANSWER = { ec(5, 22), ec(1, 14), ec(2, 57), ec(2, 49) } -- BABE POKEMON ELECTRIC STATIC
local EASY_CHAT_PHRASE = 0x3C
local BLACKTHORN_HOUSE2, DAYCARE = { 94, 2 }, { 81, 5 }

local function tap(key, wait) F.press(key, 2); F.idle(wait or 20) end
local function d(n) return (n // 100) % 10, (n // 10) % 10, n % 10 end
local function warp(m, tag)
  local gh, gt, go = d(m[1])
  local mh, mt, mo = d(m[2])
  return F.warpTo(gh, gt, go, mh, mt, mo, 0, 0, 0, m[1], m[2], tag)
end
local function flag(id)
  local o = id - 0x6000
  return (F.r8(F.sb3() + S.SaveBlock3.johtoFlags + o // 8) >> (o % 8)) & 1 == 1
end
local function scriptIdle() return F.ow() and F.r8(S.sGlobalScriptContextStatus) == 2 end

local function partyCount() return F.r8(S.gPartiesCount) end
local function slot(i) return S.gParties + i * MON end
local function decode(i)
  local a = slot(i)
  local pers, otid = F.r32(a), F.r32(a + 4)
  local w = {}
  for k = 0, 11 do w[k] = F.r32(a + 32 + k * 4) ~ pers ~ otid end
  local so = {}
  for t = 0, 3 do so[t] = F.r8(S.sSubstructOffsets + t * 24 + pers % 24) * 3 end
  local sum = 0
  for k = 0, 11 do sum = sum + (w[k] & 0xFFFF) + (w[k] >> 16) end
  return {
    species = w[so[0]] & 0x7FF, otid = otid, pid = pers,
    moves = { w[so[1]] & 0x7FF, (w[so[1]] >> 16) & 0x7FF, w[so[1] + 1] & 0x7FF, (w[so[1] + 1] >> 16) & 0x7FF },
    ok = (sum & 0xFFFF) == F.r16(a + 28),
  }
end
local function knows(m, move) for _, v in ipairs(m.moves) do if v == move then return true end end return false end
local function zeroParty()
  for o = 0, 6 * MON - 4, 4 do F.w32(S.gParties + o, 0) end
  F.w8(S.gPartiesCount, 0)
end

-- Debug Give X > Pokemon (Basic): four-digit species spinner, then level.
local function spin4(n)
  n = n - 1
  local dg = { n // 1000, (n // 100) % 10, (n // 10) % 10, n % 10 }
  for _ = 1, 3 do tap("Right", 8) end
  for _ = 1, 3 do tap("Down", 8) end
  for i = 1, 4 do
    for _ = 1, dg[i] do tap("Up", 8) end
    if i < 4 then tap("Left", 8) end
  end
  tap("A", 45)
end
local function giveMon(species, level)
  local n0 = partyCount()
  for _ = 1, 3 do
    F.dbg(); F.idle(30); F.bOut(4)
    F.dbg(); F.sel(3); F.sel(1); F.idle(20)
    spin4(species); F.idle(20)
    local l = level - 1
    F.spin(l // 100, (l // 10) % 10, l % 10); F.idle(60); F.bOut(4)
    if partyCount() == n0 + 1 and decode(n0).species == species then return true end
    for o = n0 * MON, 6 * MON - 4, 4 do F.w32(S.gParties + o, 0) end
    F.w8(S.gPartiesCount, n0)
    F.idle(60)
  end
  return false
end

-- Press `key` through messages and scenes until the script ends on the field. Facing an NPC, A
-- would talk to them again once the script ends, so their messages are paged with B.
local function untilField(tag, budget, key)
  for i = 1, budget or 3000 do
    if i > 60 and scriptIdle() then F.idle(20); if scriptIdle() then return true end end
    if i % 60 == 0 and F.reportCrash(tag) then return false end
    if i % 12 == 0 then F.press(key or "A", 2) else F.idle(1) end
  end
  F.shot(tag .. "_stuck")
  return false
end
local function talk(path, facing, tag)
  if not F.route(path, tag .. "_walk") then F.check(tag .. ": reached the NPC", false); return false end
  F.face(facing); F.press("A", 2); F.idle(40)
  return true
end

-- The box chooser is the SwSh storage screen with the cursor in box slot 1: Left lands on party
-- index 1, A opens the menu and A picks SELECT (as MoneySinkEdges' deposit picker).
local function pickPartyIndex1(tag)
  for _ = 1, 12 do
    if not F.ow() then break end
    tap("A", 40)
  end
  F.idle(200)
  if F.ow() then F.shot(tag .. "_no_chooser"); return false end
  tap("Left", 40); F.shot(tag .. "_chooser")
  tap("A", 40); tap("A", 60)
  return true
end

local function easyChat() return F.cb2() == (S.CB2_EasyChatScreen & ~1) and F.r32(S.sEasyChatScreen) ~= 0 end
local function phraseAddr() return F.r32(S.sEasyChatScreen) + EASY_CHAT_PHRASE end
local function awaitEasyChat(tag)
  for _ = 1, 600 do
    if easyChat() then F.idle(120); return true end
    if F.ow() and scriptIdle() then break end
    if F.ow() then F.press("A", 2) end
    F.idle(10)
  end
  F.shot(tag .. "_no_easy_chat")
  return false
end
-- Start opens "Is this OK?" with YES highlighted; A confirms.
local function confirmPhrase(tag)
  F.shot(tag .. "_phrase")
  tap("Start", 60); tap("A", 60)
  for _ = 1, 300 do if not easyChat() then return true end F.idle(1) end
  return false
end
local function oddEggTalk() return talk({ { 4, 4 }, { 9, 4 }, { 9, 3 } }, "Right", "clerk") end

F.run(function()
  if not F.boot(100) then F.check("boot to the hub", false); F.finish(); return end
  local opt = F.sb2() + S.SaveBlock2.optionsU16
  F.w16(opt, (F.r16(opt) & ~7) | 3)

  F.L("== Blackthorn: Emy's Mr. Mime ==")
  zeroParty()
  F.check("setup: Abra and Dodrio in the party", giveMon(SP.abra, 20) and giveMon(SP.dodrio, 30), "party=" .. partyCount())
  local abraPid = decode(0).pid
  if warp(BLACKTHORN_HOUSE2, "blackthorn_house2") then
    F.idle(60)
    if talk({ { 4, 6 }, { 2, 6 }, { 2, 5 } }, "Up", "emy") then
      F.shot("emy_offer")
      if pickPartyIndex1("emy") then
        F.check("Emy: the trade ran and the field came back", untilField("emy_trade", 9000, "A"))
      end
    end
    local p0, p1 = decode(0), decode(1)
    F.L(string.format("  party: [0] species=%d pid=%08X [1] species=%d otid=%d", p0.species, p0.pid, p1.species, p1.otid & 0xFFFF))
    F.check("the Dodrio became a Mr. Mime", p1.ok and p1.species == SP.mime, "species=" .. p1.species)
    F.check("the Mr. Mime is Emy's (trainer ID 10283), not REYLEY's Kanto copy",
      (p1.otid & 0xFFFF) == EMY_OT_ID, string.format("otid=%d (REYLEY is %d)", p1.otid & 0xFFFF, REYLEY_OT_ID))
    F.check("the Abra was not traded", p0.ok and p0.species == SP.abra and p0.pid == abraPid, "species=" .. p0.species)
    F.check("Emy's trade flag is set", flag(FLAG_BLACKTHORN_NPC_TRADE_COMPLETED))
    local count = partyCount()
    if talk({ { 2, 6 }, { 2, 5 } }, "Up", "emy_again") then untilField("emy_again", 1200, "B") end
    F.check("a second talk trades nothing", partyCount() == count and decode(1).species == p1.species and decode(1).pid == p1.pid)
    F.check("Emy: back in control", scriptIdle() and not F.reportCrash("emy"))
  end

  F.L("== Route 34 Day Care: the Odd Egg ==")
  zeroParty()
  F.check("setup: one Abra in the party", giveMon(SP.abra, 20), "party=" .. partyCount())
  if warp(DAYCARE, "daycare") then
    for _ = 1, 6 do tap("B", 30) end

    if oddEggTalk() and awaitEasyChat("wrong") then
      tap("A", 60); tap("A", 60); tap("A", 60)
      local w = F.r16(phraseAddr())
      F.L(string.format("  picked word %04X", w))
      F.check("wrong answer: a word was picked on the real word screen", w ~= EC_EMPTY_WORD)
      F.check("wrong answer: confirmed", confirmPhrase("wrong"))
      untilField("wrong", 1500, "B")
    end
    F.check("wrong answer: no Egg was given", partyCount() == 1, "party=" .. partyCount()
      .. (partyCount() > 1 and (" species=" .. decode(1).species) or ""))
    F.check("wrong answer: the Odd Egg flag stays clear", not flag(FLAG_RECEIVED_ODD_EGG))

    if oddEggTalk() and awaitEasyChat("elekid") then
      for i = 1, 4 do F.w16(phraseAddr() + (i - 1) * 2, ELEKID_ANSWER[i]) end
      F.check("Elekid answer: confirmed", confirmPhrase("elekid"))
      untilField("elekid", 1500, "B")
    end
    local egg = decode(1)
    F.L(string.format("  party=%d [1] species=%d moves=%d,%d,%d,%d", partyCount(), egg.species,
      egg.moves[1], egg.moves[2], egg.moves[3], egg.moves[4]))
    F.check("Elekid answer: an Elekid Egg joined the party", partyCount() == 2 and egg.ok and egg.species == SP.elekid,
      "species=" .. egg.species .. " (Pichu is " .. SP.pichu .. ")")
    F.check("Elekid answer: the Egg knows Dizzy Punch", knows(egg, MOVE_DIZZY_PUNCH))
    F.check("Elekid answer: the Odd Egg flag is set", flag(FLAG_RECEIVED_ODD_EGG))

    if oddEggTalk() then untilField("after", 1200, "B") end
    F.check("a third talk gives nothing", partyCount() == 2 and not easyChat())
    F.check("Day Care: back in control", scriptIdle())
  end

  F.check("no crash", not F.reportCrash("end"))
  F.finish()
end)
