-- Two Johto menus whose scripts came from pokemonHnS but whose MULTI_* list resolves to this tree's.
--
-- The weekday siblings ask "Can you guess my favorite day?" over MULTI_DAYS_OF_WEEK and branch on the
-- row number HnS's list gives that day (SUNDAY first: Wesley's Wednesday is row 3, Santos's Saturday
-- row 6). This tree's list starts on MONDAY, so naming the right day was refused and the day after won.
--
-- The Ruins of Alph researcher, offered two fossils, shows MULTI_FOSSIL and branches Claw, Root, Helix,
-- Dome, Old Amber, Exit. Here MULTI_FOSSIL is Devon's two-fossil list (CLAW, ROOT, Exit), so Helix, Dome
-- and Old Amber could not be chosen and Exit (row 2) handed the Helix Fossil over.
--
-- Rows are picked by the label the menu shows: the suite reads the open menu's option texts from
-- sMultichoiceLists (the list the multichoice task draws) and steers the cursor to that row. Setup is a
-- warp and the items in the bag; talking, the Yes/No and the menu are real input.
--
-- Run via test/overworld/mgba-run.sh test/overworld/lua/JohtoPortedMenus.lua <rom.gba>

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "JohtoPortedMenus")

local CONTEXT_SHUTDOWN = 2
local ITEM_HELIX_FOSSIL, ITEM_OLD_AMBER, ITEM_BLACK_BELT, ITEM_SPELL_TAG = 165, 167, 431, 438
local ALPH = { 79, 3, 7, 3, "Up" }
local WESLEY = { 91, 4, 54, 15, "Right" }
local SANTOS = { 93, 0, 26, 39, "Right" }
local BUF = S.gStringVar4 + 900

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
local function additem(id) runScript({ 0x44, id & 0xFF, id >> 8, 1, 0, 0x02 }); settle() end

local function warp(at)
  local g, n, x, y = at[1], at[2], at[3], at[4]
  runScript({ 0x39, g, n, 0xFF, x & 0xFF, x >> 8, y & 0xFF, y >> 8, 0x27, 0x02 })
  for _ = 1, 600 do
    F.idle(4)
    local px, py = F.pos()
    if F.grp() == g and F.mapn() == n and px == x and py == y and hasControl() then F.idle(30); return true end
  end
  return false
end

local CH = {}
for i = 0, 9 do CH[0xA1 + i] = string.char(48 + i) end
for i = 0, 25 do CH[0xBB + i] = string.char(65 + i); CH[0xD5 + i] = string.char(97 + i) end
CH[0x00] = " "
local function romString(ptr)
  local s = {}
  for i = 0, 40 do
    local c = F.r8(ptr + i)
    if c == 0xFF then break end
    s[#s + 1] = CH[c] or "?"
  end
  return table.concat(s)
end

-- The open multichoice's option labels, from its task's multichoice id (tMultichoiceId, data[7]).
local function menuLabels()
  for i = 0, S.Task.count - 1 do
    local t = S.gTasks + i * S.Task.stride
    if F.r8(t + S.Task.isActive) ~= 0 and (F.r32(t + S.Task.func) & ~1) == (S.Task_HandleMultichoiceInput & ~1) then
      local id = F.r16(t + S.Task.data + 7 * 2)
      local list, count = F.r32(S.sMultichoiceLists + id * 8), F.r8(S.sMultichoiceLists + id * 8 + 4)
      local labels = {}
      for row = 0, count - 1 do labels[row] = romString(F.r32(list + row * 8)) end
      return labels, count
    end
  end
  return nil, 0
end

-- Talk, A through the lines (YES at a Yes/No), and at the multichoice pick the row labelled `want`.
-- Returns the labels the menu showed. With no such row the menu is cancelled with B.
local function talk(tag, at, want)
  if not F.check(tag .. ": stand before the NPC", warp(at)) then return {} end
  F.face(at[5])
  F.press("A", 2)
  local shown, done = nil, false
  for i = 1, 4000 do
    if i > 30 and hasControl() then break end
    local labels, count = menuLabels()
    if labels and not done then
      F.idle(20)
      shown = labels
      local row
      for r = 0, count - 1 do if labels[r]:upper() == want:upper() then row = r end end
      local listed = {}
      for r = 0, count - 1 do listed[#listed + 1] = labels[r] end
      F.L("  " .. tag .. ": menu rows " .. table.concat(listed, " | "))
      F.shot(tag .. "_menu")
      if row then
        for _ = 1, 12 do
          if F.mcur() == row then break end
          F.press("Down", 2); F.idle(8)
        end
        F.L("  " .. tag .. ": cursor on row " .. F.mcur() .. " for " .. want)
        F.press("A", 2)
      else
        F.press("B", 2)
      end
      done = true
    else
      joypad.set((i % 24 == 0 and not labels) and { A = true } or {})
      emu.frameadvance()
    end
  end
  F.shot(tag)
  F.check(tag .. ": control returns", hasControl(), "")
  return shown or {}
end
local function offers(labels, want)
  for _, l in pairs(labels) do if l:upper() == want:upper() then return true end end
  return false
end

F.run(function()
  if not F.boot(100) then F.check("boot", false); F.finish(); return end

  local menu = talk("wesley", WESLEY, "WEDNESDAY")
  F.check("wesley: the day menu offers WEDNESDAY", offers(menu, "WEDNESDAY"), "")
  F.check("wesley: answering WEDNESDAY gets his Black Belt", F.itemCount(ITEM_BLACK_BELT) == 1,
    "black belt slots=" .. F.itemCount(ITEM_BLACK_BELT))

  menu = talk("santos", SANTOS, "SATURDAY")
  F.check("santos: answering SATURDAY gets his Spell Tag", F.itemCount(ITEM_SPELL_TAG) == 1,
    "spell tag slots=" .. F.itemCount(ITEM_SPELL_TAG))

  additem(ITEM_HELIX_FOSSIL)
  additem(ITEM_OLD_AMBER)
  F.check("alph: Helix Fossil and Old Amber in the bag",
    F.itemCount(ITEM_HELIX_FOSSIL) == 1 and F.itemCount(ITEM_OLD_AMBER) == 1, "")
  menu = talk("alph_exit", ALPH, "EXIT")
  F.check("alph_exit: the fossil menu lists all five fossils",
    offers(menu, "CLAW FOSSIL") and offers(menu, "HELIX FOSSIL") and offers(menu, "DOME FOSSIL")
    and offers(menu, "OLD AMBER"), "")
  F.check("alph_exit: EXIT keeps both fossils",
    F.itemCount(ITEM_HELIX_FOSSIL) == 1 and F.itemCount(ITEM_OLD_AMBER) == 1,
    "helix=" .. F.itemCount(ITEM_HELIX_FOSSIL) .. " amber=" .. F.itemCount(ITEM_OLD_AMBER))

  menu = talk("alph_amber", ALPH, "OLD AMBER")
  F.check("alph_amber: OLD AMBER hands over the Old Amber and keeps the Helix Fossil",
    F.itemCount(ITEM_OLD_AMBER) == 0 and F.itemCount(ITEM_HELIX_FOSSIL) == 1,
    "helix=" .. F.itemCount(ITEM_HELIX_FOSSIL) .. " amber=" .. F.itemCount(ITEM_OLD_AMBER))
  F.check("no crash screen", not F.crashScreen(), tostring(F.crashScreen()))
  F.finish()
end)
