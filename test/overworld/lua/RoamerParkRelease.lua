-- Burned Tower with a Hoenn Lati already roaming: ROAMER_COUNT is 2, so Entei takes the free slot
-- and Raikou is parked until a slot frees. Defeating Entei frees one. The parked Raikou must take
-- it, and the defeated Entei must stay gone (outside the parked case a defeated beast returns
-- only at the Johto Hall of Fame). Nothing may be lost or duplicated across map loads and the Hub.
--
-- Setup gives a level 100 Arena Trap Dugtrio, runs the Lati TV special the Littleroot scene runs (InitRoamer
-- with the colour in VAR_0x8004), and sets the Ecruteak state that arms the Burned Tower scene.
-- The beast release, the walk, the encounter and the battle are the game's own on real input. The
-- one convenience is moving Entei's EWRAM map position onto Route 31 so the grass finds it (a
-- roamer's map is random and re-rolled on every map change). Map loads are debug warps.
local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "RoamerParkRelease")

local BURNED_TOWER_B1F = {86, 11}
local ROUTE31, DARK_CAVE_SOUTH = {75, 4}, {94, 16}
local SPECIES_DUGTRIO, SPECIES_RAIKOU, SPECIES_ENTEI, SPECIES_LATIAS = 51, 243, 244, 380
local MOVE_EARTHQUAKE = 89
local ABILITY_SLOT_ARENA_TRAP = 1
local VAR_ECRUTEAK_CITY_STATE, VAR_ROAMER_POKEMON = 0xA0A0, 0x40D5
local VAR_0x8004 = 0x8004
local FLAG_LATIOS_OR_LATIAS_ROAMING = 0xFF
local BATTLE_TYPE_ROAMER = 1 << 10
local ROAMER_COUNT, ROAMER_SIZE = 2, 28
local CONTEXT_RUNNING = 0
local PARTY_SIZE = 6

local function where() local x, y = F.pos(); return string.format("%d/%d (%d,%d)", F.grp(), F.mapn(), x, y) end
local function mapIs(m) return F.grp() == m[1] and F.mapn() == m[2] end
local function count() return F.r8(S.gPartiesCount) end
local function flagSet(id, on)
  local a = F.sb1() + S.SaveBlock1.flags + id // 8
  local bit = 1 << (id % 8)
  F.w8(a, on and (F.r8(a) | bit) or (F.r8(a) & (~bit & 0xFF)))
end
local function varSet(id, v)
  if id >= 0xA000 then F.w16(F.sb3() + S.SaveBlock3.regionVars + (id - 0xA000) * 2, v)
  else F.w16(F.sb1() + S.SaveBlock1.vars + (id - 0x4000) * 2, v) end
end
local function varGet(id)
  if id >= 0xA000 then return F.r16(F.sb3() + S.SaveBlock3.regionVars + (id - 0xA000) * 2) end
  return F.r16(F.sb1() + S.SaveBlock1.vars + (id - 0x4000) * 2)
end

-- roamer slots, read straight from SaveBlock1
local function slot(i)
  local a = F.sb1() + S.SaveBlock1.roamer + i * ROAMER_SIZE
  return { species = F.r16(a + 8), personality = F.r32(a + 4), active = F.r8(a + 19) ~= 0, hp = F.r16(a + 10) }
