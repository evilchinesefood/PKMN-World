-- The Radio Tower Director's rescue talk must not depend on which CARD KEY the bag holds.
--
-- ITEM_CARD_KEY is also Silph Co.'s Kanto CARD KEY, and key items carry across regions. The
-- Director (Goldenrod Underground Storage, Team Rocket takeover) used `checkitem ITEM_CARD_KEY`
-- to tell a first talk from a repeat, so a player holding Silph's key skipped his rescue lines
-- and never heard that the key opens the shutters on 3F.
-- Two cases, each talked to twice with real input from (14,8) facing him:
--   1. Silph's CARD KEY held, seeded the way the 5F item ball leaves it (its hide flag set, one
--      key in the Key Items pocket);
--   2. no CARD KEY held (the plain story path).
-- First talk: the rescue lines and the shutter hint, never the duplicate refusal. Second talk:
-- the repeat plea only. Both: exactly one CARD KEY in the bag.
-- Setup: Johto state as the Underground Switches leave it (VAR_GOLDENROD_CITY_STATE 9, Rockets
-- out) and Eto, whose sight covers the only way in, marked beaten.
-- Oracle: the field message, read from gStringVar4 where the game expands it.
local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "RadioDirectorCardKey")

local HUB_GROUP = 100
local STORAGE = { 84, 25 }
local CONTEXT_SHUTDOWN = 2
local POCKET_KEY_ITEMS = 4

local ITEM_CARD_KEY = 750
local VAR_GOLDENROD_CITY_STATE = 0xA083
local FLAG_HIDE_GOLDENROD_ROCKETS = 0x6000 + 0xDD
local FLAG_UNLOCKED_GOLDENROD_UNDERGROUND_DOOR = 0x6000 + 0xE9
local FLAG_GOT_RADIO_TOWER_CARD_KEY = 0x6000 + 0x25F
local FLAG_HIDE_SILPH_CO_5F_CARD_KEY = 0xA40 + 0x192
local FLAG_TRAINER_ETO_3 = 0x500 + 900

local function where() local x, y = F.pos(); return string.format("%d/%d (%d,%d)", F.grp(), F.mapn(), x, y) end
local function hasControl()
  return F.ow() and F.r8(S.sLockFieldControls) == 0 and F.r8(S.sGlobalScriptContextStatus) == CONTEXT_SHUTDOWN
end
local function instantText()
  local a = F.sb2() + S.SaveBlock2.optionsU16
  F.w16(a, (F.r16(a) & ~7) | 3)
end
local function flagAddr(id)
  if id >= 0x6000 and id < 0x6400 then return F.sb3() + S.SaveBlock3.johtoFlags + (id - 0x6000) // 8, 1 << ((id - 0x6000) % 8) end
  return F.sb1() + S.SaveBlock1.flags + id // 8, 1 << (id % 8)
end
local function flagGet(id) local a, bit = flagAddr(id); return F.r8(a) & bit ~= 0 end
local function flag(id, on)
  local a, bit = flagAddr(id)
  F.w8(a, on and (F.r8(a) | bit) or (F.r8(a) & (~bit & 255)))
end
local function var(id, v) F.w16(F.sb3() + S.SaveBlock3.regionVars + (id - 0xA000) * 2, v) end
local function varGet(id) return F.r16(F.sb3() + S.SaveBlock3.regionVars + (id - 0xA000) * 2) end

local function key() return F.r32(F.sb2() + S.SaveBlock2.encryptionKey) & 0xFFFF end
local function keySlot(id)
  local base = F.r32(S.gBagPockets + POCKET_KEY_ITEMS * S.BagPocket.stride)
  for i = 0, F.pocketCap(POCKET_KEY_ITEMS) - 1 do
    if F.r16(base + i * 4) == id then return base + i * 4 end
  end
  return nil
end
-- The bag's own slot shape: plaintext id, quantity XORed with the encryption key.
local function setKeyItem(id, qty)
  local slot = keySlot(id) or keySlot(0)
  if not slot then return false end
  F.w16(slot, qty > 0 and id or 0)
  F.w16(slot + 2, qty ~ key())
  return true
end
local function held(id)
  local slot = keySlot(id)
  return F.itemCount(id), slot and (F.r16(slot + 2) ~ key()) or 0
end

