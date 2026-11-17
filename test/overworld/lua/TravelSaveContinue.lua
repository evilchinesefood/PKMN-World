-- Save and Continue after Dig, Escape Rope, Teleport and Fly in each region, and right after a
-- World Transit gate crossing: Teleport or Fly as the first move after the arrival, and Escape Rope
-- out of a cave entered straight after it. Each landing is saved from the Start menu, then soft
-- reset or power cut, and the Continue must restore the map, tile, saved region, whiteout point,
-- escape warp, party, PC and money. A power cut on a range of frames inside the flash write after
-- a Dig must load either the save before the Dig or the save after it, whole. From the Battle
-- Frontier, Fly to Hoenn and a later Teleport must claim Hoenn without recording a departure, and
-- Select with the Hub Pass registered, held through each move's warp, must only act after landing.
--
-- Setup seeds badges, visited towns and a lead that knows Teleport, Dig and Fly. The gate, the Hub
-- Pass, the cave doors, the Bag, the party menu, the Fly map and every save use real input. A debug
-- warp puts the player on the outdoor tile of each cave door; the step into the cave is real, so
-- the game sets the escape warp itself.
--
-- PW_TSC_ONLY=<text> (runner --env) runs only the matching cases.
--
-- Run via test/overworld/mgba-run.sh test/overworld/lua/TravelSaveContinue.lua <rom>

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "TravelSaveContinue")

local HUB = { 100, 0 }
local SLOTS = 14 * 30
local KANTO, JOHTO, HOENN = 1, 2, 3
local USM_ICO_PARTY, USM_ICO_BAG, USM_ICO_SAVE = 1, 2, 7
local POCKET_ITEMS = 0
local SENTINEL = 0xFFFF
local CONTEXT_RUNNING = 0
local MAPSECTYPE_CITY_CANFLY = 2
local SPECIES_ABRA, SPECIES_RATTATA = 63, 19
local MOVE_TELEPORT, MOVE_DIG, MOVE_FLY = 100, 91, 19
local ROW_TELEPORT, ROW_DIG, ROW_FLY = 1, 2, 3
local ITEM_ESCAPE_ROPE, ITEM_HUB_PASS = 120, 893
local ONLY = os.getenv("PW_TSC_ONLY")

local gates = {
  [KANTO] = { attendant = 11, g = 37, m = 5 },   -- Vermilion City
  [JOHTO] = { attendant = 16, g = 84, m = 23 },  -- Goldenrod station
  [HOENN] = { attendant = 21, g = 9, m = 9 },    -- Slateport harbor
}
-- The outdoor map and warp id of a cave door near each arrival, and the cave behind it.
local caves = {
  [KANTO] = { g = 37, m = 29, warp = 0, caveG = 35, caveM = 38, name = "Diglett's Cave" },
  [JOHTO] = { g = 80, m = 1, warp = 0, caveG = 82, caveM = 2, name = "Union Cave" },
  [HOENN] = { g = 0, m = 31, warp = 0, caveG = 24, caveM = 4, name = "Rusturf Tunnel" },
}

local function where() local x, y = F.pos(); return string.format("%d/%d (%d,%d)", F.grp(), F.mapn(), x, y) end
local function mapIs(g, m) return F.grp() == g and F.mapn() == m end
local function count() return F.r8(S.gPartiesCount) end
local function party(slot) return S.gParties + (slot or 0) * S.Pokemon.size end
local function box(slot) return F.r32(S.gPokemonStoragePtr) + 4 + slot * 80 end
local function present(address) return (F.r8(address + 19) & 2) ~= 0 end
local function region() return F.r8(F.sb2() + S.SaveBlock2.currentRegion) end
local function travelBank() return F.sb3() + S.SaveBlock3.regionalTravel end

local function warpData(off)
  local a = F.sb1() + off
  return string.format("%d/%d(%d,%d)", F.rs8(a), F.rs8(a + 1), F.rs16(a + 4), F.rs16(a + 6))
end
local function heal() return warpData(S.SaveBlock1.lastHealLocation) end
local function escape() return warpData(S.SaveBlock1.lastHealLocation + 8) end
local function escapeXY()
  local a = F.sb1() + S.SaveBlock1.lastHealLocation + 8
  return F.rs8(a), F.rs8(a + 1), F.rs16(a + 4), F.rs16(a + 6)
end
local function healMap()
  local a = F.sb1() + S.SaveBlock1.lastHealLocation
  return F.rs8(a), F.rs8(a + 1)
end

