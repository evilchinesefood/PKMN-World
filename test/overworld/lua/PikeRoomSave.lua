-- A Battle Pike challenge carries only the three chosen Pokemon. The lobby saves the whole party
-- first and the challenge keeps the rest in SaveBlock1's party copy until it ends. A Start-menu
-- save inside a Pike room writes the three-member party over that copy, so the other three would
-- be gone from the file and from the game once the challenge ends. The Pike start menu must not
-- offer Save, and whatever the player does there, a reboot and Continue must keep all six.
-- Nor may it offer the Bag: the lobby ends the challenge by reloading the saved party and its
-- held items, so a Bag > Give in a room loses the given item and leaves the swapped-out one in
-- the bag as a second copy.
--
-- The suite gives six distinct Pokemon, takes the real Lv. 50 challenge at the lobby attendant
-- (choosing three in the party screen and saving when asked), walks into the three-path room,
-- tries the Start-menu save, then cuts the power and continues.
--
-- Run via test/overworld/mgba-run.sh test/overworld/lua/PikeRoomSave.lua <rom>

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "PikeRoomSave")

local HUB_GROUP = 100
local FRONTIER = 26
local PIKE_LOBBY, PIKE_THREE_PATH = 34, 36
local USM_ICO_BAG, USM_ICO_SAVE = 2, 7
local POCKET_ITEMS = 0
local ITEM_POTION, ITEM_LEFTOVERS = 28, 472
local CHALLENGE_STATUS_LOST = 4
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

local function secure(a)
  local pers = F.r32(a)
  local key = pers ~ F.r32(a + 4)
  local w = {}
  for i = 0, 11 do w[i] = F.r32(a + 32 + i * 4) ~ key end
  return w, F.r8(S.sSubstructOffsets + pers % 24) * 3, key
end
local function heldItem(a) local w, s0 = secure(a); return (w[s0] >> 16) & 0x3FF end
local function setHeldItem(a, item)
  local w, s0, key = secure(a)
  w[s0] = (w[s0] & ~(0x3FF << 16)) | (item << 16)
  local sum = 0
  for i = 0, 11 do
    local v = w[i] & 0xFFFFFFFF
    sum = sum + (v & 0xFFFF) + (v >> 16)
    F.w32(a + 32 + i * 4, v ~ key)
  end
  F.w16(a + 28, sum & 0xFFFF)
end

local function pocketPtr(p) return F.r32(S.gBagPockets + p * S.BagPocket.stride + S.BagPocket.itemsPtr) end
local function qtyKey() return F.r32(F.sb2() + S.SaveBlock2.encryptionKey) & 0xFFFF end
local function bagCount(id)
  local n = 0
  for p = 0, 4 do
    local ptr, cap = pocketPtr(p), F.pocketCap(p)
    if ptr >= 0x02000000 and ptr < 0x02040000 and cap < 400 then
      for s = 0, cap - 1 do
        if F.r16(ptr + s * 4) == id then n = n + (F.r16(ptr + s * 4 + 2) ~ qtyKey()) end
      end
    end
  end
  return n
end
local function setPocket(p, id, qty)
  local ptr, cap = pocketPtr(p), F.pocketCap(p)
  for s = 0, cap - 1 do F.w16(ptr + s * 4, 0); F.w16(ptr + s * 4 + 2, qtyKey()) end
  if qty > 0 then F.w16(ptr, id); F.w16(ptr + 2, qty ~ qtyKey()) end
end
local function heldCount(id)
  local n = 0
  for i = 0, 5 do if present(party(i)) and heldItem(party(i)) == id then n = n + 1 end end
  return n
end
local function stock(id) return bagCount(id) + heldCount(id) end

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
local function chooseThree()
  for _ = 1, 300 do
    if inPartyMenu() then break end
    F.press("A", 2); F.idle(20)
  end
  if not inPartyMenu() then return false end
  F.idle(60)
  for i = 1, 3 do
    F.press("A", 2); F.idle(30)
    F.press("A", 2); F.idle(40)
    if i < 3 then F.press("Down", 2); F.idle(20) end
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

local function inBag() return F.cb2() == (S.CB2_BagMenuRun & ~1) end

