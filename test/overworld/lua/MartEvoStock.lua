-- The four marts that stocked evolution items must not sell one that evolves nothing obtainable.
--
-- Gen 4+ families are stripped, so the Dusk Stone, Electirizer, Oval Stone and 34 more evolution
-- items evolve no species the player can own. Celadon Dept. Store 4F, Lilycove Dept. Store 2F, the
-- Mahogany shop and the Hub Battle Depot sold them anyway. test/overworld/ValidateDeadEvoItems.py
-- derives the dead list from the species table; this suite checks the stock the game really shows.
--
-- For each mart it stands at the clerk's counter, presses A with real input until the shop opens and
-- reads sMartInfo's item list. Oracle: no item from the dead list is for sale, while the Fire Stone
-- and the Linking Cord still are, and so is the Razor Claw (dead as an evolution item but kept for
-- its held critical-hit boost) where it was sold before. Mahogany's shop opens only after the Rocket
-- hideout, so the suite writes VAR_MAHOGANY_TOWN_STATE 14 the way that story leaves it.
local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "MartEvoStock")

local MART_ITEMLIST, MART_ITEMCOUNT = 8, 12
local ITEM_FIRE_STONE, ITEM_LINKING_CORD, ITEM_RAZOR_CLAW = 211, 796, 492
local DEAD = {
  [763] = "AUSPICIOUS_ARMOR", [240] = "BERRY_SWEET", [795] = "BLACK_AUGURITE", [224] = "CHIPPED_POT",
  [241] = "CLOVER_SWEET", [223] = "CRACKED_POT", [220] = "DAWN_STONE", [232] = "DUBIOUS_DISC",
  [219] = "DUSK_STONE", [230] = "ELECTIRIZER", [242] = "FLOWER_SWEET", [225] = "GALARICA_CUFF",
  [226] = "GALARICA_WREATH", [766] = "GIMMIGHOUL_COIN", [215] = "ICE_STONE", [767] = "LEADERS_CREST",
  [239] = "LOVE_SWEET", [231] = "MAGMARIZER", [768] = "MALICIOUS_ARMOR", [802] = "MASTERPIECE_TEACUP",
  [814] = "METAL_ALLOY", [237] = "OVAL_STONE", [797] = "PEAT_BLOCK", [229] = "PROTECTOR",
  [233] = "REAPER_CLOTH", [244] = "RIBBON_SWEET", [236] = "SACHET", [770] = "SCROLL_OF_DARKNESS",
  [771] = "SCROLL_OF_WATERS", [218] = "SHINY_STONE", [243] = "STAR_SWEET", [238] = "STRAWBERRY_SWEET",
  [221] = "SWEET_APPLE", [800] = "SYRUPY_APPLE", [222] = "TART_APPLE", [801] = "UNREMARKABLE_TEACUP",
  [235] = "WHIPPED_DREAM",
}
local MAHOGANY_STATE = S.gSaveblock3 + S.SaveBlock3.regionVars + (0xA080 + 0x11 - 0xA000) * 2

-- Clerks sit behind counters, so each mart lists the tiles to try (the counter tile itself is solid
-- and a talk reaches across it) and the way to face.
local MARTS = {
  { name = "celadon_4f", group = 44, map = 3, tiles = { { 3, 11 }, { 3, 12 } }, face = "Down", razor = true },
  { name = "lilycove_2f", group = 13, map = 17, tiles = { { 7, 4 }, { 7, 5 } }, face = "Down", razor = true },
  { name = "mahogany", group = 92, map = 3, tiles = { { 4, 5 }, { 3, 5 } }, face = "Left", razor = true,
    setup = function() F.w16(MAHOGANY_STATE, 14) end },
  { name = "hub_depot", group = 100, map = 0, tiles = { { 23, 13 }, { 23, 12 } }, face = "Up", razor = false },
}

local function martCount() return F.r16(S.sMartInfo + MART_ITEMCOUNT) end
local function martItems()
  local p, n, t = F.r32(S.sMartInfo + MART_ITEMLIST), martCount(), {}
  if p ~= 0 and n > 0 and n < 128 then
    for i = 0, n - 1 do t[#t + 1] = F.r16(p + i * 2) end
  end
  return t
end

local function d(n) return (n // 100) % 10, (n // 10) % 10, n % 10 end
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
      if F.ow() and F.grp() == grp and F.mapn() == map and px == x and py == y then
        F.idle(120)
        return true
      end
    end
    F.bOut(5)
  end
  F.shot(tag .. "_warpfail")
  return false
end

local function openShop(m)
  for _, t in ipairs(m.tiles) do
    if warpToCoords(m.group, m.map, t[1], t[2], m.name) then
      F.face(m.face)
      F.w32(S.sMartInfo + MART_ITEMLIST, 0)
      F.w16(S.sMartInfo + MART_ITEMCOUNT, 0)
      for _ = 1, 12 do
        F.press("A", 2); F.idle(40)
        if martCount() > 0 then F.idle(30); F.shot(m.name .. "_shop"); return true end
      end
      F.bOut(6)
    end
  end
  return false
end

F.run(function()
  if not F.boot(100) then F.check("boot to the hub", false); F.finish(); return end
  for _, m in ipairs(MARTS) do
    if m.setup then m.setup() end
    local opened = openShop(m)
    F.check(m.name .. ": the shop opens", opened)
    local items, dead, has = martItems(), {}, {}
    for _, id in ipairs(items) do
      has[id] = true
      if DEAD[id] then dead[#dead + 1] = DEAD[id] end
    end
    F.L(string.format("  %s stock (%d): %s", m.name, #items, table.concat(items, ",")))
    F.check(m.name .. ": sells no dead evolution item", opened and #dead == 0, table.concat(dead, ","))
    F.check(m.name .. ": still sells the Fire Stone and the Linking Cord", has[ITEM_FIRE_STONE] and has[ITEM_LINKING_CORD])
    if m.razor then F.check(m.name .. ": still sells the Razor Claw", has[ITEM_RAZOR_CLAW]) end
    F.bOut(10)
  end
  F.check("no crash", not F.crashScreen())
  F.finish()
end)
