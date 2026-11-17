-- Move animations that replace or tint the battle background put the background back exactly.
--
-- PR #634 replaced every battle background and re-derived the Ice Path and Mt. Silver palettes;
-- #327 made the battlefield a captured presentation (art plus time tint) that restorebg, terrain
-- expiry and the Bag/Party return rebuild. This suite plays real battles across the new art and
-- uses moves whose animations fade to their own background (Psychic, Night Shade, Shadow Ball,
-- Crunch, Sky Attack, Cosmic Power, Fissure), shake or flash it (Earthquake, Magnitude), or set
-- weather over it, in grass by day and night, Ice Path, snowy Mt. Silver at night, a fog cave
-- (Misty Terrain from the overworld), a Route 41 thunderstorm while surfing (rain and Electric
-- Terrain), underwater, the Route 111 desert at night, long grass, Pokemon Tower's ghost battle,
-- a plain-ground trainer at night, a double battle, and Hoenn and Johto Leader stadiums. Safari
-- battles in Kanto, Johto and Hoenn check the intro and the return.
--
-- Setup: debug gives two Lv. 5 Pokemon (obedient with no badges) and warps; wild battles start by
-- walking on encounter tiles and trainer battles by talking. Each turn, before the move is chosen,
-- the suite writes the move into the battler's four slots and makes both sides sturdy (No Guard,
-- 1 Atk, a Focus Sash on the foe) so the battle lasts; the move is then picked with real input.
--
-- Oracles, all against the battlefield read at the first action menu:
--   * after every turn: BG palette banks 2-4 (unfaded and faded), the BG3 tilemap, every BG3 tile
--     the tilemap names, the BG3 scroll and BG3CNT are unchanged;
--   * the moves that fade to their own background did change it during the turn (the animation ran);
--   * from the first battle frame to the action menu the battlefield takes one state, or the
--     terrain set by overworld weather;
--   * after the battle the field's BG palette banks 0-12 equal those before it, and control returns.
--
-- Run via test/overworld/mgba-run.sh test/overworld/lua/BattleBgMoveAnims.lua
-- (BGS_CASE=name,name runs a subset of CASES).

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "BattleBgMoveAnims")

local HUB_GROUP = 100
local CONTEXT_SHUTDOWN = 2
local BM = S.BattlePokemon
local BM_DEFENSE, BM_SPEED, BM_SPDEF, BM_ABILITY, BM_TYPES, BM_LEVEL, BM_ITEM = 4, 6, 10, 32, 34, 44, 48
local ABILITY_NONE, ABILITY_RUN_AWAY, ABILITY_NO_GUARD = 0, 50, 99
local TYPE_FIRE, ITEM_FOCUS_SASH = 11, 481
local ACTION_RUN = 3
local VRAM_BG3_TILES, VRAM_BG3_MAP, REG_BG3CNT = 0x06008000, 0x0600D000, 0x0400000E
local FLAG_SYS_SAFARI_MODE = 0x948 + 0x2C
local SPECIES_MARSHTOMP, SPECIES_COMBUSKEN = 259, 256

local MOVES = { PSYCHIC = 94, NIGHT_SHADE = 101, SURF = 57, EARTHQUAKE = 89, FISSURE = 90,
  SHADOW_BALL = 247, CRUNCH = 242, FEINT_ATTACK = 185, SKY_ATTACK = 143, RAIN_DANCE = 240,
  SANDSTORM = 201, HAIL = 258, SUNNY_DAY = 241, ICE_BEAM = 58, CONFUSE_RAY = 109,
  COSMIC_POWER = 322, AURORA_BEAM = 62, PSYCHO_BOOST = 354, SOLAR_BEAM = 76, MAGNITUDE = 222 }
local OHKO = { [MOVES.FISSURE] = true }
-- Moves whose animation fades to a background of its own (fadetobg in data/battle_anim_scripts.s).
local OWN_BACKGROUND = { PSYCHIC = true, NIGHT_SHADE = true, SHADOW_BALL = true, CRUNCH = true,
  SKY_ATTACK = true, COSMIC_POWER = true, FISSURE = true }
local ALL = { "PSYCHIC", "NIGHT_SHADE", "SURF", "EARTHQUAKE", "SHADOW_BALL", "CRUNCH", "FEINT_ATTACK",
  "SKY_ATTACK", "RAIN_DANCE", "SANDSTORM", "HAIL", "SUNNY_DAY", "ICE_BEAM", "CONFUSE_RAY",
  "COSMIC_POWER", "PSYCHO_BOOST", "SOLAR_BEAM", "MAGNITUDE", "AURORA_BEAM", "FISSURE" }
