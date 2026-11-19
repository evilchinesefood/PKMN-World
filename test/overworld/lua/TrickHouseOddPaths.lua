-- Trick House odd paths, with a Machop follower out the whole time.
--
-- 1. Level 8 with every ORNAMENT decoration slot full (adddecoration scripts), reaching the end
--    room through puzzle 8's scroll, door and stairs: the end room says there is no room, the
--    Trick Master still leaves, the corridor and front door bring the player back to the
--    'mechadoll' (entrance state 6, kept across a save and Continue), a talk with the slots still
--    full keeps the tent pending, and after one slot is freed (removedecoration) the mechadoll
--    hands over the BLUE TENT exactly once.
-- 2. Puzzle 3 (one rock smashed with A and YES) and puzzle 4 (one boulder pushed with Strength):
--    walk out through the start door, back in through the scroll door, then save in the room, soft
--    reset and Continue. The rock stays gone, the boulder stays where it was pushed until the room
--    is re-entered, the follower is out of any obstacle and the room is still walkable. Puzzle 3's
--    first button, taken from the west, raises a blue door on the follower's tile: the follower
--    goes into its Poke Ball and comes back out behind the player.
-- 3. Dig and Teleport from the party menu and an Escape Rope from the Bag, in puzzle 8 and in the
--    end room: each refused, no warp, the rope kept, control back.
-- 4. Puzzle 8 (slippery floor) and puzzle 6 (rotating gates) walked with the follower: the
--    follower never stands on a wall, an object or the player, never crosses a gate arm that turned
--    after the player passed, and leaving and re-entering leaves nothing stuck.
-- 5. A seeded mash of every button during a hiding-spot discovery, the reward text and the Trick
--    Master's exit spin (puzzle 6's level; PW_TRICK_SEED, default 1109).
-- 6. Save and Continue with the Trick Master hiding in the entrance, and in the end room before
--    and after the reward.
-- 7. The gates between puzzles, walked into from Route 110 without and then with the next gate's
--    flag: badge 3 before puzzle 2, and the Hoenn championship (not another region's game clear)
--    before puzzle 8.
--
-- Debug setup only reaches scenes: flags, VAR_TRICK_HOUSE_LEVEL, the party, items, warp scripts.
-- PW_TRICK_ONLY=<n> runs only scenario n; PW_TRICK_TEXT=0..3 sets the text speed (default 3).
--
-- Run: test/overworld/mgba-run.sh test/overworld/lua/TrickHouseOddPaths.lua pokemonworld.gba
--        --out _pwtest/trick --env PW_MAX_FRAMES=900000 --timeout 1800

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "TrickHouseOddPaths")

local ONLY = os.getenv("PW_TRICK_ONLY")
local SEED = tonumber(os.getenv("PW_TRICK_SEED") or "") or 1109
local TEXT_SPEED = tonumber(os.getenv("PW_TRICK_TEXT") or "") or 3      -- 0 slow .. 3 instant

local CONTEXT_RUNNING, CONTEXT_SHUTDOWN = 0, 2
local MAIN_VBLANK_COUNTER1 = 0x20
local VAR_LEVEL, VAR_ENTRANCE, VAR_PRIZE = 0x4044, 0x40A7, 0x40C1
local VAR_REPEL_STEP_COUNT = 0x4021
local SYS = 0x948
local FLAG_BADGE = { SYS + 7, SYS + 8, SYS + 9, SYS + 10, SYS + 11, SYS + 12, SYS + 13, SYS + 14 }
local FLAG_HOENN_CHAMPION = 0xA4A
local FLAG_SYS_USE_STRENGTH = SYS + 0x29
local FLAG_SYS_POKEMON_GET = SYS
local GRP = 29
local MAP_ENTRANCE, MAP_END, MAP_CORRIDOR = 0, 1, 2
local function puzzleMap(level) return 3 + level end
local ROUTE110 = { 0, 25 }
local USM_ICO_PARTY, USM_ICO_BAG, USM_ICO_SAVE = 1, 2, 7
local POCKET_ITEMS = 0
local SPECIES_MACHOP = 66
local MOVE_DIG, MOVE_TELEPORT, MOVE_ROCK_SMASH, MOVE_STRENGTH = 91, 100, 249, 70
local ROW_DIG, ROW_TELEPORT = 1, 2          -- SUMMARY, then the known field moves in move order
local ITEM_ESCAPE_ROPE = 120
local DECORCAT_ORNAMENT = 3
local DECOR_RED_TENT, DECOR_BLUE_TENT, DECOR_SOLID_BOARD = 31, 32, 33
local OBJ_EVENT_ID_FOLLOWER, OBJ_EVENT_ID_PLAYER = 0xFE, 0xFF
local SENTINEL = 0xFFFF

-- hiding spot -> tile to stand on and the facing that looks at it
local HIDE = {
  [0] = { 7, 3, "Left" },  { 10, 5, "Right" }, { 9, 2, "Up" },  { 3, 2, "Up" },
  { 1, 5, "Left" },  { 11, 2, "Up" },  { 8, 2, "Up" },  { 4, 5, "Up" },
}

local rng = SEED
local function rand(n)
  rng = (rng * 1103515245 + 12345) & 0x7FFFFFFF
  return (rng >> 8) % n
end

local function vblank() return F.r32(S.gMain + MAIN_VBLANK_COUNTER1) end
local function hasControl()
  return F.ow() and F.r8(S.sLockFieldControls) == 0 and F.r8(S.sGlobalScriptContextStatus) == CONTEXT_SHUTDOWN
