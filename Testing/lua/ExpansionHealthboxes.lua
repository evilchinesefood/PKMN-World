-- Issue #120 playtest A: healthboxes / FillSpriteRect.
--
-- UpdateLeftNoOfBallsTextOnHealthbox (src/battle_interface.c:1963) is the only
-- FillSpriteRectColor(..., left=55, ...) caller. 55%8=7, the unaligned case the
-- expansion merge repaired in src/sprite.c. Singles/doubles also FillSpriteRectColor
-- for nickname (left=16/8, width=55) and HP numbers (left=40). A clean HP *bar* is
-- MoveBattleBar — this suite does not pass on the bar alone.
--
-- RAM (must fail on a broken build, not vacuously):
--   Safari: gBattleTypeFlags has BATTLE_TYPE_SAFARI (1<<7), gNumSafariBalls 30→29
--   Singles: trainer flag, in-battle, an HP word actually changed
--   Doubles: BATTLE_TYPE_DOUBLE, gBattlersCount>=3. If a doubles battle cannot be
--            reached from a fresh save, doubles_healthbox_reached FAILs rather than
--            skipping. Debug trainer is Singles; this uses the Trainers debug menu
--            (trainer 1 + trainer 2 => TWO_OPPONENTS | DOUBLE).
--
-- Run via Testing/mgba-run.sh Testing/lua/ExpansionHealthboxes.lua

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "ExpansionHealthboxes")

local HUB_GROUP = 100
local ROW_PARTY, ROW_SET, ROW_BATTLE = 2, 9, 10
local ROW_TRAINERS = 6
local B_SAFARI = 1 << 7
local B_TRAINER = 1 << 3
local B_DOUBLE = 1 << 0
local B_TWO_OPPONENTS = 1 << 15
local B_OUTCOME_RAN = 4
local FLAG_SYS_SAFARI_MODE = 0x974       -- SYSTEM_FLAGS+0x2C
local FLAG_SYS_ENC_UP_ITEM = 0x995       -- SYSTEM_FLAGS+0x4D
local GRP_SAFARI, MAP_SAFARI = 26, 3     -- MAP_SAFARI_ZONE_SOUTH
local MB_TALL_GRASS, MB_LONG_GRASS, MB_SHORT_GRASS = 2, 3, 7
local LOCALID_OWE_END, OWE_SPAWNS_MAX = 252, 4
local OBJ_PREV_X, OBJ_SPRITE_ID = 0x14, 0x23
local PARTY_SIZE = 6

