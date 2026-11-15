-- The Bag's in-place party select serves both Use and Give (SWSH_ITEM_MENU_ACTION_IN_BAG). Use
-- leaves its item callback in gItemUseCB, which nothing resets, and Give keeps its mode in the
-- static sPartyGiveMode. Two leaks were fixed in 0829014ec0: a Sacred Ash used earlier turned a
-- later Give into a party-wide revive, and a Mail give left give mode on, so the next bag's Use
-- gave the item away instead of using it.
--
-- This suite drives every party-callback item the in-bag select knows with real input, cancels
-- out of it (B at the party select, and B again one level deeper for the PP items), then Gives a
-- Revive to the lead. Each Give must hand over exactly one Revive and touch nothing else. It then
-- Gives Orange Mail to a holder (refused) and to a non-holder (the letter is written), reopens the
-- Bag, and Uses a Potion on the hurt lead: it must heal, not be given.
--
-- Run via test/overworld/mgba-run.sh test/overworld/lua/BagCallbackGiveStress.lua <rom>

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "BagCallbackGiveStress")

local HUB_GROUP = 100
local MON = S.Pokemon.size
local USM_ICO_BAG = 2
local POCKET_ITEMS, POCKET_TMS = 0, 2
local BULBASAUR, CHARMANDER, SQUIRTLE = 1, 4, 7
local ITEM = {
  POTION = 28, REVIVE = 33, MAX_REVIVE = 34, ETHER = 49, SACRED_ASH = 54, PP_UP = 71,
  RARE_CANDY = 102, FIRE_STONE = 211, ORANGE_MAIL = 199, ORAN_BERRY = 520, TM01 = 582,
}
local OFF_HP, OFF_MAXHP, OFF_LEVEL = 0x56, 0x58, 0x54

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
local function writeWords(a, w)
  local key = F.r32(a) ~ F.r32(a + 4)
  local sum = 0
  for i = 0, 11 do
    sum = (sum + (w[i] & 0xFFFF) + (w[i] >> 16)) & 0xFFFF
    F.w32(a + 32 + i * 4, w[i] ~ key)
  end
  F.w16(a + 28, sum)
end
local function heldItem(a) local w, o = words(a); return (w[o[0]] >> 16) & 0x3FF end
local function speciesOf(a) local w, o = words(a); return w[o[0]] & 0x7FF end
local function setHeldItem(a, item)
  local w, o = words(a)
  w[o[0]] = (w[o[0]] & ~(0x3FF << 16)) | (item << 16)
  writeWords(a, w)
end
local function hp(slot) return F.r16(party(slot) + OFF_HP) end
local function maxHp(slot) return F.r16(party(slot) + OFF_MAXHP) end

local function pocketPtr(p) return F.r32(S.gBagPockets + p * S.BagPocket.stride) end
local function qtyKey() return F.r32(F.sb2() + S.SaveBlock2.encryptionKey) & 0xFFFF end
local function countIn(p, id)
  local n, ptr, cap = 0, pocketPtr(p), F.pocketCap(p)
  for s = 0, cap - 1 do
    if F.r16(ptr + s * 4) == id then n = n + (F.r16(ptr + s * 4 + 2) ~ qtyKey()) end
  end
  return n
end
local function setPocket(p, list)
  local ptr, cap = pocketPtr(p), F.pocketCap(p)
  for s = 0, cap - 1 do F.w16(ptr + s * 4, 0); F.w16(ptr + s * 4 + 2, qtyKey()) end
  for i, e in ipairs(list) do F.w16(ptr + (i - 1) * 4, e[1]); F.w16(ptr + (i - 1) * 4 + 2, e[2] ~ qtyKey()) end
end

local function inBag() return F.cb2() == (S.CB2_BagMenuRun & ~1) end
local function instantText()
  local a = F.sb2() + S.SaveBlock2.optionsU16
  F.w16(a, (F.r16(a) & ~7) | 3)
end

