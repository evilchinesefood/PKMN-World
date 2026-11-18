-- A Rare Candy used from the Bag must offer every move the new level teaches.
--
-- Bulbasaur learns Poison Powder and Sleep Powder at level 15. The Bag runs its own Rare Candy
-- flow (SWSH_ITEM_MENU_ACTION_IN_BAG, BagMenu_RareCandyDoLearnMoveStep in src/swsh_item_menu.c),
-- separate from the party menu's. Each scenario gives a real Bulbasaur through the debug Give
-- menu, uses candies on it from the Bag with real input, and records every move the game tries
-- to teach (gMoveToLearn) while it does:
--
--   1. one candy at level 14 with two free move slots, A mashed: both powders learned;
--   2. one candy at level 14 with four moves, every prompt accepted: both powders offered;
--   3. one candy at level 14 with four moves, every prompt cancelled with B: both offered,
--      neither learned, the old moveset untouched;
--   4. three candies at level 13 with two free slots: both powders learned on the way, then the
--      evolution into Ivysaur at 16 runs from the Bag;
--   5. eight candies at once on a level 40 Cradily with four moves, every prompt accepted: the jump
--      crosses level 43, which teaches three moves (Stockpile, Spit Up, Swallow), and level 48
--      (Energy Ball); all four are offered in learnset order and the last one ends in slot 1.
--
-- Run via test/overworld/mgba-run.sh test/overworld/lua/BagRareCandyMoves.lua <rom>
-- PW_CANDY_ONLY=<text> (runner --env) runs only the scenarios whose tag contains <text>.

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "BagRareCandyMoves")

local HUB_GROUP = 100
local ONLY = os.getenv("PW_CANDY_ONLY")
local PARTY_SIZE = 6
local MON = S.Pokemon.size
local USM_ICO_BAG = 2
local POCKET_ITEMS = 0

