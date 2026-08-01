-- Issue #41 — the intro tour escort with a FOLLOWER POKéMON out. Evidence suite.
--
-- The escort is ~47 scripted player steps. RegionHub has 14 object events and OBJECT_EVENTS_COUNT
-- is 16, so player + follower fills the map's sprite budget EXACTLY — a scripted walk of that
-- length with a follower trailing had never been exercised on this map, and the issue called it
-- out as needing a real run rather than a static read.
--
-- What this proves that HubIntroTour.lua cannot: the follower spawns at all under a full object
-- table, it is still adjacent to the player when the tour ends 47 tiles later (no desync), and
-- the guide still gets home.
--
-- Run against a THROWAWAY COPY, on a genuinely fresh save:
--   cp <repo>\pokemonworld.gba  BizHawk\Verify2.gba
--   rm BizHawk\GBA\SaveRAM\Verify2.SaveRAM
--   EmuHawk.exe BizHawk\Verify2.gba --lua=<repo>\Testing\lua\HubIntroTourFollower.lua
local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(require("symbols"), "HubIntroTourFollower")

local FLAG_HUB_INTRO_TOUR_DONE = 0xDCF
local CURATOR = 13                  -- LOCALID_REGION_HUB_CURATOR
local FOLLOWER = 0xFE               -- OBJ_EVENT_ID_FOLLOWER
local CREST = { 16, 4 }
local STOPS = { { 21, 3 }, { 16, 3 }, { 11, 3 }, { 4, 3 }, { 2, 2 }, { 2, 7 }, { 13, 12 },
                { 9, 11 }, { 4, 13 } }

local function flagAddr(id) return F.sb1() + S.SaveBlock1.flags + math.floor(id / 8) end
local function flagGet(id) return (F.r8(flagAddr(id)) & (1 << (id % 8))) ~= 0 end
local function flagClear(id)
  F.w8(flagAddr(id), F.r8(flagAddr(id)) & ~(1 << (id % 8)) & 0xFF)
end
-- ACTIVE IS NOT VISIBLE. ScriptHideFollower (src/scrcmd.c) pockets the follower by running
-- EnterPokeballMovement and setting objectEvent->invisible; the object stays ACTIVE in
-- gObjectEvents, parked at whatever tile it was last on. An active-only check therefore reads a
-- pocketed follower as "still out there", and as the player walks away the apparent gap grows
-- without bound -- which is exactly the false desync the first version of this suite reported
-- (max gap 22, player (3,12) vs a "follower" frozen at (17,4) that was not on screen at all).
local function obj(localId)
  for i = 0, 15 do
    local b = S.gObjectEvents + i * S.ObjectEvent.stride
    if (F.r8(b) & 1) == 1 and F.r8(b + S.ObjectEvent.localId) == localId then
      return {
        i = i,
        x = F.rs16(b + S.ObjectEvent.x) - 7,
        y = F.rs16(b + S.ObjectEvent.y) - 7,
        invisible = (F.r8(b + S.ObjectEvent.flags1) & 0x20) ~= 0,
      }
    end
  end
  return nil
end
local function liveObjects()
  local n = 0
  for i = 0, 15 do
    if (F.r8(S.gObjectEvents + i * S.ObjectEvent.stride) & 1) == 1 then n = n + 1 end
  end
  return n
end
local function at(o) return o and string.format("(%d,%d)", o.x, o.y) or "ABSENT" end

-- See HubIntroTour.lua: lib's dismiss() budget is too small for the Curator's fall-through, and A
-- is unsafe next to an NPC or a counter, so drain with B only and give it room.
local function drain(tries, tag)
  for i = 1, (tries or 150) do
    F.press("B", 3); F.idle(24)
    if i % 6 == 0 and F.ensureFree() then return true end
  end
  local x, y = F.pos()
  F.L(string.format("  drain %s exhausted at (%d,%d)", tag or "?", x, y))
  F.shot((tag or "drain") .. "_stuck")
  return F.ensureFree()
end

-- lib's pick() only ever presses Down, so it can reach NO but never YES: menuLive() itself
-- presses Down to test the menu, which moves a 2-row yes/no cursor off YES, and
-- Menu_MoveCursorNoWrapAround will not bring it back. Drive the cursor in BOTH directions,
-- verified against sMenu.cursorPos each step, so YES and NO are equally reachable.
local function answer(row, tag)
  for _ = 1, 30 do
    if F.menuLive() then
      for _ = 1, 8 do
        local c = F.mcur()
        if c == row then
          F.press("A", 2); F.idle(45)
          F.L(string.format("  answer %s row %d ok", tag, row))
          return true
        end
        F.press(c > row and "Up" or "Down", 2); F.idle(10)
      end
      F.L(string.format("  answer %s: cursor never reached %d (last %d)", tag, row, F.mcur()))
      return false
    end
    F.press("A", 2); F.idle(35)
  end
  F.L("  answer " .. tag .. ": menu never went live")
  return false
