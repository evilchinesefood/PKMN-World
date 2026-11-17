-- The Johto and Kanto move relearners must charge for a lesson exactly when a move is learned.
--
-- Blackthorn's relearner (Heart Scale) and the Two Island Move Maniac (two Tiny Mushrooms) came from
-- older decomps that read the relearner's result from VAR_0x8004, which used to be zeroed on a give-up.
-- This build's relearner reports the result in VAR_RESULT and leaves VAR_0x8004 as the chosen party
-- slot, so giving up on the second Pokemon took the payment and a lesson for the first Pokemon was
-- free. They also read VAR_0x8005 as "number of relearnable moves", which nothing sets any more.
--
-- With real input in each house the suite gives up from the move list for the second Charizard, asks
-- for a Magikarp that has nothing to relearn, then teaches the first Charizard a move. Oracle: giving
-- up and the Magikarp cost nothing and the Magikarp gets the "no move" line instead of the list; the
-- lesson costs one payment, the move is learned and the script does not reopen the chooser.
local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "RelearnerPaymentRegions")

local HUB = 100
local REGION_KANTO, REGION_JOHTO = 1, 2
local ITEM_TINY_MUSHROOM, ITEM_HEART_SCALE = 137, 152
local SPECIES_CHARIZARD, SPECIES_MAGIKARP = 6, 129
local CONTEXT_RUNNING, CONTEXT_SHUTDOWN = 0, 2
local SCRIPT_BUF = S.gStringVar4 + 960

local HOUSES = {
  { name = "blackthorn", region = REGION_JOHTO, group = 94, map = 3, x = 7, y = 5,
    item = ITEM_HEART_SCALE, give = 3, cost = 1 },
  { name = "two_island", region = REGION_KANTO, group = 65, map = 1, x = 7, y = 6,
    item = ITEM_TINY_MUSHROOM, give = 4, cost = 2 },
}

