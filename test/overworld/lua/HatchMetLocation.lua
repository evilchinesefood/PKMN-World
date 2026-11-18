-- Where a Pokemon was met, as hatching, gifts and OT names record it and the summary, friendship,
-- EXP and obedience read it.
--
-- Met location is a u8 in the box data, but Johto's map sections run past 255 and three of them land
-- on the special met codes: Route 46 is 0xFD (METLOC_SPECIAL_EGG), Ice Path 0xFE (METLOC_IN_GAME_TRADE)
-- and Dragon's Den 0xFF (METLOC_FATEFUL_ENCOUNTER). CreateBoxMon stores MAPSEC_SPECIAL_AREA for any
-- section from 0xFD up, and the hatch takes its met location from that same CreateBoxMon call.
--
-- Hatch: an Egg (giveegg script command) with no cycles left hatches on the player's next real step,
-- and the scene is driven with B. In Ecruteak (an ordinary section) and on Route 46, Ice Path,
-- Dragon's Den and Mt. Silver the hatched Togepi must record the section (or MAPSEC_SPECIAL_AREA),
-- met level 0 and 120 friendship, and its SwSh summary memo must say it hatched there. A Protein used
-- from the Bag on the spot must add 3 friendship, plus the met-location bonus of 1 only where the
-- stored met location is the section the player stands in and neither a special code nor
-- MAPSEC_SPECIAL_AREA. A sixth Togepi hatched in Ice Path gets its Protein in the Region Hub 2F,
-- whose own section is MAPSEC_SPECIAL_AREA: no bonus there either.
-- Gift: a createmon gift (the command `givemon` runs) on Mt. Silver and in Dragon's Den must record
-- MAPSEC_SPECIAL_AREA at the gift's level and the memo must say it was met there.
-- OT name: the player's name is seven letters. A Lapras whose OT name is a prefix of it (same ID) is an
-- outsider: in a scripted wild battle it gains 1.5 times the EXP of an identical own Lapras; at level
-- 100 (met at 5) it disobeys under the no-badge cap while the own one knocks its foe out on the first
-- turn three times; and its memo says it only "seems to have met" there.
--
-- Run via test/overworld/mgba-run.sh test/overworld/lua/HatchMetLocation.lua <rom>
-- PW_MET_ONLY=<text> (runner --env) runs only the scenarios whose tag contains <text>.

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "HatchMetLocation")

local HUB_GROUP = 100
local ONLY = os.getenv("PW_MET_ONLY")
local MON = S.Pokemon.size
local USM_ICO_PARTY, USM_ICO_BAG = 1, 2
local POCKET_ITEMS = 0
local VAR_REPEL_STEP_COUNT = 0x4021
local STEP_COUNTER = 2 * 140 + 4

local SPECIES_TOGEPI, SPECIES_LAPRAS, SPECIES_DRATINI, SPECIES_LARVITAR, SPECIES_RATTATA = 175, 131, 147, 246, 19
local ITEM_PROTEIN = 66
local MOVE_SURF, MOVE_TACKLE, MOVE_PSYCHIC = 57, 33, 94
local MAPSEC_SPECIAL_AREA, MAPSEC_ECRUTEAK_CITY = 0xC0, 0xE5
local FLAG_SYS_POKEMON_GET = 0x948
local METLOC_SPECIAL_EGG = 0xFD

local function slot(i) return S.gParties + i * MON end
local function count() return F.r8(S.gPartiesCount) end

local function order(p)
  local o = {}
  for i = 0, 3 do o[i] = F.r8(S.sSubstructOffsets + i * 24 + p % 24) * 3 end
  return o
end
local function words(a)
  local key = F.r32(a) ~ F.r32(a + 4)
  local w = {}
  for i = 0, 11 do w[i] = F.r32(a + 32 + i * 4) ~ key end
  return w, order(F.r32(a))
end
local function checksumOk(a)
  local w = words(a)
  local sum = 0
  for i = 0, 11 do sum = sum + (w[i] & 0xFFFF) + (w[i] >> 16) end
  return (sum & 0xFFFF) == F.r16(a + 28)
end
local function writeWord(a, idx, v)
  local key = F.r32(a) ~ F.r32(a + 4)
  local old = F.r32(a + 32 + idx * 4) ~ key
  F.w32(a + 32 + idx * 4, v ~ key)
  local d = (v & 0xFFFF) + (v >> 16) - (old & 0xFFFF) - (old >> 16)
  F.w16(a + 28, (F.r16(a + 28) + d) & 0xFFFF)
