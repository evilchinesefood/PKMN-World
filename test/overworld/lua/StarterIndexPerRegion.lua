-- Each region's rival reads the starter index the player chose in THAT region. Oak's lab, Elm's lab
-- and Birch's bag all wrote one shared VAR_STARTER_MON, so a starter chosen in a second region
-- changed the first region's rival team. Here the player takes Charmander in Oak's lab (Blue takes
-- Squirtle in front of them), leaves by Hub Pass before Blue's battle, takes Cyndaquil in Elm's lab,
-- and comes back: Blue must battle with the Squirtle he took. Setup is debug warps to Pallet Town
-- and Elm's lab only; the gate crossings, Oak's trigger, Elm's intro, both ball picks, the Hub Pass
-- and Blue's trigger use real input.
local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "StarterIndexPerRegion")

local HUB = { 100, 0 }
local VAR_OAK_LAB = 0xA02E
local VAR_ELM_LAB = 0xA081
local VAR_SHARED_STARTER = 0x4023
local FLAG_HIDE_SQUIRTLE_BALL = 0xA40 + 0x29
local FLAG_JOHTO_STARTER_CHOSEN = 0x6000 + 0x38
local SPECIES = { [1] = "Bulbasaur", [4] = "Charmander", [7] = "Squirtle", [155] = "Cyndaquil" }
local hubPass

local function where() local x, y = F.pos(); return string.format("%d/%d (%d,%d)", F.grp(), F.mapn(), x, y) end
local function mapIs(g, m) return F.grp() == g and F.mapn() == m end
local function varAddr(id)
  if id >= 0xA000 then return F.sb3() + S.SaveBlock3.regionVars + (id - 0xA000) * 2 end
  return F.sb1() + S.SaveBlock1.vars + (id - 0x4000) * 2
