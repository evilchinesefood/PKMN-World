-- Trade evolutions that need a held item must work from the Bag.
--
-- Link trade is compiled out, and FEATURES.md promises trade evolutions work offline: the
-- department stores and Mahogany's shop sell the Linking Cord and the held evolution items
-- (Metal Coat, King's Rock, Dragon Scale, Up-Grade, Deep Sea Tooth and Scale) to be used like
-- stones. The species table has the matching EVO_ITEM rows, but I_USE_EVO_HELD_ITEMS_FROM_BAG is
-- FALSE, so those items carried ItemUseOutOfBattle_CannotUse: "Use" only printed Dad's advice and
-- Scizor, Steelix, Kingdra, Porygon2, Slowking, Politoed, Huntail and Gorebyss could not be made.
--
-- Each scenario gives the base species through the debug Give menu and one item in the Items
-- pocket, then with real input opens the Bag, picks Use, picks the party slot and drives the
-- evolution with A. Oracle: the Bag armed an evolution-stone use, the species changed to the
-- target and the item was spent. The Kadabra + Linking Cord row is the control (already worked).
--
-- Run via test/overworld/mgba-run.sh test/overworld/lua/HeldItemTradeEvolution.lua <rom>
-- PW_EVO_ONLY=<text> (runner --env) runs only the scenarios whose tag contains <text>.

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "HeldItemTradeEvolution")

local HUB_GROUP = 100
local ONLY = os.getenv("PW_EVO_ONLY")
local PARTY_SIZE = 6
local MON = S.Pokemon.size
local USM_ICO_BAG = 2
local POCKET_ITEMS = 0
local LEVEL = 30

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

local function describe(i)
  local m = decode(slotAddr(i))
  return string.format("[%d] sp=%d lv=%d moves=%d,%d,%d,%d pp=%d,%d,%d,%d sum=%s", i, m.species, m.level,
    m.moves[1], m.moves[2], m.moves[3], m.moves[4], m.pp[1], m.pp[2], m.pp[3], m.pp[4],
    m.checksumOk and "ok" or "BAD")
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

-- From the item's party select, A on slot 0 and A through the evolution scene (and any move it
-- teaches) until the scene is over and the Bag is back.
local function evolve(tag, frames)
  local r = { evolved = false, crash = false }
  for i = 1, frames do
    if i % 8 == 0 and F.reportCrash(tag) then r.crash = true; break end
    if F.r32(S.sEvoStructPtr) ~= 0 then r.evolved = true
    elseif r.evolved and inBag() then break end
    joypad.set((i % 20 < 2) and { A = true } or {})
    emu.frameadvance()
  end
  joypad.set({})
  return r
end

local ROWS = {
  { "Scyther + Metal Coat", 123, 441, 212 },
  { "Onix + Metal Coat", 95, 441, 208 },
  { "Seadra + Dragon Scale", 117, 227, 230 },
  { "Porygon + Up-Grade", 137, 228, 233 },
  { "Slowpoke + King's Rock", 79, 465, 199 },
  { "Poliwhirl + King's Rock", 61, 465, 186 },
  { "Clamperl + Deep Sea Tooth", 366, 399, 367 },
  { "Clamperl + Deep Sea Scale", 366, 398, 368 },
  { "Kadabra + Linking Cord (control)", 64, 796, 65 },
}

F.run(function()
  if not F.boot(HUB_GROUP) then F.check("boot to the hub", false); F.finish(); return end
  instantText()

  for _, row in ipairs(ROWS) do
    local name, base, item, target = row[1], row[2], row[3], row[4]
    scenario(name, function(tag)
      if not giveMon(base, LEVEL) then F.check(tag .. ": the debug Give made the base species", false, describe(0)); return end
      setPocket(POCKET_ITEMS, item, 1)
      if not openBagOnFirstItem() then F.check(tag .. ": the bag opened", false); return end
      F.idle(30)
      F.press("A", 2); F.idle(40)       -- action menu (Use is the first entry)
      F.press("A", 2); F.idle(60)       -- Use
      F.shot(tag:gsub("%W", "_") .. "_use")
      local cb, used = F.r32(S.gItemUseCB) & ~1, F.r16(S.gSpecialVar_ItemId)
      F.check(tag .. ": Use opens the party to evolve", cb == (S.ItemUseCB_EvolutionStone & ~1) and used == item,
        string.format("cb=%08X item=%d", cb, used))
      local r = evolve(tag, 2400)
      F.L("  after " .. describe(0))
      F.check(tag .. ": no crash screen", not r.crash)
      F.check(tag .. ": the evolution scene ran", r.evolved)
      F.check(tag .. ": the POKéMON evolved into its trade evolution", decode(slotAddr(0)).species == target, describe(0))
      F.check(tag .. ": the item was spent", countItem(item) == 0, "left=" .. countItem(item))
    end)
  end

  F.finish()
end)
