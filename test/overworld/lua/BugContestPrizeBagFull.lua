-- Bug-Catching Contest prize with a full bag: the prize must not vanish.
--
-- Judging hands out a stone (Items pocket) or a berry (Berries pocket). With both pockets full,
-- the prize goes to the item PC instead, and the player is told so.
--
-- Setup writes the region, gives a party through the debug menu, fills both pockets in RAM and
-- stands a debug-given Pokemon in for the catch. The attendant, retiring, choosing the kept
-- Pokemon, judging and the trip back to the gate use real input.
--
-- PW_PRIZE_PC_FULL=1 also fills the item PC: the prize is forfeited, and the player must be told
-- the bag is full rather than nothing.
--
-- Run via test/overworld/mgba-run.sh test/overworld/lua/BugContestPrizeBagFull.lua <rom.gba>

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "BugContestPrizeBagFull")

local REGION_JOHTO = 2
local GATE_G, GATE_M = 83, 7
local CONTEST_G, CONTEST_M = 83, 5
local FLAG_SYS_POKEMON_GET = 0x948
local FLAG_SYS_BUG_CONTEST_MODE = 0x948 + 0x21
local POCKET_ITEMS, POCKET_BERRIES = 0, 3
local ITEM_POTION, ITEM_LUM_BERRY = 28, 522
local PCITEMS_OFF, PC_ITEMS_COUNT = 0x4A0, 150
-- src/bug_contest.c JudgeBugContestMon reward tables
local PRIZES = { 217, 216, 214, 211, 213, 212, 520, 514, 521, 516, 517, 518, 515 }
local PC_FULL = os.getenv("PW_PRIZE_PC_FULL") == "1"

