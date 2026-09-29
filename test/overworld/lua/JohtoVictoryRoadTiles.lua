-- 050d785f: JohtoVictoryRoad_1F / _B1F / _B2F were tagged `layout_version: "johto"` in
-- data/layouts/layouts.json while their PRIMARY tileset is gTileset_General, which holds 512
-- metatiles. `GetNumMetatilesInPrimary` (src/fieldmap.c:434) returns 640 for a layout whose
-- isFrlg OR isJohto byte is set, so the id space was split at 640 on a 512-metatile primary and
-- every id in 512..639 was treated as PRIMARY and indexed 128 entries past the end of
-- gMetatiles_General. Neither `GetAttributeByMetatileIdAndMapLayout` nor `DrawMetatileAt`
-- (src/field_camera.c:226) bounds-checks, so the overrun corrupted what was DRAWN as well as the
-- behaviour byte.
--
-- What it cost, from the link map of the pre-fix build: gMetatiles_General ends exactly where
-- gMetatileAttributes_SecretBaseSecondary begins, and gMetatiles_SecretBaseSecondary follows that
-- -- so ids 512..639 drew SECRET BASE metatiles. Counted off map.bin, 1989 of 1F's 2070 tiles sit
-- in that band; _1F and _B1F use no id below 512 AT ALL. About 96% of the first floor was
-- rendering someone's secret base.
--
-- The fix retagged all three to "emerald", moving the split back to 512: ids 512..639 become
-- gTileset_Cave local 0..127 and the floors' top id (886 on _B2F) becomes Cave local 374, inside
-- Cave's 414 metatiles.
--
-- ---------------------------------------------------------------------------------------------
-- Why this suite is not arithmetic. The host-side validators can only re-derive the same
-- spreadsheet the fix was reasoned from. The three claims that actually need a running ROM are:
--
--   1. the retag reached the BINARY -- struct MapLayout's isJohto byte is 0 for these layouts;
--   2. the split the game will use fits the primary tileset it is splitting -- 512 <= 512, where
--      BOTH numbers are read out of the live ROM rather than assumed;
--   3. the floor DRAWS as a cave -- the BG tilemaps mGBA is scanning out hold the tile entries
--      that gTileset_Cave's metatiles specify, and not the ones the 640 split would have fetched.
--
-- (3) is the one that would have caught the bug by looking at it, so it is done properly: the
-- suite reconstructs BOTH candidate resolutions from live ROM pointers for the 16x16 metatile
-- window the camera is showing, then reads the three overworld BG tilemaps straight out of VRAM
-- and asks which model explains them. On the pre-fix ROM the answer flips, and both halves of the
-- pair fail -- that is what makes the check non-vacuous rather than "the screen has tiles on it".
--
-- ---------------------------------------------------------------------------------------------
-- The Hoenn twin is the control. VictoryRoad_1F/_B1F pair the identical gTileset_General +
-- gTileset_Cave at identical dimensions (46x45, 46x31) and were always tagged "emerald"; the
-- Johto floors are copies of them down to the warp coordinates (both maps' warp 4 is at (9,14)).
-- So the suite reads the Hoenn floor FIRST and then requires the Johto floors to report the same
-- tileset pointers and the same split. Without that, "isJohto is 0" is just a byte with no
-- meaning attached; with it, the assertion is "these floors are now byte-for-byte configured the
-- way the working map they were copied from is".
--
-- ---------------------------------------------------------------------------------------------
-- No trainer suppression here, deliberately. NationalParkTiles has to mark its trainers beaten
-- because it WALKS a 22-tile band through two sight cones; this suite takes exactly one step per
-- floor, onto a tile chosen to sit outside every sight line on that map:
--
--   1F   stand (9,15).  Nearest is Hope (6,15) MOVEMENT_TYPE_FACE_LEFT sight 4 -- she watches
--                       x=5..2 on y=15, i.e. away from the player, who is four tiles EAST.
--   B1F  stand (17,17). Mitchell (14,16) FACE_DOWN sight 4 watches (14,17..20); Halle (14,20)
--                       FACE_UP_AND_RIGHT watches (14,19..17) and (15..17,20). Neither cone
--                       contains (17,17).
--   B2F  stand (19,13). Vito (15,6) FACE_DOWN sight 2 watches (15,7..8); the next nearest is
--                       Dianne at (25,18). Nothing is within reach.
--
-- That matters beyond tidiness: hard-coded trainer defeat flags are a known fragility in this
-- battery (repointing a trainer silently stops the suppression and reads as a real regression),
-- and geometry cannot go stale the same way. If a future edit MOVES one of these trainers this
-- suite will fail loudly on `stepped_off_warp_tile`, which is the correct outcome.

local hereDir = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = hereDir .. "?.lua;" .. package.path

local S = require("symbols")
local F = require("lib").new(S, "JohtoVictoryRoadTiles")

-- include/constants/map_groups.h
local JOHTO_GRP, JOHTO_1F, JOHTO_B1F, JOHTO_B2F = 99, 0, 1, 2
local HOENN_GRP, HOENN_1F = 24, 43

-- include/fieldmap.h
local SPLIT_EMERALD, SPLIT_FRLG, METATILES_TOTAL = 512, 640, 1024
local TILES_PER_METATILE = 8              -- NUM_TILES_PER_METATILE; 8 u16 entries = 16 bytes

-- gTileset_Cave's metatile count. Not readable at runtime -- struct Tileset carries no length --
-- so it is taken from the blob: `wc -c data/tilesets/secondary/cave/metatiles.bin` / 16 = 414.
-- The same file's metatile_attributes.bin is 828 = 414 * 2, i.e. u16 attributes, which is the
-- independent cross-check that 414 is the count and not a coincidence of file size.
local CAVE_METATILES = 414

-- The two BG layers DrawMetatile writes real tile entries into are BG1 (top) and BG2 (middle);
-- BG3 gets either the metatile's bottom layer or the constant 0x3014 filler, depending on the
-- metatile's layer type. 0 is the transparent entry written to whichever layer is unused.
local BG3_FILLER = 0x3014

-- Fallbacks for the field BG screen bases, from sOverworldBgTemplates (src/overworld.c:316-352).
-- The suite prefers to read REG_BG1CNT/2CNT/3CNT so it is describing the hardware state rather
-- than a source constant, and only falls back if those reads come back implausible.
local REG_BG1CNT, REG_BG2CNT, REG_BG3CNT = 0x0400000A, 0x0400000C, 0x0400000E
local FALLBACK_BASES = { 29, 28, 30 }

-- Sampled tiles, per floor: { mapX, mapY, expectedMetatileId }. Read out of
-- data/layouts/<map>/map.bin at author time and re-read here from the LIVE gBackupMapLayout, so
-- a mismatch means the map data in the ROM is not the map data on disk -- which would make every
-- id-range claim below meaningless. One from the 512..639 band that the bug corrupted, one from
-- the >= 640 band that it merely mis-rebased, and each floor's HIGHEST id, which is the worst
-- case for "does this still land inside Cave's 414 metatiles".
local SAMPLES = {
  [JOHTO_1F]  = { { 9, 15, 529 }, { 18, 17, 699 }, { 17, 28, 848 } },
  [JOHTO_B1F] = { { 17, 17, 513 }, { 11, 4, 848 }, { 11, 6, 850 } },
  [JOHTO_B2F] = { { 19, 13, 513 }, { 10, 5, 852 }, { 27, 12, 886 } },
}

-- Warp in, then step ONE tile off the warp tile before doing anything else. Standing on a stairs
-- metatile while ensureFree() shuffles left and right is a way to re-enter the warp and end the
-- run on a different floor than the one being asserted about.
local FLOORS = {
  { num = JOHTO_1F,  name = "1F",  warp = 4, on = { 9, 14 },  step = "Down", stand = { 9, 15 } },
  { num = JOHTO_B1F, name = "B1F", warp = 1, on = { 17, 16 }, step = "Down", stand = { 17, 17 } },
  { num = JOHTO_B2F, name = "B2F", warp = 2, on = { 19, 12 }, step = "Down", stand = { 19, 13 } },
}

local function here() local x, y = F.pos(); return string.format("(%d,%d)", x, y) end
local function at(t) local x, y = F.pos(); return x == t[1] and y == t[2] end

-- ---- the live layout, read as the game reads it ----------------------------------------------
-- gMapHeader.mapLayout is the same pointer GetNumMetatilesInPrimary is handed, so everything
-- below is the exact input to the branch under test rather than a re-derivation of it.
local function layout()
  local p = F.r32(S.gMapHeader + S.MapHeader.mapLayout)
  local L = {
    ptr = p,
    width = F.r32(p + S.MapLayout.width),
    height = F.r32(p + S.MapLayout.height),
    prim = F.r32(p + S.MapLayout.primaryTileset),
    sec = F.r32(p + S.MapLayout.secondaryTileset),
    isFrlg = F.r8(p + S.MapLayout.isFrlg),
    isJohto = F.r8(p + S.MapLayout.isJohto),
  }
  -- GetNumMetatilesInPrimary, verbatim.
  L.split = (L.isFrlg ~= 0 or L.isJohto ~= 0) and SPLIT_FRLG or SPLIT_EMERALD
  L.primMetatiles = F.r32(L.prim + S.Tileset.metatiles)
  L.secMetatiles = F.r32(L.sec + S.Tileset.metatiles)
  -- How many metatiles the primary ACTUALLY has. struct Tileset stores no length, but since #53
  -- it carries hasFrlgAttributes, which mapjson derives from TILESET_METATILES -- a tileset built
  -- with 640 metatiles has u32 attributes and this bit set, one built with 512 does not. So the
  -- bit is a faithful proxy for the capacity, read out of the ROM rather than assumed.
  local frlgAttrs = (F.r8(L.prim + S.Tileset.flags1) & S.Tileset.hasFrlgAttributesBit) ~= 0
  L.primCapacity = frlgAttrs and SPLIT_FRLG or SPLIT_EMERALD
  return L
end

local function describe(L)
  return string.format("layout=0x%08X %dx%d isFrlg=%d isJohto=%d split=%d "
                       .. "primary=0x%08X(cap %d) secondary=0x%08X",
                       L.ptr, L.width, L.height, L.isFrlg, L.isJohto, L.split,
                       L.prim, L.primCapacity, L.sec)
end

-- ---- the live map grid -----------------------------------------------------------------------
-- gBackupMapLayout.map is indexed in GRID coordinates, which are map coordinates + MAP_OFFSET(7)
-- -- the same array MapGridGetMetatileIdAt reads. Bits 0-9 are the metatile id.
local function gridId(gx, gy)
  local w = F.r32(S.gBackupMapLayout + S.BackupMapLayout.width)
  local m = F.r32(S.gBackupMapLayout + S.BackupMapLayout.map)
  return F.r16(m + (gx + w * gy) * 2) & S.Metatiles.idMask
end
local function mapId(x, y) return gridId(x + 7, y + 7) end

-- ---- the two competing resolutions -----------------------------------------------------------
-- DrawMetatileAt picks `primary` or `secondary` off GetNumMetatilesInPrimary and then indexes
-- `metatiles + id * 8` u16s. Given a split, this returns the address of that metatile's 8 tile
-- entries -- so calling it with 512 and again with 640 produces the two pictures the ROM could
-- have drawn, both built from pointers read out of the running game.
local function metatileAddr(L, id, split)
  if id < split then return L.primMetatiles + id * TILES_PER_METATILE * 2 end
  return L.secMetatiles + (id - split) * TILES_PER_METATILE * 2
end

-- Collect every tile entry the 16x16 metatile window around the player would produce under a
-- given split. DrawWholeMapViewInternal (src/field_camera.c:100) draws grid columns
-- pos.x .. pos.x+15 and rows pos.y .. pos.y+15 -- note it passes gSaveBlock1Ptr->pos.x straight
-- to MapGridGetMetatileIdAt as a GRID index, which is why the player (grid pos.x+7) sits in the
-- middle of the window and not at its corner.
--
-- >>> This model is only exact on a FRESHLY drawn map view, which is why the render check below
-- runs on arrival and before the step off the warp tile. Once the camera moves, the 16th row (or
-- column) of the tilemap goes stale: a step south increments pos.y and RedrawMapSliceNorth
-- (:138, and yes the names are inverted relative to the caller) redraws only pos.y + 14, so the
-- slot that ought to hold pos.y + 15 keeps the row from BEFORE the step. That row is off-screen
-- -- the GBA shows 15x10 metatiles out of the 16x16 the tilemap holds -- so the game is right not
-- to bother, but a model that assumes all 256 are current is not. The first run of this suite
-- did assume it, and B1F duly reported 2 of 76 entries "unexplained", both of them leftovers from
-- one row outside the window.
local function windowTileSet(L, split)
  local px, py = F.pos()
  local set, n = {}, 0
  for j = 0, 15 do
    for i = 0, 15 do
      local id = gridId(px + i, py + j)
      if id > METATILES_TOTAL then id = 0 end          -- DrawMetatileAt's own clamp
      local a = metatileAddr(L, id, split)
      for k = 0, TILES_PER_METATILE - 1 do
        local v = F.r16(a + k * 2)
        if not set[v] then set[v] = true; n = n + 1 end
      end
    end
  end
  return set, n
end

-- ---- what is actually on screen --------------------------------------------------------------
local function bgScreenBases()
  local b = {}
  for i, reg in ipairs({ REG_BG1CNT, REG_BG2CNT, REG_BG3CNT }) do
    b[i] = (F.r16(reg) >> 8) & 0x1F
  end
  -- Three distinct, non-zero screen blocks is what the overworld config gives. If the I/O read
  -- comes back as anything else the suite is reading the wrong thing entirely, so say so and use
  -- the source constants rather than silently scanning zeros and calling it a pass.
  if b[1] == b[2] or b[2] == b[3] or b[1] == b[3] or b[1] == 0 or b[2] == 0 or b[3] == 0 then
    F.L(string.format("  REG_BG1/2/3CNT gave screen bases %d/%d/%d -- implausible, falling back "
                      .. "to sOverworldBgTemplates' 29/28/30", b[1], b[2], b[3]))
    return FALLBACK_BASES, false
  end
  return b, true
end

-- Read the three overworld tilemaps out of VRAM. Each is one 2KB screen block = 32x32 u16 tile
-- entries, and DrawMetatile copies the metatile's u16s in verbatim (flip and palette bits and
-- all), so equality against the ROM value is exact rather than approximate.
--
-- Entries excluded: 0, the transparent filler written to whichever layer a metatile does not use,
-- and 0x3014, the constant DrawMetatile writes into BG3 for METATILE_LAYER_TYPE_NORMAL. Both are
-- generated by the drawing code, not read out of any tileset, so neither is evidence either way.
local function drawnTileEntries()
  local bases = bgScreenBases()
  local out, n = {}, 0
  for _, base in ipairs(bases) do
    local addr = 0x06000000 + base * 0x800
    for i = 0, 1023 do
      local v = F.r16(addr + i * 2)
      if v ~= 0 and v ~= BG3_FILLER and not out[v] then out[v] = true; n = n + 1 end
    end
  end
  return out, n
