-- Script money sinks at the wallet's edges. For each sink the wallet is set to 0, one short of the
-- price and exactly the price (plus a comfortable amount where it is cheap), then the purchase runs
-- through the real script with real input: walking, talking, Yes/No and menus. Short wallets must
-- be refused with the money unchanged and nothing handed over; the exact wallet must end at 0 with
-- the purchase delivered once. Money, items, Pokemon and Safari state are read from RAM.
--
-- Run via test/overworld/mgba-run.sh test/overworld/lua/MoneySinkEdges.lua <rom>
-- PW_SINK_ONLY=<text> (runner --env) runs only the sinks whose tag contains <text>.

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "MoneySinkEdges")

local HUB_GROUP = 100
local ONLY = os.getenv("PW_SINK_ONLY")
local CONTEXT_SHUTDOWN = 2

local SPECIES_RATTATA, SPECIES_MAGIKARP = 19, 129
local FLAG_BOUGHT_MAGIKARP = 0xA40 + 0x249
local FLAG_SYS_SAFARI_MODE = 0x948 + 0x2C
local VAR_SAFARI_ZONE_STATE = 0x40A4
local VAR_KANTO_SAFARI_SCENE = 0xA000 + 0x47
local SAFARI_BALLS = 30
local ITEM_FRESH_WATER, ITEM_SODA_POP, ITEM_LEMONADE, ITEM_MOOMOO_MILK = 35, 36, 37, 38
local ITEM_RAGE_CANDY_BAR, ITEM_LAVA_COOKIE = 58, 59
local ITEM_POKEBLOCK_CASE = 722
local FLAG_RECEIVED_6_SODA_POP, FLAG_DELIVERED_DEVON_GOODS = 0x8C, 0x95
local FLAG_HIDE_MT_CHIMNEY_TEAM_AQUA, FLAG_HIDE_MT_CHIMNEY_TEAM_MAGMA = 0x39E, 0x39F
local FLAG_HIDE_MT_CHIMNEY_LAVA_COOKIE_LADY = 0x3E2
local FLAG_GOT_COIN_CASE = 0xA40 + 0x243
local VAR_SLATEPORT_MUSEUM_1F_STATE = 0x40AA
local VAR_MAP_SCENE_PEWTER_CITY_MUSEUM_1F = 0xA000 + 0x3A
local VAR_TRAINER_CARD_MON_ICON_TINT_IDX, VAR_TRAINER_CARD_MON_ICON_1 = 0xA000 + 0x1D, 0xA000 + 0x1E
local MON_ICON_TINT_BLACK = 1
local VAR_MAHOGANY_TOWN_STATE, VAR_ROUTE39_BARN = 0xA080 + 0x11, 0xA080 + 0x23
local ROW_GIVE, ROW_MON_BASIC = 3, 1
local DAYCARE_MON_SIZE = 140       -- struct DaycareMon
local DAYCARE_STEPS = 136          -- DaycareMon.steps
-- The Day Care asks 100 plus 100 per level its Pokemon gained, and each step adds one Exp. The
-- Rattata are Medium Fast (level L needs L^3 Exp), so the fee is modelled here from the deposited
-- Pokemon's own Exp and step count, and the walk goes on until that model asks at least 400.
local DAYCARE_MIN_FEE, DAYCARE_MAX_STEPS = 400, 600

