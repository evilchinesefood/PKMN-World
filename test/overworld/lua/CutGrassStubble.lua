-- Cut leaves stubble on grass in every region, the stubble has no wild encounters, and the grass
-- grows back once the player leaves.
--
-- SetCutGrassMetatile (src/fldeff_cut.c) cuts each grass metatile to the stubble that
-- test/overworld/ValidateCutGrass.py generates: the ground under the grass with short stalks of that
-- grass left standing. Cut writes only the map grid copy (gBackupMapLayout), so:
--   * a battle on the same map keeps the stubble (the field returns without reloading the map, as in
--     vanilla Hoenn);
--   * a save and Continue keeps the stubble around the player (the save's map view snapshot, as in
--     vanilla Hoenn: the player never left);
--   * leaving the map and coming back grows the grass back (the map reloads from its layout);
--   * crossing a map seam carries the stubble still on screen into the next map's grid and back.
--
-- Each case warps the player beside grass, teaches the lead Pokemon CUT and uses it from the Start
-- menu's party screen with real input. Every grass metatile in the 3x3 around the player must become
-- the literal stubble its case names, and nothing else in the surrounding 5x5 may change (Route 120
-- also checks Fortree's long grass roots: the row under uncut long grass gets its roots back, and the
-- roots below the cut grass are cut too). The player then walks back and forth between a stubble tile
-- and uncut grass beside it: wild battles must start on the grass and never on the stubble. After the
-- first battle (fled with real input) the stubble must still be there, then again after a save and
-- Continue, and the grass must be back after a warp away and back.
--   * Hoenn: Route 101 (General tall grass), Route 120 (Fortree long grass and its roots);
--   * Kanto: Viridian Forest, Route 13 (General_FrlgNight tree tops);
--   * Johto: Route 29, National Park (long grass and its south edges), Route 39 (wheat, straw stubble
--     drawn on the top layer under sprites), Route 37 (the pink apricorn tree's grass), Mt. Silver
--     (frosty stubble);
--   * seam: Mt. Silver's outside grass beside Route 28, carried across the seam and back.
--
-- Run via test/overworld/mgba-run.sh test/overworld/lua/CutGrassStubble.lua
-- --env PW_CUT_CASE=<substring> runs only the matching cases.

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "CutGrassStubble")

local HUB_GROUP = 100
local CONTEXT_RUNNING = 0
local SPECIES_MARSHTOMP = 259
local MOVE_CUT, ITEM_CUT_TOOL = 15, 875
local SCR_OP_ADDITEM, SCR_OP_SETMONMOVE, SCR_OP_END = 0x44, 0x7B, 0x02
local SCRIPT_BUF = S.gStringVar4 + 960
local SP = S.Sprite
local BM_ABILITY, ABILITY_RUN_AWAY = 32, 50
local ACTION_RUN = 3
local USM_ICO_SAVE, SENTINEL = 7, 0xFFFF
local DIRS = { Up = { 0, -1 }, Down = { 0, 1 }, Left = { -1, 0 }, Right = { 1, 0 } }

-- { tag, grp, map, x, y, { grass = stubble }, { [x,y offset] = metatile the long grass roots leave } }
local CASES = {
  { "route101", 0, 16, 15, 14, { [0x00D] = 0x02A, [0x1C6] = 0x13F, [0x1C7] = 0x1A2 } },
  { "route120_long_grass", 0, 35, 25, 86, { [0x015] = 0x05C },
    { ["-1,-1"] = 0x208, ["0,-1"] = 0x208, ["1,-1"] = 0x208, ["-1,2"] = 0x2A9, ["0,2"] = 0x2A9, ["1,2"] = 0x2A9 } },
  { "viridian_forest", 35, 0, 35, 18, { [0x284] = 0x297, [0x00D] = 0x228 } },
  { "route13", 37, 31, 57, 7, { [0x00B] = 0x02E, [0x00C] = 0x20B, [0x00D] = 0x228 } },
  { "route29", 75, 2, 51, 14, { [0x00B] = 0x27F, [0x00C] = 0x27E, [0x00D] = 0x27D } },
  { "national_park", 83, 4, 30, 15, { [0x287] = 0x2D7, [0x28F] = 0x2E1, [0x297] = 0x2E8, [0x2DF] = 0x2E9 } },
  { "route39_wheat", 85, 2, 2, 5, { [0x301] = 0x3C1, [0x302] = 0x3C2, [0x303] = 0x3C8, [0x309] = 0x3CA, [0x30A] = 0x3CB, [0x30B] = 0x3CC } },
  { "route37_apricorn", 83, 3, 11, 17, { [0x00D] = 0x27D, [0x3F8] = 0x3C2, [0x3F9] = 0x3FC } },
  { "mt_silver_frosty", 97, 7, 18, 20, { [0x282] = 0x2C9, [0x37F] = 0x326 } },
}
local SEAMS = {
  { "seam_mt_silver_outside", 97, 0, 42, 16, { [0x00D] = 0x27E }, "Right" },
}
local AWAY = { HUB_GROUP, 0, 16, 4 }

