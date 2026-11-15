-- Johto Headbutt trees. The Ilex Forest tutor ("Rattle trees with HEADBUTT") and the Route 39 sign
-- promise trees that shake out Pokemon, and 35 Johto maps carry pokemonHnS's Headbutt tables as
-- rock_smash_mons with no breakable rock on the map. In HnS a tree metatile has behaviour 0xA1,
-- MB_HEADBUTT_TREE, and A in front of it runs EventScript_Headbutt. This tree read 0xA1 with its
-- own numbering, MB_INDIGO_PLATEAU_SIGN_1, which answers only in Kanto, so A did nothing.
--
-- Azalea Town is the bed: its only wild table is the Headbutt one (rate 60), it has no grass, and
-- the single-tile tree at (28,12) is faced from (28,13). The suite walks there with real input:
--   * control: A at the wall west of (28,13) runs no script;
--   * a Magikarp, which can never learn Headbutt, refuses with and without FLAG_GET_HEADBUTT
--     (Bugsy's win and the Ilex tutor set it): "small tree", no battle;
--   * a Pidgey that can be taught Headbutt but does not know it: refused without the flag; with
--     it, "Pidgey used Headbutt!" and, within 30 tries, a wild battle against a species from
--     Azalea's table. HnS lets a Pokemon the tutor could teach shake trees.
--
-- Run via test/overworld/mgba-run.sh test/overworld/lua/JohtoHeadbuttTrees.lua

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "JohtoHeadbuttTrees")

local GRP_HUB, MAP_HUB = 100, 0
local GRP_AZALEA, MAP_AZALEA_TOWN = 80, 0

local FLAG_JOHTO_BASE = 0x6000
local FLAG_GET_HEADBUTT = FLAG_JOHTO_BASE + 0x8A

local SPECIES_PIDGEY, SPECIES_MAGIKARP = 16, 129
local MOVE_HEADBUTT = 29
local AZALEA_HEADBUTT = { [204] = "PINECO", [167] = "SPINARAK", [214] = "HERACROSS", [190] = "AIPOM" }

local TREE, STAND = { 28, 12 }, { 28, 13 }
local TREE_METATILE = 0x005
local MAP_OFFSET = 7

