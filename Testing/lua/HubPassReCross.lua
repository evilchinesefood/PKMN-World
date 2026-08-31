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
-- SCOPE, because it is easy to over-assert here: `setrespawn` and the home `warp` deliberately
-- stay OUTSIDE the guard (data/maps/RegionHub/scripts.inc, the comment above the call_if_eq). The
-- gate warps the player to 2F on every PRE-BADGE visit, so 2F is the right respawn on those visits,
-- and RegionHub_ScrEnterRegion re-arms the respawn from C one callnative earlier regardless. So
-- the respawn is a CONTRACT check below, not a #195 discriminator: it reads the same on both ROMs.
--
-- This is a SIBLING of HoennIntroClock.lua, not an extension of it. That suite warps straight to
-- Brendan's 2F with the arrival state forged and stops at "the stairs let me through"; it never
-- touches the hub gate, the HUB PASS, Littleroot Town or the intro-done bit. This one drives the
-- whole journey through the real scripts and is ~4x longer, so folding them together would make
-- a clock-skip regression and a gate regression share one verdict line.
--
-- Five scenarios, in the only order that can produce them from one fresh save:
--   S2  a genuine first visit still seeds  (the regression risk the guard creates)
--   S1  the HUB PASS re-cross does NOT rewind  (the bug; the first discriminating phase)
--   S3  walking out latches hoennIntroDone, but only the first badge unlocks Slateport
--   S4  the SAME gate on the FEMALE branch still seeds MAY's own state on a genuine first visit
--   S5  the FEMALE re-cross does NOT rewind either  (the second discriminating phase)
--
-- S4/S5 are a SEGMENT of this suite, not a sibling suite. S1-S3 pin `playerGender == MALE`, so
-- every assertion above walks straight past `goto_if_eq VAR_RESULT, FEMALE` and the female half of
-- the fix had no coverage at all -- and that half is not a copy of the male one: it writes a
-- different var (VAR_LITTLEROOT_HOUSES_STATE_MAY), a different six hide flags, a different respawn
-- and a different destination map, so a regression there is invisible to S1/S2/S3. Everything
-- expensive is already paid for by the time S4 starts (the fresh boot, the derived HUB PASS id, the
-- yesNo() driver, FLAG_SET_WALL_CLOCK, FLAG_HUB_INTRO_TOUR_DONE), so a sibling suite would re-run
-- all of it and split one regression across two verdict lines.
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

