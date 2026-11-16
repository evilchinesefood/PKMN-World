-- The Trick House loop for all eight levels, with real input wherever the game's own scripts move
-- the state. Each level: walk in from Route 110, find the Trick Master at that level's hiding spot,
-- watch him leave, open the scroll door and enter that level's puzzle room. The puzzle itself is
-- skipped by warping onto the end room's arrival tile. There the Trick Master is talked to for the
-- reward, the player walks out through the corridor and the front door, and re-enters for the next
-- level. Level 1 is taken with a full Items pocket: the Rare Candy must wait, and the Trick Master
-- must hand it over at the entrance once there is room. Level 8 picks the RED TENT.
--
-- Run: test/overworld/mgba-run.sh test/overworld/lua/TrickHouseRewards.lua

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "TrickHouseRewards")

local CONTEXT_RUNNING, CONTEXT_SHUTDOWN = 0, 2
local MAIN_VBLANK_COUNTER1 = 0x20
local VAR_LEVEL, VAR_ENTRANCE, VAR_PRIZE = 0x4044, 0x40A7, 0x40C1
local VAR_REPEL_STEP_COUNT = 0x4021
local SYS = 0x948
local FLAG_BADGE = { SYS + 7, SYS + 8, SYS + 9, SYS + 10, SYS + 11, SYS + 12, SYS + 13, SYS + 14 }
local FLAG_HOENN_CHAMPION = 0xA4A
local GRP = 29
local MAP_ENTRANCE, MAP_END, MAP_CORRIDOR = 0, 1, 2
local ROUTE110 = { 0, 25 }
local REWARD = { 102, 11, 437, 468, 0, 428, 72 }   -- Rare Candy .. PP Max; TM Taunt checked by pocket

-- hiding spot -> tile to stand on and the facing that looks at it
local HIDE = {
  [0] = { 7, 3, "Left" },  { 10, 5, "Right" }, { 9, 2, "Up" },  { 3, 2, "Up" },
  { 1, 5, "Left" },  { 11, 2, "Up" },  { 8, 2, "Up" },  { 4, 5, "Up" },
}

local function vblank() return F.r32(S.gMain + MAIN_VBLANK_COUNTER1) end
local function hasControl()
  return F.ow() and F.r8(S.sLockFieldControls) == 0 and F.r8(S.sGlobalScriptContextStatus) == CONTEXT_SHUTDOWN
