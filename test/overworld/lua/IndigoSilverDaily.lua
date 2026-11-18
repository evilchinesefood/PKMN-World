-- Silver's once-a-day rematch in the Johto Indigo Plateau Pokemon Center. Route 27's first steps
-- hide him (FLAG_HIDE_INDIGO_PLATEAU_SILVER) and upstream HnS brought him back after a post-League
-- Mt. Moon fight that was never ported, so nothing here ever showed him again. His script records
-- the win in FLAG_DAILY_BEAT_SILVER, which lives in the Johto flag bank outside the daily window
-- ClearDailyFlags wipes, so even a shown Silver would refuse every rematch after the first.
--
-- From a fresh game the suite leaves the state Route 27 leaves (Silver hidden), sets the wall clock
-- the way New Bark's clock does, checks Silver is absent before the League, then plays the Johto
-- Hall of Fame from its own ON_FRAME scene to the title and continues at New Bark. In the Plateau
-- Center Silver must stand at (32,8); talking to him starts a battle (the foe's HP is zeroed, the
-- battle is not under test) and sets the daily flag; a second talk the same day starts none. The
-- emulator's RTC then runs past midnight, the player leaves the Center (DoTimeBasedEvents never
-- runs inside one) and comes back: the flag must be clear and Silver must battle again.
--
-- Run via test/overworld/mgba-run.sh test/overworld/lua/IndigoSilverDaily.lua <rom> --env PW_MAX_FRAMES=900000

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "IndigoSilverDaily")

local HUB_GROUP = 100
local ROW_PARTY_MENU, ROW_SET = 2, 9
local REGION_VARS_START, FLAG_JOHTO_BASE = 0xA000, 0x6000
local VAR_LEAGUE_STATE = 0xA080 + 0x3B
local VAR_DAYS = 0x4040
local FLAG_SYS_CLOCK_SET = 0x948 + 0x35
local FLAG_JOHTO_CHAMPION = 0xA49
local FLAG_HIDE_INDIGO_PLATEAU_SILVER = FLAG_JOHTO_BASE + 0x1E7
local FLAG_DAILY_BEAT_SILVER = FLAG_JOHTO_BASE + 0x1F1
local GRP_PLATEAU, MAP_OUTSIDE, MAP_CENTER, MAP_HOF = 99, 3, 4, 10
local NEWBARK_G, NEWBARK_M = 75, 0
local SILVER_LOCALID, SILVER_X, SILVER_Y = 7, 32, 8
local CONTEXT_RUNNING = 0
local PKMN_SIZE, OFF_HP = S.Pokemon.size, S.Pokemon.hp
local BP_STRIDE, BP_HP = S.BattlePokemon.size, S.BattlePokemon.hp
-- Wound to 23:56, so five minutes of frames always cross midnight.
local WAIT_FRAMES = 5 * 3600

