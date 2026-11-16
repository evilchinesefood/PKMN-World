-- A Battle Tower multi challenge carries the two chosen Pokemon into the partner room, where the
-- player walks freely. The lobby parks the whole party in SaveBlock1 (SavePlayerParty) and the
-- challenge's end puts it back with LoadPlayerParty, so the two-member stand-in party must not
-- reach the PC: a Pokemon deposited from it is cloned at the end (it is back in the party AND in
-- the box), and one withdrawn into it is deleted. The SwSh party menu opens the PC on R
-- (SWSH_PARTY_MENU_PC_ACCESS); the Bug Contest, Pike and Pyramid refuse it, and so must this room.
--
-- The suite gives six distinct Pokemon, takes the real Lv. 50 multi challenge at the lobby
-- attendant, rides the elevator to the partner room, opens the party from the Start menu and
-- presses R. If the PC opens it moves the second Pokemon into the box with real input, then quits
-- through the room attendant and counts each Pokemon's copies across the party and the boxes.
-- Control: back in the lobby, the same R opens the PC.
--
-- Run via test/overworld/mgba-run.sh test/overworld/lua/TowerMultiRoomBoxes.lua <rom>

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "TowerMultiRoomBoxes")

local HUB_GROUP = 100
local FRONTIER = 26
local TOWER_LOBBY, PARTNER_ROOM = 5, 15
local USM_ICO_PARTY = 1
local SLOTS = 14 * 30
local SPECIES = { 1, 4, 7, 25, 152, 258 }

local function party(slot) return S.gParties + slot * S.Pokemon.size end
local function box(slot) return F.r32(S.gPokemonStoragePtr) + 4 + slot * 80 end
local function present(a) return (F.r8(a + 19) & 2) ~= 0 end
local function pid(a) return F.r32(a) end
local function where() local x, y = F.pos(); return string.format("%d/%d (%d,%d)", F.grp(), F.mapn(), x, y) end

-- copies[pid] = how many times that Pokemon exists across the party and every box
local function copies()
  local c = {}
  for i = 0, 5 do if present(party(i)) then local p = pid(party(i)); c[p] = (c[p] or 0) + 1 end end
  for i = 0, SLOTS - 1 do if present(box(i)) then local p = pid(box(i)); c[p] = (c[p] or 0) + 1 end end
  return c
end

local function giveMon(species)
  local h, t, o = species // 100, (species // 10) % 10, species % 10
  F.dbg(); F.sel(3); F.sel(1); F.idle(20)
  F.spin(h, t, o); F.idle(20); F.spin(0, 3, 0); F.idle(60); F.bOut(4)
end

local function scriptMenuActive()
  for i = 0, S.Task.count - 1 do
    local a = S.gTasks + i * S.Task.stride
    local fn = F.r32(a + S.Task.func) & 0xFFFFFFFE
    if F.r8(a + S.Task.isActive) ~= 0
      and (fn == S.Task_HandleYesNoInput or fn == S.Task_HandleMultichoiceInput or fn == S.Task_CallYesOrNoCallback) then
      return true
    end
  end
  return false
end

local function menu(want, tag)
  for _ = 1, 80 do
    if scriptMenuActive() then
      F.idle(12)
      for _ = 1, 10 do
        local c = F.mcur()
        if c == want then
          F.shot(tag)
          F.press("A", 2); F.idle(40)
          return true
        end
        F.press(c > want and "Up" or "Down", 2); F.idle(12)
      end
      return false
    end
    F.press("A", 2); F.idle(25)
  end
  F.L("  menu " .. tag .. ": never opened")
  return false
end

local function inPartyMenu()
  local c = F.cb2()
  return c == (S.CB2_UpdatePartyMenu & ~1) or c == (S.CB2_InitPartyMenu & ~1)
    or c == (S.CB2_PartyMenuFromStartMenu & ~1)
end

local function choose(n)
  for _ = 1, 300 do
    if inPartyMenu() then break end
    F.press("A", 2); F.idle(20)
  end
  if not inPartyMenu() then return false end
  F.idle(60)
  for i = 1, n do
    F.press("A", 2); F.idle(30)
    F.press("A", 2); F.idle(40)
    if i < n then F.press("Down", 2); F.idle(20) end
  end
  F.press("Start", 2); F.idle(40)
  for _ = 1, 8 do
    if not inPartyMenu() then break end
    F.press("A", 2); F.idle(60)
  end
  return not inPartyMenu()
end

local function openParty()
  for _ = 1, 3 do
    F.press("Start", 2); F.idle(60)
    if F.selectStartIcon(USM_ICO_PARTY) then
      F.press("A", 2)
      for _ = 1, 200 do
        F.idle(3)
        if F.cb2() == (S.CB2_UpdatePartyMenu & ~1) then F.idle(60); return true end
      end
    end
    for _ = 1, 6 do F.press("B", 2); F.idle(20) end
  end
  return false
