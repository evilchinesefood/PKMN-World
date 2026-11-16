-- Southern Island's Lati and both Birth Islands' Deoxys (Hoenn's, and Kanto's reached by the
-- Seagallop) with an Egg as the whole party, on real input.
--
-- Both scripts refuse an empty or Egg-only party before the scene starts ("You don't have a single
-- POKéMON"). Each refusal must leave no battle, no legendary object, the map's own music and a free
-- field, and the scene must play once a real Pokemon joins the party on the same visit: the Lati
-- flies in and the battle starts, the Deoxys rock bursts and the battle starts. The Birth Island
-- puzzle is solved with real steps, rock by rock, within each rock's step limit. Each battle is
-- left with RUN, so the encounter flags are not spent.
--
-- Run via test/overworld/mgba-run.sh test/overworld/lua/EggOnlyIslandLegends.lua <rom>

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "EggOnlyIslandLegends")

local HUB = { 100, 0 }
local SOUTHERN_ISLAND_INTERIOR = { 26, 10 }
local BIRTH_ISLAND_EXTERIOR = { 26, 58 }
local BIRTH_ISLAND_EXTERIOR_FRLG = { 36, 56 }
local SPECIES_TOGEPI, SPECIES_MEWTWO = 175, 150
local SPECIES_LATIAS, SPECIES_LATIOS, SPECIES_DEOXYS = 380, 381, 386
local MOVE_PSYCHIC = 94
local FLAG_TEMP_2 = 0x2
local FLAG_ENCOUNTERED_LATIAS_OR_LATIOS = 0xCE
local FLAG_BATTLED_DEOXYS = 0x1AD
local FLAG_FOUGHT_DEOXYS = 0xA40 + 0x2E4
local FLAG_ENABLE_SHIP_SOUTHERN_ISLAND = 0x948 + 0x53
local FLAG_DEOXYS_ROCK_COMPLETE = 0x948 + 0x74
local VAR_DEOXYS_ROCK_LEVEL = 0x4035
local LOCALID_LATI, LOCALID_ROCK, LOCALID_DEOXYS = 2, 1, 2
local CONTEXT_RUNNING = 0

-- Rock positions by level (src/field_specials.c sDeoxysRockCoords) and, for each, the tile the
-- player talks from and the facing. Every leg is a shortest path inside the step limit.
local ROCK_TALK = {
  { 15, 13, "Up" },    -- level 0 rock at (15,12)
  { 12, 14, "Left" },  -- (11,14), 4 steps allowed
  { 15, 9, "Up" },     -- (15,8), 8
  { 19, 13, "Down" },  -- (19,14), 8
  { 13, 11, "Left" },  -- (12,11), 8
  { 17, 11, "Right" }, -- (18,11), 4
  { 15, 13, "Down" },  -- (15,14), 4
  { 12, 14, "Left" },  -- (11,14), 4
  { 18, 14, "Right" }, -- (19,14), 6
  { 15, 14, "Down" },  -- (15,15), 3
  { 15, 11, "Up" },    -- (15,10), 3
}

