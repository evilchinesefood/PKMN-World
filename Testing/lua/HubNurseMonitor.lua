-- World Transit hub nurse heal must spawn the FRLG 32x16 monitor.
-- Fresh new game. Prior JohtoWhiteoutHeal.lua stood on (14,12) (Chansey column)
-- so A never started RegionHub_EventScript_Nurse. This run stands on (13,11) facing Up.
--
-- Run via Testing/mgba-run.sh Testing/lua/HubNurseMonitor.lua

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "HubNurseMonitor")

local FLAG_HUB_INTRO_TOUR_DONE = 0xDCF
local LOCALID_NURSE, LOCALID_CHANSEY = 1, 2
local HUB_G, HUB_M = 100, 0
local NURSE_X, NURSE_Y = 13, 10
-- (13,11) is the FRLG desk (MB_COUNTER, collision 1). Talk-through stands on (13,12).
local COUNTER_X, COUNTER_Y = 13, 11
local STAND_X, STAND_Y = 13, 12
local MB_COUNTER = 128
local ROW_PARTY_MENU, ROW_SET = 2, 9
local PKMN_SIZE = S.Pokemon.size
local OFF_HP, OFF_MAXHP = S.Pokemon.hp, S.Pokemon.maxHP
local MAIN_VBLANK_COUNTER1 = 0x20
local MAPGRID_COLLISION_MASK, MAPGRID_COLLISION_SHIFT = 0x0C00, 10

-- OAM: 16x16 square/size1; 32x16 h-rect/size2. FRLG monitor palette is POKEBALL_GLOW.
local ST_OAM_SQUARE, ST_OAM_H_RECT = 0, 1
local ST_OAM_SIZE_1, ST_OAM_SIZE_2 = 1, 2
local PAL_GENERAL_0, PAL_POKEBALL_GLOW = 0x1004, 0x1007
-- UsesFrlgPokecenterMonitor returns true for the first four, false for Emerald's
-- gTileset_PokemonCenter.
local TILESET_KANTO_PC     = S.gTileset_Kanto_PokemonCenter
local TILESET_FRLG_PC      = S.gTileset_PokemonCenterFrlg
local TILESET_PC_WHITE     = S.gTileset_PokemonCenter_White
local TILESET_TRAINER_TOWER= S.gTileset_TrainerTower
local TILESET_EMERALD_PC   = S.gTileset_PokemonCenter

local function tilesetName(p)
  if p == TILESET_KANTO_PC then return "gTileset_Kanto_PokemonCenter" end
  if p == TILESET_FRLG_PC then return "gTileset_PokemonCenterFrlg" end
  if p == TILESET_PC_WHITE then return "gTileset_PokemonCenter_White" end
  if p == TILESET_TRAINER_TOWER then return "gTileset_TrainerTower" end
  if p == TILESET_EMERALD_PC then return "gTileset_PokemonCenter (Emerald)" end
  return string.format("unknown:0x%08X", p)
end

local function usesFrlgTileset(p)
  return p == TILESET_KANTO_PC or p == TILESET_FRLG_PC
      or p == TILESET_PC_WHITE or p == TILESET_TRAINER_TOWER
end

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

local function secondaryTileset()
  local layout = F.r32(S.gMapHeader + S.MapHeader.mapLayout)
  if layout < 0x08000000 or layout >= 0x0A000000 then return 0 end
  return F.r32(layout + S.MapLayout.secondaryTileset)
end

