-- The event-island legendaries that have a twin in another region (Deoxys on both Birth Islands,
-- Ho-Oh and Lugia on both Navel Rocks), played with real input.
--
-- Deoxys knows Teleport at level 30 under the Gen 9 learnsets. When it teleports away the battle
-- ends with B_OUTCOME_MON_TELEPORTED, which is neither caught nor beaten: Deoxys must leave the
-- field, stay unmarked and come back on the next visit. Then a Master Ball (the R shortcut) catches
-- it, and the other region's Birth Island must not offer a second Deoxys. Kanto's Navel Rock Ho-Oh
-- and Lugia are caught with a full party (the catch goes to the PC), and Hoenn's Navel Rock must
-- not offer a second one of either.
--
-- Run via test/overworld/mgba-run.sh test/overworld/lua/LegendWorldGuards.lua <rom>

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "LegendWorldGuards")

local HUB = 100
local BIRTH_HOENN = { 26, 58 }
local BIRTH_HOENN_HARBOR = { 26, 59 }
local BIRTH_KANTO = { 36, 56 }
local BIRTH_KANTO_HARBOR = { 36, 57 }
local NAVEL_KANTO_SUMMIT = { 36, 37 }
local NAVEL_KANTO_BASE = { 36, 38 }
local NAVEL_HOENN_TOP = { 26, 75 }
local NAVEL_HOENN_BOTTOM = { 26, 87 }
local MT_SILVER_WATERFALL = { 97, 1 }
local MT_SILVER_MOLTRES = { 97, 2 }
local SPECIES_MOLTRES, MOVE_ROAR, OUTCOME_PLAYER_TELEPORTED = 146, 46, 5
local FLAG_HIDE_MOLTRES, FLAG_FOUGHT_MOLTRES = 0xA40 + 0x52, 0xA40 + 0x2BD
local LOCALID_MOLTRES = 1

local SPECIES_SNORLAX, SPECIES_DEOXYS, SPECIES_LUGIA, SPECIES_HO_OH = 143, 386, 249, 250
local MOVE_CELEBRATE = 606
local ITEM_MASTER_BALL = 4
local POCKET_BALLS = 1
local OUTCOME_CAUGHT, OUTCOME_MON_TELEPORTED = 7, 10
local MON = S.Pokemon.size
local BOXES, PER_BOX = 14, 30

local FLAG_CAUGHT_LUGIA, FLAG_CAUGHT_HO_OH = 0x91, 0x92
local FLAG_DEFEATED_DEOXYS, FLAG_BATTLED_DEOXYS = 0x1AC, 0x1AD
local FLAG_HIDE_DEOXYS, FLAG_HIDE_HOENN_ROCK = 0x2FB, 0x2FC
local FLAG_HIDE_LUGIA, FLAG_HIDE_HO_OH = 0x320, 0x321
local FLAG_HIDE_KANTO_ROCK = 0xA40 + 0x9A
local FLAG_FOUGHT_DEOXYS, FLAG_DEOXYS_FLEW_AWAY = 0xA40 + 0x2E4, 0xA40 + 0x2F7
local FLAG_FOUGHT_LUGIA, FLAG_FOUGHT_HO_OH = 0xA40 + 0x2F2, 0xA40 + 0x2F3
local VAR_DEOXYS_ROCK_LEVEL, VAR_REPEL_STEP_COUNT = 0x4035, 0x4021
local LOCALID_ROCK, LOCALID_DEOXYS, LOCALID_NAVEL = 1, 2, 1
local CONTEXT_RUNNING = 0

-- Rock positions by level (src/field_specials.c sDeoxysRockCoords) and, for each, the tile the
-- player talks from and the facing. Every leg is a shortest path inside the step limit.
local ROCK_TALK = {
  { 15, 13, "Up" }, { 12, 14, "Left" }, { 15, 9, "Up" }, { 19, 13, "Down" }, { 13, 11, "Left" },
  { 17, 11, "Right" }, { 15, 13, "Down" }, { 12, 14, "Left" }, { 18, 14, "Right" }, { 15, 14, "Down" },
  { 15, 11, "Up" },
}

