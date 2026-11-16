-- The seven special forms keep their themed types and abilities everywhere the game shows or uses
-- them: in battle (gBattleMons types and ability, both as the player's lead and as the wild
-- opponent), in the summary and the PC, and in the Pokedex form page. Each special form comes from
-- the debug Give menu; summaries, the PC, the Pokedex and every battle action are real input.
--
-- Run via: test/overworld/mgba-run.sh test/overworld/lua/SpecialFormsIdentity.lua <rom.gba>

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "SpecialFormsIdentity")

local MON = S.Pokemon.size
local BMON = S.BattlePokemon.size
local B_ABILITY, B_TYPES = 32, 34
local T = { NORMAL = 1, FIGHTING = 2, FLYING = 3, POISON = 4, GROUND = 5, ROCK = 6, BUG = 7, GHOST = 8,
            STEEL = 9, MYSTERY = 10, FIRE = 11, WATER = 12, GRASS = 13, ELECTRIC = 14, PSYCHIC = 15,
            ICE = 16, DRAGON = 17, DARK = 18, FAIRY = 19 }
local FORMS = {
  { name = "classic",     species = 1573, types = { T.ELECTRIC, T.ELECTRIC } },
  { name = "surfboard",   species = 1574, types = { T.ELECTRIC, T.WATER } },
  { name = "balloons",    species = 1575, types = { T.ELECTRIC, T.FLYING } },
  { name = "squad",       species = 1576, types = { T.WATER, T.DARK } },
  { name = "firefighter", species = 1577, types = { T.WATER, T.WATER } },
  { name = "flower",      species = 1578, types = { T.NORMAL, T.FAIRY } },
  { name = "pirate",      species = 1580, types = { T.WATER, T.GHOST } },
}

local function tap(key, n, wait) for _ = 1, (n or 1) do F.press(key, 2); F.idle(wait or 24) end end
local function flag(id, value)
  local a, bit = F.sb1() + S.SaveBlock1.flags + id // 8, 1 << (id % 8)
  if value ~= nil then F.w8(a, value and (F.r8(a) | bit) or (F.r8(a) & ~bit & 0xFF)) end
  return (F.r8(a) & bit) ~= 0
end
local function decode(i)
  local a = S.gParties + i * MON
  local pers, otid = F.r32(a), F.r32(a + 4)
  local key = pers ~ otid
  local w = {}
  for k = 0, 11 do w[k] = F.r32(a + 32 + k * 4) ~ key end
  local s0 = F.r8(S.sSubstructOffsets + pers % 24) * 3
  return { species = w[s0] & 0x7FF }
end

