-- The SwSh PC's box rename (Box title, Name) under edge input. An empty name (Backspace past the
-- start, then OK) must keep the old name; the keyboard page cycle (Select) must come back to upper
-- case; eight W's (the widest letter) fill the name, a ninth A press lands on OK and saves exactly
-- eight; four seeded mash sessions across the naming screen and the storage screen must leave every
-- box name terminated within its nine bytes; and the names must survive a Start-menu save, soft
-- reset and Continue byte for byte. Screenshots show the wide name in the title bar and Jump view.
--
-- Run via test/overworld/mgba-run.sh test/overworld/lua/BoxRenameStress.lua <rom>

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "BoxRenameStress")

local PC_MENU_ROWS = 5
local USM_ICO_SAVE = 7
local BOX_NAMES = 0x8344        -- offsetof(struct PokemonStorage, boxNames)
local BOX_NAME_SIZE = 9
local TOTAL_BOXES = 14
local CURSOR_AREA_BOX_TITLE = 2
local CHAR_W, EOS = 0xD1, 0xFF

local function nameBytes(b)
  local base = F.r32(S.gPokemonStoragePtr) + BOX_NAMES + b * BOX_NAME_SIZE
  local t = {}
  for i = 0, BOX_NAME_SIZE - 1 do t[#t + 1] = F.r8(base + i) end
  return t
end
local function hex(t) local o = {}; for _, v in ipairs(t) do o[#o + 1] = string.format("%02X", v) end; return table.concat(o, " ") end
local function allNames() local o = {}; for b = 0, TOTAL_BOXES - 1 do o[#o + 1] = hex(nameBytes(b)) end; return table.concat(o, " | ") end
local function terminated(t) for _, v in ipairs(t) do if v == EOS then return true end end; return false end

local function openStorage()
  F.w8(S.sMenu + 2, 0); F.w8(S.sMenu + S.Menu.maxCursorPos, 0)
  F.dbg(); F.idle(60); F.press("Down", 3); F.idle(16); F.press("A", 3); F.idle(60); F.press("A", 3); F.idle(60)
  for _ = 1, 200 do
    if F.ow() and F.rs8(S.sMenu + S.Menu.maxCursorPos) == PC_MENU_ROWS - 1 then break end
    F.press("A", 2); F.idle(18)
  end
  F.press("A", 2)
  for _ = 1, 300 do F.idle(2); if not F.ow() then break end end
  F.idle(120)
  return not F.ow()
end

local function openNaming(tag)
  if F.r8(S.sCursorArea) ~= CURSOR_AREA_BOX_TITLE then F.press("Up", 2); F.idle(30) end
  F.press("A", 2); F.idle(40)
  F.press("Down", 2); F.idle(15); F.press("Down", 2); F.idle(15); F.press("A", 2); F.idle(150)
  F.shot(tag .. "_naming")
end

local function leaveToField()
  for _ = 1, 60 do
    if F.ow() and F.ensureFree() then return true end
    F.press("B", 2); F.idle(30)
  end
  return F.ow()
end

local function driveSave()
  F.w16(S.gSaveAttemptStatus, 0xFFFF)
  F.press("Start", 2); F.idle(60)
  if not F.selectStartIcon(USM_ICO_SAVE) then return "noicon" end
  for i = 1, 3000 do
    if F.r16(S.gSaveAttemptStatus) ~= 0xFFFF then
      F.idle(30)
      for _ = 1, 6 do F.press("B", 2); F.idle(20) end
      return F.r16(S.gSaveAttemptStatus) == 1 and "done" or "failed"
    end
    if i % 20 == 1 then joypad.set({ A = true }) else joypad.set({}) end
    emu.frameadvance()
  end
  return "timeout"
end

F.run(function()
  if not F.boot(100) then F.check("boot", false); F.finish(); return end
  local box1 = hex(nameBytes(0))
  F.check("opened the storage screen", openStorage())

  openNaming("empty")
  for _ = 1, 12 do F.press("B", 2); F.idle(10) end
  F.press("Start", 2); F.idle(30); F.press("A", 2); F.idle(220)
  F.check("an empty name keeps the old box name", hex(nameBytes(0)) == box1, hex(nameBytes(0)))

  openNaming("wide")
  for _ = 1, 3 do F.press("Down", 2); F.idle(10) end
  for _ = 1, 3 do F.press("Right", 2); F.idle(10) end
  F.press("A", 2); F.idle(80)
  F.press("Select", 2); F.idle(80); F.press("Select", 2); F.idle(80)
  F.shot("wide_upper_again")
  for _ = 1, 7 do F.press("A", 2); F.idle(20) end
  F.shot("wide_typed8")
  F.press("A", 2); F.idle(220)
  F.shot("wide_title")
  local want = hex({ CHAR_W, CHAR_W, CHAR_W, CHAR_W, CHAR_W, CHAR_W, CHAR_W, CHAR_W, EOS })
  F.check("eight W's are saved and the ninth A press confirms", hex(nameBytes(0)) == want, hex(nameBytes(0)))
  F.press("A", 2); F.idle(40); F.press("A", 2); F.idle(80); F.shot("wide_jump_view")
  F.press("B", 2); F.idle(40); F.press("B", 2); F.idle(40)

  math.randomseed(6)
  local keys = { "A", "B", "Up", "Down", "Left", "Right", "Select", "Start", "L", "R" }
  for round = 1, 4 do
    if F.ow() then openStorage() end
    openNaming("mash" .. round)
    for _ = 1, 1500 do
      if F.ow() then break end
      local k = keys[math.random(#keys)]
      if k == "Start" and math.random(10) > 2 then k = "A" end
      F.press(k, 2); F.idle(math.random(0, 6))
      if F.reportCrash("mash" .. round) then break end
    end
    F.shot("mash" .. round .. "_end")
    local ok = true
    for b = 0, TOTAL_BOXES - 1 do ok = ok and terminated(nameBytes(b)) end
    F.check("mash " .. round .. ": every box name ends within nine bytes", ok, allNames())
  end

  F.check("back on the field", leaveToField())
  local before = allNames()
  F.check("saved from the Start menu", driveSave() == "done")
  for _ = 1, 8 do joypad.set({ A = true, B = true, Start = true, Select = true }); emu.frameadvance() end
  joypad.set({}); F.idle(60)
  F.check("continued", F.boot(nil, true))
  F.check("box names survive save, reset and Continue", allNames() == before, allNames())
  F.check("the storage screen opens after Continue", openStorage())
  F.shot("continued_storage")
  F.check("no crash screen", not F.crashScreen())
  F.finish()
end)
