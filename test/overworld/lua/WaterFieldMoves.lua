-- Surf, Waterfall and Dive with a follower in all three regions, through real input.
--
--   surf cycles   mount Surf from the shore with A and step back onto land, ten times on one map:
--                 control returns each time, the follower comes back beside the player, and the
--                 sprite slots, sprite tile VRAM and OBJ palette tags return to the first count
--   waterfall     Johto Route 47, Kanto Cape Brink, Hoenn Route 119: from the pool below, face the
--                 falls, press A, YES: the player rides to the top still surfing; surfing back down
--                 lands below the falls; control returns at each end
--   dive (none)   Johto Route 41's deep water has no underwater map: A there must not start Dive
--   dive          Hoenn Route 124: dive with A, YES, then emerge with B, YES, back on the same tile
--
-- PW_WATER_ONLY=<text> runs only the cases whose tag contains it.
--
-- Run via test/overworld/mgba-run.sh test/overworld/lua/WaterFieldMoves.lua <rom>

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "WaterFieldMoves")

local HUB_GROUP = 100
local CONTEXT_RUNNING = 0
local PARTY_SIZE = 6
local SPECIES_LAPRAS = 131
local MOVE_SURF, MOVE_WATERFALL, MOVE_DIVE = 57, 127, 291
local TOOLS = { 876, 879, 880 } -- ITEM_SURF_TOOL, ITEM_WATERFALL_TOOL, ITEM_DIVE_TOOL
local AVATAR_SURFING, AVATAR_UNDERWATER = 1 << 3, 1 << 4
local OBJ_EVENT_ID_FOLLOWER = 0xFE
local VAR_REPEL_STEP_COUNT = 0x4021
local ONLY = os.getenv("PW_WATER_ONLY")
local OPP = { Up = "Down", Down = "Up", Left = "Right", Right = "Left" }

local SCRIPT_BUF = S.gStringVar4 + 960
local function runScript(bytes)
  for i, b in ipairs(bytes) do F.w8(SCRIPT_BUF + i - 1, b) end
  F.w8(S.sGlobalScriptContext, 0)
  F.w8(S.sGlobalScriptContext + 1, 1)
  F.w32(S.sGlobalScriptContext + 4, 0)
  F.w32(S.sGlobalScriptContext + S.ScriptCtx.scriptPtr, SCRIPT_BUF)
  F.w8(S.sGlobalScriptContextStatus, CONTEXT_RUNNING)
