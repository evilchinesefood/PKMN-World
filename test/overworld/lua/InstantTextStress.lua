-- Instant text speed (#387) mashed through the game's message-heavy screens.
--
-- Instant renders a whole message in the frame its printer starts, so any flow that leaned on a
-- message taking a few frames (to let a sprite load, a fade finish or a window draw) now runs those
-- steps back to back. Each case starts a real flow, then mashes a seeded mix of A and B (and Start
-- where a naming screen can open) until the player has control again. A case fails when the flow
-- crashes, freezes (vblank counter stops), never hands control back inside its budget, leaves the
-- field on a different map, or draws the field message box with a palette index no message colour
-- uses (the global text colour table leaking from another window, see text.c AddTextPrinter).
--
-- Run: test/overworld/mgba-run.sh test/overworld/lua/InstantTextStress.lua pokemonworld.gba
-- PW_ITS_ONLY=<text> runs the cases whose tag contains <text>.

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "InstantTextStress")

local ONLY = os.getenv and os.getenv("PW_ITS_ONLY") or nil
local CONTEXT_RUNNING, CONTEXT_SHUTDOWN = 0, 2
local TEXT_SPEED_INSTANT = 3
local MAIN_VBLANK_COUNTER1 = 0x20
local SYS = 0x948
local FLAG_SYS_POKEMON_GET, FLAG_SYS_POKEDEX_GET, FLAG_SYS_POKENAV_GET = SYS, SYS + 1, SYS + 2
local FLAG_SYS_GAME_CLEAR = SYS + 0x2B
local FLAG_SYS_BUG_CONTEST_MODE = SYS + 0x21
local ICON_POKEDEX, ICON_POKENAV, ICON_TRAINER = 0, 3, 5
local ITEM_MASTER_BALL = 4
local ITEM_CUT_TOOL, ITEM_SURF_TOOL, ITEM_ROCK_SMASH_TOOL, ITEM_STRENGTH_TOOL, ITEM_WATERFALL_TOOL = 875, 876, 877, 878, 879
local MOVE_CUT, MOVE_STRENGTH, MOVE_FLASH, MOVE_ROCK_SMASH, MOVE_SURF, MOVE_WATERFALL = 15, 70, 148, 249, 57, 127
local SPECIES_MACHOP, SPECIES_LAPRAS, SPECIES_PIDGEY, SPECIES_SCYTHER = 66, 131, 16, 123
local REGION_JOHTO = 2
local VAR_BUG_CONTEST_STATE = 0xA080 + 0x0E
local BUG_CONTEST_LIMIT = 60 * 60 * 8

local function vblank() return F.r32(S.gMain + MAIN_VBLANK_COUNTER1) end
local function optWord() return F.r16(F.sb2() + S.SaveBlock2.optionsU16) end
local function hasControl()
  return F.ow() and F.r8(S.sLockFieldControls) == 0 and F.r8(S.sGlobalScriptContextStatus) == CONTEXT_SHUTDOWN
