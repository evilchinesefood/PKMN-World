-- Family options (#383/#387) opened from every field state the Options screen can interrupt.
--
-- The main menu Options screen runs before New Game and again before Continue. The Start menu
-- Options screen runs with a follower out, with a Repel counting down, in Cianwood's rain and
-- while surfing in Dragon's Den. Each visit walks every row Right then Left, then leaves the
-- family rates and text speed on a different column than the visit before, so all four values
-- of each preference are written once from the field. Every return is compared against a
-- snapshot taken just before Start: map, tile, facing, avatar flags, live object events and the
-- follower, the playing song, the Repel count and the unfaded BG and OBJ palettes.
--
-- Run: test/overworld/mgba-run.sh test/overworld/lua/FamilyOptionsFieldStress.lua pokemonworld.gba

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "FamilyOptionsFieldStress")

local ID_PLAYER, ID_FOLLOWER = 255, 254
local VARS_START, VAR_REPEL_STEP_COUNT = 0x4000, 0x4021
local AVATAR_SURFING, AVATAR_CONTROLLABLE = 1 << 3, 1 << 5
local ITEM_SURF_TOOL = 876
local GRP_INDOOR_BLACKTHORN, MAP_DRAGONS_DEN_CAVERN = 94, 12
local GRP_CIANWOOD, MAP_CIANWOOD = 89, 0
local FLAG_HIDE_DEN = { 0x6000 + 0x169, 0x6000 + 0x16A, 0x6000 + 0x16B, 0x6000 + 0x1B3 }
local DEN_TRAINERS = { 1005, 1008, 1014 }
local OPTION_ROWS = 13

-- column order on screen is 0.5x, 1x, 1.5x, 2x; each preference stores its own value per column
local RATES = {
  { name = "Exp Rate", row = 8, slot = 13, byColumn = { 1, 0, 2, 3 }, shift = 0 },
  { name = "Catch Rate", row = 9, slot = 14, byColumn = { 3, 0, 1, 2 }, shift = 2 },
  { name = "Encounter Rate", row = 10, slot = 2, byColumn = { 1, 0, 2, 3 }, shift = 6 },
  { name = "Money Loss", row = 11, slot = 4, byColumn = { 1, 0, 2, 3 }, shift = 8 },
}

local function tap(key) F.press(key, 2); F.idle(12) end
local function optWord(off) return F.r16(F.sb2() + S.SaveBlock2.optionsU16 + off) end
local function textSpeed() return optWord(0) & 7 end
local function rateValue(r) return (optWord(2) >> r.shift) & 3 end

local function optionTask()
  for i = 0, S.Task.count - 1 do
    local a = S.gTasks + i * S.Task.stride
    if F.r8(a + S.Task.isActive) ~= 0 and (F.r32(a + S.Task.func) & ~1) == S.Task_OptionMenuProcessInput then return a end
  end
end
local function staged(slot) local t = optionTask(); return t and F.r16(t + S.Task.data + slot * 2) or -1 end
local function cursor() return staged(0) end

local function selectRow(row)
  for _ = 1, 30 do
    local c = cursor()
    if c < 0 then return false end
    if c == row then return true end
    tap(c > row and "Up" or "Down")
  end
  return false
end

local function awaitOptions()
  for _ = 1, 150 do
    if optionTask() then F.idle(20); return true end
    if F.reportCrash("options_open") then return false end
    F.idle(4)
  end
  return false
end

-- Every row changed and changed back, then text speed and the four rates left on `column`.
local function exercise(tag, column)
  local ok = true
  for row = 0, OPTION_ROWS - 1 do
    if not selectRow(row) then ok = false; break end
    tap("Right"); tap("Left")
  end
  F.check(tag .. ": every row redraws through Right and Left", ok and optionTask() ~= nil)
  if selectRow(0) then
    for _ = 1, 4 do if staged(1) == column - 1 then break end tap("Right") end
  end
  F.check(tag .. ": Text Speed staged at column " .. column, staged(1) == column - 1, "staged=" .. staged(1))
  for _, r in ipairs(RATES) do
    if selectRow(r.row) then
      for _ = 1, 4 do if staged(r.slot) == r.byColumn[column] then break end tap("Right") end
    end
    F.check(tag .. ": " .. r.name .. " staged at column " .. column, staged(r.slot) == r.byColumn[column],
      "staged=" .. staged(r.slot))
  end
  F.shot(tag:gsub("[^%w]", "_") .. "_options")
