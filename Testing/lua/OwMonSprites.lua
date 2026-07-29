-- Issue #49: map-placed overworld Pokemon rendered as garbage.
--
-- 741 Johto objects were authored with `OBJ_EVENT_GFX_OW_MON` (graphics-id 240), a plain sequential
-- member of the graphics-id enum with no `OBJ_EVENT_MON` bit. `GetObjectEventGraphicsInfo` therefore
-- never reached `SpeciesToGraphicsInfo` and indexed `gObjectEventGraphicsInfoPointers[]` instead,
-- landing on `gObjectEventGraphicsInfo_Follower` - `.tileTag = TAG_NONE`, `.paletteTag =
-- OBJ_EVENT_PAL_TAG_DYNAMIC`, no `.images`. Nothing fills those slots for a map-placed object, so
-- the sprite drew whatever was resident.
--
-- Two layers, because they prove different links in the chain and neither alone is enough:
--
-- 1. **The loaded TEMPLATES** (`SaveBlock1.objectEventTemplates`, filled by
--    `CopyObjectEventTemplatesToSaveBlock` on every map load). This covers EVERY mon on the map and
--    proves the graphics id survived map.json -> mapjson -> assembler -> ROM, which a host-side
--    scan of map.json cannot. Only the first `objects` slots belong to this map: the copy writes
--    `objectEventCount` entries and leaves the rest holding the PREVIOUS map's templates, so
--    scanning all 64 would attribute stale rows to the wrong map.
-- 2. **The SPAWNED objects** (`gObjectEvents`). This is the only thing that proves the engine
--    resolved a real species sprite rather than the placeholder. Coverage is necessarily partial -
--    `OBJECT_EVENTS_COUNT` is 16 against up to 64 templates, and the whole FLAG_NIGHT_POKEMON half
--    is hidden - so the per-map assertion is "every one that spawned is legitimate" and the count
--    is accumulated into one run-wide floor rather than asserted per map, which would be flaky by
--    construction.
--
-- Neither layer is vacuous: against the pre-fix ROM every one of these reads `graphicsId == 240`
-- with bit 14 clear, so both fail on the old build. And the species is checked against the exact
-- set each `map.json` places, because `OW_SUBSTITUTE_PLACEHOLDER = TRUE` makes a *wrong* species a
-- silent Substitute doll rather than a crash - "it renders" proves nothing on its own.

local hereDir = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = hereDir .. "?.lua;" .. package.path

local S = require("symbols")
local F = require("lib").new(S, "OwMonSprites")

local OBJ_EVENT_MON = 1 << 14
-- OBJ_EVENT_MON_SPECIES_MASK is ~(7u << 12): keeps the low 12 bits and everything above bit 14, so
-- the shiny (1<<13) and female (1<<12) bits mask out along with OBJ_EVENT_MON itself.
local SPECIES_MASK = 0x8FFF
-- The broken id, so a survivor is CAUGHT as a mon that lost its bit rather than skipped as "not a
-- mon". Value from the OBJ_EVENT_GFX_* enum in include/constants/event_objects.h.
local OBJ_EVENT_GFX_OW_MON = 240

-- Compiler-probed with the build's real CFLAGS (-mabi=apcs-gnu -march=armv4t; omitting either
-- changes struct layout and yields plausible wrong numbers):
--   offsetof(SaveBlock1, objectEventTemplates) = 3988
--   sizeof(ObjectEventTemplate) = 24, and it is __attribute__((packed)), so graphicsId at +1 is an
--   UNALIGNED u16 - read it as u16 anyway, BizHawk does not care.
local TEMPLATES = 3988
local TEMPLATE = { stride = 24, localId = 0, graphicsId = 1, x = 4, y = 6, flagId = 20 }

