-- The Ruins of Alph's four sliding puzzles and the Kabuto reward chamber, end to end, with real
-- input. No suite drove them before.
--
-- Setup sets the four B1F item hide flags the way Violet City's first-visit heap does. Then for
-- each chamber the suite reads the sign, and on the puzzle screen moves the cursor, picks up,
-- rotates (R) and places tiles with the D-pad, A and R until the board reads solved, then presses
-- A to leave. The completion flag must be set, the floor must open and drop the player to B1F on
-- the same tile, and the chamber's reward (Dome Fossil, Helix Fossil, Old Amber, GS Ball) must
-- stand one tile north and go into the bag on A. Before the Kabuto solve, quitting with B while
-- holding a tile must return control with the flag clear and a fresh board on the next visit;
-- the Kabuto drop must show B1F's "strange presence" line. Last, the Kabuto chamber's sensor must
-- refuse a Lapras lead and open its door for a Kabuto lead, and the door must lead to the reward room.
--
-- Run via test/overworld/mgba-run.sh test/overworld/lua/AlphSlidingPuzzles.lua

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "AlphSlidingPuzzles")

local CONTEXT_SHUTDOWN = 2
local G, CHAMBERS, B1F = 79, 5, 4
local SPRITE_STRIDE, SPRITE_DATA = 68, 0x2E
local BUF = S.gStringVar4 + 900
local SOLVED = { { 0, 1, 2, 3, 4, 0 }, { 0, 5, 6, 7, 8, 0 }, { 0, 9, 10, 11, 12, 0 }, { 0, 13, 14, 15, 16, 0 } }
local PUZZLES = {
  { name = "kabuto", x = 21, y = 5, flag = 0x602B, itemFlag = 0x606D, item = 166 },
  { name = "omanyte", x = 5, y = 22, flag = 0x602C, itemFlag = 0x606E, item = 165 },
  { name = "aerodactyl", x = 21, y = 22, flag = 0x602A, itemFlag = 0x606F, item = 167 },
  { name = "ho_oh", x = 5, y = 5, flag = 0x6029, itemFlag = 0x6070, item = 881 },
}

local function hasControl()
  return F.ow() and F.r8(S.sLockFieldControls) == 0 and F.r8(S.sGlobalScriptContextStatus) == CONTEXT_SHUTDOWN
end
local function runScript(bytes)
  for i, v in ipairs(bytes) do F.w8(BUF + i - 1, v) end
  F.w8(S.sGlobalScriptContext, 0)
  F.w8(S.sGlobalScriptContext + 1, 1)
  F.w32(S.sGlobalScriptContext + 4, 0)
  F.w32(S.sGlobalScriptContext + S.ScriptCtx.scriptPtr, BUF)
  F.w8(S.sGlobalScriptContextStatus, 0)
end
local function settle() for _ = 1, 300 do F.idle(1); if F.r8(S.sGlobalScriptContextStatus) == CONTEXT_SHUTDOWN then return end end end
local function setflag(id) runScript({ 0x29, id & 0xFF, id >> 8, 0x02 }); settle() end
local function warp(g, n, x, y)
  runScript({ 0x39, g, n, 0xFF, x & 0xFF, x >> 8, y & 0xFF, y >> 8, 0x27, 0x02 })
  for _ = 1, 600 do
    F.idle(4)
    local px, py = F.pos()
    if F.grp() == g and F.mapn() == n and px == x and py == y and hasControl() then F.idle(30); return true end
  end
  return false
