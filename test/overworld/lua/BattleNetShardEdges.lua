-- The Battle Net floor's currencies at their edges: the BP clerk (4 BP for a shard), the stone
-- vendor (35 or 20 shards of any colour for a Mega Stone) and the Director's free starter stone,
-- each against a short balance, an exact balance, a full Items pocket and a 999 stack.
--
-- These are hack-specific C specials (TryBuyBattleNetShard, GetBattleNetShardCount,
-- DeductBattleNetShards) that AuditCapacity.py only reviews by hand, and no suite drove them.
-- A refusal must take nothing and give nothing; a purchase must take exactly the price once and
-- give exactly one item; a seeded mash of the menus must conserve value (BP spent = 4 x shards
-- received, shards spent = the listed price of each stone received).
--
-- Setup writes BP, the bag and the Director's flags in RAM and warps to the counter. Talking,
-- every menu row, Yes/No and the mashes are real input.
--
-- `PW_BNET_ONLY=<text>` runs matching scenarios, `PW_BNET_SEED=<n>` reseeds the mashes.
local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "BattleNetShardEdges")

local HUB = 100
local FLOOR_G, FLOOR_N = 100, 1
local CLERK, VENDOR, DIRECTOR = { 10, 4 }, { 6, 4 }, { 2, 4 }
local CONTEXT_RUNNING, CONTEXT_SHUTDOWN = 0, 2
local TEXT_INSTANT = 3
local RED, BLUE, YELLOW, GREEN = 148, 149, 150, 151
local SHARDS = { RED, BLUE, YELLOW, GREEN }
local VENUSAURITE, PINSIRITE, MAWILITE = 292, 302, 318
local MEGA_RING = 703
local STONE_PRICE = {
  [292] = 35, [293] = 35, [294] = 35, [295] = 35, [313] = 35, [314] = 35, [315] = 35, [316] = 35,
  [302] = 20, [318] = 20,
}
local FLAG_BNET_DIRECTOR_INTRO, FLAG_BNET_DIRECTOR_STONE = 0xDC4, 0xDCE
local ONLY = os.getenv("PW_BNET_ONLY") or ""
local SEED = tonumber(os.getenv("PW_BNET_SEED") or "") or 0xB4E7

