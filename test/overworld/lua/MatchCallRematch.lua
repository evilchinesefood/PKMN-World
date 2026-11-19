-- Hoenn Match Call rematches, played with real input. No suite had fought one.
--
-- With five Hoenn badges, the PokeNav and Match Call, and Calvin beaten and registered, the player
-- walks 150 steps on Route 104 and crosses into Petalburg by the connection: Emerald's rematch step
-- count (trainerRematchStepCounter, the low byte the Kanto VS Seeker shares) must survive the map
-- change. Petalburg then fills it to 255 and each crossing into Route 102 rolls for Calvin; a
-- crossing back into Petalburg (no rematch trainer) must keep the full count. Once Calvin asks (by
-- that roll or by a Match Call), talking to him must field CALVIN_2, pay once, consume the request
-- and keep him registered; a second talk starts nothing. Then, as Hoenn champion, with Roxanne's
-- PokeNav entry asking for a rematch (the state UpdateGymLeaderRematch leaves), Roxanne is refused
-- once (NO) and then fought (YES): the champion rematch must use ROXANNE_1's Hard team, return
-- control and consume her request, so her PokeNav call no longer says the gym is ready. Last, every
-- Hoenn trainer and leader is registered and the whole Match Call list is walked with a seeded mash.
--
-- Knobs: PW_SEED=<n> reseeds the mash, PW_INSTANT=1 sets Instant text.
-- Run via test/overworld/mgba-run.sh test/overworld/lua/MatchCallRematch.lua <rom> --env PW_MAX_FRAMES=900000

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "MatchCallRematch")

local HUB_GROUP = 100
local CONTEXT_RUNNING = 0
local FLAG_SYS_POKENAV_GET = 0x94A
local FLAG_HAS_MATCH_CALL = 0x12F
local FLAG_ADDED_MATCH_CALL_TO_POKENAV = 0x130
local FLAG_BADGE01_GET = 0x94F
local FLAG_HOENN_CHAMPION = 0xA40 + 0x0A
local FLAG_RECEIVED_TM_ROCK_TOMB = 0xA5
local FLAG_ENABLE_ROXANNE_MATCH_CALL = 0x1D3
local FLAG_DEFEATED_RUSTBORO_GYM = 0x4F0
local TRAINER_FLAGS_START = 0x500
local TRAINER_REGISTERED_FLAGS_START = 0x15C
local VAR_REPEL_STEP_COUNT = 0x4021
local VAR_DIFFICULTY = 0x40F8
local REMATCH_CALVIN, REMATCH_ROXANNE = 34, 65
local TRAINER_CALVIN_1, TRAINER_CALVIN_2 = 318, 328
local TRAINER_ROXANNE_1 = 265
local ROUTE104 = { g = 0, m = 19 }
local PETALBURG = { g = 0, m = 0 }
local ROUTE102 = { g = 0, m = 17 }
local RUSTBORO_GYM = { g = 11, m = 3 }
local RUSTBORO = { g = 0, m = 3 }
local USM_ICO_POKENAV = 3
local SUBSTRUCT_MATCH_CALL_MAIN = 5
local MC = { numRegistered = 10, initFinished = 16, callback = 24, entries = 28, entrySize = 8, special = 0, headerId = 4 }

local seed = tonumber(os.getenv("PW_SEED") or "") or 5113
local rng = seed
local function rand(n) rng = (rng * 1103515245 + 12345) & 0x7FFFFFFF; return (rng >> 16) % n end
local NUM_HOENN_TRAINERS = 64
local FLAG_ENABLE_LEADER_MATCH_CALLS = { 0x1D3, 0x1D4, 0x1D5, 0x1D6, 0x1D7, 0x1D8, 0x1D9, 0x132 }

