-- #195: the Hoenn hub gate must seed the Littleroot first-visit state ONCE, not on every cross.
--
-- `hoennIntroDone` (SaveBlock2 bitfield) is written by ONE site: `region_intro_done_hook` on
-- Littleroot Town's ON_FRAME (src/region_switch.c RegionHub_ScrSetIntroDone). A player who takes
-- the HUB PASS back out of the bedroom before ever stepping outside therefore still reads as a
-- first visit, and `RegionHub_EventScript_AttendantHoennBoard` used to re-run its whole seed:
-- rewinding VAR_LITTLEROOT_INTRO_STATE from 6/7 to 4 and VAR_LITTLEROOT_HOUSES_STATE_BRENDAN to 1.
-- The fix guards those two setvars (and the idempotent hide flags) behind
-- `call_if_eq VAR_LITTLEROOT_INTRO_STATE, 0`.
--
-- SCOPE, because it is easy to over-assert here: `setrespawn` and the `warp` deliberately stay
-- OUTSIDE the guard (data/maps/RegionHub/scripts.inc, the comment above the call_if_eq) -- the
-- gate warps the player to 2F on EVERY visit, so 2F is the right respawn on every visit, and
-- RegionHub_ScrEnterRegion re-arms the respawn from C one callnative earlier regardless. So the
-- respawn is a CONTRACT check below, not a #195 discriminator: it reads the same on both ROMs.
--
-- This is a SIBLING of HoennIntroClock.lua, not an extension of it. That suite warps straight to
-- Brendan's 2F with the arrival state forged and stops at "the stairs let me through"; it never
-- touches the hub gate, the HUB PASS, Littleroot Town or the intro-done bit. This one drives the
-- whole journey through the real scripts and is ~4x longer, so folding them together would make
-- a clock-skip regression and a gate regression share one verdict line.
--
-- Three scenarios, in the only order that can produce them from one fresh save:
--   S2  a genuine first visit still seeds  (the regression risk the guard creates)
--   S1  the HUB PASS re-cross does NOT rewind  (the bug; the ONLY discriminating phase)
--   S3  walking out to town latches hoennIntroDone  (coverage nothing else has)
--
-- Run via: Testing/mgba-run.sh Testing/lua/HubPassReCross.lua <rom.gba>

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "HubPassReCross")

-- ---- map ids (include/constants/map_groups.h) -------------------------------------------------
local HUB_G,   HUB_M   = 100, 0   -- MAP_REGION_HUB
local BR2F_G,  BR2F_M  = 1,   1   -- MAP_LITTLEROOT_TOWN_BRENDANS_HOUSE_2F
local BR1F_G,  BR1F_M  = 1,   0   -- MAP_LITTLEROOT_TOWN_BRENDANS_HOUSE_1F
local TOWN_G,  TOWN_M  = 0,   9   -- MAP_LITTLEROOT_TOWN
local HARB_G,  HARB_M  = 9,   9   -- MAP_SLATEPORT_CITY_HARBOR  (RegionHub_EventScript_ReturnHoenn)
local PCEN_G,  PCEN_M  = 2,   2   -- MAP_OLDALE_TOWN_POKEMON_CENTER_1F (the respawn sentinel)

-- ---- vars / flags (include/constants/vars.h, flags.h) ------------------------------------------
local VARS_START         = 0x4000
local VAR_INTRO          = 0x4092  -- VAR_LITTLEROOT_INTRO_STATE
local VAR_HOUSES_BRENDAN = 0x408C  -- VAR_LITTLEROOT_HOUSES_STATE_BRENDAN
local VAR_REGION_ARRIVAL = 0x40FD

local FLAG_SET_WALL_CLOCK      = 0x51
local FLAG_HUB_INTRO_TOUR_DONE = 0xDCF   -- FLAG_WORLD_MAP_BANK (0xD40) + 0x8F
-- The six hide flags RegionHub_EventScript_SeedFirstVisitHoennMale sets. These are idempotent, so
-- they are S2 evidence (did the seed run at all) rather than S1 evidence.
local SEED_FLAGS = {
  { 0x2F7, "MAYS_HOUSE_MOM" },
  { 0x2FA, "MAYS_HOUSE_TRUCK" },
  { 0x310, "BRENDANS_HOUSE_RIVAL_MOM" },
  { 0x2DF, "BRENDANS_HOUSE_RIVAL_SIBLING" },
  { 0x331, "BRENDANS_HOUSE_2F_POKE_BALL" },
  { 0x2F9, "BRENDANS_HOUSE_TRUCK" },
}