local function digits(n) n = n - 1; return n // 100, (n // 10) % 10, n % 10 end
local function giveTeam()
  for _ = 1, 3 do
    for off = 0, 6 * MON - 4, 4 do F.w32(S.gParties + off, 0) end
    F.w8(S.gPartiesCount, 0)
    F.dbg(); F.idle(30); F.bOut(4)
    for _, sp in ipairs({ BULBASAUR, CHARMANDER, SQUIRTLE }) do
      F.dbg(); F.sel(3); F.sel(1); F.idle(20)
      F.spin(digits(sp)); F.idle(20)
      F.spin(digits(20)); F.idle(60); F.bOut(4)
    end
    if F.r8(S.gPartiesCount) == 3 and speciesOf(party(2)) == SQUIRTLE then return true end
    F.idle(60)
  end
  return false
end

local function openBag(pocket)
  F.w8(S.gBagPosition + 5, pocket)
  for p = 0, 4 do
    F.w16(S.gBagPosition + 8 + p * 2, 0)
    F.w16(S.gBagPosition + 18 + p * 2, 0)
  end
  F.press("Start", 2); F.idle(60)
  if not F.selectStartIcon(USM_ICO_BAG) then return false end
  F.press("A", 2)
  for _ = 1, 150 do
    if inBag() then F.idle(40); return true end
    F.idle(2)
  end
  return false
end

local function backToField()
  for _ = 1, 40 do
    if F.ow() then break end
    F.press("B", 2); F.idle(20)
  end
  F.idle(30)
  return F.ow()
end

local function pulseA(n, gap) for _ = 1, n do F.press("A", 2); F.idle(gap or 40) end end
local function crashed(tag) return F.reportCrash(tag) end

-- Each plan: the pocket, the item, and the presses after Use that back out to the item list.
local plans = {
  { name = "Potion", pocket = POCKET_ITEMS, item = ITEM.POTION, cancel = { "B" } },
  { name = "Revive", pocket = POCKET_ITEMS, item = ITEM.REVIVE, cancel = { "B" } },
  { name = "Max Revive", pocket = POCKET_ITEMS, item = ITEM.MAX_REVIVE, cancel = { "B" } },
  { name = "Rare Candy", pocket = POCKET_ITEMS, item = ITEM.RARE_CANDY, cancel = { "B" } },
  { name = "Fire Stone", pocket = POCKET_ITEMS, item = ITEM.FIRE_STONE, cancel = { "B" } },
  { name = "Ether", pocket = POCKET_ITEMS, item = ITEM.ETHER, cancel = { "A", "B", "B" } },
  { name = "PP Up", pocket = POCKET_ITEMS, item = ITEM.PP_UP, cancel = { "A", "B", "B" } },
  { name = "Sacred Ash", pocket = POCKET_ITEMS, item = ITEM.SACRED_ASH, cancel = { "A" } },
  -- Sacred Ash with nobody fainted has no effect and stays in the Bag, but its callback stays in
  -- gItemUseCB. The Charmander faints before the Give, so a hijacked Give would revive it.
  { name = "Sacred Ash no effect", pocket = POCKET_ITEMS, item = ITEM.SACRED_ASH, cancel = { "A" },
    allAlive = true, keepsItem = true },
  { name = "TM01", pocket = POCKET_TMS, item = ITEM.TM01, cancel = { "A", "A", "A", "B" } },
}

local function resetState()
  for s = 0, 2 do setHeldItem(party(s), 0) end
  F.w16(party(0) + OFF_HP, maxHp(0))
  F.w16(party(1) + OFF_HP, 0)
  F.w16(party(2) + OFF_HP, maxHp(2))
end

