-- Escape Rope and Dig on Mt. Silver's outdoor map.
--
-- MtSilver_Outside is a city-type outdoor map, and it was the only one that allowed Escape Rope
-- and Dig. Nothing sets the escape warp there: the player walks out of the Mt. Silver Pokemon
-- Center or in from Route 28, so the warp still names the last building or cave entered from
-- outdoors anywhere, in any region. The World Transit gate resumes a Johto trip at the Mt. Silver
-- Center, so a rope used on the doorstep could carry the player into Kanto with Johto still the
-- saved region, bypassing the gate's departure record and region claim.
--
-- The suite visits the Mt. Silver Center for real (the gate remembers it), enters Diglett's Cave
-- in Kanto (the game sets the escape warp to Route 11), then resumes Johto at the Mt. Silver Center
-- through the gate, walks out and uses an Escape Rope from the Bag and Dig from the party menu. The
-- Bag, the party menu, the gate, the Hub Pass and every door are real input; debug warps only put
-- the player on the outdoor tile of a door.
--
-- Run via test/overworld/mgba-run.sh test/overworld/lua/MtSilverEscape.lua <rom>

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "MtSilverEscape")

local HUB = { 100, 0 }
local SLOTS = 14 * 30
local KANTO, JOHTO = 1, 2
local USM_ICO_PARTY, USM_ICO_BAG = 1, 2
local POCKET_ITEMS = 0
local CONTEXT_RUNNING = 0
local SPECIES_ABRA, SPECIES_RATTATA = 63, 19
local MOVE_TELEPORT, MOVE_DIG, MOVE_FLY = 100, 91, 19
local ROW_TELEPORT, ROW_DIG, ROW_FLY = 1, 2, 3
local ITEM_ESCAPE_ROPE, ITEM_HUB_PASS = 120, 893
local MT_SILVER = { g = 97, m = 0 }
local MT_SILVER_CENTER = { g = 97, m = 9, id = 47 }
local ROUTE11 = { g = 37, m = 29 }
local gates = {
  [KANTO] = { attendant = 11, g = 37, m = 5 },
  [JOHTO] = { attendant = 16, g = 84, m = 23 },
}
local function count() return F.r8(S.gPartiesCount) end
local function party(slot) return S.gParties + (slot or 0) * S.Pokemon.size end
local function box(slot) return F.r32(S.gPokemonStoragePtr) + 4 + slot * 80 end
local function present(address) return (F.r8(address + 19) & 2) ~= 0 end
local function region() return F.r8(F.sb2() + S.SaveBlock2.currentRegion) end
local function travelBank() return F.sb3() + S.SaveBlock3.regionalTravel end
local function rememberedCenter(r) return F.r16(travelBank() + 160 + (r - 1) * 2) end

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
local function where() local x, y = F.pos(); return string.format("%d/%d (%d,%d)", F.grp(), F.mapn(), x, y) end
local function mapIs(g, m) return F.grp() == g and F.mapn() == m end
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
local function inPartyMenu()
  local c = F.cb2()
  return c == S.CB2_UpdatePartyMenu or c == S.CB2_InitPartyMenu or c == S.CB2_PartyMenuFromStartMenu
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
-- arrival: 0 resumes at the remembered Center, 1 is the standard arrival.
local function cross(r, arrival, g, m, tag)
  local x = gates[r].attendant
  drain()
  if not F.route({ { 16, 4 }, { x, 4 }, { x, 3 } }, tag .. "_walk") then return false end
  F.face("Up"); F.press("A", 3); F.idle(60)
  if not menu(1, tag .. "_team") then return false end
  if not menu(arrival, tag .. "_arrival") then return false end
  if not menu(0, tag .. "_confirm") then return false end
  return awaitMap(g, m, tag) and awaitControl(600)
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
local function d(n) return (n // 100) % 10, (n // 10) % 10, n % 10 end
local function warp(g, m, w, tag)
  local gh, gt, go = d(g)
  local mh, mt, mo = d(m)
  local wh, wt, wo = d(w)
  return F.warpTo(gh, gt, go, mh, mt, mo, wh, wt, wo, g, m, tag)
end
-- Step off a door tile the debug warp landed on, then walk back into the door.
local function walkInto(g, m, tag)
  F.step("Down")
  for _ = 1, 4 do
    F.press("Up", 16); F.idle(20)
    for _ = 1, 120 do
      if mapIs(g, m) and hasControl() then return true end
      F.idle(2)
    end
  end
  F.shot(tag .. "_nodoor")
  return false
end
local function walkOutDown(tag)
  local from = { F.grp(), F.mapn() }
  for _ = 1, 6 do
    F.press("Down", 16)
    for _ = 1, 100 do
      if not mapIs(from[1], from[2]) and hasControl() then return true end
      F.idle(2)
    end
  end
  F.shot(tag .. "_noexit")
  return false
end

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
-- Bag, Escape Rope, Use. Returns once the field is back, whether the rope warped or was refused.
local function tryEscapeRope(tag)
  F.w8(S.gBagPosition + 5, POCKET_ITEMS)
  F.w16(S.gBagPosition + 8 + POCKET_ITEMS * 2, 0)
  F.w16(S.gBagPosition + 18 + POCKET_ITEMS * 2, 0)
  awaitControl(300)
  F.press("Start", 2); F.idle(60)
  if not F.selectStartIcon(USM_ICO_BAG) then return false end
  F.press("A", 2)
  for _ = 1, 150 do if inBag() then break end; F.idle(2) end
  F.idle(40)
  F.press("A", 2); F.idle(40)
  F.shot(tag .. "_actions")
  F.press("A", 2); F.idle(90)
  F.shot(tag .. "_used")
  for _ = 1, 600 do
    if hasControl() then break end
    if inBag() and _ % 40 == 0 then F.press("B", 2) else F.idle(2) end
  end
  return awaitControl(600)
end
local function tryDig(tag)
  if not openParty(tag) then return false end
  F.press("A", 3); F.idle(50)
  for _ = 1, ROW_DIG do F.press("Down", 2); F.idle(12) end
  F.shot(tag .. "_actions")
  F.press("A", 3); F.idle(60)
  F.shot(tag .. "_chosen")
  -- Yes to the exit question if Dig is allowed; B backs out of a refusal.
  for _ = 1, 20 do
    if not inPartyMenu() then break end
    F.press("Up", 2); F.idle(6); F.press("A", 2); F.idle(30)
  end
  for _ = 1, 600 do
    if hasControl() then break end
    if inPartyMenu() and _ % 40 == 0 then F.press("B", 2) else F.idle(2) end
  end
  return awaitControl(600)
end

local function checkStayed(tag)
  local x, y = F.pos()
  F.L(string.format("  %s: now at %s region=%d escape=%s", tag, where(), region(), escape()))
  F.check(tag .. ": the player is still on Mt. Silver's doorstep", mapIs(MT_SILVER.g, MT_SILVER.m),
    string.format("%s region=%d", where(), region()))
  F.check(tag .. ": the saved region is still Johto", region() == JOHTO, "region=" .. region())
end

F.run(function()
  if not F.boot(HUB[1]) then F.check("boot to the hub", false); F.finish(); return end
  F.w16(F.sb2() + S.SaveBlock2.optionsU16, (F.r16(F.sb2() + S.SaveBlock2.optionsU16) & ~7) | 3)
  -- Openings and first badges, Johto past Ilex, and the Mt. Silver guard gone.
  for _, id in ipairs({ 0xDCF, 0x51, 0xA4B, 0x63F8, 0x94F, 0x95F, 0x63FC, 0x63FD, 0x948, 0x61E5 }) do flag(id, true) end
  F.w8(F.sb2() + S.SaveBlock2.introDoneBits, 7)
  createMon(SPECIES_ABRA, 30, { MOVE_TELEPORT, MOVE_DIG, MOVE_FLY })
  createMon(SPECIES_RATTATA, 12, { 33 })
  ropeFirst(9)
  drain()
  F.check("setup: two Pokemon and Escape Ropes", count() == 2 and ropeCount() == 9, "party=" .. count())

  -- Johto: visit the Mt. Silver Pokemon Center, which the gate remembers.
  F.check("cross to Johto", cross(JOHTO, 1, 84, 23, "johto"), where())
  local visited = warp(MT_SILVER.g, MT_SILVER.m, 1, "mtsilver_door") and walkInto(MT_SILVER_CENTER.g, MT_SILVER_CENTER.m, "center")
  F.check("walked into the Mt. Silver Pokemon Center", visited, where())
  F.check("the gate remembers the Mt. Silver Center", rememberedCenter(JOHTO) == MT_SILVER_CENTER.id,
    "center=" .. rememberedCenter(JOHTO))
  F.check("Hub Pass out of Johto", passToHub("johto_pass"), where())

  -- Kanto: walk into Diglett's Cave from Route 11, so the escape warp names Route 11.
  F.check("cross to Kanto", cross(KANTO, 1, 37, 5, "kanto"), where())
  local caved = warp(ROUTE11.g, ROUTE11.m, 0, "route11_door") and walkInto(35, 38, "digletts")
  local eg, em = escapeXY()
  F.check("walked into Diglett's Cave; the escape warp is Route 11", caved and eg == ROUTE11.g and em == ROUTE11.m, escape())
  F.check("walked back out to Route 11", walkOutDown("digletts_out") and mapIs(ROUTE11.g, ROUTE11.m), where())
  F.check("Hub Pass out of Kanto", passToHub("kanto_pass"), where())

  -- Johto again, resuming at the Mt. Silver Center, then out onto the doorstep.
  F.check("Johto gate resumes at the Mt. Silver Center", cross(JOHTO, 0, MT_SILVER_CENTER.g, MT_SILVER_CENTER.m, "resume"), where())
  F.check("walked out onto Mt. Silver's doorstep", walkOutDown("center_out") and mapIs(MT_SILVER.g, MT_SILVER.m), where())
  F.L("  doorstep: escape warp " .. escape() .. " region " .. region())

  local ropes = ropeCount()
  F.check("Escape Rope: the Bag returned to the field", tryEscapeRope("rope"), where())
  checkStayed("Escape Rope")
  F.check("Escape Rope: no rope used", ropeCount() == ropes, ropes .. "->" .. ropeCount())

  if not mapIs(MT_SILVER.g, MT_SILVER.m) then
    -- Unfixed: the rope left Johto. Come back the same way for the Dig check.
    passToHub("back_pass")
    cross(JOHTO, 0, MT_SILVER_CENTER.g, MT_SILVER_CENTER.m, "resume2")
    walkOutDown("center_out2")
  end
  F.check("Dig: the party menu returned to the field", tryDig("dig"), where())
  checkStayed("Dig")

  -- Control: Diglett's Cave still escapes to Route 11 with both moves.
  local ok = passToHub("control_pass") and cross(KANTO, 1, 37, 5, "control_kanto")
    and warp(ROUTE11.g, ROUTE11.m, 0, "control_door") and walkInto(35, 38, "control_cave")
  F.check("control: back in Diglett's Cave", ok, where())
  if ok then
    tryEscapeRope("control_rope")
    F.check("control: Escape Rope in the cave lands on Route 11", mapIs(ROUTE11.g, ROUTE11.m), where())
    if walkInto(35, 38, "control_cave2") then
      tryDig("control_dig")
      F.check("control: Dig in the cave lands on Route 11", mapIs(ROUTE11.g, ROUTE11.m), where())
    end
  end
  F.finish()
end)
