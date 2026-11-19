-- The Ruins of Alph sliding puzzles under seeded input mashes, on all four boards.
--
-- Each chamber's sign opens the puzzle. A seeded mash of the D-pad, A, L, R and same-frame chords
-- runs first, and after every input the live board must hold each of the 16 tile sprites exactly
-- once (on the board or in hand), the immovable tiles must not move, the cursor sprite must never
-- carry a tile id or a rotation, and `solved` must agree with an independent read of the board.
-- A second mash adds B; when the puzzle closes, the completion flag must match the board.
-- Then B and A pressed on one frame over a tile must quit with nothing picked up.
-- Then a solver that rotates through extra turns and swaps tiles onto occupied slots brings the
-- board to its last tile; placing it with A and B on one frame must quit unsolved. On a fresh
-- board the last tile goes down with A and L on one frame: the board must read solved, the cursor
-- must stay upright, a mash through the glow must not leave early, and the floor must drop the
-- player to B1F with the flag set. Last, the solved picture opens from the Kabuto sign and closes.
--
-- PW_SEED=<n> reseeds every mash (default 1). Each scenario logs its own seed.
-- Run via test/overworld/mgba-run.sh test/overworld/lua/AlphSlidingPuzzleMash.lua

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "AlphSlidingPuzzleMash")

local BASE = tonumber(os.getenv("PW_SEED")) or 1
local CONTEXT_SHUTDOWN = 2
local G, CHAMBERS, B1F = 79, 5, 4
local SPRITE_STRIDE, SPRITE_DATA = 68, 0x2E
local BUF = S.gStringVar4 + 900
local SOLVED = { { 0, 1, 2, 3, 4, 0 }, { 0, 5, 6, 7, 8, 0 }, { 0, 9, 10, 11, 12, 0 }, { 0, 13, 14, 15, 16, 0 } }
local PUZZLES = {
  { name = "kabuto", x = 21, y = 5, flag = 0x602B, itemFlag = 0x606D },
  { name = "omanyte", x = 5, y = 22, flag = 0x602C, itemFlag = 0x606E },
  { name = "aerodactyl", x = 21, y = 22, flag = 0x602A, itemFlag = 0x606F },
  { name = "ho_oh", x = 5, y = 5, flag = 0x6029, itemFlag = 0x6070 },
}

local seed = BASE
local function rnd(n)
  seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF
  return (seed >> 8) % n
end
local function seedFor(tag)
  local h = BASE & 0x7FFFFFFF
  for i = 1, #tag do h = ((h ~ tag:byte(i)) * 16777619) & 0x7FFFFFFF end
  return h
end
local function reseed(tag) seed = seedFor(tag); F.L(string.format("== %s == seed=%d", tag, seed)) end

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

-- struct SlidingPuzzle { u8 tiles[4][6]; puzzleId; cursorSpriteId; heldTile; solved; }
-- and each tile sprite's data[] (row 2, col 3, tile id 4, orientation 5).
local function board() return F.r32(S.sSlidingPuzzle) end
local function cell(r, c) return F.r8(board() + r * 6 + c) end
local function cursorId() return F.r8(board() + 25) end
local function held() return F.r8(board() + 26) end
local function solvedFlag() return F.r8(board() + 27) end
local function sdata(id, k) return F.rs16(S.gSprites + id * SPRITE_STRIDE + SPRITE_DATA + k * 2) end
local function cursorRC() local c = cursorId(); return sdata(c, 2), sdata(c, 3) end
local function inPuzzle() return F.cb2() == (S.CB2_SlidingPuzzle & ~1) end

local function boardSolved()
  for r = 0, 3 do for c = 0, 5 do
    local want, id = SOLVED[r + 1][c + 1], cell(r, c)
    if want == 0 then
      if id ~= 0 then return false end
    elseif id == 0 or sdata(id, 4) ~= want or sdata(id, 5) ~= 0 then
      return false
    end
  end end
  return true
end