local function giveMon(species, lvT, lvO)
  local n = species - 1
  local d = { n // 1000, (n // 100) % 10, (n // 10) % 10, n % 10 }
  local before = F.r8(S.gPartiesCount)
  F.dbg(); F.sel(3); F.sel(1); F.idle(20)
  for _ = 1, 3 do tap("Right", 1, 8) end
  for _ = 1, 3 do tap("Down", 1, 8) end
  for i = 1, 4 do
    for _ = 1, d[i] do tap("Up", 1, 8) end
    if i < 4 then tap("Left", 1, 8) end
  end
  tap("A", 1, 45); F.idle(20)
  F.spin(0, lvT, lvO); F.idle(60); F.bOut(6)
  for _ = 1, 10 do if F.ensureFree() then break end F.press("B", 2); F.idle(20) end
  return F.r8(S.gPartiesCount) == before + 1
end

local SCRIPT_BUF = S.gStringVar4 + 960
local function le16(t, v) t[#t + 1] = v & 0xFF; t[#t + 1] = (v >> 8) & 0xFF end
local function runScript(b)
  for i, v in ipairs(b) do F.w8(SCRIPT_BUF + i - 1, v) end
  F.w8(S.sGlobalScriptContext, 0)
  F.w8(S.sGlobalScriptContext + 1, 1)
  F.w32(S.sGlobalScriptContext + 4, 0)
  F.w32(S.sGlobalScriptContext + S.ScriptCtx.scriptPtr, SCRIPT_BUF)
  F.w8(S.sGlobalScriptContextStatus, 0)
end
local function inBattle() return F.cb2() == (S.BattleMainCB2 & ~1) end
local function ctrl(b) return F.r32(S.gBattlerControllerFuncs + b * 4) & ~1 end
local function actionMenu()
  for _, p in ipairs(S.ActionInputFunctions) do if ctrl(0) == (p & ~1) then return true end end
  return false
end
local function bmon(b)
  local a = S.gBattleMons + b * BMON
  return { species = F.r16(a), ability = F.r16(a + B_ABILITY), t1 = F.r8(a + B_TYPES), t2 = F.r8(a + B_TYPES + 1) }
end

-- Party order is setup, not the behaviour under test: swap the lead with `slot` in RAM.
local function swapLead(slot)
  for o = 0, MON - 4, 4 do
    local x, y = F.r32(S.gParties + o), F.r32(S.gParties + slot * MON + o)
    F.w32(S.gParties + o, y); F.w32(S.gParties + slot * MON + o, x)
  end
end

local function battleAgainst(lead, wild)
  local w = { 0xB6 }
  le16(w, wild.species); w[#w + 1] = 10; le16(w, 0); le16(w, 0); w[#w + 1] = 0; le16(w, 0)
  w[#w + 1] = 0xB7; w[#w + 1] = 0x02
  runScript(w)
  local started = false
  for _ = 1, 1500 do
    F.idle(1)
    if inBattle() and F.battlers() >= 2 then started = true; break end
  end
  local tag = lead.name .. "_vs_" .. wild.name
  F.check(tag .. ": battle started", started)
  for _ = 1, 600 do if actionMenu() then break end F.press("B", 2); F.idle(10) end
  F.idle(30)
  local p, o = bmon(0), bmon(1)
  F.check(tag .. ": lead types", p.species == lead.species and p.t1 == lead.types[1] and p.t2 == lead.types[2],
    string.format("species %d types %d/%d", p.species, p.t1, p.t2))
  F.check(tag .. ": wild types", o.species == wild.species and o.t1 == wild.types[1] and o.t2 == wild.types[2],
    string.format("species %d types %d/%d", o.species, o.t1, o.t2))
  F.shot(tag .. "_action")
  tap("A", 1, 40)                                  -- Fight: the move menu shows the type indicators
  F.shot(tag .. "_moves")
  tap("B", 1, 30)
  -- Run (bottom right of the action menu).
  for _ = 1, 8 do
    local c = F.r8(S.gActionSelectionCursor)
    if c == 3 then break end
    if (c & 1) == 0 then tap("Right", 1, 14) else tap("Down", 1, 14) end
  end
  tap("A", 1, 30)
  for _ = 1, 600 do
    if F.ow() and not inBattle() then break end
    F.press("B", 2); F.idle(10)
  end
  F.idle(30)
  for _ = 1, 10 do if F.ensureFree() then break end F.press("B", 2); F.idle(20) end
  F.check(tag .. ": ran back to the field", F.ow(), "outcome " .. F.outcome())
  return p, o
end


local function taskRunning(fn)
  for i = 0, S.Task.count - 1 do
    local task = S.gTasks + i * S.Task.stride
    if F.r8(task + S.Task.isActive) ~= 0 and (F.r32(task + S.Task.func) & ~1) == (fn & ~1) then return true end
  end
  return false
end
local function toField()
  for _ = 1, 40 do if F.ow() then break end tap("B", 1, 40) end
  for _ = 1, 10 do if F.ensureFree() then break end F.press("B", 2); F.idle(20) end
  F.idle(30)
  return F.ow()
end
-- Pokedex list row `index` (national order), Info, Evos, Forms; Right to the last form, Left
-- `back` times, A opens that form's info page.
local function dexForm(index, back, tag)
  F.press("Start", 2); F.idle(60)
  if not F.selectStartIcon(0) then return false end
  F.press("A", 2); F.idle(240)
  tap("Start", 1, 40); tap("Down", 1, 20); tap("A", 1, 60)
  for _ = 1, index do F.press("Down", 2); F.idle(12) end
  F.idle(40)
  tap("A", 1, 100)
  tap("Right", 3, 70)
  tap("Start", 1, 30)
  local forms = false
  for _ = 1, 300 do if taskRunning(S.Task_HandleFormsScreenInput) then forms = true; break end F.idle(2) end
  F.idle(40)
  tap("A", 1, 40)
  tap("Right", 20, 12)
  tap("Left", back, 20)
  F.shot(tag .. "_forms")
  tap("A", 1, 120)
  F.shot(tag .. "_dex_info")
  local ok = toField()
  return forms and ok
end

local function summary(slot, tag)
  F.press("Start", 2); F.idle(60)
  if not F.selectStartIcon(1) then return false end
  F.press("A", 2); F.idle(90)
  tap("Down", slot, 16); tap("A", 1, 50)
  tap("A", 1, 120)
  F.shot(tag .. "_summary_1")
  tap("Right", 1, 90); F.shot(tag .. "_summary_2")
  tap("Right", 1, 90); F.shot(tag .. "_summary_3")
  for _ = 1, 6 do F.press("B", 2); F.idle(60); if F.ow() then break end end
  for _ = 1, 20 do if F.ensureFree() then break end F.press("B", 2); F.idle(20) end
  return F.ow()
end

F.run(function()
  assert(F.boot(100), "Fresh game did not boot")
  local opt = F.sb2() + S.SaveBlock2.optionsU16
  F.w16(opt, (F.r16(opt) & ~7) | 3)
  flag(0x949, true)
  F.dbg(); F.sel(7); F.sel(2); F.idle(60); F.bOut(4)   -- Pokedex Flags All (types show in battle)

  for i = 1, 6 do
    F.check("setup: " .. FORMS[i].name .. " given", giveMon(FORMS[i].species, 9, 9))
  end
  for i = 1, 6 do
    F.check("party slot " .. i .. " is " .. FORMS[i].name, decode(i - 1).species == FORMS[i].species,
      "species " .. decode(i - 1).species)
  end

  local only = os.getenv("PW_ID_ONLY")
  if not only then
  for i = 1, 6 do F.check(FORMS[i].name .. ": summary opens and closes", summary(i - 1, FORMS[i].name)) end

  -- Each form leads once against the next form as the wild opponent; Pirate Totodile is the wild
  -- opponent of the last round and Classic Cap Pikachu of a Pirate-free round.
  for i = 1, 6 do
    if i > 1 then swapLead(i - 1) end
    local lead = FORMS[i]
    F.check(lead.name .. " leads", decode(0).species == lead.species, "species " .. decode(0).species)
    local wild = FORMS[(i % 7) + 1]
    battleAgainst(lead, wild)
  end
  end

  -- Pokedex form info pages (national dex on, every flag set as the Dex capture does).
  F.dbg(); F.sel(7); F.sel(5); F.idle(60); F.bOut(4)   -- Toggle National Dex
  F.w8(F.sb2() + 0x19, 1)
  F.idle(30)
  local DEX = {
    { "classic", 24, 2 }, { "surfboard", 24, 1 }, { "balloons", 24, 0 },
    { "squad", 6, 1 }, { "firefighter", 6, 0 }, { "flower", 132, 0 }, { "pirate", 157, 0 },
  }
  for _, d in ipairs(DEX) do F.check(d[1] .. ": Pokedex form page", dexForm(d[2], d[3], d[1])) end

  -- The seventh form goes to the PC; the PC shows its types while the cursor is on it.
  F.check("setup: pirate given to the PC", giveMon(FORMS[7].species, 9, 9) or F.r8(S.gPartiesCount) == 6)
  local function pcMenuLive() return F.ow() and F.rs8(S.sMenu + S.Menu.maxCursorPos) == 4 end
  F.w8(S.sMenu + 2, 0); F.w8(S.sMenu + S.Menu.maxCursorPos, 0)
  F.dbg(); F.idle(60)
  F.press("Down", 3); F.idle(16); F.press("A", 3); F.idle(60)
  F.press("A", 3); F.idle(60)
  for _ = 1, 200 do if pcMenuLive() then break end F.press("A", 2); F.idle(18) end
  F.check("PC menu opens", pcMenuLive())
  F.idle(20)
  for _ = 1, 4 do if F.mcur() == 0 then break end F.press("Up", 2); F.idle(14) end
  F.press("A", 2); F.idle(200)                          -- Move Pokemon: cursor on box 1 slot 1
  F.shot("pirate_pc")
  tap("Left", 1, 60); F.shot("pc_party_column")
  F.check("back on the field after the PC", toField())
  F.finish()
end)
