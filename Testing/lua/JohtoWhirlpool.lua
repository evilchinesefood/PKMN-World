-- Issue #160: Whirlpool / Glacier Badge.
-- EventScript_Whirlpool: lockall, goto_if_unset FLAG_JOHTO_BADGE_7 -> swirling-water
-- msgbox, else playse + applymovement 3 slide_ tiles in facing direction. applymovement
-- does not collide, so the 2x2 invisible Archer blockers are walked over.
--
-- Dragon's Den Cavern whirlpools sit in ELEVATION_SURF water. Warp 0 lands on the
-- north entrance at (31,3); the only land-to-water edge that does not need a prior
-- Surf is the dock at (31,15) facing the 1C6 channel, then the e3->e1 drop at
-- (31,20). F.leg is axis-first, so a greedy walk toward (24,22) from (31,3) dies
-- immediately (only x=31 is open at y=3).
--
-- Run via Testing/mgba-run.sh Testing/lua/JohtoWhirlpool.lua

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "JohtoWhirlpool")

-- ---- maps ------------------------------------------------------------------------------------
local GRP_INDOOR_BLACKTHORN = 94
local MAP_DRAGONS_DEN_CAVERN, MAP_DRAGONS_DEN_SHRINE = 12, 14

-- ---- flags / items / species -----------------------------------------------------------------
local FLAG_JOHTO_BASE = 0x6000
local FLAG_JOHTO_BADGE_7 = 0x6000 + 0x3F8 + 6          -- Glacier Badge, 0x63FE
local FLAG_HIDE_DRAGONS_DEN_CAVERN_CLAIR  = 0x6000 + 0x169
local FLAG_HIDE_DRAGONS_DEN_CAVERN_LANCE  = 0x6000 + 0x16A
local FLAG_HIDE_DRAGONS_DEN_CAVERN_SILVER = 0x6000 + 0x16B
local FLAG_HIDE_DEN_CLAIR                 = 0x6000 + 0x1B3

local TRAINER_FLAGS_START = 0x500
local TRAINER_CARA, TRAINER_DARIN, TRAINER_LEA_AND_PIA = 1005, 1008, 1014

local VARS_START = 0x4000
local VAR_REPEL_STEP_COUNT = 0x4021
local REGION_VARS_START = 0xA000
local VAR_BLACKTHORN_CITY_STATE = 0xA080 + 0x2B        -- VAR_JOHTO_SLICE(0x2B)

-- ITEM_POKEVIAL=874, then CUT_TOOL, SURF_TOOL. Give-item spinner min=1 so
-- spin(h,t,o) yields 1+100h+10t+o; 876 = 1+800+70+5.
local ITEM_SURF_TOOL = 876
local PLAYER_AVATAR_FLAG_SURFING = 1 << 3
local OBJ_EVENT_MON = 1 << 14
local ID_PLAYER, ID_FOLLOWER = 255, 254
local LOCALID_OWE_END, OWE_SPAWNS_MAX = 252, 4
local MAP_OFFSET = 7
local MB_ANIMATED_DOOR = S.MetatileBehavior.ANIMATED_DOOR

-- Whirlpool (24,22): 2x2 blockers (24,21)(25,21)(24,22)(25,22). Approach from
-- the west at (23,22) facing east; 3-tile slide lands on (26,22).
-- Whirlpool (15,39): 2x2 (15,38)(16,38)(15,39)(16,39). Approach from the north
-- at (15,37) facing south; 3-tile slide lands on (15,40), which is the land/water
-- that actually reaches the shrine door's south tile (31,47).
local WP1_APPROACH, WP1_LAND = { 23, 22 }, { 26, 22 }
local WP2_APPROACH, WP2_LAND = { 15, 37 }, { 15, 40 }
local SHRINE_DOOR, SHRINE_FRONT = { 31, 46 }, { 31, 47 }