end

-- ---- per-floor -------------------------------------------------------------------------------
local ref = nil     -- the Hoenn twin's (primary, secondary, split), captured first

local function checkFloor(fl)
  local tag = fl.name
  F.L(string.format("---- JohtoVictoryRoad_%s ----", tag))

  F.check(tag .. "_warp", F.warpTo(0, 9, 9, 0, 0, fl.num, 0, 0, fl.warp,
                                   JOHTO_GRP, fl.num, "jvr_" .. tag) and at(fl.on),
          string.format("expected %s, got %s", string.format("(%d,%d)", fl.on[1], fl.on[2]), here()))
  F.idle(90)
  F.check(tag .. "_no_crash_screen", not F.crashScreen(),
          "a metatile overrun that walks off the end of an array is exactly the shape of fault "
          .. "that lands on an assertf, so read the screen rather than inferring from silence")

  local L = layout()
  F.L("  " .. describe(L))

  -- (1) the retag reached the binary. This is the whole change, in one byte.
  F.check(tag .. "_layout_is_not_johto_tagged", L.isJohto == 0 and L.isFrlg == 0,
          string.format("isJohto=%d isFrlg=%d -- either one set makes GetNumMetatilesInPrimary "
                        .. "return 640 for a layout whose primary holds 512", L.isJohto, L.isFrlg))

  -- (2) the split fits the thing being split. Both numbers come out of the ROM: the split from
  -- the layout's own flag bytes, the capacity from the primary tileset's hasFrlgAttributes bit.
  F.check(tag .. "_split_fits_primary_tileset", L.split <= L.primCapacity,
          string.format("split=%d primary capacity=%d; a split above the capacity means ids "
                        .. "%d..%d index past the end of the primary's metatile array",
                        L.split, L.primCapacity, L.primCapacity, L.split - 1))

  -- (3) same configuration as the Hoenn floor these maps were copied from.
  F.check(tag .. "_matches_hoenn_twin",
          ref ~= nil and L.prim == ref.prim and L.sec == ref.sec and L.split == ref.split,
          ref == nil and "the Hoenn control never loaded"
                     or string.format("this floor primary=0x%08X secondary=0x%08X split=%d; "
                                      .. "VictoryRoad_1F primary=0x%08X secondary=0x%08X split=%d",
                                      L.prim, L.sec, L.split, ref.prim, ref.sec, ref.split))

  -- (4) sampled real ids resolve into gTileset_Cave and stay inside it.
  local okIds, why = true, {}
  for _, s in ipairs(SAMPLES[fl.num]) do
    local x, y, want = s[1], s[2], s[3]
    local got = mapId(x, y)
    local local_ = got - L.split
    local ok = (got == want) and (got >= L.split) and (local_ < CAVE_METATILES)
    if not ok then okIds = false end
    why[#why + 1] = string.format("(%d,%d) id=%d%s -> Cave[%d]%s", x, y, got,
                                  got == want and "" or string.format(" WANTED %d", want),
                                  local_, local_ < CAVE_METATILES and "" or " OUT OF RANGE")
    if want < SPLIT_FRLG and want >= SPLIT_EMERALD then
      why[#why] = why[#why] .. string.format(" [under the 640 split this id was "
                                             .. "gMetatiles_General[%d], %d past its %d-metatile "
                                             .. "end]", want, want - SPLIT_EMERALD, SPLIT_EMERALD)
    end
  end
  F.check(tag .. "_sampled_ids_resolve_into_cave", okIds, table.concat(why, "; "))

  -- (5) the render check, on the map view the warp drew. Build both candidate pictures from live
  -- ROM pointers, then ask the screen which one it is.
  local cave, nCave = windowTileSet(L, SPLIT_EMERALD)
  local johto, nJohto = windowTileSet(L, SPLIT_FRLG)
  local drawn, nDrawn = drawnTileEntries()

  local unexplained, unexplainedEg = 0, nil
  local onlyCave = 0                       -- drawn entries the 640 model cannot account for
  for v in pairs(drawn) do
    if not cave[v] then
      unexplained = unexplained + 1
      if not unexplainedEg then unexplainedEg = v end
    end
    if not johto[v] then onlyCave = onlyCave + 1 end
  end
  F.L(string.format("  window models: emerald-split %d distinct entries, johto-split %d; "
                    .. "screen shows %d", nCave, nJohto, nDrawn))

  F.check(tag .. "_drawn_tiles_are_the_cave_resolution", nDrawn > 0 and unexplained == 0,
          string.format("%d of %d distinct tile entries on screen are NOT produced by resolving "
                        .. "this window's metatiles at the 512 split%s", unexplained, nDrawn,
                        unexplainedEg and string.format(" (e.g. 0x%04X)", unexplainedEg) or ""))

  -- The negative half. If the two models happened to agree on this window the check above would
  -- be satisfied by a ROM drawing secret bases, so require that the screen contains something the
  -- 640 split could not have put there. On the pre-fix ROM this is 0 -- everything drawn IS the
  -- johto resolution -- so the pair fails from both ends at once.
  F.check(tag .. "_johto_split_would_have_drawn_something_else", onlyCave > 0,
          string.format("%d of %d entries on screen are unique to the 512 split; 0 would mean "
                        .. "the two resolutions are indistinguishable here and the check above "
                        .. "proves nothing", onlyCave, nDrawn))

  F.shot("johto_victory_road_" .. tag)

  -- (6) field control, on a walkable tile, off the stairs. Last, because stepping is what makes
  -- the tilemap model above go stale -- and because the step has to leave the warp tile rather
  -- than shuffle on and off it, which is a way to re-enter the stairs and finish the run on a
  -- different floor than the one just asserted about.
  local stepped = F.step(fl.step)
  F.check(tag .. "_stepped_off_warp_tile", stepped and at(fl.stand) and F.ow(),
          string.format("step %s from the warp tile: at %s ow=%s (wanted (%d,%d)); a trainer "
                        .. "intercept or a softlock both land here", fl.step, here(),
                        tostring(F.ow()), fl.stand[1], fl.stand[2]))
