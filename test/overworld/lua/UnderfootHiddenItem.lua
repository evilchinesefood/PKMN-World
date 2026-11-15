-- The Itemfinder digs up an FRLG underfoot hidden item.
--
-- FRLG marks six hidden items "underfoot": both Snorlax spots' Leftovers (Routes 12 and 16), Mr.
-- Fuji's Soothe Bell (Pokémon Tower 7F), Giovanni's Macho Brace (Viridian Gym), the Navel Rock
-- summit's Sacred Ash and Cape Brink's PP Max. Facing one does nothing
-- (GetInteractedBackgroundEventScript returns NULL for them); in pokefirered the Itemfinder digs
-- one up when the player stands on it (itemfinder.c SetUnderfootHiddenItem,
-- EventScript_ItemfinderDigUpUnderfootItem). This tree uses Emerald's Itemfinder, which spun the
-- player on the spot, said "The ITEMFINDER's shaking wildly!" and gave nothing, so the six items
-- could never be collected.
--
-- The suite warps onto Cape Brink's PP Max cell (16,28), the one with no object standing on it,
-- registers the Itemfinder on Select and presses Select. Oracle: PP Max is in the bag and the
-- item's hidden-item flag is set.
--
-- Run via test/overworld/mgba-run.sh test/overworld/lua/UnderfootHiddenItem.lua

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "UnderfootHiddenItem")

local HUB_GROUP = 100
local CAPE_BRINK_GROUP, CAPE_BRINK_MAP, PP_MAX_X, PP_MAX_Y = 37, 47, 16, 28
local ITEM_PP_MAX, ITEM_ITEMFINDER = 72, 712
local FLAG_HIDDEN_ITEM_TWO_ISLAND_CAPE_BRINK_PP_MAX = 0x1011   -- FLAG_HIDDEN_ITEMS_START 0xF00 + 0x111
local CONTEXT_RUNNING, CONTEXT_SHUTDOWN = 0, 2

local function d(n) return (n // 100) % 10, (n // 10) % 10, n % 10 end

local function flagSet(id)
  return (F.r8(F.sb1() + S.SaveBlock1.flags + (id // 8)) & (1 << (id % 8))) ~= 0
end

local function hasControl()
  return F.ow() and F.r8(S.sLockFieldControls) == 0 and F.r8(S.sGlobalScriptContextStatus) == CONTEXT_SHUTDOWN
end

-- Run a few bytes of event script, the way the game's own scripts give an item.
local SCRIPT_BUF = S.gStringVar4 + 960
local function addItem(id)
  local bytes = { 0x44, id & 0xFF, id >> 8, 1, 0, 0x02 }       -- additem id, 1; end
  for i, b in ipairs(bytes) do F.w8(SCRIPT_BUF + i - 1, b) end
  F.w8(S.sGlobalScriptContext, 0)
  F.w8(S.sGlobalScriptContext + 1, 1)
  F.w32(S.sGlobalScriptContext + 4, 0)
  F.w32(S.sGlobalScriptContext + S.ScriptCtx.scriptPtr, SCRIPT_BUF)
  F.w8(S.sGlobalScriptContextStatus, CONTEXT_RUNNING)
  for _ = 1, 200 do
    F.idle(4)
    if hasControl() then break end
  end
  F.idle(30)
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
      if F.ow() and F.grp() == grp and F.mapn() == map and px == x and py == y then
        F.idle(120)
        F.L(string.format("  WARP %s ok (%d,%d)", tag, px, py))
        return true
      end
    end
    F.bOut(5)
  end
  F.shot(tag .. "_warpfail")
  return false
end

F.run(function()
  if not F.boot(HUB_GROUP) then F.check("boot", false); F.finish(); return end
  if not F.check("warp_onto_pp_max_cell", warpToCoords(CAPE_BRINK_GROUP, CAPE_BRINK_MAP, PP_MAX_X, PP_MAX_Y, "cape")) then
    F.finish(); return
  end
  addItem(ITEM_ITEMFINDER)
  F.check("has_itemfinder", F.itemCount(ITEM_ITEMFINDER) == 1, "slots=" .. F.itemCount(ITEM_ITEMFINDER))
  F.check("pp_max_not_yet_found", F.itemCount(ITEM_PP_MAX) == 0 and not flagSet(FLAG_HIDDEN_ITEM_TWO_ISLAND_CAPE_BRINK_PP_MAX),
    string.format("slots=%d flag=%s", F.itemCount(ITEM_PP_MAX), tostring(flagSet(FLAG_HIDDEN_ITEM_TWO_ISLAND_CAPE_BRINK_PP_MAX))))

  F.w16(F.sb1() + S.SaveBlock1.registeredItem, ITEM_ITEMFINDER)
  F.press("Select", 2)
  F.idle(240)
  F.shot("itemfinder_on_the_spot")
  for i = 1, 16 do
    if hasControl() then break end
    F.press("A", 2); F.idle(60)
    if i <= 4 then F.shot("message_" .. i) end
  end
  F.idle(30)
  F.shot("after_itemfinder")
  local x, y = F.pos()
  F.check("still_on_the_spot", x == PP_MAX_X and y == PP_MAX_Y, string.format("(%d,%d)", x, y))
  F.check("control_returned", hasControl(), "lock=" .. F.r8(S.sLockFieldControls) .. " ctx=" .. F.r8(S.sGlobalScriptContextStatus))
  F.check("pp_max_dug_up", F.itemCount(ITEM_PP_MAX) == 1, "PP Max slots=" .. F.itemCount(ITEM_PP_MAX))
  F.check("hidden_item_flag_set", flagSet(FLAG_HIDDEN_ITEM_TWO_ISLAND_CAPE_BRINK_PP_MAX),
    "flag 0x1011=" .. tostring(flagSet(FLAG_HIDDEN_ITEM_TWO_ISLAND_CAPE_BRINK_PP_MAX)))
  F.finish()
end)
