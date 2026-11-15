-- An Egg-only party (a World Transit gate boxes the party; a gift Egg can be all that is left) has
-- nothing to fight with, so 0829014ec0 refuses scripted wild battles with "You don't have a single
-- POKéMON" and leaves the encounter exactly as it was. Two encounters, both on real input:
--   * the Power Plant's Electrode 1, refused inside the battle starter (BattleSetup_Start...):
--     the Electrode must stay and its flags must stay clear;
--   * Ilex Forest's GS Ball shrine, whose script cleared Celebi's hide flag and spawned it before
--     reaching the battle: the refusal must leave Celebi hidden and the shrine still armed.
-- Setup gives the Egg with the giveegg script command and sets the post-game Azalea state.
local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "EggOnlyStaticRefusal")

-- Ilex Forest from the Route 34 gate, round the pond and the Farfetch'd loop.
local ILEX_TO_SHRINE = {{19,14},{23,14},{23,16},{37,16},{37,13},{42,13},{42,10},{43,10},{43,9},{53,9},{53,10},
  {55,10},{55,12},{53,12},{53,18},{47,18},{47,19},{44,19},{44,20},{35,20},{35,22},{32,22},{32,24},{26,24},
  {26,25},{25,25},{25,26},{24,26},{24,28},{22,28},{22,29},{18,29},{18,38},{31,38},{31,36}}
local ILEX_TO_CELEBI_STUB = {}
for i = 1, 32 do ILEX_TO_CELEBI_STUB[i] = ILEX_TO_SHRINE[i] end
ILEX_TO_CELEBI_STUB[33] = {18,33}
local POWER_PLANT, ILEX_FOREST, HUB = {35, 95}, {80, 3}, {100, 0}
local ELECTRODE_X, ELECTRODE_Y = 30, 38
local CELEBI_X, CELEBI_Y = 24, 33
local FLAG_HIDE_ELECTRODE_1, FLAG_FOUGHT_ELECTRODE_1 = 0xA40 + 0x85, 0xA40 + 0x2D0
local SPECIES_TOGEPI = 175
local VAR_AZALEA_TOWN_STATE = 0xA08C
local CONTEXT_RUNNING = 0

local function where() local x, y = F.pos(); return string.format("%d/%d (%d,%d)", F.grp(), F.mapn(), x, y) end
local function count() return F.r8(S.gPartiesCount) end
local function flagAddr(id)
  if id >= 0x6000 and id < 0x6400 then return F.sb3() + S.SaveBlock3.johtoFlags + (id - 0x6000) // 8, (id - 0x6000) % 8 end
  return F.sb1() + S.SaveBlock1.flags + id // 8, id % 8
end
local function flagGet(id) local a, b = flagAddr(id); return (F.r8(a) & (1 << b)) ~= 0 end
local function varSet(id, v) F.w16(F.sb3() + S.SaveBlock3.regionVars + (id - 0xA000) * 2, v) end
local function varGet(id) return F.r16(F.sb3() + S.SaveBlock3.regionVars + (id - 0xA000) * 2) end
local function objectAt(x, y)
  for _, o in ipairs(F.objdump()) do if o.x == x and o.y == y then return true end end
  return false
end

local FLAG_HIDE_CELEBI
do
  -- FLAG_HIDE_CELEBI is a Johto-bank flag; read it from the generated header rather than guess.
  local f = io.open(here .. "../../../include/constants/johto_flags.h", "r")
  local src = f and f:read("a") or ""
  if f then f:close() end
  local n = src:match("#define%s+FLAG_HIDE_CELEBI%s+FLAG_JOHTO_SLICE%((0x%x+)%)")
  FLAG_HIDE_CELEBI = n and (0x6000 + tonumber(n)) or nil
end

