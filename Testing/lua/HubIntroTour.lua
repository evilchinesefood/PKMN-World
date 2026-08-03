-- Issue #41 — World Transit intro tour. Evidence suite.
--
-- Drives all five reachable paths of the tour on ONE fresh new game, in an order chosen so each
-- phase leaves the state the next one needs:
--
--   1. warp-in offer + DECLINE      — the auto-trigger a brand-new game must get with no input,
--                                     and that declining releases the player and sets the flag
--   2. Curator re-offer + DECLINE   — falls through to his normal HUB PASS / POKeVIAL gives
--   3. Curator re-offer + ACCEPT    — the full seven-stop escort, in order
--   4. map reload                   — the guide stays home and nothing re-triggers
--   5. walk-on trigger              — the crest coord_event, with the flag cleared by hand to
--                                     stand in for a legacy save that never saw the intro
--
-- Run against a THROWAWAY COPY (lib.new() enforces Verify*/MigChk*/FixGen*):
--   cp <repo>\pokemonworld.gba  BizHawk\Verify1.gba
--   rm BizHawk\GBA\SaveRAM\Verify1.SaveRAM          # phase 1 needs a genuinely new game
--   EmuHawk.exe BizHawk\Verify1.gba --lua=<repo>\Testing\lua\HubIntroTour.lua
--
-- Dialogue is advanced with B, never A: at three of the seven stops the player is left facing a
-- counter or an attendant, and an A there opens the nurse/mart/travel script instead.
local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(require("symbols"), "HubIntroTour")

local FLAG_HUB_INTRO_TOUR_DONE = 0xDCF   -- include/constants/flags.h (FLAG_WORLD_MAP_BANK + 0x8F)
local CURATOR = 13                       -- LOCALID_REGION_HUB_CURATOR
local DIR_SOUTH, DIR_WEST = 1, 3         -- enum Direction, include/constants/global.h
local CREST = { 16, 4 }
local STOPS = { { 21, 3 }, { 16, 3 }, { 11, 3 }, { 4, 3 }, { 2, 2 }, { 2, 7 }, { 13, 12 },
                { 9, 11 }, { 4, 13 } }
local STOP_NAMES = { "HOENN gate", "JOHTO gate", "KANTO gate", "FRONTIER gate",
                     "world tour board", "POKeMART counter", "POKeMON CENTER counter",
                     "BATTLE NET terminal", "flagship stairs" }

local function flagAddr(id) return F.sb1() + S.SaveBlock1.flags + math.floor(id / 8) end
local function flagGet(id) return (F.r8(flagAddr(id)) & (1 << (id % 8))) ~= 0 end
local function flagClear(id)
  F.w8(flagAddr(id), F.r8(flagAddr(id)) & ~(1 << (id % 8)) & 0xFF)
end

-- Resolve an object event by its LOCAL id, not by array index: the index is spawn order and moves.
local function obj(localId)
  for i = 0, 15 do
    local b = S.gObjectEvents + i * S.ObjectEvent.stride
    if (F.r8(b) & 1) == 1 and F.r8(b + S.ObjectEvent.localId) == localId then
      return {
        i = i,
        x = F.rs16(b + S.ObjectEvent.x) - 7,
        y = F.rs16(b + S.ObjectEvent.y) - 7,
        facing = F.r16(b + S.ObjectEvent.facing) & 0xF,
        heldActive = (F.r8(b) & 0x40) ~= 0,
      }
    end
  end
  return nil
end
local function at(o) return o and string.format("(%d,%d) facing %d", o.x, o.y, o.facing) or "ABSENT" end
local function keyItems()
  local _, dump = F.keyItemSlot(-1)
  return #dump
end

-- lib's dismiss(30) is not enough here. The Curator's fall-through is two giveitems (each with a
-- fanfare that a button press cannot skip) plus four multi-page boxes, and the first run of this
-- suite ran out of presses mid-POKeVIAL explanation. B only, never A: at (22,6) the player is
-- facing the Curator, and an A would re-open the conversation we are trying to close.
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
-- lib's menuLive() probes with Down only, which cannot detect a menu whose cursor rests on
-- the BOTTOM row — exactly what the Curator re-offer now does (multichoicedefault row 1, so
-- an A-mash declines). Probe both directions: at the bottom, Down is dead but Up moves.
local function menuLiveBothWays()
  local c0 = F.mcur()
  F.press("Down", 2); F.idle(10)
  if F.mcur() ~= c0 then return true end
  F.press("Up", 2); F.idle(10)
  return F.mcur() ~= c0
