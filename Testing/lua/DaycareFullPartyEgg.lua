-- Route 34 daycare egg with a full party of 6 must NOT overwrite party slot 5.
-- The overworld "no room" branch has to actually run.
--
-- Fresh new game: boot the hub, Debug Set Party, clone slot 0 across 6 slots,
-- then RAM-stuff the daycare and talk to the Route 34 man.
--
-- Run via Testing/mgba-run.sh Testing/lua/DaycareFullPartyEgg.lua

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "DaycareFullPartyEgg")

local PKMN_SIZE = S.Pokemon.size
local BOX_SIZE  = S.BoxPokemon.size
-- GiveEggFromDaycare uses gSaveBlock1Ptr + offsetof(SaveBlock1, daycare) (offspringPersonality
-- at +280). #203: this was hardcoded 0x3434 while global.h claimed /*0x3030*/ and nothing pinned
-- either. It is now ELF-bound via src/load_save.c's STATIC_ASSERT, so a SaveBlock1 insert breaks
-- the build instead of quietly moving this write into a neighbouring field.
local DAYCARE_OFF = S.SaveBlock1.daycare
local DAYCARE_MON = 140             -- second mon at +140
local FLAG_PENDING_EGG = 0x86
local VAR_RESULT = S.gSpecialVar_Result
local VAR_8004   = S.gSpecialVar_0x8004
local LOCALID_MAN = 12
local SPECIES_PIDGEY, SPECIES_DITTO = 16, 132
local ROW_PARTY_MENU, ROW_SET = 2, 9
local ROW_GIVE = 3
local ROW_POKE_BASIC = 1
local ROW_DAYCARE_EGG = 8

local R34_G, R34_M, R34_W = 80, 2, 4   -- MAP_ROUTE34 warp 4 = daycare door (31,30)

local SUB0 = {0,0,0,0,0,0,1,1,2,3,2,3,1,1,2,3,2,3,1,1,2,3,2,3}

