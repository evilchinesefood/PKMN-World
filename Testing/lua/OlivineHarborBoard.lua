-- OlivineHarborBoard.lua — issue #79: the BATTLE FRONTIER row carries a credential.
--
-- OlivinePort_EventScript_ChoseBattleFrontier was the one row on the OLIVINE harbour board with no
-- gate of any kind: the three island rows above it each do `checkitem` + `goto_if_unset
-- FLAG_ENABLE_SHIP_*`, and this one went straight to `call OlivinePort_EventScript_EnterShip`. So
-- anyone who could open the board — i.e. anyone at VAR_SSAQUA_STATE >= 7 — sailed to the BATTLE
-- FRONTIER for free. It now checks ITEM_SS_TICKET, in the sibling rows' exact shape.
--
-- What this run proves, from a fresh new game with no fixture save, on ONE seeding of the board
-- state (VAR_SSAQUA_STATE = 7, VAR_NEWBARKTOWN_LABSTATE = 11, FLAG_HIDE_OLIVINE_PORT_OAK):
--   A. WITH the ticket in the bag, the BATTLE FRONTIER row still boards and still lands the player
--      on MAP_BATTLE_FRONTIER_OUTSIDE_WEST. This is the no-regression half — a gate that refused
--      everybody would satisfy B on its own.
--   B. WITHOUT it, the same row refuses: the player is still standing in MAP_OLIVINE_CITY_PORT_INSIDE,
--      a box opened (so the refusal was OlivinePort_EventScript_Sailor_NoCredentials answering,
--      not the menu silently eating the press), and control comes back afterwards.
--
-- B is the discriminating half and it is the reason the order below is with-ticket FIRST: the
-- with-ticket pass parks the player on the Frontier, which is what makes segment B's warp back to
-- OLIVINE a real warp rather than the documented no-op that leaves the debug menu open.
--
-- Measured, not reasoned: with the scripts.inc hunk stashed and the ROM rebuilt, this suite scores
-- 18/20, and the two failures are both in segment B and both name the defect —
--   "the refusal names the item it wants ... gStringVar1[0]=0xFF"   (the seeded EOS survived, so
--                                                                    bufferitemname never ran)
--   "... refuses and does not sail -- grp=26 map=4 pos=(20,67)"     (the ticketless player is
--                                                                    standing on the Frontier dock)
-- With the hunk restored it is 20/20.
--
-- ★ The gate deliberately does NOT include FLAG_SYS_GAME_CLEAR, which is what the Hoenn-side
-- BattleFrontier_OutsideWest_EventScript_FerryAttendant demands on top of the ticket. That flag is
-- HOENN's clear flag; a Johto champion gets FLAG_IS_CHAMPION / FLAG_JOHTO_CHAMPION instead
-- (data/maps/JohtoPokemonLeague_HallOfFame/scripts.inc:61-62), so mirroring the attendant would
-- shut this row for precisely the players the board exists for. That is why this suite never sets
-- a clear flag and still expects segment A to sail: a build that "fixed" #79 by copying the Hoenn
-- gate literally would go red here rather than pass quietly.

package.path = (debug.getinfo(1, "S").source:sub(2):match("^(.*[/\\])") or "") .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(require("symbols"), "OlivineHarborBoard")

-- ---- map ids (data/maps/map_groups.json, MAP_X = (num | (group << 8))) -----------------------
local GRP_OLIVINE_INDOOR, MAP_OLIVINE_PORT = 88, 8
-- MAP_BATTLE_FRONTIER_OUTSIDE_WEST shares group 26 with the event islands (the "special area"
-- group), which is why SSAquaKantoCrossing.lua names the same number GRP_EVENT_ISLANDS.
local GRP_SPECIAL, MAP_BF_OUTSIDE_WEST = 26, 4

-- ---- flags/vars ------------------------------------------------------------------------------
-- Johto vars live in SaveBlock3.region.regionVars[id - REGION_VARS_START] (src/event_data.c) and
-- Johto flags in SaveBlock3.region.johtoFlags[(id - FLAG_JOHTO_BASE) / 8]. Neither is in
-- SaveBlock1, and SaveBlock3 is a fixed EWRAM symbol so it never relocates.
local REGION_VARS_START = 0xA000
local VAR_SSAQUA_STATE         = 0xA080 + 0x28  -- VAR_JOHTO_SLICE(0x28), include/constants/johto_vars.h:51
local VAR_NEWBARKTOWN_LABSTATE = 0xA080 + 0x01  -- VAR_JOHTO_SLICE(0x01), :13
local FLAG_JOHTO_BASE            = 0x6000
local FLAG_HIDE_OLIVINE_PORT_OAK = 0x6000 + 0x0F

