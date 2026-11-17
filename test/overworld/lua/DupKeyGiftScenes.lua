-- A key item the player already owns from another region must not break the scene that gives it.
--
-- One bag serves all three regions and IsDuplicateKeyClassItem (src/item.c) refuses a second copy
-- of a key-class item, so Std_ObtainItem used to print "But {PLAYER} already has one ..." in the
-- middle of the speaker's lines. Three real scenes, each driven with real input and seeded the way
-- the other region's give leaves the bag (the item in the Key Items pocket):
--   1. Dad's S.S. TICKET after the Hoenn Hall of Fame, with Bill's Kanto ticket already held
--      (the ON_FRAME scene starts on the real stairs from 2F, the Lati TV color picked with A);
--   2. the Mossdeep SUPER ROD fisherman (Hoenn) with Kanto's Route 12 rod held;
--   3. the Vermilion OLD ROD fisherman (Kanto) with a Hoenn or Johto rod held;
--   4. the Rustboro Cutter's HM01 (Hoenn, givekeyitem) with the S.S. Anne captain's HM01 held.
-- Each must never show the refusal, must say the speaker's own already-have line, must finish
-- with the same flags the give sets, and must leave exactly one copy in the bag.
-- Oracle: the field message, read from gStringVar4 where the game expands it.
local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "DupKeyGiftScenes")

local HUB_GROUP = 100
local BRENDAN_1F, BRENDAN_2F = { 1, 0 }, { 1, 1 }
local MOSSDEEP_HOUSE3 = { 14, 6 }
local VERMILION_HOUSE1 = { 43, 0 }
local CUTTERS_HOUSE = { 11, 11 }
local CONTEXT_SHUTDOWN = 2

local ITEM_HM01, ITEM_OLD_ROD, ITEM_SUPER_ROD, ITEM_SS_TICKET = 682, 709, 711, 727
local VAR_HOUSES_STATE_MAY, VAR_HOUSES_STATE_BRENDAN, VAR_INTRO = 0x4082, 0x408C, 0x4092
local FLAG_RECEIVED_SS_TICKET, FLAG_RECEIVED_SUPER_ROD, FLAG_GOT_OLD_ROD = 0x123, 0x98, 0xA40 + 0x240
local FLAG_RECEIVED_HM_CUT = 0x89
local FLAG_HIDE_DAD, FLAG_HIDE_MOM = 0x2DE, 0x2F6
local HIDE_IN_PLAYERS_HOUSE = { 0x2DF, 0x2E9, 0x2F2, 0x2F3, 0x310 }   -- rival family, Vigoroths

local function where() local x, y = F.pos(); return string.format("%d/%d (%d,%d)", F.grp(), F.mapn(), x, y) end
local function hasControl()
  return F.ow() and F.r8(S.sLockFieldControls) == 0 and F.r8(S.sGlobalScriptContextStatus) == CONTEXT_SHUTDOWN
end
local function instantText()
  local a = F.sb2() + S.SaveBlock2.optionsU16
  F.w16(a, (F.r16(a) & ~7) | 3)
end
local function flagAddr(n) return F.sb1() + S.SaveBlock1.flags + n // 8, 1 << (n % 8) end
local function setFlag(n, on)
  local a, bit = flagAddr(n)
  F.w8(a, on and (F.r8(a) | bit) or (F.r8(a) & (~bit & 255)))
end
local function flagSet(n) local a, bit = flagAddr(n); return F.r8(a) & bit ~= 0 end
local function varAddr(id) return F.sb1() + S.SaveBlock1.vars + (id - 0x4000) * 2 end
local function setVar(id, v) F.w16(varAddr(id), v) end
local function getVar(id) return F.r16(varAddr(id)) end