local CORE = { "PSYCHIC", "NIGHT_SHADE", "EARTHQUAKE", "SHADOW_BALL", "SKY_ATTACK", "SUNNY_DAY", "FISSURE" }
local WEATHER = { "PSYCHIC", "RAIN_DANCE", "SANDSTORM", "HAIL", "SUNNY_DAY", "CRUNCH" }

local function d(n) return (n // 100) % 10, (n // 10) % 10, n % 10 end
local function hexs(s) return (s:gsub(".", function(c) return string.format("%02X", c:byte()) end)) end
local function inBattle() return F.cb2() == (S.BattleMainCB2 & ~1) end
local function ctrl(b) return F.r32(S.gBattlerControllerFuncs + b * 4) & ~1 end
local function isActionB(b)
  for _, p in ipairs(S.ActionInputFunctions) do if ctrl(b) == (p & ~1) then return true end end
  return false
end
local function isAction() return isActionB(0) end
local function animating() return F.r8(S.gAnimScriptActive) ~= 0 end
local function options() return F.sb2() + S.SaveBlock2.optionsU16 end
-- Instant text, battle scene on: the animations are the subject.
local function battleOptions() F.w16(options(), (F.r16(options()) & ~(7 | (1 << 10))) | 3) end
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

local function localTime() return F.rs8(S.gLocalTime + S.Time.hours), F.rs8(S.gLocalTime + S.Time.minutes) end
local function setClock(targetHour)
  local off = F.sb2() + S.SaveBlock2.localTimeOffset
  local h, m = localTime()
  local deltaMin = ((h * 60 + m) - (targetHour * 60 + 30)) % (24 * 60)
  local newMin = F.rs8(off + S.Time.minutes) + (deltaMin % 60)
  local carry = 0
  if newMin >= 60 then newMin, carry = newMin - 60, 1 end
  F.w8(off + S.Time.minutes, newMin % 60)
  F.w8(off + S.Time.hours, (F.rs8(off + S.Time.hours) + (deltaMin // 60) + carry) % 24)
  F.w8(S.sHoursOverride, 0)
end

local function sb1Flag(id, on)
  local a, m = F.sb1() + S.SaveBlock1.flags + (id // 8), 1 << (id % 8)
  F.w8(a, on and (F.r8(a) | m) or (F.r8(a) & ~m))
end

-- The battlefield: BG3 draws the background from palette banks 2-4.
local function maxTile(map)
  local m = 0
  for i = 1, #map, 2 do
    local v = (map:byte(i) | (map:byte(i + 1) << 8)) & 0x3FF
    if v > m then m = v end
  end
  return m
end
local function battlefield(tileCount)
  local map = memory.readbyterange(VRAM_BG3_MAP, 0x1000)
  tileCount = tileCount or (maxTile(map) + 1)
  return {
    palU = memory.readbyterange(S.gPlttBufferUnfaded + 0x40, 96),
    palF = memory.readbyterange(S.gPlttBufferFaded + 0x40, 96),
    map = map,
    tiles = memory.readbyterange(VRAM_BG3_TILES, tileCount * 32),
    bg3 = string.format("%d,%d", F.r16(S.gBattle_BG3_X), F.r16(S.gBattle_BG3_Y)),
    cnt = string.format("%04X", F.r16(REG_BG3CNT)),
    tileCount = tileCount,
  }
end
local function firstDiff(a, b, width)
  for i = 1, #a, width do
    if a:sub(i, i + width - 1) ~= b:sub(i, i + width - 1) then
      return string.format("@%X %s->%s", i - 1, hexs(a:sub(i, i + width - 1)), hexs(b:sub(i, i + width - 1)))
    end
  end
  return ""
end
local function diff(a, b)
  local out = {}
  for _, k in ipairs({ "palU", "palF", "map", "tiles", "bg3", "cnt" }) do
    if a[k] ~= b[k] then
      if k == "bg3" or k == "cnt" then out[#out + 1] = k .. " " .. a[k] .. "->" .. b[k]
      else out[#out + 1] = k .. firstDiff(a[k], b[k], 2) end
    end
  end
  return table.concat(out, "; ")
end

-- The field's tileset palettes (BG banks 0-12; 13-15 belong to message boxes and pop-ups).
local function fieldPalette() return memory.readbyterange(S.gPlttBufferFaded, 13 * 32) end

local function prepMons(move, b)
  local p, o = S.gBattleMons + b * BM.size, S.gBattleMons + BM.size
  for i = 0, 3 do F.w16(p + BM.moves + i * 2, move); F.w8(p + BM.pp + i, 20) end
  F.w16(p + BM.hp, F.r16(p + BM.maxHP)); F.w32(p + BM.status1, 0)
  F.w16(p + BM_ABILITY, ABILITY_NO_GUARD)
  F.w16(p + BM.attack, 1); F.w16(p + BM.spAttack, 1)
  F.w8(p + BM_LEVEL, OHKO[move] and 100 or 1)
  F.w16(p + BM_DEFENSE, 999); F.w16(p + BM_SPDEF, 999); F.w16(p + BM_SPEED, 999)
  for _, foe in ipairs({ o, o + 2 * BM.size }) do
    F.w16(foe + BM_ABILITY, ABILITY_NONE)
    for i = 0, 2 do F.w8(foe + BM_TYPES + i, TYPE_FIRE) end
    F.w16(foe + BM_DEFENSE, 999); F.w16(foe + BM_SPDEF, 999)
    F.w16(foe + BM_ITEM, ITEM_FOCUS_SASH)
    local hp, max = F.r16(foe + BM.hp), F.r16(foe + BM.maxHP)
    if hp ~= 0 and hp ~= max then F.w16(foe + BM.hp, max) end
  end
end

local function actFor(b, move)
  prepMons(move, b)
  F.press("A", 2); F.idle(20); F.press("A", 2); F.idle(20)
  if ctrl(b) == (S.HandleInputChooseTarget & ~1) then F.press("A", 2); F.idle(10) end
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

-- Plays until the next action menu ("ok"), the end of the battle ("ended") or a timeout.
local function runTurn(tag, monitor)
  for i = 1, 4000 do
    F.idle(1)
    if F.reportCrash(tag) then return "crash", i end
    if monitor then monitor(i) end
    if i > 30 and isAction() then return "ok", i end
    if not inBattle() then return "ended", i end
    if i > 150 and i % 40 == 0 and not animating() then F.press("B", 2) end
  end
  return "stuck", 4000
end

local function useMove(tag, name, base)
  local move = MOVES[name]
  actFor(0, move)
  if F.battlers() == 4 then
    for _ = 1, 120 do if isActionB(2) then break end; F.idle(1) end
    if isActionB(2) then actFor(2, move) end
  end
  local changed, shots = false, 0
  local res, frames = runTurn(tag, function(i)
    if not changed and (memory.readbyterange(S.gPlttBufferUnfaded + 0x40, 96) ~= base.palU
      or memory.readbyterange(VRAM_BG3_MAP, 0x1000) ~= base.map) then changed = true end
    if animating() and i % 16 == 0 and shots < 3 then shots = shots + 1; F.shot(tag .. "_" .. name) end
  end)
  if res ~= "ok" then
    F.L(string.format("%s %s: turn %s after %d frames", tag, name, res, frames))
    return res
  end
  F.idle(10)
  local dd = diff(base, battlefield(base.tileCount))
  F.L(string.format("%s %s: background changed=%s frames=%d weather=%X field=%X", tag, name, tostring(changed),
    frames, F.r16(S.gBattleWeather), F.r32(S.gFieldStatuses)))
  F.check(tag .. " " .. name .. ": the battlefield is restored exactly", dd == "", dd)
  if OWN_BACKGROUND[name] then F.check(tag .. " " .. name .. ": its own background was drawn", changed) end
  return "ok"
end

-- From the first battle frame to the action menu, then the moves.
local function battleBody(tag, moves, terrain)
  local seen, states = {}, {}
  local ready = false
  for i = 1, 2500 do
    F.idle(1)
    if F.reportCrash(tag) then break end
    local key = memory.readbyterange(S.gPlttBufferUnfaded + 0x40, 96) .. memory.readbyterange(VRAM_BG3_MAP, 0x1000)
    if not seen[key] then seen[key] = true; states[#states + 1] = i end
    if i % 6 == 0 and i < 150 then F.shot(tag .. "_intro") end
    if isAction() then ready = true; break end
    if i > 300 and i % 30 == 0 then F.press("B", 2) end
  end
  if not F.check(tag .. ": the action menu opens", ready) then F.shot(tag .. "_noaction"); return end
  F.idle(30)
  local base = battlefield()
  F.shot(tag .. "_field")
  F.L(string.format("%s: environment %d, flags %X, weather %X, terrain %X, hour %d, intro states at frames %s",
    tag, F.r8(S.gBattleEnvironment), F.battleFlags(), F.r16(S.gBattleWeather), F.r32(S.gFieldStatuses),
    localTime(), table.concat(states, ",")))
  if terrain then
    F.check(tag .. ": overworld weather sets a terrain", F.r32(S.gFieldStatuses) ~= 0)
  else
    F.check(tag .. ": the battlefield holds one state through the intro", #states == 1,
      "states at frames " .. table.concat(states, ","))
  end
  for _, mv in ipairs(moves) do
    if useMove(tag, mv, base) ~= "ok" then break end
  end
end

local function outro(tag)
  for i = 1, 400 do
    if not inBattle() then break end
    F.idle(1)
    if i % 30 == 0 then F.press("B", 2) end
  end
  for i = 1, 90 do
    F.idle(1)
    if i % 6 == 0 then F.shot(tag .. "_return") end
    if F.ow() and i > 45 then break end
  end
end

local function runAway(tag)
  for _ = 1, 4 do
    if not inBattle() then break end
    if isAction() then
      F.w16(S.gBattleMons + BM_ABILITY, ABILITY_RUN_AWAY) -- a foe's Mean Look must not trap the exit
      if steer(ACTION_RUN) then F.press("A", 2) end
    end
    for i = 1, 400 do
      if not inBattle() or (i > 60 and isAction()) then break end
      F.idle(1)
      if i % 30 == 0 then F.press("B", 2) end
    end
  end
  outro(tag)
  for i = 1, 3000 do
    if F.ow() then break end
    F.idle(1)
    if i % 30 == 0 then F.press("B", 2) end
  end
  F.idle(60)
end

local function loseBattle(tag)
  for _ = 1, 3 do
    if not inBattle() then break end
    for s = 0, 5 do
      local b = S.gParties + s * S.Pokemon.size
      if F.r16(b + S.Pokemon.hp) ~= 0 then F.w16(b + S.Pokemon.hp, 0) end
    end
    F.w16(S.gBattleMons + BM.hp, 0)
    F.w16(S.gBattleMons + 2 * BM.size + BM.hp, 0)
    for i = 1, 3000 do
      if not inBattle() then break end
      F.idle(1)
      if isAction() then F.press("A", 2); F.idle(20); F.press("A", 2); F.idle(20); F.press("A", 2)
      elseif i % 30 == 0 then F.press("B", 2) end
    end
  end
  outro(tag)
  for i = 1, 3000 do
    if hasControl() then break end
    F.idle(1)
    if i % 30 == 0 then F.press("A", 2) end
  end
  F.idle(60)
end

local function checkFieldReturn(tag, before, weatherFades)
  F.check(tag .. ": control returns to the field", F.ow())
  F.idle(30)
  -- Route 111's sandstorm coord events start a weather palette fade that the battle interrupts.
  if weatherFades then return end
  local now = fieldPalette()
  F.check(tag .. ": the field's palettes are the ones it left", now == before, firstDiff(before, now, 2))
end

-- Wild case: { grp, map, x, y | arrive, dirs, moves, hour, terrain, safari, weatherFades }
local function wildCase(tag, c)
  if c.hour then setClock(c.hour) end
  local arrived
  if c.arrive then arrived = c.arrive() else arrived = warpToCoords(c.grp, c.map, c.x, c.y, tag) end
  if not F.check(tag .. ": arrives", arrived) then return end
  if c.safari then sb1Flag(FLAG_SYS_SAFARI_MODE, true); F.w8(S.gNumSafariBalls, 30) end
  battleOptions()
  F.idle(60)
  local before = fieldPalette()
  local started = false
  for i = 1, 800 do
    if inBattle() then started = true; break end
    if hasControl() then before = fieldPalette() end
    F.step(c.dirs[(i % #c.dirs) + 1])
    if F.reportCrash(tag) then break end
  end
  if F.check(tag .. ": a wild battle starts", started) then
    battleBody(tag, c.moves, c.terrain)
    runAway(tag)
    checkFieldReturn(tag, before, c.weatherFades)
  end
  if c.safari then sb1Flag(FLAG_SYS_SAFARI_MODE, false) end
end

-- Trainer case: { grp, map, x, y, face, moves, hour }; the battle is lost on purpose.
local function trainerCase(tag, c)
  if c.hour then setClock(c.hour) end
  if not F.check(tag .. ": arrives", warpToCoords(c.grp, c.map, c.x, c.y, tag)) then return end
  battleOptions()
  F.face(c.face); F.press("A", 2)
  local started = false
  for i = 1, 4000 do
    if inBattle() then started = true; break end
    if F.reportCrash(tag) then break end
    if i % 20 == 0 then F.press("A", 2) else F.idle(1) end
  end
  if not F.check(tag .. ": the trainer battle starts", started) then F.shot(tag .. "_nostart"); return end
  battleBody(tag, c.moves, c.terrain)
  loseBattle(tag)
  F.check(tag .. ": control returns after the whiteout", hasControl())
end

local LR, UD = { "Left", "Right" }, { "Down", "Up" }
local CASES = {
  { "grass_day", { grp = 0, map = 16, x = 11, y = 10, dirs = UD, moves = ALL, hour = 12 } },
  { "grass_night", { grp = 0, map = 16, x = 11, y = 10, dirs = UD, moves = CORE, hour = 22 } },
  { "ice_path", { grp = 94, map = 7, x = 19, y = 24, dirs = LR, moves = CORE } },
  { "mt_silver_snow_night", { grp = 97, map = 7, x = 14, y = 40, dirs = LR, moves = WEATHER, hour = 22 } },
  { "rusturf_fog", { grp = 24, map = 4, x = 10, y = 5, dirs = LR, moves = CORE, terrain = true } },
  { "route41_surf_storm_night", { dirs = UD, moves = CORE, hour = 22, terrain = true,
    arrive = function() return F.warpTo(0, 8, 7, 0, 0, 2, 0, 0, 4, 87, 2, "route41") and (F.r8(S.gPlayerAvatar) & 8) ~= 0 end } },
  { "underwater", { grp = 0, map = 51, x = 37, y = 12, dirs = UD, moves = CORE } },
  { "desert_night", { grp = 0, map = 26, x = 23, y = 37, dirs = LR, moves = CORE, hour = 22, weatherFades = true } },
  { "long_grass", { grp = 0, map = 34, x = 34, y = 10, dirs = UD, moves = CORE, hour = 12 } },
  { "pokemon_tower_ghost", { grp = 35, map = 90, x = 9, y = 7, dirs = LR, moves = { "PSYCHIC", "SHADOW_BALL" }, terrain = true } },
  { "safari_kanto", { grp = 35, map = 63, x = 33, y = 28, dirs = LR, moves = {}, safari = true } },
  { "safari_johto", { grp = 96, map = 5, x = 2, y = 4, dirs = LR, moves = {}, safari = true } },
  { "safari_hoenn", { grp = 26, map = 3, x = 27, y = 33, dirs = LR, moves = {}, safari = true } },
  { "plain_trainer_night", { trainer = true, grp = 0, map = 17, x = 33, y = 15, face = "Up", moves = CORE, hour = 22 } },
  { "double_twins", { trainer = true, grp = 0, map = 19, x = 27, y = 16, face = "Up", moves = { "PSYCHIC", "EARTHQUAKE", "SKY_ATTACK" }, hour = 12 } },
  { "leader_roxanne", { trainer = true, grp = 11, map = 3, x = 5, y = 3, face = "Up", moves = CORE } },
  { "leader_bugsy", { trainer = true, grp = 81, map = 0, x = 11, y = 7, face = "Up", moves = CORE } },
}

F.run(function()
  if not F.boot(HUB_GROUP) then F.check("boot", false); F.finish(); return end
  giveMon(SPECIES_MARSHTOMP)
  giveMon(SPECIES_COMBUSKEN)
  F.check("two Pokemon in the party", F.r8(S.gPartiesCount) >= 2, "n=" .. F.r8(S.gPartiesCount))
  local only = os.getenv("BGS_CASE")
  local want
  if only then want = {}; for n in only:gmatch("[^,]+") do want[n] = true end end
  for _, entry in ipairs(CASES) do
    local tag, c = entry[1], entry[2]
    if not want or want[tag] then
      if c.trainer then trainerCase(tag, c) else wildCase(tag, c) end
    end
  end
  F.finish()
end)
