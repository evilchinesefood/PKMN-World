-- The Sevii Trainer Tower lobby, which is closed: every object and event played with real input.
--
-- The tower's FRLG challenge and records are compiled out (5ac8745870 deleted those paths from
-- src/trainer_tower.c), but the lobby's time board still ran ShowTrainerHillRecords with
-- VAR_0x8004 = 1, whose Trainer Tower branch prints nothing: reading the board faded to an empty
-- records frame. The suite walks in from Seven Island through the door with a fainted lead and 0
-- money, then reads the time board, steps on the entry trigger (the receptionist refuses and
-- walks the player back), has the nurse heal the party across her counter, opens the clerk's
-- mart and tries to buy with 0 money, and walks out of the door. Each scene is mashed with its
-- own seeded source (A, B, Start, L, R and the D-pad; never Select; A alone at the nurse, whose
-- Yes/No keeps its default). Checks: no crash, control returns, the board opens no blank records
-- screen, the trigger leaves the player below it, the nurse heals, the mart takes nothing, the
-- floors above stay sealed, the door returns to Seven Island. Control: Route 111's Trainer Hill
-- board still opens and prints its TIME BOARD.
--
-- PW_TOWER_BASE=<n> reseeds the mash.
-- Run: test/overworld/mgba-run.sh test/overworld/lua/TrainerTowerLobby.lua

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "TrainerTowerLobby")

local BASE = tonumber(os.getenv("PW_TOWER_BASE") or "") or 0x7070
local MON = S.Pokemon.size
local CONTEXT_RUNNING, CONTEXT_SHUTDOWN = 0, 2
local LOBBY = { 36, 10 }
local OUTSIDE = { 37, 58 }
local HILL = { 26, 60 }

