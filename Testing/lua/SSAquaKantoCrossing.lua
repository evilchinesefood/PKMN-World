-- SSAquaKantoCrossing.lua — issue #65: the real S.S.AQUA Kanto disembark.
--
-- What this proves, in one run, from a fresh new game with no fixture save:
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
