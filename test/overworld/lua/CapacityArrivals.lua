-- Pokemon arrivals with the party and every PC box full, played through the givers' own scripts.
--
-- AuditCapacity.py proves each gift script tests its result for MON_CANT_GIVE (or checks the party
-- size first). It cannot see what the game does on that path: whether the giver says so, gives
-- nothing, keeps the gift on offer, hands control back, and leaves every Pokemon where it was.
-- This suite plays each giver with six Pokemon in the party and all 420 box slots taken, once
-- answering every prompt with A and once under a seeded mash, at Instant and at Mid text. Then it
-- frees one box slot (a party slot for the Eggs) and takes the gift, answering YES to the nickname
-- and typing one letter: it must land in that slot, once, as the right species, wearing the name,
-- with every other Pokemon byte for byte unchanged.
--
-- Setup is debug-side only: six Pokemon from `createmon`, debug Fill PC Boxes Fast, the story
-- flags each giver waits on (injected setflag/setvar), and a coordinate warp next to the giver.
-- Facing the giver, every A, B and mash press is real input through the real script.
--
-- `PW_CAP_ONLY=<text>` runs matching sites, `PW_CAP_SEED=<n>` reseeds the mashes.
local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "CapacityArrivals")

local HUB = 100
local BOXES, PER_BOX = 14, 30
local SLOTS = BOXES * PER_BOX
local BOX_MON = S.BoxPokemon.size
local PARTY_SIZE = 6
local FREED = SLOTS - 1
local CONTEXT_RUNNING, CONTEXT_SHUTDOWN = 0, 2
local REGION_KANTO, REGION_JOHTO, REGION_HOENN = 1, 2, 3
local TEXT_MID, TEXT_INSTANT = 1, 3
local FLAG_SYS_POKEMON_GET = 0x948
local ONLY = os.getenv("PW_CAP_ONLY") or ""
local SEED = tonumber(os.getenv("PW_CAP_SEED") or "") or 0xCA8