local SCRIPT_BUF = S.gStringVar4 + 960
local function le16(t, v) t[#t + 1] = v & 0xFF; t[#t + 1] = (v >> 8) & 0xFF end
local function runScript(bytes)
  for i, b in ipairs(bytes) do F.w8(SCRIPT_BUF + i - 1, b) end
  F.w8(S.sGlobalScriptContext, 0)
  F.w8(S.sGlobalScriptContext + 1, 1)
  F.w32(S.sGlobalScriptContext + 4, 0)
  F.w32(S.sGlobalScriptContext + S.ScriptCtx.scriptPtr, SCRIPT_BUF)
  F.w8(S.sGlobalScriptContextStatus, CONTEXT_RUNNING)
  F.idle(20)
end
local function giveEgg(species) local b = { 0x7A }; le16(b, species); b[#b + 1] = 0x02; runScript(b) end

-- Visible wild Pokemon that spawn in Ilex Forest's one-tile passages block the walk and are not
-- under test, so the walks hold the spawn countdown up (the existing harness symbol for it).
local suppressOWE = false
do
  local frameadvance = emu.frameadvance
  emu.frameadvance = function()
    if suppressOWE then F.w8(S.sOWESpawnCountdown, 200) end
    frameadvance()
  end
end

local function hasControl()
  return F.ow() and F.r8(S.sLockFieldControls) == 0 and F.r8(S.sGlobalScriptContextStatus) ~= CONTEXT_RUNNING
end

-- Random encounters on the walks: an Egg-only party is refused those too; just wait them out.
local function walk(pts, tag)
  local blocked = 0
  for _, p in ipairs(pts) do
    for _ = 1, 140 do
      if not F.ow() then
        for _ = 1, 1500 do F.press("B", 2); F.idle(8); if F.ow() then break end end
      end
      local x, y = F.pos()
      if x == p[1] and y == p[2] then break end
      local dir
      if x < p[1] then dir = "Right" elseif x > p[1] then dir = "Left"
      elseif y < p[2] then dir = "Down" else dir = "Up" end
      if not F.step(dir) and F.ow() and hasControl() then
        -- A visible wild Pokemon wandering into the path moves on; a wall does not.
        blocked = blocked + 1
        if blocked > 8 then
          F.L(string.format("  walk %s blocked %s at %s", tag, dir, where()))
          for _, o in ipairs(F.objdump()) do F.L(string.format("    obj %d at (%d,%d)", o.i, o.x, o.y)) end
          F.shot(tag .. "_blocked"); return false
        end
        F.idle(45)
      else
        blocked = 0
      end
      if not hasControl() and F.ow() then
        for _ = 1, 20 do F.press("B", 2); F.idle(20); if hasControl() then break end end
      end
    end
    local x, y = F.pos()
    if x ~= p[1] or y ~= p[2] then return false end
  end
  return true
end

-- Interact, mash A/B/Start (or A/Start) through whatever follows, and report whether a battle ever started and
-- whether control came back. Start is pressed only while a script runs (the field ignores it).
local function interactAndMash(tag, useB)
  F.press("A", 3)
  local sawBattle, freed = false, false
  for i = 1, 1800 do
    if not F.ow() then sawBattle = true end
    local k = i % 30
    if k == 0 then F.press("A", 2) elseif k == 10 and useB then F.press("B", 2)
    elseif k == 20 and not hasControl() then F.press("Start", 2) else F.idle(1) end
    if i == 90 then F.shot(tag .. "_message") end
    if i > 300 and hasControl() then freed = true; break end
    if i % 300 == 0 and F.reportCrash(tag) then break end
  end
  F.idle(30)
  return sawBattle, freed and hasControl()
end

F.run(function()
  if not F.boot(HUB[1]) then F.check("boot", false); F.finish(); return end
  giveEgg(SPECIES_TOGEPI)
  F.check("setup: the party is one Egg", count() == 1, "n=" .. count())
  F.check("setup: FLAG_HIDE_CELEBI found in johto_flags.h", FLAG_HIDE_CELEBI ~= nil)
  if count() ~= 1 or not FLAG_HIDE_CELEBI then F.finish(); return end

  -- Electrode 1: the battle starter refuses.
  F.check("warped into the Power Plant", F.warpTo(0, 3, 5, 0, 9, 5, 0, 0, 0, POWER_PLANT[1], POWER_PLANT[2], "power_plant"), where())
  local ok = walk({{4,37},{6,37},{6,28},{3,28},{3,23},{9,23},{9,19},{14,19},{14,22},{13,22},{13,26},
                   {17,26},{17,31},{15,31},{15,36},{17,36},{17,38},{29,38}}, "to_electrode")
  F.check("walked to the tile west of Electrode 1", ok, where())
  if ok then
    F.face("Right")
    local battle, freed = interactAndMash("electrode", true)
    F.check("Electrode: no battle started", not battle)
    F.check("Electrode: control returns", freed, string.format("lock=%d ctx=%d", F.r8(S.sLockFieldControls), F.r8(S.sGlobalScriptContextStatus)))
    F.check("Electrode: it is still standing there", objectAt(ELECTRODE_X, ELECTRODE_Y))
    F.check("Electrode: its hide and fought flags stay clear",
      not flagGet(FLAG_HIDE_ELECTRODE_1) and not flagGet(FLAG_FOUGHT_ELECTRODE_1))
  end

  -- Ilex Forest's shrine with the GS Ball (Azalea state 9).
  varSet(VAR_AZALEA_TOWN_STATE, 9)
  suppressOWE = true
  F.check("warped into Ilex Forest", F.warpTo(0, 8, 0, 0, 0, 3, 0, 0, 1, ILEX_FOREST[1], ILEX_FOREST[2], "ilex"), where())
  local hideBefore = flagGet(FLAG_HIDE_CELEBI)
  ok = walk(ILEX_TO_SHRINE, "to_shrine")
  F.check("walked to the shrine", ok, where())
  if ok then
    F.face("Right")
    -- A and Start only: B would answer the GS Ball question NO.
    local battle, freed = interactAndMash("shrine", false)
    F.shot("shrine_after")
    F.check("Shrine: no battle started", not battle)
    F.check("Shrine: control returns", freed, string.format("lock=%d ctx=%d", F.r8(S.sLockFieldControls), F.r8(S.sGlobalScriptContextStatus)))
    F.check("Shrine: Celebi's hide flag is untouched", hideBefore and flagGet(FLAG_HIDE_CELEBI),
      string.format("before=%s after=%s", tostring(hideBefore), tostring(flagGet(FLAG_HIDE_CELEBI))))
    F.check("Shrine: the GS Ball event is still armed", varGet(VAR_AZALEA_TOWN_STATE) == 9, "state=" .. varGet(VAR_AZALEA_TOWN_STATE))
    -- Leave and come back: no scriptless Celebi left standing by the shrine.
    F.warpTo(1, 0, 0, 0, 0, 0, 0, 0, 0, HUB[1], HUB[2], "hub")
    F.warpTo(0, 8, 0, 0, 0, 3, 0, 0, 1, ILEX_FOREST[1], ILEX_FOREST[2], "ilex2")
    walk(ILEX_TO_CELEBI_STUB, "look")
    F.shot("celebi_tile_after_reload")
    F.check("after a reload no Celebi stands at (24,33)", not objectAt(CELEBI_X, CELEBI_Y))
  end
  F.finish()
end)