local MAY2F_G, MAY2F_M = 1, 3     -- MAP_LITTLEROOT_TOWN_MAYS_HOUSE_2F (S4/S5's destination)
local VAR_HOUSES_MAY   = 0x4082   -- VAR_LITTLEROOT_HOUSES_STATE_MAY. NOT ..._BRENDAN + 1.

local FLAG_SET_WALL_CLOCK      = 0x51
local FLAG_HUB_INTRO_TOUR_DONE = 0xDCF   -- FLAG_WORLD_MAP_BANK (0xD40) + 0x8F
local FLAG_BADGE01_GET         = 0x94F   -- Hoenn Stone Badge; exact late-arrival unlock
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
-- RegionHub_EventScript_SeedFirstVisitHoennFemale's six. Only four of them are new: BOTH truck
-- flags are in BOTH seed lists (the hub hides both trucks whichever gender crosses), so S4 clears
-- all six before its cross -- otherwise those two assertions would pass on S2's leftovers no matter
-- what the female script did, which is exactly the vacuous check this suite exists to avoid.
local MAY_SEED_FLAGS = {
  { 0x2F6, "BRENDANS_HOUSE_MOM" },
  { 0x2F9, "BRENDANS_HOUSE_TRUCK" },
  { 0x311, "MAYS_HOUSE_RIVAL_MOM" },
  { 0x2E0, "MAYS_HOUSE_RIVAL_SIBLING" },
  { 0x332, "MAYS_HOUSE_2F_POKE_BALL" },
  { 0x2FA, "MAYS_HOUSE_TRUCK" },
}

-- SaveBlock2 +0x92 packs three first-visit bits (include/global.h:629): bit0 kanto, bit1 johto,
-- bit2 hoenn. Read through S so a struct move is a symbols.lua edit, not 40 suite edits — and the
-- suite proves the offset rather than trusting it: the bit must read CLEAR for the whole journey
-- and flip on exactly the frame Littleroot's arrival scene runs, which a wrong byte cannot do.
local HOENN_INTRO_DONE_BIT = 2

-- ---- hub floor plan (data/maps/RegionHub/map.json) ---------------------------------------------
local ATTENDANT_HOENN = { 21, 3 }   -- talk tile below the TEALA at (21,2)
local HUB_ARRIVE      = { 16, 4 }   -- Task_UseHubReturnOnField's fixed re-entry tile

-- ---- May's 2F floor plan (data/maps/LittlerootTown_MaysHouse_2F/map.json) ----------------------
-- May's house is the horizontal MIRROR of Brendan's (x -> 8-x on the 9-wide 2F layout), so the male
-- coordinates do NOT carry over -- only the two that sit on the mirror axis do, which is why the
-- gate's arrival tile (4,4) and the respawn (4,2) read the same for both genders and everything
-- else does not. The wall clock sign is at (3,1) against the male (5,1), and row 1 is solid apart
-- from the stairs, so the player stands on (3,2) facing Up (male: (5,2)).
-- The waypoint is not decoration. leg() walks x before y, so a bare route to (3,2) from (4,4) hops
-- through (3,4) -- the tile May's 2F parks its PICHU DOLL on (object 14, where Brendan's 2F has an
-- ITEM BALL, which is why the male segment never had to think about it). That doll is elevation 4
-- against the tile's 3, so it may well not collide at all; going up the x=4 column and then west
-- along row 2 sidesteps the question, because (4,3), (4,2) and (3,2) hold no object on this map.
local MAY_CLOCK_ROUTE = { { 4, 2 }, { 3, 2 } }

-- The HUB PASS id S2 derives, and whether Phase 0 ever got a controllable overworld. Both are file
-- scope because the May segment is a separate function: a bail inside the male journey must end
-- THAT journey, not skip S4/S5 and leave the coverage they add with no verdict at all.
local hubPass
local booted = false

-- ---- small readers -----------------------------------------------------------------------------
local function varAddr(id) return F.sb1() + S.SaveBlock1.vars + (id - VARS_START) * 2 end
local function varGet(id) return F.r16(varAddr(id)) end
local function varSet(id, v) F.w16(varAddr(id), v) end