-- The other region's give: one copy in its pocket, quantity encrypted like AddBagItem.
local POCKET_TM_HM, POCKET_KEY_ITEMS = 2, 4
local function holdItem(id, pocket)
  pocket = pocket or POCKET_KEY_ITEMS
  local base = F.r32(S.gBagPockets + pocket * S.BagPocket.stride)
  for i = 0, F.pocketCap(pocket) - 1 do
    if F.r16(base + i * 4) == id then return true end
  end
  for i = 0, F.pocketCap(pocket) - 1 do
    if F.r16(base + i * 4) == 0 then
      F.w16(base + i * 4, id)
      F.w16(base + i * 4 + 2, 1 ~ (F.r32(F.sb2() + S.SaveBlock2.encryptionKey) & 0xFFFF))
      return F.itemCount(id) == 1
    end
  end
  return false
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
    elseif c == 0xAE then out[#out + 1] = "-"
    elseif c == 0xB8 then out[#out + 1] = ","
    elseif c == 0xB4 then out[#out + 1] = "'"
    elseif c == 0xFE or c == 0xFA or c == 0xFB then out[#out + 1] = " "
    else out[#out + 1] = "~" end
  end
  return table.concat(out)
end

-- Press A every 40 frames, keeping each new gStringVar4 text, until `done()` holds with control back.
local function playScene(tag, frames, done)
  local seen, shots = {}, 0
  for i = 1, frames do
    if i % 8 == 0 and F.reportCrash(tag) then break end
    local t = decode(S.gStringVar4)
    if not seen[t] then
      seen[t] = true; seen[#seen + 1] = t; F.L("  " .. tag .. ": " .. t)
      if shots < 6 then shots = shots + 1; F.idle(12); F.shot(tag .. "_" .. #seen) end
    end
    if i > 120 and done() and hasControl() then break end
    joypad.set(i % 40 < 2 and { A = true } or {})
    emu.frameadvance()
  end
  joypad.set({})
  return seen
end
local function saw(seen, text)
  for _, t in ipairs(seen) do if t:find(text, 1, true) then return true end end
  return false
end
local function refusal(seen)
  for _, t in ipairs(seen) do if t:find("already has", 1, true) then return t end end
  return nil
end
local function copies(id) return F.itemCount(id) end

local function talkUp() F.face("Up"); F.press("A", 2); F.idle(10) end

local function warp(m, tag)
  local g, n = m[1], m[2]
  return F.warpTo(g // 100, (g // 10) % 10, g % 10, n // 100, (n // 10) % 10, n % 10, 0, 0, 0, g, n, tag)
end

local function checkScene(tag, seen, own, follow)
  F.check(tag .. ": never prints the duplicate refusal", refusal(seen) == nil, refusal(seen) or "")
  F.check(tag .. ": says it already has one, in the speaker's voice", saw(seen, own), table.concat(seen, " | "):sub(1, 300))
  F.check(tag .. ": the rest of the scene plays", saw(seen, follow), follow)
end

F.run(function()
  if not F.boot(HUB_GROUP) then F.check("boot to the hub", false); F.finish(); return end
  instantText()

  -- 1. Dad's ticket after the Hoenn Hall of Fame, as EverGrandeCity_HallOfFame leaves the house.
  F.check("Bill's S.S. TICKET is in the bag", holdItem(ITEM_SS_TICKET))
  setVar(VAR_INTRO, 7)
  setVar(VAR_HOUSES_STATE_MAY, 3)
  setVar(VAR_HOUSES_STATE_BRENDAN, 3)
  setFlag(FLAG_HIDE_DAD, false)
  setFlag(FLAG_HIDE_MOM, false)
  for _, f in ipairs(HIDE_IN_PLAYERS_HOUSE) do setFlag(f, true) end
  F.check("warp to the player's bedroom", warp(BRENDAN_2F, "bedroom"), where())
  instantText()
  F.leg(7, 2)
  F.press("Up", 20); F.idle(30)
  F.check("down the stairs into the 1F", F.grp() == BRENDAN_1F[1] and F.mapn() == BRENDAN_1F[2], where())
  local seen = playScene("dad", 9000, function() return getVar(VAR_HOUSES_STATE_MAY) == 4 end)
  F.shot("dad_after")
  F.check("dad: Dad's ticket scene ran", saw(seen, "MR. BRINEY"), table.concat(seen, " | "):sub(1, 300))
  checkScene("dad", seen, "you already have one", "ferry ports in")
  F.check("dad: the Lati TV scene finished (house state 4)", getVar(VAR_HOUSES_STATE_MAY) == 4, "state=" .. getVar(VAR_HOUSES_STATE_MAY))
  F.check("dad: FLAG_RECEIVED_SS_TICKET set", flagSet(FLAG_RECEIVED_SS_TICKET))
  F.check("dad: one S.S. TICKET in the bag", copies(ITEM_SS_TICKET) == 1, "copies=" .. copies(ITEM_SS_TICKET))
  F.check("dad: control back after the scene", hasControl(), where())

  -- 2. Mossdeep's SUPER ROD, with Kanto's Route 12 rod held.
  F.check("Kanto's SUPER ROD is in the bag", holdItem(ITEM_SUPER_ROD))
  F.check("warp to the Mossdeep fisherman's house", warp(MOSSDEEP_HOUSE3, "mossdeep"), where())
  instantText()
  F.check("walk to the fisherman", F.route({ { 3, 6 }, { 4, 6 }, { 4, 5 } }, "mossdeep_walk"), where())
  talkUp()
  seen = playScene("mossdeep", 3000, function() return flagSet(FLAG_RECEIVED_SUPER_ROD) end)
  F.shot("mossdeep_after")
  checkScene("mossdeep", seen, "already have a", "see what bites")
  F.check("mossdeep: FLAG_RECEIVED_SUPER_ROD set", flagSet(FLAG_RECEIVED_SUPER_ROD))
  F.check("mossdeep: one SUPER ROD in the bag", copies(ITEM_SUPER_ROD) == 1, "copies=" .. copies(ITEM_SUPER_ROD))
  F.check("mossdeep: control back", hasControl(), where())

  -- 3. Vermilion's OLD ROD, with a Hoenn or Johto rod held.
  F.check("an OLD ROD is in the bag", holdItem(ITEM_OLD_ROD))
  F.check("warp to the Vermilion fishing guru", warp(VERMILION_HOUSE1, "vermilion"), where())
  instantText()
  F.check("walk to the guru", F.route({ { 3, 6 }, { 4, 6 } }, "vermilion_walk"), where())
  talkUp()
  seen = playScene("vermilion", 3000, function() return flagSet(FLAG_GOT_OLD_ROD) end)
  F.shot("vermilion_after")
  checkScene("vermilion", seen, "already have an", "way of life")
  F.check("vermilion: FLAG_GOT_OLD_ROD set", flagSet(FLAG_GOT_OLD_ROD))
  F.check("vermilion: one OLD ROD in the bag", copies(ITEM_OLD_ROD) == 1, "copies=" .. copies(ITEM_OLD_ROD))
  F.check("vermilion: control back", hasControl(), where())

  -- 4. Rustboro's HM01, with the S.S. Anne captain's HM01 held.
  F.check("Kanto's HM01 is in the bag", holdItem(ITEM_HM01, POCKET_TM_HM))
  F.check("warp to the Cutter's house", warp(CUTTERS_HOUSE, "cutter"), where())
  instantText()
  F.check("walk to the Cutter", F.route({ { 5, 7 }, { 7, 7 }, { 7, 6 } }, "cutter_walk"), where())
  talkUp()
  seen = playScene("cutter", 3000, function() return flagSet(FLAG_RECEIVED_HM_CUT) end)
  F.shot("cutter_after")
  checkScene("cutter", seen, "already have HM01", "HIDDEN MACHINE, or HM")
  F.check("cutter: FLAG_RECEIVED_HM_CUT set", flagSet(FLAG_RECEIVED_HM_CUT))
  F.check("cutter: one HM01 in the bag", copies(ITEM_HM01) == 1, "copies=" .. copies(ITEM_HM01))
  F.check("cutter: control back", hasControl(), where())
  F.finish()
end)
