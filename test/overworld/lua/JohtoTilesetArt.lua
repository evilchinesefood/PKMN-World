-- JohtoTilesetArt.lua: Johto rooms whose secondary tileset name collided with a Kanto or Hoenn
-- tileset draw pokemonHnS's art, not the other region's.
--
-- The five Johto League rooms (gTileset_PokemonLeague), the Johto Hall of Fame
-- (gTileset_HallOfFame) and Cianwood's shop (gTileset_BikeShop) were ported from pokemonHnS with
-- their layouts still naming HnS's tilesets, but here those names belong to the FRLG or Emerald
-- tileset of the same name. The blockdata then indexed metatiles HnS never drew: the Champion's
-- room had black void squares beside its stairs and stray tiles where HnS has dragon statues,
-- Koga's and Karen's rooms showed Lorelei's ice pillars and Agatha's fangs, the Hall of Fame's
-- entrance was a void square, and the shop's shelves were Mauville bike-shop machines.
--
-- For each cell below the suite hashes the picture the running game builds for it: the metatile id
-- from the live map grid, that metatile's eight tile entries from the live layout's tilesets, and
-- each entry's tile pixels from BG VRAM, hashed as palette-slot and colour indices (FNV-1a, the top
-- layer over the bottom, colour 0 transparent). The expected id and hash are pokemonHnS's own,
-- computed from its layout and tileset files by test/overworld/JohtoTilesetArtExpect.py. Each map
-- carries a control cell the port always drew right, so a hash mismatch cannot be the hash itself.

package.path = (debug.getinfo(1, "S").source:sub(2):match("^(.*[/\\])") or "") .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "JohtoTilesetArt")

-- { x, y, metatile id, hash } from JohtoTilesetArtExpect.py against pokemonHnS; the last cell of
-- each map is the control.
local EXPECT = {
  will = { { 3, 0, 0x283, 0xB39E99F5 }, { 9, 0, 0x283, 0xB39E99F5 }, { 6, 9, 0x2CF, 0x4BE2F249 } },
  koga = { { 2, 4, 0x34A, 0xFCF0C8C9 }, { 10, 6, 0x341, 0x5571FD61 }, { 5, 0, 0x283, 0xB39E99F5 }, { 6, 9, 0x2C9, 0x6384C449 } },
  bruno = { { 3, 0, 0x283, 0xB39E99F5 }, { 9, 0, 0x283, 0xB39E99F5 }, { 6, 9, 0x2CC, 0xB76C2489 } },
  karen = { { 2, 4, 0x36A, 0x6C1A2D4A }, { 10, 6, 0x379, 0xAD32BB11 }, { 6, 9, 0x299, 0x3199DF09 } },
  champion = { { 5, 4, 0x3F3, 0x2F7815C5 }, { 5, 8, 0x3F6, 0x618C1AC5 }, { 1, 4, 0x386, 0xC7B6D343 }, { 6, 16, 0x3CD, 0xC97447B9 } },
  hof = { { 5, 12, 0x2B7, 0x46B491C5 }, { 5, 8, 0x2BD, 0x8C7949E9 } },
  cianwood_shop = { { 4, 6, 0x2A0, 0x4864FBBD }, { 11, 6, 0x2A0, 0x4864FBBD }, { 8, 9, 0x0A9, 0x77E2A745 } },
}

-- name, warp spinner digits (group, map, warp), group, map. Koga's room comes before Will's, whose
-- exit walk ends in it: warpTo onto the map the player is already on would warp nobody.
local MAPS = {
  { "koga", 0, 9, 9, 0, 0, 6, 0, 0, 0, 99, 6 },
  { "will", 0, 9, 9, 0, 0, 5, 0, 0, 0, 99, 5 },
  { "bruno", 0, 9, 9, 0, 0, 7, 0, 0, 0, 99, 7 },
  { "karen", 0, 9, 9, 0, 0, 8, 0, 0, 0, 99, 8 },
  { "champion", 0, 9, 9, 0, 0, 9, 0, 0, 0, 99, 9 },
  { "hof", 0, 9, 9, 0, 1, 0, 0, 0, 0, 99, 10 },
  { "cianwood_shop", 0, 9, 0, 0, 0, 5, 0, 0, 0, 90, 5 },
}

local SPLIT = 640          -- GetNumMetatilesInPrimary for an isJohto layout
local BG_CHAR_BASE = 0x06000000

-- Will's defeat script leaves VAR_LEAGUE_STATE at 2, and his room's ON_LOAD then opens the north
-- exit with setmetatile 0x28E/0x296, ids that name HnS's open door. Seeded the way that script
-- leaves it, the exit must lead on to Koga's room.
local VAR_LEAGUE_STATE = 0xA080 + 0x3B
local function seedLeagueState(v)
  F.w16(F.sb3() + S.SaveBlock3.regionVars + (VAR_LEAGUE_STATE - 0xA000) * 2, v)
end

local function walkWillsExit()
  if not F.route({ { 7, 10 }, { 7, 5 }, { 6, 5 }, { 6, 3 } }, "will_exit") then return false end
  for _ = 1, 120 do
    joypad.set({ Up = true }); emu.frameadvance()
    if F.grp() == 99 and F.mapn() == 6 then break end
  end
  F.idle(120)
  return F.grp() == 99 and F.mapn() == 6
end

local function gridId(x, y)
  local w = F.r32(S.gBackupMapLayout + S.BackupMapLayout.width)
  local m = F.r32(S.gBackupMapLayout + S.BackupMapLayout.map)
  return F.r16(m + ((x + 7) + w * (y + 7)) * 2) & S.Metatiles.idMask
end

local function cellHash(layout, id)
  local tileset = id < SPLIT and S.MapLayout.primaryTileset or S.MapLayout.secondaryTileset
  local metatiles = F.r32(F.r32(layout + tileset) + S.Tileset.metatiles)
  local entries = metatiles + (id % SPLIT) * 16
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

F.run(function()
  if not F.boot(100) then F.finish() return end
  seedLeagueState(2)
  for _, m in ipairs(MAPS) do
    local name = m[1]
    if F.warpTo(m[2], m[3], m[4], m[5], m[6], m[7], m[8], m[9], m[10], m[11], m[12], name) then
      F.idle(240)
      local layout = F.r32(S.gMapHeader + S.MapHeader.mapLayout)
      F.check(name .. " is a Johto layout", F.r8(layout + S.MapLayout.isJohto) ~= 0, "")
      for i, c in ipairs(EXPECT[name]) do
        local x, y, wantId, wantHash = c[1], c[2], c[3], c[4]
        local id = gridId(x, y)
        local h = cellHash(layout, id)
        local role = i == #EXPECT[name] and "control" or "cell"
        F.check(("%s %s (%d,%d) draws HnS's art"):format(name, role, x, y), id == wantId and h == wantHash,
                ("metatile 0x%03X hash 0x%08X, want 0x%03X 0x%08X"):format(id, h, wantId, wantHash))
      end
      F.shot(name)
      if name == "will" then
        F.check("will north exit leads to Koga's room", walkWillsExit(),
                ("now %d.%d"):format(F.grp(), F.mapn()))
      end
    else
      F.check(name .. " warp", false, "")
    end
  end
  F.finish()
end)
