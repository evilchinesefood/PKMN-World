-- BizHawk-compatible runtime for mGBA's headless frontend (macOS/arm64).
--
-- The suites in this directory were written against EmuHawk's Lua API. BizHawk ships no macOS
-- build at all -- upstream targets Windows and Linux only -- so on this machine they run under
-- `mgba-headless --script`. Launch them via Testing/mgba-run.sh, never directly: this file is
-- the --script entry point and reads its configuration from the environment.
--
-- mGBA's API differs from BizHawk's in three ways that actually matter:
--
--   1. mGBA is callback-driven. A script's main chunk runs ONCE, before emulation starts, and
--      `callbacks:add("frame", ...)` fires thereafter. BizHawk suites are straight-line code
--      that blocks inside emu.frameadvance(). We reconcile the two by running the suite body in
--      a coroutine and resuming it exactly once per frame; frameadvance() is coroutine.yield().
--      This is why the suite is loaded by THIS file rather than passed to --script itself: a
--      second --script would run at load time, where yielding is an error.
--
--   2. mGBA exposes methods on userdata (emu:read32) where BizHawk uses free functions on
--      tables (memory.read_u32_le). We keep a private reference to the real objects and shadow
--      the globals with BizHawk-shaped tables.
--
--   3. C.GBA_KEY.* are bit INDICES (A=0, B=1 ... L=9), not masks. emu:setKeys() wants a mask,
--      so every lookup goes through (1 << index). Passing the index directly "works" for A
--      (1<<0 == 1 only by coincidence at bit 0) and silently presses the wrong button for
--      everything else -- Start would register as Right.
--
-- Screenshots require a video buffer. Stock mGBA's headless frontend never attached one, so
-- emu:screenshot() wrote a PNG header and then segfaulted the process; see Testing/mgba/README
-- for the one-line upstream patch this build carries.

local core     = emu      -- capture before we shadow the globals below
local mconsole = console

-- ---- configuration from the runner ----------------------------------------------------------
local SUITE    = os.getenv("PW_SUITE")
local ROM_NAME = os.getenv("PW_ROM_NAME") or "unknown"
local ROM_HASH = os.getenv("PW_ROM_HASH") or ""

-- lib.lua bootstraps package.path off its own location, but it can only do that once something
-- has already found it. Derive the directory from THIS chunk, which mGBA loads by absolute path.
local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or "./"
package.path = here .. "?.lua;" .. package.path

-- ---- key masks -------------------------------------------------------------------------------
-- BizHawk spells buttons Up/Down/Left/Right/A/B/Start/Select/L/R; mGBA uses SCREAMING_CASE.
local KEYMASK = {}
for biz, mgba in pairs({
  A = "A", B = "B", Start = "START", Select = "SELECT",
  Up = "UP", Down = "DOWN", Left = "LEFT", Right = "RIGHT", L = "L", R = "R",
}) do
  KEYMASK[biz] = 1 << C.GBA_KEY[mgba]
end

-- ---- console ---------------------------------------------------------------------------------
-- Straight to stdout, NOT through mconsole:log. mGBA routes script logging through its normal
-- logger, so the -l mask the runner uses to silence per-DMA/BIOS chatter would swallow the
-- suite's own output with it -- the run looks silent and passing whether or not it did anything.
local function emit(stream, prefix, ...)
  local parts = {}
  for i = 1, select("#", ...) do parts[i] = tostring((select(i, ...))) end
  stream:write(prefix, table.concat(parts, " "), "\n")
  stream:flush()
end

console = {
  log   = function(...) emit(io.stdout, "", ...) end,
  warn  = function(...) emit(io.stderr, "WARN: ", ...) end,
  error = function(...) emit(io.stderr, "ERROR: ", ...) end,
}

-- ---- memory ----------------------------------------------------------------------------------
-- BizHawk takes an optional domain string ("System Bus"); mGBA's read8/16/32 are already
-- bus-addressed, so the argument is accepted and ignored rather than erroring on call sites.
local function signed(v, bits)
  local half = 1 << (bits - 1)
  return v >= half and v - (half << 1) or v
end