local function count() return F.r8(S.gPartiesCount) end
local function where() local x, y = F.pos(); return string.format("%d/%d (%d,%d)", F.grp(), F.mapn(), x, y) end
local function inContest() return F.grp() == CONTEST_G and F.mapn() == CONTEST_M end
local function atGate() return F.grp() == GATE_G and F.mapn() == GATE_M end
local function sb1Flag(id, on)
  local a, m = F.sb1() + S.SaveBlock1.flags + (id // 8), 1 << (id % 8)
  if on == nil then return (F.r8(a) & m) ~= 0 end
  F.w8(a, on and (F.r8(a) | m) or (F.r8(a) & ~m & 0xFF))
end
local function setJohto()
  F.w32(S.gCurrentRegion, REGION_JOHTO)
  F.w8(F.sb2() + S.SaveBlock2.currentRegion, REGION_JOHTO)
end

local function pocketPtr(p) return F.r32(S.gBagPockets + p * S.BagPocket.stride + S.BagPocket.itemsPtr) end
local function fillPocket(p, id)
  local ptr, cap = pocketPtr(p), F.pocketCap(p)
  if ptr < 0x02000000 or ptr >= 0x02040000 or cap < 1 or cap > 200 then return false end
  local qty = (1 ~ F.r32(F.sb2() + S.SaveBlock2.encryptionKey)) & 0xFFFF
  for s = 0, cap - 1 do F.w16(ptr + s * 4, id); F.w16(ptr + s * 4 + 2, qty) end
  return true
end
local function pocketFull(p, id)
  local ptr, cap = pocketPtr(p), F.pocketCap(p)
  for s = 0, cap - 1 do if F.r16(ptr + s * 4) ~= id then return false end end
  return cap > 0
end
local function pcHas(id)
  local base = F.sb1() + PCITEMS_OFF
  for i = 0, PC_ITEMS_COUNT - 1 do if F.r16(base + i * 4) == id then return true end end
  return false
end
local function fillPC(id)
  local base = F.sb1() + PCITEMS_OFF
  for i = 0, PC_ITEMS_COUNT - 1 do F.w16(base + i * 4, id); F.w16(base + i * 4 + 2, 1) end
end
local function prizeIn(where_)
  for _, id in ipairs(PRIZES) do
    if (where_ == "pc" and pcHas(id)) or (where_ == "bag" and F.itemCount(id) > 0) then return id end
  end
  return nil
end

local function text(addr, n)
  local t = {}
  for i = 0, n - 1 do
    local b = F.r8(addr + i)
    if b == 0xFF then break end
    if b >= 0xBB and b <= 0xD4 then t[#t + 1] = string.char(65 + b - 0xBB)
    elseif b >= 0xD5 and b <= 0xEE then t[#t + 1] = string.char(97 + b - 0xD5)
    else t[#t + 1] = " " end
  end
  return table.concat(t)
end

local function tapDown(n) for _ = 1, n do F.press("Down", 3); F.idle(16) end end
local function drain(tries)
  for i = 1, tries or 40 do
    F.press("B", 3); F.idle(20)
    if i % 5 == 0 and F.ensureFree() then return true end
  end
  return F.ensureFree()
end
local function debugAction(path, tag)
  F.dbg(); F.idle(60)
  for i, row in ipairs(path) do
    tapDown(row); F.press("A", 3); F.idle(i == #path and 240 or 60)
  end
  if not drain(20) then F.L("  debug action " .. tag .. " did not return to the field") return false end
  return true
end
local function give(sp)
  F.dbg(); F.idle(60)
  tapDown(3); F.press("A", 3); F.idle(50)
  tapDown(1); F.press("A", 3); F.idle(40)
  F.press("Right", 2); F.idle(10)
  for _ = 1, (sp // 10) % 10 do F.press("Up", 2); F.idle(8) end
  F.press("Left", 2); F.idle(10)
  for _ = 1, sp % 10 - 1 do F.press("Up", 2); F.idle(8) end
  F.press("A", 3); F.idle(30)
  F.press("A", 3); F.idle(80)
  for _ = 1, 10 do F.press("B", 3); F.idle(20) end
  drain(20)
end

F.run(function()
  if not F.boot(100) then F.check("boot to the hub", false); F.finish(); return end
  setJohto()
  sb1Flag(FLAG_SYS_POKEMON_GET, true)
  F.check("setup: debug Set Party ran", debugAction({ 2, 9 }, "set_party") and count() >= 1, "count=" .. count())

  if not F.warpTo(0, 8, 3, 0, 0, 7, 0, 0, 0, GATE_G, GATE_M, "gate") then
    F.check("warp to the National Park gate", false, where()); F.finish(); return
  end
  setJohto()

  F.leg(4, 2); F.face("Left"); F.press("A", 3); F.idle(40)
  for _ = 1, 400 do
    F.press("A", 2); F.idle(18)
    if inContest() and F.ow() then break end
  end
  drain(30)
  F.check("the attendant lets the player in", inContest() and sb1Flag(FLAG_SYS_BUG_CONTEST_MODE), where())

  give(13)
  F.check("setup: a contest catch joins the party", count() == 2, "count=" .. count())

  F.check("setup: Items and Berries pockets full of non-prize items",
    fillPocket(POCKET_ITEMS, ITEM_POTION) and fillPocket(POCKET_BERRIES, ITEM_LUM_BERRY)
      and pocketFull(POCKET_ITEMS, ITEM_POTION) and pocketFull(POCKET_BERRIES, ITEM_LUM_BERRY))
  F.check("setup: no prize item in the bag or the PC yet", not prizeIn("bag") and not prizeIn("pc"),
    string.format("bag=%s pc=%s", tostring(prizeIn("bag")), tostring(prizeIn("pc"))))

  if PC_FULL then fillPC(ITEM_POTION) end

  F.leg(13, 48)
  F.step("Down")
  local sawPC, sawFull = false, false
  for _ = 1, 1200 do
    if F.reportCrash("retire") then break end
    if atGate() and F.ow() and not sb1Flag(FLAG_SYS_BUG_CONTEST_MODE) then break end
    if not sawPC and text(S.gStringVar4, 160):find("BAG is full  so the") then
      sawPC = true; F.L("  message: " .. text(S.gStringVar4, 160)); F.shot("prize_to_pc_msg")
    end
    if not sawFull and text(S.gStringVar4, 160):find("Too bad") then
      sawFull = true; F.L("  message: " .. text(S.gStringVar4, 160)); F.shot("prize_bag_full_msg")
    end
    if F.cb2() == (S.CB2_UpdatePartyMenu & ~1) then
      F.idle(30); F.press("Down", 2); F.idle(20); F.press("A", 2); F.idle(40)
      if F.cb2() == (S.CB2_UpdatePartyMenu & ~1) then F.press("A", 2); F.idle(40) end
    else
      F.press("A", 2); F.idle(18)
    end
  end
  drain(30)
  F.shot("back_at_gate")
  F.check("the contest ends back at the gate", atGate() and not sb1Flag(FLAG_SYS_BUG_CONTEST_MODE), where())

  local pcPrize = prizeIn("pc")
  F.L(string.format("  prize in PC=%s bag=%s", tostring(pcPrize), tostring(prizeIn("bag"))))
  if PC_FULL then
    F.check("with the PC full too, the player is told the bag is full", sawFull and not sawPC)
  else
    F.check("the prize is not lost: it reached the item PC", pcPrize ~= nil,
      "no reward-table item in bag or PC after judging")
    F.check("the player is told the prize went to the PC", sawPC)
  end
  F.check("the bag pockets were left untouched", pocketFull(POCKET_ITEMS, ITEM_POTION) and pocketFull(POCKET_BERRIES, ITEM_LUM_BERRY))
  F.check("no crash", not F.crashScreen())
  F.finish()
end)
