-- DoorAnimsRegistered.lua — issue #92: doors that warp without ever opening.
--
-- THE BUG. `GetDoorGraphics` (src/field_door.c:681) matches a door on TWO things, not one:
--
--     if (gfx->metatileNum == metatileNum
--      && (gfx->tileset == gMapHeader.mapLayout->primaryTileset
--       || gfx->tileset == gMapHeader.mapLayout->secondaryTileset))
--
-- so a tileset that REUSES another tileset's door metatile id still needs its OWN row in
-- `sDoorAnimGraphicsTable`. With no row the lookup returns NULL, `FieldAnimateDoorOpen` returns
-- -1, and `Task_DoDoorWarp` reads -1 as "the animation has already finished" — the player warps
-- through a door that never opened. It does not crash, it does not warn at build time, and it
-- still makes a NOISE, because `GetDoorSoundEffect` falls through to SE_DOOR when the lookup
-- fails. That combination is why these sat unnoticed: they read as normal play.
--
-- WHAT THIS SUITE ASSERTS, AND WHY IT IS NOT VACUOUS.
--
-- The tempting test — "walk into the door and count the frames before the map changes" — is
-- exactly the test this project has been burned by before: frame parity shifts on unrelated ROM
-- edits and a green suite flips for reasons that have nothing to do with doors. So the
-- load-bearing assertions here do not measure time at all. They evaluate GetDoorGraphics' OWN
-- condition, on the live ROM, on the real map:
--
--   1. warp to the map, so gMapHeader.mapLayout is the real one;
--   2. read mapLayout->primaryTileset and ->secondaryTileset — the two POINTERS the game compares;
--   3. read the metatile id actually present at the door's (x,y) out of the live map grid
--      (gBackupMapLayout), not out of a header;
--   4. walk sDoorAnimGraphicsTable row by row to its terminator, applying the identical rule;
--   5. assert a row matches.
--
-- Because step 2 reads the pointers the game itself compares, no per-tileset symbol is needed and
-- nothing is assumed about WHICH tileset ought to match — a row only counts if its tileset pointer
-- is bit-for-bit one of this map's two. That is the whole bug, expressed as an assertion.
--
-- The struct decode is PROVED before it is trusted (`door_table_decode_matches_source`). struct
-- DoorGraphics is
--
--     { u16 metatileNum; const struct Tileset *tileset; u8 sound; u8 size;
--       const void *tiles; const void *palettes; }
--
-- whose hand-summed size is 18 but whose real stride is 20: the u16 is followed by two bytes of
-- alignment padding before the pointer. A wrong stride does not fail loudly, it silently reads
-- garbage that happens not to match anything — i.e. it reports the bug as still present, or as
-- fixed, at random. So row 0 is decoded first and required to reproduce the source table's first
-- entry exactly: METATILE_General_Door (0x021) paired with &gTileset_General, whose address comes
-- from the ELF via symbols.lua. The walk terminates on `tiles == NULL`, which is the condition
-- GetDoorGraphics itself uses — NOT on an all-zero row, because one live row (the cut Battle
-- Frontier door 0x3B0) has a NULL TILESET and must still be walked past.
--
-- WHAT THE FIX ADDED (the positive cases; these FAIL against the pre-fix ROM):
--
--   MAP_BATTLE_FRONTIER_OUTSIDE_EAST — layout (gTileset_General, gTileset_BattleFrontierOutsideEast)
--     0x396 sliding door at (5,8) (4,44) (14,51)
--     0x3FC normal  door at (10,28) (22,51) (65,31)
--   Both ids are the West map's door metatiles. The table registered them for
--   &gTileset_BattleFrontierOutsideWest only, which is neither half of the East map's pair, so all
--   six East doors failed the lookup. The East METATILE_* labels had existed unreferenced since
--   vanilla Emerald.
--
--   MAP_BELLCHIME_TRAIL — layout (gTileset_Johto_NorthWest, gTileset_BellchimeTrail)
--     0x333 door at (35,41), the Tin Tower entrance. 0x333 was registered for
--     &gTileset_Ecruteak_City only.
--
--   MAP_DRAGONS_DEN_CAVERN — layout (gTileset_Johto_NorthEast, gTileset_Cave_DragonsDen)
--     0x2FF sliding door at (31,46). This is the ONLY warp into MAP_DRAGONS_DEN_SHRINE, so the
--     shrine's single approach was through a door that never opened. The row reuses Violet City's
--     dojo frames; 0x2FF itself was in no row at all.
--
--   MAP_SAFARI_ZONE2 — layout (gTileset_Johto_NorthEast, gTileset_SafariZoneJohto)
--     0x2BF door at (35,11), the Safari Zone entrance hut. 0x2BF was registered for
--     &gTileset_FuchsiaCity only — the id was in the table the whole time.
--
--   MAP_MAHOGANYTOWN — layout (gTileset_Johto_NorthEast, gTileset_MahoganyTown)
--   MAP_LAKE_OF_RAGE — the SAME pair, which is why one row repairs four doors
--     0x2A2 doors at Mahogany (15,10) (27,10) and Lake of Rage (15,4) (39,41). 0x2A2 was
--     registered for &gTileset_LavenderTown only.
--
--   MAP_SSAQUA_1F — layout (gTileset_Johto_General, gTileset_ssaqua)
--   MAP_SSAQUA_PLAYERS_ROOM / _ROOM_NW / _ROOM_NE / _ROOM_NNE — (gTileset_Johto_Building,
--     gTileset_ssaqua), the same secondary, which is why one row repairs all five
--     0x281 doors at 1F (29,1) and at (2,1) in each of the four northern cabins. 0x281 is
--     METATILE_SSAnne_Door and was registered for &gTileset_SSAnne only. Issue #92 proposed
--     REMOVING this door's animation instead — it compared the two tilesets' art and found
--     ssaqua's to be "a sparse alternating lattice with no top layer", i.e. unported. That was a
--     decoding artefact: ssaqua's tiles.png is 8bpp, and reading it as packed 4bpp splits every
--     byte into two nibbles and blanks alternate pixel columns. The art is shared, and so are the
--     frames — at SSAnne's size of 2, because the frames are 8 tiles each and size 1 would draw
--     their upper half over the door.
--
-- THE NEGATIVE CONTROLS (these pass against BOTH the fixed and the pre-fix ROM, which is what
-- makes the seven checks above mean "the fix works" rather than merely "a door exists"):
--
--   * bf_battle_tower_door — (16,14) on the SAME East map is metatile 0x329, which already had its
--     own &gTileset_BattleFrontierOutsideEast row before the fix. A suite that only proved "some
--     door on this map resolves" would have passed on the broken ROM by matching this one.
--   * ecruteak_door_* — Ecruteak City's four 0x333 door warps ((39,22) (39,40) (19,40) (28,47))
--     already resolved via &gTileset_Ecruteak_City. Same metatile id as Bellchime's broken door,
--     different tileset pointer: the pair isolates the pointer half of the condition.
--   * *_non_door_metatile_has_no_row — a plain walkable metatile beside each door must match NO
--     row, so the matcher cannot be trivially returning true.
--   * *_foreign_tileset_door_id_has_no_row — the sharpest control. A metatile id that IS in the
--     table, but only for tilesets this map does not use, must NOT match: 0x021
--     (METATILE_General_Door, registered for &gTileset_General) looked up on Bellchime Trail, and
--     0x333 (registered for Ecruteak City's and Bellchime's tilesets) looked up on Battle Frontier
--     Outside East. If the id half alone decided the match, both would resolve and both checks
--     would fail — on either ROM. Each repaired map states one: 0x32B on Dragon's Den (the very
--     row whose ART that door borrows), 0x333 on Safari Zone 2, 0x2D2 on Mahogany Town.
--   * violet_dojo_door_* / lavender_door_* — the cross-map halves of the Ecruteak pattern.
--     Violet City's two 0x32B dojo doors carry the artwork Dragon's Den's row borrows, under their
--     own id and tileset; Lavender Town's three doors carry the very SAME id as Mahogany's,
--     0x2A2, behind a different tileset pointer. Both resolved before the fix and must still
--     resolve after it — adding a second row for an id that already had one must not shadow the
--     first. Each is paired with an assertion that the two maps have NO tileset in common, so the
--     comparison cannot be vacuous.
--   * safari_johto_gate_door_id_resolves_on_this_tileset — the strongest control here. 0x2D2 is
--     the OTHER door in gTileset_SafariZoneJohto and predates the fix, so looking it up on
--     SafariZone2 exercises the same map, the same pointer pair, the same walk and the same
--     matcher as the repaired 0x2BF lookup, and resolves on both ROMs. The two differ in one
--     thing only: the row. `safari_gate_shares_safari_zone2_tilesets` proves the pairs really are
--     identical, and MAP_SAFARI_ZONE_GATE is then visited so 0x2D2 is also checked as a real
--     MB_ANIMATED_DOOR at its own coordinates.
--   * *_door_id_also_has_a_foreign_row — the form checkNoDoorRow cannot express. On Mahogany Town
--     0x2A2 DOES resolve after the fix (correctly), so "must not match" is the wrong assertion;
--     what must hold is that a row carrying that id is bound to a tileset this map does not use
--     (&gTileset_LavenderTown). That is what makes the positive read "the &gTileset_MahoganyTown
--     row is present" rather than "0x2A2 is a known door metatile" — on the pre-fix ROM the id
--     was in the table and the doors still never opened. Safari Zone 2 states the same thing
--     against &gTileset_FuchsiaCity's 0x2BF row.
--
-- Every door coordinate is also required to really BE a door: `behaviorAt` reproduces
-- GetAttributeByMetatileIdAndMapLayout (primary below GetNumMetatilesInPrimary, secondary rebased
-- above it, attribute width from the TILESET's hasFrlgAttributes and not from the layout — see
-- issue #53) and the behavior must read MB_ANIMATED_DOOR. Without that the suite would be anchored
-- to bare numbers rather than to doors.
--
-- SUPPLEMENTARY, clearly labelled and NOT load-bearing: `*_live_door_animation_runs` walks the
-- player into one repaired door on Battle Frontier Outside East, Bellchime Trail and Mahogany
-- Town, and watches gTasks for Task_AnimateDoor.
-- `StartDoorAnimationTask` is the only caller of CreateTask(Task_AnimateDoor) and it is reached
-- only after GetDoorGraphics returns non-NULL, so an unregistered door never creates that task at
-- all. It is a real behavioural read of the same lookup, and it saves a screenshot of the door
-- part-way through opening. It is listed as supplementary because it polls frames; the pointer-rule
-- assertions above stand entirely on their own.

package.path = (debug.getinfo(1, "S").source:sub(2):match("^(.*[/\\])") or "") .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "DoorAnimsRegistered")

