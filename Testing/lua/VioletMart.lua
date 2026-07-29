-- Issue #48: the Violet City Poké Mart clerk opened the shop with a NULL item list.
--
-- `VioletCity_Mart_EventScript_Clerk` ran `pokemart 0`, which `ScrCmd_pokemart` passes straight
-- through to `SetShopItemsForSale(NULL)` (src/shop.c). That trips
-- `assertf(items != NULL, "Shop items list should never be set as NULL")` — a blue screen in a dev
-- build, and dev builds are what ship here — after the "How may I serve you?" box has already
-- drawn, so it reads as a freeze mid-conversation. The fix points the clerk object at the shared
-- `Cherrygrove_Pokemart_EventScript_Clerk`, which every other Johto mart already uses.
--
-- WHY A LIVE RUN: the failure is a runtime assertion. It assembles, links and boots clean, so
-- neither the build, `make check`, nor the new Testing/ValidateScripts.py static guard can observe
-- the shop actually opening. Only running it can.
--
-- WHAT DISCRIMINATES THE BUG, precisely: on the NULL path the assert's recovery block sets
-- `sMartInfo.itemList = sShopItemsListDummy` ({ ITEM_NONE }) and leaves `sMartInfo.itemCount` at
-- the 0 assigned just above it. So the pre-fix state is reachable and readable — itemCount == 0
-- with an empty list. Asserting a specific NON-ZERO count and the exact item ids therefore fails
-- against the old build rather than passing vacuously. This is a RAM assertion, not a screenshot.
--
-- BOTH STOCK TIERS ARE COVERED, including the one normal play cannot reach. The shared script
-- branches on `goto_if_ge VAR_NEWBARK_TOWN_STATE, 5`. In real play that var is always >= 5 by the
-- time any Johto mart is reachable — New Bark's only land exit is gated on Mom's farewell, which
-- is the sole writer of state 5 — so the 2-item tier is dead data in a normal playthrough. A
-- debug warp arrives with the var still 0, which exercises the low tier for free; the run then
-- writes 5 and re-opens the shop to check the tier players actually see.
--
-- Run against a THROWAWAY COPY — lib.new() refuses anything not named Verify*/MigChk*/FixGen*:
--   make -j12                                     # symbols.lua is a prerequisite of `rom`
--   cp <repo>\pokemonworld.gba  BizHawk\Verify1.gba
--   EmuHawk.exe BizHawk\Verify1.gba --lua=<repo>\Testing\lua\VioletMart.lua
local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(require("symbols"), "VioletMart")

-- MAP_VIOLET_CITY_MART = (3 | (78 << 8)); MAP_GROUP is the HIGH byte, so group 78 / num 3.
local MART_GROUP, MART_NUM = 78, 3

-- struct MartInfo (src/shop.c): callback +0, menuActions +4, itemList +8, itemCount +12.
local MART_ITEMLIST, MART_ITEMCOUNT = 8, 12

local ITEM_POKE_BALL, ITEM_POTION, ITEM_ANTIDOTE, ITEM_PARALYZE_HEAL = 1, 28, 43, 44

-- VAR_NEWBARK_TOWN_STATE = VAR_JOHTO_BASE + 0 = 0xA080. Region story vars do NOT live in
-- SaveBlock1.vars[]; GetVarPointer routes REGION_VARS_START..END to
-- gSaveBlock3Ptr->region.regionVars[id - REGION_VARS_START] (src/event_data.c). SaveBlock3 is a
-- fixed EWRAM symbol (no save-block relocation), and symbols.lua derives SaveBlock3.regionVars
-- from the STATIC_ASSERTs in load_save.c, so this is compiler-pinned rather than hand-counted.
local NEWBARK_STATE_ADDR = S.gSaveblock3 + S.SaveBlock3.regionVars + (0xA080 - 0xA000) * 2

local function martCount() return F.r16(S.sMartInfo + MART_ITEMCOUNT) end
local function martList() return F.r32(S.sMartInfo + MART_ITEMLIST) end

-- sMartInfo is a file-scope static: it KEEPS the last shop's list and count after that shop
-- closes. Reading it after a second interaction therefore returns the FIRST shop's stock if the
-- second one has not opened yet — which is exactly how the first version of this suite reported
-- the low tier as the upgraded tier's result. Clearing it before every interaction means a stale
-- value can never be mistaken for a fresh open, and makes the wait below honest.
local function clearMartInfo()
  F.w32(S.sMartInfo + MART_ITEMLIST, 0)
  F.w16(S.sMartInfo + MART_ITEMCOUNT, 0)
end

