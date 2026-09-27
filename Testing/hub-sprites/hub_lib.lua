local M = {}
function M.new(name)
  local here = (debug.getinfo(1, "S").source:sub(2)):match("^(.*[/\\])") or ""
  package.path = assert(os.getenv("PW_FEATURE_LIB")) .. "/?.lua;" .. here .. "?.lua;" .. package.path
  local S, H, X = require("symbols"), require("hub_symbols"), require("feature_symbols")
  local F = require("lib").new(S, name)
  local function invoke(command, arg, frames)
    assert(F.ow(), "fixture entry requires the idle overworld")
    F.w16(H.gSpecialVar_0x8004, command)
    F.w16(H.gSpecialVar_0x8005, arg or 0)
    F.w32(S.gMain + 4, X.hook)
    F.idle(frames or 60)
  end
  local function actor(id)
    for i = 0, 15 do
      local b = S.gObjectEvents + i * S.ObjectEvent.stride
      if (F.r8(b) & 1) ~= 0 and F.r8(b + S.ObjectEvent.localId) == id then
        return { x=F.rs16(b+S.ObjectEvent.x)-7, y=F.rs16(b+S.ObjectEvent.y)-7,
                 gfx=F.r16(b+S.ObjectEvent.graphicsId),
                 visible=(F.r8(b+S.ObjectEvent.flags1) & 0x60)==0,
                 sprite=F.r8(b+0x23), base=b }
      end
    end
  end
  local csv = assert(io.open(F.out .. name .. "-actors.csv", "w"))
  csv:write("scene,map_group,map_number,player_x,player_y,local_id,x,y,graphics_id,visible,sprite,palette\n")
  local seen, peak = {}, 0
  local function census(scene)
    local n = 0
    local x,y = F.pos()
    for id = 0,255 do
      local o=actor(id)
      if o then
        n=n+1
        local pal = (F.r16(S.gSprites+o.sprite*S.Sprite.stride+4)>>12)&15
        csv:write(string.format("%s,%d,%d,%d,%d,%d,%d,%d,%d,%s,%d,%d\n",
          scene,F.grp(),F.mapn(),x,y,id,o.x,o.y,o.gfx,tostring(o.visible),o.sprite,pal))
        if F.grp()==100 and F.mapn()==0 and o.visible then seen[id]=true end
      end
    end
    csv:flush(); peak=math.max(peak,n)
    F.check(scene .. ": object budget", n<=16, "active="..n)
    return n
  end
  local function probe(id, tag, requireNew)
    invoke(5,id,1)
    local function v(n) return F.r16(H["gSpecialVar_0x800"..n]) end
    local flags,gfx,pal,ptag,dims,shadow,dir=v("5"),v("6"),v("7"),v("8"),v("9"),v("A"),v("B")
    F.L(string.format("PROBE %s id=%d flags=0x%02X gfx=0x%04X pal=%d tag=0x%04X size=%dx%d shadow=%d dir=%d",
       tag,id,flags,gfx,pal,ptag,dims>>8,dims&255,shadow,dir))
    F.check(tag .. ": actor and sprite present", (flags&3)==3)
    if requireNew then
      F.check(tag .. ": approved FRLG graphics", gfx==v("3"))
      F.check(tag .. ": correct palette colors and slot", (flags&0x30)==0x30)
      F.check(tag .. ": standard dimensions and shadow", dims==0x1020 and shadow==1)
    end
    return flags,gfx,pal,dims
  end
  local function follower(tag,variant)
    local o=actor(254)
    local x,y=F.pos()
    F.check(tag .. ": follower visible and adjacent",o~=nil and o.visible and math.abs(o.x-x)+math.abs(o.y-y)<=1)
    local flags,gfx,pal=probe(254,tag .. " follower",false)
    F.check(tag .. ": expected follower species/shininess",(gfx&0x8FFF)==(variant==0 and 172 or 143)
      and ((gfx&0x2000)~=0)==(variant==2))
    F.check(tag .. ": follower palette matches its source",(flags&0x30)==0x30 and pal>=0 and pal<16)
  end
  local function drain()
    for i=1,200 do
      F.press("B",2);F.idle(24)
      if i%6==0 and F.ensureFree() then return true end
    end
    return F.ensureFree()
  end
  local function finish()
    csv:close()
    F.L("Peak active objects="..peak)
    F.finish()
  end
  return {F=F,S=S,invoke=invoke,actor=actor,census=census,probe=probe,follower=follower,
          drain=drain,finish=finish,seen=seen}
end
return M
