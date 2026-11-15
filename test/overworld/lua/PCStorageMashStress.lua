-- PC storage under input mashing: no Pokemon or held item may be lost or copied.
--
-- Setup gives four Bulbasaur through the debug menu (two hold a Potion), fills every box with
-- debug Fill PC Boxes Fast, empties part of BOX1 and BOX2 so Pokemon can move, puts a Potion on
-- five boxed Pokemon and adds Potions to the Bag. Each session then opens the PC (debug Access PC),
-- picks Move Pokemon, Deposit, Withdraw or Move Items in turn and mashes seeded random input on
-- every frame (A, B, the D-pad, L/R box paging, Select cursor modes, Start) through moves, shifts,
-- multi-select moves, item takes and gives, releases and their animations, box menus and screen
-- changes, then leaves the PC. On the field after each session the suite counts every Pokemon in
-- the party and the boxes by personality and every Potion held or in the Bag. Releases are the only
-- way a Pokemon may leave (each one is counted as it happens), a released Pokemon's Potion must
-- reach the Bag, and nothing may appear that was not there before. In the summary screen the
-- mash skips L, R and Select (the move relearner and the debug sprite visualizer live there).
--
-- Run via test/overworld/mgba-run.sh test/overworld/lua/PCStorageMashStress.lua <rom.gba>
-- --env PW_SEED=<n> picks another input sequence; --env PW_SESSIONS=<n> the session count.

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "PCStorageMashStress")

local PARTY_SIZE, MON = 6, S.Pokemon.size
local BOXES, PER_BOX, BOX_MON = 14, 30, S.BoxPokemon.size
local BULBASAUR = 1
local ITEM_POTION = 28
local PC_MENU_ROWS = 5
local RELEASE_DONE_STATE = 4   -- Task_ReleaseMon's state right after ReleaseMon() ran
local SEED = tonumber(os.getenv and os.getenv("PW_SEED") or "") or 4242
local SESSIONS = tonumber(os.getenv and os.getenv("PW_SESSIONS") or "") or 16
local MASH_FRAMES = 3000

local function party(slot) return S.gParties + slot * MON end
local function boxSlot(box, slot) return F.r32(S.gPokemonStoragePtr) + 4 + (box * PER_BOX + slot) * BOX_MON end

local function order(p)
  local o = {}
  for i = 0, 3 do o[i] = F.r8(S.sSubstructOffsets + i * 24 + p % 24) * 3 end
  return o
end
local function words(a)
  local key = F.r32(a) ~ F.r32(a + 4)
  local w = {}
  for i = 0, 11 do w[i] = F.r32(a + 32 + i * 4) ~ key end
  return w, order(F.r32(a))
end
local function writeWords(a, w)
  local key = F.r32(a) ~ F.r32(a + 4)
  local sum = 0
  for i = 0, 11 do
    sum = (sum + (w[i] & 0xFFFF) + (w[i] >> 16)) & 0xFFFF
    F.w32(a + 32 + i * 4, w[i] ~ key)
  end
  F.w16(a + 28, sum)
end
local function heldItem(a) local w, o = words(a); return (w[o[0]] >> 16) & 0x3FF end
local function setHeldItem(a, item)
  local w, o = words(a)
  w[o[0]] = (w[o[0]] & ~(0x3FF << 16)) | (item << 16)
  writeWords(a, w)
end
local function checksumOk(a)
  local w = words(a)
  local sum = 0
  for i = 0, 11 do sum = sum + (w[i] & 0xFFFF) + (w[i] >> 16) end
  return (sum & 0xFFFF) == F.r16(a + 28)
end
local function occupied(a) return F.r32(a) ~= 0 or F.r32(a + 4) ~= 0 end

local function instantText()
  local a = F.sb2() + S.SaveBlock2.optionsU16
  F.w16(a, (F.r16(a) & ~7) | 3)
end

local function digits(n) n = n - 1; return n // 100, (n // 10) % 10, n % 10 end
local function giveParty(n, species, level)
  for _ = 1, 3 do
    for off = 0, PARTY_SIZE * MON - 4, 4 do F.w32(S.gParties + off, 0) end
    F.w8(S.gPartiesCount, 0)
    F.dbg(); F.idle(30); F.bOut(4)
    for _ = 1, n do
      F.dbg(); F.sel(3); F.sel(1); F.idle(20)
      F.spin(digits(species)); F.idle(20)
      F.spin(digits(level)); F.idle(60); F.bOut(4)
    end
    local ok = F.r8(S.gPartiesCount) == n
    for i = 0, n - 1 do ok = ok and checksumOk(party(i)) end
    if ok then return true end
    F.idle(60)
  end
  return false