end

local function answer(row, tag)
  for _ = 1, 30 do
    if menuLiveBothWays() then
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
  ----------------------------------------------------------------------------------------------
  -- Phase 1 — the warp-in offer on a brand-new game, then decline
  ----------------------------------------------------------------------------------------------
  F.L("== phase 1: warp-in auto-offer, declined ==")
  -- keepScene: this suite's whole subject is the arrival prompt, so boot() must NOT clear it.
  if not F.boot(100, true) then F.check("boot to the hub", false); F.finish(); return end
  F.check("fresh new game lands on the arrival crest", select(1, F.pos()) == CREST[1] and select(2, F.pos()) == CREST[2],
    string.format("(%d,%d)", select(1, F.pos()), select(2, F.pos())))
  F.idle(400)   -- the guide's 8-step approach is ~128 frames, plus the message box

  local g = obj(CURATOR)
  F.check("the tour fires with no input on a brand-new game (guide left his post)",
    g ~= nil and not (g.x == 22 and g.y == 7), at(g))
  F.check("guide finishes his approach beside the player at (17,4)",
    g ~= nil and g.x == 17 and g.y == 4, at(g))
  F.check("guide turns to face the player", g ~= nil and g.facing == DIR_WEST, at(g))
  F.check("flag is still clear while the prompt is open", not flagGet(FLAG_HUB_INTRO_TOUR_DONE))
  F.shot("offer")
  F.check("the player is locked by the prompt", not F.ensureFree())

  F.check("decline the offer (cursor lands on NO)", answer(1, "crest-no"))
  drain(60, "crest_decline")
  F.check("declining sets FLAG_HUB_INTRO_TOUR_DONE", flagGet(FLAG_HUB_INTRO_TOUR_DONE))
  F.check("declining leaves the player on the crest", select(1, F.pos()) == CREST[1] and select(2, F.pos()) == CREST[2],
    string.format("(%d,%d)", select(1, F.pos()), select(2, F.pos())))
  F.check("the player is released after declining", F.ensureFree())
  local gh = obj(CURATOR)
  F.check("guide walks back to his post at (22,7)", gh ~= nil and gh.x == 22 and gh.y == 7, at(gh))
  F.check("guide faces down at his post", gh ~= nil and gh.facing == DIR_SOUTH, at(gh))
  F.shot("declined")

  -- ensureFree() above stepped OFF the crest and back ON to it. With the flag now set the crest
  -- coord_event must not fire again, which is the "no auto-trigger on later arrivals" clause.
  F.check("stepping back onto the crest does not re-trigger the tour", F.ensureFree())

  ----------------------------------------------------------------------------------------------
  -- Phase 2 — the Curator re-offer, declined, must fall through to his normal script
  ----------------------------------------------------------------------------------------------
  F.L("== phase 2: Curator re-offer, declined ==")
  local kBefore = keyItems()
  F.check("route to the Curator", F.route({ { 22, 4 }, { 22, 6 } }, "toCurator"))
  F.face("Down")
  F.press("A", 2); F.idle(60)
  -- Deep-review task 36: the re-offer is now a multichoicedefault with the cursor RESTING
  -- ON NO (row 1), so an A-mash can no longer re-enter the multi-minute escort. Same rows
  -- as ever: 0 = tour, 1 = decline/business — but the helper must drive UP to reach YES.
  F.check("decline the Curator's re-offer (cursor rests on NO)", answer(1, "curator-no"))
  drain(150, "curator_decline")
  local kAfter = keyItems()
  F.check("declining falls straight through to the HUB PASS + POKeVIAL gives",
    kAfter >= kBefore + 2, string.format("key items %d -> %d", kBefore, kAfter))
  F.check("the player is released after the Curator chat", F.ensureFree())
  F.shot("curator_declined")

  ----------------------------------------------------------------------------------------------
  -- Phase 3 — the Curator re-offer, accepted: the full escort
  ----------------------------------------------------------------------------------------------
  F.L("== phase 3: Curator re-offer, accepted — the full escort ==")
  local x0, y0 = F.pos()
  F.check("standing next to the Curator before accepting", x0 == 22 and y0 == 6, string.format("(%d,%d)", x0, y0))
  F.face("Down")
  F.press("A", 2); F.idle(60)
  -- Row 0 = tour, as ever — but the cursor now rests on NO, so the helper drives Up first.
  F.check("accept the Curator's re-offer", answer(0, "curator-yes"))

  -- Watch the escort. Stops must be hit IN ORDER: the index only ever advances, so a tile that
  -- matches a LATER stop early, or the same stop twice, cannot fake a pass.
  local seen, idx = {}, 1
  local reachedCrest = false
  for f = 1, 20000 do
    if f % 24 == 0 then F.press("B", 2) else joypad.set({}); emu.frameadvance() end
    local x, y = F.pos()
    if not reachedCrest and x == CREST[1] and y == CREST[2] then reachedCrest = true end
    if idx <= #STOPS and x == STOPS[idx][1] and y == STOPS[idx][2] then
      seen[idx] = f
      F.L(string.format("  stop %d %s reached at frame %d", idx, STOP_NAMES[idx], f))
      -- Arriving on the stop tile is the END of that leg's applymovement, so the stop's own
      -- message box opens right after. Hold still for it and shoot: "each stop with its
      -- dialogue" is an acceptance clause, and only a screenshot can evidence the text.
      F.idle(90)
      F.shot(string.format("stop%d", idx))
      idx = idx + 1
    end
    if idx > #STOPS then break end
  end
  F.check("accepting from the Curator walks the player back to the crest first", reachedCrest)
  for i = 1, #STOPS do
    F.check(string.format("stop %d: %s at (%d,%d)", i, STOP_NAMES[i], STOPS[i][1], STOPS[i][2]),
      seen[i] ~= nil, seen[i] and ("frame " .. seen[i]) or "never reached")
  end
  F.shot("stop7")

  drain(80, "tour_end")
  local ex, ey = F.pos()
  F.check("the tour ends at the flagship stairs (#59 stop 9)", ex == 4 and ey == 13, string.format("(%d,%d)", ex, ey))
  F.check("the player is released and free to walk", F.ensureFree())
  -- The guide CANNOT be checked live from here: the #59 tour ends at (4,13),
  -- eighteen columns from his (22,7) post, and the walk-away Depart carries him
  -- outside the object-spawn window, where the engine culls him from
  -- gObjectEvents. His setobjectxyperm still landed -- phase 4 warps back to
  -- the crest (six columns from the post) and proves position, facing AND the
  -- held-movement state on the respawned object.
  F.check("the flag stays set after a completed tour", flagGet(FLAG_HUB_INTRO_TOUR_DONE))
  F.shot("tour_end")

  ----------------------------------------------------------------------------------------------
  -- Phase 4 — reload the map: the guide must still be home, and nothing may re-trigger
  ----------------------------------------------------------------------------------------------
  F.L("== phase 4: map reload ==")
  F.check("warp out and back into the hub", F.warpTo(1, 0, 0, 0, 0, 0, 0, 0, 0, 100, 0, "hubReload"))
  F.idle(300)
  local gr = obj(CURATOR)
  F.check("guide is still at (22,7) after a map reload", gr ~= nil and gr.x == 22 and gr.y == 7, at(gr))
  F.check("guide still faces down after a map reload", gr ~= nil and gr.facing == DIR_SOUTH, at(gr))
  -- The issue-#42 trap: a stale held movement blocks the NEXT faceplayer outright.
  F.check("guide has no stale held movement after the escort", gr ~= nil and not gr.heldActive)
  F.check("no tour re-triggers on a later arrival at the crest", F.ensureFree())

  ----------------------------------------------------------------------------------------------
  -- Phase 5 — the walk-on coord_event, standing in for a legacy save that never saw the intro
  ----------------------------------------------------------------------------------------------
  F.L("== phase 5: walk-on crest trigger ==")
  flagClear(FLAG_HUB_INTRO_TOUR_DONE)
  F.check("flag cleared by hand to simulate a save that never saw the intro",
    not flagGet(FLAG_HUB_INTRO_TOUR_DONE))
  local wx, wy = F.pos()
  F.L(string.format("  standing at (%d,%d) before stepping south", wx, wy))
  F.step("Down")           -- onto (16,5): the southern crest coord_event
  F.idle(400)
  local sx, sy = F.pos()
  F.check("the southern crest trigger steps the player up onto (16,4)", sx == CREST[1] and sy == CREST[2],
    string.format("(%d,%d)", sx, sy))
  local gw = obj(CURATOR)
  F.check("the walk-on trigger brings the guide over to (17,4)", gw ~= nil and gw.x == 17 and gw.y == 4, at(gw))
  F.shot("walkon_offer")
  F.check("decline the walk-on offer", answer(1, "walkon-no"))
  drain(60, "walkon_decline")
  F.check("declining the walk-on offer re-sets the flag", flagGet(FLAG_HUB_INTRO_TOUR_DONE))
  F.check("the player is released after the walk-on decline", F.ensureFree())
  local gf = obj(CURATOR)
  F.check("guide is home again after the walk-on decline", gf ~= nil and gf.x == 22 and gf.y == 7, at(gf))

  ----------------------------------------------------------------------------------------------
  -- Phase 6 — the OTHER crest coord_event, the one on (16,4) itself
  ----------------------------------------------------------------------------------------------
  -- Phase 5 came in over (16,5). (16,4) is a separate coord_event with its own script, and it is
  -- the one the acceptance criteria name ("crossing (16,4) fires it once"), so walk onto it
  -- sideways rather than assuming the two entry points behave alike.
  F.L("== phase 6: the (16,4) crest coord_event, entered from the west ==")
  flagClear(FLAG_HUB_INTRO_TOUR_DONE)
  F.check("step west off the crest", F.step("Left"))
  local ox, oy = F.pos()
  F.check("standing beside the crest at (15,4)", ox == 15 and oy == 4, string.format("(%d,%d)", ox, oy))
  F.step("Right")
  F.idle(400)
  local cx, cy = F.pos()
  F.check("walking east onto (16,4) fires the crest trigger", cx == CREST[1] and cy == CREST[2],
    string.format("(%d,%d)", cx, cy))
  local gc = obj(CURATOR)
  F.check("the (16,4) trigger brings the guide over", gc ~= nil and gc.x == 17 and gc.y == 4, at(gc))
  F.check("decline the (16,4) offer", answer(1, "crest164-no"))
  drain(60, "crest164_decline")
  F.check("declining the (16,4) offer sets the flag", flagGet(FLAG_HUB_INTRO_TOUR_DONE))
  F.check("the player is released after the (16,4) decline", F.ensureFree())

  ----------------------------------------------------------------------------------------------
  -- Phase 7 — the Curator entry from a DIFFERENT adjacent tile
  ----------------------------------------------------------------------------------------------
  -- Phase 3 accepted from (22,6), which needs no normalisation. (21,7) and (23,7) are the only
  -- other tiles a player can talk to him from, and they take the two branches that step the
  -- player onto (22,6) first. Exercise the west one live; the east one is the mirror.
  F.L("== phase 7: Curator entry normalised from (21,7) ==")
  flagClear(FLAG_HUB_INTRO_TOUR_DONE)
  F.check("route to the west-side talk tile", F.route({ { 21, 4 }, { 21, 7 } }, "toCuratorWest"))
  local wx2, wy2 = F.pos()
  F.check("standing west of the Curator at (21,7)", wx2 == 21 and wy2 == 7, string.format("(%d,%d)", wx2, wy2))
  F.face("Right")
  F.press("A", 2); F.idle(60)
  F.check("accept the tour from (21,7)", answer(0, "west-yes"))
  local seen2, idx2, crest2 = {}, 1, false
  for f = 1, 20000 do
    if f % 24 == 0 then F.press("B", 2) else joypad.set({}); emu.frameadvance() end
    local x, y = F.pos()
    if not crest2 and x == CREST[1] and y == CREST[2] then crest2 = true end
    if idx2 <= #STOPS and x == STOPS[idx2][1] and y == STOPS[idx2][2] then seen2[idx2] = f; idx2 = idx2 + 1 end
    if idx2 > #STOPS then break end
  end
  F.check("the (21,7) branch normalises the player onto the crest", crest2)
  local allStops = true
  for i = 1, #STOPS do if seen2[i] == nil then allStops = false end end
  F.check("all nine stops still run in order from the (21,7) entry", allStops)
  drain(80, "west_tour_end")
  local wex, wey = F.pos()
  F.check("the (21,7) escort also ends at the flagship stairs", wex == 4 and wey == 13, string.format("(%d,%d)", wex, wey))
  F.check("the player is released after the (21,7) escort", F.ensureFree())
  -- Same spawn-window reality as phase 3: verify the guide from the crest.
  F.check("warp back for the guide check", F.warpTo(1, 0, 0, 0, 0, 0, 0, 0, 0, 100, 0, "westGuide"))
  F.idle(240)
  local gw2 = obj(CURATOR)
  F.check("guide is home after the (21,7) escort", gw2 ~= nil and gw2.x == 22 and gw2.y == 7, at(gw2))
  F.shot("west_entry_end")

  F.finish()
end)
