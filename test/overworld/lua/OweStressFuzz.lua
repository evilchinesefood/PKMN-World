-- Visible wild Pokemon under pressure: crowded routes, menus, running, map edges and gates.
--
-- On a route in each region the spawn countdown is zeroed before every action, so all four
-- encounter slots stay filled. A fixed pseudo-random sequence then walks, runs, opens and closes
-- the Start menu, presses A at whatever is ahead, and crosses map connections and gate doors.
-- Contacts, approaches, battles and their returns are the game's own. Battles are won by pressing
-- A with a debug-given Mewtwo.
--
-- After every action the game must come back to a free field inside the budget: CB2 overworld,
-- field controls unlocked, no script running. A stretch that never gets there is reported with
-- the script pointer and the live tasks, so a freeze names where it stopped.
--
-- Run via test/overworld/mgba-run.sh test/overworld/lua/OweStressFuzz.lua
-- PW_FUZZ_ACTIONS (default 300 per map) lengthens it; above ~600 also raise PW_MAX_FRAMES.

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "OweStressFuzz")

local CONTEXT_RUNNING = 0
local SPECIES_MEWTWO = 150
local ACTIONS = tonumber(os.getenv("PW_FUZZ_ACTIONS") or "300")
local SETTLE_BUDGET = 3600
local BATTLE_BUDGET = 20000
local DIRS = { "Up", "Down", "Left", "Right" }

-- Maps with visible wild Pokemon and no trainer who battles on sight, so battles are encounters.
-- Rusturf Tunnel is where #398's approach froze. Route 29 (2|75<<8) warp 0 is the Route 46
-- gate, Route 2 (20|37<<8) warp 0 the Viridian Forest north gate, Rusturf Tunnel (4|24<<8)
-- warp 0 its Rustboro mouth.
local ROUTES = {
  { name = "Route29", g = 75, m = 2, w = 0 },
  { name = "Route2", g = 37, m = 20, w = 0 },
  { name = "RusturfTunnel", g = 24, m = 4, w = 0 },
}

local seed = 0x2F6E2B1
local function rand(n)
  seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF
  return (seed >> 8) % n
end

-- An encounter script ends in `waitstate`, and the wild battle returns to the field without
-- resuming it, so the context is left WAITING with the controls unlocked. That is a free field:
-- input runs whenever the context is not RUNNING.
local function hasControl()
  return F.ow() and F.r8(S.sLockFieldControls) == 0
    and F.r8(S.sGlobalScriptContextStatus) ~= CONTEXT_RUNNING
end
local function inBattle() return F.cb2() == (S.BattleMainCB2 & ~1) end

