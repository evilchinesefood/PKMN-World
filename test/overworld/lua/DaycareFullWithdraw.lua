-- Day Care withdrawal with a full party and a full PC, at all four Day Cares: Route 117 (Hoenn),
-- Route 5 and Four Island (Kanto) and Route 34 (Johto). Each Day Care takes a real deposit through
-- its own script and picker; then the party is filled to six, the PC boxes are filled (debug Fill
-- PC Boxes Fast) and the wallet holds 50,000. Asking for the Pokemon back must be refused with the
-- Day Care's no-room line: no money taken, the Pokemon still in the Day Care, the party and the PC
-- unchanged, and the field back under control. The messages are read from gStringVar4: Route 117,
-- Four Island and Route 34 run the same script and must print the same lines, line breaks included,
-- for the "raise one more?" offer, the greeting and the "team is full" refusal.
--
-- PW_DCFULL_ONLY=<text> runs matching Day Cares.
local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "DaycareFullWithdraw")

local HUB_GROUP = 100
local ONLY = os.getenv("PW_DCFULL_ONLY")
local CONTEXT_SHUTDOWN = 2
local CONTEXT_RUNNING = 0
local PARTY_SIZE = 6
local SPECIES_RATTATA, SPECIES_PIDGEY = 19, 16
local MOVE_TACKLE = 33
local BOXES, PER_BOX = 14, 30
local WALLET = 50000

local function key32() return F.r32(F.sb2() + S.SaveBlock2.encryptionKey) end
local function setMoney(v) F.w32(F.sb1() + S.SaveBlock1.money, v ~ key32()) end
local function partyCount() return F.r8(S.gPartiesCount) end
local function partyAddr(i) return S.gParties + i * S.Pokemon.size end

