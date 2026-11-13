-- QoL #7 autosave under adversarial play. The autosave must fire when it should, never fire where
-- the game must not save, survive mashing and resets, and never write a state the player could
-- not have saved by hand.
--
-- Controls first: a fresh game's different-file latch blocks it, a manual save clears the latch and
-- stamps the ten-minute interval, and a due autosave then fires once after a warp. The blocked
-- checks are only meaningful next to those positive controls, and each one also asserts a HARD
-- block: IsAutosaveBlocked() disarms the settle timer on the first field frame, while the
-- warp-exit fade still holds the controls, so a later on-frame cancel cannot pass for it.
--
-- Scenarios: option on/off, the interval and a manual save stamping it, vblankCounter1
-- wraparound, an overworld encounter walking into the player inside the settle window (its
-- script must forfeit the autosave, not delay it past the battle), a step started on the frame
-- the autosave would fire (the autosave must wait for the step and its trigger), Start on that
-- frame, mashing every button across the warp and inside the SAVING window, power cuts on every
-- frame of the flash write and soft resets around it, the flash write failing, a real door walk,
-- Safari Zone, Bug Contest, Battle Pike, Battle Pyramid, Trainer Hill, a live or paused Frontier
-- challenge, region first-visit arrival, flight, an on-frame arrival script, a trainer whose
-- sight covers the warp exit, and a hub gate crossing that boxes the party.
--
-- PW_AUTOSAVE_ONLY=<text> (runner --env) runs the base controls plus the matching scenarios.
--
-- The interval is reached by rewinding sLastAutosaveFrame rather than idling ten emulated minutes.
-- Blocked contexts that need a challenge or a session are entered by setting the same flag the
-- entry script sets (EnterSafariMode, EnterBugContestMode) and warping in with the debug menu.
--
-- Run via test/overworld/mgba-run.sh test/overworld/lua/AutosaveStress.lua <rom>

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "AutosaveStress")

local HUB_GROUP = 100
local USM_ICO_SAVE = 7
local SENTINEL = 0xFFFF
local SAVE_OK, SAVE_ERROR = 1, 0xFF
local NICK = 8
local INTERVAL = 60 * 600          -- AUTOSAVE_MIN_INTERVAL_FRAMES
local SETTLE = 300                 -- AUTOSAVE_SETTLE_FRAMES
local VBLANK1 = S.gMain + 0x20     -- struct Main.vblankCounter1 (include/main.h)
local AUTOSAVE_BIT = 13            -- optionsAutosave in the SaveBlock2 options u16 (global.h)
local CONTEXT_RUNNING = 0          -- src/script.c

local FLAG_SYS_BUG_CONTEST_MODE = 0x948 + 0x21
local FLAG_SYS_SAFARI_MODE = 0x948 + 0x2C
local FLAG_HUB_INTRO_TOUR_DONE = 0xDCF
local VAR_REGION_ARRIVAL = 0x40FD
local MOVE_TACKLE = 33

-- Warp targets as (group, num, warp). Two quiet Dewford houses are the neutral maps.
local HOUSE_A = { 3, 0, 0 }
local HOUSE_B = { 3, 5, 0 }
local HUB_CREST = { HUB_GROUP, 0, 0 }
local SAFARI_SOUTH = { 26, 3, 0 }
local BUG_CONTEST = { 83, 5, 0 }
local PIKE_ROOM = { 26, 36, 0 }
local PYRAMID_TOP = { 26, 27, 0 }
local TRAINER_HILL_1F = { 26, 61, 0 }
-- SS Anne 1F Room 5: the door warp lands the player at (2,2) after the exit walk, inside the
-- four-tile sight line of the trainer at (2,6) facing up.
local SSANNE_ROOM5 = { 35, 16, 0 }

-- ---- RAM helpers -----------------------------------------------------------------------------
local function vblank() return F.r32(VBLANK1) end
local function optAddr() return F.sb2() + S.SaveBlock2.optionsU16 end
local function setAutosave(on)
  local v = F.r16(optAddr())
  if on then v = v | (1 << AUTOSAVE_BIT) else v = v & ~(1 << AUTOSAVE_BIT) end
  F.w16(optAddr(), v)
end
local function autosaveOpt() return (F.r16(optAddr()) >> AUTOSAVE_BIT) & 1 end
local function lastStamp() return F.r32(S.sLastAutosaveFrame) end
local function setStamp(v) F.w32(S.sLastAutosaveFrame, v & 0xFFFFFFFF) end
local function dueNow() setStamp(vblank() - INTERVAL - 10) end
local function timer() return F.r16(S.sAutosaveSettleTimer) end
local function saves() return F.r32(S.gSaveCounter) end
local function locked() return F.r8(S.sLockFieldControls) ~= 0 end
local function scriptRunning() return F.r8(S.sGlobalScriptContextStatus) == CONTEXT_RUNNING end
local function menuOpen() return F.r32(S.sUsmMemory) ~= 0 end
local function flag(id, on)
  local a = F.sb1() + S.SaveBlock1.flags + (id >> 3)
  local v = F.r8(a)
  if on == nil then return (v >> (id & 7)) & 1 end
  if on then v = v | (1 << (id & 7)) else v = v & ~(1 << (id & 7)) end
  F.w8(a, v)
end
local function var(id, value)
  local a = F.sb1() + S.SaveBlock1.vars + (id - 0x4000) * 2
  if value == nil then return F.r16(a) end
  F.w16(a, value)
end
local function autosaveTask()
  for i = 0, S.Task.count - 1 do
    local a = S.gTasks + i * S.Task.stride
    if F.r8(a + S.Task.isActive) ~= 0 and (F.r32(a + S.Task.func) & ~1) == (S.Task_Autosave & ~1) then return a end
  end
  return nil
end
local function saving() return autosaveTask() ~= nil end
local function windowGone(id) return id and F.r8(S.gWindows + id * S.Window.stride + S.Window.bg) == 0xFF end

local function setMoney(v)
  F.w32(F.sb1() + S.SaveBlock1.money, v ~ F.r32(F.sb2() + S.SaveBlock2.encryptionKey))
end
local function partyHash()
  local n = F.r8(S.gPartiesCount)
  local h = n
  for i = 0, n * S.Pokemon.size - 1, 4 do h = (h * 31 + F.r32(S.gParties + i)) & 0xFFFFFFFF end
  return h
end
local function snapshot()
  local x, y = F.pos()
  return { money = F.money(), party = partyHash(), n = F.r8(S.gPartiesCount),
           grp = F.grp(), map = F.mapn(), x = x, y = y }
