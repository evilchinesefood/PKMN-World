-- Badge speeches must state this build's badge rules.
--
-- B_BADGE_BOOST is GEN_LATEST, so no badge raises a stat, and GetAttackerObedienceForAction
-- (src/battle_util.c) raises the obedience cap by 10 with every badge of the active region. The
-- FRLG, Emerald and HnS speeches kept their own games' rules: Brock, Surge, Koga, Blaine, Falkner,
-- Whitney, Jasmine, Pryce, Roxanne, Wattson, Norman and Tate & Liza promised a stat boost, the
-- Cerulean badge describer promised four, and Chuck quoted GSC's level 70 for the 5th badge, which
-- grants 60 here.
--
-- Two real-input drives cover the class (ValidateConfigRules.py covers every line):
--   1. the Cerulean badge describer (Kanto): the BOULDER, THUNDER, SOUL and VOLCANO rows must quote
--      the obedience level the badge grants (20, 40, 60, 80) and claim no stat;
--   2. Roxanne (Hoenn): talk, battle (the win is forced once it starts), and her STONE BADGE speech
--      must quote level 20 and no ATTACK boost.
-- Oracle: the field message, read from gStringVar4 where the game expands it.
local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "BadgeSpeechRules")

local HUB_GROUP = 100
local CERULEAN_HOUSE_G, CERULEAN_HOUSE_M = 41, 0
local RUSTBORO_GYM_G, RUSTBORO_GYM_M = 11, 3
local CONTEXT_SHUTDOWN = 2
local PARTY_SIZE = 6
local MON = S.Pokemon.size
local BP_STRIDE, BP_HP = S.BattlePokemon.size, S.BattlePokemon.hp
local B_OUTCOME_WON = 1
local TRAINER_FLAGS_START = 0x500
local GYM_TRAINERS = { 320, 321, 571 }                 -- Josh, Tommy, Marc

local function where() local x, y = F.pos(); return string.format("%d/%d (%d,%d)", F.grp(), F.mapn(), x, y) end
local function hasControl()
  return F.ow() and F.r8(S.sLockFieldControls) == 0 and F.r8(S.sGlobalScriptContextStatus) == CONTEXT_SHUTDOWN
end
local function instantText()
  local a = F.sb2() + S.SaveBlock2.optionsU16
  F.w16(a, (F.r16(a) & ~7) | 3)
end
local function setFlag(n)
  local a = F.sb1() + S.SaveBlock1.flags + n // 8
  F.w8(a, F.r8(a) | (1 << (n % 8)))
end

