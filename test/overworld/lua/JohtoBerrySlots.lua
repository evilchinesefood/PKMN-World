-- Issue #163: nine Johto berry trees shared save slots with nine OTHER Johto berry trees.
--
-- `include/constants/johto_compat.h` defined BERRY_TREE_<berry>_<n> straight onto
-- BERRY_TREE_JOHTO_<berry>_<n>. Two map objects on different routes therefore named what looked
-- like two constants but resolved to ONE index into `SaveBlock1.berryTrees[]` -- so planting or
-- harvesting Azalea's Leppa emptied Route 43's, Route 31's Rawst emptied Route 38's, and so on
-- for all nine pairs. The fix gives each alias-side tree its own slot (113-121) and deletes the
-- alias block outright.
--
-- WHY THIS SUITE EXISTS AND WHAT IT ACTUALLY PROVES
--
-- `include/constants/berry.h:155-157` already warned that a shared id is a shared save slot and
-- that the symptom is invisible until someone harvests. It was invisible: #104 shipped the Johto
-- slot block, closed COMPLETED, and left the alias layer live underneath it. Nothing in the build,
-- the validators or `make check` can see it, because the aliases are valid C and the map JSON is
-- well-formed -- the defect only exists in what two names RESOLVE to.
--
-- So the check is on the seeded save state, not on the constants: after a new game,
-- `data/scripts/new_game.inc` runs one `setberrytree` per tree. If two trees share a slot, the
-- second write lands on the first's index and the array ends up with FEWER distinct seeded slots
-- than there are seeded trees. That is observable from memory and does not require walking to
-- eight routes and harvesting, which would be slow and would couple the suite to arrival tiles.
--
-- Two layers, because either alone can pass vacuously:
--
--   1. Slots 113-121 hold the RIGHT berry at BERRY_STAGE_BERRIES. On the pre-fix ROM these nine
--      indices were never written by anything, so they read as an all-zero BerryTree -- berryId 0,
--      stage 0. This is the direct discriminator and it fails 9/9 on the old build.
--   2. The total number of seeded slots equals the number of `setberrytree` lines. This is what
--      catches the *general* bug rather than these nine instances: any future pair that collides
--      makes the seeded count drop below the line count, whatever slots they use.
--
-- Layer 2 is the one that keeps working after this fix. Layer 1 would still pass if someone
-- reintroduced a collision among a DIFFERENT pair of trees.

local hereDir = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = hereDir .. "?.lua;" .. package.path

local S = require("symbols")
local F = require("lib").new(S, "JohtoBerrySlots")

-- sizeof(struct BerryTree) == 8, pinned by STATIC_ASSERT in src/load_save.c alongside
-- offsetof(SaveBlock1, berryTrees) == 6812 (which global.h:1265 independently comments as 0x1A9C).
--
-- The two fields we want are BITFIELDS, not whole bytes (include/global.berry.h:85-97):
--   byte 0:  berry:7 | weeds:1
--   byte 1:  stage:3 | mulch:4 | stopGrowth:1
-- Reading byte 1 raw returns 133 (0x85) on a seeded tree -- stage 5 with stopGrowth set -- so an
-- unmasked compare against BERRY_STAGE_BERRIES fails on a perfectly correct save. Mask both.
local TREE_STRIDE = 8
local BERRY_ID, STAGE = 0, 1
local BERRY_MASK, STAGE_MASK = 0x7F, 0x07

local BERRY_STAGE_NO_BERRY = 0
local BERRY_STAGE_BERRIES  = 5

-- enum BerryId (include/constants/items.h) is BERRY_ID_NONE = 0 followed by FOREACH_BERRY's
-- order (include/constants/berries.h:4-14): CHERI CHESTO PECHA RAWST ASPEAR LEPPA ORAN PERSIM
-- LUM SITRUS. Counted from that list rather than assumed -- the Gen-3 item order puts SITRUS at
-- 10, not where an alphabetical or National-Dex guess would land it.
local BERRY_ID_CHERI,  BERRY_ID_CHESTO = 1, 2
local BERRY_ID_RAWST,  BERRY_ID_ASPEAR = 4, 5
local BERRY_ID_LEPPA,  BERRY_ID_LUM    = 6, 9
local BERRY_ID_SITRUS                  = 10

