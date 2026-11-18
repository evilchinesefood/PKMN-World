-- Warden Baoba's Route 39 scene ends "{PLAYER} registered BAOBA in the POKéNAV!" and sets
-- FLAG_ENABLE_BAOBA_MATCH_CALL, but the PokeNav (Johto's PokeGear) had no contact for him, so the
-- player could neither see nor call the number they were just given. pokemonHnS defines that
-- contact (an NPC Match Call header gated on the flag, "SAFARI WARDEN", two call lines).
--
-- The suite gives the PokeGear with Match Call, Elm's contact (PROF. BIRCH's flag, which Elm's lab
-- sets) and MOM's, warps to Route 39 and opens the Match Call list from the Start menu with real
-- input. Then it walks into the shadow trigger and plays Baoba's scene with a seeded mash of A, B
-- and Down (B at the Gold/Silver choice asks again), opens the list again and calls every contact. Oracle: the list read from the live Match Call menu, and each
-- call's text from gStringVar4. Before the scene there is no BAOBA; after it there is exactly one,
-- his call says the Safari Zone is nearly ready, and once Ampharos is healed it says the Safari
-- Zone is open. Elm's and MOM's entries must still be there and still answer.
--
-- Knobs: PW_SEED=<n> reseeds the mash, PW_INSTANT=1 sets Instant text.
-- Run via: test/overworld/mgba-run.sh test/overworld/lua/BaobaMatchCall.lua <rom.gba>

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "BaobaMatchCall")

local ROUTE39 = { 85, 2 }
local FLAG_SYS_POKENAV_GET = 0x94A
local FLAG_ADDED_MATCH_CALL_TO_POKENAV = 0x130
local FLAG_ENABLE_PROF_BIRCH_MATCH_CALL = 0x119
local FLAG_ENABLE_MOM_MATCH_CALL = 0xD8
local FLAG_TRAINER_NORMAN = 0x500 + 940
local FLAG_ENABLE_BAOBA_MATCH_CALL = 0x6000 + 0xF0
local FLAG_AMPHAROS_HEALED = 0x6000 + 0xEB
local VAR_LUGIA_OR_HOOH = 0xA080 + 0x10
local USM_ICO_POKENAV = 3
local SUBSTRUCT_MATCH_CALL_MAIN = 5
local MC = { numRegistered = 10, initFinished = 16, callback = 24, entries = 28, entrySize = 8, special = 0, headerId = 4 }
local CONTEXT_SHUTDOWN = 2

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
local function setFlag(id) local a, bit = flagAddr(id); F.w8(a, F.r8(a) | bit) end
local function getFlag(id) local a, bit = flagAddr(id); return (F.r8(a) & bit) ~= 0 end
local function getVar(id) return F.r16(F.sb3() + S.SaveBlock3.regionVars + (id - 0xA000) * 2) end
local function hasControl()
  return F.ow() and F.r8(S.sLockFieldControls) == 0 and F.r8(S.sGlobalScriptContextStatus) == CONTEXT_SHUTDOWN
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

local function matchCallMenu()
  local res = F.r32(S.gPokenavResources)
  if res < 0x02000000 or res >= 0x02040000 then return nil end
  local p = F.r32(res + 16 + SUBSTRUCT_MATCH_CALL_MAIN * 4)
  if p < 0x02000000 or p >= 0x02040000 then return nil end
  return p
end
local function listReady()
  local p = matchCallMenu()
  return p and F.r32(p + MC.initFinished) ~= 0 and (F.r32(p + MC.callback) & ~1) == (S.CB2_HandleMatchCallInput & ~1)
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