end
local function flagAddr(id) return F.sb1() + S.SaveBlock1.flags + (id // 8) end
local function flagSet(id, on)
  local a = flagAddr(id)
  if on == false then F.w8(a, F.r8(a) & ~(1 << (id % 8)) & 0xFF) else F.w8(a, F.r8(a) | (1 << (id % 8))) end
end
local function flagGet(id) return (F.r8(flagAddr(id)) & (1 << (id % 8))) ~= 0 end
local function varGet(id) return F.r16(F.sb1() + S.SaveBlock1.vars + (id - 0x4000) * 2) end
local function varSet(id, v) F.w16(F.sb1() + S.SaveBlock1.vars + (id - 0x4000) * 2, v) end
local function where() local x, y = F.pos(); return string.format("%d/%d (%d,%d)", F.grp(), F.mapn(), x, y) end
local function vars()
  return string.format("level=%d state=%d prize=%d", varGet(VAR_LEVEL), varGet(VAR_ENTRANCE), varGet(VAR_PRIZE))
end

local SCRIPT_BUF = S.gStringVar4 + 960
local function le16(t, v) t[#t + 1] = v & 0xFF; t[#t + 1] = (v >> 8) & 0xFF end
local function le32(t, v) le16(t, v & 0xFFFF); le16(t, (v >> 16) & 0xFFFF) end
local function runScript(bytes)
  for i, b in ipairs(bytes) do F.w8(SCRIPT_BUF + i - 1, b) end
  F.w8(S.sGlobalScriptContext, 0)
  F.w8(S.sGlobalScriptContext + 1, 1)
  F.w32(S.sGlobalScriptContext + 4, 0)
  F.w32(S.sGlobalScriptContext + S.ScriptCtx.scriptPtr, SCRIPT_BUF)
  F.w8(S.sGlobalScriptContextStatus, CONTEXT_RUNNING)
  for _ = 1, 30 do
    F.idle(1)
    if F.r8(S.sGlobalScriptContextStatus) ~= CONTEXT_RUNNING then break end
  end
end
local function createMon(species, level, moves)
  local b = { 0x23 }; le32(b, S.ScrCmd_createmon | 1)
  b[#b + 1] = 0; b[#b + 1] = 6
  le16(b, species); le16(b, level)
  le32(b, (1 << 17) | (1 << 18) | (1 << 19) | (1 << 20))
  for k = 1, 4 do le16(b, moves[k] or 0) end
  b[#b + 1] = 0x02
  runScript(b); F.idle(20)
  return F.r8(S.gPartiesCount)
end
local function addItem(id, qty) runScript({ 0x44, id & 0xFF, id >> 8, qty & 0xFF, qty >> 8, 0x02 }) end
local function addDecoration(id) runScript({ 0x4B, id & 0xFF, id >> 8, 0x02 }); return F.r16(S.gSpecialVar_Result) end
local function removeDecoration(id) runScript({ 0x4C, id & 0xFF, id >> 8, 0x02 }); return F.r16(S.gSpecialVar_Result) end

-- text: field messages are expanded into gStringVar4
local function decode(addr, max)
  local out = {}
  for i = 0, (max or 200) - 1 do
    local c = F.r8(addr + i)
    if c == 0xFF then break end
    if c == 0x00 then out[#out + 1] = " "
    elseif c >= 0xBB and c <= 0xD4 then out[#out + 1] = string.char(65 + c - 0xBB)
    elseif c >= 0xD5 and c <= 0xEE then out[#out + 1] = string.char(97 + c - 0xD5)
    elseif c >= 0xA1 and c <= 0xAA then out[#out + 1] = string.char(48 + c - 0xA1)
    elseif c == 0xAB then out[#out + 1] = "!"
    elseif c == 0xAD then out[#out + 1] = "."
    elseif c == 0xB8 then out[#out + 1] = ","
    elseif c == 0xB4 then out[#out + 1] = "'"
    elseif c == 0xAC then out[#out + 1] = "?"
    elseif c == 0xFE or c == 0xFA or c == 0xFB then out[#out + 1] = " "
    else out[#out + 1] = "~" end
  end
  return table.concat(out)
end
local function clearText() F.w8(S.gStringVar4, 0xFF) end
local Said = {}
Said.__index = Said
local function newSaid() clearText(); return setmetatable({ list = {}, last = "" }, Said) end
function Said:note()
  local t = decode(S.gStringVar4)
  if t ~= "" and t ~= self.last then self.list[#self.list + 1] = t; self.last = t end
end
function Said:has(s) for _, t in ipairs(self.list) do if t:find(s, 1, true) then return true end end return false end
function Said:all() return table.concat(self.list, " | ") end

-- Press keys until control comes back (or a frame budget runs out). Returns ok, detail.
local function mashA(tag, budget, keys, said)
  local frames, settled, lastVb, stalls, i = 0, 0, vblank(), 0, 0
  while frames < (budget or 6000) do
    if F.reportCrash(tag) then return false, "crash screen" end
    if said then said:note() end
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
  return false, string.format("no control after %d frames at %s", frames, where())
end

-- Seeded mash of every button while a script holds the field. Start is only pressed while a
-- script runs, so it cannot open the menu; once control returns the mash stops.
local MASH_KEYS = { "A", "B", "Start", "Select", "L", "R", "Up", "Down", "Left", "Right" }
local function mashAll(tag, budget, said)
  local frames, settled, lastVb, stalls, presses = 0, 0, vblank(), 0, 0
  while frames < (budget or 9000) do
    if F.reportCrash(tag) then return false, "crash screen" end
    if said then said:note() end
    local vb = vblank()
    if vb == lastVb then stalls = stalls + 1 else stalls = 0 end
    lastVb = vb
    if stalls > 30 then return false, "vblank counter stopped" end
    if hasControl() then
      settled = settled + 1
      if settled >= 3 then return true, string.format("frames=%d presses=%d", frames, presses) end
      F.idle(10); frames = frames + 10
    else
      settled = 0
      local scripted = F.r8(S.sGlobalScriptContextStatus) ~= CONTEXT_SHUTDOWN
      local k = MASH_KEYS[rand(#MASH_KEYS) + 1]
      if not scripted and (k == "Start" or k == "Select") then k = "B" end
      local hold = 1 + rand(3)
      F.press(k, hold); presses = presses + 1
      local gap = rand(9)
      F.idle(gap); frames = frames + hold + gap
    end
  end
  return false, string.format("no control after %d frames at %s", frames, where())
end

local function awaitControl(budget)
  for i = 1, budget or 600 do
    if hasControl() then return true end
    if i % 30 == 0 then F.press("B", 2) else F.idle(1) end
  end
  return hasControl()
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

local function walk(pts, tag)
  for _, p in ipairs(pts) do
    local ok = false
    for _ = 1, 4 do
      if F.leg(p[1], p[2]) then ok = true; break end
      mashA(tag .. "_interrupt", 3000, { "B" })
    end
    if not ok then
      F.L(string.format("  %s: stuck at %s heading (%d,%d)", tag, where(), p[1], p[2]))
      F.shot(tag .. "_stuck")
      return false
    end
  end
  return true
end

-- objects
local function objByLocal(id)
  for i = 0, 15 do
    local o = S.gObjectEvents + i * S.ObjectEvent.stride
    if (F.r8(o) & 1) ~= 0 and F.r8(o + 8) == id then return o end
  end
end
local function objAt(x, y)
  for i = 0, 15 do
    local o = S.gObjectEvents + i * S.ObjectEvent.stride
    local id = F.r8(o + 8)
    if (F.r8(o) & 1) ~= 0 and id ~= OBJ_EVENT_ID_FOLLOWER and id ~= OBJ_EVENT_ID_PLAYER and F.rs16(o + 0x10) == x + 7 and F.rs16(o + 0x12) == y + 7
      and ((F.r8(o + 1) >> 5) & 1) == 0 then return o end
  end
end
local function follower()
  local o = objByLocal(OBJ_EVENT_ID_FOLLOWER)
  if not o then return nil end
  return { x = F.rs16(o + 0x10) - 7, y = F.rs16(o + 0x12) - 7, hidden = ((F.r8(o + 1) >> 5) & 1) == 1 }
end
local function followerStr()
  local f = follower()
  if not f then return "none" end
  return string.format("%s@(%d,%d)", f.hidden and "hidden" or "shown", f.x, f.y)
end

-- static collision of the current map's layout, read from the live map header
local function layoutCollision(x, y)
  local layout = F.r32(S.gMapHeader)
  local w, h = F.r32(layout), F.r32(layout + 4)
  if x < 0 or y < 0 or x >= w or y >= h then return true end
  local map = F.r32(layout + 12)
  return ((F.r16(map + 2 * (y * w + x)) >> 10) & 3) ~= 0
end

-- live collision from the map grid, which carries every setmetatile made since the map loaded
local function liveCollision(x, y)
  local L = S.gBackupMapLayout
  local w, off = F.r32(L + S.BackupMapLayout.width), S.BackupMapLayout.mapOffset
  local map = F.r32(L + S.BackupMapLayout.map)
  return ((F.r16(map + 2 * ((x + off) + (y + off) * w)) >> 10) & 3) ~= 0
end

-- The follower is fine when hidden, or shown on a walkable tile no other object holds.
local function followerSafe()
  local f = follower()
  if not f then return true, "no follower" end
  if f.hidden then return true, followerStr() end
  if layoutCollision(f.x, f.y) or liveCollision(f.x, f.y) then return false, followerStr() .. " on a wall" end
  local px, py = F.pos()
  if f.x == px and f.y == py then return false, followerStr() .. " on the player's tile" end
  local o = objAt(f.x, f.y)
  if o then return false, string.format("%s inside object local %d", followerStr(), F.r8(o + 8)) end
  return true, followerStr()
end

-- Wait for the player to stop moving (a slide or a forced step ends), then let the follower land.
local function settleMove(budget)
  local stable, lx, ly = 0, F.pos()
  for _ = 1, budget or 400 do
    F.idle(1)
    local x, y = F.pos()
    local still = x == lx and y == ly and F.r8(S.gPlayerAvatar + S.PlayerAvatar.tileTransitionState) == 0
    if still then stable = stable + 1 else stable = 0 end
    lx, ly = x, y
    if stable >= 20 then break end
  end
  F.idle(10)
end

-- items and decorations
local function qtyKey() return F.r32(F.sb2() + S.SaveBlock2.encryptionKey) & 0xFFFF end
local function itemSlot(pocket, id)
  local ptr = F.r32(S.gBagPockets + pocket * S.BagPocket.stride)
  for s = 0, F.pocketCap(pocket) - 1 do
    if F.r16(ptr + s * 4) == id then return s, (F.r16(ptr + s * 4 + 2) ~ qtyKey()) & 0xFFFF end
  end
  return -1, 0
end
local function ropes() return select(2, itemSlot(POCKET_ITEMS, ITEM_ESCAPE_ROPE)) end
local function ornaments()
  local base = S.gDecorationInventories + DECORCAT_ORNAMENT * 8
  local p, n = F.r32(base), F.r8(base + 4)
  local r = { n = n, filled = 0, red = 0, blue = 0, board = 0 }
  for i = 0, n - 1 do
    local v = F.r8(p + i)
    if v ~= 0 then r.filled = r.filled + 1 end
    if v == DECOR_RED_TENT then r.red = r.red + 1 elseif v == DECOR_BLUE_TENT then r.blue = r.blue + 1
    elseif v == DECOR_SOLID_BOARD then r.board = r.board + 1 end
  end
  return r
end
local function ornStr(o) return string.format("%d/%d filled red=%d blue=%d board=%d", o.filled, o.n, o.red, o.blue, o.board) end

local function partyHash()
  local n = F.r8(S.gPartiesCount)
  local h = n
  for i = 0, n * S.Pokemon.size - 1, 4 do h = (h * 31 + F.r32(S.gParties + i)) & 0xFFFFFFFF end
  return h
end

local function snapshot()
  local x, y = F.pos()
  return { g = F.grp(), m = F.mapn(), x = x, y = y, party = partyHash(), ropes = ropes(), money = F.money(),
           level = varGet(VAR_LEVEL), state = varGet(VAR_ENTRANCE), prize = varGet(VAR_PRIZE) }
end
local function sameSnap(a, b)
  return a.g == b.g and a.m == b.m and a.x == b.x and a.y == b.y and a.party == b.party and a.ropes == b.ropes
    and a.money == b.money and a.level == b.level and a.state == b.state and a.prize == b.prize
end
local function snapStr(s)
  return string.format("%d/%d (%d,%d) party=%08X ropes=%d money=%d level=%d state=%d prize=%d",
    s.g, s.m, s.x, s.y, s.party, s.ropes, s.money, s.level, s.state, s.prize)
end

-- The field is walkable: one step off and back, along the first free axis.
local function walkable()
  local x0, y0 = F.pos()
  for _, pair in ipairs({ { "Up", "Down" }, { "Right", "Left" }, { "Left", "Right" }, { "Down", "Up" } }) do
    local g, m = F.grp(), F.mapn()
    local nx = x0 + (pair[1] == "Right" and 1 or pair[1] == "Left" and -1 or 0)
    local ny = y0 + (pair[1] == "Down" and 1 or pair[1] == "Up" and -1 or 0)
    if not layoutCollision(nx, ny) and not objAt(nx, ny) and F.step(pair[1]) then
      settleMove()
      local moved = F.grp() == g and F.mapn() == m
      F.step(pair[2]); settleMove()
      local x, y = F.pos()
      if moved and x == x0 and y == y0 then return true end
      return false
    end
  end
  return false
end

-- menus
local function inPartyMenu()
  local c = F.cb2()
  return c == S.CB2_UpdatePartyMenu or c == S.CB2_InitPartyMenu or c == S.CB2_PartyMenuFromStartMenu
end
local function inBag() return F.cb2() == S.CB2_BagMenuRun end
local function backToField(tag)
  for _ = 1, 60 do
    if hasControl() then return true end
    if F.reportCrash(tag) then return false end
    F.press("B", 2); F.idle(24)
  end
  return hasControl()
end

-- Dig or Teleport from the party menu. A is pressed after the choice too, so a YES/NO escape
-- prompt, if one were offered, would be accepted.
local function tryFieldMove(tag, row)
  awaitControl(300)
  local said = newSaid()
  F.press("Start", 2); F.idle(60)
  if not F.selectStartIcon(USM_ICO_PARTY) then backToField(tag); return false, "no PARTY icon" end
  F.press("A", 3)
  for _ = 1, 240 do F.idle(4); if inPartyMenu() then break end end
  F.idle(40)
  F.w8(S.sMenu + 2, 0)
  F.press("A", 3); F.idle(50)
  for _ = 1, 6 do
    if F.mcur() == row then break end
    F.press("Down", 2); F.idle(12)
  end
  F.shot(tag .. "_actions")
  if F.mcur() ~= row then backToField(tag); return false, "action cursor at " .. F.mcur() end
  F.press("A", 3)
  for _ = 1, 40 do F.idle(2); said:note() end
  F.shot(tag .. "_answer")
  for _ = 1, 3 do F.press("A", 2); for _ = 1, 15 do F.idle(2); said:note() end end
  local back = backToField(tag)
  F.idle(120)
  return back, said:all()
end

local function tryEscapeRope(tag)
  awaitControl(300)
  local said = newSaid()
  local slot = itemSlot(POCKET_ITEMS, ITEM_ESCAPE_ROPE)
  if slot < 0 then return false, "no rope" end
  F.w8(S.gBagPosition + 5, POCKET_ITEMS)
  F.w16(S.gBagPosition + 8 + POCKET_ITEMS * 2, slot)
  F.w16(S.gBagPosition + 18 + POCKET_ITEMS * 2, 0)
  F.press("Start", 2); F.idle(60)
  if not F.selectStartIcon(USM_ICO_BAG) then backToField(tag); return false, "no BAG icon" end
  F.press("A", 2)
  for _ = 1, 150 do if inBag() then break end; F.idle(2) end
  F.idle(40)
  F.shot(tag .. "_bag")
  F.press("A", 2); F.idle(40)
  F.press("A", 2)
  for _ = 1, 40 do F.idle(2); said:note() end
  F.shot(tag .. "_answer")
  local back = backToField(tag)
  F.idle(120)
  return back, said:all()
end

local function refusals(tag)
  local cases = {
    { "Dig", function() return tryFieldMove(tag .. "_dig", ROW_DIG) end },
    { "Teleport", function() return tryFieldMove(tag .. "_teleport", ROW_TELEPORT) end },
    { "Escape Rope", function() return tryEscapeRope(tag .. "_rope") end },
  }
  for _, c in ipairs(cases) do
    local before = snapshot()
    local fBefore = followerStr()
    local back, said = c[2]()
    local after = snapshot()
    F.L(string.format("  %s %s said: %s", tag, c[1], said))
    F.check(tag .. ": " .. c[1] .. " refused, control back", back, said)
    F.check(tag .. ": " .. c[1] .. " left map, tile, party, rope and vars unchanged", sameSnap(before, after),
      snapStr(before) .. " -> " .. snapStr(after))
    F.check(tag .. ": " .. c[1] .. " follower unchanged", followerStr() == fBefore, fBefore .. " -> " .. followerStr())
  end
end

-- save, soft reset, Continue
local function driveSave()
  F.w16(S.gSaveAttemptStatus, SENTINEL)
  F.press("Start", 2); F.idle(60)
  if not F.selectStartIcon(USM_ICO_SAVE) then backToField("save"); return "noicon" end
  for i = 1, 3000 do
    if F.r16(S.gSaveAttemptStatus) ~= SENTINEL then
      F.idle(30)
      for _ = 1, 6 do F.press("B", 2); F.idle(20) end
      return F.r16(S.gSaveAttemptStatus) == 1 and "done" or "failed"
    end
    if i % 20 == 1 then joypad.set({ A = true }) else joypad.set({}) end
    emu.frameadvance()
  end
  return "timeout"
end
local function softReset()
  for _ = 1, 8 do joypad.set({ A = true, B = true, Start = true, Select = true }); emu.frameadvance() end
  joypad.set({})
end
local function saveResetContinue(tag)
  awaitControl(300)
  local before = snapshot()
  F.check(tag .. ": saved in the room", driveSave() == "done")
  awaitControl(300)
  softReset()
  F.idle(60)
  local booted = F.boot(nil, true)
  F.check(tag .. ": continued to the field", booted)
  if not booted then return false end
  F.idle(30)
  local after = snapshot()
  F.check(tag .. ": same map and tile after Continue", after.g == before.g and after.m == before.m
    and after.x == before.x and after.y == before.y, snapStr(before) .. " -> " .. snapStr(after))
  F.check(tag .. ": same party, rope, money and vars", sameSnap(before, after))
  F.check(tag .. ": control returns", awaitControl(600))
  return true
end

-- Trick House flow
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

-- Walk in, find the Trick Master at this level's spot and watch him leave. mash = key driver.
local function findMaster(lvl, tag, mash)
  local spot = HIDE[lvl]
  if not walk({ { 5, 5 }, { spot[1], 5 }, { spot[1], spot[2] } }, tag .. "_tospot") then
    walk({ { 4, 5 }, { 4, 2 }, { spot[1], 2 }, { spot[1], spot[2] } }, tag .. "_tospot2")
  end
  F.face(spot[3])
  F.press("A", 2); F.idle(20)
  local ok, detail
  if mash then ok, detail = mash(tag .. "_found") else ok, detail = mashA(tag .. "_found", 6000) end
  return F.check(tag .. ": found him; he left for the puzzle (entrance state 1)", ok and varGet(VAR_ENTRANCE) == 1,
    detail .. " " .. vars())
end
local function discover(lvl, tag, mash)
  if not F.check(tag .. ": walked in from Route 110", enterFromRoute110(tag)) then return false end
  F.check(tag .. ": Trick Master hiding (entrance state 0)", varGet(VAR_ENTRANCE) == 0, vars())
  return findMaster(lvl, tag, mash)
end

-- From the entrance, open the scroll door (state 1) and enter the level's puzzle room.
local function scrollDoor(lvl, tag)
  if not walk({ { 4, 2 }, { 5, 2 } }, tag .. "_todoor") then return false end
  F.face("Up")
  F.press("A", 2); F.idle(30)
  for _ = 1, 20 do
    if F.grp() == GRP and F.mapn() == puzzleMap(lvl) then break end
    F.press("A", 2); F.idle(30)
  end
  local ok = waitMap(GRP, puzzleMap(lvl), 300)
  mashA(tag .. "_arrival", 3000, { "B" })
  return F.check(tag .. ": entered puzzle room " .. (lvl + 1), ok, where())
end

-- Leave a puzzle room through its start door (the south arrow under the arrival tile).
local function startDoorOut(tag)
  if not walk({ { 0, 21 } }, tag .. "_tostart") then return false end
  F.press("Down", 16)
  local ok = waitMap(GRP, MAP_ENTRANCE, 600)
  mashA(tag .. "_entrance", 3000, { "B" })
  return F.check(tag .. ": out through the start door to the entrance", ok, where() .. " " .. vars())
end

local function setLevel(lvl)
  varSet(VAR_LEVEL, lvl); varSet(VAR_ENTRANCE, 0); varSet(VAR_PRIZE, 0)
end

local function followerCheck(tag)
  local ok, d = followerSafe()
  return F.check(tag .. ": follower clear of walls and objects", ok, d)
end

------------------------------------------------------------------------------------------------
local function scenario1()
  F.L("== 1: level 8 with the ORNAMENT slots full ==")
  setLevel(7)
  local o = ornaments()
  for _ = 1, o.n + 2 do if addDecoration(DECOR_SOLID_BOARD) == 0 then break end end
  local full = ornaments()
  F.check("1: every ORNAMENT slot filled through adddecoration", full.n > 0 and full.filled == full.n and full.red == 0
    and full.blue == 0, ornStr(full))
  F.check("1: one more adddecoration is refused", addDecoration(DECOR_SOLID_BOARD) == 0 and ornaments().filled == full.n)

  if not discover(7, "L8") then return end
  if not scrollDoor(7, "L8") then return end
  F.step("Up"); settleMove()
  F.shot("L8_puzzle8")
  F.check("1: follower out in puzzle 8 after a step", follower() ~= nil and not follower().hidden, followerStr())
  followerCheck("L8 arrival")
  refusals("puzzle8")

  -- Reach the end room through the real exit: read the scroll, open the door, take the stairs.
  if not warpScript(GRP, puzzleMap(7), 4, 21) then F.check("1: reach puzzle 8's scroll", false); return end
  F.face("Left")
  local scroll = newSaid()
  F.press("A", 2); F.idle(20)
  mashA("L8_scroll", 6000, nil, scroll)
  F.L("  scroll said: " .. scroll:all())
  F.check("1: puzzle 8 scroll read (state 1)", varGet(0x40B2) == 1, "state=" .. varGet(0x40B2))
  if not warpScript(GRP, puzzleMap(7), 13, 2) then F.check("1: reach puzzle 8's door", false); return end
  F.face("Up")
  local door = newSaid()
  F.press("A", 2); F.idle(20)
  mashA("L8_door", 6000, nil, door)
  F.L("  door said: " .. door:all())
  F.check("1: puzzle 8 door opened (state 2)", varGet(0x40B2) == 2, "state=" .. varGet(0x40B2))
  F.press("Up", 16)
  local trace, seenIn = {}, false
  for i = 1, 600 do
    F.idle(1)
    if F.grp() == GRP and F.mapn() == MAP_END and F.ow() then
      local f = follower()
      local x, y = F.pos()
      local doorSolid = layoutCollision(10, 1)
      local cur = string.format("p(%d,%d) f%s", x, y, followerStr())
      if trace[#trace] ~= cur then trace[#trace + 1] = cur end
      if f and not f.hidden and f.x == 10 and f.y == 1 then seenIn = true end
      if i > 60 and hasControl() then break end
    end
  end
  F.L("  arrival trace: " .. table.concat(trace, " > "))
  if not F.check("1: end room through the exit stairs", waitMap(GRP, MAP_END, 300), where()) then return end
  awaitControl(600)
  F.shot("L8_endroom_arrival")
  F.L("  end room arrival: player " .. where() .. " follower " .. followerStr())
  followerCheck("1: end room arrival")
  F.step("Down"); settleMove()
  F.check("1: follower out in the end room after a step", follower() ~= nil and not follower().hidden, followerStr())
  refusals("endroom")
  if not walk({ { 9, 3 }, { 4, 3 }, { 4, 4 } }, "L8_tomaster") then walk({ { 10, 6 }, { 4, 6 } }, "L8_tomaster2") end
  local _, y = F.pos()
  F.face(y == 4 and "Down" or "Up")
  local said = newSaid()
  F.press("A", 2); F.idle(30)
  local ok, detail = mashA("L8_reward", 12000, nil, said)
  F.L("  end room said: " .. said:all())
  F.shot("L8_after_reward")
  F.check("1: reward scene returns control", ok, detail)
  F.check("1: the Trick Master says there is no room", said:has("No room in your PC"), said:all())
  local after = ornaments()
  F.check("1: no tent added, slots unchanged", after.filled == full.n and after.red == 0 and after.blue == 0, ornStr(after))
  F.check("1: level 8 recorded and the tent kept pending", varGet(VAR_LEVEL) == 8 and varGet(VAR_PRIZE) == 1, vars())
  F.check("1: the Trick Master left the end room", objAt(4, 5) == nil)

  if not walk({ { 4, 3 }, { 2, 3 }, { 2, 2 } }, "L8_tocorridor") then return end
  F.step("Up")
  if not F.check("1: corridor", waitMap(GRP, MAP_CORRIDOR, 600)) then return end
  mashA("L8_corridor", 2000, { "B" })
  if not walk({ { 4, 3 }, { 4, 10 }, { 2, 10 }, { 2, 22 }, { 4, 22 } }, "L8_corridor_walk") then return end
  F.step("Down"); F.step("Down")
  if not F.check("1: back in the entrance from the corridor", waitMap(GRP, MAP_ENTRANCE, 600), where()) then return end
  mashA("L8_back", 3000, { "B" })
  F.check("1: entrance state 5 after the corridor", varGet(VAR_ENTRANCE) == 5, vars())
  if not leaveToRoute110("L8") then F.check("1: left by the front door", false); return end
  if not F.check("1: walked back in", enterFromRoute110("L8_pickup")) then return end
  F.check("1: the mechadoll waits (entrance state 6)", varGet(VAR_ENTRANCE) == 6, vars())
  F.check("1: the mechadoll stands in front of the scroll", objAt(5, 2) ~= nil)
  F.shot("L8_mechadoll")
  if saveResetContinue("1: mechadoll waiting") then
    F.check("1: the mechadoll still waits after Continue", objAt(5, 2) ~= nil and varGet(VAR_ENTRANCE) == 6, vars())
  end

  walk({ { 4, 5 }, { 4, 2 } }, "L8_pickup_walk")
  F.face("Right")
  said = newSaid()
  F.press("A", 2); F.idle(30)
  ok, detail = mashA("L8_pickup_full", 9000, nil, said)
  F.L("  mechadoll (full) said: " .. said:all())
  F.check("1: talk with the slots full returns control", ok, detail)
  F.check("1: the mechadoll says the PC is full again", said:has("full") or said:has("room"), said:all())
  after = ornaments()
  F.check("1: still no tent, the reward still pending", after.filled == full.n and after.red == 0 and after.blue == 0
    and varGet(VAR_PRIZE) == 1 and varGet(VAR_ENTRANCE) == 6, ornStr(after) .. " " .. vars())

  removeDecoration(DECOR_SOLID_BOARD)
  local freed = ornaments()
  F.check("1: one ORNAMENT slot freed", freed.filled == full.n - 1, ornStr(freed))
  F.face("Right")
  F.w8(S.sMenu + 2, 0); F.w8(S.sMenu + S.Menu.maxCursorPos, 0)
  said = newSaid()
  F.press("A", 2); F.idle(30)
  local picked = false
  for _ = 1, 60 do
    said:note()
    if F.taskLive(S.Task_HandleMultichoiceInput) then
      F.idle(10)
      for _ = 1, 4 do
        if F.mcur() == 1 then break end
        F.press("Down", 2); F.idle(12)
      end
      F.shot("L8_tent_choice")
      picked = F.mcur() == 1
      F.press("A", 2); F.idle(20)
      break
    end
    F.press("A", 2); F.idle(24)
  end
  F.check("1: BLUE TENT chosen on the mechadoll's list", picked)
  ok, detail = mashA("L8_pickup", 9000, nil, said)
  F.L("  mechadoll said: " .. said:all())
  F.check("1: mechadoll scene returns control", ok, detail)
  after = ornaments()
  F.check("1: the BLUE TENT handed over exactly once", after.blue == 1 and after.red == 0 and after.filled == full.n,
    ornStr(after))
  F.check("1: reward cleared (prize 0, entrance state 5)", varGet(VAR_PRIZE) == 0 and varGet(VAR_ENTRANCE) == 5, vars())
  F.check("1: the mechadoll is gone", objAt(5, 2) == nil)
  F.face("Right"); F.press("A", 2); F.idle(30)
  F.check("1: nothing answers a second talk", awaitControl(120) and ornaments().blue == 1, ornStr(ornaments()))
  if not leaveToRoute110("L8_done") then return end
  if not enterFromRoute110("L8_done") then return end
  F.check("1: after the journey note state (4), still one tent", varGet(VAR_ENTRANCE) == 4 and ornaments().blue == 1
    and objAt(5, 2) == nil, vars() .. " " .. ornStr(ornaments()))
  F.check("1: the entrance is walkable", walkable())
  leaveToRoute110("L8_final")
end

------------------------------------------------------------------------------------------------
local P3_ROCK, P3_ROCK2 = 6, 7          -- Puzzle 3 breakable rocks at (1,20) and (2,21)
local P4_BOULDER = 10                    -- Puzzle 4 boulder at (5,7), pushed Right from (4,7)
local P4_PATH = { { 0, 20 }, { 0, 12 }, { 1, 12 }, { 1, 10 }, { 4, 10 }, { 4, 7 } }
local P4_BACK = { { 4, 10 }, { 1, 10 }, { 1, 12 }, { 0, 12 }, { 0, 21 } }

local function objPos(id)
  local o = objByLocal(id)
  if not o then return nil end
  return F.rs16(o + 0x10) - 7, F.rs16(o + 0x12) - 7
end
local function objPosStr(id)
  local x, y = objPos(id)
  return x and string.format("(%d,%d)", x, y) or "gone"
end

local function followerAfterStep(tag, dir, back)
  F.step(dir); settleMove()
  if back then F.step(back); settleMove() end
  local f = follower()
  F.check(tag .. ": follower out after a step", f ~= nil and not f.hidden, followerStr())
  followerCheck(tag)
end

local function scenario2()
  F.L("== 2: puzzle 3 rock and puzzle 4 boulder, re-entry and Continue ==")
  setLevel(2)
  if not discover(2, "P3") then return end
  if not scrollDoor(2, "P3") then return end
  F.step("Up"); settleMove()
  F.check("2: puzzle 3 rocks in place", objPos(P3_ROCK) == 1 and objPos(P3_ROCK2) == 2,
    objPosStr(P3_ROCK) .. " " .. objPosStr(P3_ROCK2))
  F.face("Right")
  local said = newSaid()
  F.press("A", 2); F.idle(20)
  local ok, detail = mashA("P3_smash", 6000, nil, said)
  F.L("  rock said: " .. said:all())
  F.check("2: Rock Smash with A and YES returns control", ok and said:has("ROCK SMASH"), detail .. " " .. said:all())
  F.check("2: the rock at (1,20) is gone, the other stays", objByLocal(P3_ROCK) == nil and objPos(P3_ROCK2) == 2,
    objPosStr(P3_ROCK) .. " " .. objPosStr(P3_ROCK2))
  F.shot("P3_smashed")
  followerCheck("2: after the smash")
  if not startDoorOut("P3") then return end
  F.check("2: entrance still open for the puzzle (state 1)", varGet(VAR_ENTRANCE) == 1, vars())
  if not scrollDoor(2, "P3_again") then return end
  F.check("2: the smashed rock stays gone on re-entry", objByLocal(P3_ROCK) == nil and objAt(1, 20) == nil
    and objPos(P3_ROCK2) == 2, objPosStr(P3_ROCK) .. " " .. objPosStr(P3_ROCK2))
  followerAfterStep("2: puzzle 3 re-entry", "Up")
  F.check("2: the rock's tile is walkable", walk({ { 1, 20 } }, "P3_rocktile"), where())
  F.shot("P3_reentered")
  if saveResetContinue("P3") then
    F.check("2: the rock is still gone after Continue", objByLocal(P3_ROCK) == nil and objAt(1, 20) == nil, objPosStr(P3_ROCK))
    followerAfterStep("2: puzzle 3 after Continue", "Right", "Left")
    F.check("2: puzzle 3 path open past the rock", walk({ { 1, 20 }, { 6, 20 }, { 1, 20 }, { 1, 17 }, { 1, 20 }, { 0, 20 } }, "P3_path"), where())
    F.shot("P3_continued")
  end
  -- Button 1 at (4,14) taken from the west: the blue door it raises lands on (3,14), the tile the
  -- follower steps onto behind the player.
  if F.check("2: reach the tile west of puzzle 3's first button", warpScript(GRP, puzzleMap(2), 1, 14), where()) then
    F.step("Right"); settleMove(); F.step("Right"); settleMove()
    F.L(string.format("  before the button: player %s follower %s doors=%d", where(), followerStr(), varGet(0x4009)))
    local trace = {}
    F.step("Right")
    for _ = 1, 240 do
      F.idle(1)
      local cur = string.format("p(%d,%d) f%s solid(3,14)=%s", select(1, F.pos()), select(2, F.pos()), followerStr(),
        tostring(liveCollision(3, 14)))
      if trace[#trace] ~= cur then trace[#trace + 1] = cur end
    end
    mashA("P3_button", 3000, { "B" })
    F.L("  button trace: " .. table.concat(trace, " > "))
    F.shot("P3_button")
    F.check("2: the button swapped the doors and (3,14) is solid", varGet(0x4009) == 1 and liveCollision(3, 14),
      string.format("doors=%d solid=%s", varGet(0x4009), tostring(liveCollision(3, 14))))
    followerCheck("2: after the door rose on the follower's tile")
    local f = follower()
    F.check("2: the follower is not left inside the raised door", not (f and not f.hidden and f.x == 3 and f.y == 14), followerStr())
    followerAfterStep("2: one step after the button", "Down")
    local f2 = follower()
    F.check("2: the follower came back out behind the player", f2 and not f2.hidden and f2.x == 4 and f2.y == 14, followerStr())
    walk({ { 4, 14 } }, "P3_button_back")
  end
  if not warpScript(GRP, puzzleMap(2), 0, 20) then return end
  if not startDoorOut("P3_done") then return end
  leaveToRoute110("P3")

  setLevel(3)
  if not discover(3, "P4") then return end
  if not scrollDoor(3, "P4") then return end
  local function pushBoulder(tag)
    if not walk(P4_PATH, tag .. "_toboulder") then return false end
    local x0, y0 = objPos(P4_BOULDER)
    F.check(tag .. ": boulder at (5,7) before the push", x0 == 5 and y0 == 7, objPosStr(P4_BOULDER))
    F.face("Right")
    said = newSaid()
    F.press("A", 2); F.idle(20)
    ok, detail = mashA(tag .. "_strength", 6000, nil, said)
    F.L("  boulder said: " .. said:all())
    F.check(tag .. ": STRENGTH on with A and YES", ok and flagGet(FLAG_SYS_USE_STRENGTH), detail .. " " .. said:all())
    F.press("Right", 24); settleMove(); F.idle(30)
    local bx, by = objPos(P4_BOULDER)
    F.L(string.format("  %s: boulder %s player %s follower %s", tag, objPosStr(P4_BOULDER), where(), followerStr()))
    F.shot(tag .. "_pushed")
    return F.check(tag .. ": boulder pushed from (5,7) to (6,7)", bx == 6 and by == 7, objPosStr(P4_BOULDER))
  end
  pushBoulder("P4")
  followerCheck("2: after the push")
  if not walk(P4_BACK, "P4_back") then return end
  if not startDoorOut("P4") then return end
  F.check("2: STRENGTH off after leaving", not flagGet(FLAG_SYS_USE_STRENGTH))
  if not scrollDoor(3, "P4_again") then return end
  followerAfterStep("2: puzzle 4 re-entry", "Up")
  if not pushBoulder("P4_again") then return end
  F.step("Right"); settleMove()
  F.check("2: the player walks into the boulder's old tile", select(1, F.pos()) == 5, where())
  local bx, by = objPos(P4_BOULDER)
  if saveResetContinue("P4") then
    F.L(string.format("  P4 after Continue: boulder %s player %s follower %s", objPosStr(P4_BOULDER), where(), followerStr()))
    local cx, cy = objPos(P4_BOULDER)
    F.check("2: the boulder stays where it was pushed", cx == bx and cy == by, objPosStr(P4_BOULDER))
    followerAfterStep("2: puzzle 4 after Continue", "Left", "Right")
    F.check("2: puzzle 4 not sealed: back to the start door", walk({ { 4, 7 } }, "P4_cont") and walk(P4_BACK, "P4_cont_back"), where())
    F.shot("P4_continued")
    if startDoorOut("P4_done") then
      if scrollDoor(3, "P4_reset") and walk(P4_PATH, "P4_reset_walk") then
        local rx, ry = objPos(P4_BOULDER)
        F.check("2: re-entry after Continue resets the boulder to (5,7)", rx == 5 and ry == 7, objPosStr(P4_BOULDER))
        if walk(P4_BACK, "P4_reset_back") then startDoorOut("P4_reset_out") end
      end
    end
  end
  leaveToRoute110("P4")
end

------------------------------------------------------------------------------------------------
-- Rotating gates (src/rotating_gate.c): each pivot sits on the top-left corner of tile (x,y) and
-- its arms lie on the grid lines through it. World arm a (0 N, 1 E, 2 S, 3 W) exists when
-- ARM_LAYOUT[shape][((a - orientation) % 4) * 2 + long]; the orientation bytes start at VAR_TEMP_0.
local ARM_LAYOUT = {
  [0] = { 1, 0, 1, 0, 0, 0, 0, 0 }, { 1, 1, 1, 0, 0, 0, 0, 0 }, { 1, 0, 1, 1, 0, 0, 0, 0 }, { 1, 1, 1, 1, 0, 0, 0, 0 },
  { 1, 0, 1, 0, 1, 0, 0, 0 }, { 1, 1, 1, 0, 1, 0, 0, 0 }, { 1, 0, 1, 1, 1, 0, 0, 0 }, { 1, 0, 1, 0, 1, 1, 0, 0 },
}
local L1, L2, L3, L4, T1, T3 = 0, 1, 2, 3, 4, 6
local P6_GATES = {
  { 14, 5, T1, 1 }, { 10, 6, L2, 2 }, { 6, 6, L4, 1 }, { 14, 8, T1, 1 }, { 3, 10, L3, 3 }, { 9, 14, L1, 1 },
  { 3, 15, T3, 0 }, { 2, 17, L2, 2 }, { 12, 18, T3, 3 }, { 5, 18, L4, 1 }, { 10, 19, L3, 2 },
}
local function gateOrient(i) return F.r8(F.sb1() + S.SaveBlock1.vars + (i - 1)) end
local function orients()
  local t = {}
  for i = 1, #P6_GATES do t[i] = gateOrient(i) end
  return t
end
local function hasArm(o, i, a, long)
  local g = P6_GATES[i]
  return ARM_LAYOUT[g[3]][((a - o[i]) % 4) * 2 + (long and 2 or 1)] == 1
end
-- Does a one-tile move from (x1,y1) to (x2,y2) cross a gate arm, with the gates turned as in o?
local function crossesArm(o, x1, y1, x2, y2)
  for i, g in ipairs(P6_GATES) do
    local gx, gy = g[1], g[2]
    if x1 == x2 and math.max(y1, y2) == gy then
      if (x1 == gx - 1 and hasArm(o, i, 3, false)) or (x1 == gx - 2 and hasArm(o, i, 3, true))
        or (x1 == gx and hasArm(o, i, 1, false)) or (x1 == gx + 1 and hasArm(o, i, 1, true)) then return i end
    elseif y1 == y2 and math.max(x1, x2) == gx then
      if (y1 == gy - 1 and hasArm(o, i, 0, false)) or (y1 == gy - 2 and hasArm(o, i, 0, true))
        or (y1 == gy and hasArm(o, i, 2, false)) or (y1 == gy + 1 and hasArm(o, i, 2, true)) then return i end
    end
  end
  return nil
end
local function orientStr()
  local t = {}
  for i = 1, #P6_GATES do t[#t + 1] = tostring(gateOrient(i)) end
  return table.concat(t)
end
local function configOrients()
  local t = {}
  for _, g in ipairs(P6_GATES) do t[#t + 1] = tostring(g[4]) end
  return table.concat(t)
end

-- Step and judge the follower: never on a wall or object, and never across a gate arm that
-- arrived after the player crossed the same edge. An arm that turns onto the edge the player is
-- crossing is vanilla rotating_gate.c (it checks only map collision for the swept tiles), so the
-- player's own crossings are logged, not failed, and the follower is judged against the gates as
-- they stood when the player made that move.
local function trackedStep(tag, dir, gates, hist)
  local px, py = F.pos()
  local f0 = follower()
  local moved = F.step(dir)
  settleMove()
  local qx, qy = F.pos()
  local f1 = follower()
  local bad, note = {}, ""
  local ok, d = followerSafe()
  if not ok then bad[#bad + 1] = d end
  if gates then
    local o = orients()
    if moved then
      local pc = crossesArm(o, px, py, qx, qy)
      if pc then note = string.format(" (player crossed gate %d as it turned)", pc) end
    end
    if f0 and f1 and not f0.hidden and not f1.hidden and (f0.x ~= f1.x or f0.y ~= f1.y) then
      local fc = crossesArm(o, f0.x, f0.y, f1.x, f1.y)
      local prev = hist[f0.x .. "," .. f0.y .. ">" .. f1.x .. "," .. f1.y]
      if fc and not (prev and crossesArm(prev, f0.x, f0.y, f1.x, f1.y)) then
        bad[#bad + 1] = string.format("follower crossed gate %d (%d,%d)->(%d,%d)", fc, f0.x, f0.y, f1.x, f1.y)
      end
    end
    if moved then hist[px .. "," .. py .. ">" .. qx .. "," .. qy] = o end
  end
  F.L(string.format("    %s %s: (%d,%d)->(%d,%d) follower %s%s%s%s", tag, dir, px, py, qx, qy, followerStr(),
    gates and (" gates " .. orientStr()) or "", note, #bad > 0 and (" BAD " .. table.concat(bad, "; ")) or ""))
  return moved, bad
end
local function trackedWalk(tag, dirs, gates)
  local bads, blocked, hist, done = {}, 0, {}, {}
  for _, dir in ipairs(dirs) do
    if F.reportCrash(tag) then bads[#bads + 1] = "crash"; break end
    local moved, bad = trackedStep(tag, dir, gates, hist)
    if moved then done[#done + 1] = dir else blocked = blocked + 1 end
    for _, b in ipairs(bad) do bads[#bads + 1] = b end
  end
  return bads, blocked, done
end
local OPPOSITE = { Up = "Down", Down = "Up", Left = "Right", Right = "Left" }
local function reversed(dirs)
  local t = {}
  for i = #dirs, 1, -1 do t[#t + 1] = OPPOSITE[dirs[i]] end
  return t
end

local P6_OUT = { "Up", "Up", "Right", "Up", "Right", "Right", "Up", "Up", "Up", "Up" }

local function scenario45()
  F.L(string.format("== 4/5: puzzle 6 gates with the follower, seeded mash (seed %d) ==", SEED))
  setLevel(5)
  local said = newSaid()
  if not discover(5, "P6", function(tag) return mashAll(tag, 12000, said) end) then
    F.L("  discovery said: " .. said:all())
    return
  end
  F.L("  mashed discovery said: " .. said:all())
  F.check("5: mashed discovery left the player standing in the entrance", F.grp() == GRP and F.mapn() == MAP_ENTRANCE
    and walkable(), where())
  if not scrollDoor(5, "P6") then return end
  F.check("4: gates at their start orientations", orientStr() == configOrients(), orientStr())
  local bads, blocked, done = trackedWalk("P6", P6_OUT, true)
  F.shot("P6_walked")
  F.check("4: walked into puzzle 6 and turned at least one gate", orientStr() ~= configOrients(),
    string.format("gates %s blocked=%d at %s", orientStr(), blocked, where()))
  F.check("4: follower never on a wall, an object or across a gate arm (puzzle 6)", #bads == 0, table.concat(bads, "; "))
  local back = reversed(done)
  table.remove(back)
  bads = trackedWalk("P6_back", back, true)
  F.check("4: follower clean on the way back", #bads == 0, table.concat(bads, "; "))
  if not startDoorOut("P6") then return end
  if not scrollDoor(5, "P6_again") then return end
  F.check("4: gates reset on re-entry", orientStr() == configOrients(), orientStr())
  followerAfterStep("4: puzzle 6 re-entry", "Up")
  bads = trackedWalk("P6_again", { "Up", "Right", "Right", "Left", "Left", "Down" }, true)
  F.check("4: puzzle 6 walkable after re-entry, follower clean", #bads == 0, table.concat(bads, "; "))

  if not F.check("5: end room", warpScript(GRP, MAP_END, 10, 2)) then return end
  F.step("Down"); settleMove()
  if not walk({ { 9, 3 }, { 4, 3 }, { 4, 4 } }, "P6_tomaster") then walk({ { 10, 6 }, { 4, 6 } }, "P6_tomaster2") end
  local _, y = F.pos()
  F.face(y == 4 and "Down" or "Up")
  local magnets = F.itemCount(428)
  said = newSaid()
  F.press("A", 2); F.idle(20)
  local ok, detail = mashAll("P6_reward", 15000, said)
  F.L("  mashed reward said: " .. said:all())
  F.shot("P6_after_mash")
  F.check("5: mashed reward text and exit spin return control", ok, detail)
  F.check("5: level 6 recorded once, MAGNET given once", varGet(VAR_LEVEL) == 6 and F.itemCount(428) == magnets + 1
    and varGet(VAR_PRIZE) == 0, string.format("%s magnet slots %d->%d", vars(), magnets, F.itemCount(428)))
  F.check("5: the Trick Master left", objAt(4, 5) == nil)
  F.check("5: end room walkable after the mash", walkable(), where())
  followerCheck("5: after the mash")
end

local function scenario4b()
  F.L("== 4: puzzle 8 slippery floor with the follower ==")
  setLevel(7)
  if not discover(7, "P8") then return end
  if not scrollDoor(7, "P8") then return end
  local bads = trackedWalk("P8", { "Up", "Up" }, false)
  local x, y = F.pos()
  F.shot("P8_slid")
  F.check("4: slid up the column to (0,11)", x == 0 and y == 11, where())
  F.check("4: follower clean after the slide up", #bads == 0, table.concat(bads, "; ") .. " " .. followerStr())
  bads = trackedWalk("P8_down", { "Down" }, false)
  x, y = F.pos()
  F.check("4: slid back down to (0,20)", x == 0 and y == 20, where())
  F.check("4: follower clean after the slide down", #bads == 0, table.concat(bads, "; ") .. " " .. followerStr())
  followerAfterStep("4: puzzle 8 after the slides", "Right", "Left")
  if not startDoorOut("P8") then return end
  if not scrollDoor(7, "P8_again") then return end
  followerAfterStep("4: puzzle 8 re-entry", "Up")
  bads = trackedWalk("P8_again", { "Up", "Down" }, false)
  x, y = F.pos()
  F.check("4: puzzle 8 slides again after re-entry", x == 0 and y == 20 and #bads == 0,
    where() .. " " .. table.concat(bads, "; "))
  startDoorOut("P8_done")
  leaveToRoute110("P8")
end

------------------------------------------------------------------------------------------------
local function scenario6()
  F.L("== 6: Continue with the Trick Master hidden, and in the end room before the reward ==")
  setLevel(4)
  if not F.check("6: walked in from Route 110", enterFromRoute110("C6")) then return end
  F.check("6: Trick Master hiding (entrance state 0)", varGet(VAR_ENTRANCE) == 0, vars())
  if not saveResetContinue("6: entrance, Trick Master hiding") then return end
  if not findMaster(4, "C6") then return end
  if not scrollDoor(4, "C6") then return end
  if not F.check("6: end room", warpScript(GRP, MAP_END, 10, 2)) then return end
  F.step("Down"); settleMove()
  F.check("6: the Trick Master waits in the end room", objAt(4, 5) ~= nil)
  if not saveResetContinue("6: end room before the reward") then return end
  F.check("6: the Trick Master still waits after Continue", objAt(4, 5) ~= nil)
  F.shot("C6_endroom_continued")
  if not walk({ { 9, 3 }, { 4, 3 }, { 4, 4 } }, "C6_tomaster") then walk({ { 10, 6 }, { 4, 6 } }, "C6_tomaster2") end
  local _, y = F.pos()
  F.face(y == 4 and "Down" or "Up")
  local said = newSaid()
  F.press("A", 2); F.idle(20)
  local ok, detail = mashA("C6_reward", 12000, nil, said)
  F.L("  end room (after Continue) said: " .. said:all())
  F.check("6: reward after Continue: TM given, level 5 recorded", ok and said:has("Obtained") and varGet(VAR_LEVEL) == 5
    and varGet(VAR_PRIZE) == 0, detail .. " " .. vars())
  F.check("6: the Trick Master left", objAt(4, 5) == nil)
  if not saveResetContinue("6: end room after the reward") then return end
  F.check("6: the Trick Master stays gone after Continue", objAt(4, 5) == nil)
  F.check("6: the end room is walkable", walkable(), where())
end

------------------------------------------------------------------------------------------------
-- The gate before each next puzzle. A completed level leaves the entrance in state 5; entering
-- without the next gate's flag must park the Trick Master in front of the scroll (state 3) with his
-- "still devising" lines, and entering again with the flag must hide him for the next puzzle.
-- Puzzle 8 gates on FLAG_HOENN_CHAMPION here (upstream: FLAG_SYS_GAME_CLEAR, which another
-- region's Hall of Fame sets), so its closed case runs with FLAG_SYS_GAME_CLEAR set.
local FLAG_SYS_GAME_CLEAR = SYS + 4
local GATES = {
  { level = 1, flag = FLAG_BADGE[3], name = "badge 3", alsoSet = nil },
  { level = 7, flag = FLAG_HOENN_CHAMPION, name = "the Hoenn championship", alsoSet = FLAG_SYS_GAME_CLEAR },
}
local function scenario7()
  F.L("== 7: gates between puzzles ==")
  for _, g in ipairs(GATES) do
    local tag = "7 (level " .. g.level .. ")"
    setLevel(g.level); varSet(VAR_ENTRANCE, 5)
    flagSet(g.flag, false)
    if g.alsoSet then flagSet(g.alsoSet, true) end
    if not F.check(tag .. ": walked in from Route 110 without " .. g.name, enterFromRoute110(tag .. "_closed")) then return end
    F.check(tag .. ": the Trick Master waits at the scroll (entrance state 3)", varGet(VAR_ENTRANCE) == 3 and objAt(5, 2) ~= nil,
      vars())
    if F.check(tag .. ": walked up beside him", walk({ { 4, 5 }, { 4, 2 } }, tag .. "_tomaster"), where()) then
      F.face("Right")
      local said = newSaid()
      F.press("A", 2); F.idle(20)
      local ok, detail = mashA(tag .. "_talk", 6000, nil, said)
      F.L("  " .. tag .. " said: " .. said:all())
      F.check(tag .. ": he is still devising the next puzzle", ok and said:has("devising new tricky"), detail)
      F.check(tag .. ": nothing advanced", varGet(VAR_ENTRANCE) == 3 and varGet(VAR_LEVEL) == g.level, vars())
    end
    if not F.check(tag .. ": out to Route 110", leaveToRoute110(tag .. "_closed")) then return end
    flagSet(g.flag, true)
    if not F.check(tag .. ": walked in with " .. g.name, enterFromRoute110(tag .. "_open")) then return end
    F.check(tag .. ": the Trick Master is hiding again (entrance state 0)", varGet(VAR_ENTRANCE) == 0 and objAt(5, 2) == nil,
      vars())
    findMaster(g.level, tag .. "_open")
    if not F.check(tag .. ": out to Route 110 again", leaveToRoute110(tag .. "_open")) then return end
  end
end

------------------------------------------------------------------------------------------------
local function setup()
  if not F.boot(100) then return false end
  F.w16(F.sb2() + S.SaveBlock2.optionsU16, (F.r16(F.sb2() + S.SaveBlock2.optionsU16) & ~7) | TEXT_SPEED)
  addItem(ITEM_ESCAPE_ROPE, 3)
  F.check("setup: a Machop leads (Dig, Teleport, Rock Smash, Strength)",
    createMon(SPECIES_MACHOP, 50, { MOVE_DIG, MOVE_TELEPORT, MOVE_ROCK_SMASH, MOVE_STRENGTH }) == 1)
  for _, f in ipairs(FLAG_BADGE) do flagSet(f) end
  flagSet(FLAG_HOENN_CHAMPION)
  flagSet(FLAG_SYS_POKEMON_GET)
  varSet(VAR_REPEL_STEP_COUNT, 250)
  F.check("setup: three Escape Ropes", ropes() == 3, "ropes=" .. ropes())
  return true
end

local function run(n, fn)
  if ONLY and ONLY ~= tostring(n) then return end
  local ok, err = pcall(fn)
  if not ok then F.check(n .. ": ran without a Lua error", false, tostring(err)) end
  varSet(VAR_REPEL_STEP_COUNT, 250)
end

F.run(function()
  if not setup() then F.check("boot", false); F.finish(); return end
  F.L(string.format("seed %d text speed %d", SEED, TEXT_SPEED))
  run(2, scenario2)
  run(6, scenario6)
  run(5, scenario45)
  run(4, scenario4b)
  run(1, scenario1)
  run(7, scenario7)
  F.finish()
end)
