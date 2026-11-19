-- A Hall of Fame team carrying an Egg and a fainted Pokemon, in all three regions and both viewers.
--
-- The records keep each member's species, or SPECIES_EGG for an Egg. 5ac8745870 retired the
-- loader that rewrote an older build's Egg value (it now reads as Classic Cap Pikachu) and folded
-- the record loading in both induction screens into one condition. The party is a level 70 Mewtwo,
-- a Togepi Egg from the giveegg command and a level 30 Pidgey at 0 HP. Each region's room script
-- inducts it under a seeded mash of every button until the soft reset; Continue must return with
-- the same three members. Then HALL OF FAME is opened at the Viridian PC (the Kanto viewer) and the
-- Oldale PC (the Emerald viewer) with real input: three records, each holding Mewtwo, the Egg and
-- Pidgey, and on the Egg's page the "No." line must be blank (the viewers print no dex number for
-- SPECIES_EGG) while Mewtwo's and Pidgey's pages print one. The game clear heals the party, as in
-- Emerald, so Pidgey is knocked out again before each induction. A soft reset inside the viewer
-- must Continue at the last save (the Johto induction's New Bark Town) with the party intact.
--
-- PW_HOFEGG_BASE=<n> reseeds the mash.
-- Run: test/overworld/mgba-run.sh test/overworld/lua/HofEggRecord.lua

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "HofEggRecord")

local BASE = tonumber(os.getenv("PW_HOFEGG_BASE") or "") or 0x1E66
local SPECIES_PIDGEY, SPECIES_MEWTWO, SPECIES_TOGEPI = 16, 150, 175
local MON = S.Pokemon.size
local CONTEXT_RUNNING, CONTEXT_SHUTDOWN = 0, 2
local VAR_JOHTO_LEAGUE_STATE = 0xA080 + 0x3B
local HOF_MON_SIZE, HOF_TEAM_SIZE = 24, 24 * 6
local TASK_SIZE, TASK_ACTIVE, TASK_DATA = 40, 4, 8
local NUM_TASKS = 16

local KANTO_HOF = { 35, 80, 5, 12 }
local HOENN_HOF = { 16, 11, 7, 16 }
local JOHTO_HOF = { 99, 10, 5, 12 }
local VIRIDIAN_PC = { 39, 4, 11, 2 }
local OLDALE_PC = { 2, 2, 10, 2 }

local seed = BASE
local function rnd()
  seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF
  return seed >> 8
