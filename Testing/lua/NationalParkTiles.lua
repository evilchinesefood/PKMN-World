-- Issue #53: eleven "johto" layouts read their metatile attributes at the wrong width.
--
-- `MapGridGetMetatileAttributeAt` used to pass `gMapHeader.mapLayout->isFrlg` as the attribute
-- width selector. The width is a property of the BLOB, not of the layout: National Park is a
-- `layout_version: "johto"` layout whose PRIMARY is `gTileset_General_Frlg`, whose attribute blob is
-- natively u32 (2560 B for 640 metatiles). Read at u16 stride, metatile `m` landed on byte `2m` — so
-- even ids returned another metatile's behaviour and odd ids returned ~0 = MB_NORMAL. The fix moves
-- the width onto `struct Tileset.hasFrlgAttributes`, derived at compile time by TILESET_METATILES.
--
-- What that misread actually cost on this map, computed from the two blobs:
--
--   walkable tiles that trigger encounters   207 -> 412
--   surfable tiles                             1 ->   7   (decorative, unreachable — see #54)
--   MB_SOUTH_ARROW_WARP at (12,49) (13,49)  absent -> present
--   MB_EAST_ARROW_WARP  at (40,19)          absent -> present
--
-- That last pair is the sharpest thing to test, because it is DETERMINISTIC and it was a softlock.
-- `TryArrowWarp` (field_control_avatar.c:970) needs `IsArrowWarpMetatileBehavior`, and
-- `TryStartWarpEventScript` (:996) needs `IsWarpMetatileBehavior` — which does NOT include arrow
-- warps. With every gate tile reading MB_NORMAL, National Park's three warp tiles could not fire by
-- either route, and the map's only other warps are the two dead (11,49)/(14,49) entries that are
-- MB_NORMAL in both reads. Entering the park was a one-way trip.
--
-- Nothing here is vacuous: `south_arrow_warp_fires`, `east_arrow_warp_fires` and
-- `grass_encounter_fires` all fail against the pre-fix ROM, and `safe_corridor_no_encounter` is the
-- negative control that makes the grass check mean something rather than just "a battle happened
-- after walking about".
--
-- Coordinates and the route come from data/layouts/NationalPark_Normal/map.bin decoded against both
-- attribute blobs; see the #53 analysis. The corridor is deliberately routed over tiles that are NOT
-- encounter tiles under EITHER read, so the walk doubles as the negative control, and the battle is
-- attributed to the tile only after `gSpecialVar_LastTalked` rules out an overworld-Pokemon bump —
-- see battleWasABump below for why proximity cannot decide that.

local hereDir = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = hereDir .. "?.lua;" .. package.path

local S = require("symbols")
local F = require("lib").new(S, "NationalParkTiles")

local GRP = 83                    -- gMapGroup_JohtoGoldenrod
local PARK, CONTEST, GATE = 4, 5, 7
local BATTLE_TYPE_IS_MASTER = 1 << 2   -- set on every non-link battle; a wild single battle is only this

-- Safe corridor: (12,49) -> (9,29). Every tile on it is collision 0, holds no object event, and is a
-- non-encounter behaviour under BOTH the old u16 misread and the new u32 read — so it doubles as the
-- negative control, and no step on it can produce a grass encounter either before or after the fix.
local CORRIDOR = { { 12, 43 }, { 15, 43 }, { 15, 42 }, { 18, 42 }, { 18, 34 },
                   { 15, 34 }, { 15, 32 }, { 11, 32 }, { 11, 30 }, { 9, 30 }, { 9, 29 } }
local CORRIDOR_STEPS = 35
local STAGE = { 9, 29 }

-- The grass band at y=29, x=10..31: 22 CONSECUTIVE tiles that all go MB_NORMAL -> MB_TALL_GRASS.
-- Walking east along it puts every single step on a tile the fix turned into grass, which is what
-- makes the attribution sound — an alternating two-tile probe spends half its steps on bare ground,
-- and the first version of this suite duly reported a battle starting on the bare tile.
local GRASS_ROW = 29
local GRASS_X0, GRASS_X1 = 10, 31
local GRASS_BUDGET = 60           -- ~3 passes of the band; land_mons encounter_rate is 20

-- National Park places 15 overworld Pokemon (issue #49), and walking into one starts a wild battle
-- from ANY tile. That is the one other way this run can leave the overworld, so the tile attribution
-- has to rule it out — otherwise a bump reads as a passing grass check.
--
-- ★ Proximity cannot do it, and two runs of this suite proved that the hard way. The collision test
-- (`GetObjectObjectCollidesWith`) matches the wild mon's `previousCoords` as well as its current
-- tile, and `TryTriggerOverworldWildEncounter` fires for the FOLLOWER's collisions too, so the real
-- bump radius is not a fixed ring around the player. Worse, the debug party's lead is a Wobbuffet,
-- so the follower's own graphicsId carries OBJ_EVENT_MON (0x50CA) and a naive bit test flagged the
-- player's own pet; tightening the ring then flagged a mon standing DIAGONALLY, which cannot be
-- bumped at all.
--
-- The exact discriminator is `gSpecialVar_LastTalked`. `ProcessPlayerFieldInput` clears it to
-- LOCALID_NONE at the top of every call and a grass roll fires inside that same call, whereas
-- `TryTriggerOverworldWildEncounter` sets it to the wild mon's local id and hands over to
-- `InteractWithOverworldWildEncounter` — a script, so field input stops running and the value
-- survives into the battle. Zero means the tile did it.
local OBJ_EVENT_MON = 1 << 14
local LOCALID_NONE, ID_PLAYER, ID_FOLLOWER = 0, 255, 254
local function battleWasABump(tag)
  local px, py = F.pos()
  local lastTalked = F.r8(S.gSpecialVar_LastTalked)
  local out = {}
  for i = 0, 15 do
    local b = S.gObjectEvents + i * S.ObjectEvent.stride
    if (F.r8(b) & 1) == 1 then
      local x = F.rs16(b + S.ObjectEvent.x) - 7
      local y = F.rs16(b + S.ObjectEvent.y) - 7
      if math.abs(x - px) + math.abs(y - py) <= 2 then
        local id = F.r8(b + S.ObjectEvent.localId)
        local gfx = F.r16(b + S.ObjectEvent.graphicsId)
        local kind = ""
        if id == ID_PLAYER then kind = "=player"
        elseif id == ID_FOLLOWER then kind = "=follower"
        elseif (gfx & OBJ_EVENT_MON) ~= 0 then kind = "=OW_MON" end
        out[#out + 1] = string.format("id%d(%d,%d)gfx=0x%04X%s", id, x, y, gfx, kind)
      end
    end
  end
  -- Log the neighbours either way: on a pass this is what shows the check was not vacuous, and on a
  -- bump it names the culprit.
  F.L(string.format("  %s: player (%d,%d) gSpecialVar_LastTalked=%d, neighbours within 2: %s",
                    tag, px, py, lastTalked,
                    #out > 0 and table.concat(out, " ") or "none"))
  return lastTalked ~= LOCALID_NONE, lastTalked
end

local function at(t) local x, y = F.pos(); return x == t[1] and y == t[2] end
local function here() local x, y = F.pos(); return string.format("(%d,%d)", x, y) end
local function onMap(m) return F.grp() == GRP and F.mapn() == m end

-- Hold one direction and watch for the map to change. The tile ahead of all three gate tiles is
-- collision 1, so the player cannot walk off — an arrow warp is the only thing that can happen, and
-- if the behaviour is MB_NORMAL nothing happens at all.
local function holdForWarp(dir, wantMap, frames, tag)
  for i = 1, frames do
    joypad.set({ [dir] = true }); emu.frameadvance()
    if onMap(wantMap) then
      F.idle(180)   -- the warp is still in flight when mapNum flips; let ON_TRANSITION run
      F.L(string.format("  %s: warped after %d held frames", tag, i))
      return true
    end
  end
  F.L(string.format("  %s: still on map %d after %d held frames at %s", tag, F.mapn(), frames, here()))
  return false
end

local function warpToPark(map, warpId, tag)
  return F.warpTo(0, 8, 3, 0, 0, map, 0, 0, warpId, GRP, map, tag)
end

local function main()
  if not F.boot() then return F.finish() end

  -- ---- 1. south gate, National Park (Normal) ------------------------------------------------
  F.check("warp_to_park_south_gate", warpToPark(PARK, 0, "park_w0") and at({ 12, 49 }),
          "expected (12,49), got " .. here())
  F.shot("park_south_gate")
  F.check("stepped_off_gate_tile", F.step("Up") and at({ 12, 48 }), "expected (12,48), got " .. here())
  F.check("south_arrow_warp_fires", holdForWarp("Down", GATE, 300, "south_arrow") and onMap(GATE),
          "MB_SOUTH_ARROW_WARP at (12,49) must warp to Gate_NationalPark; on the pre-fix ROM that "
          .. "tile reads MB_NORMAL and nothing happens")
  F.shot("gate_from_south")

  -- ---- 2. east gate, National Park (Normal) -------------------------------------------------
  -- The park's only east exit, and the tile the Bug Contest's east entrance warps the player onto
  -- (Gate_NationalPark/scripts.inc:161 `warp MAP_NATIONAL_PARK_BUG_CONTEST, 40, 19`).
  F.check("warp_to_park_east_gate", warpToPark(PARK, 2, "park_w2") and at({ 40, 19 }),
          "expected (40,19), got " .. here())
  F.check("east_arrow_warp_fires", holdForWarp("Right", GATE, 300, "east_arrow") and onMap(GATE),
          "MB_EAST_ARROW_WARP at (40,19) must warp to Gate_NationalPark")
  F.shot("gate_from_east")

  -- ---- 3. the Bug Contest layout still works (regression, not a #53 proof) -------------------
  -- LAYOUT_NATIONAL_PARK_BUG_CONTEST shares gTileset_General_Frlg with the Normal layout and the
  -- flag lives on the tileset, so its 455 corrected behaviours follow by construction — there is
  -- nothing map-specific left to prove. What IS worth checking is that the fix did not disturb the
  -- contest map's own exit flow, because that flow does NOT use the arrow warp:
  --
  --   ★ all four south-gate tiles (11..14, 49) carry a `coord_event` -> EventScript_Trigger, which
  --     `lock`s and opens the attendant's retire YES/NO. `TryStartStepBasedScript`
  --     (field_control_avatar.c:203) runs coord events BEFORE the arrow-warp check (:219) and
  --     returns TRUE, so MB_SOUTH_ARROW_WARP on this layout is unreachable by design. The first
  --     version of this suite asserted the arrow warp here and failed for exactly that reason.
  F.check("warp_to_contest_south_gate", warpToPark(CONTEST, 0, "contest_w0") and at({ 12, 49 }),
          "expected (12,49), got " .. here())
  F.check("contest_stepped_off_gate_tile", F.step("Up") and at({ 12, 48 }),
          "expected (12,48), got " .. here())
  -- Step back onto the gate tile: the coord event must still fire and open a live menu.
  F.step("Down")
  local promptLive = false
  for _ = 1, 12 do
    if F.menuLive() then promptLive = true; break end
    F.press("A", 2); F.idle(35)
  end
  F.check("contest_retire_prompt_still_fires", promptLive and at({ 12, 49 }),
          promptLive and ("retire YES/NO live at " .. here())
                      or ("no menu after stepping onto the contest gate tile at " .. here()))
  F.shot("contest_retire_prompt")
  -- Answer NO. The script then walks the player one tile north and releases; both halves have to
  -- work or the run cannot get field control back to open the debug menu.
  F.pick(1, "retire_no", 8)
  F.dismiss(30)
  F.check("contest_released_after_no", F.ow() and F.ensureFree(),
          "field control after declining retirement, at " .. here())

  -- ---- 4. grass: 206 walkable tiles gained encounters --------------------------------------
  -- Assert the ARRIVAL, not warpTo's return value. `warpTo` only compares group+map, and when it
  -- reports failure it has already left the debug menu open — which then silently eats every later
  -- step. So the check is "am I on the tile with field control", which catches that state too.
  local backOk = warpToPark(PARK, 0, "park_w0b")
  F.check("warp_back_to_park", at({ 12, 49 }) and F.ow(),
          string.format("at %s ow=%s (warpTo returned %s)", here(), tostring(F.ow()), tostring(backOk)))

  -- Seed a party. `BattleSetup_StartWildBattle` has a 0-party guard, so with an empty party the
  -- grass check would fail for a reason that has nothing to do with metatile behaviour.
  -- Debug root row 2 = "Party...", submenu row 9 = "Set Party" (since 65b63de1 it publishes the
  -- count itself; the w8 below is a belt-and-braces fallback, not the mechanism under test).
  F.dbg(); F.sel(2); F.sel(9); F.bOut(4); F.idle(60)
  if F.r8(S.gPartiesCount) == 0 then F.w8(S.gPartiesCount, 1) end
  F.check("party_seeded", F.r8(S.gPartiesCount) > 0, "gPartiesCount = " .. F.r8(S.gPartiesCount))
  F.dismiss(20)

  -- The control. 35 steps over tiles that are non-encounter behaviours under BOTH reads: without it,
  -- "a battle happened after walking about the park" would prove nothing about the fix.
  local corridorOk, corridorWhere = true, ""
  for i, wp in ipairs(CORRIDOR) do
    if not F.leg(wp[1], wp[2]) then
      corridorOk = false; corridorWhere = string.format("blocked at wp%d %s", i, here()); break
    end
    if not F.ow() then
      corridorOk = false
      corridorWhere = string.format("left the overworld at %s during leg %d — no tile on this "
                                    .. "corridor is an encounter tile under either read, so this is "
                                    .. "an overworld-Pokemon bump, not a grass roll", here(), i)
      battleWasABump("corridor_battle")
      break
    end
  end
  F.check("safe_corridor_no_encounter", corridorOk and at(STAGE),
          corridorOk and (CORRIDOR_STEPS .. " non-encounter steps, ended at " .. here())
                      or corridorWhere)
  F.shot("staging_tile")

  -- Walk the band. Every step lands on a tile that only has encounters because of the fix, so the
  -- tile the player is standing on when the battle starts is the attribution.
  local fired, steps, tileX, tileY, bumped, lastTalked = false, 0, -1, -1, false, 0
  local dir = "Right"
  if at(STAGE) then
    for i = 1, GRASS_BUDGET do
      F.step(dir)
      steps = i
      local x, y = F.pos()
      if not F.ow() then
        fired = true; tileX, tileY = x, y
        bumped, lastTalked = battleWasABump("grass_battle")
        break
      end
      if x >= GRASS_X1 then dir = "Left" elseif x <= GRASS_X0 then dir = "Right" end
    end
  end
  -- Sample AFTER the transition settles. gBattlersCount is set during battle init, so reading it the
  -- frame the overworld callback drops reports 0 — which reads exactly like "not really a battle".
  F.idle(240)
  local flags, battlers = F.battleFlags(), F.battlers()
  F.check("grass_encounter_fires", fired,
          fired and string.format("battle after %d grass steps at (%d,%d), battlers=%d, flags=0x%08X",
                                  steps, tileX, tileY, battlers, flags)
                or string.format("no encounter in %d steps along the y=%d band (x %d..%d), every one "
                                 .. "of which the fix turns into MB_TALL_GRASS",
                                 steps, GRASS_ROW, GRASS_X0, GRASS_X1))
  -- There is no BATTLE_TYPE_WILD bit. A plain wild single battle is exactly BATTLE_TYPE_IS_MASTER
  -- ("in not-link battles, it's always set"), so requiring that one bit and nothing else is a
  -- sharper test than checking BATTLE_TYPE_TRAINER is clear: it also rules out SAFARI, LEGENDARY,
  -- DOUBLE and a link/recorded battle. `battlers` must be sampled after the transition settles.
  F.check("encounter_was_wild", fired and flags == BATTLE_TYPE_IS_MASTER and battlers == 2,
          string.format("flags=0x%08X battlers=%d (a wild single battle is exactly "
                        .. "BATTLE_TYPE_IS_MASTER with 2 battlers)", flags, battlers))
  F.check("encounter_on_a_gained_grass_tile",
          fired and not bumped
                and tileY == GRASS_ROW and tileX >= GRASS_X0 and tileX <= GRASS_X1,
          bumped and string.format("gSpecialVar_LastTalked=%d — the player or its follower walked "
                                   .. "into overworld Pokemon id%d, so this battle is not "
                                   .. "attributable to the tile", lastTalked, lastTalked)
                 or string.format("battle started at (%d,%d); the gained-grass band is y=%d x=%d..%d",
                                  tileX, tileY, GRASS_ROW, GRASS_X0, GRASS_X1))
  F.shot("grass_encounter")

  F.finish()
end

F.run(main)
