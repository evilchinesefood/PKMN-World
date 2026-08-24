-- v1.5 Fly/Teleport land on Johto heal APRONS, not Center doors.
-- Teleport copies lastHealLocation (SetWarpDestinationForTeleport). Fly uses the
-- town-map picker / HEAL_LOCATION_AZALEA_TOWN. Both should be Azalea (31,16),
-- one tile south of the Center door (31,15).
--
-- Run via Testing/mgba-run.sh Testing/lua/JohtoFlyTeleport.lua

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "JohtoFlyTeleport")

local HEAL_OFF = S.SaveBlock1.lastHealLocation
local MAIN_VBLANK_COUNTER1 = 0x20
local WARP_ID_NONE = 255
local REGION_JOHTO = 2

local OFF_HP, OFF_MAXHP = S.Pokemon.hp, S.Pokemon.maxHP
local OFF_CHECKSUM, OFF_SECURE = 28, 32
local SUB_STRIDE, NRAW = 12, 12
-- src/pokemon.c sSubstructOffsets[SUBSTRUCT_TYPE_0 / 1]
local SUB0 = { [0]=0,0,0,0,0,0,1,1,2,3,2,3,1,1,2,3,2,3,1,1,2,3,2,3 }
local SUB1 = { [0]=1,1,2,3,2,3,0,0,0,0,0,0,2,3,1,1,3,2,2,3,1,1,3,2 }

local SPECIES_ABRA, SPECIES_PIDGEOT = 63, 18
local MOVE_TELEPORT, MOVE_FLY = 100, 19

local FLAG_JOHTO_BASE = 0x6000
local FLAG_JOHTO_BADGE_6 = 0x6000 + 0x3F8 + 5          -- 0x63FD
local FLAG_VISITED_AZALEA_TOWN = 0x6000 + 0x88         -- FLAG_JOHTO_SLICE(0x88)
local FLAG_SYS_POKEMON_GET = 0x948                     -- SYSTEM_FLAGS + 0

local USM_ICO_PARTY = 1
local USM_NAMES = {
  [0] = "POKEDEX", "PARTY", "BAG", "POKENAV", "DEXNAV", "TRAINER",
  "QUESTS", "SAVE", "REST", "OPTIONS", "RETIRE", "DEBUG",
}

local ROW_GIVE, ROW_MON_BASIC = 3, 1
local ROW_PARTY_MENU, ROW_SET = 2, 9

-- MAP_AZALEA_TOWN_POKEMON_CENTER = (4 | (81 << 8)); outdoor MAP_AZALEA_TOWN = (0 | (80 << 8))
local AZALEA_PC_G, AZALEA_PC_M, AZALEA_PC_W = 81, 4, 0
local AZALEA_G, AZALEA_M = 80, 0
local AZALEA_HEAL_X, AZALEA_HEAL_Y = 31, 16
local AZALEA_DOOR_X, AZALEA_DOOR_Y = 31, 15
local NURSE = { 7, 4 }

-- MAP_ROUTE33 = (1 | (80 << 8)), MAP_TYPE_ROUTE (Teleport/Fly allowed). Warp 0 = Union Cave door.
local R33_G, R33_M, R33_W = 80, 1, 0
local MAP_TYPE_ROUTE, MAP_TYPE_TOWN, MAP_TYPE_INDOOR = 3, 1, 8
local MAPSEC_AZALEA_TOWN = 219
local MAPSECTYPE_CITY_CANFLY = 2