local function d(n) return (n // 100) % 10, (n // 10) % 10, n % 10 end
local function where() local x, y = F.pos(); return string.format("%d/%d (%d,%d)", F.grp(), F.mapn(), x, y) end
local function flag(id, on)
  local a, m = F.sb1() + S.SaveBlock1.flags + id // 8, 1 << (id % 8)
  if on == nil then return (F.r8(a) & m) ~= 0 end
  F.w8(a, on and (F.r8(a) | m) or (F.r8(a) & ~m & 0xFF))
end
local function var(id, v)
  local a = F.sb1() + S.SaveBlock1.vars + (id - 0x4000) * 2
  if v == nil then return F.r16(a) end
  F.w16(a, v)
end
local function stepCounter() return F.r16(F.sb1() + S.SaveBlock1.trainerRematchStepCounter) end
local function rematchState(id, v)
  local a = F.sb1() + S.SaveBlock1.trainerRematches + id
  if v == nil then return F.r8(a) end
  F.w8(a, v)
end
local function opponentA() return F.r16(S.gTrainerBattleParameter + 2) end
local function hasControl()
  return F.ow() and F.r8(S.sLockFieldControls) == 0 and F.r8(S.sGlobalScriptContextStatus) ~= CONTEXT_RUNNING
end
local function awaitControl(budget, key)
  local calm = 0
  for i = 1, budget or 3000 do
    calm = hasControl() and calm + 1 or 0
    if calm >= 30 then return true end
    if calm == 0 and i % 20 == 0 then F.press(key or "B", 2) else F.idle(1) end
  end
  return hasControl()
end

local function setParty()
  F.dbg(); F.idle(60)
  for _ = 1, 2 do F.press("Down", 3); F.idle(16) end
  F.press("A", 3); F.idle(60)
  for _ = 1, 9 do F.press("Down", 3); F.idle(16) end
  F.press("A", 3); F.idle(180)
  for _ = 1, 6 do F.press("B", 3); F.idle(20) end
end

local function warpToCoords(g, m, x, y, tag)
  for _ = 1, 4 do
    F.dbg(); F.sel(0); F.sel(1); F.idle(20)
    F.spin(d(g)); F.spin(d(m))
    F.press("A", 2)
    for _ = 1, 400 do
      F.w8(S.sWarpDestination + 2, 0xFF)
      F.w16(S.sWarpDestination + 4, x)
      F.w16(S.sWarpDestination + 6, y)
      F.idle(1)
      local px, py = F.pos()
      if F.ow() and F.grp() == g and F.mapn() == m and px == x and py == y then
        F.idle(120)
        for i = 1, 900 do
          if hasControl() then break end
          if i % 20 == 0 then F.press("B", 2) else F.idle(1) end
        end
        F.L(string.format("  WARP %s ok (%d,%d)", tag, px, py))
        return true
      end
    end
    F.bOut(5)
  end
  F.shot(tag .. "_warpfail")
  return false
end

local function koFoes()
  for i = 0, 5 do F.w16(S.gParties + 6 * S.Pokemon.size + i * S.Pokemon.size + S.Pokemon.hp, 0) end
  F.w16(S.gBattleMons + S.BattlePokemon.size + S.BattlePokemon.hp, 0)
  F.w16(S.gBattleMons + 3 * S.BattlePokemon.size + S.BattlePokemon.hp, 0)
end

local function playOut(tag, budget)
  local battled, inBattle, outcome, opp, foeLv, calm = false, 0, nil, nil, nil, 0
  for f = 1, budget or 15000 do
    if not F.ow() and F.battlers() > 0 then
      if not battled then opp = opponentA() end
      battled = true
      inBattle = inBattle + 1
      if inBattle == 200 then foeLv = F.r8(S.gParties + 6 * S.Pokemon.size + S.Pokemon.level) end
      if inBattle > 240 and inBattle % 60 == 0 then koFoes() end
      F.w8(S.gActionSelectionCursor, 0)
    end
    if battled and F.ow() and not outcome then outcome = F.outcome() end
    calm = hasControl() and calm + 1 or 0
    if f > 30 and calm >= 30 then break end
    if f % 600 == 0 and F.reportCrash(tag .. f) then break end
    if calm == 0 and f % 20 == 0 then F.press((battled and F.ow()) and "B" or "A", 2) else F.idle(1) end
  end
  return battled, outcome or 0, opp, foeLv
end

local function walkSteps(n, xa, xb, tag)
  local done, dir = 0, "Right"
  while done < n do
    local x = select(1, F.pos())
    if dir == "Right" and x >= xb then dir = "Left" elseif dir == "Left" and x <= xa then dir = "Right" end
    if F.step(dir) then done = done + 1 else
      if not awaitControl(600) then F.L("  walk " .. tag .. " stuck at " .. where()); return done end
    end
  end
  return done
end

local function decode(addr, max)
  local out = {}
  for i = 0, (max or 300) - 1 do
    local c = F.r8(addr + i)
    if c == 0xFF then break end
    if c == 0x00 or c == 0xFE or c == 0xFA or c == 0xFB then out[#out + 1] = " "
    elseif c >= 0xBB and c <= 0xD4 then out[#out + 1] = string.char(65 + c - 0xBB)
    elseif c >= 0xD5 and c <= 0xEE then out[#out + 1] = string.char(97 + c - 0xD5)
    elseif c >= 0xA1 and c <= 0xAA then out[#out + 1] = string.char(48 + c - 0xA1)
    elseif c == 0xAB then out[#out + 1] = "!"
    elseif c == 0xAD then out[#out + 1] = "."
    elseif c == 0xB4 then out[#out + 1] = "'"
    elseif c == 0xB8 then out[#out + 1] = ","
    elseif c == 0xF0 then out[#out + 1] = ":"
    else out[#out + 1] = "?" end
  end
  return table.concat(out)
end
local function matchCallMenu()
  local res = F.r32(S.gPokenavResources)
  if res < 0x02000000 or res >= 0x02040000 then return nil end
  local p = F.r32(res + 16 + SUBSTRUCT_MATCH_CALL_MAIN * 4)
  if p < 0x02000000 or p >= 0x02040000 then return nil end
  return p
end
local function listReady()
  local p = matchCallMenu()
  return p and F.r32(p + MC.initFinished) ~= 0 and (F.r32(p + MC.callback) & ~1) == (S.CB2_HandleMatchCallInput & ~1)
end
local function openMatchCall(tag)
  for _ = 1, 10 do if hasControl() then break end F.press("B", 2); F.idle(20) end
  local offered = false
  for _ = 1, 3 do
    F.press("Start", 2); F.idle(60)
    offered = F.selectStartIcon(USM_ICO_POKENAV)
    if offered then break end
    for _ = 1, 4 do F.press("B", 2); F.idle(30) end
  end
  if not F.check(tag .. ": the Start menu offers the PokeNav", offered) then return false end
  F.press("A", 2); F.idle(240)
  F.press("Down", 2); F.idle(20); F.press("Down", 2); F.idle(20)
  F.press("A", 2)
  for _ = 1, 300 do if listReady() then break end F.idle(1) end
  F.idle(60)
  return F.check(tag .. ": the Match Call list opened", listReady(), where())
end
local function callAll(tag)
  local p = matchCallMenu()
  local n = F.r16(p + MC.numRegistered)
  local got = {}
  for i = 0, n - 1 do
    F.w8(S.gStringVar4, 0xFF)
    F.press("A", 2); F.idle(30)
    F.press("A", 2)
    for t = 1, 900 do
      if F.r8(S.gStringVar4) ~= 0xFF then break end
      if t % 40 == 0 then F.press("A", 2) else F.idle(1) end
    end
    local text = decode(S.gStringVar4)
    F.idle(90)
    F.shot(string.format("%s_call%d", tag, i))
    for _ = 1, 40 do
      if listReady() then break end
      F.press("A", 2); F.idle(40)
    end
    F.L(string.format("  %s #%d: %s", tag, i, text))
    got[#got + 1] = text
    F.press("Down", 2); F.idle(30)
  end
  return got
end
local function closePokenav(tag)
  for _ = 1, 10 do if F.ow() then break end F.press("B", 2); F.idle(90) end
  for _ = 1, 10 do if F.ensureFree() then break end F.press("B", 2); F.idle(20) end
  F.check(tag .. ": back on the field and walkable", F.ow() and F.ensureFree(), where())
end
local function roxanneLine(rows)
  for _, t in ipairs(rows) do if t:sub(1, 7) == "ROXANNE" then return t end end
  return ""
end

F.run(function()
  if not F.boot(HUB_GROUP) then F.check("boot to the hub", false); F.finish(); return end
  F.L("seed " .. seed)
  if os.getenv("PW_INSTANT") == "1" then
    local a = F.sb2() + S.SaveBlock2.optionsU16
    F.w16(a, (F.r16(a) & ~7) | 3)
  end
  F.idle(40)
  setParty()
  for _, id in ipairs({ FLAG_SYS_POKENAV_GET, FLAG_HAS_MATCH_CALL, FLAG_ADDED_MATCH_CALL_TO_POKENAV }) do flag(id, true) end
  for i = 0, 4 do flag(FLAG_BADGE01_GET + i, true) end
  flag(TRAINER_FLAGS_START + TRAINER_CALVIN_1, true)
  flag(TRAINER_REGISTERED_FLAGS_START + REMATCH_CALVIN, true)
  var(VAR_REPEL_STEP_COUNT, 999)

  if not F.check("Route 104 reached", warpToCoords(ROUTE104.g, ROUTE104.m, 30, 61, "route104"), where()) then F.finish(); return end
  F.L(string.format("  counter at Route 104 0x%04X", stepCounter()))
  local n = walkSteps(150, 28, 37, "r104")
  F.L(string.format("  walked %d on Route 104: counter 0x%04X", n, stepCounter()))
  F.step("Down")
  local before = stepCounter() & 0xFF
  for _ = 1, 12 do
    if F.grp() == PETALBURG.g and F.mapn() == PETALBURG.m then break end
    if not F.step("Right") then awaitControl(300) end
  end
  F.L(string.format("  entered %s: counter 0x%04X (was %d before the last steps)", where(), stepCounter(), before))
  F.check("Petalburg reached by the Route 104 connection", F.grp() == PETALBURG.g and F.mapn() == PETALBURG.m, where())
  F.check("the Match Call step count survives a map change", (stepCounter() & 0xFF) >= before, string.format("0x%04X", stepCounter()))


  -- Fill the count in Petalburg, then cross into Route 102 (Calvin's map) until he wants a rematch.
  if not F.check("Petalburg east edge reached", warpToCoords(PETALBURG.g, PETALBURG.m, 27, 17, "petal"), where()) then F.finish(); return end
  walkSteps(math.max(0, 255 - (stepCounter() & 0xFF)), 22, 27, "petal255")
  F.L(string.format("  Petalburg full: counter 0x%04X at %s", stepCounter(), where()))
  local wanted, crossings = false, 0
  for c = 1, 20 do
    crossings = c
    for _ = 1, 6 do if F.grp() == ROUTE102.g and F.mapn() == ROUTE102.m then break end; if not F.step("Right") then awaitControl(300) end end
    F.L(string.format("  crossing %d into %s: counter 0x%04X calvin=%d", c, where(), stepCounter(), rematchState(REMATCH_CALVIN)))
    if rematchState(REMATCH_CALVIN) ~= 0 then wanted = true; break end
    for _ = 1, 6 do if F.grp() == PETALBURG.g and F.mapn() == PETALBURG.m then break end; if not F.step("Left") then awaitControl(300) end end
    F.check(string.format("crossing %d: Petalburg keeps a full count", c), (stepCounter() & 0xFF) == 255, string.format("0x%04X", stepCounter()))
    if (stepCounter() & 0xFF) ~= 255 then break end
  end
  F.check("Calvin asks for a rematch on entering Route 102", wanted, "crossings=" .. crossings)
  if wanted then
    local m0 = F.money()
    if F.check("Calvin reached", warpToCoords(ROUTE102.g, ROUTE102.m, 33, 15, "calvin"), where()) then
      F.face("Up"); F.press("A", 2)
      local battled, outcome, opp = playOut("calvin", 15000)
      F.L(string.format("  calvin: battled=%s outcome=%d opp=%s money %d -> %d at %s", tostring(battled), outcome, tostring(opp), m0, F.money(), where()))
      F.check("Calvin's rematch fields CALVIN_2", opp == TRAINER_CALVIN_2, tostring(opp))
      F.check("Calvin's rematch is won and pays", outcome == 1 and F.money() > m0)
      F.check("Calvin's request is consumed", rematchState(REMATCH_CALVIN) == 0, tostring(rematchState(REMATCH_CALVIN)))
      F.check("Calvin stays registered", flag(TRAINER_REGISTERED_FLAGS_START + REMATCH_CALVIN))
      local m1 = F.money()
      F.face("Up"); F.press("A", 2)
      battled = playOut("calvin_again", 3000)
      F.check("Calvin again: no battle and no pay", not battled and F.money() == m1)
    end
  end

  -- A Hoenn champion whose PokeNav says Roxanne is ready (what UpdateGymLeaderRematch leaves).
  for _, id in ipairs({ FLAG_HOENN_CHAMPION, FLAG_RECEIVED_TM_ROCK_TOMB, FLAG_ENABLE_ROXANNE_MATCH_CALL, FLAG_DEFEATED_RUSTBORO_GYM, TRAINER_FLAGS_START + TRAINER_ROXANNE_1 }) do flag(id, true) end
  rematchState(REMATCH_ROXANNE, 1)
  if not F.check("Rustboro City reached", warpToCoords(RUSTBORO.g, RUSTBORO.m, 27, 20, "rustboro"), where()) then F.finish(); return end
  if openMatchCall("ready") then
    local line = roxanneLine(callAll("ready"))
    F.check("ready: Roxanne's call asks for the rematch", line:find("GYM is ready", 1, true) ~= nil, line)
    closePokenav("ready")
  end
  if not F.check("Rustboro Gym reached", warpToCoords(RUSTBORO_GYM.g, RUSTBORO_GYM.m, 5, 3, "gym"), where()) then F.finish(); return end
  F.L("  VAR_DIFFICULTY=" .. var(VAR_DIFFICULTY))
  local m0 = F.money()
  F.face("Up"); F.press("A", 2)
  local refused = false
  for f = 1, 3000 do
    if F.taskLive(S.Task_HandleYesNoInput) then F.idle(20); F.press("B", 2); refused = true; break end
    if f % 30 == 0 then F.press("A", 2) else F.idle(1) end
  end
  local rb = playOut("roxanne_no", 3000)
  F.check("NO to Roxanne: no battle, control returns, money kept", refused and not rb and hasControl() and F.money() == m0,
    string.format("refused=%s battled=%s control=%s money %d -> %d at %s", tostring(refused), tostring(rb), tostring(hasControl()), m0, F.money(), where()))
  F.face("Up"); F.press("A", 2)
  local battled, outcome, opp, foeLv = playOut("roxanne", 20000)
  F.L(string.format("  roxanne: battled=%s outcome=%d opp=%s foeLv=%s", tostring(battled), outcome, tostring(opp), tostring(foeLv)))
  F.check("the champion rematch is fought against ROXANNE_1 and won", battled and opp == TRAINER_ROXANNE_1 and outcome == 1)
  F.check("the champion rematch uses the Hard team", (foeLv or 0) >= 58, tostring(foeLv))
  F.check("control returns after the rematch", awaitControl(1200), where())
  F.check("the rematch consumed Roxanne's request", rematchState(REMATCH_ROXANNE) == 0, tostring(rematchState(REMATCH_ROXANNE)))
  if not F.check("back outside the gym", warpToCoords(RUSTBORO.g, RUSTBORO.m, 27, 20, "rustboro2"), where()) then F.finish(); return end
  if openMatchCall("after") then
    local line = roxanneLine(callAll("after"))
    F.check("after: Roxanne no longer asks for a rematch", line ~= "" and line:find("GYM is ready", 1, true) == nil, line)
    closePokenav("after")
  end

  for i = 0, NUM_HOENN_TRAINERS - 1 do flag(TRAINER_REGISTERED_FLAGS_START + i, true) end
  for _, id in ipairs(FLAG_ENABLE_LEADER_MATCH_CALLS) do flag(id, true) end
  if openMatchCall("full") then
    local p = matchCallMenu()
    local count = F.r16(p + MC.numRegistered)
    F.L("  full list: " .. count .. " contacts")
    F.check("full: every registered trainer and leader is listed", count >= NUM_HOENN_TRAINERS + #FLAG_ENABLE_LEADER_MATCH_CALLS, tostring(count))
    for f = 1, 3000 do
      local k = ({ "Down", "Down", "Down", "Up", "Right", "Left", "A", "B" })[rand(8) + 1]
      if f % 8 < 2 then joypad.set({ [k] = true }) else joypad.set({}) end
      emu.frameadvance()
      if f == 240 then F.shot("full_list") end
      if f % 300 == 0 and F.reportCrash("full" .. f) then break end
      if F.ow() then break end
    end
    joypad.set({})
    closePokenav("full")
  end
  F.check("no crash screen", not F.reportCrash("end"))
  F.finish()
end)
