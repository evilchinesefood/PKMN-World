package.path=assert(os.getenv('PW_FEATURE_LIB'))..'/?.lua;'..package.path
local F,S,U,X,tap,hook,controller,action,exitBattle=require('bw_helpers')('BWPalettes')
local function palette()
 local t={}
 for _,bank in ipairs({0,1,10,11,12,13}) do
  for i=0,31 do t[#t+1]=F.r8(0x5000000+bank*32+i) end
 end
 return table.concat(t,',')
end
F.run(function()
 assert(F.boot(100));hook(0);hook(4,0,300)
 local control
 for _,v in ipairs({{0,'grass'},{2,'sand'},{7,'cave'}}) do
  hook(15,v[1]);hook(1,0,600);assert(action());F.shot(v[2]..'_commands');tap('A');F.shot(v[2]..'_moves')
  local p=palette();if control then F.check(v[2]..' keeps UI palette banks',p==control) else control=p end
  tap('B');F.check(v[2]..' return',exitBattle())
 end
 for i,name in ipairs({'ice_path','mt_silver_snow'}) do
  hook(20,i-1,480);F.shot(name..'_field');hook(1,0,600);assert(action());tap('A');F.shot(name..'_moves')
  F.check(name..' keeps UI palette banks',palette()==control);tap('B');F.check(name..' return',exitBattle())
 end
 hook(4,0,300)
 for outfit=0,11 do
  hook(14,outfit);hook(15,0);hook(1,0,1)
  for i=1,40 do F.idle(8);F.shot(string.format('outfit_%02d_intro_%02d',outfit,i)) end
  F.check('outfit '..outfit..' commands',action());F.check('outfit '..outfit..' return',exitBattle())
 end
 F.finish()
end)