-- ---- RAM ------------------------------------------------------------------------------------
local function key32() return F.r32(F.sb2() + S.SaveBlock2.encryptionKey) end
local function setMoney(v) F.w32(F.sb1() + S.SaveBlock1.money, v ~ key32()) end
local function flag(id, on)
  local a, m = F.sb1() + S.SaveBlock1.flags + (id // 8), 1 << (id % 8)
  if on == nil then return (F.r8(a) & m) ~= 0 end
  F.w8(a, on and (F.r8(a) | m) or (F.r8(a) & ~m & 0xFF))
end
local function key16() return key32() & 0xFFFF end
local function varAddr(id)
  if id >= 0xA000 then return F.sb3() + S.SaveBlock3.regionVars + (id - 0xA000) * 2 end
  return F.sb1() + S.SaveBlock1.vars + (id - 0x4000) * 2
end
local function setVar(id, v) F.w16(varAddr(id), v) end
local function getVar(id) return F.r16(varAddr(id)) end
local function coins() return F.r16(F.sb1() + S.SaveBlock1.coins) ~ key16() end
local function setCoins(v) F.w16(F.sb1() + S.SaveBlock1.coins, v ~ key16()) end

-- Total quantity of an item across the bag pockets (quantities are XORed with the key).
local function qty(id)
  local n = 0
  for p = 0, 4 do
    local ptr = F.r32(S.gBagPockets + p * S.BagPocket.stride)
    if ptr >= 0x02000000 and ptr < 0x02040000 then
      for slot = 0, F.pocketCap(p) - 1 do
        if F.r16(ptr + slot * 4) == id then n = n + (F.r16(ptr + slot * 4 + 2) ~ key16()) end
      end
    end
  end
  return n
end

local function giveKeyItem(id)
  local ptr = F.r32(S.gBagPockets + 4 * S.BagPocket.stride)
  for slot = 0, F.pocketCap(4) - 1 do if F.r16(ptr + slot * 4) == id then return true end end
  for slot = 0, F.pocketCap(4) - 1 do
    if F.r16(ptr + slot * 4) == 0 then F.w16(ptr + slot * 4, id); F.w16(ptr + slot * 4 + 2, 1 ~ key16()); return true end
  end
  return false
end

local function partyCount() return F.r8(S.gPartiesCount) end
local function partyAddr(i) return S.gParties + i * S.Pokemon.size end

-- Species of a (Box)Pokemon at address b: the growth substruct's first word, decrypted.
local function speciesAt(b)
  local pid = F.r32(b)
  if pid == 0 and F.r32(b + 4) == 0 then return 0 end
  local k = pid ~ F.r32(b + 4)
  return (F.r32(b + 32 + F.r8(S.sSubstructOffsets + pid % 24) * 12) ~ k) & 0x7FF
end

local function expAt(b)
  local pid = F.r32(b)
  local k = pid ~ F.r32(b + 4)
  return (F.r32(b + 32 + F.r8(S.sSubstructOffsets + pid % 24) * 12 + 4) ~ k) & 0x1FFFFF
end

local function mediumFastLevel(exp)
  local l = 1
  while l < 100 and (l + 1) ^ 3 <= exp do l = l + 1 end
  return l
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
local function state() return string.format("money=%d at %s party=%d", F.money(), where(), partyCount()) end

-- The game's charset: digits are 0xA1..0xAA, EOS is 0xFF.
local function decodeNumber(a)
  local n, any = 0, false
  for i = 0, 10 do
    local b = F.r8(a + i)
    if b == 0xFF then break end
    if b >= 0xA1 and b <= 0xAA then n = n * 10 + (b - 0xA1); any = true end
  end
  return any and n or nil
end

-- gLocalTime = sRtc - localTimeOffset, so winding the offset forward winds the clock back.
local function setClock(hour)
  local off = F.sb2() + S.SaveBlock2.localTimeOffset
  local h, m = F.rs8(S.gLocalTime + S.Time.hours), F.rs8(S.gLocalTime + S.Time.minutes)
  local delta = ((h * 60 + m) - hour * 60) % (24 * 60)
  local newMin = F.rs8(off + S.Time.minutes) + delta % 60
  local carry = 0
  if newMin >= 60 then newMin, carry = newMin - 60, 1 end
  F.w8(off + S.Time.minutes, newMin)
  F.w8(off + S.Time.hours, (F.rs8(off + S.Time.hours) + delta // 60 + carry) % 24)
  F.w8(S.sHoursOverride, 0)
end

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

-- ---- movement ---------------------------------------------------------------------------------
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

-- ---- sinks -------------------------------------------------------------------------------------
-- A sink knows how to reach its counter, how to start the purchase, which answers buy it, and how
-- to read what it delivers. `snap()` returns a table of observations; `delivered(before, after)`
-- says how many units the purchase handed over (0 = nothing), and `ready()` restores any one-time
-- state so the next wallet case starts from the same place.

local SINKS = {}

local function tapDown(n) for _ = 1, n do F.press("Down", 3); F.idle(16) end end

-- Debug Give Pokemon (basic): species spinner from 1, level spinner from 1 (plus 10 x tens).
local function giveMon(sp, tens)
  F.dbg(); F.idle(60)
  tapDown(ROW_GIVE); F.press("A", 3); F.idle(50)
  tapDown(ROW_MON_BASIC); F.press("A", 3); F.idle(40)
  F.press("Right", 2); F.idle(10)
  for _ = 1, (sp // 10) % 10 do F.press("Up", 2); F.idle(8) end
  F.press("Left", 2); F.idle(10)
  for _ = 1, sp % 10 - 1 do F.press("Up", 2); F.idle(8) end
  F.press("A", 3); F.idle(30)
  if tens then
    F.press("Right", 2); F.idle(10)
    for _ = 1, tens do F.press("Up", 2); F.idle(8) end
  end
  F.press("A", 3); F.idle(80)
  for _ = 1, 10 do F.press("B", 3); F.idle(20) end
end

local function leftField() return not F.ow() end

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

local function dayCareSlot() return F.sb1() + S.SaveBlock1.daycare end
local function route5Slot() return F.sb3() + S.SaveBlock3.route5DayCareMon end
local function dayCareSlot2() return dayCareSlot() + DAYCARE_MON_SIZE end

local function daycareSteps(slot) return F.r32(slot + DAYCARE_STEPS) end
local function modelFeeAt(slot)
  local exp = expAt(slot)
  return 100 + 100 * (mediumFastLevel(exp + daycareSteps(slot)) - mediumFastLevel(exp))
end

-- A Day Care counter. `slot()` is the DaycareMon the withdrawal empties; `quote` is the prompt
-- that shows the fee (GetDaycareCostAndPrepareString has just filled VAR_0x8005 and STR_VAR_2).
-- prepare() deposits through the real deposit script and picker (the last party slot, and with
-- d.second a second Pokemon after "raise one more?" Yes), walks until the fee model asks enough,
-- then asks the fee once and declines, so every wallet case is priced by the game.
local function dayCare(d)
  local sink = d
  local function pid() return F.r32(sink.slot()) end
  local function seeFee(i)
    if i == sink.quote then
      sink.seen = { var = F.r16(S.gSpecialVar_0x8005), shown = decodeNumber(S.gStringVar2), model = modelFeeAt(sink.slot()) }
    end
  end
  sink.onPrompt = seeFee
  sink.snap = function()
    local n, has = partyCount(), false
    for i = 0, n - 1 do if F.r32(partyAddr(i)) == sink.pid then has = true end end
    return { n = n, has = has, kept = pid() }
  end
  sink.delivered = function(b, a)
    if a.n == b.n + 1 and a.has and not b.has and a.kept == 0 and b.kept == sink.pid then return 1 end
    if a.n == b.n and not a.has and a.kept == sink.pid then return 0 end
    return -1
  end
  sink.describe = function(snap) return string.format("party=%d withdrawn=%s daycare=%08X", snap.n, tostring(snap.has), snap.kept) end
  sink.ready = function() sink.seen = nil end
  sink.prepare = function()
    local shotTag = sink.tag:gsub("%W", "_")
    -- The second slot's case brings its own pair: a level 11 Rattata for the second slot and a
    -- level 1 Rattata (deposited first) for the first. Walking levels the young one up while the
    -- level 11 one stays put, so the second slot asks less than the first.
    if d.second then giveMon(SPECIES_RATTATA, 1); giveMon(SPECIES_RATTATA) end
    local n = partyCount()
    local before = {}
    for i = 0, n - 1 do before[F.r32(partyAddr(i))] = i end
    local ok, err = goTo(sink)
    if not ok then F.L("  " .. err); return false end
    F.press("A", 2)
    converse({ answers = { "yes" }, stop = leftField })
    if not depositPick(n - 1, shotTag) then return false end
    if d.second then
      converse({ answers = { "yes" }, stop = leftField })
      if not depositPick(partyCount() - 1, shotTag .. "_2") then return false end
    end
    converse({})
    sink.pid = pid()
    local deposits = d.second and 2 or 1
    F.L(string.format("  %s: the withdrawn slot holds party slot %s (%08X)", sink.tag, tostring(before[sink.pid]), sink.pid))
    if not F.check(sink.tag .. ": the deposit took the party Pokemon", before[sink.pid] ~= nil and partyCount() == n - deposits,
      string.format("daycare=%08X party=%d", sink.pid, partyCount())) then return false end
    F.check(sink.tag .. ": the Day Care holds a Rattata", speciesAt(sink.slot()) == SPECIES_RATTATA,
      "species=" .. speciesAt(sink.slot()))
    local function enough()
      if d.second then return modelFeeAt(dayCareSlot()) >= modelFeeAt(dayCareSlot2()) + 200 end
      return modelFeeAt(sink.slot()) >= DAYCARE_MIN_FEE
    end
    local dir = sink.walkDir
    for _ = 1, DAYCARE_MAX_STEPS do
      if enough() or not F.step(dir) then break end
      dir = BACK[dir]
    end
    F.L(string.format("  %s: %d steps on %d Exp", sink.tag, daycareSteps(sink.slot()), expAt(sink.slot())))
    if d.second then
      F.check(sink.tag .. ": the second slot asks less than the first", enough(),
        string.format("first=%d second=%d", modelFeeAt(dayCareSlot()), modelFeeAt(dayCareSlot2())))
    end
    if not goTo(sink) then return false end
    F.press("A", 2)
    sink.seen = nil
    converse({ answers = sink.quoteAnswers, onPrompt = seeFee })
    local seen = sink.seen or {}
    F.check(sink.tag .. ": the fee asked is 100 plus 100 per level gained", seen.var ~= nil and seen.var == seen.model
      and (d.second or seen.var >= DAYCARE_MIN_FEE), string.format("VAR_0x8005=%s model=%s steps=%d exp=%d",
      tostring(seen.var), tostring(seen.model), daycareSteps(sink.slot()), expAt(sink.slot())))
    F.check(sink.tag .. ": the message shows the fee it charges", seen.shown == seen.var,
      string.format("shown=%s var=%s", tostring(seen.shown), tostring(seen.var)))
    sink.price = seen.var or DAYCARE_MIN_FEE
    return pid() == sink.pid
  end
  return sink
end

-- Deposit and withdrawal answers: "Raise one more?" No, "Take your Pokemon back?" Yes, then the
-- fee. Route 5's man asks only the fee.
SINKS[#SINKS + 1] = dayCare({
  tag = "daycare route117", warp = { 0, 2, 2, 0, 0, 0, 0, 0, 0 }, g = 22, m = 0,
  path = { { 2, 4 } }, face = "Up", walkDir = "Right", slot = dayCareSlot,
  quote = 3, quoteAnswers = { "no", "yes", "no" }, answers = { "no", "yes", "yes" },
})
SINKS[#SINKS + 1] = dayCare({
  tag = "daycare route5", warp = { 0, 5, 1, 0, 0, 0, 0, 0, 0 }, g = 51, m = 0,
  path = { { 4, 7 }, { 4, 5 } }, face = "Up", walkDir = "Right", slot = route5Slot,
  quote = 1, quoteAnswers = { "no" }, answers = { "yes" },
})
SINKS[#SINKS + 1] = dayCare({
  tag = "daycare fourisland", warp = { 0, 6, 7, 0, 0, 0, 0, 0, 0 }, g = 67, m = 0,
  path = { { 2, 7 }, { 2, 4 } }, face = "Up", walkDir = "Right", slot = dayCareSlot,
  quote = 3, quoteAnswers = { "no", "yes", "no" }, answers = { "no", "yes", "yes" },
})
SINKS[#SINKS + 1] = dayCare({
  tag = "daycare route34", warp = { 0, 8, 1, 0, 0, 5, 0, 0, 0 }, g = 81, m = 5,
  path = { { 3, 4 }, { 3, 6 } }, face = "Down", walkDir = "Right", slot = dayCareSlot,
  quote = 3, quoteAnswers = { "no", "yes", "no" }, answers = { "no", "yes", "yes" },
})
-- Two Pokemon in the Route 117 Day Care: "Take your Pokemon back?" Yes, the level menu's second
-- row, then the fee. The second slot asks less than the first, so a fee checked, charged or
-- delivered for the wrong slot fails. After the sale the lady offers the other one: No.
SINKS[#SINKS + 1] = dayCare({
  tag = "daycare route117 second slot", warp = { 0, 2, 2, 0, 0, 0, 0, 0, 0 }, g = 22, m = 0,
  path = { { 2, 4 } }, face = "Up", walkDir = "Right", slot = dayCareSlot2, second = true,
  quote = 3, quoteAnswers = { "yes", 1, "no" }, answers = { "yes", 1, "yes" },
})

