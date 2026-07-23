-- Fixture harvester (USM-wheel era, save format v2+): boot a fresh new-game and write the battery
-- save so MakeMigrationFixtures.sh can copy out a historical-format .srm. START -> pin slot 0 (Bag)
-- -> Right x2 (Save) -> A -> confirm the save dialog -> settle so flash flushes. Verified by the
-- SaveBlock2.saveVersion appearing in the written .srm (footer signature 0x08012025).
--
-- The four address constants below are per-build: MakeMigrationFixtures.sh sed-patches them from
-- each historical build's pokemonworld.map before running. The defaults are the current build's
-- addresses so this also runs standalone against the current ROM.
local GMAIN_CB2 = 0x030065b4
local CB2_OW    = 0x081996e0
local SB1_PTR   = 0x030050b0
local SB2_PTR   = 0x030050ac

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
local SEP = (here ~= "" and here:sub(-1)) or "/"
local OUT = (here ~= "" and (here .. ".." .. SEP .. ".." .. SEP .. "_pwtest" .. SEP)) or ("_pwtest" .. SEP)

local function r8(a) return memory.read_u8(a, "System Bus") end
local function r32(a) return memory.read_u32_le(a, "System Bus") end
local function cb2() local v = r32(GMAIN_CB2); return v - (v % 2) end
local function ow() return cb2() == CB2_OW end
local function press(b, n) for _ = 1, (n or 2) do joypad.set({ [b] = true }); emu.frameadvance() end end
local function idle(n) for _ = 1, n do joypad.set({}); emu.frameadvance() end end
local log = io.open(OUT .. "saveharvest.log", "w")
local function L(s) if log then log:write(s .. "\n"); log:flush() end console.log(s) end

client.speedmode(800)
idle(300)
local f = 0
while f < 150000 and not (ow() and r8(r32(SB1_PTR) + 4) == 100) do
  local p = f % 30
  if p < 3 then joypad.set({ A = true }) elseif p >= 15 and p < 17 then joypad.set({ Start = true }) else joypad.set({}) end
  emu.frameadvance(); f = f + 1
end
if not ow() then L("BOOT FAIL"); if log then log:close() end client.exit(); return end
idle(200)
L("booted grp=" .. r8(r32(SB1_PTR) + 4) .. " saveVersion(RAM)=" .. r8(r32(SB2_PTR) + 145))

press("Start", 2); idle(60)
for _ = 1, 10 do press("Left", 2); idle(8) end     -- pin slot 0 = Bag
press("Right", 2); idle(12); press("Right", 2); idle(12)  -- -> Save
press("A", 2); idle(90)                             -- open Save dialog
press("A", 2); idle(60)                             -- advance the save-info window
press("A", 2); idle(200)                            -- confirm YES
idle(300)                                           -- let flash flush
L("done")
if log then log:close() end
client.exit()
