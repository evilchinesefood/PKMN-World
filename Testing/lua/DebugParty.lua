-- Issue #44 — the debug Party actions publish the party count, and keep the follower in sync.
--
-- The bug: DebugAction_Party_SetParty filled gParties and never wrote gPartiesCount, so every
-- consumer of the cached count (party menu, battle, whiteout, follower spawn) behaved as if the
-- player had no POKéMON. It failed silently — the menu just closed. `make check` could never have
-- caught it: battle_main.c recomputes every party count from the array under `#if TESTING`, so the
-- value self-corrects in a test build and only a real ROM shows the gap. That is why this suite
-- exists alongside test/debug.c.
--
-- What is proven here that the host test cannot be: the count is right in a real ROM, the follower
-- appears/disappears immediately without a map reload, and a debug battle runs with a published
-- player count (the in-battle party menu derives maxMonIndex = count - 1, which underflows to 255
-- at count 0).
--
-- Run against a THROWAWAY COPY, on a genuinely fresh save:
--   cp <repo>\pokemonworld.gba  BizHawk\Verify3.gba
--   del BizHawk\GBA\SaveRAM\Verify3.SaveRAM
--   EmuHawk.exe BizHawk\Verify3.gba --lua=<repo>\Testing\lua\DebugParty.lua
local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(require("symbols"), "DebugParty")

local FOLLOWER = 0xFE               -- OBJ_EVENT_ID_FOLLOWER
local SPECIES_WOBBUFFET = 202       -- the one-slot Lv100 "Buffie" in src/data/debug_trainers.party
local OBJ_EVENT_MON_SPECIES_MASK = 0x8FFF
local HUB_GROUP = 100

-- Party… is main row 2; inside it Clear Party / Set Party / Start Debug Battle are rows 8/9/10
-- (sDebugMenu_Actions_Party, src/debug.c).
local ROW_PARTY_MENU, ROW_CLEAR, ROW_SET, ROW_BATTLE = 2, 8, 9, 10

local function count() return F.r8(S.gPartiesCount) end

local function obj(localId)
  for i = 0, 15 do
    local b = S.gObjectEvents + i * S.ObjectEvent.stride
    if (F.r8(b) & 1) == 1 and F.r8(b + S.ObjectEvent.localId) == localId then
      return {
        i = i,
        x = F.rs16(b + S.ObjectEvent.x) - 7,
        y = F.rs16(b + S.ObjectEvent.y) - 7,
        gfx = F.r16(b + S.ObjectEvent.graphicsId),
        invisible = (F.r8(b + S.ObjectEvent.flags1) & 0x20) ~= 0,
      }
    end
  end
  return nil
end
local function describe(o)
  if not o then return "ABSENT" end
  return string.format("(%d,%d) gfx=0x%04X species=%d %s", o.x, o.y, o.gfx,
    o.gfx & OBJ_EVENT_MON_SPECIES_MASK, o.invisible and "invisible" or "visible")
end

-- lib's sel() taps Down for 2 frames with an 8-frame gap; press slower, because the Down that
-- scrolls the list window past the visible rows is the one most likely to be eaten.
local function tap(n)
  for _ = 1, n do F.press("Down", 3); F.idle(16) end
end

-- Open the debug menu and run one Party action. Every call starts from a closed menu, and the
-- root and each submenu always open at row 0, so the row counts above are absolute.
local function partyAction(row, tag)
  F.dbg(); F.idle(60)
  tap(ROW_PARTY_MENU); F.press("A", 3); F.idle(60)
  tap(row); F.shot(tag .. "_cursor")
  F.press("A", 3); F.idle(180)
end

-- B only. A next to an NPC re-opens whatever you are facing.
local function drain(tries, tag)
  for i = 1, (tries or 60) do
    F.press("B", 3); F.idle(24)
    if i % 6 == 0 and F.ensureFree() then return true end
  end
  local x, y = F.pos()
  F.L(string.format("  drain %s exhausted at (%d,%d)", tag or "?", x, y))
  return F.ensureFree()
end

