-- Whiting out returns control at every heal location in all three regions, with no money.
--
-- For each entry of sHealLocations: point lastHealLocation at it, set money to 0, start a debug
-- battle and faint the party. Everything after the faint is the game's own code: the money loss
-- with nothing to lose, the whiteout warp, the recovery message, and the nurse or Mom script.
-- Each landing must hand control back on the map the respawn tables name, party healed, money
-- still 0, no crash screen. The next whiteout starts from where the last one landed.
--
-- "Control" is read, not stepped for: the field controls are unlocked, no script is running and
-- CB2 is the overworld. A landing that never gets there inside the budget is a softlock.
--
-- Run via test/overworld/mgba-run.sh test/overworld/lua/WhiteoutEveryCenter.lua
-- PW_WHITEOUT_ONLY=<heal location id> runs one landing; PW_WHITEOUT_FROM=<id> starts partway.
-- Discrimination: with fd67615708's Indigo Plateau nurse reverted, heal32 never returns control.

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "WhiteoutEveryCenter")

local HEAL_OFF = S.SaveBlock1.lastHealLocation
local PKMN_SIZE, OFF_HP, OFF_MAXHP = S.Pokemon.size, S.Pokemon.hp, S.Pokemon.maxHP
local BP_STRIDE, BP_HP = S.BattlePokemon.size, S.BattlePokemon.hp
local WARP_ID_NONE = 255
local CONTEXT_SHUTDOWN = 2
local ROW_PARTY_MENU, ROW_SET, ROW_BATTLE = 2, 9, 10
-- struct HealLocation is s8,s8,u16,u16 but the ROM table strides 8 (the first two entries,
-- Littleroot 2F (1,1) and (1,3), sit 8 bytes apart).
local HEAL_SIZE = 8
local LANDING_BUDGET = 6000
-- One Island's Center sets the respawn in ON_TRANSITION and starts the Celio meeting in ON_FRAME
-- on the same arrival, so a respawn there with that scene unplayed cannot occur in a game. A fresh
-- save has it unplayed, and the scene's region var is not in SaveBlock1's vars to preset.
local SKIP = { ["37/12"] = "One Island: the Celio scene always plays before its respawn is usable" }

local function tapDown(n) for _ = 1, n do F.press("Down", 3); F.idle(16) end end
local function closeDbg() for _ = 1, 16 do F.press("B", 3); F.idle(20) end end

local function hasControl()
  return F.ow() and F.r8(S.sLockFieldControls) == 0
    and F.r8(S.sGlobalScriptContextStatus) == CONTEXT_SHUTDOWN
end

local function setMoney(v)
  F.w32(F.sb1() + S.SaveBlock1.money, v ~ F.r32(F.sb2() + S.SaveBlock2.encryptionKey))
end

local function healEntry(i)
  local b = S.sHealLocations + i * HEAL_SIZE
  local m = S.sWhiteoutRespawnHealCenterMapIdxs + i * 8
  local npc = F.r8(S.sWhiteoutRespawnHealerNpcIds + i)
  local e = { g = F.rs8(b), n = F.rs8(b + 1), x = F.r16(b + 2), y = F.r16(b + 4), npc = npc }
  if npc ~= 0 then
    e.rg, e.rn = F.r16(m), F.r16(m + 2)
  else
    e.rg, e.rn = e.g, e.n
  end
  return e
end

local function writeLastHeal(e)
  local b = F.sb1() + HEAL_OFF
  F.w8(b, e.g); F.w8(b + 1, e.n); F.w8(b + 2, WARP_ID_NONE)
  F.w16(b + 4, e.x); F.w16(b + 6, e.y)
end

local function setParty()
  F.dbg(); F.idle(60)
  tapDown(ROW_PARTY_MENU); F.press("A", 3); F.idle(60)
  tapDown(ROW_SET); F.press("A", 3); F.idle(180)
  closeDbg()
  return F.r8(S.gPartiesCount)
end

local function partyHealed()
  local n = F.r8(S.gPartiesCount)
  for i = 0, n - 1 do
    local b = S.gParties + i * PKMN_SIZE
    if F.r16(b + OFF_HP) ~= F.r16(b + OFF_MAXHP) then return false end
  end
  return n > 0
end

local function faintIntoWhiteout(tag)
  F.dbg(); F.idle(60)
  tapDown(ROW_PARTY_MENU); F.press("A", 3); F.idle(60)
  tapDown(ROW_BATTLE); F.press("A", 3); F.idle(30)
  local inBattle = false
  for _ = 1, 600 do
    F.idle(4)
    if not F.ow() then inBattle = true; break end
  end
  if not inBattle then return false, "debug battle never started" end
  F.idle(240)
  for i = 0, 5 do
    local b = S.gParties + i * PKMN_SIZE
    if F.r16(b + OFF_MAXHP) ~= 0 then F.w16(b + OFF_HP, 0) end
  end
  for i = 0, 3 do F.w16(S.gBattleMons + i * BP_STRIDE + BP_HP, 0) end
  return true
end

local function waitLanding(tag)
  local leftField = false
  for f = 1, LANDING_BUDGET do
    -- A takes the fainted lead through its turn; once out of battle only B, which never talks.
    if f % 20 == 0 then F.press(leftField and F.ow() and "B" or "A", 2) else F.idle(1) end
    if f % 60 == 0 and F.reportCrash(tag) then return false, "crash screen" end
    if not F.ow() then leftField = true end
    if leftField and F.ow() and f % 10 == 0 and hasControl() then
      F.idle(30)
      if hasControl() then return true, f end
    end
  end
  return false, string.format("no control after %d frames: cb2=%08X lock=%d script=%d pos=(%d,%d) grp=%d map=%d",
    LANDING_BUDGET, F.cb2(), F.r8(S.sLockFieldControls), F.r8(S.sGlobalScriptContextStatus),
    select(1, F.pos()), select(2, F.pos()), F.grp(), F.mapn())
end

F.run(function()
  if not F.boot(100) then F.check("boot to the hub", false); F.finish(); return end
  F.check("debug Set Party gave a party", setParty() > 0)
  local count = S.sHealLocations_size // HEAL_SIZE
  F.check("heal location table read", count > 40, "count=" .. count)
  local only = os.getenv("PW_WHITEOUT_ONLY")
  local from = tonumber(os.getenv("PW_WHITEOUT_FROM") or "1")
  for i = 0, count - 1 do
    local e = healEntry(i)
    local tag = string.format("heal%02d_%d_%d", i + 1, e.g, e.n)
    local skip = SKIP[e.g .. "/" .. e.n]
    if skip then F.L("  skip " .. tag .. ": " .. skip) end
    if not skip and e.g >= 0 and i + 1 >= from and (not only or tonumber(only) == i + 1) then
      writeLastHeal(e)
      setMoney(0)
      local ok, why = faintIntoWhiteout(tag)
      if not ok then
        F.check(tag .. " fainted into a whiteout", false, why)
      else
        local landed, detail = waitLanding(tag)
        local x, y = F.pos()
        F.check(tag .. " control returns", landed, tostring(detail))
        F.check(tag .. " lands on the respawn map", F.grp() == e.rg and F.mapn() == e.rn,
          string.format("at %d/%d (%d,%d), want %d/%d npc=%d", F.grp(), F.mapn(), x, y, e.rg, e.rn, e.npc))
        F.check(tag .. " party healed", partyHealed())
        F.check(tag .. " money still 0", F.money() == 0, "money=" .. F.money())
        if not landed then F.shot(tag .. "_stuck"); break end
      end
    end
  end
  F.finish()
end)
