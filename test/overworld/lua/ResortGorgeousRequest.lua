-- Selphy's wish at Resort Gorgeous (Five Island), driven by talking to her. With every Gen 1 to 3
-- species seen, each request must name an enabled base species, and showing that species must
-- earn the reward. Five rounds: talk, read the request, put the base species in the party, talk
-- again, then leave the house and come back, which is how the game clears her "just fulfilled"
-- temp flag.
--
-- Setup writes the seen Pokedex, Selphy's at-home state and the shown Pokemon through RAM and the
-- debug menu. The requests come from her own script and the `SampleResortGorgeousMonAndReward`
-- special with the game's RNG.
--
-- Run via: test/overworld/mgba-run.sh test/overworld/lua/ResortGorgeousRequest.lua <rom.gba>

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "ResortGorgeousRequest")

local HOUSE_G, HOUSE_M = 71, 0
local FLAG_TEMP_2 = 0x2
local FLAG_HIDE_RESORT_GORGEOUS_INSIDE_SELPHY = 0xA40 + 0x95
local VAR_REQUESTED, VAR_REWARD, VAR_SCENE = 0xA011, 0xA016, 0xA05D
local GEN3_DEX = 386
local ROUNDS = 5
local MON = S.Pokemon.size

local function flag(id, value)
  local a, bit = F.sb1() + S.SaveBlock1.flags + id // 8, 1 << (id % 8)
  if value ~= nil then F.w8(a, value and (F.r8(a) | bit) or (F.r8(a) & ~bit & 0xFF)) end
  return (F.r8(a) & bit) ~= 0
end
local function varAddr(id) return F.sb3() + S.SaveBlock3.regionVars + (id - 0xA000) * 2 end
local function var(id, value) if value ~= nil then F.w16(varAddr(id), value) end return F.r16(varAddr(id)) end

local function info(s) return S.gSpeciesInfo + s * S.SpeciesInfo.stride end
local function enabled(s) return s > 0 and F.r8(info(s) + S.SpeciesInfo.baseHP) > 0 end
local function baseOf(s)
  local t = F.r32(info(s) + S.SpeciesInfo.formSpeciesIdTable)
  return t == 0 and s or F.r16(t)
end
local function dexOf(s) return F.r16(info(s) + S.SpeciesInfo.natDexNum) end
local function seenAddr(n) return F.sb1() + S.SaveBlock1.dexSeen + (n - 1) // 8, 1 << ((n - 1) % 8) end
local function seen(n) local a, bit = seenAddr(n); return (F.r8(a) & bit) ~= 0 end
local function seeGen3()
  for n = 1, GEN3_DEX do local a, bit = seenAddr(n); F.w8(a, F.r8(a) | bit) end
end

local function itemQty(id)
  local key, n = F.r32(F.sb2() + S.SaveBlock2.encryptionKey) & 0xFFFF, 0
  for p = 0, 4 do
    local ptr = F.r32(S.gBagPockets + p * S.BagPocket.stride)
    for slot = 0, F.pocketCap(p) - 1 do
      if F.r16(ptr + slot * 4) == id then n = n + (F.r16(ptr + slot * 4 + 2) ~ key) end
    end
  end
  return n
end

local function scriptIdle() return F.ow() and F.r8(S.sGlobalScriptContextStatus) == 2 end
local function partyCount() return F.r8(S.gPartiesCount) end
local GROWTH_SLOT = { [0]=0,0,0,0,0,0,1,1,2,3,2,3,1,1,2,3,2,3,1,1,2,3,2,3 }
local function partySpecies(i)
  local mon = S.gParties + i * MON
  if (F.r8(mon + 19) & 2) == 0 then return 0 end
  local key = F.r32(mon) ~ F.r32(mon + 4)
  return (F.r16(mon + 32 + GROWTH_SLOT[F.r32(mon) % 24] * 12) ~ (key & 0xFFFF)) & 0x7FF
end

-- Talks to Selphy from the tile below her. Every crash screen shown on the way is counted and
-- dismissed with Start (it is resumable), so the round still finishes and the count is reported.
local function talk(tag)
  local crashes = 0
  F.face("Up"); F.press("A", 2); F.idle(20)
  for n = 1, 400 do
    if F.crashScreen() then
      crashes = crashes + 1
      if crashes == 1 then F.reportCrash(tag) end
      F.press("Start", 2); F.idle(20)
    elseif scriptIdle() and n > 3 then
      return true, crashes
    else
      F.press("B", 2); F.idle(20)
    end
  end
  F.shot(tag .. "_stuck")
  return false, crashes
