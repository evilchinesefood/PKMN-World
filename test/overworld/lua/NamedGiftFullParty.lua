-- Johto's named gift Pokemon with a full party and room in the PC. `givenamedmon` (Randy's Kenya,
-- Kirk's Shuckie, Bill's Eevee, the Dragon's Den Dratini) only ever places the Pokemon in the
-- party, so with six in the party it reports MON_CANT_GIVE however empty the boxes are. The
-- refusal must say the party is full, not that the PC boxes are, give nothing and leave the gift on
-- offer; with a free party slot the same talk must give it. Setup gives the team through the debug
-- menu and frees the slot in memory; the warps are debug warps, the talks and Yes/No are real input.
local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "NamedGiftFullParty")

local HUB = 100
local SLOTS = 14 * 30
local REGION_JOHTO = 2
local CONTEXT_SHUTDOWN = 2
local VAR_KENYA, VAR_SHUCKIE = 0xA080 + 0x09, 0xA080 + 0x2A
local FLAG_GOT_BILLS_EEVEE = 0x6000 + 0x25E
local FLAG_HIDE_GOLDENROD_BILL = 0x6000 + 0xD8

local GIFTS = {
  { tag = "kenya", group = 83, num = 6, warp = 0, at = { { 7, 8 }, { 7, 7 } }, face = "Right",
    given = function(self) return self.getVar(VAR_KENYA) == 1 end },
  { tag = "shuckie", group = 90, num = 3, warp = 0, at = { { 4, 7 }, { 4, 5 } }, face = "Up",
    given = function(self) return self.getVar(VAR_SHUCKIE) == 1 end },
  -- Bill is home once the Ecruteak Pokemon Center scene clears his hide flag.
  { tag = "eevee", group = 84, num = 1, warp = 0, at = { { 4, 7 }, { 4, 4 } }, face = "Right",
    prep = function(self) self.setJohtoFlag(FLAG_HIDE_GOLDENROD_BILL, false) end,
    given = function(self) return self.johtoFlag(FLAG_GOT_BILLS_EEVEE) end },
}