-- Calls every listed contact with real input, top to bottom. Returns { {header, special, text} }.
local function callAll(tag)
  local p = matchCallMenu()
  local n = F.r16(p + MC.numRegistered)
  F.L(string.format("  %s: %d contacts", tag, n))
  F.shot(tag .. "_list")
  local got = {}
  for i = 0, n - 1 do
    local e = p + MC.entries + i * MC.entrySize
    local row = { header = F.r16(e + MC.headerId), special = F.r8(e + MC.special) ~= 0 }
    F.w8(S.gStringVar4, 0xFF)
    F.press("A", 2); F.idle(30)
    F.press("A", 2)
    for t = 1, 900 do
      if F.r8(S.gStringVar4) ~= 0xFF then break end
      if t % 40 == 0 then F.press("A", 2) else F.idle(1) end
    end
    row.text = decode(S.gStringVar4)
    F.idle(90)
    F.shot(string.format("%s_call%d", tag, i))
    for _ = 1, 40 do
      if listReady() then break end
      F.press("A", 2); F.idle(40)
    end
    F.L(string.format("  %s #%d header %d special=%s: %s", tag, i, row.header, tostring(row.special), row.text))
    got[#got + 1] = row
    F.check(string.format("%s: call %d ends back on the list", tag, i), listReady())
    F.press("Down", 2); F.idle(30)
  end
  return got
end

local function closePokenav(tag)
  for _ = 1, 10 do if F.ow() then break end F.press("B", 2); F.idle(90) end
  for _ = 1, 10 do if F.ensureFree() then break end F.press("B", 2); F.idle(20) end
  F.check(tag .. ": back on the field and walkable", F.ow() and F.ensureFree(), where())
end

local function count(rows, prefix)
  local n, row = 0, nil
  for _, r in ipairs(rows) do if r.text:sub(1, #prefix) == prefix then n = n + 1; row = r end end
  return n, row
end

F.run(function()
  local beforeCount = -1
  assert(F.boot(100), "boot")
  F.L("seed " .. seed)
  if os.getenv("PW_INSTANT") == "1" then
    local a = F.sb2() + S.SaveBlock2.optionsU16
    F.w16(a, (F.r16(a) & ~7) | 3)
  end
  for _, id in ipairs({ FLAG_SYS_POKENAV_GET, FLAG_ADDED_MATCH_CALL_TO_POKENAV, FLAG_ENABLE_PROF_BIRCH_MATCH_CALL,
                        FLAG_ENABLE_MOM_MATCH_CALL, FLAG_TRAINER_NORMAN }) do setFlag(id) end
  F.check("warped to Route 39", F.warpTo(0, 8, 5, 0, 0, 2, 0, 0, 0, ROUTE39[1], ROUTE39[2], "route39"))
  for _ = 1, 10 do if hasControl() then break end F.press("B", 2); F.idle(20) end
  F.check("Baoba's scene is still ahead", not getFlag(FLAG_ENABLE_BAOBA_MATCH_CALL) and getVar(VAR_LUGIA_OR_HOOH) == 0)

  if openMatchCall("before") then
    local rows = callAll("before")
    beforeCount = #rows
    F.check("before: no BAOBA contact yet", count(rows, "BAOBA") == 0)
    F.check("before: MOM answers", count(rows, "MOM:") == 1)
    F.check("before: Elm's contact (PROF. BIRCH) answers", count(rows, "PROF. BIRCH:") == 1)
    closePokenav("before")
  end

  F.check("walked to the shadow trigger", F.route({ { 21, 18 }, { 30, 18 }, { 30, 21 }, { 34, 21 } }, "to_trigger"), where())
  F.step("Right")
  local f = 0
  while f < 12000 do
    if f % 8 == 0 and F.reportCrash("scene") then break end
    if f > 120 and hasControl() and getFlag(FLAG_ENABLE_BAOBA_MATCH_CALL) then break end
    local k = rand(8)
    joypad.set(f % 12 < 2 and { [k == 0 and "B" or k == 1 and "Down" or "A"] = true } or {})
    emu.frameadvance(); f = f + 1
  end
  joypad.set({})
  F.L(string.format("  scene took %d frames, VAR_LUGIA_OR_HOOH=%d at %s", f, getVar(VAR_LUGIA_OR_HOOH), where()))
  if not getFlag(FLAG_ENABLE_BAOBA_MATCH_CALL) then F.reportCrash("scene_stuck"); F.shot("scene_stuck") end
  F.shot("after_scene")
  F.check("the scene registered Baoba", getFlag(FLAG_ENABLE_BAOBA_MATCH_CALL))
  F.check("a legend was chosen", getVar(VAR_LUGIA_OR_HOOH) == 1 or getVar(VAR_LUGIA_OR_HOOH) == 2)
  F.check("control returned after the scene", hasControl() and F.ensureFree(), where())

  if openMatchCall("after") then
    local rows = callAll("after")
    local n, baoba = count(rows, "BAOBA:")
    F.check("after: exactly one BAOBA contact", n == 1, tostring(n))
    F.check("after: Baoba says the Safari Zone is nearly ready", baoba and baoba.text:find("nearly ready", 1, true) ~= nil)
    F.check("after: MOM still answers", count(rows, "MOM:") == 1)
    F.check("after: Elm's contact (PROF. BIRCH) still answers", count(rows, "PROF. BIRCH:") == 1)
    F.check("after: the list grew by exactly one contact", #rows == beforeCount + 1,
      string.format("%d before, %d after", beforeCount, #rows))
    closePokenav("after")
  end

  setFlag(FLAG_AMPHAROS_HEALED)
  if openMatchCall("open") then
    local rows = callAll("open")
    local n, baoba = count(rows, "BAOBA:")
    F.check("open: Baoba says the Safari Zone is open", n == 1 and baoba.text:find("is open", 1, true) ~= nil)
    closePokenav("open")
  end
  F.finish()
end)
