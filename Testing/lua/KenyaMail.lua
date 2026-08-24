-- Issue #66: Randy's Kenya gift carries RetroMail, the Route 31
-- sleeper actually removes her, and TM41 bag-full is checked before the take.
--
-- Run via Testing/mgba-run.sh Testing/lua/KenyaMail.lua

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "KenyaMail")

-- MAP_GATE_GOLDENROD_CITY_ROUTE35 = (6 | (83 << 8)); MAP_ROUTE31 = (4 | (75 << 8)).
local GATE_G, GATE_M, GATE_W = 83, 6, 0
local R31_G,  R31_M,  R31_W  = 75, 4, 1   -- warp 1 = Violet gate at (4,10), near the sleeper

local REGION_VARS_START = 0xA000
local VAR_KENYA = 0xA080 + 0x09            -- VAR_JOHTO_SLICE(0x09)
local ITEM_RETRO_MAIL, ITEM_TM41 = 210, 622
local MAIL_NONE, MAIL_COUNT, MAIL_STRIDE = 0xFF, 16, 36
local MAIL_NAME, MAIL_TID, MAIL_SPECIES, MAIL_ITEM = 0x12, 0x1A, 0x1E, 0x20
local PKMN_SIZE = S.Pokemon.size
local OFF_LEVEL, OFF_HP, OFF_MAXHP = S.Pokemon.level, S.Pokemon.hp, S.Pokemon.maxHP
local OFF_MAIL = 85
local ROW_PARTY_MENU, ROW_SET = 2, 9
local HUB_GROUP = 100

