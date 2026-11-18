-- Fishing with each rod in all three regions, through the SELECT key-item path.
--
-- Each cast warps to a shore cell (debug warp to a coordinate), faces the water, registers one
-- rod and presses SELECT. The suite reads Task_Fishing's step: on "Oh! A bite!" it presses A
-- once, and a battle must start whose foe is in the map's fishing table; it then flees with a
-- level-100 lead. A map with fishable water and no fishing table must say "Not even a nibble".
-- Every cast must end with the rod put away (player graphics restored), the field unlocked, the
-- follower beside the player and a step that lands. Mash casts press seeded random buttons
-- (A, B, Start, Select, L, R, D-pad) from SELECT to the end of the cast instead.
--
-- PW_FISH_ONLY=<text> runs only the cases whose tag contains it. PW_FISH_SEED sets the mash seed.
--
-- Run via test/overworld/mgba-run.sh test/overworld/lua/FishingAcrossRegions.lua <rom>

local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "FishingAcrossRegions")

local HUB_GROUP = 100
local CONTEXT_RUNNING = 0
local PARTY_SIZE = 6
local SPECIES_LAPRAS = 131
local MOVE_SURF, MOVE_ICE_BEAM = 57, 58
local ITEM_OLD_ROD, ITEM_GOOD_ROD, ITEM_SUPER_ROD = 709, 710, 711
local ITEM_SURF_TOOL = 876
local AVATAR_SURFING = 1 << 3
local OBJ_EVENT_ID_FOLLOWER = 0xFE
local VAR_REPEL_STEP_COUNT = 0x4021
local FISHING_WAIT_FOR_A, FISHING_A_PRESS_NO_MINIGAME, FISHING_START_ENCOUNTER = 8, 9, 12
local ONLY = os.getenv("PW_FISH_ONLY")
local SEED = tonumber(os.getenv("PW_FISH_SEED") or "") or 9001
local TRACE = os.getenv("PW_FISH_TRACE")

local RODS = { old = ITEM_OLD_ROD, good = ITEM_GOOD_ROD, super = ITEM_SUPER_ROD }
local OPP = { Up = "Down", Down = "Up", Left = "Right", Right = "Left" }

-- Species ids (include/constants/species.h) each map's fishing_mons can give, any rod.
local FISH = {
  newbark = { [170] = "CHINCHOU", [171] = "LANTURN", [129] = "MAGIKARP", [90] = "SHELLDER", [72] = "TENTACOOL",
              [73] = "TENTACRUEL" },
  vermilion = { [130] = "GYARADOS", [116] = "HORSEA", [98] = "KRABBY", [129] = "MAGIKARP", [79] = "SLOWPOKE",
                [120] = "STARYU" },
  route104 = { [129] = "MAGIKARP" },
}

