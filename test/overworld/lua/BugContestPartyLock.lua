-- The Bug-Catching Contest parks the team in SaveBlock1 and takes only the lead in; the contest's
-- end reloads the parked team. While parked, the party menu must not offer the PC (R, Boxes) or the
-- held-item actions: a Pokemon withdrawn from the PC into the stand-in party is deleted at the end,
-- and an item given to or taken from the lead is undone or doubled (0829014ec0).
--
-- Setup gives a team with the debug Give menu and the region; the entry, the contest warp and the
-- party menu use real input. In the contest the suite opens the party from the Start menu, presses
-- R, and counts the lead's action rows (Summary and Cancel only); after retiring, the same R opens
-- the PC (control).
local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "BugContestPartyLock")

local REGION_JOHTO = 2
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
local function pcOpened()
  F.press("R", 2)
  for i = 1, 180 do
    F.idle(1)
    if not inPartyMenu() and not F.ow() and i > 40 then F.idle(90); return not inPartyMenu() and not F.ow() end
  end
  return false
end

local function leaveMenus()
  for _ = 1, 40 do
    if F.ow() and F.ensureFree() then return true end
    F.press("B", 3); F.idle(30)
  end
  return F.ow()
end

F.run(function()
  if not F.boot(100) then F.check("boot to the hub", false); F.finish(); return end
  setJohto()
  sb1Flag(FLAG_SYS_POKEMON_GET, true)
  for _, sp in ipairs(TEAM) do give(sp) end
  F.check("setup: a team of three", count() == 3, "count=" .. count())

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
  F.check("the attendant sends the player into the contest", inContest() and sb1Flag(FLAG_SYS_BUG_CONTEST_MODE),
    string.format("at %s state=%d", where(), contestState()))
  F.check("only the lead enters the contest", count() == 1, "count=" .. count())

  if not openParty() then F.check("open the party menu in the contest", false, where()); F.finish(); return end
  F.shot("contest_party")
  local pc = pcOpened()
  F.check("R in the contest party menu does not open the PC", not pc, string.format("cb2=%08X", F.cb2()))
  for _ = 1, 20 do
    if inPartyMenu() then break end
    F.press("B", 3); F.idle(40)
  end
  F.idle(40)
  if inPartyMenu() then
    F.press("A", 3); F.idle(50)
    F.shot("contest_lead_actions")
    -- The action menu is a standard menu (sMenu): rows = maxCursorPos + 1. Outside the contest the
    -- lead's list is Summary, Switch-free Item, Follow, Nickname, Cancel; parked, Summary and Cancel.
    local rows = F.rs8(S.sMenu + S.Menu.maxCursorPos) + 1
    F.check("the parked lead's action menu has no held-item, Follow or Nickname rows", rows == 2, "rows=" .. rows)
  end
  leaveMenus()

  if inContest() then
    F.leg(13, 48)
    F.step("Down")
    for _ = 1, 300 do
      F.press("A", 2); F.idle(18)
      if F.grp() == GATE_G and F.mapn() == GATE_M and F.ow() and count() == 3 then break end
    end
    drain(30)
  end
  F.check("retired with the team back", F.grp() == GATE_G and F.mapn() == GATE_M and count() == 3, where())
  local ctl = openParty() and pcOpened()
  F.shot("gate_after_R")
  F.check("control: after the contest R opens the PC", ctl, string.format("cb2=%08X", F.cb2()))
  leaveMenus()
  F.check("no crash screen", not F.crashScreen())
  F.finish()
end)
