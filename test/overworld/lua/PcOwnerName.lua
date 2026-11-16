-- The storage PC's owner name follows each region's own unlock.
--
-- One cartridge holds three storage PCs that the source games name differently: Emerald says
-- SOMEONE'S PC until the player meets Lanette (FLAG_SYS_PC_LANETTE), FireRed until Bill gives the
-- S.S. Ticket, and HnS until Bill leaves the Ecruteak Pokemon Center (FLAG_SYS_PC_BILL). The name
-- shows in four places: the PC menu row, "Accessed ...'s PC.", the scripted gift line
-- (Common_EventScript_TransferredToPC) and the catch line in battle. Before the fix only some of
-- them looked at the region, and FireRed's Bill script wrote Hoenn's Lanette flag, so the name a
-- player saw depended on which flag another region had set.
--
-- Every unlock here is the region's own script driven with real input: Johto's Bill in the Ecruteak
-- Pokemon Center, Kanto's Bill handing over the S.S. Ticket in the Sea Cottage, and Lanette in her
-- Route 114 house. Setup only puts the actor on the map (clears the hide flag the game clears on
-- arrival) and, for the Sea Cottage, sets the flags the cell separator cutscene leaves. At each PC
-- the suite opens the menu with real input, reads "Accessed ...'s PC." from gStringVar4, and
-- fingerprints the menu's first row from the window's tile data: every name must keep one
-- fingerprint, and names must differ. The gift line is read from gStringVar4 (Celadon Eevee) and
-- the catch line from the battle text (Master Ball on a wild Pidgey, declining the party swap),
-- both with a full party.
--
-- Run: test/overworld/mgba-run.sh test/overworld/lua/PcOwnerName.lua

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "PcOwnerName")

local PARTY_SIZE, MON = 6, S.Pokemon.size
local BULBASAUR, SPECIES_PIDGEY = 1, 16
local ITEM_MASTER_BALL = 4
local CONTEXT_RUNNING, CONTEXT_SHUTDOWN = 0, 2

local FLAG_HIDE_ECRUTEAK_BILL = 0x60F8
local FLAG_SYS_PC_BILL_JOHTO = 0x60E8
local FLAG_SYS_PC_LANETTE = 0x993
local FLAG_GOT_SS_TICKET = 0xA40 + 0x234
local FLAG_HELPED_BILL_IN_SEA_COTTAGE = 0xA40 + 0x233
local FLAG_HIDE_BILL_HUMAN_SEA_COTTAGE = 0xA40 + 0x33
local FLAG_HIDE_LANETTES_HOUSE_LANETTE = 0x366

-- {group, num, x, y} of the tile in front of each PC or actor, all facing up.
local ECRUTEAK_PC = { 86, 4, 11, 2 }
local ECRUTEAK_BILL = { 86, 4, 11, 3 }   -- Bill stands in front of the PC
local OLDALE_PC = { 2, 2, 10, 2 }
local VIRIDIAN_PC = { 39, 4, 11, 2 }
local SEA_COTTAGE_BILL = { 62, 0, 7, 6 }
local LANETTE = { 20, 2, 5, 5 }
local CELADON_EEVEE = { 44, 11, 7, 4 }

local function instantText()
  local a = F.sb2() + S.SaveBlock2.optionsU16
  F.w16(a, (F.r16(a) & ~7) | 3)
end
local function hasControl()
  return F.ow() and F.r8(S.sLockFieldControls) == 0 and F.r8(S.sGlobalScriptContextStatus) == CONTEXT_SHUTDOWN
end
local function settle()
  for _ = 1, 300 do if hasControl() then return true end F.press("B", 2); F.idle(10) end
  return hasControl()
end