SINKS[#SINKS + 1] = {
  tag = "magikarp", price = 500, comfortable = 2000,
  warp = { 0, 5, 0, 0, 0, 0, 0, 0, 0 }, g = 50, m = 0,
  path = { { 1, 8 }, { 1, 4 } }, face = "Up",
  answers = { "yes", "no" },
  snap = function()
    local n = partyCount()
    return { n = n, last = n > 0 and speciesAt(partyAddr(n - 1)) or 0, flag = flag(FLAG_BOUGHT_MAGIKARP) }
  end,
  delivered = function(b, a)
    if a.n == b.n + 1 and a.last == SPECIES_MAGIKARP and a.flag then return 1 end
    if a.n == b.n and a.flag == b.flag then return 0 end
    return -1
  end,
  describe = function(s) return string.format("party=%d last=%d bought=%s", s.n, s.last, tostring(s.flag)) end,
  ready = function() flag(FLAG_BOUGHT_MAGIKARP, false) end,
}

-- Safari Zone counters: stepping onto the counter tile runs the entry script. Delivery is Safari
-- mode with 30 Safari Balls and the player inside the zone; cleanup() ends the game the way
-- ExitSafariMode does and clears the zone's scene var so the next sink starts outside.
local function safari(z)
  local sink = z
  sink.price = 500
  sink.answers = { "yes" }
  sink.start = function() F.step(z.trigger) end
  sink.snap = function()
    return { on = flag(FLAG_SYS_SAFARI_MODE), balls = F.r8(S.gNumSafariBalls), g = F.grp(), m = F.mapn() }
  end
  sink.delivered = function(b, a)
    if a.on and not b.on and a.balls == SAFARI_BALLS and a.g == z.zoneG and a.m == z.zoneM then return 1 end
    if not a.on and a.g == z.g and a.m == z.m then return 0 end
    return -1
  end
  sink.describe = function(s) return string.format("safari=%s balls=%d map=%d/%d", tostring(s.on), s.balls, s.g, s.m) end
  sink.ready = function() end
  sink.cleanup = function()
    flag(FLAG_SYS_SAFARI_MODE, false)
    F.w8(S.gNumSafariBalls, 0)
    F.w16(S.gSafariZoneStepCounter, 0)
    setVar(VAR_SAFARI_ZONE_STATE, 0)
    setVar(VAR_KANTO_SAFARI_SCENE, 0)
  end
  return sink
