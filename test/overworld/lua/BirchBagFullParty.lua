-- A Johto champion can reach Birch's bag on Route 101 with a full party (Frontier ferry, then the
-- same-region gate). The starter then goes to the PC, and Birch's lab scene must still talk about
-- the starter and say where it went, not offer to nickname the party's lead.
-- Setup writes the region, the Route 101 story state and a six-Pokemon party; the rescue trigger,
-- the bag, the starter pick, the first battle and the lab scene use real input.
local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "BirchBagFullParty")

local REGION_HOENN = 3
local ROUTE101_G, ROUTE101_M = 0, 16
local LAB_G, LAB_M = 1, 4
local VAR_ROUTE101_STATE, VAR_BIRCH_LAB_STATE, VAR_STARTER_MON = 0x4060, 0x4084, 0x4023
local HIDE_FLAGS = { 0x2BC, 0x2D0, 0x2EE }
local STARTERS = { [0] = 252, 255, 258 }
local SPECIES_PIDGEY = 16
-- PW_BIRCH_PARTY=0 runs the ordinary empty-party start as a control.
local FULL = (os.getenv("PW_BIRCH_PARTY") or "6") ~= "0"
local ROW_GIVE, ROW_MON_BASIC = 3, 1
local BOX_SLOTS = 14 * 30

local OFF_SECURE = 32
local SUB0 = { [0]=0,0,0,0,0,0,1,1,2,3,2,3,1,1,2,3,2,3,1,1,2,3,2,3 }