-- ---- memory -------------------------------------------------------------------------------------
local function where() local x, y = F.pos(); return string.format("%d/%d (%d,%d)", F.grp(), F.mapn(), x, y) end
local function partyCount() return F.r8(S.gPartiesCount) end
local function storage() return F.r32(S.gPokemonStoragePtr) end
local function boxAddr(i) return storage() + 4 + i * BOX_MON end
local function partyAddr(i) return S.gParties + i * S.Pokemon.size end
local function occupied(a) return F.r32(a) ~= 0 or F.r32(a + 4) ~= 0 end
local function blob(a, n)
  local t = {}
  for o = 0, n - 4, 4 do t[#t + 1] = string.pack("<I4", F.r32(a + o)) end
  return table.concat(t)
end
local function putBlob(a, s) for o = 0, #s - 4, 4 do F.w32(a + o, string.unpack("<I4", s, o + 1)) end end
local function boxCount() local n = 0; for i = 0, SLOTS - 1 do if occupied(boxAddr(i)) then n = n + 1 end end; return n end
local function snapshot()
  local s = { party = {}, box = {}, count = partyCount() }
  for i = 0, PARTY_SIZE - 1 do s.party[i] = blob(partyAddr(i), S.Pokemon.size) end
  for i = 0, SLOTS - 1 do s.box[i] = blob(boxAddr(i), BOX_MON) end
  return s
end
-- Slots that differ from a snapshot, as "party N" / "box N" names.
local function changed(snap)
  local out = {}
  if partyCount() ~= snap.count then out[#out + 1] = "count " .. snap.count .. "->" .. partyCount() end
  for i = 0, PARTY_SIZE - 1 do if blob(partyAddr(i), S.Pokemon.size) ~= snap.party[i] then out[#out + 1] = "party " .. i end end
  for i = 0, SLOTS - 1 do if blob(boxAddr(i), BOX_MON) ~= snap.box[i] then out[#out + 1] = "box " .. i end end
  return out
end

local function order(p)
  local o = {}
  for i = 0, 3 do o[i] = F.r8(S.sSubstructOffsets + i * 24 + p % 24) * 3 end
  return o
end
local function monSpecies(a)
  local key = F.r32(a) ~ F.r32(a + 4)
  return (F.r32(a + 32 + order(F.r32(a))[0] * 4) ~ key) & 0x7FF
end

-- The nickname's last letter (BoxPokemon nickname at +8, 10 bytes, 0xFF-terminated).
local function lastLetter(a)
  local last = 0
  for i = 0, 9 do
    local c = F.r8(a + 8 + i)
    if c == 0xFF then break end
    last = c
  end
  return last
end
local function flag(id)
  if id >= 0x6000 then
    local off = id - 0x6000
    return (F.r8(F.sb3() + S.SaveBlock3.johtoFlags + off // 8) & (1 << (off % 8))) ~= 0
  end
  return (F.r8(F.sb1() + S.SaveBlock1.flags + id // 8) & (1 << (id % 8))) ~= 0
end
local function var(id)
  if id >= 0xA000 then return F.r16(F.sb3() + S.SaveBlock3.regionVars + (id - 0xA000) * 2) end
  return F.r16(F.sb1() + S.SaveBlock1.vars + (id - 0x4000) * 2)
end
local function key() return F.r32(F.sb2() + S.SaveBlock2.encryptionKey) end
local function money() return F.r32(F.sb1() + S.SaveBlock1.money) ~ key() end
local function setMoney(v) F.w32(F.sb1() + S.SaveBlock1.money, v ~ key()) end
local function coins() return F.r16(F.sb1() + S.SaveBlock1.coins) ~ (key() & 0xFFFF) end
local function setCoins(v) F.w16(F.sb1() + S.SaveBlock1.coins, v ~ (key() & 0xFFFF)) end
local function setRegion(r)
  F.w8(F.sb2() + S.SaveBlock2.currentRegion, r)
  F.w32(S.gCurrentRegion, r)
end
local function setTextSpeed(v)
  local a = F.sb2() + S.SaveBlock2.optionsU16
  F.w16(a, (F.r16(a) & ~7) | v)
end
local function objAt(x, y)
  for i = 0, 15 do
    local b = S.gObjectEvents + i * S.ObjectEvent.stride
    if (F.r8(b) & 1) == 1 and (F.r8(b + 1) & 0x20) == 0
      and F.rs16(b + S.ObjectEvent.x) - 7 == x and F.rs16(b + S.ObjectEvent.y) - 7 == y then return true end
  end
  return false
end
local function hasControl()
  return F.ow() and F.r8(S.sLockFieldControls) == 0 and F.r8(S.sGlobalScriptContextStatus) == CONTEXT_SHUTDOWN
end
local function yesNoUp()
  for i = 0, S.Task.count - 1 do
    local a = S.gTasks + i * S.Task.stride
    local fn = F.r32(a + S.Task.func) & 0xFFFFFFFE
    if F.r8(a + S.Task.isActive) ~= 0 and (fn == S.Task_HandleYesNoInput or fn == S.Task_HandleMultichoiceInput) then
      return true
    end
  end
  return false
end

-- ---- injected scripts (setup only) --------------------------------------------------------------
local SCRIPT_BUF = S.gStringVar4 + 960
local function le16(t, v) t[#t + 1] = v & 0xFF; t[#t + 1] = (v >> 8) & 0xFF end
local function le32(t, v) le16(t, v & 0xFFFF); le16(t, (v >> 16) & 0xFFFF) end
local function runScript(bytes)
  for i, b in ipairs(bytes) do F.w8(SCRIPT_BUF + i - 1, b) end
  F.w8(S.sGlobalScriptContext, 0)
  F.w8(S.sGlobalScriptContext + 1, 1)
  F.w32(S.sGlobalScriptContext + 4, 0)
  F.w32(S.sGlobalScriptContext + S.ScriptCtx.scriptPtr, SCRIPT_BUF)
  F.w8(S.sGlobalScriptContextStatus, CONTEXT_RUNNING)
  for _ = 1, 300 do F.idle(1); if F.r8(S.sGlobalScriptContextStatus) == CONTEXT_SHUTDOWN then break end end
end
local function setflag(id) local b = { 0x29 }; le16(b, id); b[#b + 1] = 0x02; runScript(b) end
local function clearflag(id) local b = { 0x2A }; le16(b, id); b[#b + 1] = 0x02; runScript(b) end
local function setvar(id, v) local b = { 0x16 }; le16(b, id); le16(b, v); b[#b + 1] = 0x02; runScript(b) end
local function additem(id, n) local b = { 0x44 }; le16(b, id); le16(b, n or 1); b[#b + 1] = 0x02; runScript(b) end
local function settrainerflag(id) local b = { 0x61 }; le16(b, id); b[#b + 1] = 0x02; runScript(b) end
local function createmon(species, level)
  local b = { 0x23 }; le32(b, S.ScrCmd_createmon | 1)
  b[#b + 1] = 0; b[#b + 1] = PARTY_SIZE
  le16(b, species); le16(b, level)
  le32(b, (1 << 17) | (1 << 18) | (1 << 19) | (1 << 20))
  for k = 1, 4 do le16(b, k == 1 and 33 or 0) end   -- Tackle only: the Cianwood fisher gives to a party without Surf
  b[#b + 1] = 0x02
  runScript(b)
end
local function warp(g, n, x, y)
  for _ = 1, 30 do
    if hasControl() then break end
    F.press("B", 2); F.idle(20)
  end
  local b = { 0x39, g, n, 0xFF }; le16(b, x); le16(b, y); b[#b + 1] = 0x27; b[#b + 1] = 0x02
  runScript(b)
  for _ = 1, 600 do
    F.idle(4)
    local px, py = F.pos()
    if F.grp() == g and F.mapn() == n and px == x and py == y and hasControl() then F.idle(30); return true end
  end
  return false
end

-- ---- text ---------------------------------------------------------------------------------------
local CH = { [0x00] = " ", [0xAB] = "!", [0xAC] = "?", [0xAD] = ".", [0xB4] = "'", [0xB8] = ",", [0x1B] = "E" }
for i = 0, 9 do CH[0xA1 + i] = string.char(48 + i) end
for i = 0, 25 do CH[0xBB + i] = string.char(65 + i); CH[0xD5 + i] = string.char(65 + i) end
local function shownText()
  local s = {}
  for i = 0, 239 do
    local c = F.r8(S.gStringVar4 + i)
    if c == 0xFF then break end
    s[#s + 1] = CH[c] or " "
  end
  return (table.concat(s):gsub("%s+", " "))
end

-- ---- debug menu (setup only) --------------------------------------------------------------------
local function drain(tries)
  for i = 1, tries or 40 do
    F.press("B", 3); F.idle(20)
    if i % 5 == 0 and F.ensureFree() then return true end
  end
  return F.ensureFree()
end
local function debugAction(path)
  F.dbg(); F.idle(60)
  for i, row in ipairs(path) do
    for _ = 1, row do F.press("Down", 3); F.idle(16) end
    F.press("A", 3); F.idle(i == #path and 240 or 60)
  end
  return drain(20)
end

-- ---- talking ------------------------------------------------------------------------------------
local rngState = 1
local function seedFor(tag)
  local h = SEED
  for i = 1, #tag do h = (h * 31 + tag:byte(i)) & 0x7FFFFFFF end
  rngState = h ~= 0 and h or 1
end
local function rnd(n)
  rngState = (rngState * 1103515245 + 12345) & 0x7FFFFFFF
  return (rngState >> 8) % n
end
local MASH = { "A", "A", "A", "B", "Up", "Down", "Left", "Right", "L", "R", "Start" }

-- "accept": A through every line and YES, B on the nickname question.
-- "name": the same, but YES to the nickname and one letter typed.
-- "mash": a seeded mash of every button but Select, only while the giver's script runs.
local function talk(site, mode, shoot)
  F.face(site.face)
  F.w8(S.gStringVar4, 0xFF)
  F.press("A", 2)
  local said, last, crashed, started, named = {}, nil, false, false, false
  for i = 1, 9000 do
    if i % 30 == 0 and F.reportCrash(site.tag .. "_" .. mode) then crashed = true; break end
    local s = shownText()
    if s ~= last then last = s; if #s > 0 then said[#said + 1] = s end end
    if shoot and s:find(site.refusal, 1, true) then
      F.idle(30); F.shot(site.tag .. "_refusal"); shoot = false
    end
    local live = F.r8(S.sGlobalScriptContextStatus) ~= CONTEXT_SHUTDOWN
    if live then started = true end
    if (started or i > 120) and hasControl() then break end
    local btn
    if mode == "mash" then
      -- Only while the giver's script runs: once it lets go, a stray Start or A is the player
      -- walking into their own menus (the party menu reaches the PC and can release Pokemon).
      if live and rnd(4) == 0 then btn = MASH[rnd(#MASH) + 1] end
    elseif not F.ow() and mode == "name" and not named then
      -- The naming screen: one letter (the keyboard opens on A), Start to OK, A to confirm.
      F.idle(120)
      F.shot(site.tag .. "_naming")
      F.press("A", 2); F.idle(40)
      F.press("Start", 2); F.idle(40)
      F.press("A", 2); F.idle(40)
      named = true
    elseif i % 20 == 0 then
      btn = (s:find("NICKNAME") and yesNoUp()) and (mode == "name" and "A" or "B") or "A"
      if not F.ow() then btn = (i % 40 == 0) and "Start" or "A" end
    end
    joypad.set(btn and { [btn] = true } or {})
    emu.frameadvance()
  end
  joypad.set({})
  for _ = 1, 20 do
    if hasControl() then break end
    F.press("B", 2); F.idle(20)
  end
  F.idle(20)
  return said, hasControl() and not crashed, named
end
local function saidAny(said, pattern)
  for _, s in ipairs(said) do if s:find(pattern, 1, true) then return true end end
  return false
end

-- ---- the givers ---------------------------------------------------------------------------------
local SITES = {
  { tag = "castform", region = REGION_HOENN, g = 32, n = 1, at = { 5, 6 }, face = "Left", species = 351,
    refusal = "NO MORE ROOM",
    prep = function() setvar(0x40B3, 1); setflag(0x37A); clearflag(0x97) end,
    given = function() return flag(0x97) end },
  { tag = "beldum", region = REGION_HOENN, g = 14, n = 7, at = { 3, 3 }, face = "Right", species = 374,
    refusal = "NO MORE ROOM", obj = { 4, 3 },
    prep = function() clearflag(0x3C8); clearflag(0x12A) end,
    given = function() return flag(0x3C8) end },
  { tag = "lileep", region = REGION_HOENN, g = 11, n = 1, at = { 13, 8 }, face = "Right", species = 345,
    refusal = "NO MORE ROOM", walk = "Left",
    prep = function() setvar(0x40C4, 2); setvar(0x40C5, 1) end,
    given = function() return var(0x40C4) ~= 2 end },
  { tag = "cyndaquil", region = REGION_HOENN, g = 1, n = 4, at = { 8, 5 }, face = "Up", species = 155,
    refusal = "NO MORE ROOM", obj = { 8, 4 },
    prep = function() setvar(0x40D3, 5) end,
    given = function() return var(0x40D3) == 6 end },
  { tag = "wynaut_egg", region = REGION_HOENN, g = 0, n = 12, at = { 4, 8 }, face = "Up", species = 360,
    refusal = "NO ROOM FOR THIS EGG", partyOnly = true,
    prep = function() clearflag(0x10A) end,
    given = function() return flag(0x10A) end },
  { tag = "lapras", region = REGION_KANTO, g = 35, n = 53, at = { 1, 7 }, face = "Left", species = 131,
    refusal = "NO MORE ROOM",
    prep = function() clearflag(0xC86) end,
    given = function() return flag(0xC86) end },
  { tag = "magikarp_sale", region = REGION_KANTO, g = 50, n = 0, at = { 2, 3 }, face = "Left", species = 129,
    refusal = "NO MORE ROOM",
    prep = function() clearflag(0xC89); setMoney(500) end,
    given = function() return flag(0xC89) end,
    -- Use this Center's PC first, as a player buying here might: switching it off leaves
    -- VAR_0x8004 at PC_LOCATION_OTHER (0), and the nickname screen must still name the boxed Magikarp.
    before = function()
      if not F.check("magikarp_sale: reach the PC", warp(50, 0, 11, 2), where()) then return end
      F.face("Up")
      F.press("A", 2)
      local menu = false
      for i = 1, 600 do
        if yesNoUp() then menu = true; break end
        F.idle(2)
        if F.r8(S.sGlobalScriptContextStatus) ~= CONTEXT_SHUTDOWN and i % 30 == 0 then F.press("A", 2) end
      end
      F.idle(20); F.press("B", 2)
      for _ = 1, 300 do if hasControl() then break end; F.idle(4) end
      F.check("magikarp_sale: the PC menu opened and switched off", menu and hasControl(), where())
    end },
  { tag = "eevee", region = REGION_KANTO, g = 44, n = 11, at = { 7, 4 }, face = "Up", species = 133,
    refusal = "NO MORE ROOM", obj = { 7, 3 },
    prep = function() clearflag(0xA97) end,
    given = function() return flag(0xA97) end },
  { tag = "hitmonlee", region = REGION_KANTO, g = 48, n = 2, at = { 5, 4 }, face = "Up", species = 106,
    refusal = "NO MORE ROOM", obj = { 5, 3 }, walk = "Right",
    prep = function() settrainerflag(1313); setvar(0xA05A, 1); clearflag(0xAA0); clearflag(0xCB8) end,
    given = function() return flag(0xAA0) end },
  { tag = "tentacool", region = REGION_JOHTO, g = 90, n = 4, at = { 13, 6 }, face = "Right", species = 72,
    refusal = "NO MORE ROOM",
    prep = function() clearflag(0x625D) end,
    given = function() return flag(0x625D) end },
  { tag = "tyrogue", region = REGION_JOHTO, g = 92, n = 12, at = { 16, 5 }, face = "Up", species = 236,
    refusal = "NO MORE ROOM", walk = "Left",
    prep = function() setflag(0x60EC); clearflag(0x60F2) end,
    given = function() return flag(0x60F2) end },
  { tag = "alph_kabuto", region = REGION_JOHTO, g = 79, n = 3, at = { 7, 3 }, face = "Up", species = 140,
    refusal = "NO MORE ROOM", walk = "Left",
    prep = function() setvar(0xA0BC, 2); setvar(0xA0BD, 4) end,
    given = function() return var(0xA0BC) ~= 2 end },
  { tag = "abra_prize", region = REGION_JOHTO, g = 84, n = 12, at = { 16, 4 }, face = "Up", species = 63,
    refusal = "ANY ROOM FOR THIS POKEMON",
    prep = function() if F.itemCount(718) == 0 then additem(718) end; setCoins(9999) end,
    given = function() return coins() ~= 9999 end },
  { tag = "togepi_egg", region = REGION_JOHTO, g = 78, n = 4, at = { 9, 5 }, face = "Up", species = 175,
    refusal = "MAKE ROOM IN YOUR PARTY", partyOnly = true,
    prep = function() clearflag(0x6016); clearflag(0x602F) end,
    given = function() return flag(0x602F) end },
}

-- ---- one giver ----------------------------------------------------------------------------------
local function fullStorageTalk(site, speed, mode)
  local tag = string.format("%s %s %s", site.tag, speed == TEXT_MID and "mid" or "instant", mode)
  site.prep()
  setRegion(site.region)
  setTextSpeed(speed)
  if not F.check(tag .. ": reach the giver", warp(site.g, site.n, site.at[1], site.at[2]), where()) then
    F.shot(site.tag .. "_nowarp")
    return
  end
  local snap, cash, chips = snapshot(), money(), coins()
  seedFor(tag)
  local said, back = talk(site, mode, mode == "accept" and speed == TEXT_INSTANT)
  F.L("  " .. tag .. " said: " .. table.concat(said, " | "))
  F.check(tag .. ": control returns", back, where())
  local diff = changed(snap)
  F.check(tag .. ": every Pokemon stays where it was", #diff == 0, table.concat(diff, ", "))
  F.check(tag .. ": nothing is given", not site.given(), "")
  F.check(tag .. ": money and coins are untouched", money() == cash and coins() == chips,
    string.format("money %d -> %d, coins %d -> %d", cash, money(), chips, coins()))
  if site.obj then
    F.check(tag .. ": the gift's ball stays on the table", objAt(site.obj[1], site.obj[2]), "")
  end
  if mode == "accept" then
    F.check(tag .. ": the giver says there is no room", saidAny(said, site.refusal), table.concat(said, " | "))
  end
  local away = site.walk or (site.face == "Down" and "Up" or "Down")
  F.check(tag .. ": the field is walkable", F.step(away), where())
end

local function controlTalk(site, filler)
  local tag = site.tag .. " one free slot"
  site.prep()
  setRegion(site.region)
  setTextSpeed(TEXT_INSTANT)
  if site.partyOnly then
    putBlob(partyAddr(5), string.rep("\0", S.Pokemon.size))
    F.w8(S.gPartiesCount, 5)
  else
    putBlob(boxAddr(FREED), string.rep("\0", BOX_MON))
  end
  if site.before then site.before() end
  if not F.check(tag .. ": reach the giver", warp(site.g, site.n, site.at[1], site.at[2]), where()) then return end
  local snap = snapshot()
  local said, back, named = talk(site, "name")
  F.L("  " .. tag .. " said: " .. table.concat(said, " | "))
  F.check(tag .. ": control returns", back, where())
  local diff = changed(snap)
  local slot = site.partyOnly and partyAddr(5) or boxAddr(FREED)
  local want = site.partyOnly and { "count 5->6", "party 5" } or { "box " .. FREED }
  F.check(tag .. ": the gift fills that one slot and no other Pokemon changes", table.concat(diff, ",") == table.concat(want, ","), table.concat(diff, ", "))
  F.check(tag .. ": the gift is the right species", monSpecies(slot) == site.species,
    "species=" .. monSpecies(slot))
  F.check(tag .. ": the gift is recorded", site.given(), "")
  if named then
    F.check(tag .. ": the nickname typed goes on the gift", lastLetter(slot) == 0xBB,
      string.format("last letter 0x%02X", lastLetter(slot)))
  end
  F.check(tag .. ": no refusal line", not saidAny(said, site.refusal), table.concat(said, " | "))
  if site.partyOnly then putBlob(partyAddr(5), filler.party); F.w8(S.gPartiesCount, 6)
  else putBlob(boxAddr(FREED), filler.box) end
end

F.run(function()
  if not F.boot(HUB) then F.check("fresh boot", false); F.finish(); return end
  setflag(FLAG_SYS_POKEMON_GET)
  for _, sp in ipairs({ 16, 19, 21, 10, 13, 41 }) do createmon(sp, 10) end
  F.check("setup: a party of six distinct Pokemon", partyCount() == 6, "count=" .. partyCount())
  F.check("setup: debug Fill PC Boxes Fast fills all 420 slots", debugAction({ 1, 1, 0 }) and boxCount() == SLOTS,
    "boxed=" .. boxCount())
  F.check("setup: box slots decode (box 1 slot 1 is Bulbasaur)", monSpecies(boxAddr(0)) == 1, "species=" .. monSpecies(boxAddr(0)))
  local filler = { box = blob(boxAddr(FREED), BOX_MON), party = blob(partyAddr(5), S.Pokemon.size) }

  for _, site in ipairs(SITES) do
    if ONLY == "" or site.tag:find(ONLY, 1, true) then
      for _, speed in ipairs({ TEXT_INSTANT, TEXT_MID }) do
        fullStorageTalk(site, speed, "accept")
        fullStorageTalk(site, speed, "mash")
      end
      controlTalk(site, filler)
      F.check(site.tag .. ": storage is full again", boxCount() == SLOTS and partyCount() == 6,
        string.format("boxed=%d party=%d", boxCount(), partyCount()))
    end
  end
  F.check("no crash screen", not F.crashScreen())
  F.finish()
end)
