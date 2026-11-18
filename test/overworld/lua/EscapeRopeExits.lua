-- Escape Rope and Dig out of Viridian Forest, Ilex Forest and Mt. Silver land outside, on ground.
--
-- UpdateEscapeWarp records the escape point when the player warps from an outdoor map into a
-- building or cave. Emerald stored the warp cell plus one row south, which is where the player
-- stood for a door. pokefirered (src/overworld.c) adds a row only when the player is not facing
-- south, because an arrow warp entered facing south leaves the player on the warp cell with the
-- wall below, and it skips Viridian Forest, an outdoor map Escape Rope works in, so walking out
-- of the forest into a gate never names the forest as the way out.
--
-- Each case puts the player beside a real entrance with a debug warp, walks through it, then uses
-- an Escape Rope from the Bag or Dig from the party menu:
--   Viridian Forest from Route 2 (south arrow): the rope must land on Route 2's arrow cell (5,13);
--   Viridian Forest after walking out north and back in: still Route 2 (5,13);
--   Ilex Forest from Route 34 (south arrow): Escape Rope and Dig land on Route 34 (31,67);
--   Mt. Silver 2F entered from the snowfield's south arrow at (24,17), after walking in from the
--   doorstep: the rope lands on the doorstep (17,8), not in the snowfield's rock at (24,18).
-- Every landing must be a cell the player can walk off.
--
-- Run via test/overworld/mgba-run.sh test/overworld/lua/EscapeRopeExits.lua <rom>

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "EscapeRopeExits")

local HUB_GROUP = 100
local USM_ICO_PARTY, USM_ICO_BAG = 1, 2
local POCKET_ITEMS = 0
local CONTEXT_RUNNING = 0
local SPECIES_ABRA = 63
local MOVE_TELEPORT, MOVE_DIG = 100, 91
local ROW_DIG = 2
local ITEM_ESCAPE_ROPE = 120

local ROUTE2 = { g = 37, m = 20 }
local NORTH_GATE = { g = 49, m = 3 }
local FOREST = { g = 35, m = 0 }
local ROUTE34 = { g = 80, m = 2 }
local ILEX_GATE = { g = 82, m = 1 }
local ILEX = { g = 80, m = 3 }
local SILVER_OUTSIDE = { g = 97, m = 0 }
local SILVER_1F = { g = 97, m = 1 }
local SILVER_2F = { g = 97, m = 4 }
local SILVER_SNOW = { g = 97, m = 7 }

local function count() return F.r8(S.gPartiesCount) end
local function hasControl()
  return F.ow() and F.r8(S.sLockFieldControls) == 0
    and F.r8(S.sGlobalScriptContextStatus) ~= CONTEXT_RUNNING
end
local function awaitControl(budget)
  for i = 1, budget or 600 do
    if hasControl() then return true end
    if i % 30 == 0 then F.press("B", 2) else F.idle(1) end
  end
  return hasControl()
end
local function where() local x, y = F.pos(); return string.format("%d/%d (%d,%d)", F.grp(), F.mapn(), x, y) end
local function mapIs(t) return F.grp() == t.g and F.mapn() == t.m end
local function at(t, x, y)
  local px, py = F.pos()
  return mapIs(t) and px == x and py == y
end
local function escape()
  local a = F.sb1() + S.SaveBlock1.lastHealLocation + 8
  return string.format("%d/%d(%d,%d)", F.rs8(a), F.rs8(a + 1), F.rs16(a + 4), F.rs16(a + 6))
end

local function flag(id, value)
  local base, offset
  if id >= 0x6000 and id < 0x6400 then base = F.sb3() + S.SaveBlock3.johtoFlags; offset = id - 0x6000
  else base = F.sb1() + S.SaveBlock1.flags; offset = id end
  local a = base + offset // 8
  local bit = 1 << (offset % 8)
  F.w8(a, value and (F.r8(a) | bit) or (F.r8(a) & (~bit & 255)))
