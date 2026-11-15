-- Recovery paths of the two visible special catches, Surfboard Pikachu (Route 19) and Pirate
-- Totodile (Olivine), driven with real input.
--
-- For each source: the target refuses a battle until its intro NPC has spoken, the offer can be
-- declined, running and knocking the target out leave it uncollected and available, a battle with
-- no Poke Balls hides the ball shortcut and throws nothing, and Poke Balls are thrown until one
-- holds (break-outs included); the catch must set the collection mark and deliver the catalog
-- level, themed move, no held item and a non-shiny Pokemon. On Pirate Totodile the suite also
-- loses the battle (whiteout must keep the source unlocked and the next talk must start a battle
-- again) and fights with a full party and full PC (the ball must be refused and not spent).
--
-- Run via: test/overworld/mgba-run.sh test/overworld/lua/SpecialPokemonCatchRecovery.lua <rom.gba>

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "SpecialPokemonCatchRecovery")

local FLAG_SYS_POKEMON_GET = 0x948
local ITEM_POKE_BALL = 1
local POCKET_BALLS = 1
local OUTCOME_WON, OUTCOME_LOST, OUTCOME_RAN, OUTCOME_CAUGHT = 1, 2, 4, 7
local MON = S.Pokemon.size
local BOXES, PER_BOX = 14, 30

local SOURCES = {
  { name = "Surfboard Pikachu", species = 1574, level = 25, move = 57, unlocked = 0xDDB, collected = 0xDD1 },
  { name = "Pirate Totodile", species = 1580, level = 20, move = 168, unlocked = 0xDE1, collected = 0xDD7 },
}

local function flag(id, value)
  local address, bit = F.sb1() + S.SaveBlock1.flags + id // 8, 1 << (id % 8)
  if value ~= nil then
    local old = F.r8(address)
    F.w8(address, value and (old | bit) or (old & ~bit & 0xFF))
  end
  return (F.r8(address) & bit) ~= 0
end

local function tap(key, wait) F.press(key, 2); F.idle(wait or 20) end