end
local function fmt(s)
  if not s then return "nil" end
  return string.format("money=%d party=%08X n=%d at %d/%d (%d,%d)", s.money, s.party, s.n, s.grp, s.map, s.x, s.y)
end
local function same(a, b)
  return a.money == b.money and a.party == b.party and a.n == b.n
     and a.grp == b.grp and a.map == b.map and a.x == b.x and a.y == b.y
end
local function mark(k)
  setMoney(20000 + k)
  if F.r8(S.gPartiesCount) > 0 then F.w8(S.gParties + NICK, 0xBB + (k % 26)) end
end

-- Every personality value in the party and the PC, for conservation checks across a boxing.
local function monCensus()
  local seen = {}
  for i = 0, F.r8(S.gPartiesCount) - 1 do
    local p = F.r32(S.gParties + i * S.Pokemon.size)
    seen[p] = (seen[p] or 0) + 1
  end
  local base = F.r32(S.gPokemonStoragePtr) + 4
  for slot = 0, 14 * 30 - 1 do
    local p = F.r32(base + slot * 80)
    if p ~= 0 then seen[p] = (seen[p] or 0) + 1 end
  end
  return seen
end

-- ---- input helpers ---------------------------------------------------------------------------
local function openSave()
  F.press("Start", 2); F.idle(60)
  return F.selectStartIcon(USM_ICO_SAVE)
end

local function manualSave()
  F.w16(S.gSaveAttemptStatus, SENTINEL)
  if not openSave() then return "noicon" end
  for i = 1, 3000 do
    if F.r16(S.gSaveAttemptStatus) ~= SENTINEL then
      F.idle(30)
      for _ = 1, 6 do F.press("B", 2); F.idle(20) end
      return F.r16(S.gSaveAttemptStatus) == SAVE_OK and "done" or "error"
    end
    if i % 20 == 1 then joypad.set({ A = true }) else joypad.set({}) end
    emu.frameadvance()
  end
  return "timeout"
end

local function softReset(frames)
  for _ = 1, frames or 8 do
    joypad.set({ A = true, B = true, Start = true, Select = true }); emu.frameadvance()
  end
  joypad.set({})
end

local function reboot(tag)
  F.idle(60)
  local ok = F.boot(nil, true)
  F.idle(60)
  if F.reportCrash(tag) then return false end
  return ok
end

local function verifyLoad(tag, old, new)
  local status = F.r8(S.gSaveFileStatus)
  local s = snapshot()
  local which = (old and same(s, old)) and "old" or ((new and same(s, new)) and "new" or "neither")
  F.L(string.format("  [%s] status=%d loaded %s -> %s", tag, status, fmt(s), which))
  F.check(tag .. ": the save loaded", status == SAVE_OK or status == SAVE_ERROR, "status=" .. status)
  F.check(tag .. ": the file is the old or the new save", which ~= "neither",
    "loaded " .. fmt(s) .. " old " .. fmt(old) .. " new " .. fmt(new))
  return which, s
end

-- lib's ensureFree steps Left first; try every direction and step back.
local BACK = { Right = "Left", Left = "Right", Down = "Up", Up = "Down" }
local function free()
  local x0, y0 = F.pos()
  for _, dir in ipairs({ "Right", "Left", "Down", "Up" }) do
    if F.step(dir) then
      F.step(BACK[dir])
      local x, y = F.pos()
      return x == x0 and y == y0
    end
  end
  return false
end

-- Back out of anything a mash opened: B mostly, A to advance text.
local function recover(tag, budget)
  for i = 1, budget or 3000 do
    if F.reportCrash(tag) then return false end
    if F.ow() and not saving() and i % 90 == 0 and free() then return true end
    local p = i % 24
    if p < 2 then joypad.set({ B = true }) elseif p >= 12 and p < 14 then joypad.set({ A = true }) else joypad.set({}) end
    emu.frameadvance()
  end
  return F.ow() and free()
end

local function giveMon(h, t, o)
  F.dbg(); F.sel(3); F.sel(1); F.idle(20)
  F.spin(h, t, o); F.idle(20); F.spin(0, 2, 0); F.idle(60); F.bOut(4)
end

-- Debug warp through the (group, num, warp) spinners. beforeGo runs just before the final A
-- press, so a suite can poke RAM with no debug-menu frames in between.
local function digits(n) return n // 100, (n // 10) % 10, n % 10 end
local function startWarp(dest, beforeGo)
  F.dbg(); F.sel(0); F.sel(1); F.idle(20)
  F.spin(digits(dest[1])); F.spin(digits(dest[2]))
  local h, t, o = digits(dest[3])
  F.press("Right", 2); F.idle(8); F.press("Right", 2); F.idle(8)
  for _ = 1, 6 do F.press("Down", 2); F.idle(8) end
  for _ = 1, h do F.press("Up", 2); F.idle(8) end
  F.press("Left", 2); F.idle(8); for _ = 1, t do F.press("Up", 2); F.idle(8) end
  F.press("Left", 2); F.idle(8); for _ = 1, o do F.press("Up", 2); F.idle(8) end
  if beforeGo then beforeGo() end
  F.press("A", 2)
end

-- Warp and watch the field for `frames`. Per-frame bookkeeping records what the autosave did:
-- saves written, SAVING tasks started, whether the settle timer was disarmed before it ever
-- ticked (a hard block), the state at the frame the task appeared, and
-- anything that must never coincide with a live SAVING window.
local function warpWatch(tag, dest, opts)
  opts = opts or {}
  local c0 = saves()
  startWarp(dest, opts.beforeGo)
  local r = { saves = 0, tasks = 0, armed = false, hardBlock = false, menuDuringTask = false,
              scriptDuringTask = false, maxTimer = 0, crash = false, landed = false }
  local wasTask = false
  local v0 = vblank()
  for i = 1, opts.frames or 600 do
    if opts.input then opts.input(i, r) else joypad.set({}) end
    emu.frameadvance()
    if F.reportCrash(tag) then r.crash = true; break end
    local t = timer()
    local onMap = F.grp() == dest[1] and F.mapn() == dest[2]
    if onMap and F.ow() then r.landed = true end
    if t > 0 then r.armed = true end
    if t > 0 and t < SETTLE then r.sawTick = true end
    if t > r.maxTimer then r.maxTimer = t end
    if opts.onFrame then opts.onFrame(i, r) end
    local task = autosaveTask()
    if task then
      if not wasTask then
        r.tasks = r.tasks + 1
        r.taskAt = i
        r.windowId = F.r16(task + S.Task.data)
        r.atTask = snapshot()
        if opts.onTask then opts.onTask(i, r) end
      end
      if menuOpen() then r.menuDuringTask = true end
      if scriptRunning() then r.scriptDuringTask = true end
    elseif wasTask then
      r.taskEndAt = i
      r.lockAfterTask = locked()
      r.windowCleared = windowGone(r.windowId)
    end
    wasTask = task ~= nil
    r.saves = saves() - c0
  end
  -- A hard block disarms the timer on the first field frame: it goes from SETTLE straight to 0,
  -- never ticking. A later cancel (on-frame script, menu) first ticks it down during the fade.
  r.hardBlock = r.armed and not r.sawTick and timer() == 0
  r.vblankAdvanced = vblank() ~= v0
  r.endLocked = locked()
  F.L(string.format("  %s: saves=%d tasks=%d taskAt=%s hardBlock=%s maxTimer=%d landed=%s at %d/%d",
    tag, r.saves, r.tasks, tostring(r.taskAt), tostring(r.hardBlock), r.maxTimer, tostring(r.landed), F.grp(), F.mapn()))
  return r
