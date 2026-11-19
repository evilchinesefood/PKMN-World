-- The Pokedex area page must mark the same Johto places before and after a battle. Its wild-header
-- region index lived on the heap and was cached across visits; every battle (and field return)
-- re-inits the heap, so the next visit read save-block copies or other allocations through the
-- stale pointer. Johto maps also sit in their own map groups, which the old group switch never
-- matched, so Johto encounters were dropped; they are now classed by map type (0829014ec0).
--
-- On a Johto map with the Pokedex (and so the National Pokedex) and every dex flag set, the suite
-- opens the Pokedex from the Start menu with real input and reads the area page's species and its
-- glow and marker counts for Pidgey (routes) and Zubat (caves). It then wins a wild battle started
-- by setwildbattle/dowildbattle and opens both area pages again: the counts must match the first
-- visit and be non-zero. Then in Viridian City (Kanto) it reads Pidgey's area page, wins another
-- battle and reads it again.
--
-- Run via test/overworld/mgba-run.sh test/overworld/lua/PokedexAreaAfterBattle.lua <rom>

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "PokedexAreaAfterBattle")

local HUB_GROUP = 100
local JOHTO_GATE = { 83, 7 }      -- National Park gate
local KANTO_TOWN = { 37, 1 }      -- Viridian City
local FLAG_SYS_POKEDEX_GET = 0x949
local FLAG_SYS_DEXNAV_GET = 0x948 + 0xBE
local USM_ICO_POKEDEX = 0
local SPECIES_PIDGEY, SPECIES_ZUBAT, SPECIES_MEWTWO = 16, 41, 150
local OFF_SPECIES, OFF_NUM_OVERWORLD, OFF_NUM_SPECIAL = 0x0E, 0x110, 0x112

