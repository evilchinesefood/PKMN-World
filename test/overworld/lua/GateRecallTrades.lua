-- World Transit gate recall when the remembered team changed through the game's own flows:
-- a member traded away in an in-game trade, a member left at the Route 5 Day Care, an Egg hatched
-- by the hatch scene, a Caterpie evolved by a Rare Candy, a collectible special Pokemon (Squad
-- Squirtle from SpecialPokemon_Give), and a Pokemon received in a Kanto in-game trade that leaves
-- Kanto and is recalled on return.
--
-- Johto remembers six. In Kanto the Abra is traded for Mr. Mime, the Pidgey goes to the Day Care,
-- the Egg hatches and the Caterpie evolves, all with real input. The Johto recall must carry the
-- four reachable members in remembered order, leave the Pidgey in the Day Care, and box Mr. Mime.
-- The Kanto recall must then bring Mr. Mime back out of the PC. Every Pokemon is counted by
-- personality across the party, the PC and both Day Cares after each step, and a save and Continue
-- closes the run.
--
-- Run via test/overworld/mgba-run.sh test/overworld/lua/GateRecallTrades.lua <rom>

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "GateRecallTrades")

local HUB = { 100, 0 }
local SLOTS = 14 * 30
local KANTO, JOHTO = 1, 2
local USM_ICO_BAG, USM_ICO_SAVE = 2, 7
local POCKET_ITEMS = 0
local SENTINEL = 0xFFFF
local CONTEXT_RUNNING = 0
local SPECIES_CATERPIE, SPECIES_METAPOD, SPECIES_SPEAROW, SPECIES_PIDGEY = 10, 11, 21, 16
local SPECIES_ABRA, SPECIES_MR_MIME, SPECIES_TOGEPI, SPECIES_SQUIRTLE_SQUAD = 63, 122, 175, 1576
local ITEM_RARE_CANDY, ITEM_HUB_PASS = 102, 893
local SPECIAL_POKEMON_SQUAD = 3
local SPECIAL_SPECIAL_POKEMON_GIVE = 667
local FLAG_SPECIAL_COLLECTED_SQUAD, FLAG_SPECIAL_UNLOCKED_SQUAD = 0xDD3, 0xDDD

local gates = {
  [KANTO] = { attendant = 11, g = 37, m = 5 },
  [JOHTO] = { attendant = 16, g = 84, m = 23 },
}

local function where() local x, y = F.pos(); return string.format("%d/%d (%d,%d)", F.grp(), F.mapn(), x, y) end
local function mapIs(g, m) return F.grp() == g and F.mapn() == m end
local function count() return F.r8(S.gPartiesCount) end
local function party(slot) return S.gParties + (slot or 0) * S.Pokemon.size end
local function box(slot) return F.r32(S.gPokemonStoragePtr) + 4 + slot * 80 end
local function daycare() return F.sb1() + S.SaveBlock1.daycare end
local function route5() return F.sb3() + S.SaveBlock3.route5DayCareMon end
local function present(address) return (F.r8(address + 19) & 2) ~= 0 end
local function isEgg(address) return (F.r8(address + 19) & 4) ~= 0 end
local function pid(address) return F.r32(address) end
local function travelBank() return F.sb3() + S.SaveBlock3.regionalTravel end
local function teamCount(r) return F.r8(travelBank() + 4 + (r - 1) * 52 + 48) end

local function flag(id, value)
  local a = F.sb1() + S.SaveBlock1.flags + id // 8
  local bit = 1 << (id % 8)
  F.w8(a, value and (F.r8(a) | bit) or (F.r8(a) & (~bit & 255)))
