-- Shared driver for PikeChallengeStress.lua and PikeFollowerChoice.lua: Battle Pike challenges played
-- with real input from the lobby attendant to the end, room by room. See PikeChallengeStress.lua for
-- what each case asserts.

return function(suiteName, CASES)
local S = require("symbols")
local F = require("lib").new(S, suiteName)

local FRONTIER, LOBBY, THREE, NORMAL, WILD = 26, 34, 36, 37, 39
local STATUS = S.SaveBlock2.frontierChallengeStatus
local BP = S.SaveBlock2.bp
local FOLLOWER_SLOT = S.SaveBlock2.followerSlot
-- SaveBlock2.frontier fields, from an offsetof probe built with the repo's flags (calibrated on
-- money 1168, bp 3768, arenaWinStreaks 0xDDA).
local PIKE_STREAK, PIKE_RECORD, PIKE_TOTAL, STREAK_ACTIVE, BATTLE_NUM = 0xE04, 0xE08, 0xE0C, 0xCDC, 0xCB2
local STREAK_PIKE_50 = 1 << 10
local FLAG_SYS_PIKE_SILVER = 0x9B6
local FOLLOWER = 0xFE
local ROOMS = { [0] = "single", "heal_full", "npc", "status", "heal_part", "wild", "hard", "double", "queen" }
local HEAL_PART = 4
local TRACE = os.getenv("PW_PIKE_TRACE") ~= nil

local SPECIES = { 6, 9, 3, 25, 94, 143 }
local MOVES = { { 53, 89 }, { 57, 58 }, { 202, 89 }, { 85, 98 }, { 247, 85 }, { 34, 89 } }
local ITEMS = { 472, 462, 473 } -- Leftovers, Quick Claw, Shell Bell on the three that enter

-- Walls of the three Pike layouts (data/layouts). "b" marks the entry row, whose coord events turn
-- the player back once the room is entered: it is walkable only while the player is still on it.
local GRID = {
  [THREE] = { "#############", "#############", "#############", "##.###.###.##", "#...#...#...#",
              ".............", ".............", ".............", ".............", ".............",
              "bbb#bbbb#bbbb" },
  [NORMAL] = { "#########", "#########", "#########", "####.####", "..#...#..", ".........", ".........",
               "bb#bbb#bb" },
  [WILD] = { "#########", "#########", "#########", "##.#.#.##", "..#...#..", ".........", "###...###",
             ".........", "########.", ".........", ".########", ".........", "#######.#", ".........",
             "#.#######", ".........", "#######.#", ".........", "##.....##", "bb#bbb#bb" },
}
local DOORS = { { 2, 3 }, { 6, 3 }, { 10, 3 } }

