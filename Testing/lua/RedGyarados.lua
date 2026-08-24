-- Issue #66: "The Red Gyarados is red".
-- Overworld half: Lake of Rage template + spawned graphicsId is MON|SHINY|GYARADOS.
-- Battle half: Set Party, get in range, start the scripted fight, read opponent shininess.
-- Dragon's Den elder DRATINI (perfect-quiz shiny) is attempted only if a cheap warp works.
--
-- Run via Testing/mgba-run.sh Testing/lua/RedGyarados.lua

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path

local S = require("symbols")
local F = require("lib").new(S, "RedGyarados")

local OBJ_EVENT_MON       = 1 << 14
local OBJ_EVENT_MON_SHINY = 1 << 13
local SPECIES_MASK        = 0x8FFF
local SPECIES_GYARADOS    = 130
local SPECIES_DRATINI     = 147
local EXPECT_GFX          = SPECIES_GYARADOS + OBJ_EVENT_MON + OBJ_EVENT_MON_SHINY -- 0x6082

local TEMPLATES = 3988
local TEMPLATE  = { stride = 24, localId = 0, graphicsId = 1, x = 4, y = 6, flagId = 20 }

local GRP_LAKE, MAP_LAKE = 91, 4
local LOCALID_GYARADOS   = 8
local GYARADOS_TILE      = { 32, 28 }

local FLAG_JOHTO_BASE = 0x6000
local FLAG_HIDE_LAKE_OF_RAGE_GYARADOS = FLAG_JOHTO_BASE + 0x16E

local REGION_VARS_START = 0xA000
local VAR_JOHTO_BASE    = 0xA080
local VAR_BLACKTHORN_CITY_STATE = VAR_JOHTO_BASE + 0x2B
local VAR_DRAGONS_DEN_QUIZ      = VAR_JOHTO_BASE + 0x2D

local GRP_SHRINE, MAP_SHRINE = 94, 14
local ELDER_TILE = { 6, 9 }

local HUB_GROUP = 100
local ROW_PARTY_MENU, ROW_SET = 2, 9
local PARTY_SIZE, POKEMON_SIZE = 6, 100
local B_TRAINER_PLAYER, B_TRAINER_OPPONENT_A = 0, 1
local SHINY_ODDS = 512
local BOX_PERSONALITY, BOX_OTID, BOX_SHINY_U16 = 0, 4, 30
local MON_LEVEL = 84

