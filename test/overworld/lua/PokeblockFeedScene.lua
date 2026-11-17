-- The Pokeblock feeding scene (src/pokeblock_feed.c), which #634 gave a private copy of the old
-- building tiles and Frontier palette, driven from the Pokeblock Case with real input.
--
-- Setup gives two Pokemon, the Pokeblock Case and Pokeblocks written into SaveBlock1.pokeblocks
-- the way AddPokeblock leaves them. Select (the case registered) opens the case; USE, the Pokemon,
-- YES and the scene itself are real input. Each feed must run the scene, take the block out of the
-- case, raise the Pokemon's condition by the block's flavour and its sheen by the block's feel, show
-- the condition results and come back to the case. Mashed feeds (A, B and Start) must end the same
-- way. Feeding past the sheen cap must be refused with "won't eat anymore" and keep the block.
-- Screenshots of the background, the toss, the results and the case are left for review.
local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "PokeblockFeedScene")

local SPECIES_ZIGZAGOON, SPECIES_TORCHIC = 263, 255
local MOVE_TACKLE = 33
local ITEM_POKEBLOCK_CASE = 722
local POKEBLOCKS_COUNT, POKEBLOCK_SIZE = 40, 8
local CONTEXT_RUNNING = 0
local PARTY_SIZE = 6

