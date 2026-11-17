-- The Berry Blender in Lilycove's Contest Lobby against a full or nearly full Pokeblock Case.
--
-- Setup gives the Pokeblock Case, Berries and a Pokemon, and writes Pokeblocks into
-- SaveBlock1.pokeblocks the way AddPokeblock leaves them. Talking to the two-person blender, the
-- Yes/No prompts, the Berry from the Bag, the blending and the "blend another" prompt are real
-- input. With 40 Pokeblocks the blender must refuse before it starts: no Berry taken, the case
-- unchanged. With 39, one blend must take exactly one Berry and fill the case; asking to blend
-- again must say the case is full and end without taking another Berry or losing the block.
-- PW_BLEND_TRACE=1 screenshots the run.
local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "BlenderFullCase")

local CONTEST_LOBBY = { 13, 4 }
local SPECIES_ZIGZAGOON = 263
local MOVE_TACKLE = 33
local ITEM_POKEBLOCK_CASE, ITEM_CHERI_BERRY, ITEM_PECHA_BERRY = 722, 514, 516
local POKEBLOCKS_COUNT, POKEBLOCK_SIZE = 40, 8
local CONTEXT_RUNNING = 0
local PARTY_SIZE = 6
local TRACE = os.getenv("PW_BLEND_TRACE")

local function where() local x, y = F.pos(); return string.format("%d/%d (%d,%d)", F.grp(), F.mapn(), x, y) end
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

local function qty(id)
  local key = F.r16(F.sb2() + S.SaveBlock2.encryptionKey)
  local n = 0
  for p = 0, 4 do
    local ptr = F.r32(S.gBagPockets + p * S.BagPocket.stride)
    local cap = F.pocketCap(p)
    if ptr >= 0x02000000 and ptr < 0x02040000 then
      for s = 0, cap - 1 do
        if F.r16(ptr + s * 4) == id then n = n + (F.r16(ptr + s * 4 + 2) ~ key) end
      end
    end
  end
  return n
end

local function pbAddr(i) return F.sb1() + S.SaveBlock1.pokeblocks + i * POKEBLOCK_SIZE end
local function fillCase(n)
  for i = 0, POKEBLOCKS_COUNT - 1 do
    local b = i < n and { 2, 0, 15, 0, 0, 0, 12 } or { 0, 0, 0, 0, 0, 0, 0 }
    for k = 0, 6 do F.w8(pbAddr(i) + k, b[k + 1]) end
  end
end
local function blockCount()
  local n = 0
  for i = 0, POKEBLOCKS_COUNT - 1 do if F.r8(pbAddr(i)) ~= 0 then n = n + 1 end end
  return n
end

local function hasControl()
  return F.ow() and F.r8(S.sLockFieldControls) == 0 and F.r8(S.sGlobalScriptContextStatus) ~= CONTEXT_RUNNING
end
local function awaitControl(budget)
  for i = 1, budget or 900 do
    if hasControl() and i > 20 then return true end
    F.idle(1)
  end
  return hasControl()
end

local tn = 0
local function trace(tag) if TRACE then tn = tn + 1; F.shot(string.format("%s_%03d", tag, tn)) end end

local function berries() return qty(ITEM_CHERI_BERRY) + qty(ITEM_PECHA_BERRY) end
local function cb(name) return S[name] and F.cb2() == S[name] end

-- Talk to the blender and answer every prompt with A (YES). Returns "bag" once the Berry Bag is
-- up, or "field" if the talk ended on the field without the blender starting.
local function talk(tag)
  F.face("Up")
  F.press("A", 2)
  local sawText = false
  for i = 1, 1200 do
    if not F.ow() then
      for k = 1, 1500 do
        if F.cb2() == S.CB2_BagMenuRun then F.idle(40); return "bag" end
        if k % 30 == 0 then F.press("A", 2) else F.idle(1) end
      end
      return string.format("other %08X", F.cb2())
    end
    if i > 60 and hasControl() then return "field" end
    if i % 30 == 0 then
      if not sawText and i > 60 then F.shot(tag .. "_talk"); sawText = true end
      F.press("A", 2)
    else F.idle(1) end
    if i % 120 == 0 and i <= 480 then F.shot(tag .. "_message") end
  end
  return "timeout"
end

