-- Battle Frontier Exchange Service Corner at the edges: all four clerks, buying with exactly
-- enough Battle Points, one short, a full Items pocket and a full poster inventory.
--
-- Each case loads the same in-corner savestate, seeds the BP (and the full pocket or poster
-- inventory), then with real input walks to the clerk (the side clerks across their side counters),
-- talks, picks the row from the scrollable list and confirms. The BP, the bag count or decoration
-- count after the reply is the verdict: a purchase takes exactly the price and adds one; a refusal
-- (too few BP, no room) takes nothing and adds nothing. Text is set to Instant so every reply settles.
--
-- Run via test/overworld/mgba-run.sh test/overworld/lua/ExchangeCornerPurchases.lua <rom>

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "ExchangeCornerPurchases")

local FRONTIER, CORNER = 26, 42
local ITEM_PROTEIN, ITEM_LEFTOVERS = 66, 472
local DECOR_KISS_POSTER, DECOR_BLASTOISE_DOLL = 75, 116
local DECORCAT_POSTER, DECORCAT_DOLL = 5, 6
local DECOR_INV_STRIDE = 8
local TEXT_SPEED_INSTANT = 3

local function decorCount(cat, id)
  local inv = S.gDecorationInventories + cat * DECOR_INV_STRIDE
  local p, n, c = F.r32(inv), F.r8(inv + 4), 0
  for i = 0, n - 1 do if F.r8(p + i) == id then c = c + 1 end end
  return c
end
local function fillDecor(cat, id)
  local inv = S.gDecorationInventories + cat * DECOR_INV_STRIDE
  for i = 0, F.r8(inv + 4) - 1 do F.w8(F.r32(inv) + i, id) end
end
local function setBp(v) F.w16(F.sb2() + S.SaveBlock2.bp, v) end

local function liveTask(fn)
  for i = 0, S.Task.count - 1 do
    local t = S.gTasks + i * S.Task.stride
    if F.r8(t + S.Task.isActive) ~= 0 and (F.r32(t + S.Task.func) & ~1) == (fn & ~1) then return true end
  end
  return false
end
local function listLive() return liveTask(S.ScrollableMultichoice_ProcessInput) end
local function scriptDone() return F.ow() and F.r8(S.sGlobalScriptContextStatus) == 2 end
local function untilList()
  for _ = 1, 60 do
    F.idle(20)
    if listLive() then F.idle(10); return true end
    if scriptDone() then return false end
    F.press("A", 2)
  end
  return false
end

-- Decor clerk 1 (4,4) and the hold-item clerk (10,4) face their side counters.
local CLERKS = {
  decor1 = { path = { { 2, 7 }, { 2, 4 } }, face = "Right" },
  decor2 = { path = { { 5, 7 } }, face = "Up" },
  vitamin = { path = { { 9, 7 } }, face = "Up" },
  hold = { path = { { 7, 7 }, { 12, 7 }, { 12, 4 } }, face = "Left" },
}

