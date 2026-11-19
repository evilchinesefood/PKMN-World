-- Save format v14's load gate, driven through the main menu with forged flash images.
--
-- A fresh game saves twice in the hub (counter 1 on one tile, counter 2 on the next), and its own
-- flash bytes are the base for every image. Each image is swapped into the cartridge, the console
-- is reset, and the main menu's verdict is read: the load status, the version refusal, the error
-- window and the menu rows. Older images (the tracked v3 and v13 saves), a newer one (the version
-- byte above SAVE_FORMAT_VERSION with valid checksums) and damaged ones (a bad checksum, a cleared
-- signature, the wrong counter parity, a duplicated sector, a damaged PC sector, both slots damaged,
-- all 0x00, all 0xFF, a damaged Hall of Fame, a v13 slot beside a v14 slot on either side) each get
-- their own message. The error window is paged with screenshots or mashed with A, B, Start and
-- Select. A surviving slot must Continue onto its own tile.
--
-- Then NEW GAME over refused cartridges. Text speed chosen on the title Options of a refused v13
-- cart reaches the new game, and its first save loads cleanly. A v3 cart saved twice: the first
-- save left the old layout's other slot behind, and the next boot called the new file corrupted. A
-- v3 cart saved once: a power cut between any two sectors of the new game's first save may not leave
-- a slot that loads. The new game reused the old slot's counter and sector rotation, so the old PC
-- sectors completed the torn slot. Last, a power cut in a normal v14 save falls back to the slot
-- written before it (the counter parity rule accepts every slot the game writes).
--
-- Run via test/overworld/mgba-run.sh test/overworld/lua/SaveGateStress.lua <rom>

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, os.getenv("PW_CASE_NAME") or "SaveGateStress")

local HUB_GROUP = 100
local USM_ICO_SAVE = 7
local SENTINEL = 0xFFFF
local CONTEXT_SHUTDOWN = 2
local SECTOR, SIG, PER_SLOT = 0x1000, 0x08012025, 14
local EMPTY, OK, CORRUPT, ERROR = 0, 1, 2, 0xFF
local NONE, TOO_OLD, TOO_NEW = 0, 1, 2
local HAS_NO_SAVED_GAME, HAS_SAVED_GAME = 0, 1
local OUT = os.getenv("PW_OUT") or "./"
local LIVE = OUT .. "../emulator/Verify1.sav"
local BOX_COUNT, BOX_SIZE = 14, 30
local LAST_WALLPAPER = 4 + BOX_COUNT * BOX_SIZE * S.BoxPokemon.size + BOX_COUNT * 9 + BOX_COUNT - 1
local MARK_WALLPAPER = 13
local STATUS_NAME = { [EMPTY] = "EMPTY", [OK] = "OK", [CORRUPT] = "CORRUPT", [ERROR] = "ERROR" }

local rngState = tonumber(os.getenv("PW_SGS_SEED") or "") or 1409
local function rnd(n)
  rngState = (rngState * 1103515245 + 12345) & 0x7FFFFFFF
  return rngState % n
end