end

SINKS[#SINKS + 1] = safari({
  tag = "safari kanto", warp = { 0, 4, 5, 0, 0, 0, 0, 0, 2 }, g = 45, m = 0, zoneG = 35, zoneM = 63,
  path = { { 4, 4 } }, trigger = "Up",
})
SINKS[#SINKS + 1] = safari({
  tag = "safari hoenn", warp = { 0, 2, 3, 0, 0, 0, 0, 0, 2 }, g = 23, m = 0, zoneG = 26, zoneM = 3,
  path = { { 14, 4 }, { 9, 4 } }, trigger = "Left",
})
SINKS[#SINKS + 1] = safari({
  tag = "safari johto", warp = { 0, 9, 6, 0, 0, 2, 0, 0, 1 }, g = 96, m = 2, zoneG = 96, zoneM = 4,
  path = { { 9, 3 } }, trigger = "Up",
})

-- Vending machines: the drink row is picked from the multichoice, and the check and the charge
-- are each chosen by a call_if on that row. After a sale the menu reopens; B leaves it. Lilycove
-- drops a free extra can 1 time in 64, so delivery counts the chosen drink rising at all while the
-- charge must still be exactly one price.
local DRINKS = {
  { name = "freshwater", item = ITEM_FRESH_WATER, price = 200, row = 0 },
  { name = "sodapop", item = ITEM_SODA_POP, price = 300, row = 1 },
  { name = "lemonade", item = ITEM_LEMONADE, price = 350, row = 2 },
}
local function vending(v, drink)
  local sink = {
    tag = "vending " .. v.name .. " " .. drink.name, price = drink.price,
    warp = v.warp, g = v.g, m = v.m, path = v.path, face = "Up", answers = { drink.row },
  }
  sink.snap = function()
    local t = {}
    for _, d in ipairs(DRINKS) do t[d.item] = qty(d.item) end
    return t
  end
  sink.delivered = function(b, a)
    for _, d in ipairs(DRINKS) do
      if d.item ~= drink.item and a[d.item] ~= b[d.item] then return -1 end
    end
    if a[drink.item] > b[drink.item] then return 1 end
    if a[drink.item] == b[drink.item] then return 0 end
    return -1
  end
  sink.describe = function(s)
    return string.format("water=%d soda=%d lemonade=%d", s[ITEM_FRESH_WATER], s[ITEM_SODA_POP], s[ITEM_LEMONADE])
  end
  sink.ready = function() end
  return sink
