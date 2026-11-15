-- A catch with a full party, "add it to your party?" Yes: the party Pokemon sent to the PC in its
-- place must not hold Mail.
--
-- A letter lives in the party's mail slots and is linked from its holder. The PC refuses to box a
-- Mail holder, but the catch swap (B_CATCH_SWAP_INTO_PARTY) only refused partner Pokemon and HM
-- users, so choosing a Mail holder boxed it with its Mail: the letter stayed allocated with no
-- holder and the boxed Pokemon held Mail with no mail index.
--
-- Setup gives six Bulbasaur through the debug menu (the third holds Orange Mail, letter in mailbox
-- slot 0, linked the way GiveMailToMonByItemId leaves it), adds one Master Ball with `additem` and
-- starts a wild Pidgey with `setwildbattle` + `dowildbattle`. The throw (the last-used-ball R
-- shortcut), the nickname prompt and naming screen, "add to party?", the party pick and "send to
-- the PC?" are real input. The suite first picks the Mail holder and confirms; it must be refused
-- and the menu must come back, and the suite then picks the fourth Bulbasaur (control), which must
-- go to the PC. The Mail holder must end in the party with its letter linked and Pidgey must join.
--
-- Run via test/overworld/mgba-run.sh test/overworld/lua/CatchSwapMailHolder.lua <rom.gba>

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "CatchSwapMailHolder")

local PARTY_SIZE, MON = 6, S.Pokemon.size
local BOXES, PER_BOX, BOX_MON = 14, 30, S.BoxPokemon.size
local BULBASAUR, SPECIES_PIDGEY = 1, 16
local ITEM_ORANGE_MAIL, ITEM_MASTER_BALL = 199, 4
local MAIL_SIZE, MON_MAIL, MAIL_NONE = 36, 85, 0xFF
local PARTY_MENU_SLOT = 9   -- struct PartyMenu.slotId
local MAIL_SLOT, CONTROL_SLOT = 2, 3

local function party(slot) return S.gParties + slot * MON end
local function boxSlot(box, slot) return F.r32(S.gPokemonStoragePtr) + 4 + (box * PER_BOX + slot) * BOX_MON end
local function mail(i) return F.sb1() + S.SaveBlock1.mail + i * MAIL_SIZE end

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
local function heldItem(a) local w, o = words(a); return (w[o[0]] >> 16) & 0x3FF end
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

