-- Wild battles in Mt. Silver's frosty grass draw the grass background in frosted colors.
--
-- The snowy Mt. Silver map (MtSilver_Snow) draws its tall grass white and pale blue, but its wild
-- battles drew the ordinary green grass background: ResolveBattlePresentation (src/battle_presentation.c)
-- restyled only the map's plain ground (rock art, mt_silver_snow.pal) and left BATTLE_ENVIRONMENT_GRASS
-- on the authored green palette. The grass art now takes tall_grass/mt_silver_snow.pal, derived from
-- the colors the map's frosty grass metatiles draw with (palette-sources.json records the mapping).
--
-- Each case warps beside encounter tiles, sets the clock, and walks until a wild battle starts. At the
-- first action menu it reads BG palette banks 2-4 (gPlttBufferUnfaded) and the palette the captured
-- presentation points at, and compares them with the authored .pal file read from the repository.
--   * frosty grass by day and at night: the presentation names the frosted palette and the drawn banks
--     equal it after the presentation's own time tint (identity by day);
--   * green grass on Route 101 by day and at night: the authored green palette, unchanged;
--   * Ice Path: the cave art keeps its cold palette (the owner kept that look).
-- The tint is recomputed here from the presentation's TimeBlendSettings with TimeMixPalettes'
-- arithmetic, so a wrong art choice and a lost night tint both fail.
--
-- Run via test/overworld/mgba-run.sh test/overworld/lua/BattleBgFrostGrass.lua

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "BattleBgFrostGrass")

local HUB_GROUP = 100
local CONTEXT_RUNNING = 0
local BM = S.BattlePokemon
local BM_ABILITY, ABILITY_RUN_AWAY = 32, 50
local ACTION_RUN = 3
local ENV_GRASS, ENV_CAVE = 0, 7
local SPECIES_MARSHTOMP = 259
local PRESENTATION = S.sBattlePresentation
local REPO = here .. "../../../"

