-- A visible wild Pokemon that walks into the player mid-step must not swallow the coord event on
-- the tile the player arrives on.
--
-- Victory Road 1F's Wally battle is the pair of coord events at (2,23) and (3,23), which fill the
-- only corridor to the B1F ladder. A world campaign reached that ladder with Wally unbeaten. An
-- encounter walked into the player during the step onto the trigger and its script took the field
-- controls before the step ended. DoCB1_Overworld skips ProcessPlayerFieldInput while the controls
-- are held, so the arrival's coord event never ran, and after the battle the player stood on the
-- trigger and walked on.
--
-- The suite stands the player at (2,22) facing the trigger, with a generated encounter moved beside
-- the corridor, and saves a state. Each trial loads it, waits a different number of frames and
-- steps down onto (2,23) with real input. The encounter's wandering, its contact, the battle and the
-- walk on are the game's own code. Sweep A has the trigger live: every trial that takes the step
-- must start Wally's scene before the player leaves (2,23). Sweep B repeats it with
-- VAR_VICTORY_ROAD_1F_STATE at 1, the value Wally's scene leaves, so (2,23) is a plain tile, and
-- requires contacts made during the step to still start their battle.
--
-- Run via test/overworld/mgba-run.sh test/overworld/lua/OweContactCoordEvent.lua
-- PW_OWE_OFFSETS (default 128) sets the number of frame offsets per sweep.

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "OweContactCoordEvent")

local OE = S.ObjectEvent
local OWE_FIRST, OWE_LAST = 249, 252
local SPECIES_MEWTWO = 150
local VICTORY_ROAD_1F = { 24, 43 }
local VAR_VICTORY_ROAD_1F_STATE = 0x40C3
local CONTEXT_RUNNING = 0
local T_TILE_TRANSITION = 1
local DIR_SOUTH = 1
local OFFSETS = tonumber(os.getenv("PW_OWE_OFFSETS") or "128")
local TRIAL_BUDGET = 5000
local WALLY_LO, WALLY_HI = S.VictoryRoad_1F_EventScript_WallyBattleTrigger1, S.VictoryRoad_1F_EventScript_WallyEntranceBattle

