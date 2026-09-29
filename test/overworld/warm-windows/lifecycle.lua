local here = debug.getinfo(1, "S").source:sub(2):match("^(.*[/\\])") or ""
package.path = here.."?.lua;"..package.path
local W = require("windows_lib").new("WarmWindowsLifecycle")
local F,S = W.F,W.S
local function tap(key) F.press(key,2);F.idle(60) end
local function record(tag,n,key)
  for i=1,n do
    if key then F.press(key,1) else F.idle(1) end
    if i%6==0 then client.screenshot(F.out..string.format("%s_%03d.png",tag,i//6)) end
  end
end
local function naturalBoundary(tag,h,m)
  W.clock(h,m,50)
  local x0,y0 = F.pos()
  local initial = F.r16(S.gTimeBlend+10)
  local last, stayed, monotonic = initial,true,true
  local csv = assert(io.open(F.out..tag..".csv","w"))
  csv:write("frame,hour,minute,alt_weight\n")
  -- Real RTC progression, no further clock/counter writes or fixture calls.
  for i=1,12000 do
    F.idle(1)
    stayed = stayed and F.ow() and F.grp()==75 and F.mapn()==1
    local value = F.r16(S.gTimeBlend+10)
    monotonic = monotonic and (tag=="natural_dusk" and value<=last or tag=="natural_dawn" and value>=last)
    last = value
    if i%120==0 then
      csv:write(string.format("%d,%d,%d,%d\n",i,F.rs8(S.gLocalTime+S.Time.hours),F.rs8(S.gLocalTime+S.Time.minutes),value))
      client.screenshot(F.out..string.format("%s_%03d.png",tag,i//120))
    end
  end
  csv:close()
  local x,y = F.pos()
  F.check(tag..": clock crossed boundary naturally",initial~=last and (initial-128)*(last-128)<0)
  F.check(tag..": blend moved monotonically",monotonic)
  F.check(tag..": no map reload or player movement",stayed and x==x0 and y==y0)
  W.palette(tag)
end
F.run(function()
  assert(F.boot(100),"boot failed");W.invoke(0);W.go(2)
  for _, spec in ipairs({{"dusk",19*60,15},{"dawn",6*60,30}}) do
    for i=0,8 do
      local minute = spec[2]+i*spec[3]
      W.clock(minute//60,minute%60)
      W.palette(spec[1].." sweep "..i)
      client.screenshot(F.out..string.format("sweep_%s_%03d.png",spec[1],i+1))
    end
  end
  naturalBoundary("natural_dusk",19,58)
  naturalBoundary("natural_dawn",7,58)
  W.clock(22);W.palette("before returns")
  tap("Start")
  local menu = F.r32(S.sUsmState)
  assert(menu>=0x02000000 and menu<0x02040000,"start menu state missing")
  local selection = F.r8(menu+5)
  tap("Right")
  F.check("start menu opens and responds",F.r8(menu+5)~=selection)
  tap("Left")
  record("menu",60)
  tap("B");F.idle(120)
  F.check("start menu closes",F.ow());W.palette("menu return");W.dump("menu_return")
  -- Enter the west house through its normal door and leave through its warp.
  assert(F.route({{34,14}},"front_door"),"door approach failed")
  record("house_entry",90,"Up");F.idle(180)
  F.check("normal house entry",F.grp()~=75 or F.mapn()~=1)
  local x,y=F.pos();F.L(string.format("inside house (%d,%d) map %d/%d",x,y,F.grp(),F.mapn()))
  record("house_exit",90,"Down");F.idle(180)
  F.check("normal house exit",F.grp()==75 and F.mapn()==1)
  W.palette("house return");W.dump("house_return")
  -- A real encounter and ordinary Run selection exercise the battle return.
  W.invoke(2,0,600)
  F.check("wild battle entered",not F.ow())
  local function prompt()
    local text={}
    for i=0,80 do
      local b=F.r8(S.gDisplayedStringBattle+i);if b==255 then break end
      if b>=0xBB and b<=0xD4 then text[#text+1]=string.char(b-0xBB+65)
      elseif b>=0xD5 and b<=0xEE then text[#text+1]=string.char(b-0xD5+65)
      elseif b==0 then text[#text+1]=" " end
    end
    return table.concat(text):find("WHAT WILL",1,true)~=nil
  end
  for _=1,100 do if prompt() then break end;tap("A") end
  assert(prompt(),"battle command prompt did not open")
  F.shot("battle");tap("B")
  F.check("Run selected",F.r8(S.gActionSelectionCursor)==3)
  tap("A");record("battle_return",180)
  for _=1,40 do if F.ow() then break end;tap("A") end
  assert(F.ow(),"battle did not return")
  F.check("escaped normally",F.outcome()==4);F.idle(120)
  W.palette("battle return");W.dump("battle_return")
  -- Cross the actual New Bark / Route 29 connection in both directions.
  W.invoke(1,10,300);record("connection_out",60,"Left");F.idle(180)
  F.check("walked into Route29",F.grp()==75 and F.mapn()==2)
  W.palette("connection outward")
  record("connection_back",90,"Right");F.idle(180)
  F.check("walked back into New Bark",F.grp()==75 and F.mapn()==0)
  W.palette("connection return");W.dump("connection_return")
  W.go(2);W.clock(22)
  W.invoke(3,0,1200)
  F.check("synthetic night save written",F.r16(W.X.gSpecialVar_0x8005)==1)
  client.reboot_core();F.idle(5)
  assert(F.boot(75,true),"night save failed to reload")
  F.idle(120);F.check("save returns to Cherrygrove",F.grp()==75 and F.mapn()==1)
  W.palette("save reload");W.dump("save_reload")
  F.check("normal controls after reload",F.ensureFree())
  F.finish()
end)
