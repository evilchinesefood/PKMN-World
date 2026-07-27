-- Issue #24 acceptance: the expanded bag + item PC really shipped, and survives a save/reload.
-- Evidence suite.
--
--   cp <repo>\pokemonworld.gba  BizHawk\Verify1.gba
--   EmuHawk.exe BizHawk\Verify1.gba --lua=<repo>\Testing\lua\VerifyBagLayout.lua
--
-- Why the pointer-spacing checks and not just the capacities: gBagPockets[p].capacity is written
-- from BAG_*_COUNT at runtime, so reading it back only proves the *constant* changed. The thing
-- #24 actually did was resize `struct Bag` inside SaveBlock1. Consecutive pockets are contiguous
-- fields, so the gap between two pocket pointers IS the earlier pocket's real slot count x 4.
-- That distinguishes "the header says 99" from "the save block genuinely holds 99".
local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(require("symbols"), "VerifyBagLayout")

-- include/constants/global.h
local CAP = { [0] = 60, [1] = 16, [2] = 64, [3] = 46, [4] = 99 }  -- Items, Balls, TMHM, Berries, Key
local NAME = { [0] = "Items", [1] = "PokeBalls", [2] = "TMHM", [3] = "Berries", [4] = "KeyItems" }
local PC_ITEMS_COUNT = 150
local OLD_CAP = 30              -- the pre-#24 Items / Key Items cap
local PCITEMS_OFF = 0x4A0       -- include/global.h; the one offset comment that is still correct

local function pocketPtr(p) return F.r32(S.gBagPockets + p * S.BagPocket.stride + S.BagPocket.itemsPtr) end

-- count occupied slots by walking the pocket's real slot array (ItemSlot{u16 id, u16 qty}, stride 4)
local function occupied(p)
  local ptr, cap, n = pocketPtr(p), F.pocketCap(p), 0
  if ptr < 0x02000000 or ptr >= 0x02040000 then return -1 end
  for s = 0, cap - 1 do if F.r16(ptr + s * 4) ~= 0 then n = n + 1 end end
  return n
end

-- Occupancy is seeded by writing sentinel item ids straight into the pocket's slot array rather
-- than by driving PC/Bag -> Fill... The debug route was tried first and is not usable as evidence:
-- it depends on submenu cursor state that is documented to persist between opens, so a run where
-- the fill silently never fires reports "0 occupied" — indistinguishable from a real defect.
-- A direct write needs no navigation and tests the stronger claim anyway: that a slot ABOVE the
-- old 30-slot cap is genuinely inside SaveBlock1 and round-trips through flash. Item ids are not
-- encryption-keyed (only quantities are), so the id reads back verbatim.
local SENTINEL = 28              -- ITEM_POTION
local PROBE_SLOT = { [0] = 45, [4] = 90 }   -- both well past the old cap of 30
local function seed(p)
  local ptr = pocketPtr(p)
  F.w16(ptr + PROBE_SLOT[p] * 4, SENTINEL)
  F.w16(ptr + PROBE_SLOT[p] * 4 + 2, 1)
  F.L(string.format("  seeded %s slot %d with item %d", NAME[p], PROBE_SLOT[p], SENTINEL))
end
local function probeReads(p) return F.r16(pocketPtr(p) + PROBE_SLOT[p] * 4) end

