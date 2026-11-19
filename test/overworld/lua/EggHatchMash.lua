-- Mashing through Egg hatches that start from a real step.
--
-- Each scenario gives Eggs with the giveegg script command, sets their remaining cycles to 0 in
-- the encrypted party data (checksum kept) and the Day Care step counter one short of a cycle, so
-- the next step the player takes runs the game's own hatch check. Once the player starts that step,
-- the rest of the step and scene (including the nickname prompt and naming screen) use a seeded
-- mash of A, B, Start, Select, L, R and the D-pad. After it the field must come back with control,
-- no crash screen, the party count unchanged, every hatched slot decrypting to the Egg's species
-- with a valid checksum and no Egg bit, and the follower (when one is shown) the lead's species.
--
-- Scenarios: an Egg leading on foot in Ecruteak with a Lapras behind; two Eggs hatching on the
-- next two cycles; an Egg hatching while surfing in Sootopolis; and while riding the Mach Bike on
-- Route 119.
--
-- PW_EGG_ONLY=<text> runs matching scenarios, PW_EGG_BASE=<n> reseeds the mash.

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "EggHatchMash")

local HUB_GROUP = 100
local ONLY = os.getenv("PW_EGG_ONLY")
local BASE = tonumber(os.getenv("PW_EGG_BASE") or "") or 0xE66
local OBJ_EVENT_ID_FOLLOWER = 0xFE
local OBJ_EVENT_MON = 0x4000
local ITEM_MACH_BIKE = 707
local VAR_REPEL_STEP_COUNT = 0x4021
local SUB0 = { 0,0,0,0,0,0,1,1,2,3,2,3,1,1,2,3,2,3,1,1,2,3,2,3 }
local STEP_COUNTER = 2 * 140 + 4

local seed = BASE
local function rnd()
  seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF
  return seed >> 8
end
local function seedFor(tag)
  local h = BASE & 0x7FFFFFFF
  for i = 1, #tag do h = ((h ~ tag:byte(i)) * 16777619) & 0x7FFFFFFF end
  return h
end

local SCRIPT_BUF = S.gStringVar4 + 960
local function runScript(bytes)
  for i, b in ipairs(bytes) do F.w8(SCRIPT_BUF + i - 1, b) end
  F.w8(S.sGlobalScriptContext, 0)
  F.w8(S.sGlobalScriptContext + 1, 1)
  F.w32(S.sGlobalScriptContext + 4, 0)
  F.w32(S.sGlobalScriptContext + S.ScriptCtx.scriptPtr, SCRIPT_BUF)
  F.w8(S.sGlobalScriptContextStatus, 0)
  F.idle(20)
