-- The World Championship registrar must send the player through the singles door the same way the
-- singles attendant does.
--
-- The registrar (the Maniac, local id 5, wandering around (8,14)) hands over to the stock Dome
-- singles flow, whose WalkToDoor walks the player five tiles north with collision off. That walk
-- assumes the player stands at the singles counter (5,11) facing the attendant. A three-region
-- champion is set up, the singles attendant flow is driven once for the reference walk, then the
-- registrar is talked to from each side and the challenge is entered through the real menus and
-- save. Every tile the player occupies from the save until the warp is recorded. The walk must
-- match the reference tile for tile, end on the same door tile facing north, and never occupy a
-- tile with collision (other than the door itself) or another object's tile. A cancel at the
-- challenge menu must leave the player on a free tile with control.
--
-- Run via: test/overworld/mgba-run.sh test/overworld/lua/DomeRegistrarWalk.lua <rom.gba>

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "DomeRegistrarWalk")

local LOBBY_G, LOBBY_M = 26, 18
local CHAMPION_FLAGS = { 0xA48, 0xA49, 0xA4A }
local MODE = 0x40F7
local REGISTRAR, PLAYER, FOLLOWER = 5, 0xFF, 0xFE
local DOOR_X, DOOR_Y = 5, 4
local DIR_NAMES = { [1] = "S", [2] = "N", [3] = "W", [4] = "E" }

local function flag(id)
  local address = F.sb1() + S.SaveBlock1.flags + id // 8
  F.w8(address, F.r8(address) | (1 << (id % 8)))
end

local function var(id) return F.r16(F.sb1() + S.SaveBlock1.vars + (id - 0x4000) * 2) end

local function objects()
  local list = {}
  for i = 0, 15 do
    local a = S.gObjectEvents + i * S.ObjectEvent.stride
    if (F.r8(a) & 1) ~= 0 then
      list[#list + 1] = {
        id = F.r8(a + S.ObjectEvent.localId),
        x = F.rs16(a + S.ObjectEvent.x) - 7, y = F.rs16(a + S.ObjectEvent.y) - 7,
        facing = F.r8(a + S.ObjectEvent.facing) & 0xF,
        invisible = (F.r8(a + 1) & 0x20) ~= 0,
      }
    end
  end
  return list
end

local function object(id)
  for _, o in ipairs(objects()) do if o.id == id then return o end end
end

local function collides(x, y)
  local L = S.gBackupMapLayout
  local w = F.r32(L + S.BackupMapLayout.width)
  local block = F.r16(F.r32(L + S.BackupMapLayout.map) + 2 * ((x + 7) + (y + 7) * w))
  return ((block >> 10) & 3) ~= 0
end

local function liveMenu()
  for i = 0, S.Task.count - 1 do
    local task = S.gTasks + i * S.Task.stride
    local fn = F.r32(task + S.Task.func) & 0xFFFFFFFE
    if F.r8(task + S.Task.isActive) ~= 0 then
      if fn == S.Task_HandleYesNoInput or fn == S.Task_CallYesOrNoCallback then return "yesno" end
      if fn == S.Task_HandleMultichoiceInput then return "multi" end
    end
  end
end

local function untilMenu(tag)
  for _ = 1, 60 do
    if F.reportCrash("menu_" .. tag) then return nil end
    local kind = liveMenu()
    if kind then F.idle(12); return kind end
    F.press("A", 2); F.idle(30)
  end
  F.L("  " .. tag .. ": no menu went live"); F.shot(tag .. "_nomenu")
end

local function choose(want, tag, settle)
  for _ = 1, 8 do
    local c = F.mcur()
    if c == want then F.press("A", 2); F.idle(settle or 45); return true end
    F.press(c > want and "Up" or "Down", 2); F.idle(12)
  end
  F.L("  " .. tag .. ": cursor never reached " .. want)
  return false
end

local function scriptRunning() return F.r8(S.sGlobalScriptContextStatus) ~= 2 end

