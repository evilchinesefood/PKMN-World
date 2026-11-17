-- Full storage at harvest and gift time. Berry trees in all three regions (Hoenn Route 117's Wepear,
-- Kanto Route 11's Persim, Johto Route 30's Lum) with a full Berries pocket: the debug Fill Pocket
-- Berries leaves 46 stacks of 999, so first the tree's own Berry is a full stack, then its slot holds
-- a Berry the tree does not grow (the pocket has no slot for it). Picking must be refused with the
-- pocket-full line: the Bag and the tree unchanged. With the tree's stack at 990 (control) the
-- harvest must add the Berries and empty the tree. Then Lanette's Lotad Doll on Route 114 with every
-- decoration category full: refused with the no-room line, no doll and no received flag, and after a
-- doll slot is freed the second visit gives it.
--
-- The trees are talked to and answered with real input; the full pocket and the full decoration PC
-- are setup (debug fill, and the decoration arrays written the way DecorationAdd leaves them).
-- PW_FULL_ONLY=<text> runs matching scenarios.
local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "BerryDecorFull")

local HUB_GROUP = 100
local ONLY = os.getenv("PW_FULL_ONLY")
local CONTEXT_SHUTDOWN = 2
local CONTEXT_RUNNING = 0
local PARTY_SIZE = 6
local SPECIES_RATTATA, SPECIES_PIDGEY = 19, 16
local MOVE_TACKLE = 33
local BOXES, PER_BOX = 14, 30
local WALLET = 50000
local POCKET_BERRIES, BERRIES_SLOTS = 3, 46
local ITEM_ROWAP_BERRY = 578
local BERRY_TREE_SIZE = 8
local DECORCAT_COUNT, DECORCAT_DOLL = 8, 6
local DECOR_LOTAD_DOLL = 99
local FILL_DECOR = { 1, 10, 19, 25, 60, 66, 76, 101 }   -- one decoration of each category
local FLAG_RECEIVED_DOLL_LANETTE, FLAG_HIDE_LANETTES_HOUSE_LANETTE = 0x83, 0x366

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

local function instantText()
  local a = F.sb2() + S.SaveBlock2.optionsU16
  F.w16(a, (F.r16(a) & ~7) | 3)
end

-- ---- driving a conversation -------------------------------------------------------------------
-- Advance the running script with A, answering each Yes/No or multichoice from o.answers in order
-- ("yes", "no", or a multichoice row; a missing answer is B). o.onPrompt(i) runs before prompt i is
-- answered, o.stop() ends the drive early (a party menu taking over), o.shot names a screenshot of
-- each reply. Returns the answers used, whether the field came back, and the prompts seen.
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

