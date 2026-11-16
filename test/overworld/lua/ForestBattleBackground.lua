-- Battles in a forest draw a tree-line background, not the open-field tall grass one. The forest art is
-- presentation only: gBattleEnvironment, which drives Nature Power, Secret Power and Camouflage, keeps
-- the value the player's tile gives it.
--
-- Route 2 is the control: a wild battle in its grass must still draw the tall grass art. In Viridian
-- Forest the suite starts a wild battle (setwildbattle/dowildbattle) while the player stands on a grass
-- tile, so BattleSetup_GetEnvironmentId reads that real tile, then walks up the path into Bug Catcher
-- Rick's line of sight with real input. At each battle's action menu it reads gBattleEnvironment and the
-- captured sBattlePresentation (background tiles, entry tiles, palette), checks the palette bank BG3 drew
-- from in VRAM and takes a screenshot.
--
-- Run via test/overworld/mgba-run.sh test/overworld/lua/ForestBattleBackground.lua <rom>

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "ForestBattleBackground")

local HUB_GROUP = 100
local ROUTE2 = { 37, 20 }
local VIRIDIAN_FOREST = { 35, 0 }
local BATTLE_ENVIRONMENT_GRASS, BATTLE_ENVIRONMENT_PLAIN = 0, 9
local SPECIES_MEWTWO, SPECIES_CATERPIE = 150, 10
local MOVE_PSYCHIC = 94
local BATTLE_TYPE_TRAINER = 8
local OBEDIENT_LEVEL = 10 -- B_OBEDIENCE_MECHANICS GEN_LATEST: one met above the badge cap disobeys

local PRESENTATION = { backgroundTiles = 0, entryTiles = 8, palette = 16 }
-- BG3's tilemap lives in screen block 26. The tall grass art fills its row 0 from palette bank 2,
-- the forest tree line from bank 4.
local BG3_ROW0 = 0x06000000 + 26 * 0x800

local function digits(n) n = n - 1; return n // 100, (n // 10) % 10, n % 10 end
local function warp(m, tag)
  local function d(n) return n // 100, (n // 10) % 10, n % 10 end
  local gh, gt, go = d(m[1]); local mh, mt, mo = d(m[2])
  return F.warpTo(gh, gt, go, mh, mt, mo, 0, 0, 0, m[1], m[2], tag)
end

local function inBattle() return F.cb2() == (S.BattleMainCB2 & ~1) end
local function ctrl(b) return F.r32(S.gBattlerControllerFuncs + b * 4) & ~1 end
local function actionMenu()
  for _, p in ipairs(S.ActionInputFunctions) do if ctrl(0) == (p & ~1) then return true end end
  return false
end

local SCRIPT_BUF = S.gStringVar4 + 960
local function runScript(b)
  for i, v in ipairs(b) do F.w8(SCRIPT_BUF + i - 1, v) end
  F.w8(S.sGlobalScriptContext, 0)
  F.w8(S.sGlobalScriptContext + 1, 1)
  F.w32(S.sGlobalScriptContext + 4, 0)
  F.w32(S.sGlobalScriptContext + S.ScriptCtx.scriptPtr, SCRIPT_BUF)
  F.w8(S.sGlobalScriptContextStatus, 0)
end

local SUB1 = { [0]=1,1,2,3,2,3,0,0,0,0,0,0,2,3,1,1,3,2,2,3,1,1,3,2 }
local function setMove1(move)
  local mon = S.gParties
  local key = F.r32(mon) ~ F.r32(mon + 4)
  local function x() for i = 0, 11 do local a = mon + 32 + i * 4; F.w32(a, F.r32(a) ~ key) end end
  x()
  local sub = mon + 32 + SUB1[F.r32(mon) % 24] * 12
  F.w16(sub, (F.r16(sub) & 0xF800) | move)
  F.w8(sub + 8, (F.r8(sub + 8) & 0x80) | 10)
  local sum = 0
  for i = 0, 11 do local w = F.r32(mon + 32 + i * 4); sum = (sum + w + (w >> 16)) & 0xFFFFFFFF end
  F.w16(mon + 28, sum & 0xFFFF)
  x()
end

local function waitActionMenu(tag)
  for _ = 1, 4000 do
    if inBattle() and actionMenu() then F.idle(30); return true end
    if F.reportCrash(tag) then return false end
    F.press("A", 2); F.idle(10)
  end
  return false
end

local function topLeftThenA()
  F.press("Up", 2); F.idle(6); F.press("Left", 2); F.idle(6); F.press("A", 2); F.idle(10)
end

local function finishBattle()
  for f = 1, 30000 do
    if inBattle() then
      local fn = ctrl(0)
      if f % 12 ~= 0 then
        F.idle(1)
      elseif fn == (S.PlayerHandleYesNoInput & ~1) then
        F.press("B", 2)
      elseif actionMenu() or fn == (S.HandleInputChooseMove & ~1) then
        topLeftThenA()
      else
        F.press("A", 2)
      end
    elseif F.ow() then
      break
    elseif f % 20 == 0 then
      F.press("A", 2)
    else
      F.idle(1)
    end
  end
  F.idle(60)
  local free = F.dismiss(20)
  if not free then F.shot("not_free") end
  return free