-- ---- map ids (include/constants/map_groups.h, MAP_X = (num | (group << 8))) -------------------
local GRP_SPECIAL_AREA,  MAP_BF_OUTSIDE_EAST = 26, 14   -- gMapGroup_SpecialArea
local GRP_JOHTO_ECRUTEAK                     = 85       -- gMapGroup_JohtoEcruteak
local MAP_ECRUTEAK_CITY, MAP_BELLCHIME_TRAIL = 0, 3
local GRP_INDOOR_BLACKTHORN, MAP_DRAGONS_DEN_CAVERN = 94, 12  -- gMapGroup_IndoorBlackthorn
local GRP_JOHTO_TOWNS,       MAP_VIOLET_CITY        = 75, 6   -- gMapGroup_JohtoTownsAndRoutes
local GRP_SAFARI_ZONE_JOHTO                         = 96      -- gMapGroup_SafariZoneJohto
local MAP_SAFARI_ZONE_GATE,  MAP_SAFARI_ZONE2       = 0, 11
local GRP_JOHTO_MAHOGANY                            = 91      -- gMapGroup_JohtoMahogany
local MAP_MAHOGANYTOWN,      MAP_LAKE_OF_RAGE       = 0, 4
local GRP_TOWNS_FRLG,        MAP_LAVENDER_TOWN      = 37, 4   -- gMapGroup_TownsAndRoutes_Frlg
local GRP_SSAQUA                                    = 95      -- gMapGroup_IndoorSSAqua
local MAP_SSAQUA_1F,           MAP_SSAQUA_PLAYERS_ROOM = 0, 3
local MAP_SSAQUA_ROOM_NW,      MAP_SSAQUA_ROOM_NE      = 4, 5
local MAP_SSAQUA_ROOM_NNE                               = 6
local GRP_DUNGEONS_FRLG,       MAP_SSANNE_1F_ROOM1      = 35, 12  -- gMapGroup_Dungeons_Frlg

-- Row 0 of sDoorAnimGraphicsTable in src/field_door.c. Used only to prove the decode.
local METATILE_General_Door = 0x021
-- Table walk bound. The real table is 112 rows plus a terminator; anything past this means the
-- stride is wrong and the walk is reading rubbish, which must be an error and not an infinite loop.
local MAX_DOOR_ROWS = 512

-- ---- the live map's layout and tileset pair --------------------------------------------------
-- gMapHeader.mapLayout is exactly the pointer GetDoorGraphics dereferences, so reading the two
-- tileset pointers out of it is a bit-for-bit reproduction of the comparison the game performs.
local function mapLayout() return F.r32(S.gMapHeader + S.MapHeader.mapLayout) end
local function tilesetPair()
  local layout = mapLayout()
  return F.r32(layout + S.MapLayout.primaryTileset), F.r32(layout + S.MapLayout.secondaryTileset)
end

-- ---- the LIVE map grid -----------------------------------------------------------------------
-- Not the layout's ROM blob: gBackupMapLayout is what MapGridGetMetatileIdAt reads, so a metatile
-- rewritten at runtime (setmetatile, a door left drawn open) is seen here exactly as the game sees
-- it. Blocks are u16, the metatile id is the low bits, and the grid is inset by MAP_OFFSET on both
-- axes because it also holds the border and the connected maps' fringes.
local function metatileAt(x, y)
  local width = F.r32(S.gBackupMapLayout + S.BackupMapLayout.width)
  local map   = F.r32(S.gBackupMapLayout + S.BackupMapLayout.map)
  local o     = S.BackupMapLayout.mapOffset
  local block = F.r16(map + ((x + o) + (y + o) * width) * 2)
  return (block >> S.Metatiles.idShift) & S.Metatiles.idMask
end

-- ---- metatile behavior, reproducing GetAttributeByMetatileIdAndMapLayout ----------------------
-- Two traps are deliberately reproduced rather than simplified away:
--   * the primary/secondary split point is 640 for an isFrlg OR isJohto layout and 512 otherwise
--     (GetNumMetatilesInPrimary, src/fieldmap.c) — Bellchime Trail and Ecruteak City are `johto`
--     layouts, Battle Frontier Outside East is not, and this suite reads doors on both kinds;
--   * the attribute WIDTH follows the TILESET (tileset->hasFrlgAttributes), never the layout. That
--     was issue #53: reading a u32 blob at u16 stride returns another metatile's behaviour for even
--     ids and ~0 for odd ones, which would make a real door here read MB_NORMAL.
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

-- ---- the door table --------------------------------------------------------------------------
local function doorRow(i)
  local a = S.sDoorAnimGraphicsTable + i * S.DoorGraphics.stride
  return {
    metatileNum = F.r16(a + S.DoorGraphics.metatileNum),
    tileset     = F.r32(a + S.DoorGraphics.tileset),
    sound       = F.r8(a + S.DoorGraphics.sound),
    size        = F.r8(a + S.DoorGraphics.size),
    tiles       = F.r32(a + S.DoorGraphics.tiles),
    palettes    = F.r32(a + S.DoorGraphics.palettes),
  }
end

-- Walk to the terminator, returning the usable row count (or -1 if the walk ran away, which means
-- the decode is wrong and every result below it is meaningless).
local function doorTableRows()
  for i = 0, MAX_DOOR_ROWS - 1 do
    if doorRow(i).tiles == 0 then return i end
  end
  return -1