F.run(function()
  if not F.boot(HUB_GROUP) then F.check("boot to the hub", false); F.finish(); return end
  F.idle(300)
  F.check("player is free before the debug work", F.ensureFree())

  local grp0, map0 = F.grp(), F.mapn()
  F.L(string.format("  starting on group %d map %d", grp0, map0))
  F.check("a fresh save starts with an empty party", count() == 0, "count=" .. count())
  F.check("no follower is out with an empty party", obj(FOLLOWER) == nil, describe(obj(FOLLOWER)))

  -- ---- Set Party ---------------------------------------------------------------------------
  -- Sample BEFORE any drain. drain() calls ensureFree(), which steps the player Left then Right,
  -- and a step is exactly what makes the follower emerge — so a post-drain read cannot distinguish
  -- "spawned hidden, then stepped out" from "spawned visible".
  partyAction(ROW_SET, "set1")
  local px, py = F.pos()
  local fol = obj(FOLLOWER)
  local n1 = count()
  F.check("Set Party publishes the party count", n1 ~= 0, "count=" .. n1)
  F.check("the published count matches the debug trainer's party size", n1 == 1, "count=" .. n1)

  F.check("Set Party spawns the follower immediately, with no map reload", fol ~= nil, describe(fol))
  F.check("the follower is the party's lead POKéMON",
    fol ~= nil and (fol.gfx & OBJ_EVENT_MON_SPECIES_MASK) == SPECIES_WOBBUFFET, describe(fol))
  -- Deliberate: UpdateFollowingPokemon spawns the object at the player's tile with
  -- invisible = TRUE, and it emerges on the first step. Asserting visibility here would be
  -- asserting the opposite of the engine's design.
  F.check("the freshly spawned follower is hidden under the player",
    fol ~= nil and fol.invisible and fol.x == px and fol.y == py,
    describe(fol) .. string.format(" player (%d,%d)", px, py))
  F.shot("after_set")
  drain(30, "set1")

  F.check("a step is possible with the new party", F.step("Left"))
  F.idle(60)
  local folStep = obj(FOLLOWER)
  F.check("the follower is on screen after one step", folStep ~= nil and not folStep.invisible,
    describe(folStep))
  F.shot("follower_visible")

  -- ---- Clear Party -------------------------------------------------------------------------
  partyAction(ROW_CLEAR, "clear")
  local nClear, folClear = count(), obj(FOLLOWER)
  F.check("Clear Party zeroes the party count", nClear == 0, "count=" .. nClear)
  F.check("Clear Party removes the follower immediately", folClear == nil, describe(folClear))
  F.shot("after_clear")
  drain(30, "clear")

  -- ---- Set Party again ---------------------------------------------------------------------
  partyAction(ROW_SET, "set2")
  local n2, fol2 = count(), obj(FOLLOWER)
  drain(30, "set2")
  F.check("Set Party works a second time", n2 == n1, "count=" .. n2)
  F.check("the follower comes back on the second Set Party", fol2 ~= nil, describe(fol2))
  F.check("the round trip never left the map", F.grp() == grp0 and F.mapn() == map0,
    string.format("group %d map %d", F.grp(), F.mapn()))
  F.shot("after_set2")

  -- Set Party on top of an EXISTING follower. The empty-party and no-follower branches of
  -- UpdateFollowingPokemon are covered above; this drives the remaining one, where a follower
  -- object is already on the map. It must be refreshed in place — never duplicated, never
  -- orphaned. The debug trainer only ever has one species, so the re-graphics branch inside that
  -- path fires only when the random gender flips; what is asserted here is the invariant that
  -- holds either way.
  local function followerCount()
    local n = 0
    for i = 0, 15 do
      local b = S.gObjectEvents + i * S.ObjectEvent.stride
      if (F.r8(b) & 1) == 1 and F.r8(b + S.ObjectEvent.localId) == FOLLOWER then n = n + 1 end
    end
    return n
  end
  partyAction(ROW_SET, "set3")
  local n3, fol3, nFol = count(), obj(FOLLOWER), followerCount()
  drain(30, "set3")
  F.check("Set Party over an existing follower keeps the count right", n3 == n1, "count=" .. n3)
  F.check("Set Party over an existing follower leaves exactly one follower object", nFol == 1,
    "followers=" .. nFol)
  F.check("the refreshed follower still matches the party lead",
    fol3 ~= nil and (fol3.gfx & OBJ_EVENT_MON_SPECIES_MASK) == SPECIES_WOBBUFFET, describe(fol3))

  -- ---- Start Debug Battle ------------------------------------------------------------------
  -- The player count is the point. Before this fix nothing published it before battle setup in a
  -- real ROM (the only pre-battle write is the #if TESTING loop in battle_main.c), so a debug
  -- battle ran the whole way with count 0.
  partyAction(ROW_BATTLE, "battle")
  local started, cbBattle = false, 0
  for _ = 1, 600 do
    F.idle(10)
    if not F.ow() then started = true; cbBattle = F.cb2(); break end
  end
  F.check("Start Debug Battle leaves the overworld", started,
    string.format("cb2=0x%08X", F.cb2()))

  -- Drain the send-out sequence before touching the action menu. A Down + A pressed during
  -- "Go! Buffie!" is silently eaten, and the first run of this suite "opened" a party menu that
  -- was really still the intro text — the count assertion passed for the wrong reason.
  for _ = 1, 120 do F.press("B", 2); F.idle(12) end
  F.idle(120)
  local inBattle = count()
  F.check("the player party count is published during the battle", inBattle == n1,
    "count=" .. inBattle)
  F.shot("battle")

  -- The in-battle party menu computes maxMonIndex = gPartiesCount[player] - 1, which underflows to
  -- 255 at count 0. Open it (action menu: FIGHT / BAG above, POKéMON / RUN below, so Down + A).
  -- OpenPartyMenuInBattle hands gMain.callback2 to CB2_UpdatePartyMenu, so a callback2 that moves
  -- off the battle's own is the proof the menu really took over — a screenshot cannot say that.
  F.press("Down", 3); F.idle(20)
  F.press("A", 3); F.idle(300)
  F.shot("battle_party_menu")
  local cbMenu = F.cb2()
  F.check("the in-battle party menu actually opens", cbMenu ~= cbBattle,
    string.format("battle cb2=0x%08X, now 0x%08X", cbBattle, cbMenu))
  local inMenu = count()
  F.check("the in-battle party menu reads a valid party count", inMenu == n1, "count=" .. inMenu)

  -- Closing it again is the anti-lockup check: at count 0 the summary index underflows, so a menu
  -- that opens but never hands control back is exactly the failure mode this fix removes.
  local closed = false
  for _ = 1, 60 do
    F.press("B", 3); F.idle(20)
    if F.cb2() == cbBattle then closed = true; break end
  end
  F.check("the in-battle party menu closes back to the battle", closed,
    string.format("cb2=0x%08X", F.cb2()))
  F.shot("battle_after_menu")

  F.finish()
end)
