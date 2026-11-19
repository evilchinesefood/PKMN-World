-- Link-era remnants a player can still reach, each driven through its real trigger.
--
-- Johto gym signs: the floor tile in front of the Olivine, Cianwood, Mahogany and Blackthorn gym
-- signs carried the Cable Club's MB_CABLE_BOX_RESULTS_1 behaviour, so pressing A at it opened the
-- LINK BATTLE RESULTS table. The player walks up to the tile (facing it) and presses A, then steps
-- onto it and reads the sign behind it as the positive control.
-- Frontier Maniac (Battle Frontier Lounge 2): his daily rotation names one Battle Tower mode or
-- facility per day. Each day here is a real UpdatePerDay on map load (VAR_DAYS one behind the
-- clock), then the player talks to him. No day may send the player to the sealed LINK MULTI
-- BATTLE ROOM, and the rotation must still reach every other mode.
-- Route 114 berry man: his daily berry still comes, and his lines no longer send the player to the
-- retired BERRY CRUSH machine.
-- Records boards kept for the retired minigames and link modes (Pokemon Jump and Dodrio Berry
-- Picking at Mossdeep, the Berry Crush rankings at Slateport and Cerulean, the Lilycove blender
-- speed and link contest boards): each opens from its sign and closes again.
-- Every talk must hand control back with the field walkable and no crash screen.
--
-- PW_SEED=<n> reseeds the mash (default 1). PW_TEXT=instant|fast|mid picks the text speed
-- (default instant).
-- Run via test/overworld/mgba-run.sh test/overworld/lua/LinkEraRemnants.lua

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "LinkEraRemnants")

local BASE = tonumber(os.getenv("PW_SEED")) or 1
local SPEEDS = { mid = 1, fast = 2, instant = 3 }
local TEXT_SPEED = SPEEDS[os.getenv("PW_TEXT") or "instant"] or 3
local CONTEXT_RUNNING = 0
local BUF = S.gStringVar4 + 900
local FLAG_SYS_CLOCK_SET = 0x948 + 0x35
local VAR_FRONTIER_MANIAC_FACILITY = 0x402F
local VAR_DAYS = 0x4040
local FRONTIER_MANIAC_TOWER_LINK = 3
local FACILITY_COUNT = 10

local seed = BASE
local function rnd(n)
  seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF
  return (seed >> 8) % n
end
local function reseed(tag)
  local h = BASE & 0x7FFFFFFF
  for i = 1, #tag do h = ((h ~ tag:byte(i)) * 16777619) & 0x7FFFFFFF end
  seed = h
  F.L(string.format("== %s == seed=%d", tag, seed))
end

local function flagAddr(id) return F.sb1() + S.SaveBlock1.flags + id // 8, id % 8 end
local function flag(id, on)
  local a, b = flagAddr(id)
  F.w8(a, on and (F.r8(a) | (1 << b)) or (F.r8(a) & (~(1 << b) & 0xFF)))
end
local function varAddr(id) return F.sb1() + S.SaveBlock1.vars + (id - 0x4000) * 2 end
local function varGet(id) return F.r16(varAddr(id)) end
local function varSet(id, v) F.w16(varAddr(id), v) end

local function hasControl()
  return F.ow() and F.r8(S.sLockFieldControls) == 0 and F.r8(S.sGlobalScriptContextStatus) ~= CONTEXT_RUNNING
end
local function runScript(bytes)
  for i, v in ipairs(bytes) do F.w8(BUF + i - 1, v) end
  F.w8(S.sGlobalScriptContext, 0)
  F.w8(S.sGlobalScriptContext + 1, 1)
  F.w32(S.sGlobalScriptContext + 4, 0)
  F.w32(S.sGlobalScriptContext + S.ScriptCtx.scriptPtr, BUF)
  F.w8(S.sGlobalScriptContextStatus, 0)
end

local CH = { [0x00] = " ", [0x1B] = "e", [0xAB] = "!", [0xAC] = "?", [0xAD] = ".", [0xAE] = "-", [0xB0] = "...",
  [0xB4] = "'", [0xB8] = ",", [0xFA] = " ", [0xFB] = " ", [0xFE] = " " }
