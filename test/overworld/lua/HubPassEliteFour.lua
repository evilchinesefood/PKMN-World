-- Hub Pass inside an Elite Four room, mid run.
-- Each region's E4 rooms reopen their exits on load when the member's beaten flag or League
-- state is already set, and nothing on the way back in clears that progress (Hoenn and Kanto
-- reset only on whiteout or the Hall of Fame; Johto resets in the Indigo Plateau Pokemon Center,
-- which the E4 door outside does not pass through). A Hub Pass out of a cleared room therefore
-- let the player heal and walk straight past every member already beaten. The rooms are
-- allow_escaping false indoor maps, so Fly, Dig, Teleport and the Escape Rope already refuse;
-- the Hub Pass must refuse there too. Control: it still works in the League lobby.
-- Setup writes flags and vars and uses debug warps into the rooms. The Hub Pass uses real input.
local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
package.path = here .. "?.lua;" .. package.path
local S = require("symbols")
local F = require("lib").new(S, "HubPassEliteFour")

local HUB = {100, 0}
local HOENN_ATTENDANT, HOENN_STANDARD = 21, {9, 9}
local FLAG_DEFEATED_ELITE_4_SIDNEY, VAR_ELITE_4_STATE = 0x4FB, 0x409C
local FLAG_DEFEATED_LORELEI, VAR_MAP_SCENE_POKEMON_LEAGUE = 0xA40 + 0x4B8, 0xA000 + 0x41
local VAR_LEAGUE_STATE = 0xA080 + 0x3B
local hubPass

local function where() local x,y=F.pos(); return string.format("%d/%d (%d,%d)",F.grp(),F.mapn(),x,y) end
local function mapIs(g,m) return F.grp()==g and F.mapn()==m end
local function flagAddr(id)
  if id>=0x6000 and id<0x6400 then local o=id-0x6000; return F.sb3()+S.SaveBlock3.johtoFlags+o//8, 1<<(o%8) end
  return F.sb1()+S.SaveBlock1.flags+id//8, 1<<(id%8)
end
local function flag(id,value)
  local a,bit=flagAddr(id)
  F.w8(a,value and (F.r8(a)|bit) or (F.r8(a)&(~bit&255)))
end
local function flagSet(id) local a,bit=flagAddr(id); return F.r8(a)&bit~=0 end
local function varAddr(id)
  if id>=0xA000 then return F.sb3()+S.SaveBlock3.regionVars+(id-0xA000)*2 end
  return F.sb1()+S.SaveBlock1.vars+(id-0x4000)*2
end
local function var(id,value) F.w16(varAddr(id),value) end
local function getVar(id) return F.r16(varAddr(id)) end

local function scriptMenuActive()
  for i=0,S.Task.count-1 do
    local a=S.gTasks+i*S.Task.stride
    local fn=F.r32(a+S.Task.func)&0xFFFFFFFE
    if F.r8(a+S.Task.isActive)~=0 and (fn==S.Task_HandleYesNoInput or fn==S.Task_HandleMultichoiceInput or fn==S.Task_CallYesOrNoCallback) then return true end
  end
  return false
end
local function hasControl()
  return F.ow() and not scriptMenuActive() and F.r8(S.sLockFieldControls)==0
end
local function awaitControl(tag,frames)
  for _=1,frames//10 do
    if F.reportCrash(tag) then return false end
    if hasControl() then return true end
    F.press("B",2);F.idle(8)
  end
  return false
end
local function menu(want,tag)
  for _=1,65 do
    if F.reportCrash(tag) then return false end
    if scriptMenuActive() then
      F.idle(12)
      for _=1,10 do
        local c=F.mcur()
        if c==want then
          F.press("A",2);F.idle(30)
          return not scriptMenuActive()
        end
        F.press(c>want and "Up" or "Down",2);F.idle(12)
      end
      return false
    end
    F.press("A",2);F.idle(25)
  end
  return false
end
local function awaitMap(g,m,tag)
  for _=1,220 do
    if mapIs(g,m) then F.idle(100);return true end
    if F.reportCrash(tag) then return false end
    F.press("A",2);F.idle(14)
  end
  return false
