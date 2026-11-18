-- Elm's first directions in the New Bark lab give PROF. BIRCH's number and set
-- FLAG_ENABLE_PROF_BIRCH_MATCH_CALL, so a Johto player meets the PokeNav's PROF. BIRCH contact
-- before ever seeing Hoenn. The contact is Birch's in every region: Elm's line names him, the call is
-- Birch's Pokedex rating, and Emerald's MatchCall_GetMapSec_Birch prints UNKNOWN for him (pokemonHnS
-- renames the contact PROF.ELM but keeps UNKNOWN, since its New Bark map section field is never read).
--
-- The suite plays Elm's directions with a seeded A/B mash, opens the Match Call list from the Start
-- menu in New Bark Town with real input, moves the cursor onto the PROF. BIRCH row, opens its options
-- and calls him. Then it warps to Littleroot Town and does the same. Oracle: the live Match Call menu
-- (the row's header and the map section its location window prints), the location window's drawn
-- pixels, and the call text in gStringVar4. Johto must show exactly what Hoenn shows.
--
-- Knobs: PW_SEED=<n> reseeds the mash, PW_INSTANT=1 sets Instant text.
-- Run via: test/overworld/mgba-run.sh test/overworld/lua/BirchContactRegions.lua <rom.gba>

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "BirchContactRegions")

local FLAG_SYS_POKENAV_GET = 0x94A
local FLAG_ADDED_MATCH_CALL_TO_POKENAV = 0x130
local FLAG_ENABLE_PROF_BIRCH_MATCH_CALL = 0x119
local FLAG_JOHTO_STARTER_CHOSEN = 0x6000 + 0x38
local VAR_NEWBARKTOWN_LABSTATE = 0xA081
local MC_HEADER_PROF_BIRCH = 1
local MAPSEC_NONE = 0x10A
local USM_ICO_POKENAV = 3
local SUBSTRUCT_MATCH_CALL_MAIN, SUBSTRUCT_MATCH_CALL_OPEN = 5, 6
local MC = { numRegistered = 10, initFinished = 16, callback = 24, entries = 28, entrySize = 6, special = 0, mapSec = 2, headerId = 4 }
local GFX_LOC_WINDOW = 16
local CONTEXT_SHUTDOWN = 2
local BUF = S.gStringVar4 + 900

local seed = tonumber(os.getenv("PW_SEED") or "") or 1
local rng = seed
local function rand(n) rng = (rng * 1103515245 + 12345) % 2147483648; return (rng >> 16) % n end

local function where() local x, y = F.pos(); return string.format("%d/%d (%d,%d)", F.grp(), F.mapn(), x, y) end
local function flagAddr(id)
  if id >= 0x6000 and id < 0x6400 then
    local o = id - 0x6000
    return F.sb3() + S.SaveBlock3.johtoFlags + o // 8, 1 << (o % 8)
  end
  return F.sb1() + S.SaveBlock1.flags + id // 8, 1 << (id % 8)
end
local function setFlag(id, on) local a, bit = flagAddr(id); F.w8(a, on == false and (F.r8(a) & ~bit & 0xFF) or (F.r8(a) | bit)) end
local function getFlag(id) local a, bit = flagAddr(id); return (F.r8(a) & bit) ~= 0 end
local function setVar(id, v) F.w16(F.sb3() + S.SaveBlock3.regionVars + (id - 0xA000) * 2, v) end
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
local function warp(g, n, x, y)
  runScript({ 0x39, g, n, 0xFF, x & 0xFF, x >> 8, y & 0xFF, y >> 8, 0x27, 0x02 })
  for _ = 1, 600 do
    F.idle(4)
    local px, py = F.pos()
    if F.grp() == g and F.mapn() == n and px == x and py == y and hasControl() then F.idle(30); return true end
    if F.grp() == g and F.mapn() == n and F.ow() then F.press("B", 2) end
  end
  return false
end

