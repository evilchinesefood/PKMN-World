-- The Pokedex diploma must name the Pokedex of the region that awards it.
--
-- Two game designers call Special_ShowDiploma: Lilycove's Cove Lily Motel (Hoenn, after
-- HasAllHoennMons) and Celadon's Condominiums 3F (Kanto, after HasAllKantoMons). DisplayDiplomaText
-- printed Emerald's "HOENN" for every regional diploma, so the Kanto designer certified a completed
-- HOENN POKéDEX. pokefirered prints "KANTO" there (gText_Diploma_Kanto).
--
-- Each designer is talked to with real input with every species caught but one from outside the
-- region (Chikorita for Kanto, Bulbasaur for Hoenn), so the region completes and the National Dex
-- does not. Oracle: the diploma text, read from gStringVar4 where DisplayDiplomaText expands it.
-- The designer's script ends parked in WAITING after the diploma (no script is RUNNING), so control
-- is proved by a step.
local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "DiplomaRegionName")

local HUB_GROUP = 100
local CELADON_3F_G, CELADON_3F_M = 44, 9
local LILYCOVE_2F_G, LILYCOVE_2F_M = 13, 1
local CONTEXT_RUNNING = 0
local DEX_BYTES = S.SaveBlock1.dexCaught - S.SaveBlock1.dexSeen
local SPECIES_BULBASAUR, SPECIES_CHIKORITA = 1, 152
local FLAG_HIDE_LILYCOVE_MOTEL_GAME_DESIGNERS = 0x39D

local function where() local x, y = F.pos(); return string.format("%d/%d (%d,%d)", F.grp(), F.mapn(), x, y) end
local function hasControl()
  return F.ow() and F.r8(S.sLockFieldControls) == 0 and F.r8(S.sGlobalScriptContextStatus) ~= CONTEXT_RUNNING
end
local function instantText()
  local a = F.sb2() + S.SaveBlock2.optionsU16
  F.w16(a, (F.r16(a) & ~7) | 3)
end

local function clearFlag(n)
  local a = F.sb1() + S.SaveBlock1.flags + n // 8
  F.w8(a, F.r8(a) & ~(1 << (n % 8)))
end

local function decode(addr, max)
  local out = {}
  for i = 0, (max or 400) - 1 do
    local c = F.r8(addr + i)
    if c == 0xFF then break end
    if c == 0x00 then out[#out + 1] = " "
    elseif c >= 0xBB and c <= 0xD4 then out[#out + 1] = string.char(65 + c - 0xBB)
    elseif c >= 0xD5 and c <= 0xEE then out[#out + 1] = string.char(97 + c - 0xD5)
    elseif c == 0xAB then out[#out + 1] = "!"
    elseif c == 0xAD then out[#out + 1] = "."
    elseif c == 0xFE or c == 0xFA or c == 0xFB then out[#out + 1] = " "
    else out[#out + 1] = "?" end
  end
  return table.concat(out)
end

-- Every species caught except `missing`, which the region's own completion check never asks for.
local function catchAllBut(missing)
  local base = F.sb1() + S.SaveBlock1.dexCaught
  for i = 0, DEX_BYTES - 1 do F.w8(base + i, 0xFF) end
  local a = base + (missing - 1) // 8
  F.w8(a, F.r8(a) & ~(1 << ((missing - 1) % 8)))
end

-- Talk with A until the diploma's text is expanded, then shoot the diploma and leave it.
local function readDiploma(tag)
  F.w8(S.gStringVar4, 0xFF)
  F.press("A", 2)
  local said
  for i = 1, 2400 do
    if i % 8 == 0 and F.reportCrash(tag) then break end
    local t = decode(S.gStringVar4)
    if t:find("This document certifies", 1, true) then said = t; break end
    joypad.set((i % 40 < 2) and { A = true } or {})
    emu.frameadvance()
  end
  joypad.set({})
  F.idle(120)
  F.shot(tag)
  for _ = 1, 80 do
    if hasControl() then break end
    F.press("B", 2); F.idle(20)
  end
  return said or ""
end

local function dexName(t) return t:match("completed your%s+(%u+) POK") end

F.run(function()
  if not F.boot(HUB_GROUP) then F.check("boot to the hub", false); F.finish(); return end
  instantText()

  catchAllBut(SPECIES_CHIKORITA)
  F.check("warp to Celadon Condominiums 3F", F.warpTo(0, 4, 4, 0, 0, 9, 0, 0, 3, CELADON_3F_G, CELADON_3F_M, "celadon_3f"))
  instantText()
  F.check("walk up to the Kanto game designer", F.route({ { 11, 14 }, { 4, 14 }, { 4, 11 }, { 3, 11 }, { 3, 9 } }, "celadon"), where())
  F.face("Up")
  local kanto = readDiploma("celadon_diploma")
  F.check("Kanto: the diploma was shown", kanto ~= "", where())
  F.check("Kanto: the diploma certifies the KANTO POKéDEX", dexName(kanto) == "KANTO", kanto)
  F.check("Kanto: control returns after the diploma", hasControl() and F.step("Down"), where())

  catchAllBut(SPECIES_BULBASAUR)
  clearFlag(FLAG_HIDE_LILYCOVE_MOTEL_GAME_DESIGNERS)
  F.check("warp to the Cove Lily Motel 2F", F.warpTo(0, 1, 3, 0, 0, 1, 0, 0, 0, LILYCOVE_2F_G, LILYCOVE_2F_M, "lilycove_2f"))
  instantText()
  F.check("walk up to the Hoenn game designer", F.route({ { 2, 2 }, { 5, 2 }, { 5, 6 } }, "lilycove"), where())
  F.face("Left")
  local hoenn = readDiploma("lilycove_diploma")
  F.check("Hoenn: the diploma was shown", hoenn ~= "", where())
  F.check("Hoenn: the diploma certifies the HOENN POKéDEX", dexName(hoenn) == "HOENN", hoenn)
  F.check("Hoenn: control returns after the diploma", hasControl() and F.step("Right"), where())
  F.finish()
end)
