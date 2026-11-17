-- A visible wild Pokemon that touches the player starts its battle within a bounded time.
--
-- InteractWithOverworldWildEncounter locks the field, walks the encounter up to the player
-- (Task_OWEApproachForBattle, ended after OWE_APPROACH_MAX_STALLED_STEPS steps that get no closer),
-- shows the exclamation mark, plays the cry and starts the battle. The player cannot move for any
-- of it, so the suite times each contact from the script's first frame to the frame the battle
-- transition takes the overworld callback, and fails any that takes longer than CONTACT_BUDGET.
-- OweStressFuzz.lua only notices a field that stays locked past its 3600-frame settle budget.
--
-- Maps: Pokemon Tower 3F and 5F (channelers, ghost battles, stairs to the next floor), Hoenn
-- Victory Road 1F (raised walkways on another elevation, trainers) and Granite Cave 1F (narrow
-- corridors). A debug-given level 100 Mewtwo leads, so its follower is out. The spawn countdown is
-- zeroed before every action so all encounter slots stay filled. A fixed pseudo-random sequence
-- walks, runs, walks at the nearest encounter, waits for encounters to come, presses A and opens the
-- Start menu; stairs it walks onto are taken. Wild battles are run from, trainer battles are won.
--
-- An encounter script ends in `waitstate`, and the wild battle returns to the field without resuming
-- it, so the context stays WAITING at the script's `end` with the controls unlocked. That is a free
-- field, and the suite asserts it: after each wild battle the player walks.
--
-- Run via test/overworld/mgba-run.sh test/overworld/lua/OweApproachLatency.lua
-- --env PW_LATENCY_ACTIONS=<n> (default 250 per map) lengthens it; --env PW_LATENCY_SEED=<n> reseeds it.

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "OweApproachLatency")

local CONTEXT_RUNNING, CONTEXT_WAITING, CONTEXT_SHUTDOWN = 0, 1, 2
local SPECIES_MEWTWO = 150
local ACTIONS = tonumber(os.getenv("PW_LATENCY_ACTIONS") or "250")
local CONTACT_BUDGET = 600
local SETTLE_BUDGET = 3600
local BATTLE_BUDGET = 20000
local BATTLE_TYPE_TRAINER = 1 << 3
local ACTION_FIGHT, ACTION_RUN = 0, 3
local TRAINER_TYPE_OW_WILD_ENCOUNTER = 0xFF
local DIRS = { "Up", "Down", "Left", "Right" }

local MAPS = {
  { name = "PokemonTower3F", g = 35, m = 90, w = 0 },
  { name = "PokemonTower5F", g = 35, m = 92, w = 0 },
  { name = "VictoryRoad1F", g = 24, m = 43, w = 0 },
  { name = "GraniteCave1F", g = 24, m = 7, w = 0 },
}

local seed = tonumber(os.getenv("PW_LATENCY_SEED") or "") or 0x51A7C0DE
local function rand(n)
  seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF
  return (seed >> 8) % n
end

local function task(fn)
  for j = 0, 15 do
    local t = S.gTasks + j * 40
    if F.r8(t + 4) ~= 0 and (F.r32(t) & ~1) == (fn & ~1) then return t end
  end
