-- Mashing every button during transitions, menus and battles must never crash or strand the game.
--
-- Each scenario starts from a free hub, drives a seeded pseudo-random mash (never the full
-- A+B+Start+Select soft-reset chord) through one transition or screen at Instant text, then
-- backs out with B and A until the player can walk again. A crash screen or a game that never
-- returns to a walkable field fails the scenario; the log names the callback and live tasks.
--
-- Run via test/overworld/mgba-run.sh test/overworld/lua/InputSpamStress.lua <rom>
--
-- Exploring and replaying (pass with the runner's --env): PW_SPAM_BASE=<n> seeds a different
-- mash; PW_SPAM_ONLY=<text> runs only matching scenarios; PW_SPAM_SAVE=<dir> keeps a savestate
-- before and after each scenario's mash; PW_SPAM_LOAD=<state> with PW_SPAM_SEED, PW_SPAM_ONLY,
-- and optionally PW_SPAM_ICON (a Start-menu icon to open first) replays one mash from a kept
-- state; PW_SPAM_TRACE=1 logs every mashed frame.

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "InputSpamStress")

local HUB_GROUP = 100
local ONLY = os.getenv("PW_SPAM_ONLY")
local TRACE = os.getenv("PW_SPAM_TRACE")

local seed = tonumber(os.getenv("PW_SPAM_BASE") or "") or 0x5EED
local function rnd()
  seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF
  return seed >> 8
end

local DIRS = { "Up", "Down", "Left", "Right" }
local DEFAULT = { A = 30, B = 30, Start = 8, Select = 6, dir = 50 }