end
for _, d in ipairs(DRINKS) do
  SINKS[#SINKS + 1] = vending({ name = "lilycove", warp = { 0, 1, 3, 0, 2, 1, 0, 0, 0 }, g = 13, m = 21,
    path = { { 10, 4 }, { 10, 2 } } }, d)
end
for _, d in ipairs(DRINKS) do
  SINKS[#SINKS + 1] = vending({ name = "celadon", warp = { 0, 4, 4, 0, 0, 5, 0, 0, 0 }, g = 44, m = 5,
    path = { { 11, 6 }, { 11, 4 } } }, d)
end

-- A counter whose sale leaves one reading (an item count, a var, coins) rising by `unit`.
-- ready() seeds the story state the counter needs, the way the game's own scripts leave it.
local function counter(c)
  local sink = c
  sink.snap = function() return { v = c.read() } end
  sink.delivered = function(b, a)
    if a.v == b.v + c.unit then return 1 end
    if a.v == b.v then return 0 end
    return -1
  end
  sink.describe = function(snap) return c.what .. "=" .. tostring(snap.v) end
  sink.ready = c.ready or function() end
  return sink
end

SINKS[#SINKS + 1] = counter({
  tag = "seashore sodapop", price = 300, comfortable = 1000, what = "sodapop", unit = 1,
  warp = { 0, 2, 8, 0, 0, 0, 0, 0, 0 }, g = 28, m = 0, path = { { 6, 3 } }, face = "Up",
  answers = { "yes" }, read = function() return qty(ITEM_SODA_POP) end,
  ready = function() flag(FLAG_RECEIVED_6_SODA_POP, true) end,
})
-- After the Mt. Chimney story: both teams gone, the cookie lady out.
SINKS[#SINKS + 1] = counter({
  tag = "mtchimney lavacookie", price = 200, comfortable = 1000, what = "lavacookie", unit = 1,
  warp = { 0, 2, 4, 0, 1, 2, 0, 0, 0 }, g = 24, m = 12, path = { { 20, 37 }, { 20, 39 } }, face = "Left",
  answers = { "yes" }, read = function() return qty(ITEM_LAVA_COOKIE) end,
  ready = function()
    flag(FLAG_HIDE_MT_CHIMNEY_TEAM_AQUA, true); flag(FLAG_HIDE_MT_CHIMNEY_TEAM_MAGMA, true)
    flag(FLAG_HIDE_MT_CHIMNEY_LAVA_COOKIE_LADY, false)
  end,
})
-- Before the Devon Goods are delivered a short wallet is waved in to catch up with the tour, so
-- the edges are tested after delivery.
SINKS[#SINKS + 1] = counter({
  tag = "museum slateport", price = 50, what = "museum1F", unit = 1,
  warp = { 0, 0, 9, 0, 0, 7, 0, 0, 0 }, g = 9, m = 7, path = { { 9, 8 } },
  start = function() F.step("Up") end, answers = { "yes" },
  read = function() return getVar(VAR_SLATEPORT_MUSEUM_1F_STATE) end,
  ready = function() flag(FLAG_DELIVERED_DEVON_GOODS, true); setVar(VAR_SLATEPORT_MUSEUM_1F_STATE, 0) end,
})
SINKS[#SINKS + 1] = counter({
  tag = "museum pewter", price = 50, what = "museumScene", unit = 1,
  warp = { 0, 4, 0, 0, 0, 0, 0, 0, 0 }, g = 40, m = 0, path = { { 13, 6 } },
  start = function() F.step("Up") end, answers = { "yes" },
  read = function() return getVar(VAR_MAP_SCENE_PEWTER_CITY_MUSEUM_1F) end,
  ready = function() setVar(VAR_MAP_SCENE_PEWTER_CITY_MUSEUM_1F, 0) end,
})
-- The merchant sells when talked to, and while Mahogany's Rocket plot runs (state 1 to 16) he
-- also stops the player walking up his column.
SINKS[#SINKS + 1] = counter({
  tag = "mahogany ragecandybar talk", price = 300, comfortable = 1000, what = "ragecandybar", unit = 1,
  warp = { 0, 9, 1, 0, 0, 0, 0, 0, 2 }, g = 91, m = 0, path = { { 27, 12 }, { 30, 12 } }, face = "Up",
  answers = { "yes" }, read = function() return qty(ITEM_RAGE_CANDY_BAR) end,
  ready = function() setVar(VAR_MAHOGANY_TOWN_STATE, 0) end,
})
SINKS[#SINKS + 1] = counter({
  tag = "mahogany ragecandybar stop", price = 300, comfortable = 1000, what = "ragecandybar", unit = 1,
  warp = { 0, 9, 1, 0, 0, 0, 0, 0, 2 }, g = 91, m = 0, path = { { 27, 12 }, { 29, 12 } },
  start = function() F.step("Right") end,
  answers = { "yes" }, read = function() return qty(ITEM_RAGE_CANDY_BAR) end,
  ready = function() setVar(VAR_MAHOGANY_TOWN_STATE, 1) end,
  cleanup = function() setVar(VAR_MAHOGANY_TOWN_STATE, 0) end,
})
-- After a sale he offers another bottle: the exact wallet says Yes to it, so the second sale meets
-- an empty wallet inside the same conversation.
SINKS[#SINKS + 1] = counter({
  tag = "route39 moomoomilk", price = 500, what = "moomoomilk", unit = 1,
  warp = { 0, 8, 6, 0, 0, 9, 0, 0, 0 }, g = 86, m = 9, path = { { 4, 5 } }, face = "Up",
  answers = { "yes", "yes" }, read = function() return qty(ITEM_MOOMOO_MILK) end,
  ready = function() setVar(VAR_ROUTE39_BARN, 5) end,
})
-- Celadon Game Corner: the photo printer charges before the tint menu (B is ignored there), then
-- writes the party icons and the tint to the trainer card vars.
SINKS[#SINKS + 1] = counter({
  tag = "celadon photo", price = 50, comfortable = 1000, what = "photo", unit = 1,
  warp = { 0, 4, 4, 0, 1, 4, 0, 0, 0 }, g = 44, m = 14, path = { { 16, 13 } }, face = "Right",
  answers = { "yes", MON_ICON_TINT_BLACK },
  read = function()
    return (getVar(VAR_TRAINER_CARD_MON_ICON_1) ~= 0 and getVar(VAR_TRAINER_CARD_MON_ICON_TINT_IDX) == MON_ICON_TINT_BLACK) and 1 or 0
  end,
  ready = function() setVar(VAR_TRAINER_CARD_MON_ICON_1, 0); setVar(VAR_TRAINER_CARD_MON_ICON_TINT_IDX, 0) end,
})
for row, c in ipairs({ { 50, 1000 }, { 500, 10000 }, { 5000, 100000 } }) do
  SINKS[#SINKS + 1] = counter({
    tag = "celadon coins " .. c[1], price = c[2], what = "coins", unit = c[1],
    warp = { 0, 4, 4, 0, 1, 4, 0, 0, 0 }, g = 44, m = 14, path = { { 8, 13 }, { 8, 4 }, { 6, 4 } }, face = "Up",
    answers = { row - 1 }, read = coins,
    ready = function() flag(FLAG_GOT_COIN_CASE, true); setCoins(0) end,
  })