end

-- A neutral warp with the autosave held off (option off), to reposition between scenarios.
local function reposition(dest)
  local on = autosaveOpt() == 1
  setAutosave(false)
  startWarp(dest)
  F.idle(240)
  if not F.ensureFree() then F.dismiss(10) end
  if on then setAutosave(true) end
end

-- The full "fired cleanly" bar for one due autosave.
local function checkFired(tag, r)
  F.check(tag .. ": exactly one autosave", r.saves == 1 and r.tasks == 1, string.format("saves=%d tasks=%d", r.saves, r.tasks))
  F.check(tag .. ": the SAVING window closed and field controls unlocked",
    r.taskEndAt ~= nil and r.lockAfterTask == false and r.windowCleared == true and not saving(),
    string.format("taskEnd=%s lock=%s window=%s", tostring(r.taskEndAt), tostring(r.lockAfterTask), tostring(r.windowCleared)))
  F.check(tag .. ": no Start menu or script ran over the SAVING window", not r.menuDuringTask and not r.scriptDuringTask)
end

local function checkBlocked(tag, r)
  F.check(tag .. ": landed on the target map", r.landed)
  F.check(tag .. ": no autosave", r.saves == 0 and r.tasks == 0, string.format("saves=%d tasks=%d", r.saves, r.tasks))
  F.check(tag .. ": hard-blocked during the warp-exit fade", r.hardBlock, "maxTimer=" .. r.maxTimer)
end

-- ---- battle helpers (trainer scenario) -------------------------------------------------------
local function inBattle() return F.cb2() == (S.BattleMainCB2 & ~1) end
local function assistBattle(i)
  for b = 0, F.battlers() - 1 do
    local a = S.gBattleMons + b * S.BattlePokemon.size
    local hp = F.r16(a + S.BattlePokemon.hp)
    -- Opponents sit at 1 HP and the player's first move slot is Tackle, so the pure-A driver's
    -- first move always ends the opponent (a lead whose first move does no damage, or a sleeping
    -- lead, would otherwise stall it forever).
    if b % 2 == 1 and hp > 1 then F.w16(a + S.BattlePokemon.hp, 1) end
    if b % 2 == 0 and hp > 0 then
      F.w16(a + S.BattlePokemon.hp, F.r16(a + S.BattlePokemon.maxHP))
      F.w32(a + S.BattlePokemon.status1, 0)
      F.w16(a + S.BattlePokemon.moves, MOVE_TACKLE)
      F.w8(a + S.BattlePokemon.pp, 35)
    end
  end
end

-- ---- scenarios -------------------------------------------------------------------------------
local saved -- snapshot of what the save file currently holds

local function scenarioLatchAndBasic()
  -- A fresh new game sets gDifferentSaveFile: no autosave may write over another file before the
  -- manual overwrite confirmation.
  F.check("fresh game: the different-file latch is set", F.r8(S.gDifferentSaveFile) == 1)
  setAutosave(true)
  dueNow()
  local r = warpWatch("different-file latch", HOUSE_A)
  checkBlocked("different-file latch", r)
  if not F.ensureFree() then F.dismiss(10) end

  -- A manual save clears the latch and stamps the interval (Autosave_MarkSaved).
  mark(1)
  local before = vblank()
  local st = manualSave()
  F.check("manual save completed", st == "done", st)
  F.check("manual save cleared the different-file latch", F.r8(S.gDifferentSaveFile) == 0)
  local stamp = lastStamp()
  F.check("manual save stamped the autosave interval", (stamp - before) & 0xFFFFFFFF < 3000,
    string.format("stamp=%d before=%d now=%d", stamp, before, vblank()))
  saved = snapshot()
  r = warpWatch("manual save stamps the interval", HOUSE_B)
  checkBlocked("manual save stamps the interval", r)
  if not F.ensureFree() then F.dismiss(10) end

  -- Control: due, option on, warp, idle. It fires once and hands the field back.
  mark(2)
  dueNow()
  r = warpWatch("basic autosave", HOUSE_A)
  checkFired("basic autosave", r)
  F.check("basic autosave: the player can walk afterwards", free())
  F.check("basic autosave: the interval stamp moved to the autosave", (vblank() - lastStamp()) & 0xFFFFFFFF < 2000)
  local new = r.atTask
  if new then F.L("  autosaved " .. fmt(new)) end

  -- Two warps inside ten minutes: the second one must not save again.
  r = warpWatch("second warp inside the interval", HOUSE_B)
  checkBlocked("second warp inside the interval", r)

  -- Reboot and Continue: the file is the autosave at the post-warp spot, option still on.
  softReset()
  if reboot("continue after the basic autosave") then
    local which = verifyLoad("continue after the basic autosave", saved, new)
    F.check("continue lands at the post-warp spot of the autosave", which == "new", which)
    F.check("the autosave option survived the reboot", autosaveOpt() == 1)
    if which == "new" then saved = new end
  end
  if not F.ensureFree() then F.dismiss(10) end
end

local function scenarioOptionOff()
  setAutosave(false)
  dueNow()
  local r = warpWatch("option off", HOUSE_B)
  checkBlocked("option off", r)
  setAutosave(true)
  if not F.ensureFree() then F.dismiss(10) end
end

