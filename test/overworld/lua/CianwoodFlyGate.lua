-- Chuck's wife (Cianwood City, Johto) must follow her own HM02 state, not whatever HM02 the bag holds.
--
-- One bag serves all three regions, so HM02 can already be held from Hoenn (Fortree's Steven) or
-- Kanto before the player reaches Cianwood. She used to pick her repeat line with
-- `checkitem ITEM_HM_FLY`, so a player who had not beaten Chuck heard "My husband lost to you".
-- Every talk is real input: the player walks up to the wandering NPC and presses A.
--   1. HM02 held as an HM gift leaves it (TM/HM pocket, one copy), Chuck not beaten: she says the
--      easier-to-fly and beat-the-leader lines, never the "lost to you" line, VAR_GETFLY stays 0.
--   2. Chuck's victory script state written while standing in the city (FLAG_JOHTO_BADGE_5,
--      FLAG_DEFEATED_CIANWOOD_GYM, VAR_NUM_BADGES + 1, VAR_GETFLY 1): she offers the HM, says the
--      giver's already-have line, gives the Fly speech, and VAR_GETFLY becomes 2. One HM02.
--   3. Then her repeat line.
--   4. Control without HM02: the same three talks, with a real give of HM02.
-- Oracle: the field message, read from gStringVar4 where the game expands it.
local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "CianwoodFlyGate")

local HUB_GROUP = 100
local CIANWOOD = { 89, 0 }
local WIFE = 6
local CONTEXT_SHUTDOWN = 2

local ITEM_HM02 = 683
local POCKET_TM_HM = 2
local VAR_GETFLY, VAR_NUM_BADGES = 0xA0A6, 0xA08B
local FLAG_JOHTO_BADGE_5, FLAG_DEFEATED_CIANWOOD_GYM = 0x63FC, 0x612C

local LOST_TO_YOU = "My husband lost to you"
local EASIER = "much easier if your"
local BEAT_CHUCK = "If you beat the GYM LEADER here"
local GIVE_HM = "Then you should take this HM"
local ALREADY = "Oh, you already have HM02"
local OBTAINED = "Obtained the HM02"
local FLY_SPEECH = "Teach FLY to your"

local function where() local x, y = F.pos(); return string.format("%d/%d (%d,%d)", F.grp(), F.mapn(), x, y) end
local function hasControl()
  return F.ow() and F.r8(S.sLockFieldControls) == 0 and F.r8(S.sGlobalScriptContextStatus) == CONTEXT_SHUTDOWN
end
local function instantText()
  local a = F.sb2() + S.SaveBlock2.optionsU16
  F.w16(a, (F.r16(a) & ~7) | 3)
end
local function flagAddr(id)
  local o = id - 0x6000
  return F.sb3() + S.SaveBlock3.johtoFlags + o // 8, 1 << (o % 8)
end
local function setFlag(id, on)
  local a, bit = flagAddr(id)
  F.w8(a, on and (F.r8(a) | bit) or (F.r8(a) & (~bit & 255)))
end
local function varAddr(id) return F.sb3() + S.SaveBlock3.regionVars + (id - 0xA000) * 2 end
local function setVar(id, v) F.w16(varAddr(id), v) end
local function getVar(id) return F.r16(varAddr(id)) end

local function pocketBase(p) return F.r32(S.gBagPockets + p * S.BagPocket.stride) end
local function holdHM02()
  local base = pocketBase(POCKET_TM_HM)
  for i = 0, F.pocketCap(POCKET_TM_HM) - 1 do
    if F.r16(base + i * 4) == 0 then
      F.w16(base + i * 4, ITEM_HM02)
      F.w16(base + i * 4 + 2, 1 ~ (F.r32(F.sb2() + S.SaveBlock2.encryptionKey) & 0xFFFF))
      return F.itemCount(ITEM_HM02) == 1
    end
  end
  return false
end
local function dropHM02()
  local base = pocketBase(POCKET_TM_HM)
  for i = 0, F.pocketCap(POCKET_TM_HM) - 1 do
    if F.r16(base + i * 4) == ITEM_HM02 then
      F.w16(base + i * 4, 0)
      F.w16(base + i * 4 + 2, 0 ~ (F.r32(F.sb2() + S.SaveBlock2.encryptionKey) & 0xFFFF))
    end
  end
  return F.itemCount(ITEM_HM02) == 0
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

local function wifePos()
  for i = 0, 15 do
    local b = S.gObjectEvents + i * S.ObjectEvent.stride
    if (F.r8(b) & 1) == 1 and F.r8(b + S.ObjectEvent.localId) == WIFE then
      return F.rs16(b + S.ObjectEvent.x) - 7, F.rs16(b + S.ObjectEvent.y) - 7
    end
  end
end

