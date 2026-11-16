-- The Deoxys puzzle's stone on Kanto's Birth Island (reached by the Seagallop) must change colour as
-- it climbs, like Hoenn's, and must not write outside the palette buffers.
--
-- With a real Pokemon in the party, the player walks to the stone and touches it with A, then
-- follows it to its second tile within the step limit and touches it again. After each touch the
-- stone sprite's palette (read through its OAM palette slot, unfaded) must hold that level's
-- colours, from graphics/field_specials/deoxys_rock_N.pal, and the 32 bytes that palette slot 0xFF
-- would address past gPlttBufferUnfaded and gPlttBufferFaded must be unchanged. Opening and
-- closing the party menu runs the map's return-to-field palette reload, which must keep the colour
-- and stay in bounds too. Hoenn's Birth Island is the control for the colours. After Deoxys has
-- been fought the stone is hidden on both islands, and the same reload must still stay in bounds.
--
-- Run via test/overworld/mgba-run.sh test/overworld/lua/BirthIslandRockPalette.lua <rom>

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "BirthIslandRockPalette")

local HUB = { 100, 0 }
local KANTO_BIRTH, HOENN_BIRTH = { 36, 56 }, { 26, 58 }
local SPECIES_MEWTWO, MOVE_PSYCHIC = 150, 94
local VAR_DEOXYS_ROCK_LEVEL = 0x4035
local LOCALID_ROCK = 1
local FLAG_SYS_POKEMON_GET = 0x948
local FLAG_BATTLED_DEOXYS, FLAG_FOUGHT_DEOXYS = 0x1AD, 0xA40 + 0x2E4
local CONTEXT_RUNNING = 0
local STRAY = (256 + 255 * 16) * 2   -- OBJ_PLTT_ID(0xFF) in bytes, where an unknown tag's slot lands

