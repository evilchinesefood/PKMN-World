-- The Johto scenes whose scripts 5ac8745870 rewrote and no other suite plays.
--
-- That commit cut randomizer, Nuzlocke and Pokecenter-challenge branches, a legacy save heal and a
-- never-set finite-TM shop out of reachable scripts. Each cut branch sat behind a stub that
-- returned FALSE, a flag nothing sets, or state a new game cannot hold
-- (test/overworld/ScriptRemovalDiff.py lists them). This plays what is left of each script with
-- real input and a seeded mash, so the same suite can run on the ROM before and after the cut:
--
--   curator    the hub Curator, talked to twice under a mash, after the arrival tour was declined:
--              control returns, one Hub Pass, the guide is home at his post
--   mrpokemon  walk into Mr. Pokemon's house with VAR_CHERRYGROVE_CITY_STATE 1: the egg scene
--              gives the Mystery Egg once, Oak's Pokedex, and leaves the story vars at 2 / 4
--   ticket     Olivine's ticket woman for a Kanto champion: one Aurora Ticket and the Birth
--              Island ship flag; a second talk gives nothing more
--   bed        the S.S. Aqua cabin bed heals a party Pokemon at 1 HP
--   incense    the Safari Zone Gate incense clerk opens the shop and the field returns
--
-- Setup sets story vars and flags and warps; every trigger is real input. `PW_TRIM_SEED=<n>`
-- reseeds the mashes, `PW_TRIM_ONLY=<text>` runs matching scenarios.
local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "TrimmedJohtoScenes")

local HUB = 100
local ROUTE30, MRPOKEMON_HOUSE = { 75, 3 }, { 98, 7 }
local OLIVINE, AQUA_ROOM, SAFARI_GATE = { 87, 0 }, { 95, 3 }, { 96, 0 }
local CONTEXT_RUNNING, CONTEXT_SHUTDOWN = 0, 2
local VAR_NEWBARKTOWN_LABSTATE, VAR_CHERRYGROVE_CITY_STATE = 0xA081, 0xA082
local FLAG_DELIVERED_EGG, FLAG_IS_KANTO_CHAMPION = 0x61DB, 0x613D
local FLAG_SYS_POKEDEX_GET, FLAG_ENABLE_SHIP_BIRTH_ISLAND = 0x949, 0x9BD
local ITEM_MYSTERY_EGG, ITEM_AURORA_TICKET, ITEM_HUB_RETURN = 887, 730, 893
local FLAG_HUB_INTRO_TOUR_DONE, LOCALID_CURATOR = 0xDCF, 13
local ONLY = os.getenv("PW_TRIM_ONLY") or ""
local SEED = tonumber(os.getenv("PW_TRIM_SEED") or "") or 0x5AC8

local function where() local x, y = F.pos(); return string.format("%d/%d (%d,%d)", F.grp(), F.mapn(), x, y) end
local function on(m) return F.grp() == m[1] and F.mapn() == m[2] end
local function hasControl()
  return F.ow() and F.r8(S.sLockFieldControls) == 0 and F.r8(S.sGlobalScriptContextStatus) == CONTEXT_SHUTDOWN
end

local function flagAddr(id)
  if id >= 0x6000 then return F.sb3() + S.SaveBlock3.johtoFlags + (id - 0x6000) // 8, (id - 0x6000) % 8 end
  return F.sb1() + S.SaveBlock1.flags + id // 8, id % 8
end
local function flag(id) local a, b = flagAddr(id); return (F.r8(a) >> b) & 1 == 1 end
local function setFlag(id) local a, b = flagAddr(id); F.w8(a, F.r8(a) | (1 << b)) end
local function varAddr(id) return F.sb3() + S.SaveBlock3.regionVars + (id - 0xA000) * 2 end
local function var(id) return F.r16(varAddr(id)) end
local function setVar(id, v) F.w16(varAddr(id), v) end

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
local MASH = { "A", "A", "A", "B", "B", "Up", "Down", "Start", "Select", "L", "R" }

local SCRIPT_BUF = S.gStringVar4 + 960
local function runScript(bytes)
  for i, b in ipairs(bytes) do F.w8(SCRIPT_BUF + i - 1, b) end
  F.w8(S.sGlobalScriptContext, 0)
  F.w8(S.sGlobalScriptContext + 1, 1)
  F.w32(S.sGlobalScriptContext + 4, 0)
  F.w32(S.sGlobalScriptContext + S.ScriptCtx.scriptPtr, SCRIPT_BUF)
  F.w8(S.sGlobalScriptContextStatus, CONTEXT_RUNNING)
