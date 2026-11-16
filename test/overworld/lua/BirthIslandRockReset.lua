-- Leaving Birth Island in the middle of the Deoxys puzzle must start it over on the next visit.
--
-- With a real Pokemon in the party the player touches the stone once (it climbs to level 1 and
-- moves), walks out to the harbor and back in. The map's transition script must reset the stone's
-- level and step count, so the stone stands on its first tile at level 0 and the first touch moves
-- it to level 1 again, instead of failing on the steps walked since the last visit. Kanto's Birth
-- Island (reached by the Seagallop) and Hoenn's, which is the control, both walk out and in for real.
--
-- Run via test/overworld/mgba-run.sh test/overworld/lua/BirthIslandRockReset.lua <rom>

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "BirthIslandRockReset")

local HUB = { 100, 0 }
local ISLANDS = {
  { tag = "kanto", map = { 36, 56 }, harbor = { 36, 58 } },
  { tag = "hoenn", map = { 26, 58 }, harbor = { 26, 59 } },
}
local SPECIES_MEWTWO, MOVE_PSYCHIC = 150, 94
local VAR_DEOXYS_ROCK_STEP_COUNT, VAR_DEOXYS_ROCK_LEVEL = 0x4034, 0x4035
local CONTEXT_RUNNING = 0

local function where() local x, y = F.pos(); return string.format("%d/%d (%d,%d)", F.grp(), F.mapn(), x, y) end
local function varGet(id) return F.r16(F.sb1() + S.SaveBlock1.vars + (id - 0x4000) * 2) end
local function mapIs(m) return F.grp() == m[1] and F.mapn() == m[2] end
local function d(n) return (n // 100) % 10, (n // 10) % 10, n % 10 end
local function warp(g, m, w, tag)
  local gh, gt, go = d(g)
  local mh, mt, mo = d(m)
  local wh, wt, wo = d(w)
  return F.warpTo(gh, gt, go, mh, mt, mo, wh, wt, wo, g, m, tag)
end

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
local function createMon(species, level, moves)
  local b = { 0x23 }; le32(b, S.ScrCmd_createmon | 1)
  b[#b + 1] = 0; b[#b + 1] = 6
  le16(b, species); le16(b, level)
  le32(b, (1 << 17) | (1 << 18) | (1 << 19) | (1 << 20))
  for k = 1, 4 do le16(b, moves[k] or 0) end
  b[#b + 1] = 0x02
  runScript(b)
  return F.r8(S.gPartiesCount)
end
local function hasControl()
  return F.ow() and F.r8(S.sLockFieldControls) == 0 and F.r8(S.sGlobalScriptContextStatus) ~= CONTEXT_RUNNING
end
local function walkTo(tx, ty, tag)
  for _ = 1, 60 do
    local x, y = F.pos()
    if x == tx and y == ty then return true end
    local dir
    if x < tx then dir = "Right" elseif x > tx then dir = "Left"
    elseif y < ty then dir = "Down" else dir = "Up" end
    if not F.step(dir) then F.L("  walk " .. tag .. " blocked at " .. where()); return false end
  end
  return false
end
local function awaitMap(m)
  for _ = 1, 400 do
    if mapIs(m) and hasControl() then F.idle(30); return true end
    F.idle(1)
  end
  return mapIs(m)
end
local function touch()
  F.press("A", 3)
  for _ = 1, 400 do
    if hasControl() and F.r8(S.sGlobalScriptContextStatus) ~= CONTEXT_RUNNING then break end
    F.idle(1)
  end
  F.idle(90)
  for _ = 1, 200 do if hasControl() then break end; F.idle(1) end
  return varGet(VAR_DEOXYS_ROCK_LEVEL)
end

local function island(isl)
  local tag = isl.tag
  F.check(tag .. ": warped to the harbor", warp(isl.harbor[1], isl.harbor[2], 0, tag .. "_harbor"), where())
  F.idle(30)
  F.press("Up", 20)
  F.check(tag .. ": walked onto Birth Island", awaitMap(isl.map), where())
  F.check(tag .. ": stood below the stone", walkTo(15, 13, tag), where())
  F.face("Up")
  F.check(tag .. ": the first touch climbs to level 1", touch() == 1, "level=" .. varGet(VAR_DEOXYS_ROCK_LEVEL))
  F.check(tag .. ": walked back to the landing", walkTo(15, 24, tag .. "_out"), where())
  F.press("Down", 20)
  F.check(tag .. ": walked out to the harbor", awaitMap(isl.harbor), where())
  F.press("Up", 20)
  F.check(tag .. ": walked back onto Birth Island", awaitMap(isl.map), where())
  F.check(tag .. ": the stone is back at level 0", varGet(VAR_DEOXYS_ROCK_LEVEL) == 0,
    "level=" .. varGet(VAR_DEOXYS_ROCK_LEVEL))
  F.check(tag .. ": the step count starts over", varGet(VAR_DEOXYS_ROCK_STEP_COUNT) == 0,
    "steps=" .. varGet(VAR_DEOXYS_ROCK_STEP_COUNT))
  F.check(tag .. ": stood below the stone again", walkTo(15, 13, tag .. "_again"), where())
  F.face("Up")
  F.shot(tag .. "_before_touch")
  local level = touch()
  F.shot(tag .. "_after_touch")
  F.check(tag .. ": the first touch of the new visit climbs to level 1", level == 1, "level=" .. level)
end

F.run(function()
  if not F.boot(HUB[1]) then F.check("boot", false); F.finish(); return end
  F.check("setup: a Pokemon that can fight", createMon(SPECIES_MEWTWO, 100, { MOVE_PSYCHIC }) == 1)
  for _, isl in ipairs(ISLANDS) do island(isl) end
  F.finish()
end)