end
local function le16(t, v) t[#t + 1] = v & 0xFF; t[#t + 1] = (v >> 8) & 0xFF end
local function le32(t, v) le16(t, v & 0xFFFF); le16(t, (v >> 16) & 0xFFFF) end
local function createMon(species, level, moves)
  local b = { 0x23 }; le32(b, S.ScrCmd_createmon | 1)
  b[#b + 1] = 0; b[#b + 1] = PARTY_SIZE
  le16(b, species); le16(b, level)
  le32(b, (1 << 17) | (1 << 18) | (1 << 19) | (1 << 20))
  for k = 1, 4 do le16(b, moves[k] or 0) end
  b[#b + 1] = 0x02
  runScript(b); F.idle(20)
  return F.r8(S.gPartiesCount)
end
local function addItem(id, qty)
  runScript({ 0x44, id & 0xFF, id >> 8, qty & 0xFF, qty >> 8, 0x02 }); F.idle(10)
end

local function d(n) return (n // 100) % 10, (n // 10) % 10, n % 10 end
local function avatar() return F.r8(S.gPlayerAvatar) end
local function surfing() return (avatar() & AVATAR_SURFING) ~= 0 end
local function underwater() return (avatar() & AVATAR_UNDERWATER) ~= 0 end
local function hasControl()
  return F.ow() and F.r8(S.sLockFieldControls) == 0 and F.r8(S.sGlobalScriptContextStatus) ~= CONTEXT_RUNNING
end
local function awaitControl(budget)
  for _ = 1, budget or 900 do
    if hasControl() then return true end
    F.idle(1)
  end
  return hasControl()
end
local function objByLocal(id)
  for i = 0, 15 do
    local o = S.gObjectEvents + i * S.ObjectEvent.stride
    if (F.r8(o) & 1) ~= 0 and F.r8(o + S.ObjectEvent.localId) == id then return o end
  end
end
local function follower()
  local o = objByLocal(OBJ_EVENT_ID_FOLLOWER)
  if not o then return nil end
  return { hidden = ((F.r8(o + 1) >> 5) & 1) == 1, x = F.rs16(o + 0x10) - 7, y = F.rs16(o + 0x12) - 7 }
end
local function popcount(v) local n = 0; while v ~= 0 do n = n + (v & 1); v = v >> 1 end; return n end
local function spriteUse()
  local tiles = 0
  for i = 0, 127 do tiles = tiles + popcount(F.r8(S.sSpriteTileAllocBitmap + i)) end
  local pals = 0
  for i = 0, 15 do if F.r16(S.sSpritePaletteTags + 2 * i) ~= 0xFFFF then pals = pals + 1 end end
  local sprites = 0
  for i = 0, 63 do if (F.r8(S.gSprites + i * 0x44 + 0x3E) & 1) ~= 0 then sprites = sprites + 1 end end
  return { tiles = tiles, pals = pals, sprites = sprites }
end

local function warpToCoords(g, m, x, y, tag)
  for _ = 1, 4 do
    F.dbg(); F.sel(0); F.sel(1); F.idle(20)
    F.spin(d(g)); F.spin(d(m))
    F.press("A", 2)
    for _ = 1, 400 do
      F.w8(S.sWarpDestination + 2, 0xFF)
      F.w16(S.sWarpDestination + 4, x)
      F.w16(S.sWarpDestination + 6, y)
      F.idle(1)
      local px, py = F.pos()
      if F.ow() and F.grp() == g and F.mapn() == m and px == x and py == y then
        F.idle(120)
        -- the first arrival in a region narrates it; page that away like a player would
        for i = 1, 900 do
          if hasControl() then break end
          if i % 20 == 0 then F.press("B", 2) else F.idle(1) end
        end
        F.L(string.format("  WARP %s ok (%d,%d) surfing=%s", tag, px, py, tostring(surfing())))
        return true
      end
    end
    F.bOut(5)
  end
  F.shot(tag .. "_warpfail")
  return false
end

-- One tile at the current speed; F.step's tail would carry a surfer a second tile.
local function move(dir)
  local x0, y0, g0, m0 = F.pos(), select(2, F.pos()), F.grp(), F.mapn()
  for _ = 1, 40 do
    joypad.set({ [dir] = true }); emu.frameadvance()
    local x, y = F.pos()
    if x ~= x0 or y ~= y0 or F.grp() ~= g0 or F.mapn() ~= m0 then F.idle(24); return true end
  end
  F.idle(10)
  return false
end

-- A in front of the player, then A through the prompt (YES is the default) until `done` holds.
local function fieldMoveAhead(done, budget, first)
  F.press(first or "A", 2)
  for i = 1, budget or 900 do
    if done() then return true end
    if i % 20 == 0 then F.press("A", 2) else F.idle(1) end
  end
  return done()
end

local function case(tag, body)
  if ONLY and not tag:find(ONLY, 1, true) then return end
  F.L("== " .. tag .. " ==")
  local ok, err = pcall(body)
  if not ok then F.check(tag .. ": ran without a Lua error", false, tostring(err)) end
  if F.reportCrash(tag) then F.check(tag .. ": no crash screen", false) end
end

-- The follower stays in its ball on the dismount tile until the player walks; one step must bring
-- it out beside the player.
local function followerBeside(tag, dir)
  F.check(tag .. ": a step " .. dir .. " on land", F.step(dir))
  F.idle(30)
  local fol = follower()
  local x, y = F.pos()
  local ok = fol and not fol.hidden and math.abs(fol.x - x) + math.abs(fol.y - y) <= 1
  F.check(tag .. ": follower back beside the player", ok, fol and string.format("follower (%d,%d) hidden=%s player (%d,%d)",
    fol.x, fol.y, tostring(fol.hidden), x, y) or "no follower")
end

F.run(function()
  if not F.boot(HUB_GROUP) then F.check("boot to the hub", false); F.finish(); return end
  F.w8(F.sb2() + 0x14, (F.r8(F.sb2() + 0x14) & ~7) | 3)
  F.check("a Lapras leads", createMon(SPECIES_LAPRAS, 100, { MOVE_SURF, MOVE_WATERFALL, MOVE_DIVE }) == 1)
  for _, id in ipairs(TOOLS) do addItem(id, 1) end
  F.w16(F.sb1() + S.SaveBlock1.vars + (VAR_REPEL_STEP_COUNT - 0x4000) * 2, 9999)

  case("surf cycles", function()
    -- Route 32, standing on the pier edge facing the sea to the east
    if not warpToCoords(75, 5, 25, 44, "surf_cycles") then F.check("surf cycles: warp", false); return end
    F.face("Right"); F.idle(30)
    local base
    for n = 1, 10 do
      local tag = "surf cycle " .. n
      local mounted = fieldMoveAhead(function() return surfing() and hasControl() end)
      F.check(tag .. ": Surf from the shore", mounted)
      if not mounted then F.shot("surf_cycle_" .. n .. "_mount"); return end
      local off = move("Left")
      local px, py = F.pos()
      F.check(tag .. ": step back onto land", off and not surfing() and awaitControl(600),
        string.format("(%d,%d) surfing=%s", px, py, tostring(surfing())))
      followerBeside(tag, "Left")
      F.step("Right"); F.face("Right"); F.idle(20)
      local u = spriteUse()
      F.L(string.format("  %s sprites=%d tiles=%d pals=%d", tag, u.sprites, u.tiles, u.pals))
      if n == 1 then base = u else
        F.check(tag .. ": sprite slots, tiles and palettes back to cycle 1",
          u.sprites == base.sprites and u.tiles == base.tiles and u.pals == base.pals,
          string.format("sprites %d/%d tiles %d/%d pals %d/%d", u.sprites, base.sprites, u.tiles, base.tiles, u.pals, base.pals))
      end
    end
  end)

  -- a surfable cell in the pool below each falls (Route 47's row 34 under the falls is MB_NORMAL
-- at elevation 1 in pokemonHnS too, so a warp there lands on foot)
  local FALLS = {
    { tag = "johto Route 47 waterfall", g = 89, m = 1, x = 50, y = 35 },
    { tag = "kanto Cape Brink waterfall", g = 37, m = 47, x = 11, y = 26 },
    { tag = "hoenn Route 119 waterfall", g = 0, m = 34, x = 17, y = 29 },
  }
  for _, fall in ipairs(FALLS) do
    case(fall.tag, function()
      if not warpToCoords(fall.g, fall.m, fall.x, fall.y, fall.tag) then F.check(fall.tag .. ": warp", false); return end
      F.check(fall.tag .. ": arrives surfing", surfing())
      local y0 = select(2, F.pos())
      for _ = 1, 8 do if not move("Up") then break end end
      local yb = select(2, F.pos())
      F.face("Up")
      local up = fieldMoveAhead(function() return select(2, F.pos()) < yb - 1 and hasControl() end, 1500)
      local x1, y1 = F.pos()
      F.shot(fall.tag:gsub("%W", "_") .. "_top")
      F.check(fall.tag .. ": rides to the top", up, string.format("(%d,%d) from y=%d", x1, y1, yb))
      F.check(fall.tag .. ": still surfing on top", surfing())
      if not up then return end
      local down = 0
      for _ = 1, 30 do
        if select(2, F.pos()) >= yb then break end
        if not move("Down") then break end
        down = down + 1
      end
      local x2, y2 = F.pos()
      F.check(fall.tag .. ": surfs back down below the falls", y2 >= yb and surfing() and awaitControl(600),
        string.format("(%d,%d) after %d steps", x2, y2, down))
      F.check(fall.tag .. ": back on the pool it started from", F.grp() == fall.g and F.mapn() == fall.m)
    end)
  end

  case("dive with no underwater map", function()
    if not warpToCoords(87, 2, 18, 6, "route41_deep") then F.check("route41: warp", false); return end
    F.check("route41: surfing", surfing())
    local g, m = F.grp(), F.mapn()
    F.press("A", 2)
    for _ = 1, 240 do F.idle(1); if F.r8(S.sGlobalScriptContextStatus) == CONTEXT_RUNNING then break end end
    for _ = 1, 6 do F.press("A", 2); F.idle(20) end
    F.check("route41: no dive", not underwater() and F.grp() == g and F.mapn() == m and awaitControl(600),
      string.format("avatar %02X at %d/%d", avatar(), F.grp(), F.mapn()))
    F.check("route41: can still surf on", move("Down"))
  end)

  case("dive and emerge", function()
    if not warpToCoords(0, 39, 10, 5, "route124_deep") then F.check("route124: warp", false); return end
    F.check("route124: surfing", surfing())
    local x0, y0 = F.pos()
    local dived = fieldMoveAhead(function() return underwater() and hasControl() end, 1500)
    F.check("route124: dives", dived, string.format("avatar %02X at %d/%d", avatar(), F.grp(), F.mapn()))
    if not dived then return end
    local up = fieldMoveAhead(function() return surfing() and not underwater() and hasControl() end, 1500, "B")
    local x1, y1 = F.pos()
    F.check("route124: emerges on the same tile surfing", up and F.grp() == 0 and F.mapn() == 39 and x1 == x0 and y1 == y0,
      string.format("avatar %02X at %d/%d (%d,%d)", avatar(), F.grp(), F.mapn(), x1, y1))
  end)

  F.finish()
end)