local function d(n) return (n // 100) % 10, (n // 10) % 10, n % 10 end

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

-- Gen 8+ obedience reads the met level; lower it the way the campaign harness does (substruct 3,
-- encrypted with personality ^ otId, checksum adjusted).
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

-- A debug warp with sWarpDestination's warp id held at WARP_ID_NONE, so SetPlayerCoordsFromWarp
-- takes its x,y.
local function warpToCoords(map, x, y, tag)
  local grp, num = map[1], map[2]
  for _ = 1, 4 do
    F.dbg(); F.sel(0); F.sel(1); F.idle(20)
    F.spin(d(grp)); F.spin(d(num))
    F.press("A", 2)
    for _ = 1, 400 do
      F.w8(S.sWarpDestination + 2, 0xFF)
      F.w16(S.sWarpDestination + 4, x)
      F.w16(S.sWarpDestination + 6, y)
      F.idle(1)
      local px, py = F.pos()
      if F.ow() and F.grp() == grp and F.mapn() == num and px == x and py == y then
        F.idle(120)
        F.L(string.format("  WARP %s ok (%d,%d)", tag, px, py))
        return true
      end
    end
    F.bOut(5)
  end
  F.shot(tag .. "_warpfail")
  return false
end

local function varAddr(id) return F.sb1() + S.SaveBlock1.vars + (id - 0x4000) * 2 end
local function playerBase() return S.gObjectEvents + F.r8(S.gPlayerAvatar + 5) * OE.stride end
local function coords(b)
  return F.rs16(b + OE.x) - 7, F.rs16(b + OE.y) - 7, F.rs16(b + OE.x + 4) - 7, F.rs16(b + OE.y + 4) - 7
end
local function inBattle() return F.cb2() == (S.BattleMainCB2 & ~1) end
local function midStep() return F.r8(S.gPlayerAvatar + 3) == T_TILE_TRANSITION end
-- An encounter script ends in `waitstate` and the battle returns without resuming it, so the
-- context is left WAITING with the controls unlocked. That is a free field.
local function hasControl()
  return F.ow() and F.r8(S.sLockFieldControls) == 0
    and F.r8(S.sGlobalScriptContextStatus) ~= CONTEXT_RUNNING
end
local function wallyScene()
  local sp = F.r32(S.sGlobalScriptContext + 8)
  return sp >= WALLY_LO and sp < WALLY_HI
end

local function findOWE()
  for i = 0, 15 do
    local b = S.gObjectEvents + i * OE.stride
    local id = F.r8(b + OE.localId)
    if F.r8(b) & 1 == 1 and id >= OWE_FIRST and id <= OWE_LAST then return b end
  end
end

-- Moves an object to (x,y) at elevation 4, the corridor's: initial, current and previous coords.
local function placeAt(b, x, y)
  for _, off in ipairs({ OE.x - 4, OE.x, OE.x + 4 }) do
    F.w16(b + off, x + 7); F.w16(b + off + 2, y + 7)
  end
  F.w8(b + 0x0B, 0x44)
end

-- One trial from `state`, where the player stands at (2,22) facing down with the trigger below.
-- Down is held while the player stands there with control. A contact before the step leaves the
-- race untested and ends the trial. Otherwise it ends when Wally's scene starts, or when the player
-- stands on (2,23) with control: on the live trigger that is a skip, and the player walks on as the
-- campaign did.
local function trial(state, oweId, k, live)
  client.loadstate(state)
  F.idle(1 + k)
  local pb = playerBase()
  local r = {}
  for f = 1, TRIAL_BUDGET do
    if live and wallyScene() then r.wally = true; break end
    local x, y, px, py = coords(pb)
    local standing = x == px and y == py
    local onTrigger = standing and x == 2 and y == 23
    if not r.step and not standing then r.step = f end
    if onTrigger and not r.arrive then r.arrive = f end
    if not r.lock and F.r8(S.sLockFieldControls) ~= 0 and F.r16(S.gSpecialVar_LastTalked) == oweId then
      r.lock = f
      if not r.step then r.early = true; break end
    end
    local free = hasControl() and not midStep()
    if inBattle() then
      r.battle = true
      -- How the battle is won is not under test: aim the level 100 Mewtwo at Psystrike.
      F.w8(S.gMoveSelectionCursor, 1)
      if f % 10 == 0 then F.press(f % 70 == 0 and "B" or "A", 2) else F.idle(1) end
    elseif free and onTrigger and live then
      r.skipped = true
      for _ = 1, 60 do
        joypad.set({ Down = true }); emu.frameadvance()
        if wallyScene() then r.skipped, r.wally = false, true; break end
      end
      joypad.set({})
      F.idle(30)
      if wallyScene() then r.skipped, r.wally = false, true end
      r.walkedTo = select(2, coords(pb))
      break
    elseif free and onTrigger and (r.battle or f - r.arrive > 30) then
      break
    elseif free and standing and x == 2 and y == 22 then
      joypad.set({ Down = true }); emu.frameadvance()
    else
      F.idle(1)
    end
  end
  joypad.set({})
  return r
end

-- A contact whose script holds the controls when the frame after the walk ends begins (lock at or
-- before `arrive`) is the race: that frame's ProcessPlayerFieldInput is the one that would run
-- the tile's coord event.
local function sweep(tag, state, oweId, live)
  local n = { trials = 0, early = 0, wally = 0, skipped = 0, midStep = 0, byStepEnd = 0 }
  for k = 0, OFFSETS - 1 do
    local r = trial(state, oweId, k, live)
    local during = r.lock and r.step and r.lock >= r.step
    n.trials = n.trials + 1
    if r.early then n.early = n.early + 1 end
    if r.wally then n.wally = n.wally + 1 end
    if r.skipped then n.skipped = n.skipped + 1; F.shot(tag .. "_skip_" .. k) end
    if during and r.arrive and r.lock <= r.arrive then n.midStep = n.midStep + 1 end
    if during and r.arrive and r.lock <= r.arrive + 1 then n.byStepEnd = n.byStepEnd + 1 end
    if during or r.skipped then
      F.L(string.format("    %s k=%d step=%s lock=%s arrive=%s wally=%s skipped=%s%s", tag, k, tostring(r.step),
        tostring(r.lock), tostring(r.arrive), tostring(r.wally == true), tostring(r.skipped == true),
        r.walkedTo and (" walked on to (2," .. r.walkedTo .. ")") or ""))
    end
  end
  F.L(string.format("  %s: trials=%d contact before the step=%d wally=%d skipped=%d encounter lock by the walk's end=%d by the next frame=%d",
    tag, n.trials, n.early, n.wally, n.skipped, n.midStep, n.byStepEnd))
  return n
end

-- West of the trigger and west of the tile the player leaves: the encounter's westward step meets
-- the player's destination or the tile it is leaving.
local PLACES = { { 3, 23 }, { 3, 22 } }

F.run(function()
  if not F.boot(100) then F.check("boot to the hub", false); F.finish(); return end
  F.check("debug Give gave a level 100 Mewtwo", giveMon(SPECIES_MEWTWO, 100) == 1)
  setMetLevel(0, 5)
  if not warpToCoords(VICTORY_ROAD_1F, 2, 21, "victory_road") then
    F.check("warp to Victory Road 1F (2,21)", false); F.finish(); return
  end
  F.check("Wally's corridor trigger is live on a fresh save", F.r16(varAddr(VAR_VICTORY_ROAD_1F_STATE)) == 0)

  local owe
  for k = 1, 120 do
    F.w8(S.sOWESpawnCountdown, 0)
    owe = findOWE()
    if owe then break end
    F.step(k % 2 == 0 and "Up" or "Down")
  end
  F.check("a generated encounter spawned", owe ~= nil)
  if not owe then F.finish(); return end
  -- Reaching (2,22) from (2,21) leaves the player facing the trigger, so a trial's first Down
  -- press walks instead of turning.
  F.check("stand at (2,22) above the trigger", F.leg(2, 22), string.format("(%d,%d)", F.pos()))
  F.check("facing down with control", F.r8(playerBase() + OE.facing) & 0xF == DIR_SOUTH and hasControl(),
    string.format("facing=%d lock=%d", F.r8(playerBase() + OE.facing) & 0xF, F.r8(S.sLockFieldControls)))
  local oweId = F.r8(owe + OE.localId)
  F.L(string.format("  encounter local id %d, graphics %04X", oweId, F.r16(owe + OE.graphicsId)))
  local base = F.out .. "OweContactCoordEvent_base.ss"
  client.savestate(base)

  local total = { A = { trials = 0, early = 0, wally = 0, skipped = 0, midStep = 0 }, B = { trials = 0, midStep = 0, byStepEnd = 0 } }
  for _, p in ipairs(PLACES) do
    for _, live in ipairs({ true, false }) do
      client.loadstate(base)
      F.idle(1)
      placeAt(owe, p[1], p[2])
      if not live then F.w16(varAddr(VAR_VICTORY_ROAD_1F_STATE), 1) end
      local tag = string.format("%s(%d,%d)", live and "A" or "B", p[1], p[2])
      local state = F.out .. "OweContactCoordEvent_" .. (live and "A" or "B") .. ".ss"
      client.savestate(state)
      local n = sweep(tag, state, oweId, live)
      local t = total[live and "A" or "B"]
      for key in pairs(t) do t[key] = t[key] + n[key] end
    end
  end
  F.check("sweep A: no trial walked past the live trigger without Wally's scene", total.A.skipped == 0,
    string.format("skipped %d of %d (encounter locks by the walk's end %d)", total.A.skipped, total.A.trials, total.A.midStep))
  F.check("sweep A: every trial that took the step started Wally's scene", total.A.wally == total.A.trials - total.A.early,
    string.format("%d of %d", total.A.wally, total.A.trials - total.A.early))
  F.check("sweep B: contacts during the step still started their battle by the frame after it", total.B.byStepEnd > 0,
    string.format("%d of %d (by the walk's end %d)", total.B.byStepEnd, total.B.trials, total.B.midStep))
  F.finish()
end)