local function where() local x, y = F.pos(); return string.format("%d/%d (%d,%d)", F.grp(), F.mapn(), x, y) end
local function count() return F.r8(S.gPartiesCount) end
local function flagGet(id) return (F.r8(F.sb1() + S.SaveBlock1.flags + id // 8) >> (id % 8)) & 1 == 1 end
local function flagSet(id)
  local a = F.sb1() + S.SaveBlock1.flags + id // 8
  F.w8(a, F.r8(a) | (1 << (id % 8)))
end
local function varGet(id) return F.r16(F.sb1() + S.SaveBlock1.vars + (id - 0x4000) * 2) end
local function d(n) return (n // 100) % 10, (n // 10) % 10, n % 10 end
local function warp(g, m, w, tag)
  local gh, gt, go = d(g)
  local mh, mt, mo = d(m)
  local wh, wt, wo = d(w)
  return F.warpTo(gh, gt, go, mh, mt, mo, wh, wt, wo, g, m, tag)
end

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
local function giveEgg(species) local b = { 0x7A }; le16(b, species); b[#b + 1] = 0x02; runScript(b) end
local function createMon(species, level, moves)
  local b = { 0x23 }; le32(b, S.ScrCmd_createmon | 1)
  b[#b + 1] = 0; b[#b + 1] = 6
  le16(b, species); le16(b, level)
  le32(b, (1 << 17) | (1 << 18) | (1 << 19) | (1 << 20))
  for k = 1, 4 do le16(b, moves[k] or 0) end
  b[#b + 1] = 0x02
  runScript(b)
  return count()
end

local function hasControl()
  return F.ow() and F.r8(S.sLockFieldControls) == 0 and F.r8(S.sGlobalScriptContextStatus) ~= CONTEXT_RUNNING
end
local function objByLocal(id)
  for i = 0, 15 do
    local o = S.gObjectEvents + i * S.ObjectEvent.stride
    if (F.r8(o) & 1) ~= 0 and F.r8(o + 8) == id then return o end
  end
end
local function visible(id)
  local o = objByLocal(id)
  return o ~= nil and (F.r8(o + 1) >> 5) & 1 == 0
end
local function playingSong()
  local hdr = F.r32(S.gMPlayInfo_BGM)
  if hdr == 0 then return 0 end
  for id = 0, 900 do
    if F.r32(S.gSongTable + id * 8) == hdr then return id end
  end
  return -1
end
local function headerMusic() return F.r16(S.gMapHeader + 0x10) end

local function walkTo(tx, ty, tag)
  for _ = 1, 60 do
    local x, y = F.pos()
    if x == tx and y == ty then return true end
    local dir
    if x < tx then dir = "Right" elseif x > tx then dir = "Left"
    elseif y < ty then dir = "Down" else dir = "Up" end
    if not F.step(dir) then F.L("  walk " .. tag .. " blocked at " .. where()); F.shot(tag .. "_blocked"); return false end
  end
  return false
end

-- Talk, then press A through whatever follows: report a battle, the wild species and whether the
-- field came back.
local function talkAndWatch(tag)
  F.w16(S.gBattleMons + S.BattlePokemon.size, 0)   -- forget the previous battle's foe
  F.press("A", 3)
  local battle, species, freed = false, 0, false
  for i = 1, 1500 do
    if not F.ow() then battle = true; break end
    if i == 80 then F.shot(tag .. "_scene") end
    if i % 30 == 0 then F.press("A", 2) else F.idle(1) end
    if i > 240 and hasControl() then freed = true; break end
    if i % 300 == 0 and F.reportCrash(tag) then break end
  end
  if battle then
    for _ = 1, 900 do
      species = F.r16(S.gBattleMons + S.BattlePokemon.size)
      if F.battlers() > 0 and (species == SPECIES_DEOXYS or species == SPECIES_LATIAS or species == SPECIES_LATIOS)
        then break end
      F.idle(1)
    end
    F.shot(tag .. "_battle")
  end
  return battle, species, freed
end
local function flee(tag)
  for _ = 1, 400 do
    F.press("B", 2); F.idle(6)
    F.press("Right", 2); F.idle(4)
    F.press("Down", 2); F.idle(4)
    F.press("A", 2); F.idle(10)
    if F.ow() then break end
    if F.reportCrash(tag) then return false end
  end
  for _ = 1, 600 do if hasControl() then return true end; F.press("B", 2); F.idle(10) end
  return hasControl()
end

-- MUS_NONE maps (Birth Island) play nothing; the refusal must not start the encounter music there.
local function musicUnchanged(tag, before)
  local header = headerMusic()
  local quiet = header == 0xFFFF and before == 0
  F.check(tag .. ": the map's music still plays", playingSong() == before and (before == header or quiet),
    string.format("song=%d before=%d header=%d", playingSong(), before, header))
end

local function southernIsland(tag)
  local before = playingSong()
  F.check(tag .. ": stood under the Eon sign", walkTo(13, 12, tag), where())
  F.face("Up")
  local battle, _, freed = talkAndWatch(tag .. "_refused")
  F.check(tag .. ": no battle", not battle)
  F.check(tag .. ": the field comes back", freed)
  F.check(tag .. ": no Lati object", not visible(LOCALID_LATI))
  F.check(tag .. ": the scene is not marked seen", not flagGet(FLAG_TEMP_2)
    and not flagGet(FLAG_ENCOUNTERED_LATIAS_OR_LATIOS))
  musicUnchanged(tag, before)
  F.shot(tag .. "_after_refusal")
end

local function birthIslandPuzzle(tag)
  for level = 0, 10 do
    local t = ROCK_TALK[level + 1]
    if not walkTo(t[1], t[2], tag .. "_rock" .. level) then return false, level end
    F.face(t[3])
    if level < 10 then
      F.press("A", 3)
      for _ = 1, 300 do if hasControl() and varGet(VAR_DEOXYS_ROCK_LEVEL) == level + 1 then break end; F.idle(1) end
      if varGet(VAR_DEOXYS_ROCK_LEVEL) ~= level + 1 then
        F.shot(tag .. "_rock" .. level .. "_failed")
        return false, level
      end
      for _ = 1, 120 do if hasControl() then break end; F.idle(1) end
    end
  end
  return true, 10
end

local function eggOnly(tag)
  F.dbg(); F.sel(2); F.sel(8); F.bOut(4)   -- Party > Clear Party
  giveEgg(SPECIES_TOGEPI)
  F.check(tag .. ": the party is one Egg", count() == 1, "n=" .. count())
end

local function birthIsland(tag, map, battledFlag)
  eggOnly(tag)
  F.check(tag .. ": warped to Birth Island", warp(map[1], map[2], 0, tag), where())
  F.idle(60)
  local before = playingSong()
  local solved, level = birthIslandPuzzle(tag)
  F.check(tag .. ": the rock reached its last tile with real steps", solved, "level=" .. level)
  if not solved then return end
  local battle, _, freed = talkAndWatch(tag .. "_refused")
  F.check(tag .. ": no battle", not battle)
  F.check(tag .. ": the field comes back", freed)
  F.check(tag .. ": no Deoxys object", not visible(LOCALID_DEOXYS))
  F.check(tag .. ": the rock is still there", visible(LOCALID_ROCK))
  F.check(tag .. ": Deoxys is not marked battled", not flagGet(battledFlag))
  musicUnchanged(tag, before)
  F.shot(tag .. "_after_refusal")

  -- A real Pokemon joins on the same visit (as when the Egg hatches here): the rock must answer.
  F.check(tag .. ": a real Pokemon joins", createMon(SPECIES_MEWTWO, 100, { MOVE_PSYCHIC }) == 2)
  F.face("Up")
  local b2, sp2 = talkAndWatch(tag .. "_replay")
  F.check(tag .. ": the Deoxys battle starts once a Pokemon can fight", b2 and sp2 == SPECIES_DEOXYS,
    string.format("battle=%s species=%d rockComplete=%s", tostring(b2), sp2, tostring(flagGet(FLAG_DEOXYS_ROCK_COMPLETE))))
  if b2 then F.check(tag .. ": RUN leaves the battle", flee(tag .. "_flee")) end
end

F.run(function()
  if not F.boot(HUB[1]) then F.check("boot", false); F.finish(); return end
  flagSet(FLAG_ENABLE_SHIP_SOUTHERN_ISLAND)

  -- Kanto's Birth Island first: its map script does not reset the rock's level (a separate
  -- defect), so it must see the puzzle fresh; Hoenn's own reset then covers the second run.
  birthIsland("kanto_birth", BIRTH_ISLAND_EXTERIOR_FRLG, FLAG_FOUGHT_DEOXYS)
  birthIsland("hoenn_birth", BIRTH_ISLAND_EXTERIOR, FLAG_BATTLED_DEOXYS)

  eggOnly("southern")
  F.check("southern: warped into Southern Island", warp(SOUTHERN_ISLAND_INTERIOR[1], SOUTHERN_ISLAND_INTERIOR[2], 0,
    "southern"), where())
  F.idle(60)
  southernIsland("southern")
  F.check("southern: a real Pokemon joins", createMon(SPECIES_MEWTWO, 100, { MOVE_PSYCHIC }) == 2)
  F.face("Up")
  local b3, sp3 = talkAndWatch("southern_replay")
  F.check("southern: the Lati battle starts once a Pokemon can fight", b3 and (sp3 == SPECIES_LATIAS or sp3 == SPECIES_LATIOS),
    string.format("battle=%s species=%d", tostring(b3), sp3))
  if b3 then F.check("southern: RUN leaves the battle", flee("southern_flee")) end
  F.finish()
end)
