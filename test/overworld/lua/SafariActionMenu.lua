-- The Safari battle menu offers each region's own choices, and each choice does what its label says.
--
-- Kanto's Safari Zone follows FireRed: BALL, BAIT, ROCK, RUN. The engine already throws bait and
-- rocks in Kanto (HandleAction_ThrowPokeblock and HandleAction_GoNear, src/battle_util.c), but the
-- BW battle UI (#339) drew Hoenn's labels in every region, so Kanto offered POKeBLOCK and GO NEAR
-- and then threw bait and a rock. Johto follows pokemonHnS, whose Safari Zone lends a Pokeblock
-- case at the gate and offers Emerald's BALL, POKeBLOCK, GO NEAR, RUN; Hoenn is Emerald.
--
-- Setup: debug gives one Pokemon; the Safari state is the one EnterSafariMode leaves (the flag,
-- 30 balls, the step clock). Johto and Hoenn get the Pokeblock case their gates require; Kanto's
-- player has none. Wild battles start by walking in each zone's grass. Every choice is made with
-- real input.
--
-- Oracles:
--   * the action box's label tiles (gWindows[B_WIN_ACTION_MENU]) per quadrant: BALL and RUN match
--     across regions, Johto's four match Hoenn's, and Kanto's second and third differ from Hoenn's;
--   * Kanto's second choice throws BAIT without leaving the battle, its third throws a ROCK;
--   * Johto's and Hoenn's second choice opens the Pokeblock case and B returns to the menu, their
--     third creeps closer.
--
-- Run via test/overworld/mgba-run.sh test/overworld/lua/SafariActionMenu.lua

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "SafariActionMenu")

local HUB_GROUP = 100
local FLAG_SYS_SAFARI_MODE = 0x948 + 0x2C
local ITEM_POKEBLOCK_CASE = 722
local SPECIES_MARSHTOMP = 259
local B_WIN_ACTION_MENU = 2
local WINDOW_SIZE = 12
local SLOT_BALL, SLOT_SECOND, SLOT_THIRD, SLOT_RUN = 0, 1, 2, 3

