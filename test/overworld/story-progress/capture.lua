-- Disposable fixture enters the production renderer. Never touches an owner save.
package.path=assert(os.getenv('PW_FEATURE_LIB'))..'/?.lua;'..package.path
local S=require('symbols');local X=require('story_symbols')
local F=require('lib').new(S,'StoryProgress')
local texts=require('story_texts')
local function tap(k) F.press(k,2);F.idle(90) end
local function hook(c,a)
  F.w16(S.gSpecialVar_0x8004,c);F.w16(X.gSpecialVar_0x8005,a or 0)
  F.w32(S.gMain+4,X.hook);F.idle(200)
end
local function open()return (F.cb2()&~1)==(X.CB2_Story&~1) end
local byId={}
for _,objective in ipairs(texts) do byId[objective.id]=objective end
local layouts={X.sRegionMap_MapSectionLayout,X.sRegionMapSections_Kanto,X.sRegionMapSections_Sevii123,
  X.sRegionMapSections_Sevii45,X.sRegionMapSections_Sevii67,X.sRegionMapSections_Johto}
local function ptrarg(pointer)
  F.w16(X.gSpecialVar_0x8008,pointer&0xffff);F.w16(X.gSpecialVar_0x8009,pointer>>16)
end
local function resumeHook(command,arg)
  ptrarg(F.cb2()|1);hook(command,arg)
end
local function view()
  local p=F.r32(X.sStoryDestinationMap)
  assert(p>=0x02000000 and p<0x02040000,string.format('destination view is not allocated p=%08X cb=%08X detail=%d page=%d',p,F.cb2(),F.r8(X.sStoryDetail),F.r8(X.sStoryPage)))
  assert((F.cb2()&~1)==(X.CB2_StoryDestinationMap&~1),'destination callback is not active')
  return p