-- Shore cells: map, standing cell, the facing that looks at the water, a walkable step away from
-- it, and the first word of the region's "can't use that here" line (src/strings.c), in the game's
-- charset: OAK: (FireRed), ELM's (pokemonHnS), DAD's (Emerald).
local OAK, ELM, DAD = { 0xC9, 0xBB, 0xC5, 0xF0 }, { 0xBF, 0xC6, 0xC7, 0xB4 }, { 0xBE, 0xBB, 0xBE, 0xB4 }
local SPOTS = {
  { tag = "johto New Bark", g = 75, m = 0, x = 24, y = 12, face = "Right", back = "Left", table = true,
    fish = FISH.newbark, adviser = ELM },
  { tag = "kanto Vermilion", g = 37, m = 5, x = 22, y = 31, face = "Left", back = "Right", table = true,
    fish = FISH.vermilion, adviser = OAK },
  { tag = "hoenn Route 104", g = 0, m = 19, x = 24, y = 22, face = "Up", back = "Down", table = true,
    fish = FISH.route104, adviser = DAD },
  { tag = "kanto Route 18 (no table)", g = 37, m = 36, x = 12, y = 10, face = "Down", back = "Up", table = false },
  { tag = "johto Safari Zone (no table)", g = 96, m = 10, x = 18, y = 16, face = "Right", back = "Up", table = false },
  { tag = "hoenn Frontier West (no table)", g = 26, m = 4, x = 39, y = 58, face = "Down", back = "Up", table = false },
}

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
  b[#b + 1] = 0; b[#b + 1] = PARTY_SIZE
  le16(b, species); le16(b, level)
  le32(b, (1 << 17) | (1 << 18) | (1 << 19) | (1 << 20))
  for k = 1, 4 do le16(b, moves[k] or 0) end
  b[#b + 1] = 0x02
  runScript(b); F.idle(20)
  return F.r8(S.gPartiesCount)
end
local function addItem(id, qty)
  runScript({ 0x44, id & 0xFF, id >> 8, qty & 0xFF, qty >> 8, 0x02 }); F.idle(10)
end

local function d(n) return (n // 100) % 10, (n // 10) % 10, n % 10 end
local function surfing() return (F.r8(S.gPlayerAvatar) & AVATAR_SURFING) ~= 0 end
local function hasControl()
  return F.ow() and F.r8(S.sLockFieldControls) == 0 and F.r8(S.sGlobalScriptContextStatus) ~= CONTEXT_RUNNING
end
local function playerObj() return S.gObjectEvents + F.r8(S.gPlayerAvatar + 5) * S.ObjectEvent.stride end
local function playerGfx() return F.r16(playerObj() + S.ObjectEvent.graphicsId) end
local function objByLocal(id)
  for i = 0, 15 do
    local o = S.gObjectEvents + i * S.ObjectEvent.stride
    if (F.r8(o) & 1) ~= 0 and F.r8(o + S.ObjectEvent.localId) == id then return o end
  end
end
local function follower()
  local o = objByLocal(OBJ_EVENT_ID_FOLLOWER)
  if not o then return nil end
  return { hidden = ((F.r8(o + 1) >> 5) & 1) == 1, x = F.rs16(o + 0x10) - 7, y = F.rs16(o + 0x12) - 7 }
end
local function fishTask()
  for i = 0, S.Task.count - 1 do
    local t = S.gTasks + i * S.Task.stride
    if F.r8(t + S.Task.isActive) ~= 0 and (F.r32(t + S.Task.func) & ~1) == (S.Task_Fishing & ~1) then return t end
  end
end
local function inBattle() return (F.cb2() & ~1) == (S.BattleMainCB2 & ~1) end

-- Debug warp with sWarpDestination held at WARP_ID_NONE, so SetPlayerCoordsFromWarp takes x,y.
local function warpToCoords(g, m, x, y, tag)
  for _ = 1, 4 do
    F.dbg(); F.sel(0); F.sel(1); F.idle(20)
    F.spin(d(g)); F.spin(d(m))
    F.press("A", 2)
    for _ = 1, 400 do
      F.w8(S.sWarpDestination + 2, 0xFF)
      F.w16(S.sWarpDestination + 4, x)
      F.w16(S.sWarpDestination + 6, y)
      F.idle(1)
      local px, py = F.pos()
      if F.ow() and F.grp() == g and F.mapn() == m and px == x and py == y then
        F.idle(120)
        -- the first arrival in a region narrates it; page that away like a player would
        for i = 1, 900 do
          if hasControl() then break end
          if i % 20 == 0 then F.press("B", 2) else F.idle(1) end
        end
        F.L(string.format("  WARP %s ok (%d,%d) surfing=%s", tag, px, py, tostring(surfing())))
        return true
      end
    end
    F.bOut(5)
  end
  F.shot(tag .. "_warpfail")
  return false
end

local rng = SEED
local function rand(n) rng = (rng * 1103515245 + 12345) & 0x7FFFFFFF; return rng % n end
local MASH = { "A", "B", "Start", "Select", "L", "R", "Up", "Down", "Left", "Right" }

local function flee(tag)
  local foe = 0
  for _ = 1, 900 do
    foe = F.r16(S.gBattleMons + S.BattlePokemon.size)
    if F.r8(S.gBattlersCount) > 0 and foe ~= 0 then break end
    F.idle(1)
  end
  for i = 1, 6000 do
    if F.ow() and hasControl() then break end
    if inBattle() then F.w8(S.gActionSelectionCursor, 3) end
    if i % 120 == 0 and F.reportCrash(tag .. "_battle") then break end
    if i % 10 == 0 then F.press("A", 2) else F.idle(1) end
  end
  return foe
end

-- One cast. Returns "bite" (a battle ran and ended), "nibble" (no bite), or a failure string.
-- I_FISHING_MINIGAME is GEN_2: after "Oh! A bite!" the rod waits for A (step 9) with no timeout.
local function cast(tag, rod, mash)
  F.w16(F.sb1() + S.SaveBlock1.registeredItem, rod)
  for k = 0, 6 do F.w16(F.sb1() + S.SaveBlock1.registeredItem + 2 + 2 * k, 0) end
  local gfx = playerGfx()
  F.press("Select", 2)
  local seenTask, bitten, gone, outcome, foe = false, false, 0, nil, nil
  local hooked = 0
  local lastStep
  for frame = 1, 3000 do
    local t = fishTask()
    if TRACE then
      local st = t and F.rs16(t + S.Task.data) or -1
      if st ~= lastStep then
        F.L(string.format("    f%d step %d lock=%d ctx=%d cb2=%08X", frame, st, F.r8(S.sLockFieldControls),
          F.r8(S.sGlobalScriptContextStatus), F.cb2()))
        lastStep = st
      end
    end
    if t then
      seenTask = true
      local st = F.rs16(t + S.Task.data)
      if st == FISHING_WAIT_FOR_A or st == FISHING_A_PRESS_NO_MINIGAME then
        bitten = true
        if not mash then F.press("A", 2) end
      elseif st == FISHING_START_ENCOUNTER and not mash then
        hooked = hooked + 1
        if hooked == 25 then F.shot(tag:gsub("%W", "_") .. "_hooked") end
        if hooked % 30 == 0 then F.press("A", 2) end
      end
    elseif seenTask then
      gone = gone + 1
    end
    if inBattle() then outcome = "bite"; break end
    if gone > 400 and hasControl() then break end
    if F.reportCrash(tag .. "_cast") then return "crash" end
    if mash and seenTask and gone == 0 then
      local b = MASH[rand(#MASH) + 1]
      if b == "Start" and rand(4) ~= 0 then b = "A" end
      F.press(b, 1 + rand(3)); F.idle(rand(6))
    elseif gone > 0 and F.ow() then
      F.press("B", 2); F.idle(6); gone = gone + 8
    else
      F.idle(1)
    end
  end
  if not seenTask then
    local x, y = F.pos()
    F.shot(tag:gsub("%W", "_") .. "_norod")
    F.L(string.format("    no rod task: (%d,%d) facing=%d lock=%d ctx=%d cb2=%08X reg=%d", x, y,
      F.r16(playerObj() + S.ObjectEvent.facing) & 0xF, F.r8(S.sLockFieldControls), F.r8(S.sGlobalScriptContextStatus),
      F.cb2(), F.r16(F.sb1() + S.SaveBlock1.registeredItem)))
    return "no rod task"
  end
  if outcome == "bite" then
    foe = flee(tag)
  else
    outcome = bitten and "unreeled bite" or "nibble"
  end
  for _ = 1, 900 do
    if hasControl() then break end
    F.press("B", 2); F.idle(8)
  end
  if F.reportCrash(tag .. "_after") then return "crash" end
  if not hasControl() then F.shot(tag:gsub("%W", "_") .. "_stuck"); return "stuck" end
  return outcome, foe, gfx
end

local function case(tag, body)
  if ONLY and not tag:find(ONLY, 1, true) then return end
  F.L("== " .. tag .. " ==")
  local ok, err = pcall(body)
  if not ok then F.check(tag .. ": ran without a Lua error", false, tostring(err)) end
end

-- After a cast: the rod is away, the field is free, a step off the shore lands and the follower
-- walks beside the player.
local function settled(tag, spot, gfx)
  F.check(tag .. ": player graphics restored", playerGfx() == gfx,
    string.format("gfx %04X want %04X", playerGfx(), gfx))
  local moved = F.step(spot.back)
  local x, y = F.pos()
  F.check(tag .. ": a step " .. spot.back .. " lands", moved, string.format("(%d,%d)", x, y))
  if not moved then return end
  F.step(OPP[spot.back]); F.face(spot.face)
  local fol = follower()
  x, y = F.pos()
  if fol and not surfing() then
    local dist = math.abs(fol.x - x) + math.abs(fol.y - y)
    F.check(tag .. ": follower beside the player", not fol.hidden and dist == 1,
      string.format("follower (%d,%d) hidden=%s player (%d,%d)", fol.x, fol.y, tostring(fol.hidden), x, y))
  end
end

F.run(function()
  if not F.boot(HUB_GROUP) then F.check("boot to the hub", false); F.finish(); return end
  F.w8(F.sb2() + 0x14, (F.r8(F.sb2() + 0x14) & ~7) | 3)
  F.check("a Lapras leads", createMon(SPECIES_LAPRAS, 100, { MOVE_SURF, MOVE_ICE_BEAM }) == 1)
  addItem(ITEM_OLD_ROD, 1); addItem(ITEM_GOOD_ROD, 1); addItem(ITEM_SUPER_ROD, 1); addItem(ITEM_SURF_TOOL, 1)
  F.check("three rods in the bag", F.itemCount(ITEM_OLD_ROD) == 1 and F.itemCount(ITEM_GOOD_ROD) == 1
    and F.itemCount(ITEM_SUPER_ROD) == 1)
  F.w16(F.sb1() + S.SaveBlock1.vars + (VAR_REPEL_STEP_COUNT - 0x4000) * 2, 0)

  for _, spot in ipairs(SPOTS) do
    case(spot.tag, function()
      if not warpToCoords(spot.g, spot.m, spot.x, spot.y, spot.tag) then F.check(spot.tag .. ": warp", false); return end
      F.face(spot.face)
      F.shot(spot.tag:gsub("%W", "_") .. "_shore")
      local bites = 0
      for _, rodName in ipairs({ "old", "good", "super" }) do
        local nibbles = 0
        local casts = spot.table and (rodName == "super" and 8 or 3) or 2
        for n = 1, casts do
          local tag = string.format("%s %s rod cast %d", spot.tag, rodName, n)
          local outcome, foe, gfx = cast(tag, RODS[rodName], false)
          F.L(string.format("  %s -> %s foe=%s", tag, tostring(outcome), tostring(foe)))
          if outcome ~= "bite" and outcome ~= "nibble" then
            F.check(tag .. ": cast ends in a battle or not even a nibble", false, outcome); return
          end
          if outcome == "bite" then
            bites = bites + 1
            F.check(tag .. ": foe is in the map's fishing table", spot.fish and spot.fish[foe] ~= nil, tostring(foe))
          else
            nibbles = nibbles + 1
          end
          settled(tag, spot, gfx)
          if outcome == "bite" then break end
        end
        if not spot.table then
          F.check(string.format("%s %s rod: every cast says not even a nibble", spot.tag, rodName),
            nibbles == casts, string.format("nibbles=%d of %d", nibbles, casts))
        end
      end
      if spot.table then F.check(spot.tag .. ": a fishing battle starts", bites > 0) end
    end)
  end

  case("mash casts", function()
    local spot = SPOTS[1]
    if not warpToCoords(spot.g, spot.m, spot.x, spot.y, "mash") then F.check("mash: warp", false); return end
    F.face(spot.face)
    for n = 1, 8 do
      local tag = string.format("mash cast %d (seed %d)", n, SEED)
      local outcome, foe, gfx = cast(tag, RODS[({ "old", "good", "super" })[n % 3 + 1]], true)
      F.L(string.format("  %s -> %s foe=%s", tag, tostring(outcome), tostring(foe)))
      F.check(tag .. ": cast ends in a battle or not even a nibble", outcome == "bite" or outcome == "nibble", outcome)
      if outcome ~= "bite" and outcome ~= "nibble" then break end
      if outcome == "bite" then F.check(tag .. ": foe is in the map's fishing table", FISH.newbark[foe] ~= nil, tostring(foe)) end
      F.check(tag .. ": player graphics restored", playerGfx() == gfx, string.format("%04X vs %04X", playerGfx(), gfx))
      F.face(spot.face)
    end
  end)

  case("surfing cast", function()
    if not warpToCoords(75, 0, 26, 12, "surf") then F.check("surf: warp", false); return end
    F.check("surf: arrives surfing", surfing())
    local spot = { face = "Right" }
    F.face("Right")
    for n = 1, 4 do
      local tag = string.format("surfing cast %d", n)
      local outcome, foe, gfx = cast(tag, ITEM_SUPER_ROD, false)
      F.L(string.format("  %s -> %s foe=%s", tag, tostring(outcome), tostring(foe)))
      F.check(tag .. ": cast ends in a battle or not even a nibble", outcome == "bite" or outcome == "nibble", outcome)
      if outcome ~= "bite" and outcome ~= "nibble" then break end
      F.check(tag .. ": still surfing", surfing())
      F.check(tag .. ": player graphics restored", playerGfx() == gfx, string.format("%04X vs %04X", playerGfx(), gfx))
      F.check(tag .. ": can surf on", F.step("Down") and F.step("Up"))
      F.face("Right")
      if outcome == "bite" then break end
    end
  end)

  -- A rod that cannot fish (facing land) shows the region's own adviser, through SELECT.
  for _, spot in ipairs(SPOTS) do
    if spot.adviser then
      case(spot.tag .. " rod facing land", function()
        if not warpToCoords(spot.g, spot.m, spot.x, spot.y, spot.tag .. "_land") then F.check(spot.tag .. ": warp", false); return end
        F.face(spot.back)
        for k = 0, 7 do F.w8(S.gStringVar4 + k, 0xFF) end
        F.w16(F.sb1() + S.SaveBlock1.registeredItem, ITEM_OLD_ROD)
        F.press("Select", 2)
        local shown = false
        for _ = 1, 300 do
          if F.r8(S.gStringVar4) ~= 0xFF then shown = true; break end
          F.idle(1)
        end
        F.idle(90)
        F.shot(spot.tag:gsub("%W", "_") .. "_cant_fish")
        local got = {}
        for k = 0, 3 do got[#got + 1] = string.format("%02X", F.r8(S.gStringVar4 + k)) end
        local want = {}
        for _, c in ipairs(spot.adviser) do want[#want + 1] = string.format("%02X", c) end
        F.check(spot.tag .. ": no cast", fishTask() == nil)
        F.check(spot.tag .. ": the region's adviser says it", shown and table.concat(got, " ") == table.concat(want, " "),
          "got " .. table.concat(got, " ") .. " want " .. table.concat(want, " "))
        for _ = 1, 20 do
          if hasControl() then break end
          F.press("A", 2); F.idle(20)
        end
        F.check(spot.tag .. ": control returns after the message", hasControl())
        F.check(spot.tag .. ": a step lands", F.step(spot.back))
      end)
    end
  end

  F.finish()
end)