-- GBA charset to ASCII, enough for these lines.
local function decode(a, n)
  local out = {}
  for i = 0, (n or 200) - 1 do
    local c = F.r8(a + i)
    if c == 0xFF then break end
    if c >= 0xBB and c <= 0xD4 then out[#out + 1] = string.char(65 + c - 0xBB)
    elseif c >= 0xD5 and c <= 0xEE then out[#out + 1] = string.char(97 + c - 0xD5)
    elseif c >= 0xA1 and c <= 0xAA then out[#out + 1] = string.char(48 + c - 0xA1)
    elseif c == 0x00 or c == 0xFE or c == 0xFA or c == 0xFB then out[#out + 1] = " "
    elseif c == 0xAD then out[#out + 1] = "."
    elseif c == 0xB4 then out[#out + 1] = "'"
    end
  end
  return table.concat(out)
end
local function ownerIn(text)
  local up = text:upper()
  for _, n in ipairs({ "SOMEONE", "LANETTE", "BILL" }) do
    if up:find(n .. "'S PC", 1, true) then return n end
  end
  return nil
end

local SCRIPT_BUF = S.gStringVar4 + 960
local function le16(t, v) t[#t + 1] = v & 0xFF; t[#t + 1] = (v >> 8) & 0xFF end
local function runScript(b)
  for i, v in ipairs(b) do F.w8(SCRIPT_BUF + i - 1, v) end
  F.w8(S.sGlobalScriptContext, 0)
  F.w8(S.sGlobalScriptContext + 1, 1)
  F.w32(S.sGlobalScriptContext + 4, 0)
  F.w32(S.sGlobalScriptContext + S.ScriptCtx.scriptPtr, SCRIPT_BUF)
  F.w8(S.sGlobalScriptContextStatus, CONTEXT_RUNNING)
end
local function flagScript(op, flags)
  local b = {}
  for _, f in ipairs(flags) do b[#b + 1] = op; le16(b, f) end
  b[#b + 1] = 0x02
  runScript(b); F.idle(20)
end
local function setFlags(flags) flagScript(0x29, flags) end
local function clearFlags(flags) flagScript(0x2A, flags) end

local function warpTo(p, tag)
  local b = { 0x39, p[1], p[2], 0xFF }
  le16(b, p[3]); le16(b, p[4]); b[#b + 1] = 0x27; b[#b + 1] = 0x02
  runScript(b)
  for _ = 1, 400 do
    F.idle(4)
    if F.reportCrash("warp") then break end
    if F.grp() == p[1] and F.mapn() == p[2] and F.ow() then
      settle(); instantText()
      return true
    end
  end
  F.check(tag .. ": warped to " .. p[1] .. "." .. p[2], false,
    string.format("at %d.%d", F.grp(), F.mapn()))
  return false
end

local function johtoFlag(f) local n = f - 0x6000; return (F.r8(F.sb3() + S.SaveBlock3.johtoFlags + n // 8) >> (n % 8)) & 1 == 1 end
local function flag(f) return (F.r8(F.sb1() + S.SaveBlock1.flags + f // 8) >> (f % 8)) & 1 == 1 end

local function order(p)
  local o = {}
  for i = 0, 3 do o[i] = F.r8(S.sSubstructOffsets + i * 24 + p % 24) * 3 end
  return o
end
local function checksumOk(a)
  local key = F.r32(a) ~ F.r32(a + 4)
  local sum = 0
  for i = 0, 11 do local w = F.r32(a + 32 + i * 4) ~ key; sum = sum + (w & 0xFFFF) + (w >> 16) end
  return (sum & 0xFFFF) == F.r16(a + 28)
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
    for i = 0, n - 1 do ok = ok and checksumOk(S.gParties + i * MON) end
    if ok then return true end
    F.idle(60)
  end
  return false
end

-- Talk to whoever stands in front of the player and run their script to the end.
local function talk(tag)
  F.face("Up"); F.press("A", 2); F.idle(30)
  for _ = 1, 400 do
    if F.r8(S.sGlobalScriptContextStatus) == CONTEXT_SHUTDOWN and F.r8(S.sLockFieldControls) == 0 then break end
    F.press("A", 2); F.idle(20)
  end
  F.shot(tag)
  return settle()
end

-- Fingerprint of the menu window's first text row: tile rows 0 and 1 of its pixel buffer.
local function menuRowPrint()
  local w = S.gWindows + F.r8(S.sMenu + S.Menu.windowId) * S.Window.stride
  local width, data = F.r8(w + S.Window.width), F.r32(w + S.Window.tileData)
  if data < 0x02000000 or data >= 0x02040000 or width == 0 then return nil end
  local h = 2166136261
  for i = 0, width * 2 * 32 - 1, 4 do h = ((h ~ F.r32(data + i)) * 16777619) & 0xFFFFFFFF end
  return string.format("%08x", h)
end

local prints, printOwner = {}, {}

-- Open the PC with real input, fingerprint the menu, pick the storage row and read the access
-- line. Returns the owner it names.
local function usePc(pc, tag)
  if not warpTo(pc, tag) then return nil end
  F.face("Up")
  F.w8(S.sMenu + S.Menu.maxCursorPos, 0)
  F.press("A", 2)
  local live = false
  for _ = 1, 120 do
    F.idle(10)
    if F.r8(S.sMenu + S.Menu.maxCursorPos) >= 2 and F.mcur() == 0 then live = true; break end
    F.press("A", 2)
  end
  if not F.check(tag .. ": the PC menu opened", live) then F.shot(tag:gsub("[^%w]", "_") .. "_no_menu"); settle(); return nil end
  F.idle(20)
  F.shot(tag:gsub("[^%w]", "_") .. "_pcmenu")
  local fp = menuRowPrint()
  F.press("A", 2)
  local owner, line
  for _ = 1, 60 do
    F.idle(8)
    local t = decode(S.gStringVar4)
    if t:find("Accessed", 1, true) then owner, line = ownerIn(t), t; break end
  end
  F.shot(tag:gsub("[^%w]", "_") .. "_accessed")
  F.L(string.format("  %s: menu row print %s, access line '%s'", tag, tostring(fp), tostring(line)))
  for _ = 1, 30 do
    if hasControl() then break end
    F.press("B", 2); F.idle(30)
  end
  settle()
  if owner and fp then
    prints[#prints + 1] = { tag = tag, owner = owner, fp = fp }
  end
  return owner
end

local function expectPc(pc, want, tag)
  local got = usePc(pc, tag)
  F.check(string.format("%s: the PC is %s'S PC", tag, want), got == want, "access line names " .. tostring(got))
end

local function inBattle() return F.cb2() == (S.BattleMainCB2 & ~1) end
local function ctrl(b) return F.r32(S.gBattlerControllerFuncs + b * 4) & ~1 end
local function actionMenu()
  for _, p in ipairs(S.ActionInputFunctions) do if ctrl(0) == (p & ~1) then return true end end
  return false
end
local function atGiveCaughtMon() return F.r32(S.gBattlescriptCurrInstr) == S.BattleScript_GiveCaughtMonAfterNick end

-- Master Ball on a wild Pidgey with a full party, declining the swap; returns the owner the
-- battle's "transferred to" line names.
local function catchToPc(tag)
  local b = { 0x44 }; le16(b, ITEM_MASTER_BALL); le16(b, 1); b[#b + 1] = 0x02
  runScript(b); F.idle(30)
  local w = { 0xB6 }
  le16(w, SPECIES_PIDGEY); w[#w + 1] = 3; le16(w, 0); le16(w, 0); w[#w + 1] = 0; le16(w, 0)
  w[#w + 1] = 0xB7; w[#w + 1] = 0x02
  runScript(w)
  local started = false
  for _ = 1, 1500 do
    F.idle(1)
    if inBattle() and F.battlers() >= 2 then started = true; break end
  end
  F.check(tag .. ": a wild Pidgey battle started", started)
  local owner, line, threw, shotTaken = nil, nil, false, false
  for _ = 1, 4000 do
    if inBattle() then
      local t = decode(S.gDisplayedStringBattle, 300)
      if not owner and t:find("transferred", 1, true) then
        owner, line = ownerIn(t), t
      end
      if owner and not shotTaken then F.idle(20); F.shot(tag:gsub("[^%w]", "_") .. "_line"); shotTaken = true end
      if actionMenu() and not threw then
        F.idle(10); F.press("R", 2); F.idle(30); threw = true
      elseif atGiveCaughtMon() then
        F.press("B", 2); F.idle(10)
      else
        F.press("A", 2); F.idle(10)
      end
    elseif F.ow() and threw then
      break
    else
      F.press("Start", 2); F.idle(20); F.press("A", 2); F.idle(40)
    end
  end
  F.idle(40)
  settle()
  F.L(string.format("  %s: battle line '%s'", tag, tostring(line)))
  return owner
end

F.run(function()
  if not F.boot(100) then F.check("boot to the hub", false); F.finish(); return end
  instantText()
  F.check("setup: six Bulbasaur fill the party", giveParty(6, BULBASAUR, 10), "count=" .. F.r8(S.gPartiesCount))
  settle()

  -- Johto. Bill leaves the Ecruteak Pokemon Center and the Johto PC becomes his.
  expectPc(ECRUTEAK_PC, "SOMEONE", "Johto before Bill")
  clearFlags({ FLAG_HIDE_ECRUTEAK_BILL })
  if warpTo(ECRUTEAK_BILL, "Ecruteak Bill") then talk("ecruteak_bill") end
  F.check("Ecruteak Bill's own script set FLAG_SYS_PC_BILL", johtoFlag(FLAG_SYS_PC_BILL_JOHTO))
  expectPc(ECRUTEAK_PC, "BILL", "Johto after Bill")
  local caught = catchToPc("Johto catch")
  F.check("Johto catch: the line names BILL'S PC", caught == "BILL", "names " .. tostring(caught))

  -- Hoenn has not met Lanette.
  expectPc(OLDALE_PC, "SOMEONE", "Hoenn before Lanette")

  -- Kanto. Bill hands over the S.S. Ticket after the cell separator.
  expectPc(VIRIDIAN_PC, "SOMEONE", "Kanto before Bill")
  setFlags({ FLAG_HELPED_BILL_IN_SEA_COTTAGE })
  clearFlags({ FLAG_HIDE_BILL_HUMAN_SEA_COTTAGE })
  if warpTo(SEA_COTTAGE_BILL, "Sea Cottage Bill") then talk("sea_cottage_bill") end
  F.check("Sea Cottage Bill's own script gave the S.S. Ticket", flag(FLAG_GOT_SS_TICKET))
  F.check("Kanto's Bill leaves Hoenn's Lanette flag alone", not flag(FLAG_SYS_PC_LANETTE))
  expectPc(VIRIDIAN_PC, "BILL", "Kanto after Bill")
  expectPc(OLDALE_PC, "SOMEONE", "Hoenn after Kanto's Bill")

  do
    local tag = "Kanto gift"
    local owner, line
    if warpTo(CELADON_EEVEE, tag) then
      F.face("Up"); F.press("A", 2); F.idle(30)
      for _ = 1, 160 do
        local t = decode(S.gStringVar4)
        if not owner and t:find("transferred", 1, true) then owner, line = ownerIn(t), t; F.shot("kanto_gift_line") end
        if F.r8(S.sGlobalScriptContextStatus) == CONTEXT_SHUTDOWN then break end
        F.press("B", 2); F.idle(20)
      end
      settle()
    end
    F.L(string.format("  %s: line '%s'", tag, tostring(line)))
    F.check(tag .. ": the Eevee line names BILL'S PC", owner == "BILL", "names " .. tostring(owner))
  end

  -- Hoenn. Lanette gives the doll and the Hoenn PC becomes hers; the others keep Bill.
  clearFlags({ FLAG_HIDE_LANETTES_HOUSE_LANETTE })
  if warpTo(LANETTE, "Lanette") then talk("lanette") end
  F.check("Lanette's own script set FLAG_SYS_PC_LANETTE", flag(FLAG_SYS_PC_LANETTE))
  expectPc(OLDALE_PC, "LANETTE", "Hoenn after Lanette")
  expectPc(VIRIDIAN_PC, "BILL", "Kanto after Lanette")
  expectPc(ECRUTEAK_PC, "BILL", "Johto after Lanette")

  -- The menu row and the access line come from different code; they must agree on every visit.
  local byOwner, byPrint, agree = {}, {}, true
  for _, p in ipairs(prints) do
    if byOwner[p.owner] and byOwner[p.owner] ~= p.fp then agree = false; F.L("  print split for " .. p.owner .. " at " .. p.tag) end
    if byPrint[p.fp] and byPrint[p.fp] ~= p.owner then agree = false; F.L("  print shared by " .. byPrint[p.fp] .. " and " .. p.owner .. " at " .. p.tag) end
    byOwner[p.owner] = byOwner[p.owner] or p.fp
    byPrint[p.fp] = byPrint[p.fp] or p.owner
  end
  F.check("the PC menu row names the same owner as the access line at every PC", agree and #prints >= 9,
    #prints .. " visits fingerprinted")

  F.check("no crash", not F.reportCrash("end"))
  F.finish()
end)