local function bytes(base, size)
  local t = {}
  for i = 0, size - 1 do t[#t + 1] = string.char(F.r8(base + i)) end
  return table.concat(t)
end
local function putBytes(base, value) for i = 1, #value do F.w8(base + i - 1, value:byte(i)) end end
local function letter(seed, item)
  local w = {}
  for i = 0, 8 do w[#w + 1] = string.char((seed + i) & 255, (seed >> 8) & 255) end
  return table.concat(w) .. "PLAYER\255\255\0\0\0\0" .. string.char(BULBASAUR, 0, item & 255, item >> 8, 0, 0)
end

local function instantText()
  local a = F.sb2() + S.SaveBlock2.optionsU16
  F.w16(a, (F.r16(a) & ~7) | 3)
end

local function digits(n) n = n - 1; return n // 100, (n // 10) % 10, n % 10 end
local function giveParty(n, sp, level)
  for _ = 1, 3 do
    for off = 0, PARTY_SIZE * MON - 4, 4 do F.w32(S.gParties + off, 0) end
    F.w8(S.gPartiesCount, 0)
    F.dbg(); F.idle(30); F.bOut(4)
    for _ = 1, n do
      F.dbg(); F.sel(3); F.sel(1); F.idle(20)
      F.spin(digits(sp)); F.idle(20)
      F.spin(digits(level)); F.idle(60); F.bOut(4)
    end
    local ok = F.r8(S.gPartiesCount) == n
    for i = 0, n - 1 do ok = ok and checksumOk(party(i)) end
    if ok then return true end
    F.idle(60)
  end
  return false
end

-- Script bytes run from the tail of gStringVar4, which no message reaches.
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

local function inBattle() return F.cb2() == (S.BattleMainCB2 & ~1) end
local function inPartyMenu() return F.cb2() == (S.CB2_UpdatePartyMenu & ~1) end
local function ctrl(b) return F.r32(S.gBattlerControllerFuncs + b * 4) & ~1 end
local function actionMenu()
  for _, p in ipairs(S.ActionInputFunctions) do if ctrl(0) == (p & ~1) then return true end end
  return false
end
local function partySlotOf(pid)
  for i = 0, PARTY_SIZE - 1 do if pid ~= 0 and F.r32(party(i)) == pid then return i end end
  return nil
end
local function boxSlotOf(pid)
  for b = 0, BOXES - 1 do
    for s = 0, PER_BOX - 1 do if F.r32(boxSlot(b, s)) == pid then return b * PER_BOX + s end end
  end
  return nil
end
local function boxedCount()
  local n = 0
  for b = 0, BOXES - 1 do
    for s = 0, PER_BOX - 1 do if F.r32(boxSlot(b, s)) ~= 0 then n = n + 1 end end
  end
  return n
end

local function pickSlot(slot, tag)
  for _ = 1, 12 do
    local s = F.rs8(S.gPartyMenu + PARTY_MENU_SLOT)
    if s == slot then break end
    F.press(s < slot and "Down" or "Up", 2); F.idle(16)
  end
  F.check(tag .. ": the party cursor is on slot " .. slot, F.rs8(S.gPartyMenu + PARTY_MENU_SLOT) == slot)
  F.press("A", 2); F.idle(40)
  F.shot(tag:gsub("%W", "_") .. "_picked")
  F.press("A", 2); F.idle(60)
  F.shot(tag:gsub("%W", "_") .. "_confirmed")
end

F.run(function()
  if not F.boot(100) then F.check("boot to the hub", false); F.finish(); return end
  instantText()
  F.check("setup: the debug Give made six Bulbasaur", giveParty(6, BULBASAUR, 10), "count=" .. F.r8(S.gPartiesCount))
  for i = 0, 15 do for b = 0, MAIL_SIZE - 1 do F.w8(mail(i) + b, 0) end end
  local text = letter(0x1234, ITEM_ORANGE_MAIL)
  putBytes(mail(0), text)
  for i = 0, PARTY_SIZE - 1 do F.w8(party(i) + MON_MAIL, MAIL_NONE) end
  setHeldItem(party(MAIL_SLOT), ITEM_ORANGE_MAIL)
  F.w8(party(MAIL_SLOT) + MON_MAIL, 0)
  local mailPid, controlPid = F.r32(party(MAIL_SLOT)), F.r32(party(CONTROL_SLOT))
  local boxedBefore = boxedCount()

  local b = { 0x44 }; le16(b, ITEM_MASTER_BALL); le16(b, 1); b[#b + 1] = 0x02   -- additem, end
  runScript(b); F.idle(30)
  F.check("setup: one Master Ball in the Bag", F.itemCount(ITEM_MASTER_BALL) == 1)

  local w = { 0xB6 }                                                            -- setwildbattle
  le16(w, SPECIES_PIDGEY); w[#w + 1] = 3; le16(w, 0); le16(w, 0); w[#w + 1] = 0; le16(w, 0)
  w[#w + 1] = 0xB7; w[#w + 1] = 0x02                                            -- dowildbattle, end
  runScript(w)
  local started = false
  for _ = 1, 1500 do
    F.idle(1)
    if inBattle() and F.battlers() >= 2 then started = true; break end
  end
  F.check("a wild Pidgey battle started", started)

  local threw, partyMenus = false, 0
  for _ = 1, 4000 do
    if inPartyMenu() then
      partyMenus = partyMenus + 1
      F.idle(40)
      if partyMenus == 1 then
        pickSlot(MAIL_SLOT, "Mail holder")
        F.check("Mail holder: refused, the party menu is still choosing",
          inPartyMenu() and partySlotOf(mailPid) == MAIL_SLOT, string.format("cb2=%08X", F.cb2()))
        if inPartyMenu() then pickSlot(CONTROL_SLOT, "control") end
      else
        F.press("B", 2); F.idle(20)
      end
    elseif inBattle() then
      if actionMenu() and not threw then
        F.idle(10); F.press("R", 2); F.idle(30); threw = true
      else
        F.press("A", 2); F.idle(10)   -- text, the nickname prompt (Yes) and "add to party?" (Yes)
      end
    elseif F.ow() and threw then
      break
    else
      F.press("Start", 2); F.idle(20); F.press("A", 2); F.idle(40)   -- naming screen: START jumps to OK
    end
  end
  F.idle(60)
  F.shot("field")

  F.check("back on the field after the catch", F.ow() and F.outcome() == 7, "outcome=" .. F.outcome())
  local slot = partySlotOf(mailPid)
  F.check("the Mail holder is still in the party, not in the PC", slot ~= nil and boxSlotOf(mailPid) == nil,
    string.format("party=%s box=%s", tostring(slot), tostring(boxSlotOf(mailPid))))
  if slot then
    F.check("it still holds the Orange Mail, linked to its unchanged letter",
      heldItem(party(slot)) == ITEM_ORANGE_MAIL and F.r8(party(slot) + MON_MAIL) == 0
        and bytes(mail(0), MAIL_SIZE) == text,
      "held=" .. heldItem(party(slot)) .. " mail=" .. F.r8(party(slot) + MON_MAIL))
  end
  local pidgey = false
  for i = 0, PARTY_SIZE - 1 do if species(party(i)) == SPECIES_PIDGEY then pidgey = true end end
  F.check("the control Bulbasaur went to the PC and Pidgey joined the party",
    boxSlotOf(controlPid) ~= nil and partySlotOf(controlPid) == nil and pidgey and F.r8(S.gPartiesCount) == 6,
    string.format("box=%s pidgey=%s count=%d", tostring(boxSlotOf(controlPid)), tostring(pidgey), F.r8(S.gPartiesCount)))
  F.check("exactly one Pokemon was boxed", boxedCount() == boxedBefore + 1, "boxed=" .. boxedCount())
  F.check("no crash", not F.reportCrash("end"))
  F.finish()
end)
