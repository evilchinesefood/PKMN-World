-- Shared BizHawk/Lua test helpers for PKMN-World.
--
-- The ~250 scripts in _pwtest/ each re-implemented this same set (boot loop, coordinate-verified
-- stepping, the two debug spinners, cursor-verified multichoice, screenshots). This is the
-- extracted, reviewed version. A promoted suite starts with:
--
--   local S = require("symbols")          -- fresh per-build addresses (see Testing/GenLuaSymbols.py)
--   local T = require("lib")
--   local F = T.new(S, "MySuite")         -- one handle carrying the log + screenshot dir
--
-- Everything that was empirically load-bearing is preserved with its rationale; see
-- Testing/BizHawkTesting.md for the full field guide.

local M = {}

-- Where logs + screenshots land. Derived, not hardcoded to the author's disk.
--
-- The previous comment here claimed this "CANNOT be derived portably inside BizHawk: the main
-- --lua chunk is named 'main' (debug.getinfo gives no file path)". That is true of the MAIN chunk
-- but lib.lua is not the main chunk — it is require()d, so debug.getinfo(1,"S") gives ITS path.
-- Both suites already prove the technique works: SmokeBoot.lua and MigrateFixtures.lua each
-- bootstrap package.path off exactly this call, and if it returned nothing require("symbols")
-- would fail outright. lib.lua sits in <repo>/Testing/lua/, so ../../ is the repo root.
--
-- This matters because _pwtest/ is gitignored and absent from a fresh clone: io.open on a missing
-- directory returns nil and logging used to degrade SILENTLY to console-only, while MANIFEST.md
-- advertises the suites as fresh-clone-runnable.
local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
local DEFAULT_OUT = here .. ".." .. package.config:sub(1, 1) .. ".." .. package.config:sub(1, 1)
                    .. "_pwtest" .. package.config:sub(1, 1)

-- Only throwaway ROM copies may be driven. boot() blind-presses A and Start for up to 120,000
-- frames against whatever EmuHawk loaded, and the shipped save profile puts SAVE at wheel slot 2
-- of 4 — Start,A,A,A is literally SaveHarvest.lua's deliberate save sequence. BizHawk flushes
-- SaveRAM on exit, so pointing a suite at the real ROM/save is a live clobber path, and
-- BizHawkTesting.md records that accident already happening once. Prose in a doc cannot stop it;
-- this can. Override deliberately with opts.allowAnyRom = true.
local ROM_ALLOWLIST = { "^Verify", "^MigChk", "^FixGen" }

local function romAllowed(romName)
  for _, pat in ipairs(ROM_ALLOWLIST) do
    if romName:match(pat) then return true end
  end
  return false
end

-- BizHawk versions differ on whether getromhash() returns MD5 or SHA1, and some prefix it
-- ("SHA1:..."). Normalise to bare uppercase hex and accept a match against either.
local function normHash(h)
  return (tostring(h or ""):gsub("^%a+:", ""):gsub("[^%x]", "")):upper()
end

-- The hash to stamp into a .PASS/.FAIL sentinel. Prefer what the emulator says it actually
-- loaded; fall back to the runner's exported PW_ROM_HASH, then to symbols.lua's recorded hash.
-- Returns "" when nothing is available, which the sweep treats as unverifiable rather than fresh.
local function romHashStamp(S)
  if gameinfo and gameinfo.getromhash then
    local h = normHash(gameinfo.getromhash())
    if h ~= "" then return h end
  end
  local env = os.getenv and normHash(os.getenv("PW_ROM_HASH")) or ""
  if env ~= "" then return env end
  return S and normHash(S.romMD5) or ""
end

