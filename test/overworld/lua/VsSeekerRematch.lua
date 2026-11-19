-- Kanto VS Seeker rematches, played with real input. No suite had used the seeker.
--
-- The Vermilion Pokemon Center woman gives the seeker (real talk). On Route 3, with its trainers
-- beaten and three Kanto badges, SELECT uses the seeker: uncharged at first, charged by 100 Kanto
-- steps, then used once to the far east with nobody in range and once among Ben, Colton and Janice
-- (rematch families) and Greg (no rematch party) with a seeded mash of every button under the
-- animation. Ben and Colton are talked into rematches; the rematch must field the stage-1 party
-- (BEN_2, COLTON_2), pay once, clear only that trainer's offer and record the party beaten. A second
-- talk must start nothing. 100 steps after the use the charge runs out: control returns and the
-- untouched offer (Janice) lapses. The charged seeker then walks three steps in the World Transit
-- hub and three on Hoenn's Route 104 (both tick the shared Match Call step byte); back on Route 3
-- it must still be charged. With an empty party a talk to Janice is refused and keeps her offer,
-- and with the party back she battles JANICE_2. Without a Repel the seeker is charged among the wild
-- Pokemon and used with one within three tiles and the follower out, under a mash. As Kanto champion (Hoenn champion all along, so
-- Kanto stays on the Normal tier until then) Ben's next rematch is BEN_3. Last, a Start-menu save
-- with Colton's and Janice's offers pending, a soft reset in the middle of a trainer's approach and
-- Continue: control returns, the offers and charging window are cleared (as on any map load), the
-- saved charge is kept, and 100 steps later the seeker offers both rematches again.
--
-- Knobs: PW_SEED=<n> reseeds the mash, PW_INSTANT=1 sets Instant text.
-- Run via test/overworld/mgba-run.sh test/overworld/lua/VsSeekerRematch.lua <rom> --env PW_MAX_FRAMES=900000

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "VsSeekerRematch")

local HUB = { g = 100, m = 0 }
local CONTEXT_RUNNING = 0
local ITEM_VS_SEEKER = 714
local FLAG_KANTO_BASE = 0xA40
local FLAG_GOT_VS_SEEKER = FLAG_KANTO_BASE + 0x292
local FLAG_KANTO_BADGE_1 = FLAG_KANTO_BASE + 0x0B
local FLAG_KANTO_CHAMPION = FLAG_KANTO_BASE + 0x08
local FLAG_HOENN_CHAMPION = FLAG_KANTO_BASE + 0x0A
local FLAG_SYS_VS_SEEKER_CHARGING = 0x20
local FLAG_BADGE01_GET = 0x94F
local VAR_REPEL_STEP_COUNT = 0x4021
local VAR_DIFFICULTY = 0x40F8
local KANTO_TRAINER_ID_OFFSET = 1096
local REMATCH_KANTO_START = 78
local VSSEEKER_RECHARGE_STEPS = 100
local VERMILION_PC = { g = 43, m = 1 }
local ROUTE3 = { g = 37, m = 21 }
local ROUTE104 = { g = 0, m = 19 }

local T = {
  BEN = 1097, BEN_2 = 1109, BEN_3 = 1480, COLTON = 1113, COLTON_2 = 1706, JANICE = 1123, JANICE_2 = 1489,
  CALVIN = 1098, GREG = 1114, SALLY = 1124, JAMES = 1115, ROBIN = 1125,
}
local FAMILY = { BEN = REMATCH_KANTO_START + 0, COLTON = REMATCH_KANTO_START + 1, JANICE = REMATCH_KANTO_START + 2 }
local GREG_LOCALID = 5

local seed = tonumber(os.getenv("PW_SEED") or "") or 4207
local rng = seed
local function rand(n) rng = (rng * 1103515245 + 12345) & 0x7FFFFFFF; return (rng >> 16) % n end
local MASH = { "A", "B", "Start", "Select", "L", "R", "Up", "Down", "Left", "Right" }