local function d(n) return (n // 100) % 10, (n // 10) % 10, n % 10 end
local function inBattle() return F.cb2() == (S.BattleMainCB2 & ~1) end
local function ctrl(b) return F.r32(S.gBattlerControllerFuncs + b * 4) & ~1 end
local function isAction()
  for _, p in ipairs(S.ActionInputFunctions) do if ctrl(0) == (p & ~1) then return true end end
  return false
end

-- A JASC palette as 48 GBA colors, converted the way gbagfx does (each channel >> 3).
local function authored(path)
  local fh = assert(io.open(REPO .. path, "r"), path)
  local nums = {}
  for n in fh:read("a"):gmatch("%d+") do nums[#nums + 1] = tonumber(n) end
  fh:close()
  local out = {}
  for i = 0, 47 do
    local r, g, b = nums[3 + i * 3], nums[4 + i * 3], nums[5 + i * 3]
    out[i] = (r >> 3) | ((g >> 3) << 5) | ((b >> 3) << 10)
  end
  return out
end

local function blendSettings(addr)
  local v = F.r32(addr)
  return { color = v & 0xFFFFFF, tint = (v >> 24) & 1, coeff = (v >> 25) & 31 }
end

-- TimeMixPalettes (src/palette.c) for colors without the alt-blend bit, which no battle palette sets.
local function timeMix(pal, time)
  local b0, b1, weight = time.start, time.stop, time.weight
  local function split(bs)
    if bs.tint == 1 then return bs.color & 0xFF, (bs.color >> 8) & 0xFF, (bs.color >> 16) & 0xFF, 16 end
    return bs.color & 31, (bs.color >> 5) & 31, (bs.color >> 10) & 31, bs.coeff * 2
  end
  local r0, g0, bl0, c0 = split(b0)
  local r1, g1, bl1, c1 = split(b1)
  local function apply(bs, cr, cg, cb, coeff, r, g, b)
    if bs.tint == 1 then
      return math.min((cr * r) >> 8, 31), math.min((cg * g) >> 8, 31), math.min((cb * b) >> 8, 31)
    end
    return r + ((cr - r) * coeff) // 32, g + ((cg - g) * coeff) // 32, b + ((cb - b) * coeff) // 32
  end
  local out = {}
  for i = 0, 47 do
    local c = pal[i]
    if i % 16 == 0 then out[i] = c else
      local r, g, b = c & 31, (c >> 5) & 31, (c >> 10) & 31
      local r2, g2, b2 = apply(b1, r1, g1, bl1, c1, r, g, b)
      r, g, b = apply(b0, r0, g0, bl0, c0, r, g, b)
      r = r2 + ((r - r2) * weight) // 256
      g = g2 + ((g - g2) * weight) // 256
      b = b2 + ((b - b2) * weight) // 256
      out[i] = r | (g << 5) | (b << 10)
    end
  end
  return out
end

local function presentationTime()
  local t = PRESENTATION + S.BattlePresentation.time
  return { start = blendSettings(t), stop = blendSettings(t + 4), weight = F.r16(t + 8) }
end

local function firstDiff(want, read)
  for i = 0, 47 do
    local got = read(i)
    if got ~= want[i] then return string.format("color %d is %04X, want %04X", i, got, want[i]) end
  end
  return nil
end
local function drawn(i) return F.r16(S.gPlttBufferUnfaded + 0x40 + i * 2) end

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

local function runAway()
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
  for i = 1, 3000 do
    if F.ow() and F.r8(S.sLockFieldControls) == 0 and F.r8(S.sGlobalScriptContextStatus) ~= CONTEXT_RUNNING then break end
    F.idle(1)
    if i % 30 == 0 then F.press("B", 2) end
  end
  F.idle(60)
end

-- { tag, grp, map, x, y, steps, hour, environment, palette file, tinted }
local LR, UD = { "Left", "Right" }, { "Down", "Up" }
local FROST, GREEN, ICE = "graphics/battle_environment/tall_grass/mt_silver_snow.pal",
  "graphics/battle_environment/tall_grass/palette.pal", "graphics/battle_environment/cave/ice_path.pal"
local CASES = {
  { "mt_silver_frost_grass_day", 97, 7, 18, 21, LR, 12, ENV_GRASS, FROST, true },
  { "mt_silver_frost_grass_night", 97, 7, 18, 21, LR, 22, ENV_GRASS, FROST, true },
  { "route101_green_grass_day", 0, 16, 11, 10, UD, 12, ENV_GRASS, GREEN, true },
  { "route101_green_grass_night", 0, 16, 11, 10, UD, 22, ENV_GRASS, GREEN, true },
  { "ice_path_cave", 94, 7, 19, 24, LR, 12, ENV_CAVE, ICE, false },
}

local function battle(c)
  local tag, grp, map, x, y, dirs, hour, env, file, tinted = table.unpack(c)
  setClock(hour)
  if not F.check(tag .. ": arrives", warpToCoords(grp, map, x, y, tag)) then return end
  F.idle(30)
  F.shot(tag .. "_overworld")
  local started = false
  for i = 1, 800 do
    if inBattle() then started = true; break end
    F.step(dirs[(i % #dirs) + 1])
    if F.reportCrash(tag) then break end
  end
  if not F.check(tag .. ": a wild battle starts", started) then return end
  local ready = false
  for i = 1, 3000 do
    F.idle(1)
    if F.reportCrash(tag) then break end
    if isAction() then ready = true; break end
    if i > 300 and i % 30 == 0 then F.press("B", 2) end
  end
  if not F.check(tag .. ": the action menu opens", ready) then F.shot(tag .. "_noaction"); return end
  F.idle(30)
  F.shot(tag)
  local want = authored(file)
  local day = F.r32(PRESENTATION + S.BattlePresentation.dayPalette)
  local isTinted = F.r8(PRESENTATION + S.BattlePresentation.tintWithTime) ~= 0
  F.L(string.format("%s: environment %d, hour %d, day palette %08X, tinted=%s", tag,
    F.r8(S.gBattleEnvironment), localTime(), day, tostring(isTinted)))
  F.check(tag .. ": battle environment", F.r8(S.gBattleEnvironment) == env, "env=" .. F.r8(S.gBattleEnvironment))
  local bad = firstDiff(want, function(i) return F.r16(day + i * 2) end)
  F.check(tag .. ": the presentation names " .. file, bad == nil, bad)
  F.check(tag .. ": time tint " .. (tinted and "on" or "off"), isTinted == tinted)
  local expected = tinted and timeMix(want, presentationTime()) or want
  bad = firstDiff(expected, drawn)
  F.check(tag .. ": palette banks 2-4 draw it" .. (tinted and " under the time tint" or ""), bad == nil, bad)
  if hour == 12 then
    bad = firstDiff(want, drawn)
    F.check(tag .. ": by day the banks equal the authored colors", bad == nil, bad)
  else
    F.check(tag .. ": at night the banks are tinted", firstDiff(want, drawn) ~= nil)
  end
  runAway()
  F.check(tag .. ": control returns to the field", F.ow())
end

F.run(function()
  if not F.boot(HUB_GROUP) then F.check("boot", false); F.finish(); return end
  giveMon(SPECIES_MARSHTOMP)
  F.check("a Pokemon in the party", F.r8(S.gPartiesCount) >= 1, "n=" .. F.r8(S.gPartiesCount))
  local only = os.getenv("FROST_CASE")
  for _, c in ipairs(CASES) do
    if not only or c[1]:find(only, 1, true) then battle(c) end
  end
  F.finish()
end)