local function liveTasks()
  local t = {}
  for j = 0, 15 do
    local b = S.gTasks + j * 40
    if F.r8(b + 4) ~= 0 then t[#t + 1] = string.format("%08X", F.r32(b)) end
  end
  return table.concat(t, ",")
end

local stats = { battles = 0, approaches = 0, maps = {} }

local function settle(tag)
  local battled, approached = false, false
  -- Battle frames get their own, larger budget; the field budget is what catches a freeze.
  for f = 1, SETTLE_BUDGET + BATTLE_BUDGET do
    if not inBattle() and f > SETTLE_BUDGET and not battled then break end
    if inBattle() then
      battled = true
      -- How a battle is won is not under test. A level 100 Mewtwo's first move is Mist, so aim at
      -- the second, Psystrike, and keep its 10 PP from running out over a long fuzz.
      F.w8(S.gMoveSelectionCursor, 1)
      F.w8(S.gBattleMons + S.BattlePokemon.pp + 1, 10)
      if f % 10 == 0 then F.press(f % 70 == 0 and "B" or "A", 2) else F.idle(1) end
    elseif F.ow() then
      -- One frame of control is enough: the next action is the player's input on that frame. A
      -- player who waits in a crowd gets walked into again, which is play, not a freeze.
      if hasControl() then
        if battled then stats.battles = stats.battles + 1 end
        if approached then stats.approaches = stats.approaches + 1 end
        return true
      end
      for j = 0, 15 do
        local b = S.gTasks + j * 40
        if F.r8(b + 4) ~= 0 and (F.r32(b) & ~1) == (S.Task_OWEApproachForBattle & ~1) then approached = true end
      end
      if f % 20 == 0 then F.press("B", 2) else F.idle(1) end
    else
      if f % 20 == 0 then F.press("B", 2) else F.idle(1) end
    end
    if f % 120 == 0 and F.reportCrash(tag) then return false, "crash screen" end
  end
  return false, string.format("cb2=%08X lock=%d script=%d pc=%08X tasks=%s at %d/%d (%d,%d)",
    F.cb2(), F.r8(S.sLockFieldControls), F.r8(S.sGlobalScriptContextStatus),
    F.r32(S.sGlobalScriptContext + 8), liveTasks(), F.grp(), F.mapn(), select(1, F.pos()), select(2, F.pos()))
end

local function act(k)
  F.w8(S.sOWESpawnCountdown, 0)
  local r = rand(20)
  if r < 11 then
    F.press(DIRS[rand(4) + 1], 16 * (1 + rand(3)))
  elseif r < 14 then
    local d = DIRS[rand(4) + 1]
    for _ = 1, 16 * (1 + rand(3)) do joypad.set({ [d] = true, B = true }); emu.frameadvance() end
  elseif r < 16 then
    F.press("Start", 2); F.idle(20 + rand(40)); F.press("B", 2); F.idle(20)
  elseif r < 18 then
    F.press("A", 2); F.idle(10)
  else
    F.idle(30 + rand(90))
  end
  joypad.set({})
  return settle("act" .. k)
end

-- Debug Give X > Pokemon (Basic): ScriptGiveMon with the player as OT. The debug Set Party carries
-- another OT, so obedience reads its level 100 against a badge-less cap and it naps every turn.
local function task(fn)
  for j = 0, 15 do
    local t = S.gTasks + j * 40
    if F.r8(t + 4) ~= 0 and (F.r32(t) & ~1) == (fn & ~1) then return t end
  end
end
local function giveMon(species, level)
  F.dbg(); F.idle(30)
  for _ = 1, 3 do F.press("Down", 3); F.idle(16) end
  F.press("A", 3); F.idle(50)
  F.press("Down", 3); F.idle(16)
  F.press("A", 3); F.idle(80)
  for _, step in ipairs({ { S.DebugAction_Give_Pokemon_SelectId, species },
                          { S.DebugAction_Give_Pokemon_SelectLevel, level } }) do
    local t = task(step[1])
    if t then F.w16(t + 8 + 6, step[2]); F.idle(4); F.press("A", 3); F.idle(40) end
  end
  for _ = 1, 8 do F.press("B", 2); F.idle(20) end
  return F.r8(S.gPartiesCount)
end

local function d(n) return (n // 100) % 10, (n // 10) % 10, n % 10 end

-- Gen 8+ obedience reads the met level of a Pokemon the player caught. Lower it to 5 the way the
-- campaign harness does (johto-playthrough/nav.lua N.setMetLevel): substruct 3, encrypted with
-- personality ^ otId, checksum adjusted.
local SUB3 = { 3, 2, 3, 2, 1, 1, 3, 2, 3, 2, 1, 1, 3, 2, 3, 2, 1, 1, 0, 0, 0, 0, 0, 0 }
local function setMetLevel(slot, lvl)
  local b = S.gParties + slot * S.Pokemon.size
  local pid, otid = F.r32(b), F.r32(b + 4)
  local key = pid ~ otid
  local addr = b + 32 + 12 * SUB3[(pid % 24) + 1]
  local old = F.r32(addr) ~ key
  local new = (old & ~(0x7F << 16)) | ((lvl & 0x7F) << 16)
  local function halves(v) return (v & 0xFFFF) + (v >> 16) end
  F.w32(addr, new ~ key)
  F.w16(b + 28, (F.r16(b + 28) - halves(old) + halves(new)) & 0xFFFF)
end

F.run(function()
  if not F.boot(100) then F.check("boot to the hub", false); F.finish(); return end
  F.check("debug Give gave a level 100 Mewtwo", giveMon(SPECIES_MEWTWO, 100) == 1)
  setMetLevel(0, 5)
  for _, r in ipairs(ROUTES) do
    local gh, gt, go = d(r.g)
    local mh, mt, mo = d(r.m)
    local wh, wt, wo = d(r.w)
    local warped = F.warpTo(gh, gt, go, mh, mt, mo, wh, wt, wo, r.g, r.m, r.name)
    F.check("warp to " .. r.name, warped)
    if warped then
      local ok, why = settle(r.name .. "_arrive")
      local failed
      for k = 1, (ok and ACTIONS or 0) do
        stats.maps[F.grp() * 256 + F.mapn()] = true
        ok, why = act(r.name .. k)
        if not ok then failed = k; break end
      end
      F.check(r.name .. ": every action returned to a free field", ok,
        failed and string.format("action %d: %s", failed, why) or tostring(why or ""))
      if not ok then F.shot(r.name .. "_stuck"); break end
    end
  end
  local nmaps = 0
  for _ in pairs(stats.maps) do nmaps = nmaps + 1 end
  F.L(string.format("  stats: battles=%d approaches=%d maps=%d", stats.battles, stats.approaches, nmaps))
  F.check("the fuzz reached battles with visible wild Pokemon", stats.battles > 0, "battles=" .. stats.battles)
  F.finish()
end)
