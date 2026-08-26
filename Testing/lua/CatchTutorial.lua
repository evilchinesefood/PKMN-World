-- Issue #120 playtest B: Kanto catch tutorial must not say WALLY.
--
-- src/battle_message.c:3537 GetCurrentRegion()==REGION_KANTO → "The old man" else "WALLY".
-- src/battle_controllers.c:277 CATCH_TUTORIAL → SetControllerToOakOrOldMan vs SetControllerToWally.
-- StartOldManTutorialBattle creates WEEDLE; StartWallyTutorialBattle creates RALTS.
--
-- WHAT WOULD FAIL ON THE PRE-FIX ARM. Before the merge, IS_FRLG was hard-0 in an
-- ALL_REGIONS build, so the WALLY branch always ran — including during a Kanto
-- catch tutorial. The load-bearing assert is kanto_text_has_no_WALLY: a Viridian
-- Old Man battle whose gDisplayedStringBattle contains "WALLY" fails. The matching
-- positive asserts (OLD MAN / WEEDLE, and the Petalburg control that still says
-- WALLY / RALTS) stop that check from being a vacuous "string never appeared".
--
-- Authentic path: warp Viridian, VAR_MAP_SCENE_VIRIDIAN_CITY_OLD_MAN=1, walk onto
-- (20,8) or (22,8). Control: warp Petalburg first (region Hoenn), then debug
-- Utilities → Wally Tutorial.
--
-- Run via Testing/mgba-run.sh Testing/lua/CatchTutorial.lua

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "CatchTutorial")

local HUB_GROUP = 100
local ROW_PARTY, ROW_SET = 2, 9
local ROW_UTIL, ROW_WALLY = 0, 10
local B_CATCH_TUTORIAL = 1 << 9
local REGION_KANTO, REGION_HOENN = 1, 3
local GRP_VIRIDIAN, MAP_VIRIDIAN = 37, 1
local GRP_PETALBURG, MAP_PETALBURG = 0, 0
local VAR_OLD_MAN = 0xA02A          -- VAR_KANTO_SLICE(0x2A)
local REGION_VARS_START = 0xA000
local TRIGGER_L = { 20, 8 }
local TRIGGER_R = { 22, 8 }
local MAN_TALK = { 21, 7 }