-- Unaligned reads MUST be composed byte-by-byte.
--
-- mGBA faithfully models the GBA's misaligned-access behaviour: an LDRH/LDR off a non-2/4-byte
-- boundary reads the containing aligned word and ROTATES it. emu:read16(0x080000A1) returns
-- 0x5000004F, not the 0x4B4F that the two bytes at that address spell. BizHawk's
-- memory.read_u16_le instead does a plain little-endian read of the bytes AT the address, and
-- the suites were written against that.
--
-- This is not a corner case here: struct ObjectEventTemplate is __attribute__((packed)) with
-- graphicsId at offset +1, so every template scan reads a u16 from an odd address. Forwarding
-- straight to emu:read16 made OwMonSprites report "0/N real species" on all seven maps -- it
-- was comparing rotated garbage, not the sprite ids. Aligned reads take the cheap path.
local function ru16(a)
  if a & 1 == 0 then return core:read16(a) end
  return core:read8(a) | (core:read8(a + 1) << 8)
end

local function ru32(a)
  if a & 3 == 0 then return core:read32(a) end
  return core:read8(a) | (core:read8(a + 1) << 8) | (core:read8(a + 2) << 16) | (core:read8(a + 3) << 24)
end

local function wu16(a, v)
  if a & 1 == 0 then return core:write16(a, v) end
  core:write8(a, v & 0xFF); core:write8(a + 1, (v >> 8) & 0xFF)
end

local function wu32(a, v)
  if a & 3 == 0 then return core:write32(a, v) end
  for i = 0, 3 do core:write8(a + i, (v >> (8 * i)) & 0xFF) end
end

memory = {
  read_u8      = function(a) return core:read8(a) end,
  read_u16_le  = function(a) return ru16(a) end,
  read_u32_le  = function(a) return ru32(a) end,
  read_s8      = function(a) return signed(core:read8(a), 8) end,
  read_s16_le  = function(a) return signed(ru16(a), 16) end,
  read_s32_le  = function(a) return signed(ru32(a), 32) end,
  write_u8     = function(a, v) core:write8(a, v & 0xFF) end,
  write_u16_le = function(a, v) wu16(a, v & 0xFFFF) end,
  write_u32_le = function(a, v) wu32(a, v & 0xFFFFFFFF) end,
  readbyterange = function(a, n) return core:readRange(a, n) end,
}

-- ---- joypad ----------------------------------------------------------------------------------
-- BizHawk's joypad.set applies to the frame about to be emulated and clears when passed {}.
-- mGBA's setKeys is level-triggered and persists, which matches once every call rebuilds the
-- full mask -- so an empty table correctly releases everything.
joypad = {
  set = function(tbl)
    local mask = 0
    for name, held in pairs(tbl or {}) do
      if held then
        local m = KEYMASK[name]
        if not m then error("unknown button: " .. tostring(name), 2) end
        mask = mask | m
      end
    end
    core:setKeys(mask)
  end,
}

-- ---- gameinfo --------------------------------------------------------------------------------
-- lib.lua gates on these to refuse to drive the user's real ROM/save. The runner supplies the
-- values it actually launched, so the guard keeps working under mGBA.
gameinfo = {
  getromname = function() return ROM_NAME end,
  getromhash = function() return ROM_HASH end,
}
getromhash = gameinfo.getromhash

-- ---- client ----------------------------------------------------------------------------------
local finished = false

local function finish(code)
  finished = true
  io.stdout:flush()
  os.exit(code or 0)
end

client = {
  -- Headless already runs unthrottled; there is no frame limiter to raise.
  speedmode   = function() end,
  screenshot  = function(path) core:screenshot(path) end,
  reboot_core = function() core:reset() end,
  exit        = function(code) finish(code) end,
}

-- ---- the coroutine bridge --------------------------------------------------------------------
emu = {
  frameadvance = function() coroutine.yield() end,
  framecount   = function() return core:currentFrame() end,
}

if not SUITE then
  mconsole:error("PW_SUITE is not set -- launch through Testing/mgba-run.sh")
  os.exit(2)
end

local chunk, loadErr = loadfile(SUITE)
if not chunk then
  mconsole:error("could not load suite: " .. tostring(loadErr))
  os.exit(2)
end

local suite = coroutine.create(chunk)

callbacks:add("frame", function()
  if finished then return end
  if coroutine.status(suite) == "dead" then
    -- Ran to completion without calling client.exit() -- treat as a pass.
    finish(0)
  end
  local ok, err = coroutine.resume(suite)
  if not ok then
    mconsole:error("suite error: " .. tostring(err))
    finish(1)
  end
end)