-- ---- accessors -------------------------------------------------------------------------------
local function johtoFlagSet(id, on)
  local a, m = F.sb3() + S.SaveBlock3.johtoFlags + ((id - FLAG_JOHTO_BASE) // 8), 1 << (id % 8)
  local v = F.r8(a)
  F.w8(a, on and (v | m) or (v & ~m & 0xFF))
end
local function johtoFlagGet(id)
  local a, m = F.sb3() + S.SaveBlock3.johtoFlags + ((id - FLAG_JOHTO_BASE) // 8), 1 << (id % 8)
  return (F.r8(a) & m) ~= 0
end
local function sb1FlagSet(id, on)
  local a, m = F.sb1() + S.SaveBlock1.flags + (id // 8), 1 << (id % 8)
  local v = F.r8(a)
  F.w8(a, on and (v | m) or (v & ~m & 0xFF))
end
local function sb1VarSet(id, v)
  F.w16(F.sb1() + S.SaveBlock1.vars + (id - VARS_START) * 2, v)
end
local function regionVarSet(id, v)
  F.w16(F.sb3() + S.SaveBlock3.regionVars + (id - REGION_VARS_START) * 2, v)
end

local function here()
  local x, y = F.pos()
  return string.format("grp=%d map=%d pos=(%d,%d)", F.grp(), F.mapn(), x, y)
end
local function at(t)
  local x, y = F.pos()
  return x == t[1] and y == t[2]
end
local function surfing()
  return (F.r8(S.gPlayerAvatar) & PLAYER_AVATAR_FLAG_SURFING) ~= 0
end
local function scriptPtr()
  return F.r32(S.sGlobalScriptContext + S.ScriptCtx.scriptPtr)
end
local function crash(tag)
  return F.reportCrash(tag)
end

local function blockAt(x, y)
  local w = F.r32(S.gBackupMapLayout + S.BackupMapLayout.width)
  local map = F.r32(S.gBackupMapLayout + S.BackupMapLayout.map)
  return F.r16(map + ((x + MAP_OFFSET) + (y + MAP_OFFSET) * w) * 2)
end
local function dumpAround(tag)
  local px, py = F.pos()
  local av = S.gPlayerAvatar
  F.L(string.format("  dump %s at (%d,%d) surf=%s script=0x%08X flags=0x%02X preventStep=%d",
    tag, px, py, tostring(surfing()), scriptPtr(), F.r8(av), F.r8(av + 6)))
  for y = py - 2, py + 2 do
    local bits = {}
    for x = px - 3, px + 3 do
      local b = blockAt(x, y)
      bits[#bits + 1] = string.format("%03X/%d%d%s", b & 0x3FF, (b >> 10) & 3, (b >> 12) & 0xF,
        (x == px and y == py) and "*" or " ")
    end
    F.L(string.format("    y=%d %s", y, table.concat(bits, " ")))
  end
end

local function behaviorAt(x, y)
  local id = blockAt(x, y) & S.Metatiles.idMask
  local layout = F.r32(S.gMapHeader + S.MapHeader.mapLayout)
  local frlgOrJohto = F.r8(layout + S.MapLayout.isFrlg) ~= 0
                   or F.r8(layout + S.MapLayout.isJohto) ~= 0
  local inPrimary = frlgOrJohto and S.Metatiles.inPrimaryFrlg or S.Metatiles.inPrimary
  local tileset, localId
  if id < inPrimary then
    tileset, localId = F.r32(layout + S.MapLayout.primaryTileset), id
  elseif id < S.Metatiles.total then
    tileset, localId = F.r32(layout + S.MapLayout.secondaryTileset), id - inPrimary
  else
    return -1, id
  end
  local attrs = F.r32(tileset + S.Tileset.metatileAttributes)
  if (F.r8(tileset + S.Tileset.flags1) & S.Tileset.hasFrlgAttributesBit) ~= 0 then
    return F.r32(attrs + localId * 4) & S.Metatiles.behaviorMaskFrlg, id
  end
  return F.r16(attrs + localId * 2) & S.Metatiles.behaviorMask, id
end

-- Park species OW-mons and generated OWEs so a bump cannot steal the whirlpool A-press.
local PARK_X, PARK_Y = 1 + 7, 1 + 7
local OBJ_PREV_X, OBJ_SPRITE_ID = 0x14, 0x23
local function despawnOwMons()
  local n = 0
  for i = 0, 15 do
    local b = S.gObjectEvents + i * S.ObjectEvent.stride
    if (F.r8(b) & 1) == 1 then
      local id = F.r8(b + S.ObjectEvent.localId)
      local gfx = F.r16(b + S.ObjectEvent.graphicsId)
      local isOwe = id > (LOCALID_OWE_END - OWE_SPAWNS_MAX) and id <= LOCALID_OWE_END
      local isSpecies = (gfx & OBJ_EVENT_MON) ~= 0
      if id ~= ID_PLAYER and id ~= ID_FOLLOWER and (isOwe or isSpecies) then
        local sid = F.r8(b + OBJ_SPRITE_ID)
        if sid < S.Sprite.count then
          local sp = S.gSprites + sid * S.Sprite.stride
          F.w16(sp + S.Sprite.inUse, F.r16(sp + S.Sprite.inUse) & ~1)
        end
        F.w16(b + S.ObjectEvent.x, PARK_X)
        F.w16(b + S.ObjectEvent.y, PARK_Y)
        F.w16(b + OBJ_PREV_X, PARK_X)
        F.w16(b + OBJ_PREV_X + 2, PARK_Y)
        F.w8(b, F.r8(b) & ~1)
        n = n + 1
      end
    end
  end
  return n
end

local function playerObj()
  for i = 0, 15 do
    local b = S.gObjectEvents + i * S.ObjectEvent.stride
    if (F.r8(b) & 1) == 1 and F.r8(b + S.ObjectEvent.localId) == ID_PLAYER then
      return b
    end
  end
  return S.gObjectEvents
end

local function parkFollower()
  for i = 0, 15 do
    local b = S.gObjectEvents + i * S.ObjectEvent.stride
    if (F.r8(b) & 1) == 1 and F.r8(b + S.ObjectEvent.localId) == ID_FOLLOWER then
      F.w16(b + S.ObjectEvent.x, PARK_X)
      F.w16(b + S.ObjectEvent.y, PARK_Y)
      F.w16(b + OBJ_PREV_X, PARK_X)
      F.w16(b + OBJ_PREV_X + 2, PARK_Y)
      F.w8(b + S.ObjectEvent.flags1, F.r8(b + S.ObjectEvent.flags1) | 0x20)
    end
  end
end

-- applymovement-while-surfing leaves player byte0=0xC1 (heldMovementActive+Finished)
-- with action FACE_RIGHT, rewritten every frame. F.step is then a no-op until the
-- bits are cleared on the SAME frame as the input.
local clearHeldEachStep = false
local function stepSafe(dir)
  despawnOwMons()
  if crash("step_" .. dir) then return false end
  if not clearHeldEachStep then return F.step(dir) end
  local x0, y0 = F.pos()
  local pob = playerObj()
  for _ = 1, 40 do
    F.w8(pob + 0x1C, 0xFF)
    F.w8(pob, F.r8(pob) & ~0xC0)
    joypad.set({ [dir] = true }); emu.frameadvance()
    local x, y = F.pos()
    if x ~= x0 or y ~= y0 then
      -- Tile has started. Stop poking heldMovement and stop holding the key;
      -- let the engine finish this one tile.
      for _ = 1, 16 do joypad.set({}); emu.frameadvance() end
      return true
    end
  end
  F.idle(4); return false
end

local function legSafe(tx, ty)
  for _ = 1, 80 do
    local x, y = F.pos()
    if x == tx and y == ty then return true end
    local dir
    if x < tx then dir = "Right" elseif x > tx then dir = "Left"
    elseif y < ty then dir = "Down" else dir = "Up" end
    if not stepSafe(dir) then
      F.L(string.format("    legSafe BLOCKED %s at (%d,%d)->(%d,%d)", dir, x, y, tx, ty))
      crash(string.format("leg_%d_%d", tx, ty))
      return false
    end
  end
  return false
end

local function routeSafe(pts, tag)
  for i, p in ipairs(pts) do
    if not legSafe(p[1], p[2]) then
      local x, y = F.pos()
      F.L(string.format("  ROUTE %s stuck wp%d at (%d,%d)", tag, i, x, y))
      dumpAround(tag .. "_stuck")
      local objs = F.objdump()
      for _, o in ipairs(objs) do
        F.L(string.format("    obj i=%d (%d,%d)", o.i, o.x, o.y))
      end
      F.shot(tag .. "_stuck")
      return false
    end
    if crash(tag .. "_wp" .. i) then return false end
  end
  return true
end

-- A-press the tile in front. Surf's Yes/No defaults to YES, then a "used SURF" box.
-- Fixed A budget: F.step() is a coordinate-change detector and would fire on the hop.
local function tryStartSurf(dir, tag)
  local x0, y0 = F.pos()
  F.face(dir)
  F.idle(20)
  F.L(string.format("  tryStartSurf %s from (%d,%d) %s", dir, x0, y0, tag))
  for _ = 1, 8 do
    F.press("A", 2); F.idle(40)
    if surfing() then break end
    if crash("surf_" .. tag) then return false end
  end
  -- hop animation + music change; do not probe with F.step
  F.idle(200)
  local x1, y1 = F.pos()
  F.L(string.format("  after surf attempt %s surf=%s (%d,%d)->(%d,%d)",
    tag, tostring(surfing()), x0, y0, x1, y1))
  return surfing()
end

local function dismissBox(n)
  for _ = 1, (n or 16) do
    F.press("B", 2); F.idle(24)
    if scriptPtr() == 0 then return true end
  end
  return scriptPtr() == 0
end

-- ---- debug give ------------------------------------------------------------------------------
local function tapDown(n)
  for _ = 1, n do F.press("Down", 3); F.idle(16) end
end

local function giveSurfTool()
  F.dbg(); F.idle(60)
  tapDown(3); F.press("A", 3); F.idle(60)               -- root row 3 = Give X…
  F.press("A", 3); F.idle(60)                           -- row 0 = Give item XYZ…
  F.spin(8, 7, 5)                                      -- 1+800+70+5 = 876
  F.press("A", 2); F.idle(60)
  F.bOut(4); F.idle(60)
end

local function giveLapras()
  F.dbg(); F.idle(60)
  tapDown(3); F.press("A", 3); F.idle(60)               -- Give X…
  tapDown(1); F.press("A", 3); F.idle(60)               -- Pokémon (Basic)
  F.spin(1, 3, 0)                                      -- SPECIES_LAPRAS=131 (spinner min=1)
  F.spin(0, 9, 9)                                      -- level 1+90+9 = 100 (3-digit, min=1)
  F.idle(90)
  F.bOut(4); F.idle(60)
end

-- ---- main ------------------------------------------------------------------------------------
F.run(function()
  if not F.boot(100) then F.check("boot", false); F.finish(); return end
  if crash("post_boot") then F.check("boot survived", false); F.finish(); return end

  -- Party + Surf tool at the hub, where a missed debug press only walks the crest.
  giveLapras()
  local nParty = F.r8(S.gPartiesCount)
  F.check("Lapras reached the party (QOL_FIELD_MOVES_NO_TEACH can then Surf)",
    nParty >= 1, "gPartiesCount=" .. nParty)
  if nParty < 1 then F.shot("no_party"); F.finish(); return end

  local toolSlot = -1
  for _ = 1, 3 do
    giveSurfTool()
    toolSlot = F.keyItemSlot(ITEM_SURF_TOOL)
    if toolSlot >= 0 then break end
    F.bOut(6); F.idle(60)
  end
  F.check("ITEM_SURF_TOOL is in KEY ITEMS (unlocks Surf without Fog Badge)",
    toolSlot >= 0, "slot=" .. tostring(toolSlot))
  if toolSlot < 0 then F.shot("no_surf_tool"); F.finish(); return end

  -- Hide the story NPCs BEFORE the warp -- object visibility is sampled at map load.
  johtoFlagSet(FLAG_HIDE_DRAGONS_DEN_CAVERN_CLAIR, true)
  johtoFlagSet(FLAG_HIDE_DRAGONS_DEN_CAVERN_LANCE, true)
  johtoFlagSet(FLAG_HIDE_DRAGONS_DEN_CAVERN_SILVER, true)
  johtoFlagSet(FLAG_HIDE_DEN_CLAIR, true)
  regionVarSet(VAR_BLACKTHORN_CITY_STATE, 0)
  sb1FlagSet(TRAINER_FLAGS_START + TRAINER_DARIN, true)
  sb1FlagSet(TRAINER_FLAGS_START + TRAINER_CARA, true)
  sb1FlagSet(TRAINER_FLAGS_START + TRAINER_LEA_AND_PIA, true)
  sb1VarSet(VAR_REPEL_STEP_COUNT, 250)
  F.check("FLAG_JOHTO_BADGE_7 is unset on a fresh save",
    not johtoFlagGet(FLAG_JOHTO_BADGE_7), "set=" .. tostring(johtoFlagGet(FLAG_JOHTO_BADGE_7)))

  -- Warp 0: (31,3) entrance. DoorAnimsRegistered uses warp 1, which is the shrine door
  -- in disconnected south water -- not a walk to either whirlpool.
  F.check("warp_to_dragons_den_cavern_entrance",
    F.warpTo(0, 9, 4, 0, 1, 2, 0, 0, 0, GRP_INDOOR_BLACKTHORN, MAP_DRAGONS_DEN_CAVERN,
             "dragonsden") and F.ow(),
    here())
  if crash("after_warp") then F.check("warp survived", false); F.finish(); return end
  F.idle(60)
  despawnOwMons()
  dumpAround("arrival")
  F.shot("dragons_den")

  -- Attempt 1: walk the x=31 corridor to the dock. Do NOT greedy-path toward the
  -- whirlpool: only x=31 is open at y=3.
  local onDock = routeSafe({ { 31, 15 } }, "to_dock")
  F.check("walked the entrance corridor to the dock at (31,15)", onDock, here())
  if not onDock then F.finish(); return end
  dumpAround("dock")
  F.shot("dock")
  sb1VarSet(VAR_REPEL_STEP_COUNT, 250)

  -- Attempt 1b: step onto the e3 1C6 channel if the tile is walkable, then Surf
  -- off the e3->e1 drop. Attempt 2: Surf straight off the dock if the channel is
  -- blocked.
  local gotSurf = false
  if stepSafe("Down") then
    F.L("  stepped south of the dock onto " .. here())
    routeSafe({ { 31, 19 } }, "down_channel")
    dumpAround("channel")
    F.shot("channel")
    gotSurf = tryStartSurf("Down", "channel_drop")
    if not gotSurf then
      gotSurf = tryStartSurf("Left", "channel_west") or tryStartSurf("Right", "channel_east")
    end
  else
    F.L("  dock south is solid -- Surf from (31,15)")
    dumpAround("dock_blocked")
    gotSurf = tryStartSurf("Down", "dock")
  end
  F.check("player is surfing in Dragon's Den (needed to reach either whirlpool)",
    gotSurf or surfing(), here() .. " surf=" .. tostring(surfing()))
  F.shot("after_surf")
  if crash("after_surf") then F.finish(); return end
  if not surfing() then
    F.L("  could not Surf; stopping rather than inventing a pass")
    dumpAround("no_surf")
    F.finish(); return
  end

  sb1VarSet(VAR_REPEL_STEP_COUNT, 250)
  despawnOwMons()
  local toWp1 = routeSafe({ { 31, 20 }, { 23, 20 }, { 23, 22 } }, "to_wp1")
  if not toWp1 then
    -- second honest try: whatever tile we landed on, greedy-path the remaining water
    toWp1 = routeSafe({ WP1_APPROACH }, "to_wp1_direct")
  end
  F.check("reached the (24,22) whirlpool's west approach at (23,22)", toWp1 and at(WP1_APPROACH),
    here())
  if not (toWp1 and at(WP1_APPROACH)) then
    dumpAround("wp1_unreached")
    F.finish(); return
  end
  dumpAround("wp1_approach")
  F.shot("wp1_approach")

  -- WITHOUT Glacier Badge: bump, expect lockall+msgbox, player does not slide 3 tiles.
  F.face("Right")
  F.idle(20)
  local xBefore, yBefore = F.pos()
  F.press("A", 2)
  F.idle(90)                                           -- box opens; do NOT F.step (OlivineHarborBoard trap + heldMovement)
  crash("no_badge_after_a")
  local boxed = scriptPtr() ~= 0
  F.shot("no_badge_box")
  local xMid, yMid = F.pos()
  local noSlide = xMid == xBefore and yMid == yBefore
  F.check("without FLAG_JOHTO_BADGE_7 a bump locks the player (swirling-water box)",
    boxed, here() .. " script=0x" .. string.format("%08X", scriptPtr()))
  F.check("without the badge the player does not slide 3 tiles",
    noSlide, string.format("(%d,%d)->(%d,%d)", xBefore, yBefore, xMid, yMid))
  dismissBox(20)
  F.idle(30)
  if not at(WP1_APPROACH) then routeSafe({ WP1_APPROACH }, "reapproach") end

  -- WITH Glacier Badge: same bump, fixed idle, then read pos. F.step() would fire
  -- mid-applymovement (OlivineHarborBoard trap).
  johtoFlagSet(FLAG_JOHTO_BADGE_7, true)
  F.check("FLAG_JOHTO_BADGE_7 is now set in SaveBlock3.johtoFlags",
    johtoFlagGet(FLAG_JOHTO_BADGE_7))
  F.face("Right")
  F.idle(20)
  xBefore, yBefore = F.pos()
  F.press("A", 2)
  for i = 1, 12 do
    F.idle(20)
    if crash("slide_" .. i) then break end
    local x, y = F.pos()
    if x == WP1_LAND[1] and y == WP1_LAND[2] then break end
  end
  F.idle(40)
  local xAfter, yAfter = F.pos()
  F.shot("with_badge_slid")
  dumpAround("after_slide")
  local slid = (xAfter == WP1_LAND[1] and yAfter == WP1_LAND[2])
            or (math.abs(xAfter - xBefore) + math.abs(yAfter - yBefore) == 3)
  F.check("with FLAG_JOHTO_BADGE_7 the player slides 3 tiles to the far side",
    slid, string.format("(%d,%d)->(%d,%d) want (%d,%d)",
      xBefore, yBefore, xAfter, yAfter, WP1_LAND[1], WP1_LAND[2]))

  -- Shrine path: cross the (15,39) whirlpool (already badged) and walk to (31,47).
  sb1VarSet(VAR_REPEL_STEP_COUNT, 250)
  despawnOwMons()
  -- Let the surf blob finish the slide. A too-early F.step("Right") on the
  -- landing tile jumped 3 tiles (another slide_right) to (29,22).
  F.idle(180)
  local px, py = F.pos()
  local pob = playerObj()
  F.L(string.format("  post-slide settle %s obj=(%d,%d) byte0=0x%02X action=0x%02X",
    here(), F.rs16(pob + S.ObjectEvent.x) - 7, F.rs16(pob + S.ObjectEvent.y) - 7,
    F.r8(pob), F.r8(pob + 0x1C)))
  clearHeldEachStep = true
  px, py = F.pos()
  -- Drive south first onto the y=23 water band, then west. Never walk left on
  -- y=22 -- that is back into the 2x2.
  local toWp2 = routeSafe({ { px, py + 1 }, { 23, py + 1 }, { 23, 29 }, { 22, 29 },
                            { 22, 30 }, { 18, 30 }, { 18, 31 }, { 15, 31 },
                            { 15, 37 } }, "to_wp2")
  F.check("reached the (15,39) whirlpool's north approach at (15,37)",
    toWp2 and at(WP2_APPROACH), here())
  local shrineWalkable = false
  if toWp2 and at(WP2_APPROACH) then
    F.shot("wp2_approach")
    F.face("Down")
    F.idle(20)
    local a0x, a0y = F.pos()
    F.press("A", 2)
    for i = 1, 12 do
      F.idle(20)
      if crash("wp2_slide_" .. i) then break end
      local x, y = F.pos()
      if x == WP2_LAND[1] and y == WP2_LAND[2] then break end
    end
    F.idle(80)
    clearHeldEachStep = true
    local a1x, a1y = F.pos()
    F.shot("wp2_slid")
    F.check("the shrine-path whirlpool also slides 3 tiles south",
      a1x == WP2_LAND[1] and a1y == WP2_LAND[2],
      string.format("(%d,%d)->(%d,%d)", a0x, a0y, a1x, a1y))
    if at(WP2_LAND) then
      parkFollower()
      local toDoor = routeSafe({ { 15, 48 }, { 24, 48 }, { 24, 47 }, { 31, 47 } }, "to_shrine")
      if not (toDoor and at(SHRINE_FRONT)) then
        -- Hammer-step can leave SaveBlock1 behind the object. Collision uses the
        -- object, so resync the save pos and retry from where the sprite actually is.
        local pob = playerObj()
        local ox = F.rs16(pob + S.ObjectEvent.x) - 7
        local oy = F.rs16(pob + S.ObjectEvent.y) - 7
        F.w16(F.sb1() + S.SaveBlock1.x, ox)
        F.w16(F.sb1() + S.SaveBlock1.y, oy)
        F.L(string.format("  resynced SaveBlock to obj (%d,%d)", ox, oy))
        parkFollower()
        toDoor = routeSafe({ SHRINE_FRONT }, "to_shrine_retry")
      end
      F.check("walked to the shrine door's south tile (31,47) after the crossing",
        toDoor and at(SHRINE_FRONT), here())
      F.shot("shrine_front")
      dumpAround("shrine_front")
      local beh, mid = behaviorAt(SHRINE_DOOR[1], SHRINE_DOOR[2])
      F.check("shrine door tile (31,46) is MB_ANIMATED_DOOR",
        beh == MB_ANIMATED_DOOR,
        string.format("metatile=0x%03X behavior=%d", mid, beh))
      -- From (30,47) the door is one tile north-east; try Up if already on (31,47),
      -- otherwise Right then Up.
      parkFollower()
      if not at(SHRINE_FRONT) then stepSafe("Right") end
      F.face("Up")
      F.idle(10)
      stepSafe("Up")
      for _ = 1, 40 do
        if F.grp() == GRP_INDOOR_BLACKTHORN and F.mapn() == MAP_DRAGONS_DEN_SHRINE then
          break
        end
        F.idle(15)
        if crash("shrine_warp") then break end
      end
      F.idle(40)
      shrineWalkable = (F.grp() == GRP_INDOOR_BLACKTHORN and F.mapn() == MAP_DRAGONS_DEN_SHRINE)
      F.check("MAP_DRAGONS_DEN_SHRINE is reachable by walking in after the crossing",
        shrineWalkable, here())
      F.shot("shrine_arrival")
    else
      F.check("walked to the shrine door's south tile (31,47) after the crossing", false, here())
      local beh, mid = behaviorAt(SHRINE_DOOR[1], SHRINE_DOOR[2])
      F.check("shrine door tile (31,46) is MB_ANIMATED_DOOR",
        beh == MB_ANIMATED_DOOR, string.format("metatile=0x%03X behavior=%d", mid, beh))
      F.check("MAP_DRAGONS_DEN_SHRINE is reachable by walking in after the crossing", false, here())
    end
  else
    F.check("the shrine-path whirlpool also slides 3 tiles south", false, "never reached (15,37)")
    F.check("walked to the shrine door's south tile (31,47) after the crossing", false, here())
    -- The door tile is on the loaded map; gBackupMapLayout can be read from here.
    local beh, mid = behaviorAt(SHRINE_DOOR[1], SHRINE_DOOR[2])
    F.check("shrine door tile (31,46) is MB_ANIMATED_DOOR",
      beh == MB_ANIMATED_DOOR,
      string.format("metatile=0x%03X behavior=%d (read remotely; walk after slide did not leave (26,22))", mid, beh))
    F.check("MAP_DRAGONS_DEN_SHRINE is reachable by walking in after the crossing", false, here())
  end
  F.L("  shrineWalkable=" .. tostring(shrineWalkable))
  crash("end")
  F.finish()
end)
