-- The Lake of Rage fisherman's Magikarp sale (LakeOfRage_House2, after the Rocket event).
--
-- He buys a Magikarp from the party (removegenericmon). The sale must follow the same rules as
-- every other way a Pokemon leaves the party: it may not take the last healthy, non-Egg Pokemon,
-- an Egg is not a Magikarp, and a Magikarp holding Mail must take its letter with it. Before the
-- fix the script only refused a party of one, the species check read through Eggs, and the slot
-- was zeroed with the letter still allocated in the party mailbox.
--
-- Setup gives the party with the debug Give menu and `giveegg`, sets the Rocket event done and
-- warps into the house; talking to the fisherman, Yes, the party pick and every message are real
-- input:
--   1. Magikarp and an Egg: selling the Magikarp must be refused, nothing paid;
--   2. a Magikarp Egg and a Bulbasaur: picking the Egg must be refused as not a Magikarp;
--   3. control: Magikarp, Egg and Bulbasaur: the Magikarp sells for 2,000;
--   4. a second Magikarp holding Orange Mail: it sells, and its letter is freed.
--
-- Run via test/overworld/mgba-run.sh test/overworld/lua/LakeOfRageMagikarpSale.lua <rom.gba>

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "LakeOfRageMagikarpSale")

local PARTY_SIZE, MON = 6, S.Pokemon.size
local SPECIES_BULBASAUR, SPECIES_MAGIKARP = 1, 129
local ITEM_ORANGE_MAIL = 199
local MAIL_SIZE, MON_MAIL, MAIL_NONE = 36, 85, 0xFF
local VAR_MAHOGANY_TOWN_STATE = 0xA091
local HOUSE_G, HOUSE_M = 92, 8
local FISHER_APPROACH = { 5, 5 }   -- below the fisherman at (5,4)
local CONTEXT_SHUTDOWN = 2
local PARTY_MENU_SLOT = 9          -- struct PartyMenu.slotId

local function party(slot) return S.gParties + slot * MON end
local function mail(i) return F.sb1() + S.SaveBlock1.mail + i * MAIL_SIZE end
local function count() return F.r8(S.gPartiesCount) end

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
local function writeWords(a, w)
  local key = F.r32(a) ~ F.r32(a + 4)
  local sum = 0
  for i = 0, 11 do
    sum = (sum + (w[i] & 0xFFFF) + (w[i] >> 16)) & 0xFFFF
    F.w32(a + 32 + i * 4, w[i] ~ key)
  end
  F.w16(a + 28, sum)
end
local function species(a) local w, o = words(a); return w[o[0]] & 0x7FF end
local function isEgg(a) return (F.r8(a + 19) & 4) ~= 0 end
local function setHeldItem(a, item)
  local w, o = words(a)
  w[o[0]] = (w[o[0]] & ~(0x3FF << 16)) | (item << 16)
  writeWords(a, w)
end
local function checksumOk(a)
  local w = words(a)
  local sum = 0
  for i = 0, 11 do sum = sum + (w[i] & 0xFFFF) + (w[i] >> 16) end
  return (sum & 0xFFFF) == F.r16(a + 28)
