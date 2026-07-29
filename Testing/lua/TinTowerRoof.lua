-- TinTowerRoof.lua — issue #50: MAP_TIN_TOWER_ROOF_NIGHT deleted.
--
-- What this proves, in one run, at BOTH day/night flag states:
--   1. Entering the roof from TinTower_8F lands on MAP_TIN_TOWER_ROOF_DAY — the map that owns the
--      Ho-Oh scripts — and never on a scriptless twin. This is the issue's acceptance clause 1.
--   2. The layout still swaps (LAYOUT_TIN_TOWER_ROOF_DAY <-> LAYOUT_TIN_TOWER_ROOF_NIGHT), so
--      deleting the map did not break `setmaplayoutindex`. That layout is now map-less, which is
--      the whole point of keeping its layouts.json entry.
--   3. The roof's ON_TRANSITION still runs there: with VAR_COMPLETED_HO_OH == 2 it clears
--      FLAG_HIDE_HO_OH and Ho-Oh spawns. On the deleted map this could never have happened
--      (its scripts.inc was `.byte 0`).
--   4. The D3 weather fix: WEATHER_SUNNY by day, WEATHER_NONE by night. `setmaplayoutindex` swaps
--      the layout only, so the map header's weather would otherwise stay sunny at night — that is
--      the one behaviour the deleted map's header encoded.
--
-- The night pass deliberately reproduces the exact flag state the issue said would softlock:
-- FLAG_DAY_POKEMON set AND FLAG_NIGHT_POKEMON clear.

package.path = (debug.getinfo(1, "S").source:sub(2):match("^(.*[/\\])") or "") .. "?.lua;" .. package.path
local S = require("symbols")
local T = require("lib")
local F = T.new(S, "TinTowerRoof")

-- ---- constants (compiler-probed against this build, not hand-summed) -------------------------
local GRP_ECRUTEAK_INDOOR = 86
local MAP_TIN_TOWER_8F    = 19
local MAP_ROOF_DAY        = 21

local LAYOUT_ROOF_DAY   = 892
local LAYOUT_ROOF_NIGHT = 905
local WEATHER_NONE, WEATHER_SUNNY = 0, 2

-- SaveBlock1 field offsets (offsetof probe with the build's real CFLAGS)
local SB1_WEATHER, SB1_MAPLAYOUT = 46, 50

-- Johto flags live in SaveBlock3.region.johtoFlags[(id - 0x6000) / 8] (event_data.c:275).
local FLAG_JOHTO_BASE = 0x6000
local FLAG_DAY_POKEMON, FLAG_NIGHT_POKEMON = 0x6040, 0x6041
local FLAG_HIDE_KIMONO = 0x6100
-- Johto vars live in SaveBlock3.region.regionVars[id - REGION_VARS_START] (event_data.c:203).
local REGION_VARS_START = 0xA000
local VAR_COMPLETED_HO_OH = 0xA0A1
-- FLAG_HIDE_HO_OH is an ordinary Hoenn-bank flag in SaveBlock1.flags.
local FLAG_HIDE_HO_OH = 0x321

-- From TinTower_RoofDay/scripts.inc's `.set LOCALID_*`. These SHIFTED DOWN BY ONE in #49, which
-- deleted that map's dead second FLAG_HIDE_HO_OH object (the scriptless one parked off the layout at
-- (-6,18)) — localId is the object's index in map.json, so removing the first element renumbers
-- everything after it. This suite caught the shift as "Ho-Oh never reached (10,6)" while its own
-- object dump plainly showed `id7(10,6)`, which is the signature of a stale hardcoded localId rather
-- than a broken cutscene. Keep these in step with the `.set` lines.
local LOCALID_HO_OH, LOCALID_KIMONO_MID = 7, 3

-- The Ho-Oh BATTLE itself is deliberately not driven: this suite boots a fresh new game, which has
-- an empty party, and BattleSetup_StartLegendaryBattle has no 0-party guard (the centralised one
-- lives in BattleSetup_StartWildBattle). Everything this issue could have broken — which map the
-- warp lands on, whether ON_TRANSITION runs, whether the layout swaps, whether the descent script
-- executes — is upstream of the battle and is asserted here. The battle script itself is unchanged
-- by this work and sits on the same map it always did.

