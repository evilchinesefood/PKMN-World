-- Every HARD-tier party in the game, fought to a finish on the HARD tier.
--
-- VAR_DIFFICULTY becomes DIFFICULTY_HARD once a region is cleared, and gym leaders, both Elite
-- Fours, the Hoenn champions and the Kanto champion rematch then load their `Difficulty: Hard`
-- party (full AI flags, held Mega Stones, Full Restores, Tate & Liza's six-member double). The
-- campaigns fight only a few of them (Johto's eight leaders, Roxanne, Brock). This fights all 42,
-- with the champion flags set as the three Hall of Fame scripts leave them, through the debug
-- Trainers > Try Battle path (the same difficulty-driven party build, see test/overworld/README.md),
-- and checks for a crash, a hang, a party that did not load the HARD tier, and a tier left changed.
-- A loss is allowed: the whiteout path is part of what it exercises.
--
--   python3 test/overworld/johto-playthrough/run.py --suite hard_tier_battles.lua --timeout 7000
local here = (debug.getinfo(1, 'S').source:sub(2)):match('^(.*[/\\])')
package.path = here .. '?.lua;' .. here .. '../lua/?.lua;' .. assert(os.getenv('PW_PLAY_LUA')) .. '/?.lua;' .. package.path
local S = require('symbols')
local F = require('lib').new(S, 'HardTierBattles')
local N = require('nav')(F, S)
local C = require('pwconst')
local P = require('pwsym')
local O = require('pwoff')
local L = F.L

local DIFFICULTY_HARD = 2

-- { trainer, highest level in its NORMAL party (src/data/trainers*.party), double }. No foe above
-- that level means the NORMAL party was loaded.
local HARD = {
  { 'TRAINER_SIDNEY', 49 },
  { 'TRAINER_PHOEBE', 51 },
  { 'TRAINER_GLACIA', 53 },
  { 'TRAINER_DRAKE', 55 },
  { 'TRAINER_ROXANNE_1', 15 },
  { 'TRAINER_BRAWLY_1', 19 },
  { 'TRAINER_WATTSON_1', 24 },
  { 'TRAINER_FLANNERY_1', 29 },
  { 'TRAINER_NORMAN_1', 31 },
  { 'TRAINER_WINONA_1', 33 },
  { 'TRAINER_TATE_AND_LIZA_1', 42, true },
  { 'TRAINER_JUAN_1', 46 },
  { 'TRAINER_WALLACE', 58 },
  { 'TRAINER_STEVEN', 78 },
  { 'TRAINER_FALKNER_1', 11 },
  { 'TRAINER_BUGSY_1', 16 },
  { 'TRAINER_WHITNEY_1', 21 },
  { 'TRAINER_MORTY_1', 25 },
  { 'TRAINER_JASMINE_1', 36 },
  { 'TRAINER_CHUCK_1', 31 },
  { 'TRAINER_PRYCE_1', 33 },
  { 'TRAINER_CLAIR_1', 45 },
  { 'TRAINER_WILL_2', 68 },
  { 'TRAINER_KOGA_2', 68 },
  { 'TRAINER_BRUNO_2', 68 },
  { 'TRAINER_KAREN_2_JT', 69 },
  { 'TRAINER_LANCE_2', 70 },
  { 'TRAINER_LEADER_GIOVANNI', 50 },
  { 'TRAINER_LEADER_BROCK', 14 },
  { 'TRAINER_LEADER_MISTY', 21 },
  { 'TRAINER_LEADER_LT_SURGE', 24 },
  { 'TRAINER_LEADER_ERIKA', 29 },
  { 'TRAINER_LEADER_KOGA', 43 },
  { 'TRAINER_LEADER_BLAINE', 47 },
  { 'TRAINER_LEADER_SABRINA', 43 },
  { 'TRAINER_ELITE_FOUR_LORELEI_2', 66 },
  { 'TRAINER_ELITE_FOUR_BRUNO_2', 68 },
  { 'TRAINER_ELITE_FOUR_AGATHA_2', 70 },
  { 'TRAINER_ELITE_FOUR_LANCE_2', 72 },
  { 'TRAINER_CHAMPION_REMATCH_SQUIRTLE', 75 },
  { 'TRAINER_CHAMPION_REMATCH_BULBASAUR', 75 },
  { 'TRAINER_CHAMPION_REMATCH_CHARMANDER', 75 },
}

local function setFlag(id)
  local a = F.sb1() + O.sb1_flags + (id >> 3)
  F.w8(a, F.r8(a) | (1 << (id & 7)))
end
local function vblank() return F.r32(S.gMain + 0x20) end   -- gMain.vblankCounter1, include/main.h

local function openDebug()
  N.press('R', 1); for _ = 1, 3 do joypad.set({ R = true, Start = true }); emu.frameadvance() end; N.idle(80)
end
local function downs(n) for _ = 1, n do N.press('Down', 3); N.idle(16) end end
local function taskWith(fn)
  for j = 0, 15 do
    local t = S.gTasks + j * 40
    if F.r8(t + 4) ~= 0 and (F.r32(t) & ~1) == (fn & ~1) then return t end
  end
end

-- Trainers... is row 6 of the main menu. With no rematch entry selected its rows are Choose from
-- map, Trainer 1, Trainer 2, Partner, Double Battle, Try Battle, Recharge VS Seeker. The menu
-- opens with Double Battle FALSE every time.
local function tryBattle(id, double)
  openDebug()
  downs(6); N.press('A', 3); N.idle(60)
  downs(1); N.press('A', 3); N.idle(60)
  local t = taskWith(P.DebugAction_ChooseTrainerID_Select)
  if not t then return false, 'trainer id spinner not open' end
  F.w16(t + 8 + 8, 0)            -- tDigit: the ones column
  F.w16(t + 8 + 6, id - 1)       -- tInput; the Up below lands it on id and copies it out
  N.press('Up', 3); N.idle(20)
  N.press('A', 3); N.idle(60)
  if double then
    downs(4); N.press('A', 3); N.idle(30)
    downs(1)
  else
    downs(5)
  end
  N.press('A', 3)
  for _ = 1, 600 do
    if N.inBattle() and F.r8(S.gBattlersCount) > 0 then return true end
    N.idle(5)
  end
  return false, 'no battle started'
end

F.run(function()
  if not F.boot(100) then F.check('boot', false); F.finish(); return end
  local SPECIAL, PHYSICAL = { 4, 0, 0, 252, 252, 0 }, { 4, 252, 0, 252, 0, 0 }
  local TEAM = {
    { species = C.SPECIES_MEWTWO, evs = SPECIAL, moves = { C.MOVE_PSYSTRIKE, C.MOVE_AURA_SPHERE, C.MOVE_ICE_BEAM, C.MOVE_FLAMETHROWER } },
    { species = C.SPECIES_RAYQUAZA, evs = PHYSICAL, moves = { C.MOVE_EARTHQUAKE, C.MOVE_DRAGON_CLAW, C.MOVE_EXTREME_SPEED, C.MOVE_AERIAL_ACE } },
    { species = C.SPECIES_GROUDON, evs = PHYSICAL, moves = { C.MOVE_EARTHQUAKE, C.MOVE_STONE_EDGE, C.MOVE_FIRE_PUNCH, C.MOVE_HAMMER_ARM } },
    { species = C.SPECIES_KYOGRE, evs = SPECIAL, moves = { C.MOVE_SURF, C.MOVE_ICE_BEAM, C.MOVE_THUNDER, C.MOVE_PSYCHIC } },
    { species = C.SPECIES_LATIOS, evs = SPECIAL, moves = { C.MOVE_DRAGON_PULSE, C.MOVE_PSYCHIC, C.MOVE_THUNDERBOLT, C.MOVE_FLAMETHROWER } },
    { species = C.SPECIES_METAGROSS, evs = PHYSICAL, moves = { C.MOVE_METEOR_MASH, C.MOVE_EARTHQUAKE, C.MOVE_ZEN_HEADBUTT, C.MOVE_ICE_PUNCH } },
  }
  for i, spec in ipairs(TEAM) do
    spec.level = 100
    assert(N.giveMon(spec), 'give ' .. spec.species)
    N.setMetLevel(i - 1, 5)
  end
  setFlag(C.FLAG_KANTO_CHAMPION); setFlag(C.FLAG_JOHTO_CHAMPION); setFlag(C.FLAG_HOENN_CHAMPION)
  N.setVar(C.VAR_DIFFICULTY, DIFFICULTY_HARD)
  F.check('party of six Lv100', N.partyCount() == 6 and N.partyMon(0).level == 100)

  local wins = 0
  for _, h in ipairs(HARD) do
    local name, normalHigh, double = h[1], h[2], h[3] or false
    local id = assert(C[name], name)
    N.debugHeal()
    local seen, low, high = {}, 999, 0
    N.foeHook = function(species, level, trainer)
      if trainer and level > 0 then seen[species] = level; low = math.min(low, level); high = math.max(high, level) end
    end
    local started, why = tryBattle(id, double)
    local battlers = started and F.r8(S.gBattlersCount) or 0
    local settled = false
    if started then settled = N.settle({ limit = 60 * 60 * 15 }) end
    N.foeHook = nil
    local v0 = vblank(); N.idle(30)
    local outcome, frozen = F.outcome(), vblank() == v0
    local foes = {}
    for sp, lv in pairs(seen) do foes[#foes + 1] = sp .. ':L' .. lv end
    table.sort(foes)
    L(string.format('  %-36s started=%s settled=%s outcome=%d foes=%d L%d-%d [%s] difficulty=%d %s',
      name, tostring(started), tostring(settled), outcome, #foes, low, high, table.concat(foes, ' '),
      N.var(C.VAR_DIFFICULTY), why or ''))
    F.check(name .. ': battle started', started, why)
    F.check(name .. (double and ': double battle' or ': single battle'), battlers == (double and 4 or 2), 'battlers=' .. battlers)
    F.check(name .. ': battle finished and control returned', settled and not frozen and F.ow() and N.free())
    F.check(name .. ': ended in a win or a whiteout', outcome == 1 or outcome == 2, 'outcome=' .. outcome)
    F.check(name .. ': HARD party loaded', #foes > 0 and high > normalHigh, string.format('highest L%d vs normal L%d', high, normalHigh))
    F.check(name .. ': tier unchanged', N.var(C.VAR_DIFFICULTY) == DIFFICULTY_HARD)
    if outcome == 1 then wins = wins + 1 end
    if not settled or frozen then F.reportCrash('hard_' .. name); F.shot('hard_' .. name); break end
  end
  L(string.format('TOTAL hard wins=%d of %d', wins, #HARD))
  F.finish()
end)
