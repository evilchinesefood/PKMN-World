-- Secret Power on each Hoenn entrance type and moving the base twice, with every decoration owned.
--
-- With real input the suite makes a base in the Route 116 blue cave, opens its PC and the Decorate
-- category list (all 120 decorations given first, each through an adddecoration script), leaves, then
-- uses Secret Power on the Route 110 tree and the Route 119 shrub. Each move must name the route of
-- the base being left, land in the right base map in front of its PC, and close the old entrance
-- again: the Route 116 indent (open while the base is there) and the Route 110 vines are read back
-- from the live map grid.
-- Setup is the debug party (Secret Power written into its last move slot by setmonmove), the
-- decorations and the debug warps; every talk, YES and menu choice is real input.
local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "SecretBaseMoveStress")

local HUB = 100
local REGION_HOENN = 3
local MOVE_SECRET_POWER = 290
local DECORATION_IDS = 120
local SECRET_BASE_GROUP = 25
local CONTEXT_RUNNING, CONTEXT_SHUTDOWN = 0, 2
local METATILE_BLUE_CAVE_INDENT, METATILE_BLUE_CAVE_OPEN = 0x1B0, 0x1B1
local METATILE_TREE_LEFT, METATILE_VINE_LEFT = 0x026, 0x036

local SPOTS = {
  { tag = "cave", group = 0, map = 31, x = 71, y = 5, base = 2, bx = 1, by = 3,
    found = "DISCOVERED A SMALL CAVERN" },
  { tag = "tree", group = 0, map = 25, x = 16, y = 26, base = 16, bx = 15, by = 3,
    found = "A THICK VINE DROPPED DOWN", leaving = "NEAR ROUTE 116" },
  { tag = "shrub", group = 0, map = 34, x = 34, y = 25, base = 17, bx = 7, by = 8,
    found = "DISCOVERED A SMALL ENTRANCE", leaving = "NEAR ROUTE 110" },
}