end
local function putBytes(base, value) for i = 1, #value do F.w8(base + i - 1, value:byte(i)) end end
local function letter(seed, item)
  local w = {}
  for i = 0, 8 do w[#w + 1] = string.char((seed + i) & 255, (seed >> 8) & 255) end
  return table.concat(w) .. "PLAYER\255\255\0\0\0\0" .. string.char(SPECIES_MAGIKARP, 0, item & 255, item >> 8, 0, 0)
end

local function instantText()
  local a = F.sb2() + S.SaveBlock2.optionsU16
  F.w16(a, (F.r16(a) & ~7) | 3)
end

local SCRIPT_BUF = S.gStringVar4 + 960
local function le16(t, v) t[#t + 1] = v & 0xFF; t[#t + 1] = (v >> 8) & 0xFF end
local function runScript(b)
  for i, v in ipairs(b) do F.w8(SCRIPT_BUF + i - 1, v) end
  F.w8(S.sGlobalScriptContext, 0)
  F.w8(S.sGlobalScriptContext + 1, 1)
  F.w32(S.sGlobalScriptContext + 4, 0)
  F.w32(S.sGlobalScriptContext + S.ScriptCtx.scriptPtr, SCRIPT_BUF)
  F.w8(S.sGlobalScriptContextStatus, 0)
end
local function giveEgg(sp)
  local before = count()
  local b = { 0x7A }; le16(b, sp); b[#b + 1] = 0x02   -- giveegg, end
  runScript(b); F.idle(30)
  return count() == before + 1
end

local function digits(n) n = n - 1; return n // 100, (n // 10) % 10, n % 10 end
local function giveMon(sp, level)
  local before = count()
  for _ = 1, 3 do
    F.dbg(); F.sel(3); F.sel(1); F.idle(20)
    F.spin(digits(sp)); F.idle(20)
    F.spin(digits(level)); F.idle(60); F.bOut(4)
    if count() == before + 1 and species(party(before)) == sp then return true end
    F.idle(60)
  end
  return false
end
local function clearParty()
  for off = 0, PARTY_SIZE * MON - 4, 4 do F.w32(S.gParties + off, 0) end
  F.w8(S.gPartiesCount, 0)
end

local function hasMagikarp()
  for i = 0, PARTY_SIZE - 1 do
    if F.r32(party(i)) ~= 0 and not isEgg(party(i)) and species(party(i)) == SPECIES_MAGIKARP then return true end
  end
  return false
end
local function inPartyMenu() return F.cb2() == (S.CB2_UpdatePartyMenu & ~1) end
local function scriptDone() return F.r8(S.sGlobalScriptContextStatus) == CONTEXT_SHUTDOWN end

-- Talk to the fisherman, answer Yes, pick party slot `slot`, then clear every message.
local function sell(slot, tag)
  if not F.leg(FISHER_APPROACH[1], FISHER_APPROACH[2]) then F.check(tag .. ": reached the fisherman", false); return end
  F.face("Up"); F.press("A", 2); F.idle(40)
  local picked = false
  for _ = 1, 300 do
    if inPartyMenu() then
      F.idle(30)
      for _ = 1, 10 do
        local s = F.rs8(S.gPartyMenu + PARTY_MENU_SLOT)
        if s == slot then break end
        F.press(s < slot and "Down" or "Up", 2); F.idle(16)
      end
      picked = F.rs8(S.gPartyMenu + PARTY_MENU_SLOT) == slot
      F.press("A", 2); F.idle(90)
      F.shot(tag:gsub("%W", "_") .. "_answer")
    elseif F.ow() and scriptDone() then
      break
    else
      F.press("A", 2); F.idle(30)
    end
  end
  F.idle(30)
  F.check(tag .. ": picked party slot " .. slot, picked)
  F.check(tag .. ": back in control", F.ow() and scriptDone())
end

F.run(function()
  if not F.boot(100) then F.check("boot to the hub", false); F.finish(); return end
  instantText()
  F.w16(F.sb3() + S.SaveBlock3.regionVars + (VAR_MAHOGANY_TOWN_STATE - 0xA000) * 2, 14)
  F.check("warp: Lake of Rage fisherman's house", F.warpTo(0, 9, 2, 0, 0, 8, 0, 0, 0, HOUSE_G, HOUSE_M, "house"))
  instantText()

  do
    local tag = "Magikarp and an Egg"
    clearParty()
    F.check(tag .. ": setup", giveMon(SPECIES_MAGIKARP, 20) and giveEgg(SPECIES_BULBASAUR) and count() == 2)
    local pid, money = F.r32(party(0)), F.money()
    sell(0, tag)
    F.check(tag .. ": the Magikarp is still in the party", F.r32(party(0)) == pid and count() == 2,
      string.format("count=%d", count()))
    F.check(tag .. ": nothing was paid", F.money() == money, string.format("%d -> %d", money, F.money()))
  end

  do
    local tag = "a Magikarp Egg"
    clearParty()
    F.check(tag .. ": setup", giveEgg(SPECIES_MAGIKARP) and giveMon(SPECIES_BULBASAUR, 20) and count() == 2
      and isEgg(party(0)))
    local pid, money = F.r32(party(0)), F.money()
    sell(0, tag)
    F.check(tag .. ": the Egg is still in the party", F.r32(party(0)) == pid and count() == 2,
      string.format("count=%d", count()))
    F.check(tag .. ": nothing was paid", F.money() == money, string.format("%d -> %d", money, F.money()))
  end

  do
    local tag = "control"
    clearParty()
    F.check(tag .. ": setup", giveMon(SPECIES_MAGIKARP, 20) and giveEgg(SPECIES_BULBASAUR)
      and giveMon(SPECIES_BULBASAUR, 20) and count() == 3)
    local money = F.money()
    sell(0, tag)
    F.check(tag .. ": the Magikarp was sold", count() == 2 and not hasMagikarp(), string.format("count=%d", count()))
    F.check(tag .. ": 2,000 was paid", F.money() == money + 2000, string.format("%d -> %d", money, F.money()))
  end

  do
    local tag = "a Magikarp holding Mail"
    F.check(tag .. ": setup", giveMon(SPECIES_MAGIKARP, 20) and count() == 3)
    for i = 0, 15 do for b = 0, MAIL_SIZE - 1 do F.w8(mail(i) + b, 0) end end
    putBytes(mail(0), letter(0x4321, ITEM_ORANGE_MAIL))
    for i = 0, 1 do F.w8(party(i) + MON_MAIL, MAIL_NONE) end
    setHeldItem(party(2), ITEM_ORANGE_MAIL)
    F.w8(party(2) + MON_MAIL, 0)
    local money = F.money()
    sell(2, tag)
    F.check(tag .. ": the Magikarp was sold", count() == 2, string.format("count=%d", count()))
    F.check(tag .. ": its letter was freed", F.r16(mail(0) + 32) == 0, "mail[0].itemId=" .. F.r16(mail(0) + 32))
    F.check(tag .. ": 2,000 was paid", F.money() == money + 2000, string.format("%d -> %d", money, F.money()))
  end

  F.check("no crash", not F.reportCrash("end"))
  F.finish()
end)