local function mashFrame(w)
  local t = {}
  for _, b in ipairs({ "A", "B", "Start", "Select", "L", "R" }) do
    if rnd() % 100 < (w[b] or 0) then t[b] = true end
  end
  if t.A and t.B and t.Start and t.Select then t.Select = nil end
  if rnd() % 100 < (w.dir or 0) then t[DIRS[rnd() % 4 + 1]] = true end
  if TRACE then
    local k = {}
    for b in pairs(t) do k[#k + 1] = b end
    table.sort(k)
    F.L(string.format("  f%d cb2=%08X %s", emu.framecount(), F.cb2(), table.concat(k, "+")))
  end
  joypad.set(t)
  emu.frameadvance()
end

local function tasks()
  local t = {}
  for i = 0, S.Task.count - 1 do
    local a = S.gTasks + i * S.Task.stride
    if F.r8(a + S.Task.isActive) ~= 0 then t[#t + 1] = string.format("%08X", F.r32(a + S.Task.func)) end
  end
  return table.concat(t, ",")
end

local function state()
  return string.format("cb2=%08X tasks=[%s] grp=%d map=%d battle=%08X printer=%08X",
    F.cb2(), tasks(), F.grp(), F.mapn(), F.battleFlags(), F.r32(S.sFirstTextPrinter))
end

local function mash(tag, frames, w, stop)
  w = w or DEFAULT
  for i = 1, frames do
    if F.reportCrash(tag) then return "crash", i end
    if stop and stop(i) then return "stop", i end
    mashFrame(w)
  end
  return "ok", frames
end

local function inBattle() return F.cb2() == (S.BattleMainCB2 & ~1) end

-- Drop each opponent on the field to 1 HP and keep the player's side topped up, so mashed moves
-- end a battle through the engine's own faint and switch-in path instead of trading blows for
-- minutes or stranding the mash on a forced switch.
local function assistBattle(i)
  for b = 0, F.battlers() - 1 do
    local a = S.gBattleMons + b * S.BattlePokemon.size
    local hp = F.r16(a + S.BattlePokemon.hp)
    if b % 2 == 1 and hp > 1 and i % 60 == 0 then F.w16(a + S.BattlePokemon.hp, 1) end
    if b % 2 == 0 and hp > 0 then F.w16(a + S.BattlePokemon.hp, F.r16(a + S.BattlePokemon.maxHP)) end
  end
end

-- lib's ensureFree steps Left first, and on the hub's escalator apron that rides the escalator,
-- whose arrival walk lands back on the apron: the check itself kept the player cycling between
-- floors. Try Right first, then the other directions; the step back returns to a tile the player
-- already stood on.
local BACK = { Right = "Left", Left = "Right", Down = "Up", Up = "Down" }
local function free()
  local x0, y0 = F.pos()
  for _, dir in ipairs({ "Right", "Left", "Down", "Up" }) do
    if F.step(dir) then
      F.step(BACK[dir])
      local x, y = F.pos()
      return x == x0 and y == y0
    end
  end
  return false
end

local function controller() return F.r32(S.gBattlerControllerFuncs) & ~1 end

local function actionMenu()
  local fn = controller()
  for _, p in ipairs(S.ActionInputFunctions) do if fn == (p & ~1) then return true end end
  return false
end

-- The key that walks a battle toward its end: on the action menu, Right and Down reach RUN
-- (flee a wild battle, or the forfeit prompt in a trainer battle), the prompt takes Up for Yes
-- and then A, B leaves the move list, and A advances text. Off the battle screen (Bag, party,
-- summary) B backs out, with Down and A for the forced switch after a faint, which refuses B.
local atPrompt = false
local function battleKey(n)
  if inBattle() then
    local fn = controller()
    if fn == (S.PlayerHandleYesNoInput & ~1) then
      local key = atPrompt and "A" or "Up"
      atPrompt = not atPrompt
      return key
    end
    atPrompt = false
    if actionMenu() then return ({ "Right", "Down", "A" })[n % 3 + 1] end
    if fn == (S.HandleInputChooseMove & ~1) then return "B" end
    return "A"
  end
  return ({ "B", "B", "Down", "A", "A" })[n % 5 + 1]
end

-- Back out to a walkable field: mostly B, with A to advance text.
local function recover(tag, budget)
  for i = 1, budget or 4000 do
    if F.reportCrash(tag) then return false, "crash" end
    if F.ow() and i % 90 == 0 and free() then return true, "free after " .. i end
    local p = i % 24
    if p < 2 then
      -- Down now and then lets a held PC Pokemon reach a slot where B can put it down, and Start
      -- moves a naming screen's cursor to OK, where B only deletes letters.
      local n = i // 24
      local key = (n % 10 == 9) and "Start" or ((n % 6 == 5) and "Down" or ((n % 4 == 3) and "A" or "B"))
      -- gBattleTypeFlags outlives a battle; an undecided outcome marks one still running.
      if not F.ow() and F.battleFlags() ~= 0 and F.outcome() == 0 then key = battleKey(n) end
      joypad.set({ [key] = true })
    else
      joypad.set({})
    end
    emu.frameadvance()
  end
  return false, state()
end

local SAVE_DIR = os.getenv("PW_SPAM_SAVE")

local function instantText()
  local a = F.sb2() + S.SaveBlock2.optionsU16
  F.w16(a, (F.r16(a) & ~7) | 3)
end

local function scenario(tag, body)
  if ONLY and not tag:find(ONLY, 1, true) then return end
  F.L(string.format("== %s == seed=%d", tag, seed))
  if SAVE_DIR then client.savestate(SAVE_DIR .. "/" .. tag:gsub("%W", "_") .. ".ss") end
  local result, at = body()
  if SAVE_DIR then client.savestate(SAVE_DIR .. "/" .. tag:gsub("%W", "_") .. "_after.ss") end
  F.check(tag .. ": the scenario reached its subject", result ~= "skip", state())
  local crashed = result == "crash"
  F.check(tag .. ": no crash while mashing", not crashed, "at frame " .. tostring(at) .. " " .. state())
  if crashed then return false end
  -- Back out at Instant text: the backing-out is not under test, and Slow text outlasts it.
  instantText()
  local ok, how = recover(tag)
  if not ok then F.shot(tag:gsub("%W", "_") .. "_stuck") end
  F.check(tag .. ": control returns", ok, how)
  return ok
end

-- The debug spinners count up from 1, so 3/7/5 gives species 376; a 1/0/0 level spin lands on
-- the cap, 100.
local function giveMon(h, t, o)
  F.dbg(); F.sel(3); F.sel(1); F.idle(20)
  F.spin(h, t, o); F.idle(20); F.spin(1, 0, 0); F.idle(60); F.bOut(4)
end

local function flag(n)
  local a = F.sb1() + S.SaveBlock1.flags + n // 8
  F.w8(a, F.r8(a) | (1 << (n % 8)))
end

-- A mash that walks through a hub gate boxes the party (a new region starts empty) and moves
-- the active region; put both back so the next scenario starts from the same footing.
local function setup()
  while F.r8(S.gPartiesCount) < 3 do
    local n = F.r8(S.gPartiesCount)
    if n == 0 then giveMon(3, 7, 5) elseif n == 1 then giveMon(0, 0, 1) else giveMon(1, 4, 9) end
    if F.r8(S.gPartiesCount) == n then return false end
  end
  F.w8(F.sb2() + S.SaveBlock2.currentRegion, 3); F.w32(S.gCurrentRegion, 3)
  instantText()
  return true
end

local function toHub()
  local ok = F.warpTo(1, 0, 0, 0, 0, 0, 0, 0, 0, HUB_GROUP, 0, "hub")
  setup()
  return ok
end

-- Warp menu up to the final A, so the mash itself confirms the warp and rides its fade.
local function armWarp(g, m)
  F.dbg(); F.sel(0); F.sel(1); F.idle(20)
  F.spin(g[1], g[2], g[3]); F.spin(m[1], m[2], m[3])
  F.press("Right", 2); F.idle(8); F.press("Right", 2); F.idle(8)
  for _ = 1, 6 do F.press("Down", 2); F.idle(8) end
end

local function terminalMenu(path)
  if not F.route({ { 6, 10 }, { 9, 10 } }, "terminal") then return false end
  F.face("Up"); F.press("A", 2); F.idle(30)
  for _, row in ipairs(path) do
    if not F.pick(row, "terminal_" .. row, 40) then return false end
  end
  return true
end

local function battleMash(tag, frames)
  local w = { A = 45, B = 20, Start = 4, Select = 4, dir = 40 }
  local entered = false
  local result, at = mash(tag, frames, w, function()
    if inBattle() then entered = true end
    return entered and F.ow()
  end)
  if result == "ok" and entered and not F.ow() then
    -- Still trading blows: assist the battle to its end and keep mashing through it.
    result, at = mash(tag .. "_end", 4000, w, function(i)
      assistBattle(i)
      return F.ow()
    end)
  end
  F.L(string.format("  %s: entered=%s result=%s at=%d outcome=%d", tag, tostring(entered), result, at, F.outcome()))
  F.check(tag .. ": the battle started", entered)
  return result, at
end

F.run(function()
  if not F.boot(HUB_GROUP) then F.check("boot to the hub", false); F.finish(); return end
  local load = os.getenv("PW_SPAM_LOAD")
  if load then
    client.loadstate(load)
    seed = tonumber(os.getenv("PW_SPAM_SEED"))
    local tag = ONLY
    scenario(tag, function()
      local icon = tonumber(os.getenv("PW_SPAM_ICON") or "")
      if icon then F.press("Start", 2); F.idle(60); F.selectStartIcon(icon); F.press("A", 2) end
      return mash(tag, tonumber(os.getenv("PW_SPAM_FRAMES") or "1500"),
      { A = 40, B = 12, Start = 8, Select = 8, L = 10, R = 10, dir = 60 }) end)
    F.finish(); return
  end
  flag(0xA4A)
  flag(0x949)
  for id = 0x94F, 0x956 do flag(id) end
  setup()
  F.check("setup party", F.r8(S.gPartiesCount) >= 3, "n=" .. F.r8(S.gPartiesCount))

  scenario("hub field mash", function()
    return mash("hub", 2400)
  end)
  toHub()

  scenario("start menu open and close", function()
    return mash("startmenu", 1500, { A = 12, B = 30, Start = 45, dir = 40 })
  end)
  toHub()

  for _, w in ipairs({ { "debug warp fade", { 0, 0, 3 }, { 0, 0, 0 } },
                       { "debug warp to a town", { 0, 0, 0 }, { 0, 0, 2 } } }) do
    scenario(w[1], function()
      armWarp(w[2], w[3])
      return mash(w[1], 400, { A = 50, B = 30, Start = 10, dir = 60 })
    end)
    toHub()
  end

  scenario("hub stairs warp", function()
    if not F.route({ { 6, 4 }, { 6, 12 }, { 3, 12 }, { 3, 13 }, { 2, 13 } }, "stairs") then return "skip", 0 end
    local result, at = mash("stairs", 600, { A = 40, B = 30, Start = 10, dir = 0 })
    if result == "crash" then return result, at end
    return mash("stairs_down", 400, { A = 40, B = 30, Start = 10, dir = 100 })
  end)
  toHub()

  scenario("save prompt mash", function()
    F.press("Start", 2); F.idle(60)
    if not F.selectStartIcon(7) then return "skip", 0 end
    return mash("save", 900, { A = 45, B = 35, Start = 10, dir = 40 })
  end)
  toHub()

  for _, entry in ipairs({ { 0, "pokedex" }, { 1, "party" }, { 2, "bag" }, { 5, "trainer card" },
                           { 6, "story map" }, { 9, "options" } }) do
    local icon, name = entry[1], entry[2]
    scenario(name .. " screen mash", function()
      F.press("Start", 2); F.idle(60)
      if not F.selectStartIcon(icon) then F.L("  no " .. name .. " icon"); return "skip", 0 end
      F.press("A", 2)
      return mash(name, 1500, { A = 40, B = 12, Start = 8, Select = 8, L = 10, R = 10, dir = 60 })
    end)
    toHub()
  end

  scenario("PC mash", function()
    F.dbg(); F.sel(1); F.sel(0)
    return mash("pc", 1800, { A = 40, B = 15, Start = 6, Select = 8, L = 8, R = 8, dir = 60 })
  end)
  toHub()

  scenario("wardrobe outfit picker mash", function()
    if not F.route({ { 6, 4 }, { 6, 8 }, { 7, 8 } }, "wardrobe") then return "skip", 0 end
    F.face("Up")
    return mash("wardrobe", 1500, { A = 40, B = 12, Start = 8, Select = 6, dir = 60 })
  end)
  toHub()

  scenario("trainer single battle mash", function()
    if not terminalMenu({ 1, 0, 0 }) then F.L("  terminal refused"); return "skip", 0 end
    return battleMash("roxanne", 9000)
  end)
  toHub()

  scenario("trainer double battle mash", function()
    if not terminalMenu({ 1, 0, 4, 2 }) then F.L("  terminal refused"); return "skip", 0 end
    return battleMash("tate_liza", 12000)
  end)
  toHub()

  scenario("scripted wild battle mash", function()
    F.dbg(); F.sel(0); F.sel(10)
    return battleMash("wally_tutorial", 9000)
  end)
  toHub()

  scenario("slow text field mash", function()
    local a = F.sb2() + S.SaveBlock2.optionsU16
    F.w16(a, F.r16(a) & ~7)
    if not F.route({ { 6, 8 }, { 7, 8 } }, "wardrobe_sign") then return "skip", 0 end
    F.face("Up")
    return mash("slow_text", 2400, { A = 35, B = 25, Start = 25, Select = 5, dir = 25 })
  end)
  toHub()

  scenario("slow text battle mash", function()
    local a = F.sb2() + S.SaveBlock2.optionsU16
    F.w16(a, F.r16(a) & ~7)
    if not terminalMenu({ 1, 0, 0 }) then F.L("  terminal refused"); return "skip", 0 end
    return battleMash("roxanne_slow", 9000)
  end)
  toHub()

  scenario("tag battle with a partner mash", function()
    -- Lance's Rocket HQ multi battle, entered at its post-party-selection seam as
    -- LanceMultiBattle.lua does, then mashed through the Instant-text intro and the battle.
    if not F.warpTo(0, 9, 2, 0, 1, 4, 0, 0, 0, 92, 14, "rocket_hq") then return "skip", 0 end
    instantText()
    for i = 0, 2 do F.w8(S.gSelectedOrderFromParty + i, i + 1) end
    F.w8(S.sGlobalScriptContext, 0)
    F.w8(S.sGlobalScriptContext + 1, 1)
    F.w32(S.sGlobalScriptContext + 4, 0)
    F.w32(S.sGlobalScriptContext + S.ScriptCtx.scriptPtr, S.MahoganyHideout_B2F_EventScript_DoLanceMultiBattle)
    F.w8(S.sGlobalScriptContextStatus, 0)
    return battleMash("lance_multi", 12000)
  end)
  toHub()

  F.finish()
end)
