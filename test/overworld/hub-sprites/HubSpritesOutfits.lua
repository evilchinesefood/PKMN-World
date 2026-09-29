local here=(debug.getinfo(1,"S").source:sub(2)):match("^(.*[/\\])") or ""
package.path=here.."?.lua;"..package.path
local H=require("hub_lib").new("HubSpritesOutfits")
local F,S=H.F,H.S
local function playerPalette()
  local o=assert(H.actor(255))
  local pal=(F.r16(S.gSprites+o.sprite*S.Sprite.stride+4)>>12)&15
  local colors={}
  for i=1,15 do colors[#colors+1]=string.format("%04X",F.r16(S.gPlttBufferUnfaded+(256+pal*16+i)*2)) end
  return table.concat(colors)
end
local function westEntry(tag)
  H.invoke(1,4,180)
  F.check(tag..": reach upstairs escalator",F.route({{2,6}},tag))
  for _=1,20 do
    F.press("Left",12);F.idle(8)
    if F.mapn()==0 then break end
  end
  for _=1,300 do
    local x,y=F.pos()
    if F.grp()==100 and F.mapn()==0 and x==2 and y==14 and F.ow() then break end
    F.idle(10)
  end
  local x,y=F.pos()
  F.check(tag..": actual west stairs arrival",F.grp()==100 and F.mapn()==0 and x==2 and y==14)
  F.check(tag..": leave west stairs",F.route({{2,13},{4,13}},tag))
end
F.run(function()
  if not F.boot(100) then F.finish();return end
  H.invoke(0,2);H.invoke(11)
  local palettes={}
  for outfit=0,11 do
    H.invoke(2,outfit,180)
    F.check("outfit "..outfit..": walk beside curator",F.step("Right"));F.idle(30)
    H.probe(13,"outfit "..outfit.." curator",true)
    local p=playerPalette()
    palettes[p]=true
    F.shot("outfit_"..outfit.."_curator")
    for entry=0,1 do
      for _,hour in ipairs({12,22}) do
        local tag=string.format("outfit_%02d_%s_%02dh",outfit,entry==0 and "normal" or "west",hour)
        if entry==0 then
          H.invoke(1,0,180)
          F.check(tag..": normal crest arrival",F.grp()==100 and F.mapn()==0)
          F.check(tag..": leave crest",F.step("Right"));F.idle(30)
        else westEntry(tag) end
        H.invoke(3,hour,90)
        F.check(tag..": actual day/night state",F.r8(S.gTimeOfDay)==(hour==22 and S.TimeOfDay.NIGHT or S.TimeOfDay.DAY))
        H.census(tag);H.follower(tag,2)
        F.check(tag..": outfit retained across map/time change",playerPalette()==p)
        F.shot(tag)
        F.press("Start",2);F.idle(60);F.shot(tag.."_menu")
        F.press("B",2);F.idle(90)
        F.check(tag..": menu returns control",F.ensureFree())
        H.follower(tag.."_return",2)
        F.check(tag..": outfit retained after menu",playerPalette()==p)
        H.probe(entry==0 and 13 or 12,tag.."_return",true)
        F.shot(tag.."_return")
      end
    end
  end
  local n=0;for _ in pairs(palettes) do n=n+1 end
  F.check("all twelve gender/outfit palettes differ",n==12,"unique="..n)
  H.finish()
end)