end

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
  b[#b + 1] = 0; b[#b + 1] = 6
  le16(b, species); le16(b, level)
  le32(b, (1 << 17) | (1 << 18) | (1 << 19) | (1 << 20))
  for k = 1, 4 do le16(b, moves[k] or 0) end
  b[#b + 1] = 0x02
  runScript(b); F.idle(20)
  return count()
end

local function d(n) return (n // 100) % 10, (n // 10) % 10, n % 10 end
local function warp(t, w, tag)
  local gh, gt, go = d(t.g)
  local mh, mt, mo = d(t.m)
  local wh, wt, wo = d(w)
  return F.warpTo(gh, gt, go, mh, mt, mo, wh, wt, wo, t.g, t.m, tag) and awaitControl(600)
end
-- Hold a direction until the map changes and the player has control again.
local function through(dir, dest, tag)
  for _ = 1, 6 do
    F.press(dir, 16)
    for _ = 1, 120 do
      if mapIs(dest) and hasControl() then F.idle(20); return true end
      F.idle(2)
    end
  end
  F.shot(tag .. "_nowarp")
  return false
end

local function inBag() return F.cb2() == (S.CB2_BagMenuRun & ~1) end
local function pocketPtr(p) return F.r32(S.gBagPockets + p * S.BagPocket.stride) end
local function qtyKey() return F.r32(F.sb2() + S.SaveBlock2.encryptionKey) & 0xFFFF end
local function ropeFirst(qty)
  local ptr = pocketPtr(POCKET_ITEMS)
  for s = 0, F.pocketCap(POCKET_ITEMS) - 1 do F.w16(ptr + s * 4, 0); F.w16(ptr + s * 4 + 2, qtyKey()) end
  F.w16(ptr, ITEM_ESCAPE_ROPE); F.w16(ptr + 2, qty ~ qtyKey())
end
local function inPartyMenu()
  local c = F.cb2()
  return c == S.CB2_UpdatePartyMenu or c == S.CB2_InitPartyMenu or c == S.CB2_PartyMenuFromStartMenu
end
local function settle(from, tag)
  for _ = 1, 600 do
    if not mapIs(from) and hasControl() then break end
    F.idle(2)
  end
  local ok = awaitControl(600)
  F.idle(40)
  F.shot(tag .. "_landed")
  return ok
end
local function escapeRope(tag)
  local from = { g = F.grp(), m = F.mapn() }
  F.w8(S.gBagPosition + 5, POCKET_ITEMS)
  F.w16(S.gBagPosition + 8 + POCKET_ITEMS * 2, 0)
  F.w16(S.gBagPosition + 18 + POCKET_ITEMS * 2, 0)
  awaitControl(300)
  F.press("Start", 2); F.idle(60)
  if not F.selectStartIcon(USM_ICO_BAG) then return false end
  F.press("A", 2)
  for _ = 1, 150 do if inBag() then break end; F.idle(2) end
  F.idle(40)
  F.press("A", 2); F.idle(40)
  F.press("A", 2); F.idle(90)
  return settle(from, tag)
end
local function dig(tag)
  local from = { g = F.grp(), m = F.mapn() }
  awaitControl(300)
  F.press("Start", 2); F.idle(60)
  if not F.selectStartIcon(USM_ICO_PARTY) then return false end
  F.press("A", 3)
  for _ = 1, 240 do F.idle(4); if inPartyMenu() then break end end
  F.idle(40)
  F.press("A", 3); F.idle(50)
  for _ = 1, ROW_DIG do F.press("Down", 2); F.idle(12) end
  F.shot(tag .. "_actions")
  F.press("A", 3); F.idle(60)
  for _ = 1, 20 do
    if not inPartyMenu() then break end
    F.press("Up", 2); F.idle(6); F.press("A", 2); F.idle(30)
  end
  return settle(from, tag)
end

-- The landing must be ground: a step off it moves the player and a step back returns.
local function walkable(tag)
  local x0, y0 = F.pos()
  for _, pair in ipairs({ { "Left", "Right" }, { "Right", "Left" }, { "Up", "Down" }, { "Down", "Up" } }) do
    local g, m = F.grp(), F.mapn()
    if F.step(pair[1]) then
      local moved = F.grp() == g and F.mapn() == m
      F.step(pair[2])
      local x, y = F.pos()
      if moved and x == x0 and y == y0 then return true end
    end
  end
  F.shot(tag .. "_stuck")
  return false
end
local function landing(tag, t, x, y)
  F.L(string.format("  %s: landed %s escape=%s", tag, where(), escape()))
  F.check(tag .. ": lands at " .. string.format("%d/%d (%d,%d)", t.g, t.m, x, y), at(t, x, y), where())
  F.check(tag .. ": the landing is walkable ground", walkable(tag))
end

F.run(function()
  if not F.boot(HUB_GROUP) then F.check("boot to the hub", false); F.finish(); return end
  F.w16(F.sb2() + S.SaveBlock2.optionsU16, (F.r16(F.sb2() + S.SaveBlock2.optionsU16) & ~7) | 3)
  for _, id in ipairs({ 0xDCF, 0x51, 0xA4B, 0x63F8, 0x94F, 0x95F, 0x63FC, 0x63FD, 0x948, 0x61E5 }) do flag(id, true) end
  F.w8(F.sb2() + S.SaveBlock2.introDoneBits, 7)
  createMon(SPECIES_ABRA, 30, { MOVE_TELEPORT, MOVE_DIG })
  ropeFirst(20)
  awaitControl(300)
  F.check("setup: an Abra with Dig", count() == 1, "party=" .. count())

  -- Viridian Forest, entered from Route 2 through the north gate.
  local ok = warp(ROUTE2, 0, "route2") and through("Down", NORTH_GATE, "north_gate")
    and F.route({ { 7, 10 } }, "gate_walk") and through("Down", FOREST, "forest")
  F.check("viridian: walked from Route 2 into Viridian Forest", ok, where())
  if ok then
    F.L("  viridian: escape=" .. escape())
    F.check("viridian rope: the Bag returned to the field", escapeRope("viridian_rope"), where())
    landing("viridian rope", ROUTE2, 5, 13)
  end

  -- Out of the forest's north exit into the gate and straight back in.
  ok = warp(ROUTE2, 0, "route2_again") and through("Down", NORTH_GATE, "north_gate2")
    and F.route({ { 7, 10 } }, "gate_walk2") and through("Down", FOREST, "forest2")
    and F.step("Down") and F.step("Up") and through("Up", NORTH_GATE, "forest_exit")
    and through("Down", FOREST, "forest3")
  F.check("viridian: left the forest north and walked back in", ok, where())
  if ok then
    F.L("  viridian re-entry: escape=" .. escape())
    F.check("viridian re-entry rope: the Bag returned to the field", escapeRope("viridian_rope2"), where())
    landing("viridian re-entry rope", ROUTE2, 5, 13)
  end

  -- Ilex Forest, entered from Route 34 through its gate.
  ok = warp(ROUTE34, 0, "route34") and through("Down", ILEX_GATE, "ilex_gate")
    and F.route({ { 7, 9 } }, "ilex_gate_walk") and through("Down", ILEX, "ilex")
  F.check("ilex: walked from Route 34 into Ilex Forest", ok, where())
  if ok then
    F.L("  ilex: escape=" .. escape())
    F.check("ilex rope: the Bag returned to the field", escapeRope("ilex_rope"), where())
    landing("ilex rope", ROUTE34, 31, 67)
  end
  ok = warp(ROUTE34, 0, "route34_dig") and through("Down", ILEX_GATE, "ilex_gate_dig")
    and F.route({ { 7, 9 } }, "ilex_gate_walk_dig") and through("Down", ILEX, "ilex_dig")
  F.check("ilex: walked back into Ilex Forest", ok, where())
  if ok then
    F.check("ilex dig: the party menu returned to the field", dig("ilex_dig"), where())
    landing("ilex dig", ROUTE34, 31, 67)
  end

  -- Mt. Silver: in from the doorstep, then into 2F from the snowfield's south arrow.
  ok = warp(SILVER_OUTSIDE, 0, "silver_door") and F.step("Down") and through("Up", SILVER_1F, "silver_1f")
  F.check("mt silver: walked in from the doorstep", ok, where())
  F.L("  mt silver doorstep: escape=" .. escape())
  ok = ok and warp(SILVER_SNOW, 6, "silver_snow") and through("Down", SILVER_2F, "silver_2f")
  F.check("mt silver: walked into 2F from the snowfield", ok, where())
  if ok then
    F.L("  mt silver 2F: escape=" .. escape())
    F.check("mt silver rope: the Bag returned to the field", escapeRope("silver_rope"), where())
    landing("mt silver rope", SILVER_OUTSIDE, 17, 8)
  end
  F.finish()
end)