-- Generated from data/maps/<Map>/map.json. `objects` is the map's total object-event count (the
-- template-scan bound); `mons` is how many of those are overworld Pokemon.
local MAPS = {
  { name = "Route35", grp = 83, num = 1, objects = 22, mons = 8,
    species = { [63] = "ABRA", [58] = "GROWLITHE", [16] = "PIDGEY", [54] = "PSYDUCK", [209] = "SNUBBULL", [193] = "YANMA" } },
  { name = "Route36", grp = 83, num = 2, objects = 21, mons = 15,
    species = { [69] = "BELLSPROUT", [58] = "GROWLITHE", [16] = "PIDGEY", [19] = "RATTATA", [185] = "SUDOWOODO" } },
  { name = "NationalPark_Normal", grp = 83, num = 4, objects = 49, mons = 15,
    species = { [10] = "CATERPIE", [29] = "NIDORAN_F", [32] = "NIDORAN_M", [53] = "PERSIAN", [123] = "SCYTHER", [191] = "SUNKERN", [13] = "WEEDLE" } },
  { name = "EcruteakCity", grp = 85, num = 0, objects = 49, mons = 23,
    species = { [133] = "EEVEE", [163] = "HOOTHOOT", [52] = "MEOWTH", [16] = "PIDGEY", [60] = "POLIWAG", [61] = "POLIWHIRL", [37] = "VULPIX" } },
  { name = "BellchimeTrail", grp = 85, num = 3, objects = 64, mons = 46,
    species = { [58] = "GROWLITHE", [166] = "LEDIAN", [52] = "MEOWTH", [17] = "PIDGEOTTO", [16] = "PIDGEY", [60] = "POLIWAG", [61] = "POLIWHIRL", [20] = "RATICATE", [234] = "STANTLER", [37] = "VULPIX" } },
  { name = "Route46", grp = 93, num = 2, objects = 13, mons = 8,
    species = { [74] = "GEODUDE", [231] = "PHANPY", [19] = "RATTATA", [21] = "SPEAROW" } },
  -- Not in the issue's list, and the most important one on it. Lugia is a cover legendary whose
  -- capture sets VAR_ECRUTEAK_CITY_THEATER = 8, which is what opens the Johto League - so it was
  -- one of two story-critical objects the placeholder bug was drawing as garbage. Its map.json
  -- (29,7) is a staging tile; `setobjectxyperm` moves it to (29,12).
  { name = "WhirlIslands_LugiaChamber", grp = 88, num = 16, objects = 8, mons = 3,
    species = { [116] = "HORSEA", [249] = "LUGIA", [72] = "TENTACOOL" } },
}

local spawnedTotal, spawnedNames = 0, {}

local function isMonCandidate(gfx)
  return (gfx & OBJ_EVENT_MON) ~= 0 or gfx == OBJ_EVENT_GFX_OW_MON
end