local function d(n) return (n // 100) % 10, (n // 10) % 10, n % 10 end
local function inBattle() return F.cb2() == (S.BattleMainCB2 & ~1) end
local function ctrl(b) return F.r32(S.gBattlerControllerFuncs + b * 4) & ~1 end
local function isAction()
  for _, p in ipairs(S.ActionInputFunctions) do if ctrl(0) == (p & ~1) then return true end end
  return false
end
local function hasControl()
  return F.ow() and F.r8(S.sLockFieldControls) == 0 and F.r8(S.sGlobalScriptContextStatus) ~= CONTEXT_RUNNING
end

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

local function sameArea(a, b)
  for i = 1, 25 do if a[i] ~= b[i] then return false end end
  return true
end

local function clippings()
  local n = 0
  for i = 0, SP.count - 1 do
    local s = S.gSprites + i * SP.stride
    if (F.r16(s + SP.inUse) & 1) == 1 and F.r32(s + SP.template) == S.sSpriteTemplate_CutGrass then n = n + 1 end
  end
  return n
end

local function waitControl()
  for _ = 1, 600 do
    F.idle(1)
    if hasControl() then return true end
  end
  return false
end

local function useCut(tag)
  F.press("Start", 2); F.idle(60)
  if not F.check(tag .. ": the Start menu offers the party", F.selectStartIcon(1)) then return end
  F.press("A", 2)
  for _ = 1, 300 do F.idle(1); if F.cb2() == (S.CB2_UpdatePartyMenu & ~1) then break end end
  F.idle(60)
  F.press("A", 2); F.idle(40)
  F.press("Down", 2); F.idle(20); F.press("A", 2)
  local thrown = 0
  for _ = 1, 900 do
    F.idle(1)
    thrown = clippings()
    if thrown > 0 then break end
  end
  F.check(tag .. ": Cut throws grass clippings", thrown > 0)
  waitControl()
  F.idle(30)
end

local function steer(want)
  for _ = 1, 8 do
    local cur = F.r8(S.gActionSelectionCursor)
    if cur == want then return true end
    local key
    if (cur & 1) ~= (want & 1) then key = (cur & 1) < (want & 1) and "Right" or "Left"
    else key = (cur & 2) < (want & 2) and "Down" or "Up" end
    F.press(key, 2); F.idle(10)
  end
  return F.r8(S.gActionSelectionCursor) == want
end

local function runAway()
  for _ = 1, 6 do
    if not inBattle() then break end
    if isAction() then
      F.w16(S.gBattleMons + BM_ABILITY, ABILITY_RUN_AWAY) -- a foe's Mean Look must not trap the exit
      if steer(ACTION_RUN) then F.press("A", 2) end
    end
    for i = 1, 400 do
      if not inBattle() or (i > 60 and isAction()) then break end
      F.idle(1)
      if i % 30 == 0 then F.press("B", 2) end
    end
  end
  for i = 1, 3000 do
    if hasControl() then break end
    F.idle(1)
    if i % 30 == 0 then F.press("B", 2) end
  end
  F.idle(60)
end

-- One step: "moved", "blocked", or "battle", whether the player moved, and whether a script started
-- the battle. A step encounter locks field controls the moment the step ends and starts the battle
-- with no script; an overworld wild encounter that walks up to the player or bumps into them starts
-- it from a script (StartWildBattleWithOWE).
local function waitBattle()
  local scripted = false
  for _ = 1, 600 do
    if inBattle() then return true, scripted end
    scripted = scripted or F.r8(S.sGlobalScriptContextStatus) == CONTEXT_RUNNING
    F.idle(1)
  end
  return inBattle(), scripted
end
local function walk(dir)
  local x0, y0 = F.pos()
  local moved = false
  for _ = 1, 30 do
    joypad.set({ [dir] = true }); emu.frameadvance()
    local x, y = F.pos()
    if x ~= x0 or y ~= y0 then moved = true; break end
    if F.r8(S.sLockFieldControls) ~= 0 then
      local began, scripted = waitBattle()
      if began then return "battle", false, scripted end
    end
  end
  joypad.set({})
  for _ = 1, 32 do
    F.idle(1)
    if F.r8(S.sLockFieldControls) ~= 0 then break end
  end
  if F.r8(S.sLockFieldControls) ~= 0 then
    local began, scripted = waitBattle()
    if began then return "battle", moved, scripted end
  end
  return moved and "moved" or "blocked", moved, false
end

-- A stubble tile in the 3x3 with uncut grass beside it in the 5x5, and the step between them.
local function stubbleBesideGrass(cx, cy, before, after, cuts)
  local function at(t, dx, dy) return t[(dy + 2) * 5 + dx + 3] end
  for dy = -1, 1 do
    for dx = -1, 1 do
      if cuts[at(before, dx, dy)] and at(after, dx, dy) == cuts[at(before, dx, dy)] then
        for name, v in pairs(DIRS) do
          local gx, gy = dx + v[1], dy + v[2]
          if math.abs(gx) <= 2 and math.abs(gy) <= 2 and (math.abs(gx) == 2 or math.abs(gy) == 2)
              and cuts[at(before, gx, gy)] and at(after, gx, gy) == at(before, gx, gy) then
            return cx + dx, cy + dy, name
          end
        end
      end
    end
  end
  return nil
end

local OPPOSITE = { Up = "Down", Down = "Up", Left = "Right", Right = "Left" }
-- Walk from (x0, y0) to (tx, ty) one axis at a time.
local function goTo(tx, ty)
  for _ = 1, 8 do
    local x, y = F.pos()
    if x == tx and y == ty then return true end
    local dir = x < tx and "Right" or x > tx and "Left" or y < ty and "Down" or "Up"
    if walk(dir) == "battle" then runAway() end
  end
  local x, y = F.pos()
  return x == tx and y == ty
end

-- Back and forth between stubble and grass: battles must begin only after a step onto the grass.
local function encounters(tag, sx, sy, toGrass)
  if not F.check(tag .. ": walks onto the stubble", goTo(sx, sy), string.format("at %d,%d", F.pos())) then return false end
  local onStubble, onGrass, stubbleSteps, contact, blocked, shot = 0, 0, 0, 0, 0, false
  local dir = toGrass
  for _ = 1, 160 do
    local res, moved, scripted = walk(dir)
    local x, y = F.pos()
    local onS = x == sx and y == sy
    if res == "battle" then
      if not moved or scripted then contact = contact + 1
      elseif onS then onStubble = onStubble + 1
      else onGrass = onGrass + 1 end
      F.L(string.format("  battle at %d,%d after %s (moved %s, scripted %s)", x, y, dir, tostring(moved), tostring(scripted)))
      if onGrass == 1 and not shot then F.shot(tag .. "_battle"); shot = true end
      runAway()
    elseif res == "blocked" then
      blocked = blocked + 1
      if blocked > 20 then break end
      F.idle(30)
    elseif onS then
      stubbleSteps = stubbleSteps + 1
    end
    if res ~= "blocked" then blocked = 0 end
    if onS then dir = toGrass else dir = OPPOSITE[toGrass] end
    if onGrass >= 1 and stubbleSteps >= 40 then break end
  end
  goTo(sx, sy)
  F.L(string.format("%s: %d steps onto stubble, %d step battles on stubble, %d on grass, %d by an overworld Pokemon",
    tag, stubbleSteps, onStubble, onGrass, contact))
  F.check(tag .. ": walked onto the stubble at least 40 times", stubbleSteps >= 40, "steps " .. stubbleSteps)
  F.check(tag .. ": no step on the stubble starts a wild battle", onStubble == 0, "battles " .. onStubble)
  F.check(tag .. ": a step on the uncut grass beside it starts one", onGrass >= 1, "battles " .. onGrass)
  return onGrass >= 1
end

local function driveSave()
  F.w16(S.gSaveAttemptStatus, SENTINEL)
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

local function softReset()
  for _ = 1, 8 do joypad.set({ A = true, B = true, Start = true, Select = true }); emu.frameadvance() end
  joypad.set({})
end

-- Cut at (x, y): every grass in the 3x3 becomes its stubble, the roots table names the rest.
local function cutAndCheck(tag, x, y, cuts, roots)
  local before = area(x, y)
  F.shot(tag .. "_before")
  useCut(tag)
  F.shot(tag .. "_after")
  local after = area(x, y)
  F.L(tag .. ": before " .. table.concat(before, " "))
  F.L(tag .. ": after  " .. table.concat(after, " "))
  local inner, outer, grassInReach = {}, {}, 0
  for i = 1, 25 do
    local dx, dy = (i - 1) % 5 - 2, (i - 1) // 5 - 2
    local reach = math.abs(dx) <= 1 and math.abs(dy) <= 1
    local want = reach and cuts[before[i]] or before[i]
    if roots and roots[dx .. "," .. dy] then want = roots[dx .. "," .. dy] end
    if reach and cuts[before[i]] then grassInReach = grassInReach + 1 end
    if after[i] ~= want then
      local list = reach and inner or outer
      list[#list + 1] = string.format("(%d,%d) %#x->%#x want %#x", x + dx, y + dy, before[i], after[i], want)
    end
  end
  F.check(tag .. ": grass stands in Cut's reach", grassInReach >= 3, "grass tiles " .. grassInReach)
  F.check(tag .. ": every grass tile in reach becomes its stubble", #inner == 0, table.concat(inner, "; "))
  F.check(tag .. ": nothing else in the 5x5 changes", #outer == 0, table.concat(outer, "; "))
  F.check(tag .. ": control returns to the field", hasControl())
  return before, after
end

local function run(c)
  local tag, grp, map, x, y, cuts, roots = table.unpack(c)
  if not F.check(tag .. ": arrives", warpToCoords(grp, map, x, y, tag)) then return end
  F.idle(30)
  local before, after = cutAndCheck(tag, x, y, cuts, roots)

  local sx, sy, toGrass = stubbleBesideGrass(x, y, before, after, cuts)
  if F.check(tag .. ": stubble lies beside uncut grass", sx ~= nil) and encounters(tag, sx, sy, toGrass) then
    local now = area(x, y)
    F.check(tag .. ": the stubble survives a battle on the same map", sameArea(now, after), table.concat(now, " "))
    F.shot(tag .. "_after_battle")
  end

  local status = driveSave()
  F.check(tag .. ": saved beside the stubble", status == "done", status)
  softReset(); F.idle(60)
  if F.check(tag .. ": Continue reaches the field", F.boot(nil, true) and F.grp() == grp and F.mapn() == map) then
    waitControl()
    local now = area(x, y)
    F.check(tag .. ": the stubble survives a save and Continue on the same map", sameArea(now, after), table.concat(now, " "))
    F.shot(tag .. "_continue")
  end

  F.check(tag .. ": leaves the map", warpToCoords(AWAY[1], AWAY[2], AWAY[3], AWAY[4], tag .. "_away"))
  if not F.check(tag .. ": comes back", warpToCoords(grp, map, x, y, tag .. "_back")) then return end
  F.idle(30)
  local back = area(x, y)
  F.check(tag .. ": the grass grows back after leaving and returning", sameArea(back, before), table.concat(back, " "))
  F.shot(tag .. "_regrown")
end

-- Cut beside a seam, cross it and come back: the stubble on screen must cross with the player.
local function runSeam(c)
  local tag, grp, map, x, y, cuts, dir = table.unpack(c)
  if not F.check(tag .. ": arrives", warpToCoords(grp, map, x, y, tag)) then return end
  F.idle(30)
  local _, after = cutAndCheck(tag, x, y, cuts)
  local px, py, crossed = x, y, false
  local tx, ty = 0, 0
  for _ = 1, 8 do
    local res = walk(dir)
    local qx, qy = F.pos()
    F.L(string.format("  %s: step %s -> %s at %d,%d map %d.%d", tag, dir, res, qx, qy, F.grp(), F.mapn()))
    if res == "battle" then runAway() end
    if F.grp() ~= grp or F.mapn() ~= map then
      local qx, qy = F.pos()
      tx, ty = qx - (px + DIRS[dir][1]), qy - (py + DIRS[dir][2])
      crossed = true
      break
    end
    px, py = F.pos()
  end
  if not F.check(tag .. ": crosses the seam", crossed, string.format("grp %d map %d", F.grp(), F.mapn())) then return end
  F.idle(30)
  F.shot(tag .. "_across")
  local across = area(x + tx, y + ty)
  F.check(tag .. ": the stubble on screen crosses into the next map", sameArea(across, after), table.concat(across, " "))
  for _ = 1, 4 do
    if F.grp() == grp and F.mapn() == map then break end
    if walk(OPPOSITE[dir]) == "battle" then runAway() end
  end
  F.idle(30)
  F.check(tag .. ": back on the cut map", F.grp() == grp and F.mapn() == map)
  local back = area(x, y)
  F.check(tag .. ": the stubble is still there after crossing back", sameArea(back, after), table.concat(back, " "))
  F.shot(tag .. "_back")
end

F.run(function()
  if not F.boot(HUB_GROUP) then F.check("boot", false); F.finish(); return end
  giveMon(SPECIES_MARSHTOMP)
  F.check("a Pokemon in the party", F.r8(S.gPartiesCount) >= 1, "n=" .. F.r8(S.gPartiesCount))
  runScript({ SCR_OP_SETMONMOVE, 0, 0, MOVE_CUT & 0xFF, MOVE_CUT >> 8, SCR_OP_ADDITEM, ITEM_CUT_TOOL & 0xFF, ITEM_CUT_TOOL >> 8, 1, 0, SCR_OP_END })
  local only = os.getenv("PW_CUT_CASE")
  for _, c in ipairs(CASES) do
    if not only or c[1]:find(only, 1, true) then run(c) end
  end
  for _, c in ipairs(SEAMS) do
    if not only or c[1]:find(only, 1, true) then runSeam(c) end
  end
  F.finish()
end)
