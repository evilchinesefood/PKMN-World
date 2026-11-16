-- The Frontier Pass (Start menu Trainer icon once FLAG_SYS_FRONTIER_PASS is set) with five symbol
-- states seeded through the facilities' own flags: none, all silver, all gold, a mix, and gold flags
-- without silver; Battle Points 0 to 9999. Each case opens the pass and with real input zooms the
-- Trainer Card and flips it, zooms the Battle Frontier map and walks its facility list both ways,
-- points at Battle Record with no record, then mashes seeded random input for 2,500 presses; the pass
-- must always come back to the field with no crash.
--
-- Run via test/overworld/mgba-run.sh test/overworld/lua/FrontierPassStress.lua <rom>
local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "FrontierPassStress")
local FLAG_TOWER_SILVER = 0x9AC   -- FLAG_SYS_TOWER_SILVER; each facility has a silver and a gold flag
local FLAG_FRONTIER_PASS = 0x9BA  -- FLAG_SYS_FRONTIER_PASS, set at the Reception Gate
local USM_ICO_TRAINER = 5

local function setFlag(fl, on)
  local a = F.sb1() + S.SaveBlock1.flags + (fl >> 3)
  local b = F.r8(a)
  if on then b = b | (1 << (fl & 7)) else b = b & ~(1 << (fl & 7)) end
  F.w8(a, b)
end

local function hold(btn, n) for _ = 1, n do joypad.set({ [btn] = true }); emu.frameadvance() end; F.idle(20) end

local CASES = {
  { name = "none", sym = { 0, 0, 0, 0, 0, 0, 0 }, bp = 0 },
  { name = "silver", sym = { 1, 1, 1, 1, 1, 1, 1 }, bp = 9999 },
  { name = "gold", sym = { 2, 2, 2, 2, 2, 2, 2 }, bp = 5 },
  { name = "mixed", sym = { 2, 0, 1, 2, 0, 1, 2 }, bp = 123 },
  { name = "goldonly", sym = { 3, 3, 3, 3, 3, 3, 3 }, bp = 1000 },
}

local function openPass(tag)
  F.press("Start", 2); F.idle(60)
  if not F.selectStartIcon(USM_ICO_TRAINER) then F.L("no trainer icon"); return false end
  F.press("A", 2); F.idle(150)
  F.shot(tag .. "_pass")
  return not F.ow()
end

F.run(function()
  if not F.boot(100) then F.check("boot", false); F.finish(); return end
  local base = F.out .. "FrontierPassStress_base.ss"
  client.savestate(base)
  for _, c in ipairs(CASES) do
    client.loadstate(base); F.idle(10)
    setFlag(FLAG_FRONTIER_PASS, true)
    for i = 0, 6 do
      local s = c.sym[i + 1]
      setFlag(FLAG_TOWER_SILVER + i * 2, s == 1 or s == 2)
      setFlag(FLAG_TOWER_SILVER + i * 2 + 1, s == 2 or s == 3)
    end
    F.w16(F.sb2() + S.SaveBlock2.bp, c.bp)
    local t = c.name
    if F.check(t .. ": pass opened", openPass(t)) then
      F.press("A", 2); F.idle(120); F.shot(t .. "_card_zoom")
      F.press("A", 2); F.idle(120); F.shot(t .. "_card_flip")
      F.press("A", 2); F.idle(120); F.shot(t .. "_card_flip2")
      hold("Up", 30); F.shot(t .. "_cursor_up")
      F.press("A", 2); F.idle(150); F.shot(t .. "_map")
      for i = 1, 8 do F.press("Down", 2); F.idle(25) end
      F.shot(t .. "_map_down8")
      for i = 1, 3 do F.press("Up", 2); F.idle(25) end
      F.shot(t .. "_map_up3")
      F.press("B", 2); F.idle(150); F.shot(t .. "_map_back")
      hold("Left", 60); hold("Down", 20); F.shot(t .. "_cursor_record")
      F.press("A", 2); F.idle(60); F.shot(t .. "_record_a")
      math.randomseed(#t * 7)
      local keys = { "A", "B", "Up", "Down", "Left", "Right", "Select", "Start", "L", "R" }
      for f = 1, 2500 do
        if F.ow() then break end
        local k = keys[math.random(#keys)]
        if k == "B" and math.random(8) > 1 then k = "A" end
        F.press(k, math.random(1, 12)); F.idle(math.random(0, 4))
        if F.reportCrash(t .. "_spam") then break end
      end
      F.shot(t .. "_spam_end")
      for _ = 1, 30 do if F.ow() then break end; F.press("B", 2); F.idle(40) end
      F.check(t .. ": back on the field", F.ow())
    end
  end
  F.check("no crash", not F.crashScreen())
  F.finish()
end)