end

F.run(function()
  -- Clear the auto-offer out of the way first: this suite is about the escort, and the fresh-boot
  -- trigger is already proven by HubIntroTour.lua.
  -- keepScene: this suite declines the arrival offer itself, so boot() must leave it open.
  if not F.boot(100, true) then F.check("boot to the hub", false); F.finish(); return end
  F.idle(400)
  F.check("decline the fresh-boot offer", answer(1, "boot-no"))
  drain(60, "boot_decline")
  F.check("player is free before the debug work", F.ensureFree())

  -- Debug -> Party… (main row 2) -> Set Party (row 9), per sDebugMenu_Actions_Main and
  -- sDebugMenu_Actions_Party in src/debug.c. lib's sel() taps Down for 2 frames with an 8-frame
  -- gap; press slower here because the Down that scrolls the window past the visible rows is the
  -- one most likely to be eaten. The screenshot of the cursor BEFORE the A press is what settled
  -- the diagnosis below: the cursor was verifiably on "Set Party" and the party was still empty,
  -- so this was never a menu-navigation miss.
  local function tap(n)
    for _ = 1, n do F.press("Down", 3); F.idle(16) end
  end
  F.dbg(); F.idle(60); F.shot("dbg_root")
  tap(2); F.press("A", 3); F.idle(60); F.shot("dbg_party")
  tap(9); F.shot("dbg_cursor_before_A")
  F.press("A", 3); F.idle(180); F.shot("dbg_after_A")
  drain(30, "setparty")
  -- Set Party seeds the one-slot Lv100 Wobbuffet "Buffie" from src/data/debug_trainers.party
  -- (partySize 1) and publishes the count itself.
  --
  -- ★ HISTORY, because this line used to say the opposite: until issue #44,
  -- DebugAction_Party_SetParty filled the party ARRAY and threw away
  -- CreateNPCTrainerPartyFromTrainer's return value, so gPartiesCount stayed 0 and the game saw an
  -- empty party. This suite worked around it by asserting count == 0 and then writing the count
  -- from Lua -- i.e. it encoded the bug as a passing check, which is why the fix turned it red.
  -- The seed is still self-validating: if slot 0 were actually empty the follower checks below
  -- would fail loudly rather than pass on a blank mon.
  local party = F.r8(S.gPartiesCount)
  F.check("debug Set Party publishes the party count (issue #44)", party == 1, "count=" .. party)
  if party < 1 then F.shot("no_party"); F.finish(); return end

  -- Set Party now spawns the follower on the spot (#44 added the UpdateFollowingPokemon call), so
  -- the reload below is no longer what makes it appear -- it is kept as a guard that the follower
  -- also survives a map load, which is the state the escort actually runs in.
  F.check("reload the hub so the follower spawns", F.warpTo(1, 0, 0, 0, 0, 0, 0, 0, 0, 100, 0, "hubReload"))
  F.idle(300)
  local fol = obj(FOLLOWER)
  F.check("follower POKéMON is out on the map", fol ~= nil, at(fol))
  F.check("object table is at or under the 16 spawn cap", liveObjects() <= 16, "live=" .. liveObjects())
  F.L(string.format("  live objects with a follower out: %d", liveObjects()))
  F.shot("follower_out")
  if fol == nil then F.finish(); return end

  -- Re-arm the tour and take it from the crest.
  flagClear(FLAG_HUB_INTRO_TOUR_DONE)
  F.check("tour flag cleared for the escort run", not flagGet(FLAG_HUB_INTRO_TOUR_DONE))
  local px, py = F.pos()
  F.L(string.format("  standing at (%d,%d) after the reload", px, py))
  if px ~= CREST[1] or py ~= CREST[2] then
    F.check("route back to the crest", F.route({ { CREST[1], CREST[2] } }, "toCrest"))
  else
    -- already on the crest: step off and back on so the coord_event fires
    F.step("Right"); F.idle(30); F.step("Left")
  end
  F.idle(400)
  local g = obj(CURATOR)
  F.check("the guide comes over for the offer", g ~= nil and g.x == 17 and g.y == 4, at(g))
  F.check("accept the tour", answer(0, "tour-yes"))

  -- WHAT "no desync" MEANS HERE. `ScrCmd_applymovement` calls ScriptHideFollower() whenever the
  -- movement target is not the follower, FLAG_SAFE_FOLLOWER_MOVEMENT is clear (nothing sets it on
  -- this map) and the movement data sits outside Common_Movement_FollowerSafeStart..End (ours
  -- does). So the engine's own answer to a long scripted escort is to pocket the follower for the
  -- duration and bring it back at the release, and that is the SAFE path. The failure to catch is
  -- a follower that is genuinely ON SCREEN and drifting, so the gap is only measured over frames
  -- where it is active AND not invisible. Both counts are logged: if a future engine change stops
  -- pocketing it, `visible` jumps off zero and the gap assertion starts doing real work.
  local seen, idx = {}, 1
  local maxGap, gapAt, visible, activeSamples = 0, "", 0, 0
  for f = 1, 20000 do
    if f % 24 == 0 then F.press("B", 2) else joypad.set({}); emu.frameadvance() end
    local x, y = F.pos()
    -- Sample the follower every 4th frame, not every frame: obj() walks all 16 object slots and
    -- doing that per frame through BizHawk's Lua bridge dominates the run (the first version of
    -- this suite spent >15 minutes inside this loop). A follower step takes 16 frames, so every
    -- 4th frame still catches any tile it occupies.
    if f % 4 == 0 then
      local fo = obj(FOLLOWER)
      if fo then
        activeSamples = activeSamples + 1
        if not fo.invisible then
          visible = visible + 1
          local d = math.abs(fo.x - x) + math.abs(fo.y - y)
          if d > maxGap then maxGap, gapAt = d, string.format("player (%d,%d) follower (%d,%d) at frame %d", x, y, fo.x, fo.y, f) end
        end
      end
    end
    if f % 400 == 0 then
      F.L(string.format("    t=%d player (%d,%d) waiting for stop %d (%d,%d)", f, x, y, idx,
        STOPS[math.min(idx, #STOPS)][1], STOPS[math.min(idx, #STOPS)][2]))
      if f == 800 or f == 4000 then F.shot("escort_t" .. f) end
    end
    if idx <= #STOPS and x == STOPS[idx][1] and y == STOPS[idx][2] then
      seen[idx] = f
      F.L(string.format("  stop %d reached at frame %d", idx, f))
      idx = idx + 1
    end
    if idx > #STOPS then break end
  end
  F.L(string.format("  follower sampled: %d active, %d of those actually visible; worst on-screen gap %d",
    activeSamples, visible, maxGap))
  for i = 1, #STOPS do
    F.check(string.format("stop %d at (%d,%d) reached with a follower out", i, STOPS[i][1], STOPS[i][2]),
      seen[i] ~= nil, seen[i] and ("frame " .. seen[i]) or "never reached")
  end

  drain(80, "tour_end")
  local ex, ey = F.pos()
  F.check("the escort ends at the POKéMON CENTER counter", ex == 13 and ey == 12, string.format("(%d,%d)", ex, ey))
  F.check("the player is released", F.ensureFree())
  local fe = obj(FOLLOWER)
  F.check("the follower is out again after the escort", fe ~= nil and not fe.invisible,
    fe and (at(fe) .. (fe.invisible and " STILL POCKETED" or "")) or "ABSENT")
  local fx, fy = -99, -99
  if fe then fx, fy = fe.x, fe.y end
  F.check("the follower is beside the player at the end", fe ~= nil and (math.abs(fx - ex) + math.abs(fy - ey)) <= 1,
    string.format("player (%d,%d) follower (%d,%d)", ex, ey, fx, fy))
  F.check("the follower never desynced during the escort (pocketed, or kept within one tile)",
    visible == 0 or maxGap <= 1,
    string.format("%d active samples, %d visible, max on-screen gap %d %s", activeSamples, visible, maxGap, gapAt))
  -- Record the mechanism, so a future run that stops pocketing is visible as a CHANGE rather than
  -- quietly passing the check above for a different reason.
  F.check("the engine pocketed the follower for the scripted escort", visible == 0 and activeSamples > 0,
    string.format("%d active samples, %d visible", activeSamples, visible))
  local ge = obj(CURATOR)
  F.check("the guide still gets home to (22,7) with a follower out", ge ~= nil and ge.x == 22 and ge.y == 7, at(ge))
  F.check("the tour flag is set after the escort", flagGet(FLAG_HUB_INTRO_TOUR_DONE))
  F.shot("follower_tour_end")
  F.finish()
end)