-- Bag, Items pocket first row, Give (the 2x2 grid's top right), then A through the bag's own
-- party column (first member) and its switch prompt until the lead's item changes.
local function tryBagGive()
  F.w8(S.gBagPosition + 5, POCKET_ITEMS)
  F.w16(S.gBagPosition + 8 + POCKET_ITEMS * 2, 0)
  F.w16(S.gBagPosition + 18 + POCKET_ITEMS * 2, 0)
  F.press("Start", 2); F.idle(60)
  local offered = F.selectStartIcon(USM_ICO_BAG)
  F.shot("bag_icon")
  if offered then
    F.press("A", 2)
    for _ = 1, 150 do if inBag() then break end F.idle(2) end
    F.idle(30)
    F.press("A", 2); F.idle(30)
    F.press("Right", 2); F.idle(20)
    F.shot("bag_give")
    for _ = 1, 16 do
      F.press("A", 2); F.idle(40)
      if heldItem(party(0)) ~= ITEM_LEFTOVERS then break end
    end
    F.idle(60)
    F.shot("bag_after_give")
  end
  for _ = 1, 40 do
    if F.ow() and F.ensureFree() then break end
    F.press("B", 2); F.idle(30)
  end
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
  local lv = {}
  for i = 0, 5 do lv[#lv + 1] = F.r8(party(i) + S.Pokemon.level) end
  F.L("  levels " .. table.concat(lv, ","))
  setHeldItem(party(0), ITEM_LEFTOVERS)
  setPocket(POCKET_ITEMS, ITEM_POTION, 1)
  F.check("the lead holds Leftovers and the bag has one Potion",
    heldItem(party(0)) == ITEM_LEFTOVERS and bagCount(ITEM_POTION) == 1 and bagCount(ITEM_LEFTOVERS) == 0)
  local before, n0 = owned()
  F.L("  owned before the challenge: " .. n0)

  if not F.warpTo(0, 2, 6, 0, 3, 4, 0, 0, 0, FRONTIER, PIKE_LOBBY, "pike lobby") then
    F.check("warped to the Pike lobby", false); F.finish(); return
  end
  if not F.ensureFree() then F.dismiss(10) end
  local reached = F.route({ { 5, 7 }, { 5, 6 } }, "attendant")
  F.check("walked to the lobby attendant", reached, where())
  F.face("Up")
  F.press("A", 2); F.idle(40)
  local took = menu(0, "take_challenge") and menu(0, "level_50")
  F.check("took the Lv. 50 challenge", took)
  local chose = took and chooseThree()
  F.check("chose three Pokemon in the party screen", chose)
  local saved = chose and menu(0, "save_before")
  F.check("agreed to save before the challenge", saved)

  -- The lobby save, the walk, the corridor and the warp into the three-path room.
  local arrived = false
  for i = 1, 6000 do
    if F.grp() == FRONTIER and F.mapn() == PIKE_THREE_PATH and F.ow() and i % 60 == 0 and F.ensureFree() then
      arrived = true
      break
    end
    if i % 40 == 1 then joypad.set({ A = true }) else joypad.set({}) end
    emu.frameadvance()
  end
  F.check("reached the three-path room in control", arrived, where())
  F.check("the challenge carries three Pokemon", F.r8(S.gPartiesCount) == 3, "n=" .. F.r8(S.gPartiesCount))

  local offered, wrote = tryStartSave()
  F.L(string.format("  three-path room Start menu: save offered=%s wrote=%s", tostring(offered), tostring(wrote)))
  F.check("the Pike room start menu does not offer Save", not offered)

  local bagOffered = tryBagGive()
  F.L(string.format("  three-path room Start menu: bag offered=%s lead holds %d, bag Potion=%d Leftovers=%d",
    tostring(bagOffered), heldItem(party(0)), bagCount(ITEM_POTION), bagCount(ITEM_LEFTOVERS)))
  F.check("the Pike room start menu does not offer the Bag", not bagOffered)

  -- A lost Pike battle sets the challenge status and warps to the lobby, whose script reloads the
  -- saved party, restores the held items and saves.
  F.w8(F.sb2() + S.SaveBlock2.frontierChallengeStatus, CHALLENGE_STATUS_LOST)
  local back = F.warpTo(0, 2, 6, 0, 3, 4, 0, 0, 0, FRONTIER, PIKE_LOBBY, "pike lobby after the loss")
  for _ = 1, 40 do
    if F.ow() and F.ensureFree() and F.r8(S.gPartiesCount) == 6 then break end
    F.press("A", 2); F.idle(40)
  end
  F.check("the lobby ended the challenge with six Pokemon", back and F.r8(S.gPartiesCount) == 6,
    "n=" .. F.r8(S.gPartiesCount))
  F.L(string.format("  after the challenge: Leftovers bag=%d held=%d, Potion bag=%d held=%d",
    bagCount(ITEM_LEFTOVERS), heldCount(ITEM_LEFTOVERS), bagCount(ITEM_POTION), heldCount(ITEM_POTION)))
  F.check("one Leftovers after the challenge", stock(ITEM_LEFTOVERS) == 1, "count=" .. stock(ITEM_LEFTOVERS))
  F.check("one Potion after the challenge", stock(ITEM_POTION) == 1, "count=" .. stock(ITEM_POTION))

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