local function d(n) return (n // 100) % 10, (n // 10) % 10, n % 10 end
local function where() local x, y = F.pos(); return string.format("%d/%d (%d,%d)", F.grp(), F.mapn(), x, y) end

local function hasControl()
  return F.ow() and F.r8(S.sLockFieldControls) == 0 and F.r8(S.sGlobalScriptContextStatus) == CONTEXT_SHUTDOWN
end

local SCRIPT_BUF = S.gStringVar4 + 960
local function runScript(bytes)
  for i, b in ipairs(bytes) do F.w8(SCRIPT_BUF + i - 1, b) end
  F.w8(S.sGlobalScriptContext, 0)
  F.w8(S.sGlobalScriptContext + 1, 1)
  F.w32(S.sGlobalScriptContext + 4, 0)
  F.w32(S.sGlobalScriptContext + S.ScriptCtx.scriptPtr, SCRIPT_BUF)
  F.w8(S.sGlobalScriptContextStatus, CONTEXT_RUNNING)
  for _ = 1, 200 do F.idle(2); if hasControl() then break end end
  F.idle(4)
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
      if F.ow() and F.grp() == grp and F.mapn() == map and px == x and py == y then
        F.idle(120)
        return true
      end
    end
    F.bOut(5)
  end
  F.shot(tag .. "_warpfail")
  return false
end

local function metatileAt(x, y)
  local L = S.gBackupMapLayout
  local w = F.r32(L + S.BackupMapLayout.width)
  return F.r16(F.r32(L + S.BackupMapLayout.map) + 2 * ((x + 7) + (y + 7) * w)) & 0x3FF
end

-- gStringVar4 as uppercase ASCII; Gen 3 A = 0xBB, a = 0xD5.
local function message()
  local s = {}
  for i = 0, 300 do
    local c = F.r8(S.gStringVar4 + i)
    if c == 0xFF then break end
    if c >= 0xBB and c <= 0xD4 then s[#s + 1] = string.char(65 + c - 0xBB)
    elseif c >= 0xD5 and c <= 0xEE then s[#s + 1] = string.char(65 + c - 0xD5)
    elseif c >= 0xA1 and c <= 0xAA then s[#s + 1] = string.char(48 + c - 0xA1)
    else s[#s + 1] = " " end
  end
  return (table.concat(s):gsub("%s+", " "))
end

local function scriptMenuUp()
  for i = 0, S.Task.count - 1 do
    local a = S.gTasks + i * S.Task.stride
    local fn = F.r32(a + S.Task.func) & 0xFFFFFFFE
    if F.r8(a + S.Task.isActive) ~= 0 and (fn == S.Task_HandleYesNoInput or fn == S.Task_HandleMultichoiceInput) then return true end
  end
  return false
end

-- Talk, answer YES to every prompt, and read each message until the script lets go.
local function talkYes(tag)
  F.press("A", 2); F.idle(30)
  local seen = {}
  for _ = 1, 400 do
    if F.reportCrash(tag) then break end
    local m = message()
    if seen[#seen] ~= m then seen[#seen + 1] = m end
    if scriptMenuUp() then
      F.idle(16)
      for _ = 1, 4 do if F.mcur() == 0 then break end; F.press("Up", 2); F.idle(10) end
      F.press("A", 2); F.idle(30)
    elseif hasControl() then
      F.idle(20); if hasControl() then break end
    else
      F.press("A", 2); F.idle(14)
    end
  end
  return table.concat(seen, " | ")
end

F.run(function()
  if not F.boot(HUB) then F.check("boot", false); F.finish(); return end
  F.dbg(); F.sel(2); F.sel(9); F.idle(120); F.bOut(3)    -- Party > Set Party: the debug Wobbuffet
  F.w8(F.sb2() + S.SaveBlock2.currentRegion, REGION_HOENN)
  F.w32(S.gCurrentRegion, REGION_HOENN)
  runScript({ 0x7B, 0, 3, MOVE_SECRET_POWER & 0xFF, MOVE_SECRET_POWER >> 8, 0x02 })   -- setmonmove 0, 3
  for id = 1, DECORATION_IDS do runScript({ 0x4B, id & 0xFF, id >> 8, 0x02 }) end       -- adddecoration

  for i, sp in ipairs(SPOTS) do
    if not F.check(sp.tag .. ": reach the entrance", warpToCoords(sp.group, sp.map, sp.x, sp.y, sp.tag)) then break end
    F.face("Up")
    F.shot(sp.tag .. "_entrance")
    local text = talkYes(sp.tag)
    F.L("  " .. sp.tag .. ": " .. text)
    F.idle(60)
    F.shot(sp.tag .. "_inside")
    local x, y = F.pos()
    F.check(sp.tag .. ": Secret Power opens it", text:find(sp.found) ~= nil, text)
    if sp.leaving then
      F.check(sp.tag .. ": the move names the base being left", text:find(sp.leaving) ~= nil, text)
    end
    F.check(sp.tag .. ": land in the new base in front of its PC",
      F.grp() == SECRET_BASE_GROUP and F.mapn() == sp.base and x == sp.bx and y == sp.by, where())

    if i == 1 then
      -- PC > Decoration > Decorate shows the category list; back out without placing anything.
      F.face("Up")
      F.press("A", 2)
      for _ = 1, 60 do if scriptMenuUp() then break end; F.press("A", 2); F.idle(30) end
      F.idle(30)
      F.shot("pc_menu")
      F.check("cave: the base PC offers its menu", scriptMenuUp(), message())
      F.press("A", 2); F.idle(60)
      F.press("A", 2); F.idle(60)
      F.shot("decorate_categories")
      for _ = 1, 12 do F.press("B", 2); F.idle(30); if hasControl() then break end end
      F.check("cave: control returns after backing out of the PC", hasControl(), where())
    end
    if not F.check(sp.tag .. ": leave the base", warpToCoords(0, 9, 10, 10, sp.tag .. "_out")) then break end
    if i == 1 and F.check("cave: back outside the new base", warpToCoords(sp.group, sp.map, sp.x, sp.y, "cave_open")) then
      F.check("cave: the occupied indent draws open", metatileAt(71, 4) == METATILE_BLUE_CAVE_OPEN,
        string.format("metatile=0x%03X", metatileAt(71, 4)))
    end
  end

  if F.check("back at the Route 116 cave", warpToCoords(0, 31, 71, 5, "cave_again")) then
    F.check("the Route 116 indent is closed again", metatileAt(71, 4) == METATILE_BLUE_CAVE_INDENT,
      string.format("metatile=0x%03X (indent 0x%03X, open 0x%03X)", metatileAt(71, 4), METATILE_BLUE_CAVE_INDENT, METATILE_BLUE_CAVE_OPEN))
  end
  if F.check("back at the Route 110 tree", warpToCoords(0, 25, 16, 26, "tree_again")) then
    F.check("the Route 110 vines are gone", metatileAt(16, 25) == METATILE_TREE_LEFT,
      string.format("metatile=0x%03X (tree 0x%03X, vine 0x%03X)", metatileAt(16, 25), METATILE_TREE_LEFT, METATILE_VINE_LEFT))
  end
  F.check("no crash", not F.crashScreen())
  F.finish()
end)