local function d(n) return (n // 100) % 10, (n // 10) % 10, n % 10 end

local function partyCount() return F.r8(S.gPartiesCount) end
local function slot(i) return S.gParties + i * PKMN_SIZE end
local function sb1() return F.sb1() end

local function scriptPtr()
  return F.r32(S.sGlobalScriptContext + S.ScriptCtx.scriptPtr)
end
local function scriptRunning()
  local p = scriptPtr()
  return p >= 0x08000000 and p < 0x0A000000
end

local function flagByteAddr(id)
  return sb1() + S.SaveBlock1.flags + (id // 8)
end
local function flagGet(id)
  return (F.r8(flagByteAddr(id)) & (1 << (id % 8))) ~= 0
end
local function flagSet(id)
  local a = flagByteAddr(id)
  F.w8(a, F.r8(a) | (1 << (id % 8)))
end

local function daycareBase() return sb1() + DAYCARE_OFF end
local function daycareMon(i) return daycareBase() + i * DAYCARE_MON end
local function offspringPid() return F.r32(daycareBase() + 2 * DAYCARE_MON) end
local function setOffspringPid(v) F.w32(daycareBase() + 2 * DAYCARE_MON, v) end

local function speciesOf(box)
  local pid, ot = F.r32(box), F.r32(box + 4)
  local idx = SUB0[(pid % 24) + 1]
  local w = F.r32(box + 32 + idx * 12) ~ ot ~ pid
  return w & 0x7FF
end
local function isEgg(box) return (F.r8(box + 19) & 0x04) ~= 0 end
local function hasSpecies(box) return (F.r8(box + 19) & 0x02) ~= 0 end

local CHARMAP = {}
for i = 0, 9 do CHARMAP[0xA1 + i] = string.char(48 + i) end
for i = 0, 25 do CHARMAP[0xBB + i] = string.char(65 + i) end
for i = 0, 25 do CHARMAP[0xD5 + i] = string.char(97 + i) end
CHARMAP[0x00] = ""; CHARMAP[0xFF] = ""; CHARMAP[0x7F] = " "
CHARMAP[0xB8] = "."; CHARMAP[0xAE] = "?"; CHARMAP[0xAB] = "!"; CHARMAP[0xB0] = "-"
CHARMAP[0xB1] = "-"; CHARMAP[0xFC] = " "
local function pokeStr(addr, n)
  local t = {}
  for i = 0, (n or 16) - 1 do
    local c = F.r8(addr + i)
    if c == 0xFF then break end
    t[#t + 1] = CHARMAP[c] or string.format("[%02X]", c)
  end
  return table.concat(t)
end

local function snapMon(i)
  local b = slot(i)
  local bytes = {}
  for o = 0, PKMN_SIZE - 1 do bytes[o] = F.r8(b + o) end
  return {
    i = i, pid = F.r32(b), ot = F.r32(b + 4), species = speciesOf(b),
    level = F.r8(b + S.Pokemon.level), hp = F.r16(b + S.Pokemon.hp),
    maxHP = F.r16(b + S.Pokemon.maxHP), egg = isEgg(b), has = hasSpecies(b),
    nick = pokeStr(b + 8, 10), bytes = bytes,
  }
end
local function snapParty()
  local t = { count = partyCount() }
  for i = 0, 5 do t[i] = snapMon(i) end
  return t
end
local function fmtMon(m)
  if not m.has and m.pid == 0 and m.level == 0 then
    return string.format("slot%d EMPTY", m.i)
  end
  return string.format("slot%d sp=%d pid=%08X ot=%08X lv=%d hp=%d/%d egg=%s nick=%s",
    m.i, m.species, m.pid, m.ot, m.level, m.hp, m.maxHP,
    m.egg and "Y" or "n", m.nick)
end
local function dumpParty(tag)
  local n = partyCount()
  F.L(string.format("  party[%s] gPartiesCount=%d", tag, n))
  for i = 0, 5 do F.L("    " .. fmtMon(snapMon(i))) end
end
local function dumpDaycare(tag)
  F.L(string.format("  daycare[%s] offspringPid=%08X pendingFlag=%s VAR_RESULT=%d VAR_8004=%d script=0x%08X",
    tag, offspringPid(), tostring(flagGet(FLAG_PENDING_EGG)),
    F.r16(VAR_RESULT), F.r16(VAR_8004), scriptPtr()))
  for i = 0, 1 do
    local b = daycareMon(i)
    F.L(string.format("    dc[%d] sp=%d pid=%08X has=%s egg=%s steps=%d nick=%s",
      i, speciesOf(b), F.r32(b), tostring(hasSpecies(b)), tostring(isEgg(b)),
      F.r32(b + BOX_SIZE + 36 + 8 + 11 + 1), pokeStr(b + 8, 10)))
  end
  F.L("    gStringVar1=" .. pokeStr(S.gStringVar1, 20))
end
local function dumpVars(tag)
  F.L(string.format("  vars[%s] RESULT=%d 8004=%d script=0x%08X locked=%s",
    tag, F.r16(VAR_RESULT), F.r16(VAR_8004), scriptPtr(), tostring(scriptRunning())))
end

local function copyBytes(dst, src, n)
  for i = 0, n - 1 do F.w8(dst + i, F.r8(src + i)) end
end
local function writeBytes(dst, bytes, n)
  for i = 0, n - 1 do F.w8(dst + i, bytes[i] or 0) end
end
local function zeroBytes(dst, n)
  for i = 0, n - 1 do F.w8(dst + i, 0) end
end
local function restoreMon(i, m)
  writeBytes(slot(i), m.bytes, PKMN_SIZE)
end
local function restoreParty(p)
  for i = 0, 5 do restoreMon(i, p[i]) end
  F.w8(S.gPartiesCount, p.count)
end

local function go(grp, map, warp, tag)
  local gh, gt, go_ = d(grp)
  local mh, mt, mo = d(map)
  local wh, wt, wo = d(warp)
  if not F.warpTo(gh, gt, go_, mh, mt, mo, wh, wt, wo, grp, map, tag) then
    F.check(tag .. "_warped", false, string.format("grp=%d map=%d", F.grp(), F.mapn()))
    return false
  end
  F.idle(60)
  return true
end

local function tapDown(n)
  for _ = 1, n do F.press("Down", 3); F.idle(16) end
end

-- DebugParty/HubNurseMonitor: Party is root row 2, Set Party is row 9.
local function setParty()
  F.dbg(); F.idle(60)
  tapDown(ROW_PARTY_MENU); F.press("A", 3); F.idle(60)
  tapDown(ROW_SET)
  F.shot("dbg_setparty_cursor")
  F.press("A", 3); F.idle(180)
  for _ = 1, 6 do F.press("B", 3); F.idle(20) end
end

-- LevelUpSummary.lua clone: memcpy slot 0 across the other five so count=6.
local function fillPartyToSix()
  local src = S.gParties
  for i = 1, 5 do
    local dst = src + i * PKMN_SIZE
    for off = 0, PKMN_SIZE - 1 do F.w8(dst + off, F.r8(src + off)) end
  end
  F.w8(S.gPartiesCount, 6)
end

-- Species spinner min=1, so the ones digit starts at 1 and Down will not
-- floor it to 0. spin(h,t,o) therefore produces 100*h+10*t+(1+o), and the
-- ones argument is (species%10 - 1).
local function giveBasic(species, tag)
  local before = {}
  for i = 0, 5 do before[i] = snapMon(i).pid end
  F.dbg(); F.idle(60)
  tapDown(ROW_GIVE); F.press("A", 3); F.idle(60)
  tapDown(ROW_POKE_BASIC); F.press("A", 3); F.idle(60)
  local h, t = (species // 100) % 10, (species // 10) % 10
  local o = (species % 10) - 1
  if o < 0 then o = 0 end
  F.spin(h, t, o)
  F.press("A", 2); F.idle(40)
  F.spin(0, 9, 9)                 -- level ~100
  F.press("A", 2); F.idle(90)
  F.bOut(6); F.idle(40)
  dumpParty("after_give_" .. tag)
  local got = -1
  for i = 0, 5 do
    local m = snapMon(i)
    if m.has and m.pid ~= before[i] then got = m.species; break end
  end
  F.L(string.format("  give %s wanted species %d, new slot species=%s", tag, species, tostring(got)))
  return got == species
end

local function debugDaycareEgg()
  local before = offspringPid()
  F.dbg(); F.idle(60)
  tapDown(ROW_GIVE); F.press("A", 3); F.idle(60)
  tapDown(ROW_DAYCARE_EGG); F.shot("dbg_daycare_egg_cursor")
  F.press("A", 3); F.idle(90)
  F.shot("dbg_daycare_egg_after")
  local after = offspringPid()
  local boxed = scriptRunning()
  F.L(string.format("  debug Daycare Egg: pid %08X -> %08X script=%s",
    before, after, tostring(boxed)))
  if boxed then
    F.L("    (incompatible / empty daycare message is up)")
    for _ = 1, 20 do F.press("B", 2); F.idle(20) end
  else
    F.bOut(6); F.idle(30)
  end
  return after ~= 0 and after ~= before or (after ~= 0 and before ~= 0)
end

local function stuffDaycareFromParty(a, b)
  zeroBytes(daycareBase(), DAYCARE_MON * 2 + 8)
  copyBytes(daycareMon(0), slot(a), BOX_SIZE)
  copyBytes(daycareMon(1), slot(b), BOX_SIZE)
  F.w32(daycareMon(0) + BOX_SIZE + 56, 0) -- steps (approx; mail is zeroed)
  F.w32(daycareMon(1) + BOX_SIZE + 56, 0)
end

local function armEgg()
  local orig = snapParty()
  F.check("boot party is 6", orig.count == 6, "count=" .. orig.count)
  if orig.count ~= 6 then return orig, false end

  -- Free two slots, gift Ditto + Pidgey (always compatible), copy their
  -- BoxPokemon into SaveBlock1.daycare, then restore the original six.
  zeroBytes(slot(4), PKMN_SIZE)
  zeroBytes(slot(5), PKMN_SIZE)
  F.w8(S.gPartiesCount, 4)
  dumpParty("slots45_cleared")

  local dittoOk = giveBasic(SPECIES_DITTO, "ditto")
  local pidgeyOk = giveBasic(SPECIES_PIDGEY, "pidgey")
  F.check("debug-gave SPECIES_DITTO (132)", dittoOk, "see after_give_ditto dump")
  F.check("debug-gave SPECIES_PIDGEY (16)", pidgeyOk, "see after_give_pidgey dump")
  local n = partyCount()
  F.L("  after gifts count=" .. n)
  -- Prefer the two gifts; Ditto + anything breedable is compatible.
  local gift, dittoSlot = {}, -1
  for i = 0, 5 do
    local m = snapMon(i)
    if m.species == SPECIES_DITTO then dittoSlot = i; gift[#gift + 1] = i end
  end
  for i = 0, 5 do
    local m = snapMon(i)
    if m.has and m.species ~= SPECIES_DITTO and m.species ~= 0 then
      gift[#gift + 1] = i
      if #gift >= 2 then break end
    end
  end
  F.L(string.format("  gift slots: %s (n=%d) dittoSlot=%d", table.concat(gift, ","), #gift, dittoSlot))
  if #gift < 2 then
    gift = {}
    for i = 0, 5 do if snapMon(i).has then gift[#gift + 1] = i end end
  end
  if #gift < 2 then
    F.check("armed two daycare parents", false, "could not gift Ditto+Pidgey")
    restoreParty(orig)
    return orig, false
  end
  stuffDaycareFromParty(gift[1], gift[2])
  dumpDaycare("stuffed_from_gifts")

  restoreParty(orig)
  dumpParty("restored_original_six")
  F.check("party restored to original 6 after stuffing daycare",
    partyCount() == 6 and snapMon(5).pid == orig[5].pid,
    fmtMon(snapMon(5)))

  -- Confirm the copies landed at daycare+0 / +140 by pid.
  local p0, p1 = F.r32(daycareMon(0)), F.r32(daycareMon(1))
  F.check("daycare slot 0 has a BoxPokemon pid", p0 ~= 0, string.format("pid=%08X", p0))
  F.check("daycare slot 1 has a BoxPokemon pid", p1 ~= 0, string.format("pid=%08X", p1))
  F.L(string.format("  stuffed species dc0=%d dc1=%d", speciesOf(daycareMon(0)), speciesOf(daycareMon(1))))

  setOffspringPid(0)
  local ok = debugDaycareEgg()
  if not ok or offspringPid() == 0 then
    F.L("  debug Daycare Egg did not arm; forcing personality+flag")
    setOffspringPid(0x0E660001)
    flagSet(FLAG_PENDING_EGG)
  end
  flagSet(FLAG_PENDING_EGG)
  if offspringPid() == 0 then setOffspringPid(0x0E660001) end
  dumpDaycare("armed")
  local armed = offspringPid() ~= 0
  F.check("egg is pending (offspringPersonality != 0)", armed,
    string.format("pid=%08X flag=%s", offspringPid(), tostring(flagGet(FLAG_PENDING_EGG))))
  return orig, armed
end

local function findMan()
  for i = 0, 15 do
    local b = S.gObjectEvents + i * S.ObjectEvent.stride
    if (F.r8(b) & 1) == 1 and F.r8(b + S.ObjectEvent.localId) == LOCALID_MAN then
      return {
        x = F.rs16(b + S.ObjectEvent.x) - 7,
        y = F.rs16(b + S.ObjectEvent.y) - 7,
        facing = F.r16(b + S.ObjectEvent.facing) & 0xF,
      }
    end
  end
  return nil
end

local function walkTo(tx, ty, tag)
  local x0, y0 = F.pos()
  F.L(string.format("  walk %s (%d,%d)->(%d,%d)", tag, x0, y0, tx, ty))
  for _ = 1, 80 do
    if F.reportCrash("walk_" .. tag) then return false end
    local x, y = F.pos()
    if x == tx and y == ty then return true end
    local dir
    if x < tx then dir = "Right" elseif x > tx then dir = "Left"
    elseif y < ty then dir = "Down" else dir = "Up" end
    if not F.step(dir) then
      F.L(string.format("  walk %s blocked at (%d,%d)->(%d,%d)", tag, x, y, tx, ty))
      F.shot(tag .. "_stuck")
      return false
    end
  end
  F.L(string.format("  walk %s exhausted at (%d,%d)", tag, F.pos()))
  F.shot(tag .. "_stuck")
  return false
end

-- Flowerbed + fence sit between the daycare door (31,30) and the man
-- (31,34 / 30,34). The dirt path west of the building is the way around.
local function aroundToMan(man)
  local px, py = F.pos()
  F.L(string.format("  aroundToMan from (%d,%d) man=(%d,%d)", px, py, man.x, man.y))
  -- Already adjacent?
  if math.abs(px - man.x) + math.abs(py - man.y) == 1 then
    local faceDir = px < man.x and "Right" or px > man.x and "Left" or py < man.y and "Down" or "Up"
    return px, py, faceDir
  end
  local wps = {
    { 28, 30 },
    { 27, 30 },
    { 27, 36 },
    { 28, 36 },
    { man.x - 1, man.y },
    { man.x, man.y + 1 },
    { man.x, man.y - 1 },
    { man.x + 1, man.y },
  }
  for _, w in ipairs(wps) do
    local x, y = F.pos()
    if math.abs(x - man.x) + math.abs(y - man.y) == 1 then
      local faceDir = x < man.x and "Right" or x > man.x and "Left" or y < man.y and "Down" or "Up"
      return x, y, faceDir
    end
    walkTo(w[1], w[2], string.format("wp_%d_%d", w[1], w[2]))
    x, y = F.pos()
    if math.abs(x - man.x) + math.abs(y - man.y) == 1 then
      local faceDir = x < man.x and "Right" or x > man.x and "Left" or y < man.y and "Down" or "Up"
      return x, y, faceDir
    end
  end
  -- Last resort: poke SaveBlock1 pos + the player object-event coords.
  local talkX, talkY = man.x - 1, man.y
  F.L(string.format("  teleport fallback to (%d,%d)", talkX, talkY))
  F.w16(sb1() + S.SaveBlock1.x, talkX)
  F.w16(sb1() + S.SaveBlock1.y, talkY)
  local oid = F.r8(S.gPlayerAvatar + 5)
  if oid < 16 then
    local b = S.gObjectEvents + oid * S.ObjectEvent.stride
    F.w16(b + S.ObjectEvent.x, talkX + 7)
    F.w16(b + S.ObjectEvent.y, talkY + 7)
  end
  F.idle(20)
  local x, y = F.pos()
  F.L(string.format("  after teleport pos=(%d,%d)", x, y))
  F.shot("teleport")
  if math.abs(x - man.x) + math.abs(y - man.y) == 1 then
    return x, y, x < man.x and "Right" or "Left"
  end
  return nil
end

local function talkAcceptEgg(tag)
  F.shot(tag .. "_before_talk")
  dumpVars(tag .. "_before")
  dumpParty(tag .. "_before")
  dumpDaycare(tag .. "_before")
  local s5 = snapMon(5)
  local count0 = partyCount()
  local pid0 = offspringPid()
  local flag0 = flagGet(FLAG_PENDING_EGG)

  -- Open the script.
  local opened = false
  for t = 1, 40 do
    if F.reportCrash(tag .. "_open") then return nil end
    F.press("A", 2); F.idle(12)
    if scriptRunning() then opened = true; break end
  end
  F.check(tag .. ": daycare man script opened", opened, "script=0x" .. string.format("%08X", scriptPtr()))
  F.shot(tag .. "_opened")
  F.idle(40)

  -- YES on "Do you want the egg?" (default cursor is YES). Keep A; never B.
  local sawBoxAfterYes = false
  local varSnap, shotGuard = {}, false
  for t = 1, 60 do
    if F.reportCrash(tag .. "_yes") then return nil end
    F.press("A", 2); F.idle(18)
    local res, v8004 = F.r16(VAR_RESULT), F.r16(VAR_8004)
    varSnap[#varSnap + 1] = {
      t = t, res = res, v8004 = v8004,
      count = partyCount(), pid = offspringPid(),
      s5pid = F.r32(slot(5)), egg = isEgg(slot(5)),
      script = scriptPtr(),
    }
    if t == 4 or t == 10 or t == 20 then
      F.shot(string.format("%s_t%d", tag, t))
      dumpVars(string.format("%s_t%d", tag, t))
      dumpParty(string.format("%s_t%d", tag, t))
    end
    -- Guard just fired: GetMaxPartySize wrote 6 to VAR_0x8004 and
    -- CalculatePlayerPartyCount wrote the live count to VAR_RESULT.
    -- That happens after the yesno (around t=12). Hold so the printer finishes.
    if not shotGuard and v8004 == 6 and res >= 5 and t >= 11 then
      F.idle(50)
      F.shot(tag .. (res == 6 and "_noroom_box" or "_receive_box"))
      dumpVars(tag .. "_guard")
      shotGuard = true
    end
    if t >= 3 and scriptRunning() then sawBoxAfterYes = true end
    if t >= 8 and not scriptRunning() then break end
  end
  F.shot(tag .. "_after_accept")
  dumpVars(tag .. "_after")
  dumpParty(tag .. "_after")
  dumpDaycare(tag .. "_after")
  F.L(string.format("  %s var trail:", tag))
  for _, v in ipairs(varSnap) do
    F.L(string.format("    t=%d RESULT=%d 8004=%d count=%d offPid=%08X s5pid=%08X egg=%s script=0x%08X",
      v.t, v.res, v.v8004, v.count, v.pid, v.s5pid, tostring(v.egg), v.script))
  end

  -- Face away so extra A cannot re-open him, then drain leftover boxes.
  F.face("Down")
  for _ = 1, 12 do
    if not scriptRunning() then break end
    F.press("A", 2); F.idle(20)
  end
  for _ = 1, 8 do F.press("B", 2); F.idle(16) end

  return {
    opened = opened, sawBox = sawBoxAfterYes,
    before = { count = count0, s5 = s5, pid = pid0, flag = flag0 },
    afterCount = partyCount(), afterS5 = snapMon(5),
    afterPid = offspringPid(), afterFlag = flagGet(FLAG_PENDING_EGG),
    result = F.r16(VAR_RESULT), v8004 = F.r16(VAR_8004),
  }
end

F.run(function()
  if not F.boot(100) then
    F.check("boot to the hub", false,
      string.format("ow=%s grp=%d map=%d", tostring(F.ow()), F.grp(), F.mapn()))
    F.finish(); return
  end
  F.L(string.format("BOOTED grp=%d map=%d pos=(%d,%d) count=%d",
    F.grp(), F.mapn(), select(1, F.pos()), select(2, F.pos()), partyCount()))
  F.shot("booted")
  dumpParty("boot")
  F.check("standing in group 100", F.grp() == 100, "grp=" .. F.grp())

  setParty()
  fillPartyToSix()
  dumpParty("cloned_six")
  F.check("party count is 6", partyCount() == 6, "count=" .. partyCount())

  local orig, armed = armEgg()
  if not orig then F.finish(); return end
  if not armed then
    F.check("could not arm a pending daycare egg", false,
      "daycare offset/NPC lock/compatibility — see log")
    F.finish(); return
  end
  F.check("original six still in party after arming",
    partyCount() == 6 and snapMon(5).pid == orig[5].pid,
    fmtMon(snapMon(5)))

  -- Beat every Johto trainer flag so Route 34 sightlines cannot start a battle.
  local tf = F.sb3() + S.SaveBlock3.johtoTrainerFlags
  for i = 0, 31 do F.w8(tf + i, 0xFF) end

  if not go(R34_G, R34_M, R34_W, "route34") then F.finish(); return end
  F.check("on Route 34", F.grp() == R34_G and F.mapn() == R34_M,
    string.format("grp=%d map=%d", F.grp(), F.mapn()))
  local sx, sy = F.pos()
  F.L(string.format("  Route 34 spawn (%d,%d)", sx, sy))
  F.shot("route34_arrival")
  dumpDaycare("on_route34")

  local man = findMan()
  if not man then
    F.check("daycare man object (localId 12) is on the map", false, "absent")
    -- Indoor fallback: warp into the building and talk to the lady, then
    -- back out; the man is the outdoor collector though, so this is a miss.
    F.finish(); return
  end
  F.L(string.format("  daycare man at (%d,%d) facing=%d", man.x, man.y, man.facing))
  F.check("egg-ready man is at the perm tile (30,34) or default (31,34)",
    (man.x == 30 or man.x == 31) and man.y == 34,
    string.format("(%d,%d)", man.x, man.y))

  local tx, ty, faceDir = aroundToMan(man)
  local atx, aty = F.pos()
  F.check("reached a tile adjacent to the daycare man", tx ~= nil,
    string.format("pos=(%d,%d) man=(%d,%d)", atx, aty, man.x, man.y))
  if not tx then F.finish(); return end
  F.face(faceDir)
  F.idle(20)

  -- ---- Attempt 1: collect while party is full --------------------------------
  local a1 = talkAcceptEgg("full")
  if not a1 then F.finish(); return end

  F.check("full-party: party count stays 6", a1.afterCount == 6,
    "count=" .. a1.afterCount)
  F.check("full-party: slot 5 pid UNCHANGED",
    a1.afterS5.pid == orig[5].pid,
    string.format("before %s | after %s", fmtMon(orig[5]), fmtMon(a1.afterS5)))
  F.check("full-party: slot 5 species UNCHANGED",
    a1.afterS5.species == orig[5].species,
    string.format("before sp=%d after sp=%d", orig[5].species, a1.afterS5.species))
  F.check("full-party: all 6 original pids intact",
    (function()
      for i = 0, 5 do if snapMon(i).pid ~= orig[i].pid then return false end end
      return true
    end)(),
    "see party dump")
  F.check("full-party: a message box / script ran (no-room or otherwise)",
    a1.opened and a1.sawBox, "opened=" .. tostring(a1.opened))
  F.check("full-party: egg still pending (personality not cleared)",
    a1.afterPid ~= 0, string.format("pid=%08X", a1.afterPid))
  F.check("full-party: FLAG_PENDING_DAYCARE_EGG still set",
    a1.afterFlag, "flag=" .. tostring(a1.afterFlag))
  -- If the no-room guard ran, VAR_RESULT (party count) equals VAR_0x8004 (max).
  -- Log it even if the values have since been reused.
  F.L(string.format("  last VAR_RESULT=%d VAR_0x8004=%d (6==6 means guard compared equal)",
    a1.result, a1.v8004))

  local overwritten = a1.afterS5.pid ~= orig[5].pid or a1.afterS5.species ~= orig[5].species
  if overwritten then
    F.L("  *** SLOT 5 WAS OVERWRITTEN — the no-room branch did NOT hold ***")
  else
    F.L("  slot 5 survived the full-party collect attempt (pid+species intact)")
  end
  F.check("full-party: GetMaxPartySize (VAR_0x8004) compared equal to party count (VAR_RESULT)",
    a1.result == 6 and a1.v8004 == 6,
    string.format("RESULT=%d 8004=%d", a1.result, a1.v8004))

  -- ---- Attempt 2: free one slot, collect the egg -----------------------------
  -- Zero slot 5 (the 6th). Compact is unnecessary: 0-4 stay filled, 5 empty.
  zeroBytes(slot(5), PKMN_SIZE)
  F.w8(S.gPartiesCount, 5)
  dumpParty("slot5_cleared")
  F.check("cleared slot 5, party count 5", partyCount() == 5, "count=" .. partyCount())
  F.shot("slot5_cleared")

  -- Re-arm if attempt 1 consumed the egg (the bug path).
  if offspringPid() == 0 then
    F.L("  egg was consumed on the full-party attempt; re-arming personality+flag")
    setOffspringPid(0x0E660001)
    flagSet(FLAG_PENDING_EGG)
  end
  dumpDaycare("before_attempt2")

  -- Re-park on the talk tile (drain/face may have stepped).
  man = findMan() or man
  tx, ty, faceDir = aroundToMan(man)
  if not tx then
    F.check("re-reached the man for attempt 2", false, string.format("pos=(%d,%d)", F.pos()))
    F.finish(); return
  end
  F.face(faceDir)
  F.idle(20)

  local a2 = talkAcceptEgg("room")
  if not a2 then F.finish(); return end

  local after = snapParty()
  local eggSlot = -1
  for i = 0, 5 do if after[i].egg then eggSlot = i; break end end
  F.check("with-room: party count is 6", a2.afterCount == 6, "count=" .. a2.afterCount)
  F.check("with-room: an egg is in the party", eggSlot >= 0, "eggSlot=" .. eggSlot)
  F.check("with-room: slots 0-4 (the previous 5 non-egg mons) are intact",
    (function()
      for i = 0, 4 do
        if after[i].pid ~= orig[i].pid then
          F.L(string.format("    slot %d changed: %s -> %s", i, fmtMon(orig[i]), fmtMon(after[i])))
          return false
        end
      end
      return true
    end)(),
    "see dump")
  F.check("with-room: pending personality cleared (egg was taken)",
    a2.afterPid == 0, string.format("pid=%08X", a2.afterPid))
  F.check("with-room: FLAG_PENDING_DAYCARE_EGG cleared",
    not a2.afterFlag, "flag=" .. tostring(a2.afterFlag))

  F.shot("final")
  dumpParty("final")
  dumpDaycare("final")
  F.L(string.format("  orig slot5 was %s; after-free it was EMPTY; after-collect slot5=%s eggSlot=%d",
    fmtMon(orig[5]), fmtMon(after[5]), eggSlot))
  F.finish()
end)
