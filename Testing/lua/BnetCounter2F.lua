-- POKéMON CENTER 2F Battle Net counter (issue #42). Evidence suite.
--
-- Proves the 2F rewire on BOTH layouts, which differ (Hoenn LAYOUT_POKEMON_CENTER_2F put the old
-- floor terminal at (11,4); FRLG LAYOUT_POKEMON_CENTER_2F_FRLG at (11,5)):
--   * the floor-standing sim attendant is gone and the room is down to 4 NPCs
--   * the Union Room slot (6,2) opens the Scaling Type Trainer DIRECTLY
--   * the Direct Corner slot (10,2) opens the Leader Sim DIRECTLY
--   * backing out of either picker returns control with no orphaned lock
--   * a real Scaling match pays 1 BP and comes back to "Run another simulation?"
--
-- How the first two are proved rather than assumed: the menus have different row counts, and the
-- cursor is read out of menu.c's sMenu rather than counted blind. The combined menu this replaced
-- (MULTI_BNET_SIM_MENU) has 3 rows, so a cursor that reaches row 7 can only be the 8-row type
-- picker and one that reaches row 3 can only be the 4-row region picker. Neither is reachable
-- through the old wiring, so these are positive checks, not absence-of-menu guesses.
--
-- The Scaling match is the regression test for the refactor: the payout body moved into
-- BattleNet_EventScript_ScalingRun, which both entry points now `call` across a battle's
-- waitstate. If that call/return did not survive the battle, the "Run another simulation?"
-- prompt would never appear.
--
-- Run against a THROWAWAY COPY -- lib.new() refuses anything not named Verify*/MigChk*/FixGen*:
--   make -j12                                     # keeps symbols.lua bound to this ROM
--   cp <repo>/pokemonworld.gba  BizHawk\Verify1.gba
--   EmuHawk.exe BizHawk\Verify1.gba --lua=<repo>\Testing\lua\BnetCounter2F.lua
local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(require("symbols"), "BnetCounter2F")

-- Both 2F layouts. Digits are the debug warp spinner's hundreds/tens/ones.
local MAPS = {
  { tag = "Hoenn",  grp = 2,  map = 3, g = { 0, 0, 2 }, m = { 0, 0, 3 }, termY = 4 },
  { tag = "FRLG",   grp = 40, map = 6, g = { 0, 4, 0 }, m = { 0, 0, 6 }, termY = 5 },
}

local SCALING_SLOT   = { 6, 2 }    -- old Union Room attendant
local LEADERSIM_SLOT = { 10, 2 }   -- old Direct Corner attendant
local TYPE_EXIT      = 7           -- MULTI_BNET_TYPE_1: 6 types + MORE + EXIT
local REGION_EXIT    = 3           -- MULTI_BNET_REGION: HOENN/JOHTO/KANTO + EXIT
local OPP_PARTY      = 6 * 100     -- gParties is [player][6] then [opponent][6]

-- Walk in front of a counter slot and face it.
--
-- The attendants stand at y=2 BEHIND a counter at y=3, so the player talks from y=4 and never
-- occupies y=3 at all. That still reaches them: field_control_avatar.c:416 explicitly "looks for
-- an object event on the other side of the counter" when the faced tile is MB_COUNTER, which is
-- how every Poké Mart clerk and cable-club attendant is talked to.
--
-- Approach along the y=6 corridor rather than straight across y=4: leg() is a greedy axis-first
-- walk, not a pathfinder, and the Hoenn 2F layout blocks y=4 around x=8 (measured -- the first
-- run got stuck at (7,4) trying to walk right).
local function faceSlot(slot, tag)
  local px = select(1, F.pos())
  if not F.route({ { px, 6 }, { slot[1], 6 }, { slot[1], slot[2] + 2 } }, tag) then return false end
  F.face("Up")
  return true
end

-- Seed a party. Debug root row 3 = "Give X...", submenu row 1 = "Pokemon (Basic)", then a species
-- spinner and a level spinner.
--
-- NOT "Party... > Set Party": that path was tried first and silently gave nothing (partyCount
-- stayed 0), which is the documented debug-submenu hazard -- cursor state persists between opens,
-- so a blind Down count can land on the wrong row and the action never fires. This Give X route is
-- the one the earlier Battle Net suites actually drove. Either way the caller must assert the
-- party arrived rather than trust the navigation.
local function giveMon(sh, st, so, lh, lt, lo)
  F.dbg(); F.sel(3); F.sel(1); F.idle(20)
  F.spin(sh, st, so); F.idle(20)
  F.spin(lh, lt, lo); F.idle(60)
  F.bOut(4)
end

-- Is there an active object event on this tile (ignoring the player at index 0)?
local function npcAt(objs, x, y)
  for _, o in ipairs(objs) do
    if o.i ~= 0 and o.x == x and o.y == y then return o end
  end
  return nil
end

-- Every (id, qty) in every bag pocket, as one comparable string. Used to prove the Leader Sim
-- hands out NOTHING but BP: the shard/stone economy is supposed to stay on real gym rematches,
-- so a sim win must leave the bag byte-identical. Comparing whole pockets catches a stray stone
-- or shard of ANY id, which checking one known item id would not.
--
-- ★ The quantity MUST be decrypted. ItemSlot.quantity is stored XORed with
-- gSaveBlock2Ptr->encryptionKey (src/item.c:70), and MoveSaveBlocks_ResetHeap() draws a NEW key
-- from Random32() and re-encrypts the whole bag — and it runs on both battle entry
-- (battle_main.c:482) and the return to the field (overworld.c:2694). So the raw ciphertext of an
-- unchanged item is guaranteed to differ either side of any battle, which is exactly the span this
-- check straddles. Comparing raw quantities reported a phantom shard payout the first time the
-- Scaling match's 30% shard roll actually landed; before that the bag was empty at both snapshots,
-- the two strings were both "" and the check had been passing vacuously.
local function bagSnapshot()
  local out = {}
  local key = F.r32(F.sb2() + S.SaveBlock2.encryptionKey) & 0xFFFF
  for p = 0, 4 do
    local ptr = F.r32(S.gBagPockets + p * S.BagPocket.stride)
    local cap = F.pocketCap(p)
    if ptr >= 0x02000000 and ptr < 0x02040000 and cap > 0 and cap < 256 then
      for s = 0, cap - 1 do
        local id, qty = F.r16(ptr + s * 4), F.r16(ptr + s * 4 + 2) ~ key
        if id ~= 0 then out[#out + 1] = ("%d:%d=%d"):format(p, id, qty) end
      end
    end
  end
  return table.concat(out, ",")
end

-- Set a flag directly in SaveBlock1.flags (FlagGet reads this array, so the script sees it).
local function setFlag(n)
  local a = F.sb1() + S.SaveBlock1.flags + math.floor(n / 8)
  F.w8(a, F.r8(a) | (1 << (n % 8)))
end

-- Wait for a battle to come up, TAPPING A while waiting rather than idling.
-- Idling alone is not enough: the leader-sim path puts a message between the picker and the
-- battle, so a pure idle loop sits on an unadvanced msgbox until it times out and reports "no
-- battle" for a battle that was only ever waiting on the player.
local function waitBattle(tag)
  for _ = 1, 40 do
    if F.battlers() > 0 and not F.ow() then return true end
    F.tap("A"); F.idle(30)
  end
  F.shot(tag .. "_nobattle")
  return false
end

-- Win the current battle and come back. NoAliveMonsForOpponent sums the opponent PARTY, not
-- gBattleMons, so zeroing the on-screen foe alone shows 0 HP and never ends the battle.
--
-- The lead is also kept topped up every iteration. Without that the leader sim came back
-- B_OUTCOME_DREW (3) rather than WON: against a real gym-leader party the single test mon can
-- faint in the same window the opponent is zeroed, and the engine scores both-sides-empty as a
-- draw, which pays no BP. Holding the player's party HP above zero makes the win unambiguous.
local function winBattle()
  F.idle(240)
  local function forceWin()
    for i = 0, 5 do F.w16(S.gParties + OPP_PARTY + i * S.Pokemon.size + S.Pokemon.hp, 0) end
    local mx = F.r16(S.gParties + S.Pokemon.maxHP)
    if mx > 0 then F.w16(S.gParties + S.Pokemon.hp, mx) end
  end
  forceWin()
  for _ = 1, 1200 do
    if F.ow() then return true end
    forceWin()
    F.press("A", 2); F.idle(6)
  end
  return false
end

-- Leave whatever dialogue is open and prove the player actually has control again. This is the
-- orphaned-lock check: a script that locked and never released leaves the player unable to step,
-- and ensureFree() only returns true if a Left/Right round trip really moved them and came back.
local function freeAgain(name)
  F.dismiss(20)
  return F.check(name .. ": control returns, no orphaned lock", F.ensureFree())
end

F.run(function()
  if not F.boot(100) then F.check("boot to overworld", false); F.finish(); return end

  -- A party is needed before the Leader Sim will show its region picker: LeaderSim runs
  -- CheckBattleNetRuleParty first and an empty party diverts to the "no battle-ready POKéMON"
  -- error. Species 375 at Lv100 -- Gen 3, always battle-ready, and high enough that the Scaling
  -- opponent it scales to is a real battle rather than a level-floor edge case.
  giveMon(3, 7, 5, 1, 0, 0)
  local pc = F.r8(S.gPartiesCount)
  -- Assert the precondition really took. A silently-empty party would make every later check fail
  -- for the wrong reason and read as a regression in the thing under test.
  if not F.check("debug gave a party", pc > 0, "count=" .. pc) then F.finish(); return end

  for _, M in ipairs(MAPS) do
    F.L(("== %s 2F (group %d, map %d) =="):format(M.tag, M.grp, M.map))
    if not F.warpTo(M.g[1], M.g[2], M.g[3], M.m[1], M.m[2], M.m[3], 0, 0, 0, M.grp, M.map, M.tag) then
      F.check(M.tag .. ": warped to the 2F", false)
    else
      F.check(M.tag .. ": warped to the 2F", true)

      -- The floor NPC is gone. Checked by TILE, not by object count: the player now has a party,
      -- so a follower object may also be on the map and a bare count would move for that reason.
      local objs = F.objdump()
      local dump = {}
      for _, o in ipairs(objs) do dump[#dump + 1] = ("%d:(%d,%d)"):format(o.i, o.x, o.y) end
      F.L("  objects: " .. table.concat(dump, " "))
      local onTerm = npcAt(objs, 11, M.termY)
      F.check(("%s: no NPC left at the old terminal tile (11,%d)"):format(M.tag, M.termY),
        onTerm == nil, onTerm and ("obj " .. onTerm.i .. " still there") or "clear")

      -- (6,2): the Scaling Type Trainer, entered directly. Reaching cursor row 7 proves the
      -- 8-row type picker opened; the 3-row combined menu could never get there.
      if F.check(M.tag .. ": reached the Scaling slot", faceSlot(SCALING_SLOT, M.tag .. "_scaling")) then
        F.tap("A")
        F.check(M.tag .. ": Scaling slot opens the TYPE PICKER, not the 2-option menu",
          F.pick(TYPE_EXIT, M.tag .. "_typepicker", 10))
        F.shot(M.tag .. "_scaling_cancel")
        freeAgain(M.tag .. " Scaling cancel")
      end

      -- (10,2): the Leader Sim, entered directly. Reaching cursor row 3 proves the 4-row region
      -- picker opened -- again out of reach for the 3-row combined menu.
      if F.check(M.tag .. ": reached the Leader Sim slot", faceSlot(LEADERSIM_SLOT, M.tag .. "_leadersim")) then
        F.tap("A")
        F.check(M.tag .. ": Leader Sim slot opens the REGION PICKER, not the 2-option menu",
          F.pick(REGION_EXIT, M.tag .. "_regionpicker", 10))
        F.shot(M.tag .. "_leadersim_cancel")
        freeAgain(M.tag .. " Leader Sim cancel")
      end

      -- The Wireless Club slot the issue put out of scope must still be standing.
      F.check(M.tag .. ": Wireless Club attendant still at (2,2)", npcAt(objs, 2, 2) ~= nil)
      -- The Mystery Gift man at (1,2) is deliberately NOT asserted present: his object carries
      -- FLAG_HIDE_POKEMON_CENTER_2F_MYSTERY_GIFT_MAN (FLAG_HIDE_MG_DELIVERYMEN on FRLG), so on a
      -- fresh save he is not spawned at all. His map entry is checked statically instead; asserting
      -- him here would fail for a vanilla reason that has nothing to do with this change.
      F.check(M.tag .. ": Mystery Gift man is flag-hidden, not deleted", npcAt(objs, 1, 2) == nil)
      -- ...and the two converted slots are still occupied (a botched edit could drop an NPC).
      F.check(M.tag .. ": Scaling slot occupied at (6,2)", npcAt(objs, 6, 2) ~= nil)
      F.check(M.tag .. ": Leader Sim slot occupied at (10,2)", npcAt(objs, 10, 2) ~= nil)
    end
  end

  -- Regression test for the shared-body refactor, on the Hoenn layout. Drive one real Scaling
  -- match to completion and confirm the script comes back out of the `call`.
  F.L("== Scaling match: call/return across a battle ==")
  if F.warpTo(0, 0, 2, 0, 0, 3, 0, 0, 0, 2, 3, "rematch") and faceSlot(SCALING_SLOT, "battle") then
    local bp0 = F.bp()
    F.tap("A")
    if F.check("type picker opened for the match", F.pick(0, "pick_NORMAL", 10)) then
      -- Wait for the battle to start, then win it. NoAliveMonsForOpponent sums the opponent PARTY,
      -- not gBattleMons, so zeroing the on-screen foe is not enough -- all 6 party slots must go.
      local started = waitBattle("scaling")
      F.check("Scaling match launched a battle", started, "flags=" .. string.format("%08X", F.battleFlags()))
      if started then
        F.check("battle ended and returned to the overworld", winBattle())
        local outcome = F.outcome()
        F.check("the match was won (B_OUTCOME_WON)", outcome == 1, "gBattleOutcome=" .. outcome)
        -- THE refactor check. "Run another simulation?" is only reachable by returning out of
        -- BattleNet_EventScript_ScalingRun, so if the call/return did not survive the battle's
        -- waitstate this prompt never appears. Row 1 is NO.
        F.check("script returned from ScalingRun to the retry prompt", F.pick(1, "another_no", 16))
        -- Read BP only after the prompt: AddBattleNetPoints runs before it, so by here the award
        -- has definitely happened and this cannot race the script.
        F.idle(90)
        local bp1 = F.bp()
        F.check("Scaling win paid 1 BP", bp1 == bp0 + 1, ("bp %d -> %d"):format(bp0, bp1))
        F.shot("scaling_after_match")
        freeAgain("Scaling match")
      end
    end
  else
    F.check("re-reached the Scaling slot for the match", false)
  end

  -- The Leader Sim end-to-end, from the converted counter slot. The region picker is gated on
  -- that region's championship, so grant FLAG_HOENN_CHAMPION (0xA4A) first -- a fresh save has
  -- none and would only ever see the "not champion" message.
  --
  -- The payout invariant here is the one #5 P3 established and this issue must not disturb: a
  -- leader sim pays 2 BP and NOTHING else, so that the shard/stone economy stays on real gym
  -- rematches and cannot be farmed from a Pokémon Center couch.
  F.L("== Leader Sim: region -> leader -> battle, from the counter slot ==")
  setFlag(0xA4A)
  F.check("FLAG_HOENN_CHAMPION set for the gate",
    (F.r8(F.sb1() + S.SaveBlock1.flags + math.floor(0xA4A / 8)) & (1 << (0xA4A % 8))) ~= 0)
  if faceSlot(LEADERSIM_SLOT, "leadersim_battle") then
    local bp0, bag0 = F.bp(), bagSnapshot()
    F.tap("A")
    if F.check("region picker opened", F.pick(0, "pick_HOENN", 12))
       and F.check("leader picker opened", F.pick(0, "pick_ROXANNE", 12)) then
      local started = waitBattle("leadersim")
      F.check("Leader Sim launched a battle", started, "flags=" .. string.format("%08X", F.battleFlags()))
      if started then
        F.check("Leader Sim battle ended and returned to the overworld", winBattle())
        F.check("the leader sim was won", F.outcome() == 1, "gBattleOutcome=" .. F.outcome())
        F.check("returned to the leader-sim retry prompt", F.pick(1, "sim_another_no", 16))
        F.idle(90)
        local bp1, bag1 = F.bp(), bagSnapshot()
        F.check("Leader Sim win paid 2 BP", bp1 == bp0 + 2, ("bp %d -> %d"):format(bp0, bp1))
        -- Always print BOTH snapshots, including on a pass. The Scaling match above pays a shard
        -- only 30% of the time, so on most runs the bag is empty at both ends and this check is
        -- comparing "" with "" — a real pass and a vacuous one used to log the same word
        -- ("identical"). Printing the contents makes the difference visible in the log.
        F.check("Leader Sim win paid NO shard or stone (bag unchanged)", bag1 == bag0,
          ("before=[%s] after=[%s]"):format(bag0, bag1))
        F.shot("leadersim_after_match")
        freeAgain("Leader Sim match")
      end
    end
  else
    F.check("reached the Leader Sim slot for the match", false)
  end

  F.finish()
end)