local function decode(addr, max)
  local out = {}
  for i = 0, (max or 400) - 1 do
    local c = F.r8(addr + i)
    if c == 0xFF then break end
    if c == 0x00 then out[#out + 1] = " "
    elseif c >= 0xBB and c <= 0xD4 then out[#out + 1] = string.char(65 + c - 0xBB)
    elseif c >= 0xD5 and c <= 0xEE then out[#out + 1] = string.char(97 + c - 0xD5)
    elseif c >= 0xA1 and c <= 0xAA then out[#out + 1] = string.char(48 + c - 0xA1)
    elseif c == 0xAB then out[#out + 1] = "!"
    elseif c == 0xAD then out[#out + 1] = "."
    elseif c == 0xAE then out[#out + 1] = "-"
    elseif c == 0xB8 then out[#out + 1] = ","
    elseif c == 0xB4 then out[#out + 1] = "'"
    elseif c == 0xFE or c == 0xFA or c == 0xFB then out[#out + 1] = " "
    else out[#out + 1] = "?" end
  end
  return table.concat(out)
end

-- Press `key` every `gap` frames for `frames` frames, keeping each new gStringVar4 text.
local function record(tag, frames, key, gap, seen, stop, shots)
  seen = seen or {}
  for i = 1, frames do
    if i % 8 == 0 and F.reportCrash(tag) then break end
    local t = decode(S.gStringVar4)
    if not seen[t] then
      seen[t] = true; seen[#seen + 1] = t; F.L("  " .. tag .. ": " .. t)
      if shots then F.idle(20); F.shot(tag .. "_" .. #seen) end
    end
    if stop and stop(t) then break end
    joypad.set((key and i % gap < 2) and { [key] = true } or {})
    emu.frameadvance()
  end
  joypad.set({})
  return seen
end

local function backToControl()
  for _ = 1, 80 do
    if hasControl() then return true end
    F.press("B", 2); F.idle(20)
  end
  return hasControl()
end

local function zeroParty()
  for off = 0, PARTY_SIZE * MON - 4, 4 do F.w32(S.gParties + off, 0) end
  F.w8(S.gPartiesCount, 0)
end
local function digits(n) n = n - 1; return n // 100, (n // 10) % 10, n % 10 end
local function giveMon(species, level)
  for _ = 1, 3 do
    zeroParty()
    F.dbg(); F.idle(30); F.bOut(4)
    F.dbg(); F.sel(3); F.sel(1); F.idle(20)
    F.spin(digits(species)); F.idle(20)
    F.spin(digits(level)); F.idle(60); F.bOut(4)
    if F.r8(S.gPartiesCount) == 1 then return true end
    F.idle(60)
  end
  return false
end

-- The describer: talk, wait for the badge list, move down `row` rows, pick, read the description.
local function describe(row, tag)
  F.face("Up")
  F.press("A", 2)
  local seen = record(tag .. "_intro", 600, "A", 40, nil, function(t) return t:find("Which of the eight", 1, true) end)
  F.idle(30)
  F.press("A", 2)                     -- "Now then…" waits for a page turn before the list opens
  F.idle(150)
  for _ = 1, row do F.press("Down", 4); F.idle(20) end
  F.idle(20)
  local said
  record(tag, 600, "A", 40, seen, function(t)
    if t:find("outside of battle", 1, true) then said = t; return true end
  end)
  F.idle(30)
  F.shot(tag)
  backToControl()
  return said or ""
end

F.run(function()
  if not F.boot(HUB_GROUP) then F.check("boot to the hub", false); F.finish(); return end
  instantText()

  -- 1. Cerulean badge describer.
  F.check("warp to the Cerulean badge describer", F.warpTo(0, 4, 1, 0, 0, 0, 0, 0, 1, CERULEAN_HOUSE_G, CERULEAN_HOUSE_M, "cerulean"))
  instantText()
  F.check("walk up to the describer", F.route({ { 3, 6 }, { 6, 6 } }, "describer"), where())
  for _, b in ipairs({ { 0, "BOULDER", 20, "FLASH" }, { 2, "THUNDER", 40, "FLY" }, { 4, "SOUL", 60, "SURF" },
                       { 6, "VOLCANO", 80, "WATERFALL" } }) do
    local row, name, level, move = b[1], b[2], b[3], b[4]
    local t = describe(row, "describe_" .. name:lower())
    F.check(name .. ": the description of this badge was read", t:find(move .. " outside of battle", 1, true) ~= nil, t)
    F.check(name .. ": quotes obedience up to level " .. level, t:find("up to Lv. " .. level .. " will obey", 1, true) ~= nil, t)
    F.check(name .. ": claims no stat boost", not t:find("stat", 1, true), t)
  end

  -- 2. Roxanne.
  F.check("give a party POKéMON", giveMon(258, 50))
  for _, id in ipairs(GYM_TRAINERS) do setFlag(TRAINER_FLAGS_START + id) end
  F.check("warp to the Rustboro Gym", F.warpTo(0, 1, 1, 0, 0, 3, 0, 0, 0, RUSTBORO_GYM_G, RUSTBORO_GYM_M, "rustboro_gym"))
  instantText()
  F.check("walk up to Roxanne",
    F.route({ { 5, 14 }, { 4, 14 }, { 4, 12 }, { 5, 12 }, { 5, 8 }, { 2, 8 }, { 2, 5 }, { 5, 5 }, { 5, 3 } }, "roxanne"), where())
  F.face("Up")
  F.press("A", 2)
  local started = false
  for _ = 1, 60 do
    if F.battlers() > 0 and not F.ow() then started = true; break end
    F.press("A", 2); F.idle(30)
  end
  F.check("Roxanne's battle started", started)
  for t = 1, 6000 do
    local n = F.battlers()
    for b = 1, n - 1, 2 do F.w16(S.gBattleMons + b * BP_STRIDE + BP_HP, 0) end
    F.w8(S.gBattleOutcome, B_OUTCOME_WON)
    F.press("A", t % 3 == 0 and 2 or 1); F.idle(1)
    if F.ow() then break end
  end
  local seen = record("roxanne", 3000, "A", 40, nil, function() return false end, true)
  local speech = ""
  for _, t in ipairs(seen) do if t:find("STONE BADGE,", 1, true) or t:find("STONE BADGE ", 1, true) then speech = speech .. t .. " | " end end
  F.shot("roxanne_after")
  F.check("Roxanne's STONE BADGE speech was read", speech ~= "", table.concat(seen, " | "):sub(1, 400))
  F.check("Roxanne quotes obedience up to level 20", speech:find("up to Level 20 will obey", 1, true) ~= nil, speech)
  F.check("Roxanne claims no ATTACK boost", not speech:find("ATTACK", 1, true), speech)
  backToControl()
  F.finish()
end)