-- Hardcoded with its citation, exactly as the vars above are. Testing/GenLuaSymbols.py resolves
-- LINKER symbols out of the ELF, and `enum Item` members are compile-time constants that never
-- reach the symbol table — a WANT entry for one fails the build with "symbol not found".
local ITEM_SS_TICKET = 727                      -- include/constants/items.h:889
local EOS = 0xFF                                -- string terminator, include/constants/characters.h
local MAIN_VBLANK_COUNTER1 = 0x20               -- gMain.vblankCounter1, include/main.h:22

local function regionVarAddr(id) return F.sb3() + S.SaveBlock3.regionVars + (id - REGION_VARS_START) * 2 end
local function regionVarSet(id, v) F.w16(regionVarAddr(id), v) end
local function regionVarGet(id) return F.r16(regionVarAddr(id)) end
local function johtoFlagSet(id, on)
  local a, m = F.sb3() + S.SaveBlock3.johtoFlags + ((id - FLAG_JOHTO_BASE) // 8), 1 << (id % 8)
  local v = F.r8(a)
  F.w8(a, on and (v | m) or (v & ~m & 0xFF))
end

-- ---- helpers ---------------------------------------------------------------------------------
-- Drive a ferry conversation to its destination map. A is the only key used: OlivinePort_
-- EventScript_EnterShip contains a blocking MSGBOX_DEFAULT ("We're departing soon."), so a poll
-- loop that pressed nothing would sit in front of it forever. Landing on the destination map is
-- also the honest assertion — frame counts drift with the cutscene, the save block does not.
local function talkUntilMap(grp, map, tries)
  for _ = 1, (tries or 260) do
    if F.grp() == grp and F.mapn() == map then F.idle(60); return true end
    F.press("A", 2); F.idle(20)
  end
  return F.grp() == grp and F.mapn() == map
end

-- Close whatever box is open, B-only (A would re-open the NPC the player is still facing).
local function clearBox(n)
  for _ = 1, (n or 20) do F.press("B", 2); F.idle(30) end
end

-- "Control came back", proved by a real step in whatever direction is open. lib's ensureFree()
-- cannot be trusted on either tile this suite uses it on: OLIVINE's berth corridor is ONE tile
-- wide (x = 8 all the way from the door at (8,9) to the sailor at (8,17)), so its Left/Right probe
-- always reports stuck; and the Frontier dock's neighbourhood at (20,67) is not one this suite
-- should be asserting the shape of. Try the sideways probe first, then fall back to a vertical
-- step — any successful move proves the script released.
--
-- It DOES leave the player displaced, on two counts: ensureFree() can step Left, fail to step back
-- Right and return false having moved him (lib.lua:204-211), and the fallbacks move him a tile on
-- purpose. That is why both call sites are the last thing their segment does, and why every
-- screenshot is taken before it rather than after.
local function freeAnyDirection()
  if F.ensureFree() then return true end
  if F.step("Up") then return true end
  return F.step("Down")
end

-- ★ The "no assert screen" probe is NOT gMain.callback2, and getting that wrong would make it
-- vacuous. AssertfCrashScreen (src/assertf.c:436) never touches callback2: it sets REG_IME = 0 and
-- busy-loops on REG_VCOUNT waiting for START, INSIDE CB2_Overworld's own call stack (Overworld ->
-- ScriptContext_RunScript -> StopScript -> assertf), so F.ow() reads CB2_Overworld with the crash
-- screen on screen. What stops is the main loop: with interrupts off VBlankIntr never runs, so
-- gMain.vblankCounter1 (zeroed only by InitMainCallbacks at boot) freezes.
--
-- This file's own header comment (scripts.inc:131-136) makes that assert the headline hazard for
-- this map — every `warpsilent` here must keep its `waitstate` or the SHIPPED ROM blue-screens —
-- and the row this suite edits sits directly above one. Nothing may press Start between the
-- boarding and this probe: the screen is RESUMABLE and Start dismisses it, restoring REG_IME and
-- letting the counter tick again. lib's dbg() presses Start (lib.lua:224), so every warpTo after
-- this point is reading a resumed game.
local function mainLoopAlive()
  local v0 = F.r32(S.gMain + MAIN_VBLANK_COUNTER1)
  F.idle(30)
  local v1 = F.r32(S.gMain + MAIN_VBLANK_COUNTER1)
  return v1 ~= v0, ("gMain.vblankCounter1 %d -> %d across 30 frames"):format(v0, v1)
