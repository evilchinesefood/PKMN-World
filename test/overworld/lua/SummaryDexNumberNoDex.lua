-- Before the National Pokedex, the summary's info page prints the regional dex number beside the
-- species name, and only for a species in that dex (PrintMonDexNumberSpecies skips 0xFFFF). Johto
-- has no regional dex, so SpeciesToPokedexNum falls back to the Hoenn order, whose lookup returns 0
-- for every species outside it; 0 passed the "<= REGIONAL_DEX_COUNT" test and printed "000" beside
-- a Johto starter until Elm handed over the Pokedex, and a Hoenn number beside Johto Pokemon that
-- the Hoenn dex lists (Zubat showed 063).
--
-- The suite gives a Pokemon with the debug Give menu, warps to a map of the region (the region is
-- map-derived), opens its summary from the Start menu's party with real input, and reads the
-- species window's pixels where the number goes:
--   Johto (National Park gate), Chikorita, in no regional dex here: no number;
--   Johto, Zubat, in the Hoenn dex Johto used to borrow: no number;
--   control: Kanto (Viridian City), Bulbasaur, Kanto #001: a number.
--
-- Run via test/overworld/mgba-run.sh test/overworld/lua/SummaryDexNumberNoDex.lua <rom>

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "SummaryDexNumberNoDex")

local HUB_GROUP = 100
local MON = S.Pokemon.size
local USM_ICO_PARTY = 1
local WINDOW_STRIDE, WINDOWS_MAX = 12, 32

-- GetCurrentRegion follows the map's section, so each case stands on a map of its region.
local JOHTO_GATE = { 83, 7 }      -- National Park gate
local KANTO_TOWN = { 37, 1 }      -- Viridian City
local function warp(m, tag)
  local function d(n) return n // 100, (n // 10) % 10, n % 10 end
  local gh, gt, go = d(m[1]); local mh, mt, mo = d(m[2])
  return F.warpTo(gh, gt, go, mh, mt, mo, 0, 0, 0, m[1], m[2], tag)
end

-- The info page's species window: bg 0 at (7,3), 12x9 tiles, base block 277. Count lit pixels in
-- the box where the dex number prints (x 76..99, y 5..16). The box holds 12 lit pixels of the
-- page's own art with no number; three digits add over 100.
local NO_NUMBER_MAX = 20
local function numberPixels()
  for i = 0, WINDOWS_MAX - 1 do
    local w = S.gWindows + i * WINDOW_STRIDE
    if F.r8(w) == 0 and F.r8(w + 1) == 7 and F.r8(w + 2) == 3 and F.r8(w + 3) == 12
      and F.r16(w + 6) == 277 then
      local data = F.r32(w + 8)
      if data == 0 then return nil end
      local n = 0
      for y = 5, 16 do
        for x = 76, 99 do
          local tile = (x // 8) + (y // 8) * 12
          local b = F.r8(data + tile * 32 + (y % 8) * 4 + (x % 8) // 2)
          local px = (x % 2 == 0) and (b & 0xF) or (b >> 4)
          if px ~= 0 then n = n + 1 end
        end
      end
      return n
    end
  end
  return nil
end

local function digits(n) n = n - 1; return n // 100, (n // 10) % 10, n % 10 end
local function giveOnly(species)
  for off = 0, 6 * MON - 4, 4 do F.w32(S.gParties + off, 0) end
  F.w8(S.gPartiesCount, 0)
  F.dbg(); F.idle(30); F.bOut(4)
  F.dbg(); F.sel(3); F.sel(1); F.idle(20); F.spin(digits(species)); F.idle(20); F.spin(0, 0, 9); F.idle(60); F.bOut(4)
  return F.r8(S.gPartiesCount) == 1
end

local function inSummary() return F.cb2() ~= (S.CB2_UpdatePartyMenu & ~1) and not F.ow() end

local function summaryNumber(tag)
  F.press("Start", 2); F.idle(60)
  if not F.selectStartIcon(USM_ICO_PARTY) then return nil end
  F.press("A", 2)
  for _ = 1, 200 do F.idle(3); if F.cb2() == (S.CB2_UpdatePartyMenu & ~1) then break end end
  F.idle(60)
  F.press("A", 2); F.idle(40)
  F.press("A", 2)
  for _ = 1, 200 do F.idle(3); if inSummary() then break end end
  F.idle(120)
  F.shot(tag)
  local n = numberPixels()
  for _ = 1, 30 do
    if F.ow() then break end
    F.press("B", 2); F.idle(30)
  end
  F.ensureFree()
  return n
end

F.run(function()
  if not F.boot(HUB_GROUP) then F.check("boot to the hub", false); F.finish(); return end

  F.check("setup: Chikorita given", giveOnly(152))
  F.check("setup: on a Johto map", warp(JOHTO_GATE, "johto"))
  F.ensureFree()
  local johto = summaryNumber("johto_chikorita")
  F.L("  Johto Chikorita number pixels: " .. tostring(johto))
  F.check("Johto, no Pokedex: Chikorita's summary prints no dex number", johto ~= nil and johto <= NO_NUMBER_MAX,
    tostring(johto))

  F.check("setup: Zubat given", giveOnly(41))
  F.ensureFree()
  local zubat = summaryNumber("johto_zubat")
  F.L("  Johto Zubat number pixels: " .. tostring(zubat))
  F.check("Johto, no Pokedex: Zubat's summary prints no Hoenn dex number", zubat ~= nil and zubat <= NO_NUMBER_MAX,
    tostring(zubat))

  F.check("setup: Bulbasaur given", giveOnly(1))
  F.check("setup: on a Kanto map", warp(KANTO_TOWN, "kanto"))
  F.ensureFree()
  local kanto = summaryNumber("kanto_bulbasaur")
  F.L("  Kanto Bulbasaur number pixels: " .. tostring(kanto))
  F.check("control: Kanto, no Pokedex: Bulbasaur's summary prints its Kanto number", kanto ~= nil and kanto > 5 * NO_NUMBER_MAX,
    tostring(kanto))
  F.check("no crash screen", not F.crashScreen())
  F.finish()
end)
