-- Both Hall of Fame PC viewers print a record's dex number the same way.
--
-- The records are one buffer that two viewers read: the Kanto one (hall_of_fame_frlg.c) at Kanto
-- PCs and the Emerald one (hall_of_fame.c) elsewhere. Each printed the "No." line with its own
-- code: the Emerald viewer four digits once the National Pokedex is on ("No. 0031"), the Kanto
-- viewer always three ("No. 031").
--
-- The National Pokedex is switched on by the special the professors' scripts run. Each record is
-- a real Kanto induction (warp onto the Hall of Fame room's arrival tile, the room's script
-- inducts, the screen saves and soft resets, Continue). The team is one Pokemon: Wobbuffet, which
-- has no Kanto dex number, then Nidoqueen. Both viewers are opened at Center PCs with real input,
-- and the "No." line's pixels are read from window 0's tile data, colour-blind, at the same screen
-- position. The two viewers must draw the same pixels for the same record, and the two records
-- must differ.
--
-- Run: test/overworld/mgba-run.sh test/overworld/lua/HofDexNumbers.lua

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "HofDexNumbers")

local PARTY_SIZE, MON = 6, S.Pokemon.size
local SPECIES_NIDOQUEEN, SPECIES_WOBBUFFET = 31, 202
local CONTEXT_RUNNING, CONTEXT_SHUTDOWN = 0, 2
local SPECIAL_ENABLE_NATIONAL_POKEDEX = 503
local VAR_NATIONAL_DEX = 0x4046
local HOF_TEAM_SIZE = 24 * 6
local TASK_SIZE, TASK_ACTIVE, TASK_DATA = 40, 4, 8
local NUM_TASKS = 16

local KANTO_HOF = { 35, 80, 5, 12 }
local VIRIDIAN_PC = { 39, 4, 11, 2 }
local OLDALE_PC = { 2, 2, 10, 2 }

local function instantText()
  local a = F.sb2() + S.SaveBlock2.optionsU16
  F.w16(a, (F.r16(a) & ~7) | 3)
end
local function hasControl()
  return F.ow() and F.r8(S.sLockFieldControls) == 0 and F.r8(S.sGlobalScriptContextStatus) == CONTEXT_SHUTDOWN
end
local function settle()
  for _ = 1, 300 do if hasControl() then return true end F.press("B", 2); F.idle(10) end
  return hasControl()