local function d(n) return (n // 100) % 10, (n // 10) % 10, n % 10 end

local function tap(n)
  for _ = 1, n do F.press("Down", 3); F.idle(16) end
end

local function flagAddr(id) return F.sb1() + S.SaveBlock1.flags + (id // 8) end
local function flagSet(id)
  F.w8(flagAddr(id), F.r8(flagAddr(id)) | (1 << (id % 8)))
end
local function flagGet(id)
  return (F.r8(flagAddr(id)) & (1 << (id % 8))) ~= 0
end
local function flagClear(id)
  F.w8(flagAddr(id), F.r8(flagAddr(id)) & ~(1 << (id % 8)) & 0xFF)
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

local function setParty()
  F.dbg(); F.idle(60)
  tap(ROW_PARTY); F.press("A", 3); F.idle(60)
  tap(ROW_SET); F.press("A", 3); F.idle(180)
  for _ = 1, 8 do F.press("B", 3); F.idle(20) end
end

local function cloneLead(n)
  local src = S.gParties
  for slot = 1, n - 1 do
    local dst = src + slot * S.Pokemon.size
    for off = 0, S.Pokemon.size - 1 do F.w8(dst + off, F.r8(src + off)) end
  end
  F.w8(S.gPartiesCount, n)
end

local function battleHp(battler)
  return F.r16(S.gBattleMons + battler * S.BattlePokemon.size + S.BattlePokemon.hp)
end

local function leaveBattle(tag)
  -- Close party/shift/bag overlays first; gBattleOutcome is ignored while
  -- CB2 is the party menu (the doubles switch attempt lands there).
  for _ = 1, 24 do
    F.press("B", 3); F.idle(12)
    if F.ow() then return true end
  end
  F.w8(S.gBattleOutcome, 1) -- B_OUTCOME_WON
  for i = 1, 360 do
    F.idle(8)
    if F.ow() then return true end
    if i % 4 == 0 then F.press("A", 2); F.idle(6); F.press("B", 2) end
  end
  F.w8(S.gBattleOutcome, B_OUTCOME_RAN)
  for i = 1, 180 do
    F.idle(8)
    if F.ow() then return true end
    F.press("A", 2)
  end
  F.shot(tag .. "_stuck_in_battle")
  return F.ow()
end

local function waitBattle(flagsWant, tag, budget)
  budget = budget or 900
  for i = 1, budget do
    F.idle(2)
    if (not F.ow()) and F.battleFlags() ~= 0 then
      if flagsWant == 0 or (F.battleFlags() & flagsWant) ~= 0 then
        -- battlers is still 0 the frame CB2 leaves the overworld
        for _ = 1, 200 do
          F.idle(2)
          if F.battlers() >= 2 then return true end
        end
        return F.battlers() >= 1
      end
    end
    if i % 40 == 0 and F.reportCrash(tag) then return false end
  end
  return false
end

local function despawnGeneratedOWEs()
  local n = 0
  for i = 0, 15 do
    local b = S.gObjectEvents + i * S.ObjectEvent.stride
    if (F.r8(b) & 1) == 1 then
      local id = F.r8(b + S.ObjectEvent.localId)
      if id > (LOCALID_OWE_END - OWE_SPAWNS_MAX) and id <= LOCALID_OWE_END then
        local sid = F.r8(b + OBJ_SPRITE_ID)
        if sid < S.Sprite.count then
          local sp = S.gSprites + sid * S.Sprite.stride
          F.w16(sp + S.Sprite.inUse, F.r16(sp + S.Sprite.inUse) & ~1)
        end
        F.w16(b + S.ObjectEvent.x, 8)
        F.w16(b + S.ObjectEvent.y, 8)
        F.w16(b + OBJ_PREV_X, 8)
        F.w16(b + OBJ_PREV_X + 2, 8)
        F.w8(b, F.r8(b) & ~1)
        n = n + 1
      end
    end
  end
  return n
end

-- Live metatile behaviour. Same decode DoorAnimsRegistered / NationalParkTiles use:
-- primary vs secondary from layout isFrlg/isJohto, attribute width from the tileset bit.
local function tileBehavior(x, y)
  local w = F.r32(S.gBackupMapLayout + S.BackupMapLayout.width)
  local map = F.r32(S.gBackupMapLayout + S.BackupMapLayout.map)
  if map < 0x02000000 then return 0 end
  local id = F.r16(map + ((x + 7) + (y + 7) * w) * 2) & S.Metatiles.idMask
  local layout = F.r32(S.gMapHeader + S.MapHeader.mapLayout)
  local isFrlg = F.r8(layout + S.MapLayout.isFrlg) ~= 0
  local isJohto = F.r8(layout + S.MapLayout.isJohto) ~= 0
  local nPrimary = (isFrlg or isJohto) and S.Metatiles.inPrimaryFrlg or S.Metatiles.inPrimary
  local ts, localId
  if id < nPrimary then
    ts, localId = F.r32(layout + S.MapLayout.primaryTileset), id
  else
    ts, localId = F.r32(layout + S.MapLayout.secondaryTileset), id - nPrimary
  end
  if ts < 0x08000000 then return 0 end
  local attrs = F.r32(ts + S.Tileset.metatileAttributes)
  local hasFrlg = (F.r8(ts + S.Tileset.flags1) & S.Tileset.hasFrlgAttributesBit) ~= 0
  if hasFrlg then
    return F.r32(attrs + localId * 4) & S.Metatiles.behaviorMaskFrlg
  end
  return F.r16(attrs + localId * 2) & S.Metatiles.behaviorMask
end

local function isGrass(beh)
  return beh == MB_TALL_GRASS or beh == MB_LONG_GRASS or beh == MB_SHORT_GRASS
end

local function findGrassNear()
  local px, py = F.pos()
  for r = 0, 12 do
    for dx = -r, r do
      for dy = -r, r do
        if math.abs(dx) == r or math.abs(dy) == r then
          local x, y = px + dx, py + dy
          if x >= 0 and y >= 0 and isGrass(tileBehavior(x, y)) then
            return x, y
          end
        end
      end
    end
  end
  return nil
end

local function healthboxLive(battler)
  local hid = F.r8(S.gHealthboxSpriteIds + battler)
  if hid >= S.Sprite.count then return false end
  local sp = S.gSprites + hid * S.Sprite.stride
  return (F.r16(sp + S.Sprite.inUse) & 1) ~= 0
end

local function pokeChar(b)
  if b == 0xFF or b == 0xFA or b == 0xFB then return "" end
  if b == 0xFE then return "\n" end
  if b == 0x00 then return " " end
  if b >= 0xA1 and b <= 0xAA then return string.char(48 + (b - 0xA1)) end
  if b >= 0xBB and b <= 0xD4 then return string.char(65 + (b - 0xBB)) end
  if b >= 0xD5 and b <= 0xEE then return string.char(97 + (b - 0xD5)) end
  return ""
end
local function battleText()
  local t = {}
  for i = 0, 80 do
    local b = F.r8(S.gDisplayedStringBattle + i)
    if b == 0xFF then break end
    t[#t + 1] = pokeChar(b)
  end
  return table.concat(t):upper()
end

local function waitWhatWill(budget)
  for i = 1, budget do
    F.idle(2)
    if battleText():find("WHAT WILL", 1, true) then return true end
    if i % 25 == 0 then F.press("A", 1) end
  end
  return battleText():find("WHAT WILL", 1, true) ~= nil
end

local function freeField(tag)
  for _ = 1, 40 do
    F.press("B", 3); F.idle(16)
    if F.ow() and F.ensureFree() then return true end
  end
  F.L("  freeField " .. tag .. " still busy")
  return F.ow()
end

-- ---- safari leftover-ball text (left=55) --------------------------------------------------
local function safariPhase()
  if not go(GRP_SAFARI, MAP_SAFARI, 0, "safari_south") then return false end
  F.check("on Safari Zone South", F.grp() == GRP_SAFARI and F.mapn() == MAP_SAFARI,
    string.format("grp=%d map=%d", F.grp(), F.mapn()))

  -- Warp does not go through Overworld_ResetStateAfterFly, but set the flag AFTER
  -- arrival anyway so a later map-load cannot clear it before we walk.
  flagSet(FLAG_SYS_SAFARI_MODE)
  flagSet(FLAG_SYS_ENC_UP_ITEM)
  F.w8(S.gNumSafariBalls, 30)
  F.w16(S.gSafariZoneStepCounter, 500)
  F.check("FLAG_SYS_SAFARI_MODE is set", flagGet(FLAG_SYS_SAFARI_MODE))
  F.check("gNumSafariBalls seeded at 30", F.r8(S.gNumSafariBalls) == 30,
    "balls=" .. F.r8(S.gNumSafariBalls))

  local gx, gy = findGrassNear()
  local px, py = F.pos()
  F.L(string.format("  nearest grass: %s (player at %d,%d)",
    gx and string.format("(%d,%d) beh=%d", gx, gy, tileBehavior(gx, gy)) or "NONE",
    px, py))
  F.shot("safari_field")

  if gx then
    F.route({ { gx, gy } }, "to_safari_grass")
  else
    -- Path north from warp 0 at (32,33); attendant sits one tile south.
    F.step("Up")
  end

  local started = false
  local dirs, di = { "Up", "Right", "Down", "Left" }, 1
  for i = 1, 500 do
    despawnGeneratedOWEs()
    if F.reportCrash("safari_walk") then break end
    if (F.battleFlags() & B_SAFARI) ~= 0 or not F.ow() then
      started = true
      break
    end
    local x, y = F.pos()
    if not isGrass(tileBehavior(x, y)) and gx then
      -- Stay on grass: step to an adjacent grass tile.
      local stepped = false
      for _, dir in ipairs(dirs) do
        local nx, ny = x, y
        if dir == "Up" then ny = y - 1 elseif dir == "Down" then ny = y + 1
        elseif dir == "Left" then nx = x - 1 else nx = x + 1 end
        if isGrass(tileBehavior(nx, ny)) then
          if F.step(dir) then stepped = true; break end
        end
      end
      if not stepped and not F.step(dirs[di]) then di = (di % 4) + 1 end
    else
      if not F.step(dirs[di]) then di = (di % 4) + 1 end
      if i % 16 == 0 then di = (di % 4) + 1 end
    end
  end

  if started and F.ow() then
    -- Transition frame: flags may already be set while CB2 is still overworld.
    for _ = 1, 400 do
      F.idle(2)
      if not F.ow() then break end
    end
  end
  started = waitBattle(B_SAFARI, "safari_enter", 400) or ((F.battleFlags() & B_SAFARI) ~= 0)
  F.check("safari battle started (BATTLE_TYPE_SAFARI)", started
    and (F.battleFlags() & B_SAFARI) ~= 0,
    string.format("started=%s flags=0x%X ow=%s balls=%d",
      tostring(started), F.battleFlags(), tostring(F.ow()), F.r8(S.gNumSafariBalls)))
  if (F.battleFlags() & B_SAFARI) == 0 then return false end

  -- A skips the encounter printer; once the action prompt is up, A throws.
  -- Stop mashing when WHAT WILL appears so the 30-ball shot is the leftover box.
  for i = 1, 800 do
    if battleText():find("WHAT WILL", 1, true) then break end
    if i % 12 == 0 then F.press("A", 1) end
    F.idle(2)
  end
  F.idle(40)
  local balls30 = F.r8(S.gNumSafariBalls)
  F.L(string.format("  safari ready: flags=0x%X balls=%d battlers=%d hb0=%s",
    F.battleFlags(), balls30, F.battlers(), tostring(healthboxLive(0))))
  F.check("Safari healthbox sprite is live", healthboxLive(0) or healthboxLive(1))
  F.check("gNumSafariBalls still 30 before the throw", balls30 == 30, "balls=" .. balls30)
  F.shot("safari_balls_30")

  -- Throw. Cursor 0 = Ball / Bait / Rock / Run. Keep A until the count drops;
  -- A during send-out text is eaten (same trap DebugParty paid for).
  local dropped = false
  for t = 1, 900 do
    if t % 20 == 0 then F.press("A", 2) end
    F.idle(2)
    if F.r8(S.gNumSafariBalls) < 30 then dropped = true; break end
    if F.ow() then break end
  end
  F.idle(90)
  local balls29 = F.r8(S.gNumSafariBalls)
  F.L(string.format("  after throw: balls=%d (want 29) flags=0x%X", balls29, F.battleFlags()))
  F.check("gNumSafariBalls dropped from 30 (FillSpriteRect left=55 path ran)",
    dropped and balls29 < 30,
    string.format("balls %d -> %d", balls30, balls29))
  F.check("gNumSafariBalls is 29 after one throw", balls29 == 29, "balls=" .. balls29)
  F.shot("safari_balls_29")
  F.check("field control returns after Safari", leaveBattle("safari"))
  flagClear(FLAG_SYS_SAFARI_MODE)
  F.w32(S.gBattleTypeFlags, 0)
  -- Do NOT ensureFree/step: Safari Zone grass + the follower both start
  -- battles, and warpTo then runs inside a fight (hub_after_safari_warpfail
  -- was a wild Wobbuffet). B-dismiss only, then warp.
  for _ = 1, 20 do F.press("B", 3); F.idle(16) end
  if F.grp() ~= HUB_GROUP then
    local gh, gt, go_ = d(HUB_GROUP)
    local ok = F.warpTo(gh, gt, go_, 0, 0, 0, 0, 0, 0, HUB_GROUP, 0, "hub_after_safari")
    if not ok then
      for _ = 1, 30 do F.press("B", 3); F.idle(20) end
      ok = F.warpTo(gh, gt, go_, 0, 0, 0, 0, 0, 0, HUB_GROUP, 0, "hub_after_safari2")
    end
    F.check("back on hub for singles", ok and F.grp() == HUB_GROUP,
      string.format("grp=%d map=%d", F.grp(), F.mapn()))
  end
  for _ = 1, 10 do F.press("B", 3); F.idle(16) end
  return true
end

-- ---- singles: debug trainer, nickname + HP numbers after an HP change --------------------
local function singlesPhase()
  if not F.ow() then leaveBattle("pre_singles") end
  F.w32(S.gBattleTypeFlags, 0)
  F.dbg(); F.idle(60)
  tap(ROW_PARTY); F.press("A", 3); F.idle(60)
  tap(ROW_BATTLE); F.press("A", 3); F.idle(260)
  local started = waitBattle(B_TRAINER, "singles", 600)
  F.check("Start Debug Battle is a trainer battle", started
    and (F.battleFlags() & B_TRAINER) ~= 0
    and F.battleFlags() ~= 0,
    string.format("started=%s flags=0x%X ow=%s", tostring(started), F.battleFlags(), tostring(F.ow())))
  if not started then return false end

  F.check("singles is in-battle (CB2 not overworld, flags~=0)",
    (not F.ow()) and F.battleFlags() ~= 0,
    string.format("ow=%s flags=0x%X cb2=0x%08X", tostring(F.ow()), F.battleFlags(), F.cb2()))
  local ready = waitWhatWill(600)
  F.L("  singles action prompt: " .. battleText():sub(1, 60))
  F.check("player healthbox is live", healthboxLive(0))
  F.check("foe healthbox is live", healthboxLive(1))
  F.shot("singles_sendout")

  local pHp0, fHp0 = battleHp(0), battleHp(1)
  F.L(string.format("  singles HP before: player=%d foe=%d ready=%s cursor=%d",
    pHp0, fHp0, tostring(ready), F.r8(S.gActionSelectionCursor)))

  -- Menu is not input-ready the frame gDisplayedStringBattle first contains
  -- WHAT WILL (the send-out shot was an empty box). Wait, then mash A:
  -- Battle -> Earthquake. Metang may Protect turn 1; keep going.
  F.idle(180)
  local changed = false
  for i = 1, 120 do
    F.press("A", 2); F.idle(28)
    if battleHp(0) ~= pHp0 or battleHp(1) ~= fHp0 then changed = true; break end
    if F.ow() then break end
    if i % 15 == 0 then
      F.L(string.format("  singles mash %d hp=%d/%d text=%s",
        i, battleHp(0), battleHp(1), battleText():sub(1, 48)))
    end
  end
  F.idle(90)
  local pHp1, fHp1 = battleHp(0), battleHp(1)
  F.L(string.format("  singles HP after: player=%d foe=%d text=%s", pHp1, fHp1, battleText():sub(1, 50)))
  F.check("an HP word changed (not the bar alone)",
    changed and (pHp1 ~= pHp0 or fHp1 ~= fHp0),
    string.format("player %d->%d foe %d->%d", pHp0, pHp1, fHp0, fHp1))
  F.shot("singles_hp_change")
  F.check("field control returns after singles", leaveBattle("singles"))
  freeField("after_singles")
  return true
end

-- ---- doubles: Trainers debug menu, two opponents -----------------------------------------
-- DebugAction_Party_BattleSingle always starts the debug trainer, which is
-- Battle Type: Singles. The Trainers submenu's Try Battle ORs BATTLE_TYPE_DOUBLE
-- when trainer 2 is set (TWO_OPPONENTS) or the doubles toggle is on.
local function doublesPhase()
  cloneLead(2)
  F.check("party cloned to 2 for doubles", F.r8(S.gPartiesCount) >= 2,
    "count=" .. F.r8(S.gPartiesCount))
  for _ = 1, 12 do F.press("B", 3); F.idle(16) end

  -- Root row 6 = Trainers…. Visible rows with isRealFight=false hide Matches/Rematch:
  -- 0 Choose from map, 1 Trainer 1, 2 Trainer 2, 3 Partner, 4 Double Battle, 5 Try Battle.
  F.dbg(); F.idle(80)
  tap(ROW_TRAINERS); F.press("A", 3); F.idle(80)

  tap(1); F.press("A", 3); F.idle(50)
  F.press("Up", 3); F.idle(16)          -- 0 -> 1 TRAINER_SAWYER_1
  F.press("A", 3); F.idle(80)

  tap(2); F.press("A", 3); F.idle(50)
  F.press("Up", 3); F.idle(16)
  F.press("Up", 3); F.idle(16)          -- 0 -> 2 TRAINER_GRUNT_AQUA_HIDEOUT_1
  F.press("A", 3); F.idle(80)

  -- Belt: toggle Double Battle so a missed trainer-2 write still starts doubles.
  tap(4); F.press("A", 3); F.idle(30)
  F.shot("doubles_trainers_menu")
  F.press("Down", 3); F.idle(16)
  F.press("A", 3); F.idle(260)

  local started = waitBattle(B_DOUBLE, "doubles", 700)
    or ((F.battleFlags() & B_DOUBLE) ~= 0)
  local flags = F.battleFlags()
  F.L(string.format("  doubles: flags=0x%X battlers=%d ow=%s", flags, F.battlers(), tostring(F.ow())))
  F.check("doubles_healthbox_reached",
    started and (flags & B_DOUBLE) ~= 0,
    string.format("flags=0x%X battlers=%d ow=%s (need BATTLE_TYPE_DOUBLE)",
      flags, F.battlers(), tostring(F.ow())))
  if (flags & B_DOUBLE) == 0 then
    F.shot("doubles_not_reached")
    return false
  end

  for _ = 1, 120 do F.press("B", 2); F.idle(10) end
  F.idle(90)
  F.check("doubles has at least 3 battlers", F.battlers() >= 3, "battlers=" .. F.battlers())
  F.check("two-opponent or doubles flag is set",
    (flags & (B_DOUBLE | B_TWO_OPPONENTS)) ~= 0, string.format("flags=0x%X", flags))
  F.check("a doubles healthbox sprite is live",
    healthboxLive(0) or healthboxLive(1) or healthboxLive(2))
  F.shot("doubles_healthboxes")
  -- Both player slots are already out (cloned lead x2), so a switch is
  -- "Buffie is already in battle!" and traps us in the party menu. The
  -- nick leftover-after-switch visual is therefore not reachable with this
  -- party; bars/numbers are on the screenshot.
  F.check("field control returns after doubles", leaveBattle("doubles"))
  return true
end

F.run(function()
  if not F.boot(HUB_GROUP) then F.check("boot to the hub", false); F.finish(); return end
  F.check("player is free before the debug work", F.ensureFree())

  setParty()
  local n = F.r8(S.gPartiesCount)
  F.check("Set Party published a non-empty party", n ~= 0, "count=" .. n)
  F.shot("after_set_party")

  safariPhase()
  if not F.ow() then leaveBattle("between") end
  singlesPhase()
  if not F.ow() then leaveBattle("between2") end
  doublesPhase()

  F.finish()
end)
