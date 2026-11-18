-- The Bug-Catching Contest's lead is the player's own Pokemon: what the Bag does to it in the
-- contest must survive the contest's end.
--
-- The attendant parks the whole team with SavePlayerParty and takes only the lead in; every end
-- (retire, time up, judging, forfeit) puts the parked team back with LoadPlayerParty. The contest
-- start menu keeps the Bag, so a Rare Candy or an evolution stone used on the lead levels or evolves
-- it and is spent, and the end then restored the lead's pre-contest copy: the item was gone and the
-- evolution undone. In HGSS the lead keeps what happened to it during the contest.
--
-- Setup gives a team with the debug Give menu and one item; the entry, the Bag, the evolution scene
-- and the retirement use real input. Oracle: back at the gate the team has its old size, the lead is
-- the evolved species at the new level, the second Pokemon is untouched and the item is spent.
--
-- Run via test/overworld/mgba-run.sh test/overworld/lua/BugContestLeadKeeps.lua <rom>
-- PW_LEAD_ONLY=<text> (runner --env) runs only the scenarios whose tag contains <text>.
local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "BugContestLeadKeeps")

local ONLY = os.getenv("PW_LEAD_ONLY")
local REGION_JOHTO = 2
local GATE_G, GATE_M = 83, 7
local CONTEST_G, CONTEST_M = 83, 5
local FLAG_SYS_POKEMON_GET = 0x948
local FLAG_SYS_BUG_CONTEST_MODE = 0x948 + 0x21
local VAR_BUG_CONTEST_STATE = 0xA080 + 0x0E
local DAILY_CONTEST_BIT = 0xC1
local ATTENDANT_STAND = { 4, 2 }
local PARTY_SIZE = 6
local MON = S.Pokemon.size
local USM_ICO_BAG = 2
local POCKET_ITEMS = 0
local SPECIES_PIDGEY = 16

local function where() local x, y = F.pos(); return string.format("%d/%d (%d,%d)", F.grp(), F.mapn(), x, y) end
local function count() return F.r8(S.gPartiesCount) end
local function inContest() return F.grp() == CONTEST_G and F.mapn() == CONTEST_M end
local function atGate() return F.grp() == GATE_G and F.mapn() == GATE_M end
local function slotAddr(i) return S.gParties + i * MON end