-- SaveBlock2 +0x92 packs three first-visit bits (include/global.h:629): bit0 kanto, bit1 johto,
-- bit2 hoenn. Read through S so a struct move is a symbols.lua edit, not 40 suite edits — and the
-- suite proves the offset rather than trusting it: the bit must read CLEAR for the whole journey
-- and flip on exactly the frame Littleroot's arrival scene runs, which a wrong byte cannot do.
local HOENN_INTRO_DONE_BIT = 2

-- ---- hub floor plan (data/maps/RegionHub/map.json) ---------------------------------------------
local ATTENDANT_HOENN = { 21, 3 }   -- talk tile below the TEALA at (21,2)
local HUB_ARRIVE      = { 16, 4 }   -- Task_UseHubReturnOnField's fixed re-entry tile

-- ---- small readers -----------------------------------------------------------------------------
local function varAddr(id) return F.sb1() + S.SaveBlock1.vars + (id - VARS_START) * 2 end
local function varGet(id) return F.r16(varAddr(id)) end
local function varSet(id, v) F.w16(varAddr(id), v) end

local function flagAddr(id) return F.sb1() + S.SaveBlock1.flags + (id // 8) end
local function flagGet(id) return (F.r8(flagAddr(id)) & (1 << (id % 8))) ~= 0 end
local function flagSet(id) F.w8(flagAddr(id), F.r8(flagAddr(id)) | (1 << (id % 8))) end

-- struct WarpData { s8 mapGroup; s8 mapNum; s8 warpId; s16 x, y; } (include/global.h:710)
local function healAddr() return F.sb1() + S.SaveBlock1.lastHealLocation end
local function healLoc() return F.rs8(healAddr()), F.rs8(healAddr() + 1) end
local function setHealLoc(g, m, x, y)
  F.w8(healAddr(), g); F.w8(healAddr() + 1, m); F.w8(healAddr() + 2, 0)
  F.w16(healAddr() + 4, x); F.w16(healAddr() + 6, y)
end
local function healStr()
  return string.format("(%d,%d)@(%d,%d)", F.rs8(healAddr()), F.rs8(healAddr() + 1),
    F.rs16(healAddr() + 4), F.rs16(healAddr() + 6))
end

local function introDone()
  return (F.r8(F.sb2() + S.SaveBlock2.introDoneBits) & (1 << HOENN_INTRO_DONE_BIT)) ~= 0
end

local function keyItems()
  local _, dump = F.keyItemSlot(0xFFFF)   -- an id nothing can match: dump only
  return dump
end

local function mapIs(g, m) return F.grp() == g and F.mapn() == m end
local function where()
  return string.format("grp=%d map=%d pos=(%d,%d)", F.grp(), F.mapn(), F.pos())
end
local function state()
  return string.format("intro=%d houses=%d heal=%s arrival=%d introDone=%s",
    varGet(VAR_INTRO), varGet(VAR_HOUSES_BRENDAN), healStr(),
    varGet(VAR_REGION_ARRIVAL), tostring(introDone()))
end
local function dumpObjects(tag)
  local parts = {}
  for _, o in ipairs(F.objdump()) do
    parts[#parts + 1] = string.format("%d:(%d,%d)", o.i, o.x, o.y)
  end
  F.L(string.format("  objects %s: %s", tag, table.concat(parts, " ")))
end

-- ---- YES/NO driver -----------------------------------------------------------------------------
-- lib's pick() is unusable on a two-row YES/NO: both the script msgbox (ScriptMenu_YesNo) and the
-- field item confirm (DisplayYesNoMenuWithDefault) run Menu_ProcessInputNoWrapClearOnChoose, so
-- Down at the bottom row does NOT wrap and pick()'s Down-only walk hangs there for its whole
-- budget. Probe liveness with Down THEN Up (a real menu moves for one of them wherever the cursor
-- sits; a stale sMenu static moves for neither), then drive the cursor by reading it.
--   want: 0 = YES, 1 = NO.
local function yesNo(want, tag, maxA)
  for _ = 1, (maxA or 24) do
    if F.reportCrash("yesno_" .. tag) then return false end
    local c0 = F.mcur()
    F.press("Down", 2); F.idle(12)
    local live = F.mcur() ~= c0
    if not live then
      c0 = F.mcur()
      F.press("Up", 2); F.idle(12)
      live = F.mcur() ~= c0
    end
    if live then
      for _ = 1, 6 do
        local c = F.mcur()
        if c == want then
          F.press("A", 2); F.idle(60)
          F.L(string.format("  yesNo %s -> row %d", tag, want))
          return true
        end
        F.press(c > want and "Up" or "Down", 2); F.idle(12)
      end
      F.L(string.format("  yesNo %s: cursor never reached %d (at %d)", tag, want, F.mcur()))
      return false
    end
    F.press("A", 2); F.idle(35)
  end
  F.L("  yesNo " .. tag .. ": menu never went live")
  return false
end

-- Advance msgboxes with A until the map becomes (g,m). Returns as soon as it does, so nothing is
-- pressed on the destination map. A only — B would answer NO to any YES/NO still queued behind.
local function mashToMap(g, m, tag, budget)
  for _ = 1, (budget or 150) do
    if mapIs(g, m) then F.idle(90); return true end
    if F.reportCrash("mash_" .. tag) then return false end
    F.press("A", 2); F.idle(20)
  end
  return mapIs(g, m)
end

-- Talk to the Hoenn attendant and answer YES. Leaves the player wherever the gate warped them.
local function crossToHoenn(tag)
  if not F.route({ { HUB_ARRIVE[1], HUB_ARRIVE[2] }, { ATTENDANT_HOENN[1], HUB_ARRIVE[2] },
                   ATTENDANT_HOENN }, "walk_" .. tag) then
    return false
  end
  F.face("Up")
  F.press("A", 3); F.idle(50)
  if not yesNo(0, "travelHoenn_" .. tag) then F.shot(tag .. "_noyesno"); return false end
  -- TryGiveHubPass' give box (first cross only), then the gate's warp.
  return mashToMap(BR2F_G, BR2F_M, tag)
end

F.run(function()
  ------------------------------------------------------------------------------------------------
  -- Phase 0 — preconditions. A fresh save must really be a Hoenn first-timer, or S2 proves
  -- nothing and S1 cannot reach the bug at all.
  ------------------------------------------------------------------------------------------------
  if not F.boot(HUB_G) then F.check("boot", false, where()); F.finish(); return end
  F.check("booted in the World Transit hub", mapIs(HUB_G, HUB_M), where())
  F.check("player is MALE (the seed path under test)",
    F.r8(F.sb2() + S.SaveBlock2.playerGender) == 0,
    "gender=" .. F.r8(F.sb2() + S.SaveBlock2.playerGender))
  F.check("fresh save: VAR_LITTLEROOT_INTRO_STATE is 0", varGet(VAR_INTRO) == 0, state())
  F.check("fresh save: hoennIntroDone is clear", not introDone(), state())

  -- The #195 player is Johto/Kanto-first: they set the wall clock in their home region, which is
  -- what makes 2F's clock take the ClockAlreadySetElsewhere branch to state 6. One global flag.
  flagSet(FLAG_SET_WALL_CLOCK)
  F.check("seeded FLAG_SET_WALL_CLOCK (Johto/Kanto-first player)", flagGet(FLAG_SET_WALL_CLOCK))
  -- boot() already declined the arrival tour, which sets this. Set it explicitly anyway: the suite
  -- re-enters the hub twice on the crest tile (16,4), which is the tour's own coord_event, and a
  -- tour firing mid-run would eat the attendant walk for a reason unrelated to #195.
  flagSet(FLAG_HUB_INTRO_TOUR_DONE)
  F.check("FLAG_HUB_INTRO_TOUR_DONE set (the crest coord_event cannot re-fire)",
    flagGet(FLAG_HUB_INTRO_TOUR_DONE))

  local bagBefore = keyItems()
  F.L("  key items before the first cross: " .. #bagBefore)

  ------------------------------------------------------------------------------------------------
  -- S2 — a genuine first visit MUST still be seeded. This is the regression the guard risks.
  ------------------------------------------------------------------------------------------------
  local crossed = crossToHoenn("first")
  F.check("S2 first cross landed in Brendan's 2F", crossed, where())
  if not crossed then F.shot("s2_lost"); F.finish(); return end
  F.shot("s2_first_arrival")

  -- 2F's ON_TRANSITION runs BlockStairsUntilClockIsSet on state 4, so 4 is already 5 by the time
  -- anything can read it. 5 is still exclusive proof the seed ran: nothing turns 0 into 5.
  F.check("S2 seed ran: intro state is 5 (seeded 4, 2F ON_TRANSITION advanced it)",
    varGet(VAR_INTRO) == 5, state())
  F.check("S2 seed ran: VAR_LITTLEROOT_HOUSES_STATE_BRENDAN is 1",
    varGet(VAR_HOUSES_BRENDAN) == 1, state())
  -- The respawn is written TWICE on every cross: RegionHub_ScrEnterRegion calls
  -- SetRegionArrivalRespawn (src/region_switch.c) which arms the TOWN door
  -- (HEAL_LOCATION_LITTLEROOT_TOWN_BRENDANS_HOUSE, MAP_LITTLEROOT_TOWN), then the gate's
  -- `setrespawn HEAL_LOCATION_LITTLEROOT_TOWN_BRENDANS_HOUSE_2F` overwrites it with the bedroom.
  -- That second write sits OUTSIDE the guard, so this is the same contract check S1 makes, not
  -- seed evidence -- the seed evidence is the two vars and the six flags either side of it.
  local hg, hm = healLoc()
  F.check("S2 the cross arms the bedroom respawn (contract, both ROMs)",
    hg == BR2F_G and hm == BR2F_M,
    string.format("heal=(%d,%d) want=(%d,%d)", hg, hm, BR2F_G, BR2F_M))
  for _, f in ipairs(SEED_FLAGS) do
    F.check("S2 seed ran: FLAG_HIDE_LITTLEROOT_TOWN_" .. f[2] .. " set", flagGet(f[1]))
  end

  -- The HUB PASS the attendant handed over on the way in. Its id is DERIVED, not hardcoded: the
  -- one key item that appeared across the cross is the pass, so an ITEMS_COUNT shift cannot make
  -- this suite quietly drive the wrong item.
  local bagAfter = keyItems()
  local seen = {}
  for _, id in ipairs(bagBefore) do seen[id] = true end
  local hubPass
  for _, id in ipairs(bagAfter) do if not seen[id] then hubPass = id break end end
  F.check("S2 the gate handed over the HUB PASS", hubPass ~= nil,
    string.format("before=%d after=%d id=%s", #bagBefore, #bagAfter, tostring(hubPass)))
  if not hubPass then F.finish(); return end
  F.L(string.format("  HUB PASS item id = %d", hubPass))

  ------------------------------------------------------------------------------------------------
  -- Reach state 6 the way the #195 player does: the clock they already set elsewhere.
  ------------------------------------------------------------------------------------------------
  F.check("route to the wall clock tile (5,2)", F.route({ { 5, 2 } }, "clock"), where())
  F.face("Up")
  F.press("A", 3); F.idle(40)
  for _ = 1, 40 do F.press("A", 2); F.idle(16); F.press("B", 2); F.idle(16) end
  F.dismiss(20)
  F.shot("after_clock")
  local at6 = varGet(VAR_INTRO) == 6
  F.check("clock-already-set branch advanced intro to 6", at6, state())
  if not at6 then F.finish(); return end

  -- Advance the houses state so "unchanged" is a real claim: left at 1 it would be
  -- indistinguishable from a rewind TO 1. 2 = "Met Rival's Mom", the next value the intro reaches.
  varSet(VAR_HOUSES_BRENDAN, 2)
  F.check("staged VAR_LITTLEROOT_HOUSES_STATE_BRENDAN = 2 (Met Rival's Mom)",
    varGet(VAR_HOUSES_BRENDAN) == 2, state())
  -- Stand in for "a POKeMON CENTER they registered since arriving", so the respawn contract check
  -- after the re-cross has something to displace. Two writers act on the re-cross and neither is
  -- the bug: RegionHub_ScrEnterRegion -> SetRegionArrivalRespawn (C, arms Littleroot Town's door,
  -- src/region_switch.c) and then the gate's unguarded `setrespawn ..._BRENDANS_HOUSE_2F`, which
  -- wins. Both are by design; what matters is that the stale cross-region PC does not survive.
  setHealLoc(PCEN_G, PCEN_M, 6, 8)
  F.check("staged an OLDALE POKeMON CENTER respawn over the bedroom",
    select(1, healLoc()) == PCEN_G and select(2, healLoc()) == PCEN_M, state())
  F.check("hoennIntroDone still clear (never walked outside)", not introDone(), state())

  ------------------------------------------------------------------------------------------------
  -- S1 — HUB PASS out of the bedroom, re-cross the Hoenn gate, nothing rewinds.
  -- THIS is the discriminating phase.
  ------------------------------------------------------------------------------------------------
  -- Register the pass to SELECT rather than driving the BAG UI: the field callback under test
  -- (ItemUseOutOfBattle_HubReturn) is the same one the BAG's USE reaches, and this cannot get lost
  -- in a pocket cursor. The write proves S.SaveBlock1.registeredItem by itself — a wrong offset
  -- leaves SELECT inert and the phase fails loudly rather than silently skipping.
  F.w16(F.sb1() + S.SaveBlock1.registeredItem, hubPass)
  F.press("Select", 2); F.idle(90)
  -- Cursor rests on NO by design (item_use.c: the warp is one-way), so this must move it.
  local said = yesNo(0, "hubPassConfirm")
  F.check("S1 the HUB PASS confirm opened inside the house and took YES", said, where())
  local backInHub = said and mashToMap(HUB_G, HUB_M, "hubpass") or false
  F.check("S1 the HUB PASS warped out of the bedroom to the hub", backInHub, where())
  if not backInHub then F.shot("s1_pass_failed"); F.finish(); return end
  F.shot("s1_back_in_hub")
  F.check("S1 hoennIntroDone STILL clear, so the gate re-runs its first-visit branch",
    not introDone(), state())

  local recrossed = crossToHoenn("recross")
  F.check("S1 re-cross landed in Brendan's 2F again", recrossed, where())
  if not recrossed then F.shot("s1_lost"); F.finish(); return end
  F.shot("s1_after_recross")

  -- ---- the three assertions that fail on a ROM without the guard -------------------------------
  F.check("S1 intro state NOT rewound (still 6, not re-seeded to 4/5)",
    varGet(VAR_INTRO) == 6, state())
  F.check("S1 VAR_LITTLEROOT_HOUSES_STATE_BRENDAN NOT rewound to 1",
    varGet(VAR_HOUSES_BRENDAN) == 2, state())
  -- CONTRACT, not a discriminator. The gate's `setrespawn` is deliberately outside the guard, so
  -- this reads (1,1)@(4,2) on the fixed AND the unfixed ROM. It is worth an assertion anyway: it
  -- is the documented invariant ("the player is warped to 2F on every visit, so 2F is the right
  -- respawn on every visit"), and it is the one that would catch someone moving `setrespawn`
  -- inside the guard as a tidy-up -- which leaves a returning player's respawn on whatever
  -- SetRegionArrivalRespawn armed (Littleroot Town's door), a silent behaviour change.
  local rg, rm = healLoc()
  F.check("S1 CONTRACT (not a discriminator): the cross re-arms the respawn to Brendan's 2F, "
          .. "so the stale cross-region POKeMON CENTER does not survive",
    rg == BR2F_G and rm == BR2F_M,
    string.format("heal=%s  want=(%d,%d) sentinel=(%d,%d) arrivalRespawn=(%d,%d)",
      healStr(), BR2F_G, BR2F_M, PCEN_G, PCEN_M, TOWN_G, TOWN_M))

  ------------------------------------------------------------------------------------------------
  -- S3 — walk 2F -> 1F -> outdoors. The arrival scene fires, VAR_REGION_ARRIVAL clears, and the
  -- hoennIntroDone bit latches. Nothing in the tree covered this.
  ------------------------------------------------------------------------------------------------
  F.check("route to the 2F stairs tile (7,1)", F.route({ { 7, 1 } }, "stairs"), where())
  F.face("Up")
  F.press("Up", 8); F.idle(120)
  F.check("S3 the stairs let us onto 1F at all", mapIs(BR1F_G, BR1F_M), where())
  -- 1F ON_FRAME fires PetalburgGymReport at intro state 6 (a long Mom/TV cutscene that
  -- applymovements the player across the room). Mash it out, then walk from wherever it parked us.
  for _ = 1, 40 do F.press("A", 2); F.idle(24) end
  F.dismiss(30)
  F.shot("s3_on_1f")
  -- Re-read AFTER the scene, not on the frame the warp lands: at intro state 5 (the rewound
  -- state) 1F's ON_TRANSITION parks Mom on the stairs and GoUpstairsToSetClock warps the player
  -- straight back to 2F, so an on-arrival sample reports 1F for a run that got bounced.
  F.check("S3 still on 1F after the arrival scene, not a mom-bounce back onto 2F",
    mapIs(BR1F_G, BR1F_M), where() .. " " .. state())
  if not mapIs(BR1F_G, BR1F_M) then F.shot("s3_stairs"); F.finish(); return end
  dumpObjects("1F")
  F.L("  1F player at " .. where() .. "  " .. state())

  -- Back out the way the cutscene walked us in (PlayersHouse_1F_Movement_PlayerApproachTVForGymMale
  -- is down,down,left,left,left from the stairs), then south to the door mat at (8,8). Going down
  -- the west side first does NOT work: (4,6) is furniture.
  local out = F.route({ { 8, 5 } }, "toDoorRow")
  F.check("route back to the 1F door column (8,5)", out, where())
  if out then
    for _ = 1, 6 do
      if mapIs(TOWN_G, TOWN_M) then break end
      F.step("Down"); F.idle(60)
    end
  end
  F.idle(120)
  F.check("S3 stepped out into Littleroot Town", mapIs(TOWN_G, TOWN_M), where())
  if not mapIs(TOWN_G, TOWN_M) then F.shot("s3_door"); F.finish(); return end
  F.shot("s3_littleroot")

  -- ON_TRANSITION's region_arrival_hook armed the scene; the ON_FRAME msgbox is blocking, so the
  -- var is still 1 while it is up. Read BEFORE dismissing it.
  F.check("S3 arrival scene armed: VAR_REGION_ARRIVAL is 1", varGet(VAR_REGION_ARRIVAL) == 1,
    state())
  F.check("S3 hoennIntroDone still clear while the scene is on screen", not introDone(), state())
  for _ = 1, 24 do F.press("A", 2); F.idle(30) end
  F.dismiss(20)
  F.shot("s3_after_arrival")
  F.check("S3 region_intro_done_hook latched hoennIntroDone", introDone(), state())
  F.check("S3 region_intro_done_hook cleared VAR_REGION_ARRIVAL",
    varGet(VAR_REGION_ARRIVAL) == 0, state())

  ------------------------------------------------------------------------------------------------
  -- S3b — the same claim without reading a struct offset. With the bit set, the gate must take
  -- RegionHub_EventScript_ReturnHoenn (Slateport harbour) instead of the bedroom. If the bit read
  -- above were the wrong byte, this contradicts it.
  ------------------------------------------------------------------------------------------------
  F.w16(F.sb1() + S.SaveBlock1.registeredItem, hubPass)
  F.press("Select", 2); F.idle(90)
  local said2 = yesNo(0, "hubPassConfirm2")
  local hub2 = said2 and mashToMap(HUB_G, HUB_M, "hubpass2") or false
  F.check("S3b HUB PASS returned to the hub from Littleroot Town", hub2, where())
  if hub2 then
    F.check("route to the Hoenn attendant", F.route({ { ATTENDANT_HOENN[1], HUB_ARRIVE[2] },
                                                      ATTENDANT_HOENN }, "walk_return"), where())
    F.face("Up")
    F.press("A", 3); F.idle(50)
    F.check("S3b the returning-traveller YES/NO opened", yesNo(0, "travelHoenn_return"), where())
    mashToMap(HARB_G, HARB_M, "return", 150)
    F.shot("s3b_return_destination")
    F.check("S3b intro-done routes the gate to SLATEPORT HARBOR, not the bedroom",
      mapIs(HARB_G, HARB_M), where() .. " bedroom=(1,1)")
  end

  F.finish()
end)
