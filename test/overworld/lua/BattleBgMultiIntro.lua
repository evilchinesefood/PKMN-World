-- The Battle Tower multi battle intro slides in the battle's own background.
--
-- A multi battle beside a Battle Tower NPC partner opens with both teams facing the screen
-- (BattleIntroSlidePartner). LoadBattleEnvironmentEntryGfx draws that intro on BG1 and BG2 from
-- gMultiBattleIntroBg_Opponent/Player_Tilemap with char base 2, the tiles of the Frontier
-- background on BG3. Each intro tilemap is a crop of the building background tilemap: the
-- opponent half is its rows 0-9, the player half its rows 10-13 lowered six rows (BG2 then
-- scrolls up 48 px into place). PR #634 replaced the building tiles and tilemap, so intro tilemaps
-- cut from the old art name tiles the new 48-tile set does not have.
--
-- The suite takes the real Lv. 50 multi challenge, picks a partner in the partner room, rides to
-- the battle room and watches the intro. Oracle, read from VRAM while BG1 and BG2 use char base 2:
-- the opponent half (BG1, screen 28) shows the background's own rows 0-9 (BG3, screen 26), the
-- player half (BG2, screen 30) its rows 10-13 six rows lower, and no intro entry names a tile
-- past the background tileset.
--
-- Run via test/overworld/mgba-run.sh test/overworld/lua/BattleBgMultiIntro.lua

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "BattleBgMultiIntro")

local HUB_GROUP = 100
local FRONTIER = 26
local TOWER_LOBBY, PARTNER_ROOM = 5, 15
local SPECIES = { 1, 4, 7, 25, 152, 258 }
local BATTLE_TYPE_INGAME_PARTNER = 0x400000
local REG_BG1CNT, REG_BG2CNT = 0x0400000A, 0x0400000C
local VRAM = 0x06000000
local BG_TILE_COUNT = 48   -- graphics/battle_environment/building/tiles.png, the Frontier background

local function where() local x, y = F.pos(); return string.format("%d/%d (%d,%d)", F.grp(), F.mapn(), x, y) end

local function giveMon(species)
  local h, t, o = species // 100, (species // 10) % 10, species % 10
  F.dbg(); F.sel(3); F.sel(1); F.idle(20)
  F.spin(h, t, o); F.idle(20); F.spin(0, 3, 0); F.idle(60); F.bOut(4)
end

local function scriptMenuActive()
  for i = 0, S.Task.count - 1 do
    local a = S.gTasks + i * S.Task.stride
    local fn = F.r32(a + S.Task.func) & 0xFFFFFFFE
    if F.r8(a + S.Task.isActive) ~= 0
      and (fn == S.Task_HandleYesNoInput or fn == S.Task_HandleMultichoiceInput or fn == S.Task_CallYesOrNoCallback) then
      return true
    end
  end
  return false
end

local function menu(want, tag)
  for _ = 1, 80 do
    if scriptMenuActive() then
      F.idle(12)
      for _ = 1, 10 do
        local c = F.mcur()
        if c == want then
          F.shot(tag)
          F.press("A", 2); F.idle(40)
          return true
        end
        F.press(c > want and "Up" or "Down", 2); F.idle(12)
      end
      return false
    end
    F.press("A", 2); F.idle(25)
  end
  F.L("  menu " .. tag .. ": never opened")
  return false
end

local function inPartyMenu() return F.cb2() == (S.CB2_UpdatePartyMenu & ~1) end

local function choose(n)
  for _ = 1, 300 do
    if inPartyMenu() then break end
    F.press("A", 2); F.idle(20)
  end
  if not inPartyMenu() then return false end
  F.idle(60)
  for i = 1, n do
    F.press("A", 2); F.idle(30)
    F.press("A", 2); F.idle(40)
    if i < n then F.press("Down", 2); F.idle(20) end
  end
  F.press("Start", 2); F.idle(40)
  for _ = 1, 8 do
    if not inPartyMenu() then break end
    F.press("A", 2); F.idle(60)
  end
  return not inPartyMenu()
end

local function charBase(reg) return (F.r16(reg) >> 2) & 3 end
local function screenAddr(reg) return VRAM + ((F.r16(reg) >> 8) & 0x1F) * 0x800 end
local function entry(base, row, col) return F.r16(base + (row * 32 + col) * 2) end

