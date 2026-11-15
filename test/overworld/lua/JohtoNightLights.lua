-- JohtoNightLights.lua: the ported Johto maps' light sprites draw the light each map asked for.
--
-- A map places a light as an OBJ_EVENT_GFX_LIGHT_SPRITE object whose trainer_sight_or_berry_tree_id
-- is the light type. pokemonHnS, which the Johto maps came from, defines six types; this engine
-- shipped three (ball, Pokemon Center sign, Mart sign) and clamped every larger number to the last
-- one. Goldenrod, Route 34, both National Park maps and Olivine use type 3 (street lamp) and every
-- Whirl Islands floor plus Olivine's lighthouse use type 4 (lighthouse glow / glow lichen), so at
-- night each of those lamps drew a teal "MART" sign beside its post and the caves glowed with Mart
-- signs too.
--
-- The read is the picture table of the sprite's template (a ball light draws from a tile sheet, so
-- its own `images` is NULL; the template's is not). Each lamp below is a literal from the map
-- data, and the expectation is the picture pokemonHnS gives that type: street lamp -> the 16x16
-- SmallLight glow, glow -> the 32x32 BallLight. A type-4 glow also stays
-- lit by day (HnS: "will remain on during daytime"); the day pass checks that, with Goldenrod's
-- street lamps as the control that a day light really does switch off.
--
-- The lamps are reached with real input after one debug warp per map: Goldenrod is walked from the
-- Game Corner door to the campaign's (32,43) viewpoint and on across the connection into Route 34.

package.path = (debug.getinfo(1, "S").source:sub(2):match("^(.*[/\\])") or "") .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "JohtoNightLights")

local STREET, GLOW = "street lamp", "glow"
local PICTURE = {
  [STREET] = S.gFieldEffectObjectPicTable_SmallLight,
  [GLOW] = S.gFieldEffectObjectPicTable_BallLight,
}
local PICTURE_NAME = {
  [S.gFieldEffectObjectPicTable_BallLight] = "BallLight",
  [S.gFieldEffectObjectPicTable_PokeCenterLight] = "PokeCenterLight",
  [S.gFieldEffectObjectPicTable_MartLight] = "MartLight",
}
if S.gFieldEffectObjectPicTable_SmallLight ~= 0 then
  PICTURE_NAME[S.gFieldEffectObjectPicTable_SmallLight] = "SmallLight"
end

-- Every light on each map, from data/maps/<map>/map.json (all match pokemonHnS).
local LAMPS = {
  goldenrod = { STREET, { 31, 35 }, { 36, 42 }, { 31, 42 }, { 12, 25 }, { 52, 15 }, { 7, 25 } },
  route34 = { STREET, { 38, 20 }, { 38, 15 }, { 38, 9 }, { 38, 3 }, { 50, 32 }, { 50, 36 }, { 50, 42 } },
  park = { STREET, { 13, 2 }, { 7, 6 }, { 3, 13 }, { 3, 19 }, { 3, 25 }, { 17, 40 }, { 9, 46 }, { 24, 40 },
           { 36, 46 }, { 34, 33 }, { 38, 25 }, { 26, 25 }, { 30, 21 }, { 15, 25 }, { 11, 21 }, { 11, 17 },
           { 15, 13 }, { 26, 13 }, { 30, 17 }, { 38, 13 }, { 34, 6 }, { 28, 2 } },
  olivine = { STREET, { 18, 12 }, { 21, 12 }, { 18, 20 }, { 21, 20 }, { 9, 34 }, { 13, 34 }, { 30, 32 },
              { 33, 32 }, { 30, 39 }, { 33, 39 }, { 24, 45 } },
  olivineBeacon = { GLOW, { 39, 38 } },
  whirlB1F = { GLOW, { 35, 34 }, { 45, 36 }, { 50, 33 }, { 37, 24 }, { 23, 61 }, { 16, 40 }, { 11, 39 },
               { 23, 3 } },
  whirlInner = { GLOW, { 14, 10 }, { 21, 9 }, { 19, 2 }, { 11, 1 }, { 14, 19 }, { 11, 18 } },
}

