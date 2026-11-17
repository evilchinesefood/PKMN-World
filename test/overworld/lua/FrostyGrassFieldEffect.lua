-- Grass effects drawn over Mt. Silver's frosty grass use the frosted palette, not the green one.
--
-- The snowy Mt. Silver map (MtSilver_Snow) draws its tall grass white and pale blue, but the rustle
-- drawn over a walker's feet (FLDEFF_TALL_GRASS), the hop an overworld wild encounter makes when it
-- spawns in grass (FLDEFF_OW_ENCOUNTER_SPAWN_ANIM, JumpTallGrass art) and DexNav's shaking grass
-- (FLDEFF_SHAKING_GRASS) all took the green general_1 palette. They now take frosty_grass.pal on grass drawn from a tileset in sFrostyGrassTilesets
-- (src/field_effect_helpers.c), and general_1 everywhere else.
--
-- Each case sets the clock, warps beside the grass and walks one step into it with real input. On the
-- frames after the step begins, every TallGrass sprite must sit in an OBJ palette slot tagged with the
-- expected palette whose colors equal the authored .pal file read from the repository, and the drawn
-- (faded) colors must equal those colors after the overworld's time tint, recomputed here with
-- TimeMixPalettes' arithmetic from gTimeBlend. The player then stands still until an overworld wild
-- encounter spawns in the grass, and its JumpTallGrass hop is checked the same way. Last, R starts a
-- DexNav search for a species of the map, and the shaking grass it draws is checked the same way.
--   * Mt. Silver frosty grass at 12:00 and 22:00: frosty_grass.pal, tinted at night;
--   * Route 101 green grass at 12:00 and 22:00 (control): general_1.pal, unchanged.
--
-- Run via test/overworld/mgba-run.sh test/overworld/lua/FrostyGrassFieldEffect.lua

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "FrostyGrassFieldEffect")

local HUB_GROUP = 100
local CONTEXT_RUNNING = 0
local BM_ABILITY, ABILITY_RUN_AWAY = 32, 50
local ACTION_RUN = 3
local SPECIES_MARSHTOMP = 259
local SPECIES_SNEASEL, SPECIES_ZIGZAGOON = 215, 263
local FLAG_SYS_DEXNAV_SEARCHING, VAR_DEXNAV_SPECIES = 0x948 + 0xBD, 0x40FE
local TAG_GREEN, TAG_FROSTY = 0x1005, 0x1016
local REPO = here .. "../../../"
local SP = S.Sprite

