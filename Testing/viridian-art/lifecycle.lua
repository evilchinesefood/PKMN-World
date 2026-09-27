local here=debug.getinfo(1,"S").source:sub(2):match("^(.*[/\\])") or ""
package.path=here.."../night-lighting/?.lua;"..package.path
local W=require("lighting_lib").new("ViridianArtLifecycle")
local F,S=W.F,W.S
local function warp(x,y)
  W.invoke(3,x+y*256,360)
  local px,py=F.pos()
  assert(F.ow() and F.grp()==37 and F.mapn()==1 and px==x and py==y,"fixture warp failed")
end
local function cross(key,group,map)
  for _=1,80 do
    F.press(key,8);F.idle(12)
    if F.grp()==group and F.mapn()==map then F.idle(180);return F.ow() end
  end
  return false
end
local function tap(key) F.press(key,2);F.idle(60) end
F.run(function()
  assert(F.boot(100),"boot failed");W.invoke(0)
  local paths={
    {"west_entry",7,15,{{8,15},{8,16},{7,16},{7,15}}},
    {"western_lawn",8,20,{{12,20},{12,21},{8,21},{8,20}}},
    {"pond_walk",17,26,{{19,26},{19,29},{17,29},{17,26}}},
    {"eastern_garden",34,23,{{38,23},{38,26},{34,26},{34,23},{35,24},{36,24},{36,25},{37,25}}},
    {"northeast_verge",32,13,{{34,13},{34,14},{32,14},{32,13}}},
    {"southern_verge",24,31,{{40,31},{24,31}}}
  }
  for _,p in ipairs(paths) do
    warp(p[2],p[3]);W.clock(12)
    F.check(p[1]..": garden traversable",F.route(p[4],p[1]))
    W.invoke(4)
    F.check(p[1]..": follower remains visible",F.r16(W.X.gSpecialVar_0x8005)==1)
    if p[1]=="eastern_garden" then F.shot("actors_on_flowers") end
  end
  for _,d in ipairs({{"house",25,12,0},{"school",25,19,2},{"mart",36,20,3},
                     {"center",26,27,4},{"gym",36,11,1}}) do
    warp(d[2],d[3]);W.clock(22)
    F.check(d[1]..": correct door entry",cross("Up",39,d[4]))
    assert(F.grp()==39 and F.mapn()==d[4],"door entry failed: "..d[1])
    F.check(d[1]..": normal door exit",cross("Down",37,1))
    F.check(d[1]..": night tint restored",F.r16(S.gTimeBlend+10)==0)
  end
  for _,c in ipairs({{"Route1",23,38,"Down",19,"Up"},
                     {"Route2",21,1,"Up",20,"Down"},
                     {"Route22",1,18,"Left",41,"Right"}}) do
    warp(c[2],c[3])
    F.check(c[1]..": normal connection exit",cross(c[4],37,c[5]))
    F.check(c[1]..": normal connection return",cross(c[6],37,1))
  end
  W.invoke(5,0,360)
  F.press("Up",24);F.idle(90)
  for _=1,12 do tap("B") end
  local x,y=F.pos()
  F.check("locked gym returns to unchanged jump-back tile",F.ow() and x==36 and y==13)
  W.invoke(5,1,360)
  W.invoke(1,2,360);W.clock(22)
  local palette={}
  for i=0,207 do palette[i]=F.r16(S.gPlttBufferUnfaded+i*2) end
  tap("Start");tap("Right");tap("Left");tap("B");F.idle(120)
  F.check("menu returns to field",F.ow() and F.ensureFree())
  local restored=true
  for i=0,207 do restored=restored and palette[i]==F.r16(S.gPlttBufferUnfaded+i*2) end
  F.check("menu preserves map palettes and night blend",restored and F.r16(S.gTimeBlend+10)==0)
  W.invoke(2,0,1200)
  F.check("synthetic save written",F.r16(W.X.gSpecialVar_0x8005)==1)
  client.reboot_core();F.idle(5)
  F.check("Continue returns to Viridian",F.boot(37,true) and F.mapn()==1)
  F.idle(120)
  F.check("Continue preserves night tint and walking",F.r16(S.gTimeBlend+10)==0 and F.ensureFree())
  F.shot("night_continue")
  F.finish()
end)
