local here=debug.getinfo(1,"S").source:sub(2):match("^(.*[/\\])") or ""
package.path=here.."../night-lighting/?.lua;"..package.path
local W=require("lighting_lib").new("ViridianFrontagesLifecycle")
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
local function message()
  local chars={}
  for i=0,511 do
    local b=F.r8(S.gStringVar4+i)
    if b==0xFF then break end
    if b>=0xBB and b<=0xD4 then chars[#chars+1]=string.char(65+b-0xBB)
    elseif b>=0xD5 and b<=0xEE then chars[#chars+1]=string.char(97+b-0xD5)
    elseif b==0 or b==0xFE then chars[#chars+1]=" " end
  end
  return table.concat(chars)
end
local function dismiss()
  for _=1,15 do tap("B") end
end
F.run(function()
  assert(F.boot(100),"boot failed");W.invoke(0)
  local paths={
    {"house",23,12,{{24,12},{25,12},{26,12},{26,13},{22,13},{22,7},{29,7},{29,11},{29,9},{29,11}}},
    {"school",29,19,{{29,16},{29,19},{28,19}}},
    {"center",23,26,{{23,25},{23,26},{23,27},{29,27},{29,26},{29,25},{29,26}}},
    {"mart",33,19,{{33,18},{33,19},{33,20},{38,20},{38,19},{38,18},{38,19}}},
    {"gym_west",32,11,{{33,11},{32,11}}},
    {"gym_east",37,11,{{38,11},{37,11}}}
  }
  for _,p in ipairs(paths) do
    warp(p[2],p[3]);W.clock(12)
    F.check(p[1]..": frontage traversable",F.route(p[4],p[1]))
    W.invoke(4)
    F.check(p[1]..": follower remains visible",F.r16(W.X.gSpecialVar_0x8005)==1)
    if p[1]=="center" then F.shot("actors_on_planted_edge") end
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
  for _,sign in ipairs({{"gym_sign",32,11,"VIRIDIAN CITY"},
                          {"city_sign",20,17,"The Eternally Green Paradise"},
                          {"south_tips",20,32,"POWER POINTS"},
                          {"north_tips",23,2,"collection"}}) do
    warp(sign[2],sign[3]);F.w8(S.gStringVar4,0xFF);F.face("Up")
    tap("A");F.idle(180)
    F.L(sign[1].." text: "..message())
    F.check(sign[1]..": correct sign text",message():find(sign[4],1,true)~=nil)
    dismiss()
    F.check(sign[1]..": returns control",F.ow() and F.ensureFree())
  end
  -- Exercise the original early-story roadblock; the fixture only seeds its var.
  W.invoke(6,0,360);F.w8(S.gStringVar4,0xFF)
  F.press("Up",24);F.idle(120)
  F.check("early-story roadblock still opens its dialogue",message():find("private property",1,true)~=nil)
  dismiss()
  local bx,by=F.pos()
  F.check("roadblock returns the player south",F.ow() and bx==22 and by==12)
  W.invoke(6,2,360)
  F.check("post-tutorial corridor opens",F.route({{22,10},{22,12}},"open_corridor"))
  W.invoke(5,0,360)
  F.w8(S.gStringVar4,0xFF)
  F.press("Up",24);F.idle(90)
  F.check("gym locked-door message remains correct",message():find("doors are locked",1,true)~=nil)
  for _=1,12 do tap("B") end
  local x,y=F.pos()
  F.check("locked gym returns to unchanged jump-back tile",F.ow() and x==36 and y==13)
  for _,state in ipairs({{0,"locked","always closed"},{1,"unlocked","LEADER returned"}}) do
    W.invoke(5,state[1],360);warp(33,11)
    F.w8(S.gStringVar4,0xFF);F.face("Right");tap("A");F.idle(180)
    F.check("gym old man "..state[2]..": correct dialogue",message():find(state[3],1,true)~=nil)
    dismiss()
    F.check("gym old man "..state[2]..": returns control",F.ow() and F.ensureFree())
  end
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