end
local function var(id) return F.r16(F.sb1() + S.SaveBlock1.vars + (id - 0x4000) * 2) end

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
local function warpScript(p)
  local b = { 0x39, p[1], p[2], 0xFF }
  le16(b, p[3]); le16(b, p[4]); b[#b + 1] = 0x27; b[#b + 1] = 0x02
  runScript(b)
  for _ = 1, 400 do
    F.idle(4)
    if F.reportCrash("warp") then return false end
    if F.grp() == p[1] and F.mapn() == p[2] and F.ow() then return true end
  end
  return false
end

local function checksumOk(a)
  local key = F.r32(a) ~ F.r32(a + 4)
  local sum = 0
  for i = 0, 11 do local w = F.r32(a + 32 + i * 4) ~ key; sum = sum + (w & 0xFFFF) + (w >> 16) end
  return (sum & 0xFFFF) == F.r16(a + 28)
end
local function digits(n) n = n - 1; return n // 100, (n // 10) % 10, n % 10 end
local function giveOne(sp)
  for _ = 1, 3 do
    for off = 0, PARTY_SIZE * MON - 4, 4 do F.w32(S.gParties + off, 0) end
    F.w8(S.gPartiesCount, 0)
    F.dbg(); F.idle(30); F.bOut(4)
    F.dbg(); F.sel(3); F.sel(1); F.idle(20)
    F.spin(digits(sp)); F.idle(20)
    F.spin(digits(50)); F.idle(60); F.bOut(4)
    if F.r8(S.gPartiesCount) == 1 and checksumOk(S.gParties) then settle(); return true end
    F.idle(60)
  end
  return false
end

local function induct(tag)
  if not warpScript(KANTO_HOF) then return false, "warp" end
  local left = false
  for i = 1, 6000 do
    if not F.ow() then left = true; break end
    if i % 12 == 0 then F.press("A", 2) else F.idle(1) end
  end
  if not left then F.shot(tag .. "_stuck_in_room"); return false, "no Hall of Fame screen" end
  F.idle(60)
  if not F.boot(nil, true) then return false, "no Continue" end
  settle()
  instantText()
  return true, ""
end

local function viewerOpen(pageNo)
  for i = 0, NUM_TASKS - 1 do
    local t = S.gTasks + i * TASK_SIZE
    if F.r8(t + TASK_ACTIVE) ~= 0 and F.r16(t + TASK_DATA + 2) == pageNo then return true end
  end
  return false
end

-- Window 0's "No." line as a colour-blind pixel mask, screen x 16..79 and rows 0..15. A pixel's
-- place in the tile data depends on the window width, so it is read through the tile layout.
local function dexLineMask()
  local w = S.gWindows
  local width, data = F.r8(w + S.Window.width), F.r32(w + S.Window.tileData)
  if data < 0x02000000 or data >= 0x02040000 or width == 0 then return nil, 0 end
  local rows, ink = {}, 0
  for y = 0, 15 do
    local row = {}
    for x = 16, 79 do
      local tile = (y // 8) * width + (x // 8)
      local b = F.r8(data + tile * 32 + (y % 8) * 4 + (x % 8) // 2)
      local px = (x % 2 == 0) and (b & 0xF) or (b >> 4)
      row[#row + 1] = px ~= 0 and "#" or "."
      if px ~= 0 then ink = ink + 1 end
    end
    rows[#rows + 1] = table.concat(row)
  end
  return table.concat(rows, "/"), ink
end

local function viewDexLine(pc, pageNo, tag)
  if not warpScript(pc) then F.check(tag .. ": reached the PC", false); return nil end
  settle(); instantText()
  F.face("Up")
  F.w8(S.sMenu + S.Menu.cursorPos, 0); F.w8(S.sMenu + S.Menu.maxCursorPos, 0)
  F.press("A", 2)
  local live = false
  for _ = 1, 120 do
    F.idle(10)
    if F.r8(S.sMenu + S.Menu.maxCursorPos) == 3 then live = true; break end
    F.press("A", 2)
  end
  if not F.check(tag .. ": PC menu with HALL OF FAME opened", live) then F.shot(tag .. "_no_pc_menu"); settle(); return nil end
  F.idle(20)
  for _ = 1, 8 do
    if F.mcur() == 2 then break end
    F.press("Down", 2); F.idle(12)
  end
  F.press("A", 2)
  local open = false
  for _ = 1, 600 do
    F.idle(5)
    if viewerOpen(pageNo) and not F.ow() then F.idle(120); open = true; break end
  end
  F.check(tag .. ": viewer opened", open)
  F.shot(tag)
  local mask, ink = dexLineMask()
  F.L(string.format("  %s: No. line ink %d px", tag, ink))
  for _ = 1, 3 do F.press("B", 2); F.idle(40) end
  settle()
  return mask
end

F.run(function()
  if not F.boot(100) then F.finish(); return end
  instantText()
  local b = { 0x25 }; le16(b, SPECIAL_ENABLE_NATIONAL_POKEDEX); b[#b + 1] = 0x02
  runScript(b); F.idle(30)
  F.check("setup: the National Pokedex is on", var(VAR_NATIONAL_DEX) == 0x302, string.format("var=%04X", var(VAR_NATIONAL_DEX)))

  local masks = {}
  for n, sp in ipairs({ SPECIES_WOBBUFFET, SPECIES_NIDOQUEEN }) do
    local name = sp == SPECIES_WOBBUFFET and "Wobbuffet" or "Nidoqueen"
    F.check(name .. ": setup gave a one-Pokemon party", giveOne(sp))
    local ok, why = induct(name)
    if not F.check(name .. ": Kanto induction returns to the field", ok, why) then F.finish(); return end
    local kanto = viewDexLine(VIRIDIAN_PC, n, name .. "_kanto_viewer")
    local hoenn = viewDexLine(OLDALE_PC, n, name .. "_emerald_viewer")
    F.check(name .. ": both viewers drew a No. line", kanto ~= nil and hoenn ~= nil and kanto:find("#", 1, true) ~= nil)
    F.check(name .. ": the Kanto viewer's No. line matches the Emerald viewer's", kanto == hoenn,
      "the two viewers printed different dex numbers for one record")
    masks[#masks + 1] = hoenn
  end
  F.check("the two records print different numbers", masks[1] ~= nil and masks[1] ~= masks[2])

  F.check("no crash", not F.reportCrash("end"))
  F.finish()
end)
