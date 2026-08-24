-- v1.5 Johto whiteout/heal-tile landings + Center monitor sprite.
-- Fresh new game: boot the hub, Debug Set Party, write lastHealLocation to the
-- Violet apron (39,46), then white out.
--
-- A. lastHealLocation is the Violet apron (39,46). Force a debug-battle whiteout and
--    require the landing is the migrated Violet heal, not the old Sprout Tower door (30,18).
-- B. Azalea / Goldenrod / Safari Zone Gate heals store the apron (one tile south of the
--    Center door), not the door metatile itself.
-- C. Johto Center heal animation uses the FRLG/wide 32x16 monitor, keyed off tileset not
--    region. Same on the World Transit hub (MAPSEC_DYNAMIC; used to get the Hoenn 24x16).
--
-- Run via Testing/mgba-run.sh Testing/lua/JohtoWhiteoutHeal.lua

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "JohtoWhiteoutHeal")

local HEAL_OFF = S.SaveBlock1.lastHealLocation
local MAIN_VBLANK_COUNTER1 = 0x20
local PKMN_SIZE, OFF_HP, OFF_MAXHP = 100, 86, 88
local BP_STRIDE, BP_HP = 140, 42
local B_OUTCOME_LOST = 2
local WARP_ID_NONE = 255

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

local ROW_PARTY_MENU, ROW_SET, ROW_BATTLE = 2, 9, 10

-- MAP_RUINS_OF_ALPH_PUZZLE_AND_REWARD_CHAMBERS = (5 | (79 << 8))
local RUINS_G, RUINS_M = 79, 5
-- MAP_VIOLET_CITY = (6 | (75 << 8)); Center = (4 | (78 << 8))
local VIOLET_G, VIOLET_M = 75, 6
local VIOLET_PC_G, VIOLET_PC_M = 78, 4
local VIOLET_HEAL = { x = 39, y = 46 }
local VIOLET_OLD  = { x = 30, y = 18 }
local VIOLET_DOOR = { x = 39, y = 45 }
local VIOLET_PC_STAND = { x = 7, y = 4 }   -- whiteout cutscene dest inside the Center