local OFS_TEMPLATE, OFS_CALLBACK, OFS_DATA, OFS_FLAGS = 0x14, 0x1C, 0x2E, 0x3E
local TEMPLATE_IMAGES = 0x0C
local MAP_OFFSET = 7

local function lightSprites()
  local out = {}
  for i = 0, S.Sprite.count - 1 do
    local a = S.gSprites + i * S.Sprite.stride
    local flags = F.r8(a + OFS_FLAGS)
    if flags & 1 ~= 0 and (F.r32(a + OFS_CALLBACK) & ~1) == (S.UpdateLightSprite & ~1) then
      local x, y = F.rs16(a + OFS_DATA + 12) - MAP_OFFSET, F.rs16(a + OFS_DATA + 14) - MAP_OFFSET
      out[x .. "," .. y] = { images = F.r32(F.r32(a + OFS_TEMPLATE) + TEMPLATE_IMAGES),
                             invisible = (flags >> 2) & 1 == 1,
                             lightType = F.rs16(a + OFS_DATA + 10) }
    end
  end
  return out
end

-- UpdateLightSprite keeps a light only while it is inside this box around the player.
local function inView(px, py, x, y)
  return x >= px - 9 and x <= px + 10 and y >= py - 7 and y <= py + 8
end

local function checkLamps(tag, set, wantLit, minLamps)
  F.idle(30)
  local px, py = F.pos()
  local sprites = lightSprites()
  local kind, n = set[1], 0
  for i = 2, #set do
    local x, y = set[i][1], set[i][2]
    if inView(px, py, x, y) then
      n = n + 1
      local s = sprites[x .. "," .. y]
      local where = ("%s %s (%d,%d)"):format(tag, kind, x, y)
      if not s then
        F.check(where .. " has a light sprite", false, ("player (%d,%d)"):format(px, py))
      else
        local drew = PICTURE_NAME[s.images] or ("0x%08X"):format(s.images)
        F.check(where .. " draws its own light", PICTURE[kind] ~= 0 and s.images == PICTURE[kind],
                ("drew %s, type %d"):format(drew, s.lightType))
        F.check(where .. (wantLit and " is lit" or " is dark"), s.invisible ~= wantLit,
                ("invisible=%s"):format(tostring(s.invisible)))
      end
    end
  end
  F.check(tag .. " has lamps in view", n >= minLamps, ("%d in view from (%d,%d), want >= %d"):format(n, px, py, minLamps))
  F.shot(tag)
end

local function localTime()
  return F.rs8(S.gLocalTime + S.Time.hours), F.rs8(S.gLocalTime + S.Time.minutes)
end

