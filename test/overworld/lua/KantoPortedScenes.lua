-- Kanto scenes whose pokefirered scripts name something that means another thing in this tree.
--
-- The Viridian school whiteboard branches Sleep, Poison, Paralysis, Burn, Freeze on FRLG's rows (SLP
-- first), but showed this tree's MULTI_STATUS_INFO (Rustboro's list, PSN first): the cell labelled PSN
-- explained sleep and the one labelled SLP explained paralysis.
--
-- MUS_FOLLOW_ME and MUS_POKE_CENTER are Emerald's songs here; FRLG's are MUS_RG_FOLLOW_ME and
-- MUS_RG_POKE_CENTER. So the Pewter gym guide led the way to Hoenn's guide theme, and Jigglypuff's song
-- in the Pewter Pokemon Center gave way to Hoenn's Pokemon Center theme instead of the Center's own.
--
-- The Route 12 fishing guru's brother branches not-a-Magikarp, smaller, new record and tie (1-4) on
-- FRLG's CompareMagikarpSize, but this tree's returned Emerald's three results, counting a tie as
-- smaller. Shown the record Magikarp again he said it "doesn't measure up" to itself.
--
-- Setup is warps and, for the brother, a party of one Magikarp; the whiteboard grid, the talks, the
-- Super Rod's YES and the party menu run on real input. Whiteboard cells are picked by
-- the label the grid shows (read from the list the script passes) and checked against the line it
-- prints.
--
-- Run via test/overworld/mgba-run.sh test/overworld/lua/KantoPortedScenes.lua <rom.gba>

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "KantoPortedScenes")

local CONTEXT_SHUTDOWN = 2
local MUS_FOLLOW_ME, MUS_RG_FOLLOW_ME = 420, 484
local MUS_POKE_CENTER, MUS_RG_POKE_CENTER = 400, 515
local MUS_RG_JIGGLYPUFF = 488
local SCHOOL = { 39, 2, 4, 2, "Up" }
local GYM_GUIDE = { 37, 2, 41, 20, "Right" }
local JIGGLYPUFF = { 40, 5, 2, 3, "Up" }
local FISHING_BROTHER = { 57, 2, 4, 5, "Up" }
local SPECIES_MAGIKARP = 129
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

local function warp(at)
  local g, n, x, y = at[1], at[2], at[3], at[4]
  runScript({ 0x39, g, n, 0xFF, x & 0xFF, x >> 8, y & 0xFF, y >> 8, 0x27, 0x02 })
  for _ = 1, 600 do
    F.idle(4)
    local px, py = F.pos()
    if F.grp() == at[1] and F.mapn() == at[2] and px == at[3] and py == at[4] and hasControl() then F.idle(30); return true end
  end
  return false
end

local function playingSong(player)
  local hdr = F.r32(player or S.gMPlayInfo_BGM)
  if hdr == 0 then return 0 end
  for id = 0, 900 do
    if F.r32(S.gSongTable + id * 8) == hdr then return id end
  end
  return -1
end

