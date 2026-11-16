-- The PokeNav's map option, its help line and the region map's header must name the region the
-- map shows. They said HOENN MAP in Johto and Kanto too. The suite turns the PokeNav on, then in
-- Hoenn (Route 106), Johto (Goldenrod City) and Kanto (Pallet Town) opens it from the Start menu
-- with real input and reads the map option's sprite: its tile, measured from the Condition
-- option's (tile 0x020 of the options sheet), must be that region's label (Hoenn 0x000, Johto
-- 0x1A0, Kanto 0x1C0). Screenshots: the menu with its help line, the full map and the zoomed map.
--
-- Run via: test/overworld/mgba-run.sh test/overworld/lua/PokenavRegionNames.lua <rom.gba>

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "PokenavRegionNames")

local FLAG_SYS_POKENAV_GET = 0x94A
local USM_ICO_POKENAV = 3
local OPTION_X, OPTION_SELECTED_X, MAP_Y, CONDITION_Y, CONDITION_TILE = 140, 130, 42, 62, 0x020
local SPR_X, SPR_Y, SPR_X2 = 0x20, 0x22, 0x24
local REGIONS = {
  { name = "hoenn", warp = { 0, 0, 0, 0, 2, 1 }, map = { 0, 21 }, tile = 0x000 },
  { name = "johto", warp = { 0, 8, 3, 0, 0, 0 }, map = { 83, 0 }, tile = 0x1A0 },
  { name = "kanto", warp = { 0, 3, 7, 0, 0, 0 }, map = { 37, 0 }, tile = 0x1C0 },
}

local function flag(id)
  local a = F.sb1() + S.SaveBlock1.flags + id // 8
  F.w8(a, F.r8(a) | (1 << (id % 8)))
end
local function tap(key, n, wait) for _ = 1, (n or 1) do F.press(key, 2); F.idle(wait or 24) end end
-- Tile number of the first subsprite of the option drawn at row y.
local function optionTile(y)
  for i = 0, S.Sprite.count - 1 do
    local a = S.gSprites + i * S.Sprite.stride
    local x = F.rs16(a + SPR_X)
    if (F.r8(a + S.Sprite.inUse) & 1) ~= 0 and (x == OPTION_X or x == OPTION_SELECTED_X) and F.rs16(a + SPR_Y) == y
        and F.rs16(a + SPR_X2) == 0 then
      return F.r16(a + 4) & 0x3FF
    end
  end
  return nil
end

F.run(function()
  assert(F.boot(100), "boot")
  flag(FLAG_SYS_POKENAV_GET)
  for _, r in ipairs(REGIONS) do
    local w = r.warp
    F.check(r.name .. ": warped", F.warpTo(w[1], w[2], w[3], w[4], w[5], w[6], 0, 0, 0, r.map[1], r.map[2], r.name))
    for _ = 1, 10 do F.press("B", 2); F.idle(20) end
    F.ensureFree()
    F.idle(60)
    local offered = false
    for _ = 1, 3 do
      F.press("Start", 2); F.idle(60)
      offered = F.selectStartIcon(USM_ICO_POKENAV)
      if offered then break end
      for _ = 1, 4 do F.press("B", 2); F.idle(30) end
    end
    F.check(r.name .. ": the Start menu offers the PokeNav", offered)
    F.press("A", 2); F.idle(240)
    local map, cond = optionTile(MAP_Y), optionTile(CONDITION_Y)
    local got = (map and cond) and (map - (cond - CONDITION_TILE)) or -1
    F.shot(r.name .. "_menu")
    F.check(string.format("%s: the map option shows the %s MAP label", r.name, r.name:upper()), got == r.tile,
      string.format("label tile %03X, want %03X", got, r.tile))
    tap("A", 1, 150); F.shot(r.name .. "_map_full")
    tap("A", 1, 90); F.shot(r.name .. "_map_zoom")
    for _ = 1, 8 do if F.ow() then break end tap("B", 1, 90) end
    for _ = 1, 10 do if F.ensureFree() then break end F.press("B", 2); F.idle(20) end
    F.check(r.name .. ": back on the field", F.ow())
  end
  F.finish()
end)