local function martItems()
  local p, n, t = martList(), martCount(), {}
  if p ~= 0 and n > 0 and n < 64 then
    for i = 0, n - 1 do t[#t + 1] = F.r16(p + i * 2) end
  end
  return t
end

local function itemsEqual(got, want)
  if #got ~= #want then return false end
  for i = 1, #want do if got[i] ~= want[i] then return false end end
  return true
end

local function fmt(t)
  if #t == 0 then return "{}" end
  return "{" .. table.concat(t, ",") .. "}"
end

-- Walk to the clerk's talking tile and press A.
--
-- The clerk object sits at (2,3) behind a solid tile at (3,3); the player stands at (4,3) and
-- faces LEFT. That is two tiles from the NPC, which is correct and not a routing bug:
-- field_control_avatar.c re-looks one tile further when the faced tile is MB_COUNTER, which is how
-- every Poké Mart clerk in the game is reached. A route to a tile "adjacent" to the clerk reports
-- BLOCKED, because (3,3) is the counter. Column x=4 is clear from the warp-in tile (4,7) up to
-- (4,3), so this is a straight walk with no cornering.
-- The script is `lock, faceplayer, message, waitmessage, pokemart`, and the greeting is
-- `gText_HowMayIServeYou` = "Welcome!\pHow may I serve you?". That `\p` is a PAGE BREAK: the box
-- stops and waits for a button before printing the second page, and only then does the script
-- reach `pokemart`. So one A press opens the conversation but never opens the shop — a version of
-- this that pressed A once and then waited 600 frames sat on "Welcome!" forever.
--
-- Keep pressing A until the shop is actually up. SetShopItemsForSale runs inside
-- CreatePokemartMenu before the menu takes input, so itemCount goes non-zero the moment the shop
-- exists — checking it each pass stops the presses right there and cannot stray onto BUY.
local function talkToClerk(tag)
  if not F.leg(4, 3) then F.check("reached the clerk counter tile (4,3) " .. tag, false); return false end
  F.face("Left")
  clearMartInfo()
  for _ = 1, 12 do
    F.press("A", 2); F.idle(40)
    if martCount() > 0 then F.idle(30); return true end
  end
  F.L("  clerk " .. tag .. ": no shop opened after 12 A presses")
  F.shot("noshop_" .. tag)
  return true   -- let the assertions below report it, with the real values
end

F.run(function()
  if not F.boot(100) then F.check("boot to overworld", false); F.finish(); return end

  if not F.warpTo(0, 7, 8, 0, 0, 3, 0, 0, 0, MART_GROUP, MART_NUM, "VioletMart") then
    F.check("warped into VioletCity_Mart", false); F.finish(); return
  end
  F.check("warped into VioletCity_Mart (group 78, map 3)",
    F.grp() == MART_GROUP and F.mapn() == MART_NUM,
    string.format("grp=%d map=%d", F.grp(), F.mapn()))

  -- Baseline: nothing has opened a shop yet this run, so a stale non-zero count cannot make the
  -- checks below pass on their own.
  F.check("no shop open on arrival (baseline itemCount == 0)", martCount() == 0,
    "itemCount=" .. martCount())

  -- ---- tier 1: VAR_NEWBARK_TOWN_STATE < 5 (fresh game; unreachable in normal play) ----
  local state0 = F.r16(NEWBARK_STATE_ADDR)
  F.check("fresh game arrives with VAR_NEWBARK_TOWN_STATE < 5", state0 < 5, "state=" .. state0)

  if not talkToClerk("low_tier") then F.finish(); return end
  F.shot("shop_low_tier")

  -- THE REGRESSION ASSERT. Pre-fix this is 0 (assertf recovery sets the dummy list and leaves the
  -- count at 0) and the screen is the blue assertion box.
  local lowN, lowItems = martCount(), martItems()
  F.check("clerk opened a shop with a NON-EMPTY item list (issue #48)", lowN > 0,
    "itemCount=" .. lowN .. " list=0x" .. string.format("%08x", martList()))
  F.check("low tier sells exactly POTION, ANTIDOTE",
    itemsEqual(lowItems, { ITEM_POTION, ITEM_ANTIDOTE }),
    "got " .. fmt(lowItems) .. " want {" .. ITEM_POTION .. "," .. ITEM_ANTIDOTE .. "}")

  -- Cancelling must hand control back — the script holds a `lock` until it reaches `release`.
  F.check("cancelling the shop returns field control", F.dismiss(60))
  local cx, cy = F.pos()
  F.check("player is still on the counter tile after cancelling", cx == 4 and cy == 3,
    string.format("(%d,%d)", cx, cy))

  -- ---- tier 2: VAR_NEWBARK_TOWN_STATE >= 5 (what players actually see) ----
  -- A read-back only proves the write landed where the write went — the documented trap that let
  -- a stale symbols.lua offset agree with itself while the game saw nothing. The real proof that
  -- this address is the one GetVarPointer resolves is the NEXT check: the stock has to change to
  -- the four-item list, which only happens if the script's `goto_if_ge` saw the 5.
  F.w16(NEWBARK_STATE_ADDR, 5)
  F.check("VAR_NEWBARK_TOWN_STATE reads back as 5", F.r16(NEWBARK_STATE_ADDR) == 5,
    "state=" .. F.r16(NEWBARK_STATE_ADDR))

  if not talkToClerk("upgraded_tier") then F.finish(); return end
  F.shot("shop_upgraded_tier")

  local hiN, hiItems = martCount(), martItems()
  F.check("upgraded tier opened a shop with a NON-EMPTY item list", hiN > 0, "itemCount=" .. hiN)
  F.check("upgraded tier sells POKE BALL, POTION, ANTIDOTE, PARALYZE HEAL",
    itemsEqual(hiItems, { ITEM_POKE_BALL, ITEM_POTION, ITEM_ANTIDOTE, ITEM_PARALYZE_HEAL }),
    "got " .. fmt(hiItems))
  -- The whole point of the fix is that Violet now shares Cherrygrove's script, so its stock must
  -- be the same four items the other five Johto marts sell.
  F.check("the two tiers are different lists (the progression gate really branches)",
    not itemsEqual(lowItems, hiItems), fmt(lowItems) .. " vs " .. fmt(hiItems))

  F.check("cancelling the upgraded shop returns field control", F.dismiss(60))
  local ex, ey = F.pos()
  F.check("player can still walk away afterwards", F.ensureFree(),
    string.format("(%d,%d)", ex, ey))

  F.finish()
end)
