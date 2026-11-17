-- Cut clears tall and long grass in Kanto and Johto, as it does in Hoenn.
--
-- SetCutGrassMetatile (src/fldeff_cut.c) cuts a grass metatile only when sCutGrassMetatiles has a
-- rule keyed on the tileset that holds it. Kanto's and Johto's grass had none (the rows generated
-- into src/data/field_effects/cut_grass_metatiles.h by test/overworld/ValidateCutGrass.py), so CUT
-- played its animation and left the grass standing. Kanto's and Johto's plain tall grass (primary
-- id 0x00D) was cut only because Hoenn's primary rule matched the same number.
--
-- Each case warps the player beside grass, teaches the lead Pokemon CUT and uses it from the Start
-- menu's party screen with real input. Every metatile in the 3x3 around the player must become the
-- literal tile its case names (the stubble on the ground under that grass in its own tileset, see
-- test/overworld/lua/CutGrassStubble.lua), and nothing else in
-- the surrounding 5x5 may change. Leaving and re-entering the map must bring the grass back, as it
-- does in Hoenn (Cut writes only the map grid copy).
--   * Kanto: Viridian Forest (ViridianForest tree-top grass), Route 13 (General_FrlgNight tree tops);
--   * Johto: Route 29 (Johto_General grass under tree tops), Route 33 (Johto_South), National Park
--     (long grass and its south edge), Route 39 (the wheat field, cut to straw stubble);
--   * Route 101 (control): Hoenn's grass.
--
-- Run via test/overworld/mgba-run.sh test/overworld/lua/CutGrassKantoJohto.lua

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "CutGrassKantoJohto")

local HUB_GROUP = 100
local CONTEXT_RUNNING = 0
local SPECIES_MARSHTOMP = 259
local MOVE_CUT, ITEM_CUT_TOOL = 15, 875
local SCR_OP_ADDITEM, SCR_OP_SETMONMOVE, SCR_OP_END = 0x44, 0x7B, 0x02
local SCRIPT_BUF = S.gStringVar4 + 960
local SP = S.Sprite

-- { tag, grp, map, x, y, { grass metatile = metatile Cut leaves } }
local CASES = {
  { "viridian_forest", 35, 0, 35, 18, { [0x284] = 0x297, [0x00D] = 0x228 } },
  { "route13", 37, 31, 57, 7, { [0x00B] = 0x02E, [0x00C] = 0x20B, [0x00D] = 0x228 } },
  { "route29", 75, 2, 51, 14, { [0x00B] = 0x27F, [0x00C] = 0x27E, [0x00D] = 0x27D } },
  { "route33", 80, 1, 18, 28, { [0x00B] = 0x27F, [0x00C] = 0x27E, [0x00D] = 0x27D } },
  { "national_park", 83, 4, 30, 15, { [0x287] = 0x2D7, [0x28F] = 0x2E1, [0x297] = 0x2E8, [0x2DF] = 0x2E9 } },
  { "route39_wheat", 85, 2, 2, 5, { [0x301] = 0x3C1, [0x302] = 0x3C2, [0x303] = 0x3C8, [0x309] = 0x3CA, [0x30A] = 0x3CB, [0x30B] = 0x3CC } },
  { "route101_control", 0, 16, 15, 14, { [0x00D] = 0x02A, [0x1C6] = 0x13F, [0x1C7] = 0x1A2 } },
}