local function scenarioWrap()
  -- Recent stamp just before vblankCounter1 wraps: the warp and settle cross zero, and the
  -- unsigned difference stays small, so nothing may fire.
  local r = warpWatch("wraparound, recent stamp", HOUSE_A, { beforeGo = function()
    F.w32(VBLANK1, 0xFFFFFFFF - 40)
    setStamp(0xFFFFFFFF - 200)
  end })
  F.check("wraparound, recent stamp: the counter wrapped during the warp", vblank() < 0x10000, string.format("vblank=%08X", vblank()))
  checkBlocked("wraparound, recent stamp", r)
  if not F.ensureFree() then F.dismiss(10) end

  -- Due stamp on the far side of the wrap: the autosave must fire once, and stamp a post-wrap value.
  r = warpWatch("wraparound, due stamp", HOUSE_B, { beforeGo = function()
    F.w32(VBLANK1, 0xFFFFFFFF - 40)
    setStamp(0xFFFFFFFF - 40 - INTERVAL - 10)
  end })
  checkFired("wraparound, due stamp", r)
  F.check("wraparound, due stamp: the new stamp is post-wrap", lastStamp() < 0x10000, string.format("stamp=%08X", lastStamp()))
  if r.atTask and r.saves == 1 then saved = r.atTask end
  if not F.ensureFree() then F.dismiss(10) end

  -- And the interval still holds after the wrap.
  r = warpWatch("wraparound, interval after the wrap", HOUSE_A)
  checkBlocked("wraparound, interval after the wrap", r)
  if not F.ensureFree() then F.dismiss(10) end
end

-- A step that starts on the frame the autosave would fire. ProcessPlayerFieldInput runs before
-- UpdateAutosave in DoCB1_Overworld, so the step's trigger can only be evaluated when the step
-- ends. The autosave must not save the player mid-step (it would write the destination tile with
-- its trigger never run, and a reboot then stands the player past it). The hub crest's (16,5)
-- coord trigger is the step trigger: arm it after the load (clear FLAG_HUB_INTRO_TOUR_DONE once
-- ON_TRANSITION has run, so the ON_FRAME tour stays disarmed) and hold Down through the unlock.
local function scenarioStepAtUnlock()
  reposition(HOUSE_A)
  dueNow()
  local cleared = false
  local r = warpWatch("step at unlock", HUB_CREST, { frames = 500, input = function(i)
    if i < 300 then joypad.set({ Down = true }) else joypad.set({}) end
  end, onFrame = function()
    local x, y = F.pos()
    local t = timer()
    if not cleared and F.grp() == HUB_GROUP and x == 16 and y == 4 and t > 0 and t < SETTLE then
      flag(FLAG_HUB_INTRO_TOUR_DONE, false); cleared = true
    end
  end })
  local tourRan = scriptRunning() or flag(FLAG_HUB_INTRO_TOUR_DONE) == 1 or select(2, F.pos()) == 4
  F.L(string.format("  step at unlock: cleared=%s pos=(%d,%d) tour=%s", tostring(cleared), select(1, F.pos()), select(2, F.pos()), tostring(tourRan)))
  F.check("step at unlock: the coord trigger was armed after the load", cleared)
  F.check("step at unlock: no autosave of a step whose trigger has not run",
    not (r.saves > 0 and r.atTask and r.atTask.x == 16 and r.atTask.y == 5),
    r.atTask and fmt(r.atTask) or "no save")
  F.check("step at unlock: the step's coord trigger ran", tourRan)
  -- Close the tour (B declines) and leave the hub.
  F.dismiss(20)
  flag(FLAG_HUB_INTRO_TOUR_DONE, true)
  if r.saves > 0 and r.atTask then saved = r.atTask end
  if not F.ensureFree() then F.dismiss(10) end

  -- Walking without a break after a warp: the autosave waits until the player stops, and the
  -- position it writes is where the player stands.
  reposition(HOUSE_B)
  dueNow()
  local stopAt
  r = warpWatch("walk through the settle window", HUB_CREST, { frames = 500, input = function(i)
    if F.ow() and not locked() and not stopAt and i < 400 then
      joypad.set({ Down = true })
    else
      joypad.set({})
    end
  end, onFrame = function(i)
    local _, y = F.pos()
    if not stopAt and F.grp() == HUB_GROUP and y >= 7 then stopAt = i end
  end })
  local x, y = F.pos()
  F.check("walk through the settle window: one autosave", r.saves == 1, "saves=" .. r.saves)
  F.check("walk through the settle window: the autosave waited for the walk to stop",
    r.taskAt ~= nil and stopAt ~= nil and r.taskAt >= stopAt,
    string.format("taskAt=%s stopAt=%s", tostring(r.taskAt), tostring(stopAt)))
  F.check("walk through the settle window: the saved tile is where the player stands",
    r.atTask ~= nil and r.atTask.x == x and r.atTask.y == y,
    string.format("saved %s now (%d,%d)", fmt(r.atTask), x, y))
  if r.saves == 1 and r.atTask then saved = r.atTask end
  if not F.ensureFree() then F.dismiss(10) end
end

-- Seeded mash, never the A+B+Start+Select soft-reset chord and never R (R+Start is the debug menu).
local seed = 0x5A7E
local function rnd()
  seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF
  return seed >> 8
end
local DIRS = { "Up", "Down", "Left", "Right" }
local function mashKeys(w)
  local t = {}
  for _, b in ipairs({ "A", "B", "Start", "Select" }) do
    if rnd() % 100 < w[b] then t[b] = true end
  end
  if t.A and t.B and t.Start and t.Select then t.Select = nil end
  if rnd() % 100 < w.dir then t[DIRS[rnd() % 4 + 1]] = true end
  joypad.set(t)
end