local function flag(id, on)
  local a, m = F.sb1() + S.SaveBlock1.flags + (id // 8), 1 << (id % 8)
  F.w8(a, on and (F.r8(a) | m) or (F.r8(a) & ~m & 0xFF))
end
local function warp(m, tag)
  local function d(n) return n // 100, (n // 10) % 10, n % 10 end
  local gh, gt, go = d(m[1]); local mh, mt, mo = d(m[2])
  return F.warpTo(gh, gt, go, mh, mt, mo, 0, 0, 0, m[1], m[2], tag)
end
local function digits(n) n = n - 1; return n // 100, (n // 10) % 10, n % 10 end

local function area()
  local p = F.r32(S.sPokedexAreaScreen)
  if p < 0x02000000 or p >= 0x02040000 then return nil end
  return { species = F.r16(p + OFF_SPECIES), glow = F.r16(p + OFF_NUM_OVERWORLD), markers = F.r16(p + OFF_NUM_SPECIAL) }
end

local function backToField()
  for _ = 1, 40 do
    if F.ow() and F.r32(S.sUsmMemory) == 0 then break end
    F.press("B", 2); F.idle(30)
  end
  F.idle(30)
  return F.ensureFree()
end

-- Opens the Pokedex, walks the list from the remembered entry to national number `want` (the list
-- reopens on the last entry viewed), opens the entry and its area page.
local listAt = 1
local function areaFor(want, tag)
  F.press("Start", 2); F.idle(60)
  if not F.selectStartIcon(USM_ICO_POKEDEX) then F.shot(tag .. "_no_dex_icon"); return nil end
  F.press("A", 2); F.idle(150)
  local dir = want > listAt and "Down" or "Up"
  for _ = 1, math.abs(want - listAt) do F.press(dir, 2); F.idle(8) end
  listAt = want
  F.idle(30)
  F.press("A", 2); F.idle(120)        -- the entry's info page
  F.press("Right", 2)
  local a
  for _ = 1, 120 do
    F.idle(4)
    a = area()
    if a and a.species ~= 0 then break end
  end
  F.idle(90)
  a = area()
  F.shot(tag)
  if F.reportCrash(tag) then return nil end
  return a
end

local function fmt(a) if not a then return "nil" end return string.format("species=%d glow=%d markers=%d", a.species, a.glow, a.markers) end

-- Script bytes run from the tail of gStringVar4, which no message reaches.
local SCRIPT_BUF = S.gStringVar4 + 960
local function runScript(b)
  for i, v in ipairs(b) do F.w8(SCRIPT_BUF + i - 1, v) end
  F.w8(S.sGlobalScriptContext, 0)
  F.w8(S.sGlobalScriptContext + 1, 1)
  F.w32(S.sGlobalScriptContext + 4, 0)
  F.w32(S.sGlobalScriptContext + S.ScriptCtx.scriptPtr, SCRIPT_BUF)
  F.w8(S.sGlobalScriptContextStatus, 0)
end
local function inBattle() return F.cb2() == (S.BattleMainCB2 & ~1) end

-- Move 1 becomes Psychic so a pure-A driver knocks the Pidgey out on the first turn.
local SUB1 = { [0]=1,1,2,3,2,3,0,0,0,0,0,0,2,3,1,1,3,2,2,3,1,1,3,2 }
local function setMove1(move)
  local mon = S.gParties
  local key = F.r32(mon) ~ F.r32(mon + 4)
  local function x() for i = 0, 11 do local a = mon + 32 + i * 4; F.w32(a, F.r32(a) ~ key) end end
  x()
  local sub = mon + 32 + SUB1[F.r32(mon) % 24] * 12
  F.w16(sub, (F.r16(sub) & 0xF800) | move)
  F.w8(sub + 8, (F.r8(sub + 8) & 0x80) | 10)
  local sum = 0
  for i = 0, 11 do local w = F.r32(mon + 32 + i * 4); sum = (sum + w + (w >> 16)) & 0xFFFFFFFF end
  F.w16(mon + 28, sum & 0xFFFF)
  x()
end

local function winWildBattle()
  local w = { 0xB6, SPECIES_PIDGEY & 0xFF, SPECIES_PIDGEY >> 8, 3, 0, 0, 0, 0, 0, 0, 0, 0xB7, 0x02 }
  runScript(w)
  local started = false
  for _ = 1, 1500 do F.idle(1); if inBattle() and F.battlers() >= 2 then started = true; break end end
  if not started then return false end
  local outcome = 0
  for f = 1, 30000 do
    if inBattle() then
      if F.outcome() ~= 0 then outcome = F.outcome() end
      F.w8(S.gMoveSelectionCursor, 0)
      if f % 12 == 0 then F.press("A", 2) else F.idle(1) end
    elseif F.ow() then
      break
    else
      if f % 20 == 0 then F.press("A", 2) else F.idle(1) end
    end
  end
  F.idle(120)
  return F.ow() and outcome == 1, outcome
end

F.run(function()
  if not F.boot(HUB_GROUP) then F.check("boot to the hub", false); F.finish(); return end
  for off = 0, 6 * S.Pokemon.size - 4, 4 do F.w32(S.gParties + off, 0) end
  F.w8(S.gPartiesCount, 0)
  F.dbg(); F.idle(30); F.bOut(4)
  F.dbg(); F.sel(3); F.sel(1); F.idle(20); F.spin(digits(SPECIES_MEWTWO)); F.idle(20); F.spin(9, 9, 9); F.idle(60); F.bOut(4)
  F.check("setup: a Mewtwo leads", F.r8(S.gPartiesCount) == 1)
  setMove1(94)
  F.dbg(); F.sel(7); F.sel(2); F.idle(60); F.bOut(4)       -- Flags & Vars > Pokedex Flags All
  flag(FLAG_SYS_POKEDEX_GET, true)
  flag(FLAG_SYS_DEXNAV_GET, true)
  -- The warp's field load enables the National Pokedex for a Pokedex holder (ResyncCurrentRegionFromMap).
  F.check("setup: on a Johto map", warp(JOHTO_GATE, "johto"))
  F.ensureFree()

  local p1 = areaFor(SPECIES_PIDGEY, "pidgey_before")
  F.L("  Pidgey before: " .. fmt(p1))
  backToField()
  local z1 = areaFor(SPECIES_ZUBAT, "zubat_before")
  F.L("  Zubat before: " .. fmt(z1))
  backToField()
  F.check("the area pages opened on Pidgey and Zubat", p1 and z1 and p1.species == SPECIES_PIDGEY
    and z1.species == SPECIES_ZUBAT, fmt(p1) .. " / " .. fmt(z1))
  F.check("Johto routes glow for Pidgey", p1 and p1.glow > 0, fmt(p1))
  F.check("Johto caves get markers for Zubat", z1 and z1.markers > 0, fmt(z1))

  local won, outcome = winWildBattle()
  F.check("won a wild battle", won, string.format("outcome=%d", outcome or -1))
  F.ensureFree()

  local p2 = areaFor(SPECIES_PIDGEY, "pidgey_after")
  F.L("  Pidgey after: " .. fmt(p2))
  backToField()
  local z2 = areaFor(SPECIES_ZUBAT, "zubat_after")
  F.L("  Zubat after: " .. fmt(z2))
  backToField()
  F.check("Pidgey's area page is unchanged after the battle", fmt(p2) == fmt(p1), fmt(p1) .. " -> " .. fmt(p2))
  F.check("Zubat's area page is unchanged after the battle", fmt(z2) == fmt(z1), fmt(z1) .. " -> " .. fmt(z2))

  -- Kanto: the index was built on the first visit above, and every field return since re-inited
  -- the heap under it.
  F.check("setup: on a Kanto map", warp(KANTO_TOWN, "kanto"))
  F.ensureFree()
  local k1 = areaFor(SPECIES_PIDGEY, "kanto_pidgey_before")
  F.L("  Kanto Pidgey before: " .. fmt(k1))
  backToField()
  local won2 = winWildBattle()
  F.check("won a second wild battle", won2)
  F.ensureFree()
  local k2 = areaFor(SPECIES_PIDGEY, "kanto_pidgey_after")
  F.L("  Kanto Pidgey after: " .. fmt(k2))
  backToField()
  F.check("Kanto routes glow for Pidgey", k1 and k1.species == SPECIES_PIDGEY and k1.glow > 0, fmt(k1))
  F.check("Kanto Pidgey's area page is unchanged after the battle", fmt(k2) == fmt(k1), fmt(k1) .. " -> " .. fmt(k2))
  F.check("no crash screen", not F.crashScreen())
  F.finish()
end)
