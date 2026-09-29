-- The restored SwSh frame must coexist with BW cells and palette banks.
package.path=assert(os.getenv('PW_FEATURE_LIB'))..'/?.lua;'..package.path
local F,S,U,X,tap,hook,controller,action,exitBattle=require('bw_helpers')('BWMoveInfo')
local function bytes(address,size)
 local data={};for i=0,size-1 do data[#data+1]=F.r8(address+i) end
 return string.char(table.unpack(data))
end
local function uiPalettes()
 local data=''
 for _,bank in ipairs({0,1,10,11,12,13}) do data=data..bytes(0x05000000+bank*32,32) end
 return data
end
F.run(function()
 assert(F.boot(100));hook(0);hook(4,0,300);hook(1,0,600);assert(action())
 tap('A');tap('Right')
 F.check('Fight reaches moves',controller('HandleInputChooseMove'))
 local selected=F.r8(U.gMoveSelectionCursor)
 local moveTiles=bytes(0x06000000+0x200*32,(0x32a-0x200)*32)
 local palettes=uiPalettes()
 tap('L');F.shot('restored_details')
 F.check('move information preserves move-cell tiles',bytes(0x06000000+0x200*32,(0x32a-0x200)*32)==moveTiles)
 F.check('move information preserves BW UI palettes',uiPalettes()==palettes)
 tap('L');F.shot('restored_moves')
 F.check('details restore selected move',controller('HandleInputChooseMove') and F.r8(U.gMoveSelectionCursor)==selected)
 tap('B');assert(action());F.check('normal exit restores field',exitBattle())
 F.finish()
end)