-- The nine trees that used to reach a shared slot through a johto_compat.h alias, with the slot
-- each now owns. Coordinates are from the map.json objects, so a wrong repoint is legible in the
-- failure text rather than just "slot 113 empty".
local NEW = {
  { slot = 113, berry = BERRY_ID_RAWST,  name = "JOHTO_RAWST_3",  was = 92,  where = "Route 38 (21,24)" },
  { slot = 114, berry = BERRY_ID_RAWST,  name = "JOHTO_RAWST_4",  was = 93,  where = "Route 39 (12,27)" },
  { slot = 115, berry = BERRY_ID_SITRUS, name = "JOHTO_SITRUS_2", was = 94,  where = "Route 47 (51,8)"  },
  { slot = 116, berry = BERRY_ID_ASPEAR, name = "JOHTO_ASPEAR_3", was = 95,  where = "Route 44 (7,10)"  },
  { slot = 117, berry = BERRY_ID_ASPEAR, name = "JOHTO_ASPEAR_4", was = 96,  where = "Route 45 (24,87)" },
  { slot = 118, berry = BERRY_ID_CHESTO, name = "JOHTO_CHESTO_3", was = 97,  where = "Route 42 (40,19)" },
  { slot = 119, berry = BERRY_ID_LEPPA,  name = "JOHTO_LEPPA_3",  was = 98,  where = "Route 43 (3,27)"  },
  { slot = 120, berry = BERRY_ID_LEPPA,  name = "JOHTO_LEPPA_4",  was = 99,  where = "Route 43 (4,25)"  },
  { slot = 121, berry = BERRY_ID_LUM,    name = "JOHTO_LUM_2",    was = 100, where = "Route 46 (9,11)"  },
}

-- The eleven slots the JOHTO_* names already owned. Asserted unchanged so a "fix" that merely
-- MOVED the collision -- repointing the original tree instead of the alias-side one -- is caught.
local KEPT = {
  { slot = 90,  berry = BERRY_ID_CHERI  }, { slot = 91,  berry = BERRY_ID_CHERI  },
  { slot = 92,  berry = BERRY_ID_RAWST  }, { slot = 93,  berry = BERRY_ID_RAWST  },
  { slot = 94,  berry = BERRY_ID_SITRUS }, { slot = 95,  berry = BERRY_ID_ASPEAR },
  { slot = 96,  berry = BERRY_ID_ASPEAR }, { slot = 97,  berry = BERRY_ID_CHESTO },
  { slot = 98,  berry = BERRY_ID_LEPPA  }, { slot = 99,  berry = BERRY_ID_LEPPA  },
  { slot = 100, berry = BERRY_ID_LUM    },
}

-- BERRY_TREES_COUNT (include/constants/berry.h). Sizes berryTrees[]; 122-127 are the remaining
-- budget and must stay untouched by the seeding.
local BERRY_TREES_COUNT = 128
local RESERVE_FIRST = 122

-- Number of `setberrytree` lines in data/scripts/new_game.inc (103 before this fix, +9 for the
-- reclaimed slots). Layer 2 compares the seeded-slot count against this; keep it in step when a
-- tree is added, or the suite reports a collision that is really just a stale constant.
local SEEDED_LINES = 112

local function treeAt(i)
  local base = F.sb1() + S.SaveBlock1.berryTrees + i * TREE_STRIDE
  return F.r8(base + BERRY_ID) & BERRY_MASK, F.r8(base + STAGE) & STAGE_MASK
end

F.run(function()
  if not F.boot(100) then F.check("boot to overworld", false); F.finish(); return end
  F.shot("booted")

  -- Layer 1 -- the nine reclaimed slots.
  for _, t in ipairs(NEW) do
    local id, stage = treeAt(t.slot)
    F.check(string.format("slot %d (%s, %s) is seeded", t.slot, t.name, t.where),
      id == t.berry and stage == BERRY_STAGE_BERRIES,
      string.format("berryId=%d stage=%d (wanted berryId=%d stage=%d); reads all-zero on a build "
                    .. "where this tree still aliases slot %d", id, stage, t.berry,
                    BERRY_STAGE_BERRIES, t.was))
  end

  -- The original eleven must be untouched.
  for _, t in ipairs(KEPT) do
    local id, stage = treeAt(t.slot)
    F.check(string.format("slot %d still holds its original Johto tree", t.slot),
      id == t.berry and stage == BERRY_STAGE_BERRIES,
      string.format("berryId=%d stage=%d (wanted berryId=%d)", id, stage, t.berry))
  end

  -- Layer 2 -- the general collision check. Counts every seeded slot in the whole array, so a
  -- collision anywhere (not just among these nine) shows up as a shortfall.
  local seeded, reserveUsed = 0, {}
  for i = 0, BERRY_TREES_COUNT - 1 do
    local id, stage = treeAt(i)
    if id ~= 0 or stage ~= BERRY_STAGE_NO_BERRY then
      seeded = seeded + 1
      if i >= RESERVE_FIRST then reserveUsed[#reserveUsed + 1] = i end
    end
  end
  -- A shortfall means one of two things, and both are the same defect wearing different clothes:
  -- either two trees resolved to the same index (the later setberrytree overwrote the earlier),
  -- or a tree has no slot of its own at all and is riding another's. On the pre-fix ROM this
  -- reads 103 seeded against 112 expected -- exactly the nine aliased trees.
  F.check("every seeded tree owns its own slot (no two resolve to the same index)",
    seeded == SEEDED_LINES,
    string.format("%d slots seeded, %d expected -- short by %d, i.e. that many trees are sharing "
                  .. "an index with another tree instead of owning one", seeded, SEEDED_LINES,
                  SEEDED_LINES - seeded))

  F.check("slots 122-127 are still unspent reserve", #reserveUsed == 0,
    #reserveUsed == 0 and "6 slots remain" or ("seeded: " .. table.concat(reserveUsed, ",")))

  F.finish()
end)
