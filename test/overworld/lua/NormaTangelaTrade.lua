-- Norma's in-game trade in the Cinnabar Pokemon Lab lounge: a Venonat for her Tangela (TANGENY).
--
-- The trade specials read the trade id from VAR_0x8005 and the party slot from VAR_0x8004; every
-- other in-game trade reaches them through the shared EventScript_*InGameTrade* wrappers. Norma's
-- script still used FRLG's order (trade id in VAR_0x8004, slot in VAR_0x8005), so she asked for the
-- species of whatever trade id VAR_0x8005 last held (after Clifton, a Raichu for an Electrode), and
-- an accepted trade built the wrong mon from the wrong slot.
--
-- Setup gives one Venonat through the debug menu and warps into the lounge. Talking to Clifton and
-- declining his trade (which leaves his trade id in VAR_0x8005, as in normal play), talking to
-- Norma, Yes, the party pick and the trade scene are real input. The party's only Pokemon must
-- become Norma's Tangela and her trade flag must be set.
--
-- Run via test/overworld/mgba-run.sh test/overworld/lua/NormaTangelaTrade.lua <rom.gba>

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "NormaTangelaTrade")

local PARTY_SIZE, MON = 6, S.Pokemon.size
local SPECIES_VENONAT, SPECIES_TANGELA = 48, 114
local FLAG_DID_TANGENY_TRADE = 0xA40 + 0x275
local LOUNGE_G, LOUNGE_M = 46, 2
local CLIFTON_APPROACH, NORMA_APPROACH = { 4, 7 }, { 10, 6 }
local CONTEXT_SHUTDOWN = 2

local function party(slot) return S.gParties + slot * MON end
local function order(p)
  local o = {}
  for i = 0, 3 do o[i] = F.r8(S.sSubstructOffsets + i * 24 + p % 24) * 3 end
  return o
end
local function words(a)
  local key = F.r32(a) ~ F.r32(a + 4)
  local w = {}
  for i = 0, 11 do w[i] = F.r32(a + 32 + i * 4) ~ key end
  return w, order(F.r32(a))
end
local function species(a) local w, o = words(a); return w[o[0]] & 0x7FF end
local function checksumOk(a)
  local w = words(a)
  local sum = 0
  for i = 0, 11 do sum = sum + (w[i] & 0xFFFF) + (w[i] >> 16) end
  return (sum & 0xFFFF) == F.r16(a + 28)
end
local function flag(id) return (F.r8(F.sb1() + S.SaveBlock1.flags + id // 8) >> (id % 8)) & 1 == 1 end

local function instantText()
  local a = F.sb2() + S.SaveBlock2.optionsU16
  F.w16(a, (F.r16(a) & ~7) | 3)
end

local function digits(n) n = n - 1; return n // 100, (n // 10) % 10, n % 10 end
local function giveOne(sp, level)
  for _ = 1, 3 do
    for off = 0, PARTY_SIZE * MON - 4, 4 do F.w32(S.gParties + off, 0) end
    F.w8(S.gPartiesCount, 0)
    F.dbg(); F.idle(30); F.bOut(4)
    F.dbg(); F.sel(3); F.sel(1); F.idle(20)
    F.spin(digits(sp)); F.idle(20)
    F.spin(digits(level)); F.idle(60); F.bOut(4)
    if F.r8(S.gPartiesCount) == 1 and checksumOk(party(0)) and species(party(0)) == sp then return true end
    F.idle(60)
  end
  return false
end

local function inPartyMenu() return F.cb2() == (S.CB2_UpdatePartyMenu & ~1) end
local function scriptRunning() return F.r8(S.sGlobalScriptContextStatus) ~= CONTEXT_SHUTDOWN end

-- Walk to the tile below an NPC, face Up and talk.
local function talkFromBelow(tile, tag)
  if not F.leg(tile[1], tile[2]) then F.check(tag .. ": reached the tile below", false); return false end
  F.face("Up"); F.press("A", 2); F.idle(40)
  return true
end

F.run(function()
  if not F.boot(100) then F.check("boot to the hub", false); F.finish(); return end
  instantText()
  F.check("setup: the debug Give made one Venonat", giveOne(SPECIES_VENONAT, 20), "species=" .. species(party(0)))
  F.check("warp: Cinnabar Lab lounge", F.warpTo(0, 4, 6, 0, 0, 2, 0, 0, 0, LOUNGE_G, LOUNGE_M, "lounge"))
  instantText()
  local pid = F.r32(party(0))

  if talkFromBelow(CLIFTON_APPROACH, "Clifton") then
    F.idle(40); F.shot("clifton")
    for _ = 1, 8 do F.press("B", 2); F.idle(30) end
    for _ = 1, 60 do
      if not scriptRunning() then break end
      F.press("B", 2); F.idle(20)
    end
    F.check("Clifton: declined, back in control", F.ow() and not scriptRunning())
  end

  if talkFromBelow(NORMA_APPROACH, "Norma") then
    F.idle(40); F.shot("norma_offer")
    local picked = false
    for _ = 1, 400 do
      if inPartyMenu() then
        F.idle(30)
        if not picked then F.shot("party_pick") end
        picked = true
        F.press("A", 2); F.idle(40)
      elseif F.ow() and not scriptRunning() then
        break
      else
        F.press("A", 2); F.idle(30)
      end
    end
    F.idle(30); F.shot("after_norma")
    F.check("Norma: the party menu opened for the pick", picked)
  end

  F.check("the Venonat was traded away", F.r32(party(0)) ~= pid, string.format("pid=%08X", F.r32(party(0))))
  F.check("the party's only Pokemon is now a Tangela", F.r8(S.gPartiesCount) == 1 and species(party(0)) == SPECIES_TANGELA
    and checksumOk(party(0)), "species=" .. species(party(0)))
  F.check("Norma's trade flag is set", flag(FLAG_DID_TANGENY_TRADE))
  F.check("back in control on the field", F.ow() and not scriptRunning())
  F.check("no crash", not F.reportCrash("end"))
  F.finish()
end)