local SCRIPT_BUF = S.gStringVar4 + 960
local function le16(t, v) t[#t + 1] = v & 0xFF; t[#t + 1] = (v >> 8) & 0xFF end
local function le32(t, v) le16(t, v & 0xFFFF); le16(t, (v >> 16) & 0xFFFF) end
local function runScript(bytes)
  for i, b in ipairs(bytes) do F.w8(SCRIPT_BUF + i - 1, b) end
  F.w8(S.sGlobalScriptContext, 0)
  F.w8(S.sGlobalScriptContext + 1, 1)
  F.w32(S.sGlobalScriptContext + 4, 0)
  F.w32(S.sGlobalScriptContext + S.ScriptCtx.scriptPtr, SCRIPT_BUF)
  F.w8(S.sGlobalScriptContextStatus, CONTEXT_RUNNING)
  F.idle(20)
end
local function giveMon(species, level, moves)
  local b = { 0x23 }; le32(b, S.ScrCmd_createmon | 1)
  b[#b + 1] = 0; b[#b + 1] = PARTY_SIZE
  le16(b, species); le16(b, level)
  le32(b, (1 << 17) | (1 << 18) | (1 << 19) | (1 << 20))
  for k = 1, 4 do le16(b, moves[k] or 0) end
  b[#b + 1] = 0x02
  runScript(b)
end
local function addItem(id, qty) runScript({ 0x44, id & 0xFF, id >> 8, qty & 0xFF, qty >> 8, 0x02 }) end

local function pbAddr(i) return F.sb1() + S.SaveBlock1.pokeblocks + i * POKEBLOCK_SIZE end
local function setBlock(i, b)
  for k = 0, 6 do F.w8(pbAddr(i) + k, b[k + 1] or 0) end
end
local function getBlock(i)
  local t = {}
  for k = 0, 6 do t[k + 1] = F.r8(pbAddr(i) + k) end
  return t
end
local function blockCount()
  local n = 0
  for i = 0, POKEBLOCKS_COUNT - 1 do if F.r8(pbAddr(i)) ~= 0 then n = n + 1 end end
  return n
end

-- Condition bytes (cool, beauty, cute, smart, tough, sheen) live in the EV substruct, encrypted
-- with personality ^ otId; EV_POS gives its slot for each personality % 24.
local EV_POS = { 2, 3, 1, 1, 3, 2, 2, 3, 1, 1, 3, 2, 0, 0, 0, 0, 0, 0, 3, 2, 3, 2, 1, 1 }
local function condition(slot)
  local b = S.gParties + slot * S.Pokemon.size
  local pid, otid = F.r32(b), F.r32(b + 4)
  local key = pid ~ otid
  local base = b + 32 + 12 * EV_POS[(pid % 24) + 1]
  local w1, w2 = F.r32(base + 4) ~ key, F.r32(base + 8) ~ key
  -- bytes 6..11 of the substruct: cool beauty cute smart tough sheen
  return { cool = (w1 >> 16) & 0xFF, beauty = (w1 >> 24) & 0xFF, cute = w2 & 0xFF, smart = (w2 >> 8) & 0xFF,
           tough = (w2 >> 16) & 0xFF, sheen = (w2 >> 24) & 0xFF }
end
local function fmtCond(c)
  return string.format("cool=%d beauty=%d cute=%d smart=%d tough=%d sheen=%d", c.cool, c.beauty, c.cute, c.smart,
    c.tough, c.sheen)
end
local function condSum(c) return c.cool + c.beauty + c.cute + c.smart + c.tough end

local function hasControl()
  return F.ow() and F.r8(S.sLockFieldControls) == 0 and F.r8(S.sGlobalScriptContextStatus) ~= CONTEXT_RUNNING
end
local function awaitCb(name, budget)
  for _ = 1, budget or 900 do
    if F.cb2() == S[name] then F.idle(40); return true end
    F.idle(1)
  end
  return false
end

-- A seeded mash of A, B and Start. PW_PB_SEED=<n> reseeds it.
local seed = tonumber(os.getenv("PW_PB_SEED") or "") or 7
local function rnd(n) seed = (seed * 1103515245 + 12345) % 2147483648; return seed % n end
local MASH = { "A", "B", "Start" }

-- Open the case with Select, pick the block on `row`, USE, pick the Pokemon on `monRow`, YES, then
-- watch the scene. Returns what was seen.
local function feed(tag, row, monRow, mash)
  local shotTag = tag:gsub("%W", "_")
  local seen = { feed = false, results = false, back = false, wontEat = false }
  F.press("Select", 2)
  if not awaitCb("CB2_PokeblockMenu", 600) then F.L("  " .. tag .. ": the case never opened"); return seen end
  for _ = 1, row do F.press("Down", 2); F.idle(12) end
  F.press("A", 2); F.idle(30)         -- the block's menu
  F.press("A", 2)                     -- USE
  if not awaitCb("CB2_UsePokeblockMenu", 600) then F.L("  " .. tag .. ": USE did not open the party"); return seen end
  F.idle(40)
  for _ = 1, monRow do F.press("Down", 2); F.idle(20) end
  F.press("A", 2); F.idle(40)         -- the Pokemon: YES/NO, or "won't eat"
  if F.cb2() == S.CB2_UsePokeblockMenu then F.shot(shotTag .. "_ask") end
  F.press("A", 2)                     -- YES
  for i = 1, 300 do
    if F.cb2() == S.CB2_PokeblockFeed then seen.feed = true; break end
    F.idle(1)
  end
  if not seen.feed then
    seen.wontEat = true
    F.shot(shotTag .. "_wont_eat")
    F.press("A", 2); F.idle(30)
    F.press("B", 2)
    seen.back = awaitCb("CB2_PokeblockMenu", 600)
    F.press("B", 2)
    awaitCb("CB2_Overworld", 900)
    return seen
  end
  local shots = { [60] = "bg", [200] = "toss", [700] = "ate" }
  for i = 1, 4000 do
    if F.cb2() ~= S.CB2_PokeblockFeed then break end
    if shots[i] then F.shot(shotTag .. "_" .. shots[i]) end
    if mash then
      if rnd(4) == 0 then F.press(MASH[rnd(#MASH) + 1], 2) else F.idle(1) end
    elseif i > 600 and i % 40 == 0 then
      F.press("A", 2)
    else
      F.idle(1)
    end
    if i % 300 == 0 and F.reportCrash(tag) then return seen end
  end
  seen.results = awaitCb("CB2_UsePokeblockMenu", 600)
  F.idle(120)
  F.shot(shotTag .. "_results")
  for _ = 1, 40 do
    if F.cb2() == S.CB2_PokeblockMenu then break end
    F.press("A", 2); F.idle(30)
  end
  seen.back = awaitCb("CB2_PokeblockMenu", 300)
  F.shot(shotTag .. "_case")
  F.press("B", 2)
  awaitCb("CB2_Overworld", 900)
  return seen
end

local function feedCase(tag, row, monRow, block, mash)
  local slot = monRow
  local before, n0 = condition(slot), blockCount()
  local seen = feed(tag, row, monRow, mash)
  local after, n1 = condition(slot), blockCount()
  F.L(string.format("  %s: %s -> %s", tag, fmtCond(before), fmtCond(after)))
  F.check(tag .. ": the feeding scene ran", seen.feed)
  F.check(tag .. ": the condition results followed and the case came back", seen.results and seen.back)
  F.check(tag .. ": one Pokeblock left the case", n1 == n0 - 1, n0 .. " -> " .. n1)
  F.check(tag .. ": the condition rose by the block's flavour and the sheen by its feel",
    condSum(after) > condSum(before) and after.sheen == math.min(255, before.sheen + block[7]), fmtCond(after))
  F.check(tag .. ": control returns on the field", hasControl() or (F.idle(60) or hasControl()))
end

F.run(function()
  if not F.boot(100) then F.check("boot", false); F.finish(); return end
  giveMon(SPECIES_ZIGZAGOON, 20, { MOVE_TACKLE })
  giveMon(SPECIES_TORCHIC, 20, { MOVE_TACKLE })
  addItem(ITEM_POKEBLOCK_CASE, 1)
  F.check("setup: two Pokemon and the Pokeblock Case", F.r8(S.gPartiesCount) == 2 and F.itemCount(ITEM_POKEBLOCK_CASE) == 1)
  -- color, spicy, dry, sweet, bitter, sour, feel
  local RED = { 1, 20, 0, 0, 0, 0, 10 }
  local BLUE = { 2, 0, 20, 0, 0, 0, 10 }
  local GOLD = { 14, 30, 30, 30, 30, 30, 90 }
  setBlock(0, RED); setBlock(1, BLUE)
  for i = 2, 6 do setBlock(i, GOLD) end
  F.w16(F.sb1() + S.SaveBlock1.registeredItem, ITEM_POKEBLOCK_CASE)

  F.check("warped to Route 117", F.warpTo(0, 0, 0, 0, 3, 2, 0, 0, 0, 0, 32, "route117"))
  for _ = 1, 300 do if hasControl() then break end F.idle(1) end

  feedCase("red to Zigzagoon", 0, 0, RED, false)
  -- The case keeps its order with the fed block gone, so BLUE is on row 0 now.
  feedCase("blue to Torchic, mashed", 0, 1, BLUE, true)
  feedCase("gold to Zigzagoon, mashed", 0, 0, GOLD, true)
  feedCase("gold to Zigzagoon", 0, 0, GOLD, false)
  feedCase("gold to Zigzagoon, sheen to the cap", 0, 0, GOLD, true)
  local full = condition(0)
  F.check("Zigzagoon's sheen is at the cap", full.sheen == 255, fmtCond(full))
  local n0 = blockCount()
  local seen = feed("a fourth gold to a full Zigzagoon", 0, 0, true)
  F.check("a full Zigzagoon won't eat: no scene, the block stays, the case comes back",
    seen.wontEat and not seen.feed and blockCount() == n0 and seen.back, string.format("blocks %d -> %d", n0, blockCount()))
  F.check("control returns on the field", hasControl())
  F.finish()
end)