local function scenarioMash()
  -- Start on the very frame the autosave would fire: the first field frame after the warp-exit
  -- fade unlocks the controls. ProcessPlayerFieldInput runs first and opens the menu, so the
  -- autosave must stand down, and stay down once the menu closes.
  do
    local tag = "Start on the firing frame"
    if not F.ensureFree() then F.dismiss(10) end
    dueNow()
    local phase, menuSeen = "wait", false
    local r = warpWatch(tag, HOUSE_A, { frames = 120, input = function()
      if phase == "press" then joypad.set({ Start = true }); phase = "held" else joypad.set({}) end
    end, onFrame = function(_, r)
      if phase == "wait" and r.landed and r.armed and not locked() then phase = "press" end
      if menuOpen() then menuSeen = true end
    end })
    F.check(tag .. ": the Start press landed on the first unlocked frame", phase == "held")
    F.check(tag .. ": the Start menu opened", menuSeen)
    F.check(tag .. ": no autosave under the menu", r.saves == 0 and r.tasks == 0, "saves=" .. r.saves)
    local c0 = saves()
    for _ = 1, 6 do F.press("B", 2); F.idle(20) end
    F.idle(SETTLE + 60)
    F.check(tag .. ": no autosave after the menu closed", saves() == c0 and not saving(), "saves=" .. (saves() - c0))
    F.check(tag .. ": the player can walk afterwards", free() or recover(tag))
  end

  -- Mash across the warp and the settle window. The mash can legitimately open the Start menu
  -- (cancelling the autosave) or even save from it; what it must never do is crash, stack a
  -- second SAVING task, open a menu or script over a live one, or leave the field stuck.
  for round = 1, 4 do
    local tag = "mash across the warp " .. round
    if not F.ensureFree() then recover(tag) end
    dueNow()
    local r = warpWatch(tag, (round % 2 == 1) and HOUSE_A or HOUSE_B, { frames = 500, input = function()
      mashKeys({ A = 35, B = 45, Start = 25, Select = 15, dir = 50 })
    end })
    joypad.set({})
    F.check(tag .. ": no crash and the game kept running", not r.crash and r.vblankAdvanced)
    F.check(tag .. ": at most one SAVING task", r.tasks <= 1, "tasks=" .. r.tasks)
    F.check(tag .. ": no Start menu or script over the SAVING window", not r.menuDuringTask and not r.scriptDuringTask)
    if r.tasks == 1 and r.taskEndAt then
      F.check(tag .. ": the SAVING window released the controls", r.lockAfterTask == false and r.windowCleared == true)
    end
    F.check(tag .. ": the field recovers", recover(tag))
    F.check(tag .. ": the autosave option is untouched", autosaveOpt() == 1)
    setAutosave(true)
  end

  -- Mash every button inside the SAVING window itself: idle until the task starts, then press
  -- a fresh random combination every frame (Start toggled so every other frame is a new press)
  -- until it ends.
  for round = 1, 3 do
    local tag = "mash inside the SAVING window " .. round
    if not F.ensureFree() then recover(tag) end
    dueNow()
    local inTask = false
    local n = 0
    local r = warpWatch(tag, (round % 2 == 1) and HOUSE_B or HOUSE_A, { frames = 600, input = function()
      if inTask then
        n = n + 1
        mashKeys({ A = 60, B = 60, Start = 0, Select = 50, dir = 70 })
        if n % 2 == 1 then
          local keys = { Start = true, A = rnd() % 2 == 0, B = rnd() % 2 == 0 }
          keys[DIRS[rnd() % 4 + 1]] = true
          joypad.set(keys)
        end
      else
        joypad.set({})
      end
    end, onFrame = function()
      inTask = saving()
    end })
    joypad.set({})
    F.L(string.format("  %s: mashed %d frames", tag, n))
    F.check(tag .. ": the mash ran inside the window", n > 30, "frames=" .. n)
    checkFired(tag, r)
    F.idle(2)
    F.check(tag .. ": nothing opened from input pressed during the window", not menuOpen() and not scriptRunning() and not locked())
    if r.saves == 1 and r.atTask then saved = r.atTask end
    F.check(tag .. ": the player can walk afterwards", free() or recover(tag))
  end
end