local function d(n) return (n // 100) % 10, (n // 10) % 10, n % 10 end
local function hasControl()
  return F.ow() and F.r8(S.sLockFieldControls) == 0 and F.r8(S.sGlobalScriptContextStatus) == CONTEXT_SHUTDOWN
end
local function runScript(b)
  for i, v in ipairs(b) do F.w8(SCRIPT_BUF + i - 1, v) end
  F.w8(S.sGlobalScriptContext, 0)
  F.w8(S.sGlobalScriptContext + 1, 1)
  F.w32(S.sGlobalScriptContext + 4, 0)
  F.w32(S.sGlobalScriptContext + S.ScriptCtx.scriptPtr, SCRIPT_BUF)
  F.w8(S.sGlobalScriptContextStatus, CONTEXT_RUNNING)
  for _ = 1, 200 do F.idle(4); if hasControl() then break end end
  F.idle(30)
end
local function le16(t, v) t[#t + 1] = v & 0xFF; t[#t + 1] = (v >> 8) & 0xFF end
local function le32(t, v) le16(t, v & 0xFFFF); le16(t, (v >> 16) & 0xFFFF) end
local function addItem(id, n) runScript({ 0x44, id & 0xFF, id >> 8, n, 0, 0x02 }) end
local function createMon(species, level, moves)
  local b = { 0x23 }; le32(b, S.ScrCmd_createmon | 1)
  b[#b + 1] = 0; b[#b + 1] = 6
  le16(b, species); le16(b, level)
  le32(b, (1 << 17) | (1 << 18) | (1 << 19) | (1 << 20))
  for k = 1, 4 do le16(b, moves[k] or 0) end
  b[#b + 1] = 0x02
  runScript(b)
end
local function warpToCoords(grp, map, x, y, tag)
  for _ = 1, 4 do
    F.dbg(); F.sel(0); F.sel(1); F.idle(20)
    F.spin(d(grp)); F.spin(d(map))
    F.press("A", 2)
    for _ = 1, 400 do
      F.w8(S.sWarpDestination + 2, 0xFF)
      F.w16(S.sWarpDestination + 4, x)
      F.w16(S.sWarpDestination + 6, y)
      F.idle(1)
      local px, py = F.pos()
      if F.ow() and F.grp() == grp and F.mapn() == map and px == x and py == y then F.idle(120); return true end
    end
    F.bOut(5)
  end
  F.shot(tag .. "_warpfail")
  return false
end
-- gStringVar4 as uppercase ASCII; Gen 3 A = 0xBB, a = 0xD5.
local function message()
  local s = {}
  for i = 0, 200 do
    local c = F.r8(S.gStringVar4 + i)
    if c == 0xFF then break end
    if c >= 0xBB and c <= 0xD4 then s[#s + 1] = string.char(65 + c - 0xBB)
    elseif c >= 0xD5 and c <= 0xEE then s[#s + 1] = string.char(65 + c - 0xD5)
    elseif c == 0xAC then s[#s + 1] = "?"
    else s[#s + 1] = " " end
  end
  return table.concat(s)
end
-- Bag quantity of an item: ids are plaintext, quantities are XORed with the encryption key.
local function qty(id)
  local key = F.r16(F.sb2() + S.SaveBlock2.encryptionKey)
  local n = 0
  for p = 0, 4 do
    local ptr = F.r32(S.gBagPockets + p * S.BagPocket.stride)
    local cap = F.pocketCap(p)
    if ptr >= 0x02000000 and ptr < 0x02040000 and cap > 0 and cap < 400 then
      for s = 0, cap - 1 do if F.r16(ptr + s * 4) == id then n = n + (F.r16(ptr + s * 4 + 2) ~ key) end end
    end
  end
  return n
end
local function waitFor(pred, frames)
  for _ = 1, frames // 5 do if pred() then return true end; F.idle(5) end
  return pred()
end
local function moveCount(i)
  local a = S.gParties + i * S.Pokemon.size
  local pers, otid = F.r32(a), F.r32(a + 4)
  local key = pers ~ otid
  local s1 = F.r8(S.sSubstructOffsets + 24 + pers % 24) * 3
  local w0, w1 = F.r32(a + 32 + s1 * 4) ~ key, F.r32(a + 32 + (s1 + 1) * 4) ~ key
  local n = 0
  for _, m in ipairs({ w0 & 0x7FF, (w0 >> 16) & 0x7FF, w1 & 0x7FF, (w1 >> 16) & 0x7FF }) do
    if m ~= 0 then n = n + 1 end
  end
  return n
end

-- One talk: pick party slot `slot` in the chooser, then give up ("giveup") or teach the first move
-- ("learn") if the move list opens. Any later chooser is cancelled with B. Returns what was seen.
local function visit(tag, slot, mode)
  local seen = { list = false, reopened = false, said = {} }
  local function note()
    local m = message()
    if seen.said[#seen.said] ~= m then seen.said[#seen.said + 1] = m end
  end
  F.face("Up"); F.press("A", 2)
  local chooser = false
  for _ = 1, 400 do
    note()
    if not F.ow() then chooser = true; break end
    F.press("A", 2); F.idle(14)
  end
  F.idle(90)
  if not chooser then return seen end
  F.shot(tag .. "_chooser")
  for _ = 1, slot do F.press("Down", 2); F.idle(30) end
  F.press("A", 2)
  local backOnField, handled = false, false
  for _ = 1, 1500 do
    note()
    if hasControl() then F.idle(20); if hasControl() then break end end
    if F.ow() then
      backOnField = true
      F.press("A", 2); F.idle(20)
    elseif F.cb2() == S.CB2_MoveRelearnerMain and not handled then
      handled, seen.list = true, true
      F.idle(90); F.shot(tag .. "_list")
      if mode == "giveup" then
        for _ = 1, 10 do
          if F.cb2() ~= S.CB2_MoveRelearnerMain then break end
          if message():find("GIVE UP") then F.idle(60); F.press("A", 2); F.idle(60)
          else F.press("B", 2); F.idle(60) end
        end
      else
        F.press("A", 2)
        waitFor(function() local m = message(); return m:find("TEACH [A-Z ]+%?") ~= nil and not m:find("WHICH") end, 200)
        F.idle(30)
        F.press("A", 2)
        for _ = 1, 200 do if F.ow() then break end; note(); F.press("A", 2); F.idle(10) end
      end
    elseif backOnField and F.cb2() == S.CB2_UpdatePartyMenu then
      seen.reopened = true
      F.idle(60); F.shot(tag .. "_chooser_again")
      F.press("B", 2); F.idle(60)
    else
      F.idle(5)
    end
  end
  F.L("  " .. tag .. ": " .. table.concat(seen.said, " | "))
  return seen
end

local function said(seen, pattern)
  for _, m in ipairs(seen.said) do if m:find(pattern) then return true end end
  return false
end

F.run(function()
  if not F.boot(HUB) then F.check("boot", false); F.finish(); return end
  for _, h in ipairs(HOUSES) do
    for off = 0, 6 * S.Pokemon.size - 4, 4 do F.w32(S.gParties + off, 0) end
    F.w8(S.gPartiesCount, 0)
    createMon(SPECIES_CHARIZARD, 50, { 10, 45, 52 })
    createMon(SPECIES_CHARIZARD, 50, { 10, 45, 52 })
    createMon(SPECIES_MAGIKARP, 5, { 150 })
    addItem(h.item, h.give)
    local paid0 = qty(h.item)
    F.check(h.name .. " setup: two Charizard, a Magikarp and the payment",
      F.r8(S.gPartiesCount) == 3 and paid0 >= h.give, string.format("party=%d items=%d", F.r8(S.gPartiesCount), paid0))
    F.w8(F.sb2() + S.SaveBlock2.currentRegion, h.region)
    F.w32(S.gCurrentRegion, h.region)
    if not F.check(h.name .. " setup: in front of the relearner", warpToCoords(h.group, h.map, h.x, h.y, h.name)) then
      F.finish(); return
    end
    local a = F.sb2() + S.SaveBlock2.optionsU16
    F.w16(a, (F.r16(a) & ~7) | 3)

    local g = visit(h.name .. "_giveup", 1, "giveup")
    F.check(h.name .. ": the second Charizard's move list opens", g.list)
    F.check(h.name .. ": giving up costs nothing", qty(h.item) == paid0 and not said(g, "HANDED OVER"),
      string.format("items %d -> %d", paid0, qty(h.item)))
    F.check(h.name .. ": giving up teaches nothing", moveCount(1) == 3, "moves=" .. moveCount(1))

    local k = visit(h.name .. "_magikarp", 2, "giveup")
    F.check(h.name .. ": the Magikarp gets the no-move line", said(k, "DOESN T APPEAR"))
    F.check(h.name .. ": no move list opens for the Magikarp", not k.list)
    F.check(h.name .. ": the Magikarp costs nothing", qty(h.item) == paid0, string.format("items %d -> %d", paid0, qty(h.item)))

    local l = visit(h.name .. "_learn", 0, "learn")
    F.check(h.name .. ": the first Charizard learns a move", moveCount(0) == 4, "moves=" .. moveCount(0))
    F.check(h.name .. ": the lesson costs one payment", qty(h.item) == paid0 - h.cost and said(l, "HANDED OVER"),
      string.format("items %d -> %d", paid0, qty(h.item)))
    F.check(h.name .. ": the chooser does not reopen after the lesson", not l.reopened)
    F.check(h.name .. ": control returns", hasControl())
    F.shot(h.name .. "_end")
  end
  F.check("no crash", not F.crashScreen())
  F.finish()
end)