local function runPlan(pl)
  local tag = pl.name
  F.L("== " .. tag .. " then Give Revive ==")
  resetState()
  -- The Revive plan uses and gives from one stack of four; the others keep one of their own item.
  local items = { { ITEM.REVIVE, pl.item == ITEM.REVIVE and 4 or 3 } }
  if pl.pocket == POCKET_ITEMS and pl.item ~= ITEM.REVIVE then table.insert(items, 1, { pl.item, 1 }) end
  local revivesBefore = items[#items][2]
  setPocket(POCKET_ITEMS, items)
  setPocket(POCKET_TMS, pl.pocket == POCKET_TMS and { { pl.item, 1 } } or {})
  if pl.allAlive then F.w16(party(1) + OFF_HP, maxHp(1)) end
  local lvBefore = F.r8(party(0) + OFF_LEVEL)

  if not openBag(pl.pocket) then F.check(tag .. ": the bag opened", false); return end
  F.press("A", 2); F.idle(40)          -- action menu, Use is selected
  F.press("A", 2); F.idle(60)          -- Use
  F.shot(tag:gsub("%W", "_") .. "_use")
  for i, b in ipairs(pl.cancel) do F.press(b, 2); F.idle(50); F.shot(tag:gsub("%W", "_") .. "_cancel" .. i) end
  if not inBag() then F.check(tag .. ": still in the bag after cancelling", false, string.format("cb2=%08X", F.cb2())); backToField(); return end
  if pl.allAlive then F.w16(party(1) + OFF_HP, 0) end
  local hpBefore = { hp(0), hp(1), hp(2) }

  if pl.pocket == POCKET_TMS then
    F.press("Left", 2); F.idle(30); F.press("Left", 2); F.idle(40)
  end
  -- Revive is the first Items row when the plan item lives in another pocket, else the second.
  if pl.pocket == POCKET_ITEMS and pl.item ~= ITEM.REVIVE and countIn(POCKET_ITEMS, pl.item) > 0 then
    F.press("Down", 2); F.idle(30)
  end
  F.shot(tag:gsub("%W", "_") .. "_on_revive")
  F.press("A", 2); F.idle(40)
  F.press("Right", 2); F.idle(20)
  F.press("A", 2); F.idle(60)          -- Give: party select on slot 0
  F.shot(tag:gsub("%W", "_") .. "_give_select")
  F.press("A", 2); F.idle(60)          -- give to the lead
  F.shot(tag:gsub("%W", "_") .. "_given")
  pulseA(1, 40)
  local crash = crashed(tag)
  F.check(tag .. ": no crash screen", not crash)
  F.L(string.format("  after: held=%d revives=%d hp=%d/%d/%d (was %d/%d/%d) lv=%d",
    heldItem(party(0)), countIn(POCKET_ITEMS, ITEM.REVIVE), hp(0), hp(1), hp(2),
    hpBefore[1], hpBefore[2], hpBefore[3], F.r8(party(0) + OFF_LEVEL)))
  F.check(tag .. ": the lead holds the Revive", heldItem(party(0)) == ITEM.REVIVE, "held=" .. heldItem(party(0)))
  F.check(tag .. ": exactly one Revive left the Bag", countIn(POCKET_ITEMS, ITEM.REVIVE) == revivesBefore - 1,
    "revives=" .. countIn(POCKET_ITEMS, ITEM.REVIVE))
  F.check(tag .. ": the Give changed no Pokemon's HP", hp(0) == hpBefore[1] and hp(1) == hpBefore[2]
    and hp(2) == hpBefore[3], string.format("hp=%d/%d/%d", hp(0), hp(1), hp(2)))
  F.check(tag .. ": the lead's level is unchanged", F.r8(party(0) + OFF_LEVEL) == lvBefore)
  if (pl.item ~= ITEM.SACRED_ASH or pl.keepsItem) and pl.item ~= ITEM.REVIVE then
    F.check(tag .. ": the cancelled item is still in the Bag", countIn(pl.pocket, pl.item) == 1,
      "count=" .. countIn(pl.pocket, pl.item))
  end
  if not backToField() then F.check(tag .. ": back on the field", false, string.format("cb2=%08X", F.cb2())) end
end

local function inEasyChat() return not inBag() and not F.ow() end

F.run(function()
  if not F.boot(HUB_GROUP) then F.check("boot to the hub", false); F.finish(); return end
  instantText()
  if not giveTeam() then F.check("setup: the debug Give made three Pokemon", false); F.finish(); return end
  instantText()

  local only = os.getenv("PW_ONLY")
  for _, pl in ipairs(plans) do if not only or pl.name == only then runPlan(pl) end end

  -- Mail: a holder refuses it, a non-holder takes it and the letter is written.
  F.L("== Mail give, then Use a Potion ==")
  resetState()
  setHeldItem(party(0), ITEM.ORAN_BERRY)
  F.w16(party(1) + OFF_HP, maxHp(1))
  setPocket(POCKET_ITEMS, { { ITEM.ORANGE_MAIL, 2 }, { ITEM.POTION, 3 } })
  setPocket(POCKET_TMS, {})
  if openBag(POCKET_ITEMS) then
    F.press("A", 2); F.idle(40); F.press("Right", 2); F.idle(20); F.press("A", 2); F.idle(60)
    F.press("A", 2); F.idle(60)        -- onto the Oran Berry holder: refused
    F.shot("mail_to_holder")
    pulseA(1, 40)
    F.check("Mail onto a holder: refused, the Oran Berry stays", heldItem(party(0)) == ITEM.ORAN_BERRY
      and countIn(POCKET_ITEMS, ITEM.ORANGE_MAIL) == 2, "held=" .. heldItem(party(0)))
    F.press("Down", 2); F.idle(30)     -- party slot 1, holds nothing
    F.press("A", 2)
    local chat = false
    for _ = 1, 200 do F.idle(3); if inEasyChat() then chat = true; break end end
    F.idle(120)
    F.shot("mail_easy_chat")
    F.check("Mail onto a non-holder opens the letter", chat, string.format("cb2=%08X", F.cb2()))
    -- Quit without writing: B, then Yes to quitting; a cancelled letter returns the Mail.
    -- B asks "Stop giving the POKeMON MAIL?" with the cursor on No: Up to Yes, then A.
    F.press("B", 2); F.idle(40)
    F.press("Up", 2); F.idle(20)
    F.shot("chat_stop_yes")
    F.press("A", 2); F.idle(40)
    for _ = 1, 60 do if inBag() then break end; F.idle(5) end
    F.idle(60)
    F.shot("back_from_letter")
    F.check("back in the Bag after the letter", inBag(), string.format("cb2=%08X", F.cb2()))
    F.L(string.format("  after the letter: held1=%d mail=%d", heldItem(party(1)), countIn(POCKET_ITEMS, ITEM.ORANGE_MAIL)))

    -- Now Use a Potion on the hurt lead.
    F.w16(party(0) + OFF_HP, 1)
    setHeldItem(party(0), 0)
    local potions = countIn(POCKET_ITEMS, ITEM.POTION)
    for _ = 1, 4 do F.press("Down", 2); F.idle(20) end
    for _ = 1, 4 do F.press("Up", 2); F.idle(20) end
    if countIn(POCKET_ITEMS, ITEM.ORANGE_MAIL) > 0 then F.press("Down", 2); F.idle(30) end
    F.shot("on_potion")
    F.press("A", 2); F.idle(40)
    F.press("A", 2); F.idle(60)        -- Use
    F.shot("potion_select")
    F.press("A", 2); F.idle(90)        -- onto the lead
    pulseA(2, 50)
    F.shot("potion_used")
    F.L(string.format("  after the Potion: hp=%d held=%d potions=%d (was %d)", hp(0), heldItem(party(0)),
      countIn(POCKET_ITEMS, ITEM.POTION), potions))
    F.check("Use Potion after a Mail give heals the lead", hp(0) > 1, "hp=" .. hp(0))
    F.check("Use Potion after a Mail give does not give it", heldItem(party(0)) ~= ITEM.POTION,
      "held=" .. heldItem(party(0)))
  else
    F.check("the bag opened for the Mail give", false)
  end
  backToField()
  F.check("no crash screen at the end", not F.crashScreen())
  F.finish()
end)
