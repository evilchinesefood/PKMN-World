-- Battles on fog maps start with no terrain, no fog weather and the authored battlefield.
--
-- Gen 3 fog was scenery. B_OVERWORLD_FOG was left at the expansion default GEN_LATEST, which makes
-- every battle on a fog map start under Misty Terrain for the whole fight (FIELD_EFFECT_OVERWORLD_
-- TERRAIN, src/battle_util.c) and swaps the authored background for the pink Misty Terrain art.
-- Flannery's burns failed against grounded Pokemon, and so did every status move at Groudon,
-- Kyogre, Mt. Pyre and Pokemon Tower.
--
-- Setup: debug gives two Lv. 5 Pokemon and warps beside the encounter tiles or the Leader. Wild
-- battles start by walking in Rusturf Tunnel and on Pokemon Tower 3F; Flannery's starts by talking
-- to her in the Lavaridge Gym. At the first action menu the suite reads the overworld weather (the
-- map's fog must be up), gFieldStatuses, gBattleWeather, and BG palette banks 2-4 against the day
-- palette the battle's captured presentation points at (none of these maps take a time tint).
--
-- Run via test/overworld/mgba-run.sh test/overworld/lua/OverworldFogBattle.lua
-- (FOG_CASE=name,name runs a subset of CASES).

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "OverworldFogBattle")

local HUB_GROUP = 100
local CONTEXT_SHUTDOWN = 2
local BM = S.BattlePokemon
local BM_ABILITY = 32
local ABILITY_RUN_AWAY = 50
local ACTION_RUN = 3
local B_OUTCOME_RAN = 4
local WEATHER_CURR = 0x210
local WEATHER_FOG_HORIZONTAL = 6
local STATUS_FIELD_MISTY_TERRAIN = 1 << 7
local STATUS_FIELD_TERRAIN_ANY = (1 << 6) | (1 << 7) | (1 << 8) | (1 << 9)
local B_WEATHER_FOG = 1 << 8
local SPECIES_MARSHTOMP, SPECIES_COMBUSKEN = 259, 256
local PRESENTATION_BYTES = 3 * 16 * 2