end
local function free(n)
  for _ = 1, n or 30 do
    if hasControl() then return true end
    F.press("B", 2); F.idle(20)
  end
  return hasControl()
end
local function warp(m, x, y)
  free()
  runScript({ 0x39, m[1], m[2], 0xFF, x & 0xFF, x >> 8, y & 0xFF, y >> 8, 0x27, 0x02 })
  for _ = 1, 600 do
    F.idle(4)
    local px, py = F.pos()
    if on(m) and px == x and py == y and hasControl() then F.idle(20); return true end
  end
  return false
end

-- Run whatever script the last input started, mashing while it is live, until the field is back.
local function play(tag)
  seedFor(tag)
  local started, crashed = false, false
  for i = 1, 20000 do
    if i % 30 == 0 and F.reportCrash(tag) then crashed = true; break end
    local running = F.r8(S.sGlobalScriptContextStatus) ~= CONTEXT_SHUTDOWN
    local live = running or F.r8(S.sLockFieldControls) ~= 0 or not F.ow()
    if running then started = true end
    if (started or i > 600) and hasControl() then break end
    local btn = (live and rnd(3) == 0) and MASH[rnd(#MASH) + 1] or nil
    joypad.set(btn and { [btn] = true } or {})
    emu.frameadvance()
  end
  joypad.set({})
  local back = free(40)
  F.idle(8)
  F.shot(tag .. "_after")
  return back and not crashed, started
end
local function talk(dir, tag)
  F.face(dir)
  F.press("A", 2)
  return play(tag)
end
local function walkable(tag)
  local ok = F.ensureFree()
  if not ok then F.shot(tag .. "_stuck") end
  return ok
end

local function giveMon()
  free()
  F.dbg(); F.idle(60)
  for _ = 1, 3 do F.press("Down", 3); F.idle(16) end
  F.press("A", 3); F.idle(60)
  F.press("Down", 3); F.idle(16); F.press("A", 3); F.idle(60)
  F.spin(1, 5, 1)
  F.spin(0, 2, 0)
  F.idle(90)
  F.bOut(4); F.idle(60)
  free()
end

local SCENARIOS = {}
local function scenario(tag, fn) SCENARIOS[#SCENARIOS + 1] = { tag = tag, fn = fn } end

local function curatorAt()
  for i = 0, 15 do
    local b = S.gObjectEvents + i * S.ObjectEvent.stride
    if (F.r8(b) & 1) == 1 and F.r8(b + S.ObjectEvent.localId) == LOCALID_CURATOR then
      return F.rs16(b + S.ObjectEvent.x) - 7, F.rs16(b + S.ObjectEvent.y) - 7
    end
  end
  return -1, -1
end

scenario("curator", function(tag)
  F.check(tag .. ": the arrival tour was declined", flag(FLAG_HUB_INTRO_TOUR_DONE))
  if not F.check(tag .. ": reach the Curator", F.route({ { 22, 4 }, { 22, 6 } }, tag), where()) then return end
  for round = 1, 2 do
    local px, py = F.pos()
    if px ~= 22 or py ~= 6 then F.L("  the mash took the tour; the player ended at " .. where()); break end
    local back = talk("Down", tag .. "_" .. round)
    F.check(tag .. ": talk " .. round .. " returns control", back, where())
    local x, y = F.pos()
    local toured = x ~= 22 or y ~= 6
    local passes = F.itemCount(ITEM_HUB_RETURN)
    F.check(tag .. ": " .. (toured and "the replayed tour gives no Hub Pass" or "one Hub Pass") .. " after talk " .. round,
      passes == (toured and round - 1 or 1), "slots=" .. passes)
    local gx, gy = curatorAt()
    F.check(tag .. ": the Curator is home after talk " .. round, gx == 22 and gy == 7, string.format("(%d,%d)", gx, gy))
  end
  F.check(tag .. ": the tour flag stays set", flag(FLAG_HUB_INTRO_TOUR_DONE))
  F.check(tag .. ": the field is walkable", walkable(tag), where())
end)

scenario("mrpokemon", function(tag)
  setVar(VAR_CHERRYGROVE_CITY_STATE, 1)
  setVar(VAR_NEWBARKTOWN_LABSTATE, 3)
  if not F.check(tag .. ": below Mr. Pokemon's door", warp(ROUTE30, 35, 5), where()) then return end
  F.press("Up", 20)
  for _ = 1, 400 do if on(MRPOKEMON_HOUSE) then break end F.idle(2) end
  if not F.check(tag .. ": the door leads into the house", on(MRPOKEMON_HOUSE), where()) then return end
  local back, started = play(tag)
  F.check(tag .. ": the egg scene ran and gave control back", back and started, where())
  F.check(tag .. ": one Mystery Egg", F.itemCount(ITEM_MYSTERY_EGG) == 1, "slots=" .. F.itemCount(ITEM_MYSTERY_EGG))
  F.check(tag .. ": egg delivered and Pokedex given", flag(FLAG_DELIVERED_EGG) and flag(FLAG_SYS_POKEDEX_GET),
    string.format("delivered=%s dex=%s", tostring(flag(FLAG_DELIVERED_EGG)), tostring(flag(FLAG_SYS_POKEDEX_GET))))
  F.check(tag .. ": story vars advance to Cherrygrove 2, lab 4",
    var(VAR_CHERRYGROVE_CITY_STATE) == 2 and var(VAR_NEWBARKTOWN_LABSTATE) == 4,
    string.format("cherrygrove=%d lab=%d", var(VAR_CHERRYGROVE_CITY_STATE), var(VAR_NEWBARKTOWN_LABSTATE)))
  F.check(tag .. ": the field is walkable", walkable(tag), where())
end)

scenario("ticket", function(tag)
  setFlag(FLAG_IS_KANTO_CHAMPION)
  if not F.check(tag .. ": below the ticket woman", warp(OLIVINE, 26, 53), where()) then return end
  local back = talk("Up", tag .. "_first")
  F.check(tag .. ": first talk returns control", back, where())
  F.check(tag .. ": one Aurora Ticket", F.itemCount(ITEM_AURORA_TICKET) == 1, "slots=" .. F.itemCount(ITEM_AURORA_TICKET))
  F.check(tag .. ": the Birth Island ship flag is set", flag(FLAG_ENABLE_SHIP_BIRTH_ISLAND))
  back = talk("Up", tag .. "_again")
  F.check(tag .. ": second talk returns control", back, where())
  F.check(tag .. ": still one Aurora Ticket and the flag",
    F.itemCount(ITEM_AURORA_TICKET) == 1 and flag(FLAG_ENABLE_SHIP_BIRTH_ISLAND), "slots=" .. F.itemCount(ITEM_AURORA_TICKET))
  F.check(tag .. ": the field is walkable", walkable(tag), where())
end)

scenario("bed", function(tag)
  if F.r8(S.gPartiesCount) == 0 then giveMon() end
  if not F.check(tag .. ": a Pokemon in the party", F.r8(S.gPartiesCount) >= 1, "count=" .. F.r8(S.gPartiesCount)) then return end
  if not F.check(tag .. ": beside the cabin bed", warp(AQUA_ROOM, 5, 4), where()) then return end
  F.w16(S.gParties + 0x56, 1)
  local back = talk("Right", tag)
  local hp, max = F.r16(S.gParties + 0x56), F.r16(S.gParties + 0x58)
  F.check(tag .. ": the bed returns control", back, where())
  F.check(tag .. ": the bed heals the party", hp == max and max > 1, string.format("hp=%d/%d", hp, max))
  F.check(tag .. ": the field is walkable", walkable(tag), where())
end)

scenario("incense", function(tag)
  if not F.check(tag .. ": below the incense clerk", warp(SAFARI_GATE, 11, 22), where()) then return end
  local money = F.money()
  F.face("Up")
  F.press("A", 2)
  local shop = false
  for _ = 1, 600 do
    if F.taskLive(S.Task_ShopMenu) then shop = true; break end
    F.press("A", 2); F.idle(10)
  end
  F.check(tag .. ": the clerk opens the shop", shop)
  if shop then
    F.idle(30); F.press("A", 2)
    for _ = 1, 300 do if F.cb2() == S.CB2_BuyMenu then break end F.idle(2) end
    F.idle(60)
    F.shot(tag .. "_buy_list")
    F.check(tag .. ": BUY lists the stock", F.cb2() == S.CB2_BuyMenu, string.format("cb2=%08X", F.cb2()))
  end
  local back = free(60)
  F.shot(tag .. "_after")
  F.check(tag .. ": leaving the shop with B returns control", back and not F.reportCrash(tag), where())
  F.check(tag .. ": money unchanged", F.money() == money, string.format("%d -> %d", money, F.money()))
  F.check(tag .. ": the field is walkable", walkable(tag), where())
end)

F.run(function()
  if not F.boot(HUB) then F.check("boot", false); F.finish(); return end
  for _, s in ipairs(SCENARIOS) do
    if ONLY == "" or s.tag:find(ONLY, 1, true) then
      F.L("-- " .. s.tag)
      s.fn(s.tag)
    end
  end
  F.finish()
end)