end

-- Goldenrod Underground haircut brothers. The older brother works by day, the younger by night
-- (the clock drives the Johto day/night hide flags on each map load). After Yes the party picker
-- opens; the sale is the daily flag plus the chosen Pokemon's friendship going up.
local FLAG_JOHTO_BASE = 0x6000
local function johtoFlag(id, on)
  local a, m = F.sb3() + S.SaveBlock3.johtoFlags + (id - FLAG_JOHTO_BASE) // 8, 1 << ((id - FLAG_JOHTO_BASE) % 8)
  if on == nil then return (F.r8(a) & m) ~= 0 end
  F.w8(a, on and (F.r8(a) | m) or (F.r8(a) & ~m & 0xFF))
end
local function friendshipAt(b)
  local pid = F.r32(b)
  local k = pid ~ F.r32(b + 4)
  return ((F.r32(b + 32 + F.r8(S.sSubstructOffsets + pid % 24) * 12 + 8) ~ k) >> 8) & 0xFF
end
local function partyFriendship()
  local t = 0
  for i = 0, partyCount() - 1 do t = t + friendshipAt(partyAddr(i)) end
  return t
end
local function haircut(h)
  local sink = h
  sink.answers = { "yes" }
  -- ChoosePartyMon opens the party menu on slot 1; A picks it.
  sink.picker = function()
    F.idle(200)
    F.shot(sink.tag:gsub("%W", "_") .. "_picker")
    F.press("A", 2); F.idle(150)
    F.shot(sink.tag:gsub("%W", "_") .. "_picked")
  end
  -- Each brother's map load must see his time of day, so leave the tunnel before setting the clock.
  sink.prepare = function()
    if F.grp() == h.g and F.mapn() == h.m and not F.warpTo(1, 0, 0, 0, 0, 0, 0, 0, 0, HUB_GROUP, 0, "hub") then
      return false
    end
    setClock(h.hour)
    return true
  end
  sink.snap = function() return { cut = johtoFlag(h.flag), love = partyFriendship() } end
  sink.delivered = function(b, a)
    if a.cut and not b.cut and a.love > b.love then return 1 end
    if a.cut == b.cut and a.love == b.love then return 0 end
    return -1
  end
  sink.describe = function(snap) return string.format("haircut=%s friendship=%d", tostring(snap.cut), snap.love) end
  sink.ready = function() johtoFlag(h.flag, false) end
  return sink