-- Returns whether the list came back after the reply (it does after a purchase and after "not
-- enough BP"; a full bag or PC ends the conversation).
local function buy(tag, clerk, row)
  local c = CLERKS[clerk]
  if not F.check(tag .. ": reached the clerk", F.route(c.path, tag)) then return nil end
  F.face(c.face); F.press("A", 2); F.idle(40)
  if not F.check(tag .. ": the prize list opened", untilList()) then F.shot(tag .. "_nolist"); return nil end
  for _ = 1, row do F.press("Down", 2); F.idle(12) end
  F.shot(tag .. "_row")
  F.press("A", 2)
  for _ = 1, 60 do F.idle(10); if liveTask(S.Task_HandleYesNoInput) then break end end
  F.idle(10); F.press("A", 2); F.idle(40)
  F.shot(tag .. "_reply")
  local back = untilList()
  for _ = 1, 30 do
    if scriptDone() then break end
    F.press("B", 2); F.idle(30)
  end
  return back
end

local base
local function case(tag, seed, clerk, row, check)
  client.loadstate(base); F.idle(10)
  seed()
  local back = buy(tag, clerk, row)
  if back ~= nil then check(back) end
  F.check(tag .. ": control returns", scriptDone())
end

F.run(function()
  if not F.boot(100) then F.check("boot", false); F.finish(); return end
  F.w16(F.sb2() + S.SaveBlock2.optionsU16, (F.r16(F.sb2() + S.SaveBlock2.optionsU16) & ~7) | TEXT_SPEED_INSTANT)
  if not F.check("warp into the Exchange Service Corner", F.warpTo(0, 2, 6, 0, 4, 2, 0, 0, 0, FRONTIER, CORNER, "corner")) then
    F.finish(); return
  end
  F.idle(60)
  base = F.out .. "ExchangeCornerPurchases_base.ss"
  client.savestate(base)

  local protein0, leftovers0 = F.itemCount(ITEM_PROTEIN), F.itemCount(ITEM_LEFTOVERS)
  case("protein_exact", function() setBp(1) end, "vitamin", 0, function(back)
    F.check("protein_exact: 1 BP buys a Protein (1 BP)", F.bp() == 0 and F.itemCount(ITEM_PROTEIN) == protein0 + 1,
      string.format("bp=%d protein=%d", F.bp(), F.itemCount(ITEM_PROTEIN)))
    F.check("protein_exact: the list comes back", back)
  end)
  case("protein_none", function() setBp(0) end, "vitamin", 0, function(back)
    F.check("protein_none: 0 BP is refused", F.bp() == 0 and F.itemCount(ITEM_PROTEIN) == protein0,
      string.format("bp=%d protein=%d", F.bp(), F.itemCount(ITEM_PROTEIN)))
    F.check("protein_none: the list comes back", back)
  end)
  case("leftovers_short", function() setBp(47) end, "hold", 0, function()
    F.check("leftovers_short: 47 BP is refused for Leftovers (48)", F.bp() == 47 and F.itemCount(ITEM_LEFTOVERS) == leftovers0,
      string.format("bp=%d leftovers=%d", F.bp(), F.itemCount(ITEM_LEFTOVERS)))
  end)
  case("leftovers_exact", function() setBp(48) end, "hold", 0, function()
    F.check("leftovers_exact: 48 BP buys Leftovers", F.bp() == 0 and F.itemCount(ITEM_LEFTOVERS) == leftovers0 + 1,
      string.format("bp=%d leftovers=%d", F.bp(), F.itemCount(ITEM_LEFTOVERS)))
  end)
  case("leftovers_full_pocket", function()
    F.dbg(); F.sel(1); F.sel(1); F.sel(3); F.idle(200); F.bOut(4)
    setBp(500)
  end, "hold", 0, function(back)
    F.check("leftovers_full_pocket: a full Items pocket refuses and keeps the BP",
      F.bp() == 500 and F.itemCount(ITEM_LEFTOVERS) == 0, string.format("bp=%d leftovers=%d", F.bp(), F.itemCount(ITEM_LEFTOVERS)))
    F.check("leftovers_full_pocket: the clerk ends the conversation", back == false)
  end)
  case("poster_exact", function() setBp(16) end, "decor1", 0, function()
    F.check("poster_exact: 16 BP buys a Kiss Poster", F.bp() == 0 and decorCount(DECORCAT_POSTER, DECOR_KISS_POSTER) == 1,
      string.format("bp=%d posters=%d", F.bp(), decorCount(DECORCAT_POSTER, DECOR_KISS_POSTER)))
  end)
  case("poster_full", function() fillDecor(DECORCAT_POSTER, DECOR_KISS_POSTER); setBp(500) end, "decor1", 0, function(back)
    F.check("poster_full: a full poster inventory refuses and keeps the BP",
      F.bp() == 500 and decorCount(DECORCAT_POSTER, DECOR_KISS_POSTER) == 10,
      string.format("bp=%d posters=%d", F.bp(), decorCount(DECORCAT_POSTER, DECOR_KISS_POSTER)))
    F.check("poster_full: the clerk ends the conversation", back == false)
  end)
  case("doll_short", function() setBp(255) end, "decor2", 4, function()
    F.check("doll_short: 255 BP is refused for the Blastoise Doll (256)", F.bp() == 255 and decorCount(DECORCAT_DOLL, DECOR_BLASTOISE_DOLL) == 0,
      string.format("bp=%d dolls=%d", F.bp(), decorCount(DECORCAT_DOLL, DECOR_BLASTOISE_DOLL)))
  end)
  case("doll_exact", function() setBp(256) end, "decor2", 4, function()
    F.check("doll_exact: 256 BP buys the Blastoise Doll", F.bp() == 0 and decorCount(DECORCAT_DOLL, DECOR_BLASTOISE_DOLL) == 1,
      string.format("bp=%d dolls=%d", F.bp(), decorCount(DECORCAT_DOLL, DECOR_BLASTOISE_DOLL)))
  end)
  F.check("no crash screen", not F.crashScreen())
  F.finish()
end)