end

local function presentation()
  local p = S.sBattlePresentation
  return {
    env = F.r8(S.gBattleEnvironment),
    background = F.r32(p + PRESENTATION.backgroundTiles),
    entry = F.r32(p + PRESENTATION.entryTiles),
    palette = F.r32(p + PRESENTATION.palette),
    vramBank = F.r16(BG3_ROW0) >> 12,
  }
end
local function fmt(v)
  return string.format("env=%d background=%08X entry=%08X palette=%08X bg3bank=%d", v.env, v.background, v.entry,
    v.palette, v.vramBank)
end
local function tallGrassArt(v)
  return v.background == S.gBattleEnvironmentTiles_TallGrass and v.palette == S.gBattleEnvironmentPalette_TallGrass
    and v.vramBank == 2
end
local function forestArt(v)
  return v.background ~= S.gBattleEnvironmentTiles_TallGrass and v.palette ~= S.gBattleEnvironmentPalette_TallGrass
    and v.entry == S.gBattleEnvironmentAnimTiles_TallGrass and v.vramBank == 4
end

local function wildBattleHere(tag)
  runScript({ 0xB6, SPECIES_CATERPIE & 0xFF, SPECIES_CATERPIE >> 8, 3, 0, 0, 0, 0, 0, 0, 0, 0xB7, 0x02 })
  local ok = waitActionMenu(tag)
  local v = presentation()
  F.shot(tag)
  F.L("  " .. tag .. ": " .. fmt(v))
  return ok, v
end

F.run(function()
  if not F.boot(HUB_GROUP) then F.check("boot to the hub", false); F.finish(); return end
  for off = 0, 6 * S.Pokemon.size - 4, 4 do F.w32(S.gParties + off, 0) end
  F.w8(S.gPartiesCount, 0)
  F.dbg(); F.idle(30); F.bOut(4)
  F.dbg(); F.sel(3); F.sel(1); F.idle(20); F.spin(digits(SPECIES_MEWTWO)); F.idle(20); F.spin(digits(OBEDIENT_LEVEL)); F.idle(60); F.bOut(4)
  F.check("setup: a Mewtwo leads", F.r8(S.gPartiesCount) == 1)
  setMove1(MOVE_PSYCHIC)

  F.check("setup: warp to Route 2", warp(ROUTE2, "route2"))
  F.check("Route 2: walk into the grass north of the forest gate", F.route({ { 5, 12 }, { 5, 8 } }, "route2_grass"))
  local ok, v = wildBattleHere("route2_wild")
  F.check("Route 2: the wild battle reached the action menu", ok)
  F.check("Route 2: grass keeps its grass environment", v.env == BATTLE_ENVIRONMENT_GRASS, fmt(v))
  F.check("Route 2: open grass still draws the tall grass art", tallGrassArt(v), fmt(v))
  F.check("Route 2: the battle ended back on the field", finishBattle())

  F.check("setup: warp to Viridian Forest", warp(VIRIDIAN_FOREST, "forest"))
  F.check("Viridian Forest: walk into the grass by the south gate", F.route({ { 29, 61 }, { 25, 61 }, { 25, 58 } }, "forest_grass"))
  ok, v = wildBattleHere("forest_wild")
  F.check("Viridian Forest: the wild battle reached the action menu", ok)
  F.check("Viridian Forest: grass keeps its grass environment", v.env == BATTLE_ENVIRONMENT_GRASS, fmt(v))
  F.check("Viridian Forest: the wild battle draws forest art with the grass entry slide", forestArt(v), fmt(v))
  local wild = v
  F.check("Viridian Forest: the wild battle ended back on the field", finishBattle())

  -- A wandering overworld Pokemon can bump into the player on the way; finish that battle and walk on.
  for attempt = 1, 4 do
    F.route({ { 25, 61 }, { 42, 61 }, { 42, 46 } }, "forest_path")
    F.step("Up")
    ok = waitActionMenu("rick")
    if not ok or (F.battleFlags() & BATTLE_TYPE_TRAINER) ~= 0 then break end
    F.L(string.format("  attempt %d met a wild Pokemon on the path at env=%d", attempt, F.r8(S.gBattleEnvironment)))
    finishBattle()
  end
  v = presentation()
  F.shot("forest_trainer")
  F.L("  forest_trainer: " .. fmt(v))
  F.check("Viridian Forest: Rick's sight started a trainer battle", ok and (F.battleFlags() & BATTLE_TYPE_TRAINER) ~= 0,
    string.format("flags=%08X", F.battleFlags()))
  F.check("Viridian Forest: the path keeps its plain environment", v.env == BATTLE_ENVIRONMENT_PLAIN, fmt(v))
  F.check("Viridian Forest: the trainer battle draws the same forest art", forestArt(v)
    and v.background == wild.background and v.palette == wild.palette, fmt(v))
  F.check("Viridian Forest: the trainer battle ended back on the field", finishBattle())
  F.check("no crash screen", not F.crashScreen())
  F.finish()
end)