local function flagAddr(id) return F.sb1() + S.SaveBlock1.flags + (id // 8) end
local function flagGet(id) return (F.r8(flagAddr(id)) & (1 << (id % 8))) ~= 0 end
local function flagSet(id)
  F.w8(flagAddr(id), F.r8(flagAddr(id)) | (1 << (id % 8)))
end

local function mapLayout() return F.r32(S.gMapHeader + S.MapHeader.mapLayout) end

local function mapBlock(x, y)
  local width = F.r32(S.gBackupMapLayout + S.BackupMapLayout.width)
  local map   = F.r32(S.gBackupMapLayout + S.BackupMapLayout.map)
  local o     = S.BackupMapLayout.mapOffset
  return F.r16(map + ((x + o) + (y + o) * width) * 2)
end

local function metatileAt(x, y)
  return (mapBlock(x, y) >> S.Metatiles.idShift) & S.Metatiles.idMask
end

local function collisionAt(x, y)
  return (mapBlock(x, y) & MAPGRID_COLLISION_MASK) >> MAPGRID_COLLISION_SHIFT
end

-- Reproduces GetAttributeByMetatileIdAndMapLayout (see DoorAnimsRegistered.lua).
local function behaviorAt(x, y)
  local id = metatileAt(x, y)
  local layout = mapLayout()
  local frlgOrJohto = F.r8(layout + S.MapLayout.isFrlg) ~= 0 or F.r8(layout + S.MapLayout.isJohto) ~= 0
  local inPrimary = frlgOrJohto and S.Metatiles.inPrimaryFrlg or S.Metatiles.inPrimary
  local tileset, localId
  if id < inPrimary then
    tileset, localId = F.r32(layout + S.MapLayout.primaryTileset), id
  elseif id < S.Metatiles.total then
    tileset, localId = F.r32(layout + S.MapLayout.secondaryTileset), id - inPrimary
  else
    return -1
  end
  local attrs = F.r32(tileset + S.Tileset.metatileAttributes)
  if (F.r8(tileset + S.Tileset.flags1) & S.Tileset.hasFrlgAttributesBit) ~= 0 then
    return F.r32(attrs + localId * 4) & S.Metatiles.behaviorMaskFrlg
  end
  return F.r16(attrs + localId * 2) & S.Metatiles.behaviorMask
end

local function dumpTile(x, y)
  local blk = mapBlock(x, y)
  F.L(string.format("  tile (%d,%d) block=0x%04X metatile=0x%03X collision=%d behavior=%d",
    x, y, blk, metatileAt(x, y), collisionAt(x, y), behaviorAt(x, y)))
end

local function dumpNurseTiles()
  for y = 10, 13 do
    for x = 6, 16 do
      dumpTile(x, y)
    end
  end
end

local function spriteAt(i)
  local b = S.gSprites + i * S.Sprite.stride
  local flags = F.r16(b + S.Sprite.inUse)
  if (flags & 1) == 0 then return nil end
  local oam = F.r32(b)
  local template = F.r32(b + 0x14)
  local palTag = 0
  if template >= 0x08000000 and template < 0x0A000000 then
    palTag = F.r16(template + 2)
  end
  return {
    i = i,
    shape = (oam >> 14) & 3,
    size = (oam >> 30) & 3,
    x = F.rs16(b + 0x20),
    y = F.rs16(b + 0x22),
    ccx = F.rs8(b + 0x28),
    ccy = F.rs8(b + 0x29),
    template = template,
    palTag = palTag,
    subs = F.r32(b + 0x18),
    invisible = (flags & 4) ~= 0,
    callback = F.r32(b + 0x1C),
  }
end

local function fmtSprite(s)
  if not s then return "none" end
  return string.format(
    "slot%d oam %dx? shape=%d size=%d xy=(%d,%d) ccx=%d pal=0x%04X subs=0x%08X tmpl=0x%08X invis=%s",
    s.i,
    (s.shape == ST_OAM_H_RECT and s.size == ST_OAM_SIZE_2) and 32
      or ((s.shape == ST_OAM_SQUARE and s.size == ST_OAM_SIZE_1) and 16 or -1),
    s.shape, s.size, s.x, s.y, s.ccx, s.palTag, s.subs, s.template,
    s.invisible and "yes" or "no")
end

-- FRLG wide monitor: 32x16 OAM, no subsprite table, POKEBALL_GLOW pal, ccx=-16.
-- Emerald narrow: 16x16 OAM + subsprite table (drawn 24x16), GENERAL_0 pal, ccx=-8.
local function classifyMonitor(s)
  if not s then return "none" end
  local frlgOam = s.shape == ST_OAM_H_RECT and s.size == ST_OAM_SIZE_2
  local emOam = s.shape == ST_OAM_SQUARE and s.size == ST_OAM_SIZE_1
  local romTmpl = s.template >= 0x08000000 and s.template < 0x0A000000
  if frlgOam and s.subs == 0 and romTmpl
     and (s.palTag == PAL_POKEBALL_GLOW or s.ccx == -16) then
    return "frlg32"
  end
  if emOam and s.subs ~= 0 and romTmpl
     and (s.palTag == PAL_GENERAL_0 or s.ccx == -8) then
    return "emerald24"
  end
  if frlgOam and romTmpl then return "frlg32_weak" end
  if emOam and romTmpl and s.y >= 8 and s.y <= 40 and s.x >= 100 and s.x <= 140
     and s.palTag == PAL_GENERAL_0 then
    return "emerald24_weak"
  end
  return "other"
end

local function scanMonitors()
  local best, kind = nil, "none"
  for i = 0, 63 do
    local s = spriteAt(i)
    if s and not s.invisible then
      local k = classifyMonitor(s)
      if k == "frlg32" or k == "emerald24" then
        return s, k
      elseif (k == "frlg32_weak" or k == "emerald24_weak") and not best then
        best, kind = s, k
      end
    end
  end
  -- also accept still-invisible monitors: CreatePokecenterMonitorSprite starts invisible
  -- and SpriteCB reveals it one state later. Catch the pre-glow sprite too.
  if not best then
    for i = 0, 63 do
      local s = spriteAt(i)
      if s then
        local k = classifyMonitor(s)
        if k == "frlg32" or k == "emerald24" or k == "frlg32_weak" or k == "emerald24_weak" then
          return s, k
        end
      end
    end
  end
  return best, kind
end

local function drainB(tries, tag)
  for i = 1, (tries or 50) do
    F.press("B", 3); F.idle(20)
    if F.reportCrash((tag or "drain") .. i) then return false end
  end
  return true
end

-- Mash A through a nurse heal and snapshot the monitor.
local function watchHealGlow(tag, frames)
  local seen, kind, shot = nil, "none", false
  for t = 1, (frames or 1200) do
    if t % 6 == 0 then F.press("A", 2) end
    F.idle(1)
    if t % 30 == 0 and F.reportCrash(tag .. "_glow") then break end
    local s, k = scanMonitors()
    if s and (k == "frlg32" or k == "emerald24" or k == "frlg32_weak" or k == "emerald24_weak") then
      if not seen then
        seen, kind = s, k
        F.L(string.format("  %s monitor %s %s tileset=0x%08X", tag, k, fmtSprite(s), secondaryTileset()))
      end
      if seen and seen.invisible and not s.invisible then
        seen, kind = s, k
      end
      if not shot and not s.invisible then
        F.shot(tag .. "_glow")
        shot = true
      end
    end
    if shot and t > 90 and F.ow() then
      if not s then break end
    end
  end
  if seen and not shot then
    F.shot(tag .. "_glow")
    shot = true
  end
  return seen, kind, shot
end

local function partyHp()
  local n = F.r8(S.gPartiesCount)
  local hp, maxhp = 0, 0
  for i = 0, 5 do
    local b = S.gParties + i * PKMN_SIZE
    local mx = F.r16(b + OFF_MAXHP)
    if mx ~= 0 then
      hp = hp + F.r16(b + OFF_HP)
      maxhp = maxhp + mx
    end
  end
  return hp, maxhp, n
end

local function damageParty()
  for i = 0, 5 do
    local b = S.gParties + i * PKMN_SIZE
    local mx = F.r16(b + OFF_MAXHP)
    if mx ~= 0 then F.w16(b + OFF_HP, 1) end
  end
end

local function tapDown(n)
  for _ = 1, n do F.press("Down", 3); F.idle(16) end
end

-- Close the debug menu without ensureFree() (that would step off the nurse tile).
local function closeDbg()
  for _ = 1, 16 do F.press("B", 3); F.idle(20) end
end

local function setPartyHere()
  F.dbg(); F.idle(60)
  tapDown(ROW_PARTY_MENU); F.press("A", 3); F.idle(60)
  tapDown(ROW_SET)
  F.shot("dbg_setparty_cursor")
  F.press("A", 3); F.idle(180)
  closeDbg()
  local n = F.r8(S.gPartiesCount)
  F.L(string.format("  Set Party count=%d hp=%d/%d", n, partyHp()))
  return n
end

local function lastTalked() return F.r16(S.gSpecialVar_LastTalked) end
local function scriptPtr() return F.r32(S.sGlobalScriptContext + S.ScriptCtx.scriptPtr) end

local function objAt(x, y)
  for i = 0, 15 do
    local b = S.gObjectEvents + i * S.ObjectEvent.stride
    if (F.r8(b) & 1) == 1 then
      local ox = F.rs16(b + S.ObjectEvent.x) - 7
      local oy = F.rs16(b + S.ObjectEvent.y) - 7
      if ox == x and oy == y then
        return {
          i = i,
          localId = F.r8(b + S.ObjectEvent.localId),
          gfx = F.r16(b + S.ObjectEvent.graphicsId),
        }
      end
    end
  end
  return nil
end

local function nurseAdjacent(x, y)
  local dx, dy = x - NURSE_X, y - NURSE_Y
  if dx < 0 then dx = -dx end
  if dy < 0 then dy = -dy end
  return (dx + dy) == 1
end

-- South aisle in front of the desk. y=11 is the counter (solid); (13,12) is the
-- talk-through tile. Prior JohtoWhiteoutHeal used (14,12) and hit Chansey.
local AISLE = { { 16, 6 }, { 6, 6 }, { 6, 12 }, { STAND_X, STAND_Y } }

local function tryStand(x, y, way, tag)
  local px, py = F.pos()
  F.L(string.format("  %s walk to (%d,%d) from (%d,%d)", tag, x, y, px, py))
  local reached
  if way then
    reached = F.route(way, tag)
  else
    reached = F.leg(x, y)
  end
  local rx, ry = F.pos()
  if not reached then
    F.L(string.format("  %s stuck at (%d,%d) want (%d,%d)", tag, rx, ry, x, y))
    F.shot(tag .. "_stuck")
    return false, rx, ry
  end
  return rx == x and ry == y, rx, ry
end

local function talkNurse(faceDir, tag)
  F.face(faceDir or "Up")
  F.idle(20)
  local sx, sy = F.pos()
  F.L(string.format("  %s stand (%d,%d) face %s lastTalked=%d script=0x%08X",
    tag, sx, sy, faceDir or "Up", lastTalked(), scriptPtr()))
  F.shot(tag .. "_before_A")
  F.press("A", 3); F.idle(50)
  local talked = lastTalked()
  local sp = scriptPtr()
  F.L(string.format("  %s after A lastTalked=%d script=0x%08X", tag, talked, sp))
  -- Do NOT use menuLive()/pick(): menuLive taps Down, which moves a Yes/No onto NO.
  -- Up keeps the cursor on YES for both MSGBOX_YESNO and MULTI_YESNO, then A confirms.
  for _ = 1, 16 do
    F.press("Up", 2); F.idle(8)
    F.press("A", 2); F.idle(24)
    local s = scanMonitors()
    if s then break end
  end
  local s, k, shot = watchHealGlow(tag, 900)
  drainB(40, tag .. "_afterheal")
  return s, k, shot, talked, sp
end

F.run(function()
  if not F.boot(HUB_G) then
    F.check("boot to the hub", false)
    F.finish(); return
  end
  assertAlive("boot")
  F.check("booted on MAP_REGION_HUB", F.grp() == HUB_G and F.mapn() == HUB_M,
    string.format("grp=%d map=%d", F.grp(), F.mapn()))

  -- Safety: the walk must not re-arm the intro tour.
  if not flagGet(FLAG_HUB_INTRO_TOUR_DONE) then
    flagSet(FLAG_HUB_INTRO_TOUR_DONE)
    F.L("  set FLAG_HUB_INTRO_TOUR_DONE (boot did not)")
  end
  F.check("FLAG_HUB_INTRO_TOUR_DONE is set", flagGet(FLAG_HUB_INTRO_TOUR_DONE))

  local px, py = F.pos()
  F.L(string.format("  after boot pos=(%d,%d) region=%d", px, py, F.r32(S.gCurrentRegion)))
  F.shot("hub_booted")

  local hubTs = secondaryTileset()
  F.L(string.format("  hub tileset=%s (0x%08X)", tilesetName(hubTs), hubTs))
  F.check("hub_secondary_tileset_is_gTileset_PokemonCenterFrlg",
    hubTs == TILESET_FRLG_PC, tilesetName(hubTs))
  F.check("hub_tileset_is_in_UsesFrlgPokecenterMonitor",
    usesFrlgTileset(hubTs), tilesetName(hubTs))
  F.check("hub_tileset_is_NOT_Emerald_gTileset_PokemonCenter",
    hubTs ~= TILESET_EMERALD_PC, tilesetName(hubTs))

  dumpNurseTiles()
  local nurseObj = objAt(NURSE_X, NURSE_Y)
  F.L(string.format("  nurse object at (%d,%d): %s", NURSE_X, NURSE_Y,
    nurseObj and string.format("localId=%d gfx=0x%04X", nurseObj.localId, nurseObj.gfx) or "ABSENT"))
  F.check("nurse object is on (13,10)",
    nurseObj ~= nil and nurseObj.localId == LOCALID_NURSE,
    nurseObj and string.format("localId=%d", nurseObj.localId) or "ABSENT")

  F.check("(13,11) is the solid FRLG desk (MB_COUNTER), not a stand tile",
    collisionAt(COUNTER_X, COUNTER_Y) ~= 0 and behaviorAt(COUNTER_X, COUNTER_Y) == MB_COUNTER,
    string.format("collision=%d behavior=%d (MB_COUNTER=%d)",
      collisionAt(COUNTER_X, COUNTER_Y), behaviorAt(COUNTER_X, COUNTER_Y), MB_COUNTER))
  F.check("(12,11) and (14,11) are also MB_COUNTER",
    behaviorAt(12, 11) == MB_COUNTER and behaviorAt(14, 11) == MB_COUNTER,
    string.format("b(12,11)=%d b(14,11)=%d", behaviorAt(12, 11), behaviorAt(14, 11)))
  F.check("(13,12) is walkable floor in front of the desk",
    collisionAt(STAND_X, STAND_Y) == 0,
    string.format("collision=%d behavior=%d", collisionAt(STAND_X, STAND_Y), behaviorAt(STAND_X, STAND_Y)))

  local standX, standY, faceDir = STAND_X, STAND_Y, "Up"
  local reached, rx, ry = tryStand(STAND_X, STAND_Y, AISLE, "to_nurse")
  if not reached then
    dumpNurseTiles()
    -- From wherever we are, drop to y=12 then walk to (13,12) without going back east first.
    local fallbacks = {
      { 13, 12, nil, "Up", "fb_13_12_direct" },
      { 12, 12, { { 6, 12 }, { 12, 12 } }, "Right", "fb_12_12" },
      { 14, 12, { { 6, 12 }, { 14, 12 } }, "Left", "fb_14_12" },
    }
    for _, fb in ipairs(fallbacks) do
      local ok, fx, fy = tryStand(fb[1], fb[2], fb[3], fb[5])
      if ok then
        reached, rx, ry = true, fx, fy
        standX, standY, faceDir = fx, fy, fb[4]
        F.L(string.format("  using fallback stand (%d,%d) face %s", standX, standY, faceDir))
        break
      end
    end
  end

  -- Proven nurse-facing tile: (13,12) talks through the MB_COUNTER at (13,11) to (13,10).
  local atStand = rx == STAND_X and ry == STAND_Y
  local adjacent = nurseAdjacent(rx, ry)
  local throughCounter = (rx == 13 and ry == 12) or (rx == 12 and ry == 12) or (rx == 14 and ry == 12)
  F.check("reached (13,11) or a proven nurse-adjacent/counter-talk tile",
    atStand or adjacent or throughCounter,
    string.format("at (%d,%d) want stand (%d,%d) adjacent=%s", rx, ry, STAND_X, STAND_Y, tostring(adjacent)))
  if not (atStand or adjacent or throughCounter) then
    F.shot("never_reached_nurse")
    F.finish(); return
  end
  standX, standY = rx, ry
  F.shot("at_stand")

  -- Seed a party on the stand tile so HP restore is observable. Do not ensureFree() after:
  -- that would step off the counter.
  local n = setPartyHere()
  F.check("debug Set Party published a party", n >= 1, "count=" .. tostring(n))
  local hpBefore, maxBefore = partyHp()
  if n >= 1 and maxBefore > 0 then
    damageParty()
    hpBefore = select(1, partyHp())
    F.check("party HP damaged before heal", hpBefore < maxBefore and hpBefore > 0,
      string.format("hp=%d/%d", hpBefore, maxBefore))
  end
  local sx, sy = F.pos()
  F.check("still on the stand tile after Set Party", sx == standX and sy == standY,
    string.format("at (%d,%d) stand (%d,%d)", sx, sy, standX, standY))

  -- (14,12) facing Up talks through the counter to Chansey. Face Left toward the nurse column.
  if standX == 14 and standY == 12 then faceDir = "Left" end
  if standX == 12 and standY == 12 then faceDir = "Right" end

  local hs, hk, glowShot, talked, sp = talkNurse(faceDir, "hub")
  F.L(string.format("  lastTalked_at_A=%d (nurse=%d chansey=%d) script=0x%08X kind=%s",
    talked, LOCALID_NURSE, LOCALID_CHANSEY, sp, hk))
  F.check("A started RegionHub_EventScript_Nurse (lastTalked is the nurse, not Chansey)",
    talked == LOCALID_NURSE,
    string.format("lastTalked=%d script=0x%08X", talked, sp))

  local hpAfter, maxAfter = partyHp()
  local healedHp = n >= 1 and maxAfter > 0 and hpAfter == maxAfter and hpBefore < maxBefore
  local healRan = (hs ~= nil) or healedHp
  F.check("heal script ran (party HP heal and/or monitor sprite)",
    healRan,
    string.format("monitor=%s hp %d/%d -> %d/%d lastTalked=%d",
      hk, hpBefore, maxBefore, hpAfter, maxAfter, talked))
  if n >= 1 and maxBefore > 0 then
    F.check("party HP restored to full", hpAfter == maxAfter,
      string.format("hp=%d/%d", hpAfter, maxAfter))
  end

  F.L(string.format("  hub monitor verdict %s %s", hk, fmtSprite(hs)))
  F.check("hub_heal_created_a_monitor_sprite", hs ~= nil, hk)
  local okKind = (hk == "frlg32")
  F.check("hub_monitor_kind_is_frlg32_not_emerald24", okKind,
    string.format("kind=%s %s tileset=0x%08X region=%d", hk, fmtSprite(hs),
      secondaryTileset(), F.r32(S.gCurrentRegion)))
  F.check("hub_did_not_get_the_Hoenn_narrow_monitor",
    hk ~= "emerald24" and hk ~= "emerald24_weak",
    string.format("kind=%s %s", hk, fmtSprite(hs)))
  if hs then
    F.check("hub_monitor_oam_is_32x16 (shape=1 size=2)",
      hs.shape == ST_OAM_H_RECT and hs.size == ST_OAM_SIZE_2,
      string.format("shape=%d size=%d (want shape=1 size=2)", hs.shape, hs.size))
    F.check("hub_monitor_has_no_emerald_subsprite_table",
      hs.subs == 0, string.format("subs=0x%08X", hs.subs))
    F.check("hub_monitor_palette_is_POKEBALL_GLOW",
      hs.palTag == PAL_POKEBALL_GLOW, string.format("pal=0x%04X want 0x%04X", hs.palTag, PAL_POKEBALL_GLOW))
  end
  F.check("screenshot of the glow was taken", glowShot == true, tostring(glowShot))

  -- Tileset must still be FRLG after the heal; do not pass on tileset-only.
  local tsAfter = secondaryTileset()
  F.check("hub_tileset_still_gTileset_PokemonCenterFrlg_after_heal",
    tsAfter == TILESET_FRLG_PC, tilesetName(tsAfter))

  F.shot("hub_afterheal")
  assertAlive("hub")
  F.L(string.format("  RESULT stand=(%d,%d) face=%s healRan=%s kind=%s tileset=%s",
    standX, standY, faceDir, tostring(healRan), hk, tilesetName(tsAfter)))
  F.finish()
end)