local BULBASAUR, IVYSAUR = 1, 2
local CRADILY = 346
local MOVE_STOCKPILE, MOVE_SPIT_UP, MOVE_SWALLOW, MOVE_ENERGY_BALL = 254, 255, 256, 412
local ITEM_RARE_CANDY = 102
local MOVE_VINE_WHIP, MOVE_GROWTH, MOVE_LEECH_SEED, MOVE_RAZOR_LEAF = 22, 74, 73, 75
local MOVE_POISON_POWDER, MOVE_SLEEP_POWDER = 77, 79

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
  local s0, s1 = o[0], o[1]
  return {
    species = w[s0] & 0x7FF,
    moves = { w[s1] & 0x7FF, (w[s1] >> 16) & 0x7FF, w[s1 + 1] & 0x7FF, (w[s1 + 1] >> 16) & 0x7FF },
    pp = { w[s1 + 2] & 0x7F, (w[s1 + 2] >> 8) & 0x7F, (w[s1 + 2] >> 16) & 0x7F, (w[s1 + 2] >> 24) & 0x7F },
    checksumOk = (sum & 0xFFFF) == F.r16(a + 28),
    level = F.r8(a + S.Pokemon.level),
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

local function describe(i)
  local m = decode(slotAddr(i))
  return string.format("[%d] sp=%d lv=%d moves=%d,%d,%d,%d pp=%d,%d,%d,%d sum=%s", i, m.species, m.level,
    m.moves[1], m.moves[2], m.moves[3], m.moves[4], m.pp[1], m.pp[2], m.pp[3], m.pp[4],
    m.checksumOk and "ok" or "BAD")
end

local function knows(m, move)
  for k = 1, 4 do if m.moves[k] == move then return true end end
  return false
end

local function movesetSane(m)
  local seen = {}
  for k = 1, 4 do
    local mv, pp = m.moves[k], m.pp[k]
    if mv == 0 then
      if pp ~= 0 then return false, "empty slot " .. k .. " has pp " .. pp end
    else
      if seen[mv] then return false, "duplicate move " .. mv end
      seen[mv] = true
      if pp == 0 or pp > 64 then return false, "move " .. mv .. " pp " .. pp end
    end
  end
  if m.moves[1] == 0 then return false, "no first move" end
  return true, "ok"
end

-- Empty move slots 3 and 4 the way a two-move mon has them: move 0, PP 0.
local function keepTwoMoves(i)
  local a = slotAddr(i)
  local m = decode(a)
  local s1 = m.o[1]
  m.words[s1 + 1] = 0
  m.words[s1 + 2] = m.words[s1 + 2] & 0xFFFF
  encode(a, m)
end

local function pocketPtr(p) return F.r32(S.gBagPockets + p * S.BagPocket.stride) end
local function qtyKey() return F.r32(F.sb2() + S.SaveBlock2.encryptionKey) & 0xFFFF end
local function countItem(id)
  local n, ptr, cap = 0, pocketPtr(POCKET_ITEMS), F.pocketCap(POCKET_ITEMS)
  for s = 0, cap - 1 do
    if F.r16(ptr + s * 4) == id then n = n + (F.r16(ptr + s * 4 + 2) ~ qtyKey()) end
  end
  return n
end
local function setPocket(p, id, qty)
  local ptr, cap = pocketPtr(p), F.pocketCap(p)
  for s = 0, cap - 1 do F.w16(ptr + s * 4, 0); F.w16(ptr + s * 4 + 2, qtyKey()) end
  if qty > 0 then F.w16(ptr, id); F.w16(ptr + 2, qty ~ qtyKey()) end
end

local function inBag() return F.cb2() == (S.CB2_BagMenuRun & ~1) end

local function instantText()
  local a = F.sb2() + S.SaveBlock2.optionsU16
  F.w16(a, (F.r16(a) & ~7) | 3)
end

local function zeroParty()
  for off = 0, PARTY_SIZE * MON - 4, 4 do F.w32(S.gParties + off, 0) end
  F.w8(S.gPartiesCount, 0)
end

local function digits(n) n = n - 1; return n // 100, (n // 10) % 10, n % 10 end
-- A debug-menu open right after a Bag close can desync; retry from a flushed menu.
local function giveMon(species, level)
  for _ = 1, 3 do
    zeroParty()
    F.dbg(); F.idle(30); F.bOut(4)
    F.dbg(); F.sel(3); F.sel(1); F.idle(20)
    F.spin(digits(species)); F.idle(20)
    F.spin(digits(level)); F.idle(60); F.bOut(4)
    local m = decode(slotAddr(0))
    if F.r8(S.gPartiesCount) == 1 and m.species == species and m.level == level and m.checksumOk then return true end
    F.idle(60)
  end
  return false
end

local function openBagOnFirstItem()
  F.w8(S.gBagPosition + 5, POCKET_ITEMS)
  F.w16(S.gBagPosition + 8 + POCKET_ITEMS * 2, 0)
  F.w16(S.gBagPosition + 18 + POCKET_ITEMS * 2, 0)
  F.press("Start", 2); F.idle(60)
  if not F.selectStartIcon(USM_ICO_BAG) then return false end
  F.press("A", 2)
  for _ = 1, 150 do
    if inBag() then return true end
    F.idle(2)
  end
  return false
end

-- Drive the Bag from "candy chosen" onward with one key, tapped every `gap` frames, until the
-- candies are spent and the scene is back in the Bag. Records each move offered and whether an
-- evolution scene ran.
local function drive(tag, key, frames)
  local r = { offered = {}, order = {}, evolved = false, crash = false }
  local last = F.r16(S.gMoveToLearn)
  for i = 1, frames do
    if i % 8 == 0 and F.reportCrash(tag) then r.crash = true; break end
    local mv = F.r16(S.gMoveToLearn)
    if mv ~= last and mv ~= 0 then
      if not r.offered[mv] then r.order[#r.order + 1] = mv end
      r.offered[mv] = true
    end
    last = mv
    if F.r32(S.sEvoStructPtr) ~= 0 then r.evolved = true
    elseif r.evolved and inBag() then break end
    joypad.set((i % 20 < 2) and { [key] = true } or {})
    emu.frameadvance()
  end
  joypad.set({})
  local list = {}
  for _, v in ipairs(r.order) do list[#list + 1] = tostring(v) end
  r.list = table.concat(list, ",")
  F.L(string.format("  %s: offered=[%s] evolved=%s cb2=%08X", tag, r.list, tostring(r.evolved), F.cb2()))
  return r
end

local function backToField()
  for _ = 1, 40 do
    if F.ow() then break end
    F.press("B", 2); F.idle(20)
  end
  F.idle(30)
  return F.ow()
end

local function scenario(tag, body)
  if ONLY and not tag:find(ONLY, 1, true) then return end
  F.L("== " .. tag .. " ==")
  instantText()
  body(tag)
  if not backToField() then
    F.shot(tag:gsub("%W", "_") .. "_stuck")
    F.check(tag .. ": back on the field", false, string.format("cb2=%08X", F.cb2()))
  end
end

-- Give the Pokemon, set the candies, open the Bag and pick Use on slot 0. Returns false if any
-- step of the setup did not land.
local function useCandiesOn(species, tag, level, candies, uses, twoMoves)
  if not giveMon(species, level) then F.check(tag .. ": the debug Give made the Pokemon", false, describe(0)); return false end
  if twoMoves then keepTwoMoves(0) end
  F.L("  before " .. describe(0))
  setPocket(POCKET_ITEMS, ITEM_RARE_CANDY, candies)
  F.w16(S.gMoveToLearn, 0)
  if not openBagOnFirstItem() then F.check(tag .. ": the bag opened", false); return false end
  F.idle(30)
  F.press("A", 2); F.idle(40)       -- action menu
  F.press("A", 2); F.idle(60)       -- Use: party select on slot 0
  F.press("A", 2); F.idle(60)       -- slot 0 (with more than one candy, "Use how many?")
  if candies > 1 then
    for _ = 2, uses do F.press("Up", 2); F.idle(12) end
    F.press("A", 2)
  end
  return true
end

F.run(function()
  if not F.boot(HUB_GROUP) then F.check("boot to the hub", false); F.finish(); return end
  instantText()

  scenario("one candy, two free slots", function(tag)
    if not useCandiesOn(BULBASAUR, tag, 14, 1, 1, true) then return end
    local r = drive(tag, "A", 1500)
    local m = decode(slotAddr(0))
    F.L("  after " .. describe(0))
    F.check(tag .. ": no crash screen", not r.crash)
    F.check(tag .. ": Poison Powder was offered", r.offered[MOVE_POISON_POWDER] == true, "offered=" .. r.list)
    F.check(tag .. ": Sleep Powder was offered", r.offered[MOVE_SLEEP_POWDER] == true, "offered=" .. r.list)
    F.check(tag .. ": Bulbasaur is level 15 and knows both powders", m.species == BULBASAUR and m.level == 15
      and knows(m, MOVE_POISON_POWDER) and knows(m, MOVE_SLEEP_POWDER), describe(0))
    local ok, why = movesetSane(m)
    F.check(tag .. ": the moveset is unique with sane PP", ok and m.checksumOk, why)
    F.check(tag .. ": the candy was spent", countItem(ITEM_RARE_CANDY) == 0, "candies=" .. countItem(ITEM_RARE_CANDY))
  end)

  scenario("one candy, four moves, accept", function(tag)
    if not useCandiesOn(BULBASAUR, tag, 14, 1, 1, false) then return end
    local r = drive(tag, "A", 2400)
    local m = decode(slotAddr(0))
    F.L("  after " .. describe(0))
    F.check(tag .. ": no crash screen", not r.crash)
    F.check(tag .. ": Poison Powder was offered first", r.order[1] == MOVE_POISON_POWDER, "offered=" .. r.list)
    F.check(tag .. ": Sleep Powder was offered after it", r.order[2] == MOVE_SLEEP_POWDER, "offered=" .. r.list)
    F.check(tag .. ": the last accepted move is known", knows(m, MOVE_SLEEP_POWDER), describe(0))
    local ok, why = movesetSane(m)
    F.check(tag .. ": four unique moves with sane PP", ok and m.checksumOk and m.moves[4] ~= 0, why)
    F.check(tag .. ": level 15", m.level == 15, describe(0))
  end)

  scenario("one candy, four moves, cancel", function(tag)
    if not useCandiesOn(BULBASAUR, tag, 14, 1, 1, false) then return end
    local before = decode(slotAddr(0)).moves
    local r = drive(tag, "B", 700)
    local m = decode(slotAddr(0))
    F.L("  after " .. describe(0))
    F.check(tag .. ": no crash screen", not r.crash)
    F.check(tag .. ": both powders were offered", r.offered[MOVE_POISON_POWDER] == true
      and r.offered[MOVE_SLEEP_POWDER] == true, "offered=" .. r.list)
    local same = true
    for k = 1, 4 do if m.moves[k] ~= before[k] then same = false end end
    F.check(tag .. ": the old moveset is untouched", same and m.checksumOk, describe(0))
    F.check(tag .. ": level 15", m.level == 15, describe(0))
  end)

  scenario("three candies through 15 into Ivysaur", function(tag)
    if not useCandiesOn(BULBASAUR, tag, 13, 5, 3, true) then return end
    local r = drive(tag, "A", 4000)
    local m = decode(slotAddr(0))
    F.L("  after " .. describe(0))
    F.check(tag .. ": no crash screen", not r.crash)
    F.check(tag .. ": both powders were offered", r.offered[MOVE_POISON_POWDER] == true
      and r.offered[MOVE_SLEEP_POWDER] == true, "offered=" .. r.list)
    F.check(tag .. ": the evolution scene ran", r.evolved)
    F.check(tag .. ": Ivysaur at level 16 knowing both powders", m.species == IVYSAUR and m.level == 16
      and knows(m, MOVE_POISON_POWDER) and knows(m, MOVE_SLEEP_POWDER), describe(0))
    local ok, why = movesetSane(m)
    F.check(tag .. ": the moveset is unique with sane PP", ok and m.checksumOk, why)
    F.check(tag .. ": exactly three candies spent", countItem(ITEM_RARE_CANDY) == 2,
      "candies=" .. countItem(ITEM_RARE_CANDY))
  end)

  scenario("eight candies through Cradily's three level 43 moves", function(tag)
    if not useCandiesOn(CRADILY, tag, 40, 8, 8, false) then return end
    local before = decode(slotAddr(0)).moves
    local r = drive(tag, "A", 6000)
    local m = decode(slotAddr(0))
    F.L("  after " .. describe(0))
    F.check(tag .. ": no crash screen", not r.crash)
    F.check(tag .. ": Stockpile, Spit Up, Swallow and Energy Ball were offered in that order",
      r.order[1] == MOVE_STOCKPILE and r.order[2] == MOVE_SPIT_UP and r.order[3] == MOVE_SWALLOW
      and r.order[4] == MOVE_ENERGY_BALL and #r.order == 4, "offered=" .. r.list)
    F.check(tag .. ": Cradily is level 48 with Energy Ball in slot 1 and the rest untouched",
      m.species == CRADILY and m.level == 48 and m.moves[1] == MOVE_ENERGY_BALL and m.moves[2] == before[2]
      and m.moves[3] == before[3] and m.moves[4] == before[4], describe(0))
    local ok, why = movesetSane(m)
    F.check(tag .. ": the moveset is unique with sane PP", ok and m.checksumOk, why)
    F.check(tag .. ": all eight candies spent", countItem(ITEM_RARE_CANDY) == 0, "candies=" .. countItem(ITEM_RARE_CANDY))
  end)

  F.finish()
end)