-- Power cut on every frame of the autosave's flash write, plus soft resets around it.
local function scenarioResets()
  local k = 100
  -- Measure the write with a clean autosave.
  if not F.ensureFree() then F.dismiss(10) end
  k = k + 1; mark(k)
  dueNow()
  F.w16(S.gSaveAttemptStatus, SENTINEL)
  local c0 = saves()
  local span, started = 0, false
  local r = warpWatch("measure the autosave write", HOUSE_A, { onFrame = function()
    local s = saves() ~= c0
    local done = F.r16(S.gSaveAttemptStatus) ~= SENTINEL
    if s and not done then span = span + 1 end
  end })
  F.check("measured autosave completed", r.saves == 1 and F.r16(S.gSaveAttemptStatus) == SAVE_OK)
  F.L("  the autosave flash write spans " .. span .. " frames")
  if r.atTask then saved = r.atTask end
  if not F.ensureFree() then F.dismiss(10) end

  -- The write's length in emulated frames varies with the map's interrupt load, so the late cuts
  -- are anchored on the write's completion (gSaveAttemptStatus set) as well as on its start.
  local offsets = {}
  for o = 0, span + 2, math.max(1, span // 20) do offsets[#offsets + 1] = o end
  for o = math.max(0, span - 3), span + 2 do offsets[#offsets + 1] = o end
  for o = 0, 2 do offsets[#offsets + 1] = "done+" .. o end
  local counts = { old = 0, new = 0, neither = 0 }
  local afterDone = { old = 0, new = 0, neither = 0 }
  local dest = HOUSE_B
  for _, off in ipairs(offsets) do
    k = k + 1; mark(k)
    dueNow()
    local doneOff = type(off) == "string" and tonumber(off:match("%d+$")) or nil
    local tag = doneOff and string.format("power cut %d frames after the autosave write", doneOff)
                         or ("power cut " .. off .. " frames into the autosave write")
    c0 = saves()
    F.w16(S.gSaveAttemptStatus, SENTINEL)
    local seen, sinceDone, cut, new = -1, -1, false, nil
    startWarp(dest)
    for _ = 1, 900 do
      emu.frameadvance()
      if not new and saving() then new = snapshot() end
      if saves() ~= c0 then seen = seen + 1 end
      if F.r16(S.gSaveAttemptStatus) ~= SENTINEL then sinceDone = sinceDone + 1 end
      if (doneOff and sinceDone >= doneOff) or (not doneOff and seen >= off) then
        client.reboot_core(); cut = true; break
      end
    end
    dest = (dest == HOUSE_B) and HOUSE_A or HOUSE_B
    if not cut then F.check(tag .. ": the autosave started", false); break end
    if not reboot(tag) then F.check(tag .. ": rebooted to the field", false); break end
    local which, s = verifyLoad(tag, saved, new)
    counts[which] = counts[which] + 1
    if doneOff then afterDone[which] = afterDone[which] + 1 end
    saved = (which == "new") and new or ((which == "old") and saved or s)
    -- Every reboot zeroes vblankCounter1 and the stamp; dueNow() handles the wrap that implies.
    if not F.ensureFree() then F.dismiss(10) end
  end
  F.check("every power cut once the autosave write completed keeps the new file", afterDone.new == 3,
    string.format("old=%d new=%d", afterDone.old, afterDone.new))
  F.L(string.format("  power cuts: old=%d new=%d neither=%d", counts.old, counts.new, counts.neither))
  F.check("a power cut early in the autosave write keeps the old file", counts.old > 0 or span == 0)
  F.check("a power cut after the autosave write keeps the new file", counts.new > 0)

  -- Soft reset on the SAVING window's first frame, before the write: the old file loads.
  local function softResetRound(tag, when, expect)
    k = k + 1; mark(k)
    dueNow()
    c0 = saves()
    F.w16(S.gSaveAttemptStatus, SENTINEL)
    local new, fired = nil, false
    startWarp(dest)
    dest = (dest == HOUSE_B) and HOUSE_A or HOUSE_B
    for i = 1, 900 do
      emu.frameadvance()
      if not new and saving() then new = snapshot() end
      if new and when(saves() ~= c0, F.r16(S.gSaveAttemptStatus) ~= SENTINEL) then
        -- Hold the chord until the write is over: the main loop only reads it between frames.
        for _ = 1, 1200 do
          joypad.set({ A = true, B = true, Start = true, Select = true }); emu.frameadvance()
          if F.r16(S.gSaveAttemptStatus) ~= SENTINEL or not F.ow() then break end
        end
        local reset = false
        for _ = 1, 40 do
          joypad.set({ A = true, B = true, Start = true, Select = true }); emu.frameadvance()
          if not F.ow() then reset = true end
        end
        joypad.set({})
        F.check(tag .. ": the soft reset fired", reset)
        fired = true; break
      end
    end
    if not fired then F.check(tag .. ": reached the reset point", false); return end
    if reboot(tag) then
      local which = verifyLoad(tag, saved, new)
      if expect then F.check(tag .. ": loads the " .. expect .. " file", which == expect, which) end
      if which == "new" then saved = new end
    end
    if not F.ensureFree() then F.dismiss(10) end
  end
  softResetRound("soft reset as the SAVING window opens", function(started) return not started end, "old")
  softResetRound("soft reset held through the autosave write", function(started) return started end, "new")
  softResetRound("soft reset in the post-save hold", function(_, done) return done end, "new")
end

-- The flash write failing. With gFlashMemoryPresent cleared TrySavingData returns
-- SAVE_STATUS_ERROR without writing, and Task_Autosave must show the error, wait for A, and hand
-- the field back with nothing written.
local function scenarioSaveError()
  if not F.ensureFree() then F.dismiss(10) end
  local shown, presses, errFrames = false, 0, 0
  local r = warpWatch("save error", HOUSE_B, { frames = 900, beforeGo = function()
    dueNow(); F.w32(S.gFlashMemoryPresent, 0)
  end, input = function(i)
    local t = autosaveTask()
    if t and F.rs16(t + S.Task.data + 4) >= 3 then
      errFrames = errFrames + 1
      if errFrames == 30 then F.shot("autosave_error") end
      shown = true
      if i % 20 == 0 then joypad.set({ A = true }); presses = presses + 1 else joypad.set({}) end
    else
      joypad.set({})
    end
  end })
  F.w32(S.gFlashMemoryPresent, 1)
  F.check("save error: one SAVING task, nothing written", r.tasks == 1 and r.saves == 0,
    string.format("tasks=%d saves=%d", r.tasks, r.saves))
  F.check("save error: the error message came up", shown)
  F.check("save error: A dismissed it and the field came back",
    r.taskEndAt ~= nil and r.lockAfterTask == false and not saving() and not locked(),
    string.format("taskEnd=%s lock=%s presses=%d", tostring(r.taskEndAt), tostring(r.lockAfterTask), presses))
  F.check("save error: no Start menu or script over it", not r.menuDuringTask and not r.scriptDuringTask)
  F.check("save error: the player can walk afterwards", free() or recover("save error"))
end

-- A real door: walk onto House A's exit mat and out into Dewford Town. The player is still
-- moving when the warp fires; the autosave must wait for the field, then save where they stand.
local function scenarioDoor()
  reposition(HOUSE_A)
  dueNow()
  local c0 = saves()
  local leftAt, taskAt, atTask
  for i = 1, 900 do
    if F.grp() == HOUSE_A[1] and F.mapn() == HOUSE_A[2] and not leftAt then joypad.set({ Down = true }) else joypad.set({}) end
    emu.frameadvance()
    if F.reportCrash("door") then break end
    if not leftAt and F.grp() ~= HOUSE_A[1] then leftAt = i end
    if not taskAt and saving() then taskAt = i; atTask = snapshot() end
    if taskAt and (i - taskAt == 4 or i - taskAt == 120) then F.shot("autosave_window_" .. (i - taskAt)) end
  end
  local x, y = F.pos()
  F.L(string.format("  door: leftAt=%s taskAt=%s at %d/%d (%d,%d)", tostring(leftAt), tostring(taskAt), F.grp(), F.mapn(), x, y))
  F.check("door: walked out into Dewford Town", leftAt ~= nil and F.grp() == 0, string.format("grp=%d", F.grp()))
  F.check("door: exactly one autosave", saves() - c0 == 1, "saves=" .. (saves() - c0))
  F.check("door: it saved the tile the player stands on", atTask ~= nil and atTask.x == x and atTask.y == y
    and atTask.grp == F.grp() and atTask.map == F.mapn(), fmt(atTask))
  F.check("door: the field came back", not saving() and not locked())
  if atTask and saves() - c0 == 1 then saved = atTask end
end

local function scenarioContexts()
  if not F.ensureFree() then F.dismiss(10) end

  -- Safari Zone: EnterSafariMode sets the flag before the entrance script warps.
  local r = warpWatch("Safari Zone", SAFARI_SOUTH, { beforeGo = function()
    dueNow(); flag(FLAG_SYS_SAFARI_MODE, true); F.w16(S.gSafariZoneStepCounter, 500)
  end })
  checkBlocked("Safari Zone", r)
  flag(FLAG_SYS_SAFARI_MODE, false); F.w16(S.gSafariZoneStepCounter, 0)
  -- Same map without the session flag: it fires, so the flag is what blocked it.
  r = warpWatch("Safari Zone map without a session", SAFARI_SOUTH, { beforeGo = dueNow })
  F.check("Safari Zone map without a session: autosaves", r.saves == 1, "saves=" .. r.saves)
  if r.saves == 1 and r.atTask then saved = r.atTask end
  if not F.ensureFree() then F.dismiss(10) end

  -- Bug-Catching Contest.
  r = warpWatch("Bug Contest", BUG_CONTEST, { beforeGo = function()
    dueNow(); flag(FLAG_SYS_BUG_CONTEST_MODE, true)
  end })
  checkBlocked("Bug Contest", r)
  flag(FLAG_SYS_BUG_CONTEST_MODE, false)
  if not F.ensureFree() then F.dismiss(10) end
  reposition(HOUSE_A)

  -- Region first-visit arrival pending.
  r = warpWatch("region arrival pending", HOUSE_B, { beforeGo = function()
    dueNow(); var(VAR_REGION_ARRIVAL, 1)
  end })
  checkBlocked("region arrival pending", r)
  var(VAR_REGION_ARRIVAL, 0)
  if not F.ensureFree() then F.dismiss(10) end

  -- A live or paused Battle Frontier challenge owns its own save mode.
  for _, c in ipairs({ { "frontier challenge in progress", 1 }, { "frontier challenge paused", 2 } }) do
    r = warpWatch(c[1], HOUSE_A, { beforeGo = function()
      dueNow(); F.w8(F.sb2() + S.SaveBlock2.frontierChallengeStatus, c[2])
    end })
    checkBlocked(c[1], r)
    F.w8(F.sb2() + S.SaveBlock2.frontierChallengeStatus, 0)
    if not F.ensureFree() then F.dismiss(10) end
    reposition(HOUSE_B)
  end

  -- Flight: IsPlayerFlying() during the settle window.
  local poked = false
  r = warpWatch("flying", HOUSE_A, { beforeGo = dueNow, onFrame = function()
    if not poked and F.grp() == HOUSE_A[1] and F.mapn() == HOUSE_A[2] and timer() > 0 and timer() < SETTLE then
      F.w8(S.sFlightActive, 1); poked = true
    end
  end })
  F.w8(S.sFlightActive, 0)
  F.check("flying: flight was set inside the settle window", poked)
  F.check("flying: no autosave", r.saves == 0 and r.tasks == 0, "saves=" .. r.saves)
  if not F.ensureFree() then F.dismiss(10) end

  -- On-frame arrival script: the hub intro tour runs on the first unlocked frame. Declining it
  -- ends the script and frees the field; the forfeited autosave must stay forfeited.
  r = warpWatch("on-frame arrival script", HUB_CREST, { frames = 300, beforeGo = function()
    dueNow(); flag(FLAG_HUB_INTRO_TOUR_DONE, false)
  end })
  F.check("on-frame arrival script: the tour started", scriptRunning() or locked())
  local after = saves()
  F.dismiss(20)
  F.idle(SETTLE + 60)
  F.check("on-frame arrival script: no autosave during or after the script",
    r.saves == 0 and r.tasks == 0 and saves() == after, string.format("saves=%d after=%d", r.saves, saves() - after))
  flag(FLAG_HUB_INTRO_TOUR_DONE, true)
  if not F.ensureFree() then F.dismiss(10) end
  -- Control on the same arrival with the tour done.
  reposition(HOUSE_B)
  r = warpWatch("hub arrival with the tour done", HUB_CREST, { beforeGo = dueNow })
  F.check("hub arrival with the tour done: autosaves", r.saves == 1, "saves=" .. r.saves)
  if r.saves == 1 and r.atTask then saved = r.atTask end
  if not F.ensureFree() then F.dismiss(10) end

  -- Frontier facilities with a map-based block. Entered without a challenge, so only the
  -- autosave's own gate is under test; the hard-block assertion keeps an on-frame script from
  -- standing in for it.
  for _, c in ipairs({ { "Battle Pike", PIKE_ROOM }, { "Battle Pyramid", PYRAMID_TOP }, { "Trainer Hill", TRAINER_HILL_1F } }) do
    r = warpWatch(c[1], c[2], { beforeGo = dueNow })
    checkBlocked(c[1], r)
    F.dismiss(6)
    reposition(HOUSE_A)
  end
end

-- A trainer whose sight covers the warp exit: the spot fires on the first unlocked frame. No
-- autosave before the battle, and none after it either.
local function ensureParty()
  if F.r8(S.gPartiesCount) == 0 then
    giveMon(2, 5, 4)
    giveMon(0, 2, 5)
  end
end

local function scenarioTrainer()
  ensureParty()
  F.check("trainer: party ready", F.r8(S.gPartiesCount) >= 1, "n=" .. F.r8(S.gPartiesCount))
  if not F.ensureFree() then F.dismiss(10) end
  local battled = false
  local r = warpWatch("trainer sight at the warp exit", SSANNE_ROOM5, { frames = 9000, beforeGo = dueNow,
    input = function(i)
      if F.cb2() == (S.CB2_UpdatePartyMenu & ~1) then
        -- Forced switch after a faint: Down to the next Pokemon, A to send it.
        local p = i % 30
        if p == 1 then joypad.set({ Down = true }) elseif p == 16 then joypad.set({ A = true }) else joypad.set({}) end
      elseif battled and not inBattle() and not F.ow() then
        -- A level-up move prompt opened the summary screen: B out, A through the prompts.
        local p = i % 30
        if p == 1 then joypad.set({ B = true }) elseif p == 16 then joypad.set({ A = true }) else joypad.set({}) end
      elseif inBattle() then
        battled = true
        assistBattle(i)
        if i % 12 == 1 then joypad.set({ A = true }) else joypad.set({}) end
      elseif not battled and F.ow() and scriptRunning() and i % 20 == 1 then
        joypad.set({ A = true }) -- the trainer's intro text
      elseif battled and F.ow() and i % 30 == 1 then
        joypad.set({ B = true })
      else
        joypad.set({})
      end
    end })
  F.check("trainer: the battle started from the warp exit", battled)
  F.L(string.format("  trainer: cb2=%08X outcome=%d", F.cb2(), F.outcome()))
  if not F.ow() then F.shot("trainer_not_back") end
  F.check("trainer: back on the field afterwards", F.ow())
  F.check("trainer: no autosave before, during or after the battle", r.saves == 0 and r.tasks == 0,
    string.format("saves=%d tasks=%d", r.saves, r.tasks))
  F.dismiss(10)
end

-- An overworld encounter that walks into the player starts its script from object collision
-- code, not from ProcessPlayerFieldInput, so DoCB1_Overworld's input-side cancel never sees it.
-- Contact on the frame the settle window is armed must forfeit the autosave like any other
-- script; it must not wait the script out and then save after the battle. The window is armed
-- by writing sAutosaveSettleTimer on the step's frame (a warp-exit arming cannot be timed to the
-- contact); the contact, the script and the battle are the game's own code.
local OWE_FIRST, OWE_LAST = 249, 252
local function findOWE()
  for i = 0, 15 do
    local b = S.gObjectEvents + i * S.ObjectEvent.stride
    local id = F.r8(b + S.ObjectEvent.localId)
    if F.r8(b) & 1 == 1 and id >= OWE_FIRST and id <= OWE_LAST then return b end
  end
end
local function placeAt(b, x, y)
  for _, off in ipairs({ S.ObjectEvent.x - 4, S.ObjectEvent.x, S.ObjectEvent.x + 4 }) do
    F.w16(b + off, x + 7); F.w16(b + off + 2, y + 7)
  end
end
local function playerObj() return S.gObjectEvents + F.r8(S.gPlayerAvatar + 5) * S.ObjectEvent.stride end

local function scenarioOweContact()
  if not F.ensureFree() then F.dismiss(10) end
  reposition({ 75, 2, 0 }) -- Route 29
  local owe
  for k = 1, 60 do
    F.w8(S.sOWESpawnCountdown, 0)
    owe = findOWE()
    if owe then break end
    F.step(k % 2 == 0 and "Left" or "Right")
  end
  F.check("encounter contact: a generated encounter spawned", owe ~= nil)
  if not owe then return end
  F.check("encounter contact: on the path below the gate", F.leg(34, 12), string.format("(%d,%d)", F.pos()))
  if F.r16(playerObj() + S.ObjectEvent.facing) & 0xF ~= 1 then F.face("Down") end
  local px, py = F.pos()
  placeAt(owe, px, py + 1)
  F.idle(2)
  setAutosave(true)
  dueNow()
  local c0 = saves()
  local contact = false
  for f = 1, 60 do
    if not locked() and not scriptRunning() then placeAt(owe, px, py + 1) end
    if f == 1 then F.w16(S.sAutosaveSettleTimer, SETTLE) end
    joypad.set({ Down = true }); emu.frameadvance()
    if F.r16(S.gSpecialVar_LastTalked) == F.r8(owe + S.ObjectEvent.localId) and scriptRunning() then contact = true; break end
    if saving() then break end
  end
  joypad.set({})
  F.check("encounter contact: walking into it started the encounter script", contact)
  -- With no Pokemon able to battle the script releases at once (the party is still empty here;
  -- the trainer scenario gives one later). B only: A would talk to the encounter again.
  local back = false
  for f = 1, 3000 do
    if f % 15 == 0 then F.press("B", 2) else F.idle(1) end
    if f > 60 and F.ow() and not locked() and not scriptRunning() then back = true; break end
  end
  F.check("encounter contact: the script ended and handed the field back", back)
  F.idle(SETTLE + 60)
  F.check("encounter contact: no autosave during or after the encounter script", saves() == c0 and not saving(),
    "saves=" .. (saves() - c0))
end

-- Hub gate crossing: the attendant boxes the party (DepositPartyToPC) and warps to the region.
-- Whatever autosave follows must hold each party Pokemon exactly once across party and PC, in RAM
-- and after a reboot.
local function scenarioGate()
  ensureParty()
  reposition(HOUSE_A)
  reposition(HUB_CREST)
  local mons = {}
  for i = 0, F.r8(S.gPartiesCount) - 1 do mons[#mons + 1] = F.r32(S.gParties + i * S.Pokemon.size) end
  F.check("gate: carrying a party", #mons >= 1, "n=" .. #mons)
  if not F.route({ { 16, 4 }, { 11, 4 }, { 11, 3 } }, "gate") then F.check("gate: reached the attendant", false); return end
  F.face("Up")
  dueNow()
  local c0 = saves()
  local boxedAt, taskAt, atTask
  for i = 1, 2400 do
    if not taskAt and (i % 16 == 1) and F.grp() == HUB_GROUP then joypad.set({ A = true }) else joypad.set({}) end
    emu.frameadvance()
    if F.reportCrash("gate") then break end
    if not boxedAt and F.r8(S.gPartiesCount) == 0 then boxedAt = i end
    if not taskAt and saving() then
      taskAt = i
      atTask = monCensus()
    end
    if taskAt and not saving() and i - taskAt > 30 then break end
  end
  local left = F.grp() ~= HUB_GROUP
  F.L(string.format("  gate: boxedAt=%s taskAt=%s at %d/%d saves=%d", tostring(boxedAt), tostring(taskAt), F.grp(), F.mapn(), saves() - c0))
  F.check("gate: the crossing left the hub", left, string.format("grp=%d", F.grp()))
  F.check("gate: the crossing boxed the party", boxedAt ~= nil)
  local function conserved(census)
    for _, p in ipairs(mons) do if census[p] ~= 1 then return false end end
    return true
  end
  if atTask then
    F.check("gate: the autosave's party state holds each Pokemon exactly once", conserved(atTask))
  end
  F.check("gate: RAM holds each Pokemon exactly once after the crossing", conserved(monCensus()))
  local wrote = saves() ~= c0
  F.idle(60)
  softReset()
  if reboot("continue after the gate crossing") then
    F.check("gate: the reloaded file holds each Pokemon exactly once", conserved(monCensus()))
    if wrote then
      F.check("gate: the reloaded file is the post-crossing autosave", F.grp() ~= HUB_GROUP, string.format("grp=%d", F.grp()))
    end
  end
end

F.run(function()
  if not F.boot(HUB_GROUP) then F.check("boot to the hub", false); F.finish(); return end
  -- Instant text keeps the manual save dialog short; SET battle style skips the switch prompt.
  F.w8(F.sb2() + 0x14, (F.r8(F.sb2() + 0x14) & ~7) | 3)
  F.w16(optAddr(), F.r16(optAddr()) | (1 << 9))

  -- PW_AUTOSAVE_ONLY=<text> runs the base controls plus only the scenarios whose name matches.
  local only = os.getenv("PW_AUTOSAVE_ONLY")
  local function want(name) return not only or only == "" or name:find(only, 1, true) end
  scenarioLatchAndBasic()
  -- Generated encounters depend on the in-game hour (the time-of-day encounter table and spawn
  -- checks), so this one runs while the clock still matches the fresh boot the runner pins.
  if want("owe") then scenarioOweContact() end
  if want("optionoff") then scenarioOptionOff() end
  if want("wrap") then scenarioWrap() end
  if want("step") then scenarioStepAtUnlock() end
  if want("mash") then scenarioMash() end
  if want("resets") then scenarioResets() end
  if want("error") then scenarioSaveError() end
  if want("door") then scenarioDoor() end
  if want("contexts") then scenarioContexts() end
  if want("trainer") then scenarioTrainer() end
  if want("gate") then scenarioGate() end

  F.L("SUMMARY final save " .. fmt(saved))
  F.finish()
end)