local function goTo(sink)
  local last = sink.path[#sink.path]
  local x, y = F.pos()
  if F.grp() == sink.g and F.mapn() == sink.m and x == last[1] and y == last[2] then
    if sink.face then F.face(sink.face) end
    return true
  end
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


local function flag(id, on)
  local a, m = F.sb1() + S.SaveBlock1.flags + (id // 8), 1 << (id % 8)
  if on == nil then return (F.r8(a) & m) ~= 0 end
  F.w8(a, on and (F.r8(a) | m) or (F.r8(a) & ~m & 0xFF))
end
local function key16() return F.r32(F.sb2() + S.SaveBlock2.encryptionKey) & 0xFFFF end
local function berrySlots()
  local ptr, t = F.r32(S.gBagPockets + POCKET_BERRIES * S.BagPocket.stride), {}
  for s = 0, F.pocketCap(POCKET_BERRIES) - 1 do
    t[#t + 1] = { addr = ptr + s * 4, id = F.r16(ptr + s * 4), qty = F.r16(ptr + s * 4 + 2) ~ key16() }
  end
  return t
end
local function pocketSig()
  local parts, used = {}, 0
  for _, s in ipairs(berrySlots()) do
    if s.id ~= 0 then used = used + 1 end
    parts[#parts + 1] = s.id .. ":" .. s.qty
  end
  return table.concat(parts, ","), used
end
local function slotOf(item)
  for _, s in ipairs(berrySlots()) do if s.id == item then return s end end
end
local function setSlot(s, id, q) F.w16(s.addr, id); F.w16(s.addr + 2, q ~ key16()) end
local function treeAddr(id) return F.sb1() + S.SaveBlock1.berryTrees + id * BERRY_TREE_SIZE end
-- Berry, stage and count. Talking to a tree clears its sparkle bit (stopGrowth) by design.
local function treeSig(id)
  local a = treeAddr(id)
  return string.format("berry=%d stage=%d count=%d", F.r8(a) & 0x7F, F.r8(a + 1) & 7, F.r8(a + 4) & 0x1F)
end
local function treeBerries(id) return F.r8(treeAddr(id) + 4) & 0x1F end
local function treeStage(id) return F.r8(treeAddr(id) + 1) & 7 end

local function decorCat(c)
  local a = S.gDecorationInventories + c * 8
  return F.r32(a), F.r8(a + 4)
end
local function fillDecorations()
  for c = 0, DECORCAT_COUNT - 1 do
    local items, size = decorCat(c)
    for i = 0, size - 1 do F.w8(items + i, FILL_DECOR[c + 1]) end
  end
end
local function countDecor(id)
  local n = 0
  for c = 0, DECORCAT_COUNT - 1 do
    local items, size = decorCat(c)
    for i = 0, size - 1 do if F.r8(items + i) == id then n = n + 1 end end
  end
  return n
end
local function decorFull()
  for c = 0, DECORCAT_COUNT - 1 do
    local items, size = decorCat(c)
    for i = 0, size - 1 do if F.r8(items + i) == 0 then return false end end
  end
  return true
end

local function talkTo()
  for _ = 1, 5 do
    F.idle(30); F.press("A", 2); F.idle(20)
    if not fieldFree() then return true end
  end
  return false
end

local TREES = {
  { tag = "hoenn route117 wepear", warp = { 0, 0, 0, 0, 3, 2, 0, 0, 0 }, g = 0, m = 32,
    path = { { 51, 8 }, { 48, 8 }, { 48, 15 }, { 42, 15 }, { 42, 14 } }, face = "Up", tree = 28, item = 532 },
  { tag = "kanto route11 persim", warp = { 0, 3, 7, 0, 2, 9, 0, 0, 0 }, g = 37, m = 29,
    path = { { 6, 8 }, { 11, 8 } }, face = "Up", tree = 108, item = 521 },
  { tag = "johto route30 lum", warp = { 0, 7, 5, 0, 0, 3, 0, 0, 0 }, g = 75, m = 3,
    path = { { 26, 40 }, { 23, 40 }, { 23, 39 } }, face = "Up", tree = 100, item = 522 },
}

local function pick(t, label, expectHarvest)
  local tag = t.tag .. ": " .. label
  local sig0, used0 = pocketSig()
  local tree0, yield = treeSig(t.tree), treeBerries(t.tree)
  local s0 = slotOf(t.item)
  local q0 = s0 and s0.qty or 0
  if not goTo(t) then F.check(tag .. ": reached the tree", false, where()); return end
  F.check(tag .. ": the tree answers", talkTo(), where())
  local _, back, prompts = converse({ answers = { "yes" }, shot = (t.tag .. "_" .. label):gsub("%W", "_") })
  local sig1 = pocketSig()
  local s1 = slotOf(t.item)
  if expectHarvest then
    F.check(tag .. ": the Berries went into the Bag and the tree was picked",
      s1 ~= nil and s1.qty == q0 + yield and treeBerries(t.tree) == 0,
      string.format("qty %d -> %s (yield %d) tree %s -> %s", q0, s1 and s1.qty or "-", yield, tree0, treeSig(t.tree)))
  else
    F.check(tag .. ": refused: the Bag and the tree are unchanged", sig1 == sig0 and treeSig(t.tree) == tree0,
      string.format("tree %s -> %s, pocket %d slots, prompts %s", tree0, treeSig(t.tree), used0, table.concat(prompts, " ")))
  end
  F.check(tag .. ": control returns on the field", back and fieldFree(), where())
end

local function tree(t)
  F.L(string.format("  %s: tree %d stage %d holds %d", t.tag, t.tree, treeStage(t.tree), treeBerries(t.tree)))
  F.check(t.tag .. ": the tree has Berries to pick", treeBerries(t.tree) > 0, treeSig(t.tree))
  local s = slotOf(t.item)
  F.check(t.tag .. ": the pocket is full and holds 999 of the tree's Berry",
    select(2, pocketSig()) == BERRIES_SLOTS and s ~= nil and s.qty == 999, s and ("qty " .. s.qty) or "no slot")
  if not s then return end
  pick(t, "full stack", false)
  setSlot(slotOf(t.item), ITEM_ROWAP_BERRY, 999)
  pick(t, "no slot for it", false)
  setSlot(slotOf(ITEM_ROWAP_BERRY), t.item, 990)
  pick(t, "room in the stack", true)
  local s2 = slotOf(t.item)
  if s2 then setSlot(s2, t.item, 999) end
end

local function lanette()
  local tag = "lanette's lotad doll"
  local L = { tag = tag, warp = { 0, 2, 0, 0, 0, 2, 0, 0, 0 }, g = 20, m = 2, path = { { 5, 5 } }, face = "Up" }
  fillDecorations()
  flag(FLAG_HIDE_LANETTES_HOUSE_LANETTE, false)
  F.check(tag .. ": every decoration category is full", decorFull())
  local dolls0 = countDecor(DECOR_LOTAD_DOLL)
  if not goTo(L) then F.check(tag .. ": reached Lanette", false, where()); return end
  F.check(tag .. ": Lanette answers", talkTo(), where())
  for k = 1, 6 do F.idle(50); if fieldFree() then break end F.shot("lanette_full_" .. k); F.press("A", 2) end
  local _, back = converse({})
  F.check(tag .. ": refused: no doll and no received flag", countDecor(DECOR_LOTAD_DOLL) == dolls0
    and not flag(FLAG_RECEIVED_DOLL_LANETTE) and decorFull(), string.format("dolls %d flag %s", countDecor(DECOR_LOTAD_DOLL), tostring(flag(FLAG_RECEIVED_DOLL_LANETTE))))
  F.check(tag .. ": control returns on the field", back and fieldFree(), where())
  local items, size = decorCat(DECORCAT_DOLL)
  F.w8(items + size - 1, 0)
  F.check(tag .. ": Lanette answers again", talkTo(), where())
  local _, back2 = converse({ shot = "lanette_room" })
  F.check(tag .. ": with a doll slot free, the second visit gives the doll and sets the flag",
    countDecor(DECOR_LOTAD_DOLL) == dolls0 + 1 and flag(FLAG_RECEIVED_DOLL_LANETTE),
    string.format("dolls %d flag %s", countDecor(DECOR_LOTAD_DOLL), tostring(flag(FLAG_RECEIVED_DOLL_LANETTE))))
  F.check(tag .. ": control returns after the gift", back2 and fieldFree(), where())
end

F.run(function()
  if not F.boot(HUB_GROUP) then F.check("boot", false); F.finish(); return end
  instantText()
  giveMon(SPECIES_PIDGEY, 10)
  F.check("setup: debug Fill Pocket Berries ran", debugAction({ 1, 1, 6 }, "fill_berries")
    and select(2, pocketSig()) == BERRIES_SLOTS, "slots " .. select(2, pocketSig()))
  for _, t in ipairs(TREES) do
    if not ONLY or t.tag:find(ONLY, 1, true) then
      F.L("== " .. t.tag .. " ==")
      local ok, e = pcall(tree, t)
      if not ok then F.check(t.tag .. ": ran without a Lua error", false, tostring(e)) end
    end
  end
  if not ONLY or ("lanette"):find(ONLY, 1, true) then
    F.L("== lanette ==")
    local ok, e = pcall(lanette)
    if not ok then F.check("lanette: ran without a Lua error", false, tostring(e)) end
  end
  F.finish()
end)
