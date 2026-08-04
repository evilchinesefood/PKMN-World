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
--   C. The terminal's north door reaches VERMILION CITY (the one-way city link), and the pier's
--      ferry sailor sells the return leg back to OLIVINE — flipping the region back to JOHTO.
--      Note the state this runs in: VAR_MAP_SCENE_VERMILION_CITY is 0, because a Johto champion
--      arriving by sea has never touched Kanto's S.S.ANNE story. The return offer must not sit
--      behind that scene gate or the far shore is a trap too.
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

-- ---- flags/vars ------------------------------------------------------------------------------
-- Johto vars live in SaveBlock3.region.regionVars[id - REGION_VARS_START] (src/event_data.c:203);
-- Johto flags in SaveBlock3.region.johtoFlags[(id - FLAG_JOHTO_BASE) / 8] (:275). Neither is in
-- SaveBlock1, and SaveBlock3 is a fixed EWRAM symbol so it never relocates.
local REGION_VARS_START = 0xA000
local VAR_SSAQUA_STATE  = 0xA080 + 0x28  -- VAR_JOHTO_SLICE(0x28)
local FLAG_JOHTO_BASE   = 0x6000
local FLAG_HIDE_OLIVINE_PORT_OAK = 0x6000 + 0x0F

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
  local function giveSSTicket()
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
    F.spin(7, 2, 6)                                      -- id: 1 + 700 + 20 + 6 = 727
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
  local ticketSlot, keyPocket = -1, {}
  for _ = 1, 3 do
    giveSSTicket()
    ticketSlot, keyPocket = F.keyItemSlot(ITEM_SS_TICKET)
    if ticketSlot >= 0 then break end
    F.bOut(6); F.idle(60)
  end
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

  -- ============================================================ C. terminal -> city -> back
  -- The north door is the terminal's only city-side link; (8,9) is the warp tile itself, so
  -- stand one tile short and step onto it.
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
  F.check("C: landed on the pier at (24,32)", inCity and cx == 24 and cy == 32, ("(%d,%d)"):format(cx, cy))
  F.shot("vermilion_pier")

  if inCity then
    -- The landing tile has to be part of the city, not an island: walk north up the pier to
    -- where it meets the beach the S.S.ANNE dock shares, then come back for the return leg.
    F.check("C: the landing tile connects to the city on foot", F.route({ { 24, 28 } }, "upThePier"))
    F.check("C: walked back to the berth", F.route({ { 24, 32 } }, "downThePier"))
    -- The pier sailor is at (24,33), directly south. VAR_MAP_SCENE_VERMILION_CITY is 0 on this
    -- save (no Kanto story), which is precisely the case the S.S.ANNE scene gate used to swallow.
    F.face("Down")
    local home = talkUntilMap(GRP_OLIVINE_INDOOR, MAP_OLIVINE_PORT)
    F.check("C: pier sailor sails the return leg to OLIVINE CITY's port", home,
      ("grp=%d map=%d"):format(F.grp(), F.mapn()))
    F.check("B: active region is JOHTO after the return leg", activeRegion() == REGION_JOHTO,
      "region=" .. activeRegion())
    clearBox(10)
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

  local atPort = F.warpTo(0, 4, 3, 0, 0, 8, 0, 0, 0, GRP_VERM_INDOOR, MAP_VERM_PORT, "vermport")
  F.check("G: back in the KANTO terminal", atPort)
  if atPort then
    F.idle(90)
    F.step("Down")  -- the follower spawns hidden under the player and emerges on the first step
    F.check("G: the follower is out", followerOut(), describeFollower())
    F.check("G: reached the berth sailor", F.route({ { 8, 16 } }, "toBerthSailor"))
    F.face("Down")
    local sailed = talkUntilMap(GRP_OLIVINE_INDOOR, MAP_OLIVINE_PORT)
    F.check("G: the terminal's boarding cutscene sails to OLIVINE with a follower out", sailed,
      ("grp=%d map=%d"):format(F.grp(), F.mapn()))
    F.check("B: active region is JOHTO after the terminal crossing", activeRegion() == REGION_JOHTO,
      "region=" .. activeRegion())
    clearBox(10)
    F.check("G: control returns on the far shore", F.step("Down"))
    F.check("G: the follower came across too", followerOut(), describeFollower())
    F.shot("follower_crossing")
  end

  -- ============================================================ H. the event islands have two homes
  -- Opening the Olivine board made SOUTHERN / BIRTH / FARAWAY bookable from Johto, and their
  -- sailors all warped unconditionally to LILYCOVE — a Hoenn dock, reachable back to Johto only
  -- through the hub, which boxes the party. They now read the ACTIVE REGION as the departure
  -- record. Birth Island's harbour is the cheapest of the three to drive (one column, sailor two
  -- tiles from the warp). BOTH directions are asserted: the Hoenn leg is the no-regression half.
  local function sailHomeFrom(region, expectGrp, expectMap, tag)
    F.w32(S.gCurrentRegion, region)
    F.w8(F.sb2() + S.SaveBlock2.currentRegion, region)
    if not F.warpTo(0, 2, 6, 0, 5, 9, 0, 0, 0, GRP_EVENT_ISLANDS, MAP_BIRTH_HARBOR, tag) then
      return false
    end
    F.idle(90)
    if not F.route({ { 8, 4 } }, tag .. "ToSailor") then return false end
    F.face("Down")
    return talkUntilMap(expectGrp, expectMap)
  end

  F.check("H: a JOHTO-booked island trip sails home to OLIVINE, not Lilycove",
    sailHomeFrom(REGION_JOHTO, GRP_OLIVINE_INDOOR, MAP_OLIVINE_PORT, "islandJohto"),
    ("grp=%d map=%d"):format(F.grp(), F.mapn()))
  clearBox(10)
  F.check("H: a HOENN-booked one still sails home to LILYCOVE (no regression)",
    sailHomeFrom(REGION_HOENN, GRP_LILYCOVE_INDOOR, MAP_LILYCOVE_HARBOR, "islandHoenn"),
    ("grp=%d map=%d"):format(F.grp(), F.mapn()))
  F.shot("island_home")

  F.finish()
end)