end
local function offWarp() local x, y = F.pos(); if x == 12 and y == 10 then F.step("Down") end end
SINKS[#SINKS + 1] = haircut({
  tag = "haircut older", price = 500, flag = FLAG_JOHTO_BASE + 0xC2, hour = 12,
  warp = { 0, 8, 4, 0, 2, 7, 0, 0, 2 }, g = 84, m = 27, path = { { 4, 12 }, { 4, 20 } }, face = "Right",
  arrive = offWarp,
})
SINKS[#SINKS + 1] = haircut({
  tag = "haircut younger", price = 300, flag = FLAG_JOHTO_BASE + 0xC3, hour = 22,
  warp = { 0, 8, 4, 0, 2, 7, 0, 0, 2 }, g = 84, m = 27, path = { { 4, 12 }, { 4, 16 } }, face = "Right",
  arrive = offWarp, cleanup = function() setClock(12) end,
})

-- ---- the edge cases ---------------------------------------------------------------------------
local function attempt(sink, wallet, shotTag)
  sink.ready()
  local ok, err = goTo(sink)
  if not ok then return nil, err end
  setMoney(wallet)
  local before = sink.snap()
  if sink.start then sink.start() else F.press("A", 2) end
  local used, back, prompts = converse({ answers = sink.answers, shot = shotTag, onPrompt = sink.onPrompt,
    picker = sink.picker })
  local after = sink.snap()
  return { before = before, after = after, back = back, used = used, prompts = table.concat(prompts, ",") }