F.run(function()
  if not F.boot(100) then F.check("boot to overworld", false); F.finish(); return end

  -- ---- 1. capacities actually present in the shipped ROM -------------------------------------
  for p = 0, 4 do
    F.check("cap " .. NAME[p] .. " == " .. CAP[p], F.pocketCap(p) == CAP[p], "got " .. F.pocketCap(p))
  end

  -- ---- 2. struct Bag was genuinely resized (pointer spacing == capacity x 4) ------------------
  local sb1 = F.sb1()
  local ptr = {}
  for p = 0, 4 do ptr[p] = pocketPtr(p) end
  -- field order in `struct Bag`: items, keyItems, pokeBalls, TMsHMs, berries
  local ORDER = { 0, 4, 1, 2, 3 }
  for i = 1, #ORDER - 1 do
    local a, b = ORDER[i], ORDER[i + 1]
    local want = CAP[a] * 4
    F.check(string.format("gap %s->%s == %d B", NAME[a], NAME[b], want), ptr[b] - ptr[a] == want,
      string.format("got %d", ptr[b] - ptr[a]))
  end
  for p = 0, 4 do
    F.check(NAME[p] .. " pocket ptr inside SaveBlock1 and 4-aligned",
      ptr[p] > sb1 and ptr[p] < sb1 + 0x4000 and ptr[p] % 4 == 0,
      string.format("+0x%X", ptr[p] - sb1))
  end

  -- ---- 3. the item PC really holds 150 (bag sits directly after pcItems) ----------------------
  local bagOff = ptr[0] - sb1
  F.check("bag offset == pcItems + PC_ITEMS_COUNT*4", bagOff == PCITEMS_OFF + PC_ITEMS_COUNT * 4,
    string.format("bag at +0x%X, expected +0x%X", bagOff, PCITEMS_OFF + PC_ITEMS_COUNT * 4))

  -- ---- 4. a slot past the OLD cap is real storage, not just a bigger capacity field -----------
  seed(0); seed(4)
  F.check(string.format("Items slot %d (> old cap %d) holds the written id", PROBE_SLOT[0], OLD_CAP),
    probeReads(0) == SENTINEL, "read " .. probeReads(0))
  F.check(string.format("Key Items slot %d (> old cap %d) holds the written id", PROBE_SLOT[4], OLD_CAP),
    probeReads(4) == SENTINEL, "read " .. probeReads(4))
  local occItems, occKey = occupied(0), occupied(4)
  F.L(string.format("  occupied: Items=%d KeyItems=%d", occItems, occKey))

  -- ---- 5. persistence: save, reboot the core, reload, recount --------------------------------
  F.press("Start", 2); F.idle(60)
  for _ = 1, 10 do F.press("Left", 2); F.idle(8) end      -- pin wheel slot 0
  F.press("Right", 2); F.idle(12); F.press("Right", 2); F.idle(12)  -- -> Save
  F.press("A", 2); F.idle(90); F.press("A", 2); F.idle(60); F.press("A", 2); F.idle(240)
  F.idle(300)                                            -- let flash flush
  F.L("  saved; rebooting core")

  client.reboot_core()
  F.idle(240)
  if not F.boot(100) then
    F.check("reboot + reload reaches the overworld", false)
  else
    F.check("reboot + reload reaches the overworld", true)
    local rItems, rKey = occupied(0), occupied(4)
    F.L(string.format("  after reload: Items=%d KeyItems=%d", rItems, rKey))
    -- The load-bearing one: a slot past the old cap round-tripped through flash. If SaveBlock1's
    -- saved region did not really cover the expanded bag, this is where it would read back 0.
    F.check(string.format("Items slot %d survived save/reload", PROBE_SLOT[0]),
      probeReads(0) == SENTINEL, "read " .. probeReads(0))
    F.check(string.format("Key Items slot %d survived save/reload", PROBE_SLOT[4]),
      probeReads(4) == SENTINEL, "read " .. probeReads(4))
    F.check("Items pocket occupancy survived save/reload", rItems == occItems,
      string.format("before=%d after=%d", occItems, rItems))
    F.check("Key Items pocket occupancy survived save/reload", rKey == occKey,
      string.format("before=%d after=%d", occKey, rKey))
    F.check("capacities still correct after reload",
      F.pocketCap(0) == CAP[0] and F.pocketCap(4) == CAP[4],
      string.format("items=%d key=%d", F.pocketCap(0), F.pocketCap(4)))
    F.shot("reloaded")
  end

  F.finish()
end)