end
local function debugWarp(g,m,tag)
  local function digits(n) return n//100,(n//10)%10,n%10 end
  local gh,gt,go=digits(g);local mh,mt,mo=digits(m)
  return F.warpTo(gh,gt,go,mh,mt,mo,0,0,0,g,m,tag)
end

-- Select with the Hub Pass registered, then advance the confirm text with a few A presses.
-- The warp tiles these rooms are entered on are not adjacent to the member, so A cannot start a
-- battle. Returns "hub" when the warp happened, "refused" when no YES/NO ever appeared.
local function tryHubPass(tag)
  if not awaitControl(tag.."_ready",600) then return "no control" end
  F.w16(F.sb1()+S.SaveBlock1.registeredItem,hubPass)
  F.press("Select",2);F.idle(60)
  F.shot(tag)
  local confirm=false
  for _=1,40 do
    if scriptMenuActive() then confirm=true;break end
    F.press("A",2);F.idle(30)
  end
  if not confirm then
    awaitControl(tag.."_dismiss",600)
    return "refused"
  end
  if not menu(0,tag.."_yes") then return "confirm stuck" end
  return awaitMap(HUB[1],HUB[2],tag) and "hub" or "lost"
end

local function cross(tag)
  if not F.route({{16,4},{HOENN_ATTENDANT,4},{HOENN_ATTENDANT,3}},tag.."_walk") then return false end
  F.face("Up");F.press("A",3);F.idle(60)
  if not menu(1,tag.."_team") then return false end
  if not menu(1,tag.."_arrival") then return false end
  if not menu(0,tag.."_confirm") then return false end
  return awaitMap(HOENN_STANDARD[1],HOENN_STANDARD[2],tag)
end

local function setup()
  if not F.boot(HUB[1]) then return false end
  flag(0xDCF,true)
  flag(0x51,true)
  flag(0xA4B,true)
  flag(0x63F8,true)
  flag(0x94F,true)
  F.w8(F.sb2()+S.SaveBlock2.introDoneBits,7)
  F.dbg();F.idle(40);F.sel(2);F.idle(40)
  for _=1,9 do F.press("Down",3);F.idle(16) end
  F.press("A",3);F.idle(180)
  awaitControl("party",600)
  local seen={}
  for _,id in ipairs(select(2,F.keyItemSlot(0xFFFF))) do seen[id]=true end
  if not cross("first_keep") then return false end
  for _,id in ipairs(select(2,F.keyItemSlot(0xFFFF))) do if not seen[id] then hubPass=id end end
  return hubPass~=nil
end

-- One room per region, entered as if the previous member had just been beaten.
local rooms = {
  {name="Hoenn Phoebe's room", g=16, m=1, beaten=FLAG_DEFEATED_ELITE_4_SIDNEY,
   prime=function() var(VAR_ELITE_4_STATE,2) end},
  {name="Kanto Bruno's room", g=35, m=76, beaten=FLAG_DEFEATED_LORELEI,
   prime=function() var(VAR_MAP_SCENE_POKEMON_LEAGUE,2) end},
  {name="Johto Koga's room", g=99, m=6,
   prime=function() var(VAR_LEAGUE_STATE,2) end, league=2},
}

local function room(r)
  if r.beaten then flag(r.beaten,true) end
  r.prime()
  if not F.check(r.name..": reached",debugWarp(r.g,r.m,r.name)) then return end
  local result=tryHubPass(r.name)
  F.check(r.name..": Hub Pass refused mid run",result=="refused","result="..result.." at "..where())
  if result=="hub" then
    local kept=r.beaten and flagSet(r.beaten) or getVar(VAR_LEAGUE_STATE)>=r.league
    F.L("  exploit: left the League with the previous member still beaten="..tostring(kept))
  end
  F.check(r.name..": still in the room",mapIs(r.g,r.m),where())
end

F.run(function()
  local ok=setup()
  F.check("setup has a Hub Pass",ok,where())
  if not ok then F.finish();return end
  for _,r in ipairs(rooms) do room(r) end
  F.check("League lobby reached",debugWarp(16,10,"lobby"))
  F.check("Hub Pass still works in the League lobby",tryHubPass("lobby")=="hub",where())
  F.finish()
end)