end
local function flagSet(id) return (F.r8(F.sb1() + S.SaveBlock1.flags + id // 8) & (1 << (id % 8))) ~= 0 end
local function johtoFlag(id)
  local a = F.sb3() + S.SaveBlock3.johtoFlags + (id - 0x6000) // 8
  F.w8(a, F.r8(a) | (1 << ((id - 0x6000) % 8)))
end

local function order(p)
  local o = {}
  for i = 0, 3 do o[i] = F.r8(S.sSubstructOffsets + i * 24 + p % 24) * 3 end
  return o
end
local function species(address)
  local key = F.r32(address) ~ F.r32(address + 4)
  local o = order(F.r32(address))
  return (F.r32(address + 32 + (o[0] + 0) * 4) ~ key) & 0x7FF
end

-- Every Pokemon by personality, wherever the game keeps it.
local function census()
  local seen, dupes, n = {}, {}, 0
  local function add(address, at)
    if not present(address) then return end
    local p = pid(address)
    n = n + 1
    if seen[p] then dupes[#dupes + 1] = string.format("%08X@%s", p, at) end
    seen[p] = at
  end
  for i = 0, 5 do add(party(i), "party" .. i) end
  for i = 0, SLOTS - 1 do add(box(i), "box" .. i) end
  add(daycare(), "daycare")
  add(route5(), "route5")
  return { seen = seen, dupes = dupes, n = n }
end
local function checkCensus(tag, before, gone, arrived)
  local now = census()
  local ok, why = #now.dupes == 0, (#now.dupes > 0) and ("cloned " .. table.concat(now.dupes, ",")) or ""
  for p, at in pairs(before.seen) do
    if not now.seen[p] and not (gone and gone[p]) then ok = false; why = why .. string.format(" lost %08X(%s)", p, at) end
  end
  for p, at in pairs(now.seen) do
    if not before.seen[p] and not (arrived and arrived[p]) then ok = false; why = why .. string.format(" new %08X@%s", p, at) end
  end
  F.check(tag, ok, ok and (now.n .. " Pokemon") or why)
  return now
end
local function partyList()
  local t = {}
  for i = 0, count() - 1 do t[#t + 1] = string.format("%08X:%d%s", pid(party(i)), species(party(i)), isEgg(party(i)) and "e" or "") end
  return table.concat(t, " ")
end
local function partyIs(pids, tag)
  local ok = count() == #pids
  for i = 1, #pids do ok = ok and pid(party(i - 1)) == pids[i] end
  F.check(tag, ok, "party=" .. partyList())
  return ok
end

local function decodeText(address, max)
  local t = {}
  for i = 0, (max or 600) - 1 do
    local b = F.r8(address + i)
    if b == 0xFF then break end
    if b >= 0xBB and b <= 0xD4 then t[#t + 1] = string.char(65 + b - 0xBB)
    elseif b >= 0xD5 and b <= 0xEE then t[#t + 1] = string.char(97 + b - 0xD5)
    elseif b >= 0xA1 and b <= 0xAA then t[#t + 1] = string.char(48 + b - 0xA1)
    elseif b == 0x00 then t[#t + 1] = " "
    elseif b == 0xAD then t[#t + 1] = "."
    elseif b == 0xB8 then t[#t + 1] = ","
    elseif b == 0xF0 then t[#t + 1] = ":"
    elseif b == 0x1B then t[#t + 1] = "e"
    elseif b >= 0xFA and b <= 0xFE then t[#t + 1] = "|"
    else t[#t + 1] = "?" end
  end
  return table.concat(t)
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
local function createMon(sp, level, moves)
  local b = { 0x23 }; le32(b, S.ScrCmd_createmon | 1)
  b[#b + 1] = 0; b[#b + 1] = 6
  le16(b, sp); le16(b, level)
  le32(b, (1 << 17) | (1 << 18) | (1 << 19) | (1 << 20))
  for k = 1, 4 do le16(b, moves[k] or 0) end
  b[#b + 1] = 0x02
  runScript(b); F.idle(20)
  return count()
end
-- The gift path the special Pokemon NPCs use: setvar VAR_0x8004, id; special SpecialPokemon_Give.
local function giveSpecial(id)
  local b = { 0x16 }; le16(b, 0x8004); le16(b, id)
  b[#b + 1] = 0x25; le16(b, SPECIAL_SPECIAL_POKEMON_GIVE)
  b[#b + 1] = 0x02
  runScript(b); F.idle(30)
  return count()
end
local function giveEgg(sp)
  local b = { 0x7A }; le16(b, sp); b[#b + 1] = 0x02
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
local preview = ""
-- team: 0 recall, 1 keep. With `partial`, answers the partial-team question Yes and keeps the
-- preview text the gate buffered for it.
local function cross(r, team, tag, partial)
  local x = gates[r].attendant
  drain()
  if not F.route({ { 16, 4 }, { x, 4 }, { x, 3 } }, tag .. "_walk") then return false end
  F.face("Up"); F.press("A", 3); F.idle(60)
  if not menu(team, tag .. "_team") then return false end
  if not menu(1, tag .. "_arrival") then return false end
  if partial then
    preview = decodeText(S.gStringVar4)
    F.L("  " .. tag .. " preview: " .. preview)
    if not menu(0, tag .. "_partial") then return false end
  end
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

local function d(n) return (n // 100) % 10, (n // 10) % 10, n % 10 end
local function warp(g, m, w, tag)
  local gh, gt, go = d(g)
  local mh, mt, mo = d(m)
  local wh, wt, wo = d(w)
  return F.warpTo(gh, gt, go, mh, mt, mo, wh, wt, wo, g, m, tag)
end

-- ---- party-select screens (trade, Day Care, hatch, Rare Candy) ------------------------------------
local function inPartyMenu()
  local c = F.cb2()
  return c == S.CB2_UpdatePartyMenu or c == S.CB2_InitPartyMenu or c == S.CB2_PartyMenuFromStartMenu
end
local function partySlot() return F.rs8(S.gPartyMenu + 9) end
local function awaitPartyMenu(tag, passive)
  for t = 1, 400 do
    if inPartyMenu() then F.idle(40); return true end
    if t % 40 == 0 and not passive then F.press("A", 2) else F.idle(1) end
    if F.reportCrash(tag) then return false end
  end
  F.shot(tag .. "_nopartymenu")
  return false
end
local function chooseSlot(slot, tag, passive)
  if not awaitPartyMenu(tag, passive) then return false end
  for _ = 1, 12 do
    if partySlot() == slot then break end
    F.press(partySlot() > slot and "Up" or "Down", 2); F.idle(14)
  end
  F.shot(tag .. "_choose")
  if partySlot() ~= slot then return false end
  F.press("A", 2); F.idle(30)
  return true
end
-- Press `key` through whatever follows (trade scene, hatch scene, messages) until the field is back.
-- The hatch scene's nickname question takes B for No.
local function untilField(tag, budget, key)
  for i = 1, budget or 6000 do
    if i > 60 and hasControl() then F.idle(20); if hasControl() then return true end end
    if i % 60 == 0 and F.reportCrash(tag) then return false end
    if i % 12 == 0 then F.press(key or "A", 2) else F.idle(1) end
  end
  F.shot(tag .. "_stuck")
  return false
end

local function talkFrom(path, facing, tag)
  if not F.route(path, tag .. "_walk") then return false end
  F.face(facing); F.press("A", 3); F.idle(40)
  return true
end

local function instantText()
  F.w16(F.sb2() + S.SaveBlock2.optionsU16, (F.r16(F.sb2() + S.SaveBlock2.optionsU16) & ~7) | 3)
end

-- ---- save and Continue ----------------------------------------------------------------------------
local function driveSave()
  F.w16(S.gSaveAttemptStatus, SENTINEL)
  awaitControl(300)
  F.press("Start", 2); F.idle(60)
  if not F.selectStartIcon(USM_ICO_SAVE) then return "noicon" end
  for i = 1, 3000 do
    if F.r16(S.gSaveAttemptStatus) ~= SENTINEL then
      F.idle(30)
      for _ = 1, 6 do F.press("B", 2); F.idle(20) end
      return F.r16(S.gSaveAttemptStatus) == 1 and "done" or "failed"
    end
    if i % 20 == 1 then joypad.set({ A = true }) else joypad.set({}) end
    emu.frameadvance()
  end
  return "timeout"
end

F.run(function()
  if not F.boot(HUB[1]) then F.check("boot to the hub", false); F.finish(); return end
  instantText()
  for _, id in ipairs({ 0xDCF, 0x51, 0xA4B, 0x94F, 0x95F, 0x948, FLAG_SPECIAL_UNLOCKED_SQUAD }) do flag(id, true) end
  johtoFlag(0x63F8)
  johtoFlag(0x63FD) -- past Ilex, so the standard Johto arrival is Goldenrod station
  F.w8(F.sb2() + S.SaveBlock2.introDoneBits, 7)

  createMon(SPECIES_CATERPIE, 6, { 33, 81 })
  giveSpecial(SPECIAL_POKEMON_SQUAD)
  createMon(SPECIES_SPEAROW, 10, { 64 })
  createMon(SPECIES_PIDGEY, 10, { 33 })
  giveEgg(SPECIES_TOGEPI)
  createMon(SPECIES_ABRA, 10, { 100 })
  drain()
  local want = { SPECIES_CATERPIE, SPECIES_SQUIRTLE_SQUAD, SPECIES_SPEAROW, SPECIES_PIDGEY, nil, SPECIES_ABRA }
  local ok = count() == 6 and isEgg(party(4))
  for i = 1, 6 do if want[i] then ok = ok and species(party(i - 1)) == want[i] end end
  F.check("setup: Caterpie, Squad Squirtle, Spearow, Pidgey, an Egg and Abra", ok, "party=" .. partyList())
  F.check("setup: SpecialPokemon_Give recorded Squad Squirtle as collected", flagSet(FLAG_SPECIAL_COLLECTED_SQUAD))
  if not ok then F.finish(); return end
  local P = {}
  for i = 0, 5 do P[i + 1] = pid(party(i)) end
  local caterpie, squad, spearow, pidgey, egg, abra = P[1], P[2], P[3], P[4], P[5], P[6]

  -- Johto remembers all six.
  F.check("cross to Johto keeping the party", cross(JOHTO, 1, "johto_keep"), where())
  F.check("Hub Pass out of Johto", passToHub("depart_johto"), where())
  F.check("Johto remembers six", teamCount(JOHTO) == 6, "count=" .. teamCount(JOHTO))

  -- Kanto, with the Johto team still carried.
  F.check("cross to Kanto keeping the Johto team", cross(KANTO, 1, "kanto_keep"), where())
  local before = census()

  -- Route 2 house: Abra for Mr. Mime.
  local traded = warp(49, 1, 0, "route2_house")
    and talkFrom({ { 3, 6 }, { 7, 6 }, { 7, 3 } }, "Up", "reyley")
    and menu(0, "reyley_yes") and chooseSlot(5, "reyley") and untilField("reyley_trade", 9000, "A")
  local mime = pid(party(5))
  F.check("Abra traded for Mr. Mime in the Route 2 house", traded and species(party(5)) == SPECIES_MR_MIME,
    where() .. " party=" .. partyList())
  before = checkCensus("the trade swapped Abra for Mr. Mime and nothing else", before, { [abra] = true }, { [mime] = true })

  -- Route 5 Day Care: the Pidgey stays behind.
  local left = warp(51, 0, 0, "route5_daycare")
    and talkFrom({ { 3, 6 }, { 4, 6 }, { 4, 5 } }, "Up", "daycare_man")
    and menu(0, "daycare_yes") and chooseSlot(3, "daycare") and untilField("daycare_deposit", 3000, "A")
  F.check("Pidgey left at the Route 5 Day Care", left and present(route5()) and pid(route5()) == pidgey,
    string.format("route5=%08X party=%s", pid(route5()), partyList()))
  before = checkCensus("the Day Care deposit moved only the Pidgey", before)

  -- The Egg hatches through the hatch scene (party slot 3 after the deposit).
  F.dbg(); F.sel(2); F.sel(1)
  local hatched = chooseSlot(3, "hatch") and untilField("hatch_scene", 9000, "B")
  F.check("the Egg hatched by the hatch scene keeps its personality", hatched and pid(party(3)) == egg
    and not isEgg(party(3)) and species(party(3)) == SPECIES_TOGEPI, "party=" .. partyList())

  -- A Rare Candy evolves the Caterpie (slot 0).
  local ptr = F.r32(S.gBagPockets + POCKET_ITEMS * S.BagPocket.stride)
  local key = F.r32(F.sb2() + S.SaveBlock2.encryptionKey) & 0xFFFF
  for s = 0, F.pocketCap(POCKET_ITEMS) - 1 do F.w16(ptr + s * 4, 0); F.w16(ptr + s * 4 + 2, key) end
  F.w16(ptr, ITEM_RARE_CANDY); F.w16(ptr + 2, 1 ~ key)
  F.w8(S.gBagPosition + 5, POCKET_ITEMS)
  F.w16(S.gBagPosition + 8 + POCKET_ITEMS * 2, 0)
  F.w16(S.gBagPosition + 18 + POCKET_ITEMS * 2, 0)
  awaitControl(300)
  F.press("Start", 2); F.idle(60)
  local evolved = F.selectStartIcon(USM_ICO_BAG)
  if evolved then
    F.press("A", 2)
    for _ = 1, 150 do if F.cb2() == (S.CB2_BagMenuRun & ~1) then break end; F.idle(2) end
    F.idle(40)
    F.shot("candy_bag")
    -- The SwSh Bag picks the target in its own party column: actions, Use, slot 0.
    F.press("A", 2); F.idle(40)
    F.press("A", 2); F.idle(60)
    F.shot("candy_target")
    F.press("A", 2); F.idle(60)
    -- A through the level-up and the evolution (B would cancel it), then B back to the field.
    local scene = false
    for i = 1, 4000 do
      if F.r32(S.sEvoStructPtr) ~= 0 then scene = true end
      if scene and F.r32(S.sEvoStructPtr) == 0 and F.cb2() == (S.CB2_BagMenuRun & ~1) then break end
      if i % 60 == 0 and F.reportCrash("candy") then evolved = false; break end
      if i % 20 == 0 then F.press("A", 2) else F.idle(1) end
    end
    F.L("  candy: evolution scene ran=" .. tostring(scene))
    evolved = evolved and untilField("candy_back", 3000, "B")
  end
  F.check("the Rare Candy evolved Caterpie into Metapod", evolved and pid(party(0)) == caterpie
    and species(party(0)) == SPECIES_METAPOD, where() .. " party=" .. partyList())
  before = checkCensus("hatching and evolving kept every Pokemon once", before)

  -- Kanto now remembers Metapod, Squad, Spearow, Togepi and Mr. Mime.
  F.check("Hub Pass out of Kanto", passToHub("depart_kanto"), where())
  F.check("Kanto remembers five", teamCount(KANTO) == 5, "count=" .. teamCount(KANTO))

  -- Johto recall: Abra was traded away and Pidgey is at the Day Care.
  before = census()
  F.check("partial Johto recall", cross(JOHTO, 0, "recall_johto", true), where())
  F.check("the preview names the Day Care member", preview:find("DAY CARE", 1, true) ~= nil, preview)
  F.check("the preview names the traded-away member as missing", preview:find("not in party or PC", 1, true) ~= nil, preview)
  partyIs({ caterpie, squad, spearow, egg }, "Johto recall carries the four reachable members in remembered order")
  F.check("the evolved and hatched members arrive as Metapod and Togepi",
    species(party(0)) == SPECIES_METAPOD and species(party(3)) == SPECIES_TOGEPI and not isEgg(party(3)))
  F.check("Squad Squirtle arrives as Squad Squirtle", species(party(1)) == SPECIES_SQUIRTLE_SQUAD,
    "species=" .. species(party(1)))
  checkCensus("Johto recall keeps every Pokemon once", before)
  local boxed = false
  for i = 0, SLOTS - 1 do if present(box(i)) and pid(box(i)) == mime then boxed = true end end
  F.check("Mr. Mime, not on Johto's team, went to the PC", boxed)
  F.check("Pidgey is still at the Route 5 Day Care", present(route5()) and pid(route5()) == pidgey)

  -- Kanto recall brings the Kanto-traded Mr. Mime back.
  F.check("Hub Pass out of Johto again", passToHub("depart_johto2"), where())
  before = census()
  F.check("full Kanto recall", cross(KANTO, 0, "recall_kanto"), where())
  partyIs({ caterpie, squad, spearow, egg, mime }, "Kanto recall brings back its team, Mr. Mime from the PC")
  F.check("Mr. Mime keeps its species", species(party(4)) == SPECIES_MR_MIME, "species=" .. species(party(4)))
  checkCensus("Kanto recall keeps every Pokemon once", before)
  F.check("Squad Squirtle is still recorded as collected", flagSet(FLAG_SPECIAL_COLLECTED_SQUAD))

  -- Save, soft reset, Continue.
  before = census()
  local partyBefore = partyList()
  F.check("save after the recalls", driveSave() == "done")
  for _ = 1, 8 do joypad.set({ A = true, B = true, Start = true, Select = true }); emu.frameadvance() end
  joypad.set({})
  F.idle(60)
  F.check("Continue", F.boot(nil, true), where())
  F.idle(30)
  checkCensus("Continue loads every Pokemon once", before)
  F.check("Continue loads the recalled party", partyList() == partyBefore, partyList() .. " vs " .. partyBefore)
  F.finish()
end)
