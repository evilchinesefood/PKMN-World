-- Mirage Island and Mirage Tower by odd paths, with the lead Pokemon following.
--
-- tower_escape: walk into Mirage Tower from Route 111, Dig out of 4F from the party menu and use an
--   Escape Rope out of 2F from the Bag. Each must land on (19,59) with control, the tower still drawn
--   (FLAG_MIRAGE_TOWER_VISIBLE and its walls in the live map grid) and the follower beside the
--   player after a step.
--   Then save on Route 111, soft reset, Continue, and walk back into the tower.
-- tower_floor: smash the 3F rock with the follower doing the move, fall through a 3F cracked floor
--   to 2F, save and Continue on each floor, then fall through a 2F cracked floor to 1F after the
--   Continue (the hole warp lives in EWRAM and is restored only by ON_RESUME).
-- island: VAR_MIRAGE_RND_H is set to the lead's personality low half (src/time_events.c), then the
--   player surfs from Route 129 across the connection, so ON_TRANSITION picks the layout. Land on the
--   island, walk to the berry tree, save, Continue. Deposit the matching Pokemon through the PC on
--   the island, save, Continue, then surf out to Route 129 and back: the island is gone and every
--   tile where it stood is surfable water.
-- fossil: full party, full boxes and a full Items pocket. Taking either fossil is refused and the
--   tower stays; with one slot free the collapse runs and lands the player on Route 111.
--
-- PW_MIRAGE_SEED seeds the A/B presses during transitions, PW_MIRAGE_TEXT sets the text speed and
-- PW_MIRAGE_FEMALE=1 plays as the female character. PW_MIRAGE_ONLY=<name> runs one scenario. Two extra scenarios measure a day change through --rtc:
--   island_save stops after the first save on the island, and nextday Continues that save:
--   mgba-run.sh MirageOddPaths.lua <rom> --env PW_MIRAGE_ONLY=island_save
--   mgba-run.sh MirageOddPaths.lua <rom> <case>/emulator/Verify1.sav --rtc 1704196800 --env PW_MIRAGE_ONLY=nextday
--
-- Run via test/overworld/mgba-run.sh test/overworld/lua/MirageOddPaths.lua <rom>

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "MirageOddPaths")

local HUB_GROUP = 100
local ROUTE111 = { g = 0, m = 26 }
local ROUTE129 = { g = 0, m = 44 }
local ROUTE130 = { g = 0, m = 45 }
local TOWER = { { g = 24, m = 94 }, { g = 24, m = 95 }, { g = 24, m = 96 }, { g = 24, m = 97 } }
local TOWER_DOORSTEP = { 19, 59 }

local VAR_REPEL_STEP_COUNT, VAR_MIRAGE_RND_H, VAR_MIRAGE_RND_L = 0x4021, 0x4024, 0x4025
local VAR_MIRAGE_TOWER_STATE = 0x40CB
local MIRAGE_RND_L = 0x1234
local FLAG_HIDE_BERRY_TREE = 0x11
local FLAG_FORCE_TOWER_VISIBLE, FLAG_TOWER_VISIBLE = 0x9D, 0x14E
local FLAG_CHOSE_ROOT, FLAG_CHOSE_CLAW = 0x14F, 0x150
local FLAG_HIDE_ROOT, FLAG_HIDE_CLAW = 0x3C3, 0x3C4
local FLAG_SYS_POKEMON_GET, FLAG_SYS_CLOCK_SET = 0x948, 0x97D
local TRAINER_FLAGS_START = 0x500
local SEA_TRAINERS = { 165, 168, 455, 378, 387, 580, 675, 676 }

local SPECIES_SWAMPERT, SPECIES_LAPRAS = 260, 131
local MOVE_SURF, MOVE_DIG, MOVE_ROCK_SMASH = 57, 91, 249
local ROW_DIG = 1
local ITEM_ESCAPE_ROPE, ITEM_ROOT_FOSSIL, ITEM_CLAW_FOSSIL = 120, 168, 169
local ITEM_SURF_TOOL, ITEM_ROCK_SMASH_TOOL = 876, 877
local FILLER_ITEM_FIRST = 28
local POCKET_ITEMS = 0
local USM_ICO_PARTY, USM_ICO_BAG, USM_ICO_SAVE = 1, 2, 7
local AVATAR_SURFING = 1 << 3
local OBJ_FOLLOWER = 0xFE
local CONTEXT_RUNNING, CONTEXT_SHUTDOWN = 0, 2
local PARTY_SIZE, TOTAL_BOXES, IN_BOX = 6, 14, 30
local PC_MENU_ROWS, PC_DEPOSIT = 5, 1
local SENTINEL = 0xFFFF
local SURFABLE = {}
for _, b in ipairs({ 16, 17, 18, 19, 20, 21, 25, 34, 42, 44, 45, 80, 81, 82, 83, 108, 109, 111 }) do SURFABLE[b] = true end

-- Mirage Island walk from the east beach to the tile below the berry tree (52,9).
local ISLAND_PATH = { { 41, 22 }, { 41, 17 }, { 40, 17 }, { 40, 16 }, { 39, 16 }, { 39, 10 }, { 40, 10 },
                      { 40, 9 }, { 51, 9 }, { 51, 10 }, { 52, 10 } }