end
local function liveTasks()
  local t = {}
  for j = 0, 15 do
    local b = S.gTasks + j * 40
    if F.r8(b + 4) ~= 0 then t[#t + 1] = string.format("%08X", F.r32(b)) end
  end
  return table.concat(t, ",")
end

local function inBattle() return F.cb2() == (S.BattleMainCB2 & ~1) end
local function ctxStatus() return F.r8(S.sGlobalScriptContextStatus) end
local function scriptOffset() return F.r32(S.sGlobalScriptContext + 8) - S.InteractWithOverworldWildEncounter end
local function hasControl()
  return F.ow() and F.r8(S.sLockFieldControls) == 0 and ctxStatus() ~= CONTEXT_RUNNING
end

-- Per-frame contact timer, run from the frame hook so no wait loop can miss a frame.
local frame = 0
local contact = nil
local stats = { contacts = 0, battles = 0, approaches = 0, blocked = 0, stallEnds = 0, noBattle = 0,
  latencies = {}, slow = {}, maps = {} }

local function closeContact(how)
  local c = contact
  contact = nil
  local frames = frame - c.start
  if how == "battle" then
    stats.battles = stats.battles + 1
    stats.latencies[#stats.latencies + 1] = frames
  else
    stats.noBattle = stats.noBattle + 1
  end
  if c.approach then stats.approaches = stats.approaches + 1 end
  if c.maxStall > 0 then stats.blocked = stats.blocked + 1 end
  if c.stallEnd then stats.stallEnds = stats.stallEnds + 1 end
  if frames > CONTACT_BUDGET then
    stats.slow[#stats.slow + 1] = string.format("%s: %d frames to %s (worst at +%d: %s)", c.where, frames, how,
      c.worstOffset, c.worstState)
  end
end

-- The encounter script holds the field lock from its first command to its battle. Once the battle
-- returns, the context is left pointing at the script's closing `end`, so a later lock taken by a
-- menu or a warp must not read as a contact.
local SCRIPT_END = S.InteractWithOverworldWildEncounter_NoParty - S.InteractWithOverworldWildEncounter - 1
local function inEncounterScript()
  local off = scriptOffset()
  return F.ow() and F.r8(S.sLockFieldControls) ~= 0 and ctxStatus() ~= CONTEXT_SHUTDOWN
    and off >= 0 and off < SCRIPT_END
end

local function watch()
  frame = frame + 1
  if contact then
    if not F.ow() then closeContact(F.r8(S.sLockFieldControls) ~= 0 and "battle" or "menu"); return end
    if not inEncounterScript() then closeContact("no battle"); return end
    local t = task(S.Task_OWEApproachForBattle)
    if t then
      contact.approach = true
      local stall = F.rs16(t + 12)
      if stall > contact.maxStall then contact.maxStall = stall end
      if stall > 8 then contact.stallEnd = true end
    end
    if frame - contact.start == CONTACT_BUDGET then
      contact.worstOffset = scriptOffset()
      contact.worstState = string.format("ctx=%d tasks=%s", ctxStatus(), liveTasks())
    end
    return
  end
  if inEncounterScript() then
    stats.contacts = stats.contacts + 1
    local x, y = F.pos()
    contact = { start = frame, maxStall = 0, approach = false, stallEnd = false, worstOffset = -1,
      worstState = "", where = string.format("%d/%d (%d,%d)", F.grp(), F.mapn(), x, y) }
  end
end
local rawAdvance = emu.frameadvance
emu.frameadvance = function() rawAdvance(); watch() end

local function isAction()
  local c = F.r32(S.gBattlerControllerFuncs) & ~1
  for _, p in ipairs(S.ActionInputFunctions) do if c == (p & ~1) then return true end end
  return false
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

local walkChecks, walkFails = 0, {}

-- After a wild battle the context waits at the script's end; the player must still walk.
local function walksAfterWildBattle(tag)
  for _ = 1, 600 do if hasControl() then break end; F.idle(1) end
  if not hasControl() or ctxStatus() ~= CONTEXT_WAITING then return end
  local x0, y0 = F.pos()
  local moved = false
  for _, d in ipairs(DIRS) do
    if F.step(d) then moved = true; break end
    if not hasControl() then return end
  end
  local x1, y1 = F.pos()
  walkChecks = walkChecks + 1
  if not moved and x0 == x1 and y0 == y1 and not inBattle() and ctxStatus() == CONTEXT_WAITING then
    walkFails[#walkFails + 1] = string.format("%s at %d/%d (%d,%d)", tag, F.grp(), F.mapn(), x0, y0)
  end
end

local function settle(tag)
  local battled, wild = false, false
  for f = 1, SETTLE_BUDGET + BATTLE_BUDGET do
    if not inBattle() and f > SETTLE_BUDGET and not battled then break end
    if inBattle() then
      if not battled then wild = (F.battleFlags() & BATTLE_TYPE_TRAINER) == 0 end
      battled = true
      if isAction() then
        F.idle(20)
        if steer(wild and ACTION_RUN or ACTION_FIGHT) then F.press("A", 2) end
        F.idle(20)
      end
      F.w8(S.gMoveSelectionCursor, 1)
      F.w8(S.gBattleMons + S.BattlePokemon.pp + 1, 10)
      if f % 10 == 0 then F.press("A", 2) else F.idle(1) end
    elseif F.ow() and hasControl() then
      if battled and wild then walksAfterWildBattle(tag) end
      return true
    else
      if f % 20 == 0 then F.press("B", 2) else F.idle(1) end
    end
    if f % 120 == 0 and F.reportCrash(tag) then return false, "crash screen" end
  end
  return false, string.format("cb2=%08X lock=%d script=%d pc=IWOE+%d tasks=%s at %d/%d (%d,%d)",
    F.cb2(), F.r8(S.sLockFieldControls), ctxStatus(), scriptOffset(), liveTasks(),
    F.grp(), F.mapn(), select(1, F.pos()), select(2, F.pos()))
end

-- Walk at the nearest encounter, one tile at a time, until something stops the walk.
local function pursue()
  for _ = 1, 8 do
    if not hasControl() then return end
    local px, py = F.pos()
    local best, bx, by
    for i = 0, 15 do
      local o = S.gObjectEvents + i * S.ObjectEvent.stride
      if (F.r8(o) & 1) == 1 and F.r8(o + 7) == TRAINER_TYPE_OW_WILD_ENCOUNTER then
        local x, y = F.rs16(o + S.ObjectEvent.x) - 7, F.rs16(o + S.ObjectEvent.y) - 7
        local dist = math.abs(x - px) + math.abs(y - py)
        if not best or dist < best then best, bx, by = dist, x, y end
      end
    end
    if not best then return end
    local dx, dy = bx - px, by - py
    local dir
    if math.abs(dx) > math.abs(dy) or (math.abs(dx) == math.abs(dy) and rand(2) == 0) then
      dir = dx < 0 and "Left" or "Right"
    else
      dir = dy < 0 and "Up" or "Down"
    end
    if not F.step(dir) then return end
  end
end

local function act(k)
  F.w8(S.sOWESpawnCountdown, 0)
  local r = rand(24)
  if r >= 20 then
    pursue()
  elseif r < 9 then
    F.press(DIRS[rand(4) + 1], 16 * (1 + rand(3)))
  elseif r < 11 then
    local d = DIRS[rand(4) + 1]
    for _ = 1, 16 * (1 + rand(3)) do joypad.set({ [d] = true, B = true }); emu.frameadvance() end
  elseif r < 17 then
    F.idle(60 + rand(180))
  elseif r < 18 then
    F.press("Start", 2); F.idle(20 + rand(40)); F.press("B", 2); F.idle(20)
  else
    F.press("A", 2); F.idle(10)
  end
  joypad.set({})
  return settle("act" .. k)
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

-- Gen 8+ obedience reads the met level of a Pokemon the player caught (see OweStressFuzz.lua).
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

local function percentile(list, p)
  if #list == 0 then return 0 end
  local s = {}
  for i, v in ipairs(list) do s[i] = v end
  table.sort(s)
  return s[math.max(1, math.ceil(#s * p))]
end

F.run(function()
  if not F.boot(100) then F.check("boot to the hub", false); F.finish(); return end
  F.check("debug Give gave a level 100 Mewtwo", giveMon(SPECIES_MEWTWO, 100) == 1)
  setMetLevel(0, 5)
  for _, r in ipairs(MAPS) do
    local gh, gt, go = d(r.g)
    local mh, mt, mo = d(r.m)
    local wh, wt, wo = d(r.w)
    -- An encounter can walk into the player on the frame after the last action settled.
    F.idle(60); settle(r.name .. "_before_warp")
    local warped = F.warpTo(gh, gt, go, mh, mt, mo, wh, wt, wo, r.g, r.m, r.name)
    F.check("warp to " .. r.name, warped)
    if warped then
      local before = stats.contacts
      local ok, why = settle(r.name .. "_arrive")
      local failed
      for k = 1, (ok and ACTIONS or 0) do
        stats.maps[F.grp() * 256 + F.mapn()] = true
        ok, why = act(r.name .. k)
        if not ok then failed = k; break end
      end
      F.check(r.name .. ": every action returned to a free field", ok,
        failed and string.format("action %d: %s", failed, why) or tostring(why or ""))
      F.L(string.format("  %s: %d contacts", r.name, stats.contacts - before))
      if not ok then F.shot(r.name .. "_stuck"); break end
    end
  end
  local nmaps = 0
  for _ in pairs(stats.maps) do nmaps = nmaps + 1 end
  F.L(string.format("  stats: contacts=%d battles=%d approaches=%d blocked=%d stall-ended=%d no-battle=%d maps=%d",
    stats.contacts, stats.battles, stats.approaches, stats.blocked, stats.stallEnds, stats.noBattle, nmaps))
  F.L(string.format("  contact to battle: p50=%d p95=%d max=%d frames", percentile(stats.latencies, 0.5),
    percentile(stats.latencies, 0.95), percentile(stats.latencies, 1)))
  F.check("encounters touched the player and battled", stats.battles >= 20, "battles=" .. stats.battles)
  F.check("every contact reached its battle within " .. CONTACT_BUDGET .. " frames", #stats.slow == 0,
    table.concat(stats.slow, "; "))
  F.check("after each wild battle the player walks", walkChecks > 0 and #walkFails == 0,
    string.format("checked=%d stuck=%s", walkChecks, table.concat(walkFails, "; ")))
  F.finish()
end)