-- In the Bag: pick the Berry on `row`, Confirm, play by tapping A, then answer every later prompt
-- with A until the field comes back. Returns the blends seen.
local function blendFromBag(tag, row)
  for _ = 1, row do F.press("Down", 2); F.idle(12) end
  F.press("A", 2); F.idle(30)
  F.press("A", 2)
  local blends, inGame, shots = 0, false, 0
  for i = 1, 30000 do
    if F.ow() and i > 120 then break end
    local playing = cb("CB2_PlayBlender")
    if playing and not inGame then blends = blends + 1; F.L(string.format("  %s: blend %d started", tag, blends)) end
    inGame = playing
    if F.cb2() == S.CB2_BagMenuRun then
      -- a second blend: the same Berry row again
      F.idle(40); F.press("A", 2); F.idle(30); F.press("A", 2)
    elseif playing then
      if i % 6 == 0 then F.press("A", 2) else F.idle(1) end
    else
      if i % 25 == 0 then F.press("A", 2) else F.idle(1) end
      if cb("CB2_CheckPlayAgainLocal") and shots < 6 and i % 50 == 0 then shots = shots + 1; F.shot(tag .. "_again") end
    end
    if i % 600 == 0 and F.reportCrash(tag) then break end
  end
  return blends
end

F.run(function()
  if not F.boot(100) then F.check("boot", false); F.finish(); return end
  giveMon(SPECIES_ZIGZAGOON, 20, { MOVE_TACKLE })
  addItem(ITEM_POKEBLOCK_CASE, 1)
  addItem(ITEM_CHERI_BERRY, 5)
  addItem(ITEM_PECHA_BERRY, 5)
  F.check("setup: a Pokemon, the Pokeblock Case and ten Berries",
    F.itemCount(ITEM_POKEBLOCK_CASE) == 1 and qty(ITEM_CHERI_BERRY) == 5 and qty(ITEM_PECHA_BERRY) == 5,
    string.format("cheri=%d pecha=%d", qty(ITEM_CHERI_BERRY), qty(ITEM_PECHA_BERRY)))
  F.check("warped into the Contest Lobby", F.warpTo(0, 1, 3, 0, 0, 4, 0, 0, 0, CONTEST_LOBBY[1], CONTEST_LOBBY[2], "lobby"), where())
  awaitControl(300)
  F.check("walked below the two-person blender", F.route({ { 14, 10 }, { 27, 10 } }, "to_blender"), where())

  -- 40 Pokeblocks: refused before the blender starts.
  fillCase(40)
  local b0 = berries()
  local r = talk("full")
  F.check("full case: the blender never starts and the talk ends on the field", r == "field", r)
  F.check("full case: no Berry taken and the case unchanged", berries() == b0 and blockCount() == 40,
    string.format("berries %d -> %d blocks %d", b0, berries(), blockCount()))

  -- 39 Pokeblocks: one blend fills the case; blending again is refused.
  fillCase(39)
  b0 = berries()
  r = talk("one_left")
  F.check("one slot left: the blender starts and asks for a Berry", r == "bag", r)
  if r == "bag" then
    local n = blendFromBag("one_left", 0)
    F.check("one slot left: exactly one blend ran", n == 1, "blends " .. n)
    F.check("one slot left: one Berry taken and the case full", berries() == b0 - 1 and blockCount() == 40,
      string.format("berries %d -> %d blocks %d", b0, berries(), blockCount()))
    F.check("one slot left: the new block is in the last slot", F.r8(pbAddr(39)) ~= 0,
      string.format("color %d", F.r8(pbAddr(39))))
    F.check("one slot left: control returns on the field", awaitControl(900), where())
  end

  -- 38 Pokeblocks: two blends, then the case is full.
  fillCase(38)
  b0 = berries()
  r = talk("two_left")
  F.check("two slots left: the blender starts", r == "bag", r)
  if r == "bag" then
    local n = blendFromBag("two_left", 1)
    F.check("two slots left: two blends ran", n == 2, "blends " .. n)
    F.check("two slots left: two Berries taken and the case full", berries() == b0 - 2 and blockCount() == 40,
      string.format("berries %d -> %d blocks %d", b0, berries(), blockCount()))
    F.check("two slots left: control returns on the field", awaitControl(900), where())
  end
  F.finish()
end)
