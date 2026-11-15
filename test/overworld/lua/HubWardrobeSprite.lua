-- The World Transit wardrobe must draw its sprite, not only its shadow.
--
-- OBJ_EVENT_GFX_WARDROBE has no tile tag, so its frame reaches VRAM only when an animation command
-- sets a frame, and its graphics info used gDummySpriteAnimTable, which has none. The object's
-- tiles stayed blank: the hub showed bare floor at (7,7) with a stray medium shadow under it, and a
-- player standing at the wardrobe hid the shadow, so the screens of the wardrobe suites looked
-- right. Inanimate objects use sAnimTable_Inanimate, which shows frame 0.
--
-- From a fresh hub boot the player walks to (8,8), beside the wardrobe, so nothing covers it. The
-- wardrobe object (local id 15 at (7,7)) must own an active sprite whose eight OBJ tiles are not
-- blank, and the tiles must match the start of gObjectEventPic_Wardrobe. As a control the player
-- then faces the wardrobe from (7,8) and A opens the outfit picker, and B closes it.
--
-- Run via test/overworld/mgba-run.sh test/overworld/lua/HubWardrobeSprite.lua

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "HubWardrobeSprite")

local HUB_GROUP = 100
local WARDROBE_LOCAL_ID, WARDROBE_X, WARDROBE_Y = 15, 7, 7
local OBJ_SPRITE_ID = 0x23
local TILE_BYTES, TILES = 32, 8
local OBJ_VRAM = 0x06010000

local function wardrobe()
  for i = 0, 15 do
    local b = S.gObjectEvents + i * S.ObjectEvent.stride
    if (F.r8(b) & 1) == 1 and F.r8(b + S.ObjectEvent.localId) == WARDROBE_LOCAL_ID then return b end
  end
end
local function pickerOpen() return F.r8(S.gPlayerOutfitPicker + 2) ~= 0 end

F.run(function()
  if not F.boot(HUB_GROUP) then F.check("boot to the hub", false); F.finish(); return end
  F.check("walked beside the wardrobe to (8,8)", F.route({ { 9, 4 }, { 9, 6 }, { 8, 6 }, { 8, 8 } }, "beside"),
    string.format("(%d,%d)", F.pos()))
  F.face("Up"); F.idle(60)

  local obj = wardrobe()
  F.check("the wardrobe object is on the map", obj ~= nil)
  if not obj then F.finish(); return end
  F.check("the wardrobe stands at (7,7)", F.rs16(obj + S.ObjectEvent.x) - 7 == WARDROBE_X
    and F.rs16(obj + S.ObjectEvent.y) - 7 == WARDROBE_Y,
    string.format("(%d,%d)", F.rs16(obj + S.ObjectEvent.x) - 7, F.rs16(obj + S.ObjectEvent.y) - 7))
  local spr = S.gSprites + F.r8(obj + OBJ_SPRITE_ID) * S.Sprite.stride
  F.check("the wardrobe owns an active sprite", (F.r8(spr + S.Sprite.inUse) & 1) == 1)
  local tile = F.r16(spr + 4) & 0x3FF
  local blank, same = true, true
  for k = 0, TILES * TILE_BYTES - 1, 4 do
    local v = memory.read_u32_le(OBJ_VRAM + tile * TILE_BYTES + k, "System Bus")
    if v ~= 0 then blank = false end
    if S.gObjectEventPic_Wardrobe and v ~= memory.read_u32_le(S.gObjectEventPic_Wardrobe + k, "System Bus") then same = false end
  end
  F.shot("wardrobe_from_beside")
  F.check("the wardrobe's tiles are drawn, not blank", not blank, "tile=" .. tile)
  if S.gObjectEventPic_Wardrobe then
    F.check("the wardrobe's tiles are its first frame", same, "tile=" .. tile)
  end

  F.check("stepped in front of the wardrobe", F.step("Left") and select(1, F.pos()) == 7, string.format("(%d,%d)", F.pos()))
  F.face("Up")
  for _ = 1, 20 do
    if pickerOpen() then break end
    F.press("A", 2); F.idle(40)
  end
  F.check("control, A opens the outfit picker", pickerOpen())
  for _ = 1, 10 do
    if not pickerOpen() then break end
    F.press("B", 2); F.idle(40)
  end
  F.check("control, B closes the picker", not pickerOpen())
  F.finish()
end)