-- She wanders a 3x3 box, so read where she stands, walk next to her, face her and press A.
-- The talk has started once the script context leaves SHUTDOWN.
local SIDES = { { 0, 1, "Up" }, { 0, -1, "Down" }, { -1, 0, "Right" }, { 1, 0, "Left" } }
local function talkToWife(tag)
  for try = 1, 24 do
    local wx, wy = wifePos()
    if not wx then F.L("  " .. tag .. ": wife not on the map"); return false end
    local side = SIDES[(try - 1) % #SIDES + 1]
    if F.leg(wx + side[1], wy + side[2]) then
      local nx, ny = wifePos()
      if nx == wx and ny == wy then
        F.face(side[3])
        F.w8(S.gStringVar4, 0xFF)
        F.press("A", 2)
        for _ = 1, 20 do
          if F.r8(S.sGlobalScriptContextStatus) ~= CONTEXT_SHUTDOWN then
            F.L(string.format("  %s: talking from (%d,%d), try %d", tag, wx + side[1], wy + side[2], try))
            return true
          end
          emu.frameadvance()
        end
      end
    end
    F.idle(20)
  end
  F.shot(tag .. "_notalk")
  return false
end

-- Press A every 40 frames, keeping each new gStringVar4 text, until control is back. talkToWife
-- empties gStringVar4 before its A press, so the previous talk's last line is not read again.
local function playTalk(tag, frames)
  local seen, shots = {}, 0
  for i = 1, frames or 2400 do
    if i % 8 == 0 and F.reportCrash(tag) then break end
    local t = decode(S.gStringVar4)
    if t ~= "" and not seen[t] then
      seen[t] = true; seen[#seen + 1] = t; F.L("  " .. tag .. ": " .. t)
      if shots < 6 then shots = shots + 1; F.idle(12); F.shot(tag .. "_" .. #seen) end
    end
    if i > 90 and hasControl() then break end
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
local function said(seen) return table.concat(seen, " | "):sub(1, 400) end

local function talk(tag)
  F.check(tag .. ": talk to Chuck's wife", talkToWife(tag), where())
  local seen = playTalk(tag)
  F.check(tag .. ": control back", hasControl(), where())
  return seen
end

-- Chuck's victory script (CianwoodGym_EventScript_ChuckVictory) as it leaves the save.
local function chuckBeaten()
  setFlag(FLAG_JOHTO_BADGE_5, true)
  setFlag(FLAG_DEFEATED_CIANWOOD_GYM, true)
  setVar(VAR_NUM_BADGES, getVar(VAR_NUM_BADGES) + 1)
  setVar(VAR_GETFLY, 1)
end
local function chuckUnbeaten()
  setFlag(FLAG_JOHTO_BADGE_5, false)
  setFlag(FLAG_DEFEATED_CIANWOOD_GYM, false)
  setVar(VAR_NUM_BADGES, 0)
  setVar(VAR_GETFLY, 0)
end

local function scenario(tag, held)
  local seen = talk(tag .. "_before_chuck")
  F.check(tag .. ": before Chuck, never the 'lost to you' line", not saw(seen, LOST_TO_YOU), said(seen))
  F.check(tag .. ": before Chuck, the easier-to-fly line", saw(seen, EASIER), said(seen))
  F.check(tag .. ": before Chuck, the beat-the-leader line", saw(seen, BEAT_CHUCK), said(seen))
  F.check(tag .. ": before Chuck, VAR_GETFLY stays 0", getVar(VAR_GETFLY) == 0, "VAR_GETFLY=" .. getVar(VAR_GETFLY))

  chuckBeaten()
  seen = talk(tag .. "_after_chuck")
  F.check(tag .. ": after Chuck, she offers the HM", saw(seen, GIVE_HM), said(seen))
  if held then
    F.check(tag .. ": after Chuck, the already-have line", saw(seen, ALREADY), said(seen))
    F.check(tag .. ": after Chuck, no second obtain", not saw(seen, OBTAINED), said(seen))
  else
    F.check(tag .. ": after Chuck, HM02 obtained", saw(seen, OBTAINED), said(seen))
  end
  F.check(tag .. ": after Chuck, the Fly speech", saw(seen, FLY_SPEECH), said(seen))
  F.check(tag .. ": after Chuck, never the 'lost to you' line yet", not saw(seen, LOST_TO_YOU), said(seen))
  F.check(tag .. ": after Chuck, VAR_GETFLY is 2", getVar(VAR_GETFLY) == 2, "VAR_GETFLY=" .. getVar(VAR_GETFLY))
  F.check(tag .. ": one HM02 in the bag", F.itemCount(ITEM_HM02) == 1, "copies=" .. F.itemCount(ITEM_HM02))

  seen = talk(tag .. "_repeat")
  F.check(tag .. ": repeat talk says the 'lost to you' line", saw(seen, LOST_TO_YOU), said(seen))
  F.check(tag .. ": repeat talk offers nothing", not saw(seen, GIVE_HM), said(seen))
end

F.run(function()
  if not F.boot(HUB_GROUP) then F.check("boot to the hub", false); F.finish(); return end
  instantText()
  chuckUnbeaten()
  F.check("warp to Cianwood's gym door", F.warpTo(0, 8, 9, 0, 0, 0, 0, 0, 4, CIANWOOD[1], CIANWOOD[2], "cianwood"), where())
  instantText()
  F.idle(60)
  F.shot("cianwood_arrival")

  F.check("HM02 held from another region", holdHM02(), "copies=" .. F.itemCount(ITEM_HM02))
  scenario("held", true)

  chuckUnbeaten()
  F.check("control: HM02 out of the bag", dropHM02(), "copies=" .. F.itemCount(ITEM_HM02))
  scenario("control", false)
  F.finish()
end)