local function d(n) return (n // 100) % 10, (n // 10) % 10, n % 10 end
local function inBattle() return F.cb2() == (S.BattleMainCB2 & ~1) end
local function isAction()
  local c = F.r32(S.gBattlerControllerFuncs) & ~1
  for _, p in ipairs(S.ActionInputFunctions) do if c == (p & ~1) then return true end end
  return false
end
local function options() return F.sb2() + S.SaveBlock2.optionsU16 end
local function instantText() F.w16(options(), (F.r16(options()) & ~7) | 3) end

local function pokeChar(b)
  if b == 0x00 then return " " end
  if b >= 0xA1 and b <= 0xAA then return string.char(48 + (b - 0xA1)) end
  if b >= 0xBB and b <= 0xD4 then return string.char(65 + (b - 0xBB)) end
  if b >= 0xD5 and b <= 0xEE then return string.char(97 + (b - 0xD5)) end
  if b == 0xFE then return " " end
  return ""
end
local function battleText()
  local t = {}
  for i = 0, 199 do
    local b = F.r8(S.gDisplayedStringBattle + i)
    if b == 0xFF then break end
    t[#t + 1] = pokeChar(b)
  end
  return table.concat(t)
end

local function sb1Flag(id, on)
  local a, m = F.sb1() + S.SaveBlock1.flags + (id // 8), 1 << (id % 8)
  F.w8(a, on and (F.r8(a) | m) or (F.r8(a) & ~m))
end

local function giveMon(species)
  local v = species - 1
  F.dbg(); F.sel(3); F.sel(1); F.idle(20)
  F.spin(v // 100, (v // 10) % 10, v % 10); F.idle(20); F.spin(0, 0, 5); F.idle(60); F.bOut(4)
end

local function giveKeyItem(id)
  local ptr, k = F.r32(S.gBagPockets + 4 * S.BagPocket.stride), F.r32(F.sb2() + S.SaveBlock2.encryptionKey) & 0xFFFF
  for s = 0, F.pocketCap(4) - 1 do
    if F.r16(ptr + s * 4) == id then return true end
  end
  for s = 0, F.pocketCap(4) - 1 do
    if F.r16(ptr + s * 4) == 0 then F.w16(ptr + s * 4, id); F.w16(ptr + s * 4 + 2, 1 ~ k); return true end
  end
  return false
end

local function dropKeyItem(id)
  local ptr = F.r32(S.gBagPockets + 4 * S.BagPocket.stride)
  for s = 0, F.pocketCap(4) - 1 do
    if F.r16(ptr + s * 4) == id then F.w16(ptr + s * 4, 0); F.w16(ptr + s * 4 + 2, 0) end
  end
  for s = 0, F.pocketCap(4) - 1 do
    if F.r16(ptr + s * 4) == id then return false end
  end
  return true
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
  local px, py = F.pos()
  F.L(string.format("%s: warp failed at %d/%d (%d,%d)", tag, F.grp(), F.mapn(), px, py))
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

-- The action box's label pixels, split into its four choices (left/right half, top/bottom half).
local function actionLabels()
  local w = S.gWindows + B_WIN_ACTION_MENU * WINDOW_SIZE
  local width, height, data = F.r8(w + 3), F.r8(w + 4), F.r32(w + 8)
  local q = { {}, {}, {}, {} }
  for ty = 0, height - 1 do
    for tx = 0, width - 1 do
      local slot = (tx >= width // 2 and 1 or 0) + (ty >= height // 2 and 2 or 0)
      local t = q[slot + 1]
      t[#t + 1] = memory.readbyterange(data + (ty * width + tx) * 32, 32)
    end
  end
  for i = 1, 4 do q[i] = table.concat(q[i]) end
  return q, string.format("%dx%d@%08X", width, height, data)
end

local function awaitAction(tag)
  for i = 1, 3000 do
    if not inBattle() and i > 30 then return false end
    if isAction() then F.idle(20); return true end
    F.idle(1)
    if F.reportCrash(tag) then return false end
    if i > 200 and i % 30 == 0 then F.press("B", 2) end
  end
  return false
end

local function startBattle(z, tag)
  if not inBattle() then
    for i = 1, 800 do
      if inBattle() then break end
      F.step(z.dirs[(i % #z.dirs) + 1])
      if F.reportCrash(tag) then break end
    end
  end
  return inBattle() and awaitAction(tag)
end

-- Plays out a choice, collecting the battle text, until the next action menu or the battle's end.
-- If the Pokeblock case opens, it is screenshotted and closed with B.
local function choose(slot, tag)
  steer(slot)
  F.press("A", 2)
  local seen, opened, returned = {}, false, false
  for i = 1, 2500 do
    F.idle(1)
    if F.cb2() == (S.CB2_PokeblockMenu & ~1) and not opened then
      opened = true
      F.idle(60)
      F.shot(tag .. "_pokeblock_case")
      for _ = 1, 12 do
        if F.cb2() ~= (S.CB2_PokeblockMenu & ~1) then break end
        F.press("B", 2); F.idle(40)
      end
      for _ = 1, 600 do if inBattle() then break end; F.idle(1) end
      returned = inBattle()
    end
    if F.ow() then break end
    if i % 3 == 0 and inBattle() then
      local s = battleText()
      if s ~= "" and seen[#seen] ~= s then seen[#seen + 1] = s end
    end
    if i > 20 and inBattle() and isAction() then break end
  end
  return table.concat(seen, " | "), opened, returned
end

local function leaveBattle(tag)
  for _ = 1, 3 do
    if not inBattle() then break end
    if isAction() then choose(SLOT_RUN, tag) end
  end
  for i = 1, 600 do
    if F.ow() and i > 60 then break end
    F.idle(1)
    if i % 30 == 0 then F.press("B", 2) end
  end
end

local labels = {}

local function region(z)
  local tag = z.name
  if not F.check(tag .. ": arrives in the Safari Zone", warpToCoords(z.grp, z.map, z.x, z.y, tag)) then return end
  sb1Flag(FLAG_SYS_SAFARI_MODE, true)
  F.w8(S.gNumSafariBalls, 30)
  F.w16(S.gSafariZoneStepCounter, 500)
  instantText()
  F.idle(30)

  if not F.check(tag .. ": a Safari battle reaches the action menu", startBattle(z, tag)) then return end
  F.check(tag .. ": the battle is a Safari battle", F.battleFlags() & 0x80 ~= 0, string.format("flags=%X", F.battleFlags()))
  local q, where = actionLabels()
  labels[tag] = q
  F.L(tag .. ": action box " .. where)
  F.shot(tag .. "_menu")

  local text, opened, returned = choose(SLOT_SECOND, tag)
  F.L(tag .. " second choice: " .. text)
  if z.kanto then
    F.check(tag .. ": the second choice opens no Pokeblock case", not opened)
    F.check(tag .. ": the second choice throws BAIT", text:find("threw some BAIT") ~= nil, text)
    F.shot(tag .. "_after_second")
  else
    F.check(tag .. ": the second choice opens the Pokeblock case", opened)
    F.check(tag .. ": B returns to the action menu", returned and awaitAction(tag))
  end

  if not inBattle() or not isAction() then
    F.check(tag .. ": a second Safari battle reaches the action menu", startBattle(z, tag))
  end
  text = choose(SLOT_THIRD, tag)
  F.L(tag .. " third choice: " .. text)
  if z.kanto then
    F.check(tag .. ": the third choice throws a ROCK", text:find("threw a ROCK") ~= nil, text)
  else
    F.check(tag .. ": the third choice creeps closer", text:find("crept closer") ~= nil, text)
  end
  F.shot(tag .. "_after_third")
  leaveBattle(tag)
  sb1Flag(FLAG_SYS_SAFARI_MODE, false)
end

local LR = { "Left", "Right" }
local ZONES = {
  { name = "johto", grp = 96, map = 5, x = 2, y = 4, dirs = LR, pokeblockCase = true },
  { name = "kanto", kanto = true, grp = 35, map = 63, x = 33, y = 28, dirs = LR },
  { name = "hoenn", grp = 26, map = 3, x = 27, y = 33, dirs = LR, pokeblockCase = true },
}

F.run(function()
  if not F.boot(HUB_GROUP) then F.check("boot", false); F.finish(); return end
  giveMon(SPECIES_MARSHTOMP)
  F.check("one Pokemon in the party", F.r8(S.gPartiesCount) >= 1, "n=" .. F.r8(S.gPartiesCount))
  local only = os.getenv("SAFARI_ZONE")
  for _, z in ipairs(ZONES) do
    if only and not only:find(z.name) then goto continue end
    if z.pokeblockCase then
      F.check(z.name .. ": the gate's Pokeblock case is in the bag", giveKeyItem(ITEM_POKEBLOCK_CASE))
    else
      F.check(z.name .. ": no Pokeblock case in the bag", dropKeyItem(ITEM_POKEBLOCK_CASE))
    end
    region(z)
    ::continue::
  end
  local k, j, h = labels.kanto, labels.johto, labels.hoenn
  if F.check("every region drew its action box", k and j and h) then
    F.check("BALL is the same in every region", k[1] == h[1] and j[1] == h[1])
    F.check("RUN is the same in every region", k[4] == h[4] and j[4] == h[4])
    F.check("Johto offers Hoenn's POKeBLOCK", j[2] == h[2])
    F.check("Johto offers Hoenn's GO NEAR", j[3] == h[3])
    F.check("Kanto's second choice is not POKeBLOCK", k[2] ~= h[2])
    F.check("Kanto's third choice is not GO NEAR", k[3] ~= h[3])
  end
  F.finish()
end)
