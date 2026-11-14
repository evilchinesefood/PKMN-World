-- Start menu Options opened from field states that carry their own runtime data.
--
-- FamilyOptionsFieldStress covers the hub, a Repel, rain and surfing. This suite covers the states
-- whose data lives outside the save or the map header and must survive the trip into Options and
-- back: a DexNav search, a Flash-dark cave before and after Flash, the Mach and Acro Bikes, a
-- fishing chain, the Hoenn and Kanto Safari Zones (balls and steps), the Bug-Catching Contest
-- (timer and Park Balls) and a Battle Frontier lobby. Each visit moves every row, leaves Text
-- Speed and the four rates on a new column, and compares the field against a snapshot taken
-- before Start: map, tile, facing, avatar flags, objects, song, map palettes, OBJ palettes by tag,
-- the Flash window, and the state's own counters.
--
-- Run: test/overworld/mgba-run.sh test/overworld/lua/StartOptionsStateStress.lua pokemonworld.gba
-- PW_SOS_ONLY=<text> runs the states whose tag contains <text>.

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "StartOptionsStateStress")

local ONLY = os.getenv and os.getenv("PW_SOS_ONLY") or nil
local CONTEXT_RUNNING, CONTEXT_SHUTDOWN = 0, 2
local ID_FOLLOWER = 254
local ICON_OPTIONS = 9
local OPTION_ROWS = 13
local AVATAR_CONTROLLABLE = 1 << 5
local SYS = 0x948
local FLAG_SYS_POKEMON_GET, FLAG_SYS_POKEDEX_GET = SYS, SYS + 1
local FLAG_SYS_BUG_CONTEST_MODE = SYS + 0x21
local FLAG_SYS_SAFARI_MODE = SYS + 0x2C
local FLAG_SYS_DEXNAV_SEARCHING = SYS + 0xBD
local VARS_START, VAR_DEXNAV_SPECIES, VAR_REPEL_STEP_COUNT = 0x4000, 0x40FE, 0x4021
local ITEM_MACH_BIKE, ITEM_ACRO_BIKE, ITEM_SAFARI_BALL = 707, 708, 23
local REGION_JOHTO = 2
local VAR_BUG_CONTEST_STATE = 0xA080 + 0x0E
local SPECIES_PIDGEY = 16
local AVATAR_MACH, AVATAR_ACRO = 1 << 1, 1 << 2

local RATES = {
  { name = "Exp Rate", row = 8, slot = 13, byColumn = { 1, 0, 2, 3 }, shift = 0 },
  { name = "Catch Rate", row = 9, slot = 14, byColumn = { 3, 0, 1, 2 }, shift = 2 },
  { name = "Encounter Rate", row = 10, slot = 2, byColumn = { 1, 0, 2, 3 }, shift = 6 },
  { name = "Money Loss", row = 11, slot = 4, byColumn = { 1, 0, 2, 3 }, shift = 8 },
}

local function tap(key) F.press(key, 2); F.idle(12) end
local function optWord(off) return F.r16(F.sb2() + S.SaveBlock2.optionsU16 + off) end
local function textSpeed() return optWord(0) & 7 end
local function rateValue(r) return (optWord(2) >> r.shift) & 3 end
local function hasControl()
  return F.ow() and F.r8(S.sLockFieldControls) == 0 and F.r8(S.sGlobalScriptContextStatus) == CONTEXT_SHUTDOWN