local function where() local x, y = F.pos(); return string.format("%d/%d (%d,%d)", F.grp(), F.mapn(), x, y) end
local function partyCount() return F.r8(S.gPartiesCount) end
local function flagAddr(id) return F.sb1() + S.SaveBlock1.flags + id // 8, 1 << (id % 8) end
local function flagGet(id) local a, b = flagAddr(id); return F.r8(a) & b ~= 0 end
local function flagClear(id) local a, b = flagAddr(id); F.w8(a, F.r8(a) & ~b & 0xFF) end
local function varGet(id) return F.r16(F.sb1() + S.SaveBlock1.vars + (id - 0x4000) * 2) end
local function varSet(id, v) F.w16(F.sb1() + S.SaveBlock1.vars + (id - 0x4000) * 2, v) end
local function tap(key, wait) F.press(key, 2); F.idle(wait or 20) end
local function warp(map, tag)
  local g, m = map[1], map[2]
  return F.warpTo(g // 100, (g // 10) % 10, g % 10, m // 100, (m // 10) % 10, m % 10, 0, 0, 0, g, m, tag)
end

local SCRIPT_BUF = S.gStringVar4 + 960
local function le16(t, v) t[#t + 1] = v & 0xFF; t[#t + 1] = (v >> 8) & 0xFF end
local function le32(t, v) le16(t, v & 0xFFFF); le16(t, (v >> 16) & 0xFFFF) end
local function runScript(bytes)
  for i, b in ipairs(bytes) do F.w8(SCRIPT_BUF + i - 1, b) end
  F.w8(S.sGlobalScriptContext, 0)
  F.w8(S.sGlobalScriptContext + 1, 1)
  F.w32(S.sGlobalScriptContext + 4, 0)
  F.w32(S.sGlobalScriptContext + S.ScriptCtx.scriptPtr, SCRIPT_BUF)
  F.w8(S.sGlobalScriptContextStatus, CONTEXT_RUNNING)
  F.idle(20)
end
local function createMon(species, level, moves)
  local b = { 0x23 }; le32(b, S.ScrCmd_createmon | 1)
  b[#b + 1] = 0; b[#b + 1] = 6
  le16(b, species); le16(b, level)
  le32(b, (1 << 17) | (1 << 18) | (1 << 19) | (1 << 20))
  for k = 1, 4 do le16(b, moves[k] or 0) end
  b[#b + 1] = 0x02
  runScript(b)
  return partyCount()
end
-- Gen 8 obedience goes by met level for the player's own Pokemon, so a met level of 1 lets a
-- level 100 lead act with no badges.
local function setMetLevelOne(slot)
  local a = S.gParties + slot * MON
  local pers, otid = F.r32(a), F.r32(a + 4)
  local key = pers ~ otid
  local w = {}
  for k = 0, 11 do w[k] = F.r32(a + 32 + k * 4) ~ key end
  local s3 = F.r8(S.sSubstructOffsets + 72 + pers % 24) * 3
  w[s3] = (w[s3] & ~(0x7F << 16)) | (1 << 16)
  local sum = 0
  for k = 0, 11 do
    sum = sum + (w[k] & 0xFFFF) + ((w[k] >> 16) & 0xFFFF)
    F.w32(a + 32 + k * 4, (w[k] ~ key) & 0xFFFFFFFF)
  end
  F.w16(a + 28, sum & 0xFFFF)
end
local function party(n, move)
  F.dbg(); F.sel(2); F.sel(8); F.bOut(4)   -- Party > Clear Party
  for i = 1, n do createMon(SPECIES_SNORLAX, 100, { move or MOVE_CELEBRATE }); setMetLevelOne(i - 1) end
  return partyCount() == n
end

local function qtyKey() return F.r32(F.sb2() + S.SaveBlock2.encryptionKey) & 0xFFFF end
local function setMasterBalls(qty)
  local ptr, cap = F.r32(S.gBagPockets + POCKET_BALLS * S.BagPocket.stride), F.pocketCap(POCKET_BALLS)
  for s = 0, cap - 1 do F.w16(ptr + s * 4, 0); F.w16(ptr + s * 4 + 2, qtyKey()) end
  F.w16(ptr, ITEM_MASTER_BALL); F.w16(ptr + 2, qty ~ qtyKey())
end
local function boxed()
  local storage, n = F.r32(S.gPokemonStoragePtr), 0
  for s = 0, BOXES * PER_BOX - 1 do
    local a = storage + 4 + s * S.BoxPokemon.size
    if F.r32(a) ~= 0 or F.r32(a + 4) ~= 0 then n = n + 1 end
  end
  return n
end

local function objByLocal(id)
  for i = 0, 15 do
    local o = S.gObjectEvents + i * S.ObjectEvent.stride
    if (F.r8(o) & 1) ~= 0 and F.r8(o + 8) == id then return o end
  end
end
local function visible(id)
  local o = objByLocal(id)
  return o ~= nil and (F.r8(o + 1) >> 5) & 1 == 0
end
local function scriptIdle() return F.ow() and F.r8(S.sGlobalScriptContextStatus) ~= CONTEXT_RUNNING end
local function hasControl() return scriptIdle() and F.r8(S.sLockFieldControls) == 0 end
local function inBattle() return F.cb2() == (S.BattleMainCB2 & ~1) end

local function walkTo(tx, ty, tag)
  for _ = 1, 60 do
    local x, y = F.pos()
    if x == tx and y == ty then return true end
    local dir
    if x < tx then dir = "Right" elseif x > tx then dir = "Left"
    elseif y < ty then dir = "Down" else dir = "Up" end
    if not F.step(dir) then F.L("  walk " .. tag .. " blocked at " .. where()); F.shot(tag .. "_blocked"); return false end
  end
  return false
end

-- Battle driving, steered by the controller state rather than by frame counts.
local function actionReady()
  local fn = F.r32(S.gBattlerControllerFuncs) & ~1
  for _, p in ipairs(S.ActionInputFunctions) do if fn == p then return true end end
  return false
end
local function awaitAction()
  for _ = 1, 600 do
    if actionReady() then F.idle(10); return true end
    if not inBattle() then return false end
    tap("B", 10)
  end
  return false
end
local function chooseAction(index)
  for _ = 1, 8 do
    local cursor = F.r8(S.gActionSelectionCursor)
    if cursor == index then break end
    if (cursor & 1) ~= (index & 1) then tap((index & 1) == 0 and "Left" or "Right", 14)
    else tap((index & 2) == 0 and "Up" or "Down", 14) end
  end
  tap("A")
end
local function inMoveMenu() return (F.r32(S.gBattlerControllerFuncs) & ~1) == S.HandleInputChooseMove end
local function fightFirstMove()
  chooseAction(0)
  for _ = 1, 120 do if inMoveMenu() then break end F.idle(2) end
  F.idle(20)
  for _ = 1, 5 do
    tap("A", 30)
    if not inMoveMenu() then return end
  end
end
local function finishBattle(tag)
  for _ = 1, 3000 do
    if F.reportCrash(tag) then return false end
    if not inBattle() and hasControl() then F.idle(30); return true end
    tap("B", 10)
  end
  F.shot(tag .. "_stuck")
  return false
end
local function foeSpecies() return F.r16(S.gBattleMons + S.BattlePokemon.size) end
local function awaitBattle(tag, species)
  for i = 1, 1500 do
    if inBattle() and F.battlers() > 0 and foeSpecies() == species then return true end
    if i % 30 == 0 then F.press("A", 2) else F.idle(1) end
    if i % 300 == 0 and F.reportCrash(tag) then return false end
  end
  F.shot(tag .. "_no_battle")
  return false
end
local function catchWithR(tag)
  if not awaitAction() then return false end
  F.press("R", 4); F.idle(240)
  local ok = finishBattle(tag)
  return ok and F.outcome() == OUTCOME_CAUGHT
end

local function solvePuzzle(tag)
  for level = 0, 10 do
    local t = ROCK_TALK[level + 1]
    if not walkTo(t[1], t[2], tag .. "_rock" .. level) then return false end
    F.face(t[3])
    if level < 10 then
      F.press("A", 3)
      for _ = 1, 300 do if hasControl() and varGet(VAR_DEOXYS_ROCK_LEVEL) == level + 1 then break end; F.idle(1) end
      if varGet(VAR_DEOXYS_ROCK_LEVEL) ~= level + 1 then F.shot(tag .. "_rock" .. level .. "_failed"); return false end
      for _ = 1, 120 do if hasControl() then break end; F.idle(1) end
    end
  end
  F.w16(S.gBattleMons + S.BattlePokemon.size, 0)
  F.press("A", 3)
  return awaitBattle(tag, SPECIES_DEOXYS)
end

local function reenter(island, harbor, tag)
  local ok = warp(harbor, tag .. "_out") and warp(island, tag .. "_in")
  F.idle(60)
  return ok
end

-- One island: Deoxys teleports away, comes back on the next visit, then is caught.
local function deoxysIsland(tag, island, harbor, rockFlag, markFlag)
  F.check(tag .. ": a level 100 Snorlax that only celebrates", party(1))
  F.check(tag .. ": warped to Birth Island", warp(island, tag), where())
  F.idle(60)
  F.check(tag .. ": the puzzle is offered", not flagGet(rockFlag))
  F.check(tag .. ": the puzzle opens a Deoxys battle", solvePuzzle(tag))
  F.shot(tag .. "_battle")

  local turns = 0
  while turns < 60 and awaitAction() do
    fightFirstMove()
    turns = turns + 1
  end
  F.check(tag .. ": back on the field after the battle", finishBattle(tag .. "_teleport"))
  F.L(string.format("  %s: battle ended after %d turn(s), outcome=%d", tag, turns, F.outcome()))
  F.check(tag .. ": Deoxys teleported away", F.outcome() == OUTCOME_MON_TELEPORTED, "outcome=" .. F.outcome())
  F.shot(tag .. "_after_teleport")
  F.check(tag .. ": the Deoxys object left the field", not visible(LOCALID_DEOXYS))
  F.check(tag .. ": a teleported Deoxys is not marked caught", not flagGet(markFlag)
    and not flagGet(FLAG_BATTLED_DEOXYS) and not flagGet(FLAG_FOUGHT_DEOXYS))

  F.check(tag .. ": left and came back", reenter(island, harbor, tag .. "_return"), where())
  local back = not flagGet(rockFlag)
  F.check(tag .. ": the puzzle is offered again on the next visit", back)
  if not back then
    flagClear(FLAG_BATTLED_DEOXYS); flagClear(FLAG_FOUGHT_DEOXYS)
    reenter(island, harbor, tag .. "_reset")
  end

  setMasterBalls(5)
  F.check(tag .. ": the puzzle opens the battle again", solvePuzzle(tag .. "_again"))
  F.check(tag .. ": a Master Ball catches Deoxys", catchWithR(tag .. "_catch"), "outcome=" .. F.outcome())
  F.check(tag .. ": the caught Deoxys left the field", not visible(LOCALID_DEOXYS))
  F.check(tag .. ": the catch is recorded", flagGet(markFlag))
end

local function otherIslandHidden(tag, island, rockFlag)
  F.check(tag .. ": warped to the other Birth Island", warp(island, tag), where())
  F.idle(60)
  F.shot(tag)
  F.check(tag .. ": no second Deoxys puzzle", flagGet(rockFlag), "hideRock=" .. tostring(flagGet(rockFlag)))
  local talk = ROCK_TALK[1]
  walkTo(talk[1], talk[2], tag)
  F.shot(tag .. "_rock_tile")
  F.check(tag .. ": no rock stands on the island", not visible(LOCALID_ROCK) and not visible(LOCALID_DEOXYS))
end

local function navelCatch(tag, map, species, hideFlag, approach, markFlag)
  local before0 = boxed()
  F.check(tag .. ": a full party of six", party(6))
  setMasterBalls(5)
  local before = boxed()
  F.L(string.format("  %s: boxed %d before the party, %d after", tag, before0, before))
  F.check(tag .. ": warped to Kanto's Navel Rock", warp(map, tag), where())
  F.idle(60)
  F.check(tag .. ": the legendary is there", not flagGet(hideFlag))
  F.w16(S.gBattleMons + S.BattlePokemon.size, 0)
  approach()
  F.check(tag .. ": the legendary battle starts", awaitBattle(tag, species))
  F.check(tag .. ": a Master Ball catches it", catchWithR(tag .. "_catch"), "outcome=" .. F.outcome())
  F.check(tag .. ": the full party is unchanged and the catch went to the PC", partyCount() == 6 and boxed() == before + 1,
    string.format("party=%d boxed=%d before=%d", partyCount(), boxed(), before))
  F.check(tag .. ": the legendary left the field", not visible(LOCALID_NAVEL))
  F.check(tag .. ": Kanto's own flag records it", flagGet(markFlag))
end

-- Mt. Silver's Moltres shares FLAG_FOUGHT_MOLTRES with Mt. Ember. A Roar from the player ends the
-- battle with B_OUTCOME_PLAYER_TELEPORTED, which Mt. Ember treats as running; Moltres must stay.
local function moltresRoar()
  local tag = "mtsilver_moltres"
  F.check(tag .. ": a level 100 Snorlax that knows Roar", party(1, MOVE_ROAR))
  varSet(VAR_REPEL_STEP_COUNT, 250)   -- the room has wild encounters; the walk is not under test
  F.check(tag .. ": warped to the Moltres room", warp(MT_SILVER_MOLTRES, tag), where())
  F.idle(60)
  F.check(tag .. ": Moltres is there", not flagGet(FLAG_HIDE_MOLTRES))
  local reached = walkTo(17, 31, tag) and walkTo(3, 31, tag) and walkTo(3, 7, tag) and walkTo(17, 7, tag)
    and walkTo(17, 19, tag)
  F.check(tag .. ": walked up to Moltres", reached, where())
  F.face("Down")
  F.w16(S.gBattleMons + S.BattlePokemon.size, 0)
  F.press("A", 3)
  F.check(tag .. ": the Moltres battle starts", awaitBattle(tag, SPECIES_MOLTRES))
  if awaitAction() then fightFirstMove() end
  F.check(tag .. ": back on the field after Roar", finishBattle(tag .. "_roar"))
  F.check(tag .. ": Roar ended the battle", F.outcome() == OUTCOME_PLAYER_TELEPORTED, "outcome=" .. F.outcome())
  F.shot(tag .. "_after_roar")
  F.check(tag .. ": a roared-away Moltres is not marked fought", not flagGet(FLAG_FOUGHT_MOLTRES)
    and not flagGet(FLAG_HIDE_MOLTRES))
  F.check(tag .. ": left and came back", warp(MT_SILVER_WATERFALL, tag .. "_out") and warp(MT_SILVER_MOLTRES, tag .. "_in"))
  F.idle(60)
  F.check(tag .. ": Moltres is still there on the next visit", not flagGet(FLAG_HIDE_MOLTRES))
  varSet(VAR_REPEL_STEP_COUNT, 0)
end

F.run(function()
  if not F.boot(HUB) then F.check("boot", false); F.finish(); return end
  local opt = F.sb2() + S.SaveBlock2.optionsU16
  F.w16(opt, (F.r16(opt) & ~7) | 3)

  moltresRoar()

  deoxysIsland("kanto_deoxys", BIRTH_KANTO, BIRTH_KANTO_HARBOR, FLAG_HIDE_KANTO_ROCK, FLAG_FOUGHT_DEOXYS)
  otherIslandHidden("kanto_catch_hoenn_island", BIRTH_HOENN, FLAG_HIDE_HOENN_ROCK)

  for _, f in ipairs({ FLAG_FOUGHT_DEOXYS, FLAG_BATTLED_DEOXYS, FLAG_DEOXYS_FLEW_AWAY, FLAG_DEFEATED_DEOXYS }) do flagClear(f) end
  deoxysIsland("hoenn_deoxys", BIRTH_HOENN, BIRTH_HOENN_HARBOR, FLAG_HIDE_HOENN_ROCK, FLAG_BATTLED_DEOXYS)
  otherIslandHidden("hoenn_catch_kanto_island", BIRTH_KANTO, FLAG_HIDE_KANTO_ROCK)

  navelCatch("kanto_hooh", NAVEL_KANTO_SUMMIT, SPECIES_HO_OH, FLAG_HIDE_HO_OH, function()
    walkTo(10, 16, "kanto_hooh"); walkTo(9, 16, "kanto_hooh"); walkTo(9, 12, "kanto_hooh")
  end, FLAG_FOUGHT_HO_OH)
  F.check("hoenn_hooh: warped to Hoenn's Navel Rock summit", warp(NAVEL_HOENN_TOP, "hoenn_hooh"), where())
  F.idle(60)
  F.check("hoenn_hooh: no second Ho-Oh", flagGet(FLAG_HIDE_HO_OH) and not visible(LOCALID_NAVEL),
    "caughtFlag=" .. tostring(flagGet(FLAG_CAUGHT_HO_OH)))
  walkTo(12, 16, "hoenn_hooh"); walkTo(12, 10, "hoenn_hooh")
  for _ = 1, 240 do if inBattle() then break end F.idle(1) end
  F.shot("hoenn_hooh_summit")
  F.check("hoenn_hooh: the summit stays quiet", not inBattle() and hasControl())
  if inBattle() then awaitAction(); chooseAction(3); finishBattle("hoenn_hooh_flee") end

  navelCatch("kanto_lugia", NAVEL_KANTO_BASE, SPECIES_LUGIA, FLAG_HIDE_LUGIA, function()
    walkTo(12, 20, "kanto_lugia"); walkTo(11, 19, "kanto_lugia"); walkTo(10, 18, "kanto_lugia")
    walkTo(10, 16, "kanto_lugia"); F.face("Up"); F.press("A", 3)
  end, FLAG_FOUGHT_LUGIA)
  F.check("hoenn_lugia: warped to Hoenn's Navel Rock bottom", warp(NAVEL_HOENN_BOTTOM, "hoenn_lugia"), where())
  F.idle(60)
  F.shot("hoenn_lugia_bottom")
  F.check("hoenn_lugia: no second Lugia", flagGet(FLAG_HIDE_LUGIA) and not visible(LOCALID_NAVEL),
    "caughtFlag=" .. tostring(flagGet(FLAG_CAUGHT_LUGIA)))
  F.finish()
end)