local function flag(id, value)
  local base, offset
  if id >= 0x6000 and id < 0x6400 then base = F.sb3() + S.SaveBlock3.johtoFlags; offset = id - 0x6000
  else base = F.sb1() + S.SaveBlock1.flags; offset = id end
  local a = base + offset // 8
  local bit = 1 << (offset % 8)
  F.w8(a, value and (F.r8(a) | bit) or (F.r8(a) & (~bit & 255)))
end

local function hashRange(base, size, h)
  for i = 0, size - 4, 4 do h = (h * 31 + F.r32(base + i)) & 0xFFFFFFFF end
  return h
end
local function partyHash() return hashRange(S.gParties, count() * S.Pokemon.size, count()) end
local function pcHash()
  local h = 7
  for i = 0, SLOTS - 1 do
    if present(box(i)) then h = hashRange(box(i), 80, (h * 131 + i) & 0xFFFFFFFF) end
  end
  return h
end
local function census()
  local seen, dupes, n = {}, 0, 0
  local function add(address)
    if not present(address) then return end
    local p = F.r32(address)
    n = n + 1
    if seen[p] then dupes = dupes + 1 end
    seen[p] = true
  end
  for i = 0, 5 do add(party(i)) end
  for i = 0, SLOTS - 1 do add(box(i)) end
  return n, dupes
end

local function snapshot()
  local x, y = F.pos()
  local n, dupes = census()
  return { grp = F.grp(), map = F.mapn(), x = x, y = y, region = region(), heal = heal(), escape = escape(),
           party = partyHash(), pc = pcHash(), money = F.money(), mons = n, dupes = dupes,
           bank = hashRange(travelBank(), 168, 1) }
end
local function fmt(s)
  return string.format("%d/%d (%d,%d) region=%d heal=%s escape=%s party=%08X pc=%08X money=%d mons=%d dupes=%d bank=%08X",
    s.grp, s.map, s.x, s.y, s.region, s.heal, s.escape, s.party, s.pc, s.money, s.mons, s.dupes, s.bank)
end
local function sameState(a, b)
  return a.grp == b.grp and a.map == b.map and a.x == b.x and a.y == b.y and a.region == b.region
     and a.heal == b.heal and a.escape == b.escape and a.party == b.party and a.pc == b.pc
     and a.money == b.money and a.mons == b.mons and a.dupes == b.dupes and a.bank == b.bank
end

local SCRIPT_BUF = S.gStringVar4 + 960
local function runScript(bytes)
  for i, b in ipairs(bytes) do F.w8(SCRIPT_BUF + i - 1, b) end
  F.w8(S.sGlobalScriptContext, 0)
  F.w8(S.sGlobalScriptContext + 1, 1)
  F.w32(S.sGlobalScriptContext + 4, 0)
  F.w32(S.sGlobalScriptContext + S.ScriptCtx.scriptPtr, SCRIPT_BUF)
  F.w8(S.sGlobalScriptContextStatus, CONTEXT_RUNNING)