local SCRIPT_BUF = S.gStringVar4 + 960
local function le16(t, v) t[#t + 1] = v & 0xFF; t[#t + 1] = (v >> 8) & 0xFF end
local function le32(t, v) le16(t, v & 0xFFFF); le16(t, (v >> 16) & 0xFFFF) end
local function giveMon(species, moves)
  local b = { 0x23 }; le32(b, S.ScrCmd_createmon | 1)
  b[#b + 1] = 0; b[#b + 1] = 6
  le16(b, species); le16(b, 50)
  le32(b, (1 << 17) | (1 << 18) | (1 << 19) | (1 << 20))
  for i = 1, 4 do le16(b, moves[i] or 0) end
  b[#b + 1] = 0x02
  for i, v in ipairs(b) do F.w8(SCRIPT_BUF + i - 1, v) end
  F.w8(S.sGlobalScriptContext, 0)
  F.w8(S.sGlobalScriptContext + 1, 1)
  F.w32(S.sGlobalScriptContext + 4, 0)
  F.w32(S.sGlobalScriptContext + S.ScriptCtx.scriptPtr, SCRIPT_BUF)
  F.w8(S.sGlobalScriptContextStatus, 0)
  F.idle(20)
end

local function party(slot) return S.gParties + slot * S.Pokemon.size end
local function setHeldItem(a, item)
  local pers = F.r32(a)
  local key = pers ~ F.r32(a + 4)
  local w = {}
  for i = 0, 11 do w[i] = F.r32(a + 32 + i * 4) ~ key end
  local s0 = F.r8(S.sSubstructOffsets + pers % 24) * 3
  w[s0] = (w[s0] & ~(0x3FF << 16)) | (item << 16)
  local sum = 0
  for i = 0, 11 do
    local v = w[i] & 0xFFFFFFFF
    sum = sum + (v & 0xFFFF) + (v >> 16)
    F.w32(a + 32 + i * 4, v ~ key)
  end
  F.w16(a + 28, sum & 0xFFFF)
end

local function partyBytes()
  local t = {}
  for i = 0, F.r8(S.gPartiesCount) * S.Pokemon.size - 1 do t[#t + 1] = F.r8(S.gParties + i) end
  return F.r8(S.gPartiesCount) .. ":" .. table.concat(t, ",")
end
local function personalities()
  local t = {}
  for i = 0, F.r8(S.gPartiesCount) - 1 do t[#t + 1] = string.format("%08X", F.r32(party(i))) end
  return table.concat(t, " ")
end
local function where() local x, y = F.pos(); return string.format("%d/%d (%d,%d)", F.grp(), F.mapn(), x, y) end
local function sb2u16(off) return F.r16(F.sb2() + off) end
local function flag(id) return (F.r8(F.sb1() + S.SaveBlock1.flags + (id >> 3)) & (1 << (id & 7))) ~= 0 end

local function cb(addr) return F.cb2() == (addr & ~1) end
local function inPartyMenu() return cb(S.CB2_UpdatePartyMenu) or cb(S.CB2_InitPartyMenu) end
local function inBattle() return cb(S.BattleMainCB2) end
local function atTitle() return cb(S.MainCB2_WorldTitleScreen) or cb(S.MainCB2_Intro) end

local function liveMenu()
  for i = 0, S.Task.count - 1 do
    local task = S.gTasks + i * S.Task.stride
    local fn = F.r32(task + S.Task.func) & 0xFFFFFFFE
    if F.r8(task + S.Task.isActive) ~= 0 then
      if fn == S.Task_HandleYesNoInput or fn == S.Task_CallYesOrNoCallback then return "yesno" end
      if fn == S.Task_HandleMultichoiceInput then return "multi" end
    end
  end
end
local function choose(want)
  for _ = 1, 8 do
    local c = F.mcur()
    if c == want then F.press("A", 2); F.idle(45); return true end
    F.press(c > want and "Up" or "Down", 2); F.idle(12)
  end
  return false
end
local function menu(want, tag)
  for _ = 1, 80 do
    if F.reportCrash("menu_" .. tag) then return false end
    if liveMenu() then F.idle(12); return choose(want) end
    F.press("A", 2); F.idle(30)
  end
  F.L("  " .. tag .. ": no menu went live"); F.shot(tag .. "_nomenu")
  return false
end

-- The frontier party screen, steered by gPartyMenu.slotId: A on a member opens Enter/Summary/Cancel
-- with Enter first.
local function pickSlots(slots)
  for _ = 1, 300 do
    if inPartyMenu() then break end
    F.press("A", 2); F.idle(20)
  end
  if not inPartyMenu() then return false end
  F.idle(60)
  for _, s in ipairs(slots) do
    for _ = 1, 12 do
      local cur = F.r8(S.gPartyMenu + 9)
      if cur == s - 1 then break end
      F.press(cur < s - 1 and "Down" or "Up", 2); F.idle(16)
    end
    F.press("A", 2); F.idle(30)
    F.press("A", 2); F.idle(40)
  end
  F.press("Start", 2); F.idle(40)
  for _ = 1, 8 do
    if not inPartyMenu() then break end
    F.press("A", 2); F.idle(60)
  end
  return not inPartyMenu()
end

local function steerBattle(f)
  for b = 1, 3, 2 do
    local a = S.gBattleMons + b * S.BattlePokemon.size
    if F.r16(a + S.BattlePokemon.hp) > 1 then F.w16(a + S.BattlePokemon.hp, 1) end
  end
  for b = 0, 2, 2 do
    local a = S.gBattleMons + b * S.BattlePokemon.size
    local mx = F.r16(a + S.BattlePokemon.maxHP)
    if F.r16(a + S.BattlePokemon.hp) > 0 and mx > 0 then F.w16(a + S.BattlePokemon.hp, mx) end
  end
  if f % 20 ~= 0 then F.idle(1); return end
  if (F.r32(S.gBattlerControllerFuncs) & ~1) == (S.HandleInputChooseMove & ~1) then
    local slot = (f // 20) % 4
    F.press("Up", 2); F.idle(4); F.press("Left", 2); F.idle(4)
    if slot % 2 == 1 then F.press("Right", 2); F.idle(4) end
    if slot >= 2 then F.press("Down", 2); F.idle(4) end
  end
  F.press("A", 2)
end

local function follower()
  for i = 0, 15 do
    local a = S.gObjectEvents + i * S.ObjectEvent.stride
    if (F.r8(a) & 1) ~= 0 and F.r8(a + S.ObjectEvent.localId) == FOLLOWER then
      return { gfx = F.r16(a + S.ObjectEvent.graphicsId), visible = (F.r8(a + 1) & 0x20) == 0 }
    end
  end
end

-- A wild battle started from the grass leaves the script context WAITING with the player free, so
-- "not RUNNING" is the control test, not SHUTDOWN.
local function free()
  return F.ow() and F.r8(S.sGlobalScriptContextStatus) ~= 0 and F.r8(S.sLockFieldControls) == 0
    and F.r8(S.gPlayerAvatar + S.PlayerAvatar.tileTransitionState) == 0 and not liveMenu()
end
local function settled()
  for _ = 1, 10 do
    if not free() then return false end
    F.idle(1)
  end
  return true
end

-- Tiles held by visible map objects (not the player, not the follower, which swaps places).
local function blockers()
  local t = {}
  for i = 0, 15 do
    local a = S.gObjectEvents + i * S.ObjectEvent.stride
    local id = F.r8(a + S.ObjectEvent.localId)
    if (F.r8(a) & 1) ~= 0 and (F.r8(a + 1) & 0x20) == 0 and id ~= FOLLOWER and id ~= 0xFF then
      t[(F.r16(a + 0x10) - 7) .. "," .. (F.r16(a + 0x12) - 7)] = true
    end
  end
  return t
end

-- First step of a shortest walk to (tx, ty), or nil.
local function nextDir(grid, tx, ty)
  local x0, y0 = F.pos()
  local block = blockers()
  local function open(x, y)
    local row = grid[y + 1]
    if not row or x < 0 or x >= #row then return false end
    local cell = row:sub(x + 1, x + 1)
    if cell == "#" or (cell == "b" and y ~= y0) then return false end
    return not block[x .. "," .. y] or (x == tx and y == ty)
  end
  local seen, q = { [x0 .. "," .. y0] = "start" }, { { x0, y0 } }
  local steps = { { 0, -1, "Up" }, { -1, 0, "Left" }, { 1, 0, "Right" }, { 0, 1, "Down" } }
  local head = 1
  while head <= #q do
    local x, y = q[head][1], q[head][2]; head = head + 1
    if x == tx and y == ty then
      local k = x .. "," .. y
      while seen[k] ~= "start" do
        local p = seen[k]
        if p.from == x0 .. "," .. y0 then return p.dir end
        k = p.from
      end
      return nil
    end
    for _, d in ipairs(steps) do
      local nx, ny = x + d[1], y + d[2]
      local k = nx .. "," .. ny
      if not seen[k] and open(nx, ny) then
        seen[k] = { from = x .. "," .. y, dir = d[3] }
        q[#q + 1] = { nx, ny }
      end
    end
  end
  return nil
end

-- One planned step toward (tx, ty); true once there.
local function walkTo(grid, tx, ty)
  local x, y = F.pos()
  if x == tx and y == ty then return true end
  local dir = nextDir(grid, tx, ty)
  if dir then F.step(dir) else F.idle(20) end
  return false
end

local function runCase(c, base, seed)
  local tag = c.name
  client.loadstate(base); F.idle(10)
  if c.follow then F.w8(F.sb2() + FOLLOWER_SLOT, c.follow) end
  if c.streak then
    F.w16(F.sb2() + PIKE_STREAK, c.streak)
    F.w16(F.sb2() + PIKE_RECORD, c.streak)
    F.w16(F.sb2() + PIKE_TOTAL, c.streak // 14)
    F.w32(F.sb2() + STREAK_ACTIVE, F.r32(F.sb2() + STREAK_ACTIVE) | STREAK_PIKE_50)
  end
  assert(F.warpTo(0, 2, 6, 0, 3, 4, 0, 0, 0, FRONTIER, LOBBY, tag), "lobby warp failed")
  F.idle(60)
  local party0 = partyBytes()
  local follower0 = follower()
  local bp0 = F.r16(F.sb2() + BP)
  local lv = c.open and 1 or 0
  local streak0, record0, total0 = sb2u16(PIKE_STREAK + 2 * lv), sb2u16(PIKE_RECORD + 2 * lv), sb2u16(PIKE_TOTAL + 2 * lv)
  F.L(string.format("  %s: followerSlot=%d follower=%s streak=%d record=%d total=%d bp=%d", tag,
    F.r8(F.sb2() + FOLLOWER_SLOT), follower0 and string.format("%04X", follower0.gfx) or "none", streak0, record0, total0, bp0))

  if not F.check(tag .. ": walked to the lobby attendant", F.route({ { 5, 7 }, { 5, 6 } }, tag), where()) then return end
  F.face("Up"); F.press("A", 2); F.idle(30)
  local took = menu(0, tag .. "_challenge") and menu(lv, tag .. "_level")
  took = took and pickSlots(c.picks or { 1, 2, 3 })
  took = took and menu(0, tag .. "_save")
  if not F.check(tag .. ": took the challenge", took) then return end

  local rng = seed
  local function roll() rng = (rng * 1103515245 + 12345) % 2147483648; return rng end
  local doors, rooms, pauseDone, resumed, ended = 0, {}, false, false, false
  local answers = {}
  local lastMap, talked, door, inB, battles, wilds, lastNum = -1, false, nil, false, 0, 0, -1
  local resumeParty = nil
  for f = 1, 160000 do
    if F.reportCrash(tag .. "_" .. f) then break end
    if TRACE and f % 2000 == 0 then
      F.L(string.format("    trace f=%d %s cb2=%08X ctx=%d lock=%d tts=%d menu=%s", f, where(), F.cb2(),
        F.r8(S.sGlobalScriptContextStatus), F.r8(S.sLockFieldControls),
        F.r8(S.gPlayerAvatar + S.PlayerAvatar.tileTransitionState), tostring(liveMenu() or "none")))
      if f % 10000 == 0 then F.shot(tag .. "_trace") end
    end
    local m = F.mapn()
    if F.ow() and m ~= lastMap then
      local num = F.r16(F.sb2() + BATTLE_NUM)
      if (m == NORMAL or m == WILD) and num ~= lastNum then
        doors, lastNum = doors + 1, num
        local rt = F.r8(S.sRoomType)
        rooms[#rooms + 1] = ROOMS[rt] or tostring(rt)
        F.L(string.format("  %s: room %d (battle num %d) %s at frame %d", tag, doors, num, rooms[#rooms], f))
      end
      lastMap, talked, door = m, false, nil
    end
    if inBattle() then
      if not inB then
        inB, battles = true, battles + 1
        if F.mapn() == WILD then wilds = wilds + 1 end
      end
      steerBattle(f)
    elseif atTitle() then
      F.shot(tag .. "_title")
      local booted = F.boot(nil, true)
      local status = F.r8(F.sb2() + STATUS)
      resumeParty = F.r8(S.gPartiesCount)
      F.L(string.format("  %s: continued at %s status=%d party=%d", tag, where(), status, resumeParty))
      resumed = booted and F.grp() == FRONTIER and F.mapn() == THREE
      lastMap = F.mapn()
    else
      if inB and F.ow() then inB = false end
      local k = liveMenu()
      if k then
        F.idle(20)
        choose(table.remove(answers, 1) or 0)
      elseif F.grp() == FRONTIER and (m == THREE or m == NORMAL or m == WILD) and settled() then
        if m == THREE then
          if c.resetAfter and doors == c.resetAfter and not pauseDone then
            pauseDone = true
            F.shot(tag .. "_reset")
            for _ = 1, 10 do joypad.set({ A = true, B = true, Start = true, Select = true }); emu.frameadvance() end
            F.idle(30)
          elseif c.pauseAfter and doors == c.pauseAfter and not pauseDone then
            if walkTo(GRID[THREE], 4, 9) then
              F.face("Down"); F.shot(tag .. "_attendant")
              answers = { 1, 0 } -- "Continue?" NO, then "Save and quit?" YES
              pauseDone = true
              F.press("A", 2); F.idle(30)
            end
          else
            door = door or DOORS[roll() % 3 + 1]
            walkTo(GRID[THREE], door[1], door[2])
          end
        elseif m == NORMAL and F.r8(S.sRoomType) == HEAL_PART and not talked then
          if walkTo(GRID[NORMAL], 4, 5) then
            F.face("Up"); F.press("A", 2); F.idle(30); talked = true
          end
        else
          walkTo(GRID[m], 4, 3)
        end
      elseif f % 30 == 0 then
        F.press("A", 2)
      else
        F.idle(1)
      end
      if doors >= 1 and F.grp() == FRONTIER and m == LOBBY and F.r8(F.sb2() + STATUS) == 0 and free() then
        F.idle(240)
        if free() then ended = true; break end
      end
    end
  end
  F.shot(tag .. "_end")
  F.L(string.format("  %s: rooms %s; battles %d (wild %d); emulator frame %d", tag, table.concat(rooms, ","), battles,
    wilds, emu.framecount()))

  local lvSuffix = 2 * lv
  local streak, record, total = sb2u16(PIKE_STREAK + lvSuffix), sb2u16(PIKE_RECORD + lvSuffix), sb2u16(PIKE_TOTAL + lvSuffix)
  local bp = F.r16(F.sb2() + BP)
  F.check(tag .. ": back in the lobby with control", ended and F.grp() == FRONTIER and F.mapn() == LOBBY, where())
  F.check(tag .. ": the party is byte-identical to the one that walked in", partyBytes() == party0,
    "now " .. personalities())
  F.check(tag .. ": frontier status cleared", F.r8(F.sb2() + STATUS) == 0, "status=" .. F.r8(F.sb2() + STATUS))
  if c.resetAfter then
    -- The last save is the lobby's, so Continue lands there and the attendant ends the challenge
    -- as unsaved.
    F.check(tag .. ": the reset came after the rooms it waited for", pauseDone and doors == c.resetAfter, "doors=" .. doors)
    F.check(tag .. ": Continue landed in the lobby", resumeParty == 6, "party=" .. tostring(resumeParty))
    F.check(tag .. ": the unsaved challenge ended the streak", streak == 0, string.format("%d -> %d", streak0, streak))
    F.check(tag .. ": the record and the total are unchanged", record == record0 and total == total0,
      string.format("record %d -> %d, total %d -> %d", record0, record, total0, total))
    F.check(tag .. ": no Battle Points for the unsaved challenge", bp == bp0, string.format("%d -> %d", bp0, bp))
  else
    F.check(tag .. ": seven rooms were played", doors == 7, "doors=" .. doors)
    F.check(tag .. ": the streak counts the fourteen rooms", streak == streak0 + 14, string.format("%d -> %d", streak0, streak))
    F.check(tag .. ": the record holds the streak", record == math.max(record0, streak), string.format("%d -> %d", record0, record))
    F.check(tag .. ": one more completed challenge", total == total0 + 1, string.format("%d -> %d", total0, total))
    local award = c.streak and 11 or 1
    F.check(tag .. ": the Battle Point award was added", bp - bp0 == award, string.format("%d -> %d (want +%d)", bp0, bp, award))
  end
  if c.streak then
    F.check(tag .. ": the last room was the Pike Queen's", rooms[#rooms] == "queen", tostring(rooms[#rooms]))
    F.check(tag .. ": the Pike Queen gave the silver symbol", flag(FLAG_SYS_PIKE_SILVER))
  end
  if c.pauseAfter then
    F.check(tag .. ": Continue resumed the challenge in the three-path room", resumed, "party=" .. tostring(resumeParty))
    F.check(tag .. ": the paused save kept all six Pokemon", resumeParty == 6, "party=" .. tostring(resumeParty))
  end
  F.step("Down"); F.idle(20); F.step("Down"); F.idle(60)
  local fol = follower()
  F.check(tag .. ": the chosen follower walks behind the player again", fol ~= nil and fol.visible and follower0 ~= nil
    and fol.gfx == follower0.gfx, fol and string.format("gfx=%04X visible=%s want=%04X", fol.gfx, tostring(fol.visible),
      follower0 and follower0.gfx or 0) or "none")
  if c.follow then
    local slot = F.r8(F.sb2() + FOLLOWER_SLOT)
    F.check(tag .. ": the follower choice names the same party slot", slot == c.follow, "followerSlot=" .. slot)
  end
end

F.run(function()
  assert(F.boot(100), "Fresh game did not boot")
  for i, sp in ipairs(SPECIES) do giveMon(sp, MOVES[i]) end
  F.check("six Pokemon in the party", F.r8(S.gPartiesCount) == 6, "n=" .. F.r8(S.gPartiesCount))
  for i, item in ipairs(ITEMS) do setHeldItem(party(i - 1), item) end
  setHeldItem(party(3), 522) -- Lum Berry on the Pikachu that pause_resume enters first
  local base = F.out .. suiteName .. "_base.ss"
  client.savestate(base)
  local only = os.getenv("PW_CASE")
  local seed = tonumber(os.getenv("PW_PIKE_SEED") or "") or 20261119
  F.L("  door seed " .. seed)
  for _, c in ipairs(CASES) do
    if not only or c.name:find(only, 1, true) then runCase(c, base, seed) end
  end
  F.check("no crash screen", not F.crashScreen())
  F.finish()
end)
end