end
local function flag(id, on)
  local a, m = F.sb1() + S.SaveBlock1.flags + (id // 8), 1 << (id % 8)
  if on == nil then return (F.r8(a) & m) ~= 0 end
  F.w8(a, on and (F.r8(a) | m) or (F.r8(a) & ~m & 0xFF))
end
local function setVar(id, v) F.w16(F.sb1() + S.SaveBlock1.vars + (id - VARS_START) * 2, v) end

-- ---- Options screen ---------------------------------------------------------------------------
local function optionTask()
  for i = 0, S.Task.count - 1 do
    local a = S.gTasks + i * S.Task.stride
    if F.r8(a + S.Task.isActive) ~= 0 and (F.r32(a + S.Task.func) & ~1) == S.Task_OptionMenuProcessInput then return a end
  end
end
local function staged(slot) local t = optionTask(); return t and F.r16(t + S.Task.data + slot * 2) or -1 end
local function selectRow(row)
  for _ = 1, 30 do
    local c = staged(0)
    if c < 0 then return false end
    if c == row then return true end
    tap(c > row and "Up" or "Down")
  end
  return false
end
local function awaitOptions()
  for _ = 1, 150 do
    if optionTask() then F.idle(20); return true end
    if F.reportCrash("options_open") then return false end
    F.idle(4)
  end
  return false
end
local function exercise(tag, column)
  local ok = true
  for row = 0, OPTION_ROWS - 1 do
    if not selectRow(row) then ok = false; break end
    tap("Right"); tap("Left")
  end
  F.check(tag .. ": every row redraws through Right and Left", ok and optionTask() ~= nil)
  if selectRow(0) then
    for _ = 1, 4 do if staged(1) == column - 1 then break end tap("Right") end
  end
  for _, r in ipairs(RATES) do
    if selectRow(r.row) then
      for _ = 1, 4 do if staged(r.slot) == r.byColumn[column] then break end tap("Right") end
    end
  end
end
local function checkSaved(tag, column)
  local bad = {}
  if textSpeed() ~= column - 1 then bad[#bad + 1] = "text=" .. textSpeed() end
  for _, r in ipairs(RATES) do
    if rateValue(r) ~= r.byColumn[column] then bad[#bad + 1] = r.name .. "=" .. rateValue(r) end
  end
  F.check(tag .. ": Text Speed and rates saved at column " .. column, #bad == 0, table.concat(bad, " "))
end

-- ---- field snapshot ---------------------------------------------------------------------------
local function digest(addr, count)
  local h = 0
  for i = 0, count - 1 do h = (h * 31 + F.r16(addr + i * 2)) % 4294967291 end
  return h
end
-- OBJ palettes by tag. Overworld Pokemon and field effects load and free their palettes as they
-- come and go, so only tags loaded both before and after are compared, by colour.
local function objPalettes()
  local t = {}
  for slot = 0, 15 do
    local tag = F.r16(S.sSpritePaletteTags + slot * 2)
    if tag ~= 0xFFFF then t[tag] = digest(S.gPlttBufferUnfaded + (256 + slot * 16) * 2, 16) end
  end
  return t
end
local function commonTagsDiffer(a, b)
  local bad = {}
  for tag, d in pairs(a) do
    if b[tag] and b[tag] ~= d then bad[#bad + 1] = string.format("%04X", tag) end
  end
  table.sort(bad)
  return table.concat(bad, " ")
end
local function bgPalettes()
  local t = {}
  for p = 0, 12 do
    local c = {}
    -- colours with bit 15 set are night lights the day/night blend rewrites (AvgPaletteWeighted)
    for i = 0, 15 do
      local v = F.r16(S.gPlttBufferUnfaded + p * 32 + i * 2)
      c[#c + 1] = (v & 0x8000) ~= 0 and "lamp" or string.format("%04X", v)
    end
    t[p] = table.concat(c, ",")
  end
  return t
end
local function spritesOnFreePalettes()
  local bad = {}
  for i = 0, S.Sprite.count - 1 do
    local sp = S.gSprites + i * S.Sprite.stride
    if (F.r16(sp + S.Sprite.inUse) & 1) == 1 then
      local slot = F.r16(sp + 4) >> 12
      if F.r16(S.sSpritePaletteTags + slot * 2) == 0xFFFF and slot ~= 0 then bad[#bad + 1] = i .. ":p" .. slot end
    end
  end
  return table.concat(bad, " ")
end
-- The player and follower exactly; other map objects by local id only, since wandering NPCs turn
-- and step on their own and overworld wild Pokemon spawn and despawn with time.
local function objects()
  local list = {}
  for i = 0, 15 do
    local b = S.gObjectEvents + i * S.ObjectEvent.stride
    if (F.r8(b) & 1) == 1 then
      local id = F.r8(b + S.ObjectEvent.localId)
      local gfx = F.r16(b + S.ObjectEvent.graphicsId)
      if id == 255 or id == ID_FOLLOWER then
        list[#list + 1] = string.format("%d:%04X:%d,%d:%s:f%d", id, gfx, F.rs16(b + S.ObjectEvent.x), F.rs16(b + S.ObjectEvent.y),
          (F.r8(b + S.ObjectEvent.flags1) & 0x20) ~= 0 and "h" or "v", F.r8(b + S.ObjectEvent.facing) & 0xF)
      elseif (gfx & 0x4000) == 0 then
        list[#list + 1] = tostring(id)
      end
    end
  end
  table.sort(list)
  return table.concat(list, " ")
end
local function windowsInUse()
  local n = 0
  for i = 0, 31 do if F.r8(S.gWindows + i * S.Window.stride + S.Window.bg) ~= 0xFF then n = n + 1 end end
  return n
end
-- Width of the lit window on the screen's middle scanline, from both Flash scanline buffers.
local function flashWidth()
  local best = -1
  for b = 0, 1 do
    local v = F.r16(S.gScanlineEffectRegBuffers + b * 0x3C0 * 2 + 80 * 2)
    local w = (v & 0xFF) - (v >> 8)
    if w > best then best = w end
  end
  return best
end

local function snapshot(extra)
  local x, y = F.pos()
  local s = {
    where = string.format("%d.%d (%d,%d)", F.grp(), F.mapn(), x, y),
    avatar = F.r8(S.gPlayerAvatar) & ~AVATAR_CONTROLLABLE,
    objects = objects(),
    song = F.r32(S.gMPlayInfo_BGM),
    bgPals = bgPalettes(),
    objPals = objPalettes(),
    scanline = string.format("state=%d dest=%08X", F.r8(S.gScanlineEffect + 21), F.r32(S.gScanlineEffect + 8)),
    flash = flashWidth(),
    windows = windowsInUse(),
  }
  if extra then for k, v in pairs(extra()) do s[k] = v end end
  return s
end

local function compare(tag, before, after, skip, bgSkip)
  skip = skip or {}
  local keys = {}
  for k in pairs(before) do keys[#keys + 1] = k end
  table.sort(keys)
  local bgBad = {}
  for p = 0, 12 do
    if not bgSkip[p] and before.bgPals[p] ~= after.bgPals[p] then
      bgBad[#bgBad + 1] = tostring(p)
      F.L(string.format("    BG palette %d: %s -> %s", p, before.bgPals[p], after.bgPals[p]))
    end
  end
  F.check(tag .. ": map BG palettes restored", #bgBad == 0, "changed palettes: " .. table.concat(bgBad, " "))
  local objBad = commonTagsDiffer(before.objPals, after.objPals)
  F.check(tag .. ": OBJ palettes restored per tag", objBad == "", "changed tags: " .. objBad)
  for _, k in ipairs(keys) do
    if not skip[k] and k ~= "bgPals" and k ~= "objPals" then
      F.check(tag .. ": " .. k .. " restored", tostring(after[k]) == tostring(before[k]),
        tostring(before[k]) .. " -> " .. tostring(after[k]))
    end
  end
  local stray = spritesOnFreePalettes()
  F.check(tag .. ": every sprite draws with a loaded palette", stray == "", stray)
end

local column = 1
local function wanted(tag) return not ONLY or tag:find(ONLY, 1, true) end

-- Start -> Options -> every row -> B -> field, compared with the snapshot.
local function visit(tag, extra, skip)
  if not wanted(tag) then return false end
  F.L("-- " .. tag)
  column = column % 4 + 1
  F.idle(40)
  if not F.check(tag .. ": player has control before Start", hasControl()) then F.shot(tag:gsub("%W", "_") .. "_busy"); return false end
  -- A control with no Options visit names what changes on its own (a tileset palette cycle, the
  -- bike music fading in, a field effect ending); those keys are logged and left out.
  local control = snapshot(extra)
  F.idle(400)
  local before = snapshot(extra)
  skip = skip or {}
  local bgSkip = {}
  for p = 0, 12 do
    if control.bgPals[p] ~= before.bgPals[p] then
      F.L(string.format("  %s: BG palette %d changes without Options, not compared", tag, p))
      bgSkip[p] = true
    end
  end
  local objDrift = commonTagsDiffer(control.objPals, before.objPals)
  if objDrift ~= "" then F.L("  " .. tag .. ": OBJ tags changing without Options: " .. objDrift) end
  for k, v in pairs(before) do
    if k ~= "bgPals" and k ~= "objPals" and tostring(control[k]) ~= tostring(v) then
      F.L(string.format("  %s: %s changes without Options (%s -> %s), not compared", tag, k, tostring(control[k]), tostring(v)))
      skip[k] = true
    end
  end
  tap("Start"); F.idle(50)
  if not F.selectStartIcon(ICON_OPTIONS) then F.check(tag .. ": Options icon on the Start menu", false); tap("B"); return false end
  tap("A")
  if not F.check(tag .. ": Options opens", awaitOptions()) then F.shot(tag:gsub("%W", "_") .. "_no_options"); return false end
  exercise(tag, column)
  tap("B")
  for _ = 1, 120 do if not optionTask() then break end F.idle(2) end
  F.idle(90)
  tap("B")
  for _ = 1, 60 do if hasControl() then break end F.idle(4) end
  F.idle(40)
  F.check(tag .. ": control returns without a crash", hasControl() and not F.reportCrash(tag))
  checkSaved(tag, column)
  compare(tag, before, snapshot(extra), skip, bgSkip)
  F.shot(tag:gsub("%W", "_"))
  return true
end

-- ---- setup helpers ----------------------------------------------------------------------------
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
end
local function settle(budget)
  for _ = 1, budget or 300 do
    if F.reportCrash("settle") then return false end
    if hasControl() then F.idle(30); return true end
    F.press("B", 2); F.idle(10)
  end
  return false
end
-- warp (optionally after a native call such as EnterSafariMode), waitstate, end
local function warp(g, n, x, y, native)
  local b = {}
  if native then b[#b + 1] = 0x23; le32(b, native | 1) end
  b[#b + 1] = 0x39; b[#b + 1] = g; b[#b + 1] = n; b[#b + 1] = 0xFF; le16(b, x); le16(b, y)
  b[#b + 1] = 0x27; b[#b + 1] = 0x02
  runScript(b)
  for _ = 1, 400 do
    F.idle(4)
    if F.reportCrash("warp") then return false end
    if F.grp() == g and F.mapn() == n and F.ow() then return settle() end
  end
  F.L(string.format("  warp to %d.%d failed at %d.%d", g, n, F.grp(), F.mapn()))
  return false
end
local function addItem(id, qty)
  local b = { 0x44 }; le16(b, id); le16(b, qty); b[#b + 1] = 0x02
  runScript(b); F.idle(10)
end
local function giveParty()
  F.dbg(); F.idle(40); F.sel(2); F.idle(40)
  for _ = 1, 9 do F.press("Down", 2); F.idle(12) end
  F.press("A", 2); F.idle(180); F.bOut(6); F.idle(60)
end
-- Select with the bike registered; the cycling music fades in over the next few seconds
local function registerAndSelect(item)
  F.w16(F.sb1() + S.SaveBlock1.registeredItem, item)
  F.press("Select", 2); F.idle(300)
end

F.run(function()
  if not F.boot(100) then F.finish(); return end
  giveParty()
  flag(FLAG_SYS_POKEMON_GET, true); flag(FLAG_SYS_POKEDEX_GET, true)
  F.ensureFree()

  -- DexNav: R starts the bound species' search; the Start menu ends it by design. Coming back
  -- from Options must leave no search window, sprite or palette behind, and R must work again.
  if wanted("DexNav") and F.check("warp to Route 29", warp(75, 2, 14, 15)) then
    setVar(VAR_DEXNAV_SPECIES, SPECIES_PIDGEY)
    setVar(VAR_REPEL_STEP_COUNT, 250)
    local windows0 = windowsInUse()
    F.press("R", 2); F.idle(90)
    local searching = flag(FLAG_SYS_DEXNAV_SEARCHING) and F.r32(S.sDexNavSearchDataPtr) ~= 0
    F.check("DexNav search started with R", searching,
      string.format("flag=%s ptr=%08X", tostring(flag(FLAG_SYS_DEXNAV_SEARCHING)), F.r32(S.sDexNavSearchDataPtr)))
    if searching then
      visit("DexNav search", nil, { windows = true, objects = true })
      F.check("DexNav: the search ended when the Start menu opened", not flag(FLAG_SYS_DEXNAV_SEARCHING) and F.r32(S.sDexNavSearchDataPtr) == 0,
        string.format("flag=%s ptr=%08X", tostring(flag(FLAG_SYS_DEXNAV_SEARCHING)), F.r32(S.sDexNavSearchDataPtr)))
      -- windows0 can still include the map name popup, which closes on its own
      F.check("DexNav: no search window left allocated", windowsInUse() <= windows0, windows0 .. " -> " .. windowsInUse())
      F.press("R", 2); F.idle(90)
      F.check("DexNav: R starts a new search after Options", flag(FLAG_SYS_DEXNAV_SEARCHING) and F.r32(S.sDexNavSearchDataPtr) ~= 0)
      F.shot("dexnav_again")
      F.press("Start", 2); F.idle(40); F.press("B", 2); F.idle(60)
      settle()
    end
  end

  -- fishing chain and bikes in New Bark Town, away from grass and its overworld Pokemon
  local town = (wanted("fishing") or wanted("Bike")) and F.check("warp to New Bark Town", warp(75, 0, 12, 13))
  if town and wanted("fishing") then
    F.w8(S.gChainFishingDexNavStreak, 5)
    visit("fishing chain", function() return { streak = F.r8(S.gChainFishingDexNavStreak) } end)
  end

  addItem(ITEM_MACH_BIKE, 1); addItem(ITEM_ACRO_BIKE, 1)
  if town and wanted("Bike") then
    registerAndSelect(ITEM_MACH_BIKE)
    if F.check("riding the Mach Bike", (F.r8(S.gPlayerAvatar) & AVATAR_MACH) ~= 0, string.format("avatar=%02X", F.r8(S.gPlayerAvatar))) then
      visit("Mach Bike")
      local x0 = F.pos(); local moved = F.step("Right") or F.step("Left")
      F.check("Mach Bike rides after Options", moved and (F.r8(S.gPlayerAvatar) & AVATAR_MACH) ~= 0)
      registerAndSelect(ITEM_MACH_BIKE)
    end
    registerAndSelect(ITEM_ACRO_BIKE)
    if F.check("riding the Acro Bike", (F.r8(S.gPlayerAvatar) & AVATAR_ACRO) ~= 0, string.format("avatar=%02X", F.r8(S.gPlayerAvatar))) then
      visit("Acro Bike")
      local moved = F.step("Right") or F.step("Left")
      F.check("Acro Bike rides after Options", moved and (F.r8(S.gPlayerAvatar) & AVATAR_ACRO) ~= 0)
      registerAndSelect(ITEM_ACRO_BIKE)
    end
  end

  -- Flash-dark cave, before and after Flash
  if wanted("dark cave") and F.check("warp to Dark Cave", warp(94, 16, 24, 19)) then
    F.L(string.format("  dark cave flash width %d", flashWidth()))
    visit("dark cave without Flash")
    local b = { 0x04 }; le32(b, S.EventScript_UseFlash); b[#b + 1] = 0x02
    runScript(b); settle()
    F.L(string.format("  dark cave flash width after Flash %d", flashWidth()))
    visit("dark cave after Flash")
  end

  -- Safari Zones, entered the way the gate scripts do it: EnterSafariMode then the warp
  local function safari() return { balls = F.r8(S.gNumSafariBalls), steps = F.r16(S.gSafariZoneStepCounter), mode = tostring(flag(FLAG_SYS_SAFARI_MODE)) } end
  if wanted("Safari") and F.check("warp to the Hoenn Safari gate", warp(23, 0, 9, 6)) then
    if F.check("enter the Hoenn Safari Zone", warp(26, 3, 32, 33, S.EnterSafariMode) and flag(FLAG_SYS_SAFARI_MODE)) then
      visit("Hoenn Safari Zone", safari)
      local s0 = F.r16(S.gSafariZoneStepCounter)
      local moved = F.step("Left") or F.step("Right") or F.step("Down")
      F.check("Hoenn Safari: a step after Options costs one step", moved and F.r16(S.gSafariZoneStepCounter) == s0 - 1,
        string.format("moved=%s %d -> %d", tostring(moved), s0, F.r16(S.gSafariZoneStepCounter)))
    end
  end
  if wanted("Safari") and F.check("warp to the Kanto Safari gate", warp(45, 0, 4, 4)) then
    if F.check("enter the Kanto Safari Zone", warp(35, 63, 26, 30, S.EnterSafariMode) and flag(FLAG_SYS_SAFARI_MODE)) then
      visit("Kanto Safari Zone", safari)
      local s0 = F.r16(S.gSafariZoneStepCounter)
      local moved = F.step("Left") or F.step("Right") or F.step("Down")
      F.check("Kanto Safari: a step after Options costs one step", moved and F.r16(S.gSafariZoneStepCounter) == s0 - 1,
        string.format("moved=%s %d -> %d", tostring(moved), s0, F.r16(S.gSafariZoneStepCounter)))
    end
  end

  -- Bug-Catching Contest, entered through the attendant
  local function contest()
    return { start = F.r32(S.sBugContestStartTime), active = F.r8(S.sBugContestTimerActive),
      ballSlots = F.itemCount(ITEM_SAFARI_BALL), mode = tostring(flag(FLAG_SYS_BUG_CONTEST_MODE)) }
  end
  if wanted("Contest") and F.check("warp to the National Park gate", warp(83, 7, 4, 2)) then
    F.w32(S.gCurrentRegion, REGION_JOHTO)
    F.face("Left"); F.press("A", 3); F.idle(40)
    local state = function() return F.r16(F.sb3() + S.SaveBlock3.regionVars + (VAR_BUG_CONTEST_STATE - 0xA000) * 2) end
    for _ = 1, 400 do
      F.press("A", 2); F.idle(18)
      if F.grp() == 83 and F.mapn() == 5 and F.ow() and state() == 2 then break end
      if F.reportCrash("contest_entry") then break end
    end
    settle()
    if F.check("in the Bug-Catching Contest", F.grp() == 83 and F.mapn() == 5 and flag(FLAG_SYS_BUG_CONTEST_MODE),
      string.format("at %d.%d mode=%s", F.grp(), F.mapn(), tostring(flag(FLAG_SYS_BUG_CONTEST_MODE)))) then
      visit("Bug-Catching Contest", contest)
      F.check("Bug-Catching Contest: timer still running after Options", F.r8(S.sBugContestTimerActive) ~= 0)
    end
  end

  -- Battle Frontier lobby
  if wanted("Frontier") and F.check("warp to the Battle Tower lobby", warp(26, 5, 12, 7)) then
    visit("Battle Tower lobby")
  end

  F.finish()
end)