local function where() local x, y = F.pos(); return string.format("%d/%d (%d,%d)", F.grp(), F.mapn(), x, y) end
local function varGet(id) return F.r16(F.sb1() + S.SaveBlock1.vars + (id - 0x4000) * 2) end
local function d(n) return (n // 100) % 10, (n // 10) % 10, n % 10 end
local function warp(g, m, w, tag)
  local gh, gt, go = d(g)
  local mh, mt, mo = d(m)
  local wh, wt, wo = d(w)
  return F.warpTo(gh, gt, go, mh, mt, mo, wh, wt, wo, g, m, tag)
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
  return F.r8(S.gPartiesCount)
end
local function hasControl()
  return F.ow() and F.r8(S.sLockFieldControls) == 0 and F.r8(S.sGlobalScriptContextStatus) ~= CONTEXT_RUNNING
end

-- A JASC palette as the four BGR555 colours the stone uses (slots 0..3; 0 is transparent).
local function jasc(path)
  local f = assert(io.open(here .. "../../../" .. path, "r"))
  local lines = {}
  for l in f:lines() do lines[#lines + 1] = l end
  f:close()
  local out = {}
  for i = 4, 7 do
    local r, g, b = lines[i]:match("(%d+)%s+(%d+)%s+(%d+)")
    out[#out + 1] = (tonumber(r) >> 3) | ((tonumber(g) >> 3) << 5) | ((tonumber(b) >> 3) << 10)
  end
  return out
end

local function rockPalette()
  for i = 0, 15 do
    local o = S.gObjectEvents + i * S.ObjectEvent.stride
    if (F.r8(o) & 1) ~= 0 and F.r8(o + S.ObjectEvent.localId) == LOCALID_ROCK then
      local sprite = S.gSprites + F.r8(o + 35) * S.Sprite.stride
      local slot = F.r8(sprite + 5) >> 4
      local c = {}
      for k = 0, 3 do c[#c + 1] = F.r16(S.gPlttBufferUnfaded + (256 + slot * 16 + k) * 2) end
      return c, slot
    end
  end
end
local function fmtPal(c)
  if not c then return "none" end
  local t = {}
  for _, v in ipairs(c) do t[#t + 1] = string.format("%04X", v) end
  return table.concat(t, " ")
end
local function samePal(a, b)
  if not a or not b then return false end
  for i = 2, 4 do if a[i] ~= b[i] then return false end end   -- slot 0 is transparent
  return true
end
-- The 32 bytes past each palette buffer that slot 0xFF addresses belong to other EWRAM data. They
-- are set to a sentinel around each action (and restored after), so any stray write shows even
-- when it repeats bytes an earlier write already left there.
local SENTINEL = 0x5AA5C33C
local function strayWords(fn)
  for _, base in ipairs({ S.gPlttBufferUnfaded, S.gPlttBufferFaded }) do
    for k = 0, 31, 4 do fn(base + STRAY + k) end
  end
end
local function armStray()
  local saved = {}
  strayWords(function(a) saved[#saved + 1] = F.r32(a); F.w32(a, SENTINEL) end)
  return saved
end
local function strayIntact(saved)
  local intact, i = true, 0
  strayWords(function(a)
    i = i + 1
    if F.r32(a) ~= SENTINEL then intact = false end
    F.w32(a, saved[i])
  end)
  return intact
end

local function walkTo(tx, ty, tag)
  for _ = 1, 60 do
    local x, y = F.pos()
    if x == tx and y == ty then return true end
    local dir
    if x < tx then dir = "Right" elseif x > tx then dir = "Left"
    elseif y < ty then dir = "Down" else dir = "Up" end
    if not F.step(dir) then F.L("  walk " .. tag .. " blocked at " .. where()); return false end
  end
  return false
end
local function touch(level)
  F.press("A", 3)
  for _ = 1, 400 do
    if hasControl() and varGet(VAR_DEOXYS_ROCK_LEVEL) == level then break end
    F.idle(1)
  end
  F.idle(30)
  return varGet(VAR_DEOXYS_ROCK_LEVEL) == level
end
local function partyRoundTrip()
  F.press("Start", 2); F.idle(60)
  local ok = F.selectStartIcon(1)   -- USM_ICO_PARTY
  if ok then F.press("A", 2); F.idle(150) end
  local opened = F.cb2() == (S.CB2_UpdatePartyMenu & ~1)
  F.shot("party_menu")
  for _ = 1, 20 do
    if hasControl() then break end
    F.press("B", 2); F.idle(40)
  end
  return ok and opened and hasControl()
end

local function island(tag, map, palettes)
  F.check(tag .. ": warped to Birth Island", warp(map[1], map[2], 0, tag), where())
  F.idle(60)
  F.check(tag .. ": stood below the stone", walkTo(15, 13, tag), where())
  F.face("Up")
  local saved = armStray()
  local c0 = rockPalette()
  F.check(tag .. ": level 0 colours", samePal(c0, palettes[1]), fmtPal(c0) .. " want " .. fmtPal(palettes[1]))
  F.check(tag .. ": the first touch moves the stone up a level", touch(1), "level=" .. varGet(VAR_DEOXYS_ROCK_LEVEL))
  local c1 = rockPalette()
  F.shot(tag .. "_level1")
  F.check(tag .. ": level 1 colours", samePal(c1, palettes[2]), fmtPal(c1) .. " want " .. fmtPal(palettes[2]))
  F.check(tag .. ": nothing written past the palette buffers", strayIntact(saved))
  F.check(tag .. ": followed the stone within 4 steps", walkTo(12, 14, tag .. "_2"), where())
  F.face("Left")
  F.check(tag .. ": the second touch moves it again", touch(2), "level=" .. varGet(VAR_DEOXYS_ROCK_LEVEL))
  local c2 = rockPalette()
  F.shot(tag .. "_level2")
  F.check(tag .. ": level 2 colours", samePal(c2, palettes[3]), fmtPal(c2) .. " want " .. fmtPal(palettes[3]))
  saved = armStray()
  F.check(tag .. ": party menu and back", partyRoundTrip())
  local c3 = rockPalette()
  F.check(tag .. ": the return to the field keeps level 2's colours", samePal(c3, palettes[3]), fmtPal(c3))
  F.check(tag .. ": still nothing written past the palette buffers", strayIntact(saved))
end

F.run(function()
  if not F.boot(HUB[1]) then F.check("boot", false); F.finish(); return end
  F.check("setup: a Pokemon that can fight", createMon(SPECIES_MEWTWO, 100, { MOVE_PSYCHIC }) == 1)
  runScript({ 0x29, FLAG_SYS_POKEMON_GET & 0xFF, FLAG_SYS_POKEMON_GET >> 8, 0x02 })   -- setflag: the party icon
  island("kanto", KANTO_BIRTH, {
    jasc("graphics/object_events/palettes/meteorite.pal"),
    jasc("graphics/field_specials/deoxys_rock_1.pal"),
    jasc("graphics/field_specials/deoxys_rock_2.pal"),
  })
  island("hoenn", HOENN_BIRTH, {
    jasc("graphics/object_events/palettes/birth_island_stone.pal"),
    jasc("graphics/field_effects/palettes/deoxys_rock_2.pal"),
    jasc("graphics/field_effects/palettes/deoxys_rock_3.pal"),
  })

  -- After the Deoxys battle the stone is hidden, so its palette is not loaded at all, yet the map
  -- still reloads it on every return to the field.
  for _, isl in ipairs({ { "hoenn after Deoxys", HOENN_BIRTH, FLAG_BATTLED_DEOXYS },
                         { "kanto after Deoxys", KANTO_BIRTH, FLAG_FOUGHT_DEOXYS } }) do
    local tag, map, flag = isl[1], isl[2], isl[3]
    F.w8(F.sb1() + S.SaveBlock1.flags + flag // 8, F.r8(F.sb1() + S.SaveBlock1.flags + flag // 8) | (1 << (flag % 8)))
    F.check(tag .. ": warped back to Birth Island", warp(HUB[1], HUB[2], 0, tag .. "_hub")
      and warp(map[1], map[2], 0, tag), where())
    F.idle(60)
    F.check(tag .. ": walked up to where the stone stood", walkTo(15, 15, tag), where())
    F.check(tag .. ": the stone is gone", rockPalette() == nil)
    local saved = armStray()
    F.check(tag .. ": party menu and back", partyRoundTrip())
    F.check(tag .. ": nothing written past the palette buffers", strayIntact(saved))
  end
  F.finish()
end)