local function decode(addr, max)
  local out = {}
  for i = 0, (max or 400) - 1 do
    local c = F.r8(addr + i)
    if c == 0xFF then break end
    if c == 0x00 then out[#out + 1] = " "
    elseif c >= 0xBB and c <= 0xD4 then out[#out + 1] = string.char(65 + c - 0xBB)
    elseif c >= 0xD5 and c <= 0xEE then out[#out + 1] = string.char(97 + c - 0xD5)
    elseif c >= 0xA1 and c <= 0xAA then out[#out + 1] = string.char(48 + c - 0xA1)
    elseif c == 0xAB then out[#out + 1] = "!"
    elseif c == 0xAC then out[#out + 1] = "?"
    elseif c == 0xAD then out[#out + 1] = "."
    elseif c == 0xB4 then out[#out + 1] = "'"
    elseif c == 0xF0 then out[#out + 1] = ":"
    elseif c == 0xFE or c == 0xFA or c == 0xFB then out[#out + 1] = " "
    else out[#out + 1] = "~" end
  end
  return table.concat(out)
end

-- Talk (gStringVar4 emptied first so the last scene's text is not read), then press A every 40 frames, keeping each new gStringVar4 text, until control is back.
local function talk(tag)
  F.w8(S.gStringVar4, 0xFF)
  F.face("Left")
  F.press("A", 2)
  local seen, shots = {}, 0
  for i = 1, 3000 do
    if i % 8 == 0 and F.reportCrash(tag) then break end
    local t = decode(S.gStringVar4)
    if not seen[t] then
      seen[t] = true; seen[#seen + 1] = t; F.L("  " .. tag .. ": " .. t)
      if shots < 6 then shots = shots + 1; F.idle(12); F.shot(tag .. "_" .. #seen) end
    end
    if i > 120 and hasControl() then break end
    joypad.set(i % 40 < 2 and { A = true } or {})
    emu.frameadvance()
  end
  joypad.set({})
  F.idle(20)
  return seen
end
local function saw(seen, text)
  for _, t in ipairs(seen) do if t:find(text, 1, true) then return true end end
  return false
end
local function joined(seen) return table.concat(seen, " | "):sub(1, 400) end

local function playCase(tag, keyLine)
  local first = talk(tag .. "_first")
  F.check(tag .. ": first talk says " .. keyLine, saw(first, keyLine), joined(first))
  F.check(tag .. ": first talk plays the rescue lines", saw(first, "rescue me") and saw(first, "Take this CARD KEY"), joined(first))
  F.check(tag .. ": first talk gives the shutter hint", saw(first, "shutters on 3F"), joined(first))
  F.check(tag .. ": first talk never prints the duplicate refusal", not saw(first, "already has"), joined(first))
  F.check(tag .. ": first talk is not the repeat plea", not saw(first, "begging you"), joined(first))
  F.check(tag .. ": control back after the first talk", hasControl(), where())

  local second = talk(tag .. "_second")
  F.check(tag .. ": second talk is the repeat plea", saw(second, "begging you"), joined(second))
  F.check(tag .. ": second talk does not replay the rescue", not saw(second, "rescue me") and not saw(second, "shutters on 3F"), joined(second))
  F.check(tag .. ": control back after the second talk", hasControl(), where())
  local n, qty = held(ITEM_CARD_KEY)
  F.check(tag .. ": one CARD KEY in the bag", n == 1 and qty == 1, string.format("slots=%d qty=%d", n, qty))
end

F.run(function()
  if not F.boot(HUB_GROUP) then F.check("boot to the hub", false); F.finish(); return end
  instantText()
  F.check("setup: no CARD KEY at the start", held(ITEM_CARD_KEY) == 0)

  var(VAR_GOLDENROD_CITY_STATE, 9)
  flag(FLAG_HIDE_GOLDENROD_ROCKETS, false)
  flag(FLAG_UNLOCKED_GOLDENROD_UNDERGROUND_DOOR, true)
  flag(FLAG_TRAINER_ETO_3, true)

  -- 1. Silph Co.'s CARD KEY held, as the 5F item ball leaves the bag.
  flag(FLAG_HIDE_SILPH_CO_5F_CARD_KEY, true)
  F.check("silph: Kanto CARD KEY in the bag", setKeyItem(ITEM_CARD_KEY, 1) and held(ITEM_CARD_KEY) == 1)

  F.check("warp to the Underground Storage", F.warpTo(0, 8, 4, 0, 2, 5, 0, 0, 0, STORAGE[1], STORAGE[2], "storage"), where())
  instantText()
  F.check("takeover state 9 survives the warp", varGet(VAR_GOLDENROD_CITY_STATE) == 9, "state=" .. varGet(VAR_GOLDENROD_CITY_STATE))
  F.check("walk to the Director", F.route({ { 11, 2 }, { 11, 5 }, { 14, 5 }, { 14, 8 } }, "to_director"), where())
  F.shot("at_director")
  playCase("silph", "you already have a")

  -- 2. No CARD KEY held: the bag and the Director as a new game leaves them.
  F.check("plain: CARD KEY removed", setKeyItem(ITEM_CARD_KEY, 0) and held(ITEM_CARD_KEY) == 0)
  flag(FLAG_HIDE_SILPH_CO_5F_CARD_KEY, false)
  flag(FLAG_GOT_RADIO_TOWER_CARD_KEY, false)
  playCase("plain", "Obtained the Card Key")
  F.finish()
end)
