-- The Pokemon chosen with the party menu's Follow must keep following when the party reorders.
--
-- followerSlot stores a party index. A party-menu Switch or a PC deposit moves Pokemon between
-- slots, and the index then names whichever Pokemon landed there.
--
-- Setup gives a three-Pokemon party through the debug menu. The Start menu, the party menu's
-- Follow and Switch, the PC (debug Access PC) and the deposit and withdraw use real input.
--
-- Run via test/overworld/mgba-run.sh test/overworld/lua/FollowerPartyReorder.lua <rom.gba>

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "FollowerPartyReorder")

local FLAG_SYS_POKEMON_GET = 0x948
local FOLLOWER = 0xFE
local OBJ_EVENT_MON = 0x4000
local USM_ICO_PARTY = 1
local PC_MENU_ROWS, PC_MOVE_MONS, PC_DEPOSIT, PC_WITHDRAW = 5, 0, 1, 2
local MON = S.Pokemon.size

local function count() return F.r8(S.gPartiesCount) end
local function sb1Flag(id)
  local a = F.sb1() + S.SaveBlock1.flags + (id // 8)
  F.w8(a, F.r8(a) | (1 << (id % 8)))
end
local function followerSlot() return F.r8(F.sb2() + S.SaveBlock2.followerSlot) end

local function species(i)
  local a = S.gParties + i * MON
  local pers = F.r32(a)
  local s0 = F.r8(S.sSubstructOffsets + pers % 24) * 3
  return (F.r32(a + 32 + s0 * 4) ~ pers ~ F.r32(a + 4)) & 0x7FF
end
local function partyList()
  local t = {}
  for i = 0, count() - 1 do t[#t + 1] = tostring(species(i)) end
  return table.concat(t, ",")
end

local function followerSpecies()
  for i = 0, 15 do
    local b = S.gObjectEvents + i * S.ObjectEvent.stride
    if (F.r8(b) & 1) == 1 and F.r8(b + S.ObjectEvent.localId) == FOLLOWER then
      local gfx = F.r16(b + S.ObjectEvent.graphicsId)
      if gfx & OBJ_EVENT_MON == 0 then return -1 end
      return gfx & 0x0FFF
    end
  end
  return -1
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

-- Re-entering the map respawns the follower from the current choice.
local function refresh()
  if not F.warpTo(1, 0, 0, 0, 0, 0, 0, 0, 0, 100, 0, "hub") then F.L("  refresh warp failed") end
  drain(10)
  F.idle(40)
end

local function menuMax() return F.rs8(S.sMenu + S.Menu.maxCursorPos) end
local function clearMenu() F.w8(S.sMenu + 2, 0); F.w8(S.sMenu + S.Menu.maxCursorPos, 0) end
local function pcMenuLive() return F.ow() and menuMax() == PC_MENU_ROWS - 1 end
local function cursorTo(row)
  for _ = 1, 8 do
    if F.mcur() == row then return true end
    F.press(F.mcur() < row and "Down" or "Up", 2); F.idle(12)
  end
  return F.mcur() == row
end

local function openPC()
  clearMenu()
  F.dbg(); F.idle(60)
  tapDown(1); F.press("A", 3); F.idle(60)
  F.press("A", 3); F.idle(60)
  for _ = 1, 200 do
    if pcMenuLive() then F.idle(30); return true end
    F.press("A", 2); F.idle(18)
  end
  return false
end
local function closePC()
  for _ = 1, 6 do
    if F.ow() and not pcMenuLive() then break end
    F.press("B", 2); F.idle(60)
  end
  drain(20)
end
local function exitStorage()
  for _ = 1, 4 do
    F.press("B", 2); F.idle(60)
    if F.ow() then break end
  end
  F.idle(60)
end

-- Deposit the party Pokemon at `slot` into the current box.
local function deposit(slot, tag)
  if not openPC() then F.shot(tag .. "_nopc"); return false end
  cursorTo(PC_DEPOSIT); F.press("A", 2); F.idle(150)
  for _ = 1, slot do F.press("Down", 2); F.idle(16) end
  F.press("A", 2); F.idle(40)
  F.shot(tag .. "_menu")
  F.press("A", 2); F.idle(60)
  F.press("A", 2); F.idle(90)
  F.shot(tag .. "_done")
  exitStorage()
  closePC()
  return true
end

local function withdraw(slot, tag)
  if not openPC() then F.shot(tag .. "_nopc"); return false end
  cursorTo(PC_WITHDRAW); F.press("A", 2); F.idle(150)
  for _ = 1, slot do F.press("Right", 2); F.idle(16) end
  F.press("A", 2); F.idle(40)
  F.shot(tag .. "_menu")
  F.press("A", 2); F.idle(90)
  F.shot(tag .. "_done")
  exitStorage()
  closePC()
  return true
end

local function openParty()
  F.press("Start", 2); F.idle(60)
  if not F.selectStartIcon(USM_ICO_PARTY) then F.L("  party icon not found"); return false end
  F.press("A", 2); F.idle(90)
  if F.cb2() ~= (S.CB2_UpdatePartyMenu & ~1) then F.L("  party menu did not open"); return false end
  return true
end
local function closeParty()
  for _ = 1, 4 do
    F.press("B", 2); F.idle(60)
    if F.ow() then break end
  end
  drain(20)
end

-- The field action list ends Follow, Nickname, Cancel (src/swsh_party_menu.c).
local function partyFollow(slot, tag)
  if not openParty() then return false end
  for _ = 1, slot do F.press("Down", 2); F.idle(12) end
  F.press("A", 2); F.idle(40)
  for _ = 1, menuMax() - 2 do F.press("Down", 2); F.idle(12) end
  F.shot(tag .. "_follow_row")
  F.press("A", 2); F.idle(60)
  F.press("A", 2); F.idle(40)
  closeParty()
  return true
end

local function partySwitch(a, b)
  if not openParty() then return false end
  for _ = 1, a do F.press("Down", 2); F.idle(12) end
  F.press("L", 2); F.idle(40)
  for _ = 1, b - a do F.press("Down", 2); F.idle(12) end
  F.shot("switch_target")
  F.press("A", 2); F.idle(90)
  F.shot("switched")
  closeParty()
  return true
end

F.run(function()
  if not F.boot(100) then F.check("boot to the hub", false); F.finish(); return end
  sb1Flag(FLAG_SYS_POKEMON_GET)
  F.check("setup: debug Set Party ran", debugAction({ 2, 9 }, "set_party") and count() >= 1, "count=" .. count())
  for _, sp in ipairs({ 19, 21 }) do give(sp) end
  local A, B, C = species(0), species(1), species(2)
  F.check("setup: three different species in the party", count() == 3 and A ~= B and B ~= C and A ~= C,
    "party=" .. partyList())

  F.check("Follow chosen on the second Pokemon", partyFollow(1, "second") and followerSlot() == 2, "slot=" .. followerSlot())
  refresh()
  F.shot("chosen_second")
  F.check("setup: the second Pokemon follows", followerSpecies() == B,
    string.format("follower=%d want=%d party=%s", followerSpecies(), B, partyList()))

  F.check("party-menu Switch of slots 1 and 2 ran", partySwitch(0, 1) and species(0) == B and species(1) == A,
    "party=" .. partyList())
  refresh()
  F.shot("after_switch")
  F.check("after a party Switch the chosen Pokemon still follows", followerSpecies() == B,
    string.format("follower=%d want=%d slot=%d party=%s", followerSpecies(), B, followerSlot(), partyList()))

  F.check("Follow chosen on the third Pokemon", partyFollow(2, "third") and followerSlot() == 3, "slot=" .. followerSlot())
  refresh()
  F.check("setup: the third Pokemon follows", followerSpecies() == C,
    string.format("follower=%d want=%d", followerSpecies(), C))
  F.check("PC deposit of the lead ran", deposit(0, "deposit_lead") and count() == 2 and species(0) == A and species(1) == C,
    "party=" .. partyList())
  refresh()
  F.shot("after_deposit")
  F.check("after depositing a Pokemon ahead of it the chosen Pokemon still follows", followerSpecies() == C,
    string.format("follower=%d want=%d slot=%d party=%s", followerSpecies(), C, followerSlot(), partyList()))

  F.check("PC deposit of the follower ran", deposit(1, "deposit_follower") and count() == 1, "party=" .. partyList())
  refresh()
  F.check("with the chosen Pokemon boxed the lead follows", followerSpecies() == A,
    string.format("follower=%d want=%d slot=%d", followerSpecies(), A, followerSlot()))
  F.check("PC withdraw of both boxed Pokemon ran", withdraw(1, "withdraw_c") and withdraw(0, "withdraw_b")
    and count() == 3 and species(2) == B, "party=" .. partyList())
  refresh()
  F.shot("after_withdraw")
  F.check("a withdrawn Pokemon does not take over as follower", followerSpecies() == A,
    string.format("follower=%d want=%d slot=%d party=%s", followerSpecies(), A, followerSlot(), partyList()))
  F.check("no crash", not F.crashScreen())
  F.finish()
end)