local function d(n) return (n // 100) % 10, (n // 10) % 10, n % 10 end

local function tap(n)
  for _ = 1, n do F.press("Down", 3); F.idle(16) end
end

local function go(grp, map, warp, tag)
  local gh, gt, go_ = d(grp)
  local mh, mt, mo = d(map)
  local wh, wt, wo = d(warp)
  if not F.warpTo(gh, gt, go_, mh, mt, mo, wh, wt, wo, grp, map, tag) then
    F.check(tag .. "_warped", false, string.format("grp=%d map=%d", F.grp(), F.mapn()))
    return false
  end
  F.idle(60)
  return true
end

local function setParty()
  F.dbg(); F.idle(60)
  tap(ROW_PARTY); F.press("A", 3); F.idle(60)
  tap(ROW_SET); F.press("A", 3); F.idle(180)
  for _ = 1, 8 do F.press("B", 3); F.idle(20) end
end

local function regionVarSet(id, v)
  F.w16(F.sb3() + S.SaveBlock3.regionVars + (id - REGION_VARS_START) * 2, v)
end

local function pokeChar(b)
  if b == 0xFF or b == 0xFA or b == 0xFB then return "" end
  if b == 0xFE then return "\n" end
  if b == 0x00 then return " " end
  if b == 0x1B then return "e" end          -- CHAR é; search uses ASCII
  if b >= 0xA1 and b <= 0xAA then return string.char(48 + (b - 0xA1)) end
  if b >= 0xBB and b <= 0xD4 then return string.char(65 + (b - 0xBB)) end
  if b >= 0xD5 and b <= 0xEE then return string.char(97 + (b - 0xD5)) end
  if b == 0xAE then return "-" end
  if b == 0xAD then return "." end
  if b == 0xAC then return "?" end
  if b == 0xAB then return "!" end
  if b == 0xB8 then return "," end
  return ""
end

local function pokeStr(addr, n)
  if not addr or addr == 0 then return "" end
  local t = {}
  for i = 0, (n or 80) - 1 do
    local b = F.r8(addr + i)
    if b == 0xFF then break end
    t[#t + 1] = pokeChar(b)
  end
  return table.concat(t)
end

local function battleText()
  return pokeStr(S.gDisplayedStringBattle, 200)
end

local function walkTo(tx, ty, tag)
  for n = 1, 160 do
    if F.reportCrash("walk_" .. tag) then return false end
    local x, y = F.pos()
    if x == tx and y == ty then return true end
    -- A coord-event script may already have taken the overworld.
    if not F.ow() then return true end
    local tried = {}
    local function try(dir)
      if not dir or tried[dir] then return false end
      tried[dir] = true
      return F.step(dir)
    end
    local moved = false
    if math.abs(x - tx) >= math.abs(y - ty) then
      if x < tx then moved = try("Right") elseif x > tx then moved = try("Left") end
      if not moved then
        if y < ty then moved = try("Down") elseif y > ty then moved = try("Up") end
      end
    else
      if y < ty then moved = try("Down") elseif y > ty then moved = try("Up") end
      if not moved then
        if x < tx then moved = try("Right") elseif x > tx then moved = try("Left") end
      end
    end
    if not moved then
      for _, dir in ipairs({ "Left", "Right", "Up", "Down" }) do
        if try(dir) then moved = true; break end
      end
    end
    if not moved then
      F.L(string.format("  walk %s blocked at (%d,%d)->(%d,%d) n=%d", tag, x, y, tx, ty, n))
      F.shot(tag .. "_stuck")
      return false
    end
  end
  local x, y = F.pos()
  F.L(string.format("  walk %s exhausted at (%d,%d)", tag, x, y))
  F.shot(tag .. "_stuck")
  return x == tx and y == ty
end

-- Harvest every expanded battle line. CATCH_TUTORIAL autoplays; mash A/B so
-- printers finish. Shot the first time we see each required phrase.
local function watchTutorial(tag, budget)
  local seen, shots = {}, {}
  local function consider(s)
    if s == "" or seen[s] then return end
    seen[s] = true
    local u = s:upper()
    F.L("  [" .. tag .. " text] " .. s:gsub("\n", " | "))
    if not shots.oldman and (u:find("OLD MAN", 1, true) or u:find("THE OLD MAN", 1, true)) then
      F.shot(tag .. "_old_man_line"); shots.oldman = true
    end
    if not shots.wally and u:find("WALLY", 1, true) then
      F.shot(tag .. "_wally_line"); shots.wally = true
    end
    if not shots.weedle and u:find("WEEDLE", 1, true) then
      F.shot(tag .. "_weedle"); shots.weedle = true
    end
    if not shots.ralts and u:find("RALTS", 1, true) then
      F.shot(tag .. "_ralts"); shots.ralts = true
    end
    if not shots.gotcha and u:find("GOTCHA", 1, true) then
      F.shot(tag .. "_gotcha"); shots.gotcha = true
    end
    if not shots.ball and u:find("USED", 1, true) and u:find("BALL", 1, true) then
      F.shot(tag .. "_used_ball"); shots.ball = true
    end
  end
  local blob = {}
  for i = 1, budget do
    if i % 8 == 0 then F.press("A", 1) end
    if i % 24 == 0 then F.press("B", 1) end
    F.idle(1)
    if i % 4 == 0 then
      local s = battleText()
      if s ~= "" then
        consider(s)
        blob[#blob + 1] = s
      end
    end
    if i % 60 == 0 and F.reportCrash(tag) then break end
    -- Stay in the watch until the tutorial battle is over, but keep sampling
    -- a little after CB2 returns so the last "Gotcha" line is not missed.
    if F.ow() and i > 90 and (F.battleFlags() & B_CATCH_TUTORIAL) == 0 then
      F.idle(30)
      consider(battleText())
      break
    end
  end
  F.shot(tag .. "_end")
  -- Unique-preserving concat for the asserts.
  local uniq, out = {}, {}
  for _, s in ipairs(blob) do
    if not uniq[s] then uniq[s] = true; out[#out + 1] = s end
  end
  return table.concat(out, " || "):upper()
end

local function waitCatchBattle(tag)
  for i = 1, 900 do
    if i % 12 == 0 then F.press("A", 2) end
    F.idle(2)
    if (F.battleFlags() & B_CATCH_TUTORIAL) ~= 0 or (not F.ow() and F.battleFlags() ~= 0) then
      for _ = 1, 120 do
        F.idle(2)
        if F.battlers() >= 1 then return true end
      end
      return true
    end
    if i % 60 == 0 and F.reportCrash(tag) then return false end
  end
  return (F.battleFlags() & B_CATCH_TUTORIAL) ~= 0
end

F.run(function()
  if not F.boot(HUB_GROUP) then F.check("boot to the hub", false); F.finish(); return end
  F.check("player is free before the debug work", F.ensureFree())

  setParty()
  F.check("Set Party published a non-empty party", F.r8(S.gPartiesCount) ~= 0,
    "count=" .. F.r8(S.gPartiesCount))
  F.shot("after_set_party")

  -- Seed the var BEFORE the warp so Viridian ON_TRANSITION places the tutorial
  -- man at (21,8) and arms the (20,8)/(22,8) coord events.
  regionVarSet(VAR_OLD_MAN, 1)
  if not go(GRP_VIRIDIAN, MAP_VIRIDIAN, 0, "viridian") then F.finish(); return end
  F.check("on Viridian City", F.grp() == GRP_VIRIDIAN and F.mapn() == MAP_VIRIDIAN,
    string.format("grp=%d map=%d", F.grp(), F.mapn()))
  F.check("gCurrentRegion is Kanto", F.r8(S.gCurrentRegion) == REGION_KANTO,
    "region=" .. F.r8(S.gCurrentRegion))
  F.shot("viridian_arrival")

  -- Warp 0 lands one tile south of the PC door. NEVER step Up — that walks
  -- into MAP_VIRIDIAN_CITY_POKEMON_CENTER_1F. The dirt path runs west.
  local px, py = F.pos()
  F.L(string.format("  viridian arrival (%d,%d); pathing west then north", px, py))
  local triggered = false
  if F.ow() then
    -- Around the PC, then north up the main road onto (22,8).
    F.route({ { 21, py }, { 21, 16 }, { 22, 12 }, { 22, 8 } }, "to_old_man")
    local x, y = F.pos()
    triggered = (not F.ow()) or (x == 22 and y == 8) or (x == 20 and y == 8)
    F.L(string.format("  after route (%d,%d) ow=%s", x, y, tostring(F.ow())))
  end
  if F.ow() and not triggered then
    triggered = walkTo(TRIGGER_R[1], TRIGGER_R[2], "trigger_r")
  end
  if F.ow() and not triggered then
    triggered = walkTo(TRIGGER_L[1], TRIGGER_L[2], "trigger_l")
  end
  if F.ow() and not triggered then
    F.L("  coord event missed; talking to the tutorial man")
    walkTo(MAN_TALK[1], MAN_TALK[2], "talk_man")
    F.face("Up")
    F.shot("facing_old_man")
  end
  -- "I'll show you how to catch" then StartOldManTutorialBattle, or the
  -- talk script. Mash A either way.
  for _ = 1, 50 do
    if (F.battleFlags() & B_CATCH_TUTORIAL) ~= 0 or not F.ow() then break end
    F.press("A", 2); F.idle(16)
  end

  local kantoStarted = waitCatchBattle("kanto_enter")
  F.check("Kanto catch tutorial battle started", kantoStarted
    and (F.battleFlags() & B_CATCH_TUTORIAL) ~= 0,
    string.format("started=%s flags=0x%X region=%d",
      tostring(kantoStarted), F.battleFlags(), F.r8(S.gCurrentRegion)))
  F.check("region is still Kanto in the Old Man battle",
    F.r8(S.gCurrentRegion) == REGION_KANTO, "region=" .. F.r8(S.gCurrentRegion))
  F.shot("kanto_tutorial_start")

  local kantoText = watchTutorial("kanto", 4000)
  F.L("  kanto blob: " .. kantoText:sub(1, 400))
  F.check("kanto text names the old man",
    kantoStarted and kantoText:find("OLD MAN", 1, true) ~= nil, kantoText:sub(1, 180))
  F.check("kanto text names WEEDLE (StartOldManTutorialBattle)",
    kantoStarted and kantoText:find("WEEDLE", 1, true) ~= nil, kantoText:sub(1, 180))
  -- Load-bearing. Pre-fix IS_FRLG WALLY arm prints WALLY here.
  -- Require the battle to have started so an empty buffer cannot pass.
  F.check("kanto_text_has_no_WALLY",
    kantoStarted and kantoText:find("WALLY", 1, true) == nil, kantoText:sub(1, 240))

  for i = 1, 120 do
    F.press("A", 2); F.idle(16); F.press("B", 2); F.idle(12)
    if F.ow() and F.ensureFree() then break end
    if i % 20 == 0 and F.reportCrash("kanto_exit") then break end
  end
  F.shot("after_kanto_tutorial")

  -- ---- Petalburg Wally control -------------------------------------------------------------
  -- Warp FIRST so gCurrentRegion is Hoenn, then fire the debug script. Do NOT use
  -- Cheat start: DebugAction_Util_CheatStart uses IS_FRLG which is hard-0 here.
  if not F.ow() then
    F.w8(S.gBattleOutcome, 1)
    for _ = 1, 200 do F.idle(10); if F.ow() then break end end
  end
  if not go(GRP_PETALBURG, MAP_PETALBURG, 0, "petalburg") then F.finish(); return end
  F.check("on Petalburg City", F.grp() == GRP_PETALBURG and F.mapn() == MAP_PETALBURG,
    string.format("grp=%d map=%d", F.grp(), F.mapn()))
  F.check("gCurrentRegion is Hoenn for the Wally control",
    F.r8(S.gCurrentRegion) == REGION_HOENN, "region=" .. F.r8(S.gCurrentRegion))
  F.step("Down")
  F.shot("petalburg_arrival")

  F.dbg(); F.idle(60)
  tap(ROW_UTIL); F.press("A", 3); F.idle(60)
  tap(ROW_WALLY); F.shot("wally_tutorial_cursor")
  F.press("A", 3); F.idle(200)

  local wallyStarted = waitCatchBattle("wally_enter")
  F.check("Wally catch tutorial battle started", wallyStarted
    and (F.battleFlags() & B_CATCH_TUTORIAL) ~= 0,
    string.format("started=%s flags=0x%X region=%d",
      tostring(wallyStarted), F.battleFlags(), F.r8(S.gCurrentRegion)))
  F.shot("wally_tutorial_start")

  local wallyText = watchTutorial("wally", 4000)
  F.L("  wally blob: " .. wallyText:sub(1, 400))
  F.check("wally text names WALLY",
    wallyText:find("WALLY", 1, true) ~= nil, wallyText:sub(1, 180))
  F.check("wally text names RALTS (StartWallyTutorialBattle)",
    wallyText:find("RALTS", 1, true) ~= nil, wallyText:sub(1, 180))
  F.check("wally_text_has_no_old_man",
    wallyText:find("OLD MAN", 1, true) == nil, wallyText:sub(1, 240))

  F.finish()
end)