local seed = BASE
local function rnd()
  seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF
  return seed >> 8
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
end
local function createMon(species, level)
  local b = { 0x23 }; le32(b, S.ScrCmd_createmon | 1)
  b[#b + 1] = 0; b[#b + 1] = 6
  le16(b, species); le16(b, level)
  le32(b, 0)
  b[#b + 1] = 0x02
  runScript(b); F.idle(20)
end

local function instantText()
  local a = F.sb2() + S.SaveBlock2.optionsU16
  F.w16(a, (F.r16(a) & ~7) | 3)
end
local function scriptIdle() return F.r8(S.sGlobalScriptContextStatus) == CONTEXT_SHUTDOWN end
local function hasControl() return F.ow() and F.r8(S.sLockFieldControls) == 0 and scriptIdle() end
local function settle()
  for _ = 1, 400 do if hasControl() then return true end F.press("B", 2); F.idle(10) end
  return hasControl()
end
local function setMoney(v) F.w32(F.sb1() + S.SaveBlock1.money, v ~ F.r32(F.sb2() + S.SaveBlock2.encryptionKey)) end

local function warpScript(g, n, x, y)
  local b = { 0x39, g, n, 0xFF }
  le16(b, x); le16(b, y); b[#b + 1] = 0x27; b[#b + 1] = 0x02
  runScript(b)
  for _ = 1, 400 do
    F.idle(4)
    if F.reportCrash("warp") then return false end
    if F.grp() == g and F.mapn() == n and F.ow() then return true end
  end
  return false
end

local DIRS = { "Up", "Down", "Left", "Right" }
local function seedFor(tag)
  local h = BASE & 0x7FFFFFFF
  for i = 1, #tag do h = ((h ~ tag:byte(i)) * 16777619) & 0x7FFFFFFF end
  return h
end

-- A seeded mash of A, B, Start, L, R and the D-pad; aOnly mashes A alone, so a Yes/No prompt
-- keeps its default answer.
local function mash(frames, until_, aOnly)
  for i = 1, frames do
    if i % 10 == 0 and F.reportCrash("mash") then return false end
    if until_ and i > 30 and until_() then break end
    local t = {}
    for b, p in pairs(aOnly and { A = 30 } or { A = 25, B = 30, Start = 6, L = 6, R = 6 }) do
      if rnd() % 100 < p then t[b] = true end
    end
    if t.R and t.Start then t.R = nil end
    if not aOnly and rnd() % 100 < 25 then t[DIRS[rnd() % 4 + 1]] = true end
    joypad.set(t)
    emu.frameadvance()
  end
  joypad.set({})
  return true
end

local function inLobby() return F.grp() == LOBBY[1] and F.mapn() == LOBBY[2] end
local function hp(i) return F.r16(S.gParties + i * MON + S.Pokemon.hp) end
local function maxHp(i) return F.r16(S.gParties + i * MON + S.Pokemon.maxHP) end

-- Window 0's ink after the records screen has faded in: the count of non-zero pixels in its tiles.
local function windowInk()
  local w = S.gWindows
  local width, height, data = F.r8(w + S.Window.width), F.r8(w + S.Window.height), F.r32(w + S.Window.tileData)
  if data < 0x02000000 or data >= 0x02040000 or width == 0 then return -1 end
  local ink = 0
  for off = 0, width * height * 32 - 1 do
    local b = F.r8(data + off)
    if b & 0xF ~= 0 then ink = ink + 1 end
    if b >> 4 ~= 0 then ink = ink + 1 end
  end
  return ink
end

-- Read a records board from the tile below it: A, wait for the screen, measure, close.
local function readBoard(tag)
  seed = seedFor(tag)
  F.face("Up")
  F.press("A", 2)
  local opened = false
  for _ = 1, 200 do
    F.idle(2)
    if not F.ow() then opened = true; break end
  end
  F.idle(150)
  local ink = windowInk()
  F.shot(tag .. "_records")
  F.L(string.format("  %s: records window ink %d", tag, ink))
  local ok = mash(1500, function() return hasControl() end)
  F.check(tag .. ": no crash", ok)
  F.check(tag .. ": control returns", settle())
  return opened, ink
end

-- Face a target, press A once, then mash until the scene hands control back.
local function interact(tag, dir, frames, aOnly)
  seed = seedFor(tag)
  F.face(dir)
  F.press("A", 2); F.idle(10)
  local started = not scriptIdle() or not F.ow()
  F.shot(tag .. "_open")
  local ok = mash(frames or 1500, function() return hasControl() end, aOnly)
  F.check(tag .. ": no crash", ok)
  F.check(tag .. ": control returns", settle())
  return started
end

F.run(function()
  if not F.boot(100) then F.finish(); return end
  instantText()
  createMon(66, 30)
  createMon(129, 10)
  F.w16(S.gParties + S.Pokemon.hp, 0)
  setMoney(0)
  F.check("setup: two Pokemon, the lead fainted, 0 money", F.r8(S.gPartiesCount) == 2 and hp(0) == 0 and F.money() == 0)

  F.check("warp: Seven Island below the tower door", warpScript(OUTSIDE[1], OUTSIDE[2], 58, 8))
  settle(); instantText()
  F.step("Up")
  for _ = 1, 200 do if inLobby() and F.ow() then break end F.idle(4) end
  F.check("the door leads into the lobby", inLobby(), string.format("at %d.%d", F.grp(), F.mapn()))
  F.check("control in the lobby", settle())
  local x0, y0 = F.pos()
  F.L(string.format("  arrived at (%d,%d)", x0, y0))

  F.check("walk to the time board", F.route({ { 9, 11 }, { 8, 11 } }, "board"))
  local opened, ink = readBoard("board")
  F.check("board: reading it opens no blank records screen", not opened or ink > 0,
    string.format("opened=%s ink=%d", tostring(opened), ink))

  F.check("walk below the entry trigger", F.route({ { 9, 11 }, { 9, 8 } }, "trigger"))
  F.step("Up")
  seed = seedFor("trigger")
  mash(900, function() return hasControl() end)
  F.check("trigger: control returns", settle())
  local tx, ty = F.pos()
  F.check("trigger: the receptionist sends the player back below the counter", tx == 9 and ty == 8,
    string.format("at (%d,%d)", tx, ty))

  F.check("walk below the nurse's counter", F.route({ { 9, 11 }, { 4, 11 } }, "nurse"))
  interact("nurse", "Up", 2500, true)
  F.check("nurse: the party is healed", hp(0) == maxHp(0) and hp(1) == maxHp(1),
    string.format("hp %d/%d %d/%d", hp(0), maxHp(0), hp(1), maxHp(1)))

  F.check("walk below the clerk's counter", F.route({ { 14, 11 } }, "clerk"))
  interact("clerk", "Up", 2500)
  F.check("mart: 0 money buys nothing", F.money() == 0, "money=" .. F.money())

  F.check("lobby: the floors stay sealed", inLobby())
  F.check("walk to the door", F.route({ { 9, 11 }, { 9, 15 } }, "exit"))
  for _ = 1, 20 do joypad.set({ Down = true }); emu.frameadvance() end
  joypad.set({})
  for _ = 1, 200 do if F.grp() == OUTSIDE[1] and F.mapn() == OUTSIDE[2] and F.ow() then break end F.idle(4) end
  F.check("the door returns to Seven Island", F.grp() == OUTSIDE[1] and F.mapn() == OUTSIDE[2],
    string.format("at %d.%d", F.grp(), F.mapn()))
  F.check("control outside", settle())

  F.check("warp: below the Trainer Hill records board (control)", warpScript(HILL[1], HILL[2], 8, 11))
  settle(); instantText()
  local hillOpened, hillInk = readBoard("hill_board")
  F.check("hill board: the records screen opens and prints", hillOpened and hillInk > 0, "ink=" .. hillInk)
  F.check("no crash", not F.reportCrash("end"))
  F.finish()
end)