end

-- R in the party menu. Returns true when the screen left the party menu for something that is
-- not the field (the PC), watched for long enough to cover the fade.
local function pressRForPC()
  F.press("R", 2)
  for i = 1, 180 do
    F.idle(1)
    if not inPartyMenu() and not F.ow() and i > 40 then
      F.idle(90)
      return not inPartyMenu() and not F.ow()
    end
  end
  return false
end

local function backToField()
  for _ = 1, 60 do
    if F.ow() and F.ensureFree() then return true end
    F.press("B", 2); F.idle(30)
  end
  return F.ow()
end

F.run(function()
  if not F.boot(HUB_GROUP) then F.check("boot to the hub", false); F.finish(); return end
  for _, sp in ipairs(SPECIES) do giveMon(sp) end
  F.check("six Pokemon in the party", F.r8(S.gPartiesCount) == 6, "n=" .. F.r8(S.gPartiesCount))

  if not F.warpTo(0, 2, 6, 0, 0, 5, 0, 0, 0, FRONTIER, TOWER_LOBBY, "tower lobby") then
    F.check("warped to the Battle Tower lobby", false); F.finish(); return
  end
  if not F.ensureFree() then F.dismiss(10) end
  local reached = F.route({ { 12, 8 }, { 14, 8 }, { 14, 6 } }, "multis attendant")
  F.check("walked to the multi battle attendant", reached, where())
  F.face("Up")
  F.press("A", 2); F.idle(40)
  local took = menu(0, "take_challenge") and menu(0, "level_50")
  F.check("took the Lv. 50 multi challenge", took)
  local chose = took and choose(2)
  F.check("chose two Pokemon in the party screen", chose)
  local saved = chose and menu(0, "save_before")
  F.check("agreed to save before the challenge", saved)

  local arrived = false
  for i = 1, 6000 do
    if F.grp() == FRONTIER and F.mapn() == PARTNER_ROOM and F.ow() and i % 60 == 0 and F.ensureFree() then
      arrived = true
      break
    end
    if i % 40 == 1 then joypad.set({ A = true }) else joypad.set({}) end
    emu.frameadvance()
  end
  F.check("reached the partner room in control", arrived, where())
  F.check("the challenge carries two Pokemon", F.r8(S.gPartiesCount) == 2, "n=" .. F.r8(S.gPartiesCount))
  if not arrived then F.finish(); return end

  local opened = openParty()
  F.check("the partner room Start menu opens the party", opened, string.format("cb2=%08X", F.cb2()))
  if opened then
    F.shot("party_menu")
    local pc = pressRForPC()
    F.shot("after_R")
    F.check("R in the partner room party menu does not open the PC", not pc, string.format("cb2=%08X", F.cb2()))
    if pc then
      -- Deposit the lead: the PC opens on the party, A on a Pokemon then A on Store.
      -- The PC opens on the box: Left onto the second party slot, A for its menu, A on Move,
      -- Right into the box, A to place it there.
      for _, b in ipairs({ "Left", "A", "A", "Right", "A" }) do F.press(b, 2); F.idle(40) end
      F.shot("pc_deposited")
      F.L("  party after the deposit: n=" .. F.r8(S.gPartiesCount))
    end
  end
  backToField()

  F.face("Up")
  F.press("A", 2); F.idle(40)
  local quit = menu(0, "quit_partner_search")
  F.check("quit the challenge at the room attendant", quit, where())
  local back = false
  for i = 1, 3000 do
    if F.grp() == FRONTIER and F.mapn() == TOWER_LOBBY and F.ow() and i % 60 == 0 and F.ensureFree() then
      back = true
      break
    end
    if i % 40 == 1 then joypad.set({ B = true }) else joypad.set({}) end
    emu.frameadvance()
  end
  F.check("back in the lobby", back, where())

  local dup = {}
  local total = 0
  for p, n in pairs(copies()) do
    total = total + 1
    if n > 1 then dup[#dup + 1] = string.format("%08Xx%d", p, n) end
  end
  F.check("no Pokemon exists twice after the challenge", #dup == 0, table.concat(dup, ","))
  F.check("all six Pokemon are still owned", total == 6, "distinct=" .. total)

  -- Control: outside the challenge the same R opens the PC.
  local ctl = back and openParty()
  local ctlPc = ctl and pressRForPC()
  F.shot("lobby_after_R")
  F.check("control: R in the lobby party menu opens the PC", ctlPc, string.format("cb2=%08X", F.cb2()))
  backToField()
  F.finish()
end)