end
local function le16(t, v) t[#t + 1] = v & 0xFF; t[#t + 1] = (v >> 8) & 0xFF end
local function le32(t, v) le16(t, v & 0xFFFF); le16(t, (v >> 16) & 0xFFFF) end
local function addItem(id, qty) runScript({ 0x44, id & 0xFF, id >> 8, qty & 0xFF, qty >> 8, 0x02 }) end
local function setVar(id, v) local b = { 0x16 }; le16(b, id); le16(b, v); b[#b + 1] = 0x02; runScript(b) end
local function giveEgg(species) local b = { 0x7A }; le16(b, species); b[#b + 1] = 0x02; runScript(b) end
local function createMon(species, level, moves)
  local b = { 0x23 }; le32(b, S.ScrCmd_createmon | 1)
  b[#b + 1] = 0; b[#b + 1] = 6
  le16(b, species); le16(b, level)
  le32(b, (1 << 17) | (1 << 18) | (1 << 19) | (1 << 20))
  for k = 1, 4 do le16(b, moves[k] or 0) end
  b[#b + 1] = 0x02
  runScript(b)
end

local function d3(n) return (n // 100) % 10, (n // 10) % 10, n % 10 end
local function warp(g, m, w, tag)
  local gh, gt, go = d3(g)
  local mh, mt, mo = d3(m)
  local wh, wt, wo = d3(w)
  return F.warpTo(gh, gt, go, mh, mt, mo, wh, wt, wo, g, m, tag)
end

local function count() return F.r8(S.gPartiesCount) end
local function slot(i) return S.gParties + i * S.Pokemon.size end
local function species(i)
  local box = slot(i)
  local pid, ot = F.r32(box), F.r32(box + 4)
  return (F.r32(box + 32 + SUB0[(pid % 24) + 1] * 12) ~ pid ~ ot) & 0x7FF
end
local function isEgg(i) return (F.r8(slot(i) + 19) & 0x04) ~= 0 end
local function eggCount()
  local eggs = 0
  for i = 0, count() - 1 do if isEgg(i) then eggs = eggs + 1 end end
  return eggs
end
local function checksumOk(i)
  local box = slot(i)
  local key = F.r32(box) ~ F.r32(box + 4)
  local sum = 0
  for o = 0, 44, 4 do
    local w = F.r32(box + 32 + o) ~ key
    sum = sum + (w & 0xFFFF) + (w >> 16)
  end
  return (sum & 0xFFFF) == F.r16(box + 28)
end
local function setCycles(i, v)
  local box = slot(i)
  local pid, ot = F.r32(box), F.r32(box + 4)
  local key = pid ~ ot
  local a = box + 32 + SUB0[(pid % 24) + 1] * 12 + 8
  local w = F.r32(a) ~ key
  local nw = (w & ~0xFF00) | ((v & 0xFF) << 8)
  F.w32(a, nw ~ key)
  F.w16(box + 28, (F.r16(box + 28) - (w & 0xFFFF) + (nw & 0xFFFF)) & 0xFFFF)
end
local function armCycle() F.w32(F.sb1() + S.SaveBlock1.daycare + STEP_COUNTER, 255) end

local function clearParty()
  for i = 0, 5 do for o = 0, S.Pokemon.size - 4, 4 do F.w32(slot(i) + o, 0) end end
  F.w8(S.gPartiesCount, 0)
end

local function follower()
  for i = 0, 15 do
    local o = S.gObjectEvents + i * S.ObjectEvent.stride
    if (F.r8(o) & 1) ~= 0 and F.r8(o + 8) == OBJ_EVENT_ID_FOLLOWER then
      return o, ((F.r8(o + 1) >> 5) & 1) == 0
    end
  end
end

local function hasControl()
  return F.ow() and F.r8(S.sLockFieldControls) == 0 and F.r8(S.sGlobalScriptContextStatus) ~= 0
end

local DIRS = { "Up", "Down", "Left", "Right" }
-- Assign rolls in a fixed order so the same seed replays the same buttons across Lua processes.
local BUTTONS = { {"Start", 6}, {"L", 6}, {"Select", 6}, {"R", 6}, {"B", 25}, {"A", 35} }
local function mashFrame(dirBias)
  local t = {}
  for _, button in ipairs(BUTTONS) do
    if rnd() % 100 < button[2] then t[button[1]] = true end
  end
  if t.R and t.Start then t.R = nil end
  if t.A and t.B and t.Start and t.Select then t.Select = nil end
  if dirBias then t[dirBias] = true elseif rnd() % 100 < 40 then t[DIRS[rnd() % 4 + 1]] = true end
  joypad.set(t)
  emu.frameadvance()
end

-- Step in `dir` with noise until the hatch scene runs and the field is back under control.
local function hatchMash(tag, dir, frames)
  local sawScene, crashed = false, false
  local eggs0 = eggCount()
  -- Start/Select can open a menu before the D-pad starts a step. Wait for the
  -- movement to begin, then mash immediately, including the remainder of the step.
  local x0, y0 = F.pos()
  for _ = 1, 30 do
    joypad.set({ [dir] = true })
    emu.frameadvance()
    local x, y = F.pos()
    if x ~= x0 or y ~= y0 then break end
  end
  local x, y = F.pos()
  local stepped = x ~= x0 or y ~= y0
  F.check(tag .. ": hatch-triggering step started", stepped, string.format("(%d,%d) -> (%d,%d)", x0, y0, x, y))
  if not stepped then return false, F.reportCrash(tag) end
  for i = 1, frames do
    if i % 20 == 0 and F.reportCrash(tag) then crashed = true; break end
    if not F.ow() then sawScene = true end
    if sawScene and hasControl() and eggCount() < eggs0 and i > 200 then break end
    mashFrame(i < 40 and dir or nil)
  end
  if crashed then return false, true end
  for _ = 1, 3000 do
    if hasControl() then break end
    local k = (emu.framecount() % 30 < 2) and "B" or nil
    joypad.set(k and { [k] = true } or {})
    emu.frameadvance()
  end
  F.idle(60)
  return sawScene and eggCount() < eggs0, false
end

local function checkParty(tag, expect)
  F.check(tag .. ": party count unchanged", count() == #expect, "n=" .. count())
  for i, sp in ipairs(expect) do
    local k = i - 1
    F.check(string.format("%s: slot %d is %d, decrypts, checksum valid", tag, k, sp),
      species(k) == sp and checksumOk(k), string.format("species=%d sum=%s", species(k), tostring(checksumOk(k))))
  end
end
local function checkNoEggs(tag, slots)
  for _, k in ipairs(slots) do
    F.check(string.format("%s: slot %d hatched", tag, k), not isEgg(k))
  end
end
local function checkFollower(tag)
  F.step("Down"); F.step("Up"); F.idle(30)
  local o, shown = follower()
  if not (o and shown) then F.L("  follower " .. (o and "hidden" or "none")); return end
  local gfx = F.r16(o + S.ObjectEvent.graphicsId)
  F.check(tag .. ": the follower shows the lead", (gfx & ~OBJ_EVENT_MON & 0x8FFF) == species(0),
    string.format("gfx=%04X lead=%d", gfx, species(0)))
end

local function scenario(tag, body)
  if ONLY and not tag:find(ONLY, 1, true) then return end
  seed = seedFor(tag)
  F.L(string.format("== %s == seed=%d", tag, seed))
  local ok, err = pcall(body)
  if not ok then F.check(tag .. ": ran without a Lua error", false, tostring(err)) end
  for _ = 1, 20 do F.press("B", 2); F.idle(10) end
end

local SPECIES_TOGEPI, SPECIES_PICHU, SPECIES_LAPRAS, SPECIES_MAGIKARP = 175, 172, 131, 129
local function party(list)
  clearParty()
  for _, e in ipairs(list) do
    if e.egg then giveEgg(e.sp) else createMon(e.sp, 50, e.moves or { 57, 0, 0, 0 }) end
  end
  for i = 0, count() - 1 do if isEgg(i) then setCycles(i, 0) end end
end

F.run(function()
  if not F.boot(HUB_GROUP) then F.check("boot to the hub", false); F.finish(); return end
  addItem(ITEM_MACH_BIKE, 1)
  for id = 875, 880 do addItem(id, 1) end

  scenario("egg leads on foot", function()
    if not warp(85, 0, 11, "ecruteak") then F.check("warp to Ecruteak", false); return end
    party({ { sp = SPECIES_TOGEPI, egg = true }, { sp = SPECIES_LAPRAS } })
    setVar(VAR_REPEL_STEP_COUNT, 0x7FFF)
    F.check("egg leads: slot 0 is an Egg", isEgg(0))
    armCycle()
    local saw, crashed = hatchMash("egg leads", "Down", 3000)
    F.check("egg leads: no crash", not crashed)
    F.check("egg leads: the hatch scene ran", saw)
    F.check("egg leads: control returns", hasControl())
    checkParty("egg leads", { SPECIES_TOGEPI, SPECIES_LAPRAS })
    checkNoEggs("egg leads", { 0 })
    checkFollower("egg leads")
    F.shot("egg_leads_after")
  end)

  scenario("two eggs back to back", function()
    if not warp(85, 0, 11, "ecruteak2") then F.check("warp to Ecruteak", false); return end
    party({ { sp = SPECIES_LAPRAS }, { sp = SPECIES_PICHU, egg = true }, { sp = SPECIES_TOGEPI, egg = true } })
    setVar(VAR_REPEL_STEP_COUNT, 0x7FFF)
    armCycle()
    local saw1, c1 = hatchMash("two eggs 1", "Down", 3000)
    armCycle()
    local saw2, c2 = hatchMash("two eggs 2", "Up", 3000)
    F.check("two eggs: no crash", not c1 and not c2)
    F.check("two eggs: both scenes ran", saw1 and saw2)
    F.check("two eggs: control returns", hasControl())
    checkParty("two eggs", { SPECIES_LAPRAS, SPECIES_PICHU, SPECIES_TOGEPI })
    checkNoEggs("two eggs", { 1, 2 })
    checkFollower("two eggs")
  end)

  -- Sootopolis: south of the arrival lies the crater lake.
  scenario("hatch while surfing", function()
    if not warp(0, 7, 0, "sootopolis") then F.check("warp to Sootopolis", false); return end
    party({ { sp = SPECIES_LAPRAS }, { sp = SPECIES_TOGEPI, egg = true } })
    setVar(VAR_REPEL_STEP_COUNT, 0x7FFF)
    local surfed = false
    for _ = 1, 12 do
      if (F.r8(S.gPlayerAvatar) & 0x08) ~= 0 then surfed = true; break end
      if not F.step("Down") then
        F.face("Down"); F.press("A", 2); F.idle(60)
        for _ = 1, 8 do F.press("A", 2); F.idle(40) end
        F.idle(120)
      end
    end
    F.check("surfing: the player is surfing", surfed, string.format("avatar=%02X (%d,%d)", F.r8(S.gPlayerAvatar), F.pos()))
    if not surfed then F.shot("surf_fail"); return end
    armCycle()
    local x0, y0 = F.pos()
    local saw, crashed = hatchMash("surfing", "Down", 3000)
    F.check("surfing: no crash", not crashed)
    F.check("surfing: the hatch scene ran", saw)
    F.check("surfing: control returns", hasControl())
    F.check("surfing: still surfing", (F.r8(S.gPlayerAvatar) & 0x08) ~= 0, string.format("avatar=%02X", F.r8(S.gPlayerAvatar)))
    checkParty("surfing", { SPECIES_LAPRAS, SPECIES_TOGEPI })
    checkNoEggs("surfing", { 1 })
    F.shot("surfing_after")
  end)

  scenario("hatch on the mach bike", function()
    if not warp(0, 34, 0, "route119") then F.check("warp to Route 119", false); return end
    party({ { sp = SPECIES_TOGEPI, egg = true }, { sp = SPECIES_LAPRAS } })
    setVar(VAR_REPEL_STEP_COUNT, 0x7FFF)
    F.step("Down")
    F.w16(F.sb1() + S.SaveBlock1.registeredItem, ITEM_MACH_BIKE)
    F.press("Select", 2); F.idle(60)
    F.check("bike: on the Mach Bike", (F.r8(S.gPlayerAvatar) & 0x02) ~= 0, string.format("avatar=%02X", F.r8(S.gPlayerAvatar)))
    armCycle()
    local saw, crashed = hatchMash("bike", "Down", 3000)
    F.check("bike: no crash", not crashed)
    F.check("bike: the hatch scene ran", saw)
    F.check("bike: control returns", hasControl())
    checkParty("bike", { SPECIES_TOGEPI, SPECIES_LAPRAS })
    checkNoEggs("bike", { 0 })
    F.shot("bike_after")
  end)

  F.finish()
end)
