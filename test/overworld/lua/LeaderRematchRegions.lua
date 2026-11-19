-- Champion gym rematches in all three regions, each gated on its own region's championship.
--
-- Brock (Pewter), Falkner (Violet) and Roxanne (Rustboro) are left beaten with their TMs given.
-- As Hoenn champion only, Brock and Falkner must start no battle and offer nothing, while Roxanne
-- offers her rematch: refused once (NO: no battle, no money), then fought on the Hard team and paid,
-- and offered again on the next talk (the rematch is unlimited). Each gym checks the region's tier
-- (VAR_DIFFICULTY): Hard only where the player is champion. Adding the Kanto championship opens
-- Brock's Hard rematch and still not Falkner's; the Johto championship then opens Falkner's. Every
-- talk is played with real input and a seeded mash of A and B on the rematch prompts and texts.
--
-- Knobs: PW_SEED=<n> reseeds the mash, PW_INSTANT=1 sets Instant text.
-- Run via test/overworld/mgba-run.sh test/overworld/lua/LeaderRematchRegions.lua <rom> --env PW_MAX_FRAMES=900000

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "LeaderRematchRegions")

local HUB_GROUP = 100
local CONTEXT_RUNNING = 0
local FLAG_KANTO_BASE, FLAG_JOHTO_BASE = 0xA40, 0x6000
local FLAG_KANTO_CHAMPION, FLAG_JOHTO_CHAMPION, FLAG_HOENN_CHAMPION = FLAG_KANTO_BASE + 0x08, FLAG_KANTO_BASE + 0x09, FLAG_KANTO_BASE + 0x0A
local TRAINER_FLAGS_START = 0x500
local KANTO_TRAINER_ID_OFFSET = 1096
local VAR_DIFFICULTY = 0x40F8
local DIFFICULTY_HARD = 2
local HARD_LEVEL = 58

local GYMS = {
  kanto = { name = "Brock", g = 40, m = 2, x = 6, y = 6, leader = 1410, champion = FLAG_KANTO_CHAMPION,
            flags = { FLAG_KANTO_BASE + 0x4B0, FLAG_KANTO_BASE + 0x254, FLAG_KANTO_BASE + 0x0B },
            kantoTrainers = { 1410, 1148 } },
  johto = { name = "Falkner", g = 78, m = 0, x = 9, y = 5, leader = 855, champion = FLAG_JOHTO_CHAMPION,
            flags = { FLAG_JOHTO_BASE + 0x2D, FLAG_JOHTO_BASE + 0x252, FLAG_JOHTO_BASE + 0x3F8, TRAINER_FLAGS_START + 855,
                      TRAINER_FLAGS_START + 856, TRAINER_FLAGS_START + 867 } },
  hoenn = { name = "Roxanne", g = 11, m = 3, x = 5, y = 3, leader = 265, champion = FLAG_HOENN_CHAMPION,
            flags = { 0xA5, 0x4F0, 0x94F, TRAINER_FLAGS_START + 265 } },
}

local seed = tonumber(os.getenv("PW_SEED") or "") or 6151
local rng = seed
local function rand(n) rng = (rng * 1103515245 + 12345) & 0x7FFFFFFF; return (rng >> 16) % n end