end
local function getVar(id) return F.r16(varAddr(id)) end
local function flagSet(id)
  local base, offset = F.sb1() + S.SaveBlock1.flags, id
  if id >= 0x6000 and id < 0x6400 then base, offset = F.sb3() + S.SaveBlock3.johtoFlags, id - 0x6000 end
  return (F.r8(base + offset // 8) & (1 << (offset % 8))) ~= 0
end
-- Species from the encrypted growth substruct of a struct Pokemon.
local function species(address)
  local pid, otid = F.r32(address), F.r32(address + 4)
  local growth = F.r8(S.sSubstructOffsets + pid % 24) * 3
  return (F.r32(address + 32 + growth * 4) ~ pid ~ otid) & 0x7FF
end
local function name(sp) return (SPECIES[sp] or "?") .. "(" .. sp .. ")" end
local function partyLead() return species(S.gParties) end
local function rivalLead() return species(S.gParties + 6 * S.Pokemon.size) end

local function scriptMenuActive()
  for i = 0, S.Task.count - 1 do
    local a = S.gTasks + i * S.Task.stride
    local fn = F.r32(a + S.Task.func) & 0xFFFFFFFE
    if F.r8(a + S.Task.isActive) ~= 0 and (fn == S.Task_HandleYesNoInput or fn == S.Task_HandleMultichoiceInput or fn == S.Task_CallYesOrNoCallback) then return true end
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
local function awaitMap(g, m, tag)
  for _ = 1, 260 do
    if mapIs(g, m) then F.idle(100); return true end
    if F.reportCrash(tag) then return false end
    F.press("A", 2); F.idle(14)
  end
  F.shot(tag .. "_failed")
  return false
end
local function awaitGroup(g, tag)
  for _ = 1, 260 do
    if F.grp() == g and F.ow() then F.idle(100); return true end
    if F.reportCrash(tag) then return false end
    F.press("A", 2); F.idle(14)
  end
  F.shot(tag .. "_failed")
  return false
end
local function drain()
  for _ = 1, 40 do
    F.press("B", 2); F.idle(16)
    if F.ensureFree() then return true end
  end
  return false
end
local function debugWarp(g, m, tag)
  local function digits(n) return n // 100, (n // 10) % 10, n % 10 end
  local gh, gt, go = digits(g); local mh, mt, mo = digits(m)
  return F.warpTo(gh, gt, go, mh, mt, mo, 0, 0, 0, g, m, tag)
end
local function useHubPass(tag)
  F.w16(F.sb1() + S.SaveBlock1.registeredItem, hubPass)
  F.press("Select", 2); F.idle(90)
  return menu(0, tag .. "_hub_pass") and awaitMap(HUB[1], HUB[2], tag .. "_hub")
end
local function crossGate(path, tag)
  if not F.route(path, tag .. "_walk") then return false end
  F.face("Up"); F.press("A", 3); F.idle(60)
  return menu(0, tag .. "_yes")
end
-- Talk to a starter ball from the tile below it, accept it and decline a nickname.
local function takeBall(x, tag, until_)
  local px = F.pos()
  if not F.route({ { px, 5 }, { x, 5 } }, tag .. "_walk") then return false end
  F.face("Up"); F.press("A", 2); F.idle(60)
  if not menu(0, tag .. "_yes", 40) then return false end
  for _ = 1, 400 do
    if until_() and F.ow() and not scriptMenuActive() then break end
    if scriptMenuActive() then menu(1, tag .. "_nickname_no", 5) end
    if F.reportCrash(tag) then return false end
    F.press("B", 2); F.idle(14)
  end
  drain()
  return until_()
end

F.run(function()
  if not F.boot(HUB[1]) then F.check("fresh boot", false); F.finish(); return end
  local seen = {}
  for _, id in ipairs(select(2, F.keyItemSlot(0xFFFF))) do seen[id] = true end

  F.check("first crossing: Kanto gate accepted", crossGate({ { 16, 4 }, { 11, 4 }, { 11, 3 } }, "kanto1"))
  F.check("land in the Pallet bedroom", awaitMap(38, 1, "bedroom"), where())
  drain()
  for _, id in ipairs(select(2, F.keyItemSlot(0xFFFF))) do if not seen[id] then hubPass = id end end
  F.check("the first crossing gives the Hub Pass", hubPass ~= nil, where())
  if not hubPass then F.finish(); return end

  F.check("reach Pallet Town", debugWarp(37, 0, "pallet"))
  drain()
  F.check("walk toward Route 1", F.route({ { 6, 8 }, { 12, 8 }, { 12, 2 } }, "pallet_north"))
  F.press("Up", 16); F.idle(30)
  for _ = 1, 400 do
    if getVar(VAR_OAK_LAB) == 2 and F.ow() and not scriptMenuActive() then break end
    if F.reportCrash("oak_scene") then break end
    F.press("B", 2); F.idle(14)
  end
  drain()
  F.check("Oak's starter scene opens", getVar(VAR_OAK_LAB) == 2 and mapIs(38, 3), where() .. " lab=" .. getVar(VAR_OAK_LAB))

  local took = takeBall(10, "charmander", function() return getVar(VAR_OAK_LAB) == 3 end)
  F.shot("kanto_after_pick")
  F.check("Oak's lab: Charmander taken, Blue's battle still pending", took and partyLead() == 4,
    "lab=" .. getVar(VAR_OAK_LAB) .. " lead=" .. name(partyLead()))
  F.check("Blue takes the Squirtle ball in front of the player", flagSet(FLAG_HIDE_SQUIRTLE_BALL))
  F.check("Kanto pick recorded", true, "shared VAR_STARTER_MON=" .. getVar(VAR_SHARED_STARTER))

  F.check("Hub Pass out of Oak's lab", useHubPass("kanto_out"), where())
  drain()
  F.check("first Johto crossing accepted", crossGate({ { 16, 4 }, { 16, 3 } }, "johto1"))
  F.check("land in New Bark Town", awaitGroup(76, "johto_land"), where())
  drain()
  F.check("reach Elm's lab", debugWarp(76, 0, "elm_lab"))
  drain()
  F.route({ { 6, 9 }, { 6, 8 } }, "elm_intro_walk")
  F.press("Up", 16)
  for _ = 1, 600 do
    if getVar(VAR_ELM_LAB) == 1 and F.ow() and not scriptMenuActive() and F.ensureFree() then break end
    if F.reportCrash("elm_intro") then break end
    if scriptMenuActive() then menu(0, "elm_intro_yes", 5) end
    F.press("B", 2); F.idle(14)
  end
  F.check("Elm's intro offers the starters", getVar(VAR_ELM_LAB) == 1, where() .. " lab=" .. getVar(VAR_ELM_LAB))
  local chose = takeBall(9, "cyndaquil", function() return flagSet(FLAG_JOHTO_STARTER_CHOSEN) end)
  F.shot("johto_after_pick")
  F.check("Elm's lab: Cyndaquil taken", chose and partyLead() == 155,
    "chosen=" .. tostring(flagSet(FLAG_JOHTO_STARTER_CHOSEN)) .. " lead=" .. name(partyLead()))
  F.check("Johto pick recorded", true, "shared VAR_STARTER_MON=" .. getVar(VAR_SHARED_STARTER))

  F.check("Hub Pass out of Johto", useHubPass("johto_out"), where())
  drain()
  F.check("Kanto gate accepted", crossGate({ { 16, 4 }, { 11, 4 }, { 11, 3 } }, "kanto2"))
  F.check("the gate returns to Oak's lab while Blue's battle is pending", awaitMap(38, 3, "back_in_lab"), where())
  drain()
  F.check("Kanto's team comes back", partyLead() == 4, "lead=" .. name(partyLead()))

  local x = F.pos()
  F.route({ { x, 7 }, { 6, 7 } }, "to_trigger")
  F.press("Down", 16)
  local started = false
  for _ = 1, 900 do
    if F.reportCrash("blue_battle") then break end
    if not F.ow() and F.battlers() > 0 then started = true; break end
    F.press("B", 2); F.idle(10)
  end
  for _ = 1, 40 do F.press("B", 2); F.idle(10) end
  F.shot("blue_battle")
  F.check("Blue's lab battle starts", started, where())
  F.check("Blue battles with the Squirtle he took", rivalLead() == 7, "rival lead=" .. name(rivalLead()))
  F.finish()
end)
