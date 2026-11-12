local here=debug.getinfo(1,'S').source:sub(2):match('^(.*[/\\])') or ''
package.path=assert(os.getenv('PW_FEATURE_LIB'))..'/?.lua;'..here..'?.lua;'..package.path
return function(name)
    local S,X,D=require('symbols'),require('feature_symbols'),require('sources_data')
    local F=require('lib').new(S,name)
    local function idle()
        return F.ow() and F.r8(S.sGlobalScriptContextStatus)==2
    end
    local function invoke(command,arg,frames)
        assert(idle(),'fixture requires idle field control')
        F.w16(S.gSpecialVar_0x8004,command)
        F.w16(X.gSpecialVar_0x8005,arg or 0)
        F.w32(S.gMain+4,X.hook)
        F.idle(frames or 60)
    end
    local function flag(id)
        return (F.r8(F.sb1()+S.SaveBlock1.flags+(id//8))&(1<<(id%8)))~=0
    end
    local function object(localId)
        for i=0,15 do
            local b=S.gObjectEvents+i*S.ObjectEvent.stride
            if (F.r8(b)&1)~=0 and F.r8(b+S.ObjectEvent.localId)==localId then
                return F.rs16(b+S.ObjectEvent.x)-7,F.rs16(b+S.ObjectEvent.y)-7
            end
        end
    end
    local function begin(name)
        local row=assert(D[name])
        invoke(1,row.index,180)
        for _=1,120 do
            if idle() then break end
            F.press('B',2); F.idle(10)
        end
        assert(idle(),name..': warp returned field control')
        local ox,oy=object(row.localId)
        assert(ox,name..': source object spawned')
        local px,py=F.pos()
        if math.abs(px-ox)+math.abs(py-oy)~=1 then
            assert(F.leg(ox,oy+1),name..': reach wandering source')
            px,py=F.pos()
        end
        F.face(px<ox and 'Right' or px>ox and 'Left' or py<oy and 'Down' or 'Up')
        F.press('A',2)
        F.idle(10)
        assert(not idle(),name..': actual interaction started')
        F.shot(name)
    end
    local function talk(name,accept)
        begin(name)
        for _=1,500 do
            if idle() then F.check(name..': interaction returned control',true);return end
            F.press(accept and 'A' or 'B',2)
            F.idle(10)
        end
        error(name..': interaction did not finish')
    end
    return {F=F,S=S,X=X,flag=flag,idle=idle,invoke=invoke,begin=begin,talk=talk}
end