local function d(n) return (n // 100) % 10, (n // 10) % 10, n % 10 end

local function kenyaVarAddr()
  return F.sb3() + S.SaveBlock3.regionVars + (VAR_KENYA - REGION_VARS_START) * 2
end
local function kenyaVar() return F.r16(kenyaVarAddr()) end

local function go(grp, map, warp, tag)
  local gh, gt, go_ = d(grp)
  local mh, mt, mo = d(map)
  local wh, wt, wo = d(warp)
  if not F.warpTo(gh, gt, go_, mh, mt, mo, wh, wt, wo, grp, map, tag) then
    F.check(tag .. "_warped", false, string.format("grp=%d map=%d", F.grp(), F.mapn()))
    return false
  end
  F.idle(60)
  return true
end

local function partyCount() return F.r8(S.gPartiesCount) end
local function slot(i) return S.gParties + i * PKMN_SIZE end

local function hexbytes(addr, n)
  local t = {}
  for i = 0, n - 1 do t[#t + 1] = string.format("%02X", F.r8(addr + i)) end
  return table.concat(t, " ")
end

-- SaveBlock1.mail is not a linker symbol. 0x2BE0 is the scan starting guess;
-- locateMailArray() re-pins from Kenya's ITEM_RETRO_MAIL after the gift.
local mailArrayOff = 0x2BE0

local function mailAddr(id) return F.sb1() + mailArrayOff + id * MAIL_STRIDE end

local function locateMailArray(mailId)
  local sb = F.sb1()
  local hits = {}
  for off = 0, 20000, 2 do
    if F.r16(sb + off) == ITEM_RETRO_MAIL then hits[#hits + 1] = off end
  end
  F.L("  RETRO_MAIL u16 hits at sb1+" .. table.concat((function()
    local t = {}
    for i, o in ipairs(hits) do t[i] = string.format("0x%X", o) end
    return t
  end)(), ", "))
  -- Prefer a hit that is mail[mailId].itemId, i.e. array + mailId*36 + 0x20.
  for _, off in ipairs(hits) do
    local base = off - MAIL_ITEM - mailId * MAIL_STRIDE
    if base >= 0 and base < 20000 then
      mailArrayOff = base
      F.L(string.format("  mail[] pinned at sb1+0x%X (from mailId=%d itemId @ +0x%X)", base, mailId, off))
      return true
    end
  end
  if #hits > 0 then
    mailArrayOff = hits[1] - MAIL_ITEM
    F.L(string.format("  mail[] fallback pin sb1+0x%X", mailArrayOff))
    return true
  end
  F.L("  no RETRO_MAIL word in SaveBlock1")
  return false
end

local function dumpMail(id, tag)
  if id >= MAIL_COUNT then
    F.L(string.format("  mail[%s] id=%d OUT OF RANGE", tag, id)); return
  end
  local m = mailAddr(id)
  F.L(string.format("  mail[%s] id=%d item=%d species=%d tid=%s name=%s words=%s",
    tag, id, F.r16(m + MAIL_ITEM), F.r16(m + MAIL_SPECIES),
    hexbytes(m + MAIL_TID, 4), hexbytes(m + MAIL_NAME, 8), hexbytes(m, 18)))
end

local function dumpParty(tag)
  local n = partyCount()
  F.L(string.format("  party[%s] count=%d VAR_KENYA=%d", tag, n, kenyaVar()))
  for i = 0, 5 do
    local b = slot(i)
    local lv, mail, hp, mx = F.r8(b + OFF_LEVEL), F.r8(b + OFF_MAIL), F.r16(b + OFF_HP), F.r16(b + OFF_MAXHP)
    if lv ~= 0 or hp ~= 0 or mail ~= MAIL_NONE then
      F.L(string.format("    slot%d lv=%d mail=%d hp=%d/%d", i, lv, mail, hp, mx))
      if mail ~= MAIL_NONE then dumpMail(mail, "slot" .. i) end
    end
  end
end

-- Kenya is the lv20 named gift; debug Set Party's Wobbuffet is lv100. Mail id is unencrypted.
local function findKenya()
  for i = 0, 5 do
    local b = slot(i)
    local lv, mail = F.r8(b + OFF_LEVEL), F.r8(b + OFF_MAIL)
    if lv == 20 and mail ~= MAIL_NONE and mail < MAIL_COUNT then return i, mail end
  end
  return -1, MAIL_NONE
end

local function fleeIfBattle()
  if F.ow() then return true end
  F.L("  battle started, running")
  F.shot("battle")
  for _ = 1, 400 do
    F.press("B", 2); F.idle(6)
    F.press("Right", 2); F.idle(4)
    F.press("Down", 2); F.idle(4)
    F.press("A", 2); F.idle(10)
    if F.ow() then F.idle(40); return true end
    if F.reportCrash("battle") then return false end
  end
  return F.ow()
end

local function walkTo(tx, ty, tag)
  for _ = 1, 100 do
    if F.reportCrash("walk_" .. tag) then return false end
    if not fleeIfBattle() then return false end
    local x, y = F.pos()
    if x == tx and y == ty then return true end
    local dir
    if x < tx then dir = "Right" elseif x > tx then dir = "Left"
    elseif y < ty then dir = "Down" else dir = "Up" end
    if not F.step(dir) then
      F.L(string.format("  walk %s blocked at (%d,%d)->(%d,%d)", tag, x, y, tx, ty))
      F.shot(tag .. "_stuck")
      return false
    end
  end
  return false
end

local function tapDown(n)
  for _ = 1, n do F.press("Down", 3); F.idle(16) end
end

local function setParty()
  F.dbg(); F.idle(60)
  tapDown(ROW_PARTY_MENU); F.press("A", 3); F.idle(60)
  tapDown(ROW_SET); F.shot("setparty_cursor")
  F.press("A", 3); F.idle(180)
  for _ = 1, 8 do F.press("B", 2); F.idle(20) end
  F.idle(40)
end

-- Fill TMHM pocket so CheckBagHasSpace(ITEM_TM41) is false. Quantity is XOR-keyed.
local function fillTmPocket(full)
  local ptr = F.r32(S.gBagPockets + 2 * S.BagPocket.stride)
  local cap = F.pocketCap(2)
  local key = F.r32(F.sb2() + S.SaveBlock2.encryptionKey)
  local qty = full and ((1 ~ key) & 0xFFFF) or 0
  if ptr < 0x02000000 or ptr >= 0x02040000 or cap < 1 or cap > 80 then
    F.L(string.format("  TM pocket unusable ptr=0x%08X cap=%d", ptr, cap))
    return false
  end
  local id = 582  -- ITEM_TM01; skip ITEM_TM41 so it cannot stack into an existing slot
  for s = 0, cap - 1 do
    if full then
      if id == ITEM_TM41 then id = id + 1 end
      F.w16(ptr + s * 4, id)
      F.w16(ptr + s * 4 + 2, qty)
      id = id + 1
    else
      F.w16(ptr + s * 4, 0)
      F.w16(ptr + s * 4 + 2, 0)
    end
  end
  return true
end

-- Mash A through msgboxes / yes-no (default YES). Stop when pred() or budget runs out.
local function mashUntil(pred, tries, tag)
  for i = 1, (tries or 80) do
    if F.reportCrash(tag) then return false end
    if not fleeIfBattle() then return false end
    if pred() then return true end
    F.press("A", 2); F.idle(22)
  end
  return pred()
end

local function dismissTalk()
  for _ = 1, 25 do F.press("B", 2); F.idle(24) end
  F.ensureFree()
end

F.run(function()
  if not F.boot(HUB_GROUP) then F.check("boot", false); F.finish(); return end
  F.check("fresh VAR_KENYA is 0", kenyaVar() == 0, "VAR_KENYA=" .. kenyaVar())
  F.check("fresh party is empty", partyCount() == 0, "count=" .. partyCount())

  -- Extra live mon so removenamedmon does not take the LAST_MON refusal.
  setParty()
  dumpParty("after_setparty")
  F.check("Set Party gave a second body (Wobbuffet)", partyCount() >= 1, "count=" .. partyCount())

  if not go(GATE_G, GATE_M, GATE_W, "gate") then F.finish(); return end
  F.check("on Goldenrod/Route 35 gate", F.grp() == GATE_G and F.mapn() == GATE_M,
    string.format("grp=%d map=%d", F.grp(), F.mapn()))
  local gx, gy = F.pos()
  F.L(string.format("  gate spawn (%d,%d)", gx, gy))
  F.shot("gate_arrival")

  -- Man_2 at (8,7) shares Randy's script with the policeman at (3,5). Talk from (8,8).
  local talked = walkTo(8, 8, "randy")
  F.check("reached Randy's talk tile (8,8)", talked, string.format("pos=(%d,%d)", F.pos()))
  if talked then F.face("Up") end
  F.shot("before_randy")

  local nBefore = partyCount()
  mashUntil(function() return kenyaVar() == 1 or partyCount() > nBefore end, 60, "randy")
  dismissTalk()
  dumpParty("after_randy")
  F.shot("after_randy")

  F.check("VAR_KENYA became 1 after talking to Randy", kenyaVar() == 1, "VAR_KENYA=" .. kenyaVar())
  F.check("party grew by one", partyCount() == nBefore + 1,
    string.format("before=%d after=%d", nBefore, partyCount()))

  local kSlot, kMail = findKenya()
  F.check("a lv20 mail-holding party slot exists (Kenya)", kSlot >= 0,
    string.format("slot=%d mail=%d", kSlot, kMail))
  if kSlot >= 0 then
    local found = locateMailArray(kMail)
    F.check("SaveBlock1 contains an ITEM_RETRO_MAIL record for Kenya's mailId", found,
      "mailId=" .. kMail)
    if found then
      dumpMail(kMail, "kenya")
      local m = mailAddr(kMail)
      local item = F.r16(m + MAIL_ITEM)
      F.check("Kenya's mail record is ITEM_RETRO_MAIL (210)", item == ITEM_RETRO_MAIL,
        "itemId=" .. item .. " array=0x" .. string.format("%X", mailArrayOff))
      F.L(string.format("  Kenya slot=%d mailId=%d item=%d tid=%s name=%s",
        kSlot, kMail, item, hexbytes(m + MAIL_TID, 4), hexbytes(m + MAIL_NAME, 8)))
    end
  end

  if not go(R31_G, R31_M, R31_W, "route31") then F.finish(); return end
  F.check("on Route 31", F.grp() == R31_G and F.mapn() == R31_M,
    string.format("grp=%d map=%d", F.grp(), F.mapn()))
  local rx, ry = F.pos()
  F.L(string.format("  route31 spawn (%d,%d)", rx, ry))
  F.shot("route31_arrival")

  -- Sleeper is local id 3 at (18,11) FACE_DOWN. (18,12) is through him (axis-first
  -- walk hits (18,10) then the NPC). Talk from the tile north of him.
  local atSleeper = walkTo(18, 10, "sleeper")
  F.check("reached the sleeper's north talk tile (18,10)", atSleeper,
    string.format("pos=(%d,%d)", F.pos()))
  if not atSleeper then F.finish(); return end
  F.face("Down")

  -- ---- bag-full first -------------------------------------------------------
  local filled = fillTmPocket(true)
  F.check("TM pocket write landed (64 occupied slots, no TM41)", filled and F.itemCount(ITEM_TM41) == 0,
    string.format("filled=%s tm41count=%d cap=%d", tostring(filled), F.itemCount(ITEM_TM41), F.pocketCap(2)))
  F.shot("before_sleeper_bagfull")

  local nBag = partyCount()
  local kBag = kenyaVar()
  -- Ask-for-mail yesno + "BAG is full" + release. Extra A after release would re-open him, so B-dismiss.
  for _ = 1, 18 do
    if F.reportCrash("sleeper_bagfull") then break end
    F.press("A", 2); F.idle(22)
  end
  dismissTalk()
  dumpParty("after_bagfull")
  F.shot("after_sleeper_bagfull")
  F.check("bag-full does not take Kenya", findKenya() >= 0, "kenya slot=" .. tostring(findKenya()))
  F.check("bag-full leaves VAR_KENYA at 1", kenyaVar() == 1, "VAR_KENYA=" .. kenyaVar())
  F.check("bag-full leaves party count unchanged", partyCount() == nBag,
    string.format("before=%d after=%d (kenyaVar was %d now %d)", nBag, partyCount(), kBag, kenyaVar()))

  fillTmPocket(false)
  F.check("TM pocket emptied again", F.itemCount(ITEM_TM41) == 0, "tm41=" .. F.itemCount(ITEM_TM41))

  -- ---- real hand-over -------------------------------------------------------
  -- dismissTalk's ensureFree() steps Left/Right, so re-park on the talk tile.
  if not walkTo(18, 10, "sleeper2") then
    F.check("re-reached the sleeper after emptying the TM pocket", false, string.format("pos=(%d,%d)", F.pos()))
    F.finish(); return
  end
  F.face("Down")
  F.shot("before_sleeper_give")
  mashUntil(function() return kenyaVar() == 2 end, 160, "sleeper_give")
  dismissTalk()
  dumpParty("after_give")
  F.shot("after_sleeper_give")

  F.check("VAR_KENYA became 2 after the hand-over", kenyaVar() == 2, "VAR_KENYA=" .. kenyaVar())
  F.check("Kenya is gone from the party", findKenya() < 0,
    string.format("slot=%d count=%d", findKenya(), partyCount()))
  F.check("party shrank by one", partyCount() == nBag - 1,
    string.format("before=%d after=%d", nBag, partyCount()))
  F.check("TM41 (Torment) is now in the bag", F.itemCount(ITEM_TM41) >= 1,
    "tm41count=" .. F.itemCount(ITEM_TM41))

  F.finish()
end)