local function where() local x, y = F.pos(); return string.format("%d/%d (%d,%d)", F.grp(), F.mapn(), x, y) end
local function key16() return F.r32(F.sb2() + S.SaveBlock2.encryptionKey) & 0xFFFF end
local function bp() return F.r16(F.sb2() + S.SaveBlock2.bp) end
local function setBp(v) F.w16(F.sb2() + S.SaveBlock2.bp, v) end
local function flag(id) return (F.r8(F.sb1() + S.SaveBlock1.flags + id // 8) & (1 << (id % 8))) ~= 0 end
local function setFlag(id, on)
  local a, m = F.sb1() + S.SaveBlock1.flags + id // 8, 1 << (id % 8)
  F.w8(a, on and (F.r8(a) | m) or (F.r8(a) & ~m & 0xFF))
end
local function hasControl()
  return F.ow() and F.r8(S.sLockFieldControls) == 0 and F.r8(S.sGlobalScriptContextStatus) == CONTEXT_SHUTDOWN
end
local function setTextSpeed(v)
  local a = F.sb2() + S.SaveBlock2.optionsU16
  F.w16(a, (F.r16(a) & ~7) | v)
end

-- ---- the bag ------------------------------------------------------------------------------------
local function pocketPtr(p) return F.r32(S.gBagPockets + p * S.BagPocket.stride) end
local function qty(id)
  local n = 0
  for p = 0, 4 do
    local ptr, cap = pocketPtr(p), F.pocketCap(p)
    for s = 0, cap - 1 do
      if F.r16(ptr + s * 4) == id then n = n + (F.r16(ptr + s * 4 + 2) ~ key16()) end
    end
  end
  return n
end
local function shards() local n = 0; for _, id in ipairs(SHARDS) do n = n + qty(id) end; return n end
local function stones()
  local n, worth = 0, 0
  for id, price in pairs(STONE_PRICE) do local q = qty(id); n = n + q; worth = worth + q * price end
  return n, worth
end
local function setSlot(i, id, n)
  local ptr = pocketPtr(0)
  F.w16(ptr + i * 4, id); F.w16(ptr + i * 4 + 2, (id == 0 and 0 or n) ~ (id == 0 and 0 or key16()))
end
-- The Items pocket holds exactly `slots` ({id, n} pairs, in order) and, when `fill` is set,
-- every other slot is a distinct filler item so the pocket has no free slot.
local function setItems(slots, fill)
  local cap = F.pocketCap(0)
  local filler = 28
  for i = 0, cap - 1 do
    local s = slots[i + 1]
    if s then setSlot(i, s[1], s[2])
    elseif fill then
      while filler == RED or filler == BLUE or filler == YELLOW or filler == GREEN or STONE_PRICE[filler] do filler = filler + 1 end
      setSlot(i, filler, 1); filler = filler + 1
    else setSlot(i, 0, 0) end
  end
end

-- ---- injected warp (setup only) -----------------------------------------------------------------
local SCRIPT_BUF = S.gStringVar4 + 960
local function runScript(bytes)
  for i, b in ipairs(bytes) do F.w8(SCRIPT_BUF + i - 1, b) end
  F.w8(S.sGlobalScriptContext, 0)
  F.w8(S.sGlobalScriptContext + 1, 1)
  F.w32(S.sGlobalScriptContext + 4, 0)
  F.w32(S.sGlobalScriptContext + S.ScriptCtx.scriptPtr, SCRIPT_BUF)
  F.w8(S.sGlobalScriptContextStatus, CONTEXT_RUNNING)
end
local function warp(at)
  for _ = 1, 30 do
    if hasControl() then break end
    F.press("B", 2); F.idle(20)
  end
  local x, y = at[1], at[2]
  runScript({ 0x39, FLOOR_G, FLOOR_N, 0xFF, x & 0xFF, x >> 8, y & 0xFF, y >> 8, 0x27, 0x02 })
  for _ = 1, 600 do
    F.idle(4)
    local px, py = F.pos()
    if F.grp() == FLOOR_G and F.mapn() == FLOOR_N and px == x and py == y and hasControl() then F.idle(20); return true end
  end
  return false
end

-- ---- talking ------------------------------------------------------------------------------------
local CH = { [0x00] = " ", [0xAB] = "!", [0xAC] = "?", [0xAD] = ".", [0xB4] = "'", [0xB8] = ",", [0x1B] = "E" }
for i = 0, 9 do CH[0xA1 + i] = string.char(48 + i) end
for i = 0, 25 do CH[0xBB + i] = string.char(65 + i); CH[0xD5 + i] = string.char(65 + i) end
local function shownText()
  local s = {}
  for i = 0, 239 do
    local c = F.r8(S.gStringVar4 + i)
    if c == 0xFF then break end
    s[#s + 1] = CH[c] or " "
  end
  return (table.concat(s):gsub("%s+", " "))
end
local function activeMenu()
  for i = 0, S.Task.count - 1 do
    local a = S.gTasks + i * S.Task.stride
    local fn = F.r32(a + S.Task.func) & 0xFFFFFFFE
    if F.r8(a + S.Task.isActive) ~= 0 then
      if fn == S.Task_HandleYesNoInput then return "yesno" end
      if fn == S.Task_HandleMultichoiceInput then return "list" end
    end
  end
  return nil
end

local rngState = 1
local function seedFor(tag)
  local h = SEED
  for i = 1, #tag do h = (h * 31 + tag:byte(i)) & 0x7FFFFFFF end
  rngState = h ~= 0 and h or 1
end
local function rnd(n)
  rngState = (rngState * 1103515245 + 12345) & 0x7FFFFFFF
  return (rngState >> 8) % n
end
local MASH = { "A", "A", "B", "Up", "Down", "Down", "Left", "Right", "L", "R", "Start" }

-- Talk across the counter. `rows` lists the list rows to pick in order; a Yes/No is answered
-- NO; after the rows run out a list is left with B. With `mash`, a seeded mash runs instead,
-- only while the script is live.
local function talk(tag, rows, mash)
  F.face("Up")
  F.w8(S.gStringVar4, 0xFF)
  F.press("A", 2)
  local said, last, picked, started, crashed, shots = {}, nil, 0, false, false, {}
  if mash then seedFor(tag) end
  for i = 1, 12000 do
    if i % 30 == 0 and F.reportCrash(tag) then crashed = true; break end
    local s = shownText()
    if s ~= last then last = s; if #s > 0 then said[#said + 1] = s end end
    local live = F.r8(S.sGlobalScriptContextStatus) ~= CONTEXT_SHUTDOWN
    if live then started = true end
    if (started or i > 120) and hasControl() then break end
    local btn
    if mash then
      if live and rnd(4) == 0 then btn = MASH[rnd(#MASH) + 1] end
    elseif i % 16 == 0 then
      local menu = activeMenu()
      if menu == "list" then
        if shots[picked] == nil then shots[picked] = true; F.shot(tag:gsub("[^%w]", "_") .. "_list" .. picked) end
        local want = rows[picked + 1]
        if want == nil then btn = "B"
        elseif F.mcur() < want then btn = "Down"
        elseif F.mcur() > want then btn = "Up"
        else btn = "A"; picked = picked + 1 end
      elseif menu == "yesno" then
        btn = "B"
      else
        btn = "A"
      end
    end
    joypad.set(btn and { [btn] = true } or {})
    emu.frameadvance()
  end
  joypad.set({})
  for _ = 1, 20 do
    if hasControl() then break end
    F.press("B", 2); F.idle(20)
  end
  F.idle(20)
  F.L("  " .. tag .. " said: " .. table.concat(said, " | "))
  return said, hasControl() and not crashed
end
local function saidAny(said, pattern)
  for _, s in ipairs(said) do if s:find(pattern, 1, true) then return true end end
  return false
end

-- ---- scenarios ----------------------------------------------------------------------------------
local SCENARIOS = {}
local function scenario(tag, fn) SCENARIOS[#SCENARIOS + 1] = { tag = tag, fn = fn } end

local function at(tag, spot)
  return F.check(tag .. ": stand at the counter", warp(spot), where())
end

scenario("clerk_3bp", function(tag)
  setItems({}); setBp(3)
  if not at(tag, CLERK) then return end
  local said, back = talk(tag, { 0 })
  F.check(tag .. ": control returns", back)
  F.check(tag .. ": the clerk asks for 4 BP", saidAny(said, "YOU NEED AT LEAST 4 BP"), table.concat(said, " | "))
  F.check(tag .. ": 3 BP kept, no shard", bp() == 3 and shards() == 0, string.format("bp=%d shards=%d", bp(), shards()))
end)

scenario("clerk_4bp", function(tag)
  setItems({}); setBp(4)
  if not at(tag, CLERK) then return end
  local said, back = talk(tag, { 1 })
  F.check(tag .. ": control returns", back)
  F.check(tag .. ": 4 BP buy exactly one Blue Shard", bp() == 0 and qty(BLUE) == 1 and shards() == 1,
    string.format("bp=%d blue=%d shards=%d", bp(), qty(BLUE), shards()))
  F.check(tag .. ": the clerk offers another", saidAny(said, "ANOTHER SHARD"), table.concat(said, " | "))
end)

scenario("clerk_pocket_full", function(tag)
  setItems({}, true); setBp(400)
  if not at(tag, CLERK) then return end
  local said, back = talk(tag, { 0 })
  F.check(tag .. ": control returns", back)
  F.check(tag .. ": the clerk says there is no room", saidAny(said, "NO BAG SPACE"), table.concat(said, " | "))
  F.check(tag .. ": 400 BP kept, no shard", bp() == 400 and shards() == 0, string.format("bp=%d shards=%d", bp(), shards()))
end)

scenario("clerk_stack_999", function(tag)
  setItems({ { RED, 999 } }, true); setBp(400)
  if not at(tag, CLERK) then return end
  local said, back = talk(tag, { 0 })
  F.check(tag .. ": control returns", back)
  F.check(tag .. ": a full Red stack is refused", saidAny(said, "NO BAG SPACE"), table.concat(said, " | "))
  F.check(tag .. ": 400 BP kept, still 999 Red", bp() == 400 and qty(RED) == 999, string.format("bp=%d red=%d", bp(), qty(RED)))
end)

scenario("clerk_stack_998", function(tag)
  setItems({ { RED, 998 } }, true); setBp(400)
  if not at(tag, CLERK) then return end
  local said, back = talk(tag, { 0 })
  F.check(tag .. ": control returns", back)
  F.check(tag .. ": the last Red fits on the stack", bp() == 396 and qty(RED) == 999, string.format("bp=%d red=%d", bp(), qty(RED)))
end)

scenario("vendor_34_shards", function(tag)
  setItems({ { RED, 10 }, { BLUE, 10 }, { YELLOW, 10 }, { GREEN, 4 } })
  if not at(tag, VENDOR) then return end
  local said, back = talk(tag, { 0 })
  F.check(tag .. ": control returns", back)
  F.check(tag .. ": the vendor says not enough", saidAny(said, "NOT ENOUGH SHARDS"), table.concat(said, " | "))
  local n = stones()
  F.check(tag .. ": 34 shards kept, no stone", shards() == 34 and n == 0, string.format("shards=%d stones=%d", shards(), n))
end)

scenario("vendor_35_shards", function(tag)
  setItems({ { RED, 10 }, { BLUE, 10 }, { YELLOW, 10 }, { GREEN, 5 } })
  if not at(tag, VENDOR) then return end
  local said, back = talk(tag, { 0 })
  F.check(tag .. ": control returns", back)
  local n = stones()
  F.check(tag .. ": 35 mixed shards buy exactly one Venusaurite", shards() == 0 and qty(VENUSAURITE) == 1 and n == 1,
    string.format("shards=%d venusaurite=%d stones=%d", shards(), qty(VENUSAURITE), n))
  F.check(tag .. ": the vendor offers another", saidAny(said, "ANYTHING ELSE"), table.concat(said, " | "))
end)

scenario("vendor_page2_20", function(tag)
  setItems({ { GREEN, 20 } })
  if not at(tag, VENDOR) then return end
  local said, back = talk(tag, { 5, 3 })
  F.check(tag .. ": control returns", back)
  F.check(tag .. ": 20 shards buy the second page's Pinsirite", shards() == 0 and qty(PINSIRITE) == 1,
    string.format("shards=%d pinsirite=%d", shards(), qty(PINSIRITE)))
end)

scenario("vendor_page2_back", function(tag)
  setItems({ { GREEN, 20 } })
  if not at(tag, VENDOR) then return end
  local said, back = talk(tag, { 5, 5, 6 })
  F.check(tag .. ": control returns", back)
  local n = stones()
  F.check(tag .. ": Back then EXIT buys nothing", shards() == 20 and n == 0, string.format("shards=%d stones=%d", shards(), n))
end)

scenario("vendor_pocket_full", function(tag)
  setItems({ { RED, 40 } }, true)
  if not at(tag, VENDOR) then return end
  local said, back = talk(tag, { 0 })
  F.check(tag .. ": control returns", back)
  F.check(tag .. ": the vendor says there is no room", saidAny(said, "NO BAG SPACE"), table.concat(said, " | "))
  local n = stones()
  F.check(tag .. ": 40 shards kept, no stone", shards() == 40 and n == 0, string.format("shards=%d stones=%d", shards(), n))
end)

scenario("director_pocket_full", function(tag)
  setFlag(FLAG_BNET_DIRECTOR_INTRO, false); setFlag(FLAG_BNET_DIRECTOR_STONE, false)
  setItems({}, true)
  if not at(tag, DIRECTOR) then return end
  local said, back = talk(tag, { 0 })
  F.check(tag .. ": control returns", back)
  local n = stones()
  F.check(tag .. ": the Mega Ring is given once", qty(MEGA_RING) == 1, "ring=" .. qty(MEGA_RING))
  F.check(tag .. ": the director says to make room", saidAny(said, "YOUR BAG IS FULL"), table.concat(said, " | "))
  F.check(tag .. ": no stone, and the stone stays claimable", n == 0 and not flag(FLAG_BNET_DIRECTOR_STONE),
    string.format("stones=%d flag=%s", n, tostring(flag(FLAG_BNET_DIRECTOR_STONE))))

  setItems({})
  if not at(tag .. " again", DIRECTOR) then return end
  said, back = talk(tag .. " again", { 4 })
  F.check(tag .. " again: control returns", back)
  n = stones()
  F.check(tag .. " again: with room the Sceptilite is given once", n == 1 and qty(313) == 1 and flag(FLAG_BNET_DIRECTOR_STONE),
    string.format("stones=%d sceptilite=%d", n, qty(313)))
  F.check(tag .. " again: no second Mega Ring", qty(MEGA_RING) == 1, "ring=" .. qty(MEGA_RING))

  if not at(tag .. " third", DIRECTOR) then return end
  said, back = talk(tag .. " third", { 0 })
  F.check(tag .. " third: control returns", back)
  n = stones()
  F.check(tag .. " third: no second stone", n == 1, "stones=" .. n)
end)

-- Value must be conserved however the menus are mashed.
local function clerkMash(tag)
  setItems({}); setBp(40)
  if not at(tag, CLERK) then return end
  local said, back = talk(tag, nil, true)
  F.check(tag .. ": control returns", back, where())
  local n = stones()
  F.check(tag .. ": BP spent is 4 per shard received", bp() + 4 * shards() == 40 and n == 0,
    string.format("bp=%d shards=%d stones=%d", bp(), shards(), n))
end
local function vendorMash(tag)
  setItems({ { RED, 25 }, { BLUE, 25 }, { YELLOW, 25 }, { GREEN, 25 } })
  if not at(tag, VENDOR) then return end
  local said, back = talk(tag, nil, true)
  F.check(tag .. ": control returns", back, where())
  local _, worth = stones()
  F.check(tag .. ": shards spent are the listed price of each stone", shards() + worth == 100,
    string.format("shards=%d stone_value=%d", shards(), worth))
end
for k = 1, 3 do
  scenario("clerk_mash" .. k, clerkMash)
  scenario("vendor_mash" .. k, vendorMash)
end

F.run(function()
  if not F.boot(HUB) then F.check("fresh boot", false); F.finish(); return end
  setTextSpeed(TEXT_INSTANT)
  F.check("setup: the Items pocket has slots", F.pocketCap(0) > 0, "cap=" .. F.pocketCap(0))
  for _, sc in ipairs(SCENARIOS) do
    if ONLY == "" or sc.tag:find(ONLY, 1, true) then
      sc.fn(sc.tag)
      F.check(sc.tag .. ": no crash screen", not F.crashScreen())
    end
  end
  F.finish()
end)