local function warp(g, m, w, tag)
  return F.warpTo(g // 100, (g // 10) % 10, g % 10, m // 100, (m // 10) % 10, m % 10, 0, 0, w, g, m, tag)
end

-- Bag: Poke Ball pocket. Only the quantity is XORed with the low half of the encryption key.
local function qtyKey() return F.r32(F.sb2() + S.SaveBlock2.encryptionKey) & 0xFFFF end
local function setBalls(qty)
  local ptr, cap = F.r32(S.gBagPockets + POCKET_BALLS * S.BagPocket.stride), F.pocketCap(POCKET_BALLS)
  for s = 0, cap - 1 do F.w16(ptr + s * 4, 0); F.w16(ptr + s * 4 + 2, qtyKey()) end
  if qty > 0 then F.w16(ptr, ITEM_POKE_BALL); F.w16(ptr + 2, qty ~ qtyKey()) end
end
local function balls()
  local ptr, cap, n = F.r32(S.gBagPockets + POCKET_BALLS * S.BagPocket.stride), F.pocketCap(POCKET_BALLS), 0
  for s = 0, cap - 1 do if F.r16(ptr + s * 4) == ITEM_POKE_BALL then n = n + (F.r16(ptr + s * 4 + 2) ~ qtyKey()) end end
  return n
end

local function partyCount() return F.r8(S.gPartiesCount) end
local function decode(i)
  local a = S.gParties + i * MON
  local pers, otid = F.r32(a), F.r32(a + 4)
  local key = pers ~ otid
  local w = {}
  for k = 0, 11 do w[k] = F.r32(a + 32 + k * 4) ~ key end
  local s0 = F.r8(S.sSubstructOffsets + pers % 24) * 3
  local s1 = F.r8(S.sSubstructOffsets + 24 + pers % 24) * 3
  local sv = (otid >> 16) ~ (otid & 0xFFFF) ~ (pers >> 16) ~ (pers & 0xFFFF)
  local shiny = ((sv < 512) and 1 or 0) ~ ((F.r16(a + 30) >> 14) & 1)
  return {
    species = w[s0] & 0x7FF, item = (w[s0] >> 16) & 0x3FF, level = F.r8(a + S.Pokemon.level), shiny = shiny,
    moves = { w[s1] & 0x7FF, (w[s1] >> 16) & 0x7FF, w[s1 + 1] & 0x7FF, (w[s1 + 1] >> 16) & 0x7FF },
  }
end
local function describe(m)
  return string.format("species=%d level=%d item=%d shiny=%d moves=%d,%d,%d,%d", m.species, m.level, m.item, m.shiny,
    m.moves[1], m.moves[2], m.moves[3], m.moves[4])
end
local function knows(m, move) for k = 1, 4 do if m.moves[k] == move then return true end end return false end

local function liveMenu()
  for i = 0, S.Task.count - 1 do
    local task = S.gTasks + i * S.Task.stride
    local fn = F.r32(task + S.Task.func) & 0xFFFFFFFE
    if F.r8(task + S.Task.isActive) ~= 0 and (fn == S.Task_HandleYesNoInput or fn == S.Task_HandleMultichoiceInput) then
      return true
    end
  end
  return false
end
local function scriptIdle() return F.ow() and F.r8(S.sGlobalScriptContextStatus) == 2 end
local function inBattle() return F.cb2() == (S.BattleMainCB2 & ~1) end

-- Talk facing `dir`; answer each Yes/No with `answer`. Returns (menus seen, battle started).
local function talk(dir, answer)
  F.face(dir)
  F.press("A", 2); F.idle(20)
  local menus = 0
  for n = 1, 300 do
    if inBattle() then return menus, true end
    if liveMenu() then
      menus = menus + 1
      F.press(answer and "A" or "B", 2); F.idle(40)
    elseif n > 2 and scriptIdle() then
      return menus, false
    else
      F.press("A", 2); F.idle(16)
    end
  end
  for _ = 1, 300 do if inBattle() then return menus, true end F.idle(2) end
  return menus, false
end

local function actionReady()
  local fn = F.r32(S.gBattlerControllerFuncs) & ~1
  for _, p in ipairs(S.ActionInputFunctions) do if fn == p then return true end end
  return false
end
local function awaitAction()
  for _ = 1, 600 do
    if actionReady() then F.idle(10); return true end
    if not inBattle() and F.ow() then return false end
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
local function fight(slot)
  chooseAction(0)
  for _ = 1, 120 do if inMoveMenu() then break end F.idle(2) end
  F.idle(20)
  for _ = 1, 4 do
    local c = F.r8(S.gMoveSelectionCursor)
    if c == slot then break end
    if (c & 1) ~= (slot & 1) then tap((slot & 1) == 0 and "Left" or "Right", 12) else tap((slot & 2) == 0 and "Up" or "Down", 12) end
  end
  for _ = 1, 5 do
    tap("A", 30)
    if not inMoveMenu() then return end
  end
end
local function finishBattle(tag)
  for _ = 1, 3000 do
    if F.reportCrash(tag) then return false end
    if not inBattle() and scriptIdle() then F.idle(30); return true end
    tap("B", 10)
  end
  F.shot(tag .. "_stuck")
  return false
end

-- Debug Give X > Pokemon (Basic): species 150 at level 100 into an empty party. Its met level is
-- set to 1 so Gen 8 obedience (own Pokemon go by met level) lets it act with no badges, and its
-- moves become Earthquake, Flamethrower and Celebrate (slot 2, for losing on purpose).
local function spin4(n)
  n = n - 1
  local d = { n // 1000, (n // 100) % 10, (n // 10) % 10, n % 10 }
  for _ = 1, 3 do tap("Right", 8) end
  for _ = 1, 3 do tap("Down", 8) end
  for i = 1, 4 do
    for _ = 1, d[i] do tap("Up", 8) end
    if i < 4 then tap("Left", 8) end
  end
  tap("A", 45)
end
local function giveLead()
  for _ = 1, 3 do
    for o = 0, 6 * MON - 4, 4 do F.w32(S.gParties + o, 0) end
    F.w8(S.gPartiesCount, 0)
    F.dbg(); F.idle(30); F.bOut(4)
    F.dbg(); F.sel(3); F.sel(1); F.idle(20)
    spin4(150); F.idle(20)
    F.spin(0, 9, 9); F.idle(60); F.bOut(4)
    if partyCount() == 1 and decode(0).species == 150 then break end
  end
  if partyCount() ~= 1 or decode(0).species ~= 150 then return false end
  local a = S.gParties
  local pers, otid = F.r32(a), F.r32(a + 4)
  local key = pers ~ otid
  local w = {}
  for k = 0, 11 do w[k] = F.r32(a + 32 + k * 4) ~ key end
  local s1 = F.r8(S.sSubstructOffsets + 24 + pers % 24) * 3
  local s3 = F.r8(S.sSubstructOffsets + 72 + pers % 24) * 3
  w[s1] = 89 | (53 << 16)
  w[s1 + 1] = 606
  w[s1 + 2] = 10 | (15 << 8) | (40 << 16)
  w[s3] = (w[s3] & ~(0x7F << 16)) | (1 << 16)
  local sum = 0
  for k = 0, 11 do
    sum = sum + (w[k] & 0xFFFF) + ((w[k] >> 16) & 0xFFFF)
    F.w32(a + 32 + k * 4, (w[k] ~ key) & 0xFFFFFFFF)
  end
  F.w16(a + 28, sum & 0xFFFF)
  local m = decode(0)
  return m.level == 100 and m.moves[1] == 89 and m.moves[3] == 606
end

-- Each source: walk to the target. Returns the direction to face the target and the intro NPC.
local function goToSurfboard()
  if not warp(37, 7, 6, "fuchsia") then return nil end
  F.dismiss(10)
  if not F.route({ { 25, 32 }, { 21, 32 }, { 21, 36 }, { 27, 36 }, { 27, 39 } }, "fuchsia_south") then return nil end
  for _ = 1, 4 do if F.grp() == 37 and F.mapn() == 37 then break end F.step("Down") end
  local _, y = F.pos()
  -- Around the two beach trainers' sightlines (Richard looks right along y=9, Reece left along y=10).
  if not F.route({ { 15, y }, { 15, 8 }, { 9, 8 }, { 9, 12 }, { 12, 12 }, { 12, 11 } }, "beach") then return nil end
  return "Right"
end
local function surfboardIntro() F.leg(12, 12); F.leg(11, 12); return "Up" end
local function surfboardBack() F.leg(12, 12); F.leg(12, 11); return "Right" end

local function goToPirate()
  if not warp(87, 0, 7, "olivine") then return nil end
  F.dismiss(10)
  if not F.route({ { 15, 44 }, { 17, 44 }, { 17, 45 }, { 23, 45 }, { 23, 47 }, { 32, 47 }, { 32, 48 }, { 33, 48 },
                   { 33, 55 }, { 32, 55 } }, "olivine_dock") then return nil end
  return "Up"
end
local function pirateIntro() F.leg(31, 55); return "Up" end
local function pirateBack() F.leg(32, 55); return "Up" end

local function encounter(tag, back)
  local menus, battle = talk(back(), true)
  if not battle then F.shot(tag .. "_no_battle") end
  return battle and awaitAction()
end

local function source(src, go, intro, back)
  local tag = src.name
  local dir = go()
  F.check(tag .. ": reached the target", dir ~= nil, string.format("pos=(%d,%d)", F.pos()))
  if not dir then return end
  local menus, battle = talk(dir, true)
  F.check(tag .. ": before its intro the target offers no battle", menus == 0 and not battle and not flag(src.unlocked))
  talk(intro(), true)
  F.check(tag .. ": the intro NPC unlocks it", flag(src.unlocked) and not flag(src.collected))
  menus, battle = talk(back(), false)
  F.check(tag .. ": declining the offer starts no battle", menus == 1 and not battle)

  F.check(tag .. ": run - battle starts", encounter(tag .. "_run", back))
  F.shot(tag:gsub("%W", "_") .. "_battle")
  chooseAction(3)
  F.check(tag .. ": run - back on the field, still uncollected", finishBattle("run") and F.outcome() == OUTCOME_RAN
    and flag(src.unlocked) and not flag(src.collected), "outcome=" .. F.outcome())

  F.check(tag .. ": knock out - battle starts", encounter(tag .. "_ko", back))
  for _ = 1, 15 do
    fight(0)
    if not awaitAction() then break end
  end
  F.check(tag .. ": knock out - back on the field, still uncollected", finishBattle("ko") and F.outcome() == OUTCOME_WON
    and not flag(src.collected), "outcome=" .. F.outcome())

  setBalls(0)
  F.check(tag .. ": no balls - battle starts", encounter(tag .. "_noballs", back))
  F.check(tag .. ": no balls - the ball shortcut is hidden", F.r8(S.gLastUsedBallMenuPresent) == 0)
  F.press("R", 4); F.idle(120)
  F.check(tag .. ": no balls - R throws nothing", actionReady() and inBattle())
  chooseAction(3)
  F.check(tag .. ": no balls - ran, still uncollected", finishBattle("noballs") and not flag(src.collected))

  setBalls(99)
  local before = partyCount()
  F.check(tag .. ": catch - battle starts", encounter(tag .. "_catch", back))
  local throws = 0
  for _ = 1, 60 do
    F.press("R", 4); throws = throws + 1; F.idle(200)
    if F.outcome() == OUTCOME_CAUGHT or not awaitAction() then break end
  end
  F.check(tag .. ": catch - back on the field", finishBattle("catch"))
  F.L(string.format("  %s: %d throw(s), %d ball(s) left", tag, throws, balls()))
  F.check(tag .. ": catch - caught, one ball per throw, collection marked", F.outcome() == OUTCOME_CAUGHT
    and balls() == 99 - throws and flag(src.collected), string.format("outcome=%d throws=%d", F.outcome(), throws))
  F.check(tag .. ": catch - joined the party", partyCount() == before + 1, "party=" .. partyCount())
  if partyCount() == before + 1 then
    local m = decode(before)
    F.check(tag .. ": catch - catalog level, themed move, no item, not shiny", m.species == src.species
      and m.level == src.level and knows(m, src.move) and m.item == 0 and m.shiny == 0, describe(m))
  end
end

F.run(function()
  assert(F.boot(100), "Fresh game did not boot")
  local opt = F.sb2() + S.SaveBlock2.optionsU16
  F.w16(opt, (F.r16(opt) & ~7) | 3)
  flag(FLAG_SYS_POKEMON_GET, true)
  F.check("lead: a level 100 Mewtwo that obeys", giveLead())

  source(SOURCES[1], goToSurfboard, surfboardIntro, surfboardBack)
  source(SOURCES[2], goToPirate, pirateIntro, pirateBack)

  -- Lose to Pirate Totodile: the lead at 1 HP and only Celebrate chosen.
  for o = MON, 6 * MON - 4, 4 do F.w32(S.gParties + o, 0) end
  F.w8(S.gPartiesCount, 1)
  F.w16(S.gParties + S.Pokemon.hp, 1)
  F.check("whiteout: battle starts", encounter("whiteout", pirateBack))
  for _ = 1, 30 do
    fight(2)
    if not awaitAction() then break end
  end
  for _ = 1, 3000 do
    if F.ow() and scriptIdle() and not inBattle() then break end
    tap("B", 10)
  end
  F.idle(60)
  F.check("whiteout: lost, source still unlocked, party healed", F.outcome() == OUTCOME_LOST
    and flag(SOURCES[2].unlocked) and F.r16(S.gParties + S.Pokemon.hp) > 1, "outcome=" .. F.outcome())
  F.check("whiteout: the source offers a battle again", goToPirate() ~= nil and encounter("after_whiteout", pirateBack))
  chooseAction(3)
  finishBattle("after_whiteout")

  -- Full party and full PC.
  F.dbg(); F.sel(1); F.sel(1); F.sel(0); F.idle(200); F.bOut(6)   -- PC/Bag: Fill PC Boxes Fast
  for i = 1, 5 do for o = 0, MON - 4, 4 do F.w32(S.gParties + i * MON + o, F.r32(S.gParties + o)) end end
  F.w8(S.gPartiesCount, 6)
  local storage, boxed = F.r32(S.gPokemonStoragePtr), 0
  for s = 0, BOXES * PER_BOX - 1 do
    local a = storage + 4 + s * S.BoxPokemon.size
    if F.r32(a) ~= 0 or F.r32(a + 4) ~= 0 then boxed = boxed + 1 end
  end
  F.check("full storage: party and PC full", partyCount() == 6 and boxed == BOXES * PER_BOX, "boxed=" .. boxed)
  setBalls(10)
  F.check("full storage: battle starts", encounter("fullpc", pirateBack))
  F.press("R", 4); F.idle(200)
  F.shot("fullpc_refused")
  F.check("full storage: the ball is refused and not spent", balls() == 10 and inBattle() and F.outcome() == 0,
    string.format("balls=%d outcome=%d", balls(), F.outcome()))
  awaitAction(); chooseAction(3)
  F.check("full storage: back on the field", finishBattle("fullpc"))
  F.finish()
end)