-- ---- flash images ----------------------------------------------------------------------------
local function readFile(p) local f = io.open(p, "rb"); if not f then return nil end local s = f:read("a"); f:close(); return s end
local function writeFile(p, s) local f = assert(io.open(p, "wb")); f:write(s); f:close() end
local function split(img) local t = {} for i = 0, 31 do t[i] = img:sub(i * SECTOR + 1, (i + 1) * SECTOR) end return t end
local function join(t) local p = {} for i = 0, 31 do p[#p + 1] = t[i] end return table.concat(p) end
local function foot(s) return string.unpack("<I2I2I4I4", s, 0xFF5) end
local function setFoot(s, id, ck, sig, ctr) return s:sub(1, 0xFF4) .. string.pack("<I2I2I4I4", id, ck, sig, ctr) end
local function poke(s, off, bytes) return s:sub(1, off) .. bytes .. s:sub(off + #bytes + 1) end
local function cksum(s, size)
  local t = 0
  for i = 0, size // 4 - 1 do t = (t + string.unpack("<I4", s, i * 4 + 1)) & 0xFFFFFFFF end
  return ((t >> 16) + t) & 0xFFFF
end

local sizes = {}
local function phys(t, slot, id)
  for i = 0, PER_SLOT - 1 do
    local sid = foot(t[slot * PER_SLOT + i])
    if sid == id then return slot * PER_SLOT + i end
  end
end
local function describe(tag, img)
  local t, rows = split(img), {}
  for n = 0, 31 do
    local id, ck, sig, ctr = foot(t[n])
    if sig == SIG and n < 28 then
      local good = id < PER_SLOT and cksum(t[n], sizes[id]) == ck
      rows[#rows + 1] = string.format("%d:%d/%d%s%s", n, id, ctr, good and "" or "!", id == 0 and (" v" .. t[n]:byte(0x92)) or "")
    end
  end
  F.L("  [" .. tag .. "] " .. table.concat(rows, " "))
end
local function edit(img, fn) local t = split(img); fn(t); return join(t) end

-- ---- driving ---------------------------------------------------------------------------------
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

-- Save from the Start menu; hook(frame) runs on each frame of the flash write and returns true to stop.
local function driveSave(hook)
  F.w16(S.gSaveAttemptStatus, SENTINEL)
  local c0 = F.r32(S.gSaveCounter)
  if not awaitControl(300) then return "nocontrol", 0 end
  F.press("Start", 2); F.idle(60)
  if not F.selectStartIcon(USM_ICO_SAVE) then return "noicon", 0 end
  local writing = 0
  for i = 1, 3000 do
    local started = F.r32(S.gSaveCounter) ~= c0
    local done = F.r16(S.gSaveAttemptStatus) ~= SENTINEL
    if started and not done then
      if hook and hook(writing) then return "cut", writing end
      writing = writing + 1
    end
    if done then
      F.idle(30)
      for _ = 1, 6 do F.press("B", 2); F.idle(20) end
      return F.r16(S.gSaveAttemptStatus) == OK and "done" or "failed", writing
    end
    if i % 20 == 1 then joypad.set({ A = true }) else joypad.set({}) end
    emu.frameadvance()
  end
  return "timeout", writing
end

local function findTask(fn)
  for i = 0, S.Task.count - 1 do
    local task = S.gTasks + i * S.Task.stride
    if F.r8(task + S.Task.isActive) ~= 0 and (F.r32(task + S.Task.func) & ~1) == (fn & ~1) then return task end
  end
end

-- Reset into the main menu. With page = true every page of a save error is held for a screenshot
-- and turned with A; otherwise the error window is mashed with A, B, Start and Select, which stops
-- the moment the window closes so no press can land on the menu rows.
local MASH = { "A", "B", "Start", "Select" }
local function toMenu(tag, page, keepPower)
  if not keepPower then client.reboot_core() end
  local menu, errSeen, pages, wait = nil, false, 0, 0
  for frame = 1, 8000 do
    menu = findTask(S.Task_HandleMainMenuInput)
    if menu then break end
    if frame % 300 == 0 and F.noteCrash(tag .. "_menu") then break end
    local err = findTask(S.Task_WaitForSaveFileErrorWindow)
    if err then
      errSeen = true
      if page then
        wait = wait + 1
        if wait == 170 then
          pages = pages + 1
          F.shot(tag .. "_page" .. pages)
          joypad.set({ A = true })
          wait = 0
        else
          joypad.set({})
        end
      else
        joypad.set(rnd(3) == 0 and { [MASH[rnd(#MASH) + 1]] = true } or {})
      end
    elseif not errSeen and frame % 18 < 2 then
      joypad.set({ A = true })
    else
      joypad.set({})
    end
    emu.frameadvance()
  end
  joypad.set({})
  if not menu then F.shot(tag .. "_nomenu"); return nil end
  F.idle(20)
  if not findTask(S.Task_HandleMainMenuInput) then F.L("  " .. tag .. ": a press left the menu"); return nil end
  local v = { status = F.r16(S.gSaveFileStatus), refusal = F.r8(S.gSaveVersionRefusal), err = errSeen,
    menuType = F.r16(menu + S.Task.data), items = F.r16(menu + S.Task.data + 24), counter = F.r32(S.gSaveCounter) }
  F.L(string.format("  %s: status=%s refusal=%d error window=%s rows=%d counter=%d", tag,
    STATUS_NAME[v.status] or tostring(v.status), v.refusal, tostring(v.err), v.items, v.counter))
  F.shot(tag .. "_menu")
  return v
end

local function loadImage(tag, img)
  local p = OUT .. tag .. ".sav"
  writeFile(p, img)
  describe(tag, img)
  return client.loadsave(p), p
end

-- From the main menu: row 0 is CONTINUE on a saved game and NEW GAME otherwise. A new game ends
-- with the hub's arrival scene cleared; a Continue keeps the player on the saved tile.
local function startGame(tag, newGame)
  local ok = newGame and F.boot(HUB_GROUP) or (F.boot(nil, true) and awaitControl(1200))
  if F.reportCrash(tag) then return false end
  return ok
end

F.run(function()
  if not F.boot(HUB_GROUP) then F.check("boot to the hub", false); F.finish(); return end
  for i = 0, PER_SLOT - 1 do sizes[i] = F.r16(S.gRamSaveSectorLocations + i * 8 + 4) end
  F.L("  slot chunk sizes " .. table.concat(sizes, ",", 0, PER_SLOT - 1))
  local tileOld = { F.pos() }
  local s1 = driveSave()
  if not F.step("Right") then F.step("Left") end
  local tileNew = { F.pos() }
  local s2 = driveSave()
  F.idle(300)
  F.check("the hub game saves twice", s1 == "done" and s2 == "done" and F.r32(S.gSaveCounter) == 2,
    s1 .. "," .. s2 .. " counter=" .. F.r32(S.gSaveCounter))
  local base = readFile(LIVE)
  if not F.check("the cartridge's flash file is readable", base ~= nil and #base >= 0x20000) then F.finish(); return end
  base = base:sub(1, 0x20000)
  describe("base", base)
  local t0 = split(base)
  F.check("counter 2 sits in slot 0 and counter 1 in slot 1",
    select(4, foot(t0[phys(t0, 0, 0)])) == 2 and select(4, foot(t0[phys(t0, 1, 0)])) == 1)

  local v3 = readFile(here .. "fixtures/v3.srm"):sub(1, 0x20000)
  local v13 = readFile(here .. "fixtures/v13.srm"):sub(1, 0x20000)

  local function damage(slot, id) return function(t)
    local n = phys(t, slot, id)
    t[n] = poke(t[n], 0, string.char(t[n]:byte(1) ~ 0xFF))
  end end
  local function moveSlot(src, srcSlot, dstSlot, ctr) return function(t)
    local s = split(src)
    for i = 0, PER_SLOT - 1 do
      local id, ck, sig = foot(s[srcSlot * PER_SLOT + i])
      t[dstSlot * PER_SLOT + i] = setFoot(s[srcSlot * PER_SLOT + i], id, ck, sig, ctr)
    end
  end end

  local cases = {
    { "intact", base, OK, NONE, HAS_SAVED_GAME, 2, tileNew },
    { "newest_checksum", edit(base, damage(0, 3)), ERROR, NONE, HAS_SAVED_GAME, 1, tileOld },
    { "newest_signature", edit(base, function(t)
        local n = phys(t, 0, 7); local id, ck, _, ctr = foot(t[n]); t[n] = setFoot(t[n], id, ck, 0, ctr) end),
      ERROR, NONE, HAS_SAVED_GAME, 1 },
    { "newest_parity", edit(base, function(t)
        for i = 0, PER_SLOT - 1 do local id, ck, sig = foot(t[i]); t[i] = setFoot(t[i], id, ck, sig, 3) end end),
      ERROR, NONE, HAS_SAVED_GAME, 1, tileOld },
    { "newest_duplicate", edit(base, function(t) t[phys(t, 0, 13)] = t[phys(t, 0, 5)] end), ERROR, NONE, HAS_SAVED_GAME, 1 },
    { "newest_pc_box", edit(base, damage(0, 9)), ERROR, NONE, HAS_SAVED_GAME, 1 },
    { "both_damaged", edit(base, function(t) damage(0, 2)(t); damage(1, 11)(t) end), CORRUPT, NONE, HAS_NO_SAVED_GAME },
    { "all_zero", string.rep("\0", 0x20000), EMPTY, NONE, HAS_NO_SAVED_GAME },
    { "all_ff", string.rep("\255", 0x20000), EMPTY, NONE, HAS_NO_SAVED_GAME },
    { "hall_of_fame_damaged", edit(base, function(t)
        for n = 28, 29 do t[n] = setFoot(string.rep("\90", SECTOR), 0x1234, 0, SIG, 0) end end),
      OK, NONE, HAS_SAVED_GAME, 2 },
    { "newer_version", edit(base, function(t)
        local n = phys(t, 0, 0); local s = poke(t[n], 0x91, string.char(S.SAVE_FORMAT_VERSION + 1))
        local id, _, sig, ctr = foot(s); t[n] = setFoot(s, id, cksum(s, sizes[0]), sig, ctr) end),
      EMPTY, TOO_NEW, HAS_NO_SAVED_GAME },
    { "v13_newer_than_v14", edit(base, moveSlot(v13, 1, 1, 3)), EMPTY, TOO_OLD, HAS_NO_SAVED_GAME },
    { "v14_newer_than_v13", edit(base, moveSlot(v13, 1, 1, 1)), OK, NONE, HAS_SAVED_GAME, 2, tileNew },
    { "v3", v3, EMPTY, TOO_OLD, HAS_NO_SAVED_GAME },
    { "v13", v13, EMPTY, TOO_OLD, HAS_NO_SAVED_GAME },
  }
  for i, c in ipairs(cases) do
    local tag, img, status, refusal, menuType, counter, tile = table.unpack(c)
    loadImage(tag, img)
    local v = toMenu(tag, i % 2 == 1)
    if not F.check(tag .. ": the main menu opens", v ~= nil) then break end
    local wantErr = status == ERROR or status == CORRUPT or refusal ~= NONE
    F.check(tag .. ": " .. (STATUS_NAME[status] or "?") .. " with refusal " .. refusal,
      v.status == status and v.refusal == refusal and v.err == wantErr and v.menuType == menuType
        and (counter == nil or v.counter == counter),
      string.format("status=%02X refusal=%d error=%s menu=%d counter=%d", v.status, v.refusal, tostring(v.err), v.menuType, v.counter))
    if tile then
      local ok = startGame(tag)
      local x, y = F.pos()
      F.check(tag .. ": CONTINUE lands on the saved tile with control", ok and x == tile[1] and y == tile[2],
        string.format("(%d,%d) want (%d,%d)", x, y, tile[1], tile[2]))
    end
  end

  -- Title Options on a refused v13 cart reach the new game, and its first save replaces the file.
  loadImage("v13_options", v13)
  local v = toMenu("v13_options", false)
  local menu = findTask(S.Task_HandleMainMenuInput)
  if v and v.refusal == TOO_OLD and menu then
    local speed0 = F.r16(F.sb2() + S.SaveBlock2.optionsU16) & 7
    F.press("Down", 2); F.idle(12)
    F.check("v13 options: the cursor is on OPTIONS", F.r16(menu + S.Task.data + 2) == 1, "row=" .. F.r16(menu + S.Task.data + 2))
    F.press("A", 2)
    for _ = 1, 300 do if findTask(S.Task_OptionMenuProcessInput) then break end F.idle(1) end
    F.idle(30)
    F.press("Right", 2); F.idle(12)
    F.press("B", 2)
    v = toMenu("v13_options_back", false, true)
    local speed1 = F.r16(F.sb2() + S.SaveBlock2.optionsU16) & 7
    F.check("v13 options: the title Options change text speed", speed1 ~= speed0, speed0 .. "->" .. speed1)
    F.check("v13 options: back from Options the refusal is shown again", v and v.err and v.refusal == TOO_OLD)
    menu = findTask(S.Task_HandleMainMenuInput)
    for _ = 1, 4 do
      if not menu or F.r16(menu + S.Task.data + 2) == 0 then break end
      F.press("Up", 2); F.idle(12)
    end
    if startGame("v13_newgame", true) then
      F.check("v13 options: the new game keeps the title's text speed", (F.r16(F.sb2() + S.SaveBlock2.optionsU16) & 7) == speed1,
        "speed=" .. (F.r16(F.sb2() + S.SaveBlock2.optionsU16) & 7))
      local st = driveSave(); F.idle(300)
      F.check("v13 options: the new game's first save lands", st == "done", st)
      v = toMenu("v13_reboot", false)
      F.check("v13 options: the next boot loads the new game cleanly", v and v.status == OK and not v.err and v.menuType == HAS_SAVED_GAME,
        v and string.format("status=%02X error=%s", v.status, tostring(v.err)))
    else
      F.check("v13 options: new game reaches the hub", false)
    end
  else
    F.check("v13 options: the cart is refused", false)
  end

  -- A v3 cart saved twice: the second slot carries counter 2, one sector further round.
  local v3two = edit(v3, function(t)
    for k = 0, PER_SLOT - 1 do
      local id, ck, sig = foot(t[PER_SLOT + k])
      t[(id + 2) % PER_SLOT] = setFoot(t[PER_SLOT + k], id, ck, sig, 2)
    end
  end)
  loadImage("v3_two_slots", v3two)
  v = toMenu("v3_two_slots", true)
  if F.check("v3 saved twice is refused as older", v and v.status == EMPTY and v.refusal == TOO_OLD) and startGame("v3_two_newgame", true) then
    local st = driveSave(); F.idle(300)
    F.check("v3 saved twice: the new game's first save lands", st == "done", st)
    describe("v3_two_after", readFile(OUT .. "v3_two_slots.sav"):sub(1, 0x20000))
    v = toMenu("v3_two_reboot", true)
    F.check("v3 saved twice: the next boot loads the new game without a corruption message",
      v and v.status == OK and not v.err and v.menuType == HAS_SAVED_GAME,
      v and string.format("status=%02X error=%s", v.status, tostring(v.err)))
  end

  -- A v3 cart saved once, its last box wallpaper marked, then the new game's first save. The game
  -- writes a slot's sectors in id order, so a power cut that lands after sector k has verified and
  -- before sector k+1 is erased leaves sectors 0..k new and the rest as they were when the write
  -- began. Frame-edge resets reach that window only when the sector timing happens to align (the
  -- music's interrupts shift it), so each such cut is rebuilt from the cartridge's own flash: the
  -- image at the write's first frame and the image after it. Each one boots for the game's verdict.
  local v3mark = edit(v3, function(t)
    local n = phys(t, 1, 13)
    local s = poke(t[n], LAST_WALLPAPER - 8 * 3968, string.char(MARK_WALLPAPER))
    local id, _, sig, ctr = foot(s)
    t[n] = setFoot(s, id, cksum(s, sizes[13]), sig, ctr)
  end)
  local tornPath = select(2, loadImage("v3_torn", v3mark))
  v = toMenu("v3_torn", false)
  if F.check("v3 saved once is refused as older", v and v.refusal == TOO_OLD) and startGame("v3_torn_newgame", true) then
    local before
    local st = driveSave(function(frame)
      if frame == 0 then before = readFile(tornPath):sub(1, 0x20000) end
      return false
    end)
    local after = readFile(tornPath):sub(1, 0x20000)
    local slot = F.r32(S.gSaveCounter) % 2
    F.check("v3 torn first save: the uncut write lands", st == "done" and before ~= nil, st)
    local loaded = {}
    for k = 0, PER_SLOT - 2 do
      local tag = "v3_torn_after_" .. k
      local a, img = split(after), split(before)
      for id = 0, k do local n = phys(a, slot, id); img[n] = a[n] end
      loadImage(tag, join(img))
      v = toMenu(tag, false)
      if v and (v.status == OK or v.status == ERROR) then loaded[#loaded + 1] = k end
    end
    F.check("v3 torn first save: no cut between two sectors leaves a slot that loads", #loaded == 0,
      "loaded after sector " .. table.concat(loaded, ","))
    local k = loaded[1] or PER_SLOT // 2
    loadImage("v3_torn_after_" .. k, (function()
      local a, img = split(after), split(before)
      for id = 0, k do local n = phys(a, slot, id); img[n] = a[n] end
      return join(img)
    end)())
    v = toMenu("v3_torn_after_" .. k .. "_reboot", true)
    local wallpaper
    if v and (v.status == OK or v.status == ERROR) and startGame("v3_torn_continue") then
      wallpaper = F.r8(F.r32(S.gPokemonStoragePtr) + LAST_WALLPAPER)
    end
    F.check("v3 torn first save: cut after sector " .. k .. ", only NEW GAME is offered",
      v ~= nil and v.menuType == HAS_NO_SAVED_GAME and wallpaper == nil,
      v and string.format("status=%02X refusal=%d menu=%d old wallpaper read back=%s", v.status, v.refusal, v.menuType, tostring(wallpaper)))
  end

  -- A power cut in a normal v14 save keeps the slot the game wrote before it.
  loadImage("v14_torn", base)
  v = toMenu("v14_torn", false)
  if v and v.status == OK and startGame("v14_torn_continue") then
    local st, frames = driveSave(function(frame)
      if frame >= 120 then client.reboot_core(); return true end
      return false
    end)
    v = toMenu("v14_torn_reboot", true)
    F.check("v14 torn save: the previous save loads with its own counter", v and v.status == ERROR and v.counter == 2,
      v and string.format("%s at frame %d status=%02X counter=%d", st, frames, v.status, v.counter))
    if v and startGame("v14_torn_after") then
      local x, y = F.pos()
      F.check("v14 torn save: CONTINUE lands on the previous save's tile", x == tileNew[1] and y == tileNew[2],
        string.format("(%d,%d)", x, y))
    end
  end
  F.finish()
end)
