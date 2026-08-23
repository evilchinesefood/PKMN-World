-- SSAquaKantoCrossing.lua — issue #65: the real S.S.AQUA Kanto disembark.
--
-- What this proves, in one run, from a fresh new game with no fixture save:
--   0. The MAIDEN VOYAGE itself (issue #70). Every leg below starts from a voyage that has
--      ALREADY happened; this one drives the real boarding at Olivine from a pre-voyage save with
--      the S.S.TICKET in the bag. It is the site #67's warpsilent-without-waitstate assert
--      actually shipped on — five of that file's six warps were unreachable dead code and this is
--      the one on the live post-League path — and until now the fix was proved only BY SHAPE
--      against the repeat crossing, never by executing the site itself.
--   A. The docked ship is no longer a dead end. The 1F door sailor puts the player ashore in
--      MAP_VERMILION_CITY_PORT_INSIDE — a map that did not exist before this issue — and the
--      terminal's ON_FRAME arrival scene runs there and advances VAR_SSAQUA_STATE 6 -> 7.
--   B. The crossing sets the ACTIVE REGION. src/region_switch.c's INVARIANT says every
--      cross-region entry must go through SetCurrentRegion or ResyncCurrentRegionFromMap, and
--      the latter prefers the PERSISTED region — so a warp that skipped it would leave a Johto
--      champion carrying JOHTO's HARD VAR_DIFFICULTY tier into first-run Kanto. This is the one
--      failure mode that is completely invisible in-game, hence asserted on every leg.
--   C. The terminal's north door reaches VERMILION CITY and the city-side door walks back IN
--      (issue #68 — the terminal was arrival-only, so its whole population was one visit long),
--      and the berth sailor sells the return leg back to OLIVINE — flipping the region to JOHTO.
--      The pier sailor is asserted to HAND THAT OFF rather than sail it himself: his duplicate of
--      the leg only existed because the door did not. Note the state this runs in:
--      VAR_MAP_SCENE_VERMILION_CITY is 0, because a Johto champion arriving by sea has never
--      touched Kanto's S.S.ANNE story. His reply must not sit behind that scene gate, or the
--      handoff is a dead end and the far shore is a trap again.
--   D. VAR_SSAQUA_STATE >= 7 opens OlivinePort_EventScript_Sailor_AfterKanto's six-row harbour
--      menu, which was unreachable dead code before this issue, and its VERMILION row sails.
--   E. The second crossing does NOT re-run the arrival scene (the var stays 7, it is neither
--      re-advanced nor reset), which is what makes the menu permanent.
--   F. LILYCOVE CITY's harbour claims REGION_HOENN on arrival. It is the single way home from
--      every event-ticket island, and opening the Olivine menu is what made those islands
--      bookable from Johto in the first place — so that harbour became a cross-region entry.
--   G. The terminal's own boarding cutscene, driven with a FOLLOWER out. It is a fresh copy of
--      Olivine's, and Olivine's had never run in a shipped ROM (it ended its script mid-warp
--      and asserted), so `removeobject OBJ_EVENT_ID_PLAYER` + `SpawnCameraObject` had never
--      been executed with a second object tethered to the player.
--   I. (issue #80) The PERSISTED DEPARTURE RECORD, VAR_FERRY_DEPARTURE. Reading the active
--      region as the departure record cannot answer for a save whose SaveBlock2.currentRegion is
--      still REGION_NONE — ResyncCurrentRegionFromMap derives REGION_HOENN from the island's own
--      mapsec before the script runs, so a Johto player on an island is indistinguishable from a
--      Hoenn one. The record is written at the BOARDING sites instead. Every leg here forces the
--      active region to DISAGREE with the record, so a leg that landed on the right harbour by
--      way of the region probe would be indistinguishable from one that read the record — the
--      point of the segment is that they can no longer agree by accident. Segment H is the other
--      half: with the record cleared it re-proves the probe, which is still the answer for a save
--      that boarded before this var existed.
--
-- The OLIVINE arm also moved from the terminal's north DOOR (8,9) to its BERTH (8,16), matching
-- Vermilion's arm and both S.S.AQUA arrivals, so segment I asserts the landing COORDINATE and not
-- just the map.
--
-- Segment boundaries are debug warps so no message-box or movement state leaks between them.

package.path = (debug.getinfo(1, "S").source:sub(2):match("^(.*[/\\])") or "") .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(require("symbols"), "SSAquaKantoCrossing")

-- ---- map ids (include/constants/map_groups.h, MAP_X = (num | (group << 8))) -------------------
local GRP_SSAQUA,         MAP_SSAQUA_1F    = 95, 0
local GRP_VERM_INDOOR,    MAP_VERM_PORT    = 43, 8
local GRP_KANTO_TOWNS,    MAP_VERM_CITY    = 37, 5
local GRP_OLIVINE_INDOOR, MAP_OLIVINE_PORT = 88, 8
local GRP_LILYCOVE_INDOOR, MAP_LILYCOVE_HARBOR = 13, 10
local GRP_EVENT_ISLANDS, MAP_BIRTH_HARBOR = 26, 59
local MAP_FARAWAY_ENTRANCE = 56          -- MAP_FARAWAY_ISLAND_ENTRANCE = (56 | (26 << 8))

-- ---- flags/vars ------------------------------------------------------------------------------
-- Johto vars live in SaveBlock3.region.regionVars[id - REGION_VARS_START] (src/event_data.c:203);
-- Johto flags in SaveBlock3.region.johtoFlags[(id - FLAG_JOHTO_BASE) / 8] (:275). Neither is in
-- SaveBlock1, and SaveBlock3 is a fixed EWRAM symbol so it never relocates.
local REGION_VARS_START = 0xA000
local VAR_SSAQUA_STATE  = 0xA080 + 0x28  -- VAR_JOHTO_SLICE(0x28)
local FLAG_JOHTO_BASE   = 0x6000
local FLAG_HIDE_OLIVINE_PORT_OAK = 0x6000 + 0x0F

-- Issue #80. GLOBAL vars and flags, which live in SaveBlock1 rather than SaveBlock3 — a different
-- block from everything above, and a RELOCATING one, so the pointer is deref'd on every access.
-- Global vars: SaveBlock1.vars[id - VARS_START] (src/event_data.c:204). Global flags:
-- SaveBlock1.flags[id / 8], bit id % 8. VAR_FERRY_DEPARTURE is deliberately global and not a
-- region-slice var — include/constants/region_vars.h reserves the 0xA000 bank for per-region STORY
-- vars, and "which harbour did I sail from" is cross-region state by definition.
local VARS_START = 0x4000
local VAR_FERRY_DEPARTURE = 0x40FA               -- include/constants/vars.h (reclaimed VAR_UNUSED_0x40FA)
local FERRY_DEPART_UNSET     = 0                 -- include/constants/ferry.h
local FERRY_DEPART_LILYCOVE  = 1
local FERRY_DEPART_OLIVINE   = 2
local FERRY_DEPART_VERMILION = 3
-- include/constants/flags.h. SYSTEM_FLAGS is 0x948 (= TRAINER_FLAGS_END + 1); the two ids below it
-- are plain literals. Hardcoded with citations for the same reason VAR_SSAQUA_STATE above is:
-- GenLuaSymbols.py resolves LINKER symbols, and a #define never reaches the symbol table.
local FLAG_SYS_GAME_CLEAR              = 0x948 + 0x4
local FLAG_ENABLE_SHIP_BIRTH_ISLAND    = 0x948 + 0x75
local FLAG_SHOWN_AURORA_TICKET         = 0x1AF
local FLAG_HIDE_LILYCOVE_HARBOR_SSTIDAL = 0x35D
local FLAG_ENABLE_SHIP_FARAWAY_ISLAND  = 0x948 + 0x76
local FLAG_SHOWN_OLD_SEA_MAP           = 0x1B0
local ITEM_AURORA_TICKET = 730                   -- include/constants/items.h:892
local ITEM_OLD_SEA_MAP   = 731                   -- include/constants/items.h:893

-- enum Region (include/constants/regions.h)
local REGION_KANTO, REGION_JOHTO, REGION_HOENN = 1, 2, 3

local function regionVarAddr(id) return F.sb3() + S.SaveBlock3.regionVars + (id - REGION_VARS_START) * 2 end
local function regionVarSet(id, v) F.w16(regionVarAddr(id), v) end
local function regionVarGet(id) return F.r16(regionVarAddr(id)) end
local function johtoFlagSet(id, on)
  local a, m = F.sb3() + S.SaveBlock3.johtoFlags + ((id - FLAG_JOHTO_BASE) // 8), 1 << (id % 8)
  local v = F.r8(a)
  F.w8(a, on and (v | m) or (v & ~m & 0xFF))
end
local function activeRegion() return F.r8(F.sb2() + S.SaveBlock2.currentRegion) end

-- Issue #80's record. Not covered by the snapshot()/diffSnapshot() pair below, deliberately: that
-- diff spans SaveBlock1.FLAGS and the SaveBlock3 region-var bank, and this is a SaveBlock1 var —
-- so a segment that legitimately writes the record cannot trip the "no stray damage" assertion.
local function ferryDepartureAddr() return F.sb1() + S.SaveBlock1.vars + (VAR_FERRY_DEPARTURE - VARS_START) * 2 end
local function ferryDeparture() return F.r16(ferryDepartureAddr()) end
local function setFerryDeparture(v) F.w16(ferryDepartureAddr(), v) end
local function globalFlagSet(id, on)
  local a, m = F.sb1() + S.SaveBlock1.flags + (id // 8), 1 << (id % 8)
  local v = F.r8(a)
  F.w8(a, on and (v | m) or (v & ~m & 0xFF))
end

-- "No stray flag/var damage" made assertable. HG/SS ran a ~70-entry FLAGHEAP at this disembark
-- and the decision not to port it is the single riskiest judgement in the change, so the whole
-- SaveBlock1 flag array and the whole SaveBlock3 region-var array are snapshotted across the
-- crossing and diffed byte for byte. `flags` runs from its own offset up to `vars` (they are
-- adjacent fields), and regionVars is 3 banks x 128 vars x 2 bytes.
local FLAG_BYTES = S.SaveBlock1.vars - S.SaveBlock1.flags
local REGION_VAR_BYTES = 3 * 0x80 * 2
local function snapshot()
  local fb, rb = F.sb1() + S.SaveBlock1.flags, F.sb3() + S.SaveBlock3.regionVars
  local s = { flags = {}, vars = {} }
  for i = 0, FLAG_BYTES - 1 do s.flags[i] = F.r8(fb + i) end
  for i = 0, REGION_VAR_BYTES - 1 do s.vars[i] = F.r8(rb + i) end
  return s
end
-- Returns a list of changed byte offsets, so a failure names the flag/var rather than just
-- saying "something moved".
local function diffSnapshot(before, kind, base)
  local moved = {}
  local n = (kind == "flags") and FLAG_BYTES or REGION_VAR_BYTES
  for i = 0, n - 1 do
    local now = F.r8(base + i)
    if now ~= before[kind][i] then
      moved[#moved + 1] = string.format("byte %d: %02X->%02X", i, before[kind][i], now)
    end
  end
  return moved
end

-- ---- helpers ---------------------------------------------------------------------------------
-- Drive a ferry conversation to its destination map. A is the only key used: every Yes/No on
-- these legs defaults to YES and is the answer this suite wants, and every MSGBOX_DEFAULT in the
-- boarding cutscenes BLOCKS until a key closes it — a poll loop that pressed nothing would sit
-- in front of "We're departing soon" forever. Landing on the destination map is also the honest
-- assertion: frame counts drift with the cutscene, the save block does not.
local function talkUntilMap(grp, map, tries)
  for _ = 1, (tries or 260) do
    if F.grp() == grp and F.mapn() == map then F.idle(60); return true end
    F.press("A", 2); F.idle(20)
  end
  return F.grp() == grp and F.mapn() == map
end

-- The follower object. `active` is not `visible`: a pocketed follower stays in gObjectEvents
-- parked on its last tile with the invisible bit set, so an active-only check reads a hidden
-- follower as still on the map (the trap HubIntroTourFollower.lua documents).
local OBJ_EVENT_ID_FOLLOWER = 0xFE
local function follower()
  for i = 0, 15 do
    local b = S.gObjectEvents + i * S.ObjectEvent.stride
    if (F.r8(b) & 1) == 1 and F.r8(b + S.ObjectEvent.localId) == OBJ_EVENT_ID_FOLLOWER then
      return { x = F.rs16(b + S.ObjectEvent.x) - 7, y = F.rs16(b + S.ObjectEvent.y) - 7,
               invisible = (F.r8(b + S.ObjectEvent.flags1) & 0x20) ~= 0 }
    end
  end
  return nil
end
local function followerOut() local o = follower(); return o ~= nil and not o.invisible end
local function describeFollower()
  local o = follower()
  if not o then return "ABSENT" end
  return string.format("(%d,%d) %s", o.x, o.y, o.invisible and "invisible" or "visible")
end

-- Close whatever box is open, B-only (A would re-open the NPC the player is still facing).
-- lib's dismiss() cannot be used inside either port: it proves freedom with a Left/Right step
-- and both berth corridors are ONE tile wide, so it always reports stuck.
local function clearBox(n)
  for _ = 1, (n or 20) do F.press("B", 2); F.idle(30) end
end

F.run(function()
  if not F.boot(100) then F.check("boot", false); F.finish(); return end

  -- ============================================================ 0. the MAIDEN VOYAGE at OLIVINE
  -- Issue #70. Everything after this segment seeds VAR_SSAQUA_STATE and debug-warps aboard, i.e.
  -- starts from a maiden voyage that has already happened. This drives the real one:
  -- OlivinePort_EventScript_Sailor -> OlivinePort_EventScript_Sailor_MaidenVoyage
  -- (data/maps/OlivineCity_PortInside/scripts.inc:109 and :225).
  --
  -- It is the leg that matters most. #67 found the shipped-ROM assert on exactly this script:
  -- `warpsilent MAP_SSAQUA_1F, 29, 3` ended it while Task_WarpAndLoadMap was still live, tripping
  -- StopScript's assertf ("Leaving script while a warp is in progress", src/script.c:79). Five of
  -- the six warps in that file were unreachable dead code; this one is on the live post-League
  -- path the story sends every new Johto champion down. Segment D's repeat crossing runs the
  -- identical call/warpsilent/waitstate shape and is asserted — but that proves the fix BY SHAPE.
  -- This site had never been executed by a test at all.
  --
  -- The constants below are declared here rather than in the shared block at the top of the file
  -- so this segment is one contiguous, independently-editable hunk.
  local VAR_NEWBARKTOWN_LABSTATE = 0xA080 + 0x01  -- VAR_JOHTO_SLICE(0x01), include/constants/johto_vars.h:13
  -- Hardcoded with its citation, exactly as VAR_SSAQUA_STATE above is. Testing/GenLuaSymbols.py
  -- resolves LINKER symbols out of `arm-none-eabi-nm -S` on the ELF, and `enum Item` members are
  -- compile-time constants that never reach the symbol table — a WANT entry for one fails the
  -- build with "symbol not found". DebugParty.lua hardcodes SPECIES_WOBBUFFET for the same reason.
  local ITEM_SS_TICKET = 727                      -- include/constants/items.h:889
  local MAIN_VBLANK_COUNTER1 = 0x20               -- gMain.vblankCounter1, include/main.h:22

  -- The bag, through the debug give-item spinner: root row 3 = "Give X…" (src/debug.c:740), then
  -- submenu row 0 = "Give item XYZ…" (src/debug.c:645), then the id and quantity fields.
  --
  -- ★ The arithmetic is NOT the warp spinners'. F.spin(h,t,o) (lib.lua:230) parks on the hundreds
  -- digit and presses Down SIX times to floor the field before building the number back up, and
  -- Debug_HandleInput_Numeric clamps at `min` (src/debug.c:969). The warp spinners pass min = 0
  -- (src/debug.c:1458, :1499), so spin(h,t,o) is exactly 100h+10t+o there — which is why every
  -- other call in this file reads literally. The item-id field passes min = 1 (src/debug.c:2698)
  -- and starts at 1 (:2667), so the floor lands on ONE and the field ends at 1 + 100h + 10t + o.
  -- Reaching ITEM_SS_TICKET = 727 therefore needs spin(7, 2, 6); spin(7, 2, 7) would hand over
  -- item 728, and the sailor would answer OlivinePort_Text_NoTicket instead of sailing.
  --
  -- Parameterised on the three digits (it was hardcoded to the S.S.TICKET's until issue #80 needed
  -- an AURORA TICKET in segment I as well); everything else about it, including the retry wrapper
  -- below, is unchanged.
  local function giveKeyItemViaDebug(h, t, o)
    F.dbg(); F.idle(60)
    -- lib's sel() taps Down for 2 frames with an 8-frame gap; press slower (DebugParty.lua:56).
    -- NOT for DebugParty's reason, though — its nine Downs cross the list window's bottom edge and
    -- the scrolling press is the fragile one. The root menu is 11 rows against
    -- DEBUG_MENU_HEIGHT_MAIN = 9 (src/debug.c:176), so row 3 is always already on screen and
    -- nothing scrolls here. The slower tap is just the cheaper of two habits; the retry below is
    -- what actually makes this reliable.
    for _ = 1, 3 do F.press("Down", 3); F.idle(16) end   -- root row 3 = "Give X…"
    F.press("A", 3); F.idle(60)
    F.press("A", 3); F.idle(60)                          -- Give row 0 = "Give item XYZ…"
    F.spin(h, t, o)                                      -- id: 1 + 100h + 10t + o
    -- Quantity: tInput is reset to 1 on the id's A press (src/debug.c:2710) and this field clamps
    -- at min = 1 too, so a bare A takes the single ticket the script needs. AddBagItem then runs
    -- and DebugAction_DestroyExtraWindow closes the whole menu and unfreezes the player
    -- (src/debug.c:1029); the bOut is only insurance against a spinner press that got eaten.
    F.press("A", 2); F.idle(60)
    F.bOut(4); F.idle(60)
  end

  -- Retried, the way lib's warpTo retries (lib.lua:240-249). Every other debug-menu driver in this
  -- file sits in an attempt loop because a dropped press is an expected event, and this one has the
  -- nastiest failure mode of them all: if F.dbg() does not open the menu, the three Downs walk the
  -- player three tiles across the hub and spin()'s Right/Down/Up run walks him twenty more while
  -- mashing A at whatever he passes. The bag read below is the retry condition as well as the
  -- assertion, so a bad pass costs one retry instead of poisoning every segment underneath.
  local function giveKeyItem(itemId, h, t, o)
    local slot, pocket = -1, {}
    for _ = 1, 3 do
      giveKeyItemViaDebug(h, t, o)
      slot, pocket = F.keyItemSlot(itemId)
      if slot >= 0 then break end
      F.bOut(6); F.idle(60)
    end
    return slot, pocket
  end
  local ticketSlot, keyPocket = giveKeyItem(ITEM_SS_TICKET, 7, 2, 6)
  -- Presence needs no decryption key. An item slot is {u16 id, u16 quantity} and ONLY the quantity
  -- is XORed against SaveBlock2.encryptionKey (src/item.c:66-72), so the id this reads is the same
  -- plaintext id `checkitem` compares. Asserting it BEFORE the conversation matters: a mis-spun id
  -- would otherwise surface as an unexplained "the sailor did not sail".
  F.check("0: the S.S.TICKET reached the KEY ITEMS pocket", ticketSlot >= 0,
    ("slot=%d pocket=[%s]"):format(ticketSlot, table.concat(keyPocket, ",")))

  -- The three seeds, all BEFORE the warp — a hide flag is only read when the map loader rebuilds
  -- the object set.
  --   * VAR_NEWBARKTOWN_LABSTATE >= 11 is the A1 gate the script checks (scripts.inc:115): the
  --     maiden voyage is Johto's post-League beat, and Norman's Hoenn ticket must not launch it
  --     mid-Johto. Below 11 the sailor takes the NotSailingYet branch and nothing is tested.
  --   * VAR_SSAQUA_STATE = 0 is already the fresh-save value; written anyway so this segment
  --     states its own precondition instead of inheriting one.
  --   * PROF. OAK stands at (8,16) — the exact tile the player must occupy to face the sailor at
  --     (8,17) — until his National-Dex scene runs, and on a fresh save it has not.
  regionVarSet(VAR_NEWBARKTOWN_LABSTATE, 11)
  regionVarSet(VAR_SSAQUA_STATE, 0)
  johtoFlagSet(FLAG_HIDE_OLIVINE_PORT_OAK, true)

  F.check("0: OLIVINE port entered on a pre-voyage save",
    F.warpTo(0, 8, 8, 0, 0, 8, 0, 0, 0, GRP_OLIVINE_INDOOR, MAP_OLIVINE_PORT, "olivineMaiden"))
  F.idle(90)
  F.check("0: reached the harbour sailor on OAK's (now hidden) tile",
    F.route({ { 8, 16 } }, "toMaidenSailor"))
  F.face("Down")
  -- Segment B's invariant applied to this leg. Every other leg asserts an EXPECTED region because
  -- it crosses one; boarding does not cross anything — the ship is still Johto's side of the water
  -- and the flip happens on the disembark at Vermilion. So the honest assertion is that the region
  -- is UNCHANGED, captured rather than hardcoded — and captured is not just tidier, it is the only
  -- form that works. A fresh new game reaches Olivine's port with SaveBlock2.currentRegion still
  -- 0 (UNSET), because the hub boot never claims a region and Olivine's port has no ON_TRANSITION
  -- to claim one; asserting the plausible-looking REGION_JOHTO here goes red on a green build.
  -- It is worth making at all because MaidenVoyage is the only
  -- boarding script in this file with no `callnative RegionHub_ScrSetCurrentRegion` (Vermilion's
  -- has one at scripts.inc:166), so if a future edit adds a stray region claim to the one path
  -- that must not have one, nothing else in the suite would notice.
  local regionBeforeBoarding = activeRegion()
  -- Issue #80's record, sampled on a genuinely untouched save. This is the only point in the suite
  -- that sees one: the slot VAR_FERRY_DEPARTURE reclaimed was VAR_UNUSED_0x40FA, which nothing in
  -- the tree ever wrote, so FERRY_DEPART_UNSET here is the state every PRE-#80 save is in — and
  -- "unset falls through to the old region probe" is the entire compatibility story for those
  -- saves. Asserted, not assumed, because if the slot were not actually free this would be the
  -- read that noticed.
  local departBefore = ferryDeparture()

  -- talkUntilMap is the right driver here for the same two reasons it is everywhere else: the
  -- MSGBOX_YESNO defaults to YES, which is the answer this leg wants, and A is the only key it
  -- presses; and OlivinePort_EventScript_EnterShip (scripts.inc:242) contains a blocking
  -- MSGBOX_DEFAULT ("We're departing soon.\nPlease get on board."), so a poll loop that pressed
  -- nothing would sit in front of it forever.
  local boarded = talkUntilMap(GRP_SSAQUA, MAP_SSAQUA_1F)
  F.check("0: the maiden voyage boards and lands the player on the S.S.AQUA", boarded,
    ("grp=%d map=%d pos=(%d,%d)"):format(F.grp(), F.mapn(), F.pos()))

  -- ★ The "no assert screen" probe is NOT gMain.callback2, and getting that wrong would have made
  -- this whole segment vacuous. AssertfCrashScreen (src/assertf.c:436) never touches callback2: it
  -- sets REG_IME = 0 and busy-loops on REG_VCOUNT waiting for START, INSIDE CB2_Overworld's own
  -- call stack (Overworld -> ScriptContext_RunScript -> StopScript -> assertf). So F.ow() reads
  -- CB2_Overworld with the crash screen on screen, and would PASS against precisely the build this
  -- segment exists to fail. Measured, not reasoned: against a build with this leg's `waitstate`
  -- deleted, F.ow() read TRUE and F.cb2() read CB2_Overworld exactly, while the probe below went
  -- red. What does stop is the main loop: with interrupts off VBlankIntr never runs, so
  -- gMain.vblankCounter1 (src/main.c:364, zeroed only by InitMainCallbacks at boot) freezes.
  -- Nothing may press Start between the boarding and this probe — the screen is RESUMABLE and
  -- Start dismisses it, restoring REG_IME (src/assertf.c:430) and letting the counter tick again.
  -- The park-ashore warp at the end of the segment DOES press Start, via lib's dbg() (lib.lua:224);
  -- that is deliberate and safe only because every crash-sensitive check has already been recorded
  -- by then. Any new check added after that warp would be reading a resumed game.
  local function mainLoopAlive()
    local v0 = F.r32(S.gMain + MAIN_VBLANK_COUNTER1)
    F.idle(30)
    local v1 = F.r32(S.gMain + MAIN_VBLANK_COUNTER1)
    return v1 ~= v0, ("gMain.vblankCounter1 %d -> %d across 30 frames"):format(v0, v1)
  end
  F.check("0: the boarding leaves no assert screen (the main loop is still running)",
    mainLoopAlive())

  F.check("B: boarding at OLIVINE does not change the active region",
    activeRegion() == regionBeforeBoarding,
    ("region=%d (was %d)"):format(activeRegion(), regionBeforeBoarding))

  -- Issue #80, the WRITE side, on the real script rather than a forged var. This is the maiden
  -- voyage's own OlivinePort_EventScript_EnterShip — the shared boarding helper every row of the
  -- Olivine board calls, including the three island rows — so proving it records OLIVINE here
  -- proves it for the island trips too, without having to drive a board that is not open yet.
  -- Paired with the pre-boarding read so the assertion is a TRANSITION, not a value that might
  -- have been sitting there all along.
  F.check("0: the departure record was UNSET on a fresh save", departBefore == FERRY_DEPART_UNSET,
    "VAR_FERRY_DEPARTURE=" .. departBefore)
  F.check("0: boarding at OLIVINE records OLIVINE as the departure harbour",
    ferryDeparture() == FERRY_DEPART_OLIVINE, "VAR_FERRY_DEPARTURE=" .. ferryDeparture())

  -- A state-transition witness, NOT a crash witness — and the difference is worth naming, because
  -- this is the one check in the segment that a broken build still passes. `setvar VAR_SSAQUA_STATE,
  -- 1` is scripts.inc:228, nine lines ABOVE the warpsilent, so it has already run by the time the
  -- assert fires. (That is exactly why the waitstate-deleted build scores 43/46 and not 42/46.) The
  -- crash witnesses are the landing check, the vblankCounter1 probe and the step below; do not let
  -- a future trim leave this one standing alone.
  F.check("0: the maiden voyage set VAR_SSAQUA_STATE to 1", regionVarGet(VAR_SSAQUA_STATE) == 1,
    "state=" .. regionVarGet(VAR_SSAQUA_STATE))
  clearBox(6)
  -- Control, proved DOWNWARD. The script lands the player at (29,3): (29,2) is the door sailor and
  -- (29,1) is the ship's exit warp, so Up is blocked, and Left/Right — which is all F.ensureFree()
  -- ever presses — is the one-tile corridor wall. Segment A walks this same column.
  --
  -- ★ ONE tile, deliberately, and this is the only place in the file where that matters.
  -- SSAqua_1F carries trigger coord_events at (28,8) and (29,8) gated on VAR_SSAQUA_STATE == 1
  -- (data/maps/SSAqua_1F/map.json) -> SSAqua_1F_Trigger_Grandpa, which locks, drives the player
  -- with applymovement, advances the var to 2 and writes three Johto flags. State 1 is precisely
  -- what the maiden voyage just set, so this segment is the ONLY one that ever runs with those
  -- triggers armed — every other segment forces 6 or 7 first. (29,4) is four tiles short of them,
  -- so nothing fires; but a future edit that walks this column further, or reuses F.route here,
  -- would hand the rest of the suite a moving player and a changed var.
  F.check("0: control returns aboard, with no lock left behind", F.step("Down"))
  F.shot("maiden_voyage")

  -- ★ Hand over to segment A cleanly. The maiden voyage leaves the player ON MAP_SSAQUA_1F, and
  -- segment A's very next act is a warpTo the same map — whose success test is group+map ONLY
  -- (lib.lua:245). Called while already standing there it reports true having warped nobody, and
  -- worse, leaves the debug menu OPEN, which then silently eats every key press that follows. So
  -- step ashore first. Olivine's port is the honest place to park: its map script table is empty
  -- (`OlivineCity_PortInside_MapScripts:: .byte 0`), so arriving there runs nothing that could
  -- colour what comes next, and this is where the ferry would have put the player anyway.
  F.check("0: parked ashore so segment A's boarding warp really warps",
    F.warpTo(0, 8, 8, 0, 0, 8, 0, 0, 0, GRP_OLIVINE_INDOOR, MAP_OLIVINE_PORT, "backAshore"))

  -- ============================================================ A. the disembark
  -- State 6 = "docked in VERMILION, announcement given". That is exactly where a player who
  -- finished the maiden voyage stands, and it is the state the old stopgap dead-ended in.
  regionVarSet(VAR_SSAQUA_STATE, 6)
  -- Warp 1 (the player's cabin door at (19,9)), NOT warp 0. Warp 0 is the ship's exit at (29,1):
  -- a north-arrow warp, so it is collision-blocked but still walks you through, and the ONLY
  -- thing keeping a player off it is the door sailor standing at (29,2). Warping in materialises
  -- the player ON that tile — sharing it with the sailor — and the first Up press then rides the
  -- exit straight back to Olivine, testing nothing. Boarding at the cabin door and walking the
  -- corridor reproduces the real approach.
  F.check("A: warped aboard the S.S.AQUA",
    F.warpTo(0, 9, 5, 0, 0, 0, 0, 0, 1, GRP_SSAQUA, MAP_SSAQUA_1F, "ssaqua"))
  F.idle(90)
  F.L(string.format("  aboard at (%d,%d)", F.pos()))

  F.check("A: walked the corridor to the door sailor", F.route({ { 29, 9 }, { 29, 3 } }, "toDoorSailor"))
  F.face("Up")

  -- Stand in for an ESTABLISHED save: give the Kanto bank a distinctive pattern so a memset or a
  -- mis-based flagheap write shows up as a diff rather than as zeroes-onto-zeroes. The badges are
  -- the sharpest probe available — FLAG_KANTO_BADGE(i) sits in the free head gap at
  -- FLAG_KANTO_BASE+0x0B (include/constants/region_flags.h), one byte below where a mechanical
  -- HG/SS port would have aimed FLAG_BADGE09_GET.
  for i = 0, 7 do
    local id = 0xA40 + 0x0B + i
    local a = F.sb1() + S.SaveBlock1.flags + (id // 8)
    F.w8(a, F.r8(a) | (1 << (id % 8)))
  end
  local before = snapshot()

  local landed = talkUntilMap(GRP_VERM_INDOOR, MAP_VERM_PORT)
  F.check("A: door sailor puts the player ashore in MAP_VERMILION_CITY_PORT_INSIDE", landed,
    ("grp=%d map=%d"):format(F.grp(), F.mapn()))
  if not landed then F.shot("no_vermilion_port"); F.finish(); return end

  clearBox(20)
  F.shot("vermilion_port")
  F.check("A: arrival scene advanced VAR_SSAQUA_STATE to 7", regionVarGet(VAR_SSAQUA_STATE) == 7,
    "state=" .. regionVarGet(VAR_SSAQUA_STATE))
  F.check("B: active region is KANTO after the crossing", activeRegion() == REGION_KANTO,
    "region=" .. activeRegion())

  -- The flagheap decision, asserted. Nothing in SaveBlock1's flag array may move across the
  -- disembark, and the ONLY region var that may move is VAR_SSAQUA_STATE 6 -> 7 — bytes 336/337,
  -- = (0xA0A8 - 0xA000) * 2. Anything else is the stray damage the issue forbids.
  local SSAQUA_VAR_BYTE = (VAR_SSAQUA_STATE - REGION_VARS_START) * 2
  local flagMoves = diffSnapshot(before, "flags", F.sb1() + S.SaveBlock1.flags)
  F.check("A: the disembark writes no SaveBlock1 flag at all", #flagMoves == 0,
    table.concat(flagMoves, "; "))
  local varMoves = diffSnapshot(before, "vars", F.sb3() + S.SaveBlock3.regionVars)
  local onlySSAqua = true
  for _, m in ipairs(varMoves) do
    local off = tonumber(m:match("byte (%d+)"))
    if off ~= SSAQUA_VAR_BYTE and off ~= SSAQUA_VAR_BYTE + 1 then onlySSAqua = false end
  end
  F.check("A: the only region var it writes is VAR_SSAQUA_STATE", onlySSAqua,
    table.concat(varMoves, "; "))

  -- Freedom proof for a one-tile corridor: a real step, not lib's Left/Right probe.
  F.check("A: control returns in the terminal", F.step("Up"))

  -- ============================================================ C. terminal -> city -> back in
  -- The north door is the terminal's city-side link; (8,9) is MB_NON_ANIMATED_DOOR with collision
  -- 0, so it is the warp tile itself — stand one tile short and step onto it.
  F.check("C: walked up to the terminal door", F.route({ { 8, 10 } }, "toPortDoor"))
  F.step("Up")
  local inCity = false
  for _ = 1, 400 do
    if F.grp() == GRP_KANTO_TOWNS and F.mapn() == MAP_VERM_CITY then inCity = true; break end
    F.idle(10)
  end
  F.idle(60)
  local cx, cy = F.pos()
  F.check("C: terminal door reaches VERMILION CITY", inCity, ("grp=%d map=%d"):format(F.grp(), F.mapn()))
  -- Issue #68 moved warp 10 off the inert plank at (24,32) and onto a real door:
  -- METATILE_VermilionCity_Door at (26,29), the front of the port building now standing on the
  -- pier's north edge. That makes the exit a door animation — Task_ExitDoor puts the player on
  -- the door tile and walks them one step SOUTH — so the landing tile is the apron below it.
  F.check("C: landed on the port apron at (26,30)", inCity and cx == 26 and cy == 30,
    ("(%d,%d)"):format(cx, cy))
  F.shot("vermilion_pier")

  if inCity then
    -- The landing tile has to be part of the CITY, not an island, and the walk has to leave the
    -- pier to prove it: east along the deck to the foot of the ramp at x=36, up the ramp and off
    -- the quay onto grass at (36,19). That route is also the invariant the blockdata edit rests
    -- on — the terminal narrows the deck to the single row y=30 across x=25..28, so this is the
    -- only lane left between the ramp and the S.S.ANNE walkway, and a stamp one row lower would
    -- have severed the harbour from the city with nothing else noticing.
    F.check("C: the landing tile connects to the city on foot",
      F.route({ { 36, 30 }, { 36, 19 } }, "upThePier"))
    F.check("C: walked back down to the berth",
      F.route({ { 36, 30 }, { 24, 30 }, { 24, 32 } }, "downThePier"))
    -- The pier sailor is at (24,33), directly south. VAR_MAP_SCENE_VERMILION_CITY is 0 on this
    -- save (no Kanto story), which is precisely the case the S.S.ANNE scene gate used to swallow.
    -- He used to sell this crossing himself; #68 retired that duplicate, so the assertion flips:
    -- he must NOT sail, and he must still ANSWER and hand control back. All three halves are
    -- needed — a sailor who swallowed the A press without opening a box, or one who opened a box
    -- and never released, would each satisfy "did not sail" on their own.
    --
    -- Drive it with ONE A and then B only. A blind burst of A presses cannot work here: A both
    -- advances the box and re-opens the conversation the player is still facing, so the burst
    -- always ends mid-message no matter how long it is. B advances without re-opening, and a
    -- coordinate-verified step is the honest "is the box gone yet" probe — it costs nothing when
    -- it fails and lands the first tile of the walk back when it succeeds.
    F.face("Down")
    F.press("A", 2); F.idle(40)
    local talked = not F.step("Up")
    local freed = false
    for _ = 1, 40 do
      F.press("B", 2); F.idle(30)
      if F.step("Up") then freed = true; break end
    end
    F.check("C: the pier sailor hands the crossing off instead of sailing it",
      F.grp() == GRP_KANTO_TOWNS and F.mapn() == MAP_VERM_CITY,
      ("grp=%d map=%d"):format(F.grp(), F.mapn()))
    F.check("C: the pier sailor still answers (a box opened)", talked)
    F.check("C: and hands control back rather than dead-ending", freed)

    -- The headline of #68: the door is two-way. Walk back to the apron and north into it. Two
    -- waypoints, not one: route() is a greedy x-then-y walk, so leaving the berth eastwards first
    -- would try (25,32), which is elevation-1 water beside the walkway — the step is refused, so
    -- leg() reports BLOCKED rather than the player swimming off. Climb the walkway, then go east.
    F.check("C: walked back to the port door", F.route({ { 24, 30 }, { 26, 30 } }, "toCityPortDoor"))
    F.step("Up")
    local backInside = false
    for _ = 1, 400 do
      if F.grp() == GRP_VERM_INDOOR and F.mapn() == MAP_VERM_PORT then backInside = true; break end
      F.idle(10)
    end
    F.idle(60)
    F.check("C: the city-side door walks back into the terminal", backInside,
      ("grp=%d map=%d"):format(F.grp(), F.mapn()))
    F.shot("port_door_reentry")

    if backInside then
      -- ...so the hall's population is no longer one visit long, and the return leg is booked at
      -- the berth that has a gangway and a boat to show for it.
      F.check("C: the berth sailor is reachable on a return visit",
        F.route({ { 8, 16 } }, "toBerthSailorC"))

      -- That reachability is exactly why the berth sailor gained a VAR_SSAQUA_STATE >= 7 gate in
      -- #68. While this hall was arrival-only, standing in front of this desk already IMPLIED
      -- having crossed, so an ungated offer could not be reached early. The door removes the
      -- implication — RegionHub_EventScript_ReturnKanto lands returning visitors on
      -- MAP_VERMILION_CITY warp 0 at (22,34), a short walk from the apron — and an early sail
      -- would be one-way: it flips the active region and the whiteout to JOHTO, while
      -- OlivinePort_EventScript_Sailor refuses below 7 and there is no ship back. Drop the var
      -- under the gate and prove the desk declines without moving the player off this map.
      regionVarSet(VAR_SSAQUA_STATE, 6)
      F.face("Down")
      F.press("A", 2); F.idle(40)
      local declined = false
      for _ = 1, 40 do
        F.press("B", 2); F.idle(30)
        if F.step("Up") then declined = true; break end   -- vertical: the berth is one tile wide
      end
      F.check("C: below the gate the berth sailor declines and does not sail",
        declined and F.grp() == GRP_VERM_INDOOR and F.mapn() == MAP_VERM_PORT,
        ("freed=%s grp=%d map=%d"):format(tostring(declined), F.grp(), F.mapn()))
      regionVarSet(VAR_SSAQUA_STATE, 7)
      F.check("C: back at the berth sailor with the gate open",
        F.route({ { 8, 16 } }, "toBerthSailorC2"))

      F.face("Down")
      local home = talkUntilMap(GRP_OLIVINE_INDOOR, MAP_OLIVINE_PORT)
      F.check("C: the terminal desk sails the return leg to OLIVINE CITY's port", home,
        ("grp=%d map=%d"):format(F.grp(), F.mapn()))
      F.check("B: active region is JOHTO after the return leg", activeRegion() == REGION_JOHTO,
        "region=" .. activeRegion())
      clearBox(10)
    end
  end

  -- ============================================================ D. the >= 7 harbour menu
  -- PROF.OAK stands at (8,16) in the one-tile berth corridor until his National-Dex scene runs,
  -- and on a fresh save that scene has not happened — he would block the walk to the sailor.
  -- Hiding him is seeding the story state this menu already assumes, not faking the subject.
  -- Set BEFORE the warp: the hide flag is only read when the map loader rebuilds the object set.
  johtoFlagSet(FLAG_HIDE_OLIVINE_PORT_OAK, true)
  -- Re-enter clean rather than relying on where the return leg left things.
  F.check("D: OLIVINE port re-entered clean",
    F.warpTo(0, 8, 8, 0, 0, 8, 0, 0, 0, GRP_OLIVINE_INDOOR, MAP_OLIVINE_PORT, "olivineport"))
  F.idle(90)
  F.check("D: VAR_SSAQUA_STATE still 7 (arrival scene is one-shot)", regionVarGet(VAR_SSAQUA_STATE) == 7,
    "state=" .. regionVarGet(VAR_SSAQUA_STATE))

  F.check("D: reached the OLIVINE harbour sailor", F.route({ { 8, 16 } }, "toOlivineSailor"))
  F.face("Down")
  -- Wait on sMenu's ROW COUNT, never on lib's menuLive() here. menuLive() probes by pressing
  -- Down, and this board is `message` + `waitmessage` + `multichoice`: the window only opens
  -- once "Where would you like to sail?" has finished typing, so the probe lands mid-typewriter,
  -- reads a stale sMenu, and the A press that follows it arrives after the window IS up — which
  -- selects row 0 and sails the ferry while the suite still believes no menu ever appeared.
  -- maxCursorPos == 5 is unambiguous here: every earlier menu in this run is a 2-row Yes/No.
  local function boardRows() return F.rs8(S.sMenu + S.Menu.maxCursorPos) end
  F.press("A", 2); F.idle(45)   -- open the conversation
  local live = false
  for _ = 1, 14 do
    if boardRows() == 5 then live = true; break end
    F.press("A", 2); F.idle(35)
  end
  F.check("D: the six-row AfterKanto destination board opens", live, "maxCursorPos=" .. boardRows())
  F.shot("olivine_menu")
  if live then
    -- No Down presses at all: the board opens on row 0, which is VERMILION.
    F.check("D: the cursor rests on VERMILION", F.mcur() == 0, "cursor=" .. F.mcur())
    F.press("A", 2); F.idle(45)
    local back = talkUntilMap(GRP_VERM_INDOOR, MAP_VERM_PORT)
    F.check("D: the VERMILION run sails and lands in the KANTO terminal", back,
      ("grp=%d map=%d"):format(F.grp(), F.mapn()))
    F.check("E: repeat crossing left VAR_SSAQUA_STATE at 7", regionVarGet(VAR_SSAQUA_STATE) == 7,
      "state=" .. regionVarGet(VAR_SSAQUA_STATE))
    F.check("B: active region is KANTO again", activeRegion() == REGION_KANTO,
      "region=" .. activeRegion())
    clearBox(10)
    F.check("D: control returns after the repeat crossing", F.step("Up"))
    F.shot("second_crossing")
  end

  -- ============================================================ F. the event-island way home
  -- Opening the Olivine harbour menu makes SOUTHERN / BIRTH / FARAWAY / NAVEL ROCK bookable
  -- from Johto, and all four sail home to MAP_LILYCOVE_CITY_HARBOR — mainland Hoenn. Its
  -- ON_TRANSITION now claims REGION_HOENN so that arrival cannot carry a Johto tier into Hoenn.
  -- Forge the "arrived from Johto" state: gCurrentRegion is the EWRAM mirror the guard reads,
  -- SaveBlock2.currentRegion is the persisted value ResyncCurrentRegionFromMap re-seeds it from,
  -- so both have to say JOHTO or the warp simply restores the one we did not write.
  F.w32(S.gCurrentRegion, REGION_JOHTO)
  F.w8(F.sb2() + S.SaveBlock2.currentRegion, REGION_JOHTO)
  local atHarbor = F.warpTo(0, 1, 3, 0, 1, 0, 0, 0, 0, GRP_LILYCOVE_INDOOR, MAP_LILYCOVE_HARBOR, "lilycoveharbor")
  F.check("F: reached LILYCOVE CITY's harbor as a Johto-region player", atHarbor)
  if atHarbor then
    F.idle(90)
    F.check("F: arriving there claims REGION_HOENN (persisted)",
      F.r8(F.sb2() + S.SaveBlock2.currentRegion) == REGION_HOENN,
      "region=" .. F.r8(F.sb2() + S.SaveBlock2.currentRegion))
    F.check("F: and the EWRAM mirror agrees", F.r32(S.gCurrentRegion) == REGION_HOENN,
      "gCurrentRegion=" .. F.r32(S.gCurrentRegion))
    -- The callnative pair runs in ON_TRANSITION, which is the risk: a script that faults or
    -- never ends there leaves the map loaded with the player locked.
    F.check("F: control returns after the ON_TRANSITION region claim", F.ensureFree())
    F.shot("lilycove_harbor")
  end

  -- ============================================================ G. the terminal's own cutscene,
  -- with a FOLLOWER out. VermilionPort_EventScript_EnterShip is a fresh copy of Olivine's
  -- boarding cutscene, and Olivine's had never actually run in a shipped ROM (it ended its
  -- script mid-warp and asserted), so neither has been driven with a follower. The hazard is
  -- specific: the cutscene calls `removeobject OBJ_EVENT_ID_PLAYER` and `SpawnCameraObject`
  -- while a second object is tethered to the player.
  F.dbg(); F.idle(60)
  for _ = 1, 2 do F.press("Down", 3); F.idle(16) end   -- root row 2 = "Party…"
  F.press("A", 3); F.idle(60)
  for _ = 1, 9 do F.press("Down", 3); F.idle(16) end   -- row 9 = "Set Party" (sDebugMenu_Actions_Party)
  F.press("A", 3); F.idle(180)
  F.bOut(4); F.idle(60)
  F.check("G: debug party published a count", F.r8(S.gPartiesCount) > 0,
    "count=" .. F.r8(S.gPartiesCount))

  -- The debug warp lands in the CITY, not the terminal, and the terminal is entered on foot.
  -- This used to be F.warpTo(GRP_VERM_INDOOR, MAP_VERM_PORT, warp 0) — a stand-in for the door
  -- issue #68 added, and the only way back in while the terminal was arrival-only. Warp 10 IS
  -- that door now, so the warp puts the player on the apron in front of it and the rest is walked.
  --
  -- ★ The warp-id spinner is NOT three digits, unlike the group and map ones above it.
  -- DebugAction_Util_Warp_SelectWarp (src/debug.c) handles only DPAD_UP/DOWN and never touches
  -- tDigit, so Left/Right are dead keys there and every Up is worth exactly 1 (clamped at 10).
  -- spin()'s three counts therefore just SUM on this field: (0,1,0) selects warp 1, not warp 10 —
  -- and warpTo() cannot catch that, because its success test is group+map only and warp 1 is on
  -- the same map. Hence (0,0,10), and hence the landing tile is asserted below rather than trusted.
  local onPier = F.warpTo(0, 3, 7, 0, 0, 5, 0, 0, 10, GRP_KANTO_TOWNS, MAP_VERM_CITY, "vermpier")
  F.idle(90)  -- warp 10 is a door, so let Task_ExitDoor finish walking the player out first
  local gx, gy = F.pos()
  F.check("G: back on the VERMILION port apron at (26,30)", onPier and gx == 26 and gy == 30,
    ("(%d,%d)"):format(gx, gy))
  local atPort = false
  if onPier and gx == 26 and gy == 30 then
    -- The follower spawns hidden under the player and emerges on the first step. Step SIDEWAYS
    -- here: the apron's south neighbour (26,31) is the pier's water lip and its north neighbour
    -- is the door itself, so a vertical step is either a no-op or an early warp.
    F.step("Left")
    F.check("G: the follower is out", followerOut(), describeFollower())
    F.check("G: walked back to the port door", F.route({ { 26, 30 } }, "toPortDoorG"))
    F.step("Up")
    for _ = 1, 400 do
      if F.grp() == GRP_VERM_INDOOR and F.mapn() == MAP_VERM_PORT then atPort = true; break end
      F.idle(10)
    end
    F.idle(90)
  end
  F.check("G: walked in through the city-side door to the KANTO terminal", atPort,
    ("grp=%d map=%d"):format(F.grp(), F.mapn()))
  if atPort then
    F.step("Down")  -- re-emerge the follower on this side of the door before reading it
    F.check("G: the follower came through the door too", followerOut(), describeFollower())
    F.check("G: reached the berth sailor", F.route({ { 8, 16 } }, "toBerthSailor"))
    F.face("Down")
    local sailed = talkUntilMap(GRP_OLIVINE_INDOOR, MAP_OLIVINE_PORT)
    F.check("G: the terminal's boarding cutscene sails to OLIVINE with a follower out", sailed,
      ("grp=%d map=%d"):format(F.grp(), F.mapn()))
    F.check("B: active region is JOHTO after the terminal crossing", activeRegion() == REGION_JOHTO,
      "region=" .. activeRegion())
    clearBox(10)
    -- Step NORTH, not south. Since #152 this arm lands on the BERTH (8,16) like every other
    -- scripted arrival, instead of the terminal's north door (8,9). The berth sailor is an
    -- unflagged, always-present object at (8,17), so "Down" is permanently blocked here and
    -- would report stuck no matter what the crossing did. (8,15) is the open corridor tile.
    -- This still discriminates: if the cutscene never gave control back, no direction moves.
    F.check("G: control returns on the far shore", F.step("Up"))
    F.check("G: the follower came across too", followerOut(), describeFollower())
    F.shot("follower_crossing")
  end

  -- ============================================================ H. the event islands have two homes
  -- Opening the Olivine board made SOUTHERN / BIRTH / FARAWAY bookable from Johto, and their
  -- sailors all warped unconditionally to LILYCOVE — a Hoenn dock, reachable back to Johto only
  -- through the hub, which boxes the party. They read the ACTIVE REGION as the departure record.
  -- Birth Island's harbour is the cheapest of the three to drive (one column, sailor two tiles
  -- from the warp). BOTH directions are asserted: the Hoenn leg is the no-regression half.
  --
  -- SINCE ISSUE #80 THIS SEGMENT IS THE FALLBACK PROOF, and the explicit setFerryDeparture(UNSET)
  -- below is what makes it one. VAR_FERRY_DEPARTURE now takes precedence over the region probe,
  -- and segment 0's real Olivine boarding has ALREADY written OLIVINE into it — so without the
  -- clear, every leg here would sail to Olivine on the record and the region argument would never
  -- be consulted, quietly turning eight assertions into eight copies of one. Clearing it restores
  -- exactly the pre-#80 decision path, which is not merely a way to keep these tests meaningful:
  -- it IS the behaviour a save that boarded before the var existed still gets, and the reason #80
  -- could ship without a migration. Segment I is the other half, with the record set.
  local recordOnIsland
  local function sailHomeFrom(region, expectGrp, expectMap, tag)
    setFerryDeparture(FERRY_DEPART_UNSET)
    F.w32(S.gCurrentRegion, region)
    F.w8(F.sb2() + S.SaveBlock2.currentRegion, region)
    if not F.warpTo(0, 2, 6, 0, 5, 9, 0, 0, 0, GRP_EVENT_ISLANDS, MAP_BIRTH_HARBOR, tag) then
      return false
    end
    F.idle(90)
    recordOnIsland = ferryDeparture()
    if not F.route({ { 8, 4 } }, tag .. "ToSailor") then return false end
    F.face("Down")
    return talkUntilMap(expectGrp, expectMap)
  end

  -- The premise of the whole segment, made checkable rather than left implicit, and asserted ONCE
  -- PER LEG: these legs are only testing the region probe if the #80 record really is unset when
  -- the sailor is asked. Sampled on the island, after the warp, for the same reason `onIsland`
  -- below is — a read taken before the warp would be reading back the harness's own write.
  local function checkProbeReallyDecided(leg)
    F.check("H: the #80 record was UNSET on the " .. leg .. " leg, so the probe decided it",
      recordOnIsland == FERRY_DEPART_UNSET, "VAR_FERRY_DEPARTURE=" .. tostring(recordOnIsland))
  end

  F.check("H: a JOHTO-booked island trip sails home to OLIVINE, not Lilycove",
    sailHomeFrom(REGION_JOHTO, GRP_OLIVINE_INDOOR, MAP_OLIVINE_PORT, "islandJohto"),
    ("grp=%d map=%d"):format(F.grp(), F.mapn()))
  checkProbeReallyDecided("BIRTH ISLAND Johto")
  clearBox(10)
  F.check("H: a HOENN-booked one still sails home to LILYCOVE (no regression)",
    sailHomeFrom(REGION_HOENN, GRP_LILYCOVE_INDOOR, MAP_LILYCOVE_HARBOR, "islandHoenn"),
    ("grp=%d map=%d"):format(F.grp(), F.mapn()))
  checkProbeReallyDecided("BIRTH ISLAND Hoenn")
  F.shot("island_home")

  -- Issue #69: NAVEL ROCK was the fourth island and the only one still carrying a private
  -- `warp MAP_LILYCOVE_CITY_HARBOR` instead of the shared script. Be precise about what this
  -- leg proves: there are TWO Navel Rock harbours. This one, MAP_NAVEL_ROCK_HARBOR, is the
  -- REGION_HOENN map reachable only from LILYCOVE; KANTO's MYSTIC TICKET run sails to
  -- MAP_NAVEL_ROCK_HARBOR_FRLG, a different map whose own sailor already returns to VERMILION.
  -- So the HOENN direction is the one a player can actually book, and it is asserted first as
  -- the no-regression half. JOHTO and KANTO assert the shared script's two other arms, the
  -- KANTO one being a floor under a Kanto-side island row that does not exist yet.
  -- Same LAYOUT_ISLAND_HARBOR as Birth Island's — warp 0 at (8,2), sailor at (8,5) — so the
  -- same two-tile walk drives it. MAP_NAVEL_ROCK_HARBOR = (67 | (26 << 8)), map_groups.h.
  local MAP_NAVEL_HARBOR = 67
  -- Sampled AFTER the warp onto the island but BEFORE the sailor is asked for a way home. This
  -- is the discriminating read of the three: MAP_NAVEL_ROCK_HARBOR is itself a REGION_HOENN map
  -- with a Hoenn mapsec, and ResyncCurrentRegionFromMap runs on that warp. It is only because it
  -- prefers the PERSISTED SaveBlock2.currentRegion over the map that a departure record exists at
  -- all by the time the sailor reads it — if that preference ever flipped, gCurrentRegion would
  -- read HOENN here and every leg would sail to Lilycove no matter where it was booked. Reading
  -- the mirror rather than the persisted byte matters too: gCurrentRegion is what the guard
  -- actually compares (src/region_switch.c's RegionHub_ScrTargetIsCurrent), and it is the one the
  -- engine rewrote on the warp rather than the one this harness set.
  local onIsland
  local function sailHomeFromNavelRock(region, expectGrp, expectMap, tag)
    -- Both writes, for the reason segment F states: gCurrentRegion is the EWRAM mirror the
    -- guard reads, SaveBlock2.currentRegion is what ResyncCurrentRegionFromMap re-seeds it
    -- from on the warp, so writing one alone is undone by the other.
    setFerryDeparture(FERRY_DEPART_UNSET)   -- fallback path only; see the segment note above
    F.w32(S.gCurrentRegion, region)
    F.w8(F.sb2() + S.SaveBlock2.currentRegion, region)
    if not F.warpTo(0, 2, 6, 0, 6, 7, 0, 0, 0, GRP_EVENT_ISLANDS, MAP_NAVEL_HARBOR, tag) then
      return false
    end
    F.idle(90)
    onIsland = F.r32(S.gCurrentRegion)
    recordOnIsland = ferryDeparture()
    if not F.route({ { 8, 4 } }, tag .. "ToSailor") then return false end
    F.face("Down")
    return talkUntilMap(expectGrp, expectMap)
  end

  F.check("H: a HOENN-booked NAVEL ROCK trip still sails home to LILYCOVE (no regression)",
    sailHomeFromNavelRock(REGION_HOENN, GRP_LILYCOVE_INDOOR, MAP_LILYCOVE_HARBOR, "navelHoenn"),
    ("grp=%d map=%d"):format(F.grp(), F.mapn()))
  F.check("H: the HOENN booking survived the warp onto the island", onIsland == REGION_HOENN,
    "gCurrentRegion=" .. tostring(onIsland))
  checkProbeReallyDecided("NAVEL ROCK Hoenn")
  clearBox(10)

  F.check("H: a JOHTO-booked NAVEL ROCK trip sails home to OLIVINE",
    sailHomeFromNavelRock(REGION_JOHTO, GRP_OLIVINE_INDOOR, MAP_OLIVINE_PORT, "navelJohto"),
    ("grp=%d map=%d"):format(F.grp(), F.mapn()))
  F.check("H: the JOHTO booking survived the warp onto a REGION_HOENN island map",
    onIsland == REGION_JOHTO, "gCurrentRegion=" .. tostring(onIsland))
  checkProbeReallyDecided("NAVEL ROCK Johto")
  clearBox(10)

  -- The KANTO arm lands on the berth tile (8,16) INSIDE the terminal, not on the pier, so it
  -- misses VermilionCity_EventScript_ExitedTicketCheck's coord events at (22,32)/(23,32).
  F.check("H: a KANTO-booked NAVEL ROCK trip sails home to VERMILION's terminal",
    sailHomeFromNavelRock(REGION_KANTO, GRP_VERM_INDOOR, MAP_VERM_PORT, "navelKanto"),
    ("grp=%d map=%d"):format(F.grp(), F.mapn()))
  F.check("H: the KANTO booking survived the warp onto a REGION_HOENN island map",
    onIsland == REGION_KANTO, "gCurrentRegion=" .. tostring(onIsland))
  checkProbeReallyDecided("NAVEL ROCK Kanto")
  -- "The arrival scene did not run" asserted by POSITION, not by the var. The var is already 7
  -- and the scene would set it to 7 again, so reading it back proves nothing either way — but
  -- VermilionCity_PortInside_EventScript_Arrived opens with an applymovement that walks the
  -- player one tile north off the berth. Still standing on (8,16) is the observable difference.
  local kx, ky = F.pos()
  F.check("H: the KANTO arm landed on the berth tile and the arrival scene did not run",
    kx == 8 and ky == 16, ("(%d,%d) state=%d"):format(kx, ky, regionVarGet(VAR_SSAQUA_STATE)))
  clearBox(10)
  F.check("H: control returns in the KANTO terminal after the island run", F.step("Up"))
  F.shot("navelrock_home")

  -- ==================================================== I. the persisted DEPARTURE RECORD (#80)
  -- Segment H proves the region probe. This proves the thing that overrides it, and proves it by
  -- CONTRADICTION: every leg sets VAR_FERRY_DEPARTURE to one harbour and the active region to a
  -- DIFFERENT one, so the two possible decision paths give different answers and the landing map
  -- says which one ran. A leg that merely agreed with the region would pass on the pre-#80 ROM and
  -- prove nothing — that is the failure mode this shape exists to avoid.
  --
  -- The contradiction is also the point of the issue. A save whose SaveBlock2.currentRegion is
  -- still REGION_NONE reaches this script with gCurrentRegion reading REGION_HOENN, because
  -- ResyncCurrentRegionFromMap derived it from the island's own mapsec on the warp in
  -- (src/region_switch.c, include/regions.h — GetRegionForSectionId ends `return REGION_HOENN;`).
  -- Such a save is byte-identical, at the moment of decision, to a genuine Hoenn player. So the
  -- "record says OLIVINE, region says HOENN" leg below is not a contrived state: it is exactly the
  -- state a legacy Johto player who booked at Olivine arrives in, and pre-#80 it sailed them to
  -- Lilycove.
  local landedRecord
  local function sailHomeWithRecord(record, region, expectGrp, expectMap, tag)
    setFerryDeparture(record)
    F.w32(S.gCurrentRegion, region)
    F.w8(F.sb2() + S.SaveBlock2.currentRegion, region)
    if not F.warpTo(0, 2, 6, 0, 5, 9, 0, 0, 0, GRP_EVENT_ISLANDS, MAP_BIRTH_HARBOR, tag) then
      return false
    end
    F.idle(90)
    -- Read back ON the island. SaveBlock1 relocates and the warp re-seeds gCurrentRegion from the
    -- persisted byte; the record has to survive both, or the "written at boarding, read at the
    -- island" design does not hold at all.
    landedRecord = ferryDeparture()
    if not F.route({ { 8, 4 } }, tag .. "ToSailor") then return false end
    F.face("Down")
    return talkUntilMap(expectGrp, expectMap)
  end

  F.check("I: an OLIVINE record beats a HOENN active region (the REGION_NONE legacy save's state)",
    sailHomeWithRecord(FERRY_DEPART_OLIVINE, REGION_HOENN, GRP_OLIVINE_INDOOR, MAP_OLIVINE_PORT,
      "recordOlivine"),
    ("grp=%d map=%d"):format(F.grp(), F.mapn()))
  F.check("I: the record survived the warp onto the island",
    landedRecord == FERRY_DEPART_OLIVINE, "VAR_FERRY_DEPARTURE=" .. tostring(landedRecord))
  -- The other half of #80: this arm used to warp to (8,9), the terminal's north DOOR, while the
  -- Kanto arm warped to (8,16), the BERTH. Both port-inside maps are the same 18x28 layout with a
  -- ONE-TILE corridor at x=8 running y=15..17, so (8,16) is the berth on both and (8,9) is the
  -- door on both. Asserting the coordinate is the only way to see this: the map id is identical
  -- either way. PROF. OAK's spawn tile is this same (8,16), but he stands in that one-tile
  -- corridor — segment 0 could not reach the sailor past him without hiding him — so no save that
  -- can book an island trip still has him on it.
  local ox, oy = F.pos()
  F.check("I: the OLIVINE arm lands on the BERTH (8,16), not the north door (8,9)",
    ox == 8 and oy == 16, ("(%d,%d)"):format(ox, oy))
  F.shot("olivine_berth_landing")
  -- Olivine's port has no ON_FRAME or ON_TRANSITION map script at all (its MapScripts is a bare
  -- `.byte 0`), unlike Vermilion's — so unlike the Kanto arm there is nothing here that could walk
  -- the player off the tile, and nothing that could leave him locked. Proved by stepping.
  clearBox(10)
  F.check("I: control returns on the OLIVINE berth", F.step("Up"))

  F.check("I: a LILYCOVE record beats a JOHTO active region",
    sailHomeWithRecord(FERRY_DEPART_LILYCOVE, REGION_JOHTO, GRP_LILYCOVE_INDOOR, MAP_LILYCOVE_HARBOR,
      "recordLilycove"),
    ("grp=%d map=%d"):format(F.grp(), F.mapn()))
  clearBox(10)

  -- The KANTO arm has no departure site writing it today (no Kanto-side island row exists), so
  -- this is the only thing that can keep it honest. It is the arm #72 added as a floor under a
  -- future row; the row's author writes FERRY_DEPART_VERMILION at their boarding site and this
  -- leg is what says the return already works.
  F.check("I: a VERMILION record beats a HOENN active region",
    sailHomeWithRecord(FERRY_DEPART_VERMILION, REGION_HOENN, GRP_VERM_INDOOR, MAP_VERM_PORT,
      "recordVermilion"),
    ("grp=%d map=%d"):format(F.grp(), F.mapn()))
  local vx, vy = F.pos()
  F.check("I: the VERMILION arm lands on its berth (8,16) too — the two arms now match",
    vx == 8 and vy == 16, ("(%d,%d)"):format(vx, vy))
  clearBox(10)

  -- ---- the LILYCOVE write site, driven for real, and a full round trip -------------------------
  -- Everything above forges the record. This drives the script that is supposed to write it, from
  -- the other harbour, and then sails the resulting trip home — so the write and the read are
  -- proved as one journey rather than as two halves that happen to agree on a constant.
  --
  -- Preconditions for LilycoveCity_Harbor_EventScript_FerryAttendant to reach the AURORA row:
  --   FLAG_SYS_GAME_CLEAR              — the whole conversation sits behind it (scripts.inc:37)
  --   FLAG_ENABLE_SHIP_BIRTH_ISLAND + ITEM_AURORA_TICKET — GetAuroraTicketState wants both
  --   FLAG_SHOWN_AURORA_TICKET clear   — makes VAR_TEMP_D 2 rather than 1, i.e. the FIRST-TIME
  --     branch, which is the one with NO multichoice to steer: with the Aurora ticket as the only
  --     event ticket in the bag VAR_TEMP_B is exactly 2, so the attendant jumps straight to it and
  --     the leg is a linear msgbox/cutscene/warp that talkUntilMap can drive end to end. (Segment
  --     0's S.S.TICKET is item 727, none of the four event tickets, so it does not perturb this.)
  --   FLAG_HIDE_LILYCOVE_HARBOR_SSTIDAL clear — new_game.inc:188 SETS it and hall_of_fame.inc:17
  --     clears it, so on this fresh save the ferry object the boarding cutscene applymovements
  --     (Common_EventScript_FerryDepart, via VAR_0x8004) is not spawned. Clearing it is part of
  --     the same post-game state FLAG_SYS_GAME_CLEAR above stands for, not a fudge.
  --
  -- That branch boards through LilycoveCity_Harbor_EventScript_BoardFerryWithSailor, which is the
  -- write site easiest to miss: it is a SEPARATE helper from BoardFerry rather than a wrapper
  -- around it, so a fix that patched only the obvious one would leave every first-time event
  -- ticket with no departure record. This leg is what would catch that.
  globalFlagSet(FLAG_SYS_GAME_CLEAR, true)
  globalFlagSet(FLAG_ENABLE_SHIP_BIRTH_ISLAND, true)
  globalFlagSet(FLAG_SHOWN_AURORA_TICKET, false)
  globalFlagSet(FLAG_HIDE_LILYCOVE_HARBOR_SSTIDAL, false)
  local auroraSlot, auroraPocket = giveKeyItem(ITEM_AURORA_TICKET, 7, 2, 9) -- 1 + 700 + 20 + 9 = 730
  F.check("I: the AURORA TICKET reached the KEY ITEMS pocket", auroraSlot >= 0,
    ("slot=%d pocket=[%s]"):format(auroraSlot, table.concat(auroraPocket, ",")))

  local atLily = F.warpTo(0, 1, 3, 0, 1, 0, 0, 0, 0, GRP_LILYCOVE_INDOOR, MAP_LILYCOVE_HARBOR,
    "lilycoveBoard")
  F.check("I: LILYCOVE harbour re-entered to board for real", atLily,
    ("grp=%d map=%d"):format(F.grp(), F.mapn()))
  if atLily then
    F.idle(90)
    -- Clear the record FIRST, so whatever it reads afterwards is unambiguously the boarding's
    -- doing and not a leftover from the forged legs above.
    setFerryDeparture(FERRY_DEPART_UNSET)
    -- Then force the active region to JOHTO — AFTER the warp, because this harbour's ON_TRANSITION
    -- has just claimed HOENN (segment F asserts exactly that) and would otherwise overwrite it.
    -- Boarding does not re-run an ON_TRANSITION, so the write sticks across the trip. With the
    -- region saying JOHTO, a probe-driven return would land at OLIVINE; landing back at LILYCOVE
    -- can then only be the record talking.
    F.w32(S.gCurrentRegion, REGION_JOHTO)
    F.w8(F.sb2() + S.SaveBlock2.currentRegion, REGION_JOHTO)
    -- Warp 0 puts the player at (11,14); the attendant stands at (8,10) and the tile below her is
    -- (8,11), which is also where the sail-home arm lands. Two waypoints because lib's leg() is
    -- greedy axis-first, not a pathfinder: walk the bottom row west first, then straight up the
    -- open column. LAYOUT_HARBOR's y=10 row is blocked at x=3..6, so the corner cannot be cut.
    F.check("I: walked to the LILYCOVE ferry attendant",
      F.route({ { 8, 14 }, { 8, 11 } }, "toLilyAttendant"))
    F.face("Up")
    local sailedOut = talkUntilMap(GRP_EVENT_ISLANDS, MAP_BIRTH_HARBOR)
    F.check("I: the LILYCOVE first-time AURORA boarding sails to BIRTH ISLAND", sailedOut,
      ("grp=%d map=%d"):format(F.grp(), F.mapn()))
    if sailedOut then
      F.idle(60)
      -- Guarded with the rest: a boarding that never happened makes this read meaningless, and an
      -- unguarded copy would post a second, misleading failure beside the real one.
      F.check("I: BoardFerryWithSailor recorded LILYCOVE as the departure harbour",
        ferryDeparture() == FERRY_DEPART_LILYCOVE, "VAR_FERRY_DEPARTURE=" .. ferryDeparture())
      F.check("I: the JOHTO region forge survived the crossing, so the probe would say OLIVINE",
        F.r32(S.gCurrentRegion) == REGION_JOHTO, "gCurrentRegion=" .. F.r32(S.gCurrentRegion))
      F.check("I: walked to the BIRTH ISLAND sailor", F.route({ { 8, 4 } }, "lilyRoundTripSailor"))
      F.face("Down")
      local home = talkUntilMap(GRP_LILYCOVE_INDOOR, MAP_LILYCOVE_HARBOR)
      F.check("I: the round trip returns to LILYCOVE, the harbour it was actually booked at", home,
        ("grp=%d map=%d"):format(F.grp(), F.mapn()))
      -- The arm CONSUMES the record, so the var's lifetime is one voyage. That is a floor rather
      -- than a behaviour: every route to the reader passes a writer today, so nothing currently
      -- depends on it. What it buys is that a future island route added without a boarding write
      -- degrades to the region probe instead of reading a stale harbour — which would be worse
      -- than the pre-#80 answer, because a stale non-zero record suppresses the probe entirely.
      F.check("I: arriving home consumed the record, so no stale harbour can outlive the voyage",
        ferryDeparture() == FERRY_DEPART_UNSET, "VAR_FERRY_DEPARTURE=" .. ferryDeparture())
      F.shot("lilycove_round_trip")
      clearBox(10)
    end
  end

  -- ---- the OLD SEA MAP site, the fourth writer, on the only route that reaches it --------------
  -- The third Lilycove write site calls NEITHER named helper: it boards inline with Briney's
  -- cutscene. Everything else in this segment would still pass if that setvar were dropped, which
  -- makes it exactly the line a future refactor can delete unnoticed — so it gets its own leg.
  --
  -- It is also not a rare alternative but the ONLY way a first FARAWAY ISLAND trip ever happens.
  -- The attendant tests `goto_if_eq VAR_TEMP_C, 2` (OLD SEA MAP) at scripts.inc:44, BEFORE the
  -- `goto_if_eq VAR_TEMP_B, 4` at :47 that also means "old sea map, first time" — so :47 is
  -- unreachable and every such trip goes through this path. Pre-existing, and left alone.
  --
  -- The AURORA TICKET from the leg above stays in the bag on purpose: its FLAG_SHOWN_AURORA_TICKET
  -- is now set, so VAR_TEMP_D is 1 rather than 2 and it contributes nothing to VAR_TEMP_B. The
  -- OLD SEA MAP is therefore the only FIRST-TIME ticket, and :44 fires unambiguously.
  --
  -- ITEM_OLD_SEA_MAP is 731 (include/constants/items.h:893), so the id field needs spin(7, 3, 0):
  -- it clamps at min = 1 and builds 1 + 700 + 30 + 0. NOT spin(7, 3, 1), which would hand over 732.
  globalFlagSet(FLAG_ENABLE_SHIP_FARAWAY_ISLAND, true)
  globalFlagSet(FLAG_SHOWN_OLD_SEA_MAP, false)
  local seaMapSlot, seaMapPocket = giveKeyItem(ITEM_OLD_SEA_MAP, 7, 3, 0)
  F.check("I: the OLD SEA MAP reached the KEY ITEMS pocket", seaMapSlot >= 0,
    ("slot=%d pocket=[%s]"):format(seaMapSlot, table.concat(seaMapPocket, ",")))

  local atLily2 = F.warpTo(0, 1, 3, 0, 1, 0, 0, 0, 0, GRP_LILYCOVE_INDOOR, MAP_LILYCOVE_HARBOR,
    "lilycoveSeaMap")
  F.check("I: LILYCOVE harbour re-entered for the OLD SEA MAP row", atLily2,
    ("grp=%d map=%d"):format(F.grp(), F.mapn()))
  if atLily2 then
    F.idle(90)
    setFerryDeparture(FERRY_DEPART_UNSET)
    -- Same contradiction as the AURORA leg, and for the same reason: forge JOHTO after the warp,
    -- since this harbour's ON_TRANSITION has just claimed HOENN.
    F.w32(S.gCurrentRegion, REGION_JOHTO)
    F.w8(F.sb2() + S.SaveBlock2.currentRegion, REGION_JOHTO)
    -- Approach from directly below and face Up. The Briney cutscene branches on VAR_FACING
    -- (`call_if_eq VAR_FACING, DIR_NORTH/DIR_EAST`), so the tile the player talks from decides
    -- which half of it runs; north is the half this leg drives.
    F.check("I: walked to the attendant for the OLD SEA MAP row",
      F.route({ { 8, 14 }, { 8, 11 } }, "toSeaMapAttendant"))
    F.face("Up")
    local seaMapSailed = talkUntilMap(GRP_EVENT_ISLANDS, MAP_FARAWAY_ENTRANCE, 400)
    F.check("I: the OLD SEA MAP row boards inline with Briney and sails to FARAWAY ISLAND",
      seaMapSailed, ("grp=%d map=%d"):format(F.grp(), F.mapn()))
    if seaMapSailed then
      F.check("I: the inline Briney boarding recorded LILYCOVE too",
        ferryDeparture() == FERRY_DEPART_LILYCOVE, "VAR_FERRY_DEPARTURE=" .. ferryDeparture())
      F.shot("faraway_old_sea_map")
    end
  end

  F.finish()
end)