end

-- The persisted active region. Read the SaveBlock2 byte rather than the gCurrentRegion mirror:
-- ResyncCurrentRegionFromMap re-seeds the mirror from this on every warp, so this is the value
-- that survives and the one a stray region claim would have to write.
local function activeRegion() return F.r8(F.sb2() + S.SaveBlock2.currentRegion) end

-- ★ Wait out the whole boarding cutscene before believing "it did not sail" — and never sample
-- that with F.step(). This is the trap that made the first version of this suite worthless: it
-- score 17/17 against the PRE-FIX ROM. F.step() is a COORDINATE-CHANGE detector (lib.lua:166), and
-- OlivinePort_EventScript_EnterShip's `applymovement OBJ_EVENT_ID_PLAYER,
-- OlivinePort_Movement_PlayerEnterBoat` walks the player two tiles down onto the boat — so the
-- scripted movement satisfied the step probe, the loop broke out believing control had returned,
-- and the map was read while the cutscene was still several hundred frames from its `warpsilent`.
-- It duly read OLIVINE and passed. (The tell was in the detail string: pos=(8,18), which is the
-- boat tile two south of the sailor, not a tile the player can walk to.)
--
-- So: press B on a FIXED budget and only stop early if the player actually leaves the map. B, never
-- A — A would dismiss the refusal box and immediately re-open the sailor, and the board's row 0 is
-- VERMILION, so a stray A press sails the very crossing the suite is trying not to take.
local function settleOnMap(grp, map, iters)
  for _ = 1, (iters or 45) do
    if F.grp() ~= grp or F.mapn() ~= map then return false end
    F.press("B", 2); F.idle(30)
  end
  return F.grp() == grp and F.mapn() == map
end

-- The harbour board. `message` + `waitmessage` + `multichoice` (scripts.inc:143), six rows:
-- 0 VERMILION, 1 SOUTHERN ISLAND, 2 BIRTH ISLAND, 3 FARAWAY ISLAND, 4 BATTLE FRONTIER, 5 refuse.
--
-- Never lib's menuLive()/pick() here. menuLive() probes by pressing Down, and this board only
-- opens once "Where would you like to sail?" has finished typing — so the probe lands
-- mid-typewriter, reads a stale sMenu, and the A press behind it arrives after the window IS up,
-- selecting row 0 and sailing to VERMILION while the suite still believes no menu appeared. Wait
-- on the ROW COUNT instead; maxCursorPos == 5 is unambiguous, nothing else in this run opens a
-- six-row menu.
local BOARD_ROW_BATTLE_FRONTIER = 4
local function boardRows() return F.rs8(S.sMenu + S.Menu.maxCursorPos) end
local function openBoard()
  -- ★ sMenu is a STATIC that keeps the last menu's fields after it closes — the same trap
  -- VioletMart.lua pays for with sMartInfo. This suite opens the identical six-row board TWICE, so
  -- on the second pass maxCursorPos is still 5 and cursorPos is still 4 from the first, and the
  -- wait below would return TRUE on the very first probe — before the window exists — handing
  -- selectRow() a menu that is not there. Nothing between the two passes clears it either: warpTo
  -- drives the debug menu, which is a ListMenu and never touches sMenu. Zero both fields first;
  -- InitMenuInUpperLeftCornerNormal rewrites all six when the multichoice really opens, so the
  -- write cannot be seen by the game.
  F.w8(S.sMenu + S.Menu.maxCursorPos, 0)
  F.w8(S.sMenu + S.Menu.cursorPos, 0)
  F.press("A", 2); F.idle(45)
  for _ = 1, 14 do
    if boardRows() == 5 then return true end
    F.press("A", 2); F.idle(35)
  end
  return false
end
-- Cursor-verified, never counted blind: read sMenu.cursorPos after each Down.
local function selectRow(target)
  for _ = 1, 12 do
    if F.mcur() == target then F.press("A", 2); F.idle(45); return true end
    F.press("Down", 2); F.idle(12)
  end
  return false
end

-- The bag, through the debug give-item spinner: root row 3 = "Give X…" (src/debug.c:740), then
-- submenu row 0 = "Give item XYZ…" (:645), then the id and quantity fields.
--
-- ★ The arithmetic is NOT the warp spinners'. F.spin(h,t,o) (lib.lua:230) parks on the hundreds
-- digit and presses Down SIX times to floor the field before building the number back up, and
-- Debug_HandleInput_Numeric clamps at `min` (src/debug.c:969). The warp spinners pass min = 0, so
-- spin(h,t,o) is exactly 100h+10t+o there. The item-id field passes min = 1 (:2698) and starts at
-- 1 (:2667), so the floor lands on ONE and the field ends at 1 + 100h + 10t + o. ITEM_SS_TICKET =
-- 727 therefore needs spin(7, 2, 6); spin(7, 2, 7) hands over item 728 and the row would refuse
-- for a reason that has nothing to do with the gate.
local function giveSSTicket()
  F.dbg(); F.idle(60)
  for _ = 1, 3 do F.press("Down", 3); F.idle(16) end   -- root row 3 = "Give X…"
  F.press("A", 3); F.idle(60)
  F.press("A", 3); F.idle(60)                          -- Give row 0 = "Give item XYZ…"
  F.spin(7, 2, 6)                                      -- id: 1 + 700 + 20 + 6 = 727
  -- Quantity: tInput is reset to 1 on the id's A press (src/debug.c:2710) and this field clamps at
  -- min = 1 too, so a bare A takes the single ticket the script needs. AddBagItem then runs and
  -- DebugAction_DestroyExtraWindow closes the menu and unfreezes the player; the bOut is insurance
  -- against a spinner press that got eaten.
  F.press("A", 2); F.idle(60)
  F.bOut(4); F.idle(60)
end

F.run(function()
  if not F.boot(100) then F.check("boot", false); F.finish(); return end

  -- ============================================================ the bag, before anything moves
  -- Done at the hub, where the debug menu's failure mode is harmless: if F.dbg() does not open the
  -- menu, the three Downs walk the player three tiles and spin()'s Right/Down/Up run walks him
  -- twenty more while mashing A at whatever he passes. Retried for the same reason — a dropped
  -- press is an expected event — with the bag read as both the retry condition and the assertion,
  -- so a bad pass costs one retry instead of poisoning both segments.
  local ticketSlot, keyPocket = -1, {}
  for _ = 1, 3 do
    giveSSTicket()
    ticketSlot, keyPocket = F.keyItemSlot(ITEM_SS_TICKET)
    if ticketSlot >= 0 then break end
    F.bOut(6); F.idle(60)
  end
  -- Presence needs no decryption key. An item slot is {u16 id, u16 quantity} and ONLY the quantity
  -- is XORed against SaveBlock2.encryptionKey (src/item.c:66-72), so the id read here is the same
  -- plaintext id `checkitem` compares. Asserting it up front matters: a mis-spun id would
  -- otherwise surface as an unexplained "the row refused with a ticket in the bag".
  F.check("the S.S.TICKET reached the KEY ITEMS pocket", ticketSlot >= 0,
    ("slot=%d pocket=[%s]"):format(ticketSlot, table.concat(keyPocket, ",")))
  -- Stop here rather than limp on, because ticketSlot is used as a WRITE index in segment B. At -1
  -- that write lands four bytes below the key-items array, which per `struct Bag` (items, keyItems,
  -- pokeBalls, ... — include/global.h) is the last slot of the ITEMS pocket: silent corruption of
  -- an unrelated pocket, and every failure after it misleading.
  if ticketSlot < 0 then F.shot("no_ticket"); F.finish(); return end

  -- ============================================================ the board state
  -- All three seeds BEFORE the warp — a hide flag is only read when the map loader rebuilds the
  -- object set.
  --   * VAR_SSAQUA_STATE = 7 is the only gate on reaching the board at all (scripts.inc:112). 7 is
  --     what a full crossing to VERMILION leaves behind (VermilionCity_PortInside/scripts.inc:56).
  --   * VAR_NEWBARKTOWN_LABSTATE = 11 is the A1 maiden-voyage gate (:115). It is below the
  --     >= 7 branch and so unreachable here, but seeded anyway so this suite states its own
  --     precondition rather than depending on which branch the script happens to test first.
  --   * PROF. OAK stands at (8,16) — the exact tile the player must occupy to face the sailor at
  --     (8,17), in a corridor one tile wide — until his National-Dex scene runs, and on a fresh
  --     save it has not.
  regionVarSet(VAR_SSAQUA_STATE, 7)
  regionVarSet(VAR_NEWBARKTOWN_LABSTATE, 11)
  johtoFlagSet(FLAG_HIDE_OLIVINE_PORT_OAK, true)

  -- ============================================================ A. WITH the ticket, it sails
  F.check("A: OLIVINE port entered with the board state seeded",
    F.warpTo(0, 8, 8, 0, 0, 8, 0, 0, 0, GRP_OLIVINE_INDOOR, MAP_OLIVINE_PORT, "olivineTicketed"))
  F.idle(90)
  F.check("A: VAR_SSAQUA_STATE reads 7 on the map (the region-var write landed)",
    regionVarGet(VAR_SSAQUA_STATE) == 7, "state=" .. regionVarGet(VAR_SSAQUA_STATE))
  F.check("A: reached the harbour sailor on OAK's (now hidden) tile",
    F.route({ { 8, 16 } }, "toSailorTicketed"))
  F.face("Down")

  -- Captured, not hardcoded. A fresh new game reaches OLIVINE's port with
  -- SaveBlock2.currentRegion still 0 (UNSET) — the hub boot claims no region and this port has no
  -- ON_TRANSITION to claim one — so asserting the plausible-looking REGION_JOHTO goes red on a
  -- green build. SSAquaKantoCrossing.lua:244-251 records the same finding.
  local regionBeforeBoarding = activeRegion()

  F.check("A: the six-row AfterKanto destination board opens", openBoard(),
    "maxCursorPos=" .. boardRows())
  F.check("A: the cursor reached the BATTLE FRONTIER row",
    selectRow(BOARD_ROW_BATTLE_FRONTIER), "cursor=" .. F.mcur())
  local sailed = talkUntilMap(GRP_SPECIAL, MAP_BF_OUTSIDE_WEST)
  F.check("A: with the S.S.TICKET the BATTLE FRONTIER row still sails", sailed,
    ("grp=%d map=%d pos=(%d,%d)"):format(F.grp(), F.mapn(), F.pos()))
  -- Nothing between the boarding above and this probe may press Start — see mainLoopAlive().
  F.check("A: the boarding leaves no assert screen (the main loop is still running)",
    mainLoopAlive())
  -- Issue #69's decision, made assertable. This row deliberately carries NO
  -- `callnative RegionHub_ScrSetCurrentRegion` — unlike the VERMILION row three above it
  -- (scripts.inc:166) — because Olivine -> Frontier is a journey whose Hoenn claim is made later,
  -- by the Frontier dock's own ferry, and whose second exit is the hub shuttle. Nothing else in the
  -- repo would notice a stray region claim being added to precisely the row that must not have one.
  F.check("A: the Frontier row makes no region claim (issue #69's decision)",
    activeRegion() == regionBeforeBoarding,
    ("region=%d (was %d)"):format(activeRegion(), regionBeforeBoarding))
  clearBox(8)
  F.check("A: control returns on the Frontier dock", freeAnyDirection(),
    ("grp=%d map=%d pos=(%d,%d)"):format(F.grp(), F.mapn(), F.pos()))
  F.shot("frontier_boarded")

  -- ============================================================ B. WITHOUT it, it refuses
  -- Take the ticket back by hand rather than through a menu — there is no debug "remove item"
  -- action, and the S.S.TICKET could not be tossed or sold anyway (`.importance = 1`,
  -- src/data/items.h:14174, and every toss/sell path in src/item_menu.c is gated on
  -- !GetItemImportance). The write is exact: an ItemSlot is {u16 id, u16 quantity}, and `checkitem`
  -- -> CheckBagHasItem matches on the PLAINTEXT id, so zeroing the id empties the slot as far as
  -- every reader is concerned.
  --
  -- ★ Only the id is written, deliberately. An engine-cleared slot does NOT hold a raw 0 quantity:
  -- the setter XORs against SaveBlock2.encryptionKey (src/item.c), so a genuinely empty slot's raw
  -- quantity IS the key. Writing a raw 0 there would leave a slot whose decrypted quantity is the
  -- key — harmless, since nothing reads it once the id is 0, but it would be a lie for the next
  -- person who reads this line.
  local pocketPtr = F.r32(S.gBagPockets + 4 * S.BagPocket.stride)
  F.w16(pocketPtr + ticketSlot * 4, 0)
  local goneSlot, gonePocket = F.keyItemSlot(ITEM_SS_TICKET)
  F.check("B: the S.S.TICKET is out of the bag", goneSlot < 0,
    ("slot=%d pocket=[%s]"):format(goneSlot, table.concat(gonePocket, ",")))

  -- Re-enter from the Frontier rather than re-warping in place: warpTo's success test is group+map
  -- ONLY (lib.lua:245), so calling it while already standing on the target returns true having
  -- warped nobody AND leaves the debug menu open, which then silently eats every press that
  -- follows. Segment A parked the player on a different map, which is what makes this warp real.
  F.check("B: OLIVINE port re-entered ticketless",
    F.warpTo(0, 8, 8, 0, 0, 8, 0, 0, 0, GRP_OLIVINE_INDOOR, MAP_OLIVINE_PORT, "olivineTicketless"))
  F.idle(90)
  F.check("B: the board is still open to this player (VAR_SSAQUA_STATE is still 7)",
    regionVarGet(VAR_SSAQUA_STATE) == 7, "state=" .. regionVarGet(VAR_SSAQUA_STATE))
  F.check("B: back at the harbour sailor", F.route({ { 8, 16 } }, "toSailorTicketless"))
  F.face("Down")

  F.check("B: the destination board still opens without the ticket", openBoard(),
    "maxCursorPos=" .. boardRows())
  -- Poison the string buffer before the row runs, so the {STR_VAR_1} check below cannot pass on a
  -- stale buffer. EOS at byte 0 is an empty string — which is exactly what the refusal would print
  -- if `bufferitemname` were ever dropped from the row, since OlivinePort_Text_NoPass names the
  -- item three times and nothing else on this path writes STR_VAR_1.
  F.w8(S.gStringVar1, EOS)
  F.check("B: the cursor reached the BATTLE FRONTIER row again",
    selectRow(BOARD_ROW_BATTLE_FRONTIER), "cursor=" .. F.mcur())

  -- Three halves, and all three are needed. "Did not sail" alone would be satisfied by a sailor who
  -- swallowed the press without opening a box; "a box opened" alone would be satisfied by one who
  -- opened it and never released.
  --
  -- The lock probe is sampled FIRST and is safe to take with F.step(): the row's own `closemessage`
  -- + `delay 20` have run by now and both branches are sitting on a blocking MSGBOX_DEFAULT
  -- (OlivinePort_Text_NoPass on the fixed build, OlivinePort_Text_SailorGetOnBoard on the pre-fix
  -- one), so nothing is moving the player yet either way. Everything AFTER it goes through
  -- settleOnMap, for the reason written on that helper.
  F.idle(60)
  local locked = not F.step("Up")
  -- Shot HERE, with the refusal box still on screen — it is the visual half of the acceptance, and
  -- taking it after the settle loop below would photograph an empty room.
  F.shot("frontier_refused")
  -- What the refusal SAYS, not just which branch ran. Deleting `bufferitemname` from the row leaves
  -- every other assertion in this segment green while the message names nothing; the buffer was
  -- seeded to EOS above, so this fails in exactly that case.
  local namedItem = F.r8(S.gStringVar1) ~= EOS
  F.check("B: the refusal names the item it wants (bufferitemname populated STR_VAR_1)", namedItem,
    ("gStringVar1[0]=0x%02X"):format(F.r8(S.gStringVar1)))
  local stayed = settleOnMap(GRP_OLIVINE_INDOOR, MAP_OLIVINE_PORT, 45)
  -- ★ THE discriminating assertion of the suite. Against the pre-fix ROM the ungated row runs
  -- `call OlivinePort_EventScript_EnterShip` here and this reads grp=26 map=4.
  F.check("B: without the S.S.TICKET the BATTLE FRONTIER row refuses and does not sail", stayed,
    ("grp=%d map=%d pos=(%d,%d)"):format(F.grp(), F.mapn(), F.pos()))
  F.check("B: the refusal is a spoken one (NoCredentials opened a box)", locked)
  F.check("B: and control comes back rather than dead-ending", freeAnyDirection(),
    ("pos=(%d,%d)"):format(F.pos()))

  F.finish()
end)