local function d(n) return (n // 100) % 10, (n // 10) % 10, n % 10 end
local function where() local x, y = F.pos(); return string.format("%d/%d (%d,%d)", F.grp(), F.mapn(), x, y) end
local function flag(id, on)
  local a, m
  if id >= FLAG_JOHTO_BASE and id < FLAG_JOHTO_BASE + 0x400 then
    a, m = F.sb3() + S.SaveBlock3.johtoFlags + (id - FLAG_JOHTO_BASE) // 8, 1 << (id % 8)
  else
    a, m = F.sb1() + S.SaveBlock1.flags + id // 8, 1 << (id % 8)
  end
  if on == nil then return (F.r8(a) & m) ~= 0 end
  F.w8(a, on and (F.r8(a) | m) or (F.r8(a) & ~m & 0xFF))
end
local function kantoBeaten(trainerId)
  local bit = trainerId - KANTO_TRAINER_ID_OFFSET
  local a = F.sb3() + S.SaveBlock3.kantoTrainerFlags + bit // 8
  F.w8(a, F.r8(a) | (1 << (bit % 8)))
end
local function var(id) return F.r16(F.sb1() + S.SaveBlock1.vars + (id - 0x4000) * 2) end
local function opponentA() return F.r16(S.gTrainerBattleParameter + 2) end
local function hasControl()
  return F.ow() and F.r8(S.sLockFieldControls) == 0 and F.r8(S.sGlobalScriptContextStatus) ~= CONTEXT_RUNNING
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
end

-- Talk to the leader. answer = "yes" or "no" for the rematch prompt; text is paged with a seeded
-- mix of A and B (B never lands on the prompt, which is answered explicitly).
local function talk(answer, tag)
  F.face("Up")
  F.press("A", 2)
  local prompted, battled, inBattle, outcome, opp, foeLv, calm = false, false, 0, nil, nil, nil, 0
  for f = 1, 20000 do
    if F.taskLive(S.Task_HandleYesNoInput) and not prompted then
      prompted = true
      F.idle(10 + rand(20))
      F.press(answer == "yes" and "A" or "B", 2)
    end
    if not F.ow() and F.battlers() > 0 then
      if not battled then opp = opponentA() end
      battled = true
      inBattle = inBattle + 1
      foeLv = math.max(foeLv or 0, F.r8(S.gParties + 6 * S.Pokemon.size + S.Pokemon.level))
      if inBattle > 240 and inBattle % 60 == 0 then koFoes() end
      F.w8(S.gActionSelectionCursor, 0)
    end
    if battled and F.ow() and not outcome then outcome = F.outcome() end
    calm = hasControl() and calm + 1 or 0
    if f > 30 and calm >= 30 then break end
    if f % 600 == 0 and F.reportCrash(tag .. f) then break end
    if calm == 0 and f % 18 == 0 and not F.taskLive(S.Task_HandleYesNoInput) then
      local inField = F.ow()
      F.press((inField and (battled or rand(3) == 0)) and "B" or "A", 2)
    else
      F.idle(1)
    end
  end
  F.L(string.format("  %s: prompted=%s battled=%s outcome=%s opp=%s foeLv=%s at %s", tag, tostring(prompted),
    tostring(battled), tostring(outcome), tostring(opp), tostring(foeLv), where()))
  return { prompted = prompted, battled = battled, outcome = outcome or 0, opp = opp, foeLv = foeLv or 0 }
end

local function visit(key, tag)
  local g = GYMS[key]
  return F.check(string.format("%s: %s's gym reached", tag, g.name), warpToCoords(g.g, g.m, g.x, g.y, tag .. "_" .. key), where())
end

local function expectNoOffer(key, tag)
  local g = GYMS[key]
  if not visit(key, tag) then return end
  F.check(string.format("%s: %s's region is on the Normal tier", tag, g.name), var(VAR_DIFFICULTY) ~= DIFFICULTY_HARD,
    "VAR_DIFFICULTY=" .. var(VAR_DIFFICULTY))
  local m0 = F.money()
  local r = talk("yes", tag .. "_" .. key)
  F.check(string.format("%s: %s offers no rematch and starts no battle", tag, g.name), not r.prompted and not r.battled)
  F.check(string.format("%s: control returns, money kept", tag), hasControl() and F.money() == m0, where())
end

local function expectRematch(key, tag, refuseFirst)
  local g = GYMS[key]
  if not visit(key, tag) then return end
  F.check(string.format("%s: %s's region is on the Hard tier", tag, g.name), var(VAR_DIFFICULTY) == DIFFICULTY_HARD,
    "VAR_DIFFICULTY=" .. var(VAR_DIFFICULTY))
  if refuseFirst then
    local m0 = F.money()
    local r = talk("no", tag .. "_" .. key .. "_no")
    F.check(string.format("%s: NO to %s starts no battle and keeps the money", tag, g.name),
      r.prompted and not r.battled and F.money() == m0 and hasControl(), where())
  end
  local m1 = F.money()
  local r = talk("yes", tag .. "_" .. key .. "_yes")
  F.check(string.format("%s: %s's rematch is fought and won", tag, g.name), r.prompted and r.battled and r.opp == g.leader and r.outcome == 1,
    string.format("opp=%s outcome=%d", tostring(r.opp), r.outcome))
  F.check(string.format("%s: %s fields the Hard team", tag, g.name), r.foeLv >= HARD_LEVEL, tostring(r.foeLv))
  local m2 = F.money()
  F.check(string.format("%s: %s's rematch pays", tag, g.name), m2 > m1, string.format("%d -> %d", m1, m2))
  F.check(string.format("%s: control returns after %s", tag, g.name), hasControl(), where())
  local again = talk("no", tag .. "_" .. key .. "_again")
  F.check(string.format("%s: %s offers the rematch again, nothing paid twice", tag, g.name),
    again.prompted and not again.battled and F.money() == m2)
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
  for _, g in pairs(GYMS) do
    for _, id in ipairs(g.flags) do flag(id, true) end
    for _, id in ipairs(g.kantoTrainers or {}) do kantoBeaten(id) end
  end
  flag(FLAG_HOENN_CHAMPION, true)

  expectNoOffer("kanto", "hoenn champion")
  expectNoOffer("johto", "hoenn champion")
  expectRematch("hoenn", "hoenn champion", true)

  flag(FLAG_KANTO_CHAMPION, true)
  expectRematch("kanto", "kanto champion", true)
  expectNoOffer("johto", "kanto champion")

  flag(FLAG_JOHTO_CHAMPION, true)
  expectRematch("johto", "johto champion", false)
  expectRematch("hoenn", "three-region champion", false)

  F.check("no crash screen", not F.reportCrash("end"))
  F.shot("end")
  F.finish()
end)
