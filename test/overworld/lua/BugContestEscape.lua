-- The Bug-Catching Contest keeps only the first Pokemon and parks the rest in the saved-party slot
-- until the contest ends. Leaving the contest map by Teleport skips that ending: the player walks
-- off with one Pokemon, FLAG_SYS_BUG_CONTEST_MODE stays set (which also hides SAVE), and the next
-- SavePlayerParty overwrites the parked team. The contest must refuse Teleport, as HGSS does.
-- Setup writes only the party (debug Give) and the region; the entry, the contest warp and the
-- Teleport attempt use real input.
local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "BugContestEscape")

local REGION_JOHTO = 2
local SPECIES_ABRA, MOVE_TELEPORT = 63, 100
local TEAM = { 16, 19, 10 }
local GATE_G, GATE_M = 83, 7
local CONTEST_G, CONTEST_M = 83, 5
local FLAG_SYS_POKEMON_GET = 0x948
local FLAG_SYS_BUG_CONTEST_MODE = 0x948 + 0x21
local VAR_BUG_CONTEST_STATE = 0xA080 + 0x0E
local ATTENDANT_STAND = { 4, 2 }
local ROW_GIVE, ROW_MON_BASIC = 3, 1

local OFF_CHECKSUM, OFF_SECURE = 28, 32
local SUB0 = { [0]=0,0,0,0,0,0,1,1,2,3,2,3,1,1,2,3,2,3,1,1,2,3,2,3 }
local SUB1 = { [0]=1,1,2,3,2,3,0,0,0,0,0,0,2,3,1,1,3,2,2,3,1,1,3,2 }

local function count() return F.r8(S.gPartiesCount) end
local function where() local x, y = F.pos(); return string.format("%d/%d (%d,%d)", F.grp(), F.mapn(), x, y) end
local function inContest() return F.grp() == CONTEST_G and F.mapn() == CONTEST_M end

