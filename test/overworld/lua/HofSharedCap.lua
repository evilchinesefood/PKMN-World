-- The Hall of Fame records are one save buffer shared by two induction screens and two PC
-- viewers. Hoenn and Johto champions are inducted by hall_of_fame.c and Kanto champions by
-- hall_of_fame_frlg.c; the PC viewer is the Kanto one in Kanto and the Emerald one elsewhere.
-- Each file kept its own team cap (30 and 50), so once more than 30 teams were recorded a
-- Hoenn induction dropped the oldest team and wrote at index 29, ahead of the later Kanto
-- teams, and each viewer opened on a different "latest" team.
--
-- The records are made by real inductions: the suite warps onto each Hall of Fame room's
-- arrival tile (the tile the Champion's room warps to), the room's own script runs the
-- induction, the screen saves and soft resets, and Continue returns to the field. The lead's
-- level is set to the induction number first, so every record names its place in the order.
-- 32 Kanto inductions, one Hoenn induction, then both PC viewers are opened at a Pokemon
-- Center PC; one more Kanto induction, and the Hoenn viewer again.
--
-- Run: test/overworld/mgba-run.sh test/overworld/lua/HofSharedCap.lua

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "HofSharedCap")

local KANTO_RUNS = 32
local CONTEXT_RUNNING, CONTEXT_SHUTDOWN = 0, 2
local TEXT_SPEED_INSTANT = 3
local MON_LEVEL = 0x54
local HOF_MON_SIZE, HOF_TEAM_SIZE, HOF_MON_LVL, HOF_MON_SPECIES = 24, 24 * 6, 10, 8
local TASK_SIZE, TASK_ACTIVE, TASK_DATA = 40, 4, 8
local NUM_TASKS = 16
local HOF_CAPACITY = 2 * 3968 // HOF_TEAM_SIZE

local KANTO_HOF = { 35, 80, 5, 12 }   -- MAP_POKEMON_LEAGUE_HALL_OF_FAME, Champion's room arrival
local HOENN_HOF = { 16, 11, 7, 16 }   -- MAP_EVER_GRANDE_CITY_HALL_OF_FAME, Champion's room arrival
local VIRIDIAN_PC = { 39, 4, 11, 2 }  -- PC on the counter at (11,1)
local OLDALE_PC = { 2, 2, 10, 2 }     -- PC on the counter at (10,1)

local function optWord() return F.r16(F.sb2() + S.SaveBlock2.optionsU16) end
local function hasControl()
  return F.ow() and F.r8(S.sLockFieldControls) == 0 and F.r8(S.sGlobalScriptContextStatus) == CONTEXT_SHUTDOWN
end