local ISLAND_BACK = { { 51, 10 }, { 51, 9 }, { 40, 9 }, { 40, 10 }, { 39, 10 }, { 39, 16 }, { 40, 16 },
                      { 40, 17 }, { 41, 17 }, { 41, 22 }, { 57, 22 } }

local ONLY = os.getenv("PW_MIRAGE_ONLY")
local seed = tonumber(os.getenv("PW_MIRAGE_SEED") or "") or 0x5EED
local function rnd(n) seed = (seed * 1103515245 + 12345) % 2147483648; return (seed >> 8) % n end

-- ---- state -------------------------------------------------------------------------------------
local function flagGet(id) return (F.r8(F.sb1() + S.SaveBlock1.flags + (id // 8)) & (1 << (id % 8))) ~= 0 end
local function flagSet(id, on)
  local a, m = F.sb1() + S.SaveBlock1.flags + (id // 8), 1 << (id % 8)
  F.w8(a, on and (F.r8(a) | m) or (F.r8(a) & ~m & 0xFF))
end
local function varGet(id) return F.r16(F.sb1() + S.SaveBlock1.vars + (id - 0x4000) * 2) end
local function varSet(id, v) F.w16(F.sb1() + S.SaveBlock1.vars + (id - 0x4000) * 2, v) end
local function count() return F.r8(S.gPartiesCount) end
local function personality(slot) return F.r32(S.gParties + slot * S.Pokemon.size) end
local function surfing() return (F.r8(S.gPlayerAvatar) & AVATAR_SURFING) ~= 0 end
local function mapIs(t) return F.grp() == t.g and F.mapn() == t.m end
local function at(t, x, y) local px, py = F.pos(); return mapIs(t) and px == x and py == y end
local function where() local x, y = F.pos(); return string.format("%d/%d (%d,%d)", F.grp(), F.mapn(), x, y) end
local function escapeWarp()
  local a = F.sb1() + S.SaveBlock1.lastHealLocation + 8
  return string.format("%d/%d(%d,%d)", F.rs8(a), F.rs8(a + 1), F.rs16(a + 4), F.rs16(a + 6))
end
local function hasControl()
  return F.ow() and F.r8(S.sLockFieldControls) == 0 and F.r8(S.sGlobalScriptContextStatus) == CONTEXT_SHUTDOWN
end
local function awaitControl(budget)
  for i = 1, budget or 600 do
    if hasControl() then return true end
    if i % 30 == 0 then F.press("B", 2) else F.idle(1) end
  end
  return hasControl()
end

-- The island counts as present when any party Pokemon's personality low half equals RND_H.
local function partyMatches(key)
  for i = 0, count() - 1 do if personality(i) & 0xFFFF == key then return true end end
  return false
end

-- Live map grid cell: collision, elevation and behavior from the loaded layout's tilesets.
local function tile(x, y)
  local L = S.gBackupMapLayout
  local w = F.r32(L + S.BackupMapLayout.width)
  local v = F.r16(F.r32(L + S.BackupMapLayout.map) + 2 * ((x + 7) + (y + 7) * w))
  local mid = v & S.Metatiles.idMask
  local layout = F.r32(S.gMapHeader + S.MapHeader.mapLayout)
  local ts, idx = F.r32(layout + S.MapLayout.primaryTileset), mid
  if mid >= S.Metatiles.inPrimary then ts, idx = F.r32(layout + S.MapLayout.secondaryTileset), mid - S.Metatiles.inPrimary end
  local b = F.r16(F.r32(ts + S.Tileset.metatileAttributes) + idx * 2) & S.Metatiles.behaviorMask
  return { col = (v >> 10) & 3, elev = v >> 12, behavior = b, surfable = SURFABLE[b] == true }
end
local function tileText(t) return string.format("col=%d elev=%d mb=%d", t.col, t.elev, t.behavior) end
local function ground(x, y) local t = tile(x, y); return t.col == 0 and not t.surfable end

-- setmaplayoutindex updates gMapHeader.mapLayout and SaveBlock1.mapLayoutId but not
-- gMapHeader.mapLayoutId, so the swapped layouts are told apart by their cells.
local function islandShown() return ground(40, 24) and ground(52, 10) end
local function islandGoneGrid() return tile(40, 24).surfable and tile(52, 10).surfable end
local function towerDrawn() return tile(18, 57).col ~= 0 and tile(20, 57).col ~= 0 end
local function groundSig()
  local x0, y0 = F.pos()
  local L = S.gBackupMapLayout
  local w, map = F.r32(L + S.BackupMapLayout.width), F.r32(L + S.BackupMapLayout.map)
  local h = 0
  for y = y0 - 5, y0 + 5 do
    for x = x0 - 7, x0 + 7 do h = (h * 31 + F.r16(map + 2 * ((x + 7) + (y + 7) * w))) & 0xFFFFFFFF end
  end
  return h
end

local function obj(pred)
  for i = 0, 15 do
    local b = S.gObjectEvents + i * S.ObjectEvent.stride
    if (F.r8(b) & 1) == 1 then
      local o = { localId = F.r8(b + S.ObjectEvent.localId), x = F.rs16(b + S.ObjectEvent.x) - 7,
                  y = F.rs16(b + S.ObjectEvent.y) - 7, invisible = (F.r8(b + S.ObjectEvent.flags1) & 0x20) ~= 0 }
      if pred(o) then return o end
    end
  end
end
local function objAt(x, y) return obj(function(o) return o.x == x and o.y == y and o.localId < OBJ_FOLLOWER end) end
local function follower() return obj(function(o) return o.localId == OBJ_FOLLOWER end) end
local function followerText()
  local f = follower()
  return f and string.format("(%d,%d)%s", f.x, f.y, f.invisible and " hidden" or "") or "none"
end
local function followerBeside()
  local f, x, y = follower(), F.pos()
  return f ~= nil and not f.invisible and math.abs(f.x - x) + math.abs(f.y - y) == 1
end

-- ---- scripts and setup -------------------------------------------------------------------------
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
end
local function warpScript(t, x, y)
  local b = { 0x39, t.g, t.m, 0xFF }
  le16(b, x); le16(b, y); b[#b + 1] = 0x27; b[#b + 1] = 0x02
  awaitControl(300)
  runScript(b)
  for _ = 1, 400 do
    F.idle(4)
    if F.reportCrash("warp") then return false end
    if mapIs(t) and F.ow() then
      for _ = 1, 200 do if hasControl() then F.idle(20); return true end F.press("B", 2); F.idle(10) end
      return hasControl()
    end
  end
  F.L(string.format("  warp to %d.%d failed: at %s cb2=%08X", t.g, t.m, where(), F.cb2()))
  return false
end
local function createMon(species, level, moves)
  local b = { 0x23 }; le32(b, S.ScrCmd_createmon | 1)
  b[#b + 1] = 0; b[#b + 1] = PARTY_SIZE
  le16(b, species); le16(b, level)
  le32(b, (1 << 17) | (1 << 18) | (1 << 19) | (1 << 20))
  for k = 1, 4 do le16(b, moves[k] or 0) end
  b[#b + 1] = 0x02
  runScript(b); F.idle(20)
  return count()
end
local function addItem(id, qty) runScript({ 0x44, id & 0xFF, id >> 8, qty & 0xFF, qty >> 8, 0x02 }); F.idle(10) end

local function qtyKey() return F.r32(F.sb2() + S.SaveBlock2.encryptionKey) & 0xFFFF end
local function pocketPtr(p) return F.r32(S.gBagPockets + p * S.BagPocket.stride) end
local function setPocket(ids)
  local ptr = pocketPtr(POCKET_ITEMS)
  for s = 0, F.pocketCap(POCKET_ITEMS) - 1 do
    F.w16(ptr + s * 4, ids[s + 1] or 0)
    F.w16(ptr + s * 4 + 2, (ids[s + 1] and 1 or 0) ~ qtyKey())
  end
end
local function pocketFree()
  local ptr, n = pocketPtr(POCKET_ITEMS), 0
  for s = 0, F.pocketCap(POCKET_ITEMS) - 1 do if F.r16(ptr + s * 4) == 0 then n = n + 1 end end
  return n
end
local function pocketIds()
  local ptr, t = pocketPtr(POCKET_ITEMS), {}
  for s = 0, F.pocketCap(POCKET_ITEMS) - 1 do t[#t + 1] = F.r16(ptr + s * 4) end
  return table.concat(t, ",")
end

-- ---- player actions with real input ------------------------------------------------------------
local function walkable(tag)
  local x0, y0 = F.pos()
  for _, pair in ipairs({ { "Left", "Right" }, { "Right", "Left" }, { "Down", "Up" }, { "Up", "Down" } }) do
    local g, m = F.grp(), F.mapn()
    if F.step(pair[1]) then
      local moved = F.grp() == g and F.mapn() == m
      F.step(pair[2])
      local x, y = F.pos()
      if moved and x == x0 and y == y0 then return true end
    end
  end
  F.shot(tag .. "_stuck")
  return false
end
local function through(dir, dest, tag)
  for _ = 1, 6 do
    F.press(dir, 16)
    for _ = 1, 120 do
      if mapIs(dest) and hasControl() then F.idle(20); return true end
      F.idle(2)
    end
  end
  F.shot(tag .. "_nowarp")
  return false
end

local function menuMax() return F.rs8(S.sMenu + S.Menu.maxCursorPos) end
local function clearMenu() F.w8(S.sMenu + S.Menu.cursorPos, 0); F.w8(S.sMenu + S.Menu.maxCursorPos, 0) end

-- Talk to what the player faces and answer YES to the first Yes/No, paging text with A.
local function talkYes(tag)
  clearMenu()
  F.press("A", 2); F.idle(20)
  for _ = 1, 80 do
    if menuMax() == 1 then
      if F.mcur() ~= 0 then F.press("Up", 2); F.idle(8) end
      F.shot(tag .. "_yesno")
      F.press("A", 2); F.idle(30)
      return true
    end
    if hasControl() then return false end
    F.press("A", 2); F.idle(20)
  end
  return false
end

local function surfFrom(dir, tag)
  for _ = 1, 4 do
    awaitControl(300)
    F.face(dir)
    if talkYes(tag) then
      for _ = 1, 60 do
        if surfing() and hasControl() then F.idle(20); return true end
        F.press("B", 2); F.idle(20)
      end
    end
  end
  F.shot(tag .. "_nosurf")
  return surfing()
end

-- F.step holds the key 14 frames past the coordinate change, which carries a surfing player one
-- tile further; release on the change and wait for the tile to finish instead.
local function stepOne(dir)
  local x0, y0 = F.pos()
  local g0, m0 = F.grp(), F.mapn()
  for _ = 1, 40 do
    joypad.set({ [dir] = true }); emu.frameadvance()
    local x, y = F.pos()
    if x ~= x0 or y ~= y0 or F.grp() ~= g0 or F.mapn() ~= m0 then
      for _ = 1, 60 do
        joypad.set({}); emu.frameadvance()
        if F.r8(S.gPlayerAvatar + S.PlayerAvatar.tileTransitionState) == 0 then break end
      end
      F.idle(6)
      return true
    end
  end
  F.idle(4)
  return false
end

-- Surf one tile at a time until `done()`; every tile must be surfable water and the avatar surfing.
local function surfLine(dir, done, maxSteps, tag)
  local land, blocked = 0, 0
  for _ = 1, maxSteps do
    if done() then break end
    if not stepOne(dir) then blocked = blocked + 1; if blocked > 2 then break end
    else
      local x, y = F.pos()
      local t = tile(x, y)
      if not surfing() or not t.surfable then
        land = land + 1
        F.L(string.format("    %s: off water at %s %s surfing=%s", tag, where(), tileText(t), tostring(surfing())))
      end
    end
    if F.reportCrash(tag) then break end
  end
  return done(), land, blocked
end

local function driveSave()
  awaitControl(300)
  F.w16(S.gSaveAttemptStatus, SENTINEL)
  F.press("Start", 2); F.idle(60)
  if not F.selectStartIcon(USM_ICO_SAVE) then return "noicon" end
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

local function snapshot()
  local x, y = F.pos()
  return { g = F.grp(), m = F.mapn(), x = x, y = y, ground = groundSig(), n = count() }
end
local function fmt(s) return string.format("%d/%d (%d,%d) ground=%08X party=%d", s.g, s.m, s.x, s.y, s.ground, s.n) end

-- Save from the Start menu, soft reset, Continue; checks the map, tile, layout and control.
local function saveAndContinue(tag)
  local before = snapshot()
  F.check(tag .. ": saved from the Start menu", driveSave() == "done")
  softReset(); F.idle(60)
  local booted = F.boot(nil, true)
  F.check(tag .. ": Continue reaches the field", booted)
  if not booted then return false end
  F.idle(30)
  if F.reportCrash(tag) then F.check(tag .. ": no crash after Continue", false); return false end
  local after = snapshot()
  F.L("  before " .. fmt(before))
  F.L("  after  " .. fmt(after))
  F.check(tag .. ": same map, tile and ground after Continue", after.g == before.g and after.m == before.m
    and after.x == before.x and after.y == before.y and after.ground == before.ground, fmt(after))
  F.check(tag .. ": control returns after Continue", awaitControl(600))
  F.shot(tag .. "_continued")
  return true
end

local function inBag() return F.cb2() == (S.CB2_BagMenuRun & ~1) end
local function inPartyMenu()
  local c = F.cb2()
  return c == S.CB2_UpdatePartyMenu or c == S.CB2_InitPartyMenu or c == S.CB2_PartyMenuFromStartMenu
end
-- Seeded A/B presses while a transition holds the field, until `done()` with control. No D-pad, so
-- the mash cannot walk the player onto another cracked floor or back through a warp.
local function mashUntil(done, frames, tag)
  local f = 0
  while f < frames do
    if F.reportCrash(tag) then return false end
    if done() and hasControl() then return true end
    if hasControl() then F.idle(2); f = f + 2
    else
      F.press(rnd(2) == 0 and "A" or "B", 2)
      local w = 2 + rnd(14)
      F.idle(w); f = f + 2 + w
    end
  end
  return false
end

local function settle(from, tag)
  mashUntil(function() return not mapIs(from) end, 1200, tag)
  local ok = awaitControl(600)
  F.idle(40)
  F.shot(tag .. "_landed")
  return ok
end
local function escapeRope(tag)
  local from = { g = F.grp(), m = F.mapn() }
  setPocket({ ITEM_ESCAPE_ROPE })
  F.w16(pocketPtr(POCKET_ITEMS) + 2, 5 ~ qtyKey())
  F.w8(S.gBagPosition + 5, POCKET_ITEMS)
  F.w16(S.gBagPosition + 8 + POCKET_ITEMS * 2, 0)
  F.w16(S.gBagPosition + 18 + POCKET_ITEMS * 2, 0)
  awaitControl(300)
  F.press("Start", 2); F.idle(60)
  if not F.selectStartIcon(USM_ICO_BAG) then return false end
  F.press("A", 2)
  for _ = 1, 150 do if inBag() then break end; F.idle(2) end
  F.idle(40)
  F.press("A", 2); F.idle(40)
  F.press("A", 2); F.idle(90)
  return settle(from, tag)
end
local function dig(tag)
  local from = { g = F.grp(), m = F.mapn() }
  awaitControl(300)
  F.press("Start", 2); F.idle(60)
  if not F.selectStartIcon(USM_ICO_PARTY) then return false end
  F.press("A", 3)
  for _ = 1, 240 do F.idle(4); if inPartyMenu() then break end end
  F.idle(40)
  F.press("A", 3); F.idle(50)
  for _ = 1, ROW_DIG do F.press("Down", 2); F.idle(12) end
  F.shot(tag .. "_actions")
  F.press("A", 3); F.idle(60)
  for _ = 1, 20 do
    if not inPartyMenu() then break end
    F.press("Up", 2); F.idle(6); F.press("A", 2); F.idle(30)
  end
  return settle(from, tag)
end

local function drain(tries)
  for i = 1, tries or 40 do
    F.press("B", 3); F.idle(20)
    if i % 5 == 0 and hasControl() then return true end
  end
  return hasControl()
end
local function pcMenuLive() return F.ow() and menuMax() == PC_MENU_ROWS - 1 end
local function openPC()
  clearMenu()
  F.dbg(); F.idle(60)
  F.press("Down", 3); F.idle(16); F.press("A", 3); F.idle(60)
  F.press("A", 3); F.idle(60)
  for _ = 1, 200 do
    if pcMenuLive() then F.idle(30); return true end
    F.press("A", 2); F.idle(18)
  end
  return false
end
local function deposit(slot, tag)
  if not openPC() then F.shot(tag .. "_nopc"); return false end
  for _ = 1, 8 do
    if F.mcur() == PC_DEPOSIT then break end
    F.press(F.mcur() < PC_DEPOSIT and "Down" or "Up", 2); F.idle(12)
  end
  F.press("A", 2); F.idle(150)
  for _ = 1, slot do F.press("Down", 2); F.idle(16) end
  F.press("A", 2); F.idle(40)
  F.shot(tag .. "_menu")
  F.press("A", 2); F.idle(60)
  F.press("A", 2); F.idle(90)
  F.shot(tag .. "_done")
  for _ = 1, 4 do F.press("B", 2); F.idle(60); if F.ow() then break end end
  F.idle(60)
  for _ = 1, 6 do
    if F.ow() and not pcMenuLive() then break end
    F.press("B", 2); F.idle(60)
  end
  return drain(20)
end

local function case(tag, body)
  F.L("== " .. tag .. " ==")
  local ok, err = pcall(body)
  if not ok then F.check(tag .. ": ran without a Lua error", false, tostring(err)) end
end

local function landedOnDoorstep(tag)
  local x, y = F.pos()
  F.L(string.format("  %s: landed %s escape=%s follower=%s", tag, where(), escapeWarp(), followerText()))
  F.check(tag .. ": lands on Route 111 (19,59)", at(ROUTE111, TOWER_DOORSTEP[1], TOWER_DOORSTEP[2]), where())
  F.check(tag .. ": the tower is still drawn", towerDrawn() and flagGet(FLAG_TOWER_VISIBLE),
    string.format("walls=%s visible=%s", tostring(towerDrawn()), tostring(flagGet(FLAG_TOWER_VISIBLE))))
  F.check(tag .. ": the landing tile is open ground", tile(x, y).col == 0 and not tile(x, y).surfable, tileText(tile(x, y)))
  F.check(tag .. ": control and a walkable landing", hasControl() and walkable(tag))
  F.check(tag .. ": the player walks off the doorstep", F.step("Down"), where())
  F.idle(30)
  F.check(tag .. ": the follower is beside the player after a step", followerBeside(),
    "follower " .. followerText() .. " player " .. where())
  F.step("Up")
end

-- ---- scenarios ---------------------------------------------------------------------------------
local function towerEscape()
  flagSet(FLAG_FORCE_TOWER_VISIBLE, true)
  varSet(VAR_MIRAGE_TOWER_STATE, 0)
  local ok = warpScript(ROUTE111, 19, 60) and F.step("Up") and through("Up", TOWER[1], "tower_in")
  F.check("tower: walked into Mirage Tower 1F from Route 111", ok, where())
  if not ok then return end
  F.check("tower: the escape point is the doorstep", escapeWarp() == "0/26(19,59)", escapeWarp())

  ok = warpScript(TOWER[4], 4, 5) and F.step("Right")
  F.check("tower dig: reached 4F with a follower", ok and follower() ~= nil, where() .. " follower " .. followerText())
  if ok then
    F.check("tower dig: the party menu returned to the field", dig("dig_4f"), where())
    landedOnDoorstep("tower dig")
  end

  ok = through("Up", TOWER[1], "tower_in2") and warpScript(TOWER[2], 16, 3) and F.step("Down")
  F.check("tower rope: walked in again and reached 2F", ok, where())
  if ok then
    F.check("tower rope: the Bag returned to the field", escapeRope("rope_2f"), where())
    landedOnDoorstep("tower rope")
  end

  if saveAndContinue("tower route111") then
    F.check("tower route111: the tower is still drawn after Continue",
      towerDrawn() and flagGet(FLAG_TOWER_VISIBLE))
    F.check("tower route111: walkable after Continue", walkable("route111_continue"))
    F.check("tower route111: the tower can be entered again", through("Up", TOWER[1], "tower_reenter"), where())
    F.shot("tower_reentered")
  end
end

local function towerFloor()
  flagSet(FLAG_FORCE_TOWER_VISIBLE, true)
  local ok = warpScript(TOWER[3], 4, 11) and F.step("Up") and F.step("Up")
  F.check("rock: stands below the 3F rock with the follower out", ok and at(TOWER[3], 4, 9) and objAt(4, 8) ~= nil,
    where() .. " follower " .. followerText())
  if ok then
    F.face("Up")
    F.check("rock: the smash prompt took YES", talkYes("rock"))
    awaitControl(900)
    local x, y = F.pos()
    F.L(string.format("  rock: after the smash player %s follower %s", where(), followerText()))
    F.shot("rock_smashed")
    F.check("rock: the rock is gone", objAt(4, 8) == nil)
    F.check("rock: control returns on a legal tile", hasControl() and mapIs(TOWER[3]) and tile(x, y).col == 0,
      where() .. " " .. tileText(tile(x, y)))
    F.check("rock: walkable after the smash", walkable("rock"))
    if saveAndContinue("rock 3F") then
      F.check("rock 3F: the rock stays gone after Continue", objAt(4, 8) == nil)
      F.check("rock 3F: walkable after Continue", walkable("rock_continue"))
      F.check("rock 3F: the smashed tile can be walked onto", F.route({ { 4, 9 }, { 4, 8 } }, "rock_path"), where())
    end
    ok = warpScript(TOWER[2], 16, 3) and warpScript(TOWER[3], 4, 11)
    F.check("rock: re-entered 3F", ok, where())
    if ok then F.check("rock: the smashed rock stays gone on re-entry", objAt(4, 8) == nil and objAt(3, 7) ~= nil) end
  end

  ok = warpScript(TOWER[3], 17, 10) and F.route({ { 17, 7 } }, "crack3f")
  F.check("fall: stands below the 3F cracked floor (17,6)", ok, where())
  if ok then
    F.step("Up")
    mashUntil(function() return mapIs(TOWER[2]) end, 1200, "fall3f")
    awaitControl(600)
    local x, y = F.pos()
    F.shot("fall_2f")
    F.L(string.format("  fall: landed %s follower %s", where(), followerText()))
    F.check("fall: lands on 2F (17,6)", at(TOWER[2], 17, 6), where())
    F.check("fall: control on a legal tile", hasControl() and tile(x, y).col == 0, tileText(tile(x, y)))
    F.check("fall: walkable after the fall", walkable("fall"))
    F.step("Down"); F.idle(30)
    F.check("fall: the follower is beside the player after a step", followerBeside(), "follower " .. followerText())
    F.step("Up")
    if saveAndContinue("fall 2F") then
      F.check("fall 2F: walkable after Continue", walkable("fall_continue"))
      ok = F.route({ { 17, 4 }, { 16, 4 }, { 16, 3 }, { 4, 3 }, { 4, 4 } }, "crack2f")
      F.check("fall 2F: walked to the 2F cracked floor", ok, where())
      if ok then
        F.step("Left")
        mashUntil(function() return mapIs(TOWER[1]) end, 1200, "fall2f")
        awaitControl(600)
        F.shot("fall_1f")
        F.check("fall 2F: the cracked floor still drops to 1F (3,4) after Continue", at(TOWER[1], 3, 4), where())
        F.check("fall 2F: walkable on 1F", hasControl() and walkable("fall_1f"))
      end
    end
  end
end

-- Arrive on Route 129 water; the map load runs DoTimeBasedEvents, so VAR_DAYS is current before the
-- island key is written and the crossing cannot step the key.
local function islandArrive()
  flagSet(FLAG_SYS_CLOCK_SET, true)
  varSet(VAR_REPEL_STEP_COUNT, 250)
  local ok = warpScript(ROUTE129, 3, 22)
  F.check("island: arrives surfing on Route 129", ok and surfing(), where())
  if not ok then return nil end
  local key = personality(0) & 0xFFFF
  varSet(VAR_MIRAGE_RND_H, key)
  varSet(VAR_MIRAGE_RND_L, MIRAGE_RND_L)
  F.L(string.format("  island: key=%04X lead personality=%08X follower=%s", key, personality(0), followerText()))
  local crossed, land = surfLine("Left", function() return at(ROUTE130, 58, 22) end, 90, "cross_in")
  F.check("island: surfed across the connection to Route 130 (58,22)", crossed and land == 0, where())
  if not crossed then return nil end
  F.check("island: the key did not step on the crossing", varGet(VAR_MIRAGE_RND_H) == key,
    string.format("%04X", varGet(VAR_MIRAGE_RND_H)))
  F.check("island: ON_TRANSITION loaded the Mirage Island layout", islandShown())
  F.check("island: berry tree flag clear", not flagGet(FLAG_HIDE_BERRY_TREE))
  F.shot("island_offshore")
  stepOne("Left"); F.idle(40)
  awaitControl(300)
  local x, y = F.pos()
  F.check("island: landed on the beach (57,22) on foot", at(ROUTE130, 57, 22) and not surfing(),
    where() .. " " .. tileText(tile(x, y)))
  local ok2 = F.route(ISLAND_PATH, "island_walk")
  F.check("island: walked to the berry tree", ok2 and at(ROUTE130, 52, 10), where())
  F.face("Up")
  local tree = objAt(52, 9)
  F.check("island: the berry tree object is shown", tree ~= nil and not tree.invisible)
  F.check("island: the follower walks beside the player", followerBeside(), "follower " .. followerText())
  F.shot("island_berry_tree")
  return key
end

local function islandBeach()
  varSet(VAR_REPEL_STEP_COUNT, 250)
  F.check("island: back on the east beach", F.route(ISLAND_BACK, "island_back") and at(ROUTE130, 57, 22), where())
  F.check("island: surfed off the beach", surfFrom("Right", "surf_off"), where())
end

-- Leave for Route 129 and come back: the island must be gone and its whole beach row surfable.
local function islandGone(tag)
  local out = surfLine("Right", function() return mapIs(ROUTE129) end, 40, tag .. "_out")
  F.check(tag .. ": surfed out to Route 129", out and stepOne("Right"), where())
  local back = surfLine("Left", function() return mapIs(ROUTE130) end, 10, tag .. "_back")
  F.check(tag .. ": surfed back into Route 130", back, where())
  F.check(tag .. ": the plain Route 130 layout is loaded", islandGoneGrid())
  F.check(tag .. ": berry tree flag set", flagGet(FLAG_HIDE_BERRY_TREE))
  local _, land, blocked = surfLine("Left", function() return at(ROUTE130, 24, 22) end, 70, tag .. "_over")
  F.check(tag .. ": surfed across where the island stood without touching land", at(ROUTE130, 24, 22) and land == 0
    and blocked == 0, string.format("%s land=%d blocked=%d", where(), land, blocked))
  F.shot(tag .. "_island_gone")
end

local function island()
  local key = islandArrive()
  if not key then return end
  if not saveAndContinue("island save") then return end
  F.check("island save: berry tree shown after Continue", objAt(52, 9) ~= nil and not flagGet(FLAG_HIDE_BERRY_TREE))
  F.check("island save: walkable after Continue", walkable("island_continue"))
  if ONLY == "island_save" then return end

  F.check("island pc: deposited the matching lead", deposit(0, "island_deposit") and count() == 1, "party=" .. count())
  F.check("island pc: no party Pokemon matches the key now", not partyMatches(key))
  F.check("island pc: the island stays until the next map load", islandShown())
  F.check("island pc: walkable after the PC", walkable("island_pc"))
  if saveAndContinue("island pc") then
    F.check("island pc: Continue keeps the saved island layout (vanilla)", islandShown())
    local x, y = F.pos()
    F.check("island pc: the player stands on island ground", tile(x, y).col == 0 and not tile(x, y).surfable, tileText(tile(x, y)))
    F.check("island pc: walkable after Continue", walkable("island_pc_continue"))
  end
  islandBeach()
  islandGone("island pc")
end

local function nextDay()
  if not F.boot(nil, true) then F.check("nextday: Continue reaches the field", false); return end
  awaitControl(600)
  local key = personality(0) & 0xFFFF
  local stepped = ((1103515245 * ((key << 16) | MIRAGE_RND_L) + 12345) & 0xFFFFFFFF)
  local x, y = F.pos()
  F.L(string.format("  nextday: %s key=%04X rnd=%04X%04X expect=%08X days=%d island=%s", where(), key,
    varGet(VAR_MIRAGE_RND_H), varGet(VAR_MIRAGE_RND_L), stepped, varGet(0x4040), tostring(islandShown())))
  F.shot("nextday_continued")
  F.check("nextday: Continue lands on the island tile", at(ROUTE130, 52, 10), where())
  F.check("nextday: the day change stepped the key once",
    varGet(VAR_MIRAGE_RND_H) == stepped >> 16 and varGet(VAR_MIRAGE_RND_L) == stepped & 0xFFFF)
  F.check("nextday: no party Pokemon matches the stepped key", not partyMatches(varGet(VAR_MIRAGE_RND_H)))
  F.check("nextday: Continue keeps the saved island layout (vanilla)", islandShown())
  F.check("nextday: the player stands on island ground", tile(x, y).col == 0 and not tile(x, y).surfable, tileText(tile(x, y)))
  F.check("nextday: control and walkable", awaitControl(600) and walkable("nextday"))
  islandBeach()
  islandGone("nextday")
end

local function boxCount()
  local base, n = F.r32(S.gPokemonStoragePtr) + 4, 0
  for i = 0, TOTAL_BOXES * IN_BOX - 1 do
    if (F.r8(base + i * S.BoxPokemon.size + 19) & 2) ~= 0 then n = n + 1 end
  end
  return n
end

local function fossilRefused(name, x, item, hideFlag)
  local ok = warpScript(TOWER[4], x, 5)
  F.check("fossil " .. name .. ": stands under the fossil", ok, where())
  if not ok then return end
  local pocket = pocketIds()
  F.face("Up")
  F.check("fossil " .. name .. ": the take prompt took YES", talkYes("fossil_" .. name))
  F.idle(60)
  F.shot("fossil_" .. name .. "_refused")
  F.check("fossil " .. name .. ": control returns on 4F", awaitControl(900) and mapIs(TOWER[4]), where())
  F.check("fossil " .. name .. ": not in the bag", F.itemCount(item) == 0)
  F.check("fossil " .. name .. ": the Items pocket is unchanged", pocketIds() == pocket)
  F.check("fossil " .. name .. ": the tower did not collapse", varGet(VAR_MIRAGE_TOWER_STATE) == 0
    and not flagGet(FLAG_CHOSE_ROOT) and not flagGet(FLAG_CHOSE_CLAW), "state=" .. varGet(VAR_MIRAGE_TOWER_STATE))
  local root, claw = objAt(5, 4), objAt(7, 4)
  F.check("fossil " .. name .. ": both fossils stay", root ~= nil and claw ~= nil and not root.invisible
    and not claw.invisible and not flagGet(hideFlag) and not flagGet(FLAG_HIDE_ROOT) and not flagGet(FLAG_HIDE_CLAW))
end

local function fossil()
  flagSet(FLAG_FORCE_TOWER_VISIBLE, true)
  varSet(VAR_MIRAGE_TOWER_STATE, 0)
  while count() < PARTY_SIZE do createMon(SPECIES_LAPRAS, 30, { MOVE_SURF }) end
  F.dbg(); F.sel(1); F.sel(1); F.sel(0); drain(20)
  local ids = {}
  for s = 1, F.pocketCap(POCKET_ITEMS) do ids[s] = FILLER_ITEM_FIRST + s - 1 end
  setPocket(ids)
  F.check("fossil: full party, full boxes, full Items pocket", count() == PARTY_SIZE and boxCount() == TOTAL_BOXES * IN_BOX
    and pocketFree() == 0, string.format("party=%d boxes=%d cap=%d free=%d", count(), boxCount(), F.pocketCap(POCKET_ITEMS), pocketFree()))
  fossilRefused("root", 5, ITEM_ROOT_FOSSIL, FLAG_HIDE_ROOT)
  fossilRefused("claw", 7, ITEM_CLAW_FOSSIL, FLAG_HIDE_CLAW)

  ids[#ids] = nil
  setPocket(ids)
  local ok = warpScript(TOWER[4], 5, 5)
  F.face("Up")
  F.check("fossil room: the take prompt took YES", ok and talkYes("fossil_room"))
  local landed = false
  for i = 1, 1200 do
    if F.reportCrash("collapse") then break end
    if mapIs(ROUTE111) and hasControl() and varGet(VAR_MIRAGE_TOWER_STATE) >= 2 then landed = true; break end
    if i % 3 == 0 then F.press("B", 2) end
    F.idle(8)
  end
  F.shot("fossil_room_landed")
  F.check("fossil room: the collapse lands the player on Route 111 (19,59) with control",
    landed and at(ROUTE111, 19, 59), where() .. " state=" .. varGet(VAR_MIRAGE_TOWER_STATE))
  F.check("fossil room: the Root Fossil is in the bag", F.itemCount(ITEM_ROOT_FOSSIL) == 1)
  F.check("fossil room: walkable after the collapse", walkable("collapse"))
  local back = warpScript({ g = 2, m = 2 }, 7, 4) and warpScript(ROUTE111, 19, 60)
  F.check("fossil room: Route 111 re-entered without the tower", back and not towerDrawn()
    and not flagGet(FLAG_TOWER_VISIBLE) and varGet(VAR_MIRAGE_TOWER_STATE) == 3,
    string.format("%s walls=%s state=%d", where(), tostring(towerDrawn()), varGet(VAR_MIRAGE_TOWER_STATE)))
  F.shot("fossil_room_tower_gone")
end

F.run(function()
  F.L(string.format("seed=0x%X only=%s", seed, tostring(ONLY)))
  if ONLY == "nextday" then nextDay(); F.finish(); return end
  if not F.boot(HUB_GROUP) then F.check("boot to the hub", false); F.finish(); return end
  local textSpeed = tonumber(os.getenv("PW_MIRAGE_TEXT") or "") or 3
  F.w16(F.sb2() + S.SaveBlock2.optionsU16, (F.r16(F.sb2() + S.SaveBlock2.optionsU16) & ~7) | textSpeed)
  if os.getenv("PW_MIRAGE_FEMALE") == "1" then F.w8(F.sb2() + S.SaveBlock2.playerGender, 1) end
  F.w8(F.sb2() + S.SaveBlock2.introDoneBits, 7)
  flagSet(FLAG_SYS_POKEMON_GET, true)
  for _, id in ipairs(SEA_TRAINERS) do flagSet(TRAINER_FLAGS_START + id, true) end
  createMon(SPECIES_SWAMPERT, 70, { MOVE_DIG, MOVE_SURF, MOVE_ROCK_SMASH })
  createMon(SPECIES_LAPRAS, 70, { MOVE_SURF })
  addItem(ITEM_SURF_TOOL, 1); addItem(ITEM_ROCK_SMASH_TOOL, 1)
  varSet(VAR_REPEL_STEP_COUNT, 250)
  awaitControl(300)
  F.check("setup: Swampert leads a party of two", count() == 2, "party=" .. count())

  local scenarios = {
    { name = "tower_escape", run = towerEscape },
    { name = "tower_floor", run = towerFloor },
    { name = "island", run = island },
    { name = "island_save", run = island, optIn = true },
    { name = "fossil", run = fossil },
  }
  for _, sc in ipairs(scenarios) do
    if ONLY == sc.name or (ONLY == nil and not sc.optIn) then case(sc.name, sc.run) end
  end
  F.finish()
end)
