local here=debug.getinfo(1,'S').source:sub(2):match('^(.*[/\\])') or ''
package.path=here..'?.lua;'..package.path
local H=require('outfit_lib').new('OutfitPoses')
local F,S=H.F,H.S
F.run(function()
  assert(F.boot(100));H.invoke(0)
  for gender=0,1 do
    for style=1,3 do
      local selection=style*6+1
      H.invoke(1,gender*24+selection,300);H.clock(12)
      for pose=0,8 do
        for direction=0,2 do
          if pose~=8 or direction==0 then
            H.invoke(6,pose+direction*9,1)
            F.idle(3)
            local tag=string.format('gender%d_style%d_pose%d_direction%d',gender,style,pose,direction)
            H.checkGraphics(tag,selection,gender,pose)
            H.checkPalette(tag,H.slot(H.player()),H.E['OW_'..(gender==0 and 'Male' or 'Female')][selection+1],false)
            F.shot(tag)
          end
        end
      end
    end
  end
  F.finish()
end)