end
local function flagSet(id)
  local a = F.sb1() + S.SaveBlock1.flags + (id // 8)
  F.w8(a, F.r8(a) | (1 << (id % 8)))
end
local function varGet(id) return F.r16(F.sb1() + S.SaveBlock1.vars + (id - 0x4000) * 2) end
local function varSet(id, v) F.w16(F.sb1() + S.SaveBlock1.vars + (id - 0x4000) * 2, v) end

local SCRIPT_BUF = S.gStringVar4 + 960
local function le16(t, v) t[#t + 1] = v & 0xFF; t[#t + 1] = (v >> 8) & 0xFF end
local function runScript(bytes)
  for i, b in ipairs(bytes) do F.w8(SCRIPT_BUF + i - 1, b) end
  F.w8(S.sGlobalScriptContext, 0)
  F.w8(S.sGlobalScriptContext + 1, 1)
  F.w32(S.sGlobalScriptContext + 4, 0)
  F.w32(S.sGlobalScriptContext + S.ScriptCtx.scriptPtr, SCRIPT_BUF)
  F.w8(S.sGlobalScriptContextStatus, CONTEXT_RUNNING)
end

-- Mash A until control comes back (or a frame budget runs out). Returns ok, detail.
local function mashA(tag, budget, keys)
  local frames, settled, lastVb, stalls, i = 0, 0, vblank(), 0, 0
  while frames < (budget or 6000) do
    if F.reportCrash(tag) then return false, "crash screen" end
    local vb = vblank()
    if vb == lastVb then stalls = stalls + 1 else stalls = 0 end
    lastVb = vb
    if stalls > 30 then return false, "vblank counter stopped" end
    if hasControl() then
      settled = settled + 1
      if settled >= 3 then return true, "frames=" .. frames end
      F.idle(10); frames = frames + 10
    else
      settled = 0
      i = i + 1
      F.press(keys and keys[(i % #keys) + 1] or "A", 2); F.idle(12); frames = frames + 14
    end
  end
  return false, string.format("no control after %d frames at %d.%d", frames, F.grp(), F.mapn())
end

local function warpScript(g, n, x, y)
  local b = { 0x39, g, n, 0xFF }
  le16(b, x); le16(b, y); b[#b + 1] = 0x27; b[#b + 1] = 0x02
  runScript(b)
  for _ = 1, 400 do
    F.idle(4)
    if F.reportCrash("warp") then return false end
    if F.grp() == g and F.mapn() == n and F.ow() then return mashA("warp_arrival", 3000, { "B" }) end
  end
  return false
end

local function waitMap(g, n, budget)
  for _ = 1, budget or 600 do
    if F.grp() == g and F.mapn() == n and F.ow() then return true end
    F.idle(4)
  end
  return false
end

-- Walk a list of tiles; a coord event that interrupts a leg is cleared with B and the leg retried.
local function walk(pts, tag)
  for _, p in ipairs(pts) do
    local ok = false
    for _ = 1, 4 do
      if F.leg(p[1], p[2]) then ok = true; break end
      mashA(tag .. "_interrupt", 3000, { "B" })
    end
    if not ok then
      local x, y = F.pos()
      F.L(string.format("  %s: stuck at (%d,%d) heading (%d,%d)", tag, x, y, p[1], p[2]))
      F.shot(tag .. "_stuck")
      return false
    end
  end
  return true
end

local function giveParty()
  F.dbg(); F.idle(40); F.sel(2); F.idle(40)
  for _ = 1, 9 do F.press("Down", 2); F.idle(12) end
  F.press("A", 2); F.idle(180); F.bOut(6); F.idle(60)
end

-- Debug PC/Bag (row 1) -> Fill... (row 1) -> Fill Pocket Items (row 3); PC/Bag -> Clear Bag (row 2).
local function fillItemsPocket()
  F.dbg(); F.sel(1); F.sel(1); F.sel(3); F.idle(120); F.bOut(6); mashA("fill", 2000, { "B" })
end
local function clearBag()
  F.dbg(); F.sel(1); F.sel(2); F.idle(120); F.bOut(6); mashA("clear", 2000, { "B" })
end

local function pocketHas(id) return F.itemCount(id) > 0 end

-- From the Route 110 doorstep, walk into the Trick House.
local function enterFromRoute110(tag)
  if not warpScript(ROUTE110[1], ROUTE110[2], 11, 67) then return false end
  F.step("Up")
  if not waitMap(GRP, MAP_ENTRANCE, 600) then return false end
  return mashA(tag .. "_enter", 4000, { "B" })
end

local function leaveToRoute110(tag)
  if not walk({ { 4, 2 }, { 4, 6 }, { 5, 6 } }, tag .. "_out") then return false end
  F.step("Down"); F.step("Down")
  return waitMap(ROUTE110[1], ROUTE110[2], 600) and mashA(tag .. "_outside", 2000, { "B" })
end

F.run(function()
  if not F.boot(100) then F.finish(); return end
  giveParty()
  for _, f in ipairs(FLAG_BADGE) do flagSet(f) end
  flagSet(FLAG_HOENN_CHAMPION)
  varSet(VAR_REPEL_STEP_COUNT, 250)
  F.ensureFree()

  for lvl = 0, 7 do
    local tag = "L" .. (lvl + 1)
    F.L("-- level " .. (lvl + 1))
    if lvl == 0 then fillItemsPocket() end
    if not F.check(tag .. ": walked in from Route 110", enterFromRoute110(tag)) then break end
    F.check(tag .. ": Trick Master hiding (entrance state 0)", varGet(VAR_ENTRANCE) == 0,
      "state=" .. varGet(VAR_ENTRANCE) .. " level=" .. varGet(VAR_LEVEL))
    local spot = HIDE[lvl]
    if not walk({ { 5, 5 }, { spot[1], 5 }, { spot[1], spot[2] } }, tag .. "_tospot") then
      walk({ { 4, 5 }, { 4, 2 }, { spot[1], 2 }, { spot[1], spot[2] } }, tag .. "_tospot2")
    end
    local x, y = F.pos()
    F.check(tag .. ": standing at the hiding spot", x == spot[1] and y == spot[2], string.format("(%d,%d)", x, y))
    F.face(spot[3])
    F.press("A", 2)
    F.idle(40)
    F.shot(tag .. "_found")
    local ok, detail = mashA(tag .. "_found", 6000)
    F.check(tag .. ": found him; he left for the puzzle (entrance state 1)", ok and varGet(VAR_ENTRANCE) == 1,
      detail .. " state=" .. varGet(VAR_ENTRANCE))
    if not walk({ { 4, 2 }, { 5, 2 } }, tag .. "_todoor") then break end
    F.face("Up")
    F.press("A", 2); F.idle(30)
    for _ = 1, 20 do
      if F.grp() == GRP and F.mapn() == 3 + lvl then break end
      F.press("A", 2); F.idle(30)
    end
    F.check(tag .. ": entered puzzle room " .. (lvl + 1), waitMap(GRP, 3 + lvl, 300),
      string.format("at %d.%d", F.grp(), F.mapn()))
    mashA(tag .. "_puzzle_arrival", 3000, { "B" })
    F.shot(tag .. "_puzzle")

    if not F.check(tag .. ": end room", warpScript(GRP, MAP_END, 10, 2)) then break end
    if not walk({ { 10, 3 }, { 4, 3 }, { 4, 4 } }, tag .. "_tomaster") then
      walk({ { 10, 6 }, { 4, 6 } }, tag .. "_tomaster2")
    end
    x, y = F.pos()
    F.face(y == 4 and "Down" or "Up")
    local before = {}
    for _, id in ipairs(REWARD) do before[id] = F.itemCount(id) end
    F.press("A", 2); F.idle(30)
    F.shot(tag .. "_master")
    ok, detail = mashA(tag .. "_reward", 9000)
    F.check(tag .. ": reward scene returns control", ok, detail)
    F.check(tag .. ": level advanced", varGet(VAR_LEVEL) == lvl + 1, "level=" .. varGet(VAR_LEVEL))
    local id = REWARD[lvl + 1]
    if lvl == 0 then
      F.check(tag .. ": full pocket keeps the Rare Candy waiting", F.itemCount(102) == before[102] and varGet(VAR_PRIZE) == 1,
        string.format("candy %d->%d prize=%d", before[102], F.itemCount(102), varGet(VAR_PRIZE)))
    elseif id and id > 0 then
      F.check(tag .. ": reward item " .. id .. " given", F.itemCount(id) == (before[id] or 0) + 1,
        string.format("%d->%d", before[id] or 0, F.itemCount(id)))
    end

    if not walk({ { 4, 3 }, { 2, 3 }, { 2, 2 } }, tag .. "_tocorridor") then break end
    F.step("Up")
    if not F.check(tag .. ": corridor", waitMap(GRP, MAP_CORRIDOR, 600)) then break end
    mashA(tag .. "_corridor", 2000, { "B" })
    if not walk({ { 4, 3 }, { 4, 10 }, { 2, 10 }, { 2, 22 }, { 4, 22 } }, tag .. "_corridor_walk") then break end
    F.step("Down"); F.step("Down")
    if not F.check(tag .. ": back in the entrance from the corridor", waitMap(GRP, MAP_ENTRANCE, 600),
        string.format("at %d.%d (%d,%d)", F.grp(), F.mapn(), F.pos())) then F.shot(tag .. "_corridor_end"); break end
    mashA(tag .. "_back", 3000, { "B" })
    if lvl == 0 then
      clearBag()
      F.check(tag .. ": Trick Master waits with the prize (entrance state 2)", varGet(VAR_ENTRANCE) == 2 or varGet(VAR_PRIZE) == 1,
        "state=" .. varGet(VAR_ENTRANCE) .. " prize=" .. varGet(VAR_PRIZE))
    end
    if not leaveToRoute110(tag) then F.check(tag .. ": left by the front door", false); break end
    if lvl == 0 then
      if enterFromRoute110(tag .. "_pickup") then
        F.check(tag .. ": entrance state 2 for the pickup", varGet(VAR_ENTRANCE) == 2, "state=" .. varGet(VAR_ENTRANCE))
        walk({ { 4, 5 }, { 4, 2 } }, tag .. "_pickup_walk")
        F.face("Right"); F.press("A", 2); F.idle(30)
        F.shot(tag .. "_pickup")
        ok, detail = mashA(tag .. "_pickup", 6000)
        F.check(tag .. ": Rare Candy handed over at the entrance", ok and F.itemCount(102) == 1 and varGet(VAR_PRIZE) == 0,
          string.format("%s candy=%d prize=%d", detail, F.itemCount(102), varGet(VAR_PRIZE)))
        leaveToRoute110(tag .. "_pickup")
      end
    end
  end
  F.finish()
end)