end

local function tapDown(n) for _ = 1, n do F.press("Down", 3); F.idle(16) end end
local function drain(tries)
  for i = 1, tries or 40 do
    F.press("B", 3); F.idle(20)
    if i % 5 == 0 and F.ensureFree() then return true end
  end
  return F.ensureFree()
end
local function debugAction(path)
  F.dbg(); F.idle(60)
  for i, row in ipairs(path) do
    tapDown(row); F.press("A", 3); F.idle(i == #path and 240 or 60)
  end
  return drain(20)
end

local SCRIPT_BUF = S.gStringVar4 + 960
local function runScript(b)
  for i, v in ipairs(b) do F.w8(SCRIPT_BUF + i - 1, v) end
  F.w8(S.sGlobalScriptContext, 0)
  F.w8(S.sGlobalScriptContext + 1, 1)
  F.w32(S.sGlobalScriptContext + 4, 0)
  F.w32(S.sGlobalScriptContext + S.ScriptCtx.scriptPtr, SCRIPT_BUF)
  F.w8(S.sGlobalScriptContextStatus, 0)
end

local function menuMax() return F.rs8(S.sMenu + S.Menu.maxCursorPos) end
local function pcMenuLive() return F.ow() and menuMax() == PC_MENU_ROWS - 1 end
local function cursorTo(row)
  for _ = 1, 8 do
    if F.mcur() == row then return true end
    F.press(F.mcur() < row and "Down" or "Up", 2); F.idle(12)
  end
  return F.mcur() == row
end
local function openPcMenu()
  F.w8(S.sMenu + 2, 0); F.w8(S.sMenu + S.Menu.maxCursorPos, 0)
  F.dbg(); F.idle(60)
  F.press("Down", 3); F.idle(16); F.press("A", 3); F.idle(60)
  F.press("A", 3); F.idle(60)
  for _ = 1, 200 do
    if pcMenuLive() then return true end
    F.press("A", 2); F.idle(18)
  end
  return pcMenuLive()
end

-- The storage screen's current task, read through sStorage->taskId.
local function storageTask()
  local st = F.r32(S.sStorage)
  if st < 0x02000000 or st >= 0x02040000 then return nil, nil end
  local id = F.r8(st + 4)
  if id >= S.Task.count then return nil, nil end
  local t = S.gTasks + id * S.Task.stride
  if F.r8(t + S.Task.isActive) == 0 then return nil, nil end
  return F.r32(t + S.Task.func) & ~1, F.r8(st)
end

local function census()
  local c = { total = 0, pids = {}, potions = 0, where = {} }
  local function add(a, tag)
    if occupied(a) then
      c.total = c.total + 1
      local p = F.r32(a)
      c.pids[p] = (c.pids[p] or 0) + 1
      c.where[p] = tag
      if checksumOk(a) and heldItem(a) == ITEM_POTION then c.potions = c.potions + 1 end
    end
  end
  for i = 0, PARTY_SIZE - 1 do add(party(i), "party " .. i) end
  for b = 0, BOXES - 1 do for s = 0, PER_BOX - 1 do add(boxSlot(b, s), string.format("box %d/%d", b, s)) end end
  local ptr = F.r32(S.gBagPockets + S.BagPocket.itemsPtr)
  local key = F.r32(F.sb2() + S.SaveBlock2.encryptionKey) & 0xFFFF
  for s = 0, F.pocketCap(0) - 1 do
    if F.r16(ptr + s * 4) == ITEM_POTION then c.potions = c.potions + (F.r16(ptr + s * 4 + 2) ~ key) end
  end
  return c
end

local function holding() return F.r8(S.sIsMonBeingMoved) ~= 0 end
local function area() return F.r8(S.sCursorArea) end
local function cursor() return F.r8(S.sCursorPosition) end

-- Put a held Pokemon down with B on an empty party slot, or, with the party full, on an empty
-- slot of the first box that has one (paged to with R).
local function putDown()
  local empty
  for i = 0, PARTY_SIZE - 1 do if F.r32(party(i)) == 0 then empty = i; break end end
  if empty then
    for _ = 1, 30 do
      if area() == 1 and cursor() == empty then break end
      if area() == 2 then F.press("Down", 2) elseif area() ~= 1 then F.press("Left", 2)
      else F.press(cursor() < empty and "Down" or "Up", 2) end
      F.idle(14)
    end
  else
    local box, slot
    for b = 0, BOXES - 1 do
      for s = 0, PER_BOX - 1 do if not occupied(boxSlot(b, s)) then box, slot = b, s; break end end
      if box then break end
    end
    if not box then return false end
    if area() == 1 then F.press("Right", 2); F.idle(14) end
    for _ = 1, 20 do
      if F.r8(F.r32(S.gPokemonStoragePtr)) == box then break end
      F.press("R", 2); F.idle(40)
    end
    for _ = 1, 30 do
      if area() == 0 and cursor() == slot then break end
      if area() ~= 0 then F.press("Down", 2)
      else
        local r, c, tr, tc = cursor() // 6, cursor() % 6, slot // 6, slot % 6
        F.press(r ~= tr and (r < tr and "Down" or "Up") or (c < tc and "Right" or "Left"), 2)
      end
      F.idle(14)
    end
  end
  F.press("B", 2); F.idle(40)
  return not holding()
end

-- Leave the PC whatever it is showing, steering by the storage screen's current task: close a
-- menu, put a held Pokemon down, bag a held item, answer No to "Continue Box operations?", and
-- back out of any other screen (B, or START then A for a naming screen).
local function leavePc()
  local T = function(name) return S[name] & ~1 end
  for i = 1, 200 do
    if F.ow() and not pcMenuLive() and F.r8(S.sGlobalScriptContextStatus) == 2 then return true end
    local fn = storageTask()
    if pcMenuLive() or F.ow() then
      F.press("B", 2); F.idle(30)
    elseif fn == T("Task_OnSelectedMon") then
      F.press("B", 2); F.idle(20)
    elseif fn == T("Task_PokeStorageMain") then
      if holding() then putDown() else F.press("B", 2); F.idle(30) end
    elseif fn == T("Task_CloseBoxWhileHoldingItem") then
      F.press("A", 2); F.idle(40)
    elseif fn == T("Task_OnBPressed") then
      F.press("Down", 2); F.idle(12); F.press("A", 2); F.idle(40)
    elseif fn == nil and i % 3 == 0 then
      F.press("Start", 2); F.idle(20); F.press("A", 2); F.idle(30)   -- a naming screen: OK
    elseif fn == nil and i % 3 == 1 then
      F.press("B", 2); F.idle(30); F.press("A", 2); F.idle(30)       -- B, then Yes to "give up?"
    else
      F.press("B", 2); F.idle(30)
    end
  end
  return F.ow() and F.r8(S.sGlobalScriptContextStatus) == 2
end

local KEYS = { "A", "A", "A", "B", "Up", "Down", "Left", "Right", "Left", "Right", "L", "R", "Select", "Start" }

F.run(function()
  if not F.boot(100) then F.check("boot to the hub", false); F.finish(); return end
  instantText()
  F.check("setup: the debug Give made four Bulbasaur", giveParty(4, BULBASAUR, 10), "count=" .. F.r8(S.gPartiesCount))
  setHeldItem(party(1), ITEM_POTION)
  setHeldItem(party(3), ITEM_POTION)
  F.check("setup: debug Fill PC Boxes Fast ran", debugAction({ 1, 1, 0 }) and occupied(boxSlot(13, 29)))
  for s = 10, PER_BOX - 1 do for off = 0, BOX_MON - 4, 4 do F.w32(boxSlot(0, s) + off, 0) end end
  for s = 0, 14 do for off = 0, BOX_MON - 4, 4 do F.w32(boxSlot(1, s) + off, 0) end end
  for s = 0, 4 do setHeldItem(boxSlot(0, s), ITEM_POTION) end
  runScript({ 0x44, ITEM_POTION, 0, 5, 0, 0x02 }); F.idle(30)   -- additem ITEM_POTION, 5
  instantText()

  math.randomseed(SEED)
  local before = census()
  F.L(string.format("  seed=%d start: %d Pokemon, %d Potions", SEED, before.total, before.potions))
  local options = { 0, 1, 2, 3 }
  local okSessions = 0
  for session = 1, SESSIONS do
    local opt = options[(session - 1) % #options + 1]
    if not openPcMenu() then F.check("session " .. session .. ": the storage menu opened", false); break end
    F.idle(20); cursorTo(opt); F.press("A", 2); F.idle(150)
    local releases, lastFunc, lastState = 0, nil, nil
    local f, inPc, reentries = 0, 0, 0
    while f < MASH_FRAMES do
      if F.ow() then
        -- The mash left the storage screen: go back in rather than mash the field.
        reentries = reentries + 1
        if not pcMenuLive() then
          for _ = 1, 10 do F.press("B", 2); F.idle(20) end
          if not openPcMenu() then break end
        end
        F.idle(20); cursorTo(options[math.random(#options)]); F.press("A", 2); F.idle(150)
        f = f + 400
      end
      local k = KEYS[math.random(#KEYS)]
      -- Outside the storage screen (the summary), Select opens the debug-only sprite visualizer and
      -- R the move relearner; keep those keys to the PC, where they switch modes and page boxes.
      if (k == "Select" or k == "R" or k == "L") and not storageTask() then k = "B" end
      local hold, gap = math.random(1, 4), math.random(0, 8)
      for _ = 1, hold + gap do
        if _ <= hold then joypad.set({ [k] = true }) else joypad.set({}) end
        emu.frameadvance(); f = f + 1
        if not F.ow() then inPc = inPc + 1 end
        local fn, st = storageTask()
        if fn == (S.Task_ReleaseMon & ~1) and st == RELEASE_DONE_STATE
            and not (lastFunc == fn and lastState == RELEASE_DONE_STATE) then
          releases = releases + 1
        end
        lastFunc, lastState = fn, st
      end
      if F.reportCrash("session" .. session) then break end
    end
    -- A release still running when the mash stops finishes here, where it is counted too.
    for i = 1, 600 do
      local fn, st = storageTask()
      if fn ~= (S.Task_ReleaseMon & ~1) then break end
      if st == RELEASE_DONE_STATE and not (lastFunc == fn and lastState == RELEASE_DONE_STATE) then
        releases = releases + 1
      end
      lastFunc, lastState = fn, st
      joypad.set(i % 8 == 0 and { A = true } or {}); emu.frameadvance()
    end
    if F.reportCrash("session" .. session) then F.check("session " .. session .. ": no crash", false); break end
    F.shot(string.format("session_%02d", session))
    local left = leavePc()
    if not left then F.shot(string.format("session_%02d_stuck", session)) end
    for _ = 1, 4 do F.press("B", 2); F.idle(20) end
    local after = census()
    local cloned = {}
    for p, n in pairs(after.pids) do
      if n > (before.pids[p] or 0) then cloned[#cloned + 1] = string.format("%08X", p) end
    end
    for p, n in pairs(after.pids) do
      if n > (before.pids[p] or 0) then F.L(string.format("    grew: %08X x%d -> x%d now %s", p, before.pids[p] or 0, n, after.where[p])) end
    end
    for p, n in pairs(before.pids) do
      if n > (after.pids[p] or 0) then
        F.L(string.format("    gone: %08X x%d -> x%d, last seen %s", p, n, after.pids[p] or 0, before.where[p]))
      end
    end
    local tag = string.format("session %d (option %d, %d frames in the PC, %d re-entries, %d releases)",
      session, opt, inPc, reentries, releases)
    F.L(string.format("  %s: %d -> %d Pokemon, %d -> %d Potions", tag, before.total, after.total,
      before.potions, after.potions))
    local good = left and after.total == before.total - releases and #cloned == 0
      and after.potions == before.potions
    if not good then
      F.check(tag .. ": back on the field", left)
      F.check(tag .. ": only releases removed Pokemon", after.total == before.total - releases,
        string.format("%d -> %d with %d releases", before.total, after.total, releases))
      F.check(tag .. ": no Pokemon copied", #cloned == 0, table.concat(cloned, ","))
      F.check(tag .. ": no Potion lost or copied", after.potions == before.potions,
        string.format("%d -> %d", before.potions, after.potions))
      break
    end
    okSessions = okSessions + 1
    before = after
  end
  F.check(string.format("all %d mash sessions kept every Pokemon and Potion", SESSIONS), okSessions == SESSIONS,
    okSessions .. " sessions clean")
  F.check("no crash", not F.reportCrash("end"))
  F.finish()
end)
