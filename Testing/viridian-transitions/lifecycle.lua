local here=debug.getinfo(1,"S").source:sub(2):match("^(.*[/\\])") or ""
package.path=here.."../night-lighting/?.lua;"..package.path
local W=require("lighting_lib").new("ViridianTransitionsLifecycle")
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
    {"west_entry",13,18,{{19,18},{21,18},{21,21}}},
    {"central_junction",21,21,{{23,21},{23,20},{22,20},{22,19},{23,19}}},
    {"east_loop",31,21,{{40,21},{40,28},{34,28},{34,29},{40,29},{40,28}}},
    {"south_approach",15,33,{{24,33},{24,34},{24,36},{24,33},{38,33},{38,32},{27,32},{27,33}}}
  }
  -- Release input as soon as coordinates change, then settle. Holding for the
  -- walking helper's extra 14 frames overshoots individual tiles on a bicycle.
  local function leg(tx,ty)
    for _=1,100 do
      local x,y=F.pos()
      if x==tx and y==ty then return true end
      local dir=x<tx and "Right" or x>tx and "Left" or y<ty and "Down" or "Up"
      local moved=false
      for _=1,60 do
        joypad.set({[dir]=true});emu.frameadvance()
        local nx,ny=F.pos()
        if nx~=x or ny~=y then moved=true;break end
      end
      F.idle(24)
      if not moved then
        F.shot("blocked");local px,py=F.pos();F.L(string.format("blocked at (%d,%d) toward (%d,%d)",px,py,tx,ty));return false
      end
    end
    local px,py=F.pos();F.L(string.format("overshoot loop at (%d,%d) toward (%d,%d)",px,py,tx,ty));return false
  end
  for mode=0,2 do
    local label=({"walking","running","cycling"})[mode+1]
    for _,p in ipairs(paths) do
      warp(p[2],p[3]);W.clock(12);W.invoke(6,mode)
      W.invoke(7)
      local state=F.r16(W.X.gSpecialVar_0x8005)
      local bike=(state&6)~=0
      F.check(label.." "..p[1]..": correct avatar mode",bike==(mode==2) and ((state&256)~=0)==(mode==1))
      local reached=true
      for _,point in ipairs(p[4]) do reached=leg(point[1],point[2]) and reached end
      F.check(label.." "..p[1]..": all waypoints reached",reached)
      if mode~=2 then
        W.invoke(4)
        F.check(label.." "..p[1]..": follower visible",F.r16(W.X.gSpecialVar_0x8005)==1)
      end
    end
  end
  W.invoke(6,0);warp(37,28);W.invoke(4)
  F.check("follower restored after dismount and map entry",F.r16(W.X.gSpecialVar_0x8005)==1)
  F.shot("actors_on_path")
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