local SCRIPT_BUF = S.gStringVar4 + 960
local function le16(t, v) t[#t + 1] = v & 0xFF; t[#t + 1] = (v >> 8) & 0xFF end
local function le32(t, v) le16(t, v & 0xFFFF); le16(t, (v >> 16) & 0xFFFF) end
local function runScript(bytes)
  for i, b in ipairs(bytes) do F.w8(SCRIPT_BUF + i - 1, b) end
  F.w8(S.sGlobalScriptContext, 0)
  F.w8(S.sGlobalScriptContext + 1, 1)
  F.w32(S.sGlobalScriptContext + 4, 0)
  F.w32(S.sGlobalScriptContext + S.ScriptCtx.scriptPtr, SCRIPT_BUF)
  F.w8(S.sGlobalScriptContextStatus, 0)
end

local function giveMon(species)
  local b = { 0x23 }; le32(b, S.ScrCmd_createmon | 1)
  b[#b + 1] = 0; b[#b + 1] = 6
  le16(b, species); le16(b, 50)
  le32(b, (1 << 17) | (1 << 18) | (1 << 19) | (1 << 20))
  le16(b, 33); le16(b, 0); le16(b, 0); le16(b, 0)
  b[#b + 1] = 0x02
  runScript(b); F.idle(20)
end

-- Record every tile the player stands on until `done()` holds, flagging walls (other than the
-- door) and tiles shared with another visible object. A is pressed every 30 frames for text.
local function trace(tag, done)
  local path, bad = {}, {}
  local last
  for frame = 1, 3000 do
    if F.reportCrash(tag .. "_walk") or done() then break end
    local p = object(PLAYER)
    if p then
      local key = p.x .. "," .. p.y
      if key ~= last then
        last = key
        path[#path + 1] = { x = p.x, y = p.y, facing = p.facing }
        F.shot(string.format("%s_tile_%d_%d", tag, p.x, p.y))
        if collides(p.x, p.y) and not (p.x == DOOR_X and p.y == DOOR_Y) then
          bad[#bad + 1] = string.format("wall(%d,%d)", p.x, p.y)
        end
      end
      path[#path].facing = p.facing
      for _, o in ipairs(objects()) do
        if o.id ~= PLAYER and o.id ~= FOLLOWER and not o.invisible and o.x == p.x and o.y == p.y then
          bad[#bad + 1] = string.format("object%d(%d,%d)@%d", o.id, p.x, p.y, frame)
        end
      end
    end
    if frame % 30 == 0 then F.press("A", 2) else F.idle(1) end
  end
  return path, bad
end

-- From the attendant's challenge menu through Lv50, three entries and the save, then record every
-- tile the player stands on until the map changes.
local function enterAndTrace(tag)
  if untilMenu(tag .. "_info") ~= "multi" then return nil end
  if not choose(0, tag .. "_info") then return nil end
  if untilMenu(tag .. "_level") ~= "multi" then return nil end
  if not choose(0, tag .. "_level") then return nil end
  for _ = 1, 40 do
    if F.cb2() == (S.CB2_UpdatePartyMenu & ~1) then break end
    F.press("A", 2); F.idle(30)
  end
  F.idle(60)
  F.shot(tag .. "_party_select")
  for n = 1, 3 do
    F.press("A", 3); F.idle(40)
    F.press("A", 3); F.idle(40)
    F.press("Down", 3); F.idle(20)
  end
  F.press("Start", 3); F.idle(40)
  F.shot(tag .. "_party_start")
  if untilMenu(tag .. "_save") ~= "yesno" then return nil end
  F.shot(tag .. "_save_prompt")
  if not choose(0, tag .. "_save") then return nil end

  return trace(tag, function() return F.grp() ~= LOBBY_G or F.mapn() ~= LOBBY_M end)
end

local function fmtPath(path)
  local parts = {}
  for _, t in ipairs(path or {}) do parts[#parts + 1] = string.format("(%d,%d)", t.x, t.y) end
  return table.concat(parts, " ")
end

-- The walk is the part of the trace from the tile the player stood on at the save to the warp.
local function sameWalk(a, b)
  if #a ~= #b then return false end
  for i = 1, #a do if a[i].x ~= b[i].x or a[i].y ~= b[i].y then return false end end
  return true
end

local function doorTile(path)
  local t = path[#path]
  return string.format("(%d,%d) facing %s", t.x, t.y, DIR_NAMES[t.facing] or tostring(t.facing))
end

local SIDES = {
  { name = "below", dx = 0, dy = 1, face = "Up" },
  { name = "left", dx = -1, dy = 0, face = "Right" },
  { name = "right", dx = 1, dy = 0, face = "Left" },
  { name = "above", dx = 0, dy = -1, face = "Down" },
}

local function talkFrom(side)
  for _ = 1, 20 do
    local r = object(REGISTRAR)
    assert(r, "Registrar object missing")
    local tx, ty = r.x + side.dx, r.y + side.dy
    local ax = side.dx < 0 and 6 or 10
    if not collides(tx, ty) and F.route({ { ax, 12 }, { ax, ty }, { tx, ty } }, "to_" .. side.name) then
      r = object(REGISTRAR)
      if r.x + side.dx == tx and r.y + side.dy == ty then
        F.face(side.face); F.press("A", 2); F.idle(30)
        if scriptRunning() then
          F.L(string.format("  talked from %s: player (%d,%d) registrar (%d,%d)", side.name, tx, ty, r.x, r.y))
          return true
        end
      end
    end
    F.idle(40)
  end
  return false
end

local function acceptOffer(tag)
  if untilMenu(tag .. "_offer") ~= "yesno" then return false end
  F.shot(tag .. "_offer")
  if not choose(0, tag .. "_offer", 0) then return false end
  local path, bad = trace(tag .. "_to_counter", function() return liveMenu() == "multi" end)
  return true, path, bad
end

F.run(function()
  assert(F.boot(100), "Fresh game did not boot")
  for _, species in ipairs({ 101, 175, 200 }) do giveMon(species) end
  F.check("party has three Pokemon", F.r8(S.gPartiesCount) >= 3, "count=" .. F.r8(S.gPartiesCount))
  assert(F.warpTo(0, 2, 6, 0, 1, 8, 0, 0, 0, LOBBY_G, LOBBY_M, "dome"), "Dome warp failed")
  F.idle(60)
  for _, id in ipairs(CHAMPION_FLAGS) do flag(id) end
  local base = F.out .. "DomeRegistrarWalk_base.ss"
  client.savestate(base)

  F.check("walked to the singles counter", F.route({ { 11, 12 }, { 5, 12 }, { 5, 11 } }, "to_counter"))
  F.face("Up"); F.press("A", 2); F.idle(30)
  local ref, refBad = enterAndTrace("attendant")
  F.check("singles attendant flow reaches the corridor", ref ~= nil and #ref > 1 and F.grp() == LOBBY_G and F.mapn() == 19,
    string.format("grp=%d map=%d", F.grp(), F.mapn()))
  if not ref then F.finish(); return end
  F.L("  reference walk " .. fmtPath(ref) .. " door " .. doorTile(ref))
  F.check("reference walk ends at the singles door facing north", doorTile(ref) == "(5,4) facing N", doorTile(ref))
  F.check("reference walk crosses no wall or object", #refBad == 0, table.concat(refBad, " "))

  for _, side in ipairs(SIDES) do
    client.loadstate(base); F.idle(10)
    local tag = "registrar_" .. side.name
    local accepted, approach, approachBad = false, nil, nil
    if F.check(tag .. ": talked to the registrar", talkFrom(side)) then accepted, approach, approachBad = acceptOffer(tag) end
    if F.check(tag .. ": accepted", accepted) then
      F.L("  " .. tag .. " walk to the counter " .. fmtPath(approach))
      F.check(tag .. ": at the singles counter facing north before the welcome", doorTile(approach) == "(5,11) facing N",
        doorTile(approach))
      F.check(tag .. ": walk to the counter crosses no wall or object", #approachBad == 0, table.concat(approachBad, " "))
      local path, bad = enterAndTrace(tag)
      F.check(tag .. ": reached the corridor", path ~= nil and F.grp() == LOBBY_G and F.mapn() == 19,
        string.format("grp=%d map=%d", F.grp(), F.mapn()))
      if path then
        F.check(tag .. ": walk matches the attendant's", sameWalk(path, ref), fmtPath(path))
        F.check(tag .. ": warped from the singles door facing north", doorTile(path) == doorTile(ref), doorTile(path))
        F.check(tag .. ": walk crosses no wall or object", #bad == 0, table.concat(bad, " "))
      end
    end
  end

  client.loadstate(base); F.idle(10)
  if F.check("cancel: talked to the registrar", talkFrom(SIDES[4])) and F.check("cancel: accepted", (acceptOffer("cancel"))) then
    if untilMenu("cancel_info") == "multi" then F.press("B", 2); F.idle(45) end
    for _ = 1, 30 do if not scriptRunning() then break end F.press("B", 2); F.idle(20) end
    local p = object(PLAYER)
    F.shot("cancel_done")
    F.check("cancel: player back in control on a free tile", not scriptRunning() and not collides(p.x, p.y) and F.ensureFree(),
      string.format("(%d,%d)", p.x, p.y))
    F.check("cancel: championship mode cleared", var(MODE) == 0, "mode=" .. var(MODE))
  end
  F.finish()
end)