-- Outdoor door tiles vs heal aprons from data/maps/*/map.json + data/heal_locations.json.
local CENTERS = {
  {
    tag = "azalea", name = "AzaleaTown_PokemonCenter",
    g = 81, m = 4, w = 0,
    nurse = { 7, 4 },
    healG = 80, healM = 0, hx = 31, hy = 16, doorX = 31, doorY = 15,
  },
  {
    tag = "goldenrod", name = "GoldenrodCity_PokemonCenter",
    g = 84, m = 17, w = 0,
    nurse = { 7, 4 },
    healG = 83, healM = 0, hx = 28, hy = 37, doorX = 28, doorY = 36,
  },
  {
    tag = "safari", name = "SafariZoneGate_PokemonCenter",
    g = 96, m = 1, w = 0,
    nurse = { 7, 4 },
    healG = 96, healM = 0, hx = 11, hy = 16, doorX = 11, doorY = 15,
  },
}

local HUB = { g = 100, m = 0, w = 0, nurse = { 14, 12 }, face = "Up",
              -- South aisle in front of the FRLG desk. (13,12) is the tour's scripted
              -- counter tile and is solid to walking (follower also parks on it). (14,12)
              -- is the walkable Chansey-column tile; talk facing Up then Left.
              way = { { 16, 6 }, { 6, 6 }, { 6, 12 }, { 14, 12 } } }

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
    g = F.r8(b),
    n = F.r8(b + 1),
    w = F.r8(b + 2),
    x = F.rs16(b + 4),
    y = F.rs16(b + 6),
  }
end

local function fmtHeal(h)
  return string.format("grp=%d map=%d warp=%d xy=(%d,%d)", h.g, h.n, h.w, h.x, h.y)
end

local function logPos(tag)
  local x, y = F.pos()
  local h = lastHeal()
  F.L(string.format("  %s map=(%d,%d) pos=(%d,%d) cb2=0x%08X ow=%s heal %s region=%d",
    tag, F.grp(), F.mapn(), x, y, F.cb2(), tostring(F.ow()), fmtHeal(h), F.r32(S.gCurrentRegion)))
  return x, y, h
end

local function secondaryTileset()
  local layout = F.r32(S.gMapHeader + S.MapHeader.mapLayout)
  if layout < 0x08000000 or layout >= 0x0A000000 then return 0 end
  return F.r32(layout + S.MapLayout.secondaryTileset)
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
  return assertAlive(tag .. "_arrive")
end

local function tapDown(n)
  for _ = 1, n do F.press("Down", 3); F.idle(16) end
end

local function closeDbg()
  for _ = 1, 16 do F.press("B", 3); F.idle(20) end
end

-- DebugParty/HubNurseMonitor: Party is root row 2, Set Party is row 9.
local function setPartyHere()
  F.dbg(); F.idle(60)
  tapDown(ROW_PARTY_MENU); F.press("A", 3); F.idle(60)
  tapDown(ROW_SET)
  F.shot("dbg_setparty_cursor")
  F.press("A", 3); F.idle(180)
  closeDbg()
  local n = F.r8(S.gPartiesCount)
  F.L(string.format("  Set Party count=%d", n))
  return n
end

local function writeLastHeal(g, n, w, x, y)
  local b = F.sb1() + HEAL_OFF
  F.w8(b, g)
  F.w8(b + 1, n)
  F.w8(b + 2, w)
  F.w16(b + 4, x)
  F.w16(b + 6, y)
end

local function startDebugBattle()
  F.dbg(); F.idle(60)
  tapDown(ROW_PARTY_MENU); F.press("A", 3); F.idle(60)
  tapDown(ROW_BATTLE)
  F.shot("dbg_battle_cursor")
  F.press("A", 3); F.idle(30)
  local started = false
  for i = 1, 800 do
    F.idle(8)
    if F.reportCrash("dbg_battle_" .. i) then return false end
    if not F.ow() then started = true; break end
  end
  F.check("Start Debug Battle left the overworld", started,
    string.format("cb2=0x%08X battlers=%d outcome=%d", F.cb2(), F.battlers(), F.outcome()))
  return started
end

local function zeroPlayerHp()
  for i = 0, 5 do
    local b = S.gParties + i * PKMN_SIZE
    if F.r16(b + OFF_MAXHP) ~= 0 then F.w16(b + OFF_HP, 0) end
  end
  local n = F.battlers()
  if n > 4 then n = 4 end
  for i = 0, n - 1 do
    -- singles: battler 0 is the player. Zero every slot that currently has HP so a
    -- mis-identified side cannot keep the fight alive.
    F.w16(S.gBattleMons + i * BP_STRIDE + BP_HP, 0)
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

local function drain(tries, tag)
  for i = 1, (tries or 50) do
    F.press("B", 3); F.idle(20)
    if i % 5 == 0 and F.ensureFree() then return true end
    if F.reportCrash((tag or "drain") .. i) then return false end
  end
  return F.ensureFree()
end

-- Mash A through a nurse heal (or the whiteout post-heal) and snapshot the monitor.
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
      -- don't ensureFree here; it steps. Stop once the sprite is gone and we're OW.
      if not s then break end
    end
  end
  if seen and not shot then
    F.shot(tag .. "_glow")
    shot = true
  end
  return seen, kind, shot
end

local function talkNurse(standX, standY, tag, way, faceDir)
  local x, y = F.pos()
  F.L(string.format("  %s walk to counter (%d,%d) from (%d,%d)", tag, standX, standY, x, y))
  local reached
  if way then
    reached = F.route(way, tag)
  else
    reached = F.leg(standX, standY)
  end
  if not reached then
    local sx, sy = F.pos()
    F.check(tag .. "_reached_nurse_tile", false,
      string.format("stuck at (%d,%d) want (%d,%d)", sx, sy, standX, standY))
    F.shot(tag .. "_stuck")
    return nil, "none"
  end
  local rx, ry = F.pos()
  F.check(tag .. "_reached_nurse_tile", rx == standX and ry == standY,
    string.format("at (%d,%d) want (%d,%d)", rx, ry, standX, standY))
  F.face(faceDir or "Up")
  F.idle(20)
  F.press("A", 3); F.idle(50)
  -- Do NOT use menuLive()/pick(): menuLive taps Down, which moves a Yes/No onto NO.
  -- Up keeps the cursor on YES for both MSGBOX_YESNO and MULTI_YESNO, then A confirms.
  for _ = 1, 16 do
    F.press("Up", 2); F.idle(8)
    F.press("A", 2); F.idle(24)
    local s = scanMonitors()
    if s then break end
  end
  local s, k = watchHealGlow(tag, 900)
  drain(40, tag .. "_afterheal")
  return s, k
end

local function assertMonitorFrlg(tag, s, k)
  F.L(string.format("  %s monitor verdict %s %s", tag, k, fmtSprite(s)))
  local ok = (k == "frlg32" or k == "frlg32_weak")
  F.check(tag .. "_heal_created_a_monitor_sprite", s ~= nil, k)
  F.check(tag .. "_monitor_is_FRLG_wide_32x16_not_Emerald_24x16", ok,
    string.format("kind=%s %s tileset=0x%08X region=%d", k, fmtSprite(s),
      secondaryTileset(), F.r32(S.gCurrentRegion)))
  if s then
    F.check(tag .. "_monitor_oam_is_32x16",
      s.shape == ST_OAM_H_RECT and s.size == ST_OAM_SIZE_2,
      string.format("shape=%d size=%d (want shape=1 size=2)", s.shape, s.size))
    F.check(tag .. "_monitor_has_no_emerald_subsprite_table",
      s.subs == 0, string.format("subs=0x%08X", s.subs))
  end
  return ok
end

F.run(function()
  if not F.boot(100) then
    F.check("boot to the hub", false)
    F.finish(); return
  end
  assertAlive("boot")
  F.check("booted on MAP_REGION_HUB", F.grp() == 100,
    string.format("grp=%d map=%d", F.grp(), F.mapn()))

  local nSet = setPartyHere()
  F.check("Set Party published a Pokemon", nSet > 0, "count=" .. tostring(nSet))

  writeLastHeal(VIOLET_G, VIOLET_M, WARP_ID_NONE, VIOLET_HEAL.x, VIOLET_HEAL.y)
  local xBefore, yBefore, heal0 = logPos("before_whiteout")
  F.shot("before_whiteout")
  F.check("lastHealLocation is Violet City (75,6)",
    heal0.g == VIOLET_G and heal0.n == VIOLET_M,
    fmtHeal(heal0))
  F.check("lastHealLocation warpId is WARP_ID_NONE (255)",
    heal0.w == WARP_ID_NONE, "warp=" .. tostring(heal0.w))
  F.check("lastHealLocation is the migrated apron (39,46), not Sprout Tower (30,18)",
    heal0.x == VIOLET_HEAL.x and heal0.y == VIOLET_HEAL.y,
    fmtHeal(heal0))

  -- ---- A. force a live whiteout --------------------------------------------------------------
  if not startDebugBattle() then
    F.check("whiteout battle started", false)
    F.finish(); return
  end
  F.shot("battle_started")
  for _ = 1, 180 do F.press("B", 2); F.idle(8) end
  local battlersReady = false
  for _ = 1, 400 do
    if F.battlers() > 0 then battlersReady = true; break end
    F.idle(4)
  end
  F.check("debug battle published a battler count", battlersReady,
    "battlers=" .. tostring(F.battlers()))

  local landed, landTag = false, "timeout"
  local monitorDuringWhiteout, monitorKind = nil, "none"
  for t = 1, 2400 do
    F.w8(S.gBattleOutcome, B_OUTCOME_LOST)
    zeroPlayerHp()
    if t % 3 == 0 then F.press("A", 2) else F.press("A", 1) end
    F.idle(1)
    if t % 40 == 0 and F.reportCrash("whiteout_wait_" .. t) then
      landTag = "crash"; break
    end
    local s, k = scanMonitors()
    if s and (k == "frlg32" or k == "emerald24" or k == "frlg32_weak" or k == "emerald24_weak")
       and not monitorDuringWhiteout then
      monitorDuringWhiteout, monitorKind = s, k
      F.L("  whiteout-heal monitor " .. k .. " " .. fmtSprite(s))
      F.shot("whiteout_glow")
    end
    if F.ow() then
      local g, m = F.grp(), F.mapn()
      if g == VIOLET_G or g == VIOLET_PC_G then
        landed, landTag = true, "violet"
        break
      elseif g == RUINS_G and m == RUINS_M then
        -- still the origin: either the battle returned us (we won) or whiteout has not warped yet
        if F.outcome() == 1 then
          landTag = "won"; break
        end
      elseif g ~= RUINS_G then
        landed, landTag = true, string.format("other_%d_%d", g, m)
        break
      end
    end
  end

  -- The cutscene prints "scurried to the POKéMON CENTER" then runs the nurse heal.
  -- Keep watching a bit longer so the glow shot is not a miss on a just-landed map.
  if landed then
    F.idle(30)
    logPos("whiteout_ow")
    F.shot("whiteout_landed")
    if not monitorDuringWhiteout then
      monitorDuringWhiteout, monitorKind = watchHealGlow("whiteout", 1000)
    else
      watchHealGlow("whiteout_drain", 400)
    end
    drain(50, "whiteout_done")
  end

  local xAfter, yAfter, healA = logPos("after_whiteout")
  F.shot("after_whiteout")
  assertAlive("after_whiteout")

  F.check("whiteout returned to the overworld on a Violet map (not a win-return to the ruins)",
    landed and landTag ~= "won",
    string.format("land=%s map=(%d,%d) pos=(%d,%d) outcome=%d cb2=0x%08X",
      landTag, F.grp(), F.mapn(), xAfter, yAfter, F.outcome(), F.cb2()))

  -- Discriminator: the old heal (30,18) fails GetHealLocationIndexByWarpData, so IsWhiteoutCutscene
  -- is false and DoWhiteOut copies lastHealLocation onto the field — outdoor Sprout Tower door.
  -- The migrated (39,46) matches, so the player is rushed into Violet's Center at (7,4).
  local onOldDoor = F.grp() == VIOLET_G and F.mapn() == VIOLET_M
                    and xAfter == VIOLET_OLD.x and yAfter == VIOLET_OLD.y
  local onNewApron = F.grp() == VIOLET_G and F.mapn() == VIOLET_M
                     and math.abs(xAfter - VIOLET_HEAL.x) <= 1
                     and math.abs(yAfter - VIOLET_HEAL.y) <= 1
  local inVioletCenter = F.grp() == VIOLET_PC_G and F.mapn() == VIOLET_PC_M
  F.check("whiteout did NOT land on the old Sprout Tower door (30,18)",
    not onOldDoor,
    string.format("map=(%d,%d) pos=(%d,%d)", F.grp(), F.mapn(), xAfter, yAfter))
  F.check("whiteout landed on the migrated Violet heal (Center interior or apron (39,46))",
    inVioletCenter or onNewApron,
    string.format("map=(%d,%d) pos=(%d,%d) (Center is 78/4; apron is 75/6 (39,46))",
      F.grp(), F.mapn(), xAfter, yAfter))
  F.check("lastHealLocation is still the migrated Violet apron after whiteout",
    healA.g == VIOLET_G and healA.n == VIOLET_M
      and healA.x == VIOLET_HEAL.x and healA.y == VIOLET_HEAL.y,
    fmtHeal(healA))

  -- Claim C, Johto half: the post-whiteout nurse heal is the live animation on a Johto Center.
  F.check("violet_center_secondary_tileset_is_gTileset_Kanto_PokemonCenter",
    secondaryTileset() == TILESET_KANTO_PC, tilesetName(secondaryTileset()))
  F.check("violet_center_tileset_is_in_UsesFrlgPokecenterMonitor",
    usesFrlgTileset(secondaryTileset()), tilesetName(secondaryTileset()))
  if monitorDuringWhiteout then
    assertMonitorFrlg("violet_whiteout", monitorDuringWhiteout, monitorKind)
  else
    F.L("  no monitor sprite during whiteout cutscene; will retry on an explicit Johto Center heal")
  end

  -- ---- B. Azalea / Goldenrod / Safari Gate heal points --------------------------------------
  local johtoMonitor, johtoKind, johtoTag = monitorDuringWhiteout, monitorKind, "violet_whiteout"
  for _, c in ipairs(CENTERS) do
    if not go(c.g, c.m, c.w, c.tag) then
      F.check(c.tag .. "_lastHeal_is_apron_not_door", false, "warp failed")
    else
      F.shot(c.tag .. "_inside")
      local s, k = talkNurse(c.nurse[1], c.nurse[2], c.tag)
      local h = lastHeal()
      F.L(string.format("  %s lastHeal %s (want apron (%d,%d) door (%d,%d))",
        c.tag, fmtHeal(h), c.hx, c.hy, c.doorX, c.doorY))
      F.check(c.tag .. "_lastHeal_map_is_the_outdoor_town",
        h.g == c.healG and h.n == c.healM, fmtHeal(h))
      F.check(c.tag .. "_lastHeal_xy_is_the_apron_from_heal_locations.json",
        h.x == c.hx and h.y == c.hy,
        string.format("%s want (%d,%d)", fmtHeal(h), c.hx, c.hy))
      F.check(c.tag .. "_lastHeal_is_NOT_the_Center_door_tile",
        not (h.x == c.doorX and h.y == c.doorY),
        string.format("%s door=(%d,%d)", fmtHeal(h), c.doorX, c.doorY))
      F.check(c.tag .. "_lastHeal_is_one_tile_south_of_the_door",
        h.x == c.doorX and h.y == c.doorY + 1,
        string.format("%s door=(%d,%d)", fmtHeal(h), c.doorX, c.doorY))
      if s and not johtoMonitor then
        johtoMonitor, johtoKind, johtoTag = s, k, c.tag
      elseif s and (k == "frlg32" or k == "frlg32_weak") and (johtoKind ~= "frlg32" and johtoKind ~= "frlg32_weak") then
        johtoMonitor, johtoKind, johtoTag = s, k, c.tag
      end
      assertAlive(c.tag)
    end
  end

  if not monitorDuringWhiteout then
    if johtoMonitor then
      assertMonitorFrlg("johto_center", johtoMonitor, johtoKind)
    else
      F.check("johto_center_heal_created_a_monitor_sprite", false,
        "no monitor seen on whiteout or Azalea/Goldenrod/Safari heals")
    end
  end

  -- ---- C. World Transit hub (MAPSEC_DYNAMIC; tileset is still FRLG) --------------------------
  if go(HUB.g, HUB.m, HUB.w, "hub") then
    -- decline any leftover intro-tour prompt without taking a tour branch
    for _ = 1, 20 do
      F.press("B", 3); F.idle(20)
      if F.ensureFree() then break end
    end
    F.shot("hub_inside")
    local hubTs = secondaryTileset()
    F.L(string.format("  hub tileset=%s region=%d mapsec=DYNAMIC", tilesetName(hubTs), F.r32(S.gCurrentRegion)))
    F.check("hub_secondary_tileset_is_gTileset_PokemonCenterFrlg",
      hubTs == TILESET_FRLG_PC, tilesetName(hubTs))
    F.check("hub_tileset_is_in_UsesFrlgPokecenterMonitor",
      usesFrlgTileset(hubTs), tilesetName(hubTs))
    F.check("hub_tileset_is_NOT_Emerald_gTileset_PokemonCenter",
      hubTs ~= TILESET_EMERALD_PC, tilesetName(hubTs))
    local hs, hk = talkNurse(HUB.nurse[1], HUB.nurse[2], "hub", HUB.way, HUB.face)
    if not hs then
      -- Chansey is (14,10); facing Up from (14,12) may talk to her. Try the nurse column.
      F.face("Left"); F.idle(16)
      F.press("A", 3); F.idle(40)
      for _ = 1, 16 do
        F.press("Up", 2); F.idle(8)
        F.press("A", 2); F.idle(24)
        if scanMonitors() then break end
      end
      hs, hk = watchHealGlow("hub_left", 900)
      drain(40, "hub_left_afterheal")
    end
    if hs then
      assertMonitorFrlg("hub", hs, hk)
      F.check("hub_did_not_get_the_Hoenn_narrow_monitor",
        hk ~= "emerald24" and hk ~= "emerald24_weak",
        string.format("kind=%s %s", hk, fmtSprite(hs)))
    else
      -- Heal script did not run (counter geometry / Chansey). The function under test
      -- keys off the tileset pointer asserted above, not off a sprite we never spawned.
      F.L("  hub nurse heal did not spawn a monitor; tileset discriminator stands")
    end
    assertAlive("hub")
  end

  F.finish()
end)