local function sb1Flag(id, on)
  local a, m = F.sb1() + S.SaveBlock1.flags + (id // 8), 1 << (id % 8)
  if on == nil then return (F.r8(a) & m) ~= 0 end
  F.w8(a, on and (F.r8(a) | m) or (F.r8(a) & ~m & 0xFF))
end
local function clearDailyContest()
  local a = F.sb3() + S.SaveBlock3.johtoFlags + DAILY_CONTEST_BIT // 8
  F.w8(a, F.r8(a) & ~(1 << (DAILY_CONTEST_BIT % 8)) & 0xFF)
end
local function contestState() return F.r16(F.sb3() + S.SaveBlock3.regionVars + (VAR_BUG_CONTEST_STATE - 0xA000) * 2) end
local function setJohto()
  F.w32(S.gCurrentRegion, REGION_JOHTO)
  F.w8(F.sb2() + S.SaveBlock2.currentRegion, REGION_JOHTO)
end
local function instantText()
  local a = F.sb2() + S.SaveBlock2.optionsU16
  F.w16(a, (F.r16(a) & ~7) | 3)
end

local function decode(a)
  local pers, otid = F.r32(a), F.r32(a + 4)
  local key = pers ~ otid
  local w = {}
  for i = 0, 11 do w[i] = F.r32(a + 32 + i * 4) ~ key end
  local sum = 0
  for i = 0, 11 do sum = sum + (w[i] & 0xFFFF) + (w[i] >> 16) end
  local s0 = F.r8(S.sSubstructOffsets + pers % 24) * 3
  return { species = w[s0] & 0x7FF, level = F.r8(a + S.Pokemon.level), pers = pers,
           checksumOk = (sum & 0xFFFF) == F.r16(a + 28) }
end
local function describe(i)
  local m = decode(slotAddr(i))
  return string.format("[%d] sp=%d lv=%d sum=%s", i, m.species, m.level, m.checksumOk and "ok" or "BAD")
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

local function zeroParty()
  for off = 0, PARTY_SIZE * MON - 4, 4 do F.w32(S.gParties + off, 0) end
  F.w8(S.gPartiesCount, 0)
end
local function digits(n) n = n - 1; return n // 100, (n // 10) % 10, n % 10 end
local function giveMon(slot, species, level)
  for _ = 1, 3 do
    for off = slot * MON, PARTY_SIZE * MON - 4, 4 do F.w32(S.gParties + off, 0) end
    F.w8(S.gPartiesCount, slot)
    F.dbg(); F.idle(30); F.bOut(4)
    F.dbg(); F.sel(3); F.sel(1); F.idle(20)
    F.spin(digits(species)); F.idle(20)
    F.spin(digits(level)); F.idle(60); F.bOut(4)
    local m = decode(slotAddr(slot))
    if count() == slot + 1 and m.species == species and m.level == level and m.checksumOk then return true end
    F.idle(60)
  end
  return false
end

local function drain(tries)
  for i = 1, tries or 40 do
    F.press("B", 3); F.idle(20)
    if i % 5 == 0 and F.ensureFree() then return true end
  end
  return F.ensureFree()
end
local function backToField()
  for _ = 1, 40 do
    if F.ow() then break end
    F.press("B", 2); F.idle(20)
  end
  F.idle(30)
  return F.ow() and drain(10)
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

-- From the item's party select: A on slot 0 and A through the level-up and the evolution scene
-- (and any move it teaches) until the scene is over and the Bag is back.
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

local function enterContest(tag)
  clearDailyContest()
  if not F.warpTo(0, 8, 3, 0, 0, 7, 0, 0, 0, GATE_G, GATE_M, "gate") then
    F.check(tag .. ": warp to the National Park gate", false, where()); return false
  end
  setJohto()
  if not F.leg(ATTENDANT_STAND[1], ATTENDANT_STAND[2]) then
    F.check(tag .. ": walk to the contest attendant", false, where()); return false
  end
  F.face("Left")
  F.press("A", 3); F.idle(40)
  for _ = 1, 400 do
    F.press("A", 2); F.idle(18)
    if inContest() and F.ow() and contestState() == 2 then break end
    if F.reportCrash(tag .. " entry") then break end
  end
  drain(30)
  local ok = inContest() and sb1Flag(FLAG_SYS_BUG_CONTEST_MODE) and count() == 1
  F.check(tag .. ": the attendant takes only the lead into the contest", ok,
    string.format("at %s state=%d count=%d", where(), contestState(), count()))
  return ok
end

local function retire(tag, teamSize)
  F.leg(13, 48)
  F.step("Down")
  for _ = 1, 300 do
    F.press("A", 2); F.idle(18)
    if atGate() and F.ow() and count() == teamSize then break end
    if F.reportCrash(tag .. " retire") then break end
  end
  drain(30)
  F.check(tag .. ": retired to the gate with the team back", atGate() and count() == teamSize,
    string.format("at %s count=%d", where(), count()))
end

local SCENARIOS = {
  -- tag, lead species, level, item, evolved species, level after
  { "Rare Candy evolves Bulbasaur", 1, 15, 102, 2, 16 },
  { "Fire Stone evolves Growlithe", 58, 20, 211, 59, 20 },
}

F.run(function()
  if not F.boot(100) then F.check("boot to the hub", false); F.finish(); return end
  setJohto()
  sb1Flag(FLAG_SYS_POKEMON_GET, true)

  for _, sc in ipairs(SCENARIOS) do
    local tag, base, level, item, target, after = table.unpack(sc)
    if not ONLY or tag:find(ONLY, 1, true) then
      F.L("== " .. tag .. " ==")
      instantText()
      zeroParty()
      local made = giveMon(0, base, level) and giveMon(1, SPECIES_PIDGEY, 10)
      F.check(tag .. ": setup made the lead and a second Pokemon", made, describe(0) .. " " .. describe(1))
      local second = decode(slotAddr(1))
      setPocket(POCKET_ITEMS, item, 1)
      if made and enterContest(tag) then
        if openBagOnFirstItem() then
          F.idle(30)
          F.press("A", 2); F.idle(40)       -- action menu (Use is the first entry)
          F.press("A", 2); F.idle(60)       -- Use, then the party select
          local r = evolve(tag, 3000)
          F.L("  in the contest " .. describe(0))
          F.check(tag .. ": no crash screen in the evolution", not r.crash)
          F.check(tag .. ": the lead evolved in the contest", r.evolved and decode(slotAddr(0)).species == target, describe(0))
        else
          F.check(tag .. ": the Bag opened in the contest", false, where())
        end
        if not backToField() then F.shot(tag:gsub("%W", "_") .. "_stuck") end
        retire(tag, 2)
        local lead, mon2 = decode(slotAddr(0)), decode(slotAddr(1))
        F.L("  at the gate " .. describe(0) .. " " .. describe(1))
        F.shot(tag:gsub("%W", "_") .. "_gate")
        F.check(tag .. ": the lead is still the evolved species after the contest", lead.species == target and lead.checksumOk,
          describe(0))
        F.check(tag .. ": the lead kept its level", lead.level == after, describe(0))
        F.check(tag .. ": the second Pokemon came back untouched",
          mon2.species == second.species and mon2.pers == second.pers and mon2.level == second.level and mon2.checksumOk,
          describe(1))
        F.check(tag .. ": the item was spent once", countItem(item) == 0, "left=" .. countItem(item))
        F.check(tag .. ": contest mode is over", not sb1Flag(FLAG_SYS_BUG_CONTEST_MODE))
        F.check(tag .. ": control returns on the field", F.ow() and F.ensureFree(), string.format("cb2=%08X", F.cb2()))
      end
    end
  end
  F.check("no crash screen", not F.crashScreen())
  F.finish()
end)
