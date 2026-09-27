local M = {}
function M.new(name)
  local here=debug.getinfo(1,'S').source:sub(2):match('^(.*[/\\])') or ''
  package.path=assert(os.getenv('PW_FEATURE_LIB'))..'/?.lua;'..here..'?.lua;'..package.path
  local S,X,O,E=require('symbols'),require('feature_symbols'),require('outfit_symbols'),require('outfit_expected')
  local F=require('lib').new(S,name)
  local function invoke(command,arg,frames)
    assert(F.ow(),'fixture requires idle overworld')
    F.w16(S.gSpecialVar_0x8004,command);F.w16(X.gSpecialVar_0x8005,arg or 0)
    F.w32(S.gMain+4,X.hook);F.idle(frames or 60)
  end
  local function sprite(id)
    assert(id<64,'invalid sprite')
    return S.gSprites+id*S.Sprite.stride
  end
  local function slot(id) return 256+((F.r16(sprite(id)+4)>>12)&15)*16 end
  local function player()
    for i=0,15 do
      local b=S.gObjectEvents+i*S.ObjectEvent.stride
      if (F.r8(b)&1)~=0 and F.r8(b+S.ObjectEvent.localId)==255 then return F.r8(b+0x23) end
    end
    error('no player object')
  end
  local function checkPalette(tag,offset,expected,exactHardware)
    local good,hardware=true,true
    local out=assert(io.open(F.out..tag..'.pal.bin','wb'))
    for i=0,15 do
      local u=F.r16(S.gPlttBufferUnfaded+(offset+i)*2)
      local f=F.r16(S.gPlttBufferFaded+(offset+i)*2)
      local h=F.r16(0x05000000+(offset+i)*2)
      good=good and u==expected[i+1]
      hardware=hardware and h==f and (not exactHardware or h==expected[i+1])
      out:write(string.char(u&255,u>>8,f&255,f>>8,h&255,h>>8))
      if u~=expected[i+1] then F.L(string.format('%s index %d: got %04X expected %04X',tag,i,u,expected[i+1])) end
    end
    out:close()
    F.check(tag..': all 16 source colors',good)
    F.check(tag..': hardware palette',hardware)
  end
  local function reflection(tag,expected)
    for i=0,63 do
      local b=sprite(i)
      if (F.r8(b+S.Sprite.inUse)&1)~=0 and (F.r32(b+0x1C)&~1)==O.UpdateObjectReflectionSprite
        and F.r16(b+0x30)==255 then
        F.check(tag..': reflection is visible and blended',(F.r8(b+0x3E)&4)==0 and ((F.r16(b)>>10)&3)==1)
        local filtered={expected[1]}
        for j=2,16 do local c=expected[j];filtered[j]=(c&1023)|(math.min(31,(c>>10)+10)<<10) end
        checkPalette(tag..'_reflection',slot(i),filtered,false)
        return true
      end
    end
    return F.check(tag..': reflection exists',false)
  end
  local function clock(hour)
    local off=F.sb2()+S.SaveBlock2.localTimeOffset
    local function seconds(p) return F.rs8(p+2)*3600+F.rs8(p+3)*60+F.rs8(p+4) end
    local value=(seconds(off)+seconds(S.gLocalTime)-hour*3600)%86400
    F.w8(off+2,value//3600);F.w8(off+3,(value//60)%60);F.w8(off+4,value%60)
    F.w8(S.sHoursOverride,0);F.w16(S.gTimeUpdateCounter,0);F.idle(120)
  end
  local function task(fn)
    for i=0,15 do
      local b=S.gTasks+i*S.Task.stride
      if F.r8(b+S.Task.isActive)~=0 and (F.r32(b)&~1)==fn then return b end
    end
  end
  local function action()
    for _=1,400 do
      if F.cb2()==O.BattleMainCB2 and (F.r32(O.gBattlerControllerFuncs)&~1)==O.HandleInputChooseAction then return true end
      F.press('A',2);F.idle(8)
    end
    return false
  end
  local function exitBattle()
    assert(action(),'battle command prompt missing')
    local cursor=F.r8(S.gActionSelectionCursor)
    if (cursor&1)==0 then F.press('Right',2);F.idle(15) end
    if (cursor&2)==0 then F.press('Down',2);F.idle(15) end
    F.press('A',2)
    for _=1,400 do
      if F.ow() then F.idle(90);return F.step('Up') and F.step('Down') end
      F.press('A',2);F.idle(12)
    end
    return false
  end
  return {F=F,S=S,X=X,O=O,E=E,invoke=invoke,slot=slot,player=player,sprite=sprite,
    checkPalette=checkPalette,reflection=reflection,clock=clock,task=task,action=action,exitBattle=exitBattle}
end
return M