-- Returns nil when every invariant holds, else a description of the first one that broke.
local function violation(tiles, immovable)
  local seen, count = {}, 0
  for r = 0, 3 do for c = 0, 5 do
    local id = cell(r, c)
    if id ~= 0 then
      if seen[id] then return string.format("sprite %d twice on the board", id) end
      if not tiles[id] then return string.format("unknown sprite %d at (%d,%d)", id, r, c) end
      seen[id] = true; count = count + 1
    end
  end end
  local h = held()
  if h ~= 0 then
    if seen[h] then return string.format("held sprite %d is also on the board", h) end
    if not tiles[h] then return string.format("held sprite %d is not a tile", h) end
    count = count + 1
    local cr, cc = cursorRC()
    if sdata(h, 2) ~= cr or sdata(h, 3) ~= cc then return "held tile left the cursor" end
  end
  if count ~= 16 then return string.format("%d tiles accounted for", count) end
  local cur = cursorId()
  if sdata(cur, 4) ~= 0 or sdata(cur, 5) ~= 0 then
    return string.format("cursor sprite carries tile id %d orientation %d", sdata(cur, 4), sdata(cur, 5))
  end
  for slot, id in pairs(immovable) do
    if cell(slot // 6, slot % 6) ~= id then return string.format("immovable slot %d moved", slot) end
  end
  local truth = boardSolved()
  if (solvedFlag() == 1) ~= truth then
    return string.format("solved=%d but the board reads %s", solvedFlag(), truth and "solved" or "unsolved")
  end
  return nil
end

local function openPuzzle(p)
  if not warp(G, CHAMBERS, p.x, p.y) then return false end
  F.face("Up"); F.press("A", 2)
  for _ = 1, 300 do F.idle(1); if inPuzzle() then F.idle(60); return true end end
  return false
end

local function boardState()
  local tiles, immovable = {}, {}
  local layout = {}
  for r = 0, 3 do for c = 0, 5 do
    local id = cell(r, c)
    if id ~= 0 then tiles[id] = true end
    layout[r * 6 + c] = id
  end end
  return tiles, layout
end

local POOL = {
  { Up = true }, { Down = true }, { Left = true }, { Right = true },
  { Up = true }, { Down = true }, { Left = true }, { Right = true },
  { A = true }, { A = true }, { A = true }, { L = true }, { R = true }, { R = true },
  { A = true, R = true }, { A = true, L = true }, { A = true, Up = true }, { A = true, Left = true },
  { L = true, R = true }, { Down = true, R = true }, { Start = true }, { Select = true },
}

-- Mash until `steps` inputs land or the puzzle closes; returns the first violation (or nil),
-- whether the puzzle closed, and the board's solved state just before it closed.
local function mash(steps, tiles, immovable, withB)
  local lastTruth = boardSolved()
  for i = 1, steps do
    local keys = POOL[rnd(#POOL) + 1]
    if withB and rnd(40) == 0 then keys = (rnd(2) == 0) and { B = true } or { B = true, A = true } end
    for _ = 1, 1 + rnd(2) do joypad.set(keys); emu.frameadvance() end
    for _ = 1, rnd(9) do joypad.set({}); emu.frameadvance() end
    if not inPuzzle() then return nil, true, lastTruth, i end
    local v = violation(tiles, immovable)
    if v then return string.format("input %d (%s): %s", i, table.concat((function()
      local t = {} for k in pairs(keys) do t[#t + 1] = k end table.sort(t) return t end)(), "+"), v), false, lastTruth, i end
    lastTruth = boardSolved()
  end
  return nil, false, lastTruth, steps
end

local function press(b) F.press(b, 2); F.idle(16) end
-- Quits a board a failed check left open, so later scenarios still start from the field.
local function leave()
  for _ = 1, 20 do
    if not inPuzzle() then break end
    F.press("B", 2); F.idle(30)
  end
  awaitControl("B", 30)
end
local function chord(keys) joypad.set(keys); emu.frameadvance(); F.idle(30) end
local function moveTo(r, c)
  if not r then return false end
  for _ = 1, 14 do
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
local function correct(r, c)
  local want, id = SOLVED[r + 1][c + 1], cell(r, c)
  return want == 0 or (id ~= 0 and sdata(id, 4) == want and sdata(id, 5) == 0)
end
-- Edge slots first, then any free slot. The Ho-Oh board starts with every edge slot taken, so a
-- tile a swap knocks out of the middle can have nowhere else to go.
local function dropHeld()
  for _, c in ipairs({ 0, 5, 1, 2, 3, 4 }) do for r = 0, 3 do
    if cell(r, c) == 0 then moveTo(r, c); press("A"); return held() == 0 end
  end end
  return false
end
-- Turns the held tile upright by a random path: either direction, sometimes a full extra turn.
local function uprightHeld()
  local o = sdata(held(), 5)
  local extra = rnd(2) * 4
  local btn, n = "R", (4 - o) % 4 + extra
  if rnd(2) == 0 then btn, n = "L", o + extra end
  for _ = 1, n do press(btn); F.idle(8) end
  return sdata(held(), 5) == 0
end
local function misplaced()
  local list = {}
  for r = 0, 3 do for c = 1, 4 do if not correct(r, c) then list[#list + 1] = { r, c } end end end
  return list
end

-- Solves until one tile is left, picks it up, turns it upright and stands over its slot.
-- Returns true when the last tile is in hand over the right slot.
local function solveToLast()
  if held() ~= 0 and not dropHeld() then return false end
  for _ = 1, 40 do
    local left = misplaced()
    if #left == 0 then return false end
    local t = left[rnd(#left) + 1]
    local r, c = t[1], t[2]
    local sr, sc = find(SOLVED[r + 1][c + 1])
    if not moveTo(sr, sc) then return false end
    press("A")
    if held() == 0 then return false end
    if not uprightHeld() then return false end
    moveTo(r, c)
    if #left == 1 then return cell(r, c) == 0 end
    press("A")
    if held() ~= 0 and not dropHeld() then return false end
  end
  return false
end

F.run(function()
  if not F.boot(100) then F.check("boot", false); F.finish(); return end
  for _, p in ipairs(PUZZLES) do setflag(p.itemFlag) end
  F.L("PW_SEED=" .. BASE)

  for _, p in ipairs(PUZZLES) do
    local n = p.name
    if F.check(n .. ": the sign opens the puzzle", openPuzzle(p)) then
      local tiles, layout = boardState()
      local immovable = {}
      for slot, id in pairs(layout) do
        local r, c = slot // 6, slot % 6
        if id ~= 0 then
          moveTo(r, c); press("A")
          if held() == 0 then immovable[slot] = id else press("A") end
        end
      end
      local count = 0 for _ in pairs(immovable) do count = count + 1 end
      F.check(n .. ": the board starts with 16 tiles and some immovable", (function()
        local k = 0 for _ in pairs(tiles) do k = k + 1 end return k == 16 and count > 0 end)(), "immovable=" .. count)

      reseed(n .. "/mash")
      local v, closed = mash(700, tiles, immovable, false)
      F.check(n .. ": a mash without B keeps every board invariant", v == nil and not closed, v or (closed and "closed" or ""))
      F.shot(n .. "_mashed")
      if v then leave(); openPuzzle(p) end

      reseed(n .. "/mashB")
      local lastTruth, steps
      v, closed, lastTruth, steps = mash(3000, tiles, immovable, true)
      F.check(n .. ": a mash with B keeps every board invariant", v == nil, v or "")
      if closed then
        F.check(n .. ": the mash's B closes the puzzle and control returns", awaitControl("B", 30), "after " .. steps)
        F.check(n .. ": the flag matches the board left behind", johtoFlag(p.flag) == lastTruth, tostring(lastTruth))
      else
        F.check(n .. ": the mash's B closes the puzzle and control returns", false, "B never landed in " .. steps)
        leave()
      end

      if F.check(n .. ": reopened for B and A on one frame", openPuzzle(p)) then
        local r, c
        for slot, id in pairs(layout) do if id ~= 0 and not immovable[slot] then r, c = slot // 6, slot % 6; break end end
        moveTo(r, c)
        chord({ A = true, B = true })
        local quit = false
        for _ = 1, 120 do if not inPuzzle() then quit = true; break end; F.idle(1) end
        F.check(n .. ": B and A on one frame over a tile quit the puzzle", quit)
        F.check(n .. ": control returns after B and A", awaitControl("B", 30))
        F.check(n .. ": quitting with B and A leaves the puzzle unsolved", not johtoFlag(p.flag))
      end

      reseed(n .. "/solveAB")
      if F.check(n .. ": reopened for the solver", openPuzzle(p)) then
        local ready = solveToLast()
        F.check(n .. ": the solver reaches the last tile in hand", ready, string.format("held=%d left=%d", held(), #misplaced()))
        local v2 = violation(tiles, immovable)
        F.check(n .. ": swaps and extra turns keep every board invariant", v2 == nil, v2 or "")
        F.shot(n .. "_last_tile")
        chord({ A = true, B = true })
        local quit = false
        for _ = 1, 120 do if not inPuzzle() then quit = true; break end; F.idle(1) end
        F.check(n .. ": the last tile with A and B on one frame quits", quit)
        F.check(n .. ": control returns after the last-tile quit", awaitControl("B", 30))
        F.check(n .. ": B beats A on one frame, so the last tile is never placed and the flag stays clear", not johtoFlag(p.flag))
      end

      reseed(n .. "/solveAL")
      if F.check(n .. ": reopened for the real solve", openPuzzle(p)) then
        local ready = solveToLast()
        F.check(n .. ": the solver reaches the last tile again", ready, string.format("held=%d left=%d", held(), #misplaced()))
        chord({ A = true, L = true })
        F.check(n .. ": placing with A and L leaves the board solved", held() == 0 and solvedFlag() == 1 and boardSolved(),
          string.format("held=%d solved=%d", held(), solvedFlag()))
        F.check(n .. ": the cursor stays upright", sdata(cursorId(), 5) == 0 and sdata(cursorId(), 4) == 0)
        -- The glow runs 74 frames and the fanfare 80 before A or B can close the board.
        local early = false
        for i = 1, 70 do
          joypad.set((i % 2 == 0) and { A = true, B = true } or POOL[rnd(#POOL) + 1]); emu.frameadvance()
          if not inPuzzle() then early = true; break end
        end
        F.check(n .. ": a mash through the glow does not leave early", not early)
        F.idle(240); F.shot(n .. "_solved")
        F.press("A", 2)
        local fell = false
        for _ = 1, 600 do
          F.idle(4)
          local x, y = F.pos()
          if F.ow() and F.grp() == G and F.mapn() == B1F and x == p.x and y == p.y then fell = true; break end
        end
        F.check(n .. ": the completion flag is set", johtoFlag(p.flag))
        F.check(n .. ": the floor drops the player to B1F", fell, string.format("map=%d", F.mapn()))
        F.check(n .. ": control returns on B1F", awaitControl("B", 30))
      end
    end
    if F.reportCrash(n) then break end
  end

  local k = PUZZLES[1]
  if F.check("kabuto: the solved picture opens from the sign", openPuzzle(k)) then
    F.idle(30); F.shot("kabuto_solved_picture")
    F.check("kabuto: the solved picture has no cursor", F.r8(board() + 25) == 0xFF, "cursor=" .. F.r8(board() + 25))
    reseed("kabuto/picture")
    for _ = 1, 30 do
      local keys = POOL[rnd(#POOL) + 1]
      joypad.set(keys); emu.frameadvance(); F.idle(3)
      if not inPuzzle() then break end
    end
    F.press("B", 2)
    F.check("kabuto: the solved picture closes and control returns", awaitControl("B", 40))
    F.check("kabuto: the flag stays set", johtoFlag(k.flag))
  end
  F.finish()
end)