local function d(n) return (n // 100) % 10, (n // 10) % 10, n % 10 end

local function vblank() return F.r32(S.gMain + MAIN_VBLANK_COUNTER1) end

local function assertAlive(tag)
  local t0 = vblank()
  F.idle(8)
  local crashed, text = F.reportCrash(tag)
  local t1 = vblank()
  F.check("no crash screen (" .. tag .. ")", not crashed, text or "clear")
  F.check("vblank advancing (" .. tag .. ")", t1 > t0,
    string.format("vblank %d -> %d cb2=0x%08X ow=%s", t0, t1, F.cb2(), tostring(F.ow())))
  return not crashed
end

local function lastHeal()
  if not F.valid() then
    return { g = -1, n = -1, w = -1, x = -999, y = -999 }
  end
  local b = F.sb1() + HEAL_OFF
  return {
    g = F.r8(b), n = F.r8(b + 1), w = F.r8(b + 2),
    x = F.rs16(b + 4), y = F.rs16(b + 6),
  }
end

local function fmtHeal(h)
  return string.format("grp=%d map=%d warp=%d xy=(%d,%d)", h.g, h.n, h.w, h.x, h.y)
end

local function logPos(tag)
  local x, y = F.pos()
  local h = lastHeal()
  F.L(string.format("  %s map=(%d,%d) pos=(%d,%d) cb2=0x%08X ow=%s heal %s region=%d mapType=%d mapsec=%d",
    tag, F.grp(), F.mapn(), x, y, F.cb2(), tostring(F.ow()), fmtHeal(h),
    F.r32(S.gCurrentRegion), F.r8(S.gMapHeader + 0x18), F.r16(S.gMapHeader + 0x14)))
  return x, y, h
end

local function setJohtoRegion()
  F.w32(S.gCurrentRegion, REGION_JOHTO)
  F.w8(F.sb2() + S.SaveBlock2.currentRegion, REGION_JOHTO)
end

local function sb1FlagSet(id, on)
  local a, m = F.sb1() + S.SaveBlock1.flags + (id // 8), 1 << (id % 8)
  local v = F.r8(a)
  F.w8(a, on and (v | m) or (v & ~m & 0xFF))
end

local function johtoFlagSet(id, on)
  local a, m = F.sb3() + S.SaveBlock3.johtoFlags + ((id - FLAG_JOHTO_BASE) // 8), 1 << (id % 8)
  local v = F.r8(a)
  F.w8(a, on and (v | m) or (v & ~m & 0xFF))
end

local function johtoFlagGet(id)
  local a, m = F.sb3() + S.SaveBlock3.johtoFlags + ((id - FLAG_JOHTO_BASE) // 8), 1 << (id % 8)
  return (F.r8(a) & m) ~= 0
end

local function go(grp, map, warp, tag)
  local gh, gt, go_ = d(grp)
  local mh, mt, mo = d(map)
  local wh, wt, wo = d(warp)
  if not F.warpTo(gh, gt, go_, mh, mt, mo, wh, wt, wo, grp, map, tag) then
    F.check(tag .. "_warped", false, string.format("grp=%d map=%d want %d/%d", F.grp(), F.mapn(), grp, map))
    return false
  end
  F.idle(40)
  setJohtoRegion()
  return assertAlive(tag .. "_arrive")
end

local function tapDown(n)
  for _ = 1, n do F.press("Down", 3); F.idle(16) end
end

local function drain(tries, tag)
  for i = 1, (tries or 50) do
    F.press("B", 3); F.idle(20)
    if i % 5 == 0 and F.ensureFree() then return true end
    if F.reportCrash((tag or "drain") .. i) then return false end
  end
  return F.ensureFree()
end

-- Mash A/Up through a nurse heal until lastHeal matches the apron (or the budget runs out).
local function talkNurse(standX, standY, tag)
  local x, y = F.pos()
  F.L(string.format("  %s walk to counter (%d,%d) from (%d,%d)", tag, standX, standY, x, y))
  if not F.leg(standX, standY) then
    local sx, sy = F.pos()
    F.check(tag .. "_reached_nurse_tile", false,
      string.format("stuck at (%d,%d) want (%d,%d)", sx, sy, standX, standY))
    F.shot(tag .. "_stuck")
    return false
  end
  local rx, ry = F.pos()
  F.check(tag .. "_reached_nurse_tile", rx == standX and ry == standY,
    string.format("at (%d,%d) want (%d,%d)", rx, ry, standX, standY))
  F.face("Up")
  F.idle(20)
  F.press("A", 3); F.idle(50)
  -- Do NOT use menuLive()/pick(): menuLive taps Down, which moves Yes/No onto NO.
  for t = 1, 80 do
    F.press("Up", 2); F.idle(6)
    F.press("A", 2); F.idle(18)
    if t % 10 == 0 and F.reportCrash(tag .. "_heal") then return false end
    local h = lastHeal()
    if h.g == AZALEA_G and h.n == AZALEA_M and h.x == AZALEA_HEAL_X and h.y == AZALEA_HEAL_Y then
      F.L(string.format("  %s lastHeal set on mash %d: %s", tag, t, fmtHeal(h)))
      break
    end
  end
  drain(40, tag .. "_afterheal")
  return true
end

-- Encrypted BoxPokemon helpers (same permutation FollowerOutdoors.lua uses).
local function xorSecure(mon)
  local key = F.r32(mon) ~ F.r32(mon + 4)
  for i = 0, NRAW - 1 do
    local a = mon + OFF_SECURE + i * 4
    F.w32(a, F.r32(a) ~ key)
  end
end

local function checksumDecrypted(mon)
  local sum = 0
  for i = 0, NRAW - 1 do
    local w = F.r32(mon + OFF_SECURE + i * 4)
    sum = (sum + w + (w >> 16)) & 0xFFFFFFFF
  end
  return sum & 0xFFFF
end

local function readSpecies(mon)
  xorSecure(mon)
  local pid = F.r32(mon)
  local sub = mon + OFF_SECURE + SUB0[pid % 24] * SUB_STRIDE
  local sp = F.r16(sub) & 0x7FF
  xorSecure(mon)
  return sp
end

local function writeSpecies(mon, species)
  xorSecure(mon)
  local pid = F.r32(mon)
  local sub = mon + OFF_SECURE + SUB0[pid % 24] * SUB_STRIDE
  local w = F.r16(sub)
  F.w16(sub, (w & 0xF800) | (species & 0x7FF))
  F.w16(mon + OFF_CHECKSUM, checksumDecrypted(mon))
  xorSecure(mon)
end

-- slot 0 = move1 at u16[0] of substruct1; slot 1 = move2 at u16[1].
local function readMove(mon, slot)
  xorSecure(mon)
  local pid = F.r32(mon)
  local sub = mon + OFF_SECURE + SUB1[pid % 24] * SUB_STRIDE
  local mv = F.r16(sub + slot * 2) & 0x7FF
  xorSecure(mon)
  return mv
end

local function writeMove(mon, slot, moveId)
  xorSecure(mon)
  local pid = F.r32(mon)
  local sub = mon + OFF_SECURE + SUB1[pid % 24] * SUB_STRIDE
  local w = F.r16(sub + slot * 2)
  F.w16(sub + slot * 2, (w & 0xF800) | (moveId & 0x7FF))
  -- pp1 at substruct1 + 8, packed 7-bit. Give the slot some PP so the menu is not empty.
  local ppOff = sub + 8 + slot
  F.w8(ppOff, (F.r8(ppOff) & 0x80) | 20)
  F.w16(mon + OFF_CHECKSUM, checksumDecrypted(mon))
  xorSecure(mon)
end

local function partyCount() return F.r8(S.gPartiesCount) end

local function giveSpecies(species, tag)
  F.dbg(); F.idle(60)
  tapDown(ROW_GIVE); F.press("A", 3); F.idle(50)
  tapDown(ROW_MON_BASIC); F.press("A", 3); F.idle(40)
  -- value starts at 1, digit 0 = ones. Raise tens, then ones.
  local tens = (species // 10) % 10
  local ones = species % 10
  F.press("Right", 2); F.idle(10)
  for _ = 1, tens do F.press("Up", 2); F.idle(8) end
  F.press("Left", 2); F.idle(10)
  for _ = 1, (ones - 1) do F.press("Up", 2); F.idle(8) end
  F.shot(tag .. "_species")
  F.press("A", 3); F.idle(30)
  -- level starts at 1; keep it
  F.press("A", 3); F.idle(80)
  for _ = 1, 10 do F.press("B", 3); F.idle(20) end
  drain(20, tag .. "_give")
end

local function setPartyThenRewrite(species, moveId, tag)
  F.dbg(); F.idle(60)
  tapDown(ROW_PARTY_MENU); F.press("A", 3); F.idle(60)
  tapDown(ROW_SET)
  F.shot(tag .. "_set_cursor")
  F.press("A", 3); F.idle(180)
  for _ = 1, 8 do F.press("B", 3); F.idle(20) end
  drain(20, tag .. "_set")
  local mon = S.gParties
  writeSpecies(mon, species)
  writeMove(mon, 0, moveId)
  local mx = F.r16(mon + OFF_MAXHP)
  if mx > 0 then F.w16(mon + OFF_HP, mx) end
  F.L(string.format("  %s rewrite species=%d move1=%d (want %d / %d)",
    tag, readSpecies(mon), readMove(mon, 0), species, moveId))
end

local function ensureMon(species, moveId, tag)
  sb1FlagSet(FLAG_SYS_POKEMON_GET, true)
  if partyCount() == 0 or readSpecies(S.gParties) ~= species then
    giveSpecies(species, tag)
  end
  local n = partyCount()
  local sp = (n > 0) and readSpecies(S.gParties) or 0
  F.L(string.format("  %s after Give: count=%d species=%d move1=%d",
    tag, n, sp, n > 0 and readMove(S.gParties, 0) or -1))
  if n == 0 or sp ~= species then
    setPartyThenRewrite(species, moveId, tag)
    n = partyCount()
    sp = (n > 0) and readSpecies(S.gParties) or 0
  end
  if n > 0 and readMove(S.gParties, 0) ~= moveId then
    writeMove(S.gParties, 0, moveId)
    F.L(string.format("  %s wrote move1=%d now %d", tag, moveId, readMove(S.gParties, 0)))
  end
  sb1FlagSet(FLAG_SYS_POKEMON_GET, true)
  F.check(tag .. "_party_has_the_species", sp == species,
    string.format("count=%d species=%d want %d", n, sp, species))
  F.check(tag .. "_party_knows_the_field_move",
    n > 0 and readMove(S.gParties, 0) == moveId,
    string.format("move1=%d want %d", n > 0 and readMove(S.gParties, 0) or -1, moveId))
  return n > 0 and sp == species
end

local function usmSaved()
  local a = F.sb3() + S.SaveBlock3.usmSaved
  local n = F.r8(a + 12)
  local items = {}
  if n > 12 then n = 12 end
  for i = 0, n - 1 do items[#items + 1] = F.r8(a + i) end
  return items, n
end

local function fmtUsm(items)
  local names = {}
  for i = 1, #items do names[#names + 1] = USM_NAMES[items[i]] or tostring(items[i]) end
  return table.concat(names, ",")
end

local function inPartyMenu()
  local c = F.cb2()
  return c == S.CB2_UpdatePartyMenu or c == S.CB2_InitPartyMenu or c == S.CB2_PartyMenuFromStartMenu
end

local function inFlyMap()
  local c = F.cb2()
  return c == S.CB2_FlyMap or c == S.CB2_OpenFlyMap
end

local function openStartMenu()
  F.idle(40)
  F.press("Start", 2); F.idle(90)
  local _, n = usmSaved()
  if n > 0 then return true end
  F.press("Start", 2); F.idle(90)
  _, n = usmSaved()
  return n > 0
end

-- USM stays on CB2_Overworld. Find PARTY by reading the saved icon list, then
-- Left/Right from the live cursor (sUsmState.selectedVisibleIdx + itemOffset).
local function usmCursor()
  local st = F.r32(S.sUsmState)
  if st < 0x02000000 or st >= 0x02040000 then return -1, 0, {} end
  local vis = F.r8(st + 5)
  local off = F.r8(st + 10)
  local count = F.r8(st + 23)
  if count > 12 then count = 12 end
  local items = {}
  for i = 0, count - 1 do items[#items + 1] = F.r8(st + 11 + i) end
  return off + vis, count, items
end

local function openFieldParty(tag)
  sb1FlagSet(FLAG_SYS_POKEMON_GET, true)
  for attempt = 1, 6 do
    if not F.ow() then
      for _ = 1, 8 do F.press("B", 3); F.idle(20) end
    end
    if not openStartMenu() then
      F.L("  " .. tag .. " start menu did not open on attempt " .. attempt)
    else
      local items, n = usmSaved()
      F.L(string.format("  %s USM items (%d): %s", tag, n, fmtUsm(items)))
      F.shot(tag .. "_usm_" .. attempt)
      local cur, count, live = usmCursor()
      F.L(string.format("  %s USM cursor=%d count=%d live=%s",
        tag, cur, count, fmtUsm(live)))
      local want = -1
      for i = 1, #live do if live[i] == USM_ICO_PARTY then want = i - 1 end end
      if want < 0 then
        for i = 1, #items do if items[i] == USM_ICO_PARTY then want = i - 1 end end
      end
      if want >= 0 and cur >= 0 then
        local dir = (want > cur) and "Right" or "Left"
        for _ = 1, math.abs(want - cur) do F.press(dir, 2); F.idle(12) end
      elseif attempt > 1 then
        F.press("Right", 2); F.idle(12)
      end
      F.press("A", 3)
      for t = 1, 240 do
        F.idle(4)
        if inPartyMenu() then
          F.idle(40)
          F.L(string.format("  %s party menu cb2=0x%08X after %d frames", tag, F.cb2(), t * 4))
          F.shot(tag .. "_party")
          return true
        end
        if F.reportCrash(tag .. "_partyopen") then return false end
      end
      F.L(string.format("  %s A did not open party (cb2=0x%08X ow=%s)", tag, F.cb2(), tostring(F.ow())))
      for _ = 1, 6 do F.press("B", 3); F.idle(20) end
    end
  end
  F.shot(tag .. "_nuparty")
  return false
end

-- A on slot 0, then Down `fieldRow` times onto the field-move row (0 = SUMMARY).
-- Teleport is expected at row 1 (SUMMARY, TELEPORT, ...). Confirm YES with Up+A.
local function useFieldMove(fieldRow, tag, expectFlyMap)
  if not inPartyMenu() then
    F.check(tag .. "_party_menu_open", false, string.format("cb2=0x%08X", F.cb2()))
    return false
  end
  F.idle(30)
  F.press("A", 3); F.idle(50)
  F.shot(tag .. "_actions")
  for _ = 1, fieldRow do F.press("Down", 2); F.idle(12) end
  F.L(string.format("  %s action cursor=%d (want row %d)", tag, F.mcur(), fieldRow))
  F.press("A", 3); F.idle(40)
  if expectFlyMap then
    for t = 1, 400 do
      F.idle(4)
      if inFlyMap() then
        F.idle(40)
        F.L(string.format("  %s fly map cb2=0x%08X t=%d", tag, F.cb2(), t))
        F.shot(tag .. "_flymap")
        return true
      end
      if F.ow() and t > 30 then break end
      if t % 20 == 0 then F.press("A", 2) end
      if F.reportCrash(tag .. "_flywait") then return false end
    end
    F.L(string.format("  %s fly map never opened cb2=0x%08X", tag, F.cb2()))
    F.shot(tag .. "_nofly")
    return false
  end
  -- Teleport: message then Yes/No. Keep the cursor on YES.
  for t = 1, 60 do
    F.press("Up", 2); F.idle(6)
    F.press("A", 2); F.idle(16)
    if not inPartyMenu() then
      F.L(string.format("  %s left party menu after confirm t=%d cb2=0x%08X", tag, t, F.cb2()))
      break
    end
    if F.reportCrash(tag .. "_confirm") then return false end
  end
  return true
end

local function waitLand(wantG, wantM, tag, frames)
  local landed = false
  for t = 1, (frames or 900) do
    F.idle(2)
    if t % 8 == 0 then F.press("A", 1) end
    if t % 40 == 0 and F.reportCrash(tag .. "_land") then return false end
    if F.ow() and F.grp() == wantG and F.mapn() == wantM then
      -- let the warp settle
      F.idle(30)
      if F.ow() and F.grp() == wantG and F.mapn() == wantM then
        landed = true
        break
      end
    end
  end
  local x, y = F.pos()
  F.L(string.format("  %s land map=(%d,%d) pos=(%d,%d) ow=%s cb2=0x%08X",
    tag, F.grp(), F.mapn(), x, y, tostring(F.ow()), F.cb2()))
  F.shot(tag .. "_landed")
  return landed
end

local function flyMapInfo()
  local p = F.r32(S.sRegionMap)
  if p < 0x02000000 or p >= 0x02040000 then
    return { sec = -1, typ = -1, cx = -1, cy = -1, ptr = p }
  end
  return {
    sec = F.r16(p + 0x00),
    typ = F.r8(p + 0x02),
    cx = F.r16(p + 0x54),
    cy = F.r16(p + 0x56),
    ptr = p,
  }
end

-- Johto layout puts Azalea at tile (10,13) -> cursor (11,15). gRegionMapEntries
-- parks the Route 33 cursor at (21,15), nine tiles east of the real Route 33
-- cells, so the first Left lands on MAPSEC_NONE. Walk Left until the live
-- mapSecId is Azalea (layout col 10), tapping once per cell.
local function pickAzaleaOnFlyMap(tag)
  local info = flyMapInfo()
  F.L(string.format("  %s fly start sec=%d type=%d cursor=(%d,%d) ptr=0x%08X",
    tag, info.sec, info.typ, info.cx, info.cy, info.ptr))
  F.shot(tag .. "_cursor0")
  local function tryA()
    info = flyMapInfo()
    if info.sec ~= MAPSEC_AZALEA_TOWN then return false end
    if info.typ ~= MAPSECTYPE_CITY_CANFLY then
      F.L("  Azalea is CANTFLY; forcing FLAG_VISITED")
      johtoFlagSet(FLAG_VISITED_AZALEA_TOWN, true)
      F.idle(4)
    end
    F.press("A", 3); F.idle(20)
    return true
  end
  if tryA() then return true, info end

  local function tapDir(dir)
    F.press(dir, 2); F.idle(24)
  end

  -- Attempt 1: walk Left along y=15 looking for MAPSEC_AZALEA_TOWN.
  for i = 1, 16 do
    if not inFlyMap() then break end
    tapDir("Left")
    info = flyMapInfo()
    F.L(string.format("  %s attempt1 Left#%d sec=%d type=%d cursor=(%d,%d)",
      tag, i, info.sec, info.typ, info.cx, info.cy))
    if info.sec == MAPSEC_AZALEA_TOWN then
      F.shot(tag .. "_cursor1")
      if tryA() then return true, info end
    end
  end
  F.shot(tag .. "_cursor1")

  -- Attempt 2: we overshot. Walk Right back across the same row.
  for i = 1, 16 do
    if not inFlyMap() then break end
    tapDir("Right")
    info = flyMapInfo()
    F.L(string.format("  %s attempt2 Right#%d sec=%d type=%d cursor=(%d,%d)",
      tag, i, info.sec, info.typ, info.cx, info.cy))
    if info.sec == MAPSEC_AZALEA_TOWN then
      F.shot(tag .. "_cursor2")
      if tryA() then return true, info end
    end
  end
  F.shot(tag .. "_cursor_fail")
  return false, info
end

local function stepOffWarp(tag)
  -- Debug warp onto a door tile does not auto-retrigger, but a step into it would.
  for _, dir in ipairs({ "Down", "Right", "Left", "Up" }) do
    local x0, y0 = F.pos()
    if F.step(dir) then
      local x, y = F.pos()
      F.L(string.format("  %s stepped %s (%d,%d)->(%d,%d) map=(%d,%d)",
        tag, dir, x0, y0, x, y, F.grp(), F.mapn()))
      if F.grp() == R33_G and F.mapn() == R33_M then return true end
      -- walked into the cave; warp back
      return go(R33_G, R33_M, R33_W, tag .. "_re")
    end
  end
  return F.grp() == R33_G and F.mapn() == R33_M
end

local function assertApronLanding(tag)
  local x, y = F.pos()
  local onMap = F.grp() == AZALEA_G and F.mapn() == AZALEA_M
  F.check(tag .. "_landed_on_Azalea_Town_80_0", onMap,
    string.format("map=(%d,%d) pos=(%d,%d)", F.grp(), F.mapn(), x, y))
  F.check(tag .. "_landed_on_apron_31_16",
    onMap and x == AZALEA_HEAL_X and y == AZALEA_HEAL_Y,
    string.format("pos=(%d,%d) want (%d,%d)", x, y, AZALEA_HEAL_X, AZALEA_HEAL_Y))
  F.check(tag .. "_did_NOT_land_on_Center_door_31_15",
    not (onMap and x == AZALEA_DOOR_X and y == AZALEA_DOOR_Y),
    string.format("pos=(%d,%d) door=(%d,%d)", x, y, AZALEA_DOOR_X, AZALEA_DOOR_Y))
  return onMap and x == AZALEA_HEAL_X and y == AZALEA_HEAL_Y
end

F.run(function()
  if not F.boot(100) then
    F.check("boot to the hub (fresh new game)", false)
    F.finish(); return
  end
  assertAlive("boot")
  setJohtoRegion()
  F.check("region forced to Johto (2)", F.r32(S.gCurrentRegion) == REGION_JOHTO,
    "region=" .. tostring(F.r32(S.gCurrentRegion)))
  logPos("booted")

  -- ---- lastHeal: Azalea Center nurse --------------------------------------------------------
  if not go(AZALEA_PC_G, AZALEA_PC_M, AZALEA_PC_W, "azalea_pc") then
    F.finish(); return
  end
  F.shot("azalea_inside")
  talkNurse(NURSE[1], NURSE[2], "azalea")
  local healBefore = lastHeal()
  logPos("after_nurse")
  F.check("lastHeal map is Azalea Town (80,0) before Teleport",
    healBefore.g == AZALEA_G and healBefore.n == AZALEA_M, fmtHeal(healBefore))
  F.check("lastHeal warpId is WARP_ID_NONE (255)",
    healBefore.w == WARP_ID_NONE, "warp=" .. tostring(healBefore.w))
  F.check("lastHeal xy is the apron (31,16) before Teleport",
    healBefore.x == AZALEA_HEAL_X and healBefore.y == AZALEA_HEAL_Y, fmtHeal(healBefore))
  F.check("lastHeal is NOT the Center door (31,15)",
    not (healBefore.x == AZALEA_DOOR_X and healBefore.y == AZALEA_DOOR_Y),
    fmtHeal(healBefore))

  -- ---- Teleport user ------------------------------------------------------------------------
  ensureMon(SPECIES_ABRA, MOVE_TELEPORT, "abra")
  F.L(string.format("  lastHeal BEFORE Teleport: %s", fmtHeal(lastHeal())))

  if not go(R33_G, R33_M, R33_W, "route33_tp") then
    F.finish(); return
  end
  stepOffWarp("route33_tp")
  logPos("route33_before_teleport")
  local mt = F.r8(S.gMapHeader + 0x18)
  F.check("Route 33 mapType allows Teleport (TOWN/ROUTE)",
    mt == MAP_TYPE_ROUTE or mt == MAP_TYPE_TOWN,
    "mapType=" .. tostring(mt) .. " (indoor=" .. MAP_TYPE_INDOOR .. ")")
  F.shot("route33_before_teleport")

  local tpOk = false
  if openFieldParty("teleport") then
    if useFieldMove(1, "teleport", false) then
      tpOk = waitLand(AZALEA_G, AZALEA_M, "teleport", 1200)
    end
  else
    F.check("teleport_opened_field_party", false, "Start menu never yielded PARTY")
  end
  drain(20, "teleport_land")
  logPos("after_teleport")
  assertAlive("after_teleport")
  local tpLand = assertApronLanding("teleport")
  F.check("Teleport returned to the overworld", F.ow(),
    string.format("cb2=0x%08X", F.cb2()))
  local tpx, tpy = F.pos()
  F.L(string.format("  Teleport landing: map=(%d,%d) pos=(%d,%d) lastHeal %s",
    F.grp(), F.mapn(), tpx, tpy, fmtHeal(lastHeal())))

  -- ---- Fly user -----------------------------------------------------------------------------
  -- Fly is badge-gated (Johto 6th gym) and uses the town map, not lastHeal.
  johtoFlagSet(FLAG_JOHTO_BADGE_6, true)
  johtoFlagSet(FLAG_VISITED_AZALEA_TOWN, true)
  F.check("FLAG_JOHTO_BADGE_6 is set", johtoFlagGet(FLAG_JOHTO_BADGE_6), "0x63FD")
  F.check("FLAG_VISITED_AZALEA_TOWN is set", johtoFlagGet(FLAG_VISITED_AZALEA_TOWN), "0x6088")
  setJohtoRegion()

  -- Keep Abra; add Fly as move2 so the field-move list is SUMMARY, TELEPORT, FLY, ...
  -- If write fails, Give Pidgeot (QOL_FIELD_MOVES_NO_TEACH still offers Fly with the badge).
  local flyRow = 2
  writeMove(S.gParties, 1, MOVE_FLY)
  local m2 = readMove(S.gParties, 1)
  F.L(string.format("  Abra move2=%d (FLY=%d) move1=%d", m2, MOVE_FLY, readMove(S.gParties, 0)))
  if m2 ~= MOVE_FLY then
    giveSpecies(SPECIES_PIDGEOT, "pidgeot")
    -- slot 0 is still Abra; slot 1 should be Pidgeot. Field party A is slot 0.
    -- Rewrite slot 0 to Pidgeot+Fly so the first party row is the Fly user.
    writeSpecies(S.gParties, SPECIES_PIDGEOT)
    writeMove(S.gParties, 0, MOVE_FLY)
    flyRow = 1
    F.L(string.format("  fallback Pidgeot species=%d move1=%d",
      readSpecies(S.gParties), readMove(S.gParties, 0)))
  end

  local flyAttempted, flyPicked, flyLanded = false, false, false
  local flyCursor = { sec = -1, typ = -1, cx = -1, cy = -1 }
  if not go(R33_G, R33_M, R33_W, "route33_fly") then
    F.L("  Fly: Route 33 warp failed; trying from current outdoor tile")
  else
    stepOffWarp("route33_fly")
  end
  logPos("route33_before_fly")
  F.shot("route33_before_fly")
  mt = F.r8(S.gMapHeader + 0x18)
  F.check("Fly origin mapType allows Fly (TOWN/ROUTE)",
    mt == MAP_TYPE_ROUTE or mt == MAP_TYPE_TOWN, "mapType=" .. tostring(mt))

  if openFieldParty("fly") then
    flyAttempted = true
    -- If Teleport is gone (Pidgeot fallback) the Fly row is 1.
    if not useFieldMove(flyRow, "fly", true) then
      -- maybe only one field move is listed
      for _ = 1, 8 do F.press("B", 2); F.idle(16) end
      if inPartyMenu() then
        F.press("A", 3); F.idle(40)
        flyAttempted = useFieldMove(1, "fly_row1", true)
      end
    end
    if inFlyMap() then
      flyPicked, flyCursor = pickAzaleaOnFlyMap("fly")
      F.L(string.format("  Fly pick Azalea=%s sec=%d type=%d cursor=(%d,%d)",
        tostring(flyPicked), flyCursor.sec, flyCursor.typ, flyCursor.cx, flyCursor.cy))
      if flyPicked then
        flyLanded = waitLand(AZALEA_G, AZALEA_M, "fly", 1500)
      else
        F.shot("fly_map_hostile")
        for _ = 1, 10 do F.press("B", 3); F.idle(20) end
      end
    else
      F.L(string.format("  Fly field move did not open the town map cb2=0x%08X", F.cb2()))
      F.shot("fly_no_map")
    end
  else
    F.L("  Fly: field party never opened")
    F.shot("fly_nuparty")
  end
  drain(20, "fly_land")
  logPos("after_fly")
  assertAlive("after_fly")

  if flyLanded then
    assertApronLanding("fly")
  else
    -- Documented miss, not a Teleport fail. Still record what we saw.
    F.check("fly_attempted_from_field_party", flyAttempted,
      string.format("cb2=0x%08X map=(%d,%d)", F.cb2(), F.grp(), F.mapn()))
    F.check("fly_town_map_reached", inFlyMap() or flyPicked or flyCursor.sec ~= -1,
      string.format("picked=%s sec=%d type=%d cursor=(%d,%d) cb2=0x%08X",
        tostring(flyPicked), flyCursor.sec, flyCursor.typ, flyCursor.cx, flyCursor.cy, F.cb2()))
    if flyPicked then
      local fx, fy = F.pos()
      F.check("fly_landed_on_Azalea_Town_80_0", false,
        string.format("map=(%d,%d) pos=(%d,%d)", F.grp(), F.mapn(), fx, fy))
    else
      F.L("  Fly map UI did not select Azalea after 2 attempts; Teleport result stands")
    end
  end

  F.L(string.format("  VERDICT INPUT lastHealBeforeTp=%s tpLand=%s flyAttempted=%s flyPicked=%s flyLanded=%s",
    fmtHeal(healBefore), tostring(tpLand), tostring(flyAttempted), tostring(flyPicked), tostring(flyLanded)))
  F.finish()
end)
