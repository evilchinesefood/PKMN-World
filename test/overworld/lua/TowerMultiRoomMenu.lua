-- A Battle Tower multi challenge carries the two chosen Pokemon into the partner room, where the
-- player walks freely to pick a partner. The lobby keeps the whole party in SaveBlock1's party
-- copy until the challenge ends, and a Start-menu save there writes the two-member party over
-- that copy. The partner room menu must match the vanilla one (BuildMultiPartnerRoomStartMenu):
-- no Save and no Bag.
--
-- The suite gives six distinct Pokemon, takes the real Lv. 50 multi challenge at the lobby
-- attendant, rides the elevator to the partner room, tries Save and looks for the Bag there,
-- quits through the room attendant, then cuts the power and continues.
--
-- Run via test/overworld/mgba-run.sh test/overworld/lua/TowerMultiRoomMenu.lua <rom>

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "TowerMultiRoomMenu")

local HUB_GROUP = 100
local FRONTIER = 26
local TOWER_LOBBY, PARTNER_ROOM = 5, 15
local USM_ICO_BAG, USM_ICO_SAVE = 2, 7
local SENTINEL = 0xFFFF
local SLOTS = 14 * 30
local SPECIES = { 1, 4, 7, 25, 152, 258 }

local function party(slot) return S.gParties + slot * S.Pokemon.size end
local function box(slot) return F.r32(S.gPokemonStoragePtr) + 4 + slot * 80 end
local function present(a) return (F.r8(a + 19) & 2) ~= 0 end
local function pid(a) return F.r32(a) end
local function where() local x, y = F.pos(); return string.format("%d/%d (%d,%d)", F.grp(), F.mapn(), x, y) end

local function owned()
  local seen, n = {}, 0
  for i = 0, 5 do if present(party(i)) then seen[pid(party(i))] = "party" .. i; n = n + 1 end end
  for i = 0, SLOTS - 1 do if present(box(i)) then seen[pid(box(i))] = "box" .. i; n = n + 1 end end
  return seen, n
end

local function missing(before)
  local now = owned()
  local lost = {}
  for p, w in pairs(before) do
    if not now[p] then lost[#lost + 1] = string.format("%08X(was %s)", p, w) end
  end
  return lost
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

-- Advance text with A until a script menu is up, then move the cursor to `want` and confirm.
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

local function inPartyMenu() return F.cb2() == (S.CB2_UpdatePartyMenu & ~1) end

-- The frontier party screen: A on a member opens Enter/Summary/Cancel with Enter first.
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
  F.shot("chosen")
  F.press("Start", 2); F.idle(40)
  for _ = 1, 8 do
    if not inPartyMenu() then break end
    F.press("A", 2); F.idle(60)
  end
  return not inPartyMenu()
end

local function openSave()
  F.press("Start", 2); F.idle(60)
  return F.selectStartIcon(USM_ICO_SAVE)
end

local function bagOffered()
  F.press("Start", 2); F.idle(60)
  local offered = F.selectStartIcon(USM_ICO_BAG)
  F.shot("bag_icon")
  for _ = 1, 6 do F.press("B", 2); F.idle(20) end
  return offered
end

local function tryStartSave()
  F.w16(S.gSaveAttemptStatus, SENTINEL)
  local c0 = F.r32(S.gSaveCounter)
  local offered = openSave()
  F.shot("start_menu")
  if offered then
    for i = 1, 3000 do
      if F.r16(S.gSaveAttemptStatus) ~= SENTINEL then break end
      if i % 20 == 1 then joypad.set({ A = true }) else joypad.set({}) end
      emu.frameadvance()
    end
    F.idle(30)
  end
  for _ = 1, 6 do F.press("B", 2); F.idle(20) end
  return offered, F.r32(S.gSaveCounter) ~= c0
end

F.run(function()
  if not F.boot(HUB_GROUP) then F.check("boot to the hub", false); F.finish(); return end
  for _, sp in ipairs(SPECIES) do giveMon(sp) end
  F.check("six Pokemon in the party", F.r8(S.gPartiesCount) == 6, "n=" .. F.r8(S.gPartiesCount))
  local before, n0 = owned()
  F.L("  owned before the challenge: " .. n0)

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

  local offered, wrote = tryStartSave()
  F.L(string.format("  partner room Start menu: save offered=%s wrote=%s", tostring(offered), tostring(wrote)))
  F.check("the partner room start menu does not offer Save", not offered)

  F.check("the partner room start menu does not offer the Bag", not bagOffered())

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
  F.check("back in the lobby with six Pokemon", back and F.r8(S.gPartiesCount) == 6,
    where() .. " n=" .. F.r8(S.gPartiesCount))

  client.reboot_core()
  F.idle(60)
  local booted = F.boot(nil, true)
  F.check("Continue after the power cut reached the field", booted, where())
  F.idle(240)
  for _ = 1, 20 do
    if F.ensureFree() then break end
    F.press("A", 2); F.idle(40)
  end
  F.L("  after Continue at " .. where() .. " party=" .. F.r8(S.gPartiesCount))
  local lost = missing(before)
  F.check("every Pokemon is still owned after Continue", #lost == 0, table.concat(lost, ","))
  F.finish()
end)