end

local function main()
  if not F.boot() then return F.finish() end

  -- ---- the control: Hoenn VictoryRoad_1F -----------------------------------------------------
  -- Same tileset pair, same 46x45, same warp table, always tagged "emerald". Read it first so the
  -- Johto assertions have something to be equal TO. No stepping and no render check here: this
  -- map is not the subject, it is the reference value.
  F.check("hoenn_control_warp",
          F.warpTo(0, 2, 4, 0, 4, 3, 0, 0, 4, HOENN_GRP, HOENN_1F, "hoenn_vr_1f") and at({ 9, 14 }),
          "expected (9,14) on VictoryRoad_1F, got " .. here())
  F.idle(90)
  local h = layout()
  F.L("  hoenn VictoryRoad_1F: " .. describe(h))
  F.check("hoenn_control_is_emerald_split",
          h.isJohto == 0 and h.isFrlg == 0 and h.split == SPLIT_EMERALD
            and h.split <= h.primCapacity,
          describe(h))
  F.check("hoenn_control_primary_is_gTileset_General", h.prim == S.gTileset_General,
          string.format("primary=0x%08X, gTileset_General=0x%08X -- if this ever stops matching, "
                        .. "the twin is no longer the same pairing and the comparisons below are "
                        .. "not a control", h.prim, S.gTileset_General))
  F.shot("hoenn_victory_road_1f")
  if h.prim == S.gTileset_General and h.split == SPLIT_EMERALD then ref = h end

  for _, fl in ipairs(FLOORS) do checkFloor(fl) end

  F.finish()
end

F.run(main)
