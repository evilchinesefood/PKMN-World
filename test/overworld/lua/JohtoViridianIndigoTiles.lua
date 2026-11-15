-- JohtoViridianIndigoTiles.lua: Route 28, Route 26 North and the Johto Indigo Plateau draw
-- pokemonHnS's art, and their windows still glow amber at night.
--
-- The three layouts came from pokemonHnS naming gTileset_ViridianCity and gTileset_IndigoPlateau,
-- which here are FRLG's tilesets, so the house roof and door on Route 28, the gate's tree bases
-- and the Indigo statues and doorway drew speckled garbage. They now use HnS's secondaries.
-- Day: each sampled cell must hash to HnS's picture (JohtoTilesetArtExpect.py
-- JohtoViridianIndigoTiles prints the table; the last cell of each view is a control the port
-- always drew right), and the window glass must still be blue. Night (22:30): the same glass must
-- be warm (red above blue) in the faded BG palette, the approved amber treatment.

package.path = (debug.getinfo(1, "S").source:sub(2):match("^(.*[/\\])") or "") .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "JohtoViridianIndigoTiles")

local EXPECT = {
  route28_house = { { 21, 6, 0x30D, 0x37BA92DF }, { 20, 9, 0x31B, 0x9095C569 }, { 19, 10, 0x313, 0x31C20D50 }, { 21, 7, 0x28A, 0x2356005F } },
  route28_gate = { { 49, 10, 0x2C8, 0x11ADEFB8 }, { 52, 13, 0x2CD, 0x73B44545 }, { 50, 10, 0x2C3, 0x5D1022F3 } },
  route26n = { { 8, 3, 0x2C8, 0x11ADEFB8 }, { 11, 6, 0x311, 0x24E8633B }, { 9, 3, 0x2C3, 0x5D1022F3 } },
  indigo = { { 11, 8, 0x2FF, 0x9AE8936C }, { 8, 9, 0x2B6, 0x94B3B284 }, { 7, 5, 0x2FB, 0xF06A0BFF }, { 10, 4, 0x30B, 0xEE18BC02 } },
}

-- key, warp spinner digits (group, map, warp), group, map, window glass { BG palette, colours }.
-- Two Route 28 views are split by Route 26 North: warpTo onto the current map warps nobody.
local VIEWS = {
  { "route28_house", 0, 9, 7, 0, 1, 0, 0, 0, 1, 97, 10, { 3, { 8, 15 } } },
  { "route26n", 0, 9, 8, 0, 0, 1, 0, 0, 0, 98, 1, { 12, { 12, 13, 14 } } },
  { "route28_gate", 0, 9, 7, 0, 1, 0, 0, 0, 0, 97, 10, { 12, { 12, 13, 14 } } },
  { "indigo", 0, 9, 9, 0, 0, 3, 0, 0, 0, 99, 3, { 10, { 12, 13, 14 } } },
}

local SPLIT = 640
local BG_CHAR_BASE = 0x06000000

local function clock(h, m)
  local off = F.sb2() + S.SaveBlock2.localTimeOffset
  local function seconds(p)
    return F.rs8(p + S.Time.hours) * 3600 + F.rs8(p + S.Time.minutes) * 60 + F.rs8(p + S.Time.seconds)
  end
  local value = (seconds(off) + (seconds(S.gLocalTime) - (h * 3600 + m * 60)) % 86400) % 86400
  F.w8(off + S.Time.hours, value // 3600)
  F.w8(off + S.Time.minutes, (value // 60) % 60)
  F.w8(off + S.Time.seconds, value % 60)
  F.w8(S.sHoursOverride, 0)
  F.w16(S.gTimeUpdateCounter, 0)
  F.idle(240)
end

local function gridId(x, y)
  local w = F.r32(S.gBackupMapLayout + S.BackupMapLayout.width)
  local m = F.r32(S.gBackupMapLayout + S.BackupMapLayout.map)
  return F.r16(m + ((x + 7) + w * (y + 7)) * 2) & S.Metatiles.idMask
end

local function cellHash(layout, id)
  local tileset = id < SPLIT and S.MapLayout.primaryTileset or S.MapLayout.secondaryTileset
  local entries = F.r32(F.r32(layout + tileset) + S.Tileset.metatiles) + (id % SPLIT) * 16
  local pic = {}
  for i = 0, 255 do pic[i] = 0 end
  for layer = 0, 1 do
    for q = 0, 3 do
      local e = F.r16(entries + (layer * 4 + q) * 2)
      local tile, hf, vf, pal = e & 0x3FF, (e >> 10) & 1, (e >> 11) & 1, e >> 12
      local base = BG_CHAR_BASE + tile * 32
      for ty = 0, 7 do
        for tx = 0, 7 do
          local sy, sx = vf == 1 and 7 - ty or ty, hf == 1 and 7 - tx or tx
          local byte = F.r8(base + sy * 4 + (sx >> 1))
          local c = (sx & 1 == 0) and (byte & 0xF) or (byte >> 4)
          if not (c == 0 and layer == 1) then
            pic[((q >> 1) * 8 + ty) * 16 + (q & 1) * 8 + tx] = c == 0 and 0 or ((pal << 4) | c)
          end
        end
      end
    end
  end
  local h = 0x811C9DC5
  for i = 0, 255 do h = ((h ~ pic[i]) * 16777619) & 0xFFFFFFFF end
  return h
end

-- Every glass colour as "r,g,b", and whether all are warm (red above blue) or all cool.
local function glass(spec)
  local bank, colours = spec[1], spec[2]
  local text, warm, cool = {}, true, true
  for _, c in ipairs(colours) do
    local v = F.r16(S.gPlttBufferFaded + (bank * 16 + c) * 2)
    local r, g, b = v & 31, (v >> 5) & 31, (v >> 10) & 31
    text[#text + 1] = ("%d:%d,%d,%d"):format(c, r, g, b)
    warm = warm and r > b
    cool = cool and b > r
  end
  return warm, cool, ("palette %d %s"):format(bank, table.concat(text, " "))
end

F.run(function()
  if not F.boot(100) then F.finish() return end
  for _, v in ipairs(VIEWS) do
    local key = v[1]
    if F.warpTo(v[2], v[3], v[4], v[5], v[6], v[7], v[8], v[9], v[10], v[11], v[12], key) then
      F.idle(120)
      clock(14, 30)
      local layout = F.r32(S.gMapHeader + S.MapHeader.mapLayout)
      for i, c in ipairs(EXPECT[key]) do
        local x, y, wantId, wantHash = c[1], c[2], c[3], c[4]
        local id = gridId(x, y)
        local h = cellHash(layout, id)
        local role = i == #EXPECT[key] and "control" or "cell"
        F.check(("%s %s (%d,%d) draws HnS's art"):format(key, role, x, y), id == wantId and h == wantHash,
                ("metatile 0x%03X hash 0x%08X, want 0x%03X 0x%08X"):format(id, h, wantId, wantHash))
      end
      local _, dayCool, dayText = glass(v[13])
      F.check(key .. " window glass is blue by day", dayCool, dayText)
      F.shot(key .. "_day")
      clock(22, 30)
      local nightWarm, _, nightText = glass(v[13])
      F.check(key .. " window glass glows amber at night", nightWarm, nightText)
      F.shot(key .. "_night")
    else
      F.check(key .. " warp", false, "")
    end
  end
  F.finish()
end)