end

local function digits(n) n = n - 1; return n // 100, (n // 10) % 10, n % 10 end
local function giveOnly(species)
  for _ = 1, 3 do
    for off = 0, 6 * MON - 4, 4 do F.w32(S.gParties + off, 0) end
    F.w8(S.gPartiesCount, 0)
    F.dbg(); F.idle(30); F.bOut(4)
    F.dbg(); F.sel(3); F.sel(1); F.idle(20)
    F.spin(digits(species)); F.idle(20)
    F.spin(digits(10)); F.idle(60); F.bOut(4)
    for _ = 1, 10 do if scriptIdle() then break end F.press("B", 2); F.idle(20) end
    if partyCount() == 1 and partySpecies(0) == species then return true end
    F.idle(60)
  end
  return false
end

local function toSelphy()
  return F.route({ { 4, 6 }, { 4, 5 } }, "selphy")
end
local function leaveAndReturn(tag)
  if not F.route({ { 4, 6 }, { 4, 7 } }, tag .. "_door") then return false end
  for _ = 1, 3 do
    if F.grp() ~= HOUSE_G or F.mapn() ~= HOUSE_M then break end
    F.press("Down", 8); F.idle(60)
  end
  F.idle(90)
  local outside = F.grp() ~= HOUSE_G or F.mapn() ~= HOUSE_M
  for _ = 1, 3 do
    if F.grp() == HOUSE_G and F.mapn() == HOUSE_M then break end
    F.press("Up", 8); F.idle(90)
  end
  F.idle(60)
  return outside and F.grp() == HOUSE_G and F.mapn() == HOUSE_M
end

F.run(function()
  assert(F.boot(100), "Fresh game did not boot")
  flag(FLAG_HIDE_RESORT_GORGEOUS_INSIDE_SELPHY, false)
  var(VAR_SCENE, 2)
  seeGen3()
  F.check("Gen 1 to 3 seen, nothing later", seen(1) and seen(GEN3_DEX) and not seen(GEN3_DEX + 1))
  assert(F.warpTo(0, 7, 1, 0, 0, 0, 0, 0, 0, HOUSE_G, HOUSE_M, "house"), "Selphy's house warp failed")
  F.dismiss(10)
  assert(toSelphy(), "Could not reach Selphy")

  for round = 1, ROUNDS do
    local tag = "r" .. round
    local before = var(VAR_REQUESTED)
    local ok, crashes = talk(tag .. "_wish")
    local want = var(VAR_REQUESTED)
    local name = enabled(want) and string.format("dex %d base %d", dexOf(want), baseOf(want)) or "disabled"
    F.L(string.format("round %d: request %d (%s), crash screens %d", round, want, name, crashes))
    F.check(tag .. " request starts from no wish", before == 0, "before=" .. before)
    F.check(tag .. " Selphy's wish shows no crash screen", ok and crashes == 0, "crash screens=" .. crashes)
    F.check(tag .. " request is an enabled species", enabled(want), "species=" .. want)
    if not enabled(want) then break end
    F.check(tag .. " request is a base form", baseOf(want) == want, string.format("species=%d base=%d", want, baseOf(want)))
    F.check(tag .. " request is a seen Gen 1 to 3 species", seen(dexOf(want)) and dexOf(want) <= GEN3_DEX, "dex=" .. dexOf(want))

    local show = baseOf(want)
    F.check(tag .. " party holds the requested species' base form", giveOnly(show), "species=" .. show)
    F.dismiss(10)
    assert(toSelphy(), "Could not return to Selphy")
    local reward = var(VAR_REWARD)
    local had = itemQty(reward)
    local shown, crashes2 = talk(tag .. "_show")
    F.shot(tag .. "_shown")
    F.check(tag .. " Selphy accepts the shown " .. show, shown and crashes2 == 0 and var(VAR_REQUESTED) == 0 and flag(FLAG_TEMP_2),
      string.format("request=%d tempflag=%s", var(VAR_REQUESTED), tostring(flag(FLAG_TEMP_2))))
    F.check(tag .. " the butler hands over the reward", itemQty(reward) == had + 1,
      string.format("item %d: %d -> %d", reward, had, itemQty(reward)))
    if var(VAR_REQUESTED) ~= 0 then break end
    F.check(tag .. " leave and re-enter the house", leaveAndReturn(tag))
    F.dismiss(10)
    assert(toSelphy(), "Could not reach Selphy after re-entering")
    F.check(tag .. " re-entry clears the just-fulfilled flag", not flag(FLAG_TEMP_2))
  end

  F.finish()
end)
