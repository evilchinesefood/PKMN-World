package.path=assert(os.getenv('PW_FEATURE_LIB'))..'/?.lua;'..package.path
local S,X,V=require('symbols'),require('feature_symbols'),require('visual_symbols')
local F=require('lib').new(S,'SpecialPokemonVisuals')
local names={'classic_cap','surfboard','balloons','squad','firefighter','flower_crown','pirate'}
local function invoke(command,arg,frames)
  assert(F.ow(),'visual fixture needs field control')
  F.w16(S.gSpecialVar_0x8004,command);F.w16(X.gSpecialVar_0x8005,arg or 0)
  F.w32(S.gMain+4,X.hook);F.idle(frames or 60)
end
local function tap(key,frames) F.press(key,2);F.idle(frames or 30) end
local function closeScreen()
  for _=1,40 do
    tap('B',30)
    if F.ow() then tap('B',30);return end
  end
  error('screen did not return to overworld')
end
local function action()
  for _=1,400 do
    if F.cb2()==V.BattleMainCB2 and (F.r32(V.gBattlerControllerFuncs)&~1)==V.HandleInputChooseAction then return end
    tap('A',8)
  end
  F.shot('battle_prompt_missing');error('battle command prompt missing')
end
local function exitBattle()
  local cursor=F.r8(S.gActionSelectionCursor)
  if (cursor&1)==0 then tap('Right',15) end
  if (cursor&2)==0 then tap('Down',15) end
  tap('A',10)
  for _=1,400 do
    if F.ow() then F.idle(90);return end
    tap('A',10)
  end
  error('normal run command did not exit battle')
end
local function follower(tag,direction)
  F.check(tag..': move '..direction,F.step(direction) and F.step(direction))
  F.idle(30);invoke(4)
  F.check(tag..': exact visible follower '..direction,F.r16(S.gSpecialVar_Result)==15)
  F.shot(tag..'_follow_'..direction)
end
local function capture(id,female)
  local tag=names[id+1]..(female and '_female' or '_male')
  invoke(0,id+(female and 7 or 0),300)
  follower(tag,'Right')
  follower(tag,'Left')
  follower(tag,'Down')
  follower(tag,'Up')
  invoke(1,0,240)
  F.check(tag..': summary opened',not F.ow());F.shot(tag..'_summary');closeScreen()
  invoke(3,0,240)
  F.check(tag..': party opened',not F.ow());F.shot(tag..'_party');closeScreen()
  invoke(2,0,1);action()
  local front=F.r8(V.gBattlerSpriteIds+1)
  local back=F.r8(V.gBattlerSpriteIds)
  F.check(tag..': two active battle sprites',front<64 and back<64 and front~=back
    and (F.r8(S.gSprites+front*S.Sprite.stride+S.Sprite.inUse)&1)~=0
    and (F.r8(S.gSprites+back*S.Sprite.stride+S.Sprite.inUse)&1)~=0)
  F.shot(tag..'_battle_front_back');exitBattle()
  if id==2 then
    invoke(7);F.check(tag..': flight picks balloon identity',F.r16(S.gSpecialVar_Result)==1)
  end
end
F.run(function()
  assert(F.boot(100))
  for id=0,6 do capture(id,false) end
  for _,id in ipairs({0,1,2,5}) do capture(id,true) end
  for _,id in ipairs({1}) do
    invoke(0,id,300);invoke(8,0,300)
    F.check(names[id+1]..': reach water edge',F.step('Up') and F.step('Down'))
    F.face('Down');F.idle(30);invoke(5,0,600)
    invoke(6)
    F.check(names[id+1]..': native surf mount identity and sprite',F.r16(S.gSpecialVar_Result)==7)
    F.shot(names[id+1]..'_surf_mount')
    F.check(names[id+1]..': move across water',F.step('Down'))
    F.shot(names[id+1]..'_surf_move')
    F.check(names[id+1]..': return to shore',F.step('Up') and F.step('Up'))
  end
  F.finish()
end)