end
local function roaming()
  local list, by = {}, {}
  for i = 0, ROAMER_COUNT - 1 do
    local s = slot(i)
    if s.active then list[#list + 1] = s.species; by[s.species] = (by[s.species] or 0) + 1 end
  end
  return by, table.concat(list, ",")
end
local function slotOf(species)
  for i = 0, ROAMER_COUNT - 1 do
    local s = slot(i)
    if s.active and s.species == species then return i, s end
  end
end
local function noDuplicates()
  local by = roaming()
  for _, n in pairs(by) do if n > 1 then return false end end
  return true
end

-- scripts run from EWRAM (the tail of gStringVar4), as DoubleBattleStress does
local SCRIPT_BUF = S.gStringVar4 + 960
local function le16(t, v) t[#t + 1] = v & 0xFF; t[#t + 1] = (v >> 8) & 0xFF end
local function le32(t, v) le16(t, v & 0xFFFF); le16(t, (v >> 16) & 0xFFFF) end
local function runScript(bytes)
  for i, b in ipairs(bytes) do F.w8(SCRIPT_BUF + i - 1, b) end
  F.w8(S.sGlobalScriptContext, 0)
  F.w8(S.sGlobalScriptContext + 1, 1)
  F.w32(S.sGlobalScriptContext + 4, 0)
  F.w32(S.sGlobalScriptContext + S.ScriptCtx.scriptPtr, SCRIPT_BUF)
  F.w8(S.sGlobalScriptContextStatus, CONTEXT_RUNNING)
  F.idle(20)
end
-- createmon (src/script_pokemon_util.c) with the ability slot (flag bit 3) and four moves (17-20).
local function giveMon(species, level, abilityNum, moves)
  local b = { 0x23 }; le32(b, S.ScrCmd_createmon | 1)
  b[#b + 1] = 0; b[#b + 1] = PARTY_SIZE
  le16(b, species); le16(b, level)
  le32(b, (1 << 3) | (1 << 17) | (1 << 18) | (1 << 19) | (1 << 20))
  le16(b, abilityNum)
  for k = 1, 4 do le16(b, moves[k] or 0) end
  b[#b + 1] = 0x02
  runScript(b)
end
-- Gen 8+ obedience reads the met level; lower it as OweContactCoordEvent.lua does (substruct 3,
-- encrypted with personality ^ otId, checksum adjusted).
local SUB3 = { 3, 2, 3, 2, 1, 1, 3, 2, 3, 2, 1, 1, 3, 2, 3, 2, 1, 1, 0, 0, 0, 0, 0, 0 }
local function setMetLevel(slotIdx, lvl)
  local b = S.gParties + slotIdx * S.Pokemon.size
  local pid, otid = F.r32(b), F.r32(b + 4)
  local key = pid ~ otid
  local addr = b + 32 + 12 * SUB3[(pid % 24) + 1]
  local old = F.r32(addr) ~ key
  local new = (old & ~(0x7F << 16)) | ((lvl & 0x7F) << 16)
  local function halves(v) return (v & 0xFFFF) + (v >> 16) end
  F.w32(addr, new ~ key)
  F.w16(b + 28, (F.r16(b + 28) - halves(old) + halves(new)) & 0xFFFF)
end
-- players_house.inc: multichoice -> copyvar VAR_0x8004 -> special InitRoamer -> copyvar VAR_ROAMER_POKEMON
local function laTiTvScene(colour)
  local b = { 0x16 }; le16(b, VAR_0x8004); le16(b, colour)          -- setvar
  b[#b + 1] = 0x23; le32(b, S.InitRoamer | 1)                       -- callnative InitRoamer
  b[#b + 1] = 0x16; le16(b, VAR_ROAMER_POKEMON); le16(b, colour)
  b[#b + 1] = 0x02
  runScript(b)
  flagSet(FLAG_LATIOS_OR_LATIAS_ROAMING, true)
end

local function hasControl()
  return F.ow() and F.r8(S.sLockFieldControls) == 0 and F.r8(S.sGlobalScriptContextStatus) ~= CONTEXT_RUNNING
end
local function settle(budget)
  for i = 1, budget or 2400 do
    if hasControl() and i > 30 then F.idle(20); if hasControl() then return true end end
    if i % 20 == 0 then F.press("A", 2) else F.idle(1) end
    if i % 120 == 0 and F.reportCrash("settle") then return false end
  end
  return hasControl()
end
local function awaitMap(m, budget)
  for _ = 1, budget or 600 do
    if mapIs(m) and F.ow() then F.idle(60); return true end
    F.idle(1)
  end
  return false
end

-- Wild battles on the way are fled by holding B (auto-run); the roamer battle is fought with
-- Earthquake, the Dugtrio's only move.
local function battle()
  local roamer = (F.battleFlags() & BATTLE_TYPE_ROAMER) ~= 0
  for i = 1, 6000 do
    if F.ow() and i > 60 then break end
    if roamer then
      if i % 25 == 0 then F.press("A", 2) else F.idle(1) end
    else
      local tapA = (i % 40) < 3
      joypad.set({ B = true, A = tapA or nil }); emu.frameadvance()
    end
    if i % 300 == 0 and F.reportCrash("battle") then return roamer, false end
  end
  F.idle(60)
  return roamer, F.ow()
end

F.run(function()
  if not F.boot(100) then F.check("boot", false); F.finish(); return end
  -- A roamer flees on its first turn, and running beats any move, so the beast is held by Arena Trap.
  giveMon(SPECIES_DUGTRIO, 100, ABILITY_SLOT_ARENA_TRAP, { MOVE_EARTHQUAKE })
  setMetLevel(0, 5)
  F.check("setup: a level 100 Arena Trap Dugtrio leads", count() == 1, "n=" .. count())
  laTiTvScene(0)
  local lati = slotOf(SPECIES_LATIAS)
  local latiBefore = lati and slot(lati)
  F.check("setup: the Lati TV special left Latias roaming", latiBefore ~= nil, select(2, roaming()))
  if not latiBefore then F.finish(); return end

  varSet(VAR_ECRUTEAK_CITY_STATE, 3)
  F.check("warped into Burned Tower B1F",
    F.warpTo(0, 8, 6, 0, 1, 1, 0, 0, 0, BURNED_TOWER_B1F[1], BURNED_TOWER_B1F[2], "burned_tower"), where())
  local done = settle(4000)
  F.shot("after_release")
  F.check("the beast release scene ran to the end", done and varGet(VAR_ECRUTEAK_CITY_STATE) == 4,
    string.format("state=%d control=%s", varGet(VAR_ECRUTEAK_CITY_STATE), tostring(hasControl())))
  local by, list = roaming()
  local l2 = slotOf(SPECIES_LATIAS) and slot(slotOf(SPECIES_LATIAS))
  F.check("the roaming Latias survived the release untouched",
    l2 ~= nil and l2.personality == latiBefore.personality, list)
  F.check("Entei took the free slot", by[SPECIES_ENTEI] == 1, list)
  F.check("Raikou is parked, not roaming", by[SPECIES_RAIKOU] == nil, list)

  -- Map loads, the Hub and back: still exactly Latias and Entei.
  F.warpTo(1, 0, 0, 0, 0, 0, 0, 0, 0, 100, 0, "hub")
  F.warpTo(0, 9, 4, 0, 1, 6, 0, 0, 0, DARK_CAVE_SOUTH[1], DARK_CAVE_SOUTH[2], "dark_cave")
  by, list = roaming()
  F.check("after the Hub and back: Latias and Entei roam, nothing duplicated",
    by[SPECIES_LATIAS] == 1 and by[SPECIES_ENTEI] == 1 and noDuplicates(), list)
  local enteiSlot, enteiBefore = slotOf(SPECIES_ENTEI)

  -- Route 31 at the Dark Cave mouth, then south into the grass.
  local onRoute = F.warpTo(0, 7, 5, 0, 0, 4, 0, 0, 0, ROUTE31[1], ROUTE31[2], "route31")
  F.check("walked from the Dark Cave mouth into Route 31's grass", onRoute and F.route({{48,10},{48,14}}, "to_grass"), where())
  if not onRoute or not enteiSlot then F.finish(); return end
  F.w8(S.sRoamerLocation + enteiSlot * 2, ROUTE31[1])
  F.w8(S.sRoamerLocation + enteiSlot * 2 + 1, ROUTE31[2])

  local fought, won = false, false
  for _ = 1, 400 do
    if not F.ow() then
      local roamer, back = battle()
      if roamer then fought = true; won = back and not slot(enteiSlot).active; break end
      if not back then break end
    else
      local x = F.pos()
      F.step(x == 48 and "Left" or "Right")
    end
  end
  F.shot("after_entei")
  F.check("the roaming Entei was met in the grass and defeated", fought and won,
    string.format("fought=%s won=%s %s", tostring(fought), tostring(won), select(2, roaming())))

  -- A map load runs the parked-roamer release.
  local inside = F.warpTo(0, 9, 4, 0, 1, 6, 0, 0, 0, DARK_CAVE_SOUTH[1], DARK_CAVE_SOUTH[2], "dark_cave2")
  by, list = roaming()
  local e = slotOf(SPECIES_ENTEI) and slot(slotOf(SPECIES_ENTEI))
  F.check("the next map load released the parked Raikou", inside and by[SPECIES_RAIKOU] == 1, list)
  F.check("the defeated Entei did not come straight back", by[SPECIES_ENTEI] == nil,
    string.format("%s entei pid %08X -> %s", list, enteiBefore.personality, e and string.format("%08X", e.personality) or "-"))
  F.check("Latias still roams, unchanged, and nothing is duplicated",
    by[SPECIES_LATIAS] == 1 and noDuplicates() and slot(slotOf(SPECIES_LATIAS)).personality == latiBefore.personality, list)

  -- More map loads change nothing.
  F.warpTo(0, 7, 5, 0, 0, 4, 0, 0, 0, ROUTE31[1], ROUTE31[2], "route31b")
  F.warpTo(1, 0, 0, 0, 0, 0, 0, 0, 0, 100, 0, "hub2")
  local by2, list2 = roaming()
  F.check("further map loads and the Hub change nothing", list2 == list and noDuplicates(), list2)
  F.finish()
end)
