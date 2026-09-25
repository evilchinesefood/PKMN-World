-- Native title artwork, hardware allocations, fog motion and input transitions.
-- Run with Testing/mgba-run.sh (uses a throwaway ROM and never a player's save).
local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
-- A release/LTO build can supply a smaller symbol table bound to that exact ROM.
local symbolFile = os.getenv("PW_TITLE_SYMBOLS")
local S = symbolFile and dofile(symbolFile) or require("symbols")
local F = require("lib").new(S, "WorldTitle")

local function waitFor(callback, frames)
  joypad.set({})
  for _ = 1, frames do
    if F.cb2() == callback then return true end
    emu.frameadvance()
  end
  return false
end

local function title(reboot)
  if reboot then client.reboot_core(); F.idle(1) end
  local ready = waitFor(S.MainCB2_WorldTitleScreen, 6000)
  F.check("boot reaches World title", ready, string.format("cb2=%08X", F.cb2()))
  if not ready then F.shot("boot_failure"); F.finish(); return false end
  F.idle(100) -- complete the white palette fade
  return true
end

local function matchesFile(address, name)
  local file = assert(io.open(here .. "../../graphics/title_screen/world/" .. name, "rb"))
  local bytes = file:read("*a"); file:close()
  for i = 1, #bytes do
    if F.r8(address + i - 1) ~= bytes:byte(i) then
      return false, string.format("mismatch at +0x%X", i - 1)
    end
  end
  return true, #bytes .. " bytes match"
end

local function checkResource(name, address, file)
  local ok, detail = matchesFile(address, file)
  F.check(name, ok, detail)
end

local function stoppedWave()
  -- ScanlineEffect.state at +21, waveTaskId at +22 (include/scanline_effect.h).
  return F.r8(S.gScanlineEffect + 21) == 0 and F.r8(S.gScanlineEffect + 22) == 255
end

local function checkHorizontalAlignment()
  -- Measure actual visible pixels from hardware tilemaps / OAM, so transparent
  -- source padding or an off-by-one sprite tile cannot pass as centered artwork.
  local logoLeft, logoRight, worldLeft, worldRight = 240, -1, 240, -1
  for y = 0, 159 do
    for x = 0, 239 do
      local entry = F.r16(0x0600F800 + ((y // 8) * 32 + x // 8) * 2)
      local tx, ty = x % 8, y % 8
      if (entry & 0x400) ~= 0 then tx = 7 - tx end
      if (entry & 0x800) ~= 0 then ty = 7 - ty end
      if F.r8(0x06000000 + (entry & 1023) * 64 + ty * 8 + tx) ~= 0 then
        logoLeft, logoRight = math.min(logoLeft, x), math.max(logoRight, x)
        -- Below the Pokemon lettering, the World wordmark has an intentional
        -- four-pixel optical offset within the centered logo stack.
        if y >= 64 then
          worldLeft, worldRight = math.min(worldLeft, x), math.max(worldRight, x)
        end
      end
    end
  end

  local promptLeft, promptRight, pieces, hudPieces = 240, -1, 0, 0
  for i = 0, 127 do
    local a0, a1, a2 = F.r16(0x07000000 + i * 8), F.r16(0x07000002 + i * 8), F.r16(0x07000004 + i * 8)
    if (a0 & 0xE300) == 0x4000 and (a1 & 0xC000) == 0xC000 and (a0 & 255) < 160 then
      hudPieces = hudPieces + 1
    end
    -- Non-affine, enabled 4bpp 32x8 objects in the visible screen. The quickstart
    -- HUD is 64x32; it must not influence the PRESS START bounds.
    if (a0 & 0xE300) == 0x4000 and (a1 & 0xC000) == 0x4000 and (a0 & 255) < 160 then
      pieces = pieces + 1
      local left = a1 & 511
      if left >= 256 then left = left - 512 end
      for y = 0, 7 do
        for x = 0, 31 do
          local tx = (a1 & 0x1000) ~= 0 and 31 - x or x
          local ty = (a1 & 0x2000) ~= 0 and 7 - y or y
          local tile = (a2 & 1023) + tx // 8
          local packed = F.r8(0x06010000 + tile * 32 + ty * 4 + (tx % 8) // 2)
          if ((packed >> ((tx % 2) * 4)) & 15) ~= 0 then
            promptLeft, promptRight = math.min(promptLeft, left + x), math.max(promptRight, left + x)
          end
        end
      end
    end
  end
  F.check("visible stacked logo has equal side margins within one pixel",
    logoRight >= logoLeft and math.abs(logoLeft - (239 - logoRight)) <= 1,
    string.format("left=%d right=%d", logoLeft, 239 - logoRight))
  F.check("visible PRESS START is horizontally centered",
    pieces == 5 and promptRight >= promptLeft and promptLeft == 239 - promptRight,
    string.format("left=%d right=%d pieces=%d", promptLeft, 239 - promptRight, pieces))
  F.check("logo and PRESS START share the horizontal center within half a pixel",
    logoRight >= logoLeft and promptRight >= promptLeft
      and math.abs(logoLeft + logoRight - promptLeft - promptRight) <= 1)
  F.check("World wordmark is four pixels right of the Pokemon logo center",
    worldRight >= worldLeft and worldLeft + worldRight - logoLeft - logoRight == 8,
    string.format("World=%d..%d logo=%d..%d", worldLeft, worldRight, logoLeft, logoRight))
  F.check("SELECT / New Game badge is absent", hudPieces == 0)
end

F.run(function()
  if not title(false) then return end
  F.check("mode 0, all three backgrounds and prompt enabled", F.r16(0x04000000) == 0x1740)
  F.check("scenery uses 8bpp / char 0 / screen 30 / priority 2", F.r16(0x04000008) == 0x1E82)
  F.check("fog uses 4bpp / char 3 / screen 29 / priority 1", F.r16(0x0400000A) == 0x1D0D)
  F.check("logo uses 8bpp / char 0 / screen 31 / priority 0", F.r16(0x0400000C) == 0x1F80)
  F.check("only fog blends against scenery and backdrop", F.r16(0x04000050) == 0x2142)
  F.check("original fog blend coefficients retained", F.r16(0x04000052) == 0x0F06)
  checkResource("shared artwork tiles in VRAM", 0x06000000, "background_tiles.bin")
  checkResource("original fog tiles in VRAM", 0x0600D800, "fog_tiles.bin")
  checkResource("fog map in VRAM", 0x0600E800, "fog_map.bin")
  checkResource("scenery map in VRAM", 0x0600F000, "background_map.bin")
  checkResource("transparent logo map in VRAM", 0x0600F800, "logo_map.bin")
  checkResource("RGB555 palette loaded without legacy color cycling", 0x05000000, "palette.bin")
  F.check("HBlank wave targets fog scroll only",
    F.r8(S.gScanlineEffect + 21) == 1 and F.r32(S.gScanlineEffect + 8) == 0x04000014)
  checkHorizontalAlignment()
  F.shot("title")
  local y = F.r16(S.gBattle_BG1_Y)
  F.idle(128)
  F.check("fog moves 32 pixels over 128 frames", F.r16(S.gBattle_BG1_Y) == ((y + 32) & 255))
  F.shot("fog_moved")
  F.idle(896)
  F.check("fog wraps cleanly after 1024 frames", F.r16(S.gBattle_BG1_Y) == y)
  checkResource("palette remains stable through a full fog cycle", 0x05000000, "palette.bin")
  checkResource("logo stays unchanged through animation", 0x0600F800, "logo_map.bin")
  F.press("Start", 1)
  F.check("Start opens main menu", waitFor(S.CB2_MainMenu, 300))
  F.idle(90)
  F.check("fog DMA and task stop before main menu", stoppedWave())
  F.shot("main_menu")

  if not title(true) then return end
  F.press("A", 1)
  F.check("A opens main menu", waitFor(S.CB2_MainMenu, 300))

  if not title(true) then return end
  joypad.set({B = true, Select = true, Left = true})
  for _ = 1, 5 do emu.frameadvance() end
  F.idle(90)
  F.check("locked RTC chord stays on title without triggering quickstart", F.cb2() == S.MainCB2_WorldTitleScreen)
  joypad.set({B = true, Select = true, Up = true})
  emu.frameadvance()
  F.check("clear-save chord reaches confirmation", waitFor(S.CB2_InitClearSaveDataScreen, 120))
  F.idle(90)
  F.check("fog DMA stops before clear-save screen", stoppedWave())
  F.shot("clear_save_confirmation")
  -- Cancel: never confirm deletion, even in this disposable test copy.
  F.press("B", 1)
  if not title(false) then return end
  F.check("canceling clear-save returns to a working title", F.r16(0x04000000) == 0x1740)

  -- Exercise the natural music-end return to the intro without changing its status.
  local left = false
  for _ = 1, 12000 do
    F.idle(1)
    if F.cb2() ~= S.MainCB2_WorldTitleScreen then left = true; break end
  end
  F.check("title music completion returns to intro", left)
  if left then
    if not title(false) then return end
    checkResource("title reload restores the full palette", 0x05000000, "palette.bin")
    F.shot("title_after_intro_loop")
  end
  F.press("Select", 1)
  F.idle(180)
  F.check("SELECT alone does not start a new game", F.cb2() == S.MainCB2_WorldTitleScreen)
  F.shot("select_disabled")
  F.finish()
end)