local function johtoFlagGet(id)
  local a = F.sb3() + S.SaveBlock3.johtoFlags + ((id - FLAG_JOHTO_BASE) // 8)
  return (F.r8(a) & (1 << (id % 8))) ~= 0
end

local function johtoFlagSet(id, on)
  local a = F.sb3() + S.SaveBlock3.johtoFlags + ((id - FLAG_JOHTO_BASE) // 8)
  local m = 1 << (id % 8)
  local v = F.r8(a)
  F.w8(a, on and (v | m) or (v & ~m & 0xFF))
end

local function regionVarSet(id, v)
  F.w16(F.sb3() + S.SaveBlock3.regionVars + (id - REGION_VARS_START) * 2, v)
end

local function mapObjectCount()
  local events = F.r32(S.gMapHeader + 4)
  if events < 0x08000000 or events >= 0x0A000000 then return 0 end
  return F.r8(events)
end

local function idleCrash(n, tag)
  for i = 1, n do
    F.idle(1)
    if i % 30 == 0 and F.reportCrash(tag) then return true end
  end
  return false
end

local function tapDown(n)
  for _ = 1, n do F.press("Down", 3); F.idle(16) end
end

local function setParty()
  F.dbg(); idleCrash(60, "dbg_party")
  tapDown(ROW_PARTY_MENU); F.press("A", 3); idleCrash(60, "dbg_party_open")
  tapDown(ROW_SET); F.shot("set_party_cursor")
  F.press("A", 3); idleCrash(180, "dbg_set_party")
  for _ = 1, 6 do F.press("B", 3); F.idle(20) end
end

local function partyCount(trainer)
  return F.r8(S.gPartiesCount + trainer)
end

local function partyMon(trainer, slot)
  return S.gParties + ((trainer * PARTY_SIZE) + slot) * POKEMON_SIZE
end

local function monIsShiny(mon)
  local pid = F.r32(mon + BOX_PERSONALITY)
  local ot  = F.r32(mon + BOX_OTID)
  local shinyMod = (F.r16(mon + BOX_SHINY_U16) >> 14) & 1
  local sv = ((ot >> 16) & 0xFFFF) ~ (ot & 0xFFFF) ~ ((pid >> 16) & 0xFFFF) ~ (pid & 0xFFFF)
  return ((sv < SHINY_ODDS) and 1 or 0) ~ shinyMod == 1, pid, ot, shinyMod, sv
end

local function objByLocalId(localId)
  for i = 0, 15 do
    local b = S.gObjectEvents + i * S.ObjectEvent.stride
    if (F.r8(b) & 1) == 1 and F.r8(b + S.ObjectEvent.localId) == localId then
      local gfx = F.r16(b + S.ObjectEvent.graphicsId)
      local flags1 = F.r8(b + 1)
      local flags3 = F.r8(b + 3)
      return {
        i = i, b = b,
        x = F.rs16(b + S.ObjectEvent.x) - 7,
        y = F.rs16(b + S.ObjectEvent.y) - 7,
        gfx = gfx,
        species = gfx & SPECIES_MASK,
        mon = (gfx & OBJ_EVENT_MON) ~= 0,
        shinyBit = (gfx & OBJ_EVENT_MON_SHINY) ~= 0,
        objShiny = (flags3 & 0x10) ~= 0,
        invisible = (flags1 & 0x20) ~= 0,
      }
    end
  end
  return nil
end

local function describeObj(o)
  if not o then return "ABSENT" end
  return string.format("i=%d (%d,%d) gfx=0x%04X species=%d mon=%s shinyId=%s objShiny=%s%s",
    o.i, o.x, o.y, o.gfx, o.species,
    o.mon and "Y" or "N", o.shinyBit and "Y" or "N", o.objShiny and "Y" or "N",
    o.invisible and " invisible" or "")
end

local function scanTemplates()
  local n = mapObjectCount()
  local base = F.sb1() + TEMPLATES
  local found, match, dump = 0, nil, {}
  F.L(string.format("  map objectEventCount=%d", n))
  for i = 0, n - 1 do
    local t = base + i * TEMPLATE.stride
    local gfx = F.r16(t + TEMPLATE.graphicsId)
    local localId = F.r8(t + TEMPLATE.localId)
    local x = F.rs16(t + TEMPLATE.x)
    local y = F.rs16(t + TEMPLATE.y)
    local flagId = F.r16(t + TEMPLATE.flagId)
    if (gfx & OBJ_EVENT_MON) ~= 0 then
      found = found + 1
      dump[#dump + 1] = string.format("id%d gfx=0x%04X sp=%d%s (%d,%d) flag=0x%04X",
        localId, gfx, gfx & SPECIES_MASK,
        ((gfx & OBJ_EVENT_MON_SHINY) ~= 0) and " SHINY" or "",
        x, y, flagId)
      if (gfx & SPECIES_MASK) == SPECIES_GYARADOS then
        match = { i = i, localId = localId, gfx = gfx, x = x, y = y, flagId = flagId }
      end
    end
  end
  F.L("  templates: " .. ((#dump > 0) and table.concat(dump, " | ") or "(none)"))
  return n, found, match
end

local function scanSpawned()
  local gyara, mons = nil, {}
  for i = 0, 15 do
    local b = S.gObjectEvents + i * S.ObjectEvent.stride
    if (F.r8(b) & 1) == 1 then
      local localId = F.r8(b + S.ObjectEvent.localId)
      if localId ~= 255 and localId ~= 127 then
        local gfx = F.r16(b + S.ObjectEvent.graphicsId)
        if (gfx & OBJ_EVENT_MON) ~= 0 or localId == LOCALID_GYARADOS then
          local o = objByLocalId(localId)
          mons[#mons + 1] = describeObj(o)
          if o and (o.species == SPECIES_GYARADOS or localId == LOCALID_GYARADOS) then
            gyara = o
          end
        end
      end
    end
  end
  F.L("  spawned mons: " .. ((#mons > 0) and table.concat(mons, " | ") or "(none)"))
  return gyara
end

local function playerSpriteXY()
  for i = 0, 15 do
    local b = S.gObjectEvents + i * S.ObjectEvent.stride
    if (F.r8(b) & 1) == 1 and F.r8(b + S.ObjectEvent.localId) == 255 then
      local sid = F.r8(b + 0x23)
      if sid < 64 then
        local sp = S.gSprites + sid * S.Sprite.stride
        return F.rs16(sp + 0x20), F.rs16(sp + 0x22), sid
      end
    end
  end
  return nil
end

-- Interaction looks up (facing tile, player elevation). Elevation 1 (surf) never
-- matches land elevation 3; 0 is ELEVATION_TRANSITION and matches anything.
-- Do not freeze or zero movementType: faceplayer waits on heldMovementFinished.
local function writeObjXY(b, x, y)
  local mx, my = x + 7, y + 7
  F.w16(b + 0x0C, mx); F.w16(b + 0x0E, my)
  F.w16(b + 0x10, mx); F.w16(b + 0x12, my)
  F.w16(b + 0x14, mx); F.w16(b + 0x16, my)
  F.w8(b + 0x0B, 0x00)
  local f1 = F.r8(b + 1)
  F.w8(b + 1, f1 & ~0x60)
  F.w8(b, F.r8(b) | 0x80)
  local sid = F.r8(b + 0x23)
  local px, py = playerSpriteXY()
  if sid < 64 and px then
    local sp = S.gSprites + sid * S.Sprite.stride
    F.w16(sp + 0x20, px + (x - select(1, F.pos())) * 16)
    F.w16(sp + 0x22, py + (y - select(2, F.pos())) * 16)
    local fl = F.r16(sp + S.Sprite.inUse)
    F.w16(sp + S.Sprite.inUse, fl & ~0x0004)
  end
end

local function scriptRunning()
  local p = F.r32(S.sGlobalScriptContext + S.ScriptCtx.scriptPtr)
  return p >= 0x08000000 and p < 0x0A000000
end

-- Wild battles set gBattleTypeFlags = 0, so flags~=0 is the wrong test.
local function leftOverworld()
  return (not F.ow()) or F.battlers() >= 2
end

local function tryTalk(dir, frames)
  F.face(dir)
  idleCrash(20, "face")
  local sawScript = false
  for t = 1, frames do
    if t % 12 == 0 then F.press("A", 2) end
    F.idle(1)
    if t % 60 == 0 and F.reportCrash("battle_wait") then return false end
    if scriptRunning() then sawScript = true end
    if leftOverworld() then return true end
  end
  -- Cry + msgbox can outlast the first window; if a script took the lock, keep waiting.
  if sawScript or scriptRunning() then
    F.L("  script took the lock; waiting for battle/overworld")
    for t = 1, 1800 do
      if t % 16 == 0 then F.press("A", 2) end
      F.idle(1)
      if t % 60 == 0 and F.reportCrash("battle_wait2") then return false end
      if leftOverworld() then return true end
    end
  end
  return leftOverworld()
end

local DIR_NORTH, DIR_SOUTH, DIR_WEST, DIR_EAST = 2, 1, 3, 4

local function playerObj()
  for i = 0, 15 do
    local b = S.gObjectEvents + i * S.ObjectEvent.stride
    if (F.r8(b) & 1) == 1 and F.r8(b + S.ObjectEvent.localId) == 255 then return b end
  end
  return nil
end

local function setFacing(dir)
  local b = playerObj()
  if not b then return end
  local v = F.r16(b + S.ObjectEvent.facing)
  F.w16(b + S.ObjectEvent.facing, (v & ~0x00FF) | dir | (dir << 4))
end

local function lastTalked() return F.r16(S.gSpecialVar_LastTalked) end

-- Don't freeze/inanimate: the script's faceplayer waits on heldMovementFinished.
local function prepMon(b)
  F.w8(b + 0x0B, 0x00)
  local f1 = F.r8(b + 1)
  F.w8(b + 1, f1 & ~0x60)
  F.w8(b, F.r8(b) | 0x80)
end

local function tryStartBattle(gyara)
  if not gyara then return false end
  local px, py = F.pos()
  F.L(string.format("  player (%d,%d) avatar flags=0x%02X prevent=%d trans=%d lastTalked=%d",
    px, py, F.r8(S.gPlayerAvatar), F.r8(S.gPlayerAvatar + 6), F.r8(S.gPlayerAvatar + 3), lastTalked()))
  F.w8(S.gPlayerAvatar + 6, 0)
  F.w8(S.gPlayerAvatar, F.r8(S.gPlayerAvatar) | (1 << 5))

  local spots = {
    { px,     py - 1, DIR_NORTH },
    { px + 1, py,     DIR_EAST  },
    { px - 1, py,     DIR_WEST  },
  }
  for _, s in ipairs(spots) do
    gyara = objByLocalId(LOCALID_GYARADOS) or gyara
    if not gyara then return false end
    writeObjXY(gyara.b, s[1], s[2])
    prepMon(gyara.b)
    idleCrash(16, "nudge_gyara")
    gyara = objByLocalId(LOCALID_GYARADOS) or gyara
    setFacing(s[3])
    idleCrash(20, "set_facing")
    F.L(string.format("  gyarados at (%d,%d) elev=%d facing=%d lastTalked=%d: %s",
      s[1], s[2], F.r8(gyara.b + 0x0B) & 0xF, F.r8(playerObj() + S.ObjectEvent.facing) & 0xF,
      lastTalked(), describeObj(gyara)))
    F.shot("facing_gyarados")
    F.w16(S.gSpecialVar_LastTalked, 0)
    for t = 1, 90 do
      F.press("A", 1); F.idle(20)
      if t % 15 == 0 and F.reportCrash("battle_wait") then return false end
      local lt = lastTalked()
      if lt == LOCALID_GYARADOS then
        F.L(string.format("  lastTalked=GYARADOS at tap %d", t))
        break
      end
      if leftOverworld() then
        F.shot("battle_started")
        return true
      end
    end
    if lastTalked() == LOCALID_GYARADOS then
      F.L("  gyarados script engaged; waiting for battle")
      F.shot("gyarados_script")
      for t = 1, 1800 do
        if t % 12 == 0 then F.press("A", 1) end
        F.idle(1)
        if t % 60 == 0 and F.reportCrash("battle_wait2") then return false end
        if leftOverworld() then
          F.shot("battle_started")
          return true
        end
      end
      F.L(string.format("  script engaged but still ow; battlers=%d cb2=0x%08X", F.battlers(), F.cb2()))
      F.shot("script_stuck")
      return leftOverworld()
    end
    F.L(string.format("  no talk (lastTalked=%d still ow)", lastTalked()))
  end
  F.shot("talk_failed")
  return leftOverworld()
end

F.run(function()
  if not F.boot(HUB_GROUP) then
    F.check("boot to the hub", false)
    F.finish()
    return
  end
  F.check("player is free before the debug work", F.ensureFree())

  setParty()
  local nParty = partyCount(B_TRAINER_PLAYER)
  F.check("Set Party published a non-empty party", nParty ~= 0, "count=" .. nParty)
  F.shot("after_set_party")
  if F.reportCrash("after_set_party") then F.finish(); return end

  -- FLAG_HIDE_LAKE_OF_RAGE_GYARADOS must be clear or the object never copies into the spawn list.
  F.L(string.format("  FLAG_HIDE_LAKE_OF_RAGE_GYARADOS=%s (want clear)",
    johtoFlagGet(FLAG_HIDE_LAKE_OF_RAGE_GYARADOS) and "SET" or "CLEAR"))
  if johtoFlagGet(FLAG_HIDE_LAKE_OF_RAGE_GYARADOS) then
    johtoFlagSet(FLAG_HIDE_LAKE_OF_RAGE_GYARADOS, false)
    F.L("  cleared hide flag before warp")
  end

  local warped = F.warpTo(0, 9, 1, 0, 0, 4, 0, 0, 0, GRP_LAKE, MAP_LAKE, "lakeofrage")
  F.check("warped to Lake of Rage (group 91 map 4)", warped and F.ow(),
    string.format("grp=%d map=%d", F.grp(), F.mapn()))
  if not warped then F.finish(); return end

  local spun = 0
  while not F.ow() and spun < 600 do
    F.idle(10); spun = spun + 10
    if F.reportCrash("warp_settle") then F.finish(); return end
  end
  idleCrash(180, "lake_arrive")
  F.shot("lake_arrival")

  local objCount, monTemplates, tmpl = scanTemplates()
  F.check("Lake of Rage loaded its object templates", objCount > 0, "count=" .. objCount)
  F.check("a GYARADOS template is present", tmpl ~= nil,
    tmpl and string.format("localId=%d gfx=0x%04X (%d,%d)", tmpl.localId, tmpl.gfx, tmpl.x, tmpl.y) or "missing")
  if tmpl then
    F.check("template graphicsId is OBJ_EVENT_MON | OBJ_EVENT_MON_SHINY | SPECIES_GYARADOS",
      tmpl.gfx == EXPECT_GFX,
      string.format("gfx=0x%04X want 0x%04X (MON=%s SHINY=%s species=%d)",
        tmpl.gfx, EXPECT_GFX,
        ((tmpl.gfx & OBJ_EVENT_MON) ~= 0) and "Y" or "N",
        ((tmpl.gfx & OBJ_EVENT_MON_SHINY) ~= 0) and "Y" or "N",
        tmpl.gfx & SPECIES_MASK))
    F.check("template sits at map.json (32,28)",
      tmpl.x == GYARADOS_TILE[1] and tmpl.y == GYARADOS_TILE[2],
      string.format("(%d,%d)", tmpl.x, tmpl.y))
  else
    F.check("template graphicsId is OBJ_EVENT_MON | OBJ_EVENT_MON_SHINY | SPECIES_GYARADOS", false, "no template")
  end

  local gyara = scanSpawned()
  if not gyara then
    -- Spawn window is player.y <= 35 and x in [22,41]. Warp 0 lands at (39,42), one tile
    -- SOUTH of the house door at (39,41) — an Up step walks into MAP_LAKE_OF_RAGE_HOUSE2.
    -- Stay off that door column and approach the shore from the west path.
    local px, py = F.pos()
    F.L(string.format("  gyarados not in spawn range on arrival; player at (%d,%d) grp=%d map=%d",
      px, py, F.grp(), F.mapn()))
    local paths = {
      { tag = "to_shore",     pts = { { 38, 42 }, { 38, 40 }, { 33, 40 }, { 33, 35 } } },
      { tag = "to_shore_alt", pts = { { 38, 42 }, { 34, 42 }, { 34, 36 }, { 31, 35 } } },
      { tag = "to_shore_e",   pts = { { 38, 42 }, { 36, 38 }, { 34, 35 } } },
    }
    for _, p in ipairs(paths) do
      if F.grp() ~= GRP_LAKE or F.mapn() ~= MAP_LAKE then
        F.L("  left Lake of Rage; warping back")
        if not F.warpTo(0, 9, 1, 0, 0, 4, 0, 0, 0, GRP_LAKE, MAP_LAKE, "lake_reenter") then
          break
        end
        idleCrash(180, "lake_reenter")
      end
      if F.route(p.pts, p.tag) then break end
    end
    idleCrash(90, "shore_settle")
    if F.reportCrash("shore") then F.finish(); return end
    local sx, sy = F.pos()
    F.L(string.format("  after shore walk (%d,%d) grp=%d map=%d", sx, sy, F.grp(), F.mapn()))
    F.shot("south_shore")
    gyara = scanSpawned()
  end

  F.check("a spawned object matches the shiny GYARADOS",
    gyara ~= nil and gyara.mon and gyara.shinyBit and gyara.species == SPECIES_GYARADOS,
    describeObj(gyara))
  if gyara then
    F.check("spawned graphicsId is exactly MON|SHINY|130",
      gyara.gfx == EXPECT_GFX, string.format("gfx=0x%04X", gyara.gfx))
    F.check("spawned ObjectEvent.shiny bit is set", gyara.objShiny, describeObj(gyara))
  else
    F.check("spawned graphicsId is exactly MON|SHINY|130", false, "not spawned")
  end
  F.shot("overworld_gyarados")

  -- Battle half: talking runs setwildbattleshiny + dowildbattle. Empty party is refused as a flee.
  local battled = false
  if gyara and nParty ~= 0 then
    battled = tryStartBattle(gyara)
  end
  F.check("scripted GYARADOS battle started", battled,
    battled and string.format("battlers=%d flags=0x%X", F.battlers(), F.battleFlags())
            or "could not talk / battle never left overworld")

  if battled then
    idleCrash(120, "in_battle")
    F.shot("gyarados_battle")
    local opp = partyMon(B_TRAINER_OPPONENT_A, 0)
    local shiny, pid, ot, mod, sv = monIsShiny(opp)
    local lvl = F.r8(opp + MON_LEVEL)
    local oppCount = partyCount(B_TRAINER_OPPONENT_A)
    local bSpecies = F.r16(S.gBattleMons + S.BattlePokemon.size) -- battler 1, species at +0
    F.L(string.format("  opponent count=%d level=%d pid=0x%08X ot=0x%08X shinyMod=%d shinyValue=%d battleSpecies=%d",
      oppCount, lvl, pid, ot, mod, sv, bSpecies))
    F.check("opponent party has a mon", oppCount >= 1, "count=" .. oppCount)
    F.check("scripted wild is level 30", lvl == 30, "level=" .. lvl)
    if bSpecies ~= 0 then
      F.check("gBattleMons opponent species is GYARADOS", bSpecies == SPECIES_GYARADOS,
        "species=" .. bSpecies)
    end
    F.check("battler is shiny (MON_DATA_IS_SHINY formula)", shiny,
      string.format("pid=0x%08X ot=0x%08X mod=%d sv=%d", pid, ot, mod, sv))
  end

  -- Dragon's Den elder: cheap only if we are still on the overworld (battle would eat the warp).
  if F.ow() then
    regionVarSet(VAR_BLACKTHORN_CITY_STATE, 4)
    regionVarSet(VAR_DRAGONS_DEN_QUIZ, 0)
    local shrine = F.warpTo(0, 9, 4, 0, 1, 4, 0, 0, 0, GRP_SHRINE, MAP_SHRINE, "shrine")
    if shrine and F.ow() then
      idleCrash(180, "shrine_arrive")
      F.shot("shrine_arrival")
      local sx, sy = F.pos()
      F.L(string.format("  shrine player (%d,%d); walking to elder (6,9)", sx, sy))
      F.route({ { ELDER_TILE[1], ELDER_TILE[2] + 1 } }, "to_elder")
      F.face("Up")
      F.shot("facing_elder")
      local before = partyCount(B_TRAINER_PLAYER)
      for t = 1, 900 do
        if t % 12 == 0 then F.press("A", 2) end
        F.idle(1)
        if t % 60 == 0 and F.reportCrash("elder_talk") then break end
        if partyCount(B_TRAINER_PLAYER) > before then
          idleCrash(90, "after_dratini")
          break
        end
      end
      F.shot("after_elder")
      local after = partyCount(B_TRAINER_PLAYER)
      F.check("elder gave a DRATINI on the perfect-quiz branch", after > before,
        string.format("party %d -> %d", before, after))
      if after > before then
        local gift = partyMon(B_TRAINER_PLAYER, after - 1)
        local shiny, pid, ot, mod, sv = monIsShiny(gift)
        local lvl = F.r8(gift + MON_LEVEL)
        F.L(string.format("  gift level=%d pid=0x%08X ot=0x%08X mod=%d sv=%d shiny=%s",
          lvl, pid, ot, mod, sv, shiny and "Y" or "N"))
        F.check("perfect-quiz DRATINI is shiny", shiny,
          string.format("level=%d pid=0x%08X ot=0x%08X mod=%d sv=%d", lvl, pid, ot, mod, sv))
      end
    else
      F.L("  Dragon's Den shrine warp failed; skipping elder DRATINI")
    end
  else
    F.L("  still in battle; skipping Dragon's Den elder (not cheap from here)")
  end

  F.finish()
end)