end
local function bytes(address,size)
  local result={}
  for i=0,size-1 do result[#result+1]=string.char(F.r8(address+i)) end
  return table.concat(result)
end
local function spriteResources()
  local tiles,palettes=0,0
  for i=0,X.spriteAllocSize-1 do
    local value=F.r8(X.sSpriteTileAllocBitmap+i)
    for bit=0,7 do if value&(1<<bit)~=0 then tiles=tiles+1 end end
  end
  for i=0,X.spritePaletteSize-1,2 do
    if F.r16(X.sSpritePaletteTags+i)~=0xffff then palettes=palettes+1 end
  end
  return {tiles,palettes}
end
local function heap()
  local p,total=S.gHeap,0
  for _=1,1024 do
    assert(p>=S.gHeap and p<S.gHeap+0x1c500,'heap link outside arena')
    assert(F.r16(p+2)==0xa3a3,'heap guard corrupted')
    if F.r16(p)&1~=0 then total=total+(F.r32(p+4)&0x3ffff) end
    p=F.r32(p+12);if p==S.gHeap then return total end
  end
  error('heap chain does not terminate')
end
local function tasks()
  local result={}
  for i=0,15 do
    local p=S.gTasks+i*40
    if F.r8(p+4)~=0 then result[#result+1]=F.r32(p)&~1 end
  end
  table.sort(result);return table.concat(result,',')
end
local function layoutSection(kind,x,y)
  if x<1 or x>28 or y<2 or y>16 then return -1 end
  local offset=(y-2)*28+x-1
  return F.r16(layouts[kind+1]+offset*2)
end
local function assertDestination(objective,label,expectedType,player)
  local p=view();local pinned=F.r8(p+0x88d)~=0
  F.check(label..' keeps selected objective',F.r32(p+0x884)==(objective and objective.address or 0))
  if objective and objective.kind==0 then
    local kind=F.r8(p+0x84)
    F.check(label..' has regional marker',pinned and F.r32(p+0x1c)~=0 and F.r8(p+0x88c)==0)
    F.check(label..' marker occupies its actual layout section',F.r16(p)==objective.section and layoutSection(kind,F.r16(p+0x54),F.r16(p+0x56))==objective.section)
    F.check(label..' uses expected region/submap',kind==(expectedType or objective.mapType))
    if player~=nil then F.check(label..' player icon matches physical location',(F.r32(p+0x20)~=0)==player and (F.r8(p+0x85)~=0)==player) end
  else
    F.check(label..' explains missing marker',not pinned and F.r8(p+0x88c)==1 and F.r32(p+0x1c)==0 and F.r32(p+0x20)==0)
  end
  return p
end
local function storyMap(label,objective,expectedType,player,shot)
  local selected={F.r8(X.sStoryRegion),F.r8(X.sStoryPage),F.r8(X.sStoryDetail)}
  local beforeHeap,beforeTasks=heap(),tasks()
  local beforeWarp,beforeSprites=bytes(X.sWarpDestination,8),spriteResources()
  resumeHook(7)
  tap('A');local p=assertDestination(objective,label,expectedType,player)
  if shot then F.shot(shot) end
  local mapSection=F.r16(p);local x,y=F.r16(p+0x54),F.r16(p+0x56)
  for _,key in ipairs({'R','L','Up','Down','Left','Right','Start','Select'}) do tap(key) end
  F.check(label..' ignores travel and navigation controls',view()==p and F.r16(p)==mapSection and F.r16(p+0x54)==x and F.r16(p+0x56)==y)
  if objective.kind==0 then
    tap('A');F.check(label..' shows location text',F.r8(p+0x88c)==1)
    if shot then F.shot(shot..'_details') end
    if selected[2]~=2 and selected[2]~=4 then tap('A');F.check(label..' restores map',F.r8(p+0x88c)==0) end
  end
  tap('B')
  F.check(label..' restores exact Story page',open() and F.r8(X.sStoryRegion)==selected[1] and F.r8(X.sStoryPage)==selected[2] and F.r8(X.sStoryDetail)==selected[3])
  F.check(label..' frees viewer and restores heap/tasks',F.r32(X.sStoryDestinationMap)==0 and heap()==beforeHeap and tasks()==beforeTasks)
  local afterSprites=spriteResources()
  F.check(label..' releases sprite resources',afterSprites[1]==0 and afterSprites[2]==0,
    string.format('tiles %d to %d, palettes %d to %d',beforeSprites[1],afterSprites[1],beforeSprites[2],afterSprites[2]))
  resumeHook(8);F.check(label..' leaves gameplay state unchanged',F.r16(S.gSpecialVar_Result)==1 and bytes(X.sWarpDestination,8)==beforeWarp)
end
local function directMap(objective,label,expectedType,player,shot)
  local beforeWarp=bytes(X.sWarpDestination,8)
  resumeHook(7)
  ptrarg(objective and objective.address or 0);hook(6)
  local p=assertDestination(objective,label,expectedType,player)
  if shot then F.shot(shot) end
  if player then
    local cursor,icon=F.r32(p+0x1c),F.r32(p+0x20)
    tap('A')
    F.check(label..' hides both icons throughout location text',F.r8(p+0x88c)==1 and F.r8(cursor+0x3e)&4~=0 and F.r8(icon+0x3e)&4~=0)
    tap('A')
    F.check(label..' restores both icons on map',F.r8(p+0x88c)==0 and F.r8(cursor+0x3e)&4==0 and F.r8(icon+0x3e)&4==0)
  end
  tap('B');F.check(label..' returns to field',F.ow() and F.r32(X.sStoryDestinationMap)==0)
  resumeHook(8);F.check(label..' leaves gameplay state unchanged',F.r16(S.gSpecialVar_Result)==1 and bytes(X.sWarpDestination,8)==beforeWarp)
end

F.run(function()
  F.check('fresh fixture boots',F.boot(100));if not F.ow() then F.finish();return end
  hook(0)
  local tooWide=0;local fields=0
  for _,o in ipairs(texts) do
    for _,ptr in ipairs(o.texts) do
      F.w16(X.gSpecialVar_0x8008,ptr&0xffff);F.w16(X.gSpecialVar_0x8009,ptr>>16)
      F.w16(S.gSpecialVar_0x8004,3);F.w32(S.gMain+4,X.hook);F.idle(2)
      local width=F.r16(S.gSpecialVar_Result)
      fields=fields+1
      if width>216 then tooWide=tooWide+1;F.L(o.id..' text too wide: '..width) end
    end
  end
  F.check('every compiled objective fits production font',fields==#texts*5 and fields>500 and tooWide==0,'fields='..fields)
  for _,name in ipairs({'sDetailControls','sMapControls','sInfoControls','sBackControls','sAccess'}) do
    ptrarg(X[name]);F.w16(S.gSpecialVar_0x8004,3);F.w32(S.gMain+4,X.hook);F.idle(2)
    F.check(name..' fits native window',F.r16(S.gSpecialVar_Result)<=220,'width='..F.r16(S.gSpecialVar_Result))
  end
  hook(1)
  F.check('production Story opens',open());F.check('active campaign selected',F.r8(X.sStoryRegion)==0);F.shot('overview')
  F.check('text and background layers visible',F.r16(0x04000000)&0x0900==0x0900)
  tap('A');F.shot('kanto_next');tap('Right');F.shot('kanto_where');tap('Right');F.shot('kanto_recap')
  tap('B');tap('Down');tap('A');F.check('Johto selected',F.r8(X.sStoryRegion)==1);F.shot('johto_next')
  tap('B');tap('Down');tap('A');F.check('Hoenn selected',F.r8(X.sStoryRegion)==2);F.shot('hoenn_next')
  tap('B');tap('B');F.check('screen closes to overworld',F.ow() and not open())
  hook(2);F.check('state unchanged after browsing',F.r16(S.gSpecialVar_Result)==1)
  for i=1,8 do hook(1);tap('B') end
  F.check('repeated visits return cleanly',F.ow() and not open())
  hook(2);F.check('repeat browsing preserves state',F.r16(S.gSpecialVar_Result)==1)
  hook(1);tap('A')
  for page=0,2 do
    storyMap('main page '..page,byId['kanto.deliver_parcel'],1,false,page==0 and 'destination_from_hub' or nil)
    if page<2 then tap('Right') end
  end
  resumeHook(13,4)
  storyMap('resolver refresh at map open',byId['kanto.parcel'],1,false)
  resumeHook(13,5)
  for i=1,6 do storyMap('repeated child '..i,byId['kanto.deliver_parcel'],1,false) end
  tap('B');tap('B')
  hook(4)
  F.check('classic menu remains within screen',F.r8(S.gWindows+F.r8(X.sStartMenuWindowId)*12+4)<=18)
  local count=F.r8(X.sNumStartMenuActions)
  while F.r8(X.sStartMenuCursorPos)~=0 do tap('Down') end
  for i=1,count-1 do tap('Down') end
  F.check('classic menu reaches its last action with scrolling',count>8 and F.r8(X.sStartMenuCursorPos)==count-1 and F.r8(X.sStartMenuScrollOffset)==count-8)
  tap('Down');F.check('classic menu wraps from last to first',F.r8(X.sStartMenuCursorPos)==0 and F.r8(X.sStartMenuScrollOffset)==0)
  tap('Up');F.check('classic menu wraps from first to last',F.r8(X.sStartMenuCursorPos)==count-1 and F.r8(X.sStartMenuScrollOffset)==count-8)
  tap('Down')
  local story=false
  for i=1,count do
    local cursor=F.r8(X.sStartMenuCursorPos)
    local action=F.r8(X.sCurrentStartMenuActions+cursor)
    if action==16 then story=true;tap('A');break end
    tap('Down')
  end
  F.check('Story reachable from classic menu',story and open());F.shot('classic_story')
  tap('B');tap('B')
  F.check('classic caller restores menu/overworld',F.ow())
  hook(5);hook(1);F.shot('champion_overview');tap('A');F.shot('champion_next')
  F.check('Champion status retained with started optional chain',F.r8(X.sStoryProgress+8)==2 and F.r32(X.sStoryProgress+4)~=0)
  storyMap('completed main has hub explanation',byId['kanto.champion'],nil,false,'hub_exemption')
  tap('Right');tap('Right');tap('Right');F.shot('optional_next')
  F.check('optional action page reachable',F.r8(X.sStoryPage)==3)
  local optionalPointer=F.r32(X.sStoryProgress+4)
  local optionalObjective
  for _,objective in ipairs(texts) do if objective.address==optionalPointer then optionalObjective=objective end end
  assert(optionalObjective,'optional objective missing from compiled inventory')
  storyMap('optional action',optionalObjective,2,false,'optional_destination')
  tap('Right');F.shot('optional_why');F.check('optional prerequisite page reachable',F.r8(X.sStoryPage)==4)
  storyMap('optional prerequisite',optionalObjective,2,false)
  tap('Right');F.check('five-page detail wraps cleanly',F.r8(X.sStoryPage)==0)
  tap('B');tap('B');F.check('Champion/optional view returns cleanly',F.ow())
  hook(10,2)
  F.check('cross-region fixture is physically in Hoenn',F.grp()==0 and F.mapn()==9)
  local representative={['hoenn.starter_lab']=0,['kanto.deliver_parcel']=1,['kanto.lostelle']=2,
    ['kanto.warehouse']=3,['kanto.dotted_hole']=4,['johto.starter']=5}
  local captured={}
  for _,objective in ipairs(texts) do
    local kind=representative[objective.id]
    local player
    if kind~=nil then player=kind==0 end
    directMap(objective,objective.id,kind,player,kind and 'layout_'..kind or nil)
    if kind then captured[kind]=true end
  end
  local count=0;for _ in pairs(captured) do count=count+1 end
  F.check('all six destination layouts captured',count==6)
  directMap(nil,'unknown dynamic destination',nil,false,'dynamic_destination')
  local same={{0,'kanto.deliver_parcel',1},{1,'johto.starter',5},{2,'hoenn.starter_lab',0},
    {3,'kanto.lostelle',2},{4,'kanto.warehouse',3},{5,'kanto.dotted_hole',4}}
  for _,case in ipairs(same) do
    hook(10,case[1]);F.dismiss(10)
    directMap(assert(byId[case[2]]),case[2]..' local player',case[3],true,'local_player_'..case[3])
  end
  for _,hub in ipairs({6,7}) do
    hook(10,hub);F.dismiss(10)
    directMap(byId['kanto.deliver_parcel'],'hub '..hub..' has no false player',1,false)
  end
  hook(10,0);F.dismiss(10)
  hook(9);F.check('ordinary Town Map opens after destination teardown',F.r32(X.sFieldRegionMapHandler)~=0)
  F.shot('ordinary_town_map');tap('Right');tap('B');F.check('ordinary Town Map closes normally',F.ow())
  hook(11);tap('A');tap('Right')
  local area=false
  for i=0,15 do
    local p=S.gTasks+i*40
    if F.r8(p+4)~=0 and (F.r32(p)&~1)==X.Task_HandlePokedexAreaScreenInput then area=true end
  end
  F.check('Pokedex area opens after destination teardown',area and F.r32(X.sPokedexAreaScreen)~=0)
  F.shot('pokedex_area_after_destination')
  for _=1,5 do if F.ow() then break end;tap('B') end
  F.check('Pokedex area exits normally',F.ow())
  F.finish()
end)