end

local function checkSaved(tag, column)
  F.check(tag .. ": Text Speed saved", textSpeed() == column - 1, "saved=" .. textSpeed())
  for _, r in ipairs(RATES) do
    F.check(tag .. ": " .. r.name .. " saved", rateValue(r) == r.byColumn[column], "saved=" .. rateValue(r))
  end
end

local function digest(addr, count)
  local h = 0
  for i = 0, count - 1 do h = (h * 31 + F.r16(addr + i * 2)) % 4294967291 end
  return h
end

-- The map's own BG palettes, and each OBJ palette keyed by the tag that owns it. Free OBJ slots
-- and BG 13-15 are scratch for whichever menu loads next, so a slot moving or a free slot holding
-- stale colours is not a regression; a live tag whose colours change is.
local function tilesetPalettes() return digest(S.gPlttBufferUnfaded, 13 * 16) end
local function objPalettes()
  local list = {}
  for slot = 0, 15 do
    local tag = F.r16(S.sSpritePaletteTags + slot * 2)
    if tag ~= 0xFFFF then
      list[#list + 1] = string.format("%04X=%08X", tag, digest(S.gPlttBufferUnfaded + (256 + slot * 16) * 2, 16))
    end
  end
  table.sort(list)
  return table.concat(list, " ")
end
local function spritesOnFreePalettes()
  local bad = {}
  for i = 0, S.Sprite.count - 1 do
    local sp = S.gSprites + i * S.Sprite.stride
    if (F.r16(sp + S.Sprite.inUse) & 1) == 1 then
      local slot = F.r16(sp + 4) >> 12
      if F.r16(S.sSpritePaletteTags + slot * 2) == 0xFFFF and slot ~= 0 then bad[#bad + 1] = i .. ":p" .. slot end
    end
  end
  return table.concat(bad, " ")
end

local function objects()
  local list = {}
  for i = 0, 15 do
    local b = S.gObjectEvents + i * S.ObjectEvent.stride
    if (F.r8(b) & 1) == 1 then
      local id = F.r8(b + S.ObjectEvent.localId)
      local hidden = (F.r8(b + S.ObjectEvent.flags1) & 0x20) ~= 0
      local gfx = F.r16(b + S.ObjectEvent.graphicsId)
      local where = string.format("%d,%d", F.rs16(b + S.ObjectEvent.x), F.rs16(b + S.ObjectEvent.y))
      if (gfx & 0x4000) ~= 0 and id ~= ID_FOLLOWER then where = "wild" end
      list[#list + 1] = string.format("%d:%04X:%s:%s", id, gfx, where, hidden and "h" or "v")
    end
  end
  table.sort(list)
  return table.concat(list, " ")
end

local function follower()
  for i = 0, 15 do
    local b = S.gObjectEvents + i * S.ObjectEvent.stride
    if (F.r8(b) & 1) == 1 and F.r8(b + S.ObjectEvent.localId) == ID_FOLLOWER then
      return string.format("%04X:%s", F.r16(b + S.ObjectEvent.graphicsId),
        (F.r8(b + S.ObjectEvent.flags1) & 0x20) ~= 0 and "hidden" or "shown")
    end
  end
  return "none"
end

local function playerFacing()
  for i = 0, 15 do
    local b = S.gObjectEvents + i * S.ObjectEvent.stride
    if (F.r8(b) & 1) == 1 and F.r8(b + S.ObjectEvent.localId) == ID_PLAYER then
      return F.r8(b + S.ObjectEvent.facing) & 0xF
    end
  end
  return -1
end

local function repel() return F.r16(F.sb1() + S.SaveBlock1.vars + (VAR_REPEL_STEP_COUNT - VARS_START) * 2) end

local function snapshot()
  local x, y = F.pos()
  return {
    where = string.format("%d.%d (%d,%d) face=%d", F.grp(), F.mapn(), x, y, playerFacing()),
    avatar = F.r8(S.gPlayerAvatar),
    objects = objects(),
    follower = follower(),
    song = F.r32(S.gMPlayInfo_BGM),
    repel = repel(),
    bg = tilesetPalettes(),
    obj = objPalettes(),
  }
end

local function compare(tag, before, after)
  F.check(tag .. ": same map, tile and facing", after.where == before.where, before.where .. " -> " .. after.where)
  F.check(tag .. ": avatar flags restored", (after.avatar & ~AVATAR_CONTROLLABLE) == (before.avatar & ~AVATAR_CONTROLLABLE),
    string.format("%02X -> %02X", before.avatar, after.avatar))
  F.check(tag .. ": object events restored", after.objects == before.objects, before.objects .. " -> " .. after.objects)
  F.check(tag .. ": follower restored", after.follower == before.follower, before.follower .. " -> " .. after.follower)
  F.check(tag .. ": song restored", after.song == before.song,
    string.format("%08X -> %08X", before.song, after.song))
  F.check(tag .. ": Repel count untouched", after.repel == before.repel, before.repel .. " -> " .. after.repel)
  F.check(tag .. ": map BG palettes restored", after.bg == before.bg, string.format("%08X -> %08X", before.bg, after.bg))
  F.check(tag .. ": OBJ palettes restored per tag", after.obj == before.obj, before.obj .. " -> " .. after.obj)
  local stray = spritesOnFreePalettes()
  F.check(tag .. ": every sprite draws with a loaded palette", stray == "", stray)
end

-- Start menu -> Options -> exercise -> B -> back on the field, compared against the snapshot.
local function fieldVisit(tag, column)
  F.idle(60)
  local before = snapshot()
  F.L("  " .. tag .. " before: " .. before.where .. " avatar=" .. before.avatar .. " follower=" .. before.follower)
  tap("Start"); F.idle(50)
  if not F.selectStartIcon(9) then F.check(tag .. ": Options icon on the Start menu", false); return false end
  tap("A")
  if not F.check(tag .. ": Options opens", awaitOptions()) then F.shot(tag .. "_no_options"); return false end
  exercise(tag, column)
  tap("B")
  for _ = 1, 120 do if not optionTask() then break end F.idle(2) end
  F.idle(90)
  tap("B"); F.idle(90)
  F.check(tag .. ": field resumes without a crash", F.ow() and not F.reportCrash(tag .. "_return"))
  checkSaved(tag, column)
  compare(tag, before, snapshot())
  F.shot(tag:gsub("[^%w]", "_") .. "_field")
  return true
end

local function giveParty()
  F.dbg(); F.idle(40); F.sel(2); F.idle(40)
  for _ = 1, 9 do tap("Down") end
  tap("A"); F.idle(180); F.bOut(6); F.idle(60)
end

local function giveSurfTool()
  F.dbg(); F.idle(60)
  for _ = 1, 3 do F.press("Down", 3); F.idle(16) end
  F.press("A", 3); F.idle(60)
  F.press("A", 3); F.idle(60)
  F.spin(8, 7, 5)
  F.press("A", 2); F.idle(60)
  F.bOut(4); F.idle(60)
end

local function giveLapras()
  F.dbg(); F.idle(60)
  for _ = 1, 3 do F.press("Down", 3); F.idle(16) end
  F.press("A", 3); F.idle(60)
  F.press("Down", 3); F.idle(16); F.press("A", 3); F.idle(60)
  F.spin(1, 3, 0)
  F.spin(0, 9, 9)
  F.idle(90)
  F.bOut(4); F.idle(60)
end

local function johtoFlag(id)
  local a = F.sb3() + S.SaveBlock3.johtoFlags + (id - 0x6000) // 8
  F.w8(a, F.r8(a) | (1 << (id % 8)))
end

local function surfing() return (F.r8(S.gPlayerAvatar) & AVATAR_SURFING) ~= 0 end

local function startSurf()
  F.face("Down"); F.idle(20)
  for _ = 1, 8 do
    F.press("A", 2); F.idle(40)
    if surfing() then break end
  end
  F.idle(200)
  return surfing()
end

local function mainMenuOptions(tag, column, optionsRow)
  for _ = 1, 600 do
    if F.cb2() == S.CB2_MainMenu then break end
    F.press("Start", 2); F.idle(20)
  end
  if not F.check(tag .. ": main menu reached", F.cb2() == S.CB2_MainMenu) then F.shot(tag .. "_no_menu"); return false end
  F.idle(60)
  for _ = 1, optionsRow do tap("Down"); F.idle(10) end
  tap("A")
  if not F.check(tag .. ": Options opens from the main menu", awaitOptions()) then F.shot(tag .. "_no_options"); return false end
  if column then exercise(tag, column) end
  tap("B")
  for _ = 1, 200 do if F.cb2() == S.CB2_MainMenu and not optionTask() then break end F.idle(2) end
  F.idle(60)
  F.check(tag .. ": main menu returns after Options", F.cb2() == S.CB2_MainMenu and not F.reportCrash(tag))
  F.shot(tag:gsub("[^%w]", "_") .. "_main_menu")
  for _ = 1, optionsRow do tap("Up"); F.idle(10) end
  return true
end

F.run(function()
  if not mainMenuOptions("main menu before New Game", 4, 1) then F.finish(); return end
  checkSaved("main menu before New Game", 4)
  if not F.boot(100) then F.check("New Game reaches the hub", false); F.finish(); return end
  checkSaved("main-menu choices carried into the new game", 4)

  giveParty()
  F.check("debug party reached the hub", F.r8(S.gPartiesCount) >= 1, "party=" .. F.r8(S.gPartiesCount))
  F.ensureFree()
  fieldVisit("hub with follower", 1)

  F.w16(F.sb1() + S.SaveBlock1.vars + (VAR_REPEL_STEP_COUNT - VARS_START) * 2, 137)
  fieldVisit("hub during Repel", 2)

  local rain = F.warpTo(0, 8, 9, 0, 0, 0, 0, 0, 0, GRP_CIANWOOD, MAP_CIANWOOD, "cianwood")
  F.check("warp to rainy Cianwood City", rain)
  if rain then
    F.idle(120)
    fieldVisit("Cianwood rain", 3)
    fieldVisit("Cianwood rain again", 2)
  end

  giveLapras()
  giveSurfTool()
  F.check("Surf tool in Key Items", F.keyItemSlot(ITEM_SURF_TOOL) >= 0)
  for _, id in ipairs(FLAG_HIDE_DEN) do johtoFlag(id) end
  for _, trainer in ipairs(DEN_TRAINERS) do
    local a = F.sb1() + S.SaveBlock1.flags + (0x500 + trainer) // 8
    F.w8(a, F.r8(a) | (1 << ((0x500 + trainer) % 8)))
  end
  local den = F.warpTo(0, 9, 4, 0, 1, 2, 0, 0, 0, GRP_INDOOR_BLACKTHORN, MAP_DRAGONS_DEN_CAVERN, "dragons_den")
  F.check("warp to Dragon's Den", den)
  if den then
    F.idle(60)
    local docked = F.route({ { 31, 15 } }, "dock")
    F.check("walked to the Dragon's Den dock", docked)
    if docked and F.step("Down") then F.route({ { 31, 19 } }, "channel") end
    if docked and F.check("surfing in Dragon's Den", startSurf()) then
      fieldVisit("surfing", 4)
      F.check("surfing still after Options", surfing())
      local x0, y0 = F.pos()
      local moved = F.step("Down") or F.step("Left") or F.step("Right")
      local x1, y1 = F.pos()
      F.check("Surf moves after Options", moved and (x1 ~= x0 or y1 ~= y0) and surfing(),
        string.format("(%d,%d)->(%d,%d)", x0, y0, x1, y1))
      fieldVisit("surfing again", 1)
    end
  end

  local savedText, savedRates = optWord(0), optWord(2)
  tap("Start"); F.idle(50)
  F.check("Save icon present", F.selectStartIcon(7))
  for _ = 1, 8 do tap("A"); F.idle(90) end
  F.idle(300); tap("B"); F.idle(30)
  client.reboot_core(); F.idle(240)
  if mainMenuOptions("main menu before Continue", nil, 2) then
    F.check("main menu Options read the saved Text Speed", true)
  end
  F.check("main menu Options left the saved words alone", optWord(0) == savedText and optWord(2) == savedRates,
    string.format("%04X/%04X -> %04X/%04X", savedText, savedRates, optWord(0), optWord(2)))
  F.check("Continue after main-menu Options", F.boot(nil, true))
  F.check("preferences survive Continue", optWord(0) == savedText and optWord(2) == savedRates,
    string.format("%04X/%04X -> %04X/%04X", savedText, savedRates, optWord(0), optWord(2)))
  F.finish()
end)