end
local function johtoFlag(id)
  return (F.r8(F.sb3() + S.SaveBlock3.johtoFlags + ((id - 0x6000) // 8)) & (1 << (id % 8))) ~= 0
end
local function awaitControl(btn, tries)
  for _ = 1, tries or 60 do
    if hasControl() then F.idle(10); return true end
    F.press(btn or "B", 2); F.idle(20)
  end
  return hasControl()
end

local CH = {}
for i = 0, 25 do CH[0xBB + i] = string.char(65 + i); CH[0xD5 + i] = string.char(97 + i) end
CH[0x00] = " "; CH[0xAD] = "."
local function shownText()
  local s = {}
  for i = 0, 199 do
    local c = F.r8(S.gStringVar4 + i)
    if c == 0xFF then break end
    s[#s + 1] = CH[c] or " "
  end
  return table.concat(s)
end

-- The live board: struct SlidingPuzzle { u8 tiles[4][6]; puzzleId; cursorSpriteId; heldTile; solved; }
-- and each tile sprite's data[] (row 2, col 3, tile id 4, orientation 5).
local function board() return F.r32(S.sSlidingPuzzle) end
local function cell(r, c) return F.r8(board() + r * 6 + c) end
local function held() return F.r8(board() + 26) end
local function solvedFlag() return F.r8(board() + 27) end
local function sdata(id, k) return F.rs16(S.gSprites + id * SPRITE_STRIDE + SPRITE_DATA + k * 2) end
local function cursorRC() local c = F.r8(board() + 25); return sdata(c, 2), sdata(c, 3) end
local function inPuzzle() return F.cb2() == (S.CB2_SlidingPuzzle & ~1) end

local function press(b) F.press(b, 2); F.idle(16) end
local function moveTo(r, c)
  for _ = 1, 12 do
    local cr, cc = cursorRC()
    if cr == r and cc == c then return true end
    if cc < c then press("Right") elseif cc > c then press("Left") elseif cr < r then press("Down") else press("Up") end
  end
  return false
end
local function find(tileId)
  for r = 0, 3 do for c = 0, 5 do
    local id = cell(r, c)
    if id ~= 0 and sdata(id, 4) == tileId then return r, c end
  end end
end
local function solve()
  for r = 0, 3 do for c = 0, 5 do
    local want = SOLVED[r + 1][c + 1]
    local id = cell(r, c)
    if want ~= 0 and not (id ~= 0 and sdata(id, 4) == want and sdata(id, 5) == 0) then
      local sr, sc = find(want)
      moveTo(sr, sc); press("A")
      moveTo(r, c)
      for _ = 1, 4 do if sdata(held(), 5) == 0 then break end press("R"); F.idle(30) end
      press("A")
      if held() ~= 0 then moveTo(sr, sc); press("A") end
    end
  end end
  return solvedFlag() == 1
end

local function openPuzzle(p)
  if not warp(G, CHAMBERS, p.x, p.y) then return false end
  F.face("Up"); F.press("A", 2)
  for _ = 1, 300 do F.idle(1); if inPuzzle() then F.idle(60); return true end end
  return false
end

local function givePokemon(sh, st, so, lh, lt, lo)
  F.dbg(); F.idle(60)
  for _ = 1, 3 do F.press("Down", 3); F.idle(16) end
  F.press("A", 3); F.idle(60)
  F.press("Down", 3); F.idle(16)
  F.press("A", 3); F.idle(60)
  F.spin(sh, st, so)
  F.spin(lh, lt, lo)
  F.idle(90)
  F.bOut(4); F.idle(60)
end

F.run(function()
  if not F.boot(100) then F.check("boot", false); F.finish(); return end
  givePokemon(1, 3, 0, 0, 9, 9)
  for _, p in ipairs(PUZZLES) do setflag(p.itemFlag) end

  local k = PUZZLES[1]
  if F.check("kabuto: the sign opens the puzzle", openPuzzle(k)) then
    local r0, c0 = find(6)
    moveTo(r0, c0); press("A")
    F.check("kabuto: a tile is in hand", held() ~= 0, "held=" .. held())
    F.shot("kabuto_holding")
    press("B")
    F.check("kabuto: B with a tile in hand leaves the puzzle", awaitControl("B", 20), "")
    F.check("kabuto: quitting leaves the puzzle unsolved", not johtoFlag(k.flag), "")
    F.check("kabuto: reopened after quitting", openPuzzle(k))
    local r1, c1 = find(6)
    F.check("kabuto: the board starts fresh", r1 == r0 and c1 == c0, string.format("(%d,%d) vs (%d,%d)", r1, c1, r0, c0))
    moveTo(r1, c1); press("A")
    joypad.set({ A = true, R = true }); emu.frameadvance(); F.idle(30)
    F.check("kabuto: placing and rotating together leaves the tile on the board", held() == 0 and cell(r1, c1) ~= 0)
    local cursor = F.r8(board() + 25)
    F.check("kabuto: placement leaves the cursor upright", sdata(cursor, 5) == 0)
  end

  for _, p in ipairs(PUZZLES) do
    local open = (p == k and inPuzzle()) or openPuzzle(p)
    if F.check(p.name .. ": the puzzle is open", open) then
      F.check(p.name .. ": solved with real input", solve(), "solved=" .. solvedFlag())
      F.idle(240); F.shot(p.name .. "_solved")
      F.press("A", 2)
      local fell = false
      for _ = 1, 600 do
        F.idle(4)
        local x, y = F.pos()
        if F.ow() and F.grp() == G and F.mapn() == B1F and x == p.x and y == p.y then fell = true; break end
      end
      F.check(p.name .. ": the completion flag is set", johtoFlag(p.flag), "")
      F.check(p.name .. ": the floor drops the player to B1F on the same tile", fell, string.format("map=%d", F.mapn()))
      F.idle(60)
      local said = shownText()
      F.check(p.name .. ": control returns", awaitControl("B", 30), "")
      if p == k then F.check("kabuto: B1F announces a strange presence", said:find("strange presence") ~= nil, said) end
      F.check(p.name .. ": the reward is unhidden", not johtoFlag(p.itemFlag), "")
      F.shot(p.name .. "_b1f")
      F.face("Up"); F.press("A", 2)
      awaitControl("B", 30)
      F.check(p.name .. ": the reward goes into the bag", F.itemCount(p.item) == 1 and johtoFlag(p.itemFlag), "count=" .. F.itemCount(p.item))
    end
  end

  if F.check("sensor: stand before the Kabuto chamber sensor", warp(G, CHAMBERS, 20, 2)) then
    F.face("Up"); F.w8(S.gStringVar4, 0xFF); F.press("A", 2); F.idle(40)
    local said = shownText()
    awaitControl("B", 20)
    F.check("sensor: a Lapras lead is refused", said:find("ancient sensor") ~= nil and not johtoFlag(0x6033), said)
  end
  givePokemon(1, 3, 9, 0, 1, 9)
  -- Kabuto must lead: the debug Give appended it to slot 2, so swap it with the Lapras in RAM.
  local a, b = S.gParties, S.gParties + S.Pokemon.size
  for i = 0, S.Pokemon.size - 1, 4 do local t = F.r32(a + i); F.w32(a + i, F.r32(b + i)); F.w32(b + i, t) end
  if F.check("sensor: back before the sensor with a Kabuto lead", warp(G, CHAMBERS, 20, 2)) then
    F.face("Up"); F.w8(S.gStringVar4, 0xFF); F.press("A", 2)
    local said = ""
    for _ = 1, 600 do F.idle(1); said = shownText(); if said:find("chamber reacts") then break end end
    awaitControl("B", 30)
    F.check("sensor: the chamber reacts to the Kabuto", said:find("chamber reacts") ~= nil and johtoFlag(0x6033), said)
    F.shot("sensor_open")
    F.step("Right")
    F.step("Up")
    local into = false
    for _ = 1, 200 do F.idle(4); if F.ow() and F.mapn() == CHAMBERS and select(2, F.pos()) > 40 then into = true; break end end
    local x, y = F.pos()
    F.check("sensor: the opened door leads into the reward room", into, string.format("pos=(%d,%d)", x, y))
    F.idle(90); F.shot("reward_room")
  end
  F.finish()
end)