local function d(n) return (n // 100) % 10, (n // 10) % 10, n % 10 end

local function giveMon(species)
  local v = species - 1
  F.dbg(); F.sel(3); F.sel(1); F.idle(20)
  F.spin(v // 100, (v // 10) % 10, v % 10); F.idle(20); F.spin(0, 0, 5); F.idle(60); F.bOut(4)
end

local function runScript(bytes)
  for i, b in ipairs(bytes) do F.w8(SCRIPT_BUF + i - 1, b) end
  F.w8(S.sGlobalScriptContext, 0)
  F.w8(S.sGlobalScriptContext + 1, 1)
  F.w32(S.sGlobalScriptContext + 4, 0)
  F.w32(S.sGlobalScriptContext + S.ScriptCtx.scriptPtr, SCRIPT_BUF)
  F.w8(S.sGlobalScriptContextStatus, CONTEXT_RUNNING)
  F.idle(30)
end

local function warpToCoords(grp, map, x, y, tag)
  for _ = 1, 4 do
    F.dbg(); F.sel(0); F.sel(1); F.idle(20)
    F.spin(d(grp)); F.spin(d(map))
    F.press("A", 2)
    for _ = 1, 400 do
      F.w8(S.sWarpDestination + 2, 0xFF)
      F.w16(S.sWarpDestination + 4, x)
      F.w16(S.sWarpDestination + 6, y)
      F.idle(1)
      local px, py = F.pos()
      if F.ow() and F.grp() == grp and F.mapn() == map and px == x and py == y then F.idle(90); return true end
    end
    F.bOut(5)
  end
  F.shot(tag .. "_warpfail")
  return false
end

local function metatileAt(x, y)
  local width = F.r32(S.gBackupMapLayout + S.BackupMapLayout.width)
  local map = F.r32(S.gBackupMapLayout + S.BackupMapLayout.map)
  local o = S.BackupMapLayout.mapOffset
  return (F.r16(map + ((x + o) + (y + o) * width) * 2) >> S.Metatiles.idShift) & S.Metatiles.idMask
end

local function area(cx, cy)
  local t = {}
  for dy = -2, 2 do for dx = -2, 2 do t[#t + 1] = metatileAt(cx + dx, cy + dy) end end
  return t
end

local function clippings()
  local n = 0
  for i = 0, SP.count - 1 do
    local s = S.gSprites + i * SP.stride
    if (F.r16(s + SP.inUse) & 1) == 1 and F.r32(s + SP.template) == S.sSpriteTemplate_CutGrass then n = n + 1 end
  end
  return n
end

local function useCut(tag)
  F.press("Start", 2); F.idle(60)
  if not F.check(tag .. ": the Start menu offers the party", F.selectStartIcon(1)) then return end
  F.press("A", 2)
  for _ = 1, 300 do F.idle(1); if F.cb2() == (S.CB2_UpdatePartyMenu & ~1) then break end end
  F.idle(60)
  F.press("A", 2); F.idle(40)
  F.shot(tag .. "_cut_offered")
  F.press("Down", 2); F.idle(20); F.press("A", 2)
end

local function waitControl()
  for _ = 1, 600 do
    F.idle(1)
    if F.ow() and F.r8(S.sLockFieldControls) == 0 and F.r8(S.sGlobalScriptContextStatus) ~= CONTEXT_RUNNING then return true end
  end
  return false
end

local function run(c)
  local tag, grp, map, x, y, cuts = table.unpack(c)
  if not F.check(tag .. ": arrives", warpToCoords(grp, map, x, y, tag)) then return end
  F.idle(30)
  local before = area(x, y)
  F.shot(tag .. "_before")
  useCut(tag)
  local thrown = 0
  for _ = 1, 900 do
    F.idle(1)
    thrown = clippings()
    if thrown > 0 then break end
  end
  F.check(tag .. ": Cut throws grass clippings", thrown > 0)
  waitControl()
  F.idle(30)
  F.shot(tag .. "_after")
  local after = area(x, y)
  F.L(tag .. ": before " .. table.concat(before, " "))
  F.L(tag .. ": after  " .. table.concat(after, " "))
  local inner, outer, grassInReach = {}, {}, 0
  for i = 1, 25 do
    local dx, dy = (i - 1) % 5 - 2, (i - 1) // 5 - 2
    local reach = math.abs(dx) <= 1 and math.abs(dy) <= 1
    local want = reach and cuts[before[i]] or before[i]
    if reach and cuts[before[i]] then grassInReach = grassInReach + 1 end
    if after[i] ~= want then
      local list = reach and inner or outer
      list[#list + 1] = string.format("(%d,%d) %#x->%#x want %#x", x + dx, y + dy, before[i], after[i], want)
    end
  end
  F.check(tag .. ": grass stands in Cut's reach", grassInReach >= 3, "grass tiles " .. grassInReach)
  F.check(tag .. ": every grass tile in reach becomes its stubble", #inner == 0, table.concat(inner, "; "))
  F.check(tag .. ": nothing outside Cut's reach changes", #outer == 0, table.concat(outer, "; "))
  F.check(tag .. ": control returns to the field", F.ow() and F.r8(S.sLockFieldControls) == 0)
  if not warpToCoords(grp, map, x, y, tag .. "_reload") then return end
  local reloaded, back = area(x, y), true
  for i = 1, 25 do back = back and reloaded[i] == before[i] end
  F.check(tag .. ": the grass grows back when the map reloads", back, table.concat(reloaded, " "))
end

F.run(function()
  if not F.boot(HUB_GROUP) then F.check("boot", false); F.finish(); return end
  giveMon(SPECIES_MARSHTOMP)
  F.check("a Pokemon in the party", F.r8(S.gPartiesCount) >= 1, "n=" .. F.r8(S.gPartiesCount))
  runScript({ SCR_OP_SETMONMOVE, 0, 0, MOVE_CUT & 0xFF, MOVE_CUT >> 8, SCR_OP_ADDITEM, ITEM_CUT_TOOL & 0xFF, ITEM_CUT_TOOL >> 8, 1, 0, SCR_OP_END })
  local only = os.getenv("CUT_CASE")
  for _, c in ipairs(CASES) do
    if not only or c[1]:find(only, 1, true) then run(c) end
  end
  F.finish()
end)