end
local function info(i)
  local a = slot(i)
  local w, o = words(a)
  local misc = w[o[3]]
  return {
    species = w[o[0]] & 0x7FF,
    exp = w[o[0] + 1] & 0x1FFFFF,
    friendship = (w[o[0] + 2] >> 8) & 0xFF,
    metLocation = (misc >> 8) & 0xFF,
    metLevel = (misc >> 16) & 0x7F,
    egg = (F.r8(a + 19) & 0x04) ~= 0,
    otId = F.r32(a + 4),
    level = F.r8(a + S.Pokemon.level),
    sum = checksumOk(a),
  }
end
local function describe(i)
  local m = info(i)
  return string.format("[%d] sp=%d egg=%s met=0x%02X metLv=%d friend=%d lv=%d exp=%d sum=%s", i, m.species,
    tostring(m.egg), m.metLocation, m.metLevel, m.friendship, m.level, m.exp, m.sum and "ok" or "BAD")
end
local function setCycles(i, v)
  local a = slot(i)
  local w, o = words(a)
  writeWord(a, o[0] + 2, (w[o[0] + 2] & ~0xFF00) | ((v & 0xFF) << 8))
end
local function armCycle() F.w32(F.sb1() + S.SaveBlock1.daycare + STEP_COUNTER, 255) end