local CH = {}
for i = 0, 9 do CH[0xA1 + i] = string.char(48 + i) end
for i = 0, 25 do CH[0xBB + i] = string.char(65 + i); CH[0xD5 + i] = string.char(97 + i) end
CH[0x00] = " "; CH[0xFE] = " "; CH[0xFA] = " "; CH[0xFB] = " "
local function decode(ptr, max)
  local s = {}
  for i = 0, max do
    local c = F.r8(ptr + i)
    if c == 0xFF then break end
    s[#s + 1] = CH[c] or "?"
  end
  return table.concat(s)
end

-- The grid the whiteboard script draws: its multichoicegrid's list id is the byte after message (5),
-- waitmessage (1), the opcode and x, y (3).
local function boardLabels()
  local id = F.r8(S.ViridianCity_School_EventScript_ChooseBlackboardTopic + 9)
  local list, count = F.r32(S.sMultichoiceLists + id * 8), F.r8(S.sMultichoiceLists + id * 8 + 4)
  local labels = {}
  for row = 0, count - 1 do labels[row] = decode(F.r32(list + row * 8), 20) end
  return labels, count
end
local function gridOpen() return F.taskLive(S.Task_HandleMultichoiceGridInput) end

-- Talk to the board, pick the cell labelled `want` and return the line it prints.
local function readBoard(want, keyword)
  local tag = "board_" .. want:lower()
  if not F.check(tag .. ": stand at the whiteboard", warp(SCHOOL)) then return end
  F.face(SCHOOL[5])
  F.press("A", 2)
  local opened = false
  for i = 1, 1500 do
    if gridOpen() then opened = true; break end
    joypad.set((i % 24 == 0) and { A = true } or {})
    emu.frameadvance()
  end
  if not F.check(tag .. ": the topic grid opens", opened, "") then return end
  F.idle(30)
  local labels, count = boardLabels()
  local listed, cell = {}, nil
  for r = 0, count - 1 do
    listed[#listed + 1] = labels[r]
    if labels[r] == want then cell = r end
  end
  F.L("  " .. tag .. ": grid cells " .. table.concat(listed, " | "))
  F.shot(tag .. "_grid")
  if not F.check(tag .. ": the grid has a " .. want .. " cell", cell ~= nil, "") then return end
  for _ = 1, cell % 3 do F.press("Right", 2); F.idle(8) end
  for _ = 1, cell // 3 do F.press("Down", 2); F.idle(8) end
  F.check(tag .. ": cursor on the " .. want .. " cell", F.mcur() == cell, "cursor=" .. F.mcur() .. " want=" .. cell)
  F.w8(S.gStringVar4, 0xFF)
  F.press("A", 2)
  F.idle(90)
  local line = decode(S.gStringVar4, 120)
  F.shot(tag .. "_line")
  F.L("  " .. tag .. ": board says \"" .. line .. "\"")
  F.check(tag .. ": the " .. want .. " cell explains " .. keyword, line:find(keyword, 1, true) ~= nil, line)
  for i = 1, 1500 do
    if gridOpen() then break end
    joypad.set((i % 24 == 0) and { A = true } or {})
    emu.frameadvance()
  end
  F.idle(20)
  F.press("B", 2)
  for i = 1, 600 do
    if i > 30 and hasControl() then break end
    joypad.set((i % 24 == 0) and { B = true } or {})
    emu.frameadvance()
  end
  F.check(tag .. ": control returns", hasControl(), "")
end

-- Talk to an NPC and A through the scene, noting every song that plays until control returns.
local function songsDuring(tag, at)
  local seen, order = {}, {}
  if not F.check(tag .. ": stand before the NPC", warp(at)) then return seen, order end
  F.face(at[5])
  F.press("A", 2)
  for i = 1, 6000 do
    if i > 60 and hasControl() then break end
    for _, s in ipairs({ playingSong(), playingSong(S.gMPlayInfo_SE2) }) do
      if not seen[s] then seen[s] = true; order[#order + 1] = s end
    end
    joypad.set((i % 30 == 0) and { A = true } or {})
    emu.frameadvance()
  end
  F.idle(60)
  local s = playingSong()
  if not seen[s] then seen[s] = true; order[#order + 1] = s end
  F.L("  " .. tag .. ": songs " .. table.concat(order, " > "))
  F.shot(tag)
  F.check(tag .. ": control returns", hasControl(), "")
  return seen, order
end

local function createMagikarp()
  for o = 0, S.Pokemon.size - 4, 4 do F.w32(S.gParties + o, 0) end
  F.w8(S.gPartiesCount, 0)
  local b = { 0x23 }
  local fn = S.ScrCmd_createmon | 1
  for k = 0, 3 do b[#b + 1] = (fn >> (8 * k)) & 0xFF end
  for _, v in ipairs({ 0, 6, SPECIES_MAGIKARP & 0xFF, SPECIES_MAGIKARP >> 8, 20, 0, 0, 0, 0, 0, 0x02 }) do b[#b + 1] = v end
  runScript(b)
  settle()
end

-- Talk and A through to the end (the YES at a Yes/No, the first Pokemon at a party menu), returning
-- every line the field message box printed.
local function talkLines(tag, at)
  local lines, seenLine = {}, {}
  if not F.check(tag .. ": stand before the NPC", warp(at)) then return lines end
  F.face(at[5])
  F.press("A", 2)
  for i = 1, 6000 do
    if i > 60 and hasControl() then break end
    local line = decode(S.gStringVar4, 120)
    if line ~= "" and not seenLine[line] then seenLine[line] = true; lines[#lines + 1] = line end
    joypad.set((i % 30 == 0) and { A = true } or {})
    emu.frameadvance()
  end
  F.shot(tag)
  for _, l in ipairs(lines) do F.L("  " .. tag .. ": \"" .. l .. "\"") end
  F.check(tag .. ": control returns", hasControl(), "")
  return lines
end
local function said(lines, text)
  for _, l in ipairs(lines) do if l:find(text, 1, true) then return true end end
  return false
end

F.run(function()
  if not F.boot(100) then F.check("boot", false); F.finish(); return end

  readBoard("PSN", "poisoned")
  readBoard("SLP", "asleep")
  readBoard("PAR", "Paralysis")

  local seen = songsDuring("gym_guide", GYM_GUIDE)
  F.check("gym_guide: the walk to the gym plays FRLG's guide theme", seen[MUS_RG_FOLLOW_ME] == true, "")
  F.check("gym_guide: Emerald's guide theme never plays", not seen[MUS_FOLLOW_ME], "")

  seen = songsDuring("jigglypuff", JIGGLYPUFF)
  F.check("jigglypuff: Jigglypuff sings", seen[MUS_RG_JIGGLYPUFF] == true, "")
  F.check("jigglypuff: the Center's FRLG theme comes back afterwards", playingSong() == MUS_RG_POKE_CENTER,
    "song=" .. playingSong())
  F.check("jigglypuff: Emerald's Pokemon Center theme never plays", not seen[MUS_POKE_CENTER], "")

  createMagikarp()
  F.check("fishing: a lone Magikarp in the party", F.r8(S.gPartiesCount) == 1, "count=" .. F.r8(S.gPartiesCount))
  local lines = talkLines("fishing_rod", FISHING_BROTHER)
  F.check("fishing_rod: YES to fishing gets the Super Rod", said(lines, "Take this and fish"), "")
  lines = talkLines("fishing_first", FISHING_BROTHER)
  F.check("fishing_first: the first Magikarp shown sets the record", said(lines, "Whoa"), "")
  lines = talkLines("fishing_again", FISHING_BROTHER)
  F.check("fishing_again: the record Magikarp shown again is the same size", said(lines, "same size"), "")
  F.check("fishing_again: it is not said to fall short of itself", not said(lines, "measure up"), "")
  F.check("no crash screen", not F.crashScreen(), tostring(F.crashScreen()))
  F.finish()
end)
