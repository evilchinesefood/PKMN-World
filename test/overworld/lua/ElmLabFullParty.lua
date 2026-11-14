-- Elm's starter with Pokemon already in the party. The first Johto crossing boxes the team, but the
-- Hub Pass and the same-region Johto gate keep whatever the player withdrew at the hub PC, so the
-- player can reach Elm's balls with a full party. The starter must then go to the PC exactly once
-- and count as the Johto starter. PW_ELM_PARTY=5 runs a partial party instead: the starter lands in
-- the last slot and the nickname prompt (one letter typed, "A") must rename it, not the party's lead.
-- Setup gives the team through the debug menu and stands in for the hub PC withdrawal in memory;
-- the crossings, the Hub Pass, Elm's introduction and the ball picks use real input.
local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "ElmLabFullParty")

local HUB = { 100, 0 }
local BEDROOM = { 76, 4 }
local LAB = { 76, 0 }
local SLOTS = 14 * 30
local FLAG_JOHTO_STARTER_CHOSEN = 0x6038
local VAR_LAB = 0xA081
local TEAM = tonumber(os.getenv("PW_ELM_PARTY") or "6")
local hubPass

local function where() local x, y = F.pos(); return string.format("%d/%d (%d,%d)", F.grp(), F.mapn(), x, y) end
local function mapIs(m) return F.grp() == m[1] and F.mapn() == m[2] end
local function count() return F.r8(S.gPartiesCount) end
local function party(slot) return S.gParties + (slot or 0) * S.Pokemon.size end
local function box(slot) return F.r32(S.gPokemonStoragePtr) + 4 + slot * S.BoxPokemon.size end
local function present(address) return (F.r8(address + 19) & 2) ~= 0 end
local function bytes(base, size)
  local result = {}
  for i = 0, size - 1 do result[#result + 1] = string.char(F.r8(base + i)) end
  return table.concat(result)
end
local function putBytes(base, value) for i = 1, #value do F.w8(base + i - 1, value:byte(i)) end end
local function zero(base, size) for i = 0, size - 1 do F.w8(base + i, 0) end end
local function johtoFlag(id)
  local offset = id - 0x6000
  return (F.r8(F.sb3() + S.SaveBlock3.johtoFlags + offset // 8) & (1 << (offset % 8))) ~= 0
end
local function getVar(id) return F.r16(F.sb3() + S.SaveBlock3.regionVars + (id - 0xA000) * 2) end

local function order(p)
  local o = {}
  for i = 0, 3 do o[i] = F.r8(S.sSubstructOffsets + i * 24 + p % 24) * 3 end
  return o
end
-- Re-key a copied Pokemon to a new personality so every member is a distinct individual.
local function rekey(address, personality)
  local key = F.r32(address) ~ F.r32(address + 4)
  local w = {}
  for i = 0, 11 do w[i] = F.r32(address + 32 + i * 4) ~ key end
  local o = order(F.r32(address))
  local sub = {}
  for i = 0, 3 do sub[i] = { w[o[i]], w[o[i] + 1], w[o[i] + 2] } end
  F.w32(address, personality)
  key = personality ~ F.r32(address + 4)
  o = order(personality)
  for i = 0, 3 do for k = 0, 2 do F.w32(address + 32 + (o[i] + k) * 4, sub[i][k + 1] ~ key) end end
end
local function pids()
  local set, n = {}, 0
  for i = 0, 5 do if present(party(i)) then set[F.r32(party(i))] = true; n = n + 1 end end
  for i = 0, SLOTS - 1 do if present(box(i)) then set[F.r32(box(i))] = true; n = n + 1 end end
  return set, n
end
local function newSince(before)
  local now, n = pids()
  local fresh = 0
  for p in pairs(now) do if not before[p] then fresh = fresh + 1 end end
  return fresh, n
end

local function scriptMenuActive()
  for i = 0, S.Task.count - 1 do
    local a = S.gTasks + i * S.Task.stride
    local fn = F.r32(a + S.Task.func) & 0xFFFFFFFE
    if F.r8(a + S.Task.isActive) ~= 0 and (fn == S.Task_HandleYesNoInput or fn == S.Task_HandleMultichoiceInput
      or fn == S.Task_CallYesOrNoCallback) then return true end
  end
  return false
end
local function menu(want, tag, maxA)
  for _ = 1, (maxA or 65) do
    if F.reportCrash(tag) then return false end
    if scriptMenuActive() then
      F.idle(12)
      for _ = 1, 10 do
        local c = F.mcur()
        if c == want then
          F.shot(tag)
          for _ = 1, 4 do
            F.press("A", 2)
            for _ = 1, 30 do
              if not scriptMenuActive() then F.idle(30); return true end
              F.idle(1)
            end
          end
          return false
        end
        F.press(c > want and "Up" or "Down", 2); F.idle(12)
      end
      return false
    end
    F.press("A", 2); F.idle(25)
  end
  F.shot(tag .. "_nomenu")
  return false
end
local function awaitMap(m, tag)
  for _ = 1, 260 do
    if mapIs(m) then F.idle(100); return true end
    if F.reportCrash(tag) then return false end
    F.press("A", 2); F.idle(14)
  end
  F.shot(tag .. "_failed")
  return false
end
local function drain()
  for _ = 1, 30 do
    F.press("B", 2); F.idle(16)
    if F.ensureFree() then return true end
  end
  return false
end
-- Advance text with B until the next Yes/No or field control.
local function settle(tag)
  for _ = 1, 120 do
    if F.reportCrash(tag) then return false end
    if scriptMenuActive() then return true end
    F.press("B", 2); F.idle(20)
    if F.ow() and F.ensureFree() then return true end
  end
  return false
end
local function crossJohto(tag)
  if not F.route({ { 16, 4 }, { 16, 3 } }, tag .. "_walk") then return false end
  F.face("Up"); F.press("A", 3); F.idle(60)
  if not menu(0, tag .. "_yes") then return false end
  return awaitMap(BEDROOM, tag .. "_bedroom")
end
local function pickBall(x, tag)
  local px = F.pos()
  if not F.route({ { px, 5 }, { x, 5 } }, tag .. "_walk") then return false end
  F.face("Up"); F.press("A", 2); F.idle(60)
  return menu(0, tag .. "_yes", 40)
end
local function nicknameStarter(slot)
  for _ = 1, 400 do
    if not F.ow() then break end
    F.idle(2)
  end
  F.idle(120)
  F.press("A", 2); F.idle(40)
  F.press("Start", 2); F.idle(40)
  F.press("A", 2); F.idle(40)
  for _ = 1, 400 do
    if F.ow() then break end
    F.idle(2)
  end
  F.idle(60)
end

F.run(function()
  if not F.boot(HUB[1]) then F.check("fresh boot", false); F.finish(); return end
  local seen = {}
  for _, id in ipairs(select(2, F.keyItemSlot(0xFFFF))) do seen[id] = true end

  F.dbg(); F.idle(40); F.sel(2); F.idle(40)
  for _ = 1, 9 do F.press("Down", 3); F.idle(16) end
  F.press("A", 3); F.idle(180)
  drain()
  local template = bytes(party(), S.Pokemon.size)
  for i = 0, 5 do zero(party(i), S.Pokemon.size) end
  for i = 0, TEAM - 1 do putBytes(party(i), template); rekey(party(i), 0xE100 + i) end
  F.w8(S.gPartiesCount, TEAM)
  local team = {}
  for i = 0, TEAM - 1 do team[i] = bytes(party(i), S.Pokemon.size) end
  F.check("a team of " .. TEAM .. " in the hub", count() == TEAM, "count=" .. count())

  F.check("first Johto crossing lands in the New Bark bedroom", crossJohto("first"), where())
  drain()
  for _, id in ipairs(select(2, F.keyItemSlot(0xFFFF))) do if not seen[id] then hubPass = id end end
  F.check("first crossing gives the Hub Pass", hubPass ~= nil)
  F.check("the first crossing boxes the team", count() == 0, "count=" .. count())

  F.w16(F.sb1() + S.SaveBlock1.registeredItem, hubPass or 0)
  F.press("Select", 2); F.idle(90)
  F.check("Hub Pass from the bedroom", menu(0, "hub_pass") and awaitMap(HUB, "hub"), where())
  drain()

  local moved = 0
  for i = 0, TEAM - 1 do
    local pid = string.unpack("<I4", team[i])
    for s = 0, SLOTS - 1 do
      if present(box(s)) and F.r32(box(s)) == pid then zero(box(s), S.BoxPokemon.size); break end
    end
    putBytes(party(i), team[i])
    moved = moved + 1
  end
  F.w8(S.gPartiesCount, TEAM)
  F.check("the hub PC returns the team to the party", count() == TEAM and moved == TEAM, "count=" .. count())

  F.check("same-region Johto gate lands in the bedroom", crossJohto("again"), where())
  drain()
  F.check("the same-region gate keeps the team", count() == TEAM, "count=" .. count())

  F.check("reach Elm's lab", F.warpTo(0, 7, 6, 0, 0, 0, 0, 0, 0, LAB[1], LAB[2], "lab"), where())
  drain()
  F.check("walk to Elm's introduction trigger", F.route({ { 6, 8 } }, "lab_walk"))
  F.press("Up", 16); F.idle(30)
  for _ = 1, 400 do
    if getVar(VAR_LAB) == 1 and F.ow() and not scriptMenuActive() then break end
    if F.reportCrash("elm_intro") then break end
    if scriptMenuActive() then menu(0, "elm_intro_yes", 3) else F.press("A", 2); F.idle(20) end
  end
  drain()
  F.check("Elm offers the starters", getVar(VAR_LAB) == 1 and mapIs(LAB), where() .. " lab=" .. getVar(VAR_LAB))

  local before = pids()
  local lead = bytes(party(0), S.Pokemon.size)
  F.check("pick Chikorita and confirm", pickBall(8, "chikorita"))
  settle("after_chikorita")
  local named = false
  if scriptMenuActive() then
    if TEAM < 6 then
      named = menu(0, "nickname_yes", 5)
      if named then nicknameStarter(TEAM) end
    else
      menu(1, "nickname_no", 5)
    end
  end
  for _ = 1, 300 do
    if F.ow() and not scriptMenuActive() and F.ensureFree() then break end
    F.press("B", 2); F.idle(14)
  end
  F.shot("after_first_pick")
  local fresh, total = newSince(before)
  F.check("the first pick gives exactly one starter", fresh == 1, "new=" .. fresh .. " total=" .. total)
  F.check("the first pick counts as the Johto starter", johtoFlag(FLAG_JOHTO_STARTER_CHOSEN))
  if TEAM < 6 then
    local hex = {}
    for i = 0, 11 do hex[#hex + 1] = string.format("%02X", F.r8(party(TEAM) + 8 + i)) end
    F.L("  starter nickname bytes " .. table.concat(hex, " "))
    F.check("the starter joins the party", count() == TEAM + 1, "count=" .. count())
    F.check("the nickname prompt was answered", named)
    F.check("the nickname goes to the starter, not the lead", bytes(party(0), S.Pokemon.size) == lead
      and F.r8(party(TEAM) + 8) == 0xBB and F.r8(party(TEAM) + 9) == 0xFF,
      "lead changed=" .. tostring(bytes(party(0), S.Pokemon.size) ~= lead))
  else
    local same = true
    for i = 0, 5 do if bytes(party(i), S.Pokemon.size) ~= team[i] then same = false end end
    F.check("the full party is untouched", same and count() == 6, "count=" .. count())
  end

  pickBall(9, "cyndaquil")
  for _ = 1, 300 do
    if F.ow() and not scriptMenuActive() and F.ensureFree() then break end
    F.press("B", 2); F.idle(14)
  end
  fresh, total = newSince(before)
  F.shot("after_second_pick")
  F.check("no second starter can be taken", fresh == 1, "new=" .. fresh .. " total=" .. total)
  F.check("player can still walk", F.ensureFree())
  F.finish()
end)