end
local function seedFor(tag)
  local h = BASE & 0x7FFFFFFF
  for i = 1, #tag do h = ((h ~ tag:byte(i)) * 16777619) & 0x7FFFFFFF end
  return h
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
end
local function setVar(id, v) local b = { 0x16 }; le16(b, id); le16(b, v); b[#b + 1] = 0x02; runScript(b); F.idle(20) end
local function createMon(species, level)
  local b = { 0x23 }; le32(b, S.ScrCmd_createmon | 1)
  b[#b + 1] = 0; b[#b + 1] = 6
  le16(b, species); le16(b, level)
  le32(b, 0)
  b[#b + 1] = 0x02
  runScript(b); F.idle(20)
end
local function giveEgg(species) local b = { 0x7A }; le16(b, species); b[#b + 1] = 0x02; runScript(b); F.idle(20) end

local function instantText()
  local a = F.sb2() + S.SaveBlock2.optionsU16
  F.w16(a, (F.r16(a) & ~7) | 3)
end
local function hasControl()
  return F.ow() and F.r8(S.sLockFieldControls) == 0 and F.r8(S.sGlobalScriptContextStatus) == CONTEXT_SHUTDOWN
end
local function settle()
  for _ = 1, 400 do if hasControl() then return true end F.press("B", 2); F.idle(10) end
  return hasControl()
end

local function warpScript(p)
  local b = { 0x39, p[1], p[2], 0xFF }
  le16(b, p[3]); le16(b, p[4]); b[#b + 1] = 0x27; b[#b + 1] = 0x02
  runScript(b)
  for _ = 1, 400 do
    F.idle(4)
    if F.reportCrash("warp") then return false end
    if F.grp() == p[1] and F.mapn() == p[2] and F.ow() then return true end
  end
  return false
end

local function slot(i) return S.gParties + i * MON end
local function isEgg(i) return (F.r8(slot(i) + 19) & 0x04) ~= 0 end
local function partyState()
  local t = {}
  for i = 0, F.r8(S.gPartiesCount) - 1 do
    t[#t + 1] = string.format("%08X/%d/%s", F.r32(slot(i)), F.r8(slot(i) + S.Pokemon.level), isEgg(i) and "egg" or "mon")
  end
  return table.concat(t, ",")
end
local function hp(i) return F.r16(slot(i) + S.Pokemon.hp) end
local function healed() return hp(2) > 0 and hp(2) == F.r16(slot(2) + S.Pokemon.maxHP) end

local STOP = {}
for _, k in ipairs({ "CB2_Intro", "CB2_InitTitleScreen", "CB2_WorldTitleScreen", "CB2_InitMainMenu", "CB2_MainMenu" }) do
  if S[k] then STOP[S[k] & ~1] = k end
end

local DIRS = { "Up", "Down", "Left", "Right" }
local function mashFrame()
  local t = {}
  for b, p in pairs({ A = 30, B = 25, Start = 8, Select = 8, L = 8, R = 8 }) do
    if rnd() % 100 < p then t[b] = true end
  end
  if t.R and t.Start then t.R = nil end
  if t.A and t.B and t.Start and t.Select then t.Select = nil end
  if rnd() % 100 < 40 then t[DIRS[rnd() % 4 + 1]] = true end
  joypad.set(t)
  emu.frameadvance()
end

local function induct(tag, room, party0)
  seed = seedFor(tag)
  F.L(string.format("== induct %s == seed=%d", tag, seed))
  if not warpScript(room) then F.check(tag .. ": reached the Hall of Fame", false); return false end
  local stopAt, crashed, frames = nil, false, 0
  for i = 1, 30000 do
    frames = i
    if i % 10 == 0 and F.reportCrash(tag) then crashed = true; break end
    local cb = F.cb2()
    if STOP[cb] then stopAt = STOP[cb]; break end
    if i % 3000 == 0 then F.shot(string.format("%s_%d", tag, i // 3000)) end
    mashFrame()
  end
  joypad.set({})
  F.L(string.format("  mash ended after %d frames at %s", frames, tostring(stopAt)))
  F.check(tag .. ": no crash during the induction", not crashed)
  if not F.check(tag .. ": the induction ended in the soft reset", stopAt ~= nil,
      string.format("cb2=%08X grp=%d map=%d", F.cb2(), F.grp(), F.mapn())) then
    F.shot(tag .. "_stuck"); return false
  end
  F.idle(30)
  if not F.check(tag .. ": Continue", F.boot(nil, true)) then return false end
  F.check(tag .. ": control after Continue", settle())
  instantText()
  local party1 = partyState()
  F.check(tag .. ": same three members, the Egg still an Egg", party1 == party0, party1)
  F.check(tag .. ": the game clear healed the fainted Pidgey", healed(), string.format("hp=%d", hp(2)))
  F.w16(slot(2) + S.Pokemon.hp, 0)
  return true
end

local function viewerTask()
  for i = 0, NUM_TASKS - 1 do
    local t = S.gTasks + i * TASK_SIZE
    if F.r8(t + TASK_ACTIVE) ~= 0 and F.r16(t + TASK_DATA + 2) == 3 then return t end
  end
  return nil
end

local function records()
  local buf = F.r32(S.gHoFSaveBuffer)
  local out = {}
  if buf < 0x02000000 or buf >= 0x02040000 then return out end
  for t = 0, 3 do
    local team = {}
    for m = 0, 5 do
      local a = buf + t * HOF_TEAM_SIZE + m * HOF_MON_SIZE
      local sp = F.r16(a + 8) >> 1
      if sp ~= 0 then team[#team + 1] = { species = sp, lvl = F.r8(a + 10), pid = F.r32(a + 4) } end
    end
    if #team == 0 then break end
    out[#out + 1] = team
  end
  return out
end

-- Inked pixels in window 0's "No." line, screen x 16..79 and rows 0..15, read through the tiles.
local function dexLineInk()
  local w = S.gWindows
  local width, data = F.r8(w + S.Window.width), F.r32(w + S.Window.tileData)
  if data < 0x02000000 or data >= 0x02040000 or width == 0 then return -1 end
  local ink = 0
  for y = 0, 15 do
    for x = 16, 79 do
      local tile = (y // 8) * width + (x // 8)
      local b = F.r8(data + tile * 32 + (y % 8) * 4 + (x % 8) // 2)
      local px = (x % 2 == 0) and (b & 0xF) or (b >> 4)
      if px ~= 0 then ink = ink + 1 end
    end
  end
  return ink
end

local function openViewer(pc, tag)
  if not warpScript(pc) then F.check(tag .. ": reached the PC", false); return nil end
  settle(); instantText()
  F.face("Up")
  F.w8(S.sMenu + S.Menu.cursorPos, 0); F.w8(S.sMenu + S.Menu.maxCursorPos, 0)
  F.press("A", 2)
  local live = false
  for _ = 1, 120 do
    F.idle(10)
    if F.r8(S.sMenu + S.Menu.maxCursorPos) == 3 then live = true; break end
    F.press("A", 2)
  end
  if not F.check(tag .. ": PC menu with HALL OF FAME opened", live) then F.shot(tag .. "_no_pc_menu"); settle(); return nil end
  F.idle(20)
  for _ = 1, 8 do
    if F.mcur() == 2 then break end
    F.press("Down", 2); F.idle(12)
  end
  F.press("A", 2)
  local task
  for _ = 1, 600 do
    F.idle(5)
    task = viewerTask()
    if task and not F.ow() then F.idle(120); break end
  end
  F.check(tag .. ": viewer opened on the latest record", task ~= nil)
  return task
end

local function viewRecords(pc, tag, eggSpecies)
  local task = openViewer(pc, tag)
  if not task then return end
  local recs = records()
  local ok = #recs == 3
  for _, team in ipairs(recs) do
    ok = ok and #team == 3 and team[1].species == SPECIES_MEWTWO and team[1].lvl == 70
      and team[2].species == eggSpecies and team[3].species == SPECIES_PIDGEY and team[3].lvl == 30
  end
  local desc = {}
  for _, team in ipairs(recs) do
    local m = {}
    for _, mon in ipairs(team) do m[#m + 1] = mon.species .. "/L" .. mon.lvl end
    desc[#desc + 1] = table.concat(m, " ")
  end
  F.check(tag .. ": three records of Mewtwo, the Egg and Pidgey", ok, table.concat(desc, " | "))

  for page = 1, 3 do
    local inks = {}
    for m = 0, 2 do
      if m > 0 then F.press("Down", 2); F.idle(60) end
      inks[m + 1] = dexLineInk()
      F.shot(string.format("%s_record%d_mon%d", tag, page, m))
    end
    F.L(string.format("  %s record %d No. line ink: Mewtwo %d, Egg %d, Pidgey %d", tag, page, inks[1], inks[2], inks[3]))
    F.check(string.format("%s record %d: Mewtwo's and Pidgey's pages print a No. line", tag, page), inks[1] > 0 and inks[3] > 0)
    F.check(string.format("%s record %d: the Egg's page prints no No. line", tag, page), inks[2] == 0)
    for _ = 1, 2 do F.press("Up", 2); F.idle(40) end
    if page < 3 then F.press("A", 2); F.idle(150) end
  end
  F.press("B", 2); F.idle(60)
  F.check(tag .. ": back in the field with control", settle())
end

F.run(function()
  if not F.boot(100) then F.finish(); return end
  instantText()
  createMon(SPECIES_MEWTWO, 70)
  giveEgg(SPECIES_TOGEPI)
  createMon(SPECIES_PIDGEY, 30)
  F.w16(slot(2) + S.Pokemon.hp, 0)
  F.check("setup: Mewtwo, an Egg and a fainted Pidgey", F.r8(S.gPartiesCount) == 3 and not isEgg(0) and isEgg(1)
    and not isEgg(2) and hp(2) == 0, partyState())
  local party0 = partyState()

  if not induct("kanto", KANTO_HOF, party0) then F.finish(); return end
  if not induct("hoenn", HOENN_HOF, party0) then F.finish(); return end
  setVar(VAR_JOHTO_LEAGUE_STATE, 6)
  if not induct("johto", JOHTO_HOF, party0) then F.finish(); return end

  local task = openViewer(OLDALE_PC, "probe")
  local recs = task and records() or {}
  local eggSpecies = recs[1] and recs[1][2] and recs[1][2].species or -1
  F.L(string.format("  the Egg is recorded as species %d", eggSpecies))
  F.check("the Egg is recorded as neither nothing nor a Togepi", eggSpecies > 0 and eggSpecies ~= SPECIES_TOGEPI)
  if task then F.press("B", 2); F.idle(60); settle() end

  viewRecords(VIRIDIAN_PC, "kanto_viewer", eggSpecies)
  viewRecords(OLDALE_PC, "emerald_viewer", eggSpecies)

  if openViewer(OLDALE_PC, "reset") then
    F.press("Down", 2); F.idle(60)
    for _ = 1, 10 do joypad.set({ A = true, B = true, Start = true, Select = true }); emu.frameadvance() end
    joypad.set({}); F.idle(120)
    F.check("reset: Continue after a soft reset in the viewer", F.boot(nil, true))
    F.check("reset: control at the last save, New Bark Town", settle() and F.grp() == 75 and F.mapn() == 0,
      string.format("grp=%d map=%d", F.grp(), F.mapn()))
    F.check("reset: party unchanged", partyState() == party0, partyState())
  end

  F.check("no crash", not F.reportCrash("end"))
  F.finish()
end)