local function d(n) return (n // 100) % 10, (n // 10) % 10, n % 10 end
local function warp(g, m, w, tag)
  local gh, gt, go = d(g)
  local mh, mt, mo = d(m)
  local wh, wt, wo = d(w)
  return F.warpTo(gh, gt, go, mh, mt, mo, wh, wt, wo, g, m, tag)
end
local function tapDown(n) for _ = 1, n do F.press("Down", 3); F.idle(16) end end
local function where() local x, y = F.pos(); return string.format("%d/%d (%d,%d)", F.grp(), F.mapn(), x, y) end

local function sb1Flag(id, on)
  local a, m = F.sb1() + S.SaveBlock1.flags + (id // 8), 1 << (id % 8)
  if on == nil then return (F.r8(a) & m) ~= 0 end
  F.w8(a, on and (F.r8(a) | m) or (F.r8(a) & ~m & 0xFF))
end
local function johtoFlag(id, on)
  local a, m = F.sb3() + S.SaveBlock3.johtoFlags + ((id - FLAG_JOHTO_BASE) // 8), 1 << (id % 8)
  if on == nil then return (F.r8(a) & m) ~= 0 end
  F.w8(a, on and (F.r8(a) | m) or (F.r8(a) & ~m & 0xFF))
end
local function regionVarSet(id, v) F.w16(F.sb3() + S.SaveBlock3.regionVars + (id - REGION_VARS_START) * 2, v) end
local function var(id, v)
  local a = F.sb1() + S.SaveBlock1.vars + (id - 0x4000) * 2
  if v == nil then return F.r16(a) end
  F.w16(a, v)
end

local function now()
  local t = S.gLocalTime
  return F.rs16(t + S.Time.days), F.rs8(t + S.Time.hours), F.rs8(t + S.Time.minutes), F.rs8(t + S.Time.seconds)
end
local function clock() local dd, h, m, s = now(); return string.format("day %d %02d:%02d:%02d", dd, h, m, s) end
-- gLocalTime = RTC - localTimeOffset; move the offset so the local clock reads the target.
local function windTo(days, h, m)
  local o = F.sb2() + S.SaveBlock2.localTimeOffset
  local function secs(dd, hh, mm, ss) return ((dd * 24 + hh) * 60 + mm) * 60 + ss end
  local d0, h0, m0, s0 = now()
  local off = secs(F.rs16(o), F.rs8(o + 2), F.rs8(o + 3), F.rs8(o + 4))
  local rtc = secs(d0, h0, m0, s0) + off
  local new = rtc - secs(days, h, m, 0)
  local nd = new // 86400
  local r = new - nd * 86400
  F.w16(o, nd & 0xFFFF); F.w8(o + 2, r // 3600); F.w8(o + 3, (r % 3600) // 60); F.w8(o + 4, r % 60)
end

local function hasControl()
  return F.ow() and F.r8(S.sLockFieldControls) == 0 and F.r8(S.sGlobalScriptContextStatus) ~= CONTEXT_RUNNING
end
local function awaitControl(budget)
  local calm = 0
  for i = 1, budget or 3000 do
    calm = hasControl() and calm + 1 or 0
    if calm >= 30 then return true end
    if calm == 0 and i % 20 == 0 then F.press("B", 2) else F.idle(1) end
  end
  return hasControl()
end

local function silver()
  for i = 0, 15 do
    local a = S.gObjectEvents + i * S.ObjectEvent.stride
    if F.r8(a) & 1 ~= 0 and F.r8(a + S.ObjectEvent.localId) == SILVER_LOCALID then
      return {
        x = F.rs16(a + S.ObjectEvent.x) - 7, y = F.rs16(a + S.ObjectEvent.y) - 7,
        visible = (F.r8(a + S.ObjectEvent.flags1) & 0x20) == 0,
      }
    end
  end
  return nil
end

local function setParty()
  F.dbg(); F.idle(60)
  tapDown(ROW_PARTY_MENU); F.press("A", 3); F.idle(60)
  tapDown(ROW_SET); F.press("A", 3); F.idle(180)
  for _ = 1, 6 do F.press("B", 3); F.idle(20) end
end

local function isFrontEnd(c)
  return c == S.MainCB2_Intro or c == S.CB2_InitCopyrightScreenAfterBootup
    or c == S.MainCB2_WorldTitleScreen or c == S.CB2_InitMainMenu or c == S.CB2_MainMenu
    or c == S.CB2_InitTitleScreen
end

-- The Center's own ON_FRAME turns League state 6 back into 1, so leave it before arming the room.
local function hallOfFame()
  if not warp(NEWBARK_G, NEWBARK_M, 0, "newbark") then return false, "warp " .. where() end
  regionVarSet(VAR_LEAGUE_STATE, 6)
  if not warp(GRP_PLATEAU, MAP_HOF, 0, "hof") then return false, "warp " .. where() end
  for f = 1, 60000 do
    if isFrontEnd(F.cb2()) then return true, f end
    if f % 600 == 0 and F.reportCrash("hof" .. f) then return false, "crash" end
    if f % 12 == 0 then F.press("A", 2) else F.idle(1) end
  end
  return false, string.format("cb2=%08X", F.cb2())
end

local function continueFromFrontEnd()
  for _ = 1, 3000 do
    local c = F.cb2()
    if c == S.MainCB2_WorldTitleScreen or c == S.CB2_MainMenu then break end
    if c == S.MainCB2_Intro then F.press("Start", 2) end
    F.idle(1)
  end
  if F.cb2() == S.MainCB2_WorldTitleScreen then F.idle(120); F.press("Start", 2) end
  for _ = 1, 600 do if F.cb2() == S.CB2_MainMenu then break end F.idle(1) end
  F.idle(90)
  if F.cb2() ~= S.CB2_MainMenu then return false end
  F.press("A", 2)
  for _ = 1, 3000 do if F.ow() then break end F.idle(1) end
  return F.ow()
end

-- Into the Center from its door and up to the tile below Silver, facing him.
local function enterCenter(tag)
  if not warp(GRP_PLATEAU, MAP_OUTSIDE, 0, tag .. "_out") then return false end
  awaitControl(1200)
  if not warp(GRP_PLATEAU, MAP_CENTER, 0, tag .. "_in") then return false end
  awaitControl(1200)
  return true
end
-- Silver stands 13 tiles east of the door, outside the spawn window, so look from (32,12).
local function lookForSilver(tag)
  for _ = 1, 3 do
    if F.route({ { 19, 12 }, { 32, 12 } }, tag) then break end
    awaitControl(600)
  end
  F.idle(20)
  F.L(string.format("  %s: at %s hide flag=%s", tag, where(), tostring(johtoFlag(FLAG_HIDE_INDIGO_PLATEAU_SILVER))))
  return silver()
end
local function walkToSilver(tag)
  for _ = 1, 3 do
    if F.route({ { 19, 12 }, { 32, 12 }, { SILVER_X, SILVER_Y + 1 } }, tag) then
      F.face("Up")
      return true
    end
    awaitControl(600)
  end
  return false
end

-- Silver brings a full team, so keep zeroing the foe's HP (party and active battler) until it ends.
local function koFoes()
  for i = 0, 5 do F.w16(S.gParties + 6 * PKMN_SIZE + i * PKMN_SIZE + OFF_HP, 0) end
  F.w16(S.gBattleMons + BP_STRIDE + BP_HP, 0)
end

-- Talk to Silver and page his lines. Returns whether a battle started and how it ended.
local function talk(tag)
  F.press("A", 2)
  local battled, inBattle, outcome = false, 0, nil
  for f = 1, 12000 do
    if not F.ow() and F.battlers() > 0 then
      battled = true
      inBattle = inBattle + 1
      if inBattle > 240 and inBattle % 60 == 0 then koFoes() end
    end
    if battled and F.ow() and not outcome then outcome = F.outcome() end
    if f > 60 and F.ow() and hasControl() then
      F.idle(30)
      if hasControl() then break end
    end
    if f % 600 == 0 and F.reportCrash(tag .. f) then break end
    if f % 20 == 0 then F.press((battled and F.ow()) and "B" or "A", 2) else F.idle(1) end
  end
  return battled, outcome or 0
end

F.run(function()
  if not F.boot(HUB_GROUP) then F.check("boot to the hub", false); F.finish(); return end
  F.idle(40)
  setParty()
  F.check("setup: Set Party published a party", F.r8(S.gPartiesCount) ~= 0)
  -- What Route 27's first steps leave: Silver hidden. What a wall clock leaves: the flag and the day.
  johtoFlag(FLAG_HIDE_INDIGO_PLATEAU_SILVER, true)
  sb1Flag(FLAG_SYS_CLOCK_SET, true)
  var(VAR_DAYS, (now()))

  if not F.check("before the League: into the Plateau Center", enterCenter("pre"), where()) then F.finish(); return end
  local s0 = lookForSilver("pre")
  F.check("before the League: Silver is not in the Center", s0 == nil or not s0.visible,
    s0 and string.format("at (%d,%d)", s0.x, s0.y) or "absent")
  F.shot("pre_league_center")

  local ok, info = hallOfFame()
  F.check("the Johto Hall of Fame plays to the title", ok, tostring(info))
  if not ok then F.shot("hof_stuck"); F.finish(); return end
  F.check("Continue reaches the field", continueFromFrontEnd(), string.format("cb2=%08X", F.cb2()))
  F.check("Continue lands in New Bark", F.grp() == NEWBARK_G and F.mapn() == NEWBARK_M, where())
  F.check("the Hall of Fame made the player Johto champion", sb1Flag(FLAG_JOHTO_CHAMPION))
  awaitControl(3000)

  local today = (now())
  windTo(today, 23, 56)
  var(VAR_DAYS, today)
  if not F.check("champion: into the Plateau Center", enterCenter("champ"), where()) then F.finish(); return end
  F.L("  clock " .. clock() .. " VAR_DAYS=" .. var(VAR_DAYS))
  local s1 = lookForSilver("champ")
  F.shot("champion_center")
  F.check("champion: Silver stands at (32,8)", s1 ~= nil and s1.visible and s1.x == SILVER_X and s1.y == SILVER_Y,
    s1 and string.format("at (%d,%d) visible=%s", s1.x, s1.y, tostring(s1.visible)) or "no object")
  if not s1 or not s1.visible then F.finish(); return end

  if not F.check("champion: walk up to Silver", walkToSilver("first"), where()) then F.finish(); return end
  local battled, outcome = talk("first")
  F.check("first talk: Silver battles", battled)
  F.check("first talk: the battle is won", outcome == 1, "outcome=" .. outcome)
  F.check("first talk: today's rematch is recorded", johtoFlag(FLAG_DAILY_BEAT_SILVER))
  F.check("first talk: control returns", awaitControl(1200), where())
  F.shot("after_first_battle")

  F.face("Up")
  battled = talk("again")
  F.check("same day: a second talk starts no battle", not battled)
  F.check("same day: control returns", awaitControl(1200), where())

  local day0 = (now())
  for f = 1, WAIT_FRAMES do
    F.idle(1)
    if f % 600 == 0 and F.reportCrash("wait" .. f) then break end
  end

  if not F.check("next day: back into the Center", enterCenter("next"), where()) then F.finish(); return end
  F.L("  clock " .. clock() .. " VAR_DAYS=" .. var(VAR_DAYS) .. " (was day " .. day0 .. ")")
  F.check("next day: the clock reads a later day", (now()) > day0, clock())
  F.check("next day: VAR_DAYS recorded the new day", var(VAR_DAYS) == (now()), var(VAR_DAYS) .. " vs " .. (now()))
  F.check("next day: the daily rematch flag is clear", not johtoFlag(FLAG_DAILY_BEAT_SILVER))
  if not F.check("next day: walk up to Silver", walkToSilver("second"), where()) then F.finish(); return end
  battled, outcome = talk("second")
  F.check("next day: Silver battles again", battled)
  F.check("next day: the battle is won", outcome == 1, "outcome=" .. outcome)
  F.check("next day: control returns", awaitControl(1200), where())
  F.check("no crash screen", not F.reportCrash("end"))
  F.shot("end")
  F.finish()
end)