-- Compare the intro halves with the background they slide into, for both 32-column screens.
local function checkIntro()
  local bg1, bg2, bg3 = screenAddr(REG_BG1CNT), screenAddr(REG_BG2CNT), VRAM + 26 * 0x800
  local oppBad, plyBad, maxTile, firstBad = 0, 0, 0, nil
  for s = 0, 1 do
    for r = 0, 31 do
      for c = 0, 31 do
        local e1 = F.r16(bg1 + s * 0x800 + (r * 32 + c) * 2)
        local e2 = F.r16(bg2 + s * 0x800 + (r * 32 + c) * 2)
        maxTile = math.max(maxTile, e1 & 0x3FF, e2 & 0x3FF)
        if r < 10 and e1 ~= F.r16(bg3 + s * 0x800 + (r * 32 + c) * 2) then
          oppBad = oppBad + 1
          firstBad = firstBad or string.format("BG1 s%d r%d c%d %04X vs BG3 %04X", s, r, c, e1, F.r16(bg3 + s * 0x800 + (r * 32 + c) * 2))
        end
        if r >= 16 and r < 20 and e2 ~= F.r16(bg3 + s * 0x800 + ((r - 6) * 32 + c) * 2) then
          plyBad = plyBad + 1
        end
      end
    end
  end
  return oppBad, plyBad, maxTile, firstBad
end

F.run(function()
  if not F.boot(HUB_GROUP) then F.check("boot to the hub", false); F.finish(); return end
  for _, sp in ipairs(SPECIES) do giveMon(sp) end
  F.check("six Pokemon in the party", F.r8(S.gPartiesCount) == 6, "n=" .. F.r8(S.gPartiesCount))

  if not F.warpTo(0, 2, 6, 0, 0, 5, 0, 0, 0, FRONTIER, TOWER_LOBBY, "tower lobby") then
    F.check("warped to the Battle Tower lobby", false); F.finish(); return
  end
  if not F.ensureFree() then F.dismiss(10) end
  F.check("walked to the multi battle attendant", F.route({ { 12, 8 }, { 14, 8 }, { 14, 6 } }, "multis attendant"), where())
  F.face("Up")
  F.press("A", 2); F.idle(40)
  local took = menu(0, "take_challenge") and menu(0, "level_50")
  F.check("took the Lv. 50 multi challenge", took)
  local chose = took and choose(2)
  F.check("chose two Pokemon", chose)
  F.check("agreed to save before the challenge", chose and menu(0, "save_before"))

  local arrived = false
  for i = 1, 6000 do
    if F.grp() == FRONTIER and F.mapn() == PARTNER_ROOM and F.ow() and i % 60 == 0 and F.ensureFree() then
      arrived = true
      break
    end
    if i % 40 == 1 then joypad.set({ A = true }) else joypad.set({}) end
    emu.frameadvance()
  end
  if not F.check("reached the partner room in control", arrived, where()) then F.finish(); return end

  -- Partner 5 stands still at (10,11) facing up; ask from the tile above it.
  F.check("walked above partner 5", F.leg(10, 10), where())
  F.face("Down")
  F.shot("partner_room")
  F.press("A", 2); F.idle(40)
  F.check("accepted the partner", menu(0, "accept_partner"))

  local started = false
  for i = 1, 9000 do
    if not F.ow() and F.battlers() > 0 then started = true; break end
    if F.reportCrash("to_battle") then break end
    if i % 40 == 1 then joypad.set({ A = true }) else joypad.set({}) end
    emu.frameadvance()
  end
  local flags = F.battleFlags()
  if not F.check("the multi battle with the NPC partner starts", started and (flags & BATTLE_TYPE_INGAME_PARTNER) ~= 0,
    string.format("flags=0x%X %s", flags, where())) then F.finish(); return end

  local seen, oppBad, plyBad, maxTile, firstBad = false, 0, 0, 0, nil
  for _ = 1, 900 do
    if charBase(REG_BG1CNT) == 2 and charBase(REG_BG2CNT) == 2 then
      F.idle(30)
      seen = true
      oppBad, plyBad, maxTile, firstBad = checkIntro()
      for i = 1, 4 do F.idle(40); F.shot("multi_intro_" .. i) end
      break
    end
    F.idle(1)
  end
  F.check("the partner intro draws BG1 and BG2 from char base 2", seen)
  F.check("the opponent half shows the background's rows 0-9", seen and oppBad == 0,
    string.format("%d entries differ%s", oppBad, firstBad and (", first " .. firstBad) or ""))
  F.check("the player half shows the background's rows 10-13 six rows lower", seen and plyBad == 0,
    string.format("%d entries differ", plyBad))
  F.check("no intro entry names a tile past the background tileset", seen and maxTile < BG_TILE_COUNT,
    string.format("max tile %d, tileset has %d", maxTile, BG_TILE_COUNT))
  F.idle(240)
  F.shot("after_intro")
  F.finish()
end)