local SCRIPT_BUF = S.gStringVar4 + 960
local function le16(t, v) t[#t + 1] = v & 0xFF; t[#t + 1] = (v >> 8) & 0xFF end
local function le32(t, v) le16(t, v & 0xFFFF); le16(t, (v >> 16) & 0xFFFF) end
local function runScript(bytes)
  for i, b in ipairs(bytes) do F.w8(SCRIPT_BUF + i - 1, b) end
  F.w8(S.sGlobalScriptContext, 0)
  F.w8(S.sGlobalScriptContext + 1, 1)
  F.w32(S.sGlobalScriptContext + 4, 0)
  F.w32(S.sGlobalScriptContext + S.ScriptCtx.scriptPtr, SCRIPT_BUF)
  F.w8(S.sGlobalScriptContextStatus, CONTEXT_RUNNING)
  F.idle(20)
end
local function giveMon(species, level)
  local b = { 0x23 }; le32(b, S.ScrCmd_createmon | 1)
  b[#b + 1] = 0; b[#b + 1] = PARTY_SIZE
  le16(b, species); le16(b, level)
  le32(b, (1 << 17) | (1 << 18) | (1 << 19) | (1 << 20))
  for k = 1, 4 do le16(b, k == 1 and MOVE_TACKLE or 0) end
  b[#b + 1] = 0x02
  runScript(b)
end

local function storage() return F.r32(S.gPokemonStoragePtr) end
local function boxSlot(box, slot) return storage() + 4 + (box * PER_BOX + slot) * S.BoxPokemon.size end
local function occupied(a) return F.r32(a) ~= 0 or F.r32(a + 4) ~= 0 end
local function boxCount()
  local n = 0
  for box = 0, BOXES - 1 do for slot = 0, PER_BOX - 1 do if occupied(boxSlot(box, slot)) then n = n + 1 end end end
  return n
end
local function partyPids()
  local t = {}
  for i = 0, partyCount() - 1 do t[#t + 1] = string.format("%08X", F.r32(partyAddr(i))) end
  return table.concat(t, ",")
end

local function tapDown(n) for _ = 1, n do F.press("Down", 3); F.idle(16) end end
local function drain(tries)
  for i = 1, tries or 40 do
    F.press("B", 3); F.idle(20)
    if i % 5 == 0 and F.ensureFree() then return true end
  end
  return F.ensureFree()
end
local function debugAction(path, tag)
  F.dbg(); F.idle(60)
  for i, row in ipairs(path) do
    tapDown(row); F.press("A", 3); F.idle(i == #path and 240 or 60)
  end
  if not drain(20) then F.L("  debug action " .. tag .. " did not return to the field") return false end
  return true
end

local function findTask(fn)
  for i = 0, S.Task.count - 1 do
    local a = S.gTasks + i * S.Task.stride
    if F.r8(a + S.Task.isActive) ~= 0 and (F.r32(a + S.Task.func) & ~1) == (fn & ~1) then return a end
  end
  return nil
end

local function scriptLive()
  local p = F.r32(S.sGlobalScriptContext + S.ScriptCtx.scriptPtr)
  return F.r8(S.sGlobalScriptContextStatus) ~= CONTEXT_SHUTDOWN and p >= 0x08000000 and p < 0x0A000000
end
local function fieldFree() return F.ow() and not scriptLive() and F.r8(S.sLockFieldControls) == 0 end
local function yesNoUp() return findTask(S.Task_HandleYesNoInput) ~= nil end
local function multiUp() return findTask(S.Task_HandleMultichoiceInput) ~= nil end
-- The Day Care's level menu is a ListMenu (it does not move sMenu's cursor) that clamps at both
-- ends, so its row is reached by counting Downs from the top.
local function levelMenuUp() return findTask(S.Task_HandleDaycareLevelMenuInput) ~= nil end

local function where() local x, y = F.pos(); return string.format("%d/%d (%d,%d)", F.grp(), F.mapn(), x, y) end

-- The field message as the game expanded it into gStringVar4; é reads as "?" and the line and
-- page breaks as \n, \l and \p.
local function decode(addr)
  local out = {}
  for i = 0, 399 do
    local c = F.r8(addr + i)
    if c == 0xFF then break end
    if c == 0x00 then out[#out + 1] = " "
    elseif c == 0xFE then out[#out + 1] = "\\n"
    elseif c == 0xFA then out[#out + 1] = "\\l"
    elseif c == 0xFB then out[#out + 1] = "\\p"
    elseif c >= 0xBB and c <= 0xD4 then out[#out + 1] = string.char(65 + c - 0xBB)
    elseif c >= 0xD5 and c <= 0xEE then out[#out + 1] = string.char(97 + c - 0xD5)
    elseif c >= 0xA1 and c <= 0xAA then out[#out + 1] = string.char(48 + c - 0xA1)
    elseif c == 0xAB then out[#out + 1] = "!"
    elseif c == 0xAD then out[#out + 1] = "."
    elseif c == 0xB8 then out[#out + 1] = ","
    elseif c == 0xB4 then out[#out + 1] = "'"
    else out[#out + 1] = "?" end
  end
  return table.concat(out)
end

local function instantText()
  local a = F.sb2() + S.SaveBlock2.optionsU16
  F.w16(a, (F.r16(a) & ~7) | 3)
end

-- ---- driving a conversation -------------------------------------------------------------------
-- Advance the running script with A, answering each Yes/No or multichoice from o.answers in order
-- ("yes", "no", or a multichoice row; a missing answer is B). o.onPrompt(i) runs before prompt i is
-- answered, o.stop() ends the drive early (a party menu taking over), o.shot names a screenshot of
-- each reply, o.texts collects every distinct field message. Returns the answers used, whether the
-- field came back, and the prompts seen.
-- The prompts' own input delays (5 frames on Yes/No) make a blind A safe when a prompt appears.
local function converse(o)
  local answers = o.answers or {}
  local used, calm, prompts = 0, 0, {}
  local function after()
    F.idle(30)
    if o.shot then F.shot(o.shot .. "_after" .. used) end
  end
  local picked = false
  for f = 1, o.budget or 4000 do
    if F.reportCrash("converse") then return used, false, prompts end
    if o.texts then
      local t = decode(S.gStringVar4)
      if o.texts[#o.texts] ~= t then o.texts[#o.texts + 1] = t end
    end
    if o.stop and o.stop() then return used, false, prompts end
    if o.picker and not picked and not F.ow() then
      picked = true
      prompts[#prompts + 1] = "picker"
      o.picker()
    end
    if yesNoUp() then
      F.idle(10)
      used = used + 1
      if o.onPrompt then o.onPrompt(used) end
      local a = answers[used]
      prompts[#prompts + 1] = "yesno:" .. tostring(a)
      if a == "yes" then
        for _ = 1, 4 do if F.mcur() == 0 then break end F.press("Up", 2); F.idle(8) end
        F.press("A", 2)
      else
        F.press("B", 2)
      end
      for _ = 1, 120 do F.idle(1); if not yesNoUp() then break end end
      after()
      calm = 0
    elseif multiUp() then
      F.idle(12)
      if o.shot then F.shot(o.shot .. "_menu" .. (used + 1)) end
      used = used + 1
      if o.onPrompt then o.onPrompt(used) end
      local row = answers[used]
      prompts[#prompts + 1] = "multi:" .. tostring(row)
      if type(row) ~= "number" then
        F.press("B", 2)
      else
        for _ = 1, 8 do if F.mcur() == row then break end F.press("Down", 2); F.idle(10) end
        F.press("A", 2)
      end
      for _ = 1, 120 do F.idle(1); if not multiUp() then break end end
      after()
      calm = 0
    elseif levelMenuUp() then
      F.idle(12)
      if o.shot then F.shot(o.shot .. "_levels" .. (used + 1)) end
      used = used + 1
      if o.onPrompt then o.onPrompt(used) end
      local row = answers[used]
      prompts[#prompts + 1] = "levels:" .. tostring(row)
      for _ = 1, (type(row) == "number" and row or 9) do F.press("Down", 2); F.idle(12) end
      F.press("A", 2)
      for _ = 1, 120 do F.idle(1); if not levelMenuUp() then break end end
      after()
      calm = 0
    elseif fieldFree() then
      calm = calm + 1
      if calm >= 30 then return used, true, prompts end
      F.idle(1)
    else
      calm = 0
      if f % 16 == 0 then F.press("A", 2) else F.idle(1) end
    end
  end
  return used, false, prompts
end

local function warp(w, g, m, tag)
  if F.grp() == g and F.mapn() == m then return true end
  local ok = F.warpTo(w[1], w[2], w[3], w[4], w[5], w[6], w[7], w[8], w[9], g, m, tag)
  if ok then instantText() end
  return ok
end

local BACK = { Up = "Down", Down = "Up", Left = "Right", Right = "Left" }

local function walk(path)
  for _, p in ipairs(path) do
    if not F.leg(p[1], p[2]) then return false end
  end
  return true
end

local function leftField() return not F.ow() end
local function has(list, text)
  for _, t in ipairs(list) do if t == text then return true end end
  return false
end

local function goTo(sink)
  if not warp(sink.warp, sink.g, sink.m, sink.tag) then return false, "warp failed" end
  if sink.arrive then sink.arrive() end
  if not walk(sink.path) then return false, "walk failed " .. where() end
  if sink.face then F.face(sink.face) end
  return true
end

-- The deposit picker is the SwSh storage screen with the cursor in box slot 1: Left lands on
-- party slot 2, Up and Down move along the party, A opens the menu and A picks SELECT.
local function depositPick(target, shotTag)
  F.idle(200)
  if F.ow() then F.shot(shotTag .. "_no_picker"); return false end
  F.press("Left", 2); F.idle(40)
  if target == 0 then F.press("Up", 2); F.idle(40) end
  for _ = 2, target do F.press("Down", 2); F.idle(40) end
  F.shot(shotTag .. "_deposit_pick")
  F.press("A", 2); F.idle(40)
  F.shot(shotTag .. "_deposit_menu")
  F.press("A", 2); F.idle(60)
  return true
end

local DAYCARE_MON_SIZE = 140
local function dayCareSlot() return F.sb1() + S.SaveBlock1.daycare end
local function route5Slot() return F.sb3() + S.SaveBlock3.route5DayCareMon end

-- Deposit answers: "Raise one more?" No (Route 5 asks nothing). Withdrawal answers: "Take your
-- Pokemon back?" Yes then the fee, or (Route 5) the fee Yes. refusal is the no-room line.
local TEAM_FULL = "Your POK?MON team is full.\\nMake room, then come see me."
local ONE_MORE = "We can raise two of your POK?MON.\\nWould you like us to raise one more?"
local GOOD_TO_SEE_YOU = "Ah, it's you! Good to see you.\\nYour POK?MON can only be doing good!"
local function shared(t) t.refusal = TEAM_FULL; t.oneMore = ONE_MORE; t.greeting = GOOD_TO_SEE_YOU; return t end
local DAYCARES = {
  shared({ tag = "route117", warp = { 0, 2, 2, 0, 0, 0, 0, 0, 0 }, g = 22, m = 0, path = { { 2, 4 } }, face = "Up",
    slot = dayCareSlot, answers = { "no", "yes", "yes" } }),
  { tag = "route5", warp = { 0, 5, 1, 0, 0, 0, 0, 0, 0 }, g = 51, m = 0, path = { { 4, 7 }, { 4, 5 } }, face = "Up",
    slot = route5Slot, answers = { "yes" },
    refusal = "You can't take this POK?MON back\\nif you've got no room for it." },
  shared({ tag = "fourisland", warp = { 0, 6, 7, 0, 0, 0, 0, 0, 0 }, g = 67, m = 0, path = { { 2, 7 }, { 2, 4 } }, face = "Up",
    slot = dayCareSlot, answers = { "no", "yes", "yes" } }),
  shared({ tag = "route34", warp = { 0, 8, 1, 0, 0, 5, 0, 0, 0 }, g = 81, m = 5, path = { { 3, 4 }, { 3, 6 } }, face = "Down",
    slot = dayCareSlot, answers = { "no", "yes", "yes" } }),
}

-- Talk to the counter: A until a script holds the field.
local function talkTo()
  for _ = 1, 5 do
    F.idle(30); F.press("A", 2); F.idle(20)
    if not fieldFree() then return true end
  end
  return false
end

local function run(d)
  local tag = d.tag
  -- A fresh party for this Day Care: two Pidgey (Hoenn refuses to leave one) and the Rattata
  -- deposited from the last slot.
  debugAction({ 2, 8 }, "clear_party")
  giveMon(SPECIES_PIDGEY, 10); giveMon(SPECIES_PIDGEY, 10); giveMon(SPECIES_RATTATA, 5)
  local ok, err = goTo(d)
  if not F.check(tag .. ": reached the counter", ok, err or where()) then return end
  F.L(string.format("  %s: party %d before the deposit (%s)", tag, partyCount(), partyPids()))
  F.check(tag .. ": the counter answers", talkTo(), where())
  F.shot(tag .. "_talk")
  converse({ answers = { "yes" }, stop = leftField, shot = tag .. "_dep" })
  if not F.check(tag .. ": the deposit picker opened", depositPick(partyCount() - 1, tag)) then return end
  local depositTexts = {}
  converse({ texts = depositTexts })
  if d.oneMore then
    F.check(tag .. ": offers to raise one more with the shared line", has(depositTexts, d.oneMore),
      table.concat(depositTexts, " | "))
  end
  local pid = F.r32(d.slot())
  F.check(tag .. ": the Rattata went into the Day Care", pid ~= 0 and partyCount() == 2,
    string.format("daycare=%08X party=%d", pid, partyCount()))

  for _ = 1, 4 do giveMon(SPECIES_PIDGEY, 5) end
  if boxCount() < BOXES * PER_BOX then debugAction({ 1, 1, 0 }, "fill_pc") end
  setMoney(WALLET)
  for _ = 1, 6 do F.step(_ % 2 == 1 and "Right" or "Left") end
  local before = { party = partyPids(), n = partyCount(), boxes = boxCount(), money = F.money(), pid = F.r32(d.slot()) }
  F.check(tag .. ": a full party of six and a full PC", before.n == 6 and before.boxes == BOXES * PER_BOX,
    string.format("party=%d boxes=%d", before.n, before.boxes))

  if not goTo(d) then F.check(tag .. ": back at the counter", false, where()); return end
  talkTo()
  local texts = {}
  local used, back, prompts = converse({ answers = d.answers, shot = tag, texts = texts })
  F.L(string.format("  %s: prompts %s", tag, table.concat(prompts, " ")))
  F.L(string.format("  %s: last message %q", tag, texts[#texts] or ""))
  F.shot(tag .. "_after")
  F.check(tag .. ": the withdrawal was asked for", #prompts >= 1 and prompts[#prompts]:find("yes", 1, true) ~= nil,
    table.concat(prompts, " "))
  if d.greeting then
    F.check(tag .. ": greets with the shared line", has(texts, d.greeting), table.concat(texts, " | "))
  end
  F.check(tag .. ": refused with the no-room line", texts[#texts] == d.refusal,
    string.format("got %q", texts[#texts] or ""))
  F.check(tag .. ": refused: no money taken", F.money() == before.money, before.money .. " -> " .. F.money())
  F.check(tag .. ": refused: the Pokemon is still in the Day Care", F.r32(d.slot()) == before.pid,
    string.format("%08X -> %08X", before.pid, F.r32(d.slot())))
  F.check(tag .. ": refused: the party and the PC are unchanged",
    partyPids() == before.party and boxCount() == before.boxes,
    string.format("party=%d boxes=%d", partyCount(), boxCount()))
  F.check(tag .. ": control returns on the field", back and fieldFree(), where())

  -- Control, and an empty Day Care for the next counter (Route 117, Four Island and Route 34
  -- share SaveBlock1.daycare): with room in the party the same answers take the Pokemon back.
  debugAction({ 2, 8 }, "clear_party")
  giveMon(SPECIES_PIDGEY, 10)
  if not goTo(d) then return end
  talkTo()
  local _, back2, prompts2 = converse({ answers = d.answers })
  F.check(tag .. ": with room, the same answers take the Pokemon back for a fee",
    back2 and F.r32(d.slot()) == 0 and partyCount() == 2 and F.r32(partyAddr(1)) == before.pid and F.money() < WALLET,
    string.format("prompts %s daycare=%08X party=%d money=%d", table.concat(prompts2, " "), F.r32(d.slot()), partyCount(), F.money()))
end

F.run(function()
  if not F.boot(HUB_GROUP) then F.check("boot", false); F.finish(); return end
  instantText()
  for _, d in ipairs(DAYCARES) do
    if not ONLY or d.tag:find(ONLY, 1, true) then
      F.L("== " .. d.tag .. " ==")
      local okRun, e = pcall(run, d)
      if not okRun then F.check(d.tag .. ": ran without a Lua error", false, tostring(e)) end
    end
  end
  F.finish()
end)