end

local function edge(sink, wallet, label)
  local tag = string.format("%s %s (%d)", sink.tag, label, wallet)
  F.L("== " .. tag .. " ==")
  local r, err = attempt(sink, wallet, (sink.tag .. "_" .. label):gsub("%W", "_"))
  if not r then F.check(tag .. ": reached the counter", false, err); return end
  local got = sink.delivered(r.before, r.after)
  local paid = wallet >= sink.price
  local detail = string.format("money=%d %s -> %s prompts=%s", F.money(), sink.describe(r.before), sink.describe(r.after), r.prompts)
  if paid then
    F.check(tag .. ": charged exactly the price", F.money() == wallet - sink.price, detail)
    F.check(tag .. ": delivered once", got == 1, detail)
  else
    F.check(tag .. ": refused, money unchanged", F.money() == wallet, detail)
    F.check(tag .. ": refused, nothing delivered", got == 0, detail)
  end
  if sink.quote then
    local seen = sink.seen or {}
    F.check(tag .. ": the fee asked is the quote", seen.var == sink.price and seen.shown == sink.price,
      string.format("var=%s shown=%s quote=%d", tostring(seen.var), tostring(seen.shown), sink.price))
  end
  F.check(tag .. ": the field comes back", r.back, state())
  F.check(tag .. ": no crash screen", not F.crashScreen())
end

local function run(sink)
  if ONLY and not sink.tag:find(ONLY, 1, true) then return end
  if sink.prepare then
    F.L("== " .. sink.tag .. " setup ==")
    if not F.check(sink.tag .. ": set up", sink.prepare(), state()) then return end
  end
  edge(sink, 0, "broke")
  edge(sink, sink.price - 1, "one short")
  edge(sink, sink.price, "exact")
  if sink.comfortable then edge(sink, sink.comfortable, "comfortable") end
  if sink.cleanup then sink.cleanup() end
end

F.run(function()
  if not F.boot(HUB_GROUP) then F.check("boot to the hub", false); F.finish(); return end
  instantText()
  for _ = 1, 3 do giveMon(SPECIES_RATTATA) end
  F.check("three level 1 Rattata in the party", partyCount() == 3, "party=" .. partyCount())
  F.check("a Pokeblock Case for the Hoenn and Johto Safari counters", giveKeyItem(ITEM_POKEBLOCK_CASE))
  for _, sink in ipairs(SINKS) do run(sink) end
  F.finish()
end)