local function johtoFlagSet(id, on)
  local a, m = F.sb3() + S.SaveBlock3.johtoFlags + ((id - FLAG_JOHTO_BASE) // 8), 1 << (id % 8)
  local v = F.r8(a)
  F.w8(a, on and (v | m) or (v & ~m & 0xFF))
end

local function where()
  local x, y = F.pos()
  return string.format("grp=%d map=%d pos=(%d,%d)", F.grp(), F.mapn(), x, y)
end

local function scriptPtr()
  return F.r32(S.sGlobalScriptContext + S.ScriptCtx.scriptPtr)
end

local function blockAt(x, y)
  local w = F.r32(S.gBackupMapLayout + S.BackupMapLayout.width)
  local map = F.r32(S.gBackupMapLayout + S.BackupMapLayout.map)
  return F.r16(map + ((x + MAP_OFFSET) + (y + MAP_OFFSET) * w) * 2)
end

local function behaviorAt(x, y)
  local id = blockAt(x, y) & S.Metatiles.idMask
  local layout = F.r32(S.gMapHeader + S.MapHeader.mapLayout)
  local tileset, localId = F.r32(layout + S.MapLayout.primaryTileset), id
  if id >= S.Metatiles.inPrimaryFrlg then
    tileset, localId = F.r32(layout + S.MapLayout.secondaryTileset), id - S.Metatiles.inPrimaryFrlg
  end
  return F.r16(F.r32(tileset + S.Tileset.metatileAttributes) + localId * 2) & S.Metatiles.behaviorMask
end

local GLYPH = { [0x00] = " ", [0xAB] = "!", [0xAC] = "?", [0xAD] = ".", [0xB4] = "'", [0xB8] = ",",
                [0x1B] = "e", [0xFA] = " ", [0xFB] = " ", [0xFE] = " " }
for i = 0, 25 do GLYPH[0xBB + i] = string.char(65 + i); GLYPH[0xD5 + i] = string.char(97 + i) end
for i = 0, 9 do GLYPH[0xA1 + i] = string.char(48 + i) end
local function message()
  local out = {}
  for i = 0, 200 do
    local c = F.r8(S.gStringVar4 + i)
    if c == 0xFF then break end
    out[#out + 1] = GLYPH[c] or "?"
  end
  return table.concat(out)
end

local function order(p)
  local o = {}
  for i = 0, 3 do o[i] = F.r8(S.sSubstructOffsets + i * 24 + p % 24) * 3 end
  return o
end
local function partyMon(slot)
  local a = S.gParties + slot * S.Pokemon.size
  local key = F.r32(a) ~ F.r32(a + 4)
  local w = {}
  for i = 0, 11 do w[i] = F.r32(a + 32 + i * 4) ~ key end
  local o = order(F.r32(a))
  local s1 = o[1]
  return {
    species = w[o[0]] & 0x7FF,
    moves = { w[s1] & 0x7FF, (w[s1] >> 16) & 0x7FF, w[s1 + 1] & 0x7FF, (w[s1 + 1] >> 16) & 0x7FF },
  }
end
local function knows(mon, move)
  for _, m in ipairs(mon.moves) do if m == move then return true end end
  return false
end

local function givePokemon(sh, st, so, lh, lt, lo)
  F.dbg(); F.idle(60)
  for _ = 1, 3 do F.press("Down", 3); F.idle(16) end
  F.press("A", 3); F.idle(60)
  F.press("Down", 3); F.idle(16)
  F.press("A", 3); F.idle(60)
  F.spin(sh, st, so)
  F.spin(lh, lt, lo)
  F.idle(90)
  F.bOut(4); F.idle(60)
end

local function toAzalea(tag)
  local ok = F.warpTo(0, 8, 0, 0, 0, 0, 0, 0, 3, GRP_AZALEA, MAP_AZALEA_TOWN, tag)
  F.idle(120)
  return ok
end

local function toTree(tag)
  for _ = 1, 4 do
    if F.route({ { 31, 16 }, { STAND[1], 16 }, STAND }, tag) then
      F.face("Up")
      return true
    end
    F.idle(60)
  end
  return false
end

-- Press A once at the faced tile and follow the script it starts to its end.
-- Returns whether a script ran, every message it showed, and whether a battle began.
local function pressAt(tag, shotName)
  local ran, texts, seen, battle, firstText = false, {}, {}, false, nil
  F.w8(S.gStringVar4, 0xFF)
  F.press("A", 2)
  for f = 1, 900 do
    F.idle(1)
    if not F.ow() then battle = true; break end
    if scriptPtr() ~= 0 then ran = true end
    local m = message()
    if ran and m ~= "" and not seen[m] then seen[m] = true; texts[#texts + 1] = m; firstText = firstText or f end
    if shotName and firstText and f == firstText + 150 then F.shot(shotName); shotName = nil end
    if ran and not shotName and f % 24 == 0 then F.press("B", 2) end
    if f > 60 and scriptPtr() == 0 then break end
  end
  if F.reportCrash(tag) then return ran, texts, battle, true end
  return ran, texts, battle, false
end

local function said(texts, needle)
  for _, t in ipairs(texts) do if t:find(needle, 1, true) then return true end end
  return false
end

F.run(function()
  if not F.boot(GRP_HUB) then F.check("boot", false); F.finish(); return end

  givePokemon(1, 2, 8, 0, 0, 4)
  local lead = partyMon(0)
  F.check("party lead is a Magikarp without Headbutt",
    F.r8(S.gPartiesCount) == 1 and lead.species == SPECIES_MAGIKARP and not knows(lead, MOVE_HEADBUTT),
    string.format("count=%d species=%d moves=%d,%d,%d,%d", F.r8(S.gPartiesCount), lead.species,
      lead.moves[1], lead.moves[2], lead.moves[3], lead.moves[4]))

  F.check("warp to Azalea Town", toAzalea("azalea1"), where())
  F.check("walk to the tree's south tile (28,13) with real input", toTree("tree1"), where())
  F.check("the faced tile is Azalea's small tree, metatile 0x005",
    (blockAt(TREE[1], TREE[2]) & 0x3FF) == TREE_METATILE,
    string.format("metatile=0x%03X", blockAt(TREE[1], TREE[2]) & 0x3FF))
  F.L(string.format("  behaviour byte at the tree: 0x%02X", behaviorAt(TREE[1], TREE[2])))
  F.shot("at_tree")

  F.face("Left")
  local ranWall = pressAt("wall")
  F.check("control: A at the wall west of the tree runs no script", not ranWall, where())
  F.face("Up")

  local ran, texts, battle = pressAt("noflag", "no_flag_message")
  F.check("no FLAG_GET_HEADBUTT: A at the tree opens a message", ran, table.concat(texts, " / "))
  F.check("no FLAG_GET_HEADBUTT: it is the small-tree refusal", said(texts, "small tree"),
    table.concat(texts, " / "))
  F.check("no FLAG_GET_HEADBUTT: no battle starts", not battle and F.ow(), where())

  johtoFlagSet(FLAG_GET_HEADBUTT, true)
  ran, texts, battle = pressAt("nomove")
  F.check("flag but only a Magikarp: the small-tree refusal again",
    ran and said(texts, "small tree") and not said(texts, "used Headbutt!"), table.concat(texts, " / "))
  F.check("flag but only a Magikarp: no battle starts", not battle and F.ow(), where())

  F.check("warp back to the hub", F.warpTo(1, 0, 0, 0, 0, 0, 0, 0, 0, GRP_HUB, MAP_HUB, "hub"), where())
  givePokemon(0, 1, 5, 0, 0, 4)
  local pidgey = partyMon(1)
  F.check("party gains a Pidgey that does not know Headbutt",
    F.r8(S.gPartiesCount) == 2 and pidgey.species == SPECIES_PIDGEY and not knows(pidgey, MOVE_HEADBUTT),
    string.format("count=%d species=%d moves=%d,%d,%d,%d", F.r8(S.gPartiesCount), pidgey.species,
      pidgey.moves[1], pidgey.moves[2], pidgey.moves[3], pidgey.moves[4]))

  F.check("warp to Azalea Town again", toAzalea("azalea2"), where())
  F.check("walk back to (28,13)", toTree("tree2"), where())

  johtoFlagSet(FLAG_GET_HEADBUTT, false)
  ran, texts, battle = pressAt("pidgey_noflag")
  F.check("Pidgey but no FLAG_GET_HEADBUTT: the small-tree refusal",
    ran and said(texts, "small tree") and not said(texts, "used Headbutt!"), table.concat(texts, " / "))
  johtoFlagSet(FLAG_GET_HEADBUTT, true)

  local usedHeadbutt, tries, started, heard = false, 0, false, ""
  for i = 1, 30 do
    tries = i
    ran, texts, battle = pressAt("headbutt" .. i, i == 1 and "used_headbutt" or nil)
    heard = table.concat(texts, " / ")
    if said(texts, "Pidgey used Headbutt!") then usedHeadbutt = true end
    if battle then started = true; break end
    if not ran then break end
  end
  F.check("the tree says Pidgey used Headbutt!", usedHeadbutt, "tries=" .. tries .. " last: " .. heard)
  F.check("a wild battle starts within 30 Headbutts", started, "tries=" .. tries .. " " .. where())

  local foe = 0
  if started then
    for _ = 1, 600 do
      if F.battlers() > 0 then break end
      F.idle(1)
    end
    F.idle(120)
    foe = F.r16(S.gBattleMons + S.BattlePokemon.size)
    F.shot("battle")
  end
  F.check("the wild Pokemon is from Azalea's Headbutt table", AZALEA_HEADBUTT[foe] ~= nil,
    string.format("species=%d %s", foe, tostring(AZALEA_HEADBUTT[foe])))

  F.finish()
end)