local function decode(addr, max)
  local out = {}
  for i = 0, (max or 300) - 1 do
    local c = F.r8(addr + i)
    if c == 0xFF then break end
    if c == 0x00 or c == 0xFE or c == 0xFA or c == 0xFB then out[#out + 1] = " "
    elseif c >= 0xBB and c <= 0xD4 then out[#out + 1] = string.char(65 + c - 0xBB)
    elseif c >= 0xD5 and c <= 0xEE then out[#out + 1] = string.char(97 + c - 0xD5)
    elseif c >= 0xA1 and c <= 0xAA then out[#out + 1] = string.char(48 + c - 0xA1)
    elseif c == 0xAB then out[#out + 1] = "!"
    elseif c == 0xAD then out[#out + 1] = "."
    elseif c == 0xB0 then out[#out + 1] = "..."
    elseif c == 0xB4 then out[#out + 1] = "'"
    elseif c == 0xB8 then out[#out + 1] = ","
    elseif c == 0xF0 then out[#out + 1] = ":"
    else out[#out + 1] = "?" end
  end
  return table.concat(out)
end

local function substruct(id)
  local res = F.r32(S.gPokenavResources)
  if res < 0x02000000 or res >= 0x02040000 then return nil end
  local p = F.r32(res + 16 + id * 4)
  if p < 0x02000000 or p >= 0x02040000 then return nil end
  return p
end
local function listReady()
  local p = substruct(SUBSTRUCT_MATCH_CALL_MAIN)
  return p and F.r32(p + MC.initFinished) ~= 0 and (F.r32(p + MC.callback) & ~1) == (S.CB2_HandleMatchCallInput & ~1)
end

-- FNV-1a over the location window's pixel buffer: the drawn map name, as the player sees it.
local function locationPixels()
  local gfx = substruct(SUBSTRUCT_MATCH_CALL_OPEN)
  if not gfx then return nil end
  local w = S.gWindows + F.r16(gfx + GFX_LOC_WINDOW) * 12
  local tiles = F.r32(w + 8)
  local size = F.r8(w + 3) * F.r8(w + 4) * 32
  local h = 2166136261
  for i = 0, size - 1 do h = ((h ~ F.r8(tiles + i)) * 16777619) & 0xFFFFFFFF end
  return string.format("%08X/%d", h, size)
end

local function openMatchCall(tag)
  for _ = 1, 10 do if hasControl() then break end F.press("B", 2); F.idle(20) end
  local offered = false
  for _ = 1, 3 do
    F.press("Start", 2); F.idle(60)
    offered = F.selectStartIcon(USM_ICO_POKENAV)
    if offered then break end
    for _ = 1, 4 do F.press("B", 2); F.idle(30) end
  end
  if not F.check(tag .. ": the Start menu offers the PokeNav", offered) then return false end
  F.press("A", 2); F.idle(240)
  F.press("Down", 2); F.idle(20); F.press("Down", 2); F.idle(20)
  F.press("A", 2)
  for _ = 1, 300 do if listReady() then break end F.idle(1) end
  F.idle(60)
  return F.check(tag .. ": the Match Call list opened", listReady(), where())
end

local function closePokenav(tag)
  for _ = 1, 10 do if F.ow() then break end F.press("B", 2); F.idle(90) end
  for _ = 1, 10 do if F.ensureFree() then break end F.press("B", 2); F.idle(20) end
  local free = F.ow() and F.ensureFree()
  if not free then F.shot(tag .. "_stuck") end
  F.check(tag .. ": back on the field and walkable", free, string.format("%s lock=%d ctx=%d", where(),
    F.r8(S.sLockFieldControls), F.r8(S.sGlobalScriptContextStatus)))
end

-- Moves the cursor onto PROF. BIRCH with real input and reads what the list shows for him.
local function viewBirch(tag)
  local p = substruct(SUBSTRUCT_MATCH_CALL_MAIN)
  local n = F.r16(p + MC.numRegistered)
  local row
  for i = 0, n - 1 do
    local e = p + MC.entries + i * MC.entrySize
    if F.r8(e + MC.special) ~= 0 and F.r16(e + MC.headerId) == MC_HEADER_PROF_BIRCH then row = i end
  end
  if not F.check(tag .. ": the list holds PROF. BIRCH", row ~= nil, n .. " contacts") then return nil end
  for _ = 1, row do F.press("Down", 2); F.idle(30) end
  F.idle(30)
  local e = p + MC.entries + row * MC.entrySize
  local seen = { row = row, count = n, mapSec = F.r16(e + MC.mapSec), pixels = locationPixels() }
  F.shot(tag .. "_list")
  F.press("A", 2); F.idle(60)
  F.shot(tag .. "_options")
  F.w8(S.gStringVar4, 0xFF)
  F.press("A", 2)
  for t = 1, 900 do
    if F.r8(S.gStringVar4) ~= 0xFF then break end
    if t % 40 == 0 then F.press("A", 2) else F.idle(1) end
  end
  seen.text = decode(S.gStringVar4)
  F.idle(90)
  F.shot(tag .. "_call")
  for _ = 1, 40 do
    if listReady() then break end
    F.press("A", 2); F.idle(40)
  end
  F.check(tag .. ": the call ends back on the list", listReady())
  F.L(string.format("  %s: row %d of %d, mapSec 0x%02X, location pixels %s, call: %s", tag, row, n, seen.mapSec,
    tostring(seen.pixels), seen.text))
  return seen
end

F.run(function()
  assert(F.boot(100), "boot")
  F.L("seed " .. seed)
  if os.getenv("PW_INSTANT") == "1" then
    local a = F.sb2() + S.SaveBlock2.optionsU16
    F.w16(a, (F.r16(a) & ~7) | 3)
  end
  setFlag(FLAG_SYS_POKENAV_GET); setFlag(FLAG_ADDED_MATCH_CALL_TO_POKENAV); setFlag(FLAG_JOHTO_STARTER_CHOSEN)
  setFlag(FLAG_ENABLE_PROF_BIRCH_MATCH_CALL, false)
  setVar(VAR_NEWBARKTOWN_LABSTATE, 1)

  local johto, hoenn
  if F.check("in front of Elm after the starter", warp(76, 0, 6, 4), where()) then
    F.face("Up")
    F.press("A", 2)
    local f = 0
    while f < 6000 do
      if f % 8 == 0 and F.reportCrash("elm") then break end
      if f > 120 and hasControl() then break end
      local k = rand(10)
      joypad.set(f % 6 < 2 and (k == 0 and { B = true } or k < 4 and { A = true } or {}) or {})
      emu.frameadvance(); f = f + 1
    end
    joypad.set({})
    F.check("Elm's directions register PROF. BIRCH", getFlag(FLAG_ENABLE_PROF_BIRCH_MATCH_CALL))
    F.check("control returned after Elm's directions", hasControl() and F.ensureFree(), where())
  end
  if F.check("out in New Bark Town", warp(75, 0, 12, 13), where()) and openMatchCall("johto") then
    johto = viewBirch("johto")
    closePokenav("johto")
  end
  if F.check("out in Littleroot Town", warp(0, 9, 10, 10), where()) and openMatchCall("hoenn") then
    hoenn = viewBirch("hoenn")
    closePokenav("hoenn")
  end
  if johto and hoenn then
    F.check("Hoenn's PROF. BIRCH call is his Pokedex rating", hoenn.text:sub(1, 12) == "PROF. BIRCH:", hoenn.text)
    F.check("Johto's call is the same PROF. BIRCH rating", johto.text == hoenn.text, johto.text)
    F.check("Johto's location window prints Hoenn's map section",
      johto.mapSec == hoenn.mapSec, string.format("0x%02X vs 0x%02X", johto.mapSec, hoenn.mapSec))
    F.check("Johto's location window draws the same pixels as Hoenn's",
      johto.pixels ~= nil and johto.pixels == hoenn.pixels, tostring(johto.pixels) .. " vs " .. tostring(hoenn.pixels))
    F.L(string.format("  MAPSEC_NONE (UNKNOWN) is 0x%02X; Johto 0x%02X, Hoenn 0x%02X", MAPSEC_NONE, johto.mapSec, hoenn.mapSec))
  end
  F.finish()
end)