local function d(n) return (n // 100) % 10, (n // 10) % 10, n % 10 end
local function hexs(s) return (s:gsub(".", function(c) return string.format("%02X", c:byte()) end)) end
local function inBattle() return F.cb2() == (S.BattleMainCB2 & ~1) end
local function ctrl(b) return F.r32(S.gBattlerControllerFuncs + b * 4) & ~1 end
local function isAction()
  for _, p in ipairs(S.ActionInputFunctions) do if ctrl(0) == (p & ~1) then return true end end
  return false
end
local function options() return F.sb2() + S.SaveBlock2.optionsU16 end
local function instantText() F.w16(options(), (F.r16(options()) & ~7) | 3) end
local function hasControl()
  return F.ow() and F.r8(S.sLockFieldControls) == 0 and F.r8(S.sGlobalScriptContextStatus) == CONTEXT_SHUTDOWN
end

-- The debug species field starts at 1, so it yields 1 + the spun value.
local function giveMon(species)
  local v = species - 1
  F.dbg(); F.sel(3); F.sel(1); F.idle(20)
  F.spin(v // 100, (v // 10) % 10, v % 10); F.idle(20); F.spin(0, 0, 5); F.idle(60); F.bOut(4)
end

local function warpToCoords(grp, map, x, y, tag)
  for _ = 1, 4 do
    F.dbg(); F.sel(0); F.sel(1); F.idle(20)
    F.spin(d(grp)); F.spin(d(map))
    F.press("A", 2)
    for _ = 1, 400 do
      F.w8(S.sWarpDestination + 2, 0xFF)
      F.w16(S.sWarpDestination + 4, x)
      F.w16(S.sWarpDestination + 6, y)
      F.idle(1)
      local px, py = F.pos()
      if F.ow() and F.grp() == grp and F.mapn() == map and px == x and py == y then F.idle(90); return true end
    end
    F.bOut(5)
  end
  F.shot(tag .. "_warpfail")
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

local function authoredPalette()
  local p = F.r32(S.sBattlePresentation + S.BattlePresentation.dayPalette)
  local tinted = F.r8(S.sBattlePresentation + S.BattlePresentation.tintWithTime) ~= 0
  if p < 0x08000000 or p >= 0x0A000000 then return nil, tinted, p end
  return memory.readbyterange(p, PRESENTATION_BYTES), tinted, p
end

local function firstDiff(a, b)
  for i = 1, #a, 2 do
    if a:sub(i, i + 1) ~= b:sub(i, i + 1) then
      return string.format("color %d: %s -> %s", (i - 1) // 2, hexs(a:sub(i, i + 1)), hexs(b:sub(i, i + 1)))
    end
  end
  return ""
end

local function fogUp() return F.r8(S.gWeather + WEATHER_CURR) == WEATHER_FOG_HORIZONTAL end

-- The battle as it stands at the first action menu.
local function judge(tag)
  local ready = false
  for i = 1, 3000 do
    F.idle(1)
    if F.reportCrash(tag) then break end
    if isAction() then ready = true; break end
    if i > 300 and i % 30 == 0 then F.press("B", 2) end
  end
  if not F.check(tag .. ": the action menu opens", ready) then F.shot(tag .. "_noaction"); return end
  F.idle(30)
  F.shot(tag .. "_field")
  local field, weather = F.r32(S.gFieldStatuses), F.r16(S.gBattleWeather)
  local authored, tinted, ptr = authoredPalette()
  local drawn = memory.readbyterange(S.gPlttBufferUnfaded + 0x40, PRESENTATION_BYTES)
  F.L(string.format("%s: environment %d, flags %X, weather %X, terrain %X, day palette %08X tinted=%s",
    tag, F.r8(S.gBattleEnvironment), F.battleFlags(), weather, field, ptr, tostring(tinted)))
  F.check(tag .. ": no Misty Terrain", field & STATUS_FIELD_MISTY_TERRAIN == 0, string.format("gFieldStatuses=%X", field))
  F.check(tag .. ": no terrain at all", field & STATUS_FIELD_TERRAIN_ANY == 0, string.format("gFieldStatuses=%X", field))
  F.check(tag .. ": no fog weather", weather & B_WEATHER_FOG == 0, string.format("gBattleWeather=%X", weather))
  if F.check(tag .. ": the presentation names an authored day palette", authored ~= nil and not tinted,
    string.format("ptr=%08X tinted=%s", ptr, tostring(tinted))) then
    F.check(tag .. ": the battlefield palette is the authored one", drawn == authored, firstDiff(authored, drawn))
  end
end

local function outro()
  for i = 1, 3000 do
    if hasControl() then break end
    F.idle(1)
    if i % 30 == 0 then F.press("B", 2) end
  end
  F.idle(60)
end

local function runAway(tag)
  for _ = 1, 10 do
    if not inBattle() then break end
    if isAction() then
      F.w16(S.gBattleMons + BM_ABILITY, ABILITY_RUN_AWAY)
      if steer(ACTION_RUN) then F.press("A", 2) end
    end
    for i = 1, 400 do
      if not inBattle() or (i > 60 and isAction()) then break end
      F.idle(1)
      if i % 30 == 0 then F.press("B", 2) end
    end
  end
  F.check(tag .. ": the player runs from the battle", not inBattle() and F.outcome() == B_OUTCOME_RAN,
    string.format("inBattle=%s outcome=%d", tostring(inBattle()), F.outcome()))
  outro()
end

local function loseBattle(tag)
  for _ = 1, 3 do
    if not inBattle() then break end
    for s = 0, 5 do
      local b = S.gParties + s * S.Pokemon.size
      if F.r16(b + S.Pokemon.hp) ~= 0 then F.w16(b + S.Pokemon.hp, 0) end
    end
    F.w16(S.gBattleMons + BM.hp, 0)
    for i = 1, 3000 do
      if not inBattle() then break end
      F.idle(1)
      if isAction() then F.press("A", 2); F.idle(20); F.press("A", 2); F.idle(20); F.press("A", 2)
      elseif i % 30 == 0 then F.press("B", 2) end
    end
  end
  outro()
  F.check(tag .. ": control returns after the whiteout", hasControl())
end

local function healParty()
  for s = 0, 5 do
    local b = S.gParties + s * S.Pokemon.size
    if F.r16(b + S.Pokemon.maxHP) ~= 0 then F.w16(b + S.Pokemon.hp, F.r16(b + S.Pokemon.maxHP)) end
  end
end

local function wildCase(tag, c)
  if not F.check(tag .. ": arrives", warpToCoords(c.grp, c.map, c.x, c.y, tag)) then return end
  instantText()
  F.idle(60)
  F.check(tag .. ": the map's fog is up", fogUp(), "currWeather=" .. F.r8(S.gWeather + WEATHER_CURR))
  local started = false
  for i = 1, 800 do
    if inBattle() then started = true; break end
    F.step(c.dirs[(i % #c.dirs) + 1])
    if F.reportCrash(tag) then break end
  end
  if F.check(tag .. ": a wild battle starts", started) then
    judge(tag)
    runAway(tag)
  end
end

local function trainerCase(tag, c)
  if not F.check(tag .. ": arrives", warpToCoords(c.grp, c.map, c.x, c.y, tag)) then return end
  instantText()
  F.idle(60)
  F.check(tag .. ": the map's fog is up", fogUp(), "currWeather=" .. F.r8(S.gWeather + WEATHER_CURR))
  F.face(c.face); F.press("A", 2)
  local started = false
  for i = 1, 4000 do
    if inBattle() then started = true; break end
    if F.reportCrash(tag) then break end
    if i % 20 == 0 then F.press("A", 2) else F.idle(1) end
  end
  if not F.check(tag .. ": the trainer battle starts", started) then F.shot(tag .. "_nostart"); return end
  judge(tag)
  loseBattle(tag)
end

local LR = { "Left", "Right" }
local CASES = {
  { "rusturf_tunnel", { grp = 24, map = 4, x = 10, y = 5, dirs = LR } },
  { "flannery", { trainer = true, grp = 4, map = 1, x = 13, y = 10, face = "Up" } },
  { "pokemon_tower_3f", { grp = 35, map = 90, x = 9, y = 7, dirs = LR } },
}

F.run(function()
  if not F.boot(HUB_GROUP) then F.check("boot", false); F.finish(); return end
  giveMon(SPECIES_MARSHTOMP)
  giveMon(SPECIES_COMBUSKEN)
  F.check("two Pokemon in the party", F.r8(S.gPartiesCount) >= 2, "n=" .. F.r8(S.gPartiesCount))
  local only = os.getenv("FOG_CASE")
  local want
  if only then want = {}; for n in only:gmatch("[^,]+") do want[n] = true end end
  for _, entry in ipairs(CASES) do
    local tag, c = entry[1], entry[2]
    if not want or want[tag] then
      healParty()
      if c.trainer then trainerCase(tag, c) else wildCase(tag, c) end
    end
  end
  F.finish()
end)