local SCRIPT_BUF = S.gStringVar4 + 960
local function le16(t, v) t[#t + 1] = v & 0xFF; t[#t + 1] = (v >> 8) & 0xFF end
local function runScript(bytes)
  for i, b in ipairs(bytes) do F.w8(SCRIPT_BUF + i - 1, b) end
  F.w8(S.sGlobalScriptContext, 0)
  F.w8(S.sGlobalScriptContext + 1, 1)
  F.w32(S.sGlobalScriptContext + 4, 0)
  F.w32(S.sGlobalScriptContext + S.ScriptCtx.scriptPtr, SCRIPT_BUF)
  F.w8(S.sGlobalScriptContextStatus, CONTEXT_RUNNING)
end

-- warp map.group map.num 0xFF x y; waitstate; end
local function warpScript(g, n, x, y)
  local b = { 0x39, g, n, 0xFF }
  le16(b, x); le16(b, y); b[#b + 1] = 0x27; b[#b + 1] = 0x02
  runScript(b)
  for _ = 1, 400 do
    F.idle(4)
    if F.reportCrash("warp") then return false end
    if F.grp() == g and F.mapn() == n and F.ow() then return true end
  end
  F.L(string.format("  warp to %d.%d failed: at %d.%d cb2=%08X", g, n, F.grp(), F.mapn(), F.cb2()))
  return false
end

local function giveParty()
  F.dbg(); F.idle(40); F.sel(2); F.idle(40)
  for _ = 1, 9 do F.press("Down", 2); F.idle(12) end
  F.press("A", 2); F.idle(180); F.bOut(6); F.idle(60)
end

local function setLeadLevel(lvl) F.w8(S.gParties + MON_LEVEL, lvl) end

-- One induction through the room's own script. Returns true once Continue is back in the field.
local function induct(room, lvl, tag)
  setLeadLevel(lvl)
  if not warpScript(room[1], room[2], room[3], room[4]) then return false, "warp" end
  local left = false
  for i = 1, 6000 do
    if not F.ow() then left = true; break end
    if i % 12 == 0 then F.press("A", 2) else F.idle(1) end
  end
  if not left then F.shot(tag .. "_stuck_in_room"); return false, "no Hall of Fame screen" end
  F.idle(60)
  if not F.boot(nil, true) then return false, "no Continue" end
  for _ = 1, 300 do if hasControl() then break end F.press("B", 2); F.idle(10) end
  return true, ""
end

local function hofTeamLevels(count)
  local buf = F.r32(S.gHoFSaveBuffer)
  local out = {}
  if buf < 0x02000000 or buf >= 0x02040000 then return out, buf end
  for t = 0, (count or HOF_CAPACITY) - 1 do
    local base = buf + t * HOF_TEAM_SIZE
    if (F.r16(base + HOF_MON_SPECIES) >> 1) == 0 then break end
    out[#out + 1] = F.r8(base + HOF_MON_LVL)
  end
  return out, buf
end

local function viewerTask(pageNo)
  for i = 0, NUM_TASKS - 1 do
    local t = S.gTasks + i * TASK_SIZE
    if F.r8(t + TASK_ACTIVE) ~= 0 and F.r16(t + TASK_DATA + 2) == pageNo then
      local team = F.r16(t + TASK_DATA)
      if team < 0x8000 and team < HOF_CAPACITY then return team end
    end
  end
  return nil
end

local function seq(a, b)
  local t = {}
  for i = a, b do t[#t + 1] = i end
  return table.concat(t, ",")
end

-- Walk-free PC use: stand below the PC, face it, boot it, pick HALL OF FAME (row 2) by reading
-- the cursor, then read the records the viewer loaded and the team it opened on.
local function viewHallOfFame(pc, total, tag)
  if not warpScript(pc[1], pc[2], pc[3], pc[4]) then F.check(tag .. ": reached the PC", false); return end
  for _ = 1, 300 do if hasControl() then break end F.press("B", 2); F.idle(10) end
  F.face("Up")
  F.w8(S.sMenu + S.Menu.cursorPos, 0); F.w8(S.sMenu + S.Menu.maxCursorPos, 0)
  F.press("A", 2)
  local live = false
  for _ = 1, 120 do
    F.idle(10)
    if F.r8(S.sMenu + S.Menu.maxCursorPos) == 3 then live = true; break end
    F.press("A", 2)
  end
  if not F.check(tag .. ": PC menu with HALL OF FAME opened", live,
      string.format("maxCursorPos=%d at %d.%d", F.r8(S.sMenu + S.Menu.maxCursorPos), F.grp(), F.mapn())) then
    F.shot(tag .. "_no_pc_menu"); return
  end
  F.idle(20)
  for _ = 1, 8 do
    if F.mcur() == 2 then break end
    F.press("Down", 2); F.idle(12)
  end
  F.check(tag .. ": cursor on HALL OF FAME", F.mcur() == 2, "cursor=" .. F.mcur())
  F.press("A", 2)
  local team
  for _ = 1, 600 do
    F.idle(5)
    team = viewerTask(total)
    if team and not F.ow() then F.idle(90); team = viewerTask(total); break end
  end
  F.shot(tag .. "_first_page")
  local levels = hofTeamLevels()
  local list = table.concat(levels, ",")
  F.L(string.format("  %s: viewer opened on team %s; records by lead level: %s", tag, tostring(team), list))
  F.check(tag .. ": viewer opened", team ~= nil)
  local shown = team and levels[team + 1]
  F.check(tag .. ": first page is the latest induction", shown == total,
    string.format("team %s lead Lv%s, want Lv%d", tostring(team), tostring(shown), total))
  F.check(tag .. ": every induction kept, oldest first", list == seq(1, total),
    "records " .. list)
  for _ = 1, 3 do F.press("B", 2); F.idle(40) end
  for _ = 1, 400 do if hasControl() then break end F.press("B", 2); F.idle(10) end
  F.check(tag .. ": back in the field with control", hasControl())
end

F.run(function()
  if not F.boot(100) then F.finish(); return end
  F.w16(F.sb2() + S.SaveBlock2.optionsU16, (optWord() & ~7) | TEXT_SPEED_INSTANT)
  giveParty()
  F.check("debug party", F.r8(S.gPartiesCount) >= 1, "party=" .. F.r8(S.gPartiesCount))
  F.ensureFree()

  local n = 0
  for i = 1, KANTO_RUNS do
    n = n + 1
    local ok, why = induct(KANTO_HOF, n, "kanto" .. n)
    if not F.check(string.format("Kanto induction %d returns to the field", n), ok, why) then F.finish(); return end
  end
  n = n + 1
  local ok, why = induct(HOENN_HOF, n, "hoenn" .. n)
  if not F.check(string.format("Hoenn induction %d returns to the field", n), ok, why) then F.finish(); return end

  viewHallOfFame(VIRIDIAN_PC, n, "Kanto PC")
  viewHallOfFame(OLDALE_PC, n, "Hoenn PC")

  n = n + 1
  ok, why = induct(KANTO_HOF, n, "kanto" .. n)
  if not F.check(string.format("Kanto induction %d returns to the field", n), ok, why) then F.finish(); return end
  viewHallOfFame(OLDALE_PC, n, "Hoenn PC after Kanto")

  F.finish()
end)
