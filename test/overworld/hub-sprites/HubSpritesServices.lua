local here=(debug.getinfo(1,"S").source:sub(2)):match("^(.*[/\\])") or ""
package.path=here.."?.lua;"..package.path
local H=require("hub_lib").new("HubSpritesServices")
local F=H.F
local stops={{21,3},{16,3},{11,3},{4,3},{2,2},{2,7},{13,12},{9,11},{4,13}}
local function answerYes()
  for _=1,30 do
    if F.menuLive() then
      for _=1,8 do
        if F.mcur()==0 then F.press("A",2);F.idle(45);return true end
        F.press("Up",2);F.idle(10)
      end
      return false
    end
    F.press("A",2);F.idle(35)
  end
  return false
end
local services={
 {"harbor",{{3,13}},"Down",12},
 {"clerk",{{6,13},{6,7},{2,7}},"Left",3},
 {"frontier",{{6,7},{6,3},{4,3}},"Up",10},
 {"kanto",{{11,3}},"Up",7},
 {"johto",{{16,3}},"Up",8},
 {"hoenn",{{21,3}},"Up",9},
 {"sky_charm",{{10,3},{10,6}},"Down",11},
 {"dex_reward",{{12,6}},"Down",14},
 {"curator",{{22,6}},"Down",13},
 {"nurse",{{22,4},{6,4},{6,12},{13,12}},"Up",1},
 {"chansey",{{14,12}},"Up",2},
 {"pc",{{17,12},{17,10}},"Up",0},
 {"bnet",{{17,12},{9,12},{9,10}},"Up",0},
 {"tm_vendor",{{9,13},{19,13}},"Up",4},
 {"vitamin_vendor",{{21,13}},"Up",5},
 {"battle_depot",{{23,13}},"Up",6},
}
F.run(function()
  if not F.boot(100) then F.finish();return end
  for variant=0,2 do
    local prefix=({"pichu","snorlax","shiny_snorlax"})[variant+1]
    H.invoke(0,variant)
    H.invoke(7,0,400)
    F.check(prefix..": accept intro tour",answerYes())
    local idx,active,visible,maxGap=1,0,0,0
    for frame=1,20000 do
      if frame%24==0 then F.press("B",2) else F.idle(1) end
      local x,y=F.pos()
      if frame%4==0 then
        local o=H.actor(254)
        if o then
          active=active+1
          if o.visible then visible=visible+1;maxGap=math.max(maxGap,math.abs(o.x-x)+math.abs(o.y-y)) end
        end
      end
      if idx<=#stops and x==stops[idx][1] and y==stops[idx][2] then
        H.census(prefix.."_tour_"..idx);F.shot(prefix.."_tour_"..idx);idx=idx+1
      end
      if idx>#stops then break end
    end
    F.check(prefix..": all nine tour stops reached",idx==10)
    F.check(prefix..": tour follower safely pocketed or adjacent",active>0 and (visible==0 or maxGap<=1),
      string.format("active=%d visible=%d maxGap=%d",active,visible,maxGap))
    F.check(prefix..": tour releases control",H.drain());H.follower(prefix.."_tour_end",variant)
    for _,s in ipairs(services) do
      local tag=prefix.."_"..s[1]
      F.check(tag..": service approach reachable",F.route(s[2],tag))
      F.face(s[3]);F.idle(30)
      H.census(tag);H.follower(tag,variant)
      if s[4]>0 then
        local o=H.actor(s[4])
        F.check(tag..": service NPC visible",o~=nil and o.visible)
        if s[4]==12 or s[4]==13 then
          H.probe(s[4],tag,true)
          F.press("A",2);F.idle(100);F.shot(tag.."_dialogue");H.drain()
          F.check(tag..": dialogue returns control",F.ensureFree())
        end
      end
      F.shot(tag)
    end
  end
  local missing={}
  for id=1,14 do if not H.seen[id] then missing[#missing+1]=id end end
  F.check("all fourteen Hub NPCs visibly sampled across the route",#missing==0,table.concat(missing,","))
  H.finish()
end)