local function d(n) return (n // 100) % 10, (n // 10) % 10, n % 10 end
local function where() local x, y = F.pos(); return string.format("%d/%d (%d,%d)", F.grp(), F.mapn(), x, y) end
local function flag(id, on)
  local a, m = F.sb1() + S.SaveBlock1.flags + id // 8, 1 << (id % 8)
  if on == nil then return (F.r8(a) & m) ~= 0 end
  F.w8(a, on and (F.r8(a) | m) or (F.r8(a) & ~m & 0xFF))
end
local function kantoBeaten(trainerId, on)
  local bit = trainerId - KANTO_TRAINER_ID_OFFSET
  local a, m = F.sb3() + S.SaveBlock3.kantoTrainerFlags + bit // 8, 1 << (bit % 8)
  if on == nil then return (F.r8(a) & m) ~= 0 end
  F.w8(a, on and (F.r8(a) | m) or (F.r8(a) & ~m & 0xFF))
end
local function var(id, v)
  local a = F.sb1() + S.SaveBlock1.vars + (id - 0x4000) * 2
  if v == nil then return F.r16(a) end
  F.w16(a, v)
end
local function counter() return F.r16(F.sb1() + S.SaveBlock1.trainerRematchStepCounter) end
local function charge() return counter() & 0xFF end
local function rematchState(tableId) return F.r8(F.sb1() + S.SaveBlock1.trainerRematches + tableId) end
local function states()
  return string.format("ben=%d colton=%d janice=%d", rematchState(FAMILY.BEN), rematchState(FAMILY.COLTON), rematchState(FAMILY.JANICE))
end
local function opponentA() return F.r16(S.gTrainerBattleParameter + 2) end
local function taskLive(fn)
  for i = 0, S.Task.count - 1 do
    local t = S.gTasks + i * S.Task.stride
    if F.r8(t + S.Task.isActive) ~= 0 and (F.r32(t + S.Task.func) & ~1) == (fn & ~1) then return true end
  end
  return false
end

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

local function partyMenu(row)
  F.dbg(); F.idle(60)
  for _ = 1, 2 do F.press("Down", 3); F.idle(16) end
  F.press("A", 3); F.idle(60)
  for _ = 1, row do F.press("Down", 3); F.idle(16) end
  F.press("A", 3); F.idle(180)
  for _ = 1, 6 do F.press("B", 3); F.idle(20) end
end
local function setParty() partyMenu(9) end
local function clearParty() partyMenu(8) end

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

-- Foes keep their HP zeroed once the battle has run a while; the battle is not under test.
local function koFoes()
  for i = 0, 5 do F.w16(S.gParties + 6 * S.Pokemon.size + i * S.Pokemon.size + S.Pokemon.hp, 0) end
  F.w16(S.gBattleMons + S.BattlePokemon.size + S.BattlePokemon.hp, 0)
  F.w16(S.gBattleMons + 3 * S.BattlePokemon.size + S.BattlePokemon.hp, 0)
end

-- Run whatever has started (a talk, an approach) to a field with control, fighting any battle.
local function playOut(tag, budget)
  local battled, inBattle, outcome, opp, calm = false, 0, nil, nil, 0
  for f = 1, budget or 15000 do
    if not F.ow() and F.battlers() > 0 then
      if not battled then opp = opponentA() end
      battled = true
      inBattle = inBattle + 1
      if inBattle > 240 and inBattle % 60 == 0 then koFoes() end
      F.w8(S.gActionSelectionCursor, 0)
    end
    if battled and F.ow() and not outcome then outcome = F.outcome() end
    calm = hasControl() and calm + 1 or 0
    if f > 30 and calm >= 30 then break end
    if f % 600 == 0 and F.reportCrash(tag .. f) then break end
    if calm == 0 and f % 20 == 0 then F.press((battled and F.ow()) and "B" or "A", 2) else F.idle(1) end
  end
  return battled, outcome or 0, opp
end

local function talk(dir, tag)
  F.face(dir)
  F.press("A", 2)
  return playOut(tag)
end

local function selectSeeker()
  F.w16(F.sb1() + S.SaveBlock1.registeredItem, ITEM_VS_SEEKER)
  F.press("Select", 2)
end

-- SELECT, then either page the reply or mash every button until the seeker's tasks are gone.
local function useSeeker(tag, mash)
  selectSeeker()
  if mash then
    for f = 1, 600 do
      if f > 30 and not taskLive(S.Task_InitVsSeekerAndCheckForTrainersOnScreen)
        and not taskLive(S.Task_VsSeeker_ShowResponseToPlayer) and hasControl() then break end
      if f % 6 < 2 then joypad.set({ [MASH[rand(#MASH) + 1]] = true }) else joypad.set({}) end
      emu.frameadvance()
    end
    joypad.set({})
  else
    F.idle(100)
  end
  F.shot(tag)
  local ok = awaitControl(1500, "A")
  F.L(string.format("  seeker %s at %s: %s charging=%s counter 0x%04X", tag, where(), states(),
    tostring(flag(FLAG_SYS_VS_SEEKER_CHARGING)), counter()))
  return ok
end

local function walkSteps(n, xa, xb, tag)
  local done, dir = 0, "Right"
  while done < n do
    local x = select(1, F.pos())
    if dir == "Right" and x >= xb then dir = "Left" elseif dir == "Left" and x <= xa then dir = "Right" end
    if F.step(dir) then done = done + 1 else
      if F.reportCrash("walk_" .. tag) or not awaitControl(600) then F.L("  walk " .. tag .. " stuck at " .. where()); return done end
    end
  end
  return done
end

local OBJ_EVENT_MON = 0x4000
local FOLLOWER_LOCALID = 0xFE
local function nearestOwe()
  local px, py = F.pos()
  local best
  for i = 0, 15 do
    local o = S.gObjectEvents + i * S.ObjectEvent.stride
    if (F.r8(o) & 1) ~= 0 and F.r8(o + S.ObjectEvent.localId) ~= FOLLOWER_LOCALID
      and (F.r16(o + S.ObjectEvent.graphicsId) & OBJ_EVENT_MON) ~= 0 then
      local dist = math.abs(F.rs16(o + S.ObjectEvent.x) - 7 - px) + math.abs(F.rs16(o + S.ObjectEvent.y) - 7 - py)
      if not best or dist < best then best = dist end
    end
  end
  return best
end
local function inBattle() return (F.cb2() & ~1) == (S.BattleMainCB2 & ~1) end
local function flee(tag)
  for i = 1, 6000 do
    if F.ow() and hasControl() then return true end
    if inBattle() then F.w8(S.gActionSelectionCursor, 3) end
    if i % 120 == 0 and F.reportCrash(tag .. "_battle") then return false end
    if i % 10 == 0 then F.press("A", 2) else F.idle(1) end
  end
  return false
end

local USM_ICO_SAVE = 7
local function driveSave()
  awaitControl(300)
  F.w16(S.gSaveAttemptStatus, 0xFFFF)
  F.press("Start", 2); F.idle(60)
  if not F.selectStartIcon(USM_ICO_SAVE) then return "noicon" end
  for i = 1, 3000 do
    if F.r16(S.gSaveAttemptStatus) ~= 0xFFFF then
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

local function objAt(localId)
  for i = 0, 15 do
    local o = S.gObjectEvents + i * S.ObjectEvent.stride
    if (F.r8(o) & 1) ~= 0 and F.r8(o + S.ObjectEvent.localId) == localId then return o end
  end
end

F.run(function()
  if not F.boot(HUB.g) then F.check("boot to the hub", false); F.finish(); return end
  F.L("seed " .. seed)
  if os.getenv("PW_INSTANT") == "1" then
    local a = F.sb2() + S.SaveBlock2.optionsU16
    F.w16(a, (F.r16(a) & ~7) | 3)
  end
  F.idle(40)
  setParty()
  F.check("setup: a party", F.r8(S.gPartiesCount) >= 1, "count=" .. F.r8(S.gPartiesCount))

  if not F.check("Vermilion Center reached", warpToCoords(VERMILION_PC.g, VERMILION_PC.m, 6, 5, "vermilion"), where()) then F.finish(); return end
  talk("Up", "seekerwoman")
  F.check("the woman gives the VS Seeker once", F.itemCount(ITEM_VS_SEEKER) == 1 and flag(FLAG_GOT_VS_SEEKER),
    string.format("count=%d flag=%s", F.itemCount(ITEM_VS_SEEKER), tostring(flag(FLAG_GOT_VS_SEEKER))))
  talk("Up", "seekerwoman_again")
  F.check("a second talk gives no second seeker", F.itemCount(ITEM_VS_SEEKER) == 1)

  for i = 0, 2 do flag(FLAG_KANTO_BADGE_1 + i, true) end
  for i = 0, 4 do flag(FLAG_BADGE01_GET + i, true) end
  flag(FLAG_HOENN_CHAMPION, true)
  var(VAR_REPEL_STEP_COUNT, 999)
  for _, k in ipairs({ "BEN", "COLTON", "JANICE", "CALVIN", "GREG", "SALLY", "JAMES", "ROBIN" }) do kantoBeaten(T[k], true) end

  if not F.check("Route 3 reached", warpToCoords(ROUTE3.g, ROUTE3.m, 21, 5, "route3"), where()) then F.finish(); return end
  F.check("a Hoenn champion stays on Kanto's Normal tier", var(VAR_DIFFICULTY) < 2, "VAR_DIFFICULTY=" .. var(VAR_DIFFICULTY))
  local c0 = counter()
  F.check("uncharged: control returns", useSeeker("uncharged"), where())
  F.check("uncharged: nobody is offered a rematch and the count is untouched",
    rematchState(FAMILY.BEN) == 0 and counter() == c0 and not flag(FLAG_SYS_VS_SEEKER_CHARGING), states())

  local n = walkSteps(VSSEEKER_RECHARGE_STEPS, 19, 23, "charge")
  F.check("100 Kanto steps charge the seeker", n == VSSEEKER_RECHARGE_STEPS and charge() == VSSEEKER_RECHARGE_STEPS,
    string.format("walked %d, counter 0x%04X", n, counter()))

  if not F.check("Route 3 east end reached", warpToCoords(ROUTE3.g, ROUTE3.m, 62, 12, "east"), where()) then F.finish(); return end
  F.check("nobody in range: control returns", useSeeker("nobody"), where())
  F.check("nobody in range: the charge is kept and no offer is made",
    charge() == VSSEEKER_RECHARGE_STEPS and not flag(FLAG_SYS_VS_SEEKER_CHARGING), string.format("0x%04X", counter()))

  if not F.check("back among the Route 3 trainers", warpToCoords(ROUTE3.g, ROUTE3.m, 18, 5, "west"), where()) then F.finish(); return end
  F.check("mashed use: control returns", useSeeker("mashed", true), where())
  F.check("mashed use: Ben, Colton and Janice want rematches",
    rematchState(FAMILY.BEN) ~= 0 and rematchState(FAMILY.COLTON) ~= 0 and rematchState(FAMILY.JANICE) ~= 0, states())
  F.check("mashed use: the seeker is charging and spent", flag(FLAG_SYS_VS_SEEKER_CHARGING) and charge() == 0,
    string.format("0x%04X", counter()))
  F.check("no crash after the seeker", not F.reportCrash("seeker"))

  local m0 = F.money()
  F.route({ { 17, 5 } }, "toBen")
  local battled, outcome, opp = talk("Up", "ben")
  local m1 = F.money()
  F.L(string.format("  ben: battled=%s outcome=%d opp=%s money %d -> %d", tostring(battled), outcome, tostring(opp), m0, m1))
  F.check("Ben's rematch fields BEN_2", opp == T.BEN_2, tostring(opp))
  F.check("Ben's rematch is won and pays", outcome == 1 and m1 > m0, string.format("%d -> %d", m0, m1))
  F.check("Ben's rematch clears his offer only", rematchState(FAMILY.BEN) == 0 and rematchState(FAMILY.COLTON) ~= 0
    and rematchState(FAMILY.JANICE) ~= 0, states())
  F.check("BEN_2 is recorded beaten", kantoBeaten(T.BEN_2))
  battled = talk("Up", "ben_again")
  F.check("Ben again: no battle and no pay", not battled and F.money() == m1, string.format("battled=%s money=%d", tostring(battled), F.money()))

  F.route({ { 17, 5 }, { 13, 5 }, { 13, 6 } }, "toColton")
  battled, outcome, opp = talk("Left", "colton")
  F.check("Colton's rematch fields COLTON_2 and is won", opp == T.COLTON_2 and outcome == 1, tostring(opp))
  F.check("Colton's rematch leaves Janice's offer", rematchState(FAMILY.JANICE) ~= 0, states())

  F.route({ { 13, 5 }, { 19, 5 } }, "back")
  n = walkSteps(VSSEEKER_RECHARGE_STEPS, 19, 23, "recharge")
  F.check("charge done: control returns", awaitControl(1200), where())
  F.check("charge done: the flag clears and Janice's offer lapses",
    not flag(FLAG_SYS_VS_SEEKER_CHARGING) and rematchState(FAMILY.JANICE) == 0, states())
  F.check("charge done: the seeker is charged again", charge() == VSSEEKER_RECHARGE_STEPS, string.format("0x%04X", counter()))

  -- Travel with a charged seeker: the hub and Hoenn both count steps on the shared byte.
  if not F.check("World Transit hub reached", warpToCoords(HUB.g, HUB.m, 16, 4, "hub"), where()) then F.finish(); return end
  F.step("Down"); F.step("Down"); F.step("Up")
  F.L(string.format("  hub: counter 0x%04X", counter()))
  if not F.check("Hoenn Route 104 reached", warpToCoords(ROUTE104.g, ROUTE104.m, 30, 61, "route104"), where()) then F.finish(); return end
  F.step("Right"); F.step("Right"); F.step("Right")
  F.L(string.format("  Route 104: counter 0x%04X", counter()))
  if not F.check("back on Route 3", warpToCoords(ROUTE3.g, ROUTE3.m, 18, 5, "route3b"), where()) then F.finish(); return end
  F.check("a charged seeker is still charged after the trip", charge() >= VSSEEKER_RECHARGE_STEPS, string.format("0x%04X", counter()))
  F.check("after the trip: control returns", useSeeker("after_trip"), where())
  F.check("after the trip: the seeker finds Janice again", rematchState(FAMILY.JANICE) ~= 0 and flag(FLAG_SYS_VS_SEEKER_CHARGING), states())

  -- An empty party (what the Hub Pass leaves) is refused and keeps the offer.
  if rematchState(FAMILY.JANICE) ~= 0 then
    clearParty()
    F.check("setup: the party is empty", F.r8(S.gPartiesCount) == 0, "count=" .. F.r8(S.gPartiesCount))
    F.route({ { 18, 5 }, { 18, 6 } }, "j1")
    F.route({ { 14, 6 }, { 14, 8 }, { 18, 8 }, { 18, 9 } }, "toJanice")
    battled = talk("Right", "janice_empty")
    F.check("empty party: no battle, control returns", not battled and hasControl(), where())
    F.check("empty party: Janice keeps her offer", rematchState(FAMILY.JANICE) ~= 0, states())
    setParty()
    local m2 = F.money()
    battled, outcome, opp = playOut("janice_approach")
    if not battled then battled, outcome, opp = talk("Right", "janice") end
    if not F.ow() then F.shot("janice_stuck") end
    F.check("with a party Janice battles JANICE_2", opp == T.JANICE_2 and outcome == 1,
      string.format("opp=%s outcome=%d battled=%s at %s", tostring(opp), outcome, tostring(battled), where()))
    F.check("Janice's rematch pays and clears her offer", F.money() > m2 and rematchState(FAMILY.JANICE) == 0, states())
  end

  -- No Repel: charge the seeker among the wild Pokemon and use it with one close by.
  var(VAR_REPEL_STEP_COUNT, 0)
  if not F.check("Route 3 grass reached", warpToCoords(ROUTE3.g, ROUTE3.m, 42, 13, "grass"), where()) then F.finish(); return end
  local walked, fled, closest = 0, 0, nil
  for _ = 1, 900 do
    closest = nearestOwe()
    if charge() >= VSSEEKER_RECHARGE_STEPS and closest and closest <= 3 then break end
    local x, y = F.pos()
    local dirs = {}
    if x > 34 then dirs[#dirs + 1] = "Left" end
    if x < 46 then dirs[#dirs + 1] = "Right" end
    if y > 9 then dirs[#dirs + 1] = "Up" end
    if y < 15 then dirs[#dirs + 1] = "Down" end
    local dir = dirs[rand(#dirs) + 1]
    if F.step(dir) then walked = walked + 1 elseif not F.ow() then fled = fled + 1; flee("owe") else awaitControl(300) end
    if F.reportCrash("owewalk") then break end
  end
  F.L(string.format("  wild walk: %d steps, %d battles fled, nearest wild %s, charge %d at %s", walked, fled,
    tostring(closest), charge(), where()))
  F.check("a wild Pokemon is near with the seeker charged", charge() >= VSSEEKER_RECHARGE_STEPS and closest ~= nil and closest <= 3)
  F.check("the follower is out", objAt(FOLLOWER_LOCALID) ~= nil)
  selectSeeker()
  for f = 1, 400 do
    if f % 6 < 2 then joypad.set({ [MASH[rand(#MASH) + 1]] = true }) else joypad.set({}) end
    emu.frameadvance()
    if inBattle() then break end
  end
  joypad.set({})
  F.shot("owe_use")
  if not F.ow() then flee("owe_after") end
  F.check("with a wild Pokemon near: control returns", awaitControl(1500, "A"), where())
  F.check("with a wild Pokemon near: no crash", not F.reportCrash("owe"))
  F.L("  after the wild use: " .. states() .. string.format(" charging=%s", tostring(flag(FLAG_SYS_VS_SEEKER_CHARGING))))
  var(VAR_REPEL_STEP_COUNT, 999)

  -- Kanto champion: the next stage up for Ben.
  for i = 0, 7 do flag(FLAG_KANTO_BADGE_1 + i, true) end
  flag(FLAG_KANTO_CHAMPION, true)
  if not F.check("Route 3 reloaded as champion", warpToCoords(ROUTE3.g, ROUTE3.m, 21, 5, "champ"), where()) then F.finish(); return end
  F.check("the Kanto champion is on the Hard tier", var(VAR_DIFFICULTY) == 2, "VAR_DIFFICULTY=" .. var(VAR_DIFFICULTY))
  walkSteps(VSSEEKER_RECHARGE_STEPS, 19, 23, "champ")
  F.route({ { 18, 5 } }, "champUse")
  F.check("champion use: control returns", useSeeker("champion"), where())
  F.route({ { 17, 5 } }, "toBen2")
  battled, outcome, opp = talk("Up", "ben3")
  if not battled then battled, outcome, opp = playOut("ben3_approach") end
  F.check("as champion Ben's rematch fields BEN_3", opp == T.BEN_3 and outcome == 1, tostring(opp))
  F.check("Greg (no rematch party) never offered one", objAt(GREG_LOCALID) ~= nil)
  F.check("control returns after Ben", awaitControl(1200), where())

  -- Save with Colton's and Janice's offers pending, then soft reset in the middle of an approach.
  F.check("offers pending before the save", rematchState(FAMILY.COLTON) ~= 0 and rematchState(FAMILY.JANICE) ~= 0, states())
  F.check("saved from the Start menu with offers pending", driveSave() == "done")
  local savedCharge = charge()
  F.route({ { 17, 6 } }, "row6")
  local approached = false
  for _ = 1, 40 do
    local x = select(1, F.pos())
    F.step(x <= 13 and "Right" or (x >= 16 and "Left" or (rand(2) == 0 and "Left" or "Right")))
    for _ = 1, 20 do
      if not hasControl() and F.r8(S.sGlobalScriptContextStatus) == CONTEXT_RUNNING then approached = true; break end
      F.idle(1)
    end
    if approached then break end
  end
  F.L(string.format("  approach before the reset: %s at %s", tostring(approached), where()))
  F.shot("reset_mid_approach")
  softReset(); F.idle(60)
  if not F.check("Continue reaches the field after the reset", F.boot(nil, true)) then F.finish(); return end
  F.check("Continue: control returns", awaitControl(1200), where())
  F.check("Continue: back where the save was made", F.grp() == ROUTE3.g and F.mapn() == ROUTE3.m, where())
  F.check("Continue: the pending offers and the charging window are cleared",
    rematchState(FAMILY.COLTON) == 0 and rematchState(FAMILY.JANICE) == 0 and not flag(FLAG_SYS_VS_SEEKER_CHARGING), states())
  F.check("Continue: the seeker keeps its saved charge", charge() == savedCharge, string.format("0x%04X vs %d", counter(), savedCharge))
  F.route({ { 19, 5 } }, "post")
  walkSteps(VSSEEKER_RECHARGE_STEPS, 19, 23, "post")
  F.route({ { 18, 5 } }, "postUse")
  F.check("after Continue: the seeker works", useSeeker("continued"), where())
  F.check("after Continue: Colton and Janice are offered again", rematchState(FAMILY.COLTON) ~= 0 and rematchState(FAMILY.JANICE) ~= 0, states())
  F.check("control returns at the end", awaitControl(1200), where())
  F.check("no crash screen", not F.reportCrash("end"))
  F.shot("end")
  F.finish()
end)