-- gLocalTime = RTC - localTimeOffset, and the offset is the one clock lever that survives a warp
-- (see TinTowerRoof.lua). Land on :30 so the minute tick cannot cross an hour before the read.
local function setLocalTime(targetHour)
  local off = F.sb2() + S.SaveBlock2.localTimeOffset
  local h, m = localTime()
  local deltaMin = ((h * 60 + m) - (targetHour * 60 + 30)) % (24 * 60)
  local newMin = F.rs8(off + S.Time.minutes) + (deltaMin % 60)
  local carry = 0
  if newMin >= 60 then newMin, carry = newMin - 60, 1 end
  F.w8(off + S.Time.minutes, newMin % 60)
  F.w8(off + S.Time.hours, (F.rs8(off + S.Time.hours) + (deltaMin // 60) + carry) % 24)
end

local TIME_NIGHT = 3

-- A blocked step is a wandering NPC or a story trigger's message: Route 34's y=5 row is the
-- first-visit Goldenrod trigger, whose Elm call is a PokeNav call that only A advances.
local function walk(points, tag)
  for _ = 1, 4 do
    if F.route(points, tag) then return true end
    for _ = 1, 10 do F.press("A", 2); F.idle(30); F.press("B", 2); F.idle(30) end
  end
  return false
end

local function nightPass()
  setLocalTime(22)

  -- Goldenrod Game Corner door (warp 10, (28,29)); the debug warp-id field only reaches 10. The
  -- door exit leaves the player at (28,30), and (32,36) has three lamps in view.
  if not F.warpTo(0, 8, 3, 0, 0, 0, 0, 0, 10, 83, 0, "goldenrod") then return end
  F.idle(120)
  F.check("night clock", F.r8(S.gTimeOfDay) == TIME_NIGHT, ("gTimeOfDay=%d hour=%d"):format(F.r8(S.gTimeOfDay), localTime()))
  F.check("goldenrod walk to (32,36)", walk({ { 29, 30 }, { 29, 31 }, { 32, 31 }, { 32, 36 } }, "goldenrod_walk"), "")
  checkLamps("goldenrod_32_36", LAMPS.goldenrod, true, 3)
  F.check("goldenrod walk to (32,43)", walk({ { 32, 43 } }, "goldenrod_walk2"), "")
  checkLamps("goldenrod_32_43", LAMPS.goldenrod, true, 2)

  -- South exit x=32..35 joins Route 34 at x=25..28 (connection offset 7).
  F.check("goldenrod to route34", walk({ { 33, 43 }, { 33, 45 } }, "to_route34") and F.step("Down")
          and F.grp() == 80 and F.mapn() == 2, ("grp=%d map=%d"):format(F.grp(), F.mapn()))
  F.check("route34 walk to (28,9)", walk({ { 28, 0 }, { 28, 9 } }, "route34_walk"), "")
  checkLamps("route34", LAMPS.route34, true, 3)

  -- National Park east gate (warp 2, (40,19)): an arrow warp, so never press Right here. One step
  -- west brings the x=30 lamps into view.
  if not F.warpTo(0, 8, 3, 0, 0, 4, 0, 0, 2, 83, 4, "park") then return end
  F.idle(60)
  F.step("Left")
  checkLamps("park", LAMPS.park, true, 3)

  -- Olivine (warp 3, (26,40)), then east until the lighthouse beacon at (39,38) is in view.
  if not F.warpTo(0, 8, 7, 0, 0, 0, 0, 0, 3, 87, 0, "olivine") then return end
  F.idle(120)
  checkLamps("olivine_door", LAMPS.olivine, true, 3)
  F.check("olivine walk to (33,41)", walk({ { 33, 41 } }, "olivine_walk"), "")
  checkLamps("olivine_street", LAMPS.olivine, true, 3)
  checkLamps("olivine_beacon", LAMPS.olivineBeacon, true, 1)

  if not F.warpTo(0, 8, 8, 0, 1, 1, 0, 0, 3, 88, 11, "whirl_b1f") then return end
  F.idle(60)
  checkLamps("whirl_b1f_night", LAMPS.whirlB1F, true, 3)
  if not F.warpTo(0, 8, 8, 0, 1, 2, 0, 0, 4, 88, 12, "whirl_inner") then return end
  F.idle(60)
  checkLamps("whirl_inner_night", LAMPS.whirlInner, true, 3)
end

local function dayPass()
  setLocalTime(14)
  if not F.warpTo(0, 8, 8, 0, 1, 1, 0, 0, 3, 88, 11, "whirl_b1f_day") then return end
  F.idle(60)
  F.check("day clock", F.r8(S.gTimeOfDay) ~= TIME_NIGHT, ("gTimeOfDay=%d"):format(F.r8(S.gTimeOfDay)))
  checkLamps("whirl_b1f_day", LAMPS.whirlB1F, true, 3)
  if not F.warpTo(0, 8, 3, 0, 0, 0, 0, 0, 10, 83, 0, "goldenrod_day") then return end
  F.idle(120)
  F.check("goldenrod day walk to (32,36)", walk({ { 29, 30 }, { 29, 31 }, { 32, 31 }, { 32, 36 } }, "goldenrod_day_walk"), "")
  checkLamps("goldenrod_day", LAMPS.goldenrod, false, 3)
end

F.run(function()
  if not F.boot(100) then F.finish() return end
  nightPass()
  dayPass()
  F.finish()
end)