local function count() return F.r8(S.gPartiesCount) end
local function where() local x, y = F.pos(); return string.format("%d/%d (%d,%d)", F.grp(), F.mapn(), x, y) end
local function varAddr(id) return F.sb1() + S.SaveBlock1.vars + (id - 0x4000) * 2 end
local function setVar(id, v) F.w16(varAddr(id), v) end
local function getVar(id) return F.r16(varAddr(id)) end
local function sb1Flag(id, on)
  local a, m = F.sb1() + S.SaveBlock1.flags + (id // 8), 1 << (id % 8)
  F.w8(a, on and (F.r8(a) | m) or (F.r8(a) & ~m & 0xFF))
end
local function setRegion(r)
  F.w32(S.gCurrentRegion, r)
  F.w8(F.sb2() + S.SaveBlock2.currentRegion, r)
end

local function speciesAt(mon)
  if (F.r8(mon + 19) & 2) == 0 then return 0 end
  local key = F.r32(mon) ~ F.r32(mon + 4)
  local sub = mon + OFF_SECURE + SUB0[F.r32(mon) % 24] * 12
  return (F.r16(sub) ~ (key & 0xFFFF)) & 0x7FF
end
local function party(slot) return S.gParties + slot * S.Pokemon.size end
local function boxCount(sp)
  local base, n = F.r32(S.gPokemonStoragePtr) + 4, 0
  for i = 0, BOX_SLOTS - 1 do if speciesAt(base + i * 80) == sp then n = n + 1 end end
  return n
end
local function partyCount(sp)
  local n = 0
  for i = 0, 5 do if speciesAt(party(i)) == sp then n = n + 1 end end
  return n
end

-- gStringVar1 decoded to lowercase ASCII letters (Gen 3 charset: A = 0xBB, a = 0xD5).
local function strVar(addr)
  local s = {}
  for i = 0, 15 do
    local c = F.r8(addr + i)
    if c == 0xFF then break end
    if c >= 0xBB and c <= 0xD4 then s[#s + 1] = string.char(97 + c - 0xBB)
    elseif c >= 0xD5 and c <= 0xEE then s[#s + 1] = string.char(97 + c - 0xD5) end
  end
  return table.concat(s)
end
local NAMES = { [252] = "treecko", [255] = "torchic", [258] = "mudkip", [16] = "pidgey" }

local function tapDown(n) for _ = 1, n do F.press("Down", 3); F.idle(16) end end
local function drain(tries)
  for i = 1, tries or 40 do
    F.press("B", 3); F.idle(20)
    if i % 5 == 0 and F.ensureFree() then return true end
  end
  return F.ensureFree()
end
local function give(sp)
  F.dbg(); F.idle(60)
  tapDown(ROW_GIVE); F.press("A", 3); F.idle(50)
  tapDown(ROW_MON_BASIC); F.press("A", 3); F.idle(40)
  F.press("Right", 2); F.idle(10)
  for _ = 1, (sp // 10) % 10 do F.press("Up", 2); F.idle(8) end
  F.press("Left", 2); F.idle(10)
  for _ = 1, sp % 10 - 1 do F.press("Up", 2); F.idle(8) end
  F.press("A", 3); F.idle(30)
  F.press("A", 3); F.idle(80)
  for _ = 1, 10 do F.press("B", 3); F.idle(20) end
  drain(20)
end

F.run(function()
  if not F.boot(100) then F.check("boot to the hub", false); F.finish(); return end
  setRegion(REGION_HOENN)
  if FULL then
    give(SPECIES_PIDGEY)
    for slot = 1, 5 do
      for i = 0, S.Pokemon.size - 1 do F.w8(party(slot) + i, F.r8(party(0) + i)) end
    end
    F.w8(S.gPartiesCount, 6)
  end
  F.check("setup: party of " .. (FULL and 6 or 0), count() == (FULL and 6 or 0) and partyCount(SPECIES_PIDGEY) == count(),
    string.format("count=%d pidgey=%d", count(), partyCount(SPECIES_PIDGEY)))

  setVar(VAR_ROUTE101_STATE, 1)
  setVar(VAR_BIRCH_LAB_STATE, 0)
  for _, flag in ipairs(HIDE_FLAGS) do sb1Flag(flag, false) end
  if not F.warpTo(0, 0, 0, 0, 1, 6, 0, 0, 0, ROUTE101_G, ROUTE101_M, "route101") then
    F.check("warp to Route 101", false, where()); F.finish(); return
  end
  setRegion(REGION_HOENN)
  setVar(VAR_ROUTE101_STATE, 1)
  F.route({ { 4, 10 }, { 4, 15 }, { 11, 15 }, { 11, 18 } }, "to_trigger")
  F.step("Down")
  for _ = 1, 200 do
    F.press("B", 2); F.idle(20)
    if getVar(VAR_ROUTE101_STATE) == 2 and F.ensureFree() then break end
  end
  F.check("the Birch rescue scene runs", getVar(VAR_ROUTE101_STATE) == 2, where())

  F.leg(8, 16)
  F.leg(7, 16)
  F.leg(7, 15)
  F.face("Up")
  F.press("A", 3)
  for _ = 1, 1500 do
    F.press("A", 2); F.idle(14)
    if F.grp() == LAB_G and F.mapn() == LAB_M and F.ow() then break end
    if F.reportCrash("starter") then break end
  end
  F.check("the bag, the first battle and the warp reach Birch's lab", F.grp() == LAB_G and F.mapn() == LAB_M, where())
  local starter = STARTERS[getVar(VAR_STARTER_MON)] or -1
  local named, toldPC, naming = "", false, false
  for i = 1, 200 do
    if F.ow() then
      if not naming then named = strVar(S.gStringVar1) end
      toldPC = toldPC or strVar(S.gStringVar2) == NAMES[starter]
      F.press("A", 2); F.idle(20)
    else
      if not naming then F.shot("naming"); naming = true end
      F.press("Start", 2); F.idle(20); F.press("A", 2); F.idle(40)
    end
    if i % 10 == 0 then F.shot("lab") end
    if getVar(VAR_BIRCH_LAB_STATE) == 3 and F.ow() then break end
  end
  drain(30)

  if FULL then
    F.check("the starter went to the PC, once", boxCount(starter) == 1 and partyCount(starter) == 0,
      string.format("starter=%d box=%d party=%d", starter, boxCount(starter), partyCount(starter)))
    F.check("the party is unchanged", count() == 6 and partyCount(SPECIES_PIDGEY) == 6,
      string.format("count=%d pidgey=%d", count(), partyCount(SPECIES_PIDGEY)))
    F.check("the lab scene says the starter was sent to the PC", toldPC, "STR_VAR_2 never named the starter")
  else
    F.check("the starter is the only party member", count() == 1 and partyCount(starter) == 1 and boxCount(starter) == 0,
      string.format("starter=%d count=%d box=%d", starter, count(), boxCount(starter)))
    F.check("an empty party gets no PC message", not toldPC)
  end
  F.check("the lab scene names the starter, not the party's lead", named == NAMES[starter],
    string.format("STR_VAR_1=%s want %s", named, tostring(NAMES[starter])))
  F.check("the nickname screen opens for the starter", naming)
  F.check("the lab scene ends", getVar(VAR_BIRCH_LAB_STATE) == 3, "lab state=" .. getVar(VAR_BIRCH_LAB_STATE))
  F.check("no crash", not F.crashScreen())
  F.finish()
end)
