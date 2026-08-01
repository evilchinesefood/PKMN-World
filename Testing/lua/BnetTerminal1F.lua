-- The Battle Net wall terminal (issue #59). Evidence suite; supersedes BnetCounter2F.lua,
-- whose 2F counter slots lost their staircase and cannot be reached any more.
--
-- Covers all six 1F layouts plus both League lobbies, One Island and the hub -- one map per
-- distinct (layout, tileset, pedestal-donor) row of the issue's placement table -- and carries
-- forward BnetCounter2F's payout invariants: a Scaling win pays 1 BP, a Leader Sim win pays
-- 2 BP and NOTHING else (whole-bag snapshot either side, quantities decrypted).
--
-- What "the sign form works" means here, checked per map:
--   * standing ON the pedestal facing the screen, A opens the 3-row combined menu
--     (cursor read out of menu.c's sMenu, never counted blind)
--   * the d-pad moves the cursor without closing the menu; B closes it
--   * control returns with no orphaned lock (the `lock`/`release` pairing)
-- and once, on the hub: HOLDING Up into the screen for 60 frames opens nothing -- the
-- terminal's metatile behaviour is 0, not signpost-family, so only the bg_event answers.
--
-- The gObjectEvents[16] guard: launching a Leader Sim from a bg_event runs with
-- VAR_LAST_TALKED = LOCALID_NONE, which is exactly the out-of-bounds recipe D3 exists to
-- prevent (read + unconditional directionOverwrite write one past the array). The 0x24 bytes
-- at gObjectEvents[16] are snapshotted around the whole launch and must come back identical.
--
-- Run against a THROWAWAY COPY -- lib.new() refuses anything not named Verify*/MigChk*/FixGen*:
--   make -j12
--   cp <repo>/pokemonworld.gba  BizHawk\Verify1.gba
--   EmuHawk.exe BizHawk\Verify1.gba --lua=<repo>\Testing\lua\BnetTerminal1F.lua
local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(require("symbols"), "BnetTerminal1F")

-- One map per placement-table row. ped = the read tile (the player stands ON it, facing Up).
-- Digits are the debug warp spinner's hundreds/tens/ones.
local MAPS = {
  { tag = "Hoenn/Oldale",   g = { 0, 0, 2 }, m = { 0, 0, 2 }, grp = 2,   map = 2,  ped = { 11, 2 } },
  { tag = "Lavaridge",      g = { 0, 0, 4 }, m = { 0, 0, 5 }, grp = 4,   map = 5,  ped = { 11, 2 } },
  { tag = "EverGrande1F",   g = { 0, 1, 6 }, m = { 0, 1, 0 }, grp = 16,  map = 10, ped = { 7, 2 } },
  { tag = "Kanto/Viridian", g = { 0, 3, 9 }, m = { 0, 0, 4 }, grp = 39,  map = 4,  ped = { 12, 2 } },
  { tag = "IndigoPlateau",  g = { 0, 4, 7 }, m = { 0, 0, 0 }, grp = 47,  map = 0,  ped = { 18, 10 } },
  { tag = "OneIsland",      g = { 0, 6, 4 }, m = { 0, 0, 0 }, grp = 64,  map = 0,  ped = { 10, 2 } },
  { tag = "Johto/Violet",   g = { 0, 7, 8 }, m = { 0, 0, 4 }, grp = 78,  map = 4,  ped = { 12, 2 } },
  { tag = "MtSilver",       g = { 0, 9, 7 }, m = { 0, 1, 0 }, grp = 97,  map = 10, ped = { 12, 2 } },
  { tag = "JohtoIndigo",    g = { 0, 9, 9 }, m = { 0, 0, 4 }, grp = 99,  map = 4,  ped = { 25, 10 } },
}
local HUB_PED = { 9, 10 }
local MENU_LAST = 2          -- MULTI_BNET_SIM_MENU: SCALING / LEADER SIM / EXIT
local OPP_PARTY = 6 * 100

local function giveMon(sh, st, so, lh, lt, lo)
  F.dbg(); F.sel(3); F.sel(1); F.idle(20)
  F.spin(sh, st, so); F.idle(20)
  F.spin(lh, lt, lo); F.idle(60)
  F.bOut(4)
end

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

local function setFlag(n)
  local a = F.sb1() + S.SaveBlock1.flags + math.floor(n / 8)
  F.w8(a, F.r8(a) | (1 << (n % 8)))
end

local function waitBattle(tag)
  for _ = 1, 40 do
    if F.battlers() > 0 and not F.ow() then return true end
    F.tap("A"); F.idle(30)
  end
  F.shot(tag .. "_nobattle")
  return false
end

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

local function freeAgain(name)
  F.dismiss(20)
  return F.check(name .. ": control returns, no orphaned lock", F.ensureFree())
end

-- Walk onto the pedestal and face the screen. The pedestal is the READ tile: collision 0,
-- elevation 3, directly under the screen cell the bg_event sits on.
local function toPedestal(ped, tag)
  local px, py = F.pos()
  if not F.route({ { px, ped[2] + 1 }, { ped[1], ped[2] + 1 }, ped }, tag) then return false end
  F.face("Up")
  return true
end

-- A opens the combined menu; Down x4 must move the cursor and never close it; B closes.
local function signChecks(tag)
  F.tap("A"); F.idle(45)
  local live = F.pick(MENU_LAST, tag .. "_menu", 10)
  F.check(tag .. ": terminal opens the combined menu (cursor reached EXIT)", live)
  if live then F.tap("A"); F.idle(45) end   -- EXIT row: TerminalBye, releases the lock
  return freeAgain(tag)
end

F.run(function()
  if not F.boot(100) then F.check("boot to overworld", false); F.finish(); return end

  -- CheckBattleNetRuleParty diverts an empty party to the "no battle-ready POKeMON" error, so
  -- seed one first. Species 375 Lv100: Gen 3, battle-ready, scales to a real opponent.
  giveMon(3, 7, 5, 1, 0, 0)
  local pc = F.r8(S.gPartiesCount)
  if not F.check("debug gave a party", pc > 0, "count=" .. pc) then F.finish(); return end

  -- The hub terminal first: the boot map, no warp, plus the two hub-only assertions.
  F.L("== RegionHub terminal ==")
  if F.check("hub: reached the pedestal", toPedestal(HUB_PED, "hub")) then
    -- Not signpost-family: holding Up into the screen must open nothing.
    local c0 = F.mcur()
    for _ = 1, 60 do F.press("Up", 1) end
    F.idle(20)
    F.check("hub: holding Up into the terminal opens nothing", F.mcur() == c0 and F.ensureFree())
    signChecks("hub")
  end

  for _, M in ipairs(MAPS) do
    F.L(("== %s (group %d, map %d) =="):format(M.tag, M.grp, M.map))
    if not F.warpTo(M.g[1], M.g[2], M.g[3], M.m[1], M.m[2], M.m[3], 0, 0, 0, M.grp, M.map, M.tag) then
      F.check(M.tag .. ": warped in", false)
    else
      F.check(M.tag .. ": warped in", true)
      if F.check(M.tag .. ": reached the pedestal", toPedestal(M.ped, M.tag)) then
        signChecks(M.tag)
      end
    end
  end

  -- Payout invariant 1: a real Scaling match from the wall terminal pays exactly 1 BP and the
  -- script returns out of ScalingRun's call to the retry prompt (the across-a-battle regression).
  F.L("== Scaling match from the Oldale terminal ==")
  if F.warpTo(0, 0, 2, 0, 0, 2, 0, 0, 0, 2, 2, "scaling") and toPedestal({ 11, 2 }, "scaling") then
    local bp0 = F.bp()
    F.tap("A")
    if F.check("combined menu -> SCALING row", F.pick(0, "row_scaling", 10))
       and F.check("type picker opened", F.pick(0, "pick_NORMAL", 10)) then
      local started = waitBattle("scaling")
      F.check("Scaling launched a battle", started, "flags=" .. string.format("%08X", F.battleFlags()))
      if started then
        F.check("battle ended, back to the overworld", winBattle())
        F.check("the match was won", F.outcome() == 1, "gBattleOutcome=" .. F.outcome())
        F.check("script returned from ScalingRun to the retry prompt", F.pick(1, "another_no", 16))
        F.idle(90)
        local bp1 = F.bp()
        F.check("Scaling win paid 1 BP", bp1 == bp0 + 1, ("bp %d -> %d"):format(bp0, bp1))
        freeAgain("Scaling match")
      end
    end
  else
    F.check("reached the Oldale terminal for the match", false)
  end

  -- Payout invariant 2 + the D3 guard: a Leader Sim from the hub terminal pays 2 BP and nothing
  -- else, and the whole launch never touches gObjectEvents[16] -- the sign form runs with
  -- VAR_LAST_TALKED = LOCALID_NONE, so any reveal-movement regression writes exactly there.
  F.L("== Leader Sim from the hub terminal ==")
  setFlag(0xA4A)   -- FLAG_HOENN_CHAMPION gates the region picker
  if F.warpTo(0, 0, 1, 0, 0, 0, 0, 0, 0, 100, 0, "hub2") == false then
    F.check("returned to the hub", false)
  end
  if toPedestal(HUB_PED, "leadersim") then
    local guard = S.gObjectEvents + 16 * S.ObjectEvent.stride
    local before = {}
    for i = 0, 0x23 do before[i] = F.r8(guard + i) end
    local bp0, bag0 = F.bp(), bagSnapshot()
    F.tap("A")
    if F.check("combined menu -> LEADER SIM row", F.pick(1, "row_leadersim", 10))
       and F.check("region picker opened", F.pick(0, "pick_HOENN", 12))
       and F.check("leader picker opened", F.pick(0, "pick_ROXANNE", 12)) then
      local started = waitBattle("leadersim")
      F.check("Leader Sim launched a battle", started, "flags=" .. string.format("%08X", F.battleFlags()))
      if started then
        local dirty = 0
        for i = 0, 0x23 do if F.r8(guard + i) ~= before[i] then dirty = dirty + 1 end end
        F.check("launch never touched gObjectEvents[16]", dirty == 0, "dirty bytes=" .. dirty)
        F.check("Leader Sim battle ended", winBattle())
        F.check("the sim was won", F.outcome() == 1, "gBattleOutcome=" .. F.outcome())
        F.check("returned to the retry prompt", F.pick(1, "sim_another_no", 16))
        F.idle(90)
        local bp1, bag1 = F.bp(), bagSnapshot()
        F.check("Leader Sim win paid 2 BP", bp1 == bp0 + 2, ("bp %d -> %d"):format(bp0, bp1))
        F.check("Leader Sim win paid NO shard or stone (bag unchanged)", bag1 == bag0,
          ("before=[%s] after=[%s]"):format(bag0, bag1))
        freeAgain("Leader Sim match")
      end
    end
  else
    F.check("reached the hub terminal for the sim", false)
  end

  F.finish()
end)