end

-- GetDoorGraphics, verbatim, against the CURRENTLY LOADED map.
local function matchDoorRow(metatileId)
  local primary, secondary = tilesetPair()
  for i = 0, MAX_DOOR_ROWS - 1 do
    local row = doorRow(i)
    if row.tiles == 0 then return nil end   -- `while (gfx->tiles != NULL)`
    if row.metatileNum == metatileId
       and (row.tileset == primary or row.tileset == secondary) then
      row.row = i
      return row
    end
  end
  return nil
end

-- Diagnostic only: every row carrying this metatile id, whatever its tileset. On a failure this is
-- what distinguishes "the id is nowhere in the table" from "the id is there but bound to the wrong
-- tileset", which is the entire shape of issue #92.
local function rowsWithId(metatileId)
  local out = {}
  for i = 0, MAX_DOOR_ROWS - 1 do
    local row = doorRow(i)
    if row.tiles == 0 then break end
    if row.metatileNum == metatileId then
      out[#out + 1] = string.format("row%d->tileset=0x%08X", i, row.tileset)
    end
  end
  return #out > 0 and table.concat(out, " ") or "none"
end

-- ---- assertions ------------------------------------------------------------------------------
local function here() local x, y = F.pos(); return string.format("(%d,%d)", x, y) end

-- The positive form. `wantId` is asserted too, so a suite run against a map whose blockdata moved
-- fails as "wrong metatile here" instead of silently testing a different tile.
local function checkDoorRegistered(tag, x, y, wantId)
  local id = metatileAt(x, y)
  local behavior = behaviorAt(x, y)
  local primary, secondary = tilesetPair()
  F.check(tag .. "_is_an_animated_door",
          id == wantId and behavior == S.MetatileBehavior.ANIMATED_DOOR,
          string.format("(%d,%d) metatile 0x%03X (want 0x%03X) behavior %d (want MB_ANIMATED_DOOR=%d)",
                        x, y, id, wantId, behavior, S.MetatileBehavior.ANIMATED_DOOR))
  local hit = matchDoorRow(id)
  F.check(tag .. "_has_a_door_anim_row", hit ~= nil,
          hit and string.format("metatile 0x%03X matched row %d, tileset 0x%08X (%s half), "
                                .. "sound=%d size=%d",
                                id, hit.row, hit.tileset,
                                hit.tileset == primary and "primary" or "secondary",
                                hit.sound, hit.size)
              or string.format("GetDoorGraphics would return NULL for metatile 0x%03X on this map "
                               .. "(primary=0x%08X secondary=0x%08X) — FieldAnimateDoorOpen returns "
                               .. "-1 and the player warps through a shut door. Rows carrying this "
                               .. "id: %s", id, primary, secondary, rowsWithId(id)))
  return hit
end

-- The negative form for an id that is genuinely absent from this map's pair.
local function checkNoDoorRow(tag, metatileId, why)
  local primary, secondary = tilesetPair()
  local hit = matchDoorRow(metatileId)
  F.check(tag, hit == nil,
          hit and string.format("metatile 0x%03X UNEXPECTEDLY matched row %d (tileset 0x%08X) — %s",
                                metatileId, hit.row, hit.tileset, why)
              or string.format("metatile 0x%03X matches no row against (primary=0x%08X, "
                               .. "secondary=0x%08X); rows carrying this id: %s",
                               metatileId, primary, secondary, rowsWithId(metatileId)))
end

-- The positive form for an id with no coordinate attached: "GetDoorGraphics CAN resolve a door
-- through this map's own tileset pair". Used only for ids that already had a row before the fix,
-- so it holds on BOTH ROMs. That is what turns a neighbouring failure into "this one row is
-- missing" rather than "this map, this pair, or this matcher is broken".
local function checkDoorIdResolves(tag, metatileId, why)
  local primary, secondary = tilesetPair()
  local hit = matchDoorRow(metatileId)
  F.check(tag, hit ~= nil,
          hit and string.format("metatile 0x%03X matched row %d, tileset 0x%08X (%s half) — %s",
                                metatileId, hit.row, hit.tileset,
                                hit.tileset == primary and "primary" or "secondary", why)
              or string.format("metatile 0x%03X did NOT resolve against (primary=0x%08X, "
                               .. "secondary=0x%08X) — this control is supposed to hold on every "
                               .. "build, so the failure is in the walk or the map, not in the "
                               .. "fix. Rows carrying this id: %s",
                               metatileId, primary, secondary, rowsWithId(metatileId)))
end

-- The sharpest control available for a metatile id that TWO rows carry, which checkNoDoorRow
-- cannot express: on such a map the id DOES resolve (correctly, via this map's own row), so "must
-- not match" is the wrong assertion. What must be true instead is that the id is ALSO carried by a
-- row whose tileset is neither half of this map's pair — i.e. on the pre-fix ROM the id was
-- already sitting in the table and the door STILL did not open. Without this, a reader could read
-- the positive above as "0x2A2 was simply an unknown metatile". It holds on both ROMs, because the
-- foreign row is the pre-existing one.
local function checkForeignRowExistsForId(tag, metatileId, why)
  local primary, secondary = tilesetPair()
  local foreign, mine = {}, 0
  for i = 0, MAX_DOOR_ROWS - 1 do
    local row = doorRow(i)
    if row.tiles == 0 then break end
    if row.metatileNum == metatileId then
      if row.tileset == primary or row.tileset == secondary then
        mine = mine + 1
      else
        foreign[#foreign + 1] = string.format("row%d->tileset=0x%08X", i, row.tileset)
      end
    end
  end
  F.check(tag, #foreign > 0,
          #foreign > 0
            and string.format("metatile 0x%03X is carried by %d row(s) bound to a tileset this map "
                              .. "does not use (%s) as well as %d of its own — %s",
                              metatileId, #foreign, table.concat(foreign, " "), mine, why)
            or string.format("no row carries metatile 0x%03X for a tileset outside this map's pair "
                             .. "(primary=0x%08X secondary=0x%08X), so the match above says nothing "
                             .. "about the tileset-pointer half of the condition. Rows carrying "
                             .. "this id: %s", metatileId, primary, secondary, rowsWithId(metatileId)))
end

-- ---- supplementary: the live animation task --------------------------------------------------
-- func holds a Thumb pointer, so the low bit is set; mask it before comparing to the symbol.
local function doorAnimTaskLive()
  for i = 0, S.Task.count - 1 do
    local a = S.gTasks + i * S.Task.stride
    if F.r8(a + S.Task.isActive) ~= 0
       and (F.r32(a + S.Task.func) & 0xFFFFFFFE) == S.Task_AnimateDoor then
      return true, i
    end
  end
  return false, -1
end

-- Walk north into a door and watch for Task_AnimateDoor while the warp runs. Not timing-sensitive
-- in the fragile sense: it polls EVERY frame from before the door warp starts until the map
-- changes, so the only way to miss the task is for it never to have been created.
local function walkIntoDoor(tag, doorX, doorY, wantGrp, wantMap)
  if not F.leg(doorX, doorY + 1) then
    F.check(tag .. "_live_door_animation_runs", false,
            string.format("could not reach (%d,%d), the tile below the door; stuck at %s",
                          doorX, doorY + 1, here()))
    return false
  end
  -- Deliberately NOT F.face("Up") first. Facing a direction is done by holding it for a few
  -- frames, and the door tile is impassable, so that press IS what fires TryDoorWarp — the
  -- animation would then start and could finish inside face()'s trailing idle, before the poll
  -- below ever looked. Holding Up inside the poll loop instead means the door warp cannot begin
  -- until after polling has started, which is what makes "the task was never created" the only
  -- way to miss it.
  local firstSeen, shotDone, arrived, frames = -1, false, false, 0
  for i = 1, 400 do
    joypad.set({ Up = true }); emu.frameadvance()
    frames = i
    if doorAnimTaskLive() then
      if firstSeen < 0 then firstSeen = i end
    elseif firstSeen >= 0 and not shotDone then
      -- The task died before the shot budget elapsed; grab what there is rather than nothing.
      F.shot(tag .. "_door_animation"); shotDone = true
    end
    -- 12 frames in. The open animation is four DoorAnimFrames of 4 ticks each (sDoorOpenAnimFrames
    -- / sDoorAnimFrames_OpenSmallFrlg, src/field_door.c), so this lands on the last, widest frame
    -- rather than on the barely-cracked first one; the `elseif` above still grabs a shot if the
    -- task somehow ends sooner.
    if firstSeen >= 0 and not shotDone and i >= firstSeen + 12 then
      F.shot(tag .. "_door_animation"); shotDone = true
    end
    if F.grp() == wantGrp and F.mapn() == wantMap then arrived = true; break end
  end
  F.idle(120)
  F.check(tag .. "_live_door_animation_runs", firstSeen >= 0,
          firstSeen >= 0
            and string.format("Task_AnimateDoor went live %d frames into the door warp; reached "
                              .. "map %d.%d after %d frames", firstSeen, F.grp(), F.mapn(), frames)
            or string.format("no Task_AnimateDoor in %d frames of walking into (%d,%d) — "
                             .. "StartDoorAnimationTask is only reached when GetDoorGraphics "
                             .. "returns non-NULL, so this is the unregistered-door path "
                             .. "(arrived=%s, now on map %d.%d at %s)",
                             frames, doorX, doorY, tostring(arrived), F.grp(), F.mapn(), here()))
  return arrived
end

-- ---- the door coordinates --------------------------------------------------------------------
-- Every one of these is a warp_event in the map's map.json standing on the named metatile; the ids
-- were read back out of data/layouts/*/map.bin. See the ValidateDoorAnims.py report for the
-- tree-wide census this suite is the runtime half of.
local BF_EAST_SLIDING = { { 5, 8 }, { 4, 44 }, { 14, 51 } }     -- 0x396
local BF_EAST_NORMAL  = { { 10, 28 }, { 22, 51 }, { 65, 31 } }  -- 0x3FC
local BF_EAST_TOWER   = { 16, 14 }                              -- 0x329, worked before the fix
local BF_EAST_PLAIN   = { 16, 15 }                              -- 0x319, the walkable tile below it
local ECRUTEAK_DOORS  = { { 39, 22 }, { 39, 40 }, { 19, 40 }, { 28, 47 } }  -- 0x333, worked before
local BELLCHIME_DOOR  = { 35, 41 }                              -- 0x333, the Tin Tower entrance
local BELLCHIME_PLAIN = { 35, 42 }                              -- 0x2E3, the tile below it

local DRAGONS_DEN_DOOR   = { 31, 46 }                           -- 0x2FF, the only way into the shrine
local DRAGONS_DEN_PLAIN  = { 31, 47 }                           -- 0x1C6, the walkable tile below it
local VIOLET_DOJO_DOORS  = { { 30, 13 }, { 39, 36 } }           -- 0x32B, worked before the fix
local SAFARI2_DOOR       = { 35, 11 }                           -- 0x2BF, the Safari Zone entrance hut
local SAFARI2_PLAIN      = { 35, 12 }                           -- 0x009, the walkable tile below it
local SAFARI_GATE_DOOR   = { 16, 8 }                            -- 0x2D2, worked before the fix
local MAHOGANY_DOORS     = { { 15, 10 }, { 27, 10 } }           -- 0x2A2
local MAHOGANY_PLAIN     = { 15, 11 }                           -- 0x0D3, the tile below the first
local LAKE_OF_RAGE_DOORS = { { 15, 4 }, { 39, 41 } }            -- 0x2A2, same secondary as Mahogany
local LAVENDER_DOORS     = { { 10, 11 }, { 5, 16 }, { 10, 16 } }  -- 0x2A2, worked before the fix

-- S.S. Aqua. The gangway door on 1F, then the four northern cabins, whose warp 0 sits ON the door
-- at (2,1) in every one of them -- they share LAYOUT-shaped geometry but are four separate maps.
local SSAQUA_1F_DOOR    = { 29, 1 }                             -- 0x281, the gangway to the port
local SSAQUA_1F_PLAIN   = { 29, 2 }                             -- 0x2C1, the walkable tile below it
local SSAQUA_CABIN_DOOR = { 2, 1 }                              -- 0x281, identical in all four
local SSAQUA_CABIN_PLAIN = { 2, 2 }                             -- 0x31E, the tile below it
local SSANNE_ROOM1_DOOR = { 2, 1 }                              -- 0x281, worked before the fix

-- METATILE_SSAnne_Door. Shared with &gTileset_SSAnne, which is the pre-fix row.
local METATILE_SSANNE_DOOR = 0x281
-- METATILE_Johto_General_Door. Registered for Johto_General and its three recolours (and
-- General_Frlg) -- so it resolves on SSAqua 1F, whose PRIMARY is Johto_General, and must not on
-- the cabins, whose primary is Johto_Building and which carry no door row at all.
local METATILE_JOHTO_GENERAL_DOOR = 0x03D

local METATILE_BF_DOOR_SLIDING = 0x396
local METATILE_BF_DOOR         = 0x3FC
local METATILE_BF_DOOR_TOWER   = 0x329
local METATILE_ECRUTEAK_DOOR   = 0x333
-- METATILE_CaveDragonsDen_Door. Unique by id: only ever registered for &gTileset_Cave_DragonsDen.
local METATILE_DRAGONS_DEN_DOOR = 0x2FF
-- METATILE_VioletCity_Dojo_Door. Also unique by id, and the row Dragon's Den borrows its ART from.
local METATILE_VIOLET_DOJO_DOOR = 0x32B
-- METATILE_SafariZoneJohto_Door. Shared with METATILE_FuchsiaCity_Door (&gTileset_FuchsiaCity).
local METATILE_SAFARI_DOOR      = 0x2BF
-- METATILE_SafariZoneJohto_Safari. Shared with METATILE_FuchsiaCity_SafariZoneDoor. Its
-- &gTileset_SafariZoneJohto row is the pre-fix one, on the very tileset the 0x2BF row was added to.
local METATILE_SAFARI_GATE_DOOR = 0x2D2
-- METATILE_MahoganyTown_Door. Shared with METATILE_LavenderTown_Door (&gTileset_LavenderTown).
local METATILE_MAHOGANY_DOOR    = 0x2A2

local function main()
  if not F.boot() then return F.finish() end

  -- ---- 0. prove the struct decode before trusting a single row ------------------------------
  local rows = doorTableRows()
  F.check("door_table_walk_terminates", rows > 100 and rows < MAX_DOOR_ROWS,
          string.format("%d usable rows before the tiles==NULL terminator at 0x%08X (a wrong "
                        .. "stride either runs away or terminates almost immediately)",
                        rows, S.sDoorAnimGraphicsTable))
  local row0 = doorRow(0)
  F.check("door_table_decode_matches_source",
          row0.metatileNum == METATILE_General_Door and row0.tileset == S.gTileset_General
            and row0.tiles ~= 0,
          string.format("row 0 decodes as metatile 0x%03X tileset 0x%08X (source says "
                        .. "METATILE_General_Door 0x%03X, &gTileset_General 0x%08X), sound=%d "
                        .. "size=%d tiles=0x%08X",
                        row0.metatileNum, row0.tileset, METATILE_General_Door, S.gTileset_General,
                        row0.sound, row0.size, row0.tiles))

  -- ---- 1. MAP_BATTLE_FRONTIER_OUTSIDE_EAST --------------------------------------------------
  -- Warp id 6 is the Exchange Service Corner door at (10,28), one of the six repaired ones.
  -- SetUpWarpExitTask picks Task_ExitDoor purely from the arrival tile's BEHAVIOR, so the player
  -- is walked one tile south out of the doorway on arrival exactly as a real door warp would —
  -- on the pre-fix ROM too, because Task_ExitDoor's state 3 treats FieldAnimateDoorClose's -1 as
  -- "already finished". The landing tile is therefore not itself evidence of anything.
  F.check("warp_to_battle_frontier_outside_east",
          F.warpTo(0, 2, 6, 0, 1, 4, 0, 0, 6, GRP_SPECIAL_AREA, MAP_BF_OUTSIDE_EAST, "bfeast")
            and F.ow(),
          string.format("map %d.%d at %s", F.grp(), F.mapn(), here()))
  local pri, sec = tilesetPair()
  F.L(string.format("  BattleFrontier_OutsideEast layout 0x%08X: primary=0x%08X secondary=0x%08X",
                    mapLayout(), pri, sec))
  F.shot("bf_east_arrival")

  for i, c in ipairs(BF_EAST_SLIDING) do
    checkDoorRegistered(string.format("bf_sliding_door_%d", i), c[1], c[2], METATILE_BF_DOOR_SLIDING)
  end
  for i, c in ipairs(BF_EAST_NORMAL) do
    checkDoorRegistered(string.format("bf_normal_door_%d", i), c[1], c[2], METATILE_BF_DOOR)
  end

  -- NEGATIVE CONTROL. Already registered before the fix, on this very map — so it passes on the
  -- pre-fix ROM and proves the six checks above are not just "this map has a working door".
  checkDoorRegistered("bf_battle_tower_door", BF_EAST_TOWER[1], BF_EAST_TOWER[2],
                      METATILE_BF_DOOR_TOWER)

  -- NEGATIVE CONTROL. The plain walkable tile directly below the Battle Tower door.
  local plainId = metatileAt(BF_EAST_PLAIN[1], BF_EAST_PLAIN[2])
  local plainBehavior = behaviorAt(BF_EAST_PLAIN[1], BF_EAST_PLAIN[2])
  F.check("bf_non_door_metatile_is_not_a_door", plainBehavior ~= S.MetatileBehavior.ANIMATED_DOOR,
          string.format("(%d,%d) metatile 0x%03X behavior %d",
                        BF_EAST_PLAIN[1], BF_EAST_PLAIN[2], plainId, plainBehavior))
  checkNoDoorRow("bf_non_door_metatile_has_no_row", plainId,
                 "a non-door metatile must not resolve, or the matcher is returning true for "
                 .. "anything and every check above is vacuous")

  -- NEGATIVE CONTROL, and the sharpest one: 0x333 IS in the table (Ecruteak City's door, and since
  -- the fix Bellchime Trail's too) but for tilesets this map does not use. If the id alone decided
  -- the match this would resolve — on either ROM.
  checkNoDoorRow("bf_foreign_tileset_door_id_has_no_row", METATILE_ECRUTEAK_DOOR,
                 "0x333 is registered only for Ecruteak City's and Bellchime Trail's tilesets, "
                 .. "neither of which is in this map's pair, so a match here would mean the "
                 .. "tileset-pointer half of GetDoorGraphics' condition is not being applied")

  -- SUPPLEMENTARY. Walk into the (10,28) door and watch the animation task.
  walkIntoDoor("bf_normal_door", BF_EAST_NORMAL[1][1], BF_EAST_NORMAL[1][2],
               GRP_SPECIAL_AREA, 42)   -- MAP_BATTLE_FRONTIER_EXCHANGE_SERVICE_CORNER

  -- ---- 2. MAP_BELLCHIME_TRAIL ---------------------------------------------------------------
  -- Warp id 1 is the Tin Tower entrance at (35,41) — the repaired door itself.
  F.check("warp_to_bellchime_trail",
          F.warpTo(0, 8, 5, 0, 0, 3, 0, 0, 1, GRP_JOHTO_ECRUTEAK, MAP_BELLCHIME_TRAIL, "bellchime")
            and F.ow(),
          string.format("map %d.%d at %s", F.grp(), F.mapn(), here()))
  local bPri, bSec = tilesetPair()
  F.L(string.format("  BellchimeTrail layout 0x%08X: primary=0x%08X secondary=0x%08X",
                    mapLayout(), bPri, bSec))
  F.shot("bellchime_arrival")

  checkDoorRegistered("bellchime_tin_tower_door", BELLCHIME_DOOR[1], BELLCHIME_DOOR[2],
                      METATILE_ECRUTEAK_DOOR)

  local bPlainId = metatileAt(BELLCHIME_PLAIN[1], BELLCHIME_PLAIN[2])
  local bPlainBehavior = behaviorAt(BELLCHIME_PLAIN[1], BELLCHIME_PLAIN[2])
  F.check("bellchime_non_door_metatile_is_not_a_door",
          bPlainBehavior ~= S.MetatileBehavior.ANIMATED_DOOR,
          string.format("(%d,%d) metatile 0x%03X behavior %d", BELLCHIME_PLAIN[1],
                        BELLCHIME_PLAIN[2], bPlainId, bPlainBehavior))
  checkNoDoorRow("bellchime_non_door_metatile_has_no_row", bPlainId,
                 "a non-door metatile must not resolve on this map either")
  checkNoDoorRow("bellchime_foreign_tileset_door_id_has_no_row", METATILE_General_Door,
                 "METATILE_General_Door 0x021 is registered for &gTileset_General, which is "
                 .. "neither half of this johto layout's pair")

  walkIntoDoor("bellchime_tin_tower_door", BELLCHIME_DOOR[1], BELLCHIME_DOOR[2],
               86, 12)                 -- MAP_TIN_TOWER_1F = (12 | (86 << 8))

  -- ---- 3. MAP_ECRUTEAK_CITY (negative control map) ------------------------------------------
  -- Same metatile id as Bellchime's door, different secondary tileset. These four resolved before
  -- the fix and must still resolve after it — which is what makes bellchime_tin_tower_door a
  -- statement about the missing ROW rather than about metatile 0x333 being unsupported.
  F.check("warp_to_ecruteak_city",
          F.warpTo(0, 8, 5, 0, 0, 0, 0, 0, 3, GRP_JOHTO_ECRUTEAK, MAP_ECRUTEAK_CITY, "ecruteak")
            and F.ow(),
          string.format("map %d.%d at %s", F.grp(), F.mapn(), here()))
  local ePri, eSec = tilesetPair()
  F.L(string.format("  EcruteakCity layout 0x%08X: primary=0x%08X secondary=0x%08X",
                    mapLayout(), ePri, eSec))
  F.check("ecruteak_shares_bellchime_primary_not_secondary", ePri == bPri and eSec ~= bSec,
          string.format("Ecruteak (0x%08X, 0x%08X) vs Bellchime (0x%08X, 0x%08X) — the two maps "
                        .. "must differ ONLY in the secondary, or the 0x333 pair below proves "
                        .. "nothing about the tileset pointer", ePri, eSec, bPri, bSec))
  F.shot("ecruteak_arrival")

  for i, c in ipairs(ECRUTEAK_DOORS) do
    checkDoorRegistered(string.format("ecruteak_door_%d", i), c[1], c[2], METATILE_ECRUTEAK_DOOR)
  end

  -- ---- 4. MAP_DRAGONS_DEN_CAVERN ------------------------------------------------------------
  -- Warp id 1 is the shrine entrance at (31,46). This one is not a convenience door: it is the
  -- ONLY warp into MAP_DRAGONS_DEN_SHRINE, so on the pre-fix ROM the single approach to the shrine
  -- was through a door that never opened.
  F.check("warp_to_dragons_den_cavern",
          F.warpTo(0, 9, 4, 0, 1, 2, 0, 0, 1, GRP_INDOOR_BLACKTHORN, MAP_DRAGONS_DEN_CAVERN,
                   "dragonsden") and F.ow(),
          string.format("map %d.%d at %s", F.grp(), F.mapn(), here()))
  local ddPri, ddSec = tilesetPair()
  F.L(string.format("  DragonsDen_Cavern layout 0x%08X: primary=0x%08X secondary=0x%08X",
                    mapLayout(), ddPri, ddSec))
  F.shot("dragons_den_arrival")

  checkDoorRegistered("dragons_den_shrine_door", DRAGONS_DEN_DOOR[1], DRAGONS_DEN_DOOR[2],
                      METATILE_DRAGONS_DEN_DOOR)

  local ddPlainId = metatileAt(DRAGONS_DEN_PLAIN[1], DRAGONS_DEN_PLAIN[2])
  local ddPlainBehavior = behaviorAt(DRAGONS_DEN_PLAIN[1], DRAGONS_DEN_PLAIN[2])
  F.check("dragons_den_non_door_metatile_is_not_a_door",
          ddPlainBehavior ~= S.MetatileBehavior.ANIMATED_DOOR,
          string.format("(%d,%d) metatile 0x%03X behavior %d", DRAGONS_DEN_PLAIN[1],
                        DRAGONS_DEN_PLAIN[2], ddPlainId, ddPlainBehavior))
  checkNoDoorRow("dragons_den_non_door_metatile_has_no_row", ddPlainId,
                 "a non-door metatile must not resolve on this map either")

  -- NEGATIVE CONTROL, sharpened by the art the new row reuses: 0x32B is Violet City's dojo door,
  -- whose FRAMES this Dragon's Den row shares byte-for-byte. If matching leaked through the
  -- graphics rather than through the tileset pointer, 0x32B would resolve here. It must not.
  checkNoDoorRow("dragons_den_foreign_tileset_door_id_has_no_row", METATILE_VIOLET_DOJO_DOOR,
                 "0x32B is registered only for &gTileset_VioletCity, which is neither half of this "
                 .. "cave's pair, even though the Dragon's Den row borrows that row's exact tiles "
                 .. "and palettes")

  -- ---- 5. MAP_VIOLET_CITY (negative control map for Dragon's Den) ----------------------------
  -- The same dojo door art under its OWN metatile id and its OWN tileset. These two resolved
  -- before the fix and must still resolve after it, which is what makes dragons_den_shrine_door a
  -- statement about the missing ROW rather than about that artwork being unsupported.
  F.check("warp_to_violet_city",
          F.warpTo(0, 7, 5, 0, 0, 6, 0, 0, 1, GRP_JOHTO_TOWNS, MAP_VIOLET_CITY, "violet")
            and F.ow(),
          string.format("map %d.%d at %s", F.grp(), F.mapn(), here()))
  local vPri, vSec = tilesetPair()
  F.L(string.format("  VioletCity layout 0x%08X: primary=0x%08X secondary=0x%08X",
                    mapLayout(), vPri, vSec))
  F.check("violet_and_dragons_den_share_no_tileset",
          vPri ~= ddPri and vPri ~= ddSec and vSec ~= ddPri and vSec ~= ddSec,
          string.format("Violet (0x%08X, 0x%08X) vs Dragon's Den (0x%08X, 0x%08X) — the two maps "
                        .. "must have no tileset in common, or the pair below proves nothing about "
                        .. "the tileset pointer", vPri, vSec, ddPri, ddSec))
  F.shot("violet_arrival")

  for i, c in ipairs(VIOLET_DOJO_DOORS) do
    checkDoorRegistered(string.format("violet_dojo_door_%d", i), c[1], c[2],
                        METATILE_VIOLET_DOJO_DOOR)
  end

  -- ---- 6. MAP_SAFARI_ZONE2 ------------------------------------------------------------------
  -- Warp id 0 is the entrance hut at (35,11), the repaired door. gTileset_SafariZoneJohto already
  -- had a row before the fix — for the OTHER door in the same tileset — so this map carries the
  -- strongest control this suite can state, below.
  F.check("warp_to_safari_zone2",
          F.warpTo(0, 9, 6, 0, 1, 1, 0, 0, 0, GRP_SAFARI_ZONE_JOHTO, MAP_SAFARI_ZONE2, "safari2")
            and F.ow(),
          string.format("map %d.%d at %s", F.grp(), F.mapn(), here()))
  local s2Pri, s2Sec = tilesetPair()
  F.L(string.format("  SafariZone2 layout 0x%08X: primary=0x%08X secondary=0x%08X",
                    mapLayout(), s2Pri, s2Sec))
  F.shot("safari_zone2_arrival")

  checkDoorRegistered("safari_johto_town_door", SAFARI2_DOOR[1], SAFARI2_DOOR[2],
                      METATILE_SAFARI_DOOR)

  -- NEGATIVE CONTROL, and the strongest one in this suite: 0x2D2 is the Safari Zone gate door,
  -- registered for &gTileset_SafariZoneJohto — the SAME tileset the 0x2BF row above was added to,
  -- on the SAME map, against the SAME pointer pair. It resolves on the pre-fix ROM too. So when
  -- safari_johto_town_door_has_a_door_anim_row fails on that ROM it cannot be blamed on the map,
  -- the pair, the walk or the matcher: the only difference between the two lookups is the row.
  checkDoorIdResolves("safari_johto_gate_door_id_resolves_on_this_tileset", METATILE_SAFARI_GATE_DOOR,
                      "0x2D2 is the other &gTileset_SafariZoneJohto door and predates the fix")

  -- ...and the id half of the new door is not novel either: 0x2BF is METATILE_FuchsiaCity_Door,
  -- registered for &gTileset_FuchsiaCity since vanilla FRLG. It was in the table all along and the
  -- door still did not open, which is the whole of issue #92 in one assertion.
  checkForeignRowExistsForId("safari_johto_town_door_id_also_has_a_foreign_row", METATILE_SAFARI_DOOR,
                             "0x2BF is METATILE_FuchsiaCity_Door as well, so the pre-fix lookup "
                             .. "had the id and rejected it on the tileset pointer")

  local s2PlainId = metatileAt(SAFARI2_PLAIN[1], SAFARI2_PLAIN[2])
  local s2PlainBehavior = behaviorAt(SAFARI2_PLAIN[1], SAFARI2_PLAIN[2])
  F.check("safari_johto_non_door_metatile_is_not_a_door",
          s2PlainBehavior ~= S.MetatileBehavior.ANIMATED_DOOR,
          string.format("(%d,%d) metatile 0x%03X behavior %d", SAFARI2_PLAIN[1], SAFARI2_PLAIN[2],
                        s2PlainId, s2PlainBehavior))
  checkNoDoorRow("safari_johto_non_door_metatile_has_no_row", s2PlainId,
                 "a non-door metatile must not resolve on this map either")
  checkNoDoorRow("safari_johto_foreign_tileset_door_id_has_no_row", METATILE_ECRUTEAK_DOOR,
                 "0x333 is registered for Ecruteak City's and Bellchime Trail's tilesets, neither "
                 .. "of which is in this map's pair")

  -- ---- 7. MAP_SAFARI_ZONE_GATE (the same-tileset control, as a real door) --------------------
  -- The lookup control above is stated on SafariZone2 itself; this walks to where that door
  -- physically is and requires it to be a live MB_ANIMATED_DOOR resolving a row. Both maps carry
  -- the identical (primary, secondary) pair, which is asserted rather than assumed.
  F.check("warp_to_safari_zone_gate",
          F.warpTo(0, 9, 6, 0, 0, 0, 0, 0, 0, GRP_SAFARI_ZONE_JOHTO, MAP_SAFARI_ZONE_GATE,
                   "safarigate") and F.ow(),
          string.format("map %d.%d at %s", F.grp(), F.mapn(), here()))
  local sgPri, sgSec = tilesetPair()
  F.L(string.format("  SafariZoneGate layout 0x%08X: primary=0x%08X secondary=0x%08X",
                    mapLayout(), sgPri, sgSec))
  F.check("safari_gate_shares_safari_zone2_tilesets", sgPri == s2Pri and sgSec == s2Sec,
          string.format("gate (0x%08X, 0x%08X) vs SafariZone2 (0x%08X, 0x%08X) — the 0x2D2 lookup "
                        .. "control on SafariZone2 is only legitimate if the pairs are identical",
                        sgPri, sgSec, s2Pri, s2Sec))
  F.shot("safari_gate_arrival")

  checkDoorRegistered("safari_gate_door", SAFARI_GATE_DOOR[1], SAFARI_GATE_DOOR[2],
                      METATILE_SAFARI_GATE_DOOR)

  -- ---- 8. MAP_MAHOGANYTOWN ------------------------------------------------------------------
  -- Warp id 1 is the shop door at (15,10). 0x2A2 is ALSO METATILE_LavenderTown_Door, registered
  -- for &gTileset_LavenderTown, so on this map the id alone would have resolved if the pointer
  -- half of the condition were not applied — see the two controls below.
  F.check("warp_to_mahogany_town",
          F.warpTo(0, 9, 1, 0, 0, 0, 0, 0, 1, GRP_JOHTO_MAHOGANY, MAP_MAHOGANYTOWN, "mahogany")
            and F.ow(),
          string.format("map %d.%d at %s", F.grp(), F.mapn(), here()))
  local mPri, mSec = tilesetPair()
  F.L(string.format("  Mahoganytown layout 0x%08X: primary=0x%08X secondary=0x%08X",
                    mapLayout(), mPri, mSec))
  F.shot("mahogany_arrival")

  for i, c in ipairs(MAHOGANY_DOORS) do
    checkDoorRegistered(string.format("mahogany_door_%d", i), c[1], c[2], METATILE_MAHOGANY_DOOR)
  end

  -- NEGATIVE CONTROL, the sharp one this map exists to state. checkNoDoorRow cannot be used for
  -- 0x2A2 here — after the fix it resolves, correctly — so the assertion is instead that a row
  -- carrying this very id is bound to a tileset this map does not use. It holds on both ROMs
  -- (Lavender's row is the pre-existing one), and it is what makes the two positives above mean
  -- "the &gTileset_MahoganyTown row is present" instead of "0x2A2 is a known door metatile".
  checkForeignRowExistsForId("mahogany_door_id_also_has_a_foreign_row", METATILE_MAHOGANY_DOOR,
                             "0x2A2 is METATILE_LavenderTown_Door as well, so on the pre-fix ROM "
                             .. "the id was in the table and these doors still never opened")

  local mPlainId = metatileAt(MAHOGANY_PLAIN[1], MAHOGANY_PLAIN[2])
  local mPlainBehavior = behaviorAt(MAHOGANY_PLAIN[1], MAHOGANY_PLAIN[2])
  F.check("mahogany_non_door_metatile_is_not_a_door",
          mPlainBehavior ~= S.MetatileBehavior.ANIMATED_DOOR,
          string.format("(%d,%d) metatile 0x%03X behavior %d", MAHOGANY_PLAIN[1], MAHOGANY_PLAIN[2],
                        mPlainId, mPlainBehavior))
  checkNoDoorRow("mahogany_non_door_metatile_has_no_row", mPlainId,
                 "a non-door metatile must not resolve on this map either")
  checkNoDoorRow("mahogany_foreign_tileset_door_id_has_no_row", METATILE_SAFARI_GATE_DOOR,
                 "0x2D2 is registered for Fuchsia City's and the Johto Safari Zone's tilesets, "
                 .. "neither of which is in this map's pair")

  -- SUPPLEMENTARY. Walk into the (15,10) shop door and watch the animation task.
  walkIntoDoor("mahogany_door", MAHOGANY_DOORS[1][1], MAHOGANY_DOORS[1][2],
               92, 3)                  -- MAP_MAHOGANY_TOWN_SHOP, gMapGroup_IndoorMahogany

  -- ---- 9. MAP_LAKE_OF_RAGE ------------------------------------------------------------------
  -- A second map on the same secondary tileset. One row repaired four doors across two maps, and
  -- that claim is only testable by reading the OTHER map's pointer pair on the live ROM.
  F.check("warp_to_lake_of_rage",
          F.warpTo(0, 9, 1, 0, 0, 4, 0, 0, 1, GRP_JOHTO_MAHOGANY, MAP_LAKE_OF_RAGE, "lakeofrage")
            and F.ow(),
          string.format("map %d.%d at %s", F.grp(), F.mapn(), here()))
  local lrPri, lrSec = tilesetPair()
  F.L(string.format("  LakeOfRage layout 0x%08X: primary=0x%08X secondary=0x%08X",
                    mapLayout(), lrPri, lrSec))
  F.check("lake_of_rage_shares_mahogany_tilesets", lrPri == mPri and lrSec == mSec,
          string.format("Lake of Rage (0x%08X, 0x%08X) vs Mahogany Town (0x%08X, 0x%08X) — the "
                        .. "single row is only reaching all four doors if the pairs are identical",
                        lrPri, lrSec, mPri, mSec))
  F.shot("lake_of_rage_arrival")

  for i, c in ipairs(LAKE_OF_RAGE_DOORS) do
    checkDoorRegistered(string.format("lake_of_rage_door_%d", i), c[1], c[2],
                        METATILE_MAHOGANY_DOOR)
  end

  -- ---- 10. MAP_LAVENDER_TOWN (negative control map for Mahogany) -----------------------------
  -- The same metatile id, 0x2A2, behind a different tileset pointer, on a map that has no tileset
  -- in common with Mahogany Town. These three resolved before the fix and must still resolve
  -- after it: adding a second row for an id that already had one must not shadow the first.
  F.check("warp_to_lavender_town",
          F.warpTo(0, 3, 7, 0, 0, 4, 0, 0, 2, GRP_TOWNS_FRLG, MAP_LAVENDER_TOWN, "lavender")
            and F.ow(),
          string.format("map %d.%d at %s", F.grp(), F.mapn(), here()))
  local lvPri, lvSec = tilesetPair()
  F.L(string.format("  LavenderTown layout 0x%08X: primary=0x%08X secondary=0x%08X",
                    mapLayout(), lvPri, lvSec))
  F.check("lavender_and_mahogany_share_no_tileset",
          lvPri ~= mPri and lvPri ~= mSec and lvSec ~= mPri and lvSec ~= mSec,
          string.format("Lavender (0x%08X, 0x%08X) vs Mahogany (0x%08X, 0x%08X) — the two maps must "
                        .. "have no tileset in common, or the shared 0x2A2 proves nothing",
                        lvPri, lvSec, mPri, mSec))
  F.shot("lavender_arrival")

  for i, c in ipairs(LAVENDER_DOORS) do
    checkDoorRegistered(string.format("lavender_door_%d", i), c[1], c[2], METATILE_MAHOGANY_DOOR)
  end

  -- ---- 11. MAP_SSAQUA_1F --------------------------------------------------------------------
  -- The last five warps of #92, and the one the issue got backwards. `ssaqua` 0x281 is byte-equal
  -- to METATILE_SSAnne_Door, and the issue treated that as a trap rather than a gift -- it reported
  -- ss_anne_frlg's art as "a solid door with a frame" against ssaqua's "sparse alternating lattice
  -- with no top layer", and concluded the metatile had been copied without its art. There is no
  -- lattice: ssaqua's tiles.png is 8bpp, and reading it as packed 4bpp splits every byte into two
  -- nibbles, which blanks alternate pixel columns and manufactures exactly that pattern. The frames
  -- really are shared, so the row is SSAnne's own tiles and palettes at SSAnne's size of 2.
  F.check("warp_to_ssaqua_1f",
          F.warpTo(0, 9, 5, 0, 0, 0, 0, 0, 0, GRP_SSAQUA, MAP_SSAQUA_1F, "ssaqua1f")
            and F.ow(),
          string.format("map %d.%d at %s", F.grp(), F.mapn(), here()))
  local aPri, aSec = tilesetPair()
  F.L(string.format("  SSAqua_1F layout 0x%08X: primary=0x%08X secondary=0x%08X",
                    mapLayout(), aPri, aSec))
  F.shot("ssaqua_1f_arrival")

  checkDoorRegistered("ssaqua_1f_gangway_door", SSAQUA_1F_DOOR[1], SSAQUA_1F_DOOR[2],
                      METATILE_SSANNE_DOOR)

  local aPlainId = metatileAt(SSAQUA_1F_PLAIN[1], SSAQUA_1F_PLAIN[2])
  local aPlainBehavior = behaviorAt(SSAQUA_1F_PLAIN[1], SSAQUA_1F_PLAIN[2])
  F.check("ssaqua_1f_non_door_metatile_is_not_a_door",
          aPlainBehavior ~= S.MetatileBehavior.ANIMATED_DOOR,
          string.format("(%d,%d) metatile 0x%03X behavior %d", SSAQUA_1F_PLAIN[1],
                        SSAQUA_1F_PLAIN[2], aPlainId, aPlainBehavior))
  checkNoDoorRow("ssaqua_1f_non_door_metatile_has_no_row", aPlainId,
                 "a non-door metatile must not resolve on this map either")

  -- NEGATIVE CONTROL, the two-row form. 0x281 DOES resolve here after the fix, correctly, so
  -- "must not match" would be the wrong assertion; what must hold is that the id was ALREADY in
  -- the table for a tileset this map does not use. That is the whole shape of #92 in one line:
  -- on the pre-fix ROM the lookup found 0x281, rejected it on the pointer, and returned NULL.
  checkForeignRowExistsForId("ssaqua_1f_door_id_also_has_a_foreign_row", METATILE_SSANNE_DOOR,
                             "0x281 is METATILE_SSAnne_Door, whose &gTileset_SSAnne row predates "
                             .. "the fix and is neither half of this map's pair")

  -- NEGATIVE CONTROL, same map, pre-existing row: 1F's PRIMARY is gTileset_Johto_General, so the
  -- Johto town door 0x03D resolves here on both ROMs. Paired with the cabins below, where the
  -- same id must NOT resolve, this isolates the primary half of the pointer test.
  checkDoorIdResolves("ssaqua_1f_johto_general_door_id_resolves", METATILE_JOHTO_GENERAL_DOOR,
                      "0x03D is registered for &gTileset_Johto_General, which IS this map's "
                      .. "primary -- it predates the fix and holds on every build")

  -- ---- 12. the four S.S. Aqua cabins --------------------------------------------------------
  -- Four separate maps, one row. Each cabin's only warp is index 0, standing on the door itself.
  -- They swap 1F's primary for gTileset_Johto_Building while keeping the same secondary, which is
  -- what makes the 0x03D pair below a statement about the pointer rather than about the id.
  local CABINS = {
    { name = "players_room", num = MAP_SSAQUA_PLAYERS_ROOM, tag = "ssaquaplayers", d = { 0, 0, 3 } },
    { name = "room_nw",      num = MAP_SSAQUA_ROOM_NW,      tag = "ssaquanw",      d = { 0, 0, 4 } },
    { name = "room_ne",      num = MAP_SSAQUA_ROOM_NE,      tag = "ssaquane",      d = { 0, 0, 5 } },
    { name = "room_nne",     num = MAP_SSAQUA_ROOM_NNE,     tag = "ssaquanne",     d = { 0, 0, 6 } },
  }
  local cPri, cSec
  for _, cab in ipairs(CABINS) do
    F.check("warp_to_ssaqua_" .. cab.name,
            F.warpTo(0, 9, 5, cab.d[1], cab.d[2], cab.d[3], 0, 0, 0,
                     GRP_SSAQUA, cab.num, cab.tag)
              and F.ow(),
            string.format("map %d.%d at %s", F.grp(), F.mapn(), here()))
    cPri, cSec = tilesetPair()
    F.L(string.format("  SSAqua_%s layout 0x%08X: primary=0x%08X secondary=0x%08X",
                      cab.name, mapLayout(), cPri, cSec))
    F.shot("ssaqua_" .. cab.name .. "_arrival")

    checkDoorRegistered("ssaqua_" .. cab.name .. "_door",
                        SSAQUA_CABIN_DOOR[1], SSAQUA_CABIN_DOOR[2], METATILE_SSANNE_DOOR)
  end

  -- The cabins share 1F's SECONDARY (gTileset_ssaqua, the tileset the new row names) but not its
  -- primary. Without this, "one row reached all five warps" would be an assumption.
  F.check("ssaqua_cabins_share_1f_secondary_not_primary", cSec == aSec and cPri ~= aPri,
          string.format("cabin (0x%08X, 0x%08X) vs SSAqua 1F (0x%08X, 0x%08X) -- the five warps "
                        .. "are only reached by ONE row if the secondary is shared, and the "
                        .. "0x03D pair below only means anything if the primary is not",
                        cPri, cSec, aPri, aSec))

  -- NEGATIVE CONTROL, and the sharpest one here: the very id that resolved on 1F must NOT resolve
  -- in a cabin, because gTileset_Johto_Building carries no door row at all. Same secondary, same
  -- matcher, same walk -- only the primary pointer differs. Holds on both ROMs.
  checkNoDoorRow("ssaqua_cabin_foreign_tileset_door_id_has_no_row", METATILE_JOHTO_GENERAL_DOOR,
                 "0x03D is registered for Johto_General, its three recolours and General_Frlg, "
                 .. "none of which is in a cabin's pair -- it resolved on SSAqua 1F one map ago "
                 .. "purely because Johto_General is 1F's primary")

  local cPlainId = metatileAt(SSAQUA_CABIN_PLAIN[1], SSAQUA_CABIN_PLAIN[2])
  local cPlainBehavior = behaviorAt(SSAQUA_CABIN_PLAIN[1], SSAQUA_CABIN_PLAIN[2])
  F.check("ssaqua_cabin_non_door_metatile_is_not_a_door",
          cPlainBehavior ~= S.MetatileBehavior.ANIMATED_DOOR,
          string.format("(%d,%d) metatile 0x%03X behavior %d", SSAQUA_CABIN_PLAIN[1],
                        SSAQUA_CABIN_PLAIN[2], cPlainId, cPlainBehavior))
  checkNoDoorRow("ssaqua_cabin_non_door_metatile_has_no_row", cPlainId,
                 "a non-door metatile must not resolve in a cabin either")

  -- SUPPLEMENTARY. Walk out of the last cabin and watch the animation task. This is the ONE
  -- repaired door in the group whose destination is a fixed map id, so it is the one walked.
  walkIntoDoor("ssaqua_room_nne_door", SSAQUA_CABIN_DOOR[1], SSAQUA_CABIN_DOOR[2],
               GRP_SSAQUA, MAP_SSAQUA_1F)

  -- ---- 13. MAP_SSANNE_1F_ROOM1 (negative control map for S.S. Aqua) -------------------------
  -- The cross-map twin, in the Ecruteak/Bellchime shape: the SAME metatile id, 0x281, behind a
  -- different tileset pointer, on a map with no tileset in common with any S.S. Aqua map. It
  -- resolved before the fix and must still resolve after it -- adding a second row for an id that
  -- already had one must not shadow the first. It is also the map whose ART the new row borrows.
  F.check("warp_to_ssanne_1f_room1",
          F.warpTo(0, 3, 5, 0, 1, 2, 0, 0, 0, GRP_DUNGEONS_FRLG, MAP_SSANNE_1F_ROOM1, "ssanne")
            and F.ow(),
          string.format("map %d.%d at %s", F.grp(), F.mapn(), here()))
  local nPri, nSec = tilesetPair()
  F.L(string.format("  SSAnne_1F_Room1 layout 0x%08X: primary=0x%08X secondary=0x%08X",
                    mapLayout(), nPri, nSec))
  F.check("ssanne_and_ssaqua_share_no_tileset",
          nPri ~= aPri and nPri ~= aSec and nSec ~= aPri and nSec ~= aSec
            and nPri ~= cPri and nSec ~= cPri,
          string.format("SSAnne (0x%08X, 0x%08X) vs SSAqua 1F (0x%08X, 0x%08X) and the cabins' "
                        .. "primary 0x%08X -- the maps must have no tileset in common, or the "
                        .. "shared 0x281 proves nothing about the tileset pointer",
                        nPri, nSec, aPri, aSec, cPri))
  F.shot("ssanne_1f_room1_arrival")

  checkDoorRegistered("ssanne_1f_room1_door", SSANNE_ROOM1_DOOR[1], SSANNE_ROOM1_DOOR[2],
                      METATILE_SSANNE_DOOR)

  F.finish()
end

F.run(main)