end
local function setFlag(id)
  local a = F.sb1() + S.SaveBlock1.flags + (id // 8)
  F.w8(a, F.r8(a) | (1 << (id % 8)))
end

-- ---- scripts from EWRAM -----------------------------------------------------------------------
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
local function callScript(addr) local b = { 0x04 }; le32(b, addr); b[#b + 1] = 0x02; runScript(b) end
local function warp(g, n, x, y, native)
  local b = {}
  if native then b[#b + 1] = 0x23; le32(b, native | 1) end
  b[#b + 1] = 0x39; b[#b + 1] = g; b[#b + 1] = n; b[#b + 1] = 0xFF; le16(b, x); le16(b, y); b[#b + 1] = 0x27; b[#b + 1] = 0x02
  runScript(b)
  for _ = 1, 400 do
    F.idle(4)
    if F.reportCrash("warp") then return false end
    if F.grp() == g and F.mapn() == n and F.ow() then
      -- an arrival scene (a rival on Four Island) plays out under B before the case starts
      for _ = 1, 300 do
        if hasControl() then F.idle(30); return true end
        F.press("B", 2); F.idle(10)
      end
    end
  end
  F.L(string.format("  warp to %d.%d failed: at %d.%d cb2=%08X lock=%d ctx=%d", g, n, F.grp(), F.mapn(), F.cb2(),
    F.r8(S.sLockFieldControls), F.r8(S.sGlobalScriptContextStatus)))
  return false
end

-- ---- field message box colours ----------------------------------------------------------------
-- The field message box is window 0. Its text uses fg/shadow pairs 2/3 (dark), 4..9 (colour codes)
-- on fill 1; indices 10-15 are the dynamic colours other windows print with, and only ever reach
-- this window through the shared half-row table.
local function messageBoxStains()
  local w = S.gWindows
  if F.r8(w + S.Window.bg) == 0xFF then return 0 end
  local width, height = F.r8(w + S.Window.width), F.r8(w + S.Window.height)
  local data = F.r32(w + S.Window.tileData)
  if data < 0x02000000 or data >= 0x02040000 or width == 0 or width > 30 or height > 20 then return 0 end
  local bad = 0
  for i = 0, width * height * 32 // 4 - 1 do
    local word = F.r32(data + i * 4)
    for _ = 1, 8 do
      if (word & 0xF) >= 10 then bad = bad + 1 end
      word = word >> 4
    end
  end
  return bad
end

-- ---- the mash driver --------------------------------------------------------------------------
local seed = 0x2387
local function rnd(n) seed = (seed * 1103515245 + 12345) % 2147483648; return (seed >> 8) % n end

local function pickKey(keys)
  local total = 0
  for _, k in ipairs(keys) do total = total + k[2] end
  local r = rnd(total)
  for _, k in ipairs(keys) do
    if r < k[2] then return k[1] end
    r = r - k[2]
  end
  return keys[1][1]
end

local AB = { { "A", 7 }, { "B", 3 } }
local A_HEAVY = { { "A", 9 }, { "B", 1 } }
local B_HEAVY = { { "A", 4 }, { "B", 6 } }
local B_ONLY = { { "B", 1 } }
local NAMING = { { "A", 6 }, { "B", 2 }, { "Start", 2 } }
local MENU = { { "A", 5 }, { "B", 4 }, { "Down", 1 } }

-- Mash until the player has had control for three samples in a row. Returns ok, frames, detail.
local function mash(tag, keys, budget, watch)
  local frames, settled, stains, presses = 0, 0, 0, 0
  local lastVb, stalls = vblank(), 0
  local screens, order = {}, {}
  while frames < budget do
    if F.reportCrash(tag) then return false, frames, "crash screen" end
    local vb = vblank()
    if vb == lastVb then stalls = stalls + 1 else stalls = 0 end
    lastVb = vb
    if stalls > 30 then return false, frames, "vblank counter stopped" end
    if F.ow() then stains = math.max(stains, messageBoxStains()) end
    if watch then watch() end
    local cb = F.cb2()
    if not screens[cb] then screens[cb] = true; order[#order + 1] = string.format("%08X", cb) end
    if hasControl() then
      settled = settled + 1
      if settled >= 3 then return true, frames, string.format("presses=%d screens=%s", presses, table.concat(order, ",")), stains end
      F.idle(10); frames = frames + 10
    else
      settled = 0
      F.press(pickKey(keys), 2); presses = presses + 1
      local wait = 3 + rnd(12)
      F.idle(wait); frames = frames + 2 + wait
    end
  end
  return false, frames, string.format("no control after %d frames (cb2=%08X lock=%d ctx=%d script=%08X)",
    frames, F.cb2(), F.r8(S.sLockFieldControls), F.r8(S.sGlobalScriptContextStatus),
    F.r32(S.sGlobalScriptContext + S.ScriptCtx.scriptPtr)), stains
end

local function wanted(tag) return not ONLY or tag:find(ONLY, 1, true) end

-- One case: `start()` begins the flow and returns false if it never began.
local function case(tag, start, keys, budget, expectMap, watch)
  if not wanted(tag) then return end
  F.L("-- " .. tag)
  if not F.check(tag .. ": control before the flow", hasControl()) then F.shot(tag:gsub("%W", "_") .. "_busy"); return end
  if not F.check(tag .. ": flow starts", start()) then F.shot(tag:gsub("%W", "_") .. "_nostart"); return end
  local g0, n0 = F.grp(), F.mapn()
  local ok, frames, detail, stains = mash(tag, keys, budget or 9000, watch)
  F.check(tag .. ": control returns", ok, detail)
  F.check(tag .. ": message box only uses message colours", (stains or 0) == 0, "stained pixels=" .. tostring(stains))
  local g1, n1 = F.grp(), F.mapn()
  local eg, en = g0, n0
  if expectMap then eg, en = expectMap[1], expectMap[2] end
  F.check(tag .. ": field map afterwards", g1 == eg and n1 == en, string.format("%d.%d -> %d.%d (want %d.%d)", g0, n0, g1, n1, eg, en))
  F.check(tag .. ": text speed still Instant", (optWord() & 7) == TEXT_SPEED_INSTANT, string.format("%04X", optWord()))
  F.shot(tag:gsub("%W", "_"))
  if not ok then
    for _ = 1, 40 do if hasControl() then break end F.press("B", 2); F.idle(20) end
  end
end

-- Talk to an NPC: warp to the tile in front of it, face it, press A, see a script start.
local function talk(g, n, x, y, dir)
  return function()
    if not warp(g, n, x, y) then return false end
    F.face(dir)
    for _ = 1, 3 do
      F.press("A", 2)
      for _ = 1, 30 do F.idle(2); if not hasControl() then return true end end
    end
    local x, y = F.pos()
    local near = {}
    for _, o in ipairs(F.objdump()) do
      if math.abs(o.x - x) <= 2 and math.abs(o.y - y) <= 2 then near[#near + 1] = string.format("%d@(%d,%d)", o.i, o.x, o.y) end
    end
    F.L(string.format("  talk: nothing started at %d.%d (%d,%d) facing %s; objects near: %s", F.grp(), F.mapn(), x, y, dir, table.concat(near, " ")))
    return false
  end
end

local function startIcon(icon)
  return function()
    F.press("Start", 2); F.idle(50)
    if not F.selectStartIcon(icon) then F.press("B", 2); F.idle(30); return false end
    F.press("A", 2); F.idle(10)
    return true
  end
end

local function script(addr) return function() callScript(addr); F.idle(2); return true end end

local PARTY_SIZE = 6
local function giveMon(species, level, moves)
  local b = { 0x23 }; le32(b, S.ScrCmd_createmon | 1)
  b[#b + 1] = 0; b[#b + 1] = PARTY_SIZE
  le16(b, species); le16(b, level)
  le32(b, (1 << 17) | (1 << 18) | (1 << 19) | (1 << 20))
  for k = 1, 4 do le16(b, moves[k] or 0) end
  b[#b + 1] = 0x02
  runScript(b); F.idle(30)
end
local function addItem(id, qty)
  local b = { 0x44 }; le16(b, id); le16(b, qty); b[#b + 1] = 0x02
  runScript(b); F.idle(10)
end

-- Throw the last-used ball with R as soon as the action menu offers it; the rest of the mash is
-- the post-catch Pokedex page, the nickname prompt and the naming screen.
local CATCH = { { "R", 4 }, { "A", 4 }, { "Start", 2 }, { "B", 1 } }
local function wildBattle(species, level)
  return function()
    F.w16(S.gLastThrownBall, ITEM_MASTER_BALL); F.w16(S.gBallToDisplay, ITEM_MASTER_BALL)
    local b = { 0xB6 }; le16(b, species); b[#b + 1] = level; le16(b, 0); le16(b, 0); b[#b + 1] = 0; le16(b, 0)
    b[#b + 1] = 0xB7; b[#b + 1] = 0x02
    runScript(b)
    for _ = 1, 200 do F.idle(2); if F.cb2() == S.BattleMainCB2 then return true end end
    return false
  end
end

-- Walk into the tile ahead after Strength: the boulder must move and the player keep control.
local function pushAhead(dir)
  local x0, y0 = F.pos()
  local moved = false
  for _ = 1, 4 do
    if F.step(dir) then moved = true; break end
    F.idle(20)
  end
  local x1, y1 = F.pos()
  return moved and (x1 ~= x0 or y1 ~= y0), string.format("(%d,%d)->(%d,%d)", x0, y0, x1, y1)
end

local function giveParty()
  F.dbg(); F.idle(40); F.sel(2); F.idle(40)
  for _ = 1, 9 do F.press("Down", 2); F.idle(12) end
  F.press("A", 2); F.idle(180); F.bOut(6); F.idle(60)
end

local function allDexFlags()
  F.dbg(); F.idle(40); F.sel(7); F.idle(40)
  F.sel(2); F.idle(120); F.bOut(6); F.idle(60)
end

F.run(function()
  if not F.boot(100) then F.finish(); return end
  F.w16(F.sb2() + S.SaveBlock2.optionsU16, (optWord() & ~7) | TEXT_SPEED_INSTANT)
  F.check("text speed set to Instant", (optWord() & 7) == TEXT_SPEED_INSTANT)
  giveParty()
  F.check("debug party", F.r8(S.gPartiesCount) >= 1, "party=" .. F.r8(S.gPartiesCount))
  allDexFlags()
  for _, f in ipairs({ FLAG_SYS_POKEMON_GET, FLAG_SYS_POKEDEX_GET, FLAG_SYS_POKENAV_GET, FLAG_SYS_GAME_CLEAR }) do setFlag(f) end
  F.ensureFree()

  -- nurses, one per region
  case("Johto nurse heal (Violet)", talk(78, 4, 7, 4, "Up"), A_HEAVY)
  case("Hoenn nurse heal (Oldale)", talk(2, 2, 7, 4, "Up"), A_HEAVY)
  case("Kanto nurse heal (Pewter)", talk(40, 5, 7, 4, "Up"), A_HEAVY)
  case("Kanto nurse heal mashing B (Pewter)", function() F.face("Up"); F.press("A", 2); F.idle(6); return not hasControl() end, B_HEAVY)

  -- building PC: Someone's/Bill's PC, item PC, Hall of Fame
  case("building PC mashed A/B", script(S.EventScript_PC), MENU, 20000)
  case("building PC mashed B", script(S.EventScript_PC), B_HEAVY, 20000)
  case("Hall of Fame PC", script(S.EventScript_AccessHallOfFame), AB, 20000)

  -- start menu screens
  case("Pokedex entries", startIcon(ICON_POKEDEX), MENU, 20000)
  case("Trainer Card", startIcon(ICON_TRAINER), AB, 9000)
  case("PokeNav", startIcon(ICON_POKENAV), MENU, 20000)

  -- name raters, move relearners, day care
  case("Hoenn Name Rater (Slateport)", talk(9, 5, 6, 5, "Right"), NAMING, 20000)
  case("Johto Name Rater (Goldenrod)", talk(84, 14, 4, 5, "Up"), NAMING, 20000)
  case("Kanto Name Rater (Lavender)", talk(42, 4, 4, 5, "Up"), NAMING, 20000)
  case("Hoenn Move Relearner (Fallarbor)", talk(5, 7, 4, 5, "Up"), MENU, 20000)
  case("Johto Move Relearner (Blackthorn)", talk(94, 3, 7, 5, "Up"), MENU, 20000)
  case("Johto Day Care woman (Route 34)", talk(81, 5, 4, 8, "Left"), AB, 20000)

  case("TV", script(S.EventScript_TV), AB)

  -- a catch: Pokedex registration page, nickname prompt, naming screen
  addItem(ITEM_MASTER_BALL, 10)
  case("wild catch with nickname", wildBattle(SPECIES_PIDGEY, 3), CATCH, 30000)

  -- field moves, by a party Pokemon that knows them, unlocked by the tool items
  giveMon(SPECIES_MACHOP, 50, { MOVE_CUT, MOVE_ROCK_SMASH, MOVE_STRENGTH, MOVE_FLASH })
  giveMon(SPECIES_LAPRAS, 50, { MOVE_SURF, MOVE_WATERFALL })
  for _, it in ipairs({ ITEM_CUT_TOOL, ITEM_SURF_TOOL, ITEM_ROCK_SMASH_TOOL, ITEM_STRENGTH_TOOL, ITEM_WATERFALL_TOOL }) do addItem(it, 1) end
  F.check("field move party", F.r8(S.gPartiesCount) >= 3, "party=" .. F.r8(S.gPartiesCount))
  case("Cut, Hoenn (Route 104)", talk(0, 19, 34, 22, "Right"), A_HEAVY)
  case("Cut, Johto (Ilex Forest)", talk(80, 3, 32, 41, "Up"), A_HEAVY)
  case("Cut, Kanto (Cerulean)", talk(37, 3, 26, 33, "Up"), A_HEAVY)
  case("Rock Smash, Hoenn (Granite Cave)", talk(24, 9, 5, 15, "Up"), A_HEAVY)
  case("Rock Smash, Kanto (Four Island)", talk(37, 15, 5, 12, "Up"), A_HEAVY)
  case("Rock Smash, Johto (Dark Cave)", talk(94, 16, 24, 19, "Left"), A_HEAVY)
  case("Flash, Johto (Dark Cave)", script(S.EventScript_UseFlash), A_HEAVY)
  case("Strength, Johto (Mt Mortar)", talk(92, 9, 21, 43, "Right"), A_HEAVY)
  if wanted("Strength, Johto") then
    local ok, d = pushAhead("Right")
    F.check("Strength boulder pushes after the Instant prompt", ok, d)
  end
  case("Strength, Hoenn (Fiery Path)", talk(24, 14, 10, 16, "Up"), A_HEAVY)

  -- Safari Zone PA: the last step's "time's up" announcement and the walk back to the gate
  local function lastSafariStep(gate, zone)
    return function()
      if not warp(gate[1], gate[2], gate[3], gate[4]) then return false end
      if not warp(zone[1], zone[2], zone[3], zone[4], S.EnterSafariMode) then return false end
      F.w16(S.gSafariZoneStepCounter, 1)
      local moved = F.step("Left") or F.step("Right") or F.step("Down")
      for _ = 1, 60 do F.idle(2); if not hasControl() then return true end end
      F.L("  safari: no announcement after the last step, moved=" .. tostring(moved))
      return false
    end
  end
  -- A pays 500 to continue (the zone again), B declines and walks out to the gate.
  case("Hoenn Safari Zone time's up, continue", lastSafariStep({ 23, 0, 9, 6 }, { 26, 3, 32, 33 }), A_HEAVY, 9000, { 26, 3 })
  if wanted("Hoenn Safari Zone time's up, continue") then
    F.check("Hoenn Safari: paying to continue refills the steps", F.r16(S.gSafariZoneStepCounter) > 0, "steps=" .. F.r16(S.gSafariZoneStepCounter))
  end
  case("Hoenn Safari Zone time's up, decline", lastSafariStep({ 23, 0, 9, 6 }, { 26, 3, 32, 33 }), B_ONLY, 9000, { 23, 0 })
  case("Kanto Safari Zone time's up, continue", lastSafariStep({ 45, 0, 4, 4 }, { 35, 63, 26, 30 }), A_HEAVY, 9000, { 35, 63 })
  case("Kanto Safari Zone time's up, decline", lastSafariStep({ 45, 0, 4, 4 }, { 35, 63, 26, 30 }), B_ONLY, 9000, { 45, 0 })

  -- Bug-Catching Contest: entry, a catch, then the time limit, judging and the prize
  if wanted("Bug-Catching Contest") and warp(83, 7, 4, 2) then
    F.w32(S.gCurrentRegion, REGION_JOHTO)
    F.face("Left")
    local state = function() return F.r16(F.sb3() + S.SaveBlock3.regionVars + (VAR_BUG_CONTEST_STATE - 0xA000) * 2) end
    local entered = false
    for _ = 1, 400 do
      F.press("A", 2); F.idle(18)
      if F.grp() == 83 and F.mapn() == 5 and F.ow() and state() == 2 then entered = true; break end
      if F.reportCrash("contest_entry") then break end
    end
    for _ = 1, 100 do if hasControl() then break end F.press("B", 2); F.idle(12) end
    if F.check("Bug-Catching Contest entered at Instant text", entered) then
      giveMon(SPECIES_SCYTHER, 20, { 0 })
      case("Bug-Catching Contest time limit and judging", function()
        F.w32(S.sBugContestStartTime, (F.r32(S.gMain + MAIN_VBLANK_COUNTER1) - BUG_CONTEST_LIMIT - 30) & 0xFFFFFFFF)
        local _ = F.step("Up") or F.step("Left") or F.step("Right")
        for _ = 1, 120 do F.idle(2); if not hasControl() then return true end end
        return false
      end, { { "A", 6 }, { "Down", 2 }, { "B", 1 } }, 40000, { 83, 7 })
      F.check("Bug-Catching Contest: judging ends the contest", state() == 0 and F.r8(S.sBugContestTimerActive) == 0
        and (F.r8(F.sb1() + S.SaveBlock1.flags + FLAG_SYS_BUG_CONTEST_MODE // 8) >> (FLAG_SYS_BUG_CONTEST_MODE % 8)) & 1 == 0,
        string.format("state=%d timer=%d", state(), F.r8(S.sBugContestTimerActive)))
    end
  end

  F.finish()
end)