local function sb1Flag(id, on)
  local a, m = F.sb1() + S.SaveBlock1.flags + (id // 8), 1 << (id % 8)
  if on == nil then return (F.r8(a) & m) ~= 0 end
  F.w8(a, on and (F.r8(a) | m) or (F.r8(a) & ~m & 0xFF))
end
local function contestState() return F.r16(F.sb3() + S.SaveBlock3.regionVars + (VAR_BUG_CONTEST_STATE - 0xA000) * 2) end
local function setJohto()
  F.w32(S.gCurrentRegion, REGION_JOHTO)
  F.w8(F.sb2() + S.SaveBlock2.currentRegion, REGION_JOHTO)
end

local function xorSecure(mon)
  local key = F.r32(mon) ~ F.r32(mon + 4)
  for i = 0, 11 do local a = mon + OFF_SECURE + i * 4; F.w32(a, F.r32(a) ~ key) end
end
local function checksum(mon)
  local sum = 0
  for i = 0, 11 do local w = F.r32(mon + OFF_SECURE + i * 4); sum = (sum + w + (w >> 16)) & 0xFFFFFFFF end
  return sum & 0xFFFF
end
local function species(slot)
  local mon = S.gParties + slot * S.Pokemon.size
  xorSecure(mon)
  local sp = F.r16(mon + OFF_SECURE + SUB0[F.r32(mon) % 24] * 12) & 0x7FF
  xorSecure(mon)
  return sp
end
local function setMove1(slot, move)
  local mon = S.gParties + slot * S.Pokemon.size
  xorSecure(mon)
  local sub = mon + OFF_SECURE + SUB1[F.r32(mon) % 24] * 12
  F.w16(sub, (F.r16(sub) & 0xF800) | move)
  F.w8(sub + 8, (F.r8(sub + 8) & 0x80) | 20)
  F.w16(mon + OFF_CHECKSUM, checksum(mon))
  xorSecure(mon)
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

local function inPartyMenu()
  local c = F.cb2()
  return c == S.CB2_UpdatePartyMenu or c == S.CB2_InitPartyMenu or c == S.CB2_PartyMenuFromStartMenu
end

local function openParty()
  for _ = 1, 4 do
    F.press("Start", 2); F.idle(90)
    if F.selectStartIcon(1) then
      F.press("A", 3)
      for _ = 1, 240 do F.idle(4); if inPartyMenu() then F.idle(40); return true end end
    end
    for _ = 1, 6 do F.press("B", 3); F.idle(20) end
  end
  return false
end

-- A on slot 0, Down onto TELEPORT (row 1), then hold YES through the confirmation.
local function tryTeleport()
  F.press("A", 3); F.idle(50)
  F.press("Down", 2); F.idle(12)
  F.shot("teleport_row")
  F.press("A", 3); F.idle(40)
  for _ = 1, 40 do
    F.press("Up", 2); F.idle(6)
    F.press("A", 2); F.idle(16)
    if not inPartyMenu() then break end
  end
  for _ = 1, 600 do
    F.idle(2)
    if F.ow() and not inPartyMenu() then break end
    if F.reportCrash("teleport") then return end
  end
  F.idle(120)
  drain(30)
end

F.run(function()
  if not F.boot(100) then F.check("boot to the hub", false); F.finish(); return end
  setJohto()
  sb1Flag(FLAG_SYS_POKEMON_GET, true)

  give(SPECIES_ABRA)
  for _, sp in ipairs(TEAM) do give(sp) end
  setMove1(0, MOVE_TELEPORT)
  F.check("setup: Abra leads a party of four", count() == 4 and species(0) == SPECIES_ABRA,
    string.format("count=%d lead=%d", count(), species(0)))

  if not F.warpTo(0, 8, 3, 0, 0, 7, 0, 0, 0, GATE_G, GATE_M, "gate") then
    F.check("warp to the National Park gate", false, where()); F.finish(); return
  end
  setJohto()
  if not F.leg(ATTENDANT_STAND[1], ATTENDANT_STAND[2]) then
    F.check("walk to the contest attendant", false, where()); F.finish(); return
  end
  F.face("Left")
  F.press("A", 3); F.idle(40)
  for _ = 1, 400 do
    F.press("A", 2); F.idle(18)
    if inContest() and F.ow() and contestState() == 2 then break end
    if F.reportCrash("entry") then break end
  end
  drain(30)
  F.shot("in_contest")
  F.check("the attendant sends the player into the contest", inContest() and sb1Flag(FLAG_SYS_BUG_CONTEST_MODE),
    string.format("at %s mode=%s state=%d", where(), tostring(sb1Flag(FLAG_SYS_BUG_CONTEST_MODE)), contestState()))
  F.check("only the lead Pokemon enters the contest", count() == 1 and species(0) == SPECIES_ABRA,
    string.format("count=%d lead=%d", count(), species(0)))

  if not openParty() then F.check("open the party menu in the contest", false, where()); F.finish(); return end
  tryTeleport()
  F.shot("after_teleport")
  local mode = sb1Flag(FLAG_SYS_BUG_CONTEST_MODE)
  F.check("Teleport does not leave the contest map", inContest(), "at " .. where())
  F.check("leaving never strands the parked team", inContest() or not mode or count() == 4,
    string.format("at %s count=%d contestMode=%s", where(), count(), tostring(mode)))
  F.check("no crash after the Teleport attempt", not F.crashScreen())

  if inContest() then
    F.leg(13, 48)
    F.step("Down")
    for _ = 1, 300 do
      F.press("A", 2); F.idle(18)
      if F.grp() == GATE_G and F.mapn() == GATE_M and F.ow() and count() == 4 then break end
    end
    drain(30)
    F.shot("retired")
    F.check("retiring at the exit still ends the contest and returns the team",
      F.grp() == GATE_G and F.mapn() == GATE_M and count() == 4 and not sb1Flag(FLAG_SYS_BUG_CONTEST_MODE),
      string.format("at %s count=%d contestMode=%s", where(), count(), tostring(sb1Flag(FLAG_SYS_BUG_CONTEST_MODE))))
  end
  F.finish()
end)