end
local function le16(t, v) t[#t + 1] = v & 0xFF; t[#t + 1] = (v >> 8) & 0xFF end
local function le32(t, v) le16(t, v & 0xFFFF); le16(t, (v >> 16) & 0xFFFF) end
local function createMon(species, level, moves)
  local b = { 0x23 }; le32(b, S.ScrCmd_createmon | 1)
  b[#b + 1] = 0; b[#b + 1] = 6
  le16(b, species); le16(b, level)
  le32(b, (1 << 17) | (1 << 18) | (1 << 19) | (1 << 20))
  for k = 1, 4 do le16(b, moves[k] or 0) end
  b[#b + 1] = 0x02
  runScript(b); F.idle(20)
  return count()
end

local function hasControl()
  return F.ow() and F.r8(S.sLockFieldControls) == 0
    and F.r8(S.sGlobalScriptContextStatus) ~= CONTEXT_RUNNING
end
local function awaitControl(budget)
  for i = 1, budget or 600 do
    if hasControl() then return true end
    if i % 30 == 0 then F.press("B", 2) else F.idle(1) end
  end
  return hasControl()
end
local function drain()
  for _ = 1, 30 do
    F.press("B", 2); F.idle(16)
    if F.ensureFree() then return true end
  end
  return false
end

-- ---- the World Transit gate and the Hub Pass (same drivers as GateRecallStress) ----------------
local function scriptMenuActive()
  for i = 0, S.Task.count - 1 do
    local a = S.gTasks + i * S.Task.stride
    local fn = F.r32(a + S.Task.func) & 0xFFFFFFFE
    if F.r8(a + S.Task.isActive) ~= 0 and (fn == S.Task_HandleYesNoInput or fn == S.Task_HandleMultichoiceInput
       or fn == S.Task_CallYesOrNoCallback) then return true end
  end
  return false
end
local function menu(want, tag)
  for _ = 1, 65 do
    if F.reportCrash(tag) then return false end
    if scriptMenuActive() then
      F.idle(12)
      for _ = 1, 10 do
        local c = F.mcur()
        if c == want then
          F.shot(tag)
          for _ = 1, 4 do
            F.press("A", 2)
            for _ = 1, 30 do
              if not scriptMenuActive() then F.idle(30); return true end
              F.idle(1)
            end
          end
          return false
        end
        F.press(c > want and "Up" or "Down", 2); F.idle(12)
      end
      return false
    end
    F.press("A", 2); F.idle(25)
  end
  F.shot(tag .. "_nomenu")
  return false
end
local function awaitMap(g, m, tag)
  for _ = 1, 220 do
    if mapIs(g, m) then F.idle(100); return true end
    if F.reportCrash(tag) then return false end
    F.press("A", 2); F.idle(14)
  end
  F.shot(tag .. "_failed")
  return false
end
local function cross(r, tag)
  local x = gates[r].attendant
  if not F.route({ { 16, 4 }, { x, 4 }, { x, 3 } }, tag .. "_walk") then return false end
  F.face("Up"); F.press("A", 3); F.idle(60)
  if not menu(1, tag .. "_team") then return false end
  if not menu(1, tag .. "_arrival") then return false end
  if not menu(0, tag .. "_confirm") then return false end
  return awaitMap(gates[r].g, gates[r].m, tag) and awaitControl(600)
end
local function passToHub(tag)
  for attempt = 1, 3 do
    drain()
    F.w16(F.sb1() + S.SaveBlock1.registeredItem, ITEM_HUB_PASS)
    F.press("Select", 2); F.idle(90)
    if menu(0, tag .. "_confirm" .. attempt) then return awaitMap(HUB[1], HUB[2], tag) and awaitControl(600) end
  end
  return false
end

-- ---- debug warp onto a map warp's tile -----------------------------------------------------------
local function d(n) return (n // 100) % 10, (n // 10) % 10, n % 10 end
local function warp(g, m, w, tag)
  local gh, gt, go = d(g)
  local mh, mt, mo = d(m)
  local wh, wt, wo = d(w)
  return F.warpTo(gh, gt, go, mh, mt, mo, wh, wt, wo, g, m, tag)
end

-- ---- Bag: Escape Rope ----------------------------------------------------------------------------
local function inBag() return F.cb2() == (S.CB2_BagMenuRun & ~1) end
local function pocketPtr(p) return F.r32(S.gBagPockets + p * S.BagPocket.stride) end
local function qtyKey() return F.r32(F.sb2() + S.SaveBlock2.encryptionKey) & 0xFFFF end
local function ropeCount()
  local n, ptr = 0, pocketPtr(POCKET_ITEMS)
  for s = 0, F.pocketCap(POCKET_ITEMS) - 1 do
    if F.r16(ptr + s * 4) == ITEM_ESCAPE_ROPE then n = n + (F.r16(ptr + s * 4 + 2) ~ qtyKey()) end
  end
  return n
end
local function ropeFirst(qty)
  local ptr = pocketPtr(POCKET_ITEMS)
  for s = 0, F.pocketCap(POCKET_ITEMS) - 1 do F.w16(ptr + s * 4, 0); F.w16(ptr + s * 4 + 2, qtyKey()) end
  F.w16(ptr, ITEM_ESCAPE_ROPE); F.w16(ptr + 2, qty ~ qtyKey())
end
local function useEscapeRope(tag)
  F.w8(S.gBagPosition + 5, POCKET_ITEMS)
  F.w16(S.gBagPosition + 8 + POCKET_ITEMS * 2, 0)
  F.w16(S.gBagPosition + 18 + POCKET_ITEMS * 2, 0)
  F.press("Start", 2); F.idle(60)
  if not F.selectStartIcon(USM_ICO_BAG) then return false end
  F.press("A", 2)
  local opened = false
  for _ = 1, 150 do
    if inBag() then opened = true; break end
    F.idle(2)
  end
  if not opened then return false end
  F.idle(40)
  F.shot(tag .. "_bag")
  F.press("A", 2); F.idle(40)
  F.shot(tag .. "_actions")
  F.press("A", 2); F.idle(20)
  return true
end

-- ---- party menu field moves ------------------------------------------------------------------------
local function inPartyMenu()
  local c = F.cb2()
  return c == S.CB2_UpdatePartyMenu or c == S.CB2_InitPartyMenu or c == S.CB2_PartyMenuFromStartMenu
end
local function inFlyMap()
  local c = F.cb2()
  return c == S.CB2_FlyMap or c == S.CB2_OpenFlyMap
end
local function openParty(tag)
  for _ = 1, 3 do
    awaitControl(300)
    F.press("Start", 2); F.idle(60)
    if F.selectStartIcon(USM_ICO_PARTY) then
      F.press("A", 3)
      for _ = 1, 240 do
        F.idle(4)
        if inPartyMenu() then F.idle(40); return true end
      end
    end
    for _ = 1, 8 do F.press("B", 3); F.idle(20) end
  end
  F.shot(tag .. "_noparty")
  return false
end
-- A on the lead, Down to the field-move row, A. Teleport and Dig then ask Yes/No with YES first.
local function fieldMove(row, tag)
  if not openParty(tag) then return false end
  F.press("A", 3); F.idle(50)
  for _ = 1, row do F.press("Down", 2); F.idle(12) end
  F.shot(tag .. "_actions")
  F.press("A", 3); F.idle(40)
  if row == ROW_FLY then
    for t = 1, 400 do
      F.idle(4)
      if inFlyMap() then F.idle(40); return true end
      if t % 20 == 0 then F.press("A", 2) end
    end
    F.shot(tag .. "_noflymap")
    return false
  end
  for _ = 1, 60 do
    F.press("Up", 2); F.idle(6)
    F.press("A", 2); F.idle(16)
    if not inPartyMenu() then return true end
  end
  return false
end
local function flyInfo()
  local p = F.r32(S.sRegionMap)
  if p < 0x02000000 or p >= 0x02040000 then return -1, -1 end
  return F.r16(p), F.r8(p + 2)
end
-- Raster the Fly map cursor across the map around its start until it rests on a flyable town other
-- than the one it opened on, then fly there.
local function flyToNearestTown(tag)
  local start = flyInfo()
  F.shot(tag .. "_flymap")
  local function tryHere()
    local sec, typ = flyInfo()
    if typ == MAPSECTYPE_CITY_CANFLY and sec ~= start then
      F.shot(tag .. "_flypick")
      F.L(string.format("  %s: flying from mapsec %d to %d", tag, start, sec))
      F.press("A", 3); F.idle(20)
      return true
    end
    return false
  end
  for _ = 1, 8 do F.press("Up", 2); F.idle(16) end
  for row = 1, 17 do
    local dir = row % 2 == 1 and "Left" or "Right"
    local n = row == 1 and 14 or 28
    for _ = 1, n do
      if not inFlyMap() then return false end
      F.press(dir, 2); F.idle(16)
      if tryHere() then return true end
    end
    F.press("Down", 2); F.idle(16)
    if tryHere() then return true end
  end
  return false
end
local function awaitLanding(fromG, fromM, tag)
  for t = 1, 1200 do
    F.idle(2)
    if t % 40 == 0 and F.reportCrash(tag) then return false end
    if F.ow() and not mapIs(fromG, fromM) and hasControl() then F.idle(30); return true end
    if t % 60 == 0 then F.press("A", 1) end
  end
  F.shot(tag .. "_nolanding")
  return false
end

-- ---- save, reset, Continue -------------------------------------------------------------------------
local function driveSave(hook)
  F.w16(S.gSaveAttemptStatus, SENTINEL)
  local c0 = F.r32(S.gSaveCounter)
  awaitControl(300)
  F.press("Start", 2); F.idle(60)
  if not F.selectStartIcon(USM_ICO_SAVE) then return "noicon", 0 end
  local writing = 0
  for i = 1, 3000 do
    local started = F.r32(S.gSaveCounter) ~= c0
    local done = F.r16(S.gSaveAttemptStatus) ~= SENTINEL
    if started and not done then writing = writing + 1 end
    if hook and hook(started, done) then return "stopped", writing end
    if done then
      F.idle(30)
      for _ = 1, 6 do F.press("B", 2); F.idle(20) end
      return F.r16(S.gSaveAttemptStatus) == 1 and "done" or "failed", writing
    end
    if i % 20 == 1 then joypad.set({ A = true }) else joypad.set({}) end
    emu.frameadvance()
  end
  return "timeout", writing
end
local function softReset()
  for _ = 1, 8 do joypad.set({ A = true, B = true, Start = true, Select = true }); emu.frameadvance() end
  joypad.set({})
end
local function reboot(tag)
  F.idle(60)
  local ok = F.boot(nil, true)
  F.idle(30)
  if F.reportCrash(tag) then return false end
  return ok
end

local function saveContinue(tag, how)
  awaitControl(300)
  local before = snapshot()
  local status = driveSave()
  F.check(tag .. ": saved", status == "done", status)
  if how == "power" then client.reboot_core() else softReset() end
  local booted = reboot(tag)
  F.check(tag .. ": continued to the field", booted)
  if not booted then return false end
  local after = snapshot()
  F.L("  saved     " .. fmt(before))
  F.L("  continued " .. fmt(after))
  F.check(tag .. ": same map and tile", after.grp == before.grp and after.map == before.map
    and after.x == before.x and after.y == before.y, fmt(after))
  F.check(tag .. ": same region", after.region == before.region, after.region .. " vs " .. before.region)
  F.check(tag .. ": same whiteout point", after.heal == before.heal, after.heal .. " vs " .. before.heal)
  F.check(tag .. ": same escape warp", after.escape == before.escape, after.escape .. " vs " .. before.escape)
  F.check(tag .. ": same party, PC and money", after.party == before.party and after.pc == before.pc
    and after.money == before.money and after.mons == before.mons and after.dupes == 0,
    string.format("mons=%d dupes=%d money=%d", after.mons, after.dupes, after.money))
  F.check(tag .. ": same regional memory", after.bank == before.bank)
  F.check(tag .. ": control returns", awaitControl(600))
  return true
end

-- ---- the travel moves -----------------------------------------------------------------------------
local base = {}
local function expectHome(r, tag)
  local s = snapshot()
  F.check(tag .. ": region is still " .. r, s.region == r, "region=" .. s.region)
  F.check(tag .. ": whiteout point is still the arrival's", s.heal == base.heal, s.heal .. " vs " .. tostring(base.heal))
  F.check(tag .. ": nobody lost or cloned", s.mons == base.mons and s.dupes == 0 and s.party == base.party
    and s.pc == base.pc, string.format("mons=%d dupes=%d", s.mons, s.dupes))
  F.check(tag .. ": money unchanged", s.money == base.money, "money=" .. s.money)
end

local function enterCave(r, tag)
  local c = caves[r]
  if not mapIs(c.g, c.m) then
    if not warp(c.g, c.m, c.warp, tag .. "_door") then return false end
    awaitControl(300)
  end
  F.step("Down")
  local entered = false
  for _ = 1, 4 do
    F.press("Up", 16); F.idle(20)
    for _ = 1, 120 do
      if mapIs(c.caveG, c.caveM) and hasControl() then entered = true; break end
      F.idle(2)
    end
    if entered then break end
  end
  F.L(string.format("  %s: in %s at %s escape=%s", tag, c.name, where(), escape()))
  return entered
end

local function ropeOut(r, tag)
  local c = caves[r]
  local _, _, ex, ey = escapeXY()
  local before = ropeCount()
  if not useEscapeRope(tag) then F.check(tag .. ": the Bag opened on the Escape Rope", false); return false end
  local out = awaitLanding(c.caveG, c.caveM, tag)
  local x, y = F.pos()
  F.L(string.format("  %s: landed at %s ropes %d->%d", tag, where(), before, ropeCount()))
  F.check(tag .. ": Escape Rope lands on the cave's escape warp", out and mapIs(c.g, c.m) and x == ex and y == ey,
    where() .. " escape=" .. escape())
  F.check(tag .. ": one Escape Rope used", ropeCount() == before - 1, before .. "->" .. ropeCount())
  return out
end

local function digOut(r, tag)
  local c = caves[r]
  local _, _, ex, ey = escapeXY()
  if not fieldMove(ROW_DIG, tag) then F.check(tag .. ": Dig chosen from the party menu", false); return false end
  local out = awaitLanding(c.caveG, c.caveM, tag)
  local x, y = F.pos()
  F.check(tag .. ": Dig lands on the cave's escape warp", out and mapIs(c.g, c.m) and x == ex and y == ey,
    where() .. " escape=" .. escape())
  return out
end

local function teleport(tag)
  local hg, hm = healMap()
  local fromG, fromM = F.grp(), F.mapn()
  if not fieldMove(ROW_TELEPORT, tag) then F.check(tag .. ": Teleport chosen from the party menu", false); return false end
  local landed = awaitLanding(fromG, fromM, tag)
  F.check(tag .. ": Teleport lands on the whiteout point's map", landed and mapIs(hg, hm),
    where() .. " heal=" .. heal())
  return landed
end

local function fly(r, tag)
  local fromG, fromM = F.grp(), F.mapn()
  if not fieldMove(ROW_FLY, tag) then F.check(tag .. ": the Fly map opened", false); return false end
  if not flyToNearestTown(tag) then
    F.check(tag .. ": a town picked on the Fly map", false)
    for _ = 1, 20 do if F.ow() then break end; F.press("B", 2); F.idle(30) end
    awaitControl(300)
    return false
  end
  local landed = awaitLanding(fromG, fromM, tag)
  F.check(tag .. ": Fly landed in another town", landed, where())
  F.check(tag .. ": Fly kept the region", region() == r, "region=" .. region())
  return landed
end

-- After a Dig, a power cut on frame `off` of the save write must load the save made in the cave
-- or the save made after the Dig, never a mix of the two.
local function digWriteSweep(r, tag)
  local c = caves[r]
  if not enterCave(r, tag .. "_measure") then F.check(tag .. ": entered the cave to measure", false); return end
  local status, span = driveSave()
  F.check(tag .. ": measured a save in the cave", status == "done", status)
  F.L(string.format("  %s: the flash write spans %d frames", tag, span))
  local offsets = { 0, span // 4, span // 2, (3 * span) // 4, span - 1, span + 1 }
  local loaded = { old = 0, new = 0, neither = 0 }
  for _, off in ipairs(offsets) do
    local t = string.format("%s: power cut %d frames into the write", tag, off)
    if not mapIs(c.caveG, c.caveM) and not enterCave(r, tag .. "_reenter") then F.check(t .. ": re-entered the cave", false); break end
    status = driveSave()
    if status ~= "done" then F.check(t .. ": saved in the cave", false, status); break end
    local old = snapshot()
    if not digOut(r, tag .. "_dig" .. off) then break end
    local new = snapshot()
    local seen = -1
    status = driveSave(function(started)
      if not started then return false end
      seen = seen + 1
      if seen >= off then client.reboot_core(); return true end
      return false
    end)
    if not reboot(t) then F.check(t .. ": continued", false); break end
    local got = snapshot()
    local which = sameState(got, old) and "old" or (sameState(got, new) and "new" or "neither")
    loaded[which] = loaded[which] + 1
    F.L(string.format("  %s -> %s: %s", t, which, fmt(got)))
    F.check(t .. ": loads the cave save or the Dig save, whole", which ~= "neither",
      "got " .. fmt(got) .. " old " .. fmt(old) .. " new " .. fmt(new))
    awaitControl(600)
  end
  F.L(string.format("  %s: old=%d new=%d neither=%d", tag, loaded.old, loaded.new, loaded.neither))
  F.check(tag .. ": an early cut keeps the cave save", loaded.old > 0)
  F.check(tag .. ": a cut after the write keeps the Dig save", loaded.new > 0)
end

local function case(tag, body)
  if ONLY and not tag:find(ONLY, 1, true) then return end
  F.L("== " .. tag .. " ==")
  local ok, err = pcall(body)
  if not ok then F.check(tag .. ": ran without a Lua error", false, tostring(err)) end
end

local function setup()
  if not F.boot(HUB[1]) then return false end
  F.w16(F.sb2() + S.SaveBlock2.optionsU16, (F.r16(F.sb2() + S.SaveBlock2.optionsU16) & ~7) | 3)
  -- Openings and first badges in all three regions (as GateRecallStress), then each region's Fly
  -- badge and one more visited town for the Fly map.
  for _, id in ipairs({ 0xDCF, 0x51, 0xA4B, 0x63F8, 0x94F, 0x95F, 0xA4D, 0x63FC, 0x63FD, 0x954, 0x948,
                        0xD40, 0xD45, 0x6088, 0x60EA, 0x957, 0x95C, 0xA4A }) do flag(id, true) end
  F.w8(F.sb2() + S.SaveBlock2.introDoneBits, 7)
  -- Frontier already visited once, so Scott's first-visit scene does not take the arrival.
  flag(0x9BA, true)
  F.w16(F.sb1() + S.SaveBlock1.vars + (0x40D0 - 0x4000) * 2, 1)
  if createMon(SPECIES_ABRA, 30, { MOVE_TELEPORT, MOVE_DIG, MOVE_FLY }) ~= 1 then return false end
  if createMon(SPECIES_RATTATA, 12, { 33 }) ~= 2 then return false end
  ropeFirst(20)
  F.w32(F.sb1() + S.SaveBlock1.money, 123456 ~ F.r32(F.sb2() + S.SaveBlock2.encryptionKey))
  drain()
  return true
end

local function arrive(r, tag)
  if not mapIs(HUB[1], HUB[2]) and not passToHub(tag .. "_pass") then return false end
  drain()
  if not cross(r, tag .. "_gate") then return false end
  base = snapshot()
  F.L(string.format("  %s: arrived at %s region=%d heal=%s escape=%s", tag, where(), base.region, base.heal, base.escape))
  return true
end

F.run(function()
  local ok = setup()
  F.check("setup: a lead with Teleport, Dig and Fly and a second Pokemon", ok, "party=" .. count())
  if not ok then F.finish(); return end

  local names = { [KANTO] = "Kanto", [JOHTO] = "Johto", [HOENN] = "Hoenn" }
  -- Kanto arrives outdoors in Vermilion, so Teleport and Fly can be the first move after the gate.
  -- Johto and Hoenn arrive inside a station and a harbor; one step takes the player out.
  local firstMove = { [KANTO] = "teleport", [JOHTO] = "fly", [HOENN] = "teleport" }
  for _, r in ipairs({ KANTO, JOHTO, HOENN }) do
    local n = names[r]
    case(n, function()
      F.check(n .. ": crossed the gate", arrive(r, n), where())
      F.check(n .. ": region set by the gate", region() == r, "region=" .. region())
      if r ~= KANTO then F.check(n .. ": walked out of the arrival building", F.step("Down"), where()) end
      if firstMove[r] == "teleport" then
        if teleport(n .. " Teleport right after the gate") then
          expectHome(r, n .. " Teleport right after the gate")
          saveContinue(n .. " Teleport right after the gate", "soft")
        end
      else
        if fly(r, n .. " Fly right after the gate") then
          expectHome(r, n .. " Fly right after the gate")
          saveContinue(n .. " Fly right after the gate", "power")
        end
      end

      local inCave = enterCave(r, n .. " cave")
      F.check(n .. ": walked into " .. caves[r].name, inCave, where())
      if inCave then
        local eg, em = escapeXY()
        F.check(n .. ": the cave door set the escape warp outside it", eg == caves[r].g and em == caves[r].m, escape())
        saveContinue(n .. " inside the cave", r == HOENN and "power" or "soft")
        if ropeOut(r, n .. " Escape Rope") then
          expectHome(r, n .. " Escape Rope")
          saveContinue(n .. " Escape Rope", r == JOHTO and "soft" or "power")
        end
      end
      if enterCave(r, n .. " cave again") and digOut(r, n .. " Dig") then
        expectHome(r, n .. " Dig")
        saveContinue(n .. " Dig", r == JOHTO and "power" or "soft")
      end
      if firstMove[r] == "teleport" then
        if fly(r, n .. " Fly") then
          expectHome(r, n .. " Fly")
          saveContinue(n .. " Fly", "power")
        end
      else
        if teleport(n .. " Teleport") then
          expectHome(r, n .. " Teleport")
          saveContinue(n .. " Teleport", "soft")
        end
      end
      if r == JOHTO then digWriteSweep(r, n .. " save write after Dig") end
    end)
  end

  -- The Battle Frontier is neutral. Arrive there from Kanto, then Fly to a Hoenn town: the flight
  -- claims Hoenn and re-arms the whiteout point there without recording a departure. Then return
  -- through the hub and Teleport from the Frontier, which lands on that Hoenn whiteout point.
  case("Frontier", function()
    F.check("Frontier: crossed to Kanto first", arrive(KANTO, "Frontier kanto"), where())
    local kantoBank = hashRange(travelBank(), 168, 1)
    F.check("Frontier: Hub Pass back to the hub", passToHub("Frontier pass"), where())
    local bankAfterPass = hashRange(travelBank(), 168, 1)
    local function toFrontier(tag)
      drain()
      if not F.route({ { 16, 4 }, { 4, 4 }, { 4, 3 } }, tag .. "_walk") then return false end
      F.face("Up"); F.press("A", 3); F.idle(60)
      if not menu(0, tag .. "_yes") then return false end
      for _ = 1, 200 do
        if F.ow() and F.grp() ~= HUB[1] and hasControl() then break end
        F.idle(4)
      end
      local gate = { F.grp(), F.mapn() }
      for _ = 1, 4 do
        F.press("Down", 16)
        for _ = 1, 150 do
          if not mapIs(gate[1], gate[2]) and hasControl() then return true end
          F.idle(2)
        end
      end
      return false
    end
    F.check("Frontier: walked out of the reception gate", toFrontier("Frontier gate"), where())
    F.check("Frontier: still Kanto's campaign on arrival", region() == KANTO, "region=" .. region())
    local before = snapshot()
    base = before
    if fly(HOENN, "Frontier Fly to Hoenn") then
      local hg, hm = healMap()
      F.check("Frontier Fly to Hoenn: whiteout point re-armed in Littleroot", hg == 0 and hm == 9, heal())
      F.check("Frontier Fly to Hoenn: no departure recorded from the Frontier",
        hashRange(travelBank(), 168, 1) == bankAfterPass)
      base = snapshot()
      saveContinue("Frontier Fly to Hoenn", "power")
    end
    F.check("Frontier: Hub Pass from Hoenn", passToHub("Frontier pass2"), where())
    F.check("Frontier: walked out of the reception gate again", toFrontier("Frontier gate2"), where())
    base = snapshot()
    if teleport("Frontier Teleport") then
      F.check("Frontier Teleport: lands in Hoenn's campaign", region() == HOENN, "region=" .. region())
      saveContinue("Frontier Teleport", "soft")
    end
    F.L(string.format("  Frontier: kanto bank %08X after pass %08X", kantoBank, bankAfterPass))
  end)

  -- Select, with the Hub Pass registered, held through each move's warp out and landing. The
  -- Hub Pass must neither fire mid-warp nor leave the player hidden or locked; B then answers No
  -- to any Hub Pass prompt that did open after the landing.
  case("Select", function()
    if not mapIs(HUB[1], HUB[2]) then passToHub("Select pass") end
    F.check("Select: crossed to Hoenn", arrive(HOENN, "Select"), where())
    F.check("Select: walked out of the harbor", F.step("Down"), where())
    local function mashSelect(tag, frames)
      local crashed = false
      for i = 1, frames do
        joypad.set(i % 4 < 2 and { Select = true } or {})
        emu.frameadvance()
        if i % 30 == 0 and F.reportCrash(tag) then crashed = true; break end
      end
      joypad.set({})
      F.idle(20)
      -- After the landing, Select opens the Hub Pass's question; B answers it No.
      local offered = F.ow() and not hasControl()
      F.L(string.format("  %s: Hub Pass question up after the mash=%s", tag, tostring(offered)))
      F.check(tag .. ": Select reached the field only after the landing", offered)
      for _ = 1, 12 do
        if hasControl() then break end
        F.press("B", 2); F.idle(30)
      end
      local id = F.r8(S.gPlayerAvatar + 5)
      local hidden = (F.r8(S.gObjectEvents + id * S.ObjectEvent.stride + 1) >> 5) & 1
      local s = snapshot()
      F.L(string.format("  %s: ended at %s hidden=%d", tag, where(), hidden))
      F.check(tag .. ": no crash", not crashed)
      F.check(tag .. ": control returns with the player shown", awaitControl(600) and hidden == 0, where())
      F.check(tag .. ": nobody lost or cloned", s.mons == base.mons and s.dupes == 0 and s.party == base.party
        and s.pc == base.pc, string.format("mons=%d dupes=%d", s.mons, s.dupes))
      return not crashed
    end
    F.w16(F.sb1() + S.SaveBlock1.registeredItem, ITEM_HUB_PASS)
    local fromG, fromM = F.grp(), F.mapn()
    if fieldMove(ROW_FLY, "Select fly") and flyToNearestTown("Select fly") then
      mashSelect("Select through Fly", 900)
      F.check("Select through Fly: landed in another town, not the hub", not mapIs(fromG, fromM)
        and not mapIs(HUB[1], HUB[2]), where())
    else
      F.check("Select through Fly: flew", false, where())
    end
    local hg, hm = healMap()
    if fieldMove(ROW_TELEPORT, "Select teleport") then
      mashSelect("Select through Teleport", 800)
      F.check("Select through Teleport: landed on the whiteout point's map", mapIs(hg, hm), where())
    else
      F.check("Select through Teleport: teleported", false, where())
    end
    if enterCave(HOENN, "Select cave") then
      if fieldMove(ROW_DIG, "Select dig") then
        mashSelect("Select through Dig", 800)
        F.check("Select through Dig: landed outside the cave", mapIs(caves[HOENN].g, caves[HOENN].m), where())
      end
      if enterCave(HOENN, "Select cave2") and useEscapeRope("Select rope") then
        mashSelect("Select through Escape Rope", 800)
        F.check("Select through Escape Rope: landed outside the cave", mapIs(caves[HOENN].g, caves[HOENN].m), where())
      end
    end
    saveContinue("Select", "soft")
  end)
  F.finish()
end)
