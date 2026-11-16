-- Scriptless wandering Pokemon must never stand where they shut the player out of an exit.
--
-- Ecruteak's Pidgey (object 13) and Vulpix (object 14) wandered a 9x9 box from (21,18)/(24,18)
-- that took in the one-tile stair corridor to the Burned Tower, (22,15) to (22,18), and the door
-- warp itself at (22,14). A world campaign sat below the stairs for 17 plans while the Pidgey stood
-- on the door. ValidateAmbientBlockers.py found five more such objects across Johto; the three on
-- maps a warp lands next to in daylight are watched here too.
--
-- Each case arrives by debug warp, walks to a parking tile with real input, then stands still
-- and reads the wanderer's position every frame. It fails if the wanderer ever stands on a cell
-- the audit names. Ecruteak then walks up the stairs into the Burned Tower.
local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "AmbientWanderBlockers")

local WATCH = 15000

local function objPos(localId)
  for i = 0, 15 do
    local b = S.gObjectEvents + i * S.ObjectEvent.stride
    if (memory.read_u8(b, "System Bus") & 1) == 1
        and memory.read_u8(b + S.ObjectEvent.localId, "System Bus") == localId then
      return memory.read_s16_le(b + S.ObjectEvent.x, "System Bus") - 7,
             memory.read_s16_le(b + S.ObjectEvent.y, "System Bus") - 7
    end
  end
end

-- Walk a route, waiting out an object in the way instead of giving up on the first bump.
local function patientRoute(points, budget)
  for _, p in ipairs(points) do
    while not F.leg(p[1], p[2]) do
      budget = budget - 60
      if budget <= 0 then return false end
      F.idle(60)
    end
  end
  return true
end

local function watch(tag, who, cells)
  local blocked = {}
  for _, c in ipairs(cells) do blocked[c[1] .. "," .. c[2]] = true end
  local seen, moves, hits, first, lx, ly, shotAt = false, 0, 0, nil, nil, nil, {}
  for f = 1, WATCH do
    joypad.set({}); emu.frameadvance()
    local x, y = objPos(who.id)
    if x then
      if lx and (x ~= lx or y ~= ly) then moves = moves + 1 end
      seen, lx, ly = true, x, y
      if blocked[x .. "," .. y] then
        hits = hits + 1
        first = first or string.format("(%d,%d) at frame %d", x, y, f)
        if not shotAt[x .. "," .. y] then
          shotAt[x .. "," .. y] = true
          F.shot(string.format("%s_%s_on_%d_%d", tag, who.name, x, y))
        end
      end
    end
  end
  F.check(string.format("%s: %s is on the map and wanders", tag, who.name), seen and moves > 0,
    string.format("seen=%s moves=%d", tostring(seen), moves))
  F.check(string.format("%s: %s never stands where it blocks an exit", tag, who.name), hits == 0,
    first and string.format("first %s, %d of %d frames", first, hits, WATCH) or "")
end

local CASES = {
  { tag = "ecruteak", warp = { 0, 8, 5, 0, 0, 0, 0, 0, 2 }, map = { 85, 0 },
    park = { { 22, 18 }, { 26, 19 } },
    watch = {
      { id = 13, name = "Pidgey" }, { id = 14, name = "Vulpix" },
    },
    cells = { { 22, 14 }, { 22, 15 }, { 22, 16 }, { 22, 17 }, { 22, 18 } } },
  { tag = "blackthorn", warp = { 0, 9, 3, 0, 0, 0, 0, 0, 0 }, map = { 93, 0 },
    park = { { 42, 24 }, { 42, 25 }, { 41, 25 } },
    watch = { { id = 12, name = "Dratini" } },
    cells = { { 42, 22 }, { 42, 23 } } },
  { tag = "mtsilver", warp = { 0, 9, 7, 0, 0, 0, 0, 0, 0 }, map = { 97, 0 },
    park = { { 19, 8 }, { 19, 10 } },
    watch = { { id = 5, name = "Venusaur" } },
    cells = { { 17, 7 }, { 17, 8 } } },
  { tag = "route26", warp = { 0, 9, 8, 0, 0, 0, 0, 0, 1 }, map = { 98, 0 },
    park = { { 22, 12 }, { 22, 14 } },
    watch = { { id = 7, name = "Charmander" } },
    cells = { { 24, 12 } } },
}

F.run(function()
  if not F.boot(100) then F.check("boot", false); F.finish(); return end
  for _, c in ipairs(CASES) do
    local w = c.warp
    local ok = F.warpTo(w[1], w[2], w[3], w[4], w[5], w[6], w[7], w[8], w[9], c.map[1], c.map[2], c.tag)
    F.check(c.tag .. ": warp in", ok)
    if ok then
      local parked = patientRoute(c.park, 3000)
      F.check(c.tag .. ": walk to the parking tile", parked,
        string.format("at (%d,%d)", F.pos(), select(2, F.pos())))
      if parked then
        F.shot(c.tag .. "_parked")
        for _, who in ipairs(c.watch) do watch(c.tag, who, c.cells) end
      end
      if c.tag == "ecruteak" then
        local walked = patientRoute({ { 22, 19 }, { 22, 18 }, { 22, 15 } }, 600)
        if walked then F.press("Up", 40); F.idle(240) end
        F.check("ecruteak: walk up the stairs into the Burned Tower",
          F.grp() == 86 and F.mapn() == 10,
          string.format("map %d.%d at (%d,%d)", F.grp(), F.mapn(), F.pos(), select(2, F.pos())))
      end
    end
  end
  F.finish()
end)