-- ---- flag/var accessors ----------------------------------------------------------------------
local function johtoFlagAddr(id) return F.sb3() + S.SaveBlock3.johtoFlags + ((id - FLAG_JOHTO_BASE) // 8) end
local function johtoFlagBit(id) return 1 << (id % 8) end
local function johtoFlagGet(id) return (F.r8(johtoFlagAddr(id)) & johtoFlagBit(id)) ~= 0 end
local function johtoFlagSet(id, on)
  local a, m = johtoFlagAddr(id), johtoFlagBit(id)
  local v = F.r8(a)
  F.w8(a, on and (v | m) or (v & ~m & 0xFF))
end

local function regionVarAddr(id) return F.sb3() + S.SaveBlock3.regionVars + (id - REGION_VARS_START) * 2 end
local function regionVarSet(id, v) F.w16(regionVarAddr(id), v) end
local function regionVarGet(id) return F.r16(regionVarAddr(id)) end

local function sb1FlagGet(id)
  return (F.r8(F.sb1() + S.SaveBlock1.flags + (id // 8)) & (1 << (id % 8))) ~= 0
end
local function sb1FlagSet(id, on)
  local a, m = F.sb1() + S.SaveBlock1.flags + (id // 8), 1 << (id % 8)
  local v = F.r8(a)
  F.w8(a, on and (v | m) or (v & ~m & 0xFF))
end

local function layoutId() return F.r16(F.sb1() + SB1_MAPLAYOUT) end
local function weather()  return F.r8(F.sb1() + SB1_WEATHER) end

-- Find a spawned map-local object event by local id -> x, y (map coords). Resolve by local id, not
-- array index: gObjectEvents order is spawn order.
local function findLocal(want)
  for i = 0, 15 do
    local b = S.gObjectEvents + i * S.ObjectEvent.stride
    if (F.r8(b) & 1) == 1 and F.r8(b + S.ObjectEvent.localId) == want then
      return F.rs16(b + S.ObjectEvent.x) - 7, F.rs16(b + S.ObjectEvent.y) - 7
    end
  end
  return nil
end

-- The kimono cutscene. Arrival is (10,14) and the roof's only corridor north is x=10, so the
-- coord_event at (10,13) is unavoidable — it is the intended flow, not a shortcut.
--
-- This is the part that could not have worked on the deleted map: the descent is
-- `applymovement LOCALID_HO_OH, TinTower_RoofDay_Movement_HoOhAppear` + camera pan, and it lives
-- in the DAY map's scripts. Ho-Oh spawns off-layout at (10,1) — outside the object spawn window
-- from the arrival tile, which is why it is not in gObjectEvents on landing — and the script walks
-- it down to (10,6).
-- Ho-Oh reaching (10,6) is only the MIDDLE of the scene: the camera still has to pan back down,
-- RemoveCameraObject has to run, the five girls look up, and a closing msgbox has to be dismissed
-- before `releaseall`. Asserting at (10,6) catches the player still locked.
--
-- lib's ensureFree() cannot be the release test here: it probes Left then Right, and the player
-- finishes at (10,10) with kimono girls on (9,10), (11,10) and (10,11) — every probe direction is
-- occupied, so it reports "not free" forever. The only open neighbour is (10,9), so an actual
-- northward step IS the release test.
local OBJ_EVENT_ID_CAMERA = 127

local function runKimonoCutscene()
  F.step("Up")
  local descended = false
  for _ = 1, 400 do
    F.idle(40); F.press("B", 2)
    local hx, hy = findLocal(LOCALID_HO_OH)
    if hx == 10 and hy == 6 then descended = true; break end
  end
  if not descended then return false, false end

  -- camera teardown + closing message
  for _ = 1, 200 do
    F.idle(30); F.press("B", 2)
    if findLocal(OBJ_EVENT_ID_CAMERA) == nil then break end
  end
  -- drain to releaseall: B only (A would re-open the box), then test control with a real step
  for _ = 1, 80 do
    F.press("B", 2); F.idle(24)
    if F.step("Up") then return true, true end
  end
  return true, false
end

-- ---- the roof entry, driven from TinTower_8F --------------------------------------------------
-- Debug-warp to 8F warp 2 = (11,9), then walk the decoded route to the roof warp at (6,11).
-- Collision from data/layouts/TinTower_8F/map.bin: (10,9)->(10,11) is the only corridor down.
local function enterRoofFrom8F(tag)
  -- warpTo(group h,t,o, mapNum h,t,o, warpId h,t,o, expectGroup, expectMap, tag)
  -- group 86, map 19, warp 2 = (11,9).
  --
  -- warpTo only checks group/map, so calling it while ALREADY on 8F (which happens when a previous
  -- attempt left the player there) succeeds vacuously without moving anyone. Verify the arrival
  -- TILE too and re-warp until the player is really back at the start of the route.
  --
  -- The route is retried because the corridor is not reliably clear: row 11 is the only way west,
  -- its (8,11) tile sits directly under the MOVEMENT_TYPE_TOWER_BEAM Rayquaza at (8,10), and
  -- object events block movement. An encounter can also eat a step. Both clear on their own.
  -- Warp only when we are not already on 8F. warpTo's success test is group+map ONLY, so calling
  -- it while already on 8F returns true having warped nobody — and leaves the debug menu open,
  -- which then silently eats every step that follows. That produced four identical "route stuck at
  -- (9,11)" attempts in a row.
  if F.mapn() ~= MAP_TIN_TOWER_8F then
    if not F.warpTo(0, 8, 6, 0, 1, 9, 0, 0, 2,
                    GRP_ECRUTEAK_INDOOR, MAP_TIN_TOWER_8F, tag .. "_to8F") then return false end
  end
  F.idle(60)

  if not F.leg(10, 11) then
    local x, y = F.pos()
    F.L(("    could not reach the row-11 corridor, stuck at (%d,%d)"):format(x, y))
    F.shot(tag .. "_corridor")
    return false
  end

  -- Walk west along row 11 to the warp at (6,11). Each step is retried rather than routed once,
  -- because TinTower_8F HAS WILD ENCOUNTERS (land_mons in wild_encounters.json) and an encounter
  -- roll eats the step. That is the intermittent "leg BLOCKED Left at (9,11)" — not the Rayquaza
  -- at (8,10), which is MOVEMENT_TYPE_TOWER_BEAM and that is #defined to MOVEMENT_TYPE_NONE in
  -- johto_compat.h, i.e. perfectly stationary.
  for i = 1, 60 do
    if F.mapn() ~= MAP_TIN_TOWER_8F then
      -- Do NOT read roof state the instant mapNum flips: the warp is still in flight and
      -- ON_TRANSITION (which sets the layout, the weather and clears FLAG_HIDE_HO_OH) has not run
      -- yet. Reading here reported weather=0 on the DAY roof and no kimono girls, both of which
      -- were correct a moment later. Wait for a live overworld, then settle.
      for _ = 1, 200 do F.idle(20); if F.ow() then break end end
      F.idle(180)
      return true
    end
    if not F.ow() then
      F.L("    left the overworld mid-corridor (wild encounter); recovering")
      for _ = 1, 60 do
        F.press("B", 2); F.idle(20)
        if F.ow() then break end
      end
      F.idle(60)
    end
    if not F.step("Left") then
      local bx, by = F.pos()
      F.L(("    step %d blocked at (%d,%d) ow=%s"):format(i, bx, by, tostring(F.ow())))
      F.idle(60)
    end
  end
  local x, y = F.pos()
  F.L(("    never reached the roof warp; stopped at (%d,%d)"):format(x, y))
  F.shot(tag .. "_westfail")
  return false
end

-- ---- one pass -------------------------------------------------------------------------------
local function pass(tag, night)
  F.L(("== %s pass (FLAG_DAY_POKEMON %s) =="):format(tag, night and "SET" or "CLEAR"))

  -- Story state: Ho-Oh summoned, kimono girls present. This is what makes ON_TRANSITION take the
  -- HoohStory branch and clear FLAG_HIDE_HO_OH.
  regionVarSet(VAR_COMPLETED_HO_OH, 2)
  johtoFlagSet(FLAG_HIDE_KIMONO, false)
  sb1FlagSet(FLAG_HIDE_HO_OH, true)   -- start hidden so "it got cleared" is a real observation

  -- The issue's claimed softlock condition, verbatim: night, with FLAG_NIGHT_POKEMON clear.
  johtoFlagSet(FLAG_DAY_POKEMON, night)
  johtoFlagSet(FLAG_NIGHT_POKEMON, not night)
  F.check(tag .. "_seed_var", regionVarGet(VAR_COMPLETED_HO_OH) == 2,
          "VAR_COMPLETED_HO_OH=" .. regionVarGet(VAR_COMPLETED_HO_OH))
  F.check(tag .. "_seed_flags",
          johtoFlagGet(FLAG_DAY_POKEMON) == night and johtoFlagGet(FLAG_NIGHT_POKEMON) == (not night),
          ("day=%s night=%s"):format(tostring(johtoFlagGet(FLAG_DAY_POKEMON)),
                                     tostring(johtoFlagGet(FLAG_NIGHT_POKEMON))))

  if not F.check(tag .. "_reached_roof", enterRoofFrom8F(tag), "walked 8F (6,11) -> roof") then
    return
  end

  local g, m, lay, wx = F.grp(), F.mapn(), layoutId(), weather()
  local x, y = F.pos()
  F.L(("  landed grp=%d map=%d layout=%d weather=%d pos=(%d,%d)"):format(g, m, lay, wx, x, y))
  F.shot(tag .. "_roof")

  -- (1) THE issue: the reachable warp must land on the map that owns the Ho-Oh scripts.
  F.check(tag .. "_map_is_roof_day", g == GRP_ECRUTEAK_INDOOR and m == MAP_ROOF_DAY,
          ("grp=%d map=%d (want %d/%d)"):format(g, m, GRP_ECRUTEAK_INDOOR, MAP_ROOF_DAY))

  -- (2) the layout still swaps, so the now-map-less night layout is still linked and reachable
  local wantLayout = night and LAYOUT_ROOF_NIGHT or LAYOUT_ROOF_DAY
  F.check(tag .. "_layout", lay == wantLayout, ("layout=%d want=%d"):format(lay, wantLayout))

  -- (3) ON_TRANSITION ran here: it took the HoohStory branch and unhid Ho-Oh.
  F.check(tag .. "_hooh_unhidden", not sb1FlagGet(FLAG_HIDE_HO_OH), "FLAG_HIDE_HO_OH cleared by OnTransition")

  -- the map's own objects loaded — kimono girls are local ids 3..7 around (8..12, 11..12)
  local kx, ky = findLocal(LOCALID_KIMONO_MID)
  F.check(tag .. "_kimono_spawned", kx ~= nil, kx and ("Zuki at (%d,%d)"):format(kx, ky) or "local id 4 absent")

  -- (4) D3 weather fix
  local wantW = night and WEATHER_NONE or WEATHER_SUNNY
  F.check(tag .. "_weather", wx == wantW, ("weather=%d want=%d"):format(wx, wantW))

  -- (5) the encounter is really reachable: the coord_event fires, the kimono dance plays, and
  -- Ho-Oh flies down to (10,6). All of that is DAY-map script, on both layouts.
  local descended, released = runKimonoCutscene()
  local hx, hy = findLocal(LOCALID_HO_OH)
  F.shot(tag .. "_hooh")
  F.check(tag .. "_hooh_descended", descended,
          hx and ("Ho-Oh at (%d,%d)"):format(hx, hy) or "Ho-Oh never reached (10,6)")
  F.check(tag .. "_cutscene_released", released, "player regained control after the cutscene")

  -- Player ends at (10,10) (Walk_To_Center = 3x walk_up from the trigger tile); (10,7) is the
  -- talk tile, Ho-Oh sits on solid (10,6) — the legendary-on-a-ledge idiom, GetFacingObject
  -- ignores collision. Walking there proves the encounter is reachable on foot from the warp.
  --
  -- The five kimono girls end the dance scattered across y=9..10 and OBJECT EVENTS BLOCK
  -- MOVEMENT, so the straight x=10 corridor is usually occupied — a collision-only route lies.
  -- The roof room is x=8..12 at y=9..12 and narrows to x=9..11 at y=7..8, so try both flanks.
  local objs = {}
  for i = 0, 15 do
    local b = S.gObjectEvents + i * S.ObjectEvent.stride
    if (F.r8(b) & 1) == 1 then
      objs[#objs + 1] = ("id%d(%d,%d)"):format(F.r8(b + S.ObjectEvent.localId),
        F.rs16(b + S.ObjectEvent.x) - 7, F.rs16(b + S.ObjectEvent.y) - 7)
    end
  end
  F.L("  objects after cutscene: " .. table.concat(objs, " "))

  local reached = false
  for _, wps in ipairs({
    { { 10, 8 }, { 10, 7 } },
    { { 9, 10 }, { 9, 8 }, { 10, 8 }, { 10, 7 } },
    { { 11, 10 }, { 11, 8 }, { 10, 8 }, { 10, 7 } },
  }) do
    if F.leg(wps[1][1], wps[1][2]) then
      local ok = true
      for i = 2, #wps do if not F.leg(wps[i][1], wps[i][2]) then ok = false; break end end
      if ok then reached = true; break end
    end
    local cx, cy = F.pos()
    F.L(("    flank attempt ended at (%d,%d), trying the next"):format(cx, cy))
  end

  local px, py = F.pos()
  F.check(tag .. "_can_face_hooh", reached and px == 10 and py == 7,
          ("player at (%d,%d), want (10,7)"):format(px, py))
  if reached then F.face("Up"); F.shot(tag .. "_facing") end
end

F.run(function()
  if not F.boot(100) then F.finish() return end
  F.check("booted", F.ow(), "overworld reached")

  pass("day", false)
  pass("night", true)

  F.finish()
end)
