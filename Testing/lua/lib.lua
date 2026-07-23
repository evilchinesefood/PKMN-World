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

-- ---- construction --------------------------------------------------------------------------
-- opts: { out = "C:\\...\\_pwtest\\", speed = 800 }. `out` is where the log + shots land.
function M.new(S, name, opts)
  opts = opts or {}
  local self = {}
  self.S = S
  self.name = name
  self.out = opts.out or "C:\\Users\\evilc\\Github\\PKMN-World\\_pwtest\\"
  self.speed = opts.speed or 800
  self.shotn = 0
  self.results = {}
  self.log = io.open(self.out .. name .. ".log", "w")

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
  local function grp() if not valid() then return -1 end return r8(sb1() + S.SaveBlock1.mapGroup) end
  local function mapn() if not valid() then return -1 end return r8(sb1() + S.SaveBlock1.mapNum) end
  self.pos, self.grp, self.mapn = pos, grp, mapn

  -- overworld / battle predicates
  local function cb2() local v = r32(S.gMain + 4); return v - (v % 2) end   -- gMain.callback2 at +4
  local function ow() return cb2() == S.CB2_Overworld end
  self.cb2, self.ow = cb2, ow
  self.battlers = function() return r8(S.gBattlersCount) end
  self.battleFlags = function() return r32(S.gBattleTypeFlags) end
  self.outcome = function() return r8(S.gBattleOutcome) end

  -- money / BP (money is XORed with the SaveBlock2 encryption key)
  self.money = function() return bit.bxor(r32(sb1() + S.SaveBlock1.money), r32(sb2() + S.SaveBlock2.encryptionKey)) end
  self.bp = function() return r16(sb2() + S.SaveBlock2.bp) end

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
      if not step(dir) then L(string.format("    leg BLOCKED %s at (%d,%d)->(%d,%d)", dir, x, y, tx, ty)); return false end
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
  local function keyItemSlot(id)
    local ptr = r32(S.gBagPockets + 4 * S.BagPocket.stride)
    local cap = r8(S.gBagPockets + 4 * S.BagPocket.stride + S.BagPocket.count)
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
      local cap = r8(S.gBagPockets + p * S.BagPocket.stride + S.BagPocket.count)
      if ptr >= 0x02000000 and ptr < 0x02040000 and cap > 0 and cap < 200 then
        for s = 0, cap - 1 do if r16(ptr + s * 4) == id then n = n + 1 end end
      end
    end
    return n
  end
  self.itemCount = itemCount

  -- boot a fresh new game (or a loaded save) to CB2_Overworld; optional expectGroup gate
  local function boot(expectGroup)
    client.speedmode(self.speed)
    idle(300)
    local f = 0
    while f < 120000 and not (ow() and (not expectGroup or grp() == expectGroup)) do
      local p = f % 30
      if p < 3 then joypad.set({ A = true }) elseif p >= 15 and p < 17 then joypad.set({ Start = true }) else joypad.set({}) end
      emu.frameadvance(); f = f + 1
    end
    if not ow() then L("BOOT FAIL"); shot("bootfail"); return false end
    idle(200)
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
  function self.finish()
    local okn = 0
    for _, r in ipairs(self.results) do if r.ok then okn = okn + 1 end end
    L(string.format("VERDICT %s: %d/%d PASS", name, okn, #self.results))
    if self.log then self.log:close() end
    client.exit()
  end
  -- run main() under xpcall so an EmuHawk-swallowed Lua error is logged, not silent
  function self.run(mainFn)
    local ok, err = xpcall(mainFn, debug.traceback)
    if not ok then L("LUA ERROR: " .. tostring(err)); if self.log then self.log:close() end client.exit() end
  end

  return self
end

return M