-- ---- construction --------------------------------------------------------------------------
-- opts: { out = "C:\\...\\_pwtest\\", speed = 800, allowAnyRom = false }.
function M.new(S, name, opts)
  opts = opts or {}
  local self = {}
  self.S = S
  self.name = name
  -- PW_OUT is exported by Testing/mgba-run.sh and was read by nothing, so redirecting a run to an
  -- isolated directory silently still wrote into the shared repo _pwtest/ -- overwriting the very
  -- artifacts the redirect was meant to keep apart. Honour it, normalising the trailing separator.
  local envOut = os.getenv and os.getenv("PW_OUT") or nil
  if envOut and envOut ~= "" then
    local sep = package.config:sub(1, 1)
    if not envOut:match("[/\\]$") then envOut = envOut .. sep end
  else
    envOut = nil
  end
  self.out = opts.out or envOut or DEFAULT_OUT
  self.speed = opts.speed or 800
  self.shotn = 0
  self.results = {}

  -- Guard 1: is this ROM the one symbols.lua was generated from? `make -j12` does NOT rebuild
  -- symbols.lua (only the standalone `make symbols` target does) and the ROM the user launches
  -- is routinely a stale hand-copy, so fresh-symbols-against-old-ROM is the NORMAL accident.
  -- gSaveblock3 is a fixed EWRAM symbol, so that pairing boots fine and reports every test green
  -- having exercised the previous build's code. Nothing but this compares them.
  if S.romMD5 and gameinfo and gameinfo.getromhash then
    local actual = normHash(gameinfo.getromhash())
    -- An empty hash used to SKIP the comparison, so the one guard the whole design leans on failed
    -- open. Under mgba_shim the hash comes from PW_ROM_HASH, which Testing/mgba-run.sh computes
    -- with `md5 -q` -- BSD-only, and inside an `export` its failure does not trip `set -e`. On any
    -- non-macOS host that silently produced "", re-enabling both stale-ROM directions. Abort.
    if actual == "" then
      console.log("ABORT " .. name .. ": the loaded ROM's hash is empty, so the stale-ROM guard")
      console.log("  cannot run. Check that PW_ROM_HASH is exported and non-empty (see")
      console.log("  Testing/mgba-run.sh) rather than running unguarded.")
      client.exit(2)
      return
    end
    if actual ~= normHash(S.romMD5) and actual ~= normHash(S.romSHA1) then
      console.log("ABORT " .. name .. ": ROM does not match symbols.lua.")
      console.log("  symbols.lua was generated from " .. tostring(S.romName)
                  .. " md5=" .. tostring(S.romMD5))
      console.log("  loaded ROM hash = " .. tostring(gameinfo.getromhash()))
      console.log("  Rebuild, run `make symbols`, and re-copy the ROM to your throwaway file.")
      client.exit(1)
      return
    end
  end

  -- Guard 2: is this a throwaway copy rather than the real ROM/save pair?
  if not opts.allowAnyRom and gameinfo and gameinfo.getromname then
    local rom = tostring(gameinfo.getromname()):match("([^/\\]+)$") or ""
    if not romAllowed(rom) then
      console.log("ABORT " .. name .. ": refusing to drive ROM '" .. rom .. "'.")
      console.log("  Copy the ROM *and* its SaveRAM to a throwaway pair named Verify*/MigChk*/FixGen*")
      console.log("  first. This suite presses A and Start blindly and BizHawk flushes SaveRAM on exit,")
      console.log("  so running it here can overwrite a real save. Override: opts.allowAnyRom = true.")
      client.exit(1)
      return
    end
  end

  self.log = io.open(self.out .. name .. ".log", "w")
  if not self.log and os.execute then
    -- _pwtest/ is gitignored, so it does not exist on a fresh clone. Create it, then retry.
    -- pcall'd: BizHawk's Lua host may not expose os.execute, and a missing scratch dir must
    -- degrade to a warning, never take the suite down.
    local d = self.out:gsub("[/\\]$", "")
    pcall(os.execute, 'cmd /c if not exist "' .. d .. '" mkdir "' .. d .. '"')
    self.log = io.open(self.out .. name .. ".log", "w")
  end
  if not self.log then
    console.log("WARNING " .. name .. ": cannot write to " .. self.out
                .. " — logging to console only, and screenshots will NOT be saved.")
  end

  local function L(s) if self.log then self.log:write(s .. "\n"); self.log:flush() end console.log(s) end
  self.L = L

  -- raw memory (System Bus)
  local function r8(a)  return memory.read_u8(a, "System Bus") end
  local function r16(a) return memory.read_u16_le(a, "System Bus") end
  local function r32(a) return memory.read_u32_le(a, "System Bus") end
  local function rs8(a) return memory.read_s8(a, "System Bus") end
  local function rs16(a) return memory.read_s16_le(a, "System Bus") end
  local function w8(a, v)  memory.write_u8(a, v, "System Bus") end
  local function w16(a, v) memory.write_u16_le(a, v, "System Bus") end
  local function w32(a, v) memory.write_u32_le(a, v, "System Bus") end
  self.r8, self.r16, self.r32, self.rs8, self.rs16 = r8, r16, r32, rs8, rs16
  self.w8, self.w16, self.w32 = w8, w16, w32

  -- save blocks (pointers are deref'd fresh; they relocate on savestate load so never cache)
  local function sb1() return r32(S.gSaveBlock1Ptr) end
  local function sb2() return r32(S.gSaveBlock2Ptr) end
  local function sb3() return S.gSaveblock3 end   -- fixed EWRAM symbol, no ASLR
  self.sb1, self.sb2, self.sb3 = sb1, sb2, sb3
  local function valid() local b = sb1(); return b >= 0x02000000 and b <= 0x0203FFFF end
  self.valid = valid

  -- position / map
  local function pos() if not valid() then return -999, -999 end return rs16(sb1() + S.SaveBlock1.x), rs16(sb1() + S.SaveBlock1.y) end
  local function grp() if not valid() then return -1 end return rs8(sb1() + S.SaveBlock1.mapGroup) end
  local function mapn() if not valid() then return -1 end return rs8(sb1() + S.SaveBlock1.mapNum) end
  self.pos, self.grp, self.mapn = pos, grp, mapn

  -- overworld / battle predicates
  local function cb2() local v = r32(S.gMain + 4); return v - (v % 2) end   -- gMain.callback2 at +4
  local function ow() return cb2() == S.CB2_Overworld end
  self.cb2, self.ow = cb2, ow
  self.battlers = function() return r8(S.gBattlersCount) end
  self.battleFlags = function() return r32(S.gBattleTypeFlags) end
  self.outcome = function() return r8(S.gBattleOutcome) end

  -- money / BP (money is XORed with the SaveBlock2 encryption key)
  self.money = function() return r32(sb1() + S.SaveBlock1.money) ~ r32(sb2() + S.SaveBlock2.encryptionKey) end
  self.bp = function() return r16(sb2() + S.SaveBlock2.bp) end

  -- crash screens, READ rather than inferred.
  --
  -- A suite that dies can otherwise only report "the game stopped responding", leaving you to
  -- narrow by elimination across every assertf/fatalf site in the tree. It does not have to be
  -- that way: CrashScreen (src/assertf.c) writes its message into the BG0 screen map at VRAM as
  -- raw tile indices -- TILE0_OFFSET (40) + a glyph index -- over a 32x20 grid, and leaves it
  -- there (MODE_FATALF then spins in VBlankIntrWait forever).
  --
  -- Glyph table is assertf.c's enum: 0 space, 1 _, 2 ., 3 :, 4 /, 5..30 A-Z, 31..40 0-9. The
  -- formatter has no other glyphs, so anything it could not represent ('%', '-') was already
  -- written as '_' by the GAME -- the decode is not lossy on our side.
  --
  -- Detection is on the TEXT, not the palette. CrashScreen does memcpy its 2-colour mode palette
  -- (blue for assertf, red for fatalf) to BG_PLTT, but its wait loop calls VBlankIntrWait, and the
  -- game's VBlank handler transfers gPlttBufferFaded straight back over PRAM every frame -- so by
  -- the time anything reads it, BG_PLTT holds the interrupted scene's colours again, not the mode
  -- colour. Verified: a deliberate fatalf rendered with BG_PLTT[0]=0x0000 / [1]=0x354A (black on
  -- grey-green) rather than the 0x0014 red it asks for. The first line always starts with the
  -- __FILE__ of the failing site, so "row 0 contains '.C:' followed by a digit" is both specific
  -- and robust; a normal gameplay tilemap does not decode to that.
  --
  -- Returns nil when no crash screen is up, else (text, pltt0) where text is the decoded
  -- "FILE.C:LINE: MESSAGE" naming the failing site outright, and pltt0 is BG palette entry 0 for
  -- information only. Blue vs red is best read off the screenshot reportCrash() saves.
  --
  -- VERIFIED end-to-end, not just against the source constants: a temporary
  -- `fatalf("decoder selftest %d", 1234)` was planted in DebugAction_Party_ClearParty, driven from
  -- the debug menu, and this decoded "SRC/DEBUG.C:4940: DECODER SELFTEST 1234" plus the two return
  -- addresses -- while correctly returning nil on the frames before it fired. Re-run that way if
  -- assertf.c's glyph enum or TILE0_OFFSET ever change.
  local CRASH_GLYPHS = { [0] = " ", "_", ".", ":", "/" }
  for i = 0, 25 do CRASH_GLYPHS[5 + i] = string.char(65 + i) end
  for i = 0, 9 do CRASH_GLYPHS[31 + i] = string.char(48 + i) end
  local function crashRow(y)
    local row = {}
    for x = 0, 29 do
      row[#row + 1] = CRASH_GLYPHS[r16(0x06000000 + (x + y * 32) * 2) - 40] or "?"
    end
    return (table.concat(row):gsub("%s+$", ""))
  end
  local function crashScreen()
    -- Match across rows 0 AND 1. CrashScreen writes "FILE.C:LINE: MESSAGE" and Putc wraps at
    -- column 30, so for a path of length L the ':' lands at column L and the first digit at L+1.
    -- Any src path >= 29 chars therefore pushes the line NUMBER onto row 1, leaving row 0 as
    -- e.g. "SRC/BATTLE_ANIM_SMOKESCREEN.C:" with no digit -- and the old row-0-only match
    -- returned nil for it. 34 of the tree's src/*.c paths are that long, including files that
    -- already carry assert sites. The end-to-end proof used src/debug.c (11 chars), which
    -- structurally could not exercise the wrap.
    local head = crashRow(0) .. crashRow(1)
    if not head:match("%.C:%d") then return nil end
    local lines = {}
    for y = 0, 19 do
      local s = crashRow(y)
      if s ~= "" then lines[#lines + 1] = s end
    end
    return table.concat(lines, " | "), r16(0x05000000)
  end
  self.crashScreen = crashScreen

  -- Log + screenshot a crash if one is up. Returns true when it fired, so a walk loop can do
  -- `if F.reportCrash("step" .. i) then break end`.
  self.reportCrash = function(tag)
    local text, pltt0 = crashScreen()
    if not text then return false end
    L("  *** CRASH SCREEN (" .. tostring(tag) .. ") ***")
    L(string.format("  *** %s", text))
    L(string.format("  *** BG_PLTT[0]=0x%04X (see the screenshot for blue vs red)", pltt0))
    self.shot("crash_" .. tostring(tag))   -- self.shot, not the local: shot() is declared below
    return true, text
  end

  -- input
  local function idle(n) for _ = 1, n do joypad.set({}); emu.frameadvance() end end
  local function press(btn, frames) frames = frames or 2; for _ = 1, frames do joypad.set({ [btn] = true }); emu.frameadvance() end end
  local function tap(btn) press(btn, 2); idle(30) end
  self.idle, self.press, self.tap = idle, press, tap

  -- screenshots: names embed the step so a shorter rerun can't overwrite a longer run's shots
  local function shot(n)
    self.shotn = self.shotn + 1
    client.screenshot(self.out .. string.format("%s_%02d_%s.png", name, self.shotn, n))
    L("  shot " .. name .. "_" .. self.shotn .. "_" .. n)
  end
  self.shot = shot

  -- coordinate-verified stepping: step until coords change, then finish the tile
  local function step(dir)
    local x0, y0 = pos()
    for _ = 1, 30 do
      joypad.set({ [dir] = true }); emu.frameadvance()
      local x, y = pos()
      if x ~= x0 or y ~= y0 then
        for _ = 1, 14 do joypad.set({ [dir] = true }); emu.frameadvance() end
        idle(4); return true
      end
    end
    idle(4); return false
  end
  self.step = step
  local function face(dir) for _ = 1, 4 do joypad.set({ [dir] = true }); emu.frameadvance() end; idle(14) end
  self.face = face

  -- greedy axis-first walk to a tile (verify the target is walkable first — it is NOT a pathfinder)
  local function leg(tx, ty)
    for _ = 1, 80 do
      local x, y = pos()
      if x == tx and y == ty then return true end
      local dir
      if x < tx then dir = "Right" elseif x > tx then dir = "Left"
      elseif y < ty then dir = "Down" else dir = "Up" end
      if not step(dir) then
        L(string.format("    leg BLOCKED %s at (%d,%d)->(%d,%d)", dir, x, y, tx, ty))
        -- A stuck walk and a crashed game look identical from here: the coordinates simply stop
        -- changing. #86 built the decoder to tell them apart and then wired it into nothing, so a
        -- crash still surfaced as a mute "BLOCKED". Name it when it is one.
        self.reportCrash(string.format("leg_%d_%d", tx, ty))
        return false
      end
    end
    return false
  end
  self.leg = leg
  local function route(pts, tag)
    for i, p in ipairs(pts) do
      if not leg(p[1], p[2]) then local x, y = pos(); L(string.format("  ROUTE %s stuck wp%d at (%d,%d)", tag, i, x, y)); shot(tag .. "_stuck"); return false end
    end
    return true
  end
  self.route = route

  -- "am I on a free field tile?" — a Left+Right that returns to start proves control
  local function ensureFree()
    local x0, y0 = pos()
    local a = step("Left"); if not a then a = step("Right"); if not a then return false end end
    local x = select(1, pos())
    if x < x0 then step("Right") elseif x > x0 then step("Left") end
    local x2, y2 = pos()
    return x2 == x0 and y2 == y0
  end
  self.ensureFree = ensureFree
  -- dismiss dialogs with B ONLY (A re-opens the sign/NPC you are still facing)
  local function dismiss(maxT)
    for t = 1, (maxT or 30) do
      press("B", 2); idle(36)
      if t % 5 == 0 and ensureFree() then return true end
    end
    return ensureFree()
  end
  self.dismiss = dismiss

  -- debug menu (hold R + tap Start). Root opens at item 0 every time.
  local function dbg() press("R", 1); for _ = 1, 3 do joypad.set({ R = true, Start = true }); emu.frameadvance() end; idle(50) end
  local function sel(nDown) for _ = 1, nDown do press("Down", 2); idle(8) end; press("A", 2); idle(50) end
  local function bOut(n) for _ = 1, (n or 4) do press("B", 2); idle(25) end end
  self.dbg, self.sel, self.bOut = dbg, sel, bOut

  -- warp/give/item spinner: floor at the high digit, then build up (Level fields clamp at max)
  local function spin(h, t, o)
    press("Right", 2); idle(8); press("Right", 2); idle(8)
    for _ = 1, 6 do press("Down", 2); idle(8) end
    for _ = 1, h do press("Up", 2); idle(8) end
    press("Left", 2); idle(8); for _ = 1, t do press("Up", 2); idle(8) end
    press("Left", 2); idle(8); for _ = 1, o do press("Up", 2); idle(8) end
    press("A", 2); idle(45)
  end
  self.spin = spin
  -- self-verifying warp: Utilities(0) -> Warp to map warp(1) -> (group,num,warp) spinners; retries
  local function warpTo(gh, gt, go, mh, mt, mo, wh, wt, wo, eg, em, tag)
    for _ = 1, 6 do
      dbg(); sel(0); sel(1); idle(20)
      spin(gh, gt, go); spin(mh, mt, mo); spin(wh, wt, wo)
      idle(200)
      if grp() == eg and mapn() == em then local x, y = pos(); L(string.format("  WARP %s ok (%d,%d)", tag, x, y)); idle(40); return true end
      for _ = 1, 5 do press("B", 2); idle(20) end
    end
    shot(tag .. "_warpfail"); return false
  end
  self.warpTo = warpTo

  -- cursor-verified multichoice: read menu.c's sMenu.cursorPos instead of counting blind Downs
  local function mcur() return rs8(S.sMenu + 2) end
  self.mcur = mcur
  local function menuLive()
    local c0 = mcur(); press("Down", 2); idle(10)
    if mcur() ~= c0 then return true end
    press("Down", 2); idle(10)
    return mcur() ~= c0
  end
  self.menuLive = menuLive
  -- advance msgboxes with A until a menu is live, then Down until the cursor READS `target`, then A
  local function pick(target, tag, maxA)
    for _ = 1, (maxA or 12) do
      if menuLive() then
        for _ = 1, 12 do
          if mcur() == target then press("A", 2); idle(45); L("  pick " .. tag .. " row " .. target .. " ok"); return true end
          press("Down", 2); idle(10)
        end
        L("  pick " .. tag .. ": cursor never hit " .. target); return false
      end
      press("A", 2); idle(35)
    end
    L("  pick " .. tag .. ": menu never went live"); return false
  end
  self.pick = pick

  -- object-event dump (spawn/despawn proofs)
  local function objdump()
    local o = {}
    for i = 0, 15 do
      local b = S.gObjectEvents + i * S.ObjectEvent.stride
      if (r8(b) & 1) == 1 then
        o[#o + 1] = { i = i, x = rs16(b + S.ObjectEvent.x) - 7, y = rs16(b + S.ObjectEvent.y) - 7 }
      end
    end
    return o
  end
  self.objdump = objdump

  -- key-items pocket scan: returns (slotIndex, {ids...}) for a wanted item id (pocket 4)
  -- capacity is a 10-bit bitfield (packed with id:6 into a u16) — mask it, don't r8 (r8 only works
  -- while every pocket capacity stays < 256, which is true today but silently truncates otherwise).
  local function pocketCap(p) return r16(S.gBagPockets + p * S.BagPocket.stride + S.BagPocket.count) & 0x3FF end
  self.pocketCap = pocketCap
  local function keyItemSlot(id)
    local ptr = r32(S.gBagPockets + 4 * S.BagPocket.stride)
    local cap = pocketCap(4)
    local slot, dump = -1, {}
    if ptr >= 0x02000000 and ptr < 0x02040000 then
      for s = 0, cap - 1 do
        local iid = r16(ptr + s * 4)
        if iid ~= 0 then dump[#dump + 1] = iid end
        if iid == id and slot < 0 then slot = s end
      end
    end
    return slot, dump
  end
  self.keyItemSlot = keyItemSlot
  local function itemCount(id)
    local n = 0
    for p = 0, 4 do
      local ptr = r32(S.gBagPockets + p * S.BagPocket.stride)
      local cap = pocketCap(p)
      if ptr >= 0x02000000 and ptr < 0x02040000 and cap > 0 and cap < 200 then
        for s = 0, cap - 1 do if r16(ptr + s * 4) == id then n = n + 1 end end
      end
    end
    return n
  end
  self.itemCount = itemCount

  -- boot a fresh new game (or a loaded save) to CB2_Overworld; optional expectGroup gate.
  --
  -- boot() promises a CONTROLLABLE overworld, not merely CB2_Overworld. Since issue #41 a fresh
  -- new game lands on the RegionHub crest and the intro tour opens a Yes/No prompt on the first
  -- frame with no input, so every suite that boots into the hub arrived LOCKED and the first thing
  -- it tried to do failed for a reason that had nothing to do with what it was testing (SmokeBoot
  -- went 7/8 on "coordinate-verified step moves the player"). Clearing any on-arrival scene here
  -- fixes all of them at once and makes boot() robust to the next such scene.
  --
  -- B is the right key: it CANCELS a Yes/No (= NO) and confirms nothing, so this can never take a
  -- branch a suite did not ask for. On the tour that means the offer is declined, its done-flag is
  -- set, and the guide walks home.
  --
  -- Pass keepScene = true to skip it — for a suite whose SUBJECT is the arrival scene, which must
  -- see the prompt still open (Testing/lua/HubIntroTour*.lua).
  local function boot(expectGroup, keepScene)
    client.speedmode(self.speed)
    idle(300)
    local f = 0
    while f < 120000 and not (ow() and (not expectGroup or grp() == expectGroup)) do
      local p = f % 30
      if p < 3 then joypad.set({ A = true }) elseif p >= 15 and p < 17 then joypad.set({ Start = true }) else joypad.set({}) end
      emu.frameadvance(); f = f + 1
    end
    -- The loop exits on `ow() and group matches`, but this check tested ONLY ow() -- so exhausting
    -- the 120,000-frame budget while sitting in some OTHER overworld returned true and every
    -- caller then ran its assertions against the wrong map. Test the same condition the loop did.
    if not ow() or (expectGroup and grp() ~= expectGroup) then
      L(string.format("BOOT FAIL (overworld=%s grp=%d want=%s)",
        tostring(ow()), grp(), tostring(expectGroup)))
      -- A boot that never arrives is the other place a crash hides: MODE_FATALF spins forever, so
      -- the budget simply runs out and the suite blames the map. Read the screen before giving up.
      self.reportCrash("bootfail")
      shot("bootfail")
      return false
    end
    idle(200)
    if not keepScene then
      local cleared, tries = ensureFree(), 0
      while not cleared and tries < 40 do
        press("B", 3); idle(30)
        tries = tries + 1
        if tries % 3 == 0 then cleared = ensureFree() end
      end
      if not cleared then cleared = ensureFree() end
      if tries > 0 then
        L(string.format("  boot: cleared an on-arrival scene in %d B presses%s", tries,
          cleared and "" or " -- STILL NOT FREE"))
      end
    end
    L(string.format("BOOTED grp=%d map=%d pos=(%d,%d)", grp(), mapn(), select(1, pos()), select(2, pos())))
    return true
  end
  self.boot = boot

  -- assertions + verdict
  local function check(nm, cond, detail)
    self.results[#self.results + 1] = { name = nm, ok = cond and true or false, detail = detail or "" }
    L(string.format("  [%s] %s%s", cond and "PASS" or "FAIL", nm, (detail and detail ~= "") and (" -- " .. detail) or ""))
    return cond and true or false
  end
  self.check = check
  -- Machine-readable verdict. finish() used to call client.exit() with no status whether the run
  -- was 8/8 or 0/8, so no script, hook or agent could gate on the result — a suite regressing to
  -- 5/8 exited identically to a clean one. The log itself can be nil (see the io.open guard in
  -- new()) and is documented as reading 0 bytes from the WSL side, so the sentinel file is a
  -- separate, tiny artifact that a wrapper can stat without parsing anything.
  -- Clearing the sentinels is its own function because BOTH exit paths must do it: finish() on
  -- the normal path, and run()'s error handler on the Lua-error path. Only finish() used to, so a
  -- suite that threw left the last good run's .PASS sitting there looking current.
  local function clearVerdictSentinels()
    for _, ext in ipairs({ ".PASS", ".FAIL" }) do
      if os.remove then pcall(os.remove, self.out .. name .. ext) end
    end
  end
  self.clearVerdictSentinels = clearVerdictSentinels

  function self.finish()
    local okn = 0
    for _, r in ipairs(self.results) do if r.ok then okn = okn + 1 end end
    local total = #self.results
    -- Zero assertions is a FAILURE, not a pass: a suite that aborted before its first check
    -- would otherwise report a perfect 0/0.
    local passed = (total > 0) and (okn == total)
    L(string.format("VERDICT %s: %d/%d PASS", name, okn, total))

    -- Clear BOTH sentinels first so a previous run's verdict can never be mistaken for this one's.
    clearVerdictSentinels()
    local sentinel = io.open(self.out .. name .. (passed and ".PASS" or ".FAIL"), "w")
    if sentinel then
      -- Stamp the ROM hash and a timestamp into the body. An unstamped sentinel never expires, so
      -- "21/21 green" was a hand count over a directory that mixed today's runs with ones from
      -- six days and many builds ago -- including a suite that could not run at all. A sweep can
      -- now reject any sentinel whose rom= does not match the ROM under test.
      sentinel:write(string.format("%s %d/%d rom=%s at=%s suite=%s\n",
        passed and "PASS" or "FAIL", okn, total,
        tostring(romHashStamp(self.S)), os.date("!%Y-%m-%dT%H:%M:%SZ"), tostring(name)))
      for _, r in ipairs(self.results) do
        if not r.ok then sentinel:write("FAILED: " .. r.name .. " -- " .. r.detail .. "\n") end
      end
      sentinel:close()
    else
      L("WARNING: could not write the .PASS/.FAIL sentinel to " .. self.out)
    end

    -- Drop the handle, don't just close it. client.exit() does not stop the Lua chunk on the spot,
    -- so anything that logs afterwards reached a CLOSED file and threw
    -- "lib.lua:110: attempt to use a closed file" — printed after the verdict on every run, which
    -- reads like the suite failed at the finish line when it had already passed. Nil means L()
    -- falls back to console output, which is what a post-verdict message should do anyway.
    if self.log then self.log:close(); self.log = nil end
    client.exit(passed and 0 or 1)
  end
  -- run main() under xpcall so an EmuHawk-swallowed Lua error is logged, not silent
  function self.run(mainFn)
    local ok, err = xpcall(mainFn, debug.traceback)
    -- exit(1), not exit(): a bare client.exit() lands on `os.exit(code or 0)` in mgba_shim, so a
    -- Lua error used to leave the process reporting SUCCESS. Worse, finish() never runs on this
    -- path, so the PREVIOUS run's _pwtest/<Suite>.PASS survived untouched -- both channels a gate
    -- could read said "green" for a suite that died on its first frame.
    if not ok then
      L("LUA ERROR: " .. tostring(err))
      clearVerdictSentinels()
      if self.log then self.log:close(); self.log = nil end
      client.exit(1)
    end
  end

  return self
end

return M