-- Gen 3 text to ASCII, enough for the memo and the player's name.
local function decode(addr, max)
  local s = {}
  local i = 0
  while i < (max or 200) do
    local c = F.r8(addr + i)
    if c == 0xFF then break end
    if c >= 0xBB and c <= 0xD4 then s[#s + 1] = string.char(65 + c - 0xBB)
    elseif c >= 0xD5 and c <= 0xEE then s[#s + 1] = string.char(97 + c - 0xD5)
    elseif c >= 0xA1 and c <= 0xAA then s[#s + 1] = string.char(48 + c - 0xA1)
    elseif c == 0xAD then s[#s + 1] = "."
    elseif c == 0xF0 then s[#s + 1] = ":"
    elseif c == 0xFE then s[#s + 1] = "/"
    elseif c == 0xFC then
      local code = F.r8(addr + i + 1)
      i = i + ((code == 0x04) and 4 or 2)
    elseif c ~= 0xF9 then s[#s + 1] = " " end
    i = i + 1
  end
  return table.concat(s)
end
local function encodeName(str)
  local t = {}
  for k = 1, #str do t[k] = 0xBB + str:byte(k) - 65 end
  return t
end

local SCRIPT_BUF = S.gStringVar4 + 960
local function hasControl()
  return F.ow() and F.r8(S.sLockFieldControls) == 0 and F.r8(S.sGlobalScriptContextStatus) ~= 0
end
local function runScript(bytes, frames)
  for i, b in ipairs(bytes) do F.w8(SCRIPT_BUF + i - 1, b) end
  F.w8(S.sGlobalScriptContext, 0)
  F.w8(S.sGlobalScriptContext + 1, 1)
  F.w32(S.sGlobalScriptContext + 4, 0)
  F.w32(S.sGlobalScriptContext + S.ScriptCtx.scriptPtr, SCRIPT_BUF)
  F.w8(S.sGlobalScriptContextStatus, 0)
  F.idle(frames or 20)
end
local function le16(t, v) t[#t + 1] = v & 0xFF; t[#t + 1] = (v >> 8) & 0xFF end
local function le32(t, v) le16(t, v & 0xFFFF); le16(t, (v >> 16) & 0xFFFF) end
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

local function clearParty()
  for i = 0, 5 do for o = 0, MON - 4, 4 do F.w32(slot(i) + o, 0) end end
  F.w8(S.gPartiesCount, 0)
end

local function instantText()
  local a = F.sb2() + S.SaveBlock2.optionsU16
  F.w16(a, (F.r16(a) & ~7) | 3)
end

local function d3(n) return (n // 100) % 10, (n // 10) % 10, n % 10 end
local function warp(g, m, w, tag)
  local gh, gt, go = d3(g)
  local mh, mt, mo = d3(m)
  local wh, wt, wo = d3(w)
  return F.warpTo(gh, gt, go, mh, mt, mo, wh, wt, wo, g, m, tag)
end
local function currentMapsec() return F.r16(S.gMapHeader + S.MapHeader.regionMapSectionId) end

local function untilControl(tag, key, budget)
  for i = 1, budget or 3000 do
    if i > 60 and hasControl() then F.idle(20); if hasControl() then return true end end
    if i % 60 == 0 and F.reportCrash(tag) then return false end
    if i % 14 == 0 then F.press(key or "B", 2) else F.idle(1) end
  end
  F.shot(tag .. "_stuck")
  return false
end

-- Drive the hatch scene with B (B answers the nickname question No) until the field is back.
-- Returns whether the scene left the overworld and whether control came back.
local function driveHatch(tag)
  local sawScene = false
  for i = 1, 4000 do
    if not F.ow() then sawScene = true end
    if sawScene and i > 60 and hasControl() and not info(0).egg then
      F.idle(20)
      if hasControl() then return true, true end
    end
    if i % 60 == 0 and F.reportCrash(tag) then return sawScene, false end
    if i % 14 == 0 then F.press("B", 2) else F.idle(1) end
  end
  F.shot(tag:gsub("%W", "_") .. "_stuck")
  return sawScene, false
end

local function inSummary()
  local c = F.cb2()
  return c ~= (S.CB2_UpdatePartyMenu & ~1) and not F.ow()
end

-- Start menu party, slot `i`, Summary, then right to the memo page. Returns the memo text the page
-- printed (gStringVar3 while the page is up).
local function summaryMemo(tag, i)
  local memo = ""
  F.w8(S.gStringVar3, 0xFF)
  F.press("Start", 2); F.idle(60)
  if not F.selectStartIcon(USM_ICO_PARTY) then return "noicon" end
  F.press("A", 2)
  for _ = 1, 200 do F.idle(3); if F.cb2() == (S.CB2_UpdatePartyMenu & ~1) then break end end
  F.idle(60)
  for _ = 1, i do F.press("Down", 2); F.idle(14) end
  F.press("A", 2); F.idle(40)
  F.press("A", 2)
  for _ = 1, 200 do F.idle(3); if inSummary() then break end end
  F.idle(120)
  for _ = 1, 6 do
    local t = decode(S.gStringVar3, 160)
    if t:find("atched", 1, true) or t:find("et ", 1, true) or t:find("trade", 1, true) then memo = t; break end
    F.press("Right", 2); F.idle(70)
  end
  F.shot(tag .. "_memo")
  for _ = 1, 30 do
    if F.ow() then break end
    F.press("B", 2); F.idle(30)
  end
  untilControl(tag .. "_summary_out", "B", 600)
  return memo
end

local function pocketPtr(p) return F.r32(S.gBagPockets + p * S.BagPocket.stride) end
local function qtyKey() return F.r32(F.sb2() + S.SaveBlock2.encryptionKey) & 0xFFFF end
local function setPocket(p, id, qty)
  local ptr, cap = pocketPtr(p), F.pocketCap(p)
  for s = 0, cap - 1 do F.w16(ptr + s * 4, 0); F.w16(ptr + s * 4 + 2, qtyKey()) end
  if qty > 0 then F.w16(ptr, id); F.w16(ptr + 2, qty ~ qtyKey()) end
end
local function inBag() return F.cb2() == (S.CB2_BagMenuRun & ~1) end

-- Bag, first Items slot (a lone Protein), Use, on party slot 0, then back to the field.
local function useProtein(tag)
  setPocket(POCKET_ITEMS, ITEM_PROTEIN, 1)
  F.w8(S.gBagPosition + 5, POCKET_ITEMS)
  F.w16(S.gBagPosition + 8 + POCKET_ITEMS * 2, 0)
  F.w16(S.gBagPosition + 18 + POCKET_ITEMS * 2, 0)
  F.press("Start", 2); F.idle(60)
  if not F.selectStartIcon(USM_ICO_BAG) then return false end
  F.press("A", 2)
  local opened = false
  for _ = 1, 150 do if inBag() then opened = true; break end; F.idle(2) end
  if not opened then return false end
  F.idle(30)
  F.press("A", 2); F.idle(40)
  F.press("A", 2); F.idle(60)
  F.press("A", 2); F.idle(90)
  for _ = 1, 12 do F.press("B", 2); F.idle(30) end
  untilControl(tag .. "_bag_out", "B", 900)
  return true
end

local function scenario(tag, body)
  if ONLY and not tag:find(ONLY, 1, true) then return end
  F.L("== " .. tag .. " ==")
  instantText()
  local ok, err = pcall(body, tag)
  if not ok then F.check(tag .. ": ran without a Lua error", false, tostring(err)) end
  untilControl(tag .. "_end", "B", 600)
end

-- `dir` is a step from the warp's arrival tile that stays on the map (Route 46's Down is the gate door).
local HATCHES = {
  { tag = "Ecruteak City", g = 85, m = 0, w = 11, dir = "Left", met = MAPSEC_ECRUTEAK_CITY, place = "ECRUTEAK" },
  { tag = "Route 46", g = 93, m = 2, w = 0, dir = "Right", met = MAPSEC_SPECIAL_AREA, place = "SPECIAL AREA" },
  { tag = "Ice Path", g = 94, m = 7, w = 1, dir = "Left", met = MAPSEC_SPECIAL_AREA, place = "SPECIAL AREA" },
  { tag = "Dragon's Den", g = 94, m = 12, w = 0, dir = "Left", met = MAPSEC_SPECIAL_AREA, place = "SPECIAL AREA" },
  { tag = "Mt. Silver", g = 97, m = 0, w = 0, dir = "Left", met = MAPSEC_SPECIAL_AREA, place = "SPECIAL AREA" },
  { tag = "Ice Path, Protein in the Region Hub 2F", g = 94, m = 7, w = 1, dir = "Left", met = MAPSEC_SPECIAL_AREA,
    place = "SPECIAL AREA", proteinIn = { 100, 1, 0 } },
}

local function hatchHere(c)
  local tag = "hatch in " .. c.tag
  if not warp(c.g, c.m, c.w, tag:gsub("%W", "_")) then F.check(tag .. ": warp", false); return end
  clearParty()
  giveEgg(SPECIES_TOGEPI)
  createMon(SPECIES_LAPRAS, 50, { MOVE_SURF })
  setVar(VAR_REPEL_STEP_COUNT, 0x7FFF)
  setCycles(0, 0)
  F.check(tag .. ": slot 0 is an Egg", info(0).egg, describe(0))
  local mapsec = currentMapsec()
  armCycle()
  -- A wandering overworld Pokemon can stand on the planned tile; fall back to the other directions.
  local stepped = false
  for _, dir in ipairs({ c.dir, "Left", "Right", "Up", "Down" }) do
    if F.step(dir) then stepped = F.grp() == c.g and F.mapn() == c.m; break end
  end
  local sawScene, back = driveHatch(tag)
  local m = info(0)
  F.L(string.format("  %s: mapsec=0x%03X stepped=%s %s", tag, mapsec, tostring(stepped), describe(0)))
  F.check(tag .. ": the hatch scene ran from a real step on the map", sawScene and stepped)
  F.check(tag .. ": control returns", back)
  F.check(tag .. ": a Togepi hatched with a valid checksum", m.species == SPECIES_TOGEPI and not m.egg and m.sum, describe(0))
  F.check(string.format("%s: met location is 0x%02X", tag, c.met), m.metLocation == c.met,
    string.format("met=0x%02X mapsec=0x%03X", m.metLocation, mapsec))
  F.check(tag .. ": met level 0 (hatched) and 120 friendship", m.metLevel == 0 and m.friendship == 120, describe(0))

  local memo = summaryMemo(tag:gsub("%W", "_"), 0)
  F.L("  memo: " .. memo)
  F.check(tag .. ": the summary memo says it hatched at " .. c.place,
    memo:find("Hatched from an egg", 1, true) ~= nil and memo:upper():find(c.place, 1, true) ~= nil, memo)

  -- RegionHub_2F's own section is MAPSEC_SPECIAL_AREA, the value stored for every unrepresentable
  -- section, so a special-area Pokemon must not count as met there.
  if c.proteinIn then
    if not warp(c.proteinIn[1], c.proteinIn[2], c.proteinIn[3], "protein_map") then F.check(tag .. ": warp for the Protein", false) end
    mapsec = currentMapsec()
  end
  local before = info(0).friendship
  local used = useProtein(tag:gsub("%W", "_"))
  local after = info(0).friendship
  local bonus = (m.metLocation < METLOC_SPECIAL_EGG and m.metLocation ~= MAPSEC_SPECIAL_AREA
    and m.metLocation == mapsec) and 1 or 0
  F.check(string.format("%s: a Protein here adds %d friendship", tag, 3 + bonus), used and after - before == 3 + bonus,
    string.format("friendship %d -> %d, met=0x%02X mapsec=0x%03X", before, after, m.metLocation, mapsec))
  F.check(tag .. ": no crash screen", not F.crashScreen())
end

local GIFTS = {
  { tag = "Mt. Silver", g = 97, m = 0, w = 0, sp = SPECIES_LARVITAR },
  { tag = "Dragon's Den", g = 94, m = 12, w = 0, sp = SPECIES_DRATINI },
}

local function giftHere(c)
  local tag = "gift in " .. c.tag
  if not warp(c.g, c.m, c.w, tag:gsub("%W", "_")) then F.check(tag .. ": warp", false); return end
  clearParty()
  createMon(c.sp, 15, { MOVE_TACKLE })
  local m = info(0)
  F.L("  " .. tag .. ": " .. describe(0))
  F.check(tag .. ": met location is MAPSEC_SPECIAL_AREA at level 15", m.species == c.sp and m.metLocation == MAPSEC_SPECIAL_AREA
    and m.metLevel == 15, describe(0))
  local memo = summaryMemo(tag:gsub("%W", "_"), 0)
  F.L("  memo: " .. memo)
  F.check(tag .. ": the memo says it was met at 15 in the SPECIAL AREA",
    memo:find("Met when it was", 1, true) ~= nil and memo:find("15", 1, true) ~= nil and memo:upper():find("SPECIAL AREA", 1, true) ~= nil, memo)
end

local PLAYER_NAME = "MARSHAL"
local OT_PREFIX = "MARS"

local function setPlayerName(name)
  local a = F.sb2() + S.SaveBlock2.playerName
  local t = encodeName(name)
  for k = 0, 7 do F.w8(a + k, t[k + 1] or 0xFF) end
end
local function setOtName(i, name)
  local t = encodeName(name)
  for k = 0, 6 do F.w8(slot(i) + 20 + k, t[k + 1] or 0xFF) end
end

-- A scripted wild battle (setwildbattle + dowildbattle) against a level 2 Rattata, driven with A
-- alone (FIGHT, first move). Psychic from a level 100 Lapras always knocks it out on the first
-- turn, so a battle that reaches the end of turn 1 means the Lapras disobeyed; with `flee` the
-- driver then runs (B puts the cursor on RUN in a wild battle). Returns the outcome, the EXP slot 0
-- gained and whether a turn ended with the battle still going.
local B_OUTCOME_WON, B_OUTCOME_RAN = 1, 4
local function wildBattle(tag, flee)
  local exp0 = info(0).exp
  F.w16(S.gBattleTurnCounter, 0)
  local b = { 0xB6 }; le16(b, SPECIES_RATTATA); b[#b + 1] = 2; le16(b, 0); le16(b, 0); b[#b + 1] = 0; le16(b, 0)
  b[#b + 1] = 0xB7; b[#b + 1] = 0x02
  runScript(b, 60)
  local fought, outlasted = false, false
  for i = 1, 12000 do
    if not F.ow() then fought = true end
    if fought and i > 200 and hasControl() then break end
    if i % 40 == 0 and F.reportCrash(tag) then break end
    if F.cb2() == (S.BattleMainCB2 & ~1) and F.r16(S.gBattleTurnCounter) >= 1
      and F.r16(S.gBattleMons + S.BattlePokemon.size + S.BattlePokemon.hp) > 0 then outlasted = true end
    local keys = {}
    if i % 16 < 2 then keys = { A = true } end
    if outlasted and flee and i % 32 == 8 then keys = { B = true } end
    joypad.set(keys)
    emu.frameadvance()
  end
  joypad.set({})
  untilControl(tag .. "_after", "B", 1200)
  local outcome = fought and F.r8(S.gBattleOutcome) or -1
  return outcome, info(0).exp - exp0, outlasted
end

local function setMetLevel(i, lv)
  local a = slot(i)
  local w, o = words(a)
  writeWord(a, o[3], (w[o[3]] & ~(0x7F << 16)) | ((lv & 0x7F) << 16))
end

-- Obedience here follows the Gen 8+ rule (B_OBEDIENCE_MECHANICS): the player's own Pokemon are
-- judged by the level they were met at, an outsider by its current level. The level 100 Lapras are
-- given a met level of 5, as if caught young and raised.
local function lapras(level, otName, metLevel)
  clearParty()
  createMon(SPECIES_LAPRAS, level, { MOVE_PSYCHIC })
  if otName then setOtName(0, otName) end
  if metLevel then setMetLevel(0, metLevel) end
end

local function otScenario(tag)
  if not warp(85, 0, 11, "ot_ecruteak") then F.check(tag .. ": warp", false); return end
  setVar(VAR_REPEL_STEP_COUNT, 0x7FFF)
  setPlayerName(PLAYER_NAME)
  local name = decode(F.sb2() + S.SaveBlock2.playerName, 8)
  F.check(tag .. ": the player's name is seven letters", name == PLAYER_NAME, name)

  -- Level 10 obeys with no badges either way, so the EXP comparison is clean.
  lapras(10)
  local o1, ownGain = wildBattle(tag .. "_own_exp")
  lapras(10, OT_PREFIX)
  local o2, prefixGain = wildBattle(tag .. "_prefix_exp")
  F.L(string.format("  EXP at level 10: own=%d (outcome %d) OT %s=%d (outcome %d)", ownGain, o1, OT_PREFIX, prefixGain, o2))
  F.check(tag .. ": both level 10 Lapras won and the own one gained EXP", o1 == B_OUTCOME_WON and o2 == B_OUTCOME_WON
    and ownGain > 0, string.format("outcomes %d/%d own=%d", o1, o2, ownGain))
  F.check(tag .. ": an OT that is a prefix of the player's name gets the traded 1.5x EXP",
    math.abs(prefixGain - (ownGain * 150) // 100) <= 1 and prefixGain > ownGain, string.format("own=%d prefix=%d", ownGain, prefixGain))

  -- Level 100, met at 5, against the no-badge cap of 10: an outsider obeys about one turn in ten,
  -- the player's own Pokemon always.
  local ownLog, ownOk = {}, true
  for k = 1, 3 do
    lapras(100, nil, 5)
    local o, _, outlasted = wildBattle(tag .. "_own_obey" .. k, false)
    ownLog[k] = string.format("%d/%s", o, tostring(outlasted))
    ownOk = ownOk and o == B_OUTCOME_WON and not outlasted
  end
  local prefixLog, disobeyed = {}, false
  for k = 1, 3 do
    lapras(100, OT_PREFIX, 5)
    local o, _, outlasted = wildBattle(tag .. "_prefix_obey" .. k, true)
    prefixLog[k] = string.format("%d/%s", o, tostring(outlasted))
    if outlasted and o == B_OUTCOME_RAN then disobeyed = true; break end
  end
  F.L("  level 100 battles (outcome/outlasted turn 1): own=" .. table.concat(ownLog, ",") .. " OT " .. OT_PREFIX .. "="
    .. table.concat(prefixLog, ","))
  F.check(tag .. ": the player's own level 100 Lapras obeys (three first-turn knockouts)", ownOk, table.concat(ownLog, ","))
  F.check(tag .. ": the OT-prefix level 100 Lapras disobeys (its foe outlasts a turn)", disobeyed, table.concat(prefixLog, ","))

  lapras(10)
  local ownMemo = summaryMemo("ot_own", 0)
  F.L("  own memo: " .. ownMemo)
  F.check(tag .. ": the own Lapras's memo says the player met it", ownMemo:find("Met when it was", 1, true) ~= nil, ownMemo)
  lapras(10, OT_PREFIX)
  local prefixMemo = summaryMemo("ot_prefix", 0)
  F.L("  prefix memo: " .. prefixMemo)
  F.check(tag .. ": the OT-prefix Lapras's memo says it only seems to have met there",
    prefixMemo:find("Seems to have met", 1, true) ~= nil, prefixMemo)
end

F.run(function()
  if not F.boot(HUB_GROUP) then F.check("boot to the hub", false); F.finish(); return end
  instantText()
  local fa = F.sb1() + S.SaveBlock1.flags + FLAG_SYS_POKEMON_GET // 8
  F.w8(fa, F.r8(fa) | (1 << (FLAG_SYS_POKEMON_GET % 8)))

  for _, c in ipairs(HATCHES) do scenario("hatch in " .. c.tag, function() hatchHere(c) end) end
  for _, c in ipairs(GIFTS) do scenario("gift in " .. c.tag, function() giftHere(c) end) end
  scenario("traded OT prefix", otScenario)

  F.check("no crash screen", not F.crashScreen())
  F.finish()
end)