for i = 0, 25 do CH[0xBB + i] = string.char(65 + i); CH[0xD5 + i] = string.char(97 + i) end
for i = 0, 9 do CH[0xA1 + i] = string.char(48 + i) end
local function shownText()
  local s = {}
  for i = 0, 399 do
    local c = F.r8(S.gStringVar4 + i)
    if c == 0xFF then break end
    s[#s + 1] = CH[c] or "~"
  end
  return table.concat(s)
end

local Seen = { all = {} }
local function noteText()
  local t = shownText()
  if t ~= "" and t ~= Seen.last then Seen.last = t; Seen.all[#Seen.all + 1] = t end
end
local function heard() return table.concat(Seen.all, " | ") end
local function frame(keys) joypad.set(keys or {}); emu.frameadvance(); noteText() end

local function mashOut(tag)
  for i = 1, 4000 do
    local r = rnd(10)
    if hasControl() then frame()
    elseif r == 0 then frame({ A = true }) elseif r == 1 then frame({ B = true }) else frame() end
    if i == 30 then F.shot(tag) end
    if i > 60 and hasControl() then
      for _ = 1, 30 do frame() end
      if hasControl() then return true end
    end
    if i % 500 == 0 and F.reportCrash(tag) then return false end
  end
  return false
end

local function warp(g, n, x, y)
  runScript({ 0x39, g, n, 0xFF, x & 0xFF, x >> 8, y & 0xFF, y >> 8, 0x27, 0x02 })
  for _ = 1, 600 do
    F.idle(4)
    local px, py = F.pos()
    if F.grp() == g and F.mapn() == n and px == x and py == y and hasControl() then F.idle(30); return true end
  end
  if mashOut(string.format("warp_%d_%d", g, n)) then
    local px, py = F.pos()
    return F.grp() == g and F.mapn() == n and px == x and py == y
  end
  return false
end

-- Presses A at whatever the player faces and mashes until control returns. Returns whether a
-- script ran at all and whether control came back.
local function pressA(tag)
  Seen.all, Seen.last = {}, nil
  F.w8(S.gStringVar4, 0xFF)
  reseed(tag)
  frame({ A = true }); frame({ A = true })
  local ran = false
  for _ = 1, 60 do
    if not hasControl() then ran = true; break end
    frame()
  end
  if not ran then return false, true end
  for _ = 1, 20 do frame() end
  F.shot(tag .. "_open")
  return true, mashOut(tag)
end

local function has(s, ...) for _, w in ipairs({ ... }) do if not s:find(w, 1, true) then return false end end return true end
local function lacks(s, ...) for _, w in ipairs({ ... }) do if s:find(w, 1, true) then return false end end return true end
local BACK = { Down = "Up", Up = "Down", Left = "Right", Right = "Left" }
local function walkable(tag)
  if F.reportCrash(tag) then return false end
  for _, dir in ipairs({ "Down", "Left", "Right", "Up" }) do
    if F.step(dir) then F.step(BACK[dir]); return true end
  end
  return false
end

-- The tile in front of each gym sign (x, y); the sign is the tile north of it.
local SIGNS = {
  { name = "olivine", g = 87, n = 0, x = 13, y = 28, sign = "OLIVINE" },
  { name = "cianwood", g = 89, n = 0, x = 17, y = 45, sign = "CIANWOOD" },
  { name = "mahogany", g = 91, n = 0, x = 12, y = 20, sign = "MAHOGANY" },
  { name = "blackthorn", g = 93, n = 0, x = 26, y = 27, sign = "BLACKTHORN" },
}

local function gymSign(t)
  local tag = "sign_" .. t.name
  if not F.check(tag .. ": two tiles south of the sign", warp(t.g, t.n, t.x, t.y + 2)) then return end
  F.check(tag .. ": walked up to the floor tile", F.step("Up"))
  local ran, back = pressA(tag .. "_floor")
  F.check(tag .. ": A at the floor tile hands control back", back)
  F.check(tag .. ": A at the floor tile opens no LINK BATTLE RESULTS table",
    lacks(heard(), "BATTLE RESULTS", "WIN", "LOSE", "DRAW"), heard())
  F.L(string.format("%s: floor tile ran a script=%s", tag, tostring(ran)))
  F.check(tag .. ": stepped onto the floor tile", F.step("Up"))
  local _, back2 = pressA(tag .. "_sign")
  F.check(tag .. ": the gym sign reads and hands control back", back2 and has(heard(), t.sign), heard())
  F.check(tag .. ": the field is walkable", walkable(tag))
end

local function frontierManiac()
  -- Prime the clock the way the bedroom wall clock leaves it: set, with VAR_DAYS caught up.
  flag(FLAG_SYS_CLOCK_SET, true)
  if not F.check("maniac: in Battle Frontier Lounge 2", warp(26, 43, 8, 6)) then return end
  local today = varGet(VAR_DAYS)
  F.L(string.format("maniac: VAR_DAYS after priming = %d", today))
  F.check("maniac: the clock is running (VAR_DAYS set)", today ~= 0)
  varSet(VAR_FRONTIER_MANIAC_FACILITY, 2)
  local visited, linkDays = {}, {}
  for day = 1, FACILITY_COUNT - 1 do
    varSet(VAR_DAYS, (varGet(VAR_DAYS) - 1) & 0xFFFF)
    if not F.check("maniac: day " .. day .. " back in Lounge 2", warp(26, 43, 8, 6)) then return end
    local facility = varGet(VAR_FRONTIER_MANIAC_FACILITY)
    F.check("maniac: day " .. day .. " ran the daily update", varGet(VAR_DAYS) == today, varGet(VAR_DAYS))
    visited[facility] = true
    F.check("maniac: day " .. day .. " walked up to him", F.step("Up"))
    local _, back = pressA("maniac_day" .. day)
    F.check("maniac: day " .. day .. " hands control back", back)
    F.check("maniac: day " .. day .. " gave his advice", has(heard(), "Let's see now") or has(heard(), "hottest"), heard())
    F.L(string.format("maniac: day %d facility=%d heard=%s", day, facility, heard()))
    if facility == FRONTIER_MANIAC_TOWER_LINK or not lacks(heard(), "MULTI-LINK", "LINK MULTI") then
      linkDays[#linkDays + 1] = day
    end
    F.check("maniac: day " .. day .. " names no LINK MULTI BATTLE ROOM",
      facility ~= FRONTIER_MANIAC_TOWER_LINK and lacks(heard(), "MULTI-LINK", "LINK MULTI"), heard())
  end
  local missing = {}
  for f = 0, FACILITY_COUNT - 1 do
    if f ~= FRONTIER_MANIAC_TOWER_LINK and not visited[f] then missing[#missing + 1] = f end
  end
  F.check("maniac: nine days visit every mode but LINK MULTI", #missing == 0 and #linkDays == 0,
    "missing=" .. table.concat(missing, ",") .. " link days=" .. table.concat(linkDays, ","))
  F.check("maniac: the field is walkable", walkable("maniac"))
end

local function berryMan()
  if not F.check("route114: beside the berry man", warp(0, 29, 26, 42)) then return end
  local got
  for attempt = 1, 12 do
    local man
    for _, o in ipairs(F.objdump()) do
      if o.x == 27 and o.y >= 41 and o.y <= 43 then man = o end
    end
    if man and warp(0, 29, 26, man.y) then
      F.face("Right")
      local ran, back = pressA("route114_" .. attempt)
      if ran then
        got = back
        break
      end
    end
    F.idle(30)
  end
  F.check("route114: the berry man talks and hands control back", got)
  F.check("route114: he shares a berry", has(heard(), "BERR"), heard())
  F.check("route114: no line sends the player to the BERRY CRUSH", lacks(heard(), "BERRY CRUSH"), heard())
  F.check("route114: the field is walkable", walkable("route114"))
end

local BOARDS = {
  { name = "mossdeep_dodrio", g = 14, n = 11, x = 0, y = 1 },
  { name = "mossdeep_jump", g = 14, n = 11, x = 1, y = 1 },
  { name = "slateport_crush", g = 0, n = 1, x = 10, y = 36 },
  { name = "cerulean_crush", g = 41, n = 4, x = 3, y = 1 },
  { name = "lilycove_blender", g = 13, n = 4, x = 30, y = 1 },
  { name = "lilycove_link_contest", g = 13, n = 4, x = 18, y = 3 },
}

local function recordsBoard(b)
  local tag = "board_" .. b.name
  if not F.check(tag .. ": below the board", warp(b.g, b.n, b.x, b.y + 1)) then return end
  F.face("Up")
  local ran, back = pressA(tag)
  F.check(tag .. ": the board opens", ran)
  F.check(tag .. ": the board closes and hands control back", back)
  F.check(tag .. ": the field is walkable", walkable(tag))
end

F.run(function()
  if not F.boot(100) then F.check("boot", false); F.finish(); return end
  F.w16(F.sb2() + S.SaveBlock2.optionsU16, (F.r16(F.sb2() + S.SaveBlock2.optionsU16) & ~7) | TEXT_SPEED)
  F.L(string.format("PW_SEED=%d text=%d", BASE, TEXT_SPEED))
  for _, t in ipairs(SIGNS) do gymSign(t) end
  frontierManiac()
  berryMan()
  for _, b in ipairs(BOARDS) do recordsBoard(b) end
  F.check("no crash screen", not F.reportCrash("end"))
  F.finish()
end)