-- Layer 1: every template this map loaded.
local function scanTemplates(m)
  local base = F.sb1() + TEMPLATES
  local found, bad, names = 0, {}, {}
  for i = 0, m.objects - 1 do
    local t = base + i * TEMPLATE.stride
    local gfx = F.r16(t + TEMPLATE.graphicsId)
    if isMonCandidate(gfx) then
      found = found + 1
      local species = gfx & SPECIES_MASK
      local label = m.species[species]
      if (gfx & OBJ_EVENT_MON) == 0 then
        bad[#bad + 1] = string.format("template %d gfx %d is still OBJ_EVENT_GFX_OW_MON", i, gfx)
      elseif not label then
        bad[#bad + 1] = string.format("template %d species %d is not one this map places", i, species)
      else
        names[label] = (names[label] or 0) + 1
      end
      -- Deliberately NOT asserting elevation ~= 0 here. Elevation must match the TILE, and 148 of
      -- the 811 placements stand on genuinely elevation-0 tiles (pond POLIWAG, the National Park
      -- pair) - 10 of them on these very maps. Testing/ValidateOwMonPlacements.py owns that rule
      -- against the real tile; a bare non-zero check here would fail on correct data.
    end
  end
  local list = {}
  for k, v in pairs(names) do list[#list + 1] = k .. "x" .. v end
  table.sort(list)
  F.check(m.name .. ": all " .. m.mons .. " templates are real species",
    found == m.mons and #bad == 0,
    (#bad > 0) and table.concat(bad, "; ")
      or string.format("%d/%d found: %s", found, m.mons, table.concat(list, " ")))
end

-- Layer 2: whichever of them the engine spawned.
local function scanSpawned(m)
  local bad, names, seen = {}, {}, 0
  for i = 0, 15 do
    local b = S.gObjectEvents + i * S.ObjectEvent.stride
    if (F.r8(b) & 1) == 1 then
      local localId = F.r8(b + S.ObjectEvent.localId)
      local gfx = F.r16(b + S.ObjectEvent.graphicsId)
      -- 255 = player, 127 = the camera object
      if localId ~= 255 and localId ~= 127 and isMonCandidate(gfx) then
        seen = seen + 1
        local species = gfx & SPECIES_MASK
        local label = m.species[species]
        F.L(string.format("   spawned localId %3d gfx 0x%04X species %4d %-12s (%d,%d)%s",
          localId, gfx, species, label or "?",
          F.rs16(b + S.ObjectEvent.x) - 7, F.rs16(b + S.ObjectEvent.y) - 7,
          ((F.r8(b + S.ObjectEvent.flags1) & 0x20) ~= 0) and " invisible" or ""))
        if (gfx & OBJ_EVENT_MON) == 0 then
          bad[#bad + 1] = string.format("localId %d gfx %d has no OBJ_EVENT_MON bit", localId, gfx)
        elseif not label then
          bad[#bad + 1] = string.format("localId %d species %d is not one this map places", localId, species)
        else
          names[label] = (names[label] or 0) + 1
          spawnedNames[label] = (spawnedNames[label] or 0) + 1
          spawnedTotal = spawnedTotal + 1
        end
      end
    end
  end
  local list = {}
  for k, v in pairs(names) do list[#list + 1] = k .. "x" .. v end
  table.sort(list)
  F.check(m.name .. ": every spawned overworld Pokemon is a real species sprite", #bad == 0,
    (#bad > 0) and table.concat(bad, "; ")
      or ((seen == 0) and "none in spawn range on arrival"
          or (seen .. " spawned: " .. table.concat(list, " "))))
end

local function digits(n) return n // 100, (n // 10) % 10, n % 10 end

local function checkMap(m)
  F.L(string.format("== %s (group %d, map %d; %d objects, %d of them Pokemon)",
    m.name, m.grp, m.num, m.objects, m.mons))

  -- lib.warpTo's success test is group+map only, so calling it while already on the target returns
  -- true having warped nobody AND leaves the debug menu open, which silently eats every later
  -- input. Guard on the current map.
  if not (F.grp() == m.grp and F.mapn() == m.num) then
    local g1, g2, g3 = digits(m.grp)
    local n1, n2, n3 = digits(m.num)
    if not F.warpTo(g1, g2, g3, n1, n2, n3, 0, 0, 0, m.grp, m.num, m.name) then
      F.check(m.name .. ": warped in", false, "warpTo failed")
      return
    end
  end

  -- Reading the instant mapNum flips is too early: the warp is still in flight and ON_TRANSITION -
  -- which sets the layout and clears hide flags - has not run.
  local spun = 0
  while not F.ow() and spun < 600 do F.idle(10); spun = spun + 10 end
  F.idle(180)

  scanTemplates(m)
  scanSpawned(m)
  F.shot(m.name)
end

F.run(function()
  if not F.boot() then F.finish(); return end
  for _, m in ipairs(MAPS) do checkMap(m) end

  -- One run-wide floor instead of a per-map count, so the spawn radius cannot make the whole
  -- layer-2 pass vacuous without failing here.
  local list = {}
  for k, v in pairs(spawnedNames) do list[#list + 1] = k .. "x" .. v end
  table.sort(list)
  F.check("the engine really spawned overworld Pokemon somewhere", spawnedTotal >= 2,
    string.format("%d across %d maps: %s", spawnedTotal, #MAPS, table.concat(list, " ")))
  F.finish()
end)
