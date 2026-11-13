-- The Bug-Catching Contest hands out 30 contest balls. With a full Poke Balls pocket the attendant
-- must refuse before anything changes; with room the player gets exactly 30, and the contest's end
-- takes back every contest ball and nothing else. Setup writes the Balls pocket, the region and a
-- debug-given Pokemon; the attendant, the contest and retiring at the exit use real input.
local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "BugContestBalls")

local REGION_JOHTO = 2
local POCKET_POKE_BALLS = 1
local ITEM_SAFARI_BALL = 23
local GATE_G, GATE_M = 83, 7
local CONTEST_G, CONTEST_M = 83, 5
local FLAG_SYS_POKEMON_GET = 0x948
local FLAG_SYS_BUG_CONTEST_MODE = 0x948 + 0x21
local ROW_GIVE, ROW_MON_BASIC = 3, 1

local function count() return F.r8(S.gPartiesCount) end
local function where() local x, y = F.pos(); return string.format("%d/%d (%d,%d)", F.grp(), F.mapn(), x, y) end
local function inContest() return F.grp() == CONTEST_G and F.mapn() == CONTEST_M end
local function sb1Flag(id, on)
  local a, m = F.sb1() + S.SaveBlock1.flags + (id // 8), 1 << (id % 8)
  if on == nil then return (F.r8(a) & m) ~= 0 end
  F.w8(a, on and (F.r8(a) | m) or (F.r8(a) & ~m & 0xFF))
end
local function setJohto()
  F.w32(S.gCurrentRegion, REGION_JOHTO)
  F.w8(F.sb2() + S.SaveBlock2.currentRegion, REGION_JOHTO)
end

local function key() return F.r16(F.sb2() + S.SaveBlock2.encryptionKey) end
local function slotAddr(i) return F.r32(S.gBagPockets + POCKET_POKE_BALLS * S.BagPocket.stride) + i * 4 end
local function setSlot(i, id, qty) F.w16(slotAddr(i), id); F.w16(slotAddr(i) + 2, id == 0 and 0 or (qty ~ key())) end
local function quantityOf(id)
  local n = 0
  for i = 0, F.pocketCap(POCKET_POKE_BALLS) - 1 do
    if F.r16(slotAddr(i)) == id then n = n + (F.r16(slotAddr(i) + 2) ~ key()) end
  end
  return n
end
local function otherBalls()
  local n = 0
  for i = 0, F.pocketCap(POCKET_POKE_BALLS) - 1 do
    local id = F.r16(slotAddr(i))
    if id ~= 0 and id ~= ITEM_SAFARI_BALL then n = n + 1 end
  end
  return n
end

local function tapDown(n) for _ = 1, n do F.press("Down", 3); F.idle(16) end end
local function drain(tries)
  for i = 1, tries or 40 do
    F.press("B", 3); F.idle(20)
    if i % 5 == 0 and F.ensureFree() then return true end
  end
  return F.ensureFree()
end
local function give(sp)
  F.dbg(); F.idle(60)
  tapDown(ROW_GIVE); F.press("A", 3); F.idle(50)
  tapDown(ROW_MON_BASIC); F.press("A", 3); F.idle(40)
  F.press("Right", 2); F.idle(10)
  for _ = 1, (sp // 10) % 10 do F.press("Up", 2); F.idle(8) end
  F.press("Left", 2); F.idle(10)
  for _ = 1, sp % 10 - 1 do F.press("Up", 2); F.idle(8) end
  F.press("A", 3); F.idle(30)
  F.press("A", 3); F.idle(80)
  for _ = 1, 10 do F.press("B", 3); F.idle(20) end
  drain(20)
end

local function talkToAttendant()
  F.leg(4, 2)
  F.face("Left")
  F.press("A", 3); F.idle(40)
end

F.run(function()
  if not F.boot(100) then F.check("boot to the hub", false); F.finish(); return end
  setJohto()
  sb1Flag(FLAG_SYS_POKEMON_GET, true)
  give(16)
  F.check("setup: one Pokemon in the party", count() == 1, "count=" .. count())

  local cap = F.pocketCap(POCKET_POKE_BALLS)
  for i = 0, cap - 1 do setSlot(i, i + 1, 5) end
  F.check("setup: every Poke Balls slot holds a different ball", otherBalls() == cap, "cap=" .. cap)

  if not F.warpTo(0, 8, 3, 0, 0, 7, 0, 0, 0, GATE_G, GATE_M, "gate") then
    F.check("warp to the National Park gate", false, where()); F.finish(); return
  end
  setJohto()
  talkToAttendant()
  for _ = 1, 30 do F.press("A", 2); F.idle(24); if inContest() then break end end
  for _ = 1, 20 do F.press("B", 3); F.idle(20) end
  local free = F.step("Down") and F.step("Up")
  F.face("Left")
  F.shot("full_pocket")
  F.check("a full Balls pocket keeps the player out of the contest", not inContest() and not sb1Flag(FLAG_SYS_BUG_CONTEST_MODE), where())
  F.check("the refusal hands out no contest balls", quantityOf(ITEM_SAFARI_BALL) == 0 and otherBalls() == cap,
    string.format("safari=%d other=%d", quantityOf(ITEM_SAFARI_BALL), otherBalls()))
  F.check("the player is free after the refusal", free, where())

  setSlot(cap - 1, 0, 0)
  talkToAttendant()
  for _ = 1, 400 do
    F.press("A", 2); F.idle(18)
    if inContest() and F.ow() then break end
  end
  drain(30)
  F.shot("entered")
  F.check("with one free slot the player enters the contest", inContest() and sb1Flag(FLAG_SYS_BUG_CONTEST_MODE), where())
  F.check("the attendant gives exactly 30 contest balls", quantityOf(ITEM_SAFARI_BALL) == 30,
    "safari=" .. quantityOf(ITEM_SAFARI_BALL))

  F.leg(13, 48)
  F.step("Down")
  for _ = 1, 300 do
    F.press("A", 2); F.idle(18)
    if F.grp() == GATE_G and F.mapn() == GATE_M and F.ow() and not sb1Flag(FLAG_SYS_BUG_CONTEST_MODE) then break end
  end
  drain(30)
  F.shot("retired")
  F.check("retiring returns the player to the gate", F.grp() == GATE_G and F.mapn() == GATE_M, where())
  F.check("the contest end takes back every contest ball", quantityOf(ITEM_SAFARI_BALL) == 0,
    "safari=" .. quantityOf(ITEM_SAFARI_BALL))
  F.check("the contest end leaves the player's own balls alone", otherBalls() == cap - 1,
    string.format("other=%d want %d", otherBalls(), cap - 1))
  F.check("the party comes back intact", count() == 1, "count=" .. count())
  F.check("no crash", not F.crashScreen())
  F.finish()
end)