local function d(n) return (n // 100) % 10, (n // 10) % 10, n % 10 end
local function inBattle() return F.cb2() == (S.BattleMainCB2 & ~1) end
local function ctrl(b) return F.r32(S.gBattlerControllerFuncs + b * 4) & ~1 end
local function isAction()
  for _, p in ipairs(S.ActionInputFunctions) do if ctrl(0) == (p & ~1) then return true end end
  return false
end

-- A JASC palette as 16 GBA colors, converted the way gbagfx does (each channel >> 3).
local function authored(path)
  local fh = assert(io.open(REPO .. path, "r"), path)
  local nums = {}
  for n in fh:read("a"):gmatch("%d+") do nums[#nums + 1] = tonumber(n) end
  fh:close()
  local out = {}
  for i = 0, 15 do
    local r, g, b = nums[3 + i * 3], nums[4 + i * 3], nums[5 + i * 3]
    out[i] = (r >> 3) | ((g >> 3) << 5) | ((b >> 3) << 10)
  end
  return out
end

local function blendSettings(addr)
  local v = F.r32(addr)
  return { color = v & 0xFFFFFF, tint = (v >> 24) & 1, coeff = (v >> 25) & 31 }
end

-- TimeMixPalettes (src/palette.c) for colors without the alt-blend bit, which no field effect palette sets.
local function timeMix(pal)
  local b0, b1 = blendSettings(S.gTimeBlend), blendSettings(S.gTimeBlend + 4)
  local weight = F.r16(S.gTimeBlend + 8)
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
  local out = { [0] = pal[0] }
  for i = 1, 15 do
    local c = pal[i]
    local r, g, b = c & 31, (c >> 5) & 31, (c >> 10) & 31
    local r2, g2, b2 = apply(b1, r1, g1, bl1, c1, r, g, b)
    r, g, b = apply(b0, r0, g0, bl0, c0, r, g, b)
    r = r2 + ((r - r2) * weight) // 256
    g = g2 + ((g - g2) * weight) // 256
    b = b2 + ((b - b2) * weight) // 256
    out[i] = r | (g << 5) | (b << 10)
  end
  return out
end

local function firstDiff(want, read)
  for i = 0, 15 do
    local got = read(i)
    if got ~= want[i] then return string.format("color %d is %04X, want %04X", i, got, want[i]) end
  end
  return nil
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

local function flag(id)
  return (F.r8(F.sb1() + S.SaveBlock1.flags + (id // 8)) & (1 << (id % 8))) ~= 0
end
local function setVar(id, v) F.w16(F.sb1() + S.SaveBlock1.vars + (id - 0x4000) * 2, v) end

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

-- Every live sprite drawn from `template`, as { slot = OBJ palette slot, tag = that slot's tag }.
local function spritesOf(template)
  local found = {}
  for i = 0, SP.count - 1 do
    local s = S.gSprites + i * SP.stride
    if (F.r16(s + SP.inUse) & 1) == 1 and F.r32(s + SP.template) == template then
      local slot = F.r16(s + 4) >> 12
      found[#found + 1] = { id = i, slot = slot, tag = F.r16(S.sSpritePaletteTags + slot * 2) }
    end
  end
  return found
end

-- A frame can end while the main loop is still inside CreateSprite (the field runs long frames), so
-- a sprite first seen this frame may not have its palette yet. Read it two frames later.
local function settled(template)
  F.idle(2)
  return spritesOf(template)
end

local function checkPalette(label, sprites, tag, file)
  local want = authored(file)
  local tinted = timeMix(want)
  for _, sp in ipairs(sprites) do
    local base = sp.slot * 16
    F.check(string.format("%s: sprite %d uses the %s palette (tag %04X)", label, sp.id, file, tag),
      sp.tag == tag, string.format("slot %d tag %04X", sp.slot, sp.tag))
    local bad = firstDiff(want, function(i) return F.r16(S.gPlttBufferUnfaded + 0x200 + (base + i) * 2) end)
    F.check(label .. ": its slot holds the authored colors", bad == nil, bad)
    bad = firstDiff(tinted, function(i) return F.r16(S.gPlttBufferFaded + 0x200 + (base + i) * 2) end)
    F.check(label .. ": it is drawn under the time tint", bad == nil, bad)
  end
end

-- Walk one step into the grass, then sample on the frames the rustle exists, before the step's
-- end runs the wild encounter check.
local function stepIntoGrass(dir, x0, y0)
  for _ = 1, 30 do
    joypad.set({ [dir] = true }); emu.frameadvance()
    local x, y = F.pos()
    if x ~= x0 or y ~= y0 then break end
  end
  for _ = 1, 8 do
    joypad.set({ [dir] = true }); emu.frameadvance()
    if #spritesOf(S.gFieldEffectObjectTemplate_TallGrass) > 0 then
      return settled(S.gFieldEffectObjectTemplate_TallGrass)
    end
  end
  return {}
end

-- { tag, grp, map, start x, start y, direction into the grass, hour, palette tag, palette file, DexNav species }
local FROSTY, GREEN = "graphics/field_effects/palettes/frosty_grass.pal", "graphics/field_effects/palettes/general_1.pal"
local CASES = {
  { "mt_silver_frosty_grass_day", 97, 7, 18, 20, "Down", 12, TAG_FROSTY, FROSTY, SPECIES_SNEASEL },
  { "mt_silver_frosty_grass_night", 97, 7, 18, 20, "Down", 22, TAG_FROSTY, FROSTY, SPECIES_SNEASEL },
  { "route101_green_grass_day", 0, 16, 10, 10, "Right", 12, TAG_GREEN, GREEN, SPECIES_ZIGZAGOON },
  { "route101_green_grass_night", 0, 16, 10, 10, "Right", 22, TAG_GREEN, GREEN, SPECIES_ZIGZAGOON },
}

local function run(c)
  local tag, grp, map, x, y, dir, hour, palTag, file, species = table.unpack(c)
  setClock(hour)
  if not F.check(tag .. ": arrives", warpToCoords(grp, map, x, y, tag)) then return end
  F.idle(30)
  local grass = stepIntoGrass(dir, x, y)
  F.shot(tag .. "_rustle")
  F.L(string.format("%s: hour %d, %d rustle sprite(s)", tag, localTime(), #grass))
  if F.check(tag .. ": walking into the grass draws a rustle", #grass > 0) then
    checkPalette(tag .. " rustle", grass, palTag, file)
  end
  local hops
  for i = 1, 3600 do
    F.idle(1)
    if F.reportCrash(tag) then break end
    if inBattle() then runAway() end
    if #spritesOf(S.gFieldEffectObjectTemplate_JumpTallGrass) > 0 then
      hops = settled(S.gFieldEffectObjectTemplate_JumpTallGrass)
      if #hops > 0 then break end
    end
  end
  if F.check(tag .. ": an overworld wild encounter spawns in the grass", hops and #hops > 0) then
    F.shot(tag .. "_spawn_hop")
    checkPalette(tag .. " spawn hop", hops, palTag, file)
  end
  for _ = 1, 600 do
    if not inBattle() then break end
    runAway()
  end
  -- A land search can also hide the Pokemon on a plain snow tile, so search again until it picks grass.
  setVar(VAR_DEXNAV_SPECIES, species)
  local shaking, searched, ended = {}, false, true
  for _ = 1, 8 do
    F.press("R", 2)
    for _ = 1, 240 do
      F.idle(1)
      searched = searched or flag(FLAG_SYS_DEXNAV_SEARCHING)
      if #spritesOf(S.gFieldEffectObjectTemplate_UnusedGrass) > 0 then
        shaking = settled(S.gFieldEffectObjectTemplate_UnusedGrass)
        if #shaking > 0 then break end
      end
    end
    if #shaking > 0 then
      F.shot(tag .. "_dexnav")
      checkPalette(tag .. " DexNav shaking grass", shaking, palTag, file)
    end
    F.press("Start", 2); F.idle(60); F.press("B", 2); F.idle(60)
    ended = ended and not flag(FLAG_SYS_DEXNAV_SEARCHING)
    if #shaking > 0 then break end
  end
  F.check(tag .. ": R starts a DexNav search", searched)
  F.check(tag .. ": a search shakes the grass", #shaking > 0)
  F.check(tag .. ": the Start menu ends each search", ended)
  F.check(tag .. ": control stays in the field", F.ow())
end

F.run(function()
  if not F.boot(HUB_GROUP) then F.check("boot", false); F.finish(); return end
  giveMon(SPECIES_MARSHTOMP)
  F.check("a Pokemon in the party", F.r8(S.gPartiesCount) >= 1, "n=" .. F.r8(S.gPartiesCount))
  local only = os.getenv("FROST_CASE")
  for _, c in ipairs(CASES) do
    if not only or c[1]:find(only, 1, true) then run(c) end
  end
  F.finish()
end)