local function flagAddr(id) return F.sb1() + S.SaveBlock1.flags + (id // 8) end
local function flagGet(id) return (F.r8(flagAddr(id)) & (1 << (id % 8))) ~= 0 end
local function flagSet(id) F.w8(flagAddr(id), F.r8(flagAddr(id)) | (1 << (id % 8))) end
local function flagClear(id) F.w8(flagAddr(id), F.r8(flagAddr(id)) & ~(1 << (id % 8)) & 0xFF) end

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

-- S4 has to un-latch the bit S3 latched. Clear-only: nothing in this suite ever wants to SET it by
-- hand -- S3's whole point is watching the game latch it -- and a settable version would be a dead
-- branch. The destination no longer corroborates this offset: hoennIntroDone controls only the
-- one-time arrival narration, while FLAG_BADGE01_GET independently controls the hub destination.
local function clearIntroDone()
  local a = F.sb2() + S.SaveBlock2.introDoneBits
  F.w8(a, F.r8(a) & ~(1 << HOENN_INTRO_DONE_BIT) & 0xFF)
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
-- The May segment's own one-line state dump. Deliberately a SECOND function rather than widening
-- state(): the male assertions' detail strings stay byte-identical to the runs the MANIFEST entry
-- quotes, so an A/B diff of this suite still shows only the lines that actually changed.
local function stateMay()
  return string.format("intro=%d housesMay=%d heal=%s arrival=%d introDone=%s",
    varGet(VAR_INTRO), varGet(VAR_HOUSES_MAY), healStr(),
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

-- Talk to the Hoenn attendant and answer YES, then wait for the gate's own destination. That
-- destination is a PARAMETER, not BRENDANS_2F: mashToMap presses A until the map matches, so a
-- female cross waiting on the male bedroom would mash its whole budget standing in May's and report
-- a walk failure for what is really a wrong-branch bug.
local function crossToHoenn(tag, dg, dm)
  if not F.route({ { HUB_ARRIVE[1], HUB_ARRIVE[2] }, { ATTENDANT_HOENN[1], HUB_ARRIVE[2] },
                   ATTENDANT_HOENN }, "walk_" .. tag) then
    return false
  end
  F.face("Up")
  F.press("A", 3); F.idle(50)
  if not yesNo(0, "travelHoenn_" .. tag) then F.shot(tag .. "_noyesno"); return false end
  -- TryGiveHubPass' give box (first cross only), then the gate's warp.
  return mashToMap(dg or BR2F_G, dm or BR2F_M, tag)
end

-- SELECT the registered HUB PASS and answer YES, ending in the hub. Registering to SELECT rather
-- than driving the BAG UI is the male segment's trick and its reasoning holds here too: the field
-- callback (ItemUseOutOfBattle_HubReturn) is the one the BAG's USE reaches, and a pocket cursor
-- cannot get lost. The confirm rests on NO by design (item_use.c: the warp is one-way).
local function hubPassOut(tag)
  F.w16(F.sb1() + S.SaveBlock1.registeredItem, hubPass)
  F.press("Select", 2); F.idle(90)
  if not yesNo(0, "hubPass_" .. tag) then F.shot(tag .. "_noconfirm"); return false end
  return mashToMap(HUB_G, HUB_M, "hubPass_" .. tag)
end

local function maleJourney()
  ------------------------------------------------------------------------------------------------
  -- Phase 0 — preconditions. A fresh save must really be a Hoenn first-timer, or S2 proves
  -- nothing and S1 cannot reach the bug at all.
  ------------------------------------------------------------------------------------------------
  if not F.boot(HUB_G) then F.check("boot", false, where()); return end
  booted = true
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
  if not crossed then F.shot("s2_lost"); return end
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
  for _, id in ipairs(bagAfter) do if not seen[id] then hubPass = id break end end
  F.check("S2 the gate handed over the HUB PASS", hubPass ~= nil,
    string.format("before=%d after=%d id=%s", #bagBefore, #bagAfter, tostring(hubPass)))
  if not hubPass then return end
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
  if not at6 then return end

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
  if not backInHub then F.shot("s1_pass_failed"); return end
  F.shot("s1_back_in_hub")
  F.check("S1 hoennIntroDone is still clear before the first outdoor arrival",
    not introDone(), state())

  local recrossed = crossToHoenn("recross")
  F.check("S1 re-cross landed in Brendan's 2F again", recrossed, where())
  if not recrossed then F.shot("s1_lost"); return end
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
  if not mapIs(BR1F_G, BR1F_M) then F.shot("s3_stairs"); return end
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
  if not mapIs(TOWN_G, TOWN_M) then F.shot("s3_door"); return end
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
  -- S3b — hoennIntroDone is only the one-time narration latch. With that bit set but the Stone
  -- Badge still clear, the gate must return to the bedroom, not skip the early campaign by landing
  -- in Slateport Harbor.
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
    F.check("S3b Stone Badge is still clear before the pre-badge crossing",
      not flagGet(FLAG_BADGE01_GET))
    local preBadgeHome = mashToMap(BR2F_G, BR2F_M, "return_prebadge", 150)
    F.shot("s3b_prebadge_destination")
    F.check("S3b intro-done without the Stone Badge still returns to Brendan's 2F",
      preBadgeHome, where() .. " harbor=(9,9)")

    ----------------------------------------------------------------------------------------------
    -- S3c — the first badge is the exact unlock. Change only that flag, return to the same
    -- attendant, and the destination must switch from the bedroom to Slateport Harbor.
    ----------------------------------------------------------------------------------------------
    local hub3 = preBadgeHome and hubPassOut("postbadge") or false
    F.check("S3c HUB PASS returned to the hub from the pre-badge bedroom", hub3, where())
    if hub3 then
      flagSet(FLAG_BADGE01_GET)
      F.check("S3c set the Hoenn Stone Badge", flagGet(FLAG_BADGE01_GET))
      local postBadgeHarbor = crossToHoenn("return_postbadge", HARB_G, HARB_M)
      F.shot("s3c_postbadge_destination")
      F.check("S3c the Stone Badge unlocks SLATEPORT HARBOR instead of the bedroom",
        postBadgeHarbor, where() .. " bedroom=(1,1)")
    end
  end
end

--------------------------------------------------------------------------------------------------
-- S4 / S5 — the SAME gate, the FEMALE branch.
--
-- `RegionHub_EventScript_FirstVisitHoennFemale` got the identical one-shot guard
-- (`call_if_eq VAR_LITTLEROOT_INTRO_STATE, 0` around `..._SeedFirstVisitHoennFemale`) and, before
-- this segment, nothing anywhere in the tree ran it. The female seed is a different script writing
-- different state — VAR_LITTLEROOT_HOUSES_STATE_MAY (0x4082) not ..._BRENDAN, a different six hide
-- flags, HEAL_LOCATION_LITTLEROOT_TOWN_MAYS_HOUSE_2F and a warp to May's 2F rather than Brendan's
-- — so every assertion above could stay green while the female half regressed.
--
-- Why it re-enters through forged state instead of a second fresh boot: one mGBA session gets one
-- new game. What "a Hoenn first-timer" means here is the persisted gender, intro state, houses
-- state, hoennIntroDone and first-badge flag plus the six hide flags, and every one of them is
-- written here in the open. Nothing about the JOURNEY is forged: the HUB PASS is used from the
-- field, the attendant is walked to and talked to, and the gate's own scripts pick the branch,
-- seed the state and place the warp. That is the part under test.
--
-- Where this starts is deliberately NOT assumed. On a fixed ROM the male journey ends in SLATEPORT
-- HARBOR (S3c); on an unfixed one it may end bailing out earlier. The HUB PASS is legal
-- in both (CannotUseHubReturnHere refuses only Safari, the bug contest, link rooms, the Frontier
-- facilities and an in-progress challenge, underwater, championship mode and an escorted NPC —
-- src/item_use.c) and lands on the same fixed hub tile either way, so S4 opens from wherever the
-- male journey happened to stop.
--------------------------------------------------------------------------------------------------
local function mayJourney()
  F.L("== S4/S5: the FEMALE branch of the same gate ==")
  if not hubPass then
    F.check("S4 the May segment inherited the HUB PASS the male segment derived", false,
      "the male segment never got one, so S4/S5 cannot drive the gate")
    return
  end

  -- Settle wherever the male journey left off before touching anything: on an unfixed ROM that is
  -- the tail of the mom-bounce cutscene, and a half-finished script eats the SELECT below.
  F.dismiss(20)

  F.w8(F.sb2() + S.SaveBlock2.playerGender, 1)   -- FEMALE
  varSet(VAR_INTRO, 0)
  varSet(VAR_HOUSES_MAY, 0)
  clearIntroDone()
  flagClear(FLAG_BADGE01_GET)
  for _, f in ipairs(MAY_SEED_FLAGS) do flagClear(f[1]) end

  F.check("S4 forged playerGender = FEMALE (the branch under test)",
    F.r8(F.sb2() + S.SaveBlock2.playerGender) == 1,
    "gender=" .. F.r8(F.sb2() + S.SaveBlock2.playerGender))
  F.check("S4 reset to a Hoenn first-timer: state 0, houses(MAY) 0, intro/narration and badge clear",
    varGet(VAR_INTRO) == 0 and varGet(VAR_HOUSES_MAY) == 0 and not introDone()
      and not flagGet(FLAG_BADGE01_GET), stateMay())
  local stillSet = {}
  for _, f in ipairs(MAY_SEED_FLAGS) do
    if flagGet(f[1]) then stillSet[#stillSet + 1] = f[2] end
  end
  local leftovers = table.concat(stillSet, ",")
  F.check("S4 cleared all six FEMALE seed flags first, so the flag checks below cannot pass on the "
          .. "MALE seed's leftovers (both TRUCK flags are in both seed lists)",
    #stillSet == 0, "still set: " .. (leftovers ~= "" and leftovers or "none"))

  ------------------------------------------------------------------------------------------------
  -- S4 — a genuine first visit as MAY must still be seeded. Same regression risk the guard creates
  -- on the male side, on the script that actually runs for a female save.
  ------------------------------------------------------------------------------------------------
  local inHub = hubPassOut("may_reset")
  F.check("S4 the HUB PASS returned MAY to the hub to start the female journey", inHub, where())
  if not inHub then F.shot("s4_no_hub"); return end

  local crossedMay = crossToHoenn("may_first", MAY2F_G, MAY2F_M)
  -- This one assertion is the whole gender branch: BRENDANS_HOUSE_2F and MAYS_HOUSE_2F are separate
  -- maps, so landing in (1,3) is only reachable through goto_if_eq VAR_RESULT, FEMALE.
  F.check("S4 first cross as MAY landed in MAY's 2F, so the gate took the FEMALE branch",
    crossedMay, where() .. " may=(1,3) brendan=(1,1) harbor=(9,9)")
  if not crossedMay then F.shot("s4_lost"); return end
  F.idle(120)
  F.shot("s4_may_first_arrival")

  -- May's 2F ON_TRANSITION calls the SAME shared PlayersHouse_2F_EventScript_BlockStairsUntilClock
  -- IsSet on state 4, so 4 is already 5 by the time anything can read it — identical to S2.
  F.check("S4 seed ran: intro state is 5 (seeded 4, May's 2F ON_TRANSITION advanced it)",
    varGet(VAR_INTRO) == 5, stateMay())
  F.check("S4 seed ran: VAR_LITTLEROOT_HOUSES_STATE_MAY is 1", varGet(VAR_HOUSES_MAY) == 1,
    stateMay())
  -- Same contract, mirrored: HEAL_LOCATION_LITTLEROOT_TOWN_MAYS_HOUSE_2F, and its `setrespawn`
  -- sits OUTSIDE the female guard exactly as the male one does. Reads the same on both ROMs.
  local hg, hm = healLoc()
  F.check("S4 the cross arms MAY's 2F respawn (contract, both ROMs)",
    hg == MAY2F_G and hm == MAY2F_M,
    string.format("heal=%s want=(%d,%d)", healStr(), MAY2F_G, MAY2F_M))
  for _, f in ipairs(MAY_SEED_FLAGS) do
    F.check("S4 seed ran: FLAG_HIDE_LITTLEROOT_TOWN_" .. f[2] .. " set", flagGet(f[1]))
  end

  ------------------------------------------------------------------------------------------------
  -- Reach state 6 the way the #195 player does. The two houses have their own sign scripts
  -- (LittlerootTown_{Brendans,Mays}House_2F_EventScript_WallClock, data/scripts/players_house.inc),
  -- but they only setvar VAR_0x8004 MALE/FEMALE before a shared goto: the branch that actually
  -- matters here, PlayersHouse_2F_EventScript_CheckWallClock -> ClockAlreadySetElsewhere, is one
  -- gender-agnostic script. So what differs for this segment is the sign's COORDINATE, because
  -- May's house is mirrored.
  ------------------------------------------------------------------------------------------------
  F.check("route to MAY's wall clock tile (3,2)", F.route(MAY_CLOCK_ROUTE, "clock_may"), where())
  F.face("Up")
  F.press("A", 3); F.idle(40)
  for _ = 1, 40 do F.press("A", 2); F.idle(16); F.press("B", 2); F.idle(16) end
  F.dismiss(20)
  F.shot("s5_after_clock_may")
  local mayAt6 = varGet(VAR_INTRO) == 6
  F.check("S5 clock-already-set branch advanced MAY's intro to 6", mayAt6, stateMay())
  if not mayAt6 then return end

  -- Same reason as S1: left at 1 an "unchanged" claim is indistinguishable from a rewind TO 1.
  varSet(VAR_HOUSES_MAY, 2)
  F.check("S5 staged VAR_LITTLEROOT_HOUSES_STATE_MAY = 2 (Met Rival's Mom)",
    varGet(VAR_HOUSES_MAY) == 2, stateMay())
  setHealLoc(PCEN_G, PCEN_M, 6, 8)
  F.check("S5 staged an OLDALE POKeMON CENTER respawn over MAY's bedroom",
    select(1, healLoc()) == PCEN_G and select(2, healLoc()) == PCEN_M, stateMay())
  F.check("S5 hoennIntroDone still clear (MAY never walked outside either)", not introDone(),
    stateMay())

  ------------------------------------------------------------------------------------------------
  -- S5 — HUB PASS out of MAY's bedroom, re-cross, nothing rewinds. The second discriminating phase.
  ------------------------------------------------------------------------------------------------
  local mayOut = hubPassOut("may_recross")
  F.check("S5 the HUB PASS warped MAY out of the bedroom to the hub", mayOut, where())
  if not mayOut then F.shot("s5_pass_failed"); return end
  F.shot("s5_back_in_hub")
  -- Weaker than its S1 twin, and worth saying so. S1 had EARNED its reading: the player really had
  -- crossed, and the bit's state was the game's answer. Here it only restates what S4 forged, and
  -- the female journey never enters Littleroot Town, so nothing on this path could set it. Keep it
  -- as a tripwire on the branch the gate is about to take -- not as evidence.
  F.check("S5 Hoenn's first badge is still clear, so the gate must return home",
    not flagGet(FLAG_BADGE01_GET), stateMay())

  local mayRecrossed = crossToHoenn("may_recross", MAY2F_G, MAY2F_M)
  F.check("S5 re-cross landed in MAY's 2F again", mayRecrossed, where())
  if not mayRecrossed then F.shot("s5_lost"); return end
  F.idle(120)
  F.shot("s5_after_recross")

  -- ---- the two assertions that fail on a ROM without the FEMALE guard --------------------------
  F.check("S5 intro state NOT rewound (still 6, not re-seeded to 4/5)", varGet(VAR_INTRO) == 6,
    stateMay())
  F.check("S5 VAR_LITTLEROOT_HOUSES_STATE_MAY NOT rewound to 1", varGet(VAR_HOUSES_MAY) == 2,
    stateMay())
  -- CONTRACT, not a discriminator — the female `setrespawn` is outside the guard too, so this reads
  -- (1,3)@(4,2) on both ROMs. It is worth asserting for the same reason S1's twin is: it is what
  -- catches someone "tidying" the setrespawn inside the guard and silently leaving a re-crossing
  -- player's respawn on whatever SetRegionArrivalRespawn armed.
  local rg, rm = healLoc()
  F.check("S5 CONTRACT (not a discriminator): the cross re-arms the respawn to MAY's 2F, so the "
          .. "stale cross-region POKeMON CENTER does not survive",
    rg == MAY2F_G and rm == MAY2F_M,
    string.format("heal=%s  want=(%d,%d) sentinel=(%d,%d)",
      healStr(), MAY2F_G, MAY2F_M, PCEN_G, PCEN_M))
end

-- One verdict for both halves of one fix. maleJourney() bails by RETURNING, not by finishing, so an
-- early exit up there still leaves S4/S5 a chance to report — and their absence from the count is
-- itself the signal that something went wrong before them.
F.run(function()
  maleJourney()
  if booted then mayJourney() end
  F.finish()
end)