local function where() local x, y = F.pos(); return string.format("%d/%d (%d,%d)", F.grp(), F.mapn(), x, y) end
local function count() return F.r8(S.gPartiesCount) end
local function party(slot) return S.gParties + (slot or 0) * S.Pokemon.size end
local function box(slot) return F.r32(S.gPokemonStoragePtr) + 4 + slot * S.BoxPokemon.size end
local function present(address) return (F.r8(address + 19) & 2) ~= 0 end
local function bytes(base, size)
  local out = {}
  for i = 0, size - 1 do out[#out + 1] = string.char(F.r8(base + i)) end
  return table.concat(out)
end
local function putBytes(base, value) for i = 1, #value do F.w8(base + i - 1, value:byte(i)) end end
local function zero(base, size) for i = 0, size - 1 do F.w8(base + i, 0) end end
local function varAddr(id) return F.sb3() + S.SaveBlock3.regionVars + (id - 0xA000) * 2 end
local function getVar(id) return F.r16(varAddr(id)) end
local function johtoFlag(id)
  local offset = id - 0x6000
  return (F.r8(F.sb3() + S.SaveBlock3.johtoFlags + offset // 8) & (1 << (offset % 8))) ~= 0
end
local function setJohtoFlag(id, on)
  local offset = id - 0x6000
  local a, m = F.sb3() + S.SaveBlock3.johtoFlags + offset // 8, 1 << (offset % 8)
  F.w8(a, on and (F.r8(a) | m) or (F.r8(a) & ~m & 0xFF))
end
local function setRegion(r)
  F.w8(F.sb2() + S.SaveBlock2.currentRegion, r)
  F.w32(S.gCurrentRegion, r)
end
local function boxed()
  local n = 0
  for i = 0, SLOTS - 1 do if present(box(i)) then n = n + 1 end end
  return n
end

local function order(p)
  local o = {}
  for i = 0, 3 do o[i] = F.r8(S.sSubstructOffsets + i * 24 + p % 24) * 3 end
  return o
end
-- Re-key a copied Pokemon to a new personality so every member is a distinct individual.
local function rekey(address, personality)
  local key = F.r32(address) ~ F.r32(address + 4)
  local w = {}
  for i = 0, 11 do w[i] = F.r32(address + 32 + i * 4) ~ key end
  local o = order(F.r32(address))
  local sub = {}
  for i = 0, 3 do sub[i] = { w[o[i]], w[o[i] + 1], w[o[i] + 2] } end
  F.w32(address, personality)
  key = personality ~ F.r32(address + 4)
  o = order(personality)
  for i = 0, 3 do for k = 0, 2 do F.w32(address + 32 + (o[i] + k) * 4, sub[i][k + 1] ~ key) end end
end

-- gStringVar4 (the message being printed) as uppercase ASCII; Gen 3 A = 0xBB, a = 0xD5.
local function message()
  local s = {}
  for i = 0, 200 do
    local c = F.r8(S.gStringVar4 + i)
    if c == 0xFF then break end
    if c >= 0xBB and c <= 0xD4 then s[#s + 1] = string.char(65 + c - 0xBB)
    elseif c >= 0xD5 and c <= 0xEE then s[#s + 1] = string.char(65 + c - 0xD5)
    else s[#s + 1] = " " end
  end
  return table.concat(s)
end

local function scriptMenuActive()
  for i = 0, S.Task.count - 1 do
    local a = S.gTasks + i * S.Task.stride
    local fn = F.r32(a + S.Task.func) & 0xFFFFFFFE
    if F.r8(a + S.Task.isActive) ~= 0 and (fn == S.Task_HandleYesNoInput or fn == S.Task_HandleMultichoiceInput
      or fn == S.Task_CallYesOrNoCallback) then return true end
  end
  return false
end
local function drain()
  for _ = 1, 30 do
    F.press("B", 2); F.idle(16)
    if F.ensureFree() then return true end
  end
  return false
end

-- Talk, answer Yes to the offer, then read every message until the script lets go.
local function talk(gift, shot)
  F.face(gift.face); F.press("A", 2); F.idle(30)
  local seen, answered = {}, false
  for _ = 1, 400 do
    if F.reportCrash(gift.tag) then break end
    local m = message()
    if seen[#seen] ~= m then seen[#seen + 1] = m end
    if scriptMenuActive() and not answered then
      F.idle(12)
      if F.mcur() ~= 0 then F.press("Up", 2); F.idle(12) end
      F.press("A", 2); F.idle(30)
      answered = true
    elseif scriptMenuActive() then
      F.press("B", 2); F.idle(20)
    else
      if shot and m:find("ROOM") then F.idle(90); F.shot(gift.tag .. "_refusal"); shot = false end
      F.press("B", 2); F.idle(14)
      if F.r8(S.sGlobalScriptContextStatus) == CONTEXT_SHUTDOWN and F.ow() then
        F.idle(20)
        if F.r8(S.sGlobalScriptContextStatus) == CONTEXT_SHUTDOWN and not scriptMenuActive() then break end
      end
    end
  end
  return table.concat(seen, " | "), answered
end

F.run(function()
  if not F.boot(HUB) then F.check("fresh boot", false); F.finish(); return end
  F.dbg(); F.idle(40); F.sel(2); F.idle(40)
  for _ = 1, 9 do F.press("Down", 3); F.idle(16) end
  F.press("A", 3); F.idle(180)
  drain()
  local template = bytes(party(), S.Pokemon.size)
  for i = 0, 5 do zero(party(i), S.Pokemon.size) end
  for i = 0, 5 do putBytes(party(i), template); rekey(party(i), 0xA100 + i) end
  F.w8(S.gPartiesCount, 6)
  F.check("setup: a full party of six and empty boxes", count() == 6 and boxed() == 0,
    "count=" .. count() .. " boxed=" .. boxed())
  local team = {}
  for i = 0, 5 do team[i] = bytes(party(i), S.Pokemon.size) end
  local ctx = { getVar = getVar, johtoFlag = johtoFlag, setJohtoFlag = setJohtoFlag }

  for _, gift in ipairs(GIFTS) do
    setRegion(REGION_JOHTO)
    if gift.prep then gift.prep(ctx) end
    local gh, gt, go = gift.group // 100, (gift.group // 10) % 10, gift.group % 10
    local reached = F.warpTo(gh, gt, go, 0, gift.num // 10, gift.num % 10, 0, 0, gift.warp, gift.group, gift.num, gift.tag)
    drain()
    F.check(gift.tag .. ": reach the giver", reached, where())
    if reached then
      F.check(gift.tag .. ": walk to the giver", F.route(gift.at, gift.tag .. "_walk"), where())
      local text, answered = talk(gift, true)
      drain()
      F.L("  " .. gift.tag .. " full party said: " .. text)
      local same = count() == 6
      for i = 0, 5 do if bytes(party(i), S.Pokemon.size) ~= team[i] then same = false end end
      F.check(gift.tag .. ": the offer was accepted", answered)
      F.check(gift.tag .. ": a full party gets nothing", same and boxed() == 0 and not gift.given(ctx),
        "count=" .. count() .. " boxed=" .. boxed() .. " given=" .. tostring(gift.given(ctx)))
      F.check(gift.tag .. ": the refusal does not say the boxes are full", not text:find("BOXES"), text)
      F.check(gift.tag .. ": the refusal says the party is full", text:find("PARTY") ~= nil, text)

      zero(party(5), S.Pokemon.size)
      F.w8(S.gPartiesCount, 5)
      F.check(gift.tag .. ": walk back to the giver", F.route(gift.at, gift.tag .. "_walk2"), where())
      talk(gift, false)
      drain()
      F.check(gift.tag .. ": with a free slot the gift joins the party", count() == 6 and present(party(5))
        and gift.given(ctx) and boxed() == 0, "count=" .. count() .. " given=" .. tostring(gift.given(ctx)))
      putBytes(party(5), team[5])
      F.w8(S.gPartiesCount, 6)
    end
  end
  F.check("no crash", not F.crashScreen())
  F.finish()
end)
